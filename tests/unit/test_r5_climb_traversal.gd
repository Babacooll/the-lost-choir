extends GutTest
## Physics-driven acceptance artifact for AC#1's R5 segment.
##
## Three prior rounds each fixed one failure mode invisible to whatever check
## validated the previous round (jump-height, headroom, launch-position),
## because every check so far only inspected launch/landing points, never the
## trajectory between them. This test drives the real Player scene through
## the real Room-built R5 geometry via the engine's own fixed physics tick
## (await get_tree().physics_frame, exactly as test_player_jump_buffer.gd and
## test_player_corner_correction.gd do — deterministic regardless of
## wall-clock time, since the tick itself is fixed), with scripted
## held-direction + tap-jump input through InputSender. If any hop's real
## trajectory clips a third-party platform's underside, overshoots past the
## intended landing, or simply can't reach, the player fails to land on the
## next platform within the tick budget and the test times out and fails —
## it does not just check that the numbers "look right".
##
## Rather than trust one hand-derived launch position, each hop sweeps real
## launch points across the departure platform's own span, driving the
## actual engine for each candidate. This is still the engine's own physics
## deciding pass/fail — it just doesn't assume perfect knowledge of exactly
## which point a real run-up lands on, and it exercises the same class of
## "does *any* launch position clear every third-party obstruction" question
## the geometric regression test asks, but against the real trajectory
## instead of a max-apex heuristic.

const PlayerScene := preload("res://scenes/player.tscn")
const RoomScene := preload("res://scenes/levels/R5_Colonnade.tscn")

# Mirrors R5_Colonnade's authored SolidRect climb geometry (assets/levels/
# the_lost_choir.ldtk) bottom to top. Kept as literal numbers, not read from
# LDtk, so this test fails loudly (wrong platform reached / never lands) if
# the level geometry drifts without this test being updated to match.
const CLIMB_PLATFORMS := [
	{"x0": 0.0, "x1": 460.0, "top": 528.0},    # floor
	{"x0": 273.0, "x1": 353.0, "top": 478.0},  # rung1
	{"x0": 160.0, "x1": 240.0, "top": 428.0},  # ledge1
	{"x0": 69.0, "x1": 149.0, "top": 378.0},   # rung2
	{"x0": 19.0, "x1": 99.0, "top": 328.0},    # ledge2
	{"x0": 124.0, "x1": 204.0, "top": 278.0},  # rung3
	{"x0": 184.0, "x1": 264.0, "top": 228.0},  # ledge3
	{"x0": 263.0, "x1": 343.0, "top": 178.0},  # rung4
	{"x0": 139.0, "x1": 239.0, "top": 128.0},  # ledge4 — widened for MICH-617's Keening Husk re-placement
]
const EXIT_DOOR_RECT := Rect2(171.0, 36.0, 16.0, 56.0)

const PLAYER_HALF_WIDTH := 9.0
const PLAYER_HEIGHT := 40.0

var _room: Room
var _player: CharacterBody2D
var _input


func before_each() -> void:
	_room = RoomScene.instantiate()
	add_child_autofree(_room)
	# MICH-615 wired R5's EnemyMarkers to real, live husks — this test is
	# purely about the climb's platforming geometry (see the file header),
	# and both husks' aggro ranges reach the entire lower half of the climb
	# from room entry, so leaving them live here would have this test
	# driving an unscripted fight instead of the platforming it exists to
	# check. Combat reachability/survivability against these same husks has
	# its own dedicated coverage (test_r5_encounter_reachability.gd).
	for marker in get_tree().get_nodes_in_group("EnemyMarker"):
		for child in marker.get_children():
			child.queue_free()
	_player = PlayerScene.instantiate()
	add_child_autofree(_player)
	_input = InputSender.new(Input)

	# Spawn where a real player actually arrives: near the R5_to_R4 entry
	# door on the left wall (room.gd's SPAWN_HORIZONTAL_CLEARANCE places
	# arrivals ~32px clear of the trigger), not an arbitrary floor-centre
	# pick — the approach direction into rung1 matters.
	var start: Dictionary = CLIMB_PLATFORMS[0]
	_player.global_position = Vector2(32.0, start["top"])
	_player.velocity = Vector2.ZERO


func after_each() -> void:
	_input.release_all()
	_input = null


func _release_horizontal() -> void:
	_input.action_up("move_left")
	_input.action_up("move_right")
	_held_dir = 0


var _held_dir: int = 0  # -1 left, 0 none, 1 right — tracked to avoid redundant action_down calls


func _hold_toward(target_x: float) -> void:
	var want := 0
	if target_x > _player.global_position.x + 1.0:
		want = 1
	elif target_x < _player.global_position.x - 1.0:
		want = -1
	if want == _held_dir:
		return
	if _held_dir == 1:
		_input.action_up("move_right")
	elif _held_dir == -1:
		_input.action_up("move_left")
	if want == 1:
		_input.action_down("move_right")
	elif want == -1:
		_input.action_down("move_left")
	_held_dir = want


func _player_overlaps_rect(rect: Rect2) -> bool:
	var pos := _player.global_position
	return (
		pos.x + PLAYER_HALF_WIDTH > rect.position.x
		and pos.x - PLAYER_HALF_WIDTH < rect.position.x + rect.size.x
		and pos.y > rect.position.y
		and pos.y - PLAYER_HEIGHT < rect.position.y + rect.size.y
	)


