
extends Node




signal quest_changed(quest_id: String, state: int)
signal quest_completed(quest_id: String)
signal quest_progress_updated(quest_id: String, progress: int)
signal money_changed(new_amount: int)
signal item_added(item_id: String, amount: int)
signal item_removed(item_id: String, amount: int)
signal inventory_changed(item_id: String, new_amount: int)
signal consumable_used(item_id: String)
signal item_use_blocked(item_id: String, code: String)
signal minigame_started(minigame_id: String)

signal pedestrian_died
signal minigame_ended(minigame_id: String, score: int)
signal gunshot_fired(position: Vector3, range: float)
signal day_changed(new_day: int)
signal game_reset





@export var play_intro_sequence: bool = true

@export var debug_start_gorgon_horror: bool = false

@export var debug_speed_boost: bool = false
var current_day: int = 1
var day_duration_seconds: float = 600.0
var player_name: String = "Sokrates"
var player_money: int = 0
var player_xp: int = 0




var inventory: Dictionary = {}
var active_quests: Dictionary = {}
var completed_quests: Dictionary = {}
var failed_quests: Array[String] = []
var quest_registry: Dictionary = {}
var freezer_icecream_count: int = 0
var bank_payout_claimed: Dictionary = {}
var active_minigame_id: String = ""
var dead_npcs: Array[String] = []
var npcs_talked_to: Array[String] = []

var inheritance_spent_on_non_ice_cream: bool = false

var ice_creams_purchased: int = 0

var game_completed_once: bool = false
var last_playthrough_time: float = 0.0
var session_start_time: float = 0.0
var mouse_sensitivity: float = 1.0
var master_volume: float = 1.0
var music_volume: float = 1.0
var sfx_volume: float = 1.0
var voice_volume: float = 1.0
var speedrun_timer_on: bool = false
var shadows_enabled: bool = true
var render_distance: float = 150.0

var fullscreen_enabled: bool = not OS.has_feature("editor")
var vsync_enabled: bool = true
var invert_y: bool = false
var brightness: float = 1.0
var contrast: float = 1.0
var window_size_index: int = 2


const WINDOW_SIZES: Array[Vector2i] = [
	Vector2i(640, 480), 
	Vector2i(960, 720), 
	Vector2i(1280, 960), 
	Vector2i(1600, 1200), 
]

const SETTINGS_PATH: = "user://settings.cfg"


const RADIO_BUS_BASE_DB: = -3.0
const AMBIENCE_BUS_BASE_DB: = -6.0
const ID_CARD_PATH: = "user://id_card.cfg"

var hverdagskomiker_pending_power: bool = false
var gorgon_stolen_item: String = ""
var kid_drawing_taken: bool = false
var scholarship_penalty_until: float = 0.0
var id_card_ready: bool = false
var id_card_collected: bool = false
var id_card_data: Dictionary = {}
var visited_store_during_second_ice: bool = false
var _entered_kjiwi_during_second_ice: bool = false
var last_death_cause: String = ""
var _cached_player: Node3D = null

const TOTAL_GARD_PLAKATER: int = 10

const ENDING_SEQUENCE_SCENE: PackedScene = preload("res://scenes/ui/ending_sequence.tscn")

const MEDICAL_HEAL_ITEM_IDS: Array[String] = ["god_morgen_yoghurt", "painkillers", "kefir"]
const QUEST_RESOURCE_PATHS: Array[String] = [
	"res://data/quests/quest_01_grandpa_request.tres", 
	"res://data/quests/quest_02_bank_inheritance.tres", 
	"res://data/quests/quest_03_economic_reality.tres", 
	"res://data/quests/quest_04_disappointment.tres", 
	"res://data/quests/quest_05_scholarship_application.tres", 
	"res://data/quests/quest_06_bank_deposit.tres", 
	"res://data/quests/quest_07_second_icecream.tres", 
	"res://data/quests/quest_08_final_delivery.tres", 
	"res://data/quests/quest_kris_lua.tres", 
	"res://data/quests/quest_09_iver_bevis.tres", 
	"res://data/quests/quest_10_steinar_grus.tres", 
	"res://data/quests/quest_hverdagskomiker.tres", 
	"res://data/quests/quest_gorgon_robbery.tres", 
	"res://data/quests/quest_vindkast.tres"
]

var steam_enabled: bool = false

## True in solo play, and on the host in a multiplayer session — i.e.
## whenever this GameManager instance is the source of truth for shared
## party state (money/inventory/quests/story flags) rather than a mirror.
func is_authority() -> bool:
	return NetworkManager == null or not NetworkManager.is_active or NetworkManager.is_host


## Set by GameNet while replaying a host-originated change on a client's
## local GameManager, so that replay doesn't get redirected right back to
## the host (see multiplayer/game_net.gd).
var _remote_apply: bool = false


## Call at the top of any public mutator that changes shared party state.
## Returns true if the call was redirected to the host over the network —
## the caller should return immediately without applying anything locally,
## since the resulting change will arrive via GameNet's replay once the
## host has processed it. Only ever redirects on a non-host client; solo
## play and the host itself always fall through and apply directly.
func _redirect_to_host(method: String, args: Array) -> bool:
	if _remote_apply or is_authority():
		return false
	GameNet.request_on_host(method, args)
	return true


## Snapshot of shared party state for a client joining an in-progress
## session (see GameNet.request_snapshot / _apply_snapshot). Deliberately
## excludes local-only settings (audio/video/sensitivity) and Steam/DLC
## state, which are per-machine, not per-party.
func serialize_state() -> Dictionary:
	var quests_out: Dictionary = {}
	for quest_id in active_quests:
		quests_out[quest_id] = (active_quests[quest_id] as Quest).duplicate(true)
	return {
		"player_money": player_money,
		"inventory": inventory.duplicate(true),
		"active_quests": quests_out,
		"completed_quests": completed_quests.duplicate(true),
		"failed_quests": failed_quests.duplicate(true),
		"freezer_icecream_count": freezer_icecream_count,
		"bank_payout_claimed": bank_payout_claimed.duplicate(true),
		"ice_creams_purchased": ice_creams_purchased,
		"dead_npcs": dead_npcs.duplicate(true),
		"npcs_talked_to": npcs_talked_to.duplicate(true),
		"collected_collectibles": collected_collectibles.duplicate(true),
		"hverdagskomiker_pending_power": hverdagskomiker_pending_power,
		"gorgon_stolen_item": gorgon_stolen_item,
		"inheritance_spent_on_non_ice_cream": inheritance_spent_on_non_ice_cream,
		"visited_store_during_second_ice": visited_store_during_second_ice,
		"kid_drawing_taken": kid_drawing_taken,
		"id_card_ready": id_card_ready,
		"id_card_collected": id_card_collected,
	}


