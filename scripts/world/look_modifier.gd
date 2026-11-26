extends SkeletonModifier3D
## Turns a Rocketbox character's head (and a little of its neck) toward a
## world-space target, layered on top of the mocap and blended by `amount`.
## `tilt` adds a slow roll of the head — the uncanny part.
## Axis-agnostic: the face direction is measured from the character's own
## forward at setup, so no assumptions about the rig's bone axes.

var amount := 0.0
var target := Vector3.ZERO
var tilt := 0.0
var _face := {}            # bone -> face direction in that bone's local space
var _weights := {"Bip01 Neck": 0.35, "Bip01 Head": 0.8}

## character_root: the avatar node whose -/+Z is its forward (Rocketbox faces +Z).
func setup(character_root: Node3D) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	var fwd_world := (character_root.global_transform.basis * Vector3.BACK).normalized()
	var fwd_sk := (sk.global_transform.basis.inverse() * fwd_world).normalized()
	for n in _weights:
		var b := sk.find_bone(n)
		if b >= 0:
			_face[b] = (sk.get_bone_global_rest(b).basis.inverse() * fwd_sk).normalized()   # rest pose faces forward

func _process_modification() -> void:
	if amount <= 0.001 or _face.is_empty():
		return
	var sk := get_skeleton()
	var t := sk.global_transform.affine_inverse() * target
	for n in _weights:
		var b := sk.find_bone(n)
		if not _face.has(b):
			continue
		var gp := sk.get_bone_global_pose(b)
		var cur: Vector3 = (gp.basis * _face[b]).normalized()
		var want := (t - gp.origin).normalized()
		var q := Quaternion(cur, want)
		q = Quaternion.IDENTITY.slerp(q, clampf(amount * float(_weights[n]), 0.0, 1.0))
		var basis := Basis(q) * gp.basis
		if tilt != 0.0 and n == "Bip01 Head":
			basis = Basis(want, tilt * amount) * basis
		gp.basis = basis
		sk.set_bone_global_pose(b, gp)
