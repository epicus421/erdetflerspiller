extends CanvasLayer

signal detonation_complete

const MINIGAME_ID: = "detonator"
const HANDLE_WIDTH: = 40.0
const HANDLE_HEIGHT: = 20.0
const PLUNGER_WIDTH: = 8.0
const BOX_WIDTH: = 80.0
const BOX_HEIGHT: = 40.0
const SHAFT_HEIGHT: = 100.0

@onready var canvas: Control = $Panel / Canvas

var _handle_y: float = 0.0
var _handle_max_y: float = 1.0
var _dragging: bool = false
var _detonated: bool = false
var _drag_offset: float = 0.0

func _ready() -> void :
	process_mode = Node.PROCESS_MODE_ALWAYS
	var player: = NetUtil.get_local_player()
	if player and player.has_method("freeze_for_dialogue"):
		player.freeze_for_dialogue(true)
	if player and player.has_method("set_weapon_active"):
		player.set_weapon_active(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if GameManager and GameManager.has_method("start_minigame"):
		GameManager.start_minigame(MINIGAME_ID)
	_handle_y = 0.0
	canvas.gui_input.connect(_on_canvas_input)
	canvas.draw.connect(_on_canvas_draw)
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP


const CONTROLLER_PUSH_SPEED: = 0.9

func _process(delta: float) -> void :
	if _detonated:
		return
	if Input.is_joy_button_pressed(0, JOY_BUTTON_A):
		_handle_y = minf(1.0, _handle_y + CONTROLLER_PUSH_SPEED * delta)
		canvas.queue_redraw()
		if _handle_y >= 0.95:
			_detonate()


func _exit_tree() -> void :
	if GameManager and str(GameManager.active_minigame_id) == MINIGAME_ID and GameManager.has_method("end_minigame"):
		GameManager.end_minigame(MINIGAME_ID, 0)

func _get_detonator_rect() -> Dictionary:
	var cx: float = canvas.size.x * 0.5
	var base_y: float = canvas.size.y * 0.85
	var shaft_top: float = base_y - SHAFT_HEIGHT
	return {
		"cx": cx, 
		"base_y": base_y, 
		"shaft_top": shaft_top, 
		"box_rect": Rect2(cx - BOX_WIDTH * 0.5, base_y, BOX_WIDTH, BOX_HEIGHT), 
	}

func _get_handle_rect() -> Rect2:
	var d: = _get_detonator_rect()
	var shaft_top: float = d.shaft_top
	var base_y: float = d.base_y
	var travel: = base_y - shaft_top
	var current_y: float = shaft_top + travel * _handle_y
	return Rect2(d.cx - HANDLE_WIDTH * 0.5, current_y - HANDLE_HEIGHT * 0.5, HANDLE_WIDTH, HANDLE_HEIGHT)

func _on_canvas_input(event: InputEvent) -> void :
	if _detonated:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var handle_rect: = _get_handle_rect()
			var expanded: = handle_rect.grow(10.0)
			if expanded.has_point(event.position):
				_dragging = true
				_drag_offset = event.position.y - (handle_rect.position.y + HANDLE_HEIGHT * 0.5)
		else:
			_dragging = false
		return
	if event is InputEventMouseMotion and _dragging:
		var d: = _get_detonator_rect()
		var shaft_top: float = d.shaft_top
		var base_y: float = d.base_y
		var travel: = base_y - shaft_top
		var target_center: float = event.position.y - _drag_offset
		var new_t: float = clampf((target_center - shaft_top) / travel, 0.0, 1.0)
		_handle_y = maxf(_handle_y, new_t)
		canvas.queue_redraw()
		if _handle_y >= 0.95:
			_detonate()

func _on_canvas_draw() -> void :
	var d: = _get_detonator_rect()
	var cx: float = d.cx
	var base_y: float = d.base_y
	var shaft_top: float = d.shaft_top
	var box_rect: Rect2 = d.box_rect

	canvas.draw_rect(box_rect, Color(0.45, 0.25, 0.1), true)
	canvas.draw_rect(box_rect, Color(0.3, 0.15, 0.05), false, 2.0)

	var travel: = base_y - shaft_top
	var handle_center_y: float = shaft_top + travel * _handle_y
	canvas.draw_rect(Rect2(cx - PLUNGER_WIDTH * 0.5, handle_center_y, PLUNGER_WIDTH, base_y - handle_center_y), Color(0.35, 0.35, 0.35), true)

	var handle_rect: = _get_handle_rect()
	canvas.draw_rect(handle_rect, Color(0.7, 0.15, 0.15), true)
	canvas.draw_rect(handle_rect, Color(0.5, 0.1, 0.1), false, 2.0)

	var hint_label: = "Dra ned · hold A"
	if _detonated:
		hint_label = "BOOM!"
	canvas.draw_string(
		ThemeDB.fallback_font, 
		Vector2(cx - 50.0, shaft_top - 20.0), 
		hint_label, 
		HORIZONTAL_ALIGNMENT_CENTER, 
		-1, 
		14, 
		Color.WHITE
	)

func _detonate() -> void :
	if _detonated:
		return
	_detonated = true
	_dragging = false
	canvas.queue_redraw()
	_play_explosion_sfx()
	_flash_screen()
	await get_tree().create_timer(0.6).timeout
	var player: = NetUtil.get_local_player()
	if player and player.has_method("freeze_for_dialogue"):
		player.freeze_for_dialogue(false)
	detonation_complete.emit()
	queue_free()

func _play_explosion_sfx() -> void :
	var path: = "res://assets/sfx/erdetlyd/splice/mormorexplode.wav"
	if not ResourceLoader.exists(path):
		return
	var audio: = AudioStreamPlayer.new()
	audio.stream = load(path)
	audio.bus = "Sfx"
	audio.volume_db = 3.0
	get_tree().root.add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)

func _flash_screen() -> void :
	var flash: = ColorRect.new()
	flash.color = Color(1, 0.9, 0.5, 0.8)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var tw: = create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.5)
	tw.tween_callback(flash.queue_free)
