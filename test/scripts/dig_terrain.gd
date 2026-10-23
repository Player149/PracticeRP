extends Node3D
## DigV2: persistent signed-density voxels, threaded triangle generation,
## shared shader painting the mining ring on the actual surface.

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
var rock_material: ShaderMaterial
var chunks: Dictionary = {}
var chunk_samples: Dictionary = {}
var dirty_keys: Array[Vector3i] = []
var queued_keys: Dictionary = {}
var revisions: Dictionary = {}
var worker: Thread
var working_key: Vector3i = Vector3i.ZERO
var working_revision: int = 0

func _ready() -> void:
    noise.seed = 1974
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    noise.frequency = 0.075
    rock_material = ShaderMaterial.new()
    rock_material.shader = load("res://shaders/voxel_rock.gdshader")
    rock_material.set_shader_parameter("target_active", false)
    rock_material.set_shader_parameter("dig_radius", DIG_RADIUS)

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
                chunk_samples[key] = _create_samples(key)
                revisions[key] = 0
                # Initial world load is synchronous, once. Only mining updates
                # run on a worker thread (no scene-tree calls from that thread).
                _apply_chunk(key, _generate_geometry(chunk_samples[key]) )

func _process(_delta: float) -> void:
    # Never block the main thread waiting for a running worker.
    if worker != null:
        if worker.is_alive():
            return
        var finished: Dictionary = worker.wait_to_finish()
        worker = null
        if int(revisions[working_key]) == working_revision:
            _apply_chunk(working_key, finished)
        elif not queued_keys.has(working_key):
            queued_keys[working_key] = true
            dirty_keys.append(working_key)

    if worker == null and not dirty_keys.is_empty():
        working_key = dirty_keys.pop_front()
        queued_keys.erase(working_key)
        working_revision = int(revisions[working_key])
        # Duplicate the packed samples so edits cannot mutate worker input.
        var snapshot: PackedFloat32Array = chunk_samples[working_key]
        worker = Thread.new()
        var err: Error = worker.start(Callable(self, "_generate_geometry").bind(snapshot.duplicate()))
        if err != OK:
            worker = null
            _apply_chunk(working_key, _generate_geometry(snapshot))

func _exit_tree() -> void:
    if worker != null:
        worker.wait_to_finish()
        worker = null

func set_target(surface_point: Vector3, normal: Vector3) -> void:
    var direction: Vector3 = normal.normalized()
    var center: Vector3 = surface_point - direction * DIG_INSET
    rock_material.set_shader_parameter("dig_center_world", center)
    rock_material.set_shader_parameter("target_active", true)

func clear_target() -> void:
    if rock_material != null:
        rock_material.set_shader_parameter("target_active", false)

func get_preview_radius() -> float:
    return sqrt(DIG_RADIUS * DIG_RADIUS - DIG_INSET * DIG_INSET)

func _chunk_origin(key: Vector3i) -> Vector3:
    return ORIGIN + Vector3(key.x, key.y, key.z) * CHUNK_WORLD_SIZE

func _valid_chunk(key: Vector3i) -> bool:
    return key.x >= 0 and key.y >= 0 and key.z >= 0 \
        and key.x < CHUNK_COUNT.x and key.y < CHUNK_COUNT.y and key.z < CHUNK_COUNT.z

func _density(p: Vector3) -> float:
    # Finite block of rock; each side and bottom are also diggable surfaces.
    var top: float = 0.12 + noise.get_noise_2d(p.x, p.z) * 0.28
    var d: float = top - p.y
    d = minf(d, p.y + 11.55)
    d = minf(d, 11.72 - absf(p.x))
    d = minf(d, 11.72 - absf(p.z))
    return d

func _create_samples(key: Vector3i) -> PackedFloat32Array:
    var samples: PackedFloat32Array = PackedFloat32Array()
    samples.resize((CELLS + 1) * (CELLS + 1) * (CELLS + 1))
    var origin: Vector3 = _chunk_origin(key)
    for z in range(CELLS + 1):
        for y in range(CELLS + 1):
            for x in range(CELLS + 1):
                var p: Vector3 = origin + Vector3(x, y, z) * VOXEL_SIZE
                samples[_sample_index(x, y, z)] = _density(p)
    return samples

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
    # Edit only nearby stored density samples. Unlike a list of historical
    # spheres, work per dig remains almost constant even after many digs.
    var changed: bool = false
    for y in range(k0.y, k1.y + 1):
        for x in range(k0.x, k1.x + 1):
            for z in range(k0.z, k1.z + 1):
                var key: Vector3i = Vector3i(x, y, z)
                if not _valid_chunk(key):
                    continue
                var origin: Vector3 = _chunk_origin(key)
                var samples: PackedFloat32Array = chunk_samples[key]
                var low_x: int = clampi(floori((low.x - origin.x) / VOXEL_SIZE), 0, CELLS)
                var high_x: int = clampi(ceili((high.x - origin.x) / VOXEL_SIZE), 0, CELLS)
                var low_y: int = clampi(floori((low.y - origin.y) / VOXEL_SIZE), 0, CELLS)
                var high_y: int = clampi(ceili((high.y - origin.y) / VOXEL_SIZE), 0, CELLS)
                var low_z: int = clampi(floori((low.z - origin.z) / VOXEL_SIZE), 0, CELLS)
                var high_z: int = clampi(ceili((high.z - origin.z) / VOXEL_SIZE), 0, CELLS)
                var chunk_changed: bool = false
                for iz in range(low_z, high_z + 1):
                    for iy in range(low_y, high_y + 1):
                        for ix in range(low_x, high_x + 1):
                            var p: Vector3 = origin + Vector3(ix, iy, iz) * VOXEL_SIZE
                            var dist: float = p.distance_to(center)
                            if dist >= DIG_RADIUS:
                                continue
                            var index: int = _sample_index(ix, iy, iz)
                            var new_value: float = minf(samples[index], dist - DIG_RADIUS)
                            if new_value < samples[index] - 0.00001:
                                samples[index] = new_value
                                chunk_changed = true
                if not chunk_changed:
                    continue
                chunk_samples[key] = samples
                revisions[key] = int(revisions[key]) + 1
                if not queued_keys.has(key):
                    queued_keys[key] = true
                    dirty_keys.append(key)
                changed = true
    return changed

