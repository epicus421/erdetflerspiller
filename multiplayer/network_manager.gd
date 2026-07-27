extends Node

## Autoload: NetworkManager
##
## Owns the Steam P2P multiplayer session: creating/joining a Steam lobby,
## standing up a SteamMultiplayerPeer, tracking who is connected, and getting
## every peer into the same level at the same time.
##
## Everything here is a no-op (or fails safe with a status message) when
## Steam isn't available, so single-player is never affected.
##
## NOTE: This mod targets exported Steam builds only. GameManager skips Steam
## init entirely in the editor (see components/game_manager.gd _init_steam),
## so multiplayer cannot be tested from the Godot editor.

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

## Emitted when a Steam invite arrives while we're already sitting on the
## title screen — the title screen listens for this and opens the multiplayer
## panel, so accepting an invite actually takes you somewhere instead of
## silently connecting behind a closed menu.
signal invite_received(lobby_id: int)

## Host-side: a peer has finished loading the level and its PlayerSpawnRoot
## exists, so it is now safe to replicate a body to them.
signal peer_level_ready(peer_id: int)

const Appearance := preload("res://multiplayer/player_appearance.gd")

const MAX_PLAYERS: int = 4
const VIRTUAL_PORT: int = 0
const LOADING_SCREEN_SCENE: String = "res://scenes/ui/loading_screen.tscn"
const TITLE_SCREEN_SCENE: String = "res://scenes/ui/title_screen.tscn"
const MAIN_LEVEL_SCENE: String = "res://levels/main_demo.tscn"

# Steamworks ELobbyType enum value for "friends only" — stable across SDK
# versions (0=Private, 1=FriendsOnly, 2=Public, 3=Invisible).
const LOBBY_TYPE_FRIENDS_ONLY: int = 1
## Marks our lobbies so requestLobbyList() doesn't return unrelated ones.
const LOBBY_TAG_KEY: String = "erdetspill_mp"
const LOBBY_TAG_VALUE: String = "1"

const DEFAULT_PLAYER_NAME: String = "Sokrates"
const NAME_MIN_LENGTH: int = 2
const NAME_MAX_LENGTH: int = 20

var is_active: bool = false
var is_host: bool = false
var local_peer_id: int = 0
var lobby_id: int = 0
var peers: Dictionary = {}  # peer_id:int -> {steam_id:int, name:String, character:int}

## Host-side set of peers whose level scene is actually up. A MultiplayerSpawner
## that spawns a node before the receiving peer has the spawn path in its tree
## just logs "Node not found" and drops it, which is exactly what happens to a
## late joiner — so bodies are only spawned for peers listed here.
var peers_in_level: Dictionary = {}  # peer_id:int -> true

## True from the moment the host presses START until the session ends. Peers
## that connect after this point are sent straight into the level instead of
## being left staring at the lobby forever (the original bug: _begin_session_game
## was broadcast exactly once, so late joiners never loaded anything).
var game_started: bool = false

## Shared across every peer for the current session (see start_game below),
## so anything that needs "the same random result on every machine" — e.g.
## scripts/streetlight_manager.gd's poster placement — can seed a local
## RandomNumberGenerator with this instead of using global randomness that
## would diverge per process.
var world_seed: int = 0

## Read (and cleared) by title_screen.gd on _ready to reopen the multiplayer
## panel with an explanation, instead of silently dumping the player back at
## the title screen with no idea why.
var pending_disconnect_message: String = ""

## Set when a Steam invite arrives (or the game was launched by accepting
## one). The title screen consumes it via consume_pending_invite().
var pending_invite_lobby_id: int = 0

## This machine's profile, chosen in the multiplayer panel before hosting or
## joining and persisted with the rest of the settings.
var local_player_name: String = DEFAULT_PLAYER_NAME
var local_character_id: int = 0

var _steam: Object = null
var _peer: MultiplayerPeer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Engine.has_singleton("Steam"):
		_steam = Engine.get_singleton("Steam")
		_connect_steam_signals()
	start_game_requested.connect(_on_start_game_requested)
	_load_profile()
	_check_launch_invite()


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
# Local profile (name + character), chosen before hosting/joining
# ---------------------------------------------------------------------------

## Strips anything that isn't a letter/digit/dash and capitalises, matching
## scenes/ui/name_input.gd so the multiplayer name and the single-player name
## follow one rule instead of two.
static func normalize_name(raw: String) -> String:
	var cleaned: String = ""
	for c in raw.strip_edges():
		if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z")\
		or (c >= "0" and c <= "9") or c == "-" or c in "æøåÆØÅ":
			cleaned += c
	if cleaned.is_empty():
		return ""
	if cleaned.length() > NAME_MAX_LENGTH:
		cleaned = cleaned.substr(0, NAME_MAX_LENGTH)
	return cleaned[0].to_upper() + cleaned.substr(1)


