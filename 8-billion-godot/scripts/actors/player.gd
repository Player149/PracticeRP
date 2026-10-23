extends CharacterBody2D
class_name ShadowPlayer

signal attacked(damage: int, reach: float, direction: float)

@export_range(50.0, 1200.0, 10.0) var speed: float = 300.0
@export var jump_velocity: float = -590.0
@export var gravity_force: float = 1450.0
@export_range(30.0, 400.0, 5.0) var attack_reach: float = 120.0
@export_range(0.05, 1.0, 0.01) var attack_interval: float = 0.22
var facing: float = 1.0
var attack_cooldown: float = 0.0
var slash: Node2D

func _ready() -> void:
	slash = get_node_or_null("AttackEffect")

func _physics_process(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if not is_on_floor():
		velocity.y += gravity_force * delta
	if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = jump_velocity
	var axis: float = float(int(Input.is_key_pressed(KEY_D)) - int(Input.is_key_pressed(KEY_A)))
	if axis != 0.0:
		facing = signf(axis)
		$Sprite2D.flip_h = facing < 0.0
	velocity.x = axis * speed
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and attack_cooldown <= 0.0:
		attack_cooldown = attack_interval
		attacked.emit(1, attack_reach, facing)
		if slash != null:
			slash.play(attack_reach, facing)
	move_and_slide()
