extends CharacterBody3D



class_name PlayerCharacter

@export_group("Movement variables")
var moveSpeed: float
var moveAccel: float
var moveDeccel: float
var desiredMoveSpeed: float
@export var desiredMoveSpeedCurve: Curve
@export var maxSpeed: float
@export var inAirMoveSpeedCurve: Curve
var inputDirection: Vector2
var moveDirection: Vector3
@export var hitGroundCooldown: float = 0.12
var hitGroundCooldownRef: float
@export var bunnyHopDmsIncre: float = 8.0
@export var autoBunnyHop: bool = true
@export var air_accel: float = 20.0
@export_range(0.1, 1.0, 0.05) var air_max_speed_scale: float = 0.48

@export_group("GoldSrc Movement")
@export var gs_acceleration: float = 10.0
@export var gs_air_acceleration: float = 10.0
@export var gs_friction_val: float = 4.0
@export var gs_stop_speed: float = 2.54
@export var gs_max_air_speed: float = 0.762
var lastFramePosition: Vector3
var lastFrameVelocity: Vector3
var wasOnFloor: bool
var walkOrRun: String = "WalkState"

@export var baseHitboxHeight: float
@export var baseModelHeight: float
@export var heightChangeSpeed: float

@export_group("Crouch variables")
@export var crouchSpeed: float
@export var crouchAccel: float
@export var crouchDeccel: float
@export var continiousCrouch: bool = false
@export var crouchHitboxHeight: float
@export var crouchModelHeight: float

@export_group("Walk variables")
@export var walkSpeed: float
@export var walkAccel: float
@export var walkDeccel: float

@export_group("Run variables")
@export var runSpeed: float
@export var runAccel: float
@export var runDeccel: float
@export var continiousRun: bool = false

@export_group("Jump variables")
@export var jumpHeight: float
@export var jumpTimeToPeak: float
@export var jumpTimeToFall: float
@onready var jumpVelocity: float = (2.0 * jumpHeight) / jumpTimeToPeak
@export var jumpCooldown: float
var jumpCooldownRef: float
@export var nbJumpsInAirAllowed: int
var nbJumpsInAirAllowedRef: int
var jumpBuffOn: bool = false
var bufferedJump: bool = false
@export var coyoteJumpCooldown: float
var coyoteJumpCooldownRef: float
var coyoteJumpOn: bool = false
@export_range(0.1, 1.0, 0.05) var inAirInputMultiplier: float = 1.0

@export_group("Gravity variables")
@onready var jumpGravity: float = (-2.0 * jumpHeight) / (jumpTimeToPeak * jumpTimeToPeak)
@onready var fallGravity: float = (-2.0 * jumpHeight) / (jumpTimeToFall * jumpTimeToFall)

@export_group("Keybind variables")
@export var moveForwardAction: String = ""
@export var moveBackwardAction: String = ""
@export var moveLeftAction: String = ""
@export var moveRightAction: String = ""
@export var runAction: String = ""
@export var crouchAction: String = ""
@export var jumpAction: String = ""


@onready var camHolder: Node3D = $CameraHolder
@onready var model: MeshInstance3D = $Model
@onready var hitbox: CollisionShape3D = $Hitbox
@onready var stateMachine: Node = %StateMachine
@onready var hud: CanvasLayer = $HUD
@onready var ceilingCheck: RayCast3D = $Raycasts / CeilingCheck
@onready var floorCheck: RayCast3D = $Raycasts / FloorCheck

@export var weapon_controller_path: NodePath = NodePath("CameraHolder/CameraRecoilHolder/Camera/WeaponManager")
@onready var weapon_manager: Node = get_node_or_null(weapon_controller_path)
var _weapon_active: bool = true
var _previously_active_weapon: Node = null
var carried_icecream_count: int = 0
var carried_object: RigidBody3D = null
var movement_frozen: bool = false
var camera_frozen: bool = false
var dialogue_waiting_for_button: bool = false
var is_sitting: bool = false
var _external_knockback: Vector3 = Vector3.ZERO
const KNOCKBACK_DECAY: float = 14.0

var _is_squinting: bool = false
const SQUINT_FOV: float = 28.0
const NORMAL_FOV: float = 75.0
const SQUINT_SPEED: float = 6.0
var _base_fov: float = NORMAL_FOV

func should_use_fps_mouse_capture() -> bool:
	return is_local_player() and not is_sitting and not movement_frozen and not camera_frozen and not dialogue_waiting_for_button


## Which weapon this player is holding, as a plain int so it can be replicated
## (see multiplayer/player_net.gd). The weapon itself is per-player state — the
## viewmodel, its ammo and the wheel index all stay local — but *which* gun is
## in your hands has to be visible to everyone else, which is what this drives
## on the remote avatar (multiplayer/player_avatar.gd).
var net_weapon_id: int = 0

## Which hand PNG the holster viewmodel is currently showing, as an index into
## PlayerAppearance.HAND_TEXTURES. Replicated so the middle finger you flip
## actually lands on someone else's screen — the viewmodel itself renders on a
## layer only your own camera draws, so remote players saw nothing.
var net_hand_gesture: int = 0


## Maps the texture the local viewmodel just picked onto the shared, ordered
## list that both ends agree on.
func _net_hand_index_for(tex: Texture2D) -> int:
	match tex:
		HAND_FIST_TEX: return 0
		HAND_PALM_TEX: return 1
		HAND_MIDFINGER_TEX: return 2
		HAND_OKSIGN_TEX: return 3
		HAND_PALMAWAY_TEX: return 4
		HAND_PEACE_TEX: return 5
		HAND_PISTOL_TEX: return 6
	return 0


func _update_net_weapon_id() -> void :
	if weapon_manager == null or not weapon_manager.has_method("get_current_weapon_id"):
		return
	var id: int = int(weapon_manager.get_current_weapon_id())
	if id != net_weapon_id:
		net_weapon_id = id


