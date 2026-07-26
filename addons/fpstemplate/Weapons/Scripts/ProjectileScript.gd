extends RigidBody3D




var isExplosive: bool = false
var direction: Vector3
var damage: float
var timeBeforeVanish: float
var explosionRadius: float = 6.0
var excluded_rids: Array[RID] = []
var bodiesList: Array = []
var shooter: Node = null


@onready var mesh = $Mesh
@onready var hitbox = $Hitbox

@export_group("Sound variables")
@onready var audioManager: PackedScene = preload("../../Misc/Scenes/AudioManagerScene.tscn")
@export var explosionSound: AudioStream

@export_group("Particles variables")
@onready var particlesManager: PackedScene = preload("../../Misc/Scenes/ParticlesManagerScene.tscn")

func _ready() -> void :
	_fix_uniform_scale()
	gravity_scale = 0.0
	if explosionRadius <= 0.0:
		explosionRadius = 6.0


func setup_spawn_collision_exceptions() -> void :
	if is_instance_valid(shooter):
		_add_collision_exceptions_for_node(shooter)
	for player in get_tree().get_nodes_in_group("PlayerCharacter"):
		if is_instance_valid(player):
			_add_collision_exceptions_for_node(player)
	var scene_root: = get_tree().current_scene
	if scene_root != null:
		_add_interaction_area_exceptions(scene_root)
	for npc in get_tree().get_nodes_in_group("NPC"):
		if not is_instance_valid(npc):
			continue
		var fallback: = npc.get_node_or_null("Area3D") as CollisionObject3D
		if fallback != null and fallback.name != "HitboxCollision":
			add_collision_exception_with(fallback)


func _add_interaction_area_exceptions(node: Node) -> void :
	if node is Area3D and node.name == "InteractionArea":
		add_collision_exception_with(node)
	for child in node.get_children():
		_add_interaction_area_exceptions(child)


func _add_collision_exceptions_for_node(node: Node) -> void :
	if node == null:
		return
	if node is CollisionObject3D:
		add_collision_exception_with(node)
	for child in node.get_children():
		_add_collision_exceptions_for_node(child)

func _fix_uniform_scale():
	if scale.x != scale.y or scale.x != scale.z or scale.y != scale.z:
		var uniformScale = (scale.x + scale.y + scale.z) / 3.0
		scale = Vector3(uniformScale, uniformScale, uniformScale)
		if mesh and mesh is MeshInstance3D:
			mesh.scale = Vector3(0.29, 0.29, 0.25)

func _process(delta):
	if timeBeforeVanish > 0.0:
		timeBeforeVanish -= delta
	else:
		hit()

func _on_body_entered(body: Node) -> void :
	if _should_ignore_body(body):
		return
	if not hitbox.disabled:
		hit()
		applyDamage(body)


func _should_ignore_body(body: Node) -> bool:
	if body == null:
		return true
	if body is Area3D and body.name != "HitboxCollision":
		return true
	if _should_pass_through(body):
		return true
	if _is_shooter_body(body):
		return true
	if body is CollisionObject3D:
		var body_rid: RID = (body as CollisionObject3D).get_rid()
		if excluded_rids.has(body_rid):
			return true
	return false


func _is_shooter_body(body: Node) -> bool:
	if not is_instance_valid(shooter):
		return false
	var node: Node = body
	while node:
		if node == shooter:
			return true
		node = node.get_parent()
	return false


func _should_pass_through(body: Node) -> bool:
	if body == null or not body is Area3D:
		return false
	if body.name == "InteractionArea":
		return true
	var parent: = body.get_parent()
	if parent != null and parent.is_in_group("NPC") and body.name != "HitboxCollision":
		return true
	return false

func hit():
	mesh.visible = false
	hitbox.set_deferred("disabled", true)

	if isExplosive:
		explode()
	else:
		queue_free()

func applyDamage(body: Node, damage_scale: float = 1.0) -> void :
	if body == null or body in bodiesList:
		return
	if is_instance_valid(shooter):
		if body == shooter:
			return
		if body.is_in_group("PlayerCharacter") and shooter.is_in_group("PlayerCharacter"):
			return
	if body.is_in_group("StoryNPC"):
		return
	var dmg: float = damage * damage_scale
	var dealt: = false
	if body.is_in_group("Enemies") and body.has_method("projectileHit"):
		bodiesList.append(body)
		body.projectileHit(dmg, direction)
		dealt = true
	elif body.is_in_group("HitableObjects") and body.has_method("projectileHit"):
		bodiesList.append(body)
		body.projectileHit(dmg, direction)
		dealt = true
	elif body.is_in_group("PlayerCharacter"):
		bodiesList.append(body)
		var hc: Node = body.get_node_or_null("HealthComponent")
		if hc and hc.has_method("take_damage"):
			if is_instance_valid(shooter) and shooter.is_in_group("PlayerCharacter"):
				GameManager.last_death_cause = "self_rpg"
			elif is_instance_valid(shooter) and (shooter.name.to_lower().contains("moose") or shooter.name.to_lower().contains("elg")):
				GameManager.last_death_cause = "moose_rpg"
			else:
				GameManager.last_death_cause = "explosion"
			hc.take_damage(dmg)
		dealt = true
	elif GameManager != null and GameManager.apply_weapon_damage_to_npc_collider(body, dmg):
		bodiesList.append(body)
		dealt = true
	if not dealt:
		return


func explode() -> void :
	weaponSoundManagement(explosionSound)

	var particlesIns = particlesManager.instantiate()
	particlesIns.particleToEmit = "Explosion"
	particlesIns.global_transform = global_transform
	get_tree().get_root().add_child(particlesIns)

	if hitbox != null:
		hitbox.disabled = true
	collision_layer = 0
	collision_mask = 0

	var exp_center: Vector3 = global_transform.origin
	var exp_radius: float = explosionRadius
	if exp_radius <= 0.0:
		exp_radius = 6.0
	_apply_explosion_damage_safe(exp_center, exp_radius)
	queue_free()


func _apply_explosion_damage(center: Vector3) -> void :
	var radius: float = explosionRadius
	if radius <= 0.0:
		radius = 6.0
	_apply_explosion_damage_safe(center, radius)


func _apply_explosion_damage_safe(center: Vector3, radius: float) -> void :
	if radius <= 0.0:
		radius = 6.0
	var bodies: Array = []
	var seen: Dictionary = {}
	for group_name in ["Enemies", "NPC", "HitableObjects"]:
		for node in get_tree().get_nodes_in_group(group_name):
			var id: int = node.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true
			bodies.append(node)
	for player in NetUtil.get_all_players():
		if player != null and not seen.has(player.get_instance_id()):
			bodies.append(player)
	for body in bodies:
		if not is_instance_valid(body):
			continue
		if not body is Node3D:
			continue
		if body is CollisionObject3D:
			var body_rid: RID = (body as CollisionObject3D).get_rid()
			if excluded_rids.has(body_rid):
				continue
		var dist: float = center.distance_to((body as Node3D).global_position)
		if dist > radius:
			continue
		var falloff: float = clampf(1.0 - dist / radius, 0.15, 1.0)
		applyDamage(body as Node, falloff)


func weaponSoundManagement(soundName):
	if soundName != null:
		var audioIns = audioManager.instantiate()
		audioIns.global_transform = global_transform
		get_tree().get_root().add_child(audioIns)
		audioIns.bus = "Sfx"
		audioIns.volume_db = 0.0
		audioIns.stream = soundName
		audioIns.play()
