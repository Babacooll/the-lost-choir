extends GutTest
## §7 restoration encounter (R6) — offer/response timing, adaptive shortening
## and extension, narrative delivery mechanics, and the "never a boss fight"
## guarantees. The phrase timing (700 ms lead, 1100 ms spacing, 1400 ms
## silence, adaptive-shortening thresholds, 5-note completion) is load-bearing
## per §13's review-rigor table, the same tier as §5 tell timing.

const PlayerScene := preload("res://scenes/player.tscn")
const RestorationEncounterScript := preload("res://scripts/encounters/restoration_encounter.gd")
const VerseBearerScene := preload("res://scenes/encounters/verse_bearer.tscn")
const DoorScript := preload("res://scripts/levels/door.gd")

var _player: CharacterBody2D
var _encounter
var _input


func before_each() -> void:
	GameState.restoration_complete = false

	_player = PlayerScene.instantiate()
	add_child_autofree(_player)
	_player.global_position = Vector2(0, 20)

	_encounter = RestorationEncounterScript.new()
	add_child_autofree(_encounter)
	_encounter.global_position = Vector2(100, 20)
	_encounter.set_player(_player)

	_input = InputSender.new(Input)
	await get_tree().physics_frame
	await get_tree().physics_frame


func after_each() -> void:
	_input.release_all()
	_input = null
	GameState.restoration_complete = false


func _press_answer() -> void:
	_input.action_down(&"answer")
	await get_tree().physics_frame
	_input.action_up(&"answer")


func _wait_until(predicate: Callable, max_ticks: int = 240) -> void:
	var ticks := 0
	while not predicate.call() and ticks < max_ticks:
		await get_tree().physics_frame
		ticks += 1


