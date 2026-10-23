extends Node2D

const HUMAN_SCENE: PackedScene = preload("res://scenes/actors/human.tscn")
const BUILDING_SCENE: PackedScene = preload("res://scenes/world/building.tscn")
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/world/projectile.tscn")
const INTERIOR_SCENE: PackedScene = preload("res://scenes/world/interior.tscn")
const WORLD_WIDTH: float = 6000.0
const GROUND_Y: float = 560.0
const INITIAL_POPULATION: int = 140
const MAX_POPULATION: int = 185

@onready var player: ShadowPlayer = $Player
@onready var hud: CanvasLayer = $HUD
@onready var crowd: Node2D = $Crowd
@onready var structures: Node2D = $Structures
@onready var projectiles: Node2D = $Projectiles
@onready var camera: Camera2D = $Player/Camera2D
@onready var floor_body: StaticBody2D = $Ground
var rng := RandomNumberGenerator.new()
var souls: int = 0
var defeated: int = 0
var destroyed_count: int = 0
var spawn_clock: float = 0.0
var inside: DestructibleBuilding
var interior_visual: Node2D
var exterior_position: Vector2

func _ready() -> void:
	add_to_group("world")
	rng.randomize()
	player.attacked.connect(_on_player_attack)
	player.interact_requested.connect(_toggle_building)
	player.died.connect(_restart)
	for i in range(12):
		var b: DestructibleBuilding = BUILDING_SCENE.instantiate()
		structures.add_child(b)
		b.position = Vector2(350.0 + float(i) * 450.0, GROUND_Y)
		b.destroyed.connect(_on_building_destroyed)
	for i in range(INITIAL_POPULATION):
		var role: int = 0
		var chance: float = rng.randf()
		if chance < 0.18:
			role = 1
		elif chance < 0.25:
			role = 2
		_spawn_human(rng.randf_range(170.0, WORLD_WIDTH - 100.0), role)
	_refresh_hud()

func _spawn_human(x: float, role: int) -> void:
	var human: HumanActor = HUMAN_SCENE.instantiate()
	human.role = role
	human.target = player
	crowd.add_child(human)
	human.global_position = Vector2(x, GROUND_Y)
	human.defeated.connect(_on_human_defeated)

func _process(delta: float) -> void:
	spawn_clock += delta
	if inside == null and spawn_clock >= 0.9:
		spawn_clock = 0.0
		if crowd.get_child_count() < MAX_POPULATION:
			_spawn_human(clampf(player.global_position.x + rng.randf_range(-700.0, 800.0), 20.0, WORLD_WIDTH - 20.0), 0 if rng.randf() < 0.72 else rng.randi_range(1, 2))
	# Avoid running off-screen AI physics for distant crowds.
	for node in crowd.get_children():
		var human: HumanActor = node as HumanActor
		if human != null:
			human.active_ai = inside == null and absf(human.global_position.x - player.global_position.x) < 1150.0
	_refresh_hud()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_restart()

func _restart() -> void:
	get_tree().reload_current_scene()

func _on_human_defeated(_human: HumanActor) -> void:
	defeated += 1
	souls += 1

func _on_building_destroyed(building: DestructibleBuilding) -> void:
	destroyed_count += 1
	souls += rng.randi_range(30000, 180000)
	if inside == building:
		_leave_building()

func _on_player_attack(damage: int, reach: float, direction: float) -> void:
	if inside != null:
		inside.apply_damage(20 if damage > 1 else 8)
		return
	var center_x: float = player.global_position.x + direction * reach * 0.5
	for node in crowd.get_children():
		var human: HumanActor = node as HumanActor
		if human != null and absf(human.global_position.x - center_x) <= reach * 0.5 + 18.0 and absf(human.global_position.y - player.global_position.y) < 85.0:
			human.take_damage(damage, direction * 220.0)
	for node in structures.get_children():
		var building: DestructibleBuilding = node as DestructibleBuilding
		if building != null and not building.is_destroyed:
			var tip: float = player.global_position.x + direction * reach
			if absf(building.global_position.x - tip) < 115.0:
				building.apply_damage(15 if damage > 1 else 5)

func _toggle_building() -> void:
	if inside != null:
		_leave_building()
		return
	for node in structures.get_children():
		var building: DestructibleBuilding = node as DestructibleBuilding
		if building != null and building.can_enter(player.global_position.x):
			_enter_building(building)
			return

func _enter_building(building: DestructibleBuilding) -> void:
	inside = building
	exterior_position = player.global_position
	interior_visual = INTERIOR_SCENE.instantiate()
	add_child(interior_visual)
	interior_visual.position = Vector2.ZERO
	# Reposition interior to a distant, separate part of the same world.
	interior_visual.global_position = Vector2(8000.0, 0.0)
	player.global_position = Vector2(8100.0, GROUND_Y)
	camera.limit_left = 8000
	camera.limit_right = 9280
	for node in crowd.get_children():
		(node as HumanActor).active_ai = false

func _leave_building() -> void:
	if is_instance_valid(interior_visual):
		interior_visual.queue_free()
	interior_visual = null
	inside = null
	player.global_position = exterior_position
	camera.limit_left = 0
	camera.limit_right = int(WORLD_WIDTH)

func spawn_projectile(start: Vector2, grenade: bool, target: Vector2) -> void:
	if inside != null:
		return
	var projectile: EnemyProjectile = PROJECTILE_SCENE.instantiate()
	projectiles.add_child(projectile)
	projectile.configure(start, target, grenade)

func _refresh_hud() -> void:
	hud.update_stats(player.health, souls, defeated, destroyed_count, inside != null)
