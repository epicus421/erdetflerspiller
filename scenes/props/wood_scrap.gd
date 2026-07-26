extends RigidBody3D

func _ready() -> void :
	if not is_in_group("Carriable"):
		add_to_group("Carriable")
	if not is_in_group("WoodScrap"):
		add_to_group("WoodScrap")
	CarriablePickup.register(self)


func on_picked_up() -> void :
	var tree: = get_tree()
	if tree == null:
		return
	for zone in tree.get_nodes_in_group("LemonadeBuildZone"):
		if zone and zone.has_method("activate_from_scrap_pickup"):
			zone.call("activate_from_scrap_pickup")
