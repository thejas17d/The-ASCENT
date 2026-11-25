extends FloorBase
## FLOOR 9 — THE BLUEPRINT (hidden). Unlocked by a run with no falls; entered
## from the title menu. There were never supposed to be nine floors.
## A glowing blueprint in the void; outlines of every floor you climbed; a
## model of Meridian Tower. Touch each storey of the model to remember it.
## When all nine are remembered, the scratched-out man gets a name.
## No threat. Expandable: add storeys/memories in RECAPS.

const RECAPS := [
	["G", "RECEPTION", "Your signature was already in the register, dated the night you turned nine.\nThe clock stopped at 3:33 and never moved again."],
	["1", "THE OFFICE", "Six lockers. Six names. A memo that said anyone leaving early would not be paid."],
	["2", "THE CORRIDOR", "Room 213 did not exist, the board said. It was the only way out.\nThe building lies the way people do — to keep you walking."],
	["3", "RECORDS", "HALT ALL SLAB POURS ABOVE FLOOR 4. Struck through in red.\nSigned P. Desai. Countersigned by a name nobody could read."],
	["4", "THE RESIDENCE", "Nine candles. An empty chair. A cassette: \"I promised I'd be home by eight.\"\nA letter you could keep or burn."],
	["5", "THE HUNT", "It hunted by one sense and the board told you both. You had to watch it to know which.\nThat is how the men on the night pour learned the building, too."],
	["6", "THE INVERSION", "Your shadow did what you did, three seconds late. Then it wanted to be you.\nMirrors keep things."],
	["7", "THE COLLAPSE", "03:33, 14 June 1998. Six men waiting with their tally tags.\nYou could give them their names back. Or not."],
	["8", "THE ROOF", "A painted city. Your father at the end of the crane, finally saying it out loud."],
]

var kit: Kit
var storeys: Array = []
var seen := {}
var revealed := false
var exit_door: Node3D

func _ready() -> void:
	floor_index = 9
	rules = {"rules": [{"text": "There are no rules on the ninth floor."}, {"text": "There was never supposed to be a ninth floor."}]}
	kit = Kit.new(self)
	_build()
	setup_common()
	director.enabled = false
	_blueprint_sky()
	spawn = Vector3(0, 0.05, 12.0)
	player.teleport(spawn)
	player.light.visible = false
	hud.fade_to(0.0, 2.0)
	hud.message("FLOOR 9 — THE BLUEPRINT\nThere were never supposed to be nine floors.", 7)

func _build() -> void:
	# an invisible floor under a glowing blueprint grid
	var floor_b: Node3D = kit.box(Vector3(60, 0.2, 60), Vector3(0, -0.1, 0), Color(0.01, 0.02, 0.05))
	(floor_b.get_child(1) as MeshInstance3D).material_override = _mat_floor()
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = BoxMesh.new()
	var xf: Array = []
	for i in range(-15, 16):
		var w := 0.03 if i % 5 != 0 else 0.06
		xf.append(Transform3D(Basis.from_scale(Vector3(w, 0.005, 60)), Vector3(i * 2.0, 0.003, 0)))
		xf.append(Transform3D(Basis.from_scale(Vector3(60, 0.005, w)), Vector3(0, 0.003, i * 2.0)))
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm
	mmi.material_override = _mat_line(1.2)
	add_child(mmi)
	# outlines of the floors below, in a ring around the model
	for i in 9:
		var a := TAU * i / 9.0
		var c := Vector3(sin(a) * 13.0, 0, cos(a) * 13.0)
		_outline_room(c, -a, 5.0, 3.5, 2.6)
		kit.label("%s — %s" % [RECAPS[i][0], RECAPS[i][1]], c + Vector3(0, 2.9, 0), -a + PI, Color(0.55, 0.8, 1.0), 40, false)
	# drafting table + model tower (G at the bottom, 8 at the top)
	kit.table(Vector3(0, 0, 0), Vector3(2.2, 0.9, 1.4), _mat_paper())
	for i in 9:
		var s: Node3D = kit.box(Vector3(0.5, 0.16, 0.5), Vector3(0, 0.98 + i * 0.17, 0), _mat_model())
		s.set_meta("use", "storey:%d" % i)
		s.set_meta("prompt", "Floor %s — %s" % [RECAPS[i][0], RECAPS[i][1]])
		storeys.append(s)
	kit.board(Vector3(-3.5, 1.5, 10.0), PI / 2, rules.rules)
	var l := OmniLight3D.new(); l.position = Vector3(0, 3.5, 0); l.light_color = Color(0.6, 0.8, 1.0)
	l.light_energy = 1.6; l.omni_range = 9.0; add_child(l); kit.lights.append(l)

