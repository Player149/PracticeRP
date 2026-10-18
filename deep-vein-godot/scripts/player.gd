extends CharacterBody3D

var camera: Camera3D
var lamp: SpotLight3D
var joystick
var look_finger: int = -1
var sensitivity: float = 0.0028
var speed: float = 5.7
var jump_velocity: float = 6.0
var touch_jump: bool = false

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.39
	capsule.height = 1.68
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	add_child(collision)
	camera = Camera3D.new()
	camera.position.y = 0.58
	camera.current = true
	camera.fov = 78.0
	add_child(camera)
	lamp = SpotLight3D.new()
	lamp.light_color = Color(0.78, 0.90, 1.0)
	lamp.light_energy = 3.6
	lamp.spot_range = 21.0
	lamp.spot_angle = 58.0
	lamp.shadow_enabled = false
	camera.add_child(lamp)
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(event.relative)
	elif event is InputEventScreenTouch:
		var screen := get_viewport().get_visible_rect().size
		if event.pressed and look_finger == -1 and event.position.x > screen.x * 0.43 and event.position.y < screen.y * 0.70:
			look_finger = event.index
		elif not event.pressed and look_finger == event.index:
			look_finger = -1
	elif event is InputEventScreenDrag and event.index == look_finger:
		_look(event.screen_relative * 0.95)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _look(delta_mouse: Vector2) -> void:
	rotation.y -= delta_mouse.x * sensitivity
	camera.rotation.x = clampf(camera.rotation.x - delta_mouse.y * sensitivity, -1.45, 1.45)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 21.0 * delta
	elif (Input.is_key_pressed(KEY_SPACE) or touch_jump):
		velocity.y = jump_velocity
		touch_jump = false
	var move := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move.y += 1.0
	if joystick != null:
		move += joystick.value
	move = move.limit_length(1.0)
	var direction: Vector3 = (global_transform.basis * Vector3(move.x, 0.0, move.y)).normalized()
	velocity.x = move_toward(velocity.x, direction.x * speed, delta * 19.0)
	velocity.z = move_toward(velocity.z, direction.z * speed, delta * 19.0)
	move_and_slide()
	# Keep players inside the generated finite test volume.
	position.x = clampf(position.x, -17.7, 17.7)
	position.z = clampf(position.z, -17.7, 17.7)
	if position.y < -13.1:
		position = Vector3(0, -7.5, 0)
		velocity = Vector3.ZERO

func eye() -> Vector3:
	return camera.global_position

func sight() -> Vector3:
	return -camera.global_transform.basis.z
