extends Area3D

var _player_nearby: bool = false


func _ready() -> void :
	add_to_group("KidDrawing")
	monitoring = true
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	var label: = get_node_or_null("Label3D") as Label3D
	if label:
		label.visible = false


func _on_body_entered(body: Node3D) -> void :
	if body.is_in_group("PlayerCharacter"):
		_player_nearby = true
		var label: = get_node_or_null("Label3D") as Label3D
		if label:
			label.visible = true


func _on_body_exited(body: Node3D) -> void :
	if body.is_in_group("PlayerCharacter"):
		_player_nearby = false
		var label: = get_node_or_null("Label3D") as Label3D
		if label:
			label.visible = false


func _unhandled_input(event: InputEvent) -> void :
	if not _player_nearby:
		return
	if not event.is_action_pressed("interaction"):
		return
	_pick_up()
	get_viewport().set_input_as_handled()


func _pick_up() -> void :
	GameManager.kid_drawing_taken = true
	GameManager.set_objective_hint(
		"HVERDAGSKOMIKER", "collect_kobber", "Snakk med strømmasta"
	)
	var mast: Node = get_tree().get_first_node_in_group("Strommast")
	if mast != null and mast.has_method("on_drawing_removed"):
		mast.on_drawing_removed()
	queue_free()
