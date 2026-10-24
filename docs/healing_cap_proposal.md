# One healing rule, a level-scaled cap, and boss healing

> **Status, 2026-10-24: an optional tuning tool, not part of the baseline (ledger: OPTIONAL_TUNING_TOOL).** The designer decided:
> - no global heal cap;
> - share-of-health heals only on a few rare, limited moves;
> - big boss heals only as explicit, limited, telegraphed mechanics;
> - a per-boss cap or condition only if a specific boss proves degenerate.
>
> The share-of-missing-health formula modelled here is superseded by `docs/healing_revision.md`. Keep this document for its method and numbers, should a boss ever need a cap.

Prepared 2026-10-24, following `docs/healing_and_rest_proposal.md`. **Nothing here is implemented.** Every new healing, cap and boss-healing value is a **PROPOSAL test value**; the ledger has a row for each.

Numbers come from the probe `tests/run.sh healing`, which uses the game's own functions. It writes `docs/healing_inventory.csv`, whose cap sections are:
- levels 1, 8, 14, 18, 24, 41, 54 and 64;
- the cap's triggers for every healer;
- the cap level by level, 1 to 64, under both sets of bands;
- every enemy's and boss's health.

**The model:**
- The party has no gear (weapon base 6) and no path.
- The healers' Mindfulness is their level's curve. It is their main stat for Alithia, the Priest and the Summoner, and a secondary or base stat for the Ranger and the Mimic.
- **Nearly down** means one health point left: the largest heal a target can take.
- **Mercy I** is Alithia's +10%. It is shown both ways, since whether it multiplies the hybrid amount is still OPEN.

---

## Summary

- **The universal rule works as a cap carrier.** Heal is 20% of the missing health + 0.5 × Mindfulness, the same for everyone.
  - On party members and ordinary enemies, the cap is needed almost nowhere.
  - On bosses and giants, an uncapped Heal returns 22-26% of their health per cast at every level.
- **The proposed bands:**
  - **1-7 (25): too low.** It trims Alithia's Heal on a nearly-down Enfina at every level from 1, and on Cyrus and Alithia from 6 with Mercy I. It also trims an enemy healer's Heal on ordinary Stone Golems and Pit Champions from level 1, Barbarians and Ogres from 2, and Sellswords at 7.
  - **8-18 (50): right, but tight at the top.** It never trims the party. But at 18 her Heal with Mercy I on Enfina is 96% of it, so 3 points of extra Mindfulness would hit the cap.
  - **24-45 (100): appropriately rare.** Her biggest heal is 49-72% of it. Fill the gap below it, though: if 19-23 keeps 50, it trims Enfina at 21-23 with Mercy I.
  - **54-64 (175-225): rare, but higher than it needs to be.** Her biggest heal is 80-88, under half of it. At 225 the Bellkeeper and Behemoth would heal uncapped (25-26% a cast).
  - **The gaps.** Levels 19-23 and 46-53 have no band.
- **Proposed final cap (PROPOSAL), one band per chapter:** 45 / 60 / 80 / 100 / 150 / 175 (section 7).
  - It never trims a party member or an ordinary enemy at their level's Mindfulness.
  - It keeps Alithia's biggest Heal at 46-87% of the cap, and her Restoration at 81-93%.
  - It holds a Heal to 6-19% of a large boss's health from level 8 (Erysichthon, the Ash Warden, the Colossus).
- **What a cap can't fix:**
  - Smaller bosses still get 17-26% per Heal: the Bellkeeper, 900 health at 64; the Behemoth, 700.
  - Erysichthon's meals already heal more than any spell would: 6% each, free, up to 7 in its laboratory fight, 42% of its health.
  - Those need the conditional designs in section 7.

---

## 1-2. Current healing, what it scales from, and its values

### The rule today

`Combat.heal_amount` + `heal_share_on`:

