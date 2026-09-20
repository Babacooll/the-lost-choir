extends Node
## Autoload singleton "AudioDirector". Godot-native interim implementation of
## docs/audio/fmod-implementation-contract.md's bus topology, ducking,
## parameters, scheduling discipline and save/load silence rule.
##
## INTERIM SUBSTITUTION, not a silent deviation from ARCHITECTURE.md: that
## document fixes FMOD Studio via GDExtension as the real runtime. FMOD's SDK
## is proprietary and account/license-gated; this environment has no vendored
## `fmod-gdextension` binaries under `fmod/` (still a stub) and no way to
## authenticate to obtain the SDK, so it is not buildable here. This
## implements the same contract — bus topology, ducking numbers, parameter
## names, scheduling discipline, save/load silence — against Godot's native
## AudioServer/AudioStreamPlayer instead, so replacing the runtime later is a
## backend swap behind these same entry points, not a redesign.
##
## Known gap from the real contract, honestly: Godot has no real-time
## time-stretch DSP. `TellLead` scaling here uses playback-rate (pitch_scale),
## which shifts pitch as a side effect — the real FMOD implementation must
## use a pitch-preserving stretch. Likewise "schedule so the transient lands
## at window-open ±10 ms" is approximated by calling `play()` synchronously
## on the same game-clock tick the window opens (TellEmitter.open_tell), with
## no `setDelay`-equivalent DSP-clock compensation for output latency.

const BUS_TELL := "TELL"
const BUS_VOICE := "VOICE"
const BUS_VERSE := "VERSE"
const BUS_AMB := "AMB"
const BUS_SFX := "SFX"
const DUCKED_BUSES := [BUS_AMB, BUS_SFX, BUS_VOICE, BUS_VERSE]

const DUCK_DEPTH_DB := -6.0
const DUCK_ATTACK_S := 0.04
const DUCK_RELEASE_S := 0.25

const REED_BASE_LEAD_MS := 520.0
const KEENING_BASE_LEAD_MS := 700.0
const BEARER_REGISTER := "verse_bearer"

const AMB_CROSSFADE_S := 0.4
const DRONE_SWELL_S := 1.25  # bible §5.4: the drone "arrives", 1.25 s breath envelope

const ReedStream := preload("res://audio/reference/tell_reed_husk_520ms.wav")
const KeeningStream := preload("res://audio/reference/tell_keening_husk_700ms.wav")
const BearerNoteStream := preload("res://audio/reference/tell_keening_husk_700ms.wav")
const AmbColdStream := preload("res://audio/reference/amb_cold_near_silence_30s.wav")
const AmbWarmStream := preload("res://audio/reference/amb_warm_restored_30s.wav")
const SustainEngageStream := preload("res://audio/reference/verse_sustain_loopbody_3s.wav")
const SustainBreathEndStream := preload("res://audio/reference/verse_sustain_breath_end.wav")
const ReturnStream := preload("res://audio/reference/verse_return_seam.wav")

## §4's parameter table — names and semantics mirror the contract exactly.
var verse_low_drone_restored: bool = false  # global, saved
var palette_warmth: float = 0.0             # per-room, 0..1
var tell_lead_ms: float = 0.0               # per-event-instance
var tell_repeat: bool = false                # per-encounter
var breath_remaining: float = 1.0            # global, 1 -> 0
var encounter_phrase_length: int = 0         # R6
var encounter_note_index: int = 0            # R6

var _open_tell_count: int = 0  # duck source count — only real TELL-bus opens, never the bearer's
var _duck_tween: Tween

var _amb_cold_player: AudioStreamPlayer
var _amb_warm_player: AudioStreamPlayer
var _amb_crossfade_tween: Tween
var _amb_target_warm: bool = false

var _sustain_engage_player: AudioStreamPlayer


func _ready() -> void:
	_build_bus_topology()
	_build_ambience_players()
	_build_sustain_player()
	GameState.restoration_state_changed.connect(_on_restoration_state_changed)
	# Save/load silence (contract §7): if the flag is already true the moment
	# this autoload initializes — the only way that happens without a live
	# in-session restoration is a saved/restored state loading in — snap to
	# full warm silently. A live flip during play (the encounter's own
	# _restore() call) is the only path that gets the arrival swell.
	_apply_drone_state(GameState.restoration_complete, false)
	_retarget_ambience()


func _physics_process(_delta: float) -> void:
	# PaletteWarmth "shares the art lerp" (contract §4) — read live from the
	# same WarmthField checkpoint 6 built, clamped since audio has no use for
	# the visual overshoot band.
	var room := ZoneManager.current_room
	if room != null:
		set_palette_warmth(WarmthField.warmth_at(room.warmth_origin()))