## True for the single player in solo play, and for whichever peer's own
## body this instance is in a multiplayer session. Everything input/camera/
## HUD-driven below is gated behind this so remote players don't react to
## our local input, and we don't process theirs.
func is_local_player() -> bool:
	if NetworkManager == null or not NetworkManager.is_active:
		return true
	return is_multiplayer_authority()


func _configure_as_remote_player() -> void:
	var camera: Camera3D = _get_player_camera()
	if camera:
		camera.current = false
	if hud:
		hud.visible = false
	var quest_hud: CanvasLayer = get_node_or_null("QuestHud") as CanvasLayer
	if quest_hud:
		quest_hud.visible = false
	if weapon_manager:
		# ShootManager/ReloadManager/AmmunitionManager/AnimationManager are
		# independent child nodes with their own Input-polling callbacks, so
		# disabling processing on weapon_manager alone wouldn't stop them.
		_disable_processing_recursive(weapon_manager)
	_disable_remote_weapon_viewport()
	# The body mesh is a bare CapsuleMesh on render layer 2 — it exists only
	# so the LOCAL player can cast a shadow without seeing their own body
	# (their camera's cull_mask=1 excludes layer 2). Showing that to other
	# players is what made everyone look like a bean, so a remote player gets
	# a real PSX character model instead (multiplayer/player_avatar.gd), which
	# hides the capsule itself. The capsule is only revived as a fallback if
	# the character models are missing from the build.
	if get_node_or_null("PlayerAvatar") == null:
		var avatar: Node3D = Node3D.new()
		avatar.name = "PlayerAvatar"
		avatar.set_script(REMOTE_AVATAR_SCRIPT)
		add_child(avatar)
	_add_remote_name_tag()


const REMOTE_AVATAR_SCRIPT: Script = preload("res://multiplayer/player_avatar.gd")

var _name_tag: Label3D = null


## The first-person weapon viewmodel is a full-screen SubViewportContainer
## parented to the player body, drawing render layer 3 through its own camera
## (the main camera's cull_mask is 1, so viewmodels are invisible in the world).
##
## That container ships with every PlayerCharacter — including the ones
## representing OTHER players — so each remote body was stacking another
## full-screen overlay on top of your view. When a teammate switched weapons,
## THEIR gun appeared on YOUR screen. It was also rendering a 640x480 viewport
## per remote player, every frame, for nothing.
func _disable_remote_weapon_viewport() -> void:
	var container: SubViewportContainer = get_node_or_null("SubViewportContainer") as SubViewportContainer
	if container == null:
		return
	container.visible = false
	var viewport: SubViewport = container.get_node_or_null("SubViewport") as SubViewport
	if viewport != null:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		var cam: Camera3D = viewport.get_node_or_null("ViewportCam") as Camera3D
		if cam != null:
			# Its _process copies the main camera's transform every frame.
			cam.set_process(false)


func _add_remote_name_tag() -> void:
	var tag: Label3D = Label3D.new()
	tag.name = "NameTag"
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	# The capsule's top sits at y=+1.0 (the body origin is its centre), so
	# this hangs just above the head rather than the 2.1 the first pass used,
	# which floated a good half-metre into the air.
	tag.position = Vector3(0, 1.35, 0)
	tag.font_size = 32
	tag.outline_size = 10
	tag.modulate = Color(1.0, 0.92, 0.72)
	tag.outline_modulate = Color(0, 0, 0, 0.9)
	# Layer 2 is the "hide from the owning player" layer; this tag only ever
	# hangs over someone else's head, so it belongs on the normal layer.
	tag.layers = 1
	add_child(tag)
	_name_tag = tag
	_refresh_name_tag()
	if NetworkManager != null and NetworkManager.has_signal("roster_updated"):
		# peer_connected fires before the joining peer has told us their name,
		# so the first read is usually still the placeholder — re-read it when
		# the real roster lands.
		NetworkManager.roster_updated.connect(_on_roster_updated_for_tag)


func _on_roster_updated_for_tag(_peers: Dictionary) -> void:
	_refresh_name_tag()


func _refresh_name_tag() -> void:
	if _name_tag == null or not is_instance_valid(_name_tag):
		return
	var display_name: String = "Spiller"
	if NetworkManager != null:
		var info: Variant = NetworkManager.peers.get(get_multiplayer_authority(), null)
		if info is Dictionary:
			display_name = str((info as Dictionary).get("name", display_name))
	_name_tag.text = display_name


