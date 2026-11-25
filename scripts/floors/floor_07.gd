extends FloorBase
## FLOOR 7 — THE COLLAPSE. 03:33, 14 June 1998, frozen: slabs and dust hang
## in the air. Two opposing rules: "Do not look at it" (the figure on the
## platform — holding it in view kills) and "Do not look away from them" (six
## frozen workers creep toward you whenever unobserved). Free each worker by
## giving back his ID card (from Floor 1 — spares lie here for the careless).
## The stairs are open: freeing them is a choice. Lethal.

const Supervisor := preload("res://scripts/ai/supervisor.gd")
const WORKERS := [["ramesh", "RAMESH PATIL"], ["suresh", "SURESH YADAV"], ["abdul", "ABDUL KARIM"],
	["joseph", "JOSEPH D'SOUZA"], ["mahadev", "MAHADEV GAIKWAD"], ["babu", "BABU RAO"]]
const WORKER_POS := [Vector3(-11.5, 0, 7.5), Vector3(10, 0, 5), Vector3(-11, 0, -6), Vector3(11, 0, -7), Vector3(-5, 0, -11), Vector3(6, 0, -11)]
const CREEP_SPEED := 1.1
const GAZE_DEATH := 1.6
const OVERSEER := Vector3(0, 1.2, -3)

var kit: Kit
var overseer: CharacterBody3D
var workers: Array = []          # {node, key, freed}
var gaze := 0.0
var _gaze_warned := false
var _debris: Array = []
var _scrape_t := 0.0

func _ready() -> void:
	load_floor_data(7)
	kit = Kit.new(self)
	_build()
	setup_common()
	director.enabled = false
	spawn = Vector3(0, 0.05, 10.5)
	_spawn_workers()
	begin_floor()
	exit_unlocked = true
	_update_choice()

func _build() -> void:
	var c := Vector3(0, 0, -1)
	kit.box(Vector3(30.4, 0.2, 26.4), c + Vector3(0, -0.1, 0), kit.m.concrete)
	kit.box(Vector3(30.4, 0.25, 26.4), c + Vector3(0, 3.6, 0), kit.m.concrete)
	for e in [[Vector3(0, 0, 12), Vector3(30, 0, 0.2)], [Vector3(0, 0, -14), Vector3(30, 0, 0.2)],
			[Vector3(-15, 0, -1), Vector3(0.2, 0, 26)], [Vector3(15, 0, -1), Vector3(0.2, 0, 26)]]:
		var p: Vector3 = e[0]; var sz: Vector3 = e[1]
		kit.box(Vector3(max(sz.x, 0.2), 3.6, max(sz.z, 0.2)), p + Vector3(0, 1.8, 0), kit.m.paint)
	for x in [-10.0, -5.0, 5.0, 10.0]:
		for z in [6.0, 1.0, -4.0, -9.0]:
			var col: Node3D = kit.box(Vector3(0.5, 3.6, 0.5), Vector3(x, 1.8, z), kit.m.concrete)
			if randf() < 0.3:
				col.rotation.z = randf_range(-0.12, 0.12)   # buckling
	# the overseer's platform at the centre
	kit.box(Vector3(3.0, 1.2, 3.0), Vector3(0, 0.6, -3), kit.m.concrete)
	# a hanging slab between the stairs and the platform: your first view is safe
	var slab: Node3D = kit.box(Vector3(5.0, 1.6, 0.4), Vector3(0, 1.6, 6.5), kit.m.concrete)
	slab.rotation.z = 0.06
	# frozen debris: slab chunks, bricks, a wheelbarrow, all hanging mid-fall
	var rng := RandomNumberGenerator.new(); rng.seed = 1998
	for i in 34:
		var size := Vector3(rng.randf_range(0.2, 1.6), rng.randf_range(0.08, 0.4), rng.randf_range(0.2, 1.4))
		var pos := Vector3(rng.randf_range(-13, 13), rng.randf_range(0.9, 3.2), rng.randf_range(-12, 9))
		if pos.distance_to(Vector3(0, 1.6, 10.5)) < 3.0:
			continue
		var d: Node3D = kit.box(size, pos, kit.m.concrete, false)
		d.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
		d.set_meta("dynamic", true)   # slowly turning
		_debris.append([d, Vector3(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.08, 0.08), rng.randf_range(-0.05, 0.05))])
	for p in [Vector3(-7, 1.8, -1), Vector3(7, 1.8, -1), Vector3(0, 1.8, 9), Vector3(-6, 1.8, -12), Vector3(6, 1.8, 3)]:
		kit.lamp(p, "work", Color(1.0, 0.45, 0.25), 0.9, 8.0)
	kit.board(Vector3(-4.0, 1.5, 11.86), PI, rules.rules)
	kit.note("c_tag", Vector3(1.5, 0.006, 9.8))
	if not GameState.collectibles.has("voice_3"):
		kit.item("voice_3", "cassette (voice note)", Vector3(-2.0, 0.0, 9.6), "tape", Color(0.75, 0.2, 0.15))
	kit.stair_exit(Vector3(0, 0, -13.85), 0.0, "STAIRS ▲  8")
	# the overseer: the Supervisor's body, dormant, lamp red, facing the stairs
	overseer = Supervisor.new()
	add_child(overseer)
	overseer.activate(OVERSEER + Vector3(0, 0.05, 0))
	overseer.deactivate()
	overseer.rotation.y = 0.0
	overseer._set_lamp(Color(1, 0.08, 0.04), 2.0)

