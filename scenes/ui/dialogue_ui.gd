extends CanvasLayer

signal dialogue_finished
signal dialogue_line_shown(line_index: int)

@onready var dialogue_panel: Control = $DialoguePanel
@onready var speaker_panel: PanelContainer = $DialoguePanel / MarginContainer / VBoxContainer / SpeakerPanel
@onready var speaker_label: Label = $DialoguePanel / MarginContainer / VBoxContainer / SpeakerPanel / SpeakerLabel
@onready var dialogue_label: Label = $DialoguePanel / MarginContainer / VBoxContainer / DialogueTextPanel / DialogueLabel
@onready var button_container: VBoxContainer = $DialoguePanel / MarginContainer / VBoxContainer / ButtonContainer
@onready var continue_button: Button = $DialoguePanel / MarginContainer / VBoxContainer / ButtonContainer / ContinueButton

var _lines: Array = []
var _index: int = 0
var _on_close: Callable = Callable()
var _speaker: String = ""
var _skippable: bool = true
const THOUGHT_COLOR: = Color(0.6, 0.8, 1.0)
const NPC_COLOR: = Color.WHITE
const PANEL_BOTTOM_OFFSET: = -24
const PANEL_HEIGHT_DIALOGUE: = 180
const BUTTON_MIN_HEIGHT: = 40

func _ready() -> void :
	dialogue_panel.visible = false
	dialogue_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_configure_menu_button(continue_button)
	continue_button.pressed.connect(_on_continue_pressed)




	continue_button.focus_mode = Control.FOCUS_NONE


func _apply_button_style(button: Button) -> void :
	button.add_theme_font_size_override("font_size", 13)

	var normal_style: = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.14, 0.14, 0.17, 0.95)
	normal_style.set_corner_radius_all(3)
	normal_style.content_margin_top = 10
	normal_style.content_margin_bottom = 10
	normal_style.content_margin_left = 12
	normal_style.content_margin_right = 12
	normal_style.border_width_bottom = 1
	normal_style.border_color = Color(0.3, 0.3, 0.35)

	var hover_style: = normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(0.22, 0.22, 0.27, 1.0)

	var pressed_style: = normal_style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(0.1, 0.1, 0.13, 0.98)

	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("focus", hover_style)


func _set_speaker_display(speaker_name: String) -> void :
	if speaker_name == "":
		speaker_panel.visible = false
		return
	speaker_label.text = speaker_name.to_upper()
	speaker_panel.visible = true


func show_dialogue(lines: Array, speaker: String = "", on_close: Callable = Callable()) -> void :
	_stop_finger_reactions()
	_holster_weapon()
	_lines = lines.duplicate()
	_index = 0
	_speaker = speaker
	_on_close = on_close
	set_skippable(true)
	_clear_menu_buttons()
	continue_button.visible = true
	_set_speaker_display(speaker)
	_apply_dialogue_panel_layout()
	dialogue_panel.visible = true
	_ensure_mouse_visible()
	_freeze_player(true)
	_show_next_line()


func show_menu(lines: Array, buttons: Array, speaker: String = "") -> void :
	_stop_finger_reactions()
	_holster_weapon()
	_lines = lines.duplicate()
	_index = 0
	_speaker = speaker
	_on_close = Callable()
	_clear_menu_buttons()
	continue_button.visible = false
	_set_speaker_display(speaker)
	var body_text: = _lines_to_body_text(lines)
	_set_dialogue_text(body_text, false)
	dialogue_panel.visible = true
	_ensure_mouse_visible()
	_freeze_player(true)
	for btn_data in buttons:
		var act: Callable = btn_data.get("action", Callable())
		_add_button(str(btn_data.get("text", "?")), act)
	_apply_menu_panel_layout(buttons.size(), body_text)


	_focus_first_menu_button.call_deferred()


func _focus_first_menu_button() -> void :
	for child in button_container.get_children():
		if child is Button and child != continue_button\
		and (child as Button).visible and not (child as Button).disabled:
			(child as Button).grab_focus()
			return




func _stop_finger_reactions() -> void :
	for npc in get_tree().get_nodes_in_group("FingerReactable"):
		if npc != null and is_instance_valid(npc) and npc.has_method("stop_finger_react"):
			npc.stop_finger_react()


func close() -> void :
	dialogue_panel.visible = false
	_clear_menu_buttons()
	set_skippable(true)
	_lines.clear()
	_index = 0
	_speaker = ""
	_freeze_player(false)
	var weapon_mgr: = _get_weapon_manager()
	if weapon_mgr != null and weapon_mgr.has_method("set_weapon_controls_enabled"):
		weapon_mgr.set_weapon_controls_enabled(true)
	if weapon_mgr != null and weapon_mgr.has_method("restore_after_dialogue"):
		weapon_mgr.restore_after_dialogue()
	_restore_mouse_capture()




	var cb: = _on_close
	_on_close = Callable()
	_restore_player_weapons()
	dialogue_finished.emit()
	if cb.is_valid():
		cb.call()


func is_open() -> bool:
	return dialogue_panel.visible


func set_skippable(can_skip: bool) -> void :
	_skippable = can_skip
	if continue_button == null:
		return
	continue_button.visible = can_skip
	continue_button.disabled = not can_skip


