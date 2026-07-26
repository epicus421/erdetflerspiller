extends CanvasLayer

const ITEM_ICON_DIR: = "res://assets/textures/icons/items/%s.png"
const ICON_SIZE: = 32
const ID_CARD_SCENE: PackedScene = preload("res://scenes/ui/id_card.tscn")



const MAIN_QUEST_IDS: Array[String] = [
	"GRANDPA_REQUEST", "BANK_INHERITANCE", "ECONOMIC_REALITY", 
	"GRANDPA_DISAPPOINTMENT", "SCHOLARSHIP_APPLICATION", 
	"BANK_DEPOSIT", "SECOND_ICECREAM", "FINAL_DELIVERY", 
	"KRIS_LUA", "IVER_BEVIS", "STEINAR_GRUS", 
	"HVERDAGSKOMIKER", "GORGON_ROBBERY", 
]

const SIDE_QUEST_IDS: Array[String] = [
	"VINDKAST_PLAKATER", 
]

const HIDDEN_QUEST_IDS: Array[String] = ["GRANDPA_REQUEST"]

@onready var panel: Panel = $Panel
@onready var list_container: VBoxContainer = $Panel / Margin / VBox / Columns / LeftVBox / Scroll / List
@onready var quest_list_container: VBoxContainer = $Panel / Margin / VBox / Columns / RightVBox / QuestScroll / QuestList
@onready var description_label: Label = $Panel / Margin / VBox / Description
@onready var vbox: VBoxContainer = $Panel / Margin / VBox

var is_open: = false
var _id_card_overlay: Control = null
var _collectible_overlay: Control = null
var _close_btn: Button = null
const COLLECTIBLE_KIND_FANART: = 1


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_create_close_button()
	if GameManager:
		if not GameManager.inventory_changed.is_connected(_on_inventory_changed):
			GameManager.inventory_changed.connect(_on_inventory_changed)
		if not GameManager.item_use_blocked.is_connected(_on_item_use_blocked):
			GameManager.item_use_blocked.connect(_on_item_use_blocked)
		if not GameManager.item_added.is_connected(_on_item_added):
			GameManager.item_added.connect(_on_item_added)
		if not GameManager.quest_changed.is_connected(_on_quest_changed):
			GameManager.quest_changed.connect(_on_quest_changed)


func _create_close_button() -> void :
	var btn: = Button.new()
	btn.text = "Lukk"
	btn.custom_minimum_size = Vector2(60, 24)
	btn.add_theme_font_size_override("font_size", 10)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_close_inventory)
	vbox.add_child(btn)
	_close_btn = btn


func _unhandled_input(event: InputEvent):
	var joy_pressed: bool = event is InputEventJoypadButton\
	and (event as InputEventJoypadButton).pressed

	if is_open and _collectible_overlay != null and is_instance_valid(_collectible_overlay)\
	and joy_pressed:
		var ob: int = (event as InputEventJoypadButton).button_index
		if ob == JOY_BUTTON_A or ob == JOY_BUTTON_B:
			_collectible_overlay.queue_free()
			_collectible_overlay = null
			_focus_first_row.call_deferred()
			get_viewport().set_input_as_handled()
			return

	if is_open and joy_pressed\
	and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B:
		_close_inventory()
		get_viewport().set_input_as_handled()
		return

	var toggle_pressed: bool = (event is InputEventKey and (event as InputEventKey).pressed\
	and not (event as InputEventKey).echo\
	and (event as InputEventKey).keycode == KEY_Q)\
	or (joy_pressed\
	and (event as InputEventJoypadButton).button_index == JOY_BUTTON_DPAD_LEFT)
	if toggle_pressed:
		if not is_open and _is_pause_menu_active():
			get_viewport().set_input_as_handled()
			return

		if not is_open and DialogueUI != null and DialogueUI.has_method("is_open")\
		and DialogueUI.is_open():
			return

		if not is_open and GameManager != null\
		and GameManager.has_method("is_minigame_active")\
		and GameManager.is_minigame_active():
			return
		_toggle()
		get_viewport().set_input_as_handled()


