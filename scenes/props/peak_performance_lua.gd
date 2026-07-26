extends RigidBody3D

var in_range: bool = false
var _prompt: Label3D = null

@onready var pickup_area: Area3D = $PickupArea


func _ready() -> void :
	if is_in_group("Carriable"):
		remove_from_group("Carriable")
	if pickup_area:
		pickup_area.body_entered.connect(_on_body_entered)
		pickup_area.body_exited.connect(_on_body_exited)

	_prompt = Label3D.new()
	_prompt.text = "E — Plukk opp caps"
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.pixel_size = 0.005
	_prompt.font_size = 28
	_prompt.no_depth_test = true
	_prompt.render_priority = 10
	_prompt.outline_render_priority = 9
	_prompt.position = Vector3(0, 0.5, 0)
	_prompt.visible = false
	add_child(_prompt)


	var glow: = OmniLight3D.new()
	glow.light_color = Color(1.0, 0.85, 0.5)
	glow.light_energy = 0.9
	glow.omni_range = 2.0
	glow.position = Vector3(0, 0.3, 0)
	add_child(glow)


func _input(_event: InputEvent) -> void :
	if not in_range:
		return
	if Input.is_action_just_pressed("interaction") or Input.is_action_just_pressed("carry_object"):
		GameManager.add_item("peak_performance_lua", 1)
		var quest_system: Node = get_node_or_null("/root/QuestSystem")
		if quest_system and quest_system.has_method("on_item_collected"):
			quest_system.call("on_item_collected", "peak_performance_lua")
		queue_free()


func _on_body_entered(body: Node) -> void :
	if body.is_in_group("PlayerCharacter"):
		in_range = true
		if _prompt != null:
			_prompt.visible = true


func _on_body_exited(body: Node) -> void :
	if body.is_in_group("PlayerCharacter"):
		in_range = false
		if _prompt != null:
			_prompt.visible = false
