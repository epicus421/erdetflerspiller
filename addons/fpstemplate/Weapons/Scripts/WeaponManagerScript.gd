extends Node3D



const HOLSTER_WEAPON_ID: = 0

const HAND_FIST: Texture2D = preload("res://assets/textures/images/hand_fist.png")
const HAND_MIDFINGER: Texture2D = preload("res://assets/textures/images/hand_midfinger.png")


const BREAD_MOLDED_TEX: Texture2D = preload("res://assets/props/glb/bread_brod_mold.jpg")
const BREAD_SKIN_ID: = "supporter_molded_bread"
const BREAD_MODEL_PATH: = "WeaponContainer/GrusSkive/GrusSkiveModel/BrødSkive2"

@export var debug_weapons: bool = true

var weaponStack: Array[int] = []
var weaponList: Dictionary = {}
@export var weaponResources: Array[WeaponResource]
@export var startWeapons: Array[WeaponSlot]

var cW = null
var cWModel = null
var weaponIndex: int = 0


var canChangeWeapons: bool = true
var canUseWeapon: bool = true
var _hand_sprite: Sprite3D = null
@export_group("Keybind variables")
@export var shoot_action: String
@export var reload_action: String
@export var weapon_wheel_up_action: String
@export var weapon_wheel_down_action: String

@onready var playChar: CharacterBody3D = $"../../../.."
@onready var cameraHolder: Node3D = %CameraHolder
@onready var cameraRecoilHolder: Node3D = %CameraRecoilHolder
@onready var camera: Camera3D = %Camera
@onready var weaponContainer: Node3D = %WeaponContainer
@onready var shootManager: Node3D = %ShootManager
@onready var reloadManager: Node3D = %ReloadManager
@onready var ammoManager: Node3D = %AmmunitionManager
@onready var animPlayer: AnimationPlayer = %AnimationPlayer
@onready var animManager: Node3D = %AnimationManager
@onready var audioManager: PackedScene = preload("../../Misc/Scenes/AudioManagerScene.tscn")
@onready var bulletDecal: PackedScene = preload("../../Weapons/Scenes/BulletDecalScene.tscn")
@onready var hud: CanvasLayer = %HUD
@onready var linkComponent: Node3D = %LinkComponent


func _wm_debug(msg: String) -> void :
	if debug_weapons:
		print("[WeaponManager] %s" % msg)


func _wm_debug_state(context: String) -> void :
	if not debug_weapons:
		return
	var cur_id: = -1
	var cur_name: = "null"
	if cW != null and is_instance_valid(cW):
		cur_id = int(cW.weaponId)
		cur_name = str(cW.weaponName)
	var model_vis: = "null"
	if cWModel != null and is_instance_valid(cWModel):
		model_vis = str(cWModel.visible)
	var slot_vis: = _wm_grusskive_slot_visible_text()
	_wm_debug(
		"%s | stack=%s index=%s cur=%s(%s) cWModel.vis=%s GrusSkive.slot.vis=%s canChange=%s canUse=%s"
		%[context, weaponStack, weaponIndex, cur_id, cur_name, model_vis, slot_vis, canChangeWeapons, canUseWeapon]
	)















func _force_finish_current_weapon_anim() -> void :
	if animPlayer == null:
		return
	var anim_name: = animPlayer.current_animation
	if anim_name == "":
		return
	var anim: = animPlayer.get_animation(anim_name)
	if anim == null:
		return
	animPlayer.seek(anim.length, true)


func _wm_grusskive_slot_visible_text() -> String:
	var slot: = get_node_or_null("WeaponContainer/GrusSkive") as Node3D
	if slot == null:
		return "missing"
	return str(slot.visible)





var _grus_gravel: Node3D = null
var _grus_gravel_home: Vector3 = Vector3.ZERO

