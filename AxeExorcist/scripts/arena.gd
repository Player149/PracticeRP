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
    # Arena's structural nodes are authored in the scene; only temporary graybox cover is generated.
    _build_graybox()
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

func _build_graybox() -> void:
    # TODO: replace these temporary blocks with editable level scene instances.
    _block(Vector3(0, -0.55, 0), Vector3(44, 1, 44), Color(0.18, 0.20, 0.22))
    for i in range(11):
        var v: float = -20.0 + i * 4.0
        _block(Vector3(v, 1.7, -22), Vector3(4, 3.4, 1), Color(0.18, 0.23, 0.25))
        _block(Vector3(v, 1.7, 22), Vector3(4, 3.4, 1), Color(0.18, 0.23, 0.25))
        _block(Vector3(-22, 1.7, v), Vector3(1, 3.4, 4), Color(0.18, 0.23, 0.25))
        _block(Vector3(22, 1.7, v), Vector3(1, 3.4, 4), Color(0.18, 0.23, 0.25))
    for pos in [Vector3(-8, 1, -6), Vector3(9, 1, 5), Vector3(-6, 1, 10), Vector3(7, 1, -10)]:
        _block(pos, Vector3(2, 2, 2), Color(0.30, 0.31, 0.34))

func _block(pos: Vector3, size: Vector3, tint: Color) -> void:
    var block := StaticBody3D.new()
    block.position = pos
    var visual := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    visual.mesh = mesh
    var material := StandardMaterial3D.new()
    material.albedo_color = tint
    visual.material_override = material
    block.add_child(visual)
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    block.add_child(collision)
    $Geometry.add_child(block)
