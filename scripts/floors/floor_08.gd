extends FloorBase
## FLOOR 8 — THE ROOF. No rules: "YOU MAKE THE RULES NOW." A red night over a
## painted city. Papa waits at the end of the crane boom. Step onto the roof
## and the Supervisor comes up the stairs behind you; sections of roof give way.
## Climb the water tank (it cannot climb), cross the catwalk, and choose:
##   ESCAPE — run for the door (always available)
##   TRUTH  — read their names (needs the letter KEPT and all six workers FREED)
## Lethal; the tank top is a checkpoint.

const Supervisor := preload("res://scripts/ai/supervisor.gd")
const TANK := Vector3(-8, 0, -6)
const TANK_TOP := 7.2
const FATHER := Vector3(8.2, TANK_TOP, -6)

var kit: Kit
var nav: NavigationRegion3D
var sup: CharacterBody3D
var father: Node3D
var chase_started := false
var on_tank := false
var confronted := false
var _crumble: Array = []          # [trigger z, chunk node, fallen]

func _ready() -> void:
	load_floor_data(8)
	nav = NavigationRegion3D.new(); add_child(nav)
	kit = Kit.new(nav)
	_build()
	_bake()
	setup_common()
	director.enabled = false
	_sky()
	spawn = Vector3(0, 0.05, 11.0)
	_setup_sup()
	begin_floor()
	exit_unlocked = false
	if GameState.checkpoint.get("tank", false):
		_arrive_on_tank()

