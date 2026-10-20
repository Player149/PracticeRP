# Dig — first-person digging prototype (Godot 4)

Project root: **test/project.godot** (not the repository root).
Main scene: test/scenes/main.tscn.

## Included
- FPS walk, free look, jump and collision.
- Mobile left-stick, right-side camera swipe, JUMP and DIG buttons.
- NO sprinting (removed).
- Each DIG press lowers a round patch of ground: **0.7 units at the brush center**, tapered across a 1.9-unit radius. Repeating digs deepens the crater to a maximum depth of 8 units.
- Both terrain mesh and collision are rebuilt after each dig.
- The map is a lightweight height field; it does NOT support cave tunnels, ceilings, or overhangs yet. No voxels or ore systems yet.

## Controls
Desktop: WASD/arrow keys, mouse to look, click or E to dig, Space to jump, R to respawn, Esc to release cursor.
Mobile: left thumb to move, right half upper swipe to look, JUMP and DIG lower-right.
Point at the ground and dig. If the camera is level, DIG targets soil about 2.6 m in front of the player.

The Godot project runs in the Compatibility renderer for better Android coverage.
