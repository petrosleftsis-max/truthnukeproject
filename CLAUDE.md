# Messengers of Truth

A grid tactical RPG in Godot 4.7.2. `project.godot` sits at the repo root, so
every folder here is inside the Godot project - including `tests/`, which
carries a `.gdignore` to keep the editor from parsing every test driver on every
start and shipping them in builds.

**Where the work stands, and what waits on the designer: `docs/where_we_are.md`.**
Read it at the start of a session, and keep it current at the end of one.

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

A full run is 170 suites and takes a while. Each one boots the real game
headless, plays something out and writes a result file; the runner prints one
line per suite and exits non-zero if any of them is unhappy. `tests/README.md`
has the details, including how to add one. A second harness can run beside a
full one: `MOT_TEST_WORK=<a folder> MOT_TEST_USER_DIR="MoT harness 2" tests/run.sh
<suites>` - never `net` in both at once, since its ports are fixed, and never edit
`tests/run.sh` during a run, since bash reads it as it goes.

Godot is found by `tools/find_godot.sh`, which every script that runs it
shares: `$GODOT` if set, then `godot` on PATH, then the places it has been
unpacked on the machines this is worked on - `E:\Godot\` on one, and
`C:\Users\ortin\Downloads\Godot_v4.7.2-stable_win64.exe\` on the other, where
that `.exe` on the end is a **folder**, not the executable. A new machine is a
line in that file. On Windows use the **`_console`** build - the plain `.exe`
writes nothing to a terminal, so a headless run looks like it did nothing.

## What Godot will do to your .tres files

Five things, all of which have cost real time here.

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

**A `uid` on an `ext_resource` line beats its `path`.** Change the path by hand on a
line that has one, and the game goes on loading the old file without a word: Share the
Fire wore Trailblaze's icon that way. Take the uid off in the same edit.

## Writing files into this project

**Never write a project file as UTF-8 with a BOM.** PowerShell 5.1's
`Out-File -Encoding utf8` adds one. Godot's editor then refuses the file while
headless runs keep passing, so the tests say everything is fine and the editor
says the project is broken.

**Backslash line-continuations in GDScript do not survive a bash heredoc.** A
wrapped line written that way arrives mangled and still compiles, which is the
worst of both - it runs, and it does not mean what you wrote. Write such files
with a real file-writing tool, or keep the line unwrapped.

**New scripts and pictures need the editor's scan before the game will run.** A
`class_name` the editor has not seen yet is unknown to every other script, and a new
picture has nothing imported, so a game started from the Project Manager's Run (which
scans nothing) stops on parse errors at a black screen, while the tests, which import
their own copy, pass. After adding either, run `godot --headless --path . --import` in
the project (with no editor open on it) and commit the `.uid` files it writes.

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

A blast that respects blocking needs a clear line from where it is thrown to where it lands, whatever its size (`_ai_best_aim_from`,
on the plan's `_SightGrid`; the designer saw the lab's casters throw Wildfire through walls, 2026-11-12; `wallcheck` plays the lab's City
Fight and checks every one). It only scores aim points near somebody worth hitting, and each aim once per
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

## Rolls in a fight

Every roll in a fight - to hit, contests, damage and heal ranges, breaking free,
which way the wind blows, where the arena strikes, the AI's choices - comes out
of `Combat.rng` ("Rolls"), seeded once from the encounter's "seed" meta (a
networked fight's) or at random (`seed_rolls`, `_seed_wanted`). A fight begun
from one seed and played with the same moves comes out the same on every
machine, which is what lets a network send only the moves
(docs/multiplayer_plan.md). So fight code never calls `randf`, `randi`,
`randi_range`, `shuffle` or `pick_random` itself: it uses `rng` and `_shuffle`.
Randomness that changes nothing in the fight (the camera's shake, FutureShards)
can stay global; QuickTime's and Hacking's are the player's to play, and over a
network what they come to is sent like an answer. `fight_state()` is the fight
as text - round, whose turn, everybody's side, health, tile, standing and
conditions - and is what a replay is checked by. `rolls` reads Combat.gd and
CController.gd for global rolls, and plays one fight twice from one seed.

## Projectiles

A move is seen going from its user to where it was aimed (the designer,
2026-10-30: so it is clear who does what): `combat/Projectile.gd`, a placeholder
drawn in code behind slots. `Projectile.fly` is awaited in `_use_skill` once the
targets are known and the reactions to it are over (the controller locked
meanwhile), in `use_reactive_skill` and in `_fire_readied` - so the blow lands as
it arrives. How it goes is `SkillDefinition.projectile_style` (the "Projectile"
group; `ProjectileStyle`, appended): Automatic is `style_for` - nothing for melee,
the user's own tile or a move that teleports somebody; STREAK for a line, FAN (three)
for a cone, BOLT when it respects blocking, ARC (over what is in the way, with a
shadow) when it does not. Its colour is `colour_for`: `projectile_colour`, else a
mend's green, else the element it lands as (`elements_of` / `effective_damage_type`,
`Damage.type_colour`). An orb with a two-layer trail behind it and a burst where it
lands; a move with an area lights the tiles it lands on (`area_points`, `_lit_at`) -
a line's and a cone's as it passes, an area's rippling out from where it lands;
`projectile_texture` flies in place of the orb,
`projectile_scene` in place of everything (told `landed()`). Its clock is the game's
(fast enemy turns, catching up) and nothing in it rolls or changes the fight.
Headless it lands at once unless `Projectile.plays_headless` - so no other suite
pays for it. `projectile` covers it.

**The fight's view** (`control/CameraController.gd` "Moved for the player", `Combat`
"The view, for what happens"; the designer, 2026-11-04). Nothing here is rolled
and nothing changes what happens, so over a network each machine's view goes its
own way. A blow has its attacker, where it is aimed and all of a blast in view
while it goes off (`_frame_the_blow` -> `camera.frame`, `_end_the_frame`;
`FRAME_LEAD_SECONDS`, `FRAME_ROOM_TILES`, `FRAME_HOLD_SECONDS`). What flies leans
the view after it by its style and kicks it as it lands (`Projectile.LEAN_SHARES`,
`KICK_PIXELS`; `lean_after`, `kick`). A turn this machine's player plays glides the
view onto whoever is up (`_glide_to_turn`, `glide_to`, `GLIDE_RATE`). The pan keys
or the wheel take the view back from any of it (`_take_back`); it never moves while
a fight is played through to catch up, nor headless unless
`CameraController.moves_headless`. Whoever comes in late is shown one at a time
before the next turn (`_keep_for_showing`, `_show_arrivals`, `ARRIVAL_*`). End Turn
is out of reach for `END_TURN_HOLD_SECONDS` as a turn of this player's opens
(`combat_ui._hold_end_turn`, counted down on the button; `holds_headless`).
`combatview` covers it. All the numbers are PROPOSAL.

**What aiming shows** besides the prompt (`control/CController.gd`, 2026-11-04 and
05): a blast that spreads from whoever a blow lands on shows round them
(`_preview_blast`, `Combat.splash_tiles_of`; Titanfall, Tremor; the tooltip's
"Blast" line); the tile a blink or a summon would take lights up
(`picking_a_landing_tile`); and somebody the skill only cannot get to - past its
reach, or no clear line, not too close - is still told in the prompt, under a line
saying so, the click still refused (`_only_cannot_get_there`,
`Combat.targets_if_reached`, `show_hit_preview`'s `cannot_get_there`) - whoever is
on that one tile, not the rest of a blast, and nobody hidden. `hitpreview` covers it.

**Prone** (Combat "Prone", `data/conditions/prone.tres`; the designer, 2026-11-05).
Free to lie down on one's own turn (`lie_down`, `lie_down_refusal`); getting up takes
`getting_up_share` of their movement, rounded up (`get_up`, `get_up_cost`,
`get_up_refusal`). `prevents_movement` makes every walker and AI treat them as rooted;
`controller.movement` is 0 meanwhile and `movement_left_when_down` keeps what they
had, absent when it is all of it (`movement_if_up`). `can_still_walk` is what the
turn's running out asks, since 0 is not spent. Damage: `prone_damage_factor`, in
`damage_dealt_multiplier`, so prompt and blow agree - `is_melee` is more, anything
else less, `_splashing` an area, no skill unchanged; `ignores_prone_cover` (Low Shot)
and `gets_up_free` (Kip-Up) on PassiveDefinition. `_lying_down` keeps it from
`_harmful` and `should_dispel`. The player's way in is `CController.toggle_prone` (the
`prone` action, Ctrl, and `combat_ui`'s `_prone_button`), told to the other machine
as the fight move "prone" (`change_stance`). Undo: `board_fingerprint` leaves the
walker's own lying down out, and `undo_move` puts it back (`_turn_start_prone`,
`_turn_start_kept`, `_stance_changed`, `put_back_lying`). AI: `_ai_turn` gets up first unless
`_ai_stays_down`; `goes_prone` (per creature, the Ranger's) lies down at its turn's
end (`_ai_consider_lying_down`). Erysichthon is immune (`immune_to_conditions`).
`CombatantSprite.set_lying` is a placeholder, with
a `prone` animation as its slot. `prone` covers it, and `net` plays it across.

**Shoves, foreseen** (Combat "Shoves, foreseen"; `control/CController.gd` `_preview_shoves`,
`_draw_shoves`; `combat_ui._shove_line`). One walk, `shove_walk`, does the shove and the
preview, so they cannot disagree. `foresee_shoves` plays out on the positions everything the
aim would shove - a PUSH or PULL, Push Extra, a rank's Splash Shove, Tremor, a River Flow's
sweep, a Gale Urn it would set off - and puts everybody back; nothing rolled. Somebody the
aimer cannot see is taken for empty air. The board draws a see-through figure, an arrow, a
red burst at a collision, a ring round whoever holds and faint figures on a Windswept's
possible tiles; the prompt has the damage, and the HP ghost counts it. A new thing that
shoves needs an entry through `_foresee_one`. `shoveaim` covers it.

**Spells have no levels** (the designer, 2026-11-06): a spell comes when its gate opens, and nothing else
(`required_level` is gone from every spell; `Combat.meets_level_for` asks `_gate_is_open_to`;
`CharacterSheet.comes_in`). `docs/progression.csv` still lists levels for spells, and the game ignores them.

**Spells and what they rest on** (the designer's lists of 2026-11-05; `enchant`, `spellstwo`,
`outsidespells`). Numbers the designer did not give are PROPOSAL (ledger).
- **Orders** (Combat "Orders"): a condition with `obeys_order` (Compelled): `_choose_order`
  asks the caster as it lands, in `_use_skill` and `_land_reaction`, through
  `reaction_prompt.pick`; the status entry carries `order` and `order_by`; `_advance_turn`
  plays that turn by `_obey_order` and ends it, either side, like Confused. Compel.
- **Letting go of a tether** (Combat "Letting go of a tether"; `letgo`; the designer, 2026-11-07): a right click on
  what it holds (`tethers_at`; CController, whoever's turn it is, `Coop.tether_under_pointer` letting it past the gate)
  opens `TetherChoice`, which asks if they are sure. Another player's goes to `TetherRequest`, on their machine
  (`Net.ask_to_let_go`). Then `let_go_of_tether`: due on both machines (`_let_goes_due`, `Net.let_go_due`), and
  it goes while the fight stands waiting for a player, as a "let_go" fight move from that player's machine
  (`_let_go_if_it_can`), or with nobody else playing as the next turn begins (`_let_go_as_a_turn_begins`, a move
  marked so). On a map: `StealthWatch.offer_letting_go`, `tie_outside`'s `where`, `let_go_outside`, "tethers" in `net_state`.
- **Tethers**: `EffectDefinition.held_by_tether` stores `HELD_BY_TETHER` instead of a count;
  a tether holding nothing lets go (`_release_idle_tethers`, at a turn's edges, on a hurt and
  when tied). A zone can be what it holds (`zone.tether_of`, `_zones_now`). Somebody knocked
  down stays down when it goes. `comes_off_when_hurt` is Mesmerise's break;
  `keeps_tether_when_hurt` (Composure, Shared Burden) keeps damage off the bar. Out of a
  fight a tether frays `OutsideMoves.TETHER_PER_SECOND` (5) a second, so a tethered move lasts
  its strength over that (`seconds_of`); `StealthWatch.tie_outside`, one to a character.
  The tooltip (`_tether_line`), the sheet (`facts_of`) and the aim prompt say its size.
- **Zones** grew, all on the ZONE effect: `zone_costly` (`hem_cost`), `zone_turn_damage`,
  `zone_hurts_everybody`, `zone_hurts_each_step` (`zones_under_step`, from
  `_handle_step_arrival`), `zone_leaves_conditions`, `zone_heals`, `zone_follows_caster`,
  `zone_moves` (`move_zone`; the `move_cloud` secondary, reach from the zone,
  `moves_zone` in `get_range_tiles` and `refusal_at`), `zone_melee_sweeps` (`_sweep_tiles`,
  in `shove_walk`; `_swept_along`), `zone_blows_out` (`_blow_out_of_zone`, at a turn's start
  and end), `zone_colour` for its placeholder tint. `zone_condition` may be null now, so
  ask before reading it.
- **In the dark** (Combat "In the dark"): a zone condition with `is_darkness` makes them
  invisible through `_zone_invisibility`. `hidden_from(viewer, comb)` is what to ask when
  somebody in particular is looking; the AI's looking about and aiming ask it, in place of
  `is_hidden`. `sees_in_darkness` (passive or condition; Cyrus's Night Eyes) and
  `sees_the_unseen` (condition). `unseen_by_party` is what the player can see at all:
  whoever anybody of theirs standing sees is drawn faintly (`dress_for_hiding`,
  `_redress_the_hidden`), though only they can aim at them. Stealth maps have their own
  `is_dark` and lamps. `EffectType.UNVEIL` (`unveil`; Unveil, Votive Flame).
- **Silence**: `prevents_spells`, in `can_afford_skill` (so the HUD, the AI and reactions all
  follow), `wasted_on`, `ready_refusal`, `_fire_readied`. Whoever stands in it cannot cast;
  a Gate Nade is thrown, and a spell from outside lands there.
- **Unbowed I-VII**, Alithia's (`data/passives/unbowed*.tres`; `newspells`; the designer, 2026-11-07): one passive in ranks,
  each a passive's Immune To Conditions: Fear at 1, Confused 8, Compelled 16, Blind and Deafened 24, Dazed 33, Choking Ash
  46, Stunned 56.
- `ConditionDefinition.immune_to_conditions` (Unafraid; `_lift_what_it_wards`),
  `evades_hits` (Four Reflections; `images_left`, in `_evades`; single blows only),
  `source_takes_share` (`_burden_share`), `climbs_anywhere`. `flees_from_caster` on the effect
  (Terror; `_run_from_terror`, `ran_this_turn`, `movement_budget_of`). `chooses_element` on
  a RESISTANCE effect (`_choose_element`). `answers_base_elements` on a reaction (Turn Aside;
  `_answers_this_blow`). `never_in_a_fight` on a skill (`outside_only`).
- **The Gates of Mnemosyne**: `Stats.OUTSIDE_GATES` index 2, matching the fifth gate; a spell
  marked `out_of_combat` pays there first by `iris_gate_for`. Company Unseen
  (`StealthWatch "The Company Unseen"`, `FamiliarKeeper._company_steerer`): everybody but
  Cyrus `_unseen`, all steered by whoever plays him while it lasts, guards' eyes cut to
  `COMPANY_SIGHT_TILES`, those on Stay Here called in (`call_in_stayers`), and the familiar the
  other player's. Great Snare is a `Use.TRAP`
  with `Trap.burst_tiles`: nothing has health on a map, so "a lot of damage" is everybody
  within it down.

**Illusions, from the designer's list of 2026-11-06** (Combat "Unnoticed until they act", "Disguises",
"Illusions that are called up", "Going to look", "False Ground"; `illusions`, and `outsidespells` on a map).
All on the Illusory Shepherd's path; numbers PROPOSAL. Phantom Noise: `drawn_to_aim` (`_noise_they_heard`,
`_go_and_look`, from `_advance_turn` after a terror's run); on a map a Lure with `lure_tiles`. Phantom Wall:
`summon_across` (`_summon_all`, `summon(..., only_there)`), a `wall` object with `illusion`: a wall to the
believer's sight only, no wall to aim at, no light stopped unless `illusion_stops_light`. It is placed by two
points: `CController.aimed_twice` is true for it, the first click is where it starts, and the second, snapped
to the nearest of eight directions and held to `Combat.wall_length` (`2 * summon_across + 1`), is where it ends
(`wall_end_for`, `wall_ends_from`, `aiming_a_walls_end`, `wall_end_at`). `wall_line` fills the corners of a
diagonal, since walking and sight cut them, and those fillers don't count towards the length. The end goes
as the move's destination (`_wall_ends_at`); with no end, `wall_tiles` is the old "across" for the AI or a
script. Each piece is drawn along the wall (`_lay_wall_piece` -> `CombatantSprite.lay_along`): its picture turned
to the line and, on a diagonal, stretched corner to corner, so the pieces join; a filler draws nothing and still
blocks, and the tile marks show which tiles it takes. `_draw_wall_to_be` shows the same line while aiming. Her side
walks through it; see "Seen through, one by one" below. Phantom Company: `summon_count`, `summon_as_images`,
`summon_shakes`. Seeming: `unnoticed_until_acting`: `until_acting`, `looks_like`, `_gives_themselves_away` in
`_use_skill` (`was_unnoticed`); on a map `StealthWatch "Seeming"`, `SEEMING` as what is worn (`_worn_item`).
Fallen Friend: a reaction only (Combat "A blow that would fell them", `Trigger.WOULD_FALL`: `_falls_instead`, in `_use_skill`'s
targets loop and `_land_reaction`, by `_blow_would_fell`; the blow never lands; a tethered reaction is tied in
`use_reactive_skill`), condition `looks_dead` held by a tether (`_begin_looking_dead`, `step_gives_away`,
`_keep_up_appearances` from `sync_zones`). Phantom Killer: `doubt_each_turn` (`_doubts_it_away`, in
`start_of_turn_effects`; `wins_contest(..., doubt)`). False Ground: `zone_false_ground`, `false_ground_for` in
every walk (`_apply_false_ground`, `get_reachable_tiles`, `_reachable_by_size`, `_add_step`), `zone.caught`,
`_false_ground_holds`. Mislead: `image_of_self`, `image_moves` (`double_of`, `move_double`, `MOVE_IMAGE`, the
`move_double` secondary), no tether; on a map `Use.MISLEAD`. Weird is data. `_seen_for_who_they_are`, from
`set_hidden(comb, false)`, takes off every look. **A disguise in a fight:** `disguise_refusal`, `fitting_disguise`,
`wear_disguise`, `DISGUISE_SKILL` in `main_skills_of` and `secondary_grants`, `hidden_from` asks
`sees_through_disguises`.

**Seen through, one by one** (Combat section of that name; `illusions`; the designer, 2026-11-07). An illusion stops
nobody of its own side: they walk through it, and nobody can stop on it (`illusions_to_pass`, read by
`update_points_weight`, `get_reachable_tiles`, `_reachable_by_size`, `_height_search` through `_passing`, `_fit_points_to_big`
and `_small`, `room_for`'s `passing`; `find_path` and `_stop_short_of_illusions` keep a walk from ending on one). A step
through (`illusions_stepped_through` from `_handle_step_arrival`; on False Ground `_false_ground_holds` by `zone.stood`) is
`_gives_away`: each of the other side who sees it (`_sees_it_happen`, as they believe things, so the rest of the wall stops
their eyes), and anybody at `SEES_THROUGH_FROM` (Trained) or smarter wherever they are, unless the walker is hidden from
them or they skip their turn. It goes into `comb.sees_through` by `_illusion_key`: a whole wall (`one_illusion`), all a
tether holds, a zone, so the next one fools them again. Ask `sees_through` and `not_fooled_by`. `believes_illusion` reads
`_believer`, set wherever `ai_believes` is: `ai_process`, `plan_intent`, `threat_map`, the readying as a turn ends. A
believer shoved onto False Ground still ends it for everybody. `get_combatant_at` prefers somebody real to an illusion on
their tile. `board_fingerprint` counts what has been seen through, so a walk cannot be taken back past it, and
`settle_undo_point` never leaves the way back inside one. Nobody notices who can see nothing (`_sees_nothing`): Blind, or
in darkness without `sees_in_darkness`.

**Enfina** (Combat "Enfina"; `enfina`; the designer's picks of 2026-11-07, section 15). Switches on a passive or a skill, numbers PROPOSAL. She pays, so others don't have to, and she knows
how you fight. `burn_turns_of`. Blazed Path: `blaze_where_they_walk` from the walk, a zone with "blazed_by", `blazed_for` in `hem_cost`, `blazed_path_bonus` in `set_controlled_combatant`. Flashover and
Cauterise: `needs_own_burn`, `ends_own_burn` (`_after_own_fire`), `modifier_per_burn_turn` in `modifier_of`, `heal_per_burn_turn`. Share the Fire: a condition's `dot_lands_on_source` (`_who_a_tick_lands_on`).
Through the Fire: `walks_through_fire`, `immune_while_burning`. Burning Titanfall: `_burning_titanfall`, from `_after_landing`. Drills: a passive's `reactions_granted` (`_reactions_open_to`, read by
`_react`; off the action bar), Riposte, Step In (`steps_in`, `_stepped_in`, `_take_blows_stepped_into`), `reactions_harder`. Reads the Form: `_spend_the_reaction`. Throw a Friend and Anything Is a Weapon:
`throws_friends`, `throws_things`, `BattleObjectDefinition.can_be_thrown`, in `_grip_refusal`, `throw_destinations`, `_hurl` and `CController.is_valid_skill_target`. Arrest: `needs_nerve_shaken`,
EffectType ARREST. Carries Them: `StealthWatch._carries_at_full_pace`, whoever leads.

**Prometheus's other magic** (Combat of that name; `prometheus`; section 16). Shrink: an effect's `shrinks` on GROW; on a map `OutsideMoves.Use.SHRINK`, `ExplorationScene.shrink_party`, `shrunk`
(small gaps walkable, `_shrink_on` waiting if it runs out inside one). Transposition: `swaps_places`, `transpose`, `can_transpose`, aimed twice (`CController.is_valid_landing_tile`, `landable_tiles`).
Grease: a zone with `zone_catches_fire`, `_fire_touches` from `_use_skill` and `lay_zone`; `_zone_strikes` contests a zone that does no damage. Wall of Stone: `data/objects/wall_of_stone.tres`, placed as Phantom Wall is.
False Life: EffectType OVERHEAL. Withering Touch and Blight: `ConditionDefinition.healing_taken_change`, `healing_taken_share` in `do_heal`.

**Lines in a bubble** (`combat/SpeechBubbles.gd`, `combat/resources/CombatLines.gd`; `speech`; the designer, 2026-11-07). Only to look at. `CombatantDefinition.lines` says what a creature may say at each moment;
`SpeechBubbles.on_event` from Combat (`CHANCES`, `QUIET_FOR_MS`, `WONT_WAIT`), `somebody_says` for a moment that is the fight's, `say_line` for one somebody means, `say_over` for any figure, and `do Campaign.say_bubble(key, line)`
for a conversation, on a map or in a fight. A CanvasLayer under the root, made as first needed, placed from the figure's position each frame. Global randomness is fine in that file, and not in Combat.gd (`rolls`). Headless: `plays_headless`, and `always` for a test.
A line of Enfina's and one of Prometheus's written on each monster (`CombatantDefinition.enfina_studies_line`, `prometheus_studies_line`; the designer,
2026-11-12): `SpeechBubbles.says_what_it_is` from `Combat.study`, once a fight for each kind (`_studied_said`), else her own Studies lines.
The designer's lines of 2026-11-13 (`data/lines/<key>.tres` for all four): `big_hit_taken` and `big_hit_given` (`Combat._say_of_a_big_hit` in
`do_damage`, a blow of `BIG_HIT_SHARE` of their most health or more), `brought_back` (`revive`), `condition_lifted` (`dispel_status_effects`
by `_is_harm`, and an effect's `lifts`), `enemy_gives_up` (`check_nerve` running: `somebody_says(..., side)`, one of the other side), `praise`
by the killer's key (`SpeechBubbles.praise` from `_say_of_the_fallen`, one other of their side, never for a boss), out of castings in
`last_casting`, and Enfina's Step In in `when_using.step_in`.

**The AI's mind** (Combat "The AI's mind"; `aimind`; the designer, 2026-11-06). Per creature:
`CombatantDefinition.ai_smarts` (`AI_KNOWN_BY`), `ai_also_knows`, `ai_never_knows` make `comb.ai_knows`
(`AiKnows` flags; ask `_ai_knows`), and the dials `ai_aggression`, `ai_caution`, `ai_focus`,
`ai_self_preservation`. Numbers PROPOSAL. A place: `_ai_read_the_field` (`_ai_mind`, `_ai_ground_map`) then
`_ai_tile_worth`, in `ai_plan_attack` and in `score_tile_safety` for `_ai_thinker`. A target: `ai_target_value`.
A plan: gates and `_ai_shove_worth` in `ai_plan_attack`. First things first: `_ai_mind_takes_over`, from
`_ai_turn`: `_ai_search_the_dark` (`_ai_seen`, `_ai_note_sightings`), `_ai_slap_awake`, `_ai_leave_bad_ground`,
`_ai_set_off_a_hazard` (`_ai_shooting_thing` lets a blow through at something of its own side's), `_ai_fall_back`.
A healer: `_ai_patient`, `_ai_most_afflicted`, `_ai_dispel_a_zone`. Nothing here reads a clock or rolls, so a
replayed fight agrees. `EncounterDefinition.ai_leaves_hazards` is the fight's own switch.
**Hunting in the dark** (Combat section of that name; `light`; the designer, 2026-11-12, Cunning and above: `AiKnows.DARK_PATCHES`, appended):
whoever goes into the dark in the other side's sight is remembered where (`_ai_saw_them_go`, from `_fade_into_the_dark`: `_ai_seen`,
`_ai_into_the_dark`); `_ai_dark_guesses` puts them there for a plan (`_ai_assumed`, `_ai_pos`, in `ai_worth_table` at `AI_DARK_GUESS` for an area
only, `_ai_aim_scores`, `_ai_best_aim_from`); Dispel Magic undoes a dark zone of the other side's hiding them (`_ai_best_dispel`); who fights
close goes in after them (`_ai_hunts_in_the_dark`); the dark's edge is cover (`_ai_mind.dark_cover`, `AI_DARK_COVER` in `_ai_tile_worth`).
**Dispelling and cancelling, for the AI** (Combat section of that name; `dispel`; the Sorcerer's Instahack and Dispel Magic, 2026-11-12):
`_choose_option` lets a casting go unless `_ai_cancel_worth` reaches `_ai_cancel_wanted` (`AI_CANCEL_*`); `ai_caster` tries
`_ai_dispel_a_zone`, then `_ai_dispel` (`_ai_best_dispel`, `_ai_dispel_worth` in blows, `AI_DISPEL_*`, through `cast_through`) before a blow.
What has to be worth a casting falls with the gates its caster has open (`_ai_gate_cost`, never under `AI_GATE_COST_LEAST`; `_ai_dispel_wanted`), and
what a spell left counts for more the deeper the gate it came through (`_ai_gate_worth`, `AI_DISPEL_PER_GATE`; the designer, 2026-11-12).
**A pack waits only so long** (`_ai_holds_back`, `AI_PACK_WAITS`, `AI_PACK_TOGETHER_TILES`, `comb.held_back`). **A turn after one of theirs**
(`CombatantDefinition.turn_after_one_of_them`, the Mimic's: `_turns_after_one_of_them` at each round's top and before the first, by `rng`, never
the same one twice running). Several are shared out so nobody has two more behind them than another (`_share_out`), and two behind one stay one after
the other with no extra turn between (`_follows`, read by `_spread_turn_queue`).

**Ways of its own** (Combat "Ways of its own"; `ways`; the designer, 2026-11-07). Switches on the creature's AI Mind
group, all per creature and PROPOSAL as to who has what: `ai_commands_tiles` (`_ai_take_orders`, as each begins to
think: a level higher near a commander awake, up to Mastermind), `ai_grudge` (`hurt_by`, from `lose_hp`), `ai_hunter`
(`_ai_pick_a_mark`, `_ai_mark_in_sight`, read by `ai_worth_table` and `_ai_most_wanted`), `ai_guards` and
`ai_guards_within` (`_ai_ward_of`; `_ai_tile_worth`; `_bodyguards_step_in` in `_use_skill`), `ai_pack`
(`_ai_holds_back`), `ai_fears` (`_ai_feared_tiles`, refused through `false_ground_for`), `ai_learns` (`_they_learn_from`
in `_shatter`; `_seen_through` by side, read by `believes_illusion`, `hidden_from`, `ai_worth_table`, False Ground),
`ai_greedy` (`_ai_greed_for`; `steal` sets `fleeing`; it needs a Steal in its skills). `_ai_ways_of_its_own` is first in
`_ai_mind_takes_over`. A mood is `BossPhase.ai_aggression` and the rest, below zero keeping it. **All Knowing**
(`AiSmarts.ALL_KNOWING`, `AiKnows.KITS`): `_ai_read_kit` reads each foe's skill list, so only spells prepared, and
`can_afford_skill`, so only castings left, into `_ai_mind.kits`; used by `ai_target_value` (`_ai_kit_denied_by`,
`_ai_weigh_their_kit`), `_ai_read_the_field` (reach and how much it would hurt, spreading before an area is seen,
Ready's area as a telegraph) and `ai_plan_attack` (gates dearer with a counter ready).

**Light** (`combat/Light.gd`, `LightMap.gd`, `LightView.gd`; `exploration/LightSource.gd`, `AmbientArea.gd`; Combat
"Light", ExplorationScene "Light"; `light`; the designer, 2026-11-06). Levels DARK, DIM, BRIGHT per tile in a
`LightMap`; `Light.gather` reads sources, `relight` from `sync_zones`. A Dark tile is the pseudo-zone `MAP_DARK`:
anybody on it `lost_in_the_dark`, seen only by `sees_in_darkness` or within `SEEN_IN_THE_DARK_TILES` (option A).
`hidden_from` is what to ask with somebody looking. Dim: `_hides_in_dim`, `dim_sight_tiles`. Time of day
(`Campaign.time_of_day`, `Light.Hour`, `set_time_of_day`, `pass_time`) changes during play on a map
(`_light_goes_on`). `StealthWatch` reads the same map (`lights_for_the_map`), a guard's `carries_light_tiles` among
them (`carried_lights_moved`). An illusion can have a say: `BattleObjectDefinition.illusion_stops_light` (Phantom
Wall), and any creature's `light_tiles` and `light_colour`, real or not. `docs/light_on_maps.md` says how to put light on
a map, and stage 9 shows all of it (`tools/build_stealth_stages.gd` `stage_light`, `dialogue/light_stage.dialogue`).

**How light looks** (`LightView`; `clock`; the designer, 2026-11-07). View only: nothing in it rolls or decides, and
a test wanting it sets `plays_headless`. A shade at a pixel a tile, under the figures (`SHADE_SHADER`: drains colour,
crossfades over `EASE_SECONDS`, dithers if `dithered`). Fog over the Dark (`FOG_SHADER`). A `PointLight2D` per
`LightMap.sources` (`_sync_lights`: the same light if near enough, gliding after one carried, easing on and off;
`_energy_of`, lost in what is lit already), embers and dust (`CPUParticles2D`), `_Shaft` from an Opening.
`_build_occluders` makes `LightMap.blocks_light` into `LightOccluder2D`s, only when that has changed. `Grade`
(`GRADE_SHADER`) with `Light.grade_at`, and a `CanvasModulate` with `Light.tone_at`. Godot gives a screen-reading shader
only what was on the screen the first time anything read it, and the shade reads it first: anything later needs
its own `BackBufferCopy` (`_grade_copy`, FightCards' drain). `Projectile` carries a `PointLight2D`, as below.

**Only under the open sky** (LightView section of that name; `daysky`; the designer, 2026-11-12: "outdoor effects like rain shouldn't appear
indoor"). `_mask_the_sky`: a pixel a tile, white under the sky, rebuilt with the light map (`_build_occluders`) and put on only when it has changed.
The mist, the clouds and the aurora read it by their own UV; what falls and floats, the rainbow and the flash by where on the screen they are drawn
(`AIR_SHADER`, `screen_origin` and `screen_extent` told every frame by `_keep_the_air_on_the_screen`: a particle's own place never reaches its shader
in this renderer, so `MODEL_MATRIX` will not do). `FLASH_INDOORS` of a lightning flash shows under a roof.
**Darkness comes on slowly** (LightView section of that name; `clock`, `figures`; the designer, 2026-11-12). `_put_on_the_shade` crossfades the
shade, the fog over the Dark and the figures' darkness from the same two pictures (`CombatantSprite.shade_previous`, `shade_blend`; FOG_SHADER's
`previous`, `blend`), `DARKEN_SECONDS` when anything gets darker; one coming before the last is done starts from `_shade_shown`. The fog stays until
it has faded (`_fog_wanted`). A figure's rim and eyes in the dark and its fading out of sight or back ease over `CombatantSprite.FADE_SECONDS`
(`_rim`, `_shown_alpha`, `_ease_into_the_dark`); `hidden_alpha` is still the rule's, at once, and the first dressing is at once, so nobody who starts
hidden is shown fading away where they stand.

**Light that moves** (LightView section of that name; the designer, 2026-11-13). A flame dances (`FLAME_DANCE_TILES`) and a light out under the
sky sways along the wind (`SWAY_TILES`), through `_light_moves` on each light's `base`; the shadows follow, reading the light's node. Fireflies on
warm nights under a still, dry sky (`_fireflies_wanted`, `_set_fireflies`, an additive copy of AIR_SHADER, `_glow_material`); dust in a window's
shaft (`_Shaft._keep_the_motes`). **After a fight** (Combat section of that name): won, `combat_finish` awaits `_after_the_fight` before the
closing card - dust settling over the field, smoke from fire on the ground and from whoever burned (`AFTER_SECONDS`, `_world_at`); view only.
**The wind's way, seen** (the designer, 2026-11-13: "the particles and fog flow towards the wind direction", no arrow): sand and the wind's
streaks go along `Campaign.wind_now`, from upwind (`_wind_way`, `_keep_the_air_on_the_screen`), rain and snow lean its way (`_wind_lean`),
the clouds and mist drift with it (SKY_LAYER_SHADER `drift`); the clock face's tooltip says it in words (`ClockFace.wind_said`). A lightning
flash keeps covering the view while it moves (`_keep_the_grade_on_the_screen`). The heat's shimmer is held to the ground, slow and in patches
(GRADE_SHADER's `world`), and comes from morning to evening (`Light.HEAT_BY_NIGHT`, `HEAT_LOW_SUN`). A fog a scene holds stays all day
(`Light.sky`'s `held`, from `Campaign.weather_held`) and is a veil, not only wisps; a day's own still lifts by ten.
**More to look at** (LightView section of that name; the designer, 2026-11-13, proposals 21: "I like all the new suggestions you can do them";
suite `atmos`; view only, placeholders, numbers PROPOSAL). Lights mirrored in the ground's own puddles after rain and in water (`_Reflections`,
REFLECTION_SHADER, drawn over the dark, under the figures); blossom, leaves or a summer gale's green ones on the wind (`_leaves_wanted`,
`_set_leaves`, slots `art/fx/petal.png`, `leaf.png`); birds' shadows by day, now and then (`_Birds`, `_birds_wanted`, `birds_now`, slot
`art/fx/bird_shadow.png`); a flame under the sky smokes, leaning with the wind (`ChimneySmoke.make_smoke` and `lean`); a glow round each
light after dark (`_add_bloom`, `BLOOM`, by `_dark_round`) and the view's edges darker after dusk (GRADE_SHADER's `vignette`, `_night_share`,
`_grade_wanted`); low mist in sheltered ground and by water at night, thinning as the sun climbs (`_ground_mist_wanted`, GROUND_MIST_SHADER,
`_ground_mist_mask`); far flashes with no thunder on a close summer night before a storm (`_far_lightning_wanted`, `STORMY`,
`far_lightning_now`, FAR_FLASH_SHADER); at dawn and dusk, now and then, the light's edges and the open sky stepping into pixels for a moment
(`_pixels_due`, `sky_pixels_now`, the shaders' `pixels`). Nothing in it rolls from `Combat.rng`. **On maps:** `WaterPatch` (water: a size in
tiles, a colour, foam or not; drawn by the view under the dark, `_gather_the_water`, WATER_SHADER: ripples with the wind, foam where it meets
land, rain's rings, the sun's glint on its side at the hour; only to look at, Blocks still decides walking), `WindBanner` (a banner, a pennant
or a washing line streaming the wind's way) and `ChimneySmoke`, both darkened with the night through `LightView.lit_colour_at`. The Light
stage's yard has one of each (`tools/build_stealth_stages.gd`, sign "SignWater").

**How light falls on a figure, and what is on them** (`CombatantSprite`, `combat/ConditionLook.gd`; `figures`; the designer, 2026-11-07, sections
9 and 10 of `docs/proposals_2026-11-07.md`). View only, with no icons over the head: the designer looked at an example and preferred
without. `FIGURE_SHADER`, one material per figure, set each frame by `_fall_of_light` from `light_points` (`{"at", "reach", "colour",
"node", "energy"}`, told by `LightView._tell_the_shadows`): their colour from the nearest lights, the lit edge and the far side, lit from
below by a fire or above by the sun, back lit, half in the dark by reading the shade's own picture (`shade_map`, `shade_rect`), and a
rim in the Dark (`set_in_the_dark`, `_Eyes`). `_Shadow` is a patch at the feet; its child `_Casting` lays the frame they show along the
ground away from each of the `MOST_SHADOWS` strongest lights, through `SHADOW_SHADER` (blurrier further off), or from the sun with
`Light.shadow_at`'s lean, length and colour, stopped by `stops_shadow`. A flier's is smaller and further off (`off_ground`).
`CombatantSprite.forget_the_light` at each new place. Nothing in FIGURE_SHADER reads the drawing's own edges any more: reading a few pixels aside
turned every line inside a picture into a second, shifted outline (the designer, 2026-11-07: smeared parts, "part of his outline inside of his scarf").
Light falls on a smooth rounded body instead (`across`, `down`, `n`), more so when `GameSettings.figure_shapes` (`FigureShapesToggle` in both Options;
the designer's "normal maps without extra art", to try), by the light's height (`light_height`); a highlight where `shine_mask_for` finds a mask beside
the frame (`shine_path_for`: `_shine` for `_color`; red how shiny, green how like metal; `docs/shine_masks.md`) and where they are `wet`. What is on them: `ConditionDefinition`'s "On The Figure" group (`figure_tint`, `round_them`,
`off_them`, `figure_priority`, `figure_pose`, `arrival_word`, slots for pictures), `Combat._show_conditions_on_figures` from
`update_combatants`, `ConditionLook.choose_from` (one at a time, the strongest, equals taking turns), a ring under the feet, a pose
that falls back to idle (`set_pose`, `play_idle`). `CController._draw_tether` draws a thread to what a tether holds
(`Combat.what_a_tether_holds`).

**The board without its squares** (`CController` section of that name, `control/SoftAreas.gd`, `maps/grid_overlay.gd`; `hudlook`; the designer's
"A" of 2026-11-07, section 13). The rules stay on tiles. `_draw_area` hands everything to two `SoftAreas` under the controller's own
drawing: a mask with a pixel a tile, read by a linear filter, so what shows covers just those tiles with rounded corners; a pattern
(`SoftAreas.Pattern`: stripes for danger and a blast, crosses for help) so colour isn't alone. `_walk_reach_now` is one outline of how far
they can walk, `_draw_walk_path` a curve of dots (solid while there is movement for it, hollow past that), `_walk_the_step` walks on
`_walk_curve` through the tiles, arriving on each. Headless or catching up: the straight line. `_fade_the_grid`: the lines show near the
pointer while moving or aiming, and not at all otherwise, unless `GameSettings.grid_always` (`combat_ui._grid_button`). `_draw_health`: a
bar under anybody hurt or pointed at, or all while the danger key is held. None of the soft board is made headless without `LightView.plays_headless`.

**The fight's interface, the picks of 2026-11-07** (`ui/combat_ui.gd`, `hudlook`; section 11). `GateTag`: a shape per gate (`shape_of`), `compact`
past `GATES_NAMED_IN_FULL` gates, the row an `HFlowContainer` whose foot stays over the tabs (`_seat_gate_row`). `ConditionStrip`: turns left on the
mark, `ConditionDefinition.mark_picture` in place of the placeholder and its letters. The grid hides empty slots (`_empty_action`, `_fill_action`);
`_turn_block` behind Ready, Go Prone, Undo and End Turn. `_refresh_round_mark` over the queue; `light_face_of`, from `CController._note_hover`.
`_by_side`: yellow and red in the log go by who a name is, in the one place the log is written. A wall has one line each way
(`_quiet_summons`, `_wall_said_gone`). On a map `_tuck_moves_panel`: the moves panel only while the pointer is low, the key says (`moves_panel`, M) or
a pad is in use, which has no pointer to bring it up. `apply_ui_scale`, from `GameSettings.ui_scale` and `UiScalePicker` in both Options: each part
keeps to its corner and the log narrows at the biggest; conversations and menus keep their size.
`Projectile` carries a `PointLight2D` (`light_tiles_of`, `SkillDefinition.projectile_light_tiles`), and flares on landing.

**Spells that make light** (`lightspells`; the designer, 2026-11-07). A dark zone (Light Void) is dark whatever lights it, in
`relight`, but for a zone with `zone_beats_darkness` (Daylight), which wins tile by tile while it lies there
(`_won_from_the_dark`, read by `relight`, `_zone_holds`, `zone_tiles`). Daylight aimed at somebody of her side is on their
weapon (`zone_on_a_weapon`, `follows_id`). Dancing Lights: `zone_lights`, `zone_light_points`, `zone_moved_by` (its own secondary,
`move_lights`; `movable_zone_of(comb, skill)`), no tether. Flare took Unveil's place on Prometheus and in the book: UNVEIL and a
`zone_bare` light, and on a map `Use.FLARE`, `ExplorationScene.flare_up`, `Net.flare_there`. Votive Flame's Marked by Flame:
`cannot_hide` (`set_hidden`, `make_invisible`, `_fade_into_the_dark`, `_invisibility_refusal`), `dispellable` (`spell_gate` 0).

**Darkness is cover** (Combat section of that name, `StealthWatch._dark_between`; `light`; the designer, 2026-11-07: "creatures can
go through it but cannot see in or behind it, except if they have a passive like cyrus does"). In it is "In the dark"; behind it: a line
across a Dark tile is one nobody sees along but whoever sees in the dark (`dark_between`, `_behind_the_dark`, asked by `hidden_from` for
anybody at all, and by `is_seen_by_opponents`). The tiles right round the viewer (`SEEN_IN_THE_DARK_TILES`; a guard's `dark_sight_tiles`)
and the target's own don't count. Marked by Flame and Calling Out see past it. The player is shown the other side's people the dark keeps
from every one of the party (`_dark_keeps_from_party`, in `unseen_by_party` and `dress_for_hiding`); walls alone hide nobody, as ever. On a
map it cuts a guard's `_seen` (`_sees_in_the_dark` by his creature's passives). Only sight: walking, and an area at the ground, go on.
**Night Hunter** (Cyrus's from 24; the designer's E, 2026-11-12): felling somebody from hiding on his own turn (`hidden_as_it_began`, set at the top of
`_use_skill`; `felled_from_hiding`, from `_after_felling`), he slips out of sight again after the reveal (`_slips_away`:
`PassiveDefinition.slips_away_after_felling`), even while watched, once a turn (`slipped_away`, cleared as his turn begins); hiding's other rules
stand. `stealth` covers it.

**The round of 2026-11-12** (the designer's messages of that day). Cones go eight ways: on a diagonal the quarter between the two
straight ways (`get_cone_tiles`, `get_octant_direction`; `blast`). The ground one can walk to is drawn quieter (`CController.MOVE_FILL`,
`MOVE_EDGE`, `MOVE_EDGE_WIDTH`). The first time the sheet shows a kind studied, it reveals it (CharacterSheet "A new kind, studied":
`_maybe_reveal`, `_reveal`, `_reveal_over_the_panel`, `_finish_reveal` on any press; `Campaign.sheets_revealed`, saved; SoundBank
"codex_reveal"; `reveals_headless`; `sheet`). `docs/sound_slots.md` lists every sound slot and what fills it (made by a script over the
data). Alithia's changed-future lines are the designer's own; the Gun has the torch from afar for now.

**Section 17's answers** (`beckon`; the designer, 2026-11-07). Beckoning Light, Alithia's (Hermes; Iris on a map): `SkillDefinition.beckons`
aims it twice (`CController.aimed_twice`, the second click any open ground in reach), `_beckoned_to` makes Drawn To Aim go there, and a ZONE with
`zone_at_destination` lights it; `ConditionDefinition.on_arrival` puts Off Guard on once they have walked (`_go_and_look`). On a map
`OutsideMoves.Use.BECKON` -> `StealthWatch.beckon`. Kindled Faith: `PassiveDefinition.mends_in_bright` and `_per_stat`,
`_kindled_at_turn_start`. In place of Lifted Torch: `SkillDefinition.snuffs_carried_lights` (on the Gun for now, the designer, 2026-11-07) in `OutsideMoves.fire_at`,
`StealthWatch.snuff_torch` (`Guard.torch_out`, `Mood.RELIGHTING` to the nearest lit lamp, `_torch_lit_again`; "torch" in `net_state`).

**The clock and the calendar** (Campaign "The clock and the calendar", `campaign/CalendarDefinition.gd`,
`data/calendar.tres`, `ui/clock_face.gd`, `ui/time_passing.gd`; `clock`; the designer, 2026-11-07).
`calendar_minutes`, saved, is the one number. `time_of_day` follows it (`Light.hour_at`), and `clock_to` is the only
way it moves, never backwards, saying `clock_moved` always and `time_of_day_changed` when the part changes. For a
conversation: `advance_clock`, `set_clock`, `set_time_of_day`, `watch_time_pass` (a coroutine; `time_passing` holds
everybody; `Net.time_passes` shows it on the joiner). A long rest ends at the next dawn; a short rest takes
`SHORT_REST_HOURS` (PROPOSAL). Light's rule only changes with the part of the day; how it looks goes by the minute.
**The calendar to look at** (`ui/calendar_panel.gd`, loaded by path, no class_name; `clock`; the designer, 2026-11-12): `do Campaign.open_calendar()`
(or `"weathers"`) waits for it to close: a month of days with the date, the weather drawn (`_Glyph`, a slot `art/ui/weather/<weather>.png`) and
the moon's phase; a day pressed says what its weather does (`WEATHER_SAYS`) and a day to come can be gone to; every weather to have now
(`Campaign.set_weather` for `HELD_DAYS`, so going round the hours keeps it); `Campaign.tour_the_weathers` (the panel's static `tour`, `TOUR_SECONDS`, its
caption "WeatherTour", any press stopping it, the sky as it was after). The light stage's sundial offers all of it.

**The sky** (`Light.sky`, Campaign "The day's own sky", `LightView._show_the_sky`; `daysky`; the designer's picks of 2026-11-07, section 14). `Light.SKY` is about
thirteen marks with a Hermite curve through them (`_curve`); tone, lean, strength, softness, saturation, contrast and how lit it looks all come from
`sky(ambient, minute, day, weather, place, moon, shift)`, and `Campaign.sky_now` fills in today. Nothing rolls: `day_share` works from the day number. `weather_of`, each
day's sky, or `do Campaign.set_weather("storm")`; `Light.WEATHERS` says what each does. Each day's sunrise and sunset lean by `DAY_SKIES`. `moon_phase`: full on day 1,
`MOON_DAYS` round. **Two rule changes:** a new moon is No Moon (`no_moon_now`, in place of reading `map_no_moon`, not changing in the middle of a night; `do Campaign.set_moon("full")`), and
the month moves when dawn and dusk begin (`season_shift`, in steps, 0 for the first week; `hour_at(minute, shift)`, `hour_start`). `LightView`: `_how_lit_it_looks`, the shade by the minute for
tiles `LightMap.under_the_sky`, the rule's levels unchanged; clouds' shadows and mist (`SKY_LAYER_SHADER`), rain, dust and insects (`_set_rain`, `_set_life`), a sound per hour
(`_set_day_sound`, SoundBank's "The day"); an opening's light takes the sky's colour. `MapSetup.sky_tint` is a place's own sky. `LightSource.by_the_clock` and `Lamp.by_the_clock` come on around dusk and go
out around dawn, each at its own minute by where it stands (`Light.lamp_lit_at`; `ExplorationScene._keep_lights_by_the_clock`, `StealthWatch.keep_lamps_by_the_clock`, only when they would change).
**More weathers, eased** (section 17 and the designer's messages of 2026-11-07; `daysky`). Snow, sleet, thunderstorm, wind, sandstorm, blizzard, heat, ash, aurora, rainbow
and eclipse in `Light.WEATHERS`, each with its `SKY_EXTRAS` (every `sky()` has all of them); `weather_of(day, days_in_a_year)` goes by `season_of` and `SEASON_ODDS`, and
`SCENE_WEATHERS` come only by `set_weather`; `Campaign.days_in_a_year`, `season_now`. Some of it is a rule now: below. LightView: `show_hour` wants a sky and `_ease_the_sky` gets
there over `sky_ease_seconds` (0 for a test that wants it at once), the shade over `SKY_SHADE_SECONDS`; `_put_on_the_sky` sets the tone, the grade (with `shimmer`), the
sun's shadows and `CombatantSprite.soaking`; `_set_falling` (snow, hail, sand, ash, the wind's gusts), `AURORA_SHADER`, `RAINBOW_SHADER` (on the screen, as the grade),
`_storm` (a flash, then SoundBank "thunder"). Callers ask `show_hour` each minute without `at_once`, and only set the shadows themselves with no view. Figures soak
(`CombatantSprite.wetness`, `_soak`: `SOAKED_SECONDS`, `DRY_SECONDS`, under the sky by `under_the_sky`). Steps: `audio/Footsteps.gd` (`step`, from
`ExplorationParty._step` every `STRIDE_TILES` and `CController._begin_step`), louder and splashing where `LightView.rainy_at`; SoundBank "Steps", PlaceholderSounds
"step" and "step_wet" meanwhile. `docs/proposals_2026-11-07.md` section 18 has the designer's choices of 2026-11-12.

**What the weather does** (Light "What the weather does", Combat "Weather", StealthWatch "The weather"; `weather`; the designer, 2026-11-12).
All from the sky at the minute and what lies on the ground, alike on both machines: `Light.ground(minute, today, yesterday, season)`
(wet, snow, frost, ash, sand), `lying_on` (the lee of walls), `wind_way(day)`, `thick`, `hot`, `cold`, `rain_loudness`; `Campaign.weather_on(day)`
(`weather_fixed.from_day`), `ground_now`, `wind_now`. Indoors and underground, none. In a fight (`_begin_weather`, from `_begin_light`: `weather`,
`lying`, `wind`, `_deep_snow`): `_wind_reach` for what `wind_carries` in `get_range_tiles`, `is_effectively_in_range`, `targets_if_aimed`,
`_use_skill`'s validity, `_spot_to_hit_from`, `_ai_best_aim_from` and the danger view (`_aim_points`' `windless_reach`); `_blown_by_the_wind` after
`apply_drift`; `land` / `take_off` (`comb.landed`, kept by `resync_movement_class`; `CController.toggle_flight`, `change_flight`; the "land" fight
move; `combat_ui._flight_button`; the AI's `_ai_consider_landing`); `_snow_costs_double` in `hem_cost`; `LIGHTNING_HAZARD`
(`data/hazards/lightning.tres`; `HazardDefinition.Aim.HIGH_AND_METAL`, `damage_by_level`, `flashes`; `_lightning_strikes`, `_hazard_damage`,
`LightView.lightning_now`; `CombatantDefinition.draws_lightning`); `SOAKED` (`_rain_on`, `ConditionDefinition`'s Weather group:
`damage_taken_of` in `resisted_damage`, `lengthens`, `longer_in_heat`, `longer_in_cold` through `_weather_lengthens` in `condition_turns` and
`put_condition`); `_zone_burns` in `_zones_at_turn_start`; `thick_weather` in `_hides_in_dim`, so whoever is within `DIM_SPOT_TILES` still sees them. On a map: `_rain_hearing` on
`notices_walking`, the dash and noisy ground; prints (`step_taken` from `_age_prints`, which watches the leader's walk; an oddity "prints",
never putting the map up); `_thick_now` cutting `_seen` past `dim_sight_tiles`.
**The weather on the ground and on the creatures** (LightView "The weather on the ground", CombatantSprite "The weather on the creatures";
view only). `WET_SHADER` (multiplied) and `GROUND_SHADER` over open ground under the shade, from `_ground_mask` (red open, green snow, blue
sand); `_Prints` (`leave_print`) and `splash`, from `Footsteps.step`. On a figure: `snow_on`, `ash_on`, `dust`, `cold_on`, `heat_on` into
`FIGURE_SHADER`, cloth by the shine mask's blue in the wind (`wind_blows`), drips, steam by a fire (`_by_a_fire`), breath, and
`weather_pose` (shiver, shield_eyes, hunch) under any condition's pose in `play_idle`.

**Sounds** (`audio/GameSounds.gd`, `audio/SoundBank.gd`, `audio/sound_bank.tres`; `audio`; `docs/sound_plan.md`).
Everything that is not a move's or a condition's own is a slot in the bank: `GameSounds.play(slot)`, `loop`,
`play_slice`. `GameSounds.listen` makes every button click, unless `quiet`. The wavs are kept off GitHub
(`tools/place_sfx.ps1`, `tools/sfx_list.txt`), and `SkillDatabase` first turns off aborting on a missing
resource, so a clone without them loads silent.

**Preparing spells** (Campaign "Preparing spells", `ui/prepare_spells.gd`,
`Stats.spells_prepared_at`; the designer, 2026-11-05): 5 at level 1 to 35 at 64, a straight
line. `prepared_spells`, `locked_spells`, `last_prepared`, `spells_readied`, `prepare_due` are
saved, and all but `prepare_due` (the host's to say) in `Net.MENU_KEYS`. No list yet means everything known, so nothing changes until
they are first asked; and until they have been asked after a long rest, `is_prepared` lets what
they had stand, so nobody loses a spell to a window they never saw (a rest right before a fight).
`long_rest` keeps only what is locked (`_rest_prepared`); a dungeon with
`prepares_spells` (the Dungeon Demo) asks as it starts. The map opens `PrepareSpells` when
`prepare_due` and `asks_to_prepare` (off in the harness, with `asks_for_paths`). Each machine
shows only its own player's casters; with none left it waits, naming who for, no longer a menu
(`MenuPause.release`, `_root_own_groups`) so the other machine's changes arrive, and
`Net.send_menu_changes` sends each finished list at once. `forget_unprepared` in
`_deploy_party`; `OutsideMoves.moves_of`, `outside_spells`; the sheet's fourth page "Prepared"
(`has_readied`, `_show_prepared`) and "not prepared" and "locked" badges. `preparespells`. A spell a passive gives castings of its own
for (Devotion: Heal, Dread Visage) is always prepared and not chosen (`Campaign.always_prepared`, in `is_prepared` and `prepare_choices`;
the designer, 2026-11-12), and so is a path's own spell once the path is theirs (`spares_prepared`, `path_spells_prepared`; `always_prepared_said`
for the window's note and the sheet's Prepared page). None of them counts among those chosen. The window's tooltips are the fight's own (`combat_ui.details_of`, which works with no fight on, the numbers by
`_base_damage_with_no_fight`); so is the sheet's on a map (`_preview_of`).

**What opens and closes a fight** (`combat/FightCards.gd`; EncounterDefinition's and
BossDefinition's "Title cards"; the designer, 2026-11-05). `opening` from `Combat._ready`
before deployment, `closing` from `combat_finish` before `combat_finished`; `Combat.cards_playing`
holds `Net._play_moves` back. Boss Reveal is a switch per encounter (ticked on `boss_*`): bars,
silhouette, sting, entrance or roar, portrait (`BossDefinition.reveal_portrait`) and plate,
shorter once flagged `reveal_seen:`. Then the screen freezes and shatters and the words slam in.
Any press skips. Nothing is rolled; not while `Net.catching_up`; headless only with
`FightCards.plays_headless`. `CombatantDefinition.entrance_style` (`FightCards.entrance`, from
`_show_arrivals`, with `plate`). `SpawnDefinition.warned_by_flag` and `warned_by_reading`:
`arrival_warnings`, drawn a turn ahead. **Falling**: `Combat._falls` -> `MoveFeel.falls` (flash,
`camera.punch_in`, `CombatantSprite.fall`, by `comb.last_hurt`; a "dead_<element>" animation is
the slot); one of the party: `slow_motion`, a crack across the portrait, `FightCards.fallen`, and
last words only if written (`EncounterDefinition.last_words`, `CombatantDefinition.last_words`).
`fightcards` covers it.

**How moves are felt** (`combat/MoveFeel.gd`; `docs/move_feel_proposals.md`, built
2026-10-31 but for moves coming down from above or up from below, which the
designer did not want). All of it is placeholder art and sound behind slots - the
designer makes the real ones - and none of it rolls on `Combat.rng` (MoveFeel's
scatter has a generator of its own, seeded from where it is) or changes the fight;
headless nothing is made (`MoveFeel.plays_headless`), nor while catching up
(`MoveFeel.shown`). Each move's looks are SkillDefinition's Projectile group
(enums appended - never insert): `projectile_look` (`ProjectileLook`: what flies,
drawn in `Projectile._draw_head` - tracer, dart, rock, chain, jet...), `hand_look`
(`HandLook`, `MoveFeel.hand` at release: Automatic is a glyph for a spell, a swish
for something thrown, a muzzle for another shot, nothing for melee),
`impact_look` (`ImpactLook`, `MoveFeel.impact` on each it lands on, or
`over_area` once for an area look - `looks_over_area`; Automatic: a column for a
mend, a wash for a dispel, a rise for a revive, a swoosh for a damaging blow,
ignoring what a move does to its own user) and `ground_mark` (`GroundMark`,
`mark_ground`, two rounds - `MARK_ROUNDS`; Automatic by element). ProjectileStyle
gains BEAM, SPRAY (a roar - `hand_look` ROAR - pours rings) and BACK_TO_USER.
Sounds in three: `sound` is the launch (played as before; while empty
`MoveFeel.hand` plays a stand-in), `travel_sound` and `impact_sound`; stand-ins
are `PlaceholderSounds` recipes ("launch_*", "travel*", "impact_<element>",
miss, graze, shatter, thud), pitched by `MoveFeel.pitch_for` (round and who,
never rolled; `Combat.play_stream`'s `pitch`). A blow's verdict goes to what flew
(`Projectile.verdict` - HIT, MISSED flies on past, GRAZED bursts dimly, IMAGE
shatters - for a `judged` one, a blow at one alone; `settle` after the targets
loop): told in `_use_skill`'s loop and `_land_reaction`; a move that flew nothing
lands through `MoveFeel.impact(..., flown = false)` (its burst and sound) and
`missed`. Combat's other hooks: `show_damage` (`hit_stop_for` - none under
`HIT_STOP_FROM`, a beat from `HEAVY_SHARE`, `HIT_STOP_KILL`; `shake_for`;
`slow_motion` for a boss or `_last_standing`, given back by `_time_after_stop`;
the number's `how` - share, `_grazing`, resisted, vulnerable - for
`FloatingNumber.spawn`), `flash_target` (a single blow `recoil(line, single)`:
further, and `squash`, for a blow from the other side only), the CONDITION branch (`condition_put` flies the mark to
`combat_ui.condition_point`), `do_heal` (`mended`; the bars' own
`HealthBarMarks.fill`), `_fire_readied` (`readied_line`), `use_reactive_skill` and
`_fire_readied` (`exclaim`: a "!" and the face card), `declare` (`declared`
glyphs, gone with `comb.declared`), a landing (`DECLARED_SHAKE`,
`DECLARED_HIT_STOP`), `stagger` (`staggered` -> `combat_ui.crack_stagger_bar`,
and `slow_motion`), `_hit_part` (`part_struck`), `lay_zone` (`zone_spreads`;
`spreading_zones` and `_spread_so_far` make `zone_tiles` grow from `_landing_at`),
`apply_knockback` (`dust` per tile slid, `thud` into anything solid), CASTER and
TARGET teleports (`puff`s), `summon` (`bound_out`, or `shards_gather` for an image),
`summon_decoy` and `_shatter`, `steal` and `loot` (`item_flies`), `_hurl` (`thrown`:
`CombatantSprite.fly_in`), `_hack_in_fight` (a CODE projectile, `code_scatter`).
Marks and declared glyphs go under everybody (`on_the_ground`: first child of the
map). Screen-wide flashes and faces are on `MoveFeelOverlay` (layer 20). The hurt
vignette's flare runs on real time (`HurtVignette.flare`), so a hit-stop - a kill's
longest - does not hold it back.

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

**Find Familiar** (the designer 2026-10-26 and 29): a skill with an
EffectType.FAMILIAR effect is `outside_only` - `Combat.fighting_skills` keeps it
out of every kit in a fight. It works on any map: `ExplorationScene.familiar_keeper`
(`exploration/FamiliarKeeper.gd`) calls, steers, perches and lets it go, and on a
watched map StealthWatch "Familiar" adds what guards make of it (its `familiar`,
`controlling` and `familiar_caster` read the keeper). Paid through
`FamiliarKeeper.pay`: the first since a long rest free (`Campaign.free_familiar_used`,
saved, cleared by `long_rest`), then `Campaign.spend_gate_outside` (a real gate,
off the next fight). The `Familiar` (exploration/Familiar.gd) takes the
StealthSetup's `familiar_form`, else the MapSetup's, else the rat (`FamiliarForm`,
data/familiars/). Steering roots the party (`keep_party_rooted`) and moves the
camera; the `familiar` action toggles it (R; a pad's is L3, the Outside Spell
button, heard first while one is out - the designer, 2026-10-31: Tab,
`swap_leader`, is who leads, always, and does nothing while seeing through its
eyes), its `interact` while steering
is `perch` (onto the caster's shoulder, `Familiar.perched_on`, riding along -
`FamiliarKeeper.keep_perched` puts it on the caster's new figure whenever the
party is drawn again, from `_keep_stayers`), and
StealthWatch's clicks wait while it is steered. It walks by `ExplorationScene.is_walkable_for` (small gaps -
Blocks 4, `set_small_gap` - for Small and smaller; fliers by Blocks 1).
`_watch_familiar` fills `familiar_doubt` per guard by `feels_familiar` (eyes
within Noticed Within, a dog's nose, a sensor's Sense Tiles; civilians never);
`_familiar_found` dismisses it. `Guard.Kind.SENSOR` (appended) feels only magic:
`can_perceive` is `unseen` for it, `_refresh_seen` is its radius, it never moves
or fights. It is cast from the Spells tab only, as the other spells are (the
designer, 2026-10-31: "Casting the familiar shouldn't have its own key"): G -
`StealthBar.outside_spell` on a watched map, `ExplorationScene.outside_spell`
elsewhere, `ui/outside_spell_choice.gd` asking which - only lets it go while it
is out, and the stealth bar's `_familiar` button shows only then, to let it go.
The tab's tooltip (`OutsideMovesPanel._freshen`) says the first since a long
rest is free and how to go to it. `familiar` and `outside` cover it. It hides on
the same spots Cyrus does - a guard feels it there only from within `REACH_TILES`
(`feels_familiar`, `_watch_familiar`) - and what it truly sees is drawn while it
is steered: every tile its `sight.clear` says it cannot see is dimmed, out to
`REACH` tiles (`FamiliarKeeper._show_sight`, `_Sight`; the designer, 2026-11-04).

**Stealth mode** (StealthWatch "Stealth mode"; the designer, 2026-11-04 and 05: "Make
only Cyrus and the familiar able to go to stealth mode, or any invisible ally").
Only someone with `CombatantDefinition.stealths` (Cyrus) creeping, and anybody
invisible, are `stealthing`, and the familiar has its own rules: a guard who cannot
see them does not notice them. Anybody else walking within `WALKING_NOTICED_TILES`
of a guard, walls or no walls, is noticed as if seen (`notices_walking`,
`_walking_now`), and so is Cyrus when not creeping; standing still, nobody is. Creep
is a toggle (Ctrl or the bar's button: `toggle_creep`, `_creep_on` by player; a
light push of a pad's stick creeps while it lasts), only for a group with somebody
who can (`_can_creep`, `can_creep_here`; the bar's button greys otherwise), and only
those stealthing are drawn half-there (`_dress_the_party`). `openly` covers it.

**Moves outside a fight** (`exploration/OutsideMoves.gd`, docs/outside_combat_plan.md
Phase 1, the designer 2026-10-26): `moves_of(key)` is everything somebody has on a
map; `use_of` reads what a move does out there off its effects (Mend, Revive,
Speed, Invisibility, Familiar; NONE greys it; a damaging move is Ambush); `refusal` / `use` are the one place both the panel
and G ask. **Aimed on a map** (OutsideMoves "Aimed on a map", `exploration/MapAim.gd`; `aimed`; the designer,
2026-11-07): `use` of an Ambush or a Trap only takes aim (`ExplorationScene.take_aim`); `fire_at` lets it go (`aim_refusal`,
`in_reach`, `struck_at`). Anybody who fights caught: `StealthWatch.strike`, with "aim_offset" in the opener and
"struck_first" on every spawn it caught, all of whom take it before the first turn, wherever the fight puts them. A
placed fight's marker caught: `open_fight_with`. Otherwise spent there: a wall comes down with no fight, its noise
bringing whoever hears. A trap that bursts (`Trap.bursts`) calls `trap_goes_off`, and the opener is marked "trap"
(`_spring_the_trap_from_the_map`), paid for already. Spells pay `pay`: Iris first for a spell marked
`SkillDefinition.out_of_combat` no deeper than Iris's match (`iris_gate_for`;
`Campaign.outside_gates_most` opens Iris for them), then a real casting through
its gate or deeper; Find Familiar exactly its own. `noise` (`Loudness`, appended)
and `noise_tiles` are heard through `sound` -> `StealthWatch.make_noise`; shown
only out of a fight (the panel, the sheet's Moves page on a map,
`noise_fact`). `SkillDefinition.outside_use` (appended enum; Automatic reads
`use_of` off the effects, a damaging move being Ambush) sets the rest, per
docs/outside_combat_plan.md's table: Blind / Scare / Confuse put a guard in a
`Guard.SPELLBOUND` mood (appended, errands, ABSORBED, `sees_nothing`) via
`StealthWatch.spellbind`; Read is `learn_route`; Switch Off Magic is
`Guard.switch_off` (`still`); targets are `StealthWatch.move_target` (the hovered
guard, else the nearest in the move's reach, Manhattan, clear line for one that
respects blocking). Ambush: `ambush_with` sets `_opener`, `build_fight` writes the
encounter's "opener" meta and the guard spawn's "opened_on", and Combat "An
ambush's opening blow" (`opener_due`, `_open_the_ambush`, from `start_first_turn`)
uses it free before the first turn - but a spell pays its gate there as any
casting does (`_pay_for_cast`), and with no casting of its gate or deeper left
for the fight it cannot be struck at all (`OutsideMoves.cannot_open_with`, in
`refusal`, `StealthWatch.ready_refusal` and `fire_readied`; the designer,
2026-10-31: "if it is a spell that costs a gate, then the gate is used like
normal"). On any map, with no guard to spring on, a
placed fight in reach - an `EncounterInteractable` standing
(`ExplorationScene.fight_in_reach`) - is started with it (`open_fight_with`, on
a copy of the encounter; the designer, 2026-10-31: start a combat by hitting
someone): its opener is "anywhere", and lands on the foe nearest whoever struck
(`_nearest_foe_of`) however far apart the fight puts them, through
`use_skill(..., landing)` once `refusal_for` allows it; `leave_for_battle` off
keeps a test on the map. With no guard and no fight, a `BreakableWall`
(exploration/BreakableWall.gd, flag `broken:`) in reach is `break_wall` - only by a
spell, an item (`items_of`, the panel's Items tab) or somebody with
`CombatantDefinition.breaks_walls` (Enfina): `OutsideMoves.breaks_walls`, and in a
fight `Combat.breaks_wall` for a `BattleObjectDefinition.wall` (data/objects/breakable_wall.tres;
`build_fight` brings standing walls along with a "wall_flag", which `_object_gone`
sets). InstaHack's Outside Use is Counter Trap: a `MagicTrap` (exploration/MagicTrap.gd)
stepped on (`ExplorationScene._watch_traps`, `spring_trap`) is answered by
`trap_answer` through `QuickTime.run`, else the laser (`_laser`). Run's is None. Blink is
`ExplorationScene.blink`, Fly `fly` (`is_walkable` by flier blocking while
`flying()`, down only over open ground), Lure an `OutsideMoves.Decoy` and
`make_noise`, Hiding Spot `StealthWatch.add_hiding_spot`, Trap an
`OutsideMoves.Trap` (`caught_in_trap`). The panel is `ui/outside_moves_panel.gd`, put in the action bar
by `combat_ui.show_outside_moves`. Its Spells tab is the fight's Spells panel (the
designer, 2026-10-31): `SpellShelves`, a shelf per gate with a `GateTag` at its
start, and first a shelf per Gate of Iris (`build(..., iris)`; `_iris_of`: a
spell's own `outside_gate`, Invisibility's, or the one `iris_gate_for` pays
first; `GateTag.show_iris`) - only gates with a spell on show, so Out Of Combat
Only drops the empty ones; `show_counts` keeps the tags' castings current, and
the counters beside the tabs (GateTags, Iris among them) stand down while the
shelves are up, as in a fight. Invisibility is only there (and G's): the stealth
bar's button for it is gone, and the panel greys it only when nobody at all
could be hidden - its picker chooses who. G is `StealthBar.outside_spell` on a watched
map and `ExplorationScene.outside_spell` elsewhere (`ui/outside_spell_choice.gd`);
it casts Invisibility and the spells to some purpose now, never Find Familiar.
Hurry is `ExplorationScene.hurry` and `ExplorationParty.hurry` (apart from
`pace`). Hide UI (`hide_ui`, U / pad Share) is `ExplorationScene.set_ui_hidden`
-> `combat_ui.set_ui_hidden` (all but the log) and `StealthWatch.set_ui_hidden`
(bar, objectives, prompts). Heals out here use the sheet's arithmetic
(`CharacterSheet.map_entry_of`, `heal_on_the_map`); `Campaign.mend`,
`revive_outside` and `fallen_members` hold the state. **Stay Here** (`stay_here`,
X / pad Touchpad, the panel's Stay; the designer 2026-10-29) is
`ExplorationScene.stay_here`: the leader goes into `ExplorationParty.stayers`
(out of the line, still in `sprite_for` and `_members`, so guards see them and
`build_fight` places them) and `staying` (key -> spot); the next not staying
leads, or nobody does and the leader keeps it, from where they stood with nobody moved
(`_lead_from`, `_places_kept`, `ExplorationParty.keep_places`). `_keep_stayers` puts them back
after every rebuild, `_pick_up_stayers` brings them along when the leader walks
up - only once the lead has been `LEFT_BEHIND_TILES` away (`_left_behind`), since whoever
takes over starts within `PICK_UP_TILES` of them (the designer, 2026-11-05) - and
`swap_leader` goes round past them (`_passing_lead`). **Readied out of
a fight** (OutsideMoves / StealthWatch "Readied, out of a fight"; the panel's
Ready box -> `ui/outside_ready_choice.gd`): what lands on a guard (`READYABLE`),
for a guard stepping into reach, into a cone pointed with a click
(`mark_ready_area`, `ready_cone`: `Combat.READY_CONE_TILES` long, only what
`sight` sees from them), or a chosen guard being hit (`guard_hit`, from `_do_to`,
takedowns, darts and traps). Paid at readying (an ambush's opener in the
fight); `_watch_readied` drops it once whoever readied it loses sight of the
point they marked or the guard, and fires it through `fire_readied`. A standing
`BreakableWall` is a wall on a map in every way - `_shut` for walking, flying
and the familiar, shut to `sight`, solid in `Actors`' routes (guards have no
key to it) until `break_wall` opens it (`Actors.refresh_tile`). `outside` covers it.

`stealthkit` covers the tools (throwing, ears, hiding spots, takedowns,
pockets, alert, dogs, wards, captains, questions, the ghost flag, late
arrivals) on the crossroads map; `alarm`, `ambush`, `stealthworld`,
`guardlife`, `poisons` and `stagecard` the rest; `stages` checks the eight built
test stages are playable (the eighth, The Familiar, has Alithia, a magic sensor,
`SmallGap` grates - exploration/SmallGap.gd, a placed stand-in for Blocks 4 - and
a `BreakableWall`). The stages are generated by `tools/build_stealth_stages.gd`,
which has to run as a scene (`--script` does not load the autoloads its nodes
lean on); rebuild them from a copy of the project and copy `maps/stealth_stages/*.tscn`
back, or run it in place and accept that `maps/stealth_stages/` is overwritten.

## Co-op (two players, one screen)

`Coop` (autoload, `multiplayer/Coop.gd`; docs/multiplayer_plan.md "Where it stands",
the designer 2026-10-29) holds the players - two at most (`MAX_PLAYERS`), each
with a device: the keyboard and mouse (`KEYBOARD`) or a pad. One player is not
co-op (`on()` false) and nothing changes. Who steers whom is
`Campaign.controllers` (saved; `Coop.controller_of`, `keys_of`). `CoopGate`, kept
the last node in the tree so it hears every press first, notes who pressed
(`acting`) and drops it if somebody else has the `focus` (a fight's turn -
`CController.set_controlled_combatant` -> `fight_turn`; a menu - `MenuPause`
-> `menu_held`; a conversation; a reaction's question - `ReactionPrompt._decider`)
or nobody here plays that device. A ping always gets through. While a player has
the focus only their pad drives the pointer (`Pad._vector` / `_held`,
`pointer_device`). `Campaign.living_party()` puts the acting player's characters
first (`Coop.ordered`), so `Campaign.leader()` is theirs while their press is
handled - and on a map `ExplorationScene.party` is a property returning their
group (`_acting_group`). Each player walks their own `ExplorationParty`
(`groups`; the first player's is the party node, `_main_party`): `player` reads
their device (`Coop.direction`), `companions` lets `sprite_for` find everybody
(guards, `build_fight`, conversations), `leash` is `_within_leash`
(`LEASH_TILES`), and `_frame_groups` keeps one camera on all of them
(`COOP_ZOOM_FLOOR`). Holding the party (a conversation, a catch) holds every
group (`all_groups`, `_held_by_another`). The turn banner names whose turn
(`Combat.player_of`). A player steering nobody of the party standing
(`Coop.stranded`) is offered the Players panel (`ui/players_panel.gd`,
`only_party`) to share it out again - once per change (`party_shape`,
`share_out_offered`); the title screen and the pause menu have it too. Alithia's
familiar is steered by one player (`FamiliarKeeper.steerer`, `Familiar.player`;
their group is the one rooted). Its key (R / L3, the `familiar` action) is
`swap_for(acting)`: her player takes it
or gives it back; the other player gives it back, or - while it is off her
shoulder - asks her player for it (`request_control` -> `ui/familiar_request.gd`,
theirs alone to answer). Only her player lets it go (`may_dismiss`).
**The same rules as over a network, on one screen** (the designer, 2026-10-31):
a conversation draws the one camera to whoever began it
(`ExplorationScene._conversation_focus` - `Coop.conversation_starter` while
`Coop.talking()` - and the glide of "The camera in another's conversation"). A
conversation's hold on the focus is `Coop._talks` (a hold each, who began it),
let go at its end or when its balloon leaves the tree without one
(`_watch_balloon` - a scene changed under it once left the first player with
the focus for good, the second's every press dropped). A picture is both
players' (Pictures "Two on one screen"): `shared_here` lets both through the
gate (`Coop.lets_through`) whoever has the focus, the keyboard's player (else
the first) keeps the mouse (`first_pointer`, `Coop.pointer_device`; Pad leaves
alone a pad not its own, `_may_point`), and the other has a pointer of their
own (`second_pointer`, `_second`, `_move_second` by either stick; A at it -
`_second_press`: a hotspot clicked as them, `_as_second` with a hand of their
own, `_second_holding`; a dial turned, LB/RB too; a piece carried,
`_second_piece`, put down on A's release; the bar's buttons; B puts down or goes
back), outlining what it is over (`Hotspot.pointed_by_other`) with their name
and its name beside it; a lens in their hand looks round it.
**Party Management for whoever joins** (the designer, 2026-10-31): in co-op
`Campaign.member_joined` (from `add_member`) sets the map's `_management_due`,
and once nothing else is going on `_manage_party` puts Party Management up
(`open_players(note, true)`) - over a network on the joiner's screen too
(`Net.manage_party_there` -> `_manage_party`). Each character's button is their
portrait over their name, edged in the steering player's colour
(`PlayersPanel._pick`, `PICK_SIZE`). Each player's line is a slot edged in
their colour (`_slot`, "Player%d" > "Line"), and every seat there is
(`Coop.MAX_PLAYERS`) shows: one nobody plays in is dashed ("Open%d"), saying
how to take it - only what is free, the pad's button as printed on the pads
not playing (`how_to_join`, `join_button`), and while hosting that the other
machine's player may (`_say_how_to_join`) ("its a way to show them that it's
up to two players").
**Pings** (`Pings` autoload, `multiplayer/Pings.gd`, action `ping`: Z, and in
co-op a pad's Share - alone, Share is still Hide UI): a ring in the player's
colour where they point (`aim_of`), what is there named (`label_at`), a sound,
a log line, an arrow at the screen's edge; `PING_SECONDS`, `PINGS_EACH`.
`coop` covers it all.

## Network play (two machines)

`docs/multiplayer_plan.md` is the approved plan, built step by step (Steps 0-3
done; 4 and 5 wait on the designer). `Net` (autoload, `multiplayer/Net.gd`, after Coop and Pings)
is Godot's high-level multiplayer over ENet, and every RPC is on it - an
autoload's path is the one node path both machines share. **The host decides**:
it owns Campaign, the scene and the guards; the joiner sends what its player does.
`host(port, bind_ip)` / `join(address)` / `leave()`; `active()`, `is_host()`,
`is_joiner()`, `joined()` (seated). Hosting makes the host's players peer 1
(`Coop.local_peer`), sets `Coop.networked` and sends a beacon (`BEACON`, once a
second, to `beacon_to` on `discovery_port`) that `look_for_games` hears into
`found`; an address typed always works too. The joiner's hello (`PROTOCOL`,
`build_key`, its devices) is checked by `refusal_for` - another version, a full
table - and the host seats one player for the machine (`Coop.join(device, "",
peer)`) and sends the whole table (`_table`: Coop.players, Campaign.controllers)
on every `Coop.players_changed`. **Whom each steers** (the designer, 2026-10-30):
the joiner chooses as it first comes into the host's game, on a map or in a fight
(`ui/character_choice.gd`, `_offer_the_choice` -> `choose_characters` -> `_chose`;
the host keeps at least one; `choosing(id)` keeps the share-out offer off them
meanwhile, and choosing nobody is watching). After that a change is asked of the
other player and made only if they agree: the pause menu's **Party Management**
(the Players panel with `management`; `PlayersPanel.open_over` in a fight) turns
a press into `ask_for`, answered on the other machine in `ui/steer_request.gd`
(`_ask` / `_asked` / `_reply` / `_answered`); the host makes it
(`_change_steering`). The host leads: Kick out on the joiner's row, made sure of,
is `kick` (`_kicked` tells them why, then the line goes). **In a fight** a change
waits for a moment both fights are sure to be at - one of the host's characters'
turns, standing idle (`_steer_when_both_can`), the character whose turn it is only
before anything is done in it (`_turn_fresh`) - and goes with the moves as a
"steer" move (`_note_steering`, which also writes down any change in the middle
of a fight, a joiner leaving included). The joiner's controllers change only by
those during a fight: its `_table` and `_state` keep them
(`_controllers_after_fight`, `_kept_here`). A machine dropping out takes
its player with it (`Coop.leave`: their characters to the other player, mid-fight
too - the designer, 2026-10-29); a joiner left alone is back to its own players
(`_own_devices`). Every call from the other machine is checked for its sender and
its types, and objects never travel: a resource goes as its file or as its
script and stored properties (`resource_to_data` / `data_to_resource`, which
makes nothing but a Resource of a script under `DATA_SCRIPTS`), and `is_plain`
says whether something may go. **The joiner follows the host:**
`SceneTransition.change_scene` asks `Net.may_change_scene` (no on a joiner but
where the host said) and tells `scene_changing`, which sends `_follow(path,
Campaign.net_state())` - so `ExplorationScene.reload_map` goes through both
too. The joiner puts it on with `Campaign.apply` (no scene change) and changes
scene, and its map does to that state what the host's arriving did. A joiner
seated while the host is on a map is sent there `as_it_stands`
(`arrives_as_it_stands`: the party and bags kept, where the host's party
stands). **One seated mid-fight comes into it** (the designer, 2026-10-30): every
fight keeps its beginning (`_fight_start`, Campaign as `scene_changing` sent it
into `FIGHT_SCENE`), everything done in it in order (`_history`: the host's
moves from `fight_move`, the joiner's as `_play_moves` plays them, the "steer"
moves) and every answer (`_answers_given`), alone or not; `_welcome` sends them
with the fight's seed (`_join_fight`), and the joiner goes into the same fight
and plays it all through (`fight_begins` installs it; `_known_answers` answers
its questions) - `catching_up()`: `Combat._pace_turn` at `CATCH_UP_SPEED`, the
sound off, a curtain, its presses dropped by the gate (`drops`) - until it stands
where the host's did; then `_offer_the_choice`. What the host sends while a fight
is on its way to the joiner is kept, not dropped (`_fight_coming`,
`_expect_a_fight`). A joiner seated while a fight's result is up waits for the
next change. After that the host
sends Campaign whenever it changes and every `STATE_ANYWAY_SECONDS` anyway
(`_send_state`), held on the joiner while it changes scene. On a joiner the map
sets off no contact triggers and offers no paths (`Net.follows()`): the host's
does. Leaving, and the host leaving, send the joiner to the title screen's
Players with a note. **Walking:** each machine walks its own players' groups
and `_say_where` sends their leaders' place, facing and walking
`WALKS_A_SECOND` (unreliable, ordered; every `WALK_ANYWAY_SECONDS` standing);
the other machine's copy is a puppet and `walk_to`s it, the host only where
`is_walkable`. **Presses:** the gate (`Coop._Gate`) asks `Net.forwards` first:
on a joiner a press of `HOSTS_PRESSES` (or a number key on a watched map) goes
to the host and is not acted on here; `BOTH_PRESSES` (Stay Here - the joiner's
own line) is sent and acted on here too. The host `push_input`s it - never
`Input.parse_input_event`, which would hold this machine's own keys down - on
device `Coop.REMOTE_DEVICE_BASE` + the player, which `Coop.player_of_event`
reads as that player, so the gate's focus and `acting` are theirs. A trigger
goes as the action it presses. The moves panel on a joiner sends `use_move`
and `pressed_here`. `_sent_by_whoever_plays` checks every such call came from
the machine that player is on. Pings go both ways (`Pings.pinged` -> `_ping` ->
`show_ping`). **Aimed and chosen on the joiner's own screen:** T (throw) and G
(Outside Spell) are not forwarded; their aiming and choices are the joiner's, on
its puppet watch, and what they come to is sent with `do_on_host` (`DONE_AFAR`:
`StealthWatch.throw_at`, `_click_on_guard` -> `click_at`, `ready_outside`,
`go_invisible`, `summon_familiar` / `dismiss_familiar` on a puppet, and
`ExplorationScene`'s own on a joiner) and done there as that player
(`_done_afar`). `OutsideMoves.use` on a joiner is `use_move` but for
Invisibility, whose picker is the joiner's. Every forwarded press, move and
doing carries the guard the joiner's pointer is on (`_pointed_here`), and on the
host `StealthWatch.hovered_guard` is theirs while their press is handled
(`pointing_afar`, `pointed_guard`). The puppet watch is sent the party's
listening, who is unseen and what is readied (`net_state` "ears", "unseen",
"readied"). **Alithia's familiar:** the host's `FamiliarKeeper` decides and sends
`net_state` (`_familiar_is`); the joiner's `apply_net_state`s it. Whoever steers
it walks it on their machine and sees through its eyes there (`steered_here`);
on the other it is a puppet (`Familiar.puppet`, `puppet_to`; the host takes the
joiner's walk by `_familiar_walked`, only where `can_be_at`). Asked for by the
host's player of the joiner's caster's player, the question is put there
(`ask_for_the_familiar`). **Hacks and quick times outside a fight** are played by
whoever they are for, on their screen: `Hacking.run` on the host for the
joiner's player's press is `hack_afar` (the joiner plays it as `_hack_here`,
spending gates and strain as it goes - `HACK_KEYS` kept from the host's state -
and sends what it cost, `hack_cost`; the host spends the same and settles it);
a magic trap's answer and a conversation's `QuickTime.start` go through
`quick_time_by` (the starter's: `conversation_starter`). Over a network neither
pauses the tree: like a menu, only this machine's own party stands
(`MenuPause.hold`). A joiner's map springs no traps (`_traps_gone_dark`).
**Pictures are both players'** (the designer, 2026-10-31: search and explore
together). `Pictures.open` on the host asks `picture_there(picture, first)`:
one for the joiner's player (`player_now`: the conversation's starter, else
`Coop.acting`) is sent there whatever is open here (`_picture_here`) and waited
for (`picture_closed_there`; a PictureInteractable holds nothing over a network);
one a conversation opens first is `shared` - played on both, and whoever began
the conversation leads (`picture_led_afar`; the host's closing it is
`close_picture_there` -> `_close_picture`). `_pictures_out` keeps them by number
on the host. What a picture on the joiner changes goes to the host as it is made
("What the joiner changes": `Pictures._progressed` -> `picture_progressed`, and
every `STATE_SECONDS` - `_send_picture_changes`); `_picture_done` sends the last
of it and the map a hotspot sent the party to (`may_change_scene` ->
`_scene_wanted`), which `_picture_changes` goes to, closing pictures here first.
Following a scene change or leaving ends it there. **What the joiner changes**
(a picture's, `_picture_keys`; a menu's MENU_KEYS as it closes) is
`_send_changes`: per key since `_change_base` (`_changes_since` - a dictionary by
its entries, each [there, value] before and now, gold `by`, the rest was/now),
numbered, kept in `_changes_out` until the host's state `acked`s it
(`_with_acks`); the host lays it over its own (`_changes` -> `_merged`, a
three-way `_merged_value`: a list by its places, the joiner's wins where the
host's is as the joiner found it, the same thing changed on both sides a clash -
the whole change dropped, `_clashed` -> `Pictures.got_there_first`). The joiner
puts each state on with `_put_on_state`: the pending changes laid back over
(`_lay_over`), the base taken again, what was changed here since laid over that;
`campaign_changed` when SHOWN_KEYS changed. An entry of a menu's keys that the host has and this
machine neither has nor started from comes in even while the menu keeps them
(`_take_what_is_new`): somebody who joined meanwhile, whose bag would otherwise be made up here on
first asking, clash with the host's and lose all the menu had changed. Compare with `_same_value` (typed
lists equal untyped ones; never `==` across kinds). **Looking together:** each
machine sends its player's pointer in a picture (`_looking`, `LOOKS_A_SECOND`,
`Pictures.pointer_in_picture` 0-1; `looking_there`, `looking_at_a_picture`), drawn
by `Pictures._show_the_other` (`other_pointer`) and marked on the map
(`ExplorationScene._mark_the_looking`); a click's line (`Pictures._tell` ->
`said_in_picture` -> `said_there`, `other_said`); a dial or piece moved
(`Pictures.part_moved` -> `_moved_there` -> `lay_part`; `parts_left`, laid on a
picture shown later, cleared with the map): a move that finished the puzzle
there (`completes`) only `settle`s it here, and one leaving it right with neither
having finished it is solved by the host (`Puzzle.check`). Over a network a
picture holds `MenuPause` (`_held_as_a_menu`), so only its own machine's party
stands, and keeps nothing (`_a_menu_keeps`); the Journal opens over it
(`Journal._another_menu_up`), and the joiner's ConversationMirror steps aside
while one is up. **A store is each player's own** (the designer, 2026-10-31):
one asked for the joiner's player (`ExplorationScene._on_store_requested`) is
`store_afar` -> `_store_here`; both may have the same one open; on the joiner
a deal is `store_deal` -> `_store_deal`, made on the host as that player, and
`_store_refused` -> `StoreScreen.refused` when it would not go; every
`StoreScreen` redraws on `campaign_changed`, keeping the keyboard on its row, and
the host's own deals `send_now`. **The camera in another's conversation**
(the designer, 2026-10-31): `Net.conversation_focus` (the host's `_starter`, the
joiner's `_mirror_starter`, when on the other machine) glides
`ExplorationScene`'s camera onto their leader (`_glide_camera`, `CAMERA_GLIDE`,
`conversation_shot`) and back (`CAMERA_BACK_SECONDS`); meanwhile everything else
that moves it aims the glide (`_aim_camera`, `_camera_aim`). The `familiar` key
goes to the host while a familiar is out (`forwards`; a pad's is the Outside
Spell button, which otherwise stays here), and Party Management for whoever
joins comes up on both (`manage_party_there`).
**Join codes** (`Net.code_for`, `read_code`; the designer, 2026-11-05): an IPv4 address and
port packed into base 32 with a check byte, 8 characters for the usual port and 12 with
another. `Net.join` takes one for an address; the panel has a Copy Code beside each address
to give. It does not hide the address, and the host must be reachable as for the address.
`joincode` covers it. `PROTOCOL` is 10.
**One player to a machine** (the designer's list of 2026-11-04):
`Coop.player_here()` is this machine's player over a network, and any device here
counts as them (`player_of_event`, `pointer_device`, `direction`). On a turn or a
menu that is somebody else's, `Coop.lets_through` still passes what only looks
(`LOOKING`, `_only_looks`: zoom, the wheel, the sheets; a click only over a control
in `Coop.OPEN_TO_ALL` - the HUD's faces and tabs) and, with a menu or a conversation
up on this machine, every press (`MenuPause.is_held`, `Net.conversation_up_here`).
Each player has their own lead (`Campaign.lead_here`, `is_leading`, `lead_within`,
which turns only that player's keys in their places in `party_order`): it is who
the portraits highlight, whose moves the bar shows (`OutsideMovesPanel.who`) and
who Tab changes (`swap_leader`). The camera follows this machine's own group
(`_camera_group`, `_group_moved`; `_frame_groups` is false) and the leash is only
for one screen. The other player's character walks by `_ease_to_where_said`
(`PUPPET_EASE`, `PUPPET_THERE`, teleported past 3 tiles; left alone while
`Actors.is_moving` it), its animation from what the walk says. A conversation is the
same on both: `ConversationMirror` is built as `ui/dialogue_balloon.tscn` is - the
portrait by `DialogueBalloon.portrait_of`, the name in its colour, the text typed
out, the answers both may press (`Net._line`'s `tags`, `_on_balloon_input`) - and
what a conversation's mutations do to the world is done on both (`Actors` ->
`Net.actors_did`, `ACTORS_DOES`; `Music` -> `Net.music_did`, `MUSIC_DOES`). In a
fight each sees the tile the other points at, in their colour with their name
(`pointing_on_board` -> `CController.show_other_pointing`, `OTHER_HOVER_SECONDS`, on
the unreliable channel; nothing changes a replayed fight, and `battle_party` no
longer reads `Coop.acting`, which differs). On the title screen a pick is made, not
asked for (`pick_at_the_table`, `in_the_game`; `players_panel.choose`). The panel's
stale "No answer" clears as a new attempt starts (`net_panel._was_idle`). Party
Management's panel is `MOUSE_FILTER_STOP`, and `CController.a_menu_is_over_the_map`
asks `MenuPause.is_held` - a Container's default PASS with no STOP above it lets a
click fall through to `_unhandled_input`.
**What the other machine may send** (security review, 2026-11-05):
`Net.in_the_game_files(path)` - under res://, nothing climbing out, no backslash -
guards every path that crosses (`data_to_resource`, `_follow`, `_picture_here`,
`_picture_changes`, `Campaign.apply`), since a scene or a resource can carry a script;
`_may_press_from_afar` lets the host act only on `HOSTS_PRESSES` and `BOTH_PRESSES`,
the familiar's while one is out and the number keys on a watched map; `_answer`
checks its sender; a track or portrait name cannot climb out either
(`_music_did`, `DialogueBalloon._file_safe`); `SaveGame.read` refuses text with
`Object(` or `Resource(` in it, since `str_to_var` would build one. Objects never
decode over the wire. `net` ("paths from the other machine") and `saves` cover it.
**A menu or a picture open on a machine keeps that
machine's presses:** the joiner forwards none (`forwards`), and
`ExplorationScene._unhandled_input` and `StealthBar._act` ignore a press from a
group `in_a_menu`. The share-out offer goes only to the stranded player's own
machine (`_stranded`). **Dragging and creeping are each group's**
(`StealthWatch._drag_group`, `_drags`, `creeping_in` - on its player's device -
`_set_pace` for every group of this machine's, `_group_of` for whose steps are
heard): the host says who drags (`net_state` "dragger" -> `_dragged_by`, which
the puppet watch's `_play_puppet` paces by), and the joiner says it creeps with
every walk (`_walked`'s `creeping` -> `ExplorationParty.creeping_there`;
`PROTOCOL` 3).
**Guards:** on a joiner the watch is a puppet
(`StealthWatch.puppet`, set in `begin` from `Net.follows()`, and every
`Guard.puppet`): `_process` only dresses the party, works out what each guard
sees and draws the meters, and a guard only eases to `puppet_to`. The host sends
`StealthWatch.net_state()` `WATCHES_A_SECOND` (each guard by `_id_of`: place,
facing, mood, knocked out, shown, suspicion; the alert and its floor; doors,
lamps, what is still lying about) and the joiner's `apply_net_state` puts it
on. A catch is the host's: its fight goes over with the scene change. **Menus
over a network** (the designer, 2026-10-29): while `Net.with_another()`,
`MenuPause` pauses nothing and `Coop.menu_held` takes no focus; only this
machine's own groups stand (`ExplorationParty.in_a_menu`, set by
`_stand_for_menus`, every frame and at once as `MenuPause` holds or lets go - `menus_changed` - so a menu opened and shut within one frame still counts). What a menu on the joiner changes (`MENU_KEYS`: bags,
gear, gold, spells, paths) stays the joiner's while it is open
(`Campaign.apply(state, keeping)`; `_menu_open` only for a menu that keeps,
`_a_menu_keeps` - not a store or the pictures) and goes to the host as it closes
(`_send_changes`), laid over what the host's player did meanwhile. **Fights, replayed:** going into `FIGHT_SCENE` the host gives a copy of the
encounter a "seed" (`scene_changing`); both play the fight (`fight_begins`
from `Combat._ready`). Whoever's character it is moves on their own machine,
and each move is sent from where it is made - `CController.move_player`
("walk"), `confirm_skill_target` ("skill", with `aim_choice`), `undo_move`,
the HUD's End Turn and readied cone, `ReadyPicker` ("ready"), and
`Combat.finish_deployment` ("deployed": the host places the party; the
joiner's Begin and placing wait, `may_deploy`). `_play_moves` does each on the
other machine once its fight is at the same `fight_turn` and stands waiting on
that combatant (`_replaying` keeps it from being sent back; `walk_along` walks
a sent path). The AI is not sent. A question (`ReactionPrompt._put_up` ->
`_ask_here`), a quick time (`quick_time_power`) or a hack (`hacking.run`) goes
through `Net.decided(player, call)`: put up on the decider's machine, the
answer sent, the other machine waiting for it by number. Every `turn_advanced`
the joiner sends `hash(fight_state())`; the host compares (`checked_turns`),
and told apart writes the turn into `parted` and puts the joiner's hp, tile and
standing right (`_put_right`). A joiner leaving mid-fight hands the turn under
way to the host's player (`Coop.fight_turn`). **Conversations:** the host runs
them; each line (`DialogueBalloon.apply_dialogue_line` -> `conversation_line`)
goes to the joiner's `ConversationMirror` (ui/conversation_mirror.gd), its
party held. Whoever began it (`_starter`) presses on through its lines - the
joiner's press comes back (`answer_line(-1)`) as `advance_from_afar`. An answer
is **both players'** (the designer, 2026-10-30): `Coop.focus` is let go for it,
the host's pick (`DialogueBalloon._on_responses_menu_response_selected` ->
`chose_here`) and the joiner's (`_converse`) are gathered in `_picks`, and
`_settle_picks` takes one they share (`respond_from_afar`) or shows both what
each chose and asks again (`DialogueBalloon.choose_again`, `_pick_again`); a
player leaving mid-pick leaves it to the other. Local co-op is as it was: the
one who began it chooses. **Over the internet** (Step 3): hosting on every network
(`bind_ip` "*") asks the router to open the port by UPnP on a thread
(`_open_router`, `_ask_router`, `_router_answered`; `router`, `public_address`)
and shuts it on leaving and as the game closes (`_close_router`); a host bound
to one address never asks. The panel shows the address to give, with a button
copying each to the clipboard (`NetPanel.addresses_to_give`, `copy`; the
designer, 2026-10-31), or points at a
virtual LAN app. The Players panel's network half is
`ui/net_panel.gd` (`make_panel`); it listens for games only on Look for games,
since listening (or hosting) is what makes Windows ask about its firewall. Look
for games needs no address: it hears the beacons hosts on the same network send
(`BEACON` to `beacon_to`, 255.255.255.255), whatever the address box holds.
`net` plays two machines (twice into a fight, the second joined under way; a picture and a lock searched on both, one store both shop at, a conversation's picture and the camera drawn to it, the merge rules, a dragged body the joiner's): the suite hosts on 127.0.0.1:24790 and starts a second
headless Godot (`--net-client`) on the same copy for the joiner's half, which
logs to `net_joiner` (copied into `net`'s log, its FAILs counted) and its Godot
output to `net_joiner_godot.log` (read for script errors); the halves wait on
each other with `say` / `hear`.

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
amplifications, Conduit, the Trapper's free bomb, spare castings; per fight
until the designer's changes of 2026-10-24 and 25), which `Campaign.short_rest` /
`long_rest` clear. Rests are taken whenever something calls for one (a
conversation's `do Campaign.short_rest()`, a dungeon between its fights); nothing
counts them. `rest_party`, the rest between stages, is a short rest in a dungeon
of `short_rests` (the Dungeon Demo and the lab: half of what was lost,
`SHORT_REST_MENDS`; one Devotion casting back, `spares_back_at_short_rest`; no
gates; the fallen stay down) and a full one otherwise (which calls `short_rest`
too). At a short rest somebody fallen can be brought back with Resuscitate
(`resuscitator`, `resuscitate_at_rest`: the spell's own Revive Health and
Weakening, a casting through Pandora or deeper - then rested like the rest), and
Prometheus can Meditate (`can_meditate`, `meditate`: `ceil(level / 6)` points, a
casting its gate's depth, the shallower half of his gates, once until a long
rest, `meditated`; the RestPanel offers it where the dungeon has no recovery of
its own). A long rest brings everything back: everybody up and whole, the
weakening lifted (`_lift_weakening`, from `unweakened_max_hp`), every gate and
Iris's, Meditate, Devotion. Alithia's Devotion is Combat "Spare castings"
(`spares_left`, paid first in `_pay_for_cast`). A dungeon's `kit` stocks the bags
`start_dungeon` empties. `ResultUI` shows a
`RestPanel` (`Campaign.rest_party`, `recover_gates`, the fallen, and an Inventory
button or the inventory key opening an `InventoryUI` over it, to repack) instead of its own panel
after every won fight but the last. `reset()` ends a dungeon, so the title
screen and every fresh start leave it. `dungeon` covers it, `restuses` the uses,
`restcycle` the rests, Meditate, Devotion, the Smelling Salts and the Trapper's bomb.

The late-Chapter-I laboratory sequence (`data/dungeons/lab_chapter1_sequence.tres`,
boss Erysichthon; `lab_chapter1_sequence_ash_warden.tres` the same with the Ash
Warden; `docs/lab_sequence.md`) is a TEMPORARY test harness, not story content. It
takes short rests and carries a kit, Cyrus's Smelling Salts in it (designer, 2026-10-25); `skips_rests`, which
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
(everything but movement), and carried in `Campaign.party_state` like health
until a long rest lifts it. Smelling Salts does the same as an item.

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
`skill.ability_modifier` straight. A rank can swap the condition
(`SkillRank.condition`, `ranked_condition_effect`: Deep Corrosion's Deeply Corroded,
which takes the weaker off) and a heal's share of health (`heal_share_of_health`,
read by `heal_share_of` / `heal_share_from`: Light Swing, whose once-a-foe double
is `_wounded_bonus`). Disarmed is a condition's `weapon_damage_change`, folded by
`weapon_damage_factor` into `damage_dealt_multiplier` for an `is_weapon_attack`
(Physical, not a spell, not an item), and taken off by `_weapon_attack_made`;
`disarm` covers all three. The passives' switches are read in Combat
"Progression" (`damage_reduction_of` inside `damage_taken_multiplier`,
`progression_damage_bonus` inside `damage_dealt_multiplier`, `contest_bonus_of` in
`wins_contest`, `lingering_bonus`/`lingering_turns` in the CONDITION and
DAMAGE_OVER_TIME branches, `_after_heal` in `do_heal`, `_mend_at_turn_start` and
`started_in_cover`/`moved_this_turn` at a turn's start, `spells_cast` (Kindling)
counted in `_use_skill` after the effects, `add_deepest_castings` at
creation and after gear). `in_cover` is beside a tile that blocks sight. An
enemy with one of the party's moves keeps its own learning level for it
(`CombatantDefinition.skill_levels`, read by `meets_level_for`), so a move moved
later for the party (Sweep Strike, 54) is not taken off the Barbarian. The
Sorcerer and the Priest share the party's Burner, Wind Swoon, Crystalise, Gust
Blast and River Flow, so the condition proposal of 2026-10-25
(`docs/perplexity_condition_dot_proposal.md`) changed theirs too (the designer:
enemies follow the new spells).

**Five chapters** (Campaign "Chapters"): `CHAPTER_LEVELS` is where each ends
(18, 33, 45, 55, 64); `begin_chapter(n)` from a dialogue. The character sheet's
Levels page (`ui/character_sheet.gd`, "Levels" - `levels_of(key, subclass)` is
the table, `level_entries_of` the same as entries: growth in a quiet line,
everything else a chip, `is_growth`) stops at 55, ΛΗΘΗ, until Chapter V
(`levels_in_view`), and plays its unveiling once after (`levels_unveiled`). It
opens on the level they are at (`_scroll_target`), keeps the next unlocks above
the scroll (`_pinned`) and has Unlocks Only on its toolbar. Its Moves page lists
skills, then spells on a shelf per gate, a line of numbers each (`facts_of`,
`expected_damage`, `expected_heal`) and a role filter (`roles_of`, `ROLES`). The
Sheet page shows what is on them folded in (`stat_of`), castings and uses as pips
(`_pools_of`), and a passive not reached yet as "from level N" - and no moves:
those are the Moves page's, an ally's or a studied enemy's alike. One chip
(`_tag`) serves all three; tests find rows by their first Label, so keep a
heading's text first. Tab or the right trigger (`skill_tab`, read in `_input`
before focus takes Tab) turns the page.

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
Chosen once (`choose_subclass`), a path changes only at a long rest:
`long_rest` opens `Campaign.path_change_open` (saved), `_deploy_party` shuts it,
and `change_path` / `can_change_path` are what the sheet's Change Path button and
`SubclassPicker.offer(..., change = true)` ask (`restcycle` covers it).
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
out. Passives sharing a name but for the numeral (Momentum I and II) are one
passive in ranks (Combat "Ranks of a passive", `passive_family`): each rank adds
its numbers to the ones before, and the character sheet shows only the highest
unlocked (`CharacterSheet.passive_families`, `shown_rank`) - so a higher rank's
description gives the totals, the lower ranks' effects included. The same goes for what Cyrus's Light Footed and Quick Hands grant - ask
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
`_object_gone` removes them. `blast_push` and `blast_collision_damage` throw whoever a blast
catches (Gale Urn; `_blast_throw`), `costly_radius` makes the ground dear (Tar Cauldron;
`_thing_costs_double`, `costly_ground`, drawn by the board); Max Hp, Blast Radius and Blast
Damage are the designer's to set per object. `hazards` covers them. A spawn of one is never a party tile, whatever its
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
- **"Reactions"**: everybody a moment sets off reacts, by initiative, the highest first (`_by_initiative`; `_react_all`
  takes several triggers as one moment: the Foreseen Blow, Targeted and Ally Attacked before a blow; the designer, 2026-11-12).
  `SkillDefinition.reacts_when` (flags, `Trigger`). Leaves
  Reach is still `check_reactive_skills`. Everything else goes through
  `_react(trigger, enemy, why, protected_for, fits)`, called from:
  - `_react_to_step`, at the end of `check_reactive_skills`;
  - `_react_to_casting` (Casts), in `use_skill` before the animation, for
    anything `is_spell`. It sets `comb.casting`; `cancel_casting`
    (EffectType.CANCEL_CASTING, InstaHack) sets `cast_cancelled`, and then
    `_cast_cancelled` spends the action but no gate, spare or amplifying gate (the designer, 2026-11-12), and a Gate
    Nade torn apart stays in the thrower's bag, unused (the designer, 2026-11-13);
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
  only when `_ready_impossible`. ENTERS_AREA's `area` is `ready_area(comb,
  aim)`: a great cone (`get_cone_tiles`, `READY_CONE_TILES` - 12, PROPOSAL) out
  of them towards the aim, on the aim's floor, over what they see past the
  ground and standing walls (a walls-only `_SightGrid`; bodies walk on, and at
  the moment it fires a blocking move still wants a clear line). It fires at
  whoever steps in, past the move's own reach. Drawn by CController, and
  previewed under the pointer while it is pointed (`_ready_marking`).
  The player readies through the HUD's Ready button (`combat_ui._refresh_ready`,
  `open_ready_picker` -> `ui/ready_picker.gd`; a cone is pointed by the next
  click, `mark_ready_area` / `_take_ready_click` in `_input`). Trigger
  HIT_IN_SIGHT (512, appended; `readied.watched` is an id): `_react_after` calls
  `_react_watched_hit` - a hostile move at the watched one if they are the other
  side's, else at whoever hit them; a move for allies at the watched one; only
  while the watched one is in sight. On a map the same is StealthWatch
  `readied_outside` (see Moves outside a fight).
- **"Readying, for the AI"**: `CombatantDefinition.ai_readies` (flags, `AiReady`).
  `ai_process` sets `ai_turn_live`; `advance_turn` hands a turn that ends with its
  main action unused to `_ai_consider_ready`. A guard is handled earlier, in
  `ai_process` (`_ai_can_strike_this_turn`, `_ai_guard_ready`, `comb.post`).
  `_ai_ready_pick` prefers free moves, then the move worth most against who is
  likely to set it off (`_ai_ready_worth`: `ai_target_value`, within reach from
  where it stands when that matters - Counters Casters only readies for a caster
  it could reach), and `_ai_can_spare` keeps the last casting. Covers The
  Approach points its cone by `_ai_approach_aim` (`_ai_cone_score`: no foe in it
  already, across the most of their lines in) or falls back on its reach;
  Protects Its Own (16, appended; Ranger, Hired Bow - PROPOSAL) is
  `_ai_protect_ready`, HIT_IN_SIGHT over the ally most at risk.
  `threat_map` adds readied areas and Enters Reach reaches to `reaction`.
- **Breakable walls in a fight** (`Combat.is_wall`: a standing
  `BattleObjectDefinition.wall`) are walls: nobody sees past one, however big
  (`CController.blocks_sight`, `_SightGrid.WALL_BODY`), cover beside it, immune
  like any object, no heal mends one (`do_heal`), and `refusal_for` turns away
  anything single-tile aimed at it but a blow that breaks walls (`WALL_HOLDS`).
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
  Known only once learned, as any spell (`Campaign.outside_spells` asks
  `knows_spell` - before 2026-10-31 an unlearned Prometheus was offered it).
  Prometheus has it in `starting_spells` for now (the designer, 2026-10-31);
  in the story mode to come he will not know it there yet.
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
    `_reaction_target` and the readied area. `ready_area` lies on the floor it
    is pointed at (over the same ground, `real_of` / `tile_on`), through
    `floors_open_between`; `ready_refusal` asks it too.
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

**Download only, for Windows, macOS and Linux** (the designer, 2026-10-29): the
browser build is dropped - the game has got too heavy for it.

```bash
tools/release.sh                 # build all three and pack them
tools/release.sh --publish       # and push them to itch, after asking
```

`export_presets.cfg` is git-ignored, so a fresh clone has to set its export
presets up before either that or `tests/run_packed.sh` will work. The scripts
ask for three by name - **Windows Desktop** (the `.pck` beside the `.exe`
rather than embedded), **Linux** (x86_64, the `.pck` beside it) and **macOS**
(universal, exported to a `.zip`, a bundle identifier, signed ad hoc - the
README's "Exporting" has the settings) - and exporting needs the templates for
exactly this Godot version, which are installed per machine. Itch's channels
are `windows`, `linux` and `mac`; the Mac and Linux builds are pushed with
`--fix-permissions`, since nothing on a Windows disk says they may be run. The
Mac build is not notarized (that needs an Apple developer account), so macOS
asks before opening it the first time. The three `.wav` music tracks are ignored too -
126 MB, and `audio/Music.gd` warns and plays on in silence when one is missing,
so a clone without them runs fine and fights quietly.
