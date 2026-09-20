class_name KeeningHusk
extends EnemyBase
## §5.2 — keening / high register, ranged. Stationary; pivots to face.
## Critical behavior: a successful Answer unmakes the projectile before it
## spawns — the projectile only ever gets created from _resolve_attack(),
## which only runs on tell_missed (see EnemyBase._on_tell_attack_lands).
## tell_resolved (a successful Answer) never reaches this method, so
## answering the voice is the only way the projectile never exists at all —
## not a matter of it spawning and then being cancelled or dodged.

const Projectile = preload("res://scripts/enemies/projectile.gd")

const TELL_LEAD_MS: float = 700.0
const PROJECTILE_SPEED_PX_S: float = 240.0
const HP: int = 4
const POST_ATTACK_RECOVERY_MS: float = 900.0
const AGGRO_RANGE_PX: float = 380.0


func max_hp() -> int:
	return HP


func base_tell_lead_ms() -> float:
	return TELL_LEAD_MS


func aggro_range_px() -> float:
	return AGGRO_RANGE_PX


func attack_range_px() -> float:
	# Stationary and ranged: it attacks as soon as it notices the player,
	# it never needs to close distance.
	return AGGRO_RANGE_PX


func post_attack_recovery_ms() -> float:
	return POST_ATTACK_RECOVERY_MS


func register_name() -> String:
	return "keening"


func _resolve_attack() -> void:
	var projectile := Projectile.new()
	get_parent().add_child(projectile)
	projectile.global_position = global_position
	projectile.velocity = Vector2(facing * PROJECTILE_SPEED_PX_S, 0.0)
	projectile.target = player
	projectile.shooter = self
