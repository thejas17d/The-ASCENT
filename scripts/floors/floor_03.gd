extends FloorBase
## FLOOR 3 — RECORDS. Collect six torn pages of the 1998 inspection report
## before the thing in the aisles finishes reading it. It reads only while
## unobserved: look at it and it vanishes and relocates. Power drains; restore
## it at fuse boxes. In a blackout it stops reading and HUNTS (lockers, desks,
## hold your breath). Caught or too slow → sent down to Floor 2.

const Supervisor := preload("res://scripts/ai/supervisor.gd")
const POWER_DRAIN := 1.0          # % per second
const FUSE_BOOST := 45.0
const FUSE_COOLDOWN := 15.0
const READ_RATE := 0.72           # % per second while unobserved (~140 s)
const PAGES := 6

var kit: Kit
var nav: NavigationRegion3D
var sup: CharacterBody3D
var power := 100.0
var reading := 0.0
var pages := 0
var blackout := false
var fuses: Array = []            # [{node, cool}]
var watch_spots: Array = []      # [pos, yaw]
var _base_energy: Array = []
var _watch_i := 0
var _relocate_t := -1.0
var _turn_t := 4.0
var _cued := 0

func _ready() -> void:
	load_floor_data(3)
	nav = NavigationRegion3D.new(); add_child(nav)
	kit = Kit.new(nav)
	_build()
	_bake()
	setup_common()
	spawn = Vector3(0, 0.05, 14.5)
	_setup_sup()
	for l in kit.lights:
		_base_energy.append(l.light_energy)
	begin_floor()
	if GameState.solved_floor(3):
		pages = PAGES
		unlock_exit("")

func _build() -> void:
	kit.room(Vector3.ZERO, 24.0, 32.0, 3.2, kit.m.paint, kit.m.concrete, kit.m.ceiling,
		[{"side": "n", "at": 0.0, "width": 1.1, "height": 2.2}])
	for z in [-11.0, -7.0, -3.0, 1.0, 5.0, 9.0]:
		for side in [-1, 1]:
			_shelf(Vector3(side * 6.0, 0, z), 8.0)
	for x in [-7.5, -2.5, 2.5, 7.5]:
		kit.desk(Vector3(x, 0, -14.6), 0.0)
	for z in [-9.0, -1.0, 7.0]:
		kit.locker(Vector3(-11.55, 0, z), -PI / 2)
		kit.locker(Vector3(11.55, 0, z), PI / 2)
	# fuse boxes
	for f in [[Vector3(-11.9, 1.4, 3.0), PI / 2], [Vector3(11.9, 1.4, -5.0), -PI / 2], [Vector3(-8.0, 1.4, -15.9), 0.0]]:
		var b: Node3D = kit.box(Vector3(0.5, 0.7, 0.18), f[0], kit.m.metal_grey)
		b.rotation.y = f[1]
		b.set_meta("use", "fuse"); b.set_meta("prompt", "Fuse box — restore power")
		var led: Node3D = kit.box(Vector3(0.06, 0.06, 0.02), Vector3(0.15, 0.25, 0.1), Mat_led(Color(0.1, 1, 0.2)), false, b)
		fuses.append({"node": b, "cool": 0.0, "led": led})
	# torn pages on shelves and desks
	var page_spots := [Vector3(-8.0, 0.69, -2.7), Vector3(4.0, 1.24, 1.3), Vector3(-3.5, 0.14, 5.3),
		Vector3(9.0, 1.24, -6.7), Vector3(-6.0, 1.79, -10.7), Vector3(2.5, 0.8, -14.5)]
	for i in PAGES:
		kit.item("r_page_%d" % i, "torn page", page_spots[i], "page", Color(0.85, 0.8, 0.68))
	kit.board(Vector3(-3.0, 1.6, 15.88), PI, rules.rules)
	kit.note("r_archivist", Vector3(1.2, 0.006, 13.5))
	kit.item("voice_1", "cassette (voice note)", Vector3(7.3, 0.79, -14.5), "tape", Color(0.75, 0.2, 0.15))
	kit.stair_exit(Vector3(0, 0, -16.03), 0.0, "STAIRS ▲  4")
	exit_hint = "Locked. The report isn't whole yet."
	for p in [Vector3(0, 3.2, 12), Vector3(-6, 3.2, 3), Vector3(6, 3.2, -5), Vector3(0, 3.2, -13), Vector3(-6, 3.2, -9), Vector3(6, 3.2, 7)]:
		kit.lamp(p, "tube", Color(1.0, 0.9, 0.75), 1.1, 7.5)
	# aisle ends where it stands to read
	for z in [-9.0, -5.0, -1.0, 3.0, 7.0]:
		watch_spots.append([Vector3(-10.8, 0.05, z), -PI / 2])
		watch_spots.append([Vector3(10.8, 0.05, z), PI / 2])

