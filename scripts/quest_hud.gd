extends CanvasLayer









const HINTS_PATH: = "user://hints.cfg"


const MAIN_CHAIN: Array[String] = [
	"GRANDPA_REQUEST", "BANK_INHERITANCE", "ECONOMIC_REALITY", 
	"GRANDPA_DISAPPOINTMENT", "SCHOLARSHIP_APPLICATION", "BANK_DEPOSIT", 
	"SECOND_ICECREAM", "FINAL_DELIVERY", 
]



const SIDE_QUEST_IDS: Array[String] = ["VINDKAST_PLAKATER"]



const HIDDEN_QUEST_IDS: Array[String] = ["STEINAR_GRUS"]

const TOAST_SHOW_TIME: = 2.4
const TOAST_FADE_TIME: = 0.4
const MAX_VISIBLE_TOASTS: = 2
const HINT_SHOW_TIME: = 4.0

const COLOR_SIDE: = Color(1.0, 0.85, 0.45)
const COLOR_DONE: = Color(0.55, 0.9, 0.55)

var _root: Control
var _toast_box: VBoxContainer
var _pulse_label: Label
var _hint_label: Label

var _pending_toasts: Array = []
var _unseen_sidequest: bool = false
var _pulse_time: float = 0.0
var _hint_flags: Dictionary = {}
var _hint_queue: Array = []
var _hint_active: bool = false


func _ready() -> void :
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_hint_flags()
	_build_ui()
	GameManager.quest_changed.connect(_on_quest_changed)
	GameManager.quest_completed.connect(_on_quest_completed)
	GameManager.item_added.connect(_on_item_added)


func _build_ui() -> void :
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)


	_toast_box = VBoxContainer.new()
	_toast_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_box.offset_top = 84.0
	_toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toast_box.add_theme_constant_override("separation", 4)
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toast_box)


	_pulse_label = _make_label(12, COLOR_SIDE)
	_pulse_label.text = "Q — nytt sideoppdrag!"
	_pulse_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_pulse_label.offset_left = -190.0
	_pulse_label.offset_top = -46.0
	_pulse_label.offset_right = -10.0
	_pulse_label.visible = false
	_root.add_child(_pulse_label)


	_hint_label = _make_label(12, Color(0.9, 0.9, 0.9))
	_hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)


	_hint_label.offset_top = -120.0
	_hint_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.visible = false
	_root.add_child(_hint_label)


func _make_label(size: int, color: Color) -> Label:
	var lbl: = Label.new()
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


func _process(delta: float) -> void :
	var allowed: = _hud_allowed()
	_root.visible = allowed
	if not allowed:
		return


	_pulse_label.visible = _unseen_sidequest
	if _unseen_sidequest:
		_pulse_time += delta
		_pulse_label.modulate.a = 0.4 + 0.35 * sin(_pulse_time * 4.0)


	while not _pending_toasts.is_empty() and _toast_box.get_child_count() < MAX_VISIBLE_TOASTS:
		var t: Dictionary = _pending_toasts.pop_front()
		_spawn_toast(str(t.text), t.color)


	if not _hint_active and not _hint_queue.is_empty()\
	and _pending_toasts.is_empty() and _toast_box.get_child_count() == 0:
		_show_hint(str(_hint_queue.pop_front()))


func _hud_allowed() -> bool:
	var tree: = get_tree()
	if tree == null or tree.paused:
		return false
	var cur: = tree.current_scene
	if cur == null or cur.scene_file_path != "res://levels/main_demo.tscn":
		return false
	if DialogueUI and DialogueUI.has_method("is_open") and DialogueUI.is_open():
		return false
	if GameManager.has_method("is_minigame_active") and GameManager.is_minigame_active():
		return false
	var horror: Node = tree.get_first_node_in_group("GorgonHorror")
	if horror != null and bool(horror.get("_active")):
		return false
	return true




func _on_quest_changed(quest_id: String, state: int) -> void :
	if state != Quest.QuestState.ACTIVE or quest_id in MAIN_CHAIN\
	or quest_id in HIDDEN_QUEST_IDS:
		return
	var quest: Resource = GameManager.active_quests.get(quest_id)
	var quest_name: String = quest.name if quest != null else quest_id
	if quest_id in SIDE_QUEST_IDS:
		_queue_toast("NYTT SIDEOPPDRAG: %s" % quest_name, COLOR_SIDE)
		_unseen_sidequest = true
		_pulse_time = 0.0
	else:
		_queue_toast("NYTT OPPDRAG: %s" % quest_name, COLOR_SIDE)
	show_hint_once("quest_panel", "Q — oppdrag og inventar")


func _on_quest_completed(quest_id: String) -> void :
	if quest_id in MAIN_CHAIN or quest_id in HIDDEN_QUEST_IDS:
		return
	var quest: Resource = GameManager.quest_registry.get(quest_id)
	var quest_name: String = quest.name if quest != null else quest_id
	var label: = "SIDEOPPDRAG FULLFØRT" if quest_id in SIDE_QUEST_IDS else "OPPDRAG FULLFØRT"
	_queue_toast("%s: %s" % [label, quest_name], COLOR_DONE)


func _on_item_added(_item_id: String, _amount: int) -> void :
	show_hint_once("quest_panel", "Q — oppdrag og inventar")


func mark_sidequests_seen() -> void :
	_unseen_sidequest = false




func _queue_toast(text: String, color: Color) -> void :
	_pending_toasts.append({"text": text, "color": color})


func _spawn_toast(text: String, color: Color) -> void :
	var lbl: = _make_label(14, color)
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.modulate.a = 0.0
	_toast_box.add_child(lbl)
	var tween: = lbl.create_tween()
	tween.tween_property(lbl, "modulate:a", 1.0, 0.25)
	tween.tween_interval(TOAST_SHOW_TIME)
	tween.tween_property(lbl, "modulate:a", 0.0, TOAST_FADE_TIME)
	tween.tween_callback(lbl.queue_free)




func show_hint_once(hint_id: String, text: String) -> void :
	if _hint_flags.get(hint_id, false):
		return
	_hint_flags[hint_id] = true
	_save_hint_flags()
	_hint_queue.append(text)



func show_hint(text: String) -> void :
	_hint_queue.append(text)


func _show_hint(text: String) -> void :
	_hint_active = true
	_hint_label.text = text
	_hint_label.modulate.a = 0.0
	_hint_label.visible = true
	var tween: = _hint_label.create_tween()
	tween.tween_property(_hint_label, "modulate:a", 1.0, 0.3)
	tween.tween_interval(HINT_SHOW_TIME)
	tween.tween_property(_hint_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback( func() -> void :
		_hint_label.visible = false
		_hint_active = false
	)


func _load_hint_flags() -> void :
	var cfg: = ConfigFile.new()
	if cfg.load(HINTS_PATH) != OK:
		return
	if not cfg.has_section("hints"):
		return
	for key in cfg.get_section_keys("hints"):
		_hint_flags[key] = bool(cfg.get_value("hints", key, false))


func _save_hint_flags() -> void :
	var cfg: = ConfigFile.new()
	cfg.load(HINTS_PATH)
	for key in _hint_flags:
		cfg.set_value("hints", key, _hint_flags[key])
	cfg.save(HINTS_PATH)
