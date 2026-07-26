extends Area3D



const _ItemNotification: = preload("res://scenes/ui/item_notification.gd")
const PICKUP_SFX: = preload("res://assets/sfx/erdetlyd/splice/gravelpickup.wav")

@export var ammo_amount: int = 5
@export var max_pickups: int = 3
@export var pickup_label_text: String = "E — Plukk opp grus"

var _pickup_count: int = 0
var _player_nearby: Node = null
var _pickup_label: Label3D = null


func _ready() -> void :
	monitoring = true
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)
	_setup_pickup_label()


func _setup_pickup_label() -> void :
	_pickup_label = Label3D.new()
	_pickup_label.name = "PickupLabel"
	_pickup_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_pickup_label.pixel_size = 0.005
	_pickup_label.font_size = 28
	_pickup_label.outline_size = 12
	_pickup_label.outline_modulate = Color(0, 0, 0, 1)
	_pickup_label.position = Vector3(0, 0.8, 0)
	_pickup_label.modulate = Color(1, 1, 1)
	_pickup_label.text = pickup_label_text
	_pickup_label.no_depth_test = true
	_pickup_label.visible = false
	add_child(_pickup_label)


func _set_label_visible(visible: bool) -> void :
	if _pickup_label != null:
		_pickup_label.visible = visible


func _on_entered(body: Node3D) -> void :
	if body.is_in_group("PlayerCharacter"):
		_player_nearby = body
		_set_label_visible(true)


func _on_exited(body: Node3D) -> void :
	if body.is_in_group("PlayerCharacter"):
		_player_nearby = null
		_set_label_visible(false)


func _unhandled_input(event: InputEvent) -> void :
	if _player_nearby == null:
		return
	if not (event is InputEventKey or \
	event is InputEventJoypadButton):
		return
	if event.is_action_pressed("interaction"):
		_pickup()


func _pickup() -> void :
	if _pickup_count >= max_pickups:
		return
	var player: = _player_nearby
	if player == null:
		return
	var wm: Node = null
	var wm_path: Variant = player.get("weapon_controller_path")
	if wm_path != null and wm_path != NodePath():
		wm = player.get_node_or_null(wm_path as NodePath)
	if wm == null:
		wm = player.get_node_or_null("WeaponManager")
	if wm == null:
		return
	var am: Node = wm.get("ammoManager") as Node
	if am == null:
		am = wm.get_node_or_null("AmmunitionManager")
	if am == null:
		return
	var added: int = 0
	if player.has_method("add_ammo_to_inventory"):
		added = int(player.add_ammo_to_inventory("grus_ammo", ammo_amount))
	else:
		var cur: int = int(am.ammoDict.get("grus_ammo", 0))
		var cap: int = int(am.maxNbPerAmmoDict.get("grus_ammo", cur + ammo_amount))
		added = mini(cap, cur + ammo_amount) - cur
		am.ammoDict["grus_ammo"] = cur + added
		if added > 0:
			_ItemNotification.notify_ammo_pickup(get_tree(), "grus_ammo", added)
	if added <= 0:
		return
	var sound_pos: Vector3 = global_position if is_inside_tree() else (player as Node3D).global_position
	_play_pickup_sound(sound_pos)
	_pickup_count += 1
	if wm.has_method("_refresh_reserve_dependent_weapon_meshes"):
		wm._refresh_reserve_dependent_weapon_meshes()
	if _pickup_count >= max_pickups:
		_player_nearby = null
		queue_free()


func _play_pickup_sound(pos: Vector3) -> void :
	var tree: = get_tree()
	if tree == null:
		return
	var audio: = AudioStreamPlayer3D.new()
	audio.stream = PICKUP_SFX
	audio.bus = "Sfx"
	tree.root.add_child(audio)
	audio.global_position = pos
	audio.play()
	audio.finished.connect(audio.queue_free)
