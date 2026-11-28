---
name: numbers-are-open-until-playtested
description: The design handoff's working rules (docs/handoff_0.1, 2026-10-24) - repo is truth, two-column status model, only approved trials get implemented, ledger and audit files, current priorities
metadata:
  type: feedback
---

The user relays Perplexity's instructions as theirs; the latest is the handoff package in `docs/handoff_0.1/` (read `claude_working_instructions.md` first). It superseded the five-status list from earlier the same day.
- The repository is the implementation truth; `docs/perplexity_combat_context.md` is a dated snapshot - report mismatches, don't overwrite code to match it.
- Two statuses per value: ImplementationState PRESENT / ABSENT / VERIFY; DecisionStatus EXISTING_BASELINE / APPROVED_TRIAL / PROPOSAL / OPEN / APPROVED_DESIGN, plus OPTIONAL_TUNING_TOOL (kept on hand, not baseline - the heal cap). Blank = unknown, never zero. Ranges are references for testing.
- Implement only what the designer approved (the Cyrus four-edit trial was the only one); confirm scope before anything else; propose the rest as PROPOSAL.
- Don't broadly change party HP, enemy damage, gear, rewards, boss stats or encounter composition yet. Level 64 (Sixty-Four) is a regression test, not the target; Chapter I (1-18) is.
- Files: `docs/design_status_ledger.csv` (verified ledger), `docs/chapter1_audit.md` (audit answer), `docs/chapter1_inventory.csv` (every value with source; `tests/run.sh chapter1`).
- Decided 2026-10-24: Corroded keeps Corrosive Round's -10% Defense; Catalyst keeps every-enemy scope (exact rule in docs/design_status_ledger.csv; ammo suite checks it; no change without a trial); Self Destruct stays untelegraphed (teaches reading enemies); Erysichthon closes Chapter I (also a run-away cameo in the first encounter, plus a supporting enemy - not built); the actor's rest-of-turn bonus kept; Catalyst is Cyrus's personal condition payoff on purpose (only his conditions; team-wide synergy, if ever, is a separate mechanic, never folded into Catalyst).
- The laboratory sequence (docs/lab_sequence.md): Erysichthon at 18 is the primary boss variant, the Ash Warden at 18 a second; no control-resistance system until the Erysichthon runs show chain-control removes meaningful decisions.
- Still open: Tripwire/Minefield x1.2; Venom Fan tie with Exposing Shot; Chapter I itinerary 15-18; Erysichthon's Chapter I level and supporter.

**Why:** numbers are designed outside the game and settled by playtesting; the designer decides scope.
**How to apply:** report in the two-column statuses with source paths; ask before implementing anything beyond an approved trial. Related: [[design-csvs-are-the-spec]], [[balance-numbers-are-the-users]].