> round( power × dial × (1 + heal bonus) ) + round( share × the target's max health )

- **power**
  - For a spell or skill: weapon base + 0.7 × the stat. For a spell that is the caster's spellcasting stat, which is Mindfulness for every healer here.
  - For an item: its flat item power.
- **heal bonus:** Mercy I gives +0.1 on Alithia's heals, including items she uses.

| Heal | Formula now | Scales from |
|---|---|---|
| Light Heal | power × 0.5 | **Mindfulness** (+ weapon) |
| Heal | power × 0.7 | **Mindfulness** (+ weapon) |
| Communion | power × 0.6, each ally | **Mindfulness** (+ weapon) |
| Purification | power × 0.7, + cleanse | **Mindfulness** (+ weapon) |
| Restoration | power × 0.7 + 50% of max | **Mindfulness** (+ weapon) and the target's health |
| Grace | power × 0.7 + 100% of max (full) | the target's health |
| Cure / Mediocre / Potent Cure Potion | 25% / 40% / 55% of max | the target's health |
| Medicine | 24 flat (26 from Alithia) + 1 condition lifted | nothing |
| Heal Gate Nade | 21 flat (23 from Alithia) | nothing |
| Communion Gate Nade | 30 flat each (33 from Alithia) | nothing |
| Revitalizer Gate Nade | - | ABSENT: replaced by the Communion Gate Nade |
| Light Swing (Enfina) | power × 0.3, on herself | **Physical** (+ weapon) |
| Priest: Heal, Communion | as Alithia's (the same skill files) | **Mindfulness** (its main stat) |
| Ranger: Heal | as Alithia's | **Mindfulness** (10-43: not its main stat) |
| Summoner: Mend the Bound | power × 0.9, no gate | **Mindfulness** (its main stat) |
| Mimic: whatever heal the party last used | that heal, with the Mimic's own stats | **Mindfulness** (base: 10 at every level) |
| Alchemist: its pocket | potions, Gate Nades, Medicine | as the items |
| Erysichthon: a meal | 6% of its max | its health |

### Values now (Alithia healing, Mercy I in; Enfina / Cyrus / Prometheus)

A dash (-) means not learned at that level.

| Level | Alithia's Mind | Max health | Light Heal | Heal | Communion | Restoration | Potent Cure |
|---|---|---|---|---|---|---|---|
| 1 | 10 | 130 / 75 / 30 | - | 10 | - | - | 72 / 41 / 17 |
| 8 | 18 | 137 / 79 / 33 | 10 | 14 | - | - | 75 / 43 / 18 |
| 14 | 25 | 142 / 83 / 36 | 13 | 18 | - | - | 78 / 46 / 20 |
| 18 | 30 | 146 / 86 / 38 | 15 | 21 | 18 | - | 80 / 47 / 21 |
| 24 | 37 | 152 / 90 / 40 | 18 | 25 | 21 | - | 84 / 50 / 22 |
| 41 | 58 | 168 / 100 / 48 | 26 | 36 | 31 | - | 92 / 55 / 26 |
| 54 | 73 | 180 / 109 / 54 | 31 | 44 | 38 | 134 / 99 / 71 | 99 / 60 / 30 |
| 64 | 85 | 190 / 115 / 58 | 36 | 50 | 43 | 145 / 108 / 79 | 105 / 63 / 32 |

Purification (41+) matches Heal: 36, 44, 50. Grace (64) is full health.

| Level | Priest's Mind: Heal / Communion | Ranger's Mind: Heal | Summoner: Mend the Bound | Light Swing |
|---|---|---|---|---|
| 1 | 10: 9 / (16+) | 10: 9 | 12 | 4 |
| 8 | 18: 13 / (16+) | 10: 9 | 17 | 6 |
| 14 | 25: 16 / (16+) | 13: 11 | 21 | 7 |
| 18 | 30: 19 / 16 | 15: 12 | 24 | 8 |
| 24 | 37: 22 / 19 | 19: 14 | 29 | 10 |
| 41 | 58: 33 / 28 | 29: 18 | 42 | 14 |
| 54 | 73: 40 / 34 | 37: 22 | 51 | 17 |
| 64 | 85: 46 / 39 | 43: 25 | 59 | 20 |

---

## 3. Current, hybrid and capped

The proposed Heal on a patient with 90% of their health missing, against today's Heal (Enfina / Cyrus / Prometheus):

| Level | Heal now | Hybrid Heal | Designer's cap | Trimmed? |
|---|---|---|---|---|
| 1 | 10 | 28 / 19 / 10 | 25 | **Enfina** |
| 8 | 14 | 34 / 23 / 15 | 50 | no |
| 14 | 18 | 38 / 28 / 19 | 50 | no |
| 18 | 21 | 41 / 30 / 22 | 50 | no (45 with Mercy I) |
| 24 | 25 | 46 / 35 / 26 | 100 | no |
| 41 | 36 | 59 / 47 / 38 | 100 | no |
| 54 | 44 | 69 / 56 / 46 | 175 | no |
| 64 | 50 | 77 / 63 / 52 | 175-225 | no |

- **Light Heal and Communion** (10% + 0.3 Mind) never reach a cap on anyone smaller than a boss.
- **Restoration** (54+: 50% of max + 0.5 Mind) does, but only on bosses, giants and the largest enemies, and only if one of them could cast it (a Mimic copying it).
- **Grace** is outside the cap.

---

## 4. The caps against party, enemy and boss health

**Health at each level** (from the data; enemies by `docs/enemy_progression.csv`):

| Level | Party (Enf / Cyr / Pro) | Largest ordinary enemy | Bellkeeper | Behemoth | Colossus | Ash Warden | Erysichthon |
|---|---|---|---|---|---|---|---|
| 1 | 130 / 75 / 30 | Stone Golem, Pit Champion 108 | 160 | 120 | 200 | 300 | 300 |
| 8 | 137 / 79 / 33 | 127 | 242 | 184 | 311 | 433 | 500 |
| 14 | 142 / 83 / 36 | 143 | 313 | 240 | 406 | 548 | 671 |
| 18 | 146 / 86 / 38 | 154 | 360 | 277 | 470 | 624 | 786 |
| 24 | 152 / 90 / 40 | 171 | 430 | 332 | 565 | 738 | 957 |
| 41 | 168 / 100 / 48 | 217 | 630 | 488 | 835 | 1062 | 1443 |
| 54 | 180 / 109 / 54 | 253 | 783 | 608 | 1041 | 1310 | 1814 |
| 64 | 190 / 115 / 58 | 280 | 900 | 700 | 1200 | 1500 | 2100 |

**A Heal on each boss, nearly down, healed by a Priest at the level's Mindfulness:**
- **Uncapped** it is 22-26% of their health at every level. That is what a cap is for.
- **With the designer's cap** (each cell: the heal, and the share of the boss's health):

