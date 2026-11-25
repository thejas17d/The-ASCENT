extends Node
## Persistent run state: floor, checkpoint, inventory, story choices, settings.
## Saved as JSON at user://save.json.

const SAVE_PATH := "user://save.json"
const ITEM_DEFAULTS := {"battery": 1, "chalk": 15, "diya": 2}
const FLOOR_SCENES := {2: "res://scenes/floor_02.tscn"}

var floor_num := 2
var checkpoint := {}        # floor-specific, e.g. {"streak": 3}
var items := {}
var choices := {}           # "letter": "kept"/"burned", "workers": "freed"/"left"
var falls := 0              # times sent down a floor (hidden Floor 9 needs 0)
var collectibles: Array = []
var settings := {"sensitivity": 1.0, "scare_intensity": 1.0, "subtitles": true}

func _ready() -> void:
	_setup_input()
	new_game()

func new_game() -> void:
	floor_num = 2   # Ground/Floor 1 not built yet
	checkpoint = {}
	items = ITEM_DEFAULTS.duplicate()
	choices = {}
	falls = 0
	collectibles = []

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> void:
	var data := {
		"version": 1, "floor": floor_num, "checkpoint": checkpoint, "items": items,
		"choices": choices, "falls": falls, "collectibles": collectibles,
		"settings": settings, "dread": Dread.value,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  "))

func load_game() -> bool:
	if not has_save():
		return false
	var data = JSON.parse_string(FileAccess.open(SAVE_PATH, FileAccess.READ).get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return false
	floor_num = int(data.get("floor", 2))
	checkpoint = data.get("checkpoint", {})
	items = {}
	for k in data.get("items", ITEM_DEFAULTS):
		items[k] = int(data.items[k])
	choices = data.get("choices", {})
	falls = int(data.get("falls", 0))
	collectibles = data.get("collectibles", [])
	settings.merge(data.get("settings", {}), true)
	Dread.reset(float(data.get("dread", 0.0)))
	return true

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

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
	return FLOOR_SCENES.get(floor_num, FLOOR_SCENES[2])

func _setup_input() -> void:
	var map := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"run": [KEY_SHIFT], "interact": [KEY_E], "flashlight": [KEY_F],
		"reload": [KEY_R], "chalk": [KEY_C], "diya": [KEY_G], "phone": [KEY_Q],
		"breath": [KEY_SPACE], "inventory": [KEY_TAB],
	}
	for a in map:
		if InputMap.has_action(a):
			continue
		InputMap.add_action(a)
		for k in map[a]:
			var ev := InputEventKey.new(); ev.physical_keycode = k
			InputMap.action_add_event(a, ev)
