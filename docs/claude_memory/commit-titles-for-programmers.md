---
name: commit-titles-for-programmers
description: "Commit titles and bodies must be clear to a programmer who has NEVER worked on this project: plain technical words, explain the game's own names (SkyLook, FightCards, passives, gates), no poetic phrasing"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 322dee5d-0ec4-44ab-8eeb-9bb32627375c
  modified: 2026-11-26T02:31:15.276Z
---

From 2026-11-26 the designer wants commits named so that a programmer they invite to help can understand them ("make sure you name
the commits in a way that if I invite a programmer to help me out, they can understand what the titles mean"), and clarified: "a
programmer who hasn't worked on this project ever". Earlier titles were in the game's own voice ("How the game feels, part 2: depth,
water, the blow...", "Felled fighters keep the grey").

**Why:** an outsider reading `git log` should know what changed and where without knowing the game or its vocabulary.

**How to apply:** a title under about 72 characters in plain technical terms: an imperative verb, the system, the change (e.g. "Restore
the original UI theme; keep icon-coloured skill-slot borders", "Make the battle intro sequence unskippable and slower"). In bodies,
short bullets grouped by area, each naming the file or class and what it now does, and a few words on any project-specific name the
first time it appears ("FightCards (the overlays that open and close a battle)", "SkyLook (the night-sky UI theme of 2026-11-17)",
"passives (always-on character abilities)"). The designer's words can follow as context, never as the title. Still end with the
Co-Authored-By line. Related: [[commit-means-publish]], [[commit-own-lines-in-shared-folder]].
