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

var player: Player
var hud: Hud
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
var floor_index := -1             # set by each floor before setup_common()
var rules: Dictionary = {}
var exit_unlocked := false
var exit_hint := "Locked. Something on this floor still holds it shut."
var spawn := Vector3.ZERO         # where you arrive / respawn
var spawn_yaw := 0.0
const Kit := preload("res://scripts/world/kit.gd")

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
	for k in ["knock", "footsteps", "slam", "whisper", "ring", "splash", "clang"]:
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
	if not scales_own_lights():
		for l in floor_lights():
			if is_instance_valid(l):
				l.light_energy *= GameState.light_scale()

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
func scales_own_lights() -> bool: return false
func on_item_taken(_id: String, _node: Node3D) -> bool: return false
func on_use(_id: String, _node: Node3D) -> void: pass
func apply_checkpoint(_cp: Dictionary) -> void: pass
func floor_lights() -> Array: return []
func hide_spot() -> Node3D: return null
func surface_at(_pos: Vector3) -> String: return "concrete"
func on_interact(_t: Object) -> bool: return false
## Default breakdown: sent down a floor (floors 1–4) or death (5–8).
func on_breakdown() -> void:
	fall_down("BREAKDOWN. Your mind gives out.")
func perform_floor_event(_id: String) -> bool: return false
func on_player_hid(_spot: Node3D) -> void: pass

# ---------------------------------------------------------------- per frame
func _process(d: float) -> void:
	if finished:
		return
	player.ui_lock = hud.dialog_open() or pause_menu.is_open()
	hud.set_prompt("" if player.ui_lock else player.prompt())
	hud.set_phone(player.phone_up)
	hud.set_hiding(player.hiding)
	hud.set_breath(player.breath, player.hiding)
	hud.set_status("Torch %d%%   Batteries %d   Chalk %d   Diyas %d" % [
		int(player.battery), GameState.count("battery"), GameState.count("chalk"), GameState.count("diya")])
	if Input.is_action_just_pressed("inventory"):
		_toggle_inventory()
	if Input.is_action_just_pressed("voice"):
		play_voice_note()
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

## Mother's voice notes: limited, each one calms you (Dread -35 over 6 s).
var voice_playing := false
func play_voice_note() -> bool:
	if voice_playing or busy:
		return false
	if not GameState.use_item("voice"):
		hud.message("No voice notes.", 1.5)
		return false
	voice_playing = true
	var used := int(GameState.unlocks.get("voice_played", 0))
	GameState.unlocks["voice_played"] = used + 1
	var sets: Array = JSON.parse_string(FileAccess.open("res://data/story/voice_notes.json", FileAccess.READ).get_as_text())
	var lines: Array = sets[used % sets.size()]
	var tw := create_tween()
	tw.tween_method(func(v): Dread.reset(v), Dread.value, max(0.0, Dread.value - 35.0), 6.0)
	for ln in lines:
		hud.message(str(ln), 3.0)
		await get_tree().create_timer(3.0, false).timeout
	voice_playing = false
	return true

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
	if t.has_meta("item"):
		var iid := str(t.get_meta("item"))
		if not on_item_taken(iid, t):
			if not GameState.collectibles.has(iid):
				GameState.collectibles.append(iid)
			if iid.begins_with("voice_"):
				GameState.add_item("voice")
				hud.message("A cassette in Mummy's handwriting: \"for when you're scared\".\n[V] to play it.", 4)
				GameState.save_game()
			else:
				hud.message("Taken: " + str(t.get_meta("prompt", "")).trim_prefix("Take "), 2)
			t.queue_free()
		return
	if t.has_meta("stair_exit"):
		if exit_unlocked:
			complete_floor()
		else:
			hud.message(exit_hint, 3)
		return
	if t.has_meta("use"):
		on_use(str(t.get_meta("use")), t)
		return
	if t.has_meta("hide"):
		var spot: Node3D = t.get_meta("hide_spot") if t.has_meta("hide_spot") else hide_spot()
		if spot:
			player.hide_in(spot)
			on_player_hid(spot)
			hud.message(str(t.get_meta("hide_msg", "You squeeze inside. Hold [Space] to hold your breath.")), 3)
			return
	if on_interact(t):
		return
	if t.has_meta("board"):
		show_rules()

func load_floor_data(n: int) -> void:
	floor_index = n
	var path := "res://data/floor_rules/floor_%02d.json" % n
	if FileAccess.file_exists(path):
		rules = JSON.parse_string(FileAccess.open(path, FileAccess.READ).get_as_text())
		inject_night_rule()
	var npath := "res://data/notes/floor_%02d.json" % n
	if FileAccess.file_exists(npath):
		for nd in JSON.parse_string(FileAccess.open(npath, FileAccess.READ).get_as_text()):
			notes[nd.id] = nd

## Night Shift: every board carries one extra rule that is a lie.
## The phone camera shows it struck through in red.
func inject_night_rule() -> void:
	if not GameState.night() or not rules.has("night_rule"):
		return
	for r in rules.rules:
		if r.get("night", false):
			return
	rules.rules.append({"id": "night", "text": str(rules.night_rule), "class": "false", "night": true})

func show_rules(extra := "") -> void:
	if GameState.night() and player and player.phone_up:
		for r in rules.get("rules", []):
			if r.get("night", false):
				extra += "\n\n(Through the camera, one line is struck through in red:  \"%s\")" % str(r.text)
	var s := "RULES OF THE BUILDING\nREAD CAREFULLY.  THE BUILDING IS LISTENING.\n"
	for r in rules.get("rules", []):
		s += "\n•  " + str(r.text)
	s += extra + "\n\n[E] close"
	hud.show_panel(s)

