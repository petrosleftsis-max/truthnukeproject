# Proposals, 2026-11-06

Suggestions the designer asked for on 2026-11-06. Nothing here is built. Gates and tethers are
suggestions, and everything here is a PROPOSAL until the designer picks it.

## 1. Enchantment

| Idea | Gate | Tether | What it does | Rests on |
| --- | --- | --- | --- | --- |
| Friends | World | none | On a map, a guard who is looking at them talks instead of raising the alarm. In a fight, one enemy will not target her until hurt | `Guard.fooled`, a new "will not target" switch |
| Charm | World | 100 | Contested: they will not attack her or whoever she names unless hurt | `comes_off_when_hurt`, the same switch |
| Sleep | Hermes | 200 | An area of Stunned that ends when hurt, reaching the lowest Mindfulness first, up to a total | Mesmerise's condition, a new "up to a total" |
| Hold Still | Hermes | 200 | Contested: rooted, and no reactions | `prevents_movement`, `prevents_reactions` |
| Calm | Hermes | 200 | An area: fear and confusion come off her side, and the other side's Rage-like boosts stop | Unafraid's `immune_to_conditions`, `dispel_status_effects` |
| Suggestion | Pandora | 200 | On a map, a guard walks off on an errand. In a fight, Compel's orders for two turns | `send_away`, `obeys_order` |
| Crown of Madness | Pandora | 200 | Contested: each turn they go for the nearest of their own side | Deceived's `turns_on_own_side`, held by a tether |
| Enthrall | Pandora | 200 | Contested, in an area: they may only look at her, so anything aimed at anybody else is refused | `refusal_for`, a new condition switch |
| Compulsion | Charon | 200 | Contested, in an area: she points a way, and at each of their turns they walk it first | Phantom Noise's `drawn_to_aim`, held by a tether |
| Dominate | Charon | 400 | Contested: the player plays their next turns | `switch_sides`, Compel's orders |
| Modify Memory | Tartarus | none | On a map, a guard forgets what he saw and the alert drops one. In a fight, they forget who hurt them: focus and intent cleared | `lower_alert_level`, `_ai_focus_id`, `comb.intent` |
| Geas | Nemesis | 200 | Contested: whenever they attack anybody but her, a psychic wound | A condition's new "hurts on acting" |
| Feeblemind | Ogdoad | 400 | Contested: no spells, and they think like a beast | `prevents_spells`, `ai_smarts` set to Instinct while it holds |
| Word of Stunning | Gnosis | none | Below a share of their health, Stunned, no contest | A skill's new "only below" |
| Word of Death | Yaldabaoth | none | Below a share of their health, down, no contest | The same |

## 2. Divination

| Idea | Gate | Tether | What it does | Rests on |
| --- | --- | --- | --- | --- |
| Guidance | World | none | The next blow of an ally cannot miss | A condition, `hit_chance` |
| Identify | World | none | Studies somebody from afar, no action spent on walking up | `study`, the codex |
| Detect Magic | World | none | On a map, sensors, wards, magic traps and the invisible show for 30 seconds. In a fight, unseen zones and unseen traps | `zone_unseen`, `MagicTrap`, `Guard.Kind.SENSOR` |
| Augury | Hermes | none | Shows where reinforcements will arrive and what the arena marks next | `arrival_warnings`, `_hazard_marks` |
| Detect Thoughts | Hermes | 100 | On a map, a guard's round. In a fight, Intuition on one enemy | `learn_route`, `read_intent` |
| Locate | Pandora | none | On a map, every guard is marked through walls for 20 seconds. In a fight, whoever is hidden from her shows faintly | `seen_by_gaze`, `unseen_by_party` |
| Scry | Pandora | 200 | A look at another room without a familiar, from a spot chosen on the map | `FamiliarKeeper._show_sight` |
| Arcane Eye | Charon | 200 | A familiar nothing can see or feel, that hides nowhere and touches nothing | `Familiar`, `FamiliarForm` |
| Find the Path | Charon | none | On a map, a line to the objective for 60 seconds | `StealthGoal` |
| Commune | Tartarus | none | Says what a boss's next phase will do before it starts | `BossPhase` |
| True Seeing | Nemesis | 200 | Sees the unseen and in the dark, and the other side's illusions are nothing to them | `sees_the_unseen`, `sees_in_darkness`, `believes_illusion` |
| Premonition | Sophia | none | A reaction: as a declared blow lands on them, they are somewhere else | `reacts_when`, `teleport_to` |
| Contact Beyond | Ogdoad | none | Intuition on every enemy at once. Contested against the highest Mindfulness there: she is Confused if she loses | `read_intent`, `confuses` |
| Foresight | Gnosis | 400 | The first blow each round at them misses, and they cannot be surprised | `evades_hits`, `guards_first_blow`, `catch_off_guard` |

## 3. More ways to tell enemies apart

Smarts and the four dials are built. These are more:

