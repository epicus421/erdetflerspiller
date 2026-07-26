extends Node3D

@export var cable_color: Color = Color(0.08, 0.08, 0.08)
@export var cable_radius: float = 0.035
@export var cable_points: int = 20
@export var cable_sag: float = 1.5

var _anchor_world_pos: Vector3 = Vector3.ZERO
var _stoepsel: Node3D = null
var _mesh: ImmediateMesh = null
var _mesh_instance: MeshInstance3D = null


func _ready() -> void :
	_mesh = ImmediateMesh.new()
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = _mesh
	var mat: = StandardMaterial3D.new()
	mat.albedo_color = cable_color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh_instance.material_override = mat
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh_instance)
	add_to_group("VisualCable")
	add_to_group("Path3DRope")
	_anchor_world_pos = global_position
	var stoepsel: Node = get_tree().get_first_node_in_group("StoepselProp")
	if stoepsel is Node3D:
		_stoepsel = stoepsel as Node3D


func _process(_delta: float) -> void :
	if _stoepsel == null or not is_instance_valid(_stoepsel):
		var s: Node = get_tree().get_first_node_in_group("StoepselProp")
		if s is Node3D:
			_stoepsel = s as Node3D
		else:
			return
	_draw_cable(_anchor_world_pos, _stoepsel.global_position)


func _draw_cable(from: Vector3, to: Vector3) -> void :
	_mesh.clear_surfaces()
	var points: Array[Vector3] = _catenary(from, to)
	if points.size() < 2:
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in range(points.size()):
		var p: Vector3 = points[i]
		var forward: Vector3
		if i < points.size() - 1:
			forward = (points[i + 1] - p).normalized()
		else:
			forward = (p - points[i - 1]).normalized()
		var to_cam: Vector3 = Vector3.UP
		if cam != null:
			to_cam = (cam.global_position - p).normalized()
		var right: Vector3 = forward.cross(to_cam).normalized() * cable_radius
		if right.length() < 0.001:
			right = Vector3(cable_radius, 0, 0)
		_mesh.surface_add_vertex(to_local(p + right))
		_mesh.surface_add_vertex(to_local(p - right))
	_mesh.surface_end()


func _catenary(from: Vector3, to: Vector3) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for i in range(cable_points + 1):
		var t: float = float(i) / float(cable_points)
		var pos: Vector3 = from.lerp(to, t)
		var sag: float = cable_sag * sin(t * PI)
		pos.y -= sag
		points.append(pos)
	return points
