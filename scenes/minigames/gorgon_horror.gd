extends Node3D

const JUMPSCARE_HOLD: = 0.75
const FADE_IN_TIME: = 2.0
const FADE_OUT_TIME: = 1.0

const MAZE_COLS: = 18
const MAZE_ROWS: = 15
const CELL_SIZE: = 3.0
const WALL_HEIGHT: = 3.5
const WALL_THICKNESS: = 0.3

const PATH_INTERVAL: = 0.7
const CATCH_DISTANCE: = 1.8
const FLICKER_INTERVAL: = 12.0



const GORGON_SPEED_START: = 6.5
const GORGON_SPEED_END: = 11.0
const LUNGE_DISTANCE: = 9.0
const LUNGE_MULTIPLIER: = 1.25
const WANDER_CHANCE: = 0.15



const ROAM_TIME_MIN: = 45.0
const ROAM_TIME_MAX: = 60.0
const ROAM_SPEED: = 3.5




enum Awareness{SEARCH, TRACK, CHASE}
const HEAR_RADIUS: = 5.0
const TRACK_TIME_MAX: = 6.0
const TRACK_SPEED: = 8.0
const SEARCH_SPEED: = 5.0
const SEARCH_BIAS_CELLS: = 5


const ORB_MIN_PATH_CELLS: = 18

const WALL_TEXTURE_PATH: = "res://assets/textures/256x256/Stone/Horror_Stone_08-256x256.png"

const VOX_CLOSE: Array[AudioStream] = [
	preload("res://assets/sfx/erdetlyd/vox/gorgon/horrorvox/close0.ogg"), 
	preload("res://assets/sfx/erdetlyd/vox/gorgon/horrorvox/close1.ogg"), 
	preload("res://assets/sfx/erdetlyd/vox/gorgon/horrorvox/close2.ogg"), 
	preload("res://assets/sfx/erdetlyd/vox/gorgon/horrorvox/close3.ogg"), 
	preload("res://assets/sfx/erdetlyd/vox/gorgon/horrorvox/close4.ogg"), 
	preload("res://assets/sfx/erdetlyd/vox/gorgon/horrorvox/close5.ogg"), 
	preload("res://assets/sfx/erdetlyd/vox/gorgon/horrorvox/close6.ogg"), 
	preload("res://assets/sfx/erdetlyd/vox/gorgon/horrorvox/close7.ogg"), 
	preload("res://assets/sfx/erdetlyd/vox/gorgon/horrorvox/close8.ogg"), 
	preload("res://assets/sfx/erdetlyd/vox/gorgon/horrorvox/close9.ogg"), 
]

const VOX_DISTANT: Array[AudioStream] = [
	preload("res://assets/sfx/erdetlyd/vox/gorgon/horrorvox/distant0.ogg"), 
	preload("res://assets/sfx/erdetlyd/vox/gorgon/horrorvox/distant1.ogg"), 
	preload("res://assets/sfx/erdetlyd/vox/gorgon/horrorvox/distant2.ogg"), 
]

const VOX_VERY_DISTANT: Array[AudioStream] = [
	preload("res://assets/sfx/erdetlyd/vox/gorgon/horrorvox/verydistant0.ogg"), 
	preload("res://assets/sfx/erdetlyd/vox/gorgon/horrorvox/verydistant1.ogg"), 
	preload("res://assets/sfx/erdetlyd/vox/gorgon/horrorvox/verydistant2.ogg"), 
	preload("res://assets/sfx/erdetlyd/vox/gorgon/horrorvox/verydistant3.ogg"), 
	preload("res://assets/sfx/erdetlyd/vox/gorgon/horrorvox/verydistant4.ogg"), 
]

const JUMPSCARE_SOUND: AudioStream = preload(
	"res://assets/sfx/erdetlyd/vox/gorgon/horrorvox/jumpscare.ogg"
)

const RUBBER_REACT_SOUND: AudioStream = preload(
	"res://assets/sfx/erdetlyd/vox/gorgon/herergummiendin.ogg"
)

const JUMPSCARE_TEXTURE: Texture2D = preload(
	"res://assets/textures/images/gorgonjumpscare.png"
)

const GORGON_SCENE: PackedScene = preload(
	"res://assets/props/character/Meshy_AI_Jolly_Puppet_0531185900_texture.glb"
)

@onready var _spawn_point: Marker3D = $SpawnPoint
@onready var _exit_point: Marker3D = $ExitPoint
@onready var _ambient_audio: AudioStreamPlayer = $AmbientAudio
@onready var _scare_audio: AudioStreamPlayer3D = $ScareAudio

var _active: bool = false
var _got_rubber: bool = false
var _maze_duration: float = 120.0
var _maze_timer: float = 0.0
var _scare_timer: float = 0.0
var _next_scare: float = 0.0
var _jumpscare_layer: CanvasLayer = null
var _blackout_layer: CanvasLayer = null
var _maze_root: Node3D = null
var _wall_material: StandardMaterial3D = null
var _original_env: Environment = null

var _maze_grid: PackedByteArray
var _maze_origin: Vector3

var _gorgon_node: CharacterBody3D = null
var _gorgon_audio: AudioStreamPlayer3D = null
var _waypoints: Array[Vector3] = []
var _path_timer: float = 0.0
var _hunting: bool = false
var _roam_duration: float = 30.0
var _awareness: int = Awareness.SEARCH
var _last_known_pos: Vector3 = Vector3.ZERO
var _track_timer: float = 0.0

