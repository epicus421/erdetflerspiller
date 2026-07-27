extends Node

## Defines what gets replicated for a player body, and builds the
## MultiplayerSynchronizer that does it.
##
## This used to be a *node* added under each PlayerCharacter, which built the
## synchronizer from its own `_ready()` via `get_parent().add_child(sync)`.
## That silently failed every single time:
##
##     ERROR: Parent node is busy setting up children, `add_child()` failed.
##
## A node is "blocked" while Godot is propagating `_ready()` through its
## children, so a child cannot add siblings to its parent at that moment — the
## call is rejected and the synchronizer was never created. No synchronizer
## meant no position/velocity/look-direction ever left the machine, which is
## why every remote player stood frozen at their spawn point.
##
## Now the synchronizer is built by multiplayer/player_spawner.gd inside the
## spawn function, while the player body is still detached from the tree. That
## is both legal and better: the synchronizer is present the moment the node is
## spawned, so Godot registers it as part of the spawn on every peer.
##
## NodePaths below are relative to the PlayerCharacter root, because
## MultiplayerSynchronizer.root_path defaults to ".." and the synchronizer is
## added as a direct child of that root.

const ALWAYS_PROPERTIES: Array[String] = [
	".:position",
	".:velocity",
	"CameraHolder:rotation:y",
	"CameraHolder/CameraRecoilHolder/Camera:rotation:x",
	"Model:scale",
]

const ON_CHANGE_PROPERTIES: Array[String] = [
	".:is_sitting",
	".:movement_frozen",
	".:net_weapon_id",
	".:net_hand_gesture",
	"StateMachine:currStateName",
]

## HealthComponent:current_health / :is_dead are NOT listed here — every
## HealthComponent builds its own MultiplayerSynchronizer automatically
## (see components/health_component.gd), which also covers enemies/NPCs
## sharing the same script, not just players.

const SYNC_NODE_NAME: String = "PlayerNetSync"

## How often the "always" properties go out. The default (0 = every physics
## frame, 60/s) is a lot of traffic for a 4-player P2P session over Steam
## relays; 20/s is plenty for bodies that are visually interpolated anyway.
const SYNC_INTERVAL: float = 0.05


## Build the synchronizer for a player body. Add the result to the body
## BEFORE it enters the scene tree, then set the body's multiplayer authority
## recursively so this node inherits it — `add_child()` does NOT copy the
## parent's authority (a fresh node always defaults to peer 1, the host), and
## a synchronizer evaluates its authority when it enters the tree.
static func build_synchronizer() -> MultiplayerSynchronizer:
	var config: SceneReplicationConfig = SceneReplicationConfig.new()

	for prop_path in ALWAYS_PROPERTIES:
		var path: NodePath = NodePath(prop_path)
		config.add_property(path)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)

	for prop_path in ON_CHANGE_PROPERTIES:
		var path: NodePath = NodePath(prop_path)
		config.add_property(path)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)

	var sync: MultiplayerSynchronizer = MultiplayerSynchronizer.new()
	sync.name = SYNC_NODE_NAME
	sync.replication_config = config
	sync.replication_interval = SYNC_INTERVAL
	return sync
