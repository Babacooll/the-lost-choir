extends GutTest
## Art-direction doc §4.2 — the cold->warm warmth field. Numeric propagation
## contract (300 px/s, 2500 ms, 24 px overshoot band, 400 ms settle) plus the
## room-level integration (R7/R8 pinned warm, R6's seam origin, gating on the
## single GameState.restoration_complete flag).

const RoomScene := preload("res://scenes/levels/Room.tscn")
const R6Scene := preload("res://scenes/levels/R6_ColdAmphitheater.tscn")
const R7Scene := preload("res://scenes/levels/R7_WarmReturn.tscn")

var _rooms_root: Node2D


func before_each() -> void:
	GameState.restoration_complete = false
	WarmthField._elapsed_ms = 0.0
	WarmthField._restoration_started_at_ms = -1.0
	_rooms_root = Node2D.new()
	add_child_autofree(_rooms_root)
	ZoneManager.current_room = null


func after_each() -> void:
	if ZoneManager.current_room != null:
		ZoneManager.current_room.free()
	ZoneManager.current_room = null
	GameState.restoration_complete = false


func _tick_ms(ms: float) -> void:
	for i in range(int(round(ms))):
		WarmthField._physics_process(0.001)


## --- pure formula: warmth_at_distance -------------------------------------

func test_before_restoration_everything_is_cold() -> void:
	assert_eq(WarmthField.warmth_at_distance(0.0, -1.0), 0.0)
	assert_eq(WarmthField.warmth_at_distance(500.0, -1.0), 0.0)


func test_wavefront_has_not_reached_a_far_point_yet() -> void:
	# 300 px/s -> at 500 ms the front is at 150 px; a point at 300 px is untouched.
	assert_eq(WarmthField.warmth_at_distance(300.0, 500.0), 0.0)


func test_linear_in_distance_no_ease() -> void:
	# The front's own position over time must be exactly speed * t -- checked
	# by confirming a point exactly at the front has just started its band,
	# for several different times, not just one sample.
	for t_ms in [200.0, 900.0, 1700.0]:
		var front_distance: float = WarmthField.PROPAGATION_SPEED_PX_S * t_ms / 1000.0
		var w: float = WarmthField.warmth_at_distance(front_distance, t_ms)
		assert_almost_eq(w, 0.0, 0.05, "distance %f at t=%f should be right at the wavefront" % [front_distance, t_ms])


func test_overshoot_band_peaks_at_1_15() -> void:
	# A point at the origin (distance 0) finishes crossing the 24px band after
	# BAND_DURATION_MS = 24/300*1000 = 80 ms.
	var w: float = WarmthField.warmth_at_distance(0.0, WarmthField.BAND_DURATION_MS)
	assert_almost_eq(w, WarmthField.BAND_OVERSHOOT, 0.001)


func test_overshoot_settles_to_1_over_400ms_behind_the_band() -> void:
	var just_after_band: float = WarmthField.warmth_at_distance(0.0, WarmthField.BAND_DURATION_MS)
	var mid_settle: float = WarmthField.warmth_at_distance(
		0.0, WarmthField.BAND_DURATION_MS + WarmthField.BAND_SETTLE_MS * 0.5
	)
	var fully_settled: float = WarmthField.warmth_at_distance(
		0.0, WarmthField.BAND_DURATION_MS + WarmthField.BAND_SETTLE_MS
	)
	assert_almost_eq(just_after_band, 1.15, 0.001)
	assert_almost_eq(mid_settle, 1.075, 0.005, "halfway through the 400 ms settle should be halfway between 1.15 and 1.0")
	assert_almost_eq(fully_settled, 1.0, 0.001)
	assert_eq(WarmthField.warmth_at_distance(0.0, WarmthField.BAND_DURATION_MS + WarmthField.BAND_SETTLE_MS + 1000.0), 1.0)


func test_full_propagation_duration_matches_the_2500ms_design_contract() -> void:
	# 300 px/s * 2500 ms = 750 px: the design's "full duration" is the time
	# for the wave to reach that radius, not a hard clamp on radius itself.
	var radius_at_full_duration: float = WarmthField.PROPAGATION_SPEED_PX_S * 2.5
	assert_almost_eq(radius_at_full_duration, 750.0, 0.01)
	assert_almost_eq(
		WarmthField.warmth_at_distance(radius_at_full_duration, 2500.0), 0.0, 0.05,
		"the point exactly at the 2500 ms radius should be right at the front, not already warm"
	)


## --- integration: elapsed clock + restoration flag -------------------------

func test_time_since_restoration_is_negative_before_the_flag_flips() -> void:
	assert_eq(WarmthField._time_since_restoration_ms(), -1.0)


func test_time_since_restoration_starts_counting_from_the_flip() -> void:
	_tick_ms(300.0)
	GameState.restoration_complete = true
	_tick_ms(150.0)
	assert_almost_eq(WarmthField._time_since_restoration_ms(), 150.0, 1.0)


func test_reverting_the_flag_resets_the_clock() -> void:
	GameState.restoration_complete = true
	_tick_ms(500.0)
	GameState.restoration_complete = false
	assert_eq(WarmthField._time_since_restoration_ms(), -1.0)


## --- integration: rooms --------------------------------------------------

func test_r7_is_pinned_warm_even_before_restoration() -> void:
	ZoneManager.current_room = R7Scene.instantiate()
	_rooms_root.add_child(ZoneManager.current_room)
	assert_eq(WarmthField.warmth_at(Vector2(9999, 9999)), 1.0, "R7 is authored warm-on-first-sight (art doc §4.3)")


func test_r6_seam_origin_is_the_verse_bearers_own_position() -> void:
	ZoneManager.current_room = R6Scene.instantiate()
	_rooms_root.add_child(ZoneManager.current_room)
	await get_tree().physics_frame
	var marker := ZoneManager.current_room.get_tree().get_first_node_in_group("EncounterMarker")
	assert_not_null(marker, "R6 should have spawned its EncounterMarker")
	assert_eq(ZoneManager.current_room.warmth_origin(), marker.global_position)


func test_a_room_without_a_bearer_falls_back_to_room_centre() -> void:
	var room: Room = RoomScene.instantiate()
	room.level_id = "R4_MembraneHall"
	_rooms_root.add_child(room)
	var level := LDtkProject.get_level("R4_MembraneHall")
	assert_eq(room.warmth_origin(), room.global_position + Vector2(level.get("pxWid"), level.get("pxHei")) * 0.5)


func test_room_is_uniformly_cold_before_restoration_and_warms_after() -> void:
	ZoneManager.current_room = R6Scene.instantiate()
	_rooms_root.add_child(ZoneManager.current_room)
	await get_tree().physics_frame
	var origin := ZoneManager.current_room.warmth_origin()

	assert_eq(WarmthField.warmth_at(origin), 0.0, "cold before restoration, even at the seam")
	assert_eq(WarmthField.warmth_at(origin + Vector2(300, 0)), 0.0)

	GameState.restoration_complete = true
	_tick_ms(2000.0)
	assert_almost_eq(
		WarmthField.warmth_at(origin), 1.0, 0.01,
		"long after restoration the seam itself should have settled to steady warm"
	)
