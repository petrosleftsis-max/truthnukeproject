# Applying docs/progression.csv

How each row of the CSV goes into the game. Decisions from 2026-10-22: subclasses as
in the CSV (chosen at 24, its names); keep every skill the CSV does not list; the
CSV's levels win, except the existing Holy Lance, which stays - the CSV's "Holy
Lance (Pen 25%)" is a new spell under another name; the CSV's numbers stand; no
cooldowns; Cat Burglar and Cover Runner combined; no Glass Cannon; "Double Strike"
is Follow Up Attack; and a row that is only a stronger version of a move
(Basic Strike -> Heavy Swing) is that move growing stronger, not a second move.

## Ranks

A move growing stronger is a **rank** on it (`SkillDefinition.ranks`,
`SkillRank`): from the rank's level its multiplier, its condition's damage dial
and its condition's duration stand in for the skill's own. The Levels page says
so at that level.

## Enfina

| CSV (level) | In the game |
|---|---|
| Basic Strike 1.0 (1) | **Greatsword Attack**, 1.0 |
| Heavy Swing 1.5 (8) | Greatsword Attack, rank: 1.5 |
| Guard (1) | **Guard**, from 11 to 1 |
| Iron Hide I (1) | new passive: takes 10% less damage |
| Bulwark I (8) | new passive: allies beside her take 10% less damage (aura) |
| Taunting Shout 0.6 (16) | new skill, **Battle Cry**: a cone that hits and shoves everybody in it back a tile - no taunts (see "Taunts") |
| Iron Hide II (16) | new passive: 10% less again (20%) |
| Armor Shred 0.9, -20% defence, 2 turns (24) | new skill |
| Double Strike 1.5 (32) | **Follow Up Attack**, from 12 to 32, 1.4 to 1.5 |
| Momentum I (32) | new passive: +10% damage on a turn she has not moved |
| Short Stun 0.8, 1 turn (41) | new skill, **Stunning Blow** |
| Iron Hide III (41) | new passive: half of any hit on an ally beside her is hers instead |
| ~~Finisher 2.2 (54)~~ | removed 2026-10-25 (`docs/handoff_0.1/finisher_removal_momentum_synergy.md`): Titanfall at 64 outpaces it; Momentum covers Sweep Strike at 54 |
| AOE Sweep 1.4, light CC (54) | **Sweep Strike**, from 3 to 54, 1.2 to 1.4, and a step back for whoever it hits |
| Bulwark III (54) | Bulwark reaches two tiles and gives 20% |
| Ultimate Smash 2.5 (64) | Greatsword Attack, rank **Titanfall**: x3.0, and x1.5 to everybody within 2 of who it lands on, shoved a tile (your change, 2026-10-23) |
| Momentum II (64) | +15% more when she has not moved (25%) |

## Cyrus

