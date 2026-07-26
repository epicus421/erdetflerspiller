extends CanvasLayer

const FORM_TIME: float = 40.0
const RED_TIME: float = 20.0
const FLASH_TIME: float = 10.0
const PENALTY_TIME: float = 15.0
const BLINK_INTERVAL: float = 0.25
const TICK_SOUND: String = "res://assets/sfx/erdetlyd/splice/beep.wav"
const SIGNATURE_LINE_WIDTH: = 2.0
const RESULT_OVERLAY_DURATION: = 2.0

const NORMAL_QUESTIONS: Array[String] = [
	"Spillernavn:", 
	"Fødselsdato:", 
	"Adresse:", 
	"Postnummer:", 
	"Telefonnummer:", 
	"E-postadresse:"
]

const UNUSUAL_QUESTIONS: Array[String] = [
	"Favorittfarge på brød:", 
	"Antall ganger du har tenkt på elg denne uken:", 
	"Beskriv lukten av en mandag:", 
	"Hva er din mening om grus som matvare?", 
	"Oppgi din nærmeste nabos bilmerke:"
]

const EXISTENTIAL_QUESTIONS: Array[String] = [
	"Hvorfor er du her?", 
	"Hva er egentlig penger?", 
	"Hadde du fortjent dette stipendet?", 
	"Er du sikker på at dette er riktig valg?", 
	"Hva ville mormor ha sagt?"
]

@export var success_sound: AudioStream
@export var fail_sound: AudioStream
@export var approved_sound: AudioStream
@export var rejected_sound: AudioStream
@export var error_sound: AudioStream

@onready var form_panel: PanelContainer = $FormPanel
@onready var questions_container: VBoxContainer = $FormPanel / RootVBox / ScrollContainer / QuestionsVBox
@onready var timer_label: Label = $FormPanel / RootVBox / HeaderHBox / TimerLabel
@onready var status_label: Label = $FormPanel / RootVBox / StatusLabel
@onready var signature_frame: PanelContainer = $FormPanel / RootVBox / SignatureFrame
@onready var signature_box: Control = $FormPanel / RootVBox / SignatureFrame / SignatureBox
@onready var submit_button: Button = $FormPanel / RootVBox / FooterHBox / SubmitButton
@onready var clear_button: Button = $FormPanel / RootVBox / FooterHBox / ClearButton
@onready var error_label: Label = $FormPanel / RootVBox / ErrorLabel
@onready var rejection_overlay: ColorRect = $FormPanel / RejectionOverlay
@onready var rejection_reason_label: Label = $FormPanel / RejectionOverlay / Dialog / Margin / VBox / ReasonLabel
@onready var rejection_extra_label: Label = $FormPanel / RejectionOverlay / Dialog / Margin / VBox / ExtraLabel
@onready var result_overlay: ColorRect = $ResultOverlay
@onready var result_label: Label = $ResultOverlay / ResultLabel
@onready var success_audio: AudioStreamPlayer = $SuccessAudio
@onready var fail_audio: AudioStreamPlayer = $FailAudio

var question_labels: Array[Label] = []
var input_fields: Array[LineEdit] = []

var signature_points: Array[Vector2] = []
var signature_break_indices: Array[int] = []
var signature_has_content: bool = false
var signature_out_of_bounds: bool = false
var signature_rect: Rect2 = Rect2()
var _is_drawing_signature: bool = false

var _time_remaining: float = FORM_TIME
var _is_resolved: bool = false
var _closed_with_end_call: bool = false
var _is_submitting: bool = false
var _tick_audio: AudioStreamPlayer = null
var _last_tick: int = -1
var _time_bar: ProgressBar = null

var _default_line_edit_style: StyleBox
var _default_signature_style: StyleBox
var _empty_field_style: StyleBox
var _signature_error_style: StyleBox

