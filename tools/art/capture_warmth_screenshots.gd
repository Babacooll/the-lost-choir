extends Node
## Standalone capture harness for §11 AC#10's numeric evidence — not part of
## the shipped game (not a real autoload; wired in only for a local capture
## run, per the comment in project.godot). Runs inside the real Zone scene,
## travels to a room, and renders it into a dedicated SubViewport sized to
## exactly the room's own pixel dimensions (so the shot is pixel-for-pixel
## the room, no camera-zoom/stretch-mode arithmetic to get wrong) — one
## capture before restoration, one well after the wavefront has settled —
## so tools/art/warmth_check.py has real pixels to grade.
##
##   godot --headless --path . -- <room_id> <out_dir>

var _frame := 0
var _room_id: String
var _out_dir: String
var _phase := "boot"
var _capture_viewport: SubViewport


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_room_id = args[0] if args.size() > 0 else "R6_ColdAmphitheater"
	_out_dir = args[1] if args.size() > 1 else "."
	GameState.restoration_complete = false


func _physics_process(_delta: float) -> void:
	_frame += 1
	var room := ZoneManager.current_room
	if room == null:
		return

	match _phase:
		"boot":
			if room.level_id != _room_id:
				ZoneManager.travel(_room_id, "")
			elif _frame > 6:
				_build_capture_viewport(room)
				_phase = "settle_cold"
		"settle_cold":
			if _frame > 20:
				_save("%s/cold_%s.png" % [_out_dir, _room_id])
				GameState.restoration_complete = true
				_phase = "settle_warm"
		"settle_warm":
			# 2500 ms propagation + 80 ms band + 400 ms settle, with margin.
			if _frame > 20 + 240:
				_save("%s/warm_%s.png" % [_out_dir, _room_id])
				get_tree().quit()


## A same-camera shot means exactly what it says: a viewport sized to the
## room, in world space, at zoom 1 — no scale factor for warmth_check.py's
## own pixel maths to have to know about.
func _build_capture_viewport(room: Room) -> void:
	var level := LDtkProject.get_level(room.level_id)
	var px_wid: int = int(level.get("pxWid"))
	var px_hei: int = int(level.get("pxHei"))

	_capture_viewport = SubViewport.new()
	_capture_viewport.size = Vector2i(px_wid, px_hei)
	_capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_tree().root.add_child(_capture_viewport)
	_capture_viewport.world_2d = get_tree().root.world_2d

	var cam := Camera2D.new()
	cam.global_position = Vector2(px_wid, px_hei) * 0.5
	_capture_viewport.add_child(cam)
	cam.make_current()


func _save(path: String) -> void:
	var img := _capture_viewport.get_texture().get_image()
	var abs_path := path if path.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(path)
	var err := img.save_png(abs_path)
	if err != OK:
		printerr("failed to save %s: %s" % [abs_path, err])
	else:
		print("saved %s" % abs_path)
