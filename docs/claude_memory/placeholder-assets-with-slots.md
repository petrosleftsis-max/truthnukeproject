---
name: placeholder-assets-with-slots
description: "All art and sound I make is a placeholder; the user makes the real art and sound themselves and fills slots later"
metadata:
  node_type: memory
  type: feedback
  originSessionId: daf832bf-a3b0-42bb-854e-4dde88e2fdd6
  modified: 2026-10-30T18:36:41.472Z
---

When a feature needs sounds, cursor art, effects or animations, build generated placeholders (synth blips, drawn glyphs, tweens, code-drawn effects) behind exported slots the user can fill later (e.g. `pictures/feedback.tres` / PictureFeedback, SkillDefinition's projectile texture/scene and sound slots), plus per-node overrides and AnimationPlayer hooks. The user approved this approach ("Simple and effective") on 2026-10-02, and on 2026-10-30 said they will handle the art and sound themselves: "every art and sound you make i only want as placeholders for now to develop the game".

**Why:** they make the final art and sound; my stand-ins only have to make the game playable and readable while it is developed.

**How to apply:** never ship real audio/art downloads or AI-generated final assets; keep stand-ins simple and clearly replaceable; an empty slot falls back to the placeholder, a filled one replaces it slot by slot. Don't push art/sound plugins on them. See [[balance-numbers-are-the-users]] for the same "user owns the content" spirit.