func _ready():
	if not is_in_group("WeaponViewmodelController"):
		add_to_group("WeaponViewmodelController")
	if not is_in_group("WeaponManager"):
		add_to_group("WeaponManager")
	_hand_sprite = get_node_or_null("WeaponContainer/Holster/HolsterModel/HandSprite") as Sprite3D
	initialize()
	_grus_gravel = get_node_or_null("WeaponContainer/GrusSkive/GrusSkiveModel/CSGBox3D2") as Node3D
	if _grus_gravel != null:
		_grus_gravel_home = _grus_gravel.position

	# Weapons the party has already found are shared state, so mirror them onto
	# this body — both the ones unlocked from now on and any that were picked
	# up before we joined.
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_signal("weapon_unlocked")\
	and not gm.weapon_unlocked.is_connected(_on_party_weapon_unlocked):
		gm.weapon_unlocked.connect(_on_party_weapon_unlocked)
	if gm != null and "unlocked_weapons" in gm:
		for weapon_id in gm.unlocked_weapons:
			acquire_weapon_by_id(int(weapon_id), false)

func initialize():
	for weapon in weaponResources:
		if weapon == null:
			continue
		# Every PlayerCharacter instance is exported the SAME WeaponResource
		# .tres objects, and Godot hands out one shared instance per file. That
		# made mutable per-player state global across the whole lobby:
		#
		#   * `weaponSlot` is assigned below, so the last player to initialize
		#     won the pointer and everyone else's `cWModel` then referred to
		#     THAT player's weapon nodes — switching a weapon showed/hid the
		#     model on somebody else's body.
		#   * `isShooting` / `isReloading` are checked by changeWeapon(), so one
		#     player reloading froze weapon switching for everyone.
		#   * `totalAmmoInMag` was a single magazine shared by the party.
		#
		# A shallow duplicate keeps the heavy shared assets (meshes, sounds,
		# curves, PackedScenes) shared while giving this player its own mutable
		# fields. Also correct in single-player: the originals are cached
		# between playthroughs, so mutating them leaked ammo across restarts.
		var owned: WeaponResource = weapon.duplicate() as WeaponResource
		if owned == null:
			continue
		weaponList[owned.weaponId] = owned

	for weapo in weaponList.keys():

		cW = weaponList[weapo]

		for weaponSlot in weaponContainer.get_children():
			if weaponSlot.weaponId == cW.weaponId:


				for startWeapon in startWeapons:
					if startWeapon.weaponId == cW.weaponId:
						weaponStack.append(cW.weaponId)

				cW.weaponSlot = weaponSlot
				cWModel = cW.weaponSlot.model
				cWModel.visible = false

				forceAttackPointTransformValues(cW.weaponSlot.attackPoint)

				cW.bobPos = cW.position

	_ensure_holster_in_weapon_stack()
	_sync_starting_ammo_for_demo()

	if weaponStack.size() > 0:
		var start_index: = 0
		if weaponStack[0] == HOLSTER_WEAPON_ID and weaponStack.size() > 1:
			start_index = 1
		weaponIndex = start_index
		_wm_debug("initialize -> enterWeapon(%s) start_index=%s" % [weaponStack[start_index], start_index])
		enterWeapon(weaponStack[start_index])
	else:
		cW = null
		cWModel = null
		canUseWeapon = false
		canChangeWeapons = false
		_wm_debug("initialize -> empty weaponStack")
	_apply_bread_supporter_skin()
	_wm_debug_state("initialize done")





func _apply_bread_supporter_skin() -> void :
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm == null or not gm.has_method("is_skin_active"):
		return
	if not gm.is_skin_active(BREAD_SKIN_ID):
		return
	var bread: = get_node_or_null(BREAD_MODEL_PATH) as Node3D
	if bread == null:
		push_warning("[WeaponManager] Fant ikke brødskive-modellen for skin-bytte.")
		return
	var mesh: = _wm_find_first_mesh(bread)
	if mesh == null:
		return
	var base_mat: Material = mesh.get_active_material(0)
	var mat: BaseMaterial3D
	if base_mat is BaseMaterial3D:
		mat = (base_mat as BaseMaterial3D).duplicate() as BaseMaterial3D
	else:
		mat = StandardMaterial3D.new()
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.albedo_texture = BREAD_MOLDED_TEX
	mesh.material_override = mat


