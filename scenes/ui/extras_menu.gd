extends Control

signal back_pressed

var _list: VBoxContainer
var _back_btn: Button


func _ready() -> void :
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func open() -> void :
	_refresh()
	visible = true

	if _back_btn:
		_back_btn.grab_focus()


func _build_ui() -> void :
	var dimmer: = ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.55)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dimmer)

	var center: = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel: = PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 240)
	center.add_child(panel)

	var margin: = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox: = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title: = Label.new()
	title.text = "EKSTRA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_list)

	var back: = Button.new()
	back.text = "Tilbake"
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect( func() -> void : back_pressed.emit())
	vbox.add_child(back)
	_back_btn = back


func _refresh() -> void :
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	if GameManager == null:
		return


	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_list.add_child(row)

	var name_lbl: = Label.new()
	name_lbl.text = "Supporter-pakke"
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var owned: bool = GameManager.has_supporter_dlc()

	if owned:
		var owned_lbl: = Label.new()
		owned_lbl.text = "Kjøpt"
		owned_lbl.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
		row.add_child(owned_lbl)
	else:

		var buy_btn: = Button.new()
		buy_btn.text = "Kjøp"
		buy_btn.pressed.connect( func() -> void : GameManager.open_supporter_store_page())
		row.add_child(buy_btn)



	if owned:
		var master: = CheckBox.new()
		master.text = "Aktiver alt"
		master.button_pressed = GameManager.is_supporter_pack_active()
		master.toggled.connect( func(on: bool) -> void :
			GameManager.set_supporter_pack_active(on)


			_refresh.call_deferred()
		)
		_list.add_child(master)

	_list.add_child(HSeparator.new())


	var g_check: = CheckBox.new()
	g_check.text = "Ekstra håndtegn"
	if not owned:
		g_check.text += " — krever Supporter-pakke"
	g_check.disabled = not owned
	g_check.button_pressed = GameManager.is_supporter_gestures_active()
	g_check.toggled.connect( func(on: bool) -> void :
		GameManager.set_supporter_gestures_active(on)
		_refresh.call_deferred()
	)
	_list.add_child(g_check)


	for skin: Dictionary in GameManager.SKINS:
		var s_owned: bool = GameManager.is_skin_owned(skin)
		var check: = CheckBox.new()
		check.text = str(skin.name)
		if not s_owned:
			check.text += " — krever Supporter-pakke"
		check.disabled = not s_owned
		check.button_pressed = GameManager.is_skin_active(str(skin.id))
		check.toggled.connect( func(on: bool) -> void :
			GameManager.set_skin_active(str(skin.id), on)
			_refresh.call_deferred()
		)
		_list.add_child(check)
