extends CharacterBody3D

@export var max_hp: float = 75.0
@export var movement_speed: float = 3.5
@export var attack_damage: float = 10.0
@export var attack_interval: float = 1.1

@onready var visual: MeshInstance3D = $Visual
var player: CharacterBody3D
var hp: float
var stagger: float = 0.0
var stagger_time: float = 0.0
var attack_cd: float = 0.8
var knockback: Vector3 = Vector3.ZERO

func _ready() -> void:
    add_to_group("ghosts")
    hp = max_hp

func _physics_process(delta: float) -> void:
    if not is_instance_valid(player):
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
        velocity.x = direction.x * movement_speed
        velocity.z = direction.z * movement_speed
    else:
        velocity.x = 0.0
        velocity.z = 0.0
        if attack_cd <= 0.0:
            attack_cd = attack_interval
            if player.has_method("take_damage"):
                player.take_damage(attack_damage)
    velocity.y -= 22.0 * delta
    move_and_slide()
    visual.rotation.y += delta * 1.5
    visual.position.y = 0.9 + sin(Time.get_ticks_msec() * 0.003 + float(get_instance_id() % 1000)) * 0.06

func receive_hit(damage: float, direction: Vector3, force: float) -> void:
    hp -= damage
    stagger += damage
    knockback = direction.normalized() * force
    stagger_time = 0.24 if stagger < 70.0 else 1.0
    if hp <= 0.0:
        if is_instance_valid(player) and player.has_method("on_kill"):
            player.on_kill()
        queue_free()
