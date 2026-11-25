extends CharacterBody3D
## THE SUPERVISOR — the building's recurring entity.
##
## Fairness contract (what the player can always rely on):
##  * Its helmet lamp shows its state: dim yellow = patrolling, amber = it
##    noticed something, red = it is chasing you.
##  * Heavy footsteps are always audible within ~15 m; faster = chasing.
##  * It never spawns within min_spawn_distance or in your line of sight.
##  * Sight needs line of sight and its field of view; walls block it.
##  * Hearing is noise-based: running is loud, walking quiet, crouching near-silent,
##    holding breath while hidden is silent. A gasp is loud.
##  * Hiding works unless it SAW you get in, or it has learned your favourite
##    kind of hiding place (it tells you when it has).
##
## Senses can be switched per floor (Floor 5: "it hunts by light / by sound").

signal state_changed(new_state: String)
signal caught_player
signal learned(kind: String)

enum S { DORMANT, PATROL, SUSPICIOUS, INVESTIGATE, SEARCH, CHASE, ATTACK, RETURN }
const NAMES := ["dormant", "patrol", "suspicious", "investigate", "search", "chase", "attack", "return"]
const Sfx := preload("res://scripts/systems/sfx.gd")
const Mat := preload("res://scripts/systems/mat_lib.gd")
const EYE_H := 1.95
const NOTICE_BEAT := 0.8      # seconds it stops and stares before chasing
const CLOSE_RANGE := 4.0      # inside this, no warning beat

var senses := {"sight": true, "sound": true, "light": true}
var cfg: Dictionary = {}
var state: int = S.DORMANT
var player: CharacterBody3D
var hide_spots: Array = []          # Node3D with meta "hide_kind"
var waypoints: Array = []           # Vector3
var awareness := 0.0
var last_known := Vector3.ZERO
var hide_memory := {}               # kind -> times player used it
var saw_player_hide := false
var last_perception := {}

var _wp := 0
var _wait := 0.0
var _state_t := 0.0
var _unseen_t := 0.0
var _search_queue: Array = []
var _checking: Node3D
var _check_t := 0.0
var _goal := Vector3.INF
var _agent: NavigationAgent3D
var _lamp: SpotLight3D
var _lens: StandardMaterial3D
var _legs: Array = []
var _arms: Array = []
var _head: Node3D
var _walk := 0.0
var _step_t := 0.0
var _steps: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	if cfg.is_empty():
		cfg = JSON.parse_string(FileAccess.open("res://data/ai/supervisor.json", FileAccess.READ).get_as_text())
	collision_layer = 4
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new(); cap.radius = 0.35; cap.height = 2.1
	cs.shape = cap; cs.position.y = 1.05
	add_child(cs)
	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.6
	_agent.target_desired_distance = 0.7
	_agent.agent_height_offset = 0.0
	_agent.radius = 0.4
	add_child(_agent)
	_build_body()
	_steps = AudioStreamPlayer3D.new()
	_steps.stream = Sfx.get_stream("step_concrete")
	_steps.bus = "SFX"; _steps.unit_size = 5.0; _steps.max_distance = 22.0
	_steps.volume_db = 4.0
	add_child(_steps)