func _disable_processing_recursive(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	node.set_process_input(false)
	node.set_process_unhandled_input(false)
	for child in node.get_children():
		_disable_processing_recursive(child)

const CARRY_MAX_DISTANCE: float = 2.5
const CARRY_HOLD_DISTANCE: float = 1.15
const CARRY_LERP_WEIGHT: float = 0.2
const SFX_FLASHLIGHT: = preload("res://assets/sfx/erdetlyd/splice/flashlight_toggle.wav")
const PAIN_SOUNDS: Array[AudioStream] = [
	preload("res://assets/sfx/erdetlyd/splice/fleshstab_player_takes_dmg.wav"), 
]
const _ItemNotification: = preload("res://scenes/ui/item_notification.gd")
const HAND_FIST_TEX: Texture2D = preload("res://assets/textures/images/hand_fist.png")
const HAND_PALM_TEX: Texture2D = preload("res://assets/textures/images/hand_palmopen.png")
const HAND_MIDFINGER_TEX: Texture2D = preload("res://assets/textures/images/hand_midfinger.png")
const HAND_OKSIGN_TEX: Texture2D = preload("res://assets/textures/images/hand_oksign.png")
const HAND_PALMAWAY_TEX: Texture2D = preload("res://assets/textures/images/hand_palmfacedaway.png")
const HAND_PEACE_TEX: Texture2D = preload("res://assets/textures/images/hand_peace.png")
const HAND_PISTOL_TEX: Texture2D = preload("res://assets/textures/images/hand_pistol.png")

const PEW_SOUNDS: Array[AudioStream] = [
	preload("res://assets/sfx/erdetlyd/vox/misc/munnpew0.ogg"), 
	preload("res://assets/sfx/erdetlyd/vox/misc/munnpew1.ogg"), 
	preload("res://assets/sfx/erdetlyd/vox/misc/munnpew2.ogg"), 
	preload("res://assets/sfx/erdetlyd/vox/misc/munnpew3.ogg"), 
	preload("res://assets/sfx/erdetlyd/vox/misc/munnpew4.ogg"), 
	preload("res://assets/sfx/erdetlyd/vox/misc/munnpew5.ogg"), 
]
var _last_pew_index: int = -1





var _hand_gestures: Array = []
var _gesture_index: int = 0

var _hand_anim_tween: Tween = null

const HAND_USE_COOLDOWN: float = 0.1
var _last_hand_use_time: float = -999.0

var _hand_rest_y: float = 0.0
var _hand_rest_captured: bool = false
const HAND_SPRITE_PATH: NodePath = NodePath(
	"CameraHolder/CameraRecoilHolder/Camera/WeaponManager/WeaponContainer/Holster/HolsterModel/HandSprite")
const HAND_RAYCAST_DISTANCE: float = 3.0


const FINGER_REACT_DISTANCE: float = 7.0

var _pain_audio: AudioStreamPlayer = null
var _hand_interact_pending: bool = false

var pickup_prompt: Label

@onready var health_component: HealthComponent = $HealthComponent
@onready var health_bar: ProgressBar = $HUD / UIStats / StatsPanel / Stats / HealthBar
@onready var ui_stats: HBoxContainer = $HUD / UIStats
const DEATH_SCREEN_SCENE: PackedScene = preload("res://scenes/ui/death_screen.tscn")

func _ready():
	if not is_in_group("PlayerCharacter"):
		add_to_group("PlayerCharacter")
	call_deferred("apply_mouse_sensitivity_from_settings")
	if not is_in_group("StoreBoundsActor"):
		add_to_group("StoreBoundsActor")

	moveSpeed = walkSpeed
	moveAccel = walkAccel
	moveDeccel = walkDeccel

	hitGroundCooldownRef = hitGroundCooldown
	jumpCooldownRef = jumpCooldown
	nbJumpsInAirAllowedRef = nbJumpsInAirAllowed
	coyoteJumpCooldownRef = coyoteJumpCooldown

	if health_component and is_local_player():
		# on_death/on_damage_taken now fire on every peer once is_dead/
		# current_health replicate (see components/health_component.gd) —
		# connecting these for a REMOTE player's body would show MY screen
		# a death screen / pain flash because someone else got hurt. Only
		# the local player's own health should drive local UI/game-over.
		health_component.connect("on_damage_taken", _on_damage_taken)
		health_component.connect("on_death", _on_player_death)
		_refresh_health_ui()
	_pain_audio = AudioStreamPlayer.new()
	_pain_audio.name = "PainAudio"
	_pain_audio.bus = "Sfx"
	add_child(_pain_audio)
	if GameManager:
		if not GameManager.minigame_started.is_connected(_on_minigame_started):
			GameManager.minigame_started.connect(_on_minigame_started)
		if not GameManager.minigame_ended.is_connected(_on_minigame_ended):
			GameManager.minigame_ended.connect(_on_minigame_ended)
		if not GameManager.consumable_used.is_connected(_on_consumable_used):
			GameManager.consumable_used.connect(_on_consumable_used)
		_setup_pickup_prompt()
	call_deferred("_cache_base_fov")
	if not is_local_player():
		# Synchronous, not deferred: Camera3D.current is exclusive per
		# viewport, so we must clear it before any other frame renders or
		# the local view can briefly snap to a just-spawned remote camera.
		_configure_as_remote_player()


func _cache_base_fov() -> void :
	var camera: = _get_player_camera()
	if camera != null:
		_base_fov = camera.fov

func _process(_delta: float):
	if not is_local_player():
		return
	# Outside the menu check: the weapon in your hands should stay correct on
	# everyone else's screen even while your own menu is open.
	_update_net_weapon_id()
	if _is_menu_blocking_input():
		return
	displayProperties()
	_update_squint_input()


func _update_squint_input() -> void :
	if not _can_squint():
		_is_squinting = false
		return
	_is_squinting = Input.is_action_pressed("aim")


func _can_squint() -> bool:
	if _debug_cinematic_active or camera_frozen or is_sitting or dialogue_waiting_for_button:
		return false
	if not _weapon_active:
		return true
	if weapon_manager == null:
		return true
	if _has_weapon_equipped() and weapon_manager.has_method("handle_aim_input"):
		return false
	return true


func _has_weapon_equipped() -> bool:
	if weapon_manager == null:
		return false
	return weapon_manager.get("cW") != null


func should_apply_squint_fov() -> bool:
	return _is_squinting and _can_squint()


func overrides_camera_fov() -> bool:
	if _debug_cinematic_active or camera_frozen:
		return false
	if should_apply_squint_fov():
		return true
	var camera: = _get_player_camera()
	if camera == null:
		return false
	return abs(camera.fov - _get_default_fov_target()) > 0.05


func _get_default_fov_target() -> float:
	var cam_obj: = camHolder as CameraObject
	if cam_obj != null and stateMachine != null:
		if stateMachine.currStateName == "Run" and cam_obj.runFOV > 0.0:
			return cam_obj.runFOV
		if cam_obj.startFOV > 0.0:
			return cam_obj.startFOV
	return _base_fov


func _update_squint_fov(delta: float) -> void :
	if _debug_cinematic_active or camera_frozen:
		return
	if not overrides_camera_fov():
		return
	var camera: Camera3D = _get_player_camera()
	if camera == null:
		return
	var target_fov: = SQUINT_FOV if should_apply_squint_fov() else _get_default_fov_target()
	camera.fov = lerp(camera.fov, target_fov, SQUINT_SPEED * delta)


func _get_player_camera() -> Camera3D:
	return get_node_or_null("CameraHolder/CameraRecoilHolder/Camera") as Camera3D


func reset_zoom() -> void :
	_is_squinting = false
	var camera: = _get_player_camera()
	if camera != null:
		camera.fov = _get_default_fov_target()


func _gui_text_field_has_focus() -> bool:
	var focus: Control = get_viewport().gui_get_focus_owner() as Control
	if focus == null:
		return false
	return focus is LineEdit or focus is TextEdit


func _toggle_flashlight() -> void :
	var fl: = get_node_or_null("CameraHolder/CameraRecoilHolder/Camera/Flashlight") as SpotLight3D
	if fl:
		fl.visible = not fl.visible
		_play_flashlight_sfx()


func _play_flashlight_sfx() -> void :
	var audio: = AudioStreamPlayer.new()
	add_child(audio)
	audio.bus = "Sfx"
	audio.stream = SFX_FLASHLIGHT
	audio.play()
	audio.finished.connect(audio.queue_free)


## In a multiplayer session the pause menu deliberately does NOT pause the
## SceneTree (that would freeze the shared world for one player and stall
## every synchronizer on this machine), so the menu has to block gameplay
## input the way the freeze used to.
func _is_menu_blocking_input() -> bool:
	if NetworkManager == null or not NetworkManager.is_active:
		return false
	return PauseMenu != null and PauseMenu.has_method("is_menu_paused")\
		and PauseMenu.is_menu_paused()


func _unhandled_input(event: InputEvent) -> void :
	if not is_local_player():
		return
	if _is_menu_blocking_input():
		return
	if Input.is_action_just_pressed("flashlight"):
		var focus: Control = get_viewport().gui_get_focus_owner()
		if focus != null and (focus is LineEdit or focus is TextEdit):
			return
		_toggle_flashlight()
		get_viewport().set_input_as_handled()
		return
	if _is_dialogue_blocking_holster():
		return


	if GameManager != null and GameManager.has_method("is_minigame_active")\
	and GameManager.is_minigame_active():
		return


	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if not _is_holstered():
		return

	if (event is InputEventKey and event.pressed and not event.echo\
	and event.keycode == KEY_C)\
	or (event is InputEventJoypadButton and event.pressed\
	and event.button_index == JOY_BUTTON_RIGHT_STICK):
		_cycle_hand_gesture()
		get_viewport().set_input_as_handled()
		return
	if not Input.is_action_just_pressed("shoot"):
		return

	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_hand_use_time < HAND_USE_COOLDOWN:
		return
	_last_hand_use_time = now
	_hand_interact_pending = true


func _is_holstered() -> bool:
	var wm: Node = get_node_or_null(weapon_controller_path)
	if wm == null:
		return false
	if wm.has_method("get_current_weapon_id"):
		return wm.get_current_weapon_id() == 0
	return false


func _is_dialogue_blocking_holster() -> bool:
	return DialogueUI != null\
	and DialogueUI.has_method("is_open")\
	and DialogueUI.is_open()


func _hand_raycast_interact() -> void :
	var interactable: Node = _raycast_hand_interactable()
	if interactable == null:

		_use_holster_gesture_on_press()
		return
	if interactable.has_method("hand_interact"):
		interactable.hand_interact()
	SfxManager.play("ui_blip")






func _ensure_hand_gestures() -> void :
	if not _hand_gestures.is_empty():
		return


	_hand_gestures = [
		{"tex": HAND_MIDFINGER_TEX, "kind": "midfinger"}, 
	]


	if _has_supporter_gestures():
		_hand_gestures.append_array([
			{"tex": HAND_OKSIGN_TEX, "kind": "ok"}, 
			{"tex": HAND_PEACE_TEX, "kind": "peace"}, 
			{"tex": HAND_PISTOL_TEX, "kind": "fingergun"}, 
			{"tex": HAND_PALM_TEX, "kind": "palmopen"}, 
			{"tex": HAND_PALMAWAY_TEX, "kind": "palmaway"}, 
		])


	_gesture_index = _gesture_index_of_kind("midfinger")




func _has_supporter_gestures() -> bool:
	return GameManager != null and GameManager.has_method("is_supporter_gestures_active")\
	and GameManager.is_supporter_gestures_active()



func _gesture_index_of_kind(kind: String) -> int:
	for i in _hand_gestures.size():
		if String((_hand_gestures[i] as Dictionary).get("kind", "")) == kind:
			return i
	return 0


func _current_gesture() -> Dictionary:
	_ensure_hand_gestures()
	return _hand_gestures[_gesture_index]


func _cycle_hand_gesture() -> void :
	_ensure_hand_gestures()
	_gesture_index = (_gesture_index + 1) % _hand_gestures.size()
	SfxManager.play("ui_blip", -6.0)
	_shake_hand()



func _shake_hand() -> void :
	var sprite: Sprite3D = _get_hand_sprite()
	if sprite == null:
		return
	if _hand_anim_tween != null and _hand_anim_tween.is_valid():
		_hand_anim_tween.kill()
	_hand_anim_tween = create_tween()
	_hand_anim_tween.tween_property(sprite, "rotation_degrees:z", -10.0, 0.05)
	_hand_anim_tween.tween_property(sprite, "rotation_degrees:z", 8.0, 0.06)
	_hand_anim_tween.tween_property(sprite, "rotation_degrees:z", 0.0, 0.05)



func _use_holster_gesture_on_press() -> void :
	if String(_current_gesture().get("kind", "")) == "fingergun":
		_play_mouthedpew()
		_fingergun_recoil()



func _fingergun_recoil() -> void :
	var sprite: Sprite3D = _get_hand_sprite()
	if sprite == null:
		return
	if _hand_anim_tween != null and _hand_anim_tween.is_valid():
		_hand_anim_tween.kill()


	if not _hand_rest_captured:
		_hand_rest_y = sprite.position.y
		_hand_rest_captured = true
	sprite.position.y = _hand_rest_y
	_hand_anim_tween = create_tween()
	_hand_anim_tween.tween_property(sprite, "position:y", _hand_rest_y + 0.035, 0.04)\
	.set_ease(Tween.EASE_OUT)
	_hand_anim_tween.tween_property(sprite, "position:y", _hand_rest_y, 0.18)\
	.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _play_mouthedpew() -> void :
	if PEW_SOUNDS.is_empty():
		return

	var i: = _last_pew_index
	if PEW_SOUNDS.size() == 1:
		i = 0
	else:
		while i == _last_pew_index:
			i = randi() % PEW_SOUNDS.size()
	_last_pew_index = i
	var p: = AudioStreamPlayer.new()
	p.stream = PEW_SOUNDS[i]
	p.bus = "Sfx"
	p.volume_db = -7.0
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func _raycast_hand_interactable() -> Node:
	if not is_inside_tree():
		return null
	var cam: Camera3D = get_node_or_null(
		"CameraHolder/CameraRecoilHolder/Camera") as Camera3D
	if cam == null:
		return null
	var space: PhysicsDirectSpaceState3D = _get_hand_raycast_space(cam)
	if space == null:
		return null
	var origin: Vector3 = cam.global_position
	var target: Vector3 = origin + - cam.global_transform.basis.z * HAND_RAYCAST_DISTANCE
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, target)
	query.collide_with_areas = true
	query.exclude = [get_rid()]
	var result: Dictionary = space.intersect_ray(query)
	if result.is_empty():
		return null
	var hit: Node = result.get("collider") as Node
	if hit == null:
		return null
	var node: Node = hit
	while node != null:
		if node.is_in_group("HandInteractable"):
			return node
		node = node.get_parent()
	return null


