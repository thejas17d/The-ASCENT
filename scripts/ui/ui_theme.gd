extends RefCounted
## Shared dark UI theme: worn paper-white text on near-black, brass accents.

const INK := Color(0.86, 0.82, 0.72)
const DIM := Color(0.5, 0.48, 0.44)
const ACCENT := Color(0.78, 0.6, 0.3)
static var _theme: Theme

static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 20
	var normal := _box(Color(0.07, 0.065, 0.06, 0.92), Color(0.25, 0.22, 0.18))
	var hover := _box(Color(0.13, 0.11, 0.09, 0.95), ACCENT)
	var pressed := _box(Color(0.2, 0.16, 0.11, 0.95), ACCENT)
	for cls in ["Button", "OptionButton", "CheckBox"]:
		t.set_stylebox("normal", cls, normal)
		t.set_stylebox("hover", cls, hover)
		t.set_stylebox("pressed", cls, pressed)
		t.set_stylebox("focus", cls, _box(Color(0, 0, 0, 0), ACCENT))
		t.set_color("font_color", cls, INK)
		t.set_color("font_hover_color", cls, Color(1, 0.92, 0.75))
		t.set_color("font_pressed_color", cls, ACCENT)
	t.set_color("font_color", "Label", INK)
	t.set_stylebox("panel", "PanelContainer", _box(Color(0.03, 0.028, 0.025, 0.94), Color(0.3, 0.26, 0.2), 18))
	var grab := StyleBoxFlat.new(); grab.bg_color = ACCENT
	grab.set_corner_radius_all(6); grab.content_margin_top = 6; grab.content_margin_bottom = 6
	t.set_stylebox("slider", "HSlider", _box(Color(0.15, 0.14, 0.12), Color(0.15, 0.14, 0.12), 2))
	t.set_stylebox("grabber_area", "HSlider", grab)
	t.set_stylebox("grabber_area_highlight", "HSlider", grab)
	_theme = t
	return t

static func _box(bg: Color, border: Color, margin := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg; s.border_color = border
	s.set_border_width_all(1); s.set_corner_radius_all(3)
	s.content_margin_left = margin + 6; s.content_margin_right = margin + 6
	s.content_margin_top = margin * 0.6; s.content_margin_bottom = margin * 0.6
	return s
