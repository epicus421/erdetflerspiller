extends Node

## Autoload: NetworkManager
##
## Owns the Steam P2P multiplayer session: creating/joining a Steam lobby,
## standing up a SteamMultiplayerPeer, and tracking who is connected.
## Everything here is a no-op (or fails safe with a status message) when
## Steam isn't available, so single-player is never affected.
##
## NOTE: This mod targets exported Steam builds only. GameManager skips Steam
## init entirely in the editor (see components/game_manager.gd _init_steam),
## so multiplayer cannot be tested from the Godot editor.
##
## Verify note: the exact Steamworks lobby method names below (createLobby,
## joinLobby, getLobbyOwner, requestLobbyList, setLobbyData, leaveLobby) match
## the documented GodotSteam GDScript API. If a specific method turns out to
## be named slightly differently in this vendored 4.20 build, Godot's
## in-editor "Search Help" for the Steam class (mentioned in
## addons/godotsteam/readme.md) is the fastest way to confirm — please report
## back any mismatch and it's a one-line fix.

signal session_started
signal session_ended(reason: String)
signal player_joined(peer_id: int)
signal player_left(peer_id: int)
signal roster_updated(peers: Dictionary)
signal host_ready(lobby_id: int)
signal join_failed(reason: String)
signal status_changed(text: String)
signal lobby_list_updated(lobbies: Array)
signal start_game_requested

const MAX_PLAYERS: int = 4
const VIRTUAL_PORT: int = 0
const LOADING_SCREEN_SCENE: String = "res://scenes/ui/loading_screen.tscn"

# Steamworks ELobbyType enum value for "friends only" — stable across SDK
# versions (0=Private, 1=FriendsOnly, 2=Public, 3=Invisible).
const LOBBY_TYPE_FRIENDS_ONLY: int = 1

var is_active: bool = false
var is_host: bool = false
var local_peer_id: int = 0
var lobby_id: int = 0
var peers: Dictionary = {}  # peer_id:int -> {steam_id:int, name:String}

## Shared across every peer for the current session (see start_game below),
## so anything that needs "the same random result on every machine" — e.g.
## scripts/streetlight_manager.gd's poster placement — can seed a local
## RandomNumberGenerator with this instead of using global randomness that
## would diverge per process.
var world_seed: int = 0

var _steam: Object = null
var _peer: MultiplayerPeer = null
var _pending_join_lobby_id: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Engine.has_singleton("Steam"):
		_steam = Engine.get_singleton("Steam")
		_connect_steam_signals()
	start_game_requested.connect(_on_start_game_requested)


func steam_available() -> bool:
	return _steam != null and GameManager != null and GameManager.steam_enabled


func _connect_steam_signals() -> void:
	if _steam == null:
		return
	_safe_connect(_steam, "lobby_created", _on_lobby_created)
	_safe_connect(_steam, "lobby_joined", _on_lobby_joined)
	_safe_connect(_steam, "lobby_match_list", _on_lobby_match_list)
	_safe_connect(_steam, "join_requested", _on_join_requested)


func _safe_connect(obj: Object, sig: String, cb: Callable) -> void:
	if obj != null and obj.has_signal(sig) and not obj.is_connected(sig, cb):
		obj.connect(sig, cb)


func _emit_status(text: String) -> void:
	print("[NetworkManager] %s" % text)
	status_changed.emit(text)


# ---------------------------------------------------------------------------
# Hosting
# ---------------------------------------------------------------------------

