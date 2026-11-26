extends RefCounted
## Modular building kit shared by every floor. Builds into `root`.
## All interactables communicate through node metadata that FloorBase reads:
##   prompt     — "[E] …" text
##   board      — a rule notice board
##   note       — readable note id
##   pickup     — consumable item (battery/diya/chalk)
##   item       — puzzle item id (carried / kept)
##   hide + hide_spot — hiding place (spot: Node3D, -Z faces out, meta eye/hide_kind)
##   stair_exit — the stairwell door out of the floor
##   use        — floor-specific interactable id (handled by the floor)

const Mat := preload("res://scripts/systems/mat_lib.gd")
const Props := preload("res://scripts/world/props.gd")
const Skyline := preload("res://scripts/world/skyline.gd")
## Ceiling fixtures on Forward+: the omni becomes soft fill at FILL x the lamp's
## energy and a downlight (follow_light.gd) throws the pool of light.
const FILL := 0.7

var root: Node3D
var lights: Array = []
var spots: Array = []
var m := {}

func _init(r: Node3D) -> void:
	root = r
	m.wallpaper = Mat.pbr("decrepit_wallpaper", 1.6, Color(1.0, 0.96, 0.9))
	# institutional pale green and a warm cream; decay comes from decals on top
	m.paint = Mat.pbr("painted_plaster_wall", 2.4, Color(0.7, 0.82, 0.74))
	m.paint_warm = Mat.pbr("painted_plaster_wall", 2.4, Color(0.95, 0.88, 0.74))
	m.peeling = Mat.pbr("peeling_painted_wall", 1.8, Color(0.72, 0.8, 0.78))
	m.carpet = Mat.pbr("dirty_carpet", 1.8, Color(1.5, 0.95, 0.85))
	m.carpet_grey = Mat.pbr("dirty_carpet", 1.8, Color(0.75, 0.78, 0.8))
	m.mosaic = Mat.pbr("terrazzo_tiles", 1.5, Color(1.0, 0.97, 0.92), 0.55)   # polished terrazzo: catches the lights
	m.terrazzo = m.mosaic
	m.old_mosaic = Mat.pbr("old_mosaic_floor", 1.6, Color.WHITE, 0.85)
	m.home_tile = Mat.pbr("interior_tiles", 1.6, Color(1.0, 0.97, 0.93), 0.6)
	m.dado = Mat.pbr("long_white_tiles", 1.1, Color(0.9, 0.93, 0.88), 0.55)
	m.ceiling = Mat.pbr("white_plaster_02", 2.0, Color(0.86, 0.85, 0.81))
	m.concrete = Mat.pbr("concrete_floor_worn_001", 2.5, Color(0.85, 0.85, 0.82))
	m.wood = Mat.pbr("sapele_veneer", 1.1, Color(0.62, 0.42, 0.3), 0.75)
	m.trim = Mat.pbr("sapele_veneer", 0.6, Color(0.36, 0.24, 0.17), 0.8)
	m.metal = Mat.pbr("rusty_painted_metal", 1.0, Color(0.72, 0.8, 0.76), 1.0, 0.2)
	m.metal_grey = Mat.pbr("rusty_painted_metal", 1.0, Color(0.6, 0.62, 0.62), 1.0, 0.3)
	m.ply = Mat.pbr("plywood", 1.0)
	m.door_panel = Mat.pbr("sapele_veneer", 0.8, Color(0.46, 0.3, 0.21), 0.7)
	m.chrome = Mat.solid(Color(0.78, 0.78, 0.76), 0.22, 0.9)
	m.enamel = Mat.solid(Color(0.86, 0.85, 0.8), 0.32)
	m.cork = StandardMaterial3D.new()
	m.cork.albedo_texture = Mat.fx("cork"); m.cork.roughness = 0.95
	m.cork.uv1_triplanar = true; m.cork.uv1_scale = Vector3.ONE * 1.4
	m.glass = StandardMaterial3D.new()
	m.glass.albedo_color = Color(0.7, 0.8, 0.85, 0.1)
	m.glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.glass.roughness = 0.05; m.glass.metallic = 0.15
	m.brass = Mat.solid(Color(0.8, 0.62, 0.32), 0.35, 0.45)
	m.black = Mat.solid(Color(0.03, 0.03, 0.03), 0.4)
	m.paper = Mat.solid(Color(0.88, 0.85, 0.74), 0.95)
	m.cloth = Mat.solid(Color(0.35, 0.12, 0.1), 0.95)

func mat(name: String) -> Material:
	return m[name]

# ---------------------------------------------------------------- primitives
## Box with collision (default) or visual-only. mat: Material, Color or kit name.
func box(size: Vector3, pos: Vector3, mt: Variant, collide := true, parent: Node = null) -> Node3D:
	var material: Material
	if mt is Material: material = mt
	elif mt is Color: material = Mat.solid(mt)
	else: material = m[str(mt)]
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = size
	mi.mesh = bm; mi.material_override = material
	var p: Node = parent if parent else root
	if not collide:
		mi.position = pos
		p.add_child(mi)
		return mi
	var body := StaticBody3D.new()
	body.position = pos
	var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = size
	cs.shape = sh
	body.add_child(cs); body.add_child(mi)
	p.add_child(body)
	return body

