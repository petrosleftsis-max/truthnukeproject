---
name: truthnuke-clone-line-endings
description: "Why stealth and mend failed on a fresh Windows clone, and how it was fixed for good (2026-09-24)"
metadata:
  node_type: memory
  type: project
  originSessionId: daf832bf-a3b0-42bb-854e-4dde88e2fdd6
  modified: 2026-09-24T15:22:25.459Z
---

The global git config here has `core.autocrlf=true`. Before 2026-09-24 the repo had no `.gitattributes`, so a Windows checkout turned the test drivers' multi-line string literals (`split("<newline>")`) into `"\r\n"`, and `stealth` (4 FAILs) and `mend` (index -2 script error) failed.

**Why:** the tooltips only use `\n`, so splitting on `"\r\n"` finds nothing.

**How to apply:** fixed in commit 14a8d50 with `.gitattributes` (`* text=auto eol=lf`), which wins over any local autocrlf setting. This clone also has repo-local `core.autocrlf=false`. If those suites fail with this shape again on some other checkout, check for CRLF first. Note Git Bash's `grep`/`sed`/`cat -A` hide `\r`; count with `tr -cd '\r' < file | wc -c` or read bytes in PowerShell.

Related: [[godot-path-this-machine]].
