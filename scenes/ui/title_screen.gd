extends Node3D

@onready var title_text: Node3D = $TitleText
@onready var subtitle_text: Label3D = $TitleText / SubtitleText / Label3D
@onready var menu_ui: CanvasLayer = $MenuUI
@onready var play_btn: Button = $MenuUI / VBoxContainer / PlayButton
@onready var exit_btn: Button = $MenuUI / VBoxContainer / ExitButton
@onready var settings_btn: Button = $MenuUI / VBoxContainer / SettingsButton
@onready var credits_btn: Button = $MenuUI / VBoxContainer / CreditsButton
@onready var settings_overlay: Control = $MenuUI / SettingsOverlay
@onready var settings_panel: Control = $MenuUI / SettingsOverlay / SettingsPanel
@onready var settings_back_btn: Button = $MenuUI / SettingsOverlay / BackButton
@onready var credits_panel: Control = $MenuUI / CreditsPanel
@onready var time_label: Label = $MenuUI / TimeLabel
@onready var extras_btn: Button = $MenuUI / VBoxContainer / ExtrasButton
@onready var menu_buttons: VBoxContainer = $MenuUI / VBoxContainer
@onready var multiplayer_btn: Button = $MenuUI / VBoxContainer / MultiplayerButton

const EPISODE_SELECT_SCENE: PackedScene = preload("res://scenes/ui/episode_select.tscn")
const EXTRAS_MENU_SCENE: PackedScene = preload("res://scenes/ui/extras_menu.tscn")
const MULTIPLAYER_MENU_SCENE: PackedScene = preload("res://scenes/ui/multiplayer_menu.tscn")

var episode_select
var extras_menu
var multiplayer_menu

const DROP_TIME_SECONDS: float = 10.0
const FLY_IN_DURATION: float = DROP_TIME_SECONDS
const HOVER_DISTANCE: float = 0.3
const HOVER_SPEED: float = 0.5

var _hover_time: float = 0.0
var _title_done: bool = false
var _title_rest_pos: Vector3 = Vector3(0, 1, 0)

var _intro_skipped: bool = false
var _eye_canvas: CanvasLayer = null
var _title_tween: Tween = null


var _warning_active: bool = false
var _warning_skip: bool = false

func _ready() -> void :
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	menu_ui.visible = false
	title_text.position = Vector3(0, -8, -20)
	title_text.rotation_degrees.x = 35.0
	title_text.scale = Vector3(0.1, 0.1, 0.1)
	subtitle_text.position = Vector3(0, 0.2, 0.8)
	subtitle_text.modulate.a = 0.0

	play_btn.pressed.connect(_on_play)
	exit_btn.pressed.connect(get_tree().quit)
	settings_btn.pressed.connect(_on_settings)
	settings_back_btn.pressed.connect(_on_settings_back)
	credits_btn.pressed.connect(_show_credits)
	credits_panel.back_pressed.connect(_hide_credits)
	extras_btn.pressed.connect(_on_extras)
	multiplayer_btn.pressed.connect(_on_multiplayer)

	episode_select = EPISODE_SELECT_SCENE.instantiate()
	episode_select.visible = false
	menu_ui.add_child(episode_select)
	episode_select.play_requested.connect(_on_episode_play)
	episode_select.back_pressed.connect(_on_episode_back)

	extras_menu = EXTRAS_MENU_SCENE.instantiate()
	extras_menu.visible = false
	menu_ui.add_child(extras_menu)
	extras_menu.back_pressed.connect( func() -> void :
		extras_menu.visible = false
		_set_frontpage_visible(true)
		if play_btn:
			play_btn.grab_focus.call_deferred()
	)

	multiplayer_menu = MULTIPLAYER_MENU_SCENE.instantiate()
	multiplayer_menu.visible = false
	menu_ui.add_child(multiplayer_menu)
	multiplayer_menu.back_pressed.connect( func() -> void :
		multiplayer_menu.visible = false
		_set_frontpage_visible(true)
		if play_btn:
			play_btn.grab_focus.call_deferred()
	)

	_style_menu_buttons()
	_build_supporter_ad()

	if settings_overlay:
		settings_overlay.visible = false
	credits_panel.visible = false
	if settings_panel and settings_panel.has_method("refresh_from_game_manager"):
		settings_panel.refresh_from_game_manager()
	_update_time_label()

	if NetworkManager.pending_disconnect_message != "":
		var msg: String = NetworkManager.pending_disconnect_message
		NetworkManager.pending_disconnect_message = ""
		MusicManager.play("title")
		_skip_title_intro()
		_on_multiplayer()
		if multiplayer_menu.has_method("show_status"):
			multiplayer_menu.show_status(msg)
		return

	await _show_health_warning()
	MusicManager.play("title")
	await _play_eye_open()
	_animate_title_in()


