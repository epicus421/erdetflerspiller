extends Node

const MUSIC_STREAMS: = {
	"title": preload("res://assets/sfx/erdetlyd/musikk/erdetspill temasang.ogg"), 
	"idle": preload("res://assets/sfx/erdetlyd/musikk/idle.ogg"), 
	"horror": preload("res://assets/sfx/erdetlyd/musikk/creepyambience.ogg"), 
}

const FADE_SPEED: = 1.5
const DEFAULT_BASE_VOLUME: = -20.5

var _player: AudioStreamPlayer = null
var _current_track: String = ""
var _target_volume: float = DEFAULT_BASE_VOLUME
var _base_volume: float = DEFAULT_BASE_VOLUME
var _local_sources: Array = []
var _faded_for_local: bool = false


func _ready() -> void :
	_player = AudioStreamPlayer.new()
	_player.bus = "Music"
	_player.volume_db = -80.0
	add_child(_player)
	play("idle")
	_target_volume = -80.0
	_player.volume_db = -80.0


func play(track: String) -> void :
	if _current_track == track and _player.playing:
		_target_volume = _base_volume if not _faded_for_local else -80.0
		return
	if not MUSIC_STREAMS.has(track):
		push_warning("[MusicManager] Track not found: " + track)
		return
	var stream_res: AudioStream = (MUSIC_STREAMS[track] as AudioStream).duplicate()
	stream_res.loop = true
	var track_changed: = _current_track != track
	_current_track = track
	_player.stream = stream_res
	_player.play()
	_target_volume = _base_volume if not _faded_for_local else -80.0
	if track_changed:
		_player.volume_db = _target_volume


func stop(instant: bool = false) -> void :
	_current_track = ""
	_target_volume = -80.0
	if instant and _player != null:
		_player.volume_db = -80.0
		_player.stop()


func _process(delta: float) -> void :
	_update_local_fade()
	if _player != null:
		_player.volume_db = lerpf(_player.volume_db, _target_volume, FADE_SPEED * delta)


func _update_local_fade() -> void :
	var any_active: = false
	var i: = _local_sources.size() - 1
	while i >= 0:
		var source: Node = _local_sources[i]
		if not is_instance_valid(source):
			_local_sources.remove_at(i)
		elif source.get("_is_playing_local") == true:
			any_active = true
		i -= 1
	if any_active and not _faded_for_local:
		_faded_for_local = true
		_target_volume = -80.0
	elif not any_active and _faded_for_local:
		_faded_for_local = false
		if _current_track != "":
			_target_volume = _base_volume


func activate_idle() -> void :
	if GameManager.is_ending_sequence_active():
		return
	play("idle")
	refresh_local_fade()


func refresh_local_fade() -> void :
	_update_local_fade()


func register_local_source(source: Node) -> void :
	if not _local_sources.has(source):
		_local_sources.append(source)


func unregister_local_source(source: Node) -> void :
	_local_sources.erase(source)


func set_base_volume(db: float) -> void :
	_base_volume = db
	if not _faded_for_local and _current_track != "":
		_target_volume = db
