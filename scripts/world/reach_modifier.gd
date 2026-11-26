extends SkeletonModifier3D
## Both arms swing up and out toward a world-space target, blended by `amount`.
## Rocketbox has no grab or attack clips, so the Supervisor's lunge layers this
## on its mocap. Directions come from the bones' own positions (upper arm ->
## forearm -> hand), so it works whatever the rig's axis convention.

var amount := 0.0
var target := Vector3.ZERO
var _chains: Array = []      # [[upper, fore, hand], ...]

func _ready() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for side in ["L", "R"]:
		var ids := [sk.find_bone("Bip01 %s UpperArm" % side), sk.find_bone("Bip01 %s Forearm" % side), sk.find_bone("Bip01 %s Hand" % side)]
		if not ids.has(-1):
			_chains.append(ids)

func _process_modification() -> void:
	if amount <= 0.001 or _chains.is_empty():
		return
	var sk := get_skeleton()
	var t := sk.global_transform.affine_inverse() * target
	for ids in _chains:
		for k in 2:
			var b: int = ids[k]
			var gp := sk.get_bone_global_pose(b)
			var child := sk.get_bone_global_pose(ids[k + 1])
			var cur := (child.origin - gp.origin).normalized()
			var want := (t - gp.origin).normalized()
			if k == 1:
				want = (want + Vector3.UP * 0.15).normalized()   # forearms angle up a touch: hands open, not punching
			var q := Quaternion.IDENTITY.slerp(Quaternion(cur, want), clampf(amount, 0.0, 1.0))
			gp.basis = Basis(q) * gp.basis
			sk.set_bone_global_pose(b, gp)
