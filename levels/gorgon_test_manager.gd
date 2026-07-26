extends Node

const BOSS_TIME: float = 120.0

var _timer: float = 0.0
var _boss_active: bool = false
var _hud_timer_label: Label = null
var _hud_boxes_label: Label = null


func _ready() -> void :
	add_to_group("GorgonTestManager")
	if not GameManager.has_quest("GORGON_ROBBERY"):
		GameManager.add_quest_by_id("GORGON_ROBBERY")
	GameManager.player_money = 999
	GameManager.money_changed.emit(GameManager.player_money)
	_setup_player_health()
	_hud_timer_label = get_node_or_null("../BossHUD/TimerLabel")
	_hud_boxes_label = get_node_or_null("../BossHUD/BoxesLabel")
	await get_tree().create_timer(2.0).timeout
	_start_boss()


func _setup_player_health() -> void :
	var player: Node = NetUtil.get_local_player()
	if player == null:
		get_tree().create_timer(0.5).timeout.connect(
			_setup_player_health, CONNECT_ONE_SHOT)
		return
	var hc: HealthComponent = player.get_node_or_null(
		"HealthComponent") as HealthComponent
	if hc == null:
		return
	hc.max_health = 100.0
	hc.current_health = 100.0
	hc.is_dead = false


func _start_boss() -> void :
	_boss_active = true
	var gorgon: Node = get_tree().get_first_node_in_group("Gorgon")
	if gorgon != null and gorgon.has_method("start_throwing"):
		gorgon.start_throwing()


func _process(delta: float) -> void :
	if not _boss_active:
		return
	_timer += delta
	var remaining: float = max(0, BOSS_TIME - _timer)
	if _hud_timer_label != null:
		var m: int = int(remaining) / 60
		var s: int = int(remaining) % 60
		_hud_timer_label.text = "Tid: %02d:%02d" % [m, s]
		if remaining < 30:
			_hud_timer_label.modulate = Color(1, 0.2, 0.2)
	if _timer >= BOSS_TIME:
		_on_time_expired()


func _on_time_expired() -> void :
	_boss_active = false
	DialogueUI.show_dialogue([
		"Tiden er ute.", 
		"Gorgon vant.", 
	], "", func():
		get_tree().change_scene_to_file(
			"res://levels/gorgon_boss_test.tscn")
	)


func _on_boxes_complete() -> void :
	_boss_active = false
	var gorgon: Node = get_tree().get_first_node_in_group("Gorgon")
	if gorgon != null:
		gorgon.stop_throwing()
	DialogueUI.show_dialogue([
		"Alle boksene levert.", 
		"Gorgon gir fra seg gummien.", 
	], "Gorgon", func():
		get_tree().change_scene_to_file(
			"res://levels/gorgon_boss_test.tscn")
	)


func update_boxes_hud(delivered: int, needed: int) -> void :
	if _hud_boxes_label != null:
		_hud_boxes_label.text = "Bokser: %d/%d" % [delivered, needed]
