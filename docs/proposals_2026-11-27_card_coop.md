# The card game in co-op - proposals, 2026-11-27

The designer, 2026-11-27: "Suggest ways to implement co op into the card mode as well for when multiplayer is on".

Nothing here is built. Sizes are relative (**S** small, **M** a good piece, **L** the biggest here); every number is PROPOSAL.
Two players at most, as everywhere (`Coop.MAX_PLAYERS`), each in their own colour (`Coop.COLOURS`), and **the same rules on one
screen as over a network** (the designer, 2026-10-31). Twist 16 of `docs/proposals_2026-11-26_card_game.md` ("each player holds
two of the party's suits") is one way of dressing this; nothing below needs it or the four suits.

## What the game already has for it

- **The fight's rules are already network-shaped.** `CardBattle` is rules only, seeded, and nothing in it listens to the screen:
  the same fight from the same seed, given the same plays in the same order, comes out the same on two machines. That is how the
  tactics fights already go over a network (`Net`: the host's moves in order, `_history`, a joiner seated mid-fight catching up by
  playing them through).
- **Two players on one screen:** `Coop` knows each player's device (the keyboard and mouse, or a pad), the gate gives presses to
  whoever has the focus, and Pings point at things in the player's colour.
- **The card game already plays with a pad:** left and right through the hand, a button to play, one to end the turn.
- **What changes:** the fight has one player now (`CardBattle.player`) and the run one deck (`CardRun.deck`); co-op makes both of
  those two.

---

## 1. How the two of you fight

1. **Two hands, one fight, together.** Each player has their own deck, hand, energy, health and Block. Both play in the same turn,
   in any order, and each presses Ready; the enemies act once both are ready. The genre's usual co-op, and the most lively. **L**
2. **Two hands, taking turns.** As 1, but one after the other: your turn, your partner's, then the enemies'. One hand on screen
   at a time, slower, simpler on one screen and easier to follow. **M**
3. **One deck, two pilots.** One shared deck and hand; the players take turns playing it (a turn each), or either plays whatever
   they like. The smallest change; a puzzle solved together. **S**
4. **One deck, two roles.** One plays the cards; the other has a small hand of their own each turn, of support: reveal an
   intent, Block 3, swap a card for the top of the draw pile, Expose an enemy. Good for a partner newer to deckbuilders. **M**

## 2. Playing together (two hands)

5. **Cards for your partner.** A card can aim at your ally: Block for them, mending, a card drawn into their hand, energy next
   turn, a card handed from your hand to theirs. The start of support decks. **M**
6. **Combos across hands.** What one puts on an enemy the other's cards feed on (that already works with shared statuses), and a
   few cards that reward your partner's play this turn ("If your partner played an Attack this turn, deal 4 more"). **S**
7. **Energy each, or one pool.** Each their own 3 is clean; one shared pool of 6 makes every turn a negotiation. **S**
8. **Whom the enemies hit.** Each enemy attack picks a player, shown by the intent's colour; rules can choose by it (the player
   with less Block, more health, whoever hurt it last), a blow at "both" hits each, and a Taunt card pulls blows to you. **M**
9. **Falling and getting up.** At 0 health a player is down: their hand goes, the other fights on, and the fight is lost only when
   both fall. Won, the fallen one gets up at a little health; a card can pull them up mid-fight. **S**

## 3. The run together

10. **Choosing the way.** Both choose the next room; if you agree, you go; if not, whoever chose first this time, the leader, or a
    coin decides. Pings point at rooms. **S**
11. **Each their own rewards.** Each chooses a card from their own three; gold each their own, or shared; an elite's relic for each
    (or chosen in turn). At a rest each rests or upgrades; in a shop each buys with their own gold; an event's choice is voted. **M**
12. **Harder for two.** With two players enemies have more health (about one and a half times), some fights an enemy more, and the
    elites and the boss more again. **S**
13. **Trading.** At a rest or a shop, give your partner a card (once each). **S**

## 4. Screens and machines

14. **One screen.** The hand area split in two, each half in its player's colour and driven by its own device (the mouse for the
    keyboard's player, a pad for the other); with 2, the active hand only. Each player's health and Block under their own
    picture, side by side. **M**
15. **Two machines.** The same fight on both from the same seed; each machine sends its player's plays (the card's id and its
    enemy) and Ready, and the host puts them in order and sends them on, as the tactics fights' moves go. The run's choices go
    through the host. A joiner seated mid-fight plays it through to catch up, as in the tactics fights. **L**, though the rules are
    ready for it.
