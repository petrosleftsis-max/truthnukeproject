# Sound slots: what is filled, what plays a stand-in, what is silent

Every sound the game asks for, as of 2026-11-12 (made by `perl tools/sound_slots.pl` over the data; run it again when sounds go in). **Yours** is a
file you placed. A **stand-in** is a placeholder made in code on the spot (`exploration/PlaceholderSounds.gd`), heard until a file
fills the slot. **Silent** is a slot that plays nothing until filled. Fill a slot in the editor: the sound bank is
`audio/sound_bank.tres`, the pictures' `pictures/feedback.tres`, a move's or a condition's own file (its Sound fields).

## The sound bank (`audio/sound_bank.tres`)

| Group | Slot | Now |
| --- | --- | --- |
| Fights opening and closing | `card_opening` | yours |
| Fights opening and closing | `card_victory` | yours |
| Fights opening and closing | `card_defeat` | yours |
| Fights opening and closing | `card_fled` | yours |
| Fights opening and closing | `boss_reveal` | yours |
| Falling | `boss_falls` | yours |
| Falling | `party_falls` | yours |
| Falling | `enemy_falls` | yours |
| Moves | `travel` | yours |
| The day | `birds_at_dawn` | **empty, silent** |
| The day | `insects_at_dusk` | **empty, silent** |
| The day | `crickets_at_night` | **empty, silent** |
| The day | `rain_falling` | **empty, silent** |
| The day | `wind_blowing` | **empty, silent** |
| The day | `thunder` | **empty, silent** |
| Steps | `footstep` | stand-in: a soft thud |
| Steps | `footstep_wet` | stand-in: a splash |
| The character sheet | `codex_reveal` | stand-in: three rising notes |
| Hacks and the world | `hack_failed` | yours |
| Hacks and the world | `hack_clock` | yours |
| Hacks and the world | `hack_clock_urgent` | yours |
| Hacks and the world | `solved` | yours |
| Hacks and the world | `mechanism_used` | yours |
| Hacks and the world | `mechanism_opened` | yours |
| Hacks and the world | `caught` | yours |
| Hacks and the world | `levels_unveiled` | yours |
| Menus | `menu_press` | yours |
| Menus | `ping` | yours |
| Menus | `bag_open` | yours |
| Menus | `item_moved` | yours |
| Menus | `rummage` | yours |
| Menus | `coin` | yours |
| Menus | `page` | yours |
| Menus | `learned_spell` | yours |

## Pictures and puzzles (`pictures/feedback.tres`)

| Slot | Now |
| --- | --- |
| `hover` | stand-in |
| `look` | stand-in |
| `take` | stand-in |
| `talk` | stand-in |
| `go` | stand-in |
| `back` | stand-in |
| `locked` | stand-in |
| `use_right` | yours |
| `use_wrong` | stand-in |
| `combine_right` | stand-in |
| `combine_wrong` | stand-in |
| `clue` | stand-in |
| `deduction` | yours |
| `no_deduction` | stand-in |
| `present` | stand-in |
| `dial` | yours |
| `pick_up` | stand-in |
| `put_down` | stand-in |
| `snap` | yours |
| `solved` | yours |
| `lens` | stand-in |
| `journal` | yours |

## Conditions that tick (each condition's Tick Sound)

A tick plays the condition's own sound, else the sound of the move that put it on.

| Condition | Now |
| --- | --- |
| Burn | yours |
| Crystallised | the move's own, or silent |
| Dread | the move's own, or silent |
| Frozen | the move's own, or silent |
| Phantom Wound | the move's own, or silent |
| Poisoned | the move's own, or silent |
| Shared Fire | yours |
| Swallowed | the move's own, or silent |
| Windswept | the move's own, or silent |

## Moves and items (each one's Sound, Travel Sound and Impact Sound)

Launch is as the move leaves its user, travel while it flies, impact where it lands. Stand-ins go by kind (a shot, a spell, a throw)
and by element.

### `data/items`

