class_name LDtkProject
extends RefCounted
## Minimal reader for the LDtk export JSON shape (levels / layerInstances /
## entityInstances / fieldInstances / px), per ARCHITECTURE.md's LDtk-into-Godot
## pipeline. Reads the field names LDtk actually exports so a real LDtk export
## can replace assets/levels/the_lost_choir.ldtk later without touching this
## reader or Room's use of it.

const DEFAULT_PATH := "res://assets/levels/the_lost_choir.ldtk"

static var _cache: Dictionary = {}

static func load_project(path: String = DEFAULT_PATH) -> Dictionary:
	if _cache.has(path):
		return _cache[path]

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("LDtkProject: could not open '%s'" % path)
		return {}

	var data: Variant = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		push_error("LDtkProject: '%s' did not parse to a JSON object" % path)
		return {}

	_cache[path] = data
	return data

static func get_level(identifier: String, path: String = DEFAULT_PATH) -> Dictionary:
	for level in load_project(path).get("levels", []):
		if level.get("identifier", "") == identifier:
			return level
	push_error("LDtkProject: level '%s' not found in '%s'" % [identifier, path])
	return {}

static func get_all_levels(path: String = DEFAULT_PATH) -> Array:
	return load_project(path).get("levels", [])

static func get_entities(level: Dictionary, type_identifier: String) -> Array:
	var result: Array = []
	for layer in level.get("layerInstances", []):
		if layer.get("__identifier", "") != "Entities":
			continue
		for entity in layer.get("entityInstances", []):
			if entity.get("__identifier", "") == type_identifier:
				result.append(entity)
	return result

static func get_field(entity: Dictionary, field_identifier: String, default_value: Variant = "") -> Variant:
	for field in entity.get("fieldInstances", []):
		if field.get("__identifier", "") == field_identifier:
			return field.get("__value", default_value)
	return default_value

static func entity_position(entity: Dictionary) -> Vector2:
	var px: Array = entity.get("px", [0, 0])
	return Vector2(px[0], px[1])
