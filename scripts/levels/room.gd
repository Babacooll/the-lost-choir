class_name Room
extends Node2D
## Builds itself from an LDtk level at runtime — the LDtk-into-Godot pipeline
## ARCHITECTURE.md specifies. Placeholder geometry/tiles only (§6 checkpoint
## scope); Art's real assets replace SolidRect blockouts in a later pass.

@export var level_id: String = ""
## R7/R8: authored warm-on-first-sight (art doc §4.3) — pinned to w=1 rather
## than propagating from a seam that doesn't exist in these rooms.
@export var pin_warmth: bool = false

const DoorScript := preload("res://scripts/levels/door.gd")
const WarmthVisual := preload("res://scripts/art/warmth_visual.gd")
## Stone family from docs/art/palettes/lost-choir-slice.json, authored warm —
## the cold column comes from the shader's own derive, not a second constant.
## Two distinct tones (backdrop vs. solid geometry) rather than one flat
## colour: a uniform room has ~no luma contrast to measure in either state,
## which would make §4.4's contrast-rise check untestable regardless of the
## transform being correct.
const BACKDROP_COLOR := Color(0x3b / 255.0, 0x2f / 255.0, 0x28 / 255.0, 1.0)  # ST0 deepest crevice
const SOLID_COLOR := Color(0xcb / 255.0, 0xae / 255.0, 0x8c / 255.0, 1.0)  # ST4 rim / chipped edge
const GATED_DOOR_COLOR := Color(0.55, 0.4, 0.2, 1.0)
const OPEN_DOOR_COLOR := Color(0.6, 0.6, 0.7, 0.35)

const VerseBearerScene := preload("res://scenes/encounters/verse_bearer.tscn")
# EncounterMarker.encounter_id -> scene to spawn on it. Only R6's restoration
# encounter exists this checkpoint; other encounter ids stay inert markers.
const ENCOUNTER_SCENES := {
	"verse_bearer_r6": VerseBearerScene,
}

const MembraneScene := preload("res://scenes/world/membrane.tscn")
const BellFrameScene := preload("res://scenes/world/bell_frame.tscn")

# How far, horizontally, an arriving player is pushed clear of the door
# trigger they just arrived through — big enough to clear the trigger's own
# 16 px width plus the player's 18 px collider, so gravity settling them
# back onto the floor cannot re-overlap the same Area2D and ping-pong.
const SPAWN_HORIZONTAL_CLEARANCE := 32.0
const SPAWN_MARGIN := 16.0

var doors: Dictionary = {}  # door_id: String -> Door
var player_start: Vector2 = Vector2.ZERO
var _has_player_start: bool = false
var _px_wid: float = 0.0
var _px_hei: float = 0.0
var _warmth_origin_override: Vector2 = Vector2.ZERO
var _has_warmth_origin_override: bool = false

## The warmth field's seam origin (art doc §4.2): the Verse-bearer's own
## position where this room has one (R6), room centre otherwise — every
## other room still gets the same travelling-wavefront treatment, just
## without a literal bearer to anchor it to.
func warmth_origin() -> Vector2:
	if _has_warmth_origin_override:
		return _warmth_origin_override
	return global_position + Vector2(_px_wid * 0.5, _px_hei * 0.5)

func _ready() -> void:
	if level_id.is_empty():
		push_warning("Room: no level_id set, nothing to build")
		return
	_build_from_ldtk()

func get_door_spawn_position(door_id: String) -> Vector2:
	if door_id.is_empty() or not doors.has(door_id):
		if _has_player_start:
			return player_start
		# No PlayerStart entity in this level (only R1 has one) and no valid
		# door to arrive through — fall back to a safe, bounds-clear point
		# rather than the origin, which sits exactly on a room's edge/corner
		# in every level here and can shove the player out of bounds.
		return Vector2(_px_wid * 0.5, 0.0)

	var door: Door = doors[door_id]
	# Door position is the trigger's top-left corner (§ _build_door). Push the
	# spawn point inward from its horizontal centre, clear of its own width,
	# so the arriving player cannot fall straight back into the trigger they
	# just came through. Direction is toward the room's interior, inferred
	# from which half of the room the door sits in.
	var center_x := door.position.x + door.size.x * 0.5
	var inward := 1.0 if center_x < _px_wid * 0.5 else -1.0
	var spawn_x := clampf(
		center_x + inward * SPAWN_HORIZONTAL_CLEARANCE,
		SPAWN_MARGIN, maxf(SPAWN_MARGIN, _px_wid - SPAWN_MARGIN)
	)
	# Spawn at the trigger's own top edge — always at or above the floor a
	# door's bottom edge is authored to align with — and let gravity settle
	# the player, rather than assume the bottom edge is solid ground (it
	# isn't, for every door in this zone).
	return Vector2(spawn_x, door.position.y)

func _build_from_ldtk() -> void:
	var level := LDtkProject.get_level(level_id)
	if level.is_empty():
		return

	_px_wid = level.get("pxWid", 0.0)
	_px_hei = level.get("pxHei", 0.0)
	_apply_camera_bounds(_px_wid, _px_hei)
	_build_backdrop()

	for entity in LDtkProject.get_entities(level, "SolidRect"):
		_build_solid_rect(entity)
	for entity in LDtkProject.get_entities(level, "PlayerStart"):
		player_start = LDtkProject.entity_position(entity)
		_has_player_start = true
	for entity in LDtkProject.get_entities(level, "EnemyMarker"):
		_build_marker(entity, "enemy_type", "EnemyMarker")
	for entity in LDtkProject.get_entities(level, "EncounterMarker"):
		var marker := _build_marker(entity, "encounter_id", "EncounterMarker")
		_maybe_spawn_encounter(marker, LDtkProject.get_field(entity, "encounter_id", "unnamed"))
	for entity in LDtkProject.get_entities(level, "FragmentMarker"):
		_build_marker(entity, "fragment_id", "FragmentMarker")
	for entity in LDtkProject.get_entities(level, "Membrane"):
		_build_world_object(entity, MembraneScene)
	for entity in LDtkProject.get_entities(level, "BellFrame"):
		_build_world_object(entity, BellFrameScene)
	for entity in LDtkProject.get_entities(level, "Door"):
		_build_door(entity)

