extends CanvasLayer
## Minimal diegetic-leaning HUD: crosshair, prompt, messages, dread vignette, fades.
var _prompt: Label
var _msg: Label
var _dread: ColorRect
var _fade: ColorRect
var _panel: PanelContainer
var _panel_text: Label
var _msg_t := 0.0

func _ready() -> void:
	_dread = _rect(Color(0.25, 0, 0, 0))
	var cross := _label("·", 28)
	cross.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cross.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt = _label("", 20)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt.offset_top = -110; _prompt.offset_bottom = -70
	_msg = _label("", 24)
	_msg.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_msg.offset_top = 50; _msg.offset_left = 120; _msg.offset_right = -120
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(620, 360); _panel.position = Vector2(-310, -180)
	_panel_text = Label.new(); _panel_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	_panel_text.add_theme_font_size_override("font_size", 22)
	_panel.add_child(_panel_text); _panel.visible = false
	add_child(_panel)
	_fade = _rect(Color(0, 0, 0, 1))

func _rect(c: Color) -> ColorRect:
	var r := ColorRect.new(); r.color = c
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r); return r

func _label(t: String, size: int) -> Label:
	var l := Label.new(); l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_shadow_color", Color.BLACK)
	add_child(l); return l

func _process(d: float) -> void:
	if _msg_t > 0:
		_msg_t -= d
		if _msg_t <= 0:
			_msg.text = ""

func message(t: String, secs := 4.0) -> void:
	_msg.text = t; _msg_t = secs

func set_prompt(t: String) -> void:
	_prompt.text = t

func set_dread(v: float) -> void:
	_dread.color.a = clamp(v / 100.0, 0.0, 1.0) * 0.45

func show_panel(t: String) -> void:
	_panel_text.text = t; _panel.visible = true

func hide_panel() -> void:
	_panel.visible = false

func panel_open() -> bool:
	return _panel.visible

func fade_to(a: float, secs := 0.8) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", a, secs)
	await tw.finished
