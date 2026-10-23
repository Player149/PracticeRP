# Dig — 3D Density Voxel Mining (Godot 4)

Open **test/project.godot**, not the repository root, then run F5.

## Playable prototype

- First-person movement, camera look, jump, collision, Android multi-touch controls.
- **Genuine 3D signed-density voxel field:** rock is positive; empty space is negative.
- Spherical mining removes part of the solid rock (not merely lowering a heightmap).
- Chunked 3D terrain: 3 × 2 × 3 chunks; 10 × 10 × 10 cells/chunk; sample spacing 0.8 units.
- Marching tetrahedra extract rocky triangle surfaces; the static collision uses the same generated triangle vertices.
- The **yellow outlined ring** shows the approximate excavation footprint when aiming at rock within **6 units**. The initial camera points down slightly to show the indicator immediately. The reticle also turns yellow while a valid target is acquired.
- On DIG, a sphere of **radius 1.45 units**, recessed 0.52 units into the hit surface, is subtracted from the solid. Walls, floors, and the underside of rock can be excavated.
- Signed-density samples persist per chunk. DIG changes only nearby samples: there is **no growing history of spheres to recompute** on every mesh rebuild. At most one changed chunk is rebuilt per frame.
- Sunlight casts real-time shadows; a low-intensity player flashlight lights new tunnels.

## Controls

- PC: WASD/arrows move, mouse look, click or E dig, Space jump, R respawn, Esc release cursor.
- Mobile: left-hand joystick, upper-right drag to turn, lower-right DIG and JUMP buttons.
- Sprint is deliberately removed.

## Scope and current limitations

- This is a small **bounded** proof of concept, not an infinite voxel world.
- Triangles are flat-shaded and may look faceted at this cell resolution.
- Digging near chunk borders can take a few frames to update the full surface and collision.
- No saved world, inventory, ores, or multiplayer.
- The yellow outline uses a tangent-plane approximation just above the surface, with depth testing disabled so it remains legible on mobile. It is not a precise decal and can hover over highly curved terrain; the actual mining still removes a 3D sphere.
- Triangular collision is still detailed and built synchronously for each changed chunk, so some hitching can remain on mobile. This requires an on-device profiler test before choosing collision simplification / threaded meshing.
- On-device Godot performance and runtime compatibility still need testing.

## Main files

- `test/scripts/dig_terrain.gd` — signed density, spherical subtraction, chunk meshes and collisions.
- `test/scripts/player.gd` — raycast targeting, projected dig preview and first-person movement.
- `test/scripts/touch_ui.gd` — mobile joystick, DIG and JUMP.
- `test/scenes/main.tscn` — main world, lights, obstacles, player.
