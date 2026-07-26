extends CharacterBody3D

enum States{
	Walking, 
	Pursuit, 
	Investigating, 
	Attacking, 
	Dead
}

enum AttackType{
	MELEE, 
	HITSCAN, 
	PROJECTILE
}

@export_category("Movement")
@export var walkSpeed: float = 2.0
@export var runSpeed: float = 5.0

@export var dodges_projectiles: bool = false

@export_category("Attack")
@export var attack_type: AttackType = AttackType.MELEE
@export var attack_range: float = 2.0
@export var attack_cooldown: float = 1.0

@export_category("Attack Ranges")
@export var melee_range: float = 2.0
@export var hitscan_range: float = 15.0
@export var projectile_range: float = 20.0

@export_category("Facing")
@export var facing_tolerance: float = 45.0
@export var detection_range: float = 20.0
@export var lose_sight_range: float = 24.0

@export var enemy_weapon: Resource


@export var melee_knockback: float = 5.0
@export var melee_damage: float = 10.0

@export_category("Ragdoll")
@export var ragdoll_force: float = 5.0
@export var ragdoll_torque: float = 10.0
@export var ragdoll_lifetime: float = 3.0
@export var drop_item_id: String = ""
@export var drop_item_amount: int = 1

@export_category("Audio")
@export var attack_sound: AudioStream
@export var death_sound: AudioStream
@export var hurt_sound: AudioStream

@onready var follow_target_3d: FollowTarget3D = $FollowTarget3D
@onready var random_target_3d: RandomTarget3D = $RandomTarget3D
@onready var health_component: HealthComponent = $HealthComponent
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var geometry_node: Node3D = get_node_or_null("Geometry") as Node3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
var weapon_slot: Node3D = null

var state: States = States.Walking
var target: Node3D
var can_attack: bool = true
var attack_timer: float = 0.0

var _is_flashing: bool = false
var _flash_originals: Array = []
var _flash_sprite_originals: Array = []
var _zigzag_timer: float = 0.0
var _zigzag_offset: Vector3 = Vector3.ZERO
var _dodge_vel: Vector3 = Vector3.ZERO
var _dodge_cd: float = 0.0
var _last_position: Vector3 = Vector3.ZERO
var _stuck_timer: float = 0.0
var _last_known_player_pos: Vector3 = Vector3.ZERO
var _has_last_known_pos: bool = false

var _is_alerted: bool = false
var _alert_timer: float = 0.0
const ALERT_SPEED_MULTIPLIER: float = 1.6
const ALERT_DURATION: float = 8.0

const STUCK_THRESHOLD: float = 0.2
const STUCK_TIME: float = 2.0
const LAST_KNOWN_ARRIVE_DIST: float = 2.5

func _ready() -> void :
	_last_position = global_position
	add_to_group("Enemies")
	weapon_slot = get_node_or_null("WeaponSlot") as Node3D
	ChangeState(States.Walking)
	if geometry_node == null:
		geometry_node = get_node_or_null("CrowGlbModel") as Node3D
	if geometry_node == null:
		for child in get_children():
			if child is Node3D and child != follow_target_3d and child != random_target_3d and child != collision_shape and child != weapon_slot:
				geometry_node = child as Node3D
				break
	if health_component:
		health_component.connect("on_death", _on_enemy_death)
		if not health_component.on_damage_taken.is_connected(_on_alert_triggered):
			health_component.on_damage_taken.connect(_on_alert_triggered)

	call_deferred("_bootstrap_navigation_agent")

	if dodges_projectiles and GameManager != null\
	and not GameManager.gunshot_fired.is_connected(_on_gunshot_dodge):
		GameManager.gunshot_fired.connect(_on_gunshot_dodge)

	var sfx: = AudioStreamPlayer3D.new()
	sfx.name = "SFX"
	sfx.max_distance = 20.0
	sfx.unit_size = 5.0
	add_child(sfx)

	if NetworkManager != null and NetworkManager.is_active:
		_setup_enemy_sync()


