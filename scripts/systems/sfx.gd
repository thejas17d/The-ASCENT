extends RefCounted
## Procedural placeholder audio (no external assets). Replace with licensed
## recordings later — see ASSET_LICENCES.md.
const RATE := 22050
static var _cache := {}

## Cached access: get("knock") builds once per run, so floors load without a hitch.
static func get_stream(id: String) -> AudioStreamWAV:
	if not _cache.has(id):
		match id:
			"knock": _cache[id] = knock()
			"hum": _cache[id] = hum()
			"sting": _cache[id] = sting()
			"footsteps": _cache[id] = footsteps()
			"slam": _cache[id] = slam()
			"whisper": _cache[id] = whisper()
			"ring": _cache[id] = ring()
			"gasp": _cache[id] = gasp()
			"step_carpet": _cache[id] = step(0.35, 70.0, 0.06)
			"step_tile": _cache[id] = step(0.7, 180.0, 0.03)
			"step_concrete": _cache[id] = step(0.6, 120.0, 0.04)
			"heartbeat": _cache[id] = heartbeat()
			"click": _cache[id] = click()
	return _cache[id]

static func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray(); bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clamp(samples[i], -1.0, 1.0) * 32000))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = RATE; w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD; w.loop_end = samples.size()
	return w

## Two knuckle thuds on wood.
static func knock() -> AudioStreamWAV:
	var s := PackedFloat32Array(); s.resize(int(RATE * 0.7))
	for start in [0.0, 0.28]:
		var o := int(start * RATE)
		for i in int(RATE * 0.18):
			var t := float(i) / RATE
			var env := exp(-t * 38.0)
			s[o + i] += (sin(TAU * 95.0 * t) * 0.8 + randf_range(-1, 1) * 0.5) * env
	return _wav(s)

## Fluorescent hum + low room tone, loops.
static func hum() -> AudioStreamWAV:
	var n := RATE * 2
	var s := PackedFloat32Array(); s.resize(n)
	for i in n:
		var t := float(i) / RATE
		s[i] = sin(TAU * 50.0 * t) * 0.05 + sin(TAU * 100.0 * t) * 0.03 + randf_range(-1, 1) * 0.012
	return _wav(s, true)

## Low falling drone for rule violations / breakdowns.
static func sting() -> AudioStreamWAV:
	var n := int(RATE * 2.5)
	var s := PackedFloat32Array(); s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var f := 140.0 - t * 40.0
		s[i] = (sin(TAU * f * t) + sin(TAU * f * 1.06 * t)) * 0.3 * exp(-t * 0.9)
	return _wav(s)

## Two soft footfalls (someone behind you).
static func footsteps() -> AudioStreamWAV:
	var s := PackedFloat32Array(); s.resize(int(RATE * 1.4))
	for start in [0.0, 0.55, 1.1]:
		var o := int(start * RATE)
		for i in int(RATE * 0.12):
			var t := float(i) / RATE
			s[o + i] += (sin(TAU * 60.0 * t) * 0.6 + randf_range(-1, 1) * 0.25) * exp(-t * 30.0)
	return _wav(s)

## Heavy door slam.
static func slam() -> AudioStreamWAV:
	var s := PackedFloat32Array(); s.resize(int(RATE * 1.2))
	for i in s.size():
		var t := float(i) / RATE
		s[i] = (sin(TAU * 55.0 * t) + randf_range(-1, 1) * 0.7) * exp(-t * 6.0) * 0.9
	return _wav(s)

## Breathy noise swell.
static func whisper() -> AudioStreamWAV:
	var s := PackedFloat32Array(); s.resize(int(RATE * 1.6))
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		lp = lp * 0.7 + randf_range(-1, 1) * 0.3
		s[i] = lp * sin(PI * t / 1.6) * (0.6 + 0.4 * sin(TAU * 5.0 * t))
	return _wav(s)

## Old telephone bell, two rings.
static func ring() -> AudioStreamWAV:
	var s := PackedFloat32Array(); s.resize(int(RATE * 3.0))
	for i in s.size():
		var t := float(i) / RATE
		var on := fmod(t, 1.5) < 0.9
		s[i] = (sin(TAU * 420.0 * t) * 0.5 + sin(TAU * 470.0 * t) * 0.5) * (0.35 if on else 0.0) * (1.0 if fmod(t * 25.0, 1.0) < 0.5 else 0.6)
	return _wav(s)

## Sharp inhale after holding breath too long.
static func gasp() -> AudioStreamWAV:
	var s := PackedFloat32Array(); s.resize(int(RATE * 0.6))
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		lp = lp * 0.5 + randf_range(-1, 1) * 0.5
		s[i] = lp * sin(PI * t / 0.6) * 0.8
	return _wav(s)

## One footfall. bright 0..1 = how much high-frequency scuff; body = thump pitch.
static func step(bright: float, body: float, length: float) -> AudioStreamWAV:
	var s := PackedFloat32Array(); s.resize(int(RATE * (length + 0.12)))
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		lp = lp * (1.0 - bright * 0.8) + randf_range(-1, 1) * bright * 0.8
		var scuff := lp * exp(-t * 28.0) * 0.5
		var thump := sin(TAU * body * t) * exp(-t * 45.0) * 0.6
		s[i] = scuff + thump
	return _wav(s)

## Lub-dub.
static func heartbeat() -> AudioStreamWAV:
	var s := PackedFloat32Array(); s.resize(int(RATE * 0.7))
	for start in [0.0, 0.22]:
		var o := int(start * RATE)
		for i in int(RATE * 0.16):
			var t := float(i) / RATE
			s[o + i] += sin(TAU * (48.0 - t * 60.0) * t) * exp(-t * 22.0) * (0.9 if start == 0.0 else 0.6)
	return _wav(s)

## Torch switch.
static func click() -> AudioStreamWAV:
	var s := PackedFloat32Array(); s.resize(int(RATE * 0.05))
	for i in s.size():
		var t := float(i) / RATE
		s[i] = randf_range(-1, 1) * exp(-t * 300.0) * 0.6 + sin(TAU * 2400.0 * t) * exp(-t * 400.0) * 0.3
	return _wav(s)
