---
name: user-plays-with-playstation-pad
description: "The user has a PlayStation controller plugged in and names its buttons (Square, Circle) when asking for pad features"
metadata:
  node_type: memory
  type: user
  originSessionId: daf832bf-a3b0-42bb-854e-4dde88e2fdd6
  modified: 2026-10-06T23:38:18.135Z
---

The user tests the game with a PlayStation pad (detected as device 0 in windowed runs, so screenshots show "R2", "Circle", "Create"). They describe pad requests in PlayStation terms: Square = Godot's JOY_BUTTON_X (west), Circle = JOY_BUTTON_B (east).

**How to apply:** map "Square"/"Circle"/"Triangle"/"Cross" to X/B/Y/A when wiring actions in `project.godot`'s `[input]`; button names on screen come from `Pad.key()`. Headless test runs don't see the pad, so tests get Xbox names. Related: [[ui-screenshot-workflow]].
