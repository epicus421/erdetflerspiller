extends Node3D

const NPC_DEATH_VFX: PackedScene = preload("res://scenes/vfx/npc_death_vfx.tscn")
const HAPPINESS_VFX: PackedScene = preload("res://scenes/vfx/happiness_vfx.tscn")
const ENDING_OVERLAY: PackedScene = preload("res://scenes/ui/ending_overlay.tscn")


const GRANDPA_SILENT_QUEST_IDS: Array[String] = [
	"GRANDPA_REQUEST", 
	"GRANDPA_DISAPPOINTMENT", 
]

const IVER_AUDIO_PATH: String = "res://assets/sfx/erdetlyd/vox/iver/"

const IVER_LINE_SOUNDS: Dictionary = {
	"Jeg selger 'spesiell' grus.": "iver_idle_01.ogg", 
	"Iver har ingenting til deg akkurat nå.": "iver_idle_02.ogg", 
	"Jeg har ikke sett deg før?": "iver_offer_01.ogg", 
	"Du ønsker å kjøpe grusen min sier du?": "iver_offer_02.ogg", 
	"Er du kompis av Stein og Steinar?": "iver_offer_03.ogg", 
	"Ja det er du, jeg ser det på det livløse trynet ditt.": "iver_offer_04.ogg", 
	"Jeg selger ikke grusen min til Stein og Steinar lenger.": "iver_offer_05.ogg", 
	"De sa jeg ikke kunne benke 120 kg. Noe som jeg klarer btw.": "iver_offer_06.ogg", 
	"Uansett, jeg er en rimelig fyr.": "iver_offer_07.ogg", 
	"Hvis du lover å ikke gi grusen min til grusbrødrene, signerer denne kontrakten, henter meg 3 kråkefjær og 1 elgskinn så skal jeg gi deg grusen min gratis!": "iver_offer_08.ogg", 
	"Takk for signaturen!": "iver_sign_01.ogg", 
	"Her er pistolen min.": "iver_sign_02.ogg", 
	"Gå og slakt no dyr for meg nå :)": "iver_sign_03.ogg", 
	"Du finner dyr i skogen ved Elgveien.": "iver_sign_04.ogg", 
	"Gå og jakt på dyra i skogen.": "iver_hunt_01.ogg", 
	"Ikke kom tilbake før du har fått 1 elgskinn og 3 kråkefjær.": "iver_hunt_02.ogg", 
	"Du har ikke slaktet nok dyr. Kom tilbake med alt jeg ba om.": "iver_blocked_01.ogg", 
	"Kom tilbake senere.": "iver_blocked_02.ogg", 
	"Takk for fjær og skinn, nå blir det suppe.": "iver_complete_01.ogg", 
	"Her har du grus som takk.": "iver_complete_02.ogg", 
	"Ikke gi det til Stein og Steinar.": "iver_complete_03.ogg", 
	"Jeg orker ikke snakke.": "iver_gate_01.ogg", 
}

const KRIS_AUDIO_PATH: String = "res://assets/sfx/erdetlyd/vox/kristoffer/"

const KRIS_LINE_SOUNDS: Dictionary = {
	"Jeg hørte noen rykter fra en liten fugl at du har behov for litt penger.":
		"noenrykterfrafuglpenger.ogg", 
	"De forbanna steinene tok capsen min...":
		"forbannasteinertokcaps.ogg", 
	"Den uvurderlige Peak Performance-capsen min.":
		"uvurderligepeakperfcaps.ogg", 
	"Få tilbake capsen min, så lover jeg at du skal få en liten slant for arbeidet.":
		"faatilbakecapsslantforarbeid.ogg", 
	"Om ikke jeg tar feil, sitter de nok i garasjen sin inneklemt i et av Kratergatas mange ekle hjørner.":
		"omikkejegtarfeil.ogg", 
	"Tusen takk for at du fant den!":
		"heltnydeligfanttusentakk.ogg", 
	"Hent capsen min da!":
		"hentcapsenminadinlok.ogg", 
	"Jeg har ingenting til deg akkurat nå.":
		"beklagermeninentingaasi.ogg", 
	"Leit å høre om Mormoren din, men jeg orker ikke snakke nå.":
		"jadadetvarleit.ogg", 
	"Har du fortsatt ikke funnet den?":
		"hardufortsattikkefunnet.ogg", 
}


const IVER_AUDIO_LEGACY: Dictionary = {
	"iver_greet_01.ogg": "iver01.ogg", 
	"iver_idle_01.ogg": "iver01.ogg", 
}

@export_group("Identity")
@export var npc_id: String = ""
@export var npc_name: String = "NPC"
@export var npc_color: Color = Color(1, 1, 1, 1)
@export var invulnerable: bool = false
@export var character_model: PackedScene = preload("res://assets/props/Characters_psx/Models/Male/Character_06.glb")

@export_group("Quests")
@export var quests: Array[Quest] = []

@export_group("Dialogue")
@export var idle_dialogue: Array[String] = []

@export_group("Bank")
@export var bank_teller_mode: bool = false

@export_group("Payoff")
@export var happy_sound: AudioStream = null
@export var inhale_sound: AudioStream = null

@export_group("Reaksjoner")


@export var finger_react_sounds: Array[AudioStream] = []

@export_category("Audio")

@export var greeting_sound: AudioStream = null

@export var inheritance_misuse_sound: AudioStream = null

@export var quest_dialogue_sounds: Dictionary = {}

var model_mesh: MeshInstance3D
var model_root: Node3D
var interaction_area: Area3D
var name_label: Label3D
var health_component: Node

var in_range: bool = false
var current_quest: Quest = null
var is_dead: bool = false
var _player_ref: Node3D = null
var _original_materials: Array = []
var _is_flashing: bool = false
var _is_flat_grus: bool = false
var _grus_transform_done: bool = false

var _audio_player: AudioStreamPlayer3D
var _current_dialogue_lines: Array = []
var _bounce_tween: Tween = null
var _has_been_talked_to: bool = false

const FINGER_REACT_COOLDOWN: float = 5.0
var _last_finger_react_time: float = -9999.0
var _finger_react_index: int = 0
var _finger_react_audio: AudioStreamPlayer3D = null
var _bounce_base_y: float = 0.0
var _bounce_started: bool = false

func _ready() -> void :
	model_root = get_node_or_null("Model") as Node3D
	_setup_model()
	model_mesh = _find_mesh(model_root)
	name_label = _resolve_name_label()
	interaction_area = get_node_or_null("InteractionArea") as Area3D
	if interaction_area == null:
		interaction_area = get_node_or_null("Area3D") as Area3D
	health_component = get_node_or_null("HealthComponent")

	if name_label:
		name_label.text = "E — " + npc_name
		name_label.modulate = npc_color
		name_label.visible = false
		name_label.font_size = 36
		name_label.pixel_size = 0.003
		name_label.outline_size = 12
		name_label.outline_modulate = Color(0, 0, 0, 1)
		name_label.no_depth_test = true

	if interaction_area:
		_ensure_unique_interaction_shape()
		interaction_area.monitorable = false
		interaction_area.body_entered.connect(_on_area_3d_body_entered)
		interaction_area.body_exited.connect(_on_area_3d_body_exited)

	if health_component:
		health_component.on_death.connect(_on_npc_death)
		if health_component.has_signal("on_damage_taken"):
			health_component.on_damage_taken.connect(_on_hit)
		add_to_group("NPC")

	add_to_group("StoryNPC")
	add_to_group("FingerReactable")

	_audio_player = AudioStreamPlayer3D.new()
	_audio_player.name = "NPCDialogueAudio"
	add_child(_audio_player)
	_audio_player.max_distance = 30.0
	_audio_player.unit_size = 7.0
	_audio_player.bus = "Voice"
	_apply_npc_vo_volume()

	if not DialogueUI.dialogue_finished.is_connected(_on_dialogue_ui_finished):
		DialogueUI.dialogue_finished.connect(_on_dialogue_ui_finished)
	if GameManager and GameManager.has_signal("game_reset") and not GameManager.game_reset.is_connected(_on_game_reset):
		GameManager.game_reset.connect(_on_game_reset)

	if npc_id == "steinar":
		quest_dialogue_sounds = GrusBrothersVO.steinar_sounds()
	elif npc_id == "stein":
		quest_dialogue_sounds = GrusBrothersVO.stein_sounds()
	elif npc_id == "iver":
		_apply_iver_greeting_sound()
	elif npc_id == "kris":
		_apply_kris_greeting_sound()

	if npc_id == "kris":
		_bounce_base_y = position.y
		if _should_kris_bounce():
			_start_bounce()

	if npc_id == "steinar":
		_sync_stein_cap_visual()


