extends StaticBody3D




signal shattered(bottle: Node)

const GLASSBREAK: AudioStream = preload("res://assets/sfx/erdetlyd/splice/glassbreak.wav")

var _is_shattered: bool = false

@onready var _model: Node3D = get_node_or_null("Model") as Node3D
@onready var _collision: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D


func _ready() -> void :
	add_to_group("HitableObjects")


func take_damage(_amount: float) -> void :
	if _is_shattered:
		return
	_is_shattered = true
	_play_break_sound()
	if _collision != null:
		_collision.set_deferred("disabled", true)
	shattered.emit(self)
	if _model != null:
		var base_scale: Vector3 = _model.scale
		var tween: = create_tween()
		tween.tween_property(_model, "scale", base_scale * 0.05, 0.15)
		await tween.finished
		_model.visible = false
		_model.scale = base_scale


func reset_bottle() -> void :
	_is_shattered = false
	if _model != null:
		_model.visible = true
	if _collision != null:
		_collision.set_deferred("disabled", false)


func _play_break_sound() -> void :
	var audio: = AudioStreamPlayer3D.new()
	get_tree().current_scene.add_child(audio)
	audio.global_position = global_position
	audio.bus = "Sfx"
	audio.stream = GLASSBREAK
	audio.play()
	audio.finished.connect( func(): audio.queue_free())


func projectileHit(_propul_force: float, _propul_dir: Vector3) -> void :
	take_damage(1.0)


func hitscanHit(_propul_force: float, _propul_dir: Vector3, _propul_pos: Vector3) -> void :
	take_damage(1.0)
