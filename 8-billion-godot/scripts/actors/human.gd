extends CharacterBody2D
class_name HumanActor

signal defeated(actor: HumanActor)

@export_enum("Civilian", "Soldier", "Grenadier") var role: int = 0
@export var max_health: int = 1
@export var walk_speed: float = 155.0

var health: int = 1
var target: Node2D
var active_ai: bool = true
var shoot_timer: float = 1.0
var fear_timer: float = 0.0
var gravity: float = 1450.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	health = 1 if role == 0 else 3
	shoot_timer = rng.randf_range(0.5, 2.0)
	$Sprite2D.modulate = Color("#c4b5b0") if role == 0 else Color("#a3b29c")

func _physics_process(delta: float) -> void:
	if not active_ai or not is_instance_valid(target):
		return
	var dx: float = target.global_position.x - global_position.x
	if role == 0:
		if absf(dx) < 470.0:
			fear_timer = 2.5
		fear_timer = maxf(0.0, fear_timer - delta)
		var direction: float = -signf(dx) if fear_timer > 0.0 else 0.0
		velocity.x = move_toward(velocity.x, direction * walk_speed, 360.0 * delta)
	else:
		var direction: float = -signf(dx) if absf(dx) < 160.0 else (signf(dx) if absf(dx) > 350.0 else 0.0)
		velocity.x = move_toward(velocity.x, direction * walk_speed * 0.65, 250.0 * delta)
		shoot_timer -= delta
		if absf(dx) < 640.0 and shoot_timer <= 0.0:
			shoot_timer = rng.randf_range(2.8, 4.1) if role == 2 else rng.randf_range(0.9, 2.0)
			get_tree().call_group("world", "spawn_projectile", global_position + Vector2(0, -15), role == 2, target.global_position)
	if not is_on_floor():
		velocity.y += gravity * delta
	move_and_slide()

func take_damage(amount: int, push: float) -> void:
	health -= amount
	velocity.x += push
	if health <= 0:
		defeated.emit(self)
		queue_free()
