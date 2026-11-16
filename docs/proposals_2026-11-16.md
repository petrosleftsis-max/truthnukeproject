# Proposals, 2026-11-16: how the game looks and feels from here

The designer, 2026-11-16: "Suggest ways we can improve the game visually and in terms of 'game feel' from here on."

Nothing here is built. Everything here is a PROPOSAL until the designer picks it. Each idea says how much work it is for me
(small: an evening; medium: a day or two; large: several days) and whether it needs anything from the artist.

Where the game stands, so this does not repeat it. A blow already has a lot: what flies, a flash at the hand, a burst where it
lands, hit-stop, shake, slow motion for the last blow, recoil, marks on the ground, the camera framing it. Light, weather, the
day going round, depth (walls, layers, the cutaway) and water are in. What is thin, by what I found in the code:

- **Walking on a map** is full speed the instant a key is pressed and the camera is nailed to the leader.
- **The attacker's own body** does nothing when it strikes: the blow has feel, the one who throws it stands still.
- **The pad never rumbles**, and a press made a moment too early is lost.
- **The interface does not move**: the fight's HUD has no animation of its own but the health bars.
- **Sound does not follow the picture**: nothing is muffled, ducked or filtered by what is happening.

## 1. Walking on a map

| Idea | What it adds | Work | Art |
| --- | --- | --- | --- |
| **Ease in and out** | A tenth of a second to reach full speed and to stop, so the party has weight. Turning on the spot stays instant | Small | None |
| **Followers with a mind** | Those behind fan out a little when the leader stops instead of standing in a line, and catch up with a short jog | Small | None |
| **Steps by what is underfoot** | Stone, wood, grass, water (water is in): a different step sound, and a puff of dust or a flick of grass | Medium | Sounds are yours; I make stand-ins |
| **Wet prints** | Coming out of water, dark footprints for a few steps, fading | Small | None |
| **Idle life** | Standing still a while, somebody shifts, looks round, Cyrus's tail moves | Small to wire | An idle variation per character |
| **A dash you can feel** | The stealth map's dash gets a stretch along its way, a streak and a skid of dust at its end | Small | None |

My pick: ease in and out, and followers with a mind. They change every minute spent on a map and need no art.

## 2. The map's camera

| Idea | What it adds | Work | Art |
| --- | --- | --- | --- |
| **A soft follow** | The camera trails the leader by a fraction of a second and settles, instead of being fixed to them | Small | None |
| **Looking ahead** | It leans a little the way the party walks, so more of what is coming shows | Small | None |
| **Rooms that frame themselves** | Walking into a small room or under a roof, it eases in a little; out in a yard, back out | Medium | None |
| **A look about** | Holding a key (the right stick on a pad) slides the view a few tiles without moving anybody | Small | None |
| **Arriving** | Coming onto a map, a short glide from the way in to the party | Small | None |

My pick: the soft follow and looking ahead, tried together, each with its own number to tune.

## 3. Things to use and to find

| Idea | What it adds | Work | Art |
| --- | --- | --- | --- |
| **A door that swings** | Open and shut over a fifth of a second with a creak and a thud, instead of changing at once | Small | None for the placeholder |
| **In reach, it shows** | The thing the interact key would use gets a soft outline and its prompt slides in beside it | Small | None |
| **Picked up** | What is taken rises, shrinks towards the bag's corner of the screen and lands with a tick | Small | None |
| **A lamp put out** | A puff of smoke, the light dying over a moment, the dark coming in from the edges | Small | None |
| **A wall broken** | Rubble thrown the way of the blow, dust hanging, the camera kicked | Small | A rubble picture later |

My pick: the door and "in reach, it shows". Both are touched constantly.

## 4. Depth, the next steps

| Idea | What it adds | Work | Art |
| --- | --- | --- | --- |
| **Dappled shade under a tree** | The crown's shadow on the ground and on whoever stands under it, moving with the wind | Medium | None |
| **A crown that sways** | The tree's crown leaning and rustling with the wind, leaves shaken loose in a gale | Small | None |
| **The far away, hazier** | A backdrop a little paler and softer than the ground, more so in mist: it reads as distance | Small | None |
| **Things at the screen's edge** | A branch, a banner or an eave drawn large and soft at the very front, sliding fastest as the view moves | Small | A picture each |
| **More that stands** | Crates, pillars, statues, lamp posts and railings as things that stand, as the barrels are | Small each | A picture each: this is the artist's biggest lever |
| **A step down that looks like one** | Climbing and dropping between heights with a short hop and a puff of dust on a map, as in a fight | Small | None |
| **Wall tops and faces drawn** | The artist's own wall face (256 x 192) and top, with a normal map so lamps rake across them | None for me | The pictures |

My pick: dappled shade and the swaying crown (you liked the tree), then the far away hazier.

## 5. Water