func _should_kris_bounce() -> bool:
	if _has_been_talked_to:
		return false
	if GameManager == null:
		return false
	if GameManager.has_quest("KRIS_LUA"):
		return false
	return GameManager.visited_store_during_second_ice


func _start_bounce() -> void :
	_bounce_started = true
	if _bounce_tween != null:
		_bounce_tween.kill()
	position.y = _bounce_base_y
	_bounce_tween = create_tween()
	_bounce_tween.set_loops()
	_bounce_tween.tween_property(self, "position:y", _bounce_base_y + 0.55, 0.15)\
	.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_bounce_tween.tween_property(self, "position:y", _bounce_base_y, 0.12)\
	.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	if not has_node("BounceAudio"):
		var bounce_audio: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		bounce_audio.name = "BounceAudio"
		var path: String = "res://assets/sfx/erdetlyd/vox/kristoffer/screamingloop.ogg"
		if ResourceLoader.exists(path):
			var stream: AudioStream = load(path)
			stream = stream.duplicate()
			stream.loop = true
			bounce_audio.stream = stream
			bounce_audio.max_distance = 20.0
			bounce_audio.volume_db = -3.0
			bounce_audio.bus = "Voice"
		add_child(bounce_audio)
		bounce_audio.play()
	_show_exclaim()


func _show_exclaim() -> void :
	if npc_id != "kris":
		return
	var exclaim: = get_node_or_null("ExclaimLabel") as Label3D
	if exclaim == null:
		exclaim = Label3D.new()
		exclaim.name = "ExclaimLabel"
		exclaim.text = "!"
		exclaim.font_size = 64
		exclaim.modulate = Color(1, 0, 0)
		exclaim.position = Vector3(0, 2.5, 0)
		exclaim.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		exclaim.pixel_size = 0.005
		add_child(exclaim)
	exclaim.visible = true


func _hide_exclaim() -> void :
	var exclaim: = get_node_or_null("ExclaimLabel") as Label3D
	if exclaim:
		exclaim.visible = false


func _stop_bounce() -> void :
	if _bounce_tween != null:
		_bounce_tween.kill()
		_bounce_tween = null
	position.y = _bounce_base_y
	if has_node("BounceAudio"):
		$BounceAudio.stop()
		$BounceAudio.queue_free()
	_hide_exclaim()


func _process(delta: float) -> void :
	if npc_id == "kris" and not _bounce_started and _should_kris_bounce():
		_start_bounce()
	if _is_flat_grus:
		return
	if is_dead:
		return
	if GameManager.is_npc_dead(npc_id):
		return
	if _player_ref == null or not is_instance_valid(_player_ref):
		_player_ref = GameManager.get_player()
	if _player_ref == null:
		return
	var to_player: = _player_ref.global_position - global_position
	to_player.y = 0.0
	if to_player.length_squared() <= 0.0001:
		return
	var desired: = atan2( - to_player.x, - to_player.z)
	rotation.y = lerp_angle(rotation.y, desired, clamp(delta * 6.0, 0.0, 1.0))


func _resolve_name_label() -> Label3D:
	var l: = get_node_or_null("NameLabel") as Label3D
	if l:
		return l
	return get_node_or_null("Area3D/Label3D") as Label3D


func _setup_model() -> void :
	if character_model == null:
		return
	if model_root == null:
		return
	for child in model_root.get_children():
		child.queue_free()

	var instance: = character_model.instantiate()
	model_root.add_child(instance)

	var path: String = character_model.resource_path
	if path.ends_with(".tscn"):
		_disable_model_collisions(instance)
		return

	var mesh_instance: = _find_mesh(instance)
	if mesh_instance == null:
		return
	var aabb: = mesh_instance.get_aabb()
	if aabb.size.y <= 0.0:
		return
	var factor: = 1.95 / aabb.size.y
	if instance is Node3D:
		var n: = instance as Node3D
		n.scale = Vector3(factor, factor, factor)
		n.rotation_degrees.y = 180.0
		n.position = Vector3(
			- (aabb.position.x + aabb.size.x * 0.5) * factor, 
			- (aabb.position.y + aabb.size.y * 0.5) * factor, 
			- (aabb.position.z + aabb.size.z * 0.5) * factor
		)

func _disable_model_collisions(node: Node) -> void :
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true
	if node is CollisionObject3D:
		var co: = node as CollisionObject3D
		co.collision_layer = 0
		co.collision_mask = 0
	if node is Area3D:
		var area: = node as Area3D
		area.monitoring = false
		area.monitorable = false
	for child in node.get_children():
		_disable_model_collisions(child)


func _on_dialogue_ui_finished() -> void :
	_clear_dialogue_line_audio()


func _get_npc_vo_volume() -> float:
	match npc_id:
		"steinar", "stein":
			return 20.0
		"kris":
			return 3.0
		"iver":
			return 2.0
		_:
			return 0.0


func _apply_npc_vo_volume() -> void :
	if _audio_player == null:
		return
	_audio_player.volume_db = _get_npc_vo_volume()
	if npc_id in ["steinar", "stein"]:
		_audio_player.unit_size = 8.0
		_audio_player.max_distance = 20.0


func _play_greeting() -> void :
	if greeting_sound == null:
		return
	_apply_npc_vo_volume()
	_audio_player.stream = greeting_sound
	_audio_player.play()


func _get_iver_audio(text: String) -> AudioStream:
	if npc_id != "iver":
		return null
	if not IVER_LINE_SOUNDS.has(text):
		return null
	var file_name: String = IVER_LINE_SOUNDS[text]
	var path: String = IVER_AUDIO_PATH + file_name
	if not ResourceLoader.exists(path):
		var legacy_name: String = IVER_AUDIO_LEGACY.get(file_name, "")
		if legacy_name.is_empty():
			return null
		path = IVER_AUDIO_PATH + legacy_name
		if not ResourceLoader.exists(path):
			return null
	return load(path) as AudioStream


