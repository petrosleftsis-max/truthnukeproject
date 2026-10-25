# Finisher removal and Momentum–Sweep Strike synergy

**Status:** APPROVED_DESIGN / APPROVED_TRIAL  
**Date:** 2026-10-25  
**Owner:** Designer  
**Implementer:** Claude

## Decision

1. **Remove Finisher** from Enfina's kit and from the game.
2. **Extend Momentum I** so it also applies to **Sweep Strike**.
3. Apply the agreed **new numbers and ranks for non-spell moves** below.

## 1. Remove Finisher

- Remove `finisher` from Enfina's skill list and any enemy copies or references.
- Remove `data/skills/enfina/finisher.tres` (or the equivalent skill resource).
- Remove the `Only Below Health` mechanic reference if Finisher is its only user.
- Update the progression plan and combat context so Enfina's level-54 row lists only **Sweep Strike**.

**Reason:** Titanfall at level 64 is ×3.0 with a ×1.5 splash and no health restriction, so it strictly outpaces Finisher (×2.2, only on targets at ≤50% health). The execute identity is redundant.

## 2. Momentum I applies to Sweep Strike

- **Momentum I** remains: +10% damage on a turn Enfina has not walked.
- Add: this bonus also applies to **Sweep Strike**.
- At level 54, a planted Enfina therefore deals **×1.54** with Sweep Strike instead of ×1.4.
- Do **not** extend this to **Leading Charge**; Momentum is the "stood still" payoff and Leading Charge is its opposite.

## 3. New numbers and ranks for non-spell moves

Apply these to the non-spell skills and ranks discussed earlier. Spells are unchanged.

### Enfina — non-spell moves

| Move | Level | Before | After |
|---|---:|---|---|
| Greatsword Attack | 1 | ×1.0 | ×1.0 (unchanged) |
| Greatsword Attack — Heavy Swing rank | 8 | ×1.5 | ×1.5 (unchanged) |
| Guard | 1 | Defense buff, 1 turn | Unchanged |
| Battle Cry | 16 | ×0.6 cone, push 1 | ×0.6 cone, push 1 (unchanged) |
| Armor Shred | 24 | ×0.9, −20% Defense, 2 turns | ×0.9, −20% Defense, 2 turns (unchanged) |
| Follow Up Attack | 32 | ×1.5 secondary | ×1.5 secondary (unchanged) |
| Stunning Blow | 41 | ×0.8, Stun 1 turn | ×0.8, Stun 1 turn (unchanged) |
| Sweep Strike | 54 | ×1.4 line, push | ×1.4 line, push; Momentum I now applies |
| Greatsword Attack — Titanfall rank | 64 | ×3.0, ×1.5 splash within 2, shove 1 | ×3.0, ×1.5 splash within 2, shove 1 (unchanged) |
| Momentum I | 32 | +10% on a turn not walked | +10% on a turn not walked, **including Sweep Strike** |
| Momentum II | 64 | +15% on a turn not walked | +15% on a turn not walked, **including Sweep Strike** |
| Finisher | 54 | ×2.2, only ≤50% HP | **Removed** |

### Cyrus — non-spell moves

| Move | Level | Before | After |
|---|---:|---|---|
| Gun | 1 | ×1.0 | ×1.0 (unchanged) |
| Rapier | 1 | ×1.5 reaction | ×1.5 reaction (unchanged) |
| Poison Dart | 8 | ×0.9, Poisoned 0.2, 3 turns | ×0.9, Poisoned 0.2, 3 turns (unchanged) |
| Burning Shot | 16 | ×0.8, Burn 0.35, 3 turns | ×0.8, Burn 0.35, 3 turns (unchanged) |
| Venom Fan | 24 | ×0.7 cone, Poisoned 0.2, 3 turns | ×0.7 cone, Poisoned 0.2, 3 turns (unchanged) |
| Warning Shot | 32 | ×0.9, −1 movement, 2 turns | ×0.9, −1 movement, 2 turns (unchanged) |
| Exposing Shot | 41 | ×0.7, −25% Defense, 2 turns | ×0.7, −25% Defense, 2 turns (unchanged) |
| Burning Shot — Strong Burn rank | 32 | ×0.95, Burn 0.45, 3 turns | ×0.95, Burn 0.45, 3 turns (unchanged) |
| Catalyst | 64 | Once a fight, all his conditions detonate ×2 remaining ticks, then restart | Unchanged |

### Shared / enemy non-spell moves touched by the same rules

| Move | Before | After |
|---|---|---|
| Greatsword Attack (enemies) | ×1.0 base; Heavy Swing ×1.5; Titanfall ×3.0 where present | Unchanged |
| Sweep Strike (Barbarian, Pit Champion) | ×1.4 line, push | ×1.4 line, push; Momentum synergy does **not** apply to enemies (Enfina-only passive) |
| Follow Up Attack (Barbarian, Pit Champion) | ×1.5 secondary | ×1.5 secondary (unchanged) |
| Grab / Hurl / Climb | Unchanged | Unchanged |
| Slip Past / Run / Cover Leap | Unchanged | Unchanged |

## Acceptance tests

- Finisher no longer appears in Enfina's kit, enemy kits, progression plan, or combat context.
- Sweep Strike deals ×1.54 on a turn Enfina has not walked (Momentum I).
- At level 64, Sweep Strike deals ×1.61 on a turn Enfina has not walked (Momentum I + II).
- Momentum I/II still do **not** apply on a turn Enfina has walked.
- Leading Charge remains unchanged and applies only after walking 3+ tiles.
- Titanfall remains unchanged at level 64.
- All spell numbers, gates, and DoT dials remain unchanged.

## Ledger rows to add

```csv
Variable,ImplementationState,DecisionStatus,CurrentValueOrSnapshot,ProposedValueOrRange,Source,Dependencies,Evidence,AcceptanceTest,Owner,Version,Outcome,NextAction
Finisher skill,ABSENT,APPROVED_DESIGN,"Removed (was x2.2, Only Below Health 0.5, level 54)",none,Designer decision 2026-10-25,Titanfall; Momentum I; Sweep Strike,"Titanfall at 64 (x3.0 + splash) outpaces it; execute identity redundant","Finisher no longer appears in Enfina kit, enemy copies, or progression plan",Designer,2026-10-25,Removed,"Claude removes skill file and all references"
Momentum I synergy with Sweep Strike,PRESENT,APPROVED_TRIAL,Momentum I applies only to single-target hits,"Momentum I also applies to Sweep Strike (AoE)",Designer decision 2026-10-25,Momentum I; Sweep Strike; Leading Charge,"Fills level-54 gap left by Finisher removal; reinforces planted identity","Sweep Strike deals x1.54 on a turn Enfina has not walked",Designer,2026-10-25,Pending implementation,"Claude updates Momentum I effect scope"
Momentum II synergy with Sweep Strike,PRESENT,APPROVED_TRIAL,Momentum II applies only to single-target hits,"Momentum II also applies to Sweep Strike (AoE)",Designer decision 2026-10-25,Momentum II; Sweep Strike; Momentum I,"Consistent with Momentum I synergy","Sweep Strike deals x1.61 on a turn Enfina has not walked at 64",Designer,2026-10-25,Pending implementation,"Claude updates Momentum II effect scope"
Non-spell move numbers and ranks,PRESENT,APPROVED_TRIAL,"See table in handoff","No changes beyond Momentum synergy and Finisher removal",Designer decision 2026-10-25,"All non-spell skills listed in the table","Confirmed current values match the agreed table","Every non-spell skill matches the table exactly",Designer,2026-10-25,Pending verification,"Claude audits and confirms each row"
```
