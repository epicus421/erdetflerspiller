extends "res://scenes/npc/npc_base.gd"

const V_INTRO: AudioStream = preload("res://assets/sfx/erdetlyd/vox/vindkast/v_intro.ogg")
const V_QUEST: AudioStream = preload("res://assets/sfx/erdetlyd/vox/vindkast/v_quest.ogg")
const V_QUEST_NOTFIN: AudioStream = preload("res://assets/sfx/erdetlyd/vox/vindkast/v_quest_notfin.ogg")
const V_QUESTFIN: AudioStream = preload("res://assets/sfx/erdetlyd/vox/vindkast/v_questfin.ogg")

const LINES_IDLE: Array[String] = ["Pst, kan du gjøre meg en tjeneste?"]
const LINES_BLOCKED: Array[String] = ["Ingen spørsmål takk, bare riv ned de plakatene!"]


const ASCEND_SPEED: = 2.0

var _flying_away: bool = false


func _ready() -> void :
	npc_id = "vindkast"
	npc_name = "Ondsinnet vindkast"
	idle_dialogue = LINES_IDLE



	quest_dialogue_sounds = {
		"VINDKAST_PLAKATER": [V_INTRO, V_QUEST], 
		"VINDKAST_PLAKATER_COMPLETE": [V_QUESTFIN], 
		"BLOCKED_TURN_IN": [V_QUEST_NOTFIN], 
		"IDLE": [V_INTRO], 
	}
	add_to_group("Vindkast")
	super._ready()
	if name_label:
		name_label.text = "E — Snakk med vindkastet"
	var whisper: = get_node_or_null("WhisperLabel") as Label3D
	if whisper:
		whisper.visible = true


func _interact() -> void :
	if _flying_away or DialogueUI.is_open():
		return



	if GameManager.has_active_quest("VINDKAST_PLAKATER")\
	and not GameManager.is_quest_completed("VINDKAST_PLAKATER")\
	and GameManager.get_item_count("gard_plakat") < GameManager.TOTAL_GARD_PLAKATER:
		GameManager.register_npc_talked(npc_id)
		var objs: Array = [_make_line(LINES_BLOCKED[0], V_QUEST_NOTFIN)]
		_show_npc_dialogue(LINES_BLOCKED, objs, Callable())
		return
	super._interact()


func _can_turn_in_quest(quest: Quest) -> bool:
	if quest.quest_id == "VINDKAST_PLAKATER":
		return GameManager.get_item_count("gard_plakat") >= GameManager.TOTAL_GARD_PLAKATER
	return super._can_turn_in_quest(quest)


func _get_turn_in_blocked_dialogue(quest: Quest) -> Array[String]:
	if quest.quest_id == "VINDKAST_PLAKATER":
		return LINES_BLOCKED
	return super._get_turn_in_blocked_dialogue(quest)


func _update_talk_objective_if_needed(quest: Quest) -> bool:
	if quest.quest_id == "VINDKAST_PLAKATER":
		var collected: = int(quest.objective_progress.get("collect_plakater", 0))
		if collected < GameManager.TOTAL_GARD_PLAKATER:
			return false
		if GameManager.get_item_count("gard_plakat") < GameManager.TOTAL_GARD_PLAKATER:
			return false
	return super._update_talk_objective_if_needed(quest)




func _show_completion_and_turn_in(quest: Quest) -> void :
	if quest.quest_id != "VINDKAST_PLAKATER":
		super._show_completion_and_turn_in(quest)
		return
	if _flying_away or GameManager.is_quest_completed("VINDKAST_PLAKATER"):
		return
	GameManager.remove_item("gard_plakat", GameManager.get_item_count("gard_plakat"))
	_prepare_turn_in_rewards(quest)
	GameManager.complete_quest_by_id(quest.quest_id)
	quests.erase(quest)

	var ascend_time: = 15.0
	if _audio_player != null and V_QUESTFIN != null:
		_audio_player.stream = V_QUESTFIN
		_audio_player.play()
		ascend_time = maxf(V_QUESTFIN.get_length(), 1.0)
	_fly_away(ascend_time)


func _fly_away(ascend_time: float = 15.0) -> void :
	if _flying_away:
		return
	_flying_away = true
	set_process_input(false)
	if interaction_area:
		interaction_area.monitoring = false
	if name_label:
		name_label.visible = false



	var tween: = create_tween()
	tween.tween_property(
		self, 
		"global_position", 
		global_position + Vector3(0, ascend_time * ASCEND_SPEED, 0), 
		ascend_time
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	var whisper: = get_node_or_null("WhisperLabel") as Label3D
	if whisper:
		tween.parallel().tween_property(whisper, "modulate:a", 0.0, ascend_time * 0.9)
	var wind: = get_node_or_null("WindEffect") as GPUParticles3D
	if wind:
		tween.parallel().tween_property(wind, "amount_ratio", 0.0, ascend_time * 0.9)
	await tween.finished
	queue_free()
