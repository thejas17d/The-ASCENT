extends FloorBase
## FLOOR 1 — THE OFFICE. Return six personal items from the desks to the
## right workers' lockers (true rule: every desk empty). Each locker gives you
## that worker's ID card — needed on Floor 7. Mahadev's photo has no name:
## the phone camera shows it. A 25th chair sometimes appears (incomplete
## rule): step back out through the entrance and return, or fall to Floor G.

const WORKERS := [
	{"key": "ramesh", "name": "RAMESH PATIL", "item": "steel tiffin box", "look": "box", "col": Color(0.75, 0.75, 0.78)},
	{"key": "suresh", "name": "SURESH YADAV", "item": "spectacles case", "look": "box", "col": Color(0.15, 0.12, 0.1)},
	{"key": "abdul", "name": "ABDUL KARIM", "item": "folded prayer cap", "look": "photo", "col": Color(0.92, 0.9, 0.85)},
	{"key": "joseph", "name": "JOSEPH D'SOUZA", "item": "cassette of Konkani songs", "look": "tape", "col": Color(0.2, 0.2, 0.25)},
	{"key": "mahadev", "name": "MAHADEV GAIKWAD", "item": "photograph of a little girl", "look": "photo", "col": Color(0.85, 0.8, 0.7)},
	{"key": "babu", "name": "BABU RAO", "item": "red union badge", "look": "card", "col": Color(0.7, 0.08, 0.06)},
]
const DESK_POS := [Vector3(-4, 0, -4), Vector3(1, 0, -4), Vector3(6, 0, -4), Vector3(-4, 0, -7.5), Vector3(1, 0, -7.5), Vector3(6, 0, -7.5),
	Vector3(-4, 0, -11), Vector3(1, 0, -11), Vector3(6, 0, -11), Vector3(-4, 0, -14.5), Vector3(1, 0, -14.5), Vector3(6, 0, -14.5)]
const ITEM_DESKS := [0, 2, 4, 7, 9, 11]      # which desk holds which worker's item
const CHAIR_AISLE := Vector3(-1.5, 0, -9.2)
const CHAIR_GRACE := 40.0
const MESSAGE := ["THEY", "WERE", "TOLD", "TO", "KEEP", "WORKING"]

var kit: Kit
var returned := [false, false, false, false, false, false]
var lockers: Array = []
var screens: Array = []           # Label3D per monitor
var chairs: Array = []
var extra_chair: Node3D
var _extra_t := 0.0
var _extra_due := -1.0
var _extra_count := 0
var _type_t := 18.0
var _type_i := -1

func _ready() -> void:
	load_floor_data(1)
	kit = Kit.new(self)
	_build()
	if GameState.altered_level(1) > 0:
		for c in chairs:
			c.look_at(Vector3(0, 0, 0.6), Vector3.UP)   # every chair turned toward the entrance
	setup_common()
	spawn = Vector3(0, 0.05, 0.6)
	begin_floor()
	if GameState.solved_floor(1):
		for i in 6:
			_mark_returned(i, false)
		unlock_exit("")
	# the item in your hands (saved) must not also lie on its desk
	if GameState.carry != "":
		var held := _item_node(GameState.carry)
		if held:
			held.queue_free()

func _item_node(id: String) -> Node:
	for c in get_children():
		if c.has_meta("item") and str(c.get_meta("item")) == id:
			return c
	return null

func apply_checkpoint(cp: Dictionary) -> void:
	for k in cp.get("returned", []):
		var i := int(k)
		_mark_returned(i, false)
		var n := _item_node("o_item_%d" % i)
		if n:
			n.queue_free()