| Level | Cap | Bellkeeper | Behemoth | Colossus | Ash Warden | Erysichthon |
|---|---|---|---|---|---|---|
| 1 | 25 | 25 (16%) | 25 (21%) | 25 (13%) | 25 (8%) | 25 (8%) |
| 8 | 50 | 50 (21%) | 46 (25%, uncapped) | 50 (16%) | 50 (12%) | 50 (10%) |
| 18 | 50 | 50 (14%) | 50 (18%) | 50 (11%) | 50 (8%) | 50 (6%) |
| 24 | 100 | 100 (23%) | 85 (26%, uncapped) | 100 (18%) | 100 (14%) | 100 (10%) |
| 41 | 100 | 100 (16%) | 100 (20%) | 100 (12%) | 100 (9%) | 100 (7%) |
| 54 | 175 | 175 (22%) | 158 (26%, uncapped) | 175 (17%) | 175 (13%) | 175 (10%) |
| 64 | 175 / 225 | 175 (19%) / 222 (25%, uncapped) | 175 (25%) / 182 (26%, uncapped) | 175 / 225 (15% / 19%) | 175 / 225 (12% / 15%) | 175 / 225 (8% / 11%) |

The cap holds the large bosses to 6-15% per cast. On the two smaller ones it barely bites: the Behemoth is never really capped, and the Bellkeeper only partly.

**Mindfulness headroom.** How far Alithia's Mindfulness could rise above her level's curve before the cap trimmed her biggest heal: Heal with Mercy I on a nearly-down Enfina. Mindfulness has no way to rise today (no gear, buff or passive raises it), so this is the room left for future "investment".

