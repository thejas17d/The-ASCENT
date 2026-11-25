extends SceneTree
## Screenshots of the title screen, settings panel and pause menu.
var _user_files := preload("res://tests/user_files.gd").backup()   # never touch the player's save
func _initialize() -> void:
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	for i in 90: await process_frame
	root.get_texture().get_image().save_png("user://ui_menu.png")
	menu._open_settings()
	for i in 10: await process_frame
	root.get_texture().get_image().save_png("user://ui_settings.png")
	menu.queue_free()
	var f = load("res://scenes/floor_02.tscn").instantiate()
	root.add_child(f)
	for i in 40: await process_frame
	f.pause_menu.open()
	for i in 10: await process_frame
	root.get_texture().get_image().save_png("user://ui_pause.png")
	f.pause_menu.close()
	print("saved"); quit()

func _finalize() -> void:
	preload("res://tests/user_files.gd").restore(_user_files)
