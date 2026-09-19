extends GutTest
## Sanity-checks the player controller's derived kinematics against the
## design contract in docs/design/vertical-slice.md §3.1. Checkpoint 1 scope:
## prove the constants match the contract, not full gameplay simulation.

const PlayerScene := preload("res://scenes/player.tscn")

var _player: CharacterBody2D

func before_each() -> void:
	_player = PlayerScene.instantiate()
	add_child_autofree(_player)


func test_run_max_speed_matches_contract() -> void:
	assert_eq(_player.RUN_MAX_SPEED, 170.0, "§3.1 run max speed is 170 px/s")


func test_terminal_fall_speed_matches_contract() -> void:
	assert_eq(_player.TERMINAL_FALL_SPEED, 520.0, "§3.1 terminal fall speed is 520 px/s")


func test_coyote_time_matches_contract() -> void:
	assert_eq(_player.COYOTE_TIME, 0.10, "§3.1 coyote time is 100 ms")


func test_jump_buffer_matches_contract() -> void:
	assert_eq(_player.JUMP_BUFFER_TIME, 0.12, "§3.1 jump input buffer is 120 ms")


func test_fall_gravity_is_1_7x_rise_gravity() -> void:
	assert_almost_eq(
		_player.FALL_GRAVITY,
		_player.RISE_GRAVITY * 1.7,
		0.001,
		"§3.1 fall gravity multiplier is 1.7x rise gravity"
	)


func test_jump_reaches_apex_height_in_time_to_apex() -> void:
	# apex = 0.5 * v0 * t, derived from the §3.1 apex-height/time-to-apex pair.
	var computed_apex: float = 0.5 * _player.JUMP_VELOCITY * _player.TIME_TO_APEX
	assert_almost_eq(computed_apex, 56.0, 0.01, "§3.1 jump apex height is 56 px at 320 ms")


func test_corner_correction_distance_matches_contract() -> void:
	assert_eq(_player.CORNER_CORRECTION_PX, 4.0, "§3.1 ceiling-corner nudge is 4 px")
