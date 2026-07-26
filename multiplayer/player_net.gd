extends Node

## Added as a child of every PlayerCharacter instance by
## multiplayer/player_spawner.gd. Builds a MultiplayerSynchronizer at
## runtime (avoids hand-editing the large decompiled
## PlayerCharacterScene.tscn) that replicates state FROM whichever peer
## holds authority over the player root TO everyone else.
##
## NodePaths below are relative to this node's parent (the PlayerCharacter
## root) because MultiplayerSynchronizer.root_path defaults to "..", and
## this synchronizer is added as a direct sibling child of that root.

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
	"StateMachine:currStateName",
]

## HealthComponent:current_health / :is_dead are NOT listed here — every
## HealthComponent builds its own MultiplayerSynchronizer automatically
## (see components/health_component.gd), which also covers enemies/NPCs
## sharing the same script, not just players.


func _ready() -> void:
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
	sync.name = "PlayerNetSync"
	sync.replication_config = config
	get_parent().add_child(sync)
