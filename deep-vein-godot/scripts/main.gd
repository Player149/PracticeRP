extends Node3D
## Dig-only playable sandbox: tap / hold / drag to sculpt 3D ground.
const GRID_SIZE: int = 64
const HALF_SIZE: float = 16.0
const CELL_SIZE: float = 0.5
const BRUSH_RADIUS: float = 2.15
const BRUSH_STRENGTH: float = 0.68
const MIN_HEIGHT: float = -7.0

@onready var camera: Camera3D = $Camera3D
@onready var ground_mesh: MeshInstance3D = $Ground/TerrainMesh
@onready var ground_collider: CollisionShape3D = $Ground/TerrainCollider
@onready var sun: DirectionalLight3D = $Sun

var terrain_material: StandardMaterial3D
var heights: PackedFloat32Array = PackedFloat32Array()
var camera_focus: Vector3 = Vector3.ZERO
var zoom_distance: float = 30.0
var digging: bool = false
var touch_id: int = -1
var dig_position: Vector2 = Vector2.ZERO
var dig_cooldown: float = 0.0
var dig_count: int = 0
var status_label: Label

func _ready() -> void:
	_setup_world()
	_setup_ui()
	_reset_ground()
	_update_camera()

func _setup_world() -> void:
	var world: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.17, 0.25, 0.34)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.85, 0.90, 1.0)
	environment.ambient_light_energy = 0.65
	world.environment = environment
	add_child(world)
	sun.rotation = Vector3(-0.93, -0.42, 0.0)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	camera.current = true
	camera.fov = 60.0
	terrain_material = StandardMaterial3D.new()
	terrain_material.vertex_color_use_as_albedo = true
	terrain_material.roughness = 1.0
	terrain_material.cull_mode = BaseMaterial3D.CULL_DISABLED

func _idx(x: int, z: int) -> int:
	return z * (GRID_SIZE + 1) + x

func _reset_ground() -> void:
	digging = false
	touch_id = -1
	heights.resize((GRID_SIZE + 1) * (GRID_SIZE + 1))
	for z in range(GRID_SIZE + 1):
		for x in range(GRID_SIZE + 1):
			var wx: float = float(x) * CELL_SIZE - HALF_SIZE
			var wz: float = float(z) * CELL_SIZE - HALF_SIZE
			var height: float = 0.15 * sin(wx * 0.35) * cos(wz * 0.31)
			# Visible starting depression proves the terrain is three dimensional.
			var sample_distance: float = Vector2(wx + 7.0, wz + 4.0).length()
			if sample_distance < 3.0:
				var weight: float = 1.0 - sample_distance / 3.0
				height -= 1.45 * weight * weight
			heights[_idx(x, z)] = height
	dig_count = 0
	_rebuild_terrain()
	_update_status()

func _rebuild_terrain() -> void:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()
	for z in range(GRID_SIZE + 1):
		for x in range(GRID_SIZE + 1):
			var h: float = heights[_idx(x, z)]
			vertices.append(Vector3(float(x) * CELL_SIZE - HALF_SIZE, h, float(z) * CELL_SIZE - HALF_SIZE))
			var l: float = heights[_idx(maxi(0, x - 1), z)]
			var r: float = heights[_idx(mini(GRID_SIZE, x + 1), z)]
			var b: float = heights[_idx(x, maxi(0, z - 1))]
			var f: float = heights[_idx(x, mini(GRID_SIZE, z + 1))]
			normals.append(Vector3(l - r, 2.0 * CELL_SIZE, b - f).normalized())
			var brightness: float = clampf(1.0 + h * 0.075, 0.42, 1.05)
			colors.append(Color(0.69 * brightness, 0.56 * brightness, 0.41 * brightness))
	for z in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var a: int = _idx(x, z)
			var b: int = _idx(x + 1, z)
			var c: int = _idx(x, z + 1)
			var d: int = _idx(x + 1, z + 1)
			indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, terrain_material)
	ground_mesh.mesh = mesh
	ground_collider.shape = mesh.create_trimesh_shape()

func _carve(hit_point: Vector3) -> void:
	var changed: bool = false
	for z in range(GRID_SIZE + 1):
		var wz: float = float(z) * CELL_SIZE - HALF_SIZE
		if absf(wz - hit_point.z) > BRUSH_RADIUS:
			continue
		for x in range(GRID_SIZE + 1):
			var wx: float = float(x) * CELL_SIZE - HALF_SIZE
			var distance: float = Vector2(wx - hit_point.x, wz - hit_point.z).length()
			if distance >= BRUSH_RADIUS:
				continue
			var strength: float = 1.0 - distance / BRUSH_RADIUS
			var i: int = _idx(x, z)
			var next_height: float = maxf(MIN_HEIGHT, heights[i] - BRUSH_STRENGTH * strength * strength)
			if next_height < heights[i]:
				heights[i] = next_height
				changed = true
	if changed:
		dig_count += 1
		_rebuild_terrain()
		_update_status()

