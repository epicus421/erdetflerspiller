extends Node3D

@export var open_distance: float = 3.0
@export var close_distance_buffer: float = 0.5
@export var slide_distance: float = 1.5
@export var slide_speed: float = 3.0
@export var open_sound: AudioStream = preload("res://assets/sfx/erdetlyd/splice/dooropenkjiwi.wav")
@export var close_sound: AudioStream = null

var _powered: bool = true
var _story_locked: bool = false
var _player_nearby: bool = false
var _want_open: bool = false
var _was_open: bool = false
var _door_left: Node3D = null
var _door_right: Node3D = null
var _left_closed_pos: Vector3 = Vector3.ZERO
var _right_closed_pos: Vector3 = Vector3.ZERO
var _left_open_pos: Vector3 = Vector3.ZERO
var _right_open_pos: Vector3 = Vector3.ZERO
var _door_sound: AudioStreamPlayer3D = null


func _ready() -> void :
	add_to_group("KjiwiDoor")
	_door_sound = get_node_or_null("DoorSound") as AudioStreamPlayer3D
	if _door_sound == null:
		_door_sound = AudioStreamPlayer3D.new()
		_door_sound.name = "DoorSound"
		add_child(_door_sound)
	_door_left = get_node_or_null("DoorLeft") as Node3D
	_door_right = get_node_or_null("DoorRight") as Node3D
	if _door_left != null:
		_left_closed_pos = _door_left.position
		_left_open_pos = _left_closed_pos + Vector3( - slide_distance, 0.0, 0.0)
	if _door_right != null:
		_right_closed_pos = _door_right.position
		_right_open_pos = _right_closed_pos + Vector3(slide_distance, 0.0, 0.0)
	_refresh_power_state()
	if not GameManager.quest_completed.is_connected(_on_quest_completed):
		GameManager.quest_completed.connect(_on_quest_completed)


func _refresh_power_state() -> void :
	var kris_done: bool = GameManager.is_quest_completed("KRIS_LUA")
	var hk_done: bool = GameManager.is_quest_completed("HVERDAGSKOMIKER")


	_story_locked = not GameManager.is_quest_completed("BANK_INHERITANCE")
	_powered = not _story_locked and not (kris_done and not hk_done)
	_update_sign_visibility()


func _on_quest_completed(quest_id: String) -> void :
	if quest_id == "HVERDAGSKOMIKER":
		unlock()
	elif quest_id == "KRIS_LUA" or quest_id == "BANK_INHERITANCE":
		_refresh_power_state()


func unlock() -> void :
	_powered = true
	_story_locked = false
	_update_sign_visibility()


func _physics_process(delta: float) -> void :
	var player: Node3D = NetUtil.get_local_player() as Node3D
	if player == null:
		return

	var dist: float = global_position.distance_to(player.global_position)
	_player_nearby = dist <= open_distance
	if dist <= open_distance:
		_want_open = true
	elif dist > open_distance + close_distance_buffer:
		_want_open = false
	var should_open: bool = _want_open and _powered
	if _door_left != null:
		var target_left: Vector3 = _left_open_pos if should_open else _left_closed_pos
		_door_left.position = _door_left.position.lerp(target_left, slide_speed * delta)
	if _door_right != null:
		var target_right: Vector3 = _right_open_pos if should_open else _right_closed_pos
		_door_right.position = _door_right.position.lerp(target_right, slide_speed * delta)
	_update_door_sound()
	_update_sign_visibility()
	if not _powered and _player_nearby:
		if GameManager.is_quest_completed("KRIS_LUA")\
		and not GameManager.has_quest("HVERDAGSKOMIKER"):
			GameManager.try_add_hverdagskomiker_quest()


func _update_sign_visibility() -> void :
	var sign: = get_node_or_null("SignLabel") as Label3D
	if sign == null:
		return
	sign.visible = not _powered and _player_nearby
	if sign.visible:
		sign.text = "STENGT" if _story_locked else "Ingen strøm\nMidlertidig stengt"


func _update_door_sound() -> void :
	if _door_sound == null:
		return
	if not _powered:
		_door_sound.stop()
		return

	var is_open: bool = _is_fully_open()
	var is_closed: bool = _is_fully_closed()

	if not _was_open and _want_open and not is_open:
		if open_sound != null and not _door_sound.playing:
			_door_sound.stream = open_sound
			_door_sound.play()
	elif _was_open and not _want_open and not is_closed:
		if close_sound != null and not _door_sound.playing:
			_door_sound.stream = close_sound
			_door_sound.play()
	elif (is_open or is_closed) and _door_sound.playing:
		_door_sound.stop()

	_was_open = _want_open


func _is_fully_open() -> bool:
	const EPS: = 0.02
	if _door_left != null:
		if _door_left.position.distance_to(_left_open_pos) > EPS:
			return false
	if _door_right != null:
		if _door_right.position.distance_to(_right_open_pos) > EPS:
			return false
	return true


func _is_fully_closed() -> bool:
	const EPS: = 0.02
	if _door_left != null:
		if _door_left.position.distance_to(_left_closed_pos) > EPS:
			return false
	if _door_right != null:
		if _door_right.position.distance_to(_right_closed_pos) > EPS:
			return false
	return true
