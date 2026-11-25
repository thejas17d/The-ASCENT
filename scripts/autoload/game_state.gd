extends Node
## Persistent run state: floor, checkpoint, inventory, story choices.
## Run progress -> user://save.json ; preferences -> user://settings.json
## (kept separate so New Game never wipes your settings).

const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.json"
const ITEM_DEFAULTS := {"battery": 1, "chalk": 15, "diya": 2}
const FLOOR_SCENES := {
	0: "res://scenes/floor_g.tscn", 1: "res://scenes/floor_01.tscn", 2: "res://scenes/floor_02.tscn",
	3: "res://scenes/floor_03.tscn", 4: "res://scenes/floor_04.tscn", 5: "res://scenes/floor_05.tscn",
	6: "res://scenes/floor_06.tscn", 7: "res://scenes/floor_07.tscn", 8: "res://scenes/floor_08.tscn",
}
const STAIRWELL := "res://scenes/stairwell.tscn"
const ENDING := "res://scenes/ending.tscn"
const LETHAL_FROM := 5      # floors >= this kill; below, failure sends you down a floor
const FLOOR_NAMES := ["RECEPTION", "THE OFFICE", "THE CORRIDOR", "RECORDS", "THE RESIDENCE",
	"THE HUNT", "THE INVERSION", "THE COLLAPSE", "THE ROOF"]
const DEFAULT_SETTINGS := {
	"quality": -1,              # -1 = auto (High on desktop, Medium on mobile)
	"fullscreen": false,
	"sensitivity": 1.0,
	"scare_intensity": 1.0,     # scales dread gains
	"grain": 1.0,               # film grain strength 0..1.5
	"reduced_flashing": false,
	"subtitles": true,
	"vol_master": 1.0, "vol_sfx": 1.0, "vol_ambience": 1.0,
}

var floor_num := 2
var checkpoint := {}        # floor-specific, e.g. {"streak": 3}
var items := {}
var choices := {}           # "letter": "kept"/"burned", "workers": "freed"/"left"
var falls := 0              # times sent down a floor (hidden Floor 9 needs 0)
var collectibles: Array = []
var altered := {}           # floor -> times you were sent back to it (adds anomalies)
var deaths := 0
var carry := ""             # puzzle item currently in hand (Floor 1)
var stair_from := -1        # floor just completed (stairwell scene reads it)
var unlocks := {}           # "floor9", "new_game_plus", endings seen
var solved := {}            # floor -> true once its puzzle was completed
var test_mode := false      # tests: record scene changes instead of performing them
var last_scene_request := ""
var settings := DEFAULT_SETTINGS.duplicate()
var _applied_once := false

func _ready() -> void:
	_setup_input()
	_setup_audio_buses()
	load_settings()
	_load_unlocks()
	new_game()

func new_game() -> void:
	floor_num = 0
	checkpoint = {}
	items = ITEM_DEFAULTS.duplicate()
	choices = {}
	falls = 0
	deaths = 0
	collectibles = []
	altered = {}
	solved = {}
	carry = ""
	stair_from = -1

# ---------------------------------------------------------------- save
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func floor_available(n: int) -> bool:
	return FLOOR_SCENES.has(n)

func save_game() -> bool:
	var data := {
		"version": 2, "floor": floor_num, "checkpoint": checkpoint, "items": items,
		"choices": choices, "falls": falls, "deaths": deaths, "collectibles": collectibles,
		"altered": altered, "solved": solved, "carry": carry, "dread": Dread.value, "unlocks": unlocks,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write save: %s" % FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(data, "  "))
	return true

func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return false
	floor_num = int(data.get("floor", 2))
	checkpoint = _dict(data.get("checkpoint"))
	items = ITEM_DEFAULTS.duplicate()
	var src := _dict(data.get("items"))
	for k in src:
		items[k] = int(src[k])
	choices = _dict(data.get("choices"))
	falls = int(data.get("falls", 0))
	deaths = int(data.get("deaths", 0))
	altered = {}
	var alt := _dict(data.get("altered"))
	for k in alt:
		altered[int(k)] = int(alt[k])
	carry = str(data.get("carry", ""))
	solved = {}
	for k in _dict(data.get("solved")):
		solved[int(k)] = true
	unlocks.merge(_dict(data.get("unlocks")), true)
	var c = data.get("collectibles", [])
	collectibles = c if typeof(c) == TYPE_ARRAY else []
	Dread.reset(minf(float(data.get("dread", 0.0)), 70.0))
	return true

func _dict(v) -> Dictionary:
	return v if typeof(v) == TYPE_DICTIONARY else {}

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

## Unlocks (endings seen, Floor 9, New Game+) survive finished runs.
func _load_unlocks() -> void:
	if FileAccess.file_exists("user://unlocks.json"):
		var f := FileAccess.open("user://unlocks.json", FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text()) if f else null
		if typeof(d) == TYPE_DICTIONARY:
			unlocks = d

# ---------------------------------------------------------------- settings
func load_settings() -> void:
	settings = DEFAULT_SETTINGS.duplicate()
	if FileAccess.file_exists(SETTINGS_PATH):
		var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		var data = JSON.parse_string(f.get_as_text()) if f else null
		if typeof(data) == TYPE_DICTIONARY:
			for k in DEFAULT_SETTINGS:
				if data.has(k) and typeof(data[k]) in [TYPE_FLOAT, TYPE_INT, TYPE_BOOL]:
					settings[k] = data[k]
	apply_settings()

func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings, "  "))

