# Dig — first-person movement (Godot 4)

## Current state
A playable **3D first-person movement sandbox** lives under `test/`. This is **not yet a digging game**: mining, ores and terrain deformation are deliberately excluded until movement works well on the target device.

## Open in Godot
1. Check out the `Dig` branch.
2. In Godot 4, import **`test/project.godot`** (do not import the repository root).
3. Run the project (F6 for open scene or F5 for project).

The startup scene is `test/scenes/main.tscn`. It contains the camera, static ground with collision, platforms/pillars with collision and light, so it should render even before player code runs.

## Controls
PC: WASD / arrow keys — move; mouse — camera; Shift — run; Space — jump; R — reset; Esc — release/capture mouse; left-click — recapture mouse.

Mobile: drag on the left — move; drag on the upper-right — look; on-screen JUMP — jump; hold RUN — sprint. Supports separate fingers for moving and looking.

## Technical notes
- Godot 4, GL Compatibility renderer (chosen for broad Android support).
- No add-ons, external assets, AI, multiplayer or voxel terrain required.
- Code: `test/scripts/player.gd`, `test/scripts/touch_ui.gd`.
- Scene: `test/scenes/main.tscn`.
- For validation, test both editor run and on-device mobile touch controls.
