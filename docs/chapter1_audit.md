# Chapter I and level-64 audit

Answer to the design handoff package 0.1 (`docs/handoff_0.1/`), first task. Read from the repository on 2026-10-24, not from the combat-context snapshot.

Statuses follow the package:

- **ImplementationState:** PRESENT / ABSENT / VERIFY.
- **DecisionStatus:** EXISTING_BASELINE / APPROVED_TRIAL / PROPOSAL / OPEN / APPROVED_DESIGN.
- A blank value means unknown, never zero.

Files that go with this report:

| File | What it is |
|---|---|
| `docs/chapter1_inventory.csv` | Every value below, with its source file and field. Written by the probe `tests/run.sh chapter1` from the game's own data and damage arithmetic. |
| `docs/design_status_ledger.csv` | The package's ledger, verified against the repository, with this session's changes added. |
| `docs/handoff_0.1/` | The package itself, kept as sent. |

---

## 1. Verified current-value inventory

The full inventory is `docs/chapter1_inventory.csv`. The summaries below come from it.

### The party

Health and Defense by level, with no armour worn. Health is EXISTING_BASELINE; Defense is APPROVED_TRIAL, from the player sheet.

| Level | Enfina | Cyrus | Prometheus | Alithia |
|---|---|---|---|---|
| 1 | 130 / 12 | 75 / 12 | 30 / 12 | 75 / 12 |
| 4 | 133 / 12 | 77 / 12 | 31 / 12 | 77 / 12 |
| 8 | 137 / 20 | 79 / 20 | 33 / 20 | 79 / 20 |
| 11 | 140 / 20 | 81 / 20 | 34 / 20 | 81 / 20 |
| 14 | 142 / 20 | 83 / 20 | 36 / 20 | 83 / 20 |
| 16 | 144 / 20 | 85 / 20 | 37 / 20 | 85 / 20 |
| 18 | 146 / 28 | 86 / 28 | 38 / 28 | 86 / 28 |
| 64 | 190 / 28 | 115 / 28 | 58 / 28 | 115 / 28 |

- **Initiative:** Cyrus 8, Alithia 7, Enfina 6, Prometheus 5 (EXISTING_BASELINE). Chapter I's enemies are 3-4.
- **Movement:** 6 for all four through Chapter I. Cyrus has 8 on a turn he starts in cover; from 24 it's 8 always, or 10 in cover.
- **Resistances:** none.
- **Gates** (Prometheus and Alithia):

  | Level | Gates |
  |---|---|
  | 1 | World 2 |
  | 4 | World 3 |
  | 8 | World 4, Hermes 2 |
  | 11 | World 4, Hermes 3 |
  | 14 | World 4, Hermes 3, Pandora 2 |
  | 18 | World 4, Hermes 3, Pandora 3 |

- **Kits at 18:**
  - **Enfina:** Greatsword Attack ×1.5 (the rank from 8); Light Swing, Shoving Strike and Hurl ×1.0; Blink Strike ×0.8; Fire Burst ×0.7; Battle Cry ×0.6 (from 16). Also Guard, Grab, Climb, Trailblaze and Intimidate. Passives: Measured Eye, Iron Hide I-II, Bulwark I.
  - **Cyrus:** Rapier ×1.5; Gun ×1.0; Poison Dart ×0.9 (from 8); Burning Shot ×0.8 (from 16); Blink Strike ×0.8. Also Steal, Deceive, Stealth and Cover Leap. Passives: Light Footed, Quick Hands, Nade Juggler, Cat Burglar I, Agile I, DoT Master I, Elusive.
  - **Prometheus:** cantrips Fire Burst, Zephyr Dart and Caucasus Shard (×0.7); Hack. His spells:

    | Where | Spells |
    |---|---|
    | In the story | Fire Blast, Wind Shot, Rock Throw, Quicken |
    | In Arena Mode | Also InstaHack, Dispel Magic, Burner, Wildfire, Fireball, Wind Vacuum, Crystalise, Wind Swoon, Hermes Step, Hover, Invisibility, Growth, Mist Step, Kindled Hound |

    Passives: Prying Mind, Elemental Affinity I, Kindling I-II.
  - **Alithia:** the same in the story and Arena Mode. Votive Flame and Water Spike ×0.7, Sass Club ×1.5, Intuition. Spells: Heal, Light Heal, Holy Lance, Flash, River Flow, Frozen River (from 16), Resuscitate, Cleanse, Holy Splash, Communion (from 16), Dread Visage, Bewilder. Passives: Mercy I-II, Aura I.

