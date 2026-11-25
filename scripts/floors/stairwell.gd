extends FloorBase
## Stairwell interlude between floors: one concrete flight, a scrawled wall,
## a memory (voice lines as subtitles), and a checkpoint. Walk up and through
## the door to reach the next floor.

var kit: Kit
var _voice_i := 0
var _voice_t := 1.5
var _voice: Array = []
var _top: Node3D

func _ready() -> void:
	var from: int = GameState.stair_from if GameState.stair_from >= 0 else max(0, GameState.floor_num - 1)
	floor_index = from + 1
	kit = Kit.new(self)
	_build(from)
	setup_common()
	director.enabled = false
	spawn = Vector3(0, 0.05, -0.6)
	spawn_yaw = 0.0
	player.teleport(spawn)
	GameState.floor_num = floor_index
	GameState.checkpoint = {}
	GameState.save_game()
	hud.fade_to(0.0, 1.2)
	var story: Dictionary = JSON.parse_string(FileAccess.open("res://data/story/stairwell.json", FileAccess.READ).get_as_text())
	var beat: Dictionary = story.get(str(from), {})
	_voice = beat.get("voice", [])
	if beat.has("wall"):
		kit.label(str(beat.wall), Vector3(-1.08, 2.4, -4.2), PI / 2, Color(0.75, 0.08, 0.06), 64)

func _build(from: int) -> void:
	var conc: Material = kit.m.concrete
	var wall: Material = kit.m.paint
	# bottom landing z 0..-2 (y 0), flight z -2..-6 rising 3 m, top landing z -6..-8 (y 3)
	kit.box(Vector3(2.4, 0.2, 2.4), Vector3(0, -0.1, -0.8), conc)
	kit.box(Vector3(2.4, 0.2, 2.2), Vector3(0, 2.9, -7.1), conc)
	# invisible ramp for walking, visible steps on top
	var ramp := kit.box(Vector3(2.0, 0.1, 5.0), Vector3(0, 1.45, -4.0), conc)
	ramp.rotation.x = atan2(3.0, 4.0)
	(ramp.get_child(1) as MeshInstance3D).visible = false
	for i in 12:
		var y := 0.125 + i * 0.25
		kit.box(Vector3(2.0, 0.25, 0.34), Vector3(0, y - 0.125 + 0.0, -2.17 - i * 0.333), conc, false)
		kit.box(Vector3(2.02, 0.03, 0.06), Vector3(0, y + 0.01, -2.03 - i * 0.333), kit.m.metal_grey, false)
	# under-stair mass so the flight looks solid
	var under := kit.box(Vector3(2.0, 0.3, 5.0), Vector3(0, 1.25, -4.0), conc, false)
	under.rotation.x = atan2(3.0, 4.0)
	# walls and ceiling
	kit.box(Vector3(0.2, 7.0, 9.0), Vector3(-1.2, 2.5, -3.5), wall)
	kit.box(Vector3(0.2, 7.0, 9.0), Vector3(1.2, 2.5, -3.5), wall)
	kit.box(Vector3(2.6, 7.0, 0.2), Vector3(0, 2.5, 0.6), wall)
	kit.box(Vector3(2.6, 3.0, 0.2), Vector3(0, 4.5, -8.3), wall)
	kit.box(Vector3(2.6, 3.0, 0.2), Vector3(0, 1.4, -8.3), wall)   # closes the void under the top landing
	kit.box(Vector3(2.6, 0.2, 9.0), Vector3(0, 6.1, -3.5), kit.m.ceiling)
	# handrail
	var rail := kit.box(Vector3(0.05, 0.05, 5.1), Vector3(1.0, 2.35, -4.0), kit.m.metal_grey, false)
	rail.rotation.x = atan2(3.0, 4.0)
	# doors: the one behind you is gone; the one above leads on
	kit.box(Vector3(1.0, 2.1, 0.06), Vector3(0, 1.05, 0.47), kit.m.metal).set_meta("prompt", "The way down is gone")
	var sign := "FLOOR %s ▲" % GameState.floor_label(from + 1)
	_top = kit.stair_exit(Vector3(0, 3.0, -8.17), 0.0, sign)
	_top.set_meta("prompt", "Floor %s — %s" % [GameState.floor_label(from + 1), GameState.floor_name(from + 1)])
	exit_unlocked = true
	# painted floor numbers
	kit.label(GameState.floor_label(from), Vector3(0, 3.1, 0.36), PI, Color(0.12, 0.11, 0.1), 260)
	kit.label(GameState.floor_label(from + 1), Vector3(1.09, 4.6, -7.0), -PI / 2, Color(0.12, 0.11, 0.1), 260)
	kit.prop("fire_alarm", Vector3(-1.09, 1.5, -1.2), PI / 2, Vector3.ZERO, false)
	kit.prop("korean_fire_extinguisher_01", Vector3(0.85, 0, -0.2), PI)
	kit.lamp(Vector3(0, 3.0, -0.8), "bulb", Color(1.0, 0.82, 0.55), 1.0, 5.0, true)
	kit.lamp(Vector3(0, 6.0, -7.0), "bulb", Color(1.0, 0.82, 0.55), 1.0, 5.0, true)

func complete_floor() -> void:
	# the stairwell's exit leads into the floor whose number is painted on it
	if busy:
		return
	busy = true
	finished = true
	player.input_enabled = false
	GameState.stair_from = -1
	GameState.save_game()
	await hud.fade_to(1.0, 0.8)
	GameState.go(GameState.floor_scene())

func world_root() -> Node3D: return self
func floor_lights() -> Array: return kit.lights
func surface_at(_p: Vector3) -> String: return "concrete"

func _process(d: float) -> void:
	super._process(d)
	if _voice_i < _voice.size():
		_voice_t -= d
		if _voice_t <= 0.0:
			hud.message(str(_voice[_voice_i]), 4.0)
			_voice_i += 1
			_voice_t = 4.2
