@tool
extends Container







signal child_moved(last_index: int, new_index: int)


var _separation: int = 0
var _drag_offset = null
var _dragged_child = null
var _old_index: int
var _new_index: int
var _map: = []


func _ready() -> void :
	_separation = get_theme_constant("separation", "VBoxContainer") + 2


func _notification(what):
	if what == NOTIFICATION_SORT_CHILDREN or what == NOTIFICATION_RESIZED:
		_update_layout()


func _can_drop_data(at_position, data) -> bool:
	if data.get_parent() != self:
		return false


	if not _dragged_child:
		_dragged_child = data
		_drag_offset = at_position - data.position
		_old_index = data.get_index()
		_new_index = _old_index


	data.position.y = at_position.y - _drag_offset.y


	var computed_index = 0
	for pos_y in _map:
		if pos_y > data.position.y - 16:
			break
		computed_index += 1


	computed_index = clamp(computed_index, 0, get_child_count() - 1)

	if computed_index != data.get_index():
		move_child(data, computed_index)
		_new_index = computed_index

	return true



func _drop_data(at_position, data) -> void :
	_drag_offset = null
	_dragged_child = null
	_update_layout()

	if _old_index != _new_index:
		child_moved.emit(_old_index, _new_index)




func _unhandled_input(event):
	if not _dragged_child:
		return

	if event is InputEventMouseButton and not event.pressed:
		_drop_data(_dragged_child.position, _dragged_child)


func _update_layout() -> void :
	_map.clear()
	var offset: = Vector2.ZERO

	for c in get_children():
		if c is Control:
			_map.push_back(offset.y)
			var child_min_size = c.get_combined_minimum_size()
			var possible_space = Rect2(offset, Vector2(size.x, child_min_size.y))

			if c != _dragged_child:
				fit_child_in_rect(c, possible_space)

			offset.y += c.size.y + _separation

	custom_minimum_size.y = offset.y - _separation