func _is_pause_menu_active() -> bool:
	var pause_menu: Node = get_node_or_null("/root/PauseMenu")
	return pause_menu != null\
	and pause_menu.has_method("is_menu_paused")\
	and bool(pause_menu.call("is_menu_paused"))


func _toggle():
	if is_open:
		_close_inventory()
	else:
		_open_inventory()


func _open_inventory():
	is_open = true
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_set_player_weapon_active(false)
	_refresh_list()

	_focus_first_row.call_deferred()

	if QuestNotifier:
		QuestNotifier.mark_sidequests_seen()


func _focus_first_row() -> void :
	if not is_open:
		return
	for child in list_container.get_children():
		if child is Button and not (child as Button).disabled:
			(child as Button).grab_focus()
			return
	if _close_btn != null and is_instance_valid(_close_btn):
		_close_btn.grab_focus()


func _close_inventory():
	if _id_card_overlay != null and is_instance_valid(_id_card_overlay):
		_id_card_overlay.queue_free()
		_id_card_overlay = null
	if _collectible_overlay != null and is_instance_valid(_collectible_overlay):
		_collectible_overlay.queue_free()
		_collectible_overlay = null
	is_open = false
	visible = false
	var player = NetUtil.get_local_player()
	var dialogue_waiting: = false
	var dialogue_frozen: = false
	var movement_frozen: = false
	if player:
		dialogue_waiting = bool(player.get("dialogue_waiting_for_button"))
		dialogue_frozen = bool(player.get("camera_frozen"))
		movement_frozen = bool(player.get("movement_frozen"))
	if not dialogue_waiting and not _is_pause_menu_active():
		get_tree().paused = false
	if not dialogue_waiting and not dialogue_frozen and not movement_frozen:
		if player and player.has_method("should_use_fps_mouse_capture") and player.should_use_fps_mouse_capture():
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_set_player_weapon_active(true)




func _refresh_list():
	for child in list_container.get_children():
		child.queue_free()
	for child in quest_list_container.get_children():
		child.queue_free()
	description_label.text = ""
	_add_item_rows()
	_add_ammo_rows()
	_add_collectible_rows()
	_add_quest_tab(SIDE_QUEST_IDS, "", "Ingen aktive sideoppdrag.")



func _add_collectible_rows() -> void :
	var items: Array = GameManager.get_viewable_collectibles()
	if items.is_empty():
		return
	var header: = Label.new()
	header.text = "SAMLET"
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", Color(0.75, 0.65, 0.4))
	list_container.add_child(header)
	for data in items:
		var d: Dictionary = data
		var is_art: bool = int(d.get("kind", 0)) == COLLECTIBLE_KIND_FANART
		var title: String = str(d.get("title", ""))
		if title == "":
			title = "Fan art" if is_art else "Lore-notat"
		var icon: Texture2D = d.get("artwork") as Texture2D if is_art else null
		var row: = _create_row(title, "Se" if is_art else "Les", icon, "")
		row.pressed.connect(_show_collectible_overlay.bind(d))
		list_container.add_child(row)


func _show_collectible_overlay(data: Dictionary) -> void :
	if _collectible_overlay != null and is_instance_valid(_collectible_overlay):
		_collectible_overlay.queue_free()
	var overlay: = ColorRect.new()
	overlay.color = Color(0.02, 0.02, 0.03, 0.96)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	if int(data.get("kind", 0)) == COLLECTIBLE_KIND_FANART and data.get("artwork") != null:
		var tr: = TextureRect.new()
		tr.texture = data["artwork"]
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.offset_left = 40;tr.offset_top = 40;tr.offset_right = -40;tr.offset_bottom = -60
		overlay.add_child(tr)
	else:
		var lbl: = Label.new()
		lbl.text = str(data.get("text", ""))
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lbl.offset_left = 80;lbl.offset_top = 60;lbl.offset_right = -80;lbl.offset_bottom = -80
		overlay.add_child(lbl)
	var hint: = Label.new()
	hint.text = "Klikk / B for å lukke"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 16)
	overlay.add_child(hint)
	overlay.gui_input.connect( func(e: InputEvent) -> void :
		if e is InputEventMouseButton and e.pressed:
			if is_instance_valid(overlay):
				overlay.queue_free()
			_collectible_overlay = null
			_focus_first_row.call_deferred()
	)
	add_child(overlay)
	_collectible_overlay = overlay


	get_viewport().gui_release_focus()



