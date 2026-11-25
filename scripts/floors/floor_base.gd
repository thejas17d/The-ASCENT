class_name FloorBase
extends Node3D
## Shared floor plumbing: environment + quality, player, HUD/post-FX, pause,
## Dread, Event Director, audio (footsteps, heartbeat, events), resources
## (battery / chalk / diya / phone), hiding, pickups, notes, dust.
## A floor extends this, builds its level, and overrides the hooks:
##   world_root() -> Node3D      where marks/diyas/pickups are parented
##   floor_lights() -> Array     lights the director may flicker
##   hide_spot() -> Node3D
##   surface_at(pos) -> String   "carpet" / "tile" / "concrete" for footsteps
##   on_interact(target) -> bool return true if handled
##   on_breakdown()
##   perform_floor_event(id) -> bool   floor-specific events

const Player := preload("res://scripts/player/player.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const Pause := preload("res://scripts/ui/pause_menu.gd")
const Sfx := preload("res://scripts/systems/sfx.gd")
const Director := preload("res://scripts/systems/event_director.gd")
const DIYA_SECONDS := 40.0
const DIYA_RADIUS := 3.0

var player: CharacterBody3D
var hud: CanvasLayer
var pause_menu: CanvasLayer
var director: Node
var busy := false
var finished := false
var diyas: Array = []       # [{node, t}]
var chalk_marks: Array = []
var notes: Dictionary = {}  # id -> {title, text, ...}
var _sfx := {}
var _steps: Array = []
var _step_i := 0
var _heart: AudioStreamPlayer
var _heart_t := 0.0
var _dust: GPUParticles3D

func setup_common() -> void:
	var we := WorldEnvironment.new(); we.environment = Graphics.make_environment()
	add_child(we)
	player = Player.new(); add_child(player)
	player.interacted.connect(_on_interact)
	player.chalk_requested.connect(_on_chalk)
	player.diya_requested.connect(_on_diya)
	player.gasped.connect(_on_gasp)
	player.footstep.connect(_on_footstep)
	player.flashlight_toggled.connect(func(_on): _sfx.click.play())
	player.reloaded.connect(func(ok): hud.message("Battery replaced." if ok else "No spare batteries.", 2))
	hud = Hud.new(); add_child(hud)
	pause_menu = Pause.new(); add_child(pause_menu)
	director = Director.new(); director.floor = self; add_child(director)
	Dread.breakdown.connect(_on_breakdown)
	for k in ["knock", "footsteps", "slam", "whisper", "ring"]:
		var p := AudioStreamPlayer3D.new(); p.stream = Sfx.get_stream(k)
		p.unit_size = 6; p.bus = "SFX"; p.attenuation_filter_cutoff_hz = 6000
		add_child(p); _sfx[k] = p
	for k in ["sting", "gasp", "click"]:
		var p := AudioStreamPlayer.new(); p.stream = Sfx.get_stream(k); p.bus = "SFX"
		add_child(p); _sfx[k] = p
	_sfx.click.volume_db = -10
	for i in 3:
		var p := AudioStreamPlayer.new(); p.bus = "SFX"
		add_child(p); _steps.append(p)
	_heart = AudioStreamPlayer.new(); _heart.stream = Sfx.get_stream("heartbeat"); _heart.bus = "SFX"
	add_child(_heart)
	var hum := AudioStreamPlayer.new(); hum.stream = Sfx.get_stream("hum"); hum.volume_db = -10
	hum.bus = "Ambience"; hum.autoplay = true
	add_child(hum)
	_make_dust()
	Graphics.changed.connect(_on_graphics_changed)

func _make_dust() -> void:
	_dust = GPUParticles3D.new()
	_dust.amount = max(1, Graphics.dust_amount())
	_dust.emitting = Graphics.dust_amount() > 0
	_dust.lifetime = 12.0
	_dust.preprocess = 12.0
	_dust.local_coords = false
	_dust.visibility_aabb = AABB(Vector3(-6, -3, -6), Vector3(12, 6, 12))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(4.5, 1.4, 5.5)
	pm.gravity = Vector3(0, -0.006, 0)
	pm.direction = Vector3(0, 1, 0); pm.spread = 180.0
	pm.initial_velocity_min = 0.005; pm.initial_velocity_max = 0.03
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4; pm.turbulence_noise_speed_random = 0.2
	pm.scale_min = 0.5; pm.scale_max = 1.3
	_dust.process_material = pm
	var q := QuadMesh.new(); q.size = Vector2(0.008, 0.008)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.95, 0.92, 0.85, 0.55)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	q.material = m
	_dust.draw_pass_1 = q
	add_child(_dust)

