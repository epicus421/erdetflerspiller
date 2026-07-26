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
## just receive the resulting nodes automatically (built-in Godot behavior
## for MultiplayerSpawner, including catching up peers who join in progress).

const PLAYER_SCENE: PackedScene = preload("res://scenes/PlayerCharacter/Scenes/PlayerCharacterScene.tscn")
const PLAYER_NET_SCRIPT: Script = preload("res://multiplayer/player_net.gd")
const BAKED_PLAYER_PATH: String = "NavigationRegion3D/PlayerCharacter"

@export var spawn_points: Array[Vector3] = [
	Vector3(-97.23, 1.83, -21.80),
	Vector3(-95.23, 1.83, -21.80),
	Vector3(-97.23, 1.83, -19.80),
	Vector3(-95.23, 1.83, -19.80),
]

var _spawner: MultiplayerSpawner
var _spawned: Dictionary = {}  # peer_id:int -> Node


func _ready() -> void:
	if not NetUtil.is_multiplayer_session():
		queue_free()
		return

	var current_scene: Node = get_tree().current_scene
	if current_scene != null:
		var baked_player: Node = current_scene.get_node_or_null(BAKED_PLAYER_PATH)
		if baked_player != null:
			baked_player.queue_free()

	_spawner = MultiplayerSpawner.new()
	_spawner.name = "PlayerSpawner"
	_spawner.spawn_path = get_path()
	_spawner.spawn_function = _spawn_player
	add_child(_spawner)

	NetworkManager.player_left.connect(_on_player_left)

	if NetworkManager.is_host:
		for peer_id in NetworkManager.peers.keys():
			_spawn_for_peer(int(peer_id))
		NetworkManager.player_joined.connect(_on_player_joined)


func _on_player_joined(peer_id: int) -> void:
	if NetworkManager.is_host:
		_spawn_for_peer(peer_id)


func _on_player_left(peer_id: int) -> void:
	if not NetworkManager.is_host or not _spawned.has(peer_id):
		return
	var node: Node = _spawned[peer_id]
	if is_instance_valid(node):
		node.queue_free()
	_spawned.erase(peer_id)


func _spawn_for_peer(peer_id: int) -> void:
	if _spawned.has(peer_id):
		return
	_spawned[peer_id] = _spawner.spawn({"peer_id": peer_id})


func _spawn_player(data: Dictionary) -> Node:
	var peer_id: int = int(data.get("peer_id", 1))
	var instance: Node3D = PLAYER_SCENE.instantiate() as Node3D
	instance.name = "Player_%d" % peer_id
	instance.set_multiplayer_authority(peer_id)

	if not spawn_points.is_empty():
		var spawn_index: int = _spawned.size() % spawn_points.size()
		instance.position = spawn_points[spawn_index]

	var net: Node = Node.new()
	net.name = "PlayerNet"
	net.set_script(PLAYER_NET_SCRIPT)
	instance.add_child(net)

	return instance
