extends Node3D
## Fully 3D signed-distance-field terrain. Marching tetrahedra makes smooth-ish
## rock surfaces (no Minecraft cube faces); only affected chunks rebuild on dig.

const GRID: int = 9
const STEP: float = 1.05
const CHUNK: float = GRID * STEP
const COUNT: Vector3i = Vector3i(4, 2, 4)
const ORIGIN: Vector3 = Vector3(-18.9, -14.2, -18.9)
const CORNERS = [
	Vector3i(0, 0, 0), Vector3i(1, 0, 0),
	Vector3i(1, 1, 0), Vector3i(0, 1, 0),
	Vector3i(0, 0, 1), Vector3i(1, 0, 1),
	Vector3i(1, 1, 1), Vector3i(0, 1, 1)
]
const TETS = [
	[0, 5, 1, 6], [0, 1, 2, 6], [0, 2, 3, 6],
	[0, 3, 7, 6], [0, 7, 4, 6], [0, 4, 5, 6]
]

var caves: Array[Dictionary] = [
	{"center": Vector3(0.0, -3.75, 0.0), "radius": Vector3(7.1, 5.4, 6.6)},
	{"center": Vector3(12.0, -4.8, -8.5), "radius": Vector3(5.3, 4.1, 5.5)},
	{"center": Vector3(-12.2, -5.8, 11.5), "radius": Vector3(5.1, 4.3, 5.4)}
]
var tunnels: Array[Dictionary] = [
	{"a": Vector3(4.7, -4.0, -3.5), "b": Vector3(11.6, -5.0, -7.2), "radius": 2.25},
	{"a": Vector3(-5.3, -5.0, 4.6), "b": Vector3(-11.7, -5.6, 10.3), "radius": 1.75}
]
var noise := FastNoiseLite.new()
var chunks: Dictionary = {}
var chunk_digs: Dictionary = {}
var all_digs: Array[Vector4] = []
var rebuild_queue: Array[Vector3i] = []
var queued: Dictionary = {}
var stone_material: StandardMaterial3D
var current_seed: int = 0

func _ready() -> void:
	stone_material = StandardMaterial3D.new()
	stone_material.vertex_color_use_as_albedo = true
	stone_material.roughness = 0.98
	stone_material.metallic = 0.03
	stone_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.09
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3

func new_mine(seed_value: int) -> void:
	current_seed = seed_value
	noise.seed = current_seed
	all_digs.clear()
	chunk_digs.clear()
	rebuild_queue.clear()
	queued.clear()
	for item in chunks.values():
		var body: StaticBody3D = item["body"]
		body.queue_free()
	chunks.clear()
	for x in range(COUNT.x):
		for y in range(COUNT.y):
			for z in range(COUNT.z):
				var key := Vector3i(x, y, z)
				var body := StaticBody3D.new()
				body.name = "Rock_%d_%d_%d" % [x, y, z]
				body.collision_layer = 1
				body.collision_mask = 0
				body.position = _chunk_origin(key)
				add_child(body)
				var visual := MeshInstance3D.new()
				visual.material_override = stone_material
				body.add_child(visual)
				var collision := CollisionShape3D.new()
				body.add_child(collision)
				chunks[key] = {"body": body, "visual": visual, "collision": collision}
				_build_chunk(key)

func _process(_delta: float) -> void:
	# Rebuild at most 2 chunks per frame after mining to reduce touch-device stalls.
	for i in range(mini(2, rebuild_queue.size())):
		var key: Vector3i = rebuild_queue.pop_front()
		queued.erase(key)
		_build_chunk(key)

func _chunk_origin(key: Vector3i) -> Vector3:
	return ORIGIN + Vector3(key.x, key.y, key.z) * CHUNK

func _inside_chunk_bounds(key: Vector3i) -> bool:
	return key.x >= 0 and key.y >= 0 and key.z >= 0 and key.x < COUNT.x and key.y < COUNT.y and key.z < COUNT.z

func _ellipsoid(p: Vector3, center: Vector3, radius: Vector3) -> float:
	var n := (p - center) / radius
	return (n.length() - 1.0) * minf(radius.x, minf(radius.y, radius.z))

func base_density(p: Vector3) -> float:
	# Positive means solid rock; negative means empty cave.
	var d := 1000.0
	for cave in caves:
		d = minf(d, _ellipsoid(p, cave["center"], cave["radius"]))
	for tunnel in tunnels:
		var a: Vector3 = tunnel["a"]
		var b: Vector3 = tunnel["b"]
		var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		d = minf(d, p.distance_to(a.lerp(b, t)) - float(tunnel["radius"]))
	# Spatial noise roughens the cave walls but keeps them navigable.
	d += noise.get_noise_3d(p.x, p.y, p.z) * 0.64
	d += noise.get_noise_3d(p.x * 3.1, p.y * 3.1, p.z * 3.1) * 0.18
	return d

func density(p: Vector3) -> float:
	var d := base_density(p)
	for dig in all_digs:
		d = minf(d, p.distance_to(Vector3(dig.x, dig.y, dig.z)) - dig.w)
	return d

func _density_for_chunk(p: Vector3, relevant_digs: Array) -> float:
	var d := base_density(p)
	for dig in relevant_digs:
		d = minf(d, p.distance_to(Vector3(dig.x, dig.y, dig.z)) - dig.w)
	return d

