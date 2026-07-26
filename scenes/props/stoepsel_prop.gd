extends RigidBody3D





@export var max_leash_distance: float = 22.0




@export var carry_hold_distance: float = 2.0

var _start_position: Vector3 = Vector3.ZERO
var _locked: bool = false


func _ready() -> void :
	mass = 2.0
	can_sleep = false
	_start_position = global_position
	CarriablePickup.register(self)
	add_to_group("StoepselProp")
	if MinigameManager:
		MinigameManager.register_stoepsel(self)


func _physics_process(_delta: float) -> void :
	if _locked:
		return

	if global_position.distance_to(_start_position) > max_leash_distance:
		reset_to_start()


func set_start_position(world_pos: Vector3) -> void :
	_start_position = world_pos


func lock_in_place() -> void :
	if _locked:
		return
	_locked = true
	remove_from_group("Carriable")
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	if has_node("InteractionArea"):
		var area: = $InteractionArea as Area3D
		area.monitoring = false
		area.monitorable = false
	set_process_input(false)
	set_physics_process(false)


func drop() -> void :
	force_drop()


func force_drop() -> void :
	if _locked:
		return
	var player: Node = NetUtil.get_local_player()
	if player != null and player.has_method("get_carried_object")\
	and player.get_carried_object() == self:
		if player.has_method("_drop_carried_object"):
			player._drop_carried_object()
	elif freeze:
		freeze = false
		CarriablePickup.restore_physics_after_drop(self)


func reset_to_start() -> void :
	if _locked:
		return
	force_drop()
	global_position = _start_position
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = false