| Idea | What it adds | Work | Art |
| --- | --- | --- | --- |
| **A waterline** | Whoever wades is drawn cut off at the ankle or the knee with a bright line where the water meets them, so they are in it, not on it | Medium | None |
| **Depth by colour** | Darker towards the middle of a pool, paler at its edges | Small | None |
| **Walls and trees mirrored** | The world's own reflection, not only the figures' and the lamps' | Medium | None |
| **Something landing in it** | A blast, a body or a thrown thing sends a ring and a splash | Small | None |

My pick: the waterline. It is what makes wading read as wading.

## 6. A blow, from the side of whoever throws it

| Idea | What it adds | Work | Art |
| --- | --- | --- | --- |
| **Wind-up and follow-through** | The attacker leans back a moment, then goes forward into the blow and settles: a lean and a stretch of the figure as drawn, no new frames | Medium | None; a real animation later takes its place |
| **Stepping in** | A melee blow takes a short step towards its target and back | Small | None |
| **Facing** | Everybody turns to face what they aim at, and whoever is hit turns to whoever hit them | Small | None |
| **The caster's light** | A spell lights its caster in its colour as it gathers, brighter the deeper the gate | Small | None |
| **Blocked and resisted, felt** | A blow that is resisted lands with a duller sound and a smaller burst; a vulnerable one rings | Small | None |

My pick: wind-up and stepping in. It is the largest gap in the fights: everything about a blow moves but the one who makes it.

## 7. The pad in your hands

| Idea | What it adds | Work | Art |
| --- | --- | --- | --- |
| **Rumble** | A tap for a hit, a heavier one for a big hit or a fall, a roll for thunder and for a wall coming down, a heartbeat when one of the party is near death. A slider in Options, off by default on a keyboard | Small | None |
| **A press a moment early still counts** | A key pressed in the last fifth of a second of an animation is acted on as it ends: End Turn, the next skill, a move | Medium | None |
| **Holding to repeat** | Holding a direction walks the cursor on in a fight, faster after a moment | Small | None |

My pick: rumble first. You play on a PlayStation pad, and it is the cheapest feel there is.

## 8. The interface in motion

| Idea | What it adds | Work | Art |
| --- | --- | --- | --- |
| **Buttons that answer** | A button swells a little under the pointer and dips when pressed; a refused press shakes its head | Small | None |
| **Panels that arrive** | Tabs, tooltips and menus slide or fade in over a tenth of a second instead of appearing | Small | None |
| **Whose turn** | As a turn begins, their face in the queue steps forward and their action bar deals itself in | Small | None |
| **Numbers that count** | Gold, castings and health count up or down to their new value | Small | None |
| **Choosing the look** | The six looks drawn on 2026-11-13 (O to T, R recommended) are still waiting for a pick; everything above would be built on the one chosen | Large | Yes, with the artist |

My pick: buttons that answer and whose turn. Choosing the look is the bigger step whenever you are ready for it.

## 9. Sound that follows the picture

The sounds themselves are yours. These are things the game does with them.

| Idea | What it adds | Work |
| --- | --- | --- |
| **Muffled when it should be** | Music and the world dulled behind a menu, during slow motion, indoors while it rains outside, and while hidden in the dark | Small |
| **Music that gives way** | The music dips for a line in a bubble, a boss's reveal and a killing blow, and comes back | Small |
| **Echo by place** | A tail on every sound underground and in a hall, none out of doors | Small |
| **A voice for each speaker** | A soft tick as a line types out, pitched for who speaks | Small |
| **Sound by place, and music that follows the danger** | Still open from section 21 of the proposals of 2026-11-07 | Medium |

My pick: muffled when it should be, and music that gives way.

## 10. Conversations

| Idea | What it adds | Work | Art |
| --- | --- | --- | --- |
| **Words that move** | A word that shakes, waves or comes slowly, written into the line | Small | None |
| **The speaker steps up** | Whoever speaks is lit and a little forward, the others dimmed; a portrait bobs as it changes | Small | None |
| **The camera listens** | A slow push in over a long exchange, bars top and bottom for the lines that matter | Small | None |

## 11. Life about the place

Still open from section 21: birds that take off as the party comes near, rats in the lab, a city's people with bubbles of their
own. To them I would add a cat that watches from a wall top, moths at a lamp at night, and grass and banners that bend as
somebody passes or a blast goes off beside them. All small to medium; each animal wants a picture.

## 12. Comfort

As more moves, some players will want less. One group in Options: how much the screen shakes, how bright flashes are, slow
motion on or off, rumble strength. Small. Worth doing before much more is added, so every new effect is born with its dial.

## What I would do first

Most feel for least work, none of it needing art:

1. Rumble (7).
2. Wind-up and stepping in (6).
3. The soft follow and looking ahead, with ease in and out (2 and 1).
4. The door that swings and "in reach, it shows" (3).
5. Buttons that answer and whose turn (8).
6. Muffled when it should be (9).
7. The waterline (5).
8. Dappled shade and the swaying crown (4).
9. The comfort dials (12), alongside the first of these.

For the artist, the three things that would lift the look most: a wall's face and top, a handful of things that stand (crates,
pillars, a lamp post), and one idle variation per character.
