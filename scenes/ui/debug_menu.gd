extends CanvasLayer

const QUEST_IDS: Array[String] = [
	"GRANDPA_REQUEST", 
	"BANK_INHERITANCE", 
	"ECONOMIC_REALITY", 
	"GRANDPA_DISAPPOINTMENT", 
	"SCHOLARSHIP_APPLICATION", 
	"BANK_DEPOSIT", 
	"SECOND_ICECREAM", 
	"FINAL_DELIVERY", 
	"KRIS_LUA", 
	"IVER_BEVIS", 
	"STEINAR_GRUS", 
	"HVERDAGSKOMIKER", 
	"GORGON_ROBBERY", 
	"VINDKAST_PLAKATER", 
]

const ITEM_IDS: Array[String] = [
	"fugleskinn", 
	"elgskinn", 
	"grus", 
	"kobber", 
	"plast", 
	"gummi", 
	"stoepsel", 
	"fiskestang", 
	"peak_performance_lua", 
	"gard_plakat", 
	"icecream", 
	"inheritance_document", 
	"approved_application", 
	"kefir", 
	"painkillers", 
	"god_morgen_yoghurt", 
	"id_card", 
	"tnt", 
]

const TELEPORT_LOCATIONS: Dictionary = {
	"KJIWI": Vector3(100.0, 2.1, 60.0), 
	"Lånekassa": Vector3(120.0, 2.1, 60.0), 
	"Bank": Vector3(80.0, 2.1, 60.0), 
	"Iver": Vector3(50.0, 2.1, 40.0), 
	"Elgveien": Vector3(130.0, 2.1, 90.0), 
	"Kraftstasjon": Vector3(60.0, 2.1, 90.0), 
	"PostVeien": Vector3(37.9, 2.1, -93.3), 
	"Strømmasta": Vector3(22.0, 2.1, -23.6), 
	"Annoying Kid": Vector3(17.6, 2.1, -23.7), 
	"Bestefar": Vector3(-27.2, 2.1, 69.3), 
	"Grusbrodrene": Vector3(-34.7, 2.1, 65.1), 
	"Gorgon (fabrikk)": Vector3(-75.0, 2.1, 75.0), 
	"Vindkast": Vector3(-124.6, 2.1, 44.5), 
}



const REVIEW_MODE: = false

const SCENE_PATHS: Dictionary = {
	"main_demo": "res://levels/main_demo.tscn", 
	"gorgon_boss_test": "res://levels/gorgon_boss_test.tscn", 
	"hk_test": "res://levels/hk_test.tscn", 
	"devroom": "res://levels/devroom.tscn", 
	"test_scene": "res://levels/test_scene.tscn", 
}

const CINEMATIC_FOV_MIN: = 20.0
const CINEMATIC_FOV_MAX: = 120.0
const CINEMATIC_FOV_DEFAULT: = 50.0
const CINEMATIC_FOV_STEP: = 2.0

var _menu_open: bool = false
var _cinematic_active: bool = false
var _cinematic_fov: float = CINEMATIC_FOV_DEFAULT
var _cinematic_show_hands: bool = false
var _fps_label: Label = null
var _money_label: Label = null
var _inventory_label: Label = null
var _debug_panel: Panel = null
var _quest_labels: Dictionary = {}
var _cinematic_toggle_btn: Button = null
var _cinematic_fov_slider: HSlider = null
var _cinematic_fov_label: Label = null
var _cinematic_hands_check: CheckBox = null


func _ready() -> void :
	if not OS.is_debug_build() and not REVIEW_MODE:
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	visible = true
	_build_ui()
	_debug_panel.visible = false


