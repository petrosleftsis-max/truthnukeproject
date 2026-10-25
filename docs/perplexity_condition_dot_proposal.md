# Perplexity condition and DoT tuning proposal

Status: PROPOSAL — test values only. Do not treat as APPROVED_DESIGN or APPROVED_TRIAL.

This file proposes a coherent first pass for condition durations, condition damage, and the Hermes condition spells. It does not change any game data yet.

## Core intent

- Make conditions last 5 turns by default.
- Lower per-turn DoT dials so 5-turn conditions do not become strictly overwhelming.
- Preserve a clear elemental identity:
  - Burn: highest damage, but the target becomes faster.
  - Poison: second-highest damage, and removes reactions.
  - Frozen: moderate damage, slows, and denies secondary actions.
  - Crystallised: hard containment; zero movement.
  - Windswept: low damage, but strong positional disruption.
  - Corroded: low damage, but reduces Defense.
- Make Hermes condition spells single target and stronger per target.
- Keep Pandora condition spells as area versions with lower per-target values.
- Keep Gun relevant by ensuring Burning Shot and Poison Dart are tradeoffs, not strict upgrades.

## Condition base ranges

These are proposed base ranges for the conditions themselves, before a move's own condition_dot_modifier.

| Condition | Current base DoT | Proposed base DoT | Proposed duration | Identity |
|---|---:|---:|---:|---|
| Burn | 6-8 | 4-5 | 5 turns | Highest damage; +2 movement remains the cost |
| Poisoned | 4-6 | 3-4 | 5 turns | Second-highest damage; prevents reactions |
| Frozen | 1-2 | 1-3 | 5 turns | Slows by 2 and prevents secondary actions |
| Crystallised | 2-4 | 1-3 | 5 turns | Prevents movement |
| Windswept | 1-3 | 1-2 | 5 turns | Slows by 3 and drifts 3 tiles at turn start |
| Corroded | Low Acid DoT | 1-2 | 5 turns | -10% Defense; armor erosion |

Do not add Defense reduction to Frozen. Corroded remains the Defense-reduction condition.

## Proposed hierarchy

Raw damage over time:

Burn > Poison > Frozen ≈ Crystallised > Corroded > Windswept

Control value:

Crystallised > Frozen > Poison > Windswept > Corroded > Burn

Party enablement:

Poison > Corroded > Frozen > Windswept > Crystallised > Burn

## Hermes spells: single target

Make the Hermes condition-inflicting spells single target. Raise their direct damage and/or DoT dial because they no longer hit several enemies.

| Spell | Current | Proposed |
|---|---|---|
| Burner | Radius 2; x1.4; Burn 3 turns at 0.2 | Single target; x1.7; Burn 5 turns at 0.25 |
| River Flow | Radius 2; x1.3; Frozen 2 turns at 0.2 | Single target; x1.4; Frozen 5 turns at 0.20 |
| Wind Swoon | Radius 2; x0.8; Windswept 2 turns at 0.1 | Single target; x1.0; Windswept 5 turns at 0.10 |
| Crystalise | Radius 2; x0.8; Crystallised 3 turns at 0.1 | Single target; x1.0; Crystallised 5 turns at 0.10 |

## Pandora spells: area

Keep the Pandora condition spells as area versions. Their per-target values should be lower than the Hermes single-target versions.

| Spell | Current | Proposed |
|---|---|---|
| Wildfire | Radius 2; x2.1; Burn 3 turns at 0.4 | Radius 2; x2.1; Burn 5 turns at 0.35 |
| Frozen River | Radius 2; x1.8; Frozen 3 turns at 0.25 | Radius 2; x1.8; Frozen 5 turns at 0.30 |

## Cyrus ammunition

Gun should remain the neutral immediate-damage choice. Burning Shot should trade immediate damage for Burn. Poison Dart should trade immediate damage for reaction denial and Poison.

| Ammo | Current | Proposed |
|---|---|---|
| Gun | x1.0; no condition | Unchanged: x1.0; no condition |
| Burning Shot | x0.8; Burn 3 turns at 0.35; rank 32: x0.95 and 0.45 | x0.9; Burn 5 turns at 0.15; rank 32: x1.05 and 0.20 |
| Poison Dart | x0.9; Poison 3 turns at 0.2 | x0.75; Poison 5 turns at 0.20 |
| Venom Fan | x0.7 cone; Poison 3 turns at 0.2 | x0.7 cone; Poison 5 turns at 0.15 |

