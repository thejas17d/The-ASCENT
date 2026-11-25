extends RefCounted
## Static mesh batching (Phase 8 performance).
## Merges non-moving, opaque MeshInstance3Ds under `root` into one mesh per
## (material, CELL-metre grid cell). Textures are world-space triplanar, so a
## merged mesh looks identical. Cells keep each merged mesh small enough for
## frustum culling and for the Mobile renderer's 8-lights-per-object limit.
## Originals are hidden (collision bodies stay). Skipped:
##   * anything under a node with gameplay metadata (use/item/note/pickup/board/
##     door_index/hide/stair_exit) or marked meta "dynamic"
##   * CharacterBody3D subtrees (player, Supervisor), transparent materials,
##     invisible nodes, non-primitive meshes, non-default render layers.

const CELL := 8.0
const SKIP_META := ["use", "item", "note", "pickup", "board", "door_index", "hide", "stair_exit", "dynamic"]

## Merge under `root`; returns the number of merged meshes created.
static func batch(root: Node3D) -> int:
	var groups := {}        # key -> {mat, st}
	var hidden: Array = []
	_collect(root, root, groups, hidden)
	if groups.is_empty():
		return 0
	var holder := Node3D.new()
	holder.name = "Batched"
	root.add_child(holder)
	for key in groups:
		var g: Dictionary = groups[key]
		var mi := MeshInstance3D.new()
		mi.mesh = g.st.commit()
		mi.material_override = g.mat
		holder.add_child(mi)
	for m in hidden:
		m.visible = false
	return groups.size()

static func _skip(n: Node) -> bool:
	if n is CharacterBody3D or n is MultiMeshInstance3D or n is GPUParticles3D or n is CanvasLayer:
		return true
	for k in SKIP_META:
		if n.has_meta(k):
			return true
	return n is Node3D and not (n as Node3D).visible

static func _collect(n: Node, root: Node3D, groups: Dictionary, hidden: Array) -> void:
	for c in n.get_children():
		if _skip(c):
			continue
		if c is MeshInstance3D and _batchable(c):
			var mi := c as MeshInstance3D
			var xf := _xf_to(mi, root)
			var cell := Vector2i(floori(xf.origin.x / CELL), floori(xf.origin.z / CELL))
			var key := "%d|%d|%d" % [mi.material_override.get_instance_id(), cell.x, cell.y]
			if not groups.has(key):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[key] = {"mat": mi.material_override, "st": st}
			groups[key].st.append_from(mi.mesh, 0, xf)
			hidden.append(mi)
		_collect(c, root, groups, hidden)

static func _batchable(mi: MeshInstance3D) -> bool:
	if not (mi.mesh is PrimitiveMesh) or mi.material_override == null or not mi.visible:
		return false
	if mi.layers != 1:
		return false
	var m := mi.material_override as BaseMaterial3D
	if m == null or m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return false
	return true

## Transform of `n` relative to `root` (works before entering the tree too).
static func _xf_to(n: Node3D, root: Node3D) -> Transform3D:
	var xf := n.transform
	var p := n.get_parent()
	while p and p != root:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf
