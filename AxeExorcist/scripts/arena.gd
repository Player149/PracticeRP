extends Node3D

@export var ghost_scene: PackedScene
@export var target_ghost_count: int = 8
@export var respawn_interval: float = 2.8

@onready var player: CharacterBody3D = $Player
@onready var spawn_points: Node3D = $SpawnPoints
@onready var stats: Label = $HUD/Stats
@onready var controls: Label = $HUD/Controls

var respawn_timer: float = 0.0
var feedback_timer: float = 0.0

func _ready() -> void:
    player.stats_changed.connect(_update_hud)
    player.strike_feedback.connect(_on_hit)
    _update_hud(player.hp, player.kills, player.dash_charges)
    for i in range(target_ghost_count):
        _spawn_ghost()

func _process(delta: float) -> void:
    respawn_timer -= delta
    feedback_timer -= delta
    if feedback_timer <= 0.0:
        controls.modulate = Color.WHITE
    if respawn_timer <= 0.0:
        respawn_timer = respawn_interval
        if get_tree().get_nodes_in_group("ghosts").size() < target_ghost_count:
            _spawn_ghost()

func _spawn_ghost() -> void:
    if ghost_scene == null:
        return
    var markers := spawn_points.get_children()
    if markers.is_empty():
        return
    var marker: Marker3D = markers.pick_random()
    var ghost := ghost_scene.instantiate()
    ghost.player = player
    ghost.position = marker.position
    add_child(ghost)

func _on_hit(hit_count: int) -> void:
    if hit_count > 0:
        controls.modulate = Color(1.0, 0.45, 0.25)
        feedback_timer = 0.16

func _update_hud(hp: float, kills: int, dash: int) -> void:
    stats.text = "HP %d  |  EXORCISED %d  |  DASH %d/2" % [int(hp), kills, dash]

