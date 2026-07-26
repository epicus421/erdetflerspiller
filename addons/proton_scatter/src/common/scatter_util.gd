extends Node










static func ensure_output_root_exists(s: ProtonScatter) -> void :

	if not s.output_root:
		s.output_root = s.get_node_or_null("ScatterOutput")


	if is_instance_valid(s.output_root) and s.has_node(NodePath(s.output_root.name)):
		enforce_output_root_owner(s)
		return


	if s.output_root:
		if s.has_node(NodePath(s.output_root.name)):
			s.remove_node(s.output_root.name)
		s.output_root.queue_free()
		s.output_root = null

	s.output_root = Marker3D.new()
	s.output_root.name = "ScatterOutput"
	s.add_child(s.output_root, true)

	enforce_output_root_owner(s)


static func enforce_output_root_owner(s: ProtonScatter) -> void :
	if is_instance_valid(s.output_root) and s.is_inside_tree():
		if s.show_output_in_tree:
			set_owner_recursive(s.output_root, s.get_tree().get_edited_scene_root())
		else:
			set_owner_recursive(s.output_root, null)



		s.output_root.update_configuration_warnings()





static func get_or_create_item_root(item: ProtonScatterItem) -> Node3D:
	var s: ProtonScatter = item.get_parent()
	ensure_output_root_exists(s)
	var item_root: Node3D = s.output_root.get_node_or_null(NodePath(item.name))

	if not item_root:
		item_root = Node3D.new()
		item_root.name = item.name
		s.output_root.add_child(item_root, true)

		if Engine.is_editor_hint():
			item_root.owner = item.get_tree().get_edited_scene_root()

	return item_root


static func get_or_create_multimesh(item: ProtonScatterItem, count: int) -> MultiMeshInstance3D:
	var item_root: = get_or_create_item_root(item)
	var mmi: MultiMeshInstance3D = item_root.get_node_or_null("MultiMeshInstance3D")

	if not mmi:
		mmi = MultiMeshInstance3D.new()
		mmi.set_name("MultiMeshInstance3D")
		item_root.add_child(mmi, true)

		mmi.set_owner(item_root.owner)
	if not mmi.multimesh:
		mmi.multimesh = MultiMesh.new()
		if item.custom_script:
			mmi.multimesh.use_colors = true
			mmi.multimesh.use_custom_data = true
			mmi.set_script(item.custom_script)
	elif not item.custom_script:

		mmi.multimesh.instance_count = 0
		mmi.multimesh.use_colors = false
		mmi.multimesh.use_custom_data = false

	var mesh_instance: MeshInstance3D = get_merged_meshes_from(item)
	if not mesh_instance:
		return

	mmi.position = Vector3.ZERO
	mmi.material_override = get_final_material(item, mesh_instance)
	mmi.set_cast_shadows_setting(item.override_cast_shadow)

	mmi.multimesh.instance_count = 0
	mmi.multimesh.mesh = mesh_instance.mesh
	mmi.multimesh.transform_format = MultiMesh.TRANSFORM_3D

	mmi.visibility_range_begin = item.visibility_range_begin
	mmi.visibility_range_begin_margin = item.visibility_range_begin_margin
	mmi.visibility_range_end = item.visibility_range_end
	mmi.visibility_range_end_margin = item.visibility_range_end_margin
	mmi.visibility_range_fade_mode = item.visibility_range_fade_mode
	mmi.layers = item.visibility_layers

	mmi.multimesh.instance_count = count
	copy_instance_shader_parameters(mesh_instance, mmi)

	mesh_instance.queue_free()

	return mmi


static func get_or_create_multimesh_chunk(item: ProtonScatterItem, 
				mesh_instance: MeshInstance3D, 
				index: Vector3i, 
				count: int)\
				-> MultiMeshInstance3D:
	var item_root: = get_or_create_item_root(item)
	var chunk_name = "MultiMeshInstance3D" + "_%s_%s_%s" % [index.x, index.y, index.z]
	var mmi: MultiMeshInstance3D = item_root.get_node_or_null(chunk_name)
	if not mesh_instance:
		return

	if not mmi:
		mmi = MultiMeshInstance3D.new()
		mmi.set_name(chunk_name)



		item_root.add_child.bind(mmi, true).call_deferred()

	if not mmi.multimesh:
		mmi.multimesh = MultiMesh.new()
		if item.custom_script:
			mmi.multimesh.use_colors = true
			mmi.multimesh.use_custom_data = true
			mmi.set_script(item.custom_script)
	elif not item.custom_script:

		mmi.multimesh.instance_count = 0
		mmi.multimesh.use_colors = false
		mmi.multimesh.use_custom_data = false

	mmi.position = Vector3.ZERO
	mmi.material_override = get_final_material(item, mesh_instance)
	mmi.set_cast_shadows_setting(item.override_cast_shadow)

	mmi.multimesh.instance_count = 0
	mmi.multimesh.mesh = mesh_instance.mesh
	mmi.multimesh.transform_format = MultiMesh.TRANSFORM_3D

	mmi.visibility_range_begin = item.visibility_range_begin
	mmi.visibility_range_begin_margin = item.visibility_range_begin_margin
	mmi.visibility_range_end = item.visibility_range_end
	mmi.visibility_range_end_margin = item.visibility_range_end_margin
	mmi.visibility_range_fade_mode = item.visibility_range_fade_mode
	mmi.layers = item.visibility_layers

	mmi.multimesh.instance_count = count
	copy_instance_shader_parameters(mesh_instance, mmi)

	return mmi