func _apply_iver_greeting_sound() -> void :
	var path: String = IVER_AUDIO_PATH + "iver_greet_01.ogg"
	if not ResourceLoader.exists(path):
		path = IVER_AUDIO_PATH + IVER_AUDIO_LEGACY.get("iver_greet_01.ogg", "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	greeting_sound = load(path) as AudioStream


func _get_kris_audio(text: String) -> AudioStream:
	if npc_id != "kris":
		return null
	if not KRIS_LINE_SOUNDS.has(text):
		return null
	var path: String = KRIS_AUDIO_PATH + KRIS_LINE_SOUNDS[text]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream


func _apply_kris_greeting_sound() -> void :
	var path: String = KRIS_AUDIO_PATH + "kris01.ogg"
	if not ResourceLoader.exists(path):
		return
	greeting_sound = load(path) as AudioStream


func _make_line(line_text: String, sound: AudioStream) -> DialogueLine:
	var stream: = sound
	if stream == null:
		stream = _get_iver_audio(line_text)
	if stream == null:
		stream = _get_kris_audio(line_text)
	var dl: = DialogueLine.new()
	dl.text = line_text
	dl.sound = stream
	return dl


func _set_dialogue_sounds_for_quest(sound_key: String, line_objs: Array) -> void :
	if sound_key.is_empty() or line_objs.is_empty():
		return
	if not quest_dialogue_sounds.has(sound_key):
		return
	var streams_val: Variant = quest_dialogue_sounds[sound_key]
	if not (streams_val is Array):
		return
	var streams: Array = streams_val
	for i in range(line_objs.size()):
		if i >= streams.size():
			break
		var st: Variant = streams[i]
		if st == null or not (st is AudioStream):
			continue
		var item: Variant = line_objs[i]
		if item is DialogueLine:
			(item as DialogueLine).sound = st as AudioStream


func _get_lines_for_quest(quest: Quest, use_completion: bool) -> Array:
	var lines: Array = []
	var source: Array[DialogueLine] = quest.completion_lines if use_completion else quest.offer_lines
	if not source.is_empty():
		for item in source:
			if item is DialogueLine:
				lines.append(item)
		return lines
	var strings: Array[String] = quest.completion_dialogue if use_completion else quest.offer_dialogue
	for s in strings:
		lines.append(_make_line(s, null))
	return lines


func _dialogue_line_texts(line_objs: Array) -> Array[String]:
	var texts: Array[String] = []
	for dl in line_objs:
		if dl is DialogueLine:
			texts.append((dl as DialogueLine).text)
	return texts


func _ensure_line_objects_from_quest_offer(quest: Quest, empty_fallback: Array[String]) -> Array:
	var line_objs: = _get_lines_for_quest(quest, false)
	var texts: = _dialogue_line_texts(line_objs)
	if texts.is_empty():
		texts = _dialogue_or_fallback(quest.offer_dialogue, empty_fallback)
		line_objs.clear()
		for s in texts:
			line_objs.append(_make_line(s, null))
	return line_objs


func _ensure_line_objects_from_quest_completion(quest: Quest, empty_fallback: Array[String]) -> Array:
	var line_objs: = _get_lines_for_quest(quest, true)
	var texts: = _dialogue_line_texts(line_objs)
	if texts.is_empty():
		texts = _dialogue_or_fallback(quest.completion_dialogue, empty_fallback)
		line_objs.clear()
		for s in texts:
			line_objs.append(_make_line(s, null))
	return line_objs


func _line_objs_have_audio(line_objs: Array) -> bool:
	for item in line_objs:
		if item is DialogueLine and (item as DialogueLine).sound != null:
			return true
	return false


func _begin_dialogue_line_audio(line_objs: Array) -> void :
	if DialogueUI.dialogue_line_shown.is_connected(_on_line_shown):
		DialogueUI.dialogue_line_shown.disconnect(_on_line_shown)
	DialogueUI.dialogue_line_shown.connect(_on_line_shown)
	_current_dialogue_lines = line_objs.duplicate()
	var skip_greeting: = _line_objs_have_audio(line_objs) and npc_id in ["grandpa", "iver", "steinar", "stein"]
	if not skip_greeting:
		_play_greeting()


func _clear_dialogue_line_audio() -> void :
	_current_dialogue_lines.clear()
	if DialogueUI.dialogue_line_shown.is_connected(_on_line_shown):
		DialogueUI.dialogue_line_shown.disconnect(_on_line_shown)


func _on_line_shown(index: int) -> void :
	if index < 0 or index >= _current_dialogue_lines.size():
		return
	var dl = _current_dialogue_lines[index]
	if dl == null or not (dl is DialogueLine):
		return
	var stream: AudioStream = (dl as DialogueLine).sound
	if stream == null:
		return
	_apply_npc_vo_volume()
	_audio_player.stream = stream
	_audio_player.play()


func _show_npc_dialogue(texts: Array, line_objs: Array, on_close: Callable = Callable()) -> void :
	_begin_dialogue_line_audio(line_objs)
	DialogueUI.show_dialogue(texts, npc_name, on_close)


func _find_mesh(node: Node) -> MeshInstance3D:
	if node == null:
		return null
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found: = _find_mesh(child)
		if found != null:
			return found
	return null


func _input(_event: InputEvent) -> void :
	if is_dead:
		return
	if GameManager.is_npc_dead(npc_id):
		return
	if not in_range:
		return
	if GameManager.has_method("is_minigame_active") and GameManager.is_minigame_active():
		return
	if DialogueUI.is_open():
		return
	if not Input.is_action_just_pressed("interaction"):
		return
	if not _is_closest_npc_in_range():
		return
	_interact()


func _is_closest_npc_in_range() -> bool:
	var player: = GameManager.get_player() as Node3D
	if player == null:
		return true
	var my_dist: = global_position.distance_to(player.global_position)
	for npc in get_tree().get_nodes_in_group("NPC"):
		if npc == self:
			continue


		if npc.get("in_range") != true:
			continue
		if not npc is Node3D:
			continue
		var other_dist: = (npc as Node3D).global_position.distance_to(player.global_position)
		if other_dist < my_dist:
			return false
	return true


func _interact() -> void :
	if is_dead:
		return
	if GameManager.is_npc_dead(npc_id):
		return
	if DialogueUI.is_open():
		return

	var _gated_npc_ids: Array[String] = ["kris", "iver", "steinar", "stein"]
	if npc_id in _gated_npc_ids:
		if GameManager and GameManager.has_method("is_quest_completed") and not GameManager.is_quest_completed("BANK_DEPOSIT"):
			var gated_line: = "Jeg orker ikke snakke."
			if npc_id == "kris":
				gated_line = "Leit å høre om Mormoren din, men jeg orker ikke snakke nå."
			elif npc_id == "steinar":
				gated_line = "Er det galt å gå med caps der det står peakperformance på?"
			elif npc_id == "stein":
				gated_line = "Sjekk ut den fete capsen til Steinar a!"
			var gated_lines: Array[String] = [gated_line]
			var gated_objs: Array = [_make_line(gated_line, null)]
			_set_dialogue_sounds_for_quest("GATED_PRE_BANK", gated_objs)
			_show_npc_dialogue(gated_lines, gated_objs, Callable())
			return

	if npc_id == "kris":
		_stop_bounce()
		_has_been_talked_to = true

	var _update_kris_hat_on_stein_talk: = (
		npc_id == "stein"
		and GameManager != null
		and GameManager.has_active_quest("KRIS_LUA")
		and not GameManager.has_talked_to_npc("stein")
	)

	if GameManager and GameManager.has_method("register_npc_talked"):
		GameManager.register_npc_talked(npc_id)

	if npc_id == "grandpa":
		AchievementManager.unlock("ACH_GRANDPA")

	if bank_teller_mode:
		_begin_dialogue_line_audio([])
		_show_bank_menu()
		return

	if npc_id == "grandpa" and GameManager.inheritance_spent_on_non_ice_cream:
		var misuse: = (
			"Du kjøpte ikke is? Selg lemonade da. Bygg standet ute."
		)
		var misuse_lines: Array = [_make_line(misuse, inheritance_misuse_sound)]
		_show_npc_dialogue([misuse], misuse_lines, Callable())
		return

	if npc_id == "iver":
		var talked_to_brothers: = (
			_player_has_talked_to_npc("steinar")
			or _player_has_talked_to_npc("stein")
			or GameManager.has_active_quest("IVER_BEVIS")
			or GameManager.is_quest_completed("IVER_BEVIS")
		)
		if not talked_to_brothers:
			var grus_line: = _make_line("Jeg selger 'spesiell' grus.", null)
			_show_npc_dialogue(["Jeg selger 'spesiell' grus."], [grus_line], Callable())
			return

	var npc_active_quests = _get_active_quests_for_npc()
	if not npc_active_quests.is_empty():
		for quest in npc_active_quests:
			if _is_delivery_ready_for_turn_in(quest):
				_show_completion_and_turn_in(quest)
				return
			if quest.quest_id in GameManager.NPC_TURN_IN_QUEST_IDS:
				_update_talk_objective_if_needed(quest)
			if quest.is_complete():
				if _can_turn_in_quest(quest):
					call_deferred("_show_completion_and_turn_in", quest)
				else:
					var blocked_turn: = _get_turn_in_blocked_dialogue(quest)
					var bt_objs: Array = []
					for s in blocked_turn:
						bt_objs.append(_make_line(s, null))
					_set_dialogue_sounds_for_quest("BLOCKED_TURN_IN", bt_objs)
					_show_npc_dialogue(blocked_turn, bt_objs, Callable())
				return
		for quest in npc_active_quests:
			if quest.quest_id == "FINAL_DELIVERY":
				if _can_turn_in_quest(quest):
					_update_talk_objective_if_needed(quest)
					_show_completion_and_turn_in(quest)
					return
		var first_quest = npc_active_quests[0]
		if first_quest.quest_id in GRANDPA_SILENT_QUEST_IDS:
			if _grandpa_silent_talk_done(first_quest):
				if first_quest.is_complete():
					_try_complete_without_turn_in_dialogue(first_quest)
				return
			var gp_objs: = _ensure_line_objects_from_quest_offer(first_quest, [])
			_set_dialogue_sounds_for_quest(first_quest.quest_id, gp_objs)
			var gp_texts: = _dialogue_line_texts(gp_objs)
			_show_npc_dialogue(
				gp_texts, 
				gp_objs, 
				func():
					_update_talk_objective_if_needed(first_quest)
					if first_quest.is_complete():
						_try_complete_without_turn_in_dialogue(first_quest)
			)
			return
		if first_quest.quest_id == "IVER_BEVIS" and _iver_bevis_needs_hunting(first_quest):
			var hunt_lines: Array[String] = [
				"Gå og jakt på dyra i skogen.", 
				"Ikke kom tilbake før du har fått 1 elgskinn og 3 kråkefjær.", 
			]
			var hunt_objs: Array = []
			for s in hunt_lines:
				hunt_objs.append(_make_line(s, null))
			_show_npc_dialogue(hunt_lines, hunt_objs, Callable())
			return
		if npc_id == "kris" and first_quest.quest_id == "KRIS_LUA" and _kris_lua_needs_hat(first_quest):
			var reminder_lines: Array[String] = ["Har du fortsatt ikke funnet den?"]
			var reminder_objs: Array = [_make_line(reminder_lines[0], null)]
			_set_dialogue_sounds_for_quest("KRIS_LUA_REMINDER", reminder_objs)
			_show_npc_dialogue(reminder_lines, reminder_objs, Callable())
			return
		var replay_objs: = _ensure_line_objects_from_quest_offer(
			first_quest, 
			["*du snakker med " + npc_name + "*"]
		)
		_set_dialogue_sounds_for_quest(first_quest.quest_id, replay_objs)
		var replay_texts: = _dialogue_line_texts(replay_objs)
		_show_npc_dialogue(
			replay_texts, 
			replay_objs, 
			func():
				var changed: bool = _update_talk_objective_if_needed(first_quest)
				if not changed or not first_quest.is_complete():
					return
				if first_quest.quest_id in GameManager.NPC_TURN_IN_QUEST_IDS:
					if _can_turn_in_quest(first_quest):
						call_deferred("_show_completion_and_turn_in", first_quest)
					else:
						push_warning("Quest %s complete but turn-in requirements not met." % first_quest.quest_id)
				else:
					_try_complete_without_turn_in_dialogue(first_quest)
		)
		return

	var available_quests = _get_available_quests()
	if available_quests.is_empty():
		if bank_teller_mode:
			_begin_dialogue_line_audio([])
			_show_bank_menu()
			return
		var blocked: = _blocked_prerequisite_dialogue()
		if not blocked.is_empty():
			if npc_id == "grandpa":
				_show_idle_dialogue()
				return
			var bl_objs: Array = []
			for s in blocked:
				bl_objs.append(_make_line(s, null))
			_set_dialogue_sounds_for_quest("BLOCKED_PREREQ", bl_objs)
			_show_npc_dialogue(blocked, bl_objs, Callable())
			return
		if npc_id == "stein" and GameManager.has_quest("STEINAR_GRUS"):
			var stein_grus_hint: Array[String] = ["Lever grusen til Steinar, så gir han deg capsen."]
			var sg_objs: Array = [_make_line(stein_grus_hint[0], null)]
			_set_dialogue_sounds_for_quest("STEINAR_GRUS_STEIN", sg_objs)
			_show_npc_dialogue(stein_grus_hint, sg_objs, Callable())
			return
		if (npc_id == "steinar" or npc_id == "stein") and GameManager.has_active_quest("KRIS_LUA"):
			var kris_hint_lines: Array[String] = [
				"Ja vi har capsen til Kristoffer, men du får den ikke gratis.", 
				"Vi vil gRUSE oss men Iver vil ikke selge grus til oss fordi vi såret følelsene hans.", 
				"Hvis du skaffer oss litt digg grus fra Iver får du capsen.", 
			]
			var kh_objs: Array = []
			for s in kris_hint_lines:
				kh_objs.append(_make_line(s, null))
			_set_dialogue_sounds_for_quest("KRIS_LUA_HINT", kh_objs)
			_show_npc_dialogue(kris_hint_lines, kh_objs, Callable())
			if _update_kris_hat_on_stein_talk:
				_update_kris_lua_find_hat_after_stein_talk()
			return
		_show_idle_dialogue()
	else:
		_offer_quest(available_quests[0])


func _show_idle_dialogue() -> void :
	var lines: = idle_dialogue
	if lines.is_empty():
		if npc_id == "iver":
			lines = ["Iver har ingenting til deg akkurat nå."]
		elif npc_id == "kris":
			lines = ["Jeg har ingenting til deg akkurat nå."]
		else:
			lines = ["Hei, " + npc_name + " har ingenting til deg akkurat nå."]
	var idle_objs: Array = []
	for s in lines:
		idle_objs.append(_make_line(s, null))
	_set_dialogue_sounds_for_quest("IDLE", idle_objs)
	_show_npc_dialogue(lines, idle_objs, Callable())


func _update_kris_lua_find_hat_after_stein_talk() -> void :
	if GameManager == null or not GameManager.has_active_quest("KRIS_LUA"):
		return
	var quest: Quest = GameManager.active_quests.get("KRIS_LUA") as Quest
	if quest == null:
		return
	for objective in quest.objectives:
		if objective == null:
			continue
		if objective.objective_id == "find_hat":
			objective.description = "Finn og skaff grus fra Iver"
			GameManager.quest_progress_updated.emit("KRIS_LUA", quest.get_total_progress())
			return


func _is_quest_available(quest: Quest) -> bool:
	if not GameManager:
		return false

	if GameManager.is_quest_completed(quest.quest_id):
		return false

	if GameManager.has_active_quest(quest.quest_id):
		return false

	for required_id in quest.required_quest_ids:
		if not GameManager.is_quest_completed(required_id):
			return false

	return true


func _get_available_quests() -> Array[Quest]:
	var available: Array[Quest] = []
	for quest in quests:
		if _is_quest_available(quest):
			available.append(quest)
	return available


func _blocked_prerequisite_dialogue() -> Array[String]:
	if not GameManager or quests.is_empty():
		return []
	for quest in quests:
		if GameManager.is_quest_completed(quest.quest_id):
			continue
		if GameManager.has_active_quest(quest.quest_id):
			continue
		for req_id in quest.required_quest_ids:
			if GameManager.is_quest_completed(req_id):
				continue
			if npc_id == "steinar":
				return ["Snakk med Stein."]
			return ["Kom tilbake senere."]
	return []


func _offer_quest(quest: Quest) -> void :
	current_quest = quest
	if GameManager.active_quests.is_empty() and not GameManager.has_active_quest(quest.quest_id):
		GameManager.add_quest_by_id(quest.quest_id)
	var line_objs: = _ensure_line_objects_from_quest_offer(
		quest, 
		["Vil du akseptere oppdraget: " + quest.name + "?"]
	)
	_set_dialogue_sounds_for_quest(quest.quest_id, line_objs)
	var quest_dialogue: = _dialogue_line_texts(line_objs)

	_show_npc_dialogue(
		quest_dialogue, 
		line_objs, 
		func():
			if current_quest == null:
				return
			var offered_quest_id: = current_quest.quest_id
			var quest_snapshot: Quest = current_quest
			current_quest = null
			if offered_quest_id == "IVER_BEVIS":
				_start_iver_petisjon_minigame(quest_snapshot)
			else:
				_finalize_quest_offer_accept(quest_snapshot, offered_quest_id)
	)


func _start_iver_petisjon_minigame(quest: Quest) -> void :
	var scene: PackedScene = load("res://scenes/minigames/iver_petisjon.tscn") as PackedScene
	if scene == null:
		push_error("Missing iver_petisjon.tscn")
		_finalize_quest_offer_accept(quest, quest.quest_id)
		return
	var pet: Node = scene.instantiate()
	var root: = get_tree().current_scene
	if root == null:
		root = get_tree().root
	root.add_child(pet)
	if pet.has_signal("signed"):
		pet.signed.connect( func():
			var thanks_lines: Array[String] = [
				"Takk for signaturen!", 
				"Her er pistolen min.", 
				"Gå og slakt no dyr for meg nå :)", 
				"Du finner dyr i skogen ved Elgveien.", 
			]
			var thanks_objs: Array = []
			for s in thanks_lines:
				thanks_objs.append(_make_line(s, null))
			_show_npc_dialogue(thanks_lines, thanks_objs, func():
				_finalize_quest_offer_accept(quest, quest.quest_id)
			)
		)


func _finalize_quest_offer_accept(quest: Quest, offered_quest_id: String) -> void :
	if not GameManager.has_active_quest(offered_quest_id):
		if not GameManager.add_quest_by_id(quest.quest_id):
			return
	if offered_quest_id == "IVER_BEVIS":
		_give_iver_pistol()
		var iver_quest: Quest = GameManager.active_quests.get("IVER_BEVIS") as Quest
		if iver_quest != null:
			GameManager._backfill_gather_objectives(iver_quest)
	var active_quest: Quest = GameManager.active_quests.get(offered_quest_id) as Quest
	if active_quest == null:
		return
	if not _update_talk_objective_if_needed(active_quest) or not active_quest.is_complete():
		return
	if active_quest.quest_id in GameManager.NPC_TURN_IN_QUEST_IDS and _can_turn_in_quest(active_quest):
		_show_completion_and_turn_in(active_quest)
	elif active_quest.quest_id not in GameManager.NPC_TURN_IN_QUEST_IDS:
		_try_complete_without_turn_in_dialogue(active_quest)


func _grandpa_silent_talk_done(quest: Quest) -> bool:
	if quest == null:
		return false
	for objective in quest.objectives:
		if objective == null:
			continue
		if objective.type != QuestObjective.ObjectiveType.TALK_TO_NPC:
			continue
		if objective.target_id != npc_id:
			continue
		var current: = int(quest.objective_progress.get(objective.objective_id, 0))
		return current >= objective.target_amount
	return false


func _try_complete_without_turn_in_dialogue(quest: Quest) -> bool:
	if quest == null or GameManager == null:
		return false
	if quest.quest_id in GameManager.NPC_TURN_IN_QUEST_IDS:
		return false
	var live: Quest = GameManager.active_quests.get(quest.quest_id) as Quest
	if live == null or not live.is_complete():
		return false
	GameManager.complete_quest_by_id(live.quest_id)
	for i in range(quests.size() - 1, -1, -1):
		var q: Quest = quests[i]
		if q != null and q.quest_id == quest.quest_id:
			quests.remove_at(i)
	return true


func _get_active_quests_for_npc() -> Array[Quest]:
	var matches: Array[Quest] = []
	for quest in GameManager.get_active_quests():
		if _quest_targets_this_npc(quest):
			matches.append(quest)
	return matches


func _quest_targets_this_npc(quest: Quest) -> bool:
	if quest.quest_id == "STEINAR_GRUS":
		return npc_id == "steinar"
	for objective in quest.objectives:
		if objective == null:
			continue
		if objective.type == QuestObjective.ObjectiveType.TALK_TO_NPC and objective.target_id == npc_id:
			return true
		if objective.type == QuestObjective.ObjectiveType.DELIVER and objective.target_id.begins_with(npc_id + ":"):
			return true
	if quest.quest_id == "FINAL_DELIVERY" and npc_id == "grandpa":
		return true
	if quest.quest_id == "IVER_BEVIS" and npc_id == "iver":
		return true
	return false


func _update_talk_objective_if_needed(quest: Quest) -> bool:
	var changed = false
	for objective in quest.objectives:
		if objective == null:
			continue
		if objective.type != QuestObjective.ObjectiveType.TALK_TO_NPC:
			continue
		if objective.target_id != npc_id:
			continue
		if quest.quest_id == "IVER_BEVIS" and objective.objective_id == "deliver_skins_to_iver":
			var f_prog: = int(quest.objective_progress.get("collect_fugleskinn", 0))
			var e_prog: = int(quest.objective_progress.get("collect_elgskinn", 0))
			if f_prog < 3 or e_prog < 1:
				continue
			if not GameManager.has_item("fugleskinn", 3) or not GameManager.has_item("elgskinn", 1):
				continue
		if quest.quest_id == "KRIS_LUA" and objective.objective_id == "return_lua_to_kris":
			if int(quest.objective_progress.get("find_hat", 0)) < 1:
				continue
			if not GameManager.has_item("peak_performance_lua", 1):
				continue
		var current = int(quest.objective_progress.get(objective.objective_id, 0))
		if current < objective.target_amount:
			quest.update_objective(objective.objective_id, 1)
			GameManager.quest_progress_updated.emit(quest.quest_id, quest.get_total_progress())
			changed = true
	return changed


func _can_turn_in_quest(quest: Quest) -> bool:
	if quest.quest_id == "FINAL_DELIVERY":
		return GameManager.has_item("icecream", 2)
	if quest.quest_id == "STEINAR_GRUS":
		if npc_id != "steinar":
			return false
		return GameManager.has_item("grus", 1)
	if quest.quest_id == "KRIS_LUA":
		return GameManager.has_item("peak_performance_lua", 1)
	if quest.quest_id == "IVER_BEVIS":
		return GameManager.has_item("fugleskinn", 3) and GameManager.has_item("elgskinn", 1)
	return true


func _is_delivery_ready_for_turn_in(quest: Quest) -> bool:
	if quest == null:
		return false
	for objective in quest.objectives:
		if objective == null:
			continue
		if objective.type != QuestObjective.ObjectiveType.DELIVER:
			continue
		if not objective.target_id.begins_with(npc_id + ":"):
			continue
		var current: = int(quest.objective_progress.get(objective.objective_id, 0))
		if current >= objective.target_amount:
			return true
		return _can_turn_in_quest(quest)
	return false


func _iver_bevis_needs_hunting(quest: Quest) -> bool:
	if quest == null or quest.quest_id != "IVER_BEVIS":
		return false
	var f_prog: = int(quest.objective_progress.get("collect_fugleskinn", 0))
	var e_prog: = int(quest.objective_progress.get("collect_elgskinn", 0))
	return f_prog < 3 or e_prog < 1


func _kris_lua_needs_hat(quest: Quest) -> bool:
	if quest == null or quest.quest_id != "KRIS_LUA":
		return false
	return int(quest.objective_progress.get("find_hat", 0)) < 1


func _get_turn_in_blocked_dialogue(quest: Quest) -> Array[String]:
	if quest.quest_id == "FINAL_DELIVERY":
		return ["Du mangler is. Kom tilbake med to is."]
	if quest.quest_id == "IVER_BEVIS":
		return ["Du har ikke slaktet nok dyr. Kom tilbake med alt jeg ba om."]
	if quest.quest_id == "KRIS_LUA":
		return ["Hent capsen min da!"]
	return ["Du mangler fortsatt noe før dette kan leveres inn."]


func _show_completion_and_turn_in(quest: Quest) -> void :
	if quest.quest_id not in GameManager.NPC_TURN_IN_QUEST_IDS:
		_try_complete_without_turn_in_dialogue(quest)
		return
	var line_objs: = _ensure_line_objects_from_quest_completion(quest, [])
	_set_dialogue_sounds_for_quest(quest.quest_id + "_COMPLETE", line_objs)
	var completion_dialogue: = _dialogue_line_texts(line_objs)
	if completion_dialogue.is_empty():
		if not GameManager.is_quest_completed(quest.quest_id):
			_prepare_turn_in_rewards(quest)
			GameManager.complete_quest_by_id(quest.quest_id)
			quests.erase(quest)
		return
	if quest.quest_id == "FINAL_DELIVERY":


		if not GameManager.is_quest_completed("FINAL_DELIVERY"):
			MusicManager.stop(true)
			var radios: Array = get_tree().get_nodes_in_group("Radio")
			for radio in radios:
				if is_instance_valid(radio) and radio.has_method("stop_radio"):
					radio.stop_radio()
		_show_npc_dialogue(
			completion_dialogue, 
			line_objs, 
			func():
				if GameManager.is_quest_completed("FINAL_DELIVERY"):
					return
				_prepare_turn_in_rewards(quest)
				GameManager.complete_quest_by_id(quest.quest_id)
				quests.erase(quest)
		)
		return
	_show_npc_dialogue(
		completion_dialogue,
		line_objs,
		func():
			if not GameManager.is_quest_completed(quest.quest_id):
				_prepare_turn_in_rewards(quest)
				GameManager.complete_quest_by_id(quest.quest_id)
				quests.erase(quest)
	)


func _begin_final_delivery_payoff() -> void :
	await _play_final_delivery_payoff()


func _play_final_delivery_payoff() -> void :

	_freeze_player_payoff(true)
	_flash_mesh_warm_yellow()
	_spawn_happiness_vfx()
	_play_happy_sound()
	var root: Node = get_tree().current_scene
	if root == null:
		root = get_tree().root
	var overlay: Node = ENDING_OVERLAY.instantiate()
	root.add_child(overlay)
	if overlay.has_method("run_sequence"):
		await overlay.run_sequence()
	_freeze_player_payoff(false)


func _freeze_player_payoff(locked: bool) -> void :
	var player: = NetUtil.get_local_player()
	if player and player.has_method("freeze_for_dialogue"):
		player.freeze_for_dialogue(locked)
	if player and player.has_method("set_weapon_active"):
		player.set_weapon_active( not locked)


func _flash_mesh_warm_yellow() -> void :
	if model_root == null:
		return
	var tw: = create_tween()
	tw.tween_property(model_root, "scale", Vector3(1.04, 1.04, 1.04), 0.14)
	tw.tween_property(model_root, "scale", Vector3.ONE, 0.42)


func _spawn_happiness_vfx() -> void :
	var vfx: Node = HAPPINESS_VFX.instantiate()
	var root: Node = get_tree().current_scene
	if root:
		root.add_child(vfx)
	else:
		get_tree().root.add_child(vfx)
	if vfx.has_method("play"):
		vfx.call("play", global_position + Vector3(0, 1.0, 0))

func _trigger_happiness_vfx() -> void :
	var vfx_scene: = load("res://scenes/vfx/happiness_vfx.tscn") as PackedScene
	if vfx_scene == null:
		return
	var vfx: = vfx_scene.instantiate()
	var root: Node = get_tree().current_scene
	if root == null:
		root = get_tree().root
	root.add_child(vfx)
	if vfx.has_method("play"):
		vfx.call("play", global_position + Vector3(0, 1.5, 0))


func _play_happy_sound() -> void :
	if happy_sound == null:
		return
	var ap: = AudioStreamPlayer.new()
	add_child(ap)
	ap.stream = happy_sound
	ap.bus = "Sfx"
	ap.play()
	ap.finished.connect( func(): ap.queue_free())


func _prepare_turn_in_rewards(quest: Quest) -> void :
	if quest.quest_id == "FINAL_DELIVERY":
		GameManager.remove_item("icecream", 2)
		GameManager.add_icecream_to_freezer(2)
		_trigger_happiness_vfx()
	if quest.quest_id == "IVER_BEVIS":
		GameManager.remove_item("fugleskinn", 3)
		GameManager.remove_item("elgskinn", 1)
	if quest.quest_id == "KRIS_LUA":
		GameManager.remove_item("peak_performance_lua", 1)
	if quest.quest_id == "STEINAR_GRUS":
		if npc_id != "steinar":
			return
		if GameManager.has_item("grus", 1):
			GameManager.remove_item("grus", 1)
		var quest_system = _get_quest_system()
		if quest_system and quest_system.has_method("on_item_delivered"):
			quest_system.call("on_item_delivered", "steinar", "grus")
		if npc_id == "steinar":
			_spawn_peak_performance_lua()
			await transform_to_grus()
			for npc in get_tree().get_nodes_in_group("NPC"):
				if npc == self:
					continue
				if npc.get("npc_id") == "stein":
					if npc.has_method("transform_to_grus"):
						await npc.transform_to_grus()
					break


func _dialogue_or_fallback(lines: Array[String], fallback: Array[String]) -> Array[String]:
	if lines.is_empty():
		return fallback
	return lines


func _give_iver_pistol() -> void :
	_give_iver_pistol_impl()


func _give_iver_pistol_impl() -> void :
	const PISTOL_ID: = 1
	var player: Node3D = NetUtil.get_local_player() as Node3D
	if player == null:
		return
	var wm: Node = player.get_node_or_null(player.weapon_controller_path)
	if wm == null:
		return
	wm.canUseWeapon = true
	wm.canChangeWeapons = true
	if not PISTOL_ID in wm.weaponStack:
		wm.weaponStack.append(PISTOL_ID)
	_setup_default_weapon_reserve(wm, PISTOL_ID)
	wm.weaponIndex = wm.weaponStack.find(PISTOL_ID)
	if wm.has_method("_instant_equip_weapon"):
		wm._instant_equip_weapon(PISTOL_ID)
	_setup_default_weapon_reserve(wm, PISTOL_ID)
	if wm.has_method("_ensure_holster_in_weapon_stack"):
		wm._ensure_holster_in_weapon_stack()
	if wm.has_method("_refresh_reserve_dependent_weapon_meshes"):
		wm._refresh_reserve_dependent_weapon_meshes()
	wm.canUseWeapon = true
	wm.canChangeWeapons = true


func _setup_default_weapon_reserve(weapon_manager: Node, weapon_int_id: int) -> void :
	if weapon_manager == null or not "weaponList" in weapon_manager:
		return
	var weapon_list: Dictionary = weapon_manager.weaponList
	if not weapon_list.has(weapon_int_id):
		return
	var weapon_resource = weapon_list[weapon_int_id]
	if weapon_resource == null:
		return
	var max_mag: = int(weapon_resource.totalAmmoInMagRef) if int(weapon_resource.totalAmmoInMagRef) > 0 else int(weapon_resource.totalAmmoInMag)
	if max_mag <= 0:
		return
	if weapon_int_id == 1:
		weapon_resource.totalAmmoInMag = max_mag
	elif not bool(weapon_resource.allAmmoInMag):
		weapon_resource.totalAmmoInMag = int(max_mag / 2)
	var ammo_type: String = str(weapon_resource.ammoType)
	var ammo_manager: Node = weapon_manager.get_node_or_null("AmmunitionManager")
	if ammo_manager == null and "ammoManager" in weapon_manager:
		ammo_manager = weapon_manager.ammoManager
	if ammo_manager == null or ammo_type == "":
		return
	if not "ammoDict" in ammo_manager or not "maxNbPerAmmoDict" in ammo_manager:
		return
	if ammo_type == "pistol_ammo":
		ammo_manager.ammoDict["pistol_ammo"] = max_mag * 2
		return
	var max_reserve: = int(ammo_manager.maxNbPerAmmoDict.get(ammo_type, 0))
	if max_reserve > 0:
		ammo_manager.ammoDict[ammo_type] = max_reserve


func _player_has_talked_to_npc(id: String) -> bool:
	if GameManager == null or not GameManager.has_method("has_talked_to_npc"):
		return false
	return GameManager.has_talked_to_npc(id)


func _spawn_peak_performance_lua() -> void :
	_hide_stein_cap_visual()

	var spawn_marker: Marker3D = get_node_or_null("CapSpawnMarker") as Marker3D
	var lua_scene: = load("res://scenes/props/peak_performance_lua.tscn") as PackedScene
	if lua_scene == null:
		return
	var lua: = lua_scene.instantiate()
	var root: Node = get_tree().current_scene
	if root == null:
		root = get_tree().root
	root.add_child(lua)
	if lua is Node3D:
		var spawned: Node3D = lua as Node3D
		if spawn_marker != null:
			spawned.global_transform = spawn_marker.global_transform
		else:
			spawned.global_position = global_position + Vector3(0, 1.8, 0)
	if lua is RigidBody3D:
		(lua as RigidBody3D).linear_velocity = Vector3.ZERO
		(lua as RigidBody3D).angular_velocity = Vector3.ZERO


func _hide_stein_cap_visual() -> void :
	var cap_mesh: Node3D = get_node_or_null("CapMesh") as Node3D
	if cap_mesh != null:
		cap_mesh.visible = false


func _sync_stein_cap_visual() -> void :
	if npc_id != "steinar":
		return
	var cap_mesh: Node3D = get_node_or_null("CapMesh") as Node3D
	if cap_mesh == null:
		return
	cap_mesh.visible = not _stein_cap_already_given()


func _stein_cap_already_given() -> bool:
	if GameManager == null:
		return false
	if GameManager.has_item("peak_performance_lua", 1):
		return true
	if GameManager.is_quest_completed("STEINAR_GRUS"):
		return true
	return false


func transform_to_grus() -> void :
	if _grus_transform_done:
		return
	_grus_transform_done = true

	if npc_id == "steinar":
		_hide_stein_cap_visual()

	if inhale_sound:
		var audio: = AudioStreamPlayer3D.new()
		add_child(audio)
		audio.stream = inhale_sound
		audio.bus = "Sfx"
		audio.play()
		await audio.finished
		audio.queue_free()

	var model: = get_node_or_null("Model")
	if model:
		model.visible = false

	var sprite: = Sprite3D.new()
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var grus_tex_path: = "res://assets/textures/grus_2d.png"
	if ResourceLoader.exists(grus_tex_path):
		var grus_tex: = load(grus_tex_path) as Texture2D
		sprite.texture = grus_tex
		var grus_mat: = StandardMaterial3D.new()
		grus_mat.albedo_texture = grus_tex
		grus_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		grus_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		grus_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		grus_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		grus_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
		sprite.material_override = grus_mat
	sprite.pixel_size = 0.0022
	sprite.position = Vector3(0, 0.4, 0)
	add_child(sprite)

	var area: = get_node_or_null("InteractionArea") as Area3D
	if area:
		area.monitoring = false
		area.monitorable = false

	if name_label:
		name_label.visible = false

	_is_flat_grus = true


func _on_hit(_current_health: float, _damage: float) -> void :
	_flash_hit()


func _flash_hit() -> void :
	if _is_flashing:
		return
	_is_flashing = true
	var meshes = _get_all_meshes(self)
	_original_materials.clear()
	for mesh in meshes:
		var m: = mesh as MeshInstance3D
		_original_materials.append(m.get_surface_override_material(0))
		var flash_mat: = StandardMaterial3D.new()
		flash_mat.albedo_color = Color(1.0, 0.0, 0.0, 1.0)
		flash_mat.emission_enabled = true
		flash_mat.emission = Color(1.0, 0.0, 0.0, 1.0)
		flash_mat.emission_energy_multiplier = 2.0
		m.set_surface_override_material(0, flash_mat)
	await get_tree().create_timer(0.08).timeout
	for i in range(meshes.size()):
		var m: = meshes[i] as MeshInstance3D
		if i < _original_materials.size():
			m.set_surface_override_material(0, _original_materials[i])
	_is_flashing = false


func _get_all_meshes(node: Node) -> Array:
	var result: Array = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_get_all_meshes(child))
	return result


