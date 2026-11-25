extends CharacterBody3D
## First-person controller: walk/run, mouse look, flashlight, interact ray.
signal interacted(target: Object)

const WALK := 2.6
const RUN := 5.2
const SENS := 0.0025

var cam: Camera3D
var ray: RayCast3D
var light: SpotLight3D
var is_running := false
var shake := 0.0          # 0..1, driven by Dread
var input_enabled := true
var _pitch := 0.0
var _bob := 0.0

func _ready() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new(); cap.radius = 0.3; cap.height = 1.7
	col.shape = cap; col.position.y = 0.85
	add_child(col)
	cam = Camera3D.new(); cam.position.y = 1.55; cam.fov = 72
	add_child(cam); cam.make_current()
	light = SpotLight3D.new()
	light.spot_range = 14; light.spot_angle = 26; light.light_energy = 3.0
	light.light_color = Color(1, 0.95, 0.85); light.shadow_enabled = true
	cam.add_child(light)
	ray = RayCast3D.new(); ray.target_position = Vector3(0, 0, -2.4)
	ray.add_exception(self)
	cam.add_child(ray)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(e: InputEvent) -> void:
	if not input_enabled:
		return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-e.relative.x * SENS)
		_pitch = clamp(_pitch - e.relative.y * SENS, -1.3, 1.3)
		cam.rotation.x = _pitch
	elif e is InputEventMouseButton and e.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif e.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif e.is_action_pressed("flashlight"):
		light.visible = not light.visible
	elif e.is_action_pressed("interact") and ray.is_colliding():
		interacted.emit(ray.get_collider())

func _physics_process(d: float) -> void:
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
	# head bob + dread tremor
	if v.length() > 0.1:
		_bob += d * (11.0 if is_running else 7.0)
	cam.position.y = 1.55 + sin(_bob) * 0.035
	cam.h_offset = randf_range(-1, 1) * shake * 0.012
	cam.v_offset = randf_range(-1, 1) * shake * 0.012
	light.rotation.z = randf_range(-1, 1) * shake * 0.03

func prompt() -> String:
	if ray.is_colliding():
		var c := ray.get_collider()
		if c and c.has_meta("prompt"):
			return "[E] " + str(c.get_meta("prompt"))
	return ""

func teleport(p: Vector3) -> void:
	global_position = p
	rotation.y = 0.0
	velocity = Vector3.ZERO
