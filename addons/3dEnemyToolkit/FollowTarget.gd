extends NavigationAgent3D
class_name FollowTarget3D

signal ReachedTarget(target: Node3D)

@export var Speed: float = 5.0
@export var TurnSpeed: float = 0.3
@export var ReachTargetMinDistance: float = 1.3
@export var RetargetDistance: float = 1.0

var target: Node3D
var isTargetSet: bool = false
var targetPosition: Vector3 = Vector3.ZERO
var lastTargetPosition: Vector3 = Vector3.ZERO
var fixedTarget: bool = false

var _parent: CharacterBody3D


func _ready() -> void :
	_parent = get_parent() as CharacterBody3D
	avoidance_enabled = false
	call_deferred("_sync_navigation_start")


func _sync_navigation_start() -> void :
	sync_to_parent()



func tick_movement() -> void :
	if _parent == null:
		return
	if fixedTarget:
		go_to_location(targetPosition)
	elif target != null and is_instance_valid(target):
		go_to_location(target.global_position)
		if _parent.global_position.distance_to(target.global_position) <= ReachTargetMinDistance:
			ReachedTarget.emit(target)


func sync_to_parent() -> void :
	if _parent == null:
		return
	target_position = _parent.global_position


func SetFixedTarget(newTarget: Vector3) -> void :
	target = null
	targetPosition = newTarget
	fixedTarget = true
	isTargetSet = true
	lastTargetPosition = Vector3.ZERO
	sync_to_parent()


func SetTarget(newTarget: Node3D) -> void :
	target = newTarget
	targetPosition = Vector3.ZERO
	fixedTarget = false
	isTargetSet = true
	lastTargetPosition = Vector3.ZERO
	sync_to_parent()


func ClearTarget() -> void :
	target = null
	targetPosition = Vector3.ZERO
	isTargetSet = false
	fixedTarget = false
	lastTargetPosition = Vector3.ZERO


func go_to_location(new_target_position: Vector3) -> void :
	if _parent == null:
		return

	var current_position: Vector3 = _parent.global_position
	var flat_goal: = Vector3(new_target_position.x, current_position.y, new_target_position.z)
	var to_goal: Vector3 = flat_goal - current_position
	to_goal.y = 0.0

	if to_goal.length_squared() <= 0.25:
		_parent.velocity.x = 0.0
		_parent.velocity.z = 0.0
		return

	if not isTargetSet or lastTargetPosition.distance_squared_to(new_target_position) > RetargetDistance * RetargetDistance:
		sync_to_parent()
		set_target_position(new_target_position)
		lastTargetPosition = new_target_position
		isTargetSet = true

	var move_dir: Vector3 = to_goal.normalized()
	if not is_navigation_finished():
		var next_path_position: Vector3 = get_next_path_position()
		var to_next: Vector3 = next_path_position - current_position
		to_next.y = 0.0
		if to_next.length_squared() > 0.01:
			move_dir = to_next.normalized()

	_parent.velocity.x = move_dir.x * Speed
	_parent.velocity.z = move_dir.z * Speed
	var look_dir: float = atan2( - move_dir.x, - move_dir.z)
	_parent.rotation.y = lerp_angle(_parent.rotation.y, look_dir, TurnSpeed)
