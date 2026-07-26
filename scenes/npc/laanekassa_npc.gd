extends "res://scenes/npc/npc_base.gd"










const INTRO0: AudioStream = preload("res://assets/sfx/erdetlyd/vox/laanekassa/laanekasse_intro0.ogg")
const INTRO1: AudioStream = preload("res://assets/sfx/erdetlyd/vox/laanekassa/laanekasse_intro1.ogg")
const INTRO2: AudioStream = preload("res://assets/sfx/erdetlyd/vox/laanekassa/laanekasse_intro2.ogg")
const INTRO3: AudioStream = preload("res://assets/sfx/erdetlyd/vox/laanekassa/laanekasse_intro3.ogg")
const INTRO5: AudioStream = preload("res://assets/sfx/erdetlyd/vox/laanekassa/laanekasse_intro5.ogg")
const RETTBAKDEG: AudioStream = preload("res://assets/sfx/erdetlyd/vox/laanekassa/laanekasse_rettbakdeg.ogg")


const TXT_INTRO0: = "Hei du, jeg jobber i lånekassa! Men jeg er veldig kul, det lover jeg deg."
const TXT_INTRO1: = "Før i tiden drev jeg med rap, slik rytmisk prating."
const TXT_INTRO2: = "Du trenger stipend, sier du. Det skal jeg selvsagt hjelpe til med. Men først og fremst — du fikk med deg at jeg har vært rapper før i tiden, sant?"
const TXT_INTRO3: = "Norges aller første rapper, faktisk. Er ikke det bare kjempe rått!"
const TXT_INTRO5: = "Uansett, stipendsøknaden gjør du der borte på terminalen."
const TXT_RETTBAKDEG: = "Ja, der inne — i rommet rett bak deg!"
const TXT_DUERTILBAKE: = "Jaså, kommer du tilbake for å teste freestyle-skillsa mine?"


const EARLY_INTRO_TEXTS: Array[String] = [TXT_INTRO0, TXT_INTRO1]
const EARLY_INTRO_CLIPS: Array[AudioStream] = [INTRO0, INTRO1]


const QUEST_INTRO_TEXTS: Array[String] = [TXT_INTRO2, TXT_INTRO3, TXT_INTRO5, TXT_RETTBAKDEG]
const QUEST_INTRO_CLIPS: Array[AudioStream] = [INTRO2, INTRO3, INTRO5, RETTBAKDEG]

const RAP_CLIPS: Array[AudioStream] = [
	preload("res://assets/sfx/erdetlyd/vox/laanekassa/laanekasse_rap0.ogg"), 
	preload("res://assets/sfx/erdetlyd/vox/laanekassa/laanekasse_rap1.ogg"), 
	preload("res://assets/sfx/erdetlyd/vox/laanekassa/laanekasse_rap2.ogg"), 
	preload("res://assets/sfx/erdetlyd/vox/laanekassa/laanekasse_rap3.ogg"), 
	preload("res://assets/sfx/erdetlyd/vox/laanekassa/laanekasse_rap4.ogg"), 
	preload("res://assets/sfx/erdetlyd/vox/laanekassa/laanekasse_rap5.ogg"), 
	preload("res://assets/sfx/erdetlyd/vox/laanekassa/laanekasse_rap6.ogg"), 
	preload("res://assets/sfx/erdetlyd/vox/laanekassa/laanekasse_rap7.ogg"), 
	preload("res://assets/sfx/erdetlyd/vox/laanekassa/laanekasse_rap8.ogg"), 
]

const LISTENTOTHIS: AudioStream = preload("res://assets/sfx/erdetlyd/vox/laanekassa/laanekasse_listentothis.ogg")
const DUERTILBAKE: AudioStream = preload("res://assets/sfx/erdetlyd/vox/laanekassa/laanekasse_duertilbake0.ogg")
const FUNFACT: AudioStream = preload("res://assets/sfx/erdetlyd/vox/laanekassa/laanekasse_rap_funfact0.ogg")
const FUNFACT_CHANCE: = 0.35

var _quest_intro_done: bool = false


func _ready() -> void :
	npc_id = "chief_keef"
	npc_name = "Chief Keef"
	super._ready()


func _interact() -> void :
	if is_dead or GameManager.is_npc_dead(npc_id):
		return
	if DialogueUI.is_open():
		return

	if _audio_player != null and _audio_player.playing:
		return
	GameManager.register_npc_talked(npc_id)



	var asked_to_apply: = GameManager.has_active_quest("SCHOLARSHIP_APPLICATION")\
	or GameManager.is_quest_completed("SCHOLARSHIP_APPLICATION")
	if not asked_to_apply:

		_play_clips(EARLY_INTRO_TEXTS, EARLY_INTRO_CLIPS)
		return

	if not _quest_intro_done:
		_quest_intro_done = true

		_complete_talk_objective()
		_play_clips(QUEST_INTRO_TEXTS, QUEST_INTRO_CLIPS)
	else:
		_play_return()


func _complete_talk_objective() -> void :

	var qs: = _get_quest_system()
	if qs != null and qs.has_method("on_npc_talked"):
		qs.on_npc_talked(npc_id)
	else:
		GameManager.update_quest_objective(
			"SCHOLARSHIP_APPLICATION", "talk_to_chief_keef", 1
		)


func _play_clips(texts: Array, clips: Array, on_close: Callable = Callable()) -> void :
	var line_texts: Array[String] = []
	var objs: Array = []
	for i in clips.size():
		var t: String = str(texts[i]) if i < texts.size() else ""
		line_texts.append(t)
		objs.append(_make_line(t, clips[i]))
	_show_npc_dialogue(line_texts, objs, on_close)


func _play_return() -> void :

	_show_npc_dialogue(
		[TXT_DUERTILBAKE], [_make_line(TXT_DUERTILBAKE, DUERTILBAKE)], 
		func() -> void : _play_rap_sfx(true)
	)




func _play_rap_sfx(allow_funfact: bool) -> void :
	var clips: Array[AudioStream] = [LISTENTOTHIS, RAP_CLIPS[randi() % RAP_CLIPS.size()]]
	if allow_funfact and randf() < FUNFACT_CHANCE:
		clips.append(FUNFACT)
	_play_sfx_sequence(clips)




func _play_sfx_sequence(clips: Array) -> void :
	for clip in clips:
		if clip == null:
			continue
		if not is_instance_valid(_audio_player):
			return
		_audio_player.stream = clip
		_audio_player.play()
		await _audio_player.finished
