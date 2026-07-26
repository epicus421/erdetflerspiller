extends CanvasLayer

var _running: bool = false
var _elapsed: float = 0.0

@onready var _timer_label: Label = $TimerLabel


func _ready() -> void :
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not get_tree().scene_changed.is_connected(_on_scene_changed):
		get_tree().scene_changed.connect(_on_scene_changed)
	if GameManager and GameManager.has_signal("game_reset")\
	and not GameManager.game_reset.is_connected(_on_game_reset):
		GameManager.game_reset.connect(_on_game_reset)
	_refresh_for_current_scene()


func _on_scene_changed() -> void :
	_refresh_for_current_scene()


func _refresh_for_current_scene() -> void :
	var in_game: = false
	var scene: = get_tree().current_scene
	if scene != null:
		in_game = scene.scene_file_path == "res://levels/main_demo.tscn"
	visible = GameManager.speedrun_timer_on and in_game
	_running = in_game
	if _timer_label:
		_timer_label.text = _format_time(_elapsed)


func _process(delta: float) -> void :
	if not _running:
		return
	_elapsed += delta
	if _timer_label:
		_timer_label.text = _format_time(_elapsed)


func stop() -> void :
	_running = false


func reset_timer() -> void :
	_elapsed = 0.0
	_refresh_for_current_scene()
	if _timer_label:
		_timer_label.text = _format_time(_elapsed)


func refresh_visibility() -> void :
	_refresh_for_current_scene()


func get_elapsed() -> float:
	return _elapsed


func _on_game_reset() -> void :
	reset_timer()


func _format_time(s: float) -> String:
	var m: int = int(s) / 60
	var sec: int = int(s) % 60
	var ms: int = int(s * 100) % 100
	return "%02d:%02d.%02d" % [m, sec, ms]