const COLOR_TEXT: = Color(0.95, 0.95, 0.95)
const COLOR_QUESTION: = Color(0.85, 0.85, 0.85)
const COLOR_TIMER_OK: = Color(0.75, 0.75, 0.78)
const COLOR_TIMER_WARN: = Color(0.95, 0.35, 0.35)

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cache_fields()
	_apply_visual_style()
	_configure_result_audio()
	form_panel.visible = true
	if submit_button and not submit_button.pressed.is_connected(_on_submit_pressed):
		submit_button.pressed.connect(_on_submit_pressed)
	if clear_button and not clear_button.pressed.is_connected(_on_clear_button_pressed):
		clear_button.pressed.connect(_on_clear_button_pressed)
	_tick_audio = AudioStreamPlayer.new()
	_tick_audio.process_mode = Node.PROCESS_MODE_ALWAYS
	if ResourceLoader.exists(TICK_SOUND):
		_tick_audio.stream = load(TICK_SOUND)
	_tick_audio.volume_db = -6.0
	add_child(_tick_audio)
	_create_time_bar()
	call_deferred("_initialize_form_contents")
	_set_player_form_mode(true)

func _initialize_form_contents():
	await get_tree().process_frame
	_reset_form_state()

func _process(delta: float):
	if _is_resolved:
		return
	if get_tree().paused:
		return
	_time_remaining = max(0.0, _time_remaining - delta)
	_update_timer_label()
	if _time_remaining <= 0.0 and not _is_submitting:
		_is_submitting = true
		_on_time_expired()

func _exit_tree():
	if not _is_resolved:
		_set_player_form_mode(false)

func _cache_fields():
	question_labels = [
		$FormPanel / RootVBox / ScrollContainer / QuestionsVBox / Q1Box / VBox / QuestionLabel, 
		$FormPanel / RootVBox / ScrollContainer / QuestionsVBox / Q2Box / VBox / QuestionLabel, 
		$FormPanel / RootVBox / ScrollContainer / QuestionsVBox / Q3Box / VBox / QuestionLabel, 
		$FormPanel / RootVBox / ScrollContainer / QuestionsVBox / Q4Box / VBox / QuestionLabel
	]
	input_fields = [
		$FormPanel / RootVBox / ScrollContainer / QuestionsVBox / Q1Box / VBox / Input, 
		$FormPanel / RootVBox / ScrollContainer / QuestionsVBox / Q2Box / VBox / Input, 
		$FormPanel / RootVBox / ScrollContainer / QuestionsVBox / Q3Box / VBox / Input, 
		$FormPanel / RootVBox / ScrollContainer / QuestionsVBox / Q4Box / VBox / Input
	]
	for i in input_fields.size():
		var idx: = i
		input_fields[i].text_changed.connect( func(t: String) -> void :
			_maybe_autoformat_date(idx, t))
	_default_line_edit_style = input_fields[0].get_theme_stylebox("normal")
	_default_signature_style = signature_frame.get_theme_stylebox("panel")
	_empty_field_style = _make_input_style(Color(0.55, 0.2, 0.2, 1.0))
	_signature_error_style = _make_input_style(Color(0.9, 0.25, 0.25, 1.0))
	signature_rect = Rect2(Vector2.ZERO, signature_box.size)


func _apply_visual_style() -> void :
	pass



func _maybe_autoformat_date(field_index: int, new_text: String) -> void :
	if field_index >= question_labels.size() or field_index >= input_fields.size():
		return
	if not question_labels[field_index].text.begins_with("Fødselsdato"):
		return
	var digits: = ""
	for ch in new_text:
		if ch >= "0" and ch <= "9":
			digits += ch
			if digits.length() >= 8:
				break
	var formatted: = ""
	for i in digits.length():
		if i == 2 or i == 4:
			formatted += "."
		formatted += digits[i]
	if formatted == new_text:
		return
	var field: = input_fields[field_index]
	field.text = formatted
	field.caret_column = formatted.length()

