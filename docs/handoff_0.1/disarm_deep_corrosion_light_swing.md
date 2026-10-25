# Disarm swap, Deep Corrosion rank, and Light Swing rework

**Status:** APPROVED_DESIGN / APPROVED_TRIAL  
**Date:** 2026-10-25  
**Owner:** Designer  
**Implementer:** Claude

## Decision

1. **Replace Enfina's Armor Shred** with **Disarm** — removes Enfina as a Defense-reduction source.
2. **Remove Cyrus's Exposing Shot** and replace it with a **Corrosive Round rank** (Deep Corrosion) — Cyrus becomes the single owner of Defense reduction.
3. **Rework Light Swing's heal** to scale with Enfina's max HP, with a once-per-target finisher bonus.

## 1. Enfina: Armor Shred → Disarm

**Remove:** Armor Shred (lv24, ×0.9 damage, −20% Defense, 2 turns).

**Replace with: Disarm** (lv24, main action, melee, single target):
- ×0.8 damage
- Target's next weapon-based attack deals **half** damage
- No lingering stat debuff, no stacking interaction

**Reason:** Avoids overlapping Defense reduction with Cyrus. Disarm fills a distinct niche: Stunning Blow is the hard stop (strong, limited), Disarm is the soft protect (weaker, repeatable).

## 2. Cyrus: Exposing Shot → Corrosive Round rank

**Remove:** Exposing Shot (lv41, ×0.7 damage, −25% Defense, 2 turns) as a standalone move.

**Replace with: Corrosive Round — Deep Corrosion (rank at lv41):**

| | Level | Damage | Defense reduction | Duration |
|---|---|---|---|---|
| Corrosive Round | 32 | ×0.9 | −10% | 3 turns |
| **Deep Corrosion (rank)** | 41 | ×1.0 | **−20%** | 3 turns |

**Reason:** Consolidates Defense reduction into one move owned by one character. Follows the existing rule that a stronger version of a move is a rank, not a new move. Preserves the refresh-never-stack rule for Corroded.

## 3. Light Swing heal rework

**Light Swing** heals Enfina a % of her max health on hit, with a once-per-target finisher bonus:

| Condition | Heal |
|---|---|
| Target above 50% HP | Base % of Enfina's max HP |
| **First** hit on a target ≤50% HP | **2× base %** of Enfina's max HP |
| Subsequent hits on that same target | Base % (no bonus) |

### Rank ladder

| Level | Base heal | First hit vs. target ≤50% HP |
|---|---|---|
| 1 | 5% max HP | 10% max HP |
| 16 | 7% | 14% |
| 32 | 9% | 18% |
| 54 | 12% | 24% |
| 64 | 15% | 30% |

**Reason:** % of max HP keeps the heal relevant as she levels (never goes stale). The once-per-target limit preserves the "finish off the wounded one" fantasy without creating a 1v1 sustain loop — at lv64 that's a single 57 HP payoff when she breaks the 50% threshold, then back to normal sustain.

## Acceptance tests

- Armor Shred no longer appears in Enfina's kit; Disarm does.
- Exposing Shot no longer appears in Cyrus's kit; Corrosive Round has a Deep Corrosion rank at 41.
- Cyrus is the only character with a lingering Defense-reduction effect.
- Light Swing heals % of Enfina's max HP, not a flat number.
- The 2× bonus triggers only on the first hit per target per fight once that target is ≤50% HP.
- No cooldowns introduced; limits come from the once-per-target rule only.

## Ledger rows to add

```csv
Variable,ImplementationState,DecisionStatus,CurrentValueOrSnapshot,ProposedValueOrRange,Source,Dependencies,Evidence,AcceptanceTest,Owner,Version,Outcome,NextAction
Enfina Armor Shred,PRESENT,APPROVED_DESIGN,"x0.9, -20% Def, 2 turns, lv24",Replaced by Disarm (x0.8, half next weapon attack),Designer decision 2026-10-25,Cyrus Defense reduction; Stunning Blow,"Avoids Defense-reduction overlap with Cyrus","Armor Shred absent; Disarm present at lv24",Designer,2026-10-25,Pending implementation,"Claude swaps skill file and references"
Cyrus Exposing Shot,PRESENT,APPROVED_DESIGN,"x0.7, -25% Def, 2 turns, lv41",Removed; Corrosive Round gains Deep Corrosion rank,Designer decision 2026-10-25,Corrosive Round; Corroded condition,"Consolidates Defense reduction to one owner","Exposing Shot absent; Deep Corrosion rank present at 41",Designer,2026-10-25,Pending implementation,"Claude removes skill and adds rank"
Corrosive Round Deep Corrosion rank,ABSENT,APPROVED_TRIAL,"Corrosive Round x0.9, -10% Def, 3 turns, lv32","Rank at 41: x1.0, -20% Def, 3 turns",Designer decision 2026-10-25,Corrosive Round; Corroded condition,"Follows rank-not-new-move rule","Deep Corrosion rank present at 41 with correct values",Designer,2026-10-25,Pending implementation,"Claude adds rank to Corrosive Round"
Light Swing heal rework,PRESENT,APPROVED_TRIAL,"Flat/small heal (exact base TBD)","5/7/9/12/15% max HP by rank; 2x vs first hit on target <=50% HP per fight",Designer decision 2026-10-25,"Enfina max HP; Titanfall; finisher identity","Avoids 1v1 sustain loop while keeping finisher payoff","Heal scales with max HP; 2x bonus once per target per fight",Designer,2026-10-25,Pending implementation,"Claude confirms current base and implements ladder"
```

## Open item for Claude

Confirm Light Swing's **current base heal value and rank structure** in the data before implementing the ladder — the percentages above assume a baseline that needs matching to the existing lv1 value.