var _vignette_layer: CanvasLayer = null
var _vignette_rect: ColorRect = null


var _hidden_hud_nodes: Array = []
var _horror_hint_canvas: CanvasLayer = null
var _horror_hint_label: Label = null

var _flicker_timer: float = 0.0
var _is_flickering: bool = false
var _jumpscare_triggered: bool = false

var _gorgon_speak_timer: float = 0.0
var _next_gorgon_speak: float = 4.0

var _hidden_lights: Array = []

var _static_player: AudioStreamPlayer = null
var _static_playback: AudioStreamGeneratorPlayback = null


func _ready() -> void :
	add_to_group("GorgonHorror")
	set_process(false)
	set_physics_process(false)
	_setup_wall_material()


func _setup_wall_material() -> void :
	_wall_material = StandardMaterial3D.new()
	if ResourceLoader.exists(WALL_TEXTURE_PATH):
		_wall_material.albedo_texture = load(WALL_TEXTURE_PATH)
	else:
		_wall_material.albedo_color = Color(0.15, 0.12, 0.1)
	_wall_material.uv1_scale = Vector3(0.535, 0.535, 0.535)
	_wall_material.uv1_triplanar = true
	_wall_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST


func activate() -> void :
	if _active:
		return
	_active = true
	_got_rubber = false
	_maze_duration = randf_range(170.0, 200.0)
	_roam_duration = randf_range(ROAM_TIME_MIN, ROAM_TIME_MAX)
	_hunting = false
	_awareness = Awareness.SEARCH
	_track_timer = 0.0

	var player: = _get_player()
	if player == null:
		_active = false
		return

	_apply_dark_environment()
	_build_maze()

	player.global_position = _spawn_point.global_position
	player.velocity = Vector3.ZERO

	_holster_weapon()
	_turn_on_flashlight(player)

	MusicManager.stop(true)
	MusicManager.play("horror")

	_ensure_ambient_loops()
	_ambient_audio.play()


	if GameManager.gorgon_stolen_item != "gummi" and GameManager.has_item("gummi"):
		GameManager.remove_item("gummi", 1)
		GameManager.gorgon_stolen_item = "gummi"
		GameManager.set_quest_hint("HVERDAGSKOMIKER", "Finn gummien din igjen")

	_maze_timer = 0.0
	_scare_timer = 0.0
	_path_timer = PATH_INTERVAL
	_flicker_timer = 0.0
	_is_flickering = false
	_jumpscare_triggered = false
	_gorgon_speak_timer = 0.0
	_next_gorgon_speak = randf_range(3.0, 6.0)
	_next_scare = _get_scare_interval()
	_waypoints.clear()

	_create_static_noise()
	_create_vignette()
	_create_blackout()
	_fade_from_black()


	_hide_gameplay_hud()
	_create_horror_hint()


	get_tree().create_timer(FADE_IN_TIME + 0.5).timeout.connect(
		_show_maze_hint.bind("NOEN HAR TATT GUMMIEN DIN. DU ER IKKE ALENE.")
	)

	_unfreeze_player(player)
	set_process(true)
	set_physics_process(true)


func _process(delta: float) -> void :
	if not _active:
		return

	_maze_timer += delta

	if _maze_timer >= _maze_duration:
		_fire_jumpscare()
		return

	if not _hunting and _maze_timer >= _roam_duration:
		_begin_hunt()

	_scare_timer += delta
	if _scare_timer >= _next_scare:
		_scare_timer = 0.0
		_next_scare = _get_scare_interval()
		_play_random_scare()

	if _gorgon_node != null:
		var player: = _get_player()
		if player != null:
			var dist: = _gorgon_node.global_position.distance_to(player.global_position)
			_update_fear_effects(dist)
			_update_static_noise(dist)





			if _gorgon_audio != null and _gorgon_audio.playing:
				_gorgon_speak_timer = 0.0
			else:
				_gorgon_speak_timer += delta
				if _gorgon_speak_timer >= _next_gorgon_speak:
					_gorgon_speak_timer = 0.0
					_next_gorgon_speak = _get_gorgon_speak_gap(dist)
					_play_gorgon_vox(dist)

			if not _is_flickering:
				_flicker_timer += delta
				if _flicker_timer >= FLICKER_INTERVAL:
					_flicker_timer = 0.0
					_do_flashlight_flicker(player)


func _physics_process(delta: float) -> void :
	if not _active or _gorgon_node == null:
		return

	var player: = _get_player()
	if player == null:
		return

	var dist: = _gorgon_node.global_position.distance_to(player.global_position)
	if dist <= CATCH_DISTANCE:
		_fire_jumpscare()
		return

	var speed: float
	if _hunting:
		_update_awareness(player, dist, delta)
		match _awareness:
			Awareness.CHASE:
				_path_timer += delta
				if _path_timer >= PATH_INTERVAL:
					_path_timer = 0.0
					_repath(player)
				speed = lerpf(GORGON_SPEED_START, GORGON_SPEED_END, _hunt_progress())
				if dist < LUNGE_DISTANCE:
					speed *= LUNGE_MULTIPLIER
			Awareness.TRACK:
				_path_timer += delta
				if _path_timer >= PATH_INTERVAL:
					_path_timer = 0.0
					_repath_to_pos(_last_known_pos)
				speed = TRACK_SPEED
			_:
				_repath_search(player)
				speed = SEARCH_SPEED
	else:
		_repath_roam()
		speed = ROAM_SPEED
	_update_gorgon_movement(delta, speed)


