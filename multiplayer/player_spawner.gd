extends Node

## Added to res://levels/main_demo.tscn as "PlayerSpawnRoot" (child of World).
##
## In solo play (no active NetworkManager session) this does nothing and the
## level's baked single PlayerCharacter (NavigationRegion3D/PlayerCharacter)
## is used exactly as before.
##
## In a multiplayer session it removes that baked player and spawns one
## PlayerCharacterScene per connected peer instead, replicated via a
## MultiplayerSpawner. Only the host decides who spawns/despawns; clients
## just receive the resulting nodes automatically.
##
## Spawning is gated on NetworkManager.peers_in_level: a MultiplayerSpawner
## that spawns before the receiving peer has the spawn path in its own tree
## silently drops the node, which is why a peer who joined after "START" used
## to end up in an empty world.

const PLAYER_SCENE: PackedScene = preload("res://scenes/PlayerCharacter/Scenes/PlayerCharacterScene.tscn")
const PlayerNet := preload("res://multiplayer/player_net.gd")
const BAKED_PLAYER_PATH: String = "NavigationRegion3D/PlayerCharacter"

@export var spawn_points: Array[Vector3] = [
	Vector3(-97.23, 1.83, -21.80),
	Vector3(-95.23, 1.83, -21.80),
	Vector3(-97.23, 1.83, -19.80),
	Vector3(-95.23, 1.83, -19.80),
]

var _spawner: MultiplayerSpawner
var _spawned: Dictionary = {}  # peer_id:int -> Node
## Stable per-peer spawn slot so two peers never share a spawn point and a
## re-spawn puts you back where you were, rather than wherever the dictionary
## happened to be sized at the time.
var _spawn_slots: Dictionary = {}  # peer_id:int -> int
var _next_spawn_slot: int = 0


func _ready() -> void:
	if not NetUtil.is_multiplayer_session():
		queue_free()
		return

	var current_scene: Node = get_tree().current_scene
	if current_scene != null:
		var baked_player: Node = current_scene.get_node_or_null(BAKED_PLAYER_PATH)
		if baked_player != null:
			# Free immediately, not queue_free: the group lookups in
			# NetUtil/GameManager run this same frame and would otherwise pick
			# the dead single-player body as "the" player.
			baked_player.get_parent().remove_child(baked_player)
			baked_player.queue_free()

	_spawner = MultiplayerSpawner.new()
	_spawner.name = "PlayerSpawner"
	_spawner.spawn_path = get_path()
	_spawner.spawn_function = _spawn_player
	add_child(_spawner)

	NetworkManager.player_left.connect(_on_player_left)

	if NetworkManager.is_host:
		NetworkManager.peer_level_ready.connect(_on_peer_level_ready)
		# Peers already standing in the level (e.g. we restarted the level
		# from the pause menu) still need bodies.
		for peer_id in NetworkManager.peers_in_level.keys():
			_spawn_for_peer(int(peer_id))

	# Tell the host we have somewhere to put a body. On the host this resolves
	# locally and spawns our own body on the next signal.
	NetworkManager.notify_level_ready.call_deferred()


func _exit_tree() -> void:
	# Can run during application shutdown, when the autoload may already be on
	# its way out.
	if NetworkManager != null and is_instance_valid(NetworkManager):
		NetworkManager.notify_level_left()


func _on_peer_level_ready(peer_id: int) -> void:
	if not NetworkManager.is_host:
		return
	# A repeat report means that peer reloaded the level, so whatever body we
	# spawned for them before is gone on their machine — replace it rather
	# than leaving a puppet nobody drives.
	_despawn(peer_id)
	_spawn_for_peer(peer_id)


func _despawn(peer_id: int) -> void:
	if not _spawned.has(peer_id):
		return
	var node: Node = _spawned[peer_id]
	if is_instance_valid(node):
		node.queue_free()
	_spawned.erase(peer_id)


func _on_player_left(peer_id: int) -> void:
	if not NetworkManager.is_host:
		return
	_despawn(peer_id)


func _spawn_for_peer(peer_id: int) -> void:
	if _spawned.has(peer_id):
		return
	if not NetworkManager.peers.has(peer_id):
		# We know they're in the level but not yet who they are; _submit_player_info
		# is still in flight. peer_level_ready will not fire again, so wait for
		# the roster instead of spawning a nameless body.
		if not NetworkManager.roster_updated.is_connected(_on_roster_updated):
			NetworkManager.roster_updated.connect(_on_roster_updated)
		return
	_spawned[peer_id] = _spawner.spawn({
		"peer_id": peer_id,
		"slot": _slot_for(peer_id),
	})


func _on_roster_updated(_peers: Dictionary) -> void:
	if not NetworkManager.is_host:
		return
	for peer_id in NetworkManager.peers_in_level.keys():
		_spawn_for_peer(int(peer_id))


func _slot_for(peer_id: int) -> int:
	if not _spawn_slots.has(peer_id):
		_spawn_slots[peer_id] = _next_spawn_slot
		_next_spawn_slot += 1
	return int(_spawn_slots[peer_id])


## Runs on EVERY peer (the host passes `data` along, Godot replays this
## function remotely), so it must not depend on host-only state.
func _spawn_player(data: Dictionary) -> Node:
	var peer_id: int = int(data.get("peer_id", 1))
	var instance: Node3D = PLAYER_SCENE.instantiate() as Node3D
	instance.name = "Player_%d" % peer_id

	if not spawn_points.is_empty():
		var slot: int = int(data.get("slot", 0))
		instance.position = spawn_points[posmod(slot, spawn_points.size())]

	# Attach the synchronizer here, while the body is still detached from the
	# tree. It used to be built from a child node's _ready(), which Godot
	# rejects outright ("Parent node is busy setting up children") — so no
	# synchronizer was ever created and nobody ever moved on anyone else's
	# screen. See multiplayer/player_net.gd for the full story.
	instance.add_child(PlayerNet.build_synchronizer())

	# AFTER add_child, and recursive: a freshly created node always defaults to
	# authority 1 (the host) and does NOT inherit its parent's authority, and a
	# MultiplayerSynchronizer decides who transmits based on the authority it
	# has when it enters the tree. Doing this last covers the whole body,
	# including the synchronizer and every HealthComponent inside it.
	instance.set_multiplayer_authority(peer_id)

	return instance
