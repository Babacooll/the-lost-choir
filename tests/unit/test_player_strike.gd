extends GutTest
## Behavioural coverage for Strike (§3.2): startup 90 ms, active 70 ms,
## recovery 140 ms, one hit per activation, cancellable into Jump only from
## the first recovery frame, not during startup.

const PlayerScene := preload("res://scenes/player.tscn")

class MockTarget:
	extends StaticBody2D
	var hits: Array = []
	func take_strike(damage: int) -> void:
		hits.append(damage)

var _player: CharacterBody2D
var _target: MockTarget
var _input


func before_each() -> void:
	_player = PlayerScene.instantiate()
	add_child_autofree(_player)
	_player.global_position = Vector2(0, 0)

	_target = MockTarget.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 40)
	shape.shape = rect
	_target.add_child(shape)
	_target.position = Vector2(20, -20)  # inside the strike hitbox's reach, facing right
	get_tree().root.add_child(_target)
	autofree(_target)

	_input = InputSender.new(Input)
	await get_tree().physics_frame
	await get_tree().physics_frame
	print("DIAG3 target inside_tree=%s global_pos=%s layer=%d mask=%d children=%d shape_disabled=%s" % [
		_target.is_inside_tree(), _target.global_position, _target.collision_layer, _target.collision_mask,
		_target.get_child_count(), (_target.get_child(0) as CollisionShape2D).disabled,
	])


func after_each() -> void:
	_input.release_all()
	_input = null


func _press_strike() -> void:
	_input.action_down(&"strike")
	await get_tree().physics_frame
	_input.action_up(&"strike")


func test_strike_phase_durations_match_contract() -> void:
	var combat = _player.combat
	await _press_strike()

	# Startup: should still be STARTUP for close to 90 ms, then ACTIVE.
	var startup_ticks := 0
	while combat.strike_state == combat.StrikeState.STARTUP and startup_ticks < 30:
		await get_tree().physics_frame
		startup_ticks += 1
	var startup_ms: float = startup_ticks * (1000.0 / 60.0)
	assert_almost_eq(startup_ms, combat.STRIKE_STARTUP_MS, 20.0, "startup phase should last ~90 ms")
	assert_eq(combat.strike_state, combat.StrikeState.ACTIVE)

	var active_ticks := 0
	while combat.strike_state == combat.StrikeState.ACTIVE and active_ticks < 30:
		await get_tree().physics_frame
		active_ticks += 1
	var active_ms: float = active_ticks * (1000.0 / 60.0)
	assert_almost_eq(active_ms, combat.STRIKE_ACTIVE_MS, 20.0, "active phase should last ~70 ms")
	assert_eq(combat.strike_state, combat.StrikeState.RECOVERY)

	var recovery_ticks := 0
	while combat.strike_state == combat.StrikeState.RECOVERY and recovery_ticks < 30:
		await get_tree().physics_frame
		recovery_ticks += 1
	var recovery_ms: float = recovery_ticks * (1000.0 / 60.0)
	assert_almost_eq(recovery_ms, combat.STRIKE_RECOVERY_MS, 20.0, "recovery phase should last ~140 ms")
	assert_eq(combat.strike_state, combat.StrikeState.IDLE)


func test_strike_deals_damage_exactly_once_per_activation() -> void:
	var combat = _player.combat
	# Freeze the player's own movement/gravity — Combat is a separate node
	# and keeps ticking independently — so it doesn't fall away (no floor in
	# this fixture) from the fixed-position target before Strike activates.
	_player.set_physics_process(false)
	await _press_strike()

	for i in range(40):
		await get_tree().physics_frame
		if combat.strike_state == combat.StrikeState.IDLE and i > 5:
			break

	assert_eq(_target.hits.size(), 1, "one Strike activation should hit exactly once, not once per overlapping frame")
	assert_eq(_target.hits[0], combat.STRIKE_DAMAGE)


func test_jump_locked_during_startup_and_active_unlocked_from_recovery() -> void:
	var combat = _player.combat
	await _press_strike()
	await get_tree().physics_frame

	assert_eq(combat.strike_state, combat.StrikeState.STARTUP)
	assert_true(combat.is_jump_locked(), "§3.2: not cancellable during startup")

	while combat.strike_state == combat.StrikeState.STARTUP:
		await get_tree().physics_frame
	assert_eq(combat.strike_state, combat.StrikeState.ACTIVE)
	assert_true(combat.is_jump_locked(), "active is a committed hit, not a cancel window")

	while combat.strike_state == combat.StrikeState.ACTIVE:
		await get_tree().physics_frame
	assert_eq(combat.strike_state, combat.StrikeState.RECOVERY)
	assert_false(combat.is_jump_locked(), "§3.2: cancellable into Jump from the first recovery frame")


func test_buffered_jump_pressed_during_active_fires_once_recovery_unlocks_it() -> void:
	# A Jump press while Strike locks it out (startup/active) must not be
	# silently swallowed — it stays buffered (the ordinary 120 ms window
	# from checkpoint 1) and fires the instant recovery unlocks it. Pressed
	# during ACTIVE (max 70 ms before recovery starts), comfortably inside
	# the 120 ms buffer — a press at the very start of STARTUP would not
	# still be buffered 160 ms later when recovery begins, which is just the
	# ordinary buffer window expiring, not a bug.
	_player.global_position = Vector2(0, 200)
	var floor := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	var floor_rect := RectangleShape2D.new()
	floor_rect.size = Vector2(400, 40)
	floor_shape.shape = floor_rect
	floor.add_child(floor_shape)
	floor.position = Vector2(0, 220)
	get_tree().root.add_child(floor)
	autofree(floor)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var combat = _player.combat
	await _press_strike()

	while combat.strike_state != combat.StrikeState.ACTIVE:
		await get_tree().physics_frame

	_input.action_down(&"jump")
	await get_tree().physics_frame
	assert_true(_player.velocity.y >= 0.0, "jump must not launch while Strike still locks it out (active)")

	while combat.strike_state != combat.StrikeState.RECOVERY:
		await get_tree().physics_frame

	await get_tree().physics_frame
	assert_lt(_player.velocity.y, 0.0, "the buffered jump should fire once recovery unlocks it")
