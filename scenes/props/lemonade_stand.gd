extends Node3D

@export var ghost_preview: bool = false


@export var start_built: bool = false

@onready var sign_mesh: MeshInstance3D = $SignMesh
@onready var sit_point: Marker3D = $SitPoint
@onready var prompt_label: Label3D = $PromptLabel3D

const ICE_CREAM_PRICE: int = 100
const SIGN_DRAWING_SCENE: PackedScene = preload("res://scenes/minigames/sign_drawing.tscn")
const RABBIT_TEXTURE: Texture2D = preload("res://assets/textures/images/rabbit.png")

const CUPS_TO_SERVE: int = 3

const WOOD_ID: String = "wood_scrap"
const WOOD_COST: int = 2
const POUR_RATE_BASE: float = 0.65
const POUR_RATE_RAMP: float = 0.2
const CUSTOMER_WALK_SPEED: float = 5.0

signal _pour_finished(result: String)

var _player_near_sit: bool = false
var _player_near_sign: bool = false
var _built: bool = false
var _sign_drawn: bool = false
var _working: bool = false
var _stand_used: bool = false
var _player: Node = null
var _pour_active: bool = false
var _pouring: bool = false
var _pour_fill: float = 0.0
var _pour_rate: float = POUR_RATE_BASE
var _sweet_start: float = 0.72
var _sweet_end: float = 0.92
var _service_canvas: CanvasLayer = null
var _meter: PourMeter = null
var _status_label: Label = null
var _cups_label: Label = null


func _ready() -> void :
	if ghost_preview:
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		set_process_unhandled_input(false)
		prompt_label.hide()
		if has_node("InteractionArea"):
			$InteractionArea.monitoring = false
			$InteractionArea.monitorable = false
		return
	if not _is_stand_allowed():
		_disable_stand_for_wrong_inheritance()
		return
	_built = start_built
	$InteractionArea.set_collision_mask_value(1, true)
	$InteractionArea.set_collision_mask_value(2, true)
	$InteractionArea.monitoring = true
	$InteractionArea.body_entered.connect(_on_sit_entered)
	$InteractionArea.body_exited.connect(_on_sit_exited)
	$SignInteractionArea.set_collision_mask_value(1, true)
	$SignInteractionArea.set_collision_mask_value(2, true)
	$SignInteractionArea.monitoring = true
	$SignInteractionArea.body_entered.connect(_on_sign_entered)
	$SignInteractionArea.body_exited.connect(_on_sign_exited)
	set_process_unhandled_input(true)
	prompt_label.hide()



	_prime_player_proximity.call_deferred()


func _prime_player_proximity() -> void :
	await get_tree().physics_frame
	var player: = NetUtil.get_local_player()
	if player == null or not (player is Node3D):
		return
	if $InteractionArea.overlaps_body(player):
		_player_near_sit = true
	if $SignInteractionArea.overlaps_body(player):
		_player_near_sign = true
	_refresh_prompt()


func _is_stand_allowed() -> bool:
	return GameManager != null and GameManager.inheritance_spent_on_non_ice_cream


func _disable_stand_for_wrong_inheritance() -> void :
	visible = false
	set_process(false)
	set_physics_process(false)
	set_process_unhandled_input(false)
	if has_node("InteractionArea"):
		$InteractionArea.monitoring = false
		$InteractionArea.monitorable = false
	prompt_label.hide()


func _unhandled_input(_event: InputEvent) -> void :
	if ghost_preview or not _is_stand_allowed():
		return
	if not Input.is_action_just_pressed("interaction"):
		return
	if DialogueUI.is_open() or _working or _stand_used:
		return
	if GameManager.is_minigame_active():
		return

	if not _built:
		if _player_near_sign or _player_near_sit:
			_try_build()
		return
	if _player_near_sign and not _sign_drawn:
		_draw_sign()
	elif _player_near_sit and _sign_drawn:
		_start_working()


func _try_build() -> void :
	if GameManager.get_item_count(WOOD_ID) < WOOD_COST:
		DialogueUI.show_dialogue(
			["Du trenger 2 treverk for å bygge lemonadeboden."], 
			"Lemonadebod", 
			Callable()
		)
		return
	GameManager.remove_item(WOOD_ID, WOOD_COST)
	_built = true
	SfxManager.play("item_added")
	_refresh_prompt()