func _get_quest_system() -> Node:
	var root: = get_tree().root
	var qs: = root.get_node_or_null("QuestSystem")
	if qs != null:
		return qs
	var current_scene: = get_tree().current_scene
	if current_scene != null:
		return current_scene.get_node_or_null("QuestManager")
	return null


func _show_bank_menu() -> void :
	var buttons: Array = []

	if GameManager.has_item("inheritance_document"):
		buttons.append({
			"text": "Løs inn arvedokument (100 kr)", 
			"action": func():
				if not GameManager.bank_document_payout("BANK_INHERITANCE", 100, "bank_teller"):
					DialogueUI.show_dialogue(["Dette dokumentet er allerede løst inn."], npc_name, Callable())
					return
				GameManager.remove_item("inheritance_document", 1)
				var quest_system = _get_quest_system()
				if quest_system:
					quest_system.on_npc_talked("bank_teller")
				DialogueUI.show_dialogue(
					["Mormors arv. 100 kroner.", "Ha en fin dag."], 
					npc_name, 
					Callable()
				)
		})

	if GameManager.has_item("approved_application"):
		buttons.append({
			"text": "Ta ut stipend (150 kr)", 
			"action": func():
				if not GameManager.bank_document_payout("BANK_DEPOSIT", 150, "bank_teller"):
					DialogueUI.show_dialogue(["Stipendet er allerede utbetalt."], npc_name, Callable())
					return
				GameManager.remove_item("approved_application", 1)
				var quest_system = _get_quest_system()
				if quest_system:
					quest_system.on_npc_talked("bank_teller")
				DialogueUI.show_dialogue(
					["Stipendet er utbetalt. 150 kroner.", "Ha en fin dag."], 
					npc_name, 
					Callable()
				)
		})

	buttons.append({
		"text": "Ingen ting", 
		"action": func(): DialogueUI.close()
	})

	DialogueUI.show_menu(["Hei. Hva kan jeg hjelpe deg med?"], buttons, npc_name)


