---
name: autoloads-need-editor-reload
description: "Adding an autoload by editing project.godot while the user's Godot editor is open breaks their editor until they reload the project; editor-run (@tool) scripts must not name a new autoload directly"
metadata:
  node_type: memory
  type: feedback
  originSessionId: daf832bf-a3b0-42bb-854e-4dde88e2fdd6
  modified: 2026-09-26T18:24:30.015Z
---

On 2026-09-26 the `Pictures` autoload went into project.godot by hand while the user's Godot editor was open. The editor kept its stale settings. Every @tool script that named `Pictures` failed with "Identifier not declared", and the editor could also save its old settings back over the file.

**Why:** Godot's editor holds project settings in memory and does not re-read project.godot when it changes on disk.

**How to apply:**
- After adding an autoload (or any project.godot edit), tell the user to do Project -> Reload Current Project before changing any setting.
- In `@tool` scripts, reach new autoloads with `get_node_or_null("/root/Name")` rather than the bare name.
- Autoloads go before `Actors=` in the list, because `tests/run.sh` inserts each test driver after that line.
