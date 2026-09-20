extends GutTest
## Regression coverage for the door-transition runtime path — not just the
## LDtk door-graph data (test_ldtk_zone_graph.gd covers that exhaustively).
## Drives a real ZoneManager transition and runs physics ticks, which is
## what caught the ping-pong / out-of-bounds spawn defects review found: the
## door-graph data was always correct, the runtime placement wasn't.

var _rooms_root: Node2D
var _player: CharacterBody2D

func before_each() -> void:
	GameState.restoration_complete = false

	_rooms_root = Node2D.new()
	add_child_autofree(_rooms_root)

	_player = preload("res://scenes/player.tscn").instantiate()
	add_child_autofree(_player)

	ZoneManager.current_room = null
	ZoneManager.bootstrap(_rooms_root)


func after_each() -> void:
	if ZoneManager.current_room != null:
		ZoneManager.current_room.free()
	ZoneManager.current_room = null


func test_player_stays_in_world_after_a_direct_transition() -> void:
	ZoneManager.travel("R4_MembraneHall", "R4_to_R2")

	for i in range(90):
		await get_tree().physics_frame

	var level := LDtkProject.get_level("R4_MembraneHall")
	assert_between(
		_player.global_position.x, 0.0, level.get("pxWid"),
		"player must still be inside R4's own bounds after settling, not clipped out at the seam"
	)
	assert_between(
		_player.global_position.y, -50.0, level.get("pxHei"),
		"player must not have fallen through the floor and out of R4"
	)
	assert_eq(
		ZoneManager.current_room.level_id, "R4_MembraneHall",
		"settling near the arrival door must not itself trigger another transition"
	)


func test_arriving_next_to_a_door_does_not_ping_pong_back_through_it() -> void:
	ZoneManager.travel("R2_ReedGallery", "R2_to_R1")
	var initial_room: Room = ZoneManager.current_room

	for i in range(120):
		await get_tree().physics_frame

	assert_eq(
		ZoneManager.current_room, initial_room,
		"the room instance must be unchanged 120 ticks after arrival — a ping-pong frees and replaces it"
	)

	var level := LDtkProject.get_level("R2_ReedGallery")
	assert_between(
		_player.global_position.x, 0.0, level.get("pxWid"),
		"player must have settled inside R2, not been bounced back to R1 and off the far side"
	)
