extends GutTest
## §5.1 Reed Husk behavioural coverage.

const PlayerScene := preload("res://scenes/player.tscn")
const ReedHuskScene := preload("res://scenes/enemies/reed_husk.tscn")

var _player: CharacterBody2D
var _reed
var _floor: StaticBody2D
var _input


func before_each() -> void:
	_floor = StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	var floor_rect := RectangleShape2D.new()
	floor_rect.size = Vector2(2000, 40)
	floor_shape.shape = floor_rect
	_floor.add_child(floor_shape)
	_floor.position = Vector2(0, 40)
	get_tree().root.add_child(_floor)
	autofree(_floor)

	_player = PlayerScene.instantiate()
	add_child_autofree(_player)
	_player.global_position = Vector2(0, 20)

	_reed = ReedHuskScene.instantiate()
	add_child_autofree(_reed)
	_reed.global_position = Vector2(300, 16)
	# Wire the player directly rather than relying on the deferred
	# group-lookup autodiscovery — with tests churning through Player
	# instances rapidly, more than one can transiently be in the "player"
	# group at once, and group order isn't a reliable way to pick this
	# test's own instance.
	_reed.set_player(_player)

	_input = InputSender.new(Input)
	await get_tree().physics_frame
	await get_tree().physics_frame


func after_each() -> void:
	_input.release_all()
	_input = null


## Polls rather than assuming a fixed tick count is enough — state-machine
## transitions here depend on a deferred player lookup resolving, which this
## suite has seen take longer than a handful of ticks under CI load.
func _wait_for_state(node, target_state: int, max_ticks: int = 120) -> void:
	var ticks := 0
	while node.state != target_state and ticks < max_ticks:
		await get_tree().physics_frame
		ticks += 1


func test_stays_idle_outside_aggro_range() -> void:
	for i in range(10):
		await get_tree().physics_frame
	assert_eq(_reed.state, _reed.State.IDLE, "300 px is outside the 220 px aggro range")


func test_approaches_and_walks_toward_player_once_aggro() -> void:
	_reed.global_position = Vector2(200, 16)  # 200 px away, inside the 220 px aggro range
	await _wait_for_state(_reed, _reed.State.APPROACH)
	assert_eq(_reed.state, _reed.State.APPROACH)

	var before_x: float = _reed.global_position.x
	for i in range(10):
		await get_tree().physics_frame
	assert_lt(_reed.global_position.x, before_x, "should walk toward the player (to its left)")


func test_opens_tell_once_within_lunge_reach() -> void:
	_reed.global_position = Vector2(30, 16)  # within the 40 px lunge reach
	await _wait_for_state(_reed, _reed.State.TELLING)
	assert_eq(_reed.state, _reed.State.TELLING)


func test_unanswered_tell_lunges_and_damages_player_in_reach() -> void:
	_reed.global_position = Vector2(30, 16)
	var start_hp: int = _player.hp
	await _wait_for_state(_reed, _reed.State.TELLING)
	assert_eq(_reed.state, _reed.State.TELLING)

	# Let the 520 ms tell close unanswered.
	await _wait_for_state(_reed, _reed.State.RECOVERY)

	assert_eq(_reed.state, _reed.State.RECOVERY)
	assert_eq(_player.hp, start_hp - 1, "an unanswered tell in reach should lunge and damage the player")


func test_answered_tell_staggers_instead_of_damaging() -> void:
	_reed.global_position = Vector2(30, 16)
	var start_hp: int = _player.hp
	await _wait_for_state(_reed, _reed.State.TELLING)
	assert_eq(_reed.state, _reed.State.TELLING)

	_input.action_down(&"answer")
	await get_tree().physics_frame
	_input.action_up(&"answer")

	assert_eq(_player.combat.last_answer_result, "success")
	assert_eq(_player.hp, start_hp, "a successful Answer must not damage the player")
	assert_eq(_reed.state, _reed.State.STAGGERED)


func test_recovery_lasts_700ms_then_returns_to_approach() -> void:
	_reed.global_position = Vector2(30, 16)
	await _wait_for_state(_reed, _reed.State.TELLING)
	await _wait_for_state(_reed, _reed.State.RECOVERY)  # tell closes unanswered
	assert_eq(_reed.state, _reed.State.RECOVERY)

	var ticks := 0
	while _reed.state == _reed.State.RECOVERY and ticks < 90:
		await get_tree().physics_frame
		ticks += 1
	var recovery_ms: float = ticks * (1000.0 / 60.0)
	assert_almost_eq(recovery_ms, _reed.POST_ATTACK_RECOVERY_MS, 25.0)
	assert_eq(_reed.state, _reed.State.APPROACH)


func test_takes_three_strikes_to_die() -> void:
	_reed.take_strike(1)
	assert_true(is_instance_valid(_reed))
	_reed.take_strike(1)
	assert_true(is_instance_valid(_reed))
	_reed.take_strike(1)
	await get_tree().physics_frame
	await get_tree().process_frame
	assert_false(is_instance_valid(_reed), "3 damage against 3 HP should kill it")