func _load_profile() -> void:
	if GameManager != null:
		local_player_name = str(GameManager.mp_player_name)
		local_character_id = Appearance.normalize_id(int(GameManager.mp_character_id))
	if normalize_name(local_player_name).length() < NAME_MIN_LENGTH:
		local_player_name = _default_name()


## Steam persona name is a far better default than "Sokrates" — it's the name
## your friends already know you by.
func _default_name() -> String:
	if steam_available() and _steam.has_method("getPersonaName"):
		var persona: String = normalize_name(str(_steam.getPersonaName()))
		if persona.length() >= NAME_MIN_LENGTH:
			return persona
	return DEFAULT_PLAYER_NAME


func get_suggested_name() -> String:
	if normalize_name(local_player_name).length() >= NAME_MIN_LENGTH:
		return local_player_name
	return _default_name()


## Returns "" on success, or a human-readable reason the name was rejected.
func set_local_profile(new_name: String, character_id: int) -> String:
	var cleaned: String = normalize_name(new_name)
	if new_name.strip_edges().contains(" "):
		return "Ingen mellomrom — bruk bindestrek (-) for dobbeltnavn."
	if cleaned.length() < NAME_MIN_LENGTH:
		return "Navnet må være minst %d bokstaver." % NAME_MIN_LENGTH

	local_player_name = cleaned
	local_character_id = Appearance.normalize_id(character_id)

	# The rest of the game reads GameManager.player_name (postkasse, ID card,
	# scholarship form…), so multiplayer must feed the same field — that's
	# what makes the lobby name a real in-game name and not just a label.
	if GameManager != null:
		GameManager.player_name = local_player_name
		GameManager.mp_player_name = local_player_name
		GameManager.mp_character_id = local_character_id
		GameManager.save_settings()

	if is_active:
		_publish_local_profile()
	return ""


## Pushes a profile edit made while already sitting in a lobby out to everyone.
func _publish_local_profile() -> void:
	if not is_active:
		return
	if is_host:
		var info: Dictionary = peers.get(local_peer_id, {})
		# Assign the resolved id back, so the picker in the lobby shows the
		# character we actually got rather than the one we asked for.
		local_character_id = _resolve_character(local_peer_id, local_character_id)
		info["name"] = local_player_name
		info["character"] = local_character_id
		peers[local_peer_id] = info
		_broadcast_roster.rpc(peers)
	else:
		_submit_player_info.rpc_id(1, _local_steam_id(), local_player_name, local_character_id)


func _local_steam_id() -> int:
	if _steam != null and _steam.has_method("getSteamID"):
		return int(_steam.getSteamID())
	return 0


## Keeps two players in the same lobby from wearing the same body. Host-side
## only, so there's a single arbiter and no tie to resolve.
func _resolve_character(peer_id: int, preferred: int) -> int:
	var taken: Array = []
	for other_id in peers:
		if int(other_id) == peer_id:
			continue
		var info: Variant = peers[other_id]
		if info is Dictionary:
			taken.append(Appearance.normalize_id(int((info as Dictionary).get("character", 0))))
	return Appearance.next_free_id(taken, preferred)


# ---------------------------------------------------------------------------
# Hosting
# ---------------------------------------------------------------------------

func host_game() -> bool:
	if is_active:
		push_warning("[NetworkManager] Already in a session.")
		return false
	if not steam_available():
		_emit_status("Steam er ikke tilgjengelig — kan ikke starte flerspiller.")
		return false

	var peer: SteamMultiplayerPeer = SteamMultiplayerPeer.new()
	var err: int = peer.create_host(VIRTUAL_PORT)
	if err != OK:
		_emit_status("Kunne ikke starte vert (feil %d)." % err)
		return false

	_peer = peer
	multiplayer.multiplayer_peer = _peer
	is_host = true
	is_active = true
	game_started = false
	local_peer_id = multiplayer.get_unique_id()
	peers.clear()
	peers[local_peer_id] = {
		"steam_id": _local_steam_id(),
		"name": local_player_name,
		"character": Appearance.normalize_id(local_character_id),
	}
	_connect_multiplayer_api_signals()
	roster_updated.emit(peers)

	_steam.createLobby(LOBBY_TYPE_FRIENDS_ONLY, MAX_PLAYERS)
	_emit_status("Starter lobby …")
	return true


