# Proposals, 2026-11-07

Nothing here is built unless it says so. Everything here is a PROPOSAL until the designer picks it.

## 1. Fallen Friend

**Chosen and built, 2026-11-07: A.** The rest are kept for the record.

As it was built first it was worse than Seeming: a deeper gate, and a step ends it. Ways to make it its own thing:

| Idea | What it does |
| --- | --- |
| **A. As a reaction, when a blow would down an ally** (recommended) | The blow never lands, and they fall down looking dead. Nobody aims at them while the tether holds. Their first blow from there counts as from hiding. It becomes the rescue spell, which Seeming is not, and it is at its best at the worst moment. |
| **B. An enemy's friend falls** | Aimed at an enemy, contested: their whole side believes that one has died. Each who sees it loses nerve as for a real death, and while the tether holds they do not help or follow it. Aimed at a leader or commander, the rest lose their head as if it were down, though it is still fighting. |
| **C. The body stays, and they walk away** | They become invisible and an image of their corpse stays behind. Enemies treat the body as dead, and steps no longer give them away. Close to Invisibility, but with something left for the other side to find. |
| **D. Going to look** | The body draws those of the other side who see it: they walk over to look at it, as Phantom Noise draws them, and whoever looks dead strikes first as they arrive. A trap, with an ally as the bait. |

## 2. The immunity passive, updated

**Chosen and built, 2026-11-07: Closing the gap, every level 8 lower, with Fear at level 1.** Alithia's Unbowed I-VII: Fear 1,
Confused 8, Compelled 16, Blind and Deafened 24, Dazed 33, Choking Ash 46, Stunned 56.

Hesitating, Deceived, Recanted and Accused are out, as asked. That leaves level 16 empty, so here is the ladder as it
now stands, and one way of closing the gap:

| Level | As the old ladder had it | Closing the gap |
| --- | --- | --- |
| 8 | Fear | Fear |
| 16 | *(nothing left)* | Confused |
| 24 | Confused | Compelled |
| 32 | Compelled | Blind, Deafened |
| 41 | Blind, Deafened | Dazed |
| 54 | Dazed, Choking Ash | Choking Ash |
| 64 | Stunned | Stunned |

## 3. Who could be All Knowing

**Chosen 2026-11-07: the Ash Warden has it.** It is the highest of the five levels. It reads the party's prepared spells and what castings are
left, so it is most felt on a boss with several turns and a choice of targets. The Ash Warden and Sixty-Four would
show it best.

## 4. The rest of the enchantment and divination tables

Kept for when the higher levels are revisited, as asked: `docs/proposals_2026-11-06.md` sections 1 and 2. Built from
them: Sleep, Calm, Suggestion (Iris, map only), Detect Magic, Arcane Eye (Mnemosyne), Mesmerise for Prometheus. Not
chosen and still there: Friends, Charm and Hold Still; Crown of Madness and everything deeper; Guidance, Identify,
Augury, Detect Thoughts, Locate, Scry, Find the Path, and everything deeper.

## 5. More ways to tell enemies apart

Not chosen on 2026-11-07, still there in `docs/proposals_2026-11-06.md` section 3: barks, mistakes, the Show-off.

## 6. Spells that make light

**Chosen and built, 2026-11-07:** Dancing Lights with no tether. Flare, in place of Unveil. Instead of Faerie Fire, Votive Flame
marks whoever it hits: for 8 of their turns they cannot hide or go invisible, and it can be dispelled. Daylight, which can
also go on a weapon. Light Void wins over every light source but a spell that says it can win.

Gates and tethers are suggestions.

