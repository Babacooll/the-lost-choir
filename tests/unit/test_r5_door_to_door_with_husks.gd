extends GutTest
## MICH-617 acceptance criterion 4 — the open completability question left by
## MICH-615: a real door-to-door pass through R5 with BOTH husks live, no
## test-only queue_free. test_r5_climb_traversal.gd neutralizes the husks on
## purpose (it exists to isolate pure platforming, see its own header) and
## test_r5_encounter_reachability.gd drives combat but not the full room —
## this is what actually covers the room criterion 4 asks for.
##
## Reuses test_r5_climb_traversal.gd's engine-driven, launch-point-sweeping
## climb (see that file's header for why a swept real trajectory is what
## catches unreachable hops, not a static check) and interleaves it with
## real combat: every physics tick this also checks for any live husk in
## TELLING and presses Answer, so a tell opening mid-climb doesn't stall or
## kill the run instead of being handled the way a real player would.

const PlayerScene := preload("res://scenes/player.tscn")
const RoomScene := preload("res://scenes/levels/R5_Colonnade.tscn")

# Mirrors R5_Colonnade's authored SolidRect climb geometry (assets/levels/
# the_lost_choir.ldtk) bottom to top, post-MICH-617 (ledge4/ledge8 widened
# 139-219 -> 139-239 to give the re-placed Keening Husk >=48px entry margin —
# see that item's handback for the arithmetic).
const CLIMB_PLATFORMS := [
	{"x0": 0.0, "x1": 460.0, "top": 528.0},    # floor
	{"x0": 273.0, "x1": 353.0, "top": 478.0},  # rung1
	{"x0": 160.0, "x1": 240.0, "top": 428.0},  # ledge1
	{"x0": 69.0, "x1": 149.0, "top": 378.0},   # rung2
	{"x0": 19.0, "x1": 99.0, "top": 328.0},    # ledge2
	{"x0": 124.0, "x1": 204.0, "top": 278.0},  # rung3
	{"x0": 184.0, "x1": 264.0, "top": 228.0},  # ledge3
	{"x0": 263.0, "x1": 343.0, "top": 178.0},  # rung4
	{"x0": 139.0, "x1": 239.0, "top": 128.0},  # ledge4 / Keening Husk's perch
]
const EXIT_DOOR_RECT := Rect2(171.0, 36.0, 16.0, 56.0)

const PLAYER_HALF_WIDTH := 9.0
const PLAYER_HEIGHT := 40.0

var _room: Room
var _player: CharacterBody2D
var _input
var _held_dir: int = 0  # -1 left, 0 none, 1 right


func before_each() -> void:
	_room = RoomScene.instantiate()
	add_child_autofree(_room)
	# Deliberately NOT neutralizing the husks — this test's whole point is
	# the real room with both live.
	_player = PlayerScene.instantiate()
	add_child_autofree(_player)
	_input = InputSender.new(Input)

	var entry_spawn: Vector2 = _room.get_door_spawn_position("R5_to_R4")
	_player.global_position = entry_spawn
	_player.velocity = Vector2.ZERO


func after_each() -> void:
	_input.release_all()
	_input = null


## Every tick this test advances through, service any husk currently in
## TELLING the same way a real player answering by ear would — press Answer
## once the tell is open. Both husks' registers were already validated
## individually by test_r5_encounter_reachability.gd; this isn't re-proving
## the tell contract, only keeping a live husk from turning a platforming
## tick loop into an unscripted, unhandled fight.
func _service_combat() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if "state" in enemy and "State" in enemy and enemy.state == enemy.State.TELLING:
			_input.action_down(&"answer")
			await get_tree().physics_frame
			_input.action_up(&"answer")
			return


func _tick() -> void:
	await get_tree().physics_frame
	await _service_combat()


