extends "res://scenes/npc/npc_base.gd"

signal dance_finished

var _dancing: bool = false

const _VOX: = "res://assets/sfx/erdetlyd/vox/hverdagskomiker/"

const _A1: AudioStream = preload(_VOX + "a1.ogg")
const _A2: AudioStream = preload(_VOX + "a2.ogg")
const _A3: AudioStream = preload(_VOX + "a3.ogg")
const _A4: AudioStream = preload(_VOX + "a4.ogg")
const _A5: AudioStream = preload(_VOX + "a5.ogg")
const _A6: AudioStream = preload(_VOX + "a6.ogg")
const _A7: AudioStream = preload(_VOX + "a7.ogg")
const _A8: AudioStream = preload(_VOX + "a8.ogg")
const _D1: AudioStream = preload(_VOX + "d1.ogg")
const _D2: AudioStream = preload(_VOX + "d2.ogg")
const _E1: AudioStream = preload(_VOX + "e1.ogg")

const LINE_SOUNDS: Dictionary = {
	"En hamster klatret inn i stikkontakten.": _A1, 
	"Så hamsteren svidde hele sikringen.": _A2, 
	"Støpselet er helt ødelagt og må byttes.": _A3, 
	"Bruk støpsellageren bak deg for å lage et nytt støpsel slik at byen får strøm igjen!": _A4, 
	"Du trenger bare kobberledning, plast og gummi.": _A5, 
	"En gutt her i byen har kobberledningen som du trenger, finn han så kan han gi den fra seg.": _A6, 
	"Plast finner du i fiskadammen.": _A7, 
	"Gummi får du fra bildekk, jeg tror det ligger ett dekk i Kratergata.": _A8, 
	"Supert! Koble den til i stikkontakten der borte!": _D1, 
	"Pass deg for gnistene.": _D2, 
	"Godt jobba, nå er strømmen tilbake!": _E1, 
}

const LINES_INTRO: Array[String] = [
	"En hamster klatret inn i stikkontakten.", 
	"Så hamsteren svidde hele sikringen.", 
	"Støpselet er helt ødelagt og må byttes.", 
	"Bruk støpsellageren bak deg for å lage et nytt støpsel slik at byen får strøm igjen!", 
	"Du trenger bare kobberledning, plast og gummi.", 
	"En gutt her i byen har kobberledningen som du trenger, finn han så kan han gi den fra seg.", 
	"Plast finner du i fiskadammen.", 
	"Gummi får du fra bildekk, jeg tror det ligger ett dekk i Kratergata.", 
]


func _ready() -> void :
	npc_id = "hverdagskomiker"
	npc_name = "Hverdagskomikeren"
	add_to_group("Hverdagskomiker")
	super._ready()


func _interact() -> void :
	if is_dead or GameManager.is_npc_dead(npc_id):
		return
	if DialogueUI.is_open() or _dancing:
		return
	if not GameManager.has_quest("HVERDAGSKOMIKER"):
		return
	if GameManager.has_method("register_npc_talked"):
		GameManager.register_npc_talked(npc_id)

	if GameManager.is_quest_completed("HVERDAGSKOMIKER"):
		_show_hk_lines(["Godt jobba, nå er strømmen tilbake!"])
		return

	if _has_stoepsel_prop() or _player_carrying_stoepsel():
		_show_hk_lines([
			"Supert! Koble den til i stikkontakten der borte!", 
			"Pass deg for gnistene.", 
		])
		return

	var has_all: bool = (
		GameManager.has_item("kobber")
		and GameManager.has_item("plast")
		and GameManager.has_item("gummi")
	)
	if has_all:
		_show_hk_lines(["Bygg støpselen på byggeplassen her."], func() -> void :
			GameManager.set_quest_hint(
				"HVERDAGSKOMIKER", "Bygg støpselen på byggeplassen"
			)
		)
		return

	if not _is_talk_objective_complete():
		_show_hk_lines(LINES_INTRO, Callable(_complete_talk_objective))
		return

	var reminders: = _gather_reminder_lines()
	if reminders.is_empty():
		_show_hk_lines(["Bygg støpselen på byggeplassen her."])
	else:
		_show_hk_lines(reminders)


func _is_talk_objective_complete() -> bool:
	if not GameManager.has_active_quest("HVERDAGSKOMIKER"):
		return true
	var quest: Quest = GameManager.active_quests.get("HVERDAGSKOMIKER") as Quest
	if quest == null:
		return true
	return int(quest.objective_progress.get("talk_to_hverdagskomiker", 0)) >= 1


func _complete_talk_objective() -> void :
	GameManager.update_quest_objective("HVERDAGSKOMIKER", "talk_to_hverdagskomiker", 1)


func _gather_reminder_lines() -> Array[String]:
	var lines: Array[String] = []
	if not GameManager.has_item("kobber"):
		lines.append("Kobberledning? Den ungen ved strømmasta har en.")
	if not GameManager.has_item("plast"):
		lines.append("Plast finner du i fiskadammen bak her.")
	if not GameManager.has_item("gummi"):
		lines.append("Gummi. Bildekk. Kratergata.")
	return lines


func _has_stoepsel_prop() -> bool:
	var nodes: Array = get_tree().get_nodes_in_group("StoepselProp")
	for node in nodes:
		if node is Node3D and (node as Node3D).visible:
			return true
	return false


func _player_carrying_stoepsel() -> bool:
	var player: Node = NetUtil.get_local_player()
	if player == null or not player.has_method("get_carried_object"):
		return false
	var carried: Variant = player.get_carried_object()
	return carried != null and (carried as Node).is_in_group("StoepselProp")


func _show_hk_lines(texts: Array[String], on_close: Callable = Callable()) -> void :
	var objs: Array = []
	for s in texts:
		var audio: AudioStream = LINE_SOUNDS.get(s) as AudioStream
		objs.append(_make_line(s, audio))
	_show_npc_dialogue(texts, objs, on_close)


func start_dance() -> void :
	if _dancing:
		return
	_dancing = true
	var base_y: float = position.y
	var tween: = create_tween()
	tween.set_loops(5)
	tween.tween_property(self, "position:y", base_y + 0.3, 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", base_y, 0.2).set_ease(Tween.EASE_IN)
	await tween.finished
	position.y = base_y
	_dancing = false
	dance_finished.emit()
	if GameManager.is_quest_completed("HVERDAGSKOMIKER"):
		_show_hk_lines(["Godt jobba, nå er strømmen tilbake!"])
