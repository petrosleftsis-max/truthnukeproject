# Revised healing: mostly flat, with modest scaling

> **Implemented as a trial, 2026-10-24 (APPROVED_TRIAL).**
> - **On the new formulas:** Light Heal, Heal, Communion and Restoration. Grace is unchanged.
> - **Enemy healers:** the Priest and Ranger use the same files. The Summoner's Mend the Bound now uses Heal's formula, without its ×0.9.
> - **Mercy I** multiplies the whole new amount, never a share of health. With it, Alithia's Heal is 18 / 20 / 22 / 23 / 39 at levels 1 / 8 / 14 / 18 / 64; the tables below are without it.
> - **The Mimic** heals with its healing stat: Self, through Mimicry.
> - **Unchanged:**
>   - Gate Nades and Medicine keep their flat amounts, to be tested separately;
>   - Erysichthon's 6% meal;
>   - Soothed (Aura II), OPEN;
>   - Purification;
>   - no heal cap.
> - **"Now" in this report means before the trial.**

Prepared 2026-10-24. This supersedes the share-of-missing-health direction in `docs/healing_and_rest_proposal.md` (section 2) and `docs/healing_cap_proposal.md`. The cap document is now an optional tuning tool (section 8). The rest framework from the first report is kept for testing.

**Nothing here is implemented. Every revised value is a PROPOSAL test value.**

Numbers come from the probe `tests/run.sh healing`, using the game's own functions. Its sections "Revised (PROPOSAL)", "Revised against blows", "Revised on enemies" and "Revised cap check" are in `docs/healing_inventory.csv`.