func _draw_sign() -> void :
	if not GameManager.start_minigame("sign_drawing"):
		return
	prompt_label.hide()
	var minigame: = SIGN_DRAWING_SCENE.instantiate()
	minigame.sign_finished.connect(_on_sign_drawn)
	minigame.tree_exited.connect(_on_sign_minigame_closed)
	get_tree().root.add_child(minigame)


func _on_sign_drawn(texture: ImageTexture) -> void :
	_sign_drawn = true
	var mat: = StandardMaterial3D.new()
	mat.albedo_texture = texture
	sign_mesh.material_override = mat


func _on_sign_minigame_closed() -> void :
	GameManager.end_minigame("sign_drawing", 1 if _sign_drawn else 0)
	var player: Node = NetUtil.get_local_player()
	if player and player.has_method("should_use_fps_mouse_capture") and player.should_use_fps_mouse_capture():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_refresh_prompt()


func _start_working() -> void :
	_player = NetUtil.get_local_player()
	if _player == null:
		return
	_working = true
	if _player.has_method("_drop_carried_object"):
		_player.call("_drop_carried_object")
	if _player is Node3D:
		(_player as Node3D).global_position = sit_point.global_position
	if _player.has_method("sit_at_stand"):
		_player.sit_at_stand(true)
	elif _player.has_method("set_sitting_at_stand"):
		_player.set_sitting_at_stand(true)
	elif _player.has_method("freeze_for_dialogue"):
		_player.freeze_for_dialogue(true)
	else:
		if "movement_frozen" in _player:
			_player.movement_frozen = true
		if "camera_frozen" in _player:
			_player.camera_frozen = true
	if _player.has_method("set_weapon_active"):
		_player.set_weapon_active(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	prompt_label.hide()
	_begin_service()


func _begin_service() -> void :
	GameManager.start_minigame("lemonade_pour")



	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_create_service_ui()
	var served: int = 0
	var from_left: bool = randf() < 0.5
	while served < CUPS_TO_SERVE:
		_set_cups_label(served)
		_set_status("Kunde på vei...")
		var rabbit: = _spawn_customer(from_left)
		from_left = not from_left
		await _walk_customer(rabbit, $CustomerCounterSpot.global_position)
		_set_status("Hold venstre musetast / A for å helle")
		var result: String = await _pour_cup(served)
		if result == "served":
			served += 1
			_set_cups_label(served)
			SfxManager.play("item_added")
			_set_status("Perfekt!")
			_send_customer_away(rabbit, false)
		else:
			SfxManager.play("item_removed")
			_set_status("Du sølte! Kaninen hopper hjem.")
			_send_customer_away(rabbit, true)
		await get_tree().create_timer(0.8).timeout
	_finish_service()


func _pour_cup(served: int) -> String:
	_pour_rate = POUR_RATE_BASE + POUR_RATE_RAMP * served
	var zone_width: float = randf_range(0.08, 0.13)
	_sweet_start = randf_range(0.45, 0.94 - zone_width)
	_sweet_end = _sweet_start + zone_width
	_pour_fill = 0.0
	_pouring = false
	if _meter != null:
		_meter.sweet_start = _sweet_start
		_meter.sweet_end = _sweet_end
		_meter.fill = 0.0
		_meter.queue_redraw()
	_pour_active = true
	var result: String = await _pour_finished
	_pour_active = false
	_pouring = false
	return result


func _input(event: InputEvent) -> void :
	if not _pour_active:
		return

	var pressed: bool
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = event.pressed
	elif event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A:
		pressed = event.pressed
	else:
		return
	if pressed:
		_pouring = true
	else:
		_pouring = false
		if _pour_fill >= _sweet_start and _pour_fill <= _sweet_end:
			_pour_finished.emit("served")
		elif _pour_fill > _sweet_end:
			_pour_finished.emit("spilled")
		else:
			_pour_fill = 0.0
			if _meter != null:
				_meter.fill = 0.0
				_meter.queue_redraw()
			_set_status("For lite! Prøv igjen.")
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void :
	if not _pour_active or not _pouring:
		return
	_pour_fill += _pour_rate * delta
	if _pour_fill >= 1.0:
		_pour_fill = 1.0
		_pouring = false
		if _meter != null:
			_meter.fill = 1.0
			_meter.queue_redraw()
		_pour_finished.emit("spilled")
		return
	if _meter != null:
		_meter.fill = _pour_fill
		_meter.queue_redraw()


func _spawn_customer(from_left: bool) -> Node3D:
	var rabbit: = Node3D.new()
	rabbit.name = "LemonadeCustomer"
	var sprite: = Sprite3D.new()
	sprite.name = "Sprite3D"
	sprite.texture = RABBIT_TEXTURE
	sprite.pixel_size = 0.003
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.position.y = 0.5
	rabbit.add_child(sprite)
	add_child(rabbit)
	var spawn: Marker3D = $CustomerSpawnLeft if from_left else $CustomerSpawnRight
	rabbit.global_position = spawn.global_position
	rabbit.set_meta("from_left", from_left)
	return rabbit


func _walk_customer(rabbit: Node3D, target: Vector3) -> void :
	var sprite: = rabbit.get_node_or_null("Sprite3D") as Sprite3D
	var hop: Tween = null
	if sprite != null:
		hop = rabbit.create_tween().set_loops()
		hop.tween_property(sprite, "position:y", 0.78, 0.22)
		hop.tween_property(sprite, "position:y", 0.5, 0.22)
	var dist: float = rabbit.global_position.distance_to(target)
	var tw: = rabbit.create_tween()
	tw.tween_property(rabbit, "global_position", target, dist / CUSTOMER_WALK_SPEED)
	await tw.finished
	if hop != null:
		hop.kill()
	if sprite != null:
		sprite.position.y = 0.5


func _send_customer_away(rabbit: Node3D, upset: bool) -> void :
	if rabbit == null or not is_instance_valid(rabbit):
		return
	var sprite: = rabbit.get_node_or_null("Sprite3D") as Sprite3D
	if upset and sprite != null:
		sprite.modulate = Color(1.0, 0.55, 0.55)
	var from_left: bool = bool(rabbit.get_meta("from_left", true))
	var exit_marker: Marker3D = $CustomerSpawnLeft if from_left else $CustomerSpawnRight
	var speed: float = CUSTOMER_WALK_SPEED * (1.6 if upset else 1.0)
	var dist: float = rabbit.global_position.distance_to(exit_marker.global_position)
	if sprite != null:
		var hop: = rabbit.create_tween().set_loops()
		hop.tween_property(sprite, "position:y", 0.78, 0.18 if upset else 0.22)
		hop.tween_property(sprite, "position:y", 0.5, 0.18 if upset else 0.22)
	var tw: = rabbit.create_tween()
	tw.tween_property(rabbit, "global_position", exit_marker.global_position, dist / speed)
	tw.tween_callback(rabbit.queue_free)


func _create_service_ui() -> void :
	_service_canvas = CanvasLayer.new()
	_service_canvas.layer = 60
	var root: = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_service_canvas.add_child(root)

	_meter = PourMeter.new()
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter.anchor_left = 1.0
	_meter.anchor_right = 1.0
	_meter.anchor_top = 0.5
	_meter.anchor_bottom = 0.5
	_meter.offset_left = -84.0
	_meter.offset_right = -32.0
	_meter.offset_top = -120.0
	_meter.offset_bottom = 120.0
	root.add_child(_meter)

	_cups_label = _make_service_label(20)
	_cups_label.anchor_right = 1.0
	_cups_label.offset_top = 16.0
	_cups_label.offset_bottom = 44.0
	root.add_child(_cups_label)

	_status_label = _make_service_label(16)
	_status_label.anchor_top = 1.0
	_status_label.anchor_bottom = 1.0
	_status_label.anchor_right = 1.0
	_status_label.offset_top = -64.0
	_status_label.offset_bottom = -32.0
	root.add_child(_status_label)

	get_tree().root.add_child(_service_canvas)


func _make_service_label(font_size: int) -> Label:
	var lbl: = Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 8)
	return lbl


