extends Area3D

@export var item_id: String = ""
@export var display_label: String = ""

var _player_nearby: Node = null
var _picked_up: bool = false


func _ready() -> void :
	monitoring = true
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if display_label == "" and item_id != "":
		display_label = item_id


func _unhandled_input(event: InputEvent) -> void :
	if _picked_up or _player_nearby == null:
		return
	if event.is_action_pressed("interaction"):
		_pick_up()
		get_viewport().set_input_as_handled()


func _pick_up() -> void :
	if item_id == "":
		return
	_picked_up = true
	GameManager.add_item(item_id, 1)
	var qs: Node = GameManager._get_quest_system_node()
	if qs and qs.has_method("on_item_collected"):
		qs.call("on_item_collected", item_id, 1)
	queue_free()


func _on_body_entered(body: Node3D) -> void :
	if body.is_in_group("PlayerCharacter"):
		_player_nearby = body


func _on_body_exited(body: Node3D) -> void :
	if body.is_in_group("PlayerCharacter"):
		_player_nearby = null
