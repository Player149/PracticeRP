extends StaticBody3D
## An ore deposit may be on a visible wall or concealed within solid rock.
signal mined(ore_type: int, value: int, location: Vector3)

const LABELS = ["Coal", "Copper", "Iron", "Gold", "Azure", "Starlight"]
const VALUES = [2, 5, 9, 20, 55, 180]
const COLORS = [
	Color("525960"), Color("ca784b"), Color("9facb5"),
	Color("f4bd45"), Color("4fdaf2"), Color("dc7dff")
]

var type_id: int = 0
var hp: int = 1
var hit_at: float = 0.0

func setup(ore_kind: int, normal_to_air: Vector3, size_factor: float) -> void:
	type_id = ore_kind
	hp = 1 + ore_kind / 2
	collision_layer = 2
	collision_mask = 0
	basis = Basis(Quaternion(Vector3.UP, normal_to_air.normalized()))
	scale = Vector3.ONE * size_factor
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLORS[type_id]
	mat.metallic = 0.24
	mat.roughness = 0.32
	mat.emission_enabled = type_id >= 3
	mat.emission = COLORS[type_id]
	mat.emission_energy_multiplier = 0.55 if type_id >= 3 else 0.0
	for i in range(4):
		var crystal := MeshInstance3D.new()
		var primitive := CylinderMesh.new()
		primitive.top_radius = 0.03
		primitive.bottom_radius = 0.22 if i > 0 else 0.32
		primitive.height = 0.8 if i > 0 else 1.15
		primitive.radial_segments = 6
		crystal.mesh = primitive
		crystal.material_override = mat
		var angle := float(i) * TAU / 4.0
		crystal.position = Vector3(cos(angle) * 0.20, 0.30 if i > 0 else 0.46, sin(angle) * 0.20)
		crystal.rotation = Vector3(cos(angle) * 0.38, 0.3 * float(i), sin(angle) * 0.38)
		add_child(crystal)
	var shape := SphereShape3D.new()
	shape.radius = 0.65
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0, 0.35, 0)
	add_child(collision)

func strike() -> void:
	hp -= 1
	if hp <= 0:
		mined.emit(type_id, VALUES[type_id], global_position)
		queue_free()
	else:
		hit_at = Time.get_ticks_msec() / 1000.0

func _process(_delta: float) -> void:
	if Time.get_ticks_msec() / 1000.0 - hit_at < 0.15:
		visible = (Engine.get_process_frames() % 2 == 0)
	else:
		visible = true
