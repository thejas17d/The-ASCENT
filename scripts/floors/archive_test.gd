extends FloorBase
## DEV TEST — THE SUPERVISOR in a records-archive greybox (Floor 3 layout
## prototype). Tall shelving aisles, steel lockers and desks to hide in/under.
## F3 toggles the AI debug readout; 1/2/3 toggle sight/sound/light senses.

const Supervisor := preload("res://scripts/ai/supervisor.gd")
const Mat := preload("res://scripts/systems/mat_lib.gd")

const W := 24.0      # x extent
const D := 32.0      # z extent
const H := 3.2
const START := Vector3(0, 0.05, 14.0)

var nav: NavigationRegion3D
var sup: CharacterBody3D
var spots: Array = []          # hide spot markers
var lamps: Array = []
var spawn_points: Array = []
var _debug: Label
var _debug_on := true
var _m_floor: Material
var _m_wall: Material
var _m_shelf: Material
var _m_metal: Material
var _m_wood: Material

func _ready() -> void:
	_m_floor = Mat.pbr("concrete_floor_worn_001", 2.5, Color(0.85, 0.85, 0.82))
	_m_wall = Mat.pbr("peeling_painted_wall", 3.0, Color(0.62, 0.72, 0.7))
	_m_shelf = Mat.pbr("plywood", 1.2, Color(0.8, 0.7, 0.55))
	_m_metal = Mat.pbr("rusty_painted_metal", 1.0, Color(0.6, 0.68, 0.66), 1.0, 0.25)
	_m_wood = Mat.pbr("sapele_veneer", 1.0, Color(0.55, 0.38, 0.28), 0.7)
	nav = NavigationRegion3D.new()
	add_child(nav)
	_build_level()
	_bake_nav()
	setup_common()
	_setup_supervisor()
	_debug = Label.new()
	_debug.position = Vector2(24, 24)
	_debug.add_theme_font_size_override("font_size", 16)
	_debug.add_theme_color_override("font_shadow_color", Color.BLACK)
	hud.add_child(_debug)
	player.teleport(START)
	hud.fade_to(0.0, 1.2)
	hud.message("DEV TEST — THE SUPERVISOR\nStay out of its lamp. Walk, crouch [Ctrl], hide in lockers or under desks.\nF3 debug · 1/2/3 toggle sight/sound/light", 9)

# ---------------------------------------------------------------- level
func _build_level() -> void:
	var hw := W / 2; var hd := D / 2
	_box(Vector3(W, 0.2, D), Vector3(0, -0.1, 0), _m_floor)
	_box(Vector3(W, 0.2, D), Vector3(0, H + 0.1, 0), Mat.pbr("ceiling_interior", 2.4, Color(0.7, 0.7, 0.68)))
	_box(Vector3(0.3, H, D), Vector3(-hw, H / 2, 0), _m_wall)
	_box(Vector3(0.3, H, D), Vector3(hw, H / 2, 0), _m_wall)
	_box(Vector3(W, H, 0.3), Vector3(0, H / 2, -hd), _m_wall)
	_box(Vector3(W, H, 0.3), Vector3(0, H / 2, hd), _m_wall)
	# shelving rows: two banks with a central aisle, cross aisles between rows
	for z in [-11.0, -7.0, -3.0, 1.0, 5.0, 9.0]:
		for side in [-1, 1]:
			var cx: float = side * 6.0
			_shelf(Vector3(cx, 0, z), 8.0)
	# desks along the back wall (hide under), lockers on the side walls (hide in)
	for x in [-7.5, -2.5, 2.5, 7.5]:
		_desk(Vector3(x, 0, -14.6))
	for z in [-9.0, -1.0, 7.0]:
		_locker(Vector3(-hw + 0.45, 0, z), -PI / 2)   # left wall, front faces +X
		_locker(Vector3(hw - 0.45, 0, z), PI / 2)     # right wall, front faces -X
	# sparse, dim lighting: pools of light and long dark aisles
	for p in [Vector3(0, H - 0.1, 12), Vector3(-6, H - 0.1, 3), Vector3(6, H - 0.1, -5), Vector3(0, H - 0.1, -13)]:
		_lamp(p)
	spawn_points = [Vector3(-10, 0.05, -13), Vector3(10, 0.05, -13), Vector3(0, 0.05, -13),
		Vector3(-10, 0.05, 3), Vector3(10, 0.05, 3)]

func _box(size: Vector3, pos: Vector3, mat: Material, parent: Node = null) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = size
	cs.shape = sh; body.add_child(cs)
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size
	mi.mesh = bm; mi.material_override = mat; body.add_child(mi)
	(parent if parent else nav).add_child(body)
	return body