func apply_snapshot(state: Dictionary) -> void:
	_remote_apply = true
	player_money = int(state.get("player_money", player_money))
	inventory = (state.get("inventory", inventory) as Dictionary).duplicate(true)
	active_quests = (state.get("active_quests", active_quests) as Dictionary).duplicate(true)
	completed_quests = (state.get("completed_quests", completed_quests) as Dictionary).duplicate(true)
	failed_quests.assign(state.get("failed_quests", failed_quests))
	freezer_icecream_count = int(state.get("freezer_icecream_count", freezer_icecream_count))
	bank_payout_claimed = (state.get("bank_payout_claimed", bank_payout_claimed) as Dictionary).duplicate(true)
	ice_creams_purchased = int(state.get("ice_creams_purchased", ice_creams_purchased))
	dead_npcs.assign(state.get("dead_npcs", dead_npcs))
	npcs_talked_to.assign(state.get("npcs_talked_to", npcs_talked_to))
	collected_collectibles = (state.get("collected_collectibles", collected_collectibles) as Dictionary).duplicate(true)
	hverdagskomiker_pending_power = bool(state.get("hverdagskomiker_pending_power", hverdagskomiker_pending_power))
	gorgon_stolen_item = str(state.get("gorgon_stolen_item", gorgon_stolen_item))
	inheritance_spent_on_non_ice_cream = bool(state.get("inheritance_spent_on_non_ice_cream", inheritance_spent_on_non_ice_cream))
	visited_store_during_second_ice = bool(state.get("visited_store_during_second_ice", visited_store_during_second_ice))
	kid_drawing_taken = bool(state.get("kid_drawing_taken", kid_drawing_taken))
	id_card_ready = bool(state.get("id_card_ready", id_card_ready))
	id_card_collected = bool(state.get("id_card_collected", id_card_collected))
	money_changed.emit(player_money)
	for item_id in inventory:
		inventory_changed.emit(item_id, get_item_count(item_id))
	for quest_id in active_quests:
		quest_changed.emit(quest_id, (active_quests[quest_id] as Quest).state)
	_remote_apply = false


const SUPPORTER_DLC_APP_ID: int = 4990650


const SKINS: Array[Dictionary] = [
	{"id": "supporter_molded_bread", "name": "Muggen brødskive", "requires_dlc": true}, 
]


var active_skins: Dictionary = {}




var supporter_gestures_active: bool = true


func is_episode_unlocked(episode: int) -> bool:

	return episode == 1


func has_supporter_dlc() -> bool:
	if not steam_enabled or SUPPORTER_DLC_APP_ID <= 0:
		return false
	var steam: Object = Engine.get_singleton("Steam")
	if steam == null:
		return false



	if steam.has_method("isDLCInstalled")\
	and bool(steam.isDLCInstalled(SUPPORTER_DLC_APP_ID)):
		return true
	if steam.has_method("isSubscribedApp")\
	and bool(steam.isSubscribedApp(SUPPORTER_DLC_APP_ID)):
		return true
	return false




func _debug_log_dlc_state() -> void :
	if not steam_enabled:
		print("[DLC] Steam av (editor/ingen Steam) — supporter-innhold låst.")
		return
	print("[DLC] supporter (%d) eid: %s | skin aktivt: %s"
		%[SUPPORTER_DLC_APP_ID, str(has_supporter_dlc()), 
			str(is_skin_active("supporter_molded_bread"))])





const SUPPORTER_STORE_URL: = "https://erdetenbutikk.no/products/erdetspill-supporter-pakke"

func open_supporter_store_page() -> void :
	if steam_enabled and Engine.has_singleton("Steam"):
		var steam: = Engine.get_singleton("Steam")
		if steam.has_method("activateGameOverlayToWebPage"):
			steam.activateGameOverlayToWebPage(SUPPORTER_STORE_URL)
			return
	OS.shell_open(SUPPORTER_STORE_URL)


func is_skin_owned(skin: Dictionary) -> bool:
	return not bool(skin.get("requires_dlc", false)) or has_supporter_dlc()


func is_skin_active(skin_id: String) -> bool:
	if not bool(active_skins.get(skin_id, false)):
		return false
	for skin: Dictionary in SKINS:
		if str(skin.id) == skin_id:
			return is_skin_owned(skin)
	return false


func set_skin_active(skin_id: String, on: bool) -> void :
	active_skins[skin_id] = on
	save_settings()


func is_supporter_gestures_active() -> bool:
	return has_supporter_dlc() and supporter_gestures_active


func set_supporter_gestures_active(on: bool) -> void :
	supporter_gestures_active = on
	save_settings()




func is_supporter_pack_active() -> bool:
	if not has_supporter_dlc() or not supporter_gestures_active:
		return false
	for skin: Dictionary in SKINS:
		if bool(skin.get("requires_dlc", false))\
		and not bool(active_skins.get(str(skin.id), false)):
			return false
	return true


func set_supporter_pack_active(on: bool) -> void :
	supporter_gestures_active = on
	for skin: Dictionary in SKINS:
		if bool(skin.get("requires_dlc", false)):
			active_skins[str(skin.id)] = on
	save_settings()


func _init_steam() -> void :
	if OS.has_feature("editor"):
		return
	if not Engine.has_singleton("Steam"):
		push_warning("[Steam] GodotSteam not available — running without Steam.")
		return
	var steam: Object = Engine.get_singleton("Steam")
	var init_result: Dictionary = steam.steamInitEx(false, 4887360)
	if init_result.status != 0:
		push_warning("[Steam] Init failed: %s" % init_result.verbal)
		return
	steam_enabled = true
	print("[Steam] Logged in as: %s" % steam.getPersonaName())
	_debug_log_dlc_state()


func _process(_delta: float) -> void :
	if steam_enabled:
		Engine.get_singleton("Steam").run_callbacks()


func _ready() -> void :
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_steam()
	session_start_time = Time.get_ticks_msec() / 1000.0
	load_settings()
	_load_id_card_data()
	apply_fullscreen(fullscreen_enabled)
	apply_vsync(vsync_enabled)
	apply_master_volume()
	apply_music_volume(music_volume)
	apply_sfx_volume(sfx_volume)
	apply_voice_volume(voice_volume)
	if not get_tree().scene_changed.is_connected(_on_scene_changed):
		get_tree().scene_changed.connect(_on_scene_changed)
	call_deferred("apply_shadows", shadows_enabled)
	call_deferred("apply_brightness_contrast")
	_load_all_quest_definitions()
	_validate_resources()
	if not item_added.is_connected(_on_item_added_quest_check):
		item_added.connect(_on_item_added_quest_check)
	if not gunshot_fired.is_connected(_on_gunshot_fired):
		gunshot_fired.connect(_on_gunshot_fired)
	if not quest_completed.is_connected(_on_quest_completed_music):
		quest_completed.connect(_on_quest_completed_music)
	call_deferred("_connect_kjiwi_door_trigger")


	call_deferred("_maybe_debug_start_gorgon_horror")
	call_deferred("_maybe_apply_debug_speed_boost")


func _on_quest_completed_music(quest_id: String) -> void :
	match quest_id:
		"FINAL_DELIVERY":
			pass


func _advance_day() -> void :
	current_day += 1
	day_changed.emit(current_day)


func register_dead_npc(npc_id: String) -> void :
	if _redirect_to_host("register_dead_npc", [npc_id]):
		return
	if not dead_npcs.has(npc_id):
		dead_npcs.append(npc_id)

func register_npc_talked(npc_id: String) -> void :
	if _redirect_to_host("register_npc_talked", [npc_id]):
		return
	if npc_id == "":
		return
	if not npcs_talked_to.has(npc_id):
		npcs_talked_to.append(npc_id)

func has_talked_to_npc(npc_id: String) -> bool:
	return npcs_talked_to.has(npc_id)









var collected_collectibles: Dictionary = {}