func _show_credits() -> void :
	credits_panel.visible = true
	var back: Button = credits_panel.get_node_or_null("BackButton") as Button
	if back:
		back.grab_focus.call_deferred()


func _hide_credits() -> void :
	credits_panel.visible = false
	if play_btn:
		play_btn.grab_focus.call_deferred()

func _update_time_label() -> void :
	if time_label == null or GameManager == null:
		return
	if GameManager.last_playthrough_time > 0.0:
		time_label.text = _format_time(GameManager.last_playthrough_time)
		time_label.visible = true
	else:
		time_label.visible = false

func _format_time(seconds: float) -> String:
	var m: int = int(seconds) / 60
	var s: int = int(seconds) % 60
	return "Sist: %02d:%02d" % [m, s]




const WARNING_MIN_VISIBLE: float = 1.5
const WARNING_AUTO_DISMISS: float = 8.0

func _show_health_warning() -> void :
	var canvas: = CanvasLayer.new()
	canvas.layer = 200
	add_child(canvas)

	var root: = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.modulate.a = 0.0
	canvas.add_child(root)

	var bg: = ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var margin: = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	root.add_child(margin)

	var box: = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	margin.add_child(box)

	var heading: = Label.new()
	heading.text = "ADVARSEL"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 30)
	heading.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	box.add_child(heading)

	var body: = Label.new()
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_constant_override("line_spacing", 6)
	body.text = (
		"Spillet inneholder blinkende lys og intense lyder som kan utløse "
		+ "epileptiske anfall hos et lite antall mennesker.\n\n"
		+ "Har du epilepsi eller hjerteproblemer, spill med forsiktighet. "
		+ "Stopp umiddelbart om du blir uvel."
	)
	box.add_child(body)

	var hint: = Label.new()
	hint.text = "Trykk en tast eller knapp for å fortsette"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	hint.modulate.a = 0.0
	box.add_child(hint)

	_warning_active = true
	_warning_skip = false
	var fade_in: = create_tween()
	fade_in.tween_property(root, "modulate:a", 1.0, 0.4)

	var t: = 0.0
	while t < WARNING_AUTO_DISMISS:
		await get_tree().process_frame
		t += get_process_delta_time()
		if t >= WARNING_MIN_VISIBLE:
			hint.modulate.a = 1.0
			if _warning_skip:
				break

	_warning_active = false
	var fade_out: = create_tween()
	fade_out.tween_property(root, "modulate:a", 0.0, 0.4)
	await fade_out.finished
	canvas.queue_free()


