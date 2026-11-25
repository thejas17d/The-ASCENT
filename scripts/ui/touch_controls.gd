extends CanvasLayer
## On-screen touch controls (Phase 7).
##  * Left 40% of the screen: a floating joystick (appears under your thumb).
##    Pushing it to the edge runs.
##  * Right side: drag to look.
##  * Buttons are TouchScreenButtons (true multi-touch) bound to the same input
##    actions as the keyboard, so every system works unchanged.
## Crouch is a toggle on touch; "breath" is held while hiding.

const JOY_RADIUS := 110.0
const JOY_DEADZONE := 0.12
const RUN_AT := 0.92
const LOOK_SCALE := 0.0045       # radians per pixel at sensitivity 1.0
const MOVE_ACTIONS := ["move_left", "move_right", "move_forward", "move_back"]

var player: CharacterBody3D
var joy_vector := Vector2.ZERO   # public for tests
var crouch_latched := false
var buttons := {}                # name -> TouchScreenButton
var _joy_index := -1
var _joy_origin := Vector2.ZERO
var _look_index := -1
var _joy_ring: Control
var _joy_knob: Control
var _tex_cache := {}

func _ready() -> void:
	layer = 15
	_joy_ring = _disc(JOY_RADIUS, Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.35))
	_joy_knob = _disc(44.0, Color(1, 1, 1, 0.25), Color(1, 1, 1, 0.6))
	_joy_ring.visible = false; _joy_knob.visible = false
	_layout()
	get_viewport().size_changed.connect(_layout)
	visibility_changed.connect(func():
		if not visible:
			release_all())

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		release_all()

## Forget every finger (dialogs, pause, hiding the layer).
func release_all() -> void:
	_release_move()
	_joy_index = -1
	_look_index = -1

func _screen() -> Vector2:
	return get_viewport().get_visible_rect().size

## Place buttons relative to the bottom-right corner (thumb reach), plus a few at the top.
func _layout() -> void:
	for b in buttons.values():
		b.queue_free()
	buttons.clear()
	var s := _screen()
	_button("use", "interact", "USE", Vector2(s.x - 140, s.y - 150), 72)
	_button("torch", "flashlight", "TORCH", Vector2(s.x - 290, s.y - 110), 50)
	_button("crouch", "", "CROUCH", Vector2(s.x - 140, s.y - 320), 50)
	_button("breath", "breath", "HOLD\nBREATH", Vector2(s.x - 300, s.y - 260), 54)
	_button("phone", "phone", "PHONE", Vector2(s.x - 420, s.y - 90), 44)
	_button("diya", "diya", "DIYA", Vector2(s.x - 70, s.y - 440), 40)
	_button("voice", "voice", "VOICE", Vector2(s.x - 190, s.y - 470), 40)
	_button("reload", "reload", "BATT", Vector2(s.x - 70, s.y - 560), 40)
	_button("bag", "inventory", "BAG", Vector2(80, 80), 44)
	_button("pause", "pause", "II", Vector2(s.x - 70, 70), 40)
	buttons["crouch"].pressed.connect(_toggle_crouch)

func _button(id: String, action: String, text: String, center: Vector2, r: float) -> void:
	var b := TouchScreenButton.new()
	b.texture_normal = _circle_tex(r, false)
	b.texture_pressed = _circle_tex(r, true)
	var shape := CircleShape2D.new(); shape.radius = r
	b.shape = shape
	b.shape_centered = true
	b.position = center - Vector2(r, r)
	if action != "":
		b.action = action
	var l := Label.new(); l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = Vector2(r * 2, r * 2)
	l.add_theme_font_size_override("font_size", int(r * 0.36))
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	b.add_child(l)
	b.set_meta("radius", r)
	add_child(b)
	buttons[id] = b

