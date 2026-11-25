extends Node3D
## Floor 2 — THE CORRIDOR. Procedurally builds the looping hotel corridor
## (PBR materials, wainscoting, doors, fixtures) and applies at most one
## anomaly per pass. Coordinates: corridor z = 0 .. -44, start lobby z 0..5,
## end lobby z -44..-49, walls' inner faces at x = ±1.5.

const Mat := preload("res://scripts/systems/mat_lib.gd")
const Batcher := preload("res://scripts/systems/batcher.gd")
const Props := preload("res://scripts/world/props.gd")

## A real CC0 model into the current target; null if missing (caller falls back).
func _prop(id: String, pos: Vector3, yaw := 0.0, fit := Vector3.ZERO, collide := true) -> Node3D:
	var n := Props.spawn(id, fit, collide)
	if n == null:
		return null
	n.position = pos; n.rotation.y = yaw
	_target.add_child(n)
	return n

const SLOTS := 10          # door slots per side, 4 m each
const SLOT_LEN := 4.0
const LEN := 44.0
const HALF_W := 1.6
const FACE := HALF_W - 0.1 # inner wall face
const H := 3.0
const ROOM213_SLOT := 6    # left side, slot 6 normally labelled 214

var room213_open := false
var _target: Node3D            # where builders put nodes: a cached shell or this pass
var _shells := {}              # open_213 (bool) -> Node3D, built + batched once
var _dyn: Node3D               # everything that can change between passes
var light_scale := 1.0        # Night Shift / altered-floor dimming, applied every rebuild
var figure: Node3D
var knock_doors: Array = []   # StaticBody3D per door id (null for Room 213)
var lights: Array = []        # OmniLight3D, for flicker events
var hide_spot: Node3D
var _rules: Array = []
var _rng := RandomNumberGenerator.new()

# materials
var m_wallpaper: Material
var m_lobby_wall: Material
var m_carpet: Material
var m_mosaic: Material
var m_ceiling: Material
var m_door: Material
var m_door_panel: Material
var m_trim: Material
var m_wainscot: Material
var m_metal: Material
var m_brass: Material
var m_ply: Material

func _init() -> void:
	m_wallpaper = Mat.pbr("decrepit_wallpaper", 1.6, Color(1.0, 0.96, 0.9))
	m_lobby_wall = Mat.pbr("painted_plaster_wall", 2.4, Color(0.7, 0.82, 0.74))
	m_carpet = Mat.pbr("dirty_carpet", 1.8, Color(1.5, 0.95, 0.85))
	m_mosaic = Mat.pbr("terrazzo_tiles", 1.5, Color(1.0, 0.97, 0.92), 0.55)
	m_ceiling = Mat.pbr("white_plaster_02", 2.0, Color(0.86, 0.85, 0.81))
	m_door = Mat.pbr("sapele_veneer", 1.1, Color(0.62, 0.42, 0.3), 0.75)
	m_door_panel = Mat.pbr("sapele_veneer", 0.8, Color(0.5, 0.33, 0.24), 0.75)
	m_trim = Mat.pbr("sapele_veneer", 0.6, Color(0.36, 0.24, 0.17), 0.8)
	m_wainscot = Mat.pbr("sapele_veneer", 0.9, Color(0.5, 0.35, 0.26), 0.8)
	m_metal = Mat.pbr("rusty_painted_metal", 1.0, Color(0.72, 0.8, 0.76), 1.0, 0.2)
	m_brass = Mat.solid(Color(0.8, 0.62, 0.32), 0.35, 0.45)
	m_ply = Mat.pbr("plywood", 1.0)

func set_rules(rules: Array) -> void:
	_rules = rules

func door_numbers() -> Array:
	var nums := []
	for n in range(201, 222):
		if n != 213:
			nums.append(n)
	return nums