## A tall, thin worker in a long coat and a dusty site helmet. Its face is
## never lit: the helmet lamp points away from it.
func _build_body() -> void:
	var coat := Mat.solid(Color(0.03, 0.03, 0.032), 0.95)
	var skin := Mat.solid(Color(0.02, 0.018, 0.016), 0.9)
	var helmet := Mat.solid(Color(0.55, 0.42, 0.08), 0.8)
	var tm := CapsuleMesh.new(); tm.radius = 0.26; tm.height = 1.15
	var torso := _part(tm, Vector3(0, 1.45, 0), coat)
	torso.scale = Vector3(1.0, 1.0, 0.65)
	for x in [-0.12, 0.12]:
		var hip := Node3D.new(); hip.position = Vector3(x, 0.95, 0); add_child(hip)
		var leg := MeshInstance3D.new(); var lm := CapsuleMesh.new(); lm.radius = 0.09; lm.height = 0.95
		leg.mesh = lm; leg.position.y = -0.47; leg.material_override = coat
		hip.add_child(leg); _legs.append(hip)
	for x in [-0.34, 0.34]:
		var sh := Node3D.new(); sh.position = Vector3(x, 1.85, 0); add_child(sh)
		var arm := MeshInstance3D.new(); var am := CapsuleMesh.new(); am.radius = 0.06; am.height = 1.05
		arm.mesh = am; arm.position.y = -0.5; arm.material_override = skin
		sh.add_child(arm); _arms.append(sh)
	_head = Node3D.new(); _head.position = Vector3(0, 2.0, 0); add_child(_head)
	var hm := SphereMesh.new(); hm.radius = 0.12; hm.height = 0.28
	var head := MeshInstance3D.new(); head.mesh = hm; head.material_override = skin
	_head.add_child(head)
	var dome := SphereMesh.new(); dome.radius = 0.16; dome.height = 0.16; dome.is_hemisphere = true
	var hel := MeshInstance3D.new(); hel.mesh = dome; hel.position.y = 0.06; hel.material_override = helmet
	_head.add_child(hel)
	var bm := CylinderMesh.new(); bm.top_radius = 0.2; bm.bottom_radius = 0.2; bm.height = 0.015
	var brim := MeshInstance3D.new(); brim.mesh = bm; brim.position.y = 0.06; brim.material_override = helmet
	_head.add_child(brim)
	var lens := MeshInstance3D.new(); var lsm := CylinderMesh.new()
	lsm.top_radius = 0.035; lsm.bottom_radius = 0.035; lsm.height = 0.03
	lens.mesh = lsm; lens.rotation.x = PI / 2; lens.position = Vector3(0, 0.1, -0.16)
	_lens = StandardMaterial3D.new(); _lens.emission_enabled = true; _lens.emission_energy_multiplier = 4.0
	lens.material_override = _lens
	_head.add_child(lens)
	_lamp = SpotLight3D.new()
	_lamp.position = Vector3(0, 0.1, -0.18)
	_lamp.spot_range = 9.0; _lamp.spot_angle = 22.0; _lamp.light_energy = 1.4
	_lamp.light_volumetric_fog_energy = 2.5
	_lamp.shadow_enabled = Graphics.quality >= 2
	_head.add_child(_lamp)
	_set_lamp(Color(1.0, 0.82, 0.45), 0.9)

