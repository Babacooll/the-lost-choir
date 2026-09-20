extends Node
## Autoload singleton. ARCHITECTURE.md: one restoration flag drives traversal
## gating, the seam-glow/palette lerp, and the FMOD leitmotif layer — this is
## that one flag. Gameplay Builder's Sustain/Return and restoration-encounter
## checkpoints set it; this checkpoint only reads it to gate room traversal.

signal restoration_state_changed(value: bool)

var restoration_complete: bool = false:
	set(value):
		if restoration_complete == value:
			return
		restoration_complete = value
		restoration_state_changed.emit(value)

## Looks a gate flag up by name so new gates never need new bookkeeping fields.
## An empty flag name means "ungated" per the LDtk Door schema's requires_flag.
func is_flag_met(flag_name: String) -> bool:
	if flag_name.is_empty():
		return true
	match flag_name:
		"restoration_complete":
			return restoration_complete
		_:
			push_warning("GameState: unknown gate flag '%s' — treating as unmet." % flag_name)
			return false
