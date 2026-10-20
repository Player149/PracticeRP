extends CharacterBody3D
## First-person controller: WASD / mouse / jump / sprint and multi-touch Android input.

const WALK_SPEED: float = 6.0
const RUN_SPEED: float = 10.0
const JUMP_SPEED: float = 6.5
const GRAVITY: float = 21.0
const ACCELERATION: float = 20.0
const MOUSE_SENSITIVITY: float = 0.0024
const TOUCH_SENSITIVITY: float = 0.0030
const STICK_RADIUS: float = 85.0
const START_POSITION: Vector3 = Vector3(0.0, 0.1, 14.0)

@onready var head: Node3D = $Head
@onready var touch_ui: Control = $"../CanvasLayer/TouchUI"
@onready var instructions: Label = $"../CanvasLayer/Instructions"

var touch_enabled: bool = false
var move_finger: int = -1
var look_finger: int = -1
var stick_start: Vector2 = Vector2.ZERO
var stick_axis: Vector2 = Vector2.ZERO
var touch_running: bool = false
var jump_queued: bool = false

func _ready() -> void:
    touch_enabled = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
    touch_ui.visible = touch_enabled
    touch_ui.connect("jump_requested", Callable(self, "_on_touch_jump"))
    touch_ui.connect("run_changed", Callable(self, "_on_touch_run"))
    if touch_enabled:
        instructions.text = "DIG - FPS TEST  |  Left: move   Right: look   JUMP / RUN"
        instructions.add_theme_font_size_override("font_size", 19)
    else:
        instructions.text = "DIG - FPS TEST\nWASD / Arrows: move  |  Mouse: look  |  Space: jump\nShift: run  |  R: reset  |  Esc: free cursor"
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        var motion: InputEventMouseMotion = event as InputEventMouseMotion
        if not touch_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
            _look(motion.relative, MOUSE_SENSITIVITY)
    elif event is InputEventMouseButton:
        var click: InputEventMouseButton = event as InputEventMouseButton
        if not touch_enabled and click.button_index == MOUSE_BUTTON_LEFT and click.pressed:
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
        elif event.position.x >= screen.x * 0.43 and event.position.y < screen.y * 0.70 and look_finger == -1:
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
    var speed: float = RUN_SPEED if Input.is_key_pressed(KEY_SHIFT) or touch_running else WALK_SPEED
    velocity.x = move_toward(velocity.x, move_direction.x * speed, ACCELERATION * delta)
    velocity.z = move_toward(velocity.z, move_direction.z * speed, ACCELERATION * delta)
    move_and_slide()

    if global_position.y < -8.0:
        _reset_player()

func _on_touch_jump() -> void:
    jump_queued = true

func _on_touch_run(is_running: bool) -> void:
    touch_running = is_running

func _reset_player() -> void:
    global_position = START_POSITION
    velocity = Vector3.ZERO
    rotation = Vector3.ZERO
    head.rotation = Vector3.ZERO
