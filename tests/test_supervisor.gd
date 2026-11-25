extends SceneTree
## Supervisor AI tests:  godot --headless --path . -s res://tests/test_supervisor.gd
var _user_files := preload("res://tests/user_files.gd").backup()   # never touch the player's save
var fails := 0
var lvl
var sup
var pl

func check(cond: bool, name: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond: fails += 1

func wait(s: float) -> void:
	await create_timer(s).timeout

## Put the Supervisor at `at`, facing `look`, patrolling with zero awareness.
func reset_sup(at: Vector3, look: Vector3) -> void:
	sup.activate(at)
	sup.awareness = 0.0
	sup.saw_player_hide = false
	sup.waypoints = [at]        # stand still unless something happens
	sup._wait = 999.0
	sup.look_at(Vector3(look.x, at.y, look.z), Vector3.UP)
	await physics_frame
	await physics_frame

func place_player(at: Vector3, torch: bool) -> void:
	if pl.hiding:
		pl.leave_hiding()
	pl.teleport(at)
	pl.light.visible = torch
	pl.battery = 100.0
	pl._burst = 0.0; pl._burst_t = 0.0
	await physics_frame

func _initialize() -> void:
	var save_bak := FileAccess.open("user://save.json", FileAccess.READ).get_as_text() if FileAccess.file_exists("user://save.json") else ""
	lvl = load("res://scenes/dev/supervisor_test.tscn").instantiate()
	root.add_child(lvl)
	await wait(0.5)
	lvl.director.enabled = false
	sup = lvl.sup; pl = lvl.player
	var caught := [0]
	sup.caught_player.connect(func(): caught[0] += 1)
	lvl.sup.caught_player.disconnect(lvl._on_caught)   # tests handle catches themselves

	check(lvl.nav.navigation_mesh.get_polygon_count() > 20, "navmesh baked (%d polys)" % lvl.nav.navigation_mesh.get_polygon_count())
	check(lvl.spots.size() == 10, "10 hiding spots (4 desks, 6 lockers)")

	# patrol moves along waypoints
	sup.waypoints = [Vector3(0, 0, -13), Vector3(-10.5, 0, -13)]
	sup.activate(Vector3(0, 0.05, -13)); sup._wp = 1
	await place_player(Vector3(0, 0.05, 14), false)
	var start: Vector3 = sup.global_position
	await wait(4.0)
	check(sup.global_position.distance_to(start) > 2.5, "patrols along waypoints (moved %.1f m)" % sup.global_position.distance_to(start))
	check(sup.state_name() == "patrol", "still patrolling when nothing is sensed")

	# sight: in front, 6 m, torch off -> amber warning beat, then chase
	var states: Array = []
	var rec := func(st): states.append(st)
	sup.state_changed.connect(rec)
	await place_player(Vector3(0, 0.05, 6), false)
	await reset_sup(Vector3(0, 0.05, 12), pl.global_position)
	states.clear()
	await wait(2.5)
	sup.state_changed.disconnect(rec)
	check(states.has("chase"), "sees a player in front and chases (%s)" % str(states))
	check(states.size() > 0 and states[0] == "suspicious", "always warns (amber beat) before chasing at range")

	# walls block sight: player behind a shelf bank, silent
	await place_player(Vector3(6, 0.05, 3.0), false)      # aisle between shelf rows z=1 and z=5
	await reset_sup(Vector3(6, 0.05, 11.5), Vector3(6, 0, 3))   # behind row z=9 / z=5
	await wait(1.5)
	check(not sup.last_perception.get("seen", true), "shelves block line of sight")
	check(sup.awareness < 0.25, "no awareness without line of sight (%.2f)" % sup.awareness)

	# hearing through shelves: a gasp-level noise burst
	pl.noise_burst(1.0, 1.5)
	await wait(0.5)
	check(sup.last_perception.get("heard", false), "hears a loud noise through shelves")
	check(sup.state_name() == "investigate", "loud noise -> investigate (state=%s)" % sup.state_name())

	# crouching in the dark at 10 m is invisible (range 13 * 0.6)
	Input.action_press("crouch")
	await place_player(Vector3(0, 0.05, 2), false)
	await reset_sup(Vector3(0, 0.05, 12), Vector3(0, 0, 2))
	await wait(1.0)
	check(not sup.last_perception.get("seen", true), "crouching in the dark at 10 m is not seen")
	Input.action_release("crouch")

	# torch beam aimed at it from far away
	await place_player(Vector3(0, 0.05, -4), true)
	pl.rotation.y = PI                 # face +Z toward it
	pl.cam.rotation.x = 0.1
	await reset_sup(Vector3(0, 0.05, 11), Vector3(0, 0, 20))   # facing away: can't see you
	sup.senses.sight = false
	await wait(1.2)
	check(sup.last_perception.get("light", false), "notices a torch beam pointed at it")
	check(sup.awareness > 0.5, "torch beam raises awareness (%.2f)" % sup.awareness)
	sup.senses.sight = true

	# sense toggles: sight off -> right in front, silent, unseen
	sup.senses.sight = false; sup.senses.light = false
	await place_player(Vector3(0, 0.05, 7), false)
	await reset_sup(Vector3(0, 0.05, 12), pl.global_position)
	await wait(1.0)
	check(not sup.last_perception.get("seen", true) and sup.awareness < 0.25, "sight disabled = blind (Floor 5 rule)")
	sup.senses.sight = true; sup.senses.light = true

	# catching
	caught[0] = 0
	await place_player(Vector3(0, 0.05, 9), false)
	await reset_sup(Vector3(0, 0.05, 12), pl.global_position)
	await wait(3.0)
	check(caught[0] == 1 and sup.state_name() == "attack", "chases and catches a player standing still")

	# losing the player -> search -> return
	await place_player(Vector3(0, 0.05, 7), false)
	await reset_sup(Vector3(0, 0.05, 12), pl.global_position)
	await wait(1.2)
	var chasing: bool = sup.state_name() == "chase"
	await place_player(Vector3(-9, 0.05, -13), false)      # far away, behind shelving, silent
	await wait(5.0)
	check(chasing and sup.state_name() == "search", "loses you after %ss and searches (state=%s)" % [sup.cfg.lose_after, sup.state_name()])
	sup._state_t = 999.0
	await wait(0.3)
	check(sup.state_name() == "return" or sup.state_name() == "patrol", "gives up the search and returns")

	# learning: repeated use of lockers
	var learned := [""]
	sup.learned.connect(func(k): learned[0] = k)
	sup.hide_memory = {}
	for i in 3:
		sup.note_player_hid("locker", false)
	check(learned[0] == "locker", "learns the player's favourite hiding place")
	sup.last_known = Vector3(-8, 0, -12)                  # near both desks and a left locker
	sup._build_search_queue()
	var first: String = sup.search_queue()[0].get_meta("hide_kind") if sup.search_queue().size() > 0 else ""
	check(first == "locker", "searches learned hiding places first (first=%s)" % first)

	# hiding + holding breath beats a search of an unlearned spot
	sup.hide_memory = {}
	var desk: Node3D = null
	for s in lvl.spots:
		if s.get_meta("hide_kind") == "desk":
			desk = s; break
	await place_player(desk.global_position + Vector3(0, 0, 3), false)
	pl.hide_in(desk)
	Input.action_press("breath")
	await reset_sup(desk.global_position + Vector3(0, 0.05, 3.5), desk.global_position)
	caught[0] = 0
	sup.last_known = desk.global_position
	sup._set_state(sup.S.SEARCH)
	sup._search_queue = [desk]
	await wait(4.5)
	Input.action_release("breath")
	check(caught[0] == 0, "holding breath under an unlearned desk survives a check")
	# …but not if it learned desks
	pl._breath_lock = false; pl.breath = 100.0
	sup.hide_memory = {"desk": 5}
	Input.action_press("breath")
	await reset_sup(desk.global_position + Vector3(0, 0.05, 3.5), desk.global_position)
	sup.last_known = desk.global_position
	sup._set_state(sup.S.SEARCH)
	sup._search_queue = [desk]
	await wait(4.5)
	Input.action_release("breath")
	check(caught[0] == 1, "a learned hiding place gets you found")
	pl.leave_hiding()

	# fair spawn
	await place_player(Vector3(0, 0.05, 14), false)
	var sp: Vector3 = sup.safe_spawn_point(lvl.spawn_points, pl.global_position, lvl.get_world_3d().direct_space_state)
	check(sp != Vector3.INF and sp.distance_to(pl.global_position) >= 12.0, "spawns at least 12 m away (%.1f)" % sp.distance_to(pl.global_position))
	var none: Vector3 = sup.safe_spawn_point([pl.global_position + Vector3(0, 0, -3)], pl.global_position, lvl.get_world_3d().direct_space_state)
	check(none == Vector3.INF, "refuses spawn points that are too close")

	if save_bak != "":
		FileAccess.open("user://save.json", FileAccess.WRITE).store_string(save_bak)
	print("\n%d failure(s)" % fails)
	quit(1 if fails > 0 else 0)

func _finalize() -> void:
	preload("res://tests/user_files.gd").restore(_user_files)