func _on_graphics_changed() -> void:
	_dust.emitting = Graphics.dust_amount() > 0
	if Graphics.dust_amount() > 0:
		_dust.amount = Graphics.dust_amount()
	for l in floor_lights():
		if is_instance_valid(l):
			l.shadow_enabled = Graphics.lamp_shadows()

func play_at(id: String, pos: Vector3) -> void:
	var p: Node = _sfx[id]
	if p is AudioStreamPlayer3D:
		p.global_position = pos
	p.play()

func subtitle(t: String, secs := 2.0) -> void:
	if GameState.settings.get("subtitles", true):
		hud.message(t, secs)

# ---------------------------------------------------------------- hooks
func world_root() -> Node3D: return self
func floor_lights() -> Array: return []
func hide_spot() -> Node3D: return null
func surface_at(_pos: Vector3) -> String: return "concrete"
func on_interact(_t: Object) -> bool: return false
func on_breakdown() -> void: pass
func perform_floor_event(_id: String) -> bool: return false

# ---------------------------------------------------------------- per frame
func _process(d: float) -> void:
	if finished:
		return
	hud.set_prompt(player.prompt())
	hud.set_phone(player.phone_up)
	hud.set_hiding(player.hiding)
	hud.set_breath(player.breath, player.hiding)
	hud.set_status("Torch %d%%   Batteries %d   Chalk %d   Diyas %d" % [
		int(player.battery), GameState.count("battery"), GameState.count("chalk"), GameState.count("diya")])
	if Input.is_action_just_pressed("inventory"):
		_toggle_inventory()
	_dust.global_position = player.global_position + Vector3(0, 1.3, 0)
	for dy in diyas.duplicate():
		dy.t -= d
		if dy.t <= 0.0:
			if is_instance_valid(dy.node):
				dy.node.queue_free()
			diyas.erase(dy)
	if not busy:
		Dread.tick(d, not player.light_on(), in_safe_zone(), player.hiding)
	player.shake = Dread.value / 100.0
	hud.set_dread(Dread.value)
	# heartbeat above 55 dread, faster as it climbs
	_heart_t -= d
	if Dread.value > 55.0 and _heart_t <= 0.0:
		_heart.volume_db = linear_to_db(clamp((Dread.value - 50.0) / 50.0, 0.05, 1.0))
		_heart.play()
		_heart_t = lerp(1.1, 0.5, (Dread.value - 55.0) / 45.0)

func in_safe_zone() -> bool:
	for dy in diyas:
		if is_instance_valid(dy.node) and dy.node.global_position.distance_to(player.global_position) < DIYA_RADIUS:
			return true
	return false

func clear_placed() -> void:
	for dy in diyas:
		if is_instance_valid(dy.node): dy.node.queue_free()
	diyas.clear()
	chalk_marks.clear()

# ---------------------------------------------------------------- actions
func _on_interact(t: Object) -> void:
	if busy or finished:
		return
	if hud.panel_open():
		hud.hide_panel(); return
	if player.hiding:
		player.leave_hiding(); return
	if t == null or not is_instance_valid(t):
		return
	if t.has_meta("note"):
		read_note(str(t.get_meta("note")), t)
		return
	if t.has_meta("pickup"):
		var kind: String = t.get_meta("pickup")
		GameState.add_item(kind, 3 if kind == "chalk" else 1)
		hud.message("Picked up " + kind + ".", 2)
		t.queue_free()
		return
	if t.has_meta("hide") and hide_spot():
		player.hide_in(hide_spot())
		hud.message("You squeeze into the almirah. Hold [Space] to hold your breath.", 3)
		return
	on_interact(t)

func read_note(id: String, node: Object = null) -> void:
	var n: Dictionary = notes.get(id, {"title": "Note", "text": "(illegible)"})
	if not GameState.collectibles.has(id):
		GameState.collectibles.append(id)
		GameState.save_game()
	hud.show_panel("%s\n\n%s\n\n[E] close" % [str(n.title).to_upper(), n.text])
	if node and is_instance_valid(node):
		node.queue_free()

