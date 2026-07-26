extends CanvasLayer

const CELL_SIZE: = 2.0
const WORLD_MIN_X: = -160.0
const WORLD_MAX_X: = 160.0
const WORLD_MIN_Z: = -140.0
const WORLD_MAX_Z: = 140.0
const GRID_W: int = 160
const GRID_H: int = 140
const REVEAL_RADIUS: = 6
const SAVE_PATH: = "user://map_data.dat"
const TRACK_INTERVAL: = 0.5
const MAP_BG_PATH: = "res://assets/textures/map_background.png"

const COLOR_FOG: = Color(0.03, 0.03, 0.06)
const COLOR_PLAYER: = Color(1.0, 0.9, 0.2)
const COLOR_PLAYER_OUTLINE: = Color(0.7, 0.15, 0.15)





const LABELS_NEED_EXPLORED: = true
const LOCATIONS: Array[Dictionary] = [
	{"name": "KJIWI", "x": 37.0, "z": -19.8}, 
	{"name": "BANK", "x": -16.5, "z": 11.1}, 
	{"name": "LÅNEKASSA", "x": 125.1, "z": -24.4}, 
	{"name": "POLETI", "x": 86.7, "z": -24.4}, 
	{"name": "IVER", "x": -19.4, "z": -7.7}, 
	{"name": "ERDETENBUTIKK", "x": -74.8, "z": 72.1}, 
]

var _explored: PackedByteArray
var _map_open: bool = false
var _dirty: bool = false
var _track_timer: float = 0.0

var _bg_small: Image
var _composite: Image
var _texture: ImageTexture
var _overlay: ColorRect
var _map_rect: TextureRect
var _title_label: Label
var _hint_label: Label
var _labels_root: Control
var _loc_labels: Array[Label] = []


func _ready() -> void :
	layer = 85
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_explored = PackedByteArray()
	_explored.resize(GRID_W * GRID_H)
	_explored.fill(0)
	_load_map_data()
	_load_bg_image()
	_build_ui()


func _load_bg_image() -> void :
	_bg_small = Image.create(GRID_W, GRID_H, false, Image.FORMAT_RGB8)
	_bg_small.fill(Color(0.15, 0.22, 0.12))
	if not ResourceLoader.exists(MAP_BG_PATH):
		return
	var tex: Texture2D = load(MAP_BG_PATH) as Texture2D
	if tex == null:
		return
	var src: = tex.get_image()
	if src == null:
		return
	src.resize(GRID_W, GRID_H, Image.INTERPOLATE_BILINEAR)
	_bg_small = src
	if _bg_small.get_format() != Image.FORMAT_RGB8:
		_bg_small.convert(Image.FORMAT_RGB8)


func _build_ui() -> void :
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.92)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	_composite = Image.create(GRID_W, GRID_H, false, Image.FORMAT_RGB8)
	_composite.fill(COLOR_FOG)
	_texture = ImageTexture.create_from_image(_composite)

	_map_rect = TextureRect.new()
	_map_rect.texture = _texture
	_map_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_map_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_map_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_rect.offset_left = 40.0
	_map_rect.offset_right = -40.0
	_map_rect.offset_top = 36.0
	_map_rect.offset_bottom = -36.0
	add_child(_map_rect)



	_labels_root = Control.new()
	_labels_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_labels_root.offset_left = 40.0
	_labels_root.offset_right = -40.0
	_labels_root.offset_top = 36.0
	_labels_root.offset_bottom = -36.0
	_labels_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_labels_root)
	_build_location_labels()

	_title_label = Label.new()
	_title_label.text = "KART"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title_label.offset_top = 8.0
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_label)

	_hint_label = Label.new()
	_hint_label.text = "M — lukk"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint_label.offset_bottom = -8.0
	_hint_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_hint_label.add_theme_font_size_override("font_size", 12)
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint_label)


func _process(delta: float) -> void :
	if _map_open:
		return
	_track_timer += delta
	if _track_timer >= TRACK_INTERVAL:
		_track_timer = 0.0
		_track_player()


func _track_player() -> void :
	var player: = GameManager.get_player() as Node3D
	if player == null or not player.is_inside_tree():
		return
	var pos: = player.global_position
	var cx: = int((pos.x - WORLD_MIN_X) / CELL_SIZE)
	var cz: = int((pos.z - WORLD_MIN_Z) / CELL_SIZE)
	for dz in range( - REVEAL_RADIUS, REVEAL_RADIUS + 1):
		for dx in range( - REVEAL_RADIUS, REVEAL_RADIUS + 1):
			var gx: = cx + dx
			var gz: = cz + dz
			if gx < 0 or gx >= GRID_W or gz < 0 or gz >= GRID_H:
				continue
			var idx: = gz * GRID_W + gx
			if _explored[idx] == 0:
				_explored[idx] = 1
				_dirty = true


func _unhandled_input(event: InputEvent) -> void :

	if _map_open and event.is_action_pressed("ui_cancel"):
		_close_map()
		get_viewport().set_input_as_handled()
		return

	var is_key_m: = event is InputEventKey and (event as InputEventKey).pressed\
	and not (event as InputEventKey).echo and (event as InputEventKey).keycode == KEY_M
	var is_joy_map: = event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed\
	and (event as InputEventJoypadButton).button_index == JOY_BUTTON_DPAD_RIGHT
	if not (is_key_m or is_joy_map):
		return
	if not _map_open and _should_block():
		return
	if _map_open:
		_close_map()
	else:
		_open_map()
	get_viewport().set_input_as_handled()


func _should_block() -> bool:
	var tree: = get_tree()
	if tree == null:
		return true
	var cur: = tree.current_scene
	if cur == null or cur.scene_file_path != "res://levels/main_demo.tscn":
		return true
	if cur.has_node("EndingSequence"):
		return true
	if DialogueUI and DialogueUI.is_open():
		return true
	if GameManager and GameManager.is_minigame_active():
		return true
	if tree.paused and not _map_open:
		return true
	return false


func _open_map() -> void :
	_map_open = true
	_track_player()
	_refresh_composite()
	_position_location_labels()
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _close_map() -> void :
	_map_open = false
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_save_map_data()


func _refresh_composite() -> void :
	for z in range(GRID_H):
		var row: = z * GRID_W
		for x in range(GRID_W):
			if _explored[row + x] > 0:
				_composite.set_pixel(x, z, _bg_small.get_pixel(x, z))
			else:
				_composite.set_pixel(x, z, COLOR_FOG)

	var player: = GameManager.get_player() as Node3D
	if player != null and player.is_inside_tree():
		var pos: = player.global_position
		var px: = clampi(int((pos.x - WORLD_MIN_X) / CELL_SIZE), 0, GRID_W - 1)
		var pz: = clampi(int((pos.z - WORLD_MIN_Z) / CELL_SIZE), 0, GRID_H - 1)
		for dz in range(-2, 3):
			for dx in range(-2, 3):
				var ox: = clampi(px + dx, 0, GRID_W - 1)
				var oz: = clampi(pz + dz, 0, GRID_H - 1)
				if absi(dx) <= 1 and absi(dz) <= 1:
					_composite.set_pixel(ox, oz, COLOR_PLAYER)
				else:
					_composite.set_pixel(ox, oz, COLOR_PLAYER_OUTLINE)

	_texture.update(_composite)


func _build_location_labels() -> void :
	for loc: Dictionary in LOCATIONS:
		var lbl: = Label.new()
		lbl.text = str(loc.get("name", ""))
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.96, 0.94, 0.78))
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		lbl.add_theme_constant_override("outline_size", 5)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.visible = false
		_labels_root.add_child(lbl)
		_loc_labels.append(lbl)




func _position_location_labels() -> void :
	for i in _loc_labels.size():
		var loc: Dictionary = LOCATIONS[i]
		var lbl: Label = _loc_labels[i]
		var wx: = float(loc.get("x", 0.0))
		var wz: = float(loc.get("z", 0.0))
		if LABELS_NEED_EXPLORED and not _cell_explored(wx, wz):
			lbl.visible = false
			continue
		lbl.visible = true
		lbl.reset_size()
		lbl.position = _world_to_map_point(wx, wz) - lbl.size * 0.5




func _world_to_map_point(wx: float, wz: float) -> Vector2:
	var gx: = (wx - WORLD_MIN_X) / CELL_SIZE
	var gz: = (wz - WORLD_MIN_Z) / CELL_SIZE
	var rect_size: = _labels_root.size
	var s: = minf(rect_size.x / float(GRID_W), rect_size.y / float(GRID_H))
	var disp: = Vector2(GRID_W * s, GRID_H * s)
	var origin: = (rect_size - disp) * 0.5
	return origin + Vector2(gx * s, gz * s)


func _cell_explored(wx: float, wz: float) -> bool:
	var gx: = int((wx - WORLD_MIN_X) / CELL_SIZE)
	var gz: = int((wz - WORLD_MIN_Z) / CELL_SIZE)
	if gx < 0 or gx >= GRID_W or gz < 0 or gz >= GRID_H:
		return false
	return _explored[gz * GRID_W + gx] > 0


func _save_map_data() -> void :
	if not _dirty:
		return
	var file: = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_buffer(_explored)
	file.close()
	_dirty = false


func _load_map_data() -> void :
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data: = file.get_buffer(GRID_W * GRID_H)
	file.close()
	if data.size() == _explored.size():
		_explored = data


func _exit_tree() -> void :
	_save_map_data()