## Every path through here also records the result in net_hand_gesture, so the
## hand other players see always matches the one on your own screen.
func _set_hand_texture(sprite: Sprite3D, tex: Texture2D) -> void :
	sprite.texture = tex
	net_hand_gesture = _net_hand_index_for(tex)


func _update_holster_hand_gesture() -> void :
	var sprite: Sprite3D = _get_hand_sprite()
	if sprite == null:
		return

	if DialogueUI != null and DialogueUI.has_method("is_open") and DialogueUI.is_open():
		_set_hand_texture(sprite, HAND_FIST_TEX)
		return


	if GameManager != null and GameManager.has_method("is_minigame_active")\
	and GameManager.is_minigame_active():
		_set_hand_texture(sprite, HAND_FIST_TEX)
		return



	if not Input.is_action_pressed("shoot"):
		var idle_g: Dictionary = _current_gesture()
		if String(idle_g.get("kind", "")) == "fingergun":
			_set_hand_texture(sprite, idle_g.get("tex", HAND_FIST_TEX) as Texture2D)
		else:
			_set_hand_texture(sprite, HAND_FIST_TEX)
		return


	if _raycast_hand_interactable() != null:
		_set_hand_texture(sprite, HAND_PALM_TEX)
		return



	var g: Dictionary = _current_gesture()
	_set_hand_texture(sprite, g.get("tex", HAND_FIST_TEX) as Texture2D)
	if String(g.get("kind", "")) == "midfinger":
		_try_finger_react()








