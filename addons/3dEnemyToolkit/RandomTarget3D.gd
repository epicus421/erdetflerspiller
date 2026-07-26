extends Node3D
class_name RandomTarget3D

@export var MinRadius: float = 1.0
@export var MaxRadius: float = 10.0
@export var MaxAngleRange: int = -120
@export var MinAngleRange: int = 120

const MAX_ATTEMPTS: = 16
const NAV_MESH_SNAP_TOLERANCE: = 2.5

var target_arm: SpringArm3D
var target: Marker3D
var _rng: = RandomNumberGenerator.new()


func _ready() -> void :
	target_arm = SpringArm3D.new()
	target = Marker3D.new()
	target_arm.add_child(target)
	add_child(target_arm)
	_rng.seed = hash(get_path()) + get_instance_id()


func GetNextPoint() -> Vector3:
	var world: = get_world_3d()
	if world == null or not is_navigation_map_ready(world):
		return _sample_random_point()

	var map: RID = world.navigation_map
	var origin: = _get_patrol_origin()
	var origin_flat: = Vector2(origin.x, origin.z)

	for _attempt in MAX_ATTEMPTS:
		var sample: Vector3 = _sample_random_point()
		var nav_point: Vector3 = NavigationServer3D.map_get_closest_point(map, sample)
		if not _is_valid_nav_point(origin_flat, sample, nav_point):
			continue

		return Vector3(sample.x, nav_point.y, sample.z)

	return _sample_random_point()


func _get_patrol_origin() -> Vector3:
	var parent_node: = get_parent()
	if parent_node is Node3D:
		return (parent_node as Node3D).global_position
	return global_position


func _sample_random_point() -> Vector3:
	var angle: = deg_to_rad(_rng.randi_range(MinAngleRange, MaxAngleRange))
	var distance: = _rng.randf_range(MinRadius, MaxRadius)
	rotation.y = angle
	target_arm.spring_length = distance
	return target.global_position


func _is_valid_nav_point(origin_flat: Vector2, sample: Vector3, nav_point: Vector3) -> bool:
	var sample_flat: = Vector2(sample.x, sample.z)
	var nav_flat: = Vector2(nav_point.x, nav_point.z)
	if sample_flat.distance_to(nav_flat) > NAV_MESH_SNAP_TOLERANCE:
		return false
	var travel: = nav_flat.distance_to(origin_flat)
	if travel < MinRadius:
		return false
	if travel > MaxRadius + NAV_MESH_SNAP_TOLERANCE:
		return false
	return true


static func is_navigation_map_ready(world: World3D) -> bool:
	if world == null:
		return false
	var map: RID = world.navigation_map
	if map == RID():
		return false
	if not NavigationServer3D.map_is_active(map):
		return false
	return NavigationServer3D.map_get_iteration_id(map) > 0
