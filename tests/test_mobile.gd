extends SceneTree
## Phase 7 mobile tests: touch joystick / look / buttons, crouch toggle,
## gyroscope, haptics, 1K textures, settings rows, UI stretch.
## godot --headless --path . -s res://tests/test_mobile.gd
var fails := 0
var gs

func check(cond: bool, name: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond: fails += 1

func wait(s: float) -> void:
	await create_timer(s).timeout

## Events arrive in window pixels; the UI works in stretched canvas units.
## (Headless runs use a 64x64 window, so convert like a real screen would.)
func _win(p: Vector2) -> Vector2:
	return root.get_final_transform() * p

func touch(idx: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new(); e.index = idx; e.position = _win(pos); e.pressed = pressed
	Input.parse_input_event(e)

func drag(idx: int, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new(); e.index = idx; e.position = _win(pos)
	e.relative = root.get_final_transform().basis_xform(rel)
	Input.parse_input_event(e)

func _initialize() -> void:
	gs = root.get_node("GameState")
	await process_frame; await process_frame
	var set_bak := FileAccess.open(gs.SETTINGS_PATH, FileAccess.READ).get_as_text() if FileAccess.file_exists(gs.SETTINGS_PATH) else ""
	var save_bak := FileAccess.open(gs.SAVE_PATH, FileAccess.READ).get_as_text() if FileAccess.file_exists(gs.SAVE_PATH) else ""
	gs.test_mode = true
	gs.new_game()
	check(ProjectSettings.get_setting("display/window/stretch/mode") == "canvas_items", "UI scales with resolution (canvas_items stretch)")
	check(int(ProjectSettings.get_setting("display/window/handheld/orientation")) == 4, "phones: sensor landscape orientation")
	gs.settings.touch_controls = 2
	check(not gs.touch_active(), "touch controls off on desktop when set to Never")
	gs.settings.touch_controls = 0
	check(gs.touch_active() == OS.has_feature("mobile"), "touch controls Auto = phones only")
	gs.settings.touch_controls = 1
	check(gs.touch_active(), "touch controls can be forced on")

	var f = load("res://scenes/floor_g.tscn").instantiate()
	root.add_child(f)
	await wait(0.5)
	f.director.enabled = false
	var t = f.touch
	var p = f.player
	check(t != null and p.touch_mode, "floor creates the touch layer and puts the player in touch mode")
	check(t.buttons.has("use") and t.buttons.has("torch") and t.buttons.has("pause") and t.buttons.use.action == "interact", "buttons are bound to the game's input actions")
	# joystick by API
	t.set_joystick(Vector2(0, -0.5))
	check(is_equal_approx(Input.get_action_strength("move_forward"), 0.5) and not Input.is_action_pressed("run"), "half-push joystick walks at half strength")
	var z0: float = p.global_position.z
	await wait(0.5)
	check(p.global_position.z < z0 - 0.2, "the player walks forward (%.2f m)" % (z0 - p.global_position.z))
	t.set_joystick(Vector2(0, -1.0))
	check(Input.is_action_pressed("run"), "full push runs")
	t.set_joystick(Vector2(0.05, 0.0))
	check(not Input.is_action_pressed("move_right") and t.joy_vector == Vector2.ZERO, "deadzone ignores tiny pushes")
	t._release_move()
	# joystick by real touch events on the left
	var s: Vector2 = t._screen()
	touch(0, Vector2(s.x * 0.15, s.y * 0.7), true)
	await process_frame
	drag(0, Vector2(s.x * 0.15 + 80, s.y * 0.7), Vector2(80, 0))
	await process_frame
	check(t.joy_vector.x > 0.5 and Input.get_action_strength("move_right") > 0.5, "left-side touch spawns a floating joystick")
	touch(0, Vector2(s.x * 0.15 + 80, s.y * 0.7), false)
	await process_frame
	check(t.joy_vector == Vector2.ZERO and not Input.is_action_pressed("move_right"), "lifting the thumb stops")
	# look by dragging on the right
	var yaw0: float = p.rotation.y
	touch(1, Vector2(s.x * 0.6, s.y * 0.4), true)
	await process_frame
	drag(1, Vector2(s.x * 0.6 + 100, s.y * 0.4), Vector2(100, 0))
	await process_frame
	touch(1, Vector2(s.x * 0.6 + 100, s.y * 0.4), false)
	check(p.rotation.y < yaw0 - 0.2, "right-side drag turns the view (%.2f rad)" % (yaw0 - p.rotation.y))
	# touches on a button don't start the joystick
	var ub = t.buttons.use
	touch(2, ub.position + Vector2(ub.get_meta("radius"), ub.get_meta("radius")), true)
	await process_frame
	check(t._joy_index == -1 and t._look_index == -1, "a touch on a button isn't taken as joystick/look")
	touch(2, Vector2.ZERO, false)
	# mouse motion (emulated from touch) is ignored in touch mode
	var yaw1: float = p.rotation.y
	var mm := InputEventMouseMotion.new(); mm.relative = Vector2(300, 0)
	p._unhandled_input(mm)
	check(is_equal_approx(p.rotation.y, yaw1), "emulated mouse motion doesn't double-turn the view")
	# crouch toggle
	t._toggle_crouch()
	await wait(0.1)
	check(Input.is_action_pressed("crouch") and p.is_crouching, "CROUCH is a toggle on touch")
	t._toggle_crouch()
	await wait(0.1)
	check(not p.is_crouching, "...tap again to stand")
	# breath button only while hiding
	await process_frame
	check(not t.buttons.breath.visible, "HOLD BREATH hidden when not hiding")
	f.player.hide_in(f.kit.spots[0] if f.kit.spots.size() > 0 else f)
	await process_frame
	check(t.buttons.breath.visible, "HOLD BREATH shown while hiding")
	f.player.leave_hiding()
	# prompt wording
	p.cam.rotation = Vector3.ZERO
	p.teleport(Vector3(-5.6, 0.05, 2.5)); p.rotation.y = PI / 2
	await wait(0.2)
	check(f.hud._prompt.text.begins_with("USE ·"), "prompts say USE instead of [E] (%s)" % f.hud._prompt.text)
	# gyroscope
	gs.settings.gyro = true
	var yaw2: float = p.rotation.y
	Input.set_gyroscope(Vector3(0, 1.0, 0))
	await wait(0.5)
	Input.set_gyroscope(Vector3.ZERO)
	gs.settings.gyro = false
	check(p.rotation.y > yaw2 + 0.3, "gyroscope yaw turns the view (%.2f rad)" % (p.rotation.y - yaw2))
	# haptics
	var H = load("res://scripts/systems/haptics.gd")
	H.history.clear()
	gs.settings.haptics = true
	f.fall_down("test")
	await wait(0.1)
	check(H.history.size() > 0 and H.history[-1][0] == "fall", "falling vibrates")
	gs.settings.haptics = false
	H.pulse("x", 10)
	check(H.history[-1][0] == "fall", "vibration can be turned off")
	gs.settings.haptics = true
	f.queue_free(); await wait(0.2)
	# textures
	var Mat = load("res://scripts/systems/mat_lib.gd")
	var g = root.get_node("Graphics")
	g.apply(0)
	check(Mat.tex_pattern() == Mat.TEX_1K, "Low preset / phones use the 1K texture set")
	g.apply(2)
	check(Mat.tex_pattern() == Mat.TEX_2K or OS.has_feature("mobile"), "desktop High uses 2K")
	var tex: Texture2D = load(Mat.TEX_1K % ["plywood", "albedo"])
	check(tex != null and tex.get_width() == 1024, "1K textures are imported (%d px)" % (tex.get_width() if tex else 0))
	# settings rows
	var sp = load("res://scripts/ui/settings_panel.gd").new()
	root.add_child(sp)
	await process_frame
	var labels := []
	_collect_labels(sp, labels)
	check(labels.has("Touch controls") and labels.has("Gyroscope look") and labels.has("Vibration"), "settings have a Mobile section")
	sp.queue_free()
	for a in ["move_left", "move_right", "move_forward", "move_back", "run", "crouch"]:
		Input.action_release(a)
	gs.settings.touch_controls = 0
	if set_bak != "": FileAccess.open(gs.SETTINGS_PATH, FileAccess.WRITE).store_string(set_bak)
	if save_bak != "": FileAccess.open(gs.SAVE_PATH, FileAccess.WRITE).store_string(save_bak)
	print("\n%d failure(s)" % fails)
	quit(1 if fails > 0 else 0)

func _collect_labels(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Label: out.append(c.text)
		_collect_labels(c, out)