func _ensure_unique_interaction_shape() -> void :
	var col: = interaction_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col != null and col.shape != null:
		col.shape = col.shape.duplicate()


func set_interaction_radius(radius: float) -> void :
	if interaction_area == null:
		return
	var col: = interaction_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col != null and col.shape is SphereShape3D:
		(col.shape as SphereShape3D).radius = radius


func _on_area_3d_body_entered(body: Node3D) -> void :
	if is_dead:
		return
	if body.is_in_group("PlayerCharacter"):
		in_range = true
		if name_label:
			name_label.visible = true


func _on_area_3d_body_exited(body: Node3D) -> void :
	if body.is_in_group("PlayerCharacter"):
		in_range = false
		if name_label:
			name_label.visible = false


func _on_npc_death() -> void :
	if is_dead:
		return
	if npc_id == "grandpa":
		_on_grandpa_died()
		return
	is_dead = true
	_trigger_death_vfx()
	if is_in_group("StoryNPC") and npc_id != "grandpa":
		if GrayscaleEffect and GrayscaleEffect.has_method("activate"):
			GrayscaleEffect.activate()
	_break_world()


func _on_grandpa_died() -> void :
	is_dead = true
	_stop_game_music()
	if not is_inside_tree():
		return
	var tree: = get_tree()
	if tree == null:
		return
	var player: Node3D = NetUtil.get_local_player()
	if player != null:
		if player.has_method("freeze_for_dialogue"):
			player.freeze_for_dialogue(true)
		if "movement_frozen" in player:
			player.movement_frozen = true
		if "camera_frozen" in player:
			player.camera_frozen = true

	tree.call_deferred("change_scene_to_file", "res://scenes/ui/bad_ending.tscn")


