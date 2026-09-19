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

func _init(p_action: StringName) -> void:
	action = p_action


## Call once per physics frame to record a fresh press.
func poll() -> void:
	if Input.is_action_just_pressed(action):
		_last_press_ms = Time.get_ticks_msec()


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
