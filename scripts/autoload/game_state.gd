extends Node
## Persistent run state: floor, checkpoint, inventory, story choices.
## Run progress -> user://save.json ; preferences -> user://settings.json
## (kept separate so New Game never wipes your settings).

const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.json"
const ITEM_DEFAULTS := {"battery": 1, "chalk": 15, "diya": 2}
const FLOOR_SCENES := {
	9: "res://scenes/floor_09.tscn",
	0: "res://scenes/floor_g.tscn", 1: "res://scenes/floor_01.tscn", 2: "res://scenes/floor_02.tscn",
	3: "res://scenes/floor_03.tscn", 4: "res://scenes/floor_04.tscn", 5: "res://scenes/floor_05.tscn",
	6: "res://scenes/floor_06.tscn", 7: "res://scenes/floor_07.tscn", 8: "res://scenes/floor_08.tscn",
}
const STAIRWELL := "res://scenes/stairwell.tscn"
const ENDING := "res://scenes/ending.tscn"
const LETHAL_FROM := 5      # floors >= this kill; below, failure sends you down a floor
const FLOOR_NAMES := ["RECEPTION", "THE OFFICE", "THE CORRIDOR", "RECORDS", "THE RESIDENCE",
	"THE HUNT", "THE INVERSION", "THE COLLAPSE", "THE ROOF", "THE BLUEPRINT"]
const NG_PLUS_BONUS := {"battery": 2, "diya": 2}
const DEFAULT_SETTINGS := {
	"quality": -1,              # -1 = auto (High on desktop, Medium on mobile)
	"fullscreen": false,
	"sensitivity": 1.0,
	"scare_intensity": 1.0,     # scales dread gains
	"grain": 1.0,               # film grain strength 0..1.5
	"reduced_flashing": false,
	"subtitles": true,
	"vol_master": 1.0, "vol_sfx": 1.0, "vol_ambience": 1.0,
	"touch_controls": 0,        # 0 auto (phones), 1 always, 2 never
	"touch_sensitivity": 1.0,
	"gyro": false,              # tilt the phone to look
	"haptics": true,
	"auto_level": -1,           # remembered Auto quality (set when Auto steps down)
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
var mode := "normal"        # "normal" · "night" (Night Shift) · "daily" · "floor9"
var ng_plus := false
var settings := DEFAULT_SETTINGS.duplicate()
var _applied_once := false

func _ready() -> void:
	_setup_input()
	_setup_audio_buses()
	_setup_ui_sounds()
	load_settings()
	_load_unlocks()
	new_game()

func new_game(run_mode := "normal", plus := false) -> void:
	mode = run_mode
	ng_plus = plus
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
	if plus:
		for k in NG_PLUS_BONUS:
			items[k] = count(k) + NG_PLUS_BONUS[k]

# ---------------------------------------------------------------- save
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func floor_available(n: int) -> bool:
	return FLOOR_SCENES.has(n)

## Night Shift, Daily and Floor 9 helpers -------------------------------
## On-screen touch controls: automatic on phones, forceable in Settings.
func touch_active() -> bool:
	match int(settings.get("touch_controls", 0)):
		1: return true
		2: return false
	return OS.has_feature("mobile")

func night() -> bool:
	return mode == "night"

## Story runs save; side modes (daily corridor, floor 9) never touch the save.
func story_run() -> bool:
	return mode == "normal" or mode == "night"

## Every light in the building is dimmer on the Night Shift.
func light_scale() -> float:
	return 0.6 if night() else 1.0

func save_game() -> bool:
	_remember()
	if not story_run():
		return true
	var data := {
		"version": 2, "floor": floor_num, "checkpoint": checkpoint, "items": items,
		"choices": choices, "falls": falls, "deaths": deaths, "collectibles": collectibles,
		"altered": altered, "solved": solved, "carry": carry, "mode": mode, "ng_plus": ng_plus, "dread": Dread.value, "unlocks": unlocks,
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
	mode = str(data.get("mode", "normal"))
	ng_plus = bool(data.get("ng_plus", false))
	solved = {}
	for k in _dict(data.get("solved")):
		solved[int(k)] = true
	var saved_unlocks := _dict(data.get("unlocks"))
	var mem: Array = unlocks.get("memories", [])
	for m in saved_unlocks.get("memories", []):
		if not mem.has(m):
			mem.append(m)
	unlocks.merge(saved_unlocks, false)     # never overwrite newer unlocks
	unlocks["memories"] = mem
	var c = data.get("collectibles", [])
	collectibles = c if typeof(c) == TYPE_ARRAY else []
	Dread.reset(minf(float(data.get("dread", 0.0)), 70.0))
	return true

func _dict(v) -> Dictionary:
	return v if typeof(v) == TYPE_DICTIONARY else {}

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

## Memories: everything you've ever read or found, across all runs.
func _remember() -> void:
	var mem: Array = unlocks.get("memories", [])
	var changed := false
	for c in collectibles:
		if not mem.has(c):
			mem.append(c); changed = true
	if changed:
		unlocks["memories"] = mem
		save_unlocks()

func save_unlocks() -> void:
	var f := FileAccess.open("user://unlocks.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(unlocks))

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
	Graphics.auto_mode = q < 0
	if q < 0:   # Auto: what we learned last time, else a GPU-based guess
		var learned := int(settings.get("auto_level", -1))
		q = learned if learned >= 0 else Graphics.detect_level()
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
## Every Button in every menu/dialog clicks (CC0 Kenney interface sounds).
var _ui_player: AudioStreamPlayer
func _setup_ui_sounds() -> void:
	_ui_player = AudioStreamPlayer.new()
	_ui_player.stream = preload("res://scripts/systems/sfx.gd").get_stream("ui_click")
	_ui_player.volume_db = -8
	_ui_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ui_player)
	get_tree().node_added.connect(func(n):
		if n is BaseButton and not n.pressed.is_connected(_ui_click):
			n.pressed.connect(_ui_click))

func _ui_click() -> void:
	if _ui_player and _ui_player.is_inside_tree():
		_ui_player.play()

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
		"breath": [KEY_SPACE], "inventory": [KEY_TAB], "voice": [KEY_V], "pause": [KEY_ESCAPE, KEY_P],
		"fullscreen": [KEY_F11],
	}
	for a in map:
		if InputMap.has_action(a):
			continue
		InputMap.add_action(a)
		for k in map[a]:
			var ev := InputEventKey.new(); ev.physical_keycode = k
			InputMap.action_add_event(a, ev)