## NOTE: not routed through GameNet like the other mutators — `artwork` is a
## Texture2D resource, which isn't a value GameNet's generic RPC replay can
## serialize (see multiplayer/game_net.gd). A non-host client collecting a
## collectible only updates their own local GameManager for now; it won't
## show up for the rest of the party until this is reworked to look the
## artwork up by id on the host side instead of passing the resource itself.
func collect_collectible(id: String, kind: int = 0, artwork: Texture2D = null,
		text: String = "", title: String = "") -> void :
	if id != "":
		collected_collectibles[id] = {
			"kind": kind, "artwork": artwork, "text": text, "title": title, 
		}

func is_collectible_collected(id: String) -> bool:
	return collected_collectibles.has(id)


func get_viewable_collectibles() -> Array:
	var out: Array = []
	for id in collected_collectibles:
		var d: Variant = collected_collectibles[id]
		if d is Dictionary and int(d.get("kind", 0)) != 0:
			out.append(d)
	return out


func is_npc_dead(npc_id: String) -> bool:
	return dead_npcs.has(npc_id)


func apply_weapon_damage_to_npc_collider(collider: Object, damage: float) -> bool:
	var n: Node = collider as Node
	while n:
		if n.is_in_group("StoryNPC"):
			return false
		if n.is_in_group("NPC"):
			var hc: Node = n.get_node_or_null("HealthComponent")
			if hc is HealthComponent:
				var health: = hc as HealthComponent
				if not health.is_dead:
					health.take_damage(damage)
					return true
			return false
		n = n.get_parent()
	return false




func set_money(amount: int):
	player_money = max(0, amount)
	money_changed.emit(player_money)

func add_money(_amount: int):
	push_warning("add_money is restricted. Use bank_transaction() or add_flat_money_reward().")

func add_flat_money_reward(amount: int, play_cash_sfx: bool = true):
	if _redirect_to_host("add_flat_money_reward", [amount, play_cash_sfx]):
		return
	if amount <= 0:
		return
	player_money += amount
	money_changed.emit(player_money)
	if play_cash_sfx:
		SfxManager.play("money_added")
	print("💰 Added %d money. Total: %d" % [amount, player_money])

func bank_transaction(amount: int, source: String) -> bool:
	if _redirect_to_host("bank_transaction", [amount, source]):
		return true
	if source != "bank_teller":
		push_warning("Blocked bank_transaction from source: %s" % source)
		return false
	if amount <= 0:
		return false
	add_flat_money_reward(amount, false)
	return true

func bank_document_payout(quest_id: String, amount: int, source: String = "bank_teller") -> bool:
	if _redirect_to_host("bank_document_payout", [quest_id, amount, source]):
		return true
	if bank_payout_claimed.get(quest_id, false):
		return false
	if not bank_transaction(amount, source):
		return false
	bank_payout_claimed[quest_id] = true
	SfxManager.play("money_added")
	return true

func remove_money(amount: int, spend_context: String = "general") -> bool:
	if _redirect_to_host("remove_money", [amount, spend_context]):
		return true
	if player_money >= amount:
		player_money -= amount
		money_changed.emit(player_money)
		SfxManager.play("money_removed")
		_maybe_flag_inheritance_mis_spending(spend_context)
		print("💰 Removed %d money. Total: %d" % [amount, player_money])
		return true
	print("❌ Not enough money! Need %d, have %d" % [amount, player_money])
	return false


func _maybe_flag_inheritance_mis_spending(spend_context: String) -> void :
	if spend_context == "icecream":
		if has_active_quest("ECONOMIC_REALITY") or not is_quest_completed("ECONOMIC_REALITY"):
			inheritance_spent_on_non_ice_cream = false
		return
	if not bank_payout_claimed.get("BANK_INHERITANCE", false):
		return
	if is_quest_completed("ECONOMIC_REALITY"):
		return
	inheritance_spent_on_non_ice_cream = true

func has_enough_money(amount: int) -> bool:
	return player_money >= amount

func get_icecream_price() -> int:
	match ice_creams_purchased:
		0:
			return 100
		1:
			return 200
		_:
			return 250

func on_icecream_purchased() -> void :
	ice_creams_purchased += 1




func add_item(item_id: String, amount: int = 1):
	if _redirect_to_host("add_item", [item_id, amount]):
		return
	if amount <= 0:
		return
	var item_data: = _load_item_data(item_id)
	if item_data == null:
		push_warning("Item resource not found for item_id: %s" % item_id)
		return

	var previous_amount = get_item_count(item_id)
	var max_stack = max(1, item_data.max_stack)
	var next_amount = previous_amount + amount
	if item_data.stackable:
		next_amount = min(next_amount, max_stack)
	else:
		next_amount = 1

	inventory[item_id] = {
		"data": item_data, 
		"amount": next_amount
	}
	var added_amount = max(0, next_amount - previous_amount)
	if added_amount > 0:
		SfxManager.play("item_added")
		item_added.emit(item_id, added_amount)
	inventory_changed.emit(item_id, next_amount)
	print("📦 Added %d x %s to inventory" % [added_amount, item_id])


var _ending_sequence_started: bool = false

func add_icecream_to_freezer(amount: int = 1):
	if _redirect_to_host("add_icecream_to_freezer", [amount]):
		return
	freezer_icecream_count += max(0, amount)

func get_freezer_icecream_count() -> int:
	return freezer_icecream_count

func remove_item(item_id: String, amount: int = 1) -> bool:
	if _redirect_to_host("remove_item", [item_id, amount]):
		return true
	if not inventory.has(item_id):
		return false

	var current_amount = int(inventory[item_id].get("amount", 0))
	if current_amount >= amount:
		current_amount -= amount
		item_removed.emit(item_id, amount)
		print("📦 Removed %d x %s from inventory" % [amount, item_id])

		if current_amount <= 0:
			inventory.erase(item_id)
			inventory_changed.emit(item_id, 0)
		else:
			inventory[item_id]["amount"] = current_amount
			inventory_changed.emit(item_id, current_amount)
		SfxManager.play("item_removed")
		return true

	print("❌ Not enough %s! Have %d, need %d" % [item_id, current_amount, amount])
	return false

func get_item_count(item_id: String) -> int:
	if not inventory.has(item_id):
		return 0
	return int(inventory[item_id].get("amount", 0))

func has_item(item_id: String, amount: int = 1) -> bool:
	return get_item_count(item_id) >= amount

func use_item(item_id: String) -> bool:
	if _redirect_to_host("use_item", [item_id]):
		return true
	if not inventory.has(item_id):
		return false
	var slot = inventory[item_id]
	var data: ItemData = slot.get("data")
	if data == null:
		push_warning("Item slot missing data for %s" % item_id)
		return false
	match data.category:
		ItemData.Category.CONSUMABLE:
			if _is_medical_heal_item(item_id) and _player_health_is_full():
				item_use_blocked.emit(item_id, "full_health")
				return false
			if remove_item(item_id, 1):
				consumable_used.emit(item_id)
				_on_item_used(item_id)
				return true
			return false
		ItemData.Category.QUEST_ITEM:
			push_warning("Quest item cannot be used directly: %s" % item_id)
			return false
		ItemData.Category.AMMO:
			push_warning("Ammo is handled by weapon system: %s" % item_id)
			return false
	return false

func _is_medical_heal_item(item_id: String) -> bool:
	return MEDICAL_HEAL_ITEM_IDS.has(item_id)

func _player_health_is_full() -> bool:
	var player: = get_player()
	if player == null:
		return false
	var hc = player.get_node_or_null("HealthComponent")
	if hc == null:
		return false
	return float(hc.current_health) >= float(hc.max_health)




