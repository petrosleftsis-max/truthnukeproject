# Boss control rules — proposal 0.1

## Start with existing behavior
The snapshot already describes per-creature immunities, stagger gain from blocked stuns, hazards and interrupted declared moves. Verify these before adding a replacement system.
The designer's level-64 ordinary-enemy wins do not demonstrate that bosses can be permanently controlled. Test that hypothesis first.

## Baseline test
Use an existing boss at its intended story level with actual campaign gear and spells. Log boss turns offered, turns lost, commands cancelled, source of cancellation, stagger gains, vulnerable windows, damage received by party and every down.
Separate hard control (lost turns or involuntary target control), movement control (root/slow/fear), and debuffs/DoT. Frozen in this game prevents secondary action and slows movement; do not equate it with a full stun.
Test no-control, normal mixed tactics and deliberate control chaining. Check multiple-turn-per-round bosses: one lost turn is not necessarily one lost round.

## Preferred first option: existing stagger conversion
Preserve per-boss identity. If a boss is explicitly immune to a turn-loss condition, retain the attempted skill's normal hit and legal other effects, then route the blocked control into the EXISTING stagger mechanism if supported. Verify current behavior; do not award duplicate stagger from the same event.
Do not automatically make bosses immune to all poison, movement control or stat debuffs. Body size, anatomy and phase mechanics should justify exceptions.
No final stagger-gain numbers are assigned here. Export current threshold and gains; tune contribution against the observed number of boss actions between staggers.

## Optional fallback only if chain-lock is reproduced
Trial a shared hard-control resistance window rather than a separate immunity for every status: after a hard-control-induced turn loss, further hard-control attempts cannot remove the next scheduled boss action and instead contribute only the normal eligible stagger gain. Expire the window after that action resolves. This is a proposal, not approved implementation.
Specify interactions before coding: phase transitions, stagger, interrupted declared moves, fear, Confused, Deceived, Recanted, multi-turn initiative and summon behavior. Do not let several differently named stuns bypass the protection.
Prefer a clear protected-action indicator over hidden diminishing durations. Do not implement universal diminishing-duration rules by default.

## Fairness checks
A protected boss action still needs readable counterplay through movement, mitigation, cover or another existing mechanic. Never guarantee damage merely because the boss is control-resistant.
If unavoidable party-wide damage is lethal, examine warnings, safe tiles, mitigation access and the specific hit before raising global HP.
Do not automatically clear all DoTs on phase change: it can erase the payoff for damage-over-time builds. Explicitly document any cleanse and show it before commitment where practical.

## Acceptance
Boss receives meaningful opportunities to act; control builds still contribute; no single named control bypasses intended rules; ordinary enemies retain their existing vulnerability; interrupts and environmental mechanics remain rewarding.
Choose any numerical acceptance targets with the designer after observing baseline. Recheck level 64 after implementation, including Cyrus DoT and control interactions.
