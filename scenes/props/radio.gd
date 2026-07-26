extends Node3D

const SONGS: Array[AudioStream] = [
	preload("res://assets/sfx/erdetlyd/musikk/radio/songs/en brødskive med grus [g86Yy6lwqco].mp3"), 
	preload("res://assets/sfx/erdetlyd/musikk/radio/songs/druer.mp3"), 
	preload("res://assets/sfx/erdetlyd/musikk/radio/songs/johanne.mp3"), 
	preload("res://assets/sfx/erdetlyd/musikk/radio/songs/saannsomvivar.mp3"), 
]

const HOST_CLIPS: Array[AudioStream] = [
	preload("res://assets/sfx/erdetlyd/musikk/radio/host/R01.ogg"), 
	preload("res://assets/sfx/erdetlyd/musikk/radio/host/R02.ogg"), 
	preload("res://assets/sfx/erdetlyd/musikk/radio/host/R03.ogg"), 
	preload("res://assets/sfx/erdetlyd/musikk/radio/host/R04.ogg"), 
	preload("res://assets/sfx/erdetlyd/musikk/radio/host/R05.ogg"), 
	preload("res://assets/sfx/erdetlyd/musikk/radio/host/R06.ogg"), 
	preload("res://assets/sfx/erdetlyd/musikk/radio/host/R07.ogg"), 
	preload("res://assets/sfx/erdetlyd/musikk/radio/host/R08.ogg"), 
	preload("res://assets/sfx/erdetlyd/musikk/radio/host/R09.ogg"), 
	preload("res://assets/sfx/erdetlyd/musikk/radio/host/R10.ogg"), 
	preload("res://assets/sfx/erdetlyd/musikk/radio/host/R11.ogg"), 
	preload("res://assets/sfx/erdetlyd/musikk/radio/host/R12.ogg"), 
	preload("res://assets/sfx/erdetlyd/musikk/radio/host/R13.ogg"), 
]

const VOLUME_STEPS: Array[float] = [-24.0, -16.0, -9.0, -80.0]
const SONG_INTRO_FADE: float = 1.0
const SONG_OUTRO_FADE: float = 3.0

var _volume_step: int = 0
var _songs: Array[AudioStream] = []
var _host_clips: Array[AudioStream] = []
var _last_song_index: int = -1
var _last_host_index: int = -1
var _playing_host: bool = false
var _is_playing_local: bool = false
var _song_outro_started: bool = false
var _volume_tween: Tween = null
var _hard_stopped: bool = false

@onready var _audio: AudioStreamPlayer3D = $RadioAudio
@onready var _volume_label: Label3D = $VolumeLabel


func _ready() -> void :
	add_to_group("Radio")
	add_to_group("HandInteractable")
	MusicManager.register_local_source(self)
	_audio.bus = "Radio"
	_audio.finished.connect(_on_audio_finished)
	_audio.volume_db = _get_target_volume()
	for s in SONGS:
		_songs.append(s)
	for h in HOST_CLIPS:
		_host_clips.append(h)
	await get_tree().process_frame
	_connect_home_bounds()
	_update_volume_label()
	_wait_for_intro_then_start()


func _wait_for_intro_then_start() -> void :
	var intro: Node = get_tree().get_first_node_in_group("IntroSequence")
	if intro != null and is_instance_valid(intro) and intro.has_signal("intro_finished"):
		intro.intro_finished.connect(_play_host_clip, CONNECT_ONE_SHOT)
		return
	_play_host_clip()


func _connect_home_bounds() -> void :
	var bounds: Area3D = get_tree().get_first_node_in_group("HomeBounds") as Area3D
	if bounds == null:
		push_warning("[Radio] HomeBounds not found — radio will never duck idle music")
		return
	bounds.monitoring = true
	bounds.set_collision_mask_value(1, true)
	bounds.set_collision_mask_value(2, true)
	if not bounds.body_entered.is_connected(_on_home_bounds_entered):
		bounds.body_entered.connect(_on_home_bounds_entered)
	if not bounds.body_exited.is_connected(_on_home_bounds_exited):
		bounds.body_exited.connect(_on_home_bounds_exited)
	var player: Node3D = NetUtil.get_local_player() as Node3D
	if player != null and bounds.overlaps_body(player):
		_on_home_bounds_entered(player)


