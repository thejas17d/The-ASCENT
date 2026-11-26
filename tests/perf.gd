extends SceneTree
## Performance profile (windowed, real GPU, vsync off):
##   godot --path . -s res://tests/perf.gd -- <quality 0-3>
##   godot --rendering-method mobile --path . -s res://tests/perf.gd -- 1
## Prints one row per scene: load ms, avg/max frame ms, draw calls, objects, primitives, VRAM.
var _user_files := preload("res://tests/user_files.gd").backup()   # never touch the player's save
const SCENES := [
	["menu", "res://scenes/menu.tscn", Vector3.ZERO, 0.0],
	["intro", "res://scenes/intro.tscn", Vector3.ZERO, 0.0],
	["G", "res://scenes/floor_g.tscn", Vector3(0, 0.05, 4.6), 0.0],
	["stair", "res://scenes/stairwell.tscn", Vector3(0, 0.05, -0.8), 0.0],
	["1", "res://scenes/floor_01.tscn", Vector3(0, 0.05, -2.0), 0.0],
	["2", "res://scenes/floor_02.tscn", Vector3(0, 0.05, 2.0), 0.0],
	["3", "res://scenes/floor_03.tscn", Vector3(0, 0.05, 14.0), 0.0],
	["4", "res://scenes/floor_04.tscn", Vector3(-1.0, 0.05, 1.6), 0.55],
	["5", "res://scenes/floor_05.tscn", Vector3(0, 0.05, 10.5), 0.0],
	["6", "res://scenes/floor_06.tscn", Vector3(0, 0.05, 9.0), 0.0],
	["7", "res://scenes/floor_07.tscn", Vector3(0, 0.05, 10.5), 0.0],
	["8", "res://scenes/floor_08.tscn", Vector3(0, 0.05, 5.0), 0.0],
	["9", "res://scenes/floor_09.tscn", Vector3(0, 0.05, 8.0), 0.0],
]

func _initialize() -> void:
	var gs = root.get_node("GameState")
	await process_frame; await process_frame
	gs.test_mode = true
	var q := int(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else 2
	root.get_node("Graphics").apply(q)
	root.get_node("Graphics").auto_mode = false   # measure the preset as chosen
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	print("PERF renderer=%s quality=%s window=%s device=%s" % [RenderingServer.get_current_rendering_method(),
		root.get_node("Graphics").PRESETS[q], DisplayServer.window_get_size(), RenderingServer.get_video_adapter_name()])
	print("PERF scene | load ms | avg ms | p95 ms | max ms | draw calls | objects | prims (k) | VRAM MB")
	for s in SCENES:
		gs.new_game("floor9" if s[0] == "9" else "normal")
		gs.stair_from = 3
		var t0 := Time.get_ticks_usec()
		var n = load(s[1]).instantiate()
		root.add_child(n)
		var load_ms := (Time.get_ticks_usec() - t0) / 1000.0
		await process_frame
		if "director" in n and n.director:
			n.director.enabled = false
			n.busy = true
			n.hud.fade_to(0.0, 0.01)
			n.player.teleport(s[2]); n.player.rotation.y = s[3]
			n.player.light.visible = true
		for i in 60: await process_frame        # warm up (shader compile, particles)
		var times: Array = []
		var dc := 0; var obj := 0; var prim := 0
		var last := Time.get_ticks_usec()
		for i in 180:
			await process_frame
			var now := Time.get_ticks_usec()
			times.append((now - last) / 1000.0)
			last = now
			dc = max(dc, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
			obj = max(obj, int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
			prim = max(prim, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
		times.sort()
		var avg := 0.0
		for t in times: avg += t
		avg /= times.size()
		var vram := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
		print("PERF %s | %.0f | %.2f | %.2f | %.2f | %d | %d | %.0f | %.0f" % [s[0], load_ms, avg, times[int(times.size() * 0.95)], times[-1], dc, obj, prim / 1000.0, vram])
		n.queue_free()
		await process_frame; await process_frame
	# corridor rebuild cost (Floor 2 rebuilds every pass)
	var f2 = load("res://scenes/floor_02.tscn").instantiate()
	root.add_child(f2)
	await process_frame
	var t1 := Time.get_ticks_usec()
	for i in 5:
		f2.corridor.build("", 3, false)
	print("PERF corridor rebuild avg ms: %.1f" % ((Time.get_ticks_usec() - t1) / 5000.0))
	f2.queue_free()
	quit()

func _finalize() -> void:
	preload("res://tests/user_files.gd").restore(_user_files)
