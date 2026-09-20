extends CharacterBody2D
## Player controller for the vertical slice's pre-Verse starting kit.
##
## Movement values are the design contract in docs/design/vertical-slice.md §3.1.
## They are fixed points, not tuning defaults — changing any of them requires a
## Design sign-off, not an engineering judgment call.

# --- §3.1 Movement design contract -----------------------------------------

const RUN_MAX_SPEED: float = 170.0          # px/s
const ACCEL_TIME: float = 0.09              # 90 ms to reach RUN_MAX_SPEED
const DECEL_TIME: float = 0.07              # 70 ms to reach rest from RUN_MAX_SPEED

const JUMP_APEX_HEIGHT: float = 56.0        # px
const TIME_TO_APEX: float = 0.32            # 320 ms
const FALL_GRAVITY_MULT: float = 1.7        # fall gravity = 1.7x rise gravity
const JUMP_CUT_MULTIPLIER: float = 0.45     # variable jump cut on early release
const TERMINAL_FALL_SPEED: float = 520.0    # px/s

const COYOTE_TIME: float = 0.10             # 100 ms
const JUMP_BUFFER_TIME: float = 0.12        # 120 ms

const CORNER_CORRECTION_PX: float = 4.0     # horizontal ceiling-corner clip tolerance, load-bearing for H1

# Derived kinematics (do not hand-tune; these follow from the table above).
const ACCEL: float = RUN_MAX_SPEED / ACCEL_TIME
const DECEL: float = RUN_MAX_SPEED / DECEL_TIME
# v0 such that a projectile under RISE_GRAVITY reaches JUMP_APEX_HEIGHT in TIME_TO_APEX:
#   apex = v0 * t - 0.5 * g * t^2, with g = v0 / t  =>  apex = 0.5 * v0 * t
const JUMP_VELOCITY: float = 2.0 * JUMP_APEX_HEIGHT / TIME_TO_APEX
const RISE_GRAVITY: float = JUMP_VELOCITY / TIME_TO_APEX
const FALL_GRAVITY: float = RISE_GRAVITY * FALL_GRAVITY_MULT

# Vertical look-ahead for the corner-correction probes — how far we're about to
# rise into a ceiling this tick. Not a design value; §3.1's 4 px figure is a
# horizontal clip tolerance (CORNER_CORRECTION_PX above), not this.
const CORNER_PROBE_MIN_LOOKAHEAD: float = 1.0

## §3.4 health/failure contract (minimal support for Answer's failure effects
## this checkpoint — no death/respawn behavior yet, that's a later checkpoint).
const MAX_HP: int = 5

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
# PlayerCombat is combat.gd's global class_name — no preload needed to type this.
@onready var combat: PlayerCombat = get_node_or_null("Combat")

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var was_on_floor: bool = false
var jump_held: bool = false
var jump_cut_applied: bool = false
# Only a jump that was still holding Jump as it launched can ever be cut short.
# A buffered tap whose button was already up when the jump fires keeps its full
# 56 px / 320 ms apex — nothing in §3.1 lets a pre-landing release retroactively
# read as a mid-rise release.
var jump_cut_eligible: bool = false

# Facing direction: +1 right, -1 left. Drives Strike's reach direction and
# knockback direction on a failed Answer. Updated on horizontal input only,
# so it holds steady while airborne/idle rather than snapping to 1.0.
var facing: float = 1.0

# Hit-reaction state, driven by take_hit() (see Answer's §3.3 failure effects).
var hp: int = MAX_HP
var hitstun_timer_ms: float = 0.0
var invuln_timer_ms: float = 0.0
var knockback_velocity_x: float = 0.0

# Exposed for the debug overlay (checkpoint 3 just needs a readout).
var debug_state: String = "idle"

