extends GutTest
## Godot-native interim implementation of docs/audio/fmod-implementation-
## contract.md. FMOD's SDK is proprietary/account-gated and unobtainable in
## this environment (no vendored fmod-gdextension, no license access) — see
## AudioDirector's header for the full substitution rationale. These tests
## cover the numerically-checkable contract: bus topology, ducking, TellLead
## time-stretch, save/load silence, R6 routing, and leitmotif zone-scoping.

const PlayerScene := preload("res://scenes/player.tscn")
const MembraneScene := preload("res://scenes/world/membrane.tscn")


func before_each() -> void:
	GameState.restoration_complete = false
	AudioDirector._open_tell_count = 0
	AudioDirector.verse_low_drone_restored = false
	AudioDirector._amb_target_warm = false
	if AudioDirector._duck_tween != null and AudioDirector._duck_tween.is_valid():
		AudioDirector._duck_tween.kill()
	if AudioDirector._amb_crossfade_tween != null and AudioDirector._amb_crossfade_tween.is_valid():
		AudioDirector._amb_crossfade_tween.kill()
	for bus_name in AudioDirector.DUCKED_BUSES:
		var idx := AudioServer.get_bus_index(bus_name)
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, 0.0)
	AudioDirector._amb_cold_player.volume_db = 0.0
	AudioDirector._amb_warm_player.volume_db = -80.0


func after_each() -> void:
	GameState.restoration_complete = false
	AudioDirector._open_tell_count = 0


## --- 1. Bus topology (contract §1) -----------------------------------------

func test_all_five_buses_exist() -> void:
	for bus_name in ["TELL", "VOICE", "VERSE", "AMB", "SFX"]:
		assert_ne(AudioServer.get_bus_index(bus_name), -1, "bus '%s' should exist" % bus_name)


func test_tell_bus_has_no_effects() -> void:
	var idx := AudioServer.get_bus_index("TELL")
	assert_eq(AudioServer.get_bus_effect_count(idx), 0, "TELL must carry no effect of any kind (§1)")


func test_tell_bus_is_never_a_duck_target() -> void:
	assert_false(AudioDirector.DUCKED_BUSES.has("TELL"), "TELL is never itself a duck target (§2)")


## --- 2. Ducking (contract §2) -----------------------------------------------

func test_opening_a_real_tell_ducks_the_four_buses() -> void:
	var emitter := TellEmitter.new()
	add_child_autofree(emitter)
	emitter.open_tell(520.0, "percussive")

	await get_tree().create_timer(0.06).timeout  # past the 40 ms attack

	for bus_name in AudioDirector.DUCKED_BUSES:
		var idx := AudioServer.get_bus_index(bus_name)
		assert_almost_eq(AudioServer.get_bus_volume_db(idx), AudioDirector.DUCK_DEPTH_DB, 0.5,
			"%s should be ducked -6 dB while a tell is open" % bus_name)


func test_duck_releases_after_the_tell_closes() -> void:
	var emitter := TellEmitter.new()
	add_child_autofree(emitter)
	emitter.open_tell(50.0, "percussive")  # short lead so it closes fast

	await get_tree().create_timer(0.45).timeout  # close (50 ms) + release (250 ms) + margin

	for bus_name in AudioDirector.DUCKED_BUSES:
		var idx := AudioServer.get_bus_index(bus_name)
		assert_almost_eq(AudioServer.get_bus_volume_db(idx), 0.0, 0.5,
			"%s should have released back to 0 dB once the tell closes" % bus_name)


func test_the_bearers_note_does_not_duck_anything() -> void:
	var emitter := TellEmitter.new()
	add_child_autofree(emitter)
	emitter.open_tell(700.0, "verse_bearer")

	await get_tree().create_timer(0.06).timeout

	assert_false(AudioDirector.is_ducking(), "the R6 bearer's notes are not TELL-bus opens and must not duck (contract §8)")
	for bus_name in AudioDirector.DUCKED_BUSES:
		var idx := AudioServer.get_bus_index(bus_name)
		assert_almost_eq(AudioServer.get_bus_volume_db(idx), 0.0, 0.1)


## --- 3. TellLead time-stretch, not fixed-length files (contract §4.1) ------

