extends SceneTree
## Headless logic tests:  godot --headless -s res://tests/test_floor2.gd
var fails := 0

func check(cond: bool, name: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond: fails += 1

func _initialize() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	check(main.anomalies.size() >= 10, "anomaly pool loaded (%d)" % main.anomalies.size())
	check(main.rules.rules.size() == 3, "3 floor rules loaded")
	check(main.corridor.knock_doors.size() == 20, "20 doors built")
	# every anomaly builds without error and yields a different node layout
	main.corridor.build("", 0, false, 7); await process_frame
	var base := _sig(main.corridor)
	for a in main.anomalies:
		main.corridor.build(a.id, 0, false, 7); await process_frame
		check(_sig(main.corridor) != base, "anomaly '%s' visibly changes corridor" % a.id)
	# judgement logic
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
