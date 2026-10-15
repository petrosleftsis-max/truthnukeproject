# Messengers of Truth

A grid tactical RPG in Godot 4.7.2. `project.godot` sits at the repo root, so
every folder here is inside the Godot project - including `tests/`, which
carries a `.gdignore` to keep the editor from parsing 117 test drivers on every
start and shipping them in builds.

The game starts at `scenes/game.tscn` and the menu at `scenes/main_menu.tscn`.
Images are in `art/`, content resources (characters, enemies, skills, items,
conditions, passives, encounters, clues) in `data/`, maps and stealth stages in
`maps/`, try-it scenes in `demos/`; the README's "Where things are" has the
rest.

The databases are folders: `SkillDatabase`, `ItemDatabase` and
`CombatantDatabase` are scripts (`data/databases/`) that read `data/skills/`,
`data/items/`, `data/characters/` and `data/enemies/` through `DataFolder` when
the game starts, keyed by file name. There is no dictionary to register in -
the file name is the key, and saving the file adds it. Editor tools that cannot
rely on autoloads (`SpawnMarker`) call `DataFolder` directly. Every game class
a designer places or saves has an editor icon (`@icon`, `art/editor_icons/`);
give a new one an icon too. Folder colours in the FileSystem dock are
`[file_customization]` in `project.godot`. Folders and files are snake_case with no spaces - keep it that way, since
a path is written into every scene and resource that uses it. Moving anything
is a job for the editor's FileSystem dock, which rewrites those paths; moved by
hand, every reference has to be rewritten too (`.import` files included) and
the editor kept closed while it is done.

## Running the tests

```bash
tests/run.sh                 # every suite
tests/run.sh dot flags       # just those
tests/run.sh --list          # what there is
```

A full run is 117 suites and takes a while. Each one boots the real game
headless, plays something out and writes a result file; the runner prints one
line per suite and exits non-zero if any of them is unhappy. `tests/README.md`
has the details, including how to add one.

Godot is found by `tools/find_godot.sh`, which every script that runs it
shares: `$GODOT` if set, then `godot` on PATH, then the places it has been
unpacked on the machines this is worked on - `E:\Godot\` on one, and
`C:\Users\ortin\Downloads\Godot_v4.7.2-stable_win64.exe\` on the other, where
that `.exe` on the end is a **folder**, not the executable. A new machine is a
line in that file. On Windows use the **`_console`** build - the plain `.exe`
writes nothing to a terminal, so a headless run looks like it did nothing.

## What Godot will do to your .tres files

Four things, all of which have cost real time here.

**A property equal to its export default is not written at all.** So a missing
line in a `.tres` means "whatever the script says the default is", and the day
you change that default, every resource that never set it changes with it.
Giving a new `@export` a non-zero default silently rewrites the meaning of
every file already on disk.

**A property the script no longer declares is dropped without a word.** Rename
an `@export` and every `.tres` still writing the old name loses that value on
load - no error, no warning, just the default. This shipped: `flat_power`
became `item_power`, fifteen item files kept writing `flat_power`, and every
item in the game silently loaded at power 20. Four tiers of bomb, all
identical, and the whole suite stayed green because nothing asserted they
differed from each other. The `sanity` suite now reads each `.tres` as text and
compares what it writes against its script's `get_property_list()`, because
once the resource is loaded the evidence is gone.

**Enums are stored by number.** Insert a value in the middle of an enum and
every `.tres` holding a later one now means something else. Append at the end,
always.

**The editor caches scripts, and its cache wins.** Rename an exported property
while the project is open and the inspector still shows the old one; saving any
resource from there writes the old name back over yours. That is how the
`flat_power` files got re-broken after being fixed. Reopen the project after a
rename of that kind.

## Writing files into this project

**Never write a project file as UTF-8 with a BOM.** PowerShell 5.1's
`Out-File -Encoding utf8` adds one. Godot's editor then refuses the file while
headless runs keep passing, so the tests say everything is fine and the editor
says the project is broken.

**Backslash line-continuations in GDScript do not survive a bash heredoc.** A
wrapped line written that way arrives mangled and still compiles, which is the
worst of both - it runs, and it does not mean what you wrote. Write such files
with a real file-writing tool, or keep the line unwrapped.

**Never name an unimported file from `ui/blue_theme.tres`.** Godot loads the
project theme before it imports anything, so on a fresh clone a theme naming
the fonts failed to load, and importing them then crashed the editor outright.
That is why the typefaces go onto the theme at runtime instead - `GameFonts.apply()`
(`ui/game_fonts.gd`), called by the SceneTransition autoload. A heading takes
`theme_type_variation = GameFonts.HEADER` to be set in Cinzel; everything else
is Alegreya Sans.

## How a number becomes damage

Everything routes through `power_behind(attacker, skill)` in `combat/Combat.gd`:

- a **skill's** base is `WEAPON_BASE + 0.7 x scaling_stat` (6 and
  `STAT_SCALING` in `combat/Stats.gd`), so it moves with whoever is holding it
- an **item's** base is the flat `item_power` written on it, and does not move
  at all - a bomb is the same bomb whoever throws it

From there `Stats.final_damage` is `base x ability_modifier x 40/(40+defence)`,
rounded, never below 1. Defence gives diminishing returns and can never soak a
hit to nothing.

**Conditions tick differently on purpose.** `dot_base_damage` is
`power_behind x the condition's own dial`, deliberately *without*
`ability_modifier` - that modifier sizes the hit that lands, not the burn that
follows. **Heals** are `power_behind x the heal dial`, with no defence and no
randomness, so a heal is something you can count on when deciding whether it is
enough.

