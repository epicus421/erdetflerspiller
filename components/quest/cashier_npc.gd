extends Node3D

@export var checkout_zone: NodePath
@export var npc_name: String = "Kassedama"

var npc_id: String = "kassedama"
@export var character_model: PackedScene

@export_group("Reaksjoner")

@export var finger_react_sounds: Array[AudioStream] = []
const FINGER_REACT_COOLDOWN: float = 5.0
var _last_finger_react_time: float = -9999.0
var _finger_react_index: int = 0
var _finger_react_audio: AudioStreamPlayer3D = null

const YAPP_PATH: String = "res://assets/sfx/erdetlyd/vox/kassedame/"
const YAPP_FILES: Array[String] = [
	"yapp_0.ogg", "yapp_1.ogg", "yapp_2.ogg", "yapp_3.ogg", "yapp_4.ogg", 
	"yapp_5.ogg", "yapp_6.ogg", "yapp_7.ogg", "yapp_8.ogg", "yapp_9.ogg", 
	"yapp_10.ogg", "yapp_11.ogg", "yapp_12.ogg", 
]

const BEKLAGER_FILES: Array[String] = [
	"beklager_0.ogg", "beklager_1.ogg", "beklager_2.ogg", "beklager_3.ogg", 
	"beklager_4.ogg", "beklager_5.ogg", "beklager_6.ogg", "beklager_7.ogg", 
	"beklager_8.ogg", "beklager_9.ogg", "beklager_10.ogg", 
]
const HJELP_FILES: Array[String] = [
	"hjelp_0.ogg", "hjelp_1.ogg", "hjelp_2.ogg", "hjelp_3.ogg", "hjelp_4.ogg", 
	"hjelp_5.ogg", "hjelp_6.ogg", 
]
const IKKENOK_FILES: Array[String] = [
	"ikkenok_0.ogg", "ikkenok_1.ogg", "ikkenok_2.ogg", "ikkenok_3.ogg", 
	"ikkenok_4.ogg", "ikkenok_5.ogg", "ikkenok_6.ogg", 
]
const TAKK_FILES: Array[String] = [
	"takk_0.ogg", "takk_1.ogg", "takk_2.ogg", "takk_3.ogg", "takk_4.ogg", 
	"takk_5.ogg", "takk_6.ogg", "takk_7.ogg", 
]
const INN_FILES: Array[String] = [
	"inn_0.ogg", "inn_1.ogg", "inn_2.ogg", "inn_3.ogg", 
]
const INTRO_FILES: Array[String] = [
	"intro_0.ogg", "intro_1.ogg", "intro_2.ogg", "intro_3.ogg", 
]
const UT_FILES: Array[String] = [
	"ut_0.ogg", "ut_1.ogg", "ut_2.ogg", 
]
const ID_FIRST_TIME_FILE: String = "id_first_time.ogg"
const ID_NEED_FILES: Array[String] = [
	"id_need0.ogg", "id_need1.ogg", "id_need2.ogg", 
]
const ID_NEED_EXTRA_FILES: Array[String] = [
	"id_need_extracomment0.ogg", "id_need_extracomment1.ogg", 
]
const ID_CHECK_FILES: Array[String] = [
	"id_check0.ogg", "id_check1.ogg", "id_check2.ogg", "id_check3.ogg", "id_check4.ogg", 
]
const ID_AGE_YOURE_ONLY_FILE: String = "id_age_youre_only.ogg"
const ID_AGE_YRS_FILES: Array[String] = [
	"id_age_yrs_1.ogg", "id_age_yrs_2.ogg", "id_age_yrs_3.ogg", "id_age_yrs_4.ogg", 
	"id_age_yrs_5.ogg", "id_age_yrs_6.ogg", "id_age_yrs_7.ogg", "id_age_yrs_8.ogg", 
	"id_age_yrs_9.ogg", "id_age_yrs_10.ogg", "id_age_yrs_11.ogg", "id_age_yrs_12.ogg", 
	"id_age_yrs_13.ogg", "id_age_yrs_14.ogg", "id_age_yrs_15.ogg", "id_age_yrs_16.ogg", 
	"id_age_yrs_17.ogg", 
]
const ID_EXCEPTION_FILES: Array[String] = [
	"id_exception0.ogg", "id_exception1.ogg", "id_exception2.ogg", 
]

