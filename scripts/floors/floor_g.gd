extends FloorBase
## FLOOR G — RECEPTION. Tutorial: move, look, interact, collect, torch,
## documents, the rule board. Sign the register (true rule) to unlock the
## security booth; the key cabinet code is the frozen clock's time (3:33).
## Calling the lift (true rule) sends you back to the entrance, changed.
## Answering the phone (incomplete rule) costs dread but gives a hint.

const CODE := "333"

var kit: Kit
var booth_door: Node3D
var lift_doors: Array = []
var signed := false
var has_key := false
var phone_answered := false
var _phone_t := 25.0
var _phone_ringing := 0.0
var _fans: Array = []
var _tutorial_step := 0

func _ready() -> void:
	load_floor_data(0)
	kit = Kit.new(self)
	_build()
	setup_common()
	kit.outside(-0.3, Vector3(-0.42, 0.35, 0), 1.3, 101)     # moon through the south windows
	director.enabled = false          # the tutorial floor is quiet
	spawn = Vector3(0, 0.05, 4.6)
	spawn_yaw = 0.0
	begin_floor()
	if GameState.solved_floor(0):
		_open_everything()
	hud.message("FLOOR G — RECEPTION\nMove: WASD · Look: mouse · Interact: E · Torch: F · Pause: Esc", 8)

