extends CanvasLayer
## In-game debug overlay. Off by default; toggled with the "toggle_debug_overlay"
## input action (F3).
##
## Checkpoint 1: panel, toggle, off-by-default wiring, plain movement readout.
## Checkpoint 2: extended with the §11.2/§11.3 tell-vs-input instrumentation —
## plots the Answer press against the tell window (incl. §3.3's pre-window
## buffer) it did or didn't land in, against the checkpoint's dummy emitter.

@onready var panel: Panel = $Panel
@onready var readout: Label = $Panel/MarginContainer/VBox/Readout
@onready var tell_timeline: Control = $Panel/MarginContainer/VBox/TellTimeline

var _player: CharacterBody2D = null

func _ready() -> void:
	visible = false
	# Autoload runs before the scene tree's other nodes are guaranteed ready;
	# defer the player lookup to the next frame.
	call_deferred("_find_player")


func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		_player = players[0]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug_overlay"):
		visible = not visible
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not visible:
		return
	if _player == null:
		_find_player()
		return

	var combat: Node = _player.combat
	var strike_text := "n/a"
	var answer_text := "n/a"
	if combat != null:
		strike_text = ["idle", "startup", "active", "recovery"][combat.strike_state]
		var resolved_note_text := "none"
		if combat.has_resolved_note():
			resolved_note_text = "%.0fms" % combat.resolved_note_timer_ms
		answer_text = "%s (resolved note: %s)" % [
			["idle", "active_pose", "recovery_whiff"][combat.answer_state],
			resolved_note_text,
		]

	readout.text = "state: %s\nvelocity: (%.1f, %.1f)\non_floor: %s\nhp: %d\nstrike: %s\nanswer: %s" % [
		_player.debug_state,
		_player.velocity.x,
		_player.velocity.y,
		_player.is_on_floor(),
		_player.hp,
		strike_text,
		answer_text,
	]

	if combat != null and tell_timeline != null:
		tell_timeline.set_data(
			combat.last_tell_onset_ms,
			combat.last_tell_close_ms,
			combat.ANSWER_PRE_WINDOW_BUFFER_MS,
			combat.last_answer_press_ms,
			combat.last_answer_result,
			combat.last_tell_transient_ms,
		)
