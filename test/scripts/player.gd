extends CharacterBody3D
## First person movement with a single, fixed-depth dig for each button press.

const MOVE_SPEED: float = 6.0
const JUMP_SPEED: float = 6.5
const GRAVITY: float = 21.0
const ACCELERATION: float = 20.0
const MOUSE_SENSITIVITY: float = 0.0024
const TOUCH_SENSITIVITY: float = 0.0030
const STICK_RADIUS: float = 85.0
const START_POSITION: Vector3 = Vector3(0.0, 0.1, 14.0)
const REACH: float = 6.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var terrain: StaticBody3D = $"../Ground"
@onready var touch_ui: Control = $"../CanvasLayer/TouchUI"
@onready var instructions: Label = $"../CanvasLayer/Instructions"
@onready var dig_status: Label = $"../CanvasLayer/DigStatus"

var touch_enabled: bool = false
var move_finger: int = -1
var look_finger: int = -1
var stick_start: Vector2 = Vector2.ZERO
var stick_axis: Vector2 = Vector2.ZERO
var jump_queued: bool = false
var dig_count: int = 0

func _ready() -> void:
    touch_enabled = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
    touch_ui.visible = touch_enabled
    touch_ui.connect("jump_requested", Callable(self, "_on_touch_jump"))
    touch_ui.connect("dig_requested", Callable(self, "_dig"))
    if touch_enabled:
        instructions.text = "DIG - TERRAIN TEST   |   Left: move  |  Right: look"
        instructions.add_theme_font_size_override("font_size", 19)
    else:
        instructions.text = "DIG - TERRAIN TEST\nWASD: move  |  Mouse: look  |  Space: jump\nClick / E: dig  |  R: reset player  |  Esc: cursor"
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    dig_status.text = "DIG = -0.7m at center (each press)  |  Total: 0"

func _input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        var motion: InputEventMouseMotion = event as InputEventMouseMotion
        if not touch_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
            _look(motion.relative, MOUSE_SENSITIVITY)
    elif event is InputEventMouseButton:
        var click: InputEventMouseButton = event as InputEventMouseButton
        if not touch_enabled and click.button_index == MOUSE_BUTTON_LEFT and click.pressed:
            if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
                _dig()
            else:
                Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    elif event is InputEventKey:
        var key: InputEventKey = event as InputEventKey
        if key.pressed and not key.echo:
            if key.keycode == KEY_ESCAPE:
                if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
                    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
                else:
                    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
            elif key.keycode == KEY_R:
                _reset_player()
            elif key.keycode == KEY_E:
                _dig()
    elif event is InputEventScreenTouch:
        if touch_enabled:
            _handle_touch(event as InputEventScreenTouch)
    elif event is InputEventScreenDrag:
        if touch_enabled:
            _handle_drag(event as InputEventScreenDrag)

func _handle_touch(event: InputEventScreenTouch) -> void:
    var screen: Vector2 = get_viewport().get_visible_rect().size
    if event.pressed:
        if event.position.x < screen.x * 0.43 and event.position.y > screen.y * 0.28 and move_finger == -1:
            move_finger = event.index
            stick_start = event.position
            stick_axis = Vector2.ZERO
            touch_ui.call("set_stick", stick_start, stick_axis, true)
        elif event.position.x >= screen.x * 0.43 and event.position.y < screen.y * 0.60 and look_finger == -1:
            look_finger = event.index
    else:
        if event.index == move_finger:
            move_finger = -1
            stick_axis = Vector2.ZERO
            touch_ui.call("set_stick", stick_start, stick_axis, false)
        if event.index == look_finger:
            look_finger = -1

func _handle_drag(event: InputEventScreenDrag) -> void:
    if event.index == move_finger:
        stick_axis = ((event.position - stick_start) / STICK_RADIUS).limit_length(1.0)
        touch_ui.call("set_stick", stick_start, stick_axis, true)
    elif event.index == look_finger:
        _look(event.screen_relative, TOUCH_SENSITIVITY)

func _look(delta: Vector2, sensitivity: float) -> void:
    rotation.y -= delta.x * sensitivity
    head.rotation.x = clampf(head.rotation.x - delta.y * sensitivity, deg_to_rad(-85.0), deg_to_rad(85.0))

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= GRAVITY * delta
    elif Input.is_key_pressed(KEY_SPACE) or jump_queued:
        velocity.y = JUMP_SPEED
    jump_queued = false

    var axis: Vector2 = Vector2.ZERO
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
        axis.x -= 1.0
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
        axis.x += 1.0
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
        axis.y -= 1.0
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
        axis.y += 1.0
    if move_finger >= 0:
        axis += stick_axis
    axis = axis.limit_length(1.0)

    var move_direction: Vector3 = (basis * Vector3(axis.x, 0.0, axis.y)).normalized()
    velocity.x = move_toward(velocity.x, move_direction.x * MOVE_SPEED, ACCELERATION * delta)
    velocity.z = move_toward(velocity.z, move_direction.z * MOVE_SPEED, ACCELERATION * delta)
    move_and_slide()
    if global_position.y < -9.0:
        _reset_player()

func _dig() -> void:
    var ray_start: Vector3 = camera.global_position
    var ray_end: Vector3 = ray_start - camera.global_transform.basis.z * REACH
    var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
    query.collision_mask = 1
    query.exclude = [get_rid()]
    var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
    var target: Vector3
    if not hit.is_empty() and hit["collider"] == terrain:
        target = hit["position"]
    else:
        # Fallback for a level camera: dig ground a short distance ahead.
        var forward: Vector3 = -global_transform.basis.z
        var spot: Vector3 = global_position + forward * 2.6
        var top: Vector3 = spot + Vector3.UP * 4.0
        var down_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(top, top + Vector3.DOWN * 18.0)
        down_query.collision_mask = 1
        down_query.exclude = [get_rid()]
        var down_hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(down_query)
        if down_hit.is_empty() or down_hit["collider"] != terrain:
            dig_status.text = "Move to open ground to dig."
            return
        target = down_hit["position"]
    if bool(terrain.call("dig_at", target)):
        dig_count += 1
        dig_status.text = "DUG!   -0.7m center / press   |   Total digs: %d" % dig_count
    else:
        dig_status.text = "Soil is already at maximum depth."

func _on_touch_jump() -> void:
    jump_queued = true

func _reset_player() -> void:
    global_position = START_POSITION
    velocity = Vector3.ZERO
    rotation = Vector3.ZERO
    head.rotation = Vector3.ZERO
