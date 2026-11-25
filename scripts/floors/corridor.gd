extends Node3D
## Floor 2 — THE CORRIDOR. Procedurally builds the looping corridor and
## applies at most one anomaly per pass. Geometry is placeholder greybox
## (code-built boxes) until the corridor environment kit exists.

const SLOTS := 10          # door slots per side, 4 m each
const SLOT_LEN := 4.0
const LEN := 44.0          # corridor runs z = 0 .. -44
const HALF_W := 1.6
const H := 3.0
const ROOM213_SLOT := 6    # left side, slot 6 normally labelled 214

var room213_open := false
var figure: Node3D
var knock_doors: Array = []   # [StaticBody3D] index = door id
var _mats := {}
var _rules: Array = []
var _rng := RandomNumberGenerator.new()

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
	for c in get_children():
		remove_child(c)
		c.queue_free()
	knock_doors.clear()
	figure = null
	room213_open = open_213
	_rng.seed = seed_val if seed_val != 0 else randi()

	var wall_c := Color(0.42, 0.40, 0.34)
	var floor_c := Color(0.22, 0.17, 0.13)
	# floor + ceiling (whole length incl. lobbies z=+5..-49)
	_box(Vector3(HALF_W * 2 + 0.4, 0.2, 54), Vector3(0, -0.1, -22), floor_c)
	var ceil_h := H
	_box(Vector3(HALF_W * 2 + 0.4, 0.2, 54), Vector3(0, ceil_h + 0.1, -22), Color(0.3, 0.29, 0.26))
	if anomaly == "ceiling_low":
		_box(Vector3(HALF_W * 2, 0.7, 12), Vector3(0, H - 0.35, -22), Color(0.3, 0.29, 0.26))
	# end caps
	_box(Vector3(HALF_W * 2 + 0.4, H, 0.2), Vector3(0, H / 2, 5), wall_c)
	_box(Vector3(HALF_W * 2 + 0.4, H, 0.2), Vector3(0, H / 2, -49), wall_c)
	# lobby side walls
	for side in [-1, 1]:
		_box(Vector3(0.2, H, 5), Vector3(side * HALF_W, H / 2, 2.5), wall_c)
		_box(Vector3(0.2, H, 5), Vector3(side * HALF_W, H / 2, -46.5), wall_c)
		_box(Vector3(0.2, H, 4), Vector3(side * HALF_W, H / 2, -42), wall_c)

	# walls + doors per slot
	var nums := door_numbers()
	var wrong_door := _rng.randi_range(0, SLOTS * 2 - 1)
	var ajar_door := _rng.randi_range(0, SLOTS * 2 - 1)
	for i in SLOTS:
		var zc := -SLOT_LEN * i - SLOT_LEN / 2
		for s in 2:
			var side := -1 if s == 0 else 1
			var idx := i * 2 + s
			var is213 := side == -1 and i == ROOM213_SLOT
			if is213 and open_213:
				# split wall around an open doorway
				_box(Vector3(0.2, H, 1.5), Vector3(side * HALF_W, H / 2, zc + 1.25), wall_c)
				_box(Vector3(0.2, H, 1.5), Vector3(side * HALF_W, H / 2, zc - 1.25), wall_c)
				_box(Vector3(0.2, 0.9, 1.0), Vector3(side * HALF_W, H - 0.45, zc), wall_c)
				_build_room213(zc)
				_label("213", Vector3(side * (HALF_W - 0.12), 2.35, zc), side, Color(0.9, 0.1, 0.1), 48)
				knock_doors.append(null)
				continue
			_box(Vector3(0.2, H, SLOT_LEN), Vector3(side * HALF_W, H / 2, zc), wall_c)
			var door := _box(Vector3(0.08, 2.1, 1.0), Vector3(side * (HALF_W - 0.12), 1.05, zc), Color(0.25, 0.14, 0.08))
			door.set_meta("door_index", idx)
			door.set_meta("prompt", "Door")
			if anomaly == "door_ajar" and idx == ajar_door:
				door.rotation.y = deg_to_rad(28) * side
				door.position.z += 0.25
			knock_doors.append(door)
			var num := str(nums[idx])
			if anomaly == "door_number" and idx == wrong_door:
				num = num.reverse() if num.reverse() != num else str(nums[idx] + 50)
			_label(num, Vector3(side * (HALF_W - 0.17), 2.35, zc), side, Color(0.85, 0.75, 0.4), 40)

	# ceiling lights every other slot + lobbies
	var light_zs := [2.5, -2.0, -10.0, -18.0, -26.0, -34.0, -42.0, -46.5]
	var victim := _rng.randi_range(1, 5)
	for li in light_zs.size():
		if anomaly == "light_missing" and li == victim:
			continue
		var col := Color(1.0, 0.85, 0.6)
		if anomaly == "light_red" and li == victim:
			col = Color(1, 0.08, 0.05)
		var lamp := _box(Vector3(0.5, 0.05, 0.5), Vector3(0, ceil_h - 0.03, light_zs[li]), col, false, true)
		var l := OmniLight3D.new()
		l.light_color = col
		l.light_energy = 1.1
		l.omni_range = 6.5
		l.position = lamp.position + Vector3(0, -0.3, 0)
		add_child(l)

	# paintings at slot boundaries
	var paintings := [[2, -1, Color(0.15, 0.45, 0.45)], [5, 1, Color(0.6, 0.45, 0.15)], [8, -1, Color(0.45, 0.1, 0.12)]]
	for p in paintings:
		var c: Color = p[2]
		if anomaly == "painting_color" and p[0] == 5:
			c = Color(0.1, 0.12, 0.5)
		var x: float = p[1] * (HALF_W - 0.12)
		_box(Vector3(0.05, 0.85, 1.05), Vector3(x, 1.6, -p[0] * SLOT_LEN), Color(0.12, 0.08, 0.04))
		_box(Vector3(0.06, 0.65, 0.85), Vector3(x - p[1] * 0.01, 1.6, -p[0] * SLOT_LEN), c)

	# props
	if anomaly == "chair_moved":
		_chair(Vector3(0, 0, -24), PI)
	else:
		_chair(Vector3(1.2, 0, -14), -PI / 2)
	_box(Vector3(0.5, 0.8, 0.5), Vector3(1.3, 0.4, -30), Color(0.3, 0.2, 0.12))  # side table
	if anomaly != "vase_missing":
		_box(Vector3(0.2, 0.4, 0.2), Vector3(1.3, 1.0, -30), Color(0.2, 0.35, 0.55))
	if anomaly != "extinguisher_missing":
		_box(Vector3(0.18, 0.55, 0.18), Vector3(-1.4, 0.6, -18), Color(0.7, 0.05, 0.05))
	if anomaly == "extra_phone":
		_box(Vector3(0.3, 0.15, 0.25), Vector3(-0.4, 0.075, -20), Color(0.05, 0.05, 0.05))
	if anomaly == "stains":
		for k in 5:
			_box(Vector3(0.02, 0.18, 0.14), Vector3(HALF_W - 0.11, 1.0 + k * 0.25, -21.0 - k * 0.4), Color(0.18, 0.02, 0.02), false)
	if anomaly == "figure":
		figure = Node3D.new()
		figure.position = Vector3(0.4, 0, -41)
		add_child(figure)
		var body := MeshInstance3D.new()
		var cm := CapsuleMesh.new(); cm.radius = 0.28; cm.height = 2.1
		body.mesh = cm; body.position.y = 1.05
		body.material_override = _mat(Color(0.02, 0.02, 0.02))
		figure.add_child(body)
		var helmet := MeshInstance3D.new()
		var sm := SphereMesh.new(); sm.radius = 0.2; sm.height = 0.2
		helmet.mesh = sm; helmet.position.y = 2.05
		helmet.material_override = _mat(Color(0.55, 0.45, 0.1))
		figure.add_child(helmet)

	# start lobby: rule board + tally
	var board := _box(Vector3(0.06, 1.2, 1.6), Vector3(-HALF_W + 0.13, 1.5, 2.5), Color(0.3, 0.22, 0.12))
	board.set_meta("board", true)
	board.set_meta("prompt", "Read notice board")
	var txt := "RULES OF THE BUILDING\n"
	for r in _rules:
		txt += "\n• " + str(r.text)
	_label(txt, Vector3(-HALF_W + 0.17, 1.5, 2.5), -1, Color(0.95, 0.92, 0.8), 18)
	var tally := ""
	for k in streak:
		tally += "|" if (k + 1) % 5 != 0 else "\\ "
	_label(tally if tally != "" else " ", Vector3(HALF_W - 0.12, 1.6, 2.0), 1, Color(0.95, 0.95, 0.95), 64)
	# end lobby sign and clue
	_label("STAIRS ▲  FLOOR 3", Vector3(0, 2.4, -48.88), 0, Color(0.2, 0.9, 0.3), 36)
	if streak >= 4:
		_label("213 IS REAL", Vector3(0.3, 1.2, -48.88), 0, Color(0.9, 0.9, 0.9), 44)

