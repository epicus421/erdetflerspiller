extends Node3D

@onready var label: Label3D = $Label3D
var _status_label: Label3D
var _name_label: Label3D
var _in_range: bool = false

func _ready() -> void :
	label.text = str(GameManager.player_name)
	_create_status_label()
	_create_name_label()
	_setup_interaction_area()
	_update_status()

func _input(event: InputEvent) -> void :
	if not _in_range:
		return
	if DialogueUI.is_open():
		return
	if GameManager.is_minigame_active():
		return
	if not Input.is_action_just_pressed("interaction"):
		return
	_interact()

func _interact() -> void :
	if GameManager.id_card_ready and not GameManager.id_card_collected:
		GameManager.collect_id_card()
		DialogueUI.show_dialogue(["Du fikk ID-kortet ditt i posten!"], "Postkasse")
		_update_status()
	else:
		DialogueUI.show_dialogue(["Postkassen er tom."], "Postkasse")

func _setup_interaction_area() -> void :
	var area: = get_node_or_null("InteractionArea") as Area3D
	if area == null:
		return
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void :
	if body.is_in_group("PlayerCharacter"):
		_in_range = true
		if _name_label:
			_name_label.visible = true

func _on_body_exited(body: Node3D) -> void :
	if body.is_in_group("PlayerCharacter"):
		_in_range = false
		if _name_label:
			_name_label.visible = false

func _create_name_label() -> void :
	_name_label = Label3D.new()
	_name_label.name = "NameLabel"
	_name_label.text = "E — Postkasse"
	_name_label.font_size = 36
	_name_label.pixel_size = 0.003
	_name_label.outline_size = 12
	_name_label.outline_modulate = Color(0, 0, 0, 1)
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.position = Vector3(0, 0.5, 0)
	_name_label.no_depth_test = true
	_name_label.visible = false
	add_child(_name_label)

func _create_status_label() -> void :
	_status_label = Label3D.new()
	_status_label.name = "StatusLabel3D"
	_status_label.font_size = 32
	_status_label.position = label.position + Vector3(0, -0.15, 0)
	_status_label.pixel_size = label.pixel_size
	_status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_status_label)

func _update_status() -> void :
	if _status_label == null:
		return
	if GameManager.id_card_ready and not GameManager.id_card_collected:
		_status_label.text = "Du har post!"
		_status_label.modulate = Color(0.2, 0.8, 0.2, 1)
	else:
		_status_label.text = ""
