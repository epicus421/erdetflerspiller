@tool
class_name ProtonScatterBaseShape
extends Resource


func is_point_inside_global(_point_global: Vector3, _global_transform: Transform3D) -> bool:
	return false


func is_point_inside_local(_point_local: Vector3) -> bool:
	return false




func get_corners_global(_shape_global_transform: Transform3D) -> Array[Vector3]:
	return []




func get_closed_edges(_shape_t: Transform3D) -> Array[PackedVector2Array]:
	return []




func get_open_edges(_shape_t: Transform3D) -> Array[Curve3D]:
	return []





func get_copy() -> Resource:
	return null
