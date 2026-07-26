extends Control

const PORTRAIT_BRUSH: = 2.0
const SIG_BRUSH: = 1.5

@onready var surname_label: Label = $CardBackground / MarginContainer / VBox / Body / Fields / SurnameLabel
@onready var given_name_label: Label = $CardBackground / MarginContainer / VBox / Body / Fields / GivenNameLabel
@onready var sex_label: Label = $CardBackground / MarginContainer / VBox / Body / Fields / SexLabel
@onready var dob_label: Label = $CardBackground / MarginContainer / VBox / Body / Fields / DOBHeightRow / DOBBox / DOBLabel
@onready var height_label: Label = $CardBackground / MarginContainer / VBox / Body / Fields / DOBHeightRow / HeightBox / HeightLabel
@onready var photo_rect: Control = $CardBackground / MarginContainer / VBox / Body / PhotoContainer / PhotoRect
@onready var sig_rect: Control = $CardBackground / MarginContainer / VBox / Body / Fields / SignatureRect
@onready var close_button: Button = $CloseButton

func _ready() -> void :
	var data: Dictionary = GameManager.id_card_data
	if data.is_empty():
		return

	surname_label.text = str(data.get("surname", ""))
	given_name_label.text = str(data.get("first_name", "")).to_upper()
	sex_label.text = str(data.get("sex", "M"))
	dob_label.text = str(data.get("dob", ""))
	height_label.text = str(data.get("height", ""))

	photo_rect.draw.connect(_on_photo_draw)
	photo_rect.queue_redraw()

	sig_rect.draw.connect(_on_sig_draw)
	sig_rect.queue_redraw()

	close_button.pressed.connect( func(): queue_free())

func _on_photo_draw() -> void :
	var data: Dictionary = GameManager.id_card_data
	var points: Array = data.get("portrait_points", [])
	var breaks: Array = data.get("portrait_breaks", [])
	var src_size: Vector2 = data.get("portrait_size", Vector2(140, 120))
	_draw_scaled(photo_rect, points, breaks, src_size, PORTRAIT_BRUSH)

func _on_sig_draw() -> void :
	var data: Dictionary = GameManager.id_card_data
	var points: Array = data.get("sig_points", [])
	var breaks: Array = data.get("sig_breaks", [])
	var src_size: Vector2 = data.get("sig_size", Vector2(200, 40))
	_draw_scaled(sig_rect, points, breaks, src_size, SIG_BRUSH)

func _draw_scaled(canvas: Control, points: Array, breaks: Array, src_size: Vector2, width: float) -> void :
	var dst_size: = canvas.size
	canvas.draw_rect(Rect2(Vector2.ZERO, dst_size), Color.WHITE, true)
	if points.size() < 2:
		return
	var scale_x: = dst_size.x / maxf(src_size.x, 1.0)
	var scale_y: = dst_size.y / maxf(src_size.y, 1.0)
	for i in range(1, points.size()):
		if breaks.has(i):
			continue
		var p0: Vector2 = points[i - 1]
		var p1: Vector2 = points[i]
		canvas.draw_line(
			Vector2(p0.x * scale_x, p0.y * scale_y), 
			Vector2(p1.x * scale_x, p1.y * scale_y), 
			Color.BLACK, 
			width
		)