func _release_horizontal() -> void:
	_input.action_up("move_left")
	_input.action_up("move_right")
	_held_dir = 0


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
				await _tick()
				_input.action_up("jump")
				jumped = true
				_hold_toward(to_center)
				continue

		await _tick()

		if jumped and _player.is_on_floor():
			var landed_on_target: bool = (
				absf(_player.global_position.y - to["top"]) < 2.0
				and _player.global_position.x > to["x0"] - PLAYER_HALF_WIDTH
				and _player.global_position.x < to["x1"] + PLAYER_HALF_WIDTH
			)
			if landed_on_target:
				_release_horizontal()
				return true
			return false

	return false


func _climb_to(frm: Dictionary, to: Dictionary, max_ticks: int = 260) -> bool:
	var to_center: float = (to["x0"] + to["x1"]) * 0.5
	var reset_pos: Vector2 = _player.global_position
	var dir_sign := signf(to_center - reset_pos.x)

	var candidates: Array = []
	var x: float = frm["x0"] + PLAYER_HALF_WIDTH
	var x1: float = frm["x1"] - PLAYER_HALF_WIDTH
	while x <= x1:
		candidates.append(x)
		x += 12.0
	candidates.sort_custom(func(a, b): return absf(a - reset_pos.x) < absf(b - reset_pos.x))

	for launch_x in candidates:
		# Reset position/velocity only — HP, husk states and combat progress
		# carry across attempts within a hop, same as a real player retrying
		# a jump without the room resetting around them.
		_player.global_position = reset_pos
		_player.velocity = Vector2.ZERO
		_release_horizontal()
		await _tick()

		var ok := await _attempt_climb(to, launch_x, dir_sign, max_ticks)
		if ok:
			return true

	return false


func test_r5_door_to_door_with_both_husks_live() -> void:
	var reed = null
	var keening = null
	for marker in get_tree().get_nodes_in_group("EnemyMarker"):
		for child in marker.get_children():
			if child.get_script() == null:
				continue
			var gname: String = child.get_script().get_global_name()
			if gname == "ReedHusk":
				reed = child
			elif gname == "KeeningHusk":
				keening = child
	assert_not_null(reed, "R5's ReedHusk must have spawned")
	assert_not_null(keening, "R5's KeeningHusk must have spawned")

	for i in range(CLIMB_PLATFORMS.size() - 1):
		var frm: Dictionary = CLIMB_PLATFORMS[i]
		var to: Dictionary = CLIMB_PLATFORMS[i + 1]
		var reached := await _climb_to(frm, to)
		assert_true(
			reached,
			"door-to-door pass with both husks live failed on hop %d->%d (top=%d)" % [i, i + 1, to["top"]]
		)
		if not reached:
			return

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
		await _tick()

		var jumped_for_door := false
		for i in range(120):
			_hold_toward(door_center_x if jumped_for_door else door_launch_x)

			if not jumped_for_door and _player.is_on_floor():
				var px := _player.global_position.x
				var past_launch: bool = (px >= door_launch_x) if door_dir_sign > 0.0 else (px <= door_launch_x)
				if door_dir_sign == 0.0 or past_launch:
					_input.action_down("jump")
					await _tick()
					_input.action_up("jump")
					jumped_for_door = true
					_hold_toward(door_center_x)
					continue

			await _tick()
			var pos := _player.global_position
			var overlaps := (
				pos.x + PLAYER_HALF_WIDTH > EXIT_DOOR_RECT.position.x
				and pos.x - PLAYER_HALF_WIDTH < EXIT_DOOR_RECT.position.x + EXIT_DOOR_RECT.size.x
				and pos.y > EXIT_DOOR_RECT.position.y
				and pos.y - PLAYER_HEIGHT < EXIT_DOOR_RECT.position.y + EXIT_DOOR_RECT.size.y
			)
			if overlaps:
				reached_door = true
				break
		_release_horizontal()
		if reached_door:
			break

	assert_true(reached_door, "door-to-door pass with both husks live reached the top ledge but never overlapped the R5_to_R6 door trigger")
	assert_true(is_instance_valid(reed), "the Reed Husk must not be removed to make this pass work — no test-only queue_free")
	assert_true(is_instance_valid(keening), "the Keening Husk must not be removed to make this pass work — no test-only queue_free")
	assert_gt(_player.hp, 0, "the player must reach R5_to_R6 alive")
