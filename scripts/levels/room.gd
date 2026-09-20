class_name Room
extends Node2D
## Builds itself from an LDtk level at runtime — the LDtk-into-Godot pipeline
## ARCHITECTURE.md specifies. Placeholder geometry/tiles only (§6 checkpoint
## scope); Art's real assets replace SolidRect blockouts in a later pass.

@export var level_id: String = ""

const DoorScript := preload("res://scripts/levels/door.gd")
const SOLID_COLOR := Color(0.32, 0.29, 0.36, 1.0)
const GATED_DOOR_COLOR := Color(0.55, 0.4, 0.2, 1.0)
const OPEN_DOOR_COLOR := Color(0.6, 0.6, 0.7, 0.35)

var doors: Dictionary = {}  # door_id: String -> Door
var player_start: Vector2 = Vector2.ZERO

func _ready() -> void:
	if level_id.is_empty():
		push_warning("Room: no level_id set, nothing to build")
		return
	_build_from_ldtk()

func get_door_spawn_position(door_id: String) -> Vector2:
	if door_id.is_empty() or not doors.has(door_id):
		return player_start
	# Spawn just inside the room from the door, not on top of its trigger.
	return (doors[door_id] as Door).position + Vector2(0, -8)

func _build_from_ldtk() -> void:
	var level := LDtkProject.get_level(level_id)
	if level.is_empty():
		return

	_apply_camera_bounds(level.get("pxWid", 0.0), level.get("pxHei", 0.0))

	for entity in LDtkProject.get_entities(level, "SolidRect"):
		_build_solid_rect(entity)
	for entity in LDtkProject.get_entities(level, "PlayerStart"):
		player_start = LDtkProject.entity_position(entity)
	for entity in LDtkProject.get_entities(level, "EnemyMarker"):
		_build_marker(entity, "enemy_type", "EnemyMarker")
	for entity in LDtkProject.get_entities(level, "EncounterMarker"):
		_build_marker(entity, "encounter_id", "EncounterMarker")
	for entity in LDtkProject.get_entities(level, "FragmentMarker"):
		_build_marker(entity, "fragment_id", "FragmentMarker")
	for entity in LDtkProject.get_entities(level, "Door"):
		_build_door(entity)

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

	var visual := Polygon2D.new()
	visual.color = SOLID_COLOR
	visual.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y),
	])
	body.add_child(visual)

func _build_marker(entity: Dictionary, field_id: String, group_name: String) -> void:
	var marker := Marker2D.new()
	marker.position = LDtkProject.entity_position(entity)
	var tag: String = LDtkProject.get_field(entity, field_id, "unnamed")
	marker.name = "%s_%s" % [group_name, tag]
	marker.add_to_group(group_name)
	marker.set_meta(field_id, tag)
	add_child(marker)

func _build_door(entity: Dictionary) -> void:
	var pos := LDtkProject.entity_position(entity)
	var width: float = entity.get("width", 16.0)
	var height: float = entity.get("height", 16.0)

	var door := Area2D.new()
	door.set_script(DoorScript)
	door.position = pos
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

	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(width, 0), Vector2(width, height), Vector2(0, height),
	])
	visual.color = GATED_DOOR_COLOR if not door.requires_flag.is_empty() else OPEN_DOOR_COLOR
	door.add_child(visual)
	door.set_meta("visual", visual)

	add_child(door)
	doors[door.door_id] = door
	door.body_entered.connect(_on_door_body_entered.bind(door))

func _on_door_body_entered(body: Node, door: Door) -> void:
	if not body.is_in_group("player"):
		return
	if not door.is_open():
		return
	ZoneManager.travel(door.target_level, door.target_door_id)

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
