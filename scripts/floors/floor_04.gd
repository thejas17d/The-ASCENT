extends FloorBase
## FLOOR 4 — THE RESIDENCE. Arjun's childhood flat, 14 June 1998.
## Three photographs and a cassette lead to the study code (his birthday,
## 1406). Papa's study is forbidden (false rule) but required: inside is the
## letter — the first major choice (keep / burn). Then dinner is at 8 (true
## rule): be seated before the clock strikes. The faceless mother must never
## be made to look at you (true rule): don't stand in front of her, close.

const STUDY_CODE := "1406"
const DINNER_GRACE := 60.0
const MOTHER_TRY := 1.5          # seconds in front of her before she tries to see
const MOTHER_RANGE := 1.9

var kit: Kit
var study_door: Node3D
var mother: Node3D
var _mother_head: Node3D
var _mother_path := [Vector3(5.2, 0, -5.9), Vector3(2.4, 0, -6.0), Vector3(0.2, 0, -5.0), Vector3(-1.9, 0, -4.3), Vector3(0.2, 0, -5.0)]
var _mother_i := 0
var _mother_wait := 2.0
var _mother_try := 0.0
var clock_label: Label3D
var minutes := 40                 # 7:40
var photos := 0
var tape_found := false
var tape_played := false
var study_open := false
var letter_done := false
var dinner_t := -1.0
var seated := false
var _cooker_t := 12.0
var tv_screen: Label3D

func _ready() -> void:
	load_floor_data(4)
	kit = Kit.new(self)
	_build()
	setup_common()
	director.enabled = false          # this floor's horror is quiet and domestic
	spawn = Vector3(4.0, 0.05, 1.0)
	begin_floor()
	if GameState.solved_floor(4):
		letter_done = true
		seated = true
		_open_study()
		unlock_exit("")

