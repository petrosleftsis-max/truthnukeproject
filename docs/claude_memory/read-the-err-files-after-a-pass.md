---
name: read-the-err-files-after-a-pass
description: "tests/run.sh marks script errors on an otherwise clean line; filtering out \": exit=0 FAILURES: 0\" hides them, so list *_err.txt after every pass"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 322dee5d-0ec4-44ab-8eeb-9bb32627375c
  modified: 2026-11-07T05:34:57.943Z
---

After a full pass of `tests/run.sh`, list `<logs>/*_err.txt` as well as reading the summary. A suite with script errors but passing checks prints `name : exit=0 FAILURES: 0 (FAIL lines: 0) [SCRIPT ERRORS: n]`, and the usual `grep -v ": exit=0 FAILURES: 0"` removes that line too. The runner copies `_err.txt` to `<suite>_err.txt` only when there were script errors; plain `_err.txt` is just the last suite's scratch file.

**Why:** on 2026-11-07 a real error (`zone_tiles` reading `zone.condition` on a zone without one, 48 times in `projectile`) got past one pass that way and into a commit before the next pass's file listing showed it.

**How to apply:** clear `*_err.txt` before a pass and list what appears after it, or filter with `grep -v "FAILURES: 0 (FAIL lines: 0)$"` so that lines with the note survive.

Also: headless runs here sit at about 144 frames a second whatever the load, and fights in `tests/probes/aicompare` are bound by frames. So its numbers came out the same beside a full pass as alone; a both-sides fight that doesn't finish is cut off by the probe's clock (`MOST_SECONDS`), and its "ended by" says so. Don't read a cut-off fight as a loss.