| Level | Her biggest Heal | Designer's cap | Room | Proposed cap (section 7) | Room |
|---|---|---|---|---|---|
| 1 | 34 | 25 | **already over** | 45 | +20 |
| 7 | 39 | 25 | **already over** | 45 | +11 |
| 8 | 40 | 50 | +19 | 60 | +37 |
| 18 | 48 | 50 | **+3** | 60 | +21 |
| 23 | 53 | 50 (gap) | **already over** | 80 | +44 |
| 24 | 54 | 100 | +84 | 80 | +48 |
| 41 | 69 | 100 | +57 | 100 | +57 |
| 54 | 80 | 175 | +174 | 150 | +128 (Restoration: +20) |
| 64 | 88 | 175-225 | +158 to +248 | 175 | +158 (Restoration: +43) |

---

## 5. Exactly when each cap triggers

**The trigger point.** A heal reaches the cap once the patient's missing health passes:

> (cap ÷ Mercy − Mindfulness share × Mindfulness) ÷ missing-health share

For Restoration it is when their **max** health passes (cap − 0.5 × Mindfulness) ÷ 0.5.

**At the designer's bands, on the party:**
- **Levels 1-7:** on Enfina at every level, nearly down. On Cyrus and Alithia at 6-7, with Mercy I.
- **Levels 21-23,** if the gap keeps 50: on Enfina, with Mercy I.
- **Nowhere else, at any level.**

**On ordinary enemies:**
- **Levels 1-7:** an enemy healer's Heal on Stone Golems and Pit Champions from level 1, Barbarians and Ogres from 2, and Sellswords at 7.
- **Level 23,** if the gap keeps 50: on Stone Golems and Pit Champions.
- **Restoration:** on the largest enemies at every band, but only a Mimic could cast it on them.
- **Nowhere else.**

**Alithia's Heal (no Mercy I):**

| Level | Cap | Trims above this much missing health | Trims, nearly down |
|---|---|---|---|
| 1 | 25 | 100 | Enfina; Stone Golem, Pit Champion; every boss and giant |
| 8 | 50 | 205 | Ash Warden, Bellkeeper, Colossus, Erysichthon |
| 14 | 50 | 188 | every boss and giant |
| 18 | 50 | 175 | every boss and giant |
| 24 | 100 | 408 | Ash Warden, Bellkeeper, Colossus, Erysichthon |
| 41 | 100 | 355 | every boss and giant |
| 54 | 175 / 225 | 693 / 943 | Ash Warden, Bellkeeper, Colossus, Erysichthon / Ash Warden, Colossus, Erysichthon |
| 64 | 175 / 225 | 663 / 913 | every boss and giant / Ash Warden, Colossus, Erysichthon |

**Light Heal and Communion** (10% + 0.3 Mind) trim only on Erysichthon, the Ash Warden and sometimes the Colossus. Their thresholds are 410-2031 missing health.

**Restoration** (54+) trims on every boss and giant, at a max health above 265-377. With Mercy I at 175 it also trims on the Stone Golem and Pit Champion.

**The Priest's and Ranger's Heal** trim on every boss or giant they could heal, and on no ordinary enemy above level 7. The CSV has every healer, spell and level in section "Cap trigger".

---

## 6. Every enemy and boss healing interaction

