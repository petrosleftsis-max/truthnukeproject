---
name: systems-per-creature-not-per-category
description: "User wants combat features as per-creature data switches, not rules tied to a category like \"boss\" or a size"
metadata:
  node_type: memory
  type: feedback
  originSessionId: daf832bf-a3b0-42bb-854e-4dde88e2fdd6
  modified: 2026-10-10T00:58:35.244Z
---

When adding combat systems, make each piece a field any combatant (or passive) can have, chosen per creature in its file, rather than a rule that comes with a category. Asked for bosses (2026-10-10), the user said to make it "more organic": immunities chosen per monster "maybe even normal mobs", bosses that are usually large but can be small, stagger meters "very different depending on the fight" (a mechanic, map objects, burst) with a standard default available.

**Why:** they design encounters by hand and want to mix and match traits freely.

**How to apply:** put new traits on CombatantDefinition / PassiveDefinition / per-fight resources with sensible defaults; keep the "boss" resource to what is truly boss-only (presentation, phases, stagger bar). Offer a standard preset, but never hard-wire one behaviour. Related: [[balance-numbers-are-the-users]].
