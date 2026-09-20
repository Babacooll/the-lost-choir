extends CanvasLayer
## In-game debug overlay. Off by default; toggled with the "toggle_debug_overlay"
## input action (F3).
##
## Checkpoint 1 scope: prove the panel, its toggle, and the off-by-default wiring.
## Later checkpoints extend this readout to plot tell-window-vs-input (§5, §11.2/§11.3).

@onready var panel: Panel = $Panel
@onready var readout: Label = $Panel/MarginContainer/Readout

var _player: CharacterBody2D = null

func _ready() -> void:
	visible = false
	# Autoload runs before the scene tree's other nodes are guaranteed ready;
	# defer the player lookup to the next frame.
	call_deferred("_find_player")


func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		_player = players[0]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug_overlay"):
		visible = not visible
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not visible:
		return
	if _player == null:
		_find_player()
		return

	readout.text = "state: %s\nvelocity: (%.1f, %.1f)\non_floor: %s" % [
		_player.debug_state,
		_player.velocity.x,
		_player.velocity.y,
		_player.is_on_floor(),
	]
