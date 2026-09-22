extends GutTest
## MICH-615 §3 / MICH-617: drives the real R2/R5 Room scenes with the live
## husks to confirm the authored encounters are reachable and survivable, not
## just correctly positioned (test_enemy_spawning.gd already covers
## positions/instantiation).
##
## R5's two husks were re-placed by MICH-617 specifically so neither reaches
## the room's entry point (see docs/design/vertical-slice.md §6 "R5 encounter
## placement") — the opposite of what this file asserted before that fix.
## The entry-quiet assertion below is what now guards that regression, and
## unlike test_r5_climb_traversal.gd (pure platforming, husks neutralized
## there on purpose) the other tests here drive real combat.

const R2Scene := preload("res://scenes/levels/R2_ReedGallery.tscn")
const R5Scene := preload("res://scenes/levels/R5_Colonnade.tscn")
const PlayerScene := preload("res://scenes/player.tscn")

# R5 floor slab (assets/levels/the_lost_choir.ldtk): top edge y=528, spanning
# the room's full width (x0..x460). P2's own check.
const R5_FLOOR_TOP_Y: float = 528.0
const R5_FLOOR_X0: float = 0.0
const R5_FLOOR_X1: float = 460.0
const R5_ENTRY_MARGIN_PX: float = 48.0

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


## MICH-617 acceptance criterion 1: standing at R5's real entry spawn, before
## any input, neither husk is aggroed — with >=48px of margin on each. Uses
## Room.get_door_spawn_position() itself (not a hand-derived point) so this
## stays true to whatever the entry spawn actually computes to, rather than
## an assumption that can drift out from under the design (see MICH-617:
## the design doc's own authored-entry-point arithmetic used (32, 504), 8px
## off the engine's real (40, 504) spawn — close enough to have masked a
## margin violation on Keening Husk's first proposed position).
func test_r5_both_husks_are_idle_at_the_real_entry_spawn() -> void:
	_room = R5Scene.instantiate()
	add_child_autofree(_room)
	var entry_spawn: Vector2 = _room.get_door_spawn_position("R5_to_R4")

	_player = PlayerScene.instantiate()
	add_child_autofree(_player)
	_player.global_position = entry_spawn
	_input = InputSender.new(Input)

	var reed = _find_enemy("ReedHusk")
	var keening = _find_enemy("KeeningHusk")
	assert_not_null(reed, "R5's ReedHusk marker must have spawned a real instance")
	assert_not_null(keening, "R5's KeeningHusk marker must have spawned a real instance")

	# Hold >=1s of real physics ticks (60 Hz) without any player input —
	# arithmetic alone doesn't catch a husk whose _physics_process disagrees
	# with its own authored aggro_range_px().
	for i in range(65):
		await get_tree().physics_frame

	assert_eq(reed.state, reed.State.IDLE, "Reed Husk must still be IDLE at the entry door after 1s of standing still")
	assert_eq(keening.state, keening.State.IDLE, "Keening Husk must still be IDLE at the entry door after 1s of standing still")

	var reed_margin: float = reed.global_position.distance_to(entry_spawn) - reed.aggro_range_px()
	var keening_margin: float = keening.global_position.distance_to(entry_spawn) - keening.aggro_range_px()
	assert_gt(reed_margin, R5_ENTRY_MARGIN_PX - 0.01, "Reed Husk's aggro range must clear the entry door by >=48px (got %.1f)" % reed_margin)
	assert_gt(keening_margin, R5_ENTRY_MARGIN_PX - 0.01, "Keening Husk's aggro range must clear the entry door by >=48px (got %.1f)" % keening_margin)