**The model:**
- The party has no path, at levels 1, 8, 14, 18, 24, 41, 54 and 64.
- Weapon base 6 means no weapon. In story and dungeon fights the party has no gear, and every enemy healer in Chapter I has 6. Values at 10 (a mace or staff) and 12 (the arena's best tile, Sixty-Four's healers) are given beside it.
- Mercy I (+10% on Alithia's heals) is shown separately. Whether it multiplies the new formula is OPEN.

**The revision:**

| Heal | Formula (PROPOSAL) |
|---|---|
| Light Heal | 8 + 0.15 × Mindfulness + 0.2 × weapon base |
| Heal | 12 + 0.25 × Mindfulness + 0.3 × weapon base |
| Communion | 8 + 0.15 × Mindfulness + 0.2 × weapon base, each ally |
| Restoration | 50% of max + 0.25 × Mindfulness |
| Grace | full health (unchanged) |

---

## Summary

- **Heal is the same flat amount on anyone:** 16 at level 1, 18 at 8, 20 at 14, 21 at 18, 35 at 64.
  - That is **53-60% of Prometheus's health** against **12-18% of Enfina's**, which is what the revision intends.
  - Against today's Heal: stronger at 1-14 (16 against 10 at level 1), equal at 18 (21), weaker after (35 against 50 at 64).
  - Through Chapter I it undoes about one typical enemy blow on anyone (83-133%). It never undoes two, so Enfina gets no special shelter from it.
- **Light Heal and Communion** (the same formula): 11 → 22.
  - Stronger than now at 1-8, level at 14, a little weaker at 18 (14 against 15 and 18).
  - Much weaker late: 22 against 36 and 43 at 64.
  - Communion per ally stays below Heal at every level (14 against 21 at 18).
- **The weapon barely shows.** 0.3 × weapon base makes the difference between no weapon (6) and the best (12) **1-2 points**. Today a mace adds 2-4. If weapons should be felt, the weapon share has to be larger (section 9).
- **Mindfulness spans 16 → 35 on Heal across 64 levels**, a little over double. Enemy blows grow about five times over the same span. As intended, it is not an enormous range.
- **Enemy healers are bounded by the formula itself:** a Heal is 1-13% of a boss's health, 13-21% of an ordinary enemy's.
- **No global cap is needed, and none is planned** (the designer's decision, 2026-10-24).
  - Heal, Light Heal and Communion can't reach any band discussed: their largest possible value (Heal, Mercy I, weapon base 12) is 20-41.
  - Share-of-health heals stay uncapped and rare.
  - A boss's big heal is an explicit mechanic with counterplay, never ordinary healing.
  - The cap document is an optional tuning tool for a boss that proves degenerate (section 8).

---

## 1. Current healing values

Today's rule is (weapon base + 0.7 × Mindfulness) × the heal's dial × 1.1 (Mercy I), plus a share of max health where the heal has one. Values are Alithia's, weapon base 6, Mercy I in; a dash (-) means not learned at that level.

| Level | Mind | Light Heal | Heal | Communion | Restoration (Enf / Cyr / Pro) | Potent Cure (Enf / Cyr / Pro) |
|---|---|---|---|---|---|---|
| 1 | 10 | - (7) | 10 | - (9) | - | 72 / 41 / 17 |
| 8 | 18 | 10 | 14 | - (12) | - | 75 / 43 / 18 |
| 14 | 25 | 13 | 18 | - (16) | - | 78 / 46 / 20 |
| 18 | 30 | 15 | 21 | 18 | - | 80 / 47 / 21 |
| 24 | 37 | 18 | 25 | 21 | - | 84 / 50 / 22 |
| 41 | 58 | 26 | 36 | 31 | - | 92 / 55 / 26 |
| 54 | 73 | 31 | 44 | 38 | 134 / 99 / 54 (full) | 99 / 60 / 30 |
| 64 | 85 | 36 | 50 | 43 | 145 / 108 / 58 (full) | 105 / 63 / 32 |

Cure Potion and Mediocre are 25% and 40% of max health. Medicine is 24 flat, the Heal Gate Nade 21 and the Communion Gate Nade 30 (a tenth more each when Alithia uses them). Every source is in `docs/healing_cap_proposal.md`, section 1.

---

## 2-3. The revision, and as a share of each member's health

Weapon base 6, no Mercy I. Each cell: the amount, then the share of Enfina / Cyrus (Alithia the same) / Prometheus's max health.

| Level | Max health (Enf / Cyr / Pro) | Heal | Light Heal = Communion | Restoration |
|---|---|---|---|---|
| 1 | 130 / 75 / 30 | **16**: 12% / 21% / **53%** | 11: 8% / 15% / 37% | 68 / 40 / 18 (52-60%) |
| 8 | 137 / 79 / 33 | **18**: 13% / 23% / **55%** | 12: 9% / 15% / 36% | 73 / 44 / 21 |
| 14 | 142 / 83 / 36 | **20**: 14% / 24% / **56%** | 13: 9% / 16% / 36% | 77 / 48 / 24 |
| 18 | 146 / 86 / 38 | **21**: 14% / 24% / **55%** | 14: 10% / 16% / 37% | 81 / 51 / 27 |
| 24 | 152 / 90 / 40 | **23**: 15% / 26% / **58%** | 15: 10% / 17% / 38% | 85 / 54 / 29 |
| 41 | 168 / 100 / 48 | **28**: 17% / 28% / **58%** | 18: 11% / 18% / 38% | 99 / 65 / 39 |
| 54 | 180 / 109 / 54 | **32**: 18% / 29% / **59%** | 20: 11% / 18% / 37% | 108 / 73 / 45 (60-83%) |
| 64 | 190 / 115 / 58 | **35**: 18% / 30% / **60%** | 22: 12% / 19% / 38% | 116 / 79 / 50 (61-86%) |

**Weapons and Mercy I** (Heal at 18 / 64):
- weapon base 10: 23 / 36;
- weapon base 12: 23 / 37;
- Mercy I, at weapon base 6: 23 / 39.

**Against today** (Heal now: 10 / 14 / 18 / 21 / 25 / 36 / 44 / 50 at the eight levels):

| | Now → revised |
|---|---|
| Heal | +6 at 1, +4 at 8, +2 at 14, equal at 18, then −2 / −8 / −12 / −15 |
| Light Heal | +4 at 1, +2 at 8, equal at 14, −1 at 18, then −3 / −8 / −11 / −14 |
| Communion | +2 at 1, equal at 8, −3 at 14, −4 at 18, then −6 / −13 / −18 / −21 |
| Restoration | 17-27% less than today where it is learned, 54 and 64 (0.25 × Mindfulness, against the current Heal's power on top of the half) |

---

## 4. As a share of enemy and boss health

A Priest at weapon base 6 (every Chapter I fight), Mindfulness on its level's curve:

| Level | Priest's Heal (now) | Gnawer | Sellsword | Ogre | Pit Champion | Bellkeeper | Behemoth | Colossus | Ash Warden | Erysichthon |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 16 (9) | 64% | 21% | 16% | 15% | 10% | 13% | 8% | 5% | 5% |
| 8 | 18 (13) | 58% | 20% | 15% | 14% | 7% | 10% | 6% | 4% | 4% |
| 14 | 20 (16) | 54% | 20% | 15% | 14% | 6% | 8% | 5% | 4% | 3% |
| 18 | 21 (19) | 53% | 19% | 15% | 14% | 6% | 8% | 4% | 3% | 3% |
| 24 | 23 (22) | 51% | 19% | 14% | 13% | 5% | 7% | 4% | 3% | 2% |
| 41 | 28 (33) | 46% | 18% | 14% | 13% | 4% | 6% | 3% | 3% | 2% |
| 54 | 32 (40) | 44% | 18% | 14% | 13% | 4% | 5% | 3% | 2% | 2% |
| 64 | 35 (46) | 43% | 18% | 13% | 13% | 4% | 5% | 3% | 2% | 2% |

- **The Priest's Communion** is 11 → 22 per ally: 2-15% of anything but a Gnawer.
- **The share-of-health heals on a boss stay huge.** The policy reserves them for explicit boss mechanics (section 8).
  - A Potent Cure is 55% of its health: 432 on Erysichthon at 18, 1,155 at 64.
  - Restoration (54+) is half its health plus a little: 673-771 on the Ash Warden.

---

## 5. Does Heal help Prometheus without making Enfina too hard to hurt?

Against the enemies' blows in the real fights at each level: the median of each enemy's best blow (typical) and the worst (hardest), from `Combat.predict_hit`.

| Level | Typical / hardest blow | Heal (now) | Share of a typical blow it undoes | Heal as a share of Prometheus / Enfina |
|---|---|---|---|---|
| 1 | Pro 14 / 15; Enf 12 / 14 | 16 (10) | Pro **114%**, Enf 133% (now 71%, 83%) | **53%** / 12% |
| 8 | Pro 19 / 37; Enf 17 / 33 | 18 (14) | Pro **95%**, Enf 106% (now 74%, 82%) | **55%** / 13% |
| 14 | Pro 24 / 47; Enf 20 / 42 | 20 (18) | Pro **83%**, Enf 100% (now 75%, 90%) | **56%** / 14% |
| 18 | Pro 23 / 45; Enf 18 / 36 | 21 (21) | Pro **91%**, Enf 117% (no change) | **55%** / 14% |
| 64 | Pro 84 / 126; Enf 47 / 101 | 35 (50) | Pro 42%, Enf 74% (now 60%, 106%) | 60% / 18% |

**Prometheus: yes, through Chapter I.**
- One Heal is more than half his health and undoes about one typical blow.
- It can't save him from the hardest blows: the Bombers' Self Destruct (37-47) downs him from full, and so do the 84-126 blows at 64. That belongs to the lethality rule, not to healing.

**Enfina: not made too hard to hurt.**
- One Heal is 12-18% of her health and undoes about one typical blow on her. A typical blow on her is smaller because of her Defense.
- She gains nothing special from it any more. Under the share-of-missing proposal she got 34-41, two blows' worth.
- Alithia has 2 World castings a long rest at level 1 and 4 from level 8. So a whole segment's Heals on Enfina are 4 × 18-21: 72-84, about four blows. Short rests do more for her (section 9).

---

## 6. Light Heal and Communion against their current values

- **Light Heal** (secondary action, a World casting): 11 / 12 / 13 / 14 at 1 / 8 / 14 / 18, against 7 (from 3) / 10 / 13 / 15 now.
  - It is useful in Chapter I: two thirds of a Heal, on top of a main action.
  - Late it falls to 22 against 36 now. Its only edge is then the action, since it costs the same World casting as Heal.
  - **When gates are short, Heal is the better spend.** When actions are short, Light Heal is.
- **Communion** (a Pandora casting, from 16): 14 per ally at 18 against 18 now; 22 against 43 at 64.
  - It stays below Heal per ally, as intended.
  - Per casting it still wins with a crowd: 3 allies × 14 = 42 against Heal's 21 at 18; 4 × 22 = 88 against 35 at 64.
  - Alone it is the weakest heal per casting (one Pandora casting for 14, against a World casting for 21). **It's a group heal, not a single one.**
- **Both lose most of their late-game value.** If they should keep pace with Heal's growth, their Mindfulness share could match Heal's 0.25 while keeping the lower base: 8 + 0.25 Mind + 0.2 weapon gives 17 at 18 and 30 at 64. That is a PROPOSAL alternative, not tested.

---

## 7. Enemy healers and bosses under the revision

| Who | Revised | Against now |
|---|---|---|
| **Priest** | Heal 16 → 35, Communion 11 → 22 (weapon base 6). At Sixty-Four (12): Heal 37. | Stronger at 1-14, about equal at 18-24, weaker after (35 against 46 at 64). |
| **Ranger** | Heal 16 → 25: its low Mindfulness (10-43) matters little now | Stronger at every level up to 54 (18 against 12 at 18). |
| **Mimic** | Its Mimicry passive moves every skill onto its Self, so it heals like a Priest if the rule reads "its healing stat" rather than literally Mindfulness. **Should follow that passive.** | About as now (21 against 19 at 18). |
| **Summoner** | Mend the Bound (×0.9 now) has no revised value | **OPEN.** Heal's formula would be 16 → 35. |
| **Alchemist / potion drinkers** | Potions keep their shares: 25-55% of max | As now: harmless on ordinary enemies. A boss drinking one would be a boss mechanic (section 8). No boss carries one now. |
| **Bosses** | Flat heals are 1-13% of their health. Share heals stay 50-55%. | - |
| **Erysichthon** | Its meal stays 6% of its health: **the existing implementation value, kept for now** (designer, 2026-10-24) | The changes below are separate PROPOSAL test values. |

**Erysichthon's meals: proposed changes (separate PROPOSAL test values; the 6% meal stays meanwhile):**
- **The amount:** one Heal of its level, instead of 6% of its max. That is 16 / 18 / 20 / **21** / 23 / 28 / 32 / 35 at the eight levels: 2.7% of its health at 18, 1.7% at 64.
  - With the other limits below, the laboratory fight gives it **21** from the carrion heap, against 329 from seven meals now.
- **The limits** (as before):
  - one meal a turn, costing its secondary action (needs code);
  - its own fallen regrow its parts but don't heal it.
- **The counterplay**, choose one to test:
  - **Gorging** (data only): a meal leaves it at −20% Defense until its next turn, through its existing fed effects and the existing `defense_change`. A stagger window by another name.
  - **An exposed weak point** (needs code): a meal opens its Belly Hole, which takes double damage until its next turn. It fits the creature: the food falls through the hole.
  - **Already there:** the party can taint the carrion (no heal; 90 Poison, +30 stagger) or feed it the bait keg (140 Fire, +50 stagger, the Belly Hole broken).

---

## 8. The cap, and boss healing

### The designer's decision (2026-10-24)

1. **No global heal cap.** `docs/healing_cap_proposal.md` stays as an **optional tuning tool**, not part of the baseline (ledger: OPTIONAL_TUNING_TOOL).
2. **Share-of-health healing is for a few rare, limited moves only:**
   - high-tier spells (Restoration, Grace);
   - the cure potions;
   - Resuscitate;
   - specific boss mechanics.
3. **Grace, Restoration and the party's other share heals are not capped.** That changes only if a specific boss encounter proves they make a degenerate loop.
4. **A boss heals to full or by a large share only through an explicit boss mechanic.** That means a mythic trait, a phase transition, a ritual, or a telegraphed action with counterplay. Such heals are:
   - limited: once per fight or once per phase, never repeatable as ordinary healing every turn;
   - visible: telegraphed, and interruptible where it fits;
   - interactive: tied to a phase change, a resource cost or a window of vulnerability.
5. **A boss that becomes degenerate through repeated healing gets a per-boss cap or condition**, never a universal one.
6. **Mechanics over numbers:**
   - declared ally heals;
   - meals;
   - rituals;
   - phase transitions;
   - consumable use, each with clear counterplay.
7. **Mythic full-heal mechanics stay OPEN** until a specific boss defines one.

### What the numbers say about it

**Flat heals need no cap.** The largest flat heal possible (Heal, Mercy I, weapon base 12) at each level is:

| Level | 1 | 7 | 8 | 18 | 24 | 33 | 41 | 45 | 54 | 64 |
|---|---|---|---|---|---|---|---|---|---|---|
| Largest Heal | 20 | 22 | 22 | 25 | 27 | 30 | 33 | 34 | 37 | 41 |

On a boss that is 1-13% of its health a cast, bounded by the formula.

**The share heals in the game now:**

| Share heal | Who | Fits the rule? |
|---|---|---|
| Restoration (50% of max), Grace (full) | Alithia, levels 54 and 64 | Yes: high tier, one or two castings a long rest |
| Cure potions (25 / 40 / 55% of max) | the party; the Alchemist and Sixty-Four's Priests and Sorcerers by pocket | Yes for the party (bought, limited). For an enemy, consumable use; a boss drinking one would need to be one of its explicit mechanics. |
| Resuscitate (back at 50% of max) | Alithia | Yes |
| **Soothed (Aura II, 24+)** | Alithia's passive: 5% of max at **every** turn start for allies near her | **Check.** It is share-based and repeats every turn. The rule allows that only on rare, limited moves. **OPEN for the designer.** |
| **Erysichthon's meal (6%)** | its boss mechanic: free, at most twice a turn, up to 7 in its laboratory fight | Kept as it is for now. It is a boss mechanic, but it is repeatable every turn rather than once a phase. The proposals in section 7 would bring it in line. |

**If a per-boss cap is ever needed** (the tuning tool): to never trim the party's own share heals, it must sit above a Potent Cure on Enfina (72-105) and Restoration with Mercy I (119-128). By chapter band that is 80 (1-7), 85 (8-18), 95 (19-33), 100 (34-45), 130 (46-55), 140 (56-64). No such cap is proposed.

**Risks to watch, rather than cap.** These would only matter in a specific boss fight:
- **A Mimic beside a boss** could copy Grace (a full heal) or Restoration. No boss fight has a Mimic now. If one ever does, the per-boss fix is making those two uncopyable (`can_be_copied`).
- **An enemy healer beside a boss** (none now) would add a flat 16-35 a turn. The designer's preferred shape for that is a declared ally heal, once a phase.
- **A boss with a Potent Cure** (none now) would get 55%. Under the rule that is a boss mechanic, not an item it simply carries.

---

## 9. With the short rest and the gates

The rest framework kept for testing:
- 2-3 short rests per dungeon segment, each giving back 50% of the missing health, no gates;
- **Meditate, option A:**
  - ceil(level / 6) points, once per dungeon segment;
  - a casting costs its gate's depth;
  - only castings from the shallower half of Prometheus's open gates;
- a long rest: full health, all gates, Meditate back.

**Between fights the short rest does the healing.**
- One short rest from 10% gives back about 3× a Heal on Enfina, 2× on Cyrus and Alithia, but under one Heal's worth on Prometheus.
  - At 18: Enfina +66, Cyrus +39, Prometheus +17, against a Heal of 21.
- That is the complement to the flat Heal:
  - the short rest, a share of the missing health, does most for the big health pools, between fights;
  - Heal, flat, does most for the small ones, during fights.
- Prometheus needs Alithia most, inside the fight, which is what the flat Heal gives him.

**Alithia's gates are the segment's attrition.**
- A short rest restores none, and Meditate is Prometheus's alone. Her World castings (2 at level 1, 4 from 8) pay for Heal, Light Heal and her World damage spells until the long rest.
- With a flat Heal of 18-21 in Chapter I, a segment's Heals add up to 72-84 across the party. That is enough to save Prometheus three or four times, not enough to sustain anyone through repeated focus.
- **Gate scarcity, not the heal's size, is what limits healing in a segment.**
  - That is the trade-off the laboratory runs measure: a casting on Heal is one not spent on damage.
  - Whether Alithia should get a Meditate of her own is still OPEN.

**The weapon.** If weapons should visibly raise her healing, 0.3 × weapon base isn't enough: a mace is +1. A version keeping today's value with no weapon, but felt with one, would be Heal = 9 + 0.25 × Mindfulness + 0.8 × weapon base. That is 13.8 at weapon base 6 (as now), and +3.2 with a mace. PROPOSAL alternative, not tested.

---

## Status

| Item | ImplementationState | DecisionStatus |
|---|---|---|
| Revised formulas (Light Heal, Heal, Communion, Restoration; Grace unchanged) | ABSENT | PROPOSAL (test values) |
| The share-of-missing-health hybrid | ABSENT | Superseded by the revision (2026-10-24) |
| Level-scaled heal cap (`docs/healing_cap_proposal.md`) | ABSENT | OPTIONAL_TUNING_TOOL: not a global rule (designer, 2026-10-24) |
| Healing policy: share heals only on rare limited moves; no global cap; big boss heals only as explicit mechanics; a per-boss cap or condition if a boss proves degenerate | - | APPROVED_DESIGN (designer, 2026-10-24) |
| Mythic full-heal and other big boss-heal mechanics | ABSENT | OPEN until specific bosses define them |
| Soothed (Aura II): a share heal every turn | PRESENT | OPEN: check against the policy |
| Erysichthon's meal, 6% | PRESENT | EXISTING_BASELINE, kept for now |
| Erysichthon's meal: one Heal of its level, one a turn, no heal from its own fallen; Gorging or an exposed Belly Hole | ABSENT | PROPOSAL (separate test values) |
| Mimic heals from its healing stat (Self, through Mimicry) | - | PROPOSAL |
| Mend the Bound; Mercy I on the revision; Light Heal and Communion's late value; the weapon's share | - | OPEN |
| Short rest, long rest, Meditate option A | ABSENT | PROPOSAL, kept for testing (designer, 2026-10-24) |
