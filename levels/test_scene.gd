extends Node3D

const NPC_BASE: = preload("res://scenes/npc/npc_base.tscn")
const TEST_TRIGGER: = preload("res://scenes/props/test_trigger.tscn")
const STREETLIGHT: = preload("res://scenes/props/streetlight_normal.tscn")

const QUEST_IDS: Array[String] = [
	"GRANDPA_REQUEST", 
	"BANK_INHERITANCE", 
	"ECONOMIC_REALITY", 
	"GRANDPA_DISAPPOINTMENT", 
	"SCHOLARSHIP_APPLICATION", 
	"BANK_DEPOSIT", 
	"SECOND_ICECREAM", 
	"KRIS_LUA", 
	"IVER_BEVIS", 
	"STEINAR_GRUS", 
	"HVERDAGSKOMIKER", 
]

const ITEM_IDS: Array[String] = [
	"fugleskinn", 
	"elgskinn", 
	"grus", 
	"kobber", 
	"plast", 
	"gummi", 
	"fiskestang", 
	"gard_plakat", 
	"icecream", 
	"inheritance_document", 
	"approved_application", 
	"peak_performance_lua", 
	"stoepsel", 
	"wood_scrap", 
	"god_morgen_yoghurt", 
	"painkillers", 
]

@onready var _npc_section: Node3D = $NPCSection
@onready var _ui_section: Node3D = $UISection
@onready var _pickup_section: Node3D = $PickupSection
@onready var _weapon_section: Node3D = $WeaponSection
@onready var _sign_section: Node3D = $SignSection


func _ready() -> void :
	_setup_game_state()
	_spawn_section_signs()
	_spawn_npcs()
	_spawn_ui_triggers()
	_spawn_pickups()
	_spawn_weapons()
	_spawn_test_lights()
	print("TEST SCENE READY — all quests done, money 9999, all items given")


func _setup_game_state() -> void :
	if GameManager == null:
		return
	GameManager.play_intro_sequence = false
	for qid in QUEST_IDS:
		if GameManager.is_quest_completed(qid):
			continue
		if not GameManager.has_active_quest(qid):
			GameManager.add_quest_by_id(qid, true)
		GameManager.complete_quest_by_id(qid)
	GameManager.player_money = 9999
	GameManager.money_changed.emit(GameManager.player_money)
	for iid in ITEM_IDS:
		if not GameManager.has_item(iid):
			GameManager.add_item(iid, 1)


func _spawn_section_signs() -> void :
	_add_sign(_sign_section, "NPCs", Vector3(-30, 6, -6))
	_add_sign(_sign_section, "UI TRIGGERS", Vector3(0, 6, -6))
	_add_sign(_sign_section, "PICKUPS", Vector3(30, 6, -6))
	_add_sign(_sign_section, "WEAPONS", Vector3(-30, 6, 14))


func _add_sign(parent: Node3D, text: String, pos: Vector3) -> void :
	var label: = Label3D.new()
	label.text = text
	label.position = pos
	label.font_size = 64
	label.pixel_size = 0.01
	label.modulate = Color(1, 0.8, 0.2, 1)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)


func _spawn_npcs() -> void :
	var defs: Array[Dictionary] = [
		{"name": "Bestefar", "id": "grandpa"}, 
		{"name": "Bankansatt", "id": "bank_teller"}, 
		{"name": "Chief Keef", "id": "chief_keef"}, 
		{"name": "Kristoffer", "scene": "res://scenes/npc/kristoffer.tscn"}, 
		{"name": "Iver", "scene": "res://scenes/npc/iver.tscn"}, 
		{"name": "Steinar", "scene": "res://scenes/npc/steinar.tscn"}, 
		{"name": "Stein", "scene": "res://scenes/npc/stein.tscn"}, 
		{"name": "Kassedama", "scene": "res://scenes/npc/cashier_npc_base.tscn"}, 
		{"name": "Hverdagskomiker", "scene": "res://scenes/npc/hverdagskomiker.tscn"}, 
	]
	var z: = 0.0
	for def in defs:
		var npc: Node3D
		if def.has("scene"):
			npc = (load(def["scene"]) as PackedScene).instantiate() as Node3D
		else:
			npc = NPC_BASE.instantiate() as Node3D
			npc.set("npc_id", def["id"])
			npc.set("npc_name", def["name"])
		npc.position = Vector3(0, 0, z)
		_npc_section.add_child(npc)
		_add_npc_sign(npc, str(def["name"]), z)
		z += 4.0