static func get_or_create_particles(item: ProtonScatterItem) -> GPUParticles3D:
	var item_root: = get_or_create_item_root(item)
	var particles: GPUParticles3D = item_root.get_node_or_null("GPUParticles3D")

	if not particles:
		particles = GPUParticles3D.new()
		particles.set_name("GPUParticles3D")
		item_root.add_child(particles)

		particles.set_owner(item_root.owner)

	var mesh_instance: MeshInstance3D = get_merged_meshes_from(item)
	if not mesh_instance:
		return

	particles.material_override = get_final_material(item, mesh_instance)
	particles.set_draw_pass_mesh(0, mesh_instance.mesh)
	particles.position = Vector3.ZERO
	particles.local_coords = true
	particles.layers = item.visibility_layers


	var process_material: Material = item.override_process_material


	if not process_material:
		process_material = ShaderMaterial.new()
		process_material.shader = preload("../particles/static.gdshader")

	if process_material is ShaderMaterial:
		process_material.set_shader_parameter("global_transform", item_root.get_global_transform())

	particles.set_process_material(process_material)






	particles.lifetime = 1.79769e+308


	particles.restart()

	return particles









static func request_parent_to_rebuild(node: Node, deferred: = true) -> void :
	var parent = node.get_parent()
	if not parent or not parent.is_inside_tree():
		return

	if parent and parent is ProtonScatter:
		if not parent.is_ready:
			return
		if not parent.enable_updates_in_game and not Engine.is_editor_hint():
			return

		if deferred:
			parent.rebuild.call_deferred(true)
		else:
			parent.rebuild(true)







static func get_all_mesh_instances_from(node: Node) -> Array[MeshInstance3D]:
	var res: Array[MeshInstance3D] = []

	if node is MeshInstance3D:
		res.push_back(node)

	for c in node.get_children():
		res.append_array(get_all_mesh_instances_from(c))

	return res


static func get_final_material(item: ProtonScatterItem, mi: MeshInstance3D) -> Material:
	if item.override_material:
		return item.override_material

	if mi.material_override:
		return mi.material_override

	if mi.get_surface_override_material(0):
		return mi.get_surface_override_material(0)

	return null