func test_reed_tell_pitch_scales_to_fill_a_compressed_lead() -> void:
	var emitter := TellEmitter.new()
	add_child_autofree(emitter)
	emitter.open_tell(420.0, "percussive")  # the compression floor
	await get_tree().process_frame

	var player := _find_active_stream_player()
	assert_not_null(player, "play_tell should have spawned an AudioStreamPlayer")
	assert_almost_eq(player.pitch_scale, AudioDirector.REED_BASE_LEAD_MS / 420.0, 0.001,
		"the whole 520 ms gesture must be scaled to occupy exactly the 420 ms lead, not truncated")


func test_reed_tell_at_base_lead_plays_at_normal_rate() -> void:
	var emitter := TellEmitter.new()
	add_child_autofree(emitter)
	emitter.open_tell(AudioDirector.REED_BASE_LEAD_MS, "percussive")
	await get_tree().process_frame

	var player := _find_active_stream_player()
	assert_almost_eq(player.pitch_scale, 1.0, 0.001)


## play_tell() appends its throwaway player last, so search back-to-front
## rather than risk matching the always-playing ambience/sustain players.
func _find_active_stream_player() -> AudioStreamPlayer:
	var children := AudioDirector.get_children()
	for i in range(children.size() - 1, -1, -1):
		var child = children[i]
		if child is AudioStreamPlayer and child != AudioDirector._amb_cold_player \
				and child != AudioDirector._amb_warm_player and child != AudioDirector._sustain_engage_player \
				and child.playing:
			return child
	return null


## --- 4. Save/load silence (contract §7) -------------------------------------

func test_a_live_restoration_flip_gets_the_arrival_swell() -> void:
	GameState.restoration_complete = true
	await get_tree().process_frame
	assert_true(AudioDirector._amb_crossfade_tween != null and AudioDirector._amb_crossfade_tween.is_valid(),
		"a live flip should animate the ambience crossfade, not snap it")


func test_a_flag_already_true_at_boot_snaps_silently_no_swell() -> void:
	# Simulates the save/load path: the flag is true before AudioDirector's
	# own startup logic runs, so there is no in-session event to swell from.
	AudioDirector._apply_drone_state(true, false)
	assert_true(AudioDirector.verse_low_drone_restored)
	assert_almost_eq(AudioDirector._amb_warm_player.volume_db, 0.0, 0.01,
		"loading a restored save must start warm with the interval already present, instantly")
	assert_almost_eq(AudioDirector._amb_cold_player.volume_db, -80.0, 0.01)


## --- 5. Leitmotif is zone-scoped, never restarted by a room transition -----

func test_ambience_players_survive_a_room_transition_unrecreated() -> void:
	var rooms_root := Node2D.new()
	add_child_autofree(rooms_root)
	var player := PlayerScene.instantiate()
	add_child_autofree(player)

	ZoneManager.current_room = null
	ZoneManager.bootstrap(rooms_root)

	var cold_before := AudioDirector._amb_cold_player
	var warm_before := AudioDirector._amb_warm_player

	ZoneManager.travel("R4_MembraneHall", "R4_to_R2")
	await get_tree().physics_frame
	ZoneManager.travel("R2_ReedGallery", "R2_to_R4")
	await get_tree().physics_frame

	assert_eq(AudioDirector._amb_cold_player, cold_before,
		"the leitmotif/ambience player must be the same instance across room transitions — never freed and recreated")
	assert_eq(AudioDirector._amb_warm_player, warm_before)
	# Not asserting .playing here: under the headless/Dummy audio driver GUT
	# runs under, AudioStreamPlayer never reports itself as actually playing
	# regardless of correct behaviour — the identity checks above are the
	# real claim ("never freed and recreated"; a freed-and-recreated player
	# would fail those, not this).

	if ZoneManager.current_room != null:
		ZoneManager.current_room.free()
	ZoneManager.current_room = null


## --- 6. R6 encounter parameters --------------------------------------------

func test_encounter_parameters_update_when_a_note_opens() -> void:
	AudioDirector.encounter_phrase_length = 0
	AudioDirector.encounter_note_index = -1
	AudioDirector.set_encounter_phrase_length(3)
	AudioDirector.set_encounter_note_index(1)
	assert_eq(AudioDirector.encounter_phrase_length, 3)
	assert_eq(AudioDirector.encounter_note_index, 1)
