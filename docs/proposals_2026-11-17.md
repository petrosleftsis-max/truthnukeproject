# Proposals, 2026-11-17: game feel, the next round

The designer, 2026-11-17: "Do you have suggestions to further improve the game feel?"

**Chosen, 2026-11-17** (the designer, word for word): "1. When someone is hurt, make their idle animation slower, while when
someone's nerve breaks, make it a bit faster / 2. Do a rush that stop / 3. Do all except A hard Blow. "Breathing slower" have it be
their idle animation slowing down for a bit / From section 4 and on do all. I see that the encounter scene and the exploration
scene being different makes the work more. Would it be better if we rework how it works and have it somehow be the same scene?"

So: from section 1 only the pace of the idle (slower while hurt, a little faster once their nerve has broken); from section 2 a
rush that stops; from section 3 a friend falls, a heal answered and won, together, with "breathing slower" the idle animation
slowing for a while; sections 4 to 9 whole. The map becomes the board (7) waits on the question of one scene for maps and fights.
What was built is in `docs/feel_built.md`.

Nothing below was built when it was written. Everything here is a PROPOSAL until the designer picks it. Each idea says how much work it is for me
(small: an evening; medium: a day or two; large: several days) and whether it needs art or sound from you. All of it is view and
feel: nothing rolls on a fight's dice and no rule changes, except where an idea says so. Anything that moves the screen comes with
its Comfort dial. Nothing for the interface, as you asked on 2026-11-17.

Where the game stands: everything in `docs/proposals_2026-11-16.md` is built (`docs/feel_built.md`). What I found thin this time,
by reading the code:

- **Still pictures stand dead still.** Most enemies have no animation of their own. Between blows nothing on them moves but their
  breath in the cold, and when they walk they glide from tile to tile. A board of eight of them reads as cut-outs.
- **Sounds have no place.** Every sound plays from the middle at one loudness: a blow at the far left of the board, a door off
  the screen and a click under the pointer all sound alike.
- **The party do not see each other.** Nobody turns when a friend falls, flinches when one is hit hard, or answers a heal.
- **Stealth's verbs are silent.** A takedown has no sound, beat or rumble: the guard greys and sinks as a body in a fight does. A
  thrown thing has no flight: its noise starts on the tile the moment it leaves the hand. A hiding spot does not stir as somebody
  goes into it.
- **The world shrugs off a blast**, but for the grass and the banners: trees, lamps and the things that stand stay still beside it.
- **Going into a fight is a cut to black**, though it is fought on the ground the party was standing on.

## 1. Life in the still pictures

For everybody without an animation of their own for it. Somebody who has one keeps it, as with the wind-up
(`OWN_ANIMATION_SHARE`).

| Idea | What it adds | Work | Art |
| --- | --- | --- | --- |
| **Breathing** | A slow rise and fall, 1 to 2% of their height about their feet, each at their own pace and never in step with the next; slower the bigger they are | Small | None; an idle animation takes its place |
| **By what they are** | Flyers bob and drift; spirits and images waver; the undead hold stiff and twitch now and then; beasts shift their weight from foot to foot | Small | None |
| **Hurt shows** | Under a third of their health they breathe harder and lean a little; near death they sway | Small | None |
| **Fear shows** | Somebody whose nerve is going trembles, more as it goes | Small | None. **Nerve is a rule, and today the board does not show how near somebody is to breaking (only the codex, once studied, says where they break). This would tell the player more: your call** |
| **Watching** | Standing still, they turn to face whoever is acting near them, as they already turn to whoever hits them | Small | None |

My pick: breathing and hurt shows. The board comes alive, and a glance says who is fresh and who is nearly done.

## 2. Walking with weight

| Idea | What it adds | Work | Art |
| --- | --- | --- | --- |
| **A step in each tile** | Somebody with no walk of their own lifts a little into each tile and comes down in it, with a puff at each footfall, rather than gliding | Small | None; a walk animation takes its place |
| **Big things are heavy** | A big creature's step thuds and throws dust; the biggest shake the view a touch and tap the pad | Small | A heavy step sound later |
| **Small things are quick** | Small ones take quicker, shorter steps: a scamper | Small | None |
| **A rush that stops** | A charge across the board, or somebody shoved, ends in a skid and a puff of dust, as the dash on a map does | Small | None |

My pick: a step in each tile and big things are heavy.

## 3. The party, as a party

| Idea | What it adds | Work | Art |
| --- | --- | --- | --- |
| **A friend falls** | The others turn to whoever has fallen for a moment, and the nearest takes half a step towards them | Small | None |
| **A hard blow, felt beside** | A blow of a third of somebody's health or more makes those of their side next to them flinch | Small | None |
| **A heal answered** | Whoever is healed straightens and breathes easier (with section 1); healer and healed turn to each other a moment | Small | None |
| **Won, together** | As a fight is won, the party turn to one another and their breathing slows, before the words come up | Small | None |

My pick: a friend falls. It is the moment the four feel like a party.

## 4. Sound with a place