func _build() -> void:
	kit.room(Vector3(0, 0, -10), 20.0, 18.0, 3.2, kit.m.paint, kit.m.carpet_grey, kit.m.ceiling,
		[{"side": "s", "at": 0.0, "width": 1.4, "height": 2.3}, {"side": "n", "at": 7.0, "width": 1.1, "height": 2.2}])
	# entrance vestibule (z -0.8 .. 1.6) — "leaving" means stepping back in here
	kit.box(Vector3(2.6, 0.2, 2.6), Vector3(0, -0.1, 0.4), kit.m.mosaic)
	kit.box(Vector3(2.6, 0.2, 2.6), Vector3(0, 2.4, 0.4), kit.m.ceiling)
	kit.box(Vector3(0.2, 2.5, 2.6), Vector3(-1.3, 1.25, 0.4), kit.m.paint)
	kit.box(Vector3(0.2, 2.5, 2.6), Vector3(1.3, 1.25, 0.4), kit.m.paint)
	kit.box(Vector3(2.6, 2.5, 0.2), Vector3(0, 1.25, 1.7), kit.m.paint)
	kit.box(Vector3(1.0, 2.1, 0.06), Vector3(0, 1.05, 1.57), kit.m.metal).set_meta("prompt", "The way down is gone")
	kit.board(Vector3(-1.17, 1.4, 0.4), PI / 2, rules.rules)
	kit.lamp(Vector3(0, 2.3, 0.4), "bulb", Color(1, 0.82, 0.55), 0.9, 4.0)
	kit.label("SITE OFFICE — MERIDIAN CONSTRUCTIONS", Vector3(0, 2.75, -1.12), PI, Color(0.25, 0.22, 0.18), 26)
	# worker lockers on the west wall
	for i in 6:
		var w: Dictionary = WORKERS[i]
		var l: Node3D = kit.locker(Vector3(-9.6, 0, -4.0 - i * 2.2), -PI / 2, w.name)
		l.remove_meta("hide")
		l.set_meta("use", "locker:%d" % i)
		l.set_meta("prompt", "Locker — " + str(w.name))
		lockers.append(l)
	# cubicles: desk, partitions, CRT, keyboard, chair
	for i in DESK_POS.size():
		var p: Vector3 = DESK_POS[i]
		kit.desk(p, 0.0, false)
		kit.box(Vector3(1.8, 1.35, 0.05), p + Vector3(0, 0.675, -0.45), kit.m.carpet_grey)
		kit.box(Vector3(0.05, 1.35, 1.2), p + Vector3(-0.92, 0.675, 0.12), kit.m.carpet_grey)
		kit.box(Vector3(0.42, 0.36, 0.4), p + Vector3(0.25, 0.97, -0.15), Color(0.72, 0.7, 0.62), false)
		kit.box(Vector3(0.34, 0.27, 0.01), p + Vector3(0.25, 0.98, 0.055), Mat_screen(), false)
		var scr: Label3D = kit.label("", p + Vector3(0.25, 0.98, 0.062), 0.0, Color(0.5, 1.0, 0.55), 40, false)
		scr.pixel_size = 0.0025
		screens.append(scr)
		kit.box(Vector3(0.45, 0.025, 0.16), p + Vector3(0.2, 0.8, 0.22), Color(0.65, 0.63, 0.56), false)
		chairs.append(kit.chair(p + Vector3(0.1, 0, 0.6), 0.0))
	# items on six desks
	for k in 6:
		var w: Dictionary = WORKERS[k]
		var dp: Vector3 = DESK_POS[ITEM_DESKS[k]]
		kit.item("o_item_%d" % k, w.item, dp + Vector3(-0.45, 0.79, 0.12), w.look, w.col)
	# the camera sees Mahadev's name written above his desk
	var ghost := kit.label("MAHADEV", DESK_POS[ITEM_DESKS[4]] + Vector3(-0.3, 1.75, -0.42), 0.0, Color(0.6, 1.0, 0.6), 64, false)
	ghost.layers = 2
	# meeting table with 8 chairs, 4 chairs along the east wall → 24 total
	kit.table(Vector3(-4.0, 0, -17.4), Vector3(3.0, 0.74, 1.2))
	for x in [-5.0, -4.0, -3.0]:
		chairs.append(kit.chair(Vector3(x, 0, -16.55), 0.0))
		chairs.append(kit.chair(Vector3(x, 0, -18.25), PI))
	chairs.append(kit.chair(Vector3(-6.0, 0, -17.4), -PI / 2))
	chairs.append(kit.chair(Vector3(-2.0, 0, -17.4), PI / 2))
	for z in [-4.0, -7.0, -10.0, -13.0]:
		chairs.append(kit.chair(Vector3(9.4, 0, z), PI / 2))
	# notes, wall calendar stuck on June 1998
	kit.note("o_memo", DESK_POS[1] + Vector3(-0.3, 0.795, 0.1))
	kit.note("o_clerk", DESK_POS[ITEM_DESKS[4]] + Vector3(0.5, 0.006, 0.9))
	kit.box(Vector3(0.6, 0.8, 0.02), Vector3(3.0, 1.7, -18.98), kit.m.paper, false)
	kit.label("JUNE 1998\n\n 1  2  3  4  5  6  7\n 8  9 10 11 12 13 14", Vector3(3.0, 1.72, -18.96), 0.0, Color(0.1, 0.1, 0.1), 16)
	kit.label("14", Vector3(3.22, 1.48, -18.955), 0.0, Color(0.75, 0.05, 0.05), 26)
	# stairwell door
	kit.stair_exit(Vector3(7.0, 0, -19.03), 0.0, "STAIRS ▲  2")
	exit_hint = "Locked. Every desk must be empty before you leave."
	for p in [Vector3(-4, 3.2, -5.5), Vector3(4, 3.2, -5.5), Vector3(-4, 3.2, -12.5), Vector3(4, 3.2, -12.5), Vector3(-4, 3.2, -17.5), Vector3(7, 3.2, -17.5)]:
		kit.lamp(p, "tube", Color(0.92, 0.95, 1.0), 1.05, 7.5)

