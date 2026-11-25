extends Node
## Paranormal Event Director. Picks ambient events by dread, cooldowns and a
## quiet→tension→relief rhythm, then asks the floor to perform them.
## Fake events (hallucinations) only fire at high dread and always vanish
## within ~1 s — "what vanishes was never there" — so they never decide a
## judgement unfairly.

var floor: Node          # FloorBase; must implement perform_event(id) -> bool
var events: Array = []
var enabled := true
var history: Array = []  # ids performed, for tests/debug
var _cool := {}
var _next := 15.0        # seconds of quiet before first event
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	var f := FileAccess.open("res://data/events/director.json", FileAccess.READ)
	events = JSON.parse_string(f.get_as_text())

func _process(d: float) -> void:
	for k in _cool:
		_cool[k] -= d
	if not enabled or floor == null or floor.busy or floor.finished:
		return
	# higher dread = events come sooner
	_next -= d * (1.0 + Dread.value / 100.0)
	if _next <= 0:
		fire()

func candidates() -> Array:
	return events.filter(func(e): return Dread.value >= e.min_dread and _cool.get(e.id, 0.0) <= 0.0)

func fire() -> String:
	var pool := candidates()
	if pool.is_empty():
		_next = 5.0
		return ""
	var total := 0.0
	for e in pool:
		total += e.weight
	var r := _rng.randf() * total
	var pick: Dictionary = pool[0]
	for e in pool:
		r -= e.weight
		if r <= 0:
			pick = e
			break
	if not floor.perform_event(pick.id):
		_next = 4.0
		return ""
	_cool[pick.id] = float(pick.cooldown)
	Dread.add(float(pick.dread))
	history.append(pick.id)
	# relief after big moments, silence is a tool
	_next = _rng.randf_range(18.0, 32.0) + (15.0 if int(pick.intensity) >= 3 else 0.0)
	return pick.id
