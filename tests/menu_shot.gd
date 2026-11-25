extends SceneTree
func _initialize() -> void:
	root.add_child(load("res://scenes/menu.tscn").instantiate())
	for i in 10: await process_frame
	root.get_texture().get_image().save_png("user://menu.png"); quit()
