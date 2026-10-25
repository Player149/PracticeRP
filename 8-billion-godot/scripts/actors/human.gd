extends CharacterBody2D
class_name HumanActor

signal defeated(actor: HumanActor)

@export_range(1, 20, 1) var max_health: int = 2
@export var gravity_force: float = 1450.0
@export var knockback_decay: float = 700.0
var health: int = 2
var hit_flash: float = 0.0
var base_color: Color = Color.WHITE

func _ready() -> void:
	health = max_health
	base_color = Color.from_hsv(randf_range(0.0, 1.0), 0.14, randf_range(0.72, 1.0))
	$Sprite2D.modulate = base_color

func _physics_process(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, knockback_decay * delta)
	if not is_on_floor():
		velocity.y += gravity_force * delta
	move_and_slide()
	if hit_flash > 0.0:
		hit_flash = maxf(0.0, hit_flash - delta)
		$Sprite2D.modulate = Color(1.0, 0.4, 0.52) if hit_flash > 0.0 else base_color

func take_damage(amount: int, push: float = 0.0) -> void:
	health -= amount
	velocity.x = push
	velocity.y = -180.0
	hit_flash = 0.1
	if health <= 0:
		defeated.emit(self)
		queue_free()