## anomaly: "" for a clean pass. streak drives the tally + clues.
func build(anomaly: String, streak: int, open_213: bool, seed_val: int = 0) -> void:
	if _dyn:
		remove_child(_dyn)
		_dyn.queue_free()
	knock_doors.clear()
	lights.clear()
	figure = null
	room213_open = open_213
	_rng.seed = seed_val if seed_val != 0 else randi()
	# the shell (floors, ceilings, walls, trims, door frames, Room 213) never
	# changes within a variant: build and batch it once, then just show it
	if not _shells.has(open_213):
		var sh := Node3D.new()
		sh.name = "Shell213" if open_213 else "Shell"
		add_child(sh)
		_shells[open_213] = sh
		_target = sh
		_build_shell(open_213)
		Batcher.batch(sh)
	for k in _shells:
		_shells[k].visible = (k == open_213)
	_dyn = Node3D.new(); _dyn.name = "Pass"
	add_child(_dyn)
	_target = _dyn
	if anomaly == "ceiling_low":
		_box(Vector3(HALF_W * 2, 0.7, 12), Vector3(0, H - 0.35, -22), m_ceiling)

	# doors per slot (walls and frames live in the shell)
	var nums := door_numbers()
	var wrong_door := _rng.randi_range(0, SLOTS * 2 - 1)
	var ajar_door := _rng.randi_range(0, SLOTS * 2 - 1)
	for i in SLOTS:
		var zc := -SLOT_LEN * i - SLOT_LEN / 2
		for s in 2:
			var side := -1 if s == 0 else 1
			var idx := i * 2 + s
			if side == -1 and i == ROOM213_SLOT and open_213:
				var l213 := _label("213", Vector3(side * (FACE - 0.01), 2.45, zc), side, Color(0.75, 0.05, 0.05), 56)
				l213.shaded = false
				knock_doors.append(null)
				continue
			var num := str(nums[idx])
			if anomaly == "door_number" and idx == wrong_door:
				num = num.reverse() if num.reverse() != num else str(nums[idx] + 50)
			var door := _door(side, zc, num)
			door.set_meta("door_index", idx)
			door.set_meta("prompt", "Door " + num)
			if anomaly == "door_ajar" and idx == ajar_door:
				door.rotation.y = deg_to_rad(28) * side
				door.position.z += 0.25
			knock_doors.append(door)
	_build_pass(anomaly, streak)

## Static architecture for one Room 213 variant.
func _build_shell(open_213: bool) -> void:
	# floors: mosaic lobbies, carpeted corridor
	_box(Vector3(HALF_W * 2, 0.2, 5), Vector3(0, -0.1, 2.5), m_mosaic)
	for k in int(LEN / SLOT_LEN):
		_box(Vector3(HALF_W * 2, 0.2, SLOT_LEN), Vector3(0, -0.1, -SLOT_LEN * k - SLOT_LEN / 2), m_carpet)
	_box(Vector3(HALF_W * 2, 0.2, 5), Vector3(0, -0.1, -46.5), m_mosaic)
	# ceiling in segments too (5 m lobbies + 4 m slots)
	_box(Vector3(HALF_W * 2 + 0.4, 0.2, 5), Vector3(0, H + 0.1, 2.5), m_ceiling)
	for k in int(LEN / SLOT_LEN):
		_box(Vector3(HALF_W * 2 + 0.4, 0.2, SLOT_LEN), Vector3(0, H + 0.1, -SLOT_LEN * k - SLOT_LEN / 2), m_ceiling)
	_box(Vector3(HALF_W * 2 + 0.4, 0.2, 5), Vector3(0, H + 0.1, -46.5), m_ceiling)
	# end caps
	_box(Vector3(HALF_W * 2 + 0.4, H, 0.2), Vector3(0, H / 2, 5), m_lobby_wall)
	_box(Vector3(HALF_W * 2 + 0.4, H, 0.2), Vector3(0, H / 2, -49), m_lobby_wall)
	# lobby side walls (plain paint) + slot 10 run-out (wainscoted)
	for side in [-1, 1]:
		_wall(side, 2.5, 5.0, m_lobby_wall, false)
		_wall(side, -46.5, 5.0, m_lobby_wall, false)
		_wall(side, -42.0, 4.0, m_wallpaper, true)

	# slot walls + door frames (Room 213's doorway in the open variant)
	for i in SLOTS:
		var zc := -SLOT_LEN * i - SLOT_LEN / 2
		for side in [-1, 1]:
			if side == -1 and i == ROOM213_SLOT and open_213:
				_wall(side, zc + 1.25, 1.5, m_wallpaper, true)
				_wall(side, zc - 1.25, 1.5, m_wallpaper, true)
				_box(Vector3(0.2, 0.9, 1.0), Vector3(side * HALF_W, H - 0.45, zc), m_wallpaper)
				_door_frame(side, zc)
				_build_room213(zc)
				continue
			_wall(side, zc, SLOT_LEN, m_wallpaper, true)
			_door_frame(side, zc)

