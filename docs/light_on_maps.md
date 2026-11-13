# Putting light on a map

To see all of this working, play Stealth Stages, stage 9, Light. It has a sign beside each thing saying what it is
and how it is placed. Below is how to do each of them yourself.

## 1. Say how lit the place is by itself

Select the **MapSetup** node on the map, open its Light group:

| Field | What it does |
| --- | --- |
| Ambient | Outdoors goes by the sun. Interior is Dim. Underground is Dark. |
| Time Of Day | The hour on arriving. As It Stands keeps whatever the clock says by now. |
| No Moon | A night with no moon is Dark, not Dim. |
| Sky Tint | This place's own sky over the day's: green under trees, warm in a desert, grey-blue by the sea. |
| Seconds Per Time Of Day | Above 0, the clock runs while walking here, each of day, dusk, night and dawn taking this long. |

A fight goes by the map it was walked into from. An **EncounterDefinition** can say otherwise with its own Ambient,
Time Of Day and No Moon. A stealth map can also be forced dark with **StealthSetup**'s Dark, and that is where
guards' sight in the dark is set too (Dark Sight Tiles, Dim Sight Tiles).

## 2. Give part of a map its own ambient

Add an **AmbientArea** node: a roofed building on an outdoor map, a cave on a hillside. Its corner is where the node
stands, and it reaches Size Tiles right and down. The editor draws its outline. Set its Ambient to Interior,
Underground or Outdoors.

## 3. Add lights

Add a **LightSource** node on the tile you want. The editor draws two rings: Bright inside, Dim outside.

| Field | What it does |
| --- | --- |
| Bright Tiles, Dim Tiles | How far each reaches. Bright for a torch is about half of Dim. |
| Colour | The colour of the light. |
| Lit | Whether it is on to begin with. |
| Flickers | A flame: it breathes and throws embers. Off: steady, with dust hanging in it. |
| By The Clock | Lit around dusk, out around dawn, each at its own minute. A Lamp has the same. |
| Opening | A window, a cave mouth, a hole in the roof: it lets in only what the sun gives. All of it by day, only the Dim at dusk and dawn, nothing at night. Shafts of light come from it. |
| Shows Flame | Draws a small placeholder flame, for one with no art of its own to stand on. Untick it if the map has its own. |

Put a LightSource in the **terrain** scene and it lights the map and any fight on that terrain. Put it in the map
scene and it lights only the map.

Other things that give light, all in their own inspectors:

| Thing | Field |
| --- | --- |
| A lamp that can be put out, on a watched map | **Lamp**: Light Tiles, Starts Lit, Can Be Put Out |
| Something on the map in a fight, like a brazier (breaks, and its light goes) | **BattleObjectDefinition** or any creature: Giving Light, Light Tiles and Light Colour |
| A creature that burns, real or an illusion | **CombatantDefinition**: Giving Light (the Ash Warden, the Illusory Dragon and the Kindled Hound have it) |
| A guard's torch | **Guard**: Carries Light Tiles |
| Somebody burning | **ConditionDefinition**: Light Tiles (Burn has it) |
| Ground that burns | A zone **EffectDefinition**: Zone Light Tiles (Burner has it) |
| A lantern | **ItemDefinition**: Light Tiles. It works from a Baldric. |
| A projectile | **SkillDefinition**: Projectile Light Tiles. 0 is Automatic: fire, plasma, lightning and ice give it, and a little for any spell. Below 0 takes light away. |

## 4. Let walls do the rest

Anything a tile's **Blocks** says stops sight also stops light and throws a shadow, including barrels and walls.
A shut door stops it, and an open one lets it through. An illusion can stop it too: a **BattleObjectDefinition**
with Wall and Illusion Stops Light ticked, like the Phantom Wall.

## 5. What it does in play

| Level | In a fight | On a watched map |
| --- | --- | --- |
| Bright | Nothing. | Nothing. |
| Dim | Somebody who stealths can hide without cover, and is only made out from 3 tiles. | Guards' eyes reach Dim Sight Tiles. |
| Dark | Invisible to whoever cannot see in the dark, unless right beside them. | Guards make somebody out only within Dark Sight Tiles. |

Light is to scale with this: a lamp in a dark room is a place to avoid, and putting it out is the way through.

## 6. Moving the clock in a story

In a conversation:

```
do Campaign.advance_clock(8)             # eight hours on, in a cut
do Campaign.advance_clock(0, 3)          # three days on, in a cut
do Campaign.set_clock(21, 30)            # the next time it is half past nine at night
do Campaign.set_time_of_day("night")     # the next time it is night
do Campaign.watch_time_pass(8)           # eight hours on, seen going by, in five seconds
do Campaign.watch_time_pass(0, 3, 9.0)   # three days on, seen going by, in nine seconds
do Campaign.set_no_moon(true)            # no moon on this map
do Campaign.set_moon("full")             # or "new", whatever the date; set_moon() goes by the date again
do Campaign.set_weather("storm")         # clear, haze, overcast, rain, fog, storm, today; set_weather("rain", 3) for three days; set_weather() the day's own
```

The names of the months and the days of the week, and where the story begins, are in `data/calendar.tres`.
They are placeholders for your own. The sun's colours and hours are in `combat/Light.gd`, at the top of
"By the clock".

## 7. Slots for art

Each of these replaces what is drawn in code, by being there: `art/fx/ember.png`, `art/fx/dust.png`,
`art/fx/light_shaft.png`, `art/fx/figure_shadow.png`, `art/fx/glowing_eyes.png`.

If the art ends up as pixel art, `Campaign.set_dithered_light(true)` gives the shade a dithered edge.

### Normal maps

A normal map is a second picture for a sprite or a tile. Each pixel's colour says which way that bit of the surface
faces, rather than what colour it is. With it, a real light can work out that the side of a nose facing the
torch is lit and the far side is not, so flat art looks raised, and the light slides over it as the torch moves.
Without it the whole sprite is lit evenly, which is what you see now.

It is extra art: one more picture for every tile and every frame. Most people generate them from the art with a
tool (Laigter, SpriteIlluminator), then touch them up. So it only makes sense once the real art exists, and it
needs no code when it does. In Godot, a TileSet atlas has a Normal Map field, and a sprite takes a CanvasTexture,
which holds the picture and its normal map together. The lights here already use them when they are there.

## 8. Water, cloth and smoke

Three more nodes to place, each only to look at:

| Node | What it does |
| --- | --- |
| WaterPatch | Water. Put it on the top-left tile and set Size Tiles, as for a Noisy Floor; Colour is the water's, and Foam can be turned off for water against a wall or a quay. It ripples the way the wind blows, foams where it meets the land, rings in the rain, and the sun glints on it on the side where the sun stands. Lights are mirrored in it, and the night's low mist lies thicker beside it. Nobody is kept out of it: paint the tiles under it with Blocks for that. |
| WindBanner | Cloth in the wind. Kind is Banner, Pennant or Washing Line; Cloth is its colour, Pole Tiles how tall its pole is, and a washing line reaches Reach Tiles to the right. It hangs slack in still air and streams out the way the wind blows. |
| ChimneySmoke | Smoke over the roofs, leaning with the wind: Lit, Thickness and Colour. A flame out under the sky smokes by itself. |

Nothing has to be placed for the rest, which come with the season, the hour and the weather: lights mirrored in the wet after rain,
blossom and leaves on the wind in spring and autumn, birds' shadows by day, a glow round lights and darker edges after dark, low mist
at night, far lightning on a close summer night before a storm, and at dawn and dusk the light stepping into pixels for a moment. The
Light stage's yard has one of each node, and its sundial gives any season, weather and hour.

Slots: `art/fx/water.png`, `art/fx/smoke.png`, `art/fx/leaf.png`, `art/fx/petal.png`, `art/fx/bird_shadow.png`.
