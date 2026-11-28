---
name: damage-wording-rule
description: "Player-facing text says damage changes in numbers - \"N% Damage Mitigation\", \"+N% Output Efficiency\"; the Bright light level is \"a Bright Area\""
metadata:
  node_type: memory
  type: feedback
  originSessionId: 412f4ae7-2541-4ae2-8cf5-90aa6d8c79cb
  modified: 2026-11-19T03:22:06.209Z
---

In every player-facing text (descriptions in .tres, tooltips, the sheet, the log), a damage or healing change is a number, never a word ("10%", not "a tenth"): less damage taken is **"N% Damage Mitigation"**, more damage or healing dealt is **"+N% Output Efficiency"**. The Bright light level is **"a Bright Area"**, never just "Bright".

**Why:** the designer, 2026-11-17: words like "a tenth" and a bare "Bright" read as misleading.

**How to apply:** the pass of 2026-11-17 settled the edge cases - more damage *taken* (Exposed, Staggered, Prone's melee) reads "+N% Output Efficiency against them"; less damage *dealt* (Disarmed, a graze) reads "N% Damage Mitigation against" it; armour lowered is "-N% Defense"; resistances are Damage Mitigation too. Frailty ("a tenth weaker"), temporary health, times and movement were left in words as not damage changes. Dim and Dark were still single words, pending the designer. Ledger row "Damage Mitigation and Output Efficiency". See [[design-csvs-are-the-spec]].
