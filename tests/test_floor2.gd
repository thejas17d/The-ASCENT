extends SceneTree
## Headless logic tests:  godot --headless --path . -s res://tests/test_floor2.gd
## Backs up and restores the real save + settings files.
var _user_files := preload("res://tests/user_files.gd").backup()   # never touch the player's save
var fails := 0

func check(cond: bool, name: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond: fails += 1

func _backup(path: String) -> String:
	return FileAccess.open(path, FileAccess.READ).get_as_text() if FileAccess.file_exists(path) else ""

func _restore(path: String, text: String) -> void:
	if text != "":
		FileAccess.open(path, FileAccess.WRITE).store_string(text)
	elif FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _initialize() -> void:
	var gs = root.get_node("GameState")
	var dread = root.get_node("Dread")
	var save_bak := _backup(gs.SAVE_PATH)
	var set_bak := _backup(gs.SETTINGS_PATH)
	gs.new_game(); dread.reset(0)
	gs.test_mode = true          # intercept scene changes (fall-down, stairwell)
	gs.checkpoint = {}
	var main = load("res://scenes/floor_02.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.director.enabled = false

	# ---------------------------------------------------------- corridor + loop
	check(main.anomalies.size() >= 10, "anomaly pool loaded (%d)" % main.anomalies.size())
	check(main.rules.rules.size() == 3, "3 floor rules loaded")
	check(main.corridor.knock_doors.size() == 20, "20 doors built")
	check(main.current == "", "new game starts with a clean pass")
	main.corridor.build("", 0, false, 7); await process_frame
	var base := _sig(main.corridor)
	for a in main.anomalies:
		main.corridor.build(a.id, 0, false, 7); await process_frame
		check(_sig(main.corridor) != base, "anomaly '%s' visibly changes corridor" % a.id)
	# nothing in the corridor may intersect a door (review #10)
	main.corridor.build("stains", 0, false, 7); await process_frame
	check(_overlaps_doors(main.corridor).is_empty(), "no props/decals inside doors %s" % str(_overlaps_doors(main.corridor)))
	main.corridor.build("", 0, false, 7); await process_frame
	check(_overlaps_doors(main.corridor).is_empty(), "baseline props clear of doors")
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
	# figure never vanishes (review #5)
	main.streak = 0; main.corridor.build("figure", 0, false, 7); await process_frame
	main.player.teleport(Vector3(0, 0.05, -36))
	main.went_deep = false
	await create_timer(0.5).timeout
	check(main.corridor.figure != null and main.corridor.figure.visible, "figure stays visible up close")
	main.player.teleport(Vector3(0, 0.05, 2.0)); main.went_deep = false
	# pickups/notes only in the lobby (review #9)
	var outside := 0
	for i in 20:
		main._new_pass()
		for c in _all(main.corridor):
			if (c.has_meta("pickup") or c.has_meta("note")) and c.global_position.z < 0.0:
				outside += 1
	check(outside == 0, "pickups and notes never spawn in the judged corridor")
	main.went_deep = false

	# ---------------------------------------------------------- knocking rules
	main.streak = 3; main.busy = false
	main.player.teleport(Vector3(0, 0.05, -6)); main.went_deep = false
	main._start_knocking()
	main.player.is_running = true
	main._update_knocking(0.1)
	check(main.streak == 3 and not main.busy, "running is not punished in the knock grace period (review #3)")
	main.player.is_running = false
	main._knock_left = 0.0
	# hiding clears is_running (review #2)
	main.player.is_running = true
	main.player.hide_in(main.corridor.hide_spot)
	check(not main.player.is_running, "hiding clears running state")
	main.player.leave_hiding()
	main.player.teleport(Vector3(0, 0.05, 2.0)); main.went_deep = false

	# ---------------------------------------------------------- save / load
	gs.add_item("diya", 5); main.streak = 4; main._checkpoint()
	var diyas: int = gs.count("diya")
	gs.new_game()
	check(gs.load_game(), "save file loads")
	check(int(gs.checkpoint.get("streak", -1)) == 4, "checkpoint streak restored")
	check(gs.count("diya") == diyas, "inventory restored")
	FileAccess.open(gs.SAVE_PATH, FileAccess.WRITE).store_string('{"floor": 2, "checkpoint": "bad", "falls": 1}')
	check(gs.load_game() and gs.count("battery") == 1 and gs.checkpoint.is_empty(), "malformed save loads with defaults (review #8)")
	FileAccess.open(gs.SAVE_PATH, FileAccess.WRITE).store_string("not json")
	check(not gs.load_game(), "corrupt save is rejected, not crashed on")
	# breakdown: the building sends you down to Floor 1 (saved, counted once)
	main.streak = 6; main._checkpoint(); main.busy = false
	var falls_before: int = gs.falls
	gs.last_scene_request = ""
	dread.reset(0); dread.add(200)
	await create_timer(3.0).timeout
	gs.load_game()
	check(gs.floor_num == 1 and gs.last_scene_request == gs.FLOOR_SCENES[1], "breakdown sends you down to Floor 1 (saved)")
	check(gs.altered_level(1) == 1, "the floor below is marked as changed")
	check(gs.falls == falls_before + 1, "breakdown counts exactly one fall")
	check(dread.value < 100, "breakdown resets dread (%.1f)" % dread.value)
	main.busy = false; main.player.input_enabled = true
	main.hud.fade_to(0.0, 0.01)

	# ---------------------------------------------------------- items
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
	gs.items.chalk = 2
	main.chalk_marks.clear()
	for z in [-5, -6, -7]:
		main._on_chalk(Vector3(1.5, 1.2, z), Vector3(-1, 0, 0))
	check(main.chalk_marks.size() == 2 and gs.count("chalk") == 0, "chalk places marks and runs out")
	gs.items.diya = 1
	main._on_diya(main.player.global_position)
	check(main.in_safe_zone(), "diya creates safe zone")
	dread.reset(50)
	await create_timer(1.0).timeout
	check(dread.value < 50, "dread falls inside diya glow (%.1f)" % dread.value)
	main.clear_placed()
	main.player.battery = 0.0
	dread.reset(20)
	await create_timer(1.0).timeout
	check(dread.value > 20, "dread rises in darkness (%.1f)" % dread.value)
	main.player.battery = 100.0
	dread.reset(0)

	# ---------------------------------------------------------- phone / hiding / breath
	check((main.player.cam.cull_mask & 2) == 0, "camera-only layer hidden by default")
	main.player.set_phone(true)
	check((main.player.cam.cull_mask & 2) != 0, "phone reveals camera-only layer")
	main.player.set_phone(false)
	main.streak = 3; main.corridor.build("", 3, false, 7); await process_frame
	var ghost: Label3D = null
	for c in _all(main.corridor):
		if c is Label3D and c.layers == 2:
			ghost = c
	check(ghost != null and _inside_any_door(main.corridor, ghost.global_position) == "", "phone clue exists and is not inside a door (review #4)")
	main.player.hide_in(main.corridor.hide_spot)
	await create_timer(0.5).timeout
	check(main.player.hiding and not main.busy, "hiding does not trigger a pass judgement")
	var gasps := [0]
	main.player.gasped.connect(func(): gasps[0] += 1)
	Input.action_press("breath")
	await create_timer(7.0).timeout
	Input.action_release("breath")
	check(gasps[0] == 1, "holding breath past empty gasps exactly once (got %d) (review #1)" % gasps[0])
	await create_timer(0.2).timeout
	main.player.leave_hiding()
	check(not main.player.hiding, "player leaves hiding")
	main.player.teleport(Vector3(0, 0.05, 2.0)); main.went_deep = false
	dread.reset(0)

	# ---------------------------------------------------------- panels (review #11)
	main.busy = false
	main.hud.show_panel("x")
	main._on_interact(null)
	check(not main.hud.panel_open(), "E closes a panel even when looking at nothing")
	# notes
	var nid: String = main.notes.keys()[0]
	main.read_note(nid)
	check(gs.collectibles.has(nid) and main.hud.panel_open(), "reading a note collects it")
	main._on_interact(null)

	# ---------------------------------------------------------- director
	dread.reset(0)
	var low: Array = main.director.candidates().map(func(e): return e.id)
	check(not low.has("fake_figure") and low.has("flicker"), "director gates events by dread")
	dread.reset(80)
	var fired: String = main.director.fire()
	check(fired != "", "director fires an event (%s)" % fired)
	check(not main.director.candidates().map(func(e): return e.id).has(fired), "fired event goes on cooldown")
	for id in ["flicker", "footsteps", "door_slam", "phone_ring", "whisper", "fake_chalk", "fake_figure"]:
		check(main.perform_event(id), "event '%s' performs" % id)
	dread.reset(0)

	# ---------------------------------------------------------- graphics / settings
	var g = root.get_node("Graphics")
	for q in 4:
		g.apply(q)
		await process_frame
		check(g.quality == q and g.env != null, "quality preset %s applies" % g.PRESETS[q])
	gs.settings.sensitivity = 1.7
	gs.save_settings()
	gs.settings.sensitivity = 1.0
	gs.load_settings()
	check(is_equal_approx(float(gs.settings.sensitivity), 1.7), "settings persist separately from saves")

	_restore(gs.SAVE_PATH, save_bak)
	_restore(gs.SETTINGS_PATH, set_bak)
	print("\n%d failure(s)" % fails)
	quit(1 if fails > 0 else 0)

## Signature of everything visible, recursing into children (door labels etc).
func _sig(n: Node) -> String:
	var s := ""
	for c in n.get_children():
		s += c.get_class() + str(c.position) + str(c.rotation) if c is Node3D else ""
		if c is Label3D: s += c.text
		if c is MeshInstance3D and c.material_override: s += str(c.material_override.albedo_color)
		if c is OmniLight3D: s += str(c.light_color)
		if c is Decal: s += "decal"
		s += _sig(c)
	return s

## Door volumes as AABBs (closed doors only).
func _door_boxes(cor: Node) -> Array:
	var out := []
	for d in cor.knock_doors:
		if d and absf(d.rotation.y) < 0.01:
			var p: Vector3 = d.global_position
			out.append(AABB(p - Vector3(0.06, 1.05, 0.56), Vector3(0.12, 2.1, 1.12)))
	return out

func _inside_any_door(cor: Node, p: Vector3) -> String:
	for b in _door_boxes(cor):
		if b.has_point(p):
			return str(b)
	return ""

## Every descendant.
func _all(n: Node) -> Array:
	var out := []
	for c in n.get_children():
		out.append(c)
		out.append_array(_all(c))
	return out

## Props/decals (not walls/doors/trim) whose centre sits inside a door volume.
func _overlaps_doors(cor: Node) -> Array:
	var bad := []
	for c in cor._dyn.get_children():
		if c is Decal or (c is MeshInstance3D and c.mesh is CylinderMesh) or (c is Node3D and c.get_child_count() > 3 and not c.has_meta("door_index")):
			var hit := _inside_any_door(cor, c.global_position)
			if hit != "":
				bad.append(c.name)
	return bad

func _finalize() -> void:
	preload("res://tests/user_files.gd").restore(_user_files)
