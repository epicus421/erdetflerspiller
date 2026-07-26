extends Node3D

var cW
var pointOfCollision: Vector3 = Vector3.ZERO
var rng: RandomNumberGenerator

@onready var weaponManager: Node3D = %WeaponManager

func getCurrentWeapon(currWeap):

	cW = currWeap


func _get_physics_space_state() -> PhysicsDirectSpaceState3D:
	var camera: Camera3D = null
	if weaponManager != null and weaponManager.camera != null:
		camera = weaponManager.camera
	else:
		camera = get_viewport().get_camera_3d()
	if camera != null:
		var cam_world: World3D = camera.get_world_3d()
		if cam_world != null and cam_world.direct_space_state != null:
			return cam_world.direct_space_state
	if is_inside_tree():
		var node_world: World3D = get_world_3d()
		if node_world != null and node_world.direct_space_state != null:
			return node_world.direct_space_state
	return null


func _get_scene_root() -> Node:
	if not is_inside_tree():
		return null
	var tree: = get_tree()
	if tree == null:
		return null
	var root: Node = tree.current_scene
	if root != null:
		return root
	return tree.root


func _can_continue_shooting() -> bool:
	return (
		is_inside_tree()
		and is_instance_valid(cW)
		and weaponManager != null
		and is_instance_valid(weaponManager)
		and weaponManager.is_inside_tree()
	)


func _finish_shooting() -> void :
	if is_instance_valid(cW):
		cW.isShooting = false


func shoot() -> void :
	if not is_inside_tree():
		return
	if cW == null:
		return
	if not is_instance_valid(cW):
		return
	if weaponManager == null or weaponManager.ammoManager == null:
		return
	if !cW.isShooting and (

	(cW.totalAmmoInMag > 0 and cW.totalAmmoInMag >= cW.nbProjShotsAtSameTime)
	or 

	(cW.allAmmoInMag and weaponManager.ammoManager.ammoDict[cW.ammoType] > 0 and 

	weaponManager.ammoManager.ammoDict[cW.ammoType] >= cW.nbProjShotsAtSameTime)
	) and not (cW != null and cW.isReloading):
		cW.isShooting = true


		for i in range(cW.nbProjShots):
			if not _can_continue_shooting():
				break

			if ((cW.totalAmmoInMag > 0 and cW.totalAmmoInMag >= cW.nbProjShotsAtSameTime)
			or (cW.allAmmoInMag and weaponManager.ammoManager.ammoDict[cW.ammoType] > 0) and 
			weaponManager.ammoManager.ammoDict[cW.ammoType] >= cW.nbProjShotsAtSameTime):

				weaponManager.weaponSoundManagement(cW.shootSound, cW.shootSoundSpeed)
				if not _can_continue_shooting():
					break
				if GameManager:
					var shot_origin: Vector3 = global_position
					if cW.weaponSlot and cW.weaponSlot.attackPoint:
						shot_origin = cW.weaponSlot.attackPoint.global_position
					GameManager.gunshot_fired.emit(shot_origin, 20.0)

				if cW.shootAnimName != "" and _can_continue_shooting():
					weaponManager.animManager.playAnimation("ShootAnim%s" % cW.weaponName, cW.shootAnimSpeed, true)
				elif cW.shootAnimName == "":
					print("%s doesn't have a shoot animation" % cW.weaponName)




				for j in range(0, cW.nbProjShotsAtSameTime):
					if not _can_continue_shooting():
						break
					if cW.allAmmoInMag: weaponManager.ammoManager.ammoDict[cW.ammoType] -= 1
					else: cW.totalAmmoInMag -= 1


					pointOfCollision = getCameraPOV()
					if pointOfCollision == Vector3.ZERO:
						continue


					if cW.type == cW.types.HITSCAN: hitscanShot(pointOfCollision)
					elif cW.type == cW.types.PROJECTILE: projectileShot(pointOfCollision)
					if not _can_continue_shooting():
						break

				if not _can_continue_shooting():
					break
				if cW.showMuzzleFlash:
					weaponManager.displayMuzzleFlash()
				if not _can_continue_shooting():
					break
				if weaponManager.cameraRecoilHolder != null:
					weaponManager.cameraRecoilHolder.setRecoilValues(cW.baseRotSpeed, cW.targetRotSpeed)
					weaponManager.cameraRecoilHolder.addRecoil(cW.recoilVal)

				if not is_inside_tree():
					break
				var tree: = get_tree()
				if tree == null:
					break
				await tree.create_timer(cW.timeBetweenShots).timeout
				if not _can_continue_shooting():
					break

			else:
				print("Not enought ammunitions to shoot")

		_finish_shooting()

