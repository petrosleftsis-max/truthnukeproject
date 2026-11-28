---
name: godot-path-this-machine
description: "Where Godot 4.7.2 and its export templates live on this machine, and how the repo's scripts find it"
metadata:
  node_type: memory
  type: reference
  originSessionId: daf832bf-a3b0-42bb-854e-4dde88e2fdd6
  modified: 2026-10-29T19:26:26.719Z
---

Godot 4.7.2 (the latest stable as of 2026-09-24) is at `E:\Godot\` - both the main exe and the `_console` wrapper. Since 2026-09-24 the repo's `tools/find_godot.sh` (shared by `tests/run.sh`, `tests/run_packed.sh`, `tools/release.sh`) checks `$GODOT`, then PATH, then `/e/Godot/...` and the other machine's `Downloads\...` path, so `tests/run.sh` works with no `GODOT=` prefix here.

The 4.7.2 export templates were downloaded and installed into `%APPDATA%\Godot\export_templates\4.7.2.stable` with the user's permission on 2026-09-24 (only 4.7.1's were there before). `export_presets.cfg` (git-ignored) was written by hand. Since 2026-10-29 the scripts name three presets: "Windows Desktop", "Linux" and "macOS" (added by hand that day; the old "Web" preset is still in the file, unused). A backup from before the Mac/Linux change is in that session's scratchpad. No WSL distro and no real Python on this PC (python.exe is the Store stub), so Linux builds can't be launched here.

See also [[truthnuke-clone-line-endings]].
