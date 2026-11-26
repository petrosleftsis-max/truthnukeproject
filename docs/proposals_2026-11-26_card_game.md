# A card game in the spirit of Slay the Spire - proposals, 2026-11-26

The designer, 2026-11-26: "I would like to add a card game that is like a Slay the Spire type of game. Suggest ways we can then
personalise it for this project or give it a unique twist."

Nothing here is built. Section 1 is where it could live, section 2 the baseline everyone knows, section 3 the twists that make it
this game's own (each with why it fits and a rough size), section 4 my pick, section 5 what is already in the game to build it
from, and section 6 the questions that decide it.

---

## 1. Where it lives

**1a. A mode of its own, "The Ascent" (my pick).** On the title screen beside Arena Mode and the demos: a run of card fights up
a branching map, with the party, their moves and the enemies of the main game. It touches nothing in the story or the tactics
fights, so it can be built and tried on its own, and taken out again if it does not work.

**1b. A game inside the world.** The people of the Dome play a card game with Idol cards in taverns and chapels (a Gwent or Triple
Triad of this world). Smaller, and it adds life to the maps, but it is a side game, not a run.

**1c. The dungeon run, played in cards.** The run of `docs/proposals_2026-11-20_dungeon.md` as a deckbuilder instead of grid fights.
It would replace the tactics, which are the heart of the game, so I would not start here.

A framing for 1a that the story already has room for: **a dream.** The dream map exists (DreamZone, DreamWake); a run could be
the party dreaming the climb to the top of the Dome, which excuses everything a card game does that the world does not (a hand,
a draw, a deck that changes overnight).

---

## 2. The baseline (what "Slay the Spire type" means)

- A run: a branching map of fights, elites, rests, shops and events, three acts, a boss at the end of each.
- A deck that grows: a few cards to choose from after each fight; cards can be upgraded and removed.
- A fight: draw five, spend energy (three a turn), block, attack, buffs and debuffs; the enemies show what they will do next
  (intents).
- Relics: lasting boons with odd rules, found along the way.
- Losing ends the run; winning unlocks more.

Every twist below keeps this skeleton.

---

## 3. Twists that make it ours

Sizes: **S** a few days, **M** a week or two, **L** more. All of it PROPOSAL.

### The world

1. **Climb to the Dome's ceiling.** The map is a sky of stars climbing toward the top of the Dome, and the higher the party goes the
   more the sky comes apart into pixels, until the last act is played behind it. The story's central image becomes the run's shape.
   **S** (it is art and a shader the game already has).

2. **Gates are the energy.** Instead of three energy a turn, the gates: World at the start, a deeper one opened each act (Hermes,
   Pandora, Charon...). A card's cost is the gate it is cast through, so the run itself is the climb through the gates the story
   names, and the strongest cards cannot be played until their gate opens. **M**

3. **The Dome is watching.** A meter for the whole run. Casting through a gate for the first time ("ENTRY RECORDED. PROCEED." - the
   GateVoice lines), lying and the strongest cards raise it; stealth lowers it. At each threshold the Dome answers: harder fights,
   inquisitors of the Holy Order, and struck-out cards in the deck (below). Pushing your luck, in the game's own terms. **M**

4. **Struck-out cards.** Some cards come with words crossed out, like Prometheus's notes: you do not know all they do until you play
   one, or Alithia reveals it. The 2026-11-19 proposals' struck-out words, as a mechanic. **S** once there are cards.

### The party

5. **Four characters, four suits.** The deck is the party's, every card belonging to one of them, drawn with the icons the artist
   has already painted for their moves:
   - **Cyrus:** poison, burn, ammunition, stealth, and Steal, which takes the card an enemy is about to play.
   - **Enfina:** block, Guard, Grab and Hurl, and climbing onto the big ones.
   - **Alithia:** light, protection, judgment and revelation; illusions.
   - **Prometheus:** fire and the elements, books that teach new cards in the middle of a run, and hacks that rewrite another card's
     numbers. Fragile, as he is meant to be.

   A character who falls takes their cards out of play, which turns the party's health into four lives to protect rather than one
   bar. Their last words (the game has them) play as they go. **M**

6. **Light and dark on the table.** The enemies' intents show only where there is light. In the dark you see a question mark;
   Alithia's light shows what is coming, and Cyrus is strongest where nobody can see. The game's rule that standing in the dark
   hides you carries straight across. **M**

7. **Tethers.** A held spell stays on the table tied to its target, a slot it occupies, fraying a little each turn until you renew
   it, let it go, or it snaps with an effect of its own. **S** to **M**

### Truth and forgetting

