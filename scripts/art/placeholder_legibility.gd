extends Node
## Placeholder legibility layer (MICH-613) — THROWAWAY. See
## docs/art/placeholder-legibility.md for the measurement, the impossibility
## bound, and the deletion procedure. Deleted whole when real art lands.
##
## This is the one script that owns the table and the toggle: elements
## declare a `role`, this singleton resolves role -> (fill, contour), and
## nothing outside this file hard-codes a placeholder colour.

## Single on/off switch. On: every covered element gets an opaque fill plus
## a 2px hard contour and drops its cold-derive. Off: apply() is a no-op and
## the scene renders exactly as it does without this layer (doc §7).
@export var enabled: bool = true

## role -> [fill, contour] hex, mirroring doc §4. Deliberately outside
## docs/art/palettes/lost-choir-slice.json — a placeholder colour that could
## be mistaken for a palette entry is a bug in this table, not a feature.
const ROLES := {
	"player": ["ffffff", "000000"],
	"reed_husk": ["ff4a3a", "000000"],
	"keening_husk": ["35d6ff", "000000"],
	"verse_bearer": ["ffe14a", "000000"],
	"bell_frame": ["b06fff", "000000"],
	"membrane": ["3cff7d", "000000"],
	"door_gated": ["ff44ab", "000000"],
	"door_open": ["05060a", "ff44ab"],
}

## Doc §3 rule 1: 2px, uniform, drawn outside the fill so it doesn't eat the
## collision silhouette.
const CONTOUR_WIDTH := 2.0


static func fill_color(role: String) -> Color:
	return Color.html(ROLES[role][0])


static func contour_color(role: String) -> Color:
	return Color.html(ROLES[role][1])


## Applies the layer to one fill polygon: opaque flat fill, cold-derive
## dropped (caller is responsible for not assigning a ShaderMaterial after
## this call), and a 2px contour child drawn behind the fill so only its
## outer edge shows as a hard outline.
func apply(polygon: Polygon2D, role: String) -> void:
	if not enabled or not ROLES.has(role):
		return
	polygon.material = null
	polygon.color = fill_color(role)

	var contour := Polygon2D.new()
	contour.name = "PlaceholderContour"
	contour.polygon = _expand(polygon.polygon, CONTOUR_WIDTH)
	contour.color = contour_color(role)
	# Behind the fill by tree order, not by sinking to a lower z (doc §3 rule
	# 6) — a lower z falls below the terrain solids at z 0 and gets painted
	# over wherever the element overlaps terrain, which is exactly where the
	# contour is the only value clearing the floor.
	contour.show_behind_parent = true
	polygon.add_child(contour)


## Every element this layer covers is an axis-aligned rectangle (doc §7
## scope list), so growing each vertex away from the centroid independently
## per axis is a correct outward offset, not just an approximation — it is
## not a general polygon-offset for arbitrary shapes.
func _expand(points: PackedVector2Array, width: float) -> PackedVector2Array:
	var centroid := Vector2.ZERO
	for p in points:
		centroid += p
	centroid /= points.size()

	var out := PackedVector2Array()
	for p in points:
		var dx := signf(p.x - centroid.x)
		var dy := signf(p.y - centroid.y)
		out.append(p + Vector2(dx, dy) * width)
	return out