func _check_quest_requirements(quest: Quest) -> bool:

	for required_id in quest.required_quest_ids:
		if not completed_quests.has(required_id):
			print("Missing required quest: ", required_id)
			return false


	for item_id in quest.required_items:
		if not has_item(item_id):
			print("Missing required item: ", item_id)
			return false


	if quest.required_money > 0 and player_money < quest.required_money:
		print("Missing required money: Need ", quest.required_money, " have ", player_money)
		return false

	return true




func add_quest(quest: Quest, auto_start: bool = true) -> bool:

	if completed_quests.has(quest.quest_id):
		print("Quest already completed: ", quest.quest_id)
		return false


	if active_quests.has(quest.quest_id):
		print("Quest already active: ", quest.quest_id)
		return false


	if not _check_quest_requirements(quest):
		print("Quest requirements not met: ", quest.quest_id)
		return false

	var quest_instance = quest.duplicate(true)
	quest_instance.normalize_runtime_state()

	if auto_start:
		quest_instance.state = Quest.QuestState.ACTIVE

		for objective in quest_instance.objectives:
			if objective != null and objective.objective_id != "" and not quest_instance.objective_progress.has(objective.objective_id):
				quest_instance.objective_progress[objective.objective_id] = 0
		if quest_instance.objectives.is_empty():
			quest_instance.current_progress = 0

	active_quests[quest_instance.quest_id] = quest_instance
	_backfill_gather_objectives(quest_instance)
	quest_changed.emit(quest_instance.quest_id, quest_instance.state)
	SfxManager.play("quest_added")

	if auto_start and quest_instance.quest_id == "HVERDAGSKOMIKER":
		_open_hverdagskomiker_door_passage()
	return true

func update_quest_progress(quest_id: String, amount: int = 1):
	if _redirect_to_host("update_quest_progress", [quest_id, amount]):
		return
	if not active_quests.has(quest_id):
		return

	var quest = active_quests[quest_id]
	quest.normalize_runtime_state()
	if quest.state != Quest.QuestState.ACTIVE:
		return


	if quest.objectives.is_empty():
		quest.current_progress += amount
		quest_progress_updated.emit(quest_id, quest.current_progress)

		if quest.current_progress >= quest.target_amount:
			complete_quest(quest)
	else:

		var first_objective = quest.objectives[0]
		quest.update_objective(first_objective.objective_id, amount)
		quest_progress_updated.emit(quest_id, quest.get_total_progress())

		if quest.is_complete():
			_maybe_complete_quest(quest)

func update_quest_objective(quest_id: String, objective_id: String, amount: int = 1):
	if _redirect_to_host("update_quest_objective", [quest_id, objective_id, amount]):
		return
	if not active_quests.has(quest_id):
		return

	var quest = active_quests[quest_id]
	quest.normalize_runtime_state()
	if quest.state != Quest.QuestState.ACTIVE:
		return

	quest.update_objective(objective_id, amount)
	quest_progress_updated.emit(quest_id, quest.get_total_progress())

	if quest.is_complete():
		_maybe_complete_quest(quest)





func set_objective_hint(quest_id: String, objective_id: String, text: String) -> void :
	var quest: Quest = active_quests.get(quest_id) as Quest
	if quest == null:
		return
	for objective in quest.objectives:
		if objective == null or objective.objective_id != objective_id:
			continue
		if objective.description == text:
			return
		objective.description = text
		quest_progress_updated.emit(quest_id, quest.get_total_progress())
		return




func set_quest_hint(quest_id: String, text: String) -> void :
	var quest: Quest = active_quests.get(quest_id) as Quest
	if quest == null or quest.description == text:
		return
	quest.description = text
	quest_progress_updated.emit(quest_id, quest.get_total_progress())


func _backfill_gather_objectives(quest: Quest) -> void :
	if quest == null:
		return
	quest.normalize_runtime_state()
	var changed: = false
	for objective in quest.objectives:
		if objective == null:
			continue
		if objective.type != QuestObjective.ObjectiveType.GATHER_ITEM:
			continue
		var have: int = get_item_count(objective.target_id)
		if have <= 0:
			continue
		var current: int = int(quest.objective_progress.get(objective.objective_id, 0))
		if current >= objective.target_amount:
			continue
		var desired: int = mini(have, objective.target_amount)
		var to_add: int = desired - current
		if to_add > 0:
			quest.update_objective(objective.objective_id, to_add)
			changed = true
	if changed:
		quest_progress_updated.emit(quest.quest_id, quest.get_total_progress())
	if quest.is_complete():
		_maybe_complete_quest(quest)

func has_quest(quest_id: String) -> bool:
	return has_active_quest(quest_id) or is_quest_completed(quest_id)


func add_quest_by_id(quest_id: String, auto_start: bool = true) -> bool:
	if _redirect_to_host("add_quest_by_id", [quest_id, auto_start]):
		return true
	var quest_def: Quest = get_quest_definition(quest_id)
	if quest_def == null:
		push_warning("Unknown quest_id: %s" % quest_id)
		return false
	return add_quest(quest_def, auto_start)


func try_add_hverdagskomiker_quest() -> bool:
	if not is_quest_completed("KRIS_LUA"):
		return false
	if has_quest("HVERDAGSKOMIKER"):
		return false
	return add_quest_by_id("HVERDAGSKOMIKER", true)


func complete_quest_by_id(quest_id: String) -> void :
	if _redirect_to_host("complete_quest_by_id", [quest_id]):
		return
	if active_quests.has(quest_id):
		complete_quest(active_quests[quest_id])
		return
	if quest_id == "HVERDAGSKOMIKER" and hverdagskomiker_pending_power:
		var quest_def: Quest = get_quest_definition(quest_id)
		if quest_def:
			var inst: Quest = quest_def.duplicate(true)
			inst.normalize_runtime_state()
			inst.state = Quest.QuestState.ACTIVE
			active_quests[quest_id] = inst
			complete_quest(inst)


func reset_quest_by_id(quest_id: String) -> void :
	if _redirect_to_host("reset_quest_by_id", [quest_id]):
		return
	active_quests.erase(quest_id)
	completed_quests.erase(quest_id)
	if quest_id == "HVERDAGSKOMIKER":
		hverdagskomiker_pending_power = false
	if quest_id == "SECOND_ICECREAM":
		visited_store_during_second_ice = false
		_entered_kjiwi_during_second_ice = false
	quest_changed.emit(quest_id, Quest.QuestState.AVAILABLE)


func _connect_kjiwi_door_trigger() -> void :
	var door_trigger: Node = get_tree().get_first_node_in_group("KjiwiDoorTrigger")
	if door_trigger == null:
		door_trigger = get_tree().root.find_child("KjiwiDoorTrigger", true, false)
	if door_trigger == null:
		return
	if door_trigger.has_signal("player_entered_store")\
	and not door_trigger.player_entered_store.is_connected(_on_kjiwi_player_entered_store):
		door_trigger.player_entered_store.connect(_on_kjiwi_player_entered_store)
	if door_trigger.has_signal("player_exited_store")\
	and not door_trigger.player_exited_store.is_connected(_on_kjiwi_player_exited_store):
		door_trigger.player_exited_store.connect(_on_kjiwi_player_exited_store)


func _on_kjiwi_player_entered_store() -> void :
	if has_active_quest("SECOND_ICECREAM"):
		_entered_kjiwi_during_second_ice = true


