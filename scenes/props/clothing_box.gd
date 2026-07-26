extends RigidBody3D

var _delivered: bool = false


func _ready() -> void :
	if not is_in_group("ClothingBox"):
		add_to_group("ClothingBox")
	if not is_in_group("Carriable"):
		add_to_group("Carriable")
	mass = 5.0
	CarriablePickup.register(self)


func is_delivered() -> bool:
	return _delivered


func mark_delivered() -> void :
	if _delivered:
		return
	_delivered = true
	freeze = true
	collision_layer = 0
	collision_mask = 0


func on_picked_up() -> void :
	pass


func on_dropped() -> void :
	pass
