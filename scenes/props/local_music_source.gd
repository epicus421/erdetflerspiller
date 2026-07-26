extends AudioStreamPlayer3D

@export var music_file: String = ""
@export var fade_radius: float = 8.0
@export var loop_music: bool = true
@export var always_playing: bool = false
@export var start_on_store_enter: bool = false

var _is_playing_local: bool = false
var _player_nearby: bool = false


func _ready() -> void :
	if always_playing or start_on_store_enter:
		bus = "Ambience"
	else:
		bus = "Music"
	MusicManager.register_local_source(self)
	if music_file != "" and ResourceLoader.exists(music_file):
		var stream_res: AudioStream = load(music_file)
		if stream_res != null:
			stream_res = stream_res.duplicate()
			stream_res.loop = loop_music
			stream = stream_res
	if always_playing:
		play()
		_is_playing_local = false
	elif start_on_store_enter:
		call_deferred("_connect_store_door_trigger")


func _connect_store_door_trigger() -> void :
	var trigger: Node = get_tree().get_first_node_in_group("KjiwiDoorTrigger")
	if trigger == null:
		trigger = get_tree().root.find_child("KjiwiDoorTrigger", true, false)
	if trigger == null:
		push_warning("[LocalMusicSource] KjiwiDoorTrigger not found")
		return
	if trigger.has_signal("player_entered_store")\
	and not trigger.player_entered_store.is_connected(_on_store_entered):
		trigger.player_entered_store.connect(_on_store_entered)
	if trigger.has_signal("player_exited_store")\
	and not trigger.player_exited_store.is_connected(_on_store_exited):
		trigger.player_exited_store.connect(_on_store_exited)


func _on_store_entered() -> void :
	start_local()


func _on_store_exited() -> void :
	stop_local()


func _process(_delta: float) -> void :
	var player_node: = NetUtil.get_local_player() as Node3D
	if player_node == null:
		return
	var dist: = global_position.distance_to(player_node.global_position)
	_player_nearby = dist <= fade_radius
	if always_playing:
		if _player_nearby and not playing and stream != null:
			play()
		elif not _player_nearby and playing:
			stop()
		_is_playing_local = _player_nearby and playing


func toggle_play() -> void :
	if always_playing:
		return
	if playing:
		stop_local()
	else:
		start_local()


func start_local() -> void :
	if stream == null:
		return
	play()
	_is_playing_local = true


func stop_local() -> void :
	stop()
	_is_playing_local = false


func _exit_tree() -> void :
	MusicManager.unregister_local_source(self)
