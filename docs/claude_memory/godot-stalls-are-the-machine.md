---
name: godot-stalls-are-the-machine
description: "When the net suite fails only on \"the joiner's Godot finished by itself\", time an empty project's --quit first; on 2026-11-27 the PC itself stalled every Godot process for minutes"
metadata:
  node_type: memory
  type: project
  originSessionId: 322dee5d-0ec4-44ab-8eeb-9bb32627375c
  modified: 2026-11-27T11:58:38.493Z
---

On 2026-11-27 (after the card-hacking work) the net suite failed twice on one check only, "the joiner's Godot finished by itself"
(the joiner gets 40 s to exit; that morning it took about 12 s). Every one of the joiner's own checks passed. It was not the code:
an empty Godot project (`--headless --path <empty> --quit`) hung for minutes too and needed killing. The stuck process had used
0.08 s of CPU in 50 s, and killing it took minutes, so something in Windows or a driver was blocking it. Reverting the new hacking
scripts did not help either (a trivial session took 15 s, 112 s, 33 s and over 197 s to close).

**Why:** a check that measures process exit time passes or fails with the PC's state, not just the game's.

**How to apply:** if the net suite (or any suite) fails only on timing or exit, run the empty-project quit probe first. If that is
slow too, it is the machine: say so, and re-run after a restart instead of hunting in the code. Kill leftover probe Godots by pid
(see [[stopping-a-test-pass]]).