# ---------------------------------------------------------------- building
func _build() -> void:
	var wall: Material = kit.m.paint_warm
	kit.room(Vector3(0, 0, -5), 14.0, 14.0, 3.0, wall, kit.m.mosaic, kit.m.ceiling,
		[{"side": "s", "at": 4.0, "width": 1.1, "height": 2.2}])
	# interior walls (gaps are doorways)
	_wall_x(-3.0, -7.0, 7.0, [[-4.0, 1.4], [4.0, 1.2]])
	_wall_z(1.0, 2.0, -3.0, [[-0.5, 1.2]])
	_wall_z(-1.0, -3.0, -7.0, [[-5.0, 1.4]])
	_wall_x(-7.0, -7.0, 7.0, [[-5.5, 0.9], [-1.5, 1.0], [4.0, 1.0]])
	_wall_z(-4.0, -7.0, -12.0, [])
	_wall_z(1.0, -7.0, -12.0, [])
	# LIVING ROOM (x -7..1, z 2..-3)
	kit.box(Vector3(0.9, 0.45, 2.4), Vector3(-6.4, 0.225, -0.5), kit.m.cloth)
	kit.box(Vector3(0.25, 0.6, 2.4), Vector3(-6.8, 0.6, -0.5), kit.m.cloth)
	kit.box(Vector3(1.0, 0.5, 0.5), Vector3(-2.5, 0.25, -2.6), kit.m.wood)            # TV stand
	kit.box(Vector3(0.8, 0.62, 0.55), Vector3(-2.5, 0.81, -2.6), Color(0.15, 0.14, 0.13))
	kit.box(Vector3(0.62, 0.46, 0.01), Vector3(-2.5, 0.83, -2.32), Mat_tv(), false)
	tv_screen = kit.label("TEST SIGNAL\n· · · · ·", Vector3(-2.5, 0.83, -2.31), 0.0, Color(0.9, 0.9, 1.0), 30, false)
	tv_screen.pixel_size = 0.002
	var deck: Node3D = kit.box(Vector3(0.45, 0.12, 0.25), Vector3(-0.6, 0.62, -2.6), Color(0.12, 0.12, 0.12))
	kit.box(Vector3(0.4, 0.56, 0.4), Vector3(-0.6, 0.28, -2.6), kit.m.wood)
	deck.set_meta("use", "deck"); deck.set_meta("prompt", "Cassette player")
	clock_label = kit.label("7:40", Vector3(-4.5, 2.25, -2.88), 0.0, Color(0.1, 0.08, 0.06), 64)
	kit.cyl(0.3, 0.04, Vector3(-4.5, 2.25, -2.92), Color(0.92, 0.9, 0.82)).rotation.x = PI / 2
	kit.item("h_photo_beach", "photograph (beach)", Vector3(-6.4, 0.46, 0.4), "photo", Color(0.8, 0.75, 0.6))
	# HALL (x 1..7, z 2..-3): front door / exit, shoe rack, rule board
	kit.box(Vector3(1.2, 0.5, 0.35), Vector3(6.3, 0.25, 0.8), kit.m.wood)
	kit.board(Vector3(6.88, 1.55, -1.2), -PI / 2, rules.rules)
	kit.stair_exit(Vector3(4.0, 0, 2.03), PI, "STAIRS ▲  5")
	exit_hint = "Locked from outside. Dinner first. It's always dinner first."
	# DINING (x -7..-1, z -3..-7): table, four chairs
	kit.table(Vector3(-4.0, 0, -5.0), Vector3(2.0, 0.74, 1.0))
	kit.chair(Vector3(-5.4, 0, -5.0), -PI / 2)    # Papa (head)
	kit.chair(Vector3(-4.0, 0, -5.8), PI)         # Mummy
	var mine: Node3D = kit.chair(Vector3(-4.0, 0, -4.2), 0.0)   # Arjun
	var seat: Node3D = kit.box(Vector3(0.5, 0.5, 0.5), Vector3(-4.0, 0.25, -4.2), Color(0, 0, 0))
	seat.get_child(1).visible = false
	seat.set_meta("use", "sit"); seat.set_meta("prompt", "Your chair")
	kit.chair(Vector3(-2.6, 0, -5.0), PI / 2)
	for p in [Vector3(-4.0, 0.775, -4.6), Vector3(-4.0, 0.775, -5.4), Vector3(-4.75, 0.775, -5.0)]:
		kit.cyl(0.13, 0.01, p, Color(0.85, 0.85, 0.82))
	# KITCHEN (x -1..7, z -3..-7)
	kit.box(Vector3(6.0, 0.9, 0.6), Vector3(3.5, 0.45, -6.65), kit.m.wood)
	kit.box(Vector3(6.0, 0.04, 0.62), Vector3(3.5, 0.92, -6.65), Color(0.2, 0.22, 0.2))
	kit.box(Vector3(0.6, 0.06, 0.4), Vector3(5.2, 0.97, -6.6), kit.m.metal_grey, false)   # stove
	kit.cyl(0.14, 0.25, Vector3(5.2, 1.13, -6.6), Color(0.75, 0.75, 0.78))                 # pressure cooker
	kit.box(Vector3(0.75, 1.8, 0.7), Vector3(6.5, 0.9, -3.6), Color(0.85, 0.85, 0.8))      # fridge
	kit.note("h_list", Vector3(6.12, 1.4, -3.6), 0.0).rotation = Vector3(PI / 2, -PI / 2, 0)
	# POOJA (x -7..-4, z -7..-12)
	kit.box(Vector3(1.6, 0.9, 0.5), Vector3(-5.5, 0.45, -11.6), kit.m.wood)
	kit.box(Vector3(1.6, 1.2, 0.1), Vector3(-5.5, 1.6, -11.9), Color(0.55, 0.12, 0.08))
	for x in [-6.0, -5.5, -5.0]:
		kit.cyl(0.07, 0.25, Vector3(x, 1.03, -11.7), kit.m.brass)
	var diya := OmniLight3D.new(); diya.light_color = Color(1, 0.6, 0.25); diya.light_energy = 1.4
	diya.omni_range = 3.5; diya.position = Vector3(-5.5, 1.2, -11.4); add_child(diya)
	kit.lights.append(diya)
	kit.item("h_photo_site", "photograph (the site)", Vector3(-6.2, 0.91, -11.5), "photo", Color(0.7, 0.7, 0.65))
	# STUDY (x -4..1, z -7..-12), locked
	study_door = kit.door(Vector3(-1.5, 0, -7.0), 0.0, "study", "Papa's study (keypad)")
	kit.note("h_under_door", Vector3(-1.5, 0.006, -6.55))
	kit.desk(Vector3(-1.5, 0, -11.2), 0.0, false)
	kit.item("h_letter", "Papa's letter", Vector3(-1.4, 0.79, -11.1), "page", Color(0.92, 0.9, 0.82))
	kit.box(Vector3(0.6, 1.4, 0.5), Vector3(-3.5, 0.7, -11.6), kit.m.metal_grey)
	kit.chair(Vector3(-1.5, 0, -10.5), PI)
	# BEDROOM (x 1..7, z -7..-12)
	kit.box(Vector3(1.0, 0.45, 2.0), Vector3(6.3, 0.225, -10.6), kit.m.wood)
	kit.box(Vector3(0.95, 0.12, 1.95), Vector3(6.3, 0.51, -10.6), Color(0.35, 0.45, 0.65))
	kit.item("h_tape", "cassette tape", Vector3(5.7, 0.58, -9.9), "tape", Color(0.15, 0.15, 0.2))
	kit.box(Vector3(1.0, 0.75, 0.5), Vector3(2.0, 0.375, -11.6), kit.m.wood)
	kit.item("h_photo_birthday", "photograph (birthday)", Vector3(2.0, 0.76, -11.5), "photo", Color(0.9, 0.85, 0.7))
	# lights: warm household tubes and bulbs
	for p in [Vector3(-3.0, 3.0, -0.5), Vector3(4.0, 3.0, -0.5), Vector3(-4.0, 3.0, -5.0), Vector3(3.0, 3.0, -5.0), Vector3(-1.5, 3.0, -9.5), Vector3(4.0, 3.0, -9.5)]:
		kit.lamp(p, "tube", Color(1.0, 0.86, 0.62), 0.95, 6.5)
	_build_mother()