## Enemies are baked into the level (not spawned per-peer like players), so
## they default to multiplayer authority 1 — i.e. the host is always the one
## that should actually run their AI. Damage/heal already redirect to the
## right authority on their own (see components/health_component.gd); this
## is specifically about who simulates movement/targeting, so every client
## sees the same enemy in the same place instead of each running their own
## independent, diverging copy of the same AI.
func is_authority() -> bool:
	return NetworkManager == null or not NetworkManager.is_active or is_multiplayer_authority()


func _setup_enemy_sync() -> void:
	var config: SceneReplicationConfig = SceneReplicationConfig.new()
	var always_props: Array[String] = [".:position", ".:velocity", ".:rotation"]
	var on_change_props: Array[String] = [".:state"]
	for prop in always_props:
		var path: NodePath = NodePath(prop)
		config.add_property(path)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	for prop in on_change_props:
		var path: NodePath = NodePath(prop)
		config.add_property(path)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	var sync: MultiplayerSynchronizer = MultiplayerSynchronizer.new()
	sync.name = "EnemyNetSync"
	sync.replication_config = config
	add_child(sync)


func _process(delta: float) -> void :
	if state == States.Dead:
		return
	if not is_authority():
		return

	if not can_attack:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true



func _is_player_locked() -> bool:
	if DialogueUI and DialogueUI.is_open():
		return true
	if GameManager and GameManager.is_minigame_active():
		return true
	return false


func _physics_process(delta: float) -> void :
	if state == States.Dead:
		return
	if not is_authority():
		return


	if _is_player_locked():
		velocity = Vector3.ZERO
		return
	_process_alert(delta)
	if not is_on_floor():
		velocity += get_gravity() * delta

	_update_target_tracking()

	if attack_type == AttackType.PROJECTILE and target != null and is_instance_valid(target):
		var look_dir: Vector3 = target.global_position - global_position
		look_dir.y = 0.0
		if look_dir.length() > 0.1:
			var desired_y: float = atan2( - look_dir.x, - look_dir.z)
			var rot_speed: float = 0.4
			rotation.y = lerp_angle(rotation.y, desired_y, rot_speed)

	if state == States.Pursuit and target != null:
		var look_dir: = target.global_position - global_position
		look_dir.y = 0.0
		if look_dir.length() > 0.1:
			var desired_y: = atan2( - look_dir.x, - look_dir.z)
			rotation.y = lerp_angle(rotation.y, desired_y, 0.1)
		_zigzag_timer -= delta
		if _zigzag_timer <= 0.0:
			_zigzag_timer = randf_range(0.3, 0.8)
			var rand_angle: = randf_range(-0.6, 0.6)
			var forward: = Vector3(sin(rand_angle), 0.0, cos(rand_angle)).normalized()
			_zigzag_offset = forward * runSpeed * 0.4
		var lateral: = Vector3( - look_dir.z, 0.0, look_dir.x).normalized()
		velocity += lateral * _zigzag_offset.x
	elif state == States.Investigating:
		var investigate_dir: = _last_known_player_pos - global_position
		investigate_dir.y = 0.0
		if investigate_dir.length() > 0.1:
			var desired_y: = atan2( - investigate_dir.x, - investigate_dir.z)
			rotation.y = lerp_angle(rotation.y, desired_y, 0.1)
		_zigzag_timer = 0.0
		_zigzag_offset = Vector3.ZERO
	else:
		_zigzag_timer = 0.0
		_zigzag_offset = Vector3.ZERO

	if target and state != States.Attacking:
		var distance_to_target = global_position.distance_to(target.global_position)
		var current_attack_range = attack_range
		match attack_type:
			AttackType.MELEE:
				current_attack_range = melee_range
			AttackType.HITSCAN:
				current_attack_range = hitscan_range
			AttackType.PROJECTILE:
				current_attack_range = projectile_range

		if distance_to_target <= current_attack_range and can_attack and state != States.Attacking:
			ChangeState(States.Attacking)

	if state == States.Walking:
		var moved: float = global_position.distance_to(_last_position)
		if moved < STUCK_THRESHOLD:
			_stuck_timer += delta
			if _stuck_timer > STUCK_TIME:
				_stuck_timer = 0.0
				_pick_new_random_target()
		else:
			_stuck_timer = 0.0
		_last_position = global_position

	if state in [States.Walking, States.Pursuit, States.Investigating]:
		follow_target_3d.tick_movement()

	if attack_type == AttackType.PROJECTILE and target != null:
		var dist: float = global_position.distance_to(target.global_position)
		if dist < 8.0:
			var away: Vector3 = (global_position - target.global_position).normalized()
			away.y = 0.0
			if away.length_squared() > 0.01:
				velocity.x = away.x * runSpeed
				velocity.z = away.z * runSpeed

	if is_on_floor() and velocity.length() > 0.3:
		var move_dir: = Vector3(velocity.x, 0.0, velocity.z)
		if move_dir.length_squared() > 0.0001:
			move_dir = move_dir.normalized()
			var knee_origin: = global_position + Vector3(0.0, 0.15, 0.0)
			var knee_end: = knee_origin + move_dir * 0.4
			var sq: = PhysicsRayQueryParameters3D.create(knee_origin, knee_end)
			sq.exclude = [self]
			var hit: = get_world_3d().direct_space_state.intersect_ray(sq)
			if not hit.is_empty():
				var wall_normal: Vector3 = hit.get("normal", Vector3.UP)
				if wall_normal.y < 0.35:
					velocity.y = maxf(velocity.y, 3.5)

	if is_on_floor() and velocity.y < 0.0:
		velocity.y = 0.0

	if dodges_projectiles:
		_update_dodge(delta)

	move_and_slide()


