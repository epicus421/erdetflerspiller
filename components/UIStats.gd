
extends HBoxContainer

const QUEST_BOX = preload("res://components/quest/quest_box.tscn")





const SIDE_QUEST_IDS: Array[String] = [
	"VINDKAST_PLAKATER", 
]





const HIDDEN_QUEST_IDS: Array[String] = ["GRANDPA_REQUEST", "STEINAR_GRUS"]

@onready var quest_container: VBoxContainer = %QuestDisplay as VBoxContainer
@onready var currency_label: Label = $StatsPanel / Stats / MoneyRow / NOK
@onready var health_bar: ProgressBar = $StatsPanel / Stats / HealthBar


func _ready() -> void :
	_setup_stats_panel_style()
	_setup_health_bar_background()
	await get_tree().process_frame
	if quest_container == null:
		quest_container = get_node_or_null("../../QuestHud/QuestPanel/QuestDisplay") as VBoxContainer

	if GameManager:
		GameManager.quest_changed.connect(_on_quest_changed)
		GameManager.quest_progress_updated.connect(_on_quest_progress_updated)
		GameManager.money_changed.connect(_on_money_changed)

		_refresh_quest_list()
		_on_money_changed(GameManager.player_money)

	var player: = NetUtil.get_local_player()
	if player and player.has_method("_refresh_health_ui"):
		player._refresh_health_ui()


func _setup_stats_panel_style() -> void :
	var panel: = get_node_or_null("StatsPanel") as PanelContainer
	if panel == null:
		return
	if panel.has_theme_stylebox_override("panel"):
		return
	var style: = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.45)
	style.set_corner_radius_all(4)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)


func _setup_health_bar_background() -> void :
	if health_bar == null:
		return
	if health_bar.has_theme_stylebox_override("background"):
		return
	var bg: = StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.1, 0.7)
	health_bar.add_theme_stylebox_override("background", bg)


func refresh_health_fill(current_hp: int, max_hp: float) -> void :
	if health_bar == null:
		return
	health_bar.max_value = max_hp
	health_bar.value = current_hp
	var fill: = StyleBoxFlat.new()
	fill.bg_color = Color(0.75, 0.12, 0.12, 1.0) if current_hp < 30 else Color(0.23, 0.76, 0.27, 1.0)
	health_bar.add_theme_stylebox_override("fill", fill)


func _refresh_quest_list() -> void :
	if not quest_container:
		return

	for child in quest_container.get_children():
		child.queue_free()

	if not GameManager:
		return

	for quest in GameManager.get_active_quests():
		if quest.quest_id in SIDE_QUEST_IDS or quest.quest_id in HIDDEN_QUEST_IDS:
			continue
		var quest_box = QUEST_BOX.instantiate()
		quest_box.setup(quest)
		quest_container.add_child(quest_box)


func _on_quest_changed(_quest_id: String, _state: int) -> void :
	_refresh_quest_list()


func _on_quest_progress_updated(quest_id: String, _progress: int) -> void :
	if quest_container == null:
		return
	for child in quest_container.get_children():
		if child.has_method("setup") and child.quest and child.quest.quest_id == quest_id:
			if child.has_method("_refresh"):
				child._refresh()
			return
	_refresh_quest_list()


func _on_money_changed(new_money: int) -> void :
	if currency_label:
		currency_label.text = str(new_money) + " NOK"