func mesh(mesh_res: Mesh, pos: Vector3, mt: Variant, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh_res; mi.position = pos
	mi.material_override = mt if mt is Material else (Mat.solid(mt) if mt is Color else m[str(mt)])
	(parent if parent else root).add_child(mi)
	return mi

func cyl(r: float, h: float, pos: Vector3, mt: Variant, parent: Node = null) -> MeshInstance3D:
	var c := CylinderMesh.new(); c.top_radius = r; c.bottom_radius = r; c.height = h
	return mesh(c, pos, mt, parent)

## A room shell: floor, ceiling and four walls (inner faces at ±w/2, ±d/2).
## openings: Array of {side:"n|s|e|w", at:float, width:float, height:float, sill:float}
##       (sill > 0 makes it a barred window from sill to height)
## opts: trim (skirting, cornice, door casings — default true), dado (kit material
##       name for a tiled band to 1.05 m), decals (grime/stains, default true),
##       probe (reflection probe = local reflections + bounce-like ambient, default true)
func room(center: Vector3, w: float, d: float, h: float, wall_mat: Variant, floor_mat: Variant, ceil_mat: Variant = "ceiling", openings: Array = [], opts := {}) -> void:
	var trim: bool = opts.get("trim", true)
	var dado: Variant = opts.get("dado", null)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(center) + int(w * 10) + int(d * 100)
	box(Vector3(w + 0.4, 0.2, d + 0.4), center + Vector3(0, -0.1, 0), floor_mat)
	if ceil_mat != null:
		box(Vector3(w + 0.4, 0.2, d + 0.4), center + Vector3(0, h + 0.1, 0), ceil_mat)
	for side in ["n", "s", "e", "w"]:
		var along_x: bool = side == "n" or side == "s"
		var length: float = w if along_x else d
		var off: Vector3
		match side:
			"n": off = Vector3(0, 0, -d / 2 - 0.1)
			"s": off = Vector3(0, 0, d / 2 + 0.1)
			"e": off = Vector3(w / 2 + 0.1, 0, 0)
			"w": off = Vector3(-w / 2 - 0.1, 0, 0)
		var inward: Vector3 = {"n": Vector3.BACK, "s": Vector3.FORWARD, "e": Vector3.LEFT, "w": Vector3.RIGHT}[side]
		var face := center + off + inward * 0.1       # the wall's inner surface
		var holes := openings.filter(func(o): return o.side == side)
		holes.sort_custom(func(a, b): return a.at < b.at)
		var cursor := -length / 2
		var runs: Array = []                            # floor-level wall runs [a, b]
		for o in holes:
			var a: float = o.at - o.width / 2
			_wall_seg(center + off, along_x, cursor, a, h, wall_mat)
			runs.append([cursor, a])
			var oh: float = o.get("height", 2.2)
			if oh < h:   # lintel
				_wall_piece(center + off, along_x, a, a + o.width, oh, h, wall_mat)
			var sill: float = o.get("sill", 0.0)
			if sill > 0.0:
				_wall_piece(center + off, along_x, a, a + o.width, 0.0, sill, wall_mat)
				_window(face, along_x, inward, a, a + o.width, sill, minf(oh, h))
				runs.append([a, a + o.width])
			elif trim:
				_casing(face, along_x, inward, a, a + o.width, minf(oh, h))
			cursor = o.at + o.width / 2
		_wall_seg(center + off, along_x, cursor, length / 2, h, wall_mat)
		runs.append([cursor, length / 2])
		for r in runs:
			if r[1] - r[0] < 0.05:
				continue
			if dado != null:
				_band(face, along_x, inward, r[0], r[1], 0.0, 1.05, 0.012, dado)
				_band(face, along_x, inward, r[0], r[1], 1.05, 1.09, 0.03, "trim")    # cap rail
			if trim:
				_band(face, along_x, inward, r[0], r[1], 0.0, 0.12, 0.025, "trim")    # skirting
			if opts.get("decals", true) and r[1] - r[0] > 1.2:
				for k in int(ceil((r[1] - r[0]) / 3.5)):
					var t := rng.randf_range(r[0] + 0.6, r[1] - 0.6)
					var axis := Vector3.RIGHT if along_x else Vector3.BACK
					grime(face + axis * t, inward, rng.randf_range(1.2, 2.6), rng.randf_range(0.5, 1.0))
					if rng.randf() < 0.45:      # damp seeping down from the slab above
						stain(face + axis * rng.randf_range(r[0] + 0.5, r[1] - 0.5) + Vector3(0, h - 0.55, 0), inward, rng.randf_range(0.8, 1.5))
		if trim:
			_band(face, along_x, inward, -length / 2, length / 2, h - 0.09, h, 0.05, "trim")   # cornice
	if opts.get("decals", true):
		for k in rng.randi_range(1, 2):     # ceiling water stains
			stain(center + Vector3(rng.randf_range(-w, w) * 0.35, h, rng.randf_range(-d, d) * 0.35), Vector3.DOWN, rng.randf_range(0.9, 1.8))
		for k in rng.randi_range(2, 4):     # trodden-in dirt
			stain(center + Vector3(rng.randf_range(-w, w) * 0.4, 0.0, rng.randf_range(-d, d) * 0.4), Vector3.UP, rng.randf_range(1.0, 2.2), "floor_dirt")
		var corner := Vector3(sign(rng.randf() - 0.5) * (w / 2), h - 0.45, sign(rng.randf() - 0.5) * (d / 2 - 0.6))
		stain(center + corner, Vector3.LEFT * sign(corner.x), rng.randf_range(0.6, 1.1), "mould")
	if opts.get("probe", true):
		probe(center + Vector3(0, h / 2, 0), Vector3(w, h, d))

## A thin strip on a wall's inner face from a..b along the wall, y0..y1 high,
## `thick` proud of the wall (skirting, cornice, dado tiles, rails). Visual only.
func _band(face: Vector3, along_x: bool, inward: Vector3, a: float, b: float, y0: float, y1: float, thick: float, mt: Variant) -> void:
	var len := b - a
	if len <= 0.01:
		return
	var mid := (a + b) / 2
	var size := Vector3(len, y1 - y0, thick) if along_x else Vector3(thick, y1 - y0, len)
	var pos := face + (Vector3(mid, 0, 0) if along_x else Vector3(0, 0, mid)) + Vector3(0, (y0 + y1) / 2, 0) + inward * (thick / 2)
	box(size, pos, mt, false)

## Door casing (architrave) around an opening a..b, oh high, both faces.
func _casing(face: Vector3, along_x: bool, inward: Vector3, a: float, b: float, oh: float) -> void:
	for side_off in [0.0, -0.2]:        # room side and the far side of the 0.2 m wall
		var f: Vector3 = face + inward * float(side_off) - (inward * 0.035 if float(side_off) < 0.0 else Vector3.ZERO)
		_band(f, along_x, inward, a - 0.08, a, 0.0, oh + 0.08, 0.035, "trim")      # thicker than the
		_band(f, along_x, inward, b, b + 0.08, 0.0, oh + 0.08, 0.035, "trim")      # skirting: no z-fight
		_band(f, along_x, inward, a - 0.08, b + 0.08, oh, oh + 0.08, 0.035, "trim")

## Window in a wall opening a..b along the wall, sill..top high: timber frame
## and ledge, glass (with a collider) in the wall's middle, and a Mumbai-style
## iron grille in the outer half — moonlight throws the bars across the floor.
func _window(face: Vector3, along_x: bool, inward: Vector3, a: float, b: float, sill: float, top: float) -> void:
	_band(face, along_x, inward, a - 0.07, a, sill - 0.04, top + 0.07, 0.035, "trim")
	_band(face, along_x, inward, b, b + 0.07, sill - 0.04, top + 0.07, 0.035, "trim")
	_band(face, along_x, inward, a - 0.07, b + 0.07, top, top + 0.07, 0.035, "trim")
	_band(face, along_x, inward, a - 0.1, b + 0.1, sill - 0.05, sill, 0.09, "trim")     # ledge
	var axis := Vector3.RIGHT if along_x else Vector3.BACK
	var y := (sill + top) / 2.0
	var hgt := top - sill
	box(Vector3(b - a, hgt, 0.02) if along_x else Vector3(0.02, hgt, b - a), face - inward * 0.1 + axis * ((a + b) / 2.0) + Vector3(0, y, 0), m.glass)
	var bars := maxi(2, int((b - a) / 0.13))
	for k in bars:
		var t := a + (k + 0.5) * (b - a) / bars
		box(Vector3(0.016, hgt, 0.016), face - inward * 0.16 + axis * t + Vector3(0, y, 0), m.black, false)
	for f in [0.33, 0.66]:
		box(Vector3(b - a, 0.016, 0.016) if along_x else Vector3(0.016, 0.016, b - a),
			face - inward * 0.16 + axis * ((a + b) / 2.0) + Vector3(0, sill + hgt * f, 0), m.black, false)

## The night outside the windows: sky with the city's sodium glow, towers with
## lit windows, and a moon (call after setup_common — it needs the floor's Environment).
## flipped: the city hangs upside down from `street_y` (Floor 6, where you walk on the ceiling).
func outside(street_y: float, moon_rot: Vector3, moon_energy := 0.5, seed_val := 77, flipped := false) -> DirectionalLight3D:
	if flipped:
		Skyline.night_sky(Graphics.env, Color(0.012, 0.01, 0.01), Color(0.2, 0.1, 0.045), Color(0.012, 0.014, 0.024), 0.9)
		var holder := Node3D.new(); holder.rotation.z = PI; holder.position.y = street_y
		root.add_child(holder)
		Skyline.build(holder, Vector3.ZERO, seed_val, -22.0, Color(0.02, 0.022, 0.03), Color(1.0, 0.72, 0.38), 0.2)
	else:
		Skyline.night_sky(Graphics.env, Color(0.012, 0.014, 0.024), Color(0.2, 0.1, 0.045), Color(0.012, 0.01, 0.01), 0.9)
		Skyline.build(root, Vector3.ZERO, seed_val, street_y, Color(0.02, 0.022, 0.03), Color(1.0, 0.72, 0.38), 0.2)
	return Skyline.moon(root, Color(0.62, 0.7, 0.95), moon_energy, moon_rot)

## A straight 0.2 m wall centred on `line` running a..b along X (along_x) or Z,
## with barred windows cut into it: windows = [[centre, width], …], sill..top high.
func windowed_wall(line: Vector3, along_x: bool, a: float, b: float, h: float, mt: Variant, inward: Vector3, windows: Array, sill := 1.1, top := 2.6) -> void:
	var base := Vector3(0, line.y, line.z) if along_x else Vector3(line.x, line.y, 0)
	var face := base + inward * 0.1
	var ws := windows.duplicate()
	ws.sort_custom(func(p, q): return p[0] < q[0])
	var cur := a
	for w in ws:
		var wa: float = float(w[0]) - float(w[1]) / 2.0
		var wb: float = float(w[0]) + float(w[1]) / 2.0
		_wall_piece(base, along_x, cur, wa, 0.0, h, mt)
		_wall_piece(base, along_x, wa, wb, 0.0, sill, mt)
		_wall_piece(base, along_x, wa, wb, top, h, mt)
		_window(face, along_x, inward, wa, wb, sill, top)
		cur = wb
	_wall_piece(base, along_x, cur, b, 0.0, h, mt)

## Decal of dirt creeping up a wall from the floor. `at` is on the wall face at
## floor level, `inward` points into the room.
func grime(at: Vector3, inward: Vector3, width: float, height: float) -> Decal:
	var dc := Decal.new()
	dc.texture_albedo = Mat.fx("grime_base")
	if dc.texture_albedo == null:
		return null
	dc.size = Vector3(width, 0.3, height)
	var x := inward.cross(Vector3.DOWN)
	dc.basis = Basis(x, inward, Vector3.DOWN)
	dc.position = at + Vector3(0, height / 2, 0)
	_decal_common(dc)
	root.add_child(dc)
	return dc

## Projected stain: `normal` points away from the surface (UP for floors,
## DOWN for ceilings, inward for walls). kind: water_stain / floor_dirt / mould.
func stain(at: Vector3, normal: Vector3, size: float, kind := "water_stain", upright := false) -> Decal:
	var dc := Decal.new()
	dc.texture_albedo = Mat.fx(kind)
	if dc.texture_albedo == null:
		return null
	dc.size = Vector3(size, 0.4, size)
	if upright and absf(normal.y) < 0.9:      # wall stain whose drips run downwards
		dc.basis = Basis(normal.cross(Vector3.DOWN), normal, Vector3.DOWN)
	else:
		var ref := Vector3.BACK if absf(normal.y) > 0.9 else Vector3.UP
		var x := normal.cross(ref).normalized()
		var z := x.cross(normal).normalized()
		dc.basis = Basis(x, normal, z).rotated(normal, randf() * TAU)
	dc.position = at
	_decal_common(dc)
	root.add_child(dc)
	return dc

func _decal_common(dc: Decal) -> void:
	dc.normal_fade = 0.35            # don't smear onto perpendicular surfaces
	dc.upper_fade = 0.15; dc.lower_fade = 0.15
	dc.distance_fade_enabled = true
	dc.distance_fade_begin = 18.0; dc.distance_fade_length = 6.0
	dc.set_meta("dynamic", true)

## Reflection probe for a room: box-projected local reflections on glossy floors
## plus ambient captured from the room's own lights (cheap bounce light).
## Renders once; FloorBase keeps the torch out of that capture.
func probe(center: Vector3, size: Vector3) -> ReflectionProbe:
	var p := ReflectionProbe.new()
	p.position = center
	p.size = size + Vector3(0.1, 0.1, 0.1)
	p.box_projection = true
	p.interior = true
	p.update_mode = ReflectionProbe.UPDATE_ONCE
	p.ambient_mode = ReflectionProbe.AMBIENT_ENVIRONMENT
	p.ambient_color_energy = 0.7
	p.enable_shadows = true
	p.max_distance = size.length()
	root.add_child(p)
	return p

func _wall_seg(base: Vector3, along_x: bool, a: float, b: float, h: float, mt: Variant) -> void:
	_wall_piece(base, along_x, a, b, 0.0, h, mt)

func _wall_piece(base: Vector3, along_x: bool, a: float, b: float, y0: float, y1: float, mt: Variant) -> void:
	var len := b - a
	if len <= 0.01:
		return
	var mid := (a + b) / 2
	var size := Vector3(len, y1 - y0, 0.2) if along_x else Vector3(0.2, y1 - y0, len)
	var pos := base + (Vector3(mid, 0, 0) if along_x else Vector3(0, 0, mid)) + Vector3(0, (y0 + y1) / 2, 0)
	box(size, pos, mt)

## side: rotation so the label faces a direction. yaw in radians (0 = faces +Z).
func label(t: String, pos: Vector3, yaw: float, col: Color, size: int, shaded := true, parent: Node = null) -> Label3D:
	var l := Label3D.new()
	l.text = t; l.font_size = size; l.pixel_size = 0.004
	l.modulate = col; l.outline_size = 0; l.shaded = shaded
	l.position = pos; l.rotation.y = yaw
	(parent if parent else root).add_child(l)
	return l

## Ceiling fixture + light. kind: "tube" fluorescent, "bulb" caged bulb, "work" construction lamp.
func lamp(pos: Vector3, kind := "tube", col := Color(1.0, 0.87, 0.68), energy := 1.15, rng := 7.0, shadows := false) -> OmniLight3D:
	match kind:
		"tube":
			box(Vector3(0.34, 0.06, 1.15), pos + Vector3(0, 0.03, 0), Mat.solid(Color(0.75, 0.74, 0.7), 0.5, 0.3), false)
			box(Vector3(0.3, 0.012, 1.1), pos + Vector3(0, -0.006, 0), Mat.emissive(col, 6.0), false)
		"bulb":
			var bulb := prop("lightbulb_01", pos + Vector3(0, -0.1, 0), 0.0, Vector3(0, 0.11, 0), false)
			if bulb:
				bulb.rotation.x = PI          # hangs socket-up from its flex
				var core := SphereMesh.new(); core.radius = 0.02; core.height = 0.04
				mesh(core, pos + Vector3(0, -0.155, 0), Mat.emissive(col, 9.0))
			else:
				var b := SphereMesh.new(); b.radius = 0.06; b.height = 0.12
				mesh(b, pos + Vector3(0, -0.1, 0), Mat.emissive(col, 5.0))
			cyl(0.008, 0.2, pos, m.black)
		"work":
			cyl(0.02, 1.6, pos + Vector3(0, -0.8, 0), m.metal_grey)
			if Props.available("security_light"):
				prop("security_light", pos + Vector3(0, 0.12, 0), 0.0, Vector3(0, 0.4, 0), false)
				box(Vector3(0.2, 0.14, 0.01), pos + Vector3(0, -0.02, 0.17), Mat.emissive(col, 4.0), false)
			else:
				box(Vector3(0.3, 0.22, 0.12), pos + Vector3(0, 0.0, 0), m.metal_grey, false)
				box(Vector3(0.26, 0.18, 0.01), pos + Vector3(0, 0.0, -0.065), Mat.emissive(col, 4.0), false)
	var l := OmniLight3D.new()
	l.light_color = col; l.light_energy = energy; l.omni_range = rng; l.omni_attenuation = 1.3
	l.light_volumetric_fog_energy = 0.8
	l.shadow_enabled = shadows or Graphics.lamp_shadows()
	l.position = pos + Vector3(0, -0.25, 0)
	root.add_child(l)
	lights.append(l)
	# Forward+: a shadow-casting downlight under tubes and bulbs gives each fixture
	# a real pool of light (and furniture its shadow); the omni becomes soft fill.
	# Phones skip it (the Mobile renderer caps lights per object).
	if kind != "work" and Graphics.forward_plus():
		var s := preload("res://scripts/world/follow_light.gd").new()
		s.ratio = 4.0
		s.spot_range = rng * 0.85; s.spot_angle = 48.0
		s.spot_angle_attenuation = 1.4; s.spot_attenuation = 1.1
		s.light_volumetric_fog_energy = 1.8
		s.distance_fade_enabled = true
		s.distance_fade_begin = 13.0; s.distance_fade_shadow = 9.0; s.distance_fade_length = 4.0
		s.position = Vector3(0, 0.15, 0)
		s.rotation.x = -PI / 2           # SpotLight3D shines along -Z: point it at the floor
		l.add_child(s)
		l.light_energy = energy * FILL
		l.set_meta("spot", s)
	return l

# ---------------------------------------------------------------- real models
## Place a CC0 glTF prop. Poly Haven models face +Z; yaw rotates that front.
## Returns the StaticBody (collide) or holder node, or null if the model is missing.
func prop(id: String, pos: Vector3, yaw := 0.0, fit := Vector3.ZERO, collide := true, parent: Node = null) -> Node3D:
	var n := Props.spawn(id, fit, collide)
	if n == null:
		return null
	n.position = pos
	n.rotation.y = yaw
	(parent if parent else root).add_child(n)
	return n

# ---------------------------------------------------------------- props
func board(pos: Vector3, yaw: float, rules: Array, mirrored := false) -> Node3D:
	var b := box(Vector3(1.7, 1.25, 0.05), pos, m.cork if m.cork.albedo_texture else m.ply)
	b.rotation.y = yaw
	b.set_meta("board", true)
	b.set_meta("prompt", "Read notice board")
	box(Vector3(1.25, 1.05, 0.01), Vector3(0, 0, 0.03), m.paper, false, b)
	# aluminium frame, brass pins, old slips nobody took down
	for yy in [0.645, -0.645]:
		box(Vector3(1.76, 0.04, 0.07), Vector3(0, yy, 0.01), m.chrome, false, b)
	for xx in [0.87, -0.87]:
		box(Vector3(0.04, 1.33, 0.07), Vector3(xx, 0, 0.01), m.chrome, false, b)
	for c in [Vector2(-0.58, 0.48), Vector2(0.58, 0.48), Vector2(-0.58, -0.48), Vector2(0.58, -0.48)]:
		var pin := cyl(0.012, 0.012, Vector3(c.x, c.y, 0.04), Color(0.75, 0.1, 0.08), b)
		pin.rotation.x = PI / 2
	for slip in [[Vector3(-0.74, 0.3, 0.028), 0.12, Color(0.95, 0.88, 0.45)], [Vector3(0.74, -0.25, 0.028), -0.1, Color(0.95, 0.75, 0.75)]]:
		var sl := box(Vector3(0.17, 0.24, 0.004), slip[0], slip[2], false, b)
		sl.rotation.z = slip[1]
	var txt := "RULES OF THE BUILDING\n"
	for r in rules:
		txt += "\n• " + str(r.text)
	var l := label(txt, Vector3(0, 0, 0.037), 0.0, Color(0.08, 0.07, 0.06), 20, true, b)
	l.width = 300; l.autowrap_mode = TextServer.AUTOWRAP_WORD
	var tw: Font = preload("res://scripts/ui/fonts.gd").typewriter()
	if tw:
		l.font = tw
	if mirrored:
		l.scale.x = -1.0
	for r in rules:
		if r.get("night", false):
			var lie := label("✗  " + str(r.text) + "  — A LIE", Vector3(0, -0.72, 0.04), 0.0, Color(1, 0.15, 0.1), 22, false, b)
			lie.layers = 2           # only the phone camera sees it
			if mirrored:
				lie.scale.x = -1.0
	return b

func chair(pos: Vector3, yaw: float, style := "office") -> Node3D:
	var n := Node3D.new(); n.position = pos; n.rotation.y = yaw
	root.add_child(n)
	var model_id := "SchoolChair_01" if style == "office" else "painted_wooden_chair_02"
	if Props.available(model_id):
		var fit := Vector3(0, 0.98, 0) if style == "office" else Vector3(0, 1.05, 0)
		prop(model_id, Vector3.ZERO, PI, fit, false, n)    # model faces +Z, our chairs face -Z
		return n
	var legs := Mat.solid(Color(0.12, 0.12, 0.13), 0.4, 0.8)
	box(Vector3(0.48, 0.05, 0.46), Vector3(0, 0.47, 0), m.ply, false, n)
	box(Vector3(0.48, 0.5, 0.04), Vector3(0, 0.76, 0.21), m.ply, false, n)
	for x in [-0.21, 0.21]:
		for z in [-0.2, 0.2]:
			box(Vector3(0.025, 0.47, 0.025), Vector3(x, 0.235, z), legs, false, n)
	return n

func table(pos: Vector3, size: Vector3, mt: Variant = "wood") -> Node3D:
	var t := box(Vector3(size.x, 0.05, size.z), pos + Vector3(0, size.y, 0), mt)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			box(Vector3(0.05, size.y, 0.05), pos + Vector3(sx * (size.x / 2 - 0.05), size.y / 2, sz * (size.z / 2 - 0.05)), mt)
	return t

## Desk you can hide under. The spot looks out toward the desk's +Z side.
func desk(pos: Vector3, yaw: float, hideable := true) -> Node3D:
	var n := Node3D.new(); n.position = pos; n.rotation.y = yaw
	root.add_child(n)
	var top := box(Vector3(1.6, 0.06, 0.8), Vector3(0, 0.76, 0), m.wood, true, n)
	var parts: Array = [top]
	for x in [-0.75, 0.75]:
		parts.append(box(Vector3(0.06, 0.73, 0.75), Vector3(x, 0.365, 0), m.wood, true, n))
	parts.append(box(Vector3(1.44, 0.5, 0.03), Vector3(0, 0.48, -0.37), m.wood, true, n))   # modesty panel
	if Props.available("metal_office_desk"):
		for p in parts:        # keep the colliders, show the real desk
			(p.get_child(1) as MeshInstance3D).visible = false
		prop("metal_office_desk", Vector3.ZERO, 0.0, Vector3(1.6, 0.79, 0.8), false, n)
	if hideable:
		var area := box(Vector3(1.4, 0.7, 0.66), Vector3(0, 0.35, 0), Color(0, 0, 0), true, n)
		area.get_child(1).visible = false
		area.set_meta("hide", true)
		area.set_meta("prompt", "Hide under desk")
		area.set_meta("hide_msg", "You crawl under the desk. Hold [Space] to hold your breath.")
		var spot := _spot(Vector3(0, 0, 0), "desk", 0.55, n)
		spot.rotation.y = PI
		area.set_meta("hide_spot", spot)
	return n

## Steel locker / almirah you can hide in; front faces local -Z.
func locker(pos: Vector3, yaw: float, label_text := "") -> Node3D:
	var body := box(Vector3(0.9, 2.0, 0.6), pos + Vector3(0, 1.0, 0), m.metal)
	body.rotation.y = yaw
	body.set_meta("hide", true)
	body.set_meta("prompt", "Hide in locker")
	body.set_meta("hide_msg", "You pull the door shut behind you. Hold [Space] to hold your breath.")
	for k in 4:
		box(Vector3(0.4, 0.02, 0.01), Vector3(0, 0.55 + k * 0.05, -0.305), m.black, false, body)
	box(Vector3(0.01, 1.9, 0.012), Vector3(0, 0, -0.306), m.black, false, body)
	# a Godrej-style steel almirah: pressed door panels, chrome handles, brass lock, plinth
	for sx in [-0.22, 0.22]:
		box(Vector3(0.34, 1.55, 0.006), Vector3(sx, -0.05, -0.303), m.metal, false, body)
		box(Vector3(0.018, 0.24, 0.022), Vector3(sign(sx) * 0.05, 0.02, -0.318), m.chrome, false, body)
	box(Vector3(0.05, 0.08, 0.006), Vector3(0.11, -0.12, -0.304), m.brass, false, body)
	box(Vector3(0.008, 0.025, 0.004), Vector3(0.11, -0.12, -0.308), m.black, false, body)
	box(Vector3(0.93, 0.07, 0.63), Vector3(0, -0.965, 0), m.black, false, body)
	box(Vector3(0.94, 0.035, 0.64), Vector3(0, 1.0, 0), m.metal_grey, false, body)
	if label_text != "":
		label(label_text, Vector3(0, 0.25, -0.312), PI, Color(0.1, 0.1, 0.1), 28, true, body)
	var spot := _spot(Vector3(pos.x, pos.y, pos.z), "locker", 1.55)
	spot.rotation.y = yaw
	body.set_meta("hide_spot", spot)
	return body

func _spot(pos: Vector3, kind: String, eye: float, parent: Node = null) -> Node3D:
	var s := Node3D.new()
	s.position = pos
	s.set_meta("hide_kind", kind)
	s.set_meta("eye", eye)
	(parent if parent else root).add_child(s)
	spots.append(s)
	return s

## Interactive door. state: "locked" or "open". Doors are walls with a slab.
func door(pos: Vector3, yaw: float, id: String, prompt := "Door", mt: Variant = "wood") -> Node3D:
	var d := box(Vector3(1.0, 2.1, 0.08), pos + Vector3(0, 1.05, 0), mt)
	d.rotation.y = yaw
	d.set_meta("use", id)
	d.set_meta("prompt", prompt)
	_door_dress(d, 0.04, mt is String and mt == "wood")
	return d

## Raised panels (wooden doors), lever handles and a kick plate on both faces
## of a 1.0 x 2.1 door slab whose faces sit at ±half_t.
func _door_dress(d: Node3D, half_t: float, panels: bool) -> void:
	for s in [1.0, -1.0]:
		var z: float = s * (half_t + 0.006)
		if panels:
			box(Vector3(0.72, 0.86, 0.012), Vector3(0, 0.45, z), m.door_panel, false, d)
			box(Vector3(0.72, 0.62, 0.012), Vector3(0, -0.5, z), m.door_panel, false, d)
		var rose := cyl(0.032, 0.012, Vector3(0.38, -0.02, z), m.brass, d)
		rose.rotation.x = PI / 2
		var lever := box(Vector3(0.13, 0.02, 0.02), Vector3(0.33, -0.02, z + s * 0.035), m.brass, false, d)
		box(Vector3(0.02, 0.02, 0.035), Vector3(0.38, -0.02, z + s * 0.018), m.brass, false, d)
		box(Vector3(0.9, 0.16, 0.004), Vector3(0, -0.96, z), m.brass if panels else m.metal_grey, false, d)

## Analog wall clock with its hands set to hours:minutes. Faces +Z before yaw.
func clock(pos: Vector3, yaw: float, hours: int, minutes: int, radius := 0.3) -> Node3D:
	var n := Node3D.new(); n.position = pos; n.rotation.y = yaw
	root.add_child(n)
	var rim := cyl(radius, 0.05, Vector3(0, 0, 0.025), m.black, n); rim.rotation.x = PI / 2
	var face := cyl(radius * 0.9, 0.01, Vector3(0, 0, 0.051), Mat.solid(Color(0.88, 0.86, 0.78), 0.55), n)
	face.rotation.x = PI / 2
	for k in 12:
		var a := k * TAU / 12.0
		var major := k % 3 == 0
		var t := box(Vector3(0.014 if major else 0.007, radius * (0.16 if major else 0.09), 0.004),
			Vector3(sin(a), cos(a), 0) * radius * 0.74 + Vector3(0, 0, 0.058), m.black, false, n)
		t.rotation.z = -a
	var ha := (hours % 12 + minutes / 60.0) / 12.0 * TAU
	var ma := minutes / 60.0 * TAU
	for hand in [[ha, radius * 0.5, 0.02, 0.062], [ma, radius * 0.74, 0.012, 0.066]]:
		var h := box(Vector3(hand[2], hand[1], 0.004), Vector3(sin(hand[0]), cos(hand[0]), 0) * hand[1] * 0.42 + Vector3(0, 0, hand[3]), m.black, false, n)
		h.rotation.z = -hand[0]
	var cap := cyl(0.018, 0.012, Vector3(0, 0, 0.07), m.brass, n); cap.rotation.x = PI / 2
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.8, 0.85, 0.85, 0.08); glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.04; glass.metallic = 0.3
	var g := cyl(radius * 0.92, 0.004, Vector3(0, 0, 0.078), glass, n); g.rotation.x = PI / 2
	return n

