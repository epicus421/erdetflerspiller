extends Node3D







@export var bus_scene: PackedScene
@export var pedestrian_scene: PackedScene

@export var spawn_marker: Node3D
@export var stop_marker: Node3D
@export var exit_marker: Node3D

@export_category("Tid")
@export var min_interval: float = 60.0
@export var max_interval: float = 180.0
@export var drive_in_time: float = 4.0

@export var stop_dwell: float = 1.0

@export var drop_interval: float = 0.6
@export var drive_out_time: float = 4.0

@export var spawn_scatter: float = 2.0


const BUS_DAMAGE: float = 40.0



const HONK_COOLDOWN: float = 1.2

const STUCK_GRACE: float = 12.0
var _last_honk: float = -999.0
const BUS_KNOCK_FORCE: float = 12.0
const BUS_KNOCK_UP: float = 4.0

var _dead_count: int = 0
var _timer: float = 0.0
var _next: float = 0.0
var _bus_active: bool = false


func _ready() -> void :
	_next = randf_range(min_interval, max_interval)
	if GameManager != null and GameManager.has_signal("pedestrian_died"):
		GameManager.pedestrian_died.connect(_on_pedestrian_died)


	if spawn_marker == null or stop_marker == null or exit_marker == null:
		push_warning("[BussSystem] En eller flere markører mangler i inspektøren.")
	elif stop_marker == exit_marker\
	or stop_marker.global_position.distance_to(exit_marker.global_position) < 1.0:
		push_warning("[BussSystem] Stop- og Exit-markøren er samme punkt — bussen "
			+ "får ingen avkjørsel. Lag en egen Stop-markør ute i gata, atskilt "
			+ "fra Exit.")
	elif spawn_marker.global_position.distance_to(stop_marker.global_position) < 1.0:
		push_warning("[BussSystem] Spawn- og Stop-markøren er samme punkt — "
			+ "bussen kjører ikke inn.")


func _on_pedestrian_died() -> void :
	_dead_count += 1


func _process(delta: float) -> void :
	if _bus_active:
		return
	_timer += delta
	if _timer < _next:
		return
	_timer = 0.0
	_next = randf_range(min_interval, max_interval)

	if _dead_count > 0:
		_dispatch_bus()


func _dispatch_bus() -> void :
	if bus_scene == null or spawn_marker == null or stop_marker == null\
	or exit_marker == null:
		push_warning("[BussSystem] Mangler buss_scene eller markør — hopper over.")
		return
	_bus_active = true
	var count: = _dead_count
	_dead_count = 0

	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		scene_root = get_tree().root
	var bus: = bus_scene.instantiate() as Node3D
	scene_root.add_child(bus)
	bus.global_position = spawn_marker.global_position
	_face(bus, stop_marker.global_position)
	_add_run_over_area(bus)
	_add_honk_area(bus)

	var max_life: = drive_in_time + stop_dwell + drop_interval * float(count)\
	+ drive_out_time + STUCK_GRACE
	_bus_watchdog(bus, max_life)


	await _drive_to(bus, stop_marker.global_position, drive_in_time)

	if is_instance_valid(bus):
		_play_bus_node(bus, "TireSquealSfx")



	if is_instance_valid(bus):
		await get_tree().create_timer(stop_dwell).timeout
	if is_instance_valid(bus):
		await _drop_pedestrians(bus, count)


	if is_instance_valid(bus):
		_face(bus, exit_marker.global_position)
		await _drive_to(bus, exit_marker.global_position, drive_out_time)
		if is_instance_valid(bus):
			bus.queue_free()

	_bus_active = false





func _drive_to(bus: Node3D, target: Vector3, seconds: float) -> void :
	if not is_instance_valid(bus):
		return
	var start: = bus.global_position
	var t: = 0.0
	while t < seconds and is_instance_valid(bus):
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		bus.global_position = start.lerp(target, clampf(t / seconds, 0.0, 1.0))
	if is_instance_valid(bus):
		bus.global_position = target


