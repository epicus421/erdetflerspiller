extends RigidBody3D









const PICKUP_RADIUS: = 2.4

var _picked_up: bool = false
var _label: Label3D = null
var _player: Node3D = null


func _ready() -> void :

	continuous_cd = true

	var body_col: = CollisionShape3D.new()
	var body_shape: = BoxShape3D.new()
	body_shape.size = Vector3(0.5, 0.12, 0.5)
	body_col.shape = body_shape
	add_child(body_col)

	var mesh: = MeshInstance3D.new()
	var box: = BoxMesh.new()
	box.size = Vector3(0.5, 0.5, 0.5)
	mesh.mesh = box
	var mat: = StandardMaterial3D.new()
	mat.albedo_color = Color(0.113, 0.147, 0.192, 1.0)
	mesh.material_override = mat
	add_child(mesh)

	_label = Label3D.new()
	_label.text = "E — Plukk opp plast"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.005
	_label.font_size = 28
	_label.no_depth_test = true


	_label.render_priority = 10
	_label.outline_render_priority = 9
	_label.position = Vector3(0, 0.6, 0)
	_label.visible = false
	add_child(_label)


func _physics_process(_delta: float) -> void :
	if _picked_up:
		return
	if _player == null or not is_instance_valid(_player):
		_player = GameManager.get_player()
	if _player == null:
		_label.visible = false
		return
	_label.visible = global_position.distance_to(_player.global_position) <= PICKUP_RADIUS


func _unhandled_input(event: InputEvent) -> void :
	if _picked_up or not _label.visible:
		return
	if not event.is_action_pressed("interaction"):
		return
	if DialogueUI and DialogueUI.is_open():
		return
	_picked_up = true
	GameManager.add_item("plast", 1)
	get_viewport().set_input_as_handled()
	queue_free()