var label_3d: Label3D

var in_range: bool = false
var _id_sign_shown: bool = false
var _id_sign_node: Node3D = null
var _id_first_deny_done: bool = false
var _last_id_need_index: int = -1
var _last_id_extra_index: int = -1
var _last_id_check_index: int = -1
var _player_ref: Node3D = null
var _showed_excuse_this_visit: bool = false
var _player_in_store_zone: bool = false
var _player_in_store: bool = false
var _last_yapp_index: int = -1
var _last_intro_index: int = -1
var _last_inn_index: int = -1
var _last_ut_index: int = -1
var _last_takk_index: int = -1
var _last_ikkenok_index: int = -1
var _last_hjelp_index: int = -1
var _last_beklager_index: int = -1
var _beklager_followup: Callable = Callable()
var _yapp_timer: float = 0.0
var _yapp_interval: float = 0.0
var _yapp_audio: AudioStreamPlayer3D = null
var _store_bounds_connected: bool = false
var _distance_fallback: bool = false
var _played_first_intro: bool = false
var _audio_cache: Dictionary = {}

func _ready() -> void :
	randomize()
	add_to_group("FingerReactable")
	label_3d = get_node_or_null("NameLabel") as Label3D
	if label_3d == null:
		label_3d = get_node_or_null("Area3D/Label3D") as Label3D
	_setup_model()
	if label_3d:
		label_3d.hide()
		label_3d.text = "E for å snakke med kassedama"
		label_3d.no_depth_test = true

		label_3d.render_priority = 10
		label_3d.outline_render_priority = 9
	_setup_yapp_audio()
	_preload_audio_cache()
	_randomize_yapp_interval()
	_connect_store_bounds_signals()
	call_deferred("_connect_store_bounds_signals")
	call_deferred("_find_id_sign")


func _process(delta: float) -> void :
	if _player_ref == null or not is_instance_valid(_player_ref):
		_player_ref = GameManager.get_player()
	if _player_ref == null:
		return
	var to_player: = _player_ref.global_position - global_position
	to_player.y = 0.0
	if to_player.length_squared() <= 0.0001:
		return
	var desired: = atan2( - to_player.x, - to_player.z)
	rotation.y = lerp_angle(rotation.y, desired, clamp(delta * 6.0, 0.0, 1.0))
	if not _store_bounds_connected and _distance_fallback:
		var dist: float = global_position.distance_to(_player_ref.global_position)
		_player_in_store_zone = dist < 20.0
		if not _player_in_store_zone:
			_player_in_store = false
	if not _player_in_store:
		return
	if _yapp_audio != null and _yapp_audio.playing:
		return
	_yapp_timer += delta
	if _yapp_timer >= _yapp_interval:
		_play_random_yapp()
		_randomize_yapp_interval()


func _setup_yapp_audio() -> void :
	_yapp_audio = AudioStreamPlayer3D.new()
	_yapp_audio.name = "YappAudio"
	_yapp_audio.max_distance = 55.0
	_yapp_audio.unit_size = 9.0
	_yapp_audio.bus = "Voice"
	add_child(_yapp_audio)


func _randomize_yapp_interval() -> void :
	_yapp_interval = randf_range(8.0, 20.0)
	_yapp_timer = 0.0


func _play_random_yapp() -> void :
	if _yapp_audio == null or YAPP_FILES.is_empty():
		return
	_last_yapp_index = _play_random_voice(YAPP_FILES, _last_yapp_index, "yapp")


func _connect_store_bounds_signals() -> void :
	_connect_kjiwi_door_trigger_signals()
	if _store_bounds_connected:
		return
	var bounds: Area3D = get_tree().get_first_node_in_group("StoreBounds") as Area3D
	if bounds == null:
		bounds = get_tree().root.find_child("StoreBounds", true, false) as Area3D
	if bounds == null:
		push_warning("[YAPP] StoreBounds not found!")
		_distance_fallback = true
		return
	_distance_fallback = false
	_store_bounds_connected = true
	if not bounds.body_entered.is_connected(_on_store_bounds_body_entered):
		bounds.body_entered.connect(_on_store_bounds_body_entered)
	if not bounds.body_exited.is_connected(_on_store_bounds_body_exited):
		bounds.body_exited.connect(_on_store_bounds_body_exited)


