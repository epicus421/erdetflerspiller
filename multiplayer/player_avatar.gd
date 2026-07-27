extends Node3D

## Visible body for a REMOTE player.
##
## The base game is first-person, so PlayerCharacterScene's only body is an
## untextured `CapsuleMesh` on render layer 2 (the "bønne" everyone saw in
## multiplayer) — it exists to cast a shadow for yourself, not to be looked
## at. This node replaces it with one of the PSX character models the game
## already uses for its NPCs, and drives it from state that is *already*
## replicated by multiplayer/player_net.gd:
##
##   * `CameraHolder:rotation:y` -> which way the body faces
##   * `.:velocity`              -> walk bob / lean
##   * `Model:scale`             -> crouch squash (mirrors the capsule exactly,
##                                  so the body sits where vanilla put the
##                                  capsule)
##
## Nothing here runs for the local player, and nothing here is authoritative:
## it is pure presentation, so a mismatch can never desync the simulation.
##
## Node layout built at runtime:
##   PlayerAvatar   (this node)  -> yaw, follows the look direction
##     ScaleHolder              -> crouch squash
##       BobHolder              -> walk bob + lean
##         <character model>

const Appearance := preload("res://multiplayer/player_appearance.gd")

## Matches scenes/npc/npc_base.gd _setup_model — the PSX models are authored
## at wildly different scales, so everything is normalised to a fixed height.
const TARGET_HEIGHT: float = 1.95
## The source meshes face +Z; the game's own NPC setup flips them.
const MODEL_YAW_OFFSET_DEG: float = 180.0

const BOB_FREQUENCY: float = 9.0
const BOB_HEIGHT: float = 0.055
const BOB_ROLL: float = 0.045
## Below this horizontal speed the body is treated as standing still.
const MOVING_SPEED_THRESHOLD: float = 0.4
## Speed at which the bob reaches full amplitude.
const FULL_BOB_SPEED: float = 9.0

## Where the held weapon sits relative to the body centre. The body origin is
## the capsule's centre (feet at y = -1.0), so y here is roughly chest height,
## x puts it out past the right arm and z pushes it in front of the chest
## (-Z is forward once _face_look_direction has aimed the avatar).
const WEAPON_OFFSET: Vector3 = Vector3(0.20, 0.02, -0.28)
## Longest dimension of the held weapon, in metres.
const WEAPON_LENGTH: float = 0.55
## Slight downward tilt so guns don't read as permanently aiming at the sky.
const WEAPON_PITCH_DEG: float = 8.0
const HOLSTER_WEAPON_ID: int = 0

## Where the gesture hand floats when the player is empty-handed — a little
## further out and up than a gun, so it is clearly readable.
const HAND_OFFSET: Vector3 = Vector3(0.26, 0.10, -0.34)

var _player: CharacterBody3D = null
var _cam_holder: Node3D = null
var _capsule: MeshInstance3D = null
var _scale_holder: Node3D = null
var _bob_holder: Node3D = null
var _weapon_mount: Node3D = null
var _hand_sprite: Sprite3D = null
var _hand_tween: Tween = null
var _character_id: int = -1
var _weapon_id: int = -1
var _hand_gesture: int = -1
var _bob_time: float = 0.0
var _using_fallback: bool = false


func _ready() -> void:
	_player = get_parent() as CharacterBody3D
	if _player == null:
		push_warning("[PlayerAvatar] Parent is not a CharacterBody3D — removing.")
		queue_free()
		return

	_cam_holder = _player.get_node_or_null("CameraHolder") as Node3D
	_capsule = _player.get_node_or_null("Model") as MeshInstance3D

	_scale_holder = Node3D.new()
	_scale_holder.name = "ScaleHolder"
	add_child(_scale_holder)

	_bob_holder = Node3D.new()
	_bob_holder.name = "BobHolder"
	_scale_holder.add_child(_bob_holder)

	# Sits outside ScaleHolder so a crouch squash doesn't deform the gun.
	_weapon_mount = Node3D.new()
	_weapon_mount.name = "WeaponMount"
	_weapon_mount.position = WEAPON_OFFSET
	add_child(_weapon_mount)

	# Empty-handed gestures. Billboarded so a middle finger reads from wherever
	# the other player happens to be standing — the whole point is being seen.
	_hand_sprite = Sprite3D.new()
	_hand_sprite.name = "HandGesture"
	_hand_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hand_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_hand_sprite.pixel_size = 0.0016
	_hand_sprite.position = HAND_OFFSET
	_hand_sprite.layers = 1
	_hand_sprite.visible = false
	add_child(_hand_sprite)

	_refresh_character()
	_refresh_weapon()
	_refresh_hand_gesture()
	if NetworkManager != null and NetworkManager.has_signal("roster_updated"):
		NetworkManager.roster_updated.connect(_on_roster_updated)


