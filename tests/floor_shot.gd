extends SceneTree
## Screenshots of a floor: godot --path . -s res://tests/floor_shot.gd -- <key> [quality 0-3, default 3]
## Views are [position, yaw, pitch, torch]. Images: user://floor_<key>_<i>.png (q<N> suffix below Ultra)
var _user_files := preload("res://tests/user_files.gd").backup()   # never touch the player's save
const VIEWS := {
	"g": ["res://scenes/floor_g.tscn", [[Vector3(0, 0.05, 4.6), 0.0, -0.05, false], [Vector3(-1.0, 0.05, 0.5), 0.75, -0.1, true], [Vector3(2.0, 0.05, -3.3), -1.57, -0.05, true]]],
	"stair": ["res://scenes/stairwell.tscn", [[Vector3(0, 0.05, -0.8), 0.0, 0.35, true], [Vector3(0.3, 3.05, -6.6), 3.14, -0.3, true]]],
	"1": ["res://scenes/floor_01.tscn", [[Vector3(0, 0.05, -2.0), 0.0, -0.05, true], [Vector3(-6, 0.05, -10), 1.57, -0.05, true], [Vector3(4, 0.05, -12), 0.6, -0.1, true]]],
	"3": ["res://scenes/floor_03.tscn", [[Vector3(0, 0.05, 14), 0.0, 0.0, true], [Vector3(-4, 0.05, -1), 1.57, 0.0, true]]],
	"4": ["res://scenes/floor_04.tscn", [[Vector3(2.5, 0.05, -3.6), -1.2, -0.05, true], [Vector3(-1.2, 0.05, 0.2), 0.3, -0.2, true], [Vector3(-3, 0.05, -4), 1.2, -0.05, false], [Vector3(3, 0.05, -6), -0.5, -0.05, true]]],
	"5": ["res://scenes/floor_05.tscn", [[Vector3(0, 0.05, 11), 0.0, -0.02, true], [Vector3(-8, 0.05, -4), -0.8, -0.05, true]]],
	"6": ["res://scenes/floor_06.tscn", [[Vector3(0, 0.05, 8), 0.0, 0.1, true], [Vector3(0, 0.05, -2), 0.0, 0.25, true]]],
	"7": ["res://scenes/floor_07.tscn", [[Vector3(-7.5, 0.05, 10.0), 0.55, 0.0, true], [Vector3(6.5, 0.05, -6.5), -0.7, 0.0, true]]],
	"9": ["res://scenes/floor_09.tscn", [[Vector3(0, 0.05, 6), 0.0, -0.15, false], [Vector3(5, 0.05, 5), 0.8, -0.05, false]]],
	"gn": ["res://scenes/floor_g.tscn", [[Vector3(-5.6, 0.05, 2.5), 1.57, -0.05, true]]],
	"8": ["res://scenes/floor_08.tscn", [[Vector3(0, 0.05, 10), 0.0, 0.0, true], [Vector3(5.6, 7.25, -6.0), -1.57, 0.0, true]]],
}
func _initialize() -> void:
	var key: String = OS.get_cmdline_user_args()[0]
	var gs = root.get_node("GameState")
	await process_frame; await process_frame
	if key == "gn":
		gs.new_game("night")
	gs.test_mode = true
	gs.stair_from = 3
	var q := int(OS.get_cmdline_user_args()[1]) if OS.get_cmdline_user_args().size() > 1 else 3
	root.get_node("Graphics").apply(q)
	root.get_node("Graphics").auto_mode = false
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
		if key == "gn":
			f.player.set_phone(true)
		for k in 40: await process_frame
		root.get_texture().get_image().save_png("user://floor_%s_%d%s.png" % [key, i, "" if q == 3 else "_q%d" % q])
		i += 1
	print("saved"); quit()

func _finalize() -> void:
	preload("res://tests/user_files.gd").restore(_user_files)
