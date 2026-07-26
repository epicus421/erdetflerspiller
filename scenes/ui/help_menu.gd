extends CanvasLayer




@onready var _vbox: VBoxContainer = $CenterContainer / PanelContainer / VBoxContainer
@onready var _keyboard_grid: GridContainer = $CenterContainer / PanelContainer / VBoxContainer / ControlsGrid
@onready var _close_hint: Label = $CenterContainer / PanelContainer / VBoxContainer / CloseHint

var _controller_grid: GridContainer
var _tab_keyboard: Button
var _tab_controller: Button
var _showing_controller: bool = false


const CONTROLLER_ROWS: Array = [
	["Venstre stikke", "Beveg deg"], 
	["Høyre stikke", "Se deg rundt"], 
	["RT", "Skyt"], 
	["LT", "Mys med øya"], 
	["A", "Hopp"], 
	["B", "Huk deg"], 
	["X", "Lad om"], 
	["Y", "Interager / snakk"], 
	["LB / RB", "Bytt våpen"], 
	["L3 (venstre stikke inn)", "Løp"], 
	["D-pad opp", "Lommelykt"], 
	["D-pad ned", "Plukk opp / slipp"], 
	["D-pad venstre", "Inventar"], 
	["D-pad høyre", "Kart"], 
	["R3 (høyre stikke inn)", "Bytt håndtegn"], 
	["Start", "Pause"], 
	["Back", "Hjelp (denne menyen)"], 
]


func _ready() -> void :
	visible = false
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_tabs_and_controller_grid()


func _build_tabs_and_controller_grid() -> void :
	var kb_index: int = _keyboard_grid.get_index()


	var tabs: = HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 12)
	_tab_keyboard = _make_tab_button("Tastatur", false)
	_tab_controller = _make_tab_button("Kontroller", true)
	tabs.add_child(_tab_keyboard)
	tabs.add_child(_tab_controller)
	_vbox.add_child(tabs)
	_vbox.move_child(tabs, kb_index)


	_controller_grid = GridContainer.new()
	_controller_grid.columns = 2
	_controller_grid.add_theme_constant_override("h_separation", 24)
	_controller_grid.add_theme_constant_override("v_separation", 6)
	for row: Array in CONTROLLER_ROWS:
		_controller_grid.add_child(_make_cell(str(row[0])))
		_controller_grid.add_child(_make_cell(str(row[1])))
	_controller_grid.visible = false
	_vbox.add_child(_controller_grid)
	_vbox.move_child(_controller_grid, kb_index + 2)

	if _close_hint:
		_close_hint.text = "LB / RB bytter fane · H for å lukke"


func _make_tab_button(label: String, controller_tab: bool) -> Button:
	var b: = Button.new()
	b.text = label
	b.toggle_mode = true
	b.button_pressed = controller_tab == _showing_controller
	b.pressed.connect( func() -> void : _set_tab(controller_tab))
	return b


func _make_cell(txt: String) -> Label:
	var l: = Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", 14)
	return l


func _set_tab(controller: bool) -> void :
	_showing_controller = controller
	_keyboard_grid.visible = not controller
	_controller_grid.visible = controller
	_tab_keyboard.button_pressed = not controller
	_tab_controller.button_pressed = controller

	var active: = _tab_controller if controller else _tab_keyboard
	if active:
		active.grab_focus()


func _show_help() -> void :
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_set_tab(_showing_controller)


func _hide_help() -> void :
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event: InputEvent) -> void :

	var toggle: bool = (event is InputEventKey and (event as InputEventKey).pressed\
	and not (event as InputEventKey).echo\
	and (event as InputEventKey).keycode == KEY_H)\
	or (event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed\
	and (event as InputEventJoypadButton).button_index == JOY_BUTTON_BACK)
	if toggle:
		if visible:
			_hide_help()
		else:
			_show_help()
		get_viewport().set_input_as_handled()
		return

	if not visible:
		return


	if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		var btn: int = (event as InputEventJoypadButton).button_index
		if btn == JOY_BUTTON_LEFT_SHOULDER:
			_set_tab(false)
			get_viewport().set_input_as_handled()
		elif btn == JOY_BUTTON_RIGHT_SHOULDER:
			_set_tab(true)
			get_viewport().set_input_as_handled()
