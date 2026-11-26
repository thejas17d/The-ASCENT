extends SceneTree
## Screenshots of the opening at 3, 9, 18.5 and 21.5 s: godot --path . -s res://tests/intro_shot.gd -- [quality]
var _user_files := preload("res://tests/user_files.gd").backup()   # never touch the player's save
func _initialize() -> void:
	await process_frame; await process_frame
	var gs = root.get_node("GameState"); gs.test_mode = true
	var q := int(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else 1
	root.get_node("Graphics").apply(q); root.get_node("Graphics").auto_mode = false
	var intro = load("res://scenes/intro.tscn").instantiate(); root.add_child(intro)
	var i := 0
	for t in [3.0, 9.0, 18.5, 21.5]:
		while intro._t < t:
			await process_frame
		root.get_texture().get_image().save_png("user://intro_%d.png" % i)
		i += 1
	intro.skip()
	await create_timer(1.2).timeout
	print("saved -> ", gs.last_scene_request); quit()

func _finalize() -> void:
	preload("res://tests/user_files.gd").restore(_user_files)