const FINGER_REACT_FACING_DOT: = 0.9

func _try_finger_react() -> void :
	var cam: Camera3D = get_node_or_null(
		"CameraHolder/CameraRecoilHolder/Camera") as Camera3D
	if cam == null:
		return
	var cam_pos: Vector3 = cam.global_position
	var cam_fwd: Vector3 = - cam.global_transform.basis.z
	var best: Node = null
	var best_dist: float = FINGER_REACT_DISTANCE


	for npc in get_tree().get_nodes_in_group("FingerReactable"):
		if npc == null or not is_instance_valid(npc):
			continue
		if not (npc is Node3D) or not npc.has_method("react_to_finger"):
			continue
		var npc3d: Node3D = npc as Node3D
		var to_npc: Vector3 = (npc3d.global_position + Vector3(0, 1.2, 0)) - cam_pos
		var dist: float = to_npc.length()
		if dist < 0.05 or dist > best_dist:
			continue
		if to_npc.normalized().dot(cam_fwd) < FINGER_REACT_FACING_DOT:
			continue
		best_dist = dist
		best = npc
	if best != null:
		best.call("react_to_finger")

		if AchievementManager != null:
			var fid: Variant = best.get("npc_id")
			if fid != null:
				AchievementManager.on_flipped_off(str(fid))


func _get_hand_sprite() -> Sprite3D:
	return get_node_or_null(HAND_SPRITE_PATH) as Sprite3D


func _get_hand_raycast_space(cam: Camera3D) -> PhysicsDirectSpaceState3D:
	var cam_world: World3D = cam.get_world_3d()
	if cam_world != null and cam_world.direct_space_state != null:
		return cam_world.direct_space_state
	if is_inside_tree():
		var node_world: World3D = get_world_3d()
		if node_world != null and node_world.direct_space_state != null:
			return node_world.direct_space_state
	return null


func _input(event: InputEvent) -> void :
	if not is_local_player():
		return
	if not is_sitting:
		return
	if event.is_action_pressed("jump") or event.is_action_pressed("crouch") or event.is_action_pressed("run") or event.is_action_pressed("carry_object"):
		get_viewport().set_input_as_handled()


func _physics_process(_delta: float):
	if not is_local_player():
		# Remote player: position/velocity/camera are driven by the
		# MultiplayerSynchronizer (see multiplayer/player_net.gd), not by
		# local simulation. Skip Input polling and move_and_slide() entirely.
		return
	if is_sitting:
		_hand_interact_pending = false
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y = 0.0
		move_and_slide()
		return
	if _hand_interact_pending:
		_hand_interact_pending = false
		if _is_holstered() and not _is_dialogue_blocking_holster():
			_hand_raycast_interact()
	if _is_holstered() and not _is_dialogue_blocking_holster():
		_update_holster_hand_gesture()
	_update_pickup_hint()
	if Input.is_action_just_pressed("carry_object"):
		_toggle_carry()
	_update_carried_object()
	if movement_frozen:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	modifyPhysicsProperties()
	_apply_external_knockback(_delta)
	_update_squint_fov(_delta)

	move_and_slide()