func _update_awareness(player: Node3D, dist: float, delta: float) -> void :
	var detected: = dist <= HEAR_RADIUS or _has_line_of_sight(player)
	if detected:
		if _awareness != Awareness.CHASE:
			_on_player_spotted(dist)
		_awareness = Awareness.CHASE
		_last_known_pos = player.global_position
		_track_timer = 0.0
		return
	if _awareness == Awareness.CHASE:
		_awareness = Awareness.TRACK
		_track_timer = 0.0
		_waypoints.clear()
	elif _awareness == Awareness.TRACK:
		_track_timer += delta
		var reached_last_known: = (
			_gorgon_node.global_position.distance_to(_last_known_pos) < 1.5
		)
		if _track_timer > TRACK_TIME_MAX or reached_last_known:
			_awareness = Awareness.SEARCH
			_waypoints.clear()


func _has_line_of_sight(player: Node3D) -> bool:
	var space: = _gorgon_node.get_world_3d().direct_space_state
	var from: = _gorgon_node.global_position + Vector3(0.0, 1.4, 0.0)
	var to: = player.global_position + Vector3(0.0, 1.2, 0.0)

	var query: = PhysicsRayQueryParameters3D.create(from, to, 1)
	query.exclude = [_gorgon_node.get_rid()]
	return space.intersect_ray(query).is_empty()


func _on_player_spotted(dist: float) -> void :

	_gorgon_speak_timer = 0.0
	_next_gorgon_speak = randf_range(0.5, 1.2)
	_play_gorgon_vox(dist)


func _repath_to_pos(pos: Vector3) -> void :
	var g_cell: = _world_to_cell(_gorgon_node.global_position)
	var t_cell: = _world_to_cell(pos)
	_waypoints.clear()
	for cell in _bfs_path(g_cell, t_cell):
		_waypoints.append(_cell_to_world(cell.x, cell.y))


func _repath_search(player: Node3D) -> void :
	if not _waypoints.is_empty():
		return

	var p_cell: = _world_to_cell(player.global_position)
	var g_cell: = _world_to_cell(_gorgon_node.global_position)
	var target: = Vector2i(
		clampi(p_cell.x + randi_range( - SEARCH_BIAS_CELLS, SEARCH_BIAS_CELLS), 0, MAZE_COLS - 1), 
		clampi(p_cell.y + randi_range( - SEARCH_BIAS_CELLS, SEARCH_BIAS_CELLS), 0, MAZE_ROWS - 1)
	)
	if target == g_cell:
		return
	for cell in _bfs_path(g_cell, target):
		_waypoints.append(_cell_to_world(cell.x, cell.y))


func _hunt_progress() -> float:
	if not _hunting:
		return 0.0
	var hunt_total: = maxf(1.0, _maze_duration - _roam_duration)
	return clampf((_maze_timer - _roam_duration) / hunt_total, 0.0, 1.0)


func _begin_hunt() -> void :
	_hunting = true
	_awareness = Awareness.SEARCH
	_track_timer = 0.0
	_scare_timer = 0.0
	_next_scare = _get_scare_interval()
	_waypoints.clear()
	_spawn_gorgon_chaser()
	_spawn_rubber_pickup(_pick_orb_position())

	var player: = _get_player()
	if player != null:

		if not VOX_DISTANT.is_empty():
			_scare_audio.stream = VOX_DISTANT[randi() % VOX_DISTANT.size()]
			var angle: = randf() * TAU
			_scare_audio.global_position = player.global_position + Vector3(
				cos(angle) * 9.0, 0.0, sin(angle) * 9.0
			)
			_scare_audio.pitch_scale = 0.85
			_scare_audio.play()
		_do_flashlight_flicker(player)
	_show_maze_hint("DEN VET AT DU ER HER. FINN GUMMIEN.")


func _pick_orb_position() -> Vector3:



	var player: = _get_player()
	var p_cell: = Vector2i(0, 0)
	if player != null:
		p_cell = _world_to_cell(player.global_position)
	var g_pos: Vector3 = (
		_gorgon_node.global_position if _gorgon_node != null else global_position
	)
	var best: = _cell_to_world(MAZE_COLS - 1, MAZE_ROWS - 1)
	var best_score: = -1.0
	var farthest: = best
	var farthest_len: = -1
	for i in 24:
		var c: = Vector2i(randi() % MAZE_COLS, randi() % MAZE_ROWS)
		var pos: = _cell_to_world(c.x, c.y)
		var path_len: = _bfs_path(p_cell, c).size()
		if path_len > farthest_len:
			farthest_len = path_len
			farthest = pos
		if path_len < ORB_MIN_PATH_CELLS:
			continue
		var score: = float(path_len) + pos.distance_to(g_pos) * 0.25
		if score > best_score:
			best_score = score
			best = pos
	if best_score < 0.0:

		return farthest
	return best


func _repath_roam() -> void :
	if not _waypoints.is_empty():
		return
	var g_cell: = _world_to_cell(_gorgon_node.global_position)
	var target: = Vector2i(randi() % MAZE_COLS, randi() % MAZE_ROWS)
	if target == g_cell:
		return
	for cell in _bfs_path(g_cell, target):
		_waypoints.append(_cell_to_world(cell.x, cell.y))


func _fire_jumpscare() -> void :
	if _jumpscare_triggered:
		return
	_jumpscare_triggered = true
	if AchievementManager != null:
		AchievementManager.unlock(AchievementManager.ACH_GETCAUGHT_GORGON)
	set_process(false)
	set_physics_process(false)
	_trigger_jumpscare()




