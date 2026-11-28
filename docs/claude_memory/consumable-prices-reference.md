---
name: consumable-prices-reference
description: "docs/consumables.csv is the user's price and power table for consumables (tiers I-IV); check and suggest against it whenever the user prices anything"
metadata:
  node_type: memory
  type: reference
  originSessionId: daf832bf-a3b0-42bb-854e-4dde88e2fdd6
  modified: 2026-10-22T21:41:50.096Z
---

`docs/consumables.csv` (2026-10-23) gives every consumable kind a tier (I 1-16, II 17-32, III 33-48, IV 49-64), its effect size and a SuggestedPrice. The user said: use it for prices, and **check them and suggest whenever they price stuff** - items, gear, spellbooks, store stock.

Price ladder by tier (single heal / group heal / ward / cleanse / bomb / cluster bomb / damage buff / speed buff / scroll):
- I: 50 / - / 60 / 40 / 45 / - / 40 / 40 / 60
- II: 120 / 150 / 130 / 110 / 120 / 140 / 120 / 120 / 150
- III: 240 / 280 / 260 / 260 / 260 / 280 / 240 / 260 / 300
- IV: 480 / 550 / 520 / 520 / 520 / - / 480 / 520 / 600

Applied 2026-10-23: Cure Potion 50, Mediocre 120, Potent 240, Medicine 40, Tiny Bomb 45, Small Bomb 140, Medium Bomb 280, Big Bomb 520, condition bottles 120, Gate Nades of gate 1-2 spells 60, gate 3 spells 150. Applied 2026-10-23 on the user's OK of my suggestions: spellbooks by gate 1-2 / 3-4 / 5-6 / 7-9 / 10 = 150 / 375 / 750 / 1500 / 2000 (about 2.5x the scroll); containers Utility Baldric 250, Coin Pouch 40, Belt Pouch 120, Hunter's Pouch 240, Large Pack 260, Grenadier's Pack 260 (Simple Baldric 15, Satchel 20, Traveller's Pack 60); cure potions heal only a share of max HP (`heal_share_of_health`, item_power 0): 25 / 40 / 55%.

Related: [[progression-csv-power-level]], [[balance-numbers-are-the-users]].
