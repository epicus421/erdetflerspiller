extends Node3D

const PREREQ_QUEST_IDS: Array[String] = [
	"GRANDPA_REQUEST", 
	"BANK_INHERITANCE", 
	"ECONOMIC_REALITY", 
	"GRANDPA_DISAPPOINTMENT", 
	"SCHOLARSHIP_APPLICATION", 
	"BANK_DEPOSIT", 
	"KRIS_LUA", 
]


func _ready() -> void :
	if GameManager:
		GameManager.play_intro_sequence = false
		_setup_prerequisites()
	print("HK TEST — prerequisites done")
	print("Walk up to KjiwiDoor to trigger HVERDAGSKOMIKER quest")


func _setup_prerequisites() -> void :
	for qid in PREREQ_QUEST_IDS:
		if GameManager.is_quest_completed(qid):
			continue
		if not GameManager.has_active_quest(qid):
			GameManager.add_quest_by_id(qid, true)
		GameManager.complete_quest_by_id(qid)
	GameManager.add_item("kobber", 1)
	GameManager.add_item("plast", 1)
	GameManager.add_item("gummi", 1)
	GameManager.player_money = 500
	GameManager.money_changed.emit(GameManager.player_money)


func _unhandled_input(event: InputEvent) -> void :
	if event is InputEventKey and event.is_pressed() and not event.echo:
		var key_event: = event as InputEventKey
		if key_event.keycode == KEY_F5:
			var player: Node3D = NetUtil.get_local_player() as Node3D
			if player != null:
				player.global_position = Vector3(0, 1, 0)
		elif key_event.keycode == KEY_F6:
			GameManager.add_item("kobber", 1)
			GameManager.add_item("plast", 1)
			GameManager.add_item("gummi", 1)
			print("Ingredients given")
		elif key_event.keycode == KEY_F7:
			GameManager.add_item("stoepsel", 1)
			print("Støpsel given")
