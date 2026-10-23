extends CharacterBody2D
class_name ShadowPlayer

signal attacked(damage: int, reach: float, direction: Vector2)

@export_range(50.0, 1200.0, 10.0) var speed: float = 300.0
@export var jump_velocity: float = -590.0
@export var gravity_force: float = 1450.0
@export_range(30.0, 400.0, 5.0) var attack_reach: float = 120.0
@export_range(0.05, 1.0, 0.01) var attack_interval: float = 0.28
var facing: float = 1.0
var attack_cooldown: float = 0.0
var squash: float = 0.0
@onready var slash: Node2D = $AttackEffect
@onready var sprite: Sprite2D = $Sprite2D
var previous_floor: bool = false

func _physics_process(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	var on_floor: bool = is_on_floor()
	if not on_floor:
		velocity.y += gravity_force * delta
	if Input.is_key_pressed(KEY_SPACE) and on_floor:
		velocity.y = jump_velocity
		squash = -0.15
	var axis: float = float(int(Input.is_key_pressed(KEY_D)) - int(Input.is_key_pressed(KEY_A)))
	velocity.x = axis * speed
	var aim: Vector2 = get_global_mouse_position() - (global_position + Vector2(0.0, -28.0))
	if aim.length_squared() > 0.01 and absf(aim.x) > 0.01:
		facing = signf(aim.x)
	sprite.flip_h = facing < 0.0
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and attack_cooldown <= 0.0:
		attack_cooldown = attack_interval
		var direction: Vector2 = aim.normalized() if aim.length_squared() > 0.01 else Vector2(facing, 0.0)
		slash.play(attack_reach, direction)
		attacked.emit(1, attack_reach, direction)
		squash = -0.1
	move_and_slide()
	if not previous_floor and is_on_floor():
		squash = 0.2
	previous_floor = is_on_floor()
	squash = move_toward(squash, 0.0, delta * 2.8)
	var breathing: float = sin(Time.get_ticks_msec() * 0.004) * 0.014
	sprite.scale = Vector2(0.5 * (1.0 + squash), 0.43 * (1.0 - squash + breathing))
