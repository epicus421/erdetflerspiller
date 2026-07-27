extends Control

signal back_pressed

const Appearance := preload("res://multiplayer/player_appearance.gd")

## The game renders at a 640x480 design resolution (see project.godot
## display/window/size), so every control here is deliberately small and the
## whole panel sits in a ScrollContainer — a 4-player lobby is taller than
## 480px and would otherwise have its buttons clipped off the bottom.
const PANEL_WIDTH: int = 330
const ROW_HEIGHT: int = 32
const ACCENT: Color = Color(1.0, 0.85, 0.3)
const MUTED: Color = Color(0.62, 0.62, 0.62)

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
var _profile_panel: Control
var _name_field: LineEdit
var _character_lbl: Label
var _lobby_code_field: LineEdit
var _lobby_code_row: Control

var _preview_viewport: SubViewport = null
var _preview_pivot: Node3D = null
var _preview_character_id: int = -1

var _character_id: int = 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()

	# Connected defensively so a partially-loaded NetworkManager can never
	# crash the title screen.
	if NetworkManager:
		if NetworkManager.has_signal("status_changed"):
			NetworkManager.status_changed.connect(_on_status_changed)
		if NetworkManager.has_signal("roster_updated"):
			NetworkManager.roster_updated.connect(_on_roster_signal)
		if NetworkManager.has_signal("session_started"):
			NetworkManager.session_started.connect(_refresh_panels)
		if NetworkManager.has_signal("session_ended"):
			NetworkManager.session_ended.connect(_on_session_ended)
		if NetworkManager.has_signal("join_failed"):
			NetworkManager.join_failed.connect(_on_status_changed)
		if NetworkManager.has_signal("host_ready"):
			NetworkManager.host_ready.connect(_on_host_ready)

	_load_profile_into_ui()
	_refresh_panels()


func open() -> void:
	show()
	_load_profile_into_ui()
	_refresh_panels()
	if _name_field:
		_name_field.grab_focus.call_deferred()


func show_status(text: String) -> void:
	show()
	if _status_lbl:
		_status_lbl.text = text
	_refresh_panels()


func _load_profile_into_ui() -> void:
	if NetworkManager == null:
		return
	if _name_field and _name_field.text.strip_edges().is_empty():
		_name_field.text = NetworkManager.get_suggested_name()
	_character_id = Appearance.normalize_id(int(NetworkManager.local_character_id))
	_update_character_label()


# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	var dimmer := ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.70)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dimmer)

	var outer := MarginContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", 8)
	outer.add_theme_constant_override("margin_top", 8)
	outer.add_theme_constant_override("margin_right", 8)
	outer.add_theme_constant_override("margin_bottom", 8)
	add_child(outer)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	# HBox with centre alignment does the horizontal centring a CenterContainer
	# would, but without fighting the ScrollContainer over vertical sizing.
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(row)

	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "FLERSPILLER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", ACCENT)
	vbox.add_child(title)

	_status_lbl = Label.new()
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_lbl.add_theme_color_override("font_color", Color(0.8, 0.65, 0.45))
	vbox.add_child(_status_lbl)

	_build_profile_panel(vbox)
	_build_setup_panel(vbox)
	_build_lobby_panel(vbox)

	var back := Button.new()
	back.text = "Tilbake"
	back.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	back.pressed.connect(_on_back_pressed)
	vbox.add_child(back)


## Name + character live above both the setup and lobby panels: you pick who
## you are BEFORE hosting or joining (the original menu had no name entry at
## all, so everyone showed up as the default "Sokrates"), and you can still
## change it while sitting in the lobby.
func _build_profile_panel(parent: VBoxContainer) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	parent.add_child(box)
	_profile_panel = box

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)

	var fields := VBoxContainer.new()
	fields.add_theme_constant_override("separation", 8)
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(fields)

	var name_lbl := Label.new()
	name_lbl.text = "Navnet ditt"
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", MUTED)
	fields.add_child(name_lbl)

	_name_field = LineEdit.new()
	_name_field.placeholder_text = "Navn"
	_name_field.max_length = NetworkManager.NAME_MAX_LENGTH
	_name_field.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	_name_field.text_changed.connect(_on_name_changed)
	fields.add_child(_name_field)

	var char_lbl := Label.new()
	char_lbl.text = "Figur"
	char_lbl.add_theme_font_size_override("font_size", 13)
	char_lbl.add_theme_color_override("font_color", MUTED)
	fields.add_child(char_lbl)

	var char_row := HBoxContainer.new()
	char_row.add_theme_constant_override("separation", 6)
	fields.add_child(char_row)

	var prev := Button.new()
	prev.text = "◀"
	prev.custom_minimum_size = Vector2(34, ROW_HEIGHT)
	prev.pressed.connect(func() -> void: _cycle_character(-1))
	char_row.add_child(prev)

	_character_lbl = Label.new()
	_character_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_character_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_character_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	char_row.add_child(_character_lbl)

	var next := Button.new()
	next.text = "▶"
	next.custom_minimum_size = Vector2(34, ROW_HEIGHT)
	next.pressed.connect(func() -> void: _cycle_character(1))
	char_row.add_child(next)

	_build_character_preview(row)


