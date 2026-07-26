extends AudioStreamPlayer

const DELAY_BEFORE_PLAY_SEC: = 60.0


func _ready() -> void :
	stop()
	_enable_loop()
	await get_tree().create_timer(DELAY_BEFORE_PLAY_SEC).timeout
	if is_inside_tree():
		_enable_loop()
		play()


func _enable_loop() -> void :
	if stream == null:
		return
	var stream_copy: AudioStream = stream.duplicate()
	if stream_copy != null and "loop" in stream_copy:
		stream_copy.loop = true
		stream = stream_copy
