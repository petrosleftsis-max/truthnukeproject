---
name: ui-screenshot-workflow
description: "How to see the game's UI for real - headless tests cannot show layout; run a driver in a real window from a project copy and save PNGs"
metadata:
  node_type: memory
  type: reference
  originSessionId: daf832bf-a3b0-42bb-854e-4dde88e2fdd6
  modified: 2026-11-19T08:54:59.332Z
---

Headless suites (tests/run.sh) prove behaviour but not layout. To look at the UI:

1. tar the project into a scratch folder, excluding .git, export, tests, .godot and audio/music/*.wav.
2. Drop a driver script in its root and register it in the copy's project.godot as autoload `T="*res://<driver>.gd"` right after the `Actors=` line; also add `config/use_custom_user_dir=true` + a custom dir name after `config/name=` so it never touches the player's user://.
3. `Godot_v4.7.2-stable_win64_console.exe --headless --path <copy> --import`, then run it **without** --headless.
4. In the driver: build scenes (e.g. game.tscn with Campaign.current_encounter set), stage the state, then `get_viewport().get_texture().get_image().save_png(path)`; read the PNGs back.

Never warp the mouse (it moves the user's real cursor) - place hover cards/prompts by setting global_position instead.
A reusable copy lives at the scratchpad's `shotcopy/`: refresh it with a tar that EXCLUDES project.godot (keeps the T autoload), then point `T=` at the new driver. Because its project.godot is kept, any autoload added to the real project since (e.g. `Pictures`, 2026-09-26) must be added to the copy by hand - before `Actors=`, with the dialogue state shortcut too.
A fresh import once exited 139 (segfault) and the rerun was clean - retry once before chasing it. See [[godot-path-this-machine]].

On a map, `party.teleport(to)` moves the party but not the camera (only walking tells it), so a driver calls `scene._follow_camera(to)` after each teleport and waits a second for the soft view to ease there - else every later shot is of where the party started (2026-11-19). The tar can also copy the real project.godot and re-add the custom user dir and `T=` with awk after `config/name=` and `Net=` (the wander shots did), which avoids hand-adding new autoloads. Set `Pad.warps = false` and `process_mode = ALWAYS` on the driver, and use timers made with `process_always` so waits run under a menu's pause.
