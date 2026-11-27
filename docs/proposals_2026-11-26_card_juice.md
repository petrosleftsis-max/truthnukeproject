# Juice for the card game - proposals, 2026-11-26

The designer, 2026-11-26: "Suggest ways we can give it "juice" and better the game feels for the card game".

Nothing here is built. The card game (`docs/card_game.md`) works but barely moves. After every play the whole fight is drawn again
from nothing, the enemies' whole turn happens in a single frame, and numbers simply change. The only motion is a card growing 3%
under the pointer, and 8% (risen 22 pixels) when chosen. Its buttons already swell and click like every button in the game
(UiFeel, GameSounds); the cards are not buttons, so they do neither. It starts from almost nothing, so each piece will show.

Section 1 is the groundwork most of the rest needs. Sections 2 to 10 go moment by moment through a run. Section 11 is the juice
that depends on which game in the world this is. Then my pick (12), what the game already has to build it from (13) and the
questions (14). Every item has a number, so any of them can be picked by it.

Sizes are relative: **S** small, **M** a good piece of work. Every timing and size is PROPOSAL.

## What holds for all of it

- **Only the picture and the sound.** CardBattle and CardRun do not change: the rules still happen at once, a suite still plays a
  whole fight in a frame, and the screen plays it back.
- **Every shake, flash, slowing and rumble asks Comfort first**, so the dials in Options (Screen shake, Flashes, Rumble, Slow
  motion) cover the card game with nothing new.
- **Nothing to look at draws on the fight's random numbers**, so a seeded run comes out the same with all of it on (MoveFeel's
  rule for the tactics fights).
- **Every sound and picture is a slot** for the designer to fill; until then a stand-in made in code plays (PlaceholderSounds) or
  a shape is drawn.

---

## 1. The groundwork

1. **Things that stay.** Each card in the hand keeps one drawing for as long as it is there (the fight already gives every card
   an id), and each enemy keeps one panel. A change updates them where they are instead of throwing them away and making them
   again. Without this nothing can travel: a card cannot fly to an enemy when the hand is remade after every play. **M**
2. **The fight played back a beat at a time.** The fight notes what happens as it happens: a card drawn, a card played, a hit of
   9 with 4 of it blocked, Block gained, a status put on or worn off, somebody falling, the discard pile shuffled in, an enemy's
   move. The screen plays the notes back in order with short gaps.
   - On your own turn you never wait for it: the next card can be chosen while the last still plays out, and the beats play
     faster the more are waiting.
   - During the enemies' turn the hand waits for "Your Turn". A press in its last moment still counts (the tactics fights keep
     one for 0.2 s).
   - The log can then fold away behind a button, since the screen shows it all.

   **M**

## 2. The hand

3. **A fan.** The hand in a gentle arc, the outer cards lower and turned a little. As a card leaves, the others ease into their
   new places instead of jumping. **S**
4. **A card you point at rises.** It comes up out of the fan to full size and upright, over the others, with a soft tick, and its
   neighbours lean apart to make room. What its words mean (Exposed, Exhaust...) shows in a panel beside it at once, instead of
   the slow tooltip. **S**
5. **Playable at a glance.** A card you can afford glows softly along its edge; one you cannot does not (as well as going pale).
   When the energy changes, the glow fades on or off. **S**
6. **Numbers that show the fight.** Where the fight changes a card's number (your Might or Weakened, Exposed on the enemy it is
   aimed at), the number is green when higher than printed and red when lower. The card already works its numbers out against
   the fight; this only colours them. **S**

## 3. Drawing, discarding, shuffling

7. **Drawn.** Cards fly from the draw pile, bottom left, to their places in the fan, one after another, turning face up as they
   come. Each makes a soft card sound a little higher than the last. **S**
8. **Discarded.** At End Turn what is left of the hand sweeps into the discard pile, bottom right, one card after another, faster
   than the draw. **S**
9. **Shuffled.** When the draw pile runs out, the discard pile streams back into it with a riffle, and "Shuffled" shows by the
   pile. **S**
