extends CharacterBody3D
## First-person controller: movement, flashlight + battery, phone camera,
## hiding + hold breath, and requests for chalk/diya placement.
signal interacted(target: Object)
signal chalk_requested(pos: Vector3, normal: Vector3)
signal diya_requested(pos: Vector3)
signal gasped
signal reloaded(ok: bool)

const WALK := 2.6
const RUN := 5.2
const SENS := 0.0025
const BATTERY_DRAIN := 0.7      # % per second  (~2.4 min per battery)
const BREATH_DRAIN := 22.0      # % per second while holding
const BREATH_REGEN := 14.0
const CAMERA_ONLY_LAYER := 2    # render layer bit value seen only through the phone

var cam: Camera3D
var ray: RayCast3D
var light: SpotLight3D
var is_running := false
var shake := 0.0
var input_enabled := true
var battery := 100.0
var phone_up := false
var hiding := false
var holding_breath := false
var breath := 100.0
var noise := 0.0                # 0 silent .. 1 loud, for the Supervisor later
var _pitch := 0.0
var _bob := 0.0
var _pre_hide: Transform3D
var _flicker := 0.0

func _ready() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new(); cap.radius = 0.3; cap.height = 1.7
	col.shape = cap; col.position.y = 0.85
	add_child(col)
	cam = Camera3D.new(); cam.position.y = 1.55; cam.fov = 72
	cam.cull_mask = 0xFFFFF & ~CAMERA_ONLY_LAYER
	add_child(cam); cam.make_current()
	light = SpotLight3D.new()
	light.spot_range = 14; light.spot_angle = 26; light.light_energy = 3.0
	light.light_color = Color(1, 0.95, 0.85); light.shadow_enabled = true
	cam.add_child(light)
	ray = RayCast3D.new(); ray.target_position = Vector3(0, 0, -2.4)
	ray.add_exception(self)
	cam.add_child(ray)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func light_on() -> bool:
	return light.visible and battery > 0.0

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif e.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not input_enabled:
		return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var s: float = SENS * GameState.settings.get("sensitivity", 1.0)
		rotate_y(-e.relative.x * s)
		_pitch = clamp(_pitch - e.relative.y * s, -1.3, 1.3)
		cam.rotation.x = _pitch
	elif e.is_action_pressed("flashlight"):
		light.visible = not light.visible
	elif e.is_action_pressed("reload"):
		reload()
	elif e.is_action_pressed("phone"):
		set_phone(not phone_up)
	elif e.is_action_pressed("interact") and (hiding or ray.is_colliding()):
		interacted.emit(null if hiding else ray.get_collider())
	elif e.is_action_pressed("chalk") and ray.is_colliding() and not hiding:
		chalk_requested.emit(ray.get_collision_point(), ray.get_collision_normal())
	elif e.is_action_pressed("diya") and not hiding:
		diya_requested.emit(global_position + (-global_transform.basis.z * 0.8))

func reload() -> bool:
	var ok := battery < 100.0 and GameState.use_item("battery")
	if ok:
		battery = 100.0
	reloaded.emit(ok)
	return ok

func set_phone(on: bool) -> void:
	phone_up = on
	if on:
		cam.cull_mask |= CAMERA_ONLY_LAYER
	else:
		cam.cull_mask &= ~CAMERA_ONLY_LAYER

func hide_in(spot: Node3D) -> void:
	_pre_hide = global_transform
	hiding = true
	global_position = spot.global_position
	rotation.y = spot.global_rotation.y
	velocity = Vector3.ZERO

func leave_hiding() -> void:
	hiding = false
	holding_breath = false
	global_transform = _pre_hide

func _physics_process(d: float) -> void:
	# battery
	if light.visible and battery > 0.0:
		battery = max(0.0, battery - BATTERY_DRAIN * d)
	# low battery / dread flicker
	_flicker -= d
	if _flicker <= 0.0:
		_flicker = randf_range(0.05, 0.4)
		var unstable := battery < 15.0 or shake > 0.7
		light.light_energy = 0.0 if battery <= 0.0 else (randf_range(0.6, 3.0) if unstable and randf() < 0.35 else 3.0)
	# breath
	holding_breath = hiding and input_enabled and Input.is_action_pressed("breath") and breath > 0.0
	if holding_breath:
		breath = max(0.0, breath - BREATH_DRAIN * d)
		if breath <= 0.0:
			holding_breath = false
			gasped.emit()
	else:
		breath = min(100.0, breath + BREATH_REGEN * d)
	if hiding:
		noise = 0.0 if holding_breath else 0.1
		velocity = Vector3.ZERO
		return
	if not is_on_floor():
		velocity.y -= 9.8 * d
	var v := Vector2.ZERO
	if input_enabled:
		v = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	is_running = input_enabled and Input.is_action_pressed("run") and v.length() > 0.1
	var dir := (transform.basis * Vector3(v.x, 0, v.y)).normalized()
	var sp := RUN if is_running else WALK
	velocity.x = dir.x * sp
	velocity.z = dir.z * sp
	move_and_slide()
	noise = 1.0 if is_running else (0.3 if v.length() > 0.1 else 0.05)
	if v.length() > 0.1:
		_bob += d * (11.0 if is_running else 7.0)
	cam.position.y = 1.55 + sin(_bob) * 0.035
	cam.h_offset = randf_range(-1, 1) * shake * 0.012
	cam.v_offset = randf_range(-1, 1) * shake * 0.012
	light.rotation.z = randf_range(-1, 1) * shake * 0.03

func prompt() -> String:
	if hiding:
		return "[E] Leave  ·  hold [Space] hold breath"
	if ray.is_colliding():
		var c := ray.get_collider()
		if c and c.has_meta("prompt"):
			return "[E] " + str(c.get_meta("prompt"))
	return ""

func teleport(p: Vector3) -> void:
	if hiding:
		leave_hiding()
	global_position = p
	rotation.y = 0.0
	velocity = Vector3.ZERO
