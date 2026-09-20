extends GutTest
## Checkpoint 2's manual-playtest dummy now owns applying §3.3's failure
## effects on a miss (PlayerCombat itself no longer does — see combat.gd's
## register_tell_emitter). This is the one thing that changed about it in
## checkpoint 3, so it's the one thing worth a dedicated test.

const PlayerScene := preload("res://scenes/player.tscn")
const TellEmitter = preload("res://scripts/combat/tell_emitter.gd")
const DummyTellDirector = preload("res://scripts/debug/dummy_tell_director.gd")

var _player: CharacterBody2D
var _emitter
var _director


func before_each() -> void:
	_player = PlayerScene.instantiate()
	add_child_autofree(_player)

	_emitter = TellEmitter.new()
	add_child_autofree(_emitter)

	_director = DummyTellDirector.new()
	# Export paths must be set before the director enters the tree — its
	# @onready vars resolve them at _ready(), which fires the instant
	# add_child runs.
	_director.tell_emitter_path = _emitter.get_path()
	_director.player_path = _player.get_path()
	add_child_autofree(_director)

	await get_tree().physics_frame
	await get_tree().physics_frame


func test_dummy_director_applies_failure_effects_on_miss() -> void:
	var start_hp: int = _player.hp
	_emitter.open_tell(40.0)

	await wait_seconds(0.12)

	assert_eq(_player.hp, start_hp - 1)
	assert_true(_player.hitstun_timer_ms > 0.0)
