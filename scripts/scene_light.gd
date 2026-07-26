extends OmniLight3D


func _ready() -> void :
	add_to_group("SceneLights")


func turn_off() -> void :
	visible = false
	_set_parent_street_lamp_emission(0.0)


func turn_on() -> void :
	visible = true
	_set_parent_street_lamp_emission(1.0)


func _set_parent_street_lamp_emission(value: float) -> void :
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	if parent_node.has_method("_set_emission"):
		parent_node.call("_set_emission", value)
		return
	var lamp: Node = parent_node.get_node_or_null("StreetLampMesh")
	if lamp is CSGShape3D:
		var mat: Material = (lamp as CSGShape3D).material
		if mat is StandardMaterial3D:
			(mat as StandardMaterial3D).emission_energy_multiplier = value


func flicker() -> void :
	var tween: Tween = create_tween()
	tween.tween_property(self, "visible", false, 0.05)
	tween.tween_property(self, "visible", true, 0.05)
	tween.tween_property(self, "visible", false, 0.1)
	tween.tween_property(self, "visible", true, 0.05)
	tween.tween_property(self, "visible", false, 0.15)
	tween.tween_property(self, "visible", true, 0.0)
