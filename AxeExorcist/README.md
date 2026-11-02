# Axe Exorcist (Godot 4) — playable graybox v0.1

Standalone Godot project nested in the PracticeRP repository, isolated on the `axe-exorcist-prototype` branch. No external 3D models, textures, plugins or AI keys are required.

## Run
1. Install Godot 4.3+ (desktop, Compatibility renderer).
2. Check out branch `axe-exorcist-prototype`.
3. In Godot Project Manager select **Import** and open `AxeExorcist/project.godot`.
4. Press F6/F5 or the Run Project button. Click the game to capture mouse.

## Controls
- WASD move; mouse look; Space jump.
- Left mouse quick press/release: axe slash. Repeat for next attacks.
- Hold left mouse 0.32 seconds then release: heavy strike.
- Left Shift: dash, two charges; replenishes over time.
- F: short range kick; Escape: release mouse.
- Slay ghosts to replenish 8 HP. Ghosts respawn periodically.

## Contents
- `scripts/arena.gd`: procedural arena, cover, lighting, ghosts, HUD.
- `scripts/player.gd`: movement, dash, jump, axe viewmodel and attacks, cone hit detection, health.
- `scripts/ghost.gd`: chasing enemy, stagger/knockback, attacks.
- `main.tscn`: single startup scene.

## Current limitations
This is an asset-free graybox combat prototype, not an animated release build. The axe is assembled from box primitives; its swing is procedural rather than a Blender skeleton animation. Ghosts are capsule placeholders, move directly toward the player and can get stuck behind cover (no navigation mesh). There is no gore, finishers, mobile touch UI or audio yet. Enemy and hit-detection code is intentionally lightweight. Engine execution has not been verified in the connected GitHub environment.

## Next milestones
1. Test actual feel, tune hit timings, move speed and dash cooldown.
2. Replace models with Meshy/Blender glTF and build first-person arm rig.
3. Add AnimationPlayer/AnimationTree attack animations and hit-stop.
4. Navigation, enemy telegraphs, finishers, sound, particle impact feedback.
5. Implement touch controls for Android once desktop gameplay feels good.
