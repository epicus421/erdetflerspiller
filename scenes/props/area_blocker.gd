extends StaticBody3D

@export var unlock_on_quest: String = ""


func _ready() -> void :
	if unlock_on_quest == "":
		return
	if GameManager.has_quest(unlock_on_quest):
		queue_free()
		return
	GameManager.quest_changed.connect(_on_quest_changed)
	await get_tree().process_frame
	if GameManager.has_quest(unlock_on_quest):
		queue_free()


func _on_quest_changed(quest_id: String, _state: int) -> void :
	if quest_id != unlock_on_quest:
		return
	if GameManager.has_quest(unlock_on_quest):
		queue_free()
