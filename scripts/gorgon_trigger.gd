extends Area3D

const HEAD_HIT_PATH: = "res://assets/sfx/erdetlyd/splice/punchsfx_gorgon.wav"
const GORGON_LAUGH_PATH: = "res://assets/sfx/erdetlyd/vox/gorgon/stopherkommer.ogg"

const MUSIC_FADE_DURATION: = 4.0

var _triggered: bool = false


func _ready() -> void :
	add_to_group("GorgonTrigger")
	monitoring = true
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void :
	if _triggered:
		return
	if not body.is_in_group("PlayerCharacter"):
		return
	var has_all: bool = (
		GameManager.has_item("kobber")
		and GameManager.has_item("plast")
		and GameManager.has_item("gummi")
	)
	if not has_all:
		return
	if not GameManager.has_active_quest("HVERDAGSKOMIKER"):
		return
	if not GameManager.has_item("gummi"):
		return
	_triggered = true
	_fade_then_rob()


func _fade_then_rob() -> void :

	var bus_idx: = AudioServer.get_bus_index("Music")
	var original_vol: = AudioServer.get_bus_volume_db(bus_idx)
	var tween: = get_tree().create_tween()
	tween.tween_method(
		func(v: float) -> void : AudioServer.set_bus_volume_db(bus_idx, v), 
		original_vol, -80.0, MUSIC_FADE_DURATION
	)
	await tween.finished
	MusicManager.stop(true)
	AudioServer.set_bus_volume_db(bus_idx, original_vol)
	_start_robbery()


func _start_robbery() -> void :
	var player: Node3D = NetUtil.get_local_player() as Node3D
	if player == null:
		_triggered = false
		return
	if not GameManager.has_item("gummi"):
		_triggered = false
		return

	GameManager.remove_item("gummi", 1)
	GameManager.gorgon_stolen_item = "gummi"



	GameManager.set_quest_hint("HVERDAGSKOMIKER", "Finn gummien din igjen")

	var audio: = AudioStreamPlayer.new()
	audio.bus = "Sfx"
	get_tree().root.add_child(audio)
	if ResourceLoader.exists(GORGON_LAUGH_PATH):
		audio.stream = load(GORGON_LAUGH_PATH)
		audio.play()

		await get_tree().create_timer(0.6).timeout

	_freeze_player(player, true)

	if ResourceLoader.exists(HEAD_HIT_PATH):
		audio.stream = load(HEAD_HIT_PATH)
		audio.play()

	var camera: = _get_player_camera(player)
	if camera != null:
		var fall_tween: Tween = get_tree().create_tween()
		fall_tween.tween_property(camera, "rotation:x", -1.4, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		await fall_tween.finished

	var canvas: = CanvasLayer.new()
	canvas.layer = 99
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	var overlay: = ColorRect.new()
	overlay.color = Color(0, 0, 0, 1)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(overlay)
	get_tree().root.add_child(canvas)
	audio.queue_free()

	await get_tree().create_timer(0.8).timeout

	if camera != null:
		camera.rotation.x = 0.0
	if player != null and player.has_method("reset_zoom"):
		player.reset_zoom()

	canvas.queue_free()

	var horror: = get_tree().get_first_node_in_group("GorgonHorror")
	if horror != null and horror.has_method("activate"):
		horror.activate()
	else:
		_fallback_wake(player, camera)


func _fallback_wake(player: Node3D, camera: Camera3D) -> void :
	var canvas: = CanvasLayer.new()
	canvas.layer = 99
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	var overlay: = ColorRect.new()
	overlay.color = Color(0, 0, 0, 1)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(overlay)
	get_tree().root.add_child(canvas)

	var fade_tween: Tween = get_tree().create_tween()
	fade_tween.tween_property(overlay, "color:a", 0.0, 2.0)
	await fade_tween.finished
	canvas.queue_free()

	_freeze_player(player, false)

	DialogueUI.show_dialogue(
		[
			"Gummien din er borte...", 
			"Noen slo deg i hodet.", 
			"Finn den skyldige.", 
		], 
		"", 
		Callable()
	)

	if not GameManager.has_quest("GORGON_ROBBERY"):
		GameManager.add_quest_by_id("GORGON_ROBBERY")


func _get_player_camera(player: Node) -> Camera3D:
	return player.get_node_or_null("CameraHolder/CameraRecoilHolder/Camera") as Camera3D


func _freeze_player(player: Node, frozen: bool) -> void :
	if player == null:
		return
	player.process_mode = Node.PROCESS_MODE_DISABLED if frozen else Node.PROCESS_MODE_INHERIT
