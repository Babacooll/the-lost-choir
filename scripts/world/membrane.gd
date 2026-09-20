class_name Membrane
extends StaticBody2D
## §4.1: a slack drum-skin disc that tautens into a solid one-way-up
## platform while a player is sustaining within range, and goes slack again
## on ramp-out — anything standing on it falls (not killed) rather than
## being carried or dropped through solid ground.
##
## The 140 px range is this object's own contract (§4.1); the timing that
## decides *when* "sustaining" is true (180 ms ramp-in, 120 ms ramp-out) is
## PlayerSustain's — this object only asks it, never re-derives it.

const RANGE_PX: float = 140.0

@onready var _shape: CollisionShape2D = $CollisionShape2D

var _player: CharacterBody2D


func _ready() -> void:
	add_to_group("membrane")
	_shape.disabled = true
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


func is_taut() -> bool:
	return not _shape.disabled


func _physics_process(_delta: float) -> void:
	_shape.disabled = not _should_be_taut()


func _should_be_taut() -> bool:
	if _player == null or not ("sustain" in _player) or _player.sustain == null:
		return false
	if not _player.sustain.world_effects_active():
		return false
	return global_position.distance_to(_player.global_position) <= RANGE_PX