func host_game() -> bool:
	_emit_status("HOST_GAME BLEV KALDT!")
	
	if is_active:
		push_warning("[NetworkManager] Already in a session.")
		return false
	if not steam_available():
		_emit_status("Steam er ikke tilgjengelig — kan ikke starte flerspiller.")
		return false

	_peer = SteamMultiplayerPeer.new()
	var err: int = _peer.create_host(VIRTUAL_PORT)
	if err != OK:
		_emit_status("Kunne ikke starte vert (feil %d)." % err)
		_peer = null
		return false

	multiplayer.multiplayer_peer = _peer
	is_host = true
	is_active = true
	local_peer_id = multiplayer.get_unique_id()
	peers.clear()
	peers[local_peer_id] = {"steam_id": _steam.getSteamID(), "name": GameManager.player_name}
	_connect_multiplayer_api_signals()

	_steam.createLobby(LOBBY_TYPE_FRIENDS_ONLY, MAX_PLAYERS)
	_emit_status("Starter lobby …")
	return true


func _on_lobby_created(connect_result: int, lobby: int) -> void:
	if connect_result != 1:  # k_EResultOK == 1
		_emit_status("Kunne ikke opprette Steam-lobby (resultat %d)." % connect_result)
		return
	lobby_id = lobby
	if _steam.has_method("setLobbyData"):
		_steam.setLobbyData(lobby_id, "erdetspill_mp", "1")
	if _steam.has_method("setLobbyJoinable"):
		_steam.setLobbyJoinable(lobby_id, true)
	host_ready.emit(lobby_id)
	session_started.emit()
	_emit_status("Lobby klar. Inviter venner via Steam-overlayen (Shift+Tab).")


func invite_friends() -> void:
	if not is_active or lobby_id == 0 or _steam == null:
		return
	if _steam.has_method("activateGameOverlayInviteDialog"):
		_steam.activateGameOverlayInviteDialog(lobby_id)


# ---------------------------------------------------------------------------
# Joining
# ---------------------------------------------------------------------------

func join_lobby(target_lobby_id: int) -> void:
	if is_active:
		push_warning("[NetworkManager] Already in a session.")
		return
	if not steam_available():
		_emit_status("Steam er ikke tilgjengelig — kan ikke bli med.")
		return
	if target_lobby_id == 0:
		_emit_status("Ugyldig lobby-ID.")
		return
	_pending_join_lobby_id = target_lobby_id
	_emit_status("Kobler til lobby …")
	_steam.joinLobby(target_lobby_id)


func _on_join_requested(lobby: int, _friend_id: int) -> void:
	# Fired when the player accepts a Steam invite or clicks "Join Game" on a
	# friend's profile while the game is running.
	join_lobby(lobby)


