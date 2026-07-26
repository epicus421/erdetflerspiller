extends State

class_name JumpState

var stateName: String = "Jump"

var cR: CharacterBody3D

func enter(charRef: CharacterBody3D):
	cR = charRef

	verifications()

	jump()

func verifications():
	if cR.floor_snap_length != 0.0: cR.floor_snap_length = 0.0
	if cR.jumpCooldown < cR.jumpCooldownRef: cR.jumpCooldown = cR.jumpCooldownRef
	if cR.hitGroundCooldown != cR.hitGroundCooldownRef: cR.hitGroundCooldown = cR.hitGroundCooldownRef

func physics_update(delta: float):
	if cR is PlayerCharacter and (cR as PlayerCharacter).is_sitting:
		return
	applies(delta)

	cR.gravityApply(delta)

	inputManagement()

	checkIfFloor()

	move(delta)

func applies(delta: float):
	if !cR.is_on_floor():
		if cR.jumpCooldown > 0.0: cR.jumpCooldown -= delta
		if cR.coyoteJumpCooldown > 0.0: cR.coyoteJumpCooldown -= delta

	cR.hitbox.shape.height = lerp(cR.hitbox.shape.height, cR.baseHitboxHeight, cR.heightChangeSpeed * delta)
	cR.model.scale.y = lerp(cR.model.scale.y, cR.baseModelHeight, cR.heightChangeSpeed * delta)

func inputManagement():
	if Input.is_action_just_pressed(cR.jumpAction):
		jump()

func checkIfFloor():
	if !cR.is_on_floor() and cR.velocity.y < 0.0:
		transitioned.emit(self, "InairState")

	if cR.is_on_floor():
		if cR.moveDirection: transitioned.emit(self, cR.walkOrRun)
		else: transitioned.emit(self, "IdleState")

func move(delta: float):
	cR.update_move_input()
	if !cR.is_on_floor():
		if cR.moveDirection:
			cR.gs_airaccelerate(cR.moveDirection, cR.runSpeed, cR.gs_air_acceleration, delta)
		cR.desiredMoveSpeed = cR.get_horizontal_speed()

func jump():
	var canJump: bool = false

	if !cR.is_on_floor():
		if !cR.coyoteJumpOn and cR.nbJumpsInAirAllowed > 0:
			cR.nbJumpsInAirAllowed -= 1
			cR.jumpCooldown = cR.jumpCooldownRef
			canJump = true
		if cR.coyoteJumpOn:
			cR.jumpCooldown = cR.jumpCooldownRef
			cR.coyoteJumpCooldown = -1.0
			cR.coyoteJumpOn = false
			canJump = true

	if cR.is_on_floor():
		cR.jumpCooldown = cR.jumpCooldownRef
		canJump = true

	if cR.bufferedJump:
		cR.bufferedJump = false
		cR.nbJumpsInAirAllowed = cR.nbJumpsInAirAllowedRef

	if canJump:
		cR.velocity.y = cR.jumpVelocity
		canJump = false
