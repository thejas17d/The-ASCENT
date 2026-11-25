extends Node3D
## Floor 2 prototype controller: anomaly loop, rules, dread, Room 213.

const Corridor := preload("res://scripts/floors/corridor.gd")
const Player := preload("res://scripts/player/player.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const Sfx := preload("res://scripts/systems/sfx.gd")

const START := Vector3(0, 0.05, 2.0)
const END_Z := -45.0
const DEEP_Z := -8.0
const ANOMALY_CHANCE := 0.55

var corridor: Node3D
var player: CharacterBody3D
var hud: CanvasLayer
var anomalies: Array = []
var rules: Dictionary = {}
var required := 8
var streak := 0
var current := ""          # active anomaly id, "" = clean pass
var went_deep := false
var dread := 0.0
var finished := false
var busy := false
var passes := 0
var _last := ""
var _knock_in := -1.0      # seconds until knocking starts (<0 none)
var _knock_left := 0.0     # seconds of knocking remaining
var _knock_next := 0.0
var _knock_door: Node3D
var _knock_sfx: AudioStreamPlayer3D
var _sting: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_setup_input()
	anomalies = _load_json("res://data/anomalies/floor_02.json")
	rules = _load_json("res://data/floor_rules/floor_02.json")
	required = int(rules.get("required_streak", 8))
	_setup_env()
	corridor = Corridor.new(); add_child(corridor)
	corridor.set_rules(rules.rules)
	player = Player.new(); add_child(player)
	player.interacted.connect(_on_interact)
	hud = Hud.new(); add_child(hud)
	_knock_sfx = AudioStreamPlayer3D.new(); _knock_sfx.stream = Sfx.knock(); _knock_sfx.unit_size = 6
	add_child(_knock_sfx)
	_sting = AudioStreamPlayer.new(); _sting.stream = Sfx.sting(); add_child(_sting)
	var hum := AudioStreamPlayer.new(); hum.stream = Sfx.hum(); hum.volume_db = -8; hum.autoplay = true
	add_child(hum)
	_new_pass(true)
	hud.fade_to(0.0, 1.5)
	hud.message("FLOOR 2 — THE CORRIDOR\nRead the notice board on your left.  WASD move · Shift run · E interact · F torch", 7)

func _setup_input() -> void:
	var map := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"run": [KEY_SHIFT], "interact": [KEY_E], "flashlight": [KEY_F],
	}
	for a in map:
		if InputMap.has_action(a):
			continue
		InputMap.add_action(a)
		for k in map[a]:
			var ev := InputEventKey.new(); ev.physical_keycode = k
			InputMap.action_add_event(a, ev)

func _setup_env() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.23, 0.2)
	env.ambient_light_energy = 0.25
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.045, 0.04)
	env.fog_density = 0.045
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new(); we.environment = env
	add_child(we)

func _load_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(f.get_as_text())

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
	corridor.build(current, streak, streak >= required)
	player.teleport(START)
	went_deep = false
	_knock_left = 0.0
	_knock_in = _rng.randf_range(5.0, 14.0) if (not first and _rng.randf() < 0.4) else -1.0

## Player reached the far end (judged "no anomaly").
func judge_continue() -> void:
	_judge(current == "", "You kept walking.")

## Player turned back to the start (judged "anomaly").
func judge_turn_back() -> void:
	_judge(current != "", "You turned back.")

func _judge(correct: bool, what: String) -> void:
	if streak >= required:
		_transition("The corridor resets. Room 213 is still open.", 0)
		return
	if correct:
		streak += 1
		var hint := "" if current == "" else "  (" + _desc(current) + ")"
		_transition(what + " Correct." + hint + "\nA chalk mark appears on the wall.", 0)
	else:
		var why := "Nothing had changed." if current == "" else "You missed it: " + _desc(current) + "."
		streak = 0
		_add_dread(22)
		_transition(what + " Wrong. " + why + "\nThe tally has been wiped.", 0)

func violate(reason: String) -> void:
	streak = 0
	_add_dread(30)
	_sting.play()
	_transition(reason + "\nThe lights die. You wake at the start. The tally is gone.", 1)

func _desc(id: String) -> String:
	for a in anomalies:
		if a.id == id:
			return a.desc
	return id

func _transition(msg: String, kind: int) -> void:
	busy = true
	player.input_enabled = false
	await hud.fade_to(1.0, 0.35 if kind == 0 else 0.15)
	if dread >= 100.0:
		msg = "BREAKDOWN. Your mind gives out.\n(Full game: you wake one floor below.) Dread steadies."
		dread = 40.0
		streak = 0
	_new_pass()
	hud.message(msg, 5)
	await get_tree().create_timer(0.6 if kind == 0 else 1.8).timeout
	player.input_enabled = true
	await hud.fade_to(0.0, 0.6)
	busy = false

func _win() -> void:
	finished = true
	player.input_enabled = false
	await hud.fade_to(1.0, 2.0)
	hud.message("ROOM 213 EXISTS.\nThe rule was a lie.  FLOOR 2 CLEARED in %d passes.\n\n(End of prototype — Floor 3: RECORDS is next.)" % passes, 9999)

# ---------------------------------------------------------------- per frame

func _process(d: float) -> void:
	if finished:
		return
	hud.set_prompt(player.prompt())
	_update_dread(d)
	if busy:
		return
	var p := player.global_position
	if corridor.room213_open and p.x < -2.0:
		_win()
		return
	if p.z < DEEP_Z:
		went_deep = true
	if p.z < END_Z:
		judge_continue()
	elif went_deep and p.z > 1.0:
		judge_turn_back()
	_update_knocking(d)
	if corridor.figure and p.distance_to(corridor.figure.global_position) < 9.0:
		corridor.figure.visible = false   # it is never there when you arrive

func _update_knocking(d: float) -> void:
	if _knock_in > 0:
		_knock_in -= d
		if _knock_in <= 0:
			_start_knocking()
	if _knock_left > 0:
		_knock_left -= d
		_knock_next -= d
		if _knock_next <= 0 and is_instance_valid(_knock_door):
			_knock_sfx.global_position = _knock_door.global_position
			_knock_sfx.play()
			_knock_next = 1.3
		# Rule 1 is incomplete: running is only punished while it knocks.
		if player.is_running:
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
	_add_dread(6)
	hud.message("…knock knock…", 2)

func _on_interact(t: Object) -> void:
	if busy or finished or t == null:
		return
	if hud.panel_open():
		hud.hide_panel(); return
	if t.has_meta("board"):
		var s := "RULES OF THE BUILDING\nREAD CAREFULLY. THE BUILDING IS LISTENING.\n"
		for r in rules.rules:
			s += "\n•  " + str(r.text)
		s += "\n\nIf anything in the corridor is different, turn back.\nIf nothing is different, keep walking.\n\n[E] close"
		hud.show_panel(s)
	elif t.has_meta("door_index"):
		if _knock_left > 0 and t == _knock_door:
			violate("You knocked back.")
		else:
			hud.message("Locked.", 1.5)

func _add_dread(v: float) -> void:
	dread = clamp(dread + v, 0.0, 100.0)

func _update_dread(d: float) -> void:
	if dread >= 100.0 and not busy:
		_sting.play()
		_transition("", 1)
		return
	# darkness raises dread; torchlight slowly calms
	if not player.light.visible:
		dread = min(100.0, dread + 1.2 * d)
	else:
		dread = max(0.0, dread - 0.6 * d)
	if current != "" and not busy:
		dread = min(100.0, dread + 0.25 * d)
	player.shake = dread / 100.0
	hud.set_dread(dread)
