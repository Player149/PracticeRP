extends CharacterBody3D
## FPS controls with mining raycast and a projected surface outline.

const MOVE_SPEED: float = 6.0
const JUMP_SPEED: float = 6.5
const GRAVITY: float = 21.0
const ACCELERATION: float = 20.0
const MOUSE_SENSITIVITY: float = 0.0024
const TOUCH_SENSITIVITY: float = 0.0030
const STICK_RADIUS: float = 85.0
const START_POSITION: Vector3 = Vector3(0.0, 0.1, 6.0)
const REACH: float = 6.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var terrain: Node3D = $"../Ground"
@onready var touch_ui: Control = $"../CanvasLayer/TouchUI"
@onready var instructions: Label = $"../CanvasLayer/Instructions"
@onready var dig_status: Label = $"../CanvasLayer/DigStatus"
@onready var reticle: Label = $"../CanvasLayer/Reticle"

var touch_enabled: bool = false
var move_finger: int = -1
var look_finger: int = -1
var stick_start: Vector2 = Vector2.ZERO
var stick_axis: Vector2 = Vector2.ZERO
var jump_queued: bool = false
var dig_count: int = 0
var dig_queued: bool = false
var preview_mesh: ImmediateMesh
var preview_instance: MeshInstance3D
var preview_timer: float = 0.0
const PREVIEW_SEGMENTS: int = 32
const PREVIEW_INTERVAL: float = 0.12

func _ready() -> void:
    touch_enabled = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
    touch_ui.visible = touch_enabled
    touch_ui.connect("jump_requested", Callable(self, "_on_touch_jump"))
    touch_ui.connect("dig_requested", Callable(self, "_request_dig"))
    if touch_enabled:
        instructions.text = "DIG - 3D VOXEL TEST   |   Left: move  |  Right: look"
        instructions.add_theme_font_size_override("font_size", 19)
    else:
        instructions.text = "DIG - 3D VOXEL TEST\nWASD: move  |  Mouse: look  |  Space: jump\nClick / E: dig  |  R: reset player  |  Esc: cursor"
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    dig_status.text = "Aim at rock (6m) and press DIG"
    _create_preview()
    head.rotation.x = -0.38  # Initial downward aim: rock is in range at spawn.

func _input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        var motion: InputEventMouseMotion = event as InputEventMouseMotion
        if not touch_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
            _look(motion.relative, MOUSE_SENSITIVITY)
    elif event is InputEventMouseButton:
        var click: InputEventMouseButton = event as InputEventMouseButton
        if not touch_enabled and click.button_index == MOUSE_BUTTON_LEFT and click.pressed:
            if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
                _request_dig()
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
                _request_dig()
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
    if dig_queued:
        dig_queued = false
        _dig()
    _update_preview(delta)

func _request_dig() -> void:
    dig_queued = true

func _dig() -> void:
    var hit: Dictionary = _raycast_terrain()
    if hit.is_empty():
        dig_status.text = "No mineable surface under crosshair (range 6m)"
        return
    var success: bool = bool(terrain.call("dig_at", hit["position"], hit["normal"]))
    if success:
        dig_count += 1
        dig_status.text = "Rock removed  |  Digs: %d" % dig_count
        preview_instance.visible = false
        preview_timer = 0.0
    else:
        dig_status.text = "This part of the world cannot be mined."

func _raycast_terrain() -> Dictionary:
    var start: Vector3 = camera.global_position
    var end: Vector3 = start - camera.global_transform.basis.z * REACH
    var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, end)
    query.collision_mask = 1
    query.exclude = [get_rid()]
    var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():
        return {}
    var object: Object = hit["collider"]
    if not (object is Node):
        return {}
    if not (object as Node).is_in_group("diggable_terrain"):
        return {}
    return hit

func _create_preview() -> void:
    preview_mesh = ImmediateMesh.new()
    preview_instance = MeshInstance3D.new()
    preview_instance.name = "MiningSurfaceOutline"
    preview_instance.mesh = preview_mesh
    preview_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = Color(1.0, 0.86, 0.22)
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    material.no_depth_test = true  # Outline remains visible on irregular voxel slopes.
    material.render_priority = 10
    preview_instance.material_override = material
    preview_instance.visible = false
    get_parent().add_child(preview_instance)

func _update_preview(delta: float) -> void:
    preview_timer -= delta
    if preview_timer > 0.0:
        return
    preview_timer = PREVIEW_INTERVAL
    var hit: Dictionary = _raycast_terrain()
    if hit.is_empty():
        preview_instance.visible = false
        reticle.modulate = Color(1.0, 1.0, 1.0)
        return
    reticle.modulate = Color(1.0, 0.85, 0.2)
    _draw_projected_outline(hit["position"], hit["normal"])

func _draw_projected_outline(point: Vector3, hit_normal: Vector3) -> void:
    var normal: Vector3 = hit_normal.normalized()
    var tangent: Vector3 = normal.cross(Vector3.UP)
    if tangent.length_squared() < 0.01:
        tangent = normal.cross(Vector3.RIGHT)
    tangent = tangent.normalized()
    var bitangent: Vector3 = normal.cross(tangent).normalized()
    var radius: float = float(terrain.call("get_preview_radius"))

    var points: Array[Vector3] = []
    for i in range(PREVIEW_SEGMENTS):
        var angle: float = TAU * float(i) / float(PREVIEW_SEGMENTS)
        var point_on_circle: Vector3 = point + radius * (tangent * cos(angle) + bitangent * sin(angle))
        # A camera-facing outline just above the tangent plane. No additional
        # physics rays per marker vertex (previously 24 expensive queries).
        points.append(point_on_circle + normal * 0.14)

    preview_mesh.clear_surfaces()
    preview_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(PREVIEW_SEGMENTS):
        var p0: Vector3 = points[i]
        var p1: Vector3 = points[(i + 1) % PREVIEW_SEGMENTS]
        var segment: Vector3 = p1 - p0
        if segment.length_squared() < 0.000001:
            continue
        # Tiny camera-facing ribbon is easier to see on mobile than 1px lines.
        var view: Vector3 = camera.global_position - (p0 + p1) * 0.5
        var width_axis: Vector3 = segment.cross(view).normalized()
        if width_axis.length_squared() < 0.001:
            width_axis = normal
        var width: Vector3 = width_axis * 0.045
        preview_mesh.surface_add_vertex(p0 - width)
        preview_mesh.surface_add_vertex(p0 + width)
        preview_mesh.surface_add_vertex(p1 + width)
        preview_mesh.surface_add_vertex(p0 - width)
        preview_mesh.surface_add_vertex(p1 + width)
        preview_mesh.surface_add_vertex(p1 - width)
    preview_mesh.surface_end()
    preview_instance.visible = true

func _on_touch_jump() -> void:
    jump_queued = true

func _reset_player() -> void:
    global_position = START_POSITION
    velocity = Vector3.ZERO
    rotation = Vector3.ZERO
    head.rotation = Vector3(-0.38, 0.0, 0.0)
