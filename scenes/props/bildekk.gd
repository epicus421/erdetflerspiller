extends StaticBody3D

var _shot: bool = false
var _player_nearby: bool = false
var _prompt: Label3D = null


func _ready() -> void :

	var area: = Area3D.new()

	area.set_collision_mask_value(1, true)
	area.set_collision_mask_value(2, true)
	var shape: = CollisionShape3D.new()
	var sphere: = SphereShape3D.new()
	sphere.radius = 1.6
	shape.shape = sphere
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect( func(b: Node) -> void :
		if b.is_in_group("PlayerCharacter"):
			_player_nearby = true
			if _prompt != null and not _shot:
				_prompt.visible = true
	)
	area.body_exited.connect( func(b: Node) -> void :
		if b.is_in_group("PlayerCharacter"):
			_player_nearby = false
			if _prompt != null:
				_prompt.visible = false
	)

	_prompt = Label3D.new()
	_prompt.text = "E — Plukk opp bildekk"
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.pixel_size = 0.005
	_prompt.font_size = 28
	_prompt.no_depth_test = true
	_prompt.position = Vector3(0, 0.7, 0)
	_prompt.visible = false
	add_child(_prompt)


func _unhandled_input(event: InputEvent) -> void :
	if not _player_nearby or _shot:
		return
	if not event.is_action_pressed("interaction"):
		return
	if DialogueUI and DialogueUI.is_open():
		return
	_shot = true
	GameManager.add_item("gummi", 1)
	queue_free()
