# Erysichthon, started over (2026-11-27)

The designer's redesign: "Remove anything else it already has, we are starting over with Erysichthon", then two rounds of answers
the same day. Everything here is built. **PROPOSAL** marks my numbers; the designer took them as trials to play ("Your picks sound
good, I'll test them out"), the rest is theirs. His file is still `data/enemies/glutton.tres` (key `glutton`), so everything that
names him finds him. Suite: `erysichthon`.

## What he is

- Enormous, 4 x 4. Health 300 at level 1, 2100 at 64 (900 at 22, 786 at 18). Movement 8, initiative 6 (5 in the turn order, as
  every enemy is one lower so the party goes first on a tie).
- Immune to fire and earth (resistance 100), weak to poison (-25, **PROPOSAL**).
- Passives: **Hollow Frame** (kept: he folds to fit gaps), **Vitality Devour**, **Boss Immunities**, **Starving**.
- Skills: **Claw**, **Chomp**, **Gate Devour**; **Feast** from half health.
- Three reactions a round (`CombatantDefinition.reactions_per_round`, anybody can have it).
- A stagger bar that costs him no turn (below), and one part: the belly.
- Kept from before: name, look and tint, the title card "The Hunger That Ate Itself", his reveal and phase sounds, his AI's mind
  (Cunning, never keeps from hazards).
- Gone: Ravenous Bite, Grab, Devour, Catch the Scent, Rending Claws, Rib Maws; the Jaws, Belly Hole, Hind Legs, Second Head; meals,
  Gorged, Bile; the Gorge and The Hollow phases; `ai_glutton`. The systems stay in the game (the `glutton` suite tries them on his
  old self in `tests/fixtures/`); his old skills stay in `data/skills/enemies/`, used by nobody. Bile-Soaked, applied by nothing
  now, moved to `tests/fixtures/` with him.

## Boss Immunities (`data/passives/boss_immunities.tres`)

A passive for bosses to share. Cannot be Prone, Stunned, Hesitating, Confused, Deceived, Compelled, Frightened (Fear), Blind,
Deafened or Off Guard. It also carries his old non-condition immunities - never breaks and flees, cannot be taken alive, cannot be
thrown - so a boss never runs from the fight (**PROPOSAL**). He is the only boss in the game now (below).

## Vitality Devour (passive)

Every hit of his that lands drains 10 of the target's maximum health for the fight and heals him as much. It stacks, never below a
quarter of what they had; one hit may take them straight to that floor ("If a single hit reaches an ally to the quarter floor, then
that's fine"). Their health drops to the new maximum if it is above it. What it drains goes into his belly. The health bars on the
board show what has been drained as a dark end no heal reaches. Rules: `PassiveDefinition.devours_health`,
`Combat._vitality_devour`, `drain_health`.

## Starving (passive)

Each round he devours nothing - counted at the start of his turn, from his second - his blows gain +10% Output Efficiency, up to
+30%. The next thing he devours ends it. Rules: `PassiveDefinition.starving_step` and `starving_most`,
`Combat._starving_turn_begins`, `starving_bonus` (in `damage_dealt_multiplier`), `_fed`.

## Claw, Chomp and his turn

- **Claw**: one target within 2 tiles, x0.8 (Rending Claws' strength).
- **Chomp**: one target within 2 tiles, x1.2 (Ravenous Bite's), and 5 off their main stat for the fight - never below 10 or a
  quarter of what it was, whichever is more.
- **A turn** (`AttackSet`, `ai_attack_sets`): two Claws and a Chomp, one after another, at one target. From half health a second
  set at somebody else within 6 tiles - he lunges at them first, landing as near as there is room (`Combat.lunge_at`). With nobody
  else to go for, there is no second set. If a set's target falls, the rest of its blows go at whoever else is in reach
  (**PROPOSAL**).

## Gate Devour (reaction)

InstaHack renamed and reaching 20 tiles: a spell cast in his sight within 20 tiles is torn apart as it is cast, and swallowed. It
goes into his belly, and its caster cannot cast it while it is there: an X on its slot and "Devoured by Erysichthon" in its
tooltip. He holds two; a third pushes the first back out to its caster. Not a spell out of a Gate Nade or any item. It costs him
no gate (he has none); the caster keeps the gate and loses the action, as with InstaHack.

**The contest** (a trial: "Let's try contest for now"): he only swallows a spell from a caster whose casting stat is below his
Physical. At the same level they are equal (35 each at 22), so spells get through until Chomp and Feast wear the caster down;
breaking the belly gives the stat back. Otherwise he does not react at all, so no reaction is spent (`Combat.out_devours`,
`EffectDefinition.devour_spell_contested`).

## The belly

Not there until he devours something; then a 2 x 2 part where the Belly Hole was. Everything he devours grows its health and
maximum health: 1 a point of maximum health, 3 a point of main stat, 25 a spell, 15 an item, 1 a point eaten off a tree, and the
health left in somebody swallowed (**PROPOSAL**). Hits on it come off his own health too. Torn open, it lets out whoever is inside,
alive, and gives everything back to whoever it came from - maximum health, main stat, spells, items (not the Rotten Meal, which he
ate) - and he does not lose a turn. The first time, something an earlier victim carried falls out for whoever broke it: a Potent
Cure Potion, a Big Bomb or a Wildfire Gate Nade, at random (**PROPOSAL**). The next thing he devours grows it again. Everything
also comes back when he falls and when the fight ends. Its icons show what is inside over it, and he swells as he eats.

## Swallowed whole

A Chomp or a Feast landing on somebody under a quarter of their maximum health swallows them instead of hitting them ("I like the
new swallowing suggestion, do it. It also works for Feast"). The old Swallowing does the rest: they are inside him, Swallowed,
able only to strike at him - at his belly - and digested in two of his turns unless they get out. Out they come alive when the
belly is torn open, when he is staggered, or when he falls. A Feast passes over whoever is inside. Rules:
`EffectDefinition.devour_swallows_under`, `Combat._swallowing_effect`, `swallow_whole`, `_take_inside`.

## Feast

From the first time he drops to half health (phase **Famished**), once; from a quarter (phase **Insatiable**), every turn, and
nothing else. It takes his whole turn and is not telegraphed. It hits everybody of the party, anywhere on the field: four times a
Chomp's damage (x4.8), 10 off their main stat, 30 off their maximum health (only the quarter floor holds it back), and the first
item they have ready. He uses it as soon as he has it (**PROPOSAL**). Study shows Feast only once he has it. Phase names and lines:
**PROPOSAL**.

At 22, in the armour a party of that level wears (the best of the level-17 tier each may: there is no better cloth than
Prometheus's own):

| | Health | Armour | Defense | Feast |
|---|---|---|---|---|
| Enfina | 150 | Plate Harness | 36 | 83 (Iron Hide takes 10% off) |
| Cyrus | 88 | Hardened Leather | 28 | 103 |
| Alithia | 88 | Scale Coat | 32 | 97 |
| Prometheus | 39 | Basic Cloth Armour | 24 | 110 |

Damage = (weapon base 12 + 0.7 x his Physical 35) x 4.8 x 40 / (40 + Defense); the `erysichthon` suite measures the same in the
game. Three of the four go down from full health.

## Staggered

His bar: 150, filled 0.6 a point of damage and 15 for each condition he shrugs off (his old numbers), +50% Output Efficiency
against him while it lasts. Full, he is **Reeling** and keeps his turn: hit harder until the start of the next turn of whoever's
turn he was staggered in, and his bar cannot fill until then (the designer: "keep the damage vulnerability until the start of the
turn of the creature in whose turn the boss got staggered. When the damage vulnerability leaves, its stagger bar can increase
again. For Erysichthon lets have it like this for now"). Staggered, he heaves up whoever he has swallowed. Rules:
`StaggerDefinition.harder_until` (THE_STAGGERERS_NEXT_TURN), `Combat.REELING` (`data/conditions/reeling.tres`), `stagger`,
`_reeling_ends_for`. Other bosses' bars still cost them their turn (Its Lost Turns, the default). The hint line is **PROPOSAL**.

## The Rotten Meal (`data/items/rotten_meal.tres`)

A consumable that does 25 poison damage to whoever eats it, through any armour. Its description says nothing of him. Devoured by
Feast, it does the same to him - 31, since he is weak to poison - and is gone. 30 gold (**PROPOSAL**: below the 40-60 of Tier I in
`docs/consumables.csv`, since it only hurts), sold by the Travelling Merchant, first in Cyrus's belt on the arena stage.

## Demeter's grove (`data/objects/sacred_tree.tres`)

Sacred trees on the field. A Claw can go at one in reach instead of anybody: what it tears off the tree, he eats - healed by as
much, and into the belly. He does that when nobody is in that Claw's reach, or once a set when he is under half health. The trees
burn: weak to fire, -50. Health 40 at level 1, 400 at 64 (160 at 22, 137 at 18), Defense 0. All **PROPOSAL**. Picture: a
placeholder in `art/objects/sacred_tree_*.png`.

## What Study does not show

Study's sheet reads only what he has now. The boss health bar has no marks where a phase begins (`ui/boss_bars.gd`), and a boss's
codex second page lists only the phases that had begun the furthest time it was studied (`Campaign.codex_phases_seen`,
`CodexPage.second_page`); the journal no longer says the second page waits on "its first phase".

## The stages

- **Arena Mode: Erysichthon** (`data/encounters/boss_erysichthon.tres`, in place of `boss_glutton.tres`): the party and he at 22,
  four sacred trees (two where the carrion and the keg stood), the Rotten Meal first in Cyrus's belt, and the Gnawers as before -
  two on round 3, two when his belly first breaks (was: his Jaws), two once three of his side have fallen. The supporting enemy
  is still the designer's to choose.
- **The laboratory's Stage C** (`data/encounters/lab/lab_c_erysichthon.tres`): the same, at 18, as a copy of the arena stage.

## The Ash Warden and the Bellkeeper, gone (2026-11-27)

"Remove ash warden and bell keeper from the game." Their files, their aura and the bell are test fixtures now (`tests/fixtures/`,
for the `bosses` suite, which tries boss systems on them); the laboratory's Ash Warden variant and its two demo scenes are set aside
in `docs/set_aside/`; their stages are off Arena Mode. Two things wait on the designer:
- **The card game's Ash Warden and Bellkeeper elites** are still there (they borrow the barbarian's and the sorcerer's pictures now,
  the same art). Do they go too?
- **Alithia's Unbowed VI** (from 46) grants only immunity to Choking Ash, which only the Ash Warden inflicted. Choking Ash is kept
  so her passive still names something; what should Unbowed VI give instead?

## Still open

1. The card game's two elites, and Unbowed VI (above).
2. The stagger rule for other bosses, if any come (the designer: "I'll think about stagger and tell you").
3. My picks, as the designer tries them.
