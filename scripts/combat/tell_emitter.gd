class_name TellEmitter
extends Node2D
## Minimal scriptable dummy tell source for checkpoint 2's combat core.
##
## A tell window opens at onset and stays open until its lead time elapses
## (§5 shared rule 1: the Answer window *is* the telegraph, no separate
## sub-window). Checkpoint 3 replaces this with real Reed Husk / Keening Husk
## tells driven by actual attack patterns; this node only exists so Answer has
## something to resolve against and the debug overlay has something to plot.
## Don't over-invest in this API — it's throwaway-shaped by design.

## Emitted the instant a window opens, with the lead time (ms) it will stay open for.
signal tell_opened(onset_ms: float, close_ms: float)
## Emitted when PlayerCombat resolves this window with a successful Answer.
signal tell_resolved()
## Emitted when the window closes without being resolved — the attack "lands".
signal tell_missed()

var lead_time_ms: float = 0.0
var stagger_ms: float = 0.0

var _open: bool = false
var _onset_ms: float = 0.0


func _ready() -> void:
	# Mirrors the debug overlay's own deferred group lookup: the player and
	# this emitter may enter the tree in either order, so wait a frame.
	call_deferred("_register_with_player")


func _register_with_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player: Node = players[0]
	if "combat" in player and player.combat != null:
		player.combat.register_tell_emitter(self)


## Opens a new tell window with the given lead time. Re-opening while a
## window is already open replaces it (a dummy fixture doesn't need to model
## overlapping tells from a single emitter — that's a multi-emitter concern,
## per §3.3's arbitration rule).
func open_tell(p_lead_time_ms: float) -> void:
	lead_time_ms = p_lead_time_ms
	_onset_ms = Time.get_ticks_msec()
	_open = true
	tell_opened.emit(_onset_ms, close_ms())


func is_open() -> bool:
	return _open


func onset_ms() -> float:
	return _onset_ms


func close_ms() -> float:
	return _onset_ms + lead_time_ms


## Called by PlayerCombat on a successful Answer. Stubs the §3.3 "enemy
## staggers 900 ms" consequence as a timer on the emitter itself — real
## enemy stagger behavior is checkpoint 3.
func resolve(stagger_duration_ms: float) -> void:
	if not _open:
		return
	_open = false
	stagger_ms = stagger_duration_ms
	tell_resolved.emit()


func _physics_process(delta: float) -> void:
	# Fixed-tick, matching every other timing-critical system in the combat
	# core (§2: "all timings ... measured at 60 Hz fixed tick").
	if _open and Time.get_ticks_msec() >= close_ms():
		_open = false
		tell_missed.emit()
	if stagger_ms > 0.0:
		stagger_ms = maxf(0.0, stagger_ms - delta * 1000.0)
