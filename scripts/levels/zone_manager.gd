extends Node
## Autoload singleton. Swaps the active Room per §6's door graph and places
## the player at the entry door on each transition. One room in the tree at
## a time, matching "no scrolling across doors" — rooms are disjoint scenes,
## not a shared scrollable world.

const ROOM_SCENES := {
	"R1_ColdStep": preload("res://scenes/levels/R1_ColdStep.tscn"),
	"R2_ReedGallery": preload("res://scenes/levels/R2_ReedGallery.tscn"),
	"R4_MembraneHall": preload("res://scenes/levels/R4_MembraneHall.tscn"),
	"R5_Colonnade": preload("res://scenes/levels/R5_Colonnade.tscn"),
	"R6_ColdAmphitheater": preload("res://scenes/levels/R6_ColdAmphitheater.tscn"),
	"R7_WarmReturn": preload("res://scenes/levels/R7_WarmReturn.tscn"),
	"R8_CrackedBell": preload("res://scenes/levels/R8_CrackedBell.tscn"),
}

const STARTING_LEVEL := "R1_ColdStep"

var current_room: Room = null
var _rooms_root: Node = null

func bootstrap(rooms_root: Node) -> void:
	_rooms_root = rooms_root
	travel(STARTING_LEVEL, "")

func travel(level_id: String, door_id: String) -> void:
	if not ROOM_SCENES.has(level_id):
		push_error("ZoneManager: unknown level '%s'" % level_id)
		return
	if _rooms_root == null:
		push_error("ZoneManager: travel() called before bootstrap()")
		return

	if current_room != null:
		current_room.queue_free()

	var room: Room = ROOM_SCENES[level_id].instantiate()
	_rooms_root.add_child(room)
	current_room = room

	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		player.global_position = room.get_door_spawn_position(door_id)

	# Ambience layers crossfade at doors (audio contract §6); the leitmotif/
	# drone bed itself is zone-scoped and never restarts here — AudioDirector
	# only ever fades its own two persistent players' volumes.
	AudioDirector.on_room_entered(room)