## A full-room backdrop panel so the warmth field has room-filling placeholder
## material to derive over, rather than only the thin SolidRect blockouts —
## stands in for background wall/floor art until it lands (checkpoint scope:
## "build the shader/transform pipeline against whatever placeholder tiles
## World Builder's rooms currently use").
func _build_backdrop() -> void:
	var visual := WarmthVisual.new()
	visual.color = BACKDROP_COLOR
	visual.z_index = -10
	visual.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(_px_wid, 0), Vector2(_px_wid, _px_hei), Vector2(0, _px_hei),
	])
	add_child(visual)

func _build_solid_rect(entity: Dictionary) -> void:
	var pos := LDtkProject.entity_position(entity)
	var width: float = entity.get("width", 16.0)
	var height: float = entity.get("height", 16.0)
	var half := Vector2(width, height) * 0.5

	var body := StaticBody2D.new()
	body.position = pos + half
	add_child(body)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, height)
	shape.shape = rect
	body.add_child(shape)

	var visual := WarmthVisual.new()
	visual.color = SOLID_COLOR
	visual.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y),
	])
	body.add_child(visual)

## §4.1 world objects (Membrane, BellFrame): px is the entity's top-left
## footprint, same convention as SolidRect — the spawned node's own position
## is that footprint's centre, matching both scenes' collision shapes (which
## are centred on the node with no offset).
func _build_world_object(entity: Dictionary, scene: PackedScene) -> void:
	var pos := LDtkProject.entity_position(entity)
	var width: float = entity.get("width", 16.0)
	var height: float = entity.get("height", 16.0)
	var instance: Node2D = scene.instantiate()
	instance.position = pos + Vector2(width, height) * 0.5
	add_child(instance)


func _build_marker(entity: Dictionary, field_id: String, group_name: String) -> Marker2D:
	var marker := Marker2D.new()
	marker.position = LDtkProject.entity_position(entity)
	var tag: String = LDtkProject.get_field(entity, field_id, "unnamed")
	marker.name = "%s_%s" % [group_name, tag]
	marker.add_to_group(group_name)
	marker.set_meta(field_id, tag)
	add_child(marker)
	return marker


func _maybe_spawn_encounter(marker: Marker2D, encounter_id: String) -> void:
	if not ENCOUNTER_SCENES.has(encounter_id):
		return
	var instance: Node2D = ENCOUNTER_SCENES[encounter_id].instantiate()
	marker.add_child(instance)
	if encounter_id == "verse_bearer_r6":
		# The seam the warmth field originates from (art doc §4.2) is this
		# encounter's own position, not an authored constant.
		_warmth_origin_override = marker.global_position
		_has_warmth_origin_override = true

func _build_door(entity: Dictionary) -> void:
	var pos := LDtkProject.entity_position(entity)
	var width: float = entity.get("width", 16.0)
	var height: float = entity.get("height", 16.0)

	var door := Area2D.new()
	door.set_script(DoorScript)
	door.position = pos
	door.size = Vector2(width, height)
	door.door_id = LDtkProject.get_field(entity, "door_id", "")
	door.target_level = LDtkProject.get_field(entity, "target_level", "")
	door.target_door_id = LDtkProject.get_field(entity, "target_door_id", "")
	door.requires_flag = LDtkProject.get_field(entity, "requires_flag", "")

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, height)
	shape.position = Vector2(width, height) * 0.5
	shape.shape = rect
	door.add_child(shape)

	var is_gated: bool = not door.requires_flag.is_empty()
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(width, 0), Vector2(width, height), Vector2(0, height),
	])
	visual.color = GATED_DOOR_COLOR if is_gated else OPEN_DOOR_COLOR
	door.add_child(visual)
	PlaceholderLegibility.apply(visual, "door_gated" if is_gated else "door_open")
	door.set_meta("visual", visual)

	add_child(door)
	doors[door.door_id] = door
	door.body_entered.connect(_on_door_body_entered.bind(door))

func _on_door_body_entered(body: Node, door: Door) -> void:
	if not body.is_in_group("player"):
		return
	if not door.is_open():
		return
	# body_entered fires mid physics-query-flush; travel() frees this room's
	# collision shapes and builds the next room's, which the physics server
	# rejects until the flush finishes. Defer the actual rebuild to the next
	# idle frame, outside the callback.
	ZoneManager.call_deferred("travel", door.target_level, door.target_door_id)

func _apply_camera_bounds(px_wid: float, px_hei: float) -> void:
	# Per-room camera bounds, no scrolling across doors (§6 header). The
	# player carries its own Camera2D across room transitions; each room
	# just re-clamps it to its own bounds on entry.
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var camera: Camera2D = player.get_node_or_null("Camera2D")
	if camera == null:
		return
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(px_wid)
	camera.limit_bottom = int(px_hei)
	camera.reset_smoothing()