| Idea | Who | Gate | Tether | What it does | Rests on |
| --- | --- | --- | --- | --- | --- |
| Kindle | Alithia or Prometheus | World | none | A small steady light on a tile, or on somebody's weapon, for 4 of their turns. On a map, 5 minutes | A zone's `zone_light_tiles`; a condition's `light_tiles` |
| Dancing Lights | Prometheus | World | 100 | Three small lights he places and moves with a secondary action | Storm Cloud's moved zone (`zone_moves`) |
| Flare | Prometheus | World | none | Shot up: a big area is Bright for 2 turns, and whoever hides there is shown. Loud on a map: everybody hears it | `zone_light_tiles`, Unveil's `unveil` |
| Faerie Fire | Alithia | World | 100 | Contested: they glow, cannot be hidden or invisible, and everybody sees them in the dark | A condition with `light_tiles`; `set_hidden` |
| Daylight | Alithia | Hermes | 200 | An area of Bright that also ends any darkness laid on it, Light Void included | `zone_light_tiles`, `dispel_zones_at` |
| Ember Trail | Prometheus | Hermes | 100 | The ground he walks burns low behind him: light, and a little fire | Burner's zone, laid on each step |
| Will-o'-the-Wisp | Alithia, Illusory Shepherd | Hermes | 200 | An illusion that gives real light and draws those who see it. On a map, it leads a guard off | Phantom Noise's `drawn_to_aim`, a creature's `light_tiles` |
| Lantern of Truth | Alithia | Charon | 200 | Bright for 5 tiles round her as she walks. Nothing hidden stays hidden in it, and illusions there are seen for what they are | A condition's `light_tiles`, `sees_the_unseen` for all in it |
| False Dawn | Alithia | Mnemosyne | none | Only out of a fight: the hour on this map goes to dawn for 5 minutes, and back | `Campaign.set_clock`, a map's own hour |
| Stolen Sun's light | Prometheus | as it is | as it is | His last spell lights the whole battlefield while it burns | `zone_light_tiles` on what is there |

## 7. Cyrus and the dark

**Chosen and built, 2026-11-07:** his Gun shoots out lights, in a fight and on a map, and Snuff isn't needed. Shadow Step. Silhouette at
+20%. Ink Bottle. In Plain Darkness. Calling Out went to Alithia. Night Hunter and Lifted Torch are answered in section 17.

He has Night Eyes, Stealth and Slip Past. In a fight "Dark" and "hidden" already count as the same thing to whoever
cannot see in it, so most of this gives him ways to be there, stay there, or make it.

| Idea | Kind | What it does |
| --- | --- | --- |
| **Snuff** (recommended first) | Skill | A shot at a lamp, a torch, a brazier or a placed light in reach puts it out, quietly. In a fight it makes his dark. On a map, guards notice the lamp, as now, but he need not walk up to it |
| **Shadow Step** | Secondary | From one Dim or Dark tile to another within 4, unseen and with no reactions |
| **Night Hunter** | Passive | His blows from a Dark tile at somebody who cannot see in it count as from hiding, whether or not he is hidden |
| **Silhouette** | Passive | Somebody standing in Bright, shot from Dark, takes a share more: the archer in the shadows shooting into the firelight |
| **Calling Out** | Secondary | In the Dark, he names somebody he sees: his side can aim at them until his next turn. His eyes become everybody's |
| **Ink Bottle** | Item | A Dark zone for 3 turns: Light Void in a bottle, for Cyrus's pockets and anybody else's |
| **Lifted Torch** | Map | Pick a guard's pocket for his torch: he has to go and relight it, and walks a dark round until he does |
| **In Plain Darkness** | Map | Bodies left on Dark tiles are not found. A takedown in the Dark is not heard |

## 8. Alithia and lit places

**Chosen and built, 2026-11-07:** Blessed in the Light at +10%, on her heals and her Idol damage. Nowhere to Hide. Calling Out. Her other
ways are in section 17.

She already leans on light in name: Flash, Piercing Light, Sanctuary of Light. A rule to go with it: **standing in Bright
is good for her side**, so that she wants what he wants to put out. That makes the two of them pull against each other,
in a good way.

| Idea | Kind | What it does |
| --- | --- | --- |
| **Blessed in the Light** (recommended first) | Passive | Her heals mend a share more on somebody standing in Bright |
| **Radiance** | Passive | Her light spells (Flash, Holy Lance, Piercing Light) gain a share against somebody standing in Bright, and Flash's area grows by 1 there |
| **Shining Example** | Passive | She gives a little Bright round her while she has a casting left. Allies in it hold their nerve. The cost: she is easy to find in the dark |
| **Nowhere to Hide** | Passive | Anybody of the other side in her light cannot hide, and takes Exposed if they try to |
| **Sanctuary in the Light** | Change | Sanctuary of Light lights its tiles Bright, and its 15% rises in Bright |
| **Known by the Light** | Map | In Bright, a guard knows her for a priestess at a distance, and asks instead of raising the alarm (`Gaze.ASKS`) |
| **Illusions by Light** | Change | Her illusions are believed best where they can be seen clearly: their contests gain a little in Bright, and lose a little in Dark |

## 9. Showing conditions on the figure

**Chosen and built, 2026-11-07:** everything here but icons over the head, which the designer looked at an example of and preferred
without. Poses fall back on idle for a creature with no such animation.

Now they are only marks beside a portrait and under a face in the turn queue (`ConditionStrip`), and in the log. Nothing
is on the figure itself, which is where the eye is. By how much each shows for the work:

