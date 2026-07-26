extends StaticBody3D

@onready var poster_sprite: Node3D = $Node3D / Poster
@onready var interaction_area: Area3D = $Node3D / PosterInteraction
@onready var interaction_label: Label3D = $Node3D / PosterInteraction / Label3D
@onready var omni_light: OmniLight3D = $OmniLight3D

var poster_taken: bool = false
var player_nearby: Node = null

func _ready() -> void :
	set_process_input(true)
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	$Node3D.rotation_degrees.y = randf_range(0, 360.0)


func _set_emission(value: float) -> void :
	_set_emission_on_node(self, value)
	var lamp: Node = get_node_or_null("StreetLampMesh")
	if lamp != null:
		_set_emission_on_mesh(lamp, value)
	if omni_light != null:
		omni_light.visible = value > 0.0


func _set_emission_on_node(node: Node, value: float) -> void :
	if node is CSGShape3D:
		var csg: CSGShape3D = node as CSGShape3D
		var mat: Material = csg.material
		if mat is StandardMaterial3D:
			(mat as StandardMaterial3D).emission_energy_multiplier = value
	for child in node.get_children():
		_set_emission_on_node(child, value)


func _set_emission_on_mesh(node: Node, value: float) -> void :
	if node is CSGShape3D:
		var csg: CSGShape3D = node as CSGShape3D
		var mat: Material = csg.material
		if mat is StandardMaterial3D:
			(mat as StandardMaterial3D).emission_energy_multiplier = value
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		for i in range(mi.get_surface_override_material_count()):
			var override_mat: Material = mi.get_surface_override_material(i)
			if override_mat is StandardMaterial3D:
				(override_mat as StandardMaterial3D).emission_energy_multiplier = value
		if mi.mesh != null:
			for i in range(mi.mesh.get_surface_count()):
				var mesh_mat: Material = mi.mesh.surface_get_material(i)
				if mesh_mat is StandardMaterial3D:
					(mesh_mat as StandardMaterial3D).emission_energy_multiplier = value
	for child in node.get_children():
		_set_emission_on_mesh(child, value)


func _on_body_entered(body: Node3D) -> void :
	if body.is_in_group("PlayerCharacter") and not poster_taken:
		player_nearby = body
		interaction_label.visible = true


func _on_body_exited(body: Node3D) -> void :
	if body.is_in_group("PlayerCharacter"):
		player_nearby = null
		interaction_label.visible = false


func _input(_event: InputEvent) -> void :
	if poster_taken:
		return
	if player_nearby == null:
		return
	if Input.is_action_just_pressed("interaction"):
		_take_poster()


func _take_poster() -> void :
	poster_taken = true
	interaction_label.visible = false
	interaction_area.monitoring = false
	if poster_sprite:
		poster_sprite.visible = false
	GameManager.add_item("gard_plakat", 1)
