---
name: move-feel-proposals-pending
description: "Move feel built 2026-10-31 (MoveFeel.gd + Projectile looks), all but from-above/below which the designer refused; every timing is PROPOSAL"
metadata:
  node_type: memory
  type: project
  originSessionId: 322dee5d-0ec4-44ab-8eeb-9bb32627375c
  modified: 2026-10-30T23:40:09.893Z
---

2026-10-30 the designer said "do everything not done and suggested, except ... moves that come down from above (hammers, suns) or up from below (spikes)". So everything in docs/move_feel_proposals.md was built 2026-10-31 (commit 4ab62d2): combat/MoveFeel.gd, the new Projectile looks/styles (Beam, Spray, Back To User), SkillDefinition hand_look / projectile_look / impact_look / ground_mark / travel_sound / impact_sound, Combat hooks (CLAUDE.md "Projectiles"), suite `projectile`. From-above/from-below styles are deliberately absent (ledger row "Move feel: from above, from below"); don't add them unless the designer asks.

**Why:** the designer approved the list; they make the real art and sound themselves ([[placeholder-assets-with-slots]]).

**How to apply:** every timing/size in it (hit-stop thresholds, shake, slow motion 0.3 s at 40%, mark rounds, look durations) is a PROPOSAL in the ledger - change only when the designer says. Nothing visual may roll on Combat.rng (network replay). Visual tuning work can run at lower effort ([[say-when-effort-can-drop]]).