func _update_dodge(delta: float) -> void :
	_dodge_cd = maxf(0.0, _dodge_cd - delta)

	if _dodge_cd <= 0.0 and state == States.Pursuit and target != null and is_instance_valid(target):
		var cam: = get_viewport().get_camera_3d() if get_viewport() != null else null
		if cam != null:
			var to_self: = global_position - cam.global_position
			to_self.y = 0.0
			if to_self.length() > 0.5:
				to_self = to_self.normalized()
				var cam_fwd: = - cam.global_transform.basis.z
				cam_fwd.y = 0.0
				if cam_fwd.length() > 0.01 and cam_fwd.normalized().dot(to_self) > 0.985:
					_start_dodge(to_self)
	if _dodge_vel.length_squared() > 0.01:
		velocity.x += _dodge_vel.x
		velocity.z += _dodge_vel.z
		_dodge_vel = _dodge_vel.lerp(Vector3.ZERO, clampf(delta * 6.0, 0.0, 1.0))


func _start_dodge(dir_from_player: Vector3) -> void :
	var lateral: = Vector3( - dir_from_player.z, 0.0, dir_from_player.x)
	if randf() < 0.5:
		lateral = - lateral
	if lateral.length_squared() < 0.001:
		return
	_dodge_vel = lateral.normalized() * runSpeed * 1.3
	_dodge_cd = randf_range(0.6, 1.1)


func _on_gunshot_dodge(pos: Vector3, _range: float) -> void :
	if not dodges_projectiles or state == States.Dead or _dodge_cd > 0.0:
		return
	if global_position.distance_to(pos) > 30.0:
		return
	var dir_from_player: = global_position - pos
	dir_from_player.y = 0.0
	if dir_from_player.length() < 0.5:
		dir_from_player = Vector3.FORWARD
	_start_dodge(dir_from_player.normalized())