## A live 3D preview matters more here than in most games: this is a
## first-person game, so you will never once see your own body in play.
func _build_character_preview(parent: HBoxContainer) -> void:
	var frame := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.06, 0.05, 1.0)
	style.border_color = Color(0.35, 0.3, 0.2)
	style.set_border_width_all(1)
	frame.add_theme_stylebox_override("panel", style)
	parent.add_child(frame)

	var container := SubViewportContainer.new()
	container.stretch = true
	container.custom_minimum_size = Vector2(92, 118)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(container)

	var vp := SubViewport.new()
	vp.size = Vector2i(92, 118)
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(vp)
	_preview_viewport = vp

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.06, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 1.1
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	vp.add_child(world_env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 145, 0)
	light.light_energy = 1.2
	vp.add_child(light)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.0, 2.35)
	cam.fov = 45.0
	cam.current = true
	vp.add_child(cam)

	_preview_pivot = Node3D.new()
	# Feet on the "floor" of the preview: the models are centred on their own
	# origin by _refresh_preview, so lifting the pivot half a body puts them
	# upright in frame.
	_preview_pivot.position = Vector3(0, 0.98, 0)
	vp.add_child(_preview_pivot)


func _build_setup_panel(parent: VBoxContainer) -> void:
	var panel_vbox := VBoxContainer.new()
	panel_vbox.add_theme_constant_override("separation", 8)
	parent.add_child(panel_vbox)
	_setup_panel = panel_vbox

	_host_btn = Button.new()
	_host_btn.text = "VÆR VERT"
	_host_btn.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	_host_btn.pressed.connect(_on_host_pressed)
	panel_vbox.add_child(_host_btn)

	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 8)
	panel_vbox.add_child(join_row)

	_lobby_id_field = LineEdit.new()
	_lobby_id_field.placeholder_text = "Lobby-ID"
	_lobby_id_field.custom_minimum_size = Vector2(150, ROW_HEIGHT)
	_lobby_id_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lobby_id_field.text_submitted.connect(func(_t: String) -> void: _on_join_pressed())
	join_row.add_child(_lobby_id_field)

	_join_btn = Button.new()
	_join_btn.text = "BLI MED"
	_join_btn.custom_minimum_size = Vector2(84, ROW_HEIGHT)
	_join_btn.pressed.connect(_on_join_pressed)
	join_row.add_child(_join_btn)

	var hint := Label.new()
	hint.text = "Tips: du kan også bli med ved å ta imot en invitasjon i Steam — spillet åpner denne menyen automatisk."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", MUTED)
	panel_vbox.add_child(hint)