func _spawn_workers() -> void:
	var freed_before: Array = GameState.checkpoint.get("freed", [])
	for i in 6:
		var key: String = WORKERS[i][0]
		var w := StaticBody3D.new()
		w.position = WORKER_POS[i]
		var cs := CollisionShape3D.new(); var sh := CapsuleShape3D.new(); sh.radius = 0.3; sh.height = 1.8
		cs.shape = sh; cs.position.y = 0.9; w.add_child(cs)
		add_child(w)
		var vest := StandardMaterial3D.new(); vest.albedo_color = Color(0.7, 0.35, 0.08); vest.roughness = 0.9
		var grey := StandardMaterial3D.new(); grey.albedo_color = Color(0.45, 0.43, 0.4)
		var body := CapsuleMesh.new(); body.radius = 0.25; body.height = 1.5
		kit.mesh(body, Vector3(0, 0.85, 0), vest, w)
		var head := SphereMesh.new(); head.radius = 0.12; head.height = 0.25
		kit.mesh(head, Vector3(0, 1.72, 0), grey, w)
		var hel := SphereMesh.new(); hel.radius = 0.15; hel.height = 0.15; hel.is_hemisphere = true
		kit.mesh(hel, Vector3(0, 1.78, 0), Color(0.85, 0.82, 0.7), w)
		kit.label(WORKERS[i][1], Vector3(0, 1.2, -0.26), PI, Color(0.1, 0.1, 0.1), 22, true, w)
		w.set_meta("use", "worker:%d" % i)
		w.set_meta("prompt", WORKERS[i][1].capitalize())
		w.look_at(Vector3(spawn.x, 0, spawn.z), Vector3.UP)
		var entry := {"node": w, "key": key, "freed": false}
		workers.append(entry)
		if freed_before.has(key):
			entry.freed = true
			w.queue_free()
		elif not GameState.collectibles.has("id_" + key):
			kit.item("id_" + key, "ID card — " + str(WORKERS[i][1]), WORKER_POS[i] + Vector3(1.6, 0.0, 1.2), "card", Color(0.85, 0.82, 0.7))

# ---------------------------------------------------------------- freeing
func on_use(id: String, _node: Node3D) -> void:
	if id.begins_with("worker:"):
		free_worker(int(id.trim_prefix("worker:")))

func free_worker(i: int) -> bool:
	var e: Dictionary = workers[i]
	if e.freed:
		return false
	if not GameState.collectibles.has("id_" + e.key):
		hud.message("He is waiting for his name. You don't have his card.", 3)
		return false
	e.freed = true
	var n: Node3D = e.node
	(n.get_child(0) as CollisionShape3D).disabled = true
	hud.message("You press the card into his hand. \"%s.\" He lets go of something he's held for a long time." % WORKERS[i][1].capitalize(), 4)
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector3(1.0, 1.15, 1.0), 1.2)
	tw.parallel().tween_property(n, "position:y", n.position.y + 0.6, 1.8)
	tw.tween_callback(n.queue_free)
	var freed: Array = []
	for w in workers:
		if w.freed:
			freed.append(w.key)
	GameState.checkpoint = {"freed": freed}
	_update_choice()
	GameState.save_game()
	return true

func freed_count() -> int:
	return workers.filter(func(w): return w.freed).size()

func _update_choice() -> void:
	GameState.choices["workers"] = "freed" if freed_count() == 6 else "left"

# ---------------------------------------------------------------- attention
func _looking_at(p: Vector3, threshold: float) -> bool:
	var to := p - player.cam.global_position
	if (-player.cam.global_transform.basis.z).dot(to.normalized()) < threshold:
		return false
	var q := PhysicsRayQueryParameters3D.create(player.cam.global_position, p, 1)
	var ex: Array[RID] = [player.get_rid(), overseer.get_rid()]
	for w in workers:
		if not w.freed and is_instance_valid(w.node):
			ex.append(w.node.get_rid())
	q.exclude = ex
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func update_gaze(d: float) -> void:
	if _looking_at(OVERSEER + Vector3(0, 2.0, 0), 0.93):
		gaze += d
		Dread.add(6 * d)
		if gaze > 0.45:
			hud.glitch(0.2)
			if not _gaze_warned:
				_gaze_warned = true
				subtitle("(a rising whine in your ears — LOOK AWAY)", 2.5)
				_sfx.sting.play()
	else:
		gaze = max(0.0, gaze - d * 0.8)
		if gaze == 0.0:
			_gaze_warned = false
	if gaze >= GAZE_DEATH:
		die("You looked at it.")

func update_workers(d: float) -> void:
	var moving := false
	for w in workers:
		if w.freed or not is_instance_valid(w.node):
			continue
		var n: Node3D = w.node
		var to := player.global_position - n.global_position; to.y = 0
		if to.length() < 0.9:
			die("%s reached you." % str(WORKERS[workers.find(w)][1]).capitalize())
			return
		if _looking_at(n.global_position + Vector3(0, 1.2, 0), 0.55):
			continue
		n.global_position += to.normalized() * CREEP_SPEED * d
		n.look_at(Vector3(player.global_position.x, n.global_position.y, player.global_position.z), Vector3.UP)
		moving = true
	_scrape_t -= d
	if moving and _scrape_t <= 0.0:
		_scrape_t = 2.5
		play_at("footsteps", player.global_position - (-player.cam.global_transform.basis.z) * 3.0)
		subtitle("(something scrapes behind you)", 1.5)

func floor_lights() -> Array: return kit.lights
func surface_at(_p: Vector3) -> String: return "concrete"

func _process(d: float) -> void:
	super._process(d)
	for dd in _debris:
		dd[0].rotation += dd[1] * d
	if finished or busy:
		return
	hud.set_status("Freed %d/6   ·   Torch %d%%" % [freed_count(), int(player.battery)])
	update_gaze(d)
	if busy:
		return
	update_workers(d)
