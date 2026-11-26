extends Node3D
## Opening: Meridian Tower in the monsoon, 03:31. The camera walks in from the
## street while four lines set the story, then the lobby light pulls you inside.
## Plays on New Game; any key, click or tap skips. ~24 s.

const Skyline := preload("res://scripts/world/skyline.gd")
const Mat := preload("res://scripts/systems/mat_lib.gd")
const Props := preload("res://scripts/world/props.gd")
const Sfx := preload("res://scripts/systems/sfx.gd")
const Fonts := preload("res://scripts/ui/fonts.gd")
const Characters := preload("res://scripts/world/characters.gd")
const LENGTH := 24.0
const LINES := [
	[1.2, "MUMBAI  ·  03:31"],
	[6.0, "Meridian Tower. Sealed since the night it fell —\n14 June 1998."],
	[11.5, "Papa went up that night.\nHe never came down."],
	[17.0, "Tonight, the door is open."],
]
const TOWER := Vector3(0, 0, -22)
const CAM_FROM := Vector3(1.2, 1.62, 26.0)
const CAM_TO := Vector3(0.0, 1.66, -6.5)

var _cam: Camera3D
var _t := 0.0
var _done := false
var _line := -1
var _caption: Label
var _fade: ColorRect
var _moon: DirectionalLight3D
var _bolt := 5.0
var _beacon: OmniLight3D
var _window_light: OmniLight3D
var tower: Node3D
var figure: Node3D               # someone waiting in the doorway — gone in the lightning
var _figure_state := 0

func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	var we := WorldEnvironment.new(); we.environment = Graphics.make_environment()
	add_child(we)
	var env: Environment = Graphics.env
	Skyline.night_sky(env, Color(0.012, 0.014, 0.024), Color(0.22, 0.11, 0.05), Color(0.012, 0.01, 0.01), 0.9)
	env.ambient_light_color = Color(0.28, 0.3, 0.38)
	env.volumetric_fog_density = 0.035
	env.volumetric_fog_albedo = Color(0.75, 0.8, 0.9)
	_build_street()
	_build_tower()
	Skyline.build(self, TOWER, 1998, -0.3, Color(0.02, 0.022, 0.03), Color(1.0, 0.72, 0.38), 0.18)
	_moon = Skyline.moon(self, Color(0.6, 0.68, 0.92), 0.35, Vector3(-0.55, 0.5, 0))
	_rain()
	_audio()
	var p := ReflectionProbe.new()          # wet street: reflections of the lamps and the lobby
	p.size = Vector3(40, 16, 60); p.position = Vector3(0, 6, 0)
	p.update_mode = ReflectionProbe.UPDATE_ONCE; p.box_projection = true
	add_child(p)
	_cam = Camera3D.new(); _cam.fov = 62; _cam.near = 0.05
	_cam.position = CAM_FROM
	add_child(_cam); _cam.make_current()
	_ui()

# ---------------------------------------------------------------- the street
func _build_street() -> void:
	var asphalt := Mat.pbr("concrete_floor_worn_001", 3.0, Color(0.3, 0.3, 0.32), 0.22)   # soaked
	_box(Vector3(240, 0.2, 240), Vector3(0, -0.1, 0), asphalt)
	var kerb := Mat.pbr("concrete_floor_worn_001", 1.5, Color(0.55, 0.53, 0.5), 0.5)
	_box(Vector3(40, 0.16, 6), Vector3(0, 0.08, -12), kerb)             # footpath in front of the tower
	for x in [-12.0, 12.0]:                                               # compound wall stubs
		_box(Vector3(10, 1.6, 0.3), Vector3(x, 0.8, -9.2), Mat.pbr("painted_plaster_wall", 2.0, Color(0.6, 0.56, 0.5)))
	for side in [-1, 1]:                                                  # sodium street lamps
		var lp := Vector3(side * 6.5, 0.16, -10.0)
		var lamp := Props.spawn("street_lamp_01", Vector3(0, 5.5, 0), false)
		if lamp:
			lamp.position = lp; lamp.rotation.y = PI / 2 if side < 0 else -PI / 2
			add_child(lamp)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.58, 0.24); l.light_energy = 3.0; l.omni_range = 16.0
		l.light_volumetric_fog_energy = 2.5
		l.shadow_enabled = Graphics.quality >= 1
		l.position = lp + Vector3(-side * 0.8, 5.3, 0)
		add_child(l)
	for k in 6:                                                           # puddles: glossy dark patches
		var pd := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(randf_range(1.5, 3.5), randf_range(1.0, 2.5))
		pd.mesh = pm
		var wm := StandardMaterial3D.new(); wm.albedo_color = Color(0.03, 0.035, 0.04); wm.roughness = 0.02; wm.metallic = 0.4
		pd.material_override = wm
		pd.position = Vector3(randf_range(-5, 5), 0.012, randf_range(-6, 18)); pd.rotation.y = randf() * TAU
		add_child(pd)

