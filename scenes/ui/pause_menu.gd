extends CanvasLayer



var _paused: bool = false

@onready var _panel: PanelContainer = $Center / PanelContainer
@onready var _title: Label = $Center / PanelContainer / VBox / Title
@onready var _resume_btn: Button = $Center / PanelContainer / VBox / ResumeButton
@onready var _settings_btn: Button = $Center / PanelContainer / VBox / SettingsButton
@onready var _settings_panel: Control = $Center / PanelContainer / VBox / SettingsPanel
@onready var _settings_back_btn: Button = $Center / PanelContainer / VBox / SettingsBackButton
@onready var _restart_btn: Button = $Center / PanelContainer / VBox / RestartButton
@onready var _quit_btn: Button = $Center / PanelContainer / VBox / QuitButton


func _ready() -> void :
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 80
	visible = false
	if _resume_btn:
		_resume_btn.pressed.connect(_on_resume_pressed)
	if _settings_btn:
		_settings_btn.pressed.connect(_on_settings_pressed)
	if _settings_back_btn:
		_settings_back_btn.pressed.connect(_hide_settings)
	if _settings_panel:
		_settings_panel.visible = false
	if _restart_btn:
		_restart_btn.pressed.connect(_on_restart)
	if _quit_btn:
		_quit_btn.pressed.connect(_on_quit_pressed)
	_build_leave_party_button()


## Multiplayer-only: leaving mid-session previously had no UI at all, so a
## host who wanted out had to alt-F4 (which drops everyone).
var _leave_party_btn: Button = null

func _build_leave_party_button() -> void :
	if _quit_btn == null or _quit_btn.get_parent() == null:
		return
	var btn: = Button.new()
	btn.name = "LeavePartyButton"
	btn.text = "FORLAT ØKTEN"
	btn.visible = false
	btn.pressed.connect(_on_leave_party)
	var box: = _quit_btn.get_parent()
	box.add_child(btn)
	box.move_child(btn, _quit_btn.get_index())
	_leave_party_btn = btn


func _on_leave_party() -> void :
	unpause()
	if NetworkManager != null:
		NetworkManager.leave_and_return_to_title()
	else:
		get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")


func _is_multiplayer() -> bool:
	return NetworkManager != null and NetworkManager.is_active


var _frozen_movement_before: bool = false
var _frozen_camera_before: bool = false
var _froze_local_player: bool = false


## With the SceneTree left running in multiplayer, the local body would still
## walk around behind the menu — so freeze just that body instead of the
## whole world. Restores whatever the flags were before (a dialogue may have
## set them), rather than blindly clearing them.
func _set_local_player_frozen(frozen: bool) -> void :
	# Unfreezing must still run when the session has already ended (host
	# dropped while we were in this menu), or the body stays locked.
	if frozen and not _is_multiplayer():
		return
	if not frozen and not _froze_local_player:
		return
	var player: Node = NetUtil.get_local_player()
	if player == null:
		return
	if frozen:
		if _froze_local_player:
			return
		_frozen_movement_before = bool(player.get("movement_frozen"))
		_frozen_camera_before = bool(player.get("camera_frozen"))
		_froze_local_player = true
		player.set("movement_frozen", true)
		player.set("camera_frozen", true)
		player.set("velocity", Vector3.ZERO)
	else:
		if not _froze_local_player:
			return
		_froze_local_player = false
		player.set("movement_frozen", _frozen_movement_before)
		player.set("camera_frozen", _frozen_camera_before)


func _unhandled_input(event: InputEvent) -> void :

	var toggle: bool = (event is InputEventKey and (event as InputEventKey).pressed\
	and not (event as InputEventKey).echo\
	and (event as InputEventKey).keycode == KEY_ESCAPE)\
	or (event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed\
	and (event as InputEventJoypadButton).button_index == JOY_BUTTON_START)
	if not toggle:
		return
	if _should_block_pause_toggle():
		return
	if _paused:
		if _settings_panel and _settings_panel.visible:
			_hide_settings()
			get_viewport().set_input_as_handled()
			return
		unpause()
	else:
		pause()
	get_viewport().set_input_as_handled()


