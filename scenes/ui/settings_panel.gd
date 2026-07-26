extends PanelContainer

signal settings_changed

const PANEL_MIN_SIZE: = Vector2(440, 300)
const SAVE_DEBOUNCE_SEC: = 0.4
const LABEL_MIN_WIDTH: = 124.0
const VALUE_MIN_WIDTH: = 52.0

var _tabs: TabContainer
var _root: VBoxContainer
var _save_timer: Timer


func _ready() -> void :
	custom_minimum_size = PANEL_MIN_SIZE
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DEBOUNCE_SEC
	_save_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_save_timer.timeout.connect(_save_now)
	add_child(_save_timer)
	visibility_changed.connect(_on_visibility_changed)
	_build_settings_panel()


func refresh_from_game_manager() -> void :
	_build_settings_panel()


func _build_settings_panel() -> void :
	var prev_tab: = 0
	if _tabs != null and is_instance_valid(_tabs):
		prev_tab = _tabs.current_tab
	if _root != null and is_instance_valid(_root):
		remove_child(_root)
		_root.queue_free()

	_root = VBoxContainer.new()
	_root.add_theme_constant_override("separation", 8)
	add_child(_root)

	_tabs = TabContainer.new()
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_child(_tabs)

	_build_video_tab(_add_tab_page("Video"))
	_build_audio_tab(_add_tab_page("Lyd"))
	_build_game_tab(_add_tab_page("Spill"))
	_tabs.current_tab = clampi(prev_tab, 0, _tabs.get_tab_count() - 1)

	var bottom: = HBoxContainer.new()
	_root.add_child(bottom)

	var spacer: = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)

	var reset_btn: = Button.new()
	reset_btn.text = "Tilbakestill"
	reset_btn.pressed.connect(_on_reset_pressed)
	bottom.add_child(reset_btn)


func _add_tab_page(title: String) -> VBoxContainer:
	var margin: = MarginContainer.new()
	margin.name = title
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_tabs.add_child(margin)

	var page: = VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	margin.add_child(page)
	return page


func _build_video_tab(page: VBoxContainer) -> void :
	if GameManager == null:
		return

	_add_check(page, "Fullskjerm", GameManager.fullscreen_enabled, func(on: bool) -> void :
		GameManager.apply_fullscreen(on)
	)

	var size_names: Array[String] = []
	for s: Vector2i in GameManager.WINDOW_SIZES:
		size_names.append("%d×%d" % [s.x, s.y])
	_add_option_row(page, "Vindusstørrelse", size_names, GameManager.window_size_index, 
		func(idx: int) -> void :
			GameManager.window_size_index = idx
			GameManager.apply_window_size()
	)

	_add_check(page, "V-sync", GameManager.vsync_enabled, func(on: bool) -> void :
		GameManager.apply_vsync(on)
	)
	_add_check(page, "Skygger", GameManager.shadows_enabled, func(on: bool) -> void :
		GameManager.shadows_enabled = on
		GameManager.apply_shadows(on)
	)
	_add_slider_row(page, "Render-avstand", 40.0, 385.0, 5.0, GameManager.render_distance, 
		func(v: float) -> String: return "%d m" % int(v), 
		func(v: float) -> void : GameManager.apply_render_distance(v)
	)
	_add_slider_row(page, "Lysstyrke", 0.5, 1.5, 0.05, GameManager.brightness, _fmt_percent, 
		func(v: float) -> void :
			GameManager.brightness = v
			GameManager.apply_brightness_contrast()
	)
	_add_slider_row(page, "Kontrast", 0.5, 1.5, 0.05, GameManager.contrast, _fmt_percent, 
		func(v: float) -> void :
			GameManager.contrast = v
			GameManager.apply_brightness_contrast()
	)


