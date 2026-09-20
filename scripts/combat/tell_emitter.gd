class_name TellEmitter
extends Node2D
## Tell source shared by the checkpoint-2 dummy fixture and checkpoint 3's
## real Reed Husk / Keening Husk. A tell window opens at onset and stays
## open until its lead time elapses (§5 shared rule 1: the Answer window
## *is* the telegraph, no separate sub-window).
##
## This node only tracks the window itself — onset, close, the identifying
## transient marker, and resolution. It does not decide what "the attack
## landing" means (damage amount, lunge vs. projectile): whoever opens the
## tell (a real enemy, or the checkpoint-2 manual test director) listens for
## `tell_missed` and resolves its own attack, and for `tell_resolved` to
## enter its own stagger. That keeps this class from needing to know about
## enemy-specific attack shapes.

## §5 shared rule 2: the identifying transient — the part that tells you
## *which* attack this is — lands in the first 160 ms of the tell.
const IDENTIFYING_TRANSIENT_MS: float = 160.0

## Emitted the instant a window opens, with the lead time (ms) it will stay open for.
signal tell_opened(onset_ms: float, close_ms: float)
## Emitted once, at onset + IDENTIFYING_TRANSIENT_MS, while the window is still open.
signal tell_transient()
## Emitted when PlayerCombat resolves this window with a successful Answer.
signal tell_resolved()
## Emitted when the window closes without being resolved — the attack "lands".
signal tell_missed()

## Register/voice identifier ("percussive", "keening", ...), set by whoever
## opens the tell. Purely descriptive — used for the dry-channel routing
## hook and the debug overlay; the timing rules don't depend on it.
var register: String = ""

var lead_time_ms: float = 0.0
var stagger_ms: float = 0.0

var _open: bool = false
var _onset_ms: float = 0.0
var _transient_fired: bool = false


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
## window is already open replaces it (a single emitter modeling two
## overlapping tells of its own is not a case §5 describes — overlap is a
## multi-emitter concern, per rule 6's arbitration).
func open_tell(p_lead_time_ms: float, p_register: String = "") -> void:
	lead_time_ms = p_lead_time_ms
	register = p_register
	_onset_ms = Time.get_ticks_msec()
	_open = true
	_transient_fired = false
	_route_to_dry_channel()
	tell_opened.emit(_onset_ms, close_ms())


func is_open() -> bool:
	return _open


func onset_ms() -> float:
	return _onset_ms


func close_ms() -> float:
	return _onset_ms + lead_time_ms


## §5 shared rule 2: when the identifying transient lands within this tell.
func transient_ms() -> float:
	return _onset_ms + IDENTIFYING_TRANSIENT_MS


## Called by PlayerCombat on a successful Answer. The 900 ms enemy-stagger
## consequence (§3.3) is tracked here as a timer so any listener (the owning
## enemy) can read it without PlayerCombat needing to know what "stagger"
## means for a given enemy shape.
func resolve(stagger_duration_ms: float) -> void:
	if not _open:
		return
	_open = false
	stagger_ms = stagger_duration_ms
	tell_resolved.emit()


## Attachment point for the dedicated dry tell channel (§5 shared rule 4 —
## the tell must never share a channel with ambience/flavor vocalization).
## AudioDirector decides bus routing (TELL for real tells, VOICE for the R6
## bearer's notes) and scheduling — this call site fires at the exact moment
## the window opens, which is what "the game clock owns the window" needs.
func _route_to_dry_channel() -> void:
	AudioDirector.play_tell(self)


func _physics_process(delta: float) -> void:
	# Fixed-tick, matching every other timing-critical system in the combat
	# core (§2: "all timings ... measured at 60 Hz fixed tick").
	var now := Time.get_ticks_msec()
	if _open:
		if not _transient_fired and now >= transient_ms():
			_transient_fired = true
			tell_transient.emit()
		if now >= close_ms():
			_open = false
			tell_missed.emit()
	if stagger_ms > 0.0:
		stagger_ms = maxf(0.0, stagger_ms - delta * 1000.0)
