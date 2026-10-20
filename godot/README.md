# WILDLINE — Godot prototype

This directory is an isolated Godot 4 prototype on branch godot-prototype. The current GitHub Pages game on main remains untouched.

## Included in the first scaffold
- Procedural island terrain, water plane, fog, sky, directional lighting and procedural forest.
- First-person movement for keyboard/mouse and basic two-zone touch dragging.
- Resource pickups, outpost/cave mission progression, HUD and local save data.
- Compatibility renderer as a conservative baseline for Android and web export.

## Open the project
Open this directory in Godot 4.x by selecting godot/project.godot.

## Important status
This is an initial scaffold, not a verified release. It has not yet been opened or run in the Godot editor. Final assets, polished touch controls, audio, survival drain and export presets remain future tasks.

## Save compatibility
The JSON schema preserves the browser build's fields: version, player, missionStage, taken and savedAt. Godot writes to user://wildline-save-v1.json. Importing an existing browser's localStorage entry still requires a browser-side migration bridge; the current browser game remains unchanged.

## Next validation steps
1. Open and run the scene in Godot 4.x and fix parser/runtime issues.
2. Validate player collision and terrain.
3. Test on Android and tune vegetation/shadow distance.
4. Add export presets only after the prototype passes first checks.
5. Compare the playable slice with the current Three.js version before expanding migration.
