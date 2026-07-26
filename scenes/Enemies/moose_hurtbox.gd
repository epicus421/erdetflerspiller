extends Area3D








func _ready() -> void :
	add_to_group("Enemies")


func hitscanHit(damage: float, dir: Vector3, pos: Vector3) -> void :
	var parent: = get_parent()
	if parent != null and parent.has_method("hitscanHit"):
		parent.hitscanHit(damage, dir, pos)


func projectileHit(damage: float, dir: Vector3) -> void :
	var parent: = get_parent()
	if parent != null and parent.has_method("projectileHit"):
		parent.projectileHit(damage, dir)
