extends CharacterBody3D









enum State{ROAM, FLEE, KNOCKED, DEAD}

@export_category("Bevegelse")
@export var walk_speed: float = 1.8
@export var flee_speed: float = 6.5

@export var flee_calm_time: float = 6.0

@export var flee_distance: float = 14.0

@export_category("Lyd")

@export var hurt_sounds: Array[AudioStream] = []

@export var idle_sounds: Array[AudioStream] = []

@export var scream_sounds: Array[AudioStream] = []
@export var death_sound: AudioStream


@export var pitch_min: float = 0.8
@export var pitch_max: float = 1.6

@export_category("Velt")

@export var knockdown_time: float = 2.0


const KNOCK_SHAKE_STRENGTH: float = 0.26
const KNOCK_SHAKE_TIME: float = 0.25

@export_category("Død")

@export var death_cleanup_time: float = 6.0

const GRAVITY: float = 24.0
const ARRIVE_DIST: float = 1.2
const FLEE_RETARGET_INTERVAL: float = 0.6

const KNOCK_DISTANCE: float = 1.2


const KNOCK_MIN_SPEED: float = 3.0
const IDLE_SOUND_MIN: float = 8.0
const IDLE_SOUND_MAX: float = 20.0



const ACTIVE_RADIUS: float = 45.0


const BOB_AMPLITUDE: float = 0.3
const BOB_FREQUENCY: float = 4.8

@onready var _follow: FollowTarget3D = get_node_or_null("FollowTarget3D") as FollowTarget3D
@onready var _roam: Node = get_node_or_null("RandomTarget3D")
@onready var _health: HealthComponent = get_node_or_null("HealthComponent") as HealthComponent
@onready var _collision: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
@onready var _geometry: Node3D = get_node_or_null("Geometry") as Node3D
@onready var _anim: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer
@onready var _audio: AudioStreamPlayer3D = get_node_or_null("SFX") as AudioStreamPlayer3D
@onready var _thud: AudioStreamPlayer3D = get_node_or_null("ThudSFX") as AudioStreamPlayer3D

var _state: int = State.ROAM
var _roam_target: Vector3 = Vector3.ZERO
var _roam_idle: float = 0.0
var _flee_timer: float = 0.0
var _flee_retarget: float = 0.0
var _last_hurt_index: int = -1
var _last_scream_index: int = -1
var _geo_rest_y: float = 0.0
var _bob_phase: float = 0.0
var _knock_timer: float = 0.0

var _bus_shove: Vector3 = Vector3.ZERO
const BUS_SHOVE_FORCE: float = 9.0
var _idle_sound_timer: float = 0.0
var _base_collision_layer: int = 0


func _ready() -> void :




	add_to_group("NPC")
	add_to_group("Pedestrian")
	add_to_group("Enemies")
	_base_collision_layer = collision_layer
	if _geometry != null:
		_geo_rest_y = _geometry.position.y

	if _audio != null:
		_audio.pitch_scale = randf_range(pitch_min, pitch_max)
	_idle_sound_timer = randf_range(IDLE_SOUND_MIN, IDLE_SOUND_MAX)
	if _health != null:
		if not _health.on_death.is_connected(_on_death):
			_health.on_death.connect(_on_death)
		if not _health.on_damage_taken.is_connected(_on_damage_taken):
			_health.on_damage_taken.connect(_on_damage_taken)
	_pick_roam_target()


func _physics_process(delta: float) -> void :
	if _state == State.DEAD:
		return


	var player: = _get_player()
	if player != null and _flat_dist_to(player) > ACTIVE_RADIUS:
		return

	if _is_player_locked():
		velocity.x = 0.0
		velocity.z = 0.0
		_apply_gravity(delta)
		move_and_slide()
		return


	if _state == State.ROAM or _state == State.FLEE:
		_check_player_knockback()

	_apply_gravity(delta)
	match _state:
		State.ROAM:
			_tick_roam(delta)
			_tick_idle_sound(delta)
		State.FLEE:
			_tick_flee(delta)
		State.KNOCKED:
			_tick_knocked(delta)
	move_and_slide()
	_apply_bob(delta)




