extends CanvasLayer

signal form_submitted

const BRUSH_WIDTH: = 3.0
const SIG_BRUSH_WIDTH: = 2.0
const MINIGAME_ID: = "id_card_form"

@onready var form_panel: PanelContainer = $FormPanel
@onready var name_field: LineEdit = $FormPanel / MarginContainer / VBox / HBoxContainer / VBoxContainer / NameField
@onready var surname_field: LineEdit = $FormPanel / MarginContainer / VBox / HBoxContainer / VBoxContainer2 / SurnameField
@onready var dob_field: LineEdit = $FormPanel / MarginContainer / VBox / HBoxContainer2 / VBoxContainer / DOBField
@onready var height_field: LineEdit = $FormPanel / MarginContainer / VBox / HBoxContainer2 / VBoxContainer2 / HeightField
@onready var gender_option: OptionButton = $FormPanel / MarginContainer / VBox / HBoxContainer2 / VBoxContainer3 / GenderOption
@onready var portrait_frame: PanelContainer = $FormPanel / MarginContainer / VBox / PortraitFrame
@onready var portrait_box: Control = $FormPanel / MarginContainer / VBox / PortraitFrame / PortraitBox
@onready var sig_frame: PanelContainer = $FormPanel / MarginContainer / VBox / SignatureFrame
@onready var sig_box: Control = $FormPanel / MarginContainer / VBox / SignatureFrame / SignatureBox
@onready var submit_button: Button = $FormPanel / MarginContainer / VBox / ButtonRow / SubmitButton
@onready var clear_button: Button = $FormPanel / MarginContainer / VBox / ButtonRow / ClearButton
@onready var cancel_button: Button = $FormPanel / MarginContainer / VBox / ButtonRow / CancelButton
@onready var error_label: Label = $FormPanel / MarginContainer / VBox / ErrorLabel

var _portrait_points: Array[Vector2] = []
var _portrait_breaks: Array[int] = []
var _portrait_drawing: bool = false
var _has_portrait: bool = false

var _sig_points: Array[Vector2] = []
var _sig_breaks: Array[int] = []
var _sig_drawing: bool = false
var _has_sig: bool = false

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

	name_field.text = GameManager.player_name
	name_field.editable = false
	surname_field.text = ""
	dob_field.text = ""
	height_field.text = ""
	error_label.text = ""

	submit_button.pressed.connect(_on_submit)
	clear_button.pressed.connect(_on_clear_all)
	cancel_button.pressed.connect(_on_cancel)
	dob_field.text_changed.connect(_on_dob_text_changed)

	surname_field.grab_focus()



func _on_dob_text_changed(new_text: String) -> void :
	var digits: = ""
	for ch in new_text:
		if ch >= "0" and ch <= "9":
			digits += ch
			if digits.length() >= 8:
				break
	var formatted: = ""
	for i in digits.length():
		if i == 2 or i == 4:
			formatted += "."
		formatted += digits[i]
	if formatted == new_text:
		return
	dob_field.text = formatted
	dob_field.caret_column = formatted.length()

func _exit_tree() -> void :
	if GameManager and str(GameManager.active_minigame_id) == MINIGAME_ID and GameManager.has_method("end_minigame"):
		GameManager.end_minigame(MINIGAME_ID, 0)



func _signature_is_substantial(points: Array[Vector2]) -> bool:
	if points.size() < 20:
		return false
	var mn: Vector2 = points[0]
	var mx: Vector2 = points[0]
	for p in points:
		mn = mn.min(p)
		mx = mx.max(p)
	return (mx - mn).length() >= 30.0

func _on_portrait_gui_input(event: InputEvent) -> void :
	_handle_draw_input(event, portrait_box, _portrait_points, _portrait_breaks, "_portrait_drawing", "_has_portrait")

func _on_portrait_draw() -> void :
	_draw_canvas(portrait_box, _portrait_points, _portrait_breaks, Color.BLACK, BRUSH_WIDTH)

func _on_portrait_mouse_exited() -> void :
	_portrait_drawing = false

func _on_sig_gui_input(event: InputEvent) -> void :
	_handle_draw_input(event, sig_box, _sig_points, _sig_breaks, "_sig_drawing", "_has_sig")

func _on_sig_draw() -> void :
	_draw_canvas(sig_box, _sig_points, _sig_breaks, Color.BLACK, SIG_BRUSH_WIDTH)

func _on_sig_mouse_exited() -> void :
	_sig_drawing = false

func _handle_draw_input(event: InputEvent, canvas: Control, points: Array[Vector2], breaks: Array[int], drawing_var: String, has_var: String) -> void :
	var rect: = Rect2(Vector2.ZERO, canvas.size)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		set(drawing_var, event.pressed)
		if event.pressed:
			if not points.is_empty():
				breaks.append(points.size())
			var point: Vector2 = event.position
			if rect.has_point(point):
				points.append(point)
				set(has_var, true)
		canvas.queue_redraw()
		return
	if event is InputEventMouseMotion and get(drawing_var):
		var point: Vector2 = event.position
		if rect.has_point(point):
			points.append(point)
			set(has_var, true)
		canvas.queue_redraw()