| Idea | What it does |
| --- | --- |
| **A tether line** (recommended first) | A thin thread from whoever holds a tether to what it holds, in the spell's colour, thinning as the bar wears. It says who is doing this to whom, and shows where to right click |
| **A colour on the figure** | Each condition has a tint that breathes: orange for Burn, green for Poisoned, ice blue for Frozen, grey for Crystallised. Done in the sprite's own colour, so it works on any art |
| **Something round them** | Things that go round the head or sit at the feet: stars for Stunned, a spiral for Confused, a dark band over the eyes for Blind, sweat drops for Fear, a chain at the feet for Snared and Grappled, a gag or a rune for Silenced, strings from above for Compelled |
| **Something coming off them** | Particles: embers and a flicker for Burn, drips for Poisoned and Bile-Soaked, frost for Frozen, a soft light for Blessed and Sanctified. Burn already gives real light |
| **A ring on the ground** | Under their feet, one colour for a boon and another for harm, pulsing when it is about to end. Readable at a distance, and in a crowd |
| **Icons over the head** | A small row over the figure, the same marks as the strip, while hovered, or all of them while the danger view is held. So the board stays clean until asked |
| **Poses** | If the figure's SpriteFrames has an animation called "stunned", "afraid" or "frozen", it plays that instead of idle. A slot, for when the art comes. Prone already lies down this way |
| **On arrival and on leaving** | A short flash and word as it lands ("Burning!"), a fade as it goes. Words already float for some; this makes it all of them |

To keep it from becoming a mess when somebody has six: one loop at a time shows on the figure, by a Priority on the
condition, and it takes turns every second or so if two are equal. All of it would be fields on `ConditionDefinition`:
Tint, Round Them (a picture), Off Them (particles), Ring, Pose, Priority, each with a placeholder in code and a slot
for the real art, as Skill Look has for moves. It is view only, and changes no rule.

## 10. Sprites lit more, and better shadows

**Chosen and built, 2026-11-07:** all of these, but for shine, normal maps and real shadows, which are answered in section 17.

All of it is to look at only. Each works on the art as drawn, with no extra pictures needed, unless it says so.

**How light falls on a figure.** Now a figure has one tint for the whole of it, by the level it stands in.

| Idea | What it does |
| --- | --- |
| **The light's colour on them** (recommended first) | A figure beside a red fire goes red, and between a red and a blue light goes both ways. The nearest lights' colours, by how close, mixed into the tint every frame, breathing with a flame |
| **A lit side** (recommended first) | The edge of the figure facing the nearest light gets a bright rim in its colour, and the far side falls off darker. A shader that looks for the sprite's edge in the light's direction. The cheapest way of looking solid, and it needs no normal map |
| **Light from below, light from above** | A fire on the floor lights the feet more than the head. The sun lights the head more. A gradient up the figure, by what is lighting them |
| **Half in the dark** | The figure reads the shade map at each of its own pixels, so somebody stepping out of a doorway is lit on one half. It stops whole figures changing at once at a tile's edge |
| **Back lit** | With the light behind them from where we look, the front goes dark, and only the rim shows |
| **Normal maps** | The full version of all of the above, for one more picture per frame (`docs/light_on_maps.md`). Only worth deciding once the art exists |
| **A shine mask** | A small extra picture saying what is metal: armour and blades catch a moving light. Art again |

**Shadows.** Now a figure has one soft oval, pointing away from the nearest light.

| Idea | What it does |
| --- | --- |
| **Their own shape** (recommended first) | The figure's own current frame, black and laid along the ground away from the light. It walks and swings as they do. The biggest change for the work |
| **One for each light** | Up to two or three shadows from the nearest lights, each as strong as its light, crossing each other as somebody walks between two fires |
| **Length by the light** | Long when the light is low or far, short when close. Outdoors the sun's angle: long at dawn and dusk, short at noon, with the lean going round through the day |
| **Softer further off** | The shadow blurs and fades towards its far end, and stays sharp at the feet, with a small dark contact patch where they stand |
| **Stopped by walls** | A shadow that reaches a wall ends there, rather than lying across it |
| **Real ones** | A `LightOccluder2D` round each figure, from the shape of its art, so figures block light as walls do and throw shadows on each other. More costly, and it flickers as frames change, so best kept to a simple shape |
| **Who is off the ground** | Somebody flying has a smaller, fainter shadow further from them, and something big a bigger one (`Sizes`) |
| **Coloured by the hour** | Blue-black at night, warm at dusk, rather than always black |

## 11. The interface

**Chosen and built, 2026-11-07:** all but "Less over the map" and "End Turn". The buttons' "more" needed nothing new: past twelve, they
already go on a shelf that scrolls. Health shows while the danger key is held, with no key of its own. UI Scale covers the HUD of a
fight and a map; conversations and menus keep their size.

From looking at the screens while testing the light, a fight at level 64 above all.

| Idea | What is wrong now | What it would do |
| --- | --- | --- |
| **The gates' tags** (recommended first) | At high levels the row runs behind the log and off the screen in a fight | Two lines, or small pips by each gate's colour, with the name on hovering |
| **Less over the map** (recommended first) | The bottom quarter of the screen is panels, so whoever is at the bottom of the view is behind them. In the shot at level 64 somebody stands behind the End Turn button | Move the camera up when the panels are up. Let the log close to one line by default, opening on a click. A fight's panel could slide down when it is not this player's turn |
| **Condition marks** | "Bs" and "So" need learning, and sit far from the figure | Icons with the turns left on them, on the portrait and in section 9's ways on the figure. `art/icons` could take a slot per condition |
| **The buttons in a fight** | Spells, Go Prone and End Turn float on their own, at different sizes, and empty slots look like missing things | Group them into one block. Show only as many slots as are full, and a small "more" for the rest |
| **End Turn** | It looks the same whether or not there is anything left to do | It glows once the main action, the secondary and the feet are spent, and asks once if clicked with a main action unused, if the player wants that |
| **Grid lines** | White, and the strongest lines on the screen, stronger than the map's art | Thinner and fainter, and stronger only while moving or aiming |
| **Health on the figures** | Only on the portraits, and the queue | A small bar under a figure while hurt, or while hovered, or all of them while a key is held |
| **Turn queue** | Clear, but nothing connects a face to a figure | Hovering a face lights up the figure, and hovering a figure lights up the face, with a round marker in the queue where a new round starts |
| **The log's colours** | Yellow is the party and red the enemy, except that "Cyrus is blessed by Alithia's presence" has Alithia in red | Going through those lines so a colour always means the same side. A small bug, worth doing anyway |
| **One line for a wall** | A wall writes a line per piece as it goes up and another as it goes, up to nine each on a long diagonal | One line for the whole wall, each way |
| **The moves panel on a map** | Always up, though most walking needs none of it | Hidden until a key, or the pointer at the bottom of the screen, with the map's keys on the stealth bar as they are |
| **Size** | The text and panels are one size | A UI Scale in Options, for a big screen, a small one or a pad from a sofa |
| **Colour alone** | Some things are told apart only by colour | A shape as well, for colour blindness: the move, reach and danger tiles, and each gate |

## 12. What the enemy's ways did to the fights

A measurement, not a proposal. `tests/run.sh aicompare` plays each fight from one seed, with nobody knowing anything and
every dial at 1 ("before"), and as things now stand. Nobody plays the party, so read it as a before and after, not as
how hard a fight is. "Last time" is the same probe before the ways of its own went in.

| Fight | Party standing still: damage in 3 rounds, before -> now (last time) | Rounds to fell them, before -> now (last time) | AI on both sides |
| --- | --- | --- | --- |
| Sewer Intro Fight | 75 -> 75 (75) | 8 -> 6 (8) | |
| Lab Fight | 106 -> 106 (106) | 3 -> 3 (3) | party lost before, won now with 10% left |
| City Fight | 382 -> 403 (403) | 2 -> 3 (3) | |
| Hired Blades | 211 -> 211 (211) | 4 -> 4 (4) | party won both, 20% -> 60% left |
| The Bound Golem | 263 -> 255 (255) | 6 -> 7 (5) | |
| The Alchemist | 517 -> 469 (421) | 2 -> 2 (2) | |
| The Summoner | 128 -> 145 (145) | 8 -> 9 (9) | |
| The Bellkeeper | 134 -> 135 (127) | 5 -> 4 (5) | |
| The Ash Warden | 135 -> 107 (107) | 7 -> 7 (7) | party lost both, in 6 -> 10 rounds |
| Erysichthon | 73 -> 83 (83) | 10 -> 9 (9) | |
| Sixty-Four | 661 -> 552 (592) | 3 -> 2 (2) | |

## 13. Going without tiles, as in Divinity: Original Sin 2

**Chosen, 2026-11-07: A, built that day.** The rules stay on tiles. Soft patches, one outline for how far somebody can walk, a walk on a
curve, grid lines only near the pointer while moving or aiming, and a button beside the clock for anybody who likes to count.

Nothing here is built. It is three sizes of the same idea, smallest first. The recommendation is at the end.

