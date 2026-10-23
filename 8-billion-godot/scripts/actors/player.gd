extends CharacterBody2D
class_name ShadowPlayer

signal attacked(damage: int, reach: float, direction: float)
signal interact_requested
signal died

@export var speed: float = 300.0
@export var jump_velocity: float = -590.0
@export var max_health: int = 100
var health: int = 100
var attack_cooldown: float = 0.0
var dash_time: float = 0.0
var invulnerability: float = 0.0
var facing: float = 1.0
var gravity: float = 1450.0

func _ready() -> void:
	health = max_health

func _physics_process(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	dash_time = maxf(0.0, dash_time - delta)
	invulnerability = maxf(0.0, invulnerability - delta)
	if not is_on_floor():
		velocity.y += gravity * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
	var axis: float = Input.get_axis("move_left", "move_right")
	if axis != 0.0:
		facing = signf(axis)
		$Sprite2D.flip_h = facing < 0.0
	if Input.is_action_just_pressed("dash"):
		dash_time = 0.16
		invulnerability = 0.2
	velocity.x = facing * 780.0 if dash_time > 0.0 else axis * speed
	if Input.is_action_just_pressed("attack"):
		perform_attack(false)
	if Input.is_action_just_pressed("heavy_attack"):
		perform_attack(true)
	if Input.is_action_just_pressed("interact"):
		interact_requested.emit()
	move_and_slide()

func perform_attack(heavy: bool) -> void:
	if attack_cooldown > 0.0:
		return
	attack_cooldown = 0.65 if heavy else 0.24
	attacked.emit(4 if heavy else 1, 160.0 if heavy else 95.0, facing)

func receive_damage(amount: int) -> void:
	if invulnerability > 0.0:
		return
	health = maxi(0, health - amount)
	invulnerability = 0.65
	if health <= 0:
		died.emit()