func _reset_form_state():
	_is_resolved = false
	_closed_with_end_call = false
	_is_submitting = false
	_last_tick = -1
	_time_remaining = FORM_TIME
	_update_timer_label()
	rejection_overlay.hide()
	rejection_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_overlay.hide()
	result_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_assign_random_questions()
	for field in input_fields:
		field.text = ""
		field.visible = true
		field.custom_minimum_size = Vector2(0, 32)
		field.add_theme_color_override("font_color", COLOR_TEXT)
		field.add_theme_stylebox_override("normal", _default_line_edit_style)
		field.add_theme_stylebox_override("focus", _default_line_edit_style)
	signature_points.clear()
	signature_break_indices.clear()
	signature_has_content = false
	signature_out_of_bounds = false
	_is_drawing_signature = false
	signature_frame.add_theme_stylebox_override("panel", _default_signature_style)
	signature_box.queue_redraw()
	status_label.text = ""
	if error_label:
		error_label.text = ""
		error_label.visible = false
	submit_button.disabled = false
	submit_button.text = "Send inn søknad"
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _assign_random_questions():
	if questions_container == null:
		push_warning("Questions container is null; cannot assign questions.")
		return
	var existential: = EXISTENTIAL_QUESTIONS[randi() % EXISTENTIAL_QUESTIONS.size()]
	var pool: Array[String] = []
	pool.append_array(NORMAL_QUESTIONS)
	pool.append_array(UNUSUAL_QUESTIONS)
	pool.shuffle()
	var selected: Array[String] = [existential]
	for i in range(3):
		selected.append(pool[i])
	selected.shuffle()
	for i in range(question_labels.size()):
		question_labels[i].text = selected[i]
		question_labels[i].visible = true
		question_labels[i].add_theme_color_override("font_color", COLOR_QUESTION)
		question_labels[i].autowrap_mode = TextServer.AUTOWRAP_WORD

func _create_time_bar() -> void :

	_time_bar = ProgressBar.new()
	_time_bar.custom_minimum_size = Vector2(0, 6)
	_time_bar.show_percentage = false
	_time_bar.max_value = 1.0
	_time_bar.value = 1.0
	var fill: = StyleBoxFlat.new()
	fill.bg_color = COLOR_TIMER_WARN
	_time_bar.add_theme_stylebox_override("fill", fill)
	var bg: = StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.12, 0.12, 0.7)
	_time_bar.add_theme_stylebox_override("background", bg)
	_time_bar.visible = false
	var root_vbox: = $FormPanel / RootVBox as VBoxContainer
	root_vbox.add_child(_time_bar)
	root_vbox.move_child(_time_bar, 1)


func _update_timer_label():
	var secs: = int(ceil(_time_remaining))
	timer_label.text = "%ds" % secs
	if _time_bar != null:
		_time_bar.visible = _time_remaining <= RED_TIME
		_time_bar.value = clampf(_time_remaining / RED_TIME, 0.0, 1.0)
	if _time_remaining <= FLASH_TIME:
		var blink_on: bool = int(Time.get_ticks_msec() / int(BLINK_INTERVAL * 1000.0)) % 2 == 0
		timer_label.add_theme_color_override(
			"font_color", 
			Color.WHITE if blink_on else COLOR_TIMER_WARN
		)
		var tick_second: = int(ceil(_time_remaining))
		if tick_second != _last_tick:
			_last_tick = tick_second
			if _tick_audio != null and _tick_audio.stream != null:
				_tick_audio.play()
	elif _time_remaining <= RED_TIME:
		timer_label.add_theme_color_override("font_color", COLOR_TIMER_WARN)
		_last_tick = -1
	else:
		timer_label.add_theme_color_override("font_color", COLOR_TIMER_OK)
		_last_tick = -1


func _on_time_expired() -> void :
	if _is_resolved:
		return
	GameManager.set_scholarship_penalty(PENALTY_TIME)
	await _show_result_and_close(false, "SØKNAD AVVIST ✗")


func _reject_form(reason: String = "") -> void :
	if _is_resolved:
		return
	GameManager.set_scholarship_penalty(PENALTY_TIME)
	var lines: Array[String] = []
	if reason != "":
		lines = [reason, "Du kan prøve igjen om 15 sekunder."]
	else:
		lines = ["Søknaden er avvist.", "Du kan prøve igjen om 15 sekunder."]
	_play_ephemeral_result_sound(rejected_sound if rejected_sound else fail_sound)
	_is_resolved = true
	_closed_with_end_call = true
	GameManager.end_minigame("scholarship_form", 0)
	if DialogueUI:
		DialogueUI.show_dialogue(lines, "Lånekassa", Callable())
	queue_free()


