extends Node

@export var sun: DirectionalLight3D
@export var world_env: WorldEnvironment







var time_of_day: float = 0.35


func _ready() -> void :
	add_to_group("LightingCycle")
	if sun == null:
		sun = get_tree().get_first_node_in_group("SunLight") as DirectionalLight3D
	if sun == null:
		sun = _find_node_by_class(get_tree().root, "DirectionalLight3D") as DirectionalLight3D
	if sun != null and not sun.is_in_group("DirectionalLight"):
		sun.add_to_group("DirectionalLight")
	if world_env == null:
		world_env = get_tree().get_first_node_in_group("WorldEnvironment") as WorldEnvironment
	if world_env == null:
		world_env = _find_node_by_class(get_tree().root, "WorldEnvironment") as WorldEnvironment
	if GameManager.has_signal("day_changed"):
		GameManager.day_changed.connect(_on_day_changed)
	_apply_lighting(time_of_day)
	if GameManager.has_method("apply_shadows"):
		GameManager.apply_shadows(GameManager.shadows_enabled)


var _light_frame: int = 0


const NIGHT_HINT_TIME: = 0.82


var _flashlight_hint_shown: bool = false



const DAY_TIME_SCALE: = 0.75
const NIGHT_TIME_SCALE: = 1.8

func _process(delta: float) -> void :
	var day_duration: = GameManager.day_duration_seconds
	if day_duration > 0.0:
		var is_day: = time_of_day >= 0.25 and time_of_day < 0.75
		var time_scale: = DAY_TIME_SCALE if is_day else NIGHT_TIME_SCALE
		time_of_day += delta * time_scale / day_duration
		if time_of_day >= 1.0:
			time_of_day -= 1.0

	var is_dark: = time_of_day >= NIGHT_HINT_TIME and time_of_day < 1.0
	if is_dark and not _flashlight_hint_shown and QuestNotifier != null:
		_flashlight_hint_shown = true
		QuestNotifier.show_hint("Det er blitt mørkt — trykk V for lommelykt")
	_light_frame += 1
	if _light_frame >= 4:
		_light_frame = 0
		_apply_lighting(time_of_day)


func _on_day_changed(_new_day: int) -> void :
	time_of_day = 0.25
	_apply_lighting(time_of_day)


func _apply_lighting(t: float) -> void :
	if sun == null or world_env == null:
		return


	var sun_angle: = (t - 0.25) * 360.0
	var sun_x: = -90.0 + cos(deg_to_rad(sun_angle)) * 70.0
	sun_x = clamp(sun_x, -180.0, 0.0)
	sun.rotation_degrees.x = sun_x
	sun.rotation_degrees.y = sin(deg_to_rad(sun_angle)) * 45.0








	var sun_color: Color
	var sun_energy: float
	var sky_top: Color
	var sky_horizon: Color
	var ambient_energy: float

	if t < 0.15:



		sun_color = Color(0.6, 0.7, 1.0)
		sun_energy = 0.15
		sky_top = Color(0.05, 0.07, 0.18)
		sky_horizon = Color(0.15, 0.18, 0.32)
		ambient_energy = 0.12
	elif t < 0.25:


		var p: = (t - 0.15) / 0.1
		sun_color = Color(0.6, 0.7, 1.0).lerp(Color(1.0, 0.92, 0.75), p)
		sun_energy = lerp(0.15, 0.8, p)
		sky_top = Color(0.05, 0.07, 0.18).lerp(Color(0.3, 0.45, 0.65), p)
		sky_horizon = Color(0.15, 0.18, 0.32).lerp(Color(0.6, 0.7, 0.8), p)
		ambient_energy = lerp(0.12, 0.35, p)
	elif t < 0.55:



		sun_color = Color(1.0, 0.97, 0.88)
		sun_energy = 1.3
		sky_top = Color(0.38, 0.52, 0.68)
		sky_horizon = Color(0.6, 0.72, 0.82)
		ambient_energy = 0.45
	elif t < 0.7:



		var p: = (t - 0.55) / 0.15
		sun_color = Color(1.0, 0.97, 0.88).lerp(Color(1.0, 0.93, 0.78), p)
		sun_energy = lerp(1.3, 1.1, p)
		sky_top = Color(0.38, 0.52, 0.68).lerp(Color(0.42, 0.55, 0.7), p)
		sky_horizon = Color(0.6, 0.72, 0.82)
		ambient_energy = lerp(0.45, 0.4, p)
	elif t < 0.83:



		var p: = (t - 0.7) / 0.13
		sun_color = Color(1.0, 0.93, 0.78).lerp(Color(1.0, 0.82, 0.5), p)
		sun_energy = lerp(1.1, 0.6, p)
		sky_top = Color(0.42, 0.55, 0.7).lerp(Color(0.25, 0.38, 0.58), p)
		sky_horizon = Color(0.6, 0.72, 0.82).lerp(Color(0.55, 0.62, 0.75), p)
		ambient_energy = lerp(0.4, 0.25, p)
	elif t < 0.92:



		var p: = (t - 0.83) / 0.09
		sun_color = Color(1.0, 0.82, 0.5).lerp(Color(0.7, 0.75, 1.0), p)
		sun_energy = lerp(0.6, 0.2, p)
		sky_top = Color(0.25, 0.38, 0.58).lerp(Color(0.08, 0.12, 0.28), p)
		sky_horizon = Color(0.55, 0.62, 0.75).lerp(Color(0.2, 0.25, 0.45), p)
		ambient_energy = lerp(0.25, 0.14, p)
	else:



		var p: = (t - 0.92) / 0.08
		sun_color = Color(0.7, 0.75, 1.0).lerp(Color(0.6, 0.7, 1.0), p)
		sun_energy = lerp(0.2, 0.15, p)
		sky_top = Color(0.08, 0.12, 0.28).lerp(Color(0.05, 0.07, 0.18), p)
		sky_horizon = Color(0.2, 0.25, 0.45).lerp(Color(0.15, 0.18, 0.32), p)
		ambient_energy = lerp(0.14, 0.12, p)


	sun.light_color = sun_color
	sun.light_energy = sun_energy


	var env: = world_env.environment
	if env:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = sky_horizon
		env.ambient_light_energy = ambient_energy





		env.fog_light_color = sky_horizon
		var sky_mat = env.sky.sky_material if env.sky else null
		if sky_mat is ProceduralSkyMaterial:
			sky_mat.sky_top_color = sky_top
			sky_mat.sky_horizon_color = sky_horizon
			sky_mat.ground_horizon_color = sky_horizon.darkened(0.2)
			sky_mat.ground_bottom_color = sky_top.darkened(0.4)


func _find_node_by_class(node: Node, class_name_str: String) -> Node:
	if node.get_class() == class_name_str:
		return node
	for child in node.get_children():
		var found: = _find_node_by_class(child, class_name_str)
		if found:
			return found
	return null