func _play_eye_open() -> void :
	_eye_canvas = CanvasLayer.new()
	_eye_canvas.layer = 100
	add_child(_eye_canvas)

	var vp: = get_viewport().get_visible_rect().size

	var top: = ColorRect.new()
	top.color = Color.BLACK
	top.size = Vector2(vp.x, vp.y * 0.5)
	top.position = Vector2.ZERO
	_eye_canvas.add_child(top)

	var bot: = ColorRect.new()
	bot.color = Color.BLACK
	bot.size = Vector2(vp.x, vp.y * 0.5)
	bot.position = Vector2(0.0, vp.y * 0.5)
	_eye_canvas.add_child(bot)

	await get_tree().create_timer(0.3).timeout
	if _intro_skipped:

		if is_instance_valid(_eye_canvas):
			_eye_canvas.queue_free()
		_eye_canvas = null
		return

	var tween: = create_tween().set_parallel(true)
	tween.tween_property(top, "position:y", - vp.y * 0.5, 1.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(bot, "position:y", vp.y, 1.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween.finished
	if is_instance_valid(_eye_canvas):
		_eye_canvas.queue_free()
	_eye_canvas = null


func _animate_title_in() -> void :
	if _intro_skipped:
		return
	_title_tween = create_tween()
	_title_tween.set_parallel(true)
	_title_tween.tween_property(title_text, "position", _title_rest_pos, FLY_IN_DURATION).set_ease(Tween.EASE_OUT)
	_title_tween.tween_property(title_text, "rotation_degrees:x", 0.0, FLY_IN_DURATION).set_ease(Tween.EASE_OUT)
	_title_tween.tween_property(title_text, "scale", Vector3.ONE, FLY_IN_DURATION).set_ease(Tween.EASE_OUT)
	await _title_tween.finished
	if _intro_skipped:
		return
	_title_done = true

	if subtitle_text.text.strip_edges() != "":
		var fade: = create_tween()
		fade.set_parallel(true)
		fade.tween_property(subtitle_text, "modulate:a", 1.0, 1.0)
		await get_tree().create_timer(0.5).timeout
	else:
		subtitle_text.visible = false
		await get_tree().create_timer(0.5).timeout
	menu_ui.visible = true
	if play_btn:
		play_btn.grab_focus()



func _skip_title_intro() -> void :
	if _intro_skipped or _title_done or menu_ui.visible:
		return
	_intro_skipped = true
	if _title_tween != null and _title_tween.is_valid():
		_title_tween.kill()


	if is_instance_valid(_eye_canvas):
		_eye_canvas.visible = false
	title_text.position = _title_rest_pos
	title_text.rotation_degrees.x = 0.0
	title_text.scale = Vector3.ONE
	subtitle_text.modulate.a = 1.0 if subtitle_text.text.strip_edges() != "" else 0.0
	_title_done = true
	menu_ui.visible = true
	if play_btn:
		play_btn.grab_focus()

func _unhandled_input(event: InputEvent) -> void :


	if _warning_active:
		var pk: bool = event is InputEventKey and event.pressed and not event.echo
		var pc: bool = event is InputEventMouseButton and event.pressed
		var pj: bool = event is InputEventJoypadButton and event.pressed
		if pk or pc or pj:
			_warning_skip = true
			get_viewport().set_input_as_handled()
		return

	if not menu_ui.visible and not _intro_skipped:
		var pressed_key: bool = event is InputEventKey and event.pressed and not event.echo
		var pressed_click: bool = event is InputEventMouseButton and event.pressed
		var pressed_joy: bool = event is InputEventJoypadButton and event.pressed
		if pressed_key or pressed_click or pressed_joy:
			_skip_title_intro()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_cancel"):
		if episode_select and episode_select.visible:
			_on_episode_back()
			get_viewport().set_input_as_handled()
			return
		if extras_menu and extras_menu.visible:
			extras_menu.visible = false
			get_viewport().set_input_as_handled()
			return
		if multiplayer_menu and multiplayer_menu.visible:
			if NetworkManager.is_active:
				NetworkManager.leave()
			multiplayer_menu.visible = false
			_set_frontpage_visible(true)
			get_viewport().set_input_as_handled()
			return
		if credits_panel.visible:
			_hide_credits()
			get_viewport().set_input_as_handled()
			return
		if settings_overlay and settings_overlay.visible:
			_on_settings_back()
			get_viewport().set_input_as_handled()
			return
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void :
	if not _title_done:
		return
	_hover_time += delta * HOVER_SPEED
	title_text.position.y = _title_rest_pos.y + sin(_hover_time) * HOVER_DISTANCE



func _set_frontpage_visible(v: bool) -> void :
	title_text.visible = v
	menu_buttons.visible = v
	if _supporter_ad != null and is_instance_valid(_supporter_ad):
		_supporter_ad.visible = v
	if v:
		_update_time_label()
	elif time_label:
		time_label.visible = false


func _on_play() -> void :
	_set_frontpage_visible(false)
	episode_select.open()


func _on_episode_back() -> void :
	episode_select.visible = false
	_set_frontpage_visible(true)
	if play_btn:
		play_btn.grab_focus.call_deferred()


func _on_extras() -> void :

	_set_frontpage_visible(false)
	extras_menu.open()


func _on_multiplayer() -> void :
	_set_frontpage_visible(false)
	multiplayer_menu.open()


func _on_episode_play(_episode: int) -> void :
	episode_select.visible = false
	if GameManager and GameManager.has_method("reset_game"):
		GameManager.reset_game()
	var canvas: = CanvasLayer.new()
	canvas.layer = 99
	add_child(canvas)

	var overlay: = ColorRect.new()
	overlay.color = Color.BLACK
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.modulate.a = 0.0
	canvas.add_child(overlay)

	var tween: = create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, 1.0)
	await tween.finished
	get_tree().change_scene_to_file("res://scenes/ui/name_input.tscn")




func _style_menu_buttons() -> void :
	var focus_style: = StyleBoxFlat.new()
	focus_style.draw_center = false
	focus_style.border_color = Color(1.0, 0.85, 0.3)
	focus_style.border_width_bottom = 2
	var empty: = StyleBoxEmpty.new()
	for b: Button in [play_btn, multiplayer_btn, settings_btn, credits_btn, extras_btn, exit_btn]:
		if b == null:
			continue
		b.flat = true
		b.custom_minimum_size = Vector2(180, 30)
		b.add_theme_font_size_override("font_size", 18)
		b.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		b.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.3))
		b.add_theme_color_override("font_focus_color", Color(1.0, 0.85, 0.3))
		b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
		b.add_theme_stylebox_override("normal", empty)
		b.add_theme_stylebox_override("hover", empty)
		b.add_theme_stylebox_override("pressed", empty)
		b.add_theme_stylebox_override("focus", focus_style)





