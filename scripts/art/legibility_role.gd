class_name LegibilityRole
extends Polygon2D
## Tags a plain (non-WarmthVisual) fill polygon with a placeholder-legibility
## role (MICH-613, throwaway — see docs/art/placeholder-legibility.md).
## WarmthVisual nodes declare their role directly instead (they already own
## a script slot); this exists for elements — player, the husks — that don't
## run the cold-derive at all.

@export var role: String = ""


func _ready() -> void:
	PlaceholderLegibility.apply(self, role)