func _wm_find_first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found: = _wm_find_first_mesh(child)
		if found != null:
			return found
	return null

func exitWeapon(nextWeapon: int):


	_wm_debug("exitWeapon(%s) from %s" % [nextWeapon, get_current_weapon_id()])
	if cW == null or not is_instance_valid(cW):
		enterWeapon(nextWeapon)
		return
	if nextWeapon != cW.weaponId:
		canChangeWeapons = false
		canUseWeapon = false
		if cW.isShooting: cW.isShooting = false
		if cW.isReloading:
			cW.isReloading = false
			if cWModel != null:
				_reset_all_mesh_children_visible(cWModel)

		if cW.unequipAnimName != "":
			animManager.playAnimation("UnequipAnim%s" % cW.weaponName, cW.unequipAnimSpeed, false)
		await get_tree().create_timer(cW.unequipTime).timeout

		if not is_instance_valid(cW) or cWModel == null:
			enterWeapon(nextWeapon)
			return
		_force_finish_current_weapon_anim()
		cWModel.visible = false
		_wm_debug_state("exitWeapon before enterWeapon")
		enterWeapon(nextWeapon)

func enterWeapon(nextWeapon: int):


	_wm_debug("enterWeapon(%s)" % nextWeapon)
	cW = weaponList[nextWeapon]
	nextWeapon = 0
	cWModel = cW.weaponSlot.model
	if int(cW.weaponId) == HOLSTER_WEAPON_ID:
		if cWModel != null:
			cWModel.visible = true
		_show_holster_slot_visible()
	else:
		cWModel.visible = true
		_reset_all_mesh_children_visible(cWModel)

	shootManager.getCurrentWeapon(cW)
	reloadManager.getCurrentWeapon(cW)
	if cWModel != null:
		animManager.getCurrentWeapon(cW, cWModel)

	if int(cW.weaponId) != HOLSTER_WEAPON_ID:
		weaponSoundManagement(cW.equipSound, cW.equipSoundSpeed)

	animPlayer.playback_default_blend_time = cW.animBlendTime

	if cW.equipAnimName != "" and int(cW.weaponId) != HOLSTER_WEAPON_ID:




		if animPlayer != null:
			animPlayer.stop()
		animManager.playAnimation("EquipAnim%s" % cW.weaponName, cW.equipAnimSpeed, false)
	await get_tree().create_timer(cW.equipTime).timeout

	if not is_instance_valid(cW):
		return
	_force_finish_current_weapon_anim()
	if cW.isShooting: cW.isShooting = false
	if cW.isReloading: cW.isReloading = false


	canUseWeapon = not _is_dialogue_open()
	canChangeWeapons = canUseWeapon
	_wm_debug_state("enterWeapon done")

func _process(_delta: float):
	if cW != null and is_instance_valid(cW) and canUseWeapon:
		if int(cW.weaponId) != HOLSTER_WEAPON_ID and cWModel != null:
			reloadManager.autoReload()

	displayStats()
	_refresh_reserve_dependent_weapon_meshes()


func _physics_process(_delta: float) -> void :
	if cW != null and is_instance_valid(cW) and canUseWeapon:
		weaponInputs()


func weaponInputs():
	if _is_dialogue_open():
		return


	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("is_minigame_active") and gm.is_minigame_active():
		return
	if cW == null or not is_instance_valid(cW):
		return
	var is_holster: = int(cW.weaponId) == HOLSTER_WEAPON_ID
	if is_holster:
		pass
	else:
		if Input.is_action_pressed(shoot_action):
			if weaponStack.is_empty():
				pass
			elif shootManager.is_inside_tree() and not cW.isShooting:
				shootManager.shoot()
		if Input.is_action_just_pressed(reload_action):
			reloadManager.reload()

	if Input.is_action_just_pressed(weapon_wheel_up_action):
		_scroll_weapon_wheel(1)

	if Input.is_action_just_pressed(weapon_wheel_down_action):
		_scroll_weapon_wheel(-1)


