# The late-Chapter-I laboratory sequence

A **temporary test harness, not story content.** It is the boss-sequence test proposed in `docs/chapter1_audit.md` (section 7), prepared at the designer's request on 2026-10-24.

The boss is **Erysichthon at 18, the primary variant**, since it is the boss that closes Chapter I (designer, 2026-10-24). The Ash Warden at 18 is a **second variant**, kept for what Erysichthon does not test.

Nothing about balance changed to make it: no health, damage, gear, rewards, boss stats or enemy compositions. What it adds is a dungeon's short rests (with Resuscitate at the rest) and a kit of consumables, both at the designer's request of 2026-10-25. Before then it skipped the rests altogether (`skips_rests`), and whoever fell stayed down for the rest of the run.

## How to run it

The primary variant, Erysichthon:

1. Open **`demos/lab_sequence_conservation.tscn`** in the editor and press **F6**. Play the three fights spending as few gates and items as the fights allow.
2. Open **`demos/lab_sequence_free_spending.tscn`** and press **F6**. Play them again, spending whatever helps, as soon as it helps.

The second variant, the Ash Warden, the same way:

3. `demos/lab_sequence_ash_warden_conservation.tscn`
4. `demos/lab_sequence_ash_warden_free_spending.tscn`

Each run writes two files to **`docs/lab_runs/`** (or `user://lab_runs/` in an exported build):

- `<date>_<label>.md` - a summary per fight;
- `<date>_<label>_events.csv` - every counted moment.

The labels are `erysichthon-conservation`, `erysichthon-free-spending`, `ash-warden-conservation` and `ash-warden-free-spending`. The combat log names the file after each fight. Keep expert and newcomer runs apart: label them in the file names, or move them into folders of their own.

## What it is

| | |
|---|---|
| Dungeon (primary) | `data/dungeons/lab_chapter1_sequence.tres` |
| Dungeon (second variant) | `data/dungeons/lab_chapter1_sequence_ash_warden.tres` - the same in everything but stage C |
| Party | Enfina, Cyrus, Prometheus, Alithia, all at **18**. No path yet (paths come at 24); no gear (the story gives none in Chapter I). Each starts with a **kit** that fills the four slots of their Simple Baldric (`kit`, PROPOSAL test values: tier II, as `docs/consumables.csv` has it for 17-32, about 1,570 gold of stock): Enfina two Mediocre Cure Potions, a Cure Potion and a Medicine; Cyrus a Small Bomb, Smelling Salts (to bring somebody fallen round in a fight; since 2026-10-25, in place of his second Small Bomb), a Blinding Bomb and a Mediocre Cure Potion; Prometheus two Medicines (24 each is 63% of his 38), a Mediocre Cure Potion and a Fireball Gate Nade; Alithia a Communion Gate Nade, a Heal Gate Nade, a Mediocre Cure Potion and a Medicine. **The kit is all they have for the three fights**: what is used is gone. |
| Spells | Every spell of theirs (`knows_every_spell`), as in the Dungeon Demo. Which spells Prometheus would really have by 18 is OPEN, since nothing in the story teaches him any (audit, rows 4 and 6). |
| Stage A | `data/encounters/lab/lab_a_city.tres` - the City Fight's ten enemies, at **16** |
| Stage B | `data/encounters/lab/lab_b_hired_blades.tres` - the Hired Blades, at **17** |
| Stage C (primary) | `data/encounters/lab/lab_c_erysichthon.tres` - Erysichthon at **18**, with its carrion heap and bait keg, and its six Gnawers: two at round 3, two when its Jaws break, two after three deaths. The Gnawers are at 18; the heap and the keg keep their own 22. |
| Stage C (second variant) | `data/encounters/lab/lab_c_ash_warden.tres` - the Ash Warden (with its powder kegs, hazards, phases and stagger bar), at **18** |
| Between the fights | **A short rest** (`short_rests`, `Campaign.short_rest`): everybody standing gets back half of what they lost (a PROPOSAL test value), the uses spent until a rest, and one of Alithia's two Devotion castings. No gates come back - but Prometheus may Meditate, once in the run (there is no long rest in it) - and there is no store. **The fallen stay down** - unless somebody standing who knows Resuscitate (Alithia) spends a casting of it on them at the rest, through Pandora or deeper: up with half their health, a tenth weaker until a long rest, as in a fight, and then rested like the others. If Alithia is the one down, nobody can. |
| Logging | `logs_metrics`, through `tools/lab_metrics.gd` |

The fights are copies of the existing ones. The `lab` suite checks that they keep the same enemies, positions, items, weapons, Defense, maps, hazards, ways out and pay. Only the enemies' levels differ, and the story conversations afterwards are left out. The originals are untouched.

The levels (16, 17, 18, and the party at 18) are the harness's own choice inside the audit's 16-18. Change them in the copies and the dungeons.

### What each boss tests

| | Erysichthon (primary) | The Ash Warden (second variant) |
|---|---|---|
| Turns a round | 1 | 2 |
| Immune to | being broken, taken alive, thrown - **no condition** | Stunned (until 33%), Confused; being shoved, teleported, broken |
| Phases | Gorge (66%: a second head, holds two at once), The Hollow (33%: rib maws, eats itself) | The Ash Rises (66%: Rockfall, and burning ash every other round, marked a round ahead), Cinders and Fury (33%: clears its conditions, can be stunned, two imps, a new bar) |
| Stagger bar | 150; 0.6 per damage, 15 per condition it shrugs off | 120, 20 per condition it shrugs off, doubled while it readies a Ground Pound; at 33% a bar of 90, 1.2 per damage, draining 45 a round |
| Its own | Catch the Scent (Scented), Grab, Devour (declared: swallows), Ravenous Bite, Rending Claws; eats the carrion, the keg and its own; parts that regrow | Ground Pound (declared), its Ash Vents (a part), the powder kegs |

