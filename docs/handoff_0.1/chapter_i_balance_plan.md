# Chapter I balance plan — proposal 0.1

## Scope
Primary target: actual Chapter I, levels 1–18 in the current plan. Level 64 remains a regression test. This is not a story rewrite or a final numeric balance sheet.
Preserve current HP, damage formula, gates and encounter content until a controlled test shows a specific failure.

## First audit
Export effective stats at levels 1, 4, 8, 11, 14, 16 and 18: HP, equipment, Defense, initiative, movement, resistances, learned skills and gates per caster. Use actual rounding and inheritance. Distinguish arena knowledge from campaign spell ownership. Verify party membership at each story point.
Export enemy hit multiplier, scaling attribute, weapon base, accuracy/contest, area shape, friendly fire, movement and initiative. Frail does not mean low threat.
For every skill resolve condition defaults plus source overrides, duration tick timing and reapplication policy.

## Damage and AoE audit
Compare alternatives at the same level, equipment, target Defense and resistance. Include range, accuracy or graze, action cost, gate cost, safety, friendly fire and acquired-spell availability.
Report direct hit, actual DoT ticks before death, conditions applied, enemy actions prevented and overkill separately. Do not add raw DoT modifiers to mitigated direct-hit modifiers as if they shared a denominator.
Compare AoEs at one, two and three distinct creatures; do not count a multi-tile creature repeatedly unless the engine actually does. Verify primary-target versus splash overlap.
Flag same-cost moves that outperform another in every relevant property. A costlier gate may intentionally outperform a cheaper one.
Audit Holy Lance versus Holy Splash (wide line versus small diamond), River Flow versus Frozen River (same diamond radius, different gates/conditions), and Communion versus Revitalizer (overlapping group-heal roles). Inspect actual heal coefficients instead of assuming them from labels.

## Cyrus isolated trial
Apply the four direct-hit changes only. Keep DoT, range, conditions, unlocking, costs, damage types and other skills unchanged. Gun remains 1.0; Rapier remains unchanged. Combined Load retains its current multiplier pending a dedicated test.
A lower hit modifier does not guarantee Gun wins every finisher comparison: differing ranges, types and passives may change the result. Test actual previews.

## Encounter validation
Use the accompanying encounter CSV as sandbox patterns, not claims about existing story fights. Map each pattern onto a real map only after checking party availability, actual spell access and story intent.
A no-hit expert win is not inherently a failure. Ask whether several reasonable tactics work and whether mistakes are understandable to a first-time player.
Record rounds, effective enemy actions, actions denied by reason, hits, downs, healing, resource use by gate/caster, consumables and duration. Keep expert and newcomer results separate.

## Resource-sequence experiment
After confirming a representative sequence exists, run the same sequence using conservation and free-spending policies. A three-fight sequence is a proposed laboratory test, not a Chapter I rule.
Checkpoint each caster's gates by depth and party HP; no artificial refill between the laboratory fights. Compare final-boss options, difficulty and total resource use. Also test the actual story recovery policy separately; do not silently replace it.
Hypothesis: spending heavily should make one fight easier but leave meaningful later tradeoffs. If careful play is indefinitely safe with no expenditure, scarcity alone may not create pressure; inspect enemy behavior and objectives before nerfing all control.

## Economy validation
Build a chronological budget from actual initial gold, mandatory rewards, optional rewards, loot resale, shops and required payments. Distinguish owned loot from realized sale income; do not count the same purse twice.
Use current prices as baseline. The chapter crosses the proposed item-tier boundary at level 17; this is not an automatic instruction to replace shop stock.
Test whether critical-path purchases and unavoidable payments are affordable without optional grinding. Optional upgrades should compete with utility and consumables, not block required progression.
Do not add paid gate recovery merely to force spending; define availability and recovery design first. Avoid a debt/death spiral in which a weak party cannot afford recovery.

## Pass criteria and decisions
Agree encounter-specific targets before tuning; universal round or hits-to-kill targets are not final design rules. Inspect unintended dominance, misleading predictions, unavailable counterplay and critical-path insolvency first.
Change one family of variables per trial. Keep before/after saves and outcomes. Do not use a Chapter I test to finalize tier III/IV gear or level-64 boss HP.

## Handoff
Claude supplies verified effective values and actual encounter mapping. Designer approves any new numerical choices. Update ledger after testing; retain rejected variants for traceability.
