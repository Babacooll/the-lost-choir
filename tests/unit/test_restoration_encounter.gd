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

## Color.a (modulate) is a 32-bit real_t; writing the double literal 0.30
## into it and reading it back yields ~0.300000012, which is genuinely
## greater than the 64-bit double literal 0.30 used in a bare comparison —
## a float32/float64 round-trip artifact, not a real excess over the cap.
## Anything past this margin is a real violation, not rounding noise.
const LEGIBILITY_VIOLATION_MARGIN := 0.30 + 0.001

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


## before_each's shared _encounter keeps its own tell cycling (open, miss at
## 700 ms, 1400 ms silence, re-offer) independently of anything a test does
## with a separately-instantiated encounter — and both register with the
## same PlayerCombat. A test driving its own encounter(s) through exact note
## counts must retire this one first, or an Answer press can occasionally
## resolve the shared encounter's tell instead via §5 shared rule 6's
## soonest-closing arbitration, corrupting the note/attempt count a mapping
## assertion depends on (harmless for tests that only care about eventually
## reaching a state, which is why this went unnoticed until a mapping test
## needed exact counts).
func _retire_shared_encounter() -> void:
	_encounter.queue_free()
	await get_tree().physics_frame


## A successful Answer holds PlayerCombat.answer_state in ACTIVE_POSE for a
## fixed 180 ms (ANSWER_ACTIVE_POSE_MS) before returning to IDLE — and only
## IDLE reads a new press (_update_answer's AnswerState.IDLE branch is the
## only one that checks _answer_buffer.just_pressed). A multi-encounter test
## that presses again shortly after a prior encounter's final successful
## Answer can land inside that 180 ms window and have the press silently
## dropped — not mis-resolved, just never read — which then times out into
## a real miss with no arbitration conflict to explain it. Sweep tests that
## instantiate a fresh encounter per iteration and press again quickly must
## wait this out first.
func _wait_for_answer_idle() -> void:
	await _wait_until(func(): return _player.combat.answer_state == _player.combat.AnswerState.IDLE, 30)


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


## A label's alpha only counts while it's actually on screen — Label.hide()
## leaves modulate.a untouched, so a hard cut (old label hidden at alpha 1.0,
## new label just shown at alpha 0.0) would read as "1.0" on either label
## alone and hide the very defect these tests exist to catch.
func _visible_alpha(label: Label) -> float:
	return label.modulate.a if label.visible else 0.0


## §3.2 rule 4: full legibility is a minimum of 1800 ms measured from the end
## of the 200 ms fade-in — a 2000 ms floor from the line's onset — not the
## 1800-ms-from-onset window the pre-fix implementation held it for. Asserts
## the actual rendered opacity throughout, not just elapsed time.
func test_narrative_line_holds_full_legibility_for_1800ms_after_fade_in() -> void:
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

	await _wait_until(func(): return encounter._label.modulate.a >= 1.0, 30)

	# Keep answering every note that opens so a release attempt (a gap) keeps
	# firing roughly every 1100 ms — close enough to the 2000 ms gate that an
	# early gate would show up here as a premature swap to line 2.
	var min_alpha_after_fade_in := 2.0
	var ticks := 0
	while encounter._slot_elapsed_ms[encounter._active_label_index] < 1900.0 and ticks < 200:
		min_alpha_after_fade_in = minf(min_alpha_after_fade_in, _visible_alpha(encounter._label))
		if encounter._emitter.is_open():
			await _press_answer()
		else:
			await get_tree().physics_frame
		ticks += 1

	assert_eq(encounter.narrative_lines_delivered(), 1,
		"line 1 must still be the only line delivered just short of its 1800 ms full-legibility floor")
	assert_true(encounter._line_visible, "line 1 must not hide before its full-legibility floor elapses")
	assert_eq(min_alpha_after_fade_in, 1.0,
		"line 1 must stay at full, on-screen opacity throughout its legibility floor, not just elapse in time")