func _on_kjiwi_player_exited_store() -> void :
	if has_active_quest("SECOND_ICECREAM") and _entered_kjiwi_during_second_ice:
		visited_store_during_second_ice = true
	_entered_kjiwi_during_second_ice = false


const NPC_TURN_IN_QUEST_IDS: Array[String] = [
	"IVER_BEVIS", 
	"KRIS_LUA", 
	"STEINAR_GRUS", 
	"FINAL_DELIVERY", 
	"VINDKAST_PLAKATER", 
]


func _maybe_complete_quest(quest: Quest) -> void :
	if quest == null:
		return
	if quest.quest_id == "HVERDAGSKOMIKER" and quest.is_complete():
		hverdagskomiker_pending_power = true


		set_quest_hint("HVERDAGSKOMIKER", "Snakk med Hverdagskomikeren")
		return
	if quest.is_complete():
		if quest.quest_id in NPC_TURN_IN_QUEST_IDS:
			return
		complete_quest(quest)

func complete_quest(quest: Quest):
	if quest == null:
		return
	if is_quest_completed(quest.quest_id):
		push_warning("Quest already completed: " + quest.quest_id)
		return
	print("✅ Quest completed: ", quest.name)

	quest.state = Quest.QuestState.COMPLETED
	completed_quests[quest.quest_id] = true
	SfxManager.play("quest_completed")


	if quest.reward_money > 0:
		if _has_document_reward(quest):
			push_warning("Quest %s has document reward item and money reward; skipping direct money reward." % quest.quest_id)
		else:
			add_flat_money_reward(quest.reward_money)

	for item_id in quest.reward_items:
		if item_id is String and item_id != "":
			add_item(item_id, 1)

	if quest.quest_id == "IVER_BEVIS":

		set_objective_hint(
			"KRIS_LUA", "find_hat", "Lever grus til Stein og Steinar"
		)

	if quest.quest_id == "GORGON_ROBBERY":
		if gorgon_stolen_item != "":
			add_item(gorgon_stolen_item, 1)
			gorgon_stolen_item = ""


		set_quest_hint("HVERDAGSKOMIKER", "Snakk med Hverdagskomikeren")


	for next_quest_id in quest.unlock_quests:
		var next_quest = _load_quest_by_id(next_quest_id)
		if next_quest:
			add_quest(next_quest, true)

	active_quests.erase(quest.quest_id)
	quest_completed.emit(quest.quest_id)
	quest_changed.emit(quest.quest_id, Quest.QuestState.COMPLETED)
	_on_quest_completed_story_hooks(quest.quest_id)
	if quest.quest_id == "HVERDAGSKOMIKER":
		hverdagskomiker_pending_power = false
		_open_hverdagskomiker_door_passage()
		_unlock_kjiwi_door()
	if quest.quest_id == "FINAL_DELIVERY":
		_record_playthrough_time()
		_start_ending_sequence()


func _on_quest_completed_story_hooks(quest_id: String) -> void :
	match quest_id:
		"KRIS_LUA":
			_refresh_kjiwi_door_power()
			_trigger_power_outage()


func _refresh_kjiwi_door_power() -> void :
	var tree: = get_tree()
	if tree == null:
		return
	for door in tree.get_nodes_in_group("KjiwiDoor"):
		if door == null or not is_instance_valid(door):
			continue
		if door.has_method("_refresh_power_state"):
			door.call("_refresh_power_state")


const POWER_OUTAGE_SFX_PATH: = "res://assets/sfx/erdetlyd/splice/electricburst.wav"


func _call_group_method_safe(group: String, method: String) -> void :
	var tree: = get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group(group):
		if node == null or not is_instance_valid(node):
			continue
		if node.has_method(method):
			node.call(method)


func _trigger_power_outage() -> void :
	_play_power_outage_sfx()
	_call_group_method_safe("SceneLights", "turn_off")
	_set_powered_light_group_visible(false)
	_set_inline_artificial_lights_visible(false)




func restore_scene_lights_after_power() -> void :
	_call_group_method_safe("SceneLights", "turn_on")
	_set_powered_light_group_visible(true)
	_set_inline_artificial_lights_visible(true)
	_open_hverdagskomiker_door_passage()


func _open_hverdagskomiker_door_passage() -> void :
	var hk_door: = _get_hverdagskomiker_door()
	if hk_door == null or not is_instance_valid(hk_door):
		return
	hk_door.visible = false
	_set_hverdagskomiker_door_collision(hk_door, false)


func _set_hverdagskomiker_door_collision(door: Node3D, enabled: bool) -> void :
	if door is CSGShape3D:
		(door as CSGShape3D).use_collision = enabled
	for child in door.get_children():
		if child is CSGShape3D:
			(child as CSGShape3D).use_collision = enabled
		elif child is CollisionShape3D:
			(child as CollisionShape3D).disabled = not enabled


func _get_hverdagskomiker_door() -> Node3D:
	var tree: = get_tree()
	if tree == null:
		return null
	var scene: Node = tree.current_scene
	if scene != null:
		var by_path: = scene.get_node_or_null(
			"NavigationRegion3D/PostVeien/DoorToHverdagskomiker"
		) as Node3D
		if by_path != null:
			return by_path
	for node in tree.get_nodes_in_group("Hverdagskomiker_Door"):
		if node is Node3D:
			return node as Node3D
	return null


func _play_power_outage_sfx() -> void :
	var tree: = get_tree()
	if tree == null or tree.root == null:
		return
	var sound: AudioStream = load(POWER_OUTAGE_SFX_PATH) as AudioStream
	if sound == null:
		push_warning("Power outage SFX missing: %s" % POWER_OUTAGE_SFX_PATH)
		return
	var audio: = AudioStreamPlayer.new()
	audio.stream = sound
	audio.bus = "Sfx"
	tree.root.add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)


func _set_powered_light_group_visible(visible: bool) -> void :
	var tree: = get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group("PoweredLight"):
		if node == null or not is_instance_valid(node):
			continue
		if node is Light3D and not _is_player_light(node as Light3D):
			(node as Light3D).visible = visible


func _is_player_light(light: Light3D) -> bool:
	var node: Node = light
	while node != null:
		if node.is_in_group("PlayerCharacter"):
			return true
		node = node.get_parent()
	return false


func _set_inline_artificial_lights_visible(visible: bool) -> void :
	var root: Node = get_tree().current_scene
	if root == null or not is_instance_valid(root):
		return
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node == null or not is_instance_valid(node):
			continue
		if node is OmniLight3D or node is SpotLight3D:
			var light: = node as Light3D
			if not _is_player_light(light):
				light.visible = visible
		for child in node.get_children():
			stack.append(child)


func _unlock_kjiwi_door() -> void :
	var tree: = get_tree()
	if tree == null:
		return
	for door in tree.get_nodes_in_group("KjiwiDoor"):
		if door == null or not is_instance_valid(door):
			continue
		if door.has_method("unlock"):
			door.call("unlock")


func is_ending_sequence_active() -> bool:
	return _ending_sequence_started


func _start_ending_sequence() -> void :
	if _ending_sequence_started:
		return
	_ending_sequence_started = true
	if ENDING_SEQUENCE_SCENE == null:
		push_warning("Ending sequence scene missing.")
		return
	var current: = get_tree().current_scene
	if current == null:
		_ending_sequence_started = false
		push_warning("No current scene to attach ending sequence.")
		return
	var ending: = ENDING_SEQUENCE_SCENE.instantiate()
	current.add_child(ending)