func _build_room213(zc: float) -> void:
	var red := Color(0.35, 0.05, 0.05)
	_box(Vector3(3.4, 0.2, 3.0), Vector3(-HALF_W - 1.7, -0.1, zc), red)
	_box(Vector3(3.4, 0.2, 3.0), Vector3(-HALF_W - 1.7, H + 0.1, zc), red)
	_box(Vector3(0.2, H, 3.0), Vector3(-HALF_W - 3.4, H / 2, zc), red)
	_box(Vector3(3.4, H, 0.2), Vector3(-HALF_W - 1.7, H / 2, zc + 1.5), red)
	_box(Vector3(3.4, H, 0.2), Vector3(-HALF_W - 1.7, H / 2, zc - 1.5), red)
	var l := OmniLight3D.new()
	l.light_color = Color(1, 0.1, 0.05); l.light_energy = 2.5; l.omni_range = 5
	l.position = Vector3(-HALF_W - 1.7, 2.2, zc)
	add_child(l)

func _chair(pos: Vector3, rot: float) -> void:
	var n := Node3D.new()
	n.position = pos; n.rotation.y = rot
	add_child(n)
	var c := Color(0.2, 0.2, 0.22)
	var seat := _box(Vector3(0.5, 0.06, 0.5), Vector3(0, 0.48, 0), c)
	seat.reparent(n, false)
	var back := _box(Vector3(0.5, 0.55, 0.06), Vector3(0, 0.78, 0.22), c)
	back.reparent(n, false)
	for x in [-0.2, 0.2]:
		for z in [-0.2, 0.2]:
			_box(Vector3(0.04, 0.46, 0.04), Vector3(x, 0.23, z), c, false).reparent(n, false)

## side: -1 left wall (faces +X), 1 right wall (faces -X), 0 end wall (faces +Z)
func _label(t: String, pos: Vector3, side: int, col: Color, size: int) -> Label3D:
	var l := Label3D.new()
	l.text = t; l.font_size = size; l.pixel_size = 0.004
	l.modulate = col; l.outline_size = 0
	l.position = pos
	l.rotation.y = 0.0 if side == 0 else (PI / 2 if side == -1 else -PI / 2)
	add_child(l)
	return l

func _mat(c: Color, emissive := false) -> StandardMaterial3D:
	var key := str(c) + str(emissive)
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.9
		if emissive:
			m.emission_enabled = true; m.emission = c; m.emission_energy_multiplier = 2.0
		_mats[key] = m
	return _mats[key]

func _box(size: Vector3, pos: Vector3, c: Color, collide := true, emissive := false) -> Node3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c, emissive)
	if not collide:
		mi.position = pos
		add_child(mi)
		return mi
	var body := StaticBody3D.new()
	body.position = pos
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new(); sh.size = size
	cs.shape = sh
	body.add_child(cs)
	body.add_child(mi)
	add_child(body)
	return body
