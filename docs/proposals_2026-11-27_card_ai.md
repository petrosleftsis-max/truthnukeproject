# The card game's enemies: a more interesting AI - proposals, 2026-11-27

## Chosen, and built (2026-11-27)

The designer: "Do them all, don't do any twists yet. Thank you for the report, I'll make cards according to them on a later date".
All 22 are built (`docs/card_game.md` "How enemies choose"; suite `cards`, sections "how enemies choose" to "the enemies as
made"), none of the world's twists: item 20's hidden intent is a plain trait of an enemy's (Shows: Once Hit or Nothing), not
twist 6's light and dark. Every name and number is a placeholder (PROPOSAL); the pictures and sounds are slots with stand-ins.

| Item | How it is built |
|---|---|
| 1 Opening move | A move's First |
| 2 Limits | A move's Not Twice Running, Most Times, Not Before Turn, Cooldown; and Rule Only (never the pattern's) |
| 3 Countdown | A move's Wind Up: its intent shows the turns (2, 1) and it does nothing else until it lands |
| 4 Phases | `CardEnemyPhase`: under a share of health, once; its line, statuses, Block, throwing off harm, new moves, pattern and rules |
| 5 Rules | `CardEnemyRule`: When (13 kinds), Number, Status, Move, From Tier; checked in order before the pattern |
| 6 Leaning | A move's Lean When, Number, Status and Factor |
| 7 Honest | The intent is decided as its turn ends and kept; only Reactive, waking and curling up change it, with a "!" |
| 8-13 Traits | Statuses: Enrage, Curiosity, Overtime, Toll, Reactive, Asleep (with Sleep Block), Mode Shift (Curl Block, Spines, Turns, Grows) |
| 14 Junk cards | Status cards Wound, Dazed, Slimed, Burn; a move's Adds Card, count and pile (draw, discard, hand) |
| 15 The hand | Entangled and Confused (statuses on the player); a move's Steals (from the draw pile, as the hand is empty on the enemies' turn), given back into the hand as it falls |
| 16 Roles | A move's Helps (itself, the worst hurt ally, everybody) and Heal; Command and Pack (traits) |
| 17 More of them | A move's Summons (while fewer than 4 stand); a phase's Splits Into |
| 18 Linked | Trait: rises with half health so many turns later, unless all the Linked are down |
| 19 Bosses | Invincible (trait); the Colossus has Mode Shift and a second phase (Invincible 30, a Crush that counts down) |
| 20 Hidden intent | An enemy's Shows: Nothing, or Once Hit |
| 21 Two ahead | Second Sight (an uncommon relic): the plan after each intent, dimmed |
| 22 By tier | A rule's From Tier; the run's Challenge (0 to 3, the top bar's button before the first room) |

The ten enemies there were got rules, limits and traits, and nine new ones came in eight new fights, to show it all: see
`docs/card_game.md` "How enemies choose". One rule changed along the way: enemies' Block now goes for all of them as their turn
begins, so Block one gives another lasts until their next turn (it went as each one's own turn began).

The designer, 2026-11-27: "Do you have suggestions on how to make the ai in the card game more interesting? Also let me know the
decks and playstyles that exist in slay the spire since I can't play it yet".

Nothing here is built. Sizes are relative (**S** small, **M** a good piece, **L** the biggest here); every number is PROPOSAL.
These are rules for how enemies choose and act, not twists of the world: where one touches a twist still waiting in
`docs/proposals_2026-11-26_card_game.md`, it says so.

## How they decide now

Each enemy (`data/card_enemies/`) has a list of moves, and a pattern: **in order**, round and round (the Bomber, the Ogre, the
Colossus...), or **at random by weight**, never the same move three times running (the Rat, the Sellsword...). Its next move is
picked at the end of its turn and shown as its intent (`CardBattle._pick_move`). Nothing it does depends on how the fight is
going: not its own health, not the player's Block or health, not its allies, not what the player plays.

That is how the genre starts, and the one rule to keep is that **an intent is honest**: the player sees what comes next and plans
around it. Slay the Spire's enemies are not clever, they are *scripted*, and the interest comes from how varied the scripts are
and from rules that ask questions of the player's deck. Everything below keeps that.

---

## 1. Scripts with a personality (data only)

1. **An opening move.** A move marked First is always its first turn: an enemy introduces itself (Slay the Spire's Cultist
   chants before it ever attacks; the Gremlin Nob bellows). **S**
2. **Limits on a move.** Per move: not twice running, at most once a fight, not before turn N, or every Nth turn (a cooldown). A
   heal once a fight, a big hit every third turn. **S**
3. **A countdown.** An intent that counts down over a few turns (3, 2, 1) to something huge. The player races it, braces for it,
   or kills it first (the Exploder, the Transient, the Giant Head's "It Is Time"). The Bomber's Light the Fuse already does this in
   one step. **S**
4. **Phases.** At a share of its health (half, say), an enemy switches to another move list or pattern, with a line and a pulse:
   the Colossus getting up angrier (the Champ's anger at half health, the Slime Boss splitting, the Awakened One's second form).
   **M**

## 2. Reading the fight

5. **Rules before the pattern.** Each enemy can have a short list of "if this, do that", checked in order every time it picks;
   if none holds, its pattern picks as now. What a rule can ask: its own health under a share; the player's Block, health or a
   status; an ally hurt, fallen or alone; the turn number. The Alchemist drinks when it is under half health; the Sellsword
   taunts a player behind a wall of Block; the Priest blesses whichever ally is worst hurt. One small resource per rule
   (condition, number, move), edited in the inspector like the moves. **M**
6. **Weights that lean.** Gentler than a rule: a move's weight is multiplied while something holds (Drink three times as likely
   under half health). It stays readable without becoming certain. **S**
7. **Still honest.** Whatever 5 and 6 decide is decided as the enemy's turn ends and shown as its intent, so the player can still
   plan; a rule never changes a move already shown, except where an enemy says so itself (11). **S**

## 3. Punishing how you play (traits)

Each is a status-like trait an enemy starts with, shown as a badge with its words, so the player sees the rule.

8. **Enrage.** Gains Might whenever the player plays a Skill: a defensive turn costs (the Gremlin Nob). **S**
9. **Curiosity.** Gains Might whenever the player plays a Power: a fight against a deck that sets up (the Awakened One). **S**
10. **Overtime.** After the player plays N cards in a turn, the turn ends; or every card played costs the player a little health.
    It punishes long combo turns (the Time Eater, the Heart). **S**
11. **Reactive.** Its intent changes whenever an attack hits it: nothing to plan around but killing it (the Writhing Mass). **S**
12. **Asleep.** It starts asleep, gaining Block each turn, and wakes when hit or after three turns: set up while it sleeps, or
    wake it on your own terms (the Lagavulin). **S**
13. **Mode shift.** After taking N damage it curls up for two turns, with Block and Spines, then the threshold grows: plan your
    big turns around it (the Guardian). **M**

## 4. Into the deck

14. **Junk cards.** Enemies shuffle cards into the player's piles: Wound (cannot be played), Dazed (cannot be played, gone at the
    end of the turn), Slimed (costs 1 to play, then exhausts), Burn (hurts at the end of the turn if still in hand). The enemy's
    identity reaches into the player's own deck, and exhaust and draw cards are worth more (the Sentries, the Hexaghost, the
    Acid Slime). **M**