func _trigger_death_vfx() -> void :
	var vfx: Node3D = NPC_DEATH_VFX.instantiate() as Node3D
	var scene_root: Node = get_tree().current_scene
	if scene_root:
		scene_root.add_child(vfx)
	else:
		get_tree().root.add_child(vfx)
	if vfx.has_method("play"):
		vfx.call("play", global_position + Vector3(0, 1.0, 0))
	for child in get_children():
		if child is MeshInstance3D:
			child.visible = false
		if child is Node3D and child.name == "Model":
			child.visible = false
		_hide_meshes_recursive(child)
	_disable_interaction_area_deferred()


func _get_interaction_area() -> Area3D:
	var area: Area3D = get_node_or_null("InteractionArea") as Area3D
	if area == null:
		area = get_node_or_null("Area3D") as Area3D
	return area


func _disable_interaction_area_deferred() -> void :
	var area: = _get_interaction_area()
	if area:
		area.set_deferred("monitoring", false)
		area.set_deferred("monitorable", false)


func _hide_meshes_recursive(n: Node) -> void :
	for c in n.get_children():
		if c is MeshInstance3D:
			c.visible = false
		if c is Node3D and c.name == "Model":
			c.visible = false
		_hide_meshes_recursive(c)


func _break_world() -> void :
	if not is_in_group("Enemies") and not is_in_group("enemy"):
		_stop_game_music()
	GameManager.register_dead_npc(npc_id)
	quests.clear()
	in_range = false
	if name_label:
		name_label.visible = false


