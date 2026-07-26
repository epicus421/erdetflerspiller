extends Node

## Autoload: GameNet
##
## Keeps every peer's GameManager (shared party money/inventory/quests/story
## flags) in sync using a generic "replay the same call everywhere" scheme,
## rather than one bespoke RPC per signal:
##
## 1. A client wants to mutate shared state (e.g. GameManager.add_item(...)).
##    GameManager itself detects "I'm a client, not the host" and calls
##    GameNet.request_on_host(method, args) instead of applying locally.
## 2. The host receives it, calls the SAME GameManager method for real
##    (host is authoritative, so this actually mutates state + fires
##    GameManager's normal signals for host-side UI/logic).
## 3. GameNet on the host then tells every OTHER peer to replay that exact
##    call on their own GameManager, marked so it applies directly instead
##    of redirecting again.
##
## This only works for methods whose arguments are plain serializable values
## (String/int/float/bool/Array/Dictionary) — see the ID-based wrapper
## methods on GameManager (add_quest_by_id, complete_quest_by_id, etc.)
## rather than their Resource-based counterparts.


## Non-zero for the duration of _request below: which peer's action the host
## is currently applying on their behalf. NetUtil.get_acting_player() reads
## this so host-side logic (e.g. "heal whoever used this item") resolves to
## the right player instead of an arbitrary/local one. Always 0 outside of
## that window, so it never affects purely local code paths (settings, etc).
var current_actor_peer_id: int = 0


func request_on_host(method: String, args: Array) -> void:
	if NetworkManager == null or not NetworkManager.is_active or NetworkManager.is_host:
		return
	_request.rpc_id(1, method, args)


@rpc("any_peer", "call_remote", "reliable")
func _request(method: String, args: Array) -> void:
	if not NetworkManager.is_host:
		return
	if not GameManager.has_method(method):
		push_warning("[GameNet] Unknown method requested by client: %s" % method)
		return
	current_actor_peer_id = multiplayer.get_remote_sender_id()
	GameManager.callv(method, args)
	current_actor_peer_id = 0
	_replay.rpc(method, args)


@rpc("authority", "call_remote", "reliable")
func _replay(method: String, args: Array) -> void:
	# call_remote (not call_local): the host already applied this directly
	# in _request above — replaying it here too would double-apply it.
	if not GameManager.has_method(method):
		push_warning("[GameNet] Unknown method in replay: %s" % method)
		return
	GameManager._remote_apply = true
	GameManager.callv(method, args)
	GameManager._remote_apply = false


## Full state snapshot for a client joining an already-running session, so
## they don't start with an empty inventory/quest journal.
func request_snapshot() -> void:
	if NetworkManager == null or NetworkManager.is_host:
		return
	_request_snapshot.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _request_snapshot() -> void:
	if not NetworkManager.is_host:
		return
	var sender: int = multiplayer.get_remote_sender_id()
	_apply_snapshot.rpc_id(sender, GameManager.serialize_state())


@rpc("authority", "call_remote", "reliable")
func _apply_snapshot(snapshot: Dictionary) -> void:
	GameManager.apply_snapshot(snapshot)