8. **Lethe and un-forgetting.** Exhausting a card is forgetting it for the fight; removing it, forgetting it for the run (Lethe
   Water as the shop's removal). Then the twist: **a-letheia, un-forgetting.** In the last act everything you forgot comes back,
   changed, the way the game's last levels come out from under ΛΗΘΗ. What you threw away decides how the run ends. **M**

9. **Evidence and Accusation: winning by the truth.** Some enemies, the human ones above all, can be beaten without killing them.
   Evidence cards are found on the map (events, clues, the journal's way of thinking), and in a fight they build a case. Play the
   right set and the accusation lands: "Will Subdued", the game's own closing words. Alithia's Inquisitor path is made for it, and
   it is the twist no other deckbuilder has: a fight you win by proving something. **L**

10. **The Message.** Every run starts with one card that cannot be removed or exhausted: the message the Messengers carry. Events
    add words to it, and in the final fight it is played as the truth spoken ("The messengers have already found the truth").
    How much it says depends on the run. **S**

### Bosses and fate

11. **Erysichthon eats the deck.** The first boss swallows cards and, if it can, one of the party with all their cards. Feed it
    what it should not eat (curses, lies, struck-out cards) and it staggers, heaving up whatever it swallowed; and through the hole
    in its belly what it ate falls back out at random. Its fight in the tactics game, translated into cards. **M**

12. **Moira's die.** Once a fight, cast the die: change an enemy's intent, or a card's number, for better or worse. And a last boss
    the story keeps hidden even from the gates: Fate, beaten only by the die cast at the right moment ("The die is cast"). **S** for
    the die, **L** for the boss.

### The run around the fights

13. **Rests as the game has them.** A rest spot is a short rest: mend a little, or study one card (an upgrade). Only the long rest
    at the end of an act reshapes the deck, as only a long rest prepares spells in the main game. **S**

14. **Oddities as events.** The question-mark rooms are the game's own strangeness: the looping corridor, the shifting room, the
    talking thing, notes on the wall, mementos, stashes. They exist on the maps already; here they are choices with a price. **S**
    each.

15. **Passives as relics, and Blessings to start.** The passives (Iron Hide, Quick Hands, Mercy, Momentum, Cat Burglar...) and the
    charms are the relics. The three run Blessings (iron, patient, swift) are the first choice, before the first fight. **M**

16. **Two players.** The game already has local and network co-op: each player holds two of the party's suits, and a tether can run
    between their characters. **L**, and later.

---

## 4. My pick

A first version as **1a, The Ascent, framed as a dream**, with:

- **5. the four suits** with the artist's icons, and **2. gates as the energy**. Together they make it unmistakably this game, and
  the party plays as it does in the tactics fights;
- **6. light and dark** for the intents, the most original fight rule here;
- **8. Lethe and un-forgetting** for exhaust and removal, the story's own idea of truth as un-forgetting;
- **11. Erysichthon** as the first act's boss;
- **13 and 14**, rests and oddities, which cost little and come from the maps.

Then, once it plays well: **9. Evidence and Accusation**, the twist that sets it apart from every other deckbuilder, and 3, 4, 10
and 12.

**How it would be built, in steps:**

1. **One fight.** A hand, a draw pile, a discard pile, an exhaust pile, gates as the energy, three enemies with intents, conditions
   (Burned, Poisoned, Exposed, Blessed and the rest are already defined). One character's suit.
2. **The run.** The map, card rewards, the rest spot, the shop (the travelling merchant), a few oddities, saving a run.
3. **The party.** All four suits, falling and last words, light and dark.
4. **The first act.** Its enemies, its elites, Erysichthon; then balance by playing.

Card frames, backs, map nodes and the sky would be placeholders behind slots, as everything is, for the artist.

---

## 5. What the game already has for it

- **Cards from moves.** Every move is a `SkillDefinition` with a name, an icon, a damage type and effects. A card can take its name,
  icon and element from one, with numbers of its own.
- **Conditions.** `ConditionDefinition`: Burned, Poisoned, Exposed, Accused, Blessed, Bulwarked, Staggered, Soaked... with icons and
  descriptions, already in the game's wording.
- **Enemies.** `CombatantDefinition` for health, art and the stagger bar of bosses.
- **Relics.** The passives, charms and Blessings.
- **A run.** The dungeon run (`DungeonDefinition`), the travelling merchant's store, rest spots, the oddities.
- **Feel.** FightCards (a fight's opening and closing words), MoveFeel (blows, bursts, shake), the sky's shaders, the music in
  layers, SoundBank's slots.
- **The world.** The dream map for a frame, the gates' names and lines, Lethe Water, the struck-out notes.

---

## 6. Questions that decide it

1. **Where does it live:** a mode of its own (1a), a game inside the world (1b), or the dungeon run (1c)?
2. **The party:** all four in one deck, or one or two of them chosen for each run?
3. **Does it touch the story:** a dream with consequences (what is learned carries back), or a mode apart?
4. **Which twists first:** my pick in section 4, or others?
5. **The art:** the move icons as card art for now, with frames from the artist later?
6. **Its name:** "The Ascent", or something of yours.