func _build_lobby_panel(parent: VBoxContainer) -> void:
	var panel_vbox := VBoxContainer.new()
	panel_vbox.add_theme_constant_override("separation", 8)
	panel_vbox.hide()
	parent.add_child(panel_vbox)
	_lobby_panel = panel_vbox

	var code_col := VBoxContainer.new()
	code_col.add_theme_constant_override("separation", 4)
	panel_vbox.add_child(code_col)
	_lobby_code_row = code_col

	var code_lbl := Label.new()
	code_lbl.text = "Lobby-ID (del denne)"
	code_lbl.add_theme_font_size_override("font_size", 13)
	code_lbl.add_theme_color_override("font_color", MUTED)
	code_col.add_child(code_lbl)

	var code_row := HBoxContainer.new()
	code_row.add_theme_constant_override("separation", 8)
	code_col.add_child(code_row)

	_lobby_code_field = LineEdit.new()
	_lobby_code_field.editable = false
	_lobby_code_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lobby_code_field.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	code_row.add_child(_lobby_code_field)

	var copy_btn := Button.new()
	copy_btn.text = "KOPIER"
	copy_btn.custom_minimum_size = Vector2(76, ROW_HEIGHT)
	copy_btn.pressed.connect(_on_copy_lobby_id)
	code_row.add_child(copy_btn)

	var roster_title := Label.new()
	roster_title.text = "Spillere:"
	panel_vbox.add_child(roster_title)

	_roster_box = VBoxContainer.new()
	panel_vbox.add_child(_roster_box)

	_invite_btn = Button.new()
	_invite_btn.text = "INVITER VENN (STEAM)"
	_invite_btn.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	_invite_btn.pressed.connect(func() -> void:
		if NetworkManager: NetworkManager.invite_friends()
	)
	panel_vbox.add_child(_invite_btn)

	_start_btn = Button.new()
	_start_btn.text = "START SPILLET"
	_start_btn.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	_start_btn.pressed.connect(_on_start_pressed)
	panel_vbox.add_child(_start_btn)

	_leave_btn = Button.new()
	_leave_btn.text = "FORLAT LOBBY"
	_leave_btn.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	_leave_btn.pressed.connect(func() -> void:
		if NetworkManager: NetworkManager.leave()
	)
	panel_vbox.add_child(_leave_btn)


# ---------------------------------------------------------------------------
# Profile editing
# ---------------------------------------------------------------------------

func _cycle_character(delta: int) -> void:
	_character_id = Appearance.normalize_id(_character_id + delta)
	_update_character_label()
	# Publish immediately when already in a lobby so the roster (and everyone
	# else's view of your body) updates live.
	if NetworkManager and NetworkManager.is_active:
		_commit_profile()


func _update_character_label() -> void:
	if _character_lbl:
		_character_lbl.text = "%s  (%d/%d)" % [
			Appearance.get_display_name(_character_id),
			Appearance.normalize_id(_character_id) + 1,
			Appearance.count(),
		]
	_refresh_preview()


func _refresh_preview() -> void:
	if _preview_pivot == null or not is_instance_valid(_preview_pivot):
		return
	if _preview_character_id == _character_id:
		return
	_preview_character_id = _character_id

	for child in _preview_pivot.get_children():
		child.queue_free()

	var scene: PackedScene = Appearance.get_scene(_character_id)
	if scene == null:
		return
	var instance: Node3D = scene.instantiate() as Node3D
	if instance == null:
		return
	_preview_pivot.add_child(instance)

	var mesh: MeshInstance3D = _find_mesh(instance)
	if mesh == null:
		return
	var aabb: AABB = mesh.get_aabb()
	if aabb.size.y <= 0.0:
		return
	# Same normalisation the in-game avatar uses, so what you pick here is
	# exactly what the other players see.
	var factor: float = 1.95 / aabb.size.y
	instance.scale = Vector3(factor, factor, factor)
	instance.position = Vector3(
		-(aabb.position.x + aabb.size.x * 0.5) * factor,
		-(aabb.position.y + aabb.size.y * 0.5) * factor,
		-(aabb.position.z + aabb.size.z * 0.5) * factor
	)


func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found: MeshInstance3D = _find_mesh(child)
		if found != null:
			return found
	return null


func _process(delta: float) -> void:
	if _preview_pivot != null and is_instance_valid(_preview_pivot) and visible:
		_preview_pivot.rotate_y(delta * 0.6)


func _on_name_changed(_new_text: String) -> void:
	if _status_lbl and _status_lbl.text.begins_with("Navnet"):
		_status_lbl.text = ""


## Returns false (and shows why) when the name is rejected, so hosting and
## joining both refuse to start with a nameless player.
func _commit_profile() -> bool:
	if NetworkManager == null:
		return false
	var error: String = NetworkManager.set_local_profile(
		_name_field.text if _name_field else "",
		_character_id
	)
	if error != "":
		if _status_lbl:
			_status_lbl.text = error
		if _name_field:
			_name_field.grab_focus()
		return false
	# Show the cleaned-up version back to the player.
	if _name_field:
		_name_field.text = NetworkManager.local_player_name
	_character_id = NetworkManager.local_character_id
	_update_character_label()
	return true


# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

func _on_host_pressed() -> void:
	if not _commit_profile():
		return
	if NetworkManager == null:
		if _status_lbl:
			_status_lbl.text = "Feil: NetworkManager ikke funnet."
		return
	NetworkManager.host_game()


func _on_join_pressed() -> void:
	if _lobby_id_field == null:
		return
	var text: String = _lobby_id_field.text.strip_edges()
	if not text.is_valid_int():
		if _status_lbl:
			_status_lbl.text = "Skriv inn en gyldig lobby-ID."
		return
	if not _commit_profile():
		return
	if NetworkManager:
		NetworkManager.join_lobby(int(text))


func _on_start_pressed() -> void:
	if NetworkManager == null:
		return
	if NetworkManager.peers.size() < 2:
		if _status_lbl:
			_status_lbl.text = "Ingen har blitt med ennå — inviter en venn først."
		return
	NetworkManager.start_game()


func _on_copy_lobby_id() -> void:
	if NetworkManager == null or NetworkManager.lobby_id == 0:
		return
	DisplayServer.clipboard_set(str(NetworkManager.lobby_id))
	if _status_lbl:
		_status_lbl.text = "Lobby-ID kopiert."


func _on_back_pressed() -> void:
	if NetworkManager and NetworkManager.is_active:
		NetworkManager.leave()
	back_pressed.emit()


# ---------------------------------------------------------------------------
# State refresh
# ---------------------------------------------------------------------------

func _on_host_ready(id: int) -> void:
	if _lobby_code_field:
		_lobby_code_field.text = str(id)
	_refresh_panels()


func _refresh_panels() -> void:
	var active: bool = false
	var is_host: bool = false
	var peers: Dictionary = {}

	if NetworkManager:
		active = NetworkManager.is_active
		is_host = NetworkManager.is_host
		peers = NetworkManager.peers
		if _lobby_code_field:
			_lobby_code_field.text = str(NetworkManager.lobby_id) if NetworkManager.lobby_id != 0 else "…"

	if _setup_panel:
		_setup_panel.visible = not active
	if _lobby_panel:
		_lobby_panel.visible = active
	if _lobby_code_row:
		_lobby_code_row.visible = active
	if _invite_btn:
		_invite_btn.visible = active and is_host
	if _start_btn:
		_start_btn.visible = active and is_host

	_update_start_button(peers)
	_on_roster_updated(peers)


## Separate from _refresh_panels so the roster signal can update the START
## button too — a peer leaving broadcasts a new roster but no status message,
## and START would otherwise stay enabled with nobody left to play with.
func _update_start_button(peers: Dictionary) -> void:
	if _start_btn:
		_start_btn.disabled = peers.size() < 2


func _on_roster_signal(peers: Dictionary) -> void:
	_update_start_button(peers)
	_on_roster_updated(peers)


func _on_status_changed(text: String) -> void:
	if _status_lbl:
		_status_lbl.text = text
	_refresh_panels()


func _on_session_ended(reason: String) -> void:
	if _status_lbl:
		_status_lbl.text = reason
	_refresh_panels()


func _on_roster_updated(peers: Dictionary) -> void:
	if _roster_box == null:
		return
	for child in _roster_box.get_children():
		_roster_box.remove_child(child)
		child.queue_free()

	if NetworkManager == null or not NetworkManager.is_active:
		return

	if peers.is_empty():
		var lbl := Label.new()
		lbl.text = "  (bare deg så langt)"
		lbl.add_theme_color_override("font_color", MUTED)
		_roster_box.add_child(lbl)
		return

	for peer_id in peers:
		var info: Dictionary = peers[peer_id]
		var lbl := Label.new()
		var tags: Array[String] = []
		if int(peer_id) == 1:
			tags.append("vert")
		if int(peer_id) == NetworkManager.local_peer_id:
			tags.append("deg")
		var suffix: String = ""
		if not tags.is_empty():
			suffix = " (%s)" % ", ".join(tags)
		lbl.text = "  • %s%s — %s" % [
			str(info.get("name", "?")),
			suffix,
			Appearance.get_display_name(int(info.get("character", 0))),
		]
		if int(peer_id) == NetworkManager.local_peer_id:
			lbl.add_theme_color_override("font_color", ACCENT)
		_roster_box.add_child(lbl)
