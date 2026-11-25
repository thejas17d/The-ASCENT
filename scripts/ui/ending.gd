extends Control
## Endings: ESCAPE (the loop continues) or TRUTH (the building falls, the
## evidence survives). Shows the run's stats and what was unlocked.

const UiTheme := preload("res://scripts/ui/ui_theme.gd")

const ESCAPE := [
	"You run.",
	"The door opens onto a stairwell. Down, down, down — further than eight floors should go.",
	"At the bottom there is a lobby. Dusty. A security booth. A frozen clock.",
	"3:33.",
	"On the reception desk, a visitor register lies open. The last line is in your handwriting.",
	"A sign by a different lift reads:  SUNRISE APARTMENTS — 12 FLOORS.",
	"Somewhere above you, a phone begins to ring.",
]
const TRUTH := [
	"You take out the six cards and the letter, and you read their names out loud.",
	"Ramesh Patil.  Suresh Yadav.  Abdul Karim.  Joseph D'Souza.  Mahadev Gaikwad.  Babu Rao.",
	"Papa says them with you. His voice breaks on the last one.",
	"The roof does not collapse so much as let go.",
	"…",
	"You wake on a bench outside a sealed construction site in Mumbai. It is morning. It is raining.",
	"In your hand: a water-stained letter, signed P. Desai, and six ID cards from 1998.",
	"There is a police station two streets away. You start walking.",
]

var _lines: Array = []
var _i := 0
var _label: Label
var _t := 0.0

func _ready() -> void:
	theme = UiTheme.get_theme()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	var bg := ColorRect.new(); bg.color = Color(0.01, 0.01, 0.01)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(bg)
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.offset_left = 160; _label.offset_right = -160
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_label.add_theme_font_size_override("font_size", 28)
	add_child(_label)
	var ending: String = GameState.choices.get("ending", "escape")
	_lines = (TRUTH if ending == "truth" else ESCAPE).duplicate()
	GameState.unlocks["loops"] = int(GameState.unlocks.get("loops", 0)) + 1
	var loops := int(GameState.unlocks.loops)
	if ending == "escape" and loops > 1:
		var nth := ["first", "second", "third", "fourth", "fifth"]
		_lines.append("This is the %s building you have woken up in." % nth[loops - 1] if loops <= 5 else "You have stopped counting the buildings.")
	if GameState.night():
		_lines.insert(0, "(Night Shift)")
	GameState.delete_save()   # the run is over the moment the ending begins
	GameState.save_unlocks()  # unlocks + memories survive it
	_show(0)

func _show(i: int) -> void:
	_i = i
	_label.modulate.a = 0.0
	_label.text = _lines[i]
	create_tween().tween_property(_label, "modulate:a", 1.0, 1.2)
	_t = 4.8

func _process(d: float) -> void:
	if _i >= _lines.size():
		return
	_t -= d
	if _t <= 0.0:
		if _i + 1 < _lines.size():
			_show(_i + 1)
		else:
			_i = _lines.size()
			_summary()

func _unhandled_input(e: InputEvent) -> void:
	if _i < _lines.size() and (e.is_action_pressed("interact") or e.is_action_pressed("ui_accept") or (e is InputEventMouseButton and e.pressed)):
		_t = 0.0

func _summary() -> void:
	var ending: String = GameState.choices.get("ending", "escape")
	var s := "ENDING — %s\n\n" % ("TRUTH" if ending == "truth" else "ESCAPE")
	s += "Times the building sent you down:  %d\n" % GameState.falls
	s += "Deaths:  %d\n" % GameState.deaths
	s += "Papa's letter:  %s\n" % str(GameState.choices.get("letter", "—"))
	s += "The six workers:  %s\n" % str(GameState.choices.get("workers", "—"))
	if ending == "escape":
		s += "\nThe loop continues.  (TRUTH needs the letter kept and all six freed.)\n"
	if GameState.falls == 0:
		s += "\nYou never fell.  Something has opened above the roof:  FLOOR 9.\n"
	s += "\nNew Game+ (Night Shift) unlocked."
	s += "\n\n— THE ASCENT —\nMade with Godot 4  ·  Textures: Poly Haven (CC0)  ·  All sound synthesised in code"
	_label.text = s
	_label.add_theme_font_size_override("font_size", 24)
	var b := Button.new(); b.text = "Return to the title"
	b.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	b.offset_top = -120; b.offset_bottom = -70; b.offset_left = -160; b.offset_right = 160
	b.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu.tscn"))
	add_child(b)
	GameState.save_unlocks()