func _exit_tree() -> void:
	if NetworkManager != null and NetworkManager.has_signal("roster_updated")\
	and NetworkManager.roster_updated.is_connected(_on_roster_updated):
		NetworkManager.roster_updated.disconnect(_on_roster_updated)


func _on_roster_updated(_peers: Dictionary) -> void:
	# The roster can arrive after the body has already spawned (peer_connected
	# fires before the joining peer has told us who they are), so re-read it
	# instead of leaving everyone stuck on character 0.
	_refresh_character()


func _wanted_character_id() -> int:
	if _player == null or not is_instance_valid(_player) or NetworkManager == null:
		return 0
	var info: Variant = NetworkManager.peers.get(_player.get_multiplayer_authority(), null)
	if info is Dictionary:
		return Appearance.normalize_id(int((info as Dictionary).get("character", 0)))
	return 0


func _refresh_character() -> void:
	# roster_updated also fires while a session is being torn down, which can
	# land after this node has started being freed.
	if _bob_holder == null or not is_instance_valid(_bob_holder):
		return
	var wanted: int = _wanted_character_id()
	if wanted == _character_id and not _using_fallback:
		return
	_character_id = wanted

	for child in _bob_holder.get_children():
		child.queue_free()

	var scene: PackedScene = Appearance.get_scene(_character_id)
	var instance: Node3D = null
	if scene != null:
		instance = scene.instantiate() as Node3D
	if instance == null:
		# No model in this build — fall back to the vanilla capsule so the
		# player is at least visible rather than invisible.
		_using_fallback = true
		if _capsule != null:
			_capsule.visible = true
			_capsule.layers = 1
		return

	_using_fallback = false
	if _capsule != null:
		_capsule.visible = false
	_bob_holder.add_child(instance)
	_normalize_model(instance)
	_strip_collisions(instance)


## Scales the model to TARGET_HEIGHT and centres it on this node's origin,
## the same way scenes/npc/npc_base.gd does it for NPCs — which lines it up
## with where the capsule used to be (centred on the CharacterBody3D origin).
func _normalize_model(instance: Node3D) -> void:
	var mesh: MeshInstance3D = _find_mesh(instance)
	if mesh == null:
		return
	var aabb: AABB = mesh.get_aabb()
	if aabb.size.y <= 0.0:
		return
	var factor: float = TARGET_HEIGHT / aabb.size.y
	instance.scale = Vector3(factor, factor, factor)
	instance.rotation_degrees.y = MODEL_YAW_OFFSET_DEG
	instance.position = Vector3(
		-(aabb.position.x + aabb.size.x * 0.5) * factor,
		-(aabb.position.y + aabb.size.y * 0.5) * factor,
		-(aabb.position.z + aabb.size.z * 0.5) * factor
	)


func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found: MeshInstance3D = _find_mesh(child)
		if found != null:
			return found
	return null


## Some imported .glb files ship collision shapes; a second collider riding
## inside the player's own capsule would shove players through geometry, so
## neutralise anything physical.
func _strip_collisions(node: Node) -> void:
	if node is CollisionObject3D:
		var body: CollisionObject3D = node as CollisionObject3D
		body.collision_layer = 0
		body.collision_mask = 0
	for child in node.get_children():
		_strip_collisions(child)


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_face_look_direction()
	_apply_crouch()
	_apply_walk_bob(delta)
	_refresh_weapon()
	_refresh_hand_gesture()


## Mirrors the hand PNG the player's own viewmodel is showing. Only visible
## when they're empty-handed — with a gun out, the gun is the thing to show.
func _refresh_hand_gesture() -> void:
	if _hand_sprite == null or not is_instance_valid(_hand_sprite):
		return

	var holding_weapon: bool = int(_player.net_weapon_id) > HOLSTER_WEAPON_ID
	if holding_weapon:
		if _hand_sprite.visible:
			_hand_sprite.visible = false
		return

	var wanted: int = int(_player.net_hand_gesture)
	if wanted == _hand_gesture and _hand_sprite.visible:
		return

	var changed: bool = wanted != _hand_gesture
	_hand_gesture = wanted
	var tex: Texture2D = Appearance.get_hand_texture(wanted)
	if tex == null:
		_hand_sprite.visible = false
		return
	_hand_sprite.texture = tex
	_hand_sprite.visible = true
	if changed:
		_pop_hand()