func _scroll_weapon_wheel(direction: int) -> void :
	if _is_dialogue_open():
		return
	if weaponStack.is_empty():
		return
	if cW == null or not is_instance_valid(cW):
		return
	if not canChangeWeapons or cW.isShooting or cW.isReloading:
		_wm_debug("scroll blocked dir=%s canChange=%s shooting=%s reloading=%s" % [direction, canChangeWeapons, cW.isShooting, cW.isReloading])
		return
	var old_index: = weaponIndex
	weaponIndex = posmod(weaponIndex + direction, weaponStack.size())
	_wm_debug("scroll dir=%s index %s->%s targetId=%s" % [direction, old_index, weaponIndex, weaponStack[weaponIndex]])
	changeWeapon(weaponStack[weaponIndex])

func displayStats():
	if hud == null:
		return
	if cW == null or not is_instance_valid(cW) or ammoManager == null:
		hud.displayAmmo(0, 0)
		return
	if int(cW.weaponId) == HOLSTER_WEAPON_ID:
		hud.displayAmmo(0, 0)
		return
	var shots: = maxi(cW.nbProjShotsAtSameTime, 1)
	var mag: = int(float(cW.totalAmmoInMag) / float(shots))
	var reserve_total: int = ammoManager.ammoDict.get(cW.ammoType, 0)
	var reserve: = int(float(reserve_total) / float(shots))
	hud.displayAmmo(mag, reserve)

## `equip` is false when the weapon is arriving because a TEAMMATE picked it up
## (GameManager.weapon_unlocked). The party shares which weapons it has found,
## but yanking someone's gun out of their hands because a friend across the map
## grabbed a shotgun would be obnoxious — so they just gain access to it.
func acquire_weapon_by_id(weapon_id: int, equip: bool = true) -> void :

	if weapon_id == HOLSTER_WEAPON_ID:
		return
	if not weaponList.has(weapon_id):
		push_warning("Unknown weapon id: %s" % weapon_id)
		return
	if weapon_id in weaponStack:
		if not equip:
			return
		_wm_debug("acquire_weapon_by_id(%s) already in stack — re-equip" % weapon_id)
		weaponIndex = weaponStack.find(weapon_id)
		_instant_equip_weapon(weapon_id)
		_ensure_holster_in_weapon_stack()
		canUseWeapon = true
		canChangeWeapons = true
		_refresh_reserve_dependent_weapon_meshes()
		return
	var was_empty: = weaponStack.is_empty()
	weaponStack.append(weapon_id)
	_wm_debug("acquire_weapon_by_id(%s, equip=%s) stack now %s" % [weapon_id, equip, weaponStack])
	if was_empty:
		canUseWeapon = true
		canChangeWeapons = true

	if not equip:
		# Keep holding whatever we were holding; just make the new weapon
		# reachable on the wheel.
		_ensure_holster_in_weapon_stack()
		_refresh_reserve_dependent_weapon_meshes()
		return

	weaponIndex = weaponStack.size() - 1
	changeWeapon(weapon_id)
	if cW == null or not is_instance_valid(cW) or int(cW.weaponId) != weapon_id:
		_instant_equip_weapon(weapon_id)
		if weaponStack.has(weapon_id):
			weaponIndex = weaponStack.find(weapon_id)
	_ensure_holster_in_weapon_stack()
	canUseWeapon = true
	canChangeWeapons = true
	_refresh_reserve_dependent_weapon_meshes()


## Called by the pickup/shop/quest code on the player who actually took the
## weapon. Routes through GameManager so the unlock reaches every peer (and is
## replayed to anyone who joins later via the state snapshot); the local
## equip happens immediately so it feels instant.
func take_weapon_by_id(weapon_id: int) -> void :
	if weapon_id == HOLSTER_WEAPON_ID:
		return
	acquire_weapon_by_id(weapon_id, true)
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("unlock_weapon"):
		gm.unlock_weapon(weapon_id)


