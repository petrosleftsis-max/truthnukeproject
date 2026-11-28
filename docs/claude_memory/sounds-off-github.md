---
name: sounds-off-github
description: "The designer's sound effects live on their own Google Drive, not GitHub; never convert them; a \"sword\" sound is still to come"
metadata:
  node_type: memory
  type: project
  originSessionId: 322dee5d-0ec4-44ab-8eeb-9bb32627375c
  modified: 2026-11-06T06:14:16.885Z
---

The designer keeps their sound effects on their own Google Drive (2026-11-06: "if the problem is the github repo, no need to convert them. i'll save the sounds elsewhere"). The wavs are git-ignored and used as they are; only their `.import` files are tracked.

**Why:** the originals are hundreds of MB and would bloat every clone. They asked why I was converting, and did not want quality touched just for GitHub.

**How to apply:** never propose converting or downsampling them for the repo. A new sound goes in `audio/sfx/New folder/` and `tools/sfx_list.txt`, then `tools/place_sfx.ps1`. Remind them what to back up when new ones appear.

They said they will add a "sword" sound later. When it arrives, it goes on what `metallic_scrape` would have been on: Sweep Strike, Chain Hook, Disarm. Do not use `metallic_scrape`, `necromantic_scream`, `pandoras_laugh` or `punchline`. Related: [[placeholder-assets-with-slots]].