`ItemDefinition extends SkillDefinition`, so items walk the same path; they
just answer `power_behind` with their own number. A contested item weighs the
target's `contest_stat` against `item_power` rather than against a thrower's
attribute.

## How the enemy AI chooses

The archetypes (`ai_melee_rush`, `ai_ranger`, `ai_caster`, ... in
`combat/Combat.gd`) weigh their options with `predict_hit` - the same
arithmetic as the damage prompt a player sees while aiming - rather than
counting targets. `ai_plan_attack` tries every usable skill from every tile in
reach and scores it: damage after defence and resistance times the chance to
hit, plus a bonus for a kill, for a condition not already on the target, for a
target already hurt and for the one the last enemy went for
(`_ai_focus_id`). Its own side caught by a both-sides blast is a heavy cost and
itself caught is ruled out. The `AI_*` constants beside it are the dials.

It only scores aim points near somebody worth hitting, and each aim once per
skill rather than once per standing tile - the caster once took eleven seconds
a turn, and `castcost` times the planner to keep it under one. `archetypes`
asserts what each enemy does with a turn; change a dial and run it.

The danger view (hold Shift) asks `Combat.threat_map()` the same question
from the player's side: every tile an enemy could reach and hit next turn.
A skill that respects blocking needs a clear line there too, from anywhere
the enemy could walk to - on this map three enemies reach twenty tiles, and
ignoring walls painted it all red. That is tens of thousands of sight lines, so
they are read off `_SightGrid`, a flat copy of the blocking; `danger` checks
it agrees with `has_line_of_sight` line for line. Change the sight rule in one
and the other has to follow.

## Stealth maps

An exploration map with a `StealthSetup` in it is watched in real time by its
`Guard` nodes (`exploration/StealthWatch.gd`). A guard sees by
`StealthSight`, a copy of combat's line-of-sight walk over the same "Blocks"
tile data, see-through tiles included - bodies are not cover out there. It is
a third copy of that walk, after `Combat._walk_is_clear` and `_SightGrid`;
`sneak` checks it agrees with `has_line_of_sight` on 3000 lines. Change the
rule in one and the others have to follow.

Caught, the fight is an `EncounterDefinition` built on the spot: the guards and
the party on the tiles they stood on, `fighters` naming who fights and
`skip_deployment` stopping anyone being rearranged. Won, `Campaign` clears the
map's trigger and the guards are not there on return. Disguises are
`ItemDefinition`s with `disguise_as` set, things to throw have
`distraction_radius` set, poisons `poison`, and keepsakes (a letter, a ledger)
`keepsake`; `Campaign.combat_items_of` leaves all of them out of fights
(`ItemDefinition.stealth_only`). Each guard's spawn carries what is left in his
pockets as `starting_items`, which an enemy uses (`Combat.items_of` reads
`comb.pocket` for side 1): a bomb joins the AI's plans, a potion is drunk when
badly hurt. An ambush (F) marks the unaware as `surprised`, which Combat turns
into the Caught Off Guard condition - `start_first_turn` skips a first
combatant who has it, since nothing else would.