func _build() -> void:
	var c := Vector3(0, 0, 0)
	kit.room(c, 14.0, 12.0, 3.6, kit.m.paint_warm, kit.m.terrazzo, kit.m.ceiling,
		[{"side": "n", "at": 1.5, "width": 1.1, "height": 2.2},
		 {"side": "s", "at": -4.2, "width": 1.6, "height": 2.6, "sill": 1.1},
		 {"side": "s", "at": 3.8, "width": 1.6, "height": 2.6, "sill": 1.1}], {"dado": "dado"})
	# bricked-up entrance behind you
	kit.box(Vector3(3.2, 2.6, 0.12), Vector3(0, 1.3, 5.92), kit.m.trim, false)
	kit.box(Vector3(3.0, 2.45, 0.1), Vector3(0, 1.25, 5.88), Mat_brick())
	kit.label("ENTRANCE", Vector3(0, 2.85, 5.85), PI, Color(0.6, 0.55, 0.45), 40)
	# reception counter with register, phone, bell
	kit.box(Vector3(4.2, 1.1, 0.8), Vector3(-3.0, 0.55, -2.0), kit.m.wood)
	kit.box(Vector3(4.3, 0.05, 0.9), Vector3(-3.0, 1.125, -2.0), kit.m.trim, false)
	for k in 17:      # slatted front, a dark toe-kick and a brass name plate
		kit.box(Vector3(0.05, 0.86, 0.018), Vector3(-5.0 + k * 0.25, 0.6, -1.592), kit.m.trim, false)
	kit.box(Vector3(4.2, 0.12, 0.02), Vector3(-3.0, 0.06, -1.59), kit.m.black, false)
	kit.box(Vector3(0.9, 0.13, 0.008), Vector3(-3.0, 0.92, -1.575), kit.m.brass, false)
	kit.label("RECEPTION", Vector3(-3.0, 0.92, -1.569), 0.0, Color(0.15, 0.1, 0.05), 22)
	kit.prop("desk_lamp_arm_01", Vector3(-4.6, 1.15, -2.15), 0.4, Vector3(0, 0.5, 0), false)
	var reg: Node3D = kit.box(Vector3(0.5, 0.04, 0.34), Vector3(-2.2, 1.17, -1.9), kit.m.paper)
	reg.set_meta("use", "register"); reg.set_meta("prompt", "Visitor register")
	kit.box(Vector3(0.02, 0.05, 0.34), Vector3(-2.2, 1.18, -1.9), kit.m.trim, false)
	var phone: Node3D = kit.box(Vector3(0.24, 0.1, 0.2), Vector3(-4.2, 1.2, -1.9), kit.m.black)
	phone.set_meta("use", "phone"); phone.set_meta("prompt", "Telephone")
	kit.cyl(0.05, 0.05, Vector3(-3.2, 1.17, -1.8), kit.m.brass)
	# frozen wall clock above the counter: its hands stopped at 3:33
	kit.clock(Vector3(-3.0, 2.72, -6.0), 0.0, 3, 33, 0.34)
	kit.label("THE TIME IS ALWAYS", Vector3(-3.0, 2.24, -5.985), 0.0, Color(0.35, 0.3, 0.25), 18)
	kit.plaque("MERIDIAN TOWER", Vector3(-3.0, 3.28, -5.98), 0.0, Vector2(2.6, 0.32), kit.m.trim, Color(0.82, 0.66, 0.36), 44)
	# lift on the east wall, indicator stuck on 8
	for k in 2:
		var dd: Node3D = kit.box(Vector3(0.08, 2.3, 0.6), Vector3(6.92, 1.15, -2.3 + k * 0.6), kit.m.metal_grey)
		lift_doors.append(dd)
	var lift_btn: Node3D = kit.box(Vector3(0.1, 0.3, 0.2), Vector3(6.93, 1.3, -0.95), kit.m.metal_grey)
	lift_btn.set_meta("use", "lift"); lift_btn.set_meta("prompt", "Call the lift")
	kit.box(Vector3(0.05, 0.25, 0.4), Vector3(6.94, 2.65, -2.0), Mat_emit(Color(1, 0.1, 0.05)), false)
	kit.label("8", Vector3(6.9, 2.65, -2.0), -PI / 2, Color(1, 0.2, 0.1), 60, false)
	kit.label("LIFT", Vector3(6.9, 2.95, -2.0), -PI / 2, Color(0.6, 0.55, 0.45), 30)
	# brushed-steel lift surround and a floor directory beside it
	for z in [-2.68, -1.32]:
		kit.box(Vector3(0.06, 2.45, 0.12), Vector3(6.94, 1.225, z), kit.m.chrome, false)
	kit.box(Vector3(0.06, 0.12, 1.48), Vector3(6.94, 2.4, -2.0), kit.m.chrome, false)
	kit.plaque("MERIDIAN TOWER  ·  DIRECTORY\n\n9   ———\n8   ROOF  /  WATER TANK\n7   (UNDER CONSTRUCTION)\n6   MERIDIAN CONSULTANTS\n5   SITE OPERATIONS\n4   RESIDENCE — DESAI\n3   RECORDS & ARCHIVE\n2   GUEST CORRIDOR 201–221\n1   SITE OFFICE\nG   RECEPTION  ·  SECURITY",
		Vector3(6.96, 1.62, 1.1), -PI / 2, Vector2(1.1, 1.3), kit.m.black, Color(0.85, 0.82, 0.7), 15)
	# security booth in the north-east corner (x 3..7, z -6..-2.6)
	# west wall with a door gap at z -3.8..-2.8
	kit.box(Vector3(0.15, 3.6, 2.2), Vector3(3.0, 1.8, -4.9), kit.m.paint_warm)
	kit.box(Vector3(0.15, 3.6, 0.2), Vector3(3.0, 1.8, -2.7), kit.m.paint_warm)
	kit.box(Vector3(0.15, 1.4, 1.0), Vector3(3.0, 2.9, -3.3), kit.m.paint_warm)
	# south wall with a glass window (x 3.3..5.9, y 1.1..2.1)
	kit.box(Vector3(4.0, 1.1, 0.15), Vector3(5.0, 0.55, -2.6), kit.m.paint_warm)
	kit.box(Vector3(4.0, 1.5, 0.15), Vector3(5.0, 2.85, -2.6), kit.m.paint_warm)
	kit.box(Vector3(0.3, 1.0, 0.15), Vector3(3.15, 1.6, -2.6), kit.m.paint_warm)
	kit.box(Vector3(1.1, 1.0, 0.15), Vector3(6.45, 1.6, -2.6), kit.m.paint_warm)
	kit.box(Vector3(2.6, 1.0, 0.04), Vector3(4.6, 1.6, -2.6), Mat_glass())
	booth_door = kit.door(Vector3(3.0, 0, -3.3), PI / 2, "booth", "Security booth (locked)")
	for y in [1.08, 2.12]:      # booth window frame
		kit.box(Vector3(2.7, 0.06, 0.2), Vector3(4.6, y, -2.6), kit.m.trim, false)
	kit.plaque("SECURITY", Vector3(2.92, 2.45, -3.3), -PI / 2, Vector2(0.8, 0.2), Color(0.12, 0.2, 0.45), Color(0.9, 0.9, 0.85), 26)
	kit.prop("vintage_radio_transceiver", Vector3(4.95, 0.79, -5.65), 0.3, Vector3(0.45, 0, 0), false)
	if kit.prop("metal_office_desk", Vector3(5.6, 0, -5.5), 0.0, Vector3(1.4, 0.79, 0.7)) == null:
		kit.box(Vector3(1.2, 0.75, 0.6), Vector3(5.6, 0.375, -5.5), kit.m.wood)          # guard desk
	var cab: Node3D = kit.box(Vector3(0.5, 0.6, 0.15), Vector3(6.85, 1.5, -4.6), kit.m.metal)
	cab.rotation.y = -PI / 2
	cab.set_meta("use", "cabinet"); cab.set_meta("prompt", "Key cabinet (3-digit lock)")
	kit.note("g_guard", Vector3(5.5, 0.8, -5.4))
	kit.chair(Vector3(5.6, 0, -4.8), PI)
	# lobby furniture: sofa, plants, ceiling fans, notice board
	if kit.prop("Sofa_01", Vector3(4.0, 0, 3.75), PI, Vector3(2.1, 0, 0)) == null:
		kit.box(Vector3(2.2, 0.45, 0.8), Vector3(4.0, 0.225, 3.6), kit.m.cloth)
		kit.box(Vector3(2.2, 0.6, 0.2), Vector3(4.0, 0.6, 4.0), kit.m.cloth)
	kit.prop("WetFloorSign_01", Vector3(6.1, 0, -0.2), -0.6)
	kit.prop("security_camera_01", Vector3(-6.75, 3.25, 5.75), PI * 0.75, Vector3.ZERO, false)
	kit.prop("fire_alarm", Vector3(-6.97, 1.5, -3.5), PI / 2, Vector3.ZERO, false)
	kit.prop("vintage_telephone_wall_clock", Vector3(-6.88, 1.65, 4.6), PI / 2, Vector3.ZERO, false)
	kit.prop("korean_fire_extinguisher_01", Vector3(-6.75, 0, -1.2), PI / 2)
	kit.prop("cardboard_box_01", Vector3(6.4, 0.17, 5.3), 0.4)
	kit.prop("cardboard_box_01", Vector3(6.3, 0.51, 5.25), 1.1)
	kit.plant(Vector3(-6.2, 0, 5.2), 2, 1.0)
	kit.plant(Vector3(-6.3, 0, -5.4), 4, 0.55)
	kit.plant(Vector3(2.6, 0, -5.55), 4, 0.5)
	# entrance mat, a janitor's corner, a picture nobody looks at
	kit.box(Vector3(2.2, 0.012, 1.0), Vector3(0, 0.006, 5.1), Color(0.07, 0.07, 0.065), false)
	kit.prop("plastic_broom", Vector3(6.75, 0, 4.3), -PI / 2, Vector3(0, 1.2, 0), false).rotation.z = 0.12
	kit.prop("trashbag", Vector3(5.6, 0, 5.4), 0.7, Vector3(0, 0.55, 0))
	kit.prop("hanging_picture_frame_02", Vector3(-6.97, 2.0, 0.4), PI / 2, Vector3(0.9, 0, 0), false)
	kit.plaque("NO SMOKING\nधूम्रपान निषेध", Vector3(-6.97, 2.0, -1.8), PI / 2, Vector2(0.45, 0.3), kit.m.paper, Color(0.6, 0.05, 0.05), 20)
	for p in [Vector3(-2.5, 3.6, 1.5), Vector3(2.5, 3.6, 1.5)]:
		_fans.append(_fan(p))
	kit.board(Vector3(-6.9, 1.6, 2.5), PI / 2, rules.rules)
	kit.note("g_wake", Vector3(0.6, 0.006, 3.8))
	kit.chair(Vector3(-5.5, 0, 1.0), 0.8); kit.chair(Vector3(-4.6, 0, 3.5), -2.3)
	# stairwell door in the north wall opening
	kit.stair_exit(Vector3(1.5, 0, -6.03), 0.0, "STAIRS ▲  1")
	exit_hint = "Locked. A key would open it — the guard kept keys in his booth."
	# the tutorial floor is the best-lit floor in the building
	# old fluorescent tubes: a cold, faintly green white against the warm walls
	kit.lamp(Vector3(-3.0, 3.6, -1.0), "tube", Color(0.86, 0.97, 0.92), 1.7, 9.0)
	kit.lamp(Vector3(3.0, 3.6, 2.5), "tube", Color(0.86, 0.97, 0.92), 1.4, 9.0)
	kit.lamp(Vector3(-4.0, 3.6, 3.5), "tube", Color(0.9, 0.95, 0.88), 1.2, 8.0)
	kit.lamp(Vector3(1.5, 3.6, -4.0), "tube", Color(0.86, 0.97, 0.92), 1.2, 8.0)