func end_minigame(minigame_id: String, score):
	minigame_ended.emit(minigame_id, int(score))
	if active_minigame_id == minigame_id:
		active_minigame_id = ""
	if score <= 0:
		return
	var quest_system = _get_quest_system_node()
	if quest_system and quest_system.has_method("on_minigame_completed"):
		quest_system.on_minigame_completed(minigame_id)

func start_minigame(minigame_id: String) -> bool:
	if active_minigame_id != "" and active_minigame_id != minigame_id:
		push_warning("Cannot start minigame '%s'. Active minigame: '%s'" % [minigame_id, active_minigame_id])
		return false
	active_minigame_id = minigame_id
	minigame_started.emit(minigame_id)
	return true

func is_minigame_active() -> bool:
	return active_minigame_id != ""

func _load_quest_by_id(quest_id: String):
	var from_registry = quest_registry.get(quest_id)
	if from_registry:
		return from_registry
	return _load_legacy_quest_by_id(quest_id)

func _load_all_quest_definitions():
	quest_registry.clear()
	for resource_path in QUEST_RESOURCE_PATHS:
		var quest = ResourceLoader.load(resource_path)
		if not (quest is Quest):
			push_warning("Failed to load quest resource: " + resource_path)
			continue
		if quest.quest_id == "":
			push_warning("Quest resource missing quest_id: " + resource_path)
			continue
		if quest_registry.has(quest.quest_id):
			push_warning("Duplicate quest_id '%s' in %s" % [quest.quest_id, resource_path])
			continue
		quest_registry[quest.quest_id] = quest

func _load_legacy_quest_by_id(quest_id: String):
	var legacy_files = {
		"GRANDPA_REQUEST": "res://data/quests/quest_01_grandpa_request.tres", 
		"BANK_INHERITANCE": "res://data/quests/quest_02_bank_inheritance.tres", 
		"ECONOMIC_REALITY": "res://data/quests/quest_03_economic_reality.tres", 
		"GRANDPA_DISAPPOINTMENT": "res://data/quests/quest_04_disappointment.tres", 
		"SCHOLARSHIP_APPLICATION": "res://data/quests/quest_05_scholarship_application.tres", 
		"BANK_DEPOSIT": "res://data/quests/quest_06_bank_deposit.tres", 
		"SECOND_ICECREAM": "res://data/quests/quest_07_second_icecream.tres", 
		"FINAL_DELIVERY": "res://data/quests/quest_08_final_delivery.tres", 
		"KRIS_LUA": "res://data/quests/quest_kris_lua.tres", 
		"IVER_BEVIS": "res://data/quests/quest_09_iver_bevis.tres", 
		"STEINAR_GRUS": "res://data/quests/quest_10_steinar_grus.tres", 
		"HVERDAGSKOMIKER": "res://data/quests/quest_hverdagskomiker.tres", 
		"GORGON_ROBBERY": "res://data/quests/quest_gorgon_robbery.tres", 
		"VINDKAST_PLAKATER": "res://data/quests/quest_vindkast.tres"
	}
	var path = legacy_files.get(quest_id, "")
	if path != "":
		var quest = ResourceLoader.load(path)
		if quest is Quest:
			return quest
	return null

func get_quest_definition(quest_id: String) -> Quest:
	return _load_quest_by_id(quest_id)

func get_active_quests() -> Array:
	var result: Array = []
	for quest in active_quests.values():
		result.append(quest)
	return result

func is_quest_completed(quest_id: String) -> bool:
	return completed_quests.has(quest_id)

func has_active_quest(quest_id: String) -> bool:
	return active_quests.has(quest_id)


func is_iver_hunting_active() -> bool:
	if not has_active_quest("IVER_BEVIS"):
		return false
	var quest: Quest = active_quests.get("IVER_BEVIS") as Quest
	if quest == null:
		return false
	var f_prog: = int(quest.objective_progress.get("collect_fugleskinn", 0))
	var e_prog: = int(quest.objective_progress.get("collect_elgskinn", 0))
	return f_prog < 3 or e_prog < 1

func _get_quest_system_node() -> Node:
	var root: = get_tree().root
	var qs: = root.get_node_or_null("QuestSystem")
	if qs != null:
		return qs
	var current_scene: = get_tree().current_scene
	if current_scene != null:
		return current_scene.get_node_or_null("QuestManager")
	return null

func _has_document_reward(quest: Quest) -> bool:
	for item_id in quest.reward_items:
		if not (item_id is String):
			continue
		if item_id.contains("document") or item_id.contains("application"):
			return true
	return false

func _on_item_used(item_id: String) -> void :
	match item_id:
		"kefir":
			var player: Node = get_player()
			if player == null:
				return
			var health: Node = player.get_node_or_null("HealthComponent")
			if health != null and health.has_method("heal"):
				health.heal(30.0)
				SfxManager.play("player_heal")
				if player.has_method("_refresh_health_ui"):
					player.call("_refresh_health_ui")

func _on_gunshot_fired(_position: Vector3, _range: float) -> void :

	pass


func _on_item_added_quest_check(item_id: String, amount: int) -> void :
	match item_id:
		"fugleskinn":
			if has_active_quest("IVER_BEVIS"):
				update_quest_objective("IVER_BEVIS", "collect_fugleskinn", amount)
		"elgskinn":
			if has_active_quest("IVER_BEVIS"):
				update_quest_objective("IVER_BEVIS", "collect_elgskinn", amount)
		"peak_performance_lua":
			if has_active_quest("KRIS_LUA"):
				update_quest_objective("KRIS_LUA", "find_hat", 1)
		"kobber":
			if has_active_quest("HVERDAGSKOMIKER"):
				update_quest_objective("HVERDAGSKOMIKER", "collect_kobber", amount)
		"plast":
			if has_active_quest("HVERDAGSKOMIKER"):
				update_quest_objective("HVERDAGSKOMIKER", "collect_plast", amount)
		"gummi":
			if has_active_quest("HVERDAGSKOMIKER"):
				update_quest_objective("HVERDAGSKOMIKER", "collect_gummi", amount)
		"gard_plakat":
			if has_active_quest("VINDKAST_PLAKATER"):
				update_quest_objective("VINDKAST_PLAKATER", "collect_plakater", amount)

var _item_cache: Dictionary = {}

func _load_item_data(item_id: String) -> ItemData:
	if _item_cache.has(item_id):
		return _item_cache[item_id] as ItemData
	var path = "res://data/items/%s.tres" % item_id
	var loaded = ResourceLoader.load(path)
	if loaded is ItemData:
		_item_cache[item_id] = loaded
		return loaded
	print("Failed to load ItemData for: ", item_id, " path: ", path)
	return null

func _validate_resources():
	var item_ids = [
		"icecream", "inheritance_document", 
		"approved_application", "god_morgen_yoghurt", "painkillers", "kefir", 
		"peak_performance_lua", "grus", "fugleskinn", "elgskinn", 
		"kobber", "plast", "gummi", "stoepsel", "fiskestang", 
		"id_card", "tnt"
	]
	for item_id in item_ids:
		var data: = _load_item_data(item_id)
		if data == null:
			push_warning("  ✗ MISSING ITEM: " + item_id)




