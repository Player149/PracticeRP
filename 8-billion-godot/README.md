# 8 BILLION — Godot 4 dummy test

Open this folder's `project.godot` in Godot 4.3+.

## Current scope
- Eyeless, squat, black alien monster with a wide permanent toothy grin (original SVG in `assets/characters/shadow.svg`).
- A/D move, Space jump, left mouse click attack. No other gameplay bindings.
- Only stationary human training dummies, randomly positioned in the level.
- Buildings, interiors, soldiers, grenades, projectiles and other enemy behaviors are **not part of the active scene**.
- Adjust movement speed while playing using the HUD slider (50–1200); set `starting_player_speed` and `dummy_count` on the Main node in the Inspector for defaults.

## Project layout
`main.tscn` composes Player, Crowd, Ground and HUD.
`scripts/actors/player.gd` owns player controls.
`scripts/actors/human.gd` owns dummy damage.
`scripts/world/world.gd` spawns dummies and resolves hits.
`scripts/ui/hud.gd` owns speed slider and counters.
Original editable SVG assets are in `assets/`.

## Legacy files
The earlier building/projectile scripts and scenes remain in the repository as **unused legacy assets**, but are not loaded by `main.tscn`. The old root `main.gd` is also unused.

The Godot runtime was not available for automated execution testing. Verify in Godot editor and report any parser errors.