func _physics_process(delta: float) -> void:
	var delta_ms := delta * 1000.0
	_update_hit_reaction(delta_ms)

	if hitstun_timer_ms > 0.0:
		velocity.x = knockback_velocity_x
	else:
		_apply_horizontal_movement(delta)

	# Buffer/coyote resolution runs before gravity so a jump that launches this
	# tick is evaluated against this tick's freshly-sampled input, not last
	# frame's stale jump_held.
	_handle_jump_buffer_and_coyote(delta)
	_apply_gravity(delta)
	_try_corner_correction(delta)

	was_on_floor = is_on_floor()
	move_and_slide()

	if is_on_floor() and not was_on_floor:
		jump_cut_applied = false

	_update_debug_state()


func _apply_horizontal_movement(delta: float) -> void:
	# Air control is 100% of ground accel — no separate air-accel constant needed.
	var input_dir := Input.get_axis("move_left", "move_right")

	if input_dir != 0.0:
		facing = signf(input_dir)
		velocity.x = move_toward(velocity.x, RUN_MAX_SPEED * input_dir, ACCEL * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, DECEL * delta)


## Applies a hit's damage/knockback/hitstun/invulnerability. Ignored while
## already invulnerable. Knockback is a constant horizontal velocity held for
## the hitstun duration, sized so total displacement matches knockback_px —
## the design contract (e.g. §3.3's Answer failure) specifies distance and
## duration, not a curve, so a flat-velocity impulse is the direct reading of
## those two numbers. Callers own their own damage/knockback/timing constants;
## this method just applies whatever it's given.
func take_hit(damage: int, knockback_dir: Vector2, knockback_px: float, hitstun_ms: float, invuln_ms: float) -> void:
	if invuln_timer_ms > 0.0:
		return
	hp = maxi(0, hp - damage)
	hitstun_timer_ms = hitstun_ms
	invuln_timer_ms = invuln_ms
	var dir_x := signf(knockback_dir.x) if knockback_dir.x != 0.0 else -facing
	var speed := 0.0
	if hitstun_ms > 0.0:
		speed = knockback_px / (hitstun_ms / 1000.0)
	knockback_velocity_x = dir_x * speed


func _update_hit_reaction(delta_ms: float) -> void:
	if hitstun_timer_ms > 0.0:
		hitstun_timer_ms = maxf(0.0, hitstun_timer_ms - delta_ms)
		if hitstun_timer_ms <= 0.0:
			# §3.3: the 180 px knockback is measured to where the player
			# comes to rest with no input, not the impulse itself. Residual
			# velocity carrying past hitstun end under normal deceleration
			# would drift the landing spot past the contracted distance, so
			# control returns from a standing start rather than a coast-out.
			velocity.x = 0.0
			knockback_velocity_x = 0.0
	if invuln_timer_ms > 0.0:
		invuln_timer_ms = maxf(0.0, invuln_timer_ms - delta_ms)


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		# is_on_floor() still reflects the last move_and_slide() until the next
		# one runs. If a jump launched earlier this tick, velocity.y is already
		# negative — leave it alone rather than clobbering the jump, and skip
		# gravity/cut for this single tick (the body hasn't left the floor yet
		# as far as physics is concerned).
		if velocity.y >= 0.0:
			velocity.y = 0.0
		return

	var gravity := RISE_GRAVITY if velocity.y < 0.0 else FALL_GRAVITY
	velocity.y += gravity * delta
	velocity.y = min(velocity.y, TERMINAL_FALL_SPEED)

	# Variable jump cut: releasing Jump before apex (still rising) cuts vy once,
	# but only for a jump that was actually being held as it launched.
	if velocity.y < 0.0 and jump_cut_eligible and not jump_held and not jump_cut_applied:
		velocity.y *= JUMP_CUT_MULTIPLIER
		jump_cut_applied = true