func _build() -> void:
	# roof slab 28 x 28, parapet + invisible safety barrier
	kit.box(Vector3(28.4, 0.3, 28.4), Vector3(0, -0.15, -2), kit.m.concrete)
	for e in [[Vector3(0, 0, 12.1), Vector3(28.4, 0, 0.3)], [Vector3(0, 0, -16.1), Vector3(28.4, 0, 0.3)],
			[Vector3(-14.1, 0, -2), Vector3(0.3, 0, 28.4)], [Vector3(14.1, 0, -2), Vector3(0.3, 0, 28.4)]]:
		var p: Vector3 = e[0]; var sz: Vector3 = e[1]
		kit.box(Vector3(max(sz.x, 0.3), 1.1, max(sz.z, 0.3)), p + Vector3(0, 0.55, 0), kit.m.concrete)
		var inv: Node3D = kit.box(Vector3(max(sz.x, 0.3), 4.0, max(sz.z, 0.3)), p + Vector3(0, 2.0, 0), Color(0, 0, 0))
		inv.get_child(1).visible = false
	# stair head-house you arrive from (x -2..2, z 9..12)
	kit.box(Vector3(4.2, 3.0, 0.2), Vector3(0, 1.5, 12.0), kit.m.paint)
	kit.box(Vector3(0.2, 3.0, 3.2), Vector3(-2.1, 1.5, 10.5), kit.m.paint)
	kit.box(Vector3(0.2, 3.0, 3.2), Vector3(2.1, 1.5, 10.5), kit.m.paint)
	kit.box(Vector3(4.4, 0.2, 3.4), Vector3(0, 3.1, 10.5), kit.m.concrete)
	kit.box(Vector3(1.4, 0.8, 0.2), Vector3(-1.5, 2.6, 9.0), kit.m.paint)
	kit.box(Vector3(1.4, 0.8, 0.2), Vector3(1.5, 2.6, 9.0), kit.m.paint)
	kit.box(Vector3(0.8, 3.0, 0.2), Vector3(-1.7, 1.5, 9.0), kit.m.paint)
	kit.box(Vector3(0.8, 3.0, 0.2), Vector3(1.7, 1.5, 9.0), kit.m.paint)
	var blank := kit.board(Vector3(-2.0 + 0.11, 1.5, 10.6), PI / 2, [])
	blank.set_meta("prompt", "Read notice board")
	kit.label("YOU MAKE THE RULES NOW.", Vector3(-1.86, 1.25, 10.6), PI / 2, Color(0.5, 0.05, 0.03), 26)
	# water tank on legs with a ladder (the only way up)
	for dx in [-1.2, 1.2]:
		for dz in [-1.2, 1.2]:
			kit.box(Vector3(0.2, TANK_TOP, 0.2), TANK + Vector3(dx, TANK_TOP / 2, dz), kit.m.metal_grey)
	kit.cyl(1.6, 2.6, TANK + Vector3(0, TANK_TOP - 1.45, 0), kit.m.metal)   # the tank; you stand on its lid
	kit.box(Vector3(3.6, 0.12, 3.6), TANK + Vector3(0, TANK_TOP - 0.06, 0), kit.m.metal_grey)
	# railings on the tank top (open toward the catwalk, +X)
	for r in [[Vector3(-1.8, 0, 0), Vector3(0.05, 1.0, 3.6)], [Vector3(0, 0, -1.8), Vector3(3.6, 1.0, 0.05)], [Vector3(0, 0, 1.8), Vector3(3.6, 1.0, 0.05)]]:
		kit.box(r[1], TANK + Vector3(0, TANK_TOP + 0.5, 0) + r[0], kit.m.metal_grey)
	var ladder: Node3D = kit.box(Vector3(0.6, TANK_TOP, 0.12), TANK + Vector3(0, TANK_TOP / 2, 1.9), kit.m.metal_grey)
	ladder.set_meta("use", "ladder"); ladder.set_meta("prompt", "Climb the ladder")
	for k in 18:
		kit.box(Vector3(0.6, 0.03, 0.05), TANK + Vector3(0, 0.3 + k * 0.38, 1.97), kit.m.metal_grey, false)
	# catwalk from the tank to the crane platform, with railings
	kit.box(Vector3(14.2, 0.1, 1.0), Vector3(0.1, TANK_TOP - 0.05, -6), kit.m.metal_grey)
	for z in [-6.5, -5.5]:
		kit.box(Vector3(14.2, 0.05, 0.05), Vector3(0.1, TANK_TOP + 1.0, z), kit.m.metal_grey)
		kit.box(Vector3(14.2, 1.1, 0.04), Vector3(0.1, TANK_TOP + 0.5, z), Color(0, 0, 0)).get_child(1).visible = false
	# crane: tower under the platform, boom out over the city
	kit.box(Vector3(3.0, 0.15, 3.0), Vector3(8.2, TANK_TOP - 0.07, -6), kit.m.metal_grey)
	for dx in [-0.9, 0.9]:
		for dz in [-0.9, 0.9]:
			kit.box(Vector3(0.15, TANK_TOP, 0.15), Vector3(8.2 + dx, TANK_TOP / 2, -6 + dz), Color(0.75, 0.6, 0.1))
	kit.box(Vector3(0.5, 0.5, 26.0), Vector3(8.2, TANK_TOP + 4.5, -15.0), Color(0.75, 0.6, 0.1), false)
	kit.box(Vector3(0.3, 4.5, 0.3), Vector3(8.2, TANK_TOP + 2.25, -6), Color(0.75, 0.6, 0.1), false)
	for side in [-1.4, 1.4]:   # platform railings (keep the finale safe)
		var r: Node3D = kit.box(Vector3(0.05, 1.1, 3.0), Vector3(8.2 + side, TANK_TOP + 0.55, -6), Color(0, 0, 0))
		r.get_child(1).visible = false
	kit.box(Vector3(3.0, 1.1, 0.05), Vector3(8.2, TANK_TOP + 0.55, -7.45), Color(0, 0, 0)).get_child(1).visible = false
	# roof clutter: AC units, pipes, a satellite dish, chalk note
	for p in [Vector3(6, 0, 6), Vector3(-9, 0, 4), Vector3(10, 0, -13), Vector3(-3, 0, -12)]:
		kit.box(Vector3(1.6, 1.1, 1.0), p + Vector3(0, 0.55, 0), kit.m.metal_grey)
	kit.note("f_paint", Vector3(-14.0, 1.105, 2.0), 0.0)   # lying on the parapet
	# crumbling sections along the chase route
	for z in [5.0, 0.0, -3.0]:
		var chunk: Node3D = kit.box(Vector3(4.0, 0.25, 3.0), Vector3(-4.0, 0.13, z), kit.m.concrete, false)
		chunk.set_meta("dynamic", true)
		_crumble.append([z, chunk, false])
	kit.lamp(Vector3(0, 2.9, 10.5), "bulb", Color(1, 0.8, 0.5), 0.9, 5.0)
	kit.lamp(Vector3(-8, 2.0, -3.6), "work", Color(1.0, 0.3, 0.2), 1.0, 9.0)
	_build_father()

