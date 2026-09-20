class_name RestorationEncounter
extends Node2D
## §7: the restoration encounter (R6) — the slice's thesis. It is **not** a
## boss fight: no HP, no damage, no fail state, no timer that can end badly
## (§11 AC#5). The Verse-bearer offers a phrase of notes — each note a tell
## against the same Answer verb combat uses, reusing the tell/window
## machinery from checkpoints 2-3 rather than a new input path.
##
## Design contracts (§7). Changing a number needs a Design sign-off.

const TellEmitterScript = preload("res://scripts/combat/tell_emitter.gd")

const NOTE_LEAD_MS: float = 700.0
const NOTE_SPACING_MS: float = 1100.0  # onset-to-onset; load-bearing, does not move (§7 narrative delivery)
const MISS_SILENCE_MS: float = 1400.0

const BASE_PHRASE_LENGTH: int = 3
const MAX_PHRASE_LENGTH: int = 5
const SHORTEN_TO_2_AFTER_FAILURES: int = 2
const SHORTEN_TO_1_AFTER_FAILURES: int = 4

const LINE_MIN_HOLD_MS: float = 1800.0
const LINE_FADE_MS: float = 300.0
const MAX_NARRATIVE_LINES: int = 4

const REGISTER_NAME := "verse_bearer"

## Delivery mechanics (slot, hold time, index persistence, silent gap) are
## this checkpoint's scope; the words themselves are Narrative's — these are
## placeholders standing in for a later content pass, each within the ≤12
## word / 4-line budget §7 sets.
const PLACEHOLDER_LINES: PackedStringArray = [
	"It sang until the seam went dark, then simply stopped mid-phrase.",
	"Not broken. Not asleep. Only unanswered, for longer than it could bear.",
	"It still remembers the shape of being heard, and is asking again.",
	"Answer it, and the rest of this room remembers too.",
]

enum State { OFFERING, SILENCE, RESTORED }

signal restored()
signal line_shown(index: int, text: String)
signal line_hidden(index: int)

var state: int = State.OFFERING

var player: CharacterBody2D

var _emitter: TellEmitterScript

var _phrase_length: int = BASE_PHRASE_LENGTH
var _note_index: int = 0
var _consecutive_successes: int = 0
var _consecutive_failures: int = 0

var _note_elapsed_ms: float = 0.0
var _silence_elapsed_ms: float = 0.0

var _narrative_index: int = 0
var _line_visible: bool = false
var _line_hold_remaining_ms: float = 0.0
var _current_line_text: String = ""

@onready var _label: Label = get_node_or_null("NarrativeLayer/Label")


func _ready() -> void:
	call_deferred("_find_player")
	_emitter = TellEmitterScript.new()
	add_child(_emitter)
	_emitter.tell_resolved.connect(_on_note_resolved)
	_emitter.tell_missed.connect(_on_note_missed)
	if _label != null:
		_label.hide()
	_open_note()


func _find_player() -> void:
	if player != null:
		return
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		set_player(players[0])


## Lets a test (or a future spawner) wire the player directly rather than
## relying on the deferred group lookup — same rationale as EnemyBase's.
func set_player(p: CharacterBody2D) -> void:
	player = p


func _physics_process(delta: float) -> void:
	var delta_ms := delta * 1000.0

	match state:
		State.OFFERING:
			_note_elapsed_ms += delta_ms
			if _note_elapsed_ms >= NOTE_SPACING_MS:
				_open_note()
		State.SILENCE:
			_silence_elapsed_ms += delta_ms
			if _silence_elapsed_ms >= MISS_SILENCE_MS:
				_restart_phrase()
		State.RESTORED:
			pass

	_tick_narrative(delta_ms)


func _open_note() -> void:
	_note_elapsed_ms = 0.0
	_emitter.open_tell(NOTE_LEAD_MS, REGISTER_NAME)


func _on_note_resolved() -> void:
	if state != State.OFFERING:
		return
	_note_index += 1
	# A resolved note opens a gap before the next note's onset (§7's literal
	# 400 ms gap, or the attempt-boundary gap on the phrase's last note) —
	# a candidate release point for the queued narrative line either way.
	_maybe_release_narrative_line()
	if _note_index >= _phrase_length:
		_complete_attempt()
	# else: the next note opens on schedule via _physics_process's
	# NOTE_SPACING_MS timer, anchored to this note's own onset — a note
	# answered early must not pull the next one's onset forward (§7's
	# "the 1100 ms spacing does not move").


func _on_note_missed() -> void:
	if state != State.OFFERING:
		return
	_consecutive_successes = 0
	_consecutive_failures += 1
	_phrase_length = _next_phrase_length()
	state = State.SILENCE
	_silence_elapsed_ms = 0.0
	_maybe_release_narrative_line()  # the post-miss silence counts as a gap (§7.4)


func _complete_attempt() -> void:
	if _phrase_length >= MAX_PHRASE_LENGTH:
		_restore()
		return
	_consecutive_failures = 0
	_consecutive_successes += 1
	_phrase_length = _next_phrase_length()
	_note_index = 0
	# The next note's onset is still scheduled by the running NOTE_SPACING_MS
	# timer (started when this attempt's final note opened) — an attempt
	# boundary on success is not a special pause, just a longer phrase.


func _restart_phrase() -> void:
	state = State.OFFERING
	_note_index = 0
	_open_note()


func _next_phrase_length() -> int:
	if _consecutive_failures >= SHORTEN_TO_1_AFTER_FAILURES:
		return 1
	if _consecutive_failures >= SHORTEN_TO_2_AFTER_FAILURES:
		return 2
	return mini(MAX_PHRASE_LENGTH, BASE_PHRASE_LENGTH + _consecutive_successes)


func _restore() -> void:
	state = State.RESTORED
	GameState.restoration_complete = true
	restored.emit()


# --- Narrative delivery (§7 narrative delivery section, §11 AC#14) ---------

func _maybe_release_narrative_line() -> void:
	if _narrative_index >= MAX_NARRATIVE_LINES or _narrative_index >= PLACEHOLDER_LINES.size():
		return
	if _line_hold_remaining_ms > 0.0:
		return  # the previous line's minimum hold hasn't expired — try the next gap
	_show_line(_narrative_index)
	_narrative_index += 1


func _show_line(index: int) -> void:
	_line_visible = true
	_line_hold_remaining_ms = LINE_MIN_HOLD_MS
	_current_line_text = PLACEHOLDER_LINES[index]
	if _label != null:
		_label.text = _current_line_text
		_label.modulate.a = 1.0
		_label.show()
	line_shown.emit(index, _current_line_text)


func _tick_narrative(delta_ms: float) -> void:
	if not _line_visible:
		return
	_line_hold_remaining_ms -= delta_ms
	if _line_hold_remaining_ms <= LINE_FADE_MS:
		var fade_t := clampf(_line_hold_remaining_ms / LINE_FADE_MS, 0.0, 1.0)
		if _label != null:
			_label.modulate.a = fade_t
	if _line_hold_remaining_ms <= 0.0:
		_line_visible = false
		if _label != null:
			_label.hide()
		line_hidden.emit(_narrative_index - 1)


func current_line_text() -> String:
	return _current_line_text if _line_visible else ""


func narrative_lines_delivered() -> int:
	return _narrative_index
