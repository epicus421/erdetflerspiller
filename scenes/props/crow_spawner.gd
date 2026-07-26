extends Node3D

const CROW_SCENE: PackedScene = preload(
	"res://scenes/Enemies/crow.tscn")

@export var spawn_interval: float = 15.0
@export var spawn_radius: float = 18.0
@export var max_crows: int = 6

var _timer: float = 0.0
var _spawned: Array = []


func _process(delta: float) -> void :
	_spawned = _spawned.filter(
		func(c): return is_instance_valid(c))
	if _spawned.size() >= max_crows:
		return
	_timer += delta
	if _timer >= spawn_interval:
		_timer = 0.0
		_spawn_one()


func _spawn_one() -> void :
	var crow: Node3D = CROW_SCENE.instantiate() as Node3D
	get_parent().add_child(crow)
	crow.global_position = global_position + Vector3(
		randf_range( - spawn_radius, spawn_radius), 
		1.0, 
		randf_range( - spawn_radius, spawn_radius))
	_spawned.append(crow)
