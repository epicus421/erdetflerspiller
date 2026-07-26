extends CanvasLayer

var _active: bool = false
var _rect: ColorRect = null


func _ready() -> void :
	layer = 98
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_rect = ColorRect.new()
	_rect.name = "ColorRect"
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.color = Color.WHITE

	var mat: = ShaderMaterial.new()
	var shader: = Shader.new()
	shader.code = "\nshader_type canvas_item;\nuniform sampler2D screen_texture : hint_screen_texture;\nuniform float strength : hint_range(0.0, 1.0) = 1.0;\nvoid fragment() {\n\tvec4 color = texture(screen_texture, SCREEN_UV);\n\tfloat gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));\n\tCOLOR = vec4(mix(color.rgb, vec3(gray), strength), color.a);\n}\n"









	mat.shader = shader
	mat.set_shader_parameter("strength", 0.0)
	_rect.material = mat
	add_child(_rect)


func activate() -> void :
	if _active:
		return
	_active = true
	visible = true
	var mat: = _rect.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("strength", 0.0)
	var tween: = create_tween()
	tween.tween_method(
		func(v: float) -> void :
			mat.set_shader_parameter("strength", v), 
		0.0, 
		1.0, 
		3.0
	)
	var tree: = get_tree()
	if tree != null:
		for music_player in tree.get_nodes_in_group("MusicPlayer"):
			if music_player is AudioStreamPlayer:
				(music_player as AudioStreamPlayer).stop()
			elif music_player.has_method("stop"):
				music_player.stop()
