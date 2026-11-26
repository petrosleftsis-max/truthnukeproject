# Proposals, 2026-11-19: the interface and her art, exploring and maps, and some weirdness

The designer asked:
- "Suggest ways we can improve or change the UI: Something that bothers me is how off the aesthetics of my artist and especially her
  skill icons are compared to the UI theme. Could you suggest ways to make the UI closer to her style, or alternative themes?"
- "Suggest ways to improve exploring and maps"
- "I've been inspired by honkai star rail, control and Alan wake, can we somehow add some of that 'weirdness' into our game?"

Answer per line, as before ("do 1 and 3", "not this"). Sizes are rough: Small is a day or less, Medium a few days, Large a week or
more.

**The designer, 2026-11-19:** "For now keep the same theme as already is and only apply the coloured rings of 3. I'll read the
proposals for the rest and give you a reply." Built that day: T as it was, each skill slot's ring in the colour its icon is painted on
(`SkyLook.icon_ring`, `ring_slot`). The rest of section 1 waits.

**The designer, 2026-11-19, later:** "Proposals: 2. Do all / 3. Do all except the ones kin to Alan wake and the Sky Slips". Built that
day: all of section 2, and of section 3 the archive that rearranges, things that remember, struck-out words, friendly oddities, a
dream-place and Lethe's touch. Not built: the forgetting dark, pages ahead of time and the sky slips. `docs/wander_built.md` says what
is where; The Wanderer's Quarter, the tenth of the Stealth Stages, has all of it.

## 1. The interface and her art

### What clashes

- **Colour.** Her icons are full of saturated colour, each on its own ground: teal, violet, red, orange, yellow, green. T is one cool
  blue with pale light, so every warm icon jumps out of it and the blue ones sink into it.
- **Line.** She draws with sure, dark outlines and flat cel shading: two tones with a hard edge between them. T draws with thin glowing
  rings and smooth gradients. They are two different hands.
- **Type.** Cinzel, the headings' face, is carved Roman capitals: solemn and classical. Her art is warm, modern and anime.
- **The icons disagree among themselves.** Most are bright square tiles; some are round dark medallions with a thin pale symbol (those
  sit better in T, which shows the clash is about colour and line).

### Four directions

`proposals_2026-11-19_interface.png` (beside this file) draws T and the first three in the engine, with her icons and Cyrus's
portrait in each. Health stays red in all of them.

| | What it is | What it keeps | What it takes |
|---|---|---|---|
| **1. Her line on the night** | T's blue night drawn her way: two flat tones with a hard edge in place of the gradient, her four-pointed sparkles in place of pixel stars, a dark ink outline round panels, slots and buttons, heavier underneath as her shading is; headings outlined in ink; End Turn a bright, flat blue | Blue, the sky, and the false sky of the story (the hard edge can be where it gives) | Small in code (the styles in ui/sky_look.gd); best with her own sparkle and outline pieces |
| **2. Blue glass and gold** | Deep blue see-through glass with cut corners, thin white lines, one gold accent to a panel and gold for the main action, capitals for labels. Sleek and neutral, close in spirit to Honkai Star Rail's menus; any icon colour sits on it | Blue; justice as gold | Small to Medium |
| **3. Her colours lead** | The interface steps back: near-black blue, no stars, no glow. Each skill slot's ring and each tooltip's strip take the colour of its own icon, worked out from the picture, so her art is the only colour on screen | Readability; nothing to paint | Small. The coloured slot rings alone could go with 1 or 2 |
| **4. Painted by her** | Whichever of the above, she paints the pieces and the theme takes them with no code: `art/ui/sky/` already reads `night`, `star_bright`, `frame`, `tooltip_frame`, `button_<state>` and `main_button_<state>` (normal, hover, pressed, disabled, focus), `tab` and `tab_chosen`. A `slot_<state>` for the skill slots would be one more | Her hand everywhere | Her time; I'd write her the list of sizes and stretch margins |

### The icons themselves (to talk over with her)

- One shape for all: square tiles, as most already are; the round medallions redrawn square, or framed.
- A ground colour per kind, so the bar reads at a glance: blows warm (red, orange), spells on the night's blue, healing and help green,
  tricks and movement violet or teal. The coloured slot rings of 3 would then speak the same language.
- One outline weight across the set.

### Type

A heading face nearer her art, a rounded or lettered display face for headings and names, with a plain readable face kept for the
rest. There are free fonts that can ship with the game (the SIL Open Font License ones on Google Fonts); you and she would choose, and I'd
fetch the chosen one only with your go-ahead.

### My pick