func load_settings() -> void :
	var cfg: = ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	mouse_sensitivity = float(cfg.get_value("settings", "mouse_sensitivity", 1.0))
	master_volume = float(cfg.get_value("settings", "master_volume", 1.0))
	music_volume = float(cfg.get_value("audio", "music_volume", 1.0))
	sfx_volume = float(cfg.get_value("audio", "sfx_volume", 1.0))
	voice_volume = float(cfg.get_value("audio", "voice_volume", 1.0))
	speedrun_timer_on = bool(cfg.get_value("settings", "speedrun_timer_on", false))
	shadows_enabled = bool(cfg.get_value("graphics", "shadows", true))
	render_distance = float(cfg.get_value("video", "render_distance", 150.0))
	fullscreen_enabled = bool(cfg.get_value("video", "fullscreen", not OS.has_feature("editor")))
	window_size_index = int(cfg.get_value("video", "window_size_index", 2))
	vsync_enabled = bool(cfg.get_value("video", "vsync", true))
	brightness = float(cfg.get_value("video", "brightness", 1.0))
	contrast = float(cfg.get_value("video", "contrast", 1.0))
	invert_y = bool(cfg.get_value("settings", "invert_y", false))
	last_playthrough_time = float(cfg.get_value("settings", "last_playthrough_time", 0.0))
	game_completed_once = bool(cfg.get_value("settings", "game_completed_once", false))
	var skins_v: Variant = cfg.get_value("skins", "active", {})
	if skins_v is Dictionary:
		active_skins = skins_v
	supporter_gestures_active = bool(cfg.get_value("skins", "gestures", true))


func save_settings() -> void :
	var cfg: = ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("settings", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("settings", "master_volume", master_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "voice_volume", voice_volume)
	cfg.set_value("settings", "speedrun_timer_on", speedrun_timer_on)
	cfg.set_value("graphics", "shadows", shadows_enabled)
	cfg.set_value("video", "render_distance", render_distance)
	cfg.set_value("video", "fullscreen", fullscreen_enabled)
	cfg.set_value("video", "window_size_index", window_size_index)
	cfg.set_value("video", "vsync", vsync_enabled)
	cfg.set_value("video", "brightness", brightness)
	cfg.set_value("video", "contrast", contrast)
	cfg.set_value("settings", "invert_y", invert_y)
	cfg.set_value("settings", "last_playthrough_time", last_playthrough_time)
	cfg.set_value("settings", "game_completed_once", game_completed_once)
	cfg.set_value("skins", "active", active_skins)
	cfg.set_value("skins", "gestures", supporter_gestures_active)
	cfg.save(SETTINGS_PATH)


func apply_mouse_sensitivity() -> void :
	var player: = get_player()
	if player and player.has_method("apply_mouse_sensitivity_from_settings"):
		player.apply_mouse_sensitivity_from_settings()


func apply_master_volume() -> void :
	var bus_index: = AudioServer.get_bus_index("Master")
	if bus_index < 0:
		return
	var clamped: = clampf(master_volume, 0.0, 1.0)
	if clamped <= 0.0001:
		AudioServer.set_bus_mute(bus_index, true)
		AudioServer.set_bus_volume_db(bus_index, -80.0)
		return
	AudioServer.set_bus_mute(bus_index, false)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(clamped))


func apply_music_volume(v: float) -> void :
	music_volume = clampf(v, 0.0, 1.0)
	_set_bus_volume_linear("Music", music_volume)

	_set_bus_volume_linear_offset("Radio", RADIO_BUS_BASE_DB, music_volume)


func apply_sfx_volume(v: float) -> void :
	sfx_volume = clampf(v, 0.0, 1.0)
	_set_bus_volume_linear("Sfx", sfx_volume)
	_set_bus_volume_linear_offset("Ambience", AMBIENCE_BUS_BASE_DB, sfx_volume)


func apply_voice_volume(v: float) -> void :
	voice_volume = clampf(v, 0.0, 1.0)
	_set_bus_volume_linear("Voice", voice_volume)


func _set_bus_volume_linear(bus_name: String, linear: float) -> void :
	var bus_index: = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	if linear <= 0.0001:
		AudioServer.set_bus_mute(bus_index, true)
		AudioServer.set_bus_volume_db(bus_index, -80.0)
		return
	AudioServer.set_bus_mute(bus_index, false)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(linear))


func _set_bus_volume_linear_offset(bus_name: String, base_db: float, linear: float) -> void :
	var bus_index: = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	if linear <= 0.0001:
		AudioServer.set_bus_mute(bus_index, true)
		AudioServer.set_bus_volume_db(bus_index, -80.0)
		return
	AudioServer.set_bus_mute(bus_index, false)
	AudioServer.set_bus_volume_db(bus_index, base_db + linear_to_db(linear))


func apply_brightness_contrast() -> void :
	var player: = get_player()
	if player == null or not player.is_inside_tree():
		return
	var world: = player.get_world_3d()
	if world == null or world.environment == null:
		return
	var env: = world.environment
	env.adjustment_enabled = true
	env.adjustment_brightness = brightness
	env.adjustment_contrast = contrast


func apply_render_distance(dist: float) -> void :
	render_distance = dist
	var player: = get_player()
	if player == null:
		return
	var cam: = player.get_node_or_null("CameraHolder/CameraRecoilHolder/Camera") as Camera3D
	if cam != null:


		cam.far = dist + 10.0
	if not player.is_inside_tree():
		return
	var world: = player.get_world_3d()
	if world == null:
		return
	var env: = world.environment


	if env != null and env.fog_enabled and env.fog_mode == Environment.FOG_MODE_DEPTH:


		env.fog_depth_begin = dist * 0.45
		env.fog_depth_end = dist * 0.85
	_apply_foliage_visibility(dist)



const FOLIAGE_BASELINE_DIST: = 150.0
var _foliage_multimesh: Array = []






func _apply_foliage_visibility(dist: float) -> void :
	if _foliage_multimesh.is_empty():
		_cache_foliage()
	var scale: = dist / FOLIAGE_BASELINE_DIST
	for item in _foliage_multimesh:
		var mm: = item as MultiMeshInstance3D
		if mm == null or not is_instance_valid(mm):
			continue
		var base: float = float(mm.get_meta("base_vis_end", 0.0))
		if base <= 0.0:
			continue
		mm.visibility_range_end = base * scale
		mm.visibility_range_end_margin = base * scale * 0.1


func _cache_foliage() -> void :
	_foliage_multimesh.clear()
	var tree: = get_tree()
	if tree == null or tree.current_scene == null:
		return
	_collect_foliage(tree.current_scene)


func _collect_foliage(node: Node) -> void :
	if node is MultiMeshInstance3D:
		var mm: = node as MultiMeshInstance3D

		if mm.visibility_range_end > 0.0:
			if not mm.has_meta("base_vis_end"):
				mm.set_meta("base_vis_end", mm.visibility_range_end)
			_foliage_multimesh.append(mm)
	for child in node.get_children():
		_collect_foliage(child)


func apply_fullscreen(enabled: bool) -> void :
	fullscreen_enabled = enabled
	var mode: = DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
	if not enabled:
		apply_window_size()
	save_settings()


func apply_window_size() -> void :
	if fullscreen_enabled:
		return
	window_size_index = clampi(window_size_index, 0, WINDOW_SIZES.size() - 1)
	var target: Vector2i = WINDOW_SIZES[window_size_index]
	var screen: = DisplayServer.window_get_current_screen()
	var usable: = DisplayServer.screen_get_usable_rect(screen)
	target.x = mini(target.x, usable.size.x)
	target.y = mini(target.y, usable.size.y)
	DisplayServer.window_set_size(target)
	DisplayServer.window_set_position(usable.position + (usable.size - target) / 2)


