extends CharacterBody2D
class_name HumanActor

signal defeated(actor: HumanActor)

@export var max_health: int = 1
@export var gravity_force: float = 1450.0
var health: int = 1

func _ready() -> void:
	health = max_health
	$Sprite2D.modulate = Color.from_hsv(randf_range(0.0, 1.0), 0.14, randf_range(0.72, 1.0))

func _physics_process(delta: float) -> void:
	velocity.x = 0.0
	if not is_on_floor():
		velocity.y += gravity_force * delta
	move_and_slide()

func take_damage(amount: int, _push: float = 0.0) -> void:
	health -= amount
	if health <= 0:
		defeated.emit(self)
		queue_free()