| Move | Launch | Travel | Impact |
| --- | --- | --- | --- |
| Archive Ledger | stand-in | stand-in | stand-in |
| Big Bomb | yours | stand-in | stand-in |
| Blank Requisition | stand-in | stand-in | stand-in |
| Blight Spellbook | stand-in | stand-in | stand-in |
| Blinding Bomb | stand-in | stand-in | stand-in |
| Burn Bottle | stand-in | stand-in | yours |
| Burner Spellbook | stand-in | stand-in | stand-in |
| Cling Spellbook | stand-in | stand-in | stand-in |
| Company Unseen Spellbook | stand-in | stand-in | stand-in |
| Crystal Bottle | yours | stand-in | stand-in |
| Crystalise Spellbook | stand-in | stand-in | stand-in |
| Cure Potion | stand-in | stand-in | stand-in |
| Dancing Lights Spellbook | stand-in | stand-in | stand-in |
| Dispel Magic Spellbook | stand-in | stand-in | stand-in |
| Emetic Powder | stand-in | stand-in | stand-in |
| False Life Spellbook | stand-in | stand-in | stand-in |
| Fever Dart | stand-in | stand-in | stand-in |
| Fever Tincture | stand-in | stand-in | stand-in |
| Flame Edge Spellbook | stand-in | stand-in | stand-in |
| Flame Fan Spellbook | stand-in | stand-in | stand-in |
| Flare Spellbook | stand-in | stand-in | stand-in |
| Forged Letter | stand-in | stand-in | stand-in |
| Frost Bottle | stand-in | stand-in | yours |
| Frost Edge Spellbook | stand-in | stand-in | stand-in |
| Gale Bottle | stand-in | stand-in | yours |
| Gnostic Tempest Spellbook | stand-in | stand-in | stand-in |
| Grease Spellbook | stand-in | stand-in | stand-in |
| Great Snare Spellbook | stand-in | stand-in | stand-in |
| Growth Spellbook | stand-in | stand-in | stand-in |
| Gust Blast Spellbook | stand-in | stand-in | stand-in |
| Hermes Step Spellbook | stand-in | stand-in | stand-in |
| Hover Spellbook | stand-in | stand-in | stand-in |
| Illusory Dragon Spellbook | stand-in | stand-in | stand-in |
| Ink Bottle | stand-in | stand-in | stand-in |
| InstaHack Spellbook | stand-in | stand-in | stand-in |
| Invisibility Spellbook | stand-in | stand-in | stand-in |
| Ire of Sophia Spellbook | stand-in | stand-in | stand-in |
| Kindled Hound Spellbook | stand-in | stand-in | stand-in |
| Knockout Drops | stand-in | stand-in | stand-in |
| Lantern | stand-in | stand-in | stand-in |
| Light Void Spellbook | stand-in | stand-in | stand-in |
| Magnifying Glass | stand-in | stand-in | stand-in |
| Medicine | stand-in | stand-in | stand-in |
| Mediocre Cure Potion | stand-in | stand-in | stand-in |
| Medium Bomb | yours | stand-in | stand-in |
| Mesmerise Spellbook | stand-in | stand-in | stand-in |
| Mist Step Spellbook | stand-in | stand-in | stand-in |
| Pebble | stand-in | stand-in | stand-in |
| Poison Bottle | stand-in | stand-in | stand-in |
| Potent Cure Potion | stand-in | stand-in | stand-in |
| Priest Robes | stand-in | stand-in | stand-in |
| Ravenous Dark Spellbook | stand-in | stand-in | stand-in |
| Retching Dart | stand-in | stand-in | stand-in |
| Seal of Office | stand-in | stand-in | stand-in |
| Sealed Requisition | stand-in | stand-in | stand-in |
| Shock Bottle | stand-in | stand-in | stand-in |
| Shrink Spellbook | stand-in | stand-in | stand-in |
| Sleep Dart | stand-in | stand-in | stand-in |
| Sleeping Draught | stand-in | stand-in | stand-in |
| Small Bomb | yours | stand-in | stand-in |
| Smelling Salts | stand-in | stand-in | stand-in |
| Stolen Signet | stand-in | stand-in | stand-in |
| Stolen Sun Spellbook | stand-in | stand-in | stand-in |
| Stone Edge Spellbook | stand-in | stand-in | stand-in |
| Storm Cloud Spellbook | stand-in | stand-in | stand-in |
| Storm Edge Spellbook | stand-in | stand-in | stand-in |
| Tartarus Flame Spellbook | stand-in | stand-in | stand-in |
| Terror Bottle | stand-in | stand-in | stand-in |
| Tiny Bomb | yours | stand-in | stand-in |
| Transposition Spellbook | stand-in | stand-in | stand-in |
| Turn Aside Spellbook | stand-in | stand-in | stand-in |
| Wall of Stone Spellbook | stand-in | stand-in | stand-in |
| Wildfire Spellbook | stand-in | stand-in | stand-in |
| Wind Swoon Spellbook | stand-in | stand-in | stand-in |
| Wind Vacuum Spellbook | stand-in | stand-in | stand-in |
| Withering Touch Spellbook | stand-in | stand-in | stand-in |
| communion_gate_nade.tres | stand-in | stand-in | stand-in |
| crystalise_gate_nade.tres | stand-in | stand-in | stand-in |
| heal_gate_nade.tres | stand-in | stand-in | stand-in |
| wildfire_gate_nade.tres | stand-in | stand-in | stand-in |

