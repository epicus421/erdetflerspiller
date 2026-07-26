extends "res://scenes/npc/npc_base.gd"

const _VOX: = "res://assets/sfx/erdetlyd/vox/gorgon/"

const _IDLE: AudioStream = preload(_VOX + "idle.ogg")
const _JEG_SOM_TOK_GUMMI: AudioStream = preload(_VOX + "jegsomtokgummi.ogg")
const _HA_DEN_TILBAKE: AudioStream = preload(_VOX + "hadentilbake.ogg")
const _JA_DA_MAA: AudioStream = preload(_VOX + "jadamaaduslaamegitrepaarad.ogg")
const _WIN: AudioStream = preload(_VOX + "win.ogg")
const _SAA_VANT_DU: AudioStream = preload(_VOX + "saavantdu.ogg")
const _UAVGJORT: AudioStream = preload(_VOX + "uavgjort.ogg")
const _UAVGJORT2: AudioStream = preload(_VOX + "uavgjort2.ogg")
const _PLACE0: AudioStream = preload(_VOX + "place0.ogg")
const _PLACE1: AudioStream = preload(_VOX + "place1.ogg")

const LINES_IDLE: Array[String] = ["Reparere, revidere..."]

const CHALLENGE_LINES: Array[String] = [
	"Ja det var jeg som tok gummien din.", 
	"Vil du ha den tilbake?", 
	"Da må du slå meg i tre på rad", 
]

const REFUSE_LINES: Array[String] = [
	"Ja, da må du slå meg i tre på rad.", 
]

const TTT_LINES_WIN: Array[String] = ["Ja.. så vant du da.."]
const TTT_LINES_LOSE: Array[String] = ["heheh, gorgon er bedre"]
const TTT_LINES_DRAW: Array[String] = [
	"Hahhaha, uavgjort, har du sett på makan!", 
	"Dette ble jo helt umulig for vi er like gode!", 
]

const LINE_SOUNDS: Dictionary = {
	"Reparere, revidere...": _IDLE, 
	"Heheh da vant du da...": _SAA_VANT_DU, 
	"Ja det var jeg som tok gummien din.": _JEG_SOM_TOK_GUMMI, 
	"Vil du ha den tilbake?": _HA_DEN_TILBAKE, 
	"Da må du slå meg i tre på rad": _JA_DA_MAA, 
	"Ja, da må du slå meg i tre på rad.": _JA_DA_MAA, 
	"Hahhaha, uavgjort, har du sett på makan!": _UAVGJORT, 
	"Dette ble jo helt umulig for vi er like gode!": _UAVGJORT2, 
}



const TTT_PLACE_STREAMS: Array[AudioStream] = [_PLACE0, _PLACE1]


func _ready() -> void :
	npc_id = "gorgon"
	npc_name = "Gorgon"
	add_to_group("Gorgon")
	super._ready()


func start_throwing() -> void :
	pass


func stop_throwing() -> void :
	pass


func on_box_delivered() -> void :
	pass


func _interact() -> void :
	if is_dead or GameManager.is_npc_dead(npc_id):
		return
	if DialogueUI.is_open():
		return

	if not GameManager.has_quest("GORGON_ROBBERY"):
		_show_gorgon_lines(LINES_IDLE)
		return
	if GameManager.is_quest_completed("GORGON_ROBBERY"):
		_show_gorgon_lines(["Heheh da vant du da..."])
		return

	GameManager.update_quest_objective("GORGON_ROBBERY", "find_gorgon", 1)
	_show_gorgon_lines(CHALLENGE_LINES, func() -> void :
		_show_accept_loop()
	)


func _show_accept_loop() -> void :
	DialogueUI.show_menu(
		["Aksepterer du utfordringen?"], 
		[
			{"text": "Ja", "action": _on_accept_tictactoe}, 
			{"text": "Nei", "action": _on_decline_tictactoe}, 
		], 
		npc_name
	)


func start_horror_tictactoe() -> void :
	GameManager.update_quest_objective("GORGON_ROBBERY", "find_gorgon", 1)
	_show_gorgon_lines(CHALLENGE_LINES, func() -> void :
		_on_accept_tictactoe()
	)


func _on_accept_tictactoe() -> void :
	if DialogueUI.is_open():
		DialogueUI.close()
	var ttt: PackedScene = load("res://scenes/minigames/tictactoe.tscn") as PackedScene
	if ttt == null:
		push_warning("[Gorgon] tictactoe.tscn missing")
		return
	get_tree().root.add_child(ttt.instantiate())


func _on_decline_tictactoe() -> void :
	var line: String = REFUSE_LINES[randi() % REFUSE_LINES.size()]
	_show_gorgon_lines([line], func() -> void :
		_show_accept_loop()
	)




func play_ttt_place() -> float:
	return _play_ttt_voice(TTT_PLACE_STREAMS)


func show_ttt_win_dialogue(on_close: Callable = Callable()) -> void :
	_show_gorgon_lines_with_audio(TTT_LINES_WIN, [_SAA_VANT_DU], on_close)


func show_ttt_lose_dialogue(on_close: Callable = Callable()) -> void :
	_show_gorgon_lines_with_audio(TTT_LINES_LOSE, [_WIN], on_close)


func show_ttt_draw_dialogue(on_close: Callable = Callable()) -> void :
	_show_gorgon_lines(TTT_LINES_DRAW, on_close)


func _play_ttt_voice(streams: Array) -> float:
	if _audio_player == null or streams.is_empty():
		return 0.0
	var stream: AudioStream = streams[randi() % streams.size()]
	if stream == null:
		return 0.0
	_audio_player.stream = stream
	_audio_player.play()
	return stream.get_length()


func _show_gorgon_lines(texts: Array[String], on_close: Callable = Callable()) -> void :
	var objs: Array = []
	for s in texts:
		var audio: AudioStream = LINE_SOUNDS.get(s) as AudioStream
		objs.append(_make_line(s, audio))
	_show_npc_dialogue(texts, objs, on_close)


func _show_gorgon_lines_with_audio(
		texts: Array[String], 
		streams: Array, 
		on_close: Callable = Callable()
	) -> void :
	var objs: Array = []
	for i in texts.size():
		var stream: AudioStream = streams[i] if i < streams.size() else null
		objs.append(_make_line(texts[i], stream))
	_show_npc_dialogue(texts, objs, on_close)
