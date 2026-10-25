# Messengers of Truth - the combat system, everything in it

This file explains how combat works in *Messengers of Truth* and lists everything that exists in it right now: every skill, spell, passive, path, condition, item, piece of gear and enemy, with the numbers the game actually uses. It is meant as the full context for a conversation about the game's design and balance.

- **The game:** a turn-based tactical RPG on a square grid, made in Godot 4.7.
- **The party:** four characters - Enfina, Cyrus, Prometheus and Alithia.
- **Around the fights:** the story is told between fights in conversations, exploration maps, stealth stages, point-and-click pictures and hacking minigames.
- **The numbers** follow the design handoff's status model (docs/handoff_0.1), in two columns:
  - **ImplementationState:** PRESENT, ABSENT or VERIFY.
  - **DecisionStatus:** EXISTING_BASELINE, APPROVED_TRIAL, PROPOSAL, OPEN or APPROVED_DESIGN.

  Everything in Part 3 is PRESENT. Values applied from the designer's sheets are APPROVED_TRIAL: approved for testing, not final balance. Part 4 lists the OPEN variables no sheet covers. A sheet's ranges are references for testing, not decisions.

  Every value and change, with its source, value before and after, dependencies, evidence, acceptance test and outcome, is in docs/design_status_ledger.csv. The verified Chapter I and level-64 audit is docs/chapter1_audit.md, with every value in docs/chapter1_inventory.csv.

How it is laid out:

- **Part 1** is the rules, in plain words.
- **Part 2** is the progression plan: what each character gets at levels 1, 8, 16, 24, 32, 41, 54 and 64, and how each planned row became a real skill or passive.
- **Part 3** is generated straight from the game's data files: every skill, path, passive, condition, item, piece of gear and enemy.
- **Part 4** is the designer's standing decisions, and the open questions.

---

# Part 1 - The rules

## 1. The party

| Who | What they are | Main / secondary attribute | Spells from |
|---|---|---|---|
| **Enfina** | A greatsword fighter and the party's wall. Big melee blows, Guard, Grab and Hurl, Climb onto monsters. Her Measured Eye studies whoever she hits. | Physical / Self | (no spells) |
| **Cyrus** | A rogue: rapier and gun, poison and burning ammunition, Steal, Stealth, Slip Past, Deceive. He is light-footed (Stealth, Slip Past and Run as secondary actions), has Quick Hands (items as a secondary action), Nade Juggler (throws any Gate Nade, as a secondary action) and Cat Burglar (I: +2 movement on a turn started in cover, from level 1; II: +2 always and climbs anywhere, from 24). | see Part 3 | (no spells) |
| **Prometheus** | An elemental mage of the five elements, and the party's hacker. He **learns** his spells from spellbooks (or by taking a Gate Nade apart). He can Hack an enemy's declared move, InstaHack a spell as it is cast, and Dispel Magic. | see Part 3 | Intellect |
| **Alithia** | A priestess: heals, cleanses, revives (Resuscitate), Idol (holy) and water spells, and illusions. Her Intuition reads what an enemy will do next turn and holds it to that. She **grows into** her spells by level. | see Part 3 | Mindfulness |

At level 24 each character chooses one of three **paths** (subclasses), for good:

| Character | Paths |
|---|---|
| Enfina | Vanguard, Juggernaut, Warden of Cover |
| Cyrus | Skirmisher, Saboteur, Trapper |
| Prometheus | Elemental Vanguard, Elemental Tactician, Elemental Conductor |
| Alithia | Battle Chaplain, Illusory Shepherd, Inquisitor |

A path hands something out at 24, 32, 41, 54 and 64. The Illusory Shepherd hands out two things at each.

## 2. Levels and attributes

- **Levels:** there are 64. The number is the isopsephy of ἀλήθεια (truth). Level 55 is ΛΗΘΗ (forgetting), and the character sheet hides everything past it until Chapter V.
- **How the party levels:** at story milestones, not through experience. There are five chapters, each leveling slower than the last: Chapter I ends at 18, II at 33, III at 45, IV at 55 and V at 64.
- **Attributes:** Physical, Mindfulness, Intellect and Self, plus Defense.
  - Each character has a **main** and a **secondary** attribute.
  - The main one climbs evenly from 10 at level 1 to 85 at level 64.
  - The secondary is half of the main, but never below 10.
  - Every other attribute stays at 10.
