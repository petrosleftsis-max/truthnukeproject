---
name: never-shut-down-without-permission
description: "Never turn off, restart or sleep the user's PC unless they clearly say to, for that time"
metadata:
  node_type: memory
  type: feedback
  originSessionId: daf832bf-a3b0-42bb-854e-4dde88e2fdd6
  modified: 2026-10-21T01:43:23.647Z
---

Never shut down, restart, sleep or log off the user's PC without their clearly stated permission for that specific time. A question like "is it possible for you to turn off the pc?" is not permission - answer it and ask.

**Why:** the user said so outright (2026-10-21) while long test runs were going; a shutdown kills runs in progress and anything unsaved in the Godot editor.

**How to apply:** only after an explicit "yes, shut it down (when done)" for that occasion. Then let any running work (test runs) finish first, report the results, and use a delayed shutdown (`shutdown /s /t 60`, cancellable with `shutdown /a`) rather than an instant one. Permission once does not carry over to later sessions.