func _connect_kjiwi_door_trigger_signals() -> void :
	var door_trigger: Node = get_tree().get_first_node_in_group("KjiwiDoorTrigger")
	if door_trigger == null:
		door_trigger = get_tree().root.find_child("KjiwiDoorTrigger", true, false)
	if door_trigger == null:
		return
	if door_trigger.has_signal("player_entered_store") and not door_trigger.player_entered_store.is_connected(_on_player_entering):
		door_trigger.player_entered_store.connect(_on_player_entering)
	if door_trigger.has_signal("player_exited_store") and not door_trigger.player_exited_store.is_connected(_on_player_exiting):
		door_trigger.player_exited_store.connect(_on_player_exiting)


func _on_store_bounds_body_entered(body: Node3D) -> void :
	if body != null and body.is_in_group("PlayerCharacter"):
		_on_player_entered_store()


func _on_store_bounds_body_exited(body: Node3D) -> void :
	if body != null and body.is_in_group("PlayerCharacter"):
		_on_player_exited_store()


func _on_player_entered_store() -> void :
	_player_in_store_zone = true


func _on_player_exited_store() -> void :
	_player_in_store_zone = false
	_player_in_store = false
	_yapp_timer = 0.0
	if label_3d:
		label_3d.hide()


func _on_player_entering() -> void :
	_player_in_store = false
	_play_entry_sound()


func _on_player_exiting() -> void :
	_player_in_store_zone = false
	_player_in_store = false
	_yapp_timer = 0.0
	if label_3d:
		label_3d.hide()
	if _yapp_audio != null and _yapp_audio.playing:
		_yapp_audio.stop()
	_last_ut_index = _play_random_voice(UT_FILES, _last_ut_index, "ut")


func _play_entry_sound() -> void :
	if _yapp_audio == null:
		if _player_in_store_zone:
			_player_in_store = true
			_randomize_yapp_interval()
		return
	var entry_files: Array[String] = INN_FILES
	var entry_label: String = "inn"
	var last_index: int = _last_inn_index
	if not _played_first_intro and not INTRO_FILES.is_empty():
		entry_files = INTRO_FILES
		entry_label = "intro"
		last_index = _last_intro_index
	if entry_files.is_empty():
		if _player_in_store_zone:
			_player_in_store = true
			_randomize_yapp_interval()
		return
	var played_index: int = _play_random_voice(entry_files, last_index, entry_label)
	if entry_label == "intro":
		_last_intro_index = played_index
		_played_first_intro = true
	else:
		_last_inn_index = played_index
	if not _yapp_audio.playing:
		if _player_in_store_zone:
			_player_in_store = true
			_randomize_yapp_interval()
		return
	if _yapp_audio.finished.is_connected(_on_inn_finished):
		_yapp_audio.finished.disconnect(_on_inn_finished)
	_yapp_audio.finished.connect(_on_inn_finished, CONNECT_ONE_SHOT)


func _on_inn_finished() -> void :
	if _player_in_store_zone:
		_player_in_store = true
		_randomize_yapp_interval()


func _play_takk() -> void :
	if _yapp_audio == null or TAKK_FILES.is_empty():
		if _player_in_store_zone:
			_player_in_store = true
			_randomize_yapp_interval()
		return
	_player_in_store = false
	_last_takk_index = _play_random_voice(TAKK_FILES, _last_takk_index, "takk")
	if not _yapp_audio.playing:
		if _player_in_store_zone:
			_player_in_store = true
			_randomize_yapp_interval()
		return
	if _yapp_audio.finished.is_connected(_on_takk_finished):
		_yapp_audio.finished.disconnect(_on_takk_finished)
	_yapp_audio.finished.connect(_on_takk_finished, CONNECT_ONE_SHOT)


func _on_takk_finished() -> void :
	if _player_in_store_zone:
		_player_in_store = true
		_randomize_yapp_interval()


