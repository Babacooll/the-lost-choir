class_name ReedHusk
extends EnemyBase
## §5.1 — percussive / throat register, melee. Closes distance on foot, then
## a forward lunge. "1 Strike = 1, 1 Return = 3" is just HP math (3) — Return
## itself is checkpoint 4.

const TELL_LEAD_MS: float = 520.0
const LUNGE_REACH_PX: float = 40.0
const HP: int = 3
const POST_ATTACK_RECOVERY_MS: float = 700.0
const AGGRO_RANGE_PX: float = 220.0
const WALK_SPEED_PX_S: float = 60.0


func max_hp() -> int:
	return HP


func base_tell_lead_ms() -> float:
	return TELL_LEAD_MS


func aggro_range_px() -> float:
	return AGGRO_RANGE_PX


func attack_range_px() -> float:
	return LUNGE_REACH_PX


func post_attack_recovery_ms() -> float:
	return POST_ATTACK_RECOVERY_MS


func register_name() -> String:
	return "percussive"


func _approach_move(delta: float) -> void:
	velocity.x = facing * WALK_SPEED_PX_S
	# "Does not jump" — no vertical input here; gravity (EnemyBase) handles
	# the rest, so a Reed walking off a ledge simply falls.


func _resolve_attack() -> void:
	# The lunge's reach is checked at the moment the tell resolves, not
	# animated as its own travel — the tell lead *is* the wind-up, and §5.1
	# gives the lunge a reach, not a duration.
	if _distance_to_player() <= LUNGE_REACH_PX:
		_apply_failure_effects_to_player()
