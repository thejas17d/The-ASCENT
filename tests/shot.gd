extends SceneTree
## Renders screenshots: godot --path . -s res://tests/shot.gd -- <quality 0-3> <tag>
## Saves user://shot_<tag>_<view>.png for several camera views.
func _initialize() -> void:
	await process_frame; await process_frame   # let autoload _ready run first
	var args := OS.get_cmdline_user_args()
	var q := int(args[0]) if args.size() > 0 else 2
	var tag: String = args[1] if args.size() > 1 else "q%d" % q
	root.get_node("Graphics").apply(q)
	root.get_node("Graphics").auto_mode = false
	var m = load("res://scenes/floor_02.tscn").instantiate(); root.add_child(m)
	await create_timer(0.5).timeout
	m.director.enabled = false
	m.busy = true   # stop pass judgements while the camera is teleported around
	m.hud.fade_to(0.0, 0.01)
	m.hud.message("", 0.1)
	var views := {
		"lobby": [Vector3(0, 0.05, 2.6), 0.0, 0.0, ""],
		"mid": [Vector3(0.3, 0.05, -12), 0.25, -0.05, ""],
		"doors": [Vector3(-0.6, 0.05, -20), -0.9, -0.05, "stains"],
		"figure": [Vector3(0, 0.05, -18), 0.0, 0.0, "figure"],
		"board": [Vector3(-0.2, 0.05, 2.5), 1.35, -0.1, ""],
	}
	for v in views:
		var cfg: Array = views[v]
		m.corridor.build(cfg[3], 5, false, 3)
		m.player.teleport(cfg[0])
		m.player.rotation.y = cfg[1]
		m.player.cam.rotation.x = cfg[2]
		for i in 45: await process_frame
		root.get_texture().get_image().save_png("user://shot_%s_%s.png" % [tag, v])
	print("saved"); quit()
