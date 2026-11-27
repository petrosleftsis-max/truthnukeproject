# The card game as Prometheus's hacking: what was built, the gates' playstyles, and what waits (2026-11-27)

The designer's answers to the hacking twists, co-op and the gates as characters (2026-11-27), verbatim:

> Yes go ahead and do the suggestested co op way. The differences to fit the game is as is:
> - Up to two, as the game already is
> - I'd like to tackle adding a local co op, if uncertain how to, just give me suggestions
> - Do all of Prometheus' theme twists. The characters will be the ones mentioned in the gates (world, Hermes, pandora,
>   yaldabaoth, etc) they'll be of equal power but different gameplay which will be unlocked throughout the game's progress.
>   Suggest playstyles for them
>
> 1. Go ahead / 2. No, they will be the characters / 3. I'd like to try it / 4. I like it, do it. This can also be how the decks
> are acquired, by getting fragments of a code / 5. It's a cool idea but it'll go on another minigame / 6. Sure go ahead /
> 7. Explain what this does exactly after you're done with the rest / 8. Sure / 9. No / 10. Explain what this does exactly after
> you're done with the rest / 11. Sure / 12. No, maybe not yet at least / 13. Yes / 14. Sure some could be / 15. This depends on
> what we do with the characters / 16. Yes
>
> Keep the other minigames in the code, we might use them later on, but from now on this is the main hacking minigame