1 with 3's coloured slot rings: it keeps the blue, the sky and the story you chose T for, and meets her line and her colour. Then 4 as
her time allows. 2 if you'd rather the interface be a quiet, neutral frame for whatever she paints.

## 2. Exploring and maps

| | What it is | Size | Needs |
|---|---|---|---|
| **A map you can open** | Drawn from the map's own tiles (walls, floor, doors, water), showing only where the party has been, the rest veiled; the party, shops, rest spots and the objective marked, and pins of your own | Medium | Nothing; her frame later |
| **The way, at the screen's edge** | An arrow at the edge pointing to the objective or a pin, as pings already draw one | Small | Nothing |
| **Secrets worth finding** | Cracked walls with light showing through (breakable walls exist), stashes in hiding spots, notes on walls to read by pointing (the world's own story, offered 2026-11-13 and still open), and each map counting what is left to find | Medium | Notes to write |
| **Light that finds things** | Marks and paths that show only in the dark to Cyrus's Cat Eyes, or only in a lamp's light or a Flare's: light as a way of looking | Medium | A few marks drawn |
| **Climbing and shortcuts** | Raised ground climbable on a map (already your open question), ladders and ledges, doors that open only from the far side, drops one way: maps that loop back on themselves | Medium | Ladder and ledge pieces |
| **The hours and the weather change the map** | Shops shut at night, people at home, guards changing at dawn (the hours, offered before); paths flooded after rain, ponds frozen in winter to walk on, tracks in snow that guards follow | Medium | Nothing new |
| **Foes that roam** | On open maps, foes seen walking their ground, who chase when they see you and start a fight where they meet you, as a stealth catch does: fights to avoid, or to open with an ambush | Medium | Nothing new |
| **Rest and travel** | Rest spots on maps (a short rest, Meditate, preparing spells), and travel between those found, by Iris's rainbow | Medium | A rest spot drawn; the rainbow is the weather's already |
| **Sound by place** | A bed of sound per area (wind in trees, a city's murmur, drips) and steps by what is underfoot (there is no ambience slot yet) | Small | Her or your sounds |

## 3. Some weirdness: Honkai Star Rail, Control, Alan Wake

What they share: the ordinary turned uncanny and played straight (Control's calm office voice inside a building that will not stay
put), light against a dark that is a presence, and a story that writes itself (Alan Wake), and warm, absurd surrealism (Star Rail).
This game already has the ground for it: the sky is false, magic is memory (the Gates of Mnemosyne) and forgetting (ΛΗΘΗ) waits at
the end. Weirdness works best rare, never explained on the spot, against a world that is otherwise ordinary. All of these are our
own, in our lore: nothing named or drawn from those games.

| | What it is | Kin to | Size |
|---|---|---|---|
| **The archive that rearranges** | A building, Mnemosyne's archive say, whose rooms change while out of sight: a corridor that loops until you notice what is wrong, a door that opens on a different room each time. The game knows what is on the screen, so it can change what is not | Control | Large |
| **Things that remember** | Ordinary objects charged with a memory, a stopped clock, a child's shoe, a lighthouse lens, each with one strange rule (the clock holds a guard still for a breath; the lens shows a room as it was). Bound to one of the party, each becomes a move outside fights | Control | Medium each |
| **Struck-out words** | Clues in the Journal with words blacked out that fill in as the party learns more; a gate that speaks as it opens, in a cold, official voice set apart by its type | Control | Small to Medium |
| **The forgetting dark** | Some foes wrapped in Lethe's dark that no blow reaches until light strips it: a Flare, Daylight, a lamp, fire, a Bright Area. On maps a dark that creeps and hunts, held back only by lit lamps, which become safe places | Alan Wake | Medium |
| **Pages ahead of time** | Pages found that tell what is about to happen, in the voice of Alithia's changed futures; it happens, unless a choice changes how the page ends | Alan Wake | Medium |
| **The sky slips** | Rarely, at the right moment, the sky over a map tears for a breath and shows what is behind it; people stop mid-word and go on as if nothing happened; the interface, which is the sky, flickers with it | The story | Small to Medium |
| **Friendly oddities** | Things with something to say: a statue that critiques your fighting, a bin with opinions, a lamp post that remembers you; small errands of absurd seriousness | Star Rail | Small each, and writing |
| **A dream-place** | Reached by resting: a memory palace where scale, gravity and colour bend, for puzzles, talks with the party, and fights rehearsed as runs with blessings drawn at random (the lab sequence already runs in stages) | Star Rail | Large |
| **Lethe's touch** | People who forget the party between visits, names on the map fading, a Journal entry lost until found again, a move forgotten for a fight (a condition). Some of this changes rules, so yours to weigh | The story | Medium |