func _validate_and_submit(from_timeout: bool = false) -> void :
	if _is_resolved:
		return
	if from_timeout:
		await _on_time_expired()
		return
	if signature_out_of_bounds:
		_show_field_error("Signaturen er utenfor feltet.")
		submit_button.disabled = false
		submit_button.text = "Send inn søknad"
		_is_submitting = false
		return
	if not signature_has_content:
		signature_frame.add_theme_stylebox_override("panel", _signature_error_style)
		_show_field_error("Du må signere søknaden.")
		submit_button.disabled = false
		submit_button.text = "Send inn søknad"
		_is_submitting = false
		return
	signature_frame.add_theme_stylebox_override("panel", _default_signature_style)
	var error: = _validate_all_fields()
	if error != "":
		if error.begins_with("HARD_FAIL:"):
			await _reject_form(error.replace("HARD_FAIL:", ""))
		else:
			_show_field_error(error)
			submit_button.disabled = false
			submit_button.text = "Send inn søknad"
			_is_submitting = false
		return
	_show_field_error("")
	await _show_result_and_close(true, "SØKNAD GODKJENT ✓")

func _finish_success():
	if _is_resolved:
		return
	_is_resolved = true
	_closed_with_end_call = true
	GameManager.end_minigame("scholarship_form", 1)
	_set_player_form_mode(false)
	queue_free()

func _finish_hard_fail():
	if _is_resolved:
		return
	_is_resolved = true
	_reset_scholarship_minigame_progress()
	_closed_with_end_call = true
	GameManager.end_minigame("scholarship_form", 0)
	_set_player_form_mode(false)
	queue_free()

func _show_rejection(reason: String, extra: String = ""):
	rejection_reason_label.text = reason
	rejection_extra_label.text = extra
	rejection_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	rejection_overlay.show()
	_finish_hard_fail()

func _configure_result_audio() -> void :


	if success_audio:
		success_audio.stream = success_sound
	if fail_audio:
		fail_audio.stream = fail_sound

func _show_result_and_close(success: bool, text: String) -> void :
	if _is_resolved:
		return
	result_label.text = text
	result_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3, 1.0) if success else Color(0.9, 0.2, 0.2, 1.0))
	result_overlay.show()
	var stream: AudioStream = approved_sound if success else rejected_sound
	if stream == null:
		stream = success_sound if success else fail_sound
	_play_ephemeral_result_sound(stream)
	await get_tree().create_timer(RESULT_OVERLAY_DURATION).timeout
	if success:
		_finish_success()
	else:
		_finish_hard_fail()

func _reset_scholarship_minigame_progress():
	var quest: Quest = GameManager.active_quests.get("SCHOLARSHIP_APPLICATION")
	if quest == null:
		return
	var objective_id: = "complete_scholarship_form"
	if not quest.objective_progress.has(objective_id):
		quest.objective_progress[objective_id] = 0
		return
	quest.objective_progress[objective_id] = 0
	GameManager.quest_progress_updated.emit(quest.quest_id, quest.get_total_progress())

func _set_player_form_mode(enabled: bool):
	var player = NetUtil.get_local_player()
	if player and player.has_method("freeze_for_dialogue"):
		player.freeze_for_dialogue(enabled)
	if player and player.has_method("set_weapon_active"):
		player.set_weapon_active( not enabled)
	if enabled:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		if player and player.has_method("should_use_fps_mouse_capture") and player.should_use_fps_mouse_capture():
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_submit_pressed() -> void :
	if _is_submitting:
		return
	_is_submitting = true
	submit_button.disabled = true
	submit_button.text = "Behandler..."
	await get_tree().process_frame
	await _validate_and_submit(false)

func _on_clear_button_pressed():
	signature_points.clear()
	signature_break_indices.clear()
	signature_has_content = false
	signature_out_of_bounds = false
	_is_drawing_signature = false
	signature_frame.add_theme_stylebox_override("panel", _default_signature_style)
	signature_box.queue_redraw()
	status_label.text = ""
	_show_field_error("")

func _on_rejection_ok_button_pressed():
	if not _is_resolved:
		_finish_hard_fail()
	_set_player_form_mode(false)
	queue_free()