func _apply_bob(delta: float) -> void :

	if _geometry == null or _state == State.KNOCKED:
		return
	var speed: = Vector2(velocity.x, velocity.z).length()
	if speed > 0.2:
		_bob_phase += delta * speed * BOB_FREQUENCY
		_geometry.position.y = _geo_rest_y + absf(sin(_bob_phase)) * BOB_AMPLITUDE
	else:
		_geometry.position.y = lerpf(_geometry.position.y, _geo_rest_y, 10.0 * delta)


func _apply_gravity(delta: float) -> void :
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta


func _tick_roam(delta: float) -> void :

	if _roam_idle > 0.0:
		_roam_idle -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		return
	if _follow == null:
		return
	_follow.Speed = walk_speed
	if global_position.distance_to(_roam_target) <= ARRIVE_DIST:
		_pick_roam_target()
		_roam_idle = randf_range(0.8, 2.5)
		velocity.x = 0.0
		velocity.z = 0.0
		return
	_follow.tick_movement()


func _pick_roam_target() -> void :
	if _roam != null and _roam.has_method("GetNextPoint") and _follow != null:
		_roam_target = _roam.GetNextPoint()
		_follow.SetFixedTarget(_roam_target)


func _tick_flee(delta: float) -> void :
	_flee_timer -= delta
	if _flee_timer <= 0.0:
		_go_roam()
		return
	if _follow == null:
		return
	_follow.Speed = flee_speed


	_flee_retarget -= delta
	if _flee_retarget <= 0.0:
		_flee_retarget = FLEE_RETARGET_INTERVAL
		var player: = _get_player()
		if player != null:
			var away: Vector3 = global_position - player.global_position
			away.y = 0.0
			if away.length() < 0.1:
				away = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
			_follow.SetFixedTarget(global_position + away.normalized() * flee_distance)
	_follow.tick_movement()


func _go_roam() -> void :
	_state = State.ROAM
	_roam_idle = 0.0
	_pick_roam_target()


func _enter_flee() -> void :
	_flee_timer = flee_calm_time
	_flee_retarget = 0.0
	_state = State.FLEE




func _check_player_knockback() -> void :
	var player: = _get_player()
	if player == null:
		return
	if _flat_dist_to(player) > KNOCK_DISTANCE:
		return



	if not Input.is_action_pressed("run"):
		return
	var pv: = Vector2(player.velocity.x, player.velocity.z).length()
	if pv < KNOCK_MIN_SPEED:
		return
	_knock_down()
	_boost_player_after_rundown(player)






const RUNDOWN_BOOST_MULT: = 1.3
const RUNDOWN_BOOST_MAX_SPEED: = 14.0

func _boost_player_after_rundown(player: CharacterBody3D) -> void :
	var horiz: = Vector3(player.velocity.x, 0.0, player.velocity.z)
	var spd: = horiz.length()
	if spd < 0.1:
		return
	var new_spd: float = minf(spd * RUNDOWN_BOOST_MULT, RUNDOWN_BOOST_MAX_SPEED)
	if new_spd <= spd:
		return
	var boosted: = horiz * (new_spd / spd)
	player.velocity.x = boosted.x
	player.velocity.z = boosted.z



func hit_by_bus(damage: float, dir: Vector3) -> void :
	if _state == State.DEAD:
		return
	if _health != null and not _health.is_dead:
		_health.take_damage(damage)

	if _state == State.DEAD:
		return
	_bus_shove = Vector3(dir.x, 0.0, dir.z).normalized() * BUS_SHOVE_FORCE

	_state = State.ROAM
	_knock_down()


func _knock_down() -> void :
	if _state == State.KNOCKED or _state == State.DEAD:
		return
	_state = State.KNOCKED
	_knock_timer = knockdown_time
	velocity.x = 0.0
	velocity.z = 0.0

	if AchievementManager != null:
		AchievementManager.on_pedestrian_rundown()
	_play_sound(_random_hurt())

	_play_knock_impact()

	_set_body_collision(false)
	_topple(true)



func _play_knock_impact() -> void :
	if _thud != null:
		_thud.play()
	var cam_rig: Node = get_tree().get_first_node_in_group("PlayerCamera")
	if cam_rig != null and cam_rig.has_method("add_shake"):
		cam_rig.add_shake(KNOCK_SHAKE_STRENGTH, KNOCK_SHAKE_TIME)