func _sample_index(x: int, y: int, z: int) -> int:
    return x + (CELLS + 1) * (y + (CELLS + 1) * z)

func _generate_geometry(values: PackedFloat32Array) -> Dictionary:
    # CPU-only work. Safe to run on a worker: no nodes, meshes, or PhysicsServer.
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
                    ps.append(Vector3(x + corner.x, y + corner.y, z + corner.z) * VOXEL_SIZE)
                    var v: float = values[i]
                    ds.append(v)
                    if v < 0.0:
                        air_count += 1
                if air_count == 0 or air_count == 8:
                    continue
                for tet in TETS:
                    _emit_tetra(tet, ps, ds, vertices, normals)

    # Smooth vertex normals from the density gradient rather than per-face
    # normals, so small sphere cuts do not look like abrupt tetrahedral facets.
    if not vertices.is_empty():
        var gradients: PackedVector3Array = PackedVector3Array()
        gradients.resize((CELLS + 1) * (CELLS + 1) * (CELLS + 1))
        for z in range(CELLS + 1):
            for y in range(CELLS + 1):
                for x in range(CELLS + 1):
                    var xp: int = mini(CELLS, x + 1)
                    var xm: int = maxi(0, x - 1)
                    var yp: int = mini(CELLS, y + 1)
                    var ym: int = maxi(0, y - 1)
                    var zp: int = mini(CELLS, z + 1)
                    var zm: int = maxi(0, z - 1)
                    var gradient: Vector3 = Vector3(
                        values[_sample_index(xp,y,z)] - values[_sample_index(xm,y,z)],
                        values[_sample_index(x,yp,z)] - values[_sample_index(x,ym,z)],
                        values[_sample_index(x,y,zp)] - values[_sample_index(x,y,zm)]
                    )
                    gradients[_sample_index(x,y,z)] = -gradient.normalized()
        for i in range(vertices.size()):
            var smooth: Vector3 = _interpolated_normal(vertices[i] / VOXEL_SIZE, gradients)
            if smooth.length_squared() > 0.01:
                normals[i] = smooth.normalized()

    return {"vertices": vertices, "normals": normals}

func _interpolated_normal(p: Vector3, gradients: PackedVector3Array) -> Vector3:
    var x: int = clampi(floori(p.x), 0, CELLS - 1)
    var y: int = clampi(floori(p.y), 0, CELLS - 1)
    var z: int = clampi(floori(p.z), 0, CELLS - 1)
    var f: Vector3 = Vector3(clampf(p.x - x, 0.0, 1.0),
        clampf(p.y - y, 0.0, 1.0), clampf(p.z - z, 0.0, 1.0))
    var n000: Vector3 = gradients[_sample_index(x,y,z)]
    var n100: Vector3 = gradients[_sample_index(x+1,y,z)]
    var n010: Vector3 = gradients[_sample_index(x,y+1,z)]
    var n110: Vector3 = gradients[_sample_index(x+1,y+1,z)]
    var n001: Vector3 = gradients[_sample_index(x,y,z+1)]
    var n101: Vector3 = gradients[_sample_index(x+1,y,z+1)]
    var n011: Vector3 = gradients[_sample_index(x,y+1,z+1)]
    var n111: Vector3 = gradients[_sample_index(x+1,y+1,z+1)]
    var low: Vector3 = n000.lerp(n100, f.x).lerp(n010.lerp(n110, f.x), f.y)
    var high: Vector3 = n001.lerp(n101, f.x).lerp(n011.lerp(n111, f.x), f.y)
    return low.lerp(high, f.z)

func _apply_chunk(key: Vector3i, result: Dictionary) -> void:
    # Renderer and collision server are updated only from the main thread.
    var chunk: Dictionary = chunks[key]
    var visual: MeshInstance3D = chunk["visual"]
    var collision: CollisionShape3D = chunk["collision"]
    var vertices: PackedVector3Array = result["vertices"]
    var normals: PackedVector3Array = result["normals"]

    if vertices.is_empty():
        collision.shape = null
        visual.mesh = null
        return

    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    var mesh: ArrayMesh = ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

    # Only a small chunk's triangle faces are sent to physics after the worker
    # has finished. Collider still matches visuals for passable tunnels.
    var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
    shape.set_faces(vertices)
    shape.backface_collision = true
    collision.shape = shape
    visual.mesh = mesh

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
