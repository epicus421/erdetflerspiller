extends StaticBody3D

const SNAP_DISTANCE: = 1.5

var _powered: bool = false
var _snapping: bool = false
var _ghost_material: StandardMaterial3D = null


func _ready() -> void :
	add_to_group("PowerSocket")
	var plug_mesh: = get_node_or_null("PlugMesh") as Node3D
	if plug_mesh:
		plug_mesh.visible = false
	var label: = get_node_or_null("PromptLabel3D") as Label3D
	if label:
		label.hide()
	var area: = get_node_or_null("InteractionArea") as Area3D
	if area:
		area.monitoring = false
	_pulse_ghost()


func is_powered() -> bool:
	return _powered


func _physics_process(_delta: float) -> void :
	if _powered or _snapping:
		return
	var stoepsel: Node3D = get_tree().get_first_node_in_group("StoepselProp") as Node3D
	if stoepsel == null:
		return
	var dist: float = global_position.distance_to(stoepsel.global_position)
	if dist < SNAP_DISTANCE:
		_snap_stoepsel(stoepsel)


func _snap_stoepsel(stoepsel: Node3D) -> void :
	_snapping = true
	if stoepsel.has_method("force_drop"):
		stoepsel.force_drop()
	var snap_pos: Vector3 = global_position
	var snap_rot: Vector3 = global_rotation
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(stoepsel, "global_position", snap_pos, 0.3)
	tween.tween_property(stoepsel, "global_rotation", snap_rot, 0.3)
	await tween.finished
	if is_instance_valid(stoepsel):
		stoepsel.global_position = snap_pos
		stoepsel.global_rotation = snap_rot
	if stoepsel.has_method("lock_in_place"):
		stoepsel.lock_in_place()
	if has_node("PlugSound"):
		($PlugSound as AudioStreamPlayer3D).play()
	_plug_in()


func _plug_in() -> void :
	if _powered:
		return
	if not GameManager.hverdagskomiker_pending_power:
		_show_plug_blocked_dialogue()
		return
	_powered = true
	if MinigameManager:
		MinigameManager.deactivate_minigame()
	var ghost: = get_node_or_null("GhostMesh") as Node3D
	if ghost:
		ghost.visible = false
	var plug_mesh: = get_node_or_null("PlugMesh") as Node3D
	if plug_mesh:
		plug_mesh.visible = true
	_restore_power()


func _restore_power() -> void :
	if has_node("ElectricSound"):
		var electric: = $ElectricSound as AudioStreamPlayer3D
		if electric:
			electric.play()
	var tree: = get_tree()
	if tree == null:
		push_warning("[PowerSocket] Scene tree missing during power restore")
		return
	_flicker_scene_lights_safe(tree)
	await tree.create_timer(1.0).timeout
	if not is_instance_valid(self):
		return
	if GameManager.has_method("restore_scene_lights_after_power"):
		GameManager.restore_scene_lights_after_power()
	else:
		_turn_on_scene_lights_safe(tree)
	var door: Node = tree.get_first_node_in_group("KjiwiDoor")
	if door == null or not is_instance_valid(door):
		push_warning("[PowerSocket] KjiwiDoor not found")
	elif door.has_method("unlock"):
		door.unlock()


	_on_power_restored_dialogue_closed()


func _flicker_scene_lights_safe(tree: SceneTree) -> void :
	for light in tree.get_nodes_in_group("SceneLights"):
		if is_instance_valid(light) and light.has_method("flicker"):
			light.flicker()


func _turn_on_scene_lights_safe(tree: SceneTree) -> void :
	for light in tree.get_nodes_in_group("SceneLights"):
		if is_instance_valid(light) and light.has_method("turn_on"):
			light.turn_on()


func _show_plug_blocked_dialogue() -> void :
	if not DialogueUI:
		return
	var talked: bool = GameManager.has_talked_to_npc("hverdagskomiker")
	if not talked:
		DialogueUI.show_dialogue(
			[
				"Noe mangler...", 
				"Kanskje Hverdagskomikeren ved kraftstasjonen vet noe.", 
			], 
			"", 
			Callable()
		)
	else:
		DialogueUI.show_dialogue(["Du mangler materialer."], "", Callable())


func _on_power_restored_dialogue_closed() -> void :
	if not GameManager.hverdagskomiker_pending_power:
		_show_plug_blocked_dialogue()
		return
	GameManager.complete_quest_by_id("HVERDAGSKOMIKER")
	var tree: = get_tree()
	if tree == null:
		return
	var hk: Node = tree.get_first_node_in_group("Hverdagskomiker")
	if hk == null or not is_instance_valid(hk):
		push_warning("[PowerSocket] Hverdagskomiker not found")
	elif hk.has_method("start_dance"):
		hk.start_dance()


func _pulse_ghost() -> void :
	var ghost: = get_node_or_null("GhostMesh") as MeshInstance3D
	if ghost == null:
		return
	var base_mat: = ghost.get_surface_override_material(0) as StandardMaterial3D
	if base_mat == null:
		return
	_ghost_material = base_mat.duplicate() as StandardMaterial3D
	ghost.set_surface_override_material(0, _ghost_material)
	_ghost_material.albedo_color = Color(0.4, 0.7, 1.0, 0.35)
	var tween: Tween = create_tween()
	tween.set_loops()
	tween.tween_property(_ghost_material, "albedo_color:a", 0.1, 1.0)
	tween.tween_property(_ghost_material, "albedo_color:a", 0.5, 1.0)
