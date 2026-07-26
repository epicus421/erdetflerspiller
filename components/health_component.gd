extends Node


class_name HealthComponent

signal on_death()
signal on_damage_taken(current_health: float, damage_taken: float)

@export var max_health: float = 100.0

## current_health/is_dead use property setters (not explicit .emit() calls
## in take_damage/etc.) specifically so the signals fire correctly no matter
## HOW the value changed — a direct authoritative mutation, or a value that
## just arrived via MultiplayerSynchronizer replication (see _setup_sync).
## That's what makes a remote player's pain flash / an enemy's death VFX
## show up correctly on every peer, not just the one that actually applied
## the damage.
var current_health: float = 0.0:
	set(value):
		var previous: float = current_health
		current_health = value
		if value < previous:
			on_damage_taken.emit(current_health, previous - current_health)

var is_dead: bool = false:
	set(value):
		var was_dead: bool = is_dead
		is_dead = value
		if value and not was_dead:
			on_death.emit()

func _ready():
	current_health = max_health
	if NetworkManager != null and NetworkManager.is_active:
		_setup_sync()


## True if THIS node is the one that should actually apply damage/healing:
## solo play, or whichever peer holds multiplayer authority over the entity
## this HealthComponent belongs to (the player's own peer for a
## PlayerCharacter, the host for everything baked into the level — enemies,
## NPCs, wildlife — since those default to authority 1 and nothing spawns
## them per-peer).
func is_authority() -> bool:
	return NetworkManager == null or not NetworkManager.is_active or is_multiplayer_authority()


## Forwards to whichever peer actually holds authority when we don't.
## Unlike GameManager's version of this pattern, there's no separate replay
## step here — once the authority applies the change, current_health/
## is_dead simply get replicated back out by the MultiplayerSynchronizer
## set up below, and the property setters above fire the signals on arrival.
func _redirect_if_remote(method: String, args: Array) -> bool:
	if is_authority():
		return false
	_request.rpc_id(get_multiplayer_authority(), method, args)
	return true


func take_damage(amount: float):
	if _redirect_if_remote("take_damage", [amount]):
		return
	if is_dead:
		return
	if _is_invulnerable():
		return

	current_health -= amount

	if current_health <= 0:
		is_dead = true

func heal(amount: float):
	if _redirect_if_remote("heal", [amount]):
		return
	if is_dead:
		return
	current_health = min(current_health + amount, max_health)


func _is_invulnerable() -> bool:
	var node: Node = get_parent()
	while node != null:
		if node.get("invulnerable") == true:
			return true
		node = node.get_parent()
	return false


func revive() -> void :
	if _redirect_if_remote("revive", []):
		return
	is_dead = false
	current_health = max_health


@rpc("any_peer", "call_remote", "reliable")
func _request(method: String, args: Array) -> void:
	if not is_authority():
		return
	if not has_method(method):
		return
	callv(method, args)


func _setup_sync() -> void:
	var config: SceneReplicationConfig = SceneReplicationConfig.new()
	for prop in [".:current_health", ".:is_dead"]:
		var path: NodePath = NodePath(prop)
		config.add_property(path)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	var sync: MultiplayerSynchronizer = MultiplayerSynchronizer.new()
	sync.name = "HealthSync"
	sync.replication_config = config
	add_child(sync)
