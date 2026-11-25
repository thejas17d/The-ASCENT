extends Node
## Graphics quality presets and the shared environment.
## Low / Medium / High / Ultra. Forward+ (desktop) gets SSAO, SSIL, SSR,
## volumetric fog and TAA; the Mobile renderer silently skips what it can't do.
## Ultra renders at native resolution (4K/UHD on a 4K display) with MSAA+TAA.

signal changed

const PRESETS := ["Low", "Medium", "High", "Ultra"]

var quality := 2
var env: Environment          # the active floor's environment (re-configured live)

func _ready() -> void:
	quality = 1 if is_mobile() else 2

func is_mobile() -> bool:
	return OS.has_feature("mobile")

func forward_plus() -> bool:
	return RenderingServer.get_current_rendering_method() == "forward_plus"

## Called by Settings and at boot.
func apply(q: int) -> void:
	quality = clampi(q, 0, PRESETS.size() - 1)
	var vp := get_viewport() if is_inside_tree() else null
	if vp == null:
		# autoloads can be initialised before the root viewport is ready
		call_deferred("apply", quality)
		return
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = false
	vp.msaa_3d = Viewport.MSAA_DISABLED
	match quality:
		0:
			vp.scaling_3d_scale = 0.7
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			vp.positional_shadow_atlas_size = 1024
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
		1:
			vp.scaling_3d_scale = 0.9
			vp.msaa_3d = Viewport.MSAA_2X
			vp.positional_shadow_atlas_size = 2048
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
		2:
			vp.scaling_3d_scale = 1.0
			vp.use_taa = forward_plus()
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED if forward_plus() else Viewport.SCREEN_SPACE_AA_FXAA
			vp.positional_shadow_atlas_size = 4096
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
		3:
			vp.scaling_3d_scale = 1.0
			vp.use_taa = forward_plus()
			vp.msaa_3d = Viewport.MSAA_4X
			vp.positional_shadow_atlas_size = 8192
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	if env:
		configure(env)
	changed.emit()

## Whether ceiling lamps cast shadows (expensive omni shadows).
func lamp_shadows() -> bool:
	return quality >= 3

func dust_amount() -> int:
	return [0, 120, 260, 420][quality]

func make_environment() -> Environment:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.3, 0.27)
	env.ambient_light_energy = 0.18
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	# horror grade: a little desaturated, a little contrasty
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.82
	env.adjustment_contrast = 1.08
	configure(env)
	return env

func configure(e: Environment) -> void:
	var fp := forward_plus()
	var vol := fp and quality >= 2
	e.ssao_enabled = fp and quality >= 1
	e.ssao_radius = 1.2
	e.ssao_intensity = 2.2
	e.ssao_detail = 0.6
	e.ssil_enabled = fp and quality >= 2
	e.ssil_intensity = 0.8
	e.ssr_enabled = fp and quality >= 3
	e.ssr_max_steps = 48
	e.glow_enabled = quality >= 1
	e.glow_intensity = 0.55
	e.glow_bloom = 0.04
	e.glow_hdr_threshold = 0.9
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	# volumetric fog makes torch beams and lamp cones visible
	e.volumetric_fog_enabled = vol
	e.volumetric_fog_density = 0.028
	e.volumetric_fog_albedo = Color(0.85, 0.82, 0.78)
	e.volumetric_fog_anisotropy = 0.55
	e.volumetric_fog_length = 48.0
	e.volumetric_fog_detail_spread = 2.0
	e.volumetric_fog_ambient_inject = 0.15
	e.volumetric_fog_temporal_reprojection_enabled = true
	# cheap depth fog when volumetrics are off
	e.fog_enabled = not vol
	e.fog_light_color = Color(0.05, 0.045, 0.04)
	e.fog_density = 0.045
