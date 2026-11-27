# The card game

Built 2026-11-26 at the designer's request: "a card game that is like a Slay the Spire type of game", a game that exists in the
world, first as the genre's plain baseline. **It is Prometheus's hacking** (the designer, 2026-11-27: "This will be Prometheus'
hacking game afterall"), and **since 2026-11-27 the main hacking minigame**: every hack plays as it unless it asks for its board
(below, "Hacking"). The twists the designer chose, read as hacking, are built (layers, the trace, half-read code, scanning, Lethe,
the Devourer, rests, oddities, two players), and **the ten gates are its characters**: `docs/proposals_2026-11-27_card_hacking.md`
has what was built, the gates' playstyles, twists 7, 10 and 15 explained, and what waits. Names, numbers, decks and pictures are
placeholders throughout, all of them the designer's to change.

Its feel (juice) was built from `docs/proposals_2026-11-26_card_juice.md`, section 11's hacking juice on 2026-11-27 (below, "How it
feels").

It opens from the title screen: **Card Game** (left out of a release build, with the other test entries), as a whole run of the
system (three layers), after choosing who hacks. A map can open it with `CardGame.play("res://maps/<the map>.tscn")`, which comes
back to that scene when the run is left or over; a hack opens it over the world (`CardGame.open_hack`).

## How it plays

- **A run** climbs a map of 12 floors to a boss. Each floor's rooms join one to three rooms above them; the player picks the way.
  The first floor is fights, the middle one a chest, the one before the boss a rest; the rest are fights, events (?), elites, rests
  and shops. A run starts with 60 health, 99 gold, a deck of 10 cards and one relic. Losing a fight ends it; beating the boss wins it.
- **A fight:** each turn the player draws 5 cards and has 3 energy. A card costs energy to play. Block soaks up damage and is gone
  at the start of the player's next turn. Each enemy shows what it will do next (its intent) above it. End Turn discards the hand,
  the enemies act, and the next turn begins. The draw pile is reshuffled from the discard pile when it runs out.
- **Cards** are Attacks, Skills and Powers (a Power stays in effect for the whole fight). Some exhaust: gone for the rest of the
  fight once played. Every card can be upgraded once.
- **After a fight:** gold, and one card of three to add to the deck (or none). An elite also gives a relic.
- **A rest:** mend three tenths of the most health, or upgrade a card.
- **A shop:** five cards and two relics for gold, and removing a card from the deck once per shop (75 gold, 25 more each time).
- **An event:** a few lines and a choice.
- **Relics** do something at a moment: when picked up, at the start of each fight, on the first turn, at the start of each turn,
  or whenever a fight is won.

Controls: press a card to choose it, then the enemy it is for (or the card again, for one that needs no enemy). Keys and a pad: left
and right through the hand (or the enemies, once a card that needs one is chosen), Accept (Enter, Cross) to choose and play,
Cancel (Escape, Circle) to put it back, 1 to 9 for a card, and End Turn's key (Space, Triangle). The Deck button shows the deck.

## Statuses

| Status | What it does | Wears off |
|---|---|---|
| Might | Each hit deals that much more | No |
| Footing | Each Block card gives that much more | No |
| Ward | Gains that much Block at the end of each of its turns | No |
| Spines | Whoever hits it loses that much a hit | No |
| Frenzy | Gains that much Might at the end of each of its turns | No |
| Exposed | Takes half again as much from hits | Yes |
| Weakened | Deals a quarter less with hits | Yes |
| Brittle | Gains a quarter less Block | Yes |
| Poison | Loses that much at the start of its turn, then one less | Itself |
| Entangled | Cannot play Attacks | Yes |
| Confused | Every card drawn costs 0 to 3 at random (shown on the card) | Yes |

Enemies' traits are statuses they start with, shown as badges with their words (2026-11-27, below):

| Trait | What it does |
|---|---|
| Enrage | Whenever the player plays a Skill, it gains that much Might |
| Curiosity | Whenever the player plays a Power, it gains that much Might |
| Overtime | Once the player has played that many cards in a turn, their turn ends |
| Toll | Whenever the player plays a card, they lose that much health |
| Reactive | Whenever an attack hits it, it changes what it will do (and shows it) |
| Asleep | Does nothing (gaining its Sleep Block); wakes when it loses health (stirring a turn) or after that many of its turns |
| Mode Shift | After losing that much more health it curls up: Block and Spines for a few turns, then the next curl takes more |
| Invincible | Loses no more than that much health a round |
| Command | While it stands, the rest of its side deal that much more a hit |
| Pack | Whenever another of its side falls, it gains that much Might |
| Linked | Fallen, it rises again with half its health that many turns later, unless all the Linked are down |
| Holding | (Shown, not given) the player's cards it took, given back into the hand as it falls |
| Glutton | (The Devourer's, 2026-11-27) it eats the cards it takes; a Status card among them chokes it (it spits them all out and does nothing next turn); each quarter of its health lost, one falls back into the hand |
| Scanned | (Put on by Scan) its intent is shown, encrypted or not, for the rest of the fight; a phase that clears harm takes it off |

## How enemies choose

Built 2026-11-27 from `docs/proposals_2026-11-27_card_ai.md` (the designer: "Do them all, don't do any twists yet"). Each time an
enemy chooses its next move (as its turn ends, and at the start), in this order:

1. **Asleep, curled up or winding up:** it keeps to that.
2. **Its rules** (`CardEnemyRule`, in its Rules): "if this, do that", in order; the first that holds, for a fight of its From Tier
   or harder, and whose move it may use now, decides. What a rule can ask: its own health under a share; the player's Block (as
   their last turn ended), health or a status; itself having a status; an ally hurt, one fallen, being alone; its turn number.
3. **Its opening move** on its first turn (a move marked First).
4. **Its pattern** (in order, or at random by weight, never three times running), among the moves it may use now. A move's
   **limits**: not twice running, at most so many times a fight, not before its turn N, a cooldown after it, and Rule Only (never
   the pattern's). A move's **lean** makes it likelier while something holds (Lean When, Number, Status, Factor). The pattern's
   pick is made a turn ahead, as a plan: what **Second Sight** (a relic) shows after each intent, dimmed ("then"). Its rules can
   still change the plan when the time comes.

**Honest intents:** what it shows is what it does, but where one of its own traits says otherwise, and says so with a "!": a
Reactive one hit, one woken, one curling up. An enemy marked **Shows: Once Hit** shows "?" until it is hit, each time it chooses;
**Shows: Nothing**, "?" all fight.

**More a move can do:** a **countdown** (Wind Up: it shows its turns, 2 and 1, doing nothing else, then lands); **help** (its
Block, mending and status taken go to the worst hurt of its side, or all of them); **cards** into the player's draw pile,
discard pile or hand (`data/cards/` Status cards: Wound cannot be played, Dazed is exhausted if still in hand as the turn ends,
Slimed costs 1 and exhausts, Burn costs 2 health if still in hand); **taking** cards from the draw pile, given back as it falls;
**calling** others in (Summons), while fewer than four stand.

**Phases** (`CardEnemyPhase`): once its health falls under a share, it says its line, takes its statuses and Block, may throw off
what harms it, and from its next choice fights with the phase's moves, pattern and rules; or it **splits** into others, each with
as much health as it had left.

**Tiers and the Challenge:** a rule's From Tier keeps an enemy plainer in easy fights. A run's **Challenge** (the top bar's button,
before the first room; `CardRun.challenge`): 1, enemies choose as in a fight one tier harder; 2, and they have a tenth more
health; 3, and they start each fight with 1 Might.

What the enemies were given (`tools/build_card_ai_content.gd`, placeholders all): the Rat a Pack and a lean for Gnaw; the Gnawer
an opening Hiss; the Hired Bow an opening Take Aim and, in harder fights, a Loose at a player under a quarter health; the
Sellsword a Taunt at a player behind 10 Block (harder fights); the Alchemist a Drink when under half health (once, mending 10),
a Toxic Flask likelier at a player not poisoned, and a Sticky Flask of Slimed; the Bomber a Bomb that counts down and a Toss that
leaves a Burn; the Priest Curiosity, a Blessing for its worst hurt ally and a Mend for it when an ally is under half; the Ogre an
opening Roar and Enrage; the Golem asleep for three turns (Sleep Block 8); the Colossus Mode Shift 40 and, at half health, a
second phase (Might, Invincible 30, a Crush that counts down). And nine new enemies in eight new fights: Mimic (splits into two
Imps), Imp, Summoner (Command, calls Imps), Phantom Soldier (Linked, in threes), Ranger (Entangled, takes a card), Sorcerer (seen
only once hit, Confused), and three elites: Bellkeeper (Toll, Dazed), Ash Warden (Overtime, a Burn into the hand) and Bound Beast
(Reactive, Wounds). Second Sight is an uncommon relic.

What wears off counts down by one at the end of each round, after the enemies have acted; something the enemies put on during their
turn skips that round's count. So Exposed 2 from a card covers this turn and the next, and a Weakened 1 an enemy gives lasts the
player's next turn. Statuses live in `cards/CardStatus.gd` (their names and text can be changed there).

## Hacking: the gates, the system's layers, two players

(The designer, 2026-11-27; every number PROPOSAL. `docs/proposals_2026-11-27_card_hacking.md` has all of it, with the reasons.)

- **Who hacks: a gate.** World, Hermes, Pandora, Charon, Tartarus, Nemesis, Sophia, Ogdoad, Gnosis, Yaldabaoth
  (`data/card_characters/`), each its own deck, 60 health and (since the designer's "try them all", 2026-11-27) **its own starting
  relic**, named for a passive of the main game's (World Iron Hide, Hermes Quick Hands, Pandora DoT Master, Charon Bandolier,
  Tartarus Bulwark, Nemesis Drills, Sophia Contest Insight, Ogdoad Agile, Gnosis Measured Eye, Yaldabaoth Elemental Affinity;
  placeholders, the designer refines the gates). World is open; every other needs 3 **code fragments** (a layer's boss, a Memento,
  a hack's Fragment Of, `do Hacking.find_fragment("hermes")`), kept in Campaign's flags. The choice comes first; the title screen's
  Practice box opens all of them. Then each player's **Blessing** (twist 15): up to three offered (Iron: 10 more most health;
  the Patient: 1 energy on the first turn; the Swift: 2 more cards then), one taken, or none. More Blessings are the designer's to
  add (a relic file of Rarity Blessing: never in a chest or a shop).
- **Tethers** (twist 7): a card Type of its own. Played onto its target (an enemy; a partner, yourself alone; or yourself) it stays
  on the table as a small card at their feet, a thread to its holder. At the end of each of its holder's turns it does its Effects
  and frays by 1; at 0 it snaps, doing its Snap Effects. Press it to let go early (it snaps). The same card onto the same target
  renews it. Two held at once (`CardBattle.TETHER_SLOTS`; the Spool relic a third). Whoever it holds falling, it goes loose. An
  enemy's own (Enemy Only: the Leech's Leech Line) does its Effects to you at the end of its turn and frays; every 6 health its
  holder loses cuts a strand (`CardDefinition.TETHER_BREAK_DAMAGE`). An enemy's move can cut yours (Cuts Tethers: the Severer's
  Sever, the strongest first, no snap). Cards: Leash, Siphon (Drain, a new effect Kind), Guard Link.