func _add_quest_tab(quest_ids: Array[String], header: String, empty_text: String) -> void :
	var active: Array = []
	var completed: Array = []
	for quest_id in quest_ids:
		if quest_id in HIDDEN_QUEST_IDS:
			continue
		if GameManager.is_quest_completed(quest_id):
			var cq = GameManager.active_quests.get(quest_id)
			if cq == null:
				cq = GameManager.quest_registry.get(quest_id)
			if cq != null:
				completed.append(cq)
		else:
			var aq = GameManager.active_quests.get(quest_id)
			if aq != null:
				active.append(aq)

	if active.is_empty() and completed.is_empty():
		var lbl: = Label.new()
		lbl.text = empty_text
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		quest_list_container.add_child(lbl)
		return

	if not active.is_empty():
		if header != "":
			_add_section_label(header, true)
		for quest in active:
			_add_quest_entry(quest, false)
	if not completed.is_empty():
		_add_section_label("UTFØRTE OPPDRAG", active.is_empty())
		for quest in completed:
			_add_quest_entry(quest, true)


func _add_item_rows():
	for item_id in GameManager.inventory.keys():
		var slot = GameManager.inventory[item_id]
		var data: ItemData = slot.get("data")
		var amount = int(slot.get("amount", 0))
		if data == null:
			continue
		var title: String = data.display_name if data.display_name != "" else str(item_id)
		var hover_text: = _item_hover_description(data)
		var row = _create_row(
			title, 
			str(amount), 
			_resolve_item_icon(data, item_id), 
			hover_text
		)
		if data.category == ItemData.Category.CONSUMABLE:
			row.pressed.connect(_on_consumable_pressed.bind(item_id))
		elif data.category == ItemData.Category.QUEST_ITEM:
			if item_id == "id_card":
				row.pressed.connect(_on_id_card_pressed)
			else:
				row.pressed.connect(_on_quest_item_pressed.bind(data.description))
		list_container.add_child(row)


func _add_ammo_rows():
	var player = NetUtil.get_local_player()
	if player == null:
		return
	var ammo_dict = player.get("ammoDict")
	var max_dict = player.get("maxNbPerAmmoDict")
	if ammo_dict == null or max_dict == null:
		return
	if not ammo_dict is Dictionary or not max_dict is Dictionary:
		return
	for ammo_id in ammo_dict.keys():
		var current = int(ammo_dict.get(ammo_id, 0))
		var max_amount = int(max_dict.get(ammo_id, 0))
		var ammo_hover: = "Reserve: %d / %d" % [current, max_amount]
		var row = _create_row(str(ammo_id), "%d/%d" % [current, max_amount], null, ammo_hover)
		list_container.add_child(row)


func _add_section_label(text: String, first: bool = false) -> void :
	if not first:
		var sep: = HSeparator.new()
		sep.add_theme_constant_override("separation", 8)
		quest_list_container.add_child(sep)
	var lbl: = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.65, 0.4))
	quest_list_container.add_child(lbl)


func _add_quest_entry(quest: Resource, is_completed: bool) -> void :
	var entry: = VBoxContainer.new()
	entry.add_theme_constant_override("separation", 2)
	if is_completed:
		entry.modulate = Color(0.5, 0.5, 0.5, 1.0)

	var title_row: = HBoxContainer.new()
	var name_lbl: = Label.new()
	name_lbl.text = quest.name
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var check_lbl: = Label.new()
	check_lbl.text = "✓" if is_completed else ""
	check_lbl.add_theme_font_size_override("font_size", 12)
	check_lbl.add_theme_color_override("font_color", Color(0.5, 0.85, 0.5))
	check_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_row.add_child(name_lbl)
	title_row.add_child(check_lbl)



	if is_completed:
		entry.add_child(title_row)
		quest_list_container.add_child(entry)
		return

	var obj_lbl: = Label.new()
	obj_lbl.text = "   " + _get_quest_objective_text(quest)
	obj_lbl.add_theme_font_size_override("font_size", 10)
	obj_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	obj_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	entry.add_child(title_row)
	entry.add_child(obj_lbl)
	quest_list_container.add_child(entry)


