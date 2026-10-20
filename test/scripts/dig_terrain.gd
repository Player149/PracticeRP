extends StaticBody3D
## Height-field digging prototype: each click removes a fixed depth of soil.
## No cube blocks, cave ceilings, tunnels, or voxel overhangs yet.

const CELLS: int = 80
const SPACING: float = 0.8
const BRUSH_RADIUS: float = 1.9
const DIG_DEPTH: float = 0.7
const MAX_DEPTH: float = 8.0

@onready var ground_visual: MeshInstance3D = $GroundVisual
@onready var ground_collision: CollisionShape3D = $GroundCollision

var heights: PackedFloat32Array = PackedFloat32Array()
var rebuild_pending: bool = false

func _ready() -> void:
    collision_layer = 1
    heights.resize((CELLS + 1) * (CELLS + 1))
    heights.fill(0.0)
    _rebuild()

func _index(x: int, z: int) -> int:
    return z * (CELLS + 1) + x

func _get_height(x: int, z: int) -> float:
    var ix: int = clampi(x, 0, CELLS)
    var iz: int = clampi(z, 0, CELLS)
    return heights[_index(ix, iz)]

func _grid_pos(x: int, z: int) -> Vector3:
    var wx: float = (float(x) - float(CELLS) * 0.5) * SPACING
    var wz: float = (float(z) - float(CELLS) * 0.5) * SPACING
    return Vector3(wx, _get_height(x, z), wz)

func _grid_normal(x: int, z: int) -> Vector3:
    return Vector3(
        _get_height(x - 1, z) - _get_height(x + 1, z),
        2.0 * SPACING,
        _get_height(x, z - 1) - _get_height(x, z + 1)
    ).normalized()

func dig_at(world_point: Vector3) -> bool:
    var local_point: Vector3 = to_local(world_point)
    var changed: bool = false
    var radius_squared: float = BRUSH_RADIUS * BRUSH_RADIUS
    var min_x: int = clampi(floori((local_point.x - BRUSH_RADIUS) / SPACING + float(CELLS) * 0.5), 0, CELLS)
    var max_x: int = clampi(ceili((local_point.x + BRUSH_RADIUS) / SPACING + float(CELLS) * 0.5), 0, CELLS)
    var min_z: int = clampi(floori((local_point.z - BRUSH_RADIUS) / SPACING + float(CELLS) * 0.5), 0, CELLS)
    var max_z: int = clampi(ceili((local_point.z + BRUSH_RADIUS) / SPACING + float(CELLS) * 0.5), 0, CELLS)
    for z in range(min_z, max_z + 1):
        for x in range(min_x, max_x + 1):
            var p: Vector3 = _grid_pos(x, z)
            var dx: float = p.x - local_point.x
            var dz: float = p.z - local_point.z
            var dist_squared: float = dx * dx + dz * dz
            if dist_squared >= radius_squared:
                continue
            var falloff: float = 1.0 - sqrt(dist_squared) / BRUSH_RADIUS
            var amount: float = DIG_DEPTH * falloff
            var index: int = _index(x, z)
            var new_height: float = maxf(-MAX_DEPTH, heights[index] - amount)
            if new_height < heights[index] - 0.0001:
                heights[index] = new_height
                changed = true
    if changed and not rebuild_pending:
        rebuild_pending = true
        call_deferred("_rebuild")
    return changed

func _rebuild() -> void:
    rebuild_pending = false
    var vertices: PackedVector3Array = PackedVector3Array()
    var normals: PackedVector3Array = PackedVector3Array()
    var indices: PackedInt32Array = PackedInt32Array()
    for z in range(CELLS + 1):
        for x in range(CELLS + 1):
            vertices.append(_grid_pos(x, z))
            normals.append(_grid_normal(x, z))
    for z in range(CELLS):
        for x in range(CELLS):
            var a: int = _index(x, z)
            var b: int = _index(x, z + 1)
            var c: int = _index(x + 1, z)
            var d: int = _index(x + 1, z + 1)
            indices.append(a)
            indices.append(b)
            indices.append(c)
            indices.append(c)
            indices.append(b)
            indices.append(d)
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_INDEX] = indices
    var mesh: ArrayMesh = ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    ground_visual.mesh = mesh
    var terrain_shape: ConcavePolygonShape3D = mesh.create_trimesh_shape()
    terrain_shape.backface_collision = true
    ground_collision.shape = terrain_shape
