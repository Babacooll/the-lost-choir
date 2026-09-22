extends GutTest
## MICH-615 §3: drives the real R2/R5 Room scenes with the now-live husks to
## confirm the four authored encounters are actually reachable and
## survivable, not just correctly positioned (test_enemy_spawning.gd already
## covers positions/instantiation). Unlike test_r5_climb_traversal.gd (pure
## platforming, enemies neutralized there on purpose) this test drives
## combat instead of a climb.
##
## MICH-617 re-placed both R5 husks off the entry point (docs/design/
## vertical-slice.md §6's P1/P2/P3 contract — see the LDtk file and
## test_r5_climb_traversal.gd's CLIMB_PLATFORMS for the geometry): Reed Husk
## now holds rung1 (the foot of the climb) and Keening Husk perches on a new
## high ledge at the top of the room, so neither is in range of a player who
## has just walked in. The old "opens at entry" test asserted the defect
## this fixed; it is replaced below by an explicit "stays IDLE at entry"
## check for each husk, plus a reachability check positioned where each
## husk's aggro/lunge range actually is.

const R2Scene := preload("res://scenes/levels/R2_ReedGallery.tscn")
const R5Scene := preload("res://scenes/levels/R5_Colonnade.tscn")
const PlayerScene := preload("res://scenes/player.tscn")

var _room: Room
var _player: CharacterBody2D
var _input


func after_each() -> void:
	if _input != null:
		_input.release_all()
	_input = null


func _wait_until(predicate: Callable, max_ticks: int = 300) -> bool:
	var ticks := 0
	while not predicate.call() and ticks < max_ticks:
		await get_tree().physics_frame
		ticks += 1
	return predicate.call()


func _find_enemy(script_class_name: String):
	for marker in get_tree().get_nodes_in_group("EnemyMarker"):
		for child in marker.get_children():
			if child.get_script() != null and child.get_script().get_global_name() == script_class_name:
				return child
	return null


func _press_answer() -> void:
	_input.action_down(&"answer")
	await get_tree().physics_frame
	_input.action_up(&"answer")


func test_r2_far_reed_husk_is_reachable_and_answerable() -> void:
	_room = R2Scene.instantiate()
	add_child_autofree(_room)
	_player = PlayerScene.instantiate()
	add_child_autofree(_player)
	_player.global_position = Vector2(32.0, 208.0)  # near the R2_to_R1 entry door, on the floor
	_input = InputSender.new(Input)
	await get_tree().physics_frame

	var reed = _find_enemy("ReedHusk")
	assert_not_null(reed, "R2's far-half ReedHusk marker must have spawned a real instance")

	# R2's entry-half PassiveHusk physically occupies the flat corridor (it
	# never moves — its whole point is to stand in the way as a safe Strike
	# target) — clearing it is the intended teaching beat before the far
	# ReedHusk is even reachable, not an obstacle to route around.
	var passive = _find_enemy("PassiveHusk")
	assert_not_null(passive, "R2's entry-half PassiveHusk marker must have spawned a real instance")
	passive.take_strike(3)
	await get_tree().physics_frame
	assert_false(is_instance_valid(passive), "3 Strikes should clear the entry-half PassiveHusk out of the corridor")

	# Walk across the rest of R2's flat floor toward the far-half husk (x=600).
	_input.action_down("move_right")
	var reached_telling := await _wait_until(func(): return reed.state == reed.State.TELLING, 600)
	_input.action_up("move_right")

	assert_true(reached_telling, "walking the length of R2's floor must bring the player into the far ReedHusk's reach")

	var start_hp: int = _player.hp
	await _press_answer()
	await get_tree().physics_frame
	assert_eq(_player.combat.last_answer_result, "success", "the far ReedHusk's tell must be answerable")
	assert_eq(_player.hp, start_hp, "a successful Answer must not damage the player")


