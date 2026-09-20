class_name EnemyBase
extends CharacterBody2D
## Shared state machine and tell-contract plumbing for §5's "husks of sound".
## Subclasses (Reed Husk, Keening Husk) fill in the numbers and the attack
## shape; this owns the parts every enemy shares per §5's shared rules:
## aggro, the tell lifecycle, repeat compression, and the stagger rule.
##
## Design contracts (§5). Changing a number needs a Design sign-off.

const TellEmitter = preload("res://scripts/combat/tell_emitter.gd")

# §5 shared rule 3: repeat compression.
const COMPRESSION_FACTOR: float = 0.88
const COMPRESSION_FLOOR_MS: float = 420.0
# "The counter resets after 6 s with that instance out of combat" — read here
# as 6 s elapsed since this instance's last tell, since that's the only
# per-instance clock §5 gives us to measure "out of combat" against.
const OUT_OF_COMBAT_RESET_MS: float = 6000.0

const GRAVITY: float = 1800.0

enum State { IDLE, APPROACH, TELLING, RECOVERY, STAGGERED }

var hp: int
var state: int = State.IDLE
var facing: float = -1.0

var _dead: bool = false
var _recovery_timer_ms: float = 0.0
var _tell_count: int = 0
var _ms_since_last_tell: float = INF

var _emitter: TellEmitter
var player: CharacterBody2D
# Resolved once, typed as the real class rather than chained off `player`
# (a CharacterBody2D-typed reference) — GDScript's static analyzer can trip
# on multi-level dynamic member access in some expression shapes (see
# combat.gd's history with this), so this is deliberately a direct,
# properly-typed reference instead.
var player_combat: PlayerCombat


func _ready() -> void:
	hp = max_hp()
	add_to_group("enemy")
	call_deferred("_find_player")

	_emitter = TellEmitter.new()
	add_child(_emitter)
	_emitter.tell_resolved.connect(_on_tell_resolved)
	_emitter.tell_missed.connect(_on_tell_attack_lands)


func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		player = players[0]
		if "combat" in player:
			player_combat = player.combat


## Called by Strike (duck-typed, same contract as the player's own hit
## reaction — see combat.gd's _apply_hits_to_bodies).
func take_strike(damage: int) -> void:
	if _dead:
		return
	hp -= damage
	if hp <= 0:
		_die()


func _die() -> void:
	_dead = true
	if is_instance_valid(_emitter):
		_emitter.queue_free()
	queue_free()


var _diag_ticks: int = 0

func _physics_process(delta: float) -> void:
	if _diag_ticks < 15:
		_diag_ticks += 1
		print("DIAG enemy tick #%d state=%d player=%s player_combat=%s dist=%s aggro=%s now=%s" % [
			_diag_ticks, state, player, player_combat,
			(_distance_to_player() if player != null else "n/a"), aggro_range_px(), Time.get_ticks_msec(),
		])
	if _dead or player == null:
		return

	var delta_ms := delta * 1000.0
	_tick_tell_reset_timer(delta_ms)
	_apply_gravity(delta)

	match state:
		State.IDLE:
			if _distance_to_player() <= aggro_range_px():
				state = State.APPROACH
		State.APPROACH:
			_run_approach(delta, delta_ms)
		State.TELLING:
			pass  # Waiting on the emitter's own signals.
		State.RECOVERY:
			_recovery_timer_ms -= delta_ms
			if _recovery_timer_ms <= 0.0:
				state = State.APPROACH
		State.STAGGERED:
			if not is_instance_valid(_emitter) or _emitter.stagger_ms <= 0.0:
				state = State.APPROACH

	move_and_slide()


func _run_approach(delta: float, delta_ms: float) -> void:
	var distance := _distance_to_player()
	if distance > aggro_range_px():
		state = State.IDLE
		velocity.x = 0.0
		return

	_face_player()

	if distance <= attack_range_px():
		velocity.x = 0.0
		if player_combat != null and player_combat.can_open_tell():
			_open_tell()
		# else: another enemy's tell is within its own 200 ms onset window
		# (§5 shared rule 5) — hold here and retry next tick.
	else:
		_approach_move(delta)


func _distance_to_player() -> float:
	return global_position.distance_to(player.global_position)


func _face_player() -> void:
	var dx := player.global_position.x - global_position.x
	if dx != 0.0:
		facing = signf(dx)


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y += GRAVITY * delta


## §5 shared rule 3, computed per this instance: the first two tells are
## always at base lead (so a player's first hearing of a voice is never
## compressed); the 3rd+ compresses geometrically from the base value
## (never from the previous rung, so rounding never compounds), floored.
func _next_lead_time_ms() -> float:
	_tell_count += 1
	_ms_since_last_tell = 0.0
	var base := base_tell_lead_ms()
	if _tell_count <= 2:
		return base
	var compressed := roundf(base * pow(COMPRESSION_FACTOR, _tell_count - 2))
	return maxf(COMPRESSION_FLOOR_MS, compressed)


func _tick_tell_reset_timer(delta_ms: float) -> void:
	if _ms_since_last_tell >= OUT_OF_COMBAT_RESET_MS:
		return
	_ms_since_last_tell += delta_ms
	if _ms_since_last_tell >= OUT_OF_COMBAT_RESET_MS:
		_tell_count = 0


func _open_tell() -> void:
	state = State.TELLING
	_emitter.open_tell(_next_lead_time_ms(), register_name())


func _on_tell_resolved() -> void:
	state = State.STAGGERED
	velocity.x = 0.0


func _on_tell_attack_lands() -> void:
	_resolve_attack()
	state = State.RECOVERY
	_recovery_timer_ms = post_attack_recovery_ms()


## Applies §3.3's Answer-failure effects to the player — the same numbers
## Answer itself uses on a whiff, since §5.1/§5.2's "1 damage" is that same
## contract, not a separate one. Knockback points away from this enemy.
func _apply_failure_effects_to_player() -> void:
	var away := (player.global_position - global_position)
	var knockback_dir := away.normalized() if away.length() > 0.001 else Vector2(facing, 0.0)
	player.take_hit(
		PlayerCombat.ANSWER_FAIL_DAMAGE, knockback_dir, PlayerCombat.ANSWER_FAIL_KNOCKBACK_PX,
		PlayerCombat.ANSWER_FAIL_HITSTUN_MS, PlayerCombat.ANSWER_FAIL_INVULN_MS
	)


# --- Overridden by subclasses -----------------------------------------------

func max_hp() -> int:
	return 1


func base_tell_lead_ms() -> float:
	return 0.0


func aggro_range_px() -> float:
	return 0.0


func attack_range_px() -> float:
	return aggro_range_px()


func post_attack_recovery_ms() -> float:
	return 0.0


func register_name() -> String:
	return ""


## No-op by default (a stationary ranged husk pivots but doesn't walk).
func _approach_move(_delta: float) -> void:
	velocity.x = 0.0


## Called when a tell closes unanswered — the attack actually lands.
func _resolve_attack() -> void:
	pass
