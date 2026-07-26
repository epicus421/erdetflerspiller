extends CanvasLayer



@onready var backdrop: ColorRect = $ColorRect
@onready var label: Label = $Label


func _ready() -> void :

	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	backdrop.color = Color(0, 0, 0, 0)
	label.text = ""


func run_sequence() -> void :
	visible = true
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw_in: = create_tween()
	tw_in.tween_property(backdrop, "color", Color(0, 0, 0, 1), 0.45)
	await tw_in.finished
	label.text = "Bestefar fikk 2 is."
	await get_tree().create_timer(2.0).timeout
	label.text = "Mormor ville vært stolt."
	await get_tree().create_timer(2.0).timeout
	var tw_out: = create_tween()
	tw_out.tween_property(backdrop, "color", Color(0, 0, 0, 0), 0.55)
	await tw_out.finished
	label.text = ""
	visible = false
	queue_free()