func _play_ikkenok() -> void :
	if _yapp_audio == null or IKKENOK_FILES.is_empty():
		if _player_in_store_zone:
			_player_in_store = true
			_randomize_yapp_interval()
		return
	_player_in_store = false
	_last_ikkenok_index = _play_random_voice(IKKENOK_FILES, _last_ikkenok_index, "ikkenok")
	if not _yapp_audio.playing:
		if _player_in_store_zone:
			_player_in_store = true
			_randomize_yapp_interval()
		return
	if _yapp_audio.finished.is_connected(_on_ikkenok_finished):
		_yapp_audio.finished.disconnect(_on_ikkenok_finished)
	_yapp_audio.finished.connect(_on_ikkenok_finished, CONNECT_ONE_SHOT)


func _on_ikkenok_finished() -> void :
	if _player_in_store_zone:
		_player_in_store = true
		_randomize_yapp_interval()


func _play_hjelp() -> void :
	if _yapp_audio == null or HJELP_FILES.is_empty():
		if _player_in_store_zone:
			_player_in_store = true
			_randomize_yapp_interval()
		return
	_player_in_store = false
	_last_hjelp_index = _play_random_voice(HJELP_FILES, _last_hjelp_index, "hjelp")
	if not _yapp_audio.playing:
		if _player_in_store_zone:
			_player_in_store = true
			_randomize_yapp_interval()
		return
	if _yapp_audio.finished.is_connected(_on_hjelp_finished):
		_yapp_audio.finished.disconnect(_on_hjelp_finished)
	_yapp_audio.finished.connect(_on_hjelp_finished, CONNECT_ONE_SHOT)


func _on_hjelp_finished() -> void :
	if _player_in_store_zone:
		_player_in_store = true
		_randomize_yapp_interval()


func _play_beklager(followup: Callable = Callable()) -> void :
	_beklager_followup = followup
	if _yapp_audio == null or BEKLAGER_FILES.is_empty():
		if _player_in_store_zone:
			_player_in_store = true
			_randomize_yapp_interval()
		_run_beklager_followup()
		return
	_player_in_store = false
	_last_beklager_index = _play_random_voice(BEKLAGER_FILES, _last_beklager_index, "beklager")
	if not _yapp_audio.playing:
		if _player_in_store_zone:
			_player_in_store = true
			_randomize_yapp_interval()
		_run_beklager_followup()
		return
	if _yapp_audio.finished.is_connected(_on_beklager_finished):
		_yapp_audio.finished.disconnect(_on_beklager_finished)
	_yapp_audio.finished.connect(_on_beklager_finished, CONNECT_ONE_SHOT)


func _on_beklager_finished() -> void :
	if _player_in_store_zone:
		_player_in_store = true
		_randomize_yapp_interval()
	_run_beklager_followup()


func _run_beklager_followup() -> void :
	if _beklager_followup.is_valid():
		var cb: = _beklager_followup
		_beklager_followup = Callable()
		cb.call()


func _preload_audio_cache() -> void :
	var all_files: Array[Array] = [
		YAPP_FILES, BEKLAGER_FILES, HJELP_FILES, IKKENOK_FILES, 
		TAKK_FILES, INN_FILES, INTRO_FILES, UT_FILES, 
		ID_NEED_FILES, ID_NEED_EXTRA_FILES, ID_CHECK_FILES, 
		ID_AGE_YRS_FILES, ID_EXCEPTION_FILES, 
	]
	var single_files: Array[String] = [ID_FIRST_TIME_FILE, ID_AGE_YOURE_ONLY_FILE]
	for file_name in single_files:
		var path: String = YAPP_PATH + file_name
		if not _audio_cache.has(path) and ResourceLoader.exists(path):
			var stream: = load(path) as AudioStream
			if stream != null:
				_audio_cache[path] = stream
	for file_list in all_files:
		for file_name in file_list:
			var path: String = YAPP_PATH + file_name
			if _audio_cache.has(path):
				continue
			if ResourceLoader.exists(path):
				var stream: = load(path) as AudioStream
				if stream != null:
					_audio_cache[path] = stream


func _play_random_voice(files: Array[String], last_index: int, label: String) -> int:
	if _yapp_audio == null or files.is_empty():
		return last_index
	var index: int = last_index
	if files.size() == 1:
		index = 0
	else:
		while index == last_index:
			index = randi() % files.size()
	var path: String = YAPP_PATH + files[index]
	var stream: AudioStream = _audio_cache.get(path) as AudioStream
	if stream == null:
		push_warning("[YAPP] Missing %s audio file: %s" % [label, path])
		return index
	_yapp_audio.stream = stream
	_yapp_audio.play()
	return index


