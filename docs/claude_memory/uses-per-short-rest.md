---
name: uses-per-short-rest
description: "Designer 2026-10-24 - use limits recover per short rest (not per fight); triggers stay per fight; short/long rest plug-in built, rest details still to come; Tremor/Titanfall/Dazed control trial"
metadata:
  node_type: memory
  type: project
  originSessionId: daf832bf-a3b0-42bb-854e-4dde88e2fdd6
  modified: 2026-10-24T16:46:15.437Z
---

Designer's rule (2026-10-24, APPROVED_TRIAL): any **use limit** ("once a fight", Uses Per Fight) recovers on a **short rest**; a long rest restores all. **Trigger conditions** (first hit on each enemy in a fight, first blow taken, first attack each round), durations to the fight's end, and boss phase / stagger / encounter effects stay per fight or round. Built as `Combat.SPENT_UNTIL_REST` + `Campaign.short_rest` / `long_rest` (carried between a dungeon's fights like gates; every fight elsewhere starts fresh). The audit is docs/per_fight_audit.md.

Open: the Trapper's free Small Bomb ("to hand in every fight") is ambiguous and left per fight. The user said they will **follow up with details on the short and long rest** (health, gates, how many per segment); On 2026-10-25 the short rest was built for the lab (DungeonDefinition.short_rests): 50% of missing health to the standing (SHORT_REST_MENDS, PROPOSAL), uses back, no gates; the fallen stay down unless Resuscitated at the rest (Alithia, a Pandora+ casting, 50% health, 10% weaker). A full rest (rest_party in other dungeons) still heals to full. Long rest beyond uses: still the user's to detail.

Same day, the control trial: Titanfall no shove; Tremor keeps shoving the struck target (user's answer) and dazes on any shove of hers into something solid (user's answer); the step after a Tremor hit is automatic and free, provoking nothing (user: choosing every turn would tire the player); Dazed is a PROPOSAL test value; Stunning Blow 1/2/3 uses a short rest at 41/54/64.

**Why:** the designer wants control to be a deliberate spend, and per-fight limits to mean the same resource as gates.
**How to apply:** new limited skills or passives get Uses Per Short Rest (or join SPENT_UNTIL_REST), never a per-fight counter, unless they are triggers. When the rest details arrive, extend `short_rest` / `long_rest` rather than `rest_party`. Related: [[healing-policy]], [[numbers-are-open-until-playtested]].