func _wall_x(z: float, x0: float, x1: float, gaps: Array) -> void:
	var cursor := x0
	for g in gaps:
		var a: float = g[0] - g[1] / 2.0
		_seg(Vector3((cursor + a) / 2, 0, z), Vector3(a - cursor, 0, 0.15))
		_seg(Vector3(g[0], 0, z), Vector3(g[1], 0, 0.15), 2.15)
		cursor = g[0] + g[1] / 2.0
	_seg(Vector3((cursor + x1) / 2, 0, z), Vector3(x1 - cursor, 0, 0.15))

func _wall_z(x: float, z0: float, z1: float, gaps: Array) -> void:
	# z0 > z1 (walls run from south to north)
	var cursor := z0
	for g in gaps:
		var a: float = g[0] + g[1] / 2.0
		_seg(Vector3(x, 0, (cursor + a) / 2), Vector3(0.15, 0, cursor - a))
		_seg(Vector3(x, 0, g[0]), Vector3(0.15, 0, g[1]), 2.15)
		cursor = g[0] - g[1] / 2.0
	_seg(Vector3(x, 0, (cursor + z1) / 2), Vector3(0.15, 0, cursor - z1))

## Wall segment; lintel_from > 0 builds only the part above a doorway.
func _seg(c: Vector3, s: Vector3, lintel_from := 0.0) -> void:
	var w := absf(s.x); var d := absf(s.z)
	if w < 0.01 or d < 0.01:
		return
	if lintel_from > 0.0:
		kit.box(Vector3(w, 3.0 - lintel_from, d), c + Vector3(0, (3.0 + lintel_from) / 2, 0), kit.m.paint_warm)
	else:
		kit.box(Vector3(w, 3.0, d), c + Vector3(0, 1.5, 0), kit.m.paint_warm)

func _build_mother() -> void:
	mother = Node3D.new(); add_child(mother)
	mother.position = _mother_path[0]
	var saree := Mat_solid(Color(0.55, 0.08, 0.08), 0.85)
	var skin := Mat_solid(Color(0.42, 0.3, 0.22), 0.7)
	var skirt := CylinderMesh.new(); skirt.top_radius = 0.17; skirt.bottom_radius = 0.38; skirt.height = 1.05
	kit.mesh(skirt, Vector3(0, 0.525, 0), saree, mother)
	var torso := CapsuleMesh.new(); torso.radius = 0.17; torso.height = 0.65
	kit.mesh(torso, Vector3(0, 1.25, 0), saree, mother)
	var drape := kit.box(Vector3(0.36, 0.7, 0.05), Vector3(0.05, 1.25, -0.16), Mat_solid(Color(0.75, 0.55, 0.12), 0.6), false, mother)
	drape.rotation.z = 0.35
	_mother_head = Node3D.new(); _mother_head.position = Vector3(0, 1.66, 0); mother.add_child(_mother_head)
	var head := SphereMesh.new(); head.radius = 0.11; head.height = 0.25
	kit.mesh(head, Vector3.ZERO, skin, _mother_head)               # no features. none at all.
	kit.box(Vector3(0.2, 0.42, 0.06), Vector3(0, -0.08, 0.09), Color(0.03, 0.02, 0.02), false, _mother_head)  # hair
	for x in [-0.2, 0.2]:
		var arm := CapsuleMesh.new(); arm.radius = 0.045; arm.height = 0.6
		kit.mesh(arm, Vector3(x, 1.2, 0), skin, mother)

func Mat_solid(c: Color, r: float) -> Material:
	return preload("res://scripts/systems/mat_lib.gd").solid(c, r)
func Mat_tv() -> Material:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.22, 0.3); m.emission_enabled = true
	m.emission = Color(0.35, 0.38, 0.5); m.emission_energy_multiplier = 1.5
	return m

# ---------------------------------------------------------------- story steps
func _advance(mins: int) -> void:
	minutes = min(59, minutes + mins)
	clock_label.text = "7:%02d" % minutes
	play_at("knock", Vector3(-4.5, 2.25, -2.9))   # the wall clock clunks forward

func on_item_taken(id: String, node: Node3D) -> bool:
	match id:
		"h_photo_beach":
			_photo(node, "A family at the beach — Juhu, by the look of it. Mummy laughing, Papa squinting into the sun.\nYou are on his shoulders.\nOn the back: \"Sunday. He promised more Sundays.\"")
		"h_photo_site":
			_photo(node, "Papa at the Meridian site in a yellow helmet, next to a tall man in a long coat.\nThe tall man's face has been scratched out with a pen, so hard the paper tore.\nOn the back: \"May '98 — 8 floors by June!\"")
		"h_photo_birthday":
			_photo(node, "A birthday cake with nine candles. You, blowing them out. Mummy clapping.\nPapa's chair in the background is empty.\nOn the back, in Mummy's writing: \"Arjun — 9 today! 14 · 6 · 98\"")
		"h_tape":
			tape_found = true
			node.queue_free()
			hud.message("A cassette. Papa's handwriting on the label: \"For Arjun — play me.\"", 3.5)
		"h_letter":
			node.queue_free()
			read_letter()
		_:
			return false
	return true

func _photo(node: Node3D, text: String) -> void:
	node.queue_free()
	photos += 1
	hud.show_panel(text + "\n\n[E] close")
	_advance(3)

func on_use(id: String, _node: Node3D) -> void:
	match id:
		"deck": play_tape()
		"study":
			if study_open:
				return
			var code: String = await hud.ask_code("PAPA'S STUDY", 4)
			try_study(code)
		"sit": sit()

func play_tape() -> bool:
	if not tape_found:
		hud.message("An old cassette player. Empty.", 2)
		return false
	if tape_played:
		hud.message("The tape hisses to its end.", 2)
		return false
	tape_played = true
	_advance(3)
	hud.show_panel("(click — hiss — your father's voice)\n\n\"Happy birthday, beta. If you're hearing this, I'm late again. I'm sorry.\nI promised I'd be home by eight.\n\nEverything I keep in my study is locked with the day you were born.\nI never forget that date. Even when I forget everything else.\"\n\n(the tape runs on in silence)\n\n[E] close")
	return true

func try_study(code: String) -> bool:
	if code == "":
		return false
	if code != STUDY_CODE:
		hud.message("The keypad blinks red.", 2)
		return false
	_open_study()
	_advance(3)
	subtitle("(behind you, in the kitchen, the pressure cooker stops whistling)", 3)
	return true

func _open_study() -> void:
	study_open = true
	kit.open_door(study_door)

