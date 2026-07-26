extends Area3D

var _stoepsel: Node3D = null


func _ready() -> void :
	monitoring = true
	collision_mask = 3
	body_entered.connect(_on_body_entered)
	await get_tree().process_frame
	var s: Node = get_tree().get_first_node_in_group("StoepselProp")
	if s is Node3D:
		_stoepsel = s as Node3D


func _on_body_entered(body: Node3D) -> void :
	if _stoepsel == null or not is_instance_valid(_stoepsel):
		return
	var is_stoepsel: bool = body == _stoepsel
	var is_player_with_stoepsel: bool = (
		body.is_in_group("PlayerCharacter")
		and body.has_method("get_carried_object")
		and body.get_carried_object() == _stoepsel
	)
	if not is_stoepsel and not is_player_with_stoepsel:
		return
	if is_player_with_stoepsel:
		if _stoepsel.has_method("force_drop"):
			_stoepsel.force_drop()
		else:
			var player: Node = body
			if player.has_method("_drop_carried_object"):
				player._drop_carried_object()
	if _stoepsel.has_method("reset_to_start"):
		_stoepsel.reset_to_start()
	elif _stoepsel is RigidBody3D:
		var rb: = _stoepsel as RigidBody3D
		rb.global_position = _stoepsel.get_meta("start_position", rb.global_position)
		rb.linear_velocity = Vector3.ZERO
		rb.angular_velocity = Vector3.ZERO