func _update_target_tracking() -> void :
	var player: = NetUtil.get_nearest_player(global_position)

	if state == States.Investigating:
		if player != null:
			var distance_to_player: = global_position.distance_to(player.global_position)
			if distance_to_player <= detection_range:
				target = player
				_last_known_player_pos = player.global_position
				_has_last_known_pos = true
				ChangeState(States.Pursuit)
				return
		if _has_last_known_pos and follow_target_3d.is_navigation_finished()\
		and global_position.distance_to(_last_known_player_pos) <= LAST_KNOWN_ARRIVE_DIST:
			ChangeState(States.Walking)
		return

	if player == null:
		if state != States.Attacking:
			ChangeState(States.Walking)
		return

	if target != null and ( not is_instance_valid(target) or target == self):
		target = null

	if target == null:
		var distance_to_player: = global_position.distance_to(player.global_position)
		if distance_to_player <= detection_range:
			target = player
			_last_known_player_pos = player.global_position
			_has_last_known_pos = true
			ChangeState(States.Pursuit)
		return

	if target == player:
		_last_known_player_pos = player.global_position
		_has_last_known_pos = true
		var distance_to_player: = global_position.distance_to(player.global_position)
		if distance_to_player > lose_sight_range and state != States.Attacking:
			if _is_alerted:
				return
			target = null
			if _has_last_known_pos:
				ChangeState(States.Investigating)
			else:
				ChangeState(States.Walking)

func is_facing_target() -> bool:
	if not target:
		return false

	var target_direction = (target.global_position - global_position).normalized()
	var forward_direction = - global_transform.basis.z
	var angle = forward_direction.angle_to(target_direction)
	return rad_to_deg(angle) <= facing_tolerance

func ChangeState(newState: States) -> void :
	if state == States.Dead:
		return
	if state == newState:
		return

	state = newState
	match state:
		States.Walking:
			follow_target_3d.ClearTarget()
			follow_target_3d.Speed = walkSpeed
			follow_target_3d.SetFixedTarget(random_target_3d.GetNextPoint())
			target = null
			_has_last_known_pos = false

		States.Pursuit:
			if target == null or not is_instance_valid(target):
				ChangeState(States.Walking)
				return
			follow_target_3d.Speed = runSpeed * (ALERT_SPEED_MULTIPLIER if _is_alerted else 1.0)
			follow_target_3d.SetTarget(target)

		States.Investigating:
			target = null
			follow_target_3d.Speed = runSpeed
			if _has_last_known_pos:
				follow_target_3d.SetFixedTarget(_last_known_player_pos)
			else:
				ChangeState(States.Walking)

		States.Attacking:
			follow_target_3d.ClearTarget()
			velocity = Vector3.ZERO
			_perform_attack()

		States.Dead:
			follow_target_3d.ClearTarget()
			velocity = Vector3.ZERO

func _perform_attack():
	if not can_attack or not target:
		ChangeState(States.Pursuit)
		return

	can_attack = false
	attack_timer = attack_cooldown
	_play_sfx(attack_sound)

	if animation_player and animation_player.has_animation("attack"):
		animation_player.play("attack")

	match attack_type:
		AttackType.MELEE:
			_melee_attack()
		AttackType.HITSCAN:
			_hitscan_attack()
		AttackType.PROJECTILE:
			_projectile_attack()

	await get_tree().create_timer(attack_cooldown).timeout
	if state == States.Attacking and not is_dead():
		ChangeState(States.Pursuit)

func _melee_attack():
	if not target:
		return

	var distance = global_position.distance_to(target.global_position)
	if distance <= melee_range:
		var health = target.get_node_or_null("HealthComponent")
		if health:
			if target.is_in_group("PlayerCharacter"):
				GameManager.last_death_cause = _get_enemy_death_cause()
			health.take_damage(melee_damage)

		if target is CharacterBody3D:
			var knockback_dir = (target.global_position - global_position).normalized()
			knockback_dir.y = 0.2
			target.velocity += knockback_dir * melee_knockback

func _weapon_float(weapon: Resource, key: String, default_val: float) -> float:
	var v = weapon.get(key)
	return float(v) if v != null else default_val

func _weapon_bool(weapon: Resource, key: String, default_val: bool) -> bool:
	var v = weapon.get(key)
	return bool(v) if v != null else default_val

