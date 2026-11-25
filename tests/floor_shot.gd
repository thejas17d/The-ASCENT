extends SceneTree
## Screenshots of a floor: godot --path . -s res://tests/floor_shot.gd -- <key>
## Views are [position, yaw, pitch, torch]. Images: user://floor_<key>_<i>.png
const VIEWS := {
	"g": ["res://scenes/floor_g.tscn", [[Vector3(0, 0.05, 4.6), 0.0, -0.05, false], [Vector3(-1.0, 0.05, 0.5), 0.75, -0.1, true], [Vector3(2.0, 0.05, -3.3), -1.57, -0.05, true]]],
	"stair": ["res://scenes/stairwell.tscn", [[Vector3(0, 0.05, -0.8), 0.0, 0.35, true], [Vector3(0.3, 3.05, -6.6), 3.14, -0.3, true]]],
	"1": ["res://scenes/floor_01.tscn", [[Vector3(0, 0.05, -2.0), 0.0, -0.05, true], [Vector3(-6, 0.05, -10), 1.57, -0.05, true], [Vector3(4, 0.05, -12), 0.6, -0.1, true]]],
	"3": ["res://scenes/floor_03.tscn", [[Vector3(0, 0.05, 14), 0.0, 0.0, true], [Vector3(-4, 0.05, -1), 1.57, 0.0, true]]],
	"4": ["res://scenes/floor_04.tscn", [[Vector3(0, 0.05, 3.0), 0.0, -0.05, false], [Vector3(-3, 0.05, -4), 1.2, -0.05, false], [Vector3(3, 0.05, -6), -0.5, -0.05, true]]],
	"5": ["res://scenes/floor_05.tscn", [[Vector3(0, 0.05, 11), 0.0, -0.02, true], [Vector3(-8, 0.05, -4), -0.8, -0.05, true]]],
	"6": ["res://scenes/floor_06.tscn", [[Vector3(0, 0.05, 8), 0.0, 0.1, true], [Vector3(0, 0.05, -2), 0.0, 0.25, true]]],
	"7": ["res://scenes/floor_07.tscn", [[Vector3(0, 0.05, 11), 0.0, 0.05, true], [Vector3(-6, 0.05, 2), -0.5, 0.0, true]]],
	"8": ["res://scenes/floor_08.tscn", [[Vector3(0, 0.05, 10), 0.0, 0.0, true], [Vector3(6, 0.05, -2), 0.9, 0.05, true]]],
}
func _initialize() -> void:
	var key: String = OS.get_cmdline_user_args()[0]
	var gs = root.get_node("GameState")
	gs.test_mode = true
	gs.stair_from = 3
	root.get_node("Graphics").apply(3)
	var cfg: Array = VIEWS[key]
	var f = load(cfg[0]).instantiate()
	root.add_child(f)
	await create_timer(0.6).timeout
	f.director.enabled = false
	f.busy = true
	f.hud.fade_to(0.0, 0.01); f.hud.message("", 0.1)
	var i := 0
	for v in cfg[1]:
		f.player.teleport(v[0]); f.player.rotation.y = v[1]; f.player.cam.rotation.x = v[2]
		f.player.light.visible = v[3]
		for k in 40: await process_frame
		root.get_texture().get_image().save_png("user://floor_%s_%d.png" % [key, i])
		i += 1
	print("saved"); quit()
