extends RigidBody3D

@export var damage: float = 34.0
@export var splash_radius: float = 1.5
@export var spin_speed: float = 14.0

const SPAWN_GRACE_MS: int = 300

var _has_hit: bool = false
var _armed: bool = false
var _spawned_at_ms: int = 0
var _visual: Node3D


func _ready() -> void :
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)
	_visual = get_node_or_null("kefir kart") as Node3D
	if _visual == null and get_child_count() > 0:
		for child in get_children():
			if child is Node3D and not child is CollisionShape3D:
				_visual = child as Node3D
				break
	set_physics_process(true)
	_spawn_lifetime_timer()


func setup_throw(spawn_pos: Vector3, velocity: Vector3) -> void :
	global_position = spawn_pos
	_spawned_at_ms = Time.get_ticks_msec()
	_armed = true
	sleeping = false
	linear_velocity = velocity
	angular_velocity = Vector3.ZERO


func _physics_process(delta: float) -> void :
	if _has_hit or _visual == null:
		return
	_visual.rotate_object_local(Vector3(1.0, 0.35, 0.2).normalized(), spin_speed * delta)


func _spawn_lifetime_timer() -> void :
	await get_tree().create_timer(5.0).timeout
	if is_instance_valid(self):
		queue_free()


func _in_spawn_grace() -> bool:
	return Time.get_ticks_msec() - _spawned_at_ms < SPAWN_GRACE_MS


func _should_ignore_body(body: Node3D) -> bool:
	if body == self:
		return true
	if body.is_in_group("Gorgon"):
		return true
	var node: Node = body
	while node != null:
		if node.is_in_group("Gorgon"):
			return true
		node = node.get_parent()
	return false


func _on_body_entered(body: Node3D) -> void :
	if not _armed or _has_hit:
		return
	if _should_ignore_body(body):
		return
	if _in_spawn_grace() and not body.is_in_group("PlayerCharacter"):
		return
	_has_hit = true
	_splash()
	if body.is_in_group("PlayerCharacter"):
		_hit_player(body)
	queue_free()


func _hit_player(player: Node3D) -> void :
	var health: Node = player.get_node_or_null("HealthComponent")
	if health != null and health.has_method("take_damage"):
		health.take_damage(damage)


func _splash() -> void :
	var particles: = GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 48
	particles.lifetime = 1.0
	var quad: = QuadMesh.new()
	quad.size = Vector2(0.28, 0.28)
	particles.draw_pass_1 = quad
	var mat: = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 3.5
	mat.initial_velocity_max = 8.0
	mat.scale_min = 0.2
	mat.scale_max = 0.45
	mat.color = Color(1, 1, 1, 0.92)
	particles.process_material = mat
	get_tree().root.add_child(particles)
	particles.global_position = global_position
	var cleanup_timer: = get_tree().create_timer(1.2)
	cleanup_timer.timeout.connect( func() -> void :
		if is_instance_valid(particles):
			particles.queue_free()
	)