func _dig_at_screen(screen_point: Vector2) -> void:
	var origin: Vector3 = camera.project_ray_origin(screen_point)
	var end: Vector3 = origin + camera.project_ray_normal(screen_point) * 150.0
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, end)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		var point: Vector3 = hit["position"]
		_carve(point)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			digging = mouse.pressed
			if digging:
				dig_position = mouse.position
				_dig_at_screen(dig_position)
				dig_cooldown = 0.13
		elif mouse.pressed and mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(-3.0)
		elif mouse.pressed and mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(3.0)
	elif event is InputEventMouseMotion and digging and touch_id == -1:
		var motion: InputEventMouseMotion = event
		dig_position = motion.position
	elif event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed and touch_id == -1:
			touch_id = touch.index
			digging = true
			dig_position = touch.position
			_dig_at_screen(dig_position)
			dig_cooldown = 0.13
		elif not touch.pressed and touch.index == touch_id:
			touch_id = -1
			digging = false
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		if drag.index == touch_id:
			dig_position = drag.position
	elif event is InputEventKey:
		var key: InputEventKey = event
		if key.pressed and not key.echo and key.keycode == KEY_R:
			_reset_ground()

func _process(delta: float) -> void:
	var step: Vector2 = Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		step.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		step.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		step.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		step.y += 1.0
	if step.length_squared() > 0.0:
		step = step.normalized()
		camera_focus.x = clampf(camera_focus.x + step.x * delta * 8.0, -HALF_SIZE * 0.60, HALF_SIZE * 0.60)
		camera_focus.z = clampf(camera_focus.z + step.y * delta * 8.0, -HALF_SIZE * 0.60, HALF_SIZE * 0.60)
		_update_camera()
	if digging:
		dig_cooldown -= delta
		if dig_cooldown <= 0.0:
			dig_cooldown = 0.13
			_dig_at_screen(dig_position)

func _update_camera() -> void:
	camera.position = camera_focus + Vector3(0.0, zoom_distance * 0.93, zoom_distance * 0.78)
	camera.look_at(camera_focus, Vector3.UP)

func _zoom(amount: float) -> void:
	zoom_distance = clampf(zoom_distance + amount, 13.0, 54.0)
	_update_camera()

func _update_status() -> void:
	if status_label != null:
		status_label.text = "DIG TEST  |  Excavations: %d" % dig_count

func _setup_ui() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	add_child(canvas)
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)

	var title: Label = Label.new()
	title.position = Vector2(15, 14)
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color.WHITE)
	root.add_child(title)
	status_label = title

	var hint: Label = Label.new()
	hint.position = Vector2(15, 47)
	hint.text = "Tap / hold / drag to DIG  |  R: reset  |  WASD: move camera"
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	root.add_child(hint)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.anchor_left = 1.0
	buttons.anchor_right = 1.0
	buttons.anchor_top = 1.0
	buttons.anchor_bottom = 1.0
	buttons.offset_left = -315.0
	buttons.offset_right = -12.0
	buttons.offset_top = -71.0
	buttons.offset_bottom = -16.0
	buttons.add_theme_constant_override("separation", 9)
	root.add_child(buttons)

	var reset_button: Button = Button.new()
	reset_button.text = "RESET"
	reset_button.custom_minimum_size = Vector2(125, 51)
	reset_button.focus_mode = Control.FOCUS_NONE
	reset_button.pressed.connect(_reset_ground)
	buttons.add_child(reset_button)

	var plus_button: Button = Button.new()
	plus_button.text = "ZOOM +"
	plus_button.custom_minimum_size = Vector2(77, 51)
	plus_button.focus_mode = Control.FOCUS_NONE
	plus_button.pressed.connect(func() -> void: _zoom(-4.0))
	buttons.add_child(plus_button)

	var minus_button: Button = Button.new()
	minus_button.text = "-"
	minus_button.custom_minimum_size = Vector2(56, 51)
	minus_button.focus_mode = Control.FOCUS_NONE
	minus_button.pressed.connect(func() -> void: _zoom(4.0))
	buttons.add_child(minus_button)
