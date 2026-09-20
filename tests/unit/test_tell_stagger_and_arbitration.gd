extends GutTest
## §5 shared rules 5 and 6: tells must stagger (no two onsets within 200 ms
## of each other), and with two open windows, an Answer resolves the
## soonest-landing one, tying-break on distance then instance id.

const PlayerScene := preload("res://scenes/player.tscn")
const TellEmitter = preload("res://scripts/combat/tell_emitter.gd")

var _player: CharacterBody2D
var _a
var _b
var _input


func before_each() -> void:
	_player = PlayerScene.instantiate()
	add_child_autofree(_player)
	_player.global_position = Vector2(0, 0)

	_a = TellEmitter.new()
	add_child_autofree(_a)
	_b = TellEmitter.new()
	add_child_autofree(_b)

	_input = InputSender.new(Input)
	await get_tree().physics_frame
	await get_tree().physics_frame


func after_each() -> void:
	_input.release_all()
	_input = null


func test_can_open_tell_true_with_nothing_open() -> void:
	assert_true(_player.combat.can_open_tell())


func test_cannot_open_within_200ms_of_another_open_tells_onset() -> void:
	_a.open_tell(600.0)
	var now: float = _a.onset_ms()
	assert_false(_player.combat.can_open_tell(now + 199.0))
	assert_true(_player.combat.can_open_tell(now + 200.0),
		"the boundary itself (exactly 200 ms) is not 'within' 200 ms")


func test_can_open_once_the_other_tell_has_closed() -> void:
	_a.open_tell(40.0)
	await wait_seconds(0.1)
	assert_false(_a.is_open())
	assert_true(_player.combat.can_open_tell())


func test_arbitration_picks_soonest_landing_not_first_opened() -> void:
	# A opens first but closes later; B opens second but closes sooner.
	_a.open_tell(600.0)
	await wait_seconds(0.25)  # comfortably past the 200 ms stagger gate
	_b.open_tell(100.0)  # B closes ~350ms from test start, well before A's ~600ms

	_input.action_down(&"answer")
	await get_tree().physics_frame
	_input.action_up(&"answer")

	assert_eq(_player.combat.last_answer_result, "success")
	assert_false(_b.is_open(), "the soonest-landing tell (B) should be the one resolved")
	assert_true(_a.is_open(), "the other open tell must take no penalty and stay open")


func test_second_open_tell_can_still_be_answered_after_the_first() -> void:
	_a.open_tell(600.0)
	await wait_seconds(0.25)
	_b.open_tell(100.0)

	_input.action_down(&"answer")
	await get_tree().physics_frame
	_input.action_up(&"answer")
	assert_false(_b.is_open())
	assert_true(_a.is_open())

	# Success recovery is 0 ms, so answering both in sequence is legal.
	var ticks := 0
	while _player.combat.answer_state != _player.combat.AnswerState.IDLE and ticks < 30:
		await get_tree().physics_frame
		ticks += 1

	_input.action_down(&"answer")
	await get_tree().physics_frame
	_input.action_up(&"answer")
	assert_eq(_player.combat.last_answer_result, "success")
	assert_false(_a.is_open(), "the second window should now also resolve, with no penalty for the delay")


func test_tie_breaks_on_nearest_enemy_by_distance() -> void:
	_a.global_position = Vector2(100, 0)  # farther
	_b.global_position = Vector2(10, 0)   # nearer
	_a.open_tell(300.0)
	await wait_seconds(0.21)  # past the 200 ms stagger gate, same close_ms as A
	_b.open_tell(90.0)

	# Both now close at (roughly) the same instant — force an exact tie to
	# isolate the tie-break rule rather than relying on timing precision.
	_b.lead_time_ms = _a.close_ms() - _b.onset_ms()

	_input.action_down(&"answer")
	await get_tree().physics_frame
	_input.action_up(&"answer")

	assert_false(_b.is_open(), "on a tie, the nearer emitter (B) should win")
	assert_true(_a.is_open())
