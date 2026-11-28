---
name: healing-policy
description: "Designer's healing direction (2026-10-24) - mostly flat heals with modest Mindfulness and weapon scaling; share-of-health heals rare; no global heal cap; big boss heals only as explicit mechanics"
metadata:
  node_type: memory
  type: project
  originSessionId: daf832bf-a3b0-42bb-854e-4dde88e2fdd6
  modified: 2026-10-24T14:56:51.137Z
---

The designer's healing decisions of 2026-10-24, after three rounds (docs/healing_and_rest_proposal.md, healing_cap_proposal.md, healing_revision.md):

- **Ordinary heals are mostly flat** (implemented as an APPROVED_TRIAL 2026-10-24 via EffectDefinition heal_flat / heal_per_stat / heal_per_weapon; Mercy I on the whole amount; Mend the Bound as Heal; the Mimic heals from Self; Gate Nades, Medicine, Purification unchanged): Light Heal 8 + 0.15 Mind + 0.2 weapon base; Heal 12 + 0.25 Mind + 0.3 weapon base; Communion as Light Heal, per ally; Restoration 50% of max + 0.25 Mind; Grace full. The share-of-missing-health hybrid was rejected: it helped Enfina far more than Prometheus.
- **Share-of-health healing only on a few rare, limited moves**: high-tier spells, cure potions, Resuscitate, specific boss mechanics. Party share heals (Grace, Restoration) are not capped unless a boss encounter proves a loop.
- **No global heal cap.** The cap document is an OPTIONAL_TUNING_TOOL (a ledger status the designer added). If a boss turns degenerate through healing, use a per-boss cap or condition.
- **Boss big heals only as explicit mechanics**: a mythic trait, phase transition, ritual, or telegraphed action. Limited to once per fight or phase, visible, and interactive (cost or vulnerability window). Mechanics over raw numbers. Mythic full heals stay OPEN until a boss defines one.
- Erysichthon's 6% meal stays as the existing value; fixed-heal / once-a-turn changes are separate PROPOSALs.
- Rest framework kept for testing: 2-3 short rests per segment (50% of missing, no gates), long rest (all), Meditate option A (ceil(level/6) points, shallower half of Prometheus's gates).

**Why:** believability and learnability. One flat Heal should matter most on the fragile, and boss healing should be counterplay, not numbers.
**How to apply:** don't propose global caps or percentage heals for ordinary spells. Frame boss healing as a telegraphed mechanic with a cost. The probe `tests/run.sh healing` regenerates the numbers. Related: [[numbers-are-open-until-playtested]], [[lethality-rule]].
