# WILDLINE — Godot prototype

This directory is an isolated Godot 4 prototype on branch `godot-prototype`. The current GitHub Pages game on `main` remains untouched.

## Included in the first scaffold
- Procedural island terrain, water plane, fog, sky, directional lighting and procedural forest.
- First-person movement for keyboard/mouse and basic two-zone touch dragging.
- Resource pickups, outpost/cave mission progression, HUD and local save data.
- Compatibility renderer as a conservative baseline for Android and web export.

## Validation status
- GitHub Actions reports a successful run for the automated headless validation workflow.
- The workflow imports/scans the project in Godot 4.4.1 and boots the main scene headlessly for 120 frames.
- A green CI result is a useful technical check, but it does not confirm visual quality, touch usability, or performance on a physical Android device.
- This is still an initial scaffold, not a verified release. Final assets, polished touch controls, audio, survival drain and export presets remain future tasks.

## Open the project
Open this directory in Godot 4.x by selecting `godot/project.godot`.

## Save compatibility
The JSON schema preserves the browser build's fields: `version`, `player`, `missionStage`, `taken` and `savedAt`. Godot writes to `user://wildline-save-v1.json`. Importing an existing browser's `localStorage` entry still requires a browser-side migration bridge; the current browser game remains unchanged.

## Next validation steps
1. Capture and inspect a playable frame from the Godot scene.
2. Validate player collision, terrain and interaction flow.
3. Test touch controls and performance on Android; tune vegetation and shadow distance.
4. Add export presets only after the playable slice passes these checks.
5. Compare the playable slice with the current Three.js version before expanding migration.