func _setup_model() -> void :

	if character_model == null:
		return
	var model_root: = get_node_or_null("Model") as Node3D
	if model_root == null:
		return
	for child in model_root.get_children():
		child.queue_free()
	var instance: = character_model.instantiate()
	model_root.add_child(instance)
	var mesh_instance: = _find_mesh(instance)
	if mesh_instance == null:
		return
	var aabb: = mesh_instance.get_aabb()
	if aabb.size.y <= 0.0:
		return
	var factor: = 1.95 / aabb.size.y
	if instance is Node3D:
		var model_3d: = instance as Node3D
		model_3d.scale = Vector3(factor, factor, factor)
		model_3d.rotation_degrees.y = 180.0
		model_3d.position = Vector3(
			- (aabb.position.x + (aabb.size.x * 0.5)) * factor, 
			- (aabb.position.y + (aabb.size.y * 0.5)) * factor, 
			- (aabb.position.z + (aabb.size.z * 0.5)) * factor
		)


func _find_mesh(node: Node) -> MeshInstance3D:
	if node == null:
		return null
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found: = _find_mesh(child)
		if found != null:
			return found
	return null

func _input(_event: InputEvent) -> void :
	if not in_range:
		return
	if not _is_player_in_store():
		return
	if GameManager.has_method("is_minigame_active") and GameManager.is_minigame_active():
		return
	if DialogueUI.is_open():
		return
	if Input.is_action_just_pressed("interaction"):
		_interact()

func _interact() -> void :

	if GameManager.ice_creams_purchased >= 1 and not _showed_excuse_this_visit:
		_showed_excuse_this_visit = true
		_play_beklager()
	_continue_interaction_after_excuse()

func _continue_interaction_after_excuse() -> void :
	var zone: Node = _get_checkout_zone()
	if zone == null or not zone.has_method("get_items") or not zone.has_method("_calculate_total"):
		DialogueUI.close()
		_play_hjelp()
		return

	var items: Array[RigidBody3D] = zone.get_items()
	var total_cost: int = int(zone._calculate_total())
	if items.is_empty():
		DialogueUI.close()
		_play_hjelp()
		return
	_show_purchase_confirmation(items, total_cost)

func _cart_has_icecream(items: Array[RigidBody3D]) -> bool:
	for item in items:
		if not is_instance_valid(item):
			continue
		if "item_id" in item and str(item.item_id) == "icecream":
			return true
	return false


func _requires_id_for_icecream() -> bool:
	return GameManager.is_quest_completed("HVERDAGSKOMIKER")


func _show_purchase_confirmation(items: Array[RigidBody3D], total_cost: int) -> void :
	if GameManager.player_money < total_cost:
		_on_cannot_afford(total_cost)
		return

	if _cart_has_icecream(items) and _requires_id_for_icecream():
		if not GameManager.has_item("id_card"):
			DialogueUI.close()
			_on_id_required()
			return
		DialogueUI.close()
		_play_id_check( func():
			_show_purchase_menu(items, total_cost)
		)
		return

	_show_purchase_menu(items, total_cost)


func _show_purchase_menu(items: Array[RigidBody3D], total_cost: int) -> void :
	var on_confirm: = func():
		if GameManager.player_money >= total_cost:
			_process_purchase(items, total_cost)
		else:
			_on_cannot_afford(total_cost)
	DialogueUI.show_menu(
		["Er du sikker på at du vil kjøpe dette?"], 
		[
			{"text": "Ja", "action": on_confirm}, 
			{"text": "Nei", "action": func(): DialogueUI.close()}
		], 
		npc_name
	)

func _classify_cart_spend_kind(items: Array[RigidBody3D]) -> String:
	var seen_ice: = false
	var seen_other: = false
	for item in items:
		if not is_instance_valid(item):
			continue
		var ammo_type: String = str(item.ammo_type) if "ammo_type" in item else ""
		if ammo_type != "":
			seen_other = true
			continue
		var iid: = str(item.item_id) if "item_id" in item else ""
		if iid == "icecream":
			seen_ice = true
		else:
			seen_other = true
	if seen_other:
		return "non_icecream"
	if seen_ice:
		return "icecream"
	return "general"


