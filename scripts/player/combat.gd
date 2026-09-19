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

signal strike_state_changed(state: int)
signal answer_state_changed(state: int)
signal answer_resolved(emitter: TellEmitter, press_ms: float)
signal answer_whiffed(press_ms: float)

@onready var player: CharacterBody2D = get_parent()
@onready var strike_hitbox: Area2D = get_node_or_null("../StrikeHitbox")

var strike_state: int = StrikeState.IDLE
var _strike_timer_ms: float = 0.0
var _strike_buffer := InputBuffer.new(&"strike")
var _struck_bodies: Array = []

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
var last_answer_press_ms: float = -INF
var last_answer_result: String = ""  # "success" | "whiff" | ""


func _ready() -> void:
	if strike_hitbox != null:
		strike_hitbox.monitoring = false


func register_tell_emitter(emitter: TellEmitter) -> void:
	_tells.append(emitter)
	emitter.tell_opened.connect(_on_tell_opened.bind(emitter))
	emitter.tell_missed.connect(_on_tell_missed.bind(emitter))


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
				_set_strike_state(StrikeState.STARTUP)
				_strike_timer_ms = STRIKE_STARTUP_MS
		StrikeState.STARTUP:
			_strike_timer_ms -= delta_ms
			if _strike_timer_ms <= 0.0:
				_set_strike_state(StrikeState.ACTIVE)
				_strike_timer_ms = STRIKE_ACTIVE_MS
				_open_strike_hitbox()
		StrikeState.ACTIVE:
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


func _set_strike_state(state: int) -> void:
	strike_state = state
	strike_state_changed.emit(state)


func _open_strike_hitbox() -> void:
	_struck_bodies.clear()
	if strike_hitbox == null:
		return
	var facing: float = player.facing if "facing" in player else 1.0
	var collider_half_width: float = 9.0
	if player.has_node("CollisionShape2D"):
		var shape := (player.get_node("CollisionShape2D") as CollisionShape2D).shape
		if shape is RectangleShape2D:
			collider_half_width = shape.size.x * 0.5

	var reach_center := collider_half_width + STRIKE_REACH_PX * 0.5
	# Vertical center matches the player collider's own vertical center
	# (CollisionShape2D sits at local y = -20 for the 40 px-tall collider).
	strike_hitbox.position = Vector2(facing * reach_center, -20.0)
	var col_shape := strike_hitbox.get_node_or_null("CollisionShape2D")
	if col_shape != null and col_shape.shape is RectangleShape2D:
		col_shape.shape.size = Vector2(STRIKE_REACH_PX, STRIKE_HITBOX_HEIGHT_PX)
	strike_hitbox.monitoring = true


func _close_strike_hitbox() -> void:
	if strike_hitbox != null:
		strike_hitbox.monitoring = false


func _apply_strike_hits() -> void:
	if strike_hitbox == null:
		return
	for body in strike_hitbox.get_overlapping_bodies():
		if body in _struck_bodies:
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
	# §3.3 "overlapping tell windows": resolves the tell whose attack lands
	# soonest (earliest close_ms) among all matches.
	var best: TellEmitter = null
	for emitter in _tells:
		if not is_instance_valid(emitter) or not emitter.is_open():
			continue
		if _press_matches_window(press_ms, emitter.onset_ms(), emitter.close_ms()):
			if best == null or emitter.close_ms() < best.close_ms():
				best = emitter
	return best


func _press_matches_window(press_ms: float, onset_ms: float, close_ms: float) -> bool:
	# The pre-window buffer folds into a single comparison: a press counts if
	# it landed anywhere from ANSWER_PRE_WINDOW_BUFFER_MS before onset through
	# the window's close, inclusive.
	return press_ms >= onset_ms - ANSWER_PRE_WINDOW_BUFFER_MS and press_ms <= close_ms


func _on_tell_opened(onset_ms: float, close_ms: float, emitter: TellEmitter) -> void:
	last_tell_onset_ms = onset_ms
	last_tell_close_ms = close_ms
	if not _answer_press_pending:
		return
	if _press_matches_window(_answer_pending_press_ms, onset_ms, close_ms):
		_resolve_answer_success(emitter)


func _on_tell_missed(emitter: TellEmitter) -> void:
	# The attack resolves whether or not the player was mid-Answer at all —
	# "on failure (whiff or no press)" ties the damage to the tell closing
	# unresolved, not to the Answer move's own state machine.
	if player != null and player.has_method("take_hit"):
		var knockback_dir := Vector2.RIGHT
		if player.facing != 0.0:
			knockback_dir = Vector2(-player.facing, 0.0)
		player.take_hit(
			ANSWER_FAIL_DAMAGE, knockback_dir, ANSWER_FAIL_KNOCKBACK_PX,
			ANSWER_FAIL_HITSTUN_MS, ANSWER_FAIL_INVULN_MS
		)


func _resolve_answer_success(emitter: TellEmitter) -> void:
	# Success recovery is 0 ms (ANSWER_SUCCESS_RECOVERY_MS), so a success just
	# marks the outcome and lets the fixed 180 ms active pose run out on its
	# own timer (_finish_answer_pose) rather than adding a recovery state.
	_answer_press_pending = false
	emitter.resolve(ANSWER_ENEMY_STAGGER_MS)
	resolved_note_timer_ms = RESOLVED_NOTE_HOLD_MS
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