func _on_signature_box_gui_input(event: InputEvent):
	if _is_resolved:
		return
	var local_rect: = Rect2(Vector2.ZERO, signature_box.size)
	signature_rect = local_rect

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_is_drawing_signature = event.pressed
		if _is_drawing_signature:
			if not signature_points.is_empty():
				signature_break_indices.append(signature_points.size())
			var point = event.position
			if local_rect.has_point(point):
				signature_points.append(point)
				signature_has_content = true
			else:
				signature_out_of_bounds = true
				signature_frame.add_theme_stylebox_override("panel", _signature_error_style)
		signature_box.queue_redraw()
		return

	if event is InputEventMouseMotion and _is_drawing_signature:
		var point = event.position
		if local_rect.has_point(point):
			signature_points.append(point)
			signature_has_content = true
		else:
			signature_out_of_bounds = true
			signature_frame.add_theme_stylebox_override("panel", _signature_error_style)
		signature_box.queue_redraw()

func _on_signature_box_mouse_exited():
	_is_drawing_signature = false

func _on_signature_box_draw():
	var rect: = Rect2(Vector2.ZERO, signature_box.size)
	signature_box.draw_rect(rect, Color(0.18, 0.18, 0.2, 1.0), true)
	signature_box.draw_rect(rect, Color(0.4, 0.4, 0.45, 1.0), false, 1.0)
	if signature_points.size() < 2:
		return
	for i in range(1, signature_points.size()):
		if signature_break_indices.has(i):
			continue
		signature_box.draw_line(
			signature_points[i - 1], 
			signature_points[i], 
			Color(0.95, 0.95, 0.95), 
			SIGNATURE_LINE_WIDTH
		)


func _make_input_style(border_color: Color) -> StyleBoxFlat:
	var style: = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.22, 1.0)
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(6)
	return style


func _signature_valid() -> bool:
	if signature_out_of_bounds:
		return false
	if not signature_has_content or not _signature_is_substantial(signature_points):
		signature_frame.add_theme_stylebox_override("panel", _signature_error_style)
		return false
	signature_frame.add_theme_stylebox_override("panel", _default_signature_style)
	return true



func _signature_is_substantial(points: Array[Vector2]) -> bool:
	if points.size() < 20:
		return false
	var mn: Vector2 = points[0]
	var mx: Vector2 = points[0]
	for p in points:
		mn = mn.min(p)
		mx = mx.max(p)
	return (mx - mn).length() >= 30.0


func _validate_all_fields() -> String:
	if question_labels.size() != input_fields.size():
		return "Skjemafeil: antall spørsmål stemmer ikke."
	for field in input_fields:
		field.add_theme_stylebox_override("normal", _default_line_edit_style)
	for i in range(question_labels.size()):
		var question: = question_labels[i].text.strip_edges()
		var value: = input_fields[i].text.strip_edges()
		if value.is_empty():
			input_fields[i].add_theme_stylebox_override("normal", _empty_field_style)
		var error: = _validate_field_by_question(question, value)
		if error != "":
			return error
	return ""


func _qerr(question: String, detail: String) -> String:
	return "«%s» — %s" % [question, detail]


