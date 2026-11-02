# Axe Exorcist — editable Godot scene prototype

Branch: `axe-exorcist-prototype`. Import `AxeExorcist/project.godot` using Godot 4.3+ and press F5.

## Scene ownership
- `main.tscn` — WorldEnvironment, Sun, Player instance, SpawnPoints, HUD and Geometry.
- `scenes/player.tscn` — player collider, camera pivot, camera, weapon scene instance.
- `scenes/axe_viewmodel.tscn` — editable blade/handle/grip meshes and placeholder AnimationPlayer.
- `scenes/ghost.tscn` — ghost collider, model and AnimationPlayer.
- `scripts/*.gd` — behavior and combat logic only. Exported values are editable in the inspector.

The graybox arena walls and cover are still generated in `scripts/arena.gd` and should be replaced with hand-authored level geometry next. The HUD and other gameplay nodes are editable in the scene tree. No externally generated asset required.

## Controls
WASD move, mouse look, Space jump, Shift dash, F kick, left mouse click/release to slash, hold 0.32s+ to heavy attack, Esc release mouse.

## Limitations
This is an unverified Godot graybox prototype, not a finished animated game. Axe movement is procedural; there is no enemy navigation, sound, touch controls, execution animation or imported first-person rig. Open it in Godot and share error messages if encountered.