func _set_status(text: String) -> void :
	if _status_label != null and is_instance_valid(_status_label):
		_status_label.text = text


func _set_cups_label(served: int) -> void :
	if _cups_label != null and is_instance_valid(_cups_label):
		_cups_label.text = "Lemonade: %d/%d" % [served, CUPS_TO_SERVE]


func _finish_service() -> void :

	if AchievementManager != null:
		AchievementManager.unlock(AchievementManager.ACH_LIMONADE)
	if _service_canvas != null and is_instance_valid(_service_canvas):
		_service_canvas.queue_free()
	_service_canvas = null
	_meter = null
	_status_label = null
	_cups_label = null

	var award: int = maxi(0, ICE_CREAM_PRICE - GameManager.player_money)
	if award > 0:
		GameManager.add_flat_money_reward(award, true)

	_stand_used = true
	_working = false
	GameManager.end_minigame("lemonade_pour", CUPS_TO_SERVE)
	_stand_up_player()
	DialogueUI.show_dialogue(
		["Du tjente %d kr på lemonadestanden!" % award], 
		"Lemonadebod", 
		Callable()
	)
	_refresh_prompt()


func _stand_up_player() -> void :
	var player: Node = NetUtil.get_local_player()
	if player == null:
		return
	if player.has_method("sit_at_stand"):
		player.sit_at_stand(false)
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity = Vector3(0.0, 0.5, 0.0)
	elif player.has_method("set_sitting_at_stand"):
		player.set_sitting_at_stand(false)
	elif player.has_method("freeze_for_dialogue"):
		player.freeze_for_dialogue(false)
	else:
		if "movement_frozen" in player:
			player.movement_frozen = false
		if "camera_frozen" in player:
			player.camera_frozen = false
	if player.has_method("set_weapon_active"):
		player.set_weapon_active(true)
	if player.has_method("should_use_fps_mouse_capture") and player.should_use_fps_mouse_capture():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _refresh_prompt() -> void :
	if _stand_used:
		if _player_near_sit or _player_near_sign:
			prompt_label.text = "Markedet er mettet."
			prompt_label.show()
		else:
			prompt_label.hide()
		return
	if not _built:
		if _player_near_sign or _player_near_sit:
			prompt_label.text = "E — Bygg lemonadebod (2 treverk)"
			prompt_label.show()
		else:
			prompt_label.hide()
		return
	if _player_near_sign and not _sign_drawn:
		prompt_label.text = "E — Tegn skilt"
		prompt_label.show()
	elif _player_near_sit and _sign_drawn:
		prompt_label.text = "E — Sett deg"
		prompt_label.show()
	else:
		prompt_label.hide()


