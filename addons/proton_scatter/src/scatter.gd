@tool
@icon("../icons/scatter.svg")
class_name ProtonScatter
extends Node3D


signal build_completed



const ProtonScatterDomain: = preload("./common/domain.gd")
const ProtonScatterPhysicsHelper: = preload("./common/physics_helper.gd")
const ProtonScatterTransformList: = preload("./common/transform_list.gd")
const ProtonScatterUtil: = preload("./common/scatter_util.gd")

@export_group("General")



@export var enabled: = true:
	set(val):
		enabled = val
		if is_ready:
			rebuild()



@export var global_seed: = 0:
	set(val):
		global_seed = val
		rebuild()



@export var show_output_in_tree: = false:
	set(val):
		show_output_in_tree = val
		if output_root:
			ProtonScatterUtil.enforce_output_root_owner(self)

@export_group("Performance")






@export_enum("Use Instancing:0", 
			"Create Copies:1", 
			"Use Particles:2")\
			var render_mode: = 0:
	set(val):
		render_mode = val
		if is_ready:
			notify_property_list_changed()
			full_rebuild.call_deferred()

var use_chunks: bool = true:
	set(val):
		use_chunks = val
		if is_ready:
			notify_property_list_changed()
			full_rebuild.call_deferred()

var chunk_dimensions: = Vector3.ONE * 15.0:
	set(val):
		chunk_dimensions.x = max(val.x, 1.0)
		chunk_dimensions.y = max(val.y, 1.0)
		chunk_dimensions.z = max(val.z, 1.0)
		if is_ready:
			notify_property_list_changed()
			rebuild.call_deferred()



@export var keep_static_colliders: = false




@export var force_rebuild_on_load: = true




@export var enable_updates_in_game: = false

@export_group("Compatibility")

@export var force_uniform_scale: bool = false:
	set(val):
		force_uniform_scale = val
		if is_ready:
			rebuild.call_deferred()

@export_group("Dependency")



@export var scatter_parent: NodePath:
	set(val):
		if not is_inside_tree():
			scatter_parent = val
			return

		scatter_parent = NodePath()
		if is_instance_valid(_dependency_parent):
			_dependency_parent.build_completed.disconnect(rebuild)
			_dependency_parent = null

		var node = get_node_or_null(val)
		if not node:
			return

		var type = node.get_script()
		var scatter_type = get_script()
		if type != scatter_type:
			push_warning("ProtonScatter warning: Please select a ProtonScatter node as a parent dependency.")
			return



		scatter_parent = val
		_dependency_parent = node
		_dependency_parent.build_completed.connect(rebuild, CONNECT_DEFERRED)


@export_group("Debug", "dbg_")




@export var dbg_disable_thread: = false

var undo_redo
var modifier_stack: ProtonScatterModifierStack:
	set(val):
		if modifier_stack:
			if modifier_stack.value_changed.is_connected(rebuild):
				modifier_stack.value_changed.disconnect(rebuild)
			if modifier_stack.stack_changed.is_connected(rebuild):
				modifier_stack.stack_changed.disconnect(rebuild)
			if modifier_stack.transforms_ready.is_connected(_on_transforms_ready):
				modifier_stack.transforms_ready.disconnect(_on_transforms_ready)
		if not val:
			modifier_stack = null
			return

		if val.parent and val.parent != self:
			modifier_stack = val.get_copy()
		else:
			modifier_stack = val
		modifier_stack.parent = self
		modifier_stack.value_changed.connect(rebuild, CONNECT_DEFERRED)
		modifier_stack.stack_changed.connect(rebuild, CONNECT_DEFERRED)
		modifier_stack.transforms_ready.connect(_on_transforms_ready, CONNECT_DEFERRED)

var domain: ProtonScatterDomain:
	set(_val):
		domain = ProtonScatterDomain.new()

var items: Array = []
var total_item_proportion: int
var output_root: Marker3D
var transforms: ProtonScatterTransformList
var editor_plugin
var is_ready: = false
var build_version: = 0


