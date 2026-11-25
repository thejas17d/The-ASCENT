extends DirectionalLight3D
## Moonlight for floors with a view outside. Casts shadows from Medium up — the
## point is the shapes it throws through grilles and between columns.

func _ready() -> void:
	shadow_blur = 1.5
	light_volumetric_fog_energy = 1.2
	Graphics.changed.connect(_apply_quality)
	_apply_quality()

func _apply_quality() -> void:
	shadow_enabled = Graphics.quality >= 1
	# Medium: one cascade over a shorter range (cheap); High+: two cascades
	directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if Graphics.quality <= 1 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	directional_shadow_max_distance = 28.0 if Graphics.quality <= 1 else 45.0
	visible = Graphics.quality >= 1     # without shadows it would light every wall: skip it on Low
