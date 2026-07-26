extends Node





const SFX = {

	"item_added":
		"res://assets/sfx/erdetlyd/splice/generalpickup0.wav", 
	"item_removed":
		"res://assets/sfx/erdetlyd/splice/generalpickup1.wav", 


	"money_added":
		"res://assets/sfx/erdetlyd/splice/coin_add.wav", 
	"money_removed":
		"res://assets/sfx/erdetlyd/splice/coin_remove.wav", 


	"quest_added":
		"res://assets/sfx/erdetlyd/splice/bell.wav", 
	"quest_completed":
		"res://assets/sfx/erdetlyd/splice/bell.wav", 


	"player_heal":
		"res://assets/sfx/erdetlyd/splice/eat.wav", 
	"player_death":
		"res://assets/sfx/erdetlyd/splice/fleshstab_player_takes_dmg.wav", 


	"gorgon_impact":
		"res://assets/sfx/erdetlyd/splice/gravelpickup.wav", 


	"electric_shock":
		"res://assets/sfx/erdetlyd/splice/electricburst.wav", 


	"explosion":
		"res://assets/sfx/erdetlyd/splice/mormorexplode.wav", 


	"ui_blip":
		"res://assets/sfx/erdetlyd/splice/beep.wav", 
	"ui_error":
		"res://assets/sfx/erdetlyd/splice/ui_negative0.wav", 
}

var _player: AudioStreamPlayer = null
var _streams: Dictionary = {}


func _ready() -> void :
	_player = AudioStreamPlayer.new()
	_player.bus = "Sfx"
	_player.volume_db = -6.0
	add_child(_player)
	_preload_streams()


func _preload_streams() -> void :
	for key in SFX:
		var path: String = SFX[key]
		if ResourceLoader.exists(path):
			_streams[key] = load(path)
		else:
			push_warning("[SFX] Missing: " + path)





func play(event: String, volume_db: float = 0.0) -> void :
	if not _streams.has(event):
		return
	_player.stream = _streams[event]
	_player.volume_db = -6.0 + volume_db
	_player.play()
