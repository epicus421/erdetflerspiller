extends Node

func _ready() -> void :
	GameManager.quest_changed.connect(_on_quest_changed)
	GameManager.quest_progress_updated.connect(_on_quest_progress_updated)
	call_deferred("_sync_hunt_animals")


func _on_quest_changed(quest_id: String, _state: int) -> void :
	if quest_id != "IVER_BEVIS":
		return
	_sync_hunt_animals()


func _on_quest_progress_updated(quest_id: String, _progress: int) -> void :
	if quest_id != "IVER_BEVIS":
		return
	_sync_hunt_animals()


func _sync_hunt_animals() -> void :
	if not GameManager.is_iver_hunting_active():
		return
	enable_for_hunt()


func enable_for_hunt() -> void :
	var all_wildlife: Array = get_tree().get_nodes_in_group("Wildlife")
	for animal in all_wildlife:
		if not is_instance_valid(animal):
			continue
		if animal.has_method("enable_for_hunt"):
			animal.enable_for_hunt()
		elif animal.has_method("set_active"):
			animal.set_active(true)
		animal.visible = true
		animal.process_mode = Node.PROCESS_MODE_INHERIT
	print("[WildlifeManager] Hunt enabled for ", all_wildlife.size(), " animals")
