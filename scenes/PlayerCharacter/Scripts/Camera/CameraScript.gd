extends Node3D


class_name CameraObject

@export_group("Camera variables")
@export_range(0.1, 10.0, 0.1) var raw_sensitivity: float = 1.6
@export var maxUpAngleView: float
@export var maxDownAngleView: float

@export_group("FOV variables")
@export var startFOV: float
@export var runFOV: float
@export var fovTransitionSpeed: float

@export_group("Movement changes variables")
@export var baseCamAngle: float
@export var crouchCamAngle: float
@export var baseCameraLerpSpeed: float
@export var crouchCameraLerpSpeed: float
@export var crouchCameraDepth: float

@export_group("Camera bob variables")
@export var enableBob: bool = true
var headBobValue: float
@export var bobFrequency: float
@export var bobAmplitude: float

@export_group("Camera tilt variables")
@export var enableTilt: bool = true
@export var tiltRotationValue: float
@export var tiltRotationSpeed: float
@export var inAirTiltValDivider: float

@export_group("Input variables")
var mouseInput: Vector2
var playCharInputDir: Vector2
const RAW_SENS_MULTIPLIER: float = 0.00038397243458548


var mouseFree: bool = false

@export_group("Keybind variables")
@export var mouseModeAction: String = ""


@onready var camera: Camera3D = %Camera
@onready var playChar: PlayerCharacter = $".."
@onready var weaponManager: Node3D = %WeaponManager

var _effective_sens: float
var _y_sign: float = 1.0



const CONTROLLER_LOOK_BASE: = 3.2
const STICK_DEADZONE: = 0.15

var debug_cinematic_active: bool = false
var debug_cinematic_fov: float = 50.0
var _saved_enable_bob: bool = true
var _saved_enable_tilt: bool = true





var _shake_strength: float = 0.0
var _shake_decay: float = 0.0
@onready var _recoil_holder: Node3D = camera.get_parent() as Node3D
var _recoil_rest: Vector3 = Vector3.ZERO


func _ready():
	Input.use_accumulated_input = false
	if not _is_local():
		# Remote player: yaw/pitch arrive via MultiplayerSynchronizer instead
		# of local mouse input, and this camera is never the active viewport
		# camera. Don't poll Input on their behalf.
		if camera:
			camera.current = false
		set_process(false)
		set_process_unhandled_input(false)
		return
	apply_sensitivity_multiplier()
	add_to_group("PlayerCamera")
	if _recoil_holder != null:
		_recoil_rest = _recoil_holder.position
	if playChar != null and playChar.should_use_fps_mouse_capture():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _is_local() -> bool:
	if playChar == null or not playChar.has_method("is_local_player"):
		return true
	return playChar.is_local_player()



func add_shake(strength: float, duration: float = 0.4) -> void :
	_shake_strength = maxf(_shake_strength, strength)
	_shake_decay = _shake_strength / maxf(duration, 0.05)


func _apply_shake(delta: float) -> void :
	if _recoil_holder == null:
		return
	if _shake_strength > 0.0:
		_recoil_holder.position = _recoil_rest + Vector3(
			randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0
		) * _shake_strength
		_shake_strength = maxf(_shake_strength - _shake_decay * delta, 0.0)
	elif _recoil_holder.position != _recoil_rest:
		_recoil_holder.position = _recoil_holder.position.lerp(_recoil_rest, 14.0 * delta)


func apply_sensitivity_multiplier() -> void :
	var mult: = 1.0
	_y_sign = 1.0
	if GameManager:
		mult = GameManager.mouse_sensitivity
		if GameManager.invert_y:
			_y_sign = -1.0
	_effective_sens = raw_sensitivity * mult * RAW_SENS_MULTIPLIER


func set_debug_cinematic(active: bool, fov: float = -1.0) -> void :
	if fov >= 0.0:
		debug_cinematic_fov = clampf(fov, 20.0, 120.0)
	if active == debug_cinematic_active:
		if active and camera:
			camera.fov = debug_cinematic_fov
		return
	if active:
		_saved_enable_bob = enableBob
		_saved_enable_tilt = enableTilt
		enableBob = false
		enableTilt = false
		if camera:
			camera.transform.origin = Vector3.ZERO
			camera.fov = debug_cinematic_fov
	else:
		enableBob = _saved_enable_bob
		enableTilt = _saved_enable_tilt
	debug_cinematic_active = active


func set_debug_cinematic_fov(fov: float) -> void :
	debug_cinematic_fov = clampf(fov, 20.0, 120.0)
	if debug_cinematic_active and camera:
		camera.fov = debug_cinematic_fov

