extends GutTest
## MICH-615 §3: drives the real R2/R5 Room scenes with the now-live husks to
## confirm the four authored encounters are actually reachable and
## survivable, not just correctly positioned (test_enemy_spawning.gd already
## covers positions/instantiation). R5's two husks both have aggro ranges
## that reach the room's entry point (see the finding in this checkpoint's
## handback), so unlike test_r5_climb_traversal.gd (pure platforming,
## enemies neutralized there on purpose) this test drives combat instead of
## a climb.

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


func test_r5_keening_husk_tell_opens_at_entry_and_is_answerable() -> void:
	_room = R5Scene.instantiate()
	add_child_autofree(_room)
	_player = PlayerScene.instantiate()
	add_child_autofree(_player)
	_player.global_position = Vector2(32.0, 504.0)  # authored R5_to_R4 entry door position
	_input = InputSender.new(Input)
	await get_tree().physics_frame

	var keening = _find_enemy("KeeningHusk")
	assert_not_null(keening, "R5's KeeningHusk marker must have spawned a real instance")

	var reached_telling := await _wait_until(func(): return keening.state == keening.State.TELLING, 300)
	assert_true(
		reached_telling,
		"the Keening Husk's 380px aggro range must reach the player at R5's own entry point without any extra travel"
	)

	var start_hp: int = _player.hp
	await _press_answer()
	await get_tree().physics_frame
	assert_eq(_player.combat.last_answer_result, "success", "the Keening Husk's tell must be answerable from entry")
	assert_eq(_player.hp, start_hp, "a successful Answer must not damage the player")


func test_r5_reed_husk_eventually_closes_and_is_answerable() -> void:
	_room = R5Scene.instantiate()
	add_child_autofree(_room)
	_player = PlayerScene.instantiate()
	add_child_autofree(_player)
	_player.global_position = Vector2(32.0, 504.0)
	_input = InputSender.new(Input)
	await get_tree().physics_frame

	var reed = _find_enemy("ReedHusk")
	assert_not_null(reed, "R5's ReedHusk marker must have spawned a real instance")

	# No player input needed — the husk itself is what has to close distance
	# and reach lunge range from wherever it settles.
	var reached_telling := await _wait_until(func(): return reed.state == reed.State.TELLING, 600)
	assert_true(reached_telling, "the Reed Husk must eventually close to lunge range and open its tell")

	var start_hp: int = _player.hp
	await _press_answer()
	await get_tree().physics_frame
	assert_eq(_player.combat.last_answer_result, "success", "R5's Reed Husk tell must be answerable")
	assert_eq(_player.hp, start_hp, "a successful Answer must not damage the player")