func _spawn_gorgon_chaser() -> void :
	_gorgon_node = CharacterBody3D.new()
	_gorgon_node.name = "GorgonChaser"
	_gorgon_node.collision_layer = 4
	_gorgon_node.collision_mask = 1

	var col_shape: = CollisionShape3D.new()
	var capsule: = CapsuleShape3D.new()
	capsule.height = 1.8
	capsule.radius = 0.35
	col_shape.shape = capsule
	col_shape.position.y = 0.9
	_gorgon_node.add_child(col_shape)

	var model: = GORGON_SCENE.instantiate()
	model.position.y = 0.0
	model.scale = Vector3(1.0, 1.0, 1.0)
	model.rotation_degrees.y = 180.0
	_gorgon_node.add_child(model)



	var light: = OmniLight3D.new()
	light.light_color = Color(1.0, 0.0, 0.0)
	light.light_energy = 0.2
	light.omni_range = 1.6
	light.position.y = 1.5
	_gorgon_node.add_child(light)

	_gorgon_audio = AudioStreamPlayer3D.new()
	_gorgon_audio.volume_db = -6.0
	_gorgon_audio.max_distance = 50.0
	_gorgon_audio.unit_size = 6.0
	_gorgon_audio.bus = "Sfx"
	_gorgon_node.add_child(_gorgon_audio)

	_maze_root.add_child(_gorgon_node)
	_gorgon_node.global_position = _cell_to_world(MAZE_COLS - 1, 0)


func _repath(player: Node3D) -> void :
	var g_cell: = _world_to_cell(_gorgon_node.global_position)
	var p_cell: = _world_to_cell(player.global_position)
	if g_cell == p_cell:
		_waypoints.clear()
		return
	var path: = _bfs_path(g_cell, p_cell)
	_waypoints.clear()

	if randf() < WANDER_CHANCE and not path.is_empty():
		var wander: = _random_valid_neighbor(g_cell)
		if wander != g_cell:
			_waypoints.append(_cell_to_world(wander.x, wander.y))
	for cell in path:
		_waypoints.append(_cell_to_world(cell.x, cell.y))


func _random_valid_neighbor(cell: Vector2i) -> Vector2i:
	var gw: = 2 * MAZE_COLS + 1
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	dirs.shuffle()
	for d in dirs:
		var nb: = cell + d
		if nb.x < 0 or nb.x >= MAZE_COLS or nb.y < 0 or nb.y >= MAZE_ROWS:
			continue
		var wall_gx: = 2 * cell.x + 1 + d.x
		var wall_gz: = 2 * cell.y + 1 + d.y
		if _maze_grid[wall_gz * gw + wall_gx] == 0:
			return nb
	return cell


func _update_gorgon_movement(delta: float, speed: float) -> void :
	if not _gorgon_node.is_on_floor():
		_gorgon_node.velocity.y -= 9.8 * delta
	else:
		_gorgon_node.velocity.y = 0.0

	if not _waypoints.is_empty():
		var target: = _waypoints[0]
		var dir: = Vector3(
			target.x - _gorgon_node.global_position.x, 
			0.0, 
			target.z - _gorgon_node.global_position.z
		)
		var flat_dist: = dir.length()
		if flat_dist < 0.3:
			_waypoints.pop_front()
		elif flat_dist > 0.01:
			dir = dir / flat_dist
			_gorgon_node.velocity.x = dir.x * speed
			_gorgon_node.velocity.z = dir.z * speed
			var look_flat: = Vector3(dir.x, 0.0, dir.z)
			if look_flat.length() > 0.01:
				_gorgon_node.look_at(_gorgon_node.global_position + look_flat, Vector3.UP)
	else:
		_gorgon_node.velocity.x = 0.0
		_gorgon_node.velocity.z = 0.0

	_gorgon_node.move_and_slide()


func _update_fear_effects(dist: float) -> void :
	var near_t: = clampf(inverse_lerp(12.0, 3.0, dist), 0.0, 1.0)

	if _vignette_rect != null:
		_vignette_rect.color = Color(0.5, 0.0, 0.0, near_t * 0.22)


func _do_flashlight_flicker(player: Node3D) -> void :
	var fl: = player.get_node_or_null(
		"CameraHolder/CameraRecoilHolder/Camera/Flashlight"
	) as SpotLight3D
	if fl == null:
		return
	_is_flickering = true
	var orig: = fl.light_energy
	var tw: = get_tree().create_tween()
	tw.tween_property(fl, "light_energy", 0.05, 0.15)
	tw.tween_property(fl, "light_energy", orig * 0.6, 0.1)
	tw.tween_property(fl, "light_energy", 0.05, 0.1)
	tw.tween_property(fl, "light_energy", orig, 0.2)
	tw.tween_callback( func(): _is_flickering = false)