**How deep tiles go now.** Outside the tests, 838 lines in 41 scripts hold a tile position (`Vector2i`), 299 of them in
`combat/Combat.gd`. "Reach" is a count of tiles, asked for in 60 places in that file. Areas, zones, light, sight, blocks,
hemming, sizes, shoves and the AI's choice of where to stand all work in whole tiles, and so do 1,121 lines in 93 test
scripts. The stealth maps are the exception: figures there walk freely, and the watch asks which tile they are on.

**What the game would gain**
- **Standing exactly where you mean to:** half behind a pillar, or just outside an area.
- **Zones with a natural shape:** fire, ash and darkness as spreading patches, not coloured squares.
- **Walls at any angle:** Phantom Wall from any point to any other, not only along eight directions.
- **Round creatures:** a big one takes up a circle, not a rectangle.
- **Maps painted without a grid:** blocking would follow drawn outlines, not 256-pixel squares.
- **No snap into a fight:** figures would stay where they stood on the map. Today a fight shifts them to tiles.

**What it would cost**
- **Reading the board:** today you can count to see if someone is in reach. Without tiles you rely on the preview, and
  the well-known annoyance arrives: a spell just short of its target, by a hair.
- **The pad:** the cursor steps tile to tile, which is good on a PlayStation pad. Free positions need a stick-driven
  cursor, which is slower and less exact, or a cursor that snaps to suggested spots.
- **Every rule that says "on" or "beside":** is a figure in a zone when its middle is in, or when any part is? What does
  "beside you" mean in the Dark? When is someone hemmed? Each needs a new answer.
- **The numbers:** a reach of 5 covers 61 tiles now, and a circle of 5 covers about 81, a third more ground. An area of
  radius 3 goes from 25 tiles to about 29. Every area spell gets stronger unless retuned, and those numbers are yours.
- **Playing together:** fights replay from a seed and must come out the same on both machines. Free positions have to be
  rounded the same way everywhere, and paths sent rather than worked out again.
- **The AI:** it weighs tiles one by one, and an enemy's turn at level 64 already takes about 2 seconds. Free positions
  mean sampling spots, so it gets slower or plays worse.

### A. Keep the rules, stop showing the tiles

The rules stay on tiles. Only the look changes:
- Grid lines fade away except while moving or aiming, with a button to show them for anyone who likes to count.
- Reach is one soft outline, not a field of squares.
- Figures walk smooth curves and only end on a tile.
- Zones are drawn as soft patches over their tiles, and areas as circles and cones.
- Phantom Wall is drawn as one wall, not as pieces.

The AI, playing together, the numbers and the tests don't change. It can be done one piece at a time, and each piece can
be undone. It won't let anyone stand between two tiles.

### B. Smaller tiles

Tiles get cut to half size (or quarter), and whole numbers stay. Figures then take up several small tiles, which the
size rules already handle for big creatures. Reach could go by real distance, shown as "5.0".
- **Stays:** exact replay, and playing together works as it does.
- **Gets better:** finer standing places, rougher edges on zones, and walls at more angles.
- **Has to change:** the AI has four times the tiles to weigh at half size, so it needs a coarse pass and then a fine
  one. The pad's cursor needs a step size. Maps need blocking at the finer size.
- **The numbers:** they shift if reach goes by real distance (the figures above), and stay put if it keeps counting.

### C. Truly free, as in Divinity

Positions become exact points:
- Walking goes on a navigation mesh, by distance.
- Zones are shapes, and hits are overlaps.
- Sight is a ray against the map's outlines.
- Light is read at a point.
- Rounding is added for playing together.

This replaces the foundation of `combat/Combat.gd` and `control/CController.gd`, and most of the fight tests would need
rewriting. It is the only one that gives everything on the list above, and the only one that pays every cost on it.

### Recommendation

**Do A, then decide.** Most of what makes Divinity feel free on the screen is the smooth walking and the natural-looking
surfaces, and A gets those for very little risk. If you then still want to stand between tiles, B gets that while keeping
the game's exact rules, its replay and the pad. I wouldn't do C unless you decide that free movement is what this game is
about, because it trades away the exact reading of the board that the fights and the pad are built around.

## 14. The day going round, smoother and with more to it

**What it does now.** Eight marks round the day (`Light.SKY`), with straight lines between them, the same every day. So
it turns sharply at each mark, nothing changes from 9:00 to 15:00, and nothing changes from 20:30 to 5:00. How dark a
place looks changes at four moments only (5:00, 8:00, 17:00, 20:00), each eased over a second or so.

**Smoother**