func getCameraPOV():
	if cW == null or not is_instance_valid(cW):
		return Vector3.ZERO
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return Vector3.ZERO
	var window: Window = get_window()
	var viewport: Vector2i


	match window.content_scale_mode:
		window.CONTENT_SCALE_MODE_VIEWPORT:
			viewport = window.content_scale_size
		window.CONTENT_SCALE_MODE_CANVAS_ITEMS:
			viewport = window.content_scale_size
		window.CONTENT_SCALE_MODE_DISABLED:
			viewport = window.get_size()


	var raycastStart = camera.project_ray_origin(viewport / 2)
	var raycastEnd
	if cW.type == cW.types.HITSCAN: raycastEnd = raycastStart + camera.project_ray_normal(viewport / 2) * cW.maxRange
	if cW.type == cW.types.PROJECTILE: raycastEnd = raycastStart + camera.project_ray_normal(viewport / 2) * 280


	var newIntersection = PhysicsRayQueryParameters3D.create(raycastStart, raycastEnd)
	newIntersection.collide_with_areas = true
	newIntersection.collide_with_bodies = true
	newIntersection.collision_mask = 4294967295
	var space_state: = _get_physics_space_state()
	if space_state == null:
		return Vector3.ZERO
	var intersection = space_state.intersect_ray(newIntersection)


	if !intersection.is_empty():
		var collisionPoint = intersection.position
		return collisionPoint

	else:
		return raycastEnd

func hitscanShot(pointOfCollisionHitscan: Vector3):
	if not is_inside_tree():
		return
	if cW == null or not is_instance_valid(cW):
		return
	rng = RandomNumberGenerator.new()


	var spread = Vector3(rng.randf_range(cW.minSpread, cW.maxSpread), rng.randf_range(cW.minSpread, cW.maxSpread), rng.randf_range(cW.minSpread, cW.maxSpread))


	var hitscanBulletDirection = (pointOfCollisionHitscan - cW.weaponSlot.attackPoint.get_global_transform().origin).normalized()


	var newIntersection = PhysicsRayQueryParameters3D.create(cW.weaponSlot.attackPoint.get_global_transform().origin, pointOfCollisionHitscan + spread + hitscanBulletDirection * 2)
	newIntersection.collide_with_areas = true
	newIntersection.collide_with_bodies = true
	newIntersection.collision_mask = 4294967295
	var space_state: = _get_physics_space_state()
	if space_state == null:
		return
	var hitscanBulletCollision = space_state.intersect_ray(newIntersection)


	if hitscanBulletCollision:
		var collider = hitscanBulletCollision.collider
		var colliderPoint = hitscanBulletCollision.position
		var colliderNormal = hitscanBulletCollision.normal
		var finalDamage: float

		if collider.is_in_group("Enemies") and collider.has_method("hitscanHit"):
			finalDamage = cW.damagePerProj * cW.damageDropoff.sample(pointOfCollisionHitscan.distance_to(global_position) / cW.maxRange)
			collider.hitscanHit(finalDamage, hitscanBulletDirection, hitscanBulletCollision.position)
			if is_inside_tree():
				_spawn_blood_at(colliderPoint, colliderNormal)

		elif collider.is_in_group("EnemiesHead") and collider.has_method("hitscanHit"):
			finalDamage = cW.damagePerProj * cW.headshotDamageMult * cW.damageDropoff.sample(pointOfCollisionHitscan.distance_to(global_position) / cW.maxRange)
			collider.hitscanHit(finalDamage, hitscanBulletDirection, hitscanBulletCollision.position)
			if is_inside_tree():
				_spawn_blood_at(colliderPoint, colliderNormal)

		elif collider.is_in_group("HitableObjects") and collider.has_method("hitscanHit"):
			finalDamage = cW.damagePerProj * cW.damageDropoff.sample(pointOfCollisionHitscan.distance_to(global_position) / cW.maxRange)
			collider.hitscanHit(finalDamage / 6.0, hitscanBulletDirection, hitscanBulletCollision.position)
			if weaponManager != null and weaponManager.is_inside_tree():
				weaponManager.displayBulletHole(colliderPoint, colliderNormal, collider)

		elif GameManager.apply_weapon_damage_to_npc_collider(collider, float(cW.damagePerProj) * cW.damageDropoff.sample(pointOfCollisionHitscan.distance_to(global_position) / cW.maxRange)):
			if is_inside_tree():
				_spawn_blood_at(colliderPoint, colliderNormal)

		elif weaponManager != null and weaponManager.is_inside_tree():
			weaponManager.displayBulletHole(colliderPoint, colliderNormal, collider)


