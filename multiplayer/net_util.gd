extends Node

## Autoload: NetUtil
##
## Multiplayer-aware replacements for the single-player assumptions baked
## throughout the codebase (get_first_node_in_group("PlayerCharacter"),
## GameManager.get_player()). Safe to call in solo play — with no active
## session there is exactly one PlayerCharacter, and every lookup here
## degenerates to that.


func get_all_players() -> Array:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return []
	return tree.get_nodes_in_group("PlayerCharacter")


## The player controlled by this instance of the game (local input authority).
func get_local_player() -> Node3D:
	if NetworkManager == null or not NetworkManager.is_active:
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		if tree == null:
			return null
		return tree.get_first_node_in_group("PlayerCharacter") as Node3D

	for p in get_all_players():
		if p is Node3D and (p as Node).is_multiplayer_authority():
			return p as Node3D
	return null


## Nearest player to a world position — for enemy targeting, area triggers,
## etc. Falls back to the single local player in solo play.
func get_nearest_player(pos: Vector3) -> Node3D:
	var best: Node3D = null
	var best_dist_sq: float = INF
	for p in get_all_players():
		if not (p is Node3D) or not is_instance_valid(p):
			continue
		var node3d: Node3D = p as Node3D
		var dist_sq: float = node3d.global_position.distance_squared_to(pos)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best = node3d
	return best


## The player whose action is currently being processed: the host resolving
## a client's networked request resolves to that client's player; anything
## else (solo play, local input, a client replaying a host broadcast)
## resolves to the local player. Use this (via GameManager.get_player())
## anywhere game logic means "the player who did this," not necessarily
## "the player on this machine."
func get_acting_player() -> Node3D:
	if GameNet != null and GameNet.current_actor_peer_id != 0:
		var actor: Node3D = get_player_by_peer(GameNet.current_actor_peer_id)
		if actor != null:
			return actor
	return get_local_player()


func get_player_by_peer(peer_id: int) -> Node3D:
	for p in get_all_players():
		if (p as Node).get_multiplayer_authority() == peer_id:
			return p as Node3D
	return null


## True while any active session exists, whether we're host or a client.
func is_multiplayer_session() -> bool:
	return NetworkManager != null and NetworkManager.is_active
