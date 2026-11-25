extends SceneTree
## Screenshots of the Supervisor in the archive test level (patrol + chase lamp).
var _user_files := preload("res://tests/user_files.gd").backup()   # never touch the player's save
func _initialize() -> void:
	await process_frame; await process_frame   # let autoload _ready run first
	root.get_node("Graphics").apply(3)
	root.get_node("Graphics").auto_mode = false
	var lvl = load("res://scenes/dev/supervisor_test.tscn").instantiate()
	root.add_child(lvl)
	await create_timer(0.6).timeout
	lvl.director.enabled = false
	lvl.hud.fade_to(0.0, 0.01); lvl.hud.message("", 0.1)
	var sup = lvl.sup
	sup.senses.sight = false; sup.senses.sound = false; sup.senses.light = false
	sup.activate(Vector3(0, 0.05, 0.5)); sup.waypoints = [Vector3(0, 0.05, 0.5)]; sup._wait = 999.0
	lvl.player.teleport(Vector3(0.4, 0.05, 6.5))
	sup.look_at(Vector3(0.4, 0.05, 6.5), Vector3.UP)
	sup.rotation.y += 0.5
	for i in 60: await process_frame
	root.get_texture().get_image().save_png("user://sup_patrol.png")
	sup._set_state(sup.S.CHASE)
	sup._head.rotation.y = 0.0
	sup.look_at(Vector3(0.4, 0.05, 6.5), Vector3.UP)
	sup.rotation.y += 0.25
	sup.velocity = Vector3.ZERO
	sup.state = sup.S.ATTACK   # freeze in place, keep the red lamp
	for i in 30: await process_frame
	root.get_texture().get_image().save_png("user://sup_chase.png")
	lvl.player.teleport(Vector3(-9.5, 0.05, 12.5)); lvl.player.rotation.y = -0.6
	for i in 30: await process_frame
	root.get_texture().get_image().save_png("user://sup_archive.png")
	print("saved"); quit()

func _finalize() -> void:
	preload("res://tests/user_files.gd").restore(_user_files)