10. **Piles you can see.** The draw, discard and exhaust piles as small stacks of card backs that grow and shrink, with their
    counts on them, instead of three lines of text. Pressing one shows what is in it (the draw pile in no particular order).
    **S**

## 4. Playing a card

11. **The card goes off.** It leaves the hand for the middle of the screen (an attack leaning towards its enemy) and holds a
    moment as it goes off. Then:
    - it flies, shrinking, into the discard pile;
    - one that exhausts burns away in embers instead;
    - a Power breaks into light that flows into your side, since it stays in effect.

    **S**
12. **An arrow to aim with.** While a card that needs an enemy is chosen, a curved arrow runs from it to the enemy it is aimed
    at, and corners close in around that enemy. With a mouse it follows the pointer; with keys and a pad it jumps from enemy to
    enemy. **S**
13. **The hit, shown before it lands.** While an attack is aimed, the enemy's health bar marks the stretch it would take, after
    their Block (the tactics fights' preview, HealthBarMarks). **S**
14. **Drag to play.** With a mouse:
    - drag a card up out of the hand and let it go to play it;
    - an attack drags its arrow onto an enemy;
    - let go back over the hand and the card goes back.

    Pressing, then pressing again, stays as it is. **M**
15. **Energy you can see spent.** The energy as an orb with its number. The number pops as it drops and the orb dims at nothing;
    it flares when it fills at the start of a turn or a card gives more. **S**
16. **A refusal you feel.** A card that cannot be played shakes its head when pressed, with the Refused sound (as the game's
    disabled buttons already do, UiFeel). Why shows for a moment in a small bubble over the hand, instead of only in the log;
    for "Not enough energy" the orb flashes red as well. **S**

## 5. Hits

17. **A hit lands.** Whoever is hit is knocked back a few pixels and springs back, flashes white for an instant, and a slash is
    drawn across them. The damage jumps out of them as a number that rises and fades, bigger for a bigger hit. **S**
18. **Block, seen taking it.** What Block takes shows as its own number in Block's blue ("Blocked" when it takes it all), and the
    shield shakes. The hit that breaks the last of it shatters the shield. **S**
19. **The health bar drains.** It drops at once and the stretch that was lost fades after it, as the tactics fights' bars do
    (HealthBarMarks.drain). The number counts down meanwhile (UiFeel.count_to). **S**
20. **Weight for the big ones.** The tactics fights' own thresholds (Combat.hit_stop_for and shake_for):

    | The hit | The stop | The shake |
    |---|---|---|
    | Under 8% of somebody's health | None | None |
    | From 8% | 0.03 s | None |
    | From 25% | 0.07 to 0.13 s | 5 to 16 pixels |
    | The blow that fells them | 0.18 s | 12 pixels |

    **S**
21. **Hit after hit.** A card or move that hits more than once lands each hit on its own, with its own number, each a little
    quicker and higher in pitch. One that hits every enemy sweeps across them left to right. Spines answer a hit with a spray of
    small spikes back at whoever struck, with their own number. **S**
22. **You are hurt.**
    - The screen's edges flare red (green for poison), as the tactics fights' do (HurtVignette).
    - A pad rumbles, harder for a bigger share (Rumble.blow).
    - At a fifth of your health or less: a heartbeat in the pad and a faint pulse at the edges (the tactics fights' NEAR_DEATH).

    **S**

## 6. Statuses

23. **Statuses as badges.** A small picture with the number on it instead of words, with the explanation in a tooltip as now.
    Nine picture slots; until they are filled, the status's first letter in a circle of its colour. **S**
24. **Put on, seen.** A status flies from the card (or the enemy using it) to whoever gets it and lands with a pop. A good one
    rises as it comes, a bad one drops, and the number ticks when it grows. **S**
25. **Wearing off, seen.** At the end of the round each status counting down ticks with a small pulse, and one that is gone
    shrinks away. **S**
26. **Poison bites.** Green drops fall from whoever is poisoned as it bites at the start of their turn, with the number in green.
    **S**

## 7. The enemies

27. **Intents as pictures.**
    - A sword and the number for an attack: a bigger sword for a bigger hit, "x3" for three hits.
    - A shield for Block, an arrow up for growing stronger, the status's badge for putting one on.

    The intent bobs gently over the enemy, the words go into its tooltip, and it pulses when its number changes (Weakened put on
    the enemy, say). Picture slots, drawn in code until they are filled. **S**
28. **Their turn, one at a time.** Each enemy in turn steps towards you and its intent flares and goes. The move lands (the hit as
    in section 5, its Block, its status), and it steps back. A short pause, then the next. **S**, once section 1 is in.
29. **Alive.** Each enemy breathes (a slow, slight swell) and sways a little, out of step with the others. It breathes slower
    while hurt (under a third of its health), as the tactics fights' figures do. **S**
30. **Their own figures.** An enemy that borrows a main-game combatant (Borrow Picture From) could show that combatant's figure
    instead of its still portrait: its idle, its attack animation when it attacks, its fall (CombatantSprite). Where a figure has
    an animation of its own, the step of 28 is left out (the lesson of the tactics fights). **M**
31. **Falling.** The enemy flashes, goes grey and sinks away with the sound bank's Enemy Falls; its intent and badges go at once.
    The last of a fight falls in a moment of slow motion while the music gives way (SoundFollows.give_way), as in the tactics
    fights. **S**

## 8. Turns, and a fight's start and end

32. **Whose turn.** "Your Turn" and "Enemy Turn" across the middle for a moment (the tactics fights' TurnBanner). **S**
33. **An End Turn that tells you.** It glows gently once nothing left in the hand can be played. **S**
34. **A fight begins.** The enemies come in one after another from the right, the deck is shuffled with a riffle, and the first
    hand is dealt. An elite or the boss comes in with its name across the screen and a heavier sound. **S**
35. **Won, and lost.**
    - Won: the last enemy falls (31) and "Victory" comes in hard. What is left of the hand and the piles sweeps away, and the
      rewards come up.
    - Lost: the colour drains out and the screen slows, "Defeated" fades in and the music dulls.

    **S**

## 9. Rewards, the map and the rooms

36. **Reward cards turned over.** They are dealt face down and turned one after another; a rare one turns with a burst of gold and
    its own sound. The one taken flies to the Deck button, whose count pops (UiFeel.pop), and the others fall away. **S**
37. **Gold you can see.** Coins fly from where the gold came from into the Gold counter, which counts up with a tick
    (UiFeel.count_to). Spending runs it the other way. **S**
38. **Relics.** Along the top as their pictures (each relic already has its Picture slot; they show as words now). One gained
    rises out of a glow and flies into the row, which pops. One doing its thing flashes there as it does (Field Dressing as a
    fight is won). **S**
39. **The map.**
    - Rooms as pictures (slots: Fight, Elite, Rest, Shop, Event, Chest, Boss) instead of words, the boss's bigger and darker.
    - The rooms you can go to now pulse.
    - The way you choose inks itself in from where you are, a marker walks it, and the view glides up to the next floor instead
      of jumping.

    **S**
40. **Into a room.** A short wipe from the map into the room, and back. The panels of a rest, a shop or an event arrive with the
    game's fade (UiFeel.arrive), and their buttons deal in one after another (UiFeel.deal_in). **S**
41. **A rest.** A small fire flickering (drawn in code until there is a picture), and mending counts the health up in green.
    Studying shows each card's upgraded version as you point at it, and the one chosen flashes as it changes. **S**
42. **A shop.** What is bought flies to the deck or the relic row, and the gold runs down. A card removed burns away. What you
    cannot afford refuses (16). **S**
43. **A chest.** The lid flies up, light spills out, and the relic rises from it. **S**
44. **An event.** Its text types out, as a conversation's lines do, and the choices arrive one after another. **S**

## 10. Sound, music, the pad and pace

45. **The card game's sounds.** A group of its own in the sound bank (`audio/sound_bank.tres`). Each slot plays a stand-in made
    in code until it is filled:
    - cards: drawn; played (Attack, Skill, Power); a shuffle; End Turn;
    - a fight: a hit (light and heavy); Block gained, struck and broken; a good status, a bad one; poison; energy filling;
    - the rest: a reward card turned over, a rare one; gold; a relic; a step on the map; a chest; an upgrade; a card removed.

    **S**
46. **Music.** Slots for the card game's music (the map, a fight, an elite, the boss), played through the Music autoload as the
    maps and bosses choose theirs. Today whatever played on the title screen carries on. **S**
47. **The pad.** A tap as a card is played, a thump as an enemy falls, and the blows on you as in 22. Nothing on a keyboard, and
    the Rumble dial covers it. **S**
48. **Pace.** A Card Game Speed in Options for section 1's playback, Normal or Fast; Fast halves every gap and flight. The
    tactics fights' opening was made unskippable at your word; I would offer this one because a card game's fights are played
    so many more times. **S**

## 11. Juice that depends on which game it is

Not to be built until you say where it lives in the world. Nothing in sections 1 to 10 needs it decided.

- **Prometheus's hacking.**
  - Cards as fragments of code that type across as they are played.
  - A hit as a glitch: the portrait torn into offset strips for an instant.
  - A faint scanline over the screen, and terminal beeps among the sounds.
  - The map a network of nodes.
- **Enfina's game.**
  - A table under the cards, the cards slapped down with a snap.
  - A candle's light that flickers, and coins that clink.
  - The enemies opponents across the table.

## 12. My pick

The groundwork (1, 2) first: almost everything else waits on it. Then the five that change the feel most:

- hits (17 to 20);
- cards that travel (3, 4, 7, 8, 11);
- the enemies' turn one at a time (28);
- intents as pictures (27);
- the sounds (45).

The rest in any order after.

## 13. What the game already has to build it from

| What | Where | For |
|---|---|---|
| The comfort dials | `ui/comfort.gd` (Comfort) | Every shake, flash, slowing and rumble |
| Buttons that answer, panels that arrive, numbers that count | `ui/ui_feel.gd` (UiFeel: refuse, arrive, deal_in, count_to, pop) | 16, 19, 36, 37, 40 |
| A bar's drain and preview | `ui/health_bar_marks.gd` (HealthBarMarks) | 13, 19 |
| The red edges | `ui/hurt_vignette.gd` (HurtVignette; the tactics fight makes its own, so the card screen would too) | 22 |
| Rumble | `control/Rumble.gd` (tap, thump, blow, heartbeat) | 22, 47 |
| Whose turn | `ui/turn_banner.gd` (TurnBanner) | 32 |
| Music that gives way | `audio/SoundFollows.gd` | 31, 35 |
| Sound slots and stand-ins | `audio/sound_bank.tres` (SoundBank, GameSounds), `exploration/PlaceholderSounds.gd` | 45 and every sound here |
| Hit-stop and shake thresholds | `combat/Combat.gd` (hit_stop_for, shake_for) | 20 |
| Animated figures | `combat/CombatantSprite.gd` | 30 |
| Bursts, shatters, falls | `combat/MoveFeel.gd`: drawn on the tactics board, so the card screen needs flat versions of its own | 17, 18, 31 |

## 14. Questions

1. **Which?** By number, by section, or "all but".
2. **Drag to play (14)?** My pick: yes, beside pressing twice.
3. **A speed option (48)?** My pick: yes, Normal by default.
4. **The sounds at a fight's start and end.** The sound bank's Card Opening, Card Victory and Card Defeat (named after the tactics
   fights' title cards, not this game), or slots of the card game's own? My pick: its own, so it can sound like whichever game
   it becomes.
5. **The enemies' figures (30).** Animated where the main game has a figure, or portraits only? My pick: animated where there is
   one.