- **Defense** is not worked out from the attributes:
  - The party's follows the player sheet's armour bands, the same for all four: 12 from level 1, 20 from 8, 28 from 17 to 64. Armour worn in the story stands in for it (Padded Jacket 12, Brigandine 20, Plate Harness 28).
  - Every creature has its own Defense by level: a level-1 value climbing evenly to a level-64 value, or steps (the party's). A fight can override it per combatant.
  - The enemies' come from the enemy progression sheet: frail enemies 5 → 30, average 10 → 60, tanky 18 → 65.
- **Health** also climbs evenly from a level-1 value to a level-64 value. Part 3 gives both for everyone.
  - The party, at level 1 → 64: Enfina 130 → 190, Cyrus 75 → 115, Alithia 75 → 115, Prometheus 30 → 58. The player sheet (player_hp_defense_progression.csv) keeps exactly these.
  - The enemies follow the enemy progression sheet. HP per tier, from tier I to tier IV:

    | Kind | Tier I | Tier II | Tier III | Tier IV |
    |---|---|---|---|---|
    | Frail | 25-40 | 40-60 | 60-80 | 70-90 |
    | Average | 60-90 | 100-140 | 140-180 | 160-200 |
    | Tanky | 100-130 | 150-190 | 200-240 | 230-280 |

  - Each enemy's line passes through its kind's band at the middle of every tier.
  - Frail: rats, gnawers, imps, the Summoner, Sorcerer, Bomber and Alchemist.
  - Average: Hired Bow, Priest, Ranger, Mimic, Bound Beast and Sellsword.
  - Tanky: Ogre, Barbarian, Golem and Pit Champion.
  - Bosses and the giant Behemoth and Colossus are outside the sheet.
- **Known imbalance:** party health barely grows, while every hit grows about 5×. Even at Defense 28, at level 64 a single enemy blow can down anybody but Enfina; see Part 4.
- **How long things last:** "N turns" is N of the target's own turns.
  - Warning Shot's -1 movement for 2 turns holds through 2 of the target's turns. A 3-turn Burn ticks 3 times, 4 with Cyrus's DoT Master II.
  - Landing on whoever is acting, the rest of the current turn comes on top: Run 1 is this turn and the next. Kept by the designer (APPROVED_DESIGN, 2026-10-24).
  - Most effects wear off as their last turn ends. Some (Guard) wear off as the turn after starts, so they cover the enemies' turns in between.
- **Movement:** the party walks 6 tiles a turn. Cyrus walks 8 on a turn he starts in cover (Cat Burglar I), and 8 always (10 in cover) from 24 (Cat Burglar II); Prometheus 8 as an Elemental Vanguard. Enemies have their own speeds: 4, 6, 7, 9, up to 18 for the Illusory Dragon.
- **Milestone tiers:** the progression plan puts milestones at levels 1, 8, 16, 24, 32, 41, 54 and 64 (tiers 0-7).
  - Skill multipliers climb by tier. Melee goes 1.0 → 1.5 (8) → 2.2 (54) → 2.5 (64).
  - Caster nukes go 3.1 (32), 4.2 (41), 5.4 (54), 6.0 (64).
  - Damage-over-time dials are 0.1-0.45, lasting 1-3 turns.
  - Defence debuffs are -20 to -25%; defence penetration is 25%, 50% or 75%.

## 3. A turn

- **Turn order:** a round is everybody once, in initiative order.
  - Somebody with more than one turn a round (a boss) is put in again, spread evenly through the round.
  - The turn queue shows a face for every turn.
- **Before the fight:** there is usually a deployment phase, where the party is arranged on its starting tiles.
- **On their turn,** everybody has:
  - **movement**: tiles of walking, spent in any amount around their actions. Terrain costs depend on how they get about (ground, flying, mounted).
  - one **main action**: most skills, spells and items.
  - one **secondary action**: lighter moves such as Run, Slip Past, Intuition, Command, Loot, Bribe, Mist Step and Rummage. Passives can let main-action skills be used as secondary ones too.
  - one **reaction**, between their own turns.
- **No cooldowns.** A move is limited instead by:
  - a gate (spells),
  - **Uses Per Short Rest**,
  - **Needs Read** (only on somebody Alithia's Intuition has read),
  - or **Lands In Cover** (Cover Leap must land beside cover).
- **Leaving somebody's reach** can set off their reaction (an attack of opportunity). **Slip Past** lets you leave reach without doing so. It is a secondary action for Cyrus from level 1, through his Elusive passive.

## 4. How a hit is worked out

```
Base damage   = Weapon Base + 0.7 x the attribute it scales from
Final damage  = Base x Ability Modifier x 40 / (40 + Defense), rounded, never below 1
```

- **Weapon Base** is 6 unarmed and is replaced by the weapon worn (10-11 for the best ones now).
- **A skill** scales from its own attribute.
- **A spell** always scales from its caster's spellcasting attribute: Intellect for Prometheus and the Sorcerer, Mindfulness for Alithia, the Priest, the Ranger and the Summoner.
- **An item** has a flat **Item Power** of its own. A bomb is the same bomb whoever throws it.
- **Defense** gives diminishing returns: 40 halves a hit and 120 quarters it.
  - **Ignores Defense** lowers the target's Defense for that hit only, by a percentage.
- **Damage types** (13):
  - the five elements: Fire, Water, Wind, Earth, Physical;
  - their upgraded forms: Plasma, Ice, Lightning, Metal, Acid;
  - and Poison, Psychic and Idol (holy).
  - Every combatant has a resistance per type. Negative means weak to it; 100 means immune.
- **Hit chance** is the skill's own accuracy plus accuracy changes from conditions, between 0 and 100.
  - The "untouchable" (the Illusory Dragon) cannot be hit at all.
- **Contested skills** do not roll.
  - The caster's attribute, plus any contest bonuses from passives, is weighed against the target's named attribute.
  - Higher wins and the skill lands in full.
  - Lose, and it is a **graze**: half damage and none of its other effects.
  - A contested *item* weighs its own Item Power instead.
- **Bonuses to a hit** add together into one multiplier, for example:
  - Kindling (each spell cast this fight makes the next hotter: +5% each, up to 15/30/45% by rank);
  - a target **Exposed** to this attacker (+20%);
  - a faction the party knows (+15%);
  - passives that hit harder against the afflicted, the weak to an element, those taking lingering damage, or on a turn spent standing still;
  - the paths' bonuses (Flanker, Ambush Strike, Righteous, Crusade...).
- **A passive's ranks are one passive** (Momentum I and II, Iron Hide I-III): each rank adds to the ones before, and only the highest unlocked is shown, with the totals.
- **Damage over time** (Burn, Poisoned, Frozen, Corroded...) ticks at the start of the victim's turns.
  - Each tick is the inflicter's base damage times the condition's own dial. The skill's Ability Modifier does not apply: that sizes the hit, not the burn after it.
  - Passives make lingering damage harder or longer.
- **Heals** are base x the heal dial, with no defence and no randomness, so a heal can be counted on. Some heals give back a share of max health instead (the cure potions: 25%, 40%, 55%).
- **Overheal** is health on top of health. It is taken first, never stacks, and is gone by the end of the fight.

## 5. Gates (spell slots)

Spells are cast through ten **gates**. Each gate opens at a level and has so many castings. The table is D&D's full caster table, stretched so that its level 20 is level 64 here:

| Level | World | Hermes | Pandora | Charon | Tartarus | Nemesis | Sophia | Ogdoad | Gnosis | Yaldabaoth |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 2 | | | | | | | | | |
| 4 | 3 | | | | | | | | | |
| 8 | 4 | 2 | | | | | | | | |
| 11 | 4 | 3 | | | | | | | | |
| 14 | 4 | 3 | 2 | | | | | | | |
| 18 | 4 | 3 | 3 | | | | | | | |
| 21 | 4 | 3 | 3 | 1 | | | | | | |
| 24 | 4 | 3 | 3 | 2 | | | | | | |
| 28 | 4 | 3 | 3 | 3 | 1 | | | | | |
| 31 | 4 | 3 | 3 | 3 | 2 | | | | | |
| 34 | 4 | 3 | 3 | 3 | 2 | 1 | | | | |
| 41 | 4 | 3 | 3 | 3 | 2 | 1 | 1 | | | |
| 47 | 4 | 3 | 3 | 3 | 2 | 1 | 1 | 1 | | |
| 54 | 4 | 3 | 3 | 3 | 2 | 1 | 1 | 1 | 1 | |
| 57 | 4 | 3 | 3 | 3 | 3 | 1 | 1 | 1 | 1 | |
| 61 | 4 | 3 | 3 | 3 | 3 | 2 | 1 | 1 | 1 | 1 |
| 64 | 4 | 3 | 3 | 3 | 3 | 2 | 2 | 1 | 1 | 1 |

- **Refilling:** gates come back at the start of every fight in the story. In a dungeon they come back only at a long rest, or some through Prometheus's Meditate at a short rest.
  - Later in the game the party will fight several fights between rests. Gates then become scarce, and the fighters (Enfina and Cyrus, who use no gates) should outshine the casters.
- **Gates outside a fight:** the **Gates of Iris** works like Hermes and is used for casting outside fights (Invisibility on a stealth map). A second outside gate, Mnemosyne, is planned.
- **Spells never rank up.** A stronger version of a spell is a spell of its own: Burner and Wildfire, River Flow and Frozen River.
  - Moves that are not spells can rank up. Greatsword Attack, for example, is x1.0, then x1.5 from 8, then becomes Titanfall at 64.
- **Gate Nades** are spells sealed in a shell, like scrolls in other games.
  - Throwing one needs no gate and no level, only that the thrower knows or could learn the spell.
  - Cyrus can throw any of them, and as a secondary action.
- **Spellbooks** teach Prometheus his spells. In Arena Mode every character knows every spell of theirs.
- **Choosing the gate:** Dispel Magic asks which gate to cast it through. It reaches only what came through that gate or a shallower one.

## 6. Skills

**Range and aim:**

- Range runs from a minimum to a maximum.
- **Melee** and ranged are separate from range (a melee move can reach further than the next tile).
- Area shapes: a diamond of a radius, a line of a length and width, a cone, or a square.
- A skill can need a clear line (**Respects Blocking**), hit both sides (**Affects Both Sides**), aim at allies, aim at the fallen (revives), or be **Placed In Reach** (aimed twice: who, then where).

**What a skill does** is its damage, plus a list of **effects**:

| Effect | What it does |
|---|---|
| **Damage, Heal, Damage over time** | Hurts, mends, or hurts at each of the target's turn starts. |
| **Stat Modifier, Stat Multiplier** | Adds to or multiplies a stat for some turns. |
| **Condition** | Puts on a named condition. |
| **Dispel** | Strips stat changes and damage over time. |
| **Push, Pull** | Shoves away or drags closer. |
| **Reveal** (Study) | Opens the enemy's full sheet. |
| **Movement Class** | Makes the target fly or walk for some turns. |
| **Hide** | Takes the target out of sight. |
| **Resistance** | Raises or lowers a resistance. |
| **Upgrade Element** | The next damaging skill is cast in the upgraded element. |
| **Revive** | Brings back a fallen ally weaker, until a long rest. |
| **Steal** | Empties one container. |
| **Summon Decoy** | Makes an image of an ally. |
| **Interact** | Uses a thing on the map. |
| **Hack** | Cancels a declared move through a minigame. |
| **Read Intent** | Alithia's Intuition. |
| **Shake** | Shakes an enemy's nerve. |
| **Climb** | Climbs onto something huge. |
| **Bribe** | Pays an enemy out of the fight. |
| **Break Free** | Escapes a grip. |
| **Invisible** | Unseen even in plain view. |
| **Cancel Casting** | InstaHack. |
| **Swallow** | The boss's Devour. |
| **Grow** | One size bigger. |
| **Summon, Command** | Calls a summon; gives it its move and action. |
| **Loot** | Takes from a fallen enemy. |
| **Draw** (Rummage) | Pouch to baldric. |
| **Trap** | Sets a hidden trap. |
| **Catalyst** | Sets off lingering conditions at once. |
| **Zone** | Leaves a lasting area on the ground. |
| **Dispel Magic** | Ends what spells did. |

**Kinds of move:**

- **Reactions** go off as their user's one reaction between turns, when something happens:
  - somebody leaves their reach, or enters it;
  - they are targeted or struck;
  - an ally is attacked;
  - somebody casts a spell, or declares a move;
  - a foreseen blow comes.
  
  **Reaction Only** moves (InstaHack) can't be used on one's own turn.
- **Ready** holds a move back:
  - It spends the main action now, and any gate.
  - It fires as the reaction the first time its trigger happens, or when somebody steps into a marked 4-tile area.
  - It is lost at the user's next turn.
  - Enemies ready too, each in its own way: covering the approach, guarding a post, countering casters, or waiting for the hidden.
- **Declared moves** are called on one turn and land at the start of the user's next.
  - Calling one is free. The tiles it will hit are marked, and anybody still on them when it lands is hit.
  - Enemies use these (Ground Pound, Rockfall).
  - Prometheus can Hack a declared move that is marked **Hackable**. Won, it comes to nothing and a boss is staggered.
- **Throws** (Hurl): picks up somebody beside you, up to a size bigger, and throws them. Throwing them into somebody hurts both.
- **Teleports:** the caster or the target, sometimes landing in cover.
- **Tethers:** a spell held on the caster's tether (summons, the dragon).
  - The tether frays each turn and with every hurt the caster takes.
  - When it snaps, the spell ends. Only one tethered spell is held at a time.
- **Quick time events:** a button press against the clock can make the party's own move land harder, or an enemy's land softer.

## 7. Conditions

A **condition** is a resource with switches. Durations count down on the holder's own turns, ending either as their turn starts or as it ends.

**What the switches do:**

- **Turns and movement:** loses the turn (stun); damage over time of a type and strength; movement up or down; can't move; can't advance on enemies; blown a few tiles each turn.
- **Actions:** accuracy up or down; no secondary action; no reactions; skill range capped.
- **Damage taken:** more or less damage taken; mends a share of health each turn; **More From Source** (Exposed: more damage from whoever put it on); **Less From Afar**.
- **Protection and illusion:** **Evades Next Hit** (Phantom Body); **Miss Chance** (Blurred); **Casts Freely**; **Makes Invisible** (Reflected).
- **Holds:** the condition holds them in place (Grappled, Snared).

**Examples:** Burn, Poisoned, Frozen, Crystallised, Windswept, Corroded, Stunned, Blind, Fear, Confused, Deceived, Grappled, Snared, Exposed, Scented, Swallowed, Bile-Soaked, Staggered, Surprised, Sanctified, Mirage, Reflected, Accused, Recanted and Grand Design. Part 3 lists them all.

- **Confused:** the AI plays the victim's turn at whoever is nearest, friend or foe.
- **Deceived:** their next turn is turned on the nearest of their own side.

**Immunities** are per creature: listed conditions, and categories such as being shoved, stolen from, weakened, lingering wounds, studied, movement changed, or boons dispelled.

## 8. Sight, cover, hiding, invisibility, images and illusions

**Sight and cover:**

- Line of sight runs on the grid. Walls and bodies block it.
- A body blocks the view of anybody up to one size bigger than itself.
- High ground and size let you see over low things.
- **Cover** is standing beside something that blocks sight.

**Hiding (Stealth):**

- You can only slip out of sight, and you stay hidden until somebody sees you again. This is checked on every step.
- Enemies simply don't know a hidden character is there.

**Invisibility:**

- Unseen even in plain view.
- Being seen or caught in a blast doesn't end it. Doing anything to an enemy does (Study excepted).
- **The side rule:** one of a side must always be left in sight. When nobody else of a side is visible, everybody hiding on it is revealed.

**Images** (Mirror Image, Phantom Body, Reality's Reflection):

- An image is a 1-health copy of an ally.
- Enemies believe it while they decide what to do. They target it, and treat it as a body that blocks shots and gives cover.
- What actually happens follows what is really there: it stops no shot and shields nobody from a blast.
- An image counts as "somebody in sight". So while one of the party's images stands, and its maker does, every one of the party can be hidden or invisible at once.
- The last image breaking reveals its maker, while the rest stay hidden. Its maker falling reveals everybody.
- This works the same when enemies use images.

**Illusory Cover** is an illusion of a barricade:

- It fades after three of Alithia's turns.
- It blocks sight and gives cover only in the other side's mind. Real shots and blasts pass straight through, and the AI doesn't know that.

## 9. Zones, traps, Catalyst and Dispel Magic

**Zones** are lasting areas on the ground, left by a spell's area for a number of its caster's turns.

- Whoever of the chosen side stands in a zone has its condition: stepping in puts it on, stepping out takes it off.
- Zones are tinted gold for the party's and red for the other side's.
- An **unseen** zone is not shown to the other side.
- A zone outlasts its caster: once they are down, its turns count by the round.
- The zones so far:
  - **Sanctuary of Light**: Sanctified, for allies.
  - **Mass Mirage**: radius 3, 1 turn.
  - **Reality's Reflection**: a decoy, plus an unseen zone that makes everybody of the party in it invisible (Reflected).

**Traps** belong to the Trapper (Snare, Tripwire, Minefield).

- They go on bare ground, are seen only by the party, and are drawn in bronze.
- The first enemy to step on one is held fast (Snared) and stops there. A Tripwire also bursts.

**Catalyst** is Cyrus's at level 64, once a fight. The rule, exactly (APPROVED_DESIGN, 2026-10-24; not to change without an approved trial):

- **Scope:** every living enemy, not only the one it is aimed at. On each, only the lingering conditions (ones that deal damage over time) whose source is Cyrus.
- **Damage:** each such condition goes off as one hit: one tick's damage × the ticks it has left × 2 (Catalyst Times).
  - One tick's damage is the condition's stored power through that enemy's current Defense, rounded, at least 1.
  - The product is rounded, then resisted once by that condition's own damage type.
  - Each condition is its own hit, so an enemy with Burn and Poison takes two.
  - A condition with no ticks left deals nothing.
- **Restart:** each restarts at the full length it landed with, its turns plus DoT Master's.
- **Untouched:** other sources' conditions, conditions that don't linger, and bare damage-over-time wounds.
- **Intentional:** Catalyst is Cyrus's personal condition payoff, so only conditions he inflicted count. Team-wide condition synergy may be added later through a separate mechanic, but is not to be folded into Catalyst.
- **No hit bonuses** apply: the burn's power was set when it landed.

**Dispel Magic** belongs to Prometheus (Gates of Pandora, from level 14).

- It ends what spells left: on a combatant, their conditions, changes and invisibility.
- It also ends anything a spell called up or made (a summon such as the Kindled Hound, an image, Illusory Cover), and a spell's zone when aimed at its bare ground.
- It reaches only what came through its own gate or a shallower one. A Yaldabaoth spell needs Dispel Magic cast through Yaldabaoth.

## 10. Summons, things on the map, the arena

**Summons** (Kindled Hound, Illusory Dragon, the Summoner's Bound Beast):

- A summon has no turn of its own. Its summoner's secondary action **Command** gives it its move and one action.
- Left un-commanded, it guards (Defense doubled).
- It fends for itself under the AI when its summoner loses a turn.
- It goes when its summoner goes.

**Things on the map** (bells, powder kegs, carrion, illusory cover):

- They take no turns and block like a body.
- The party can **Use** them, and breakable ones can be hit.
- Setting one off can blast an area, add a condition, or stagger a boss.

**Arena hazards:**

- **Falling** hazards are marked a round ahead, then come down.
- **Ground** hazards hurt whoever starts a turn on them.
- A hazard can stagger a boss caught in it.

## 11. Size, height, grappling

**Sizes:** Tiny, Small, Human, Large (2×2), Enormous (4×4), Monstrous (8×8), Gigantic (16×16+).

- Small and Tiny share tiles with their own side.
- Big ones occupy, are hit on, and reach from their whole square.
- Monstrous and bigger ignore walls and cover.
- A melee blow grows with its user's size: one tile becomes a cone, then longer rows.
- **Growth** makes an ally a size bigger for 3 turns.

**Heights:** high ground and stacked floors.

- High ground and floors are reached by climb tiles, and one sees over low things from up there.
- Lines of sight pass between floors only through open air.

**Grappling and climbing:**

- **Grab** (contest Physical vs Physical) holds a target in place.
  - The holder can drag the held one.
  - **Break Free** is a roll: 20-80% depending on Physical.
- **Hurl** throws somebody.
- **Climb** gets Enfina onto something Monstrous or bigger. Up there:
  - nobody reaches her;
  - she is carried along;
  - every blow she lands hits 25% harder;
  - the monster spends turns trying to shake her off.

## 12. Enemies

**The AI:**

- Each enemy has an AI archetype: melee rush, ranger, caster, healer, alchemist, hit-and-explode, copycat (the Mimic), summoner, glutton (the boss Erysichthon).
- The planner tries every usable skill from every reachable tile. It scores each by the same predicted damage a player sees, times the chance to hit, with bonuses for:
  - a kill;
  - a new condition;
  - a hurt target;
  - focusing the target the last enemy went for.
- Hitting its own side is a heavy cost.

**Intuition** (Alithia, secondary action):

- It reads an enemy's next turn: where it will stand, what it will use, and where it will land. That turn is marked on the map.
- The enemy is held to it. Step off the marked tiles and its blow lands on nothing; block its path and it must think again.
- Paths add to a reading:
  - effects on the enemy read;
  - shields for the allies it aimed at;
  - bonus damage against an enemy whose future was changed.

**Nerve:**

- Fear, being hurt, a fallen leader, half its side down, or being the last left adds to an enemy's nerve damage.
- At its Nerve it **breaks**: it flees for an escape point, or surrenders.
- Fled enemies can be gone, come back later, or lose the party the fight (a messenger who must not get away).
- Fallen enemies are taken alive, to be questioned for clues and gold, then let go or handed over.

**Dealing with them:**

- **Talking:** Intimidate (Enfina), Persuade (Alithia) and Deceive (Cyrus) are contests. They need **leverage**: the enemy's faction known, one of its kind questioned, or a clue.
- **Bribe:** pay an enemy its price as a secondary action. A parley before a fight can also buy enemies out or onto your side.
- **Changing sides:** an enemy bought or rebound fights for the party for some turns.
- **Rebinding:** Prometheus can Hack the Bound Golem to his side.

**Bosses:**

- Boss traits are per creature, not tied to size.
- A boss has phases at health thresholds (new skills, AI, summons, hazards, music...).
- Its **stagger bar** fills from damage, hits, blocked stuns, particular skills, interrupting a declared move, or hazards.
  - Full, the boss loses a turn, its declared move is cancelled, and it takes more damage.
- Bosses can have body parts. Breaking one:
  - roots it (legs);
  - weakens its hits (arms);
  - exposes it to harder hits (armour);
  - staggers it (a weak point);
  - disarms skills.
- Some have more than one turn a round, and auras.
- The bosses so far: the Ash Warden, the Bellkeeper, and Erysichthon (an Enormous undead wolf that grabs, devours and digests people, and eats carrion and its own dead).

**No taunts:** nothing forces anybody's aim. Attention is held by placement, cover, conditions and holds.

- The Pit Champion makes tiles within 2 cost double movement (**Hemmed In**).
- Ending a turn within 2 of it without hurting it leaves you **Exposed** to it: +20% from it.

## 13. Gear, items and containers

- **Gear:** a weapon (its Weapon Base), armour (its Defense) and a charm (a passive).
- **Containers:**
  - The **Baldric** (4 or 6 slots) is what comes into a fight.
  - The pouch and the backpack hold the rest.
  - **Rummage** moves an item from the pouch to the baldric during a fight.
  - The Grenadier's Pack holds two bombs per slot.
- **Consumables:** cure potions (a share of health), Medicine, bombs (tiny/small/medium/big), condition bottles (burn, frost, gale, crystal, poison, shock, terror), blinding bomb, Gate Nades and spellbooks.
- **Prices** follow two design sheets, by tier (I = levels 1-16, II = 17-32, III = 33-48, IV = 49-64):
  - **Consumables:** about 50/120/240/480 for a single heal, 45/120/260/520 for a bomb, 60/150/300/600 for a scroll. Spellbooks cost 150/375/750/1500/2000 by gate depth.
  - **Gear:** a weapon 50/150/300/600, armour 60/180/320/640, a charm 40/120/260/520.
  - **Selling:** a store buys back at half.
  - **Fight pay:** a won fight pays like a contract: 30-50 gold in tier I, 150-300 in II, 300-600 in III, 800-1200 in IV.
  - **Not in the game yet:** whole-mission payouts (500-1000 in tier I up to 8000-12000 in IV), cheaper resale for junk and rare artifacts, and services (inns, horses, healers, Gate Nade crafting).

---

# Part 2 - The progression plan (docs/progression_plan.md)

How each row of the designer's progression sheet became a skill, rank or passive in the game, and the paths' moves with their numbers.



How each row of the CSV goes into the game. Decisions from 2026-10-22: subclasses as
in the CSV (chosen at 24, its names); keep every skill the CSV does not list; the
CSV's levels win, except the existing Holy Lance, which stays - the CSV's "Holy
Lance (Pen 25%)" is a new spell under another name; the CSV's numbers stand; no
cooldowns; Cat Burglar and Cover Runner combined; no Glass Cannon; "Double Strike"
is Follow Up Attack; and a row that is only a stronger version of a move
(Basic Strike -> Heavy Swing) is that move growing stronger, not a second move.

### Ranks

A move growing stronger is a **rank** on it (`SkillDefinition.ranks`,
`SkillRank`): from the rank's level its multiplier, its condition's damage dial
and its condition's duration stand in for the skill's own. The Levels page says
so at that level.

### Enfina

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

### Cyrus

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

### Prometheus

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

### Alithia

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

### New mechanics this needs

- Damage reduction: passives (Iron Hide, Agile in cover, Radiant Guardian) and conditions (Bulwark's and Aura's, Mercy III's).
- On a turn not moved (Momentum).
- Lingering damage harder and longer (DoT Master).
- Against a target carrying a harmful condition (Synergy, Contest Insight II); weak to the element, or taking lingering damage (Elemental Affinity).
- A bonus to the stat in contests (Contest Insight).
- More castings through the deepest gate (Reserved Power, Elemental Mastery).
- Heals that lift a condition, or leave a ward (Mercy II, III); heals worth a share of health (Restoration, Grace); healing on the turn's start (Aura II).
- Cover: standing beside something that blocks sight. Cat Burglar I, Agile I and II, Cover Leap.
- A skill only for somebody at half health or less (Finisher) - removed with it on 2026-10-25.

### Instead of Glass Cannon: Kindling

**Kindling I-III** (1, 16, 54; picked 2026-10-23): every spell he casts in a fight
makes the ones after it 5% hotter, up to 15 / 30 / 45%. Cantrips take no gate,
so they neither stoke it nor are stoked. Turned down: Stoked Fire (a flat 10 / 20
/ 30%) and First Spark (more on anybody at full health).

### Cooldowns

Only three rows mention one:
- **Finisher** ("long CD"): an execute instead - usable only on somebody at half health or less (removed 2026-10-25). Other ways: it takes both actions, or it lands a turn later (declared, as Earthsplitter was).
- **Elemental Mastery** ("extra slot or reduced cooldown") and **Reserved Power II** ("extra high-tier slot or CD reduction"): the extra slot.

### Subclasses - the moves (built 2026-10-23)

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

### Taunts

No taunts: aggro comes from placement, cover, debuffs and holds like Grab. What taunted:
- The Pit Champion's **Challenge** (an aura: anybody of the party starting a turn within two tiles may only hurt the champion). Replaced (2026-10-23) by **Hemmed In** and **Exposed**, both built; the taunt mechanic is gone from the game.
- The CSV's Taunting Shout - built as Battle Cry, a cone that shoves. Kept as the shove.

Ways to keep the effect without forcing a target:
- **Punish** (for Challenge): a reaction - anybody within two tiles who hurts somebody else is struck by the champion. Staying near it is the price of ignoring it.
- **Hemmed In** (for Challenge): tiles within two of it cost twice the movement for the party - hard to get past, easy to fight.
- **Exposed** (for Challenge): anybody within two tiles who does not hit it takes a fifth more from it until their next turn.
- For Battle Cry: the shove it does now; or Rattled - those hit lose their secondary action next turn; or Pinned - two less movement for a turn, so they cannot reach the back line.

### What changed for skills that were already in the game

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

### Open (2026-10-23)

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

---

# Part 3 - Everything in the game, from its data files

Generated from the game's resource files (data/). Every value here is PRESENT: what the game uses today - open design variables unless a sheet set them. `x1.5` is an ability modifier: damage = (weapon base + 0.7 x stat) x modifier x 40/(40 + defence). Only settings that differ from the default are listed under 'settings'.

## The party

### Alithia (`alithia`)

- Main stat Mindfulness, secondary Self; spells scale from Mindfulness
- Health: 75 at level 1, 90 at 24, 115 at 64; movement 6; initiative 7
- Gates: level 1 World 2; level 24 World 4, Hermes 3, Pandora 3, Charon 2; level 64 World 4, Hermes 3, Pandora 3, Charon 3, Tartarus 3, Nemesis 2, Sophia 2, Ogdoad 1, Gnosis 1, Yaldabaoth 1
- Paths (chosen at 24): Battle Chaplain, Illusory Shepherd, Inquisitor
- Skills and spells, by the level they come at:
  - 1: Votive Flame, Water Spike, Sass Club, Heal, Cleanse, Intuition, Persuade, Slip Past, Run
  - 3: Light Heal
  - 5: Holy Lance
  - 6: Flash
  - 7: Dread Visage
  - 8: River Flow, Holy Splash
  - 9: Resuscitate, Bewilder
  - 16: Frozen River, Communion
  - 24: Piercing Light
  - 32: Judgment
  - 41: Glacial Tide, Purification
  - 54: Divine Verdict, Restoration
  - 64: Revelation, Grace
- Passives:
  - **Mercy I** (Always active): Her heals mend a tenth more. [Heals mend 10% more.]
  - **Aura I** (Always active, from level 8): Allies within two tiles of her are blessed: a tenth less damage. [Aura: their own side within 2 tiles are blessed.]
  - **Mercy II** (Always active, from level 16): Her heals mend a tenth more, and lift one harmful condition as well. [Heals lift one harmful condition too.]
  - **Aura II** (Always active, from level 24): Allies within two tiles of her are blessed and soothed: a tenth less damage, and a twentieth of their health back as each turn starts. [Aura: their own side within 2 tiles are soothed.]
  - **Reserved Power I** (Always active, from level 32): One more casting through the deepest gate open to her. [1 more casting through the deepest gate open to them.]
  - **Mercy III** (Always active, from level 41): Her heals mend a tenth more and lift one harmful condition, and whoever she heals is sheltered: a fifth less damage until their next turn starts. [Whoever they heal is sheltered.]
  - **Reserved Power II** (Always active, from level 54): Two more castings through the deepest gate open to her. [1 more casting through the deepest gate open to them.]
  - **Radiant Guardian** (Always active, from level 64): While she stands, the party takes a tenth less damage. [While they stand, their side takes 10% less damage.]
  - **Devotion** (Always active): Two castings of her own, for Heal or for Dread Visage on one person, spent before any gate. One comes back at a short rest, both at a long rest. [2 castings of their own for Heal or Dread Visage, in place of a gate - 1 back at a short rest, all at a long rest.]
- Other settings: glossary_text: "A prideful and arrogant cleric with several capabilities of protecting her allies.  Narrative:  One of the most talented Idol Users of the Holy Order, she always kept the Divine close to her heart as It has guided her many times.  And yet the way people see her are very mixed, for many feel uncomfortable with how much she questions even the smallest thing instead of showing silent obedience. Throughout her studies and career she has infuriated a lot of clerics and yet has also helped the souls of many followers. Due to her debates, the clergy find themselves in an unspoken split between those who consider her blasphemous and those whose faith only became stronger with her masterful questioning.  Gameplay: Even though she's really important for the party to not be worn out from the duration of combat, she is durable enough to survive hits herself. Prioritise keeping her in range of everyone!  She is also capable of weakening enemies to mitigate their offensive capabilities."; class_t: Magic; max_hp: 75; max_hp_level_20: 115; defense_by_level: { 1: 12, 8: 20, 17: 28 }

### Cyrus (`cyrus`)

- Main stat Self, secondary Physical; spells scale from Intellect
- Health: 75 at level 1, 90 at 24, 115 at 64; movement 6; initiative 8
- Gates: level 1 none; level 24 none; level 64 none
- Paths (chosen at 24): Skirmisher, Saboteur, Trapper
- Skills and spells, by the level they come at:
  - 1: Rapier, Blink Strike, Gun, Steal, Deceive, Stealth, Slip Past, Run, Cover Leap
  - 8: Poison Dart
  - 16: Burning Shot
  - 24: Venom Fan
  - 32: Warning Shot
  - 41: Exposing Shot
  - 64: Catalyst
- Passives:
  - **Light Footed** (Always active): Stealth, Slip Past and Run can be used as his secondary action as well as his main one - so he can Run twice in a turn, or slip away after striking. [Can use Stealth, Slip Past and Run as a secondary action as well as a main one.]
  - **Quick Hands** (Always active): Items can be used as his secondary action as well as his main one, and he reaches for the secondary first - so he can drink a potion and still attack in the same turn. [Can use items as a secondary action as well as a main one.]
  - **Nade Juggler** (Always active): Throws any Gate Nade, whatever spell is in it - everybody else only those whose spell they know or could learn - and throws them with his secondary action, where the spell would take the main one. [Can throw Gate Nades as a secondary action as well as a main one. Can throw any Gate Nade, whatever spell is in it.]
  - **Cat Burglar II** (Always active, from level 24): Two more tiles of movement, four on a turn he starts in cover - and nothing stops him going up: he climbs onto high ground from anywhere, no ladder or steps needed, and up a wall or a pillar onto the floor above it. [+2 movement. Climbs onto high ground from anywhere, and up a wall or pillar to the floor above it.]
  - **Cat Burglar I** (Always active): Quick between hiding places: two more tiles of movement on a turn he starts in cover. [+2 movement on a turn they start in cover.]
  - **Agile I** (Always active, from level 8): Hard to pin down in cover: a twentieth less damage there. [Takes 5% less damage in cover.]
  - **DoT Master I** (Always active, from level 16): His poisons and burns bite deeper: a tenth harder. [Their lingering damage is 10% harder.]
  - **Agile II** (Always active, from level 32): Hard to pin down in cover - a twentieth less damage there - and into cover before anybody can strike: stepping into cover sets nothing off. [Stepping into cover sets off nothing.]
  - **DoT Master II** (Always active, from level 41): His poisons and burns bite deeper still: three tenths harder, and a turn longer. [Their lingering damage is 20% harder. Their lingering damage lasts 1 turn longer.]
  - **Synergy I** (Always active, from level 54): He shows the party where it hurts: they hit anybody carrying a harmful condition a tenth harder. [Their side hits anybody carrying a harmful condition 10% harder.]
  - **Synergy II** (Always active, from level 64): He shows the party where it hurts: they hit anybody carrying a harmful condition a tenth harder, and a fifth harder if it is one of his. [And 10% harder again on anybody carrying one of theirs.]
  - **Elusive** (Always active): He can Slip Past as a secondary action as well as a main one. [Can use Slip Past as a secondary action as well as a main one.]
- Other settings: glossary_text: "A swift cunning cat with a bunch of tricks up his sleeves to hide from enemies and hunt down his targets.  Narrative: An unfortunate circumstance which resulted in his mother's passing and him running away from home, has caused him to be stranded and struggling to survive since his teenage years. These harsh circumstances have forced him to develop the skills and greed of a thief.  And yet, despite the cruelty of reality, he still keeps on to his red scarf. The scarf that reminds him of the oath he swore to himself of becoming a hero.  These childish ambitions have lead him into a secret group, which has the intention to steal and weaken those who grow too strong.  Gameplay: By having high initiative and movement, he gets to decide how a combat begins and where he is needed to go. He is capable of reaching even the most hidden enemy and hunt them down until they're no more. This makes him the only member who can get away from the team to take care of potent but frail targets, such as casters!  He also has the special capability of using consumables as a secondary action, making him the most adaptable member in the team."; class_t: Ranged; max_hp: 75; max_hp_level_20: 115; defense_by_level: { 1: 12, 8: 20, 17: 28 }

### Enfina (`enfina`)

- Main stat Physical, secondary Intellect; spells scale from Intellect
- Health: 130 at level 1, 152 at 24, 190 at 64; movement 6; initiative 6
- Gates: level 1 none; level 24 none; level 64 none
- Paths (chosen at 24): Vanguard, Juggernaut, Warden of Cover
- Skills and spells, by the level they come at:
  - 1: Study, Greatsword Attack, Fire Burst, Light Swing, Shoving Strike, Blink Strike, Guard, Slip Past, Run, Intimidate, Hurl, Grab, Climb
  - 4: Trailblaze
  - 16: Battle Cry
  - 24: Armor Shred
  - 32: Follow Up Attack
  - 41: Stunning Blow
  - 54: Sweep Strike
- Passives:
  - **Measured Eye** (Always active): Every blow she lands teaches her something. Whoever she hits is studied, just as Study would - their sheet open to the party, and her next blows landing with a studier's edge. [Every hit studies whoever it lands on, as Study does.]
  - **Iron Hide I** (Always active): Hide hardened by every blow she has taken: a tenth less damage from anything. [Takes 10% less damage.]
  - **Bulwark I** (Always active, from level 8): Allies beside her are bulwarked: a tenth less damage. [Aura: their own side within 1 tiles are bulwarked.]
  - **Iron Hide II** (Always active, from level 16): Harder again: a fifth less damage from anything. [Takes 10% less damage.]
  - **Momentum I** (Always active, from level 32): Planted, she hits harder: a tenth more damage on a turn she has not walked - every blow, Sweep Strike's whole sweep too. [10% more damage on a turn they have not walked.]
  - **Iron Hide III** (Always active, from level 41): Hide hardened to a fifth less damage from anything - and she steps into blows meant for others: half of any hit on an ally beside her is hers instead. [Takes 50% of any hit on an ally within 1 tiles.]
  - **Bulwark III** (Always active, from level 54): Allies beside her are bulwarked, and her guard reaches two tiles: allies within them are fortified - a tenth less damage, a fifth beside her. [Aura: their own side within 2 tiles are fortified.]
  - **Momentum II** (Always active, from level 64): Planted, every blow lands like a falling wall: fifteen hundredths more damage on a turn she has not walked - Sweep Strike's whole sweep too. [5% more damage on a turn they have not walked.]
- Other settings: glossary_text: "A city guard who has trained and studied to perfectly respond to any combat situation.  Narrative: Not born in favourable circumstances, she was faced with a lot of disadvantages. Unable to be trusted to become a knight of the Holy Order, too useful to just leave her out of the picture, yet still faced with uncertainty. An uncertainty that she also sees in herself and how cut out she truly is for the path she chose.   And yet, she still raises her sword. She still trains unrelentlessly, to perform as well as possible, even if no one has any intention of recognising and rewarding her for it with a higher rank.  But Enfina's intentions are pure. For she does not raise her sword for herself. She raises it for everyone else.  Gameplay: Capable of dealing the most damage and take the most hit, she is an invaluable piece that allows her to fend off the mightiest of foe.   Her foes fear her reactive skill, so staying close to one will either force them to stay in place, or move and be damaged.  As a frontliner, she controls where the fight takes place. Make sure she is always in front of your allies and at the part of the map where you want the fight to take place."; max_hp: 130; max_hp_level_20: 190; defense_by_level: { 1: 12, 8: 20, 17: 28 }; keeps_codex: true

### Prometheus (`prometheus`)

- Main stat Intellect, secondary Mindfulness; spells scale from Intellect
- Health: 30 at level 1, 40 at 24, 58 at 64; movement 6; initiative 5
- Gates: level 1 World 2; level 24 World 4, Hermes 3, Pandora 3, Charon 2; level 64 World 4, Hermes 3, Pandora 3, Charon 3, Tartarus 3, Nemesis 2, Sophia 2, Ogdoad 1, Gnosis 1, Yaldabaoth 1
- Paths (chosen at 24): Elemental Vanguard, Elemental Tactician, Elemental Conductor
- Skills and spells, by the level they come at:
  - 1: Fire Burst, Zephyr Dart, Caucasus Shard, Study, Hack, Fire Blast, Wind Shot, Rock Throw, Quicken, Hover, Slip Past, Invisibility, Run
  - 5: Wind Vacuum
  - 7: Hermes Step
  - 8: Burner, Wind Swoon, Growth, Mist Step
  - 9: Fireball
  - 14: InstaHack, Dispel Magic, Kindled Hound
  - 16: Wildfire, Crystalise
  - 24: Gust Blast
  - 32: Tartarus Flame
  - 41: Ire of Sophia
  - 47: Illusory Dragon
  - 54: Gnostic Tempest
  - 64: Stolen Sun
- Passives:
  - **Prying Mind** (Always active): He can hack: wards and seals, machines and locks, and the spell a foe is winding up. The sharper his Intellect, the more tries he gets, and the less each retry costs him. [Can hack wards, machines and the spells others are winding up - more tries, and cheaper ones, the higher their Intellect.]
  - **Elemental Affinity I** (Always active, from level 8): He knows what each element undoes: a tenth more damage on anybody weak to the element. [10% more damage on anybody weak to the hit's element.]
  - **Contest Insight I** (Always active, from level 24): He reads a contest before it starts: +10 to his stat in one. [+10 to their stat in a stat contest.]
  - **Elemental Affinity II** (Always active, from level 32): He knows what each element undoes: a tenth more damage on anybody weak to the element, and a tenth more on anybody already burning, frozen, poisoned - taking any lingering damage. [10% more damage on anybody taking lingering damage.]
  - **Contest Insight II** (Always active, from level 41): He reads a contest before it starts: +10 to his stat in one, +20 against anybody already afflicted. [+10 more in a contest with anybody carrying a harmful condition.]
  - **Elemental Mastery** (Always active, from level 64): One more casting through the deepest gate open to him. [1 more casting through the deepest gate open to them.]
  - **Kindling I** (Always active): Every spell he casts in a fight stokes the next: each one after it burns 5% hotter, up to 15%. [Each spell they cast in a fight makes the ones after it 5% harder, up to 15%.]
  - **Kindling II** (Always active, from level 16): Every spell he casts in a fight stokes the next: each one after it burns 5% hotter, up to 30%. [Kindling builds up to 15% further.]
  - **Kindling III** (Always active, from level 54): Every spell he casts in a fight stokes the next: each one after it burns 5% hotter, up to 45%. [Kindling builds up to 15% further.]
  - **Meditate** (Always active): At a short rest, once until the next long rest, he brings back castings he has spent: a point to spend every six levels, each casting costing its gate's depth, and none deeper than the shallower half of his open gates. [Meditates at a short rest, once until the next long rest: brings back spent castings, a point every six levels, each costing its gate's depth.]
- Other settings: glossary_text: "A messy pragmatic scholar who can never be seen without a book and a drink.  Narrative: He was an up and rising star in Idology from his late teen years. This lead him to quickly get into high and important research. However... It is now a painful memory that only destroys him further and further as time passes.  Despite it all, or perhaps because of it all, he is now a really warm and caring person that, despite not saying it out loud, would always be there for you.  Gameplay: The hardest unit to use well, he has the most potent capabilities in the party. Yet they are limited by resource and his frail frame makes him easy to be killed in but an instant. It is more important for him to stay alive, rather than cast spells earlier! Make sure to properly utilise cover!  He also can provide with utility, such as weakening enemies or teleporting allies. To make the most of him is to make the most of all!"; class_t: Magic; max_hp: 30; max_hp_level_20: 58; defense_by_level: { 1: 12, 8: 20, 17: 28 }; learns_spells: true; starting_spells: ["fire_blast", "wind_shot", "rock_throw", "quicken"]; keeps_codex: true

## The paths (subclasses, chosen at level 24)

### Battle Chaplain (`battle_chaplain`)

Holy weapons. Alithia takes the fight to them with spear, sweep and hammer of light - and what she deals, her friends are mended by.

- Skill, level 24: **Holy Spear** (see its entry under Skills)
- Skill, level 32: **Censure** (see its entry under Skills)
- Skill, level 41: **Judgement Hammer** (see its entry under Skills)
- Passive, Always active, from level 54: **Righteous** - Her damaging spells heal the most hurt of her side within two tiles of her for a fifth of the damage they did. [Their damaging spells heal the most hurt ally within 2 for 20% of the damage.]
- Passive, Always active, from level 64: **Crusade** - Allies within two tiles of her hit 15% harder. [Allies within 2 of them hit 15% harder.]

### Elemental Conductor (`elemental_conductor`)

The overcharge. Prometheus pushes every spell past where it should stop: through deeper gates, from one enemy to the next, and once, twice over.

- Passive, Always active, from level 24: **Overcharge** - Amplify a spell by casting it through a deeper gate - half as much damage again for each gate deeper. Once a short rest he can do it without spending the deeper gate. [Can amplify a spell, casting it through a higher gate for 50% more damage a gate. Amplifies for free once a short rest from level 24.]
- Passive, Always active, from level 32: **Chain** - His fire and lightning spells leap from whoever they hit to one more of the other side within two tiles, at half the damage. [Their fire/lightning spells leap to one more within 2, at 50%.]
- Passive, Always active, from level 41: **Resonance** - A spell of another element than his last one hits 15% harder. [A spell of another element than their last hits 15% harder.]
- Passive, Always active, from level 54: **Deep Current** - One more Overcharge a short rest that spends no deeper gate - two in all. [Amplifies for free once a short rest from level 54.]
- Passive, Always active, from level 64: **Conduit** - Once a short rest, a spell through the deepest gate open to him comes through twice. [Once a short rest, a spell through their deepest gate is cast twice.]

### Elemental Tactician (`elemental_tactician`)

The ward. Prometheus shapes the fight rather than ending it: shielding his friends, holding his enemies where he wants them - and, once, opening every gate at once.

- Skill, level 64: **Grand Design** (see its entry under Skills)
- Passive, Always active, from level 24: **Ward** - Reaction: when an ally within five tiles - or Prometheus himself - is about to be hit, take four tenths off it. [Reaction: when an ally within 5 tiles is hit, takes 40% off it.]
- Passive, Always active, from level 32: **Bulwark Weave** - A spell of his landing on an ally leaves them overhealed: extra health, taken first, gone by the end of the fight. [A spell on an ally leaves them overhealed - extra health, taken first, gone by the fight's end.]
- Passive, Always active, from level 41: **Battlefield Control** - His roots and slows last a turn longer, and his shoves go a tile further. [Their roots and slows last 1 turn longer. Their shoves go 1 tile further.]
- Passive, Always active, from level 54: **Shared Ward** - He can Ward twice a round. [Can Ward 2 times a round.]

### Elemental Vanguard (`elemental_vanguard`)

The blade. Prometheus closes in, quick on his feet, and fights with swords of fire, ice, storm and stone - each blow a spell.

- Skill, level 32: **Flame Edge** (see its entry under Skills)
- Skill, level 32: **Frost Edge** (see its entry under Skills)
- Skill, level 32: **Storm Edge** (see its entry under Skills)
- Skill, level 32: **Stone Edge** (see its entry under Skills)
- Passive, Always active, from level 24: **Fleet Blade** - Light on his feet: two more tiles of movement - and he can Slip Past as a secondary action as well as a main one. [Can use Slip Past as a secondary action as well as a main one. +2 movement.]
- Passive, Always active, from level 41: **Spellstrike** - An Edge that lands strikes again with its element - his cantrip of it, x0.7 - and costs nothing more. [Flame Edge, Frost Edge, Storm Edge and Stone Edge that lands strikes again with its element, x0.7, free.]
- Passive, Always active, from level 54: **Elemental Armour** - Wrapped in what he last struck with: a fifth less of that element. [Takes 20% less of the element they last used.]
- Passive, Always active, from level 64: **Avatar** - His Edges hit half as hard again. [Flame Edge hits 50% harder. Frost Edge hits 50% harder. Stone Edge hits 50% harder. Storm Edge hits 50% harder.]

### Illusory Shepherd (`illusory_shepherd`)

Protective illusions. Alithia makes cover where there is none, lays phantoms over her friends and fills the field with false targets - and her heals leave a veil behind.

- Skill, level 24: **Illusory Cover** (see its entry under Skills)
- Skill, level 32: **Phantom Body** (see its entry under Skills)
- Skill, level 41: **Sanctuary of Light** (see its entry under Skills)
- Skill, level 54: **Mass Mirage** (see its entry under Skills)
- Skill, level 64: **Reality's Reflection** (see its entry under Skills)
- Passive, Always active, from level 24: **Veil of Mercy I** - Whoever she heals is veiled: the next blow on them lands 15% softer. [Whoever they heal is veiled.]
- Passive, Always active, from level 32: **Veil of Mercy II** - Whoever she heals is veiled - the next blow on them lands 15% softer - and blurred: a fifth less from anything thrown or shot from more than a tile away, until their next turn. [Whoever they heal is blurred.]
- Passive, Always active, from level 41: **Guiding Phantasm** - An image goes ahead of whoever she heals, showing them the way: two more tiles of movement until the end of their next turn. [Whoever they heal moves 2 tiles further until the end of their next turn.]
- Passive, Always active, from level 54: **Veil of Mercy III** - Whoever she heals is veiled and blurred, and her heals leave a shield of light too: a fifth of their health on top of it, for two of their turns. [Their heals leave a shield of 20% of health for 2 turns.]
- Passive, Always active, from level 64: **Illusory Guardian** - While she stands, the first blow each of her side takes in a fight finds only an illusion of them, and misses. [While they stand, each ally's first blow taken in a fight misses.]

### Inquisitor (`inquisitor`)

Reading them. Alithia sees what they will do, says so before everybody - and passes sentence on it, or simply forbids it.

- Skill, level 32: **Accusation** (see its entry under Skills)
- Skill, level 54: **Recant** (see its entry under Skills)
- Passive, Always active, from level 24: **Inquest** - Reading somebody's next turn studies them too, the way Study does: what they are weak to, and what they are made of. [Reading an enemy's next turn also does something to them: Reveal.]
- Passive, Always active, from level 41: **Sentence** - Her hits land a quarter harder on anybody whose next turn she has read. [Their hits land 25% harder on anybody they have read.]
- Passive, Always active, from level 64: **Final Judgment** - Her Judgment goes through all defence, not half, on anybody whose next turn she has read. [Judgment goes through all defence on anybody they have read.]

### Juggernaut (`juggernaut`)

The immovable. Enfina drags them in, cuts their legs from under them and pins them where they stand - and nothing moves her.

- Skill, level 24: **Chain Hook** (see its entry under Skills)
- Skill, level 32: **Hamstring** (see its entry under Skills)
- Skill, level 41: **Pin Down** (see its entry under Skills)
- Passive, Always active, from level 54: **Immovable** - A tenth less from every hit, and nothing shoves or pulls her anywhere. [Takes 10% less damage. Immune to being shoved.]
- Passive, Always active, from level 64: **Tremor** - Every hit of hers also hits everybody beside whoever it lands on for half, and shoves them all a tile - into something solid, they are dazed. Then she steps a tile after whoever she hit, free. [Their hits also hit everybody beside the target for 50%, shoving them all a tile - into something solid, dazed. After such a hit, they step a tile after whoever they hit, free.]

### Saboteur (`saboteur`)

The ammunition. Cyrus loads rounds that chill and corrode, fires two at once, sets off what is already burning in them - and lets it spread.

- Skill, level 24: **Frost Round** (see its entry under Skills)
- Skill, level 32: **Corrosive Round** (see its entry under Skills)
- Skill, level 41: **Combined Load** (see its entry under Skills)
- Passive, Always active, from level 54: **Overload** - A Gun hit of his - any load - makes each of his lingering conditions on the target tick once more, there and then. [A Gun hit makes each of their lingering conditions on the target tick once more, at once.]
- Passive, Always active, from level 64: **Contagion** - As each of their turns starts, whatever he put on somebody spreads to everybody of their side beside them - as strong, and as long, as it began. [Their conditions spread to everybody beside whoever has them, as each of their turns starts.]

### Skirmisher (`skirmisher`)

The rapier. Cyrus strikes first, from the flank, and is gone before it can be answered - and is never quite where the blow lands.

- Passive, Always active, from level 24: **Riposte Step** - After a Rapier strike lands, Cyrus can step up to two tiles away in a straight line - in whichever direction he likes - and nothing can react to it. [After Rapier, can step up to 2 tiles away in a straight line, provoking nothing.]
- Passive, Always active, from level 32: **Flanker** - His Rapier lands a quarter harder on anybody standing beside one of his allies. [Rapier lands 25% harder on anybody standing beside one of their allies.]
- Passive, Always active, from level 41: **Ambush Strike** - His first hit on each enemy in a fight - with anything - deals double. [Their first hit on each enemy in a fight lands 100% harder.]
- Passive, Always active, from level 54: **Afterimage** - While he is in cover, the first attack at him each round strikes an afterimage and misses. [In cover, the first attack at them each round misses.]
- Passive, Always active, from level 64: **Thousand Cuts** - The Rapier is his secondary action as well as a main one, and each Rapier strike after the first in a turn lands a quarter harder. [Can use Rapier as a secondary action as well as a main one. Each Rapier after the first in a turn lands 25% harder.]

### Trapper (`trapper`)

Bombs and traps. Cyrus never fights a fight that is not already rigged: a bomb in hand, the ground set under them, and whoever walks into it held there.

- Skill, level 32: **Snare** (see its entry under Skills)
- Skill, level 41: **Tripwire** (see its entry under Skills)
- Skill, level 64: **Minefield** (see its entry under Skills)
- Passive, Always active, from level 24: **Bombardier's Kit** - A Small Bomb to hand, free, once a short rest - on top of whatever is in his bag. And Steal reaches three tiles further. [Steal reaches +3 tiles. Has a Small Bomb to hand, free, once a short rest.]
- Passive, Always active, from level 54: **Field of Traps** - Two traps set at once, and setting one - Snare or Tripwire - is a secondary action as well as a main one. [Can use Snare and Tripwire as a secondary action as well as a main one. 1 more trap set at once.]
- Passive, Always active, from level 64: **Grand Snare** - Anybody held fast by one of his traps takes a quarter more from him. [Anybody held by their traps takes 25% more from them.]

### Vanguard (`vanguard`)

The charge. Enfina burns, runs at them and does not stop: harder after a charge, through everything that would hold her, and on from one fallen to the next.

- Skill, level 41: **Daunting Roar** (see its entry under Skills)
- Passive, Always active, from level 24: **Adrenaline** - While she is burning, her hits deal three tenths more damage, and set whoever they land on burning too. [While Burn: 30% more damage, and every hit spreads it.]
- Passive, Always active, from level 32: **Leading Charge** - After walking three tiles or more in a turn, her next hit that turn lands a fifth harder - Momentum's other half: stand, or charge. [Having walked 3 tiles or more in a turn, their next hit lands 20% harder.]
- Passive, Always active, from level 54: **Unstoppable** - Nothing slows her, roots her or holds her: her movement is never less than her own, and nobody can get a grip on her. [Cannot be grappled. Nothing lowers their movement or roots them.]
- Passive, Always active, from level 64: **Rampage** - Felling somebody on her own turn gives her main action back, and three more tiles of movement - one after another, while they keep falling. [Felling somebody on their turn gives their main action back and 3 more movement.]

### Warden of Cover (`warden_of_cover`)

The protector. Enfina stands between her friends and harm - frightening it back, guarding them as she guards herself, and taking what gets through.

- Skill, level 24: **Shield Bash** (see its entry under Skills)
- Passive, Always active, from level 32: **Covering Stance** - Her Guard covers the allies beside her too. [Their Guard covers allies within 1 too.]
- Passive, Always active, from level 41: **Hold the Line** - Allies inside her Bulwark cannot be shoved or pulled. [Allies inside their aura cannot be shoved or pulled.]
- Passive, Always active, from level 54: **Interceptor** - Half of any hit on an ally within two tiles of her is taken by her instead - Iron Hide III, further. [Takes 50% of any hit on an ally within 2 tiles.]
- Passive, Always active, from level 64: **Last Wall** - While she stands, no blow fells an ally within two tiles of her: it stops at one point of health, and the rest of it lands on her. [While they stand, a blow cannot fell an ally within 2: it stops at 1 health, and the rest lands on them.]

## Skills and spells

Sorted the way the game's folders sort them: common to the party, each character's own, their spells, their paths', the enemies', and unused. A spell is anything cast through a gate.

### Folder: alithia

- **Intuition** (`intuition`) - level 1; secondary action; range 1-8; ranged; single target; no damage
  - Who has it: Alithia
  - Says: Read what an enemy means to do with their next turn: where they will stand, what they will use, and where it will land - all marked on the map. They are held to it, so step out of the marked tiles and the blow finds nothing.
  - Effect: {type: Read Intent}
  - Settings: can_be_copied: false
- **Persuade** (`persuade`) - level 1; main action; range 1-4; ranged; single target; no damage; contested against Self
  - Who has it: Alithia
  - Says: Use what the party knows about them to talk them into standing down: they lose their next turn, unless somebody hurts them first. Only works on somebody the party has something on - their faction known, one of their kind questioned, a clue about them. Her Mindfulness against their Self.
  - Effect: {type: Condition; condition: Hesitating (hesitating); condition_duration: 1}
  - Settings: can_be_copied: false; needs_leverage: true
- **Sass Club** (`sass_club`) - level 1; main action; reacts: an enemy leaves its reach; range 0-1; melee; single target; damage x1.5 Physical, scales with Self
  - Who has it: Alithia, The Bellkeeper, Imp, Rat
  - Says: What's worse than getting clobberred by a staff is also hearing a painful remark.
- **Votive Flame** (`votive_flame`) - level 1; main action; range 2-20; ranged; single target; damage x0.7 Idol, scales with Mindfulness
  - Who has it: Alithia
  - Says: Shoot them with the offering of the idol.
  - Settings: respects_blocking: true
- **Water Spike** (`water_spike`) - level 1; main action; range 2-20; ranged; single target; damage x0.7 Water, scales with Mindfulness
  - Who has it: Alithia, Priest, Summoner
  - Says: A streak of water used as projectile.
  - Settings: respects_blocking: true

### Folder: alithia/paths/battle_chaplain

- **Censure** (`censure`) - level 32; spell, Gates of Tartarus; main action; range 1-4; ranged; area: Cone 3; damage x2.4 Idol
  - Who has it: Battle Chaplain path
  - Says: A wide sweep of judgement, spreading from her hands.
- **Holy Spear** (`holy_spear`) - level 24; spell, Gates of Pandora; main action; range 1-6; ranged; area: Line 6; damage x1.6 Idol
  - Who has it: Battle Chaplain path
  - Says: A spear of Idol light thrown straight through a line of them.
- **Judgement Hammer** (`judgement_hammer`) - level 41; spell, Gates of Nemesis; main action; range 1-8; ranged; area: Diamond 1; damage x3.0 Idol
  - Who has it: Battle Chaplain path
  - Says: A hammer of light brought down on a crowd, throwing them back.
  - Effect: {type: Push}
  - Settings: respects_blocking: true

### Folder: alithia/paths/illusory_shepherd

- **Illusory Cover** (`illusory_cover`) - level 24; spell, Gates of Pandora; main action; range 1-6; ranged; single target; no damage
  - Who has it: Illusory Shepherd path
  - Says: Cover that is not there, on a bare tile within six, for three of her turns. The other side takes it for a real barricade - it blocks their sight, whoever stands beside it is in cover to them, and they plan around it - but shots and blasts go straight through it, and they never learn it.
  - Effect: {type: Summon; summons: "illusory_cover"}
  - Settings: can_be_copied: false
- **Mass Mirage** (`mass_mirage`) - level 54; spell, Gates of Ogdoad; main action; range 0-6; ranged; area: Diamond 3; aimed at allies; no damage
  - Who has it: Illusory Shepherd path
  - Says: A mirage on the ground, three tiles round where she puts it within six, until her next turn: her side standing in it takes a quarter less from every blow, and one attack in four at them misses outright.
  - Effect: {type: Zone; zone_condition: Mirage (mirage); zone_turns: 1}
  - Settings: can_be_copied: false
- **Phantom Body** (`phantom_body`) - level 32; spell, Gates of Charon; main action; range 0-6; ranged; single target; aimed at allies; no damage
  - Who has it: Illusory Shepherd path
  - Says: An image laid over an ally within six: the next attack that would hit them strikes it instead, and misses. It lasts three of their turns, or one blow.
  - Effect: {type: Condition; condition: Phantom Body (phantom_body)}
  - Settings: can_be_copied: false
- **Reality's Reflection** (`realitys_reflection`) - level 64; spell, Gates of Yaldabaoth; main action; range 0-8; ranged; area: Diamond 3; aimed at allies; no damage
  - Who has it: Illusory Shepherd path
  - Says: A reflection of the world on the ground, three tiles round where she puts it within eight, for two of her turns - and the other side never knows it is there. Her side standing in it is invisible, and an image of each of them caught as she casts it stands beside them for the other side to go for. Acting against an enemy gives one away until their next turn.
  - Effect: {type: Summon Decoy}
  - Effect: {type: Zone; zone_condition: Reflected (reflected); zone_unseen: true}
  - Settings: can_be_copied: false
- **Sanctuary of Light** (`sanctuary_of_light`) - level 41; spell, Gates of Nemesis; main action; range 0-6; ranged; area: Diamond 2; aimed at allies; no damage
  - Who has it: Illusory Shepherd path
  - Says: A sanctuary on the ground, two tiles round where she puts it within six, for two of her turns: her side standing in it takes 15% less from every blow, and one attack in four at them strikes a copy and misses.
  - Effect: {type: Zone; zone_condition: Sanctified (sanctified)}
  - Settings: can_be_copied: false

### Folder: alithia/paths/inquisitor

- **Accusation** (`accusation`) - level 32; spell, Gates of Charon; main action; range 0-15; ranged; single target; damage x1.5 Idol
  - Who has it: Inquisitor path
  - Says: Spoken at somebody whose next turn she has read: x1.5, and until their next turn they take 15% more from everybody.
  - Effect: {type: Condition; condition: Accused (accused)}
  - Settings: respects_blocking: true; needs_read: true
- **Recant** (`recant`) - level 54; secondary action; range 0-15; ranged; single target; no damage
  - Who has it: Inquisitor path
  - Says: Once a short rest, as a secondary action, on somebody whose next turn she has read: it does not happen. They lose it.
  - Effect: {type: Condition; condition: Recanted (recanted)}
  - Settings: can_be_copied: false; needs_read: true; uses_per_short_rest: 1

### Folder: alithia/spells

- **Bewilder** (`bewilder`) - level 9; spell, Gates of Hermes; main action; range 1-6; ranged; single target; no damage; contested against Self
  - Who has it: Alithia
  - Says: Twists what the target sees until friend and foe are one. Confused, they go for whoever is nearest.
  - Effect: {type: Condition; condition: Confused (confused); condition_duration: 1}
- **Cleanse** (`cleanse`) - level 1; spell, Gates of World; secondary action; range 0-10; ranged; single target; aimed at allies; no damage
  - Who has it: Alithia, Priest
  - Says: Removes debuff effects from an ally.
  - Effect: {type: Dispel; dispel_scope: Debuffs Only}
- **Communion** (`communion`) - level 16; spell, Gates of Pandora; main action; range 0-10; ranged; area: Diamond 2; aimed at allies; no damage; heals 8 + 0.15 x the healer's healing stat + 0.2 x weapon base (no defence, no randomness; the effect's min and max amount are unused)
  - Who has it: Alithia, Priest
  - Says: The idol's mercy on everyone near where it lands: every ally there is healed.
  - Effect: {type: Heal; heal_flat: 8.0; heal_per_stat: 0.15; heal_per_weapon: 0.2}
- **Divine Verdict** (`divine_verdict`) - level 54; spell, Gates of Gnosis; main action; range 1-15; ranged; area: Diamond 1; damage x4.2 Idol; ignores 50% defence
  - Who has it: Alithia
  - Says: Judgment from on high on everything near where it lands: half their defence counts for nothing.
  - Settings: respects_blocking: true
- **Dread Visage** (`dread_visage`) - level 7; spell, Gates of Hermes; main action; range 1-6; ranged; single target; no damage; contested against Self
  - Who has it: Alithia
  - Says: A face only the target sees, and cannot stop seeing.
  - Effect: {type: Condition; condition: Fear (fear); condition_duration: 2}
- **Flash** (`flash`) - level 6; spell, Gates of Hermes; main action; range 1-15; ranged; area: Diamond 2; no damage; contested against Mindfulness
  - Who has it: Alithia
  - Says: A burst of light enough to blind anyone.
  - Effect: {type: Condition; condition: Blind (blind); condition_duration: 5}
  - Settings: respects_blocking: true
- **Frozen River** (`frozen_river`) - level 16; spell, Gates of Pandora; main action; range 1-15; ranged; area: Diamond 2; damage x1.8 Water; contested against Intellect
  - Who has it: Alithia
  - Says: A whole river of it, freezing as it comes down on them.
  - Effect: {type: Condition; condition: Frozen (frozen); condition_duration: 5; condition_dot_modifier: 0.3}
  - Settings: respects_blocking: true
- **Glacial Tide** (`glacial_tide`) - level 41; spell, Gates of Sophia; main action; range 1-15; ranged; area: Diamond 3; damage x2.2 Water
  - Who has it: Alithia
  - Says: A wave of freezing water over everything near where it lands: frozen for two turns.
  - Effect: {type: Condition; condition: Frozen (frozen); condition_duration: 2; condition_dot_modifier: 0.25}
  - Settings: respects_blocking: true
- **Grace** (`grace`) - level 64; spell, Gates of Yaldabaoth; main action; range 0-10; ranged; area: Diamond 3; aimed at allies; no damage; heals (weapon base + 0.7 x the caster's spellcasting stat) x 0.7 + 100% of the target's max health (no defence, no randomness; the effect's min and max amount are unused)
  - Who has it: Alithia
  - Says: Every ally near where it lands, back to full health.
  - Effect: {type: Heal; heal_share_of_health: 1.0}
- **Heal** (`heal`) - level 1; spell, Gates of World; main action; range 0-5; ranged; single target; aimed at allies; no damage; heals 12 + 0.25 x the healer's healing stat + 0.3 x weapon base (no defence, no randomness; the effect's min and max amount are unused)
  - Who has it: Alithia, Priest, Ranger
  - Says: Recover one's vitality.
  - Effect: {type: Heal; heal_flat: 12.0; heal_per_stat: 0.25; heal_per_weapon: 0.3; min_amount: 4; max_amount: 8}
- **Holy Lance** (`holy_lance`) - level 5; spell, Gates of Hermes; main action; range 1-10; ranged; area: Line 10 wide 3; damage x1.2 Idol; contested against Self
  - Who has it: Alithia
  - Says: Blast a line of pure Idol energy.
- **Holy Splash** (`holy_splash`) - level 8; spell, Gates of Hermes; main action; range 1-15; ranged; area: Diamond 1; damage x1.1 Idol
  - Who has it: Alithia
  - Says: A splash of the idol's light over a small area.
  - Settings: respects_blocking: true
- **Judgment** (`judgment`) - level 32; spell, Gates of Tartarus; main action; range 1-15; ranged; single target; damage x3.4 Idol; ignores 50% defence
  - Who has it: Alithia
  - Says: The idol's verdict on one enemy: half their defence counts for nothing.
  - Settings: respects_blocking: true
- **Light Heal** (`light_heal`) - level 3; spell, Gates of World; secondary action; range 0-5; ranged; single target; aimed at allies; no damage; heals 8 + 0.15 x the healer's healing stat + 0.2 x weapon base (no defence, no randomness; the effect's min and max amount are unused)
  - Who has it: Alithia
  - Says: Swiftly recover one's vitality.
  - Effect: {type: Heal; heal_flat: 8.0; heal_per_stat: 0.15; heal_per_weapon: 0.2; min_amount: 3; max_amount: 6}
- **Piercing Light** (`piercing_light`) - level 24; spell, Gates of Charon; main action; range 1-15; ranged; single target; damage x2.2 Idol; ignores 25% defence
  - Who has it: Alithia
  - Says: A spear of light that finds the gaps in armour: a quarter of their defence counts for nothing.
  - Settings: respects_blocking: true
- **Purification** (`purification`) - level 41; spell, Gates of Nemesis; main action; range 0-5; ranged; single target; aimed at allies; no damage; heals (weapon base + 0.7 x the caster's spellcasting stat) x 0.7 (no defence, no randomness; the effect's min and max amount are unused)
  - Who has it: Alithia
  - Says: Mends an ally and lifts every harmful condition from them.
  - Effect: {type: Heal}
  - Effect: {type: Dispel; dispel_scope: Debuffs Only}
- **Restoration** (`restoration`) - level 54; spell, Gates of Ogdoad; main action; range 0-5; ranged; single target; aimed at allies; no damage; heals 0.25 x the healer's healing stat + 50% of the target's max health (no defence, no randomness; the effect's min and max amount are unused)
  - Who has it: Alithia
  - Says: Half of an ally's health back, and more besides.
  - Effect: {type: Heal; heal_share_of_health: 0.5; heal_per_stat: 0.25}
- **Resuscitate** (`resuscitate`) - level 9; spell, Gates of Pandora; main action; range 1-1; melee; single target; aimed at allies; no damage
  - Who has it: Alithia
  - Says: Bring a fallen ally back into the fight with half their health. It costs them: everything about them but how far they can walk is a tenth less afterwards - until a long rest, and a tenth less again each time.
  - Effect: {type: Revive; revive_health: 0.5; revive_weakening: 0.1}
  - Settings: targets_fallen: true; can_be_copied: false
- **Revelation** (`revelation`) - level 64; spell, Gates of Yaldabaoth; main action; range 1-15; ranged; area: Diamond 1; damage x5.0 Idol; ignores 75% defence
  - Who has it: Alithia
  - Says: The truth unhidden, burning through everything near where it lands: three quarters of their defence count for nothing.
  - Settings: respects_blocking: true
- **River Flow** (`river_flow`) - level 8; spell, Gates of Hermes; main action; range 1-15; ranged; single target; damage x1.4 Water; contested against Intellect
  - Who has it: Alithia, Priest
  - Says: Control water to freeze the target.
  - Effect: {type: Condition; condition: Frozen (frozen); condition_duration: 5; condition_dot_modifier: 0.2}
  - Settings: respects_blocking: true

### Folder: common

- **Blink Strike** (`blink_strike`) - level 1; main action; range 0-4; melee; area: Diamond 1; damage x0.8 Physical, scales with Physical
  - Who has it: Cyrus, Enfina
  - Says: Arrive on a tile within reach and cut down everything standing beside it, all at once.
  - Settings: teleports: Caster
- **Break Free** (`break_free`) - level 1; main action; range 1-1; melee; single target; no damage
  - Says: Struggle against whoever is holding you. Half the time against somebody as strong as you, more the stronger you are than them and less the weaker - never under one in five or over four in five. Only while Grappled.
  - Effect: {type: Break Free}
  - Settings: can_be_copied: false
- **Bribe** (`bribe`) - level 1; secondary action; range 1-6; ranged; single target; no damage
  - Says: Pay somebody who fights for money their price, from the party's purse, and they walk away from the fight. Hover them to see what they want.
  - Effect: {type: Bribe}
  - Settings: can_be_copied: false
- **Climb Down** (`climb_down`) - level 1; secondary action; range 1-3; melee; single target; no damage
  - Says: Jump down off whatever you climbed, onto free ground nearby.
  - Settings: can_be_copied: false; teleports: Caster
- **Command** (`command`) - level 1; secondary action; range 0-99; ranged; single target; aimed at allies; no damage
  - Says: Give a summon of yours its moment: it moves and acts now, and then the turn is yours again. A summon not commanded stands on guard as your turn ends.
  - Effect: {type: Command}
  - Settings: can_be_copied: false
- **Fire Burst** (`fire_burst`) - level 1; main action; range 1-20; ranged; single target; damage x0.7 Fire, scales with Intellect
  - Who has it: Enfina, Prometheus, The Bellkeeper, Imp, Sorcerer
  - Says: A weak outburst of flames.
  - Settings: respects_blocking: true
- **Loot** (`loot`) - level 1; secondary action; range 0-1; melee; single target; no damage
  - Says: Go through a fallen enemy beside you, or under your feet: everything they carried goes in your bag, and whatever they wore into the party's stash. What you leave, you can still search for once the fight is won.
  - Effect: {type: Loot}
  - Settings: can_be_copied: false
- **Rummage** (`rummage`) - level 1; main action; range 0-0; ranged; single target; aimed at allies; no damage
  - Says: Take one thing out of your pouch and put it on your baldric, ready to use. Handling an item: a main action, or a secondary one for whoever uses items with it.
  - Effect: {type: Draw}
  - Settings: can_be_copied: false
- **Run** (`run`) - level 1; main action; range 0-0; melee; single target; aimed at allies; no damage
  - Who has it: Alithia, Cyrus, Enfina, Prometheus, Alchemist, Barbarian, Bomber, Bound Beast, Hired Bow, Kindled Hound, Pit Champion, Priest, Ranger, Sellsword, Sorcerer, Summoner
  - Says: Doubles your movement for this turn only.
  - Effect: {type: Stat Multiplier; display_name: "Haste"; duration: 1; wears_off_at_start: true}
  - Settings: can_be_copied: false
- **Slip Past** (`slip_past`) - level 1; main action; range 0-0; melee; single target; aimed at allies; no damage
  - Who has it: Alithia, Cyrus, Enfina, Prometheus
  - Says: Move as though nobody were watching. Nothing can react to you for the rest of this turn.
  - Settings: suppresses_reactions: true; can_be_copied: false
- **Study** (`study`) - level 1; secondary action; range 1-40; melee; single target; no damage
  - Who has it: Enfina, Prometheus
  - Says: Take the measure of an enemy: their health, attributes, movement, what they resist, what they are weak to, and everything they can do. Read it all on the character sheet, under C. What is learned lasts the battle.
  - Effect: {type: Reveal}
  - Settings: can_be_copied: false
- **Use** (`use`) - level 1; main action; range 1-1; melee; single target; no damage
  - Says: Use something on the battlefield beside you: ring the bell, pull the lever, cut the rope. What it does is the thing's own - hover it to read.
  - Effect: {type: Interact}
  - Settings: can_be_copied: false

### Folder: cyrus

- **Burning Shot** (`burning_shot`) - level 16; main action; range 2-15; ranged; single target; damage x0.8 Physical, scales with Self
  - Who has it: Cyrus
  - Says: Special ammunition that helps them feel the heat.
  - Effect: {type: Condition; condition: Burn (burn); condition_duration: 3; condition_dot_modifier: 0.35}
  - Rank from level 32 "Strong Burn": ability_modifier: 0.95; condition_dot_modifier: 0.45
  - Settings: respects_blocking: true; is_ammo: true
- **Catalyst** (`catalyst`) - level 64; main action; range 0-0; ranged; single target; aimed at allies; no damage
  - Who has it: Cyrus
  - Says: Once a short rest: every lingering condition of his, on every enemy, goes off at once, for twice what it had left - and then starts again, as long as it ever lasted.
  - Effect: {type: Catalyst}
  - Settings: can_be_copied: false; uses_per_short_rest: 1
- **Cover Leap** (`cover_leap`) - level 1; secondary action; range 1-3; ranged; single target; no damage
  - Who has it: Cyrus
  - Says: A quick dash of up to three tiles into cover - beside a wall, a crate, anything that blocks sight. Nothing can react to it. A secondary action.
  - Settings: teleports: Caster; lands_in_cover: true
- **Deceive** (`deceive`) - level 1; main action; range 1-4; ranged; single target; no damage; contested against Intellect
  - Who has it: Cyrus
  - Says: Use what the party knows about them to convince them one of their own has sold them out: their next turn goes on the nearest of their own side. Only works on somebody the party has something on - their faction known, one of their kind questioned, a clue about them. His Self against their Intellect.
  - Effect: {type: Condition; condition: Deceived (deceived); condition_duration: 1}
  - Settings: can_be_copied: false; needs_leverage: true
- **Exposing Shot** (`exposing_shot`) - level 41; main action; range 2-20; ranged; single target; damage x0.7 Physical, scales with Self
  - Who has it: Cyrus
  - Says: A shot at the joints of their armour: a quarter less defence for two turns.
  - Effect: {type: Stat Multiplier; stat: "defense"; stat_multiplier: 0.75}
  - Settings: respects_blocking: true
- **Gun** (`gun`) - level 1; main action; range 2-20; ranged; single target; damage x1.0 Physical, scales with Self
  - Who has it: Cyrus
  - Says: Cyrus uses gun.
  - Settings: respects_blocking: true
- **Poison Dart** (`poison_dart`) - level 8; main action; range 2-20; ranged; single target; damage x0.9 Physical, scales with Self
  - Who has it: Cyrus
  - Says: A dart coated in a toxin that poisons the target.
  - Effect: {type: Condition; condition: Poisoned (poisoned); condition_duration: 3; condition_dot_modifier: 0.2}
  - Settings: respects_blocking: true; is_ammo: true
- **Rapier** (`rapier`) - level 1; main action; reacts: an enemy leaves its reach; range 0-1; melee; single target; damage x1.5 Physical, scales with Self
  - Who has it: Cyrus, Alchemist, Priest
  - Says: One feign, another feign, strike your enemy with swiftness and cunning.
  - Settings: respects_blocking: true
- **Steal** (`steal`) - level 1; main action; range 1-1; melee; single target; no damage
  - Who has it: Cyrus
  - Says: Lift everything an enemy has to hand - their potions, bombs and bottles - and keep it. Whatever fits in your first four slots can be used straight away; the rest goes in your bag.
  - Effect: {type: Steal}
  - Settings: respects_blocking: true; can_be_copied: false
- **Stealth** (`stealth`) - level 1; main action; range 0-0; ranged; single target; aimed at allies; no damage
  - Who has it: Cyrus
  - Says: Slip out of sight. Only possible while no enemy can see you, and it lasts until one of them can again - at which point whoever spotted you stops where they stand.
  - Effect: {type: Hide}
- **Venom Fan** (`venom_fan`) - level 24; main action; range 1-3; ranged; area: Cone 3; damage x0.7 Physical, scales with Self
  - Who has it: Cyrus
  - Says: A fan of poisoned darts across everybody in front of him: poisoned for three turns.
  - Effect: {type: Condition; condition: Poisoned (poisoned); condition_duration: 3; condition_dot_modifier: 0.2}
  - Settings: respects_blocking: true
- **Warning Shot** (`warning_shot`) - level 32; main action; range 1-20; ranged; single target; damage x0.9 Physical, scales with Self
  - Who has it: Cyrus
  - Says: A shot that should slow their advances.
  - Effect: {type: Stat Modifier}
  - Settings: respects_blocking: true

### Folder: cyrus/paths/saboteur

- **Combined Load** (`combined_load`) - level 41; main action; range 2-15; ranged; single target; damage x1.0 Physical, scales with Self
  - Who has it: Saboteur path
  - Says: Two loads at once: pick two of your ammunition, and fire them as one shot.
  - Settings: respects_blocking: true; can_be_copied: false; combines_ammo: true
- **Corrosive Round** (`corrosive_round`) - level 32; main action; range 2-15; ranged; single target; damage x0.8 Acid, scales with Self
  - Who has it: Saboteur path
  - Says: A round that eats at whatever it hits: it burns on for five turns, and their armour is a tenth worse while it does.
  - Effect: {type: Condition; condition: Corroded (corroded); condition_duration: 5; condition_dot_modifier: 0.25}
  - Settings: respects_blocking: true; is_ammo: true
- **Frost Round** (`frost_round`) - level 24; main action; range 2-15; ranged; single target; damage x0.9 Ice, scales with Self
  - Who has it: Saboteur path
  - Says: A round packed with rime. It bites, and the cold slows whoever it hits.
  - Effect: {type: Stat Modifier; display_name: "Chilled"; modifier_amount: -2; duration: 1}
  - Settings: respects_blocking: true; is_ammo: true

### Folder: cyrus/paths/trapper

- **Minefield** (`minefield`) - level 64; main action; range 1-6; ranged; single target; no damage
  - Who has it: Trapper path
  - Says: Once a short rest: a Tripwire on every free tile within two of where it is thrown, on top of whatever traps are already set.
  - Effect: {type: Trap; trap_holds_with: Snared (snared); trap_burst_modifier: 1.2; trap_burst_radius: 1; trap_field_radius: 2}
  - Settings: can_be_copied: false; uses_per_short_rest: 1
- **Snare** (`snare`) - level 32; main action; range 1-3; ranged; single target; no damage
  - Who has it: Trapper path
  - Says: A hidden snare on bare ground within three tiles: the first of the other side to step on it is caught fast, and cannot walk on, for a turn. One set at a time - setting another takes the first one's place.
  - Effect: {type: Trap; trap_holds_with: Snared (snared)}
  - Settings: can_be_copied: false
- **Tripwire** (`tripwire`) - level 41; main action; range 1-3; ranged; single target; no damage
  - Who has it: Trapper path
  - Says: As Snare, and it bursts as it is sprung: x1.2 to everybody of the other side within a tile of it.
  - Effect: {type: Trap; trap_holds_with: Snared (snared); trap_burst_modifier: 1.2; trap_burst_radius: 1}
  - Settings: can_be_copied: false

### Folder: enemies

- **Acid Breath** (`acid_breath`) - level 1; main action; range 1-6; ranged; area: Cone 6; damage x1.6 Acid, scales with Intellect; contested against Intellect
  - Who has it: Illusory Dragon
  - Says: It spits a sheet of acid, over everybody in a cone - half to whoever's mind sees through it. Made of its caster's mind: as strong as their Intellect.
  - Settings: affects_both_sides: true; can_be_copied: false
- **Call the Bound** (`call_the_bound`) - level 1; spell, Gates of World; main action; range 1-3; ranged; single target; no damage
  - Who has it: Summoner
  - Says: Calls a bound beast up on a tile in reach, to fight for its caller.
  - Effect: {type: Summon; summons: "bound_beast"}
  - Settings: can_be_copied: false
- **Catch the Scent** (`catch_the_scent`) - level 1; secondary action; range 1-12; ranged; single target; no damage
  - Who has it: Erysichthon
  - Says: It lifts its head and breathes them in. Next, it comes for them.
  - Effect: {type: Condition; condition: Scented (scented)}
  - Settings: can_be_copied: false
- **Devour** (`devour`) - level 1; main action; range 1-1; melee; single target; no damage
  - Who has it: Erysichthon
  - Says: Whoever it has hold of, it opens wide for - announced a turn ahead, landing next turn if they are still in its grip. Swallowed, they are digested in two of its turns unless its Belly Hole is torn open, it is staggered, or it falls.
  - Effect: {type: Swallow; condition: Swallowed (swallowed)}
  - Settings: can_be_copied: false; declared: true; hackable: true
- **Dread Breath** (`dread_breath`) - level 1; main action; range 1-6; ranged; area: Cone 6; damage x1.6 Psychic, scales with Intellect; contested against Intellect
  - Who has it: Illusory Dragon
  - Says: A wave of dread breaks from it, over everybody in a cone - half to whoever's mind sees through it. Made of its caster's mind: as strong as their Intellect.
  - Settings: affects_both_sides: true; can_be_copied: false
- **Empower the Bound** (`empower_the_bound`) - level 1; main action; range 0-6; ranged; single target; aimed at allies; no damage
  - Who has it: Summoner
  - Says: Floods an ally with strength: harder blows and a tougher hide, for two turns.
  - Effect: {type: Stat Multiplier; display_name: "Empowered"; stat: "physical"; stat_multiplier: 1.3}
  - Effect: {type: Stat Multiplier; display_name: "Hardened"; stat: "defense"; stat_multiplier: 1.3}
  - Settings: can_be_copied: false
- **Fire Breath** (`fire_breath`) - level 1; main action; range 1-6; ranged; area: Cone 6; damage x1.6 Fire, scales with Intellect; contested against Intellect
  - Who has it: Illusory Dragon
  - Says: Fire pours from its jaws, over everybody in a cone - half to whoever's mind sees through it. Made of its caster's mind: as strong as their Intellect.
  - Settings: affects_both_sides: true; can_be_copied: false
- **Flammable Limb** (`flammable_limb`) - level 14; main action; range 2-20; ranged; single target; damage x1.0 Physical, scales with Physical
  - Who has it: Ranger
  - Says: It throws an organ coated in flammable liquid that burns the target.
  - Effect: {type: Condition; condition: Burn (burn); condition_duration: 5; condition_dot_modifier: 0.5}
  - Settings: respects_blocking: true
- **Frost Breath** (`frost_breath`) - level 1; main action; range 1-6; ranged; area: Cone 6; damage x1.6 Ice, scales with Intellect; contested against Intellect
  - Who has it: Illusory Dragon
  - Says: A storm of frost rolls out of it, over everybody in a cone - half to whoever's mind sees through it. Made of its caster's mind: as strong as their Intellect.
  - Settings: affects_both_sides: true; can_be_copied: false
- **Ground Pound** (`ground_pound`) - level 1; main action; range 0-2; ranged; area: Diamond 1; damage x2.0 Physical, scales with Physical
  - Who has it: Ash Warden, Behemoth, Colossus, Ogre
  - Says: A fist raised high and brought down a turn later. Everything around where it lands is thrown off its feet.
  - Settings: respects_blocking: true; declared: true; quick_time_for: Defender
- **Kindled Bite** (`kindled_bite`) - level 1; main action; range 1-1; melee; single target; damage x1.1 Fire, scales with Physical
  - Who has it: Kindled Hound
  - Says: Burning teeth.
  - Settings: can_be_copied: false
- **Lightning Breath** (`lightning_breath`) - level 1; main action; range 1-6; ranged; area: Cone 6; damage x1.6 Lightning, scales with Intellect; contested against Intellect
  - Who has it: Illusory Dragon
  - Says: Lightning forks from its throat, over everybody in a cone - half to whoever's mind sees through it. Made of its caster's mind: as strong as their Intellect.
  - Settings: affects_both_sides: true; can_be_copied: false
- **Mend the Bound** (`mend_the_bound`) - level 1; main action; range 0-6; ranged; single target; aimed at allies; no damage; heals 12 + 0.25 x the healer's healing stat + 0.3 x weapon base (no defence, no randomness; the effect's min and max amount are unused)
  - Who has it: Summoner
  - Says: Knits an ally's wounds - the Summoner's own beast, most of all.
  - Effect: {type: Heal; heal_flat: 12.0; heal_per_stat: 0.25; heal_per_weapon: 0.3}
  - Settings: can_be_copied: false
- **Nail Projectile** (`nail_projectile`) - level 1; main action; range 2-20; ranged; single target; damage x1.35 Physical, scales with Physical
  - Who has it: Hired Bow, Ranger
  - Says: The monster fires off a long nail-like projectile.
  - Settings: respects_blocking: true
- **Ravenous Bite** (`ravenous_bite`) - level 1; main action; range 1-1; melee; single target; damage x1.2 Physical, scales with Physical
  - Who has it: Erysichthon, Gnawer
  - Says: Jaws that never close on enough - tearing at whoever is nearest.
  - Settings: can_be_copied: false
- **Rending Claws** (`rending_claws`) - level 1; main action; range 1-1; melee; single target; damage x0.8 Physical, scales with Physical
  - Who has it: Erysichthon
  - Says: Forepaws raking at whoever is beside it - what it falls back on with its jaws in pieces.
  - Settings: can_be_copied: false
- **Rib Maws** (`rib_maws`) - level 1; reaction; reacts: an enemy steps into its reach; range 1-1; melee; single target; damage x0.7 Physical, scales with Physical
  - Says: Its ribs have split into mouths along its flanks: whoever steps up beside it is bitten.
  - Settings: can_be_copied: false
- **Rockfall** (`rockfall`) - level 1; main action; range 2-8; ranged; area: Diamond 2; damage x1.6 Earth, scales with Physical
  - Who has it: Behemoth, The Bellkeeper, Colossus, Stone Golem
  - Says: Brings the roof down - the stones take a turn to fall, and land where they were called.
  - Settings: declared: true
- **Savage Bite** (`savage_bite`) - level 1; main action; range 1-1; melee; single target; damage x1.35 Physical, scales with Physical
  - Who has it: Bound Beast
  - Says: Teeth, and all its weight behind them.
  - Settings: can_be_copied: false
- **Self Destruct** (`self_destruct`) - level 1; main action; range 0-0; ranged; area: Diamond 3; damage x3.0 Plasma, scales with Mindfulness
  - Who has it: Bomber
  - Says: Detonates violently, damaging everyone nearby - and always kills the user.
  - Settings: kills_caster: true
- **Venom Breath** (`venom_breath`) - level 1; main action; range 1-6; ranged; area: Cone 6; damage x1.6 Poison, scales with Intellect; contested against Intellect
  - Who has it: Illusory Dragon
  - Says: A choking cloud spills from it, over everybody in a cone - half to whoever's mind sees through it. Made of its caster's mind: as strong as their Intellect.
  - Settings: affects_both_sides: true; can_be_copied: false
- **Venomous Shot** (`venomous_shot`) - level 1; main action; range 2-20; ranged; single target; damage x0.8 Physical, scales with Physical
  - Who has it: Hired Bow, Ranger
  - Says: A fang containing a highly dangerous poison.
  - Effect: {type: Condition; condition: Poisoned (poisoned); condition_duration: 5; condition_dot_modifier: 0.4}
  - Settings: respects_blocking: true

### Folder: enfina

- **Armor Shred** (`armor_shred`) - level 24; main action; range 1-1; melee; single target; damage x0.9 Physical, scales with Physical
  - Who has it: Enfina
  - Says: A tearing cut that opens up their armour: a fifth less defence for two turns.
  - Effect: {type: Stat Multiplier; stat: "defense"; stat_multiplier: 0.8}
- **Battle Cry** (`battle_cry`) - level 16; main action; range 1-2; melee; area: Cone 2; damage x0.6 Physical, scales with Physical
  - Who has it: Enfina
  - Says: A roar and a sweep at everybody in front of her that drives them back a tile - off whoever stands behind her.
  - Effect: {type: Push; damage_modifier: 0.0}
- **Climb** (`climb`) - level 1; main action; range 1-1; melee; single target; no damage
  - Who has it: Enfina
  - Says: Climb up onto something Monstrous or bigger and fight it from on top. Up there nobody can reach you, every blow on it lands - and harder - and it carries you wherever it goes. It will try to throw you off, and that hurts whether it works or not. Climb Down to jump off.
  - Effect: {type: Climb}
  - Settings: can_be_copied: false; needs_size_at_least: 5
- **Follow Up Attack** (`follow_up_attack`) - level 32; secondary action; range 1-1; melee; single target; damage x1.5 Physical, scales with Physical
  - Who has it: Enfina, Barbarian, Pit Champion
  - Says: Move the greatsword with such ease that your strikers are endless.
- **Grab** (`grab`) - level 1; main action; reacts: an enemy leaves its reach; range 1-1; melee; single target; no damage; contested against Physical
  - Who has it: Enfina, Barbarian, Erysichthon
  - Says: Take hold of somebody beside you - your size or smaller, or one size bigger at most - and keep them there: they cannot move until they spend their main action breaking free. Your Physical against theirs: it never misses anyone weaker than you, and anyone as strong or stronger twists out of it. Also a reaction: grab somebody as they leave your reach, and drag them back beside you.
  - Effect: {type: Condition; condition: Grappled (grappled)}
  - Settings: can_be_copied: false; lifts_sizes_above: 1
- **Greatsword Attack** (`greatsword_attack`) - level 1; main action; reacts: an enemy leaves its reach; range 1-1; melee; single target; damage x1.0 Physical, scales with Physical
  - Who has it: Enfina, Ash Warden, Barbarian, Behemoth, Stone Golem, Ogre, Pit Champion, Sellsword
  - Says: A strike trained to perfection.
  - Rank from level 8 "Heavy Swing": ability_modifier: 1.5
  - Rank from level 64 "Titanfall": ability_modifier: 3.0; splash_radius: 2; splash_modifier: 1.5
- **Guard** (`guard`) - level 1; main action; range 0-0; melee; single target; aimed at allies; no damage
  - Who has it: Enfina
  - Says: Stay on your guard.
  - Effect: {type: Stat Multiplier; stat: "defense"; duration: 1; wears_off_at_start: true}
- **Hurl** (`hurl`) - level 1; main action; range 1-1; melee; single target; damage x1.0 Physical, scales with Physical
  - Who has it: Enfina, Barbarian, Pit Champion, Sellsword
  - Says: Grab somebody beside you - your size or smaller, or one size bigger at most - and throw them. Throw them into somebody else and both are hurt. Further and harder the stronger you are.
  - Settings: can_be_copied: false; teleports: Target; throws: true; throw_range: 3; lifts_sizes_above: 1
- **Intimidate** (`intimidate`) - level 1; main action; range 1-3; melee; single target; no damage; contested against Self
  - Who has it: Enfina
  - Says: Use what the party knows about them to break their nerve: they are afraid, and nearer to running or giving up. Only works on somebody the party has something on - their faction known, one of their kind questioned, a clue about them. Her Physical against their Self.
  - Effect: {type: Shake; min_amount: 25; max_amount: 35}
  - Effect: {type: Condition; condition: Fear (fear); condition_duration: 2}
  - Settings: can_be_copied: false; needs_leverage: true
- **Light Swing** (`light_swing`) - level 1; main action; range 0-1; melee; single target; damage x1.0 Physical, scales with Physical; heals (weapon base + 0.7 x Physical) x 0.3, on its user (no defence, no randomness; the effect's min and max amount are unused)
  - Who has it: Enfina
  - Says: Preserve your energy to restore some vitality while still slashing at the enemy.
  - Effect: {type: Heal; heal_modifier: 0.3}
- **Shoving Strike** (`shoving_strike`) - level 1; main action; range 0-1; melee; single target; damage x1.0 Physical, scales with Physical
  - Who has it: Enfina
  - Says: Hit them with enough force to push them back.
  - Effect: {type: Push; min_amount: 3; max_amount: 6; knockback_distance: 3}
- **Stunning Blow** (`stunning_blow`) - level 41; main action; range 1-1; melee; single target; damage x0.8 Physical, scales with Physical
  - Who has it: Enfina
  - Says: A blow to the head: they lose their next turn. Once a short rest - twice from level 54, three times from 64.
  - Effect: {type: Condition; condition: Stunned (stunned); condition_duration: 1}
  - Settings: uses_per_short_rest: 1; more_uses_at: [54, 64]
- **Sweep Strike** (`sweep_strike`) - level 54; main action; range 0-2; melee; area: Line 2 wide 3; damage x1.4 Physical, scales with Physical
  - Who has it: Enfina, Barbarian
  - Says: Use swift movements and swing at all enemies in range.
  - Effect: {type: Push; damage_modifier: 0.0}
- **Trailblaze** (`trailblaze`) - level 4; secondary action; range 0-0; melee; single target; aimed at allies; no damage
  - Who has it: Enfina
  - Says: Blaze your way through.
  - Effect: {type: Condition; condition: Burn (burn); condition_duration: 5; condition_dot_modifier: 0.2}

### Folder: enfina/paths/juggernaut

- **Chain Hook** (`chain_hook`) - level 24; main action; range 2-5; melee; single target; damage x0.9 Physical, scales with Physical
  - Who has it: Juggernaut path
  - Says: A hooked chain thrown out to drag somebody to her.
  - Effect: {type: Pull; knockback_distance: 4}
  - Settings: respects_blocking: true
- **Hamstring** (`hamstring`) - level 32; main action; range 0-1; melee; single target; damage x1.0 Physical, scales with Physical
  - Who has it: Juggernaut path
  - Says: A cut low at the legs. They will not be going far for a while.
  - Effect: {type: Stat Modifier; display_name: "Hamstrung"; modifier_amount: -3}
  - Settings: respects_blocking: true
- **Pin Down** (`pin_down`) - level 41; main action; range 0-1; melee; single target; damage x1.0 Physical, scales with Physical
  - Who has it: Juggernaut path
  - Says: Pins them where they stand: they cannot walk at all on their next turn.
  - Effect: {type: Stat Multiplier; display_name: "Pinned"; stat_multiplier: 0.0; duration: 1}
  - Settings: respects_blocking: true

### Folder: enfina/paths/vanguard

- **Daunting Roar** (`daunting_roar`) - level 41; main action; range 1-2; melee; area: Cone 2; damage x0.6 Physical, scales with Physical
  - Who has it: Vanguard path
  - Says: A roar that hits those in front of her and stops them coming any closer: x0.6, and Fear for a turn.
  - Effect: {type: Condition; condition: Fear (fear); condition_duration: 1}

### Folder: enfina/paths/warden_of_cover

- **Shield Bash** (`shield_bash`) - level 24; main action; range 0-1; melee; single target; damage x0.9 Physical, scales with Physical
  - Who has it: Warden of Cover path
  - Says: A blow with the flat of the blade that leaves them afraid to press on.
  - Effect: {type: Condition; condition: Fear (fear); condition_duration: 2}
  - Settings: respects_blocking: true

### Folder: prometheus

- **Caucasus Shard** (`caucasus_shard`) - level 1; main action; range 2-20; ranged; single target; damage x0.7 Earth, scales with Intellect
  - Who has it: Prometheus
  - Says: Throw a rock at an enemy target.
  - Settings: respects_blocking: true
- **Hack** (`hack`) - level 1; main action; range 1-6; ranged; single target; no damage
  - Who has it: Prometheus
  - Says: Reach into the spell a foe is winding up - one that can be hacked - and pick it apart before it lands. A minigame: win it and the spell comes to nothing - and a boss reels; lose it and the spell may go off early.
  - Effect: {type: Hack}
  - Settings: can_be_copied: false
- **Zephyr Dart** (`zephyr_dart`) - level 1; main action; range 2-20; ranged; single target; damage x0.7 Wind, scales with Intellect
  - Who has it: Prometheus
  - Says: Throw a wind dart onto an enemy.
  - Settings: respects_blocking: true

### Folder: prometheus/paths/elemental_tactician

- **Grand Design** (`grand_design`) - level 64; secondary action; range 0-0; ranged; single target; aimed at allies; no damage
  - Who has it: Elemental Tactician path
  - Says: Once a short rest, as a secondary action: for this turn every gate stands open. His spells cost no gate, and the first he casts leaves his action for another.
  - Effect: {type: Condition; condition: Grand Design (grand_design)}
  - Settings: can_be_copied: false; uses_per_short_rest: 1

### Folder: prometheus/paths/elemental_vanguard

- **Flame Edge** (`flame_edge`) - level 32; spell, Gates of Pandora; main action; range 0-1; melee; single target; damage x1.8 Fire
  - Who has it: Elemental Vanguard path
  - Says: A blade of fire, swung close. It leaves the wound burning.
  - Effect: {type: Condition; condition: Burn (burn); condition_duration: 2}
  - Settings: respects_blocking: true
- **Frost Edge** (`frost_edge`) - level 32; spell, Gates of Pandora; main action; range 0-1; melee; single target; damage x1.8 Ice
  - Who has it: Elemental Vanguard path
  - Says: A blade of ice. Whoever it cuts is slow to follow.
  - Effect: {type: Stat Modifier; display_name: "Frostbitten"; modifier_amount: -2}
  - Settings: respects_blocking: true
- **Stone Edge** (`stone_edge`) - level 32; spell, Gates of Charon; main action; range 0-1; melee; single target; damage x2.2 Earth
  - Who has it: Elemental Vanguard path
  - Says: A blade of rock, heavy enough to crack armour.
  - Effect: {type: Stat Modifier; display_name: "Cracked Armour"; stat: "defense"; modifier_amount: -10}
  - Settings: respects_blocking: true
- **Storm Edge** (`storm_edge`) - level 32; spell, Gates of Charon; main action; range 0-1; melee; single target; damage x2.2 Lightning
  - Who has it: Elemental Vanguard path
  - Says: A blade of lightning that throws its target back.
  - Effect: {type: Push; knockback_distance: 2}
  - Settings: respects_blocking: true

### Folder: prometheus/spells

- **Burner** (`burner`) - level 8; spell, Gates of Hermes; main action; range 1-15; ranged; single target; damage x1.7 Fire; contested against Mindfulness
  - Who has it: Prometheus, Sorcerer
  - Says: Burn the target.
  - Effect: {type: Condition; condition: Burn (burn); condition_duration: 5; condition_dot_modifier: 0.25}
  - Settings: respects_blocking: true
- **Crystalise** (`crystalise`) - level 16; spell, Gates of Hermes; main action; range 0-15; ranged; single target; damage x1.0 Earth; contested against Self
  - Who has it: Prometheus, Sorcerer
  - Says: Cover an enemy in hindering stones.
  - Effect: {type: Condition; condition: Crystallised (crystallised); condition_duration: 5; condition_dot_modifier: 0.1}
  - Settings: respects_blocking: true
- **Dispel Magic** (`dispel_magic`) - level 14; spell, Gates of Pandora; main action; range 0-10; ranged; single target; no damage
  - Who has it: Prometheus
  - Says: Undo magic: everything spells did to the one it lands on - theirs or the other side's, blessing or curse - or a spell's zone, aimed at its ground. Cast through Pandora's gate it reaches what came through Pandora's or a shallower one; cast through a deeper gate, deeper. Something a spell called up or made is undone with it.
  - Effect: {type: Dispel Magic}
  - Settings: affects_both_sides: true; can_be_copied: false; chooses_gate: true
- **Fire Blast** (`fire_blast`) - level 1; spell, Gates of World; main action; range 0-20; ranged; single target; damage x1.2 Fire
  - Who has it: Prometheus, Sorcerer
  - Says: Shoot a flaming laser onto the target.
  - Settings: respects_blocking: true
- **Fireball** (`fireball`) - level 9; spell, Gates of Pandora; main action; range 1-15; ranged; area: Diamond 5; damage x2.0 Fire; contested against Physical
  - Who has it: Prometheus, Sorcerer
  - Says: Fire engulfs everyone around where it lands, unless a wall shelters them.
  - Settings: affects_both_sides: true; respects_blocking: true
- **Gnostic Tempest** (`gnostic_tempest`) - level 54; spell, Gates of Gnosis; main action; range 1-15; ranged; area: Diamond 2; damage x5.4 Plasma
  - Who has it: Prometheus
  - Says: A tempest of knowing over everything near where it lands.
  - Settings: respects_blocking: true
- **Growth** (`growth`) - level 8; spell, Gates of Hermes; main action; range 0-5; ranged; single target; aimed at allies; no damage
  - Who has it: Prometheus
  - Says: Swell an ally to a size bigger for three turns - a Human to a Large, covering four tiles and reaching from every edge of them; too big to be lifted by what could lift them before, and seeing over the bodies of the smaller. They need the room to grow into.
  - Effect: {type: Grow; duration: 3}
  - Settings: respects_blocking: true
- **Gust Blast** (`gust_blast`) - level 24; spell, Gates of Hermes; main action; range 1-15; ranged; single target; damage x1.2 Wind; contested against Physical
  - Who has it: Prometheus, Sorcerer
  - Says: Blast a powerful gust that pushes the target.
  - Effect: {type: Push; min_amount: 2; max_amount: 4; knockback_distance: 3}
  - Effect: {type: Condition; condition: Windswept (windswept); condition_duration: 5; condition_dot_modifier: 0.1}
  - Settings: affects_both_sides: true; respects_blocking: true
- **Hermes Step** (`hermes_step`) - level 7; spell, Gates of Hermes; main action; range 0-6; ranged; single target; aimed at allies; no damage
  - Who has it: Prometheus
  - Says: Pick an ally, then pick where they should be. They are simply there. Click them first, then the tile.
  - Settings: teleports: Target
- **Hover** (`hover`) - level 1; spell, Gates of Hermes; main action; range 0-10; ranged; single target; aimed at allies; no damage
  - Who has it: Prometheus
  - Says: Surround an ally in uplifting wind that allows them to fly across the field.
  - Effect: {type: Movement Class; display_name: "Hovering"; movement_class: Flying; duration: 5}
  - Settings: respects_blocking: true
- **Illusory Dragon** (`illusory_dragon`) - level 47; spell, Gates of Ogdoad; main action; range 1-12; ranged; single target; no damage
  - Who has it: Prometheus
  - Says: Shadow drawn out of the Ogdoad and given a dragon's shape, anywhere in reach. It stands where it stands like a living thing, but every blow misses it and nothing harms it; the other side near it is gripped by fear. Commanded, it flies and breathes a cone of whatever it is told to - fire, frost, lightning, poison, acid or dread - as strong as your own mind. It lasts as long as its tether to you holds.
  - Effect: {type: Summon; summons: "illusory_dragon"; with_summoners_attributes: true}
  - Settings: can_be_copied: false; tethered: true; tether_per_turn: 20
- **InstaHack** (`instahack`) - level 14; spell, Gates of Pandora; reaction; reacts: an enemy casts a spell; range 1-6; ranged; single target; no damage
  - Who has it: Prometheus
  - Says: Tear a spell apart the instant a foe in reach casts it - no minigame, no second chance for them. It comes to nothing, and their gate is spent all the same. Only ever a reaction, through the Gates of Pandora.
  - Effect: {type: Cancel Casting}
  - Settings: respects_blocking: true; can_be_copied: false
- **Invisibility** (`invisibility`) - level 1; spell, Gates of Hermes; main action; range 0-10; ranged; single target; aimed at allies; no damage
  - Who has it: Prometheus
  - Says: Turn yourself or an ally invisible - even while the enemy is watching. It lasts until they do anything to an enemy. On a stealth map it hides whoever you choose for ten minutes, through the Gates of Iris, at one casting each.
  - Effect: {type: Invisible}
  - Settings: respects_blocking: true; outside_gate: Gates of Iris; outside_seconds: 600
- **Ire of Sophia** (`ire_of_sophia`) - level 41; spell, Gates of Sophia; main action; range 1-15; ranged; area: Diamond 1; damage x4.2 Lightning
  - Who has it: Prometheus
  - Says: Wisdom's anger as a burst of lightning around where it lands.
  - Settings: respects_blocking: true
- **Kindled Hound** (`kindled_hound`) - level 14; spell, Gates of Pandora; main action; range 1-5; ranged; single target; no damage
  - Who has it: Prometheus
  - Says: A hound of embers, called up on a tile in reach to fight for you. Commanded, it runs and bites with fire; otherwise it stands on guard. It lasts as long as its tether to you holds.
  - Effect: {type: Summon; summons: "kindled_hound"}
  - Settings: can_be_copied: false; tethered: true; tether_per_damage: 1.5
- **Mist Step** (`mist_step`) - level 8; spell, Gates of Hermes; secondary action; range 0-6; ranged; single target; no damage
  - Who has it: Prometheus
  - Says: Gone in a breath of silver mist, and there again on any free tile within six - walls, cover and all between are nothing to it. A secondary action, so the main one is still yours.
  - Settings: teleports: Caster
- **Quicken** (`quicken`) - level 1; spell, Gates of World; main action; range 0-10; ranged; single target; aimed at allies; no damage
  - Who has it: Prometheus
  - Says: Grant an ally extra speed
  - Effect: {type: Stat Modifier; modifier_amount: 2; duration: 5}
  - Settings: respects_blocking: true
- **Rock Throw** (`rock_throw`) - level 1; spell, Gates of World; main action; range 0-20; ranged; single target; damage x1.2 Earth
  - Who has it: Prometheus, Sorcerer
  - Says: Create a stone that throws itself at high velocity.
  - Settings: respects_blocking: true
- **Stolen Sun** (`stolen_sun`) - level 64; spell, Gates of Yaldabaoth; main action; range 1-15; ranged; area: Diamond 2; damage x6.0 Fire
  - Who has it: Prometheus
  - Says: The fire he stole from the gods, let go at once: a sun on the battlefield.
  - Settings: respects_blocking: true
- **Tartarus Flame** (`tartarus_flame`) - level 32; spell, Gates of Tartarus; main action; range 1-15; ranged; single target; damage x3.1 Fire
  - Who has it: Prometheus
  - Says: Fire from the deepest pit, poured on one enemy.
  - Settings: respects_blocking: true
- **Wildfire** (`wildfire`) - level 16; spell, Gates of Pandora; main action; range 1-15; ranged; area: Diamond 2; damage x2.1 Fire; contested against Mindfulness
  - Who has it: Prometheus
  - Says: A fire that runs through all of them, and keeps burning.
  - Effect: {type: Condition; condition: Burn (burn); condition_duration: 5; condition_dot_modifier: 0.35}
  - Settings: respects_blocking: true
- **Wind Shot** (`wind_shot`) - level 1; spell, Gates of World; main action; range 0-20; ranged; single target; damage x1.2 Wind
  - Who has it: Prometheus, Sorcerer
  - Says: Conjure wind on your fingertips before leading it to the target.
  - Settings: respects_blocking: true
- **Wind Swoon** (`wind_swoon`) - level 8; spell, Gates of Hermes; main action; range 0-15; ranged; single target; damage x1.0 Wind; contested against Self
  - Who has it: Prometheus, Sorcerer
  - Says: Swoon them with the wind.
  - Effect: {type: Condition; condition: Windswept (windswept); condition_duration: 5; condition_dot_modifier: 0.1}
  - Settings: respects_blocking: true
- **Wind Vacuum** (`wind_vacuum`) - level 5; spell, Gates of Hermes; main action; range 2-15; ranged; single target; damage x0.2 Wind; contested against Physical
  - Who has it: Prometheus
  - Says: Suck a target closer to you.
  - Effect: {type: Pull; knockback_distance: 3}
  - Settings: affects_both_sides: true; respects_blocking: true

### Folder: unused

- **Element Up** (`element_up`) - level 4; spell, Gates of World; secondary action; range 0-0; ranged; single target; aimed at allies; no damage
  - Says: Through the study of Idology, upgrade the element of the next spell you cast.
  - Effect: {type: Upgrade Element; duration: 3}
- **Lightning Bolt** (`lightning_bolt`) - level 1; spell, Gates of Hermes; main action; range 1-10; ranged; area: Line 4; damage x1.0 Lightning
  - Says: A crackling beam that can be aimed in any direction, including diagonally.
  - Settings: respects_blocking: true
- **Mirror Image** (`mirror_image`) - level 5; spell, Gates of World; main action; range 0-6; ranged; single target; aimed at allies; no damage
  - Says: An image of an ally - any of them, near or far - set down anywhere in reach. The enemy takes it for them: goes for it as it would for them, and plans around it as it would around them. It has one point of health, stops nothing, and is gone at the first touch.
  - Effect: {type: Summon Decoy}
  - Settings: placed_in_reach: true; can_be_copied: false
- **Revitalizer** (`revitalizer`) - level 9; spell, Gates of Pandora; main action; range 0-20; ranged; area: Diamond 3; aimed at allies; no damage; heals (weapon base + 0.7 x the caster's spellcasting stat) x 1.3 (no defence, no randomness; the effect's min and max amount are unused)
  - Says: Heal everyone back to shape.
  - Effect: {type: Heal}

## Passives (data/passives)

- **Agile I** (`agile`, Always active, from level 8): Hard to pin down in cover: a twentieth less damage there. [Takes 5% less damage in cover.]
- **Agile II** (`agile_ii`, Always active, from level 32): Hard to pin down in cover - a twentieth less damage there - and into cover before anybody can strike: stepping into cover sets nothing off. [Stepping into cover sets off nothing.]
- **Ash Presence** (`ash_presence`, Always active): Ash pours off it. Anybody of the other side who starts a turn within two tiles of it chokes on it. [Aura: the other side within 2 tiles are choking ash.]
- **Aura I** (`aura`, Always active, from level 8): Allies within two tiles of her are blessed: a tenth less damage. [Aura: their own side within 2 tiles are blessed.]
- **Aura II** (`aura_ii`, Always active, from level 24): Allies within two tiles of her are blessed and soothed: a tenth less damage, and a twentieth of their health back as each turn starts. [Aura: their own side within 2 tiles are soothed.]
- **Bandolier** (`bandolier`, Always active): Everything it carries is to hand: an item can be its secondary action as well as its main one, and it throws any Gate Nade, whatever spell is sealed in it. [Can use items as a secondary action as well as a main one. Can throw Gate Nades as a secondary action as well as a main one. Can throw any Gate Nade, whatever spell is in it.]
- **Bulwark I** (`bulwark`, Always active, from level 8): Allies beside her are bulwarked: a tenth less damage. [Aura: their own side within 1 tiles are bulwarked.]
- **Bulwark III** (`bulwark_iii`, Always active, from level 54): Allies beside her are bulwarked, and her guard reaches two tiles: allies within them are fortified - a tenth less damage, a fifth beside her. [Aura: their own side within 2 tiles are fortified.]
- **Cat Burglar II** (`cat_burglar`, Always active, from level 24): Two more tiles of movement, four on a turn he starts in cover - and nothing stops him going up: he climbs onto high ground from anywhere, no ladder or steps needed, and up a wall or a pillar onto the floor above it. [+2 movement. Climbs onto high ground from anywhere, and up a wall or pillar to the floor above it.]
- **Cat Burglar I** (`cat_burglar_i`, Always active): Quick between hiding places: two more tiles of movement on a turn he starts in cover. [+2 movement on a turn they start in cover.]
- **Contest Insight I** (`contest_insight`, Always active, from level 24): He reads a contest before it starts: +10 to his stat in one. [+10 to their stat in a stat contest.]
- **Contest Insight II** (`contest_insight_ii`, Always active, from level 41): He reads a contest before it starts: +10 to his stat in one, +20 against anybody already afflicted. [+10 more in a contest with anybody carrying a harmful condition.]
- **Devotion** (`devotion`, Always active): Two castings of her own, for Heal or for Dread Visage on one person, spent before any gate. One comes back at a short rest, both at a long rest. [2 castings of their own for Heal or Dread Visage, in place of a gate - 1 back at a short rest, all at a long rest.]
- **DoT Master I** (`dot_master`, Always active, from level 16): His poisons and burns bite deeper: a tenth harder. [Their lingering damage is 10% harder.]
- **DoT Master II** (`dot_master_ii`, Always active, from level 41): His poisons and burns bite deeper still: three tenths harder, and a turn longer. [Their lingering damage is 20% harder. Their lingering damage lasts 1 turn longer.]
- **Dread Presence** (`dread_presence`, Always active): Whoever of the other side is within four tiles of it - when it appears, or as a turn of theirs begins - is gripped by fear of it, unless their Mindfulness is a match for its caster's Intellect. [Aura: the other side within 4 tiles are fear, unless their Mindfulness beats its Intellect.]
- **Elemental Affinity I** (`elemental_affinity`, Always active, from level 8): He knows what each element undoes: a tenth more damage on anybody weak to the element. [10% more damage on anybody weak to the hit's element.]
- **Elemental Affinity II** (`elemental_affinity_ii`, Always active, from level 32): He knows what each element undoes: a tenth more damage on anybody weak to the element, and a tenth more on anybody already burning, frozen, poisoned - taking any lingering damage. [10% more damage on anybody taking lingering damage.]
- **Elemental Mastery** (`elemental_mastery`, Always active, from level 64): One more casting through the deepest gate open to him. [1 more casting through the deepest gate open to them.]
- **Elusive** (`elusive`, Always active): He can Slip Past as a secondary action as well as a main one. [Can use Slip Past as a secondary action as well as a main one.]
- **Exposed** (`exposed`, Always active): Turn away from a champion at your peril: anybody of the other side who ends a turn within two tiles of them without hurting them is Exposed - a fifth more from the champion until their next turn. [Anybody of the other side ending a turn within 2 of them without hurting them is exposed.]
- **Hemmed In** (`hemmed_in`, Always active): Nobody walks past a champion of the pits for free: every tile within two of them costs the other side twice the movement. [Tiles within 2 of them cost the other side twice the movement.]
- **Hollow Frame** (`hollow_frame`, Always active): There is little left of it but bone and hunger. It folds itself to fit a gap - only the way the gap is too small: long and thin, tall and narrow, or down to a single tile - slowly, at twice the movement a step, and opens out again once there is room. [Folds itself a size narrower or shorter, or both, to fit where it is too big, at twice the movement a step.]
- **Iron Hide I** (`iron_hide`, Always active): Hide hardened by every blow she has taken: a tenth less damage from anything. [Takes 10% less damage.]
- **Iron Hide II** (`iron_hide_ii`, Always active, from level 16): Harder again: a fifth less damage from anything. [Takes 10% less damage.]
- **Iron Hide III** (`iron_hide_iii`, Always active, from level 41): Hide hardened to a fifth less damage from anything - and she steps into blows meant for others: half of any hit on an ally beside her is hers instead. [Takes 50% of any hit on an ally within 1 tiles.]
- **Kindling I** (`kindling`, Always active): Every spell he casts in a fight stokes the next: each one after it burns 5% hotter, up to 15%. [Each spell they cast in a fight makes the ones after it 5% harder, up to 15%.]
- **Kindling II** (`kindling_ii`, Always active, from level 16): Every spell he casts in a fight stokes the next: each one after it burns 5% hotter, up to 30%. [Kindling builds up to 15% further.]
- **Kindling III** (`kindling_iii`, Always active, from level 54): Every spell he casts in a fight stokes the next: each one after it burns 5% hotter, up to 45%. [Kindling builds up to 15% further.]
- **Light Footed** (`light_footed`, Always active): Stealth, Slip Past and Run can be used as his secondary action as well as his main one - so he can Run twice in a turn, or slip away after striking. [Can use Stealth, Slip Past and Run as a secondary action as well as a main one.]
- **Measured Eye** (`measured_eye`, Always active): Every blow she lands teaches her something. Whoever she hits is studied, just as Study would - their sheet open to the party, and her next blows landing with a studier's edge. [Every hit studies whoever it lands on, as Study does.]
- **Meditate** (`meditate`, Always active): At a short rest, once until the next long rest, he brings back castings he has spent: a point to spend every six levels, each casting costing its gate's depth, and none deeper than the shallower half of his open gates. [Meditates at a short rest, once until the next long rest: brings back spent castings, a point every six levels, each costing its gate's depth.]
- **Mercy I** (`mercy`, Always active): Her heals mend a tenth more. [Heals mend 10% more.]
- **Mercy II** (`mercy_ii`, Always active, from level 16): Her heals mend a tenth more, and lift one harmful condition as well. [Heals lift one harmful condition too.]
- **Mercy III** (`mercy_iii`, Always active, from level 41): Her heals mend a tenth more and lift one harmful condition, and whoever she heals is sheltered: a fifth less damage until their next turn starts. [Whoever they heal is sheltered.]
- **Mimicry** (`mimicry`, Always active): Does whatever your party did last: the last skill any of you used, turned on you - or on its own side, if it was meant for allies. It cannot copy Run, Slip Past or Study, and copies whatever came before them instead. Until one of you has done something it can copy, it waits. It opens no gates and needs none, so a copied spell is cast however deep a gate it calls for. Whatever it copies is worked out from its Self, not the stat the skill would usually use. [Casts without opening a gate, however deep a gate the spell calls for. Every skill scales with Self, whatever stat the skill itself names.]
- **Momentum I** (`momentum`, Always active, from level 32): Planted, she hits harder: a tenth more damage on a turn she has not walked - every blow, Sweep Strike's whole sweep too. [10% more damage on a turn they have not walked.]
- **Momentum II** (`momentum_ii`, Always active, from level 64): Planted, every blow lands like a falling wall: fifteen hundredths more damage on a turn she has not walked - Sweep Strike's whole sweep too. [5% more damage on a turn they have not walked.]
- **Nade Juggler** (`nade_juggler`, Always active): Throws any Gate Nade, whatever spell is in it - everybody else only those whose spell they know or could learn - and throws them with his secondary action, where the spell would take the main one. [Can throw Gate Nades as a secondary action as well as a main one. Can throw any Gate Nade, whatever spell is in it.]
- **Prying Mind** (`prying_mind`, Always active): He can hack: wards and seals, machines and locks, and the spell a foe is winding up. The sharper his Intellect, the more tries he gets, and the less each retry costs him. [Can hack wards, machines and the spells others are winding up - more tries, and cheaper ones, the higher their Intellect.]
- **Quick Hands** (`quick_hands`, Always active): Items can be used as his secondary action as well as his main one, and he reaches for the secondary first - so he can drink a potion and still attack in the same turn. [Can use items as a secondary action as well as a main one.]
- **Radiant Guardian** (`radiant_guardian`, Always active, from level 64): While she stands, the party takes a tenth less damage. [While they stand, their side takes 10% less damage.]
- **Reserved Power I** (`reserved_power`, Always active, from level 32): One more casting through the deepest gate open to her. [1 more casting through the deepest gate open to them.]
- **Reserved Power II** (`reserved_power_ii`, Always active, from level 54): Two more castings through the deepest gate open to her. [1 more casting through the deepest gate open to them.]
- **Synergy I** (`synergy`, Always active, from level 54): He shows the party where it hurts: they hit anybody carrying a harmful condition a tenth harder. [Their side hits anybody carrying a harmful condition 10% harder.]
- **Synergy II** (`synergy_ii`, Always active, from level 64): He shows the party where it hurts: they hit anybody carrying a harmful condition a tenth harder, and a fifth harder if it is one of his. [And 10% harder again on anybody carrying one of theirs.]

## Conditions (data/conditions)

- **Accused** (`accused`, tag Ac): Accused before everybody: 15% more from every blow, until their next turn starts. | settings: duration: 1; wears_off_at_start: true; damage_taken_change: 0.15
- **Bile-Soaked** (`bile_soaked`, tag Bi): Spat out of the glutton, dripping with it: slower, and half-blind. | settings: duration: 2; movement_change: -2; accuracy_change: -15
- **Blessed** (`blessed`, tag Bs): In Alithia's grace: takes less damage. | settings: duration: 1; damage_taken_change: -0.1
- **Blind** (`blind`, tag ): Can barely see - every skill reaches only one tile away. | settings: max_range: 1
- **Blurred** (`blurred`, tag Br): Hard to make out from afar: a fifth less from anything thrown or shot from more than a tile away, until their next turn starts. | settings: duration: 1; wears_off_at_start: true; less_from_afar: 0.2
- **Bulwarked** (`bulwarked`, tag Bw): Behind Enfina's guard: takes less damage. | settings: duration: 1; damage_taken_change: -0.1
- **Burn** (`burn`, tag ): A strong DOT that also increases the speed by 2. | settings: duration: 5; dot_type: Fire; dot_strength: Powerful; dot_modifier: 1.0; dot_min: 4; dot_max: 5; movement_change: 2
- **Choking Ash** (`choking_ash`, tag ): Ash in the throat and eyes: everything they do is less likely to land. | settings: duration: 1; accuracy_change: -15
- **Confused** (`confused`, tag ): Cannot tell friend from foe: goes for whoever is nearest, and does nothing else. | settings: duration: 1; confuses: true
- **Corroded** (`corroded`, tag Cd): Eaten at by something caustic: it burns a little every turn, and their armour is worse while it does. | settings: duration: 5; dot_type: Acid; dot_modifier: 0.25; dot_min: 1; dot_max: 2; defense_change: -0.1
- **Crippled** (`crippled`, tag Cp): Its legs are broken. It cannot move again this fight. | settings: duration: 999; prevents_movement: true
- **Crystallised** (`crystallised`, tag ): Encased and cracking. Cannot move. | settings: duration: 5; dot_type: Earth; dot_strength: Weak; dot_modifier: 1.0; dot_min: 1; dot_max: 3; prevents_movement: true
- **Dazed** (`dazed`, tag ): Reeling from the impact: two tiles less to walk, no secondary action and no reactions. They keep their main action. | settings: duration: 1; movement_change: -2; prevents_secondary: true; prevents_reactions: true
- **Deafened** (`deafened`, tag ): The bells still ringing in their ears: less likely to land anything, and too slow to react to anybody. | settings: duration: 1; accuracy_change: -10; prevents_reactions: true
- **Deceived** (`deceived`, tag Dc): Sure one of their own has sold them out: their next turn goes on the nearest of their own side. | settings: duration: 2; turns_on_own_side: true
- **Exposed** (`exposed`, tag Ex): Turned their back on a champion standing close: takes a fifth more from that champion until their next turn starts. | settings: duration: 1; wears_off_at_start: true; more_from_source: 0.2
- **Fear** (`fear`, tag ): Too afraid to advance and can barely aim. | settings: accuracy_change: -20; prevents_approach: true
- **Fortified** (`fortified`, tag Fo): Within Enfina's reach: takes a tenth less damage. | settings: duration: 1; damage_taken_change: -0.1
- **Frozen** (`frozen`, tag ): Locked in ice. Too stiff for a secondary action and speed is slowed by 2. | settings: duration: 5; dot_type: Water; dot_strength: Weak; dot_modifier: 1.0; dot_min: 1; dot_max: 3; movement_change: -2; prevents_secondary: true
- **Grand Design** (`grand_design`, tag Gd): Every gate open at once: this turn his spells cost no gate, and casting one leaves his action for another. | settings: duration: 1; wears_off_at_start: true; casts_freely: true
- **Grappled** (`grappled`, tag Gp): Held fast by whoever grabbed them: no moving until they break free, which takes their main action. Teleported, shoved or thrown - either of them - and the grip is gone; so it is if whoever holds them is not beside them any more. | settings: duration: 999; prevents_movement: true; holds: true
- **Hesitating** (`hesitating`, tag ): Talked into standing down: they lose their next turn - unless somebody hurts them first. | settings: duration: 2; skips_turn: true; ends_when_hit: true
- **Mirage** (`mirage`, tag Mi): Cloaked in illusions: a quarter less from every blow, and one in four misses outright, while they stand in the mirage. | settings: duration: 1; wears_off_at_start: true; damage_taken_change: -0.25; miss_chance: 25
- **Phantom Body** (`phantom_body`, tag Ph): An image laid over them: the next attack that would hit them strikes it instead, and misses. | settings: evades_next_hit: true
- **Poisoned** (`poisoned`, tag ): Venom works through them. Too sick to react to anything. | settings: duration: 5; dot_type: Poison; dot_strength: Strong; dot_modifier: 1.0; dot_min: 3; dot_max: 4; prevents_reactions: true
- **Recanted** (`recanted`, tag Rc): The future that was read of them will not happen: they lose their next turn. | settings: duration: 1; skips_turn: true
- **Reflected** (`reflected`, tag Rf): Inside a reflection of the world: invisible to the other side while they stay in it. Acting against an enemy gives them away until their next turn starts. | settings: duration: 1; makes_invisible: true
- **Riding** (`riding`, tag ): Up on somebody enormous: carried wherever they go, out of everybody's reach, and every blow on them lands - and harder. No walking until they climb down or are thrown off. | settings: duration: 999; prevents_movement: true
- **Sanctified** (`sanctified`, tag Sa): Standing in a sanctuary of light: 15% less from every blow, and one attack in four strikes a copy of them and misses. | settings: duration: 2; damage_taken_change: -0.15; miss_chance: 25
- **Scented** (`scented`, tag Sc): The glutton has their scent: it is coming for them next, to get hold of them - and what it holds, it swallows. Cleanse washes it off. | settings: duration: 2
- **Sheltered** (`sheltered`, tag Sh): Healed and steadied: takes a fifth less damage until their next turn starts. | settings: duration: 1; wears_off_at_start: true; damage_taken_change: -0.2
- **Snared** (`snared`, tag Sn): Caught in a trap: cannot walk until it lets go. | settings: duration: 1; prevents_movement: true
- **Soothed** (`soothed`, tag So): Alithia's grace mends a little of their health as each turn starts. | settings: duration: 1; mends_share: 0.05
- **Staggered** (`staggered`, tag Sg): Reeling from a full stagger bar: loses their turn, and is hit harder until it is over. | settings: duration: 1; skips_turn: true
- **Stunned** (`stunned`, tag ): Loses their turn entirely. | settings: duration: 2; skips_turn: true
- **Caught off guard** (`surprised`, tag ): Ambushed before they knew anybody was there: loses their first turn. | settings: duration: 1; skips_turn: true
- **Swallowed** (`swallowed`, tag Sw): Inside the glutton, being digested: acid every turn, no moving, and nothing to hit but the belly around them. Out alive if its Belly Hole is torn open, if it is staggered, or if it falls - dead, if it digests them first. | settings: duration: 999; dot_type: Acid; dot_strength: Medium; dot_modifier: 0.5; dot_min: 8; dot_max: 12; prevents_movement: true; prevents_reactions: true
- **Veiled** (`veiled`, tag Ve): A veil of mercy over them: the next blow lands a little softer (15% less), and the veil goes with it. | settings: duration: 2; damage_taken_change: -0.15; ends_when_hit: true
- **Windswept** (`windswept`, tag ): Battered by wind - slowed by 3, and blown about 3 tiles away at the start of each turn. | settings: duration: 5; dot_type: Wind; dot_strength: Medium; dot_modifier: 1.0; dot_min: 1; dot_max: 2; movement_change: -3; drift_tiles: 3

## Items

- **Archive Ledger** (`archive_ledger`): Who paid whom, and for what. Worth more than everything else in the archive put together. | keepsake: true; targets_ally: true; deals_damage: false
- **Big Bomb** (`big_bomb`): An adequate explosion | item_power: 85; price: 520; bomb: true; max_range: 5; affects_both_sides: true; ability_modifier: 2.0; uses_stat_contest: true; aoe_radius: 3
- **Blank Requisition** (`blank_requisition`): A requisition for ten crates of lamp oil, filled in in the quartermaster's hand. It only wants a seal. | keepsake: true; targets_ally: true; deals_damage: false
- **Blinding Bomb** (`blinding_bomb`): Deliver to them an instant of intense light that blinds them temporarily. | item_power: 47; price: 120; bomb: true; max_range: 5; effects: [{type: Condition; condition: Blind (blind); condition_duration: 3}]; deals_damage: false; uses_stat_contest: true; contest_stat: Mindfulness
- **Burn Bottle** (`burn_bottle`): Bring on the heat. | item_power: 47; price: 120; max_range: 5; effects: [{type: Condition; condition: Burn (burn); condition_duration: 3}]; deals_damage: false; uses_stat_contest: true; contest_stat: Mindfulness
- **Burner Spellbook** (`burner_spellbook`): A spellbook of Burner. Prometheus can learn Burner from it - on the Moves page of his character sheet, between fights - and it is used up as he does. | price: 150; teaches: "burner"; can_be_copied: false; deals_damage: false
- **Communion Gate Nade** (`communion_gate_nade`): Communion, sealed in a shell: throw it and the spell goes off with no gate of your own opened - if you know the spell or could learn it. Gone once thrown. | spell: "communion"; item_power: 50; price: 150; max_range: 10; targets_ally: true; can_be_copied: false; effects: [{type: Heal; heal_flat: 8.0; heal_per_stat: 0.15; heal_per_weapon: 0.2}]; deals_damage: false; ability_modifier: 0.6; scaling_stat: Mindfulness; aoe_radius: 2 | heals item power 50 x 0.6 (no defence, no randomness; the effect's min and max amount are unused)
- **Crystal Bottle** (`crystal_bottle`): Give them a highly volatile crystal in a bottle. | item_power: 47; price: 120; max_range: 5; effects: [{type: Condition; condition: Crystallised (crystallised); condition_duration: 3; condition_dot_modifier: 0.3}]; deals_damage: false; uses_stat_contest: true; contest_stat: Self
- **Crystalise Gate Nade** (`crystalise_gate_nade`): Crystalise, sealed in a shell: throw it and the spell goes off with no gate of your own opened - if you know the spell or could learn it. Gone once thrown. | spell: "crystalise"; item_power: 40; price: 60; max_range: 15; respects_blocking: true; can_be_copied: false; effects: [{type: Condition; condition: Crystallised (crystallised); condition_duration: 5; condition_dot_modifier: 0.1}]; scaling_stat: Intellect; damage_type: Earth; uses_stat_contest: true; contest_stat: Self
- **Crystalise Spellbook** (`crystalise_spellbook`): A spellbook of Crystalise. Prometheus can learn Crystalise from it - on the Moves page of his character sheet, between fights - and it is used up as he does. | price: 150; teaches: "crystalise"; can_be_copied: false; deals_damage: false
- **Cure Potion** (`cure_potion`): A quick drink to help you restore minor vitality. | item_power: 0; price: 50; max_range: 2; targets_ally: true; effects: [{type: Heal; heal_modifier: 0.7; heal_share_of_health: 0.25; min_amount: 25; max_amount: 25}]; deals_damage: false | heals item power 0 x 0.7 + 25% of the target's max health (no defence, no randomness; the effect's min and max amount are unused)
- **Dispel Magic Spellbook** (`dispel_magic_spellbook`): A spellbook of Dispel Magic. Prometheus can learn Dispel Magic from it - on the Moves page of his character sheet, between fights - and it is used up as he does. | price: 375; teaches: "dispel_magic"; can_be_copied: false; deals_damage: false
- **Emetic Powder** (`emetic_powder`): Stir it into something left out for a guard to eat or drink (stand beside it, E). A few seconds after he has had it, he is off to be sick for five minutes, seeing nothing. | poison: Emetic; targets_ally: true; deals_damage: false
- **Fever Dart** (`fever_dart`): Throw it at a guard (T, then click him). He is too unwell to stand, and whoever is nearest comes to see to him. Both watch half as wide. | poison: Disease; poison_onset: Instant; poison_shootable: true; targets_ally: true; deals_damage: false
- **Fever Tincture** (`fever_tincture`): Into somebody's food or drink. A quarter of a minute after, they are too unwell to stand - and whoever is nearest comes to see to them. Both watch half as wide. | poison: Disease; poison_onset: Delayed; targets_ally: true; deals_damage: false
- **Fireball Gate Nade** (`fireball_gate_nade`): Fireball, sealed in a shell: throw it and the spell goes off with no gate of your own opened - if you know the spell or could learn it. Gone once thrown. | spell: "fireball"; item_power: 50; price: 150; min_range: 1; max_range: 15; affects_both_sides: true; respects_blocking: true; can_be_copied: false; ability_modifier: 2.0; scaling_stat: Intellect; damage_type: Fire; uses_stat_contest: true; aoe_radius: 5
- **Fireball Spellbook** (`fireball_spellbook`): A spellbook of Fireball. Prometheus can learn Fireball from it - on the Moves page of his character sheet, between fights - and it is used up as he does. | price: 375; teaches: "fireball"; can_be_copied: false; deals_damage: false
- **Flame Edge Spellbook** (`flame_edge_spellbook`): A spellbook of Flame Edge. Prometheus can learn Flame Edge from it - on the Moves page of his character sheet, between fights - and it is used up as he does. | price: 375; teaches: "flame_edge"; can_be_copied: false; deals_damage: false
- **Forged Letter** (`forged_letter`): A letter in the captain's own hand - or near enough. Left somewhere it will be found, it will cause a great deal of trouble for somebody. | keepsake: true; targets_ally: true; deals_damage: false
- **Frost Bottle** (`frost_bottle`): A volatile ice crystal that will expand on impact. | item_power: 47; price: 120; max_range: 5; effects: [{type: Condition; condition: Frozen (frozen); condition_duration: 2; condition_dot_modifier: 0.3}]; deals_damage: false; uses_stat_contest: true; contest_stat: Intellect
- **Frost Edge Spellbook** (`frost_edge_spellbook`): A spellbook of Frost Edge. Prometheus can learn Frost Edge from it - on the Moves page of his character sheet, between fights - and it is used up as he does. | price: 375; teaches: "frost_edge"; can_be_copied: false; deals_damage: false
- **Gale Bottle** (`gale_bottle`): Bottled mini tornado to give as a gift. Without consent. | item_power: 47; price: 120; max_range: 5; effects: [{type: Condition; condition: Windswept (windswept); condition_duration: 2; condition_dot_modifier: 0.6}]; deals_damage: false; uses_stat_contest: true
- **Gnostic Tempest Spellbook** (`gnostic_tempest_spellbook`): A spellbook of Gnostic Tempest. Prometheus can learn Gnostic Tempest from it - on the Moves page of his character sheet, between fights - and it is used up as he does. | price: 1500; teaches: "gnostic_tempest"; can_be_copied: false; deals_damage: false
- **Growth Spellbook** (`growth_spellbook`): A spellbook of Growth. Prometheus can learn Growth from it - on the Moves page of his character sheet, between fights - and it is used up as he does. | price: 150; teaches: "growth"; can_be_copied: false; deals_damage: false
- **Gust Blast Spellbook** (`gust_blast_spellbook`): A spellbook of Gust Blast. Prometheus can learn Gust Blast from it - on the Moves page of his character sheet, between fights - and it is used up as he does. | price: 150; teaches: "gust_blast"; can_be_copied: false; deals_damage: false
- **Heal Gate Nade** (`heal_gate_nade`): Heal, sealed in a shell: throw it and the spell goes off with no gate of your own opened - if you know the spell or could learn it. Gone once thrown. | spell: "heal"; item_power: 30; price: 60; max_range: 5; targets_ally: true; can_be_copied: false; effects: [{type: Heal; heal_flat: 12.0; heal_per_stat: 0.25; heal_per_weapon: 0.3; min_amount: 4; max_amount: 8}]; deals_damage: false; ability_modifier: 0.7; scaling_stat: Mindfulness | heals item power 30 x 0.7 (no defence, no randomness; the effect's min and max amount are unused)
- **Hermes Step Spellbook** (`hermes_step_spellbook`): A spellbook of Hermes Step. Prometheus can learn Hermes Step from it - on the Moves page of his character sheet, between fights - and it is used up as he does. | price: 150; teaches: "hermes_step"; can_be_copied: false; deals_damage: false
- **Hover Spellbook** (`hover_spellbook`): A spellbook of Hover. Prometheus can learn Hover from it - on the Moves page of his character sheet, between fights - and it is used up as he does. | price: 150; teaches: "hover"; can_be_copied: false; deals_damage: false
- **Illusory Dragon Spellbook** (`illusory_dragon_spellbook`): A spellbook of Illusory Dragon. Prometheus can learn Illusory Dragon from it - on the Moves page of his character sheet, between fights - and it is used up as he does. | price: 1500; teaches: "illusory_dragon"; can_be_copied: false; deals_damage: false
- **InstaHack Spellbook** (`instahack_spellbook`): A spellbook of InstaHack. Prometheus can learn InstaHack from it - on the Moves page of his character sheet, between fights - and it is used up as he does. | price: 375; teaches: "instahack"; can_be_copied: false; deals_damage: false
- **Invisibility Spellbook** (`invisibility_spellbook`): A spellbook of Invisibility. Prometheus can learn Invisibility from it - on the Moves page of his character sheet, between fights - and it is used up as he does. | price: 150; teaches: "invisibility"; can_be_copied: false; deals_damage: false
- **Ire of Sophia Spellbook** (`ire_of_sophia_spellbook`): A spellbook of Ire of Sophia. Prometheus can learn Ire of Sophia from it - on the Moves page of his character sheet, between fights - and it is used up as he does. | price: 1500; teaches: "ire_of_sophia"; can_be_copied: false; deals_damage: false
- **Kindled Hound Spellbook** (`kindled_hound_spellbook`): A spellbook of Kindled Hound. Prometheus can learn Kindled Hound from it - on the Moves page of his character sheet, between fights - and it is used up as he does. | price: 375; teaches: "kindled_hound"; can_be_copied: false; deals_damage: false
- **Knockout Drops** (`knockout_drops`): Into somebody's food or drink. The moment he has had it he is out cold where he stands - right beside his supper, a body to be found. | poison: Sedative; poison_onset: Instant; targets_ally: true; deals_damage: false
- **Magnifying Glass** (`magnifying_glass`): Brass and a good lens. Hold it over a picture to see what is too faint or too small to see without it. | keepsake: true; reveals_hidden_details: true; targets_ally: true; deals_damage: false
- **Medicine** (`medicine`): Restores minor health and lifts whatever went wrong most recently. | item_power: 47; price: 40; max_range: 2; targets_ally: true; effects: [{type: Heal; heal_modifier: 0.5; min_amount: 15; max_amount: 15}, {type: Dispel; dispel_scope: Debuffs Only; dispel_count: 1}]; deals_damage: false | heals item power 47 x 0.5 (no defence, no randomness; the effect's min and max amount are unused)
- **Mediocre Cure Potion** (`mediocre_cure_potion`): In the same ammount of sips, you restore more vitality. | item_power: 0; price: 120; max_range: 2; targets_ally: true; effects: [{type: Heal; heal_modifier: 0.7; heal_share_of_health: 0.4}]; deals_damage: false | heals item power 0 x 0.7 + 40% of the target's max health (no defence, no randomness; the effect's min and max amount are unused)
- **Medium Bomb** (`medium_bomb`): Sometimes used to demolish weak structures. | item_power: 47; price: 280; bomb: true; max_range: 4; affects_both_sides: true; ability_modifier: 2.0; uses_stat_contest: true; aoe_radius: 2
- **Mist Step Spellbook** (`mist_step_spellbook`): A spellbook of Mist Step. Prometheus can learn Mist Step from it - on the Moves page of his character sheet, between fights - and it is used up as he does. | price: 150; teaches: "mist_step"; can_be_copied: false; deals_damage: false
- **Pebble** (`pebble`): Throw it on a stealth map (T, then click) and every guard within four tiles of where it lands goes to see what that was. | distraction_radius: 4.0; targets_ally: true; deals_damage: false
- **Poison Bottle** (`poison_bottle`): Dull their reactions with a well placed and subtle poison. | item_power: 47; price: 120; max_range: 5; effects: [{type: Condition; condition: Poisoned (poisoned); condition_duration: 3; condition_dot_modifier: 0.8}]; deals_damage: false; uses_stat_contest: true
- **Potent Cure Potion** (`potent_cure_potion`): Just a sip is enough to restore a lot of vitality. | item_power: 0; price: 240; max_range: 3; targets_ally: true; effects: [{type: Heal; heal_modifier: 0.7; heal_share_of_health: 0.55}]; deals_damage: false | heals item power 0 x 0.7 + 55% of the target's max health (no defence, no randomness; the effect's min and max amount are unused)
- **Priest Robes** (`priest_robes`): Pass for a Priest on a stealth map. Fools anyone who doesn't know every Priest by sight. | consumed_on_use: false; disguise_as: "priest"; targets_ally: true; deals_damage: false
- **Retching Dart** (`retching_dart`): Throw it at a guard (T, then click him). A quarter of a minute later he is off to be sick, for five minutes. | poison: Emetic; poison_onset: Delayed; poison_shootable: true; targets_ally: true; deals_damage: false
- **Seal of Office** (`seal_of_office`): Captain Vell's own seal, kept under lock. Whatever it is pressed into, he has signed. | keepsake: true; targets_ally: true; deals_damage: false
- **Sealed Requisition** (`sealed_requisition`): Ten crates of lamp oil, ordered under Captain Vell's seal. The same ten crates that never reached the ledger. | keepsake: true; made_from: ["blank_requisition", "seal_of_office"]; combine_text: "Pressed into the wax, the captain's seal turns the quartermaster's scrap into an order - ten crates of lamp oil, with Vell's own name under it."; targets_ally: true; deals_damage: false
- **Shock Bottle** (`shock_bottle`): Glass, and something unpleasant inside. Thrown at one enemy. | item_power: 47; price: 120; max_range: 5; effects: [{type: Condition; condition: Stunned (stunned); condition_duration: 1}]; deals_damage: false
- **Sleep Dart** (`sleep_dart`): Throw it at a guard (T, then click him). He is out cold where he stands, without a sound. | poison: Sedative; poison_onset: Instant; poison_shootable: true; targets_ally: true; deals_damage: false
- **Sleeping Draught** (`sleeping_draught`): Into somebody's food or drink. A quarter of a minute after they have had it they are out cold where they stand - a body, to be found. | poison: Sedative; poison_onset: Delayed; targets_ally: true; deals_damage: false
- **Small Bomb** (`small_bomb`): Rather more than a firecracker. | item_power: 25; price: 140; bomb: true; max_range: 5; affects_both_sides: true; ability_modifier: 2.0; uses_stat_contest: true; aoe_radius: 1
- **Smelling Salts** (`smelling_salts`): Held under the nose of somebody fallen beside you: they are back up with half their health - and, as after Resuscitate, a tenth weaker until a long rest. | min_range: 1; max_range: 1; melee: true; targets_ally: true; targets_fallen: true; effects: [{type: Revive; revive_health: 0.5; revive_weakening: 0.1}]; deals_damage: false
- **Stolen Signet** (`stolen_signet`): The captain's own ring, missing since yesterday - and the whole watch looking for whoever took it. Slip it into a guard's pocket and let the next one find it there. | keepsake: true; frames: true; targets_ally: true; deals_damage: false
- **Stolen Sun Spellbook** (`stolen_sun_spellbook`): A spellbook of Stolen Sun. Prometheus can learn Stolen Sun from it - on the Moves page of his character sheet, between fights - and it is used up as he does. | price: 2000; teaches: "stolen_sun"; can_be_copied: false; deals_damage: false
- **Stone Edge Spellbook** (`stone_edge_spellbook`): A spellbook of Stone Edge. Prometheus can learn Stone Edge from it - on the Moves page of his character sheet, between fights - and it is used up as he does. | price: 375; teaches: "stone_edge"; can_be_copied: false; deals_damage: false
- **Storm Edge Spellbook** (`storm_edge_spellbook`): A spellbook of Storm Edge. Prometheus can learn Storm Edge from it - on the Moves page of his character sheet, between fights - and it is used up as he does. | price: 375; teaches: "storm_edge"; can_be_copied: false; deals_damage: false
- **Tartarus Flame Spellbook** (`tartarus_flame_spellbook`): A spellbook of Tartarus Flame. Prometheus can learn Tartarus Flame from it - on the Moves page of his character sheet, between fights - and it is used up as he does. | price: 750; teaches: "tartarus_flame"; can_be_copied: false; deals_damage: false
- **Terror Bottle** (`terror_bottle`): Some say that emotions are just chemical reactions. | item_power: 47; price: 120; max_range: 5; effects: [{type: Condition; condition: Fear (fear); condition_duration: 2}]; deals_damage: false; uses_stat_contest: true; contest_stat: Mindfulness
- **Tiny Bomb** (`tiny_bomb`): Hopefully they won't appear inside someone's dinner. | item_power: 10; price: 45; bomb: true; max_range: 5; affects_both_sides: true; ability_modifier: 2.0; uses_stat_contest: true; aoe_radius: 1
- **Wildfire Spellbook** (`wildfire_spellbook`): A spellbook of Wildfire. Prometheus can learn Wildfire from it - on the Moves page of his character sheet, between fights - and it is used up as he does. | price: 375; teaches: "wildfire"; can_be_copied: false; deals_damage: false
- **Wind Swoon Spellbook** (`wind_swoon_spellbook`): A spellbook of Wind Swoon. Prometheus can learn Wind Swoon from it - on the Moves page of his character sheet, between fights - and it is used up as he does. | price: 150; teaches: "wind_swoon"; can_be_copied: false; deals_damage: false
- **Wind Vacuum Spellbook** (`wind_vacuum_spellbook`): A spellbook of Wind Vacuum. Prometheus can learn Wind Vacuum from it - on the Moves page of his character sheet, between fights - and it is used up as he does. | price: 150; teaches: "wind_vacuum"; can_be_copied: false; deals_damage: false

## Equipment and containers

- **Belt Pouch** (`belt_pouch`): A stout pouch that hangs at the hip. | slot: Pouch; price: 120
- **Brigandine** (`brigandine`): Plates riveted inside a canvas coat. | slot: Armour; price: 180; defense: 20; armour_category: Heavy
- **Coin Pouch** (`coin_pouch`): Room for a couple of small things beside the coins. | slot: Pouch; price: 40; slots: 2
- **Ember Greatsword** (`ember_greatsword`): Forged hot and never quite cooled. | for_characters: ["enfina"]; price: 150; weapon_base: 11
- **Feather Charm** (`feather_charm`): A white feather on a cord. The step comes lighter. | slot: Charm; price: 120; passive: Light Step {name: "Light Step"; movement_bonus: 1}
- **Fencer's Rapier** (`fencers_rapier`): A slimmer, quicker blade than the one he grew up with. | for_characters: ["cyrus"]; price: 150; weapon_base: 10
- **Grenadier's Pack** (`grenadiers_pack`): Padded cells sized for bombs: two bombs sit snugly in each. | slot: Backpack; price: 260; slots: 16; bombs_per_slot: 2
- **Hunter's Pouch** (`hunters_pouch`): Deep and many-pocketed, for a long day out. | slot: Pouch; price: 240; slots: 6
- **Iron Charm** (`iron_charm`): A ring of black iron, cold to the touch. | slot: Charm; price: 40; passive: Iron Skin {name: "Iron Skin"; defense_bonus: 5}
- **Large Pack** (`large_pack`): A frame pack for somebody who means to carry everything. | slot: Backpack; price: 260; slots: 28
- **Padded Jacket** (`padded_jacket`): Quilted cloth, quiet and warm. | slot: Armour; price: 60; defense: 12
- **Plate Harness** (`plate_harness`): Full plate, made for her. | slot: Armour; for_characters: ["enfina"]; price: 320; defense: 28; armour_category: Heavy
- **Rowan Staff** (`rowan_staff`): Old wood that has carried a great deal of fire. | for_characters: ["prometheus"]; price: 150; weapon_base: 10
- **Satchel** (`satchel`): A shoulder bag. It will do. | slot: Backpack; price: 20; slots: 12
- **Simple Baldric** (`simple_belt`): A plain leather baldric, worn across the chest, with loops for four things to hand. | slot: Belt; price: 15
- **Traveller's Pack** (`travellers_pack`): The pack everybody sets out with. | slot: Backpack; price: 60; slots: 20
- **Utility Baldric** (`utility_belt`): Buckles, loops and a clip for everything - six things to hand in a fight. | slot: Belt; price: 250; slots: 6
- **Votive Mace** (`votive_mace`): Heavy at the head, light in the hand of the faithful. | for_characters: ["alithia"]; price: 150; weapon_base: 10
- **Worn Knife** (`worn_knife`): Anybody's, and it has been everybody's. | price: 50; weapon_base: 7

## Enemies

### Alchemist (`alchemist`)

- Main stat Intellect, secondary Mindfulness; health 32 at level 1, 90 at 64; movement 6
- Skills: Rapier, Run
- Passive **Bandolier**: Everything it carries is to hand: an item can be its secondary action as well as its main one, and it throws any Gate Nade, whatever spell is sealed in it. [Can use items as a secondary action as well as a main one. Can throw Gate Nades as a secondary action as well as a main one. Can throw any Gate Nade, whatever spell is in it.]
- Settings: glossary_text: "Hung about with bottles, bombs and Gate Nades, and quick with all of them: it mends whoever of its side is worst hurt and throws the rest at you, two things a turn. Take it down and what it did not use is yours."; class_t: Ranged; max_hp: 32; max_hp_level_20: 90; defense: 5; defense_level_64: 30; initiative: 4; pocket_size: 12; ai_function: "ai_alchemist"

### Ash Warden (`ash_warden`)

- Main stat Physical, secondary Mindfulness; health 300 at level 1, 1500 at 64; movement 6
- Skills: Greatsword Attack, Ground Pound
- Passive **Ash Presence**: Ash pours off it. Anybody of the other side who starts a turn within two tiles of it chokes on it. [Aura: the other side within 2 tiles are choking ash.]
- Settings: glossary_text: "A giant in black iron, full of fire. It cannot be stunned, confused, shoved or moved - until its armour cracks."; max_hp: 300; max_hp_level_20: 1500; size: Large; initiative: 4; resist_fire: 50; immune_to_conditions: [Stunned (stunned), Confused (confused)]; immune_to: [0, 1, 9]; turns_per_round: 2; boss: {title: "Warden of the Ash Gate"; stagger: {hint: "Hit it hard - twice as hard while it winds up a Ground Pound. Stuns it shrugs off still count. So do the powder kegs, and its own ash."; max_value: 120.0; per_blocked_condition: 20.0; while_readying: 2.0}; phases: [The Ash Rises {name: "The Ash Rises"; at_health: 0.66; message: "Its armour splits, and burning ash pours out of it."; skills_added: ["rockfall"]; hazards: [{display_name: "Burning ash falls"; description: "Every other round, burning ash comes down where the party stands - marked a round ahead."; every_rounds: 2; count: 2; damage: 20; damage_type: Fire; condition: Choking Ash (choking_ash); stagger: 30.0}]}, Cinders and Fury {name: "Cinders and Fury"; at_health: 0.33; message: "It burns brighter as it breaks - and its cracked armour can no longer keep a stun out."; stagger: {hint: "It drains fast now: only a burst of damage in one round will stagger it."; max_value: 90.0; per_damage: 1.2; drain_per_round: 45.0}; clears_conditions: true; immunities_lost: [Stunned (stunned)]; summons: ["imp", "imp"]}]}; parts: [Ash Vents {name: "Ash Vents"; tiles: [(0, 0), (1, 0)]; health_share: 0.15; when_broken: Staggered; stagger: 60.0}]

### Barbarian (`barbarian`)

- Main stat Physical, secondary Self; health 102 at level 1, 265 at 64; movement 7
- Skills: Greatsword Attack, Follow Up Attack, Sweep Strike, Hurl, Grab, Run
- Settings: max_hp: 102; max_hp_level_20: 265; defense: 18; defense_level_64: 65; initiative: 3; skill_levels: { "follow_up_attack": 12, "sweep_strike": 3 }; resist_fire: -50; resist_earth: 50; ai_readies: Waits For The Hidden

### Behemoth (`behemoth`)

- Main stat Physical, secondary Mindfulness; health 120 at level 1, 700 at 64; movement 6
- Skills: Greatsword Attack, Ground Pound, Rockfall
- Settings: max_hp: 120; max_hp_level_20: 700; size: Monstrous; initiative: 3; parts: [Legs {name: "Legs"; tiles: [(0, 7), (1, 7), (2, 7), (3, 7), (4, 7), (5, 7), (6, 7), (7, 7)]; health_share: 0.2}, Tusks {name: "Tusks"; tiles: [(3, 0), (4, 0)]; health_share: 0.15; when_broken: Disarmed; disarms: ["ground_pound"]}, Soft Hide {name: "Soft Hide"; tiles: [(3, 3), (4, 3), (3, 4), (4, 4)]; health_share: 0.25; when_broken: Exposed}]

### The Bellkeeper (`bellkeeper`)

- Main stat Intellect, secondary Mindfulness; health 160 at level 1, 900 at 64; movement 7
- Skills: Fire Burst, Sass Club, Rockfall
- Settings: glossary_text: "Small, quick, and deaf to everything you throw at it. Nothing stuns, confuses, freezes or moves it. Only its own bells reach it."; max_hp: 160; max_hp_level_20: 900; size: Small; initiative: 5; immune_to_conditions: [Stunned (stunned), Confused (confused), Frozen (frozen), Crystallised (crystallised)]; immune_to: [0, 1, 2, 9]; turns_per_round: 2; boss: {title: "Keeper of the Silent Bells"; stagger: {hint: "Nothing you do to it fills this. Ring the bells."; per_damage: 0.0; turns_lost: 2}; phases: [The Last Toll {name: "The Last Toll"; message: "It tears the clapper from its own throat, and the floor itself begins to ring."; stagger: {hint: "The bells are spent. Strike it hard, all at once."; max_value: 80.0; drain_per_round: 40.0}; summons: ["rat", "rat", "rat"]; hazards: [{display_name: "The stones ring"; description: "The floor where the party stands rings like a struck bell - whoever starts a turn there is shaken by it."; kind: Ground; every_rounds: 2; count: 2; hits: The Party; damage: 12; damage_type: Lightning}]}]}; ai_function: "ai_caster"

### Bomber (`bomber`)

- Main stat Mindfulness, secondary Physical; health 28 at level 1, 85 at 64; movement 6
- Skills: Self Destruct, Run
- Settings: max_hp: 28; max_hp_level_20: 85; defense: 5; defense_level_64: 30; initiative: 3; resist_plasma: -50; resist_ice: -50; resist_lightning: -50; resist_metal: -50; resist_acid: -50; ai_function: "ai_hit_and_explode"

### Bound Beast (`bound_beast`)

- Main stat Physical, secondary Defense; health 70 at level 1, 200 at 64; movement 9
- Skills: Savage Bite, Run
- Settings: glossary_text: "A beast bound to a Summoner: it fights on its master's turn, recklessly, and is gone the moment its master is. Mended and empowered, it hits harder than a barbarian."; max_hp: 70; max_hp_level_20: 200; defense_level_64: 60; resist_fire: -25; resist_poison: 25

### Colossus (`colossus`)

- Main stat Physical, secondary Mindfulness; health 200 at level 1, 1200 at 64; movement 4
- Skills: Ground Pound, Rockfall
- Settings: max_hp: 200; max_hp_level_20: 1200; size: Gigantic; initiative: 3

### Erysichthon (`glutton`)

- Main stat Physical, secondary Mindfulness; health 300 at level 1, 2100 at 64; movement 7
- Skills: Ravenous Bite, Grab, Devour, Catch the Scent, Rending Claws
- Passive **Hollow Frame**: There is little left of it but bone and hunger. It folds itself to fit a gap - only the way the gap is too small: long and thin, tall and narrow, or down to a single tile - slowly, at twice the movement a step, and opens out again once there is room. [Folds itself a size narrower or shorter, or both, to fit where it is too big, at twice the movement a step.]
- Settings: glossary_text: "An undead wolf grown to an abomination, that never stops eating and is never full: whatever it swallows falls out through the hole in its belly. It catches the scent of its prey, grabs it, and swallows it whole - and it eats anything it finds in reach, even its own."; max_hp: 300; max_hp_level_20: 2100; size: Enormous; initiative: 4; resist_fire: -25; immune_to: [9, 10, 12]; boss: {title: "The Hunger That Ate Itself"; stagger: {hint: "Feed it what it should not eat, and hit it hard. Staggered, it heaves up whoever it has swallowed."; max_value: 150.0; per_damage: 0.6; per_blocked_condition: 15.0}; phases: [Gorge {name: "Gorge"; at_health: 0.66; message: "A second head tears its way out of its shoulder, snapping - now it can hold two."; parts_added: [Second Head {name: "Second Head"; tiles: [(2, 0), (3, 0), (2, 1), (3, 1)]; health_share: 0.1; when_broken: Weakened; regrows_after: 3; regrows_when_eating: true}]; holds_at_once: 2}, The Hollow {name: "The Hollow"; at_health: 0.33; message: "Its ribs split into mouths - and with nothing left in reach, it starts on itself."; skills_added: ["rib_maws"]; parts_added: [Rib Maws {name: "Rib Maws"; tiles: [(2, 2), (3, 2), (2, 3), (3, 3)]; health_share: 0.1; when_broken: Disarmed; disarms: ["rib_maws"]; regrows_after: 2; regrows_when_eating: true}]; eats_itself: 0.04}]; codex_second_page: "It never stops eating, and nothing it eats stays in it: there is a hole through its belly, gnawed by its own teeth. Whoever it swallows falls through that hole in the end - alive, if the hole is torn open first."}; parts: [Jaws {name: "Jaws"; tiles: [(0, 0), (1, 0), (2, 0), (3, 0), (0, 1), (1, 1), (2, 1), (3, 1)]; health_share: 0.12; when_broken: Disarmed; disarms: ["ravenous_bite", "devour"]; regrows_after: 3; regrows_when_eating: true}, Belly Hole {name: "Belly Hole"; tiles: [(0, 2), (1, 2), (0, 3), (1, 3)]; health_share: 0.1; when_broken: Exposed; regrows_after: 2; regrows_when_eating: true; frees_the_swallowed: true}, Hind Legs {name: "Hind Legs"; tiles: [(2, 2), (3, 2), (2, 3), (3, 3)]; health_share: 0.1; regrows_after: 3; regrows_when_eating: true}]; eats: Food On The Map|Its Own Fallen; meal_heals: 0.06; fed_effects: [{type: Stat Modifier; display_name: "Gorged"; stat: "physical"; modifier_amount: 4; duration: 3}]; spat_out_with: Bile-Soaked (bile_soaked); ai_function: "ai_glutton"

### Gnawer (`gnawer`)

- Main stat Physical, secondary Mindfulness; health 25 at level 1, 81 at 64; movement 7
- Skills: Ravenous Bite
- Settings: glossary_text: "A sewer rat that died and kept eating. They come in waves to the glutton's call - and it eats them too, when they fall."; max_hp: 25; max_hp_level_20: 81; defense: 5; defense_level_64: 30; size: Tiny; initiative: 3; immune_to: [9, 10]

### Stone Golem (`golem`)

- Main stat Physical, secondary Mindfulness; health 108 at level 1, 280 at 64; movement 4
- Skills: Greatsword Attack, Rockfall
- Settings: glossary_text: "Clay and stone with words cut into it, made to answer to whoever cut them. It feels nothing and fears nothing - but the words can be rewritten."; max_hp: 108; max_hp_level_20: 280; defense: 18; defense_level_64: 65; size: Enormous; initiative: 3; resist_earth: 50; immune_to_conditions: [Poisoned (poisoned)]; immune_to: [0, 9, 10, 11]; bound_to: "its master"; rebind_hack: golem_binding; rebind_turns: 3; parts: [Legs {name: "Legs"; tiles: [(0, 3), (1, 3), (2, 3), (3, 3)]; health_share: 0.25}, Arms {name: "Arms"; tiles: [(0, 1), (0, 2), (3, 1), (3, 2)]; health_share: 0.25; when_broken: Weakened}, Core Plate {name: "Core Plate"; tiles: [(1, 1), (2, 1), (1, 2), (2, 2)]; when_broken: Exposed}]

### Hired Bow (`hired_bow`)

- Main stat Physical, secondary Mindfulness; health 60 at level 1, 190 at 64; movement 7
- Skills: Nail Projectile, Venomous Shot, Run
- Settings: glossary_text: "An archer who fights for whoever pays, and runs the moment the pay stops being worth it."; class_t: Ranged; max_hp: 60; max_hp_level_20: 190; defense_level_64: 60; initiative: 4; nerve: 40; when_fled: Comes back; brings_back: ["sellsword"]; fled_flag: "hired_bow_got_away"; bribe_price: 40; leverage_clues: ["sellsword_contract"]; interrogation_gold: 20; ai_function: "ai_ranger"; ai_readies: Covers The Approach

### Illusory Dragon (`illusory_dragon`)

- Main stat Intellect, secondary Self; health 100 at level 1, 400 at 64; movement 18
- Skills: Fire Breath, Frost Breath, Lightning Breath, Venom Breath, Acid Breath, Dread Breath
- Passive **Dread Presence**: Whoever of the other side is within four tiles of it - when it appears, or as a turn of theirs begins - is gripped by fear of it, unless their Mindfulness is a match for its caster's Intellect. [Aura: the other side within 4 tiles are fear, unless their Mindfulness beats its Intellect.]
- Settings: glossary_text: "A dragon of shadow, called out of the Ogdoad by its caster's mind and held there on a tether to them. It stands where it stands like a living thing, but every blow misses it and nothing harms it - and it is as strong as whoever called it."; class_t: Magic; class_m: Flying; max_hp: 100; max_hp_level_20: 400; size: Large; untouchable: true

### Imp (`imp`)

- Main stat Intellect, secondary Mindfulness; health 26 at level 1, 82 at 64; movement 7
- Skills: Fire Burst, Sass Club
- Settings: max_hp: 26; max_hp_level_20: 82; defense: 5; defense_level_64: 30; size: Small; initiative: 3

### Kindled Hound (`kindled_hound`)

- Main stat Physical, secondary Mindfulness; health 18 at level 1, 110 at 64; movement 9
- Skills: Kindled Bite, Run
- Settings: glossary_text: "A hound of embers that Prometheus calls up and holds on a tether. It bites with fire, and goes out when the tether snaps."; max_hp: 18; max_hp_level_20: 110; resist_fire: 100; resist_water: -50

### Mimic (`mimic`)

- Main stat Self, secondary Mindfulness; health 62 at level 1, 190 at 64; movement 7
- Skills: 
- Passive **Mimicry**: Does whatever your party did last: the last skill any of you used, turned on you - or on its own side, if it was meant for allies. It cannot copy Run, Slip Past or Study, and copies whatever came before them instead. Until one of you has done something it can copy, it waits. It opens no gates and needs none, so a copied spell is cast however deep a gate it calls for. Whatever it copies is worked out from its Self, not the stat the skill would usually use. [Casts without opening a gate, however deep a gate the spell calls for. Every skill scales with Self, whatever stat the skill itself names.]
- Settings: max_hp: 62; max_hp_level_20: 190; defense_level_64: 60; initiative: 4; resist_water: -50; resist_wind: 50; ai_function: "ai_copycat"

### Ogre (`ogre`)

- Main stat Physical, secondary Mindfulness; health 100 at level 1, 262 at 64; movement 6
- Skills: Greatsword Attack, Ground Pound
- Settings: max_hp: 100; max_hp_level_20: 262; defense: 18; defense_level_64: 65; size: Large; initiative: 3

### Pit Champion (`pit_champion`)

- Main stat Physical, secondary Self; health 108 at level 1, 280 at 64; movement 6
- Skills: Greatsword Attack, Follow Up Attack, Hurl, Run
- Passive **Hemmed In**: Nobody walks past a champion of the pits for free: every tile within two of them costs the other side twice the movement. [Tiles within 2 of them cost the other side twice the movement.]
- Passive **Exposed**: Turn away from a champion at your peril: anybody of the other side who ends a turn within two tiles of them without hurting them is Exposed - a fifth more from the champion until their next turn. [Anybody of the other side ending a turn within 2 of them without hurting them is exposed.]
- Settings: glossary_text: "A fighter of the pits who has never once let anybody walk past them to somebody easier. Stand near and you fight them, or pay for it."; max_hp: 108; max_hp_level_20: 280; defense: 18; defense_level_64: 65; initiative: 4; skill_levels: { "follow_up_attack": 12 }; resist_physical: 20; leads: true; leverage_clues: ["sellsword_contract"]

### Priest (`priest`)

- Main stat Mindfulness, secondary Self; health 60 at level 1, 190 at 64; movement 6
- Skills: Rapier, Water Spike, Heal, Cleanse, River Flow, Communion, Run
- Settings: class_t: Magic; max_hp: 60; max_hp_level_20: 190; defense_level_64: 60; initiative: 3; spellcasting_stat: Mindfulness; skill_levels: { "river_flow": 7 }; resist_water: 50; resist_earth: -50; ai_function: "ai_healer"

### Ranger (`ranger`)

- Main stat Physical, secondary Mindfulness; health 60 at level 1, 190 at 64; movement 7
- Skills: Heal, Nail Projectile, Venomous Shot, Flammable Limb, Run
- Settings: class_t: Ranged; max_hp: 60; max_hp_level_20: 190; defense_level_64: 60; initiative: 4; spellcasting_stat: Mindfulness; half_caster: true; resist_wind: -50; resist_poison: 50; ai_function: "ai_ranger"; ai_readies: Covers The Approach|Waits For The Hidden

### Rat (`rat`)

- Main stat Physical, secondary Mindfulness; health 25 at level 1, 81 at 64; movement 7
- Skills: Sass Club
- Settings: max_hp: 25; max_hp_level_20: 81; defense: 5; defense_level_64: 30; size: Tiny; initiative: 3; ai_readies: Guards Its Post

### Sellsword (`sellsword`)

- Main stat Physical, secondary Self; health 75 at level 1, 200 at 64; movement 7
- Skills: Greatsword Attack, Hurl, Run
- Settings: glossary_text: "A blade for hire. Loyal to the purse - anybody's purse."; max_hp: 75; max_hp_level_20: 200; defense_level_64: 60; initiative: 3; nerve: 50; when_broken: Surrenders; bribe_price: 50; leverage_clues: ["sellsword_contract"]; interrogation_clues: ["sellsword_contract"]; interrogation_gold: 30

### Sorcerer (`sorcerer`)

- Main stat Intellect, secondary Mindfulness; health 28 at level 1, 85 at 64; movement 6
- Skills: Burner, Fireball, Crystalise, Gust Blast, Wind Swoon, Run, Fire Burst, Fire Blast, Rock Throw, Wind Shot
- Settings: class_t: Magic; max_hp: 28; max_hp_level_20: 85; defense: 5; defense_level_64: 30; initiative: 4; skill_levels: { "burner": 5, "crystalise": 7, "gust_blast": 6, "wind_swoon": 6 }; resist_fire: 50; resist_poison: -50; ai_function: "ai_caster"; ai_readies: Counters Casters

### Summoner (`summoner`)

- Main stat Mindfulness, secondary Intellect; health 27 at level 1, 84 at 64; movement 6
- Skills: Mend the Bound, Empower the Bound, Call the Bound, Water Spike, Run
- Settings: glossary_text: "Frailer even than a sorcerer, and it knows it: it keeps out of reach and lets its Bound Beast do the fighting - mending it, empowering it, and sending it in. Fell the Summoner and the beast goes with it."; class_t: Magic; max_hp: 27; max_hp_level_20: 84; defense: 5; defense_level_64: 30; initiative: 4; spellcasting_stat: Mindfulness; resist_poison: -25; summon_at_start: "bound_beast"; ai_function: "ai_summoner"

## Things on the map (objects)

### Meat-Wrapped Keg (`bait_keg`)

- Settings: breakable: true; edible: true; nourishing: false; eaten_damage: 140; eaten_damage_type: Fire; eaten_condition: Burn (burn); eaten_stagger: 50.0; eaten_breaks: "Belly Hole"; set_off_line: "The meat-wrapped keg goes up!"; stagger: 20.0; blast_radius: 1; blast_damage: 40; blast_damage_type: Fire; blast_condition: Burn (burn); glossary_text: "A powder keg bound up in raw meat. Swallowed, it goes off inside whatever swallowed it - tearing its belly open from within. Light it, or break it, and it goes up where it stands like any keg."; max_hp: 20; max_hp_level_20: 20

### Bell (`bell`)

- Settings: set_off_line: "The bell tolls!"; stagger: 40.0; blast_radius: 2; blast_condition: Deafened (deafened); blast_hits: The Enemies; glossary_text: "An old iron bell. Use it from beside it: its toll staggers the Bellkeeper, and leaves its own side deafened. It rings once."; max_hp: 10; max_hp_level_20: 10

### Carrion Heap (`carrion_heap`)

- Settings: used_becomes: Tainted Carrion (tainted_carrion); edible: true; glossary_text: "Something that died down here a while ago. Whatever eats it is fed - healed, and grows back what it lost. Use it from beside it to taint it first."; max_hp: 20; max_hp_level_20: 20

### Illusory Cover (`illusory_cover`)

- Settings: interactable: false; breakable: true; lasts_turns: 3; illusion: true; glossary_text: "Cover that is not there: Alithia's illusion of a barricade. The other side takes it for the real thing - it blocks their sight and they plan around it - but shots and blasts go straight through it. It fades after three of her turns."; max_hp_level_20: 1

### Powder Keg (`powder_keg`)

- Settings: breakable: true; set_off_line: "The powder keg goes up!"; stagger: 25.0; blast_radius: 1; blast_damage: 40; blast_damage_type: Fire; blast_condition: Burn (burn); glossary_text: "A barrel of black powder. Light it from beside it, or hit it: it goes up, burning everyone around it - the Warden too, which staggers it."; max_hp: 20; max_hp_level_20: 20

### Tainted Carrion (`tainted_carrion`)

- Settings: interactable: false; edible: true; nourishing: false; eaten_damage: 90; eaten_condition: Poisoned (poisoned); eaten_condition_turns: 3; eaten_stagger: 30.0; glossary_text: "A heap of carrion, gone bad on purpose. Whatever eats it is poisoned, and reels - and is fed nothing by it."; max_hp: 20; max_hp_level_20: 20

---

# Part 4 - The designer's decisions, and what is still open

## Standing decisions

These are settled; suggestions should work within them.

**Numbers and progression**

- **The numbers are the designer's.** Most are placeholders until playtesting. Weigh a suggestion against the progression plan's power level: tiers at 1/8/16/24/32/41/54/64, and the multipliers in Part 2.
- **No cooldowns, ever.** Limits come from gates, Uses Per Short Rest, Needs Read, and placement (Only Below Health went with Finisher, 2026-10-25).
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
- **Repacking between fights:** the rest screen of the Dungeon Demo and the lab has an Inventory button (and the inventory key), which opens the party's bags as on a map: move items between belt, pouch and backpack, and from one member to another, before the next fight (the designer, 2026-10-25).
- **Not decided:** whether a short rest ends conditions; where the long rests fall; whether a rest called from a conversation should open the rest screen, so Meditate and Resuscitate can be chosen there (OPEN).

## The condition and DoT proposal (2026-10-25; implemented as PROPOSAL test values)

Perplexity's proposal (`docs/perplexity_condition_dot_proposal.md`); the designer said to go with it. As the proposal asks, every value is logged PROPOSAL, not APPROVED_TRIAL.

- **Conditions last 5 turns:** Burn, Poisoned, Frozen, Crystallised, Windswept and Corroded, and every move the proposal names inflicts them for 5. Their rules are kept: Burn's +2 movement, Poisoned's no reactions, Frozen's -2 and no secondary action, Crystallised's no movement, Windswept's -3 and 3-tile drift, Corroded's -10% Defense.
- **Base DoT ranges** (`dot_min`-`dot_max`): Burn 4-5 (was 6-8), Poisoned 3-4 (4-6), Frozen 1-3 (1-2), Crystallised 1-3 (2-4), Windswept 1-2 (1-3), Corroded 1-2 (none).
  - In the game these ranges are only what a tick rolls when an **item** inflicts the condition (the bottles). A **skill's** tick is the caster's power times the move's own dial. That is where the proposal's per-move dials below act.
- **Hermes spells, single target:**
  - Burner x1.7, Burn 0.25 (was radius 2, x1.4, 3 turns at 0.2).
  - River Flow x1.4, Frozen 0.20 (radius 2, x1.3, 2 turns at 0.2).
  - Wind Swoon x1.0, Windswept 0.10 (radius 2, x0.8, 2 turns at 0.1).
  - Crystalise x1.0, Crystallised 0.10 (radius 2, x0.8, 3 turns at 0.1). The Crystalise Gate Nade copies it.
- **Pandora spells, still radius 2:** Wildfire x2.1, Burn 0.35 (was 0.4). Frozen River x1.8, Frozen 0.30 (was 0.25).
- **Gust Blast:** Windswept 0.10 (was 2 turns at 0.15); the shove unchanged.
- **Cyrus's ammunition stays as it was.** The proposal changed it, but the non-spell handoff of the same day (below) puts it back, and the designer pointed to it: Burning Shot x0.8, Burn 0.35 for 3 turns, and x0.95, 0.45 at 32 (under the Gun); Poison Dart x0.9, Poison 0.2 for 3; Venom Fan x0.7, Poison 0.2 for 3. Corrosive Round, which the handoff does not list, keeps the proposal's 5 turns of Corroded.
- **The enemies follow the new spells** (the designer, 2026-10-25). The Sorcerer and the Priest cast the party's Burner, Wind Swoon, Crystalise, Gust Blast and River Flow, so theirs are single target and last 5 turns too.
- **Left as they were:** Catalyst; immunities; Frozen has no Defense loss; the bottles, Glacial Tide, Flame Edge and Trailblaze; the enemies' own moves (Flammable Limb, Venomous Shot). Erysichthon's Tainted Carrion poisons for the Poisoned condition's own length, which went from 3 to 5; it is pinned at 3 (OPEN: whether it should follow too).
- **Ledger status:** PROPOSAL until the designer has tried them.
- **To watch in testing** (from the proposal):
  - whether Burn stays the strongest DoT, and Poison the best set-up for a decisive party turn;
  - whether Frozen is useful without being a universal answer;
  - whether Crystalise contains melee threats without trivialising them;
  - whether Windswept is worth its displacement, and Corroded before a focus-fire turn;
  - whether the Gun stays a real choice;
  - whether the Hermes single-target spells feel stronger per target than the Pandora areas.

## Finisher removed; Momentum and Sweep Strike; the non-spell moves (2026-10-25; implemented)

The designer's handoff, `docs/handoff_0.1/finisher_removal_momentum_synergy.md` (APPROVED_DESIGN / APPROVED_TRIAL).

- **Finisher is gone:** the skill, Enfina's kit entry and the progression row. Titanfall at 64 (x3.0 with a x1.5 splash, no health limit) outpaced it.
  - The Only Below Health limit, which only Finisher used, went with it. Its icon (`art/icons/finisher_skill.png`) is left unused.
- **Momentum covers Sweep Strike.** It already did: Momentum adds to every blow on a turn Enfina has not walked, the whole sweep included, so no code changed. Its description now says so, and a test holds it.
  - At 54, planted, Sweep Strike is x1.54.
  - It does not touch Leading Charge, which needs a walk.
  - The enemies' Sweep Strike (Barbarian, Pit Champion) gets nothing: Momentum is Enfina's passive.
- **Momentum at 64:** Momentum II now adds 5% to Momentum I's 10% (Passive ranks, below), so a planted Sweep Strike is x1.61, as the handoff says.
- **The non-spell table, audited.** Every Enfina and Cyrus non-spell move matches it, once Cyrus's ammunition was put back. Three lines of the table describe the game differently. The table says "unchanged", so the game is kept as it is:
  - Titanfall has no shove: Tremor became the control layer on 2026-10-24.
  - Catalyst is once a short rest (2026-10-24), not once a fight.
  - Momentum at 64 was x1.75; it is x1.61 now, Momentum II adding 5% (Passive ranks, below).

## Passive ranks (2026-10-25; implemented)

The designer: a passive's ranks are one passive. This holds for every passive sharing a name but for the numeral.

- **The numbers add.** Each rank adds to the ones before, as separate passives always did. (For a few hours the same day a higher rank replaced the lower's numbers; the designer chose adding.)
- **Only the highest unlocked rank shows** on the character sheet. Its description gives the totals, the lower ranks' effects included: Mercy I "+10% healing" and a rank adding 5% would show only the second rank, saying 15%. Every rank II and III description is written that way now.
- **Momentum II adds 5%** to Momentum I's 10%, shown as fifteen hundredths, so a planted Sweep Strike at 64 is x1.61, as the handoff says. It added 15% before, 25% in all. This is a PROPOSAL test value.
- **Everything else plays as before:**
  - Iron Hide 20%; DoT Master 30% and a turn longer; Kindling up to 45%; Reserved Power two more castings.
  - Bulwark: a tenth less within two tiles, a fifth beside her.
  - Aura: Blessed and Soothed both.

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
   - River Flow (8, Hermes): single target, x1.4, Frozen 5 turns at 0.20 (was radius 2, x1.3, 2 turns at 0.2).
   - Frozen River (16, Pandora): radius 2, x1.8, Frozen 5 turns at 0.30 (was 3 turns at 0.25).
   - Glacial Tide (41, Sophia): radius 3, x2.2, Frozen 2 turns at 0.25.
7. **The Burn line:**
   - Burner (8, Hermes): single target, x1.7, Burn 5 turns at 0.25 (was radius 2, x1.4, 3 turns at 0.2).
   - Wildfire (16, Pandora): radius 2, x2.1, Burn 5 turns at 0.35 (was 3 turns at 0.4).
   - Fireball (9, Pandora) is close in power: radius 5, x2.0, hits both sides.
8. **Wind Swoon and Gust Blast:**
   - Wind Swoon (8, Hermes): single target, x1.0, Windswept 5 turns at 0.10 (was radius 2, x0.8).
   - Gust Blast (24, Hermes): single target, x1.2, a 3-tile shove, Windswept 5 turns at 0.10.
   - Both single target now, they differ by the shove and the gate's level.
9. **Communion and Revitalizer** - settled: Revitalizer was taken out and Communion took its place (Alithia's kit, the Priest's, and the Gate Nade). Revitalizer was heal x1.3, radius 3, range 20 from level 9; Communion is x0.6, radius 2, range 10 from 16. Alithia now has no group heal before 16, and neither do Priests below 16.
10. **Heal and Light Heal** (World): Light Heal is a smaller Heal, but a secondary action.
11. **Hermes Step and Mist Step** (Hermes, a 6-tile teleport): Hermes Step moves an ally, as a main action. Mist Step moves himself, as a secondary action.
12. **The four Edges** (Elemental Vanguard melee spells), in two pairs:
   - Flame and Frost (Pandora, x1.8): Burn, or -2 movement.
   - Storm and Stone (Charon, x2.2): a 2-tile shove, or -10 defence.

Also: since spells stopped ranking up, the enemy Sorcerer and Priest no longer get the stronger version of Burner and River Flow past level 16. They cast the level-8 versions at any level - since 2026-10-25 the single-target ones, as the party does.

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