## MICH-617 acceptance criterion 2: the Keening Husk's 380px aggro circle
## must never intersect the floor slab. Static check on the authored marker
## position (mirrors the design contract's own `marker_y + 380 < 528`)...
func test_r5_keening_husk_aggro_circle_does_not_reach_the_floor_slab() -> void:
	_room = R5Scene.instantiate()
	add_child_autofree(_room)
	var keening = _find_enemy("KeeningHusk")
	assert_not_null(keening, "R5's KeeningHusk marker must have spawned a real instance")

	assert_lt(
		keening.global_position.y + keening.aggro_range_px(), R5_FLOOR_TOP_Y,
		"Keening Husk's aggro circle must not reach the floor slab's top edge"
	)

	# ...and confirmed by driving the real engine along the floor's full
	# span: at no point standing on the floor may the Keening Husk leave
	# IDLE. The floor spans the room's full width, so its closest point to
	# the (stationary) Keening Husk is always directly below it — sweeping
	# the whole span is what "anywhere on the floor" means physically.
	_player = PlayerScene.instantiate()
	add_child_autofree(_player)
	_input = InputSender.new(Input)

	var x := R5_FLOOR_X0 + 8.0
	while x <= R5_FLOOR_X1 - 8.0:
		_player.global_position = Vector2(x, R5_FLOOR_TOP_Y - 1.0)
		await get_tree().physics_frame
		await get_tree().physics_frame
		assert_eq(
			keening.state, keening.State.IDLE,
			"Keening Husk left IDLE with the player standing on the floor at x=%.0f" % x
		)
		x += 20.0


## MICH-617 acceptance criterion 3 (Keening Husk half): reachable at its new
## perch and its tell is answerable from there.
func test_r5_keening_husk_tell_opens_at_its_perch_and_is_answerable() -> void:
	_room = R5Scene.instantiate()
	add_child_autofree(_room)
	_player = PlayerScene.instantiate()
	add_child_autofree(_player)

	var keening = _find_enemy("KeeningHusk")
	assert_not_null(keening, "R5's KeeningHusk marker must have spawned a real instance")

	# Standing beside the Keening Husk's own perch (the widened top ledge,
	# ledge8) — well within its 380px stationary/ranged aggro.
	_player.global_position = keening.global_position + Vector2(16.0, 0.0)
	_input = InputSender.new(Input)
	await get_tree().physics_frame

	var reached_telling := await _wait_until(func(): return keening.state == keening.State.TELLING, 300)
	assert_true(reached_telling, "the Keening Husk's tell must open once the player is on its own perch")

	var start_hp: int = _player.hp
	await _press_answer()
	await get_tree().physics_frame
	assert_eq(_player.combat.last_answer_result, "success", "the Keening Husk's tell must be answerable from its perch")
	assert_eq(_player.hp, start_hp, "a successful Answer must not damage the player")


## MICH-617 acceptance criterion 3 (Reed Husk half): reachable by walking in
## from the entry (the Reed Husk closes the remaining distance itself, same
## as before MICH-617 — only the starting distance grew).
func test_r5_reed_husk_eventually_closes_and_is_answerable() -> void:
	_room = R5Scene.instantiate()
	add_child_autofree(_room)
	_player = PlayerScene.instantiate()
	add_child_autofree(_player)
	_player.global_position = _room.get_door_spawn_position("R5_to_R4")
	_input = InputSender.new(Input)
	await get_tree().physics_frame

	var reed = _find_enemy("ReedHusk")
	assert_not_null(reed, "R5's ReedHusk marker must have spawned a real instance")

	# Walk toward the Reed Husk's ledge until it aggroes, then let it close
	# the rest of the distance and lunge on its own.
	_input.action_down("move_right")
	var aggroed := await _wait_until(func(): return reed.state != reed.State.IDLE, 400)
	_input.action_up("move_right")
	assert_true(aggroed, "walking from the entry toward Reed Husk's ledge must bring the player into its 220px aggro range")

	var reached_telling := await _wait_until(func(): return reed.state == reed.State.TELLING, 600)
	assert_true(reached_telling, "the Reed Husk must eventually close to lunge range and open its tell")

	var start_hp: int = _player.hp
	await _press_answer()
	await get_tree().physics_frame
	assert_eq(_player.combat.last_answer_result, "success", "R5's Reed Husk tell must be answerable")
	assert_eq(_player.hp, start_hp, "a successful Answer must not damage the player")