func _wait_ticks(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame


## Answers every note of the currently-in-progress attempt in turn, matching
## real note onsets rather than assuming fixed timing.
func _complete_current_attempt() -> void:
	var target_length: int = _encounter._phrase_length
	for i in range(target_length):
		await _wait_until(func(): return _encounter._emitter.is_open())
		await _press_answer()


## Lets the currently-open note miss (never pressing Answer) and waits
## through the resulting silence back to the next re-offer.
func _fail_full_attempt(max_ticks: int = 240) -> void:
	await _wait_until(func(): return _encounter.state == _encounter.State.SILENCE, max_ticks)
	await _wait_until(func(): return _encounter.state == _encounter.State.OFFERING, max_ticks)


func test_first_note_opens_immediately_with_700ms_lead() -> void:
	assert_true(_encounter._emitter.is_open())
	assert_eq(_encounter._emitter.lead_time_ms, 700.0, "§7.1: each note is a tell with a 700 ms lead")


func test_notes_spaced_1100ms_apart_when_answered_promptly() -> void:
	var onsets: Array = []
	_encounter._emitter.tell_opened.connect(func(onset_ms, _close_ms): onsets.append(onset_ms))
	var note0_onset: float = _encounter._emitter.onset_ms()

	await _press_answer()
	await _wait_until(func(): return onsets.size() >= 1)
	assert_almost_eq(onsets[0] - note0_onset, 1100.0, 50.0,
		"note 2's onset should land 1100 ms after note 1's, however early note 1 was answered")

	await _press_answer()
	await _wait_until(func(): return onsets.size() >= 2)
	assert_almost_eq(onsets[1] - onsets[0], 1100.0, 50.0,
		"the 1100 ms spacing is load-bearing and must not move (§7 narrative delivery)")


func test_missed_note_triggers_1400ms_silence_then_reoffers_from_start() -> void:
	# A plain local captured by a lambda is captured BY VALUE in GDScript —
	# assigning to it inside the callback would not be visible out here, so
	# the mutable box is a one-element Array instead (captured by reference).
	var miss_ms := [-1.0]
	_encounter._emitter.tell_missed.connect(func(): miss_ms[0] = Time.get_ticks_msec())

	await _wait_until(func(): return miss_ms[0] > 0.0, 120)
	assert_true(miss_ms[0] > 0.0, "an unanswered note should miss once its 700 ms lead elapses")
	assert_eq(_encounter.state, _encounter.State.SILENCE)

	await _wait_until(
		func(): return _encounter.state == _encounter.State.OFFERING and _encounter._emitter.is_open(), 180
	)
	var reoffer_onset: float = _encounter._emitter.onset_ms()
	assert_almost_eq(reoffer_onset - miss_ms[0], 1400.0, 60.0,
		"the bearer should re-offer 1400 ms after a missed note, carrying no sound in between")
	assert_eq(_encounter._note_index, 0, "a re-offer starts the phrase over from the first note")


func test_two_consecutive_failures_shorten_the_phrase_to_2_notes() -> void:
	assert_eq(_encounter._phrase_length, 3, "the phrase starts at 3 notes")

	await _fail_full_attempt()
	assert_eq(_encounter._consecutive_failures, 1)
	assert_eq(_encounter._phrase_length, 3, "a single failure must not shorten the phrase yet")

	await _fail_full_attempt()
	assert_eq(_encounter._consecutive_failures, 2)
	assert_eq(_encounter._phrase_length, 2, "two consecutive failed attempts should drop the phrase to 2 notes")


func test_four_consecutive_failures_shorten_the_phrase_to_1_note_and_no_further() -> void:
	for i in range(4):
		await _fail_full_attempt()
	assert_eq(_encounter._consecutive_failures, 4)
	assert_eq(_encounter._phrase_length, 1, "four consecutive failed attempts should drop the phrase to 1 note")

	await _fail_full_attempt()
	assert_eq(_encounter._phrase_length, 1, "the phrase must never drop below 1 note")


func test_completed_attempt_resets_the_failure_streak() -> void:
	await _fail_full_attempt()
	await _fail_full_attempt()
	assert_eq(_encounter._phrase_length, 2, "two failures should have shortened the phrase")

	await _complete_current_attempt()
	assert_eq(_encounter._consecutive_failures, 0, "a completed phrase should reset the consecutive-failure count")
	assert_eq(_encounter._phrase_length, 3, "completing a 2-note phrase should climb exactly one rung, to 3")


func test_two_failures_from_an_extended_phrase_drop_relative_to_current_not_to_base() -> void:
	# PR #15's ruling: "the thresholds shorten from wherever the player
	# currently is — a player at 4 notes who fails twice drops to 2." A
	# single failure along the way must hold, not snap back to base 3.
	await _complete_current_attempt()  # 3 -> 4
	assert_eq(_encounter._phrase_length, 4)

	await _fail_full_attempt()
	assert_eq(_encounter._phrase_length, 4, "a single failure must hold the current length, not snap to base")

	await _fail_full_attempt()
	assert_eq(_encounter._phrase_length, 2, "two consecutive failures from 4 notes should drop to 2, per the ruling")


func test_completing_a_1_note_phrase_climbs_to_2_not_back_to_base() -> void:
	for i in range(4):
		await _fail_full_attempt()
	assert_eq(_encounter._phrase_length, 1, "four consecutive failures should floor the phrase at 1 note")

	await _complete_current_attempt()
	assert_eq(_encounter._phrase_length, 2,
		"completing a 1-note phrase should climb exactly one rung, to 2 — not back to base 3 (§7.5 as amended)")


func test_completing_attempts_extends_the_phrase_then_restores_on_5() -> void:
	assert_eq(_encounter._phrase_length, 3)

	await _complete_current_attempt()  # attempt 1: 3 notes
	assert_eq(_encounter._phrase_length, 4, "attempt 2 should be 4 notes")
	assert_false(GameState.restoration_complete)

	await _complete_current_attempt()  # attempt 2: 4 notes
	assert_eq(_encounter._phrase_length, 5, "attempt 3 should be 5 notes")
	assert_false(GameState.restoration_complete)

	await _complete_current_attempt()  # attempt 3: 5 notes
	assert_true(GameState.restoration_complete, "completing 5 consecutive notes should restore the Verse")
	assert_eq(_encounter.state, _encounter.State.RESTORED)


## §3.2 rule 4: full legibility is a minimum of 1800 ms measured from the end
## of the 200 ms fade-in — a 2000 ms floor from the line's onset — not the
## 1800-ms-from-onset window the pre-fix implementation held it for.
func test_narrative_line_holds_full_legibility_for_1800ms_after_fade_in() -> void:
	await _wait_until(func(): return _encounter._emitter.is_open())
	await _press_answer()
	await _wait_until(func(): return _encounter.narrative_lines_delivered() >= 1, 120)
	assert_true(_encounter._line_visible, "the first line should show at the first gap")

	# Keep answering every note that opens so a release attempt (a gap) keeps
	# firing roughly every 1100 ms — close enough to the 2000 ms gate that an
	# early gate would show up here as a premature swap to line 2.
	var ticks := 0
	while _encounter._line_elapsed_ms < 1900.0 and ticks < 200:
		if _encounter._emitter.is_open():
			await _press_answer()
		else:
			await get_tree().physics_frame
		ticks += 1

	assert_eq(_encounter.narrative_lines_delivered(), 1,
		"line 1 must still be the only line delivered just short of its 1800 ms full-legibility floor")
	assert_true(_encounter._line_visible, "line 1 must not hide before its full-legibility floor elapses")


## §3.2 rule 4: a line clears when the next line begins, or after its 1800 ms
## floor, whichever is later — on a clean run there is no blank interval
## between two consecutive lines, unlike the pre-fix implementation's ~400 ms
## dead beat between a line's 1800 ms hold expiring and the next gap arriving.
func test_no_blank_interval_between_consecutive_narrative_lines() -> void:
	await _wait_until(func(): return _encounter._emitter.is_open())
	await _press_answer()
	await _wait_until(func(): return _encounter.narrative_lines_delivered() >= 1, 120)
	assert_true(_encounter._line_visible, "the first line should show at the first gap")

	var observed_blank := false
	var ticks := 0
	while _encounter.narrative_lines_delivered() < 2 and ticks < 260:
		if not _encounter._line_visible:
			observed_blank = true
		if _encounter._emitter.is_open():
			await _press_answer()
		else:
			await get_tree().physics_frame
		ticks += 1

	assert_eq(_encounter.narrative_lines_delivered(), 2,
		"line 2 should have released by now on a clean run of continuous answers")
	assert_false(observed_blank,
		"the line must never go invisible between line 1 clearing and line 2 beginning")


func test_narrative_lines_match_the_approved_restoration_narrative() -> void:
	assert_eq(_encounter.NARRATIVE_LINES, PackedStringArray([
		"I was the ground note. Everything above was tuned to me.",
		"I drifted. Slowly. For years. And they followed me down.",
		"When I finally heard myself, I could not take it back.",
		"This is the pitch I have left. Answer it anyway.",
	]), "docs/narrative/vertical-slice-narrative.md §3.1 is the approved source; the bearer's words must match it verbatim")


func test_narrative_line_fades_in_over_200ms_at_gap_onset() -> void:
	# The shared _encounter from before_each is a bare RestorationEncounterScript.new()
	# (a plain Node2D) with no NarrativeLayer/Label child, so its _label is null and
	# any assertion on _label would silently no-op the whole test body. This test
	# needs the real label, so it instantiates the actual scene instead.
	var encounter = VerseBearerScene.instantiate()
	add_child_autofree(encounter)
	encounter.global_position = Vector2(100, 20)
	encounter.set_player(_player)
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_not_null(encounter._label, "the scene-instantiated bearer must resolve a real NarrativeLayer/Label")
	if encounter._label == null:
		return  # nothing further to check without a label to observe

	await _wait_until(func(): return encounter._emitter.is_open())
	await _press_answer()
	await _wait_until(func(): return encounter.narrative_lines_delivered() >= 1, 120)
	assert_true(encounter._line_visible, "the first line should show at the first gap")
	# _tick_narrative only runs on the next physics step after _show_line, so the
	# earliest observable alpha is ~1 tick into the 200 ms fade-in (16.67/200 ≈
	# 0.083), not exactly 0.0 — assert a near-zero bound instead of exact equality.
	assert_lt(encounter._label.modulate.a, 0.2, "a line should be close to transparent at gap onset (§3.2.4)")

	await _wait_ticks(6)  # ~100 ms into the 200 ms fade-in
	var mid_alpha: float = encounter._label.modulate.a
	assert_true(mid_alpha > 0.0 and mid_alpha < 1.0,
		"a line should be partway faded in ~100 ms into its 200 ms fade-in (§3.2.4)")

	await _wait_until(func(): return encounter._label.modulate.a >= 1.0, 30)
	assert_eq(encounter._label.modulate.a, 1.0, "a line must be fully legible once its 200 ms fade-in elapses")


func test_narrative_index_persists_across_a_failed_attempt() -> void:
	await _wait_until(func(): return _encounter._emitter.is_open())
	await _press_answer()
	await _wait_until(func(): return _encounter.narrative_lines_delivered() >= 1, 120)
	assert_eq(_encounter.narrative_lines_delivered(), 1)

	await _fail_full_attempt()
	assert_gte(_encounter.narrative_lines_delivered(), 1,
		"a retry after a miss must not roll the narrative index back to 0")


func test_never_damages_or_kills_the_player_regardless_of_input() -> void:
	var start_hp: int = _player.hp
	for i in range(4):
		await _fail_full_attempt()
	assert_eq(_player.hp, start_hp, "the restoration encounter must never damage the player (§11 AC#5)")
	assert_true(is_instance_valid(_player), "the restoration encounter must never kill the player (§11 AC#5)")


func test_restoring_flips_the_flag_and_opens_a_gated_door() -> void:
	var door := Area2D.new()
	door.set_script(DoorScript)
	door.requires_flag = "restoration_complete"
	add_child_autofree(door)
	await get_tree().physics_frame
	assert_false(door.is_open(), "a restoration-gated door must start closed")

	for i in range(3):
		await _complete_current_attempt()

	assert_true(GameState.restoration_complete)
	assert_true(door.is_open(),
		"flipping the restoration flag from the encounter must actually open a gated door, not just set the boolean")