static func get_merged_meshes_from(item: ProtonScatterItem) -> MeshInstance3D:
	if not item:
		return null

	var source: Node = item.get_item()
	if not is_instance_valid(source):
		return null

	source.transform = Transform3D()


	var mesh_instances: Array[MeshInstance3D] = get_all_mesh_instances_from(source)
	source.queue_free()

	if mesh_instances.is_empty():
		return null


	if mesh_instances.size() == 1:

		var mi: MeshInstance3D = mesh_instances[0].duplicate()
		copy_instance_shader_parameters(mesh_instances[0], mi)


		if mi.material_override:
			return mi

		var surface_overrides_count: = 0
		for i in mi.get_surface_override_material_count():
			if mi.get_surface_override_material(i):
				surface_overrides_count += 1


		if surface_overrides_count <= 1:
			return mi


	var get_material_for_surface = func(mi: MeshInstance3D, idx: int) -> Material:
		if mi.get_material_override():
			return mi.get_material_override()

		if mi.get_surface_override_material(idx):
			return mi.get_surface_override_material(idx)

		if mi.mesh is PrimitiveMesh:
			return mi.mesh.get_material()

		return mi.mesh.surface_get_material(idx)


	var total_surfaces: = 0
	var surfaces_map: = {}





	for mi in mesh_instances:
		if not mi.mesh:
			continue


		var surface_count = mi.mesh.get_surface_count()
		total_surfaces += surface_count


		for surface_index in surface_count:
			var material: Material = get_material_for_surface.call(mi, surface_index)
			if not material in surfaces_map:
				surfaces_map[material] = []

			surfaces_map[material].push_back({
				"surface": surface_index, 
				"mesh_instance": mi, 
			})




	if total_surfaces <= 8:
		var mesh: = ImporterMesh.new()

		for mi in mesh_instances:
			var inverse_transform: = mi.transform.affine_inverse()

			for surface_index in mi.mesh.get_surface_count():

				var primitive_type = Mesh.PRIMITIVE_TRIANGLES
				var format = 0
				var arrays: = mi.mesh.surface_get_arrays(surface_index)
				if mi.mesh is ArrayMesh:
					primitive_type = mi.mesh.surface_get_primitive_type(surface_index)
					format = mi.mesh.surface_get_format(surface_index)


				var vertex_count = arrays[ArrayMesh.ARRAY_VERTEX].size()
				var vertex: Vector3
				for index in vertex_count:
					vertex = arrays[ArrayMesh.ARRAY_VERTEX][index] * inverse_transform
					arrays[ArrayMesh.ARRAY_VERTEX][index] = vertex


				var material: Material = get_material_for_surface.call(mi, surface_index)


				mesh.add_surface(primitive_type, arrays, [], {}, material, "", format)

		if item.lod_generate:
			mesh.generate_lods(item.lod_merge_angle, item.lod_split_angle, [])

		var instance: = MeshInstance3D.new()
		instance.mesh = mesh.get_mesh()
		return instance




	var total_unique_materials: = surfaces_map.size()

	if total_unique_materials > 8:
		var surface_tool: = SurfaceTool.new()
		surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

		for mi in mesh_instances:
			var mesh: Mesh = mi.mesh
			for surface_i in mesh.get_surface_count():
				surface_tool.append_from(mesh, surface_i, mi.transform)

		var mesh: = ImporterMesh.new()
		mesh.add_surface(surface_tool.get_primitive_type(), surface_tool.commit_to_arrays())

		if item.lod_generate:
			mesh.generate_lods(item.lod_merge_angle, item.lod_split_angle, [])

		var instance = MeshInstance3D.new()
		instance.mesh = mesh.get_mesh()
		return instance




	var mesh: = ImporterMesh.new()

	for material in surfaces_map.keys():
		var surface_tool: = SurfaceTool.new()
		surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

		var surfaces: Array = surfaces_map[material]
		for data in surfaces:
			var idx: int = data["surface"]
			var mi: MeshInstance3D = data["mesh_instance"]

			surface_tool.append_from(mi.mesh, idx, mi.transform)

		mesh.add_surface(
			surface_tool.get_primitive_type(), 
			surface_tool.commit_to_arrays(), 
			[], {}, 
			material)

	if item.lod_generate:
		mesh.generate_lods(item.lod_merge_angle, item.lod_split_angle, [])

	var instance: = MeshInstance3D.new()
	instance.mesh = mesh.get_mesh()
	return instance


static func get_all_static_bodies_from(node: Node) -> Array[StaticBody3D]:
	var res: Array[StaticBody3D] = []

	if node is StaticBody3D:
		res.push_back(node)

	for c in node.get_children():
		res.append_array(get_all_static_bodies_from(c))

	return res




static func get_collision_data(item: ProtonScatterItem) -> StaticBody3D:
	var static_body: = StaticBody3D.new()
	var source: Node3D = item.get_item()
	if not is_instance_valid(source):
		return static_body

	source.transform = Transform3D()

	for body in get_all_static_bodies_from(source):
		for child in body.get_children():
			if child is CollisionShape3D:

				body.remove_child(child)
				child.owner = null
				static_body.add_child(child)

	source.queue_free()
	return static_body


static func set_owner_recursive(node: Node, new_owner) -> void :
	node.set_owner(new_owner)

	if not node.get_scene_file_path().is_empty():
		return

	for c in node.get_children():
		set_owner_recursive(c, new_owner)


static func get_aabb_from_transforms(transforms: Array) -> AABB:
	if transforms.size() < 1:
		return AABB(Vector3.ZERO, Vector3.ZERO)
	var aabb = AABB(transforms[0].origin, Vector3.ZERO)
	for t in transforms:
		aabb = aabb.expand(t.origin)
	return aabb


static func set_visibility_layers(node: Node, layers: int) -> void :
	if node is VisualInstance3D:
		node.layers = layers
	for child in node.get_children():
		set_visibility_layers(child, layers)




static func copy_instance_shader_parameters(source: GeometryInstance3D, target: GeometryInstance3D) -> void :
	const SHADER_PARAMETER_PREFIX: = &"instance_shader_parameters/"
	for property: Dictionary in source.get_property_list():
		var p_name: String = property["name"]
		if not p_name.begins_with(SHADER_PARAMETER_PREFIX):
			continue
		var uniform_name: String = p_name.trim_prefix(SHADER_PARAMETER_PREFIX)
		if uniform_name.is_empty():
			continue
		var value: Variant = source.get_instance_shader_parameter(uniform_name)
		if value == null:
			continue
		target.set_instance_shader_parameter(uniform_name, value)
