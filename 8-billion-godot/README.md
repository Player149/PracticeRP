# 8 BILLION — Godot 4 modular prototype

Open **this folder** as a Godot 4.3+ project (import `project.godot`), then run `main.tscn` with F5.

## Controls
- A / D: move
- W / Space: jump
- J: attack
- K: heavy attack
- L: dash
- E: enter / exit a building
- R: restart

## Architecture
- `main.tscn`: world composition, ground collision, camera, HUD
- `scripts/world/world.gd`: spawning, combat targeting, score and building transitions
- `scenes/actors/player.tscn` + `scripts/actors/player.gd`: independent player controller
- `scenes/actors/human.tscn` + `scripts/actors/human.gd`: configurable civilians, soldiers, grenadiers
- `scenes/world/building.tscn` + `scripts/world/building.gd`: destructible buildings
- `scenes/world/interior.tscn`: reusable interior backdrop and core art
- `scenes/world/projectile.tscn` + `scripts/world/projectile.gd`: bullets and grenades
- `scenes/ui/hud.tscn` + `scripts/ui/hud.gd`: HUD
- `assets/`: original SVG character and environment placeholders; Godot imports them as textures.

## Prototype limitations
No external plugins. This is a refactored playable-design prototype, not a tested release. It has not been run through a Godot executable in this environment. The city uses one flat ground plane; interiors are simple separate zones; animations and advanced crowd behaviors remain future work. `main.gd` at project root is the archived earlier monolithic script and is not used by the current main scene. The older `8-billion/index.html` remains a separate web prototype.

## Next steps
Test with Godot 4.3+ and inspect the editor debugger, then refine collision, performance, interior combat and mobile controls.