func _tick_knocked(delta: float) -> void :

	if _bus_shove.length() > 0.1:
		velocity.x = _bus_shove.x
		velocity.z = _bus_shove.z
		_bus_shove = _bus_shove.lerp(Vector3.ZERO, 6.0 * delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	_knock_timer -= delta
	if _knock_timer <= 0.0:
		_topple(false)
		_set_body_collision(true)
		_go_roam()




func _topple(down: bool) -> void :
	if _geometry == null:
		return
	var tw: = create_tween()
	tw.tween_property(_geometry, "rotation_degrees:x", 86.0 if down else 0.0, 0.3)\
	.set_ease(Tween.EASE_OUT)






func _set_body_collision(enabled: bool) -> void :
	collision_layer = _base_collision_layer if enabled else 0


func _tick_idle_sound(delta: float) -> void :
	if idle_sounds.is_empty() or _audio == null:
		return
	_idle_sound_timer -= delta
	if _idle_sound_timer <= 0.0:
		_idle_sound_timer = randf_range(IDLE_SOUND_MIN, IDLE_SOUND_MAX)

		if not _audio.playing:
			_play_sound(idle_sounds[randi() % idle_sounds.size()])





func hitscanHit(damage: float, _dir: Vector3, _pos: Vector3) -> void :
	if _health != null and not _health.is_dead:
		_health.take_damage(damage)


func projectileHit(damage: float, _dir: Vector3) -> void :
	if _health != null and not _health.is_dead:
		_health.take_damage(damage)




func _on_damage_taken(current_health: float, _damage: float) -> void :
	if _state == State.DEAD:
		return


	if current_health <= 0.0:
		return

	if _state == State.KNOCKED:
		_play_sound(_random_hurt())
		return


	if _state == State.FLEE:
		_play_sound(_random_hurt())
	else:
		_play_sound(_random_scream())
	_enter_flee()


func _on_death() -> void :
	if _state == State.DEAD:
		return
	_state = State.DEAD
	velocity = Vector3.ZERO

	if GameManager != null and GameManager.has_signal("pedestrian_died"):
		GameManager.pedestrian_died.emit()


	_play_sound(death_sound if death_sound != null else _random_scream())


	remove_from_group("NPC")
	_set_body_collision(false)
	var hurt: = get_node_or_null("HurtBox") as Area3D
	if hurt != null:
		hurt.set_deferred("monitoring", false)
		hurt.set_deferred("monitorable", false)


	if _anim != null and _anim.has_animation("fall"):
		_anim.play("fall")
	elif _geometry != null:
		var tw: = create_tween()
		tw.tween_property(_geometry, "rotation_degrees:x", 85.0, 0.4)\
		.set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(death_cleanup_time).timeout
	if is_instance_valid(self):
		queue_free()




func _play_sound(s: AudioStream) -> void :
	if s != null and _audio != null:
		_audio.stream = s
		_audio.play()


func _random_hurt() -> AudioStream:
	_last_hurt_index = _pick_no_repeat(hurt_sounds, _last_hurt_index)
	return null if _last_hurt_index < 0 else hurt_sounds[_last_hurt_index]


func _random_scream() -> AudioStream:

	if scream_sounds.is_empty():
		return _random_hurt()
	_last_scream_index = _pick_no_repeat(scream_sounds, _last_scream_index)
	return null if _last_scream_index < 0 else scream_sounds[_last_scream_index]



func _pick_no_repeat(arr: Array, last: int) -> int:
	if arr.is_empty():
		return -1
	if arr.size() == 1:
		return 0
	var i: = last
	while i == last:
		i = randi() % arr.size()
	return i


func _get_player() -> Node3D:
	if GameManager != null and GameManager.has_method("get_player"):
		return GameManager.get_player() as Node3D
	return NetUtil.get_local_player() as Node3D



func _flat_dist_to(node: Node3D) -> float:
	var a: = global_position
	var b: = node.global_position
	return Vector2(a.x - b.x, a.z - b.z).length()



func _is_player_locked() -> bool:
	if DialogueUI != null and DialogueUI.has_method("is_open") and DialogueUI.is_open():
		return true
	if GameManager != null and GameManager.has_method("is_minigame_active")\
	and GameManager.is_minigame_active():
		return true
	return false