# ---------------------------------------------------------------- Meridian Tower
func _build_tower() -> void:
	tower = Node3D.new(); tower.position = TOWER; add_child(tower)
	var facade := Mat.pbr("painted_plaster_wall", 3.0, Color(0.5, 0.47, 0.45))
	var slab := Mat.pbr("concrete_floor_worn_001", 2.0, Color(0.42, 0.4, 0.38))
	var dark_glass := StandardMaterial3D.new(); dark_glass.albedo_color = Color(0.02, 0.025, 0.03); dark_glass.roughness = 0.08; dark_glass.metallic = 0.5
	var floors := 9
	var h := 3.6
	_box(Vector3(18, floors * h, 14), Vector3(0, floors * h / 2, 0), facade, tower)
	for f in floors + 1:                                                  # slab edges
		_box(Vector3(18.4, 0.25, 14.4), Vector3(0, f * h, 0), slab, tower)
	for f in range(1, floors):                                            # windows, all dark…
		for k in 6:
			var x := -7.0 + k * 2.8
			_box(Vector3(1.7, 1.6, 0.1), Vector3(x, f * h + 1.6, 7.02), dark_glass, tower)
	# …except one on the eighth floor, where a light still flickers
	var lit := Mat.emissive(Color(1.0, 0.82, 0.55), 3.0)
	_box(Vector3(1.7, 1.6, 0.1), Vector3(1.4, 8 * h + 1.6, 7.03), lit, tower)
	_window_light = OmniLight3D.new(); _window_light.light_color = Color(1.0, 0.8, 0.5)
	_window_light.light_energy = 1.5; _window_light.omni_range = 6.0
	_window_light.position = Vector3(1.4, 8 * h + 1.6, 8.0); tower.add_child(_window_light)
	# scaffolding and green safety netting on the unfinished top floors
	var pole := Mat.solid(Color(0.35, 0.33, 0.3), 0.6, 0.5)
	for x in range(-9, 10, 3):
		_box(Vector3(0.06, 3 * h, 0.06), Vector3(x, 7.5 * h, 7.6), pole, tower)
	for f in range(6, 10):
		_box(Vector3(18.5, 0.06, 0.06), Vector3(0, f * h, 7.6), pole, tower)
	var net := StandardMaterial3D.new(); net.albedo_color = Color(0.1, 0.35, 0.18, 0.55)
	net.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; net.cull_mode = BaseMaterial3D.CULL_DISABLED
	_box(Vector3(18.5, 2.6 * h, 0.02), Vector3(0, 7.5 * h + 0.6, 7.7), net, tower)
	# crane on the roof with a red aviation light
	var steel := Mat.solid(Color(0.5, 0.36, 0.12), 0.6, 0.5)
	_box(Vector3(0.8, 12, 0.8), Vector3(-5, floors * h + 6, -3), steel, tower)
	var boom := _box(Vector3(18, 0.6, 0.6), Vector3(1, floors * h + 12, -3), steel, tower)
	boom.rotation.z = -0.05
	_beacon = OmniLight3D.new(); _beacon.light_color = Color(1, 0.08, 0.04); _beacon.light_energy = 3.0; _beacon.omni_range = 8.0
	_beacon.position = Vector3(-5, floors * h + 12.6, -3); tower.add_child(_beacon)
	_box(Vector3(0.3, 0.3, 0.3), _beacon.position, Mat.emissive(Color(1, 0.1, 0.05), 6.0), tower)
	# the entrance: a canopy, the name in brass, and the lobby light spilling out
	_box(Vector3(5.0, 3.0, 0.04), Vector3(0, 1.5, 7.02), Mat.solid(Color(0.03, 0.03, 0.03)), tower)   # doorway surround
	_box(Vector3(6.4, 0.25, 2.2), Vector3(0, 3.4, 8.1), slab, tower)                                  # canopy
	var name_sign := Label3D.new(); name_sign.text = "MERIDIAN  TOWER"
	name_sign.font_size = 120; name_sign.pixel_size = 0.006; name_sign.modulate = Color(0.85, 0.66, 0.36)
	name_sign.outline_size = 0; name_sign.shaded = true
	if Fonts.ui(600, 8):
		name_sign.font = Fonts.ui(600, 8)
	name_sign.position = Vector3(0, 4.55, 7.05); tower.add_child(name_sign)
	var spill := Mat.emissive(Color(0.8, 0.92, 0.86), 1.3)
	_box(Vector3(4.4, 2.7, 0.02), Vector3(0, 1.4, 7.05), spill, tower)                               # the lit lobby beyond
	var door_light := SpotLight3D.new(); door_light.light_color = Color(0.86, 0.97, 0.92)
	door_light.light_energy = 6.0; door_light.spot_range = 14.0; door_light.spot_angle = 55.0
	door_light.light_volumetric_fog_energy = 3.0
	door_light.position = Vector3(0, 2.6, 7.4); door_light.rotation.x = -0.35
	tower.add_child(door_light)
	figure = Characters.spawn("Construction_Male_02", {"idle": "m_idle_neutral_01"}, {"height": 1.95, "tint": Color(0.04, 0.04, 0.045)})
	if figure:
		figure.position = Vector3(0.5, 0.16, 7.35)
		figure.visible = false
		tower.add_child(figure)
		Characters.play(figure, "idle", 0.4)

