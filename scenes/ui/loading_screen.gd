extends CanvasLayer

const MAIN_DEMO_PATH: = "res://levels/main_demo.tscn"

var _transitioned: bool = false
var _slow_label: Label = null


func _ready() -> void :
	ResourceLoader.load_threaded_request(MAIN_DEMO_PATH)


	_slow_label = Label.new()
	_slow_label.text = "Første oppstart kan ta litt ekstra tid…"
	_slow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slow_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_slow_label.offset_top = -70.0
	_slow_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_slow_label.add_theme_font_size_override("font_size", 13)
	_slow_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))


	_slow_label.visible = _is_first_startup()
	add_child(_slow_label)





const FIRST_BOOT_MARKER: = "user://first_boot_done"

func _is_first_startup() -> bool:
	if FileAccess.file_exists(FIRST_BOOT_MARKER):
		return false
	var f: = FileAccess.open(FIRST_BOOT_MARKER, FileAccess.WRITE)
	if f != null:
		f.store_8(1)
		f.close()
	return true


func _process(_delta: float) -> void :
	if _transitioned:
		return

	var progress: Array = []
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(
		MAIN_DEMO_PATH, 
		progress
	)

	var bar: ProgressBar = get_node_or_null("ProgressBar") as ProgressBar
	if bar != null and not progress.is_empty():
		bar.value = progress[0] * 100.0
	if _slow_label != null and not progress.is_empty() and progress[0] >= 0.99:
		_slow_label.visible = true

	match status:
		ResourceLoader.ThreadLoadStatus.THREAD_LOAD_LOADED:
			_transitioned = true
			var scene: PackedScene = ResourceLoader.load_threaded_get(MAIN_DEMO_PATH) as PackedScene
			if scene != null:
				get_tree().change_scene_to_packed(scene)
			else:
				push_error("[LoadingScreen] Failed to get packed scene: %s" % MAIN_DEMO_PATH)
				get_tree().change_scene_to_file(MAIN_DEMO_PATH)
		ResourceLoader.ThreadLoadStatus.THREAD_LOAD_FAILED, \
		ResourceLoader.ThreadLoadStatus.THREAD_LOAD_INVALID_RESOURCE:
			_transitioned = true
			push_error("[LoadingScreen] Threaded load failed: %s" % MAIN_DEMO_PATH)
			get_tree().change_scene_to_file(MAIN_DEMO_PATH)
