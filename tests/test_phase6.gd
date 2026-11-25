extends SceneTree
## Phase 6: Night Shift, New Game+, voice notes, Memories, Daily Corridor,
## Floor 9, title menu, endings.  godot --headless --path . -s res://tests/test_phase6.gd
var _user_files := preload("res://tests/user_files.gd").backup()   # never touch the player's save
var fails := 0
var gs
var dread
const FILES := ["user://save.json", "user://settings.json", "user://unlocks.json", "user://daily.json"]

func check(cond: bool, name: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond: fails += 1

func wait(s: float) -> void:
	await create_timer(s).timeout

func open_scene(path: String) -> Node:
	var f = load(path).instantiate()
	root.add_child(f)
	await wait(0.4)
	if "director" in f and f.director:
		f.director.enabled = false
	return f

func find_label(n: Node, needle: String, layer := -1) -> Label3D:
	for c in n.get_children():
		if c is Label3D and needle in c.text and (layer < 0 or c.layers == layer):
			return c
		var r := find_label(c, needle, layer)
		if r: return r
	return null

func find_meta(n: Node, key: String, value = null) -> Node:
	for c in n.get_children():
		if c.has_meta(key) and (value == null or c.get_meta(key) == value):
			return c
		var r := find_meta(c, key, value)
		if r: return r
	return null

func _initialize() -> void:
	gs = root.get_node("GameState")
	dread = root.get_node("Dread")
	# autoload _ready() (which calls new_game) runs after _initialize in script mode
	await process_frame
	await process_frame
	var bak := {}
	for p in FILES:
		bak[p] = FileAccess.open(p, FileAccess.READ).get_as_text() if FileAccess.file_exists(p) else ""
	gs.test_mode = true
	await t_night()
	await t_voice_and_memories()
	await t_daily()
	await t_floor9()
	await t_menu_and_ending()
	for p in FILES:
		if bak[p] != "":
			FileAccess.open(p, FileAccess.WRITE).store_string(bak[p])
		elif FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	print("\n%d failure(s)" % fails)
	quit(1 if fails > 0 else 0)

func t_night() -> void:
	gs.new_game("night", true)
	check(gs.night() and is_equal_approx(gs.light_scale(), 0.6), "night: Night Shift dims every light to 60 percent")
	check(gs.count("battery") == 3 and gs.count("diya") == 4, "NG+: starts with +2 batteries and +2 diyas")
	dread.reset(0); dread.add(10)
	check(is_equal_approx(dread.value, 13.0), "night: fear builds 30%% faster (%.1f)" % dread.value)
	dread.reset(0)
	var f = await open_scene("res://scenes/floor_g.tscn")
	var l0: Light3D = f.kit.lights[0]
	var design: float = 1.7 * (f.kit.FILL if l0.has_meta("spot") else 1.0)
	check(is_equal_approx(l0.light_energy, design * 0.6), "night: floor lamps are dimmed (%.2f)" % l0.light_energy)
	if l0.has_meta("spot"):
		await process_frame
		var s: SpotLight3D = l0.get_meta("spot")
		check(is_equal_approx(s.light_energy, l0.light_energy * s.ratio), "night: the lamp's downlight dims with it (%.2f)" % s.light_energy)
	var lie: Label3D = find_label(f, "A LIE", 2)
	check(f.rules.rules.size() == 4 and lie != null, "night: the board carries an extra rule, marked a lie on the camera layer only")
	f.player.phone_up = true
	f.show_rules()
	check("struck through" in f.hud._panel_text.text, "night: reading the board through the phone reveals the lie")
	f.queue_free(); await wait(0.1)
	f = await open_scene("res://scenes/floor_05.tscn")
	check(is_equal_approx(float(f.sup.cfg.speed_chase), 4.4 * 1.15), "night: the Supervisor is 15 percent faster")
	check(is_equal_approx(float(f.sup.cfg.hearing_range), 18.0 * 1.2), "night: ...and hears 20 percent further")
	f.queue_free(); await wait(0.1)
	f = await open_scene("res://scenes/floor_02.tscn")
	check(f.required == 10, "night: Room 213 needs 10 in a row")
	check(find_label(f.corridor, "A LIE", 2) != null, "night: the corridor board also hides a lie")
	f.queue_free(); await wait(0.1)
	gs.new_game()
	check(not gs.night() and is_equal_approx(gs.light_scale(), 1.0), "normal runs are unaffected")

func t_voice_and_memories() -> void:
	gs.new_game()
	gs.unlocks.erase("memories")
	var f = await open_scene("res://scenes/floor_03.tscn")
	var tape := find_meta(f, "item", "voice_1")
	check(tape != null, "voice: a voice note lies on Floor 3")
	f._on_interact(tape)
	check(gs.count("voice") == 1, "voice: picking it up adds one voice note")
	dread.reset(80)
	f.play_voice_note()
	await wait(6.6)
	check(dread.value <= 46.0 and gs.count("voice") == 0, "voice: playing it calms you (80 -> %.1f) and uses it up" % dread.value)
	f.queue_free(); await wait(0.1)
	gs.collectibles.append("g_guard")
	gs.save_game()
	check(gs.unlocks.get("memories", []).has("voice_1") and gs.unlocks.memories.has("g_guard"), "memories: found things are remembered")
	gs.new_game()
	var Memories = load("res://scripts/systems/memories.gd")
	check(gs.unlocks.memories.has("g_guard"), "memories: they survive a new game")
	check(Memories.all().size() >= 25 and Memories.found().size() >= 2, "memories: registry has %d entries, %d found" % [Memories.all().size(), Memories.found().size()])
	var u = JSON.parse_string(FileAccess.open("user://unlocks.json", FileAccess.READ).get_as_text())
	check(u.get("memories", []).has("g_guard"), "memories: persisted to user://unlocks.json")

func t_daily() -> void:
	var save_before := FileAccess.open("user://save.json", FileAccess.READ).get_as_text() if FileAccess.file_exists("user://save.json") else ""
	var LB = load("res://scripts/systems/leaderboard.gd")
	var seqs := []
	for run in 2:
		gs.new_game("daily")
		var f = await open_scene("res://scenes/floor_02.tscn")
		check(f.daily and f.required == 9999, "daily: endless mode (run %d)" % run)
		var seq := []
		for i in 12:
			f._new_pass()
			seq.append(f.current)
		seqs.append(seq)
		if run == 1:
			f.streak = 7
			f.current = "figure"
			f.judge_continue()        # wrong: walked past an anomaly
			await wait(6.0)
			check(gs.last_scene_request == "res://scenes/menu.tscn", "daily: one mistake ends the run")
			check(LB.best(LB.today()) >= 7, "daily: score recorded as today's best (%d)" % LB.best(LB.today()))
		f.queue_free(); await wait(0.1)
	check(seqs[0] == seqs[1] and seqs[0].filter(func(a): return a != "").size() > 0, "daily: same anomaly sequence every time today")
	var save_after := FileAccess.open("user://save.json", FileAccess.READ).get_as_text() if FileAccess.file_exists("user://save.json") else ""
	check(save_before == save_after, "daily: never touches the story save")
	check(not LB.submit(LB.today(), 3), "daily: a lower score isn't a new best")

func t_floor9() -> void:
	gs.new_game("floor9")
	gs.last_scene_request = ""
	var f = await open_scene("res://scenes/floor_09.tscn")
	check(f.storeys.size() == 9 and not f.revealed, "9: a model of the tower with nine storeys")
	for i in 9:
		f.remember(i)
		f.hud.hide_panel()
	await wait(0.8)
	check(f.revealed and gs.collectibles.has("f9_owner") and f.exit_door != null, "9: remembering every floor names the Supervisor and opens a door")
	f.on_use("ground", null)
	await wait(8.5)
	check(gs.unlocks.get("floor9_done", false) and gs.last_scene_request == "res://scenes/menu.tscn", "9: leaving returns you to the title")
	f.queue_free(); await wait(0.1)

func t_menu_and_ending() -> void:
	gs.new_game()
	gs.unlocks["floor9"] = true
	gs.unlocks["new_game_plus"] = true
	var m = load("res://scenes/menu.tscn").instantiate()
	root.add_child(m)
	await wait(0.3)
	var texts := []
	for c in m._box.get_children():
		if c is Button: texts.append(c.text)
	var joined := " | ".join(texts)
	check("New Game+" in joined and "Floor 9" in joined and "Daily Corridor" in joined and "Memories" in joined, "menu: unlocked modes appear (%s)" % joined)
	m._open_memories()
	await wait(0.1)
	check(not m._box.visible, "menu: the Memories journal opens")
	m.queue_free(); await wait(0.1)
	gs.new_game()
	gs.choices["ending"] = "escape"
	gs.unlocks["loops"] = 1
	var e = load("res://scenes/ending.tscn").instantiate()
	root.add_child(e)
	await wait(0.2)
	check(int(gs.unlocks.loops) == 2 and "second building" in str(e._lines[-1]), "ending: a second escape knows it's the second building")
	e.queue_free(); await wait(0.1)

func _finalize() -> void:
	preload("res://tests/user_files.gd").restore(_user_files)