## Potted plant (CC0 model) with a primitive fallback. which: 2 (leafy, ~70k
## triangles: one per floor at most) or 4 (small succulent). Foliage casts no
## shadows: it would multiply that triangle count in every shadow pass.
func plant(pos: Vector3, which := 4, height := 0.5) -> Node3D:
	var n := prop("potted_plant_%02d" % which, pos, randf() * TAU, Vector3(0, height, 0), true)
	if n == null:
		cyl(0.25, 0.5, pos + Vector3(0, 0.25, 0), Color(0.4, 0.25, 0.15))
		return null
	for g in n.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n

## A flat sign: a plate with text (wall plaques, directories, notices). Faces +Z before yaw.
func plaque(text: String, pos: Vector3, yaw: float, size: Vector2, bg: Variant, fg: Color, font := 24) -> Node3D:
	var n := Node3D.new(); n.position = pos; n.rotation.y = yaw
	root.add_child(n)
	box(Vector3(size.x, size.y, 0.02), Vector3(0, 0, 0.01), bg, false, n)
	var l := label(text, Vector3(0, 0, 0.022), 0.0, fg, font, true, n)
	l.width = size.x / l.pixel_size * 0.92
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	return n

## Swing a door open (removes its collision so you can walk through).
func open_door(d: Node3D) -> void:
	if not is_instance_valid(d) or d.get_meta("opened", false):
		return
	d.set_meta("opened", true)
	d.remove_meta("prompt")
	var creak := AudioStreamPlayer3D.new()
	creak.stream = preload("res://scripts/systems/sfx.gd").get_stream("creak")
	creak.bus = "SFX"; creak.unit_size = 5.0; creak.autoplay = true
	d.add_child(creak)
	(d.get_child(0) as CollisionShape3D).disabled = true
	var hinge := d.global_transform.basis.x * -0.5
	var tw := d.create_tween()
	tw.tween_property(d, "rotation:y", d.rotation.y + deg_to_rad(95), 1.2).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(d, "position", d.position + hinge + d.global_transform.basis.z * 0.5, 1.2)

## Metal stairwell door with a glowing sign. Locked until the floor is solved.
func stair_exit(pos: Vector3, yaw: float, sign_text: String) -> Node3D:
	var d := box(Vector3(1.0, 2.1, 0.06), pos + Vector3(0, 1.05, 0), m.metal)
	d.rotation.y = yaw
	d.set_meta("stair_exit", true)
	d.set_meta("prompt", "Stairwell")
	var wired := StandardMaterial3D.new()
	wired.albedo_color = Color(0.08, 0.1, 0.1); wired.roughness = 0.1; wired.metallic = 0.4
	for s in [1.0, -1.0]:
		box(Vector3(0.26, 0.5, 0.008), Vector3(0.22, 0.42, s * 0.032), wired, false, d)
		box(Vector3(0.3, 0.54, 0.006), Vector3(0.22, 0.42, s * 0.03), m.black, false, d)
		box(Vector3(0.9, 0.18, 0.004), Vector3(0, -0.94, s * 0.031), m.metal_grey, false, d)
	box(Vector3(0.9, 0.04, 0.03), Vector3(0, -0.05, 0.05), m.brass, false, d)
	box(Vector3(0.6, 0.18, 0.05), Vector3(0, 1.35, 0.02), Mat.emissive(Color(0.1, 0.9, 0.3), 2.5), false, d)
	var l := label(sign_text, Vector3(0, 1.35, 0.06), 0.0, Color(0.02, 0.1, 0.03), 22, false, d)
	l.pixel_size = 0.0035
	return d