func apply_settings() -> void:
	var q := int(settings.quality)
	q = q if q >= 0 else (1 if Graphics.is_mobile() else 2)
	if q != Graphics.quality or not _applied_once:
		Graphics.apply(q)
	_applied_once = true
	if not Graphics.is_mobile() and DisplayServer.get_name() != "headless":
		var want := DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		var cur := DisplayServer.window_get_mode()
		var is_full := cur == DisplayServer.WINDOW_MODE_FULLSCREEN or cur == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		if is_full != bool(settings.fullscreen):
			DisplayServer.window_set_mode(want)
	for b in ["master", "sfx", "ambience"]:
		var idx := AudioServer.get_bus_index(b.capitalize() if b != "sfx" else "SFX")
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, linear_to_db(max(0.0001, float(settings["vol_" + b]))))

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("fullscreen"):
		settings.fullscreen = not settings.fullscreen
		apply_settings()
		save_settings()

# ---------------------------------------------------------------- items
func count(id: String) -> int:
	return int(items.get(id, 0))

func add_item(id: String, n := 1) -> void:
	items[id] = count(id) + n

func use_item(id: String, n := 1) -> bool:
	if count(id) < n:
		return false
	items[id] = count(id) - n
	return true

func floor_scene() -> String:
	return FLOOR_SCENES.get(floor_num, FLOOR_SCENES[0])

func floor_name(n: int) -> String:
	return FLOOR_NAMES[n] if n >= 0 and n < FLOOR_NAMES.size() else "?"

func floor_label(n: int) -> String:
	return "G" if n == 0 else str(n)

func solved_floor(n: int) -> bool:
	return solved.has(n)

func is_lethal(n: int) -> bool:
	return n >= LETHAL_FROM

func altered_level(n: int) -> int:
	return int(altered.get(n, 0))

## Every scene change goes through here so tests can intercept it.
func go(scene: String) -> void:
	last_scene_request = scene
	if test_mode:
		return
	get_tree().change_scene_to_file(scene)

# ---------------------------------------------------------------- setup
## Buses: Master <- SFX (corridor reverb) , Ambience.
func _setup_audio_buses() -> void:
	if AudioServer.get_bus_index("SFX") >= 0:
		return
	for n in ["SFX", "Ambience"]:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, n)
		AudioServer.set_bus_send(i, "Master")
	var rv := AudioEffectReverb.new()
	rv.room_size = 0.55; rv.damping = 0.6; rv.spread = 0.8
	rv.wet = 0.22; rv.dry = 0.9; rv.predelay_msec = 25
	AudioServer.add_bus_effect(AudioServer.get_bus_index("SFX"), rv)

func _setup_input() -> void:
	var map := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"run": [KEY_SHIFT], "crouch": [KEY_CTRL], "interact": [KEY_E], "flashlight": [KEY_F],
		"reload": [KEY_R], "chalk": [KEY_C], "diya": [KEY_G], "phone": [KEY_Q],
		"breath": [KEY_SPACE], "inventory": [KEY_TAB], "pause": [KEY_ESCAPE, KEY_P],
		"fullscreen": [KEY_F11],
	}
	for a in map:
		if InputMap.has_action(a):
			continue
		InputMap.add_action(a)
		for k in map[a]:
			var ev := InputEventKey.new(); ev.physical_keycode = k
			InputMap.action_add_event(a, ev)