func _build_father() -> void:
	father = Node3D.new(); add_child(father)
	father.position = FATHER
	father.rotation.y = 0.0      # looking out along the boom, away from you
	var shirt := StandardMaterial3D.new(); shirt.albedo_color = Color(0.55, 0.52, 0.45)
	var dark := StandardMaterial3D.new(); dark.albedo_color = Color(0.08, 0.07, 0.07)
	var body := CapsuleMesh.new(); body.radius = 0.24; body.height = 1.15
	kit.mesh(body, Vector3(0, 1.3, 0), shirt, father)
	var legs := CapsuleMesh.new(); legs.radius = 0.16; legs.height = 0.95
	kit.mesh(legs, Vector3(0, 0.48, 0), dark, father)
	var head := SphereMesh.new(); head.radius = 0.12; head.height = 0.26
	kit.mesh(head, Vector3(0, 2.0, 0), Color(0.4, 0.3, 0.24), father)
	var hel := SphereMesh.new(); hel.radius = 0.16; hel.height = 0.16; hel.is_hemisphere = true
	kit.mesh(hel, Vector3(0.28, 1.1, 0.05), Color(0.6, 0.48, 0.1), father).rotation.z = PI / 2   # helmet held at his side
	var l := OmniLight3D.new(); l.position = Vector3(0, 2.6, 0); l.light_color = Color(1, 0.75, 0.55)
	l.light_energy = 0.8; l.omni_range = 4.0
	father.add_child(l)

func _sky() -> void:
	var env: Environment = Graphics.env
	env.background_color = Color(0.09, 0.012, 0.01)
	env.ambient_light_color = Color(0.5, 0.15, 0.12); env.ambient_light_energy = 0.35
	env.fog_light_color = Color(0.12, 0.02, 0.02)
	env.volumetric_fog_albedo = Color(0.9, 0.5, 0.45)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(1.0, 0.45, 0.38); moon.light_energy = 0.35
	moon.rotation = Vector3(-0.5, 0.8, 0); moon.shadow_enabled = Graphics.quality >= 2
	add_child(moon)
	var disk := SphereMesh.new(); disk.radius = 6.0; disk.height = 12.0
	kit.mesh(disk, Vector3(-60, 45, -120), preload("res://scripts/systems/mat_lib.gd").emissive(Color(0.9, 0.25, 0.18), 2.0), self)
	# the "city": a painted skyline on four sides — silhouettes with lit windows.
	# It is a backdrop, not a place (the chalk on the parapet says so).
	var sil := StandardMaterial3D.new(); sil.albedo_color = Color(0.025, 0.015, 0.02); sil.roughness = 1.0
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = true
	var q := QuadMesh.new(); q.size = Vector2(0.55, 0.75); mm.mesh = q
	var rng := RandomNumberGenerator.new(); rng.seed = 333
	var xf: Array = []; var cols: Array = []
	for side in 4:
		var yaw := side * PI / 2
		var basis := Basis(Vector3.UP, yaw)
		var x := -95.0
		while x < 95.0:
			var bw := rng.randf_range(6.0, 16.0)
			var bh := rng.randf_range(8.0, 42.0)
			var dist := rng.randf_range(62.0, 80.0)
			var center := basis * Vector3(x + bw / 2, -10.0 + bh / 2, -dist)
			var b := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(bw, bh, 4.0)
			b.mesh = bm; b.material_override = sil; b.position = center; b.rotation.y = yaw
			add_child(b)
			# windows on the face toward the roof, in a loose grid
			var wy := -9.0
			while wy < -10.0 + bh - 1.5:
				var wx := x + 0.8
				while wx < x + bw - 0.8:
					if rng.randf() < 0.22:
						xf.append(Transform3D(basis, basis * Vector3(wx, wy, -dist + 2.05)))
						cols.append(Color(1.0, 0.72, 0.38) * rng.randf_range(0.25, 0.8))
					wx += 1.3
				wy += 1.9
			x += bw + rng.randf_range(0.5, 4.0)
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i]); mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm
	var wm := StandardMaterial3D.new(); wm.vertex_color_use_as_albedo = true
	wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mmi.material_override = wm
	add_child(mmi)

func _bake() -> void:
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.agent_radius = 0.5; nm.agent_height = 2.0; nm.agent_max_climb = 0.25
	nav.navigation_mesh = nm
	nav.bake_navigation_mesh(false)

