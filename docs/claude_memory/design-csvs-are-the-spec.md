---
name: design-csvs-are-the-spec
description: "The user's design CSVs in docs/ are the spec; apply their numbers directly, ask only where they say nothing"
metadata:
  node_type: memory
  type: feedback
  originSessionId: daf832bf-a3b0-42bb-854e-4dde88e2fdd6
  modified: 2026-10-23T14:42:22.531Z
---

The user gives design sheets as CSVs (from their Perplexity sessions) and wants them applied as written: "if the design csv i gave you included numbers for enemies as well, just adjust them according to that. otherwise let me know" (2026-10-23). The sheets, all copied into docs/:
- `progression.csv` - the party's moves and passives by tier ([[progression-csv-power-level]])
- `alithia_illusory_shepherd.csv` - that path's features
- `consumables.csv` - consumable effects and prices ([[consumable-prices-reference]])
- `enemy_progression.csv` - enemy HP and Defense by tier (I 1-16, II 17-32, III 33-48, IV 49-64) and kind (Frail / Average / Tanky). Applied 2026-10-23 as linear level-1 -> level-64 curves (`max_hp`/`max_hp_level_20`, new `defense`/`defense_level_64` on CombatantDefinition; a spawn's defense 0 = the creature's own). Bosses, Behemoth, Colossus and the party's summons left out - the sheet does not cover them.
- `gold_economy_gear.csv` - gear prices by tier, sell rate 0.5, contract pay per fight (tier I 30-50), mission payouts and services (not in the game yet)
- `cyrus_damage_adjustments.csv` - Cyrus's shot multipliers (Poison Dart 0.9, Burning Shot 0.8 / rank 0.95, Venom Fan 0.7), applied 2026-10-23; the `ammo` suite reads it. Its "verify" rows led to Corroded carrying the -10% Defense itself (ConditionDefinition.defense_change).
- `player_hp_defense_progression.csv` - party HP (identical to what the game already had - Perplexity derived it "from context") and Defense bands 12 / 20 / 28 from levels 1 / 8 / 17 (CombatantDefinition.defense_by_level); party spawns no longer write defence.

**Why:** the user designs the numbers outside the game and wants the game to match; when a sheet is silent they want to be told, not guessed for ([[balance-numbers-are-the-users]]).

**How to apply:** before tuning anything, check docs/*.csv; when a sheet covers it, apply it and report before/after; when one doesn't (e.g. the party's health - no sheet has it), say so and suggest, don't change.
