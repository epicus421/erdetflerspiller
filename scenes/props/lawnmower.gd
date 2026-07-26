extends CharacterBody3D














enum State{RUNNING, PAUSED, DEAD}

@export_category("Kjøring")
@export var drive_speed: float = 2.2

@export var min_pause: float = 1.5
@export var max_pause: float = 5.0

@export var max_turn: float = PI

@export var turn_time: float = 0.6

@export_category("Død")


@export var max_health: float = 60.0
@export var death_sound: AudioStream

const GRAVITY: float = 24.0
const EXPLOSION_VFX: PackedScene = preload("res://addons/fpstemplate/Misc/Scenes/ParticlesManagerScene.tscn")

const EXPLOSION_LIFETIME: float = 2.0

@onready var _engine: AudioStreamPlayer3D = get_node_or_null("EngineActiveSfx") as AudioStreamPlayer3D
@onready var _health: HealthComponent = get_node_or_null("HealthComponent") as HealthComponent

var _state: int = State.RUNNING


func _ready() -> void :


	add_to_group("NPC")
	add_to_group("Enemies")



	collision_layer = 32
	collision_mask = 31


	if _health == null:
		for c in get_children():
			if c is HealthComponent:
				_health = c as HealthComponent
				break
	if _health == null:
		_health = HealthComponent.new()
		add_child(_health)



	if _health.name != "HealthComponent":
		_health.name = "HealthComponent"

	_health.max_health = max_health
	_health.current_health = max_health
	if not _health.on_death.is_connected(_on_death):
		_health.on_death.connect(_on_death)
	if _engine != null:
		if not _engine.finished.is_connected(_on_engine_finished):
			_engine.finished.connect(_on_engine_finished)
		_engine.play()
	else:
		push_warning("[LawnMower] Fant ikke EngineActiveSfx.")


func _physics_process(delta: float) -> void :
	if _state == State.DEAD:
		return
	_check_moose_trample()
	if _state == State.DEAD:
		return
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta

	if _state == State.RUNNING:
		var fwd: Vector3 = - global_transform.basis.z
		velocity.x = fwd.x * drive_speed
		velocity.z = fwd.z * drive_speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	move_and_slide()


	if _state == State.RUNNING and is_on_wall():
		if _engine != null and is_instance_valid(_engine):
			_engine.stop()
		_begin_pause_cycle()



func _on_engine_finished() -> void :

	if _state == State.RUNNING:
		_begin_pause_cycle()



func _begin_pause_cycle() -> void :
	if _state == State.DEAD:
		return
	_state = State.PAUSED
	await get_tree().create_timer(randf_range(min_pause, max_pause)).timeout
	if not is_inside_tree() or _state == State.DEAD:
		return
	var new_yaw: = rotation.y + randf_range( - max_turn, max_turn)
	var tw: = create_tween()
	tw.tween_property(self, "rotation:y", new_yaw, turn_time)
	await tw.finished
	if _state == State.DEAD:
		return
	_state = State.RUNNING
	if is_instance_valid(_engine):
		_engine.play()





const MOOSE_TRAMPLE_RADIUS: float = 1.3
var _killed_by_moose: bool = false


func hitscanHit(damage: float, _dir: Vector3, _pos: Vector3) -> void :
	if _health != null and not _health.is_dead:
		_health.take_damage(damage)


func projectileHit(damage: float, _dir: Vector3) -> void :
	if _health != null and not _health.is_dead:
		_health.take_damage(damage)





func _check_moose_trample() -> void :
	if _state == State.DEAD or _health == null or _health.is_dead:
		return
	for moose in get_tree().get_nodes_in_group("Wildlife"):
		if not (moose is Node3D) or not is_instance_valid(moose):
			continue
		var mp: Vector3 = (moose as Node3D).global_position
		var flat: Vector2 = Vector2(mp.x - global_position.x, mp.z - global_position.z)
		if flat.length() <= MOOSE_TRAMPLE_RADIUS:
			_killed_by_moose = true
			_health.take_damage(_health.current_health + 1.0)
			return


func _on_death() -> void :
	if _state == State.DEAD:
		return
	_state = State.DEAD
	velocity = Vector3.ZERO


	if AchievementManager != null:
		AchievementManager.unlock(AchievementManager.ACH_MOWERDEST)
		if _killed_by_moose:
			AchievementManager.unlock(AchievementManager.ACH_MOWERDEST_MOOSE)
	if _engine != null and is_instance_valid(_engine):
		_engine.stop()

	var col: = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col != null:
		col.disabled = true
	remove_from_group("NPC")
	remove_from_group("Enemies")


	var vfx: Node = EXPLOSION_VFX.instantiate()
	vfx.set("particleToEmit", "Explosion")
	get_tree().root.add_child(vfx)
	(vfx as Node3D).global_position = global_position
	if SfxManager != null:
		SfxManager.play("explosion")
	if death_sound != null:
		var p: = AudioStreamPlayer3D.new()
		p.stream = death_sound
		p.bus = "Sfx"
		get_tree().root.add_child(p)
		(p as Node3D).global_position = global_position
		p.play()
		p.finished.connect(p.queue_free)



	visible = false
	await get_tree().create_timer(EXPLOSION_LIFETIME).timeout
	queue_free()
