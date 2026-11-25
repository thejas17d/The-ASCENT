extends RefCounted
## Shared PBR material library. Textures are CC0 from Poly Haven (see
## docs/ASSET_LICENCES.md). World-space triplanar mapping lets code-built
## boxes tile seamlessly with no UV work. Falls back to flat colour if a
## texture set is missing so the game never breaks on a missing asset.

const TEX_2K := "res://assets/textures/%s/%s.jpg"
const TEX_1K := "res://assets/textures_1k/%s/%s.jpg"   # phones and the Low preset
static var _cache := {}
## Per-texture tuning: some scans read far too bumpy as flat code-built walls
## (the old ceiling looked like cave rock). normal = normal-map strength.
const TUNE := {
	"ceiling_interior": {"normal": 0.3},
	"peeling_painted_wall": {"normal": 0.55},
	"white_plaster_02": {"normal": 0.45},
	"terrazzo_tiles": {"normal": 0.6},
	"old_mosaic_floor": {"normal": 0.6},
	"dirty_carpet": {"normal": 0.45},
}

## Generated effect textures (tools/gen_fx_textures.py): torch cookie, decals.
static func fx(name: String) -> Texture2D:
	var p := "res://assets/fx/%s.png" % name
	if not _cache.has(p):
		_cache[p] = load(p) if ResourceLoader.exists(p) else null
	return _cache[p]

## 1K textures on phones (memory, download size) and on the Low preset.
static func tex_pattern() -> String:
	var small: bool = OS.has_feature("mobile") or Graphics.quality == 0
	if small and ResourceLoader.exists(TEX_1K % ["plywood", "albedo"]):
		return TEX_1K
	return TEX_2K

## tile_m: metres covered by one texture repeat.
static func pbr(id: String, tile_m := 2.0, tint := Color.WHITE, rough := 1.0, metal := 0.0) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s|%s" % [id, tile_m, tint, rough, metal]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = rough
	m.metallic = metal
	var TEX := tex_pattern()
	if ResourceLoader.exists(TEX % [id, "albedo"]):
		m.albedo_texture = load(TEX % [id, "albedo"])
		m.normal_enabled = true
		m.normal_texture = load(TEX % [id, "normal"])
		m.normal_scale = float(TUNE.get(id, {}).get("normal", 1.0))
		m.roughness_texture = load(TEX % [id, "rough"])
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		if ResourceLoader.exists(TEX % [id, "ao"]):
			m.ao_enabled = true
			m.ao_texture = load(TEX % [id, "ao"])
			m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			m.ao_light_affect = 0.4
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_triplanar_sharpness = 4.0
		m.uv1_scale = Vector3.ONE / tile_m
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_cache[key] = m
	return m

## Plain lit colour with optional gloss/metal (brass, ceramic, plastic).
static func solid(c: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var key := "solid|%s|%s|%s" % [c, rough, metal]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c; m.roughness = rough; m.metallic = metal
	_cache[key] = m
	return m

static func emissive(c: Color, energy := 2.0) -> StandardMaterial3D:
	var key := "emit|%s|%s" % [c, energy]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true; m.emission = c; m.emission_energy_multiplier = energy
	_cache[key] = m
	return m

## Abstract oil-painting canvas from noise, tinted. albedo_color keeps the tint
## so anomaly checks can compare it.
static func canvas(tint: Color, seed_val: int) -> StandardMaterial3D:
	var key := "canvas|%s|%s" % [tint, seed_val]
	if _cache.has(key):
		return _cache[key]
	var n := FastNoiseLite.new()
	n.seed = seed_val; n.frequency = 0.012
	n.fractal_octaves = 5
	var g := Gradient.new()
	g.set_color(0, Color(0.15, 0.13, 0.11)); g.set_color(1, Color(1.25, 1.2, 1.1))
	g.add_point(0.55, Color(0.75, 0.72, 0.68))
	var t := NoiseTexture2D.new()
	t.width = 256; t.height = 256; t.noise = n; t.color_ramp = g
	var m := StandardMaterial3D.new()
	m.albedo_color = tint; m.albedo_texture = t; m.roughness = 0.55
	_cache[key] = m
	return m
