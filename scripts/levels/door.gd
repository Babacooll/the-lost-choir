class_name Door
extends Area2D
## Room-to-room connector built at runtime by Room from an LDtk Door entity.
## `requires_flag` empty means always open; otherwise gated on GameState
## (ARCHITECTURE.md's single-restoration-flag pattern) — this is the
## placeholder stand-in for Sustain-gated traversal (R4 ledge, R7 shortcut).

var door_id: String = ""
var target_level: String = ""
var target_door_id: String = ""
var requires_flag: String = ""
var size: Vector2 = Vector2.ZERO  # trigger footprint; position is its top-left corner

func _ready() -> void:
	if not requires_flag.is_empty():
		GameState.restoration_state_changed.connect(_on_flag_changed)
	_refresh_visual()

func is_open() -> bool:
	return GameState.is_flag_met(requires_flag)

func _on_flag_changed(_value: bool) -> void:
	_refresh_visual()

func _refresh_visual() -> void:
	var visual: Node = get_meta("visual", null)
	if visual == null:
		return
	# Barred gates dim rather than disappear — a placeholder is still meant
	# to read as "locked," not as missing geometry.
	visual.modulate.a = 1.0 if is_open() else 0.55