# --- Bus topology -----------------------------------------------------------

func _build_bus_topology() -> void:
	for bus_name in [BUS_TELL, BUS_VOICE, BUS_VERSE, BUS_AMB, BUS_SFX]:
		_ensure_bus(bus_name)
	# TELL is inviolable (§1): no effect of any kind, never ducked, never
	# limited. Everything else routes to Master (default) and gets its
	# ducking applied per-bus via volume automation, not a bus effect.
	var voice_idx := AudioServer.get_bus_index(BUS_VOICE)
	var verse_idx := AudioServer.get_bus_index(BUS_VERSE)
	if voice_idx >= 0 and AudioServer.get_bus_effect_count(voice_idx) == 0:
		AudioServer.add_bus_effect(voice_idx, AudioEffectReverb.new())  # "amphitheater reverb"
	if verse_idx >= 0 and AudioServer.get_bus_effect_count(verse_idx) == 0:
		AudioServer.add_bus_effect(verse_idx, AudioEffectReverb.new())  # "room reverb, high send"


func _ensure_bus(bus_name: String) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		return idx
	idx = AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")
	return idx


# --- Tells: scheduling, TellLead time-stretch, dry-channel routing ---------

## Called from TellEmitter._route_to_dry_channel() at the exact moment
## open_tell() sets the window — same game-clock tick the window opens, per
## §5 "the game clock owns the window."
func play_tell(emitter: TellEmitter) -> void:
	tell_lead_ms = emitter.lead_time_ms
	var is_bearer := emitter.register == BEARER_REGISTER

	var stream: AudioStream
	var base_lead_ms: float
	var bus: String
	match emitter.register:
		"percussive":
			stream = ReedStream
			base_lead_ms = REED_BASE_LEAD_MS
			bus = BUS_TELL
		"keening":
			stream = KeeningStream
			base_lead_ms = KEENING_BASE_LEAD_MS
			bus = BUS_TELL
		BEARER_REGISTER:
			stream = BearerNoteStream
			base_lead_ms = KEENING_BASE_LEAD_MS
			bus = BUS_VOICE  # wet — an offer, not an attack (contract §8)
		_:
			return

	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus
	# TellLead time-stretch (contract §4.1): the whole gesture must occupy the
	# actual lead, never truncated or padded. Godot has no pitch-preserving
	# time-stretch, so this scales playback rate instead (pitch shifts as a
	## documented side effect of the interim substitution).
	if emitter.lead_time_ms > 0.0:
		player.pitch_scale = base_lead_ms / emitter.lead_time_ms
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

	if not is_bearer:
		# Only real TELL-bus opens are a duck source (§2) — the bearer's
		# notes are deliberately not TELL and must not duck anything by
		# virtue of merely being a tell.
		_open_tell_count += 1
		if _open_tell_count == 1:
			_start_duck()
		emitter.tell_resolved.connect(_on_tell_closed.bind(emitter), CONNECT_ONE_SHOT)
		emitter.tell_missed.connect(_on_tell_closed.bind(emitter), CONNECT_ONE_SHOT)


func _on_tell_closed(_emitter: TellEmitter) -> void:
	_open_tell_count = maxi(0, _open_tell_count - 1)
	if _open_tell_count == 0:
		_release_duck()


func _start_duck() -> void:
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = create_tween()
	for bus_name in DUCKED_BUSES:
		var idx := AudioServer.get_bus_index(bus_name)
		if idx >= 0:
			_duck_tween.parallel().tween_method(
				func(db: float): AudioServer.set_bus_volume_db(idx, db),
				AudioServer.get_bus_volume_db(idx), DUCK_DEPTH_DB, DUCK_ATTACK_S
			)


func _release_duck() -> void:
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = create_tween()
	for bus_name in DUCKED_BUSES:
		var idx := AudioServer.get_bus_index(bus_name)
		if idx >= 0:
			_duck_tween.parallel().tween_method(
				func(db: float): AudioServer.set_bus_volume_db(idx, db),
				AudioServer.get_bus_volume_db(idx), 0.0, DUCK_RELEASE_S
			)


func is_ducking() -> bool:
	return _open_tell_count > 0


# --- Verse drone (VerseLowDroneRestored) — save/load silence ---------------

func _on_restoration_state_changed(value: bool) -> void:
	_apply_drone_state(value, true)


