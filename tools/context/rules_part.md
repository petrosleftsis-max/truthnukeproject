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
