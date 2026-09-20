extends GutTest
## Coverage for the checkpoint-2 debug overlay extension: it must read the
## tell-vs-input data straight from PlayerCombat and feed it to the timeline
## widget, per §11.2/§11.3's instrumentation requirement.

const PlayerScene := preload("res://scenes/player.tscn")
const TellEmitter = preload("res://scripts/combat/tell_emitter.gd")
const OverlayScene := preload("res://scenes/debug_overlay.tscn")

var _player: CharacterBody2D
var _emitter
var _overlay
var _input


func before_each() -> void:
	_player = PlayerScene.instantiate()
	add_child_autofree(_player)

	_emitter = TellEmitter.new()
	add_child_autofree(_emitter)

	# DebugOverlay is normally an autoload singleton; instantiate the scene
	# directly here instead so the test doesn't fight the real autoload.
	_overlay = OverlayScene.instantiate()
	add_child_autofree(_overlay)
	_overlay.visible = true

	_input = InputSender.new(Input)
	await get_tree().physics_frame
	await get_tree().physics_frame


func after_each() -> void:
	_input.release_all()
	_input = null


func test_overlay_plots_a_successful_answer_against_its_tell_window() -> void:
	var combat = _player.combat
	_emitter.open_tell(300.0)
	await wait_seconds(0.05)
	_input.action_down(&"answer")
	await get_tree().physics_frame
	_input.action_up(&"answer")

	assert_eq(combat.last_answer_result, "success")

	_overlay._process(0.016)
	var timeline = _overlay.tell_timeline

	assert_eq(timeline.onset_ms, combat.last_tell_onset_ms)
	assert_eq(timeline.close_ms, combat.last_tell_close_ms)
	assert_eq(timeline.press_ms, combat.last_answer_press_ms)
	assert_eq(timeline.result, "success")
	assert_eq(timeline.buffer_ms, combat.ANSWER_PRE_WINDOW_BUFFER_MS)


func test_readout_includes_hp_strike_and_answer_state() -> void:
	_overlay._process(0.016)
	assert_string_contains(_overlay.readout.text, "hp: %d" % _player.hp)
	assert_string_contains(_overlay.readout.text, "strike: idle")
	assert_string_contains(_overlay.readout.text, "answer: idle")
