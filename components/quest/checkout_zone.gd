extends Area3D

@onready var price_label: Label3D = $PriceLabel3D

var items_on_counter: Array[RigidBody3D] = []

const COLOR_AFFORDABLE: = Color(0.302, 0.902, 0.0, 1.0)
const COLOR_TOO_EXPENSIVE: = Color(1.0, 0.0, 0.0, 1.0)
const COLOR_DENIED_FLASH: = Color(0.35, 0.0, 0.0, 1.0)
const SCAN_SOUND: AudioStream = preload("res://assets/sfx/erdetlyd/splice/cashier_scansound.wav")

var _flash_tween: Tween = null
var _scan_audio: AudioStreamPlayer3D = null




const ICECREAM_HINT_DELAY: = 30.0
var _icecream_hint_armed: bool = false

func _ready():
	add_to_group("CheckoutZone")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if price_label:
		price_label.font_size = 36
		price_label.pixel_size = 0.003
		price_label.outline_size = 12
		price_label.outline_modulate = Color(0, 0, 0, 1)

		price_label.render_priority = 10
		price_label.outline_render_priority = 9
	if GameManager and not GameManager.money_changed.is_connected(_on_money_changed):
		GameManager.money_changed.connect(_on_money_changed)
	_scan_audio = AudioStreamPlayer3D.new()
	_scan_audio.name = "ScanAudio"
	_scan_audio.stream = SCAN_SOUND
	_scan_audio.bus = "Sfx"
	_scan_audio.max_distance = 25.0
	add_child(_scan_audio)
	_update_price_label()


func _exit_tree() -> void :
	if GameManager and GameManager.money_changed.is_connected(_on_money_changed):
		GameManager.money_changed.disconnect(_on_money_changed)


func _on_money_changed(_new_amount: int) -> void :
	_update_price_label()


func remove_item_if_present(body: RigidBody3D) -> void :
	if items_on_counter.has(body):
		items_on_counter.erase(body)
		_update_price_label()

func _on_body_entered(body: Node3D):
	if not (body is RigidBody3D):
		return
	if not body.is_in_group("ShopItem"):
		return
	var item: RigidBody3D = body as RigidBody3D
	if items_on_counter.has(item):
		return
	items_on_counter.append(item)
	if _scan_audio != null:
		_scan_audio.play()
	_maybe_arm_icecream_hint(item)
	_update_price_label()




func _maybe_arm_icecream_hint(item: RigidBody3D) -> void :
	if _icecream_hint_armed:
		return
	if not ("item_id" in item and str(item.item_id) == "icecream"):
		return
	if GameManager != null and int(GameManager.get("ice_creams_purchased")) > 0:
		return
	_icecream_hint_armed = true
	get_tree().create_timer(ICECREAM_HINT_DELAY).timeout.connect(_on_icecream_hint_timeout)


func _on_icecream_hint_timeout() -> void :

	if GameManager != null and int(GameManager.get("ice_creams_purchased")) > 0:
		return
	if QuestNotifier != null and QuestNotifier.has_method("show_hint_once"):
		QuestNotifier.show_hint_once(
			"one_icecream", 
			"Du har bare råd til én is. Kjøp den ene og gå tilbake til bestefar."
		)

func _on_body_exited(body: Node3D):
	if not (body is RigidBody3D):
		return
	if not body.is_in_group("ShopItem"):
		return
	items_on_counter.erase(body)
	_update_price_label()

func _update_price_label():
	items_on_counter = items_on_counter.filter( func(item): return is_instance_valid(item))
	var total: int = _calculate_total()
	if price_label == null:
		return
	if total <= 0:
		price_label.visible = false
		return
	price_label.visible = true
	price_label.text = "%d kr" % total
	var can_afford: bool = GameManager != null and GameManager.player_money >= total
	price_label.modulate = COLOR_AFFORDABLE if can_afford else COLOR_TOO_EXPENSIVE

func flash_denied() -> void :
	if price_label == null or not price_label.visible:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	for i in 3:
		_flash_tween.tween_property(price_label, "modulate", COLOR_DENIED_FLASH, 0.12)
		_flash_tween.tween_property(price_label, "modulate", COLOR_TOO_EXPENSIVE, 0.12)
	_flash_tween.tween_callback(_update_price_label)

func _calculate_total() -> int:
	var total: int = 0
	for item in items_on_counter:
		if not is_instance_valid(item):
			continue
		if "item_id" in item and str(item.item_id) == "icecream" and GameManager and GameManager.has_method("get_icecream_price"):
			total += int(GameManager.get_icecream_price())
			continue
		if item.has_method("get_price"):
			total += int(item.get_price())
		elif "price" in item:
			total += int(item.price)
	return total

func get_items() -> Array[RigidBody3D]:
	items_on_counter = items_on_counter.filter( func(item): return is_instance_valid(item))
	return items_on_counter