func _build_ui() -> void :
	_debug_panel = Panel.new()
	_debug_panel.name = "DebugPanel"
	_debug_panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_debug_panel.custom_minimum_size = Vector2(320, 0)
	add_child(_debug_panel)

	var scroll: = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_debug_panel.add_child(scroll)

	var vbox: = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.custom_minimum_size = Vector2(300, 0)
	scroll.add_child(vbox)

	_fps_label = Label.new()
	_fps_label.text = "FPS: 0"
	vbox.add_child(_fps_label)
	vbox.add_child(HSeparator.new())

	_money_label = Label.new()
	_money_label.text = "Penger: 0 NOK"
	vbox.add_child(_money_label)

	var money_row: = HBoxContainer.new()
	vbox.add_child(money_row)

	var money_input: = LineEdit.new()
	money_input.placeholder_text = "Sett NOK"
	money_input.custom_minimum_size = Vector2(120, 0)
	money_row.add_child(money_input)

	var set_money_btn: = Button.new()
	set_money_btn.text = "Sett"
	set_money_btn.pressed.connect( func() -> void :
		var amount: int = int(money_input.text)
		GameManager.set_money(amount)
	)
	money_row.add_child(set_money_btn)

	var add_100_btn: = Button.new()
	add_100_btn.text = "+100"
	add_100_btn.pressed.connect( func() -> void :
		GameManager.add_flat_money_reward(100)
	)
	money_row.add_child(add_100_btn)

	vbox.add_child(HSeparator.new())

	var inv_title: = Label.new()
	inv_title.text = "INVENTORY"
	vbox.add_child(inv_title)

	_inventory_label = Label.new()
	_inventory_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inventory_label.custom_minimum_size = Vector2(280, 0)
	_inventory_label.add_theme_font_size_override("font_size", 11)
	_inventory_label.text = "(tom)"
	vbox.add_child(_inventory_label)

	vbox.add_child(HSeparator.new())

	var quest_title: = Label.new()
	quest_title.text = "QUESTS (+ add, ✓ complete, ✗ reset)"
	vbox.add_child(quest_title)

	for qid in QUEST_IDS:
		var row: = HBoxContainer.new()
		vbox.add_child(row)

		var lbl: = Label.new()
		lbl.text = qid
		lbl.custom_minimum_size = Vector2(140, 0)
		lbl.add_theme_font_size_override("font_size", 11)
		row.add_child(lbl)
		_quest_labels[qid] = lbl

		var add_btn: = Button.new()
		add_btn.text = "+"
		add_btn.custom_minimum_size = Vector2(28, 0)
		add_btn.pressed.connect(_on_add_quest.bind(qid))
		row.add_child(add_btn)

		var done_btn: = Button.new()
		done_btn.text = "✓"
		done_btn.custom_minimum_size = Vector2(28, 0)
		done_btn.pressed.connect(_on_complete_quest.bind(qid))
		row.add_child(done_btn)

		var reset_btn: = Button.new()
		reset_btn.text = "✗"
		reset_btn.custom_minimum_size = Vector2(28, 0)
		reset_btn.pressed.connect(_on_reset_quest.bind(qid))
		row.add_child(reset_btn)

	vbox.add_child(HSeparator.new())

	var item_title: = Label.new()
	item_title.text = "ITEMS"
	vbox.add_child(item_title)

	for iid in ITEM_IDS:
		var row: = HBoxContainer.new()
		vbox.add_child(row)

		var lbl: = Label.new()
		lbl.text = iid
		lbl.custom_minimum_size = Vector2(160, 0)
		lbl.add_theme_font_size_override("font_size", 11)
		row.add_child(lbl)

		var give_btn: = Button.new()
		give_btn.text = "Gi"
		give_btn.pressed.connect(_on_give_item.bind(iid))
		row.add_child(give_btn)

	var hk_row: = HBoxContainer.new()
	vbox.add_child(hk_row)
	var hk_btn: = Button.new()
	hk_btn.text = "Gi HK-materialer"
	hk_btn.pressed.connect(_on_give_hk_materials)
	hk_row.add_child(hk_btn)

	vbox.add_child(HSeparator.new())

	var tp_title: = Label.new()
	tp_title.text = "TELEPORT"
	vbox.add_child(tp_title)

	for loc_name in TELEPORT_LOCATIONS:
		var btn: = Button.new()
		btn.text = loc_name
		var pos: Vector3 = TELEPORT_LOCATIONS[loc_name]
		btn.pressed.connect(_on_teleport.bind(pos))
		vbox.add_child(btn)

	vbox.add_child(HSeparator.new())

	_build_cinematic_ui(vbox)

	vbox.add_child(HSeparator.new())

	var npc_title: = Label.new()
	npc_title.text = "NPC TEST"
	vbox.add_child(npc_title)

	var tp_mast_btn: = Button.new()
	tp_mast_btn.text = "TP Strømmasta"
	tp_mast_btn.pressed.connect(_on_teleport.bind(TELEPORT_LOCATIONS["Strømmasta"]))
	vbox.add_child(tp_mast_btn)

	var tp_kid_btn: = Button.new()
	tp_kid_btn.text = "TP Annoying Kid"
	tp_kid_btn.pressed.connect(_on_teleport.bind(TELEPORT_LOCATIONS["Annoying Kid"]))
	vbox.add_child(tp_kid_btn)

	var drawing_taken_btn: = Button.new()
	drawing_taken_btn.text = "Strømmasta: tegning tatt"
	drawing_taken_btn.pressed.connect(_on_strommast_drawing_taken)
	vbox.add_child(drawing_taken_btn)

	var flatten_kid_btn: = Button.new()
	flatten_kid_btn.text = "Flatten kid"
	flatten_kid_btn.pressed.connect(_on_flatten_kid)
	vbox.add_child(flatten_kid_btn)

	vbox.add_child(HSeparator.new())

	var misc_title: = Label.new()
	misc_title.text = "MISC"
	vbox.add_child(misc_title)

	var radio_skip_btn: = Button.new()
	radio_skip_btn.text = "Radio: neste sekvens"
	radio_skip_btn.pressed.connect(_on_radio_skip)
	vbox.add_child(radio_skip_btn)

	var next_day_btn: = Button.new()
	next_day_btn.text = "Neste dag"
	next_day_btn.pressed.connect( func() -> void :
		GameManager._advance_day()
	)
	vbox.add_child(next_day_btn)

	var speedrun_btn: = Button.new()
	speedrun_btn.text = "Lås opp speedrun"
	speedrun_btn.pressed.connect( func() -> void :
		GameManager.game_completed_once = true
		GameManager.save_settings()
	)
	vbox.add_child(speedrun_btn)

	var complete_game_btn: = Button.new()
	complete_game_btn.text = "Fullfør alle quests"
	complete_game_btn.pressed.connect(_on_complete_all_quests)
	vbox.add_child(complete_game_btn)

	var reset_all_btn: = Button.new()
	reset_all_btn.text = "Reset alt"
	reset_all_btn.pressed.connect(_on_reset_all)
	vbox.add_child(reset_all_btn)

	vbox.add_child(HSeparator.new())

	var scene_title: = Label.new()
	scene_title.text = "SCENE JUMP"
	vbox.add_child(scene_title)

	for scene_name in SCENE_PATHS:
		var scene_btn: = Button.new()
		scene_btn.text = scene_name
		var scene_path: String = SCENE_PATHS[scene_name]
		scene_btn.pressed.connect(_on_change_scene.bind(scene_path))
		vbox.add_child(scene_btn)


	vbox.add_child(HSeparator.new())
	var review_title: = Label.new()
	review_title.text = "VALVE-TESTING (minispill + jumpscare)"
	vbox.add_child(review_title)

	var ttt_btn: = Button.new()
	ttt_btn.text = "Minispill: Tre på rad"
	ttt_btn.pressed.connect(_spawn_minigame_overlay.bind("res://scenes/minigames/tictactoe.tscn"))
	vbox.add_child(ttt_btn)

	var scholar_btn: = Button.new()
	scholar_btn.text = "Minispill: Stipendsøknad"
	scholar_btn.pressed.connect(_spawn_minigame_overlay.bind("res://scenes/minigames/scholarship_form.tscn"))
	vbox.add_child(scholar_btn)

	var lemon_btn: = Button.new()
	lemon_btn.text = "Minispill: Limonadesalg"
	lemon_btn.pressed.connect(_spawn_lemonade)
	vbox.add_child(lemon_btn)

	var horror_btn: = Button.new()
	horror_btn.text = "Gorgon-labyrint (horror + jumpscare)"
	horror_btn.pressed.connect(_start_gorgon_horror)
	vbox.add_child(horror_btn)