func _shelf(base: Vector3, length: float) -> void:
	_box(Vector3(length, 2.4, 0.08), base + Vector3(0, 1.2, 0), _m_shelf)       # back panel (collision)
	for y in [0.1, 0.65, 1.2, 1.75, 2.35]:
		_box(Vector3(length, 0.04, 0.6), base + Vector3(0, y, 0), _m_shelf)
	for x in [-length / 2, 0.0, length / 2]:
		_box(Vector3(0.05, 2.4, 0.6), base + Vector3(x, 1.2, 0), _m_metal)
	# file boxes so shelves read as an archive — one MultiMesh (single draw call) per shelf
	var rng := RandomNumberGenerator.new(); rng.seed = int(base.z * 100 + base.x)
	var xf: Array = []
	var cols: Array = []
	for y in [0.12, 0.67, 1.22, 1.77]:
		var x := -length / 2 + 0.3
		while x < length / 2 - 0.3:
			var w := rng.randf_range(0.25, 0.45)
			if rng.randf() < 0.8:
				var size := Vector3(w - 0.03, rng.randf_range(0.28, 0.42), 0.5)
				xf.append(Transform3D(Basis.from_scale(size), base + Vector3(x + w / 2, y + 0.02 + size.y / 2, 0)))
				cols.append(Color(0.75, 0.68, 0.5).lerp(Color(0.42, 0.37, 0.3), rng.randf()))
			x += w
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = BoxMesh.new()
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var fm := StandardMaterial3D.new()
	fm.vertex_color_use_as_albedo = true; fm.roughness = 0.95
	mmi.material_override = fm
	nav.add_child(mmi)

func _desk(base: Vector3) -> void:
	_box(Vector3(1.6, 0.06, 0.8), base + Vector3(0, 0.76, 0), _m_wood)
	for x in [-0.75, 0.75]:
		_box(Vector3(0.06, 0.73, 0.75), base + Vector3(x, 0.365, 0), _m_wood)
	var area := _box(Vector3(1.4, 0.7, 0.7), base + Vector3(0, 0.35, 0), Mat.solid(Color(0, 0, 0, 0)))
	area.get_child(1).visible = false
	area.set_meta("hide", true)
	area.set_meta("prompt", "Hide under desk")
	area.set_meta("hide_msg", "You crawl under the desk. Hold [Space] to hold your breath.")
	var spot := _spot(base + Vector3(0, 0.0, 0), 0.0, "desk", 0.55)   # looks toward +room (-Z is wall side)
	spot.rotation.y = PI     # face out into the room (+Z)
	area.set_meta("hide_spot", spot)

func _locker(base: Vector3, yaw: float) -> void:
	var body := _box(Vector3(0.9, 2.0, 0.6), base + Vector3(0, 1.0, 0), _m_metal)
	body.rotation.y = yaw
	body.set_meta("hide", true)
	body.set_meta("prompt", "Hide in locker")
	body.set_meta("hide_msg", "You pull the locker door shut. Hold [Space] to hold your breath.")
	for k in 4:   # vents
		var v := MeshInstance3D.new(); var vm := BoxMesh.new(); vm.size = Vector3(0.4, 0.02, 0.01)
		v.mesh = vm; v.material_override = Mat.solid(Color(0.02, 0.02, 0.02))
		v.position = Vector3(0, 0.55 + k * 0.05, -0.305)
		body.add_child(v)
	# locker front faces the body's -Z; the hidden player looks out that way
	var spot := _spot(base, yaw, "locker", 1.55)
	body.set_meta("hide_spot", spot)

func _spot(pos: Vector3, yaw: float, kind: String, eye: float) -> Node3D:
	var m := Node3D.new()
	m.position = pos; m.rotation.y = yaw
	m.set_meta("hide_kind", kind)
	m.set_meta("eye", eye)
	add_child(m)
	spots.append(m)
	return m

func _lamp(p: Vector3) -> void:
	var fixture := MeshInstance3D.new(); var cm := CylinderMesh.new()
	cm.top_radius = 0.18; cm.bottom_radius = 0.28; cm.height = 0.18
	fixture.mesh = cm; fixture.position = p; fixture.material_override = Mat.solid(Color(0.2, 0.22, 0.2), 0.5, 0.6)
	add_child(fixture)
	var bulb := MeshInstance3D.new(); var bm := SphereMesh.new(); bm.radius = 0.07; bm.height = 0.14
	bulb.mesh = bm; bulb.position = p + Vector3(0, -0.12, 0); bulb.material_override = Mat.emissive(Color(1, 0.8, 0.5), 5.0)
	add_child(bulb)
	var l := OmniLight3D.new()
	l.position = p + Vector3(0, -0.3, 0)
	l.light_color = Color(1, 0.8, 0.55); l.light_energy = 1.3; l.omni_range = 7.5; l.omni_attenuation = 1.4
	l.light_volumetric_fog_energy = 0.8
	l.shadow_enabled = Graphics.quality >= 2
	add_child(l)
	lamps.append(l)

