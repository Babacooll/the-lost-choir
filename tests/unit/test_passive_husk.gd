extends GutTest
## MICH-615 §2: PassiveHusk's teaching-target contract — never aggros, never
## attacks, never opens a tell, dies to exactly 3 Strikes. Mirrors
## test_reed_husk.gd's structure so the two targets are exercised the same
## way.

const PlayerScene := preload("res://scenes/player.tscn")
const PassiveHuskScene := preload("res://scenes/enemies/passive_husk.tscn")

var _player: CharacterBody2D
var _passive
var _floor: StaticBody2D


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
	_player.set_physics_process(false)

	_passive = PassiveHuskScene.instantiate()
	add_child_autofree(_passive)
	# Directly on top of the player — the closest distance possible — so a
	# false aggro would show up immediately rather than needing a coincidence
	# of range.
	_passive.global_position = Vector2(0, 16)
	_passive.set_player(_player)

	await get_tree().physics_frame
	await get_tree().physics_frame


func test_never_aggros_even_standing_on_top_of_the_player() -> void:
	for i in range(60):
		await get_tree().physics_frame
	assert_eq(_passive.state, _passive.State.IDLE, "aggro range 0 must keep it in IDLE regardless of distance")


func test_never_opens_a_tell_or_damages_the_player() -> void:
	var start_hp: int = _player.hp
	for i in range(90):
		await get_tree().physics_frame
	assert_eq(_passive.state, _passive.State.IDLE, "must never reach TELLING")
	assert_eq(_player.hp, start_hp, "must never deal damage to the player")


func test_takes_three_strikes_to_die() -> void:
	_passive.take_strike(1)
	assert_true(is_instance_valid(_passive))
	_passive.take_strike(1)
	assert_true(is_instance_valid(_passive))
	_passive.take_strike(1)
	await get_tree().physics_frame
	await get_tree().process_frame
	assert_false(is_instance_valid(_passive), "3 damage against 3 HP should kill it")


func test_survives_two_strikes() -> void:
	_passive.take_strike(1)
	_passive.take_strike(1)
	await get_tree().physics_frame
	assert_true(is_instance_valid(_passive), "2 Strikes against 3 HP must not kill it")
