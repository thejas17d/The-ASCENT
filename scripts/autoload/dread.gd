extends Node
## Dread Meter — replaces health. 0..100. Emits `breakdown` once at 100
## until reset(). Passive change is applied by the active floor via tick().
signal changed(value: float)
signal breakdown

const DARK_RATE := 1.2      # /s with no light
const LIGHT_RATE := -0.4    # /s with torch on
const SAFE_RATE := -5.0     # /s inside a diya's glow
const HIDING_RATE := -1.0   # /s while hidden

var value := 0.0
var _broken := false

func add(v: float) -> void:
	value = clamp(value + v * (GameState.settings.get("scare_intensity", 1.0) if v > 0 else 1.0), 0.0, 100.0)
	changed.emit(value)
	if value >= 100.0 and not _broken:
		_broken = true
		breakdown.emit()

func tick(delta: float, dark: bool, safe: bool, hiding: bool) -> void:
	var rate := DARK_RATE if dark else LIGHT_RATE
	if hiding:
		rate = min(rate, HIDING_RATE)
	if safe:
		rate = SAFE_RATE
	add(rate * delta)

func reset(v := 0.0) -> void:
	value = clamp(v, 0.0, 100.0)
	_broken = false
	changed.emit(value)

## 0 calm · 1 uneasy (≥30) · 2 shaken (≥60) · 3 breaking (≥85)
func tier() -> int:
	return 3 if value >= 85 else (2 if value >= 60 else (1 if value >= 30 else 0))