## Everything that can differ between passes: fixtures, paintings, props, anomalies, lobby.
func _build_pass(anomaly: String, streak: int) -> void:
	# ceiling fixtures: 1990s fluorescent diffusers
	var light_zs := [2.5, -2.0, -10.0, -18.0, -26.0, -34.0, -42.0, -46.5]
	var victim := _rng.randi_range(1, 5)
	for li in light_zs.size():
		var col := Color(1.0, 0.87, 0.68)
		var dead := anomaly == "light_missing" and li == victim
		if anomaly == "light_red" and li == victim:
			col = Color(1, 0.08, 0.05)
		var z: float = light_zs[li]
		_box(Vector3(0.34, 0.06, 1.15), Vector3(0, H - 0.03, z), Mat.solid(Color(0.75, 0.74, 0.7), 0.5, 0.3), false)
		if dead:
			_box(Vector3(0.3, 0.012, 1.1), Vector3(0, H - 0.066, z), Mat.solid(Color(0.15, 0.15, 0.14), 0.4), false)
			continue
		_box(Vector3(0.3, 0.012, 1.1), Vector3(0, H - 0.066, z), Mat.emissive(col, 3.0), false)
		var l := OmniLight3D.new()
		l.light_color = col
		l.light_energy = 1.15 * light_scale
		l.omni_range = 7.0
		l.omni_attenuation = 1.3
		l.light_volumetric_fog_energy = 0.7
		l.shadow_enabled = Graphics.lamp_shadows()
		l.position = Vector3(0, H - 0.25, z)
		_target.add_child(l)
		lights.append(l)

	# paintings at slot boundaries
	var paintings := [[2, -1, Color(0.5, 0.85, 0.85)], [5, 1, Color(1.0, 0.8, 0.45)], [8, -1, Color(0.9, 0.45, 0.45)]]
	for p in paintings:
		var c: Color = p[2]
		if anomaly == "painting_color" and p[0] == 5:
			c = Color(0.35, 0.45, 1.0)
		var x: float = p[1] * (FACE - 0.025)
		_box(Vector3(0.05, 0.85, 1.05), Vector3(x, 1.7, -p[0] * SLOT_LEN), m_trim)
		_box(Vector3(0.06, 0.68, 0.88), Vector3(x - p[1] * 0.006, 1.7, -p[0] * SLOT_LEN), Mat.canvas(c, int(p[0])))

	# props
	if anomaly == "chair_moved":
		_chair(Vector3(0, 0, -24), PI)
	else:
		_chair(Vector3(1.15, 0, -16), -PI / 2)
	var table_top := 0.78
	if _prop("side_table_01", Vector3(1.22, 0, -28), -PI / 2, Vector3(0.5, table_top, 0.45)) == null:
		_box(Vector3(0.45, 0.75, 0.45), Vector3(1.24, 0.375, -28), m_door)  # side table
		_box(Vector3(0.5, 0.03, 0.5), Vector3(1.24, 0.765, -28), m_trim, false)
	if anomaly != "vase_missing":
		if _prop("ceramic_vase_01", Vector3(1.22, table_top, -28), 0.0, Vector3(0, 0.42, 0), false) == null:
			var vm := CylinderMesh.new(); vm.top_radius = 0.06; vm.bottom_radius = 0.1; vm.height = 0.36
			_mesh(vm, Vector3(1.24, 0.96, -28), Mat.solid(Color(0.16, 0.3, 0.55), 0.12))
	if anomaly != "extinguisher_missing" and _prop("korean_fire_extinguisher_01", Vector3(-1.32, 0, -20), PI / 2, Vector3(0, 0.62, 0), false) != null:
		pass
	elif anomaly != "extinguisher_missing":
		var em := CylinderMesh.new(); em.top_radius = 0.08; em.bottom_radius = 0.08; em.height = 0.52
		_mesh(em, Vector3(-1.38, 0.62, -20), Mat.solid(Color(0.62, 0.04, 0.03), 0.3, 0.2))
		_box(Vector3(0.05, 0.08, 0.05), Vector3(-1.38, 0.92, -20), Mat.solid(Color(0.05, 0.05, 0.05), 0.4), false)
		_box(Vector3(0.04, 0.16, 0.2), Vector3(-FACE + 0.02, 0.95, -20), m_metal, false)
	if anomaly == "extra_phone":
		_box(Vector3(0.24, 0.1, 0.22), Vector3(-0.4, 0.05, -20), Mat.solid(Color(0.03, 0.03, 0.03), 0.2))
		var hm := CapsuleMesh.new(); hm.radius = 0.03; hm.height = 0.24
		var hs := _mesh(hm, Vector3(-0.4, 0.12, -20), Mat.solid(Color(0.03, 0.03, 0.03), 0.2))
		hs.rotation.x = PI / 2
	if anomaly == "stains":
		for k in 5:
			_stain(Vector3(FACE - 0.02, 1.15 + k * 0.22, -23.0 - k * 0.38), Vector3(0.42, 0.3, 0.34))
		for k in 3:
			_stain(Vector3(FACE - 0.02, 0.95 + k * 0.2, -23.2 - k * 0.6), Vector3(0.7, 0.3, 0.1))
	if anomaly == "figure":
		figure = _figure(Vector3(0.4, 0, -41))

	# start lobby: rule board, tally, hiding almirah, floor sign
	_rule_board(Vector3(-FACE + 0.03, 1.55, 2.5))
	var tally := ""
	for k in streak:
		tally += "|" if (k + 1) % 5 != 0 else "\\ "
	var tl := _label(tally if tally != "" else " ", Vector3(FACE - 0.01, 1.6, 2.0), 1, Color(0.92, 0.92, 0.9), 72)
	tl.shaded = true
	var sign := _label("2", Vector3(0, 2.0, 4.89), 2, Color(0.2, 0.18, 0.15), 220)
	sign.shaded = true
	_almirah(Vector3(FACE - 0.32, 0.0, 4.25))
	# camera-only clue: only the phone sees it (render layer 2)
	if streak >= 2:
		var ghost := _label("2 1 3 →", Vector3(-FACE + 0.012, 1.6, -SLOT_LEN * ROOM213_SLOT), -1, Color(0.6, 1.0, 0.6), 72)
		ghost.layers = 2
	# end lobby: stair door, exit sign, chalk clue
	_box(Vector3(1.0, 2.1, 0.06), Vector3(0, 1.05, -48.87), m_metal)
	_box(Vector3(0.9, 0.04, 0.03), Vector3(0, 1.0, -48.83), m_brass, false)
	_box(Vector3(0.5, 0.18, 0.05), Vector3(0, 2.45, -48.86), Mat.emissive(Color(0.1, 0.9, 0.3), 2.5), false)
	var stairs := _label("STAIRS ▲  FLOOR 3", Vector3(0, 2.45, -48.82), 0, Color(0.02, 0.1, 0.03), 22)
	stairs.shaded = false
	if streak >= 4:
		var clue := _label("213 IS REAL", Vector3(0.9, 1.3, -48.88), 0, Color(0.9, 0.9, 0.88), 44)
		clue.shaded = true
	if figure:
		figure.set_meta("dynamic", true)    # it turns to watch you

