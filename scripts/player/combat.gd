class_name PlayerCombat
extends Node
## Strike and Answer — the pre-Verse combat kit, per
## docs/design/vertical-slice.md §3.2 (Strike) and §3.3 (Answer). Values below
## are design contracts; changing one needs a Design sign-off.
##
## Owns the Strike and Answer state machines and the input buffers that feed
## them (see scripts/common/input_buffer.gd). Tell resolution talks to
## whatever TellEmitter nodes are registered via `register_tell_emitter` — for
## this checkpoint, the scripted dummy fixture in scripts/combat/tell_emitter.gd.

const InputBuffer = preload("res://scripts/common/input_buffer.gd")
const TellEmitter = preload("res://scripts/combat/tell_emitter.gd")

# --- §3.2 Strike design contract --------------------------------------------
const STRIKE_STARTUP_MS: float = 90.0
const STRIKE_ACTIVE_MS: float = 70.0
const STRIKE_RECOVERY_MS: float = 140.0
const STRIKE_REACH_PX: float = 22.0          # forward from collider edge
const STRIKE_HITBOX_HEIGHT_PX: float = 30.0
const STRIKE_DAMAGE: int = 1
const STRIKE_BUFFER_MS: float = 120.0

enum StrikeState { IDLE, STARTUP, ACTIVE, RECOVERY }

# --- §3.3 Answer design contract --------------------------------------------
const ANSWER_ACTIVE_POSE_MS: float = 180.0
const ANSWER_WHIFF_RECOVERY_MS: float = 220.0
const ANSWER_SUCCESS_RECOVERY_MS: float = 0.0
const ANSWER_PRE_WINDOW_BUFFER_MS: float = 120.0
const ANSWER_ENEMY_STAGGER_MS: float = 900.0
const RESOLVED_NOTE_HOLD_MS: float = 1200.0

const ANSWER_FAIL_DAMAGE: int = 1
const ANSWER_FAIL_KNOCKBACK_PX: float = 180.0
const ANSWER_FAIL_HITSTUN_MS: float = 400.0
const ANSWER_FAIL_INVULN_MS: float = 600.0

enum AnswerState { IDLE, ACTIVE_POSE, RECOVERY_WHIFF }

# --- §4.2 Return design contract (post-restoration only) --------------------
# While holding a resolved note, Strike becomes Return: no new button, the
# same press releases the just-answered enemy's own note back at it. Startup
# differs from Strike's; active/recovery reuse Strike's own timing since §4.2
# specifies no separate numbers for them — Return changes what the press
# does, not the beat it's on.
const RETURN_STARTUP_MS: float = 120.0
const RETURN_DAMAGE: int = STRIKE_DAMAGE * 3
const RETURN_STAGGER_MS: float = 1600.0

signal strike_state_changed(state: int)
signal answer_state_changed(state: int)
signal answer_resolved(emitter: TellEmitter, press_ms: float)
signal answer_whiffed(press_ms: float)
signal return_executed(target: Node)

@onready var player: CharacterBody2D = get_parent()

# Strike's hitbox is a direct PhysicsServer2D shape query each active tick,
# not an Area2D. An Area2D (tried both as a child of the player's
# CharacterBody2D and as a runtime-created sibling) reliably failed to
# report a stationary body it was fully, geometrically overlapping —
# confirmed against a from-scratch control Area2D with identical geometry/
# layer/mask that worked correctly in the same scene — while only ever
# reporting the player's own touching collider. Root cause not isolated to
# a specific Area2D setting; a stateless shape query sidesteps whatever
# enter/exit-tracking assumption was being violated.
var _strike_hitbox_shape := RectangleShape2D.new()
var _strike_hitbox_position: Vector2 = Vector2.ZERO

var strike_state: int = StrikeState.IDLE
var _strike_timer_ms: float = 0.0
var _strike_buffer := InputBuffer.new(&"strike")
var _struck_bodies: Array = []
var _is_return: bool = false  # true for this Strike-state activation only
var _last_resolved_emitter: TellEmitter = null

