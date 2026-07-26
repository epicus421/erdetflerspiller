extends CanvasLayer

signal game_won
signal game_lost

const GORGON_MISTAKE_CHANCE: = 0.15
const GORGON_BLOCK_CHANCE: = 0.4

var _board: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0]
var _player_turn: bool = true
var _buttons: Array[Button] = []
var _status_label: Label = null
var _busy: bool = false


const MINIGAME_ID: = "tictactoe"

func _ready() -> void :
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


	if GameManager and GameManager.has_method("start_minigame"):
		GameManager.start_minigame(MINIGAME_ID)
	_freeze_player(true)
	_holster_weapon()
	_build_ui()


func _exit_tree() -> void :
	if GameManager and str(GameManager.active_minigame_id) == MINIGAME_ID\
	and GameManager.has_method("end_minigame"):
		GameManager.end_minigame(MINIGAME_ID, 0)


func _build_ui() -> void :
	var panel: = ColorRect.new()
	panel.color = Color(0, 0, 0, 0.85)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	var title: = Label.new()
	title.text = "TRE PÅ RAD MED\nGORGON VAKTMESTER"
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_top = 80
	title.offset_left = -200
	title.offset_right = 200
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	add_child(title)

	var grid: = GridContainer.new()
	grid.columns = 3
	grid.set_anchors_preset(Control.PRESET_CENTER)
	grid.offset_left = -120
	grid.offset_top = -120
	grid.offset_right = 120
	grid.offset_bottom = 120
	add_child(grid)



	var focus_style: = StyleBoxFlat.new()
	focus_style.draw_center = false
	focus_style.border_color = Color(1.0, 0.85, 0.2)
	focus_style.set_border_width_all(4)

	for i in range(9):
		var btn: = Button.new()
		btn.custom_minimum_size = Vector2(80, 80)
		btn.add_theme_font_size_override("font_size", 32)
		btn.text = ""
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.add_theme_stylebox_override("focus", focus_style)
		var idx: int = i
		btn.pressed.connect( func() -> void : _on_cell_pressed(idx))
		grid.add_child(btn)
		_buttons.append(btn)

	_status_label = Label.new()
	_status_label.text = "Din tur"
	_status_label.set_anchors_preset(Control.PRESET_CENTER)
	_status_label.offset_top = 150
	_status_label.offset_left = -150
	_status_label.offset_right = 150
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 18)
	add_child(_status_label)



	_focus_playable_cell.call_deferred()



func _focus_playable_cell() -> void :
	if _board[4] == 0 and not _buttons[4].disabled:
		_buttons[4].grab_focus()
		return
	for i in range(9):
		if _board[i] == 0 and not _buttons[i].disabled:
			_buttons[i].grab_focus()
			return


func _on_cell_pressed(idx: int) -> void :
	if _busy or not _player_turn:
		return
	if _board[idx] != 0:
		return

	_board[idx] = 1
	_buttons[idx].text = "X"
	_buttons[idx].modulate = Color(0.3, 0.9, 0.3)
	_player_turn = false

	if _check_winner() == 1:
		_on_player_wins()
		return
	if _is_board_full():
		_on_draw()
		return

	_status_label.text = "Gorgon tenker..."
	_busy = true
	await get_tree().create_timer(0.6).timeout


	var voice_len: = _play_gorgon_place()
	if voice_len > 0.0:
		await get_tree().create_timer(voice_len).timeout
	_gorgon_move()
	_busy = false


func _play_gorgon_place() -> float:
	var gorgon: Node = get_tree().get_first_node_in_group("Gorgon")
	if gorgon != null and gorgon.has_method("play_ttt_place"):
		return gorgon.play_ttt_place()
	return 0.0


func _gorgon_move() -> void :
	var move: = -1

	if randf() < GORGON_MISTAKE_CHANCE:
		move = _pick_random_move()
	else:
		move = _find_winning_move(2)
		if move == -1 and randf() < GORGON_BLOCK_CHANCE:
			move = _find_winning_move(1)
		if move == -1:
			var candidates: Array[int] = []
			if _board[4] == 0:
				candidates.append(4)
			for corner in [0, 2, 6, 8]:
				if _board[corner] == 0:
					candidates.append(corner)
			for i in range(9):
				if _board[i] == 0 and not candidates.has(i):
					candidates.append(i)
			if not candidates.is_empty():
				move = candidates[randi() % candidates.size()]

	if move == -1:
		move = _pick_random_move()
	if move == -1:
		return

	_board[move] = 2
	_buttons[move].text = "O"
	_buttons[move].modulate = Color(0.9, 0.2, 0.2)
	_player_turn = true

	if _check_winner() == 2:
		_on_gorgon_wins()
		return
	if _is_board_full():
		_on_draw()
		return
	_status_label.text = "Din tur"

	_focus_playable_cell()