Guards far from where he was caught can join late: `build_fight` gives their
spawn an `arrives_on_round`, and `Combat` holds any enemy spawn with one above
1 back until the top of that round (`_bring_in_arrivals`, on the round wrap in
`set_next_combatant`). Any encounter can use it, not just stealth fights.

`ExplorationParty` has two ways to stop the party: `frozen` makes
`ExplorationScene.is_holding()` true, which stops the guards too (a
conversation, a menu, a catch); `rooted` stops only the party (putting a
disguise on), so the world carries on. `pace` slows its walking (dragging a
body). Use the wrong one and a disguise change becomes a free pause.

The stages are on the title screen (`MainMenu.STEALTH_STAGES`). Their
`StealthGoal`s have `ends_at_menu` set, which sends the player back with
`Campaign.to_main_menu(MainMenu.STEALTH_PANEL, note)` - the menu opens at that
panel, shows the note once, and clears both.

A guard's time off his beat is an **errand** (`Guard.send_on_errand`): chat,
eat, retch, be sick, tend somebody, run to report, wake a body. The watch sends
them and says what happens on arrival and when it is done; the guard walks
there, stays, and goes back to his beat. Moods in `Guard.ABSORBED` (retching,
sick, asleep, reporting) are not drawn off by what they see or hear; anything
else drops the errand for whatever caught their eye. Add a new errand mood to
`ERRANDS` and to the match in `Guard._process`, at the end of the enum.

Doors and lamps change what a guard sees, so `_world_version` is in every
guard's `_seen_key`: bump it (`_relight` does) whenever one changes, or guards
keep seeing through a shut door. A shut door is in `StealthSight`'s and
`ExplorationScene`'s `_shut` tiles but not in the static `_blocking` - Actors'
routes are built once and still run through it, which is how guards have the
keys. Things out of place (a door left open, a lamp out, something gone, a
stuffed hiding spot) are `_oddities`; a guard who notices one investigates, and
`_see_to_oddities` puts it right when he gets there.

The alert never fades. `alert_floor` is where a found body pinned it;
`lower_alert_level` will not go below it - whether by a word (E beside a guard
a disguise fools), a conversation (`do Campaign.settle_alert()`) or an
Interactable with Settles Alert ticked.

`stealthkit` covers the tools (throwing, ears, hiding spots, takedowns,
pockets, alert, dogs, wards, captains, questions, the ghost flag, late
arrivals) on the crossroads map; `alarm`, `ambush`, `stealthworld`,
`guardlife`, `poisons` and `stagecard` the rest; `stages` checks the seven built
test stages are playable. The stages are generated by `tools/build_stealth_stages.gd`,
which has to run as a scene (`--script` does not load the autoloads its nodes
lean on); rebuild them from a copy of the project and copy `maps/stealth_stages/*.tscn`
back, or run it in place and accept that `maps/stealth_stages/` is overwritten.

## Keys and controllers

Every key the game answers is an action in `project.godot`'s `[input]`, with
its pad button beside it - read actions, never raw keycodes, or the pad cannot
press it and Project Settings cannot rebind it. A new key is a new action with
both bound. Number keys 1-9 (skills, disguises) are the one exception. Any text
naming a key asks `Pad.key(action)` or `Pad.hint(text, action)`, which name the
keyboard's or the pad's by whichever was used last, and refreshes on
`Pad.changed`. A trigger repeats "pressed" while held, so a press bound to one
is read with `Pad.went_down(event, action)`.

