extends Area3D








const VOX_START: AudioStream = preload(
	"res://assets/sfx/erdetlyd/vox/misc/mekonommedvokal.ogg")
const VOX_LOOP: AudioStream = preload(
	"res://assets/sfx/erdetlyd/vox/misc/mekonommedloopaftervoxtrigger.ogg")

var _triggered: bool = false


func _ready() -> void :
	monitoring = true

	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void :
	if _triggered or not body.is_in_group("PlayerCharacter"):
		return
	_triggered = true
	set_deferred("monitoring", false)

	var sfx: = _get_sfx_player()
	if sfx == null:
		queue_free()
		return
	sfx.stream = VOX_START
	sfx.play()


	var loop_stream: = VOX_LOOP.duplicate() as AudioStream
	if loop_stream is AudioStreamOggVorbis:
		(loop_stream as AudioStreamOggVorbis).loop = true
	sfx.finished.connect( func() -> void :
		sfx.stream = loop_stream
		sfx.play()
	, CONNECT_ONE_SHOT)

	queue_free()


func _get_sfx_player() -> AudioStreamPlayer3D:
	var sfx: = get_node_or_null("../mechanicsfx") as AudioStreamPlayer3D
	if sfx != null:
		return sfx
	push_warning("[MechanicVox] Fant ikke '../mechanicsfx' — lager fallback.")
	sfx = AudioStreamPlayer3D.new()
	sfx.name = "mechanicsfx"
	sfx.bus = "Sfx"
	sfx.max_distance = 40.0
	sfx.unit_size = 8.0
	var parent: = get_parent()
	if parent == null:
		return null
	parent.add_child(sfx)
	var shape: = get_node_or_null("CollisionShape3D") as Node3D
	sfx.global_position = shape.global_position if shape != null else global_position
	return sfx