func _build_maze() -> void :
	if _maze_root != null:
		_maze_root.queue_free()
	_maze_root = Node3D.new()
	_maze_root.name = "MazeGeometry"
	add_child(_maze_root)

	_maze_origin = global_position
	_maze_grid = _generate_maze_grid()
	var origin: = _maze_origin

	var floor_w: float = MAZE_COLS * CELL_SIZE
	var floor_h: float = MAZE_ROWS * CELL_SIZE
	_add_csg_box(
		Vector3(floor_w * 0.5, - WALL_THICKNESS * 0.5, floor_h * 0.5) + origin, 
		Vector3(floor_w, WALL_THICKNESS, floor_h)
	)
	_add_csg_box(
		Vector3(floor_w * 0.5, WALL_HEIGHT + WALL_THICKNESS * 0.5, floor_h * 0.5) + origin, 
		Vector3(floor_w, WALL_THICKNESS, floor_h)
	)

	var gw: int = 2 * MAZE_COLS + 1
	var gh: int = 2 * MAZE_ROWS + 1
	for gz in range(gh):
		for gx in range(gw):
			if _maze_grid[gz * gw + gx] == 0:
				continue
			var wx: float = gx * CELL_SIZE * 0.5
			var wz: float = gz * CELL_SIZE * 0.5
			_add_csg_box(
				Vector3(wx, WALL_HEIGHT * 0.5, wz) + origin, 
				Vector3(CELL_SIZE * 0.5, WALL_HEIGHT, CELL_SIZE * 0.5)
			)

	_spawn_point.global_position = _cell_to_world(0, 0)





func _spawn_rubber_pickup(pos: Vector3) -> void :
	var pickup: = Area3D.new()
	pickup.name = "RubberPickup"
	pickup.collision_layer = 0
	pickup.collision_mask = 0
	pickup.set_collision_mask_value(1, true)
	pickup.set_collision_mask_value(2, true)
	pickup.monitoring = true
	_maze_root.add_child(pickup)
	pickup.global_position = pos

	var col: = CollisionShape3D.new()
	var shape: = SphereShape3D.new()
	shape.radius = 1.0
	col.shape = shape
	pickup.add_child(col)

	var mesh_inst: = MeshInstance3D.new()
	var sphere: = SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	mesh_inst.mesh = sphere
	var mat: = StandardMaterial3D.new()


	mat.albedo_color = Color(1.0, 0.0, 0.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.0, 0.0)
	mat.emission_energy_multiplier = 2.0
	mesh_inst.material_override = mat
	pickup.add_child(mesh_inst)

	var light: = OmniLight3D.new()
	light.light_color = Color(1.0, 0.0, 0.0)
	light.light_energy = 0.2
	light.omni_range = 1.6
	pickup.add_child(light)

	pickup.body_entered.connect(_on_rubber_collected)


func _on_rubber_collected(body: Node3D) -> void :
	if not body.is_in_group("PlayerCharacter"):
		return
	if _got_rubber or not _active:
		return
	_got_rubber = true
	if AchievementManager != null:
		AchievementManager.unlock(AchievementManager.ACH_ESCAPE_GORGON)
	set_process(false)
	set_physics_process(false)

	GameManager.add_item("gummi", 1)
	if GameManager.gorgon_stolen_item == "gummi":
		GameManager.gorgon_stolen_item = ""
	SfxManager.play("item_added")

	if _gorgon_node != null:
		var react_sfx: = AudioStreamPlayer3D.new()
		react_sfx.stream = RUBBER_REACT_SOUND
		react_sfx.bus = "Sfx"
		react_sfx.volume_db = 6.0
		react_sfx.max_distance = 40.0
		react_sfx.unit_size = 8.0
		react_sfx.global_position = _gorgon_node.global_position
		get_tree().root.add_child(react_sfx)
		react_sfx.play()
		react_sfx.finished.connect(react_sfx.queue_free)

	_exit_maze_clean()


func _exit_maze_clean() -> void :
	_ambient_audio.stop()
	_scare_audio.stop()
	_destroy_vignette()
	_destroy_static_noise()

	var overlay: = _create_fullscreen_overlay(Color(0, 0, 0, 1))
	await get_tree().create_timer(0.5).timeout

	_destroy_maze()
	_restore_environment()
	_set_nighttime()

	var player: = _get_player()
	if player != null:
		player.global_position = _exit_point.global_position
		player.velocity = Vector3.ZERO

	MusicManager.stop(true)
	MusicManager.activate_idle()
	_restore_weapon()

	if player != null:
		player.freeze_for_dialogue(false)

	var fade: = get_tree().create_tween()
	fade.tween_property(overlay, "color:a", 0.0, FADE_OUT_TIME)
	await fade.finished
	overlay.get_parent().queue_free()

	_active = false

	DialogueUI.show_dialogue(
		[
			"Du fant gummien!", 
			"Du klarte å rømme fra Gorgon.", 
		], 
		"", 
		Callable()
	)

	if GameManager.has_quest("GORGON_ROBBERY"):
		GameManager.update_quest_objective("GORGON_ROBBERY", "play_tictactoe", 1)
		var quest: Quest = GameManager.active_quests.get("GORGON_ROBBERY") as Quest
		if quest != null and quest.is_complete():
			GameManager.complete_quest_by_id(quest.quest_id)
	elif not GameManager.has_quest("GORGON_ROBBERY"):
		GameManager.add_quest_by_id("GORGON_ROBBERY")
		GameManager.update_quest_objective("GORGON_ROBBERY", "find_gorgon", 1)
		GameManager.update_quest_objective("GORGON_ROBBERY", "play_tictactoe", 1)
		var quest: Quest = GameManager.active_quests.get("GORGON_ROBBERY") as Quest
		if quest != null and quest.is_complete():
			GameManager.complete_quest_by_id(quest.quest_id)