func _draw_canvas(canvas: Control, points: Array[Vector2], breaks: Array[int], color: Color, width: float) -> void :
	var rect: = Rect2(Vector2.ZERO, canvas.size)
	canvas.draw_rect(rect, Color.WHITE, true)
	canvas.draw_rect(rect, Color(0.3, 0.3, 0.3), false, 2.0)
	if points.size() < 2:
		return
	for i in range(1, points.size()):
		if breaks.has(i):
			continue
		canvas.draw_line(points[i - 1], points[i], color, width)

func _on_clear_all() -> void :
	_portrait_points.clear()
	_portrait_breaks.clear()
	_has_portrait = false
	portrait_box.queue_redraw()
	_sig_points.clear()
	_sig_breaks.clear()
	_has_sig = false
	sig_box.queue_redraw()

func _on_cancel() -> void :
	var player: = NetUtil.get_local_player()
	if player and player.has_method("freeze_for_dialogue"):
		player.freeze_for_dialogue(false)
	if player and player.has_method("set_weapon_active"):
		player.set_weapon_active(true)
	queue_free()

func _on_submit() -> void :
	var surname: = surname_field.text.strip_edges()
	var dob: = dob_field.text.strip_edges()
	var height_text: = height_field.text.strip_edges()

	if surname == "":
		_show_error("Du ma fylle inn etternavn.")
		return
	if dob == "":
		_show_error("Du ma fylle inn fodselsdato.")
		return
	var dob_err: = _dob_error(dob)
	if dob_err != "":
		_show_error(dob_err)
		return
	if height_text == "":
		_show_error("Du ma fylle inn hoyde.")
		return
	if not _validate_height(height_text):
		_show_error("Ugyldig hoyde. Skriv et tall i cm (f.eks. 175).")
		return
	if not _has_portrait:
		_show_error("Du ma tegne et bilde av deg selv.")
		return
	if not _has_sig or not _signature_is_substantial(_sig_points):
		_show_error("Du ma signere skikkelig — ikke bare en prikk.")
		return

	var portrait_size: = Vector2(portrait_box.size)
	var sig_size: = Vector2(sig_box.size)
	var gender_text: = ""
	if gender_option.selected >= 0:
		gender_text = gender_option.get_item_text(gender_option.selected)
	GameManager.id_card_data = {
		"first_name": name_field.text, 
		"surname": surname.to_upper(), 
		"dob": dob, 
		"height": height_text + " CM", 
		"sex": gender_text, 
		"portrait_points": _portrait_points.duplicate(), 
		"portrait_breaks": _portrait_breaks.duplicate(), 
		"portrait_size": portrait_size, 
		"sig_points": _sig_points.duplicate(), 
		"sig_breaks": _sig_breaks.duplicate(), 
		"sig_size": sig_size, 
	}

	GameManager.apply_for_id_card()
	var player: = NetUtil.get_local_player()
	if player and player.has_method("freeze_for_dialogue"):
		player.freeze_for_dialogue(false)
	form_submitted.emit()
	queue_free()







func _dob_error(text: String) -> String:
	var regex: = RegEx.new()
	regex.compile("^(\\d{2})\\.(\\d{2})\\.(\\d{4})$")
	var m: = regex.search(text)
	if m == null:
		return "Ugyldig fodselsdato. Bruk format: DD.MM.YYYY"
	var day: = m.get_string(1).to_int()
	var month: = m.get_string(2).to_int()
	var year: = m.get_string(3).to_int()
	if month < 1 or month > 12:
		return "Ugyldig maned. Bruk 01-12."
	if day < 1 or day > _days_in_month(month, year):
		return "Ugyldig dag for denne maneden."
	var now: = Time.get_date_dict_from_system()
	if year < 1900:
		return "Ugyldig arstall."
	var cur_y: = int(now["year"])
	var cur_m: = int(now["month"])
	var cur_d: = int(now["day"])
	if year > cur_y\
	or (year == cur_y and month > cur_m)\
	or (year == cur_y and month == cur_m and day > cur_d):
		return "Du kan ikke vaere fodt i fremtiden."
	return ""


func _days_in_month(month: int, year: int) -> int:
	match month:
		4, 6, 9, 11:
			return 30
		2:
			var leap: = (year % 4 == 0 and year % 100 != 0) or year % 400 == 0
			return 29 if leap else 28
	return 31

func _validate_height(text: String) -> bool:
	var regex: = RegEx.new()
	regex.compile("^\\d{2,3}$")
	var m: = regex.search(text)
	if m == null:
		return false
	var val: = int(text)
	return val >= 50 and val <= 250

func _show_error(msg: String) -> void :
	error_label.text = msg
	SfxManager.play("ui_error")