## Same little shake the first-person hand does when you switch gesture, so it
## reads as a deliberate action rather than the texture silently swapping.
func _pop_hand() -> void:
	if _hand_tween != null and _hand_tween.is_valid():
		_hand_tween.kill()
	_hand_tween = create_tween()
	_hand_sprite.rotation_degrees.z = 0.0
	_hand_tween.tween_property(_hand_sprite, "rotation_degrees:z", -12.0, 0.05)
	_hand_tween.tween_property(_hand_sprite, "rotation_degrees:z", 9.0, 0.06)
	_hand_tween.tween_property(_hand_sprite, "rotation_degrees:z", 0.0, 0.05)


## Mirrors whatever this player currently has equipped onto the third-person
## body. The first-person viewmodel can't be reused directly: it lives under
## the camera on render layer 3, which only that player's weapon SubViewport
## camera draws — invisible to everyone else. So we clone the model, force it
## onto the normal render layer, and hang it off the body.
func _refresh_weapon() -> void:
	if _weapon_mount == null or not is_instance_valid(_weapon_mount):
		return
	var wanted: int = int(_player.net_weapon_id)
	if wanted == _weapon_id:
		return
	_weapon_id = wanted

	for child in _weapon_mount.get_children():
		child.queue_free()

	# Empty hands / fists: nothing to show.
	if wanted <= HOLSTER_WEAPON_ID:
		return

	var slot: Node3D = _find_weapon_slot(wanted)
	var source: Node3D = _model_of_slot(slot)
	if source == null:
		return

	# Work the barrel direction out from the ORIGINAL nodes, in the source
	# model's local frame — which is identical to the clone's, since the clone
	# starts at identity with the same children. Most weapons keep their
	# AttackPoint inside the model; the GrusSkive hangs it off the slot
	# instead, so fall back to searching there.
	var muzzle: Node3D = _find_attack_point(source)
	if muzzle == null and slot != null:
		muzzle = _find_attack_point(slot)
	var muzzle_local: Vector3 = Vector3.ZERO
	var have_muzzle: bool = false
	if muzzle != null and source.is_inside_tree() and muzzle.is_inside_tree():
		muzzle_local = source.to_local(muzzle.global_position)
		have_muzzle = true

	var copy: Node3D = source.duplicate(DUPLICATE_USE_INSTANTIATION) as Node3D
	if copy == null:
		return
	_weapon_mount.add_child(copy)
	# The viewmodel's transform is tuned for a camera-relative position; ours is
	# relative to the body, so start clean.
	copy.transform = Transform3D.IDENTITY
	_make_world_visible(copy)
	_place_weapon(copy, muzzle_local, have_muzzle)


## Aims and sizes a cloned weapon so it reads as being held.
##
## The clone arrives with an identity transform, which left every gun floating
## sideways through the torso: a viewmodel's local axes are whatever the artist
## happened to author, and there is no rig on these PSX bodies to parent to.
##
## Each weapon model carries an `<Name>AttackPoint` Marker3D at the muzzle, so
## the vector from the model's centre to that marker IS the barrel direction.
## Rotating that vector onto the avatar's forward (-Z) aims any weapon
## correctly without hand-tuning a table of per-weapon rotations.
func _place_weapon(root: Node3D, muzzle_local: Vector3, have_muzzle: bool) -> void:
	var bounds: AABB = _local_bounds(root, root)
	if bounds.size == Vector3.ZERO:
		return

	var longest: float = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	var factor: float = WEAPON_LENGTH / longest if longest > 0.0 else 1.0

	var forward: Vector3 = Vector3.ZERO
	if have_muzzle:
		forward = muzzle_local - bounds.get_center()
	if forward.length_squared() < 0.000001:
		# No marker (or it sits dead centre): fall back to the model's longest
		# axis, which for a gun is always the barrel.
		if bounds.size.x >= bounds.size.y and bounds.size.x >= bounds.size.z:
			forward = Vector3.RIGHT
		elif bounds.size.z >= bounds.size.y:
			forward = Vector3.BACK
		else:
			forward = Vector3.UP
	forward = forward.normalized()

	# Rotate the barrel onto -Z. Basis.looking_at(f) maps -Z ONTO f, which is
	# the opposite of what we want, so transpose it (it is orthonormal, so the
	# transpose is the inverse). Doing it this way also keeps the model's own
	# up axis pointing up, so the gun isn't rolled onto its side.
	var up: Vector3 = Vector3.UP
	if absf(forward.dot(up)) > 0.99:
		up = Vector3.BACK
	var basis: Basis = Basis.looking_at(forward, up).transposed()

	root.transform = Transform3D(basis.scaled(Vector3(factor, factor, factor)), Vector3.ZERO)
	# Re-centre AFTER rotating: the pivot is wherever the artist left it, which
	# is rarely the middle of the gun.
	root.position = -(root.basis * bounds.get_center())
	_weapon_mount.rotation_degrees.x = WEAPON_PITCH_DEG


