extends StaticBody3D

const FACE_IDLE: = preload("res://assets/textures/images/mast_face_idle.png")
const FACE_OPEN: = preload("res://assets/textures/images/mast_face_aapenmunn.png")
const FACE_TEETH: = preload("res://assets/textures/images/mast_face_tenner.png")
const FACE_TALK_INTERVAL: = 0.18
const ARM2_SHOW_DELAY: = 36.0

const LINES_TALK_1: Array[String] = [
	"Føkk han kidden, lil bro drepte meg nesten!", 
	"Ta også oppdra han kidden din litt bedre a! Så kan du stikke før eg gir deg og snørrungen din støt!", 
]

const LINES_TALK_2: Array[String] = [
	"Du er åpenbart en idiot, hørte du ikkje ka eg sa, ta også stikk vekk her fra!", 
	"Ikkje prøv å snakk til meg igjen for da vil du måtte smake på min VREDE!", 
]

const LINES_TALK_3: Array[String] = [
	"Ok, du ber om det, eg er nødt til å vise deg SoundCloud rappen min!", 
]

const LINES_TAUNT: Array[String] = [
	"Gå hjem og grin a din ekle faen.", 
	"Ja jeg ser du har våpen. Du er KJEEEEEEMPE kul. Du vet ikke hvordan du bruker den engang!", 
	"HAHAHAHAH! Taper.", 
]

const STROMMAST_AUDIO_PATH: String = "res://assets/sfx/erdetlyd/vox/strommast/"

const STROMMAST_LINE_SOUNDS: Dictionary = {
	"Føkk han kidden, lil bro drepte meg nesten!":
		"strommast_fuckhankiddenlilbrodreptemegnesten.ogg", 
	"Ta også oppdra han kidden din litt bedre a! Så kan du stikke før eg gir deg og snørrungen din støt!":
		"strommast_vergenhans.ogg", 
	"Du er åpenbart en idiot, hørte du ikkje ka eg sa, ta også stikk vekk her fra!":
		"strommast_aapenbartidiot.ogg", 
	"Ikkje prøv å snakk til meg igjen for da vil du måtte smake på min VREDE!":
		"strommast_ikkjeprovsnakktilmegigjenvrede.ogg", 
	"Ok, du ber om det, eg er nødt til å vise deg SoundCloud rappen min!":
		"strommast_beromdetsoundcloudrap.ogg", 
	"Gå hjem og grin a din ekle faen.":
		"strommast_hjemaagrineklefaen.ogg", 
	"Ja jeg ser du har våpen. Du er KJEEEEEEMPE kul. Du vet ikke hvordan du bruker den engang!":
		"strommast_serduharvaapen.ogg", 
	"HAHAHAHAH! Taper.":
		"strommast_hahaforbannataper.ogg", 
}

var _drawing_removed: bool = false
var _talk_count: int = 0
var _is_playing_rap: bool = false
var _has_fallen: bool = false
var _player_in_range: bool = false
var _face_material: StandardMaterial3D = null
var _face_talking: bool = false
var _face_mouth_open: bool = false
var _face_talk_timer: Timer = null
var _arm2_show_timer: Timer = null
var _dialogue_line_objs: Array = []
var _mast_vo_player: AudioStreamPlayer3D

@onready var _jbl: Node3D = get_node_or_null("JBLSpeaker")
@onready var _phone: Node3D = get_node_or_null("Phone")
@onready var _arm2: Node3D = get_node_or_null("Phone/arm2")
@onready var _player_name_label: Label3D = get_node_or_null("Phone/arm2/MeshInstance3D/PlayerName")
@onready var _rap_audio: AudioStreamPlayer3D = get_node_or_null("RapAudio")


func _ready() -> void :
	add_to_group("Strommast")
	add_to_group("HitableObjects")
	if _jbl != null:
		_jbl.visible = false
	if _phone != null:
		_phone.visible = false
	if _arm2 != null:
		_arm2.visible = false
	if _player_name_label != null:
		_player_name_label.text = str(GameManager.player_name)
	_setup_arm2_timer()
	_setup_mast_vo_player()
	if _rap_audio != null:
		_rap_audio.finished.connect(_on_rap_finished)
	_setup_face_material()
	_drawing_removed = GameManager.kid_drawing_taken
	var face: = _get_face_mesh()
	if face != null:
		face.visible = _drawing_removed
	if _drawing_removed:
		_reveal_face()
	var drawing: = get_node_or_null("Node3D/KidDrawing")
	if drawing != null and _drawing_removed:
		drawing.queue_free()
	var area: = get_node_or_null("InteractionArea") as Area3D
	if area:
		area.collision_layer = 0
		area.monitorable = false
		area.monitoring = true
		area.set_collision_mask_value(2, true)
		if not area.body_entered.is_connected(_on_body_entered):
			area.body_entered.connect(_on_body_entered)
		if not area.body_exited.is_connected(_on_body_exited):
			area.body_exited.connect(_on_body_exited)
	var label: = get_node_or_null("PromptLabel3D") as Label3D
	if label:
		label.visible = false
	if DialogueUI and not DialogueUI.dialogue_finished.is_connected(_update_prompt):
		DialogueUI.dialogue_finished.connect(_update_prompt)


