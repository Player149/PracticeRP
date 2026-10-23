# Dig — 3D Density Voxel Mining (Godot 4)

Open **test/project.godot**, not the repository root, then run F5.

## Playable prototype

- First-person movement, camera look, jump, collision, Android multi-touch controls.
- **Genuine 3D signed-density voxel field:** rock is positive; empty space is negative.
- Spherical mining removes part of the solid rock (not merely lowering a heightmap).
- Chunked 3D terrain: 3 × 2 × 3 chunks; 10 × 10 × 10 cells/chunk; sample spacing 0.8 units.
- Marching tetrahedra extract rocky triangle surfaces; triangle collisions are rebuilt with the edited surface.
- The **yellow outlined ring** is projected onto the terrain in range and indicates the approximate visible excavation footprint. It disappears unless the crosshair points at mineable rock within **6 units**.
- On DIG, a sphere of **radius 1.45 units**, recessed 0.52 units into the hit surface, is subtracted from the solid. Walls, floors, and the underside of rock can be excavated.
- At most one changed chunk is rebuilt each frame to spread work across mobile frames.
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
- The yellow outline projects a ring onto the visible surface. On highly irregular walls, the precise volumetric cut can differ slightly from that approximation.
- On-device Godot performance and runtime compatibility still need testing.

## Main files

- `test/scripts/dig_terrain.gd` — signed density, spherical subtraction, chunk meshes and collisions.
- `test/scripts/player.gd` — raycast targeting, projected dig preview and first-person movement.
- `test/scripts/touch_ui.gd` — mobile joystick, DIG and JUMP.
- `test/scenes/main.tscn` — main world, lights, obstacles, player.