var _thread: Thread
var _rebuild_queued: = false
var _dependency_parent
var _physics_helper: ProtonScatterPhysicsHelper
var _body_rid: RID
var _collision_shapes: Array[RID]
var _ignore_transform_notification = false
var _is_using_jolt: bool = false


func _ready() -> void :
	if Engine.is_editor_hint() or enable_updates_in_game:
		set_notify_transform(true)
		child_exiting_tree.connect(_on_child_exiting_tree)

	_is_using_jolt = ProjectSettings.get_setting("physics/3d/physics_engine") == "Jolt Physics"
	_perform_sanity_check()
	_discover_items()
	update_configuration_warnings.call_deferred()
	is_ready = true

	if force_rebuild_on_load and not is_instance_valid(_dependency_parent):
		full_rebuild.call_deferred()


func _exit_tree():
	if is_thread_running():
		modifier_stack.stop_update()
		_thread.wait_to_finish()
		_thread = null

	_clear_collision_data()


func _get_property_list() -> Array:
	var list: = []
	list.push_back({
		name = "modifier_stack", 
		type = TYPE_OBJECT, 
		hint_string = "ScatterModifierStack", 
	})

	var chunk_usage: = PROPERTY_USAGE_NO_EDITOR
	var dimensions_usage: = PROPERTY_USAGE_NO_EDITOR
	if render_mode == 0 or render_mode == 2:
		chunk_usage = PROPERTY_USAGE_DEFAULT
		if use_chunks:
			dimensions_usage = PROPERTY_USAGE_DEFAULT

	list.push_back({
		name = "Performance/use_chunks", 
		type = TYPE_BOOL, 
		usage = chunk_usage
	})

	list.push_back({
		name = "Performance/chunk_dimensions", 
		type = TYPE_VECTOR3, 
		usage = dimensions_usage
	})
	return list


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: = PackedStringArray()

	if items.is_empty():
		warnings.push_back("At least one ScatterItem node is required.")

	if modifier_stack and not modifier_stack.does_not_require_shapes():
		if domain and domain.is_empty():
			warnings.push_back("At least one ScatterShape node is required.")

	return warnings


func _notification(what):
	if not is_ready:
		return
	match what:
		NOTIFICATION_TRANSFORM_CHANGED:
			if _ignore_transform_notification:
				_ignore_transform_notification = false
				return
			_perform_sanity_check()
			domain.compute_bounds()
			rebuild.call_deferred()
		NOTIFICATION_ENTER_WORLD:
			_ignore_transform_notification = true


func _set(property, value):


	if property == "Performance/use_chunks":
		use_chunks = value

	elif property == "Performance/chunk_dimensions":
		chunk_dimensions = value

	if not Engine.is_editor_hint():
		return false


	if property == "transform":
		_on_node_duplicated.call_deferred()



	elif property == "use_instancing":
		render_mode = 0 if value else 1
		return true

	return false


func _get(property):
	if property == "Performance/use_chunks":
		return use_chunks

	elif property == "Performance/chunk_dimensions":
		return chunk_dimensions


func is_thread_running() -> bool:
	return _thread != null and _thread.is_started()



func get_physics_helper() -> ProtonScatterPhysicsHelper:
	return _physics_helper



func clear_output() -> void :
	if not output_root:
		output_root = get_node_or_null("ScatterOutput")

	if output_root:
		remove_child(output_root)
		output_root.queue_free()
		output_root = null

	ProtonScatterUtil.ensure_output_root_exists(self)
	_clear_collision_data()


func _clear_collision_data() -> void :
	if _body_rid.is_valid():
		PhysicsServer3D.free_rid(_body_rid)
		_body_rid = RID()

	for rid in _collision_shapes:
		if rid.is_valid():
			PhysicsServer3D.free_rid(rid)

	_collision_shapes.clear()




func full_rebuild():
	update_gizmos()

	if not is_inside_tree():
		return

	_rebuild_queued = false

	if is_thread_running():
		await _thread.wait_to_finish()
		_thread = null

	clear_output()
	_rebuild(true)






func rebuild(force_discover: = false) -> void :
	update_gizmos()

	if not is_inside_tree() or not is_ready:
		return

	if is_thread_running():
		_rebuild_queued = true
		return

	force_discover = true
	_rebuild(force_discover)






func _rebuild(force_discover) -> void :
	if not enabled:
		_clear_collision_data()
		clear_output()
		build_completed.emit()
		return

	_perform_sanity_check()

	if force_discover:
		_discover_items()
		domain.discover_shapes(self)

	if items.is_empty() or (domain.is_empty() and not modifier_stack.does_not_require_shapes()):
		clear_output()
		push_warning("ProtonScatter warning: No items or shapes, abort")
		return

	if render_mode == 1:
		clear_output()

	if keep_static_colliders:
		_clear_collision_data()

	if dbg_disable_thread:
		modifier_stack.start_update(self, domain)
		return

	if is_thread_running():
		await _thread.wait_to_finish()

	_thread = Thread.new()
	_thread.start(_rebuild_threaded, Thread.PRIORITY_NORMAL)


func _rebuild_threaded() -> void :

	if _thread.has_method("set_thread_safety_checks_enabled"):

		@warning_ignore("static_called_on_instance")
		_thread.set_thread_safety_checks_enabled(false)

	modifier_stack.start_update(self, domain.get_copy())


func _discover_items() -> void :
	items.clear()
	total_item_proportion = 0

	for c in get_children():
		if is_instance_of(c, ProtonScatterItem):
			items.push_back(c)
			total_item_proportion += c.proportion

	update_configuration_warnings()



func _update_multimeshes() -> void :
	if items.is_empty():
		_discover_items()

	var offset: = 0
	var transforms_count: int = transforms.size()

	for item in items:
		var count = int(round(float(item.proportion) / total_item_proportion * transforms_count))
		var mmi = ProtonScatterUtil.get_or_create_multimesh(item, count)
		if not mmi:
			continue
		var static_body: = ProtonScatterUtil.get_collision_data(item)

		var t: Transform3D
		for i in count:

			if (offset + i) >= transforms_count:
				mmi.multimesh.instance_count = i - 1
				continue

			t = item.process_transform(transforms.list[offset + i])
			mmi.multimesh.set_instance_transform(i, t)
			_create_collision(static_body, t)

		static_body.queue_free()
		offset += count


func _update_split_multimeshes() -> void :
	var size = domain.bounds_local.size

	var splits: = Vector3i.ONE
	splits.x = max(1, ceil(size.x / chunk_dimensions.x))
	splits.y = max(1, ceil(size.y / chunk_dimensions.y))
	splits.z = max(1, ceil(size.z / chunk_dimensions.z))

	if items.is_empty():
		_discover_items()

	var offset: = 0
	var transforms_count: int = transforms.size()
	clear_output()

	for item in items:
		var root: Node3D = ProtonScatterUtil.get_or_create_item_root(item)
		if not is_instance_valid(root):
			continue


		var count = int(round(float(item.proportion) / total_item_proportion * transforms_count))


		var transform_chunks: Array = []
		for xi in splits.x:
			transform_chunks.append([])
			for yi in splits.y:
				transform_chunks[xi].append([])
				for zi in splits.z:
					transform_chunks[xi][yi].append([])

		var t_list = transforms.list.slice(offset)
		var aabb = ProtonScatterUtil.get_aabb_from_transforms(t_list)
		aabb = aabb.grow(0.1)
		var static_body: = ProtonScatterUtil.get_collision_data(item)

		for i in count:
			if (offset + i) >= transforms_count:
				continue

			var t = item.process_transform(transforms.list[offset + i])
			var p_rel = (t.origin - aabb.position) / aabb.size

			var ci = (p_rel * Vector3(splits)).floor()

			transform_chunks[ci.x][ci.y][ci.z].append(t)
			_create_collision(static_body, t)

		static_body.queue_free()


		var mesh_instance: MeshInstance3D = ProtonScatterUtil.get_merged_meshes_from(item)

		for xi in splits.x:
			for yi in splits.y:
				for zi in splits.z:
					var chunk_elements = transform_chunks[xi][yi][zi].size()
					if chunk_elements == 0:
						continue
					var mmi = ProtonScatterUtil.get_or_create_multimesh_chunk(
						item, 
						mesh_instance, 
						Vector3i(xi, yi, zi), 
						chunk_elements)
					if not mmi:
						continue




					var center = ProtonScatterUtil.get_aabb_from_transforms(transform_chunks[xi][yi][zi]).get_center()
					mmi.transform.origin = center

					var t: Transform3D
					for i in chunk_elements:
						t = transform_chunks[xi][yi][zi][i]
						t.origin -= center
						mmi.multimesh.set_instance_transform(i, t)
		mesh_instance.queue_free()
		offset += count