# ---------------------------------------------------------------- weather, sound, captions
func _rain() -> void:
	var r := GPUParticles3D.new()
	r.amount = 1400 if Graphics.quality >= 2 else 700
	r.lifetime = 1.1; r.preprocess = 1.2
	r.visibility_aabb = AABB(Vector3(-30, -20, -30), Vector3(60, 30, 60))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(14, 0.5, 16)
	pm.direction = Vector3(0.06, -1, 0.02); pm.spread = 2.0
	pm.initial_velocity_min = 13.0; pm.initial_velocity_max = 16.0
	pm.gravity = Vector3.ZERO
	r.process_material = pm
	var q := QuadMesh.new(); q.size = Vector2(0.012, 0.6)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.75, 0.8, 0.88, 0.32); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = m
	r.draw_pass_1 = q
	r.position = Vector3(0, 12, 8)
	r.name = "Rain"
	add_child(r)

func _audio() -> void:
	for spec in [["rain", 0.0, "Ambience"], ["drone_a", -10.0, "Ambience"]]:
		var a := AudioStreamPlayer.new(); a.stream = Sfx.get_stream(spec[0])
		a.volume_db = spec[1]; a.bus = spec[2]; a.autoplay = true
		add_child(a)

func _ui() -> void:
	var layer := CanvasLayer.new(); add_child(layer)
	_caption = Label.new()
	_caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_caption.offset_left = -600; _caption.offset_right = 600; _caption.offset_top = -190; _caption.offset_bottom = -90
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", 30)
	if Fonts.ui(400, 2):
		_caption.add_theme_font_override("font", Fonts.ui(400, 2))
	_caption.add_theme_color_override("font_color", Color(0.9, 0.86, 0.76))
	_caption.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_caption.add_theme_constant_override("shadow_offset_x", 3); _caption.add_theme_constant_override("shadow_offset_y", 3)
	_caption.modulate.a = 0.0
	layer.add_child(_caption)
	var hint := Label.new(); hint.text = "any key to skip"
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -220; hint.offset_top = -44; hint.offset_right = -24; hint.offset_bottom = -16
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.6, 0.58, 0.52, 0.7))
	layer.add_child(hint)
	_fade = ColorRect.new(); _fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT); _fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 2.5)