func _on_party_weapon_unlocked(weapon_id: int) -> void :
	# Only mirror onto the body this manager belongs to, and never steal the
	# player's current weapon.
	if playChar != null and playChar.has_method("is_local_player")\
	and not playChar.is_local_player():
		return
	acquire_weapon_by_id(weapon_id, false)


func _ensure_holster_in_weapon_stack() -> void :
	if not weaponList.has(HOLSTER_WEAPON_ID):
		return
	if HOLSTER_WEAPON_ID in weaponStack:
		weaponStack.erase(HOLSTER_WEAPON_ID)
	weaponStack.insert(0, HOLSTER_WEAPON_ID)
	if cW != null and is_instance_valid(cW) and weaponStack.has(int(cW.weaponId)):
		weaponIndex = weaponStack.find(int(cW.weaponId))
	elif weaponIndex >= weaponStack.size():
		weaponIndex = maxi(weaponStack.size() - 1, 0)
	_wm_debug("_ensure_holster_in_weapon_stack -> stack=%s index=%s" % [weaponStack, weaponIndex])


func _sync_starting_ammo_for_demo() -> void :
	if ammoManager == null:
		return
	for k in ammoManager.ammoDict.keys():
		ammoManager.ammoDict[k] = 0
	var pistol_res = weaponList.get(1)
	if pistol_res:
		var pm: = int(pistol_res.totalAmmoInMagRef)
		pistol_res.totalAmmoInMag = pm
		if ammoManager.ammoDict.has("pistol_ammo"):
			ammoManager.ammoDict["pistol_ammo"] = pm * 2
	var rpg_res = weaponList.get(5)
	if rpg_res:
		rpg_res.totalAmmoInMag = 0
	if ammoManager.ammoDict.has("rocket_ammo"):
		ammoManager.ammoDict["rocket_ammo"] = 0
	var grus_res = weaponList.get(6)
	if grus_res:
		grus_res.totalAmmoInMag = 0
	for wid in weaponList.keys():
		if wid == 1 or wid == 5 or wid == 6:
			continue
		var w = weaponList[wid]
		if w:
			w.totalAmmoInMag = int(w.totalAmmoInMagRef)


func _refresh_reserve_dependent_weapon_meshes() -> void :
	if ammoManager == null:
		return
	var rocket_node: = get_node_or_null("WeaponContainer/RocketLauncher/RocketMesh") as MeshInstance3D
	if rocket_node != null:
		var is_rpg: = cW != null and is_instance_valid(cW) and str(cW.weaponName) == "RocketLauncher"
		var total_rockets: int = int(ammoManager.ammoDict.get("rocket_ammo", 0))
		if is_rpg:
			total_rockets += int(cW.totalAmmoInMag)
		if total_rockets <= 0:
			rocket_node.visible = false
	_update_grusskive_visibility()


func _update_grusskive_visibility() -> void :



	var mesh: = get_node_or_null("WeaponContainer/GrusSkive/GrusSkiveModel/CSGBox3D2") as GeometryInstance3D
	if mesh == null or ammoManager == null:
		return
	var is_current: = cW != null and is_instance_valid(cW) and str(cW.weaponName) == "GrusSkive"
	var grus_reserve: int = int(ammoManager.ammoDict.get("grus_ammo", 0))
	var has_ammo: = grus_reserve > 0
	if is_current:
		has_ammo = has_ammo or int(cW.totalAmmoInMag) > 0
	var new_vis: = not (is_current and not has_ammo)
	if is_current and mesh.visible != new_vis:
		_wm_debug(
			"GrusSkive grus mesh vis %s->%s (mag=%s reserve=%s slot.vis=%s model.vis=%s)"
			%[mesh.visible, new_vis, cW.totalAmmoInMag, grus_reserve, _wm_grusskive_slot_visible_text(), cWModel.visible if cWModel != null else "null"]
		)
	mesh.visible = new_vis




	if _grus_gravel != null:
		var reloading_grus: bool = is_current and bool(cW.isReloading)
		if not reloading_grus:
			_grus_gravel.position = _grus_gravel_home


