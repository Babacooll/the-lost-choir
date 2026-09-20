extends GutTest
## §4.1 Sustain — breath meter, ramp-in/out, availability gating, and the
## run-speed modifier. Load-bearing per §13's review-rigor table.
##
## PlayerSustain's timers are pure delta accumulation, not tied to the
## engine clock (unlike TellEmitter) — driving them with manual
## _physics_process(dt) calls is deterministic and avoids multi-second real
## waits for the 3000 ms breath meter.

const PlayerScene := preload("res://scenes/player.tscn")
const PlayerScript := preload("res://scripts/player/player.gd")

var _player: CharacterBody2D
var _sustain
var _floor: StaticBody2D
var _input


func before_each() -> void:
	GameState.restoration_complete = true

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
	_player.global_position = Vector2(0, 20)  # resting exactly on the floor's top surface

	_sustain = _player.sustain
	_sustain.set_physics_process(false)

	_input = InputSender.new(Input)
	await get_tree().physics_frame
	await get_tree().physics_frame


func after_each() -> void:
	_input.release_all()
	_input = null
	GameState.restoration_complete = false


## Steps in small (1 ms) increments rather than one big call — the state
## machine only evaluates one state's transition per _physics_process call,
## same as the real engine's per-frame invocation, so a single huge-delta
## call would consume an entire ramp window on the transition alone instead
## of accumulating hold time within the newly-entered state.
func _tick(ms: float) -> void:
	var steps := int(round(ms))
	for i in range(steps):
		_sustain._physics_process(0.001)


func test_unavailable_before_restoration() -> void:
	GameState.restoration_complete = false
	_input.action_down(&"sustain")
	_tick(500.0)
	assert_eq(_sustain.state, _sustain.State.IDLE, "Sustain must not activate before restoration (§4.1)")
	assert_eq(_sustain.breath_ms, PlayerSustain.BREATH_MAX_MS, "breath should not drain while unavailable")


func test_ramp_in_takes_180ms_before_world_effects_engage() -> void:
	var engaged := [false]
	_sustain.world_effect_engaged.connect(func(): engaged[0] = true)

	_input.action_down(&"sustain")
	_tick(179.0)
	assert_false(engaged[0], "world effects must not engage a moment before the 180 ms ramp-in")
	assert_false(_sustain.world_effects_active())

	_tick(2.0)
	assert_true(engaged[0], "world effects should engage once the 180 ms ramp-in completes")
	assert_true(_sustain.world_effects_active())


func test_a_tap_shorter_than_ramp_in_never_engages() -> void:
	var engaged := [false]
	_sustain.world_effect_engaged.connect(func(): engaged[0] = true)

	_input.action_down(&"sustain")
	_tick(100.0)
	_input.action_up(&"sustain")
	_tick(50.0)
	assert_false(engaged[0], "a tap shorter than ramp-in must never engage world effects (anti-flicker)")
	assert_eq(_sustain.state, _sustain.State.IDLE)


func test_ramp_out_keeps_world_effects_active_for_120ms_after_release() -> void:
	_input.action_down(&"sustain")
	_tick(200.0)  # past ramp-in, now ACTIVE
	assert_true(_sustain.world_effects_active())

	_input.action_up(&"sustain")
	_tick(119.0)
	assert_true(_sustain.world_effects_active(),
		"world effects should still be active a moment before the 120 ms ramp-out completes")

	_tick(2.0)
	assert_false(_sustain.world_effects_active(), "world effects should release once the 120 ms ramp-out completes")


func test_breath_drains_while_held_and_forces_ramp_out_when_exhausted() -> void:
	_input.action_down(&"sustain")
	_tick(200.0)  # ACTIVE
	assert_true(_sustain.world_effects_active())

	_tick(2800.0)  # 3000 ms total held -> breath exhausted
	assert_almost_eq(_sustain.breath_ms, 0.0, 1.0)

	# Exhaustion is treated exactly like a release — it still gets the same
	# 120 ms ramp-out grace, not an instant cutoff — so world effects are
	# still active for a moment, then release once that grace elapses too.
	_tick(1.0)
	assert_eq(_sustain.state, _sustain.State.RAMPING_OUT,
		"breath exhausting mid-traversal must force the ramp-out even with input still held (§4.1)")
	assert_true(_sustain.world_effects_active(), "the ramp-out grace still applies to a forced release")

	_tick(121.0)
	assert_false(_sustain.world_effects_active(), "world effects release once the forced ramp-out's grace elapses")


func test_refill_waits_500ms_after_release_then_refills_at_1_5x_over_2000ms() -> void:
	_input.action_down(&"sustain")
	_tick(3000.0)  # drain to empty
	assert_almost_eq(_sustain.breath_ms, 0.0, 1.0)

	_input.action_up(&"sustain")
	_tick(499.0)
	assert_almost_eq(_sustain.breath_ms, 0.0, 1.0, "breath must not refill before the 500 ms refill delay elapses")

	_tick(2.0)
	assert_gt(_sustain.breath_ms, 0.0, "refill should begin once the 500 ms delay elapses")

	_tick(2000.0)
	assert_almost_eq(_sustain.breath_ms, PlayerSustain.BREATH_MAX_MS, 5.0,
		"a full refill from empty should take 2000 ms at 1.5x the drain rate")


func test_run_speed_is_0_85x_while_world_effects_are_active() -> void:
	_player.global_position = Vector2(200, 20)
	_input.action_down(&"sustain")
	_tick(200.0)  # ACTIVE, frozen there since sustain's own processing is manual

	_input.action_down(&"move_right")
	for i in range(30):
		await get_tree().physics_frame
	assert_almost_eq(_player.velocity.x, PlayerScript.RUN_MAX_SPEED * PlayerSustain.RUN_SPEED_MULT, 5.0,
		"run speed should be capped at 0.85x while sustaining (§4.1)")
	_input.action_up(&"move_right")


func test_jump_velocity_is_unaffected_by_sustaining() -> void:
	_input.action_down(&"sustain")
	_tick(200.0)  # ACTIVE

	_input.action_down(&"jump")
	var ticks := 0
	while _player.velocity.y >= 0.0 and ticks < 10:
		await get_tree().physics_frame
		ticks += 1
	assert_almost_eq(_player.velocity.y, -PlayerScript.JUMP_VELOCITY, 1.0,
		"§4.1: jump is unaffected by Sustain")
	_input.action_up(&"jump")
