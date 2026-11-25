extends SceneTree
## Plays every floor's puzzle through in code and checks each rule's consequence.
## godot --headless --path . -s res://tests/test_floors.gd
## Scene changes are intercepted (GameState.test_mode); real save files are restored.
var _user_files := preload("res://tests/user_files.gd").backup()   # never touch the player's save
var fails := 0
var gs
var dread

func check(cond: bool, name: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond: fails += 1

func wait(s: float) -> void:
	await create_timer(s).timeout

func frames(n := 3) -> void:
	for i in n:
		await physics_frame

func _bak(p: String) -> String:
	return FileAccess.open(p, FileAccess.READ).get_as_text() if FileAccess.file_exists(p) else ""

func _restore(p: String, t: String) -> void:
	if t != "":
		FileAccess.open(p, FileAccess.WRITE).store_string(t)
	elif FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

## Fresh run state, then load a floor scene.
func open_floor(path: String, setup := Callable()) -> Node:
	gs.new_game()
	gs.test_mode = true
	gs.last_scene_request = ""
	dread.reset(0)
	if setup.is_valid():
		setup.call()
	var f = load(path).instantiate()
	root.add_child(f)
	await wait(0.4)
	f.director.enabled = false
	return f

func close_floor(f: Node) -> void:
	paused = false
	f.queue_free()
	await frames(2)

func find_meta(n: Node, key: String, value = null) -> Node:
	for c in n.get_children():
		if c.has_meta(key) and (value == null or c.get_meta(key) == value):
			return c
		var r := find_meta(c, key, value)
		if r:
			return r
	return null

func _initialize() -> void:
	gs = root.get_node("GameState")
	dread = root.get_node("Dread")
	await process_frame   # let autoload _ready() (new_game) run first
	await process_frame
	var b_save := _bak("user://save.json"); var b_set := _bak("user://settings.json"); var b_unl := _bak("user://unlocks.json")
	await t_ground()
	await t_office()
	await t_records()
	await t_residence()
	await t_hunt()
	await t_inversion()
	await t_collapse()
	await t_roof()
	await t_stairwell()
	await t_progression()
	_restore("user://save.json", b_save); _restore("user://settings.json", b_set); _restore("user://unlocks.json", b_unl)
	print("\n%d failure(s)" % fails)
	quit(1 if fails > 0 else 0)

# ---------------------------------------------------------------- G
func t_ground() -> void:
	var f = await open_floor("res://scenes/floor_g.tscn")
	check(f.floor_index == 0 and not f.exit_unlocked, "G: starts locked")
	check(find_meta(f, "stair_exit") != null and find_meta(f, "board") != null, "G: has a stair exit and a rule board")
	f.on_use("booth", null)
	check(not f.booth_door.get_meta("opened", false), "G: booth stays shut before signing")
	f.on_use("register", null)
	await frames()
	check(f.signed and f.booth_door.get_meta("opened", false), "G: signing the register opens the booth (true rule)")
	f.hud.hide_panel()
	check(not f.try_cabinet("123") and not f.exit_unlocked, "G: wrong cabinet code fails")
	check(f.try_cabinet("333") and f.exit_unlocked, "G: clock time 3:33 opens the key cabinet -> stairs unlocked")
	var d0: float = dread.value
	f.answer_phone()
	check(f.phone_answered and dread.value > d0, "G: answering the phone costs dread but is survivable (incomplete rule)")
	f.on_use("lift", null)
	await wait(2.8)
	check(gs.last_scene_request == gs.FLOOR_SCENES[0] and gs.altered_level(0) == 1 and gs.falls == 1, "G: calling the lift = violation, building resets G (altered)")
	await close_floor(f)

# ---------------------------------------------------------------- 1
func t_office() -> void:
	var f = await open_floor("res://scenes/floor_01.tscn")
	check(f.chair_count() == 24, "1: there are exactly 24 chairs")
	check(not f.exit_unlocked, "1: exit locked while desks hold items")
	var item0 := find_meta(f, "item", "o_item_0")
	check(f.on_item_taken("o_item_0", item0) and gs.carry == "o_item_0", "1: picking up an item carries it")
	var item1 := find_meta(f, "item", "o_item_1")
	f.on_item_taken("o_item_1", item1)
	check(gs.carry == "o_item_0" and is_instance_valid(item1), "1: hands full — can't carry two")
	check(not f.use_locker(3), "1: wrong locker refuses the item")
	check(f.use_locker(0) and gs.collectibles.has("id_ramesh"), "1: right locker accepts it and gives the ID card")
	for k in range(1, 6):
		var it := find_meta(f, "item", "o_item_%d" % k)
		f.on_item_taken("o_item_%d" % k, it)
		f.use_locker(k)
	check(f.desks_remaining() == 0 and f.exit_unlocked, "1: all six returned -> stairs unlock (true rule)")
	var ids := 0
	for k in ["ramesh", "suresh", "abdul", "joseph", "mahadev", "babu"]:
		if gs.collectibles.has("id_" + k): ids += 1
	check(ids == 6, "1: all six ID cards kept for Floor 7")
	var ghost := false
	for c in f.get_children():
		if c is Label3D and c.layers == 2 and c.text == "MAHADEV": ghost = true
	check(ghost, "1: Mahadev's name exists only on the camera layer")
	# 25th chair: leaving through the entrance resolves it
	f.player.teleport(Vector3(0, 0.05, -6))
	f.spawn_extra_chair()
	check(f.chair_count() == 25, "1: a 25th chair appears")
	f.player.teleport(Vector3(0, 0.05, 0.6))
	await wait(0.3)
	check(f.chair_count() == 24 and gs.last_scene_request == "", "1: stepping back out through the entrance resolves it (incomplete rule)")
	f.player.teleport(Vector3(0, 0.05, -6))
	f.spawn_extra_chair()
	f._extra_t = 0.05
	await wait(2.8)
	check(gs.last_scene_request == gs.FLOOR_SCENES[0], "1: staying with 25 chairs sends you down to G")
	await close_floor(f)

# ---------------------------------------------------------------- 3
func t_records() -> void:
	var f = await open_floor("res://scenes/floor_03.tscn")
	check(f.nav.navigation_mesh.get_polygon_count() > 20, "3: navmesh baked")
	check(not f.blackout and f.sup.state_name() == "dormant" and f.sup.visible, "3: it stands reading at an aisle end")
	# looking at it stops the reading and moves it
	var head: Vector3 = f.sup.global_position + Vector3(0, 1.6, 0)
	var stand: Vector3 = f.sup.global_position + (-f.sup.global_transform.basis.z) * 6.0
	f.player.teleport(Vector3(stand.x, 0.05, stand.z))
	f.player.look_at(Vector3(head.x, f.player.global_position.y, head.z), Vector3.UP)
	f.player.cam.rotation.x = 0.0
	await frames(2)
	f.player.cam.look_at(head, Vector3.UP)
	await frames(3)
	check(not f.sup.visible and f._relocate_t > 0.0, "3: looking straight at it makes it vanish and relocate")
	f.player.cam.rotation = Vector3.ZERO
	f.player.rotate_y(PI)
	await wait(4.5)            # it reappears elsewhere
	f.player.cam.rotation = Vector3(-1.4, 0, 0)   # stare at the floor: unobserved
	var r0: float = f.reading
	await wait(1.0)
	check(f.reading > r0, "3: it reads while unobserved (%.2f -> %.2f)" % [r0, f.reading])
	# power -> blackout -> it hunts; fuse ends it
	f.power = 0.3
	await wait(0.6)
	check(f.blackout and f.sup.state_name() != "dormant", "3: power out -> blackout, it starts hunting")
	var fuse: Node3D = f.fuses[0].node
	check(f.use_fuse(fuse) and not f.blackout and f.power > 40.0, "3: a fuse box restores power and ends the hunt")
	check(not f.use_fuse(fuse), "3: fuse box has a cooldown")
	# pages
	for i in 6:
		var pg := find_meta(f, "item", "r_page_%d" % i)
		f.on_item_taken("r_page_%d" % i, pg)
	check(f.pages == 6 and f.exit_unlocked, "3: six pages assemble the report -> stairs unlock")
	f.hud.hide_panel()
	await close_floor(f)
	# too slow -> it finishes
	f = await open_floor("res://scenes/floor_03.tscn")
	f.player.rotate_y(PI)
	f.reading = 99.9
	await wait(2.8)
	check(gs.last_scene_request == gs.FLOOR_SCENES[2], "3: if it finishes reading you fall to Floor 2")
	await close_floor(f)

# ---------------------------------------------------------------- 4
func t_residence() -> void:
	var f = await open_floor("res://scenes/floor_04.tscn")
	f.player.teleport(Vector3(4, 0.05, 1.0))
	check(not f.play_tape(), "4: tape deck is empty at first")
	f.on_item_taken("h_tape", find_meta(f, "item", "h_tape"))
	check(f.play_tape() and f.tape_played, "4: the cassette plays Papa's message")
	f.hud.hide_panel()
	f.on_item_taken("h_photo_birthday", find_meta(f, "item", "h_photo_birthday"))
	f.hud.hide_panel()
	check(not f.try_study("0000") and not f.study_open, "4: wrong study code fails")
	check(f.try_study("1406") and f.study_open, "4: the birthday 1406 opens the forbidden study (false rule)")
	check(f.minutes > 40, "4: the clock advances with each discovery (7:%02d)" % f.minutes)
	f.sit()
	check(not f.seated, "4: can't sit down before dinner is called")
	f.choose_letter(true)
	check(gs.choices.get("letter") == "kept" and f.dinner_t > 0.0, "4: keeping the letter is recorded; dinner is called (7:59)")
	f.sit()
	await wait(7.0)
	check(f.seated and f.exit_unlocked, "4: sitting before 8 -> the front door opens (true rule)")
	await close_floor(f)
	# late for dinner
	f = await open_floor("res://scenes/floor_04.tscn")
	f.player.teleport(Vector3(4, 0.05, 1.0))
	f.choose_letter(false)
	check(gs.choices.get("letter") == "burned", "4: burning the letter is recorded")
	f.dinner_t = 0.05
	await wait(2.8)
	check(gs.last_scene_request == gs.FLOOR_SCENES[3], "4: missing dinner at 8 sends you down to Floor 3")
	await close_floor(f)
	# making mother try to see you
	f = await open_floor("res://scenes/floor_04.tscn")
	f._mother_wait = 999.0
	var m: Node3D = f.mother
	var front: Vector3 = m.global_position + (-m.global_transform.basis.z) * 1.2
	f.player.teleport(Vector3(front.x, 0.05, front.z))
	await wait(4.2)
	check(gs.last_scene_request == gs.FLOOR_SCENES[3], "4: standing in front of Mother makes her try -> violation")
	await close_floor(f)

# ---------------------------------------------------------------- 5
func t_hunt() -> void:
	var f = await open_floor("res://scenes/floor_05.tscn")
	var sense: String = f.hunt_sense
	var other := "sound" if sense == "light" else "light"
	check(sense in ["light", "sound"] and gs.choices.get("hunt_sense") == sense, "5: one sense chosen for this playthrough (%s)" % sense)
	check(not f.sup.senses.sight and f.sup.senses[sense] and not f.sup.senses[other], "5: it is blind except for that one sense")
	check(not f.sup.lure(Vector3(0, 0, 0), other), "5: it ignores lures of the false sense")
	check(f.sup.lure(Vector3(0, 0, 0), sense) and f.sup.state_name() == "investigate", "5: it walks to lures of the true sense (the clue)")
	f.player.teleport(Vector3(-3, 0.05, 6.5))
	await frames(2)
	f.player.teleport(Vector3(-3, 0.05, 4))
	await frames(4)
	check(f.player.noise >= 0.8, "5: stepping in a puddle makes noise (%.2f)" % f.player.noise)
	f.player.teleport(Vector3(0, 0.05, 10))
	check(not f.use_hoist(), "5: hoist needs three fuses")
	for id in ["u_fuse_store", "u_fuse_rebar", "u_fuse_scaffold"]:
		f.on_item_taken(id, find_meta(f, "item", id))
	check(f.fuses.size() == 3 and gs.checkpoint.get("fuses", []).size() == 3, "5: fuses are checkpointed")
	check(f.use_hoist() and f.exit_unlocked, "5: three fuses power the hoist -> exit")
	var deaths: int = gs.deaths
	f.sup.caught_player.emit()
	await wait(3.0)
	check(gs.deaths == deaths + 1 and gs.last_scene_request == gs.FLOOR_SCENES[5], "5: being caught here is death (restart floor 5)")
	await close_floor(f)
	# restart restores the checkpoint
	f = await open_floor("res://scenes/floor_05.tscn", func():
		gs.choices["hunt_sense"] = "sound"
		gs.checkpoint = {"fuses": ["u_fuse_store"], "pos": [9.0, 0.05, -6.0]})
	check(f.fuses.size() == 1 and f.player.global_position.distance_to(Vector3(9, 0.05, -6)) < 0.5, "5: death restarts at the last fuse checkpoint")
	await close_floor(f)

# ---------------------------------------------------------------- 6
func t_inversion() -> void:
	var f = await open_floor("res://scenes/floor_06.tscn")
	check(not f.a_open and not f.exit_unlocked, "6: doors sealed at start")
	f.player.teleport(Vector3(-2.5, 0.05, 0.0))   # stand on A1 ...
	await wait(3.6)
	f.player.teleport(Vector3(2.5, 0.05, 0.0))    # ... then A2: the shadow is still on A1
	await wait(0.3)
	check(f.a_open, "6: you + your 3-second-late shadow hold both A plates")
	f.player.teleport(Vector3(-3.0, 0.05, -8.0))
	await wait(3.6)
	f.player.teleport(Vector3(3.0, 0.05, -8.0))
	await wait(0.3)
	check(f.b_open and f.hunting, "6: B plates open the second door — and the shadow turns on you")
	f.player.phone_up = false
	f.show_rules()
	check("GNIDLIUB" in f.hud._panel_text.text, "6: the rule board reads backwards without the camera")
	f.hud.hide_panel()
	# trap it: shadow inside the mirror room, you outside, pull the lever
	f.player.teleport(Vector3(2.6, 0.05, -20.0))
	f.shadow.global_position = Vector3(0, 0.05, -16.0)
	check(f.pull_lever() and f.trapped and f.exit_unlocked, "6: lever traps it in the mirror room -> stairs")
	await close_floor(f)
	f = await open_floor("res://scenes/floor_06.tscn")
	f._start_hunt()
	f.player.teleport(Vector3(0, 0.05, 0.0))
	f.shadow.global_position = Vector3(0.3, 0.05, 0.0)
	await wait(3.0)
	check(gs.last_scene_request == gs.FLOOR_SCENES[6], "6: if it reaches you, you die")
	await close_floor(f)

# ---------------------------------------------------------------- 7
func t_collapse() -> void:
	var f = await open_floor("res://scenes/floor_07.tscn", func():
		for k in ["ramesh", "suresh", "abdul", "joseph", "mahadev", "babu"]:
			gs.collectibles.append("id_" + k))
	check(f.exit_unlocked, "7: the stairs are open (freeing them is a choice)")
	check(gs.choices.get("workers") == "left", "7: by default you leave them")
	# a worker creeps only while unobserved
	var w: Node3D = f.workers[0].node
	f.player.teleport(Vector3(-10, 0.05, 1.0))
	f.player.look_at(Vector3(w.global_position.x, f.player.global_position.y, w.global_position.z), Vector3.UP)
	f.player.cam.rotation = Vector3.ZERO
	await frames(2)
	var d0: float = w.global_position.distance_to(f.player.global_position)
	await wait(0.6)
	check(absf(w.global_position.distance_to(f.player.global_position) - d0) < 0.05, "7: watched, it stays frozen")
	f.player.rotate_y(PI)
	await wait(0.8)
	check(w.global_position.distance_to(f.player.global_position) < d0 - 0.3, "7: unwatched, it creeps closer")
	for i in 6:
		f.free_worker(i)
	check(f.freed_count() == 6 and gs.choices.get("workers") == "freed", "7: all six freed with their ID cards")
	check(gs.checkpoint.get("freed", []).size() == 6, "7: freed workers are checkpointed")
	# looking at it kills
	f.player.teleport(Vector3(0, 0.05, 2.5))
	f.player.rotation = Vector3.ZERO
	f.player.cam.look_at(f.OVERSEER + Vector3(0, 2.0, 0), Vector3.UP)
	await wait(4.6)
	check(gs.last_scene_request == gs.FLOOR_SCENES[7], "7: holding it in view kills you")
	await close_floor(f)

# ---------------------------------------------------------------- 8
func t_roof() -> void:
	var f = await open_floor("res://scenes/floor_08.tscn", func():
		gs.choices["letter"] = "kept"; gs.choices["workers"] = "freed")
	check(not f.chase_started, "8: quiet on arrival")
	f.player.teleport(Vector3(0, 0.05, 5.0))
	await wait(0.3)
	check(f.chase_started and f.sup.state_name() == "chase", "8: stepping onto the roof starts the chase")
	await f.climb()
	check(f.on_tank and gs.checkpoint.get("tank", false) and f.sup.state_name() == "dormant", "8: the tank is safe ground and a checkpoint")
	f.player.teleport(f.FATHER + Vector3(-1.8, 0.05, 0))
	await wait(18.5)
	check(f.hud.dialog_open(), "8: Papa speaks, then the final choice appears")
	f.hud.answer_dialog(1)
	await wait(2.5)
	check(gs.choices.get("ending") == "truth" and gs.last_scene_request == gs.ENDING, "8: TRUTH ending when the letter was kept and all six freed")
	check(gs.unlocks.get("floor9", false), "8: a no-fall run unlocks Floor 9")
	await close_floor(f)
	f = await open_floor("res://scenes/floor_08.tscn", func():
		gs.choices["letter"] = "burned"; gs.checkpoint = {"tank": true})
	check(f.on_tank, "8: dying after the climb restarts on the tank")
	f.player.teleport(f.FATHER + Vector3(-1.8, 0.05, 0))
	await wait(18.5)
	f.hud.answer_dialog(1)    # TRUTH is disabled -> falls back to escape
	await wait(2.5)
	check(gs.choices.get("ending") == "escape", "8: without the letter, only ESCAPE is possible")
	await close_floor(f)

# ---------------------------------------------------------------- stairwell + progression
func t_stairwell() -> void:
	var f = await open_floor("res://scenes/stairwell.tscn", func():
		gs.stair_from = 3; gs.floor_num = 4)
	check(f.floor_index == 4 and gs.floor_num == 4, "stairs: arriving from 3 leads to 4")
	var story := false
	for c in f.get_children():
		if c is Label3D and c.text == "INSPECTION:  PASSED": story = true
	check(story, "stairs: the story beat for floor 3 is on the wall")
	f.complete_floor()
	await wait(1.2)
	check(gs.last_scene_request == gs.FLOOR_SCENES[4], "stairs: the top door opens onto floor 4")
	await close_floor(f)

func t_progression() -> void:
	var f = await open_floor("res://scenes/floor_01.tscn")
	f.unlock_exit("")
	f.complete_floor()
	await wait(1.6)
	check(gs.last_scene_request == gs.STAIRWELL and gs.floor_num == 2 and gs.stair_from == 1 and gs.solved_floor(1), "flow: completing a floor goes to the stairwell, marks it solved")
	await close_floor(f)
	# a solved floor stays open when you are sent back to it
	f = await open_floor("res://scenes/floor_01.tscn", func():
		gs.solved[1] = true; gs.altered[1] = 1)
	check(f.exit_unlocked and f.desks_remaining() == 0, "flow: falling back to a solved floor keeps its exit open")
	await close_floor(f)
	for n in range(0, 9):
		check(ResourceLoader.exists(gs.FLOOR_SCENES[n]), "flow: floor %d scene exists" % n)

func _finalize() -> void:
	preload("res://tests/user_files.gd").restore(_user_files)