## One concrete attempt: walk toward `launch_x` (a specific point on the
## departure platform), tap jump on arrival, then keep holding toward `to`'s
## centre through the whole flight and stop only once genuinely standing on
## `to` — not merely "airborne near the right x", which is exactly the class
## of false-pass a static launch/landing check can't catch. A trajectory
## that clips a third party's underside or overshoots halts real engine
## velocity outright; this shows up here as never reaching a standing
## landing within the tick budget.
func _attempt_climb(to: Dictionary, launch_x: float, dir_sign: float, max_ticks: int) -> bool:
	var to_center: float = (to["x0"] + to["x1"]) * 0.5
	var jumped := false
	for i in range(max_ticks):
		_hold_toward(to_center if jumped else launch_x)

		if not jumped and _player.is_on_floor():
			var px := _player.global_position.x
			var past_launch: bool = (px >= launch_x) if dir_sign > 0.0 else (px <= launch_x)
			if dir_sign == 0.0 or past_launch:
				_input.action_down("jump")
				await get_tree().physics_frame
				_input.action_up("jump")
				jumped = true
				_hold_toward(to_center)
				continue

		await get_tree().physics_frame

		if jumped and _player.is_on_floor():
			var landed_on_target: bool = (
				absf(_player.global_position.y - to["top"]) < 2.0
				and _player.global_position.x > to["x0"] - PLAYER_HALF_WIDTH
				and _player.global_position.x < to["x1"] + PLAYER_HALF_WIDTH
			)
			if landed_on_target:
				_release_horizontal()
				return true
			# Landed somewhere else entirely (fell through/back to a lower
			# platform) — this attempt failed; stop early rather than
			# burning the rest of the tick budget.
			return false

	return false


## Drives real input to land a stand on `to`. Rather than hand-derive one
## "correct" launch point, this sweeps real candidate launch points across
## the departure platform `frm`'s own span (every ~12px), running the
## engine's own tick loop for each, and accepts the first the engine itself
## actually lands cleanly. A hop only passes here if some real, walkable
## launch position on `frm` clears every third-party obstruction and lands
## standing on `to` — the same question the geometric regression test asks,
## now answered by the real trajectory instead of a max-apex heuristic.
func _climb_to(frm: Dictionary, to: Dictionary, max_ticks: int = 220) -> bool:
	var to_center: float = (to["x0"] + to["x1"]) * 0.5
	var reset_pos: Vector2 = _player.global_position
	var dir_sign := signf(to_center - reset_pos.x)

	var candidates: Array = []
	var x: float = frm["x0"] + PLAYER_HALF_WIDTH
	var x1: float = frm["x1"] - PLAYER_HALF_WIDTH
	while x <= x1:
		candidates.append(x)
		x += 12.0
	# Prefer candidates closer to the departure position actually reached
	# from the previous hop first — cheaper to reach, and matches how a
	# real player would approach (minimal backtracking).
	candidates.sort_custom(func(a, b): return absf(a - reset_pos.x) < absf(b - reset_pos.x))

	for launch_x in candidates:
		_player.global_position = reset_pos
		_player.velocity = Vector2.ZERO
		_release_horizontal()
		await get_tree().physics_frame

		var ok := await _attempt_climb(to, launch_x, dir_sign, max_ticks)
		if ok:
			return true

	return false


func test_full_r5_climb_reaches_the_exit_door_floor_to_door() -> void:
	for i in range(CLIMB_PLATFORMS.size() - 1):
		var frm: Dictionary = CLIMB_PLATFORMS[i]
		var to: Dictionary = CLIMB_PLATFORMS[i + 1]
		var reached := await _climb_to(frm, to)
		assert_true(
			reached,
			"driven climb failed on hop %d->%d: never landed standing on the platform at top=%d within budget" % [i, i + 1, to["top"]]
		)
		if not reached:
			return

	# Final push from the top ledge into the exit door itself. The door
	# (16px) is narrower than the player (18px), so there is no interior
	# span to be "inside" — sweep launch points across ledge4's own span
	# the same way, and success is overlapping its trigger rather than
	# landing.
	var ledge4: Dictionary = CLIMB_PLATFORMS[CLIMB_PLATFORMS.size() - 1]
	var door_center_x: float = EXIT_DOOR_RECT.position.x + EXIT_DOOR_RECT.size.x * 0.5
	var reset_pos: Vector2 = _player.global_position
	var door_dir_sign := signf(door_center_x - reset_pos.x)

	var candidates: Array = []
	var x: float = ledge4["x0"] + PLAYER_HALF_WIDTH
	var x1: float = ledge4["x1"] - PLAYER_HALF_WIDTH
	while x <= x1:
		candidates.append(x)
		x += 12.0
	candidates.sort_custom(func(a, b): return absf(a - reset_pos.x) < absf(b - reset_pos.x))

	var reached_door := false
	for door_launch_x in candidates:
		_player.global_position = reset_pos
		_player.velocity = Vector2.ZERO
		_release_horizontal()
		await get_tree().physics_frame

		var jumped_for_door := false
		for i in range(90):
			_hold_toward(door_center_x if jumped_for_door else door_launch_x)

			if not jumped_for_door and _player.is_on_floor():
				var px := _player.global_position.x
				var past_launch: bool = (px >= door_launch_x) if door_dir_sign > 0.0 else (px <= door_launch_x)
				if door_dir_sign == 0.0 or past_launch:
					_input.action_down("jump")
					await get_tree().physics_frame
					_input.action_up("jump")
					jumped_for_door = true
					_hold_toward(door_center_x)
					continue

			await get_tree().physics_frame
			if _player_overlaps_rect(EXIT_DOOR_RECT):
				reached_door = true
				break
		_release_horizontal()
		if reached_door:
			break

	assert_true(reached_door, "driven climb reached the top ledge but never overlapped the R5_to_R6 door trigger")