func apply_external_knockback(impulse: Vector3) -> void :
	_external_knockback += impulse


func _apply_external_knockback(delta: float) -> void :
	if _external_knockback.length_squared() <= 0.0001:
		return
	velocity += _external_knockback
	_external_knockback = _external_knockback.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)

func displayProperties():

	if hud != null:
		hud.displayCurrentState(stateMachine.currStateName)
		hud.displayCurrentDirection(moveDirection)
		hud.displayDesiredMoveSpeed(desiredMoveSpeed)
		hud.displayVelocity(velocity.length())
		hud.displayNbJumpsInAirAllowed(nbJumpsInAirAllowed)

func modifyPhysicsProperties():
	lastFramePosition = position
	lastFrameVelocity = velocity
	wasOnFloor = !is_on_floor()


func get_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func update_move_input() -> void :
	inputDirection = Input.get_vector(moveLeftAction, moveRightAction, moveForwardAction, moveBackwardAction)
	moveDirection = (camHolder.global_basis * Vector3(inputDirection.x, 0.0, inputDirection.y)).normalized()


func get_air_max_speed() -> float:
	return maxSpeed * air_max_speed_scale


func clamp_air_horizontal_speed() -> void :
	if is_on_floor():
		return
	var cap: float = get_air_max_speed()
	var horiz: Vector2 = Vector2(velocity.x, velocity.z)
	var speed: float = horiz.length()
	if speed <= cap:
		return
	horiz = horiz * (cap / speed)
	velocity.x = horiz.x
	velocity.z = horiz.y


func apply_air_acceleration(delta: float) -> void :
	if is_on_floor() or moveDirection == Vector3.ZERO:
		return
	var wishdir: Vector3 = moveDirection
	var wishspeed: float = runSpeed
	var horiz_vel: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var currentspeed: float = horiz_vel.dot(wishdir)
	var addspeed: float = wishspeed - currentspeed
	if addspeed <= 0.0:
		clamp_air_horizontal_speed()
		desiredMoveSpeed = get_horizontal_speed()
		return
	var accelspeed: float = minf(air_accel * delta * wishspeed, addspeed)
	velocity.x += accelspeed * wishdir.x
	velocity.z += accelspeed * wishdir.z
	clamp_air_horizontal_speed()
	desiredMoveSpeed = get_horizontal_speed()


func gs_accelerate(wishdir: Vector3, wishspeed: float, accel: float, delta: float) -> void :
	var current_speed: float = Vector3(velocity.x, 0.0, velocity.z).dot(wishdir)
	var add_speed: float = wishspeed - current_speed
	if add_speed <= 0.0:
		return
	var accel_speed: float = minf(accel * delta * wishspeed, add_speed)
	velocity.x += accel_speed * wishdir.x
	velocity.z += accel_speed * wishdir.z


func gs_airaccelerate(wishdir: Vector3, wishspeed: float, accel: float, delta: float) -> void :
	var wishspd: float = minf(wishspeed, gs_max_air_speed)
	var current_speed: float = Vector3(velocity.x, 0.0, velocity.z).dot(wishdir)
	var add_speed: float = wishspd - current_speed
	if add_speed <= 0.0:
		return
	var accel_speed: float = minf(accel * delta * wishspeed, add_speed)
	velocity.x += accel_speed * wishdir.x
	velocity.z += accel_speed * wishdir.z


func gs_apply_friction(t: float, delta: float) -> void :
	var speed: float = Vector2(velocity.x, velocity.z).length()
	if speed < 0.1:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var control: float = maxf(speed, gs_stop_speed)
	var drop: float = control * gs_friction_val * delta * t
	var new_speed: float = maxf(speed - drop, 0.0) / speed
	velocity.x *= new_speed
	velocity.z *= new_speed


func gravityApply(delta: float):


	if !is_on_floor():
		if velocity.y >= 0.0: velocity.y += jumpGravity * delta
		elif velocity.y < 0.0: velocity.y += fallGravity * delta


func _on_damage_taken(_current_health: float, _damage_taken: float):
	_refresh_health_ui()
	var pain: AudioStreamPlayer = get_node_or_null("PainAudio") as AudioStreamPlayer
	if pain != null and not pain.playing and not PAIN_SOUNDS.is_empty():
		pain.stream = PAIN_SOUNDS[randi() % PAIN_SOUNDS.size()]
		pain.volume_db = 0.0
		pain.play()
	var overlay: = get_node_or_null("DamageFlashLayer/DamageOverlay") as ColorRect
	if overlay == null:
		return
	var c: = overlay.color
	c.a = 0.4
	overlay.color = c
	var tw: = create_tween()
	tw.tween_property(overlay, "color:a", 0.0, 0.4)


func _on_consumable_used(item_id: String):
	if not health_component:
		return
	var heal_amount: = 0.0
	match item_id:
		"painkillers":
			heal_amount = 20.0
		"god_morgen_yoghurt":
			heal_amount = 35.0
		"kefir":
			return
		_:
			return
	health_component.heal(heal_amount)
	SfxManager.play("player_heal")
	_refresh_health_ui()


func _refresh_health_ui() -> void :
	if not health_component:
		return
	var current_hp: = int(clamp(health_component.current_health, 0.0, health_component.max_health))
	if ui_stats and ui_stats.has_method("refresh_health_fill"):
		ui_stats.refresh_health_fill(current_hp, health_component.max_health)
	elif health_bar:
		health_bar.max_value = health_component.max_health
		health_bar.value = current_hp
		var fill: = StyleBoxFlat.new()
		fill.bg_color = Color(0.75, 0.12, 0.12, 1.0) if current_hp < 30 else Color(0.23, 0.76, 0.27, 1.0)
		health_bar.add_theme_stylebox_override("fill", fill)


