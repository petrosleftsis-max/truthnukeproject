---
name: interface-look-direction
description: "The interface is back in the look from before T (designer, 2026-11-21): ui/blue_theme.tres, End Turn in the accent, each screen's own palette; SkyLook (T) kept but not applied; no more UI look suggestions unasked"
metadata:
  node_type: memory
  type: project
  originSessionId: 322dee5d-0ec4-44ab-8eeb-9bb32627375c
  modified: 2026-11-21T17:20:00.312Z
---

**Since 2026-11-21 the interface is in the look from before T** ("Change the UI style to what it used to be ... i meant the
style before teh sky style i chose"): ui/blue_theme.tres as it stands, End Turn in the accent (combat_ui._style_turn_buttons,
_accent_box), and each screen that draws its own cards with its own palette (INK dce8f5, INK_DIM c2ceda, ACCENT 4a86c8, PANEL
19212c, CARD 1c2531, CARD_LIT 24344a, CARD_EDGE 2b3947). SkyLook (ui/sky_look.gd) is kept whole but never applied. Same day the
designer asked for the coloured skill-slot rings back: they are on the old look now (SkyLook.ring_plain_slot: the theme's own
button, edge 2 wide in the icon's colour). Bringing T back = SceneTransition calling SkyLook.apply() and the call sites as in
commit fca4fa6.

History (docs/proposals_2026-11-07.md section 20; the artifact "Messengers of Truth Interface Styles",
https://claude.ai/artifact/9ji9fNjhKNK5jW1pyCevqK):
- 2026-11-12: liked A (illuminated codex) and E (night sky); blue and justice. F to I turned down.
- 2026-11-13: "I actually really like K" (smooth blue night coming apart into pixels); O to T drawn.
- 2026-11-17: "Do T: K, Lighter" - built as SkyLook. "You don't need to give further suggestions for the UI."
- 2026-11-19: reopened because the artist's skill icons sat badly with T; kept T, added rings in each icon's colour.
- 2026-11-21: back to the look before T.

**Why:** the artist's work (above all her skill icons) is what the interface has to sit well with; the designer has gone back and
forth, so keep T recoverable rather than deleting it.

**How to apply:** build new UI in the old look (the theme's panels and buttons, the old palette above, a journal-like flat box for a
menu panel), not SkyLook. Don't pitch other looks unasked. Keep red for health and danger. Under T the designer asked for skill
icons to fill their slots (2026-11-17); whether they want that in the old look is open. Related: [[placeholder-assets-with-slots]].