func _build_cinematic_ui(vbox: VBoxContainer) -> void :
	var title: = Label.new()
	title.text = "CINEMATIC VIEW (F3)"
	vbox.add_child(title)

	_cinematic_toggle_btn = Button.new()
	_cinematic_toggle_btn.text = "Aktiver cinematic"
	_cinematic_toggle_btn.pressed.connect(_toggle_cinematic)
	vbox.add_child(_cinematic_toggle_btn)

	_cinematic_hands_check = CheckBox.new()
	_cinematic_hands_check.text = "Vis hender / våpen"
	_cinematic_hands_check.button_pressed = _cinematic_show_hands
	_cinematic_hands_check.toggled.connect(_on_cinematic_hands_toggled)
	vbox.add_child(_cinematic_hands_check)

	_cinematic_fov_label = Label.new()
	_cinematic_fov_label.text = "FOV: %.0f" % _cinematic_fov
	vbox.add_child(_cinematic_fov_label)

	_cinematic_fov_slider = HSlider.new()
	_cinematic_fov_slider.min_value = CINEMATIC_FOV_MIN
	_cinematic_fov_slider.max_value = CINEMATIC_FOV_MAX
	_cinematic_fov_slider.step = 1.0
	_cinematic_fov_slider.value = _cinematic_fov
	_cinematic_fov_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cinematic_fov_slider.value_changed.connect(_on_cinematic_fov_slider_changed)
	vbox.add_child(_cinematic_fov_slider)

	var fov_row: = HBoxContainer.new()
	vbox.add_child(fov_row)

	var narrow_btn: = Button.new()
	narrow_btn.text = "− FOV"
	narrow_btn.pressed.connect(_adjust_cinematic_fov.bind( - CINEMATIC_FOV_STEP))
	fov_row.add_child(narrow_btn)

	var wide_btn: = Button.new()
	wide_btn.text = "+ FOV"
	wide_btn.pressed.connect(_adjust_cinematic_fov.bind(CINEMATIC_FOV_STEP))
	fov_row.add_child(wide_btn)

	var reset_fov_btn: = Button.new()
	reset_fov_btn.text = "Reset 50"
	reset_fov_btn.pressed.connect( func() -> void :
		_set_cinematic_fov(CINEMATIC_FOV_DEFAULT)
	)
	fov_row.add_child(reset_fov_btn)

	var hint: = Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(280, 0)
	hint.add_theme_font_size_override("font_size", 10)
	hint.text = "[ / ] justerer FOV mens cinematic er på. Skjuler HUD og quest."
	vbox.add_child(hint)


func _get_player() -> PlayerCharacter:
	return NetUtil.get_local_player() as PlayerCharacter


func _toggle_cinematic() -> void :
	_set_cinematic_active( not _cinematic_active)


func _set_cinematic_active(active: bool) -> void :
	_cinematic_active = active
	var player: = _get_player()
	if player:
		player.set_debug_cinematic_view(active, _cinematic_fov, _cinematic_show_hands)
	if _cinematic_toggle_btn:
		_cinematic_toggle_btn.text = "Deaktiver cinematic" if active else "Aktiver cinematic"
	if active:
		var player_cam: = _get_player_camera()
		if player_cam:
			_cinematic_fov = player_cam.fov
			_set_cinematic_fov(_cinematic_fov, false)


func _get_player_camera() -> Camera3D:
	var player: = _get_player()
	if player == null:
		return null
	var cam_holder: Node3D = player.get_node_or_null("CameraHolder")
	if cam_holder == null:
		return null
	return cam_holder.get_node_or_null("CameraRecoilHolder/Camera") as Camera3D


func _set_cinematic_fov(fov: float, apply_to_player: bool = true) -> void :
	_cinematic_fov = clampf(fov, CINEMATIC_FOV_MIN, CINEMATIC_FOV_MAX)
	if _cinematic_fov_slider and not is_equal_approx(_cinematic_fov_slider.value, _cinematic_fov):
		_cinematic_fov_slider.value = _cinematic_fov
	if _cinematic_fov_label:
		_cinematic_fov_label.text = "FOV: %.0f" % _cinematic_fov
	if apply_to_player and _cinematic_active:
		var player: = _get_player()
		if player:
			player.set_debug_cinematic_fov(_cinematic_fov)


func _on_cinematic_fov_slider_changed(value: float) -> void :
	_set_cinematic_fov(value)


func _adjust_cinematic_fov(delta: float) -> void :
	_set_cinematic_fov(_cinematic_fov + delta)


func _on_cinematic_hands_toggled(on: bool) -> void :
	_cinematic_show_hands = on
	if not _cinematic_active:
		return
	var player: = _get_player()
	if player:
		player.set_weapon_active(on)


func _on_add_quest(qid: String) -> void :
	if not GameManager.has_quest(qid):
		GameManager.add_quest_by_id(qid)


func _on_complete_quest(qid: String) -> void :
	if GameManager.is_quest_completed(qid):
		return
	if not GameManager.has_active_quest(qid):
		GameManager.add_quest_by_id(qid)
	GameManager.complete_quest_by_id(qid)


func _on_reset_quest(qid: String) -> void :
	GameManager.reset_quest_by_id(qid)


func _on_give_item(item_id: String) -> void :
	GameManager.add_item(item_id, 1)


func _on_give_hk_materials() -> void :
	GameManager.add_item("kobber", 1)
	GameManager.add_item("plast", 1)
	GameManager.add_item("gummi", 1)


func _on_teleport(pos: Vector3) -> void :
	var player: Node3D = NetUtil.get_local_player() as Node3D
	if player != null:
		player.global_position = pos


