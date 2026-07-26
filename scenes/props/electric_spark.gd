extends Node3D

@export var bob_enabled: bool = false
@export var bob_amount: float = 0.15
@export var bob_speed: float = 3.0

var _active: bool = true
var _base_y: float = 0.0
var _bob_phase: float = 0.0


func _ready() -> void :
	_base_y = position.y
	_bob_phase = randf() * TAU
	var area: = get_node_or_null("HazardArea") as Area3D
	if area:
		area.monitoring = false
	if has_node("GPUParticles3D"):
		$GPUParticles3D.emitting = true
	var hum: = get_node_or_null("AudioStreamPlayer3D") as AudioStreamPlayer3D
	if hum and hum.stream:
		hum.play()


func _process(delta: float) -> void :
	if not bob_enabled:
		return
	_bob_phase += delta * bob_speed
	position.y = _base_y + sin(_bob_phase) * bob_amount


func is_spark_active() -> bool:
	return _active


func activate() -> void :
	_active = true
	if has_node("GPUParticles3D"):
		$GPUParticles3D.emitting = true


func deactivate() -> void :
	_active = false
	if has_node("GPUParticles3D"):
		$GPUParticles3D.emitting = false
