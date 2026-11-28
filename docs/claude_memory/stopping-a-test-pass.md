---
name: stopping-a-test-pass
description: "TaskStop on a backgrounded tests/run.sh, or an outer timeout round it, leaves Godot running and a .run.lock folder behind; kill by pid and rm -rf the lock; no outer timeout on run.sh"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 322dee5d-0ec4-44ab-8eeb-9bb32627375c
  modified: 2026-11-19T20:38:49.768Z
---

Stopping a background full pass with TaskStop kills only the outer bash. The `tests/run.sh` bash, its `timeout.exe` and the harness Godot
(two processes: `_console.exe` and the plain `.exe`) keep going and start the next suite. And the runner's lock is a **folder**,
`$MOT_TEST_WORK/.run.lock`, which stays behind, so the next run says "Another run is already going" and ends at once.

**Why:** 2026-11-12, a stale pass kept respawning suites after TaskStop, then two restarts failed on the leftover lock (`rm -f` on a folder).

**How to apply:** find them with PowerShell `Get-CimInstance Win32_Process` filtered on `tests/run.sh` and the work folder's `copy` path,
kill those pids only (never the designer's Godot, which runs from Downloads or the Project Manager), check none are left, then
`rm -rf "$MOT_TEST_WORK/.run.lock"` before starting again. Related: [[read-the-err-files-after-a-pass]].

**An outer `timeout N tests/run.sh ...` does the same** (2026-11-19): it kills only run.sh, so the summary never prints and the later
suites never start, while the running suite's Godot goes on to the end of its own cap and writes its full result file; the lock
stays. `sweep` alone takes about 20 minutes (its own cap is 1500 s). So put no outer timeout on run.sh (each suite has its own),
and if one cut it off, read the suite's `logs/<suite>_test_result.txt` and err file once its Godot has exited, then clear the lock.
