extends GutTest
## §4.1 Membranes — real end-to-end verification that a Sustain hold near a
## real membrane actually makes it solid, not just that a flag flips.

const PlayerScene := preload("res://scenes/player.tscn")
const MembraneScene := preload("res://scenes/world/membrane.tscn")

var _player: CharacterBody2D
var _membrane
var _input


func before_each() -> void:
	GameState.restoration_complete = true

	_player = PlayerScene.instantiate()
	add_child_autofree(_player)
	_player.global_position = Vector2(0, 0)
	_player.sustain.set_physics_process(false)  # drive manually, deterministic

	_membrane = MembraneScene.instantiate()
	add_child_autofree(_membrane)
	_membrane.global_position = Vector2(50, 0)  # 50 px away — inside the 140 px range
	_membrane.set_player(_player)

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


func test_slack_by_default() -> void:
	await get_tree().physics_frame
	assert_false(_membrane.is_taut(), "a membrane starts slack (§4.1)")


func test_tautens_while_a_player_sustains_within_range() -> void:
	_engage_sustain()
	await get_tree().physics_frame
	assert_true(_membrane.is_taut(), "a membrane within 140 px of an active Sustain should tauten")


func test_goes_slack_again_once_world_effects_release() -> void:
	_engage_sustain()
	await get_tree().physics_frame
	assert_true(_membrane.is_taut())

	_input.action_up(&"sustain")
	_tick_sustain(150.0)  # past the 120 ms ramp-out
	await get_tree().physics_frame
	assert_false(_membrane.is_taut(), "a membrane should go slack once ramp-out completes")


func test_stays_slack_outside_the_140px_range() -> void:
	_membrane.global_position = Vector2(300, 0)
	_engage_sustain()
	await get_tree().physics_frame
	assert_false(_membrane.is_taut(), "a membrane outside 140 px must not tauten")


func test_stays_slack_before_restoration() -> void:
	GameState.restoration_complete = false
	_engage_sustain()
	await get_tree().physics_frame
	assert_false(_membrane.is_taut(), "Sustain (and so membranes) must not work before restoration")


func test_a_taut_membrane_is_solid_ground_a_player_can_land_on() -> void:
	_engage_sustain()
	await get_tree().physics_frame
	assert_true(_membrane.is_taut())

	_player.set_physics_process(true)
	_player.global_position = _membrane.global_position + Vector2(0, -30)
	_player.velocity = Vector2.ZERO
	for i in range(30):
		await get_tree().physics_frame

	assert_true(_player.is_on_floor(), "a tautened membrane must actually be standable, not just flagged solid")
	assert_almost_eq(_player.global_position.y, _membrane.global_position.y - 4.0, 2.0,
		"the player's feet should rest on the membrane's top surface (4 px half-height)")
