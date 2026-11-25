extends RefCounted
## Vibration on phones (Android needs the VIBRATE permission — set in the
## export preset). Respects Settings → Haptics. Desktop: no-op, but pulses are
## still recorded in `history` so tests can verify which events vibrate.

static var history: Array = []     # [name, ms, amplitude]

static func pulse(name: String, ms: int, amplitude := 0.6) -> void:
	if not GameState.settings.get("haptics", true):
		return
	history.append([name, ms, amplitude])
	if history.size() > 64:
		history.pop_front()
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms, amplitude)
