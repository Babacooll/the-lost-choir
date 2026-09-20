extends GutTest
## Exercises the LDtk-into-Godot pipeline (scripts/levels/ldtk_project.gd,
## room.gd) against docs/design/vertical-slice.md §6's seven-room graph —
## checkpoint scope: room geometry/gating fails visibly when played, so this
## checks pipeline wiring and door-graph integrity, not design numbers.

const EXPECTED_LEVELS := [
	"R1_ColdStep", "R2_ReedGallery", "R4_MembraneHall", "R5_Colonnade",
	"R6_ColdAmphitheater", "R7_WarmReturn", "R8_CrackedBell",
]

func before_each() -> void:
	GameState.restoration_complete = false


func test_all_seven_rooms_are_present() -> void:
	var identifiers: Array = []
	for level in LDtkProject.get_all_levels():
		identifiers.append(level.get("identifier", ""))
	for expected in EXPECTED_LEVELS:
		assert_has(identifiers, expected, "§6 requires room '%s'" % expected)
	assert_eq(identifiers.size(), 7, "§6 is exactly seven rooms (R3 folded into R2)")


func test_every_door_has_a_reciprocal_door_in_its_target_level() -> void:
	for level in LDtkProject.get_all_levels():
		var level_id: String = level.get("identifier", "")
		for door_entity in LDtkProject.get_entities(level, "Door"):
			var target_level: String = LDtkProject.get_field(door_entity, "target_level")
			var target_door_id: String = LDtkProject.get_field(door_entity, "target_door_id")
			var target_level_data := LDtkProject.get_level(target_level)
			var found := false
			for candidate in LDtkProject.get_entities(target_level_data, "Door"):
				if LDtkProject.get_field(candidate, "door_id") == target_door_id:
					found = true
					assert_eq(
						LDtkProject.get_field(candidate, "target_level"), level_id,
						"door '%s' in %s should point back to %s" % [target_door_id, target_level, level_id]
					)
					break
			assert_true(found, "no reciprocal door '%s' found in %s" % [target_door_id, target_level])


func test_r7_shortcut_and_r1_drop_are_gated_on_restoration() -> void:
	var r4 := LDtkProject.get_level("R4_MembraneHall")
	var r7 := LDtkProject.get_level("R7_WarmReturn")

	var r4_to_r7_flag: String = ""
	for door_entity in LDtkProject.get_entities(r4, "Door"):
		if LDtkProject.get_field(door_entity, "door_id") == "R4_to_R7":
			r4_to_r7_flag = LDtkProject.get_field(door_entity, "requires_flag")
	assert_eq(r4_to_r7_flag, "restoration_complete", "R4's shortcut door to R7 is barred until restoration (§6)")

	var r7_to_r1_flag: String = ""
	for door_entity in LDtkProject.get_entities(r7, "Door"):
		if LDtkProject.get_field(door_entity, "door_id") == "R7_to_R1":
			r7_to_r1_flag = LDtkProject.get_field(door_entity, "requires_flag")
	assert_eq(r7_to_r1_flag, "restoration_complete", "R7's drop back to R1 only opens after the Verse (§6)")


func test_room_builds_solid_geometry_doors_and_markers_from_ldtk() -> void:
	var room := preload("res://scenes/levels/R2_ReedGallery.tscn").instantiate()
	add_child_autofree(room)

	assert_true(room.doors.has("R2_to_R1"), "R2 should expose its door back to R1")
	assert_true(room.doors.has("R2_to_R4"), "R2 should expose its door onward to R4")
	assert_eq(get_tree().get_nodes_in_group("EnemyMarker").size(), 2, "R2 has a passive husk and one Reed Husk marker (§6)")


func test_gated_door_is_closed_until_restoration_flag_is_set() -> void:
	var room := preload("res://scenes/levels/R4_MembraneHall.tscn").instantiate()
	add_child_autofree(room)

	var shortcut: Door = room.doors["R4_to_R7"]
	assert_false(shortcut.is_open(), "shortcut must be barred before restoration")

	GameState.restoration_complete = true
	assert_true(shortcut.is_open(), "shortcut opens once the restoration flag is set")


func test_ungated_door_is_always_open() -> void:
	var room := preload("res://scenes/levels/R1_ColdStep.tscn").instantiate()
	add_child_autofree(room)

	var door: Door = room.doors["R1_to_R2"]
	assert_true(door.is_open(), "R1<->R2 is a normal, always-open connection")
