extends Node
## Graphics quality presets and the shared environment.
## Low / Medium / High / Ultra. Forward+ (desktop) gets SSAO, SSIL, SSR,
## volumetric fog and TAA; the Mobile renderer silently skips what it can't do.
## Ultra renders at native resolution (4K/UHD on a 4K display) with MSAA+TAA.

signal changed
signal auto_lowered(new_quality: int)

const PRESETS := ["Low", "Medium", "High", "Ultra"]
const INTEGRATED_HINTS := ["intel", "uhd", "iris", "radeon(tm) graphics", "radeon graphics", "vega", "adreno", "mali", "powervr", "apple"]
const SLOW_FRAME_MS := 25.0     # auto mode steps down if a gameplay window averages slower (< 40 fps)
const WINDOW_S := 4.0
const SETTLE_S := 3.0           # ignore shader-compile spikes after a load / change

var quality := 2
var env: Environment          # the active floor's environment (re-configured live)
var auto_mode := false        # Settings → Graphics quality = Auto
var _measuring := false
var _settle := 0.0
var _acc := 0.0
var _frames := 0

func _ready() -> void:
	quality = 1 if is_mobile() else 2

## Integrated / mobile GPUs start on Medium; discrete GPUs on High.
func detect_level() -> int:
	if is_mobile():
		return 1
	var name := RenderingServer.get_video_adapter_name().to_lower()
	for h in INTEGRATED_HINTS:
		if h in name:
			return 1
	return 2

## Floors call this when gameplay starts: auto mode then watches frame times.
func begin_measure() -> void:
	_measuring = auto_mode
	_settle = SETTLE_S
	_acc = 0.0; _frames = 0

func _process(d: float) -> void:
	if not _measuring or get_tree().paused:
		return
	if _settle > 0.0:
		_settle -= d
		return
	_acc += d; _frames += 1
	if _acc < WINDOW_S:
		return
	var avg_ms := _acc / _frames * 1000.0
	_acc = 0.0; _frames = 0
	if avg_ms > SLOW_FRAME_MS and quality > 0:
		apply(quality - 1)
		_settle = SETTLE_S
		GameState.settings["auto_level"] = quality
		GameState.save_settings()
		auto_lowered.emit(quality)

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
	# Low/Medium render below native and upscale with AMD FSR 1 on Forward+ (sharper than
	# bilinear; the Mobile renderer doesn't support FSR in 4.4, so phones use bilinear). High/Ultra render at native resolution (UHD on a 4K display).
	match quality:
		0:
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if forward_plus() else Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 0.67
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			vp.positional_shadow_atlas_size = 1024
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
		1:
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if forward_plus() else Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 0.8
			vp.fsr_sharpness = 0.1
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			vp.positional_shadow_atlas_size = 2048
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
			RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_VERY_LOW, true, 0.5, 2, 50.0, 300.0)
			RenderingServer.environment_set_volumetric_fog_volume_size(48, 48)   # coarse but cheap: torch beams on iGPUs
		2:
			vp.scaling_3d_scale = 1.0
			vp.use_taa = forward_plus()
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED if forward_plus() else Viewport.SCREEN_SPACE_AA_FXAA
			vp.positional_shadow_atlas_size = 4096
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
			RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_MEDIUM, true, 0.5, 2, 50.0, 300.0)
			RenderingServer.environment_set_volumetric_fog_volume_size(64, 64)
		3:
			vp.scaling_3d_scale = 1.0
			vp.use_taa = forward_plus()
			vp.msaa_3d = Viewport.MSAA_2X
			vp.positional_shadow_atlas_size = 8192
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
			RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_HIGH, false, 0.5, 2, 50.0, 300.0)
			RenderingServer.environment_set_volumetric_fog_volume_size(128, 96)
	# directional (moon) shadow map: the big cost on iGPUs, so it scales with the preset
	RenderingServer.directional_shadow_atlas_set_size([1024, 2048, 4096, 4096][quality], true)
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
	env.ambient_light_energy = 0.14
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
	var vol := fp and quality >= 1
	# Medium spends its budget on moonlight shadows + volumetric fog instead of SSAO
	# (measured on the Intel UHD: SSAO ~4 ms, more than both); High and Ultra keep it.
	e.ssao_enabled = fp and quality >= 2
	e.ssao_radius = 1.2
	e.ssao_intensity = 2.2
	e.ssao_detail = 0.6
	e.ssil_enabled = fp and quality >= 2
	e.ssil_intensity = 0.8
	e.ssr_enabled = fp and quality >= 3
	e.ssr_max_steps = 48
	e.glow_enabled = quality >= 1
	e.glow_intensity = 0.7
	e.glow_bloom = 0.08
	e.glow_hdr_threshold = 0.85
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	# volumetric fog makes torch beams and lamp cones visible
	e.volumetric_fog_enabled = vol
	e.volumetric_fog_density = 0.055
	e.volumetric_fog_albedo = Color(0.85, 0.82, 0.78)
	e.volumetric_fog_anisotropy = 0.55
	e.volumetric_fog_length = 32.0 if quality <= 1 else 48.0
	e.volumetric_fog_detail_spread = 2.0
	e.volumetric_fog_ambient_inject = 0.04
	e.volumetric_fog_temporal_reprojection_enabled = true
	# cheap depth fog when volumetrics are off
	e.fog_enabled = not vol
	e.fog_light_color = Color(0.05, 0.045, 0.04)
	e.fog_density = 0.045