func _on_complete_all_quests() -> void :
	for qid in QUEST_IDS:
		_on_complete_quest(qid)


func _on_reset_all() -> void :
	GameManager.reset_game()
	get_tree().change_scene_to_file("res://levels/main_demo.tscn")


func _on_change_scene(scene_path: String) -> void :
	get_tree().change_scene_to_file(scene_path)


func _spawn_minigame_overlay(scene_path: String) -> void :
	_toggle_menu()
	if not ResourceLoader.exists(scene_path):
		push_warning("[Debug] Mangler scene: %s" % scene_path)
		return
	var packed: = load(scene_path) as PackedScene
	if packed == null:
		return
	get_tree().current_scene.add_child(packed.instantiate())


func _spawn_lemonade() -> void :


	_toggle_menu()
	if GameManager:
		GameManager.inheritance_spent_on_non_ice_cream = true
	var packed: = load("res://scenes/props/lemonade_stand.tscn") as PackedScene
	if packed == null:
		return
	var stand: = packed.instantiate() as Node3D
	get_tree().current_scene.add_child(stand)
	var player: = _get_player()
	if player != null and stand != null:
		stand.global_position = player.global_position + player.global_transform.basis.z * -3.0


func _start_gorgon_horror() -> void :
	_toggle_menu()
	var horror: = get_tree().get_first_node_in_group("GorgonHorror")
	if horror != null and horror.has_method("activate"):
		horror.call("activate")
	else:
		push_warning("[Debug] GorgonHorror ikke funnet — vær i main_demo.")


func _on_strommast_drawing_taken() -> void :
	GameManager.kid_drawing_taken = true
	for node in get_tree().get_nodes_in_group("KidDrawing"):
		if is_instance_valid(node):
			node.queue_free()
	var mast: Node = get_tree().get_first_node_in_group("Strommast")
	if mast != null and mast.has_method("on_drawing_removed"):
		mast.on_drawing_removed()


func _on_radio_skip() -> void :
	var radio: Node = get_tree().get_first_node_in_group("Radio")
	if radio != null and radio.has_method("skip_to_next"):
		radio.skip_to_next()


func _on_flatten_kid() -> void :
	var kid: Node = get_tree().get_first_node_in_group("AnnoyingKid")
	if kid != null and kid.has_method("flatten"):
		kid.flatten()


func _process(_delta: float) -> void :
	if not OS.is_debug_build() and not REVIEW_MODE:
		return
	if _fps_label != null:
		_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	if _money_label != null:
		_money_label.text = "Penger: %d NOK" % GameManager.player_money
	if _inventory_label != null:
		_inventory_label.text = _format_inventory()
	for qid in QUEST_IDS:
		var lbl: Label = _quest_labels.get(qid) as Label
		if lbl == null:
			continue
		if GameManager.is_quest_completed(qid):
			lbl.modulate = Color.GREEN
		elif GameManager.has_active_quest(qid):
			lbl.modulate = Color.YELLOW
		else:
			lbl.modulate = Color.WHITE


func _format_inventory() -> String:
	if GameManager.inventory.is_empty():
		return "(tom)"
	var lines: PackedStringArray = PackedStringArray()
	for item_id in GameManager.inventory.keys():
		var entry: Variant = GameManager.inventory[item_id]
		var amount: int = int(entry.get("amount", 0)) if entry is Dictionary else 0
		if amount > 0:
			lines.append("%s x%d" % [item_id, amount])
	return "\n".join(lines) if lines.size() > 0 else "(tom)"


func _unhandled_input(event: InputEvent) -> void :
	if not OS.is_debug_build() and not REVIEW_MODE:
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F3:
		_toggle_cinematic()
		get_viewport().set_input_as_handled()
		return
	if _cinematic_active and (event.keycode == KEY_BRACKETLEFT or event.keycode == KEY_BRACKETRIGHT):
		var delta: = - CINEMATIC_FOV_STEP if event.keycode == KEY_BRACKETLEFT else CINEMATIC_FOV_STEP
		_adjust_cinematic_fov(delta)
		get_viewport().set_input_as_handled()
		return
	if event.keycode != KEY_F1 and event.keycode != KEY_QUOTELEFT:
		return
	_toggle_menu()
	get_viewport().set_input_as_handled()


func _toggle_menu() -> void :
	_menu_open = not _menu_open
	_debug_panel.visible = _menu_open
	if _menu_open:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		var player: Node = NetUtil.get_local_player()
		if player and player.has_method("should_use_fps_mouse_capture")\
		and player.should_use_fps_mouse_capture():
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
