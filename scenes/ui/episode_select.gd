extends Control

signal play_requested(episode: int)
signal back_pressed

const EP1_THUMB: Texture2D = preload("res://assets/textures/map_background.png")

const EPISODES: = [
	{"num": 1, "title": "EPISODE 1", "subtitle": "Eg vil ha to is"}, 
	{"num": 2, "title": "EPISODE 2", "subtitle": "TBA"}, 
]

const CARD_SIZE: = Vector2(190, 220)
const THUMB_SIZE: = Vector2(170, 110)

var _selected: int = 1
var _cards: Dictionary = {}
var _play_btn: Button
var _status_lbl: Label


func _ready() -> void :
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func open() -> void :
	_select(1)
	visible = true

	if _play_btn:
		_play_btn.grab_focus.call_deferred()


func _build_ui() -> void :
	var dimmer: = ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.55)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dimmer)

	var center: = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel: = PanelContainer.new()
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
	title.text = "VELG EPISODE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var cards_row: = HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 16)
	vbox.add_child(cards_row)
	for ep in EPISODES:
		var card: = _make_card(ep)
		cards_row.add_child(card)
		_cards[int(ep.num)] = card

	_status_lbl = Label.new()
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.custom_minimum_size = Vector2(0, 18)
	_status_lbl.add_theme_color_override("font_color", Color(0.75, 0.62, 0.4))
	vbox.add_child(_status_lbl)

	var buttons: = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	vbox.add_child(buttons)

	var back: = Button.new()
	back.text = "Tilbake"
	back.pressed.connect( func() -> void : back_pressed.emit())
	buttons.add_child(back)

	_play_btn = Button.new()
	_play_btn.text = "SPILL"
	_play_btn.custom_minimum_size = Vector2(100, 0)
	_play_btn.pressed.connect( func() -> void : play_requested.emit(_selected))
	buttons.add_child(_play_btn)


func _make_card(ep: Dictionary) -> PanelContainer:
	var card: = PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	card.gui_input.connect( func(event: InputEvent) -> void :
		var mb: = event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_select(int(ep.num))
	)

	var vbox: = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	if int(ep.num) == 1:
		var thumb: = TextureRect.new()
		thumb.texture = EP1_THUMB
		thumb.custom_minimum_size = THUMB_SIZE
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		vbox.add_child(thumb)
	else:
		var unknown: = Label.new()
		unknown.text = "?"
		unknown.custom_minimum_size = THUMB_SIZE
		unknown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		unknown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		unknown.add_theme_font_size_override("font_size", 64)
		unknown.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
		vbox.add_child(unknown)

	var ep_title: = Label.new()
	ep_title.text = str(ep.title)
	ep_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(ep_title)

	var subtitle: = Label.new()
	subtitle.text = str(ep.subtitle)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(subtitle)

	return card


func _select(num: int) -> void :
	_selected = num
	for n in _cards:
		var card: = _cards[n] as Control
		card.modulate = Color.WHITE if int(n) == num else Color(0.55, 0.55, 0.55)
	var unlocked: bool = GameManager != null and GameManager.is_episode_unlocked(num)
	_play_btn.disabled = not unlocked
	_status_lbl.text = "" if unlocked else "Ikke tilgjengelig ennå"
