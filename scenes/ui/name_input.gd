extends CanvasLayer

@export var bestefar_voice: AudioStream

@onready var name_input: LineEdit = $Panel / NameInput
@onready var confirm_btn: Button = $Panel / ConfirmButton
@onready var error_label: Label = $Panel / ErrorLabel
@onready var audio: AudioStreamPlayer = $Panel / BestefarstemmeAudio

func _ready() -> void :
	layer = 20
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if bestefar_voice != null:
		audio.stream = bestefar_voice
	if audio.stream:
		audio.play()
	confirm_btn.pressed.connect(_on_confirm)
	name_input.text_submitted.connect( func(_t: String) -> void : _on_confirm())
	name_input.text_changed.connect(_on_name_changed)
	name_input.grab_focus()
	if error_label:
		error_label.visible = false


func _on_name_changed(_new_text: String) -> void :
	if error_label and error_label.visible:
		error_label.visible = false




func _normalize_name(raw: String) -> String:
	var cleaned: = ""
	for c in raw.strip_edges():
		if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z")\
		or (c >= "0" and c <= "9") or c == "-" or c in "æøåÆØÅ":
			cleaned += c
	if cleaned.is_empty():
		return ""
	return cleaned[0].to_upper() + cleaned.substr(1)


func _show_error(message: String) -> void :
	if error_label:
		error_label.text = message
		error_label.visible = true
	name_input.grab_focus()


func _on_confirm() -> void :
	if name_input.text.strip_edges().contains(" "):
		_show_error("Ingen mellomrom — bruk bindestrek (-) for dobbeltnavn.")
		return

	var player_name: String = _normalize_name(name_input.text)

	if player_name.length() < 2:
		_show_error("Navnet må være minst 2 bokstaver.")
		return

	if player_name.length() > 20:
		player_name = player_name.substr(0, 20)

	GameManager.player_name = player_name

	var tween: = create_tween()
	var overlay: = ColorRect.new()
	overlay.color = Color.BLACK
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Panel.add_child(overlay)
	overlay.modulate.a = 0.0
	tween.tween_property(overlay, "modulate:a", 1.0, 0.8)
	await tween.finished
	get_tree().change_scene_to_file("res://scenes/ui/loading_screen.tscn")