func _process(d: float) -> void:
	_t += d
	# a slow walk in from across the road, eyes climbing the tower then dropping to the door
	var k := smoothstep(0.0, LENGTH, _t)
	_cam.position = CAM_FROM.lerp(CAM_TO, k) + Vector3(sin(_t * 1.7) * 0.015, sin(_t * 3.4) * 0.02, 0)
	var look_top := TOWER + Vector3(0, 30, 7)
	var look_door := TOWER + Vector3(0, 2.0, 7)
	var look := look_top.lerp(look_door, smoothstep(2.0, 15.0, _t))
	_cam.look_at(look, Vector3.UP)
	# captions
	var idx := -1
	for i in LINES.size():
		if _t >= LINES[i][0]:
			idx = i
	if idx != _line:
		_line = idx
		_caption.text = LINES[idx][1] if idx >= 0 else ""
		_caption.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(_caption, "modulate:a", 1.0, 1.0)
		tw.tween_interval(3.0)
		tw.tween_property(_caption, "modulate:a", 0.0, 0.9)
	# the beacon blinks, the eighth-floor window flickers, lightning now and then
	_beacon.light_energy = 3.0 if fmod(_t, 1.4) < 0.25 else 0.0
	_window_light.light_energy = 1.5 * (0.6 + 0.4 * sin(_t * 23.0) * sin(_t * 7.0)) if randf() > 0.03 else 0.0
	# the figure: there as the last line reads, gone in the next flash
	if figure and _figure_state == 0 and _t > 15.8:
		figure.visible = true; _figure_state = 1
	elif figure and _figure_state == 1 and _t > 20.6:
		_lightning()
		figure.visible = false; _figure_state = 2
		_bolt = 99.0
	_bolt -= d
	if _bolt <= 0.0:
		_bolt = randf_range(6.0, 11.0)
		_lightning()
	if _t >= LENGTH:
		_finish()

func _lightning() -> void:
	if GameState.settings.get("reduced_flashing", false):
		return
	var base := _moon.light_energy
	var tw := create_tween()
	tw.tween_property(_moon, "light_energy", 3.0, 0.04)
	tw.tween_property(_moon, "light_energy", base, 0.15)
	tw.tween_property(_moon, "light_energy", 2.0, 0.04)
	tw.tween_property(_moon, "light_energy", base, 0.5)
	var thunder := AudioStreamPlayer.new(); thunder.stream = Sfx.get_stream("boom"); thunder.bus = "SFX"
	add_child(thunder)
	get_tree().create_timer(randf_range(0.8, 2.0)).timeout.connect(func():
		if is_instance_valid(thunder): thunder.play())

func _unhandled_input(e: InputEvent) -> void:
	if _t < 0.8:
		return
	if (e is InputEventKey or e is InputEventMouseButton or e is InputEventScreenTouch or e is InputEventJoypadButton) and e.is_pressed():
		skip()

func skip() -> void:
	_finish()

func _finish() -> void:
	if _done:
		return
	_done = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.9)
	await tw.finished
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameState.go(GameState.floor_scene())

func _box(size: Vector3, pos: Vector3, mt: Material, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size
	mi.mesh = bm; mi.material_override = mt; mi.position = pos
	(parent if parent else self).add_child(mi)
	return mi