func _fan(p: Vector3) -> Node3D:
	var n := Node3D.new(); n.position = p + Vector3(0, -0.45, 0); add_child(n)
	n.set_meta("dynamic", true)
	if kit.prop("ceiling_fan", Vector3(0, 0.45, 0), 0.0, Vector3(1.3, 0, 0), false, n) != null:
		return n
	kit.cyl(0.015, 0.4, p + Vector3(0, -0.2, 0), kit.m.black)
	kit.cyl(0.12, 0.12, Vector3.ZERO, Color(0.5, 0.48, 0.42), n)
	for k in 3:
		var b := kit.box(Vector3(0.9, 0.01, 0.14), Vector3(0, 0, 0), Color(0.55, 0.5, 0.42), false, n)
		b.position = Vector3(cos(k * TAU / 3) * 0.5, -0.02, sin(k * TAU / 3) * 0.5)
		b.rotation.y = -k * TAU / 3
	return n

func Mat_brick() -> Material:
	return preload("res://scripts/systems/mat_lib.gd").pbr("concrete_floor_worn_001", 0.6, Color(0.55, 0.32, 0.25))
func Mat_emit(c: Color) -> Material:
	return preload("res://scripts/systems/mat_lib.gd").emissive(c, 3.0)
func Mat_glass() -> Material:
	var g := StandardMaterial3D.new()
	g.albedo_color = Color(0.6, 0.7, 0.7, 0.18); g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	g.roughness = 0.05; g.metallic = 0.2
	return g