| Idea | What it does |
| --- | --- |
| **Barks** | A short line over their head as they choose: "Get the healer!", "Spread out!", "Where did he go?" Built on what the AI already decided, this is what lets a player feel who is clever. *The most worth doing.* |
| **Commanders** | While a Mastermind or Cunning leader stands, those near it think one level higher. Bringing it down makes the rest stupid, on top of the Nerve hit `leads` already gives |
| **Mistakes** | Instinct and Trained choose among their top few plans by `Combat.rng`, Mastermind always the best. Same seed, same fight |
| **Grudges** | Goes for whoever hurt it last, whoever is better to hit (`last_hurt`) |
| **The Hunter** | Picks a mark at the start of the fight and ignores everybody else until it falls |
| **The Bodyguard** | Stays within a few tiles of a named ally, and takes reactions for them |
| **Pack tactics** | Holds back until two or more of them can reach the same target |
| **The Show-off** | Rather kills up close and in sight of everybody; will not run; Pit Champion |
| **The Greedy** | Goes for whoever carries the most, and leaves with it (`steal`, `when_fled`) |
| **Fears** | One element it will not walk beside, per creature: beasts and fire |
| **Learning** | Once an image has shattered in front of it, a Mastermind's side stops believing images for the rest of the fight |
| **Moods by phase** | A boss's phase changes its dials: careful at first, reckless when hurt |

## 4. Making light look better

All of it is view only and changes no rule. Roughly in order of how much it would show for the work:

| Idea | What it does |
| --- | --- |
| **Real lights** | A `PointLight2D` on each source, in its colour, over the soft shade that is there now, with flicker |
| **Shadows** | `LightOccluder2D` built from the Blocks tiles, so walls and pillars cast real shadows across the floor |
| **Figures against the dark** | A faint rim or outline on whoever stands in Dark, and eyes that glow for those who see in it |
| **Dim as its own look** | Colours drained a little in Dim and much more in Dark, by a screen shader on the shade map, rather than only darker |
| **Figures' own shadows** | A soft shadow per figure, pointing away from the nearest light, or leaning with the hour outdoors |
| **Normal maps** | Your real art with normal maps, so light wraps round it. A slot on each sprite, and only for when the art exists |
| **What hangs in the air** | Embers round fire, dust in the light, slow fog in the Dark, god rays through a window or door Opening |
| **Hours graded** | A colour grade per hour rather than one tint: gold at dusk, blue at night, grey at dawn |
| **Edges** | Fades between levels, and a dithered tile edge if the art ends up pixel art |
| **Light moving** | Light that eases on and off rather than snapping when a lamp breaks, a door opens or somebody burns |

## 5. What the enemy's mind did to the fights

These are measurements, not proposals. They come from `tests/run.sh aicompare`, a probe that plays each
fight from one seed, before (nobody knows anything, every dial at 1) and now. Nobody plays the party in
it, so read it as a before and after, not as how hard a fight is.

| Fight | Party standing still: damage taken in 3 rounds | Rounds to fell them | AI on both sides: party health left |
| --- | --- | --- | --- |
| Sewer Intro Fight | 75 -> 75 | 8 -> 8 | |
| Lab Fight | 106 -> 106 | 3 -> 3 | 7% -> 10%, lost both times |
| City Fight | 382 -> 403 | 2 -> 3 | |
| Hired Blades | 211 -> 211 | 4 -> 4 | 20% -> 60%, won both times |
| The Bound Golem | 263 -> 255 | 6 -> 5 | |
| The Alchemist | 517 -> 421 | 2 -> 2 | |
| The Summoner | 128 -> 145 | 8 -> 9 | |
| The Bellkeeper | 134 -> 127 | 5 -> 5 | |
| The Ash Warden | 135 -> 107 | 7 -> 7 | 0% -> 0%, lost both times |
| Erysichthon | 73 -> 83 | 10 -> 9 | |
| Sixty-Four | 661 -> 592 | 3 -> 2 | |

Who thinks how, all of it PROPOSAL and per creature:

| Smarts | Who | Dials (1 unless said) |
| --- | --- | --- |
| Instinct | Rat, Gnawer, Imp, Bound Beast, Behemoth, Colossus, Golem, Ogre | |
| Trained | Barbarian, Sellsword, Pit Champion, Hired Bow, Bomber, Mimic, Erysichthon | Barbarian aggression 1.3, caution 0.6. Sellsword self-preservation 1.5. Pit Champion aggression 1.2, focus 1.3. Hired Bow caution 1.3. Bomber aggression 1.4, caution 0.3. Erysichthon never keeps from hazards, so a baited keg still works |
| Cunning | Ranger, Sorcerer, Priest, Alchemist, Summoner, Bellkeeper | Ranger caution 1.3, focus 1.3. Sorcerer caution 1.3. Priest caution 1.4, self-preservation 1.3. Alchemist caution 1.2 |
| Mastermind | Ash Warden | |
