@tool
extends Control






var _scatter_completed: = false


func _ready() -> void :

	visible = not _scatter_completed






func _on_scatter_build_completed() -> void :
	visible = false
	_scatter_completed = true
