---
name: lethality-rule
description: Designer's lethality intent (2026-10-24) - ignored telegraphs may down Prometheus; Cyrus/Alithia survive ordinary telegraphs; fair vs unfair lethality; never fix by broad HP raises
metadata:
  type: project
---

Designer's intent (via Perplexity, 2026-10-24): telegraphed attacks should be devastating if ignored. Prometheus is meant to be fragile enough that an ignored telegraphed attack can down him - desired. Cyrus and Alithia should generally survive ordinary telegraphed attacks unless especially powerful; Enfina most, but stay vulnerable to major boss attacks. Don't solve fragility by broadly raising Prometheus's HP; verify readable counterplay instead (visible warning area, time/movement to escape, path blocking, Hack/InstaHack where apt, protection: Intuition, Guard, cover, illusions, interception).

Review encounters as **fair** lethality (telegraphed, avoidable, interruptible, protectable) vs **unfair** (unclear warning, no viable response, damage out of proportion). The probe `tests/run.sh chapter1` writes a "Lethality review" into docs/chapter1_inventory.csv; docs/chapter1_audit.md section 9 summarises it. Found: the Bomber's Self Destruct is not telegraphed and downs Prometheus in one in the Lab Fight, City Fight, Dungeon Demo and lab stage A - the only Chapter I UNFAIR candidate - and the designer KEPT it as is (2026-10-24): "it teaches the player to read enemy moves". So an untelegraphed but readable threat (visible bomber, danger view) can be fair by design; ask rather than assume. Only declared moves (Ground Pound, Rockfall, Devour) are telegraphed; only Devour is hackable.

**Why:** the designer wants danger to come from readable choices, not from health totals ([[party-health-at-64-open]], [[numbers-are-open-until-playtested]]).
**How to apply:** when judging a dangerous attack, check its counterplay against this rule and report fair/unfair; propose telegraph or counterplay fixes, not HP raises.