var answer_state: int = AnswerState.IDLE
var _answer_timer_ms: float = 0.0
var _answer_buffer := InputBuffer.new(&"answer")
var _answer_press_pending: bool = false
var _answer_pending_press_ms: float = -INF
var resolved_note_timer_ms: float = 0.0

var _tells: Array = []

# --- Debug-overlay-facing readouts (§11.2/§11.3 instrumentation) -----------
var last_tell_onset_ms: float = -INF
var last_tell_close_ms: float = -INF
var last_tell_transient_ms: float = -INF
var last_answer_press_ms: float = -INF
var last_answer_result: String = ""  # "success" | "whiff" | ""


func _ready() -> void:
	_strike_hitbox_shape.size = Vector2(STRIKE_REACH_PX, STRIKE_HITBOX_HEIGHT_PX)


func register_tell_emitter(emitter: TellEmitter) -> void:
	_tells.append(emitter)
	emitter.tell_opened.connect(_on_tell_opened.bind(emitter))
	# Note: PlayerCombat does NOT listen for tell_missed to deal damage.
	# "The attack lands" is enemy-specific (a lunge's reach check, a
	# projectile's travel-and-hit) — whoever opens the tell owns resolving
	# it. PlayerCombat's job is only answer-matching/arbitration and
	# bookkeeping for the overlay.


## §5 shared rule 5: no enemy may begin a tell while another enemy's tell is
## open *and* within 200 ms of its onset — tells must stagger so two open
## windows are always distinguishable. Enemies call this before opening.
func can_open_tell(now_ms: float = -1.0) -> bool:
	if now_ms < 0.0:
		now_ms = Time.get_ticks_msec()
	for emitter in _tells:
		if is_instance_valid(emitter) and emitter.is_open():
			if absf(now_ms - emitter.onset_ms()) < 200.0:
				return false
	return true


## Strike is locked out during startup and active — "not cancellable during
## startup" per §3.2, and active is a committed hit, not a cancel window
## either. Recovery is unlocked from its first frame, which is what makes
## "cancellable into Jump from the first recovery frame" true for free: Jump
## simply isn't blocked once recovery begins.
func is_jump_locked() -> bool:
	return strike_state == StrikeState.STARTUP or strike_state == StrikeState.ACTIVE


func has_resolved_note() -> bool:
	return resolved_note_timer_ms > 0.0


func _physics_process(delta: float) -> void:
	var delta_ms := delta * 1000.0
	_strike_buffer.poll()
	_answer_buffer.poll()

	_update_strike(delta_ms)
	_update_answer(delta_ms)

	if resolved_note_timer_ms > 0.0:
		resolved_note_timer_ms = maxf(0.0, resolved_note_timer_ms - delta_ms)


# --- Strike ------------------------------------------------------------------

func _update_strike(delta_ms: float) -> void:
	match strike_state:
		StrikeState.IDLE:
			if _strike_buffer.is_buffered(STRIKE_BUFFER_MS):
				_strike_buffer.consume()
				_is_return = _can_return()
				_set_strike_state(StrikeState.STARTUP)
				_strike_timer_ms = RETURN_STARTUP_MS if _is_return else STRIKE_STARTUP_MS
		StrikeState.STARTUP:
			_strike_timer_ms -= delta_ms
			if _strike_timer_ms <= 0.0:
				_set_strike_state(StrikeState.ACTIVE)
				_strike_timer_ms = STRIKE_ACTIVE_MS
				if _is_return:
					_execute_return()
				else:
					_open_strike_hitbox()
		StrikeState.ACTIVE:
			if not _is_return:
				_apply_strike_hits()
			_strike_timer_ms -= delta_ms
			if _strike_timer_ms <= 0.0:
				_close_strike_hitbox()
				_set_strike_state(StrikeState.RECOVERY)
				_strike_timer_ms = STRIKE_RECOVERY_MS
		StrikeState.RECOVERY:
			_strike_timer_ms -= delta_ms
			if _strike_timer_ms <= 0.0:
				_set_strike_state(StrikeState.IDLE)


