---
name: resume-side-sessions-on-continue
description: "When the user says \"continue\" after a usage-limit stop, also message every linked side session to carry on"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 322dee5d-0ec4-44ab-8eeb-9bb32627375c
  modified: 2026-11-19T03:23:24.845Z
---

When the user tells me to continue after the usage limit ran out, I also wake every side session I started (SendMessage to each
`local_…` id from list_sessions {"linked": true}: "your turn stopped on the usage limit; carry on where you left off"). The limit is
the whole account's, so they stop with me; nothing restarts by itself after the reset.

**Why:** the user, 2026-11-19: "If I tell you to continue after usage runs out, tell the other sessions to continue as well."

**How to apply:** on any "continue" that follows a limit stop, check linked sessions first and resume the ones that stopped on it,
alongside my own work. Related: [[never-shut-down-without-permission]].
