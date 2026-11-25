extends SceneTree
## Phase 8: regressions for the second code review + a full end-to-end
## playthrough with REAL scene changes (title → G … 8 → ending → title),
## including a fall and a quit/Continue mid-run.
## godot --headless --path . -s res://tests/test_phase8.gd
var fails := 0
var gs
var dread
const FILES := ["user://save.json", "user://settings.json", "user://unlocks.json", "user://daily.json"]

func check(cond: bool, name: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond: fails += 1

func wait(s: float) -> void:
	await create_timer(s).timeout

func find_meta(n: Node, key: String, value = null) -> Node:
	for c in n.get_children():
		if c.has_meta(key) and (value == null or c.get_meta(key) == value):
			return c
		var r := find_meta(c, key, value)
		if r: return r
	return null

func open(path: String) -> Node:
	var f = load(path).instantiate()
	root.add_child(f)
	await wait(0.4)
	if "director" in f and f.director:
		f.director.enabled = false
	return f

func _initialize() -> void:
	gs = root.get_node("GameState")
	dread = root.get_node("Dread")
	await process_frame; await process_frame
	var bak := {}
	for p in FILES:
		bak[p] = FileAccess.open(p, FileAccess.READ).get_as_text() if FileAccess.file_exists(p) else ""
	root.get_node("Graphics").auto_mode = false
	await regressions()
	await playthrough()
	for p in FILES:
		if bak[p] != "":
			FileAccess.open(p, FileAccess.WRITE).store_string(bak[p])
		elif FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	print("\n%d failure(s)" % fails)
	quit(1 if fails > 0 else 0)

# ---------------------------------------------------------------- review regressions
func regressions() -> void:
	gs.test_mode = true
	# 1. Floor 9 breakdown stays in Floor 9
	gs.new_game("floor9"); gs.last_scene_request = ""
	var f = await open("res://scenes/floor_09.tscn")
	f.player.light.visible = false
	dread.reset(99); dread.add(5)
	await wait(0.5)
	check(gs.last_scene_request == "" and gs.mode == "floor9" and dread.value < 50, "R1: a breakdown on Floor 9 doesn't throw you into a story floor")
	f.queue_free(); await wait(0.1)
	# 2. touch: hiding the layer releases a held joystick
	gs.new_game(); gs.settings.touch_controls = 1
	f = await open("res://scenes/floor_g.tscn")
	f.touch._joy_index = 0
	f.touch.set_joystick(Vector2(0, -0.8))
	f.touch.visible = false
	await process_frame
	check(not Input.is_action_pressed("move_forward") and f.touch._joy_index == -1, "R2: dialogs/pause release a held touch joystick")
	gs.settings.touch_controls = 0
	f.queue_free(); await wait(0.1)
	# 3. Floor 1: carried item isn't duplicated after Continue; returns are checkpointed
	gs.new_game(); gs.carry = "o_item_2"; gs.checkpoint = {"returned": [0, 1]}
	f = await open("res://scenes/floor_01.tscn")
	check(find_meta(f, "item", "o_item_2") == null and find_meta(f, "item", "o_item_0") == null, "R3: the carried item and returned items aren't back on their desks")
	check(f.returned[0] and f.returned[1] and not f.returned[2], "R3: returned lockers restored from the checkpoint")
	check(f.use_locker(2) and gs.carry == "", "R3: the carried item can still be returned")
	f.queue_free(); await wait(0.1)
	# 4. Floor 5: Supervisor spawns far from a checkpoint position
	gs.new_game(); gs.choices["hunt_sense"] = "sound"
	gs.checkpoint = {"fuses": ["u_fuse_scaffold"], "pos": [-11.0, 1.5, -9.5]}
	f = await open("res://scenes/floor_05.tscn")
	var dist: float = f.sup.global_position.distance_to(f.player.global_position)
	check(dist >= 12.0, "R4: Floor 5 respawn keeps the Supervisor >= 12 m away (%.1f m)" % dist)
	f.queue_free(); await wait(0.1)
	# 6. memories survive loading an older save
	gs.new_game()
	gs.unlocks["memories"] = ["g_wake"]
	gs.collectibles = ["g_wake"]
	gs.save_game()                                  # save holds memories [g_wake]
	gs.unlocks["memories"] = ["g_wake", "f9_owner"]  # learned later (e.g. Floor 9)
	gs.load_game()
	check(gs.unlocks.memories.has("f9_owner"), "R6: loading a save never shrinks Memories")
	# 7. Floor 4: mother frozen while a dialog is open
	gs.new_game()
	f = await open("res://scenes/floor_04.tscn")
	f._mother_wait = 0.0
	var m0: Vector3 = f.mother.global_position
	f.hud.ask_code("TEST", 4)
	await wait(1.5)
	check(f.mother.global_position.distance_to(m0) < 0.01, "R7: the household freezes while a keypad is open")
	f.hud.answer_dialog("")
	f.queue_free(); await wait(0.1)
	# 8. Daily: a violation ends the run and keeps the score
	gs.new_game("daily"); gs.last_scene_request = ""
	f = await open("res://scenes/floor_02.tscn")
	f.streak = 5
	f.violate("You ran while something was knocking.")
	await wait(6.0)
	var LB = load("res://scripts/systems/leaderboard.gd")
	check(gs.last_scene_request == "res://scenes/menu.tscn" and LB.best(LB.today()) >= 5, "R8: a Daily rule violation ends the run with its score")
	f.queue_free(); await wait(0.1)
	# 9. Floor 8: falling off the tank top you can climb again; rails exist
	gs.new_game(); gs.checkpoint = {"tank": true}
	f = await open("res://scenes/floor_08.tscn")
	f.player.teleport(Vector3(-8, 0.05, -3.5))
	await f.climb()
	check(f.player.global_position.y > f.TANK_TOP - 0.5, "R9: you can climb the tank again after stepping off")
	f.queue_free(); await wait(0.1)
	# 10. unlock_exit("") keeps the current message
	gs.new_game()
	f = await open("res://scenes/floor_g.tscn")
	f.on_use("register", null); f.hud.hide_panel()
	f.try_cabinet("333")
	check("key" in f.hud._msg.text.to_lower(), "R10: solving doesn't blank the message on screen")
	f.queue_free(); await wait(0.1)
	# 11. Floor 4 photos become memories
	gs.new_game()
	f = await open("res://scenes/floor_04.tscn")
	f.on_item_taken("h_photo_beach", find_meta(f, "item", "h_photo_beach"))
	check(gs.collectibles.has("h_photo_beach"), "R11: photos are collected as memories")
	f.queue_free(); await wait(0.1)
	# 12. voice cassettes don't respawn
	gs.new_game(); gs.collectibles.append("voice_1")
	f = await open("res://scenes/floor_03.tscn")
	check(find_meta(f, "item", "voice_1") == null, "R12: a collected voice note doesn't respawn")
	f.queue_free(); await wait(0.1)
	# batching sanity: static geometry merged, gameplay objects untouched
	gs.new_game()
	f = await open("res://scenes/floor_01.tscn")
	check(f.batched_meshes > 10 and find_meta(f, "item", "o_item_0").visible, "perf: static geometry is batched (%d meshes), items still interactive" % f.batched_meshes)
	f.queue_free(); await wait(0.1)

# ---------------------------------------------------------------- end-to-end
func current() -> Node:
	return current_scene

func wait_scene(path: String, timeout := 12.0) -> bool:
	var t := 0.0
	while t < timeout:
		if current_scene and current_scene.scene_file_path == path:
			await wait(0.6)
			if "director" in current_scene and current_scene.director:
				current_scene.director.enabled = false
			return true
		await wait(0.2); t += 0.2
	return false

func climb_stairs(to_floor: int) -> void:
	var ok := await wait_scene("res://scenes/stairwell.tscn")
	var saved := false
	if ok:
		var d = JSON.parse_string(FileAccess.open("user://save.json", FileAccess.READ).get_as_text())
		saved = int(d.floor) == to_floor
		current().complete_floor()
	check(ok and saved, "flow: stairwell reached and checkpointed for floor %d" % to_floor)
	check(await wait_scene(gs.FLOOR_SCENES[to_floor]), "flow: arrived on floor %d" % to_floor)

func playthrough() -> void:
	gs.test_mode = false
	gs.settings.touch_controls = 0
	change_scene_to_file("res://scenes/menu.tscn")
	await wait(1.0)
	current()._new()
	check(await wait_scene(gs.FLOOR_SCENES[0]), "E2E: New Game starts on Floor G")
	var f = current()
	f.on_use("register", null); f.hud.hide_panel()
	f.try_cabinet("333")
	f.complete_floor()
	await climb_stairs(1)
	# Floor 1 — first, fail once: fall to G, which stays solved, and climb back
	f = current()
	f.player.teleport(Vector3(0, 0.05, -6))
	f.spawn_extra_chair(); f._extra_t = 0.05
	check(await wait_scene(gs.FLOOR_SCENES[0], 8.0), "E2E: staying with 25 chairs drops you to G")
	f = current()
	check(f.exit_unlocked and gs.falls == 1, "E2E: G remembers it was solved")
	f.complete_floor()
	await climb_stairs(1)
	f = current()
	for k in 6:
		f.on_item_taken("o_item_%d" % k, find_meta(f, "item", "o_item_%d" % k))
		f.use_locker(k)
	f.complete_floor()
	await climb_stairs(2)
	f = current()
	f.streak = f.required
	f._win()
	await climb_stairs(3)
	# quit to the title mid-run and Continue
	change_scene_to_file("res://scenes/menu.tscn")
	await wait(1.0)
	current()._continue()
	check(await wait_scene(gs.FLOOR_SCENES[3]), "E2E: Continue resumes on Floor 3")
	f = current()
	for i in 6:
		f.on_item_taken("r_page_%d" % i, find_meta(f, "item", "r_page_%d" % i))
	f.hud.hide_panel()
	f.complete_floor()
	await climb_stairs(4)
	f = current()
	f.on_item_taken("h_tape", find_meta(f, "item", "h_tape"))
	f.play_tape(); f.hud.hide_panel()
	f.try_study("1406")
	f.choose_letter(true)
	f.sit()
	await wait(7.0)
	check(f.exit_unlocked, "E2E: dinner at 8 opens the front door")
	f.complete_floor()
	await climb_stairs(5)
	f = current()
	f.sup.deactivate()
	for id in ["u_fuse_store", "u_fuse_rebar", "u_fuse_scaffold"]:
		f.on_item_taken(id, find_meta(f, "item", id))
	f.use_hoist()
	f.complete_floor()
	await climb_stairs(6)
	f = current()
	f._start_hunt()
	f.player.teleport(Vector3(2.6, 0.05, -20.0))
	f.shadow.global_position = Vector3(0, 0.05, -16.0)
	f.pull_lever()
	f.complete_floor()
	await climb_stairs(7)
	f = current()
	for i in 6:
		f.free_worker(i)
	check(f.freed_count() == 6, "E2E: the ID cards from Floor 1 free all six workers on Floor 7")
	f.complete_floor()
	await climb_stairs(8)
	f = current()
	await f.climb()
	f.player.teleport(f.FATHER + Vector3(-1.8, 0.05, 0))
	var t := 0.0
	while not f.hud.dialog_open() and t < 25.0:
		await wait(0.5); t += 0.5
	check(f.hud.dialog_open(), "E2E: Papa's final choice appears")
	f.hud.answer_dialog(1)
	check(await wait_scene(gs.ENDING, 10.0), "E2E: the ending plays")
	check(gs.choices.get("ending") == "truth" and gs.choices.get("letter") == "kept" and gs.choices.get("workers") == "freed", "E2E: TRUTH ending earned by keeping the letter and freeing the six")
	check(gs.falls == 1 and not gs.unlocks.get("floor9_run_flag", false), "E2E: one fall recorded (so no Floor 9 unlock from this run)")
	await wait(1.0)
	check(not FileAccess.file_exists("user://save.json"), "E2E: the finished run's save is cleared")
	var memories: Array = gs.unlocks.get("memories", [])
	check(memories.has("h_letter") and memories.has("id_mahadev") and memories.has("r_report"), "E2E: memories from the run are kept")
	gs.test_mode = true
