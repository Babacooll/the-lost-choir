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

## Minimum time a line stays fully legible, measured from the end of its
## 200 ms fade-in (§3.2 rule 4) — not from the line's onset. A line's
## earliest possible release-gate opening is therefore fade-in + this, i.e.
## LINE_RELEASE_GATE_MS below.
const LINE_MIN_HOLD_MS: float = 1800.0
const LINE_FADE_IN_MS: float = 200.0
const LINE_FADE_MS: float = 300.0
## Elapsed time since a line's onset at which it becomes eligible to be
## cleared by the next line's release. Reaching this mark does not clear the
## line by itself — it only opens the gate; the line still holds until the
## next line's release actually happens (§3.2 rule 4's "whichever is later").
const LINE_RELEASE_GATE_MS: float = LINE_FADE_IN_MS + LINE_MIN_HOLD_MS
const MAX_NARRATIVE_LINES: int = 4

const REGISTER_NAME := "verse_bearer"

## The approved restoration-encounter narrative (docs/narrative/vertical-slice-narrative.md
## §3.1), each within the ≤12 word / 4-line budget §7 sets.
const NARRATIVE_LINES: PackedStringArray = [
	"I was the ground note. Everything above was tuned to me.",
	"I drifted. Slowly. For years. And they followed me down.",
	"When I finally heard myself, I could not take it back.",
	"This is the pitch I have left. Answer it anyway.",
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
var _consecutive_failures: int = 0

var _note_elapsed_ms: float = 0.0
var _silence_elapsed_ms: float = 0.0

var _narrative_index: int = 0
var _line_visible: bool = false
var _line_elapsed_ms: float = 0.0
## True when the currently visible line is the last one that will ever be
## shown (no successor can arrive to release it) — only then does it fade
## itself out once its own legibility floor is reached (§3.2 rule 4's
## degenerate case: no "next line begins" event will ever come).
var _line_is_final: bool = false
var _current_line_text: String = ""

## Which of the two labels (0 = _label, 1 = _label_b) currently holds the
## line tracked by _line_visible / _line_elapsed_ms. The two labels ping-pong
## on every non-final release so an outgoing line's 300 ms fade-out can run
## on one label while the incoming line's 200 ms fade-in runs on the other —
## a genuine overlap, not a sequential hide-then-show (§3.2 rule 4).
var _active_label_index: int = 0

## The line clearing on the label _not_ currently active, mid its own
## independent 300 ms fade-out timer. Only ever set on a "next line begins"
## release — the final line's self-clear still runs through _line_elapsed_ms
## on the single active label, untouched by this.
var _outgoing_active: bool = false
var _outgoing_elapsed_ms: float = 0.0
var _outgoing_index: int = -1

@onready var _label: Label = get_node_or_null("NarrativeLayer/Label")
@onready var _label_b: Label = get_node_or_null("NarrativeLayer/LabelB")


func _ready() -> void:
	call_deferred("_find_player")
	_emitter = TellEmitterScript.new()
	add_child(_emitter)
	_emitter.tell_resolved.connect(_on_note_resolved)
	_emitter.tell_missed.connect(_on_note_missed)
	if _label != null:
		_label.hide()
	if _label_b != null:
		_label_b.hide()
	_open_note()


func _label_for(index: int) -> Label:
	return _label if index == 0 else _label_b


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
	AudioDirector.set_encounter_phrase_length(_phrase_length)
	AudioDirector.set_encounter_note_index(_note_index)
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
	_consecutive_failures += 1
	_phrase_length = _shortened_phrase_length_after_failure()
	state = State.SILENCE
	_silence_elapsed_ms = 0.0
	_maybe_release_narrative_line()  # the post-miss silence counts as a gap (§7.4)


func _complete_attempt() -> void:
	_consecutive_failures = 0
	if _phrase_length >= MAX_PHRASE_LENGTH:
		_restore()
		return
	# Phrase length is a single ladder (1..5, §7.5 as amended by PR #15): a
	# completed attempt always climbs exactly one rung from wherever
	# shortening left the player — never a snap back to base, and never a
	# jump straight into the extension track either.
	_phrase_length += 1
	_note_index = 0
	# The next note's onset is still scheduled by the running NOTE_SPACING_MS
	# timer (started when this attempt's final note opened) — an attempt
	# boundary on success is not a special pause, just a longer phrase.


func _restart_phrase() -> void:
	state = State.OFFERING
	_note_index = 0
	_open_note()


## §7.4 as amended by PR #15: the thresholds are absolute floors reached
## from wherever the player currently is, not a fixed step relative to it —
## "a player at 4 notes who fails twice drops to 2," the same target a
## player at base (3) drops to. A failure that doesn't cross a threshold
## (1st, 3rd, ...) holds the current length; it does not shorten on its own.
func _shortened_phrase_length_after_failure() -> int:
	if _consecutive_failures >= SHORTEN_TO_1_AFTER_FAILURES:
		return mini(_phrase_length, 1)
	if _consecutive_failures >= SHORTEN_TO_2_AFTER_FAILURES:
		return mini(_phrase_length, 2)
	return _phrase_length


func _restore() -> void:
	state = State.RESTORED
	GameState.restoration_complete = true
	restored.emit()


# --- Narrative delivery (§7 narrative delivery section, §11 AC#14) ---------

func _maybe_release_narrative_line() -> void:
	if _narrative_index >= MAX_NARRATIVE_LINES or _narrative_index >= NARRATIVE_LINES.size():
		return
	if _line_visible and _line_elapsed_ms < LINE_RELEASE_GATE_MS:
		return  # the current line hasn't held its full 1800 ms of legibility yet
	if _line_visible:
		# The next line begins now: the outgoing line starts its own 300 ms
		# fade-out on its label while the incoming line fades in on the other
		# one, overlapping — a true crossfade, not a hide-then-show, so there
		# is no blank frame between them (§3.2 rule 4).
		_outgoing_active = true
		_outgoing_elapsed_ms = 0.0
		_outgoing_index = _narrative_index - 1
		_active_label_index = 1 - _active_label_index
	_show_line(_narrative_index)
	_narrative_index += 1


func _show_line(index: int) -> void:
	_line_visible = true
	_line_elapsed_ms = 0.0
	_line_is_final = index + 1 >= MAX_NARRATIVE_LINES or index + 1 >= NARRATIVE_LINES.size()
	_current_line_text = NARRATIVE_LINES[index]
	var label := _label_for(_active_label_index)
	if label != null:
		label.text = _current_line_text
		label.modulate.a = 0.0
		label.show()
	line_shown.emit(index, _current_line_text)


## Only the final line's self-clear (no successor to release it) still goes
## through this — a "next line begins" release clears the outgoing line via
## the independent _outgoing_* fade in _tick_narrative instead.
func _hide_current_line() -> void:
	var index := _narrative_index - 1
	_line_visible = false
	var label := _label_for(_active_label_index)
	if label != null:
		label.hide()
	line_hidden.emit(index)


func _tick_narrative(delta_ms: float) -> void:
	if _outgoing_active:
		_outgoing_elapsed_ms += delta_ms
		var outgoing_label := _label_for(1 - _active_label_index)
		if _outgoing_elapsed_ms >= LINE_FADE_MS:
			_outgoing_active = false
			if outgoing_label != null:
				outgoing_label.hide()
			line_hidden.emit(_outgoing_index)
		elif outgoing_label != null:
			outgoing_label.modulate.a = 1.0 - clampf(_outgoing_elapsed_ms / LINE_FADE_MS, 0.0, 1.0)

	if not _line_visible:
		return
	_line_elapsed_ms += delta_ms
	var label := _label_for(_active_label_index)
	if _line_elapsed_ms < LINE_FADE_IN_MS:
		if label != null:
			label.modulate.a = clampf(_line_elapsed_ms / LINE_FADE_IN_MS, 0.0, 1.0)
		return
	if not _line_is_final or _line_elapsed_ms < LINE_RELEASE_GATE_MS:
		# Fully legible and waiting: either still inside its 1800 ms floor, or
		# past it but holding for a successor that hasn't released yet — a
		# line is a passive layer and never times itself out on a note clock.
		if label != null:
			label.modulate.a = 1.0
		return
	# The last line has no successor to release it, so once its own floor is
	# reached it fades itself out (§3.2 rule 4's degenerate case).
	var fade_elapsed_ms := _line_elapsed_ms - LINE_RELEASE_GATE_MS
	if fade_elapsed_ms >= LINE_FADE_MS:
		_hide_current_line()
		return
	if label != null:
		label.modulate.a = 1.0 - clampf(fade_elapsed_ms / LINE_FADE_MS, 0.0, 1.0)


func current_line_text() -> String:
	return _current_line_text if _line_visible else ""


func narrative_lines_delivered() -> int:
	return _narrative_index