func _generate_maze_grid() -> PackedByteArray:
	var gw: int = 2 * MAZE_COLS + 1
	var gh: int = 2 * MAZE_ROWS + 1
	var grid: = PackedByteArray()
	grid.resize(gw * gh)
	grid.fill(1)

	var visited: = PackedByteArray()
	visited.resize(MAZE_ROWS * MAZE_COLS)
	visited.fill(0)

	var stack: Array[Vector2i] = []
	var start: = Vector2i(0, 0)
	visited[0] = 1
	grid[(2 * start.y + 1) * gw + (2 * start.x + 1)] = 0
	stack.append(start)

	var dirs: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]

	while not stack.is_empty():
		var current: Vector2i = stack[stack.size() - 1]
		var neighbors: Array[Vector2i] = []
		for d in dirs:
			var nx: int = current.x + d.x
			var ny: int = current.y + d.y
			if nx >= 0 and nx < MAZE_COLS and ny >= 0 and ny < MAZE_ROWS:
				if visited[ny * MAZE_COLS + nx] == 0:
					neighbors.append(Vector2i(nx, ny))

		if neighbors.is_empty():
			stack.pop_back()
			continue

		var next: Vector2i = neighbors[randi() % neighbors.size()]
		visited[next.y * MAZE_COLS + next.x] = 1

		var cx: int = 2 * current.x + 1
		var cy: int = 2 * current.y + 1
		var nx: int = 2 * next.x + 1
		var ny: int = 2 * next.y + 1
		grid[ny * gw + nx] = 0
		grid[((cy + ny) / 2) * gw + ((cx + nx) / 2)] = 0

		stack.append(next)



	for gz in range(1, gh - 1):
		for gx in range(1, gw - 1):
			if grid[gz * gw + gx] == 0:
				continue
			var is_h_passage: = (gz % 2 == 0) and (gx % 2 == 1)
			var is_v_passage: = (gz % 2 == 1) and (gx % 2 == 0)
			if (is_h_passage or is_v_passage) and randf() < 0.25:
				grid[gz * gw + gx] = 0

	return grid




func _world_to_cell(world_pos: Vector3) -> Vector2i:
	var local: = world_pos - _maze_origin
	var col: = clampi(int(floor(local.x / CELL_SIZE)), 0, MAZE_COLS - 1)
	var row: = clampi(int(floor(local.z / CELL_SIZE)), 0, MAZE_ROWS - 1)
	return Vector2i(col, row)


func _cell_to_world(col: int, row: int) -> Vector3:
	return _maze_origin + Vector3((col + 0.5) * CELL_SIZE, 0.5, (row + 0.5) * CELL_SIZE)