func changeWeapon(nextWeapon: int):
	_wm_debug("changeWeapon(%s) from %s" % [nextWeapon, get_current_weapon_id()])
	if cW == null or not is_instance_valid(cW):
		enterWeapon(nextWeapon)
		return
	if not canChangeWeapons or cW.isShooting or cW.isReloading:
		_wm_debug("changeWeapon blocked (shooting=%s reloading=%s)" % [cW.isShooting, cW.isReloading])
		return
	if int(cW.weaponId) == nextWeapon:
		_wm_debug("changeWeapon early return same id=%s" % nextWeapon)
		return
	if nextWeapon == HOLSTER_WEAPON_ID or int(cW.weaponId) == HOLSTER_WEAPON_ID:
		_wm_debug("changeWeapon -> instant (holster involved)")
		_instant_equip_weapon(nextWeapon)
		if weaponStack.has(nextWeapon):
			weaponIndex = weaponStack.find(nextWeapon)
		_wm_debug_state("changeWeapon instant done")
		return
	_wm_debug("changeWeapon -> async exitWeapon")
	exitWeapon(nextWeapon)

func displayMuzzleFlash():
	if not is_inside_tree():
		return
	if cW == null or not is_instance_valid(cW):
		return
	if cW.weaponSlot == null or cW.weaponSlot.muzzleFlashSpawner == null:
		return

	if cW.muzzleFlashRef != null:
		var muzzleFlashInstance = cW.muzzleFlashRef.instantiate()
		add_child(muzzleFlashInstance)
		muzzleFlashInstance.global_position = cW.weaponSlot.muzzleFlashSpawner.global_position
		muzzleFlashInstance.emitting = true
	else:
		push_error("%s doesn't have a muzzle flash reference" % cW.weaponName)
		return

func displayBulletHole(colliderPoint: Vector3, colliderNormal: Vector3, hit_collider: Node = null):
	if not is_inside_tree():
		return
	var bulletDecalInstance = bulletDecal.instantiate()
	var parent_node: Node = get_tree().get_root()
	if hit_collider != null and hit_collider is Node3D:
		var s: Vector3 = hit_collider.global_transform.basis.get_scale()
		if absf(s.x) < 5.0 and absf(s.y) < 5.0 and absf(s.z) < 5.0:
			parent_node = hit_collider
	parent_node.add_child(bulletDecalInstance)
	bulletDecalInstance.global_position = colliderPoint


	var up_vector: Vector3 = Vector3.UP
	if abs(colliderNormal.dot(Vector3.UP)) > 0.99:
		up_vector = Vector3.FORWARD

	bulletDecalInstance.look_at(colliderPoint - colliderNormal, up_vector)
	bulletDecalInstance.rotate_object_local(Vector3(1.0, 0.0, 0.0), 90)

func weaponSoundManagement(soundName: AudioStream, soundSpeed: float):
	if not is_inside_tree():
		return
	if cW == null or not is_instance_valid(cW) or cW.weaponSlot == null:
		return
	var tree: = get_tree()
	if tree == null:
		return
	var audioIns: AudioStreamPlayer3D = audioManager.instantiate()
	tree.root.add_child.call_deferred(audioIns)

	await tree.process_frame
	if not is_inside_tree() or not audioIns.is_inside_tree():
		if is_instance_valid(audioIns):
			audioIns.queue_free()
		return
	if cW.weaponSlot.attackPoint != null:
		audioIns.global_transform = cW.weaponSlot.attackPoint.global_transform
		audioIns.bus = "Sfx"
		audioIns.pitch_scale = soundSpeed
		audioIns.stream = soundName
		audioIns.play()
	else:
		print("The sound can't be played, AudioStreamPlayer3D instance is not in the scene tree")

func forceAttackPointTransformValues(attackPoint: Marker3D):

	if attackPoint.rotation != Vector3.ZERO: attackPoint.rotation = Vector3.ZERO