func _on_footstep(loud: float) -> void:
	var surf := surface_at(player.global_position)
	var p: AudioStreamPlayer = _steps[_step_i % _steps.size()]
	_step_i += 1
	p.stream = Sfx.get_stream("step_" + surf)
	p.pitch_scale = randf_range(0.88, 1.12)
	p.volume_db = linear_to_db(clamp(loud, 0.05, 1.0)) - 4.0
	p.play()

func _on_chalk(pos: Vector3, normal: Vector3) -> void:
	if busy or not world_root().has_method("add_chalk"):
		return
	if not GameState.use_item("chalk"):
		hud.message("Out of chalk.", 2); return
	chalk_marks.append(world_root().add_chalk(pos, normal))

func _on_diya(pos: Vector3) -> void:
	if busy or not world_root().has_method("add_diya"):
		return
	if not GameState.use_item("diya"):
		hud.message("No diyas left.", 2); return
	diyas.append({"node": world_root().add_diya(pos), "t": DIYA_SECONDS})
	hud.message("The small flame steadies you.", 2)

func _on_gasp() -> void:
	_sfx.gasp.play()
	Dread.add(5)
	hud.message("You gasp for air.", 2)

func _on_breakdown() -> void:
	if busy:
		# already mid-transition: just recover, no extra penalty
		Dread.reset(40.0)
		return
	_sfx.sting.play()
	hud.glitch(1.6)
	GameState.falls += 1
	on_breakdown()

func _toggle_inventory() -> void:
	if hud.panel_open():
		hud.hide_panel(); return
	var s := "INVENTORY\n\n"
	s += "Batteries   %d      [R] replace\n" % GameState.count("battery")
	s += "Chalk       %d      [C] mark a surface\n" % GameState.count("chalk")
	s += "Diyas       %d      [G] place — a safe glow for %ds\n" % [GameState.count("diya"), DIYA_SECONDS]
	s += "Old phone           [Q] camera — sees what eyes cannot\n"
	s += "\nNOTES FOUND\n"
	var found := 0
	for id in GameState.collectibles:
		if notes.has(id):
			s += "  • " + str(notes[id].title) + "\n"
			found += 1
	if found == 0:
		s += "  (none yet)\n"
	s += "\nTimes the building sent you down: %d\n\n[Tab] close" % GameState.falls
	hud.show_panel(s)

# ---------------------------------------------------------------- events
## Called by the Event Director. Generic events here, floor-specific via hook.
func perform_event(id: String) -> bool:
	var fwd := -player.global_transform.basis.z
	match id:
		"flicker":
			if GameState.settings.get("reduced_flashing", false):
				return false
			var ls := floor_lights().filter(func(l): return is_instance_valid(l) and l.global_position.distance_to(player.global_position) < 14.0)
			if ls.is_empty():
				return false
			_flicker(ls[randi() % ls.size()])
			return true
		"footsteps":
			play_at("footsteps", player.global_position - fwd * 5.0)
			subtitle("(footsteps behind you)")
			return true
		"door_slam":
			play_at("slam", player.global_position + fwd * 12.0)
			subtitle("(a door slams somewhere ahead)")
			return true
		"phone_ring":
			play_at("ring", player.global_position + fwd * 15.0)
			subtitle("(a telephone rings, far away)")
			return true
		"whisper":
			play_at("whisper", player.global_position + player.global_transform.basis.x * (1.0 if randf() < 0.5 else -1.0))
			subtitle("(whispering, very close)")
			return true
		"fake_chalk":
			if not world_root().has_method("add_chalk"):
				return false
			# the building imitates your marks, then they are gone
			var m: Node3D = world_root().add_chalk(player.global_position + fwd * 3.0 + Vector3(0, 1.2, 0) + player.global_transform.basis.x * 1.45, -player.global_transform.basis.x)
			get_tree().create_timer(1.2, false).timeout.connect(func(): if is_instance_valid(m): m.queue_free())
			return true
	return perform_floor_event(id)

func _flicker(l: Light3D) -> void:
	var base := l.light_energy
	var tw := create_tween()
	for i in 6:
		tw.tween_property(l, "light_energy", 0.0, 0.05)
		tw.tween_property(l, "light_energy", base, 0.08)