func _bfs_path(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	if from_cell == to_cell:
		return []
	var gw: = 2 * MAZE_COLS + 1
	var queue: Array[Vector2i] = [from_cell]
	var came_from: Dictionary = {}
	came_from[from_cell] = Vector2i(-1, -1)

	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current == to_cell:
			break
		for d in dirs:
			var neighbor: = current + d
			if neighbor.x < 0 or neighbor.x >= MAZE_COLS or neighbor.y < 0 or neighbor.y >= MAZE_ROWS:
				continue
			if came_from.has(neighbor):
				continue
			var wall_gx: = 2 * current.x + 1 + d.x
			var wall_gz: = 2 * current.y + 1 + d.y
			if _maze_grid[wall_gz * gw + wall_gx] == 1:
				continue
			came_from[neighbor] = current
			queue.append(neighbor)

	if not came_from.has(to_cell):
		return []

	var path: Array[Vector2i] = []
	var c: = to_cell
	while c != from_cell:
		path.push_front(c)
		c = came_from[c]
	return path


func _add_csg_box(pos: Vector3, size: Vector3) -> void :
	var box: = CSGBox3D.new()
	box.size = size
	box.use_collision = true
	box.material_override = _wall_material
	box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_maze_root.add_child(box)
	box.global_position = pos


func _destroy_maze() -> void :
	if _maze_root != null:
		_maze_root.queue_free()
		_maze_root = null
	_gorgon_node = null
	_gorgon_audio = null
	_waypoints.clear()


func _apply_dark_environment() -> void :
	var sun: = get_tree().current_scene.find_child("DirectionalLight3D", true, false) as DirectionalLight3D
	if sun != null and sun.visible:
		_hidden_lights = [sun]
		sun.visible = false

	var world: = get_viewport().get_world_3d()
	_original_env = world.environment

	var env: = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.BLACK
	env.ambient_light_energy = 0.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.ssao_enabled = false
	env.ssil_enabled = false
	env.sdfgi_enabled = false
	env.set("tonemap_mode", 0)
	env.fog_enabled = true
	env.fog_light_color = Color.BLACK
	env.fog_density = 0.06

	world.environment = env


func _restore_environment() -> void :
	for light in _hidden_lights:
		if is_instance_valid(light):
			light.visible = true
	_hidden_lights.clear()

	get_viewport().get_world_3d().environment = _original_env
	_original_env = null



	_show_gameplay_hud()
	_destroy_horror_hint()


func _set_nighttime() -> void :
	var lc: Node = get_tree().get_first_node_in_group("LightingCycle")
	if lc == null:
		return
	lc.time_of_day = 0.95
	if lc.has_method("_apply_lighting"):
		lc._apply_lighting(0.95)








func _ensure_ambient_loops() -> void :
	if _ambient_audio == null or _ambient_audio.stream == null:
		return
	if _ambient_audio.stream.get_meta("looped_local", false):
		return
	var amb: AudioStream = _ambient_audio.stream.duplicate()
	amb.loop = true
	amb.set_meta("looped_local", true)
	_ambient_audio.stream = amb


func _get_scare_interval() -> float:
	if not _hunting:

		return randf_range(14.0, 22.0)
	return lerpf(12.0, 3.5, _hunt_progress())


func _play_random_scare() -> void :

	if VOX_VERY_DISTANT.is_empty():
		return

	if _scare_audio.playing:
		return
	var sound: AudioStream = VOX_VERY_DISTANT[randi() % VOX_VERY_DISTANT.size()]
	_scare_audio.stream = sound
	var player: = _get_player()
	if player != null:
		var dist: float = lerpf(28.0, 10.0, _hunt_progress())
		var angle: = randf() * TAU
		_scare_audio.global_position = player.global_position + Vector3(
			cos(angle) * dist, 0.0, sin(angle) * dist
		)
	_scare_audio.pitch_scale = randf_range(0.8, 1.05)
	_scare_audio.play()




func _gorgon_menace(dist: float) -> float:
	var by_time: float = _hunt_progress() if _hunting else 0.0
	var by_dist: = clampf(1.0 - (dist - CATCH_DISTANCE) / 20.0, 0.0, 1.0)
	return clampf(by_time * 0.55 + by_dist * 0.65, 0.0, 1.0)




func _get_gorgon_speak_gap(dist: float) -> float:
	if not _hunting:

		return randf_range(5.0, 10.0)
	return lerpf(2.8, 0.12, _gorgon_menace(dist))


func _play_gorgon_vox(dist: float) -> void :

	if _gorgon_audio == null or _gorgon_audio.playing:
		return
	var menace: = _gorgon_menace(dist)

	var pool: Array[AudioStream]
	if dist <= 10.0 or menace > 0.75:
		pool = VOX_CLOSE
	elif dist <= 16.0 or menace > 0.4:
		pool = VOX_DISTANT
	else:
		pool = VOX_VERY_DISTANT
	if pool.is_empty():
		return

	_gorgon_audio.pitch_scale = lerpf(1.05, 0.78, menace) * randf_range(0.96, 1.04)
	_gorgon_audio.volume_db = lerpf(-8.0, 0.0, menace)
	_gorgon_audio.stream = pool[randi() % pool.size()]
	_gorgon_audio.play()




func _trigger_jumpscare() -> void :
	var player: = _get_player()
	if player != null:
		player.freeze_for_dialogue(true)

	_jumpscare_layer = CanvasLayer.new()
	_jumpscare_layer.layer = 100
	_jumpscare_layer.process_mode = Node.PROCESS_MODE_ALWAYS

	var img: = TextureRect.new()
	img.texture = JUMPSCARE_TEXTURE
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.set_anchors_preset(Control.PRESET_FULL_RECT)
	_jumpscare_layer.add_child(img)

	var flash: = ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_jumpscare_layer.add_child(flash)

	get_tree().root.add_child(_jumpscare_layer)



	var strobe: = flash.create_tween().set_loops()
	strobe.tween_property(flash, "color:a", 0.85, 0.04)
	strobe.tween_property(flash, "color:a", 0.0, 0.07)

	var shake: = img.create_tween().set_loops()
	shake.tween_property(img, "position", Vector2(14.0, -10.0), 0.05)
	shake.tween_property(img, "position", Vector2(-12.0, 8.0), 0.05)
	shake.tween_property(img, "position", Vector2(8.0, 12.0), 0.05)
	shake.tween_property(img, "position", Vector2.ZERO, 0.05)

	var audio: = AudioStreamPlayer.new()
	audio.bus = "Sfx"
	audio.stream = JUMPSCARE_SOUND
	audio.volume_db = 6.0
	_jumpscare_layer.add_child(audio)
	audio.play()

	await get_tree().create_timer(JUMPSCARE_HOLD).timeout
	_end_horror_jumpscared()


func _end_horror_jumpscared() -> void :
	if _jumpscare_layer != null:
		_jumpscare_layer.queue_free()
		_jumpscare_layer = null

	_ambient_audio.stop()
	_scare_audio.stop()
	_destroy_vignette()
	_destroy_static_noise()

	var overlay: = _create_fullscreen_overlay(Color(0, 0, 0, 1))
	await get_tree().create_timer(0.5).timeout

	_destroy_maze()
	_restore_environment()
	_set_nighttime()

	var player: = _get_player()
	if player != null:
		player.global_position = _exit_point.global_position
		player.velocity = Vector3.ZERO

	MusicManager.stop(true)
	MusicManager.activate_idle()
	_restore_weapon()

	if player != null:
		player.freeze_for_dialogue(false)

	var fade: = get_tree().create_tween()
	fade.tween_property(overlay, "color:a", 0.0, FADE_OUT_TIME)
	await fade.finished
	overlay.get_parent().queue_free()

	_active = false

	if not GameManager.has_quest("GORGON_ROBBERY"):
		GameManager.add_quest_by_id("GORGON_ROBBERY")

	DialogueUI.show_dialogue(
		[
			"Gummien din er borte...", 
			"Det var Gorgon. Han slo deg i hodet og tok den.", 
			"Han holder til på Kratergata. Finn ham og få gummien tilbake.", 
		], 
		"", 
		Callable()
	)




func _create_static_noise() -> void :
	var stream: = AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = 0.1
	_static_player = AudioStreamPlayer.new()
	_static_player.stream = stream
	_static_player.bus = "Sfx"
	_static_player.volume_db = -80.0
	add_child(_static_player)
	_static_player.play()
	_static_playback = _static_player.get_stream_playback() as AudioStreamGeneratorPlayback


func _update_static_noise(dist: float) -> void :
	if _static_player == null or _static_playback == null:
		return
	var t: = clampf(inverse_lerp(8.0, 1.5, dist), 0.0, 1.0)
	_static_player.volume_db = lerpf(-80.0, -2.0, t * t)
	var frames: = _static_playback.get_frames_available()
	for i in range(frames):
		_static_playback.push_frame(Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)))