func _spawn_blood_at(pos: Vector3, normal: Vector3) -> void :
	var blood_scene: = load("res://scenes/vfx/blood_splatter.tscn") as PackedScene
	if blood_scene == null:
		return
	var root: = _get_scene_root()
	if root == null:
		return
	var blood: = blood_scene.instantiate()
	root.add_child(blood)
	if blood.has_method("play"):
		blood.call("play", pos, normal)


const PROJECTILE_SPAWN_CLEARANCE: = 0.5


func _collect_collision_exclude_rids(root: Node) -> Array[RID]:
	var rids: Array[RID] = []
	_collect_collision_exclude_rids_recursive(root, rids)
	return rids


func _collect_collision_exclude_rids_recursive(node: Node, rids: Array[RID]) -> void :
	if node is CollisionObject3D:
		rids.append((node as CollisionObject3D).get_rid())
	for child in node.get_children():
		_collect_collision_exclude_rids_recursive(child, rids)


func projectileShot(pointOfCollisionProjectile: Vector3):
	if not is_inside_tree():
		return
	if cW == null or not is_instance_valid(cW):
		return
	rng = RandomNumberGenerator.new()


	var spread = Vector3(rng.randf_range(cW.minSpread, cW.maxSpread), rng.randf_range(cW.minSpread, cW.maxSpread), rng.randf_range(cW.minSpread, cW.maxSpread))

	var attack_pos = cW.weaponSlot.attackPoint.global_position
	var base_direction = (pointOfCollisionProjectile - attack_pos).normalized()
	var projectileDirection = base_direction + spread
	if projectileDirection.length_squared() > 0.0001:
		projectileDirection = projectileDirection.normalized()
	else:
		projectileDirection = base_direction


	var projInstance = cW.projRef.instantiate()


	var cleanTransform = Transform3D.IDENTITY
	cleanTransform.origin = attack_pos + base_direction * PROJECTILE_SPAWN_CLEARANCE
	cleanTransform.basis = cW.weaponSlot.attackPoint.global_transform.basis.orthonormalized()

	projInstance.global_transform = cleanTransform


	projInstance.direction = projectileDirection
	projInstance.damage = cW.damagePerProj
	projInstance.timeBeforeVanish = cW.projTimeBeforeVanish
	projInstance.gravity_scale = cW.projGravityVal
	projInstance.isExplosive = cW.isProjExplosive
	if cW.isProjExplosive:
		var exp_radius: float = cW.explosionRadius
		if exp_radius <= 0.0:
			exp_radius = 6.0
		projInstance.explosionRadius = exp_radius

	var root: = _get_scene_root()
	if root == null:
		projInstance.queue_free()
		return
	root.add_child(projInstance)

	if cW.isProjExplosive and projInstance.explosionRadius <= 0.0:
		projInstance.explosionRadius = 6.0

	var shooter: = NetUtil.get_local_player()
	if "shooter" in projInstance:
		projInstance.shooter = shooter
	if "excluded_rids" in projInstance and shooter != null:
		projInstance.excluded_rids = _collect_collision_exclude_rids(shooter)
	if projInstance.has_method("setup_spawn_collision_exceptions"):
		projInstance.setup_spawn_collision_exceptions()

	projInstance.call_deferred("set_linear_velocity", projectileDirection * cW.projMoveSpeed)
