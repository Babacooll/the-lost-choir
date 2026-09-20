extends Node
## Autoload singleton. Design spec §8 / art-direction doc §4.2: the cold->warm
## warmth field, a single scalar `w` per pixel driven off the one
## GameState.restoration_complete flag — no second state for this (per the
## checkpoint dispatch and ARCHITECTURE.md's one-flag convergence rule).
##
## One elapsed-time clock, shared by every room, rather than a per-room timer
## that would restart the moment a player happens to walk in — "full duration
## 2500 ms" is one global event a room can arrive before, during or after.

const PROPAGATION_SPEED_PX_S: float = 300.0
const BAND_WIDTH_PX: float = 24.0
const BAND_OVERSHOOT: float = 1.15
const BAND_SETTLE_MS: float = 400.0
## Time for the 24 px band itself to sweep past a fixed point, at the fixed
## propagation speed — not an authored constant, a consequence of the other two.
const BAND_DURATION_MS: float = BAND_WIDTH_PX / PROPAGATION_SPEED_PX_S * 1000.0

var _elapsed_ms: float = 0.0
var _restoration_started_at_ms: float = -1.0


func _ready() -> void:
	GameState.restoration_state_changed.connect(_on_restoration_state_changed)


func _physics_process(delta: float) -> void:
	_elapsed_ms += delta * 1000.0


func _on_restoration_state_changed(value: bool) -> void:
	_restoration_started_at_ms = _elapsed_ms if value else -1.0


func _time_since_restoration_ms() -> float:
	if _restoration_started_at_ms < 0.0:
		return -1.0
	return _elapsed_ms - _restoration_started_at_ms


## The design-spec formula in isolation, driven by explicit inputs so it can
## be tested without a scene tree: distance from the seam in px, and elapsed
## time since restoration began in ms. Linear in distance, no ease-in/out —
## a wave, not a fade (art doc §4.2).
static func warmth_at_distance(distance_px: float, time_since_restoration_ms: float) -> float:
	if time_since_restoration_ms < 0.0:
		return 0.0
	var arrival_ms := distance_px / PROPAGATION_SPEED_PX_S * 1000.0
	var elapsed := time_since_restoration_ms - arrival_ms
	if elapsed < 0.0:
		return 0.0  # wavefront hasn't reached this point yet
	if elapsed < BAND_DURATION_MS:
		# inside the 24 px leading-edge band: ramping up to the overshoot peak
		return lerpf(0.0, BAND_OVERSHOOT, elapsed / BAND_DURATION_MS)
	var settle_elapsed := elapsed - BAND_DURATION_MS
	if settle_elapsed < BAND_SETTLE_MS:
		# behind the band: overshoot settling to steady warm over 400 ms
		return lerpf(BAND_OVERSHOOT, 1.0, settle_elapsed / BAND_SETTLE_MS)
	return 1.0


## Per-visual entry point. Room-aware so callers never need to know whether
## they're in an authored-warm room (R7/R8, pinned to w=1) or a propagating
## one, or where that room's seam origin actually is.
func warmth_at(world_pos: Vector2) -> float:
	var room: Room = ZoneManager.current_room
	if room == null:
		return 0.0
	if room.pin_warmth:
		return 1.0
	var distance := world_pos.distance_to(room.warmth_origin())
	return warmth_at_distance(distance, _time_since_restoration_ms())
