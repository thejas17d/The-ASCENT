extends RefCounted
## The game's type (assets/fonts, licence files alongside; credited in-game):
##   Oswald (SIL OFL 1.1)               — UI, titles, signage
##   Special Elite (Apache 2.0)         — typed documents: notes, register, rule boards
##   Noto Sans Devanagari (SIL OFL 1.1) — fallback so Hindi / Marathi signage renders
## install() makes Oswald the engine-wide fallback font, so every Label, Button
## and Label3D picks it up without per-node setup.

const OSWALD := "res://assets/fonts/Oswald.ttf"
const TYPEWRITER := "res://assets/fonts/SpecialElite-Regular.ttf"
const DEVANAGARI := "res://assets/fonts/NotoSansDevanagari.ttf"
static var _cache := {}

static func _file(path: String) -> Font:
	return load(path) if ResourceLoader.exists(path) else null

static func devanagari() -> Font:
	if not _cache.has("deva"):
		_cache["deva"] = _file(DEVANAGARI)
	return _cache["deva"]

## Oswald at a weight (200–700), letter spacing in pixels.
static func ui(weight := 400, spacing := 0) -> Font:
	var key := "ui|%d|%d" % [weight, spacing]
	if not _cache.has(key):
		var base := _file(OSWALD)
		if base == null:
			_cache[key] = null
		else:
			var fv := FontVariation.new()
			fv.base_font = base
			fv.variation_opentype = {"wght": weight}
			fv.spacing_glyph = spacing
			if devanagari():
				fv.fallbacks = [devanagari()]
			_cache[key] = fv
	return _cache[key]

static func typewriter() -> Font:
	if not _cache.has("type"):
		var base := _file(TYPEWRITER)
		if base == null:
			_cache["type"] = null
		else:
			var fv := FontVariation.new()
			fv.base_font = base
			if devanagari():
				fv.fallbacks = [devanagari()]
			_cache["type"] = fv
	return _cache["type"]

## Engine-wide default (called once from GameState._ready, before any UI exists).
static func install() -> void:
	var f := ui(400)
	if f:
		ThemeDB.fallback_font = f
