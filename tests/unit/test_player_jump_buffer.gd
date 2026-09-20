extends GutTest
## Behavioural coverage for the §3.1 jump-buffer interaction: a buffered tap
## whose button is already released by the time ground contact registers must
## still reach the full 56 px apex, not collapse under the variable jump cut.
## Regression for the bug where a stale pre-landing `jump_held == false` was
## read as a mid-rise release on the very tick the buffered jump launched.

const PlayerScene := preload("res://scenes/player.tscn")

var _player: CharacterBody2D
var _floor: StaticBody2D
var _input

func before_each() -> void:
	_player = PlayerScene.instantiate()
	add_child_autofree(_player)

	_floor = StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(400, 40)
	shape.shape = rect
	_floor.add_child(shape)
	_floor.position = Vector2(0, 220)
	get_tree().root.add_child(_floor)
	autofree(_floor)

	# Start the player already resting on the floor (top surface at y = 200).
	# is_on_floor() only reflects reality from the second physics tick onward
	# (it's set by move_and_slide()), so buffering the jump right away and
	# tracking the tick it actually launches keeps this test independent of
	# fall-distance/timing arithmetic.
	_player.global_position = Vector2(0, 200)
	_player.velocity = Vector2(0, 0)

	_input = InputSender.new(Input)


func after_each() -> void:
	_input.release_all()
	_input = null


func test_buffered_tap_released_before_landing_reaches_full_apex() -> void:
	# Buffer a jump request without ever pressing the real "jump" action, so
	# jump_held stays false throughout — this reproduces a tap that was
	# released before ground contact registers.
	_player.jump_buffer_timer = _player.JUMP_BUFFER_TIME

	var launched := false
	var launch_y := 0.0
	var apex_y := 0.0
	var prev_y := _player.global_position.y
	for i in range(30):
		await get_tree().physics_frame
		if not launched and _player.velocity.y < -1.0:
			launched = true
			# Baseline is the position BEFORE this tick's motion was applied —
			# the tick that sets velocity also moves the body via
			# move_and_slide(), so reading position after the await already
			# includes part of the rise.
			launch_y = prev_y
			apex_y = _player.global_position.y
		elif launched:
			apex_y = min(apex_y, _player.global_position.y)
			if _player.velocity.y >= 0.0:
				break
		prev_y = _player.global_position.y

	assert_true(launched, "buffered jump should have launched on landing")
	assert_false(_player.jump_held, "sanity check: the jump action was never actually pressed")

	var measured_apex_height: float = launch_y - apex_y
	assert_almost_eq(measured_apex_height, _player.JUMP_APEX_HEIGHT, 6.0,
		"a tap released before landing must still reach the full §3.1 apex, not collapse early")


func test_holding_jump_into_the_rise_then_releasing_still_cuts_short() -> void:
	# Sanity check for the other half of the contract: a real release DURING
	# the rise (button held as the jump launches) must still cut the jump
	# short, so the fix above cannot regress into "the cut never fires".
	_player.jump_buffer_timer = _player.JUMP_BUFFER_TIME
	_input.action_down("jump")  # holding the button as the buffered jump launches

	var launched := false
	var launch_y := 0.0
	var apex_y := 0.0
	var ticks_since_launch := 0
	var prev_y := _player.global_position.y
	for i in range(30):
		if launched:
			ticks_since_launch += 1
			if ticks_since_launch == 3:
				_input.action_up("jump")  # release a few ticks into the rise, well before apex
		await get_tree().physics_frame
		if not launched and _player.velocity.y < -1.0:
			launched = true
			launch_y = prev_y
			apex_y = _player.global_position.y
		elif launched:
			apex_y = min(apex_y, _player.global_position.y)
			if _player.velocity.y >= 0.0:
				break
		prev_y = _player.global_position.y

	assert_true(launched, "jump should have launched on landing")
	var measured_apex_height: float = launch_y - apex_y
	assert_lt(measured_apex_height, _player.JUMP_APEX_HEIGHT - 10.0,
		"releasing Jump during the rise must still apply the variable jump cut")
