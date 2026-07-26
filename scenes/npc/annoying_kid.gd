extends "res://scenes/npc/npc_base.gd"

var _is_flat: bool = false
var _copper_given: bool = false

const BRUH_MOMENT_CHANCE: float = 0.2

const LINES_BRUH: Array[String] = [
	"Hehehehe, certified bruh moment", 
]

const LINES_WIRE: Array[String] = [
	"Jeg har en kobberledning, men du får den ikke.", 
	"Den er min.", 
]

const LINES_FLAT_GIVE: Array[String] = [
	"Au!", 
	"Beklager for at jeg var en liten dritt unge og ikke ga deg kobberledningen.", 
	"Jeg har lært leksen min.", 
]

const KID_AUDIO_PATH: String = "res://assets/sfx/erdetlyd/vox/kid/"

const KID_LINE_SOUNDS: Dictionary = {
	"Hehehehe, certified bruh moment":
		"kid_01_bruh_moment.ogg", 
	"Jeg har en kobberledning, men du får den ikke.":
		"kid_02_kobberledning.ogg", 
	"Den er min.":
		"kid_03_den_er_min.ogg", 
	"Au!":
		"kid_04_au.ogg", 
	"Beklager for at jeg var en liten dritt unge og ikke ga deg kobberledningen.":
		"kid_05_beklager.ogg", 
	"Jeg har lært leksen min.":
		"kid_06_laert_leksen.ogg", 
}


func _ready() -> void :
	npc_id = "annoying_kid"
	npc_name = "Gutt"
	add_to_group("AnnoyingKid")
	super._ready()
	_resync_kobber_hint.call_deferred()




func _resync_kobber_hint() -> void :
	if GameManager == null or not GameManager.kid_drawing_taken:
		return
	if GameManager.has_item("kobber"):
		return
	GameManager.set_objective_hint(
		"HVERDAGSKOMIKER", "collect_kobber", "Snakk med strømmasta"
	)


func _interact() -> void :
	if is_dead or GameManager.is_npc_dead(npc_id):
		return
	if DialogueUI.is_open():
		return

	var is_first_talk: = GameManager != null and not GameManager.has_talked_to_npc(npc_id)

	if GameManager.has_method("register_npc_talked"):
		GameManager.register_npc_talked(npc_id)

	if _copper_given or GameManager.has_item("kobber"):
		_copper_given = true
		_show_kid_dialogue(["Jeg lærte leksen min."], Callable())
		return

	if _is_flat:
		_show_kid_dialogue(LINES_FLAT_GIVE, Callable(_give_copper))
		return

	var lines: = LINES_WIRE.duplicate()
	if is_first_talk and randf() < BRUH_MOMENT_CHANCE:
		lines = LINES_BRUH + lines
	_show_kid_dialogue(lines, func() -> void :


		if GameManager != null and not GameManager.kid_drawing_taken:
			GameManager.set_objective_hint(
				"HVERDAGSKOMIKER", "collect_kobber", 
				"Ungen gir seg ikke. Undersøk tegningene ved strømmasta"
			)
	)


func flatten() -> void :
	if _is_flat:
		return
	_is_flat = true
	var model: = get_node_or_null("Model") as Node3D
	if model != null:
		var base_scale: Vector3 = model.scale
		var flat_scale: = Vector3(base_scale.x, base_scale.y * 0.15, base_scale.z)
		var tween: = create_tween()
		tween.set_parallel(true)
		tween.tween_property(model, "scale", flat_scale, 0.25)
		tween.tween_property(model, "position:y", -0.3, 0.25)
		return
	rotation_degrees.x = 90.0


func get_hit_by_mast() -> void :
	flatten()


func _give_copper() -> void :
	if _copper_given:
		return
	_copper_given = true
	if GameManager.has_item("kobber"):
		return
	GameManager.add_item("kobber", 1)
	var qs: = _get_quest_system()
	if qs and qs.has_method("on_item_collected"):
		qs.call("on_item_collected", "kobber", 1)


func _show_kid_dialogue(lines: Array[String], on_close: Callable) -> void :
	var objs: Array = []
	for s in lines:
		objs.append(_make_line(s, _get_kid_audio(s)))
	_show_npc_dialogue(lines, objs, on_close)


func _get_kid_audio(text: String) -> AudioStream:
	if not KID_LINE_SOUNDS.has(text):
		return null
	var path: String = KID_AUDIO_PATH + KID_LINE_SOUNDS[text]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream
