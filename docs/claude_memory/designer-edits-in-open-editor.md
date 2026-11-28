---
name: designer-edits-in-open-editor
description: "The designer works in an open Godot editor while I work; their .tres changes are theirs to keep and commit; a new imported file (.dialogue, .png) stays unimported until the editor rescans, which blacked out a whole map once"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 322dee5d-0ec4-44ab-8eeb-9bb32627375c
  modified: 2026-11-06T17:54:50.476Z
---

The designer keeps Godot open on the project and changes data by hand while I work (2026-11-07: tethers, Mesmerise's contest stat and radius, Seeming's Iris gate). Those show up as uncommitted `.tres` changes, mixed with the editor's own reshuffling of lines and uids.

**Why:** they are design decisions, and silently dropping them or being surprised by them breaks what they just set. One of them changed behaviour by accident too: `outside_gate` on Seeming made `use_of` read it as Invisibility until that was fixed.

**How to apply:** at the start of a piece of work read `git diff` for values, not just file names, and say in the closing message which of their changes I saw. Keep them and commit them with my work. Run builders and tools in a scratch copy, as `tests/run.sh` and my probes do, and bring back only the new files, so the open editor is not fought with. Tell them to reload if I changed a script or a resource they may have open.

**New imported files:** my scratch copies run `--import`, so they hide this. The open editor only imports on its next scan, so a new `.dialogue` or `.png` has no `.import` there and anything naming it fails to load. The Light stage's map failed that way on 2026-11-07: the whole map missing, black, with the party walking on top. When adding one, copy its `.import` and its `.godot/imported/` files back from the scratch copy, and check their log first if they report something odd: `%APPDATA%/Godot/app_userdata/Messengers of Truth/logs/godot.log`.
