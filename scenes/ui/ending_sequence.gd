extends CanvasLayer

@onready var overlay: ColorRect = $BlackOverlay
@onready var bestefar_line: Label = $BestefarLine
@onready var ending_audio: AudioStreamPlayer = $EndingAudio

const JINGLE_PATH: = "res://assets/sfx/erdetlyd/musikk/endingjingle.ogg"
const MORMOR_IMAGE_PATH: = "res://assets/textures/images/mormor.png"
const TEXT_1_TIME: = 6.0
const TEXT_2_TIME: = 10.0

var _mormor_rect: TextureRect = null


func _show_mormor_image() -> void :
	if not ResourceLoader.exists(MORMOR_IMAGE_PATH):
		return
	var tex: Texture2D = load(MORMOR_IMAGE_PATH) as Texture2D
	if tex == null:
		return
	_mormor_rect = TextureRect.new()
	_mormor_rect.texture = tex
	_mormor_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_mormor_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE


	_mormor_rect.set_anchors_preset(Control.PRESET_CENTER)
	_mormor_rect.offset_left = -90.0
	_mormor_rect.offset_right = 90.0
	_mormor_rect.offset_top = -125.0
	_mormor_rect.offset_bottom = 35.0
	_mormor_rect.modulate.a = 0.0
	add_child(_mormor_rect)
	var tw: = create_tween()
	tw.tween_property(_mormor_rect, "modulate:a", 1.0, 0.8)

func _ready() -> void :
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.modulate.a = 0.0
	bestefar_line.modulate.a = 0.0
	_run_ending()


func _run_ending() -> void :
	for radio in get_tree().get_nodes_in_group("Radio"):
		if is_instance_valid(radio) and radio.has_method("stop_radio"):
			radio.stop_radio()
	MusicManager.stop(true)

	var player: = NetUtil.get_local_player()
	if player:
		player.process_mode = Node.PROCESS_MODE_DISABLED

	if not ResourceLoader.exists(JINGLE_PATH):
		push_warning("[Ending] Jingle not found: " + JINGLE_PATH)
		get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
		return

	ending_audio.stream = load(JINGLE_PATH)
	ending_audio.bus = "Music"
	ending_audio.volume_db = -6.0
	ending_audio.play()
	var music_start: = Time.get_ticks_msec() / 1000.0

	var tween: = create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, 2.0)
	await tween.finished

	var elapsed: = Time.get_ticks_msec() / 1000.0 - music_start
	var wait_1: = maxf(0.0, TEXT_1_TIME - elapsed)
	if wait_1 > 0.0:
		await get_tree().create_timer(wait_1).timeout

	bestefar_line.text = "Bestefar fikk 2 is."
	var t1: = create_tween()
	t1.tween_property(bestefar_line, "modulate:a", 1.0, 0.8)
	await t1.finished

	elapsed = Time.get_ticks_msec() / 1000.0 - music_start
	var wait_2: = maxf(0.0, TEXT_2_TIME - elapsed)
	if wait_2 > 0.0:
		await get_tree().create_timer(wait_2).timeout

	var t2: = create_tween()
	t2.tween_property(bestefar_line, "modulate:a", 0.0, 0.5)
	await t2.finished

	bestefar_line.text = _get_proud_line()
	_show_mormor_image()
	var t3: = create_tween()
	t3.tween_property(bestefar_line, "modulate:a", 1.0, 0.8)
	await t3.finished

	if ending_audio.playing:
		await ending_audio.finished

	await get_tree().create_timer(1.5).timeout

	var t4: = create_tween()
	t4.tween_property(bestefar_line, "modulate:a", 0.0, 1.0)
	if _mormor_rect != null:
		t4.parallel().tween_property(_mormor_rect, "modulate:a", 0.0, 1.0)
	await t4.finished

	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")


func _get_proud_line() -> String:
	if GameManager and GameManager.speedrun_timer_on and GameManager.last_playthrough_time > 0.0:
		if SpeedrunTimer:
			return SpeedrunTimer._format_time(GameManager.last_playthrough_time)
		return _format_playthrough_time(GameManager.last_playthrough_time)
	return "Mormor ville vært stolt."


func _format_playthrough_time(seconds: float) -> String:
	var m: int = int(seconds) / 60
	var sec: int = int(seconds) % 60
	var ms: int = int(seconds * 100) % 100
	return "%02d:%02d.%02d" % [m, sec, ms]