16. **Seeing your partner.** Their hand (face down, or face up for planning), their energy, a ghost of their aiming arrow in their
    colour, and their Ready; ping a card or an enemy ("play this", "hit that one"). **M**
17. **Joining and leaving.** One who joins mid-run comes in at the next fight or on the map with a starting deck; one who leaves
    takes their deck out (the other fights on), or their partner plays both hands. **M**

---

## How Slay the Spire 2 does it (looked up 2026-11-27)

The designer asked. Slay the Spire 2 is in Early Access and changes with its patches; this is from its community wiki
(slaythespire.wiki.gg, "Slay the Spire 2: Multiplayer" and "Rest Sites") and several co-op guides, which mostly agree.

- **Who:** up to 4 players, online only through Steam friends (no couch co-op), each choosing a character (the same one twice is
  allowed). The host chooses the Ascension, and co-op has its own Ascension track.
- **Each their own:** deck, health, energy, gold, relics and potions.
- **A fight:** everybody plays at the same time, in real time; the enemies' turn waits until every player has ended theirs, and
  one who ended may take theirs back while another is still playing. Cards resolve in the order played, so a debuff first helps
  everyone's attacks after it. A potion can be thrown to another player.
- **The enemies hit everybody:** they do not choose a target. Every attack and debuff lands on all players at once, each blocking
  their own. Their attacks are no stronger; their **health** is: health x players x the act's factor (1.1 in act 1, 1.2 in acts 2
  and 3, 1.3 for the last boss), so two players face x2.2 to x2.6. A few enemy powers scale too. A debuff on an enemy (Weak) helps
  every player.
- **Falling:** a player who dies is out for the rest of the fight, and gets up on the next floor with 1 health if another survived.
- **The map:** everybody moves together and votes; disagreeing, it is chosen at random, weighted by the votes (1 against 3 is a
  25% against 75% chance).
- **Rooms:** an event is met by all at once, most of its choices each their own, some needing everybody to agree. At a rest each
  takes their own action, or **Mends** another player (30% of their most health) instead. The merchant is separate for each
  player, their own stock. A treasure chest holds one relic per player and each picks; two wanting the same one play a quick
  rock-paper-scissors for it. The act's Ancient offers each player their own relics.
- **Co-op cards:** each character has a few multiplayer-only cards, and there are shared colourless ones: giving another player
  Strength, halving the damage allies take, Block transferred to an ally, a summon or a resource for the whole party (names such
  as Tank, Blaze, Intercept, Tag Team, Huddle Up). One multiplayer-only relic.

**What that changes here.** Most of my suggestions are what it does: 1 (two hands, together, waiting for all), 5 (cards for each
other), 9 (falling, up again after), 10 (voting, weighted at random on a tie), 11 (each their own rewards, the merchant each their
own). Where it differs:

- **8, whom the enemies hit:** it hits everybody and makes enemies tougher instead of choosing targets. Simpler (no target to
  show, nobody singled out), and it leaves Taunt-like cards out. I would now follow it: **8b, every blow at both, each blocking
  their own.**
- **12, harder for two:** its x2.2 health (with blows reaching both) against my x1.5 (with blows at one). With 8b, about x2.2.
- **New, from it:** 18. **Mend** at a rest (heal your partner instead of yourself) **S**; 19. a **chest's relic each**, chosen in
  turn, a clash settled by a coin (or its rock-paper-scissors) **S**; 20. **taking your turn back** after ending it while your
  partner still plays **S**.
- **One screen:** it has no couch co-op; this game has, so 14 (two hands on one screen) is ours to work out.

## My pick

**1, 5, 8b, 9, 10, 11, 12 (at x2.2), 18, 19, 20**, played the same on **14** and **15** - Slay the Spire 2's way, with one screen
as well. (Before looking it up: **1, 5, 8, 9, 10, 11, 12**, played the same on **14** and **15**: two hands in one fight, playing at the same time and pressing
Ready, with a few cards for each other, enemies choosing whom to hit, falling without losing the run, and each choosing their own
rewards.) If simultaneous turns feel too busy on one screen, **2** is the same with turns taken.

In steps: the rules first (two players in `CardBattle` and `CardRun`, all tried in the suite with no screen), then one screen,
then the network (the plays as moves, through `Net` as the tactics fights' are).

## Questions

1. **Together or taking turns** (1 or 2), or one deck (3, 4)?
2. **Gold and relics:** each their own, or shared?
3. **Down, or dead:** does a fallen player get up after the fight (9), or does the run end with one fall?
4. **Their deck:** the same starting deck for both, or a different starter each (two "characters" of the card game, which would be
   the first step towards Slay the Spire's characters and archetypes)?
