extends "res://addons/3dEnemyToolkit/Example/example_enemy.gd"

const FIRE_SFX: = preload("res://assets/sfx/erdetlyd/splice/rpgshoot.wav")

var _fire_audio: AudioStreamPlayer3D = null
var _activated: bool = false


func _ready() -> void :
	GameManager.quest_changed.connect(_on_quest_changed)
	GameManager.quest_progress_updated.connect(_on_quest_progress_updated)
	_sync_activation()


func _sync_activation() -> void :
	if GameManager.is_iver_hunting_active():
		_enable_moose()
	else:
		_disable_moose()


func _enable_moose() -> void :
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	_activate()


func _disable_moose() -> void :
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED


func _activate() -> void :
	if _activated:
		return
	_activated = true
	super._ready()
	detection_range = 30.0
	lose_sight_range = 40.0
	projectile_range = 25.0
	if follow_target_3d != null:
		follow_target_3d.path_desired_distance = 1.0
		follow_target_3d.target_desired_distance = 1.0
		follow_target_3d.avoidance_enabled = false
	_fire_audio = AudioStreamPlayer3D.new()
	_fire_audio.stream = FIRE_SFX
	_fire_audio.volume_db = 0.0
	_fire_audio.bus = "Sfx"
	add_child(_fire_audio)


func _bootstrap_navigation_agent() -> void :
	if not is_instance_valid(self) or not _activated:
		return
	await get_tree().physics_frame
	if not is_instance_valid(self) or not _activated:
		return
	super._bootstrap_navigation_agent()
	var player: = NetUtil.get_nearest_player(global_position)
	if player != null\
	and global_position.distance_to(player.global_position) <= detection_range:
		target = player
		_last_known_player_pos = player.global_position
		_has_last_known_pos = true
		ChangeState(States.Pursuit)


func _on_quest_changed(quest_id: String, _state: int) -> void :
	if quest_id != "IVER_BEVIS":
		return
	_sync_activation()


func _on_quest_progress_updated(quest_id: String, _progress: int) -> void :
	if quest_id != "IVER_BEVIS":
		return
	_sync_activation()


func _projectile_attack() -> void :
	if not target or not is_instance_valid(target) or enemy_weapon == null:
		return
	if _fire_audio != null:
		_fire_audio.play()
	super._projectile_attack()
