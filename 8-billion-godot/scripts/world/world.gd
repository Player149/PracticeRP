extends Node2D

const HUMAN_SCENE: PackedScene = preload("res://scenes/actors/human.tscn")
const DEATH_EFFECT: PackedScene = preload("res://scenes/effects/death_particles.tscn")
const WORLD_WIDTH: float = 6000.0
const GROUND_Y: float = 560.0

@export_range(1, 400, 1) var dummy_count: int = 100
@export_range(50.0, 1200.0, 10.0) var starting_player_speed: float = 300.0
@export var camera_bounds: Rect2 = Rect2(0.0, -160.0, 6000.0, 880.0)

@onready var player: ShadowPlayer = $Player
@onready var hud: CanvasLayer = $HUD
@onready var crowd: Node2D = $Crowd
@onready var camera: Camera2D = $Player/Camera2D
var defeated: int = 0
var rng := RandomNumberGenerator.new()

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

func _set_player_speed(value: float) -> void:
	player.speed = value

func _on_human_defeated(human: HumanActor) -> void:
	var effect: Node2D = DEATH_EFFECT.instantiate()
	add_child(effect)
	effect.global_position = human.global_position + Vector2(0.0, -22.0)
	defeated += 1
	_update_hud()

func _on_player_attack(damage: int, reach: float, direction: float) -> void:
	var center_x: float = player.global_position.x + direction * reach * 0.5
	for node in crowd.get_children():
		var human: HumanActor = node as HumanActor
		if human != null and not human.is_queued_for_deletion():
			if absf(human.global_position.x - center_x) <= reach * 0.5 + 16.0 and absf(human.global_position.y - player.global_position.y) < 90.0:
				human.take_damage(damage, direction * 220.0)

func _update_hud() -> void:
	hud.update_stats(defeated, maxi(0, dummy_count - defeated))
