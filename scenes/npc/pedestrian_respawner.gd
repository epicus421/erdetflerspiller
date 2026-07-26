extends Node3D








@export var pedestrian_scene: PackedScene

@export var max_count: int = 8

@export var respawn_interval: float = 15.0

@export var spawn_radius: float = 22.0


@export var min_player_distance: float = 30.0

const SPAWN_ATTEMPTS: int = 8

var _pedestrians: Array = []
var _timer: float = 0.0


func _ready() -> void :
	if pedestrian_scene == null:
		push_warning("[PedestrianRespawner] Mangler pedestrian_scene — deaktivert.")
		set_process(false)
		return

	_fill_initial.call_deferred()


func _fill_initial() -> void :
	await get_tree().physics_frame
	await get_tree().physics_frame
	for i in max_count:
		_spawn(true)


func _process(delta: float) -> void :
	_timer += delta
	if _timer < respawn_interval:
		return
	_timer = 0.0
	_prune()
	if _pedestrians.size() < max_count:
		_spawn(false)



func _prune() -> void :
	var alive: Array = []
	for p in _pedestrians:
		if is_instance_valid(p):
			alive.append(p)
	_pedestrians = alive


func _spawn(initial: bool) -> void :
	var map: RID = get_world_3d().navigation_map
	var point: = Vector3.ZERO
	var found: = false
	for attempt in SPAWN_ATTEMPTS:
		var angle: = randf() * TAU
		var r: = randf_range(spawn_radius * 0.25, spawn_radius)
		var sample: = global_position + Vector3(cos(angle) * r, 0.0, sin(angle) * r)
		var nav_point: = NavigationServer3D.map_get_closest_point(map, sample)

		if not initial:
			var player: = NetUtil.get_local_player() as Node3D
			if player != null\
			and nav_point.distance_to(player.global_position) < min_player_distance:
				continue
		point = nav_point
		found = true
		break
	if not found:
		return
	var ped: = pedestrian_scene.instantiate() as Node3D
	if ped == null:
		return
	add_child(ped)
	ped.global_position = point
	_pedestrians.append(ped)