func _setup_face_material() -> void :
	var face: = _get_face_mesh() as MeshInstance3D
	if face == null:
		return
	var mat: = face.get_active_material(0)
	if mat == null:
		return
	_face_material = mat.duplicate() as StandardMaterial3D
	face.set_surface_override_material(0, _face_material)
	_face_talk_timer = Timer.new()
	_face_talk_timer.name = "FaceTalkTimer"
	_face_talk_timer.wait_time = FACE_TALK_INTERVAL
	_face_talk_timer.timeout.connect(_on_face_talk_tick)
	add_child(_face_talk_timer)
	_set_face_texture(FACE_IDLE)


func _setup_arm2_timer() -> void :
	_arm2_show_timer = Timer.new()
	_arm2_show_timer.name = "Arm2ShowTimer"
	_arm2_show_timer.one_shot = true
	_arm2_show_timer.wait_time = ARM2_SHOW_DELAY
	_arm2_show_timer.timeout.connect(_show_arm2)
	add_child(_arm2_show_timer)


func _setup_mast_vo_player() -> void :
	_mast_vo_player = AudioStreamPlayer3D.new()
	_mast_vo_player.name = "MastDialogueAudio"
	_mast_vo_player.bus = "Voice"
	_mast_vo_player.max_distance = 18.0
	add_child(_mast_vo_player)


func _set_face_texture(tex: Texture2D) -> void :
	if _face_material != null:
		_face_material.albedo_texture = tex


func _start_face_talk() -> void :
	_face_talking = true
	_face_mouth_open = false
	_set_face_texture(FACE_IDLE)
	if _face_talk_timer != null:
		_face_talk_timer.start()


func _stop_face_talk() -> void :
	_face_talking = false
	if _face_talk_timer != null:
		_face_talk_timer.stop()
	_set_face_texture(FACE_IDLE)


func _on_face_talk_tick() -> void :
	if not _face_talking:
		return
	_face_mouth_open = not _face_mouth_open
	_set_face_texture(FACE_OPEN if _face_mouth_open else FACE_IDLE)


func _mast_dialogue(lines: Array, on_close: Callable = Callable()) -> void :
	var line_objs: Array = []
	for line in lines:
		line_objs.append(_make_mast_line(str(line)))
	_begin_mast_dialogue_audio(line_objs)
	_start_face_talk()
	var wrapped: = func() -> void :
		_clear_mast_dialogue_audio()
		_stop_face_talk()
		if on_close.is_valid():
			on_close.call()
	DialogueUI.show_dialogue(lines, "Strømmasta", wrapped)
	_update_prompt()


func _make_mast_line(line_text: String) -> DialogueLine:
	var dl: = DialogueLine.new()
	dl.text = line_text
	dl.sound = _get_strommast_audio(line_text)
	return dl


func _get_strommast_audio(text: String) -> AudioStream:
	if not STROMMAST_LINE_SOUNDS.has(text):
		return null
	var path: String = STROMMAST_AUDIO_PATH + STROMMAST_LINE_SOUNDS[text]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream


func _begin_mast_dialogue_audio(line_objs: Array) -> void :
	if DialogueUI.dialogue_line_shown.is_connected(_on_mast_line_shown):
		DialogueUI.dialogue_line_shown.disconnect(_on_mast_line_shown)
	DialogueUI.dialogue_line_shown.connect(_on_mast_line_shown)
	_dialogue_line_objs = line_objs.duplicate()


func _clear_mast_dialogue_audio() -> void :
	_dialogue_line_objs.clear()
	if DialogueUI != null and DialogueUI.dialogue_line_shown.is_connected(_on_mast_line_shown):
		DialogueUI.dialogue_line_shown.disconnect(_on_mast_line_shown)
	if _mast_vo_player != null:
		_mast_vo_player.stop()


func _on_mast_line_shown(index: int) -> void :
	if index < 0 or index >= _dialogue_line_objs.size():
		return
	var dl = _dialogue_line_objs[index]
	if dl == null or not (dl is DialogueLine):
		return
	var stream: AudioStream = (dl as DialogueLine).sound
	if stream == null or _mast_vo_player == null:
		return
	_mast_vo_player.stream = stream
	_mast_vo_player.play()


func _get_taunt_lines() -> Array:
	return LINES_TAUNT.duplicate()


func _get_face_mesh() -> Node3D:
	var face: = get_node_or_null("FaceMesh") as Node3D
	if face != null:
		return face
	return get_node_or_null("Node3D/FaceMesh") as Node3D


func _reveal_face() -> void :
	var face: = _get_face_mesh()
	if face != null:
		face.visible = true
	_set_face_texture(FACE_TEETH)