func _build_audio_tab(page: VBoxContainer) -> void :
	if GameManager == null:
		return

	_add_slider_row(page, "Hovedvolum", 0.0, 1.0, 0.01, GameManager.master_volume, _fmt_percent, 
		func(v: float) -> void :
			GameManager.master_volume = v
			GameManager.apply_master_volume()
	)
	_add_slider_row(page, "Musikk", 0.0, 1.0, 0.01, GameManager.music_volume, _fmt_percent, 
		func(v: float) -> void : GameManager.apply_music_volume(v)
	)
	_add_slider_row(page, "Effekter", 0.0, 1.0, 0.01, GameManager.sfx_volume, _fmt_percent, 
		func(v: float) -> void : GameManager.apply_sfx_volume(v)
	)
	_add_slider_row(page, "Stemmer", 0.0, 1.0, 0.01, GameManager.voice_volume, _fmt_percent, 
		func(v: float) -> void : GameManager.apply_voice_volume(v)
	)


func _build_game_tab(page: VBoxContainer) -> void :
	if GameManager == null:
		return

	_add_slider_row(page, "Musfølsomhet", 0.1, 3.0, 0.1, GameManager.mouse_sensitivity, 
		func(v: float) -> String: return "%.1f" % v, 
		func(v: float) -> void :
			GameManager.mouse_sensitivity = v
			GameManager.apply_mouse_sensitivity()
	)
	_add_check(page, "Inverter Y-akse", GameManager.invert_y, func(on: bool) -> void :
		GameManager.invert_y = on
		GameManager.apply_mouse_sensitivity()
	)

	var sr_text: = "Speedrun-timer"
	if not GameManager.game_completed_once:
		sr_text = "Speedrun-timer (fullfør spillet først)"
	var sr_check: = _add_check(page, sr_text, GameManager.speedrun_timer_on, func(on: bool) -> void :
		GameManager.speedrun_timer_on = on
		if SpeedrunTimer:
			SpeedrunTimer.refresh_visibility()
	)
	sr_check.disabled = not GameManager.game_completed_once


func _add_slider_row(
	page: Control, 
	label_text: String, 
	min_v: float, 
	max_v: float, 
	step: float, 
	value: float, 
	fmt: Callable, 
	on_apply: Callable
) -> void :
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(row)

	var lbl: = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(LABEL_MIN_WIDTH, 0)
	row.add_child(lbl)

	var slider: = HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)

	var value_lbl: = Label.new()
	value_lbl.text = String(fmt.call(value))
	value_lbl.custom_minimum_size = Vector2(VALUE_MIN_WIDTH, 0)
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_lbl)

	slider.value_changed.connect( func(v: float) -> void :
		value_lbl.text = String(fmt.call(v))
		on_apply.call(v)
		_queue_save()
		settings_changed.emit()
	)
	slider.drag_ended.connect( func(changed: bool) -> void :
		if changed:
			_save_now()
	)


func _add_option_row(page: Control, label_text: String, options: Array[String], selected: int, on_select: Callable) -> OptionButton:
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(row)

	var lbl: = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(LABEL_MIN_WIDTH, 0)
	row.add_child(lbl)

	var option: = OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for opt in options:
		option.add_item(opt)
	option.selected = clampi(selected, 0, options.size() - 1)
	option.item_selected.connect( func(idx: int) -> void :
		on_select.call(idx)
		_queue_save()
		settings_changed.emit()
	)
	row.add_child(option)
	return option


func _add_check(page: Control, text: String, pressed: bool, on_toggle: Callable) -> CheckBox:
	var check: = CheckBox.new()
	check.text = text
	check.button_pressed = pressed
	check.toggled.connect( func(on: bool) -> void :
		on_toggle.call(on)
		_queue_save()
		settings_changed.emit()
	)
	page.add_child(check)
	return check


func _fmt_percent(v: float) -> String:
	return "%d%%" % int(round(v * 100.0))


func _queue_save() -> void :
	_save_timer.start()


func _save_now() -> void :
	_save_timer.stop()
	if GameManager:
		GameManager.save_settings()


func _on_visibility_changed() -> void :
	if not is_visible_in_tree() and _save_timer != null and not _save_timer.is_stopped():
		_save_now()


func _exit_tree() -> void :
	if _save_timer != null and not _save_timer.is_stopped():
		_save_now()


func _on_reset_pressed() -> void :
	if GameManager:
		GameManager.reset_settings_to_defaults()
	_build_settings_panel()
	settings_changed.emit()
