extends SceneTree
## Visual systems (v0.10): room trim/decals/probes, downlights, windows + the
## night outside, moonlight, lightning, torch cookie, material tuning, presets.
## godot --headless --path . -s res://tests/test_visuals.gd
var _user_files := preload("res://tests/user_files.gd").backup()   # never touch the player's save
var fails := 0
var gs: Node
var G: Node

func check(cond: bool, name: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond: fails += 1

func wait(s: float) -> void:
	await create_timer(s).timeout

func open(path: String) -> Node:
	gs.new_game()
	var f = load(path).instantiate(); root.add_child(f)
	await wait(0.4)
	return f

func close(f: Node) -> void:
	f.queue_free()
	await process_frame; await process_frame

func _initialize() -> void:
	gs = root.get_node("GameState"); G = root.get_node("Graphics")
	await process_frame; await process_frame
	gs.test_mode = true
	G.auto_mode = false
	G.apply(1)
	var save_bak := FileAccess.get_file_as_string(gs.SAVE_PATH) if FileAccess.file_exists(gs.SAVE_PATH) else ""
	var Mat = load("res://scripts/systems/mat_lib.gd")

	# ---------------------------------------------------------------- Floor G: kit room dressing
	var f = await open("res://scenes/floor_g.tscn")
	var decals: Array = f.find_children("*", "Decal", true, false)
	check(decals.size() >= 20, "room: grime, damp and dirt decals placed (%d)" % decals.size())
	check(decals.all(func(d): return d.texture_albedo != null), "room: every decal has its generated texture")
	check(f.find_children("*", "ReflectionProbe", true, false).size() >= 1, "room: a reflection probe captures the lobby")
	var thin := 0
	for mi in f.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh is BoxMesh and (mi.mesh as BoxMesh).size.y <= 0.13 and (mi.mesh as BoxMesh).size.x + (mi.mesh as BoxMesh).size.z > 3.0:
			thin += 1
	check(f.batched_meshes > 0 or thin > 0, "room: skirting / cornice strips built (batched into the shell)")
	# windows: glass with a collider, iron grille bars
	var glass := 0
	for b in f.find_children("*", "StaticBody3D", true, false):
		for mi in b.find_children("*", "MeshInstance3D", false, false):
			if mi.material_override == f.kit.m.glass:
				glass += 1
	check(glass == 2, "windows: two glazed windows in the lobby, each with a collider (%d)" % glass)
	check(G.env.background_mode == Environment.BG_SKY and G.env.sky != null, "outside: a night sky behind the windows")
	var moons: Array = f.find_children("*", "DirectionalLight3D", true, false)
	check(moons.size() == 1 and moons[0].shadow_enabled and moons[0].visible, "outside: moonlight casts shadows on Medium")
	G.apply(0)
	check(not moons[0].visible, "outside: no unshadowed moon on Low (it would light every wall)")
	G.apply(1)
	check(f.find_children("*", "MultiMeshInstance3D", true, false).size() >= 2, "outside: skyline towers + lit windows are instanced")
	# lamps: downlights follow their fixture
	if G.forward_plus():
		var l0: Light3D = f.kit.lights[0]
		check(l0.has_meta("spot"), "lamps: tube fixtures get a downlight on Forward+")
		var s: SpotLight3D = l0.get_meta("spot")
		l0.visible = false
		await process_frame
		check(not s.is_visible_in_tree(), "lamps: the downlight goes out with its lamp (blackouts, flickers)")
		l0.visible = true
		check(not s.shadow_enabled, "lamps: downlight shadows are off on Medium (budget)")
		G.apply(2)
		check(s.shadow_enabled, "lamps: downlight shadows on High")
		G.apply(1)
	# torch + clock + props
	var cookie: Texture2D = f.player.light.light_projector
	check(cookie != null and cookie.resource_path.ends_with("torch_cookie.png"), "torch: uses the generated flashlight cookie")
	var clocks := 0
	for n in f.get_children():
		if n is Node3D and n.get_child_count() >= 15 and n.find_children("*", "MeshInstance3D", false, false).size() >= 15:
			clocks += 1
	check(clocks >= 1, "lobby: the 3:33 clock is an analog clock with hands")
	var shadowless := true
	var plants := 0
	for b in f.find_children("*", "StaticBody3D", true, false):
		for g in b.find_children("*", "GeometryInstance3D", true, false):
			if g.scene_file_path.contains("potted_plant") or (g.get_parent() and g.get_parent().scene_file_path.contains("potted_plant")):
				plants += 1
				if g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
					shadowless = false
	check(plants > 0 and shadowless, "props: foliage casts no shadows (%d plant meshes)" % plants)
	await close(f)

	# ---------------------------------------------------------------- Floor 1: CRT phosphor
	f = await open("res://scenes/floor_01.tscn")
	var crt := 0
	for mi in f.find_children("*", "MeshInstance3D", true, false):
		if mi.material_override is ShaderMaterial and (mi.material_override as ShaderMaterial).shader.resource_path.ends_with("crt_screen.gdshader"):
			crt += 1
	check(crt >= 12, "office: every monitor glows with the CRT shader (%d)" % crt)
	await close(f)

	# ---------------------------------------------------------------- Floor 5: rain night + lightning
	f = await open("res://scenes/floor_05.tscn")
	check(f._moon != null and G.env.background_mode == Environment.BG_SKY, "site: monsoon sky and a low moon")
	gs.settings["reduced_flashing"] = true
	var e0: float = f._moon.light_energy
	f._lightning()
	await wait(0.1)
	check(is_equal_approx(f._moon.light_energy, e0), "site: no lightning flash with Reduced flashing on")
	gs.settings["reduced_flashing"] = false
	f._lightning()
	await wait(0.05)
	check(f._moon.light_energy > e0 + 0.5, "site: lightning flashes the slab")
	await close(f)

	# ---------------------------------------------------------------- materials + presets
	var ceil_m: StandardMaterial3D = Mat.pbr("white_plaster_02", 2.0, Color(0.86, 0.85, 0.81))
	check(is_equal_approx(ceil_m.normal_scale, 0.45), "materials: per-texture normal strength (plaster ceiling 0.45)")
	var pf: Node3D = load("res://scripts/world/props.gd").spawn("hanging_picture_frame_02")
	var clear := false
	for mi in pf.find_children("*", "MeshInstance3D", true, false):
		for k in (mi as MeshInstance3D).mesh.get_surface_count():
			var o = (mi as MeshInstance3D).get_surface_override_material(k)
			if o and o.resource_name == "clear_glass":
				clear = true
	check(clear, "props: glTF glass is see-through (picture artwork shows)")
	pf.free()
	G.apply(1)
	var env: Environment = G.make_environment()
	if G.forward_plus():
		check(env.volumetric_fog_enabled and not env.ssao_enabled, "Medium: volumetric fog on, SSAO off (measured trade)")
		G.apply(2); G.configure(env)
		check(env.volumetric_fog_enabled and env.ssao_enabled, "High: fog and SSAO")
	G.apply(1)
	for p in ["torch_cookie", "grime_base", "water_stain", "mould", "floor_dirt"]:
		check(Mat.fx(p) != null, "fx: %s.png imported" % p)

	if save_bak != "":
		var fw := FileAccess.open(gs.SAVE_PATH, FileAccess.WRITE); fw.store_string(save_bak); fw.close()
	print("\n%d failure(s)" % fails)
	quit(1 if fails > 0 else 0)

func _finalize() -> void:
	preload("res://tests/user_files.gd").restore(_user_files)