func _shelf(base: Vector3, length: float) -> void:
	kit.box(Vector3(length, 2.4, 0.08), base + Vector3(0, 1.2, 0), kit.m.ply)
	for y in [0.1, 0.65, 1.2, 1.75, 2.35]:
		kit.box(Vector3(length, 0.04, 0.6), base + Vector3(0, y, 0), kit.m.ply)
	for x in [-length / 2, 0.0, length / 2]:
		kit.box(Vector3(0.05, 2.4, 0.6), base + Vector3(x, 1.2, 0), kit.m.metal)
	var rng := RandomNumberGenerator.new(); rng.seed = int(base.z * 100 + base.x)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = true; mm.mesh = BoxMesh.new()
	var xf: Array = []; var cols: Array = []
	for y in [0.12, 0.67, 1.22, 1.77]:
		var x := -length / 2 + 0.3
		while x < length / 2 - 0.3:
			var w := rng.randf_range(0.25, 0.45)
			if rng.randf() < 0.78:
				var size := Vector3(w - 0.03, rng.randf_range(0.28, 0.42), 0.5)
				xf.append(Transform3D(Basis.from_scale(size), base + Vector3(x + w / 2, y + 0.02 + size.y / 2, 0)))
				cols.append(Color(0.75, 0.68, 0.5).lerp(Color(0.42, 0.37, 0.3), rng.randf()))
			x += w
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i]); mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm
	var fm := StandardMaterial3D.new(); fm.vertex_color_use_as_albedo = true; fm.roughness = 0.95
	mmi.material_override = fm
	nav.add_child(mmi)

func Mat_led(c: Color) -> Material:
	return preload("res://scripts/systems/mat_lib.gd").emissive(c, 4.0)

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
	sup.waypoints = [Vector3(0, 0, -13), Vector3(-10.5, 0, -13), Vector3(-10.5, 0, 11), Vector3(-1, 0, 3),
		Vector3(1, 0, -5), Vector3(10.5, 0, -13), Vector3(10.5, 0, 11), Vector3(0, 0, 11)]
	sup.caught_player.connect(func(): fall_down("It found you in the dark."))
	sup.learned.connect(func(kind): subtitle("(it has started checking the %ss first)" % kind, 4))
	_place_watcher(4)

func _place_watcher(i: int) -> void:
	_watch_i = i
	sup.deactivate()
	sup.global_position = watch_spots[i][0]
	sup.rotation.y = watch_spots[i][1]
	sup.visible = true

## Is the player looking straight at it (with line of sight)?
func observed() -> bool:
	if not sup.visible:
		return false
	var head: Vector3 = sup.global_position + Vector3(0, 1.6, 0)
	var to := head - player.cam.global_position
	if to.length() > 26.0:
		return false
	var fwd := -player.cam.global_transform.basis.z
	if fwd.dot(to.normalized()) < 0.9:
		return false
	var q := PhysicsRayQueryParameters3D.create(player.cam.global_position, head, 1)
	q.exclude = [player.get_rid(), sup.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

# ---------------------------------------------------------------- interaction
func on_use(id: String, node: Node3D) -> void:
	if id == "fuse":
		use_fuse(node)

func use_fuse(node: Node3D) -> bool:
	for f in fuses:
		if f.node == node:
			if f.cool > 0.0:
				hud.message("The breaker is still hot. (%ds)" % ceili(f.cool), 2)
				return false
			f.cool = FUSE_COOLDOWN
			power = min(100.0, power + FUSE_BOOST)
			subtitle("(CLUNK — the lights surge)", 2)
			if blackout:
				end_blackout()
			return true
	return false

func on_item_taken(id: String, node: Node3D) -> bool:
	if not id.begins_with("r_page_"):
		return false
	node.queue_free()
	pages += 1
	if not GameState.collectibles.has(id):
		GameState.collectibles.append(id)
	if pages < PAGES:
		hud.message("A torn page of a typed report. (%d / %d)" % [pages, PAGES], 3)
	else:
		hud.show_panel("MERIDIAN TOWER — STRUCTURAL INSPECTION, 11 JUNE 1998\n\nFindings: hairline cracking in columns C4–C9, floors 4 to 7.\nRecommendation: HALT ALL SLAB POURS ABOVE FLOOR 4 UNTIL THE COLUMNS ARE TESTED.\n\n(The recommendation has been struck through in red ink. Beneath it:)\n\nNO DEFECTS FOUND.  FIT FOR CONTINUED CONSTRUCTION.\n\nSigned:  P. DESAI, Site Engineer\nCountersigned:  (illegible), Site Supervisor\n\n[E] close")
		if not GameState.collectibles.has("r_report"):
			GameState.collectibles.append("r_report")
		unlock_exit("")
		GameState.save_game()
	return true

func start_blackout() -> void:
	blackout = true
	power = 0.0
	for l in kit.lights:
		l.light_energy = 0.0
	subtitle("(the lights die. The page-turning stops.)", 3)
	hud.glitch(0.6)
	var at: Vector3 = sup.safe_spawn_point(watch_spots.map(func(w): return w[0]), player.global_position, get_world_3d().direct_space_state)
	sup.visible = true
	sup.activate(at if at != Vector3.INF else watch_spots[0][0])

func end_blackout() -> void:
	blackout = false
	subtitle("(somewhere in the aisles, heavy footsteps retreat)", 3)
	_place_watcher(randi() % watch_spots.size())

func floor_lights() -> Array: return kit.lights
func surface_at(_p: Vector3) -> String: return "concrete"

func _process(d: float) -> void:
	super._process(d)
	if finished or busy:
		return
	for f in fuses:
		f.cool = max(0.0, f.cool - d)
		f.led.visible = f.cool <= 0.0
	hud.set_status("Power %d%%   ·   Pages %d/%d   ·   Torch %d%%" % [int(power), pages, PAGES, int(player.battery)])
	# power
	if not blackout:
		var drain := POWER_DRAIN * (1.3 if GameState.altered_level(3) > 0 else 1.0)
		power = max(0.0, power - drain * d)
		var k := clampf(power / 30.0, 0.0, 1.0)
		for i in kit.lights.size():
			var e: float = _base_energy[i] * (0.35 + 0.65 * k)
			if power < 30.0 and randf() < 0.04 and not GameState.settings.get("reduced_flashing", false):
				e = 0.0
			kit.lights[i].light_energy = e
		if power <= 0.0:
			start_blackout()
			return
	if blackout or pages >= PAGES:
		return
	# the reader
	if _relocate_t > 0.0:
		_relocate_t -= d
		if _relocate_t <= 0.0:
			_relocate()
		return
	if observed():
		sup.visible = false
		_relocate_t = 4.0
		subtitle("(it is gone)", 1.5)
		return
	reading += READ_RATE * d
	_turn_t -= d
	if _turn_t <= 0.0:
		play_at("whisper", sup.global_position + Vector3(0, 1.5, 0))
		_turn_t = lerp(5.0, 1.2, reading / 100.0)
	if reading >= 50.0 and _cued == 0:
		_cued = 1; subtitle("(pages turning — faster now)", 3)
	elif reading >= 80.0 and _cued == 1:
		_cued = 2; subtitle("(it is near the last page)", 3); Dread.add(10)
	if reading >= 100.0:
		fall_down("It finished reading. It knows what the report says — and now it knows you.")

## Move to an aisle end the player can't currently see.
func _relocate() -> void:
	var order := range(watch_spots.size())
	order.shuffle()
	for i in order:
		_place_watcher(i)
		if not observed():
			return
