class_name Projectile
extends Node2D
## Keening Husk's ranged attack (§5.2): travels at a constant velocity until
## it hits a wall or the player. A raycast sweep each tick, not an Area2D —
## this codebase's Strike hitbox found Area2D overlap detection unreliable
## in ways that were never fully root-caused; a direct physics query is the
## pattern already proven to work here.
##
## Only ever created from KeeningHusk._resolve_attack(), which only runs on
## an unanswered tell (see EnemyBase._on_tell_attack_lands / tell_missed) —
## a successful Answer means this node is never instantiated at all.

const MAX_LIFETIME_MS: float = 4000.0  # safety net against an unbounded travel; not a §5 value

var velocity: Vector2 = Vector2.ZERO
var target: CharacterBody2D
var shooter: CharacterBody2D

var _age_ms: float = 0.0


func _ready() -> void:
	add_to_group("projectile")


func _physics_process(delta: float) -> void:
	_age_ms += delta * 1000.0
	if _age_ms > MAX_LIFETIME_MS:
		queue_free()
		return

	var motion := velocity * delta
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + motion)
	if shooter != null:
		query.exclude = [shooter.get_rid()]
	var hit := space_state.intersect_ray(query)

	if not hit.is_empty():
		if target != null and hit.collider == target and target.has_method("take_hit"):
			var dir := velocity.normalized() if velocity.length() > 0.001 else Vector2.RIGHT
			target.take_hit(
				PlayerCombat.ANSWER_FAIL_DAMAGE, dir, PlayerCombat.ANSWER_FAIL_KNOCKBACK_PX,
				PlayerCombat.ANSWER_FAIL_HITSTUN_MS, PlayerCombat.ANSWER_FAIL_INVULN_MS
			)
		queue_free()  # a wall, or the player — either way, this is where it stops
		return

	global_position += motion