func _on_player_death():
	if MinigameManager and MinigameManager.should_handle_death():
		MinigameManager.handle_player_death(self)
		return
	SfxManager.play("player_death")
	if DialogueUI and DialogueUI.is_open():
		DialogueUI.close()
	movement_frozen = true
	camera_frozen = true
	velocity = Vector3.ZERO
	set_weapon_active(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var death_screen: = DEATH_SCREEN_SCENE.instantiate()
	get_tree().root.add_child(death_screen)

func _on_minigame_started(_minigame_id: String):
	set_weapon_active(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_minigame_ended(_minigame_id: String, _score: int):
	if DialogueUI and DialogueUI.is_open():
		return
	if dialogue_waiting_for_button:
		return
	if _can_show_weapon():
		set_weapon_active(true)
	if should_use_fps_mouse_capture():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

var _debug_cinematic_active: bool = false
var _weapon_active_before_cinematic: bool = true


func set_debug_cinematic_view(active: bool, fov: float = -1.0, show_hands: bool = false) -> void :
	if active == _debug_cinematic_active:
		if fov >= 0.0:
			set_debug_cinematic_fov(fov)
		return
	_debug_cinematic_active = active
	var cam: = camHolder as CameraObject
	if cam:
		cam.set_debug_cinematic(active, fov)
	if hud:
		hud.visible = not active
	var quest_hud: = get_node_or_null("QuestHud") as CanvasLayer
	if quest_hud:
		quest_hud.visible = not active
	if active:
		_weapon_active_before_cinematic = _weapon_active
		set_weapon_active(show_hands)
	else:
		set_weapon_active(_weapon_active_before_cinematic)


func set_debug_cinematic_fov(fov: float) -> void :
	var cam: = camHolder as CameraObject
	if cam:
		cam.set_debug_cinematic_fov(fov)


func set_weapon_active(enabled: bool):
	if weapon_manager == null:
		weapon_manager = get_node_or_null(weapon_controller_path)
	if weapon_manager == null:
		return
	if _weapon_active == enabled:
		return

	if not enabled:
		if weapon_manager.has_method("get_current_weapon_model"):
			_previously_active_weapon = weapon_manager.get_current_weapon_model()
		if weapon_manager.has_method("hide_all_weapon_models"):
			weapon_manager.hide_all_weapon_models()
		elif weapon_manager.has_method("set_weapon_visible"):
			weapon_manager.set_weapon_visible(false)
		if weapon_manager.has_method("set_weapon_controls_enabled"):
			weapon_manager.set_weapon_controls_enabled(false)
		weapon_manager.set_process(false)
		weapon_manager.set_physics_process(false)
		weapon_manager.set_process_input(false)
		_weapon_active = false
	else:
		if weapon_manager.has_method("hide_all_weapon_models"):
			weapon_manager.hide_all_weapon_models()
		var model_to_show: Node = _previously_active_weapon
		if weapon_manager.has_method("get_current_weapon_model"):
			var current = weapon_manager.get_current_weapon_model()
			if current != null:
				model_to_show = current
		if model_to_show != null and weapon_manager.has_method("show_weapon_model"):
			weapon_manager.show_weapon_model(model_to_show)
		elif weapon_manager.has_method("set_weapon_visible"):
			weapon_manager.set_weapon_visible(true)
		if weapon_manager.has_method("reset_current_weapon_mesh_visibility"):
			weapon_manager.reset_current_weapon_mesh_visibility()
		if weapon_manager.has_method("set_weapon_controls_enabled"):
			weapon_manager.set_weapon_controls_enabled(true)
		weapon_manager.set_process(true)
		weapon_manager.set_physics_process(true)
		weapon_manager.set_process_input(true)
		_weapon_active = true

func _setup_pickup_prompt() -> void :
	pickup_prompt = get_node_or_null("HUD/PickupPrompt") as Label
	if pickup_prompt:
		pickup_prompt.visible = false


func _update_pickup_hint() -> void :
	if pickup_prompt == null:
		return
	if is_sitting or movement_frozen or camera_frozen or dialogue_waiting_for_button:
		pickup_prompt.visible = false
		return

	if has_carried_object():
		pickup_prompt.text = "F — Slipp"
		pickup_prompt.visible = true
		return
	var viewport_camera: Camera3D = get_viewport().get_camera_3d()
	if viewport_camera == null:
		pickup_prompt.visible = false
		return
	var from: Vector3 = viewport_camera.global_transform.origin
	var to: Vector3 = from + ( - viewport_camera.global_transform.basis.z * CARRY_MAX_DISTANCE)
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.exclude = [self]
	var result: Dictionary = space_state.intersect_ray(query)
	if result.is_empty():
		pickup_prompt.visible = false
		return
	var collider: Variant = result.get("collider")
	if collider is RigidBody3D and (collider as RigidBody3D).is_in_group("Carriable"):
		pickup_prompt.text = "F — Plukk opp"
		pickup_prompt.visible = true
	else:
		pickup_prompt.visible = false



func has_carried_object() -> bool:
	return carried_object != null

func get_carried_object() -> RigidBody3D:
	return carried_object

func _toggle_carry():
	if carried_object:
		_drop_item()
		return
	_try_pickup_carriable()


## Makes a carried prop visible moving in others' games too. This only runs
## on the carrier's own process (_try_pickup_carriable is gated to the local
## player already), and only works if `body`'s NodePath is the same on
## every peer — true for anything baked into a scene, and for freezer/shelf
## spawns since those were given deterministic names (see
## components/quest/freezer.gd / shelf_section.gd). A carriable spawned with
## a non-deterministic name won't sync; it'll just look frozen in place on
## other peers' screens until dropped.
func _ensure_carriable_sync(body: RigidBody3D) -> void:
	if NetworkManager == null or not NetworkManager.is_active:
		return
	body.set_multiplayer_authority(get_multiplayer_authority())
	if body.get_node_or_null("CarriableSync") != null:
		return
	var config: SceneReplicationConfig = SceneReplicationConfig.new()
	for prop in [".:position", ".:rotation"]:
		var path: NodePath = NodePath(prop)
		config.add_property(path)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	var sync: MultiplayerSynchronizer = MultiplayerSynchronizer.new()
	sync.name = "CarriableSync"
	sync.replication_config = config
	body.add_child(sync)

func _try_pickup_carriable():
	var viewport_camera: Camera3D = get_viewport().get_camera_3d()
	if viewport_camera == null:
		return
	var from: Vector3 = viewport_camera.global_transform.origin
	var to: Vector3 = from + ( - viewport_camera.global_transform.basis.z * CARRY_MAX_DISTANCE)
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.exclude = [self]
	var result: Dictionary = space_state.intersect_ray(query)
	if result.is_empty():
		return
	var collider: Variant = result.get("collider")
	if not (collider is RigidBody3D):
		return
	var body: RigidBody3D = collider as RigidBody3D
	if not body.is_in_group("Carriable"):
		return
	CarriablePickup.save_physics_before_carry(body)
	carried_object = body
	carried_object.freeze = true
	carried_object.collision_layer = 0
	carried_object.collision_mask = 0
	carried_object.linear_velocity = Vector3.ZERO
	_ensure_carriable_sync(carried_object)
	carried_object.angular_velocity = Vector3.ZERO
	if carried_object.has_method("on_picked_up"):
		carried_object.on_picked_up()
	set_weapon_active(false)

func _update_carried_object():
	if carried_object == null:
		return
	if not is_instance_valid(carried_object):
		carried_object = null
		if _can_show_weapon():
			set_weapon_active(true)
		return
	var viewport_camera: Camera3D = get_viewport().get_camera_3d()
	if viewport_camera == null:
		return


	var hold_dist: float = CARRY_HOLD_DISTANCE
	var custom_dist: Variant = carried_object.get("carry_hold_distance")
	if custom_dist != null:
		hold_dist = float(custom_dist)
	var target_pos: Vector3 = viewport_camera.global_transform.origin + ( - viewport_camera.global_transform.basis.z * hold_dist)
	carried_object.global_position = carried_object.global_position.lerp(target_pos, CARRY_LERP_WEIGHT)
	carried_object.linear_velocity = Vector3.ZERO
	carried_object.angular_velocity = Vector3.ZERO

func _drop_item():
	if carried_object == null:
		return
	if is_instance_valid(carried_object):
		if carried_object.has_method("on_dropped"):
			carried_object.on_dropped()
		carried_object.freeze = false
		CarriablePickup.restore_physics_after_drop(carried_object)
	carried_object = null
	if _can_show_weapon():
		set_weapon_active(true)

func _drop_carried_object():
	_drop_item()

func _can_show_weapon() -> bool:
	if is_sitting or movement_frozen or camera_frozen:
		return false
	var current_scene: Node = get_tree().current_scene
	if current_scene != null:
		var inventory_panel: Node = current_scene.get_node_or_null("InventoryPanel")
		if inventory_panel != null and inventory_panel.has_method("get"):
			if bool(inventory_panel.get("is_open")):
				return false
	return true

func freeze_for_dialogue(frozen: bool):
	if not frozen and dialogue_waiting_for_button:
		return
	movement_frozen = frozen
	camera_frozen = frozen
	if frozen:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		velocity = Vector3.ZERO
	else:
		if should_use_fps_mouse_capture():
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func set_dialogue_waiting_for_button(waiting: bool):
	dialogue_waiting_for_button = waiting
	if waiting:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func sit_at_stand(sitting: bool) -> void :
	is_sitting = sitting
	movement_frozen = sitting
	camera_frozen = false
	if sitting:
		velocity = Vector3.ZERO
		_force_stand_up()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		set_weapon_active(false)
	else:
		if stateMachine and stateMachine.has_method("transition_to"):
			stateMachine.transition_to("WalkState")
		if should_use_fps_mouse_capture():
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		if _can_show_weapon():
			set_weapon_active(true)


func _force_stand_up() -> void :
	if stateMachine and stateMachine.has_method("transition_to"):
		if stateMachine.currStateName == "Crouch":
			stateMachine.transition_to("WalkState")
	var cap: = hitbox.shape as CapsuleShape3D
	if cap:
		cap.height = baseHitboxHeight
	if model:
		model.scale.y = baseModelHeight


func set_sitting_at_stand(sitting: bool, _look_target: Vector3 = Vector3.ZERO) -> void :
	sit_at_stand(sitting)


func apply_mouse_sensitivity_from_settings() -> void :
	if camHolder and camHolder.has_method("apply_sensitivity_multiplier"):
		camHolder.apply_sensitivity_multiplier()

func get_carried_icecream_count() -> int:
	return carried_icecream_count

func try_pickup_icecream() -> bool:
	if carried_icecream_count >= 2:
		return false
	carried_icecream_count += 1
	return true

func take_carried_icecream(amount: int) -> int:
	var taken = min(max(0, amount), carried_icecream_count)
	carried_icecream_count -= taken
	return taken

func add_ammo_to_inventory(ammo_type: String, amount: int) -> int:
	if amount <= 0:
		return 0
	if weapon_manager == null:
		weapon_manager = get_node_or_null(weapon_controller_path)
	if weapon_manager == null:
		return 0
	var ammo_manager: Node = weapon_manager.get("ammoManager")
	if ammo_manager == null:
		return 0
	var ammo_dict: Dictionary = ammo_manager.get("ammoDict")
	var max_dict: Dictionary = ammo_manager.get("maxNbPerAmmoDict")
	if not ammo_dict.has(ammo_type) or not max_dict.has(ammo_type):
		return 0
	var current: int = int(ammo_dict.get(ammo_type, 0))
	var max_amount: int = int(max_dict.get(ammo_type, current))
	var next_amount: int = min(max_amount, current + amount)
	var added: int = max(0, next_amount - current)
	ammo_dict[ammo_type] = next_amount
	if added > 0:
		_ItemNotification.notify_ammo_pickup(get_tree(), ammo_type, added)
	return added