| Who | How they heal | In which fights | Under the universal rule and a cap |
|---|---|---|---|
| **Priest** | Heal, and Communion from 16. Its AI (`ai_healer`) mends the most hurt. | Sewer Intro, Lab Fight, City Fight, the Dungeon Demo, laboratory stage A, Sixty-Four (2) | Same formula. Its Heal on a nearly-down Ogre goes 19 → 41 at 18. Never capped on an ordinary enemy above 7, except at 23 if that gap keeps 50. |
| **Ranger** | Heal, through `_ai_heal_key` | the same fights | Its low Mindfulness stops mattering: 12 → 34 on that Ogre at 18. |
| **Summoner** | Mend the Bound (×0.9, no gate), mostly on its bound beast | Summoner Den (22), Sixty-Four | **No hybrid value yet.** Modelled here as Heal's. OPEN. |
| **Alchemist** | Its pocket: a Potent Cure Potion, two Heal Gate Nades, a Communion Gate Nade, Medicine. Mends anyone under 60% (`AI_ALCHEMIST_MENDS_BELOW`). | Alchemist Den (14) | Potions are shares of **max** health, so a Potent Cure on a boss would be 55% (1,155 on Erysichthon at 64). No boss fight has an Alchemist now. |
| **Any enemy with a potion** | Drinks it under 50% (`AI_DRINK_BELOW`) | Sixty-Four: a Priest and a Sorcerer with Potent Cures | The same issue as the Alchemist's, if a boss ever carried one. |
| **Mimic** | Copies whatever the party last used, heals included (Heal, Light Heal, Communion, Restoration, Grace, Purification can all be copied), on its most hurt ally, with its own stats. It could copy Cyrus's Steal too, and drink what it took. | Sewer Intro, Lab Fight, City Fight, the Dungeon Demo, laboratory stage A | **A copied Grace is a full heal and a copied Restoration half one.** Harmless with no boss present, a runaway beside one. |
| **Erysichthon** | Meals: 6% of its max each, **free**, at the start of its turn and again after it moves. A meal is the carrion heap or any of its own fallen. Each meal also regrows every broken part and makes it Gorged (+4 Physical, 3 turns). | Arena (22); laboratory stage C (18) | **Up to 7 meals** (the heap and six Gnawers): 329 at 18, 42% of its health. More than any capped spell. |
| Erysichthon: tainted carrion | The party can taint the heap. It is then no meal: 90 Poison, Poisoned, +30 stagger. | its fights | Counterplay already present. |
| Erysichthon: bait keg | No meal: 140 Fire, Burn, +50 stagger, and its Belly Hole breaks, freeing the swallowed | its fights | Counterplay already present. |
| Erysichthon: The Hollow (33%) | With nothing in reach it eats itself: **loses** 4% of its max, regrows parts, no heal | its fights | No heal. |
| Erysichthon: Devour, digestion | Swallowing and digesting heal nothing | - | - |
| Ash Warden | No healing. Its last phase clears its conditions (a cleanse, not a heal) and summons two Imps, who don't heal. | Arena (10); laboratory variant (18) | - |
| Bellkeeper, Behemoth, Colossus | No healing | Arena | - |
| Boss phases | `BossPhase` has no healing of any kind | - | - |

---

## 7. Verdict, and proposed final values (all PROPOSAL)

### The bands

| Designer's band | Verdict | Why |
|---|---|---|
| 1-7: 25 | **Too low** | Trims Alithia's Heal on Enfina from level 1 (31, 34 with Mercy I), and on Cyrus and Alithia at 6-7. Also trims enemy Heals on ordinary Stone Golems, Pit Champions, Barbarians, Ogres and (at 7) Sellswords. |
| 8-18: 50 | **About right; tight at 18** | Never trims the party or an ordinary enemy. But her biggest Heal is 80-96% of it with Mercy I, leaving 3 points of Mindfulness at 18. |
| 19-23 | **Missing** | Carrying 50 over trims Enfina at 21-23, and enemy Heals on Stone Golems and Pit Champions at 23. Jumping to 100 doubles what a boss gets back from one level to the next. |
| 24-45: 100 | **Appropriately rare** | Her biggest heal is 49-72% of it. On bosses, 7-14% a cast for the large ones. |
| 46-53 | **Missing** | - |
| 54-64: 175-225 | **Keep the low end** | Her biggest Heal is 80-88. Her Restoration (learned at 54) is 139-151 with Mercy I, which is what sets the floor. At 225, the Bellkeeper and Behemoth heal uncapped (25-26%). |

### Proposed final cap: one band per chapter

The cap applies to the final amount, on each target.

| Levels (chapter) | Cap | Alithia's biggest Heal, with Mercy I, as a share of it | A Heal on a large boss, as a share of its health |
|---|---|---|---|
| 1-7 (Chapter I) | **45** | 76-87% | 10-23% |
| 8-18 (Chapter I) | **60** | 67-80% | 8-19% |
| 19-33 (Chapter II) | **80** | 61-76% | 7-16% |
| 34-45 (Chapter III) | **100** | 62-72% | 6-14% |
| 46-55 (Chapter IV) | **150** | 49-53% (Restoration, from 54: 93%) | 8-16% |
| 56-64 (Chapter V) | **175** | 46-50% (Restoration: 81-86%) | 8-16% |

