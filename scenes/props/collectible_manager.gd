extends Node3D










@export var collectible_type: String = "pages"

@export var achievement_id: String = ""

@export var collect_label: String = "Lore-notat"


func _ready() -> void :
	add_to_group("CollectibleManager")



func get_collectible_id(child: Node) -> String:
	return collectible_type + "/" + str(child.name)


func _collectibles() -> Array:
	var out: Array = []
	for child in get_children():
		if child.is_in_group("Collectible"):
			out.append(child)
	return out


func total_count() -> int:
	return _collectibles().size()


func collected_count() -> int:
	var n: = 0
	for child in _collectibles():
		if GameManager.is_collectible_collected(get_collectible_id(child)):
			n += 1
	return n



func on_collected() -> void :
	var got: = collected_count()
	var total: = total_count()
	if QuestNotifier != null and QuestNotifier.has_method("show_hint"):
		QuestNotifier.show_hint("%s %d/%d" % [collect_label, got, total])
	if achievement_id != "" and total > 0 and got >= total:
		if AchievementManager != null:
			AchievementManager.unlock(achievement_id)