func _add_npc_sign(npc: Node3D, display_name: String, _z: float) -> void :
	var label: = Label3D.new()
	label.text = display_name
	label.position = Vector3(0, 2.4, 0)
	label.font_size = 28
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	npc.add_child(label)


func _spawn_ui_triggers() -> void :
	var defs: Array[Dictionary] = [
		{"label": "Dialogue test", "action": 0}, 
		{"label": "Menu test", "action": 1}, 
		{"label": "Stipend form", "action": 2}, 
		{"label": "Fishing minigame", "action": 3}, 
		{"label": "Lemonade stand", "action": 4}, 
		{"label": "Power outage", "action": 5}, 
		{"label": "Power restore", "action": 6}, 
		{"label": "Death test", "action": 7}, 
		{"label": "Item notification", "action": 8}, 
	]
	var col: = 0
	var row: = 0
	for def in defs:
		var trigger: Area3D = TEST_TRIGGER.instantiate() as Area3D
		trigger.position = Vector3(col * 5.0, 0, row * 5.0)
		trigger.set("trigger_label", def["label"])
		trigger.set("trigger_action", def["action"])
		_ui_section.add_child(trigger)
		col += 1
		if col >= 3:
			col = 0
			row += 1


func _spawn_pickups() -> void :
	var defs: Array[Dictionary] = [
		{"scene": "res://scenes/props/weapon_world_pickup.tscn", "label": "GrusSkive", "props": {"weapon_int_id": 6, "display_name": "GrusSkive"}}, 
		{"scene": "res://scenes/props/grus_ammo_pickup.tscn", "label": "Grus ammo"}, 
		{"scene": "res://scenes/props/tnt_pickup.tscn", "label": "TNT"}, 
		{"scene": "res://scenes/props/kobber_pickup.tscn", "label": "Kobber"}, 
		{"scene": "res://scenes/props/gummi_pickup.tscn", "label": "Gummi"}, 
		{"scene": "res://scenes/props/strommast.tscn", "label": "Strømmast"}, 
		{"scene": "res://scenes/props/bildekk.tscn", "label": "Bildekk"}, 
	]
	var col: = 0
	var row: = 0
	for def in defs:
		if not ResourceLoader.exists(def["scene"]):
			continue
		var inst: Node3D = (load(def["scene"]) as PackedScene).instantiate() as Node3D
		if def.has("props"):
			for key in def["props"]:
				inst.set(key, def["props"][key])
		inst.position = Vector3(col * 5.0, 0, row * 5.0)
		_pickup_section.add_child(inst)
		_add_pickup_sign(inst, def["label"])
		col += 1
		if col >= 3:
			col = 0
			row += 1


func _add_pickup_sign(node: Node3D, text: String) -> void :
	var label: = Label3D.new()
	label.text = text
	label.position = Vector3(0, 2.2, 0)
	label.font_size = 22
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.add_child(label)


func _spawn_weapons() -> void :
	var defs: Array[Dictionary] = [
		{"name": "Pistol", "id": 1}, 
		{"name": "SMG", "id": 2}, 
		{"name": "Hagle", "id": 3}, 
		{"name": "Rifle", "id": 4}, 
		{"name": "RPG", "id": 5}, 
	]
	var x: = 0.0
	for def in defs:
		var wpn: RigidBody3D = load("res://scenes/props/shop/wall_weapon.tscn").instantiate() as RigidBody3D
		wpn.position = Vector3(x, 1.5, 0)
		wpn.set("weapon_name", def["name"])
		wpn.set("weapon_int_id", def["id"])
		wpn.set("weapon_price", 0)
		wpn.set("instant_pickup", true)
		_weapon_section.add_child(wpn)
		_add_pickup_sign(wpn, def["name"])
		x += 4.0


func _spawn_test_lights() -> void :
	for i in 3:
		var light: Node3D = STREETLIGHT.instantiate() as Node3D
		light.position = Vector3(12 + i * 8.0, 0, -8)
		_ui_section.add_child(light)


func _unhandled_input(event: InputEvent) -> void :
	if event is InputEventKey and (event as InputEventKey).pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_F5:
				var player: Node3D = NetUtil.get_local_player() as Node3D
				if player != null:
					player.global_position = Vector3.ZERO
			KEY_F6:
				if GameManager.has_method("_trigger_power_outage"):
					GameManager._trigger_power_outage()
				else:
					get_tree().call_group("SceneLights", "turn_off")
			KEY_F7:
				if GameManager.has_method("restore_scene_lights_after_power"):
					GameManager.restore_scene_lights_after_power()
				else:
					get_tree().call_group("SceneLights", "turn_on")
