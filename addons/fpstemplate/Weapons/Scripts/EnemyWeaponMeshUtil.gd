extends RefCounted
class_name EnemyWeaponMeshUtil

const WEAPON_MANAGER_SCENE: PackedScene = preload(
	"res://addons/fpstemplate/Weapons/Scenes/WeaponManagerScene.tscn")
const PLAYER_SCENE: PackedScene = preload(
	"res://scenes/PlayerCharacter/Scenes/PlayerCharacterScene.tscn")

const PLAYER_WEAPON_ROOT: = \
"CameraHolder/CameraRecoilHolder/Camera/WeaponManager/WeaponContainer"

const WEAPON_PATHS: Dictionary = {
	"Pistol": [
		"%s/Pistol" % PLAYER_WEAPON_ROOT, 
		"WeaponContainer/Pistol", 
	], 
	"AssaultRifle": [
		"%s/AssaultRifle" % PLAYER_WEAPON_ROOT, 
		"WeaponContainer/AssaultRifle", 
	], 
	"Shotgun": [
		"%s/Shotgun" % PLAYER_WEAPON_ROOT, 
		"WeaponContainer/Shotgun", 
	], 
	"SniperRifle": [
		"%s/SniperRifle" % PLAYER_WEAPON_ROOT, 
		"WeaponContainer/SniperRifle", 
	], 
	"RocketLauncher": [
		"%s/RocketLauncher" % PLAYER_WEAPON_ROOT, 
		"WeaponContainer/RocketLauncher", 
	], 
	"GrusSkive": [
		"%s/GrusSkive" % PLAYER_WEAPON_ROOT, 
		"WeaponContainer/GrusSkive", 
	], 
}


static func instantiate_weapon_scene(scene: PackedScene) -> Node3D:
	if scene == null:
		push_warning("EnemyWeaponMeshUtil: weapon scene is null")
		return null
	var state: SceneState = scene.get_state()
	if state == null or state.get_node_count() == 0:
		push_warning("EnemyWeaponMeshUtil: weapon scene is empty")
		return null
	var inst: Node3D = scene.instantiate() as Node3D
	if inst == null:
		return null
	return inst


static func duplicate_weapon_view(weapon_name: String) -> Node3D:
	if not WEAPON_PATHS.has(weapon_name):
		return null
	var paths: Array = WEAPON_PATHS[weapon_name]
	var scenes: Array[PackedScene] = [PLAYER_SCENE, WEAPON_MANAGER_SCENE]
	for scene: PackedScene in scenes:
		if scene == null:
			push_warning("EnemyWeaponMeshUtil: weapon manager scene preload is null")
			continue
		var state: SceneState = scene.get_state()
		if state == null or state.get_node_count() == 0:
			push_warning("EnemyWeaponMeshUtil: weapon scene is empty")
			continue
		var root: Node = scene.instantiate()
		if root == null:
			continue
		var source: Node3D = null
		for path in paths:
			source = root.get_node_or_null(path) as Node3D
			if source != null:
				break
		if source != null:
			var dup: Node3D = source.duplicate() as Node3D
			_strip_scripts(dup)
			root.queue_free()
			return dup
		root.queue_free()
	return null


static func find_attack_point(weapon_root: Node3D) -> Node3D:
	if weapon_root == null:
		return null
	var queue: Array[Node] = [weapon_root]
	while not queue.is_empty():
		var node: Node = queue.pop_front()
		if node is Marker3D and "AttackPoint" in node.name:
			return node as Node3D
		for child in node.get_children():
			queue.append(child)
	return weapon_root


static func strip_scripts(node: Node) -> void :
	_strip_scripts(node)


static func _strip_scripts(node: Node) -> void :
	if node.get_script() != null:
		node.set_script(null)
	for child in node.get_children():
		_strip_scripts(child)
