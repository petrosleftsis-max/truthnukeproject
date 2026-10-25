# Healing and rest: what exists, and the proposal tested against it

> **Status, 2026-10-24:**
> - The share-of-missing-health proposal (section 2) is superseded by the flat-plus-scaling revision in `docs/healing_revision.md`.
> - The rest framework is kept for testing (sections 3-4), with Meditate option A.
> - **2026-10-25:** short and long rests and Meditate (option A, Prometheus only) are implemented as the designer gave them - see the table at the end and the ledger. Alithia gets no gate recovery; she has Devotion instead (two castings of her own for Heal or Dread Visage).
> - The current values (section 1) and the coherence list (section 5) still stand.

Prepared 2026-10-24 at the designer's request. **Nothing here is implemented.** Every new healing and rest value is a **PROPOSAL test value**, not final balance; the ledger (`docs/design_status_ledger.csv`) has a row for each.

Every current number below comes from the probe `tests/run.sh healing`, which works them out with the game's own functions (`Combat.predict_hit`, `heal_amount`, `heal_share_on`). It writes `docs/healing_inventory.csv`: every heal on every party member, the proposal beside it, the enemies' blows, the short rest and the gates. Since the follow-up it also covers levels 24, 41 and 54, and the cap; this report quotes the five levels it was written for.

**How to read the levels:** the party is made at each level with no gear (weapon base 6), on no path, with every passive its level allows. Alithia's Mindfulness is 10 / 18 / 25 / 30 / 85 at levels 1 / 8 / 14 / 18 / 64.

---

## 0. "Heal is 4-8" came from our export, not the game

The data export given to Perplexity listed Heal's effect as `min_amount 4; max_amount 8`. That range is never used. A heal with a skill behind it ignores the effect's min and max; they only stand in for a heal with no skill at all.

Heal really mends **10 at level 1, 14 at 8, 18 at 14, 21 at 18 and 50 at 64**.

The same goes for Light Heal (3-6), Cure Potion (25) and Medicine (15): their ranges are unused too.

The export is fixed. `tests/run.sh refdump` now writes each heal's real formula, and `docs/perplexity_combat_context.md` is rebuilt with it.

---

## 1. The current healing calculations

### The formula

`Combat.heal_amount` and `heal_share_on`, applied by `do_heal`:

