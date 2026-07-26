extends CanvasLayer

@onready var black_overlay: ColorRect = $BlackOverlay
@onready var line1: Label = $Line1
@onready var line2: Label = $Line2


func _ready() -> void :
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	black_overlay.modulate.a = 0.0
	line1.visible = false
	line1.modulate.a = 0.0
	line2.visible = false
	line2.modulate.a = 0.0
	_run_bad_ending()


func _run_bad_ending() -> void :
	var tween: = create_tween()
	tween.tween_property(black_overlay, "modulate:a", 1.0, 2.0)
	await tween.finished

	line1.visible = true
	line1.modulate.a = 0.0
	var t2: = create_tween()
	t2.tween_property(line1, "modulate:a", 1.0, 1.5)
	await t2.finished
	await get_tree().create_timer(2.0).timeout

	line2.visible = true
	line2.modulate.a = 0.0
	var t3: = create_tween()
	t3.tween_property(line2, "modulate:a", 1.0, 1.5)
	await t3.finished
	await get_tree().create_timer(3.0).timeout

	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
