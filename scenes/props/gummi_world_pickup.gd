extends RigidBody3D

var _player_nearby: bool = false


func _ready() -> void :
	add_to_group("GummiPickup")
	freeze = true

	var area: = Area3D.new()
	var shape: = CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	(shape.shape as SphereShape3D).radius = 1.2
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(
		func(b: Node) -> void :
			if b.is_in_group("PlayerCharacter"):
				_player_nearby = true
	)
	area.body_exited.connect(
		func(b: Node) -> void :
			if b.is_in_group("PlayerCharacter"):
				_player_nearby = false
	)

	var body_col: = CollisionShape3D.new()
	var body_shape: = SphereShape3D.new()
	body_shape.radius = 0.15
	body_col.shape = body_shape
	add_child(body_col)

	var mesh: = MeshInstance3D.new()
	var sphere: = SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	mesh.mesh = sphere
	var mat: = StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.05, 0.05)
	mesh.material_override = mat
	add_child(mesh)

	var label: = Label3D.new()
	label.text = "E — Plukk opp gummi"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.005
	label.font_size = 28
	label.position = Vector3(0, 0.5, 0)
	add_child(label)


func _unhandled_input(event: InputEvent) -> void :
	if not _player_nearby:
		return
	if not event.is_action_pressed("interaction"):
		return
	GameManager.add_item("gummi", 1)
	if GameManager.gorgon_stolen_item == "gummi":
		GameManager.gorgon_stolen_item = ""
	var qs: Node = GameManager._get_quest_system_node()
	if qs and qs.has_method("on_item_collected"):
		qs.call("on_item_collected", "gummi", 1)
	queue_free()
