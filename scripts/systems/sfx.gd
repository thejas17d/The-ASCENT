extends RefCounted
## Procedural placeholder audio (no external assets). Replace with licensed
## recordings later — see ASSET_LICENCES.md.
const RATE := 22050

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
