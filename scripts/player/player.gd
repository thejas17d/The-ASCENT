extends CharacterBody3D
## First-person controller: walk/run/crouch, flashlight + battery, phone
## camera, hiding + hold breath, footsteps, and requests for chalk/diya.
signal interacted(target: Object)        # null = pressed E on nothing
signal chalk_requested(pos: Vector3, normal: Vector3)
signal diya_requested(pos: Vector3)
signal gasped
signal reloaded(ok: bool)
signal footstep(loudness: float)
signal flashlight_toggled(on: bool)

const WALK := 2.6
const RUN := 5.2
const CROUCH := 1.4
const SENS := 0.0025
const EYE := 1.55
const EYE_CROUCH := 1.0
const BATTERY_DRAIN := 0.7      # % per second  (~2.4 min per battery)
const BREATH_DRAIN := 22.0      # % per second while holding
const BREATH_REGEN := 14.0
const CAMERA_ONLY_LAYER := 2    # render layer bit value seen only through the phone

var cam: Camera3D
var ray: RayCast3D
var light: SpotLight3D
var is_running := false
var is_crouching := false
var shake := 0.0
var input_enabled := true
var ui_lock := false            # a keypad/choice dialog is open
var battery := 100.0
var phone_up := false
var hiding := false
var holding_breath := false
var breath := 100.0
var noise := 0.0                # 0 silent .. 1 loud, heard by the Supervisor
var _pitch := 0.0
var _bob := 0.0
var _step_phase := 0
var _eye := EYE
var _breath_lock := false       # after a gasp, Space must be released first
var _hide_eye := EYE
var _burst := 0.0               # temporary loud noise (gasp, knocking things over)
var _burst_t := 0.0
var _pre_hide: Transform3D
var _flicker := 0.0
var _torch_q := Quaternion.IDENTITY
var _torch_init := false
var _torch_wobble := Vector3.ZERO
var touch_mode := false         # touch controls drive look; mouse-motion (emulated from touch) is ignored

func _ready() -> void:
	collision_mask = 1 | 4   # world + the Supervisor (layer 4)
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new(); cap.radius = 0.3; cap.height = 1.7
	col.shape = cap; col.position.y = 0.85
	add_child(col)
	cam = Camera3D.new(); cam.position.y = EYE; cam.fov = 72; cam.near = 0.03
	cam.cull_mask = 0xFFFFF & ~CAMERA_ONLY_LAYER
	add_child(cam); cam.make_current()
	light = SpotLight3D.new()
	light.spot_range = 16; light.spot_angle = 27; light.spot_attenuation = 0.9
	light.spot_angle_attenuation = 1.6
	light.light_energy = 3.2
	light.light_color = Color(0.95, 0.96, 1.0)
	light.light_volumetric_fog_energy = 2.2
	light.shadow_enabled = true; light.shadow_blur = 1.5
	var cookie := preload("res://scripts/systems/mat_lib.gd").fx("torch_cookie")
	light.light_projector = cookie if cookie else _torch_pattern()
	light.position = Vector3(0.18, -0.12, 0)   # held low and to the right
	cam.add_child(light)
	ray = RayCast3D.new(); ray.target_position = Vector3(0, 0, -2.4)
	ray.add_exception(self)
	cam.add_child(ray)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## Hot centre, soft spill and a faint reflector ring, like a real torch.
func _torch_pattern() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1)); g.set_color(1, Color(0, 0, 0))
	g.add_point(0.22, Color(0.95, 0.95, 0.95))
	g.add_point(0.38, Color(0.55, 0.55, 0.55))
	g.add_point(0.5, Color(0.68, 0.68, 0.68))   # reflector ring
	g.add_point(0.62, Color(0.3, 0.3, 0.3))
	g.add_point(0.85, Color(0.08, 0.08, 0.08))
	var t := GradientTexture2D.new()
	t.gradient = g; t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5); t.fill_to = Vector2(1.0, 0.5)
	t.width = 256; t.height = 256
	return t

func light_on() -> bool:
	return light.visible and battery > 0.0

func _unhandled_input(e: InputEvent) -> void:
	if get_tree().paused:
		return
	if e is InputEventMouseButton and e.pressed and not ui_lock:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not _can_act():
		return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not touch_mode:
		var s: float = SENS * GameState.settings.get("sensitivity", 1.0)
		rotate_y(-e.relative.x * s)
		_pitch = clamp(_pitch - e.relative.y * s, -1.3, 1.3)
		cam.rotation.x = _pitch
	elif e.is_action_pressed("flashlight"):
		light.visible = not light.visible
		flashlight_toggled.emit(light.visible)
	elif e.is_action_pressed("reload"):
		reload()
	elif e.is_action_pressed("phone"):
		set_phone(not phone_up)
	elif e.is_action_pressed("interact"):
		# always emit so panels/hiding can be closed while looking at nothing
		interacted.emit(ray.get_collider() if (ray.is_colliding() and not hiding) else null)
	elif e.is_action_pressed("chalk") and ray.is_colliding() and not hiding:
		chalk_requested.emit(ray.get_collision_point(), ray.get_collision_normal())
	elif e.is_action_pressed("diya") and not hiding:
		diya_requested.emit(global_position + (-global_transform.basis.z * 0.8))

