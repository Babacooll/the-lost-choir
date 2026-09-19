class_name InputBuffer
extends RefCounted
## Generalizes the checkpoint-1 jump-buffer pattern for reuse by Strike and Answer.
##
## Unlike a countdown timer that is silently consumed, this keeps the actual
## wall-clock timestamp (`Time.get_ticks_msec()`) of the most recent press, so
## callers can inspect *when* a press happened relative to some other event —
## not just whether "a press is currently buffered". The debug overlay's
## tell-vs-input plot reads `last_press_ms()` directly for this reason.

var action: StringName
var _last_press_ms: float = -INF
var _was_pressed: bool = false

## True only during the poll() call that detected the rising edge — for
## callers (like Answer, whose 0 ms startup means it acts on the edge
## directly rather than through a buffered window) that want "was this
## action just pressed" without a window comparison.
var just_pressed: bool = false

func _init(p_action: StringName) -> void:
	action = p_action


## Call once per physics frame to record a fresh press. Detects the rising
## edge itself (comparing this poll to the last one) rather than relying on
## Input.is_action_just_pressed(), which is only guaranteed accurate for
## nodes polled directly by the engine's own per-frame input pass — a node
## nested under another (like Combat under Player) can poll on a tick where
## the "just pressed" flag has already lapsed even though the action only
## just became pressed as far as this buffer has observed it.
func poll() -> void:
	var is_pressed := Input.is_action_pressed(action)
	just_pressed = is_pressed and not _was_pressed
	if just_pressed:
		_last_press_ms = Time.get_ticks_msec()
	_was_pressed = is_pressed


## True if the most recent press falls within `window_ms` before `now_ms`
## (inclusive of both ends): now_ms - window_ms <= last_press_ms <= now_ms.
func is_buffered(window_ms: float, now_ms: float = -1.0) -> bool:
	if _last_press_ms == -INF:
		return false
	if now_ms < 0.0:
		now_ms = Time.get_ticks_msec()
	return _last_press_ms >= now_ms - window_ms and _last_press_ms <= now_ms


## Invalidates the buffered press so it cannot be reused by a later check.
func consume() -> void:
	_last_press_ms = -INF


## Timestamp (Time.get_ticks_msec()) of the most recent press, or -INF if none
## has been recorded (or the buffer was consumed).
func last_press_ms() -> float:
	return _last_press_ms