func _get_shot_origin() -> Vector3:
	if weapon_slot != null:
		return weapon_slot.global_position
	return global_position

func _hitscan_attack() -> void :
	if not target or not enemy_weapon:
		return
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var from: Vector3 = _get_shot_origin()
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, target.global_position)
	query.exclude = [self]
	var result: Dictionary = space.intersect_ray(query)
	if result.is_empty():
		return
	if result.collider != target:
		return
	var dmg: float = float(
		enemy_weapon.get("damagePerProj") if enemy_weapon.get("damagePerProj") != null else 10.0)
	var health: Node = target.get_node_or_null("HealthComponent")
	if health and not target.is_in_group("StoryNPC"):
		if target.is_in_group("PlayerCharacter"):
			GameManager.last_death_cause = _get_enemy_death_cause()
		health.take_damage(dmg)

func _projectile_attack() -> void :
	if not target:
		return
	if not is_instance_valid(target):
		return
	var weapon: Resource = enemy_weapon
	if weapon == null:
		return
	var proj_scene: PackedScene = null
	if weapon.get("projRef") != null:
		proj_scene = weapon.get("projRef") as PackedScene
	if proj_scene == null:
		push_warning("Enemy has no projRef set")
		return
	var spawn_pos: Vector3 = global_position + Vector3(0, 1.5, 0)
	var ws: Node3D = get_node_or_null("WeaponSlot") as Node3D
	if ws != null:
		spawn_pos = ws.global_position
	spawn_pos.y -= 0.4
	var target_pos: Vector3 = target.global_position + Vector3(0, 0.28125, 0)
	var direction: Vector3 = (target_pos - spawn_pos).normalized()
	var proj: Node3D = proj_scene.instantiate() as Node3D
	if proj == null:
		return

	if "explosionRadius" in proj:
		proj.set("explosionRadius", 6.0)
	if "isExplosive" in proj:
		proj.set("isExplosive", true)
	if "direction" in proj:
		proj.set("direction", direction)
	if "damage" in proj:
		var full_damage: float = _weapon_float(weapon, "damagePerProj", 30.0)
		proj.set("damage", full_damage * 0.5)
	if "timeBeforeVanish" in proj:
		proj.set("timeBeforeVanish", _weapon_float(weapon, "projTimeBeforeVanish", 8.0))
	if "gravity_scale" in proj:
		proj.set("gravity_scale", 0.0)

	var exclude_rids: Array[RID] = []
	exclude_rids.append(get_rid())
	for child in get_children():
		if child is CollisionObject3D:
			exclude_rids.append((child as CollisionObject3D).get_rid())
	if "excluded_rids" in proj:
		proj.set("excluded_rids", exclude_rids)
	if "shooter" in proj:
		proj.set("shooter", self)

	get_tree().root.add_child(proj)
	if "explosionRadius" in proj:
		proj.set("explosionRadius", 6.0)

	if proj is RigidBody3D:
		var rb: RigidBody3D = proj as RigidBody3D
		if direction.length_squared() > 0.0001:
			rb.global_transform = Transform3D(
				Basis.looking_at( - direction, Vector3.UP), spawn_pos)
		else:
			rb.global_position = spawn_pos
		rb.angular_velocity = Vector3.ZERO
		var speed: float = _weapon_float(weapon, "projMoveSpeed", 20.0)
		rb.set_linear_velocity(direction * speed)
	else:
		proj.global_position = spawn_pos

func _on_follow_target_3d_navigation_finished() -> void :
	if state == States.Dead:
		return
	if state == States.Attacking:
		return
	if state == States.Pursuit:
		if target != null and is_instance_valid(target):
			follow_target_3d.SetTarget(target)
		return
	if state == States.Investigating:
		if _has_last_known_pos:
			follow_target_3d.SetFixedTarget(_last_known_player_pos)
		return
	follow_target_3d.SetFixedTarget(random_target_3d.GetNextPoint())