func _show_next_line() -> void :
	if _index >= _lines.size():
		close()
		return
	var line = _lines[_index]
	var shown_index: int = _index
	_index += 1
	var text: String = ""
	var is_thought: bool = false
	if line is Dictionary:
		text = str(line.get("text", ""))
		is_thought = bool(line.get("is_thought", false)) or bool(line.get("is_player_thought", false))
	elif str(line).begins_with("§"):
		text = str(line).substr(1)
		is_thought = true
	else:
		text = str(line)
	_set_dialogue_text(text, is_thought)
	_update_text_panel_min_height(text)
	dialogue_line_shown.emit(shown_index)




const ADVANCE_DEBOUNCE_MS: = 200
var _last_advance_ms: int = 0

func _on_continue_pressed() -> void :
	if not _skippable:
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_advance_ms < ADVANCE_DEBOUNCE_MS:
		return
	_last_advance_ms = now
	_show_next_line()





func _unhandled_input(event: InputEvent) -> void :
	if not is_open():
		return
	var advance: bool = false
	if event is InputEventJoypadButton:
		var jb: = event as InputEventJoypadButton
		advance = jb.pressed and jb.button_index == JOY_BUTTON_A
	elif event is InputEventKey:
		var k: = event as InputEventKey
		advance = k.pressed and not k.echo\
		and k.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]
	if not advance:
		return
	if continue_button != null and continue_button.visible and _skippable:
		_on_continue_pressed()
		get_viewport().set_input_as_handled()


func _clear_menu_buttons() -> void :
	for child in button_container.get_children():
		if child != continue_button:
			child.queue_free()


func _lines_to_body_text(lines: Array) -> String:
	if lines.is_empty():
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for line in lines:
		if line is Dictionary:
			parts.append(str(line.get("text", "")))
		else:
			parts.append(str(line))
	return "\n".join(parts)


func _get_dialogue_text_panel() -> PanelContainer:
	return dialogue_label.get_parent() as PanelContainer


func _set_dialogue_text(text: String, is_thought: bool) -> void :
	dialogue_label.text = text
	dialogue_label.add_theme_color_override(
		"font_color", 
		THOUGHT_COLOR if is_thought else NPC_COLOR
	)


func _update_text_panel_min_height(text: String) -> void :
	var text_panel: = _get_dialogue_text_panel()
	if text_panel == null:
		return
	var line_count: = maxi(1, text.split("\n", false).size())
	text_panel.custom_minimum_size.y = maxi(48, line_count * 15 + 20)


func _apply_dialogue_panel_layout() -> void :
	var text_panel: = _get_dialogue_text_panel()
	if text_panel:
		text_panel.custom_minimum_size.y = 48
	dialogue_panel.offset_top = - PANEL_HEIGHT_DIALOGUE
	dialogue_panel.offset_bottom = PANEL_BOTTOM_OFFSET


func _apply_menu_panel_layout(num_buttons: int, body_text: String) -> void :
	_update_text_panel_min_height(body_text)
	var line_count: = maxi(1, body_text.split("\n", false).size())
	var panel_height: = _calculate_panel_height(num_buttons, line_count, speaker_panel.visible)
	dialogue_panel.offset_top = - panel_height
	dialogue_panel.offset_bottom = PANEL_BOTTOM_OFFSET


func _calculate_panel_height(num_buttons: int, line_count: int, has_speaker: bool) -> int:
	const PANEL_PAD: = 16
	const SPEAKER_H: = 30
	const LINE_H: = 15
	const TEXT_PAD: = 20
	const VBOX_GAP: = 4
	var height: = PANEL_PAD
	if has_speaker:
		height += SPEAKER_H + VBOX_GAP
	height += maxi(48, line_count * LINE_H + TEXT_PAD) + VBOX_GAP
	height += num_buttons * BUTTON_MIN_HEIGHT
	if num_buttons > 1:
		height += (num_buttons - 1) * 2
	height += VBOX_GAP
	return height


func _configure_menu_button(btn: Button) -> void :
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.custom_minimum_size = Vector2(0, BUTTON_MIN_HEIGHT)
	_apply_button_style(btn)


func _add_button(text: String, action: Callable) -> void :
	var btn: = Button.new()
	btn.text = text
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_configure_menu_button(btn)
	btn.pressed.connect(
		func():
			_clear_menu_buttons()
			continue_button.visible = true
			if action.is_valid():
				action.call()
	)
	button_container.add_child(btn)


func _freeze_player(frozen: bool) -> void :
	var player: = NetUtil.get_local_player()
	if player and player.has_method("freeze_for_dialogue"):
		player.freeze_for_dialogue(frozen)


func _get_weapon_manager() -> Node:
	var wm: = get_tree().get_first_node_in_group("WeaponManager")
	if wm != null:
		return wm
	return get_tree().get_first_node_in_group("WeaponViewmodelController")


func _holster_weapon() -> void :
	var weapon_mgr: = _get_weapon_manager()
	if weapon_mgr != null and weapon_mgr.has_method("holster_for_dialogue"):
		weapon_mgr.holster_for_dialogue()


func _restore_player_weapons() -> void :
	var player: = NetUtil.get_local_player()
	if player == null:
		return
	if player.has_method("set_weapon_active"):
		player.set_weapon_active(true)


func _ensure_mouse_visible() -> void :
	if Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _restore_mouse_capture() -> void :
	var player: = NetUtil.get_local_player()
	if player and player.has_method("should_use_fps_mouse_capture") and not player.should_use_fps_mouse_capture():
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
