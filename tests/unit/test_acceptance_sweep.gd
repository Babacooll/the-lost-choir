extends GutTest
## §11 acceptance sweep — one continuous playthrough through the real Zone
## scene, the real door graph, the real restoration encounter, and the real
## Sustain/Return/warmth/audio systems together, rather than in the
## checkpoint-scoped isolation each already has thorough coverage under.
## Integration gaps between independently-correct systems are exactly what
## per-checkpoint unit tests (144 of them, each independently reviewed) can
## miss — this test exists to catch those, not to re-derive numbers already
## verified in isolation (§3.1 movement, §5 tell timing/compression,
## Return's damage/stagger, the warmth propagation formula, the audio bus
## topology): those stay covered by their own dedicated suites.

const ZoneScene := preload("res://scenes/levels/Zone.tscn")
const R7Scene := preload("res://scenes/levels/R7_WarmReturn.tscn")

var _zone: Node2D
var _player: CharacterBody2D
var _input


func before_each() -> void:
	GameState.restoration_complete = false
	ZoneManager.current_room = null

	_zone = ZoneScene.instantiate()
	add_child_autofree(_zone)
	_player = get_tree().get_first_node_in_group("player")
	_input = InputSender.new(Input)
	await get_tree().physics_frame


func after_each() -> void:
	_input.release_all()
	_input = null
	if ZoneManager.current_room != null:
		ZoneManager.current_room.free()
	ZoneManager.current_room = null
	GameState.restoration_complete = false