func _drop_pedestrians(bus: Node3D, count: int) -> void :
	if pedestrian_scene == null:
		return
	var drop: Node3D = bus.get_node_or_null("PedestrianSpawner") as Node3D
	var origin: Vector3 = drop.global_position if drop != null else bus.global_position
	var map: RID = get_world_3d().navigation_map
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		scene_root = get_tree().root
	for i in count:
		if not is_instance_valid(bus):
			return

		var drop_now: Node3D = bus.get_node_or_null("PedestrianSpawner") as Node3D
		var here: Vector3 = drop_now.global_position if drop_now != null else origin
		var sample: = here + Vector3(
			randf_range( - spawn_scatter, spawn_scatter), 0.0, 
			randf_range( - spawn_scatter, spawn_scatter)
		)
		var point: = NavigationServer3D.map_get_closest_point(map, sample)
		var ped: = pedestrian_scene.instantiate() as Node3D
		if ped != null:
			scene_root.add_child(ped)
			ped.global_position = point

		await get_tree().create_timer(drop_interval).timeout






func _play_bus_node(bus: Node3D, node_name: String) -> void :
	if bus == null or not is_instance_valid(bus):
		return
	var p: = bus.get_node_or_null(node_name) as AudioStreamPlayer3D
	if p != null:
		p.play()



func _add_honk_area(bus: Node3D) -> void :
	var area: = Area3D.new()
	area.name = "HonkArea"
	area.collision_layer = 0
	area.set_collision_mask_value(2, true)
	area.set_collision_mask_value(6, true)
	area.monitoring = true
	var cs: = CollisionShape3D.new()
	var box: = BoxShape3D.new()
	box.size = Vector3(3.5, 2.5, 7.0)
	cs.shape = box
	cs.position = Vector3(0.0, 1.0, -5.5)
	area.add_child(cs)
	bus.add_child(area)
	area.body_entered.connect(_on_honk_body.bind(bus))


func _on_honk_body(body: Node3D, bus: Node3D) -> void :
	if body == null or not is_instance_valid(body) or not is_instance_valid(bus):
		return
	if not (body.is_in_group("PlayerCharacter") or body.is_in_group("Pedestrian")):
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_honk < HONK_COOLDOWN:
		return
	_last_honk = now
	_play_bus_node(bus, "HonkSfx")



func _bus_watchdog(bus: Node3D, seconds: float) -> void :
	await get_tree().create_timer(seconds).timeout
	if is_instance_valid(bus):
		bus.queue_free()
	_bus_active = false






func _add_run_over_area(bus: Node3D) -> void :
	var area: = Area3D.new()
	area.name = "RunOverArea"
	area.collision_layer = 0
	area.set_collision_mask_value(2, true)
	area.set_collision_mask_value(6, true)
	area.monitoring = true
	var cs: = CollisionShape3D.new()
	var body_cs: = bus.get_node_or_null("CollisionShape3D2") as CollisionShape3D
	if body_cs != null and body_cs.shape != null:
		cs.shape = body_cs.shape
		cs.transform = body_cs.transform
	else:
		var box: = BoxShape3D.new()
		box.size = Vector3(3.0, 2.5, 9.0)
		cs.shape = box
	area.add_child(cs)
	bus.add_child(area)
	area.body_entered.connect(_on_bus_hit.bind(bus))


func _on_bus_hit(body: Node3D, bus: Node3D) -> void :
	if body == null or not is_instance_valid(body) or not is_instance_valid(bus):
		return

	var away: = body.global_position - bus.global_position
	away.y = 0.0
	var dir: = away.normalized() if away.length() > 0.2 else bus.global_transform.basis.x
	if body.is_in_group("PlayerCharacter"):
		_hit_player(body, dir)
	elif body.is_in_group("Pedestrian") and body.has_method("hit_by_bus"):
		body.hit_by_bus(BUS_DAMAGE, dir)


func _hit_player(player: Node3D, dir: Vector3) -> void :
	var hc: Node = player.get_node_or_null("HealthComponent")
	if hc != null and hc.has_method("take_damage"):

		hc.take_damage(BUS_DAMAGE)
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = dir * BUS_KNOCK_FORCE + Vector3.UP * BUS_KNOCK_UP



func _face(node: Node3D, target: Vector3) -> void :
	var flat: = Vector3(target.x, node.global_position.y, target.z)
	if flat.distance_to(node.global_position) > 0.05:
		node.look_at(flat, Vector3.UP)
