extends StaticBody3D


@export var weapon_int_id: int = 6
@export var display_name: String = "Våpen"
@export var pickup_label_text: String = ""

var _player_nearby: Node = null
var _picked_up: bool = false
var _pickup_label: Label3D = null


func _ready() -> void :
	var area: = get_node_or_null("InteractionArea") as Area3D
	if area:
		area.body_entered.connect(_on_entered)
		area.body_exited.connect(_on_exited)
	_setup_pickup_label()


func _setup_pickup_label() -> void :
	_pickup_label = Label3D.new()
	_pickup_label.name = "PickupLabel"
	_pickup_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_pickup_label.pixel_size = 0.005
	_pickup_label.font_size = 28
	_pickup_label.outline_size = 12
	_pickup_label.outline_modulate = Color(0, 0, 0, 1)
	_pickup_label.position = Vector3(0, 0.25, 0)
	_pickup_label.modulate = Color(1, 1, 1)
	_pickup_label.text = _get_pickup_label()
	_pickup_label.no_depth_test = true
	_pickup_label.visible = false
	add_child(_pickup_label)


func _get_pickup_label() -> String:
	if pickup_label_text != "":
		return pickup_label_text
	match weapon_int_id:
		2:
			return "E — Plukk opp rifle"
		5:
			return "E — Plukk opp bazooka"
		6:
			return "E — Plukk opp brødskive"
		_:
			return "E — Plukk opp %s" % display_name.to_lower()


func _set_label_visible(visible: bool) -> void :
	if _pickup_label != null:
		_pickup_label.visible = visible


## Only the body this machine actually controls may trigger the pickup.
## Otherwise a teammate standing on the weapon armed OUR "E" key, and pressing
## it handed the gun to their WeaponManager instead of ours.
func _is_local_body(body: Node3D) -> bool:
	if not body.is_in_group("PlayerCharacter"):
		return false
	if body.has_method("is_local_player"):
		return body.is_local_player()
	return true


func _on_entered(body: Node3D) -> void :
	if _is_local_body(body):
		_player_nearby = body
		_set_label_visible(true)


func _on_exited(body: Node3D) -> void :
	if body == _player_nearby:
		_player_nearby = null
		_set_label_visible(false)


func _unhandled_input(event: InputEvent) -> void :
	if _picked_up or _player_nearby == null:
		return
	if event.is_action_pressed("interaction"):
		_pick_up()
		get_viewport().set_input_as_handled()


func _pick_up() -> void :
	_picked_up = true
	var player: = _player_nearby
	if player == null:
		return
	var wm_path: NodePath = player.get("weapon_controller_path") as NodePath
	var wm: Node = null
	if wm_path != NodePath():
		wm = player.get_node_or_null(wm_path)
	if wm == null:
		wm = player.get_node_or_null("WeaponManager")
	if wm and wm.has_method("take_weapon_by_id"):
		# take_weapon_by_id equips it here and unlocks it for the whole party.
		wm.take_weapon_by_id(int(weapon_int_id))
	elif wm and wm.has_method("acquire_weapon_by_id"):
		if int(weapon_int_id) in wm.weaponStack:
			pass
		else:
			wm.acquire_weapon_by_id(int(weapon_int_id))
	elif wm and "weaponStack" in wm:
		var wid: = int(weapon_int_id)
		if not wid in wm.weaponStack:
			wm.weaponStack.append(wid)
	queue_free()