## Combined bounds of every mesh under `root`, expressed in `space`'s frame.
func _local_bounds(node: Node, space: Node3D) -> AABB:
	var out: AABB = AABB()
	var started: bool = false
	for mesh in _all_meshes(node):
		var local: Transform3D = space.global_transform.affine_inverse() * mesh.global_transform
		var box: AABB = local * mesh.get_aabb()
		if not started:
			out = box
			started = true
		else:
			out = out.merge(box)
	return out


func _all_meshes(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		found.append(node as MeshInstance3D)
	for child in node.get_children():
		found.append_array(_all_meshes(child))
	return found


func _find_attack_point(node: Node) -> Node3D:
	if node is Marker3D and str(node.name).to_lower().ends_with("attackpoint"):
		return node as Node3D
	for child in node.get_children():
		var found: Node3D = _find_attack_point(child)
		if found != null:
			return found
	return null


## The weapon slots live under the remote player's own (disabled) first-person
## rig, which is the one place a model for every weapon id is guaranteed to
## exist on this machine.
func _find_weapon_slot(weapon_id: int) -> Node3D:
	var manager: Node = _player.get_node_or_null(
		"CameraHolder/CameraRecoilHolder/Camera/WeaponManager")
	if manager == null:
		return null
	var container: Node = manager.get_node_or_null("WeaponContainer")
	if container == null:
		return null
	for slot in container.get_children():
		if slot is Node3D and int(slot.get("weaponId")) == weapon_id:
			return slot as Node3D
	return null


func _model_of_slot(slot: Node3D) -> Node3D:
	if slot == null:
		return null
	var model: Variant = slot.get("model")
	if model is Node3D:
		return model as Node3D
	# Fall back to the "<Name>Model" child the scene uses by convention.
	for child in slot.get_children():
		if child is Node3D and str(child.name).ends_with("Model"):
			return child as Node3D
	return null


## Layer 3 is the viewmodel-only layer; the main camera's cull_mask is 1.
func _make_world_visible(node: Node) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = 1
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).visible = true
	if node is Node3D:
		(node as Node3D).visible = true
	for child in node.get_children():
		_make_world_visible(child)




## The player body itself never yaws (the base game rotates CameraHolder and
## leaves the CharacterBody3D alone), so without this every remote player
## would stand facing world-north no matter where they were actually looking.
func _face_look_direction() -> void:
	if _cam_holder == null or not is_instance_valid(_cam_holder):
		return
	var forward: Vector3 = -_cam_holder.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return
	# look_at() points -Z at the target, which is the direction the model
	# faces once _normalize_model has applied MODEL_YAW_OFFSET_DEG.
	look_at(global_position + forward.normalized(), Vector3.UP)


## Mirrors the capsule's crouch squash rather than inventing its own, so the
## body never floats or sinks relative to what vanilla already did.
func _apply_crouch() -> void:
	if _capsule == null or not is_instance_valid(_capsule):
		return
	_scale_holder.scale.y = maxf(_capsule.scale.y, 0.05)


func _apply_walk_bob(delta: float) -> void:
	var horizontal: Vector3 = _player.velocity
	horizontal.y = 0.0
	var speed: float = horizontal.length()

	if speed < MOVING_SPEED_THRESHOLD:
		_bob_time = 0.0
		_bob_holder.position.y = lerpf(_bob_holder.position.y, 0.0, delta * 10.0)
		_bob_holder.rotation.z = lerpf(_bob_holder.rotation.z, 0.0, delta * 10.0)
		return

	var intensity: float = clampf(speed / FULL_BOB_SPEED, 0.0, 1.0)
	_bob_time += delta * BOB_FREQUENCY * (0.5 + intensity)
	_bob_holder.position.y = absf(sin(_bob_time)) * BOB_HEIGHT * intensity
	_bob_holder.rotation.z = sin(_bob_time * 0.5) * BOB_ROLL * intensity
