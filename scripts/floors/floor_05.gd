extends FloorBase
## FLOOR 5 — THE HUNT. An unfinished slab in the rain. The Supervisor is blind
## to shapes and hunts by ONE sense — light or sound — chosen per playthrough
## (rules: "It hunts by light. It hunts by sound. One of these is false.").
## Lures show which: work lamps flicker, buckets clatter; it walks to one.
## Puddles and loose metal sheets are noise traps. Find 3 fuses, power the
## hoist. Lethal: death restarts from the last fuse checkpoint.

const Supervisor := preload("res://scripts/ai/supervisor.gd")
const LURE_EVERY := 24.0

var kit: Kit
var nav: NavigationRegion3D
var sup: CharacterBody3D
var hunt_sense := "light"
var fuses: Array = []              # ids collected
var work_lamps: Array = []
var hoist_on := false
var _lure_t := 14.0
var _lure_phase := 0
var _rain: AudioStreamPlayer

func _ready() -> void:
	load_floor_data(5)
	if not GameState.choices.has("hunt_sense"):
		GameState.choices["hunt_sense"] = ["light", "sound"][randi() % 2]
	hunt_sense = GameState.choices["hunt_sense"]
	nav = NavigationRegion3D.new(); add_child(nav)
	kit = Kit.new(nav)
	_build()
	_bake()
	setup_common()
	spawn = Vector3(0, 0.05, 10.5)
	_setup_sup()
	_rain = AudioStreamPlayer.new(); _rain.stream = Sfx.get_stream("rain"); _rain.bus = "Ambience"
	_rain.volume_db = -6; _rain.autoplay = true; add_child(_rain)
	begin_floor()

func _build() -> void:
	var c := Vector3(0, 0, -1)
	kit.box(Vector3(30.4, 0.2, 26.4), c + Vector3(0, -0.1, 0), kit.m.concrete)
	kit.box(Vector3(30.4, 0.25, 26.4), c + Vector3(0, 3.5, 0), kit.m.concrete)
	# perimeter: low concrete upstand + invisible safety barrier + plastic sheeting
	for e in [[Vector3(0, 0, 12), Vector3(30, 0, 0.2)], [Vector3(0, 0, -14), Vector3(30, 0, 0.2)],
			[Vector3(-15, 0, -1), Vector3(0.2, 0, 26)], [Vector3(15, 0, -1), Vector3(0.2, 0, 26)]]:
		var p: Vector3 = e[0]; var sz: Vector3 = e[1]
		kit.box(Vector3(max(sz.x, 0.2), 0.9, max(sz.z, 0.2)), p + Vector3(0, 0.45, 0), kit.m.concrete)
		var inv: Node3D = kit.box(Vector3(max(sz.x, 0.2), 3.4, max(sz.z, 0.2)), p + Vector3(0, 1.7, 0), Color(0, 0, 0))
		inv.get_child(1).visible = false
	for i in 7:
		var sx := -13.0 + i * 4.3
		if absf(sx) > 2.5:
			_sheet(Vector3(sx, 2.1, -13.85), 0.0)
		_sheet(Vector3(sx, 2.1, 11.85), 0.0)
	# column grid with rebar sticking out of the tops
	for x in [-10.0, -5.0, 0.0, 5.0, 10.0]:
		for z in [6.0, 1.0, -4.0, -9.0]:
			kit.box(Vector3(0.5, 3.4, 0.5), Vector3(x, 1.7, z), kit.m.concrete)
	# east store room (x 11..15, z -8..-3), door gap on its west side
	kit.box(Vector3(0.2, 3.4, 1.8), Vector3(11.0, 1.7, -7.1), kit.m.paint)
	kit.box(Vector3(0.2, 3.4, 1.8), Vector3(11.0, 1.7, -3.9), kit.m.paint)
	kit.box(Vector3(4.0, 3.4, 0.2), Vector3(13.0, 1.7, -8.0), kit.m.paint)
	kit.box(Vector3(4.0, 3.4, 0.2), Vector3(13.0, 1.7, -3.0), kit.m.paint)
	kit.box(Vector3(1.2, 1.6, 0.6), Vector3(14.2, 0.8, -7.4), kit.m.ply)
	# rebar stack and sand/cement bags
	for k in 9:
		var r := kit.cyl(0.02, 6.0, Vector3(7.0 + (k % 3) * 0.12, 0.1 + (k / 3) * 0.05, 3.0 + (k % 2) * 0.08), kit.m.metal_grey)
		r.rotation.z = PI / 2
	for k in 6:
		kit.box(Vector3(0.6, 0.25, 0.4), Vector3(-6.0 + (k % 3) * 0.62, 0.125 + (k / 3) * 0.25, -11.5), Color(0.6, 0.58, 0.52))
	# scaffold tower with a plank ramp up to its platform (x -12..-9, z -11..-8)
	for p in [Vector3(-12, 0, -11), Vector3(-9, 0, -11), Vector3(-12, 0, -8), Vector3(-9, 0, -8)]:
		kit.cyl(0.03, 2.6, p + Vector3(0, 1.3, 0), kit.m.metal_grey)
	kit.box(Vector3(3.2, 0.08, 3.2), Vector3(-10.5, 1.4, -9.5), kit.m.ply)
	var ramp: Node3D = kit.box(Vector3(1.0, 0.08, 4.6), Vector3(-10.5, 0.7, -5.65), kit.m.ply)
	ramp.rotation.x = atan2(1.4, 4.4)   # rises toward the platform (-Z)
	# hoist (the way up) with its control panel
	kit.box(Vector3(2.2, 3.4, 0.1), Vector3(0, 1.7, -13.85), kit.m.metal_grey, false)
	var cage: Node3D = kit.stair_exit(Vector3(0, 0, -13.75), 0.0, "HOIST ▲  6")
	cage.set_meta("prompt", "Hoist cage")
	var panel: Node3D = kit.box(Vector3(0.45, 0.6, 0.2), Vector3(1.7, 1.2, -13.7), kit.m.metal)
	panel.set_meta("use", "hoist"); panel.set_meta("prompt", "Hoist panel (needs 3 fuses)")
	exit_hint = "The hoist is dead. The panel needs three fuses."
	# fuses
	kit.item("u_fuse_store", "fuse", Vector3(14.2, 1.61, -7.4), "fuse", Color(0.8, 0.65, 0.2))
	kit.item("u_fuse_rebar", "fuse", Vector3(7.2, 0.0, 2.2), "fuse", Color(0.8, 0.65, 0.2))
	kit.item("u_fuse_scaffold", "fuse", Vector3(-11.4, 1.45, -10.4), "fuse", Color(0.8, 0.65, 0.2))
	# noise traps
	for p in [Vector3(-3, 0, 4), Vector3(4, 0, -2), Vector3(-7, 0, -6), Vector3(2.5, 0, -11), Vector3(9, 0, -1), Vector3(-12, 0, 2)]:
		_puddle(p)
	for p in [Vector3(-2.5, 0, -6.5), Vector3(7.5, 0, -10), Vector3(-9, 0, 6.5), Vector3(12.5, 0, 4)]:
		_sheet_metal(p)
	# work lamps (lures) and a few dim bulbs
	for p in [Vector3(-8, 1.8, 3), Vector3(8, 1.8, -6), Vector3(-4, 1.8, -12), Vector3(5, 1.8, 8)]:
		work_lamps.append(kit.lamp(p, "work", Color(1.0, 0.85, 0.6), 0.8, 7.0))
	for p in [Vector3(0, 3.35, 9), Vector3(0, 3.35, -12)]:
		kit.lamp(p, "bulb", Color(1, 0.8, 0.5), 0.7, 5.0)
	kit.board(Vector3(-3.0, 1.5, 11.86), PI, rules.rules)
	kit.note("u_foreman", Vector3(2.0, 0.006, 9.5))
	for p in [Vector3(-14.3, 0, -3.0), Vector3(14.3, 0, 8.0), Vector3(-14.3, 0, 7.0)]:
		kit.locker(p, -PI / 2 if p.x < 0 else PI / 2)
	_make_rain()

