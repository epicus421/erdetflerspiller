extends Node3D

const INTERACT_RADIUS: = 2.5
const BIRD_INSIDE_POS: = Vector3(0.0, 16.717, 0.3)
const BIRD_OUTSIDE_POS: = Vector3(0.0, 16.717, 2.2)
const BIRD_OUT_DURATION: = 0.22
const BIRD_IN_DURATION: = 0.18
const BIRD_HOLD_DURATION: = 0.35

const KNOCK_SOUND: AudioStream = preload("res://assets/sfx/erdetlyd/splice/knockondoor.wav")
const KNOCK_DELAY: = 0.4

const CLIPS: Array[AudioStream] = [
	preload("res://assets/sfx/erdetlyd/vox/gjok/gjok_1.ogg"), 
	preload("res://assets/sfx/erdetlyd/vox/gjok/gjok_2.ogg"), 
	preload("res://assets/sfx/erdetlyd/vox/gjok/gjok_3.ogg"), 
	preload("res://assets/sfx/erdetlyd/vox/gjok/gjok_4.ogg"), 
	preload("res://assets/sfx/erdetlyd/vox/gjok/gjok_5.ogg"), 
]

var _bird_mesh: MeshInstance3D = null
var _prompt_label: Label3D = null
var _audio: AudioStreamPlayer3D = null
var _busy: bool = false
var _done: bool = false
var _knock_index: int = 0
var _player_in_range: bool = false
func _ready() -> void :
	_bird_mesh = get_node_or_null("BirdMesh") as MeshInstance3D
	if _bird_mesh:
		_bird_mesh.position = BIRD_INSIDE_POS

	_audio = AudioStreamPlayer3D.new()
	_audio.bus = "Voice"
	_audio.max_distance = 10.0
	_audio.unit_size = 3.0
	add_child(_audio)

	_prompt_label = Label3D.new()
	_prompt_label.text = "E — Bank på"
	_prompt_label.visible = false
	_prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt_label.no_depth_test = true
	_prompt_label.pixel_size = 0.003
	_prompt_label.font_size = 36
	_prompt_label.outline_size = 12
	_prompt_label.outline_modulate = Color(0, 0, 0, 1)
	_prompt_label.set_as_top_level(true)
	add_child(_prompt_label)
	_prompt_label.global_position = global_position + Vector3(-1.0, 3.0, 0)


func _process(_delta: float) -> void :
	if _prompt_label:
		_prompt_label.global_position = global_position + Vector3(0, 3.0, 0)
		_prompt_label.visible = _player_in_range and not _busy and not _done

	var player: = NetUtil.get_local_player() as Node3D
	if player == null:
		_player_in_range = false
		return
	_player_in_range = global_position.distance_to(player.global_position) <= INTERACT_RADIUS


func _input(event: InputEvent) -> void :
	if not _player_in_range or _busy or _done:
		return
	if not event.is_action_pressed("interaction") or event.is_echo():
		return
	if DialogueUI and DialogueUI.is_open():
		return
	_busy = true
	_play_knock()
	get_viewport().set_input_as_handled()


func _play_knock() -> void :
	_audio.stream = KNOCK_SOUND
	_audio.play()
	await _audio.finished
	await get_tree().create_timer(KNOCK_DELAY).timeout
	_animate_out()


func _animate_out() -> void :
	if _bird_mesh == null:
		_speak()
		return
	var tw: = create_tween()
	tw.tween_property(_bird_mesh, "position", BIRD_OUTSIDE_POS, BIRD_OUT_DURATION)\
	.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_speak)


func _speak() -> void :

	if AchievementManager != null:
		AchievementManager.unlock(AchievementManager.ACH_GJOK)
	_look_at_player()
	var clip: AudioStream = CLIPS[_knock_index]
	_audio.stream = clip
	_audio.play()
	_knock_index += 1
	if _knock_index >= CLIPS.size():
		_done = true
	await _audio.finished
	_animate_in()


func _animate_in() -> void :
	if _bird_mesh == null:
		_finish()
		return
	var tw: = create_tween()
	tw.tween_interval(BIRD_HOLD_DURATION)
	tw.tween_property(_bird_mesh, "position", BIRD_INSIDE_POS, BIRD_IN_DURATION)\
	.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_finish)


func _look_at_player() -> void :
	if _bird_mesh == null:
		return
	var player: = NetUtil.get_local_player() as Node3D
	if player == null:
		return
	var target: = Vector3(player.global_position.x, _bird_mesh.global_position.y, player.global_position.z)
	if _bird_mesh.global_position.distance_to(target) < 0.001:
		return
	_bird_mesh.look_at(target, Vector3.UP)


func _finish() -> void :
	_busy = false
