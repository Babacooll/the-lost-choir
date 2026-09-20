extends Node
## Manual-playtest convenience for checkpoint 2: press the bound key to open a
## tell window on the scripted dummy TellEmitter, so Answer and the debug
## overlay's timeline can be exercised in a running build without a real
## enemy. Checkpoint 3 replaces the dummy (and this director) with real
## enemies driving their own tells.

const DEFAULT_LEAD_TIME_MS: float = 520.0  # the "mashing loses" reference tell from §3.3's design intent

@export var tell_emitter_path: NodePath
@onready var _tell_emitter: Node = get_node_or_null(tell_emitter_path)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_trigger_tell") and _tell_emitter != null:
		_tell_emitter.open_tell(DEFAULT_LEAD_TIME_MS)
		get_viewport().set_input_as_handled()
