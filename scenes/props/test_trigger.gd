extends Area3D

enum TriggerAction{
	DIALOGUE, 
	MENU, 
	SCHOLARSHIP, 
	FISHING, 
	LEMONADE, 
	POWER_OFF, 
	POWER_ON, 
	DEATH, 
	ITEM_NOTIFY, 
}

@export var trigger_label: String = "Test"
@export var trigger_action: TriggerAction = TriggerAction.DIALOGUE

var _player_nearby: bool = false
var _label: Label3D


func _ready() -> void :
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_label = Label3D.new()
	_label.name = "Label3D"
	_label.text = "E — " + trigger_label
	_label.position = Vector3(0, 2, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 32
	_label.pixel_size = 0.005
	_label.visible = false
	add_child(_label)


func _on_body_entered(body: Node3D) -> void :
	if body.is_in_group("PlayerCharacter"):
		_player_nearby = true
		_label.visible = true


func _on_body_exited(body: Node3D) -> void :
	if body.is_in_group("PlayerCharacter"):
		_player_nearby = false
		_label.visible = false


func _unhandled_input(event: InputEvent) -> void :
	if not _player_nearby:
		return
	if not Input.is_action_just_pressed("interaction"):
		return
	_run_action()
	get_viewport().set_input_as_handled()


func _run_action() -> void :
	match trigger_action:
		TriggerAction.DIALOGUE:
			DialogueUI.show_dialogue(
				[
					"Dette er en testlinje.", 
					"Dette er linje to.", 
					"Dette er linje tre.", 
				], 
				"Test NPC", 
				Callable()
			)
		TriggerAction.MENU:
			DialogueUI.show_menu(
				["Hva vil du?"], 
				[
					{"text": "Valg 1", "action": func(): print("Valg 1")}, 
					{"text": "Valg 2", "action": func(): print("Valg 2")}, 
					{"text": "Lukk", "action": Callable(DialogueUI, "close")}, 
				], 
				"Test Menu"
			)
		TriggerAction.SCHOLARSHIP:
			_spawn_overlay("res://scenes/minigames/scholarship_form.tscn")
		TriggerAction.FISHING:
			_spawn_overlay("res://scenes/minigames/fishing.tscn")
		TriggerAction.LEMONADE:
			_spawn_overlay("res://scenes/props/lemonade_stand.tscn")
		TriggerAction.POWER_OFF:
			if GameManager.has_method("_trigger_power_outage"):
				GameManager._trigger_power_outage()
			else:
				get_tree().call_group("SceneLights", "turn_off")
		TriggerAction.POWER_ON:
			if GameManager.has_method("restore_scene_lights_after_power"):
				GameManager.restore_scene_lights_after_power()
			else:
				get_tree().call_group("SceneLights", "turn_on")
		TriggerAction.DEATH:
			var player: = NetUtil.get_local_player()
			if player:
				var hc: = player.get_node_or_null("HealthComponent")
				if hc and hc.has_method("take_damage"):
					hc.take_damage(999.0)
		TriggerAction.ITEM_NOTIFY:
			GameManager.add_item("icecream", 1)


func _spawn_overlay(scene_path: String) -> void :
	if not ResourceLoader.exists(scene_path):
		push_warning("Test trigger missing scene: %s" % scene_path)
		return
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		return
	var inst: Node = packed.instantiate()
	get_tree().current_scene.add_child(inst)