`Pad` (autoload, `control/Pad.gd`) is the pad's pointer, and the pointer is the
mouse: it moves the real cursor and sends mouse events through
`Input.parse_input_event`, in **window** pixels (`root.get_final_transform()`
times the game's), so hover, clicks and drags all work unchanged. Which stick
drives it and what A does depend on `Pad.mode()`, read from groups: `pad_board`
(CController, which keeps a cursor tile the pointer is put on - `pad_tiles()` is
what it may step between; `map_view_rect()` on the HUD is where it is kept),
`pad_walk` (ExplorationScene), `pad_pointer` (StealthWatch while aiming) and
`pad_menu` (journal, inventory, character sheet - View and LB/RB go round
them). A windowed test or screenshot driver must set `Pad.warps = false`,
or it moves the mouse of whoever is at the computer. `pad` plays it all.

## Dungeons

A `DungeonDefinition` (`campaign/`, the demo in `data/dungeons/`) is fights in a
row. While one is on (`Campaign.in_dungeon()`): `begin_battle_from_exploration`
swaps the map's own fight for the stage's (`DungeonDefinition.stage_for`);
`ExplorationScene` leaves the party and bags alone instead of applying the map's
MapSetup cast and kit; `Combat._deploy_party` keeps the bags even on a fight
gone straight into; and `record_party` / `apply_carried_state` carry spent
`spell_slots` between fights, which no other mode does. `ResultUI` shows a
`RestPanel` (`Campaign.rest_party`, `recover_gates`) instead of its own panel
after every won fight but the last. `reset()` ends a dungeon, so the title
screen and every fresh start leave it. `dungeon` covers it.

## Point-and-click pictures

`Pictures` (autoload, `exploration/Pictures.gd`) shows `Picture` scenes over
whatever is running and resolves their `Hotspot`s. Where it sits in the
autoload list does not matter: `tests/run.sh` puts each test driver after
whichever autoload is last. It is a Dialogue Manager
state shortcut too, so `do Pictures.open(...)` works in a conversation and
holds it until the pictures close. Its layer (25) sits just under the dialogue
balloon's (30), so a hotspot's conversation plays over the picture. Escape is
taken in `_input`, not `_unhandled_input` - the pause menu lives in the scene
and would hear it first.

`Journal` (autoload, `ui/journal.gd`, also a dialogue state shortcut) is the
clue journal, on layer 40 - over the balloon, because `do Journal.present(...)`
opens it from inside a conversation and holds it until something is shown. It
pauses the tree while open and will not open over a tree something else
paused. Clues are `ClueDefinition`s read from `res://data/clues/` by `ClueBook`
(file name = key; `ClueBook.add` for clues built in code). What the party knows
is stored as flags - `clue:<key>` holding the order learned, and `seen:<picture
id>::<node path>` for every hotspot clicked - so both ride along with flags
through fights, Restart Stage's snapshot and `Campaign.reset()`.

How the pictures sound, what the cursor sign shows and how long things animate
is `res://pictures/feedback.tres` (`PictureFeedback`); an empty sound slot is
filled by `PlaceholderSounds`, generated on the spot. A PictureLayer that goes
is hidden at once and a duplicate left behind does the fading, so nothing has
to wait on an animation - tests read visibility straight after a click. A
hidden-detail layer draws through a lens shader that reads `MODEL_MATRIX`, so
its children (`use_parent_material`) share the lens's canvas coordinates.
`Pictures.lens_point` stands in for the mouse in tests. `clues` covers all of
it with the demo in `pictures/clues_*.tscn`.

## Shape of the data

A combatant is a plain `Dictionary`, not a class. The five attributes -
Physical, Mindfulness, Intellect, Self, Defense - live under `comb["stats"]`,
while `hp`, `max_hp`, `movement`, `initiative`, `level` and `weapon_base` sit at
the top level. Read an attribute with `stat_of()` and never straight out of the
dictionary: `stat_of` folds active buffs in, and reading raw means nothing can
ever buff or weaken anybody.

Content is data-driven `.tres` throughout - `SkillDefinition`,
`ItemDefinition`, `EffectDefinition`, `ConditionDefinition`,
`PassiveDefinition`, `CombatantDefinition`, `EncounterDefinition`,
`SpawnDefinition`, `MapSetup`.

**A player spawn is its character's.** `Combat.party_tiles_for` puts each
fighter on the spawn naming them, with its level, weapon and defence; only
fighters without one take whatever spawns are left. (It once went by marching
order alone, and the lab fight handed everybody somebody else's defence.)

**The fallen stay in `combatants`**, `alive = false`, on the tile they fell on,
which is freed. A Resuscitate (`targets_fallen`, `EffectType.REVIVE`) is aimed
through `CController.aim_subject_at` and stands them back up with
`Combat.revive`. Its weakening is `comb.frailty`, applied by
`Combat.apply_frailty` from the untouched figures kept in `comb.unweakened`
(everything but movement), and carried in `Campaign.party_state` like health.

**What somebody has to hand is `Combat.items_of`**: an enemy's `comb.pocket`
(from their spawn's `starting_items`), or the front `Campaign.COMBAT_SLOTS` of a
party member's bag. A Steal (`EffectType.STEAL`, `Combat.steal`) moves from one
to the other through `_stow` / `_give_up`, so it works either way round. For the
party it goes through `Campaign.stow_item`, which is `give_item` with no log line.
`SpawnDefinition` is `@tool` only so that `starting_items` can be a dropdown.

**A new `SpawnDefinition` field needs a home on `SpawnMarker`.** The encounter
editor's Save rebuilds every spawn from its marker (`_spawn_from`), so a field
that `rebuild()` and `_spawn_from` don't both carry goes back to its default on
every Save. This happened to Arrives On Round and Surprised. The `gear` suite
sets every stored field and fails on any it doesn't know about.

**Twenty levels, and the story's own.** `Stats.MAX_LEVEL` is 20; attributes and
health climb linearly between level 1 and 20 (`Stats.main_stat_at`,
`CombatantDefinition.hp_at`), gates by `Stats.GATES_BY_LEVEL`. A fight walked into
from a map (or a dungeon) fields the party at `Campaign.party_level`, on their
chosen path and in their gear (`create_combatant`'s `level`/`subclass` arguments,
`Combat.wear_gear`); one opened from Arena Mode uses the spawn's level,
subclass, weapon and defence. `Campaign.set_party`'s level is a floor and raises
through `reach_level`, never lowers.

**Paths are passives, mostly.** `SubclassDefinition` (data/subclasses) gives
skills and passives; `Combat.take_path` adds them from level 5. What a path does
is a switch on `PassiveDefinition`, read in "What the paths do" in Combat.gd
through `active_passives` (which honours each passive's `required_level`).
Damage goes through `damage_dealt_multiplier` (factions, empowered, amplified),
so the aim prompt and the hit agree. Every health loss goes through `lose_hp`,
which spends overheal (`temp_hp`) first. Images are combatants with
`illusion = true`: no turns, shatter on any hit (`_shatter`), never counted by
`side_standing`, never "fallen". `confuses` on a condition hands the turn to
`ai_confused`, either side.

**The map asks for paths** (`ExplorationScene._offer_paths`) unless
`Campaign.asks_for_paths` is off - the harness turns it off in its copy
(`game/asks_for_paths=false`), and the `progression` suite turns it back on.

**Everything a run keeps is in a save.** `Campaign.SAVED` lists what
`Campaign.snapshot` copies; the `saves` suite fails on a Campaign variable that is
in neither it nor its own NOT_SAVED list. Saves are `var_to_str` text in
`user://saves/`; the harness wipes its own saves folder before every suite, since
every fight begun from a map writes an autosave.

**Passives are not skills.** A `PassiveDefinition` sits in a combatant's
`passives` list, never in `skill_list`, so nothing that walks skills - the
panels, reactions, the AI's hunt for something to use - can ever offer one.
Ask what it grants through `Combat.active_passives(comb)` rather than reading
the list directly: that is where a passive waiting on its condition is left
out. The same goes for what Cyrus's Light Footed and Quick Hands grant - ask
`secondary_grants` and `items_as_secondary`, which also read the older
per-character fields of the same names that nothing uses any more.

**Gates are not fixed at three.** Names, colours and counts all extend: add a
name to `Stats.GATE_NAMES` (and a colour to `GATE_COLOURS`, or one is picked)
and a column to `GATES_BY_LEVEL`. The Spells panel is a shelf per gate that
scrolls within the action panel's size (`ui/spell_shelves.gd`), so more gates
never make it bigger. Skills use the twelve-button grid, until a tab has more
than twelve; then they go on one untagged shelf (`build(..., flat)`), since the
grid would drop the rest without a word. `paths` checks every kit at level 20.

**Sizes: a combatant is a rectangle, not a tile.** `comb.size` (`Sizes.Size`) and
`comb.span` (tiles a side, 1 for Human and smaller). `comb.position` is the
top-left anchor. Ask `Combat.tiles_of`, `covers`, `combatants_at`,
`nearest_tile_of`, `distance_to` and `rect_gap` rather than comparing positions:
`get_combatant_at` finds a big one from any of its tiles. Whether somebody fits
anywhere is `room_for` - the ground, the bounds, and others, with Tiny and Small
sharing a tile with their own side in shares of 16 (`Sizes.SHARE`).
`can_land_on`, the spawner, late arrivals and knockback all ask it.

`Combat.terrain_class(comb)` is the movement class a combatant's ground and sight
answer to: their own, or 1 (flier) for Monstrous and up. Pass it, not
`comb.movement_class`, wherever terrain is asked about for a mover or a viewer.
Sight takes a `viewer_size` too: `_SightGrid` stores each body's size + 1, and a
body blocks a viewer not at least two sizes bigger. Both sight walks have to
agree, as before.

The controller keeps its occupancy as every tile of everybody, rebuilt by
`refresh_occupancy` (call `reposition_combatant` *after* changing
`comb.position`). The pathfinder plans for the anchor: a big mover's grid
(`_fit_points_to_big`, a summed-area table) is solid wherever its square would
not fit; `get_reachable_tiles(..., mover)` does the same for the reach. The
sprite node stays on the anchor tile's centre; `CombatantSprite.size_offset`
draws it over its square (or in its corner of a shared tile) and
`Sizes.draw_scale` scales it. Anything that moves a sprite back "home" returns
it to `size_offset`, not zero.

**Declared moves keep their marks.** `SkillDefinition.declared`: `use_skill` calls
`declare` instead of resolving, which stores `comb.declared` (skill, aim, tiles)
and spends nothing, along with `waiting`: the ids of every opponent that takes
turns. `_turn_begins_for` takes each combatant off every waiting list as their
turn begins (stunned turns included). `advance_turn` lands it at the start of
the user's first turn once that list is empty (`declared_due`, `land_declared`
→ `use_skill(..., landing = true)`), before the AI or the player gets the turn.
A test that hands somebody consecutive turns has to give the other side theirs
(`_turn_begins_for`) or nothing lands. A landing skips the range check and hits exactly the
marked tiles (`comb.landing_tiles`), so moving after declaring doesn't change
what lands. Stun or confusion drops it (`drop_declared`). The AI calls
`_ai_declare` before its archetype, and `_ai_main_keys` leaves declared skills
out of the archetypes. On a landing turn `ai_process` only moves and uses its
secondary. `declared` covers it.

**Bosses are combatants with `comb.boss`** (a `BossDefinition`), set up by
`create_combatant` with `phase`, `phase_name` and a stagger bar (`stagger_def`,
`stagger`, `stagger_max`). Every health loss goes through `lose_hp(target,
amount, element)` and so through `_after_hp_lost`. That function first begins
any phases (`_check_phases` → `_begin_phase`), and only fills the bar (Per
Damage, type-filtered) if no phase began: a phase starts its own bar empty.
`do_damage` adds Per Hit and From Skills (`_stagger_from_hit`). `shrug_off`
adds Per Blocked Condition. Everything filling a bar goes through
`add_stagger`, which applies While Readying and calls `stagger` when full.
Staggered is the `STAGGERED` condition put on directly, past any immunity,
stored for exactly Turns Lost turns. `damage_taken_multiplier` is folded into
`damage_dealt_multiplier`, so the aim prompt agrees. The HUD's `BossBars` and
`BossBanner` read the dictionary (`announce_boss`, `_refresh_boss_bars` on every
`update_combatants`); `bosses` covers it all.

**Immunities are checked where each thing is done**, not centrally:
- the CONDITION branch of `apply_effect`, and `put_condition` for auras,
  hazards and objects
- each other effect type's branch
- `apply_knockback`, `steal`, `dispel_status_effects` (via `should_dispel`'s
  `keeps_boons`), the TARGET teleport in `use_skill`, and `catch_off_guard`

A new way of doing something to somebody needs its own check against
`immune_to` / `immune_to_condition`.

**Things on the map (`comb.object`) are in `combatants` but in no `groups`
entry and no turn order.** So nothing that counts a side - winning,
watching, allies, `side_standing` - ever sees them, while targeting, occupancy
and sight (which walk `combatants`) do. `combatant_die` sets them off and
`_object_gone` removes them. A spawn of one is never a party tile, whatever its
side. `_offer_interact` gives the party the `use` skill.

**The turn order is `_base_queue` (everybody once, as it always was) spread into
`turn_queue`** by `_spread_turn_queue` for anybody with `turns_per_round` above
1. While nobody has more than one, `add_combatant` keeps the old append-and-sort,
so a test's hand-made `turn_queue` survives an image being added. A phase
changing turns sets `_turn_order_dirty`, applied at the top of the next round.
Adding somebody mid-turn goes through `add_mid_round`, which keeps `turn` on
whoever is acting. The HUD's queue has a face per slot (`queue_slot` meta;
`_queue_faces_for`); with several faces only the one at `combat.turn` is lit.
The queue is a vertical column on the right, sized down to `queue_floor()`
(above the log).

**The arena** is `_hazards_running` / `_hazard_marks` / `_bad_ground`, advanced
by `_arena_round_begins` at the top of every round (and once in
`start_first_turn`). It is driven by `round_number`, so a test can step it
directly. `hit_by_the_arena` is damage that is nobody's skill: through defence
and resistance, into `lose_hp` with its type.

**Gate Nades copy their spell at startup.** A `GateNadeDefinition` names a
spell by key. `ItemDatabase._ready` calls `take_on`, which copies every stored
SkillDefinition property onto the nade except what the nade has of its own
(name, description, icon, sound) and its item fields. It then zeroes the gate
and the level. The spell's own resource is kept as `cast`. A new SkillDefinition
property is copied automatically.

Who may throw one is `can_use_gate_nade`. It allows anybody whose spell list,
definition, or any of their character's paths has the spell
(`knows_or_can_learn`), or anybody with a passive's `any_gate_nade`. It is
enforced in three places: `wasted_on` (the HUD greys the nade out and says
why), `use_skill` (refused, nothing spent), and the AI (`_ai_plannable`,
`_ai_drink_from_pocket`). A passive's `gate_nades_as_secondary` joins Quick
Hands in `_consumable_spends_secondary`. `nades` covers it.

**Hacking is one autoload with three boards.** `Hacking` (`hacking/Hacking.gd`,
layer 35, above the balloon) is started with `run(hack, id, combat, hacker)`,
which you await. It returns `{"result": success / failed / walked_away /
locked / nobody / busy, "set_off", "locked_out"}`.
- It builds its own screen and plays a `RewriteBoard`, `InfiltrateBoard` or
  `ResonanceBoard`. Each board has `setup`, `reset_try`, `hint`, `simplify`,
  `first_focus` and the signals `solved` / `failed_try(reason)`.
- Tries, retry costs, the clock, gates and failure all live in `Hacking`, not
  in the boards.
- Outside a fight it pauses the tree, or with `world_keeps_moving` on a stealth
  map it only roots the party. It writes `hacked:` / `hack_locked:` /
  `hack_set_off:` + id to Campaign.
- In a fight (`Combat._hack_in_fight`) nothing is written; the combatant dict
  carries `hacked` / `hack_locked`.
- Gates spent outside a fight are `Campaign.gates_spent_outside`, taken off at
  the next deployment (`take_gates_spent_outside`). Strain outside a fight is
  `Campaign.strain`.
- `Interactable` and `Hotspot` are `@tool`, so Interactable reaches the
  autoload by path (`/root/Hacking`).
- Tests drive a board through `Hacking.board()`, having started `run` without
  awaiting it; `hacking` does all of it.

**Dealing with enemies, where the code is.** All of it is in `combat/Combat.gd`,
one section each, and every rule is a per-creature switch:

- **"Changing sides".** `switch_sides` moves a combatant between `groups` and
  marks them `turncoat` / `ai_controlled`.
  - `ai_plays(comb)` is "the AI plays this turn": side 1, or ai_controlled.
    Use it, not `side == 1`, anywhere a turn is ended or handed to the AI.
  - `plays_for_party` is the player's own.
  - `record_party` skips turncoats. They turn back when the real party is gone
    (`_turncoats_turn_back_if_alone`).
- **"Reading intent".** `comb.intent` is carried out by `_ai_follow_intent`
  before anything else in `ai_process`.
- **"Nerve".** `comb.taken` ("fled", "surrendered", "knocked_out", "bought")
  is out of the fight without dying: `alive = false`, off its group, never
  found by `fallen_at`. `prisoners()` are the surrendered and knocked out.
  - Every enemy who falls is knocked out (`_knocks_out`), unless immune to
    being taken alive or `killed_itself` (a kills_caster skill). So a test
    that kills an enemy gets `taken == "knocked_out"`, and the log says
    "knocked out", not "died".
  - "Getting away": a fled enemy's `when_fled` queues a return
    (`_returning`, plus SpawnDefinitions for its help on `_arriving`), or sets
    `lost_because`, which combat_finish and ResultUI read as a defeat.
  - Ways out: `Combat.escape_points`, copied from the encounter in `_ready`; a
    test can set it. With any, `_ai_flee` is `_run_for_a_way_out`; with none,
    nobody gets away (`_keep_away`). `fleeing` is only a marker now.
    `_escape_field` is a flood from the ways out (leaving out a way out somebody
    stands on). `EncounterDefinition.runners_with_nowhere_to_run` is what the
    editor and the fight warn with.
- **Grid after something big.** `_fit_points_to_big` closes open ground the
  rest of `update_points_weight` never revisits, so `_big_fitted` makes the next
  update open the whole region first. Anything else that closes open ground on
  the grid needs the same.
  - `combat_finish` writes `Campaign.last_fight` (`record_last_fight`) before
    `combat_finished`, for a Victory Dialogue to read. It is not saved.
  - A held enemy whose planned skill no longer reaches (grabbed mid-walk) is
    turned to `_ai_make_do` by `use_skill`, not left swinging at nothing.
- **Keys or stick.** Walking and panning read `Pad.direction`, never
  `Input.get_vector` with keys and stick added together. A pad's resting
  stick walked a keyboard party slowly downhill.
- **"Taunts" and `refusal_for`.** `refusal_for` is the one place a use is
  ruled out for who it is aimed at: taunted, too heavy, too small to climb, no
  leverage, can't be bought. `use_skill` and `CController.refusal_at` both ask
  it, so the preview and the use agree. A new rule of that kind goes there.
- **"Grappling".** A rider (`comb.riding`) covers no tiles:
  - `covers` is false, and `tiles_of` with no anchor is empty.
  - `_carry_riders` (from `place_sprites`) keeps them on their mount.
  - Hurl is `_hurl`, its own path through `use_skill`.
- **"Holding on"** (Grab). The hold is a condition with `holds` ticked,
  its `source_id` the holder (`hold_on`, `holder_of`, `held_by`).
  - Anything that moves somebody by force calls `_break_holds_on`: teleport,
    knockback, drift, Hurl, climbing on or off. A new one should too.
  - `check_holds` lets go of grips nobody is keeping. It runs after every step,
    at each turn start, and when somebody falls or is taken.
  - A reactive skill is offered beside any other reactive skill
    (`choose_reaction`, `ReactionPrompt.choose`).
  - A grab mid-walk is stopped in `CController._handle_step_arrival`.
- **Ignores Defense**: `defense_against`, read by `skill_damage`, the one place
  a hit meets Defense.
- **"Body parts".** `_aimed_tile` is the impact tile, set only around each
  target's effects in `use_skill`. `do_damage` → `_hit_part`.
- **"Quick time"**: `quick_time_power` / `quick_time_governs`. The QuickTime
  autoload (`quicktime/`, layer 36) answers false headless unless a test sets
  `answer` or `play_headless`.
- **"The enemy codex"**: `_write_codex` from `study`; the pages are
  `Campaign.codex_pages`, worked out by `ui/codex_page.gd`.

Study (the skill) opens the character sheet, which holds the game
(`MenuPause`). A blow that studies does not. A test that studies with the skill
and then opens another menu has to close the sheet first.

On stealth maps, `StealthWatch` has "Planted evidence" (`plant`,
`_check_framed`, `_marched_off`, kept in the snapshot as `framed_away`) and
"Talking in disguise" (`send_away`, `tell_patrol`, `hand_over`). Those act on
`_talking_to`, set only while a guard's small talk is on.

`enemies` and `sentries` cover all of it.

A condition's mark letters can be set (`ConditionDefinition.tag`) when its first
two letters are taken: Staggered is "Sg", since Stunned is "St". `hudextras`
fails on any clash.

## Releasing

```bash
tools/release.sh                 # build both and zip them
tools/release.sh --publish       # and push to itch, after asking
```

`export_presets.cfg` is git-ignored, so a fresh clone has to set its export
presets up before either that or `tests/run_packed.sh` will work. The scripts
ask for two by name - **Windows Desktop**, with the `.pck` beside the `.exe`
rather than embedded, and **Web**, single-threaded for itch - and exporting
needs the templates for exactly this Godot version, which are installed per
machine. The three `.wav` music tracks are ignored too -
126 MB, and `audio/Music.gd` warns and plays on in silence when one is missing,
so a clone without them runs fine and fights quietly.
