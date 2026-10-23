extends Node3D
## Signed-density voxels with marching tetrahedra. Positive rock, negative air.
## A spherical subtraction modifies only chunks touched by the DIG tool.

const CELLS: int = 10
const VOXEL_SIZE: float = 0.8
const CHUNK_WORLD_SIZE: float = 8.0
const CHUNK_COUNT: Vector3i = Vector3i(3, 2, 3)
const ORIGIN: Vector3 = Vector3(-12.0, -12.0, -12.0)
const DIG_RADIUS: float = 1.45
const DIG_INSET: float = 0.52

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

var noise: FastNoiseLite = FastNoiseLite.new()
var rock_material: StandardMaterial3D
var chunks: Dictionary = {}
var chunk_digs: Dictionary = {}
var dirty_keys: Array[Vector3i] = []
var queued_keys: Dictionary = {}

func _ready() -> void:
    noise.seed = 1974
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    noise.frequency = 0.075
    rock_material = StandardMaterial3D.new()
    rock_material.albedo_color = Color(0.52, 0.40, 0.29)
    rock_material.roughness = 0.96
    rock_material.cull_mode = BaseMaterial3D.CULL_BACK

    # Top chunks first: spawn area is walkable before the lower chunks initialize.
    for y in range(CHUNK_COUNT.y - 1, -1, -1):
        for x in range(CHUNK_COUNT.x):
            for z in range(CHUNK_COUNT.z):
                var key: Vector3i = Vector3i(x, y, z)
                var body: StaticBody3D = StaticBody3D.new()
                body.name = "Stone_%d_%d_%d" % [x, y, z]
                body.collision_layer = 1
                body.collision_mask = 0
                body.add_to_group("diggable_terrain")
                body.position = _chunk_origin(key)
                add_child(body)

                var visual: MeshInstance3D = MeshInstance3D.new()
                visual.material_override = rock_material
                visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
                body.add_child(visual)
                var collision: CollisionShape3D = CollisionShape3D.new()
                body.add_child(collision)
                chunks[key] = {"body": body, "visual": visual, "collision": collision}
                _rebuild_chunk(key)

func _process(_delta: float) -> void:
    # Avoid rebuilding all affected chunks in a single mobile frame.
    if not dirty_keys.is_empty():
        var key: Vector3i = dirty_keys.pop_front()
        queued_keys.erase(key)
        _rebuild_chunk(key)

func get_preview_radius() -> float:
    return sqrt(DIG_RADIUS * DIG_RADIUS - DIG_INSET * DIG_INSET)

func _chunk_origin(key: Vector3i) -> Vector3:
    return ORIGIN + Vector3(key.x, key.y, key.z) * CHUNK_WORLD_SIZE

func _valid_chunk(key: Vector3i) -> bool:
    return key.x >= 0 and key.y >= 0 and key.z >= 0 \
        and key.x < CHUNK_COUNT.x and key.y < CHUNK_COUNT.y and key.z < CHUNK_COUNT.z

func _density(p: Vector3, digs: Array) -> float:
    # Finite block of rock; each side and bottom are also diggable surfaces.
    var top: float = 0.12 + noise.get_noise_2d(p.x, p.z) * 0.28
    var d: float = top - p.y
    d = minf(d, p.y + 11.55)
    d = minf(d, 11.72 - absf(p.x))
    d = minf(d, 11.72 - absf(p.z))
    for sphere in digs:
        var center: Vector3 = Vector3(sphere.x, sphere.y, sphere.z)
        d = minf(d, p.distance_to(center) - sphere.w)
    return d

func dig_at(surface_point: Vector3, surface_normal: Vector3) -> bool:
    var normal: Vector3 = surface_normal.normalized()
    if normal.length_squared() < 0.5:
        return false
    var center: Vector3 = to_local(surface_point - normal * DIG_INSET)
    var sphere: Vector4 = Vector4(center.x, center.y, center.z, DIG_RADIUS)
    var bounds: Vector3 = Vector3.ONE * (DIG_RADIUS + VOXEL_SIZE)
    var low: Vector3 = center - bounds
    var high: Vector3 = center + bounds
    var k0: Vector3i = Vector3i(
        floori((low.x - ORIGIN.x) / CHUNK_WORLD_SIZE),
        floori((low.y - ORIGIN.y) / CHUNK_WORLD_SIZE),
        floori((low.z - ORIGIN.z) / CHUNK_WORLD_SIZE)
    )
    var k1: Vector3i = Vector3i(
        floori((high.x - ORIGIN.x) / CHUNK_WORLD_SIZE),
        floori((high.y - ORIGIN.y) / CHUNK_WORLD_SIZE),
        floori((high.z - ORIGIN.z) / CHUNK_WORLD_SIZE)
    )
    var changed: bool = false
    for y in range(k0.y, k1.y + 1):
        for x in range(k0.x, k1.x + 1):
            for z in range(k0.z, k1.z + 1):
                var key: Vector3i = Vector3i(x, y, z)
                if not _valid_chunk(key):
                    continue
                var spheres: Array = chunk_digs.get(key, [])
                spheres.append(sphere)
                chunk_digs[key] = spheres
                if not queued_keys.has(key):
                    queued_keys[key] = true
                    dirty_keys.append(key)
                changed = true
    return changed