## §3.2 rule 4, Scope 3 (Game Designer's phasing ruling on this issue): the
## overlap rule 4 sanctions is text over a *note*, not text over text — "a
## line is never interrupted by the next one." The original two-label
## crossfade started the outgoing label's clear only when the incoming one
## released, which left both labels between roughly alpha 0.3-0.8 at once
## for ~200 ms of every swap: two superimposed, near-unreadable sentences.
## The fix decouples the outgoing's clear from the incoming's release (see
## _slot_visible's comment in the script) so only one line is ever
## meaningfully legible. This supersedes Scope 1's "combined alpha stays
## near 1.0 across the swap" property — per the ruling's stated priority,
## legibility wins over "no blank interval" at the handoff frame itself, so
## a moment where both labels read near 0 is now expected, not a defect.
func test_only_one_line_is_ever_meaningfully_legible_at_a_time() -> void:
	var encounter = VerseBearerScene.instantiate()
	add_child_autofree(encounter)
	encounter.global_position = Vector2(100, 20)
	encounter.set_player(_player)
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_not_null(encounter._label, "the scene-instantiated bearer must resolve a real NarrativeLayer/Label")
	# encounter.get(...) rather than encounter._label_b: a direct property
	# access raises a script error (not a failed assertion GUT can score) if
	# _label_b is ever removed from the encounter script, which would abort
	# this test's body silently green instead of red — the same "reports
	# coverage it isn't providing" defect class as tests/unit/test_return.gd.
	var label_b = encounter.get("_label_b")
	assert_not_null(label_b, "the scene-instantiated bearer must resolve a second crossfade label")
	if encounter._label == null or label_b == null:
		return  # nothing further to check without both labels to observe

	# Drive a full clean run — all three line-to-line swaps (lines 1-4) —
	# sampling both labels' rendered opacity every physics frame throughout,
	# and record every frame where both cross the 0.30 legibility threshold
	# at once. The contract ("if either is >=0.30 the other must be <=0.30")
	# permits one label sitting exactly at 0.30 while the other exceeds it —
	# that's the mechanism's own clamp target — so a violation is BOTH
	# strictly above 0.30, not BOTH at-or-above it.
	var violations := []
	var ticks := 0
	while encounter.narrative_lines_delivered() < 4 and ticks < 700:
		var alpha_a: float = _visible_alpha(encounter._label)
		var alpha_b: float = _visible_alpha(label_b)
		if alpha_a > LEGIBILITY_VIOLATION_MARGIN and alpha_b > LEGIBILITY_VIOLATION_MARGIN:
			violations.append("tick %d: label=%.3f label_b=%.3f" % [ticks, alpha_a, alpha_b])
		if encounter._emitter.is_open():
			await _press_answer()
		else:
			await get_tree().physics_frame
		ticks += 1

	assert_eq(encounter.narrative_lines_delivered(), 4,
		"all four lines should have released by now on a clean run of continuous answers")
	assert_eq(violations.size(), 0,
		"both labels were >= 0.30 alpha at the same frame — two lines legible at once: %s" % [violations])


## Engineering Lead's remediation ruling (this issue, Scope 3): the original
## phasing derived "only one line legible" from the timing margin between
## the outgoing's floor and the incoming's release, and Engineering Reviewer
## measured that margin as only ~3 frames on the zero-jitter path — consumed
## 1:1 by ordinary reaction-time variation on the *first* note of a run
## (unwarned, cold-start — not a contrived input), reproducing the exact
## superimposition Game Designer ruled against for delays of roughly
## 125-215 ms. test_only_one_line_is_ever_meaningfully_legible_at_a_time
## above only ever drives the single best-case point on that curve (answers
## the instant a note opens), which is exactly why it missed this. The fix
## replaces the derived margin with a direct clamp (see LEGIBILITY_THRESHOLD
## in the script), so the contract must hold at every point on the curve,
## not just the nominal one — sweep the delay across and past Reviewer's
## measured violating band.
func test_only_one_line_legible_across_a_sweep_of_first_note_answer_delays() -> void:
	await _retire_shared_encounter()
	var delays_ms: Array = [0.0, 100.0, 133.0, 150.0, 167.0, 200.0, 233.0, 267.0]
	var all_violations := []

	for delay_ms in delays_ms:
		var encounter = VerseBearerScene.instantiate()
		add_child(encounter)
		encounter.global_position = Vector2(100, 20)
		encounter.set_player(_player)
		await get_tree().physics_frame
		await get_tree().physics_frame

		var label_b = encounter.get("_label_b")
		if encounter._label == null or label_b == null:
			all_violations.append("delay=%dms: bearer did not resolve both crossfade labels" % delay_ms)
			encounter.queue_free()
			await get_tree().physics_frame
			continue

		await _wait_for_answer_idle()
		await _wait_until(func(): return encounter._emitter.is_open())
		# Delay only the run's first answer — every note after it is still
		# answered the instant its window opens. The delay shifts when the
		# first release-attempt happens without touching note onset timing
		# (§7's "the 1100 ms spacing does not move" — unaffected either way).
		var delay_ticks := int(round(delay_ms / (1000.0 / 60.0)))
		for i in range(delay_ticks):
			await get_tree().physics_frame
		await _press_answer()

		var ticks := 0
		while encounter.narrative_lines_delivered() < 4 and ticks < 700:
			var alpha_a: float = _visible_alpha(encounter._label)
			var alpha_b: float = _visible_alpha(label_b)
			if alpha_a > LEGIBILITY_VIOLATION_MARGIN and alpha_b > LEGIBILITY_VIOLATION_MARGIN:
				all_violations.append("delay=%dms tick %d: label=%.3f label_b=%.3f" % [delay_ms, ticks, alpha_a, alpha_b])
			if encounter._emitter.is_open():
				await _press_answer()
			else:
				await get_tree().physics_frame
			ticks += 1

		if encounter.narrative_lines_delivered() != 4:
			all_violations.append("delay=%dms: only %d of 4 lines released" % [delay_ms, encounter.narrative_lines_delivered()])

		# Free explicitly (not add_child_autofree) so the next delay in the
		# sweep starts with no other encounter's tell still open — several
		# overlapping VerseBearer instances would let a single Answer press
		# resolve the wrong one's note via PlayerCombat's cross-tell
		# arbitration (§5 shared rule 6), corrupting the next iteration's
		# timing.
		encounter.queue_free()
		await get_tree().physics_frame

	assert_eq(all_violations.size(), 0,
		"both labels were >= 0.30 alpha at the same frame for at least one first-note delay in the sweep: %s" % [all_violations])


