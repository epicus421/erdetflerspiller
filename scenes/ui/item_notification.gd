extends CanvasLayer
class_name ItemNotification

const ITEM_DATA_TEMPLATE: = "res://data/items/%s.tres"
const NOTIFICATION_FONT_SIZE: = 20

@onready var stack: VBoxContainer = $MarginContainer / NotificationStack

var _last_money: int = 0

func _ready():
	add_to_group("ItemNotification")
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	if GameManager:
		_last_money = GameManager.player_money
		if not GameManager.item_added.is_connected(_on_item_added):
			GameManager.item_added.connect(_on_item_added)
		if not GameManager.money_changed.is_connected(_on_money_changed):
			GameManager.money_changed.connect(_on_money_changed)

func _on_money_changed(new_amount: int) -> void :
	var gained: = new_amount - _last_money
	_last_money = new_amount
	if gained > 0:
		_show_notification("+%d NOK" % gained, Color(0.5, 0.95, 0.5))
	elif gained < 0:
		_show_notification("%d NOK" % gained, Color(0.95, 0.45, 0.45))


func _on_item_added(item_id: String, amount: int):
	if item_id == "approved_application":
		_show_notification("Stipendsøknad godkjent! Gå til banken.")
		return
	if item_id == "stoepsel":
		_show_notification("Gigant-støpsel laget! Sett den i veggen ved kraftstasjonen.")
		return
	var display_name: = item_id
	var item_data: = _load_item_data(item_id)
	if item_data != null:
		display_name = item_data.display_name if item_data.display_name != "" else item_id
	show_pickup(amount, display_name)


static func notify_pickup(tree: SceneTree, amount: int, display_name: String) -> void :
	if amount <= 0 or tree == null:
		return
	for node in tree.get_nodes_in_group("ItemNotification"):
		if node.has_method("show_pickup"):
			node.show_pickup(amount, display_name)
			return


static func notify_ammo_pickup(tree: SceneTree, ammo_type: String, amount: int) -> void :
	notify_pickup(tree, amount, _format_ammo_display_name(ammo_type))


static func _format_ammo_display_name(ammo_type: String) -> String:
	return ammo_type.replace("_", " ")


func show_pickup(amount: int, display_name: String) -> void :
	if amount <= 0:
		return
	_show_notification("+ %d x %s" % [amount, display_name])


func _show_notification(text: String, font_color: Color = Color.WHITE):
	if stack == null:
		return
	var panel: = PanelContainer.new()
	panel.self_modulate = Color(1, 1, 1, 0.9)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.06, 0.82)
	style.border_color = Color(1, 1, 1, 0.18)
	style.set_border_width_all(1)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)

	var label: = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_font_size_override("font_size", NOTIFICATION_FONT_SIZE)
	var outline: = LabelSettings.new()
	outline.font_size = NOTIFICATION_FONT_SIZE
	outline.outline_size = 4
	outline.outline_color = Color(0, 0, 0, 0.9)
	label.label_settings = outline
	panel.add_child(label)
	stack.add_child(panel)

	var tween: = create_tween()
	tween.tween_interval(1.7)
	tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	tween.finished.connect(panel.queue_free)

func _load_item_data(item_id: String) -> ItemData:
	var path: = ITEM_DATA_TEMPLATE % item_id
	var loaded: = ResourceLoader.load(path)
	if loaded is ItemData:
		return loaded
	return null