func _on_lobby_created(connect_result: int, lobby: int) -> void:
	if connect_result != 1:  # k_EResultOK == 1
		# Without a lobby nobody can ever be invited, so don't sit in a
		# half-open session pretending to be a host.
		_cleanup_session()
		_emit_status("Kunne ikke opprette Steam-lobby (resultat %d)." % connect_result)
		session_ended.emit("Kunne ikke opprette lobby.")
		return
	lobby_id = lobby
	if _steam.has_method("setLobbyData"):
		_steam.setLobbyData(lobby_id, LOBBY_TAG_KEY, LOBBY_TAG_VALUE)
		_steam.setLobbyData(lobby_id, "host_name", local_player_name)
	if _steam.has_method("setLobbyJoinable"):
		_steam.setLobbyJoinable(lobby_id, true)
	host_ready.emit(lobby_id)
	session_started.emit()
	_emit_status("Lobby klar. Inviter venner via knappen under.")


func invite_friends() -> void:
	if not is_active or lobby_id == 0 or _steam == null:
		_emit_status("Du må være vert i en lobby før du kan invitere.")
		return
	if _steam.has_method("activateGameOverlayInviteDialog"):
		_steam.activateGameOverlayInviteDialog(lobby_id)
	else:
		_emit_status("Steam-overlayen er ikke tilgjengelig — del lobby-ID-en i stedet.")


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
	_emit_status("Kobler til lobby …")
	_steam.joinLobby(target_lobby_id)