func _get_quest_objective_text(quest) -> String:
	if quest == null:
		return ""
	if quest.has_method("normalize_runtime_state"):
		quest.normalize_runtime_state()
	for objective in quest.objectives:
		if objective == null:
			continue
		var progress: int = int(quest.objective_progress.get(objective.objective_id, 0))
		if progress < objective.target_amount:
			var desc: String = objective.description if objective.description != "" else quest.description
			if objective.target_amount > 1:
				return desc + " (%d/%d)" % [progress, objective.target_amount]
			return desc
	var fallback: String = quest.description.strip_edges() if quest.description else ""
	return fallback if fallback != "" else quest.brief_description


func _item_hover_description(data: ItemData) -> String:
	var desc: = data.description.strip_edges() if data.description else ""
	if desc != "":
		return desc
	return "Ingen beskrivelse."


func _resolve_item_icon(data: ItemData, item_id: String) -> Texture2D:
	if data.icon != null:
		return data.icon
	var path: = ITEM_ICON_DIR % item_id
	if ResourceLoader.exists(path):
		var loaded: = load(path)
		if loaded is Texture2D:
			return loaded
	return null


func _create_row(title_text: String, amount_text: String, icon: Texture2D, hover_description: String = "") -> Button:
	var button = Button.new()
	button.flat = true
	button.custom_minimum_size = Vector2(0, 40)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text = title_text + "    " + amount_text
	button.clip_text = true
	if icon != null:
		button.icon = icon
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", ICON_SIZE)
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	button.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1))

	button.focus_mode = Control.FOCUS_ALL
	if hover_description != "":
		button.mouse_entered.connect(_on_item_row_mouse_entered.bind(hover_description))
		button.mouse_exited.connect(_on_item_row_mouse_exited)

		button.focus_entered.connect(_on_item_row_mouse_entered.bind(hover_description))
		button.focus_exited.connect(_on_item_row_mouse_exited)
	return button


func _on_item_row_mouse_entered(description: String):
	if not is_open or description_label == null:
		return
	description_label.text = description


func _on_item_row_mouse_exited():
	if not is_open or description_label == null:
		return
	description_label.text = ""


func _on_consumable_pressed(item_id: String):
	GameManager.use_item(item_id)
	_refresh_list()


func _on_item_use_blocked(_item_id: String, code: String):
	if not is_open:
		return
	if code == "full_health":
		description_label.text = "Du har full helse."


func _on_quest_item_pressed(description: String):
	description_label.text = description if description != "" else "Ingen beskrivelse."


func _on_id_card_pressed() -> void :
	_show_id_card_overlay()


func _show_id_card_overlay() -> void :
	if _id_card_overlay != null and is_instance_valid(_id_card_overlay):
		_id_card_overlay.queue_free()
		_id_card_overlay = null
		return
	var card: Control = ID_CARD_SCENE.instantiate()
	add_child(card)
	_id_card_overlay = card
	card.tree_exited.connect( func():
		_id_card_overlay = null
	)


func _on_item_added(item_id: String, _amount: int) -> void :
	if item_id == "id_card":
		call_deferred("_open_inventory_with_id_card")


func _open_inventory_with_id_card() -> void :
	if DialogueUI and DialogueUI.is_open():
		DialogueUI.dialogue_finished.connect(_open_inventory_with_id_card_after_dialogue, CONNECT_ONE_SHOT)
		return
	if not is_open:
		_open_inventory()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_show_id_card_overlay()


func _open_inventory_with_id_card_after_dialogue() -> void :
	call_deferred("_open_inventory_with_id_card")


func _on_inventory_changed(_item_id: String, _new_amount: int):
	if is_open:
		_refresh_list()
		_focus_first_row.call_deferred()


func _on_quest_changed(_quest_id: String, _state: int) -> void :
	if is_open:
		_refresh_list()
		_focus_first_row.call_deferred()


func _set_player_weapon_active(enabled: bool):
	var player = NetUtil.get_local_player()
	if player and player.has_method("set_weapon_active"):
		player.set_weapon_active(enabled)
