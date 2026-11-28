---
name: party-health-at-64-open
description: "Open balance issue reported 2026-10-23 - party health barely grows, so level 64 enemies one-shot everyone but Enfina; awaiting the user"
metadata:
  node_type: memory
  type: project
  originSessionId: daf832bf-a3b0-42bb-854e-4dde88e2fdd6
  modified: 2026-10-23T14:42:28.080Z
---

Found with the level-64 test fight (data/encounters/level_64_showdown.tres, "Sixty-Four"; probe tests/probes/sixtyfour_test_driver.gd logs its turns): the party's health grows only 1.5-1.9x from level 1 to 64 (Enfina 130->190, Cyrus/Alithia 75->115, Prometheus 30->58) while hits grow ~5x (attribute 10->85) and more with multipliers. At 14 a Barbarian needs ~3 swings to down Cyrus; at 64 one (Titanfall 129-143). The whole party falls in the first enemy round. The enemy CSV does not change enemy damage, so it did not fix this.

The player sheet (2026-10-23) kept the same HP and set Defense 28 from 17: a level-64 Titanfall on Cyrus 143 -> 126 vs his 115 HP, Fireball on Prometheus 95 -> 84 vs 58 - still one-shots. My suggestion (not applied): party level-64 health about Enfina 600, Cyrus/Alithia 350, Prometheus 140 (the enemies' growth factor), bringing back ~3 swings. No design sheet covers party health ([[design-csvs-are-the-spec]]). Also noted: enemy turns at 64 take ~2 s each to plan (10 enemies ~21 s).

User playtest 2026-10-24: won Sixty-Four easily, then with nobody falling and Alithia hit once - my probe let only enemies act, so it overstated the danger. In play the party has the initiative (5-8 vs enemies 3-4), level-64 area spells one-shot the CSV-sized enemies, and Illusory Guardian makes the first blow on each of the party miss. The real issue is that whoever acts first wins at 64, and enemies have no high-tier moves.

**Why:** balance numbers are the user's ([[balance-numbers-are-the-users]]).
**How to apply:** don't change party health until the user decides; bring it up when level-64 balance or health comes up.
