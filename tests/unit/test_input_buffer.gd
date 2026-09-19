extends GutTest
## Coverage for the generalized input-buffering layer (scripts/common/input_buffer.gd)
## that checkpoint 2 extends from checkpoint 1's jump buffer to cover Strike and Answer.

const InputBuffer = preload("res://scripts/common/input_buffer.gd")

var _input


func before_each() -> void:
	_input = InputSender.new(Input)
	InputMap.add_action(&"__test_buffer_action")


func after_each() -> void:
	_input.release_all()
	_input = null
	if InputMap.has_action(&"__test_buffer_action"):
		InputMap.erase_action(&"__test_buffer_action")


func test_no_press_is_not_buffered() -> void:
	var buffer := InputBuffer.new(&"__test_buffer_action")
	assert_false(buffer.is_buffered(120.0))
	assert_eq(buffer.last_press_ms(), -INF)


func test_press_is_buffered_within_window() -> void:
	var buffer := InputBuffer.new(&"__test_buffer_action")
	_input.action_down(&"__test_buffer_action")
	buffer.poll()

	var press_ms := buffer.last_press_ms()
	assert_gt(press_ms, -INF, "press timestamp should be recorded, not just consumed")
	assert_true(buffer.is_buffered(120.0, press_ms + 50.0),
		"a press 50 ms ago should still be inside a 120 ms buffer window")


func test_press_falls_outside_window_once_it_expires() -> void:
	var buffer := InputBuffer.new(&"__test_buffer_action")
	_input.action_down(&"__test_buffer_action")
	buffer.poll()

	var press_ms := buffer.last_press_ms()
	assert_false(buffer.is_buffered(120.0, press_ms + 200.0),
		"a press 200 ms ago must not still satisfy a 120 ms buffer window")


func test_consume_invalidates_the_buffered_press() -> void:
	var buffer := InputBuffer.new(&"__test_buffer_action")
	_input.action_down(&"__test_buffer_action")
	buffer.poll()
	buffer.consume()

	assert_eq(buffer.last_press_ms(), -INF)
	assert_false(buffer.is_buffered(120.0))
