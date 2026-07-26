extends Area3D

var _player_nearby: Node = null
var _picked_up: bool = false
var _prompt: Label3D = null


func _ready() -> void :
	monitoring = true
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_prompt = Label3D.new()
	_prompt.text = "E — Plukk opp dynamitt"
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.pixel_size = 0.005
	_prompt.font_size = 28
	_prompt.no_depth_test = true
	_prompt.position = Vector3(0, 0.5, 0)
	_prompt.visible = false
	add_child(_prompt)


func _unhandled_input(event: InputEvent) -> void :
	if _picked_up or _player_nearby == null:
		return
	if event.is_action_pressed("interaction"):
		_interact()
		get_viewport().set_input_as_handled()


func _interact() -> void :
	_picked_up = true
	GameManager.add_item("tnt", 1)

	if GameManager.has_active_quest("HVERDAGSKOMIKER")\
	and not GameManager.has_item("plast"):
		GameManager.set_objective_hint(
			"HVERDAGSKOMIKER", "collect_plast", "Tilbake til dammen"
		)
	queue_free()


func _on_body_entered(body: Node3D) -> void :
	if body.is_in_group("PlayerCharacter"):
		_player_nearby = body
		if _prompt != null and not _picked_up:
			_prompt.visible = true


func _on_body_exited(body: Node3D) -> void :
	if body.is_in_group("PlayerCharacter"):
		_player_nearby = null
		if _prompt != null:
			_prompt.visible = false
