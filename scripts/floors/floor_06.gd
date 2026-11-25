extends FloorBase
## FLOOR 6 — THE INVERSION. The building has turned over: you walk on the
## ceiling, desks hang above you, the stairs lead "down". The rule board is
## mirrored (the phone camera flips it). Your shadow repeats your movements
## SHADOW_DELAY seconds late — use it to hold pressure plates (plate pair B
## needs you to run). Then it stops copying and hunts you: lure it into the
## mirror room and pull the lever. Lethal.

const SHADOW_DELAY := 3.0
const PLATE_R := 0.8
const HUNT_SPEED := 2.3
const H := 3.2

var kit: Kit
var shadow: Node3D
var _trail: Array = []           # [time, pos, yaw]
var _t := 0.0
var plates := {}                 # name -> {pos, mesh, lit}
var door_a: Node3D
var door_b: Node3D
var a_open := false
var b_open := false
var hunting := false
var trapped := false
var mirror_doors: Array = []
var _lever_cool := 0.0

func _ready() -> void:
	load_floor_data(6)
	kit = Kit.new(self)
	_build()
	setup_common()
	spawn = Vector3(0, 0.05, 9.0)
	_make_shadow()
	begin_floor()
	if GameState.solved_floor(6):
		a_open = true; b_open = true; trapped = true
		kit.open_door(door_a); kit.open_door(door_b)
		shadow.visible = false
		unlock_exit("")

func _build() -> void:
	var floor_m: Material = kit.m.ceiling        # you walk on the ceiling
	var over_m: Material = kit.m.carpet          # the carpet is above you
	# a long hall of rooms from z 11 to z -22 (x -6..6)
	kit.box(Vector3(12.4, 0.2, 33.4), Vector3(0, -0.1, -5.5), floor_m)
	kit.box(Vector3(12.4, 0.2, 33.4), Vector3(0, H + 0.1, -5.5), over_m)
	kit.box(Vector3(0.2, H, 33.4), Vector3(-6.1, H / 2, -5.5), kit.m.wallpaper)
	kit.box(Vector3(0.2, H, 33.4), Vector3(6.1, H / 2, -5.5), kit.m.wallpaper)
	kit.box(Vector3(12.4, H, 0.2), Vector3(0, H / 2, 11.1), kit.m.wallpaper)
	kit.box(Vector3(12.4, H, 0.2), Vector3(0, H / 2, -22.1), kit.m.wallpaper)
	# partition walls with doors: z=4 (open arch), z=-4 (door A), z=-12 (door B)
	_partition(4.0, null)
	door_a = _partition(-4.0, "A")
	door_b = _partition(-12.0, "B")
	# lights embedded in the floor, shining up
	for z in [8.0, 1.0, -6.0, -10.0, -15.0, -20.0]:
		kit.box(Vector3(0.3, 0.015, 1.1), Vector3(0, 0.008, z), Mat_glow(), false)
		var l := OmniLight3D.new(); l.position = Vector3(0, 0.35, z)
		l.light_color = Color(0.85, 0.92, 1.0); l.light_energy = 1.0; l.omni_range = 6.5
		l.light_volumetric_fog_energy = 0.8
		add_child(l); kit.lights.append(l)
	# desks and chairs hanging upside-down from the carpet above
	for p in [Vector3(-3.5, 0, 7), Vector3(3.5, 0, 6), Vector3(-4, 0, -1), Vector3(4, 0, 1.5), Vector3(-3.5, 0, -9.5), Vector3(4, 0, -7)]:
		var dsk: Node3D = kit.desk(p, randf() * 0.4, false)
		dsk.rotation.z = PI; dsk.position.y = H
		var ch: Node3D = kit.chair(p + Vector3(0.2, 0, 0.7), 0.0)
		ch.rotation.z = PI; ch.position.y = H
	# mirrored rule board + note
	kit.board(Vector3(-5.97, 1.4, 7.0), PI / 2, rules.rules, true)
	kit.note("i_child", Vector3(1.0, 0.006, 7.5))
	# plates: A pair (walk), B pair across a glass partition (run)
	_plate("a1", Vector3(-2.5, 0, 0.0)); _plate("a2", Vector3(2.5, 0, 0.0))
	_plate("b1", Vector3(-3.0, 0, -8.0)); _plate("b2", Vector3(3.0, 0, -8.0))
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.6, 0.7, 0.75, 0.2); glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	kit.box(Vector3(0.08, H, 5.0), Vector3(0, H / 2, -7.5), glass)   # z -5..-10; go round its end at -10..-12
	# mirror room (x -2..2, z -14..-18) with an entrance and an exit door frame
	var mirror := StandardMaterial3D.new()
	mirror.albedo_color = Color(0.9, 0.92, 0.95); mirror.metallic = 1.0; mirror.roughness = 0.02
	for x in [-2.0, 2.0]:
		kit.box(Vector3(0.1, H, 4.0), Vector3(x, H / 2, -16.0), mirror)
	for z in [-14.0, -18.0]:
		kit.box(Vector3(1.4, H, 0.1), Vector3(-1.4 + 0.0, H / 2, z), mirror)
		kit.box(Vector3(1.4, H, 0.1), Vector3(1.4, H / 2, z), mirror)
		kit.box(Vector3(1.4, H - 2.2, 0.1), Vector3(0, 2.2 + (H - 2.2) / 2, z), mirror)
		var md: Node3D = kit.box(Vector3(1.4, 2.2, 0.1), Vector3(0, 1.1, z), mirror)
		md.visible = false
		(md.get_child(0) as CollisionShape3D).disabled = true
		mirror_doors.append(md)
	var probe := ReflectionProbe.new()
	probe.size = Vector3(4, H, 4); probe.position = Vector3(0, H / 2, -16)
	probe.update_mode = ReflectionProbe.UPDATE_ALWAYS if Graphics.quality >= 3 else ReflectionProbe.UPDATE_ONCE
	add_child(probe)
	var lever: Node3D = kit.box(Vector3(0.15, 0.5, 0.15), Vector3(2.6, 1.1, -19.2), kit.m.metal)
	lever.set_meta("use", "lever"); lever.set_meta("prompt", "Pull the lever (shuts the mirror room)")
	kit.stair_exit(Vector3(0, 0, -21.95), 0.0, "STAIRS ▼  7")
	exit_hint = "It won't open while your shadow is free."