func note(id: String, pos: Vector3, yaw := 0.3) -> Node3D:
	var b := box(Vector3(0.21, 0.004, 0.29), pos, m.paper)
	b.rotation.y = yaw
	b.set_meta("note", id)
	b.set_meta("prompt", "Read note")
	return b

## Puzzle item lying somewhere. look: "card", "key", "page", "fuse", "photo", "tape", "mug", "box".
func item(id: String, title: String, pos: Vector3, look := "box", col := Color(0.8, 0.75, 0.6)) -> Node3D:
	var size: Vector3 = {"card": Vector3(0.09, 0.005, 0.055), "key": Vector3(0.07, 0.01, 0.02), "page": Vector3(0.21, 0.003, 0.29),
		"fuse": Vector3(0.05, 0.05, 0.12), "photo": Vector3(0.1, 0.004, 0.15), "tape": Vector3(0.1, 0.015, 0.065),
		"mug": Vector3(0.09, 0.1, 0.09), "box": Vector3(0.16, 0.1, 0.12)}.get(look, Vector3(0.15, 0.1, 0.15))
	var b := StaticBody3D.new(); b.position = pos
	var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = size.max(Vector3(0.18, 0.12, 0.18))
	cs.shape = sh; b.add_child(cs)
	box(size, Vector3(0, size.y / 2, 0), Mat.solid(col, 0.6, 0.6 if look in ["key", "fuse"] else 0.0), false, b)
	var glint := OmniLight3D.new()
	glint.light_energy = 0.12; glint.omni_range = 0.5; glint.light_color = Color(1, 0.9, 0.7)
	glint.position.y = 0.12
	b.add_child(glint)
	b.set_meta("item", id)
	b.set_meta("prompt", "Take " + title)
	root.add_child(b)
	return b

## Trigger volume (Area3D) calling cb(body) when the player enters.
func trigger(pos: Vector3, size: Vector3, cb: Callable) -> Area3D:
	var a := Area3D.new(); a.position = pos
	var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = size
	cs.shape = sh; a.add_child(cs)
	a.body_entered.connect(cb)
	root.add_child(a)
	return a
