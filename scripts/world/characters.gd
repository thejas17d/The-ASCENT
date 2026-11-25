extends RefCounted
## Real rigged, motion-captured people: Microsoft Rocketbox Avatar Library
## (MIT licence — see docs/ASSET_LICENCES.md). FBX meshes on an 82-bone Biped
## skeleton + separate mocap clips that drive it directly (no retargeting).
## Textures were converted from 2048 TGA to 1024 JPG/PNG; materials are built
## here because the FBX files reference absolute paths from the original export.
##
##   var who := Characters.spawn("Construction_Male_02", {"walk": "m_walk_slow_01"}, {"height": 2.05, "tint": Color(0.2,0.2,0.2)})
##   Characters.play(who, "walk", 1.2)

const AV := "res://assets/characters/%s/%s.fbx"
const ANIM := "res://assets/characters/anims/%s.fbx"
const CODES := {
	"Construction_Male_02": "m101", "Construction_Male_04": "m103", "Construction_Male_07": "m107",
	"Female_Adult_02": "f002", "Male_Adult_03": "m004",
}
const NATIVE_HEIGHT := 1.84
static var _clips := {}

static func available(id: String) -> bool:
	return CODES.has(id) and ResourceLoader.exists(AV % [id, id])

## A mocap clip as a looping Animation (cached).
static func clip(name: String) -> Animation:
	if _clips.has(name):
		return _clips[name]
	var path := ANIM % name
	if not ResourceLoader.exists(path):
		return null
	var inst: Node = load(path).instantiate()
	var players := inst.find_children("*", "AnimationPlayer", true, false)
	var a: Animation = null
	if players.size() > 0:
		var ap := players[0] as AnimationPlayer
		var names := ap.get_animation_list()
		if names.size() > 0:
			a = ap.get_animation(names[0]).duplicate(true)
			a.loop_mode = Animation.LOOP_LINEAR
			# drop helper tracks that don't exist on the avatars
			for t in range(a.get_track_count() - 1, -1, -1):
				if not str(a.track_get_path(t)).begins_with("Skeleton3D"):
					a.remove_track(t)
	inst.free()
	_clips[name] = a
	return a

## opts: height (m), tint (Color multiplies albedo), faceless (bool: blank head),
##       skin (Color for a faceless head), dark (0..1 extra darkening)
static func spawn(id: String, clips: Dictionary, opts := {}) -> Node3D:
	if not available(id):
		return null
	var root: Node3D = load(AV % [id, id]).instantiate()
	var code: String = CODES[id]
	var dir := "res://assets/characters/%s/" % id
	var tint: Color = opts.get("tint", Color.WHITE)
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			var src := m.get_active_material(s)
			var part := (src.resource_name if src else "").trim_prefix(code + "_")
			m.set_surface_override_material(s, _material(dir, code, part, tint, opts))
	var ap: AnimationPlayer = null
	for p in root.find_children("*", "AnimationPlayer", true, false):
		ap = p; break
	if ap == null:
		ap = AnimationPlayer.new(); ap.name = "AnimationPlayer"; root.add_child(ap)
	var lib := AnimationLibrary.new()
	for key in clips:
		var a := clip(str(clips[key]))
		if a:
			lib.add_animation(key, a)
	if ap.has_animation_library("mocap"):
		ap.remove_animation_library("mocap")
	ap.add_animation_library("mocap", lib)
	root.scale = Vector3.ONE * float(opts.get("height", NATIVE_HEIGHT)) / NATIVE_HEIGHT
	root.set_meta("character", id)
	return root

static func _material(dir: String, code: String, part: String, tint: Color, opts: Dictionary) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.roughness = 0.75
	m.albedo_color = tint
	if part == "opacity":
		# hair cards / eyelashes: RGBA colour with an alpha cut-out
		var p := dir + code + "_opacity_color.png"
		if ResourceLoader.exists(p):
			m.albedo_texture = load(p)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.4
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		return m
	if part == "head" and opts.get("faceless", false):
		m.albedo_color = opts.get("skin", Color(0.45, 0.33, 0.26)) * tint
		m.roughness = 0.55
		return m
	var col := dir + "%s_%s_color.jpg" % [code, part]
	var nor := dir + "%s_%s_normal.jpg" % [code, part]
	if ResourceLoader.exists(col):
		m.albedo_texture = load(col)
	if ResourceLoader.exists(nor):
		m.normal_enabled = true
		m.normal_texture = load(nor)
	return m

static func player(who: Node) -> AnimationPlayer:
	for p in who.find_children("*", "AnimationPlayer", true, false):
		return p
	return null

## Play a named clip (blends over 0.25 s); speed scales playback.
static func play(who: Node, clip_name: String, speed := 1.0) -> void:
	var ap := player(who)
	if ap == null:
		return
	var full := "mocap/" + clip_name
	if not ap.has_animation(full):
		return
	if ap.current_animation != full:
		ap.play(full, 0.25)
	ap.speed_scale = speed

static func skeleton(who: Node) -> Skeleton3D:
	for s in who.find_children("*", "Skeleton3D", true, false):
		return s
	return null