- **What these values do:**
  - They never trim a party member or an ordinary enemy at the level's Mindfulness.
  - They leave at least 11 points of Mindfulness headroom; 20 or more from level 8, Restoration included.
  - They rise once per chapter, which is easy to learn.
  - The probe checks every level from 1 to 64 (section "Cap by level"). These bands trim nobody but bosses at any level, while the designer's trim somebody at 1-7 and 21-23.
  - The last two are set by Restoration, not Heal. A cap of 130 at 46-55 would trim her Restoration on Enfina at 54-55 (139-140 with Mercy I).

### Scope of the cap (proposed)

- **Every heal spell, per target.** Communion and Light Heal on a boss at 54-64 reach 235 uncapped, so a single-target-only cap would leave area heals as the loophole.
- **Grace is exempt.** Full health is its point. **It and Restoration should not be copyable** (`can_be_copied = false`), so a Mimic can never Grace a boss.
- **Copied heals are capped** like any other.
- **Items:**
  - Capping them would trim the party's own potions early: a Mediocre Cure is 52 on Enfina at level 1.
  - So instead, a **per-creature switch**: bosses don't drink potions and can't be given them.
  - That is OPEN for the designer.

### Boss healing: conditional, not repeatable

The cap stops one heal from returning a huge share. Repetition is still the risk: a Priest beside Erysichthon could add 60 every turn. Proposed defaults, all as per-creature switches:

1. **A boss doesn't heal itself by spell.** Healing comes from an ally or an action.
2. **An enemy healer's heal on a boss:**
   - a declared move, so it is telegraphed and can be interrupted or hacked;
   - once per boss phase;
   - only while the boss is below a threshold (for example 50%).
3. **Smaller bosses** (the Bellkeeper, the Behemoth) rely on 1 and 2, since the cap barely touches them.

### Erysichthon's meals (PROPOSAL)

**Today:** 6% of its max per meal, free, twice a turn, from the carrion heap and every fallen Gnawer. That is up to 42% of its health in the laboratory fight.

**Proposed:**
- **A small fixed heal per meal, a third of the cap:** 15 (1-7), **20 (8-18)**, 25 (19-33), 35 (34-45), 50 (46-55), 60 (56-64).
  - That is about 2.5-3% of its health (5% at level 1). At 18 it is 20 of 786, against 47 now.
- **One meal a turn, and it costs its secondary action.** Today eating is free. Needs code.
- **A meal leaves it Gorging until its next turn:** −20% Defense. That fits its existing fed effects and the existing `defense_change` field, so it is data only.
  - The exposed moment is the counterplay, beside the tainted carrion and the bait keg already there.
- **Its own fallen** regrow its parts, but don't heal it. Six Gnawers would otherwise be six heals the party fed it by winning.

At 18 that caps the laboratory fight at one heal of 20 from the carrion heap, not 329.

### Also to decide

- Mend the Bound's hybrid value: Heal's, or its own.
- Whether Mercy I multiplies the whole hybrid amount. The headroom above assumes the worse case, that it does.
- The Gate Nade, Medicine and Purification questions from the first report still stand.

---

## 8. Status

| Item | ImplementationState | DecisionStatus |
|---|---|---|
| One healing rule for everyone (players, enemies, bosses) | ABSENT | PROPOSAL (the direction is the designer's; the values are test values) |
| Cap bands, as proposed by the designer | ABSENT | PROPOSAL; assessed above |
| Cap, chapter bands 45 / 60 / 80 / 100 / 150 / 175 | ABSENT | PROPOSAL |
| Cap scope: every heal spell, per target; Grace exempt and not copyable | ABSENT | PROPOSAL |
| Bosses don't drink or receive potions (per-creature switch) | ABSENT | OPEN |
| Boss healing: no self-heal by spell; an ally's heal declared, once a phase, below a threshold | ABSENT | PROPOSAL |
| Erysichthon's meals: a fixed heal, one a turn, Gorging, no heal from its own fallen | PRESENT as 6% (EXISTING_BASELINE) | PROPOSAL |
| Mend the Bound under the rule | PRESENT as ×0.9 | OPEN |