func _should_block_pause_toggle() -> bool:
	var cur_scene: Node = get_tree().current_scene
	if cur_scene and cur_scene.scene_file_path != "res://levels/main_demo.tscn":
		return true
	if cur_scene and cur_scene.has_node("EndingSequence"):
		return true
	var dui: Node = get_node_or_null("/root/DialogueUI")
	if dui and dui.has_method("is_open") and dui.is_open():
		return true
	if GameManager and GameManager.has_method("is_minigame_active") and GameManager.is_minigame_active():
		return true
	var cur: Node = get_tree().current_scene
	if cur != null:
		var inv: Node = cur.get_node_or_null("InventoryPanel")
		if inv != null and inv.get("is_open") == true:
			return true

	if get_tree().paused and not _paused:
		return true
	return false


func is_menu_paused() -> bool:
	return _paused


func pause() -> void :
	_paused = true
	# In a session the world belongs to everyone, so one player opening a menu
	# must not stop it. Pausing the SceneTree would also freeze every
	# MultiplayerSynchronizer on this machine, so the other players would
	# visibly stall and this player's own body would stop being sent — they'd
	# come back to a world that had moved on without them. Everything that
	# matters here (mouse released, input gated) works without the freeze.
	get_tree().paused = not _is_multiplayer()
	_set_local_player_frozen(true)
	visible = true
	if _panel:
		_panel.show()
	if _leave_party_btn:
		_leave_party_btn.visible = _is_multiplayer()
	if _restart_btn:
		# Restarting is a whole-party decision, not a per-player one — a
		# client reloading the level alone would just desync itself from
		# everyone. "FORLAT ØKTEN" is the multiplayer equivalent.
		_restart_btn.visible = not _is_multiplayer()
	_hide_settings()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if _resume_btn:
		_resume_btn.grab_focus()


func unpause() -> void :
	_paused = false
	get_tree().paused = false
	_set_local_player_frozen(false)
	visible = false
	if _panel:
		_panel.hide()
	_hide_settings()
	var player: Node = NetUtil.get_local_player()
	if player and player.has_method("should_use_fps_mouse_capture") and player.should_use_fps_mouse_capture():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _on_resume_pressed() -> void :
	unpause()


func _on_settings_pressed() -> void :
	if _settings_panel == null:
		return
	if _settings_panel.has_method("refresh_from_game_manager"):
		_settings_panel.refresh_from_game_manager()
	_show_settings()


func _show_settings() -> void :
	if _title:
		_title.text = "Innstillinger"
	if _resume_btn:
		_resume_btn.hide()
	if _settings_btn:
		_settings_btn.hide()
	if _restart_btn:
		_restart_btn.hide()
	if _leave_party_btn:
		_leave_party_btn.hide()
	if _quit_btn:
		_quit_btn.hide()
	if _settings_panel:
		_settings_panel.show()
	if _settings_back_btn:
		_settings_back_btn.show()
		_settings_back_btn.grab_focus()


func _hide_settings() -> void :
	if _title:
		_title.text = "PAUSE"
	if _settings_panel:
		_settings_panel.hide()
	if _settings_back_btn:
		_settings_back_btn.hide()
	if _resume_btn:
		_resume_btn.show()
	if _settings_btn:
		_settings_btn.show()
	if _restart_btn:
		_restart_btn.visible = not _is_multiplayer()
	if _leave_party_btn:
		_leave_party_btn.visible = _is_multiplayer()
	if _quit_btn:
		_quit_btn.show()


	if _paused and _resume_btn:
		_resume_btn.grab_focus.call_deferred()


func _on_restart() -> void :
	unpause()
	GameManager.reset_game()
	get_tree().change_scene_to_file("res://scenes/ui/loading_screen.tscn")




func _on_quit_pressed() -> void :
	unpause()
	# Tear the session down explicitly instead of walking away from a live
	# multiplayer_peer — otherwise the title screen's "VÆR VERT" refuses to
	# start ("Already in a session") until the game is restarted.
	if _is_multiplayer():
		NetworkManager.leave()
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