func _unhandled_input(event):
	if playChar and playChar.camera_frozen:
		return
	if event is InputEventMouseMotion:
		rotate_y( - event.screen_relative.x * _effective_sens)
		camera.rotate_x( - event.screen_relative.y * _effective_sens * _y_sign)
		_clamp_camera_pitch()
		mouseInput = event.screen_relative









func _clamp_camera_pitch() -> void :
	if camera == null:
		return
	var rot: Vector3 = camera.rotation
	if absf(rot.y) > 0.5 or absf(rot.z) > 0.5:
		var true_pitch: float = signf(rot.x) * (PI - absf(rot.x))
		rot = Vector3(true_pitch, 0.0, 0.0)
	rot.x = clamp(rot.x, deg_to_rad(maxUpAngleView), deg_to_rad(maxDownAngleView))
	camera.rotation = Vector3(rot.x, 0.0, 0.0)


func _controller_look(delta: float) -> void :
	var look: = Vector2(
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), 
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	)
	if look.length() < STICK_DEADZONE:
		return
	var mult: = 1.0
	if GameManager:
		mult = GameManager.mouse_sensitivity
	var speed: = CONTROLLER_LOOK_BASE * mult * delta
	rotate_y( - look.x * speed)
	camera.rotate_x( - look.y * speed * _y_sign)
	_clamp_camera_pitch()


func _process(delta):
	if playChar and playChar.camera_frozen:
		return
	if not debug_cinematic_active:
		_controller_look(delta)


	if not debug_cinematic_active:
		_clamp_camera_pitch()
	applies(delta)

	_apply_shake(delta)
	cameraBob(delta)

	cameraTilt(delta)

func applies(delta: float):
	if debug_cinematic_active:
		camera.fov = debug_cinematic_fov
		position.y = lerp(position.y, 0.715, baseCameraLerpSpeed * delta)
		rotation.z = lerp(rotation.z, 0.0, baseCameraLerpSpeed * delta)
		return
	var fov_override: = playChar != null and playChar.overrides_camera_fov()

	if playChar.stateMachine.currStateName == "Crouch":
		position.y = lerp(position.y, 0.715 + crouchCameraDepth, crouchCameraLerpSpeed * delta)
		rotation.z = lerp(rotation.z, deg_to_rad(crouchCamAngle) * playChar.inputDirection.x if playChar.inputDirection.x != 0.0 else deg_to_rad(crouchCamAngle), crouchCameraLerpSpeed * delta)
	elif playChar.stateMachine.currStateName == "Run":
		if not fov_override:
			camera.fov = lerp(camera.fov, runFOV, fovTransitionSpeed * delta)
		rotation.z = lerp(rotation.z, deg_to_rad(baseCamAngle), baseCameraLerpSpeed * delta)
	elif playChar.stateMachine.currStateName == "Jump":

		if not fov_override:
			camera.fov = lerp(camera.fov, camera.fov, fovTransitionSpeed * delta)
	elif playChar.stateMachine.currStateName == "Inair":

		if not fov_override:
			camera.fov = lerp(camera.fov, camera.fov, fovTransitionSpeed * delta)
	else:
		position.y = lerp(position.y, 0.715, baseCameraLerpSpeed * delta)
		rotation.z = lerp(rotation.z, deg_to_rad(baseCamAngle), baseCameraLerpSpeed * delta)
		if not fov_override:
			camera.fov = lerp(camera.fov, startFOV, fovTransitionSpeed * delta)

func cameraBob(delta):
	if playChar and playChar.camera_frozen:
		return
	if enableBob:

		headBobValue += delta * playChar.velocity.length() * float( not playChar.wasOnFloor)
		camera.transform.origin = headbob(headBobValue, bobFrequency, bobAmplitude)

func headbob(time, bobFreq, bobAmpli):

	var pos = Vector3.ZERO
	pos.y = sin(time * bobFreq) * bobAmpli
	pos.x = cos(time * bobFreq / 2) * bobAmpli
	return pos

func cameraTilt(delta):
	if playChar and playChar.camera_frozen:
		return
	if enableTilt:

		if playChar.moveDirection != Vector3.ZERO and playChar.inputDirection != Vector2.ZERO:
			playCharInputDir = playChar.inputDirection

			if playChar.wasOnFloor:
				rotation.z = lerp(rotation.z, - playCharInputDir.x * tiltRotationValue / inAirTiltValDivider, tiltRotationSpeed * delta)
			else: rotation.z = lerp(rotation.z, - playCharInputDir.x * tiltRotationValue, tiltRotationSpeed * delta)

func mouseMode():

	if playChar and not playChar.should_use_fps_mouse_capture():
		return
	if Input.is_action_just_pressed(mouseModeAction): mouseFree = !mouseFree
	if !mouseFree:
		if playChar == null or playChar.should_use_fps_mouse_capture():
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
