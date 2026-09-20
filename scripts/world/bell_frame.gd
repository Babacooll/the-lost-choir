class_name BellFrame
extends AnimatableBody2D
## §4.1: a suspended bell-frame that descends to a low, reachable position
## while a player is sustaining within range, and rises again on ramp-out —
## carrying the player up with it if they're standing on it, which
## AnimatableBody2D gives for free (it's Godot's own moving-platform body;
## CharacterBody2D riders are carried by its motion automatically).
##
## §4.1 gives no travel-time contract for the descend/rise motion itself —
## only the 140 px trigger range and PlayerSustain's own ramp timing — so
## the position change is a direct snap tied to those, not an invented tween.

const RANGE_PX: float = 140.0

## Local offset from the authored (high/rest) position to the low/reachable
## position — authored per-instance since bell-frames sit at different
## heights, not a shared design contract.
@export var low_offset: Vector2 = Vector2(0.0, 140.0)

var _high_position: Vector2
var _player: CharacterBody2D
var _descended: bool = false


func _ready() -> void:
	add_to_group("bell_frame")
	_high_position = position
	call_deferred("_find_player")


func _find_player() -> void:
	if _player != null:
		return
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		set_player(players[0])


## Lets a test (or a future spawner) wire the player directly rather than
## relying on the deferred group lookup — same rationale as EnemyBase's.
func set_player(p: CharacterBody2D) -> void:
	_player = p


func is_descended() -> bool:
	return _descended


func _physics_process(_delta: float) -> void:
	var should_descend := _should_descend()
	if should_descend == _descended:
		return
	# Parenthesized deliberately — `a + b if c else a` parses in GDScript as
	# `a + (b if c else a)`, not `(a + b) if c else a`, which silently
	# doubled the high position on the rise-back-up branch.
	position = (_high_position + low_offset) if should_descend else _high_position
	_descended = should_descend


func _should_descend() -> bool:
	if _player == null or not ("sustain" in _player) or _player.sustain == null:
		return false
	if not _player.sustain.world_effects_active():
		return false
	return global_position.distance_to(_player.global_position) <= RANGE_PX