## §4.2: Strike becomes Return only while holding a resolved note, only
## post-restoration, and only if that note's tell belongs to something that
## can actually take a hit (the restoration encounter's own notes don't —
## Return is a combat tool, Answer against the Verse-bearer stays a plain
## Answer either way).
func _can_return() -> bool:
	if not GameState.restoration_complete or not has_resolved_note():
		return false
	if not is_instance_valid(_last_resolved_emitter):
		return false
	var target := _last_resolved_emitter.get_parent()
	return target != null and target.has_method("take_strike")


func _execute_return() -> void:
	var target := _last_resolved_emitter.get_parent()
	if target != null and target.has_method("take_strike"):
		target.take_strike(RETURN_DAMAGE)
	_last_resolved_emitter.stagger_ms = RETURN_STAGGER_MS
	# The note is spent the instant it's returned — a second Strike press
	# during what's left of the same window must not Return it again.
	resolved_note_timer_ms = 0.0
	return_executed.emit(target)


func _set_strike_state(state: int) -> void:
	strike_state = state
	strike_state_changed.emit(state)


func _open_strike_hitbox() -> void:
	_struck_bodies.clear()
	var facing: float = player.facing if "facing" in player else 1.0
	var collider_half_width: float = 9.0
	if player.has_node("CollisionShape2D"):
		var shape := (player.get_node("CollisionShape2D") as CollisionShape2D).shape
		if shape is RectangleShape2D:
			collider_half_width = shape.size.x * 0.5

	var reach_center := collider_half_width + STRIKE_REACH_PX * 0.5
	# Vertical center matches the player collider's own vertical center
	# (CollisionShape2D sits at local y = -20 for the 40 px-tall collider).
	_strike_hitbox_position = player.global_position + Vector2(facing * reach_center, -20.0)


func _close_strike_hitbox() -> void:
	pass  # Nothing to tear down — the hitbox is a query, not a live node.


func _apply_strike_hits() -> void:
	var space_state := player.get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _strike_hitbox_shape
	query.transform = Transform2D(0.0, _strike_hitbox_position)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [player.get_rid()]
	var bodies: Array = []
	for result in space_state.intersect_shape(query, 32):
		bodies.append(result.collider)
	_apply_hits_to_bodies(bodies)


## Split out from _apply_strike_hits() so the dedupe/damage logic is testable
## with a hand-built body list, independent of the physics query.
func _apply_hits_to_bodies(bodies: Array) -> void:
	for body in bodies:
		# The query already excludes the player's own RID; this is just a
		# defensive backstop against ever re-hitting it.
		if body == player or body in _struck_bodies:
			continue
		_struck_bodies.append(body)
		if body.has_method("take_strike"):
			body.take_strike(STRIKE_DAMAGE)


# --- Answer --------------------------------------------------------------

func _update_answer(delta_ms: float) -> void:
	match answer_state:
		AnswerState.IDLE:
			# Startup is 0 ms — "read on press" — so unlike Strike/Jump there's
			# no eligibility window to buffer against; Answer is always
			# immediately actionable while idle. just_pressed comes from the
			# buffer's own rising-edge detection (polled above), not
			# Input.is_action_just_pressed() directly — see input_buffer.gd.
			if _answer_buffer.just_pressed:
				_start_answer(_answer_buffer.last_press_ms())
		AnswerState.ACTIVE_POSE:
			_answer_timer_ms -= delta_ms
			if _answer_timer_ms <= 0.0:
				_finish_answer_pose()
		AnswerState.RECOVERY_WHIFF:
			_answer_timer_ms -= delta_ms
			if _answer_timer_ms <= 0.0:
				_set_answer_state(AnswerState.IDLE)


