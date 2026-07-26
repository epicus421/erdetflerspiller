extends State



class_name CrouchState

var stateName: String = "Crouch"

var cR: CharacterBody3D

func enter(charRef: CharacterBody3D):
	cR = charRef

	verifications()

func verifications():
	cR.moveSpeed = cR.crouchSpeed
	cR.moveAccel = cR.crouchAccel
	cR.moveDeccel = cR.crouchDeccel

	cR.floor_snap_length = 1.0
	if cR.jumpCooldown > 0.0: cR.jumpCooldown = -1.0
	if cR.nbJumpsInAirAllowed < cR.nbJumpsInAirAllowedRef: cR.nbJumpsInAirAllowed = cR.nbJumpsInAirAllowedRef
	if cR.coyoteJumpCooldown < cR.coyoteJumpCooldownRef: cR.coyoteJumpCooldown = cR.coyoteJumpCooldownRef

func physics_update(delta: float):
	if cR is PlayerCharacter and (cR as PlayerCharacter).is_sitting:
		return
	checkIfFloor()

	applies(delta)

	cR.gravityApply(delta)

	if cR.is_on_floor() and Input.is_action_pressed(cR.jumpAction):
		if !raycastVerification():
			transitioned.emit(self, "JumpState")
			return

	inputManagement()

	move(delta)

func checkIfFloor():
	if !cR.is_on_floor() and !cR.is_on_wall():
		if cR.velocity.y < 0.0:
			transitioned.emit(self, "InairState")
	if cR.is_on_floor():
		if cR.jumpBuffOn:
			cR.bufferedJump = true
			cR.jumpBuffOn = false
			transitioned.emit(self, "JumpState")

func applies(delta: float):
	if cR.hitGroundCooldown > 0.0: cR.hitGroundCooldown -= delta

	cR.hitbox.shape.height = lerp(cR.hitbox.shape.height, cR.crouchHitboxHeight, cR.heightChangeSpeed * delta)
	cR.model.scale.y = lerp(cR.model.scale.y, cR.crouchModelHeight, cR.heightChangeSpeed * delta)

func inputManagement():
	if Input.is_action_just_pressed(cR.jumpAction):
		if !raycastVerification():
			transitioned.emit(self, "JumpState")

	if cR.continiousCrouch:
		if Input.is_action_just_pressed(cR.crouchAction):
			if !raycastVerification():
				cR.walkOrRun = "WalkState"
				transitioned.emit(self, "WalkState")
	else:
		if !Input.is_action_pressed(cR.crouchAction):
			if !raycastVerification():
				cR.walkOrRun = "WalkState"
				transitioned.emit(self, "WalkState")

func raycastVerification() -> bool:
	if not cR.ceilingCheck.is_colliding():
		return false
	var collider: Object = cR.ceilingCheck.get_collider()
	if collider == null:
		return false
	if collider == cR:
		return false
	if collider is Node and cR.is_ancestor_of(collider as Node):
		return false
	return true

func move(delta: float):
	cR.update_move_input()

	if cR.is_on_floor():
		cR.gs_apply_friction(1.0, delta)
		if cR.moveDirection:
			cR.gs_accelerate(cR.moveDirection, cR.moveSpeed, cR.gs_acceleration, delta)
		cR.desiredMoveSpeed = cR.get_horizontal_speed()

	if cR.desiredMoveSpeed >= cR.maxSpeed: cR.desiredMoveSpeed = cR.maxSpeed
