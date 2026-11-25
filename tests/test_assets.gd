extends SceneTree
## Real assets: CC0 props, Rocketbox characters + mocap, recorded audio.
## godot --headless --path . -s res://tests/test_assets.gd
var _user_files := preload("res://tests/user_files.gd").backup()   # never touch the player's save
var fails := 0

func check(cond: bool, name: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond: fails += 1

func wait(s: float) -> void:
	await create_timer(s).timeout

func _initialize() -> void:
	var gs = root.get_node("GameState")
	await process_frame; await process_frame
	gs.test_mode = true
	root.get_node("Graphics").auto_mode = false
	var P = load("res://scripts/world/props.gd")
	var C = load("res://scripts/world/characters.gd")
	var S = load("res://scripts/systems/sfx.gd")
	# props
	var ok := 0; var total := 0
	for id in DirAccess.get_directories_at("res://assets/models"):
		total += 1
		var n: Node3D = P.spawn(id, Vector3.ZERO, true)
		if n and n is StaticBody3D and P.bounds(id).size.length() > 0.01:
			ok += 1
		if n: n.free()
	check(ok == total and total >= 40, "props: %d/%d CC0 models load with colliders" % [ok, total])
	var desk: Node3D = P.spawn("metal_office_desk", Vector3(1.6, 0.79, 0.8), true)
	var sh: BoxShape3D = (desk.get_child(0) as CollisionShape3D).shape
	check(sh.size.distance_to(Vector3(1.6, 0.79, 0.8)) < 0.02, "props: fit-to-size scales model + collider (%s)" % sh.size)
	desk.free()
	check(P.spawn("no_such_model") == null, "props: a missing model returns null (callers fall back)")
	# characters
	for id in ["Construction_Male_02", "Construction_Male_04", "Construction_Male_07", "Female_Adult_02", "Male_Adult_03"]:
		var who: Node3D = C.spawn(id, {"idle": "m_idle_neutral_01", "walk": "m_walk_slow_01"}, {"height": 1.8})
		root.add_child(who)
		C.play(who, "walk")
		await process_frame
		var ap: AnimationPlayer = C.player(who)
		var mats := 0; var textured := 0
		for mi in who.find_children("*", "MeshInstance3D", true, false):
			for s in (mi as MeshInstance3D).mesh.get_surface_count():
				mats += 1
				var m := (mi as MeshInstance3D).get_surface_override_material(s) as StandardMaterial3D
				if m and m.albedo_texture: textured += 1
		check(ap and ap.is_playing() and ap.current_animation == "mocap/walk" and textured == mats and C.skeleton(who).get_bone_count() == 82,
			"characters: %s — 82-bone skeleton, %d/%d textured surfaces, mocap walk playing" % [id, textured, mats])
		who.queue_free()
	for clip in ["m_idle_neutral_01", "m_walk_slow_01", "m_walk_neutral_01", "m_run_neutral", "f_idle_neutral_01", "f_walk_neutral_01"]:
		var a: Animation = C.clip(clip)
		check(a != null and a.loop_mode == Animation.LOOP_LINEAR and a.length > 0.5, "characters: clip %s loops (%.1f s)" % [clip, a.length if a else 0.0])
	# characters in the game
	gs.new_game()
	var f = load("res://scenes/floor_05.tscn").instantiate(); root.add_child(f)
	await wait(0.5)
	check(f.sup.avatar != null, "game: the Supervisor is a real mocap character")
	f.sup.activate(Vector3(0, 0.05, -10)); f.sup.waypoints = [Vector3(10, 0, -10)]; f.sup._wp = 0; f.sup._wait = 0.0
	await wait(1.5)
	check(C.player(f.sup.avatar).current_animation in ["mocap/walk", "mocap/run"], "game: it walks with a mocap walk cycle (%s)" % C.player(f.sup.avatar).current_animation)
	check(f.surface_at(Vector3(-3, 0, 4)) == "water" and f.surface_at(Vector3(0, 0, 0)) == "concrete", "game: Floor 5 puddles give wet footsteps")
	f.queue_free(); await wait(0.1)
	gs.new_game()
	f = load("res://scenes/floor_04.tscn").instantiate(); root.add_child(f)
	await wait(0.4)
	check(f._mother_avatar != null, "game: Mother is a real (faceless) character")
	f.queue_free(); await wait(0.1)
	gs.new_game()
	f = load("res://scenes/floor_07.tscn").instantiate(); root.add_child(f)
	await wait(0.4)
	var avs := 0
	for w in f.workers:
		if w.node.has_meta("avatar"): avs += 1
	check(avs == 6, "game: all six workers are real characters")
	f.queue_free(); await wait(0.1)
	gs.new_game()
	f = load("res://scenes/floor_01.tscn").instantiate(); root.add_child(f)
	await wait(0.4)
	var models := 0
	for n in f.find_children("*", "", true, false):
		if n.scene_file_path.ends_with("_1k.gltf"): models += 1
	check(models > 40, "game: Floor 1 is dressed with real models (%d instances)" % models)
	f.queue_free(); await wait(0.1)
	# a freed floor releases its cached models (VRAM doesn't climb floor after floor)
	var P2 = load("res://scripts/world/props.gd")
	gs.new_game()
	var f3 = load("res://scenes/floor_03.tscn").instantiate(); root.add_child(f3)
	await wait(0.3)
	var cached_during: int = P2._scenes.size()
	f3.queue_free(); await process_frame; await process_frame
	check(cached_during > 0 and P2._scenes.is_empty(), "props: leaving a floor releases its %d cached models" % cached_during)
	# audio
	for id in ["step_carpet", "step_concrete", "step_tile", "step_water", "knock", "slam", "creak", "clang", "splash", "heartbeat", "sting", "boom", "tape", "rain", "wind", "drone_a", "drone_b", "ui_click"]:
		var st: AudioStream = S.get_stream(id)
		var recorded := st is AudioStreamRandomizer or st is AudioStreamOggVorbis or (st is AudioStreamWAV and st.resource_path != "")
		check(recorded, "audio: %s uses a recording (%s)" % [id, st.get_class() if st else "null"])
	var steps: AudioStreamRandomizer = S.get_stream("step_carpet")
	check(steps.streams_count >= 4 and steps.random_pitch > 1.0, "audio: footsteps vary take and pitch (%d takes)" % steps.streams_count)
	check(S.get_stream("hum") is AudioStreamWAV and S.get_stream("ring") is AudioStreamWAV, "audio: hum/ring still synthesised (no CC0 recording)")
	check((S.get_stream("rain") as AudioStreamOggVorbis).loop and (S.get_stream("heartbeat") as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED, "audio: ambience and heartbeat loop")
	# credits: attribution + licence notices are in the shipped game
	var CR = load("res://scripts/systems/credits.gd")
	var full: String = CR.full_text()
	var need := ["InspectorJ", "congusbongus", "swuing", "ceberation", "EminYILDIRIM", "Bart", "http://opengameart.org", "tcarisland", "Copyright (c) 2020 Microsoft", "Permission is hereby granted", "Godot Engine", "FreeType"]
	var missing := need.filter(func(k): return not (k in full))
	check(missing.is_empty(), "credits: every CC-BY author, the Rocketbox MIT notice and Godot's licences are shown %s" % str(missing))
	var menu = load("res://scenes/menu.tscn").instantiate(); root.add_child(menu)
	await process_frame
	var cb: Button = null
	for bt in menu.find_children("*", "Button", true, false):
		if bt.text == "Credits": cb = bt
	if cb: cb.pressed.emit()
	await process_frame
	var panel = menu.get_node_or_null("Credits")
	check(cb != null and panel != null and (panel.find_children("*", "RichTextLabel", true, false)[0] as RichTextLabel).text.length() > 5000, "credits: the title screen has a Credits page")
	menu.queue_free(); await process_frame
	check(not ("synthesised in code" in FileAccess.get_file_as_string("res://scripts/ui/ending.gd")), "credits: the ending no longer claims all sound is synthesised")
	var b := Button.new(); root.add_child(b)
	await process_frame
	check(b.pressed.get_connections().size() > 0, "audio: every button clicks")
	b.free()
	print("\n%d failure(s)" % fails)
	quit(1 if fails > 0 else 0)

func _finalize() -> void:
	preload("res://tests/user_files.gd").restore(_user_files)