func _wait_ticks(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame


func _find_restoration_encounter():
	for marker in get_tree().get_nodes_in_group("EncounterMarker"):
		for child in marker.get_children():
			if child is RestorationEncounter:
				return child
	return null


## Answers every note of the currently-in-progress attempt in turn, mirroring
## test_restoration_encounter.gd's own helper, driven here against the real
## R6-spawned instance rather than a bare one.
func _complete_current_attempt(encounter) -> void:
	var target_length: int = encounter._phrase_length
	for i in range(target_length):
		var ticks := 0
		while not encounter._emitter.is_open() and ticks < 240:
			await get_tree().physics_frame
			ticks += 1
		_input.action_down(&"answer")
		await get_tree().physics_frame
		_input.action_up(&"answer")


func test_full_acceptance_sweep_in_one_continuous_session() -> void:
	# --- Sanity: R7 is genuinely gated before restoration, in THIS session's
	# GameState — not assumed from test_ldtk_zone_graph.gd's own instance.
	var r7_precheck := R7Scene.instantiate()
	add_child_autofree(r7_precheck)
	assert_false(r7_precheck.doors["R7_to_R4"].is_open(), "AC#8: R7's shortcut must be impassable before restoration")
	assert_false(r7_precheck.doors["R7_to_R1"].is_open(), "AC#8: R7's drop to R1 must be impassable before restoration")
	r7_precheck.free()

	# --- AC#1 (partial): the critical-path door graph R1..R6 is exhaustively
	# checked for reciprocity/gating by test_ldtk_zone_graph.gd already;
	# jumping straight to R6 here is deliberate — this test's job starts
	# where that coverage stops, at what happens after arrival, together.
	ZoneManager.travel("R6_ColdAmphitheater", "")
	await get_tree().physics_frame
	assert_eq(ZoneManager.current_room.level_id, "R6_ColdAmphitheater")

	var encounter = _find_restoration_encounter()
	assert_not_null(encounter, "R6 must have spawned a real restoration encounter, not stayed an inert marker")
	encounter.set_player(_player)

	# --- AC#5: restoration encounter completes, climbs exactly one rung per
	# completed phrase (3 -> 4 -> 5), and never touches the player.
	var start_hp: int = _player.hp
	assert_false(GameState.restoration_complete)
	assert_eq(encounter._phrase_length, 3)
	await _complete_current_attempt(encounter)
	assert_eq(encounter._phrase_length, 4, "completing the 3-note phrase should climb to 4")
	await _complete_current_attempt(encounter)
	assert_eq(encounter._phrase_length, 5, "completing the 4-note phrase should climb to 5")
	await _complete_current_attempt(encounter)
	assert_true(GameState.restoration_complete, "completing the 5-note phrase should restore the Verse")
	assert_eq(_player.hp, start_hp, "AC#5: the restoration encounter must never damage the player")

	# --- AC#6: Sustain and Return usable in R6 immediately, before leaving.
	assert_true(_player.sustain.is_available(), "AC#6: Sustain must be usable in R6 immediately after restoration")
	_input.action_down(&"sustain")
	var ticks := 0
	while not _player.sustain.world_effects_active() and ticks < 60:
		await get_tree().physics_frame
		ticks += 1
	assert_true(_player.sustain.world_effects_active(), "Sustain must actually engage in R6, not just report available")
	_input.action_up(&"sustain")
	await _wait_ticks(20)
	# Return's own gate (has_resolved_note() and restoration_complete and a
	# strikeable target) is exhaustively covered by test_return.gd against a
	# real enemy; R6 has none to Return against by design (§7: not a boss
	# fight, no combat here) — confirming the flag half of its gate is true
	# in this live session is what's left to check together.
	assert_true(GameState.restoration_complete, "Return's restoration gate is live for whenever an enemy is next answered")

	# --- AC#10 (R6): cold -> warm settles to fully warm at R6's far corner.
	await _wait_ticks(150)  # ~2.5 s game time — comfortably past R6's ~1.37 s settle
	var r6_room: Room = ZoneManager.current_room
	assert_almost_eq(WarmthField.warmth_at(r6_room.warmth_origin()), 1.0, 0.01,
		"AC#10: R6 should read fully warm at its own seam well after the propagation settles")

	# --- AC#11: leitmotif gains an interval at restoration (the warm
	# ambience bed becomes audible) and — the part isolated checkpoint
	# review can't see — stays the *same, continuously-playing* stream
	# across the room transition that follows, not stopped and restarted.
	var amb_warm = AudioDirector._amb_warm_player
	assert_almost_eq(amb_warm.volume_db, 0.0, 1.0, "AC#11: the warm leitmotif bed should be audible after restoration")
	var position_before_transition: float = amb_warm.get_playback_position()
	var stream_before_transition: AudioStream = amb_warm.stream

	# --- AC#8: the shortcut loop back to R4/R1 is real now, not just a flag.
	assert_true(r6_room.doors["R6_to_R7"].is_open(), "AC#8: R6's door to R7 should open once restored")
	ZoneManager.travel("R7_WarmReturn", "R6_to_R7")
	await get_tree().physics_frame
	assert_eq(ZoneManager.current_room.level_id, "R7_WarmReturn")

	assert_eq(amb_warm.stream, stream_before_transition,
		"AC#11: the leitmotif bed must be the same continuously-playing stream across a room transition, not restarted")
	assert_gt(amb_warm.get_playback_position(), position_before_transition - 0.05,
		"AC#11: playback position must have kept advancing across the transition, not reset to 0")

	# --- AC#7: a real membrane in R7 responds to a real Sustain hold. Walk
	# the player to within range first — realistic play, and it also keeps
	# this comfortably inside the 3000 ms breath budget (engaging takes only
	# the 180 ms ramp-in once in range).
	var membrane = get_tree().get_nodes_in_group("membrane")[0]
	membrane.set_player(_player)
	assert_false(membrane.is_taut())
	_player.global_position = membrane.global_position + Vector2(0.0, -30.0)
	_input.action_down(&"sustain")
	ticks = 0
	while not membrane.is_taut() and ticks < 60:
		await get_tree().physics_frame
		ticks += 1
	assert_true(membrane.is_taut(), "AC#7: a real Sustain hold near R7's real membrane should tauten it")
	_input.action_up(&"sustain")
	ticks = 0
	while membrane.is_taut() and ticks < 250:
		await get_tree().physics_frame
		ticks += 1
	assert_false(membrane.is_taut(), "AC#7: breath/release ramp-out should let the membrane go slack again")

	# --- AC#8 continued: the loop actually reaches R4 and R1, both doors
	# open, not just the one this test happens to walk through.
	assert_true(ZoneManager.current_room.doors["R7_to_R4"].is_open())
	assert_true(ZoneManager.current_room.doors["R7_to_R1"].is_open())
	ZoneManager.travel("R4_MembraneHall", "R7_to_R4")
	await get_tree().physics_frame
	assert_eq(ZoneManager.current_room.level_id, "R4_MembraneHall")

	# --- AC#10 (R4): confirmed warm too, while still the active room.
	var r4_room: Room = ZoneManager.current_room
	# No extra wait needed here — the warmth clock is global and single
	# (§8/art doc §4.2), and it's already run well past R4's own settle
	# time by this point in the session.
	assert_almost_eq(WarmthField.warmth_at(r4_room.warmth_origin()), 1.0, 0.01,
		"AC#10: R4 should also read fully warm well after restoration + settle")

	# --- AC#7: a real bell-frame in R4 responds to a real Sustain hold —
	# and AC#9's mechanism: this is what actually makes R8 reachable.
	var bell = get_tree().get_nodes_in_group("bell_frame")[0]
	bell.set_player(_player)
	assert_false(bell.is_descended())
	_player.global_position = bell.global_position + Vector2(0.0, -30.0)
	_input.action_down(&"sustain")
	ticks = 0
	while not bell.is_descended() and ticks < 60:
		await get_tree().physics_frame
		ticks += 1
	assert_true(bell.is_descended(), "AC#7: a real Sustain hold near R4's real bell-frame should lower it")
	_input.action_up(&"sustain")
	await _wait_ticks(150)

	# --- AC#9: R8 — reachable now the flag's open (the platforming itself
	# requiring Sustain is the bell-frame check just above), and contains a
	# fragment marker and nothing else.
	assert_true(ZoneManager.current_room.doors["R4_to_R8"].is_open())
	ZoneManager.travel("R8_CrackedBell", "R4_to_R8")
	await get_tree().physics_frame
	assert_eq(ZoneManager.current_room.level_id, "R8_CrackedBell")
	assert_eq(get_tree().get_nodes_in_group("FragmentMarker").size(), 1,
		"AC#9: R8 should contain exactly one narrative fragment")
	assert_eq(get_tree().get_nodes_in_group("EnemyMarker").size(), 0, "AC#9: R8 must contain no enemy — nothing else")
	assert_eq(get_tree().get_nodes_in_group("EncounterMarker").size(), 0, "AC#9: R8 must contain no encounter — nothing else")

	# --- AC#12: the debug overlay ships and stays off by default even
	# after this whole session — nothing above should have toggled it.
	assert_false(DebugOverlay.visible, "AC#12: the debug overlay must still default off after a full session")