func _circle_tex(r: float, pressed: bool) -> Texture2D:
	var key := "%s|%s" % [r, pressed]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var g := Gradient.new()
	var a := 0.32 if pressed else 0.14
	g.set_color(0, Color(1, 1, 1, a)); g.set_color(1, Color(1, 1, 1, 0.0))
	g.add_point(0.86, Color(1, 1, 1, a + 0.08))
	g.add_point(0.92, Color(1, 1, 1, 0.55))
	var t := GradientTexture2D.new()
	t.gradient = g; t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5); t.fill_to = Vector2(1.0, 0.5)
	t.width = int(r * 2); t.height = int(r * 2)
	_tex_cache[key] = t
	return t

func _disc(r: float, fill: Color, ring: Color) -> Control:
	# a soft radial disc with a bright rim (same look as the buttons)
	var g := Gradient.new()
	g.set_color(0, fill); g.set_color(1, Color(ring, 0.0))
	g.add_point(0.88, fill)
	g.add_point(0.94, ring)
	var t := GradientTexture2D.new()
	t.gradient = g; t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5); t.fill_to = Vector2(1.0, 0.5)
	t.width = int(r * 2); t.height = int(r * 2)
	var c := TextureRect.new()
	c.texture = t
	c.size = Vector2(r * 2, r * 2)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c

func on_button(pos: Vector2) -> bool:
	for b in buttons.values():
		var r: float = b.get_meta("radius")
		if (b.position + Vector2(r, r)).distance_to(pos) <= r * 1.1:
			return true
	return false

func _toggle_crouch() -> void:
	crouch_latched = not crouch_latched
	if crouch_latched:
		Input.action_press("crouch")
	else:
		Input.action_release("crouch")

# ---------------------------------------------------------------- input
func _input(e: InputEvent) -> void:
	if not visible or get_tree().paused:
		return
	if e is InputEventScreenTouch:
		if e.pressed:
			if on_button(e.position):
				return
			if e.position.x < _screen().x * 0.4 and _joy_index < 0:
				_joy_index = e.index
				_joy_origin = e.position
				_joy_ring.position = e.position - _joy_ring.size / 2
				_joy_ring.visible = true; _joy_knob.visible = true
				_set_knob(e.position)
			elif _look_index < 0:
				_look_index = e.index
		else:
			if e.index == _joy_index:
				_joy_index = -1
				_release_move()
			elif e.index == _look_index:
				_look_index = -1
	elif e is InputEventScreenDrag:
		if e.index == _joy_index:
			_set_knob(e.position)
		elif e.index == _look_index and player:
			player.look_input(e.relative * LOOK_SCALE * float(GameState.settings.get("touch_sensitivity", 1.0)))

func _set_knob(pos: Vector2) -> void:
	var v := (pos - _joy_origin) / JOY_RADIUS
	if v.length() > 1.0:
		v = v.normalized()
	_joy_knob.position = _joy_origin + v * JOY_RADIUS - _joy_knob.size / 2
	set_joystick(v)

## Apply a joystick vector (-1..1 each axis) to the movement actions.
func set_joystick(v: Vector2) -> void:
	joy_vector = v if v.length() >= JOY_DEADZONE else Vector2.ZERO
	var map := {"move_right": max(0.0, joy_vector.x), "move_left": max(0.0, -joy_vector.x),
		"move_back": max(0.0, joy_vector.y), "move_forward": max(0.0, -joy_vector.y)}
	for a in map:
		if map[a] > 0.0:
			Input.action_press(a, map[a])
		else:
			Input.action_release(a)
	if joy_vector.length() >= RUN_AT and not crouch_latched:
		Input.action_press("run")
	else:
		Input.action_release("run")

func _release_move() -> void:
	joy_vector = Vector2.ZERO
	_joy_ring.visible = false; _joy_knob.visible = false
	for a in MOVE_ACTIONS:
		Input.action_release(a)
	Input.action_release("run")

func _exit_tree() -> void:
	_release_move()
	if crouch_latched:
		Input.action_release("crouch")
