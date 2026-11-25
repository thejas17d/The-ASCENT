extends RefCounted
## Real 3D props (CC0, Poly Haven, glTF with 1K PBR textures).
## spawn() instances a model, optionally fits it to a target size, and wraps it
## in a StaticBody3D with a box collider so gameplay metadata (use/item/hide…)
## can live on the body. If a model is missing the caller gets null and should
## fall back to its primitive version — the game never breaks on a missing asset.

const PATH := "res://assets/models/%s/%s_1k.gltf"
static var _scenes := {}
static var _boxes := {}

## Drop cached model scenes so a freed floor's meshes and textures can unload
## (otherwise every model ever loaded stays in VRAM for the whole session).
## Bounds stay cached: they're tiny. Called when a floor or the title screen exits.
static func release() -> void:
	_scenes.clear()

static func available(id: String) -> bool:
	return ResourceLoader.exists(PATH % [id, id])

static func scene(id: String) -> PackedScene:
	if not _scenes.has(id):
		_scenes[id] = load(PATH % [id, id]) if available(id) else null
	return _scenes[id]

## Local-space bounds of a model (computed once from its node transforms).
static func bounds(id: String) -> AABB:
	if _boxes.has(id):
		return _boxes[id]
	var ps := scene(id)
	if ps == null:
		return AABB()
	var inst := ps.instantiate()
	var box := AABB()
	var first := true
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n and n != inst:
			if n is Node3D:
				xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var a: AABB = xf * (mi as MeshInstance3D).mesh.get_aabb()
		box = a if first else box.merge(a)
		first = false
	inst.free()
	_boxes[id] = box
	return box

## fit: target size in metres. All three > 0 → stretch to exactly that box;
## only y > 0 → uniform scale to that height; only x > 0 → uniform to that width.
static func spawn(id: String, fit := Vector3.ZERO, collide := true) -> Node3D:
	var ps := scene(id)
	if ps == null:
		return null
	var model: Node3D = ps.instantiate()
	var box := bounds(id)
	var s := Vector3.ONE
	if fit.x > 0 and fit.y > 0 and fit.z > 0:
		s = Vector3(fit.x / max(box.size.x, 0.001), fit.y / max(box.size.y, 0.001), fit.z / max(box.size.z, 0.001))
	elif fit.y > 0:
		s = Vector3.ONE * fit.y / max(box.size.y, 0.001)
	elif fit.x > 0:
		s = Vector3.ONE * fit.x / max(box.size.x, 0.001)
	model.scale = s
	_fix_glass(model)
	if not collide:
		var holder := Node3D.new()
		holder.add_child(model)
		return holder
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = (box.size * s).max(Vector3(0.05, 0.05, 0.05))
	cs.shape = sh
	cs.position = (box.position + box.size / 2.0) * s
	body.add_child(cs)
	body.add_child(model)
	return body

static var _glass: StandardMaterial3D
## glTF "glass" materials come through opaque (their base-colour texture has no
## alpha), hiding what's behind them (picture artwork, bulb filaments). Swap in
## one shared clear-glass material.
static func _fix_glass(model: Node) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for k in mesh.get_surface_count():
			var mat := mesh.surface_get_material(k)
			if mat and "glass" in mat.resource_name.to_lower():
				if _glass == null:
					_glass = StandardMaterial3D.new()
					_glass.resource_name = "clear_glass"
					_glass.albedo_color = Color(0.85, 0.9, 0.9, 0.1)
					_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					_glass.roughness = 0.04; _glass.metallic = 0.2
					_glass.cull_mode = BaseMaterial3D.CULL_DISABLED
				(mi as MeshInstance3D).set_surface_override_material(k, _glass)
