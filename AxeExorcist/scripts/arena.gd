extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const GHOST_SCRIPT = preload("res://scripts/ghost.gd")
var player: CharacterBody3D
var status: Label
var hint: Label
var respawn_time: float = 0.0
var feedback_time: float = 0.0

func _ready() -> void:
    _make_light()
    _make_block(Vector3(0,-0.55,0), Vector3(44,1,44), Color(0.18,0.20,0.22), true)
    for i in range(11):
        var v: float = -20.0 + i * 4.0
        _make_block(Vector3(v,1.7,-22), Vector3(4.0,3.4,1.0), Color(0.18,0.23,0.25), true)
        _make_block(Vector3(v,1.7,22), Vector3(4.0,3.4,1.0), Color(0.18,0.23,0.25), true)
        _make_block(Vector3(-22,1.7,v), Vector3(1.0,3.4,4.0), Color(0.18,0.23,0.25), true)
        _make_block(Vector3(22,1.7,v), Vector3(1.0,3.4,4.0), Color(0.18,0.23,0.25), true)
    for pos in [Vector3(-8,1,-6),Vector3(9,1,5),Vector3(-6,1,10),Vector3(7,1,-10)]:
        _make_block(pos, Vector3(2,2,2), Color(0.30,0.31,0.34), true)
    player = CharacterBody3D.new()
    player.name = "Player"
    player.set_script(PLAYER_SCRIPT)
    player.position = Vector3(0,0.3,8)
    add_child(player)
    player.stats_changed.connect(_update_hud)
    player.strike_feedback.connect(_on_strike)
    _make_ui()
    for i in range(8):
        _spawn_ghost()

func _make_light() -> void:
    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-55,25,0)
    light.light_energy = 0.65
    add_child(light)
    var environment := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.045,0.057,0.071)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.25,0.31,0.36)
    env.ambient_light_energy = 0.55
    environment.environment = env
    add_child(environment)

func _make_block(pos: Vector3, size: Vector3, tint: Color, solid: bool) -> void:
    var root := StaticBody3D.new()
    root.position = pos
    var visual := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    visual.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    visual.material_override = mat
    root.add_child(visual)
    if solid:
        var collider := CollisionShape3D.new()
        var box := BoxShape3D.new()
        box.size = size
        collider.shape = box
        root.add_child(collider)
    add_child(root)

func _spawn_ghost() -> void:
    var ghost := CharacterBody3D.new()
    ghost.name = "Ghost"
    ghost.set_script(GHOST_SCRIPT)
    var theta: float = randf() * TAU
    var dist: float = randf_range(8.0,17.0)
    ghost.position = Vector3(cos(theta) * dist,0.3,sin(theta) * dist)
    ghost.player = player
    add_child(ghost)

func _make_ui() -> void:
    var canvas := CanvasLayer.new()
    add_child(canvas)
    status = Label.new()
    status.position = Vector2(18,16)
    status.add_theme_font_size_override("font_size",22)
    canvas.add_child(status)
    hint = Label.new()
    hint.position = Vector2(18,48)
    hint.text = "WASD Move | Mouse Aim | LMB Slash / Hold Heavy | Shift Dash | F Kick | Space Jump | Esc Unlock"
    hint.add_theme_font_size_override("font_size",15)
    canvas.add_child(hint)
    var center := Label.new()
    center.text = "+"
    center.set_anchors_preset(Control.PRESET_CENTER)
    center.position = Vector2(-5,-12)
    center.add_theme_font_size_override("font_size",24)
    canvas.add_child(center)
    _update_hud(player.hp,player.kills,player.dash_charges)

func _process(delta: float) -> void:
    respawn_time -= delta
    feedback_time -= delta
    if respawn_time <= 0.0:
        respawn_time = 2.8
        var count: int = get_tree().get_nodes_in_group("ghosts").size()
        if count < 8:
            _spawn_ghost()
    if feedback_time <= 0.0 and is_instance_valid(hint):
        hint.modulate = Color.WHITE

func _on_strike(hit_count: int) -> void:
    if hit_count > 0:
        hint.modulate = Color(1.0,0.45,0.25)
        feedback_time = 0.16

func _update_hud(hp: float, kills: int, dash: int) -> void:
    if is_instance_valid(status):
        status.text = "HP %d  |  EXORCISED %d  |  DASH %d/2" % [int(hp), kills, dash]
