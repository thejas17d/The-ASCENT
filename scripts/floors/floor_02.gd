extends FloorBase
## Floor 2 — THE CORRIDOR: anomaly loop, lying rule board, Room 213.

const Corridor := preload("res://scripts/floors/corridor.gd")

const START := Vector3(0, 0.05, 2.0)
const END_Z := -45.0
const DEEP_Z := -8.0
const ANOMALY_CHANCE := 0.55
const PICKUP_CHANCE := 0.3
const KNOCK_GRACE := 1.2       # seconds to stop running after knocking starts
const FIGURE_WATCH := 16.0     # the figure turns to face you inside this range

var corridor: Node3D
var anomalies: Array = []
var rules: Dictionary = {}
var required := 8
var streak := 0
var current := ""          # active anomaly id, "" = clean pass
var went_deep := false
var passes := 0
var _last := ""
var _knock_in := -1.0
var _knock_left := 0.0
var _knock_next := 0.0
var _knock_age := 0.0
var _knock_door: Node3D
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	anomalies = _load_json("res://data/anomalies/floor_02.json")
	rules = _load_json("res://data/floor_rules/floor_02.json")
	for n in _load_json("res://data/notes/floor_02.json"):
		notes[n.id] = n
	required = int(rules.get("required_streak", 8))
	corridor = Corridor.new(); add_child(corridor)
	corridor.set_rules(rules.rules)
	setup_common()
	streak = int(GameState.checkpoint.get("streak", 0))
	# only a brand-new floor gets a guaranteed clean first pass
	_new_pass(streak == 0 and passes == 0 and not GameState.checkpoint.has("streak"))
	hud.fade_to(0.0, 1.5)
	var intro := "FLOOR 2 — THE CORRIDOR\nRead the notice board on your left.   Esc pause · Tab inventory"
	if GameState.checkpoint.has("streak"):
		intro = "Checkpoint restored — tally %d." % streak
	hud.message(intro, 7)

func _load_json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.open(path, FileAccess.READ).get_as_text())

# ---------------------------------------------------------------- hooks
func world_root() -> Node3D: return corridor
func floor_lights() -> Array: return corridor.lights
func hide_spot() -> Node3D: return corridor.hide_spot

func surface_at(pos: Vector3) -> String:
	return "carpet" if (pos.z < 0.0 and pos.z > -Corridor.LEN) else "tile"

func on_interact(t: Object) -> bool:
	if t.has_meta("board"):
		var s := "RULES OF THE BUILDING\nREAD CAREFULLY.  THE BUILDING IS LISTENING.\n"
		for r in rules.rules:
			s += "\n•  " + str(r.text)
		s += "\n\nIf anything in the corridor is different, turn back.\nIf nothing is different, keep walking.\nWhat vanishes was never there.\n\n[E] close"
		hud.show_panel(s)
		return true
	if t.has_meta("door_index"):
		if _knock_left > 0 and t == _knock_door:
			violate("You knocked back.")
		else:
			hud.message("Locked.", 1.5)
		return true
	return false

func on_breakdown() -> void:
	Dread.reset(40.0)   # before saving, so a reload never resumes at 100
	streak = 0
	_checkpoint()
	_transition("BREAKDOWN. Your mind gives out.\n(Full game: you wake one floor below.)", 1)

func perform_floor_event(id: String) -> bool:
	if id == "fake_figure":
		# a hallucination: appears ahead, gone within a second
		var f: Node3D = corridor._figure(Vector3(0.3, 0, player.global_position.z - 14.0))
		get_tree().create_timer(0.9, false).timeout.connect(func(): if is_instance_valid(f): f.queue_free())
		return true
	return false

# ---------------------------------------------------------------- pass flow
func pick_anomaly(first: bool) -> String:
	if first or streak >= required or _rng.randf() > ANOMALY_CHANCE:
		return ""
	var pool := anomalies.filter(func(a): return a.id != _last)
	return pool[_rng.randi_range(0, pool.size() - 1)].id

func _new_pass(first := false) -> void:
	passes += 1
	current = pick_anomaly(first)
	if current != "":
		_last = current
	clear_placed()
	corridor.build(current, streak, streak >= required)
	# pickups and notes only ever appear in the start lobby, never in the
	# judged corridor, so they can't be mistaken for anomalies
	if not first and _rng.randf() < PICKUP_CHANCE:
		var kinds := ["battery", "diya", "chalk"]
		corridor.add_pickup(kinds[_rng.randi() % 3], Vector3(_rng.randf_range(-1.1, 0.2), 0.06, _rng.randf_range(0.6, 3.6)))
	var spots := [Vector3(-0.9, 0.006, 3.9), Vector3(0.1, 0.006, 4.4), Vector3(-0.3, 0.006, 0.9)]
	var k := 0
	for n in notes.values():
		if streak >= int(n.get("min_streak", 0)) and not GameState.collectibles.has(n.id) and k < spots.size():
			corridor.add_note(n.id, spots[k])
			k += 1
	player.teleport(START)
	went_deep = false
	_knock_left = 0.0
	_knock_in = _rng.randf_range(5.0, 14.0) if (not first and _rng.randf() < 0.4) else -1.0

