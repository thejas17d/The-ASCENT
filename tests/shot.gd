extends SceneTree
func _initialize() -> void:
	var m = load("res://scenes/floor_02.tscn").instantiate(); root.add_child(m)
	await create_timer(0.3).timeout
	m.corridor.build(OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() else "", 5, false, 3)
	m.hud._fade.color.a = 0
	m.player.teleport(Vector3(0.6,0.05,-21))
	m.player.rotation.y = 0.35
	m.player.set_phone(true)
	for i in 30: await process_frame
	root.get_texture().get_image().save_png("user://shot.png")
	print(ProjectSettings.globalize_path("user://shot.png")); quit()