> **heal = round( power x dial x (1 + the healer's heal bonus) ) + round( share x the target's max health )**

- **power**
  - A skill or spell: `weapon base + 0.7 x the stat` (`power_behind`). For a spell the stat is the caster's spellcasting stat, which is Mindfulness for Alithia, the Priest, the Ranger and the Summoner.
  - An item: its flat `item_power`, whoever uses it.
- **dial:** the effect's `heal_modifier` if set, otherwise the skill's `ability_modifier`.
- **heal bonus:** Alithia's **Mercy I** gives +0.1 from level 1. It applies to anything she uses, items included, but not to the share of health.
- **No defence and no randomness.** The result is capped at the target's max health.

So the **weapon is in every spell heal**: Alithia with a Votive Mace (weapon base 10) heals 2-4 more.

### Each source

| Source | Formula now | Scales from | Learned / gate | Status |
|---|---|---|---|---|
| **Light Heal** | (wb + 0.7 Mind) x 0.5 x 1.1 | Mindfulness | 3 / World, **secondary action** | EXISTING_BASELINE |
| **Heal** | (wb + 0.7 Mind) x 0.7 x 1.1 | Mindfulness | 1 / World | EXISTING_BASELINE |
| **Communion** | (wb + 0.7 Mind) x 0.6 x 1.1, each ally in radius 2 | Mindfulness | 16 / Pandora | EXISTING_BASELINE (replaced Revitalizer, APPROVED_DESIGN) |
| **Restoration** | (wb + 0.7 Mind) x 0.7 x 1.1 **+ 50% of max** | Mindfulness | 54 / Ogdoad | EXISTING_BASELINE |
| **Grace** | (wb + 0.7 Mind) x 0.7 x 1.1 **+ 100% of max**, radius 3 (full) | Mindfulness | 64 / Yaldabaoth | EXISTING_BASELINE |
| Purification *(not in the list, but a heal)* | (wb + 0.7 Mind) x 0.7 x 1.1, and lifts every harmful condition | Mindfulness | 41 / Nemesis | EXISTING_BASELINE |
| **Cure Potion** | **25% of max** (item power 0) | nothing | - (50 gold) | EXISTING_BASELINE |
| **Mediocre Cure Potion** | **40% of max** | nothing | - (120 gold) | EXISTING_BASELINE |
| **Potent Cure Potion** | **55% of max** | nothing | - (240 gold) | EXISTING_BASELINE |
| **Medicine** | 47 x 0.5 = **24 flat** (26 from Alithia), and lifts one condition | nothing | - (40 gold) | EXISTING_BASELINE |
| **Heal Gate Nade** | 30 x 0.7 = **21 flat** (23 from Alithia) | nothing | - (60 gold) | EXISTING_BASELINE |
| **Communion Gate Nade** | 50 x 0.6 = **30 flat** each (33 from Alithia), radius 2 | nothing | - (150 gold) | EXISTING_BASELINE |
| **Revitalizer Gate Nade** | - | - | - | **ABSENT**: replaced by the Communion Gate Nade (2026-10-24) |
| Revitalizer (spell) | (wb + 0.7 Mind) x 1.3, radius 3 | Mindfulness | 9 / Pandora | **Unused** (`data/skills/unused/`) |
| Light Swing (Enfina) | (wb + 0.7 Physical) x 0.3, on herself, with the blow | Physical | 1 | EXISTING_BASELINE |
| Resuscitate (Alithia) | stands the fallen up at **50% of max**, 10% weaker | - | 9 / **Pandora (opens at 14)** | EXISTING_BASELINE |
| Aura II: Soothed (Alithia, 24+) | 5% of max at each ally's turn start, near her | - | passive | EXISTING_BASELINE |
| Elemental Tactician (Prometheus, 24+) | overheal 0.4 x his power on an ally his spell lands on (gone after the fight) | Intellect | path | EXISTING_BASELINE |
| **Enemy: Priest** | Heal and Communion: the same skill files as Alithia's | Mindfulness (main stat) | - | EXISTING_BASELINE |
| **Enemy: Ranger** | Heal | Mindfulness (**not its main stat**: 10 to 43) | - | EXISTING_BASELINE |
| **Enemy: Summoner** | Mend the Bound: (wb + 0.7 Mind) x 0.9, no gate | Mindfulness | - | EXISTING_BASELINE |
| Enemy: Alchemist | drinks and throws cure potions from its pocket (25-55% of max) | - | - | EXISTING_BASELINE |
| Enemy: Erysichthon | 6% of its max per meal | - | - | EXISTING_BASELINE |

**Scaling from Mindfulness:**
- **These scale from it:** all of Alithia's heals, the Priest's and Ranger's Heal and Communion, and the Summoner's Mend the Bound.
- **These don't:**
  - the potions, Medicine and Gate Nades: a flat power, or a share of health;
  - Light Swing, which scales from Physical;
  - Resuscitate and Soothed, which are shares of health.

### Values on the party (no gear; Alithia healing, so Mercy I is in)

Each cell shows what it mends, with the share of the target's max health in brackets. A dash (-) means not learned at that level.

| Level | Max health (Enf / Cyr / Pro / Ali) | Light Heal | Heal | Communion (each) | Restoration | Grace |
|---|---|---|---|---|---|---|
| 1 | 130 / 75 / 30 / 75 | - (learned at 3: would be 7) | **10** (Cyr 13%, Pro 33%) | - | - | - |
| 8 | 137 / 79 / 33 / 79 | 10 (Cyr 13%) | **14** (Cyr 18%, Pro 42%) | - | - | - |
| 14 | 142 / 83 / 36 / 83 | 13 (Cyr 16%) | **18** (Cyr 22%, Pro 50%) | - (learned at 16) | - | - |
| 18 | 146 / 86 / 38 / 86 | 15 (Cyr 17%) | **21** (Cyr 24%, Pro 55%) | 18 (Cyr 21%) | - | - |
| 64 | 190 / 115 / 58 / 115 | 36 (Cyr 31%) | **50** (Cyr 43%, Pro 86%) | 43 (Cyr 37%) | Enf 145, Cyr 108, Pro 79 | full |

The items, which are the same at every level unless they are shares of health:

| Item | Enfina | Cyrus / Alithia | Prometheus |
|---|---|---|---|
| Cure Potion (25%) | 33 at L1 to 48 at L64 | 19 to 29 | 8 to 15 |
| Mediocre (40%) | 52 to 76 | 30 to 46 | 12 to 23 |
| Potent (55%) | 72 to 105 | 41 to 63 | 17 to 32 |
| Medicine | 26 (24 from anyone but Alithia) | 26 | 26: **87% of his health at L1** |
| Heal Gate Nade | 23 (21) | 23 | 23: 77% of his health at L1 |
| Communion Gate Nade, each | 33 (30) | 33 | 33: **more than his whole health at L1** |

At levels 1-18 the **Heal Gate Nade** (60 gold) **out-heals the Heal spell** it copies (23 against 10-21). The **Communion Gate Nade out-heals Communion** at 18 (33 against 18 each).

---

## 2. Current against the proposed hybrid (PROPOSAL)

The proposal (test values):

| Spell | Formula |
|---|---|
| Light Heal | 10% of missing + 0.3 x Mindfulness |
| Heal | 20% of missing + 0.5 x Mindfulness |
| Communion | 10% of missing + 0.3 x Mindfulness, to each ally in its area |
| Restoration | 50% of max + 0.5 x Mindfulness |
| Grace | unchanged: full health |

No cap, diminishing returns or hidden limit, beyond the heal stopping at full health.

Two cases: the patient **half down** (50% of their health missing) and **nearly down** (90% missing). Each cell is **proposed / now**. The proposals are without Mercy I. If Mercy I still multiplies, add a tenth (the CSV has both).

**Heal**

| Level | Enfina | Cyrus / Alithia | Prometheus |
|---|---|---|---|
| 1 | 18 / 10 · 28 / 10 | 13 / 10 · 19 / 10 | 8 / 10 · 10 / 10 |
| 8 | 23 / 14 · 34 / 14 | 17 / 14 · 23 / 14 | 12 / 14 · 15 / 14 |
| 14 | 27 / 18 · 38 / 18 | 21 / 18 · 28 / 18 | 16 / 18 · 19 / 18 |
| 18 | 30 / 21 · 41 / 21 | 24 / 21 · 30 / 21 | 19 / 19 · 22 / 21 |
| 64 | 62 / 50 · 77 / 50 | 54 / 50 · 63 / 50 | 29 / 29 · 52 / 50 (both stop at full) |

**Light Heal, Communion and Restoration** (Cyrus; the CSV has everyone)

| Level | Light Heal | Communion, each | Restoration |
|---|---|---|---|
| 8 | 9 / 10 · 13 / 10 | (not learned) | (not learned) |
| 14 | 12 / 13 · 15 / 13 | (not learned) | (not learned) |
| 18 | 13 / 15 · 17 / 15 | 13 / 18 · 17 / 18 | (not learned) |
| 64 | 31 / 36 · 36 / 36 | 31 / 43 · 36 / 43 | 58 / 58 · 100 / 104 |

### What the comparison shows

- **Heal gets a little stronger, mostly on Enfina.** On Cyrus and Alithia it gains 3-10 in Chapter I. On Enfina it gains 8-20. On **Prometheus it is no stronger**: from 2 less to 1 more.
  - The reason: today's power term carries the weapon base. That is 6 x 0.7 x 1.1, worth about 4.6 on every Heal, and about 0.54 per point of Mindfulness against the proposal's 0.5.
  - The share of missing health replaces it. That pays on a big health pool and hardly at all on a small one.
- **Light Heal and Communion barely move, and weaken on small targets.**
  - Light Heal changes by a few points either way, and loses 3-4 on Prometheus at 18.
  - Communion loses up to 7 per ally at 18 and up to 12 at 64. It gains a little only on a badly hurt Enfina.
- **Restoration is already a hybrid** (50% of max plus Heal's power). The proposal changes it by 0-7.
- **Mindfulness stays meaningful.** In the proposed Heal it is 5 at level 1, 9 at 8, 15 at 18 and 42 at 64: between a quarter and four fifths of each heal on Cyrus, more as levels rise.
  - Weapons drop out of heals altogether. Today a mace adds 2-4.

**So the proposed coefficients don't make healing much stronger.** They move it from small targets to large ones, and from the weapon to the patient's missing health. If the goal is "a heal matters", the first test will show whether 20% is enough. The levers are visible: the missing share, or the Mindfulness coefficient.

---

## 3. Against party health, enemy blows and the short rest

**Enemy blows** come from the real fights at each level. The party is made at that level against every enemy, each using its strongest attack (`predict_hit`, Defense bands in):
- 1: the Sewer Intro Fight;
- 8: the Lab Fight and the Hired Blades;
- 14: the City Fight and the Dungeon Demo's three;
- 18: the laboratory sequence's three;
- 64: Sixty-Four.

*Typical* is the median of the enemies' best blows; *hardest* is the worst.

**Cyrus** (Alithia is the same):

| Level | Max | Typical blow | Hardest blow | Heal now | Heal proposed, nearly down | One short rest from 10% | Two / three short rests |
|---|---|---|---|---|---|---|---|
| 1 | 75 | 14 (19%) | 15 | 10 | 19 | +34 (8 → 42) | 59 / 67 |
| 8 | 79 | 19 (24%) | 37: Self Destruct | 14 | 23 | +36 (8 → 44) | 62 / 71 |
| 14 | 83 | 24 (29%) | 47: Self Destruct | 18 | 28 | +38 (8 → 46) | 65 / 74 |
| 18 | 86 | 23 (27%) | 45: Self Destruct | 21 | 30 | +39 (9 → 48) | 67 / 77 |
| 64 | 115 | 84 (73%) | 126: Greatsword, more than his health | 50 | 63 | +52 (12 → 64) | 90 / 103 |

**Prometheus:**

| Level | Max | Typical blow | Hardest blow | Heal now | Heal proposed, nearly down | One short rest from 10% |
|---|---|---|---|---|---|---|
| 1 | 30 | 14 (47%) | 15 | 10 | 10 | +14 (3 → 17) |
| 8 | 33 | 19 (58%) | 37 (downs him) | 14 | 15 | +15 |
| 14 | 36 | 24 (67%) | 47 (downs him) | 18 | 19 | +16 |
| 18 | 38 | 23 (61%) | 45 (downs him) | 21 | 22 | +17 |
| 64 | 58 | 84 (145%) | 126 | 50 | 52 | +26 |

**Enfina:** typical 12 / 17 / 20 / 18 / 47 at the five levels; Heal now 10 / 14 / 18 / 21 / 50; proposed nearly down 28 / 34 / 38 / 41 / 77.

### What it means

1. **In Chapter I a Heal already undoes most of one typical blow.**
   - On Cyrus and Alithia it undoes 70-90% now, and 115-135% with the proposal when they are badly hurt.
   - Healing feels weak because of the economy, not the number:
     - it costs Alithia's main action against 5-10 enemies each landing a blow;
     - it costs a World casting she would otherwise spend on damage: 2 a long rest at level 1, 4 from level 8.
2. **The short rest will do most of the healing between fights.** One short rest gives Cyrus back 34-39 in Chapter I, two to three of today's Heals, for nothing. Two short rests bring a badly hurt member back to about three quarters, three to about nine tenths.
   - So healing spells matter mostly inside a fight, keeping someone up. That is exactly where a share of the missing health pays most.
3. **Gates become the segment's real attrition.** A short rest restores no gates, so every Heal cast in a segment is a World casting gone until the long rest. Healing competes with damage for the same castings, which is the trade-off the laboratory runs are measuring.
4. **At 64 no heal formula helps.** The typical blow takes 73% of Cyrus's health, and the hardest is more than all of it. That is the level-64 regression (`chapter1_audit.md`, section 9), a party-health and enemy-damage question rather than a healing one.
5. **Prometheus is the edge case.**
   - The typical blow takes half to two thirds of him, and the Bombers' Self Destruct downs him from full.
   - A share of *his* missing health is small, so the hybrid barely helps him.
   - He is protected by staying out of reach, not by being healed. That fits the lethality rule.

---

## 4. Meditate: gate recovery (PROPOSAL)

As specified:
- once per dungeon segment, during one of its short rests;
- not again until the next long rest;
- only shallow gates.

**The machinery is already there.** A dungeon rest can already offer Prometheus a gate recovery: `DungeonDefinition.gate_recoveries`, `gate_recovery_points` and `gate_costs`, with `Campaign.recover_gates` and the rest panel's rows.
- The player spends points on castings, each costing its gate's depth: World 1, Hermes 2, Pandora 3, and so on.
- The Dungeon Demo (party at 14) gives **one recovery a run, 3 points**. That is the EXISTING_BASELINE to compare with.
- Meditate would be that recovery, once per long-rest cycle instead of once per run, with the points below.

Prometheus's gates (`Stats.GATE_STEPS`; the "pool" counts each casting at its depth):

| Level | His castings | Pool |
|---|---|---|
| 1 | World 2 | 2 |
| 8 | World 4, Hermes 2 | 8 |
| 14 | World 4, Hermes 3, Pandora 2 | 16 |
| 18 | World 4, Hermes 3, Pandora 3 | 19 |
| 24 | + Charon 2 | 27 |
| 33 | + Charon 3, Tartarus 2 | 41 |
| 45 | + Nemesis 1, Sophia 1 | 54 |
| 55 | + Ogdoad 1, Gnosis 1 | 71 |
| 64 | 24 castings up to Yaldabaoth | 109 |

Three options, all PROPOSAL. Each cell gives the points, the deepest gate it may restore, and the share of his pool at most.

| | Early: Chapter I, 1-18 | Mid: Chapters II-III, 19-45 | Late: Chapters IV-V, 46-64 |
|---|---|---|---|
| **A. Depth points by formula** (recommended first test): `ceil(level / 6)` points, nothing deeper than the shallower half of his open gates | L1: 1, World (50%) · L8: 2, World (25%) · L14-18: **3, up to Hermes** (16-19%) | L24: 4, Hermes (15%) · L33: 6, Pandora (15%) · L45: 8, Charon (15%) | L55: 10, Tartarus (14%) · L64: 11, Tartarus (10%) |
| **B. Depth points by chapter** | 1 point to level 7; **3 points** from 8, up to Hermes (Pandora from 14) | 6 points, up to Charon | 10 points, up to Tartarus |
| **C. Castings, shallowest spent first** | 1 casting, World or Hermes | 2 castings, up to Pandora | 3 castings, up to Charon |

- **Why A first:**
  - It matches the existing baseline at 14-18 (3 points), so the Dungeon Demo's numbers carry over.
  - It holds a steady 10-19% of his pool from level 8 to 64.
  - "Shallow" means the same thing at every level: the shallower half of his open gates.
- **B** is simpler to explain, but it gives 38% of his pool at level 8.
- **C** is the easiest to read on screen, but the slowest to grow.
- **Level 1 is an edge in every option.** He has only two World castings, so one restored is half his pool.

**Not decided by the proposal:**
- whether a short rest revives the fallen (dungeon rests can now: `rest_revives`);
- whether it ends conditions or frailty;
- whether it brings back the gates used outside fights (Iris);
- whether the player chooses when to take each of the 2-3 short rests;
- whether Alithia gets any gate recovery (OPEN since the audit, row 11).

---

## 5. What would need adjusting to stay coherent with the hybrid

**Data and design (all OPEN or PROPOSAL; none changed):**

1. **Enemy healers share the skill files.**
   - The Priest's and Ranger's Heal and the Priest's Communion use Alithia's own `heal.tres` and `communion.tres`, so changing those changes the enemies too.
   - On enemies' larger health the share of missing pays more. On a nearly-down Ogre:
     - the Priest's Heal goes 19 → 41 at 18, and 46 → 90 at 64;
     - the Ranger's goes 12 → 34 at 18, because its low Mindfulness stops mattering.
   - Fights with a healer would last longer.
   - **Decided 2026-10-24:** one rule for everyone, with a level-scaled cap. See `docs/healing_cap_proposal.md`.
2. **Gate Nades.** They copy their spell's dial but use a flat power. Under the hybrid they need their own rule: for example, the spell's share of the missing health plus the nade's flat power in place of Mindfulness.
   - They already out-heal their spells in Chapter I.
3. **Medicine** is flat 24 (+1 condition lifted): 87% of Prometheus at level 1, 23% of Cyrus at 64. The potions are shares of max health. A share would make it coherent with them.
4. **The cure potions** are shares of *max* health (25/40/55%), while the hybrid spells take shares of *missing* health. That's fine as long as potions stay a gold cost. But the 50-gold Cure Potion (22 on Cyrus at 18) is in the same range as a proposed Heal (24-30). Check them against `docs/consumables.csv`.
5. **Purification** (41, Nemesis) is a heal not in the proposal. It needs a hybrid value. Heal's, plus its cleanse, would be the obvious test.
6. **Mercy I** (+10%) multiplies the power part only, before the share of health. **Decide** whether it multiplies the whole hybrid amount.
7. **Resuscitate** brings back 50% of max through Pandora. The skill is learned at 9, but Pandora opens at 14, so it can't be cast before then. That's a gap to check whichever way healing goes.
8. **Revitalizer** is in `data/skills/unused/` and has no Gate Nade. Nothing to do unless it comes back.
9. **Light Swing, Soothed, Elemental Tactician's overheal and Erysichthon's meals** are already self-scaling or not heals. Nothing to change.
10. **Unused data:** Heal's 4-8, Light Heal's 3-6 (and a `damage_modifier` 0.5 that does nothing to a heal), Cure Potion's 25 and Medicine's 15 are dead values that misled the export. Clearing them changes nothing in play. PROPOSAL.
11. **Mindfulness and Intuition.**
    - Mindfulness already feeds all of Alithia's spells (damage and heals) and her contested skills: Persuade, Bewilder, Dread Visage, Flash, Frozen River, Holy Lance, River Flow.
    - **Intuition doesn't use it at all**: reading a foe has no stat and no contest.
    - Tying Intuition to Mindfulness would be a new design item. OPEN.

**Code (what implementing would touch, for the estimate):**
- `heal_amount` takes no target today, and the panel shows one number. A share of the missing health needs the target. The aim prompt (`predict_hit`) already has one; the action panel's "heals N" would become "20% of missing + N".
- The AI's heal choice (`_ai_heal_key`, the healer and alchemist archetypes) ranks heals by amount, so it would need the patient too.
- The dungeon rest (`Campaign.rest_party`) heals to full now. A short rest of 50% of the missing health, a long rest, and Meditate per segment would replace it.
- `gate_recoveries` counts per run, so it would need resetting at each long rest.

---

## 6. Status

| Item | ImplementationState | DecisionStatus |
|---|---|---|
| Current heals, as above | PRESENT | EXISTING_BASELINE |
| Hybrid healing coefficients | ABSENT | PROPOSAL (test values) |
| Short rest: 2-3 a segment (2-4 late), 50% of missing, no gates | PRESENT (2026-10-25: whenever called) | APPROVED_TRIAL (50% a PROPOSAL test value) |
| Long rest: full health, the fallen up, the weakening lifted, all gates and Iris, Meditate and Devotion back | PRESENT (2026-10-25) | APPROVED_TRIAL |
| Meditate: option A, Prometheus only | PRESENT (2026-10-25) | APPROVED_TRIAL (the numbers PROPOSAL test values) |
| Enemy heals under the hybrid; Gate Nades, Medicine and Purification; Mercy I's place | ABSENT | OPEN |
| The export showing each heal's real formula | PRESENT | - (a fix to the documentation tool) |