func _give_weapon_to_player(weapon_int_id: int, skip_reserve_ammo: bool = false) -> void :
	var player: = _get_player()
	if player == null:
		return
	var weapon_manager: = player.get_node_or_null(player.weapon_controller_path)
	if weapon_manager == null:
		return
	if weapon_int_id in weapon_manager.weaponStack:
		return
	if weapon_manager.has_method("take_weapon_by_id"):
		# Equips locally and unlocks the weapon for the whole party.
		weapon_manager.take_weapon_by_id(weapon_int_id)
	elif weapon_manager.has_method("acquire_weapon_by_id"):
		weapon_manager.acquire_weapon_by_id(weapon_int_id)
	else:
		weapon_manager.weaponStack.append(weapon_int_id)
	if not skip_reserve_ammo:
		_setup_weapon_ammo(weapon_int_id, weapon_manager)
	else:
		if weapon_manager.has_method("_refresh_reserve_dependent_weapon_meshes"):
			weapon_manager._refresh_reserve_dependent_weapon_meshes()


func _setup_weapon_ammo(weapon_int_id: int, weapon_manager: Node) -> void :
	if weapon_manager == null or not "weaponList" in weapon_manager:
		return
	var weapon_list: Dictionary = weapon_manager.weaponList
	if not weapon_list.has(weapon_int_id):
		return
	var weapon_resource = weapon_list[weapon_int_id]
	if weapon_resource == null:
		return
	var max_mag: = int(weapon_resource.totalAmmoInMagRef) if int(weapon_resource.totalAmmoInMagRef) > 0 else int(weapon_resource.totalAmmoInMag)
	if max_mag <= 0:
		return
	if not bool(weapon_resource.allAmmoInMag):
		weapon_resource.totalAmmoInMag = int(max_mag / 2)
	var ammo_type: String = str(weapon_resource.ammoType)
	var ammo_manager: Node = weapon_manager.get_node_or_null("AmmunitionManager")
	if ammo_manager == null and "ammoManager" in weapon_manager:
		ammo_manager = weapon_manager.ammoManager
	if ammo_manager == null or ammo_type == "":
		return
	if not "ammoDict" in ammo_manager or not "maxNbPerAmmoDict" in ammo_manager:
		return
	var max_reserve: = int(ammo_manager.maxNbPerAmmoDict.get(ammo_type, 0))
	if max_reserve > 0:
		ammo_manager.ammoDict[ammo_type] = max_reserve


func _process_purchase(items: Array[RigidBody3D], total: int) -> void :
	if items.is_empty() or total <= 0:
		return
	var charge_total: = _calculate_purchase_total(items)
	var spend_kind: = _classify_cart_spend_kind(items)
	if not GameManager.remove_money(charge_total, spend_kind):
		return
	var player = _get_player()
	var quest_system = _get_quest_system()
	for item in items:
		if not is_instance_valid(item):
			continue
		if item.is_in_group("WallWeapon"):
			var skip_res: bool = item.get("skip_reserve_ammo_on_pickup") == true
			_give_weapon_to_player(int(item.weapon_int_id), skip_res)
			if item.has_method("mark_as_sold"):
				item.mark_as_sold()
			continue
		var ammo_type: String = str(item.ammo_type) if "ammo_type" in item else ""
		if ammo_type != "":
			var ammo_payload: = {ammo_type: int(item.ammo_amount)}
			if player:
				var link_component: Node = player.get_node_or_null("LinkComponent")
				if link_component and link_component.has_method("ammoRefillLink"):
					link_component.ammoRefillLink(ammo_payload)
				elif player.has_method("add_ammo_to_inventory"):
					player.add_ammo_to_inventory(ammo_type, int(item.ammo_amount))
				else:
					push_warning("Player missing ammo refill path for type: %s" % ammo_type)
				var wm: Node = player.get_node_or_null(player.weapon_controller_path)
				if wm and wm.has_method("_refresh_reserve_dependent_weapon_meshes"):
					wm._refresh_reserve_dependent_weapon_meshes()
		else:
			GameManager.add_item(item.item_id, 1)
			if item.item_id == "icecream" and quest_system:
				quest_system.on_item_purchased("icecream", 1)
			if item.item_id == "icecream" and GameManager.has_method("on_icecream_purchased"):
				GameManager.on_icecream_purchased()
		item.queue_free()
	var zone: Node = _get_checkout_zone()
	if zone:
		zone.items_on_counter = zone.items_on_counter.filter( func(item): return is_instance_valid(item))
		zone._update_price_label()
	if GameManager.has_active_quest("ECONOMIC_REALITY"):
		if not GameManager.has_item("icecream", 1):
			var econ_quest: Quest = GameManager.active_quests.get("ECONOMIC_REALITY") as Quest
			if econ_quest:
				econ_quest.description = "Kjøp is i butikken"
				GameManager.quest_progress_updated.emit(
					"ECONOMIC_REALITY", 
					int(econ_quest.get_total_progress())
				)
	DialogueUI.close()
	_play_takk()

