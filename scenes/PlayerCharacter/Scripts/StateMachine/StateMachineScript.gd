extends Node

@export var initialState: State

var currState: State
var currStateName: String
var states: Dictionary = {}

@onready var charRef: CharacterBody3D = $".."

func _ready():

	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.transitioned.connect(onStateChildTransition)


	if initialState:
		initialState.enter(charRef)
		currState = initialState
		currStateName = currState.stateName

func _process(delta: float):
	if not _is_locally_controlled():
		return
	if _skip_states_for_sitting():
		return
	if currState:
		currState.update(delta)


func _physics_process(delta: float):
	if not _is_locally_controlled():
		return
	if _skip_states_for_sitting():
		return
	if currState:
		currState.physics_update(delta)


func _skip_states_for_sitting() -> bool:
	return charRef is PlayerCharacter and (charRef as PlayerCharacter).is_sitting


## A remote player's states must never poll Input on our behalf — their
## currStateName arrives via MultiplayerSynchronizer instead (see
## multiplayer/player_net.gd).
func _is_locally_controlled() -> bool:
	if charRef == null or not charRef.has_method("is_local_player"):
		return true
	return charRef.is_local_player()


func transition_to(new_state_name: String) -> void :
	if currState == null:
		return
	onStateChildTransition(currState, new_state_name)

func onStateChildTransition(state: State, newStateName: String):


	if state != currState: return

	var newState = states.get(newStateName.to_lower())
	if !newState: return


	if currState: currState.exit()


	newState.enter(charRef)

	currState = newState
	currStateName = currState.stateName