func set_weapon_controls_enabled(enabled: bool):
	canUseWeapon = enabled
	canChangeWeapons = enabled
	if cW != null and is_instance_valid(cW):
		if cW.isShooting:
			cW.isShooting = false
		if cW.isReloading:
			cW.isReloading = false

func set_weapon_visible(visible: bool):
	if visible:

		hide_all_weapon_models()
		if cWModel != null:
			cWModel.visible = true
	else:
		hide_all_weapon_models()

func get_current_weapon_model() -> Node:
	return cWModel


func get_current_weapon_id() -> int:
	if cW == null or not is_instance_valid(cW):
		return -1
	return int(cW.weaponId)


func holster_for_dialogue() -> void :
	_wm_debug("holster_for_dialogue from %s" % get_current_weapon_id())
	if cW == null or not is_instance_valid(cW):
		return
	if not weaponList.has(HOLSTER_WEAPON_ID):
		return
	if int(cW.weaponId) != HOLSTER_WEAPON_ID:
		if weaponStack.has(HOLSTER_WEAPON_ID):
			weaponIndex = weaponStack.find(HOLSTER_WEAPON_ID)
		_instant_equip_weapon(HOLSTER_WEAPON_ID, false)
	canUseWeapon = false
	canChangeWeapons = false


func restore_after_dialogue() -> void :
	if _is_dialogue_open():
		return
	canUseWeapon = true
	canChangeWeapons = true


func _is_dialogue_open() -> bool:
	var dui: Node = get_node_or_null("/root/DialogueUI")
	return dui != null and dui.has_method("is_open") and dui.is_open()


func _instant_equip_weapon(weapon_id: int, enable_controls: bool = true) -> void :
	_wm_debug("_instant_equip_weapon(%s) from %s" % [weapon_id, get_current_weapon_id()])
	if not weaponList.has(weapon_id):
		_wm_debug("_instant_equip_weapon unknown id=%s" % weapon_id)
		return


	_force_finish_current_weapon_anim()
	if cW != null and is_instance_valid(cW):
		if cW.isShooting:
			cW.isShooting = false
		if cW.isReloading:
			cW.isReloading = false
	if cWModel != null:
		cWModel.visible = false
	cW = weaponList[weapon_id]
	cWModel = cW.weaponSlot.model if cW.weaponSlot != null else null
	if cWModel != null:
		cWModel.visible = true
		var slot_parent: Node3D = cWModel.get_parent() as Node3D
		if slot_parent != null and slot_parent != weaponContainer:
			slot_parent.visible = true
		if weapon_id != HOLSTER_WEAPON_ID:
			_reset_all_mesh_children_visible(cWModel)
		elif _hand_sprite != null:
			_hand_sprite.texture = HAND_FIST
	shootManager.getCurrentWeapon(cW)
	reloadManager.getCurrentWeapon(cW)
	if cWModel != null:
		animManager.getCurrentWeapon(cW, cWModel)
	if enable_controls:
		canUseWeapon = true
		canChangeWeapons = true
	_wm_debug_state("_instant_equip_weapon done")


func _show_holster_slot_visible() -> void :
	if cW != null and cW.weaponSlot != null:
		cW.weaponSlot.visible = true
	if _hand_sprite != null:
		_hand_sprite.texture = HAND_FIST


func _update_holster_hand_gesture() -> void :
	if _hand_sprite == null:
		return
	if not Input.is_action_pressed(shoot_action):
		_hand_sprite.texture = HAND_FIST


func hide_all_weapon_models():
	for weapon_slot in weaponContainer.get_children():
		if weapon_slot != null and weapon_slot.model != null:
			weapon_slot.model.visible = false

func show_weapon_model(model: Node):
	if model != null and model is Node3D:
		model.visible = true
		_reset_all_mesh_children_visible(model)

func reset_current_weapon_mesh_visibility():
	if cWModel != null:
		_reset_all_mesh_children_visible(cWModel)

func _reset_all_mesh_children_visible(model: Node):
	if model == null:
		return
	for child in model.get_children():
		if child is MeshInstance3D:
			child.visible = true
