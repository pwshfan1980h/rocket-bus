extends SceneTree
## Screenshots for eyeballing art changes.
##   godot --path . -s tools/shot.gd -- --level=4 --at=3.0 --out=/tmp/x.png [--bot] [--scale=3]
## Loads the level scene, waits `at` seconds of game time, saves the viewport.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var at := 3.0
	var out := "user://shot.png"
	var scene := "res://scenes/level.tscn"
	for a in args:
		if a.begins_with("--at="):
			at = float(a.substr(5))
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--scene="):
			scene = a.substr(8)
	change_scene_to_file.call_deferred(scene)
	await create_timer(at, true, false, true).timeout
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out)
	print("saved ", out)
	quit()