| Idea | What it adds | Work | Sound |
| --- | --- | --- | --- |
| **Heard from where it happens** | Every sound of a fight or a map heard from its side of the screen, quieter the further it is from the middle of the view, gone a few tiles off the screen. The music and the interface's own sounds stay as they are | Medium | None |
| **Behind a wall** | A sound in another room, or the other side of a wall, dulled, as the rain is dulled indoors now | Medium | None |
| **A guard heard before seen** | On a stealth map a guard's steps heard from their side when close, so somebody coming round a corner is heard first | Small, after the first | Your steps; a stand-in meanwhile |
| **Voices in a fight** | A slot for each of the four: an effort with a blow, a cry when hurt, a breath when healed, pitched as their voice ticks are | Small | Yours; the slots stay silent until filled |

My pick: heard from where it happens. Every sound already in the game gains from it, and it needs nothing from you.

## 5. Stealth, felt

| Idea | What it adds | Work | Sound |
| --- | --- | --- | --- |
| **A takedown that lands** | A tenth of a second of stillness, a muffled thump, a tap on the pad, and the guard folds down rather than greying and sinking like a body in a fight | Small | A slot; a stand-in meanwhile |
| **A thrown thing flies** | It arcs from the hand with its shadow under it, lands with a clatter where the ripple starts and skitters a little; a dart is a quick streak | Small | A slot for the clatter |
| **A hiding spot that answers** | A bush, a barrel or a cupboard shakes as somebody goes in or comes out, with a rustle or a creak, and settles | Small | Slots |
| **Holding your breath** | As a guard's look passes over somebody hidden or in the dark without seeing them, the world goes quiet a moment and the heartbeat skips | Small | None |
| **A body dragged** | A scrape as it goes and faint marks behind it, fading. Only to look at: no guard sees them | Small | A slot |

My pick: a takedown that lands and a thrown thing flies, the two things done most on a stealth map.

## 6. The world shaken by a fight

| Idea | What it adds | Work | Art |
| --- | --- | --- | --- |
| **Trees and things that stand, shaken** | A blast beside a tree shakes its crown and knocks leaves loose; a crate or a statue rocks; a lamp post's light swings | Small | None |
| **A blast's light** | A fire blast or a bolt of lightning lights the walls and the figures about it in its colour for a moment, on the map's own light | Medium | None |
| **Dust from above** | Underground and under a roof, a heavy blow or a blast shakes dust and grit down from above | Small | None |
| **Falling away from the blow** | Somebody felled tips over away from whoever felled them and lies down, rather than greying and sinking where they stood; a "dead" animation of their own keeps its place | Small | None |

My pick: a blast's light, the one that makes a fireball feel hot; then falling away from the blow.

## 7. Into a fight

| Idea | What it adds | Work | Art |
| --- | --- | --- | --- |
| **The map becomes the board** | Caught on a map or walking into a fight, no black: the picture holds, the board's lines draw out from the party, the other side steps to its places and the music turns, and the fight begins where the party stood. Back the same way once it is won. The fight is a scene of its own, so the picture has to be carried across: that is the work | Large | None |
| **A look at what you face** | A fight without a boss's reveal opens with the view passing over the other side and coming back to whoever acts first; about a second and a half, and any press skips it | Small | None |
| **Placed with a thump** | Placing the party before a fight, each lands on their tile with a little hop and a puff; two swapped slide past each other | Small | None |

My pick: a look at what you face. The map becomes the board is the biggest change to how going into a fight feels, and worth
deciding on its own.

## 8. The view

| Idea | What it adds | Work | Art |
| --- | --- | --- | --- |
| **Never quite still** | In a fight the view drifts a few pixels, slowly, so the layers of depth always move against each other a little and the board reads as a place rather than a picture. Under the Camera sway dial | Small | None |
| **Weather near the eye** | Now and then a few big soft drops, flakes or leaves pass very close to the view, fast and blurred, as things at the screen's edge do: depth for the weather | Small | None |

My pick: never quite still, as an experiment with a switch. Some find a drifting view restful and some do not.

## 9. Music that follows, all of it

Still open from section 21 of 2026-11-07, and half built: the pulse on a watched map, the music muffling as a guard grows sure.
The rest needs your music in parts.

| Idea | What it adds | Work | Music |
| --- | --- | --- | --- |
| **Layers** | A place's music in up to three parts (calm, wary, fighting) that come in and go out with a stealth map's alert and a fight's turn, rather than one track switched for another | Medium | Your parts; slots, silent until filled |
| **The turn of a fight** | When the other side's last leader falls, or the party is down to one, the music thins to its drums or swells | Small, with layers | The same parts |

My pick: layers, the day you have a track in parts to try it on.

## What I would do first

Most feel for least work, none of it needing art:

1. Breathing and hurt shows (1), with a step in each tile (2).
2. Heard from where it happens (4).
3. A takedown that lands and a thrown thing flies (5).
4. A friend falls (3).
5. Trees and things shaken, and falling away from the blow (6).
6. A look at what you face (7).

And one large one to decide on its own: the map becomes the board (7).

## Still open from before, not raised again

- Steps by what is underfoot and idle life (2026-11-16, section 1): waiting on your sounds and an idle variation each.
- Barks (2026-11-06, section 3): passed over twice.
- The hours, the world's own story and Forgetting (2026-11-07, section 21).