func _bake_nav() -> void:
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.agent_radius = 0.45
	nm.agent_height = 2.0
	nm.agent_max_climb = 0.3
	nav.navigation_mesh = nm
	nav.bake_navigation_mesh(false)

# ---------------------------------------------------------------- supervisor
func _setup_supervisor() -> void:
	sup = Supervisor.new()
	add_child(sup)
	sup.player = player
	sup.hide_spots = spots
	sup.waypoints = [Vector3(0, 0, -13), Vector3(-10.5, 0, -13), Vector3(-10.5, 0, 11), Vector3(-3, 0, 3),
		Vector3(3, 0, -5), Vector3(10.5, 0, -13), Vector3(10.5, 0, 11), Vector3(0, 0, 11)]
	sup.caught_player.connect(_on_caught)
	sup.learned.connect(func(kind): subtitle("(it has started checking the %ss first)" % kind, 4))
	sup.state_changed.connect(_on_sup_state)
	sup.activate(Vector3(0, 0.05, -13))

func _on_sup_state(s: String) -> void:
	if s == "chase":
		_sfx.sting.play()
		hud.glitch(0.4)
		subtitle("(heavy footsteps — running)", 2)
	elif s == "suspicious":
		subtitle("(the footsteps stop)", 2)

func on_player_hid(spot: Node3D) -> void:
	var seen: bool = sup.state == Supervisor.S.CHASE and sup.last_perception.get("seen", false)
	sup.note_player_hid(str(spot.get_meta("hide_kind", "")), seen)

func _on_caught() -> void:
	if busy:
		return
	busy = true
	player.input_enabled = false
	Dread.add(25)
	_sfx.sting.play()
	hud.glitch(1.5)
	await hud.fade_to(1.0, 0.25)
	hud.message("IT FOUND YOU.\n(On Floors 1–4 the building sends you down a floor; from Floor 5 this is death.)", 5)
	GameState.falls += 1
	await get_tree().create_timer(2.0, false).timeout
	player.teleport(START)
	var at: Vector3 = sup.safe_spawn_point(spawn_points, player.global_position, get_world_3d().direct_space_state)
	sup.activate(at if at != Vector3.INF else Vector3(0, 0.05, -13))
	player.input_enabled = true
	await hud.fade_to(0.0, 0.8)
	busy = false

# ---------------------------------------------------------------- hooks
func world_root() -> Node3D: return self
func floor_lights() -> Array: return lamps
func surface_at(_p: Vector3) -> String: return "concrete"

func add_chalk(pos: Vector3, normal: Vector3) -> Label3D:
	var l := Label3D.new()
	l.text = "X"; l.font_size = 64; l.pixel_size = 0.004
	l.modulate = Color(0.95, 0.95, 0.92); l.shaded = true
	add_child(l)
	l.global_position = pos + normal * 0.02
	if abs(normal.y) < 0.9:
		l.look_at(l.global_position - normal, Vector3.UP)
		l.rotate_object_local(Vector3.UP, PI)
	else:
		l.rotation.x = -PI / 2
	return l

func add_diya(pos: Vector3) -> Node3D:
	var n := Node3D.new(); add_child(n)
	n.global_position = Vector3(pos.x, 0.0, pos.z)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.58, 0.22); l.light_energy = 1.8; l.omni_range = 3.2
	l.position.y = 0.2
	n.add_child(l)
	return n

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		match e.physical_keycode:
			KEY_F3: _debug_on = not _debug_on
			KEY_1: sup.senses.sight = not sup.senses.sight
			KEY_2: sup.senses.sound = not sup.senses.sound
			KEY_3: sup.senses.light = not sup.senses.light

func _process(d: float) -> void:
	super._process(d)
	_debug.visible = _debug_on
	if _debug_on and sup:
		var p: Dictionary = sup.last_perception
		_debug.text = "SUPERVISOR  %s\nawareness %.2f   dist %.1f m\nsenses: sight %s · sound %s · light %s\nperceives: %s%s%s\nyour noise %.2f   hide memory %s" % [
			sup.state_name().to_upper(), sup.awareness, sup.global_position.distance_to(player.global_position),
			"ON" if sup.senses.sight else "off", "ON" if sup.senses.sound else "off", "ON" if sup.senses.light else "off",
			"SEES " if p.get("seen", false) else "", "HEARS " if p.get("heard", false) else "", "LIGHT" if p.get("light", false) else "",
			player.noise, str(sup.hide_memory)]
