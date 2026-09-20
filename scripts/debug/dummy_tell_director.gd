extends Node
## Manual-playtest convenience for checkpoint 2: press the bound key to open a
## tell window on the scripted dummy TellEmitter, so Answer and the debug
## overlay's timeline can be exercised in a running build without a real
## enemy. Checkpoint 3 adds real enemies that drive their own tells and
## resolve their own attacks; this dummy is kept as a zero-setup way to
## exercise Answer without needing to lure a real enemy into range.

const DEFAULT_LEAD_TIME_MS: float = 520.0  # the "mashing loses" reference tell from §3.3's design intent

@export var tell_emitter_path: NodePath
@export var player_path: NodePath
@onready var _tell_emitter: Node = get_node_or_null(tell_emitter_path)
@onready var _player: Node = get_node_or_null(player_path)


func _ready() -> void:
	if _tell_emitter != null:
		_tell_emitter.tell_missed.connect(_on_tell_missed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_trigger_tell") and _tell_emitter != null:
		_tell_emitter.open_tell(DEFAULT_LEAD_TIME_MS, "dummy")
		get_viewport().set_input_as_handled()


func _on_tell_missed() -> void:
	# PlayerCombat no longer applies §3.3's failure effects generically —
	# "the attack lands" is owned by whoever opened the tell (see
	# combat.gd's register_tell_emitter). This dummy stands in for that
	# ownership the same way a real enemy would.
	if _player == null or not _player.has_method("take_hit"):
		return
	var knockback_dir := Vector2.RIGHT
	if "facing" in _player and _player.facing != 0.0:
		knockback_dir = Vector2(-_player.facing, 0.0)
	_player.take_hit(
		PlayerCombat.ANSWER_FAIL_DAMAGE, knockback_dir, PlayerCombat.ANSWER_FAIL_KNOCKBACK_PX,
		PlayerCombat.ANSWER_FAIL_HITSTUN_MS, PlayerCombat.ANSWER_FAIL_INVULN_MS
	)
