extends Node3D










@export var dialogue_lines: Array[String] = ["Du trenger en nøkkel for dette."]

@export var prompt_text: String = "E — Undersøk"

@export var speaker_name: String = ""

@export var one_shot: bool = false

var _player_near: bool = false
var _used: bool = false

@onready var _prompt: Label3D = get_node_or_null("PromptLabel3D") as Label3D
@onready var _area: Area3D = get_node_or_null("InteractionArea") as Area3D


func _ready() -> void :
	if _prompt != null:
		_prompt.text = prompt_text
		_prompt.visible = false

		_prompt.render_priority = 10
		_prompt.outline_render_priority = 9
	if _area != null:

		_area.set_collision_mask_value(1, true)
		_area.set_collision_mask_value(2, true)
		_area.monitoring = true
		if not _area.body_entered.is_connected(_on_body_entered):
			_area.body_entered.connect(_on_body_entered)
		if not _area.body_exited.is_connected(_on_body_exited):
			_area.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void :
	if body.is_in_group("PlayerCharacter"):
		_player_near = true
		if _prompt != null and prompt_text != "" and not (_used and one_shot):
			_prompt.visible = true


func _on_body_exited(body: Node3D) -> void :
	if body.is_in_group("PlayerCharacter"):
		_player_near = false
		if _prompt != null:
			_prompt.visible = false


func _unhandled_input(event: InputEvent) -> void :
	if not _player_near or (one_shot and _used):
		return
	if not event.is_action_pressed("interaction"):
		return
	if DialogueUI != null and DialogueUI.has_method("is_open") and DialogueUI.is_open():
		return
	if dialogue_lines.is_empty():
		return
	_used = true
	if _prompt != null and one_shot:
		_prompt.visible = false
	get_viewport().set_input_as_handled()
	DialogueUI.show_dialogue(dialogue_lines, speaker_name, Callable())
