extends CanvasLayer
## Esc / P: pause with Resume · Settings · Main Menu · Quit. Runs while paused.

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const Settings := preload("res://scripts/ui/settings_panel.gd")

var _root: Control
var _menu: VBoxContainer
var _settings: Control

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new(); _root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiTheme.get_theme()
	add_child(_root)
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT); _root.add_child(dim)
	_menu = VBoxContainer.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_menu.custom_minimum_size = Vector2(320, 0)
	_menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_menu.grow_vertical = Control.GROW_DIRECTION_BOTH
	_menu.add_theme_constant_override("separation", 12)
	_root.add_child(_menu)
	var t := Label.new(); t.text = "PAUSED"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 34)
	_menu.add_child(t)
	_button("Resume", close)
	_button("Settings", _open_settings)
	_button("Main Menu", func():
		close()
		get_tree().change_scene_to_file("res://scenes/menu.tscn"))
	_button("Quit", func(): get_tree().quit())
	_root.visible = false

func _button(text: String, cb: Callable) -> void:
	var b := Button.new(); b.text = text; b.custom_minimum_size.y = 46
	b.pressed.connect(cb); _menu.add_child(b)

func is_open() -> bool:
	return _root.visible

func open() -> void:
	_root.visible = true
	_menu.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	(_menu.get_child(1) as Button).grab_focus()

func close() -> void:
	if _settings:
		_settings.queue_free(); _settings = null
	_root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _open_settings() -> void:
	_menu.visible = false
	_settings = Settings.new()
	_settings.closed.connect(func():
		_settings.queue_free(); _settings = null
		_menu.visible = true)
	_root.add_child(_settings)

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("pause"):
		if not is_open():
			open()
		elif _settings:
			_settings.closed.emit()
		else:
			close()
		get_viewport().set_input_as_handled()