func toggle_fullscreen() -> void :
	apply_fullscreen( not fullscreen_enabled)


func apply_vsync(enabled: bool) -> void :
	vsync_enabled = enabled
	var mode: = DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(mode)


func reset_settings_to_defaults() -> void :
	mouse_sensitivity = 1.0
	invert_y = false
	master_volume = 1.0
	music_volume = 1.0
	sfx_volume = 1.0
	voice_volume = 1.0
	speedrun_timer_on = false
	shadows_enabled = true
	render_distance = 150.0
	vsync_enabled = true
	window_size_index = 2
	brightness = 1.0
	contrast = 1.0
	apply_mouse_sensitivity()
	apply_master_volume()
	apply_music_volume(music_volume)
	apply_sfx_volume(sfx_volume)
	apply_voice_volume(voice_volume)
	apply_shadows(shadows_enabled)
	apply_render_distance(render_distance)
	apply_vsync(vsync_enabled)
	apply_brightness_contrast()
	apply_fullscreen( not OS.has_feature("editor"))
	if SpeedrunTimer:
		SpeedrunTimer.refresh_visibility()
	save_settings()


func _on_scene_changed() -> void :
	_foliage_multimesh.clear()
	call_deferred("apply_shadows", shadows_enabled)
	call_deferred("apply_render_distance", render_distance)
	call_deferred("apply_brightness_contrast")
	call_deferred("_activate_scene_music")
	call_deferred("_connect_kjiwi_door_trigger")
	call_deferred("_cache_player_node")
	call_deferred("_maybe_debug_start_gorgon_horror")
	call_deferred("_maybe_apply_debug_speed_boost")


func _maybe_apply_debug_speed_boost() -> void :
	if not debug_speed_boost:
		return
	await get_tree().create_timer(1.0).timeout
	var player: = get_player()
	if player == null:
		return
	if player.has_meta("debug_run_speed_boost_applied"):
		return
	if "runSpeed" in player:
		player.set("runSpeed", float(player.get("runSpeed")) * 3.0)
		player.set_meta("debug_run_speed_boost_applied", true)


func _maybe_debug_start_gorgon_horror() -> void :
	if not debug_start_gorgon_horror:
		return

	for i in 12:
		await get_tree().create_timer(0.5).timeout
		var scene: = get_tree().current_scene
		if scene == null or scene.scene_file_path != "res://levels/main_demo.tscn":
			continue
		var horror: Node = get_tree().get_first_node_in_group("GorgonHorror")
		var player: Node = get_player()
		if horror == null or player == null:
			continue
		if horror.has_method("activate"):
			if bool(horror.get("_active")):
				return
			horror.call("activate")
		return
	push_warning("[Debug] Could not start Gorgon horror: main_demo/player/GorgonHorror not found.")


func get_player() -> Node3D:
	if NetworkManager != null and NetworkManager.is_active:
		# Who "the player" means varies per call in multiplayer (the local
		# player, or whichever peer's request the host is currently
		# applying) — never cache this here, see NetUtil.get_acting_player().
		return NetUtil.get_acting_player()
	if _cached_player != null and is_instance_valid(_cached_player):
		return _cached_player
	var tree: = get_tree()
	if tree == null:
		return null
	_cached_player = tree.get_first_node_in_group("PlayerCharacter") as Node3D
	return _cached_player


func _cache_player_node() -> void :
	_cached_player = null
	get_player()


func _activate_scene_music() -> void :
	var scene: = get_tree().current_scene
	if scene == null:
		return
	if scene.scene_file_path == "res://levels/main_demo.tscn":
		if get_tree().get_first_node_in_group("IntroSequence") != null:
			return
		MusicManager.activate_idle()


func apply_shadows(enabled: bool) -> void :
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for node in tree.get_nodes_in_group("DirectionalLight"):
		if node is DirectionalLight3D:
			(node as DirectionalLight3D).shadow_enabled = enabled
	for node in tree.get_nodes_in_group("SceneLights"):
		if node is OmniLight3D:
			(node as OmniLight3D).shadow_enabled = false
	RenderingServer.directional_shadow_atlas_set_size(4096 if enabled else 0, true)


func _record_playthrough_time() -> void :
	if SpeedrunTimer and speedrun_timer_on:
		SpeedrunTimer.stop()
		last_playthrough_time = SpeedrunTimer.get_elapsed()
	else:
		last_playthrough_time = Time.get_ticks_msec() / 1000.0 - session_start_time
	game_completed_once = true
	save_settings()


func get_scholarship_penalty_remaining() -> float:
	var now: float = Time.get_ticks_msec() / 1000.0
	return maxf(0.0, scholarship_penalty_until - now)


func apply_for_id_card() -> void :
	if _redirect_to_host("apply_for_id_card", []):
		return
	if id_card_ready or id_card_collected:
		return
	id_card_ready = true
	_save_id_card_data()


func collect_id_card() -> bool:
	if _redirect_to_host("collect_id_card", []):
		return true
	if not id_card_ready or id_card_collected:
		return false
	id_card_collected = true
	id_card_ready = false
	add_item("id_card", 1)
	return true


func _save_id_card_data() -> void :
	var cfg: = ConfigFile.new()
	for key in id_card_data:
		cfg.set_value("id_card", key, id_card_data[key])
	cfg.save(ID_CARD_PATH)


func _load_id_card_data() -> void :
	var cfg: = ConfigFile.new()
	if cfg.load(ID_CARD_PATH) != OK:
		return
	if not cfg.has_section("id_card"):
		return
	for key in cfg.get_section_keys("id_card"):
		id_card_data[key] = cfg.get_value("id_card", key)


func set_scholarship_penalty(seconds: float) -> void :
	if seconds <= 0.0:
		scholarship_penalty_until = 0.0
		return
	scholarship_penalty_until = Time.get_ticks_msec() / 1000.0 + seconds


func reset_game():
	current_day = 1
	session_start_time = Time.get_ticks_msec() / 1000.0
	player_money = 0
	player_xp = 0
	inventory.clear()
	active_quests.clear()
	completed_quests.clear()
	failed_quests.clear()
	freezer_icecream_count = 0
	bank_payout_claimed.clear()
	inheritance_spent_on_non_ice_cream = false
	ice_creams_purchased = 0
	active_minigame_id = ""
	dead_npcs.clear()
	npcs_talked_to.clear()
	collected_collectibles.clear()
	hverdagskomiker_pending_power = false
	gorgon_stolen_item = ""
	kid_drawing_taken = false
	scholarship_penalty_until = 0.0
	id_card_ready = false
	id_card_collected = false
	id_card_data = {}
	if FileAccess.file_exists(ID_CARD_PATH):
		DirAccess.remove_absolute(ID_CARD_PATH)
	visited_store_during_second_ice = false
	_entered_kjiwi_during_second_ice = false
	_ending_sequence_started = false
	last_death_cause = ""
	if SpeedrunTimer:
		SpeedrunTimer.reset_timer()
	MusicManager.stop()


	money_changed.emit(0)
	game_reset.emit()

func get_stats() -> Dictionary:
	return {
		"name": player_name, 
		"money": player_money, 
		"active_quests": active_quests.size(), 
		"completed_quests": completed_quests.size(), 
		"inventory_size": inventory.size()
	}

func print_status() -> void :
	pass
