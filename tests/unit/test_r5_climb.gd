extends GutTest
## Geometric regression coverage for R5's climb, encoding the exact class of
## defect Reviewer found across three rounds on this room: a jump can be
## reachable (right apex height) and standable (headroom above the landing
## spot) and still have zero valid launch position, because some OTHER
## platform sits between the launch platform and the target and is only
## reachable — but not landable — at the wrong moment (an overshoot into a
## third-party obstruction underside). This reads R5's actual SolidRects
## from the LDtk data and, for every step in the climb order, computes
## whether there exists an x-position on the launch platform from which the
## rise needed to reach the target's height does NOT first collide with any
## OTHER platform's underside.

const PLAYER_HALF_WIDTH := 9.0
const PLAYER_HEIGHT := 40.0
const PLATFORM_THICKNESS := 16.0
const MAX_APEX := 59.0  # matches Reviewer's measured apex (design contract is 56)

# Climb order bottom to top, matched to each SolidRect by its (x0,top) —
# identifies which of R5's several same-shaped rects is "rung2" etc. without
# depending on LDtk entity naming (SolidRects are anonymous).
const CLIMB_ORDER := [
	Vector2(0, 528),     # floor
	Vector2(273, 478),   # rung1
	Vector2(160, 428),   # ledge1
	Vector2(69, 378),    # rung2
	Vector2(19, 328),    # ledge2
	Vector2(124, 278),   # rung3
	Vector2(184, 228),   # ledge3
	Vector2(263, 178),   # rung4
	Vector2(139, 128),   # ledge4
]


func _load_platforms() -> Array:
	var level := LDtkProject.get_level("R5_Colonnade")
	var platforms := []
	for entity in LDtkProject.get_entities(level, "SolidRect"):
		var pos := LDtkProject.entity_position(entity)
		var width: float = entity.get("width", 16.0)
		platforms.append({"x0": pos.x, "x1": pos.x + width, "top": pos.y})
	return platforms


## For a player centred at x, could its collision box overlap [ox0,ox1]?
func _overlaps(x: float, ox0: float, ox1: float) -> bool:
	return x + PLAYER_HALF_WIDTH > ox0 and x - PLAYER_HALF_WIDTH < ox1


## Does a platform at other_top block a player centred at x on from_top from
## ever reaching a target above it, given the room's max jump apex?
func _blocks(x: float, from_top: float, other_x0: float, other_x1: float, other_top: float) -> bool:
	if other_top >= from_top:
		return false  # not above the launch platform
	if not _overlaps(x, other_x0, other_x1):
		return false
	var head_min := from_top - MAX_APEX - PLAYER_HEIGHT
	var underside := other_top + PLATFORM_THICKNESS
	return head_min <= underside


func test_every_climb_step_has_at_least_one_valid_launch_position() -> void:
	var platforms := _load_platforms()
	assert_gt(platforms.size(), 0, "sanity: R5 should have SolidRect platforms to check")

	# Match each expected climb-order (x0,top) to the actual loaded platform,
	# so this test fails loudly (a clear "platform not found") rather than
	# silently skipping if the level geometry moves without this test being
	# updated to match.
	var by_pos := {}
	for p in platforms:
		by_pos[Vector2(p["x0"], p["top"])] = p

	var resolved := []
	for key in CLIMB_ORDER:
		assert_true(by_pos.has(key), "expected a platform at x0=%d, top=%d — R5's geometry changed; update CLIMB_ORDER" % [key.x, key.y])
		if by_pos.has(key):
			resolved.append(by_pos[key])

	if resolved.size() != CLIMB_ORDER.size():
		return  # already failed above; nothing more to check meaningfully

	for i in range(resolved.size() - 1):
		var frm = resolved[i]
		var to = resolved[i + 1]

		var has_valid_launch := false
		var x: float = frm["x0"]
		while x <= frm["x1"]:
			var blocked := false
			for other in platforms:
				if other == frm or other == to:
					continue
				if _blocks(x, frm["top"], other["x0"], other["x1"], other["top"]):
					blocked = true
					break
			if not blocked:
				has_valid_launch = true
				break
			x += 1.0

		assert_true(
			has_valid_launch,
			"climb step %d->%d: no launch position on the lower platform's own span [%d,%d] avoids every third-party platform's underside within the %dpx max apex" % [
				i, i + 1, frm["x0"], frm["x1"], MAX_APEX
			]
		)
