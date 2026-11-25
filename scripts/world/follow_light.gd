extends SpotLight3D
## A ceiling fixture's downlight that mirrors its parent lamp (the OmniLight3D
## floors and events control): energy, colour and visibility follow every frame,
## so flickers, blackouts and Night Shift dimming apply to the pool of light too.
## Casts shadows from High up (faded out with distance to bound the cost).

var ratio := 2.2

func _ready() -> void:
	Graphics.changed.connect(_apply_quality)
	_apply_quality()

func _apply_quality() -> void:
	shadow_enabled = Graphics.quality >= 2
	shadow_blur = 1.4
	shadow_bias = 0.04

func _process(_d: float) -> void:
	var src := get_parent() as Light3D
	if src == null:
		return
	light_energy = src.light_energy * ratio
	light_color = src.light_color
	visible = src.visible
