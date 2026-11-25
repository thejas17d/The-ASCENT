extends SceneTree
## Screenshot with the Mobile renderer + touch overlay:
## godot --rendering-method mobile --path . -s res://tests/mobile_shot.gd
func _initialize() -> void:
	var gs = root.get_node("GameState")
	await process_frame; await process_frame
	gs.test_mode = true
	gs.new_game()
	gs.settings.touch_controls = 1
	root.get_node("Graphics").apply(1)
	root.get_node("Graphics").auto_mode = false
	var f = load("res://scenes/floor_02.tscn").instantiate()
	root.add_child(f)
	await create_timer(0.8).timeout
	f.director.enabled = false
	f.busy = true
	f.hud.fade_to(0.0, 0.01); f.hud.message("", 0.1)
	f.player.teleport(Vector3(0.2, 0.05, 1.0))
	f.touch.set_joystick(Vector2(0.2, -0.6))
	f.touch._joy_origin = Vector2(260, 700)
	f.touch._set_knob(Vector2(290, 640))
	f.touch._joy_ring.position = Vector2(260, 700) - f.touch._joy_ring.size / 2
	f.touch._joy_ring.visible = true; f.touch._joy_knob.visible = true
	for i in 40: await process_frame
	print("renderer: ", RenderingServer.get_current_rendering_method())
	root.get_texture().get_image().save_png("user://mobile_touch.png")
	f.touch._release_move()
	gs.settings.touch_controls = 0
	print("saved"); quit()