## A partition wall across the hall with a central doorway; returns the door (or null).
func _partition(z: float, door_id: Variant) -> Node3D:
	kit.box(Vector3(5.4, H, 0.2), Vector3(-3.3, H / 2, z), kit.m.wallpaper)
	kit.box(Vector3(5.4, H, 0.2), Vector3(3.3, H / 2, z), kit.m.wallpaper)
	kit.box(Vector3(1.2, H - 2.2, 0.2), Vector3(0, 2.2 + (H - 2.2) / 2, z), kit.m.wallpaper)
	if door_id == null:
		return null
	var d: Node3D = kit.box(Vector3(1.2, 2.2, 0.12), Vector3(0, 1.1, z), kit.m.metal)
	d.set_meta("prompt", "Sealed. Two plates must be held at once.")
	d.set_meta("dynamic", true)
	return d

func _plate(id: String, p: Vector3) -> void:
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.3, 0.3, 0.32); m.metallic = 0.6
	m.emission_enabled = true; m.emission = Color(0.1, 0.6, 1.0); m.emission_energy_multiplier = 0.0
	kit.box(Vector3(1.2, 0.05, 1.2), p + Vector3(0, 0.025, 0), m, false)
	plates[id] = {"pos": p, "mat": m, "lit": false}

func Mat_glow() -> Material:
	return preload("res://scripts/systems/mat_lib.gd").emissive(Color(0.85, 0.92, 1.0), 3.0)

func _make_shadow() -> void:
	shadow = Node3D.new(); add_child(shadow)
	shadow.set_meta("dynamic", true)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0, 0, 0, 0.82); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var C := preload("res://scripts/world/characters.gd")
	_shadow_body = C.spawn("Male_Adult_03", {"idle": "m_idle_neutral_01", "walk": "m_walk_neutral_01", "run": "m_run_neutral"}, {"height": 1.75})
	if _shadow_body:
		_shadow_body.rotation.y = PI
		for mi in _shadow_body.find_children("*", "MeshInstance3D", true, false):
			for s in (mi as MeshInstance3D).mesh.get_surface_count():
				(mi as MeshInstance3D).set_surface_override_material(s, m)
		shadow.add_child(_shadow_body)
	else:
		var body := CapsuleMesh.new(); body.radius = 0.28; body.height = 1.75
		kit.mesh(body, Vector3(0, 0.88, 0), m, shadow)
		var head := SphereMesh.new(); head.radius = 0.13; head.height = 0.26
		kit.mesh(head, Vector3(0, 1.72, 0), m, shadow)
	shadow.global_position = spawn

var _shadow_body: Node3D
var _shadow_last := Vector3.ZERO

