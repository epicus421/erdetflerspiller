extends Area3D

const BOXES_NEEDED: int = 5


func _ready() -> void :
	add_to_group("GorgonDeliveryZone")
	monitoring = true
	set_collision_mask_value(1, true)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void :
	if not body.is_in_group("ClothingBox"):
		return
	if body.has_method("is_delivered") and body.is_delivered():
		return
	if not GameManager.has_active_quest("GORGON_ROBBERY"):
		return
	var quest: Quest = GameManager.active_quests.get("GORGON_ROBBERY") as Quest
	if quest == null:
		return
	var boxes_delivered: int = int(quest.objective_progress.get("deliver_boxes", 0))
	if boxes_delivered >= BOXES_NEEDED:
		return
	if body.has_method("mark_delivered"):
		body.mark_delivered()
	GameManager.update_quest_objective("GORGON_ROBBERY", "deliver_boxes", 1)
	boxes_delivered += 1

	var gorgon: Node = get_tree().get_first_node_in_group("Gorgon")
	if gorgon != null and gorgon.has_method("on_box_delivered"):
		gorgon.on_box_delivered()

	var mgr: Node = get_tree().get_first_node_in_group("GorgonTestManager")
	if mgr != null:
		if mgr.has_method("update_boxes_hud"):
			mgr.update_boxes_hud(boxes_delivered, BOXES_NEEDED)
		if boxes_delivered >= BOXES_NEEDED:
			if mgr.has_method("_on_boxes_complete"):
				mgr._on_boxes_complete()
			return

	if boxes_delivered >= BOXES_NEEDED:
		if gorgon != null and gorgon.has_method("stop_throwing"):
			gorgon.stop_throwing()