func _find_winning_move(player: int) -> int:
	var lines: Array = [
		[0, 1, 2], [3, 4, 5], [6, 7, 8], 
		[0, 3, 6], [1, 4, 7], [2, 5, 8], 
		[0, 4, 8], [2, 4, 6], 
	]
	for line in lines:
		var vals: Array = [_board[line[0]], _board[line[1]], _board[line[2]]]
		if vals.count(player) == 2 and vals.count(0) == 1:
			for j in range(3):
				if _board[line[j]] == 0:
					return line[j]
	return -1


func _pick_random_move() -> int:
	var open: Array[int] = []
	for i in range(9):
		if _board[i] == 0:
			open.append(i)
	if open.is_empty():
		return -1
	return open[randi() % open.size()]


func _check_winner() -> int:
	var lines: Array = [
		[0, 1, 2], [3, 4, 5], [6, 7, 8], 
		[0, 3, 6], [1, 4, 7], [2, 5, 8], 
		[0, 4, 8], [2, 4, 6], 
	]
	for line in lines:
		var a: int = _board[line[0]]
		if a != 0 and a == _board[line[1]] and a == _board[line[2]]:
			return a
	return 0


func _is_board_full() -> bool:
	return not _board.has(0)


func _restore_gameplay() -> void :
	_freeze_player(false)
	_restore_weapon_controls()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _freeze_player(frozen: bool) -> void :
	var player: = NetUtil.get_local_player()
	if player != null and player.has_method("freeze_for_dialogue"):
		player.freeze_for_dialogue(frozen)


func _holster_weapon() -> void :
	var weapon_mgr: = _get_weapon_manager()
	if weapon_mgr != null and weapon_mgr.has_method("holster_for_dialogue"):
		weapon_mgr.holster_for_dialogue()


func _restore_weapon_controls() -> void :
	var weapon_mgr: = _get_weapon_manager()
	if weapon_mgr != null and weapon_mgr.has_method("restore_after_dialogue"):
		weapon_mgr.restore_after_dialogue()


func _get_weapon_manager() -> Node:
	var wm: = get_tree().get_first_node_in_group("WeaponManager")
	if wm != null:
		return wm
	return get_tree().get_first_node_in_group("WeaponViewmodelController")


func _on_player_wins() -> void :
	_status_label.text = "Du vant!"
	_disable_all_buttons()
	await get_tree().create_timer(0.5).timeout
	var tree: = get_tree()
	_restore_gameplay()
	queue_free()
	var gorgon_node: Node = tree.get_first_node_in_group("Gorgon")
	var on_win: = func() -> void :
		GameManager.add_item("gummi", 1)
		if GameManager.gorgon_stolen_item == "gummi":
			GameManager.gorgon_stolen_item = ""
		GameManager.update_quest_objective("GORGON_ROBBERY", "play_tictactoe", 1)
		var quest: Quest = GameManager.active_quests.get("GORGON_ROBBERY") as Quest
		if quest != null and quest.is_complete():
			GameManager.complete_quest_by_id(quest.quest_id)
		if gorgon_node != null and gorgon_node.has_method("stop_throwing"):
			gorgon_node.stop_throwing()
	if gorgon_node != null and gorgon_node.has_method("show_ttt_win_dialogue"):
		gorgon_node.show_ttt_win_dialogue(on_win)
	else:
		on_win.call()
	game_won.emit()


func _on_gorgon_wins() -> void :
	_status_label.text = "Gorgon vant."
	_disable_all_buttons()
	await get_tree().create_timer(0.5).timeout
	var tree: = get_tree()
	_restore_gameplay()
	queue_free()
	var gorgon_node: Node = tree.get_first_node_in_group("Gorgon")
	var on_lose: = func() -> void :
		var scene: PackedScene = load("res://scenes/minigames/tictactoe.tscn") as PackedScene
		if scene != null:
			tree.root.add_child(scene.instantiate())
	if gorgon_node != null and gorgon_node.has_method("show_ttt_lose_dialogue"):
		gorgon_node.show_ttt_lose_dialogue(on_lose)
	else:
		on_lose.call()
	game_lost.emit()


func _on_draw() -> void :
	_status_label.text = "Uavgjort."
	_disable_all_buttons()
	await get_tree().create_timer(0.5).timeout
	var tree: = get_tree()
	_restore_gameplay()
	queue_free()
	var gorgon_node: Node = tree.get_first_node_in_group("Gorgon")
	var on_draw: = func() -> void :
		var scene: PackedScene = load("res://scenes/minigames/tictactoe.tscn") as PackedScene
		if scene != null:
			tree.root.add_child(scene.instantiate())
	if gorgon_node != null and gorgon_node.has_method("show_ttt_draw_dialogue"):
		gorgon_node.show_ttt_draw_dialogue(on_draw)
	else:
		on_draw.call()


func _disable_all_buttons() -> void :
	for btn in _buttons:
		btn.disabled = true
