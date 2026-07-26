extends Node

var _frames: int = 0
var _viewport: SubViewport

func _ready() -> void :
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(800, 700)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.own_world_3d = true
	_viewport.transparent_bg = false
	add_child(_viewport)

	var env: = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.18, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.85)
	env.ambient_light_energy = 0.8
	var world_env: = WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)

	var sun: = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-65, 25, 0)
	sun.light_energy = 1.5
	sun.shadow_enabled = false
	_viewport.add_child(sun)

	var fill: = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-80, -120, 0)
	fill.light_energy = 0.5
	fill.shadow_enabled = false
	_viewport.add_child(fill)

	var cam: = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 280.0
	cam.position = Vector3(0, 200, 0)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	cam.near = 0.1
	cam.far = 400.0
	cam.current = true
	_viewport.add_child(cam)

	var scene: PackedScene = load("res://levels/main_demo.tscn")
	if scene == null:
		push_error("Failed to load main_demo.tscn")
		get_tree().quit(1)
		return
	var level: = scene.instantiate()
	_strip_non_geometry(level)
	_viewport.add_child(level)


func _process(_delta: float) -> void :
	_frames += 1
	if _frames < 30:
		return
	var image: = _viewport.get_texture().get_image()
	if image == null:
		push_error("Failed to capture viewport")
		get_tree().quit(1)
		return
	var err: = image.save_png("res://assets/textures/map_background.png")
	if err != OK:
		push_error("Failed to save image: %d" % err)
		get_tree().quit(1)
		return
	print("Map screenshot saved to assets/textures/map_background.png (%dx%d)" % [image.get_width(), image.get_height()])
	get_tree().quit()


func _strip_non_geometry(node: Node) -> void :
	var to_remove: Array[Node] = []
	for child in node.get_children():
		var n: = child.name.to_lower()
		if child is CanvasLayer or child is CanvasItem:
			to_remove.append(child)
		elif child is Camera3D:
			to_remove.append(child)
		elif child is WorldEnvironment:
			to_remove.append(child)
		elif child.name == "PlayerCharacter":
			to_remove.append(child)
		elif n.contains("skybox"):
			to_remove.append(child)
		elif child is AudioStreamPlayer or child is AudioStreamPlayer3D:
			to_remove.append(child)
		else:
			_strip_non_geometry(child)
	for child in to_remove:
		child.queue_free()