func _calculate_purchase_total(items: Array[RigidBody3D]) -> int:
	var total: = 0
	for item in items:
		if not is_instance_valid(item):
			continue
		if "item_id" in item and str(item.item_id) == "icecream" and GameManager and GameManager.has_method("get_icecream_price"):
			total += int(GameManager.get_icecream_price())
			continue
		if item.has_method("get_price"):
			total += int(item.get_price())
		elif "price" in item:
			total += int(item.price)
	return total

func _on_cannot_afford(_price: int) -> void :
	DialogueUI.close()
	var zone: Node = _get_checkout_zone()
	if zone != null and zone.has_method("flash_denied"):
		zone.flash_denied()
	_play_ikkenok()


func _is_player_in_store() -> bool:
	var trigger: Node = get_tree().get_first_node_in_group("KjiwiDoorTrigger")
	if trigger != null and "_player_inside" in trigger:
		return bool(trigger._player_inside)
	return _player_in_store or _player_in_store_zone

func _get_player() -> Node:
	return NetUtil.get_local_player()

func _get_checkout_zone() -> Node:
	if checkout_zone == NodePath():
		return null
	return get_node_or_null(checkout_zone)

func _get_quest_system() -> Node:
	var root: = get_tree().root
	var qs: = root.get_node_or_null("QuestSystem")
	if qs != null:
		return qs
	var current_scene: = get_tree().current_scene
	if current_scene != null:
		return current_scene.get_node_or_null("QuestManager")
	return null

func _on_id_required() -> void :
	if not _id_sign_shown:
		_id_sign_shown = true
		_show_id_sign()

	if not _id_first_deny_done:
		_id_first_deny_done = true
		_play_voice_file(ID_FIRST_TIME_FILE, "id_first_time")
		DialogueUI.show_dialogue(["Du trenger ID."], npc_name)
		return

	_last_id_need_index = _play_random_voice(ID_NEED_FILES, _last_id_need_index, "id_need")
	if _yapp_audio != null and _yapp_audio.playing and randf() < 0.2:
		_yapp_audio.finished.connect(_play_id_need_extra, CONNECT_ONE_SHOT)


func _play_id_need_extra() -> void :
	_last_id_extra_index = _play_random_voice(ID_NEED_EXTRA_FILES, _last_id_extra_index, "id_need_extra")


func _play_id_check(followup: Callable) -> void :
	_last_id_check_index = _play_random_voice(ID_CHECK_FILES, _last_id_check_index, "id_check")
	var after_check: = func():
		var age: = _get_id_card_age()
		if age >= 1 and age <= 17:
			_play_underage_sequence(age, followup)
		elif followup.is_valid():
			followup.call()
	if _yapp_audio == null or not _yapp_audio.playing:
		after_check.call()
		return
	_yapp_audio.finished.connect( func():
		after_check.call()
	, CONNECT_ONE_SHOT)