func dig(center: Vector3, radius: float) -> bool:
	if center.x < ORIGIN.x + 1.5 or center.z < ORIGIN.z + 1.5:
		return false
	var max_pos := ORIGIN + Vector3(COUNT.x, COUNT.y, COUNT.z) * CHUNK
	if center.x > max_pos.x - 1.5 or center.z > max_pos.z - 1.5:
		return false
	if center.y < ORIGIN.y + 1.3 or center.y > max_pos.y - 1.3:
		return false
	var dig_sphere := Vector4(center.x, center.y, center.z, radius)
	all_digs.append(dig_sphere)
	var low := center - Vector3.ONE * (radius + STEP)
	var high := center + Vector3.ONE * (radius + STEP)
	var k0 := Vector3i(floori((low.x - ORIGIN.x) / CHUNK), floori((low.y - ORIGIN.y) / CHUNK), floori((low.z - ORIGIN.z) / CHUNK))
	var k1 := Vector3i(floori((high.x - ORIGIN.x) / CHUNK), floori((high.y - ORIGIN.y) / CHUNK), floori((high.z - ORIGIN.z) / CHUNK))
	for x in range(k0.x, k1.x + 1):
		for y in range(k0.y, k1.y + 1):
			for z in range(k0.z, k1.z + 1):
				var key := Vector3i(x, y, z)
				if not _inside_chunk_bounds(key):
					continue
				if not chunk_digs.has(key):
					chunk_digs[key] = []
				chunk_digs[key].append(dig_sphere)
				if not queued.has(key):
					queued[key] = true
					rebuild_queue.append(key)
	return true

func _index(x: int, y: int, z: int) -> int:
	return x + (GRID + 1) * (y + (GRID + 1) * z)

func _build_chunk(key: Vector3i) -> void:
	if not chunks.has(key):
		return
	var offset := _chunk_origin(key)
	var relevant_digs: Array = chunk_digs.get(key, [])
	var samples := PackedFloat32Array()
	samples.resize((GRID + 1) * (GRID + 1) * (GRID + 1))
	for z in range(GRID + 1):
		for y in range(GRID + 1):
			for x in range(GRID + 1):
				var p := offset + Vector3(x, y, z) * STEP
				samples[_index(x, y, z)] = _density_for_chunk(p, relevant_digs)

	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var colors := PackedColorArray()
	for z in range(GRID):
		for y in range(GRID):
			for x in range(GRID):
				var ps: Array[Vector3] = []
				var ds: Array[float] = []
				var inside := 0
				for corner in CORNERS:
					var ix: int = x + corner.x
					var iy: int = y + corner.y
					var iz: int = z + corner.z
					ps.append(Vector3(ix, iy, iz) * STEP)
					var sample: float = samples[_index(ix, iy, iz)]
					ds.append(sample)
					if sample < 0.0:
						inside += 1
				if inside == 0 or inside == 8:
					continue
				for tetra in TETS:
					_polygonize_tetra(tetra, ps, ds, offset, verts, norms, colors)
	var part: Dictionary = chunks[key]
	var visual: MeshInstance3D = part["visual"]
	var collision: CollisionShape3D = part["collision"]
	if verts.is_empty():
		visual.mesh = null
		collision.shape = null
		return
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	visual.mesh = mesh
	var rock_shape := mesh.create_trimesh_shape()
	rock_shape.backface_collision = true
	collision.shape = rock_shape

func _polygonize_tetra(t: Array, ps: Array[Vector3], ds: Array[float], offset: Vector3, verts: PackedVector3Array, norms: PackedVector3Array, colors: PackedColorArray) -> void:
	var neg: Array[int] = []
	var pos: Array[int] = []
	for j in t:
		if ds[j] < 0.0:
			neg.append(j)
		else:
			pos.append(j)
	if neg.is_empty() or pos.is_empty():
		return
	var inward := Vector3.ZERO
	for j in neg:
		inward += ps[j] / float(neg.size())
	for j in pos:
		inward -= ps[j] / float(pos.size())
	if neg.size() == 1:
		_emit_face(_edge(neg[0], pos[0], ps, ds), _edge(neg[0], pos[1], ps, ds), _edge(neg[0], pos[2], ps, ds), inward, offset, verts, norms, colors)
	elif pos.size() == 1:
		_emit_face(_edge(pos[0], neg[0], ps, ds), _edge(pos[0], neg[1], ps, ds), _edge(pos[0], neg[2], ps, ds), inward, offset, verts, norms, colors)
	else:
		var a := _edge(neg[0], pos[0], ps, ds)
		var b := _edge(neg[0], pos[1], ps, ds)
		var c := _edge(neg[1], pos[0], ps, ds)
		var d := _edge(neg[1], pos[1], ps, ds)
		_emit_face(a, b, c, inward, offset, verts, norms, colors)
		_emit_face(b, d, c, inward, offset, verts, norms, colors)

func _edge(i: int, j: int, ps: Array[Vector3], ds: Array[float]) -> Vector3:
	var t := clampf(ds[i] / (ds[i] - ds[j]), 0.0, 1.0)
	return ps[i].lerp(ps[j], t)

func _emit_face(a: Vector3, b: Vector3, c: Vector3, toward_air: Vector3, offset: Vector3, verts: PackedVector3Array, norms: PackedVector3Array, colors: PackedColorArray) -> void:
	var normal := (b - a).cross(c - a)
	if normal.length_squared() < 0.0000001:
		return
	if normal.dot(toward_air) < 0.0:
		var hold := b
		b = c
		c = hold
		normal = -normal
	normal = normal.normalized()
	var mid := offset + (a + b + c) / 3.0
	var tint := clampf(0.46 + noise.get_noise_3d(mid.x * 0.8, mid.y * 0.8, mid.z * 0.8) * 0.18 + (mid.y + 10.0) * 0.006, 0.31, 0.67)
	var col := Color(tint * 0.90, tint * 0.96, tint * 1.1, 1.0)
	for p in [a, b, c]:
		verts.append(p)
		norms.append(normal)
		colors.append(col)