func _on_sit_entered(body: Node3D) -> void :
	if not _is_stand_allowed():
		return
	if body.is_in_group("PlayerCharacter"):
		_player_near_sit = true
		_refresh_prompt()


func _on_sit_exited(body: Node3D) -> void :
	if body.is_in_group("PlayerCharacter"):
		_player_near_sit = false
		_refresh_prompt()


func _on_sign_entered(body: Node3D) -> void :
	if not _is_stand_allowed():
		return
	if body.is_in_group("PlayerCharacter"):
		_player_near_sign = true
		_refresh_prompt()


func _on_sign_exited(body: Node3D) -> void :
	if body.is_in_group("PlayerCharacter"):
		_player_near_sign = false
		_refresh_prompt()


class PourMeter extends Control:
	var fill: float = 0.0
	var sweet_start: float = 0.72
	var sweet_end: float = 0.92

	func _draw() -> void :
		var w: float = size.x
		var h: float = size.y
		draw_rect(Rect2(0.0, 0.0, w, h), Color(0.06, 0.06, 0.09, 0.85), true)
		var fill_h: float = h * clampf(fill, 0.0, 1.0)
		draw_rect(Rect2(3.0, h - fill_h, w - 6.0, fill_h), Color(0.95, 0.85, 0.25, 0.95), true)
		var sweet_top: float = h * (1.0 - sweet_end)
		var sweet_h: float = h * (sweet_end - sweet_start)
		draw_rect(Rect2(0.0, sweet_top, w, sweet_h), Color(0.15, 0.8, 0.25, 0.35), true)
		draw_line(Vector2(0.0, sweet_top), Vector2(w, sweet_top), Color(0.9, 0.2, 0.2, 1.0), 2.0)
		draw_rect(Rect2(0.0, 0.0, w, h), Color(1, 1, 1, 0.9), false, 2.0)
