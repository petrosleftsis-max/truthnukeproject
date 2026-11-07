# Shine masks: telling the game what each part of a drawing is made of

A shine mask is a second picture for each frame. It shows the light which parts of the figure are matte, shiny, or metal.
Where a mask exists, lights and wet weather put a highlight on what it marks. Without one, the figure is lit as before.

## The file

Make one picture for **each frame**, the same size as the frame, and put it beside it. Name it the same, with `_shine` in place of
`_color`:

```
art/characters/alithia/idle/alithia_idle_color0003.png   the frame
art/characters/alithia/idle/alithia_idle_shine0003.png   its shine mask
```

A frame whose name has no `_color` takes `_shine` on the end instead: `barrel.png` and `barrel_shine.png`. A frame without a mask
is matte all over, so you can do one animation, or only the idle, and leave the rest.

The easiest way is to add a layer to the drawing and export it the way you export the colour layer. Keep the same frame
numbers and the same size. The mask has to sit exactly over the frame.

## What to paint

Paint flat colour over each part of the figure. Only two channels are read:

| Paint | Means | For |
| --- | --- | --- |
| **Black**, or nothing | Matte | Skin, cloth, hair, wood |
| **Red** | Shiny, with a white highlight | Polished leather, wet things, glass, lacquer, a varnished staff |
| **Yellow** (red and green together) | Metal: the highlight takes the metal's own colour | Enfina's greatsword, buckles, Cyrus's gun, gold trim |
| **Green** alone | Nothing yet: green only changes what red does | |

**How much** comes from how bright the red is. Full red is as shiny as it gets, dark red is a little shiny, and 50% is a soft sheen
like leather. The same goes for green inside yellow: full yellow is plain metal, and orange (full red, half green) is metal with some
of the light's own colour left in its highlight.

Paint inside the figure's outline. Outside it, the mask is not read.

## What it does in the game

A light near the figure (a lamp, a torch, a spell's light) puts a small, sharp highlight on what the mask marks, on the side facing
it. The sun does the same, more softly, from above. Rain adds a gloss of its own to everybody under the open sky, so with a mask
the rain shows most on what is already shiny.

The code is `CombatantSprite.shine_mask_for` (where it looks) and the "shine" part of `FIGURE_SHADER`. Nothing about a mask
changes a rule.
