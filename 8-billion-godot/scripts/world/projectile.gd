extends Area2D
class_name EnemyProjectile

var velocity: Vector2 = Vector2.ZERO
var grenade: bool = false
var remaining: float = 2.0
var gravity: float = 920.0
var exploded: bool = false

func configure(start: Vector2, target: Vector2, is_grenade: bool) -> void:
	global_position = start
	grenade = is_grenade
	velocity = Vector2((target - start).normalized().x * 460.0, -370.0) if grenade else (target - start).normalized() * 490.0

func _physics_process(delta: float) -> void:
	remaining -= delta
	if grenade:
		velocity.y += gravity * delta
	position += velocity * delta
	if grenade and global_position.y >= 555.0:
		explode()
	elif remaining <= 0.0:
		queue_free()
	else:
		for body in get_overlapping_bodies():
			if body is ShadowPlayer:
				if grenade:
					explode()
				else:
					body.receive_damage(5)
					queue_free()
				break

func explode() -> void:
	if exploded:
		return
	exploded = true
	for body in get_overlapping_bodies():
		if body is ShadowPlayer:
			body.receive_damage(17)
	queue_free()
