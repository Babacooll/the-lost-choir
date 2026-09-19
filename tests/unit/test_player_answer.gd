extends GutTest
## Behavioural coverage for Answer (§3.3) — the tell/response verb — against
## the scripted dummy TellEmitter. Priority per the issue brief: the 120 ms
## pre-window buffer ("a press up to 120 ms before tell onset still counts")
## is the fairness rule that must be exactly right, not just close.

const PlayerScene := preload("res://scenes/player.tscn")
const TellEmitter = preload("res://scripts/combat/tell_emitter.gd")

var _player: CharacterBody2D
var _emitter
var _input


func before_each() -> void:
	_player = PlayerScene.instantiate()
	add_child_autofree(_player)
	_player.global_position = Vector2(0, 0)

	_emitter = TellEmitter.new()
	add_child_autofree(_emitter)
	# TellEmitter self-registers with the player via a deferred call (same
	# pattern as the debug overlay's player lookup) — don't also register it
	# explicitly here, or tell_opened/tell_missed fire twice per event.

	_input = InputSender.new(Input)
	await get_tree().physics_frame
	await get_tree().physics_frame


func after_each() -> void:
	_input.release_all()
	_input = null


func test_answer_succeeds_when_pressed_inside_open_window() -> void:
	var combat = _player.combat
	_emitter.open_tell(300.0)
	await wait_seconds(0.08)  # comfortably inside the 300 ms window

	_input.action_down(&"answer")
	await get_tree().physics_frame

	assert_eq(combat.last_answer_result, "success")
	assert_false(_emitter.is_open(), "a resolved tell should no longer be open")
	assert_true(combat.has_resolved_note())


func test_answer_succeeds_via_pre_window_buffer_before_onset() -> void:
	# The core fairness rule: a press up to 120 ms BEFORE the tell even opens
	# still counts once it does.
	var combat = _player.combat
	_input.action_down(&"answer")
	await get_tree().physics_frame
	var press_ms: float = combat.last_answer_press_ms

	await wait_seconds(0.06)  # well inside the 120 ms pre-window buffer
	_emitter.open_tell(300.0)
	await get_tree().physics_frame

	assert_eq(combat.last_answer_result, "success",
		"a press ~60 ms before onset is within the 120 ms pre-window buffer and must resolve")
	assert_almost_eq(combat.last_tell_onset_ms - press_ms, 60.0, 25.0)


func test_answer_whiffs_when_pressed_too_early_beyond_the_buffer() -> void:
	var combat = _player.combat
	_input.action_down(&"answer")
	await get_tree().physics_frame

	await wait_seconds(0.2)  # 200 ms > 120 ms buffer — too early to count
	_emitter.open_tell(300.0)

	# The active pose (180 ms) has already elapsed since the press by the
	# time the (too-late) window opens, so the outcome should already be a
	# settled whiff; give it a couple frames to land in RECOVERY_WHIFF.
	for i in range(5):
		await get_tree().physics_frame

	assert_eq(combat.last_answer_result, "whiff",
		"a press more than 120 ms before onset must not count")
	assert_eq(combat.answer_state, combat.AnswerState.RECOVERY_WHIFF)


func test_answer_recovery_whiff_lasts_220ms() -> void:
	var combat = _player.combat
	_input.action_down(&"answer")  # no tell registered/open at all -> guaranteed whiff
	await get_tree().physics_frame

	var ticks := 0
	while combat.answer_state != combat.AnswerState.RECOVERY_WHIFF and ticks < 30:
		await get_tree().physics_frame
		ticks += 1
	assert_eq(combat.answer_state, combat.AnswerState.RECOVERY_WHIFF)

	var recovery_ticks := 0
	while combat.answer_state == combat.AnswerState.RECOVERY_WHIFF and recovery_ticks < 30:
		await get_tree().physics_frame
		recovery_ticks += 1
	var recovery_ms: float = recovery_ticks * (1000.0 / 60.0)
	assert_almost_eq(recovery_ms, combat.ANSWER_WHIFF_RECOVERY_MS, 20.0)
	assert_eq(combat.answer_state, combat.AnswerState.IDLE)


func test_unanswered_tell_damages_the_player_on_close() -> void:
	var start_hp: int = _player.hp
	_emitter.open_tell(40.0)  # short lead time; never press Answer

	await wait_seconds(0.12)

	assert_eq(_player.hp, start_hp - 1)
	assert_true(_player.hitstun_timer_ms > 0.0)
	assert_true(_player.invuln_timer_ms > 0.0)
	assert_ne(_player.knockback_velocity_x, 0.0)


func test_invulnerability_blocks_a_second_hit_immediately_after() -> void:
	var start_hp: int = _player.hp
	_player.take_hit(1, Vector2.LEFT, 180.0, 400.0, 600.0)
	assert_eq(_player.hp, start_hp - 1)

	_player.take_hit(1, Vector2.LEFT, 180.0, 400.0, 600.0)
	assert_eq(_player.hp, start_hp - 1, "a second hit inside the invulnerability window must be ignored")


func test_resolved_note_holds_for_1200ms_then_expires() -> void:
	var combat = _player.combat
	_emitter.open_tell(300.0)
	await get_tree().physics_frame
	_input.action_down(&"answer")
	await get_tree().physics_frame
	assert_true(combat.has_resolved_note())

	await wait_seconds(1.0)
	assert_true(combat.has_resolved_note(), "resolved note should still be held before 1200 ms elapses")

	await wait_seconds(0.35)
	assert_false(combat.has_resolved_note(), "resolved note should have expired after 1200 ms")