# ---------------------------------------------------------------- pieces

## A wall run with optional wainscot / dado / skirting / crown trims.
func _wall(side: int, zc: float, length: float, mat: Material, wainscot: bool) -> void:
	_box(Vector3(0.2, H, length), Vector3(side * HALF_W, H / 2, zc), mat)
	var x := side * FACE
	if wainscot:
		_box(Vector3(0.025, 0.95, length), Vector3(x - side * 0.0125, 0.475, zc), m_wainscot, false)
		_box(Vector3(0.05, 0.06, length), Vector3(x - side * 0.025, 0.97, zc), m_trim, false)
	_box(Vector3(0.035, 0.14, length), Vector3(x - side * 0.0175, 0.07, zc), m_trim, false)
	_box(Vector3(0.06, 0.09, length), Vector3(x - side * 0.03, H - 0.045, zc), m_trim, false)

func _door_frame(side: int, zc: float) -> void:
	var x := side * (FACE - 0.04)
	_box(Vector3(0.08, 2.2, 0.08), Vector3(x, 1.1, zc + 0.54), m_trim, false)
	_box(Vector3(0.08, 2.2, 0.08), Vector3(x, 1.1, zc - 0.54), m_trim, false)
	_box(Vector3(0.08, 0.1, 1.16), Vector3(x, 2.15, zc), m_trim, false)