func _update_duplicates() -> void :
	var offset: = 0
	var transforms_count: int = transforms.size()

	for item in items:
		var count: = int(round(float(item.proportion) / total_item_proportion * transforms_count))
		var root: Node3D = ProtonScatterUtil.get_or_create_item_root(item)
		var child_count: = root.get_child_count()

		for i in count:
			if (offset + i) >= transforms_count:
				return

			var instance
			if i < child_count:
				instance = root.get_child(i)
			else:
				instance = _create_instance(item, root)

			if not instance:
				break

			var t: Transform3D = item.process_transform(transforms.list[offset + i])
			instance.transform = t
			ProtonScatterUtil.set_visibility_layers(instance, item.visibility_layers)


		if count < child_count:
			for i in (child_count - count):
				root.get_child(-1).queue_free()

		offset += count


func _update_particles_system() -> void :
	var offset: = 0
	var transforms_count: int = transforms.size()

	for item in items:
		var count: = int(round(float(item.proportion) / total_item_proportion * transforms_count))
		var particles = ProtonScatterUtil.get_or_create_particles(item)
		if not particles:
			continue

		particles.visibility_aabb = AABB(domain.bounds_local.min, domain.bounds_local.size)
		particles.amount = count

		var static_body: = ProtonScatterUtil.get_collision_data(item)
		var t: Transform3D

		for i in count:
			if (offset + i) >= transforms_count:
				particles.amount = i - 1
				return

			t = item.process_transform(transforms.list[offset + i])
			particles.emit_particle(
				t, 
				Vector3.ZERO, 
				Color.WHITE, 
				Color.BLACK, 
				GPUParticles3D.EMIT_FLAG_POSITION | GPUParticles3D.EMIT_FLAG_ROTATION_SCALE)
			_create_collision(static_body, t)

		offset += count





