extends CharacterBody3D

var player: CharacterBody3D
var hp: float = 75.0
var stagger: float = 0.0
var stagger_time: float = 0.0
var attack_cd: float = 0.8
var knockback: Vector3 = Vector3.ZERO
var alive: bool = true
var body_mesh: MeshInstance3D
var initial_pos: Vector3

func _ready() -> void:
    add_to_group("ghosts")
    initial_pos = global_position
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.45
    capsule.height = 1.8
    var collider := CollisionShape3D.new()
    collider.shape = capsule
    collider.position.y = 0.9
    add_child(collider)
    body_mesh = MeshInstance3D.new()
    var mesh := CapsuleMesh.new()
    mesh.radius = 0.44
    mesh.height = 1.8
    body_mesh.mesh = mesh
    body_mesh.position.y = 0.9
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.55, 0.83, 0.76, 1.0)
    material.emission_enabled = true
    material.emission = Color(0.08, 0.26, 0.21)
    material.emission_energy_multiplier = 1.25
    body_mesh.material_override = material
    add_child(body_mesh)

func _physics_process(delta: float) -> void:
    if not alive or not is_instance_valid(player):
        return
    attack_cd = maxf(0.0, attack_cd - delta)
    stagger_time = maxf(0.0, stagger_time - delta)
    var diff: Vector3 = player.global_position - global_position
    diff.y = 0.0
    var distance: float = diff.length()
    if stagger_time > 0.0:
        velocity.x = knockback.x
        velocity.z = knockback.z
        knockback = knockback.move_toward(Vector3.ZERO, delta * 18.0)
    elif distance > 1.55:
        var direction: Vector3 = diff.normalized()
        velocity.x = direction.x * 3.5
        velocity.z = direction.z * 3.5
    else:
        velocity.x = 0.0
        velocity.z = 0.0
        if attack_cd <= 0.0:
            attack_cd = 1.1
            if player.has_method("take_damage"):
                player.take_damage(10.0)
    velocity.y -= 22.0 * delta
    move_and_slide()
    body_mesh.rotation.y += delta * 1.5
    body_mesh.position.y = 0.9 + sin(Time.get_ticks_msec() * 0.003 + get_instance_id()) * 0.06

func receive_hit(damage: float, direction: Vector3, force: float) -> void:
    if not alive:
        return
    hp -= damage
    stagger += damage
    knockback = direction.normalized() * force
    stagger_time = 0.24 if stagger < 70.0 else 1.0
    if hp <= 0.0:
        alive = false
        if is_instance_valid(player) and player.has_method("on_kill"):
            player.on_kill()
        queue_free()