func _get_id_card_age() -> int:
	var dob_str: String = GameManager.id_card_data.get("dob", "") as String
	if dob_str.is_empty():
		return 18
	var parts: = dob_str.split(".")
	if parts.size() < 3:
		return 18
	var day: = parts[0].to_int()
	var month: = parts[1].to_int()
	var year: = parts[2].to_int()

	if year < 100:
		var this_yy: int = Time.get_date_dict_from_system()["year"] %100
		year += 2000 if year <= this_yy else 1900
	if year < 1900 or year > 2100 or month < 1 or month > 12 or day < 1 or day > 31:
		return 18
	var now: = Time.get_date_dict_from_system()
	var age: int = now["year"] - year
	if now["month"] < month or (now["month"] == month and now["day"] < day):
		age -= 1
	return age


func _play_underage_sequence(age: int, followup: Callable) -> void :
	AchievementManager.unlock(AchievementManager.ACH_UNDERAGE_ID)
	_play_voice_file(ID_AGE_YOURE_ONLY_FILE, "id_age_youre_only")
	if _yapp_audio == null or not _yapp_audio.playing:
		if followup.is_valid():
			followup.call()
		return
	_yapp_audio.finished.connect( func():
		var idx: int = clampi(age - 1, 0, ID_AGE_YRS_FILES.size() - 1)
		_play_voice_file(ID_AGE_YRS_FILES[idx], "id_age_yrs")
		if _yapp_audio == null or not _yapp_audio.playing:
			if followup.is_valid():
				followup.call()
			return
		_yapp_audio.finished.connect( func():
			var exc_idx: int = randi() % ID_EXCEPTION_FILES.size()
			_play_voice_file(ID_EXCEPTION_FILES[exc_idx], "id_exception")
			if _yapp_audio == null or not _yapp_audio.playing:
				if followup.is_valid():
					followup.call()
				return
			_yapp_audio.finished.connect( func():
				if followup.is_valid():
					followup.call()
			, CONNECT_ONE_SHOT)
		, CONNECT_ONE_SHOT)
	, CONNECT_ONE_SHOT)


func _play_voice_file(file_name: String, label: String) -> void :
	if _yapp_audio == null:
		return
	var path: String = YAPP_PATH + file_name
	var stream: AudioStream = _audio_cache.get(path) as AudioStream
	if stream == null:
		push_warning("[YAPP] Missing %s audio file: %s" % [label, path])
		return
	_yapp_audio.stream = stream
	_yapp_audio.play()


func _find_id_sign() -> void :
	var scene: = get_tree().current_scene
	if scene != null:
		_id_sign_node = scene.get_node_or_null(
			"NavigationRegion3D/HovedGata/Butikk/Checkout/aldersgrenseskilt"
		) as Node3D
	if _id_sign_node != null:
		_id_sign_node.visible = false


func _show_id_sign() -> void :
	if _id_sign_node != null:
		_id_sign_node.visible = true


func _on_area_3d_body_entered(body: Node3D) -> void :
	if body.is_in_group("PlayerCharacter"):
		in_range = true
		if label_3d and _is_player_in_store():
			label_3d.show()

func _on_area_3d_body_exited(body: Node3D) -> void :
	if body.is_in_group("PlayerCharacter"):
		in_range = false
		_showed_excuse_this_visit = false
		if label_3d:
			label_3d.hide()



func react_to_finger() -> void :
	if _finger_react_index >= finger_react_sounds.size():
		return

	if _finger_react_blocked_by_speech():
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_finger_react_time < FINGER_REACT_COOLDOWN:
		return
	var clip: AudioStream = finger_react_sounds[_finger_react_index]
	_finger_react_index += 1
	if clip == null:
		return
	_last_finger_react_time = now
	if _finger_react_audio == null:
		_finger_react_audio = AudioStreamPlayer3D.new()
		_finger_react_audio.max_distance = 25.0
		_finger_react_audio.unit_size = 6.0
		_finger_react_audio.bus = "Voice"
		add_child(_finger_react_audio)
	_finger_react_audio.stream = clip
	_finger_react_audio.play()



func stop_finger_react() -> void :
	if _finger_react_audio != null and _finger_react_audio.playing:
		_finger_react_audio.stop()




func _finger_react_blocked_by_speech() -> bool:
	if DialogueUI != null and DialogueUI.has_method("is_open") and DialogueUI.is_open():
		return true
	if _yapp_audio != null and _yapp_audio.playing:
		return true
	if _finger_react_audio != null and _finger_react_audio.playing:
		return true
	return false