func _validate_field_by_question(question: String, value: String) -> String:
	var lower: = value.to_lower()

	match question:
		"Spillernavn:":
			if value.is_empty():
				return _qerr(question, "feltet kan ikke være tomt.")


			if value.to_lower() != String(GameManager.player_name).to_lower():
				return _qerr(question, "navnet stemmer ikke med spillernavnet ditt.")

		"Fødselsdato:":
			if value.is_empty():
				return _qerr(question, "feltet kan ikke være tomt.")
			for c in value:
				if c != "." and not (c >= "0" and c <= "9"):
					return _qerr(question, "bruk kun tall og punktum (DD.MM.ÅÅÅÅ).")
			var date_regex: = RegEx.new()
			date_regex.compile("^\\d{2}\\.\\d{2}\\.\\d{4}$")
			if date_regex.search(value) == null:
				return _qerr(question, "bruk formatet DD.MM.ÅÅÅÅ.")

		"Adresse:":
			if value.is_empty():
				return _qerr(question, "feltet kan ikke være tomt.")
			var has_letter: = false
			var has_number: = false
			for c in value:
				if c >= "0" and c <= "9":
					has_number = true
				elif c.is_subsequence_of("abcdefghijklmnopqrstuvwxyzæøåABCDEFGHIJKLMNOPQRSTUVWXYZÆØÅ"):
					has_letter = true
			if not has_number:
				return _qerr(question, "adressen må inneholde gatenummer.")
			if not has_letter:
				return _qerr(question, "adressen må inneholde gatenavn.")

		"Postnummer:":
			if value.length() != 4:
				return _qerr(question, "postnummer må være nøyaktig 4 siffer.")
			if not value.is_valid_int():
				return _qerr(question, "postnummer kan kun inneholde tall.")

		"Telefonnummer:":
			if value.length() != 8:
				return _qerr(question, "telefonnummer må være nøyaktig 8 siffer.")
			if not value.is_valid_int():
				return _qerr(question, "telefonnummer kan kun inneholde tall.")

		"E-postadresse:":
			if value.is_empty():
				return _qerr(question, "feltet kan ikke være tomt.")
			if not value.contains("@"):
				return _qerr(question, "e-post må inneholde @.")
			var at_idx: = value.find("@")
			var dot_idx: = value.rfind(".")
			if at_idx <= 0 or dot_idx <= at_idx + 1 or dot_idx >= value.length() - 1:
				return _qerr(question, "ugyldig e-postadresse.")

		"Favorittfarge på brød:":
			if value.is_empty():
				return _qerr(question, "feltet kan ikke være tomt.")
			var color_regex: = RegEx.new()
			color_regex.compile("^[A-Za-zÆØÅæøå ]+$")
			if color_regex.search(value) == null:
				return _qerr(question, "bruk bare bokstaver (ingen tall eller spesialtegn).")

		"Antall ganger du har tenkt på elg denne uken:":
			if value.is_empty():
				return _qerr(question, "feltet kan ikke være tomt.")
			if not value.is_valid_int():
				return _qerr(question, "skriv et heltall (kun tall, ingen bokstaver).")

		"Beskriv lukten av en mandag:":
			if value.length() < 3:
				return _qerr(question, "utdyp svaret (minst tre tegn).")

		"Hva er din mening om grus som matvare?":
			if lower != "ja" and lower != "nei":
				return _qerr(question, "svar «ja» eller «nei».")

		"Oppgi din nærmeste nabos bilmerke:":
			if value.is_empty():
				return _qerr(question, "feltet kan ikke være tomt.")
			var brand_regex: = RegEx.new()
			brand_regex.compile("^[A-Za-zÆØÅæøå ]+$")
			if brand_regex.search(value) == null:
				return _qerr(question, "bruk bare bokstaver (ingen tall).")

		"Hvorfor er du her?":
			if value.length() < 5:
				return _qerr(question, "utdyp svaret (minst fem tegn).")

		"Hva er egentlig penger?":
			if value.length() < 3:
				return _qerr(question, "utdyp svaret.")

		"Hadde du fortjent dette stipendet?":
			if lower == "nei":
				return "HARD_FAIL:Søknaden er avvist. Du innrømmet selv at du ikke fortjener det."
			if lower != "ja" and lower != "nei":
				return _qerr(question, "svar «ja» eller «nei».")

		"Er du sikker på at dette er riktig valg?":
			if lower == "nei":
				return _qerr(question, "Du må svare «ja» for å gå videre.")
			if lower != "ja" and lower != "nei":
				return _qerr(question, "svar «ja» eller «nei».")

		"Hva ville mormor ha sagt?":
			if value.length() < 3:
				return _qerr(question, "utdyp svaret (minst tre tegn).")

	return ""


func _show_field_error(message: String) -> void :
	if error_label == null:
		return
	error_label.text = message
	error_label.modulate = Color(1, 0, 0, 1)
	error_label.visible = not message.is_empty()
	if not message.is_empty():
		_play_ephemeral_result_sound(error_sound)


func _play_ephemeral_result_sound(stream: AudioStream) -> void :
	if stream == null:
		return
	var audio: = AudioStreamPlayer.new()
	add_child(audio)
	audio.stream = stream
	audio.play()
	audio.finished.connect( func(): audio.queue_free())
