extends GutTest
## Behavioural coverage for §3.1's ceiling-corner correction: a jump that
## clips a ceiling corner within a 4 px horizontal tolerance is nudged
## sideways rather than stopped. Exercises actual physics/collision, not just
## the CORNER_CORRECTION_PX constant — a regression in
## scripts/player/player.gd:_try_corner_correction must fail these.

const PlayerScene := preload("res://scenes/player.tscn")

var _player: CharacterBody2D
var _obstacle: StaticBody2D

func before_each() -> void:
	_player = PlayerScene.instantiate()
	add_child_autofree(_player)


func after_each() -> void:
	if is_instance_valid(_obstacle):
		_obstacle.queue_free()
	_obstacle = null


func _make_ceiling_obstacle(pos: Vector2, size: Vector2) -> void:
	_obstacle = StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	_obstacle.add_child(shape)
	_obstacle.position = pos
	get_tree().root.add_child(_obstacle)
	autofree(_obstacle)


func _settle_physics() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame


func test_left_corner_blocked_centre_clear_moving_left_nudges_right() -> void:
	# Player collider top edge is at local y = -40 (18x40, origin at feet).
	# Leading (left) corner sits at x = -9. A 4 px-wide sliver over just that
	# corner leaves the centre (x = 0) clear.
	_player.global_position = Vector2(0, 0)
	_player.velocity = Vector2(-100, -200)  # moving left, rising
	_make_ceiling_obstacle(Vector2(-9, -46), Vector2(4, 10))
	await _settle_physics()

	var before_x: float = _player.global_position.x
	_player._try_corner_correction(0.016)

	assert_gt(_player.global_position.x, before_x,
		"leading corner blocked, centre clear: should nudge right, away from the obstruction")


func test_right_corner_blocked_centre_clear_moving_right_nudges_left() -> void:
	_player.global_position = Vector2(0, 0)
	_player.velocity = Vector2(100, -200)  # moving right, rising
	_make_ceiling_obstacle(Vector2(9, -46), Vector2(4, 10))
	await _settle_physics()

	var before_x: float = _player.global_position.x
	_player._try_corner_correction(0.016)

	assert_lt(_player.global_position.x, before_x,
		"leading corner blocked, centre clear: should nudge left, away from the obstruction")


func test_centre_blocked_is_a_real_bonk_not_a_sideways_nudge() -> void:
	# A wide ceiling directly overhead is genuine contact, not a corner clip —
	# must not move the player sideways (let alone into the obstruction).
	_player.global_position = Vector2(0, 0)
	_player.velocity = Vector2(100, -200)
	_make_ceiling_obstacle(Vector2(0, -46), Vector2(40, 10))
	await _settle_physics()

	var before_x: float = _player.global_position.x
	_player._try_corner_correction(0.016)

	assert_eq(_player.global_position.x, before_x,
		"centre blocked is a real ceiling contact: must not be nudged sideways")


func test_wide_obstruction_beyond_tolerance_is_not_nudged_through() -> void:
	# Leading corner (x = 9) is blocked and centre (x = 0) is clear, but the
	# obstruction spans x = 3..33 — wider than the 4 px tolerance, so nudging
	# CORNER_CORRECTION_PX (to x = 5) would still land inside it. Must not
	# move the player through a real wall.
	_player.global_position = Vector2(0, 0)
	_player.velocity = Vector2(100, -200)
	_make_ceiling_obstacle(Vector2(18, -46), Vector2(30, 10))
	await _settle_physics()

	var before_x: float = _player.global_position.x
	_player._try_corner_correction(0.016)

	assert_eq(_player.global_position.x, before_x,
		"obstruction wider than the 4 px tolerance must not be nudged through")
