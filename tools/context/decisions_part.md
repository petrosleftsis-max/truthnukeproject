
---

# Part 4 - The designer's decisions, and what is still open

## Standing decisions

These are settled; suggestions should work within them.

**Numbers and progression**

- **The numbers are the designer's.** Most are placeholders until playtesting. Weigh a suggestion against the progression plan's power level: tiers at 1/8/16/24/32/41/54/64, and the multipliers in Part 2.
- **No cooldowns, ever.** Limits come from gates, Uses Per Short Rest, Only Below Health, Needs Read, and placement.
- **No passives with a downside.** Glass Cannon became Kindling.
- **Spells never rank up.** A stronger spell is a new spell. Moves (Greatsword Attack, Burning Shot) do rank up. A row of the plan that is only a stronger version of a move is a rank on that move, never a second move.
- **Levels come at story milestones,** not from experience. The cap is 64, the isopsephy of ἀλήθεια. 55 is ΛΗΘΗ. There are five chapters, each leveling slower than the last.
- **The gate ladder** is World, Hermes, Pandora, Charon, Tartarus, Nemesis, Sophia, Ogdoad, Gnosis, Yaldabaoth. Outside fights there is Iris (built) and Mnemosyne (to come).
  - **Moira (Fate) is central to the story** and is never to be an ordinary gate; nor are Ananke or Nyx.
- **Gates will become scarce.** Late in the game several fights come between rests, so the resource-free fighters (Enfina, Cyrus) should outshine the casters there. Weigh caster against fighter by fights per rest.
- **Damage over time should beat burst in the long run,** but burst keeps its value. Catalyst (Cyrus, 64) works once a short rest: it sets off everything of his twice over, then restarts it all. Setting things off every turn was rejected, because it defeats the point of damage over time.

**Combat rules**

- **No taunts.** Nothing forces anybody's aim. Attention is held by placement, cover, conditions, holds, and the Pit Champion's Hemmed In and Exposed.
- **Systems belong to the creature, not to a category.** Immunities, boss presentation, stagger bars, size and the like are switches any creature can have. Bosses can be any size.

**Paths and moves**

- The paths are chosen at 24 and hand something out at 24/32/41/54/64.
  - The Illusory Shepherd keeps two things a tier.
  - Every Cyrus path has Slip Past as a secondary action, which he has from level 1 (Elusive).
  - The fighters' level 64 was made much stronger, since the casters already get the tenth gate.
- **Titanfall** is Greatsword Attack's rank at 64: x3.0, with a x1.5 splash within 2. Since the control trial (2026-10-24) it shoves nobody: Titanfall is the damage, Tremor the control. Earthsplitter and Meteor were taken out.
- **Ambush Strike** (Skirmisher): the first hit on each enemy in a fight does double.

**Illusions, zones and dispelling**

