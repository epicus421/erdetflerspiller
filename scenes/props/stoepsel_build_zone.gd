extends Node3D

const STOESEL_PROP_SCENE_PATH: = "main_demo/NavigationRegion3D/PostVeien/StoepselProp"
const PATH3D_ROPE_SCENE_PATH: = "main_demo/NavigationRegion3D/PostVeien/Path3DRope"

var _player_in_range: bool = false
var _prompt_label: Label3D = null
var _built: bool = false
var _unlocked: bool = false


func _ready() -> void :
	var area: = get_node_or_null("InteractionArea") as Area3D
	if area:
		_setup_interaction_area(area)
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)
	var scene_label: = get_node_or_null("PromptLabel3D") as Label3D
	if scene_label:
		scene_label.visible = false
	_prompt_label = Label3D.new()
	_prompt_label.name = "PromptLabel"
	_prompt_label.text = "E — Bygg støpsel"
	_prompt_label.position = Vector3(0.0, 2.0, 0.0)
	_prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt_label.font_size = 32
	_prompt_label.pixel_size = 0.005
	_prompt_label.outline_size = 12
	_prompt_label.outline_modulate = Color(0, 0, 0, 1)
	_prompt_label.no_depth_test = true
	_prompt_label.visible = false
	add_child(_prompt_label)
	var built_mesh: = get_node_or_null("BuiltPlugMesh") as Node3D
	if built_mesh:
		built_mesh.visible = false
	var stoepsel: = _find_stoepsel_prop()
	if stoepsel != null and stoepsel.visible:
		_built = true
		call_deferred("_remove_build_zone")
		return
	_set_zone_active(false)
	if GameManager:
		if not GameManager.quest_progress_updated.is_connected(_on_quest_progress_updated):
			GameManager.quest_progress_updated.connect(_on_quest_progress_updated)
		if not GameManager.quest_changed.is_connected(_on_quest_changed):
			GameManager.quest_changed.connect(_on_quest_changed)
	call_deferred("_sync_unlock_state")


func _exit_tree() -> void :
	if GameManager == null:
		return
	if GameManager.quest_progress_updated.is_connected(_on_quest_progress_updated):
		GameManager.quest_progress_updated.disconnect(_on_quest_progress_updated)
	if GameManager.quest_changed.is_connected(_on_quest_changed):
		GameManager.quest_changed.disconnect(_on_quest_changed)


func _on_quest_progress_updated(_quest_id: String, _progress: int) -> void :
	_sync_unlock_state()


func _on_quest_changed(_quest_id: String, _state: int) -> void :
	_sync_unlock_state()


func _sync_unlock_state() -> void :
	if _built:
		return
	var should_unlock: bool = _has_talked_to_hverdagskomiker()
	if should_unlock == _unlocked:
		return
	_unlocked = should_unlock
	if _unlocked:
		_set_zone_active(true)
	else:
		_set_zone_active(false)


func _has_talked_to_hverdagskomiker() -> bool:
	if GameManager == null:
		return false
	return GameManager.has_talked_to_npc("hverdagskomiker")


func _set_zone_active(active: bool) -> void :
	visible = active
	set_process_unhandled_input(active)
	var area: = get_node_or_null("InteractionArea") as Area3D
	if area:
		area.monitoring = active
	if not active:
		_player_in_range = false
		if _prompt_label:
			_prompt_label.visible = false


func _setup_interaction_area(area: Area3D) -> void :
	area.monitoring = true
	area.set_collision_mask_value(1, true)
	area.set_collision_mask_value(2, true)


func _on_body_entered(body: Node3D) -> void :
	if not _unlocked or not body.is_in_group("PlayerCharacter"):
		return
	_player_in_range = true
	_update_prompt_label()
	if _prompt_label:
		_prompt_label.visible = true


func _on_body_exited(body: Node3D) -> void :
	if not body.is_in_group("PlayerCharacter"):
		return
	_player_in_range = false
	if _prompt_label:
		_prompt_label.visible = false


