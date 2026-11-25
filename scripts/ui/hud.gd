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
var _dialog: PanelContainer
signal dialog_done(result)

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

func dialog_open() -> bool:
	return _dialog != null

## Numeric keypad. Returns the entered string ("" if cancelled).
func ask_code(title: String, length := 4) -> String:
	_dialog = PanelContainer.new()
	_dialog.theme = UiTheme.get_theme()
	_dialog.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_dialog.grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 10)
	_dialog.add_child(v)
	var t := Label.new(); t.text = title; t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var edit := LineEdit.new(); edit.max_length = length; edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.placeholder_text = "_ ".repeat(length).strip_edges()
	edit.add_theme_font_size_override("font_size", 34)
	edit.custom_minimum_size = Vector2(260, 56)
	v.add_child(edit)
	var grid := GridContainer.new(); grid.columns = 3
	v.add_child(grid)
	for k in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "⌫", "0", "OK"]:
		var b := Button.new(); b.text = k; b.custom_minimum_size = Vector2(84, 48)
		b.pressed.connect(func():
			if k == "OK": _finish_dialog(edit.text)
			elif k == "⌫": edit.text = edit.text.left(-1)
			elif edit.text.length() < length: edit.text += k)
		grid.add_child(b)
	var cancel := Button.new(); cancel.text = "Step away"
	cancel.pressed.connect(func(): _finish_dialog(""))
	v.add_child(cancel)
	edit.text_submitted.connect(func(s): _finish_dialog(s))
	add_child(_dialog)
	move_child(_dialog, get_child_count() - 2)   # under the fade
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	edit.grab_focus()
	var r = await dialog_done
	return str(r)

## Choice between options. Disabled options are passed as {"text":…, "disabled":true}.
## Returns the chosen index.
func ask_choice(title: String, options: Array) -> int:
	_dialog = PanelContainer.new()
	_dialog.theme = UiTheme.get_theme()
	_dialog.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_dialog.grow_vertical = Control.GROW_DIRECTION_BOTH
	_dialog.custom_minimum_size = Vector2(620, 0)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 12)
	_dialog.add_child(v)
	var t := Label.new(); t.text = title; t.autowrap_mode = TextServer.AUTOWRAP_WORD
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	for i in options.size():
		var o = options[i]
		var b := Button.new(); b.custom_minimum_size.y = 50
		b.text = o if o is String else str(o.text)
		b.disabled = o is Dictionary and o.get("disabled", false)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD
		b.pressed.connect(func(): _finish_dialog(i))
		v.add_child(b)
	add_child(_dialog)
	move_child(_dialog, get_child_count() - 2)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var r = await dialog_done
	return int(r)

func _finish_dialog(result) -> void:
	if _dialog:
		_dialog.queue_free()
		_dialog = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	dialog_done.emit(result)

## Tests / scripted flows can answer an open dialog directly.
func answer_dialog(result) -> void:
	_finish_dialog(result)
