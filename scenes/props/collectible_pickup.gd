extends Area3D










enum Kind{ARTIFACT, FANART, LORE_NOTE}

@export var kind: Kind = Kind.ARTIFACT

@export var title: String = ""
@export var prompt_text: String = "E — Plukk opp"

@export_group("Fan art")

@export var artwork: Texture2D

@export_group("Lore note")

@export_multiline var lore_text: String = ""

var _player_nearby: bool = false
var _id: String = ""
var _manager: Node = null

@onready var _prompt: Label3D = get_node_or_null("PromptLabel3D") as Label3D


func _ready() -> void :
	add_to_group("Collectible")
	_manager = get_parent()
	if _manager != null and _manager.has_method("get_collectible_id"):
		_id = _manager.get_collectible_id(self)
	else:
		push_warning("[Collectible] '%s' mangler CollectibleManager-forelder." % name)
	monitoring = true
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if _prompt != null:
		_prompt.text = prompt_text
		_prompt.visible = false
		_prompt.render_priority = 10
		_prompt.outline_render_priority = 9
	if kind == Kind.FANART:
		_apply_fanart()
	if _is_collected():
		_hide_collected()



func _apply_fanart() -> void :
	if artwork == null:
		return
	var mesh_node: = _find_mesh(self)
	if mesh_node == null:
		return
	var mat: = StandardMaterial3D.new()
	mat.albedo_texture = artwork
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_node.material_override = mat



	mesh_node.scale = Vector3.ONE
	var w: = float(artwork.get_width())
	var h: = float(artwork.get_height())
	if w > 0.0 and h > 0.0 and mesh_node.mesh is QuadMesh:
		var quad: = (mesh_node.mesh as QuadMesh).duplicate() as QuadMesh
		const MAX_H: = 0.7
		quad.size = Vector2((w / h) * MAX_H, MAX_H)
		mesh_node.mesh = quad


func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found: = _find_mesh(child)
		if found != null:
			return found
	return null


func _is_collected() -> bool:
	return _id != "" and GameManager.is_collectible_collected(_id)


func _hide_collected() -> void :
	visible = false
	monitoring = false
	_player_nearby = false
	if _prompt != null:
		_prompt.visible = false


func _on_body_entered(body: Node3D) -> void :
	if body.is_in_group("PlayerCharacter"):
		_player_nearby = true
		if _prompt != null and not _is_collected():
			_prompt.visible = true


func _on_body_exited(body: Node3D) -> void :
	if body.is_in_group("PlayerCharacter"):
		_player_nearby = false
		if _prompt != null:
			_prompt.visible = false


func _unhandled_input(event: InputEvent) -> void :
	if not _player_nearby or _is_collected():
		return
	if not event.is_action_pressed("interaction"):
		return
	if DialogueUI != null and DialogueUI.has_method("is_open") and DialogueUI.is_open():
		return
	get_viewport().set_input_as_handled()
	_collect()


func _collect() -> void :
	if _id == "":
		return

	GameManager.collect_collectible(_id, int(kind), artwork, lore_text, title)
	if SfxManager != null:
		SfxManager.play("item_added")
	_hide_collected()
	if _manager != null and _manager.has_method("on_collected"):
		_manager.on_collected()
