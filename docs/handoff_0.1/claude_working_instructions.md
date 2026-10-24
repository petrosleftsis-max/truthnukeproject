# Claude working instructions — draft 0.1

## Authority and scope
This package is a design proposal, not an instruction to rewrite the entire game. The designer authorized preparation of these documents. Only the Cyrus numerical trial has been requested for application; confirm scope before other implementation.
Use the actual repository as implementation truth. The combat-context export is a dated snapshot; report discrepancies rather than overwriting newer code.
Preserve approved mechanics: no cooldowns, no forced taunts, milestone progression, current paths and action structure. Missing spreadsheets do not mean existing mechanics are unapproved.

## Status model
Use two columns: ImplementationState (PRESENT / ABSENT / VERIFY) and DecisionStatus (EXISTING_BASELINE / APPROVED_TRIAL / PROPOSAL / OPEN / APPROVED_DESIGN).
Implemented and provisional are not mutually exclusive. APPROVED_TRIAL means approved for testing, not final balance.
Record source, current value, proposed value, dependencies, evidence, acceptance test, owner, version and outcome. Blank means unknown, never zero.

## Order of work
1. Export relevant current repository values, including inherited defaults and rank overrides.
2. Apply only the four Cyrus trial edits in the supplied CSV; preserve all other fields.
3. Map actual Chapter I encounters, party availability, spell acquisition, stores and rest points.
4. Select a representative early battle and a late-Chapter-I sequence ending in an existing boss.
5. Propose missing values and test them; request designer approval before implementation.
6. Keep level 64 as a regression test, not the primary tuning target.

## Evidence corrections
The designer won the level-64 encounter carefully with no deaths and only one hit on Alithia, and won even more easily while freely spending resources. These are qualitative self-reports, not logged telemetry. They do not establish boss survival, resource attrition, or newcomer difficulty.
Do not globally raise party HP on the basis of the older first-round defeat report.
Earlier suggested gear ranges, encounter sizes, party initiatives and intermediate HP examples are not validated exports. Verify them before using them.
Cyrus ammunition is implemented as skills: do not invent ammunition consumption to justify its strength.
Burning Shot has a Physical direct hit and Fire DoT; do not convert the direct hit to Fire.
Catalyst scope and damage semantics must be checked in code; the plain-language snapshot is ambiguous about remaining DoT damage versus tick count. Do not implement from a paraphrase.
The snapshot also disagrees about Cyrus movement unlock timing. Export the effective passive/rank behavior.

## Deliverable from Claude
Return an inventory of verified values, mismatches, proposed edits, affected shared enemy resources, and tests. Update design documentation only after the corresponding code change, retaining trial status.