func _sheet(p: Vector3, yaw: float) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.75, 0.8, 0.82, 0.35); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.2; m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var s: MeshInstance3D = kit.box(Vector3(4.0, 2.6, 0.01), p, m, false)
	s.rotation.y = yaw
	var tw := s.create_tween().set_loops()
	tw.tween_property(s, "rotation:x", 0.05, randf_range(1.2, 2.0)).set_trans(Tween.TRANS_SINE)
	tw.tween_property(s, "rotation:x", -0.03, randf_range(1.2, 2.0)).set_trans(Tween.TRANS_SINE)

func _puddle(p: Vector3) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.05, 0.06, 0.07); m.roughness = 0.02; m.metallic = 0.3
	kit.box(Vector3(1.6, 0.01, 1.2), p + Vector3(0, 0.005, 0), m, false)
	kit.trigger(p + Vector3(0, 0.5, 0), Vector3(1.6, 1.0, 1.2), func(b):
		if b == player:
			player.noise_burst(0.85, 0.6)
			play_at("splash", player.global_position)
			subtitle("(splash)", 1.0))

func _sheet_metal(p: Vector3) -> void:
	var s: Node3D = kit.box(Vector3(1.2, 0.02, 0.9), p + Vector3(0, 0.01, 0), kit.m.metal_grey, false)
	s.rotation.y = randf() * PI
	kit.trigger(p + Vector3(0, 0.5, 0), Vector3(1.2, 1.0, 1.2), func(b):
		if b == player:
			player.noise_burst(1.0, 0.8)
			play_at("clang", player.global_position)
			subtitle("(CLANG — loose sheet metal)", 1.5))

## Rain falls only outside the slab: four emitters along the open sides.
func _make_rain() -> void:
	for strip in [[Vector3(0, 6, -16.2), Vector3(18, 0.5, 1.6)], [Vector3(0, 6, 14.2), Vector3(18, 0.5, 1.6)],
			[Vector3(17.2, 6, -1), Vector3(1.6, 0.5, 16)], [Vector3(-17.2, 6, -1), Vector3(1.6, 0.5, 16)]]:
		_rain_strip(strip[0], strip[1])

