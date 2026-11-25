extends Control
## Title screen: Continue / New Game / Quit.

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bg := ColorRect.new(); bg.color = Color(0.02, 0.02, 0.02)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.offset_left = -200; box.offset_right = 200; box.offset_top = -170; box.offset_bottom = 170
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	var t := Label.new(); t.text = "THE ASCENT"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 56)
	t.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6))
	box.add_child(t)
	var sub := Label.new(); sub.text = "Meridian Tower · Mumbai · 3:33 AM"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	box.add_child(sub)
	if GameState.has_save():
		_button(box, "Continue", _continue)
	_button(box, "New Game", _new)
	_button(box, "Quit", func(): get_tree().quit())
	var hint := Label.new(); hint.text = "Headphones recommended."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	box.add_child(hint)

func _button(parent: Node, text: String, cb: Callable) -> void:
	var b := Button.new(); b.text = text; b.custom_minimum_size.y = 44
	b.pressed.connect(cb); parent.add_child(b)

func _continue() -> void:
	if GameState.load_game():
		get_tree().change_scene_to_file(GameState.floor_scene())

func _new() -> void:
	GameState.new_game()
	Dread.reset(0.0)
	get_tree().change_scene_to_file(GameState.floor_scene())