func _update_prompt_label() -> void :
	if _prompt_label == null:
		return
	var has_kobber: bool = GameManager.has_item("kobber")
	var has_plast: bool = GameManager.has_item("plast")
	var has_gummi: bool = GameManager.has_item("gummi")
	if has_kobber and has_plast and has_gummi:
		_prompt_label.text = "E — Bygg støpsel"
	else:
		var missing: Array[String] = []
		if not has_kobber:
			missing.append("kobber")
		if not has_plast:
			missing.append("plast")
		if not has_gummi:
			missing.append("gummi")
		_prompt_label.text = "Mangler: " + ", ".join(missing)


func _unhandled_input(_event: InputEvent) -> void :
	if not _unlocked or not _player_in_range:
		return
	if not Input.is_action_just_pressed("interaction"):
		return
	if _has_stoepsel_prop():
		DialogueUI.show_dialogue(
			["Du har allerede laget støpselen."], 
			"Byggeplass", 
			Callable()
		)
		return
	_try_craft()


func _has_stoepsel_prop() -> bool:
	if _built:
		return true
	var stoepsel: = _find_stoepsel_prop()
	return stoepsel != null and stoepsel.visible


func _find_path3d_rope() -> Node:
	var rope: Node = get_tree().get_first_node_in_group("Path3DRope")
	if rope == null:
		rope = get_tree().root.get_node_or_null(PATH3D_ROPE_SCENE_PATH)
	return rope


func _find_stoepsel_prop() -> Node:
	var stoepsel: Node = get_tree().get_first_node_in_group("StoepselProp")
	if stoepsel == null:
		stoepsel = get_tree().root.get_node_or_null(STOESEL_PROP_SCENE_PATH)
	return stoepsel


func _unhide_craft_node(node: Node) -> void :
	if node == null:
		return
	node.visible = true
	node.process_mode = Node.PROCESS_MODE_INHERIT


func _try_craft() -> void :
	if not _unlocked:
		return
	var has_kobber: bool = GameManager.has_item("kobber")
	var has_plast: bool = GameManager.has_item("plast")
	var has_gummi: bool = GameManager.has_item("gummi")
	if not has_kobber or not has_plast or not has_gummi:
		var missing: Array[String] = []
		if not has_kobber:
			missing.append("kobberledning")
		if not has_plast:
			missing.append("plast")
		if not has_gummi:
			missing.append("gummi")
		DialogueUI.show_dialogue(
			["Du mangler: " + ", ".join(missing) + "."], 
			"Byggeplass", 
			Callable()
		)
		return
	GameManager.remove_item("kobber", 1)
	GameManager.remove_item("plast", 1)
	GameManager.remove_item("gummi", 1)
	var rope: Node = _find_path3d_rope()
	var stoepsel: Node = _find_stoepsel_prop()
	_unhide_craft_node(rope)
	_unhide_craft_node(stoepsel)
	if rope == null and stoepsel == null:
		push_warning("BuildZone: Could not find Path3DRope or StoepselProp")
		return
	if stoepsel is Node3D and MinigameManager:
		MinigameManager.register_stoepsel(stoepsel as Node3D)
	_hide_builder_mesh()
	_built = true
	_player_in_range = false
	set_process_unhandled_input(false)
	var area: = get_node_or_null("InteractionArea") as Area3D
	if area:
		area.monitoring = false
	DialogueUI.show_dialogue(
		[
			"Du bygget støpselen.", 
			"Plukk den opp og sett den i veggen.", 
		], 
		"Byggeplass", 
		Callable()
	)
	GameManager.set_quest_hint("HVERDAGSKOMIKER", "Sett støpselen i veggen")
	call_deferred("_remove_build_zone")


func _hide_builder_mesh() -> void :
	for node_name in ["BuiltPlugMesh", "Byggermesh", "plugbase"]:
		var mesh_node: = get_node_or_null(node_name) as Node3D
		if mesh_node:
			mesh_node.visible = false


func _remove_build_zone() -> void :
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_player_in_range = false
	set_process_unhandled_input(false)
	var area: = get_node_or_null("InteractionArea") as Area3D
	if area:
		if area.body_entered.is_connected(_on_body_entered):
			area.body_entered.disconnect(_on_body_entered)
		if area.body_exited.is_connected(_on_body_exited):
			area.body_exited.disconnect(_on_body_exited)
		area.monitoring = false
	if _prompt_label and is_instance_valid(_prompt_label):
		_prompt_label.visible = false
	queue_free()