func _stop_game_music() -> void :
	for music_player in get_tree().get_nodes_in_group("MusicPlayer"):
		if music_player is AudioStreamPlayer:
			(music_player as AudioStreamPlayer).stop()
		elif music_player.has_method("stop"):
			music_player.stop()


func _set_player_frozen(locked: bool) -> void :
	var player: = NetUtil.get_local_player()
	if player and player.has_method("freeze_for_dialogue"):
		player.freeze_for_dialogue(locked)
	if player and player.has_method("set_weapon_active"):
		player.set_weapon_active( not locked)
	if locked:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif player and player.has_method("should_use_fps_mouse_capture") and player.should_use_fps_mouse_capture():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)





func react_to_finger() -> void :
	if _finger_react_index >= finger_react_sounds.size():
		return


	if _finger_react_blocked_by_speech():
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_finger_react_time < FINGER_REACT_COOLDOWN:
		return
	var clip: AudioStream = finger_react_sounds[_finger_react_index]
	_finger_react_index += 1
	if clip == null:
		return
	_last_finger_react_time = now
	if _finger_react_audio == null:
		_finger_react_audio = AudioStreamPlayer3D.new()
		_finger_react_audio.name = "FingerReactAudio"
		_finger_react_audio.max_distance = 25.0
		_finger_react_audio.unit_size = 6.0
		_finger_react_audio.bus = "Voice"
		add_child(_finger_react_audio)
	_finger_react_audio.stream = clip
	_finger_react_audio.play()



func stop_finger_react() -> void :
	if _finger_react_audio != null and _finger_react_audio.playing:
		_finger_react_audio.stop()




func _finger_react_blocked_by_speech() -> bool:
	if DialogueUI != null and DialogueUI.has_method("is_open") and DialogueUI.is_open():
		return true
	if _audio_player != null and _audio_player.playing:
		return true
	if _finger_react_audio != null and _finger_react_audio.playing:
		return true
	return false


func reset_npc() -> void :
	is_dead = false
	in_range = false
	current_quest = null
	_is_flat_grus = false
	_grus_transform_done = false
	_has_been_talked_to = false
	_bounce_started = false
	_stop_bounce()
	if npc_id == "kris" and _should_kris_bounce():
		_start_bounce()
	if name_label:
		name_label.visible = false
	var area: = get_node_or_null("InteractionArea") as Area3D
	if area:
		area.monitoring = true
		area.monitorable = false
	var model: = get_node_or_null("Model") as Node3D
	if model:
		model.visible = true
	if npc_id == "steinar":
		_sync_stein_cap_visual()


func _on_game_reset() -> void :
	reset_npc()