## Panelled veneer door with brass number plate and lever handle.
## Everything is parented to the door body so "ajar" rotates it all.
func _door(side: int, zc: float, num: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = Vector3(side * (FACE - 0.02), 1.05, zc)
	_target.add_child(body)
	var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = Vector3(0.08, 2.1, 1.0)
	cs.shape = sh; body.add_child(cs)
	var out := -side   # direction facing into the corridor
	_child_box(body, Vector3(0.08, 2.1, 1.0), Vector3.ZERO, m_door)
	_child_box(body, Vector3(0.012, 0.72, 0.68), Vector3(out * 0.045, 0.5, 0), m_door_panel)
	_child_box(body, Vector3(0.012, 0.72, 0.68), Vector3(out * 0.045, -0.42, 0), m_door_panel)
	_child_box(body, Vector3(0.05, 0.025, 0.13), Vector3(out * 0.06, -0.05, 0.36), m_brass)
	_child_box(body, Vector3(0.02, 0.07, 0.03), Vector3(out * 0.05, -0.05, 0.42), m_brass)
	var l := Label3D.new()
	l.text = num; l.font_size = 110; l.pixel_size = 0.0016
	l.modulate = Color(0.92, 0.74, 0.42); l.shaded = true; l.outline_size = 0
	l.position = Vector3(out * 0.056, 0.58, 0)   # in front of the raised panel
	l.rotation.y = PI / 2 if side == -1 else -PI / 2
	body.add_child(l)
	return body

func _child_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = size
	mi.mesh = bm; mi.material_override = mat; mi.position = pos
	parent.add_child(mi)
	return mi

func _rule_board(pos: Vector3) -> void:
	var board := _box(Vector3(0.05, 1.25, 1.7), pos, m_ply)
	board.set_meta("board", true)
	board.set_meta("prompt", "Read notice board")
	_box(Vector3(0.01, 1.05, 1.25), pos + Vector3(0.03, 0, 0), Mat.solid(Color(0.86, 0.82, 0.7), 0.9), false)
	var txt := "RULES OF THE BUILDING\n"
	for r in _rules:
		txt += "\n• " + str(r.text)
	var l := _label(txt, pos + Vector3(0.037, 0, 0), -1, Color(0.08, 0.07, 0.06), 20)
	l.shaded = true
	l.width = 300; l.autowrap_mode = TextServer.AUTOWRAP_WORD
	for r in _rules:
		if r.get("night", false):
			var lie := _label("✗  " + str(r.text) + "  — A LIE", pos + Vector3(0.045, -0.72, 0), -1, Color(1, 0.15, 0.1), 22)
			lie.layers = 2

## Godrej-style steel almirah you can hide in.
func _almirah(base: Vector3) -> void:
	var cup := _box(Vector3(0.6, 2.0, 0.95), base + Vector3(0, 1.0, 0), m_metal)
	cup.set_meta("hide", true)
	cup.set_meta("prompt", "Hide in almirah")
	var fx := base.x - 0.305
	_box(Vector3(0.01, 1.9, 0.012), Vector3(fx, base.y + 1.0, base.z), Mat.solid(Color(0.05, 0.05, 0.05), 0.6), false)
	_box(Vector3(0.03, 0.18, 0.025), Vector3(fx - 0.01, base.y + 1.05, base.z + 0.06), m_brass, false)
	for k in 3:   # vent slats you peek through
		_box(Vector3(0.012, 0.02, 0.3), Vector3(fx, base.y + 1.5 + k * 0.05, base.z - 0.24), Mat.solid(Color(0.02, 0.02, 0.02), 0.6), false)
	hide_spot = Node3D.new()
	hide_spot.position = Vector3(base.x, 0.0, base.z)
	hide_spot.rotation.y = 0.0
	_target.add_child(hide_spot)

func _figure(pos: Vector3) -> Node3D:
	var f := Node3D.new()
	f.position = pos
	_target.add_child(f)
	var C := preload("res://scripts/world/characters.gd")
	var who: Node3D = C.spawn("Construction_Male_02", {"idle": "m_idle_neutral_01"}, {"height": 2.08, "tint": Color(0.1, 0.1, 0.11)})
	if who:
		who.rotation.y = PI
		f.add_child(who)
		C.play(who, "idle", 0.35)          # barely breathing
		return f
	var coat := Mat.solid(Color(0.025, 0.025, 0.028), 0.95)
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new(); cm.radius = 0.27; cm.height = 1.95
	body.mesh = cm; body.position.y = 0.98; body.material_override = coat
	body.scale = Vector3(1.0, 1.0, 0.7)
	f.add_child(body)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new(); hm.radius = 0.13; hm.height = 0.3
	head.mesh = hm; head.position.y = 2.02; head.material_override = coat
	f.add_child(head)
	var helmet := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.17; sm.height = 0.17; sm.is_hemisphere = true
	helmet.mesh = sm; helmet.position.y = 2.08
	helmet.material_override = Mat.solid(Color(0.55, 0.42, 0.08), 0.85)
	f.add_child(helmet)
	var brim := MeshInstance3D.new()
	var bm := CylinderMesh.new(); bm.top_radius = 0.21; bm.bottom_radius = 0.21; bm.height = 0.015
	brim.mesh = bm; brim.position.y = 2.08
	brim.material_override = helmet.material_override
	f.add_child(brim)
	return f

func _stain(pos: Vector3, size: Vector3) -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0.16, 0.01, 0.01, 0.95)); g.set_color(1, Color(0.16, 0.01, 0.01, 0.0))
	g.add_point(0.45, Color(0.2, 0.02, 0.02, 0.8))
	var t := GradientTexture2D.new()
	t.gradient = g; t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5); t.fill_to = Vector2(0.5, 0.0)
	t.width = 64; t.height = 64
	var d := Decal.new()
	d.texture_albedo = t
	d.size = size
	d.position = pos
	d.rotation.z = PI / 2       # project along +X into the right wall
	_target.add_child(d)

