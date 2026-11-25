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

var root: Node3D
var lights: Array = []
var spots: Array = []
var m := {}

func _init(r: Node3D) -> void:
	root = r
	m.wallpaper = Mat.pbr("decrepit_wallpaper", 1.6, Color(1.0, 0.96, 0.9))
	m.paint = Mat.pbr("peeling_painted_wall", 2.5, Color(0.72, 0.8, 0.78))
	m.paint_warm = Mat.pbr("peeling_painted_wall", 2.5, Color(0.95, 0.85, 0.7))
	m.carpet = Mat.pbr("dirty_carpet", 1.8, Color(1.5, 0.95, 0.85))
	m.carpet_grey = Mat.pbr("dirty_carpet", 1.8, Color(0.75, 0.78, 0.8))
	m.mosaic = Mat.pbr("old_mosaic_floor", 1.6, Color.WHITE, 0.85)
	m.ceiling = Mat.pbr("ceiling_interior", 2.4, Color(0.9, 0.88, 0.84))
	m.concrete = Mat.pbr("concrete_floor_worn_001", 2.5, Color(0.85, 0.85, 0.82))
	m.wood = Mat.pbr("sapele_veneer", 1.1, Color(0.62, 0.42, 0.3), 0.75)
	m.trim = Mat.pbr("sapele_veneer", 0.6, Color(0.36, 0.24, 0.17), 0.8)
	m.metal = Mat.pbr("rusty_painted_metal", 1.0, Color(0.72, 0.8, 0.76), 1.0, 0.2)
	m.metal_grey = Mat.pbr("rusty_painted_metal", 1.0, Color(0.6, 0.62, 0.62), 1.0, 0.3)
	m.ply = Mat.pbr("plywood", 1.0)
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
## openings: Array of {side:"n|s|e|w", at:float, width:float, height:float}
func room(center: Vector3, w: float, d: float, h: float, wall_mat: Variant, floor_mat: Variant, ceil_mat: Variant = "ceiling", openings: Array = []) -> void:
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
		var holes := openings.filter(func(o): return o.side == side)
		holes.sort_custom(func(a, b): return a.at < b.at)
		var cursor := -length / 2
		for o in holes:
			var a: float = o.at - o.width / 2
			_wall_seg(center + off, along_x, cursor, a, h, wall_mat)
			var oh: float = o.get("height", 2.2)
			if oh < h:   # lintel
				_wall_piece(center + off, along_x, a, a + o.width, oh, h, wall_mat)
			cursor = o.at + o.width / 2
		_wall_seg(center + off, along_x, cursor, length / 2, h, wall_mat)

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
			box(Vector3(0.3, 0.012, 1.1), pos + Vector3(0, -0.006, 0), Mat.emissive(col, 3.0), false)
		"bulb":
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
	var b := box(Vector3(1.7, 1.25, 0.05), pos, m.ply)
	b.rotation.y = yaw
	b.set_meta("board", true)
	b.set_meta("prompt", "Read notice board")
	box(Vector3(1.25, 1.05, 0.01), Vector3(0, 0, 0.03), m.paper, false, b)
	var txt := "RULES OF THE BUILDING\n"
	for r in rules:
		txt += "\n• " + str(r.text)
	var l := label(txt, Vector3(0, 0, 0.037), 0.0, Color(0.08, 0.07, 0.06), 20, true, b)
	l.width = 300; l.autowrap_mode = TextServer.AUTOWRAP_WORD
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
	box(Vector3(0.13, 0.03, 0.05), Vector3(0.36, 0, 0.06), m.brass, false, d)
	box(Vector3(0.13, 0.03, 0.05), Vector3(0.36, 0, -0.06), m.brass, false, d)
	return d

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