func _start_answer(press_ms: float) -> void:
	last_answer_press_ms = press_ms
	last_answer_result = ""
	_set_answer_state(AnswerState.ACTIVE_POSE)
	_answer_timer_ms = ANSWER_ACTIVE_POSE_MS
	_answer_press_pending = true
	_answer_pending_press_ms = press_ms

	# A window that's already open (or opened up to ANSWER_PRE_WINDOW_BUFFER_MS
	# before this press — §3.3's fairness rule) resolves immediately.
	var emitter := _find_matching_open_tell(press_ms)
	if emitter != null:
		_resolve_answer_success(emitter)


func _finish_answer_pose() -> void:
	if _answer_press_pending:
		_resolve_answer_whiff()
	else:
		# Already resolved successfully earlier in the pose (see
		# _on_tell_opened / _start_answer); success recovery is 0 ms, so the
		# fixed 180 ms active pose finishing just returns straight to idle.
		_set_answer_state(AnswerState.IDLE)


func _find_matching_open_tell(press_ms: float) -> TellEmitter:
	# §5 shared rule 6: with two open windows, an Answer resolves the one
	# whose attack lands soonest (earliest close_ms) — never the one that
	# opened first, never the nearest enemy. Ties break on nearest enemy by
	# centre distance, then on lowest instance id, so the result is
	# deterministic and reproducible.
	var best: TellEmitter = null
	for emitter in _tells:
		if not is_instance_valid(emitter) or not emitter.is_open():
			continue
		if not _press_matches_window(press_ms, emitter.onset_ms(), emitter.close_ms()):
			continue
		if best == null or _is_better_tell_match(emitter, best):
			best = emitter
	return best


func _is_better_tell_match(candidate: TellEmitter, current_best: TellEmitter) -> bool:
	if candidate.close_ms() != current_best.close_ms():
		return candidate.close_ms() < current_best.close_ms()
	var d_candidate := player.global_position.distance_to(candidate.global_position)
	var d_best := player.global_position.distance_to(current_best.global_position)
	if d_candidate != d_best:
		return d_candidate < d_best
	return candidate.get_instance_id() < current_best.get_instance_id()


func _press_matches_window(press_ms: float, onset_ms: float, close_ms: float) -> bool:
	# The pre-window buffer folds into a single comparison: a press counts if
	# it landed anywhere from ANSWER_PRE_WINDOW_BUFFER_MS before onset through
	# the window's close, inclusive.
	return press_ms >= onset_ms - ANSWER_PRE_WINDOW_BUFFER_MS and press_ms <= close_ms


func _on_tell_opened(onset_ms: float, close_ms: float, emitter: TellEmitter) -> void:
	last_tell_onset_ms = onset_ms
	last_tell_close_ms = close_ms
	last_tell_transient_ms = emitter.transient_ms()
	if not _answer_press_pending:
		return
	# Re-run full arbitration rather than assuming the newly-opened window is
	# the match: it might not even be the soonest-landing one if another
	# tell was already open (§5 shared rule 6).
	var best := _find_matching_open_tell(_answer_pending_press_ms)
	if best != null:
		_resolve_answer_success(best)


func _resolve_answer_success(emitter: TellEmitter) -> void:
	# Success recovery is 0 ms (ANSWER_SUCCESS_RECOVERY_MS), so a success just
	# marks the outcome and lets the fixed 180 ms active pose run out on its
	# own timer (_finish_answer_pose) rather than adding a recovery state.
	_answer_press_pending = false
	emitter.resolve(ANSWER_ENEMY_STAGGER_MS)
	resolved_note_timer_ms = RESOLVED_NOTE_HOLD_MS
	_last_resolved_emitter = emitter
	last_answer_result = "success"
	answer_resolved.emit(emitter, _answer_pending_press_ms)


func _resolve_answer_whiff() -> void:
	_answer_press_pending = false
	last_answer_result = "whiff"
	answer_whiffed.emit(_answer_pending_press_ms)
	_set_answer_state(AnswerState.RECOVERY_WHIFF)
	_answer_timer_ms = ANSWER_WHIFF_RECOVERY_MS


func _set_answer_state(state: int) -> void:
	answer_state = state
	answer_state_changed.emit(state)