func _build_room213(zc: float) -> void:
	var red := Mat.pbr("decrepit_wallpaper", 1.6, Color(0.7, 0.18, 0.15))
	_box(Vector3(3.4, 0.2, 3.0), Vector3(-HALF_W - 1.7, -0.1, zc), m_carpet)
	_box(Vector3(3.4, 0.2, 3.0), Vector3(-HALF_W - 1.7, H + 0.1, zc), m_ceiling)
	_box(Vector3(0.2, H, 3.0), Vector3(-HALF_W - 3.4, H / 2, zc), red)
	_box(Vector3(3.4, H, 0.2), Vector3(-HALF_W - 1.7, H / 2, zc + 1.5), red)
	_box(Vector3(3.4, H, 0.2), Vector3(-HALF_W - 1.7, H / 2, zc - 1.5), red)
	var bulb := SphereMesh.new(); bulb.radius = 0.06; bulb.height = 0.12
	_mesh(bulb, Vector3(-HALF_W - 1.7, 2.4, zc), Mat.emissive(Color(1, 0.15, 0.08), 4.0))
	var l := OmniLight3D.new()
	l.light_color = Color(1, 0.12, 0.06); l.light_energy = 2.2; l.omni_range = 5
	l.shadow_enabled = true
	l.position = Vector3(-HALF_W - 1.7, 2.3, zc)
	_target.add_child(l)
	var w := _label("2 1 3", Vector3(-HALF_W - 3.29, 1.6, zc), 1, Color(0.9, 0.85, 0.8), 120)
	w.shaded = true