Burning Shot should usually be better for immediate and sustained Fire damage. Poison Dart should usually be better when Cyrus wants to remove reactions before a grab, escape, InstaHack, or major party follow-up. Using both can remain a deliberate DoT-stacking approach.

## Wind spells

Wind should remain a positioning element, not a primary damage element.

| Spell | Current | Proposed |
|---|---|---|
| Wind Swoon | Radius 2; x0.8; Windswept 2 turns at 0.1 | Single target; x1.0; Windswept 5 turns at 0.10 |
| Gust Blast | Single target; x1.2; push 2-4 / 3 tiles; Windswept 2 turns at 0.15 | Single target; x1.2; push unchanged; Windswept 5 turns at 0.10 |

## Earth and Acid

| Item | Current | Proposed |
|---|---|---|
| Crystalise | Radius 2; x0.8; Crystallised 3 turns at 0.1 | Single target; x1.0; Crystallised 5 turns at 0.10 |
| Corroded condition | 3 turns; Acid DoT; -10% Defense | 5 turns; low Acid DoT; -10% Defense |

Crystalise should remain a containment tool, not a damage tool. Corroded should remain the Defense-shred condition.

## Implementation notes for Claude

- Change only the values described in this file.
- Do not change Defense reduction on Frozen.
- Do not change Catalyst.
- Do not change condition immunities unless separately requested.
- Do not change enemy conditions or enemy-specific mechanics in this pass.
- Keep Burn's +2 movement.
- Keep Poisoned's prevents_reactions.
- Keep Frozen's movement_change -2 and prevents_secondary.
- Keep Crystallised's prevents_movement.
- Keep Windswept's movement_change -3 and drift_tiles 3.
- Keep Corroded's defense_change -0.1.
- Update condition durations to 5 turns for the conditions and moves listed here.
- Make Burner, River Flow, Wind Swoon, and Crystalise single target.
- Keep Wildfire and Frozen River as radius-2 area spells.
- Update the design status ledger with these as PROPOSAL entries, not APPROVED_DESIGN or APPROVED_TRIAL.

## First test pass

If implementing all of the above at once, use these exact proposed values:

| Item | Proposed value |
|---|---|
| Burn base DoT | 4-5 |
| Poisoned base DoT | 3-4 |
| Frozen base DoT | 1-3 |
| Crystallised base DoT | 1-3 |
| Windswept base DoT | 1-2 |
| Corroded base DoT | 1-2 |
| Burner | Single target; x1.7; Burn 5 turns at 0.25 |
| Wildfire | Radius 2; x2.1; Burn 5 turns at 0.35 |
| Burning Shot | x0.9; Burn 5 turns at 0.15; rank 32: x1.05 and 0.20 |
| Poison Dart | x0.75; Poison 5 turns at 0.20 |
| Venom Fan | x0.7; Poison 5 turns at 0.15 |
| River Flow | Single target; x1.4; Frozen 5 turns at 0.20 |
| Frozen River | Radius 2; x1.8; Frozen 5 turns at 0.30 |
| Wind Swoon | Single target; x1.0; Windswept 5 turns at 0.10 |
| Gust Blast | Single target; x1.2; push unchanged; Windswept 5 turns at 0.10 |
| Crystalise | Single target; x1.0; Crystallised 5 turns at 0.10 |
| Corroded | 5 turns; low Acid DoT; -10% Defense |

## What to observe in testing

- Does Burn still feel like the strongest damage-over-time condition?
- Does Poison feel like the best condition for enabling a decisive party turn?
- Does Frozen feel useful against skill-heavy enemies without becoming a universal answer?
- Does Crystalise remain strong against melee threats without making them trivial?
- Does Windswept remain valuable because of displacement rather than damage?
- Does Corroded remain the preferred condition before a focus-fire turn?
- Does Gun remain a real choice against Burning Shot and Poison Dart?
- Do Hermes single-target spells feel meaningfully stronger per target than Pandora area spells?
