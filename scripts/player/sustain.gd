class_name PlayerSustain
extends Node
## §4.1 Sustain — the traversal verb the restored Verse grants. Values below
## are design contracts; changing one needs a Design sign-off.
##
## Not usable before restoration (GameState.restoration_complete). World
## objects (Membrane, BellFrame) read world_effects_active() and this node's
## global_position to decide whether they're within range of an engaged
## Sustain, rather than this node knowing about them.

const RAMP_IN_MS: float = 180.0
const RAMP_OUT_MS: float = 120.0
const BREATH_MAX_MS: float = 3000.0
const REFILL_RATE_MULT: float = 1.5  # refill speed relative to drain speed -> full refill in 2000 ms
const REFILL_DELAY_MS: float = 500.0
const RUN_SPEED_MULT: float = 0.85
const WORLD_EFFECT_RANGE_PX: float = 140.0

enum State { IDLE, RAMPING_IN, ACTIVE, RAMPING_OUT }

signal world_effect_engaged()
signal world_effect_released()

var state: int = State.IDLE
var breath_ms: float = BREATH_MAX_MS

var _hold_elapsed_ms: float = 0.0
var _release_elapsed_ms: float = 0.0
var _refill_delay_remaining_ms: float = 0.0

@onready var player: CharacterBody2D = get_parent()


func is_available() -> bool:
	return GameState.restoration_complete


## World effects (membranes/bell-frames) are live from the moment ramp-in
## completes until ramp-out's 120 ms grace elapses — a released-but-not-yet-
## faded hold still counts.
func world_effects_active() -> bool:
	return state == State.ACTIVE or state == State.RAMPING_OUT


## Movement slowdown tracks the same window as world effects, not the raw
## button hold — a sub-180 ms tap must not be felt at all (§4.1's anti-
## flicker intent extends to movement, not just the platforms).
func is_slowing_movement() -> bool:
	return world_effects_active()


func breath_fraction() -> float:
	return breath_ms / BREATH_MAX_MS


func _physics_process(delta: float) -> void:
	var delta_ms := delta * 1000.0
	var held := is_available() and Input.is_action_pressed("sustain") and breath_ms > 0.0

	match state:
		State.IDLE:
			if held:
				state = State.RAMPING_IN
				_hold_elapsed_ms = 0.0
		State.RAMPING_IN:
			if not held:
				state = State.IDLE
			else:
				_hold_elapsed_ms += delta_ms
				if _hold_elapsed_ms >= RAMP_IN_MS:
					state = State.ACTIVE
					# Audio bible §3: the engage partial is the player's only
					# readout for this otherwise-invisible gate, so it must
					# fire on this exact same tick, not via a signal a frame
					# later.
					AudioDirector.on_sustain_engaged()
					world_effect_engaged.emit()
		State.ACTIVE:
			if not held:
				if breath_ms <= 0.0:
					AudioDirector.on_sustain_breath_exhausted()
				state = State.RAMPING_OUT
				_release_elapsed_ms = 0.0
		State.RAMPING_OUT:
			if held:
				state = State.ACTIVE
			else:
				_release_elapsed_ms += delta_ms
				if _release_elapsed_ms >= RAMP_OUT_MS:
					state = State.IDLE
					AudioDirector.on_sustain_released()
					world_effect_released.emit()

	AudioDirector.set_breath_remaining(breath_fraction())
	_tick_breath(delta_ms, held)


func _tick_breath(delta_ms: float, held: bool) -> void:
	if held:
		breath_ms = maxf(0.0, breath_ms - delta_ms)
		_refill_delay_remaining_ms = REFILL_DELAY_MS
	elif _refill_delay_remaining_ms > 0.0:
		_refill_delay_remaining_ms = maxf(0.0, _refill_delay_remaining_ms - delta_ms)
	else:
		breath_ms = minf(BREATH_MAX_MS, breath_ms + delta_ms * REFILL_RATE_MULT)
