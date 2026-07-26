extends State

class_name InairState

var stateName: String = "Inair"

var cR: CharacterBody3D

func enter(charRef: CharacterBody3D):
	cR = charRef

	verifications()

func verifications():
	if cR.floor_snap_length != 0.0: cR.floor_snap_length = 0.0
	if cR.hitGroundCooldown != cR.hitGroundCooldownRef: cR.hitGroundCooldown = cR.hitGroundCooldownRef

func physics_update(delta: float):
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
		if cR.floorCheck.is_colliding() and cR.lastFramePosition.y > cR.position.y and cR.nbJumpsInAirAllowed <= 0: cR.jumpBuffOn = true
		if cR.wasOnFloor and cR.coyoteJumpCooldown > 0.0 and cR.lastFramePosition.y > cR.position.y:
			cR.coyoteJumpOn = true
			transitioned.emit(self, "JumpState")
		transitioned.emit(self, "JumpState")

func checkIfFloor():
	if cR.is_on_floor():
		if cR.jumpBuffOn:
			cR.bufferedJump = true
			cR.jumpBuffOn = false
			transitioned.emit(self, "JumpState")
		else:
			if cR.moveDirection: transitioned.emit(self, cR.walkOrRun)
			else: transitioned.emit(self, "IdleState")

func move(delta: float) -> void :
	cR.update_move_input()
	if cR.is_on_floor():
		return
	if cR.moveDirection:
		cR.gs_airaccelerate(cR.moveDirection, cR.runSpeed, cR.gs_air_acceleration, delta)
	cR.desiredMoveSpeed = cR.get_horizontal_speed()