### `data/skills/alithia`

| Move | Launch | Travel | Impact |
| --- | --- | --- | --- |
| Calling Out | stand-in | stand-in | stand-in |
| Intuition | stand-in | stand-in | stand-in |
| Persuade | stand-in | stand-in | stand-in |
| Sass Club | yours | stand-in | stand-in |
| Votive Flame | stand-in | stand-in | yours |
| Water Spike | stand-in | stand-in | yours |

### `data/skills/alithia/paths/battle_chaplain`

| Move | Launch | Travel | Impact |
| --- | --- | --- | --- |
| Censure | stand-in | stand-in | yours |
| Holy Spear | stand-in | stand-in | yours |
| Judgement Hammer | stand-in | stand-in | yours |

### `data/skills/alithia/paths/illusory_shepherd`

| Move | Launch | Travel | Impact |
| --- | --- | --- | --- |
| Fallen Friend | stand-in | stand-in | stand-in |
| False Ground | stand-in | stand-in | stand-in |
| Four Reflections | stand-in | stand-in | stand-in |
| Illusory Cover | stand-in | stand-in | stand-in |
| Mass Mirage | stand-in | stand-in | stand-in |
| Mislead | stand-in | stand-in | stand-in |
| Phantom Body | stand-in | stand-in | stand-in |
| Phantom Company | stand-in | stand-in | stand-in |
| Phantom Killer | stand-in | stand-in | stand-in |
| Phantom Noise | stand-in | stand-in | stand-in |
| Phantom Wall | stand-in | stand-in | stand-in |
| Reality's Reflection | stand-in | stand-in | stand-in |
| Sanctuary of Light | stand-in | stand-in | stand-in |
| Seeming | stand-in | stand-in | stand-in |
| Weird | stand-in | stand-in | stand-in |

### `data/skills/alithia/paths/inquisitor`

| Move | Launch | Travel | Impact |
| --- | --- | --- | --- |
| Accusation | stand-in | stand-in | yours |
| Recant | stand-in | stand-in | stand-in |

### `data/skills/alithia/spells`

| Move | Launch | Travel | Impact |
| --- | --- | --- | --- |
| Arcane Eye | stand-in | stand-in | stand-in |
| Beckoning Light | stand-in | stand-in | stand-in |
| Bewilder | stand-in | stand-in | stand-in |
| Calm | stand-in | stand-in | stand-in |
| Cleanse | stand-in | stand-in | stand-in |
| Clear Sight | stand-in | stand-in | stand-in |
| Communion | stand-in | stand-in | stand-in |
| Compel | stand-in | stand-in | stand-in |
| Composure | stand-in | stand-in | stand-in |
| Daylight | stand-in | stand-in | stand-in |
| Detect Magic | stand-in | stand-in | stand-in |
| Divine Verdict | stand-in | stand-in | yours |
| Dread Visage | stand-in | stand-in | stand-in |
| Ecstasy | stand-in | stand-in | stand-in |
| Elemental Ward | stand-in | stand-in | stand-in |
| Find Familiar | stand-in | stand-in | stand-in |
| Flash | stand-in | stand-in | stand-in |
| Frozen River | yours | stand-in | stand-in |
| Glacial Tide | yours | stand-in | stand-in |
| Grace | stand-in | stand-in | stand-in |
| Heal | stand-in | stand-in | stand-in |
| Holy Lance | stand-in | stand-in | yours |
| Holy Splash | stand-in | stand-in | yours |
| Judgment | stand-in | stand-in | yours |
| Light Heal | stand-in | stand-in | stand-in |
| Mesmerise | stand-in | stand-in | stand-in |
| Piercing Light | stand-in | stand-in | yours |
| Purification | stand-in | stand-in | stand-in |
| Restoration | stand-in | stand-in | stand-in |
| Restorative Aura | stand-in | stand-in | stand-in |
| Resuscitate | stand-in | stand-in | stand-in |
| Revelation | stand-in | stand-in | yours |
| River Flow | stand-in | stand-in | yours |
| Shared Burden | stand-in | stand-in | stand-in |
| Silence | stand-in | stand-in | stand-in |
| Sleep | stand-in | stand-in | stand-in |
| Steady Heart | stand-in | stand-in | stand-in |
| Suggestion | stand-in | stand-in | stand-in |
| Terror | stand-in | stand-in | stand-in |

### `data/skills/common`