## allow_swell=false is the save/load-silence path (contract §7): the world
## must start warm with the interval already present, no fade-in, no replay
## of the restoration event. allow_swell=true is a live in-session flip.
func _apply_drone_state(restored: bool, allow_swell: bool) -> void:
	verse_low_drone_restored = restored
	_retarget_ambience(allow_swell)


func _build_ambience_players() -> void:
	_amb_cold_player = AudioStreamPlayer.new()
	_amb_cold_player.stream = AmbColdStream
	_amb_cold_player.bus = BUS_AMB
	_amb_cold_player.volume_db = 0.0
	if _amb_cold_player.stream is AudioStreamWAV:
		_amb_cold_player.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD

	_amb_warm_player = AudioStreamPlayer.new()
	_amb_warm_player.stream = AmbWarmStream
	_amb_warm_player.bus = BUS_AMB
	_amb_warm_player.volume_db = -80.0
	if _amb_warm_player.stream is AudioStreamWAV:
		_amb_warm_player.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD

	add_child(_amb_cold_player)
	add_child(_amb_warm_player)
	# Leitmotif/ambience is zone-scoped (contract §6): both players start
	# once here, for the lifetime of this autoload, and are only ever
	# crossfaded by volume from this point on — never stopped, restarted or
	# re-triggered by a room transition, which is what phase-continuity
	# across R6 -> R5 -> R4 actually requires.
	_amb_cold_player.play()
	_amb_warm_player.play()


## Called by ZoneManager.travel() on every room transition, and by the
## restoration flag flipping. Ambience *layers* crossfade at doors (400 ms,
## equal-power) — the drone bed itself never restarts because the warm
## player has been continuously playing since _ready().
func on_room_entered(room: Room) -> void:
	_retarget_ambience(true, room)


func _retarget_ambience(allow_swell: bool = true, room: Room = null) -> void:
	var target_room: Room = room if room != null else ZoneManager.current_room
	var target_warm := verse_low_drone_restored or (target_room != null and target_room.pin_warmth)
	if target_warm == _amb_target_warm and _amb_crossfade_tween != null and _amb_crossfade_tween.is_valid():
		return
	_amb_target_warm = target_warm

	var duration := DRONE_SWELL_S if (target_warm and allow_swell) else AMB_CROSSFADE_S
	if _amb_crossfade_tween != null and _amb_crossfade_tween.is_valid():
		_amb_crossfade_tween.kill()
	if not allow_swell:
		# Save/load silence: snap instantly, no envelope of any kind.
		_amb_cold_player.volume_db = -80.0 if target_warm else 0.0
		_amb_warm_player.volume_db = 0.0 if target_warm else -80.0
		return
	_amb_crossfade_tween = create_tween()
	_amb_crossfade_tween.set_parallel(true)
	# Equal-power crossfade: linear volume_db ramp approximates it closely
	# enough for placeholder loops of similar spectral content.
	_amb_crossfade_tween.tween_property(_amb_cold_player, "volume_db", -80.0 if target_warm else 0.0, duration)
	_amb_crossfade_tween.tween_property(_amb_warm_player, "volume_db", 0.0 if target_warm else -80.0, duration)


# --- Sustain (engage partial, breath, ramp-out) -----------------------------

func _build_sustain_player() -> void:
	_sustain_engage_player = AudioStreamPlayer.new()
	_sustain_engage_player.stream = SustainEngageStream
	_sustain_engage_player.bus = BUS_VERSE
	add_child(_sustain_engage_player)


## Called directly from PlayerSustain the instant ramp-in completes and the
## world effect arms (checkpoint 5) — same call, same tick, so the audio
## partial cannot drift from the gate it is the readout for.
func on_sustain_engaged() -> void:
	_sustain_engage_player.play()


func on_sustain_released() -> void:
	pass  # ramp-out is silence-by-release (bible §3); nothing to trigger.


func on_sustain_breath_exhausted() -> void:
	var player := AudioStreamPlayer.new()
	player.stream = SustainBreathEndStream
	player.bus = BUS_VERSE
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func set_breath_remaining(fraction: float) -> void:
	breath_remaining = fraction


# --- Return ------------------------------------------------------------------

func on_return_executed() -> void:
	var player := AudioStreamPlayer.new()
	player.stream = ReturnStream
	player.bus = BUS_VERSE
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


# --- R6 encounter parameters -------------------------------------------------

func set_encounter_phrase_length(length: int) -> void:
	encounter_phrase_length = length


func set_encounter_note_index(index: int) -> void:
	encounter_note_index = index


# --- Palette warmth (shared with the art lerp, checkpoint 6) ----------------

func set_palette_warmth(w: float) -> void:
	palette_warmth = clampf(w, 0.0, 1.0)
