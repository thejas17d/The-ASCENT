extends SceneTree
## Headless logic tests:  godot --headless --path . -s res://tests/test_floor2.gd
## Backs up and restores any real save file.
var fails := 0

func check(cond: bool, name: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond: fails += 1

func _initialize() -> void:
	var gs = root.get_node("GameState")
	var dread = root.get_node("Dread")
	var backup := ""
	if gs.has_save():
		backup = FileAccess.open(gs.SAVE_PATH, FileAccess.READ).get_as_text()
	gs.new_game(); dread.reset(0)
	var main = load("res://scenes/floor_02.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.director.enabled = false
	# --- Phase 2: corridor + loop
	check(main.anomalies.size() >= 10, "anomaly pool loaded (%d)" % main.anomalies.size())
	check(main.rules.rules.size() == 3, "3 floor rules loaded")
	check(main.corridor.knock_doors.size() == 20, "20 doors built")
	main.corridor.build("", 0, false, 7); await process_frame
	var base := _sig(main.corridor)
	for a in main.anomalies:
		main.corridor.build(a.id, 0, false, 7); await process_frame
		check(_sig(main.corridor) != base, "anomaly '%s' visibly changes corridor" % a.id)
	main.busy = false; main.streak = 0; main.current = ""
	main._judge(true, ""); check(main.streak == 1, "correct judgement increments streak")
	await create_timer(2.0).timeout
	main.current = "figure"; main.judge_continue()
	check(main.streak == 0, "walking past an anomaly resets streak")
	await create_timer(2.0).timeout
	main.streak = 3; main.current = "stains"; main.judge_turn_back()
	check(main.streak == 4, "turning back on anomaly is correct")
	await create_timer(2.0).timeout
	main.streak = 8; main.corridor.build("", 8, true); await process_frame
	check(main.corridor.room213_open, "Room 213 opens at streak 8")
	check(main.pick_anomaly(false) == "", "no anomalies once 213 is open")
	main.streak = 5; main.violate("test"); check(main.streak == 0, "rule violation wipes streak")
	await create_timer(3.0).timeout

	# --- Phase 3: systems
	# save / load round trip
	gs.add_item("diya", 5); main.streak = 4; main._checkpoint()
	var diyas: int = gs.count("diya")
	gs.new_game()
	check(gs.load_game(), "save file loads")
	check(int(gs.checkpoint.get("streak", -1)) == 4, "checkpoint streak restored")
	check(gs.count("diya") == diyas, "inventory restored")
	# items
	gs.items.battery = 1
	main.player.battery = 10.0
	check(main.player.reload() and main.player.battery == 100.0, "battery reload consumes a spare")
	check(not main.player.reload(), "no reload without spares")
	main.player.light.visible = true
	main.player.battery = 50.0
	await create_timer(1.0).timeout
	check(main.player.battery < 50.0, "torch drains battery")
	main.player.battery = 0.0
	check(not main.player.light_on(), "dead battery = no light")
	# chalk
	gs.items.chalk = 2
	main._on_chalk(Vector3(1.5, 1.2, -5), Vector3(-1, 0, 0)); main._on_chalk(Vector3(1.5, 1.2, -6), Vector3(-1, 0, 0))
	main._on_chalk(Vector3(1.5, 1.2, -7), Vector3(-1, 0, 0))
	check(main.chalk_marks.size() == 2 and gs.count("chalk") == 0, "chalk places marks and runs out")
	# diya safe zone lowers dread
	gs.items.diya = 1
	main._on_diya(main.player.global_position)
	check(main.in_safe_zone(), "diya creates safe zone")
	dread.reset(50)
	await create_timer(1.0).timeout
	check(dread.value < 50, "dread falls inside diya glow (%.1f)" % dread.value)
	main.clear_placed()
	# dread rises in dark
	main.player.battery = 0.0
	dread.reset(20)
	await create_timer(1.0).timeout
	check(dread.value > 20, "dread rises in darkness (%.1f)" % dread.value)
	main.player.battery = 100.0
	# breakdown
	var broke := [false]
	dread.breakdown.connect(func(): broke[0] = true)
	main.busy = false
	dread.add(200)
	check(broke[0], "breakdown fires at 100 dread")
	await create_timer(3.0).timeout
	check(dread.value < 100, "breakdown resets dread (%.1f)" % dread.value)
	# phone camera layer
	check((main.player.cam.cull_mask & 2) == 0, "camera-only layer hidden by default")
	main.player.set_phone(true)
	check((main.player.cam.cull_mask & 2) != 0, "phone reveals camera-only layer")
	main.player.set_phone(false)
	# hiding + breath
	main.player.hide_in(main.corridor.hide_spot)
	check(main.player.hiding, "player can hide")
	await create_timer(0.5).timeout
	check(main.player.hiding and not main.busy, "hiding does not trigger a pass judgement")
	var gasped := [false]
	main.player.gasped.connect(func(): gasped[0] = true)
	Input.action_press("breath")
	await create_timer(5.5).timeout
	Input.action_release("breath")
	check(gasped[0], "holding breath too long causes a gasp")
	main.player.leave_hiding()
	check(not main.player.hiding, "player leaves hiding")
	# event director
	dread.reset(0)
	var low: Array = main.director.candidates().map(func(e): return e.id)
	check(not low.has("fake_figure") and low.has("flicker"), "director gates events by dread")
	dread.reset(80)
	var fired: String = main.director.fire()
	check(fired != "", "director fires an event (%s)" % fired)
	check(not main.director.candidates().map(func(e): return e.id).has(fired), "fired event goes on cooldown")
	for id in ["flicker", "footsteps", "door_slam", "phone_ring", "whisper", "fake_chalk", "fake_figure"]:
		check(main.perform_event(id), "event '%s' performs" % id)

	# restore user's save
	if backup != "":
		FileAccess.open(gs.SAVE_PATH, FileAccess.WRITE).store_string(backup)
	else:
		gs.delete_save()
	print("\n%d failure(s)" % fails)
	quit(1 if fails > 0 else 0)

func _sig(n: Node) -> String:
	var s := ""
	for c in n.get_children():
		s += c.get_class() + str(c.position) + str(c.rotation)
		if c is Label3D: s += c.text
		for g in c.get_children():
			if g is MeshInstance3D and g.material_override: s += str(g.material_override.albedo_color)
		if c is MeshInstance3D and c.material_override: s += str(c.material_override.albedo_color)
		if c is OmniLight3D: s += str(c.light_color)
	return s