| Idea | What it does |
| --- | --- |
| **Curves, not straight lines** (recommended first) | The sky speeds up and slows down between marks, not turning sharply at each one |
| **More marks** (recommended first) | About 13: blue hour before dawn, first gold, morning, a cooler and harder noon, a warmer afternoon, golden hour, red at sundown, blue hour after it, and deep night. Nothing stands still for hours |
| **The shade by the minute** (recommended first) | How dark a place looks follows the sun all the time, and only the rule changes at the four moments. At 16:30 evening is already coming, and at 17:00 nothing jumps |
| **The sun's arc** | Shadows' lean, length and softness follow one curve: long one way in the morning, short at noon, long the other way in the evening. At night a faint moon shadow follows the moon's own arc |
| **Windows follow the sky** | An Opening's light and shafts take the sky's colour at that minute and lean with the sun: gold in the evening, blue before dawn |
| **Lamps lit at dusk** | Lamps marked for it come on one by one around dusk, at slightly different minutes, and go out one by one at dawn. This one changes the rule a little, since a lit lamp is light |

**More variance**

| Idea | What it does |
| --- | --- |
| **A day's own weather** (recommended first) | Each day has a sky from a short list. Clear is crisp, haze soft and warm, overcast flat and grey with faint shadows, and there can be rain or a foggy morning that lifts by 10:00. A story can set it: `do Campaign.set_weather("storm")` |
| **Its own sunrise and sunset** (recommended first) | Each day moves the dawn and dusk colours a little: a red evening one day, pale gold the next |
| **Clouds passing** | A slow soft shadow drifting over outdoor maps, using the noise the fog already has, and thicker on an overcast day. The light changes even while the clock stands still |
| **Moon phases** | The calendar gives the moon a phase. A full moon's night is a little brighter, with moon shadows, and a new moon's is darker. The rule could follow, with a new moon being No Moon, so that a night's stealth depends on the date. That part is a rule change |
| **Seasons** | The month moves sunrise and sunset by up to an hour or so either way, with a warmer or colder sky. It moves when the rule changes, though the rule is the same |
| **A place's own sky** | A map can tint the sky a little: green under trees, warm in a desert, grey-blue by the sea, brown under a city's smoke. A MapSetup field |
| **Life by the hour** | Mist low on the ground at dawn, dust at noon, insects at dusk, and birds or crickets to match, behind slots for your own art and sound |

**So it still makes sense**
- The rule stays with the four parts of the day, so stealth and fights mean what they did. All of this is looks, unless it
  says otherwise.
- Variance only moves within a range: the sun rises on the same side, dusk is warmer than dawn and night is blue.
- It's worked out from the day number and nothing is rolled in a fight, so both players see the same sky, a save brings it
  back, and a replayed fight comes out the same.
- A scene can always fix the hour, the weather or the moon. The story has the last word.

**Recommendation:** the three smoother ones first, because they change no rule and most of the jumps go with them. Then
the weather and each day's own sunrise and sunset, which add the most variance for the work.

## 15. Enfina: more depth and personality

**Why Trailblaze works.** It is the one thing she has that asks a question: health now, for speed now. Most of her kit is
numbers that are simply on (Iron Hide, Bulwark, Momentum). She has no gates, no items to weigh and no pool to manage, so a
turn is often just "hit the thing". Cyrus, Alithia and Prometheus each decide something on every turn.

Trailblaze also fits her story better than anything else she has. She has no rank and nobody rewards her. She raises her
sword for everybody else, and she pays the price for it. So everything below is one idea: **she pays, so that others don't
have to, and she knows how you fight.**

Levels are from `docs/progression.csv`'s tiers and numbers are PROPOSAL, pitched at her sheet (Taunting Shout 0.6 at 16,
Double Strike 1.5 at 32, AOE Sweep 1.4 at 54).

### Fire she pays for: Trailblaze grown

