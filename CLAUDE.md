# Messengers of Truth

A grid tactical RPG in Godot 4.7.2. `project.godot` sits at the repo root, so
every folder here is inside the Godot project - including `tests/`, which
carries a `.gdignore` to keep the editor from parsing 89 test drivers on every
start and shipping them in builds.

The game starts at `scenes/game.tscn` and the menu at `main_menu.tscn`.

## Running the tests

```bash
tests/run.sh                 # every suite
tests/run.sh dot flags       # just those
tests/run.sh --list          # what there is
```

A full run is 88 suites and takes a while. Each one boots the real game
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
never make it bigger.

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