| Move | Launch | Travel | Impact |
| --- | --- | --- | --- |
| Blink Strike | yours | stand-in | stand-in |
| Break Free | stand-in | stand-in | stand-in |
| Bribe | stand-in | stand-in | stand-in |
| Climb Down | stand-in | stand-in | stand-in |
| Command | stand-in | stand-in | stand-in |
| Fire Burst | stand-in | stand-in | yours |
| Loot | stand-in | stand-in | stand-in |
| Move Cloud | stand-in | stand-in | stand-in |
| Move Double | stand-in | stand-in | stand-in |
| Move Lights | stand-in | stand-in | stand-in |
| Put On Disguise | stand-in | stand-in | stand-in |
| Rummage | stand-in | stand-in | stand-in |
| Run | stand-in | stand-in | stand-in |
| Slip Past | stand-in | stand-in | stand-in |
| Study | yours | stand-in | stand-in |
| Use | stand-in | stand-in | stand-in |

### `data/skills/cyrus`

| Move | Launch | Travel | Impact |
| --- | --- | --- | --- |
| Burning Shot | yours | stand-in | stand-in |
| Catalyst | stand-in | stand-in | stand-in |
| Deceive | stand-in | stand-in | stand-in |
| Gun | yours | stand-in | stand-in |
| Poison Dart | yours | stand-in | stand-in |
| Rapier | yours | stand-in | stand-in |
| Shadow Step | stand-in | stand-in | stand-in |
| Steal | stand-in | stand-in | stand-in |
| Stealth | stand-in | stand-in | stand-in |
| Venom Fan | yours | stand-in | stand-in |
| Warning Shot | yours | stand-in | stand-in |

### `data/skills/cyrus/paths/saboteur`

| Move | Launch | Travel | Impact |
| --- | --- | --- | --- |
| Combined Load | yours | stand-in | stand-in |
| Corrosive Round | yours | stand-in | stand-in |
| Frost Round | yours | stand-in | yours |

### `data/skills/cyrus/paths/trapper`

| Move | Launch | Travel | Impact |
| --- | --- | --- | --- |
| Minefield | stand-in | stand-in | stand-in |
| Snare | stand-in | stand-in | stand-in |
| Tripwire | stand-in | stand-in | stand-in |

### `data/skills/enemies`

| Move | Launch | Travel | Impact |
| --- | --- | --- | --- |
| Acid Breath | stand-in | stand-in | stand-in |
| Call the Bound | stand-in | stand-in | stand-in |
| Catch the Scent | stand-in | stand-in | stand-in |
| Devour | yours | stand-in | stand-in |
| Dread Breath | stand-in | stand-in | stand-in |
| Empower the Bound | stand-in | stand-in | stand-in |
| Fire Breath | stand-in | stand-in | yours |
| Flammable Limb | stand-in | stand-in | yours |
| Frost Breath | yours | stand-in | stand-in |
| Ground Pound | stand-in | stand-in | yours |
| Kindled Bite | stand-in | stand-in | yours |
| Lightning Breath | stand-in | stand-in | yours |
| Mend the Bound | stand-in | stand-in | stand-in |
| Nail Projectile | yours | stand-in | stand-in |
| Ravenous Bite | yours | stand-in | stand-in |
| Rending Claws | yours | stand-in | stand-in |
| Rib Maws | yours | stand-in | stand-in |
| Rockfall | stand-in | stand-in | yours |
| Savage Bite | yours | stand-in | stand-in |
| Self Destruct | yours | stand-in | stand-in |
| Venom Breath | stand-in | stand-in | stand-in |
| Venomous Shot | yours | stand-in | stand-in |

### `data/skills/enfina`

| Move | Launch | Travel | Impact |
| --- | --- | --- | --- |
| Arrest | stand-in | stand-in | stand-in |
| Battle Cry | yours | stand-in | stand-in |
| Blazed Path | stand-in | stand-in | stand-in |
| Cauterise | stand-in | stand-in | stand-in |
| Climb | stand-in | stand-in | stand-in |
| Disarm | yours | stand-in | stand-in |
| Flashover | stand-in | stand-in | stand-in |
| Follow Up Attack | yours | stand-in | stand-in |
| Grab | stand-in | stand-in | stand-in |
| Greatsword Attack | yours | stand-in | stand-in |
| Guard | stand-in | stand-in | stand-in |
| Hurl | yours | stand-in | stand-in |
| Intimidate | stand-in | stand-in | stand-in |
| Light Swing | yours | stand-in | stand-in |
| Riposte | stand-in | stand-in | stand-in |
| Share the Fire | stand-in | stand-in | stand-in |
| Shoving Strike | yours | stand-in | stand-in |
| Step In | stand-in | stand-in | stand-in |
| Stunning Blow | yours | stand-in | stand-in |
| Sweep Strike | yours | stand-in | stand-in |
| Trailblaze | stand-in | stand-in | yours |

