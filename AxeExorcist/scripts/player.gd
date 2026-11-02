extends CharacterBody3D

signal stats_changed(hp: float, kills: int, dash: int)
signal strike_feedback(hit_count: int)

const SPEED: float = 8.0
const JUMP_SPEED: float = 7.5
const GRAVITY: float = 23.0
const MOUSE_SENS: float = 0.0023

var hp: float = 100.0
var kills: int = 0
var dash_charges: int = 2
var dash_timer: float = 0.0
var dash_recharge: float = 0.0
var dash_vector: Vector3 = Vector3.ZERO
var attack_timer: float = 0.0
var attack_duration: float = 0.38
var hit_done: bool = false
var combo: int = 0
var queued_attack: bool = false
var heavy_charge: float = 0.0
var charging: bool = false
var kick_cd: float = 0.0
var invulnerability: float = 0.0
var camera: Camera3D
var weapon: Node3D

func _ready() -> void:
    var collider := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.35
    shape.height = 1.8
    collider.shape = shape
    collider.position.y = 0.9
    add_child(collider)
    camera = Camera3D.new()
    camera.position.y = 1.58
    camera.current = true
    camera.fov = 86.0
    add_child(camera)
    _build_axe()
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    stats_changed.emit(hp, kills, dash_charges)

func _make_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
    var mesh_node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_node.mesh = mesh
    mesh_node.position = pos
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mesh_node.material_override = mat
    parent.add_child(mesh_node)

func _build_axe() -> void:
    weapon = Node3D.new()
    weapon.position = Vector3(0.52, -0.45, -0.8)
    camera.add_child(weapon)
    _make_box(weapon, Vector3(0.10, 0.82, 0.12), Vector3(0.0, 0.03, 0.0), Color(0.55, 0.28, 0.12))
    _make_box(weapon, Vector3(0.42, 0.20, 0.14), Vector3(-0.13, 0.47, 0.0), Color(0.70, 0.74, 0.78))
    _make_box(weapon, Vector3(0.18, 0.20, 0.21), Vector3(0.04, -0.28, 0.0), Color(0.38, 0.38, 0.40))

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        rotate_y(-event.relative.x * MOUSE_SENS)
        camera.rotate_x(-event.relative.y * MOUSE_SENS)
        camera.rotation.x = clampf(camera.rotation.x, -1.4, 1.4)
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            charging = true
            heavy_charge = 0.0
        elif charging:
            charging = false
            if heavy_charge >= 0.32:
                _attack(true)
            else:
                _attack(false)
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE:
            Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        elif event.keycode == KEY_F:
            _kick()
        elif event.keycode == KEY_SHIFT:
            _dash()

func _physics_process(delta: float) -> void:
    var move_input := Vector2.ZERO
    if Input.is_key_pressed(KEY_A): move_input.x -= 1.0
    if Input.is_key_pressed(KEY_D): move_input.x += 1.0
    if Input.is_key_pressed(KEY_W): move_input.y -= 1.0
    if Input.is_key_pressed(KEY_S): move_input.y += 1.0
    var direction: Vector3 = (global_transform.basis * Vector3(move_input.x, 0, move_input.y)).normalized()
    if not is_on_floor():
        velocity.y -= GRAVITY * delta
    elif Input.is_key_pressed(KEY_SPACE):
        velocity.y = JUMP_SPEED
    if dash_timer > 0.0:
        dash_timer -= delta
        velocity.x = dash_vector.x * 25.0
        velocity.z = dash_vector.z * 25.0
    else:
        velocity.x = direction.x * SPEED
        velocity.z = direction.z * SPEED
    move_and_slide()
    invulnerability = maxf(0.0, invulnerability - delta)
    dash_recharge -= delta
    if dash_recharge <= 0.0 and dash_charges < 2:
        dash_charges += 1
        dash_recharge = 2.5
        stats_changed.emit(hp, kills, dash_charges)
    kick_cd = maxf(0.0, kick_cd - delta)
    if charging:
        heavy_charge = minf(0.65, heavy_charge + delta)
    if attack_timer > 0.0:
        attack_timer -= delta
        var elapsed: float = attack_duration - attack_timer
        if not hit_done and elapsed >= attack_duration * 0.42:
            hit_done = true
            _damage_cone(56.0 if attack_duration > 0.5 else 28.0, 3.0 if attack_duration > 0.5 else 2.55, 95.0 if attack_duration > 0.5 else 110.0, 13.0)
        if attack_timer <= 0.0 and queued_attack:
            queued_attack = false
            _attack(false)
    var target_angle: float = 0.0
    if attack_timer > 0.0:
        var phase: float = 1.0 - attack_timer / attack_duration
        target_angle = sin(phase * PI) * (1.7 if combo % 2 == 0 else -1.7)
    weapon.rotation.z = lerpf(weapon.rotation.z, target_angle, minf(1.0, delta * 22.0))
    weapon.position.y = lerpf(weapon.position.y, -0.49 + (0.11 if charging else 0.0), delta * 12.0)

