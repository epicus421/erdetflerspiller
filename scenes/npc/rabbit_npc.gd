extends Node3D

@export var chair_marker_path: NodePath

@export_group("Reaksjoner")

@export var finger_react_sounds: Array[AudioStream] = []
const FINGER_REACT_COOLDOWN: float = 5.0
var _last_finger_react_time: float = -9999.0
var _finger_react_index: int = 0
var _finger_react_audio: AudioStreamPlayer3D = null

const DEATH_SCREEN_SCENE: PackedScene = preload("res://scenes/ui/death_screen.tscn")
const PUNISHMENT_SFX: Array[AudioStream] = [
	preload("res://assets/sfx/erdetlyd/vox/misc/kaninstraff0.ogg"), 
	preload("res://assets/sfx/erdetlyd/vox/misc/kaninstraff1.ogg"), 
	preload("res://assets/sfx/erdetlyd/vox/misc/kaninstraff2.ogg"), 
]

var _is_dead: bool = false
var _canvas: CanvasLayer = null

@onready var health_component: Node = $HealthComponent
@onready var sprite: Sprite3D = $Sprite3D
@onready var hitbox: Area3D = $HitboxCollision


func _ready() -> void :
	add_to_group("FingerReactable")
	if health_component:
		health_component.on_death.connect(_on_rabbit_killed)
		if health_component.has_signal("on_damage_taken"):
			health_component.on_damage_taken.connect(_on_hit)



func react_to_finger() -> void :
	if _is_dead or _finger_react_index >= finger_react_sounds.size():
		return

	if DialogueUI != null and DialogueUI.has_method("is_open") and DialogueUI.is_open():
		return
	if _finger_react_audio != null and _finger_react_audio.playing:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_finger_react_time < FINGER_REACT_COOLDOWN:
		return
	var clip: AudioStream = finger_react_sounds[_finger_react_index]
	_finger_react_index += 1
	if clip == null:
		return
	_last_finger_react_time = now
	if _finger_react_audio == null:
		_finger_react_audio = AudioStreamPlayer3D.new()
		_finger_react_audio.max_distance = 25.0
		_finger_react_audio.unit_size = 6.0
		_finger_react_audio.bus = "Voice"
		add_child(_finger_react_audio)
	_finger_react_audio.stream = clip
	_finger_react_audio.play()



func stop_finger_react() -> void :
	if _finger_react_audio != null and _finger_react_audio.playing:
		_finger_react_audio.stop()


func _on_hit(_current_health: float, _damage: float) -> void :
	if sprite:
		var tw: = create_tween()
		tw.tween_property(sprite, "modulate", Color(1, 0.3, 0.3, 1), 0.05)
		tw.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.05)


func _on_rabbit_killed() -> void :
	if _is_dead:
		return
	_is_dead = true
	AchievementManager.unlock(AchievementManager.ACH_KILL_RABBIT)

	if sprite:
		sprite.visible = false
	if hitbox:
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)

	_start_chair_sequence()


