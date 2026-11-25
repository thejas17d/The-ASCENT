extends RefCounted
## The city outside: a night sky with sodium-orange light pollution on the
## horizon, and a ring of distant tower silhouettes with lit windows (one
## MultiMesh, so it costs a couple of draw calls). Used by the open floors
## (Floor 5's rain-soaked slab, the roof). A backdrop, not a place.

## Night sky on the floor's Environment. Ambient light stays a flat colour so
## the sky never floods interiors.
static func night_sky(env: Environment, top: Color, horizon: Color, ground: Color, energy := 1.0) -> void:
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = top
	sm.sky_horizon_color = horizon
	sm.sky_curve = 0.12
	sm.ground_bottom_color = ground
	sm.ground_horizon_color = horizon.lerp(ground, 0.4)
	sm.ground_curve = 0.05
	sm.sun_angle_max = 0.0
	sm.sky_energy_multiplier = energy
	sm.ground_energy_multiplier = energy
	sm.use_debanding = true
	var sky := Sky.new(); sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.background_mode = Environment.BG_SKY
	env.sky = sky

## Silhouettes on four sides around `center`. y_base: world height of the
## street far below; windows get `window_col` (scaled per window).
static func build(parent: Node3D, center: Vector3, seed_val: int, y_base: float, sil_col: Color, window_col: Color, lit := 0.22) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_val
	var towers: Array = []; var xf: Array = []; var cols: Array = []
	for side in 4:
		var yaw := side * PI / 2
		var basis := Basis(Vector3.UP, yaw)
		var x := -95.0
		while x < 95.0:
			var bw := rng.randf_range(6.0, 16.0)
			var bh := rng.randf_range(8.0, 42.0)
			var dist := rng.randf_range(62.0, 80.0)
			var c := center + basis * Vector3(x + bw / 2, y_base + bh / 2, -dist)
			towers.append(Transform3D(basis.scaled(Vector3(bw, bh, 4.0)), c))
			var wy := y_base + 1.0
			while wy < y_base + bh - 1.5:
				var wx := x + 0.8
				while wx < x + bw - 0.8:
					if rng.randf() < lit:
						xf.append(Transform3D(basis, center + basis * Vector3(wx, wy, -dist + 2.05)))
						cols.append(window_col * rng.randf_range(0.25, 0.8))
					wx += 1.3
				wy += 1.9
			x += bw + rng.randf_range(0.5, 4.0)
	# tower silhouettes: one instanced unit box (a single draw call)
	var tm := MultiMesh.new(); tm.transform_format = MultiMesh.TRANSFORM_3D
	tm.mesh = BoxMesh.new(); tm.instance_count = towers.size()
	for k in towers.size():
		tm.set_instance_transform(k, towers[k])
	var ti := MultiMeshInstance3D.new(); ti.multimesh = tm
	var sil := StandardMaterial3D.new(); sil.albedo_color = sil_col; sil.roughness = 1.0
	ti.material_override = sil
	ti.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ti)
	# lit windows
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = true
	var q := QuadMesh.new(); q.size = Vector2(0.55, 0.75); mm.mesh = q
	mm.instance_count = xf.size()
	for k in xf.size():
		mm.set_instance_transform(k, xf[k]); mm.set_instance_color(k, cols[k])
	var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm
	var wm := StandardMaterial3D.new(); wm.vertex_color_use_as_albedo = true
	wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mmi.material_override = wm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)

## A low moon (scripts/world/moon_light.gd: shadows from Medium up).
static func moon(parent: Node3D, col: Color, energy: float, rot: Vector3) -> DirectionalLight3D:
	var m: DirectionalLight3D = preload("res://scripts/world/moon_light.gd").new()
	m.light_color = col; m.light_energy = energy; m.rotation = rot
	parent.add_child(m)
	return m
