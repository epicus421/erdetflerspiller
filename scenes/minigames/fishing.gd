extends CanvasLayer

signal fishing_complete(success: bool)

const GREEN_START: float = 0.4
const GREEN_END: float = 0.6

var marker_pos: float = 0.0
var marker_speed: float = 1.5
var marker_dir: float = 1.0
var waiting: bool = true
var wait_timer: float = 0.0
var wait_duration: float = 0.0

@onready var _wait_label: Label = $Panel / VBox / WaitLabel
@onready var _fishing_bar: Control = $Panel / VBox / FishingBar
@onready var _press_label: Label = $Panel / VBox / PressLabel


func _ready() -> void :
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 12
	wait_duration = randf_range(2.0, 4.0)
	_wait_label.visible = true
	_fishing_bar.visible = false
	_press_label.visible = false
	if GameManager and GameManager.has_method("start_minigame"):
		GameManager.start_minigame("fishing")
	var player: = NetUtil.get_local_player()
	if player and player.has_method("freeze_for_dialogue"):
		player.freeze_for_dialogue(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _exit_tree() -> void :
	if GameManager and str(GameManager.active_minigame_id) == "fishing"\
	and GameManager.has_method("end_minigame"):
		GameManager.end_minigame("fishing", 0)


func _process(delta: float) -> void :
	if waiting:
		wait_timer += delta
		if wait_timer >= wait_duration:
			waiting = false
			_wait_label.visible = false
			_fishing_bar.visible = true
			_press_label.visible = true
		return
	marker_pos += marker_speed * marker_dir * delta
	if marker_pos >= 1.0:
		marker_pos = 1.0
		marker_dir = -1.0
	elif marker_pos <= 0.0:
		marker_pos = 0.0
		marker_dir = 1.0
	if _fishing_bar.has_method("update_marker"):
		_fishing_bar.update_marker(marker_pos)


func _unhandled_input(_event: InputEvent) -> void :
	if waiting:
		return
	if Input.is_action_just_pressed("interaction"):
		get_viewport().set_input_as_handled()
		var success: bool = marker_pos >= GREEN_START and marker_pos <= GREEN_END
		fishing_complete.emit(success)
		queue_free()