## P1: at the R5_to_R4 entry door, before any input, neither husk may be
## within its own aggro range (with a >=48px margin). 90 ticks at the
## physics tick rate (60 Hz) is 1.5s of continuous non-aggro, comfortably
## past the 1s the design contract asks for.
func test_r5_keening_husk_stays_idle_at_r5_entry() -> void:
	_room = R5Scene.instantiate()
	add_child_autofree(_room)
	_player = PlayerScene.instantiate()
	add_child_autofree(_player)
	_player.global_position = Vector2(32.0, 504.0)  # authored R5_to_R4 entry door position
	_input = InputSender.new(Input)
	await get_tree().physics_frame

	var keening = _find_enemy("KeeningHusk")
	assert_not_null(keening, "R5's KeeningHusk marker must have spawned a real instance")

	var margin: float = _player.global_position.distance_to(keening.global_position) - keening.aggro_range_px()
	assert_gt(margin, 48.0, "the Keening Husk must clear R5's entry point by >=48px margin (got %.1f)" % margin)

	var reached_telling := await _wait_until(func(): return keening.state == keening.State.TELLING, 90)
	assert_false(reached_telling, "the Keening Husk must stay IDLE at R5's entry point (P1)")
	assert_eq(keening.state, keening.State.IDLE, "the Keening Husk must remain IDLE, not just non-TELLING, at entry")


func test_r5_reed_husk_stays_idle_at_r5_entry() -> void:
	_room = R5Scene.instantiate()
	add_child_autofree(_room)
	_player = PlayerScene.instantiate()
	add_child_autofree(_player)
	_player.global_position = Vector2(32.0, 504.0)
	_input = InputSender.new(Input)
	await get_tree().physics_frame

	var reed = _find_enemy("ReedHusk")
	assert_not_null(reed, "R5's ReedHusk marker must have spawned a real instance")

	var margin: float = _player.global_position.distance_to(reed.global_position) - reed.aggro_range_px()
	assert_gt(margin, 48.0, "the Reed Husk must clear R5's entry point by >=48px margin (got %.1f)" % margin)

	var reached_telling := await _wait_until(func(): return reed.state == reed.State.TELLING, 90)
	assert_false(reached_telling, "the Reed Husk must stay IDLE at R5's entry point (P1)")
	assert_eq(reed.state, reed.State.IDLE, "the Reed Husk must remain IDLE, not just non-TELLING, at entry")


## P3: Reed Husk holds the foot of the climb (rung1). Parking the player
## right beside its resting spot lets it close the remaining few px on foot
## and lunge, the same way test_r5_climb_traversal.gd's live-husk climb
## engages it before continuing upward.
func test_r5_reed_husk_is_reachable_and_answerable_on_rung1() -> void:
	_room = R5Scene.instantiate()
	add_child_autofree(_room)
	_player = PlayerScene.instantiate()
	add_child_autofree(_player)
	_input = InputSender.new(Input)
	await get_tree().physics_frame

	var reed = _find_enemy("ReedHusk")
	assert_not_null(reed, "R5's ReedHusk marker must have spawned a real instance")
	# rung1 (x0=273, x1=353, top=478) — stand a few px from Reed's own resting
	# spot (345, 478), still well inside both its aggro (220) and, once it
	# closes the gap, its lunge range (40).
	_player.global_position = Vector2(300.0, 478.0)
	await get_tree().physics_frame

	var reached_telling := await _wait_until(func(): return reed.state == reed.State.TELLING, 300)
	assert_true(reached_telling, "the Reed Husk must close to lunge range and open its tell on rung1")

	var start_hp: int = _player.hp
	await _press_answer()
	await get_tree().physics_frame
	assert_eq(_player.combat.last_answer_result, "success", "R5's Reed Husk tell must be answerable")
	assert_eq(_player.hp, start_hp, "a successful Answer must not damage the player")


## P2: Keening Husk's register belongs to the top of the climb. Its 380px
## aggro reaches down as far as ledge3/rung3 but never the floor — stand on
## ledge3 (x0=184, x1=264, top=228), which the climb passes through, and
## confirm the stationary, ranged Keening Husk notices from there.
func test_r5_keening_husk_is_reachable_and_answerable_from_the_upper_climb() -> void:
	_room = R5Scene.instantiate()
	add_child_autofree(_room)
	_player = PlayerScene.instantiate()
	add_child_autofree(_player)
	_input = InputSender.new(Input)
	await get_tree().physics_frame

	var keening = _find_enemy("KeeningHusk")
	assert_not_null(keening, "R5's KeeningHusk marker must have spawned a real instance")
	_player.global_position = Vector2(224.0, 228.0)
	await get_tree().physics_frame

	var reached_telling := await _wait_until(func(): return keening.state == keening.State.TELLING, 300)
	assert_true(reached_telling, "the Keening Husk must notice the player from ledge3, on the upper climb")

	var start_hp: int = _player.hp
	await _press_answer()
	await get_tree().physics_frame
	assert_eq(_player.combat.last_answer_result, "success", "R5's Keening Husk tell must be answerable")
	assert_eq(_player.hp, start_hp, "a successful Answer must not damage the player")
