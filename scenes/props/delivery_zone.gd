extends Area3D

const BOXES_NEEDED: int = 5

var boxes_delivered: int = 0


func _ready() -> void :
	monitoring = true
	monitorable = false
	set_collision_mask_value(1, true)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void :
	if not body.is_in_group("ClothingBox"):
		return
	if body.has_method("is_delivered") and body.is_delivered():
		return
	if boxes_delivered >= BOXES_NEEDED:
		return
	if body.has_method("mark_delivered"):
		body.mark_delivered()
	boxes_delivered += 1

	var gorgon: Node = get_tree().get_first_node_in_group("Gorgon")
	if gorgon != null and gorgon.has_method("on_box_delivered"):
		gorgon.on_box_delivered()

	var mgr: Node = get_tree().get_first_node_in_group("GorgonTestManager")
	if mgr != null and mgr.has_method("update_boxes_hud"):
		mgr.update_boxes_hud(boxes_delivered, BOXES_NEEDED)

	if boxes_delivered >= BOXES_NEEDED:
		if gorgon != null and gorgon.has_method("stop_throwing"):
			gorgon.stop_throwing()
		if mgr != null and mgr.has_method("_on_boxes_complete"):
			mgr._on_boxes_complete()