func on_drawing_removed() -> void :
	_drawing_removed = true
	_reveal_face()
	_update_prompt()


func _on_body_entered(body: Node3D) -> void :
	if body.is_in_group("PlayerCharacter"):
		_player_in_range = true
		_update_prompt()


func _on_body_exited(body: Node3D) -> void :
	if body.is_in_group("PlayerCharacter"):
		_player_in_range = false
		_update_prompt()


func _update_prompt() -> void :
	var label: = get_node_or_null("PromptLabel3D") as Label3D
	if label == null:
		return
	label.visible = (
		_player_in_range
		and _drawing_removed
		and not _has_fallen
		and not _is_playing_rap
		and (DialogueUI == null or not DialogueUI.is_open())
	)


func _input(event: InputEvent) -> void :
	if not event.is_action_pressed("interaction") or event.is_echo():
		return
	if not _player_in_range or _has_fallen or not _drawing_removed or _is_playing_rap:
		return
	if DialogueUI and DialogueUI.is_open():
		return
	if not _is_closest_interactable():
		return
	_interact()
	get_viewport().set_input_as_handled()


func _is_closest_interactable() -> bool:
	var player: = NetUtil.get_local_player() as Node3D
	if player == null:
		return true
	var my_dist: = global_position.distance_to(player.global_position)
	for npc in get_tree().get_nodes_in_group("NPC"):


		if not npc.get("in_range"):
			continue
		if not npc is Node3D:
			continue
		var other_dist: = (npc as Node3D).global_position.distance_to(player.global_position)
		if other_dist < my_dist:
			return false
	return true


func _interact() -> void :
	if not _drawing_removed or _is_playing_rap or _has_fallen:
		return
	_talk_count += 1
	match _talk_count:
		1:
			_mast_dialogue(LINES_TALK_1)
		2:
			_mast_dialogue(LINES_TALK_2)
		3:
			_mast_dialogue(LINES_TALK_3, Callable(_play_rap))
		_:
			_mast_dialogue(_get_taunt_lines())


func _play_rap() -> void :
	_is_playing_rap = true

	GameManager.set_objective_hint(
		"HVERDAGSKOMIKER", "collect_kobber", 
		"Masta viser ingen respekt. Gjør noe med det"
	)
	MusicManager.stop()
	_update_prompt()
	_hide_arm2()
	if _jbl != null:
		_jbl.visible = true
	if _phone != null:
		_phone.visible = true
	if _rap_audio != null:
		_rap_audio.play()
		if _arm2_show_timer != null:
			_arm2_show_timer.start()
	else:
		push_warning("[Strommast] RapAudio node not found")
		_on_rap_finished()


func _show_arm2() -> void :
	if _arm2 != null and _is_playing_rap:
		_arm2.visible = true


func _hide_arm2() -> void :
	if _arm2_show_timer != null:
		_arm2_show_timer.stop()
	if _arm2 != null:
		_arm2.visible = false


func _on_rap_finished() -> void :

	if AchievementManager != null:
		AchievementManager.unlock(AchievementManager.ACH_LISTEN_SONG)
	_is_playing_rap = false
	_hide_arm2()
	if _jbl != null:
		_jbl.visible = false
	if _phone != null:
		_phone.visible = false
	MusicManager.play("idle")
	_update_prompt()
	_mast_dialogue(_get_taunt_lines())


func take_damage(_amount: float = 0.0) -> void :
	if _has_fallen:
		return
	_has_fallen = true
	var area: = get_node_or_null("InteractionArea") as Area3D
	if area:
		area.monitoring = false
	_update_prompt()
	_fall()


func projectileHit(_propul_force: float, _propul_dir: Vector3) -> void :
	take_damage(1.0)


func hitscanHit(_propul_force: float, _propul_dir: Vector3, _propul_pos: Vector3) -> void :
	take_damage(1.0)


func _fall() -> void :
	_stop_face_talk()
	_clear_mast_dialogue_audio()
	_hide_arm2()
	if _rap_audio != null:
		_rap_audio.stop()
	_is_playing_rap = false
	MusicManager.play("idle")
	if _jbl != null:
		_jbl.visible = false
	if _phone != null:
		_phone.visible = false
	var tween: = create_tween()
	tween.tween_property(self, "rotation:z", rotation.z + PI * 0.5, 0.8)\
	.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await tween.finished
	SfxManager.play("gorgon_impact")


	var cam_rig: Node = get_tree().get_first_node_in_group("PlayerCamera")
	if cam_rig != null and cam_rig.has_method("add_shake"):
		cam_rig.add_shake(0.18, 0.5)
	var kid: Node = get_tree().get_first_node_in_group("AnnoyingKid")
	if kid != null and kid.has_method("flatten"):
		kid.flatten()
	GameManager.set_objective_hint(
		"HVERDAGSKOMIKER", "collect_kobber", "Snakk med ungen igjen"
	)
