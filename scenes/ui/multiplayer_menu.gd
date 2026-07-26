extends Control

signal back_pressed

var _status_lbl: Label
var _host_btn: Button
var _join_btn: Button
var _lobby_id_field: LineEdit
var _invite_btn: Button
var _start_btn: Button
var _leave_btn: Button
var _roster_box: VBoxContainer
var _lobby_panel: Control
var _setup_panel: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	
	# Vi forbinder signaler sikkert, så det aldrig crasher
	if NetworkManager:
		if NetworkManager.has_signal("status_changed"):
			NetworkManager.status_changed.connect(_on_status_changed)
		if NetworkManager.has_signal("roster_updated"):
			NetworkManager.roster_updated.connect(_on_roster_updated)
		if NetworkManager.has_signal("session_started"):
			NetworkManager.session_started.connect(_refresh_panels)
		if NetworkManager.has_signal("session_ended"):
			NetworkManager.session_ended.connect(_on_session_ended)
		if NetworkManager.has_signal("join_failed"):
			NetworkManager.join_failed.connect(_on_status_changed)
			
	_refresh_panels()


func open() -> void:
	show()
	_refresh_panels()
	if _host_btn:
		_host_btn.grab_focus.call_deferred()


func show_status(text: String) -> void:
	show()
	if _status_lbl:
		_status_lbl.text = text
	_refresh_panels()


func _build_ui() -> void:
	var dimmer = ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.70)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dimmer)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel = PanelContainer.new()
	center.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(300, 0)
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var title = Label.new()
	title.text = "FLERSPILLER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_status_lbl = Label.new()
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_lbl.add_theme_color_override("font_color", Color(0.8, 0.65, 0.45))
	vbox.add_child(_status_lbl)

	_build_setup_panel(vbox)
	_build_lobby_panel(vbox)

	var back = Button.new()
	back.text = "Tilbake"
	back.custom_minimum_size = Vector2(0, 45)
	back.pressed.connect(func() -> void:
		if NetworkManager and NetworkManager.get("is_active") == true:
			NetworkManager.call("leave")
		back_pressed.emit()
	)
	vbox.add_child(back)


func _build_setup_panel(parent: VBoxContainer) -> void:
	var panel_vbox = VBoxContainer.new()
	panel_vbox.add_theme_constant_override("separation", 12)
	parent.add_child(panel_vbox)
	_setup_panel = panel_vbox

	_host_btn = Button.new()
	_host_btn.text = "VÆR VERT"
	_host_btn.custom_minimum_size = Vector2(0, 45)
	# Vi binder den til en rigtig funktion i stedet for en inline lambda
	_host_btn.pressed.connect(_on_host_pressed)
	panel_vbox.add_child(_host_btn)

	var join_row = HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 8)
	panel_vbox.add_child(join_row)

	_lobby_id_field = LineEdit.new()
	_lobby_id_field.placeholder_text = "Lobby-ID"
	_lobby_id_field.custom_minimum_size = Vector2(180, 45)
	_lobby_id_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_row.add_child(_lobby_id_field)

	_join_btn = Button.new()
	_join_btn.text = "BLI MED"
	_join_btn.custom_minimum_size = Vector2(90, 45)
	_join_btn.pressed.connect(_on_join_pressed)
	join_row.add_child(_join_btn)

	var hint = Label.new()
	hint.text = "Tips: du kan også bli med via Steam-vennelisten når verten har invitert deg."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	panel_vbox.add_child(hint)


func _build_lobby_panel(parent: VBoxContainer) -> void:
	var panel_vbox = VBoxContainer.new()
	panel_vbox.add_theme_constant_override("separation", 12)
	panel_vbox.hide()
	parent.add_child(panel_vbox)
	_lobby_panel = panel_vbox

	var roster_title = Label.new()
	roster_title.text = "Spillere:"
	panel_vbox.add_child(roster_title)

	_roster_box = VBoxContainer.new()
	panel_vbox.add_child(_roster_box)

	_invite_btn = Button.new()
	_invite_btn.text = "INVITER VENN (STEAM)"
	_invite_btn.custom_minimum_size = Vector2(0, 45)
	_invite_btn.pressed.connect(func() -> void: 
		if NetworkManager: NetworkManager.call("invite_friends")
	)
	panel_vbox.add_child(_invite_btn)

	_start_btn = Button.new()
	_start_btn.text = "START SPILLET"
	_start_btn.custom_minimum_size = Vector2(0, 45)
	_start_btn.pressed.connect(func() -> void: 
		if NetworkManager: NetworkManager.call("start_game")
	)
	panel_vbox.add_child(_start_btn)

	_leave_btn = Button.new()
	_leave_btn.text = "AVSLUTT LOBBY"
	_leave_btn.custom_minimum_size = Vector2(0, 45)
	_leave_btn.pressed.connect(func() -> void: 
		if NetworkManager: NetworkManager.call("leave")
	)
	panel_vbox.add_child(_leave_btn)


func _on_join_pressed() -> void:
	if not _lobby_id_field: return
	var text = _lobby_id_field.text.strip_edges()
	if not text.is_valid_int():
		if _status_lbl: _status_lbl.text = "Skriv inn en gyldig lobby-ID."
		return
	if NetworkManager:
		NetworkManager.call("join_lobby", int(text))

func _on_host_pressed() -> void:
	var nm = get_node_or_null("/root/NetworkManager")
	if nm:
		nm.host_game()
	else:
		if _status_lbl:
			_status_lbl.text = "Fejl: NetworkManager ikke fundet."
			
func _refresh_panels() -> void:
	var active: bool = false
	var is_host: bool = false
	var peers: Dictionary = {}
	
	if NetworkManager:
		active = NetworkManager.get("is_active") == true
		is_host = NetworkManager.get("is_host") == true
		var p = NetworkManager.get("peers")
		if p is Dictionary:
			peers = p

	if _setup_panel:
		_setup_panel.visible = not active
	if _lobby_panel:
		_lobby_panel.visible = active
		
	if _invite_btn:
		_invite_btn.visible = active and is_host
	if _start_btn:
		_start_btn.visible = active and is_host
		
	_on_roster_updated(peers)


func _on_status_changed(text: String) -> void:
	if _status_lbl: _status_lbl.text = text
	_refresh_panels()


func _on_session_ended(reason: String) -> void:
	if _status_lbl: _status_lbl.text = reason
	_refresh_panels()


func _on_roster_updated(peers: Dictionary) -> void:
	if not _roster_box: return
	for child in _roster_box.get_children():
		child.queue_free()
		
	var active: bool = false
	if NetworkManager:
		active = NetworkManager.get("is_active") == true
		
	if not active:
		return
		
	if peers.is_empty():
		var lbl = Label.new()
		lbl.text = "  (bare deg så langt)"
		_roster_box.add_child(lbl)
		return
		
	for peer_id in peers:
		var info: Dictionary = peers[peer_id]
		var lbl = Label.new()
		var suffix = " (vert)" if peer_id == 1 else ""
		lbl.text = "  • %s%s" % [str(info.get("name", "?")), suffix]
		_roster_box.add_child(lbl)