func _on_lobby_joined(lobby: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != 1:  # k_EChatRoomEnterResponseSuccess == 1
		_emit_status("Kunne ikke bli med i lobby (respons %d)." % response)
		_pending_join_lobby_id = 0
		return

	lobby_id = lobby
	var host_steam_id: int = _steam.getLobbyOwner(lobby_id)
	if host_steam_id == 0:
		_emit_status("Fant ikke lobby-verten.")
		return
	if host_steam_id == _steam.getSteamID():
		# We are the owner — we already went through host_game(), nothing to do.
		return

	_peer = SteamMultiplayerPeer.new()
	var err: int = _peer.create_client(host_steam_id, VIRTUAL_PORT)
	if err != OK:
		_emit_status("Kunne ikke koble til vert (feil %d)." % err)
		_peer = null
		return

	multiplayer.multiplayer_peer = _peer
	is_host = false
	is_active = true
	_connect_multiplayer_api_signals()
	_emit_status("Koblet til vert. Venter på bekreftelse …")


func request_lobby_list() -> void:
	if not steam_available():
		return
	if _steam.has_method("addRequestLobbyListStringFilter"):
		_steam.addRequestLobbyListStringFilter("erdetspill_mp", "1", 0)
	_steam.requestLobbyList()


func _on_lobby_match_list(lobbies: Array) -> void:
	lobby_list_updated.emit(lobbies)


# ---------------------------------------------------------------------------
# Common MultiplayerAPI wiring (shared by host + clients)
# ---------------------------------------------------------------------------

func _connect_multiplayer_api_signals() -> void:
	_safe_connect(multiplayer, "peer_connected", _on_peer_connected)
	_safe_connect(multiplayer, "peer_disconnected", _on_peer_disconnected)
	_safe_connect(multiplayer, "connected_to_server", _on_connected_to_server)
	_safe_connect(multiplayer, "connection_failed", _on_connection_failed)
	_safe_connect(multiplayer, "server_disconnected", _on_server_disconnected)


func _on_peer_connected(id: int) -> void:
	player_joined.emit(id)


func _on_peer_disconnected(id: int) -> void:
	if is_host and peers.has(id):
		peers.erase(id)
		_broadcast_roster.rpc(peers)
	player_left.emit(id)


func _on_connected_to_server() -> void:
	local_peer_id = multiplayer.get_unique_id()
	var steam_id: int = _steam.getSteamID() if _steam != null else 0
	_submit_player_info.rpc_id(1, steam_id, GameManager.player_name)
	GameNet.request_snapshot()
	_emit_status("Tilkoblet vert.")


func _on_connection_failed() -> void:
	_cleanup_session()
	join_failed.emit("Tilkobling mislyktes.")


const TITLE_SCREEN_SCENE: String = "res://scenes/ui/title_screen.tscn"

## Read (and cleared) by title_screen.gd on _ready to reopen the multiplayer
## panel with an explanation, instead of silently dumping the player back at
## the title screen with no idea why.
var pending_disconnect_message: String = ""

func _on_server_disconnected() -> void:
	var was_in_game: bool = get_tree().current_scene != null\
		and get_tree().current_scene.scene_file_path != TITLE_SCREEN_SCENE
	_cleanup_session()
	session_ended.emit("Verten koblet fra.")
	if was_in_game:
		# Nothing else keeps the party's shared state coherent once the host
		# is gone (it was the single source of truth) — send the client back
		# to the title screen rather than leave them stuck in a half-broken
		# level with a dead multiplayer_peer.
		pending_disconnect_message = "Verten koblet fra. Du ble sendt tilbake til hovedmenyen."
		get_tree().change_scene_to_file(TITLE_SCREEN_SCENE)


@rpc("any_peer", "call_remote", "reliable")
func _submit_player_info(steam_id: int, player_name: String) -> void:
	if not is_host:
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if not peers.has(sender) and peers.size() >= MAX_PLAYERS:
		push_warning("[NetworkManager] Lobby full, rejecting peer %d." % sender)
		multiplayer.multiplayer_peer.disconnect_peer(sender)
		return
	peers[sender] = {"steam_id": steam_id, "name": player_name}
	_broadcast_roster.rpc(peers)


@rpc("authority", "call_local", "reliable")
func _broadcast_roster(new_peers: Dictionary) -> void:
	peers = new_peers
	roster_updated.emit(peers)


# ---------------------------------------------------------------------------
# Leaving / cleanup
# ---------------------------------------------------------------------------

func leave() -> void:
	_cleanup_session()
	session_ended.emit("Du forlot lobbyen.")


func _cleanup_session() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	_peer = null
	is_active = false
	is_host = false
	peers.clear()
	if lobby_id != 0 and _steam != null and _steam.has_method("leaveLobby"):
		_steam.leaveLobby(lobby_id)
	lobby_id = 0


# ---------------------------------------------------------------------------
# Starting the actual game (host-triggered, runs identically on every peer)
# ---------------------------------------------------------------------------

func start_game() -> void:
	if not is_host:
		push_warning("[NetworkManager] Only the host can start the game.")
		return
	_begin_session_game.rpc(randi())


@rpc("authority", "call_local", "reliable")
func _begin_session_game(seed_value: int) -> void:
	world_seed = seed_value
	start_game_requested.emit()


func _on_start_game_requested() -> void:
	# Mirrors the solo transition in scenes/ui/title_screen.gd _on_episode_play,
	# so every peer (host and clients) ends up on the same level the same way.
	if GameManager != null and GameManager.has_method("reset_game"):
		GameManager.reset_game()
	get_tree().change_scene_to_file(LOADING_SCREEN_SCENE)