15. **The hand.** Entangled: no Attacks next turn. Confused: costs drawn at random. Or a card taken out of the hand, given back
    when its taker falls (the Red Slaver, the Snecko, the Bronze Automaton's orbs). **M**

## 5. Teams

16. **Roles.** One that shields or heals whichever ally is worst off; a leader who buffs the rest while it stands; a pack that
    gains Might whenever one of them falls (the Mystic healing the Centurion, the Shield Gremlin, the Gremlin Leader). Which to
    kill first becomes the question. **M**
17. **More of them.** Calling help when left alone, or splitting into two smaller at half health (the Gremlin Leader, the
    Reptomancer's daggers, the slimes). **M**
18. **Linked.** One that falls rises again a couple of turns later, unless all of them are down: spread the damage, then
    finish them together (the Darklings). **S**

## 6. Bosses that test the deck

19. **One question each.** A boss's rule asks something of the deck the player built: a hit too big to block every few turns
    (out-race it or out-block it); no more than N damage a turn (it beats burst, needs scaling: the Heart's Invincible); Might
    every turn (it needs speed); a punishing answer to one kind of card (8, 9). With phases (4), the Colossus could have two of
    these. **L**

## 7. Not knowing, sparingly

20. **A hidden intent.** A few enemies show the unknown intent (it has a picture slot already), or show theirs only once hit. It
    overlaps twist 6, light and dark, so it may be better to wait for that decision. **S**
21. **Two moves ahead.** A relic or card that shows each enemy's next two moves: a reward for a deck built around reading them. **S**

## 8. The difficulty

22. **Smarter by tier.** Easy fights play plain patterns; hard fights and elites add rules (5) and a trait (3); bosses add phases
    (4) and their question (19). A run setting (Slay the Spire's Ascension) could raise it: harder weights, more health, one more
    rule each. **S**

---

## My pick

**1, 2, 4 and 5**, then **14**. The first three make every enemy a personality with data alone; rules (5) make them answer the
fight; junk cards (14) make the enemies touch the player's deck, which is where a deckbuilder's decisions live. Then a trait for
each elite (8, 12 or 13), **16** for the mixed fights, and **19** for the Colossus.

## Questions

1. **Which of these, and for which enemies?** Or "all", as for the juice.
2. **Junk cards:** which of the four, and do they need art (each would get a picture slot)?
3. **Hidden intents:** now, or with light and dark (twist 6)?

---

## Slay the Spire's decks and playstyles, for reference

Slay the Spire (2019) has four characters. Each has a starter deck of Strikes and Defends and a few signature cards, and a run
picks up cards that pull it toward one or two **archetypes**: an *engine* of enablers and a *payoff* that wins with them. Relics
often decide which one a run becomes.

### The Ironclad (a warrior, the most health, heals after each fight)

- **Strength.** Inflame, Spot Weakness, Demon Form and Limit Break stack Strength, which every hit adds; Heavy Blade, Twin
  Strike, Sword Boomerang and Whirlwind cash it in, Reaper heals with it. Slow start, unstoppable later.
- **Exhaust.** Corruption makes Skills free but gone once played; Feel No Pain (Block on exhaust) and Dark Embrace (a draw on
  exhaust) turn that into an engine; Fiend Fire, Second Wind, Burning Pact feed it. With the Dead Branch relic it can run forever.
- **Block.** Barricade keeps Block from one turn to the next, Entrench doubles it, Body Slam hits for it, Juggernaut deals damage
  whenever Block is gained. A wall that becomes a weapon.
- **Self-harm.** Rupture gives Strength whenever his own cards cost him health (Offering, Bloodletting, Hemokinesis, Combust);
  Reaper and his healing pay it back. High risk, high pace.
- **Status cards.** Some of his cards put Wounds and Dazed into his deck; Evolve (a draw for each) and Fire Breathing (damage for
  each) turn the junk into fuel.

### The Silent (a rogue, nimble, draws more on the first turn)

- **Poison.** Deadly Poison, Noxious Fumes, Bouncing Flask and Crippling Cloud stack it; Catalyst doubles (upgraded, triples) it;
  Corpse Explosion turns one death into a blow on all the others. Wins by defending while the enemies wither. Best against bosses.
- **Shivs.** Blade Dance, Cloak and Dagger and Infinite Blades make free 4-damage knives; Accuracy makes each hit harder; After
  Image (Block per card played), Kunai and Shuriken (Dexterity and Strength every few attacks) reward playing many cards.
- **Discard.** Cards that pay off when discarded (Reflex draws, Tactician gives energy), cards that discard (Acrobatics,
  Prepared, Calculated Gamble, Tools of the Trade), Eviscerate getting cheaper with each discard. A deck that cycles fast.
- **Dexterity and evasion.** Footwork makes every Block card give more, Blur keeps Block into the next turn, and Wraith Form
  makes her nearly untouchable for a while. Survive anything, then finish.

### The Defect (an automaton with orbs)

- **Orbs.** Each turn's spells "channel" orbs into slots: Lightning (hits at the end of the turn), Frost (Block each turn), Dark
  (charges a big hit), Plasma (energy). **Focus** makes every orb stronger, so the archetypes are about which orbs and how much
  Focus (Defragment, Biased Cognition, Consume).
- **Frost.** Glacier, Coolheaded and Loop: a turtle that blocks forever while something else deals the damage.
- **Lightning.** Ball Lightning, Storm and Electrodynamics (every Lightning hits every enemy), Thunder Strike to finish.
- **Claw.** Claw costs nothing and makes every Claw stronger each time one is played; All for One brings every free card back
  from the discard pile; Scrape and FTL draw. A deck of many tiny free cards.
- **Powers.** Creative AI, Echo Form (the first card each turn is played twice), Storm, Heatsinks, Machine Learning: a slow set-up
  that snowballs.

### The Watcher (a monk with stances)

- **Stances.** Wrath doubles the damage she deals *and* takes, Calm gives energy when she leaves it, Divinity triples her damage.
  The core is "stance dancing": into Wrath to hit, out to Calm to be safe (Eruption, Vigilance, Tantrum, Inner Peace, Fear No
  Evil), with Mental Fortress (Block on each change) and Rushdown (a draw entering Wrath) paying for every switch.
- **Mantra.** Prostrate, Worship, Pray and Devotion build Mantra; at 10 she enters Divinity for a turn of enormous damage.
- **Scry and Retain.** Scry looks at the top of the draw pile and throws away what is not wanted (Third Eye, Cut Through Fate,
  Nirvana, Weave); Retain keeps cards from turn to turn (Establishment, Windmill Strike, Perseverance) to build one huge turn.
- **Pressure Points.** Marks that hurt all at once when triggered: a small, odd poison of her own.

### Across all four

- **Scaling or front-loaded.** Every deck must answer "how do I win a long fight" (Strength, Poison, Focus, Block that lasts) and
  "how do I survive the first turns" (cheap damage, Block). Boss fights test the first; hallway fights the second.
- **Thin decks.** Removing Strikes and Defends at shops so the best cards come round every turn. Many winning decks are small.
- **Infinites.** A deck thinned to a handful of cards that pay for and draw each other, played round and round in one turn: the
  fight ends there. The rarest and strongest way to win.
- **Relics shape runs.** Snecko Eye (draw more, costs at random), Dead Branch (a random card for each exhausted one), Kunai and
  Shuriken (rewards for many attacks), Runic Pyramid (keep the hand), and the energy relics that come with a curse or a cost.
- **What enemies ask.** The Gremlin Nob punishes Skills, the Lagavulin rewards setting up, the Sentries fill the deck with Dazed,
  the Time Eater stops long turns, the Heart caps damage per turn: every elite and boss checks one weakness of a deck, which is
  why section 3 and 6 above are where most of the AI's interest is.