func _setup_sup() -> void:
	sup = Supervisor.new()
	add_child(sup)
	sup.player = player
	sup.hide_spots = []
	sup.waypoints = [Vector3(0, 0, 8), Vector3(-8, 0, -2), Vector3(8, 0, 2)]
	sup.caught_player.connect(func(): die("It reached you on the roof."))
	sup.global_position = Vector3(0, 0.05, 11.0)
	sup.deactivate()
	sup.visible = false

# ---------------------------------------------------------------- sequence
func start_chase() -> void:
	if chase_started:
		return
	chase_started = true
	subtitle("(behind you, heavy boots on the stairs)", 3)
	hud.message("Papa, from the crane: \"Beta — the tank! Climb!\"", 4)
	sup.visible = true
	sup.activate(Vector3(0, 0.05, 10.5))
	sup.awareness = 1.2
	sup.last_known = player.global_position
	sup._set_state(Supervisor.S.CHASE)
	Dread.add(15)

func on_use(id: String, _node: Node3D) -> void:
	if id == "ladder":
		climb()

func climb() -> void:
	if on_tank and player.global_position.y > TANK_TOP - 1.0:
		return
	player.input_enabled = false
	await hud.fade_to(1.0, 0.4)
	_arrive_on_tank()
	GameState.checkpoint = {"tank": true}
	GameState.save_game()
	subtitle("(checkpoint)", 1.5)
	await hud.fade_to(0.0, 0.6)
	player.input_enabled = true

func _arrive_on_tank() -> void:
	on_tank = true
	chase_started = true
	spawn = TANK + Vector3(0.6, TANK_TOP + 0.05, 0)
	player.teleport(spawn)
	player.rotation.y = -PI / 2      # facing along the catwalk toward Papa
	sup.visible = true
	sup.activate(TANK + Vector3(0, 0.05, 3.0))
	sup.deactivate()
	sup.look_at(Vector3(TANK.x, 0.05, TANK.z), Vector3.UP)
	subtitle("(below, it stops at the foot of the ladder and looks up. It cannot climb.)", 4)

func confront() -> void:
	if confronted:
		return
	confronted = true
	player.input_enabled = false
	var lines := [
		"Papa doesn't turn around. \"You came all the way up.\"",
		"\"I used to stand here every night of the pour. I could see our window from here.\"",
		"\"Six men, Arjun. I knew their names. I signed anyway.\"",
		"\"This building is made of what I wouldn't say. It will keep you here too, if you let it.\"",
	]
	for ln in lines:
		hud.message(ln, 4.0)
		await get_tree().create_timer(4.2, false).timeout
	var can_truth: bool = GameState.choices.get("letter", "") == "kept" and GameState.choices.get("workers", "") == "freed"
	var truth := {"text": "Read their names out loud.  (TRUTH)", "disabled": not can_truth}
	if not can_truth:
		truth.text += "\n— you'd need his letter, and all six of them free"
	var pick: int = await hud.ask_choice("The door behind you is open. The names are in your pocket.", ["Run for the door.  (ESCAPE)", truth])
	end_game("escape" if pick == 0 or not can_truth else "truth")

func end_game(ending: String) -> void:
	busy = true
	finished = true
	GameState.choices["ending"] = ending
	GameState.unlocks["new_game_plus"] = true
	GameState.unlocks["ending_" + ending] = true
	if GameState.falls == 0:
		GameState.unlocks["floor9"] = true
	GameState.solved[8] = true
	GameState.save_game()
	await hud.fade_to(1.0, 2.0)
	GameState.go(GameState.ENDING)

func show_rules(_extra := "") -> void:
	hud.show_panel("RULES OF THE BUILDING

(The board is blank except for one line, written in something red.)

YOU MAKE THE RULES NOW.

[E] close")

func floor_lights() -> Array: return kit.lights
func surface_at(_p: Vector3) -> String: return "concrete"

func _process(d: float) -> void:
	super._process(d)
	if finished or busy:
		return
	var p := player.global_position
	if not chase_started and p.z < 6.5:
		start_chase()
	for c in _crumble:
		if not c[2] and chase_started and p.z < c[0] - 2.5:
			c[2] = true
			var chunk: Node3D = c[1]
			var tw := chunk.create_tween()
			tw.tween_property(chunk, "position:y", -6.0, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			play_at("slam", chunk.global_position)
			subtitle("(the roof gives way behind you)", 1.5)
	if on_tank and Vector2(p.x - FATHER.x, p.z - FATHER.z).length() < 2.6:
		confront()
