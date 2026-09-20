extends Node2D
## Root scene for the playable zone graph: hosts the persistent Player and
## hands ZoneManager the container rooms are swapped into.

@onready var rooms_root: Node2D = $Rooms

func _ready() -> void:
	ZoneManager.bootstrap(rooms_root)