func read_letter() -> void:
	hud.show_panel("Arjun,\n\nOn the night of your birthday I signed a report that said this building was safe. It was not.\nThe supervisor said the owner would ruin us. I told myself one more night would not matter.\nI was not home by eight. Six men did not go home at all.\n\nIf you keep this letter, someone will finally know.\nIf you burn it, you can forget. I tried. I never could.\n\n— Papa\n\n[E] continue")
	await get_tree().create_timer(0.1, false).timeout
	while hud.panel_open():
		await get_tree().process_frame
	var pick: int = await hud.ask_choice("Papa's letter.", ["Keep the letter.", "Burn it in the pooja diya."])
	choose_letter(pick == 0)

func choose_letter(keep: bool) -> void:
	letter_done = true
	GameState.choices["letter"] = "kept" if keep else "burned"
	if keep:
		GameState.collectibles.append("h_letter")
		hud.message("You fold it and keep it against your chest.", 3)
	else:
		hud.message("The paper curls in the small flame. Somewhere, a man sighs.", 3)
	GameState.save_game()
	# 7:59 — one minute to dinner
	minutes = 59
	clock_label.text = "7:59"
	dinner_t = DINNER_GRACE
	hud.message("\"Arjun! Khaana lag gaya hai — dinner's ready!\"", 4)

func sit() -> void:
	if seated:
		return
	if dinner_t < 0.0:
		hud.message("Not yet. Mummy is still cooking.", 2)
		return
	seated = true
	dinner_t = -1.0
	player.input_enabled = false
	await hud.fade_to(1.0, 1.0)
	clock_label.text = "8:00"
	hud.message("Mummy sets three plates. Papa's chair stays empty.\nNobody says anything.\nThen, behind you, the front door clicks open.", 6)
	await get_tree().create_timer(3.5, false).timeout
	player.input_enabled = true
	await hud.fade_to(0.0, 1.2)
	unlock_exit("")

# ---------------------------------------------------------------- per frame
func floor_lights() -> Array: return kit.lights
func surface_at(_p: Vector3) -> String: return "tile"

func _process(d: float) -> void:
	super._process(d)
	if finished or busy:
		return
	_update_mother(d)
	if dinner_t > 0.0:
		dinner_t -= d
		hud.set_status("7:59 — dinner in %d s   ·   Torch %d%%" % [ceili(dinner_t), int(player.battery)])
		if dinner_t <= 0.0:
			fall_down("The clock struck eight. Your chair was empty.")
			return
	_cooker_t -= d
	if _cooker_t <= 0.0 and not study_open:
		_cooker_t = randf_range(14.0, 22.0)
		play_at("ring", Vector3(5.2, 1.2, -6.6))
		subtitle("(the pressure cooker whistles)", 2)

func _update_mother(d: float) -> void:
	var to_p := player.global_position - mother.global_position
	to_p.y = 0
	var fwd := -mother.global_transform.basis.z
	var in_front := to_p.length() < MOTHER_RANGE and fwd.dot(to_p.normalized()) > 0.5 and not player.hiding
	if in_front:
		if _mother_try == 0.0:
			subtitle("(she stops. Her face turns toward you.)", 2)
		_mother_try += d
		_mother_head.rotation.z = lerp(_mother_head.rotation.z, 0.35, d * 2.0)
		if _mother_try >= MOTHER_TRY:
			fall_down("She tried to look at you. She has no face to look with.")
		return
	_mother_try = 0.0
	_mother_head.rotation.z = lerp(_mother_head.rotation.z, 0.0, d * 3.0)
	if _mother_wait > 0.0:
		_mother_wait -= d
		return
	var target: Vector3 = _mother_path[_mother_i]
	var to_t := target - mother.global_position; to_t.y = 0
	if to_t.length() < 0.1:
		_mother_i = (_mother_i + 1) % _mother_path.size()
		_mother_wait = randf_range(2.0, 4.0)
		return
	var step: Vector3 = to_t.normalized() * minf(0.75 * d, to_t.length())
	mother.global_position += step
	mother.rotation.y = lerp_angle(mother.rotation.y, atan2(-to_t.x, -to_t.z), d * 4.0)