func _create_collision(body: StaticBody3D, t: Transform3D) -> void :
	if not keep_static_colliders or render_mode == 1:
		return


	if not _body_rid.is_valid():
		_body_rid = PhysicsServer3D.body_create()
		PhysicsServer3D.body_set_mode(_body_rid, PhysicsServer3D.BODY_MODE_STATIC)
		PhysicsServer3D.body_set_state(_body_rid, PhysicsServer3D.BODY_STATE_TRANSFORM, global_transform)
		PhysicsServer3D.body_set_space(_body_rid, get_world_3d().space)

	for c in body.get_children():
		if c is CollisionShape3D:
			var shape_rid: RID
			var data: Variant

			if c.shape is SphereShape3D:
				shape_rid = PhysicsServer3D.sphere_shape_create()
				data = c.shape.radius

			elif c.shape is BoxShape3D:
				shape_rid = PhysicsServer3D.box_shape_create()
				data = c.shape.size / 2.0

			elif c.shape is CapsuleShape3D:
				shape_rid = PhysicsServer3D.capsule_shape_create()
				data = {
					"radius": c.shape.radius, 
					"height": c.shape.height, 
				}

			elif c.shape is CylinderShape3D:
				shape_rid = PhysicsServer3D.cylinder_shape_create()
				data = {
					"radius": c.shape.radius, 
					"height": c.shape.height, 
				}

			elif c.shape is ConcavePolygonShape3D:
				shape_rid = PhysicsServer3D.concave_polygon_shape_create()
				data = {
					"faces": c.shape.get_faces(), 
					"backface_collision": c.shape.backface_collision, 
				}

			elif c.shape is ConvexPolygonShape3D:
				shape_rid = PhysicsServer3D.convex_polygon_shape_create()
				data = c.shape.points

			elif c.shape is HeightMapShape3D:
				shape_rid = PhysicsServer3D.heightmap_shape_create()
				var min_height: = 9999999.0
				var max_height: = -9999999.0
				for v in c.shape.map_data:
					min_height = v if v < min_height else min_height
					max_height = v if v > max_height else max_height
				data = {
					"width": c.shape.map_width, 
					"depth": c.shape.map_depth, 
					"heights": c.shape.map_data, 
					"min_height": min_height, 
					"max_height": max_height, 
				}

			elif c.shape is SeparationRayShape3D:
				shape_rid = PhysicsServer3D.separation_ray_shape_create()
				data = {
					"length": c.shape.length, 
					"slide_on_slope": c.shape.slide_on_slope, 
				}

			else:
				print_debug("Scatter - Unsupported collision shape: ", c.shape)
				continue

			PhysicsServer3D.shape_set_data(shape_rid, data)
			PhysicsServer3D.body_add_shape(_body_rid, shape_rid, t * c.transform)
			_collision_shapes.push_back(shape_rid)


func _create_instance(item: ProtonScatterItem, root: Node3D):
	if not item:
		return null

	var instance = item.get_item()
	if not instance:
		return null

	instance.visible = true
	root.add_child.bind(instance, true).call_deferred()

	if show_output_in_tree:



		var defer_ownership: = func(i, o):
			ProtonScatterUtil.set_owner_recursive(i, o)
		defer_ownership.bind(instance, get_tree().get_edited_scene_root()).call_deferred()

	return instance



func _perform_sanity_check() -> void :
	if not modifier_stack:
		modifier_stack = ProtonScatterModifierStack.new()
		modifier_stack.just_created = true

	if not domain:
		domain = ProtonScatterDomain.new()

	domain.discover_shapes(self)

	if not is_instance_valid(_physics_helper):
		_physics_helper = ProtonScatterPhysicsHelper.new()
		_physics_helper.name = "PhysicsHelper"
		add_child(_physics_helper, true, INTERNAL_MODE_BACK)


	scatter_parent = scatter_parent




func _on_node_duplicated() -> void :
	clear_output()


func _on_child_exiting_tree(node: Node) -> void :
	if node is ProtonScatterShape or node is ProtonScatterItem:
		rebuild.bind(true).call_deferred()



func _on_transforms_ready(new_transforms: ProtonScatterTransformList) -> void :
	if is_thread_running():
		await _thread.wait_to_finish()
		_thread = null

	_clear_collision_data()

	if _rebuild_queued:
		_rebuild_queued = false
		rebuild.call_deferred()
		return

	transforms = new_transforms

	if force_uniform_scale or _is_using_jolt:
		transforms.enforce_uniform_scale()

	if not transforms or transforms.is_empty():
		clear_output()
		update_gizmos()
		return

	match render_mode:
		0:
			if use_chunks:
				_update_split_multimeshes()
			else:
				_update_multimeshes()
		1:
			_update_duplicates()
		2:
			_update_particles_system()

	update_gizmos()
	build_version += 1

	if is_inside_tree():
		await get_tree().process_frame

	build_completed.emit()