## Game Designer's ruling (Scope 3 remediation cycle 3): the counted release
## cadence (every second gap-opening event, not a wall-clock gate) makes
## rule 5's attempt->line mapping exact and unconditional — it no longer
## depends on reaction time at all, only on which numbered gap a release
## lands on. Re-run the same first-note-delay sweep as the mutual-exclusion
## test above, but assert the mapping itself: every delay must reproduce
## attempt 1 -> lines 1+2, attempt 2 -> lines 3+4, the 5-note restoring
## phrase -> no new line, exactly — not just "no visual overlap."
func test_rule5_mapping_holds_exactly_across_a_sweep_of_first_note_answer_delays() -> void:
	await _retire_shared_encounter()
	var delays_ms: Array = [0.0, 100.0, 150.0, 200.0, 250.0, 300.0, 400.0]
	var failures := []
	var expected := [[0, 3, 1], [1, 3, 3], [2, 4, 2], [3, 4, 4]]

	for delay_ms in delays_ms:
		var encounter = RestorationEncounterScript.new()
		add_child(encounter)
		encounter.global_position = Vector2(100, 20)
		encounter.set_player(_player)
		await get_tree().physics_frame
		await get_tree().physics_frame

		var mapping := []
		encounter.line_shown.connect(
			func(index, _text): mapping.append([index, encounter._phrase_length, encounter._note_index])
		)

		await _wait_for_answer_idle()
		await _wait_until(func(): return encounter._emitter.is_open())
		var delay_ticks := int(round(delay_ms / (1000.0 / 60.0)))
		for i in range(delay_ticks):
			await get_tree().physics_frame
		await _press_answer()

		# Answer everything else the instant it opens, through all three
		# attempts (3 + 4 + 5 = 12 notes total, the first already answered
		# above) to RESTORED.
		var ticks := 0
		while encounter.state != encounter.State.RESTORED and ticks < 900:
			if encounter._emitter.is_open():
				await _press_answer()
			else:
				await get_tree().physics_frame
			ticks += 1

		if encounter.state != encounter.State.RESTORED:
			failures.append("delay=%dms: never reached RESTORED" % delay_ms)
		elif mapping != expected:
			failures.append("delay=%dms mapping=%s expected=%s" % [delay_ms, mapping, expected])

		encounter.queue_free()
		await get_tree().physics_frame

	assert_eq(failures.size(), 0,
		"rule 5's attempt->line mapping must hold exactly at every first-note delay in the sweep: %s" % [failures])


## Game Designer: a miss is explicitly allowed to drift rule 5's mapping —
## "rule 5 is a clean-run contract only." What must NOT happen is a crashed
## gap counter or the same line index released twice. A miss is a gap in
## its own right (rule 3), so it still advances the counted cadence exactly
## like a resolved note.
func test_a_miss_early_in_the_run_does_not_crash_the_counter_or_double_release() -> void:
	var mapping := []
	_encounter.line_shown.connect(func(index, _text): mapping.append(index))

	# Let the very first note miss (never press Answer, letting its 700 ms
	# lead elapse and the phrase restart after the 1400 ms silence), then
	# answer everything else the instant it opens, through to RESTORED.
	await _fail_full_attempt()
	var ticks := 0
	while _encounter.state != _encounter.State.RESTORED and ticks < 900:
		if _encounter._emitter.is_open():
			await _press_answer()
		else:
			await get_tree().physics_frame
		ticks += 1

	assert_eq(_encounter.state, _encounter.State.RESTORED,
		"the encounter must still reach RESTORED after an early miss, not stall the counter")

	var seen := {}
	for idx in mapping:
		assert_false(seen.has(idx), "line index %d was released more than once: %s" % [idx, mapping])
		seen[idx] = true
	for i in range(1, mapping.size()):
		assert_true(mapping[i] > mapping[i - 1],
			"line indices must arrive strictly increasing, never rewinding (rule 2): %s" % [mapping])
	assert_true(mapping.size() <= _encounter.MAX_NARRATIVE_LINES,
		"no more than %d lines should ever be released regardless of how the run degrades: %s" % [_encounter.MAX_NARRATIVE_LINES, mapping])


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
