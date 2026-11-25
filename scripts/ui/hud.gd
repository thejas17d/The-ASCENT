extends CanvasLayer
## HUD: cinematic post-process (bottom), phone viewfinder, hiding slats,
## crosshair, prompt, subtitles/messages, status, breath bar, reading panel,
## and the black fade (top).

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const POST := preload("res://shaders/post_fx.gdshader")

var post: ShaderMaterial
var _prompt: Label
var _msg: Label
var _fade: ColorRect
var _panel: PanelContainer
var _panel_text: Label
var _status: Label
var _breath: ProgressBar
var _phone: Control
var _slats: Control
var _msg_t := 0.0
var _tear_t := 0.0
var _fade_tw: Tween

func _ready() -> void:
	# 1) post-process reads the 3D frame underneath it
	var fx := ColorRect.new()
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post = ShaderMaterial.new(); post.shader = POST
	fx.material = post
	add_child(fx)
	# 2) diegetic overlays
	_phone = _make_phone()
	_slats = _make_slats()
	# 3) HUD text
	var cross := _label("·", 28)
	cross.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cross.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cross.modulate.a = 0.7
	_prompt = _label("", 20)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt.offset_top = -120; _prompt.offset_bottom = -80
	_msg = _label("", 24)
	_msg.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_msg.offset_top = 50; _msg.offset_left = 120; _msg.offset_right = -120
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status = _label("", 16)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_status.offset_left = 28; _status.offset_top = -46; _status.offset_right = 700
	_status.modulate.a = 0.75
	_breath = ProgressBar.new(); _breath.show_percentage = false
	_breath.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_breath.offset_left = -150; _breath.offset_right = 150; _breath.offset_top = -64; _breath.offset_bottom = -54
	_breath.visible = false; add_child(_breath)
	_panel = PanelContainer.new()
	_panel.theme = UiTheme.get_theme()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(680, 380)
	_panel.offset_left = -340; _panel.offset_top = -190
	_panel_text = Label.new(); _panel_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	_panel_text.add_theme_font_size_override("font_size", 21)
	_panel.add_child(_panel_text); _panel.visible = false
	add_child(_panel)
	# 4) fade on top
	_fade = ColorRect.new(); _fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

func _make_phone() -> Control:
	var c := Control.new(); c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE; c.visible = false
	add_child(c)
	for r in [[0, 0, 1, 0.06], [0, 0.94, 1, 1], [0, 0, 0.04, 1], [0.96, 0, 1, 1]]:
		var b := ColorRect.new(); b.color = Color(0.04, 0.045, 0.04)
		b.anchor_left = r[0]; b.anchor_top = r[1]; b.anchor_right = r[2]; b.anchor_bottom = r[3]
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(b)
	var tint := ColorRect.new(); tint.color = Color(0.2, 0.5, 0.25, 0.12)
	tint.set_anchors_preset(Control.PRESET_FULL_RECT); tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(tint)
	var rec := Label.new(); rec.text = "● REC   03:33"
	rec.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	rec.position = Vector2(90, 66); c.add_child(rec)
	return c

## Looking out through almirah vent slats.
func _make_slats() -> Control:
	var c := Control.new(); c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE; c.visible = false
	add_child(c)
	var top := ColorRect.new(); top.color = Color(0.01, 0.01, 0.01, 0.97)
	top.anchor_right = 1; top.anchor_bottom = 0.3; c.add_child(top)
	var bot := ColorRect.new(); bot.color = Color(0.01, 0.01, 0.01, 0.97)
	bot.anchor_top = 0.7; bot.anchor_right = 1; bot.anchor_bottom = 1; c.add_child(bot)
	for k in 5:
		var s := ColorRect.new(); s.color = Color(0.015, 0.015, 0.015, 0.96)
		s.anchor_right = 1
		s.anchor_top = 0.3 + k * 0.08 + 0.045; s.anchor_bottom = s.anchor_top + 0.035
		c.add_child(s)
	return c

func _label(t: String, size: int) -> Label:
	var l := Label.new(); l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", UiTheme.INK)
	l.add_theme_color_override("font_shadow_color", Color.BLACK)
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l); return l

func _process(d: float) -> void:
	if _msg_t > 0:
		_msg_t -= d
		if _msg_t <= 0:
			_msg.text = ""
	if _tear_t > 0:
		_tear_t -= d
	var flashing_ok: bool = not GameState.settings.get("reduced_flashing", false)
	post.set_shader_parameter("tear", clamp(_tear_t, 0.0, 1.0) if flashing_ok else 0.0)
	post.set_shader_parameter("grain", 0.045 * float(GameState.settings.get("grain", 1.0)))

func message(t: String, secs := 4.0) -> void:
	_msg.text = t; _msg_t = secs

func set_prompt(t: String) -> void:
	_prompt.text = t

func set_dread(v: float) -> void:
	var n: float = clamp(v / 100.0, 0.0, 1.0)
	post.set_shader_parameter("dread", n)
	post.set_shader_parameter("aberration", 1.0 + n * n * 9.0)
	post.set_shader_parameter("pulse_speed", 1.0 + n * 1.2)

## VHS tearing burst (violations, breakdowns, the building "noticing" you).
func glitch(secs := 0.8) -> void:
	_tear_t = max(_tear_t, secs)

func set_status(t: String) -> void:
	_status.text = t

func set_breath(v: float, show: bool) -> void:
	_breath.visible = show; _breath.value = v

func set_phone(on: bool) -> void:
	_phone.visible = on

func set_hiding(on: bool) -> void:
	_slats.visible = on

func show_panel(t: String) -> void:
	_panel_text.text = t; _panel.visible = true

func hide_panel() -> void:
	_panel.visible = false

func panel_open() -> bool:
	return _panel.visible

func fade_to(a: float, secs := 0.8) -> void:
	if _fade_tw and _fade_tw.is_valid():
		_fade_tw.kill()
	_fade_tw = create_tween()
	_fade_tw.tween_property(_fade, "color:a", a, secs)
	# don't await `finished`: a killed tween never emits it and would soft-lock callers
	var tw := _fade_tw
	while tw.is_valid() and tw.is_running():
		await get_tree().process_frame

func fade_alpha() -> float:
	return _fade.color.a
