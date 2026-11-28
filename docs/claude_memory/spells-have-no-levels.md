---
name: spells-have-no-levels
description: "A spell comes when its gate opens, never by a level of its own; progression.csv's spell levels are ignored by the game"
metadata:
  node_type: memory
  type: user
  originSessionId: 322dee5d-0ec4-44ab-8eeb-9bb32627375c
  modified: 2026-11-06T06:14:20.435Z
---

Spells have no levels of their own (the designer, 2026-11-06: "dont have spells have levels, they come when the gate opens"). Never give a new spell a `required_level`; the `csv` suite refuses it.

**Why:** the gate is the spell's whole progression, so a second number only disagrees with it.

**How to apply:** when suggesting a spell, say its gate, not a level. A path spell also needs the path (level 24). `docs/progression.csv` still lists levels for spells and the game ignores them, which matters when pitching against [[progression-csv-power-level]]. Gates open at the levels in [[gate-ladder-and-level-cap-plan]].