func _rain_strip(at: Vector3, ext: Vector3) -> void:
	var r := GPUParticles3D.new()
	r.amount = 500 if Graphics.quality >= 2 else 160
	r.lifetime = 0.9; r.preprocess = 1.0
	r.visibility_aabb = AABB(Vector3(-20, -8, -20), Vector3(40, 12, 40))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = ext
	pm.direction = Vector3(0.05, -1, 0); pm.spread = 2.0
	pm.initial_velocity_min = 9.0; pm.initial_velocity_max = 11.0
	pm.gravity = Vector3.ZERO
	r.process_material = pm
	var q := QuadMesh.new(); q.size = Vector2(0.01, 0.5)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.7, 0.75, 0.8, 0.3); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = m
	r.draw_pass_1 = q
	r.position = at
	add_child(r)

func _bake() -> void:
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.agent_radius = 0.45; nm.agent_height = 2.0; nm.agent_max_climb = 0.3
	nav.navigation_mesh = nm
	nav.bake_navigation_mesh(false)

func _setup_sup() -> void:
	sup = Supervisor.new()
	add_child(sup)
	sup.player = player
	sup.hide_spots = kit.spots
	sup.senses = {"sight": false, "sound": hunt_sense == "sound", "light": hunt_sense == "light"}
	sup.waypoints = [Vector3(-12, 0, -12), Vector3(12, 0, -12), Vector3(12, 0, 9), Vector3(-12, 0, 9), Vector3(0, 0, -2)]
	sup.caught_player.connect(func(): die("It found you in the rain."))
	var at: Vector3 = sup.safe_spawn_point([Vector3(-12, 0.05, -12), Vector3(12, 0.05, -12), Vector3(0, 0.05, -10)], spawn, null)
	sup.activate(at if at != Vector3.INF else Vector3(0, 0.05, -12))

# ---------------------------------------------------------------- puzzle
func on_item_taken(id: String, node: Node3D) -> bool:
	if not id.begins_with("u_fuse_"):
		return false
	node.queue_free()
	if not fuses.has(id):
		fuses.append(id)
	hud.message("A heavy ceramic fuse. (%d / 3)" % fuses.size(), 3)
	# checkpoint where you stand
	var p := player.global_position
	GameState.checkpoint = {"fuses": fuses.duplicate(), "pos": [p.x, p.y, p.z]}
	GameState.save_game()
	subtitle("(checkpoint)", 1.5)
	return true

func apply_checkpoint(cp: Dictionary) -> void:
	var got: Array = cp.get("fuses", [])
	for c in nav.get_children():
		if c.has_meta("item") and got.has(str(c.get_meta("item"))):
			c.queue_free()
	fuses = got.duplicate()
	var pos: Array = cp.get("pos", [])
	if pos.size() == 3:
		spawn = Vector3(pos[0], pos[1], pos[2])
		player.teleport(spawn)

func on_use(id: String, _node: Node3D) -> void:
	if id == "hoist":
		use_hoist()

func use_hoist() -> bool:
	if hoist_on:
		return false
	if fuses.size() < 3:
		hud.message("The panel has three empty sockets. (%d / 3)" % fuses.size(), 2.5)
		return false
	hoist_on = true
	play_at("clang", Vector3(0, 1.5, -13.5))
	subtitle("(the hoist motor coughs, then hums)", 3)
	unlock_exit("")
	sup.lure(Vector3(0, 0, -12), hunt_sense)   # the motor is loud and bright: it comes
	return true

# ---------------------------------------------------------------- lures (the clue)
func fire_lures() -> void:
	if _lure_phase == 0:
		var l: OmniLight3D = work_lamps[randi() % work_lamps.size()]
		var base := l.light_energy
		var tw := create_tween()
		for i in 5:
			tw.tween_property(l, "light_energy", base * 3.0, 0.08)
			tw.tween_property(l, "light_energy", base * 0.2, 0.1)
		tw.tween_property(l, "light_energy", base, 0.2)
		subtitle("(a work lamp sputters and flares)", 2.5)
		sup.lure(l.global_position, "light")
		_lure_phase = 1
		_lure_t = 7.0
	else:
		var p := Vector3(randf_range(-12, 12), 0.3, randf_range(-11, 9))
		play_at("clang", p)
		subtitle("(somewhere a bucket falls and rolls)", 2.5)
		sup.lure(p, "sound")
		_lure_phase = 0
		_lure_t = LURE_EVERY

func floor_lights() -> Array: return kit.lights
func surface_at(_p: Vector3) -> String: return "concrete"

func _process(d: float) -> void:
	super._process(d)
	if finished or busy:
		return
	hud.set_status("Fuses %d/3   ·   Torch %d%%   ·   Batteries %d" % [fuses.size(), int(player.battery), GameState.count("battery")])
	_lure_t -= d
	if _lure_t <= 0.0:
		fire_lures()
