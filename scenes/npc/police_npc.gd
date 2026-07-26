extends "res://scenes/npc/npc_base.gd"

const ID_CARD_FORM_SCENE: PackedScene = preload("res://scenes/minigames/id_card_form.tscn")


const CLIP_AVVIS: AudioStream = preload("res://assets/sfx/erdetlyd/vox/politi/politi_avvis0.ogg")
const CLIP_FERDIG: AudioStream = preload("res://assets/sfx/erdetlyd/vox/politi/politi_ferdig.ogg")
const CLIP_POSTKASSE: AudioStream = preload("res://assets/sfx/erdetlyd/vox/politi/politi_postkasse.ogg")
const CLIP_START_FORM: AudioStream = preload("res://assets/sfx/erdetlyd/vox/politi/politi_startidcardform0.ogg")


const CLIP_TAKK: AudioStream = preload("res://assets/sfx/erdetlyd/vox/politi/politi_takk.ogg")
const TEXT_TAKK: = "Jaha, da var skjemaet fylt ut, ser jeg! ID-kortet blir sendt til postkassen din i løpet av kort tid."


const OFFER_CLIPS: Array[AudioStream] = [
	preload("res://assets/sfx/erdetlyd/vox/politi/politi_tilbud0.ogg"), 
	preload("res://assets/sfx/erdetlyd/vox/politi/politi_tilbud1.ogg"), 
]
const OFFER_TEXTS: Array[String] = [
	"Idkort, ja? Du fikk ikke lov til å kjøpe is på butikken, nei. Neimen, det kan vi fikse. Bare fyll ut dette skjemaet, så sender vi ID-kortet i posten.", 
	"Jasså, så du trenger idkort? Det kan vi fikse! Bare fyll ut dette skjemaet, så sender vi ID-kortet i posten.", 
]


func _play_sfx(clip: AudioStream) -> void :
	if _audio_player != null and clip != null:
		_audio_player.stream = clip
		_audio_player.play()


func _interact() -> void :
	GameManager.register_npc_talked(npc_id)


	if GameManager.id_card_collected:
		_play_sfx(CLIP_FERDIG)
		return
	if GameManager.id_card_ready:
		_play_sfx(CLIP_POSTKASSE)
		return


	if not GameManager.has_active_quest("SECOND_ICECREAM")\
	and not GameManager.is_quest_completed("SECOND_ICECREAM"):
		_play_sfx(CLIP_AVVIS)
		return

	var i: = randi() % OFFER_CLIPS.size()
	_show_npc_dialogue(
		[OFFER_TEXTS[i]], 
		[_make_line(OFFER_TEXTS[i], OFFER_CLIPS[i])], 
		func():
			_open_id_card_form()
	)


func _open_id_card_form() -> void :

	_play_sfx(CLIP_START_FORM)
	var form: Node = ID_CARD_FORM_SCENE.instantiate()
	var root: = get_tree().current_scene
	if root == null:
		root = get_tree().root
	root.add_child(form)
	if form.has_signal("form_submitted"):
		form.form_submitted.connect( func():
			_show_npc_dialogue(
				[TEXT_TAKK], 
				[_make_line(TEXT_TAKK, CLIP_TAKK)], 
				Callable()
			)
		)
