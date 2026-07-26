
extends PanelContainer

@export var quest: Quest = null

@onready var title_label: Label = $MarginContainer / VBoxContainer / TitleLabel
@onready var description_label: Label = $MarginContainer / VBoxContainer / BriefDescriptionLabel

var quest_id: String = ""


func setup(q: Quest):
	quest = q
	quest_id = q.quest_id

	await ready

	_refresh()

	if GameManager:
		GameManager.quest_progress_updated.connect(_on_quest_progress_updated)


func _refresh():
	if not quest:
		return

	if not title_label or not description_label:
		return

	title_label.text = quest.name
	description_label.text = _get_current_objective_text(quest)

	match quest.state:
		Quest.QuestState.COMPLETED:
			modulate = Color(0.5, 0.5, 0.5, 1)
		Quest.QuestState.ACTIVE:
			modulate = Color.WHITE


func _get_current_objective_text(q: Quest) -> String:
	if q == null:
		return ""
	q.normalize_runtime_state()
	for objective in q.objectives:
		if objective == null:
			continue
		var progress: int = int(q.objective_progress.get(objective.objective_id, 0))
		if progress < objective.target_amount:
			var desc: String = objective.description if objective.description != "" else q.description
			if objective.target_amount > 1:
				return desc + " (" + str(progress) + "/" + str(objective.target_amount) + ")"
			return desc
	var fallback: String = q.description.strip_edges()
	if fallback != "":
		return fallback
	return q.brief_description


func _on_quest_progress_updated(p_quest_id: String, _progress: int):
	if quest and quest.quest_id == p_quest_id:
		_refresh()
