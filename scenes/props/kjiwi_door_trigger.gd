extends Area3D

@export var store_interior_direction: Vector3 = Vector3(0, 0, -1)

signal player_entered_store
signal player_exited_store

var _player_inside: bool = false


func _ready() -> void :
	add_to_group("KjiwiDoorTrigger")
	monitoring = true
	collision_mask = 3
	body_exited.connect(_on_body_exited)


func _on_body_exited(body: Node3D) -> void :
	if not body.is_in_group("PlayerCharacter"):
		return
	var to_player: = body.global_position - global_position
	to_player.y = 0.0
	if to_player.length_squared() < 0.001:
		return
	var dot: = to_player.normalized().dot(store_interior_direction.normalized())
	if dot > 0.0:
		if not _player_inside:
			_player_inside = true
			player_entered_store.emit()
	else:
		if _player_inside:
			_player_inside = false
			player_exited_store.emit()
