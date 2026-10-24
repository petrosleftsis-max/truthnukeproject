# "Per fight" audit: what became "per short rest"

The audit the designer asked for on 2026-10-24, with the change request "convert limited per-fight effects into per-short-rest effects". It covers every skill, passive, item and enemy effect whose wording or code says "per fight", "once a fight", "a fight" or "Uses Per Fight". It was found by reading the data's descriptions, the generated passive text (`PassiveDefinition.describe_effects`) and every per-fight counter Combat keeps on a combatant.

**The rule.** A **use limit** now comes back on a short rest, and a long rest restores it too. A **trigger condition** (the first hit, the first blow, the first attack in a round) stays per fight or per round. So does anything that only lasts until the fight's end. Damage, durations, conditions and triggers are untouched; only the recovery of uses changes.

**How it works.** What is spent until a rest sits in three places on the combatant, listed as `Combat.SPENT_UNTIL_REST`: a skill's uses (`uses`), free amplifications (`free_amplifies_used`) and Conduit (`conduit_spent`).
- **In a dungeon,** Campaign carries these from fight to fight (`record_party`, `apply_carried_state`), the same way it carries spent gates. A short or long rest clears them (`Campaign.short_rest`, `long_rest`).
- **Everywhere else** (Arena Mode, a fight walked into from a map), every fight starts with all of them, again as with gates.
- **The rest between a dungeon's stages** (`rest_party`) counts as a short rest until the designer sets out what each rest is.

**What this changes in play today.** Nothing yet. Every converted limit belongs to a skill or passive learned at level 24 or above. The only dungeons are the Dungeon Demo (level 14) and the laboratory sequence (18), and every fight outside a dungeon starts with all its uses.

The difference will show in a dungeon at 24 or above. Note that the laboratory sequence skips its rests (`skips_rests`), so in a sequence like it each of these would be once for all its fights.

## 1. Use limits converted to short-rest recovery (APPROVED_TRIAL)

| Effect | Whose | From | Before | Now | Where |
|---|---|---|---|---|---|
| **Recant** | Alithia, Inquisitor | 54 | Once a fight (Uses Per Fight 1) | Once a short rest (Uses Per Short Rest 1) | `data/skills/alithia/paths/inquisitor/recant.tres` |
| **Catalyst** | Cyrus | 64 | Once a fight | Once a short rest | `data/skills/cyrus/catalyst.tres` |
| **Minefield** | Cyrus, Trapper | 64 | Once a fight | Once a short rest | `data/skills/cyrus/paths/trapper/minefield.tres` |
| **Grand Design** | Prometheus, Elemental Tactician | 64 | Once a fight | Once a short rest | `data/skills/prometheus/paths/elemental_tactician/grand_design.tres` |
| **Overcharge** (a free amplification) | Prometheus, Elemental Conductor | 24 | One a fight | One a short rest | `data/subclasses/elemental_conductor.tres`: `free_amplifies_at` |
| **Deep Current** (a second free amplification) | Prometheus, Elemental Conductor | 54 | One more a fight | One more a short rest | the same |
| **Conduit** | Prometheus, Elemental Conductor | 64 | Once a fight | Once a short rest | the same: `conduit` |
| **Stunning Blow** (the special case) | Enfina | 41 | As often as every turn | 1 use a short rest at 41, 2 at 54, 3 at 64 (Uses Per Short Rest 1, More Uses At 54, 64) | `data/skills/enfina/stunning_blow.tres` |

Their descriptions and the generated text now say "a short rest". The amplify toggle reads "free until a short rest", and a spent skill says "spent until a short rest". A limited skill's tooltip shows "Uses: N of M left until a short rest".

The inspector's **Uses Per Fight** is now **Uses Per Short Rest** (`SkillDefinition.uses_per_short_rest`).

## 2. Trigger conditions and durations left unchanged (EXISTING_BASELINE)

| Effect | Whose | Why it stays |
|---|---|---|
| **Ambush Strike**: the first hit on each enemy in a fight deals double | Cyrus, Skirmisher (41) | A trigger condition: the designer's own example |
| **Illusory Guardian**: each ally's first blow taken in a fight misses | Alithia, Illusory Shepherd (64) | A trigger condition: the designer's own example |
| **Afterimage**: in cover, the first attack at him each round misses | Cyrus, Skirmisher (54) | A per-round trigger: the designer's own example |
| **Kindling I-III**: each spell cast in a fight makes the next hotter, up to 15% | Prometheus (from 1) | A build-up through the fight, not a use limit |
| **Ward** and **Shared Ward**: times a round | Prometheus, Elemental Tactician | Per round |
| **Leading Charge**, **Thousand Cuts**, **Rampage** | Enfina, Cyrus | Per turn, or per kill |
| **Crippled**: cannot move again this fight; a broken pair of legs (`BodyPartDefinition.ROOTED`) | conditions, boss parts | Durations to the fight's end |
| **Overheal**: gone by the fight's end | Prometheus, Elemental Tactician | A duration |
| Turned to the other side "for the rest of the fight" | conditions | A duration |
| **Boss phases**, **stagger bars**, Erysichthon's meals and parts, arena hazards | bosses, encounters | Per fight or per phase: the designer's exception |
| What an enemy has to hand "in this fight" (its pocket, a Steal) | enemies | Enemies are made afresh for every fight |
| **Gates** | casters | They already follow rests (in a dungeon, only a rest brings them back) |

No enemy has a per-fight use limit of its own. A Mimic copying one of the converted skills is held to it, but an enemy starts every fight afresh.

## 3. Needs a designer decision (OPEN)

| Effect | Whose | The question |
|---|---|---|
| **Bombardier's Kit**: "A Small Bomb to hand in every fight, free - on top of whatever is in his bag" (`free_item_each_fight`) | Cyrus, Trapper (24) | Its wording describes a kit that is ready every fight, not a "once a fight" use. Should it come back only on a short rest, like the use limits, or stay a bomb in every fight? **Left per fight** until decided; it is not in `SPENT_UNTIL_REST`. |

## Tests

- `tests/run.sh restuses`: the converted limits and their wording; carrying them fight to fight in a dungeon (a save keeps them); a short rest, a long rest and the rest between stages each restoring them; every fight outside a dungeon starting with all of them; the triggers unchanged; the free bomb not carried.
- `tests/run.sh tremor`: Stunning Blow's 1 / 2 / 3, and refused after its three at 64.
- `tests/run.sh paths` and `ammo`: the converted skills still limited within a fight.
