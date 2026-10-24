# Messengers of Truth

A grid tactical RPG in Godot 4.7.2. `project.godot` sits at the repo root, so
every folder here is inside the Godot project - including `tests/`, which
carries a `.gdignore` to keep the editor from parsing 127 test drivers on every
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
the file name is the key, and saving the file adds it. `DataFolder` reads
subfolders too, so skills are sorted by who uses them: `data/skills/common/`
(two or more of the party, and the secondary actions), `<character>/`,
`<character>/spells/`, `<character>/paths/<path>/`, `enemies/` and `unused/`.
The folder is for people only - a skill is still keyed by its file name, which
must be one of a kind across all of them (a second one is warned about and
dropped). Move a skill freely when who uses it changes; nothing refers to its
path except `tests/hover_test_driver.gd`. Editor tools that cannot
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

A full run is 130 suites and takes a while. Each one boots the real game
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
  `STAT_SCALING` in `combat/Stats.gd`), so it moves with whoever is holding it.
  Read the stat through `scaling_stat_of`: a passive's `scales_every_skill_with`
  first, then for a spell (`is_spell`, not an item) the caster's
  `spellcasting_stat` (CombatantDefinition) - a spell's own `scaling_stat` is
  ignored and hidden in the inspector - and otherwise the skill's own
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
enough - except a skill's heal on the **flat rule** (APPROVED_TRIAL 2026-10-24,
`EffectDefinition.heals_flat`: Heal Flat + Heal Per Stat x the healer's healing
stat + Heal Per Weapon x their weapon base). Light Heal, Heal, Communion,
Restoration and Mend the Bound use it; the healing stat is `scaling_stat_of`, so
Self for the Mimic. Items (Gate Nades copying Heal) keep their flat item power.
`heal_amount` works out both; the heal bonus (Mercy I) multiplies the whole
amount and never the share of health (`heal_share_on`). `docs/healing_revision.md`
has the numbers.

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
`spell_slots` between fights, which no other mode does - and what is spent until a
rest (`Combat.SPENT_UNTIL_REST`: a skill's `uses_per_short_rest` uses, free
amplifications, Conduit; per fight until the designer's change of 2026-10-24),
which `Campaign.short_rest` / `long_rest` clear. `rest_party`, the rest between
stages, is a short rest in a dungeon of `short_rests` (half of what was lost,
`SHORT_REST_MENDS`; no gates; the fallen stay down) and a full one otherwise
(which calls `short_rest` too). At a short rest somebody fallen can be brought
back with Resuscitate (`resuscitator`, `resuscitate_at_rest`: the spell's own
Revive Health and Weakening, a casting through Pandora or deeper). What else a
long rest does is the designer's to give. A dungeon's `kit` stocks the bags
`start_dungeon` empties. `ResultUI` shows a
`RestPanel` (`Campaign.rest_party`, `recover_gates`, the fallen) instead of its own panel
after every won fight but the last. `reset()` ends a dungeon, so the title
screen and every fresh start leave it. `dungeon` covers it, `restuses` the uses.

The late-Chapter-I laboratory sequence (`data/dungeons/lab_chapter1_sequence.tres`,
boss Erysichthon; `lab_chapter1_sequence_ash_warden.tres` the same with the Ash
Warden; `docs/lab_sequence.md`) is a TEMPORARY test harness, not story content. It
takes short rests and carries a kit (designer, 2026-10-25); `skips_rests`, which
made `ResultUI` skip the RestPanel, is used by nothing now. Its `logs_metrics` makes `GameScene` add a `LabMetrics`
(`tools/lab_metrics.gd`) under Combat. That listens to `Combat.metric` - emitted
by `_metric` from the round, turn, action, gate, damage (`lose_hp`, which takes
who did it and what was burning, so a tick is its source's and a reaction the
reactor's), heal, item,
declare / land / drop and stagger code, `cue`, `shrug_off`, break-free, swallowing
and digesting, and every condition put on; `add_stagger` takes a source label - and
writes `docs/lab_runs/`, with a section per boss (its turns lost and why, what was
put on it, what it shrugged off, what happened around it). Nothing in the game listens to `metric`. `lab` covers it;
the probe `chapter1` writes the inventory with its "Lethality review".
The probe `healing` writes `healing_inventory.csv` (every heal at 1 / 8 / 14 / 18 /
64, the designer's hybrid proposal beside it, the enemies' blows, the short rest,
the gates Meditate would bring back, and the heal cap's triggers level by level)
for `docs/healing_and_rest_proposal.md`, `docs/healing_cap_proposal.md` (an optional
tuning tool) and `docs/healing_revision.md` (the revised flat heals).

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
(from their spawn's `starting_items`), or a party member's belt (the Baldric). A Steal
(`EffectType.STEAL`, `Combat.steal`) empties one container the thief picks
(`steal_choices`, `_choose_container`, asked in `use_skill` before the effects and
held in `_steal_from`): a party member's belt, pouch or backpack, an enemy's
pocket or `carried`. It moves through `_stow` / `_give_up`, so it works either
way round; for the party through `Campaign.stow_item`, which is `give_item` with
no log line. `SpawnDefinition` is `@tool` only so that `starting_items` can be a
dropdown. A limited cleanse (`dispel_count`) and a heal's Heals Lift ask the same
way: `_choose_lifts`, in `use_skill` before the effects, held in `_lift_picks`,
which `dispel_status_effects` and `_after_heal` take first (the `lift` suite).
Anything lifting conditions mid-turn goes through `_movement_after_lift`, so
lifting a root gives the actor back their movement less `walked_this_turn`.

**Bags are containers end to end** (Campaign "Containers"). The player calls the
belt the **Baldric** (`EquipmentDefinition.SLOT_NAMES`, `slot_name_of`); its key,
enum value and file names stay `belt`. A belt, a pouch and a
backpack are `EquipmentDefinition`s (slots Belt, Pouch, Backpack - appended to the
enum) with **Slots** and **Bombs Per Slot**, kept in `Campaign.containers`; the
flat `inventory_of` is the belt's slots, then the pouch's, then the backpack's,
so code that walks a bag as slots keeps working and "the front" is the belt.
Ask `bag_size`, `combat_slots_of`, `container_start`/`container_at`,
`contents_of`, never `INVENTORY_SIZE`/`COMBAT_SLOTS` (the starting sizes). A slot
holding more than one bomb (`ItemDefinition.bomb`) is counted in `stacks`
(`count_in`, `holds_at`); `stow_item`, `take_item`, `move_item` and `count_of`
know it. `wear_container`, `take_off_container` and `swap_containers` re-lay the
bag (`_segments`, `_packed`, `_lay_out`) and refuse what will not fit. Rummage
(EffectType.DRAW, Combat "Drawing") moves one thing from pouch to belt in a
fight: a main action from `main_skills_of`, a secondary one too from
`secondary_grants` for anybody with `items_as_secondary`.

**A new `SpawnDefinition` field needs a home on `SpawnMarker`.** The encounter
editor's Save rebuilds every spawn from its marker (`_spawn_from`), so a field
that `rebuild()` and `_spawn_from` don't both carry goes back to its default on
every Save. This happened to Arrives On Round and Surprised. The `gear` suite
sets every stored field and fails on any it doesn't know about.

**Sixty-four levels, and the story's own.** `Stats.MAX_LEVEL` is 64; attributes and
health climb linearly between level 1 and 64 (`Stats.main_stat_at`,
`CombatantDefinition.hp_at` - its `max_hp_level_20` is the top level's health),
gates by `Stats.GATE_STEPS` (`gates_for_level`, as wide as `GATE_NAMES`;
`no_gates()` for nobody's; a `half_caster` - the Ranger - has a full caster's at
half its level, rounded up, `half_caster_gates`, like a D&D paladin). The story fights at 1, 8 and 14. A fight walked into
from a map (or a dungeon) fields the party at `Campaign.party_level`, on their
chosen path and in their gear (`create_combatant`'s `level`/`subclass` arguments,
`Combat.wear_gear`); one opened from Arena Mode uses the spawn's level,
subclass, weapon and defence. `Campaign.set_party`'s level is a floor and raises
through `reach_level`, never lowers. A spawn's defence of 0 (the default) is
`CombatantDefinition.defense_at(level)` - `defense` to `defense_level_64`, like
`hp_at`, or the steps of `defense_by_level` - and so is anybody created without
a spawn. The enemies' health and defence follow `docs/enemy_progression.csv`
(frail / average / tanky, per tier), the party's
`docs/player_hp_defense_progression.csv`, Cyrus's shot multipliers
`docs/cyrus_damage_adjustments.csv`; prices and fight pay follow
`docs/consumables.csv` and `docs/gold_economy_gear.csv`. The `csv` suite checks
the progression, party and enemy sheets against the data, `ammo` Cyrus's.
A condition's `defense_change` (Corroded's -0.1) is folded in `fold_stat_changes`,
so it lasts, refreshes and is cleansed with the condition.

**How to treat the numbers** (the design handoff, `docs/handoff_0.1/`, read
`claude_working_instructions.md` first): the repository is the implementation
truth and `docs/perplexity_combat_context.md` a dated snapshot - report
mismatches, never overwrite code to match it. Every value has two statuses:
ImplementationState (PRESENT / ABSENT / VERIFY) and DecisionStatus
(EXISTING_BASELINE / APPROVED_TRIAL / PROPOSAL / OPEN / APPROVED_DESIGN, and
OPTIONAL_TUNING_TOOL for something kept on hand but not part of the baseline -
the heal cap); blank is unknown, never zero; a sheet's ranges are references for
testing, not decisions. Only what the designer approves is implemented - confirm scope
first; everything else is a PROPOSAL. Every value and change is in
`docs/design_status_ledger.csv` (source, value, proposal, dependencies,
evidence, acceptance test, owner, version, outcome). Chapter I (levels 1-18) is
the main target - `docs/chapter1_audit.md`, with every value in
`docs/chapter1_inventory.csv` (`tests/run.sh chapter1` writes it); Sixty-Four is
a regression test; party health, enemy damage, gear, rewards, boss stats and
encounter composition are not to be changed broadly yet.

**The progression is `docs/progression.csv`** (how it went in: `docs/progression_plan.md`;
the `csv` suite checks every Base row against the data). A move that only grows
stronger has **ranks** (`SkillDefinition.ranks`, `SkillRank`): read a skill's
multiplier, condition dial and condition length through `Combat.modifier_of`,
`dot_strength_of` and `rank_duration` wherever the user is known - never
`skill.ability_modifier` straight. The passives' switches are read in Combat
"Progression" (`damage_reduction_of` inside `damage_taken_multiplier`,
`progression_damage_bonus` inside `damage_dealt_multiplier`, `contest_bonus_of` in
`wins_contest`, `lingering_bonus`/`lingering_turns` in the CONDITION and
DAMAGE_OVER_TIME branches, `_after_heal` in `do_heal`, `_mend_at_turn_start` and
`started_in_cover`/`moved_this_turn` at a turn's start, `spells_cast` (Kindling)
counted in `_use_skill` after the effects, `add_deepest_castings` at
creation and after gear). `in_cover` is beside a tile that blocks sight. An
enemy with one of the party's moves keeps its own learning level for it
(`CombatantDefinition.skill_levels`, read by `meets_level_for`), so a move moved
later for the party (Sweep Strike, 54) is not taken off the Barbarian.

**Five chapters** (Campaign "Chapters"): `CHAPTER_LEVELS` is where each ends
(18, 33, 45, 55, 64); `begin_chapter(n)` from a dialogue. The character sheet's
Levels page (`ui/character_sheet.gd`, "Levels" - `levels_of(key, subclass)` is
the table) stops at 55, ΛΗΘΗ, until Chapter V (`levels_in_view`), and plays its
unveiling once after (`levels_unveiled`). Its Moves page lists skills, then
spells on a shelf per gate. Tab or the right trigger (`skill_tab`, read in
`_input` before focus takes Tab) turns the page.

**Spellbooks** (Campaign "Spellbooks"): somebody with `learns_spells`
(Prometheus) knows `starting_spells` and what is in `Campaign.learned_spells`,
nothing else, path spells included. A book is an `ItemDefinition` with `teaches`
(so `stealth_only`); a Gate Nade teaches its spell too (`spell_taught_by`). Only
`learnable_spells` (theirs and their path's) can be learned. The Moves page's
Learn button calls `learn_spell`, which uses up the first teacher in the bags.
A fight walked into from a map strips what is not learned
(`Campaign.forget_unlearned` in `_deploy_party`); Arena Mode knows everything.
A test that fields Prometheus from a map with a spell in mind has him `learn` it.

**Paths are passives, mostly.** `SubclassDefinition` (data/subclasses) gives
skills and passives; `Combat.take_path` adds them from level 24 (Stats.SUBCLASS_LEVEL).
What a path does is a switch on `PassiveDefinition`, read in "What the paths do"
and "The paths" in Combat.gd (`_path_hit_bonus` in `progression_damage_bonus`,
`_evades` after the hit roll, `_splash`/`_overload`/`_spellstrike` in
`_after_landing`, `_last_wall` in `do_damage`, `_paths_at_turn_start`), "Traps",
"Catalyst" and "Zones"
through `active_passives` (which honours each passive's `required_level`).
**Tremor** (the control trial, APPROVED_TRIAL 2026-10-24; `tremor` covers it):
`_splash` catches each one once at the harder of a rank's splash and Tremor's
share, and Tremor shoves everybody beside the target, and the target, a tile
whichever was harder - Titanfall's `splash_shove` is 0. A shove of hers into
something solid puts `tremor_impact_condition` on them (`_tremor_impact`:
Dazed, a PROPOSAL test value; `put_condition` replaces rather than stacks, and
`turns_stored` keeps it to their next turn). In her own turn `_splash` notes who
it threw (`tremor_struck`, ids, cleared at turn start); after the action
`tremor_step_to` steps her - not asked, free, provoking nothing (`teleport_to`) -
onto the straight tile of `tremor_steps` nearest the first of them still
standing (designer, 2026-10-24: choosing every turn would tire the player).
**Zones** (EffectType.ZONE, `lay_zone`): their conditions are status entries
carrying `zone_id`, owned by `sync_zones` alone - it runs after every step
(`CController._handle_step_arrival`), every use and every turn start
(`_zones_at_turn_start` counts the caster's turns down). Anything else that
moves somebody mid-turn is caught by the next of those. A zone outlasts its
caster (`_zones_round_begins` counts it by the round then); `zone_unseen` keeps
it off the other side's board (`zone_tiles`). `makes_invisible` on a zone's
condition is `_zone_invisibility`, held off by `shown_this_turn` (set by
`_invisibility_ends` and every reveal, cleared as their turn starts). A thing
on the map with `illusion` (Illusory Cover) is an image to sight and cover and
is left out of `get_targets_in_tiles`.
**Illusions fool the other side, whichever that is**: `believes_illusion(thing)` -
the AI's mind (`ai_believes`, `_believer_side` set where it is switched on) or
the player's while aiming (`party_believes`: a skill selected on the player's
turn). Ask it, not `ai_believes`, for anything about an illusion. An enemy's
image is named and drawn as its original, and its making is not said.
**Dispelling** (Combat "Dispelling"): spell effects carry `spell_gate`
(`_mark_spell_gate` after `_apply_effect_by_type`; `invisible_gate`; summons and
images; a zone's `gate`), from `spell_gate_of(skill)` - `_casting_gate`, set in
`_pay_for_cast`, which honours `cast_through` (`chooses_gate`, `_choose_gate`).
Spells never have ranks (`csv` checks).
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

**Ten gates, World to Yaldabaoth.** Names, colours and counts all extend: add a
name to `Stats.GATE_NAMES` (and a colour to `GATE_COLOURS`, or one is picked)
and its counts to `GATE_STEPS`. Anything that lists gates should skip the ones
somebody has none of (the HUD and the hacking screen do). The Spells panel is a shelf per gate that
scrolls within the action panel's size (`ui/spell_shelves.gd`), so more gates
never make it bigger. Skills use the twelve-button grid, until a tab has more
than twelve; then they go on one untagged shelf (`build(..., flat)`), since the
grid would drop the rest without a word. `paths` checks every kit at the top level.

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
draws it over its square (or, sharing a tile, in a cluster round its middle -
`drawing_offset`) and `Sizes.draw_scale` scales it. Anything that moves a sprite back "home" returns
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
  carries `hacked` / `hack_locked`. A declared move is hackable only when
  `SkillDefinition.can_be_hacked()` (Hackable, or its own `hack`); `refusal_for`
  turns the rest away. A bound creature's binding is exempt.
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
  - Every way an enemy drops what was read goes through `_future_changed`:
    the log line, `comb.thwarted` (cleared as its next turn begins), the
    shatter (`CController.shatter_future`, `control/FutureShards.gd`), the
    sound, the queue crack (`combat_ui._set_crack`) and the reader's line.
  - `foreseen_victims` and `foreseen_doom` are worked out live, so the red
    marks follow health.
  - Path hooks live on PassiveDefinition (Intuition group), applied in
    `read_intent` and `damage_dealt_multiplier`.
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
- **Sight at somebody big.** `has_line_of_sight(..., looking_at)` leaves the
  creature being looked at out of the bodies that block it. The range filter
  passes whoever stands on each tile; `CController.is_valid_skill_target` takes
  the aimed tile, and a face is aimed at its `face_aim_tile`. A target check
  against `target.position` alone is the corner of somebody big - don't.
- **Big ones from every edge.** Ask `sees_tile(viewer, tile, looking_at)`
  rather than `has_line_of_sight(viewer.position, ...)`: it looks from the
  viewer's nearest tile. Anything drawn on somebody goes at their node plus
  `drawing_offset` (their middle), not the node - floating numbers, recoil,
  the hover ring (`rect_of`), the camera. `_aim_points` and the reaction tiles
  in `threat_map` spread from every tile of the square.
- **Melee.** `SkillDefinition.melee`, asked through `Combat.is_melee`. It's
  set in the data, not worked out from range.
- **Watching a turn.** `watch_combatant` follows the sprite offset to the middle
  of their square, and `camera.fit_in_view` pulls back for somebody bigger than
  the view; `release` puts the zoom back.
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
- **`refusal_for`.** `refusal_for` is the one place a use is ruled out for
  who it is aimed at: too heavy, too small to climb, no leverage, can't be
  bought. There are no taunts (Combat "Hemmed In and Exposed"). `use_skill` and `CController.refusal_at` both ask
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
  - A holder's walk drags them along (Combat "Dragging"): `_handle_step_arrival`
    calls `drag_held` before `check_holds`. `drag_cost` (2 unless the held is a
    size or more smaller) prices every step there and in `_step_cost`,
    `move_on_path` and the drawn path, and `get_reachable_tiles` divides the
    budget by it - so the AI and the danger view plan the same halved walk.
  - A reactive skill is offered beside any other reactive skill
    (`choose_reaction`, `ReactionPrompt.choose`).
  - A grab mid-walk is stopped in `CController._handle_step_arrival`.
- **Ignores Defense**: `defense_against`, read by `skill_damage`, the one place
  a hit meets Defense.
- **"Reactions"**: `SkillDefinition.reacts_when` (flags, `Trigger`). Leaves
  Reach is still `check_reactive_skills`. Everything else goes through
  `_react(trigger, enemy, why, protected_for, fits)`, called from:
  - `_react_to_step`, at the end of `check_reactive_skills`;
  - `_react_to_casting` (Casts), in `use_skill` before the animation, for
    anything `is_spell`. It sets `comb.casting`; `cancel_casting`
    (EffectType.CANCEL_CASTING, InstaHack) sets `cast_cancelled`, and then
    `_cast_cancelled` pays (`_pay_for_cast`) and spends the action;
  - `_react_before`, in `use_skill` once the targets are known (an attacker
    left stunned there hits nobody);
  - `_react_after`, once it has landed;
  - `declare`, which is awaited now.
  `SkillDefinition.set_off_by` and `sets_off` decide who may set a trigger off:
  only the `EITHER_SIDE` ones allow allies, and a readied move's `by` does the
  same. With an ally as `source`, `protected` is that ally.
  `SkillDefinition.reaction_only` is refused by `refusal_for`, greyed by
  `wasted_on`, refused by `ready_refusal` and skipped by the AI's skill pickers.
  `_reaction_target` is who it lands on. `_choose_option` asks the player through
  `ReactionPrompt.ask/choose` with a `happening` line. `acting_foreseen` is set
  around `_ai_follow_intent`'s use_skill, for Foreseen Blow.
- **"Ready"**: `comb.readied` (`ready_action`, `drop_readied`, `_fire_readied`).
  The gate and main action are spent at readying. It's dropped at the start of
  its user's turn, by a stagger, by changing sides or breaking, and by a hold
  only when `_ready_impossible`. ENTERS_AREA's `area` is drawn by CController.
  There's no player UI for it yet.
- **"Readying, for the AI"**: `CombatantDefinition.ai_readies` (flags, `AiReady`).
  `ai_process` sets `ai_turn_live`; `advance_turn` hands a turn that ends with its
  main action unused to `_ai_consider_ready`. A guard is handled earlier, in
  `ai_process` (`_ai_can_strike_this_turn`, `_ai_guard_ready`, `comb.post`).
  `_ai_ready_pick` prefers free moves, and `_ai_can_spare` keeps the last casting.
  `threat_map` adds readied areas and Enters Reach reaches to `reaction`.
- **"Invisibility"**: `comb.invisible` on top of `comb.hidden`, so everything
  that leaves the hidden alone (`is_hidden`) leaves them alone too. What ends it
  is the difference:
  - `reveal_anyone_now_seen` skips the sight check for them, and `do_damage`
    doesn't reveal them.
  - `apply_effect` ends it (`_invisibility_ends`) when the bearer does anything
    but REVEAL to the other side.
  - `last_in_sight` is the side rule for both kinds of hiding: with nobody on a
    side left in sight, everybody hiding there is revealed. `refusal_for` asks
    `_invisibility_refusal`. An image of somebody (`image_of`) counts as in
    sight while whoever made it (`made_by`) stands (`_image_holds_the_eye`), so
    behind images a whole side can hide; the last image gone gives away its
    maker (`_after_image_gone`, from `_shatter`), and the maker falling gives
    away everybody (combatant_die's `reveal_anyone_now_seen`).
  - `set_hidden(comb, false)` always clears `invisible`.
- **Gates outside a fight** (`Stats.OUTSIDE_GATES`, Iris): a skill's
  `outside_gate`. Castings are `Campaign.outside_gates_left` / `spend_outside_gate`,
  saved in `outside_spent`, which `_deploy_party` clears at every fight outside a
  dungeon. In one, a rest brings them back: `recover_gates(key, counts, outside)`
  at `outside_gate_cost` (the matching gate's price), RestPanel's Outside rows.
  They are not `spell_slots` and never meet the ladder's "pay with a higher gate"
  rule.
- **Invisibility on a stealth map** is per member: `StealthWatch._unseen` (key ->
  seconds), `go_invisible(keys)`, `unseen(key)` (the leader when not named).
  `ui/invisibility_picker.gd` chooses who, holding the game (MenuPause). It's read
  in `can_perceive` and `gaze_of` (hounds still smell), and `_seen_again()` ends
  it for whoever leads, from every action on a guard. A new action on a guard
  should call it too. `build_fight` carries it on as `SpawnDefinition.invisible`,
  which Combat applies once everybody is placed (`_begin_invisible`, last spawn
  first) and to late arrivals.
- **"Body parts".** `_aimed_tile` is the impact tile, set only around each
  target's effects in `use_skill`. `do_damage` → `_hit_part`. Drawn by
  `CController._draw_parts` from `part_marks()` (whose `id`, `name`, `kind`),
  coloured by `PART_COLOURS`; `_note_hover` redraws as the pointer moves. Only
  a blow at one tile aims at a part (`aims_at_parts`: `aoe_radius_of` 0); an
  area - a grown blow's cone too - lands on the whole of them, and neither the
  aim prompt nor the board lights a part for it.
- **Turn-start ticks.** `advance_turn` awaits `start_of_turn_effects(comb, true)`:
  each tick plays the entry's `sound` (the inflicting skill's, stored when it
  landed) with a `TICK_BEAT` after it, input locked meanwhile. It walks a
  snapshot (`_effect_index`), since a tick can shrink the list (a phase's
  `clears_conditions`). Unpaced (tests, `process_status_effects`) it's instant.
- **"Images"** (`summon_decoy`): a skill `placed_in_reach` is aimed twice
  (`CController.aimed_twice` - who, anywhere, then where in reach; `_placing_at`).
  `ai_believes` is the other side's mind: on through `ai_process`, `threat_map`,
  `plan_intent`, off through `use_skill`, `advance_turn` and a step arriving.
  While on, an image is a body to sight (`CController.blocks_sight`,
  `_SightGrid.stand_back`); otherwise it stops nothing. `ai_target_value` judges
  an image as whoever it is of (`_seen_as`, `image_of`).
- **"Growing"**: `size_wanted` (base_size plus "size" status entries),
  `resync_size` from the turn ticks, dispel and revive; `resize` finds a square
  (`_room_to_grow`) and `_stretch_parts` copies parts per combatant. BossPhase
  `grows` raises base_size. `resize` alone leaves base_size be, so a test that
  resizes somebody walks them at that size (`CController._full_size`), but
  `size_wanted` still says the old one.
  - A melee blow's area is `aoe_radius_of(comb, skill)` and `aoe_shape_of`, from
    size minus `comb.original_size` (`_grown_by`; `area_grows_with_size`: melee,
    damaging, no throw, reach 1 unless it has an area). A one-tile blow grown
    becomes a CONE of 1 + sizes grown (get_impact_tiles adds the aim tile if the
    cone misses it); one with an area of its own goes +-1 a size. Ask them, not
    `skill.aoe_radius` / `aoe_shape`, wherever a user's actual area matters -
    pass the user to `get_impact_tiles`. Places that only sort skills into
    single-target and area (`find_best_single_target_skill`, `_hurts_somebody`)
    keep the skill's own.
  - A line or a cone from somebody bigger than a tile goes out of the tile of
    their square nearest the aim: `nearest_tile_of`, or `nearest_from(comb,
    anchor, aim)` for a standing tile the AI is weighing. The aiming marks
    (CController) once drew it from the anchor, and disagreed with the hit.
  - `resize` moves the sprite to the new anchor (`sprite_point`) - grown up or
    left, it was drawn over the square below - and `place_sprites` puts the
    drawing back over the tile once somebody is a tile big again.
- **"Summons"**: `comb.summoner` (the caller's id) - from EffectType.SUMMON
  (`summon`, aimed at a tile; `use_skill` calls it before the targets loop) or
  `summon_at_start` (`_bring_starting_summons`, and late arrivals). Not in
  `_base_queue`/`turn_queue` and skipped by `advance_turn`. `command` (EffectType
  COMMAND, `secondary_grants` adds "command") makes the summon current for a
  moment (`_commanding`); `advance_turn` with it current calls `_end_command`
  instead of advancing - so a summon's AI or the player's End Turn hands back.
  `_summons_turn_begins`/`_summons_turn_ends` (ticks, auto `_stand_guard`) and
  `_summons_fend` (lost turn: `ai_summon_alone`) hang off `_advance_turn`. On the HUD a summon is no
  party portrait: `combat_ui._refresh_summon_faces` hangs a small one (on a
  Node2D, out of the containers' way) beside its summoner's portrait and in the
  corner of their turn-queue face.
  `_summoner_gone` (combatant_die, `_taken`) `_unsummon`s them; a summon falling
  is `_unsummon`ed too (taken "unsummoned"). `record_party` skips them.
  `CombatantDefinition.untouchable`: hit_chance 0, `lose_hp` 0, `apply_effect`
  from the other side does nothing, `ai_target_value` 0. The AI is `ai_summoner`.
  A summon With Summoners Attributes carries `attributes_of`, and `stat_of`
  reads its summoner's live stats. Auras go through `_aura_of` (turn starts and
  arrivals); `_aura_takes_hold` is the `aura_contested` check.
- **"Tethers"**: `SkillDefinition.tethered` / `tether_strength` /
  `tether_per_turn` / `tether_per_damage`; `comb.tether`. `use_skill`
  snapshots everybody's status effects and marks what the cast added `tether_of`
  its id (and its summons); `snap_tether` strips those and unsummons. Fraying:
  `_tether_turn` (turn start) and `_tether_hurt` (from `lose_hp`), both through
  `fray_tether`. Drawn by `status_icon.set_tether` and `CController._draw_tether`.
- **"Loot"**: no fight rewards anything by itself. An enemy's spawn carries
  `starting_items` (into `comb.pocket` up to `CombatantDefinition.pocket_size`,
  the rest and anything `stealth_only` into `comb.carried`) and `equipment`
  (`_wear_spawn_equipment`: weapon base, defence, a charm's passive;
  `comb.equipment`). `is_lootable` is a body of the other side, down but not
  gone (fled, bought, unsummoned), with something on it. Loot (EffectType.LOOT,
  `data/skills/common/loot.tres`) is a secondary action `secondary_grants` offers while
  there is one; `refusal_for` turns away a tile with no body; `loot` stows
  items (`_stow`) and gear into `Campaign.gear`. ResultUI's "Search the fallen"
  calls `loot_the_fallen` once the fight is won (not on a dungeon's rest panel).
- **Pockets, for the AI**: `_ai_main_keys` takes pocket items that are
  `_item_against_the_other_side` into the archetypes' plans, weighed like any
  skill; `_ai_heal_key` picks the best mend between a heal skill and pocket
  heals (the ranger and the healer use it). `ai_alchemist` mends anybody below
  `AI_ALCHEMIST_MENDS_BELOW`, else throws, with both actions (its Bandolier).
- **Hops** (CController "Hops"): `_begin_step` asks `hop_for(mover, from, to)`
  at the start of every step; onto or off high ground the sprite arcs over the
  step (`CombatantSprite.hop`); between floors the walk snaps, then holds
  `FLOOR_HOP_SECONDS` while the drawing rises or drops into place. The height
  walk breaks ties between equally dear routes by how long they look
  (`_looks_longer`) - without it a diagonal costing what a straight step does
  made Cyrus (who walks by those rules everywhere) zig-zag.
- **"Squeezing"**: `PassiveDefinition.squeezes`, `can_squeeze`, `fold_shapes`
  (square, then a size narrower, shorter, both), `fit_to_room` (from
  `_handle_step_arrival` and `resync_size`). Folded, `comb.fold` is the shape and
  `comb.squeezed` is true; size stays. Everything geometric reads
  `Combat.footprint(comb)` (rect_of, covers, tiles_of, drawing_offset,
  `drawn_scale`), never `span` - a new place that does needs to. Parts stay in
  square terms; `_unfolded` / `_folded` map them (part_index_at, part_marks).
  `resize` and `_room_to_grow` drop the fold. The walk plans it: `_stance` is the
  shape (ZERO for none), a fold at twice the cost (`_add_step`, `_step_cost`); a
  squeezer always walks by the heights rules (`_height_pathing`).
- **"Heights"** (Combat) and CController "Heights" / "Floors on the screen":
  `_heights`/`_floored`, `climb_tiles`, `is_high`, `floor_of`/`real_of`/`tile_on`.
  Floors are separate regions of one TileMap, so everything per floor works as
  before; cross-floor is `get_position_distance`, `has_line_of_sight` ->
  `_sight_between_floors`, `floors_open_between` (in `refusal_for` and
  `get_range_tiles`). Walking is `_height_steps`/`_height_search`/`_height_path`
  for anybody a tile big (`_height_pathing`); a step more than two tiles long is
  a floor change and snaps. `comb.up` and `_up_tiles` come from
  `refresh_occupancy`; `terrain_class` is 1 when up. `_aim_blocked` lets a target
  on high ground be aimed at. The danger view uses `has_line_of_sight` on height
  maps (its flat grid knows nothing of who is up).
  - `Combat.climbs_anywhere` (PassiveDefinition, Cyrus's Cat Burglar): such a
    mover walks by these rules on every map (`_height_pathing`), needs no climb
    tile (`_add_step`), climbs to the floor above over a walker-blocking tile
    beside them when nothing is overhead (`_height_steps`), and is marked `up`
    and has his climbs said on maps without heights too.
  - Size is height: `Combat.elevation(comb)` (up, plus a level a size above
    Human) fills the controller's `_raised` (`raised_at`); sight looks as a flier
    from or to a raised tile, and `_eye_height` (with the viewer's size as a
    floor) lifts a tall one unless a floor is over them. Any line between eyes
    on either side of a floor's level must cross it through open air
    (`_floors_crossed_open`, walked from one end by `_walked_from_b`) - between
    floors, and on one floor with somebody raised under a floor above, where
    has_line_of_sight hands it to `_sight_between_floors` too. Large+ step over high ground
    (`steps_over_size`, `blocks_for` - room_for and `_fit_points_to_big` ask it).
  - The walk is per footprint (`_fits_as`, `_stance`): every tile on one floor;
    stairs only as wide as the climber (`_stairs_under`); down only into open
    air the size of them (`_open_air`); Small and Tiny share by `room_for`.
  - `_spread` keeps to a floor; `_aims_across_floors` is the other floors for the
    danger view, and `threat_map` returns `across` (enemy id -> floors), which
    `_draw_ghosts` reads to draw a threatening ghost red.
  - Reactions: `reach_gap` (OUT_OF_REACH for melee across floors),
    `_reaches_through_floors` and `nearest_across` in Leaves Reach, Enters Reach,
    `_reaction_target` and the readied area. `ready_area` keeps to the floor it
    is put on; `ready_refusal` asks `floors_open_between`.
- **"Arriving late"**: `SpawnDefinition.arrives_late()`; `_arrival_due` wants
  round, `fallen_of(ENEMIES)` and `_cues` (`cue(name)`, raised in `_break_part`,
  `stagger`, `combatant_die`, `set_off`/`_becomes`, `_begin_phase`, `swallow`,
  `_digest`, `eat`). `_bring_in_arrivals(true)` runs at every turn's end
  (advance_turn) through `add_mid_round`; the round top keeps the plain one.
- **"Swallowing"** reuses Climb's riding: `riding` + `inside`, `digest_left`,
  `inside_condition`. `climbers_of` (not `riders_of`) is who gets shaken off.
  `dismount` clears the inside state and shows the sprite. Inside, `refusal_for`
  allows only a single-target blow at the swallower; `get_range_tiles` is its
  tiles; `_aim_from_inside` sends the blow to the part that frees them.
- **"Gluttony"**: `_glutton_turn_begins` (digest, `_regrow_clock`, `feed` or
  `_eat_itself`) from advance_turn after `_turn_begins_for`; `ai_glutton` feeds
  again after moving. A body eaten gets `eaten` (fallen_at, prisoners skip it).
  `part_index_at` asks the newest part first; `part_marks` drops covered tiles.
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
