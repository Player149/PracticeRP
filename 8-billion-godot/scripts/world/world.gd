extends Node2D

const HUMAN_SCENE: PackedScene = preload("res://scenes/actors/human.tscn")
const DEATH_EFFECT: PackedScene = preload("res://scenes/effects/death_particles.tscn")
const WORLD_WIDTH: float = 6000.0
const GROUND_Y: float = 560.0
const ATTACK_HALF_ANGLE: float = 0.8

@export_range(1, 400, 1) var dummy_count: int = 100
@export_range(50.0, 1200.0, 10.0) var starting_player_speed: float = 300.0
@export var camera_bounds: Rect2 = Rect2(0.0, -160.0, 6000.0, 880.0)

@onready var player: ShadowPlayer = $Player
@onready var hud: CanvasLayer = $HUD
@onready var crowd: Node2D = $Crowd
@onready var camera: Camera2D = $Player/Camera2D
var defeated: int = 0
var rng := RandomNumberGenerator.new()
var shake_remaining: float = 0.0
var shake_strength: float = 0.0

func _ready() -> void:
	rng.randomize()
	player.speed = starting_player_speed
	player.attacked.connect(_on_player_attack)
	hud.set_speed(starting_player_speed)
	hud.speed_changed.connect(_set_player_speed)
	camera.position = Vector2.ZERO
	camera.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	camera.limit_left = roundi(camera_bounds.position.x)
	camera.limit_top = roundi(camera_bounds.position.y)
	camera.limit_right = roundi(camera_bounds.end.x)
	camera.limit_bottom = roundi(camera_bounds.end.y)
	camera.limit_smoothed = false
	for i in range(dummy_count):
		var human: HumanActor = HUMAN_SCENE.instantiate()
		crowd.add_child(human)
		human.global_position = Vector2(rng.randf_range(250.0, WORLD_WIDTH - 100.0), GROUND_Y)
		human.defeated.connect(_on_human_defeated)
	_update_hud()

func _process(delta: float) -> void:
	if shake_remaining > 0.0:
		shake_remaining = maxf(0.0, shake_remaining - delta)
		camera.offset = Vector2(rng.randf_range(-shake_strength, shake_strength), rng.randf_range(-shake_strength, shake_strength)) * minf(1.0, shake_remaining * 12.0)
	else:
		camera.offset = Vector2.ZERO

func _set_player_speed(value: float) -> void:
	player.speed = value

func _on_human_defeated(human: HumanActor) -> void:
	var effect: Node2D = DEATH_EFFECT.instantiate()
	add_child(effect)
	effect.global_position = human.global_position + Vector2(0.0, -22.0)
	defeated += 1
	_update_hud()

func _on_player_attack(damage: int, reach: float, direction: Vector2) -> void:
	var origin: Vector2 = player.global_position + Vector2(0.0, -28.0)
	for node in crowd.get_children():
		var human: HumanActor = node as HumanActor
		if human == null or human.is_queued_for_deletion():
			continue
		var to_target: Vector2 = human.global_position + Vector2(0.0, -30.0) - origin
		if to_target.length() > reach + 15.0:
			continue
		if to_target.length_squared() > 0.01 and absf(direction.angle_to(to_target)) > ATTACK_HALF_ANGLE:
			continue
		human.take_damage(damage, direction.x * 320.0)
		shake_remaining = 0.11
		shake_strength = 3.0

func _update_hud() -> void:
	hud.update_stats(defeated, maxi(0, dummy_count - defeated))
