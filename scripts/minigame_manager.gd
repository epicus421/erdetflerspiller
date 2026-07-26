extends Node

const STOEPSEL_SCENE: = preload("res://scenes/props/stoepsel_prop.tscn")

var _minigame_active: bool = false
var _stoepsel_start_pos: Vector3 = Vector3.ZERO
var _player_checkpoint: Vector3 = Vector3.ZERO
var _stoepsel: Node3D = null
var _respawning: bool = false


func _ready() -> void :
	add_to_group("MinigameManager")
	call_deferred("_find_checkpoint")


func _find_checkpoint() -> void :
	var marker: Node3D = get_tree().get_first_node_in_group("MinigameCheckpoint") as Node3D
	if marker:
		_player_checkpoint = marker.global_position


func register_stoepsel(node: Node3D) -> void :
	_stoepsel = node
	_stoepsel_start_pos = node.global_position
	if node.has_method("set_start_position"):
		node.set_start_position(_stoepsel_start_pos)
	_try_activate_minigame()


func spawn_stoepsel_at(world_pos: Vector3) -> Node3D:
	if _stoepsel != null and is_instance_valid(_stoepsel):
		_stoepsel.global_position = world_pos
		_stoepsel_start_pos = world_pos
		if _stoepsel.has_method("set_start_position"):
			_stoepsel.set_start_position(world_pos)
		_try_activate_minigame()
		return _stoepsel
	var prop: Node3D = STOEPSEL_SCENE.instantiate() as Node3D
	var parent: Node = get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	parent.add_child(prop)
	prop.global_position = world_pos
	_stoepsel_start_pos = world_pos
	register_stoepsel(prop)
	return prop


func _try_activate_minigame() -> void :
	if GameManager == null:
		return
	if not GameManager.has_active_quest("HVERDAGSKOMIKER"):
		return
	if not GameManager.hverdagskomiker_pending_power:
		return
	if _player_checkpoint == Vector3.ZERO:
		_find_checkpoint()
	_minigame_active = true


func deactivate_minigame() -> void :
	_minigame_active = false


func should_handle_death() -> bool:
	if not _minigame_active or _respawning:
		return false
	if _is_socket_powered():
		return false
	return _stoepsel != null and is_instance_valid(_stoepsel)


func handle_player_death(player: Node) -> void :
	if not should_handle_death():
		return
	_respawning = true
	_respawn_player(player)
	_respawn_stoepsel()
	_respawning = false


func _respawn_player(player: Node) -> void :
	if player == null:
		return
	if _player_checkpoint != Vector3.ZERO:
		(player as Node3D).global_position = _player_checkpoint
	var health: Node = player.get_node_or_null("HealthComponent")
	if health != null:
		if health.has_method("revive"):
			health.revive()
		elif health.has_method("heal"):
			health.is_dead = false
			health.heal(999.0)
	if player.has_method("freeze_for_dialogue"):
		player.freeze_for_dialogue(false)
	if player.has_method("set_weapon_active"):
		player.set_weapon_active(false)
	if player.has_method("_refresh_health_ui"):
		player._refresh_health_ui()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _respawn_stoepsel() -> void :
	if _stoepsel == null or not is_instance_valid(_stoepsel):
		return
	if _stoepsel.has_method("reset_to_start"):
		_stoepsel.reset_to_start()
	else:
		if _stoepsel.has_method("force_drop"):
			_stoepsel.force_drop()
		_stoepsel.global_position = _stoepsel_start_pos
		if _stoepsel is RigidBody3D:
			var body: = _stoepsel as RigidBody3D
			body.linear_velocity = Vector3.ZERO
			body.angular_velocity = Vector3.ZERO
			body.freeze = false


func _is_socket_powered() -> bool:
	var socket: Node = get_tree().get_first_node_in_group("PowerSocket")
	if socket != null and socket.has_method("is_powered"):
		return socket.is_powered()
	return false