func _on_lobby_joined(lobby: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != 1:  # k_EChatRoomEnterResponseSuccess == 1
		_emit_status("Kunne ikke bli med i lobby (respons %d)." % response)
		join_failed.emit("Kunne ikke bli med i lobbyen.")
		return

	var host_steam_id: int = int(_steam.getLobbyOwner(lobby))
	if host_steam_id == 0:
		_emit_status("Fant ikke lobby-verten.")
		_leave_steam_lobby(lobby)
		join_failed.emit("Fant ikke verten.")
		return
	if host_steam_id == _local_steam_id():
		# We are the owner — we already went through host_game(); this is just
		# Steam telling us we're in our own lobby.
		lobby_id = lobby
		return

	var peer: SteamMultiplayerPeer = SteamMultiplayerPeer.new()
	var err: int = peer.create_client(host_steam_id, VIRTUAL_PORT)
	if err != OK:
		_emit_status("Kunne ikke koble til vert (feil %d)." % err)
		_leave_steam_lobby(lobby)
		join_failed.emit("Kunne ikke koble til verten.")
		return

	lobby_id = lobby
	_peer = peer
	multiplayer.multiplayer_peer = _peer
	is_host = false
	is_active = true
	game_started = false
	_connect_multiplayer_api_signals()
	session_started.emit()
	_emit_status("Koblet til vert. Venter på bekreftelse …")


func request_lobby_list() -> void:
	if not steam_available():
		return
	if _steam.has_method("addRequestLobbyListStringFilter"):
		_steam.addRequestLobbyListStringFilter(LOBBY_TAG_KEY, LOBBY_TAG_VALUE, 0)
	_steam.requestLobbyList()


func _on_lobby_match_list(lobbies: Array) -> void:
	lobby_list_updated.emit(lobbies)


# ---------------------------------------------------------------------------
# Steam invites
# ---------------------------------------------------------------------------

## Fired when the player accepts a Steam invite or clicks "Join Game" on a
## friend's profile while the game is already running.
func _on_join_requested(lobby: int, _friend_id: int) -> void:
	_handle_invite(int(lobby))


## Accepting an invite while the game is CLOSED relaunches it with
## `+connect_lobby <id>` on the command line. Without this, that path did
## nothing at all — the game just booted to the title screen as usual.
func _check_launch_invite() -> void:
	var lobby: int = _parse_connect_lobby(OS.get_cmdline_args())
	if lobby == 0 and steam_available() and _steam.has_method("getLaunchCommandLine"):
		var launch: String = str(_steam.getLaunchCommandLine())
		if not launch.is_empty():
			lobby = _parse_connect_lobby(launch.split(" ", false))
	if lobby != 0:
		pending_invite_lobby_id = lobby
		print("[NetworkManager] Startet via invitasjon til lobby %d." % lobby)


func _parse_connect_lobby(args: PackedStringArray) -> int:
	for i in args.size():
		var arg: String = args[i]
		if arg.begins_with("+connect_lobby="):
			var value: String = arg.get_slice("=", 1)
			return int(value) if value.is_valid_int() else 0
		if arg == "+connect_lobby" and i + 1 < args.size():
			var next: String = args[i + 1]
			return int(next) if next.is_valid_int() else 0
	return 0


func _handle_invite(lobby: int) -> void:
	if lobby == 0:
		return
	pending_invite_lobby_id = lobby

	# Switching lobbies means abandoning the current one; do it explicitly so
	# we never try to create a second multiplayer_peer on top of a live one.
	if is_active:
		leave()

	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		# Booting up — the title screen will pick the invite up in _ready.
		return

	if tree.current_scene.scene_file_path != TITLE_SCREEN_SCENE:
		_emit_status("Invitasjon mottatt — går tilbake til hovedmenyen …")
		if PauseMenu != null and PauseMenu.has_method("unpause"):
			PauseMenu.unpause()
		tree.paused = false
		tree.change_scene_to_file(TITLE_SCREEN_SCENE)
		return

	invite_received.emit(lobby)


## Called by the title screen once its multiplayer panel is open, so the join
## status messages have somewhere visible to land.
func consume_pending_invite() -> void:
	var lobby: int = pending_invite_lobby_id
	pending_invite_lobby_id = 0
	if lobby != 0:
		join_lobby(lobby)


func has_pending_invite() -> bool:
	return pending_invite_lobby_id != 0


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
	# Deliberately does NOT spawn a body yet — the peer hasn't told us their
	# name or character. _submit_player_info does that, and player_spawner
	# listens for player_joined which we re-emit from there.
	if is_host and game_started:
		# Late joiner: pull them into the level we're already playing.
		_begin_session_game.rpc_id(id, world_seed)


func _on_peer_disconnected(id: int) -> void:
	peers_in_level.erase(id)
	if is_host and peers.has(id):
		peers.erase(id)
		_broadcast_roster.rpc(peers)
	player_left.emit(id)


# ---------------------------------------------------------------------------
# Level-load handshake
# ---------------------------------------------------------------------------

## Called by multiplayer/player_spawner.gd once the level's spawn root is in
## the tree. Until a peer reports this, the host must not spawn a body for
## them — the spawn packet would arrive before the receiving peer has anywhere
## to put it and be dropped, which is what left late joiners bodiless.
func notify_level_ready() -> void:
	if not is_active:
		return
	if is_host:
		_mark_level_ready(local_peer_id)
	else:
		_level_ready.rpc_id(1)


## Called when the spawn root leaves the tree (level restart, returning to the
## title screen) so a re-entry re-runs the handshake instead of being ignored
## as "already ready".
func notify_level_left() -> void:
	if not is_active:
		return
	if is_host:
		peers_in_level.erase(local_peer_id)
	else:
		_level_left.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _level_ready() -> void:
	if not is_host:
		return
	_mark_level_ready(multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "reliable")
func _level_left() -> void:
	if not is_host:
		return
	peers_in_level.erase(multiplayer.get_remote_sender_id())


## Always re-emits, even for a peer we already had marked: a peer that
## reloads the level (pause menu restart, rejoin) needs a fresh body, and the
## old one is stale on their machine regardless.
func _mark_level_ready(peer_id: int) -> void:
	peers_in_level[peer_id] = true
	peer_level_ready.emit(peer_id)


func _on_connected_to_server() -> void:
	local_peer_id = multiplayer.get_unique_id()
	_submit_player_info.rpc_id(1, _local_steam_id(), local_player_name, local_character_id)
	GameNet.request_snapshot()
	_emit_status("Tilkoblet vert.")


func _on_connection_failed() -> void:
	_cleanup_session()
	join_failed.emit("Tilkobling mislyktes.")


func _on_server_disconnected() -> void:
	var was_in_game: bool = get_tree() != null and get_tree().current_scene != null\
		and get_tree().current_scene.scene_file_path != TITLE_SCREEN_SCENE
	_cleanup_session()
	session_ended.emit("Verten koblet fra.")
	if was_in_game:
		# Nothing else keeps the party's shared state coherent once the host
		# is gone (it was the single source of truth) — send the client back
		# to the title screen rather than leave them stuck in a half-broken
		# level with a dead multiplayer_peer.
		pending_disconnect_message = "Verten koblet fra. Du ble sendt tilbake til hovedmenyen."
		_return_to_title()


func _return_to_title() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	if PauseMenu != null and PauseMenu.has_method("unpause"):
		PauseMenu.unpause()
	tree.paused = false
	tree.change_scene_to_file(TITLE_SCREEN_SCENE)


@rpc("any_peer", "call_remote", "reliable")
func _submit_player_info(steam_id: int, player_name: String, character_id: int) -> void:
	if not is_host:
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if not peers.has(sender) and peers.size() >= MAX_PLAYERS:
		push_warning("[NetworkManager] Lobby full, rejecting peer %d." % sender)
		if multiplayer.multiplayer_peer != null:
			multiplayer.multiplayer_peer.disconnect_peer(sender)
		return

	var was_known: bool = peers.has(sender)
	var cleaned: String = normalize_name(player_name)
	if cleaned.length() < NAME_MIN_LENGTH:
		cleaned = "Spiller %d" % sender
	peers[sender] = {
		"steam_id": steam_id,
		"name": cleaned,
		"character": _resolve_character(sender, character_id),
	}
	_broadcast_roster.rpc(peers)
	if not was_known:
		# Only now do we know who this is, so this is the right moment to give
		# them a body with the right name and character on it.
		player_joined.emit(sender)
		_announce_join.rpc(cleaned)


@rpc("authority", "call_local", "reliable")
func _broadcast_roster(new_peers: Dictionary) -> void:
	peers = new_peers
	roster_updated.emit(peers)


@rpc("authority", "call_local", "reliable")
func _announce_join(player_name: String) -> void:
	_emit_status("%s ble med i lobbyen." % player_name)


# ---------------------------------------------------------------------------
# Leaving / cleanup
# ---------------------------------------------------------------------------

func leave() -> void:
	var was_active: bool = is_active
	var leaving_host: bool = is_host
	if was_active and leaving_host and multiplayer.multiplayer_peer != null:
		# Tell clients explicitly; SteamMultiplayerPeer teardown alone can be
		# slow to surface as server_disconnected on their end.
		_host_closing.rpc()
	_cleanup_session()
	if was_active:
		session_ended.emit("Du forlot lobbyen.")


## Leaving from inside the level (pause menu) rather than the title screen.
func leave_and_return_to_title() -> void:
	leave()
	_return_to_title()


@rpc("authority", "call_remote", "reliable")
func _host_closing() -> void:
	pending_disconnect_message = "Verten avsluttet økten."
	var was_in_game: bool = get_tree() != null and get_tree().current_scene != null\
		and get_tree().current_scene.scene_file_path != TITLE_SCREEN_SCENE
	_cleanup_session()
	session_ended.emit("Verten avsluttet økten.")
	if was_in_game:
		_return_to_title()


func _leave_steam_lobby(lobby: int) -> void:
	if lobby != 0 and _steam != null and _steam.has_method("leaveLobby"):
		_steam.leaveLobby(lobby)


func _cleanup_session() -> void:
	if _peer != null:
		# Closing releases the Steam networking sockets; just dropping the
		# reference leaves them alive until GC and breaks the next host_game().
		if _peer.has_method("close"):
			_peer.close()
		_peer = null
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	is_active = false
	is_host = false
	game_started = false
	local_peer_id = 0
	world_seed = 0
	peers.clear()
	peers_in_level.clear()
	_leave_steam_lobby(lobby_id)
	lobby_id = 0
	roster_updated.emit(peers)


# ---------------------------------------------------------------------------
# Starting the actual game (host-triggered, runs identically on every peer)
# ---------------------------------------------------------------------------

func can_start_game() -> bool:
	return is_active and is_host and not game_started


func start_game() -> void:
	if not is_host:
		push_warning("[NetworkManager] Only the host can start the game.")
		return
	if game_started:
		_emit_status("Økten er allerede i gang.")
		return
	_begin_session_game.rpc(randi())


@rpc("authority", "call_local", "reliable")
func _begin_session_game(seed_value: int) -> void:
	world_seed = seed_value
	game_started = true
	start_game_requested.emit()


func _on_start_game_requested() -> void:
	# Mirrors the solo transition in scenes/ui/title_screen.gd _on_episode_play,
	# so every peer (host and clients) ends up on the same level the same way.
	if GameManager != null and GameManager.has_method("reset_game"):
		GameManager.reset_game()

	# A client's local state was just wiped by that reset; pull the party's
	# real money/inventory/quests back from the host. For a fresh session this
	# is a no-op (the host is equally fresh); for a late joiner it is the whole
	# point — they'd otherwise walk into an in-progress game with nothing.
	if not is_host:
		GameNet.request_snapshot()

	var tree: SceneTree = get_tree()
	if tree == null:
		return
	if tree.current_scene != null\
	and tree.current_scene.scene_file_path == MAIN_LEVEL_SCENE:
		# Already standing in the level — don't yank ourselves back to loading.
		return
	tree.change_scene_to_file(LOADING_SCREEN_SCENE)