func _handle_jump_buffer_and_coyote(delta: float) -> void:
	jump_held = Input.is_action_pressed("jump")

	# Coyote time: only valid after walking off a ledge, not after an intentional jump.
	if is_on_floor():
		coyote_timer = COYOTE_TIME
	elif coyote_timer > 0.0:
		coyote_timer -= delta

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	elif jump_buffer_timer > 0.0:
		jump_buffer_timer -= delta

	# Jump buffer consumes on the first frame ground contact is true (incl.
	# moving platforms). Strike locks Jump out during its startup/active
	# frames (§3.2: "not cancellable during startup") — the buffered request
	# simply waits, same as it would for a floor that hasn't arrived yet.
	var jump_locked_by_combat := combat != null and combat.is_jump_locked()
	var can_jump := (is_on_floor() or coyote_timer > 0.0) and not jump_locked_by_combat
	if jump_buffer_timer > 0.0 and can_jump:
		velocity.y = -JUMP_VELOCITY
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		jump_cut_applied = false
		jump_cut_eligible = jump_held


func _try_corner_correction(delta: float) -> void:
	# A jump that clips a ceiling corner within a 4 px HORIZONTAL tolerance is
	# nudged sideways rather than stopped — the spec's case is centre clear,
	# a corner blocked, with no precondition on horizontal approach speed.
	# Centre blocked is a real ceiling contact and must bonk normally, not be
	# nudged into (or through) the obstruction.
	if velocity.y >= 0.0:
		return

	var shape := collision_shape.shape as RectangleShape2D
	if shape == null:
		return

	var half_width := shape.size.x * 0.5
	var top_y := collision_shape.position.y - shape.size.y * 0.5
	var probe_lookahead := maxf(CORNER_PROBE_MIN_LOOKAHEAD, -velocity.y * delta)

	# Centre clear?
	if _probe_blocked(0.0, top_y, probe_lookahead):
		return  # real ceiling contact ahead; let it bonk normally

	var dir := signf(velocity.x)
	if dir != 0.0:
		# Directional approach: only the leading corner (the side we're
		# moving into) can clip.
		_nudge_away_from_corner(dir, half_width, top_y, probe_lookahead)
		return

	# Standing/vertical jump: there's no horizontal approach to pick a
	# "leading" side, so probe both corners directly and nudge away from
	# whichever one alone is clipped. Both (or neither) blocked has no
	# unambiguous side to nudge toward, so it falls through to the normal
	# collision response (a real ceiling bonk, or nothing).
	var left_blocked := _probe_blocked(-half_width, top_y, probe_lookahead)
	var right_blocked := _probe_blocked(half_width, top_y, probe_lookahead)
	if left_blocked and not right_blocked:
		_nudge_away_from_corner(-1.0, half_width, top_y, probe_lookahead)
	elif right_blocked and not left_blocked:
		_nudge_away_from_corner(1.0, half_width, top_y, probe_lookahead)


func _nudge_away_from_corner(dir: float, half_width: float, top_y: float, probe_lookahead: float) -> void:
	var leading_x := dir * half_width
	if not _probe_blocked(leading_x, top_y, probe_lookahead):
		return  # nothing to correct on this side

	# Would nudging CORNER_CORRECTION_PX away from the obstruction actually
	# clear it? If that point is still blocked, this is wider than a corner
	# sliver — a real wall — and must not be nudged through.
	var nudged_x := leading_x - dir * CORNER_CORRECTION_PX
	if _probe_blocked(nudged_x, top_y, probe_lookahead):
		return

	# Move away from the obstruction with a collision-aware motion so we can
	# never nudge into (or through) something solid.
	move_and_collide(Vector2(-dir * CORNER_CORRECTION_PX, 0.0))


func _probe_blocked(x_offset: float, top_y: float, lookahead: float) -> bool:
	var from := global_position + Vector2(x_offset, top_y)
	var to := from + Vector2(0.0, -lookahead)
	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.exclude = [self]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return not hit.is_empty()


func _update_debug_state() -> void:
	if not is_on_floor():
		debug_state = "jump" if velocity.y < 0.0 else "fall"
	elif abs(velocity.x) > 0.1:
		debug_state = "run"
	else:
		debug_state = "idle"
