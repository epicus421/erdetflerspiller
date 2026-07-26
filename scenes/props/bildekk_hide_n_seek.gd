extends Node3D





const BILDEKK_SCENE: PackedScene = preload("res://scenes/props/bildekk.tscn")


func _ready() -> void :
	var markers: Array[Marker3D] = []
	for child in get_children():
		if child is Marker3D:
			markers.append(child)
	if markers.is_empty():
		push_warning("[BildekkHideNSeek] Ingen Marker3D-barn — bildekket kan ikke plasseres.")
		return
	var marker: Marker3D = markers[randi() % markers.size()]
	var tire: = BILDEKK_SCENE.instantiate() as Node3D
	add_child(tire)
	tire.global_transform = marker.global_transform