Every number below is **PROPOSAL** (the ledger's word): mine, to be tried and changed. Every picture and sound is a slot with a
stand-in (`data/card_looks.tres`, SoundBank's "The card game" group). The decks are placeholders made of the cards there are: the
designer makes the real cards.

## 1. What was built

| # | Twist | As built |
|---|---|---|
| 1 | Down through a system's layers | A whole run is 3 layers (`CardRun.MOST_LAYERS`), each its own map of 12 floors and its own boss: the Colossus, the Devourer, the Core. A fight written for any layer is made harder the deeper it is: health x1 / x1.25 / x1.5, Might +0 / +1 / +2 (`CardBattle.LAYER_HEALTH`, `LAYER_MIGHT`); one written for its own layer (`CardEncounterDefinition.layer`) is played as written. The map comes apart into pixels the deeper it is (a screen shader, 2 and 3 pixels a dot, rows slipping now and then), and each layer has its own backdrop slot (`map_background_2`, `_3`). |
| 3 | The trace | One meter for the run, 0 to 100, on the top bar: every fight +1, an elite +3 more, every turn a fight lasts past 6 +1, and a loud card its own (`CardDefinition.trace`: Crushing Blow and Cleave 2, Last Stand 3, Plague 2, Flurry and Fortress 1). The system answers: from 25 and from 50 its programs have a Might more each, from 50 a tenth more health, at 75 a Glitch goes into every deck (once), at 100 he is traced and the run is lost. Cover Tracks at a rest takes 15 off; some oddities raise or lower it. |
| 4 | Half-read code, and the decks from fragments | An effect can be struck out (`CardEffect.struck`): the card shows `#### ### ######` for it until it has been played once, in any run (`CardUnlocks.read`, a Campaign flag, so a save keeps it). It does its work all the same. Heavy Swing (every deck has one), Venom Strike, Rally, Deep Breath and Deep Scan have one. Notes on the Wall reads every half-read card of the deck at once. **The decks are found in pieces:** World is open from the start, every other gate needs 3 code fragments (`CardCharacterDefinition.fragments_needed`). A fragment comes from beating a layer's boss, a Memento, a hack that gives one (`HackDefinition.fragment_of`), or a conversation (`do Hacking.find_fragment("hermes")`). It always goes to the locked gate nearest to opening (the fewest left, then the lowest gate). |
| 6 | What the system lets him see | On the second layer about 15 in a hundred enemies are encrypted, on the third 35 (`CardRun.DARKNESS`): their intent shows only a cipher (`intent_encrypted` slot) until they are **Scanned**. Every deck starts with a Scan (0 energy: Scanned, draw 1); Deep Scan (uncommon) scans all of them. The Core shows nothing at all until Scanned, and late in its fight rewrites itself, encrypted again. |
| 8 | Lethe and un-forgetting | A card taken out of a deck (the shop's removal, an event, the long rest) is forgotten. As the last layer begins, every forgotten card comes back into its deck, upgraded, and the layer's opening screen says what came back. A Status card taken out stays gone. |
| 11 | A program that devours his code | The Devourer, the second layer's boss (`data/card_enemies/devourer.tres`, the Glutton status): it eats cards from your draw pile (Devour, 2 at a time), hits 3 harder for every card it holds (Gnash; `CardEnemyMove.damage_per_held`), and Gorges once it holds 3. Feed it a Status card and it chokes: it spits everything it ate into your discard pile and does nothing on its next turn. It feeds you its own bile (Regurgitate: 2 Slimed into your draw pile), which you can leave in the deck for it to choke on. Each quarter of its health lost, one card it ate falls back out into your hand. |
| 13 | Rests as the game has them | A rest room is a short rest: **Patch** (mend 30%), **Study** (upgrade a card), **Cover Tracks** (trace -15), or in co-op **Mend** your partner (30% of theirs). After each layer's boss (with more layers to go) comes **the long rest**: everybody mends fully, then each reshapes their deck: a card out (forgotten) or a card upgraded, or neither. |
| 14 | Oddities as the network's events | Six events (`data/card_events/`): the Looping Corridor, the Shifting Room (a card rewritten into another of its rarity), the Talking Thing, Notes on the Wall, a Memento (a fragment, for trace) and a Stash. Their choices can raise or lower the trace, find a fragment, put a card in (a Glitch, for gold), read the half-read cards, or rewrite a card (`CardEventOption`'s new fields). "Some could be": the four old events stay. |
| 16 | Two players | Up to two, Slay the Spire 2's way: below. |
| juice | Section 11 of the juice proposals | A card played types across as a line of code over where it goes off ("> exec thrust -t rat"), ticking as it types. A hit tears the figure into offset strips for an instant (the Flashes dial scales it). A faint scanline over the whole screen (`scanlines` slot, else drawn). Terminal beeps (`card_terminal_beep`) on choosing a room and voting. The map is a network: links of dashes, the walked ones lit with packets running along them. |

**Not built**, as answered: 2 (the gates are the characters, not the energy), 5 (another minigame), 9, and 12 ("not yet").

### The gates as characters

`data/card_characters/<key>.tres` (`CardCharacterDefinition`): name, gate, health (60 for all), starting deck (11 cards: the old
10 with a Scan, two of them swapped for the gate's leaning), starting relic (Field Dressing for all), how it plays, fragments
needed, and a picture slot (shown in the fight and on its card in the choice). A card belongs to everybody unless its Character is
set (then only that gate is offered it). **The choice:** the card game asks who hacks before its first room; locked gates show how
many of their fragments are found. On the title screen a **Practice** box opens every gate, to try them.

### The card game as the hacking minigame

`HackDefinition` has a new **Played As** group: **Minigame** Cards (the default) or Board (the three boards, kept as they were).
Every hack there is now plays as the card game, since the default is Cards; give one Board to play its board. **The Card Game**
group: **Card Length** (one fight, a short layer of 6 floors, a whole layer, the whole system), **Card Encounter** (who is fought in
one fight; empty for one of **Card Tier** on **Card Layer**), and **Fragment Of** (a gate whose code it gives when got through).
`Hacking.run` opens the card game over the world (a layer of its own, the world held as for the boards) and maps how it ends: won
is success, lost or traced is failed (its Sets Off, Locks For Good and alert as before), left before the end is walking away. The
hacker's Intellect sets how much health the decks come in with: 0.6 to 1.4 of it, 1 at Intellect 30 (`Hacking.health_share_for`).
A board's tries, retry costs, clock, hints and simplifying are not used by a card hack.

## 2. Co-op: what was built, and the network

Built (rules, and the one-screen game):

- **Each has their own** character, deck, piles, hand, energy, health, Block, statuses, relics, gold, rewards and shop (`CardBattle.players`, `CardRun.players`).
- **The enemies** hit everybody standing, each blocking for themselves; their health is x2 x1.1 on the first layer (x1.2, x1.3 deeper: `COOP_LAYER_FACTOR`), and their Block twice as much.
- **Ready**: each says Ready when done; once both have, the enemies act. Playing a card takes your Ready back. Overtime makes only that player Ready.
- **Down, not out**: a player at nothing is down for the fight (their hand gone); the fight is lost only when both are. Won, the one down gets up with 1 health.
- **Cards for a partner** (`CardDefinition.Target.ALLY`, offered only to two: `coop_only`): Shared Shield, Handoff, Patch Up, Uplink, Overclock. Their Block, mending, drawing, energy and statuses go to the partner (to yourself alone).
- **The map by vote**: each votes for a room, a dot in their colour by it; agreeing goes there, differing goes to one of the two by lot ("By lot: Fight").
- **The rooms in turn**: rewards, a rest, a shop, an event, a chest and the long rest are each player's in turn ("Hermes chooses."), the first player's then the second's.

**Local co-op, one screen** (built): "Two players, one screen" on the choice. The fight shows both figures side by side and the
hand of whoever's it is, marked on their figure; **Swap** (or Tab) shows the other's hand, Ready (Space, Triangle) is the shown
player's and brings up the other's hand while they still play. It is a shared screen: either player's mouse, keys or pad works it.

Suggestions for more (not built):

1. **Each player on their own device.** The main game's `Coop` knows each player's device (`Coop.acting` on every press). The card game could make a press from a player's device show and play that player's hand, so nobody needs Swap: player 1 on the keyboard and mouse, player 2 on a pad, each with their own cursor (the main game's `Pictures` "second pointer" is the model).
2. **Both hands at once.** Two smaller hands, one each side of the screen, each with its own energy orb and Ready, played at the same time. Slay the Spire 2 shows only your own hand (it is online), so this is our own.
3. **Simultaneous rooms.** Rewards, shops and rests for both at once, each on their half of the screen, instead of in turn.

**Network co-op (two machines) is not built.** The rules were made for it: every fight is seeded (`CardBattle.rng`), and
everything a player does is a move that can be sent and played on the other machine in the same order: `play_as(by, index, who)`,
`set_ready(p, on)`, `vote(p, id)`, and the room choices. The plan, in the game's own network's terms (`docs/multiplayer_plan.md`):

- The host starts the run and sends its seed and both characters (`Net`, a new `card_run(seed, characters, layers, floors)`); the joiner opens the same run.
- Every choice is a move from the machine of the player it is for (`Net.card_move(kind, args)`, checked for its sender and its types as every other RPC is), played on both in the order the host gives: play, ready, swap is local only, vote, take a reward card, skip, rest, buy, choose an event option, pick a card.
- Each machine shows its own player's hand only (no Swap), and the rooms become simultaneous (each machine chooses its own player's reward, shop, rest).
- A hack outside a fight is already the hacking player's to play on their machine (`Net.hack_afar`); a card hack goes the same way with no more work, alone.
- What it costs: the run's rolls that the screen makes (an event, a shop's stock) have to come in the same order on both machines, so the rooms would be made on the host and sent.

## 3. Playstyles for the ten gates (suggestions)

All ten at 60 health and 11 cards, as strong as each other, each played its own way. The decks there are placeholders; the
"suggested cards" are what would make each play as described. Their text is also on each character's Playstyle (its first line
on the choice, all of it in the tooltip).

1. **World**: steady and plain. Strikes, guards, a heavy swing: a little of everything, nothing it leans on, the measure of the others. Cards: plain attacks and Block that grow with upgrades; a card rewarding an Attack and a Skill played in one turn.
2. **Hermes**: fast and light. Many cheap cards a turn, drawing as it goes. Cards: zero-cost attacks, cards growing cheaper as the turn goes, a finisher dealing more for every card played this turn, a Relay (every third card a turn draws one). Weak against Overtime and Toll.
3. **Pandora**: opens the box. Poison, Weakened and Exposed on the enemies, and her own Status cards (Wounds, Glitches) played for effects rather than dead draws. Cards: one stronger for each Status card in the deck, one throwing a Status card at an enemy, a Power drawing a card whenever a Status card is drawn.
4. **Charon**: pays the ferryman. Health for power, cards exhausted for good effects (ferried across), gold that counts in a fight. Cards: one costing 3 health and hitting hard, cards that exhaust a card from the hand for a bonus, a Power mending a little whenever a card is exhausted.
5. **Tartarus**: the pit. Block piled high and kept from turn to turn, Entangled and Brittle on the enemy, slow heavy blows through Block. Cards: a Power keeping Block between turns, a blow dealing damage equal to your Block, cards that Entangle.
6. **Nemesis**: retribution. Spines, blows struck back when struck, damage growing with the damage taken this fight. Cards: Riposte's kin, a Grudge status adding to every hit for each hit taken, a Taunt drawing every enemy's attack to her (in co-op, keeping the partner safe).
7. **Sophia**: wisdom. Looks ahead (the next cards seen, some discarded), upgrades cards in the fight, plays from the discard pile, reads half-read code as it is drawn. Cards: Study and Deep Breath's kin, one upgrading every card in the hand, a Power drawing one more card a turn.
8. **Ogdoad**: the eight. Pairs and cycles: cards in twos (playing one draws its twin), effects changing on even and odd turns, a count to eight paying off every eighth card played. Cards: twins sharing a name, a Power counting cards played, a card stronger on an even turn.
9. **Gnosis**: knowledge revealed. The Scan deck: bonuses against Scanned enemies, its own Second Sight, punishing what it foresees (more damage to an enemy about to attack, Block for exactly what is coming). Cards: one Scanning every enemy and drawing, one cancelling a foreseen move, cards stronger against a Scanned enemy.
10. **Yaldabaoth**: the demiurge. Rewrites the code: cards in the hand turned into others, cards copied, a card corrupted stronger and louder (raising the trace each play). High risk, a high trace. Cards: one turning the hand into random cards a rarity higher, a Power copying the first card played each turn, loud cards paying off big.

## 4. Twist 7, Tethers: what it would do exactly

**Built** (section 8), as described here, but for enemies cutting the strongest Tether only and an enemy's Tether breaking a strand for
every 6 health its holder loses.

In the main game a held spell is tied to what it holds by a tether that frays and can be let go. In the card game:

- A **Tether card** (a new card type beside Attack, Skill and Power) is played onto a target, an enemy or (in co-op) the partner, and **stays on the table** beside it as a small card, instead of going to the discard pile. While it stays, it does its thing every turn: holds an enemy Weakened, drains 3 health a turn into you, keeps 4 Block on your partner at the start of each of their turns.
- It has a **strength**, shown on it (say 3), that **frays by 1 at the end of each of your turns**. At 0 it **snaps**, and snapping does something of its own (a burst of damage, a last Block, a card drawn), so letting it run out is a plan, not only a loss.
- You can **renew** it (play another copy onto it: back to full strength) or **let it go** early (press it: it snaps now, with its snap effect).
- **Slots**: you can hold only so many at once (2 to start, more from relics or a gate's cards), so which to keep up is the choice.
- Enemies can **cut** one (a move that tears your strongest tether), and an enemy's own tethers on you show as the same cards on your side, which you can break by hitting the enemy holding them hard enough (its strength falls with the damage it takes).

It suits a gate that holds things: **Tartarus** (holding enemies down) or **Charon** (tethers that drain). Size: medium (a new card
type, a row of held cards on the stage, the fraying and snapping, two or three enemy moves).

## 5. Twist 10, The Message: what it would do exactly

**Built** (section 8) with the designer's two changes: it does not end the last fight by itself ("The Message would not just auto win
the fight, but still be powerful"; at the last boss it says every word twice), and the player chooses how it grows ("Allow the player
to choose how the Message grows and what effects it gets from the events which will have random options").

- Every run starts with **one card that cannot be removed, exhausted or transformed**: the Message the Messengers carry. It is in your deck in every fight.
- **It starts nearly empty**: played, it does very little (draw 1, say), and it is mostly struck out, as half-read code is.
- **Events add words to it.** Some oddities offer a word of the truth instead of gold or a card ("the system was built to forget"), and each word is a line added to the Message: more damage, Block, a card drawn, the trace lowered. A run's Message is the record of what you found on the way.
- **In the last fight it is the truth spoken.** Against the Core it does what all its words say together, and with enough of them it ends the fight ("The messengers have already found the truth": the Core's encryption breaks, every enemy Scanned and Exposed, or the Core simply stops).
- So how much it says depends on the run: rushing the layers leaves it nearly empty; taking the oddities fills it.

It would sit well with the half-read code already there (its words are struck out until found). Size: small to medium (the
card, a list of words on it, events offering words, the Core reading it).

## 6. Twist 15, with the gates as characters: suggestions

**All three built** (section 8). More Blessings are the designer's to add ("Remind me to add more blessings later on").

The twist was the main game's passives as relics and the run Blessings as a first choice. Now that the characters are the gates,
three ways it could go:

1. **Each gate's own starting relic, from the main game's passives.** World: Iron Hide (start each fight with 4 Block); Hermes: Quick Hands (draw 1 more on the first turn); Nemesis: a Spines relic; Gnosis: Second Sight from the start. This is what "different gameplay, equal power" usually means in Slay the Spire (each character's starting relic). The field is already there (`CardCharacterDefinition.starting_relic`); only the relics are to make.
2. **The Blessings as the run's first choice, after the gate.** Iron (more health), Patient (more energy on the first turn), Swift (more cards drawn on the first turn), chosen before the first room, whatever the gate. Small, and it makes two runs with the same gate differ.
3. **The party's passives as rare relics in the shop and chests** (Cat Burglar, Mercy...), for every gate, so the four Messengers are present in Prometheus's hacking as what he learned from them.

My suggestion: 1 and 3 together (each gate's own relic; the party's passives as rare relics), and 2 only if runs feel samey.

## 7. What waits on the designer (as it stood before section 8)

- The cards: the gates' own cards (the placeholders are the shared cards), their pictures, and each gate's starting relic (section 6).
- Whether the numbers feel right: the trace's sources and answers, the darkness by layer, the Devourer and the Core, the co-op health factors, the Intellect share.
- Twists 7 and 10 (sections 4 and 5), and 15 (section 6).
- Local co-op on devices of their own, or both hands at once (section 2's suggestions); network co-op (section 2's plan).
- Which hacks in the world are one fight, a short layer, a layer or the whole system, and which give a gate's fragment: every hack there is plays as one easy fight for now.

## 8. Built next: "try them all" (2026-11-27, afternoon)

The designer, verbatim:

> Let's try them all, except for the playstyles of each gate, which I'll refine later. The differences will be:
> - During a dungeon or story mode, both players still get to play the hacking game together
> - The Message would not just auto win the fight, but still be powerful. Allow the player to choose how the Message grows and what
>   effects it gets from the events which will have random options
> - Remind me to add more blessings later onkk

"Them all": section 7's list but the gates' own cards. Every number is PROPOSAL; every picture and sound a slot with a stand-in.

| What | As built |
|---|---|
| Twist 7, Tethers | A card Type, Tether. Played onto an enemy, a partner (yourself alone) or yourself, it stays on the table as a small card at their feet, a thread to its holder (`cards/CardTethers.gd`). At the end of each of its holder's turns it does its Effects and frays by 1; at 0 it snaps and does its Snap Effects. Press it to let go early (it snaps). The same card onto the same target renews it. 2 held at once (the Spool relic: 3). Whoever it holds falling: loose, nothing done. Cards: **Leash** (1 Weakened a turn; snaps for 6 damage), **Siphon** (drains 2 a turn), **Guard Link** (4 Block a turn on your partner or yourself; snaps for 4 more). An enemy's own: the **Leech** ties a Leech Line on everybody (drains 2 a turn; every 6 health the Leech loses cuts a strand); the **Severer** cuts your strongest (no snap). Two hard fights with them. |
| Twist 10, the Message | In every deck, never taken out, rewritten or forgotten; at first only "Draw 1" and a struck line. Every event now offers to listen for a word of the truth beside its own options (and A Voice in the Wires is an event of its own for it). Listening offers three ways for it to grow, at random: a **new word** (eleven to begin with, `data/card_message_words/`: 4 damage to every enemy, 5 Block, a card drawn, 1 energy, Exposed or Weakened on every enemy, 2 Poison, mend 3, a Might, a Footing, two hits of 2), a **word deepened** (its number up by its step), or **spoken lighter** (it costs 0, once). The player chooses, or lets it be. Up to six words. At the run's last boss it says every word twice: strong, never a win by itself. |
| Twist 15, the gates' own relics | Each gate starts with its own, named for a passive of the main game's, all about as strong as Field Dressing was: World **Iron Hide** (6 Block as a fight starts), Hermes **Quick Hands** (2 more cards the first turn), Pandora **DoT Master** (2 Poison on every enemy as a fight starts), Charon **Bandolier** (12 gold a fight won), Tartarus **Bulwark** (2 Block every turn), Nemesis **Drills** (2 Spines as a fight starts), Sophia **Contest Insight** (1 energy the first turn), Ogdoad **Agile** (1 Footing as a fight starts), Gnosis **Measured Eye** (every enemy Scanned as a fight starts), Yaldabaoth **Elemental Affinity** (1 Might as a fight starts). Placeholders: the gates are the designer's to refine. |
| Twist 15, the Blessings | The run's first choice, after the gate: up to three offered (all three there are now: **Iron**, 10 more most health; **the Patient**, 1 energy the first turn; **the Swift**, 2 more cards then), one taken or none. Never in a chest or a shop. More are the designer's to add: a relic file of Rarity Blessing. |
| Twist 15, the party's passives | Rare relics in chests and shops, for every gate: **Night Hunter** (Cyrus's: an enemy falls, 1 energy), **Mercy** (Alithia's: mend 2 every turn), **Breaker** (Enfina's: fights start with 2 Might), **Meditate** (Prometheus's: 2 energy the first turn). |
| Both hands at once | Two players on one screen: each hand on its player's half, each with its own energy, piles and Ready, played at the same time. A choice on the character choice (else one hand at a time with Swap). |
| Each on their own device | The main game's two players' own devices (Coop); otherwise the keyboard and mouse the first player's, a pad the second's (with two pads one each, the mouse still the first's). A key or pad press plays its own player's hand; in the rooms it brings the focus to their half, where they left it. With no pad, the keyboard and mouse play either hand. |
| The rooms together | Rewards, rests, shops, events, chests, the Blessings and the long rest for both at once, each on their half ("Done. Waiting for..."), a choice on the character choice (else in turn). |
| Network co-op | Built as planned in section 2: both machines play the same run from one seed; every choice is a move that goes to the host, is numbered there and done on both in that order (a card played by its id, Ready, a Tether let go, a vote, a gate, a Blessing, a reward, a rest, a buy, an event's option, a word, leaving). Each machine plays its own player (the host's the first), both hands shown, the other's half saying what they did. The room's random rolls (a shop's stock, a chest, an event's cards and words) are made by the rules as the room is entered or the choice made, so both make the same. From the title screen the joiner follows the host into the card game; the other machine gone, the run goes on with both players here. |
| Hacks for both | "During a dungeon or story mode, both players still get to play the hacking game together": a card hack in the world is now always played by both. Two players on one screen: a game for two there, each on their own device. Over a network: the same game on both machines (a card hack is no longer sent to one player's machine to play alone; in a fight, the other machine waits for how it went as before). |

Also: a relic giving Block at the start of a fight (Iron Buckle) used to lose it as the first turn began; the first turn now keeps it.

What still waits on the designer: the gates' own cards and playstyles (and their relics, if these picks are not right); more
Blessings; every number here once played; pictures and sounds for the new slots.