func _chair(pos: Vector3, rot: float) -> void:
	var n := Node3D.new()
	n.position = pos; n.rotation.y = rot
	_target.add_child(n)
	if Props.available("painted_wooden_chair_01"):
		var c := Props.spawn("painted_wooden_chair_01", Vector3(0, 0.96, 0), false)
		c.rotation.y = PI
		n.add_child(c)
		return
	var legs := Mat.solid(Color(0.12, 0.12, 0.13), 0.4, 0.8)
	_child_box(n, Vector3(0.48, 0.05, 0.46), Vector3(0, 0.47, 0), m_ply)
	_child_box(n, Vector3(0.48, 0.5, 0.04), Vector3(0, 0.76, 0.21), m_ply)
	for x in [-0.21, 0.21]:
		for z in [-0.2, 0.2]:
			_child_box(n, Vector3(0.025, 0.47, 0.025), Vector3(x, 0.235, z), legs)

# ---------------------------------------------------------------- helpers

## side: -1 left wall (faces +X), 1 right wall (faces -X), 0 end wall (faces +Z), 2 start wall (faces -Z)
func _label(t: String, pos: Vector3, side: int, col: Color, size: int) -> Label3D:
	var l := Label3D.new()
	l.text = t; l.font_size = size; l.pixel_size = 0.004
	l.modulate = col; l.outline_size = 0
	l.position = pos
	match side:
		-1: l.rotation.y = PI / 2
		1: l.rotation.y = -PI / 2
		2: l.rotation.y = PI
		_: l.rotation.y = 0.0
	_target.add_child(l)
	return l