# ---------------------------------------------------------------- interaction
func on_use(id: String, node: Node3D) -> void:
	match id:
		"register":
			if signed:
				hud.show_panel("VISITOR REGISTER — MERIDIAN TOWER\n\n14/06/1998   03:33   ARJUN DESAI   — purpose: \"to see Papa\"\n%s   03:33   ARJUN DESAI   — purpose: \"to go up\"\n\n[E] close" % Time.get_date_string_from_system())
				return
			signed = true
			Dread.add(6)
			hud.show_panel("VISITOR REGISTER — MERIDIAN TOWER\n\nThe last entry is already yours:\n\n14/06/1998   03:33   ARJUN DESAI   — purpose: \"to see Papa\"\n\nYou were nine in 1998.\nYou sign beneath it anyway.\n\n[E] close")
			unlock_booth()
		"booth":
			if not signed:
				hud.message("Locked. A sign on the glass: VISITORS MUST SIGN THE REGISTER.", 3)
		"cabinet":
			if has_key:
				hud.message("Empty.", 1.5); return
			var code: String = await hud.ask_code("KEY CABINET", 3)
			try_cabinet(code)
		"phone":
			answer_phone()
		"lift":
			fall_down("You called the lift. The doors opened onto nothing, and something in the dark breathed in.")

func unlock_booth() -> void:
	if booth_door.get_meta("opened", false):
		return
	kit.open_door(booth_door)
	subtitle("(BZZT — the security booth door unlocks)", 3)

func try_cabinet(code: String) -> bool:
	if code == "":
		return false
	if code != CODE:
		hud.message("The lock doesn't move.", 2)
		return false
	has_key = true
	GameState.collectibles.append("g_stair_key")
	hud.message("Click. Inside, one key on a ring: STAIRWELL.\nThe stairs are in the north wall.", 4)
	unlock_exit("")
	return true

func answer_phone() -> void:
	_phone_ringing = 0.0
	if phone_answered:
		hud.message("Dial tone. Then, very faintly, breathing.", 2.5)
		Dread.add(4)
		return
	phone_answered = true
	Dread.add(10)
	hud.glitch(0.4)
	hud.message("A voice, very close to the receiver:\n\"Arjun.\"\n\"…look at the time, beta. It never moved.\"", 6)

func _open_everything() -> void:
	signed = true
	has_key = true
	unlock_booth()
	exit_unlocked = true

func floor_lights() -> Array: return kit.lights
func surface_at(_p: Vector3) -> String: return "tile"

# ---------------------------------------------------------------- per frame
func _process(d: float) -> void:
	super._process(d)
	for f in _fans:
		f.rotation.y += d * 1.6
	if finished or busy:
		return
	# the phone rings now and then once you've signed
	if signed and not phone_answered:
		_phone_t -= d
		if _phone_t <= 0.0:
			_phone_t = 28.0
			_phone_ringing = 6.0
			play_at("ring", Vector3(-4.2, 1.2, -1.9))
			subtitle("(the reception telephone is ringing)", 3)
	# gentle tutorial nudges
	match _tutorial_step:
		0:
			if player.global_position.distance_to(spawn) > 2.0:
				_tutorial_step = 1
				hud.message("Read the notice board on the west wall. [E]", 4)
		1:
			if signed:
				_tutorial_step = 2
				hud.message("The booth is dark. Press [F] for your torch.", 4)
		2:
			if has_key:
				_tutorial_step = 3
