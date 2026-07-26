extends Area3D

var _player_nearby: bool = false


func _ready() -> void :
	monitoring = true
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)
	body_entered.connect(
		func(b: Node3D):
			if b.is_in_group("PlayerCharacter"):
				_player_nearby = true
				$Label3D.visible = true)
	body_exited.connect(
		func(b: Node3D):
			if b.is_in_group("PlayerCharacter"):
				_player_nearby = false
				$Label3D.visible = false)


func _unhandled_input(event: InputEvent) -> void :
	if not _player_nearby:
		return
	if not Input.is_action_just_pressed("interaction"):
		return
	var radio: Node = get_tree().get_first_node_in_group("Radio")
	if radio != null and radio.has_method("adjust_volume"):
		radio.adjust_volume()