So Erysichthon is the one whose turns can be taken from it: it acts once a round and can be stunned. The Ash Warden is the one that tests several turns a round, condition immunities, phases, hazards and stagger.

## What is logged

Per fight:

- **Checkpoints** as it begins and as it ends: everybody's health, who is down, the gates left by depth for each caster, and what each carries.
- **Rounds** and the real time taken.
- **Turns** per side: taken, lost (and why: stunned, staggered, caught off guard), or played for them (confused, deceived).
- **Actions** per fighter, by skill and kind (main, secondary, reaction, a declared move landing).
- **Gates spent**, by depth, per caster.
- **Items used.**
- **Damage:** hits on each side and their total, with lingering ticks counted apart, and the damage each of the party took. Each is laid at the door of whoever did it: a tick at the source of the condition (the events say "lingering: Burn"), a reaction at the one reacting - not at whoever's turn it was.
- **What each of the party did to the enemies:** damage dealt (and how much of it their conditions did as they burned), and the conditions they put on.
- **Healing**, per healer.
- **Downs:** who, in which round, and on whose turn - and the declared move it came from, if any.
- **Declared (telegraphed) moves:**
  - called, landed, or dropped and why;
  - who of the other side stood in the marked tiles when it was called, and when it landed;
  - who got out;
  - who it hit, for how much.
- **Stagger** gained by source (damage, blocked condition, a thing on the map, a hack, a hit, the arena, eating, a broken part), the times staggered, and the damage dealt while staggered.

And a section per boss, **"The boss: <name>"**:

- **Its turns:** offered, its own, lost, and played for it (confused, deceived); lost by cause; the longest run of turns in a row that were not its own; the rounds in which it never acted for itself; every turn in order (`R3:-` is a turn it took, `R4:lost` one it lost).
- **What was put on it**, by whom, and **what it shrugged off**.
- **What happened around it**, round by round:
  - whom it Scented and Grappled, and every break-free attempt (its chance, and whether it worked);
  - whom it swallowed, how they got out, and whom it digested;
  - what it ate, what the party used, which of its parts broke, and each phase.

## What to compare between the two runs

From `chapter1_audit.md` and `docs/handoff_0.1/chapter_i_balance_plan.md`:

- **Resources:** gates by depth per caster, and party health, at each checkpoint. Items used.
- **The boss:**
  - turns offered against turns lost, and the cause of each loss;
  - declared moves cancelled, and by what;
  - stagger, and its sources;
  - damage dealt while staggered;
  - every down.
- **Telegraphs:** who stood in a marked area and got out, who didn't, and what it cost.
- **The hypothesis:** spending heavily should make one fight easier but leave meaningful trade-offs later. If careful play is safe without spending anything, scarcity alone may not create pressure.

### Erysichthon, in particular

- **Can it be chain-controlled?** Read "Longest run of turns not its own" and "Rounds in which it never acted for itself". A long run, or whole rounds without it, means it can be.
- **How often its turns are lost, and why** - "Lost, by cause", against "Put on it" (who did it).
- **Devour, Scented and Grab:** whom it chose, who broke free and at what chance, who was swallowed, how they got out, and whether anybody was digested.
- **The carrion:** what it ate (the heap, the keg, its own), and what the party fed it or kept from it.
- **Party resources** at each checkpoint, and in the boss fight itself.
- **More than one way to win:** compare what each of the party did ("What each of the party did to the enemies") between the two runs, and between players.

**No control-resistance system is to be added** until this baseline shows that chain-control actually removes meaningful decisions (designer's instruction, 2026-10-24). Its turns lost are a measurement here, not a problem to fix.

The designer's lethality rule (2026-10-24):

- A telegraphed attack that is ignored may down Prometheus.
- Cyrus and Alithia should survive ordinary telegraphed attacks.
- Enfina should survive most of them, but not major boss attacks.

Read the downs against it.

## Expected to show up

The automatic lethality review (`docs/chapter1_inventory.csv`, section "Lethality review") and the audit's reading of Devour by hand predict these:

| Attack | Prediction | Reading |
|---|---|---|
| Stage C: Erysichthon's Devour at 18 | Downs anybody it digests, Enfina included, after two of its turns inside | Telegraphed (the Grab, the declaration, two turns inside), with three ways out: tear its Belly Hole open, stagger it, or down it. Allowed by the rule only as a major boss attack - the designer's to read (audit, section 9). Its other blows down nobody in one: the best, Ravenous Bite, is 23 against Prometheus's 38. |
| Stage C (second variant): the Ash Warden's Ground Pound at 18 | Can down only Prometheus | Telegraphed: FAIR by the rule |
| Stage A: the Bombers' Self Destruct at 16 | Can down Prometheus in one blow | Not telegraphed. Kept as it is by the designer (2026-10-24): it teaches the player to read enemy moves. |

## Removing it

The harness is these files:

| What | Files |
|---|---|
| The dungeons and their fights | `data/dungeons/lab_chapter1_sequence.tres`, `data/dungeons/lab_chapter1_sequence_ash_warden.tres`, `data/encounters/lab/` |
| The launchers | `demos/lab_sequence*.tscn`, `demos/lab_sequence.gd` |
| The logger | `tools/lab_metrics.gd` |
| The suite | `tests/lab_test_driver.gd` (and `lab` in `tests/suites.txt`) |
| The two switches | `DungeonDefinition.skips_rests` (no longer used by the lab) and `logs_metrics`, with their uses in `ui/result_ui.gd` and `scenes/game.gd`. Short rests, Resuscitate at a rest and the kit are general dungeon features and can stay. |

Combat's `metric` signal can stay: it changes nothing in play.