- **The Message** (twist 10): in every deck, never taken out, rewritten or forgotten; nearly empty (Draw 1, and a struck line).
  Every event offers to listen for a word of the truth (beside its own options; an event's Offers A Word, or a Message option of its
  own: A Voice in the Wires), and the player chooses how it grows from a few offers at random: a new word (`data/card_message_words/`,
  each a line and an effect), a word deepened (its number up by its Step), or spoken lighter (costs 1 less). At the run's last boss
  it says every word twice ("the truth, spoken whole"): strong, not a win by itself. Up to 6 words.
- **The party's passives as rare relics** (twist 15), in chests and shops for every gate: Night Hunter (an enemy falls: 1 energy;
  a new When), Mercy (each turn mend 2), Breaker (fights start with 2 Might), Meditate (2 energy on the first turn).
- **The layers.** A whole run is 3 layers of 12 floors, each with its own boss (the Colossus, the Devourer, the Core); deeper is
  harder (any-layer fights x1.25 and x1.5 health, +1 and +2 Might) and darker (15 and 35 in a hundred enemies encrypted: Scan them).
  After a layer's boss: the long rest (everybody mended, each deck reshaped), then the next layer, the map more pixelated.
- **The trace** (top bar): +1 a fight, +3 an elite, +1 a turn past 6, loud cards their own; Cover Tracks -15. From 25 and 50 a
  Might more, from 50 a tenth more health, at 75 a Glitch in every deck, at 100 traced: lost.