- **Illusions work for both sides.** An enemy's images and zones fool the party as the party's fool them.
- **Images:** while one of the party's images and its maker stand, everybody in the party can be invisible at once. The last image breaking reveals the maker. The maker falling reveals everybody.
- **Unseen zones:** the invisibility zone (Reality's Reflection) is unseen by the other side, and does not vanish when somebody in it is revealed.
- **Dispel Magic** reaches only what came through its own gate or a shallower one. Summons such as the Kindled Hound are dispellable, because a spell made them.

**Decided 2026-10-24**

- **Corrosive Round** keeps its -10% Defense on the Corroded condition itself: it refreshes, never stacks, and is cleansed with Corroded.
- **Catalyst** keeps its every-enemy scope and its exact rule (Part 1): once a short rest, every enemy, only the lingering conditions Cyrus himself inflicted. That is intentional - it is Cyrus's personal condition payoff. Team-wide condition synergy may come later as a separate mechanic, never folded into Catalyst.
- **The Bomber's Self Destruct** stays as it is, untelegraphed: it teaches the player to read enemy moves.
- **Erysichthon closes Chapter I.** It also appears briefly in the first encounter, as something to run from rather than a fair fight, and it has another enemy supporting it. Not implemented yet: its Chapter I level, the supporting enemy and the escape are OPEN.
- **Durations:** an effect lands for exactly N of its target's turns; on whoever is acting, the rest of the current turn comes on top (kept as it is).
- **The laboratory sequence** (a test harness, `docs/lab_sequence.md`): **Erysichthon at 18 is the primary boss variant**, after the City Fight's enemies (16) and the Hired Blades (17), with no rest or gate recovery between. The **Ash Warden at 18** is a second variant, for several turns a round, condition immunities, phases, hazards and stagger. Both are run twice, conserving and spending freely.
- **No control-resistance system** until the Erysichthon baseline shows that chain-control actually removes meaningful decisions.
- **Lethality:** an ignored telegraphed attack may down Prometheus; Cyrus and Alithia should survive ordinary telegraphed attacks; Enfina most, but not major boss attacks. Fair lethality is telegraphed, avoidable, interruptible or protectable.

## Healing and rest (2026-10-24; the healing revision implemented as a trial, the rests PROPOSAL)

Full analysis: `docs/healing_revision.md`, numbers in `docs/healing_inventory.csv` (probe `tests/run.sh healing`). Earlier rounds: `docs/healing_and_rest_proposal.md`, `docs/healing_cap_proposal.md`.

- **"Heal is 4-8" came from the export, not the game.** That range is never read. Heal today is (weapon base + 0.7 x Mindfulness) x 0.7 x 1.1 (Mercy I): 10 / 14 / 18 / 21 / 50 at levels 1 / 8 / 14 / 18 / 64. Part 3 now states every heal's real formula.
- **The share-of-missing-health hybrid is superseded.** It helped Enfina far more than Prometheus.
- **Implemented as a trial (APPROVED_TRIAL, 2026-10-24):** the revision below for Light Heal, Heal, Communion and Restoration.
  - The Priest and Ranger use the same files; Mend the Bound takes Heal's formula, without its ×0.9.
  - Mercy I multiplies the whole new amount, never a share of health.
  - The Mimic heals with its Self (Mimicry).
  - Grace, Purification, the Gate Nades, Medicine, Erysichthon's 6% meal and Soothed are unchanged.
- **The revision:**
  - Light Heal 8 + 0.15 Mind + 0.2 weapon base;
  - Heal 12 + 0.25 Mind + 0.3 weapon base;
  - Communion as Light Heal, per ally;
  - Restoration 50% of max + 0.25 Mind;
  - Grace full.
- **What the revision does:**
  - Heal is 16 / 18 / 20 / 21 / 35 at 1 / 8 / 14 / 18 / 64: 53-60% of Prometheus, 12-18% of Enfina. It undoes about one typical enemy blow on anyone through Chapter I.
  - Light Heal and Communion fall well behind today's late in the game: 22 against 36 and 43 at 64.
  - A weapon adds only 1-2.
- **The healing policy (APPROVED_DESIGN):**
  - share-of-health healing only on rare, limited moves: high-tier spells, cure potions, Resuscitate, specific boss mechanics;
  - no global heal cap: the cap analysis is an OPTIONAL_TUNING_TOOL;
  - party share heals are not capped unless a boss encounter proves a loop;
  - a boss heals big only through an explicit mechanic: once per fight or phase, telegraphed, with a cost or vulnerability;
  - a degenerate boss gets a per-boss cap or condition;
  - mythic full heals are OPEN until a boss defines one.
- **To check against the policy:** Soothed (Aura II), a 5% heal every turn.
- **Erysichthon's 6% meal stays the existing value.** Separate PROPOSAL: a meal heals one Heal of its level (21 at 18), one a turn, none from its own fallen, with Gorging (-20% Defense) or an exposed Belly Hole as the counterplay.
- **The rest framework,** implemented 2026-10-25 (see "Rests, Meditate and Devotion"):
  - 2-3 short rests per segment (2-4 late), each 50% of the missing health, no gates;
  - a long rest restores everything;
  - Meditate, option A: ceil(level / 6) points, a casting costs its depth, only the shallower half of Prometheus's open gates.
- **How the rests interact with healing:**
  - Short rests heal the big pools most between fights. The flat Heal helps the small ones most during fights.
  - Alithia's World castings (2, then 4 from level 8), and her two Devotion castings, are the segment's healing limit.
- **Still open:**
  - the enemy healers under the revision;
  - Mend the Bound, Gate Nades, Medicine and Purification;
  - whether Mercy I multiplies the revised amount;
  - Resuscitate can't be cast before 14 (Pandora), though learned at 9;
  - Intuition uses no stat at all.

## Control and limited uses (2026-10-24; APPROVED_TRIAL, implemented)

The audit: `docs/per_fight_audit.md`. The ledger has a row for each item below.

- **Titanfall:** x3.0 on the target and x1.5 to every enemy within 2, usable every turn. No shove, and so no impact Stun or Daze of its own. It is the damage upgrade.
- **Tremor** (Juggernaut, 64) is the control layer. Every hit of Enfina's also deals 50% to everybody beside the target. It shoves them a tile, and it still shoves the target a tile.
  - Where Titanfall's splash reaches the same enemy, only the harder of the two splashes lands (x1.5 either way at 64). Tremor's shove applies whichever was harder. Nothing is applied twice.
  - Any shove of hers that drives someone into something solid **Dazes** them; it used to Stun.
- **Dazed** (a PROPOSAL test value): lasts 1 turn.
  - **Effects:** two tiles less movement, no secondary action, no reactions. The target keeps its turn and its main action.
  - **Reapplying:** it never stacks; reapplying replaces it. Dazed again before the target's turn, it still lasts that one turn. Landing during the target's own turn, it covers the rest of that turn and the next, per the duration rule, and never more. The `tremor` suite checks this.
- **Enfina's step after a Tremor hit:**
  - **When:** automatic, in her own turn after the action - not a choice (the designer: choosing every turn would tire the player).
  - **Where:** one straight tile nearer the first enemy Tremor threw that still stands - the one leaving her closest beside them. The tile must be free and walkable, with nobody on it, no hazard mark, no harmful ground and no zone laid by the other side.
  - **Cost:** none - no movement spent, and it provokes nothing. No step while she is held in place, or after a felled target.
  - **Never** after a reaction (only in her own turn).
- **Stunning Blow:** keeps x0.8 and its 1-turn Stun, but is now limited to uses per short rest: 1 at 41, 2 at 54, 3 at 64. A long rest restores them all.
- **Per fight became per short rest.** Every use limit now recovers on a short rest, and a long rest restores it as well: Recant, Catalyst, Minefield, Grand Design, the Conductor's free amplifications (Overcharge, Deep Current), and Conduit. In a dungeon these carry from fight to fight until a rest. Every fight elsewhere starts with all of them, as with gates.
  - **Unchanged:** trigger conditions (Ambush Strike, Illusory Guardian, Afterimage), Kindling's build-up, durations to the fight's end, and boss phase, stagger and encounter effects.
  - **The Trapper's free Small Bomb** is once a short rest too (the designer, 2026-10-25: "it adds flavor to his short rest").
- **The short and long rest plug-in** (`Campaign.short_rest`, `long_rest`) restores those uses. The designer gave the rests' details on 2026-10-25 (below, "Rests, Meditate and Devotion").
- **Nothing in play changes yet.** Every converted limit is learned at 24 or above, and today's dungeons are at 14 and 18.

## The laboratory, short rests and half casters (2026-10-25; implemented)

- **The first lab run** (conservation, Erysichthon variant) ended in the first fight.
  - Alithia fell in round 3 to both Rangers' hits plus their Burn and Poison. Prometheus fell in round 5 to a Burner, its Burn and one Striker blow (51 against his 38). Enfina fell in round 9 to two Self Destructs (72), a Burn and the Striker.
  - The party healed 8 and used no items; the enemies healed 182, the Rangers mostly themselves.
  - With no rests and the fallen kept down, the second fight was Cyrus alone.
- **The second lab run** (`docs/lab_runs/2026-10-25_011629`; conservation, Erysichthon variant) had short rests, Resuscitate at a rest, the kit, half-caster Rangers, Tremor's free step and damage over time credited to whoever caused it. It ended in the second fight, Lab B, as the first run did; neither run reached Erysichthon.
  - **Lab A (City Fight enemies, 16): won in round 9** (the first run took 11), with three of the four standing: Enfina 69/146, Cyrus 52/86 and Alithia 42/86.
    - Prometheus fell in round 3, all to Ranger 1: a 15 hit with its Burn (8), then a 20 hit, 43 against his 38. Nobody else fell.
    - Cyrus finished 6 of the 11 enemies (3 of them with his Burn), Prometheus 2, Enfina 1 and Alithia 1. Bomber 1's own Self Destruct is credited to Cyrus's Burn, at the same moment (VERIFY).
    - Damage on the party: 390 (276 from hits, 114 lingering). Ranger 2 dealt 116, Ranger 1 114, the Striker 94, Bomber 1 36 and the Mimic 12. Enfina's own Trailblaze Burn cost her 18. Damage on the enemies: 903.
  - **The rest after Lab A:** Enfina got back 39, Cyrus 17 and Alithia 22, half of what each had lost. No gates came back.
    - Alithia used Resuscitate through Pandora on Prometheus, so he started Lab B at 17/34 health; his maximum went down from 38 to 34.
    - The party went into Lab B with 258 of 352 health.
  - **Lab B (Hired Blades, 17): lost in round 5**, all four down. The first run lost it in round 4, with Cyrus alone.
    - Enfina fell in round 2, at 108, having taken 109: the Pit Champion's Greatsword plus Follow Up twice (76), Hired Bow 1 (10, with 6 of Poison) and Hired Bow 2 (17).
    - Prometheus fell in round 2, to one Hired Bow 1 hit of 22 against his 17.
    - Alithia brought Enfina back in round 3 with Resuscitate (66/131). Enfina took 59 that round and got 52 from Cyrus's Mediocre Cure Potion in round 4. She fell again in round 5 to Hired Bow 1's Poison.
    - Alithia fell in round 5 to Hired Bow 2's Poison, having taken 68 (38 from the Pit Champion, 30 from Hired Bow 2) against her 64.
    - Cyrus fell in round 5 to two Pit Champion blows and Sellsword 1 (66 against his 47).
    - The party downed Sellsword 2 (Alithia) and Hired Bow 1 (Cyrus's Burn); the first run downed none. The Pit Champion (119 taken), Hired Bow 2 (none taken) and Sellsword 1 (70 taken) were still standing.
    - Damage on the party: 407, 222 of it from the Pit Champion. Damage on the enemies: 396.
  - **Healing:**
    - Lab A, party 192: Alithia 168 (two World Heals of 23, a Heal Gate Nade of 23, a Communion Gate Nade of 33 on each of three) and Enfina 24 (Medicine).
    - Lab A, enemies 105: Priest 1 63 (three Heals on the Striker), Priest 2 42 (two on itself). The Rangers cast no Heal and spent no gates.
    - The rest: 78, and Prometheus back at 17.
    - Lab B, party 52 (the potion); enemies none.
    - In the first run the party healed 8 and the enemies 182, 119 of it from the Rangers.
  - **Items:** 7 of the kit's 16 used.
    - Lab A: Cyrus 2 Small Bombs and the Blinding Bomb; Enfina a Medicine; Alithia both Gate Nades. Lab B: Cyrus's Mediocre Cure Potion, on Enfina.
    - Left unused when the party fell: Enfina 2 Mediocre Cure Potions and a Cure Potion; Prometheus 2 Medicines, a Mediocre Cure Potion and the Fireball Gate Nade; Alithia a Mediocre Cure Potion and a Medicine.
    - Enfina fell twice still holding three healing potions. Prometheus used nothing in either fight. The first run had no items.
  - **Gates spent:**
    - Lab A: Alithia Pandora 1, Hermes 1, World 2; Prometheus Hermes 2, Pandora 1; Priest 1 World 3; Priest 2 World 2; the Rangers none. In the first run the Rangers spent 7 (World 6, Hermes 1), Prometheus 5 and Alithia 2.
    - At the rest: Alithia Pandora 1 (Resuscitate).
    - Lab B: Alithia Hermes 1 and Pandora 1 (Resuscitate), Prometheus Hermes 1.
    - Left at the end: Alithia World 2, Hermes 1, Pandora 0; Prometheus World 4, Hermes 0, Pandora 2. Alithia's last two Pandora castings both went on Resuscitate.
  - **What the changes did, by the numbers:**
    - The overall result did not change: the run was lost in Lab B.
    - Lab A was won with three standing instead of one, two rounds sooner. The party healed 192 instead of 8, 146 of it from items. The enemies healed 105 instead of 182.
    - The Rangers' heals went from 119 to 0. A half caster at 16 still has World 4 and Hermes 2, so running out of gates does not explain it. The designer burst them down this time rather than wearing them down with damage over time, and the log agrees:
      - Neither Ranger took any damage in rounds 1-4. A Ranger heals itself only below half its health (about 91 at 16).
      - Ranger 2 had lost 44 at its round-5 turn, just above half. Cyrus then hit it for 26 straight after, and 26 in round 6: down before its next turn.
      - Ranger 1 was at 74 at its round-7 turn, walked away, and was caught by Enfina's Grab. At its round-8 turn it was at about 10, well under half, but it did not heal. It seems to have spent the turn breaking free and walking off, and was grabbed again. Cyrus finished it at the start of round 9.
      - VERIFY: the log does not record a break-free. A Ranger held below half might be expected to heal itself where it stands, since a self-heal needs no movement.
    - The rest and Resuscitate put all four into Lab B, against Cyrus alone in the first run. The fight lasted one round longer and two enemies fell instead of none. Prometheus lasted one enemy turn after coming back. Enfina, revived in the fight, lasted two more rounds.
    - Nine items were never used, five of them heals.
    - Tremor's step did not come up: Enfina is 18 here, and Tremor comes at 64.
  - **The user's painted cover** on the upper left of `maps/city_fight.tscn` is in the run if it was saved before it; the log does not say. The map is Lab A's, and also used by the Dungeon Demo's third fight (`dungeon_demo/dungeon_3_city.tres`), `boss_bellkeeper`, `level_64_showdown`, `sizes_colossus` and `encounter_03_watcher`, so the cover is in all of those. The designer is fine with that: no lab-only copy (2026-10-25).
- **Short rests in the lab** (APPROVED_TRIAL; the 50% is a PROPOSAL test value):
  - Between stages, everybody standing gets back half of what they lost, along with the uses spent until a rest. No gates come back.
  - The fallen stay down unless somebody who knows Resuscitate (Alithia) spends a casting of it on them at the rest: Pandora or deeper, back with 50% health and 10% weaker, as in a fight. If Alithia is down, nobody can. Since 2026-10-25 they are also rested, and the weakening lasts only until a long rest (below).
- **A kit** (PROPOSAL test values, tier II for a party at 18) fills every Simple Baldric, 4 slots each. It is all the party has for the three fights: what is used is gone.
  - **Enfina:** 2 Mediocre Cure Potions, a Cure Potion, a Medicine.
  - **Cyrus:** a Small Bomb, Smelling Salts (since 2026-10-25, in place of his second Small Bomb), a Blinding Bomb, a Mediocre Cure Potion.
  - **Prometheus:** 2 Medicines, a Mediocre Cure Potion, a Fireball Gate Nade.
  - **Alithia:** a Communion Gate Nade, a Heal Gate Nade, a Mediocre Cure Potion, a Medicine.
- **Half casters** (APPROVED_TRIAL): a half caster gets the gates of a full caster at half its level, rounded up, like a D&D paladin.
  - The Ranger is one. At 16 it has World 4 and Hermes 2, where a full caster has World 4, Hermes 3 and Pandora 2. At 64 it has a full caster's gates of 32.
  - Its Heal still costs a World casting.
  - The designer confirmed this reading (2026-10-25: "this is correct"), rather than half of each gate's castings at its own level.
- **The lab's logs** now credit each tick of damage to the source of its condition, and each reaction to the reactor, rather than to whoever's turn it was.
- **Lifting conditions** (the user's, 2026-10-25; implemented):
  - Cured of something that held them in place (Crystallised) in their own turn, a combatant can walk again: all their movement, or what they had not yet walked.
  - A cleanse that lifts only so much (Medicine lifts one) and a heal that lifts some (Mercy II) let the player choose which of several comes off, the most recent first, each with its turns left. The other side lifts the most recent.
- **Reactions:** when someone leaves the reach of two or more at once, every one of them whose reaction is unspent swings, and the player is asked for each of theirs in turn. Reach is counted in straight steps, so a diagonal neighbour is 2 away and outside a reach of 1.

## Rests, Meditate and Devotion (2026-10-25; implemented)

The designer's answers of 2026-10-25. The rules are APPROVED_TRIAL; the numbers the designer did not give are PROPOSAL test values, marked.

- **When rests happen:** whenever something calls for one: a conversation (`do Campaign.short_rest()` or `long_rest()`), or a dungeon between its fights. The Dungeon Demo and the lab take a short rest between each fight. A segment has 2-3 short rests on average, 2-4 late in the game; nothing counts them.
- **A short rest:**
  - Everybody standing gets back half of what they lost (the 50% is a PROPOSAL test value).
  - Uses spent until a rest come back: the use limits, the Trapper's bomb, one of Alithia's two Devotion castings.
  - No gates come back, except through Prometheus's Meditate.
  - The fallen stay down unless Resuscitated. Somebody Resuscitated at the rest is then rested too: half of what they still miss, so 75% of their (weakened) health in all.
- **A long rest** brings back everything:
  - everybody up and at full health;
  - the 10% weakening from being brought back lifted (it used to last for good);
  - every gate, those opened outside a fight (Iris) too;
  - Meditate, both Devotion castings, and every use spent until a rest.
  - No dungeon has a long rest yet.
- **Meditate** (Prometheus's passive; Alithia gets none):
  - At a short rest, once until the next long rest, he brings back castings he spent.
  - **Points:** one every six levels, rounded up. **Cost:** a casting costs its gate's depth (World 1, Hermes 2, Pandora 3). **Depth:** nothing deeper than the shallower half of his open gates, rounded up.
  - So: L1 1 point (World), L8 2 (World), L14-18 3 (up to Hermes), L24 4 (Hermes), L33 6 (Pandora), L45 8 (Charon), L55 10 (Tartarus), L64 11 (Tartarus).
  - These are option A of the rest proposal, PROPOSAL test values. Iris's outside gates are not among them; a long rest brings those back.
  - It is offered on the rest screen. The Dungeon Demo's own recovery (once a run, 3 points) was taken out, so Meditate is not a second one (PROPOSAL: the proposal said Meditate "would be that recovery").
- **Devotion** (Alithia's passive; the name is a placeholder, PROPOSAL):
  - Two castings of her own. Each pays for a Heal or a Dread Visage (on one person) in place of its gate, and is spent before any gate.
  - One comes back at a short rest, both at a long rest. In a dungeon they carry from fight to fight; every other fight starts with both.
- **Smelling Salts** (PROPOSAL test values, for the lab): a consumable that brings somebody fallen beside you back up with 50% of their health, 10% weaker until a long rest, as Resuscitate does. Cyrus carries it in the lab kit, in place of his second Small Bomb.
- **Not decided:** whether a short rest ends conditions; where the long rests fall; whether a rest called from a conversation should open the rest screen, so Meditate and Resuscitate can be chosen there (OPEN).

## Known near-twins among the spells

Spells that are close to copies of each other. They are candidates to make more distinct, or to keep on purpose:

1. **Fire Blast, Wind Shot, Rock Throw** (level 1, World): all x1.2, range 20, single target. Only the element differs, which is the point of them (picking the element a target is weak to).
2. **The Idol radius-1 line:**
   - Holy Splash (8, Hermes, x1.1)
   - Judgement Hammer (41, Nemesis, x3.0, with a shove; Battle Chaplain)
   - Divine Verdict (54, Gnosis, x4.2, ignores 50% defence)
   - Revelation (64, Yaldabaoth, x5.0, ignores 75% defence)
   
   Verdict and Revelation are the same shape with bigger numbers.
3. **Piercing Light, Judgment, Accusation:**
   - Piercing Light (24, Charon): single target, x2.2, ignores 25%.
   - Judgment (32, Tartarus): x3.4, ignores 50%.
   - Accusation (32, Charon, Inquisitor): x1.5 plus Accused, but only on somebody read.
4. **Holy Lance and Holy Spear:**
   - Holy Lance (5, Hermes): a line 10 long and 3 wide, x1.2, contested.
   - Holy Spear (24, Pandora, Battle Chaplain): a line 6 long, x1.6.
5. **Gnostic Tempest and Stolen Sun:**
   - Gnostic Tempest (54, Gnosis): radius 2, x5.4 Plasma.
   - Stolen Sun (64, Yaldabaoth): radius 2, x6.0 Fire.
6. **The Frozen line:**
   - River Flow (8, Hermes): radius 2, x1.3, Frozen 2 turns at 0.2.
   - Frozen River (16, Pandora): radius 2, x1.8, Frozen 3 turns at 0.25.
   - Glacial Tide (41, Sophia): radius 3, x2.2, Frozen 2 turns at 0.25.
7. **The Burn line:**
   - Burner (8, Hermes): radius 2, x1.4, Burn 3 turns at 0.2.
   - Wildfire (16, Pandora): radius 2, x2.1, Burn 3 turns at 0.4.
   - Fireball (9, Pandora) is close in power: radius 5, x2.0, hits both sides.
8. **Wind Swoon and Gust Blast:**
   - Wind Swoon (8, Hermes): radius 2, x0.8, Windswept.
   - Gust Blast (24, Hermes): single target, x1.2, a 3-tile shove, Windswept.
9. **Communion and Revitalizer** - settled: Revitalizer was taken out and Communion took its place (Alithia's kit, the Priest's, and the Gate Nade). Revitalizer was heal x1.3, radius 3, range 20 from level 9; Communion is x0.6, radius 2, range 10 from 16. Alithia now has no group heal before 16, and neither do Priests below 16.
10. **Heal and Light Heal** (World): Light Heal is a smaller Heal, but a secondary action.
11. **Hermes Step and Mist Step** (Hermes, a 6-tile teleport): Hermes Step moves an ally, as a main action. Mist Step moves himself, as a secondary action.
12. **The four Edges** (Elemental Vanguard melee spells), in two pairs:
   - Flame and Frost (Pandora, x1.8): Burn, or -2 movement.
   - Storm and Stone (Charon, x2.2): a 2-tile shove, or -10 defence.

Also: since spells stopped ranking up, the enemy Sorcerer and Priest no longer get the stronger version of Burner and River Flow past level 16. They cast the level-8 versions at any level.

## Open design variables

These are OPEN: no sheet documents them, or documents them only in part. The values shown are PRESENT (what the game does now), not the design.

**The party**
- **Health:** the party sheet repeats the current implementation (Enfina 130 → 190, Cyrus and Alithia 75 → 115, Prometheus 30 → 58, evenly between). It was derived from the game, not designed.
- **Movement:** 6, plus Cat Burglar's +2, Feather Charm +1, Elemental Vanguard to 8.
- **Initiative:** Cyrus 8, Alithia 7, Enfina 6, Prometheus 5.
- **Resistances:** none, beyond those from passives.
- **What gear gives:** weapons give a base of 7-11, armour 12/20/28, charms one small passive. No tier III-IV gear exists; the economy sheet prices it but doesn't say what it gives.
- **The paths' contents:** their moves and numbers, except the Illusory Shepherd, which has its own sheet. The progression sheet names the tiers only.
- **Spells the progression sheet doesn't list:** Fireball, Wind Swoon, Gust Blast, Crystalise, the Edges and others.
- **Which gate each spell uses, and castings per gate:** the gate table is D&D's, stretched to 64.
- **Kindling:** +5% per spell cast, capped at 15/30/45%.
- **Catalyst:** settled (APPROVED_DESIGN, 2026-10-24) - every enemy, Cyrus's own conditions only, as the rule in Part 1 says.
- **The party's summons:** Kindled Hound 18 → 110 health, Illusory Dragon 100 → 400.

**Enemies**
- **Damage output:**
  - their skills' multipliers;
  - their weapon base per fight, 8-12 now;
  - which moves they get as they level. No enemy has a move beyond the Gates of Pandora or a level-1 attack's rank.
- **Kind assignment:** which enemy is frail, average or tanky was decided by the implementation, not by the sheet.
- **Bosses, the Behemoth and the Colossus:**
  - health: Ash Warden 300 → 1500, Bellkeeper 160 → 900, Erysichthon 300 → 2100, Behemoth 120 → 700, Colossus 200 → 1200;
  - Defense set per fight;
  - phases and stagger bars.
- **Other enemy numbers:** movement (4-9), initiative (3-4), resistances, nerve thresholds, bribe prices, and the AI's dials.
- **Fights:** how many enemies, which ones, and at what level each fight sets them.

**Items and money**
- **Condition bottles:** their strength and their price, 120 each.
- **Gate Nades:** power Heal 30, Crystalise 40, Fireball 50, Communion 50; price 60 for a gate 1-2 spell, 150 for gate 3.
- **Spellbook prices:** 150/375/750/1500/2000 by gate depth. The consumables sheet prices only scrolls.
- **Containers:** slots and prices.
- **Stealth tools** (darts, drugs, pebbles, robes): unpriced.
- **Loot and story gold:** what enemies carry, and gold found in the story (the sellswords' 200 purse).
- **Parley costs:** 150 to buy off the Pit Champion.
- **Dungeon rests:** the gate-recovery cost.
- **What stores stock.**

**Systems**
- **Conditions:** how strong and how long most are (Blind, Stunned, Fear) and enemy moves' damage-over-time dials.
- **Nerve:** leader down 40, half the side down 25, hurt 15 / badly hurt 30, last standing 30, afraid 20.
- **Grip:** break-free chance 20-80%.
- **Bosses and the arena:** stagger bars, hazard damage, powder keg and object damage.
- **Minigames:** hacking tries and edits, stealth alert levels, quick-time windows.
- **The story's pace:** the level of each story fight (1, 8, 14) and the chapter bands (ending at 18, 33, 45, 55, 64; the designer chose this variant).

## Open questions

- **Devour's lethality** (Erysichthon, the laboratory's boss at 18). It deals no damage itself: it swallows somebody already in its grip, announced a turn ahead. After two of its turns inside, they are digested and downed outright, whoever they are, Enfina included. The ways out are tearing its Belly Hole open, staggering it, downing it, or breaking the grip before it lands; it is also hackable. So it is fair in form, but it can down Cyrus, Alithia or Enfina, which the lethality rule allows only for a major boss attack. The laboratory runs will show whether the ways out are in reach. Its other blows at 18 down nobody in one; its best, Ravenous Bite, does 23 against Prometheus's 38.
- **Party health at high levels** (the biggest issue).
  - The party's health barely grows: Enfina 130 → 190, Cyrus and Alithia 75 → 115, Prometheus 30 → 58.
  - Hits grow about 5× from the attribute (10 → 85), and more again from bigger multipliers.
  - At level 14 a Barbarian needs about 3 swings to down Cyrus (35 damage against 83 health). At 64 it needs one (Titanfall, 129-143).
  - But the designer's playtest of the level-64 fight ("Sixty-Four": 4 against 9 plus a summon) went the other way: won easily the first time, and the second time nobody fell and only Alithia was hit, once.
    - An automated run that let only the enemies act had downed all four in one enemy round. That is the worst case, not play.
    - In play the party has the initiative (5-8 against the enemies' 3-4), so all four act first.
    - At 64 they hit first with area spells that one-shot the frail and nearly kill the average: Stolen Sun ×6.0 does about 238 to a frail enemy (85 health), 167 to an average one (190), 159 to a tanky one (265-280).
    - The Illusory Shepherd's Illusory Guardian makes the first blow on each of the party miss.
    - So at 64 the fight is decided by who acts first, and the party always does. No enemy has a move past the Gates of Pandora or a level-1 attack's rank, so none has an answer.
  - One option is to scale the party's level-64 health by the same factor enemies get: about Enfina 600, Cyrus and Alithia 350, Prometheus 140. That would bring back about 3 swings at 64.
  - The player sheet (player_hp_defense_progression.csv) keeps the same health and raises Defense to 28 from level 17.
    - That takes a level-64 Titanfall on Cyrus from 143 to 126: still more than his 115 health.
    - It takes a Fireball on Prometheus from 95 to 84: still more than his 58.
- **Durations:** settled (2026-10-24). "N turns" is N of the target's own turns - Warning Shot's slow is 2 of theirs, a 3-turn Burn ticks 3 times. Only on whoever is acting does the rest of the current turn come on top (Run 1: this turn and the next) - kept by the designer.
- **Enemy turns at level 64** take about 2 seconds each to plan with a full kit (10 enemies in about 21 s). The goal has been under a second.
- **The other near-twins above** - kept for now (the designer's call, 2026-10-23).
- **The Mnemosyne gate**, for outside fights: whether it matches gate 5 or 6.
- **Later backpacks** may get effects of their own. The first is the Grenadier's Pack, which holds two bombs a slot.
- **Factions** exist as a system (knowing one gives +15% damage against it), but no enemy has one yet.
- **The economy sheet** has rows nothing in the game uses yet:
  - whole-mission payouts;
  - per-item resale rates for junk and rare artifacts;
  - inns, horses, healers, and Gate Nade crafting.
- **The sellswords' contract** on the lab map hands over a 200-gold purse, their uncollected advance. That is 4-7 contracts' pay at tier I.
