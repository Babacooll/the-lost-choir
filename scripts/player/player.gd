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

const CORNER_CORRECTION_PX: float = 4.0     # ceiling-corner nudge, load-bearing for H1

# Derived kinematics (do not hand-tune; these follow from the table above).
const ACCEL: float = RUN_MAX_SPEED / ACCEL_TIME
const DECEL: float = RUN_MAX_SPEED / DECEL_TIME
# v0 such that a projectile under RISE_GRAVITY reaches JUMP_APEX_HEIGHT in TIME_TO_APEX:
#   apex = v0 * t - 0.5 * g * t^2, with g = v0 / t  =>  apex = 0.5 * v0 * t
const JUMP_VELOCITY: float = 2.0 * JUMP_APEX_HEIGHT / TIME_TO_APEX
const RISE_GRAVITY: float = JUMP_VELOCITY / TIME_TO_APEX
const FALL_GRAVITY: float = RISE_GRAVITY * FALL_GRAVITY_MULT

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var was_on_floor: bool = false
var jump_held: bool = false
var jump_cut_applied: bool = false

# Exposed for the debug overlay (checkpoint 3 just needs a readout).
var debug_state: String = "idle"

func _physics_process(delta: float) -> void:
	_apply_horizontal_movement(delta)
	_apply_gravity(delta)
	_handle_jump_buffer_and_coyote(delta)
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
		velocity.x = move_toward(velocity.x, RUN_MAX_SPEED * input_dir, ACCEL * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, DECEL * delta)


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
		return

	var gravity := RISE_GRAVITY if velocity.y < 0.0 else FALL_GRAVITY
	velocity.y += gravity * delta
	velocity.y = min(velocity.y, TERMINAL_FALL_SPEED)

	# Variable jump cut: releasing Jump before apex (still rising) cuts vy once.
	if velocity.y < 0.0 and not jump_held and not jump_cut_applied:
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

	# Jump buffer consumes on the first frame ground contact is true (incl. moving platforms).
	var can_jump := is_on_floor() or coyote_timer > 0.0
	if jump_buffer_timer > 0.0 and can_jump:
		velocity.y = -JUMP_VELOCITY
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		jump_cut_applied = false


func _try_corner_correction(delta: float) -> void:
	# A jump that clips a ceiling corner within CORNER_CORRECTION_PX is nudged
	# horizontally rather than stopped. Probe just above the collider's top edge
	# on the side we're moving toward; if only that corner is blocked, nudge away.
	if velocity.y >= 0.0:
		return

	var shape := collision_shape.shape as RectangleShape2D
	if shape == null:
		return

	var half_width := shape.size.x * 0.5
	var top_y := collision_shape.position.y - shape.size.y * 0.5
	var probe_dir := signf(velocity.x) if velocity.x != 0.0 else 1.0

	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		global_position + Vector2(0.0, top_y),
		global_position + Vector2(0.0, top_y - CORNER_CORRECTION_PX)
	)
	query.exclude = [self]
	var center_hit := space_state.intersect_ray(query)
	if center_hit.is_empty():
		return

	var corner_query := PhysicsRayQueryParameters2D.create(
		global_position + Vector2(probe_dir * half_width, top_y),
		global_position + Vector2(probe_dir * half_width, top_y - CORNER_CORRECTION_PX)
	)
	corner_query.exclude = [self]
	var corner_hit := space_state.intersect_ray(corner_query)
	if corner_hit.is_empty():
		global_position.x -= probe_dir * CORNER_CORRECTION_PX


func _update_debug_state() -> void:
	if not is_on_floor():
		debug_state = "jump" if velocity.y < 0.0 else "fall"
	elif abs(velocity.x) > 0.1:
		debug_state = "run"
	else:
		debug_state = "idle"