### `data/skills/enfina/paths/juggernaut`

| Move | Launch | Travel | Impact |
| --- | --- | --- | --- |
| Chain Hook | yours | stand-in | stand-in |
| Hamstring | yours | stand-in | stand-in |
| Pin Down | yours | stand-in | stand-in |

### `data/skills/enfina/paths/vanguard`

| Move | Launch | Travel | Impact |
| --- | --- | --- | --- |
| Daunting Roar | yours | stand-in | stand-in |

### `data/skills/enfina/paths/warden_of_cover`

| Move | Launch | Travel | Impact |
| --- | --- | --- | --- |
| Shield Bash | yours | stand-in | stand-in |

### `data/skills/prometheus`

| Move | Launch | Travel | Impact |
| --- | --- | --- | --- |
| Caucasus Shard | yours | stand-in | stand-in |
| Hack | stand-in | stand-in | stand-in |
| Zephyr Dart | stand-in | stand-in | yours |

### `data/skills/prometheus/paths/elemental_conductor`

| Move | Launch | Travel | Impact |
| --- | --- | --- | --- |
| Storm Cloud | stand-in | stand-in | yours |

### `data/skills/prometheus/paths/elemental_tactician`

| Move | Launch | Travel | Impact |
| --- | --- | --- | --- |
| Grand Design | stand-in | stand-in | stand-in |

### `data/skills/prometheus/paths/elemental_vanguard`

| Move | Launch | Travel | Impact |
| --- | --- | --- | --- |
| Flame Edge | stand-in | stand-in | yours |
| Flame Fan | stand-in | stand-in | yours |
| Frost Edge | yours | stand-in | stand-in |
| Stone Edge | stand-in | stand-in | yours |
| Storm Edge | stand-in | stand-in | yours |

### `data/skills/prometheus/spells`

| Move | Launch | Travel | Impact |
| --- | --- | --- | --- |
| Blight | stand-in | stand-in | stand-in |
| Burner | stand-in | stand-in | yours |
| Cling | stand-in | stand-in | stand-in |
| Company Unseen | stand-in | stand-in | stand-in |
| Crystalise | yours | stand-in | stand-in |
| Dancing Lights | stand-in | stand-in | stand-in |
| Dispel Magic | stand-in | stand-in | stand-in |
| False Life | stand-in | stand-in | stand-in |
| Fire Blast | stand-in | stand-in | yours |
| Flare | stand-in | stand-in | stand-in |
| Gnostic Tempest | stand-in | stand-in | yours |
| Grease | stand-in | stand-in | stand-in |
| Great Snare | stand-in | stand-in | stand-in |
| Growth | yours | stand-in | stand-in |
| Gust Blast | stand-in | stand-in | yours |
| Hermes Step | yours | stand-in | stand-in |
| Hover | yours | stand-in | stand-in |
| Illusory Dragon | stand-in | stand-in | stand-in |
| InstaHack | yours | stand-in | stand-in |
| Invisibility | stand-in | stand-in | stand-in |
| Ire of Sophia | stand-in | stand-in | yours |
| Kindled Hound | stand-in | stand-in | stand-in |
| Light Void | stand-in | stand-in | stand-in |
| Mist Step | yours | stand-in | stand-in |
| Quicken | stand-in | stand-in | stand-in |
| Ravenous Dark | stand-in | stand-in | stand-in |
| Rock Throw | yours | stand-in | stand-in |
| Shrink | stand-in | stand-in | stand-in |
| Stolen Sun | stand-in | stand-in | yours |
| Tartarus Flame | stand-in | stand-in | yours |
| Transposition | stand-in | stand-in | stand-in |
| Turn Aside | stand-in | stand-in | stand-in |
| Wall of Stone | stand-in | stand-in | stand-in |
| Wildfire | stand-in | stand-in | yours |
| Wind Shot | stand-in | stand-in | yours |
| Wind Swoon | stand-in | stand-in | yours |
| Wind Vacuum | stand-in | stand-in | yours |
| Withering Touch | stand-in | stand-in | stand-in |

### `data/skills/unused`

| Move | Launch | Travel | Impact |
| --- | --- | --- | --- |
| Element Up | stand-in | stand-in | stand-in |
| Lightning Bolt | stand-in | stand-in | yours |
| Mirror Image | stand-in | stand-in | stand-in |
| Revitalizer | stand-in | stand-in | stand-in |