func _destroy_static_noise() -> void :
	if _static_player != null:
		_static_player.queue_free()
		_static_player = null
		_static_playback = null




func _show_maze_hint(hint_text: String) -> void :
	if not _active:
		return
	if _horror_hint_label == null:
		_create_horror_hint()
	if _horror_hint_label == null:
		return
	_horror_hint_label.text = hint_text
	_horror_hint_label.modulate.a = 0.0
	var tw: = get_tree().create_tween()
	tw.tween_property(_horror_hint_label, "modulate:a", 1.0, 0.4)



func _create_horror_hint() -> void :
	if _horror_hint_canvas != null and is_instance_valid(_horror_hint_canvas):
		return
	_horror_hint_canvas = CanvasLayer.new()
	_horror_hint_canvas.layer = 60
	_horror_hint_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	_horror_hint_label = Label.new()
	_horror_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_horror_hint_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_horror_hint_label.offset_top = 26.0
	_horror_hint_label.add_theme_font_size_override("font_size", 16)
	_horror_hint_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
	_horror_hint_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_horror_hint_label.add_theme_constant_override("outline_size", 6)
	_horror_hint_label.modulate.a = 0.0
	_horror_hint_canvas.add_child(_horror_hint_label)
	get_tree().root.add_child(_horror_hint_canvas)


func _destroy_horror_hint() -> void :
	if _horror_hint_canvas != null and is_instance_valid(_horror_hint_canvas):
		_horror_hint_canvas.queue_free()
	_horror_hint_canvas = null
	_horror_hint_label = null




func _hide_gameplay_hud() -> void :
	_hidden_hud_nodes.clear()
	var player: = _get_player()
	if player == null:
		return
	for hud_name in ["HUD", "QuestHud"]:
		var node: = player.get_node_or_null(hud_name) as CanvasLayer
		if node != null and node.visible:
			node.visible = false
			_hidden_hud_nodes.append(node)


func _show_gameplay_hud() -> void :
	for node in _hidden_hud_nodes:
		if is_instance_valid(node):
			node.visible = true
	_hidden_hud_nodes.clear()


func _create_vignette() -> void :
	_vignette_layer = CanvasLayer.new()
	_vignette_layer.layer = 50
	_vignette_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_vignette_rect = ColorRect.new()
	_vignette_rect.color = Color(0.6, 0.0, 0.0, 0.0)
	_vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette_layer.add_child(_vignette_rect)
	get_tree().root.add_child(_vignette_layer)


func _destroy_vignette() -> void :
	if _vignette_layer != null:
		_vignette_layer.queue_free()
		_vignette_layer = null
		_vignette_rect = null


func _create_blackout() -> void :
	_blackout_layer = CanvasLayer.new()
	_blackout_layer.layer = 99
	_blackout_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var overlay: = ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = Color(0, 0, 0, 1)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blackout_layer.add_child(overlay)
	get_tree().root.add_child(_blackout_layer)


func _fade_from_black() -> void :
	if _blackout_layer == null:
		return
	var overlay: ColorRect = _blackout_layer.get_node("Overlay") as ColorRect
	if overlay == null:
		return
	var fade: = get_tree().create_tween()
	fade.tween_property(overlay, "color:a", 0.0, FADE_IN_TIME)
	fade.tween_callback(_blackout_layer.queue_free)


func _create_fullscreen_overlay(color: Color) -> ColorRect:
	var canvas: = CanvasLayer.new()
	canvas.layer = 99
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	var overlay: = ColorRect.new()
	overlay.color = color
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(overlay)
	get_tree().root.add_child(canvas)
	return overlay




func _get_player() -> Node3D:
	return NetUtil.get_local_player() as Node3D


func _holster_weapon() -> void :
	var wm: = get_tree().get_first_node_in_group("WeaponManager")
	if wm == null:
		wm = get_tree().get_first_node_in_group("WeaponViewmodelController")
	if wm != null and wm.has_method("holster_for_dialogue"):
		wm.holster_for_dialogue()


func _restore_weapon() -> void :
	var wm: = get_tree().get_first_node_in_group("WeaponManager")
	if wm == null:
		wm = get_tree().get_first_node_in_group("WeaponViewmodelController")
	if wm != null and wm.has_method("restore_after_dialogue"):
		wm.restore_after_dialogue()


func _turn_on_flashlight(player: Node3D) -> void :
	var fl: = player.get_node_or_null(
		"CameraHolder/CameraRecoilHolder/Camera/Flashlight"
	) as SpotLight3D
	if fl != null:
		fl.visible = true


func _unfreeze_player(player: Node3D) -> void :



	player.set("dialogue_waiting_for_button", false)
	player.set("movement_frozen", false)
	player.set("camera_frozen", false)
	if player.has_method("freeze_for_dialogue"):
		player.freeze_for_dialogue(false)
	player.process_mode = Node.PROCESS_MODE_INHERIT
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