func _on_home_bounds_entered(body: Node3D) -> void :
	if _hard_stopped:
		return
	if not body.is_in_group("PlayerCharacter"):
		return
	_is_playing_local = true
	MusicManager.refresh_local_fade()


func _on_home_bounds_exited(body: Node3D) -> void :
	if _hard_stopped:
		return
	if not body.is_in_group("PlayerCharacter"):
		return
	_is_playing_local = false
	MusicManager.activate_idle()


func _play_next_song() -> void :
	if _songs.is_empty():
		return
	var index: int = _last_song_index
	while index == _last_song_index and _songs.size() > 1:
		index = randi() % _songs.size()
	_last_song_index = index
	var stream: AudioStream = _songs[index]
	_playing_host = false
	_song_outro_started = false
	_kill_volume_tween()
	_audio.stream = stream
	var target_db: float = _get_target_volume()
	if target_db <= -79.0:
		_audio.volume_db = target_db
	else:
		_audio.volume_db = -80.0
	_audio.play()
	if target_db > -79.0:
		_volume_tween = create_tween()
		_volume_tween.tween_property(_audio, "volume_db", target_db, SONG_INTRO_FADE)


func _play_host_clip() -> void :
	if _host_clips.is_empty():
		_play_next_song()
		return
	var index: int = _last_host_index
	while index == _last_host_index and _host_clips.size() > 1:
		index = randi() % _host_clips.size()
	_last_host_index = index
	_playing_host = true
	_song_outro_started = false
	_kill_volume_tween()
	_audio.volume_db = _get_target_volume()
	_audio.stream = _host_clips[index]
	_audio.play()


func _process(_delta: float) -> void :
	if _playing_host or not _audio.playing or _song_outro_started:
		return
	var stream: AudioStream = _audio.stream
	if stream == null:
		return
	var length: float = stream.get_length()
	if length <= 0.0:
		return
	var remaining: float = length - _audio.get_playback_position()
	if remaining > SONG_OUTRO_FADE:
		return
	var target_db: float = _get_target_volume()
	if target_db <= -79.0:
		return
	_song_outro_started = true
	_kill_volume_tween()
	_volume_tween = create_tween()
	_volume_tween.tween_property(_audio, "volume_db", -80.0, minf(remaining, SONG_OUTRO_FADE))


func _get_target_volume() -> float:
	return VOLUME_STEPS[_volume_step]


func _kill_volume_tween() -> void :
	if _volume_tween != null and _volume_tween.is_valid():
		_volume_tween.kill()
	_volume_tween = null


func _on_audio_finished() -> void :
	if _playing_host:
		_play_next_song()
	else:
		_play_host_clip()


func adjust_volume() -> void :
	_volume_step = (_volume_step + 1) % VOLUME_STEPS.size()
	_kill_volume_tween()
	_song_outro_started = false
	_audio.volume_db = _get_target_volume()
	_update_volume_label()


func hand_interact() -> void :
	adjust_volume()


func skip_to_next() -> void :
	if _hard_stopped:
		return
	_audio.stop()
	_on_audio_finished()


func stop_radio() -> void :
	_hard_stopped = true
	_kill_volume_tween()
	_audio.stop()
	if _audio.finished.is_connected(_on_audio_finished):
		_audio.finished.disconnect(_on_audio_finished)
	_is_playing_local = false
	_disconnect_home_bounds()
	set_process(false)


func _disconnect_home_bounds() -> void :
	var bounds: Area3D = get_tree().get_first_node_in_group("HomeBounds") as Area3D
	if bounds == null:
		return
	if bounds.body_entered.is_connected(_on_home_bounds_entered):
		bounds.body_entered.disconnect(_on_home_bounds_entered)
	if bounds.body_exited.is_connected(_on_home_bounds_exited):
		bounds.body_exited.disconnect(_on_home_bounds_exited)


func _update_volume_label() -> void :
	if _volume_label == null:
		return
	match _volume_step:
		0:
			_volume_label.text = "▮░░"
		1:
			_volume_label.text = "▮▮░"
		2:
			_volume_label.text = "▮▮▮"
		3:
			_volume_label.text = "░░░"


func _exit_tree() -> void :
	MusicManager.unregister_local_source(self)