func _mesh(mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh; mi.material_override = mat; mi.position = pos
	_target.add_child(mi)
	return mi

## Box with collision (default) or visual-only. Accepts a Material or a Color.
func _box(size: Vector3, pos: Vector3, mat: Variant, collide := true) -> Node3D:
	var m: Material = mat if mat is Material else Mat.solid(mat)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = size
	mi.mesh = bm
	mi.material_override = m
	if not collide:
		mi.position = pos
		_target.add_child(mi)
		return mi
	var body := StaticBody3D.new()
	body.position = pos
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new(); sh.size = size
	cs.shape = sh
	body.add_child(cs)
	body.add_child(mi)
	_target.add_child(body)
	return body

# ---------------------------------------------------------------- placeables

func add_pickup(kind: String, pos: Vector3) -> Node3D:
	var b := StaticBody3D.new()
	b.position = pos
	_target.add_child(b)
	var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = Vector3(0.25, 0.2, 0.25)
	cs.shape = sh; b.add_child(cs)
	match kind:
		"battery":
			var cm := CylinderMesh.new(); cm.top_radius = 0.035; cm.bottom_radius = 0.035; cm.height = 0.14
			var mi := MeshInstance3D.new(); mi.mesh = cm; mi.rotation.z = PI / 2
			mi.material_override = Mat.solid(Color(0.85, 0.65, 0.05), 0.35, 0.6)
			b.add_child(mi)
		"diya":
			var dm := CylinderMesh.new(); dm.top_radius = 0.08; dm.bottom_radius = 0.05; dm.height = 0.05
			var mi := MeshInstance3D.new(); mi.mesh = dm
			mi.material_override = Mat.solid(Color(0.55, 0.26, 0.12), 0.9)
			b.add_child(mi)
		_:
			_child_box(b, Vector3(0.1, 0.03, 0.03), Vector3.ZERO, Mat.solid(Color(0.95, 0.95, 0.93), 0.95))
	# faint glint so pickups are findable in torchlight
	var glint := OmniLight3D.new()
	glint.light_energy = 0.15; glint.omni_range = 0.6; glint.light_color = Color(1, 0.9, 0.7)
	glint.position.y = 0.15
	b.add_child(glint)
	b.set_meta("pickup", kind)
	b.set_meta("prompt", "Take " + kind)
	return b

## A readable note lying on the floor or pinned to a wall.
func add_note(id: String, pos: Vector3, on_wall_side := 0) -> Node3D:
	var size := Vector3(0.21, 0.004, 0.29) if on_wall_side == 0 else Vector3(0.004, 0.29, 0.21)
	var b := _box(size, pos, Mat.solid(Color(0.88, 0.85, 0.74), 0.95))
	b.rotation.y = 0.3 if on_wall_side == 0 else 0.0
	b.set_meta("note", id)
	b.set_meta("prompt", "Read note")
	return b

func add_chalk(pos: Vector3, normal: Vector3) -> Label3D:
	var l := Label3D.new()
	l.text = "X"; l.font_size = 64; l.pixel_size = 0.004
	l.modulate = Color(0.95, 0.95, 0.92); l.shaded = true
	_target.add_child(l)
	l.global_position = pos + normal * 0.02
	if abs(normal.y) < 0.9:
		l.look_at(l.global_position - normal, Vector3.UP)
		l.rotate_object_local(Vector3.UP, PI)
	else:
		l.rotation.x = -PI / 2
	return l

func add_diya(pos: Vector3) -> Node3D:
	var n := Node3D.new()
	_target.add_child(n)
	n.global_position = Vector3(pos.x, 0.0, pos.z)
	var cm := CylinderMesh.new(); cm.top_radius = 0.08; cm.bottom_radius = 0.05; cm.height = 0.05
	var cup := MeshInstance3D.new()
	cup.mesh = cm; cup.position.y = 0.025; cup.material_override = Mat.solid(Color(0.55, 0.26, 0.12), 0.9)
	n.add_child(cup)
	var flame := MeshInstance3D.new()
	var fm := SphereMesh.new(); fm.radius = 0.015; fm.height = 0.05
	flame.mesh = fm; flame.position.y = 0.08
	flame.material_override = Mat.emissive(Color(1.0, 0.55, 0.15), 6.0)
	n.add_child(flame)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.58, 0.22); l.light_energy = 1.8; l.omni_range = 3.2
	l.light_volumetric_fog_energy = 1.5
	l.shadow_enabled = Graphics.quality >= 2
	l.position.y = 0.2
	n.add_child(l)
	# gentle flame flicker
	var tw := n.create_tween().set_loops()
	tw.tween_property(l, "light_energy", 1.4, 0.18)
	tw.tween_property(l, "light_energy", 2.0, 0.23)
	return n
