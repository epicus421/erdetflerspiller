extends State

class_name IdleState

var stateName: String = "Idle"

var cR: CharacterBody3D

func enter(char_ref: CharacterBody3D):
	cR = char_ref

	verifications()

func verifications():
	cR.floor_snap_length = 1.0
	if cR.jumpCooldown > 0.0: cR.jumpCooldown = -1.0
	if cR.nbJumpsInAirAllowed < cR.nbJumpsInAirAllowedRef: cR.nbJumpsInAirAllowed = cR.nbJumpsInAirAllowedRef
	if cR.coyoteJumpCooldown < cR.coyoteJumpCooldownRef: cR.coyoteJumpCooldown = cR.coyoteJumpCooldownRef

func physics_update(delta: float):
	checkIfFloor()

	applies(delta)

	cR.gravityApply(delta)

	if cR.is_on_floor() and Input.is_action_pressed(cR.jumpAction):
		transitioned.emit(self, "JumpState")
		return

	inputManagement()

	move(delta)

func checkIfFloor():
	if !cR.is_on_floor() and !cR.is_on_wall():
		transitioned.emit(self, "InairState")
	if cR.is_on_floor():
		if cR.jumpBuffOn:
			cR.bufferedJump = true
			cR.jumpBuffOn = false
			transitioned.emit(self, "JumpState")

func applies(delta: float):
	if cR.hitGroundCooldown > 0.0: cR.hitGroundCooldown -= delta

	cR.hitbox.shape.height = lerp(cR.hitbox.shape.height, cR.baseHitboxHeight, cR.heightChangeSpeed * delta)
	cR.model.scale.y = lerp(cR.model.scale.y, cR.baseModelHeight, cR.heightChangeSpeed * delta)

func inputManagement():
	if Input.is_action_just_pressed(cR.jumpAction):
		transitioned.emit(self, "JumpState")

	if Input.is_action_just_pressed(cR.crouchAction):
		transitioned.emit(self, "CrouchState")

	if Input.is_action_just_pressed(cR.runAction):
		if cR.walkOrRun == "WalkState": cR.walkOrRun = "RunState"
		elif cR.walkOrRun == "RunState": cR.walkOrRun = "WalkState"

func move(delta: float):
	cR.update_move_input()

	if cR.moveDirection and cR.is_on_floor():
		transitioned.emit(self, cR.walkOrRun)
	else:
		cR.gs_apply_friction(1.0, delta)
		cR.desiredMoveSpeed = cR.get_horizontal_speed()

	if cR.desiredMoveSpeed >= cR.maxSpeed: cR.desiredMoveSpeed = cR.maxSpeed