func _attack(heavy: bool) -> void:
    if attack_timer > 0.12:
        queued_attack = true
        return
    attack_duration = 0.62 if heavy else 0.38
    attack_timer = attack_duration
    hit_done = false
    combo = (combo + 1) % 3

func _damage_cone(damage: float, radius: float, angle_degrees: float, force: float) -> void:
    var hits: int = 0
    var forward: Vector3 = -global_transform.basis.z
    for enemy in get_tree().get_nodes_in_group("ghosts"):
        if not is_instance_valid(enemy):
            continue
        var delta_pos: Vector3 = enemy.global_position - global_position
        delta_pos.y = 0.0
        if delta_pos.length() > radius or delta_pos.length() < 0.01:
            continue
        if rad_to_deg(acos(clampf(forward.dot(delta_pos.normalized()), -1.0, 1.0))) > angle_degrees * 0.5:
            continue
        # Prevent hitting ghosts through level geometry.
        var query := PhysicsRayQueryParameters3D.create(camera.global_position, enemy.global_position + Vector3.UP)
        query.exclude = [get_rid()]
        var result := get_world_3d().direct_space_state.intersect_ray(query)
        if not result.is_empty() and result.collider != enemy:
            continue
        enemy.receive_hit(damage, delta_pos.normalized(), force)
        hits += 1
    strike_feedback.emit(hits)

func _dash() -> void:
    if dash_charges <= 0:
        return
    dash_charges -= 1
    dash_recharge = maxf(dash_recharge, 2.5)
    var wish: Vector3 = Vector3.ZERO
    if Input.is_key_pressed(KEY_W): wish.z -= 1.0
    if Input.is_key_pressed(KEY_S): wish.z += 1.0
    if Input.is_key_pressed(KEY_A): wish.x -= 1.0
    if Input.is_key_pressed(KEY_D): wish.x += 1.0
    dash_vector = (global_transform.basis * wish).normalized() if wish.length() > 0.01 else -global_transform.basis.z
    dash_timer = 0.20
    invulnerability = 0.23
    stats_changed.emit(hp, kills, dash_charges)

func _kick() -> void:
    if kick_cd > 0.0:
        return
    kick_cd = 0.8
    _damage_cone(12.0, 1.9, 85.0, 22.0)

func take_damage(amount: float) -> void:
    if invulnerability > 0.0 or hp <= 0.0:
        return
    hp = maxf(0.0, hp - amount)
    invulnerability = 0.35
    stats_changed.emit(hp, kills, dash_charges)
    if hp <= 0.0:
        get_tree().reload_current_scene()

func on_kill() -> void:
    kills += 1
    hp = minf(100.0, hp + 8.0)
    stats_changed.emit(hp, kills, dash_charges)
