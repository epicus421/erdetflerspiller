extends CanvasLayer

const RPGSHOOT: = preload("res://assets/sfx/erdetlyd/splice/rpgshoot.wav")

const MORMOREXPLODE: = preload("res://assets/sfx/erdetlyd/splice/mormorexplode.wav")

const INTRO_AUDIO_3D_BASE: = "NavigationRegion3D/HovedGata/Home/"
const INTRO_AUDIO_3D_VOX1: = INTRO_AUDIO_3D_BASE + "IntroAudioStreamPlayer3D"
const INTRO_AUDIO_3D_BOOM: = INTRO_AUDIO_3D_BASE + "IntroAudioStreamPlayer3DBoom"
const INTRO_AUDIO_3D_VOX4: = INTRO_AUDIO_3D_BASE + "IntroAudioStreamPlayer3DVox4"

@onready var black_screen: ColorRect = $BlackScreen
@onready var hint_label: Label = $HintLabel

var _audio_vox1: AudioStreamPlayer3D = null
var _audio_boom: AudioStreamPlayer3D = null

signal intro_finished

func _ready() -> void :
	if _should_skip_intro():
		_skip_intro_immediately()
		return
	_audio_vox1 = _find_audio3d(INTRO_AUDIO_3D_VOX1)
	_audio_boom = _find_audio3d(INTRO_AUDIO_3D_BOOM)
	black_screen.modulate.a = 1.0
	hint_label.text = "H — Hjelp"
	hint_label.modulate.a = 0.0
	_freeze_player(true)
	_run_intro()


func _find_audio3d(path: String) -> AudioStreamPlayer3D:
	var scene: = get_tree().current_scene
	if scene == null:
		return null
	var node: = scene.get_node_or_null(path)
	if node == null:
		push_warning("[IntroSequence] AudioStreamPlayer3D not found at " + path)
		return null
	return node as AudioStreamPlayer3D


func _should_skip_intro() -> bool:
	var current_scene: = get_tree().current_scene
	if current_scene != null:
		var scene_game_manager: = current_scene.get_node_or_null("GameManager")
		if scene_game_manager != null:
			var scene_value: Variant = scene_game_manager.get("play_intro_sequence")
			if scene_value is bool:
				return not bool(scene_value)
	if GameManager != null:
		return not bool(GameManager.play_intro_sequence)
	return false

func _run_intro() -> void :


	if _audio_vox1:
		_audio_vox1.stream = RPGSHOOT
		_audio_vox1.play()
	if _audio_boom:
		_audio_boom.stream = MORMOREXPLODE
		_audio_boom.volume_db = -4.0
		_audio_boom.play()


	await get_tree().create_timer(1.5).timeout

	var tween: = create_tween()
	tween.tween_property(black_screen, "modulate:a", 0.0, 1.5)
	await tween.finished

	_freeze_player(false)
	MusicManager.activate_idle()
	intro_finished.emit()

	await get_tree().create_timer(0.5).timeout
	var hint_tween: = create_tween()
	hint_tween.tween_property(hint_label, "modulate:a", 1.0, 0.5)
	await hint_tween.finished
	await get_tree().create_timer(4.0).timeout
	var fade_tween: = create_tween()
	fade_tween.tween_property(hint_label, "modulate:a", 0.0, 1.0)
	await fade_tween.finished

	queue_free()

func _skip_intro_immediately() -> void :

	_freeze_player(false)
	MusicManager.activate_idle()
	intro_finished.emit()
	queue_free()

func _freeze_player(frozen: bool) -> void :
	var player: = NetUtil.get_local_player()
	if player == null:
		return
	if frozen:
		player.process_mode = Node.PROCESS_MODE_DISABLED
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	else:
		player.process_mode = Node.PROCESS_MODE_INHERIT
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
