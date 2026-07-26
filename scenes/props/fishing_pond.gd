extends Node3D

const DETONATOR_SCENE: PackedScene = preload("res://scenes/minigames/detonator.tscn")
const FISH_MODEL: PackedScene = preload("res://assets/props/glb/falke/Fisky1.glb")
const DYNAMITE_MODEL: PackedScene = preload("res://assets/props/glb/falke/Dynamit.glb")
const EXPLOSION_VFX: PackedScene = preload("res://addons/fpstemplate/Misc/Scenes/ParticlesManagerScene.tscn")
const LOOT_LAUNCH_FORCE: = 8.0
const LOOT_SPREAD: = 2.0

var _player_in_range: bool = false
var _detonation_active: bool = false
var _already_detonated: bool = false

func _ready() -> void :
	var area: = get_node_or_null("InteractionArea") as Area3D
	if area:
		_setup_interaction_area(area)
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)
	var label: = get_node_or_null("PromptLabel3D") as Label3D
	if label:
		label.no_depth_test = true
		label.hide()
	_resync_plast_hint.call_deferred()



func _resync_plast_hint() -> void :
	if GameManager == null or _already_detonated:
		return
	if GameManager.has_item("plast"):
		return
	if GameManager.has_item("tnt"):
		GameManager.set_objective_hint(
			"HVERDAGSKOMIKER", "collect_plast", "Tilbake til dammen"
		)

func _setup_interaction_area(area: Area3D) -> void :
	area.monitoring = true
	area.set_collision_mask_value(1, true)
	area.set_collision_mask_value(2, true)

func _on_body_entered(body: Node3D) -> void :
	if body.is_in_group("PlayerCharacter"):
		_player_in_range = true
		var label: = get_node_or_null("PromptLabel3D") as Label3D
		if label:
			label.text = "E — Spreng"
			label.show()

func _on_body_exited(body: Node3D) -> void :
	if body.is_in_group("PlayerCharacter"):
		_player_in_range = false
		var label: = get_node_or_null("PromptLabel3D") as Label3D
		if label:
			label.hide()

func _unhandled_input(_event: InputEvent) -> void :
	if _already_detonated:
		return
	if not Input.is_action_just_pressed("interaction"):
		return
	if DialogueUI and DialogueUI.is_open():
		return
	if not _player_in_range or _detonation_active:
		return
	if not GameManager.has_item("tnt"):
		DialogueUI.show_dialogue(["Du trenger dynamitt og detonator."], "", Callable())


		GameManager.set_objective_hint(
			"HVERDAGSKOMIKER", "collect_plast", 
			"Finn dynamitt og detonator ved Kratergata"
		)
		return
	_start_detonation()

var _tnt_prop: Node3D = null

func _start_detonation() -> void :
	_detonation_active = true
	_tnt_prop = _spawn_tnt_prop()
	var det: Node = DETONATOR_SCENE.instantiate()
	get_tree().root.add_child(det)
	if det.has_signal("detonation_complete"):
		det.detonation_complete.connect(_on_detonation_complete, CONNECT_ONE_SHOT)

func _on_detonation_complete() -> void :
	_detonation_active = false
	_already_detonated = true

	if AchievementManager != null:
		AchievementManager.unlock(AchievementManager.ACH_FISH)
	GameManager.remove_item("tnt", 1)
	if _tnt_prop != null and is_instance_valid(_tnt_prop):
		_tnt_prop.queue_free()
		_tnt_prop = null
	_spawn_explosion_vfx()
	_spawn_loot()
	_spawn_plast_pickup()
	GameManager.set_objective_hint(
		"HVERDAGSKOMIKER", "collect_plast", "Plukk opp plasten ved dammen"
	)

	var area: = get_node_or_null("InteractionArea") as Area3D
	if area:
		area.monitoring = false
	var label: = get_node_or_null("PromptLabel3D") as Label3D
	if label:
		label.hide()

func _spawn_loot() -> void :
	var spawn_pos: = global_position + Vector3(0, 1.0, 0)
	for i in range(5):
		_spawn_fish(spawn_pos)

const PLAST_PICKUP_SCRIPT: Script = preload("res://scenes/props/plast_world_pickup.gd")

func _spawn_plast_pickup() -> void :

	var body: = RigidBody3D.new()
	body.set_script(PLAST_PICKUP_SCRIPT)
	var root: = get_tree().current_scene
	if root == null:
		root = get_tree().root
	root.add_child(body)
	body.global_position = global_position + Vector3(0, 1.0, 0)
	body.linear_velocity = Vector3(
		randf_range(-2.0, 2.0), 
		LOOT_LAUNCH_FORCE + randf_range(0, 3.0), 
		randf_range(-2.0, 2.0)
	)
	body.angular_velocity = Vector3(
		randf_range(-5.0, 5.0), 
		randf_range(-5.0, 5.0), 
		randf_range(-5.0, 5.0)
	)

func _spawn_fish(origin: Vector3) -> void :
	var body: = RigidBody3D.new()
	var model: = FISH_MODEL.instantiate()
	model.scale = Vector3(0.23, 0.23, 0.23)
	body.add_child(model)
	var col: = CollisionShape3D.new()
	var shape: = BoxShape3D.new()
	shape.size = Vector3(0.2, 0.1, 0.4)
	col.shape = shape
	body.add_child(col)
	var root: = get_tree().current_scene
	if root == null:
		root = get_tree().root
	root.add_child(body)
	var offset: = Vector3(
		randf_range( - LOOT_SPREAD, LOOT_SPREAD), 
		0, 
		randf_range( - LOOT_SPREAD, LOOT_SPREAD)
	)
	body.global_position = origin + offset
	body.linear_velocity = Vector3(
		randf_range(-2.0, 2.0), 
		LOOT_LAUNCH_FORCE + randf_range(0, 3.0), 
		randf_range(-2.0, 2.0)
	)
	body.angular_velocity = Vector3(
		randf_range(-5.0, 5.0), 
		randf_range(-5.0, 5.0), 
		randf_range(-5.0, 5.0)
	)
	get_tree().create_timer(15.0).timeout.connect( func():
		if is_instance_valid(body):
			body.queue_free()
	)


func _spawn_explosion_vfx() -> void :
	var vfx: = EXPLOSION_VFX.instantiate()
	vfx.particleToEmit = "Explosion"
	get_tree().root.add_child(vfx)
	vfx.global_position = global_position
	SfxManager.play("explosion")


func _spawn_tnt_prop() -> Node3D:
	var model: = DYNAMITE_MODEL.instantiate()
	model.name = "TNTProp"
	var scene_root: = get_tree().current_scene
	if scene_root == null:
		scene_root = get_tree().root
	scene_root.add_child(model)
	model.global_position = global_position + Vector3(1.5, 0, 0)
	return model