func _part(mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.position = pos; mi.material_override = mat
	add_child(mi)
	return mi

func _set_lamp(c: Color, energy: float) -> void:
	_lamp.light_color = c; _lamp.light_energy = energy
	_lens.albedo_color = c; _lens.emission = c

# ---------------------------------------------------------------- control API
func activate(at: Vector3) -> void:
	global_position = at
	awareness = 0.0
	saw_player_hide = false
	_set_state(S.PATROL)

func deactivate() -> void:
	_set_state(S.DORMANT)
	velocity = Vector3.ZERO

func state_name() -> String:
	return NAMES[state]

## Something happened at pos: a flickering lamp ("light") or a clatter ("sound").
## It only reacts if it hunts by that sense — which is how players learn the true rule.
func lure(pos: Vector3, kind: String) -> bool:
	if not senses.get(kind, false) or state in [S.CHASE, S.ATTACK, S.DORMANT]:
		return false
	last_known = pos
	awareness = max(awareness, float(cfg.investigate_at))
	_set_state(S.INVESTIGATE)
	_goal = Vector3.INF
	return true

## The building remembers every hiding place you use.
func note_player_hid(kind: String, seen: bool) -> void:
	hide_memory[kind] = int(hide_memory.get(kind, 0)) + 1
	if seen:
		saw_player_hide = true
	if int(hide_memory[kind]) == int(cfg.learn_threshold):
		learned.emit(kind)

## Pick a spawn point far from the player and out of their sight.
func safe_spawn_point(points: Array, from: Vector3, space: PhysicsDirectSpaceState3D) -> Vector3:
	var best := Vector3.INF
	var best_d := -1.0
	for p in points:
		var d: float = from.distance_to(p)
		if d < float(cfg.min_spawn_distance):
			continue
		if space and _ray_clear(space, from + Vector3(0, 1.5, 0), p + Vector3(0, 1.5, 0)):
			continue   # visible to the player
		if d > best_d:
			best_d = d; best = p
	return best

# ---------------------------------------------------------------- loop
func _physics_process(d: float) -> void:
	if not is_on_floor():
		velocity.y -= 9.8 * d
	if state == S.DORMANT or state == S.ATTACK or player == null:
		velocity.x = 0; velocity.z = 0
		move_and_slide()
		return
	_state_t += d
	last_perception = perceive()
	_update_awareness(d, last_perception)
	_think(d, last_perception)
	_move(d)
	_animate(d)

## What it senses this frame. Public for tests.
func perceive() -> Dictionary:
	var res := {"seen": false, "heard": false, "light": false, "strength": 0.0}
	if player == null:
		return res
	var space := get_world_3d().direct_space_state
	var eye := global_position + Vector3(0, EYE_H, 0)
	var target: Vector3 = player.global_position + Vector3(0, 1.2 if not player.is_crouching else 0.7, 0)
	var to := target - eye
	var dist := to.length()
	var los := _ray_clear(space, eye, target)
	# sight
	if senses.sight and not player.hiding:
		var fwd := -global_transform.basis.z
		var flat := Vector3(to.x, 0, to.z).normalized()
		var ang := rad_to_deg(fwd.angle_to(flat))
		var rng: float = cfg.sight_range_torch_on if player.light_on() else cfg.sight_range
		if player.is_crouching:
			rng *= float(cfg.crouch_sight_mult)
		if los and ((dist < rng and ang < float(cfg.fov_degrees) * 0.5) or dist < float(cfg.proximity_sense)):
			res.seen = true
			res.strength = clamp(1.0 - dist / rng, 0.1, 1.0)
	# touch range: even a blind hunter knows when you are right next to it
	if not res.seen and los and dist < float(cfg.proximity_sense) and not player.hiding:
		res.seen = true
		res.strength = 1.0
	# sound
	if senses.sound:
		var hear: float = float(player.noise) * float(cfg.hearing_range)
		if not los:
			hear *= float(cfg.hearing_through_walls_mult)
		if dist < hear:
			res.heard = true
	# light (a): a lit torch anywhere in its field of view is a beacon — even when blind to shapes
	if senses.light and player.light_on() and not player.hiding and los:
		var fwd2 := -global_transform.basis.z
		var flat2 := Vector3(to.x, 0, to.z).normalized()
		if dist < float(cfg.sight_range_torch_on) and rad_to_deg(fwd2.angle_to(flat2)) < float(cfg.fov_degrees) * 0.5:
			res.light = true
	# light (b): the torch beam pointed at it
	if senses.light and player.light_on() and not player.hiding:
		var pf: Vector3 = -player.cam.global_transform.basis.z
		var to_me: Vector3 = eye - player.cam.global_position
		var beam: SpotLight3D = player.light
		if to_me.length() < beam.spot_range and rad_to_deg(pf.angle_to(to_me.normalized())) < beam.spot_angle + 8.0 \
				and _ray_clear(space, player.cam.global_position, eye):
			res.light = true
	return res

## True if nothing but the player/itself lies between a and b (world layer only).
func _ray_clear(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	var ex: Array[RID] = [get_rid()]
	if player:
		ex.append(player.get_rid())
	q.exclude = ex
	return space.intersect_ray(q).is_empty()

func _update_awareness(d: float, p: Dictionary) -> void:
	var any := false
	if p.seen:
		awareness += d * float(cfg.awareness_gain_sight) * (0.6 + p.strength * 2.0)
		last_known = player.global_position
		any = true
	if p.light:
		awareness += d * float(cfg.awareness_gain_light)
		last_known = player.global_position
		any = true
	if p.heard:
		var floor_level := 0.75 if player.noise >= 0.9 else 0.5
		awareness = max(awareness, floor_level)
		if not senses.sight:
			awareness += d * 1.2   # a blind hunter homes in on sound
		# hearing is imprecise
		last_known = player.global_position + Vector3(_rng.randf_range(-1.2, 1.2), 0, _rng.randf_range(-1.2, 1.2))
		any = true
	if any:
		_unseen_t = 0.0
	else:
		_unseen_t += d
		awareness -= d * float(cfg.awareness_decay)
	awareness = clamp(awareness, 0.0, 1.5)

func _think(d: float, p: Dictionary) -> void:
	var direct: bool = p.seen or p.light or (not senses.sight and p.heard)
	match state:
		S.PATROL, S.RETURN:
			# always give the player an amber "it noticed you" beat before a chase
			if awareness >= float(cfg.chase_at) and direct and _dist_to_player() < CLOSE_RANGE:
				_set_state(S.CHASE)
			elif awareness >= float(cfg.suspicious_at) and direct:
				_set_state(S.SUSPICIOUS)
			elif awareness >= float(cfg.investigate_at):
				_set_state(S.INVESTIGATE)
			elif awareness >= float(cfg.suspicious_at):
				_set_state(S.SUSPICIOUS)
			elif state == S.RETURN and _arrived():
				_set_state(S.PATROL)
			else:
				_patrol(d)
		S.SUSPICIOUS:
			_face(last_known, d, 2.5)
			if _state_t < NOTICE_BEAT and _dist_to_player() > CLOSE_RANGE:
				return
			if awareness >= float(cfg.chase_at) and direct:
				_set_state(S.CHASE)
			elif awareness >= float(cfg.investigate_at):
				_set_state(S.INVESTIGATE)
			elif _state_t > 3.0 and awareness < float(cfg.suspicious_at):
				_set_state(S.PATROL)
		S.INVESTIGATE:
			_go(last_known)
			if awareness >= float(cfg.chase_at) and direct:
				_set_state(S.CHASE)
			elif _arrived() or _state_t > 20.0:
				_set_state(S.SEARCH)
		S.CHASE:
			if player.hiding:
				if saw_player_hide:
					_go(player.global_position)
				else:
					_set_state(S.SEARCH)
					return
			else:
				_go(player.global_position if (direct or p.heard) else last_known)
			if not player.hiding or saw_player_hide:
				if global_position.distance_to(player.global_position) < float(cfg.attack_range):
					_set_state(S.ATTACK)
					caught_player.emit()
					return
			if _unseen_t > float(cfg.lose_after):
				_set_state(S.SEARCH)
		S.SEARCH:
			if awareness >= float(cfg.chase_at) and direct:
				_set_state(S.CHASE)
				return
			_search(d)
			if _state_t > float(cfg.search_time):
				_set_state(S.RETURN)

func _set_state(s: int) -> void:
	if s == state:
		return
	var prev := state
	state = s
	_state_t = 0.0
	_goal = Vector3.INF
	match s:
		S.PATROL:
			_set_lamp(Color(1.0, 0.82, 0.45), 0.9)
		S.SUSPICIOUS, S.INVESTIGATE, S.SEARCH:
			_set_lamp(Color(1.0, 0.55, 0.1), 1.4)
		S.CHASE, S.ATTACK:
			_set_lamp(Color(1.0, 0.08, 0.04), 2.2)
		S.RETURN:
			_set_lamp(Color(1.0, 0.82, 0.45), 0.9)
			_go(_nearest_waypoint())
	if s == S.SEARCH:
		# re-acquiring you needs fresh perception, not leftover alarm
		awareness = min(awareness, float(cfg.chase_at) * 0.7)
		_build_search_queue()
	if s == S.RETURN:
		awareness = min(awareness, float(cfg.suspicious_at) * 0.8)
	if s == S.CHASE and prev != S.CHASE:
		Dread.add(12)
	state_changed.emit(NAMES[s])

# ---------------------------------------------------------------- behaviours
func _patrol(d: float) -> void:
	if waypoints.is_empty():
		return
	if _wait > 0.0:
		_wait -= d
		_head.rotation.y = sin(_state_t * 1.3) * 0.7   # looking around
		return
	_head.rotation.y = lerp(_head.rotation.y, 0.0, d * 3.0)
	_go(waypoints[_wp])
	if _arrived():
		_wp = (_wp + 1) % waypoints.size()
		_wait = float(cfg.patrol_pause)
		_goal = Vector3.INF

func _nearest_waypoint() -> Vector3:
	var best: Vector3 = global_position
	var bd := INF
	for i in waypoints.size():
		var dd: float = global_position.distance_to(waypoints[i])
		if dd < bd:
			bd = dd; best = waypoints[i]; _wp = i
	return best

## Learned preference first, then distance from where it lost you.
func _build_search_queue() -> void:
	var near := hide_spots.filter(func(h): return is_instance_valid(h) and h.global_position.distance_to(last_known) < float(cfg.search_radius))
	near.sort_custom(func(a, b):
		var pa := int(hide_memory.get(a.get_meta("hide_kind", ""), 0))
		var pb := int(hide_memory.get(b.get_meta("hide_kind", ""), 0))
		if pa != pb:
			return pa > pb
		return a.global_position.distance_to(last_known) < b.global_position.distance_to(last_known))
	_search_queue = near.slice(0, int(cfg.search_spots))
	_checking = null
	_go(last_known)

func search_queue() -> Array:
	return _search_queue

func _search(d: float) -> void:
	if _checking == null:
		if not _arrived() and _goal != Vector3.INF:
			return
		if _search_queue.is_empty():
			# nothing left to check: wander around the last known point
			if _arrived() or _goal == Vector3.INF:
				_go(last_known + Vector3(_rng.randf_range(-4, 4), 0, _rng.randf_range(-4, 4)))
			return
		_checking = _search_queue.pop_front()
		_check_t = 0.0
		_go(_checking.global_position - _checking.global_basis.z * 0.9)
		return
	if not _arrived():
		return
	_face(_checking.global_position, d, 4.0)
	_check_t += d
	if _check_t >= float(cfg.check_time):
		if player.hiding and player.global_position.distance_to(_checking.global_position) < 0.6:
			var kind: String = _checking.get_meta("hide_kind", "")
			var learned_it := int(hide_memory.get(kind, 0)) >= int(cfg.learn_threshold)
			if saw_player_hide or learned_it or not player.holding_breath:
				_set_state(S.ATTACK)
				caught_player.emit()
				return
		_checking = null
		_goal = Vector3.INF

# ---------------------------------------------------------------- movement
func _dist_to_player() -> float:
	return global_position.distance_to(player.global_position) if player else INF

func _speed() -> float:
	match state:
		S.CHASE: return float(cfg.speed_chase)
		S.INVESTIGATE: return float(cfg.speed_investigate)
		S.SEARCH: return float(cfg.speed_search)
		S.SUSPICIOUS: return 0.0
	return float(cfg.speed_patrol)

func _go(p: Vector3) -> void:
	if _goal == Vector3.INF or _goal.distance_to(p) > 0.5:
		_goal = p
		_agent.target_position = p

func _arrived() -> bool:
	if _goal == Vector3.INF:
		return false
	return _agent.is_navigation_finished() or Vector2(global_position.x - _goal.x, global_position.z - _goal.z).length() < 0.8

func _move(d: float) -> void:
	var sp := _speed()
	if sp <= 0.0 or _goal == Vector3.INF or _agent.is_navigation_finished():
		velocity.x = move_toward(velocity.x, 0.0, d * 8.0)
		velocity.z = move_toward(velocity.z, 0.0, d * 8.0)
	else:
		var nxt := _agent.get_next_path_position()
		var dir := nxt - global_position; dir.y = 0
		if dir.length() > 0.05:
			dir = dir.normalized()
			velocity.x = dir.x * sp
			velocity.z = dir.z * sp
			_face(global_position + dir, d, 6.0 if state == S.CHASE else 3.0)
	move_and_slide()

func _face(p: Vector3, d: float, rate: float) -> void:
	var flat := Vector3(p.x - global_position.x, 0, p.z - global_position.z)
	if flat.length() < 0.05:
		return
	var target_yaw := atan2(-flat.x, -flat.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, clamp(d * rate, 0.0, 1.0))

func _animate(d: float) -> void:
	var spd := Vector2(velocity.x, velocity.z).length()
	if spd > 0.2:
		_walk += d * spd * 3.2
		_step_t -= d
		if _step_t <= 0.0:
			_steps.pitch_scale = _rng.randf_range(0.55, 0.68)
			_steps.play()
			_step_t = PI / (spd * 3.2)
	var sw: float = sin(_walk) * clamp(spd / 3.0, 0.0, 0.6)
	_legs[0].rotation.x = sw; _legs[1].rotation.x = -sw
	_arms[0].rotation.x = -sw * 0.5; _arms[1].rotation.x = sw * 0.5
	# chasing: arms reach forward
	var reach := -0.9 if state == S.CHASE else 0.0
	for a in _arms:
		a.rotation.x = lerp(a.rotation.x, a.rotation.x + reach, 0.5)
	if state == S.SUSPICIOUS or state == S.CHASE:
		var to := player.global_position - global_position
		var local := global_transform.basis.inverse() * to
		_head.rotation.y = lerp_angle(_head.rotation.y, clamp(atan2(-local.x, -local.z), -1.0, 1.0), d * 4.0)