| CSV (level) | In the game |
|---|---|
| Basic Shot 1.0 (1) | **Gun**, 1.35 to 1.0 |
| Light Cover Leap (1) | new secondary action, **Cover Leap**: up to 3 tiles, into cover, nothing reacts |
| Cover Runner I (1) + Cat Burglar | **Cat Burglar I**: +2 movement on a turn he starts in cover |
| Poison Strike 1.0, 0.2, 3 turns, no reactions (8) | **Poison Dart**, from 3 to 8, 0.9 (cyrus_damage_adjustments.csv), 0.2, 3 turns, and the poisoned cannot react |
| Agile I (8) | new passive: 5% less damage while in cover |
| Burn Bomb 0.9, 0.35, 3 turns (16) | **Burning Shot**, from 13 to 16, 0.8 (cyrus_damage_adjustments.csv), 0.35, 3 turns (Burn's +2 movement is the CSV's "+2 speed") |
| DoT Master I (16) | new passive: his lingering damage 10% harder |
| Wide Poison 0.8, 0.2, 3 turns, cone (24) | new skill, **Venom Fan**, 0.7 (cyrus_damage_adjustments.csv) |
| Cover Runner II (24) | **Cat Burglar II** (today's Cat Burglar, from 8 to 24): +2 movement anywhere, climbs anywhere |
| Strong Burn 1.1, 0.45, 3 turns (32) | Burning Shot, rank: 0.95 (cyrus_damage_adjustments.csv), 0.45, 3 turns |
| Minor Slow Shot 0.9, 2 turns, -1 movement (32) | **Warning Shot**, from 1 to 32, those numbers |
| Agile II (32) | new passive: stepping into cover sets off no reaction |
| Armor Weakness 0.7, -25% defence, 2 turns (41) | new skill, **Exposing Shot** |
| DoT Master II (41) | +20% more and a turn longer |
| Synergy I (54) | new passive: the party hits anybody carrying a harmful condition 10% harder |
| Synergy II (64) | and 10% more again on whatever he put it on |

## Prometheus

| CSV (level) | In the game |
|---|---|
| Cantrip 0.7 (1) | **Fire Burst**, **Zephyr Dart**, **Caucasus Shard** all from 1 |
| Small Firebolt 1.2 (1) | **Fire Blast** |
| Glass Cannon I-III (1, 16, 54) | **Kindling I-III** instead - see "Instead of Glass Cannon" |
| Early Windswept 0.8, 0.1, 2 turns (8) | **Wind Swoon**, from 6 to 8, those numbers |
| Small Burn 1.4, 0.2, 3 turns (8) | **Burner**, from 5 to 8, those numbers |
| Elemental Affinity I (8) | new passive: +10% damage on anybody weak to the element |
| Strong Burn 2.1, 0.4, 3 turns (16) | new spell, **Wildfire** (Gates of Pandora) - spells do not rank up, so not Burner grown stronger |
| Crystallize I 0.8, 0.1, 3 turns (16) | **Crystalise**, from 7 to 16, those numbers |
| Mid Windswept 1.2, 0.15, 2 turns, push (24) | **Gust Blast**, from 6 to 24, those numbers |
| Contest Insight I (24) | new passive: +10 to his stat in a contest |
| Big Nuke (gate 5) 3.1 (32) | new spell, **Tartarus Flame** |
| Elemental Affinity II (32) | +10% on anybody taking lingering damage |
| High-tier Nukes (gate 7) 4.2 (41) | new spell, **Ire of Sophia** |
| Contest Insight II (41) | +10 more against anybody carrying a harmful condition |
| Level-9 Spell 5.4 (54) | new spell, **Gnostic Tempest** |
| Level-10 Spell 6.0 (64) | new spell, **Stolen Sun** |
| Elemental Mastery (64) | one more casting through the deepest gate open to him |

## Alithia

| CSV (level) | In the game |
|---|---|
| Cantrip 0.7 (1) | **Votive Flame**, **Water Spike** |
| Small Heal (1) | **Heal** |
| Mercy I (1) | new passive: heals 10% more |
| Holy Splash 1.1 (8) | new spell |
| Frozen I 1.3, 0.2, 2 turns (8) | **River Flow**, from 7 to 8, those numbers (Frozen: -2 movement, no secondary) |
| Aura I (8) | new passive: allies within 2 take 10% less damage |
| Group Heal (16) | new spell, **Communion**: heals every ally within 2 of where it lands |
| Frozen II 1.8, 0.25, 3 turns (16) | new spell, **Frozen River** (Gates of Pandora) - not River Flow grown stronger |
| Mercy II (16) | her heals lift one harmful condition |
| "Holy Lance (Pen 25%)" 2.2 (24) | new spell, **Piercing Light**, ignores a quarter of defence (Holy Lance stays as it is) |
| Aura II (24) | her aura also mends 5% of health as their turns start |
| Judgment 3.4, Pen 50% (32) | new spell |
| Reserved Power I (32) | one more casting through her deepest gate |
| Frozen AOE 2.2, 0.25, 2 turns (41) | new spell, **Glacial Tide** |
| Advanced Cleanse (41) | new spell, **Purification**: heals and lifts every harmful condition |
| Mercy III (41) | whoever she heals takes 20% less damage until their next turn |
| Level-9 Penetration Spell 4.2, Pen 50% (54) | new spell, **Divine Verdict** |
| Elite Heal (54) | new spell, **Restoration**: half their health back |
| Reserved Power II (54) | one more again |
| Level-10 Penetration Spell 5.0, Pen 75% (64) | new spell, **Revelation** |
| Capstone Heal (64) | new spell, **Grace**: every ally within 3 back to full |
| Radiant Guardian (64) | while she stands, the party takes 10% less damage |

## New mechanics this needs

- Damage reduction: passives (Iron Hide, Agile in cover, Radiant Guardian) and conditions (Bulwark's and Aura's, Mercy III's).
- On a turn not moved (Momentum).
- Lingering damage harder and longer (DoT Master).
- Against a target carrying a harmful condition (Synergy, Contest Insight II); weak to the element, or taking lingering damage (Elemental Affinity).
- A bonus to the stat in contests (Contest Insight).
- More castings through the deepest gate (Reserved Power, Elemental Mastery).
- Heals that lift a condition, or leave a ward (Mercy II, III); heals worth a share of health (Restoration, Grace); healing on the turn's start (Aura II).
- Cover: standing beside something that blocks sight. Cat Burglar I, Agile I and II, Cover Leap.
- A skill only for somebody at half health or less (Finisher) - removed with it on 2026-10-25.

## Instead of Glass Cannon: Kindling

**Kindling I-III** (1, 16, 54; picked 2026-10-23): every spell he casts in a fight
makes the ones after it 5% hotter, up to 15 / 30 / 45%. Cantrips take no gate,
so they neither stoke it nor are stoked. Turned down: Stoked Fire (a flat 10 / 20
/ 30%) and First Spark (more on anybody at full health).

## Cooldowns

Only three rows mention one:
- **Finisher** ("long CD"): an execute instead - usable only on somebody at half health or less (removed 2026-10-25). Other ways: it takes both actions, or it lands a turn later (declared, as Earthsplitter was).
- **Elemental Mastery** ("extra slot or reduced cooldown") and **Reserved Power II** ("extra high-tier slot or CD reduction"): the extra slot.

## Subclasses - the moves (built 2026-10-23)

Chosen at 24; a feature at 24, 32, 41, 54 and 64 (the Illusory Shepherd two, as
its CSV has them). Numbers are set against the CSV's tiers: a debuffing hit
x0.8-0.9 at 24-41, a single hit x1.5-2.5, spells by gate (gate 4 x2.2, gate 5
x3.1-3.4, gate 7 x4.2). Old subclass moves reused say what they were. All of
this is built; the picks of 2026-10-23 are in the rows. Cyrus has Slip Past as a
secondary action from level 1 (his base kit's Elusive), on every path.

### Enfina

**Vanguard** - the charge
| Lv | Move | What it does | From |
|---|---|---|---|
| 24 | Adrenaline (passive) | While she is Burning, her hits deal +30% and set the target Burning | Berserker, as is |
| 32 | Leading Charge (passive) | After walking 3+ tiles in a turn, her next hit that turn +20% (Momentum's opposite: stand or charge) | new |
| 41 | Daunting Roar (skill) | Cone of 2: x0.6 and Fear 1 turn (they cannot come closer) | Guardian; was no hit |
| 54 | Unstoppable (passive) | Nothing slows, roots or holds her: her movement cannot be lowered, and she cannot be Grappled or Pinned | new |
| 64 | Rampage (passive) | Felling somebody on her turn gives her main action back, and 3 more movement - it can chain | new (in place of Spearhead) |

**Juggernaut** - the immovable
| Lv | Move | What it does | From |
|---|---|---|---|
| 24 | Chain Hook (skill) | Range 5: x0.9 and pulls them up to 4 tiles to her | Controller; was x0.5 |
| 32 | Hamstring (skill) | Melee x1.0, -3 movement for 2 turns | Controller; was x0.8 |
| 41 | Pin Down (skill) | Melee x1.0, Pinned: they cannot walk on their next turn | Controller; was x0.6. Swapped with Hamstring: a root is the stronger hold |
| 54 | Immovable (passive) | 10% less damage, and nothing shoves or pulls her | new (the draft's +8 defence) |
| 64 | Tremor (passive) | Every hit also hits everybody beside the target for half, shoving them all a tile; into something solid, stunned | new |

**Warden of Cover** - the protector
| Lv | Move | What it does | From |
|---|---|---|---|
| 24 | Shield Bash (skill) | Melee x0.9 and Fear 2 turns | Guardian, as is |
| 32 | Covering Stance (passive) | Her Guard covers allies beside her too | new |
| 41 | Hold the Line (passive) | Allies in her Bulwark cannot be shoved, pulled or knocked back | new |
| 54 | Interceptor (passive) | Iron Hide III reaches allies within 2 tiles, not only beside her | Guardian; its +8 armour dropped |
| 64 | Last Wall (passive) | While she stands, no blow fells an ally within 2: it stops at 1 health, the rest lands on her - every time | new |

### Cyrus

**Skirmisher** - the rapier
| Lv | Move | What it does | From |
|---|---|---|---|
| 24 | Riposte Step (passive) | After a Rapier hit, a step of up to 2 tiles in a line, and nothing reacts | Swashbuckler, as is |
| 32 | Flanker (passive) | +25% on Rapier hits on anybody beside one of his allies | new (Flicker's Slip Past went to his base kit) |
| 41 | Ambush Strike (passive) | The first hit on each enemy in a fight deals double, any attack | new (the opener; "has not acted" was always true for him) |
| 54 | Afterimage (passive) | While he is in cover, the first attack at him each round misses | new (draft: always) |
| 64 | Thousand Cuts (passive) | Rapier as his secondary action too; each Rapier hit after the first in a turn +25% | new |

**Saboteur** - the ammunition
| Lv | Move | What it does | From |
|---|---|---|---|
| 24 | Frost Round (ammo) | Gun x0.9, -2 movement for a turn | Gunner, as is |
| 32 | Corrosive Round (ammo) | Gun x0.8, Corroded (acid, 0.25 for 3 turns), which takes a tenth off Defense while it lasts - on the condition, so it refreshes rather than stacks and goes when Corroded does | new (in place of Shock Round, taken out) |
| 41 | Combined Load (skill) | Two ammunitions in one shot: the first one's hit, both effects, no multiplier of its own (the `ammo` suite) | Gunner, as is |
| 54 | Overload (passive) | A Gun hit makes each of his lingering conditions on the target tick once more, at once | new (in place of Faulty Powder) |
| 64 | Contagion (passive) | As their turn starts, his conditions spread to everybody beside them | new (in place of Total Breakdown) |

**Trapper** - bombs and traps (traps are a new mechanic)
| Lv | Move | What it does | From |
|---|---|---|---|
| 24 | Bombardier's Kit (passive) | A free Small Bomb every fight; Steal reaches 3 tiles further | Bombardier, as is |
| 32 | Snare (skill) | A hidden trap on a tile within 3; the first of the other side to step in is Rooted for a turn. One at a time | new |
| 41 | Tripwire (skill) | As Snare, and it bursts: x1.2 to everybody within 1 | new |
| 54 | Field of Traps (passive) | Two traps at once, and setting one is a secondary action | new |
| 64 | Minefield (skill) and Grand Snare (passive) | Once a fight, a Tripwire on every free tile within 2 of a point; anybody held by his traps takes +25% | new |

### Prometheus

**Elemental Vanguard** - the blade
| Lv | Move | What it does | From |
|---|---|---|---|
| 24 | Fleet Blade (passive) | +2 movement; Slip Past as a secondary action | Spellsword, as is |
| 32 | The four Edges (melee spells) | Flame x1.8 + Burn 2 turns, Frost x1.8 + -2 movement 2 turns (gate 3); Storm x2.2 + shove 2, Stone x2.2 + -10 defence 2 turns (gate 4) | Spellsword; were x1.2-1.6 through gates 1-2 |
| 41 | Spellstrike (passive) | An Edge that lands also hits with his cantrip of that element (x0.7), free | new |
| 54 | Elemental Armour (passive) | 20% less damage of the element he last used | new (draft said 10%) |
| 64 | Avatar (passive) | His Edges hit +50% | new |

**Elemental Tactician** - the ward
| Lv | Move | What it does | From |
|---|---|---|---|
| 24 | Ward (reaction) | An ally within 5 about to be hit takes 40% less from it | Abjurer, as is |
| 32 | Bulwark Weave (passive) | A spell of his landing on an ally gives them extra health (40% of his power) until the fight ends | Abjurer, as is |
| 41 | Battlefield Control (passive) | His roots, slows and pushes last a turn longer, and pushes go a tile further | new |
| 54 | Shared Ward (passive) | Ward can be used twice a round | new |
| 64 | Grand Design (passive) | Once a fight, a spell costs no gate, and he may cast a second spell as his secondary action that turn | new |

**Elemental Conductor** - the overcharge
| Lv | Move | What it does | From |
|---|---|---|---|
| 24 | Overcharge (passive) | Cast a spell through a deeper gate for +50% damage per gate deeper; free once a fight | Demolitionist; free uses were at 5/11/17 |
| 32 | Chain (passive) | His fire and lightning spells leap to one more within 2 of the target, at half damage | new |
| 41 | Resonance (passive) | A spell of another element than his last one hits +15% | new (draft: within a turn, but he casts one a turn) |
| 54 | Deep Current (passive) | Overcharge free twice a fight | new |
| 64 | Conduit (passive) | Once a fight, a spell through his deepest gate is cast twice | new |

### Alithia

**Battle Chaplain** - holy weapons
| Lv | Move | What it does | From |
|---|---|---|---|
| 24 | Holy Spear (spell) | A line of 6: x1.6, gate 3 | Punisher; was x1.0, gate 1 |
| 32 | Censure (spell) | A cone of 3: x2.4, gate 5 | Punisher; was x1.0, gate 2 |
| 41 | Judgement Hammer (spell) | Radius 1: x3.0 and a 1-tile shove, gate 6 | Punisher; was x1.4, gate 3 |
| 54 | Righteous (passive) | Her damaging spells heal the most hurt ally within 2 of her for 20% of the damage | new |
| 64 | Crusade (passive) | Allies within 2 of her deal +15% | new |

**Illusory Shepherd** - as your CSV designs it
| Lv | Move | What it does | From |
|---|---|---|---|
| 24 | Illusory Cover (spell, gate 3) | Cover that is not there, on a tile within 6 for 3 of her turns: to the other side's mind a barricade that blocks sight and is cover, as an image is a body; in truth shots and blasts go straight through | new |
| 24 | Veil of Mercy I (passive) | An ally she heals takes 15% less from the next blow | new |
| 32 | Phantom Body (spell, gate 4) | On an ally within 6: the next attack that would hit them strikes the image and misses (3 turns) | Mirror Image, reworked |
| 32 | Veil of Mercy II (passive) | Healed allies are Blurred: 20% less from attacks from more than a tile away, until their next turn | new |
| 41 | Sanctuary of Light (spell, gate 6) | A zone on the ground, radius 2 within 6, for 2 of her turns: her side standing in it takes 15% less, and an attack at them has a 1-in-4 chance to strike a copy and miss | new |
| 41 | Guiding Phantasm (passive) | Her heals and cleanses also give +2 movement until the end of their next turn | the Carer's Second Wind, given a home |
| 54 | Mass Mirage (spell, gate 8) | A zone on the ground, radius 3 within 6, until her next turn: her side standing in it takes 25% less, and one attack in four misses | new (was the whole party, wherever they stood) |
| 54 | Veil of Mercy III (passive) | Her heals also give a shield of 20% of their health for 2 turns | new |
| 64 | Reality's Reflection (spell, gate 10) | A zone, radius 3 within 8, for 2 of her turns, unseen by the other side: her side standing in it is invisible (given away by acting against an enemy, until their next turn), and an image beside each ally caught as she casts. Images let the whole party be out of sight; the last image gone gives Alithia away, and her falling gives everybody away - the zone stays | new |
| 64 | Illusory Guardian (passive) | While she stands, each ally's first blow taken in a fight misses | new |

**Inquisitor** - reading them
| Lv | Move | What it does | From |
|---|---|---|---|
| 24 | Inquest (passive) | Intuition also shows what they carry and their resistances | new |
| 32 | Accusation (spell, gate 4) | On somebody she has read: x1.5, and they take 15% more from everybody until her next turn | new |
| 41 | Sentence (passive) | Her hits +25% on anybody she has read | new |
| 54 | Recant (once a fight) | A read enemy's foreseen turn is simply lost | new |
| 64 | Final Judgment (passive) | Her Judgment ignores all defence (not half) on anybody she has read | new |

Left over: the Illusionist's Dread Visage (gate 2, Fear 2 turns) and Bewilder
(gate 2, Confused 1 turn) - in her own kit, or gone; the Carer's Tender Hands
(heals +25%, a quarter back to her) has no home.

## Taunts

No taunts: aggro comes from placement, cover, debuffs and holds like Grab. What taunted:
- The Pit Champion's **Challenge** (an aura: anybody of the party starting a turn within two tiles may only hurt the champion). Replaced (2026-10-23) by **Hemmed In** and **Exposed**, both built; the taunt mechanic is gone from the game.
- The CSV's Taunting Shout - built as Battle Cry, a cone that shoves. Kept as the shove.

Ways to keep the effect without forcing a target:
- **Punish** (for Challenge): a reaction - anybody within two tiles who hurts somebody else is struck by the champion. Staying near it is the price of ignoring it.
- **Hemmed In** (for Challenge): tiles within two of it cost twice the movement for the party - hard to get past, easy to fight.
- **Exposed** (for Challenge): anybody within two tiles who does not hit it takes a fifth more from it until their next turn.
- For Battle Cry: the shove it does now; or Rattled - those hit lose their secondary action next turn; or Pinned - two less movement for a turn, so they cannot reach the back line.

## What changed for skills that were already in the game

Figures are the multiplier (x) on the hit, and the lingering damage as dial x turns.

| Skill | Before | Now |
|---|---|---|
| Greatsword Attack (Enfina) | x1.5 from 1 | x1.0 from 1, x1.5 from 8 |
| Guard | from 11 | from 1 |
| Follow Up Attack | x1.4 from 12 | x1.5 from 32 |
| Sweep Strike | x1.2 from 3 | x1.4 from 54, and a shove |
| Gun (Cyrus) | x1.35 | x1.0 |
| Poison Dart | x0.8 + 0.4 x 5 from 3 | x0.9 + 0.2 x 3 from 8 |
| Burning Shot | x1.0 + 0.5 x 3 from 13 | x0.8 + 0.35 x 3 from 16; x0.95 + 0.45 x 3 from 32 |
| Warning Shot | x1.0, -2 movement, from 1 | x0.9, -1 movement for 2 turns, from 32 |
| Cat Burglar | from 8 | Cat Burglar II from 24; Cat Burglar I (+2 in cover) from 1 |
| Zephyr Dart, Caucasus Shard | from 2, 3 | from 1 |
| Wind Swoon (Prometheus) | no hit, 0.6 x 5, from 6 | x0.8 + 0.1 x 2 from 8 |
| Burner | no hit, 1.0 x 5, from 5 | x1.4 + 0.2 x 3 from 8; x2.1 + 0.4 x 3 from 16 |
| Crystalise | x0.4 + 0.3 x 4 from 7 | x0.8 + 0.1 x 3 from 16 |
| Gust Blast | x0.4 from 6 | x1.2 + Windswept 0.15 x 2 from 24 |
| River Flow (Alithia) | no hit, 0.3 x 5, from 7 | x1.3 + 0.2 x 2 from 8; x1.8 + 0.25 x 3 from 16 |
| Revitalizer (Alithia, the Priest) | heal x1.3, radius 3, reach 20, Pandora, from 9 | taken out (your call, 2026-10-23): Communion - the CSV's Group Heal, heal x0.6, radius 2, reach 10, Pandora, from 16 - is the group heal, and the Revitalizer Gate Nade is a Communion Gate Nade |

In the story's fights (levels 1, 8, 14) Enfina no longer has Sweep Strike or Follow Up Attack, Cyrus no Warning Shot, Burning Shot or Cat Burglar's climbing, and Prometheus no Crystalise or Gust Blast. Enemies with these moves keep their old levels for them (`CombatantDefinition.skill_levels`: the Barbarian, the Pit Champion, the Sorcerer, the Priest), but the new numbers apply to them too.

## Open (2026-10-23)

Approved: the subclass list above, except what follows. Decided: Slip Past as a
secondary action goes to every Cyrus path (his base kit at 24, so Flicker needs
a replacement); the Illusory Shepherd keeps two features a tier; Dread Visage
and Bewilder stay in Alithia's own kit for now; Tender Hands is dropped.

Under rework: the fighters' level 64 (base and subclass capstones - the casters
have the Gate of Yaldabaoth and many castings to spare by then), Skirmisher 32
(Flicker), Ambush Strike (much stronger), Saboteur 32 (Shock Round) and 54
(Faulty Powder, which made Frost Round redundant). The options offered are in the
conversation of 2026-10-23; the picks go here.

Picked 2026-10-23: **Flanker** for Skirmisher 32 (+25% on Rapier hits on anybody
standing beside one of his allies); **Corrosive Round** for Saboteur 32 (Gun x0.8,
Corroded: 0.25 a turn for 3 turns and -10% defence while it lasts); **Overload**
for Saboteur 54 (a Gun hit makes each of his conditions on the target tick once
more at once). The fighters' new 64s (Rampage, Tremor, Last Wall, Thousand Cuts as
a secondary Rapier, Contagion, Minefield) are liked. Still open: Ambush Strike's
number, Titanfall (once a fight x6.0 radius 2, or every turn x3.0 + x1.5 within
2) and Catalyst (once a fight on everybody, or every turn on one).
Picked 2026-10-23: **Ambush Strike** is the opener - the first hit on each enemy
in a fight deals double, with any attack. Titanfall leaning B (every turn); Catalyst
still open.
Done 2026-10-23: Earthsplitter and Meteor taken out of the game; Titanfall is no
move of its own but Greatsword Attack's rank at 64 (x3.0, a x1.5 splash within 2,
shoved a tile).

Built 2026-10-23: all twelve paths, chosen at 24 (Stats.SUBCLASS_LEVEL). Cyrus's
base kit: Elusive (Slip Past as a secondary action, 24) and Catalyst (64, once a
fight: everything of his lingering on the other side goes off at once, x2 what it
had left, then starts again). Alithia keeps Dread Visage (7) and Bewilder (9) in
her own kit; Tender Hands is dropped; Mirror Image stays in the data, in no kit.

2026-10-23, later: spells never rank up - Burner's Strong Burn is Wildfire and River
Flow's Frozen II is Frozen River, spells of their own (gate 3). Prometheus has
Dispel Magic (Pandora, 14): ends what spells left - conditions, invisibility,
summons, images, zones - that came through the gate it is cast through or a
shallower one. Zones outlast their casters.
