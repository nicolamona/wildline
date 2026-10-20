# WILDLINE — Godot prototype

This directory is an isolated Godot 4 prototype on branch `godot-prototype`. The current GitHub Pages game on `main` remains untouched.

## Included in the first scaffold
- Procedural island terrain, water plane, fog, sky, directional lighting and procedural forest.
- First-person movement for keyboard/mouse and basic two-zone touch dragging.
- Resource pickups, outpost/cave mission progression, HUD and local save data.
- Compatibility renderer as a conservative baseline for Android and web export.
- Mobile interaction-button touch area is excluded from the camera-look gesture.

## Automated validation and Android build
GitHub Actions imports/scans the project in Godot 4.4.1, boots the main scene headlessly for 120 frames, and runs `godot/scripts/smoke_test.gd` to assert that the player/camera, forest geometry, collision shapes and interaction button are present. The workflow also attempts to export a debug Android APK and upload it as the `WILDLINE-Android-debug` artifact for 7 days.

Open the latest [Godot workflow run](https://github.com/nicolamona/wildline/actions/workflows/godot-check.yml), then download the APK from the run's **Artifacts** section if the export step succeeds. Install it on an Android test device and check touch movement, camera look, interaction button, collision, visual quality, heat and frame pacing.

A passing headless check or successful APK export does not confirm visual quality, touch usability, or performance on a physical Android device; those require the device test. The debug APK is for testing, not a release build.

## Open the project
Open this directory in Godot 4.x by selecting `godot/project.godot`. The Android export preset is stored in `godot/export_presets.cfg`.

## Save compatibility
The JSON schema preserves the browser build's fields: `version`, `player`, `missionStage`, `taken` and `savedAt`. Godot writes to `user://wildline-save-v1.json`. Importing an existing browser's `localStorage` entry still requires a browser-side migration bridge; the current browser game remains unchanged.

## Remaining work
- Inspect an actual rendered frame and improve the prototype's visual identity.
- Test touch controls and performance on Android; tune vegetation and shadow distance based on real measurements.
- Add final assets, audio and survival drain after the playable slice has been validated.
- Compare the playable slice with the current Three.js version before expanding migration.
