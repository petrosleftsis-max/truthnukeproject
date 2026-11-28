---
name: durations-count-one-more
description: Durations are exact N of the target's turns (user's rule 2026-10-24); on whoever is acting the rest of the current turn comes on top (kept by the user)
metadata:
  type: project
---

The user's rule (2026-10-24, answering my question): "N turns" means N of the target's own turns. Built: `Combat.turns_stored(duration, at_start, lands_on_actor)` is duration, +1 only when the effect lands on whoever's turn it is (`on_whoever_acts`) and wears off at the end - so Run 1 is still this turn and the next, and a self-buff cast last thing in a turn isn't wasted. Before, every at-end effect was stored +1 ("Blind 3 is four blind turns"), so effects on enemies lasted, and DoTs ticked, one turn more than written. The `ammo` suite checks Warning Shot 2 / Frost Round 1 / Corroded 3 (+1 DoT Master II).

**Why:** the user's design sheets give durations and DoT value as dial x turns; [[design-csvs-are-the-spec]].
The rest-of-turn bonus on the actor was my choice at first; the user kept it ("Keep it as it is", 2026-10-24), so it is APPROVED_DESIGN in the ledger.

**How to apply:** an effect's written duration is the target's turn count, plus the rest of the current turn when it lands on whoever is acting. Don't reopen it.
