extends Control
## Title screen: a slow camera drift down the corridor behind the menu.
## Continue / New Game / Settings / Quit.

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const Settings := preload("res://scripts/ui/settings_panel.gd")
const Corridor := preload("res://scripts/floors/corridor.gd")
const POST := preload("res://shaders/post_fx.gdshader")
const Sfx := preload("res://scripts/systems/sfx.gd")
const Memories := preload("res://scripts/systems/memories.gd")
const Leaderboard := preload("res://scripts/systems/leaderboard.gd")

var _cam: Camera3D
var _box: VBoxContainer
var _settings: Control
var _t := 0.0

func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	theme = UiTheme.get_theme()
	_build_backdrop()
	var shade := ColorRect.new(); shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.35); shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_box = VBoxContainer.new()
	_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	_box.offset_left = 120; _box.offset_right = 560; _box.offset_top = -330; _box.offset_bottom = 330
	_box.add_theme_constant_override("separation", 10)
	add_child(_box)
	var t := Label.new(); t.text = "THE ASCENT"
	t.add_theme_font_size_override("font_size", 64)
	t.add_theme_color_override("font_color", Color(0.85, 0.8, 0.68))
	_box.add_child(t)
	var sub := Label.new(); sub.text = "Meridian Tower  ·  Mumbai  ·  3:33 AM"
	sub.add_theme_color_override("font_color", UiTheme.DIM)
	_box.add_child(sub)
	_box.add_child(Control.new())
	if GameState.has_save():
		var ok := GameState.load_game()
		var cont := _button("Continue", _continue)
		if not ok or not GameState.floor_available(GameState.floor_num):
			cont.disabled = true
			cont.text = "Continue — Floor %d coming soon" % GameState.floor_num
		GameState.new_game()   # loading was only a peek
	_button("New Game", _new)
	if GameState.unlocks.get("new_game_plus", false):
		_button("New Game+  —  Night Shift", _new_night)
	_button("Daily Corridor  (best today: %d)" % Leaderboard.best(Leaderboard.today()), _daily)
	if GameState.unlocks.get("floor9", false):
		_button("Floor 9", _floor9)
	_button("Memories  (%d / %d)" % [Memories.found().size(), Memories.all().size()], _open_memories)
	_button("Test: The Supervisor", func(): get_tree().change_scene_to_file("res://scenes/dev/supervisor_test.tscn"))
	_button("Settings", _open_settings)
	_button("Quit", func(): get_tree().quit())
	var ver := Label.new()
	ver.text = "v" + str(ProjectSettings.get_setting("application/config/version", "dev"))
	ver.add_theme_color_override("font_color", UiTheme.DIM)
	ver.add_theme_font_size_override("font_size", 14)
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.offset_left = -120; ver.offset_top = -36; ver.offset_right = -20; ver.offset_bottom = -12
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(ver)
	var hint := Label.new(); hint.text = "Headphones recommended."
	hint.add_theme_color_override("font_color", UiTheme.DIM)
	hint.add_theme_font_size_override("font_size", 15)
	_box.add_child(hint)
	(_box.get_child(3) as Button).call_deferred("grab_focus")

func _build_backdrop() -> void:
	var world := Node3D.new(); add_child(world)
	var we := WorldEnvironment.new(); we.environment = Graphics.make_environment()
	world.add_child(we)
	var c := Corridor.new(); world.add_child(c)
	c.build("", 0, false, 1)
	_cam = Camera3D.new(); _cam.fov = 60
	world.add_child(_cam)
	_cam.position = Vector3(0.25, 1.5, 1.5)
	_cam.make_current()
	var torch := SpotLight3D.new()
	torch.spot_range = 18; torch.spot_angle = 24; torch.light_energy = 2.2
	torch.light_volumetric_fog_energy = 2.0; torch.shadow_enabled = true
	_cam.add_child(torch)
	var fx := ColorRect.new(); fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new(); m.shader = POST
	m.set_shader_parameter("dread", 0.15); m.set_shader_parameter("aberration", 2.0)
	m.set_shader_parameter("grain", 0.05 * float(GameState.settings.get("grain", 1.0)))
	fx.material = m
	add_child(fx)
	var hum := AudioStreamPlayer.new(); hum.stream = Sfx.get_stream("hum")
	hum.bus = "Ambience"; hum.volume_db = -14; hum.autoplay = true
	add_child(hum)

func _process(d: float) -> void:
	_t += d
	# slow dolly that loops before the corridor's end
	_cam.position.z = 1.5 - fmod(_t * 0.6, 34.0)
	_cam.rotation.y = sin(_t * 0.15) * 0.06
	_cam.rotation.x = -0.03 + sin(_t * 0.11) * 0.02

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new(); b.text = text; b.custom_minimum_size = Vector2(360, 42)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(cb); _box.add_child(b)
	return b

func _open_settings() -> void:
	_box.visible = false
	_settings = Settings.new()
	_settings.closed.connect(func():
		_settings.queue_free(); _settings = null
		_box.visible = true)
	add_child(_settings)

func _continue() -> void:
	if GameState.load_game() and GameState.floor_available(GameState.floor_num):
		get_tree().change_scene_to_file(GameState.floor_scene())

func _new_night() -> void:
	GameState.new_game("night", true)
	Dread.reset(0.0)
	GameState.save_game()
	get_tree().change_scene_to_file(GameState.floor_scene())

func _daily() -> void:
	GameState.new_game("daily")
	Dread.reset(0.0)
	get_tree().change_scene_to_file(GameState.FLOOR_SCENES[2])

func _floor9() -> void:
	GameState.new_game("floor9")
	Dread.reset(0.0)
	get_tree().change_scene_to_file(GameState.FLOOR_SCENES[9])

## Journal of everything found across all runs.
func _open_memories() -> void:
	_box.visible = false
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 120; panel.offset_right = -120; panel.offset_top = 80; panel.offset_bottom = -80
	add_child(panel)
	var v := VBoxContainer.new(); panel.add_child(v)
	var head := Label.new()
	head.text = "MEMORIES   —   %d of %d found" % [Memories.found().size(), Memories.all().size()]
	head.add_theme_font_size_override("font_size", 28)
	v.add_child(head)
	var h := HBoxContainer.new(); h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_theme_constant_override("separation", 24)
	v.add_child(h)
	var scroll := ScrollContainer.new(); scroll.custom_minimum_size.x = 420
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_child(scroll)
	var list := VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var text := Label.new(); text.autowrap_mode = TextServer.AUTOWRAP_WORD
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.text = "Choose a memory."
	h.add_child(text)
	var found_ids: Array = GameState.unlocks.get("memories", [])
	for m in Memories.all():
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var label := "G" if int(m.floor) == 0 else str(m.floor)
		if found_ids.has(m.id):
			b.text = "%s · %s" % [label, m.title]
			b.pressed.connect(func(): text.text = "%s

%s" % [str(m.title).to_upper(), m.text])
		else:
			b.text = "%s · ???" % label
			b.disabled = true
		list.add_child(b)
	var back := Button.new(); back.text = "Back"
	back.pressed.connect(func():
		panel.queue_free()
		_box.visible = true)
	v.add_child(back)

func _new() -> void:
	GameState.new_game()
	Dread.reset(0.0)
	GameState.save_game()
	get_tree().change_scene_to_file(GameState.floor_scene())