func _sample_index(x: int, y: int, z: int) -> int:
    return x + (CELLS + 1) * (y + (CELLS + 1) * z)

func _rebuild_chunk(key: Vector3i) -> void:
    if not chunks.has(key):
        return
    var chunk: Dictionary = chunks[key]
    var visual: MeshInstance3D = chunk["visual"]
    var collision: CollisionShape3D = chunk["collision"]
    var digs: Array = chunk_digs.get(key, [])
    var positions: PackedVector3Array = PackedVector3Array()
    var values: PackedFloat32Array = PackedFloat32Array()
    var count: int = (CELLS + 1) * (CELLS + 1) * (CELLS + 1)
    positions.resize(count)
    values.resize(count)
    var origin: Vector3 = _chunk_origin(key)

    for z in range(CELLS + 1):
        for y in range(CELLS + 1):
            for x in range(CELLS + 1):
                var i: int = _sample_index(x, y, z)
                var p: Vector3 = Vector3(x, y, z) * VOXEL_SIZE
                positions[i] = p
                values[i] = _density(origin + p, digs)

    var vertices: PackedVector3Array = PackedVector3Array()
    var normals: PackedVector3Array = PackedVector3Array()
    for z in range(CELLS):
        for y in range(CELLS):
            for x in range(CELLS):
                var ps: Array[Vector3] = []
                var ds: Array[float] = []
                var air_count: int = 0
                for corner in CORNERS:
                    var i: int = _sample_index(x + corner.x, y + corner.y, z + corner.z)
                    ps.append(positions[i])
                    var v: float = values[i]
                    ds.append(v)
                    if v < 0.0:
                        air_count += 1
                if air_count == 0 or air_count == 8:
                    continue
                for tet in TETS:
                    _emit_tetra(tet, ps, ds, vertices, normals)

    if vertices.is_empty():
        visual.mesh = null
        collision.shape = null
        return

    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    var mesh: ArrayMesh = ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    visual.mesh = mesh

    var shape: ConcavePolygonShape3D = mesh.create_trimesh_shape()
    shape.backface_collision = true
    collision.shape = shape

func _emit_tetra(tet: Array, ps: Array[Vector3], ds: Array[float], vertices: PackedVector3Array, normals: PackedVector3Array) -> void:
    var air: Array[int] = []
    var solid: Array[int] = []
    for index in tet:
        if ds[index] < 0.0:
            air.append(index)
        else:
            solid.append(index)
    if air.is_empty() or solid.is_empty():
        return

    var toward_air: Vector3 = Vector3.ZERO
    for index in air:
        toward_air += ps[index] / float(air.size())
    for index in solid:
        toward_air -= ps[index] / float(solid.size())

    if air.size() == 1:
        _emit_triangle(_edge(air[0], solid[0], ps, ds),
            _edge(air[0], solid[1], ps, ds),
            _edge(air[0], solid[2], ps, ds),
            toward_air, vertices, normals)
    elif solid.size() == 1:
        _emit_triangle(_edge(solid[0], air[0], ps, ds),
            _edge(solid[0], air[1], ps, ds),
            _edge(solid[0], air[2], ps, ds),
            toward_air, vertices, normals)
    else:
        var a: Vector3 = _edge(air[0], solid[0], ps, ds)
        var b: Vector3 = _edge(air[0], solid[1], ps, ds)
        var c: Vector3 = _edge(air[1], solid[0], ps, ds)
        var d: Vector3 = _edge(air[1], solid[1], ps, ds)
        _emit_triangle(a, b, c, toward_air, vertices, normals)
        _emit_triangle(b, d, c, toward_air, vertices, normals)

func _edge(i: int, j: int, ps: Array[Vector3], ds: Array[float]) -> Vector3:
    var denominator: float = ds[i] - ds[j]
    var ratio: float = 0.5
    if absf(denominator) > 0.000001:
        ratio = clampf(ds[i] / denominator, 0.0, 1.0)
    return ps[i].lerp(ps[j], ratio)

func _emit_triangle(a: Vector3, b: Vector3, c: Vector3, toward_air: Vector3,
        vertices: PackedVector3Array, normals: PackedVector3Array) -> void:
    var cross: Vector3 = (b - a).cross(c - a)
    if cross.length_squared() < 0.00000001:
        return
    # Godot's front-face winding is clockwise; face the empty (air) side.
    if cross.dot(toward_air) > 0.0:
        var temp: Vector3 = b
        b = c
        c = temp
        cross = -cross
    var outward: Vector3 = (-cross).normalized()
    vertices.append(a)
    vertices.append(b)
    vertices.append(c)
    normals.append(outward)
    normals.append(outward)
    normals.append(outward)