func _start_chair_sequence() -> void :
	var player: Node3D = _get_player()
	if player == null:
		return

	_freeze_player_movement(player)
	_holster_weapon()
	if player.has_method("set_weapon_active"):
		player.set_weapon_active(false)
	MusicManager.stop()

	_canvas = CanvasLayer.new()
	_canvas.layer = 99
	_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	var overlay: = ColorRect.new()
	overlay.color = Color(0, 0, 0, 1)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(overlay)
	get_tree().root.add_child(_canvas)

	await get_tree().create_timer(2.0).timeout
	if not _is_valid_state(player):
		_cancel_chair_sequence(player)
		return

	if player.has_method("reset_zoom"):
		player.reset_zoom()

	var chair_marker: Node3D = get_node_or_null(chair_marker_path) as Node3D
	if chair_marker:
		player.global_position = chair_marker.global_position
		player.velocity = Vector3.ZERO
		var cam: = _get_player_camera(player)
		if cam:
			cam.rotation = Vector3.ZERO
		player.rotation.y = PI

	await get_tree().create_timer(1.0).timeout
	if not _is_valid_state(player):
		_cancel_chair_sequence(player)
		return

	var fade_tween: = get_tree().create_tween()
	fade_tween.tween_property(overlay, "color:a", 0.0, 2.0)
	await fade_tween.finished
	if not _is_valid_state(player):
		_cancel_chair_sequence(player)
		return

	await get_tree().create_timer(1.0).timeout
	if not _is_valid_state(player):
		_cancel_chair_sequence(player)
		return

	var audio: = AudioStreamPlayer.new()
	audio.bus = "Voice"
	audio.stream = PUNISHMENT_SFX[randi() % PUNISHMENT_SFX.size()]
	get_tree().root.add_child(audio)
	audio.play()
	await audio.finished
	audio.queue_free()
	if not _is_valid_state(player):
		_cleanup_canvas()
		return

	await get_tree().create_timer(1.5).timeout
	if not _is_valid_state(player):
		_cancel_chair_sequence(player)
		return

	_shock_and_kill(player, overlay)


func _shock_and_kill(player: Node3D, overlay: ColorRect) -> void :
	var cam: = _get_player_camera(player)

	SfxManager.play("electric_shock")

	if cam:
		var shake_tween: = get_tree().create_tween()
		shake_tween.set_loops(8)
		shake_tween.tween_property(cam, "rotation:z", 0.05, 0.05)
		shake_tween.tween_property(cam, "rotation:z", -0.05, 0.05)
		await shake_tween.finished
		cam.rotation.z = 0.0

	overlay.color = Color(1, 1, 1, 0)
	var flash_tween: = get_tree().create_tween()
	flash_tween.tween_property(overlay, "color", Color(1, 1, 1, 1), 0.2)
	flash_tween.tween_property(overlay, "color", Color(0, 0, 0, 1), 1.5)
	await flash_tween.finished

	_cleanup_canvas()

	GameManager.last_death_cause = "rabbit"
	var health_comp: Node = player.get_node_or_null("HealthComponent")
	if health_comp and health_comp.has_method("take_damage"):
		health_comp.take_damage(9999.0)
	else:
		var death_screen: = DEATH_SCREEN_SCENE.instantiate()
		get_tree().root.add_child(death_screen)


func _is_valid_state(player: Node3D) -> bool:
	return is_instance_valid(player) and is_inside_tree()


func _cleanup_canvas() -> void :
	if _canvas != null and is_instance_valid(_canvas):
		_canvas.queue_free()
		_canvas = null


func _cancel_chair_sequence(player: Node3D) -> void :
	_cleanup_canvas()
	if not is_instance_valid(player):
		return
	if "movement_frozen" in player:
		player.movement_frozen = false
	if player.has_method("set_weapon_active"):
		player.set_weapon_active(true)
	if player.has_method("should_use_fps_mouse_capture") and player.should_use_fps_mouse_capture():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _freeze_player_movement(player: Node3D) -> void :
	if player == null:
		return
	if "movement_frozen" in player:
		player.movement_frozen = true
	player.velocity = Vector3.ZERO
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _holster_weapon() -> void :
	var wm: Node = get_tree().get_first_node_in_group("WeaponManager")
	if wm == null:
		wm = get_tree().get_first_node_in_group("WeaponViewmodelController")
	if wm != null and wm.has_method("holster_for_dialogue"):
		wm.holster_for_dialogue()


func _get_player() -> CharacterBody3D:
	return NetUtil.get_local_player() as CharacterBody3D


func _get_player_camera(player: Node) -> Camera3D:
	return player.get_node_or_null("CameraHolder/CameraRecoilHolder/Camera") as Camera3D


func _exit_tree() -> void :
	_cleanup_canvas()
