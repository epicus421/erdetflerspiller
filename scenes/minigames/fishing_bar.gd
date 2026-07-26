extends Control

const GREEN_START: float = 0.4
const GREEN_END: float = 0.6

var _marker_pos: float = 0.0


func update_marker(pos: float) -> void :
	_marker_pos = clampf(pos, 0.0, 1.0)
	queue_redraw()


func _draw() -> void :
	var w: float = size.x
	var h: float = size.y
	draw_rect(Rect2(0.0, 0.0, w, h), Color(0.55, 0.12, 0.12, 0.85))
	var gx0: float = w * GREEN_START
	var gx1: float = w * GREEN_END
	draw_rect(Rect2(gx0, 0.0, gx1 - gx0, h), Color(0.15, 0.7, 0.25, 0.9))
	var marker_w: float = 8.0
	var mx: float = _marker_pos * maxf(w - marker_w, 1.0)
	draw_rect(Rect2(mx, 2.0, marker_w, h - 4.0), Color(1.0, 1.0, 1.0, 1.0))