func judge_continue() -> void:
	_judge(current == "", "You kept walking.")

func judge_turn_back() -> void:
	_judge(current != "", "You turned back.")

func _judge(correct: bool, what: String) -> void:
	if streak >= required:
		_transition("The corridor resets. Room 213 is still open.", 0)
		return
	if correct:
		streak += 1
		var hint := "" if current == "" else "  (" + _desc(current) + ")"
		_checkpoint()
		_transition(what + " Correct." + hint + "\nA chalk mark appears on the wall.", 0)
	else:
		var why := "Nothing had changed." if current == "" else "You missed it: " + _desc(current) + "."
		streak = 0
		_checkpoint()
		Dread.add(22)
		hud.glitch(0.5)
		_transition(what + " Wrong. " + why + "\nThe tally has been wiped.", 0)

func violate(reason: String) -> void:
	if busy:
		return
	streak = 0
	_checkpoint()
	Dread.add(30)
	_sfx.sting.play()
	hud.glitch(1.2)
	_transition(reason + "\nThe lights die. You wake at the start. The tally is gone.", 1)

func _checkpoint() -> void:
	GameState.floor_num = 2
	GameState.checkpoint = {"streak": streak}
	GameState.save_game()

func _desc(id: String) -> String:
	for a in anomalies:
		if a.id == id:
			return a.desc
	return id

func _transition(msg: String, kind: int) -> void:
	if busy:
		return
	busy = true
	player.input_enabled = false
	player.set_phone(false)
	await hud.fade_to(1.0, 0.35 if kind == 0 else 0.15)
	if Dread.value >= 100.0:
		Dread.reset(40.0)
	_new_pass()
	hud.message(msg, 5)
	await get_tree().create_timer(0.6 if kind == 0 else 1.8, false).timeout
	player.input_enabled = true
	await hud.fade_to(0.0, 0.6)
	busy = false

func _win() -> void:
	finished = true
	player.input_enabled = false
	GameState.floor_num = 3
	GameState.checkpoint = {}
	GameState.save_game()
	await hud.fade_to(1.0, 2.0)
	hud.message("ROOM 213 EXISTS.\nThe rule was a lie.   FLOOR 2 CLEARED in %d passes.\n\nFloor 3 — RECORDS — is under construction.\nReturning to the title screen…" % passes, 9999)
	await get_tree().create_timer(6.0, false).timeout
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

# ---------------------------------------------------------------- per frame
func _process(d: float) -> void:
	super._process(d)
	if finished or busy:
		return
	var p := player.global_position
	if corridor.room213_open and p.x < -2.0:
		_win()
		return
	if p.z < DEEP_Z:
		went_deep = true
	if p.z < END_Z:
		judge_continue()
		return
	elif went_deep and p.z > 1.0:
		judge_turn_back()
		return
	_update_knocking(d)
	# the figure never vanishes (it's a real anomaly); it turns to watch you
	if corridor.figure and p.distance_to(corridor.figure.global_position) < FIGURE_WATCH:
		var target := Vector3(p.x, (corridor.figure as Node3D).global_position.y, p.z)
		var t: Transform3D = corridor.figure.global_transform.looking_at(target, Vector3.UP, true)
		corridor.figure.global_transform = corridor.figure.global_transform.interpolate_with(t, clamp(d * 1.5, 0.0, 1.0))

func _update_knocking(d: float) -> void:
	if _knock_in > 0:
		_knock_in -= d
		if _knock_in <= 0:
			_start_knocking()
	if _knock_left > 0:
		_knock_age += d
		# hiding makes it give up sooner
		_knock_left -= d * (2.5 if player.hiding else 1.0)
		_knock_next -= d
		if _knock_next <= 0 and is_instance_valid(_knock_door):
			play_at("knock", _knock_door.global_position)
			_knock_next = 1.3
		# Rule 1 is incomplete: running is only punished while it knocks
		# (after a short grace so the player can hear it and stop).
		if player.is_running and _knock_age > KNOCK_GRACE:
			violate("You ran while something was knocking.")

func _start_knocking() -> void:
	var z := player.global_position.z
	var best: Node3D = null
	for door in corridor.knock_doors:
		if door and door.global_position.z < z - 3.0 and (best == null or door.global_position.z > best.global_position.z):
			best = door
	if best == null:
		return
	_knock_door = best
	_knock_left = 7.0
	_knock_next = 0.0
	_knock_age = 0.0
	Dread.add(6)
	subtitle("(knock… knock… from a door ahead)", 2.5)
