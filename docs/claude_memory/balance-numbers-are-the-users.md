---
name: balance-numbers-are-the-users
description: "The user tunes combat balance (damage, HP, skill numbers) themselves; report balance effects with figures, don't change the numbers or bend tests around them"
metadata:
  node_type: memory
  type: feedback
  originSessionId: daf832bf-a3b0-42bb-854e-4dde88e2fdd6
  modified: 2026-09-26T01:42:30.893Z
---

When a change shifts combat balance (e.g. the Ranger's new kit roughly tripling its damage, 2026-09-26), explain the effect with concrete numbers and leave the tuning to the user. Don't edit skill/combatant numbers, and don't loosen a test scenario (like `archetypes`' wounded Cyrus) so it passes again.

**Why:** the user said they'd playtest and "adjust the numbers myself", and chose to commit with `archetypes` knowingly failing rather than have the scenario changed.

**How to apply:** (user confirmed: before/after tables help them balance.) Fix data bugs (wrong keys, leftover conditions, missing sounds) freely when asked, but for balance, give a before/after table and let the user decide.