const BREAD_AD_TEX_PATH: = "res://assets/props/glb/bread_brod_mold.jpg"
var _supporter_ad: Button = null

func _build_supporter_ad() -> void :
	if GameManager != null and GameManager.has_method("has_supporter_dlc")\
	and GameManager.has_supporter_dlc():
		return

	var ad: = Button.new()
	ad.focus_mode = Control.FOCUS_NONE
	ad.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ad.offset_left = -164.0
	ad.offset_top = -118.0
	ad.offset_right = -12.0
	ad.offset_bottom = -12.0
	ad.pressed.connect( func() -> void :
		if GameManager != null and GameManager.has_method("open_supporter_store_page"):
			GameManager.open_supporter_store_page()
	)

	var style: = StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.07, 0.05, 0.92)
	style.border_color = Color(0.75, 0.6, 0.25)
	style.set_border_width_all(2)
	style.set_content_margin_all(8.0)
	ad.add_theme_stylebox_override("normal", style)
	var hover: = style.duplicate() as StyleBoxFlat
	hover.border_color = Color(1.0, 0.85, 0.35)
	ad.add_theme_stylebox_override("hover", hover)
	ad.add_theme_stylebox_override("pressed", hover)

	var box: = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 8.0
	box.offset_top = 6.0
	box.offset_right = -8.0
	box.offset_bottom = -6.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ad.add_child(box)

	var heading: = Label.new()
	heading.text = "STØTT SPILLET!"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 13)
	heading.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(heading)

	if ResourceLoader.exists(BREAD_AD_TEX_PATH):
		var img: = TextureRect.new()
		img.texture = load(BREAD_AD_TEX_PATH) as Texture2D
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		img.custom_minimum_size = Vector2(0, 44)
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(img)

	var body: = Label.new()
	body.text = "Supporter-pakke — 69 kr\nMuggen brødskive + håndtegn"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", 10)
	body.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(body)

	menu_ui.add_child(ad)
	_supporter_ad = ad


	menu_ui.move_child(ad, 0)


	var tw: = heading.create_tween().set_loops()
	tw.tween_property(heading, "modulate:a", 0.55, 0.9)
	tw.tween_property(heading, "modulate:a", 1.0, 0.9)


func _on_settings() -> void :

	_set_frontpage_visible(false)
	if settings_overlay:
		settings_overlay.visible = true
	if settings_panel and settings_panel.has_method("refresh_from_game_manager"):
		settings_panel.refresh_from_game_manager()
	if settings_back_btn:
		settings_back_btn.grab_focus()

func _on_settings_back() -> void :
	if settings_overlay:
		settings_overlay.visible = false
	_set_frontpage_visible(true)

	if play_btn:
		play_btn.grab_focus.call_deferred()