- **Half-read code:** a struck-out line on a card until it has been played once (any run); Notes on the Wall reads them all.
- **Lethe:** a card taken out is forgotten; the last layer brings it back upgraded.
- **Rests:** Patch (mend 30%), Study (upgrade), Cover Tracks, Mend your partner (co-op).
- **Two players** (Slay the Spire 2's way): each their own deck, hand, energy, health, gold, relics; Ready each (enemies act once
  both are); enemies hit both (x2 x1.1 health and x2 Block for two); one down gets up after a fight won; the map by vote (by lot
  when they differ). **On one screen** (the character choice's two boxes): **both hands at once** (each player's on their half,
  with its own energy, piles and Ready; `CardStage` seats) or one at a time with Swap (Tab); and **the rooms together** (rewards,
  rests, shops, events, chests, the Blessings and the long rest on each player's half at once) or in turn. **Each on their own
  device**: the main game's two players' own (Coop), else the keyboard and mouse the first's and a pad the second's (two pads: one
  each, the mouse the first's); a press plays the hand of whoever's device made it, and in the rooms brings the focus to their half.
  **Over a network** (two machines): the same run on both from the same seed, every choice a move the host numbers and both do in
  that order (`Net` "The card game, played together"); each machine plays its own player (the host's the first), both hands shown,
  the other's half saying what they do. From the title screen the joiner follows the host in; a hack is played together wherever it
  begins. The other machine gone, the run goes on with both players here.
- **As a hack:** `HackDefinition`'s Minigame (Cards, or Board for the three boards kept as they were), Card Length (one fight, a short
  layer, a layer, the whole system), Card Encounter, Card Tier, Card Layer, Fragment Of. Won is success, lost failed, left walked away;
  the hacker's Intellect sets the decks' health (0.6 to 1.4, 1 at 30). **Both players play it** (the designer, 2026-11-27: "During a
  dungeon or story mode, both players still get to play the hacking game together"): two players on one screen, a game for two
  there; over a network, the same game on both machines (in a fight, the other machine's `Net.decided` waits for how it went).

## Changing it

Everything is in data files, one per thing, edited in the inspector like the rest of the game's data:

| What | Folder | Notes |
|---|---|---|
| Cards | `data/cards/` | Name, Type, Rarity (Starter cards are never offered), Cost, Upgraded Cost, Target, Effects, Exhausts, Picture, Flavour. Each effect: Kind, Amount, Upgraded Amount, Times (hits), Status. The card's text is written from its effects. |
| Enemies | `data/card_enemies/` | Health range, Moves (each: damage and hits, block, a status on the player, a status on itself, a weight; When It May Be Chosen: First, Rule Only, Not Twice Running, Most Times, Not Before Turn, Cooldown, Wind Up, a Lean; More It Does: Helps, Heal, Adds Card (count, pile), Steals, Summons), Pattern (in order, or at random never three times running), Starting Statuses (its traits among them), Picture, or Borrow Picture From (a main-game combatant's key, for its portrait); How It Chooses: Rules, Phases, Shows; Asleep and Curled Up: Sleep Block, Curl Block, Spines, Turns, Grows. |
| Fights | `data/card_encounters/` | Tier (Easy for the first 3 fights, Hard after, Elite, Boss), the enemies' keys, and Layer (0: any layer, made harder deeper; 1 to 3: that layer's own, played as written; a boss is its layer's). |
| Relics | `data/card_relics/` | When, an Effect (an Apply goes on every enemy), Rarity (the Starter one is the run's first). |
| Events | `data/card_events/` | Title, Text, Options (each: Label, Outcome, Gold, Health, Most Health, Trace, Fragment, Adds Card, and an Action: a card to choose, a card to remove, upgrade or rewrite, a relic, every half-read card read). |
| Characters | `data/card_characters/` | Name, Gate, Health, Starting Deck, Starting Relic, Playstyle (its first line on the choice), Fragments Needed, Picture. |
| The Message's words | `data/card_message_words/` | Line (the words), Effect (what it does each time the Message is played: Damage and Apply go to every enemy), Step (how much deepening adds), Weight (how likely it is offered). |

Since the designer's "try them all" (2026-11-27): a card's Type can be Tether (its Tether group: Tether Strength, Upgraded Tether
Strength, Snap Effects, Enemy Only); an effect's Kind can be Drain; an enemy move has Ties (an Enemy Only Tether it ties onto
everybody) and Cuts Tethers; a relic has Rarity Blessing, When Enemy Falls, More Tether Slots and Learned From; an event has Offers A
Word, and an option the Action Message.

Since 2026-11-27 a card also has Character (whose it is: offered only to that gate; empty for everybody), Co-op Only, Trace (how
loud: the trace it raises when played) and Target Ally (for a partner); an effect has Struck (half-read). An enemy move has Damage
Per Held (more a hit for every card it holds).

The starting deck and relic are `CardDatabase.STARTING_DECK` and `STARTING_RELIC`; the run's numbers (floors, gold, prices, how
often each room comes) are the constants at the top of `cards/CardRun.gd`; a fight's (hand size, energy) at the top of
`cards/CardBattle.gd`.

**Pictures:** every card, enemy and relic has a Picture slot. A card with none draws a block in its type's colour with its letter.
An enemy with none stands as its main-game namesake's figure (Borrow Picture From), else its portrait, else a blank. Everything
else the screen draws has a slot in `data/card_looks.tres` (below).

`tools/build_card_content.gd` wrote the first content. **Running it again writes the same files over any changes made to them.**
`tools/build_hack_content.gd` wrote the hacking round's (2026-11-27): it adds only what is missing, so it can be run again.
`tools/build_card_twists.gd` wrote "try them all"'s (the Tethers and their enemies, the Message and its words, the gates' relics, the
Blessings, the party's relics): it adds only what is missing, and changes a gate's starting relic only while it is still Field
Dressing.

## How it feels

Built 2026-11-26 from `docs/proposals_2026-11-26_card_juice.md` (the designer: sections 1 to 10 "All", but item 29: "just use the
existing idle animations and slow them when lower hp"; section 11 waits on the card game's place in the world). Every timing is
PROPOSAL; all of it is only to look at and hear, and nothing of it is rolled on a fight's numbers.

- **A fight played back.** The rules happen at once and tell the screen each thing as it happens (CardBattle's `beat`); the screen
  (`cards/CardStage.gd`) plays the beats back one at a time with short gaps. On your own turn you never wait: a card can be played
  while the last plays out, and waiting beats hurry. During the enemies' turn the hand waits for "Your Turn" (a key pressed in its
  last 0.2 s still counts). Cards and enemies keep their views; once every beat has played, the screen puts itself right from the
  rules. Headless (the suite) it all happens at once.
- **The hand** is a fan (`cards/CardHand.gd`). The card under the pointer rises to full size, upright, its neighbours leaning
  apart, with a panel of what its words mean beside it. A card that can be played glows. A number the fight has changed is
  green when higher, red when lower.
- **Cards move.** They are dealt from the draw pile, turning face up, each a little higher in pitch. End Turn sweeps the hand
  into the discard pile, and the discard pile streams back in when it is shuffled. A card played goes to the middle and holds
  (leaning towards its enemy), then flies to the discard pile; one that exhausts burns away, a Power breaks into light flowing
  into you. The piles are stacks you can press to see what is in them.
- **Playing.** Press a card, then its enemy, or drag it: an attack's arrow onto an enemy, anything else up out of the hand. An
  arrow and closing corners show the enemy aimed at, and its health bar marks what the card would take. The energy is an orb
  that pops, dims at nothing and flares as it fills. A card that cannot be played shakes its head, and why shows over the hand.
- **Blows.** Whoever is hit is knocked back, flashes white and is slashed, and the damage jumps out of them. Block takes its share
  first, in blue; the hit that breaks it shatters the shield. Health drains and counts down. A big blow stops and shakes the
  screen, by the tactics fights' own thresholds (Combat.HIT_STOP_FROM, HEAVY_SHARE...). A flurry lands hit by hit, a sweep
  enemy by enemy, and Spines spray back. When you are hurt the edges flare red (green for poison) and a pad rumbles. At a fifth
  of your health or less, a heartbeat.
- **Statuses** are badges (`cards/CardBadge.gd`) that fly in from the card or the enemy that gave them, pop as they grow, pulse as
  they wear off and shrink away; poison drips.
- **Enemies** (`cards/CardFighter.gd`) stand as their main-game figures (`cards/CardFigure.gd`): their own idle, slower when hurt
  (CombatantSprite's HURT_BELOW, HURT_PACE, HURT_SLOWEST), and their own attack or skill when they act. Their intents are
  pictures with the number, bobbing, pulsing when it changes. They act one at a time, falling grey and sinking; the last one
  falls in slow motion as the music gives way.
- **Turns.** "Your Turn" and "Enemy Turn" cross the screen (TurnBanner). End Turn glows when nothing in the hand can be played. A
  fight begins with everyone coming in, an elite or the boss with its name. Won: "Victory" and the hand swept away. Lost: the
  colour drains out and "Defeated" fades in.
- **The run.** A wipe into every room and back. On the map the rooms are pictures, the ones you can go to pulse, and the way you
  choose inks itself in and is walked. Reward cards are dealt face down and turned over, a rare one in a burst of gold, and the
  one taken flies to the deck. Gold flies into the purse and is counted as it lands; relics rise into the bar and light up as
  they work. A chest's lid flies open; a rest has a fire, a mend that counts up, and a study that shows each card upgraded. An
  event's words type out before its choices.
- **The pace:** Options' "Card game: fast" (Comfort.card_fast) halves every gap and flight. Screen shake, flashes, rumble and
  slow motion follow the comfort dials as everything else does.
- **The hacking juice** (section 11, 2026-11-27): a card played types across as a line of code; a hit tears the figure into
  strips for an instant (`CardFighter.glitch`, the Flashes dial); a faint scanline over the screen; terminal beeps; the map a
  network (dashed links, packets along the walked ones), more pixelated each layer down.

## Slots

The designer, 2026-11-26: "Anything that uses music, sound or art, will be slots for me to fill in later". Until one is filled a
stand-in plays (PlaceholderSounds) or is drawn (CardIcon, CardFx).

| What | Where | Notes |
|---|---|---|
| Every sound | `audio/sound_bank.tres`, group "The card game" | A card drawn, shuffled, discarded, exhausted, played (by type), pointed at; a hit and a heavy one; Block gained, struck, broken; a good and a bad status, poison, Spines, a mend; energy filling; an enemy falling; End Turn, Your Turn, Enemy Turn; a fight beginning, an elite and a boss arriving, won, lost; a reward turned over, a rare one, a card taken; gold in and out; a relic gained and used; a step on the map, a room entered, a chest, an upgrade, a card removed, an event's letters; and since 2026-11-27 an enemy waking, a countdown ticking, one curling up, a phase beginning, a card put in your deck, cards taken, one called in (or splitting), one of the Linked rising, Overtime; and the hacking's (2026-11-27): a terminal's beep, a card's code typing, a hit's glitch, an enemy Scanned, the Devourer choking, the trace rising, a code fragment found; and "try them all"'s (2026-11-27): a Tether tied, fraying, snapping and cut, the Message given a word, the truth spoken at the last boss, a Blessing taken. The fire's crackle (looped) is silent until filled. |
| Music | `audio/sound_bank.tres`, "The card game": Card Music Map, Fight, Elite, Boss | Empty: whatever was playing carries on. |
| Pictures | `data/card_looks.tres` | Card back and card faces by type (a Status card's too); the fight's background, the player's picture, the energy orb, Block's shield; intents (attack, heavy attack, block, grow, curse, unknown; and since 2026-11-27 asleep, curled up, helping an ally, mending, calling others in, a card for your deck, taking cards, a countdown's mark); a badge per status (each trait too); a blow's slash, a spark, an ember, a drop, a spike, a shard, a coin; the map's background, each kind of room, the marker; a rest's fire, a chest shut and open; and the Hacking group (2026-11-27): an encrypted intent, the second and third layers' map backgrounds, the scanlines, a glitch's bars, the trace meter, a code fragment; a badge for Scanned and for Glutton; and "try them all"'s: a Tether's card face and the Message's, a held Tether's small card and its thread, the intents to tie a Tether on you and to cut yours, a Blessing, a word of the Message. Each gate's picture is on its character file. Sizes are in the inspector's notes. |

## The code

- `cards/CardBattle.gd`: one fight's rules, no nodes (`play`, `end_turn`, `attack_damage`, `block_gained`, `intent_of`,
  `preview_damage`), telling the screen each `beat`.
- `cards/CardRun.gd`: a run's rules: the map, rewards, rests, shops, events, relics (`relic_used` when one works outside a fight).
- `cards/CardGame.gd` (`scenes/card_game.tscn`): the run's screen (map, rooms, the bar) and the keyword panel; `cards/CardStage.gd`:
  a fight's screen, playing the beats back.
- Drawn pieces: `CardView` (a card), `CardHand` (the fan), `CardFighter` (somebody in a fight), `CardFigure` (a main-game figure),
  `CardBadge` (a status), `CardPile`, `CardOrb` (energy), `CardAim` (the arrow), `CardFx` (what flies and flashes), `CardIcon` (a
  picture or its stand-in), `CardLooks` (the picture slots), `CardFeel` (the pace, the sounds, a blow's stop and shake).
- `cards/Card*Definition.gd`, `CardEffect.gd`, `CardEnemyMove.gd`, `CardEnemyRule.gd`, `CardEnemyPhase.gd`, `CardEventOption.gd`: the
  data's kinds; `CardDatabase.gd` reads the folders.
- How enemies choose is `CardBattle`'s "Choosing" (`_decide`, `_pattern_pick`, `_allowed`, `_holds`, `_plan_after`) and "Traits and
  phases"; `tools/build_card_ai_content.gd` wrote that content (it adds only what is missing, so it can be run again).
- Hacking (2026-11-27): `CardBattle.players` and `active` (the one-player names `player`, `hand`, `energy`... are the active
  player's), `add_player`, `set_ready`, `play_as`, `set_layer`, `set_trace`, `set_darkness`, `intent_hidden`, the Glutton's
  `_steal`, `_choke`, `_spills`; `CardRun.players` and `me` (likewise), `vote`, `rest_with`, `long_rest`, `next_layer`, `add_trace`,
  `find_fragment`, `transform_card`, `read_all`; `CardCharacterDefinition`, `CardUnlocks` (fragments, unlocking, cards read),
  `CardHack` (a hack's length and fight); `CardGame`'s character choice, turns in a room (`_begin_turns`, `_done_here`), the long
  rest and a layer's opening, `open_hack`; `CardStage`'s two figures, `swap_hands`, Ready; `Hacking._run_cards`.
- "Try them all" (2026-11-27): Tethers are `CardBattle`'s "Tethers" (`tethers`, `_tie`, `_tie_enemy`, `let_go`, `_tether_turn`,
  `_tether_does`, `_fray`, `_snap`, `_loosen`, `_strain_tethers`, `_cut_strongest`) and `cards/CardTethers.gd` (their small cards and
  threads on the stage); the Message is `CardRun`'s "The Message" (`message_of`, `message_offers`, `grow_message`, `event_options`),
  `CardBattle.truth_spoken`, `CardMessageWord` and `CardGame._show_message`; the Blessings `CardRun.blessing_choices`,
  `choose_blessing`, `CardGame._show_blessings`. Both hands: `CardStage`'s seats (`_Seat`, `_use`, `_each_seat`, `apply_move`),
  `CardGame.devices`, `player_of_event`. The rooms together: `CardGame`'s halves (`_together`, `_in_half`, `_here0`, `_room`,
  `_half_done`). Moves and the network: `CardGame.act`, `apply_move`, `_press_for`, `_rules_only`, `take_move`, `play_together`;
  `Net.begin_card_game`, `card_move`, `_card_begin`, `_card_moved`. Hacks for both: `CardHack.players`, `Hacking._run_cards`.
- Suite `cards` (`tests/cards_test_driver.gd`): the content, the rules, the beats, the slots, a run and the screen, headless and with
  everything moving; the gates, two players, layers, the trace, scanning, half-read code, the Devourer, rests, Lethe, oddities, the
  screen for two, and a hack played as the card game; Tethers, the Message, the relics and Blessings, both hands and the rooms
  together, a hack for two on one screen. Suite `net` plays a card hack together across two Godots.