func _bootstrap_navigation_agent() -> void :
	if not is_instance_valid(self) or follow_target_3d == null:
		return
	await get_tree().physics_frame
	if not is_instance_valid(self) or follow_target_3d == null:
		return
	follow_target_3d.sync_to_parent()
	if state == States.Pursuit and target != null and is_instance_valid(target):
		follow_target_3d.SetTarget(target)
	elif state == States.Investigating and _has_last_known_pos:
		follow_target_3d.SetFixedTarget(_last_known_player_pos)
	elif state == States.Walking and random_target_3d != null:
		var nav_wait_frames: = 0
		while nav_wait_frames < 120\
		and not RandomTarget3D.is_navigation_map_ready(get_world_3d()):
			nav_wait_frames += 1
			await get_tree().physics_frame
			if not is_instance_valid(self) or follow_target_3d == null:
				return
		follow_target_3d.SetFixedTarget(random_target_3d.GetNextPoint())


func _pick_new_random_target() -> void :
	if random_target_3d == null or follow_target_3d == null:
		return
	follow_target_3d.SetFixedTarget(random_target_3d.GetNextPoint())

func hitscanHit(damageVal: float, _hitscanDir: Vector3, _hitscanPos: Vector3):
	if health_component and state != States.Dead:
		health_component.take_damage(damageVal)
		_play_sfx(hurt_sound)
		_flash_hit()

func projectileHit(damageVal: float, _projectileDir: Vector3):
	if health_component and state != States.Dead:
		health_component.take_damage(damageVal)
		_play_sfx(hurt_sound)
		_flash_hit()


func _on_alert_triggered(_current_health: float, _damage: float) -> void :
	if state == States.Dead:
		return
	_is_alerted = true
	_alert_timer = ALERT_DURATION
	var player: = NetUtil.get_nearest_player(global_position)
	if player == null:
		return
	target = player
	_last_known_player_pos = player.global_position
	_has_last_known_pos = true
	if state != States.Attacking:
		ChangeState(States.Pursuit)


func _process_alert(delta: float) -> void :
	if not _is_alerted:
		return
	_alert_timer -= delta
	var player: = NetUtil.get_nearest_player(global_position)
	if player == null or not is_instance_valid(player):
		_is_alerted = false
		return
	target = player
	_last_known_player_pos = player.global_position
	_has_last_known_pos = true
	if state != States.Attacking and state != States.Dead and state != States.Pursuit:
		ChangeState(States.Pursuit)
	if follow_target_3d != null and state == States.Pursuit:
		follow_target_3d.Speed = runSpeed * ALERT_SPEED_MULTIPLIER
		follow_target_3d.SetTarget(player)
	if _alert_timer > 0.0:
		return
	_is_alerted = false
	if state != States.Pursuit:
		return
	var distance_to_player: = global_position.distance_to(player.global_position)
	if distance_to_player > detection_range:
		target = null
		ChangeState(States.Walking)
	elif follow_target_3d != null:
		follow_target_3d.Speed = runSpeed


func _on_enemy_death():
	_play_sfx(death_sound)
	if weapon_slot:
		weapon_slot.visible = false
	state = States.Dead
	_drop_hunt_item()

	target = null
	follow_target_3d.ClearTarget()
	velocity = Vector3.ZERO

	if collision_shape:
		collision_shape.disabled = true
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)

	_convert_to_rigidbody()

	await get_tree().create_timer(0.1).timeout
	queue_free()

func _drop_hunt_item() -> void :
	if drop_item_id == "" or GameManager == null:
		return
	# _on_enemy_death() now runs on every peer (is_dead is a synced property
	# with a setter that fires on_death wherever it lands — see
	# components/health_component.gd), but the actual reward must only be
	# granted once, not once per peer watching the death happen.
	if not is_authority():
		return
	var amount: = max(1, drop_item_amount)
	GameManager.add_item(drop_item_id, amount)

