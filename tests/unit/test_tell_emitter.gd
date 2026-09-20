extends GutTest
## Coverage for the scripted dummy tell emitter (scripts/combat/tell_emitter.gd):
## §5 shared rule 1 — the window opens at onset and stays open until the lead
## time elapses, with no separate narrow sub-window.

const TellEmitter = preload("res://scripts/combat/tell_emitter.gd")

var _emitter: Node2D


func before_each() -> void:
	_emitter = TellEmitter.new()
	add_child_autofree(_emitter)


func test_open_tell_sets_onset_and_close() -> void:
	_emitter.open_tell(300.0)
	assert_true(_emitter.is_open())
	assert_almost_eq(_emitter.close_ms() - _emitter.onset_ms(), 300.0, 0.01)


func test_window_closes_and_emits_tell_missed_when_unanswered() -> void:
	watch_signals(_emitter)
	_emitter.open_tell(40.0)  # short lead time so the test doesn't need to wait long

	await wait_seconds(0.12)

	assert_false(_emitter.is_open(), "window should have closed on its own")
	assert_signal_emitted(_emitter, "tell_missed")
	assert_signal_not_emitted(_emitter, "tell_resolved")


func test_resolve_closes_the_window_and_emits_tell_resolved_not_missed() -> void:
	watch_signals(_emitter)
	_emitter.open_tell(40.0)
	_emitter.resolve(900.0)

	assert_false(_emitter.is_open())
	assert_signal_emitted(_emitter, "tell_resolved")

	await wait_seconds(0.12)
	assert_signal_not_emitted(_emitter, "tell_missed",
		"a resolved tell must not also report itself missed once its lead time elapses")


func test_resolve_stages_the_stub_stagger_timer() -> void:
	_emitter.open_tell(40.0)
	_emitter.resolve(900.0)
	assert_almost_eq(_emitter.stagger_ms, 900.0, 0.01)
