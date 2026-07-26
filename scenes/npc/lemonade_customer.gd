extends CharacterBody3D

enum State{WALKING, WAITING, LEAVING}

@export var move_speed: float = 3.0
const GRAVITY: float = 9.8

var _state: int = State.WALKING
var _counter_pos: Vector3 = Vector3.ZERO
var _spawn_pos: Vector3 = Vector3.ZERO
var _stand_ref: Node = null
var _leave_dir: Vector3 = Vector3.ZERO
var _arrival_notified: bool = false


func setup(counter_pos: Vector3, stand: Node, spawn_pos: Vector3) -> void :
	_counter_pos = counter_pos
	_stand_ref = stand
	_spawn_pos = spawn_pos
	_arrival_notified = false
	var through: Vector3 = counter_pos - spawn_pos
	through.y = 0.0
	if through.length_squared() > 0.001:
		_leave_dir = through.normalized()
	else:
		_leave_dir = Vector3.FORWARD
	_state = State.WALKING


func leave() -> void :
	_state = State.LEAVING


func _physics_process(delta: float) -> void :
	match _state:
		State.WALKING:
			_walk_to_counter(delta)
		State.WAITING:
			velocity = Vector3.ZERO
			if not is_on_floor():
				velocity.y -= GRAVITY * delta
			move_and_slide()
		State.LEAVING:
			_walk_away(delta)


func _walk_to_counter(delta: float) -> void :
	var to_counter: Vector3 = _counter_pos - global_position
	to_counter.y = 0.0
	var dist: float = to_counter.length()
	if dist < 1.2:
		velocity = Vector3.ZERO
		_state = State.WAITING
		if _stand_ref is Node3D:
			var to_stand: Vector3 = (_stand_ref as Node3D).global_position - global_position
			to_stand.y = 0.0
			if to_stand.length() > 0.01:
				rotation.y = atan2( - to_stand.x, - to_stand.z)
		if not _arrival_notified and _stand_ref and _stand_ref.has_method("on_customer_arrived"):
			_arrival_notified = true
			_stand_ref.call("on_customer_arrived", self)
	else:
		var dir: Vector3 = to_counter.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		rotation.y = lerp_angle(rotation.y, atan2( - dir.x, - dir.z), 0.2)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	move_and_slide()


func _walk_away(delta: float) -> void :
	velocity.x = _leave_dir.x * move_speed
	velocity.z = _leave_dir.z * move_speed
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	rotation.y = lerp_angle(rotation.y, atan2( - _leave_dir.x, - _leave_dir.z), 0.2)
	if global_position.distance_to(_spawn_pos) > 30.0:
		queue_free()
