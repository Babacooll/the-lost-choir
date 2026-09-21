extends GutTest
## MICH-615: EnemyMarker -> ENEMY_SCENES spawn path. Mirrors the existing
## EncounterMarker coverage's pattern (test_acceptance_sweep.gd's
## _find_restoration_encounter) — drives the real Room scene against the
## real LDtk data rather than asserting on marker coordinates alone.

const R2Scene := preload("res://scenes/levels/R2_ReedGallery.tscn")
const R5Scene := preload("res://scenes/levels/R5_Colonnade.tscn")


func _enemy_markers(root: Node2D) -> Array:
	var out := []
	for marker in root.get_tree().get_nodes_in_group("EnemyMarker"):
		if marker.is_inside_tree() and marker.get_parent() == root:
			out.append(marker)
	return out


func test_r2_spawns_passive_husk_in_entry_half_and_reed_husk_in_far_half() -> void:
	var room := R2Scene.instantiate()
	add_child_autofree(room)
	await get_tree().physics_frame

	var markers := _enemy_markers(room)
	assert_eq(markers.size(), 2, "R2 authors exactly two EnemyMarkers")

	var passive_marker: Marker2D = null
	var reed_marker: Marker2D = null
	for marker in markers:
		if marker.get_meta("enemy_type") == "PassiveHusk":
			passive_marker = marker
		elif marker.get_meta("enemy_type") == "ReedHusk":
			reed_marker = marker

	assert_not_null(passive_marker, "R2 must author a PassiveHusk marker")
	assert_not_null(reed_marker, "R2 must author a ReedHusk marker")

	assert_eq(passive_marker.position, Vector2(160, 192), "entry-half marker position must match LDtk authoring")
	assert_eq(reed_marker.position, Vector2(600, 192), "far-half marker position must match LDtk authoring")

	var passive_child := _find_child_of_type(passive_marker, "PassiveHusk")
	var reed_child := _find_child_of_type(reed_marker, "ReedHusk")
	assert_not_null(passive_child, "the entry-half marker must actually spawn a PassiveHusk instance")
	assert_not_null(reed_child, "the far-half marker must actually spawn a ReedHusk instance")


func test_r5_spawns_reed_husk_and_keening_husk_at_authored_positions() -> void:
	var room := R5Scene.instantiate()
	add_child_autofree(room)
	await get_tree().physics_frame

	var markers := _enemy_markers(room)
	assert_eq(markers.size(), 2, "R5 authors exactly two EnemyMarkers")

	var reed_marker: Marker2D = null
	var keening_marker: Marker2D = null
	for marker in markers:
		if marker.get_meta("enemy_type") == "ReedHusk":
			reed_marker = marker
		elif marker.get_meta("enemy_type") == "KeeningHusk":
			keening_marker = marker

	assert_not_null(reed_marker, "R5 must author a ReedHusk marker")
	assert_not_null(keening_marker, "R5 must author a KeeningHusk marker")

	assert_eq(reed_marker.position, Vector2(190, 412), "R5 Reed Husk marker position must match LDtk authoring")
	assert_eq(keening_marker.position, Vector2(53, 312), "R5 Keening Husk marker position must match LDtk authoring")

	assert_not_null(_find_child_of_type(reed_marker, "ReedHusk"), "R5's lower marker must spawn a ReedHusk instance")
	assert_not_null(
		_find_child_of_type(keening_marker, "KeeningHusk"), "R5's upper marker must spawn a KeeningHusk instance"
	)


func _find_child_of_type(marker: Marker2D, class_name_string: String) -> Node:
	for child in marker.get_children():
		if child.get_class() != "CharacterBody2D":
			continue
		if child.get_script() != null and child.get_script().get_global_name() == class_name_string:
			return child
	return null


## Unrecognised enemy_type must stay an inert marker — no error — same
## contract as _maybe_spawn_encounter's own unknown-id handling. Exercised
## directly against Room's marker-building rather than via LDtk data, since
## nothing in the authored slice has an unknown enemy_type to load.
func test_unrecognised_enemy_type_stays_inert_marker_no_error() -> void:
	var room := Room.new()
	add_child_autofree(room)

	var entity := {
		"px": [40, 20],
		"fieldInstances": [
			{"__identifier": "enemy_type", "__value": "SomeFutureHusk"},
		],
	}
	var marker := room._build_marker(entity, "enemy_type", "EnemyMarker")
	room._maybe_spawn_enemy(marker, "SomeFutureHusk")

	assert_eq(marker.get_child_count(), 0, "an unrecognised enemy_type must not spawn anything under the marker")
	assert_true(marker.is_in_group("EnemyMarker"), "the marker must keep its group membership regardless")
	assert_eq(marker.get_meta("enemy_type"), "SomeFutureHusk", "the marker must keep its metadata regardless")
