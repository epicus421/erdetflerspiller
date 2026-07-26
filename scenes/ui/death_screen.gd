extends CanvasLayer

@onready var retry_button: Button = $Overlay / CenterPanel / VBoxContainer / RetryButton
@onready var title_label: Label = $Overlay / CenterPanel / VBoxContainer / TitleLabel
@onready var cause_label: Label = $Overlay / CenterPanel / VBoxContainer / CauseLabel

var _pre_death_master_db: float = 0.0

func _ready() -> void :
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


	if AchievementManager != null and GameManager != null:
		AchievementManager.unlock_for_death(GameManager.last_death_cause)
	_update_text()
	retry_button.pressed.connect(_on_retry_pressed)

	retry_button.grab_focus()
	_schedule_audio_fadeout()


func _schedule_audio_fadeout() -> void :
	var master_idx: = AudioServer.get_bus_index("Master")
	_pre_death_master_db = AudioServer.get_bus_volume_db(master_idx)
	await get_tree().create_timer(3.0).timeout
	var tween: = create_tween()
	tween.tween_method(
		func(db: float) -> void : AudioServer.set_bus_volume_db(master_idx, db), 
		_pre_death_master_db, -80.0, 1.5
	)
	await tween.finished
	get_tree().paused = true


func _unhandled_input(event: InputEvent) -> void :


	var retry: bool = (event is InputEventKey and (event as InputEventKey).pressed\
	and not (event as InputEventKey).echo\
	and (event as InputEventKey).keycode == KEY_SPACE)\
	or (event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed\
	and (event as InputEventJoypadButton).button_index == JOY_BUTTON_A)
	if retry:
		_on_retry_pressed()
		get_viewport().set_input_as_handled()


func _update_text() -> void :
	var cause: String = ""
	if GameManager:
		cause = GameManager.last_death_cause

	var detail: = "Du døde"

	match cause:
		"moose":
			detail = "Det var elgfare her ja."
		"crow":
			detail = "Falturilturaltura, kråka tok deg ja!"
		"moose_rpg":
			detail = "Drept av elg med rakettskyter! Dette spillet er bedre enn Red Dead 2."
		"self_rpg":
			detail = "Du sprenger'e sjæl og kjenner deg helt aleiene\n-Trond Viggo T."
		"security_turret":
			detail = "Du er litt av en mafioso du! (Ikke stjel!)"
		"rabbit":
			detail = "Kaninen gjorde ingenting galt."

	if title_label:
		title_label.text = "GAME OVER"
	if cause_label:
		cause_label.text = detail


func _on_retry_pressed() -> void :
	var master_idx: = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master_idx, _pre_death_master_db)
	get_tree().paused = false
	if GameManager and GameManager.has_method("reset_game"):
		GameManager.reset_game()
	queue_free()
	get_tree().change_scene_to_file("res://scenes/ui/loading_screen.tscn")


func _exit_tree() -> void :
	if get_tree():
		get_tree().paused = false
