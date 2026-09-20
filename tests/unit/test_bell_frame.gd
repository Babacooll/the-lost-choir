extends GutTest
## §4.1 Bell-frames — real end-to-end verification that a Sustain hold near
## a real bell-frame actually lowers it into a reachable, standable
## platform, not just that a flag flips.

const PlayerScene := preload("res://scenes/player.tscn")
const BellFrameScene := preload("res://scenes/world/bell_frame.tscn")

var _player: CharacterBody2D
var _bell
var _input


func before_each() -> void:
	GameState.restoration_complete = true

	_player = PlayerScene.instantiate()
	add_child_autofree(_player)
	_player.global_position = Vector2(0, 0)
	_player.sustain.set_physics_process(false)

	_bell = BellFrameScene.instantiate()
	# Position and low_offset must be set BEFORE the node enters the tree —
	# _ready() captures the authored (high/rest) position from wherever the
	# node sits at that moment, matching room.gd's real spawn order
	# (position set, then add_child), not the reverse.
	_bell.position = Vector2(50, 0)
	_bell.low_offset = Vector2(0, 100)
	add_child_autofree(_bell)
	_bell.set_player(_player)

	_input = InputSender.new(Input)
	await get_tree().physics_frame


func after_each() -> void:
	_input.release_all()
	_input = null
	GameState.restoration_complete = false


## Steps in small (1 ms) increments — a single huge-delta call would consume
## the whole ramp window on a state transition alone instead of accumulating
## hold time within the newly-entered state, same pitfall real per-frame
## engine ticks avoid by construction.
func _tick_sustain(ms: float) -> void:
	for i in range(int(round(ms))):
		_player.sustain._physics_process(0.001)


func _engage_sustain() -> void:
	_input.action_down(&"sustain")
	_tick_sustain(200.0)  # past the 180 ms ramp-in


func test_rests_at_its_authored_high_position_by_default() -> void:
	await get_tree().physics_frame
	assert_false(_bell.is_descended())
	assert_eq(_bell.position.y, 0.0)


func test_descends_within_range_while_sustaining() -> void:
	_engage_sustain()
	await get_tree().physics_frame
	assert_true(_bell.is_descended(), "a bell-frame within 140 px of an active Sustain should descend (§4.1)")
	assert_eq(_bell.position.y, 100.0, "should descend to its authored low position")


func test_rises_again_on_ramp_out() -> void:
	_engage_sustain()
	await get_tree().physics_frame
	assert_true(_bell.is_descended())

	_input.action_up(&"sustain")
	_tick_sustain(150.0)
	await get_tree().physics_frame
	assert_false(_bell.is_descended(), "a bell-frame should rise again once ramp-out completes")
	assert_eq(_bell.position.y, 0.0)


func test_stays_at_high_position_outside_the_140px_range() -> void:
	_bell.global_position = Vector2(300, 0)
	_engage_sustain()
	await get_tree().physics_frame
	assert_false(_bell.is_descended(), "a bell-frame outside 140 px must not descend")


func test_a_descended_bell_frame_is_solid_ground_a_player_can_land_on() -> void:
	_engage_sustain()
	await get_tree().physics_frame
	assert_true(_bell.is_descended())

	_player.set_physics_process(true)
	_player.global_position = _bell.global_position + Vector2(0, -30)
	_player.velocity = Vector2.ZERO
	for i in range(30):
		await get_tree().physics_frame

	assert_true(_player.is_on_floor(), "a descended bell-frame must actually be standable")
	assert_almost_eq(_player.global_position.y, _bell.global_position.y - 6.0, 2.0,
		"the player's feet should rest on the bell-frame's top surface (6 px half-height)")


func test_carries_a_riding_player_up_when_it_rises() -> void:
	_engage_sustain()
	await get_tree().physics_frame
	assert_true(_bell.is_descended())

	_player.set_physics_process(true)
	_player.global_position = _bell.global_position + Vector2(0, -30)
	_player.velocity = Vector2.ZERO
	for i in range(30):
		await get_tree().physics_frame
	assert_true(_player.is_on_floor(), "sanity: the player is resting on the descended bell-frame")

	var player_y_before: float = _player.global_position.y
	_input.action_up(&"sustain")
	_tick_sustain(150.0)  # past the 120 ms ramp-out — the frame rises
	for i in range(10):
		await get_tree().physics_frame

	assert_lt(_bell.global_position.y, 0.0 + 30.0,
		"sanity: the frame actually rose back toward its high position")
	assert_lt(_player.global_position.y, player_y_before,
		"a player standing on the bell-frame should be carried up with it (§4.1)")
