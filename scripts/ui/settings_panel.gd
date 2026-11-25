extends PanelContainer
## Settings screen used by the title menu and the pause menu.
## Every change applies immediately and is saved to user://settings.json.
signal closed

const UiTheme := preload("res://scripts/ui/ui_theme.gd")

func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(640, 0)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(620, min(760.0, get_viewport().get_visible_rect().size.y - 120.0))
	add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)
	var title := Label.new(); title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var s: Dictionary = GameState.settings

	_section(box, "Display")
	var q := OptionButton.new()
	q.add_item("Auto")
	for p in Graphics.PRESETS:
		q.add_item(p)
	q.selected = int(s.quality) + 1
	q.item_selected.connect(func(i): _apply("quality", i - 1))
	_row(box, "Graphics quality", q)
	_check(box, "Fullscreen  (F11)", "fullscreen")
	_slider(box, "Film grain", "grain", 0.0, 1.5)
	_check(box, "Reduced flashing", "reduced_flashing")

	_section(box, "Controls")
	_slider(box, "Mouse sensitivity", "sensitivity", 0.3, 2.5)

	_section(box, "Mobile")
	var t := OptionButton.new()
	for o in ["Auto (phones)", "Always", "Never"]:
		t.add_item(o)
	t.selected = int(s.get("touch_controls", 0))
	t.item_selected.connect(func(i): _apply("touch_controls", i))
	_row(box, "Touch controls", t)
	_slider(box, "Touch look sensitivity", "touch_sensitivity", 0.3, 2.5)
	_check(box, "Gyroscope look", "gyro")
	_check(box, "Vibration", "haptics")

	_section(box, "Horror & accessibility")
	_slider(box, "Scare intensity", "scare_intensity", 0.5, 1.5)
	_check(box, "Subtitles for sounds", "subtitles")

	_section(box, "Audio")
	_slider(box, "Master volume", "vol_master", 0.0, 1.0)
	_slider(box, "Effects volume", "vol_sfx", 0.0, 1.0)
	_slider(box, "Ambience volume", "vol_ambience", 0.0, 1.0)

	var hint := Label.new()
	hint.text = "Ultra renders at native resolution (UHD on a 4K display)."
	hint.add_theme_color_override("font_color", UiTheme.DIM)
	hint.add_theme_font_size_override("font_size", 15)
	box.add_child(hint)
	var back := Button.new(); back.text = "Back"
	back.pressed.connect(func(): closed.emit())
	box.add_child(back)
	back.call_deferred("grab_focus")

func _apply(key: String, value) -> void:
	GameState.settings[key] = value
	GameState.apply_settings()
	GameState.save_settings()

func _section(box: Node, t: String) -> void:
	var l := Label.new(); l.text = t.to_upper()
	l.add_theme_color_override("font_color", UiTheme.ACCENT)
	l.add_theme_font_size_override("font_size", 15)
	box.add_child(l)

func _row(box: Node, label: String, ctrl: Control) -> void:
	var h := HBoxContainer.new()
	var l := Label.new(); l.text = label; l.custom_minimum_size.x = 260
	h.add_child(l)
	ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(ctrl)
	box.add_child(h)

func _check(box: Node, label: String, key: String) -> void:
	var c := CheckBox.new()
	c.button_pressed = bool(GameState.settings[key])
	c.text = "On" if c.button_pressed else "Off"
	c.toggled.connect(func(on):
		c.text = "On" if on else "Off"
		_apply(key, on))
	_row(box, label, c)

func _slider(box: Node, label: String, key: String, lo: float, hi: float) -> void:
	var sl := HSlider.new()
	sl.min_value = lo; sl.max_value = hi; sl.step = 0.05
	sl.value = float(GameState.settings[key])
	sl.custom_minimum_size.y = 24
	sl.value_changed.connect(func(v): _apply(key, v))
	_row(box, label, sl)
