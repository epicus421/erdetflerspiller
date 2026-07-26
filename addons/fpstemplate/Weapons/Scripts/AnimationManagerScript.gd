extends Node3D

var cW
var cWModel: Node3D

@onready var cameraHolder: Node3D = %CameraHolder
@onready var playChar: CharacterBody3D = $"../../../../.."
@onready var animPlayer: AnimationPlayer = %AnimationPlayer
@onready var weaponManager: Node3D = %WeaponManager

func getCurrentWeapon(currWeap, currweaponManagerodel):

	cW = currWeap
	cWModel = currweaponManagerodel

func _process(delta: float):
	if cW == null or cWModel == null:
		return
	if int(cW.weaponId) == 0:
		return
	weaponTilt(playChar.inputDirection, delta)
	weaponSway(cameraHolder.mouseInput, delta)
	weaponBob(playChar.velocity.length(), delta)

func weaponTilt(playCharInput, delta):

	cWModel.rotation.z = lerp(cWModel.rotation.z, playCharInput.x * cW.tiltRotAmount, cW.tiltRotSpeed * delta)

func weaponSway(mouseInput, delta):

	mouseInput.x = clamp(mouseInput.x, cW.minSwayVal.x, cW.maxSwayVal.x)
	mouseInput.y = clamp(mouseInput.y, cW.minSwayVal.y, cW.maxSwayVal.y)


	cWModel.position.x = lerp(cWModel.position.x, cW.position[0].x + (mouseInput.x * cW.swayAmountPos) * delta, cW.swaySpeedPos)
	cWModel.position.y = lerp(cWModel.position.y, cW.position[0].y - (mouseInput.y * cW.swayAmountPos) * delta, cW.swaySpeedPos)



	cWModel.rotation_degrees.y = lerp(cWModel.rotation_degrees.y, rad_to_deg(cW.position[1].y) - (mouseInput.x * cW.swayAmountRot) * delta, cW.swaySpeedRot)
	cWModel.rotation_degrees.x = lerp(cWModel.rotation_degrees.x, rad_to_deg(cW.position[1].x) + (mouseInput.y * cW.swayAmountRot) * delta, cW.swaySpeedRot)

func weaponBob(vel: float, delta):
	var bobFreq: float = cW.bobFreq


	if vel < 4.0 and cW.onIdleBobFreqDivider > 0.0:
		bobFreq /= cW.onIdleBobFreqDivider


	cWModel.position.y = lerp(cWModel.position.y, cW.bobPos[0].y + sin(Time.get_ticks_msec() * bobFreq) * cW.bobAmount * vel / 10, cW.bobSpeed * delta)
	cWModel.position.x = lerp(cWModel.position.x, cW.bobPos[0].x + sin(Time.get_ticks_msec() * bobFreq * 0.5) * cW.bobAmount * vel / 10, cW.bobSpeed * delta)

func playAnimation(animName: String, animSpeed: float, hasToRestartAnim: bool):
	if cW != null and animPlayer != null:

		if hasToRestartAnim and animPlayer.current_animation == animName:
			animPlayer.seek(0, true)

		animPlayer.play("%s" % animName, -1, animSpeed)
