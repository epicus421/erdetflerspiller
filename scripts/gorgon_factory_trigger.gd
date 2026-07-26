extends Area3D

var _triggered: bool = false


func _ready() -> void :
	add_to_group("GorgonFactoryTrigger")
	monitoring = true
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void :
	if _triggered:
		return
	if not body.is_in_group("PlayerCharacter"):
		return
	if not GameManager.has_active_quest("GORGON_ROBBERY"):
		return
	_triggered = true
	_gorgon_yells_from_roof()


func _gorgon_yells_from_roof() -> void :
	DialogueUI.show_dialogue(
		[
			"HEI! JA DET VAR MEG!", 
			"Jeg tok gummien din.", 
			"Har mine grunner.", 
			"Ikke spør.", 
			"Men jeg er en rettferdig mann.", 
			"Jeg gir den tilbake.", 
			"Flytt bare disse boksene ned til lastebilen.", 
			"Ryggen min, du skjønner.", 
			"Ikke den beste.", 
			"Men ikke tro at det blir lett.", 
			"Jeg har melkekartonger her oppe.", 
			"Og jeg er ikke redd for å bruke dem.", 
		], 
		"Gorgon", 
		func():
			_start_minigame()
	)


func _start_minigame() -> void :
	var gorgon: Node = get_tree().get_first_node_in_group("Gorgon")
	if gorgon != null and gorgon.has_method("start_throwing"):
		gorgon.start_throwing()
	GameManager.update_quest_objective("GORGON_ROBBERY", "talk_to_gorgon_factory", 1)