func Mat_screen() -> Material:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.02, 0.06, 0.03); m.emission_enabled = true
	m.emission = Color(0.05, 0.25, 0.08); m.emission_energy_multiplier = 1.2
	return m

# ---------------------------------------------------------------- puzzle
func on_item_taken(id: String, node: Node3D) -> bool:
	if not id.begins_with("o_item_"):
		return false
	if GameState.carry != "":
		hud.message("Your hands are full.", 2)
		return true
	var k := int(id.trim_prefix("o_item_"))
	if returned[k]:
		node.queue_free()
		return true
	GameState.carry = id
	node.queue_free()
	var named := "" if k == 4 else (" A strip of tape on it reads: " + str(WORKERS[k].name) + ".")
	hud.message("You pick up the %s.%s\nIt belongs in someone's locker." % [WORKERS[k].item, named], 4)
	return true

func on_use(id: String, _node: Node3D) -> void:
	if id.begins_with("locker:"):
		use_locker(int(id.trim_prefix("locker:")))

func use_locker(i: int) -> bool:
	var w: Dictionary = WORKERS[i]
	if returned[i]:
		hud.message("%s's locker. His things are inside now." % str(w.name).capitalize(), 2)
		return false
	if GameState.carry == "":
		hud.message("Locker — %s. Empty." % w.name, 2)
		return false
	if GameState.carry != "o_item_%d" % i:
		hud.message("This isn't his.", 2)
		Dread.add(3)
		return false
	GameState.carry = ""
	_mark_returned(i, true)
	var done: Array = []
	for j in 6:
		if returned[j]:
			done.append(j)
	GameState.checkpoint = {"returned": done}
	GameState.save_game()
	return true

func _mark_returned(i: int, announce: bool) -> void:
	returned[i] = true
	var card := "id_" + str(WORKERS[i].key)
	if not GameState.collectibles.has(card):
		GameState.collectibles.append(card)
	if announce:
		hud.message("You put the %s inside and close the door.\nClipped inside: an ID card — %s. You keep it." % [WORKERS[i].item, WORKERS[i].name], 4.5)
		GameState.save_game()
		if returned.count(true) == 1 and _extra_due < 0.0:
			_extra_due = randf_range(15.0, 35.0)
	if returned.count(true) == 6:
		unlock_exit("Every desk is empty. Somewhere in the north wall, a lock turns." if announce else "")

func desks_remaining() -> int:
	return returned.count(false)

# ---------------------------------------------------------------- 25th chair
func spawn_extra_chair() -> void:
	if extra_chair:
		return
	_extra_count += 1
	extra_chair = kit.chair(CHAIR_AISLE, 0.0)
	extra_chair.look_at(Vector3(player.global_position.x, 0, player.global_position.z), Vector3.UP)
	_extra_t = CHAIR_GRACE
	subtitle("(a chair scrapes slowly across the floor)", 3)
	Dread.add(8)
	for s in screens:
		s.text = "25"

func resolve_extra_chair() -> void:
	if not extra_chair:
		return
	extra_chair.queue_free()
	extra_chair = null
	for s in screens:
		s.text = ""
	hud.message("When you step back in, there are twenty-four again.", 3)
	if _extra_count < 2:
		_extra_due = randf_range(40.0, 80.0)

func chair_count() -> int:
	return chairs.size() + (1 if extra_chair else 0)

func floor_lights() -> Array: return kit.lights
func surface_at(p: Vector3) -> String: return "tile" if p.z > -0.9 else "carpet"

func _process(d: float) -> void:
	super._process(d)
	if GameState.carry != "":
		var k := int(GameState.carry.trim_prefix("o_item_"))
		hud.set_status("Holding: %s   ·   Torch %d%%" % [WORKERS[k].item, int(player.battery)])
	if finished or busy:
		return
	# the 25th chair
	if _extra_due > 0.0 and not extra_chair:
		_extra_due -= d
		if _extra_due <= 0.0 and player.global_position.z < -2.0:
			spawn_extra_chair()
	if extra_chair:
		if player.global_position.z > -0.9:
			resolve_extra_chair()
		else:
			_extra_t -= d
			if _extra_t <= 0.0:
				fall_down("There were twenty-five. You stayed.")
		return
	# monitors type a message one word at a time
	_type_t -= d
	if _type_t <= 0.0:
		_type_i += 1
		if _type_i < MESSAGE.size():
			screens[(_type_i * 5) % screens.size()].text = MESSAGE[_type_i]
			_type_t = 0.7
		else:
			for s in screens:
				s.text = ""
			_type_i = -1
			_type_t = randf_range(30.0, 50.0)
