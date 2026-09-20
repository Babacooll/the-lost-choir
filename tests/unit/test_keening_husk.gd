extends GutTest
## §5.2 Keening Husk behavioural coverage. The critical case is that a
## successful Answer unmakes the projectile *before it spawns* — H2/H6
## depend on Answer being the only valid response, not dodging.

const PlayerScene := preload("res://scenes/player.tscn")
const KeeningHuskScene := preload("res://scenes/enemies/keening_husk.tscn")

var _player: CharacterBody2D
var _keening
var _floor: StaticBody2D
var _input


func before_each() -> void:
	_floor = StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	var floor_rect := RectangleShape2D.new()
	floor_rect.size = Vector2(2000, 40)
	floor_shape.shape = floor_rect
	_floor.add_child(floor_shape)
	_floor.position = Vector2(0, 40)
	get_tree().root.add_child(_floor)
	autofree(_floor)

	_player = PlayerScene.instantiate()
	add_child_autofree(_player)
	_player.global_position = Vector2(0, 20)

	_keening = KeeningHuskScene.instantiate()
	add_child_autofree(_keening)
	_keening.global_position = Vector2(300, 18)

	_input = InputSender.new(Input)
	await get_tree().physics_frame
	await get_tree().physics_frame


func after_each() -> void:
	_input.release_all()
	_input = null
	for node in get_tree().get_nodes_in_group("projectile"):
		node.queue_free()


func _count_projectiles() -> int:
	return get_tree().get_nodes_in_group("projectile").size()


func test_stationary_never_moves_even_when_aggro() -> void:
	_keening.global_position = Vector2(200, 18)  # inside the 380 px aggro range
	var before_x: float = _keening.global_position.x
	for i in range(20):
		await get_tree().physics_frame
	assert_almost_eq(_keening.global_position.x, before_x, 0.01, "stationary — should never walk")


func test_opens_tell_immediately_once_aggro_no_closing_distance_needed() -> void:
	_keening.global_position = Vector2(370, 18)  # inside 380 px aggro range
	for i in range(5):
		await get_tree().physics_frame
	assert_eq(_keening.state, _keening.State.TELLING)


func test_unanswered_tell_spawns_projectile_that_damages_the_player() -> void:
	_keening.global_position = Vector2(100, 18)
	var start_hp: int = _player.hp
	for i in range(5):
		await get_tree().physics_frame
	assert_eq(_keening.state, _keening.State.TELLING)

	await wait_seconds(0.75)  # 700 ms tell + margin
	assert_eq(_count_projectiles(), 1, "a missed tell should spawn exactly one projectile")

	# Let the projectile travel the 100 px gap at 240 px/s (~420 ms).
	await wait_seconds(0.6)
	assert_eq(_player.hp, start_hp - 1, "the projectile must actually land on the player")
	assert_eq(_count_projectiles(), 0, "the projectile should be gone once it lands")


func test_successful_answer_means_no_projectile_is_ever_created() -> void:
	# The critical case: answering the voice must prevent the projectile
	# from ever existing, not just prevent it from landing. If a player
	# could dodge a spawned projectile and take no damage, that would pass
	# a damage-based test while failing this spec — so this test asserts
	# on projectile *existence*, not on the player's hp.
	_keening.global_position = Vector2(100, 18)
	for i in range(5):
		await get_tree().physics_frame
	assert_eq(_keening.state, _keening.State.TELLING)

	_input.action_down(&"answer")
	await get_tree().physics_frame
	_input.action_up(&"answer")
	assert_eq(_player.combat.last_answer_result, "success")

	# Wait well past when the tell would otherwise have closed.
	await wait_seconds(0.9)

	assert_eq(_count_projectiles(), 0,
		"a successful Answer must mean the projectile was never created, not merely avoided")
	assert_eq(_keening.state, _keening.State.STAGGERED)


func test_projectile_stops_at_a_wall_without_reaching_the_player() -> void:
	var wall := StaticBody2D.new()
	var wall_shape := CollisionShape2D.new()
	var wall_rect := RectangleShape2D.new()
	wall_rect.size = Vector2(20, 200)
	wall_shape.shape = wall_rect
	wall.add_child(wall_shape)
	wall.position = Vector2(50, -50)
	get_tree().root.add_child(wall)
	autofree(wall)
	await get_tree().physics_frame

	_keening.global_position = Vector2(100, 18)
	var start_hp: int = _player.hp
	for i in range(5):
		await get_tree().physics_frame
	await wait_seconds(0.75)
	assert_eq(_count_projectiles(), 1)

	await wait_seconds(0.5)
	assert_eq(_count_projectiles(), 0, "should have stopped at the wall by now")
	assert_eq(_player.hp, start_hp, "a wall between the husk and the player should block the projectile")


func test_takes_four_strikes_to_die() -> void:
	for i in range(3):
		_keening.take_strike(1)
		assert_true(is_instance_valid(_keening))
	_keening.take_strike(1)
	await get_tree().physics_frame
	await get_tree().process_frame
	assert_false(is_instance_valid(_keening), "4 damage against 4 HP should kill it")