## Thin glowing edges of a box room (the blueprint of a floor).
func _outline_room(c: Vector3, yaw: float, w: float, d: float, h: float) -> void:
	var n := Node3D.new(); n.position = c; n.rotation.y = yaw; add_child(n)
	var m := _mat_line(2.0)
	for y in [0.0, h]:
		kit.box(Vector3(w, 0.03, 0.03), Vector3(0, y, -d / 2), m, false, n)
		kit.box(Vector3(w, 0.03, 0.03), Vector3(0, y, d / 2), m, false, n)
		kit.box(Vector3(0.03, 0.03, d), Vector3(-w / 2, y, 0), m, false, n)
		kit.box(Vector3(0.03, 0.03, d), Vector3(w / 2, y, 0), m, false, n)
	for x in [-w / 2, w / 2]:
		for z in [-d / 2, d / 2]:
			kit.box(Vector3(0.03, h, 0.03), Vector3(x, h / 2, z), m, false, n)

func _mat_line(e: float) -> Material:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.35, 0.6, 1.0); m.emission_enabled = true
	m.emission = Color(0.35, 0.6, 1.0); m.emission_energy_multiplier = e
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func _mat_floor() -> Material:
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.02, 0.04, 0.1); m.roughness = 0.4
	return m

func _mat_paper() -> Material:
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.75, 0.82, 0.9); m.roughness = 0.8
	return m

func _mat_model() -> Material:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.92, 1.0, 0.55); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true; m.emission = Color(0.3, 0.5, 0.9); m.emission_energy_multiplier = 0.6
	return m

func _blueprint_sky() -> void:
	var env: Environment = Graphics.env
	env.background_color = Color(0.005, 0.012, 0.03)
	env.ambient_light_color = Color(0.4, 0.55, 0.9); env.ambient_light_energy = 0.4
	env.fog_light_color = Color(0.05, 0.1, 0.2)
	env.volumetric_fog_albedo = Color(0.6, 0.75, 1.0)

# ---------------------------------------------------------------- remembering
func on_use(id: String, _node: Node3D) -> void:
	if id.begins_with("storey:"):
		remember(int(id.trim_prefix("storey:")))
	elif id == "ground":
		leave()
	elif id == "owner":
		hud.show_panel("The photograph from the flat — Papa in his yellow helmet beside the tall man in the long coat.
Here the face isn't scratched out.

On the back, typed:

R. K. MEHRA — OWNER, MERIDIAN CONSTRUCTIONS.
SUNRISE APARTMENTS, 12TH FLOOR. COMPLETED 2003.

He built another one.

[E] close")

func remember(i: int) -> void:
	seen[i] = true
	var s: Node3D = storeys[i]
	var m := (s.get_child(1) as MeshInstance3D).material_override as StandardMaterial3D
	var lit := m.duplicate() as StandardMaterial3D
	lit.emission_energy_multiplier = 3.0
	(s.get_child(1) as MeshInstance3D).material_override = lit
	hud.show_panel("FLOOR %s — %s\n\n%s\n\n[E] close" % [RECAPS[i][0], RECAPS[i][1], RECAPS[i][2]])
	if seen.size() == RECAPS.size() and not revealed:
		reveal()

## Every storey remembered: the man in the photograph gets a name, and a door appears.
func reveal() -> void:
	revealed = true
	if not GameState.collectibles.has("f9_owner"):
		GameState.collectibles.append("f9_owner")
	GameState.save_game()
	var photo: Node3D = kit.box(Vector3(0.15, 0.004, 0.1), Vector3(0.7, 0.93, 0.3), Color(0.9, 0.9, 0.85))
	photo.set_meta("use", "owner"); photo.set_meta("prompt", "A photograph that wasn't there before")
	await get_tree().create_timer(0.5, false).timeout
	subtitle("(on the drafting table, a photograph has appeared)", 3)
	exit_door = kit.box(Vector3(1.2, 2.3, 0.05), Vector3(0, 1.15, -16.0), _mat_line(3.0))
	exit_door.set_meta("use", "ground"); exit_door.set_meta("prompt", "GROUND FLOOR")
	kit.label("GROUND", Vector3(0, 2.6, -15.95), 0.0, Color(0.6, 0.85, 1.0), 48, false)

func leave() -> void:
	if busy:
		return
	busy = true
	finished = true
	GameState.unlocks["floor9_done"] = true
	GameState.save_unlocks()
	await hud.fade_to(1.0, 2.0)
	hud.message("You step through, and the blueprint folds shut behind you.\n\nSomewhere across the city, in a twelve-storey building, a lift indicator stops on 12.", 9999)
	await get_tree().create_timer(6.0, false).timeout
	GameState.go("res://scenes/menu.tscn")

func floor_lights() -> Array: return kit.lights
func surface_at(_p: Vector3) -> String: return "tile"
