extends GutTest
## §4.2 Return — post-restoration, Strike becomes Return while holding a
## resolved note (checkpoint 2's PlayerCombat state). Startup/damage/stagger
## are load-bearing per §13's review-rigor table.

const PlayerScene := preload("res://scenes/player.tscn")
const ReedHuskScene := preload("res://scenes/enemies/reed_husk.tscn")

var _player: CharacterBody2D
var _reed
var _floor: StaticBody2D
var _input


func before_each() -> void:
	GameState.restoration_complete = false

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
	_player.set_physics_process(false)

	_reed = ReedHuskScene.instantiate()
	add_child_autofree(_reed)
	_reed.global_position = Vector2(30, 16)  # within the 40 px lunge reach — opens a tell fast
	_reed.set_player(_player)
	# Reed Husk's real HP (3, §5.1) is exactly RETURN_DAMAGE (STRIKE_DAMAGE x
	# 3) — a Return in these tests would be lethal, freeing this node via
	# EnemyBase._die() before the test can inspect its post-hit hp/_emitter.
	# Inflate it here so the target survives the hit under test; the real
	# 3 HP KO threshold isn't what this file is testing.
	_reed.hp = 1000

	_input = InputSender.new(Input)
	await get_tree().physics_frame
	await get_tree().physics_frame


func after_each() -> void:
	_input.release_all()
	_input = null
	GameState.restoration_complete = false


func _wait_for_state(node, target_state: int, max_ticks: int = 120) -> void:
	var ticks := 0
	while node.state != target_state and ticks < max_ticks:
		await get_tree().physics_frame
		ticks += 1


func _answer_the_tell() -> void:
	await _wait_for_state(_reed, _reed.State.TELLING)
	_input.action_down(&"answer")
	await get_tree().physics_frame
	_input.action_up(&"answer")


func _wait_for_strike_state(target_state: int, max_ticks: int = 20) -> int:
	var ticks := 0
	while _player.combat.strike_state != target_state and ticks < max_ticks:
		await get_tree().physics_frame
		ticks += 1
	return ticks


func test_strike_is_unchanged_pre_restoration_even_with_a_resolved_note() -> void:
	GameState.restoration_complete = false
	await _answer_the_tell()
	assert_true(_player.combat.has_resolved_note())

	_input.action_down(&"strike")
	await get_tree().physics_frame
	_input.action_up(&"strike")

	var ticks: int = await _wait_for_strike_state(_player.combat.StrikeState.ACTIVE)
	assert_almost_eq(ticks * (1000.0 / 60.0), PlayerCombat.STRIKE_STARTUP_MS, 20.0,
		"pre-restoration, Strike's startup must still be the normal 90 ms, not Return's 120 ms")


func test_strike_becomes_return_post_restoration_during_the_resolved_note_window() -> void:
	GameState.restoration_complete = true
	await _answer_the_tell()
	assert_true(_player.combat.has_resolved_note())
	var start_hp: int = _reed.hp

	_input.action_down(&"strike")
	await get_tree().physics_frame
	_input.action_up(&"strike")

	var ticks: int = await _wait_for_strike_state(_player.combat.StrikeState.ACTIVE)
	assert_almost_eq(ticks * (1000.0 / 60.0), PlayerCombat.RETURN_STARTUP_MS, 20.0,
		"Return's startup should be 120 ms, not Strike's 90 ms")

	await get_tree().physics_frame  # the ACTIVE tick that executes Return
	assert_eq(_reed.hp, start_hp - PlayerCombat.RETURN_DAMAGE,
		"Return should deal 3x Strike damage directly to the resolved enemy")
	assert_false(_player.combat.has_resolved_note(), "the note is spent the instant it's returned")


func test_return_staggers_the_enemy_for_1600ms() -> void:
	GameState.restoration_complete = true
	await _answer_the_tell()
	assert_eq(_reed.state, _reed.State.STAGGERED)

	_input.action_down(&"strike")
	await get_tree().physics_frame
	_input.action_up(&"strike")

	await _wait_for_strike_state(_player.combat.StrikeState.ACTIVE)
	await get_tree().physics_frame  # executes Return

	assert_almost_eq(_reed._emitter.stagger_ms, PlayerCombat.RETURN_STAGGER_MS, 40.0,
		"Return should set the enemy's stagger to 1600 ms")


func test_unspent_resolved_note_fades_after_1200ms_with_no_penalty() -> void:
	GameState.restoration_complete = true
	await _answer_the_tell()
	assert_true(_player.combat.has_resolved_note())

	var ticks := 0
	while _player.combat.has_resolved_note() and ticks < 90:
		await get_tree().physics_frame
		ticks += 1
	assert_almost_eq(ticks * (1000.0 / 60.0), PlayerCombat.RESOLVED_NOTE_HOLD_MS, 30.0,
		"§4.2: an unspent resolved note fades after its 1200 ms window, no penalty")
	assert_false(_player.combat.has_resolved_note())

	# The window has lapsed — a Strike press now must be a plain Strike
	# (normal 90 ms startup, 1 damage), not a Return.
	var start_hp: int = _reed.hp
	_input.action_down(&"strike")
	await get_tree().physics_frame
	_input.action_up(&"strike")

	var startup_ticks: int = await _wait_for_strike_state(_player.combat.StrikeState.ACTIVE)
	assert_almost_eq(startup_ticks * (1000.0 / 60.0), PlayerCombat.STRIKE_STARTUP_MS, 20.0,
		"a lapsed resolved note must not make the next Strike a Return")

	var recovery_ticks: int = await _wait_for_strike_state(_player.combat.StrikeState.RECOVERY)
	assert_eq(_reed.hp, start_hp - PlayerCombat.STRIKE_DAMAGE,
		"a plain Strike in reach deals normal Strike damage, not Return's 3x")