### The fights

Worked out with `Combat.predict_hit`, the same arithmetic as the aiming preview.

What this leaves out:

- reach, cover and hit chance;
- warnings: Ground Pound and Rockfall are declared a turn ahead, and Self Destruct kills the Bomber;
- passives that only act in play, such as Illusory Guardian.

The party side uses Arena Mode's spell knowledge. In the story, Prometheus has only his four spells.

| Fight | Level | Enemies | Fastest an enemy downs one of the party | Party: blows to down the enemies |
|---|---|---|---|---|
| **Sewer Intro Fight** (story) | 1 | 5: Priest, Ranger, 2 Mimics, a Sorcerer | Cyrus in 5 (the Priest's Rapier, 15); Enfina in 10 | 2-4 each, mostly Cyrus's Rapier (16-17) |
| **Lab Fight** (story) | 8 | 7: Priest, Bomber, 2 Barbarians, Ranger, Sorcerer, Mimic | **Prometheus in 1** (Self Destruct, 37, against his 33); Alithia and Cyrus in 3; Enfina in 5 | 2-5 (the Barbarians take 5) |
| **Hired Blades** (story) | 8 | 5: Pit Champion, 2 Sellswords, 2 Hired Bows | Prometheus in 2 (the Champion's Greatsword, 19); the others in 5, Enfina in 9 | 4-5; the **Pit Champion takes 8** |
| **City Fight** (title screen) | 14 | 10: 2 Rangers, 2 Bombers, a Barbarian, 2 Sorcerers, 2 Priests, a Mimic | **Prometheus in 1** (Self Destruct, 47, against 36); Alithia and Cyrus in 2; Enfina in 4 | 2-5 |
| Two Floors (Arena) | 8 | 4: 2 Hired Bows, a Ranger, a Sellsword | Prometheus in 2; the others in 4, Enfina in 8 | 3-5 |
| The Bound Golem (Arena) | 10 | 3: Stone Golem, Behemoth, Sorcerer | Prometheus in 2; the others in 3, Enfina in 5 | Sorcerer 2; **Golem 7, Behemoth 8** |
| Big and Small (Arena) | 10 | 9: 4 Rats, 2 Imps, Ogre, Stone Golem, Behemoth | **Prometheus in 1** (Ground Pound, 36, against 34) | Rats and Imps 2; Ogre 6, Golem 7, Behemoth 9 |
| **The Ash Warden** (Arena boss) | 10 | The Ash Warden | **Prometheus in 1** (Ground Pound, 36); the others in 3, Enfina in 5 | **About 20** (471 health) |
| **The Bellkeeper** (Arena boss) | 10 | The Bellkeeper, 2 Rats | Prometheus in 2 (Rockfall, 20); the others in 5, Enfina in 8 | Rats 1; **the Bellkeeper about 10** (266 health) |
| The Alchemist (Arena) | 14 | 3: Alchemist, Sellsword, Hired Bow | Prometheus in 2 (Greatsword, 28); the others in 3, Enfina in 6 | 2-4 |
| Dungeon Demo, ×3 | 14 | 7 each | **Prometheus in 1** (Self Destruct, 47) | 2-5 |
| **Sixty-Four** (regression) | 64 | 9 and the Bound Beast | **Alithia, Cyrus and Prometheus in 1** (the Barbarian's Titanfall, 126); Enfina in 3 | See the designer's playtest: the party acts first |

From level 8, Prometheus can be downed by one telegraphed blow in most Chapter I fights. The designer intends him to be fragile ("supposed to go down fairly easily if not careful"). Whether one blow is the intended size of "fragile" is OPEN.

### The bosses near Chapter I

| Boss | Level now | Health / Defense | Turns a round | Control resistance | Phases | Stagger bar |
|---|---|---|---|---|---|---|
| Ash Warden | 10 (Arena) | 471 / 20 | 2 | Stunned, Confused, shoves, teleports, breaking | 66%: The Ash Rises. 33%: Cinders and Fury - **loses its Stunned immunity, clears everything on it**, summons 2 Imps, new bar | 120. Fills from damage ×1.0, **+20 per blocked condition**, double while winding up, kegs, its ash. Full: loses 1 turn, takes ×1.5 damage. |
| Bellkeeper | 10 (Arena) | 266 / 20 | 2 | Stunned, Confused, Frozen, Crystallised, shoves, teleports, being stolen from, breaking | 50%: The Last Toll - summons 3 Rats, new bar | 100, from its bells only. Full: loses 2 turns, takes ×1.5. |
| Erysichthon | 22 (Arena); 18 in the laboratory sequence | 900 / 20 | 1 | **None to control** (only breaking, being taken alive, being thrown) | 66%: Gorge. 33%: The Hollow | 150. Fills from damage ×0.6, +15 per blocked condition. Full: loses 1 turn, takes ×1.5. |

Two findings against `boss_control_rules.md`:

1. **The Ash Warden's last phase clears every condition on it.** That wipes damage over time that was built up. The rules advise against doing that automatically.
2. **Erysichthon resists no control, and has one turn a round.** That's the clearest chain-lock risk, and the first thing to test in a boss baseline.

The "stagger from blocked control" route the rules prefer is already PRESENT: the Ash Warden gains 20 and Erysichthon 15 per blocked condition.

### Conditions

For every skill that puts a condition on, the inventory lists the condition's own turns and damage dial, and what the skill overrides. Rules that apply to all of them:

- A skill's own turns and dial beat the condition's.
- A rank can override both.
- A second application replaces the first: it refreshes and never stacks.
- Stat changes (STAT_MODIFIER / STAT_MULTIPLIER) do stack.
- "N turns" is N of the target's turns.

---

## 2. Snapshot versus repository

The snapshot is `docs/perplexity_combat_context.md` as it was sent. The repository is the truth.

| Topic | Snapshot says | Repository does | Action taken |
|---|---|---|---|
| Cyrus's movement | "Cyrus walks 8 from level 8"; Cat Burglar's +2 "from level 8" (Part 1, and the README) | Cat Burglar I gives +2 on a turn started in cover, from level 1. Cat Burglar II gives +2 always and climbing anywhere, from **24**. So Cyrus has 6 (8 in cover) up to 23, and 8 (10 in cover) from 24. | Documentation corrected. |
| Gate Nade power | Part 4: "Gate Nades: power 50" | Heal 30, Crystalise 40, Fireball 50, Communion 50 | Part 4 corrected. |
| Catalyst scope | `EffectDefinition`'s comment: "on the one it lands on" | `Combat.catalyst()` sets off every lingering *condition* of Cyrus's on **every** enemy, for one tick's damage × (ticks left × 2), resisted once, then restarts each at full length. Bare damage-over-time wounds (not conditions) are left out. The README describes all enemies. | **Resolved:** the designer keeps every enemy (2026-10-24). The comments, the skill text and the preview now match the code; the exact rule is in the ledger, and the `ammo` suite checks it. Code unchanged. |
| Durations | Earlier snapshots: an effect wearing off at a turn's end lasts one turn longer than written | Since 2026-10-24 (the designer's rule), "N turns" is N of the target's turns. An effect that lands on whoever is acting also gets the rest of that turn. | Snapshot rules updated. |
| Corrosive Round | A separate ×0.9 Defense effect beside Corroded (Part 3 of older snapshots) | −10% Defense carried by the Corroded condition itself (`defense_change`): it refreshes, never stacks, and is cleansed with Corroded | Done before the handoff and **outside the trial's scope**. See section 8. |
| Fight Defense | Older snapshots: Defense set per fight for everybody | Enemies follow their own Defense curves (from the enemy sheet). The party follows the player sheet's bands (12 / 20 / 28). Fights no longer write Defense for either, except bosses, the Behemoth, the Colossus and objects. | Done before the handoff, at the designer's direction. |
| Revitalizer | Older snapshots: Alithia and the Priest have Revitalizer | Replaced by Communion (the designer's decision, 2026-10-23); Revitalizer is unused | - |
| Burning Shot | Physical hit, Fire burn | Same: the hit is Physical, Burn deals Fire | Verified, unchanged. |
| Kindling | +5% a spell, caps 15 / 30 / 45%, cantrips excluded | Same. Also, a Gate Nade of a spell counts as a spell for it. | Verified. |
| Frozen | Prevents the secondary action, −2 movement | Same. Its own damage dial is **1.0**. Every source sets its own: River Flow 0.2, Frozen River and Glacial Tide 0.25, the Frost Bottle 0.3. | Reported (OPEN): a new source without an override would tick at ×1.0. |
| City Fight reward | 45 gold | Paid only when the fight is started from a story map or a dungeon. Its title-screen entry starts it directly, so it pays nothing there. | Reported. |

---

## 3. The Cyrus trial: what changed

All four are `APPROVED_TRIAL`. The values match the package's corrected CSV (`docs/handoff_0.1/cyrus_damage_adjustments.csv`). They were applied on 2026-10-23, before the package arrived. The values are the same, so nothing needed re-applying.

| File | Field | Was | Now |
|---|---|---|---|
| `data/skills/cyrus/poison_dart.tres` | `ability_modifier` (skill; no ranks) | 1.0 | **0.9** |
| `data/skills/cyrus/burning_shot.tres` | `ability_modifier` (skill; used 16-31) | 0.9 | **0.8** |
| `data/skills/cyrus/burning_shot.tres` | `ranks[Rank_32].ability_modifier` (rank "Strong Burn", from 32) | 1.1 | **0.95** |
| `data/skills/cyrus/venom_fan.tres` | `ability_modifier` (skill; no ranks) | 0.8 | **0.7** |

**Preserved and checked** by the `ammo` suite and by reading the files:

- **Damage over time:** Poisoned 0.2 for 3 turns. Burn 0.35 for 3 turns, and the rank's Burn dial 0.45, unchanged. The rank sets no duration of its own.
- **Everything else unchanged:** range, area (Venom Fan's cone 3), cost (none), damage types (Physical hits, Fire and Poison lingering), and the conditions themselves.
- **Unrelated changes in these files, separate from the trial:** the documentation text in `docs/progression_plan.md` was updated to the new numbers, and `tests/csv_test_driver.gd` lists the four as deliberate departures from `progression.csv`.

---

## 4. Shared users and rank overrides

- **Enemies:** no enemy carries Poison Dart, Burning Shot or Venom Fan. None is in a path's skill list, and no passive or item names them. Only `data/characters/cyrus.tres` lists them.
- **Rank overrides:** only Burning Shot has a rank (level 32, "Strong Burn"). It overrides the hit and the Burn dial, and the trial changed its hit. Poison Dart and Venom Fan have no ranks.
- **Combined Load inherits the change.** It fires the first load's hit with both loads' effects, so Burning Shot + Poison Dart at 32+ is now ×0.95, and Poison Dart + Burning Shot ×0.9. Its own ×1.0 applies only when it is fired without loads.
- **Overload** (Saboteur 54) and **Catalyst** set off the conditions these shots leave. Those are unchanged in strength, but at the new durations they tick one turn fewer than before 2026-10-24.
- **Not part of the trial, but shared:** Greatsword Attack is Enfina's and also the Barbarian's and the Pit Champion's. Its level-64 rank (Titanfall, ×3.0 with a ×1.5 splash) applies to them at 64 as well. That's relevant to the level-64 regression.

---

## 5. Chapter I as it stands

There is no continuous Chapter I yet. The title screen offers four separate entry points, and none of their maps leads to another. Chapter I is levels 1-18 (`Campaign.CHAPTER_LEVELS`). Story content exists at levels **1, 8 and 14** only. Nothing sets a level between 15 and 18, and no fight raises the level: `party_reaches_level` is unused. The level comes from each map's `MapSetup.level`.

| Entry point (title screen) | Where | Party | Level | Fights | Rewards and resources |
|---|---|---|---|---|---|
| **Cyrus** - "introduction and tutorial" | Narration over black (`cyrus_intro`), then the sewer map (`maps/crossroads_explore.tscn`) | Cyrus; Enfina joins in `intro_sewer_before_encounter` | 1 | **Sewer Intro Fight** (`encounter_01_ambush`) | 30 gold. The guards' cache gives Cyrus a Cure Potion and a Tiny Bomb. The story stops after the fight (`intro_sewer_after_encounter`: the Wolf). |
| **Prometheus** - "team dynamics" | The laboratory (`maps/laboratory_explore.tscn`) | All four (`MapSetup.members`; no joining scene) | 8 | **Lab Fight** (`encounter_02_sappers`); **Hired Blades** (`encounter_hired_blades`), with a parley before it | Lab Fight 40 gold; Hired Blades 0. The sellswords' contract: a clue, 200 gold, a trap (12 strain unless the quick-time press is made). Questioning: a Sellsword 30 gold, a Hired Bow 20. Parley: pay the Pit Champion 150, bribe an archer, or buy a sellsword. Supplies from the "sell" scene: Medicine ×2, Crystal, Burn, Gale and Poison bottles. The workbench strongbox holds a Fireball Gate Nade, which Prometheus can take apart to learn Fireball. Ten hacks. |
| **Enfina** - "a difficult stage" | Straight into the fight | The fight's tiles: all four | 14 | **City Fight** (`encounter_03_watcher`) | None: started without a map, it pays nothing. |
| **Alithia** - "mid to end game" | The church (`maps/church.tscn`) | Alithia | 14 | None | Narrative only. |
| Stealth stages ×7 | `maps/stealth_stages/` | Cyrus (Enfina in stage 3) | 10 | Only when caught: the guards, at the party's level | Stage items (robes, darts, drugs, keys) |
| Dungeon Demo | Three stages | Cyrus, Alithia, Prometheus (no Enfina), knowing every spell | 14 | Sewer, Lab and City variants, 7 enemies each at 14 | 45 gold each. Full rest after each (revives). One gate recovery of 3 points, Prometheus only. The travelling merchant. |

**Arena Mode at Chapter I levels:** these are not story fights. Their levels are the fights' own.

| Fight | Level |
|---|---|
| Two Floors | 8 |
| The Bound Golem | 10 |
| **The Ash Warden** (boss) | 10 |
| **The Bellkeeper** (boss) | 10 |
| Big and Small | 10 |
| The Alchemist | 14 |

Above Chapter I: The Colossus (20), **Erysichthon** (boss, 22), The Summoner (22), Sixty-Four (64).

**Party availability:**
- Cyrus from the start.
- Enfina from the sewer fight, level 1.
- Prometheus and Alithia from the laboratory, level 8. They are placed there with no joining scene.

**Spell acquisition:**
- **Alithia** grows into hers by level (section 1).
- **Prometheus** knows only his starting spells in the story: Fire Blast, Wind Shot, Rock Throw and Quicken. In Chapter I his only other source is the lab's Fireball Gate Nade. No spellbook can be found or bought in any story map: the only store is the Dungeon Demo's, and the only books on enemies are in the Arena's Alchemist Den.
- **Arena Mode and the Dungeon Demo** give him every spell.

**Shops and rests in the story:** none. Gates refill at the start of every fight. Health carries over between fights on the same map, and nothing restores it in the story. Only a dungeon rests (`Campaign.rest_party`).

**Bosses:** no boss stands in any Chapter I story fight. The bosses at Chapter I levels exist only in Arena Mode (Ash Warden and Bellkeeper, at 10). Erysichthon, called "the first boss", is set at 22.

---

## 6. Missing values, in priority order

| # | Missing | Status | Notes |
|---|---|---|---|
| 1 | The Chapter I itinerary: which fights, in what order, at what levels from 15 to 18, with whom | OPEN | Designer. Nothing can be invented here. |
| 2 | Which boss closes Chapter I, and at what level | Decided (2026-10-24): **Erysichthon**. It also appears briefly in the first encounter, as something to run from, and has another enemy supporting it. | Still OPEN: its Chapter I level (now 22), the supporting enemy, and the first-encounter escape. Not in the story yet; the laboratory sequence's primary boss at 18 (section 7). |
| 3 | Recovery in the story: does health come back between maps or fights, and is there any rest? | PROPOSAL (2026-10-24) | Only dungeons rest now. Proposed: 2-3 short rests a segment (50% of the missing health, no gates), a long rest (everything), and Prometheus's Meditate. Analysed in `docs/healing_and_rest_proposal.md`; not implemented. |
| 4 | Prometheus's Chapter I spells: which books, where, at what cost | OPEN | Without them his story kit is four spells plus Fireball. |
| 5 | Per-fight acceptance targets (rounds, downs, resources spent) | OPEN | To agree before tuning, as the plan says. |
| 6 | Party gear in Chapter I: what is found or bought, and when | OPEN | Story fights now run on the tile's weapon base (6) and the Defense bands. |
| 7 | Shops in Chapter I: where, and what they stock | OPEN | |
| 8 | Catalyst's scope: the target only, or every enemy | Decided (2026-10-24): every enemy, as the code does, but only conditions Cyrus himself put on | Documented exactly (ledger). Intentional: Catalyst is Cyrus's personal condition payoff. Other sources' conditions and bare damage-over-time wounds are unaffected. Team-wide condition synergy may come later as a separate mechanic, not folded into Catalyst. |
| 9 | Tripwire and Minefield's ×1.2 bursts; Venom Fan's tie with Exposing Shot | OPEN | Against the Cyrus rules (ledger). |
| 10 | Frozen's own dial of 1.0 | OPEN | Unused at that strength today. |
| 11 | Gate recovery for Alithia in dungeons | OPEN | Only Prometheus recovers now. |
| 12 | Enemy weapon base by tier | OPEN | Set per fight now: 6-12. |
| 13 | Party resistances | OPEN | None set. |
| 14 | Mission payouts | PROPOSAL | ABSENT as a system. Proposal: a conversation's `do Campaign.give_gold(n)` at the end of a mission, using the economy sheet's tier ranges as REFERENCE (500-1000 in tier I). No code needed. Not implemented. |
| 15 | Different resale for junk and rare goods | PROPOSAL | ABSENT. Proposal: an optional sell rate per item, falling back to the store's 0.5. Not implemented. |
| 16 | Services (inn, healer, Gate Nade crafting) | OPEN | ABSENT. Wait until recovery (row 3) is designed. |
| 17 | A dungeon option to skip the rest between stages | APPROVED_TRIAL | PRESENT since 2026-10-24: `DungeonDefinition.skips_rests`, TEMPORARY, used only by the laboratory sequence (section 7). |
| 18 | An automatic player for the party in test fights | PROPOSAL | ABSENT. The party has no AI, so fights can't be replayed for metrics without a person. Proposal: a probe that plays the party with the enemies' existing AI archetypes, for repeatable logs. Not implemented. |

---

## 7. Proposed test plans

The early fight is a PROPOSAL, not implemented. The late sequence is prepared as an APPROVED_TRIAL test harness (`docs/lab_sequence.md`).

### Early fight: the Lab Fight (Sappers), level 8

- **Why this fight:** it's the first story fight with all four, and the first where the trial applies (Poison Dart comes at 8). The Sewer Intro Fight (level 1, Cyrus and Enfina) is a separate tutorial check.
- **Start it from the laboratory map** (the Prometheus entry), so the story's own rules hold: the party's level, story spell ownership (Prometheus knows four spells), the Defense bands, and fight gold.
- **Run it three times:**
  1. Baseline, as it is.
  2. Cyrus using only Gun.
  3. Cyrus opening with Poison Dart.

  The expert's and a newcomer's runs are logged apart.
- **Log:**
  - rounds;
  - enemy actions offered and taken, and denied with the reason;
  - hits;
  - downs (whose, and to what);
  - healing;
  - gates by depth per caster;
  - items;
  - duration.
- **Questions to answer** (targets to agree first):
  - Does Poison Dart earn its place on targets that live two or more turns, while Gun still finishes?
  - Is anybody downed in one enemy blow? The inventory has the predicted blows-to-down for every pair.
  - Do several reasonable tactics win?

### Late-Chapter-I boss sequence (laboratory, not story)

- **The gap:** the story has no fights between 15 and 18 and no Chapter I boss, so this has to be a laboratory test.
- **The proposed sequence:** use the Dungeon Demo's format at level 16-18.
  - **Stage A:** the City Fight's enemies.
  - **Stage B:** the Hired Blades.
  - **The boss:** **Erysichthon at 18**, the primary variant (the designer's choice, 2026-10-24; row 2).
  - **A second variant:** the **Ash Warden at 18**, kept for what Erysichthon does not test: several turns a round, condition immunities, phases, hazards and stagger.
- **No rest or gate recovery between the stages:** the dungeon skips its rest (row 17), so health and gates carry from A to B to the boss.
- **Run it twice:** once conserving resources, once spending freely.
- **Checkpoint** each caster's gates by depth and the party's health before each fight.
- **Boss baseline** (`boss_control_rules.md`). Log:
  - the boss's turns offered, and turns lost by cause (stun, stagger, the rest);
  - declared moves cancelled, and by what;
  - stagger gained, and from what;
  - vulnerable windows;
  - damage to the party, and every down.
- **For Erysichthon, log:**
  - whether it can be chain-controlled;
  - how often its turns are lost, and why;
  - what comes of Devour, Scented and Grab;
  - what it does with the carrion;
  - the party's resources;
  - whether more than one strategy works.
- **Control:** test with no control, normal mixed tactics, and deliberate chaining.
- **No control-resistance system** is to be added until the Erysichthon baseline shows that chain-control actually removes meaningful decisions (the designer, 2026-10-24).
- **Stagger from blocked control is already PRESENT.** A boss's `StaggerDefinition` can gain stagger per blocked condition: 15 for Erysichthon, 20 for the Ash Warden. Erysichthon is immune to no condition, so that route does not fill its bar: its stagger comes from damage.
- **Then:** test the story's own recovery separately, once it exists (row 3).

---

## 8. Changed before the handoff, outside the trial

These were made before the package arrived. Most were at the designer's direction. The package says to confirm scope and not to change these areas further, so nothing more has been changed. Each is in the ledger.

| Change | DecisionStatus | Designer to... |
|---|---|---|
| Corrosive Round's Defense loss moved onto Corroded (refreshes, no stacking) | APPROVED_DESIGN (kept, 2026-10-24) | - |
| Duration rule: N of the target's turns | APPROVED_DESIGN (the designer's answer) | - |
| The actor keeps the rest of the current turn | APPROVED_DESIGN (kept, 2026-10-24) | - |
| Party Defense bands 12 / 20 / 28 | APPROVED_TRIAL (player sheet) | - |
| Enemy health and Defense curves | APPROVED_TRIAL (enemy sheet) | - |
| Gear prices; fight gold | APPROVED_TRIAL (economy sheet) | - |
| Revitalizer → Communion | APPROVED_DESIGN (the designer's decision) | - |
| The Alchemist uses the biggest heal that reaches | PROPOSAL (a fix) | confirm |
| Sixty-Four: no Brigandine, so the sheet's 28 holds | PROPOSAL | confirm |

---

## 9. Lethality review (added 2026-10-24)

The designer's rule:

- A telegraphed attack that is ignored may down Prometheus. That is intended.
- Cyrus and Alithia should survive ordinary telegraphed attacks, unless one is especially powerful.
- Enfina should survive most of them, but not major boss attacks.
- **Fair** lethality is telegraphed, avoidable, interruptible or protectable.
- **Unfair** lethality is an unclear warning, no viable response, or damage out of proportion to the available counterplay.

The probe lists every attack in the Chapter I fights, the laboratory sequence and Sixty-Four that is telegraphed, or that can down one of the party in one blow. They are in `docs/chapter1_inventory.csv`, section "Lethality review". The readings are for the designer to judge; they are not verdicts. Nothing has been changed.

### The telegraphed attacks

Only declared moves are telegraphed now.

**What they share:**
- The marked tiles show on the map (orange for an enemy's), and in the danger view.
- They land at the start of their user's next turn, once each of the other side has had a turn. So each of the party gets one turn to act.

**Ground Pound** (Ogre, Behemoth, Ash Warden):
- ×2.0 on a diamond of radius 1. Stepping two tiles out escapes it, and the party walks 6.
- Not hackable.
- Interrupted by downing its user, or taking its turn: stun, stagger, Persuade, Confused.
- The Ash Warden's stagger bar fills twice as fast while it winds one up.

**Rockfall** (Golem, Behemoth, Bellkeeper):
- ×1.6 on a diamond of radius 2, reaching 8. Three tiles out escapes it.
- Not hackable.

**Devour** (Erysichthon; the laboratory sequence's boss at 18):
- Deals no damage itself, so the probe's review leaves it out. Read by hand from `data/skills/enemies/devour.tres` and `Combat.swallow` / `_digest`.
- Only on somebody already in its grip (Grab first), and it lands only if they are still held.
- Swallowed, they take acid every turn and can't move. They are digested after two of its turns: downed outright, whoever they are.
- Out alive if its Belly Hole is torn open, it is staggered, or it falls. Breaking the grip before it lands stops it.
- Hackable.

| Attack | Where | Downs in one blow | Reading |
|---|---|---|---|
| Ground Pound | Ash Warden L10 and L18; Ogre and Behemoth L10 | Prometheus | FAIR by the rule: his downing is the intended cost of ignoring it |
| Rockfall | Bellkeeper, Golem, Behemoth L10 | nobody | FAIR |
| Devour | Erysichthon L18 (laboratory) | Anybody it digests, Enfina included, after two of its turns inside | For the designer. It is telegraphed three times over (the Grab, the declaration, two turns inside) with several ways out, so it is fair in form. But it can down Cyrus, Alithia or Enfina, which the rule allows only for a major boss attack. The laboratory runs will show whether the ways out are in reach. |

Erysichthon's other blows at 18 down nobody in one. Its best, Ravenous Bite, does 23 against Prometheus's 38.

**Open questions on the telegraphs:**

- **Stuck in the area.** A party member who can't move (Grappled, Snared, Frozen's −2, rooted) can't walk out. Hack doesn't apply to these moves, and InstaHack only cancels spells. So their only answers are downing the user or taking its turn. Check that at least one of those is in reach of a Chapter I party at each fight.
- **The protection options in Chapter I** are Guard (Enfina, herself), Bulwark I (allies beside her take 10% less), Alithia's Aura I and Mercy, and Intuition. Intuition reads an enemy's coming turn, but a declared move is marked already.
- **Out of reach in Chapter I:** illusions (Illusory Shepherd, 24+), interception (Iron Hide III, 41) and Phantom Body (32).

### Not telegraphed, and downs someone in one blow

| Attack | Where | Downs in one blow | Reading |
|---|---|---|---|
| **Self Destruct** (Bomber) | Lab Fight L8, City Fight L14, Dungeon Demo L14, lab stage A L16 | Prometheus (37 against his 33 at L8; 47 against 36 at L14) | Flagged as an UNFAIR candidate: the Bomber walks up and explodes on its own turn (×3.0, radius 3, and it dies too), and the only warning is the danger view. Its answers are killing it first (2 blows at L8), or keeping further than its walk plus 3 tiles away, which the danger view shows. **Kept as it is by the designer (2026-10-24): it teaches the player to read enemy moves.** |
| Titanfall (Barbarian, Pit Champion) | Sixty-Four, L64 | Prometheus, **Alithia, Cyrus** | UNFAIR candidate, at 64 only: the level-64 regression. |
| Follow Up Attack, Sweep Strike, Burner, Fireball | Sixty-Four, L64 | Prometheus | UNFAIR candidate, at 64 only. |

Prometheus at the Defense of 28 has 58 health at 64, and these are ordinary blows.

**Candidates to fix, for the designer to choose** (all PROPOSAL, none implemented):

- ~~Self Destruct: make it a declared move, or lower it at Chapter I levels.~~ Declined: the designer keeps it as a read-the-enemy lesson.
- **Level 64:** this is what the regression test is for. It is a later decision, and it would mean neither raising party health nor enemy damage broadly.
