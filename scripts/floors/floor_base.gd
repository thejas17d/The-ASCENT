class_name FloorBase
extends Node3D
## Shared floor plumbing: player, HUD, Dread, Event Director, resources
## (battery / chalk / diya / phone), hiding, pickups, inventory, audio.
## A floor extends this, builds its level, and overrides the hooks:
##   world_root() -> Node3D      where marks/diyas/pickups are parented
##   floor_lights() -> Array     lights the director may flicker
##   hide_spot() -> Node3D
##   on_interact(target) -> bool return true if handled
##   on_breakdown()
##   perform_floor_event(id) -> bool   floor-specific events

const Player := preload("res://scripts/player/player.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const Sfx := preload("res://scripts/systems/sfx.gd")
const Director := preload("res://scripts/systems/event_director.gd")
const DIYA_SECONDS := 40.0
const DIYA_RADIUS := 3.0

var player: CharacterBody3D
var hud: CanvasLayer
var director: Node
var busy := false
var finished := false
var diyas: Array = []       # [{node, t}]
var chalk_marks: Array = []
var _sfx := {}

func setup_common() -> void:
	_setup_env()
	player = Player.new(); add_child(player)
	player.interacted.connect(_on_interact)
	player.chalk_requested.connect(_on_chalk)
	player.diya_requested.connect(_on_diya)
	player.gasped.connect(_on_gasp)
	player.reloaded.connect(func(ok): hud.message("Battery replaced." if ok else "No spare batteries.", 2))
	hud = Hud.new(); add_child(hud)
	director = Director.new(); director.floor = self; add_child(director)
	Dread.breakdown.connect(_on_breakdown)
	var spatial := {"knock": Sfx.knock(), "footsteps": Sfx.footsteps(), "slam": Sfx.slam(),
		"whisper": Sfx.whisper(), "ring": Sfx.ring()}
	for k in spatial:
		var p := AudioStreamPlayer3D.new(); p.stream = spatial[k]; p.unit_size = 6
		add_child(p); _sfx[k] = p
	var flat := {"sting": Sfx.sting(), "gasp": Sfx.gasp()}
	for k in flat:
		var p := AudioStreamPlayer.new(); p.stream = flat[k]
		add_child(p); _sfx[k] = p
	var hum := AudioStreamPlayer.new(); hum.stream = Sfx.hum(); hum.volume_db = -8; hum.autoplay = true
	add_child(hum)

func play_at(id: String, pos: Vector3) -> void:
	var p: Node = _sfx[id]
	if p is AudioStreamPlayer3D:
		p.global_position = pos
	p.play()

func _setup_env() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.23, 0.2)
	env.ambient_light_energy = 0.25
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.045, 0.04)
	env.fog_density = 0.045
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new(); we.environment = env
	add_child(we)

# ---------------------------------------------------------------- hooks
func world_root() -> Node3D: return self
func floor_lights() -> Array: return []
func hide_spot() -> Node3D: return null
func on_interact(_t: Object) -> bool: return false
func on_breakdown() -> void: pass
func perform_floor_event(_id: String) -> bool: return false

# ---------------------------------------------------------------- per frame
func _process(d: float) -> void:
	if finished:
		return
	hud.set_prompt(player.prompt())
	hud.set_phone(player.phone_up)
	hud.set_breath(player.breath, player.hiding)
	hud.set_status("Torch %d%%  ·  Batteries %d  ·  Chalk %d  ·  Diyas %d" % [
		int(player.battery), GameState.count("battery"), GameState.count("chalk"), GameState.count("diya")])
	if Input.is_action_just_pressed("inventory"):
		_toggle_inventory()
	# diyas burn down
	for dy in diyas.duplicate():
		dy.t -= d
		if dy.t <= 0.0:
			dy.node.queue_free(); diyas.erase(dy)
	if not busy:
		Dread.tick(d, not player.light_on(), in_safe_zone(), player.hiding)
	player.shake = Dread.value / 100.0
	hud.set_dread(Dread.value)

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
	if t == null:
		return
	if t.has_meta("pickup"):
		var kind: String = t.get_meta("pickup")
		GameState.add_item(kind, 3 if kind == "chalk" else 1)
		hud.message("Picked up " + kind + ".", 2)
		t.queue_free()
		return
	if t.has_meta("hide") and hide_spot():
		player.hide_in(hide_spot())
		hud.message("You squeeze into the cupboard.", 2)
		return
	on_interact(t)

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
	play_at("gasp", player.global_position)
	Dread.add(5)
	hud.message("You gasp for air.", 2)

func _on_breakdown() -> void:
	_sfx.sting.play()
	GameState.falls += 1
	on_breakdown()

func _toggle_inventory() -> void:
	if hud.panel_open():
		hud.hide_panel(); return
	var s := "INVENTORY\n\n"
	s += "Batteries   %d     [R] replace\n" % GameState.count("battery")
	s += "Chalk       %d     [C] mark a surface\n" % GameState.count("chalk")
	s += "Diyas       %d     [G] place — a safe glow for %ds\n" % [GameState.count("diya"), DIYA_SECONDS]
	s += "Old phone          [Q] camera — sees what eyes cannot\n"
	s += "\nCollected: %d\nTimes the building sent you down: %d\n\n[Tab] close" % [GameState.collectibles.size(), GameState.falls]
	hud.show_panel(s)

# ---------------------------------------------------------------- events
## Called by the Event Director. Generic events here, floor-specific via hook.
func perform_event(id: String) -> bool:
	var fwd := -player.global_transform.basis.z
	match id:
		"flicker":
			var ls := floor_lights().filter(func(l): return is_instance_valid(l) and l.global_position.distance_to(player.global_position) < 14.0)
			if ls.is_empty():
				return false
			_flicker(ls[randi() % ls.size()])
			return true
		"footsteps":
			play_at("footsteps", player.global_position - fwd * 5.0)
			return true
		"door_slam":
			play_at("slam", player.global_position + fwd * 12.0)
			return true
		"phone_ring":
			play_at("ring", player.global_position + fwd * 15.0)
			return true
		"whisper":
			play_at("whisper", player.global_position + player.global_transform.basis.x * (1.0 if randf() < 0.5 else -1.0))
			if GameState.settings.get("subtitles", true):
				hud.message("(whispering, close)", 2)
			return true
		"fake_chalk":
			if not world_root().has_method("add_chalk"):
				return false
			# the building imitates your marks, then they are gone
			var m: Node3D = world_root().add_chalk(player.global_position + fwd * 3.0 + Vector3(0, 1.2, 0) + player.global_transform.basis.x * 1.45, -player.global_transform.basis.x)
			get_tree().create_timer(1.2).timeout.connect(func(): if is_instance_valid(m): m.queue_free())
			return true
	return perform_floor_event(id)

func _flicker(l: Light3D) -> void:
	var base := l.light_energy
	var tw := create_tween()
	for i in 6:
		tw.tween_property(l, "light_energy", 0.0, 0.05)
		tw.tween_property(l, "light_energy", base, 0.08)