func _convert_to_rigidbody():
	var rigid_body = RigidBody3D.new()
	rigid_body.name = "Ragdoll_" + name
	rigid_body.global_transform = global_transform

	var new_collision = CollisionShape3D.new()
	if collision_shape and collision_shape.shape:
		new_collision.shape = collision_shape.shape.duplicate()
		rigid_body.add_child(new_collision)

	if geometry_node:
		geometry_node.get_parent().remove_child(geometry_node)
		rigid_body.add_child(geometry_node)

	get_tree().root.add_child(rigid_body)

	rigid_body.apply_central_impulse(Vector3(
		randf_range( - ragdoll_force, ragdoll_force), 
		randf_range(ragdoll_force * 0.5, ragdoll_force), 
		randf_range( - ragdoll_force, ragdoll_force)
	))

	rigid_body.apply_torque(Vector3(
		randf_range( - ragdoll_torque, ragdoll_torque), 
		randf_range( - ragdoll_torque, ragdoll_torque), 
		randf_range( - ragdoll_torque, ragdoll_torque)
	))

	var timer = Timer.new()
	timer.wait_time = ragdoll_lifetime
	timer.one_shot = true
	timer.timeout.connect( func():
		if rigid_body and is_instance_valid(rigid_body):
			rigid_body.queue_free()
	)
	rigid_body.add_child(timer)
	timer.start()

func is_dead() -> bool:
	return state == States.Dead

func _play_sfx(stream: AudioStream) -> void :
	if stream == null:
		return
	var sfx: = get_node_or_null("SFX") as AudioStreamPlayer3D
	if sfx == null:
		return
	sfx.stream = stream
	sfx.play()

func _collect_meshes(node: Node, result: Array) -> void :
	if node == null:
		return
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		_collect_meshes(child, result)

func _collect_sprites(node: Node, result: Array) -> void :
	if node == null:
		return
	if node is Sprite3D:
		result.append(node)
	for child in node.get_children():
		_collect_sprites(child, result)

func _flash_hit() -> void :
	if _is_flashing or geometry_node == null:
		return
	_is_flashing = true
	var meshes: Array = []
	var sprites: Array = []
	_collect_meshes(geometry_node, meshes)
	_collect_sprites(geometry_node, sprites)
	if meshes.is_empty() and sprites.is_empty():
		_is_flashing = false
		return
	_flash_originals.clear()
	_flash_sprite_originals.clear()
	for m in meshes:
		var mi: = m as MeshInstance3D
		_flash_originals.append(mi.get_surface_override_material(0))
		var flash: = StandardMaterial3D.new()
		flash.albedo_color = Color(1, 0, 0, 1)
		flash.emission_enabled = true
		flash.emission = Color(1, 0, 0, 1)
		flash.emission_energy_multiplier = 2.0
		mi.set_surface_override_material(0, flash)
	for s in sprites:
		var spr: = s as Sprite3D
		_flash_sprite_originals.append(spr.modulate)
		spr.modulate = Color(3, 0.25, 0.25, 1)
	get_tree().create_timer(0.08).timeout.connect(
		func(): _end_flash_hit(meshes, sprites), CONNECT_ONE_SHOT)

func _end_flash_hit(meshes: Array, sprites: Array) -> void :
	for i in meshes.size():
		var mi: = meshes[i] as MeshInstance3D
		if is_instance_valid(mi):
			var orig: Material = _flash_originals[i] as Material
			mi.set_surface_override_material(0, orig)
	for i in sprites.size():
		var spr: = sprites[i] as Sprite3D
		if is_instance_valid(spr):
			spr.modulate = _flash_sprite_originals[i] as Color
	_flash_originals.clear()
	_flash_sprite_originals.clear()
	_is_flashing = false


func enable_for_hunt() -> void :
	if visible and process_mode == Node.PROCESS_MODE_INHERIT:
		return
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	_last_position = global_position
	call_deferred("_bootstrap_navigation_agent")


func _get_enemy_death_cause() -> String:
	var n: = name.to_lower()
	if n.contains("moose") or n.contains("elg"):
		return "moose"
	if n.contains("crow") or n.contains("krage") or n.contains("kråke"):
		return "crow"
	return "enemy"