## Standard arrival: fade in, title card, checkpoint.
func begin_floor() -> void:
	player.teleport(spawn)
	player.rotation.y = spawn_yaw
	if not GameState.checkpoint.is_empty():
		apply_checkpoint(GameState.checkpoint)
	GameState.floor_num = floor_index
	GameState.save_game()
	hud.fade_to(0.0, 1.5)
	var title := "FLOOR %s — %s" % [GameState.floor_label(floor_index), GameState.floor_name(floor_index)]
	if GameState.altered_level(floor_index) > 0:
		title += "\nIt is not the way you left it."
	hud.message(title, 5)

func unlock_exit(msg := "Somewhere, a heavy lock turns.") -> void:
	if exit_unlocked:
		return
	exit_unlocked = true
	hud.message(msg, 3)

## Climb: stairwell interlude, then the next floor.
func complete_floor() -> void:
	if busy:
		return
	busy = true
	finished = true
	player.input_enabled = false
	GameState.stair_from = floor_index
	GameState.solved[floor_index] = true
	GameState.floor_num = floor_index + 1
	GameState.checkpoint = {}
	GameState.carry = ""
	GameState.save_game()
	await hud.fade_to(1.0, 1.2)
	GameState.go(GameState.STAIRWELL)

## Failure on floors 1–4: the building sends you down a floor, which has changed.
func fall_down(reason: String) -> void:
	if busy:
		return
	if GameState.is_lethal(floor_index):
		die(reason)
		return
	busy = true
	player.input_enabled = false
	_sfx.sting.play()
	hud.glitch(1.6)
	await hud.fade_to(1.0, 0.25)
	hud.message(reason + "\nThe floor gives way beneath you.", 4)
	GameState.falls += 1
	Dread.reset(40.0)
	var below: int = max(0, floor_index - 1)
	GameState.altered[below] = GameState.altered_level(below) + 1
	GameState.floor_num = below
	GameState.checkpoint = {}
	GameState.carry = ""
	GameState.save_game()
	await get_tree().create_timer(2.2, false).timeout
	GameState.go(GameState.floor_scene())

## Failure on floors 5–8: death; restart from the floor's last checkpoint.
func die(reason: String) -> void:
	if busy:
		return
	busy = true
	player.input_enabled = false
	_sfx.sting.play()
	hud.glitch(2.0)
	await hud.fade_to(1.0, 0.2)
	hud.message(reason + "\n\nYOU DIED", 4)
	GameState.deaths += 1
	Dread.reset(30.0)
	GameState.save_game()
	await get_tree().create_timer(2.5, false).timeout
	GameState.go(GameState.floor_scene())

## Default chalk mark / diya for floors that build into themselves.
func add_chalk(pos: Vector3, normal: Vector3) -> Label3D:
	var l := Label3D.new()
	l.text = "X"; l.font_size = 64; l.pixel_size = 0.004
	l.modulate = Color(0.95, 0.95, 0.92); l.shaded = true
	add_child(l)
	l.global_position = pos + normal * 0.02
	if abs(normal.y) < 0.9:
		l.look_at(l.global_position - normal, Vector3.UP)
		l.rotate_object_local(Vector3.UP, PI)
	else:
		l.rotation.x = -PI / 2
	return l

func add_diya(pos: Vector3) -> Node3D:
	var n := Node3D.new()
	add_child(n)
	n.global_position = Vector3(pos.x, pos.y - 0.05 if pos.y > 0.5 else 0.0, pos.z)
	n.global_position.y = player.global_position.y
	var cm := CylinderMesh.new(); cm.top_radius = 0.08; cm.bottom_radius = 0.05; cm.height = 0.05
	var cup := MeshInstance3D.new(); cup.mesh = cm; cup.position.y = 0.025
	var cmat := StandardMaterial3D.new(); cmat.albedo_color = Color(0.55, 0.26, 0.12); cup.material_override = cmat
	n.add_child(cup)
	var flame := MeshInstance3D.new(); var fm := SphereMesh.new(); fm.radius = 0.015; fm.height = 0.05
	flame.mesh = fm; flame.position.y = 0.08
	var fmat := StandardMaterial3D.new(); fmat.emission_enabled = true; fmat.emission = Color(1, 0.55, 0.15)
	fmat.emission_energy_multiplier = 6.0; fmat.albedo_color = Color(1, 0.55, 0.15); flame.material_override = fmat
	n.add_child(flame)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.58, 0.22); l.light_energy = 1.8; l.omni_range = 3.2
	l.light_volumetric_fog_energy = 1.5; l.position.y = 0.2
	n.add_child(l)
	var tw := n.create_tween().set_loops()
	tw.tween_property(l, "light_energy", 1.4, 0.18)
	tw.tween_property(l, "light_energy", 2.0, 0.23)
	return n

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
	on_breakdown()      # fall_down()/die() do the counting

func _toggle_inventory() -> void:
	if hud.panel_open():
		hud.hide_panel(); return
	var s := "INVENTORY\n\n"
	s += "Batteries   %d      [R] replace\n" % GameState.count("battery")
	s += "Chalk       %d      [C] mark a surface\n" % GameState.count("chalk")
	s += "Diyas       %d      [G] place — a safe glow for %ds\n" % [GameState.count("diya"), DIYA_SECONDS]
	s += "Old phone           [Q] camera — sees what eyes cannot\n"
	if GameState.count("voice") > 0:
		s += "Voice notes %d      [V] play — Mummy's voice calms you\n" % GameState.count("voice")
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