func _animate_shadow(d: float) -> void:
	if _shadow_body == null or d <= 0.0:
		return
	var v := (shadow.global_position - _shadow_last).length() / d
	_shadow_last = shadow.global_position
	var C := preload("res://scripts/world/characters.gd")
	if v < 0.2:
		C.play(_shadow_body, "idle")
	elif v > 3.0:
		C.play(_shadow_body, "run", clamp(v / 3.6, 0.7, 1.5))
	else:
		C.play(_shadow_body, "walk", clamp(v / 1.4, 0.6, 2.0))

# ---------------------------------------------------------------- logic
## Where the shadow is (SHADOW_DELAY seconds behind the player).
func _shadow_sample() -> Array:
	var target := _t - SHADOW_DELAY
	if _trail.is_empty() or _trail[0][0] > target:
		return [spawn, 0.0]
	while _trail.size() > 1 and _trail[1][0] <= target:
		_trail.pop_front()
	return [_trail[0][1], _trail[0][2]]

func occupied(id: String) -> bool:
	var p: Vector3 = plates[id].pos
	var on_p := Vector2(player.global_position.x - p.x, player.global_position.z - p.z).length() < PLATE_R
	var on_s := shadow.visible and Vector2(shadow.global_position.x - p.x, shadow.global_position.z - p.z).length() < PLATE_R
	return on_p or on_s

func _update_plates() -> void:
	for id in plates:
		var lit := occupied(id)
		plates[id].mat.emission_energy_multiplier = 2.5 if lit else 0.0
	if not a_open and occupied("a1") and occupied("a2"):
		a_open = true
		kit.open_door(door_a)
		subtitle("(both plates sink — the first door grinds open)", 3)
	if a_open and not b_open and occupied("b1") and occupied("b2"):
		b_open = true
		kit.open_door(door_b)
		subtitle("(the second door opens. Behind you, your shadow stops moving.)", 4)
		_start_hunt()

func _start_hunt() -> void:
	hunting = true
	Dread.add(15)
	hud.glitch(0.8)
	var tw := create_tween()
	tw.tween_property(shadow, "scale", Vector3(1.08, 1.12, 1.08), 0.6)

func in_mirror_room(p: Vector3) -> bool:
	return absf(p.x) < 1.95 and p.z < -14.05 and p.z > -17.95

func on_use(id: String, _node: Node3D) -> void:
	if id == "lever":
		pull_lever()

func pull_lever() -> bool:
	if trapped or _lever_cool > 0.0:
		return false
	for d in mirror_doors:
		d.visible = true
		(d.get_child(0) as CollisionShape3D).disabled = false
	play_at("slam", Vector3(0, 1.2, -16))
	if hunting and in_mirror_room(shadow.global_position) and not in_mirror_room(player.global_position):
		trapped = true
		hunting = false
		hud.message("The mirror doors slam shut. In every mirror, your shadow presses its hands against the glass.", 5)
		unlock_exit("")
		GameState.save_game()
		return true
	hud.message("The doors slam — on nothing. They grind back open.", 3)
	_lever_cool = 3.0
	get_tree().create_timer(3.0, false).timeout.connect(func():
		for d in mirror_doors:
			d.visible = false
			(d.get_child(0) as CollisionShape3D).disabled = true)
	return false

func show_rules(extra := "") -> void:
	if player.phone_up:
		super.show_rules("\n\n(Through the camera, the backwards writing reads the right way round.)")
	else:
		var s := ""
		for r in rules.get("rules", []):
			s += "\n•  " + str(r.text).reverse()
		hud.show_panel("GNIDLIUB EHT FO SELUR\n" + s + "\n\n(It's all backwards. Something that flips an image might help.)\n\n[E] close")

func floor_lights() -> Array: return kit.lights
func surface_at(_p: Vector3) -> String: return "tile"

func _process(d: float) -> void:
	super._process(d)
	_t += d
	_lever_cool = max(0.0, _lever_cool - d)
	# the floor sways a little: gravity can't be trusted here
	player.cam.rotation.z = sin(_t * 0.4) * 0.025
	if finished or busy or trapped:
		return
	_animate_shadow(d)
	if not hunting:
		_trail.append([_t, player.global_position, player.rotation.y])
		var s := _shadow_sample()
		shadow.global_position = s[0]
		shadow.rotation.y = s[1]
		_update_plates()
	else:
		var to := player.global_position - shadow.global_position; to.y = 0
		if to.length() < 0.7:
			die("Your shadow caught up with you.")
			return
		shadow.global_position += to.normalized() * HUNT_SPEED * d
		shadow.rotation.y = atan2(-to.x, -to.z)