func _can_act() -> bool:
	return input_enabled and not ui_lock

## Look by an angle delta (radians): used by touch drag and the gyroscope.
func look_input(rel: Vector2) -> void:
	if not _can_act() or hiding:
		return
	rotate_y(-rel.x)
	_pitch = clamp(_pitch - rel.y, -1.3, 1.3)
	cam.rotation.x = _pitch

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
	is_running = false
	is_crouching = false
	global_position = spot.global_position
	rotation.y = spot.global_rotation.y
	_hide_eye = float(spot.get_meta("eye", EYE))
	velocity = Vector3.ZERO

func noise_burst(level: float, secs: float) -> void:
	_burst = max(_burst, level); _burst_t = max(_burst_t, secs)

func leave_hiding() -> void:
	hiding = false
	holding_breath = false
	global_transform = _pre_hide

func _physics_process(d: float) -> void:
	# battery
	if light.visible and battery > 0.0:
		battery = max(0.0, battery - BATTERY_DRAIN * d)
	# low battery / dread flicker (respects reduced-flashing)
	_flicker -= d
	if _flicker <= 0.0:
		_flicker = randf_range(0.05, 0.4)
		var unstable: bool = (battery < 15.0 or shake > 0.7) and not GameState.settings.get("reduced_flashing", false)
		light.light_energy = 0.0 if battery <= 0.0 else (randf_range(0.8, 3.2) if unstable and randf() < 0.35 else 3.2)
	# breath: after a gasp you must release Space before holding again
	var want_hold := hiding and _can_act() and Input.is_action_pressed("breath")
	if not Input.is_action_pressed("breath"):
		_breath_lock = false
	holding_breath = want_hold and not _breath_lock and breath > 0.0
	if holding_breath:
		breath = max(0.0, breath - BREATH_DRAIN * d)
		if breath <= 0.0:
			holding_breath = false
			_breath_lock = true
			noise_burst(0.9, 0.8)
			gasped.emit()
	else:
		breath = min(100.0, breath + BREATH_REGEN * d)
	_burst_t -= d
	if _burst_t <= 0.0:
		_burst = 0.0
	if hiding:
		is_running = false
		noise = max(0.0 if holding_breath else 0.1, _burst)
		velocity = Vector3.ZERO
		cam.position.y = lerp(cam.position.y, _hide_eye, clamp(d * 10.0, 0.0, 1.0))
		return
	if not is_on_floor():
		velocity.y -= 9.8 * d
	# gyroscope look (values are in screen space on Android; untested on hardware)
	if touch_mode and GameState.settings.get("gyro", false) and _can_act():
		var g := Input.get_gyroscope()
		rotate_y(g.y * d)
		_pitch = clamp(_pitch + g.x * d, -1.3, 1.3)
		cam.rotation.x = _pitch
	var v := Vector2.ZERO
	if _can_act():
		v = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	is_crouching = _can_act() and Input.is_action_pressed("crouch")
	is_running = _can_act() and not is_crouching and Input.is_action_pressed("run") and v.length() > 0.1
	var dir := (transform.basis * Vector3(v.x, 0, v.y)).normalized()
	var sp := RUN if is_running else (CROUCH if is_crouching else WALK)
	velocity.x = dir.x * sp
	velocity.z = dir.z * sp
	move_and_slide()
	var moving := v.length() > 0.1 and get_real_velocity().length() > 0.5
	noise = max(1.0 if is_running else (0.1 if is_crouching else (0.3 if moving else 0.05)), _burst)
	# head bob + footsteps on each trough
	if moving:
		_bob += d * (11.0 if is_running else (5.0 if is_crouching else 7.0))
		var phase := int(floor(_bob / PI))
		if phase != _step_phase:
			_step_phase = phase
			footstep.emit(1.0 if is_running else (0.25 if is_crouching else 0.55))
	_eye = lerp(_eye, EYE_CROUCH if is_crouching else EYE, clamp(d * 8.0, 0.0, 1.0))
	cam.position.y = _eye + sin(_bob) * (0.045 if is_running else 0.03)
	cam.position.x = cos(_bob * 0.5) * 0.02
	cam.h_offset = randf_range(-1, 1) * shake * 0.012
	cam.v_offset = randf_range(-1, 1) * shake * 0.012
	# torch lags slightly behind the view and trembles with dread
	_torch_wobble = Vector3(lerp(_torch_wobble.x, sin(_bob) * 0.015, 0.2), 0.0, randf_range(-1, 1) * shake * 0.03)

## The torch is held, not glued to the eyes: it trails the view slightly when
## you turn (and trembles with dread), which makes the beam feel physical.
func _process(d: float) -> void:
	var target := cam.global_basis.get_rotation_quaternion()
	if _torch_q == Quaternion.IDENTITY and not _torch_init:
		_torch_q = target; _torch_init = true
	_torch_q = _torch_q.slerp(target, 1.0 - exp(-16.0 * d))
	light.global_basis = Basis(_torch_q) * Basis.from_euler(_torch_wobble)

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