| Idea | Level | What it does | The question it asks | Rests on |
| --- | --- | --- | --- | --- |
| **Blazed Path** (recommended first) | 8 | While she burns, the tiles she walks stay lit until her next turn. Allies on them walk one tile further and pay no hemming, and foes stepping there catch Burn | Which way does she open up for the others? | Burner's zone laid each step, `zone_light_tiles`, `hem_cost` |
| **Flashover** (recommended first) | 16 | Secondary. Ends her Burn at once in a blast round her: x0.6, plus x0.15 for each Burn turn left | How long does she burn? | A self area, the Burn's turns left |
| **Cauterise** | 24 | Secondary. Ends her Burn and mends a flat amount for each turn left, taking off Poison or Corroded | Spend it on damage, or on staying up? | `heals_flat` (the healing policy's way), `_lift_conditions` |
| **Share the Fire** | 32 | Trailblaze on an ally: they get the speed, and the Burn's damage lands on her | Who gets the speed this turn? | `source_takes_share` (Shared Burden) |
| **Through the Fire** | 41 | While burning she walks through fire unharmed, thaws at once, and Fear can't take hold | Light up before going in? | A condition's `immune_to_conditions` |
| **Burning Titanfall** | 64 | Titanfall while she burns leaves the ground it shoved them off burning | When to save the big one? | Titanfall's splash, a zone |

### Knowing how you fight: "trained to perfectly respond"

| Idea | Level | What it does | Rests on |
| --- | --- | --- | --- |
| **Drills** (recommended first) | 8, more at 24 and 41 | At the end of her turn, free, she picks what she is ready for: Hold (strike whoever leaves her reach, as now), Step In (take a blow for an ally beside her) or Riposte (strike whoever hits her). Each costs her one reaction as usual. It turns her best-known move into a choice, and players can read a fight by which one to pick | `reacts_when`, Ready's machinery, her reactive Greatsword |
| **Called Opening** | 16 | Secondary, on somebody she has studied: the next ally to hit them gets her studier's edge | `studied`, `damage_dealt_multiplier` |
| **Reads the Form** | 32 | Against somebody studied, her first reaction each round doesn't spend her reaction | `_can_react` |
| **Field Notes** (recommended first) | 1 | The enemy codex becomes her notebook, each page with a line in her own voice. A kind she has studied in an earlier fight gives her a small edge from the first blow (+5%, PROPOSAL). It rewards filling the book, and it's where she can be funny or doubtful without a cutscene | `Campaign.codex_pages`, `ui/codex_page.gd` |

### A city guard's tricks

| Idea | What it does | Rests on |
| --- | --- | --- |
| **Throw a Friend** (recommended first) | Hurl, aimed at a willing ally: they land up to 3 tiles away, ready to act. It's funny and tactical, and a joy for two players | `_hurl`, `throw_destinations` |
| **Anything Is a Weapon** | Hurl picks up a barrel or a keg as well, and a Gale Urn or Tar Cauldron goes off where it lands | `_hurl`, objects' `blast_radius` |
| **Arrest** | A contested order on somebody whose nerve is nearly gone: they surrender and can be questioned after. The guard's way of winning | "Nerve", `prisoners` |
| **Show the Badge** (on a map) | City guards take her word once per map: one who is suspicious stands down. Cyrus goes round, and Enfina knocks at the front door | `Gaze.ASKS`, Talking in disguise |
| **Carries Them** (on a map) | She drags a body or a fallen ally at full pace | `ExplorationParty.pace` |

### Her story in play

- **Commendations:** a quiet tally of the blows she took for others and of who she kept standing. Nobody says anything for
  a long time. Then, at story beats you choose, somebody finally does. It would give a real payoff to "nobody recognises
  her", and a title on her sheet could change with it. All writing and flags, no new rules.
- **Lines of her own:** when she studies somebody she says what she sees ("Favours the left."), and when she burns she says
  something short and stubborn. It only needs a slot per move, like the barks in `docs/proposals_2026-11-06.md`.

**Recommendation:** Blazed Path and Flashover first, since they make the move players already love the centre of a whole
style of play. Then Drills, which gives her a real decision every turn. Throw a Friend and Field Notes are cheap, and
they're where people will start to remember her.

## 16. Prometheus: transmutation, conjuration, necromancy

He has elements in depth and a little of the rest. These fill the gaps, and all of them lean towards what makes him
different: he changes the board rather than the people on it. Gates and tethers are suggestions. Gates open at 1, 8, 14,
21, 28, 34, 41, 47, 54, 61, as spells have no levels of their own.

### Transmutation: what things are

| Spell | Gate | Tether | What it does | Rests on |
| --- | --- | --- | --- | --- |
| **Transmute Ground** (recommended first) | Hermes | none | Turns a zone of his to another element: fire to ice, ice to mud. A burn laid last turn becomes a freeze on this one. Nobody else has this, and it fits his area play | A zone's fields, `Catalyst` |
| **Stone to Mud** | Hermes | 100 | An area of ground is slow going for whoever crosses it. On a map, it softens a breakable wall silently | `zone_costly`, `break_wall` |
| **Shrink** | Hermes | 100 | A size smaller. A foe loses reach and grip, and an ally on a map fits through grates and small gaps | `size_wanted`, `SmallGap`, the counterpart of Growth |
| **Heat Metal** | Pandora | 100 | Somebody's gear heats up: Burn each turn, and they must let go (Disarmed) or keep burning | `weapon_damage_change`, a DoT |
| **Flesh to Stone** | Charon | 200 | Contested. They stand as stone, taking little from anything, until one heavy blow shatters it for double | Crystallised, `damage_taken_change` |
| **Polymorph** | Tartarus | 300 | Contested. They become a rat, with its movement and its bite, until enough damage breaks it. Bosses immune by a per-creature switch | `CombatantSprite.show_as`, a skill swap |
| **Gaseous Form** (on a map) | Pandora | none | Somebody drifts through doors and grates for a time, and can do nothing else | `is_walkable_for`, map-only like Arcane Eye |

### Conjuration: bringing things here

| Spell | Gate | Tether | What it does | Rests on |
| --- | --- | --- | --- | --- |
| **Singularity** (recommended first) | Sophia | none | Everybody within 5 of a point is dragged to it, in a shove the board previews. The best set-up an area damager could ask for | PULL, "Shoves, foreseen" |
| **Transposition** (recommended first) | Pandora | none | Two people in reach swap places, contested if unwilling. A foe into his own fire, or an ally out of danger | Teleports, `can_land_on` |
| **Grease** | World | none | Ground that knocks down whoever walks it (contested), and burns if fire touches it | `getting_up_share`, a zone |
| **Web** | Hermes | 100 | An area of Snared, flammable too | `zone_leaves_conditions` |
| **Wall of Stone** | Pandora | 200 | Placed by two clicks like Phantom Wall, but real: it stops both sides and can be broken | `summon_across`, `breaks_wall` |
| **Fetch** | World | none | A small thing within 8 comes to his hand: a key off a table, an item off a body, a lever pulled. On a map as well as in a fight | Loot, `Interactable` |
| **Create Pit** | Pandora | none | Whoever stands there drops a floor, or loses their turn climbing out | Floors, `climb_tiles` |
| **Conjure Elemental** | Tartarus | 300 | A big elemental of the element he chooses, between the Hound and the Dragon | Summons, `chooses_element` |
| **Arms of the Deep** | Tartarus | 200 | An area where things grab whoever is there each turn | `holds`, `zone_turn_damage` |

### Necromancy, and where it could go

| Spell | Gate | Tether | What it does | Rests on |
| --- | --- | --- | --- | --- |
| **Speak with the Dead** (recommended first, on a map) | World | none | Asks a body one question: a guard's route, what they carried, a clue. Very much the kind of utility nobody else has | `learn_route`, clues |
| **False Life** | World | none | Health on top of his own for a while. His 30 to 58 could use it | `overheal` |
| **Withering Touch** | World | none | A weak blow, and they can't be mended until their next turn. Good against priests | A new `prevents_healing` |
| **Blight** | Pandora | 100 | An area where everything standing rots: Corroded, and heals do less | `Corroded`, a zone |
| **Marionette** (recommended first) | Charon | 200 | Somebody fallen on the other side gets up and fights for him, on a share of its health. The fallen are knocked out here, not dead, so what it does to them is a real question for the story | `targets_fallen`, Summons |
| **Proxy of Flesh** | Nemesis | 300 | Contested. A share of what he takes lands on them instead | `source_takes_share` turned round |
| **Death Knell** | Tartarus | none | Everybody in an area below a quarter of their health falls. Bosses immune by a per-creature switch | A health threshold on a zone's area |
| **Borrowed Time** | Sophia | none | A reaction: somebody about to fall keeps fighting at 1 health for 2 more of their turns, and then falls unless mended. The dark twin of Fallen Friend, using its trigger | `Trigger.WOULD_FALL` |

**Where necromancy could go:**

- **Forbidden books for Prometheus (recommended).** He already learns from books, and these could be rare, found late and
  hidden in the story. Each casting could cost him health, which matters a great deal on a body like his. It also ties into
  the research he won't speak of. Alithia, as a cleric of the Holy Order, would have something to say when he uses them,
  through a flag the conversations can read.
- **Taken from enemies.** It first appears in the hands of somebody the party fights, and once he has Studied them it can
  be copied into a book. It shows the player what it does before they own it.
- **A fourth path for him.** The fullest version, but also the most work, and his three paths are all elemental.
- **Enemy-only.** The cheapest. It keeps it frightening, and he never gets it.

**Recommendation:** Transmute Ground, Singularity and Transposition first, since they make him more himself. For
necromancy, Speak with the Dead and Marionette in forbidden books.
