# Publishing to itch without the test stages and the placeholders (proposals, 2026-11-19)

**The designer, 2026-11-19:** "Alright I've created the restricted page. It's called 'messengers of playtesting'. Go with all
five suggestions, I like them". Built the same day; nothing has been pushed to itch.
1. **The release feature:** `Release` (`campaign/Release.gd`), from the "... Release" presets. The title screen drops Arena Mode,
   the Stealth Stages and both demos. Stand-in sounds are silent but footsteps (`Release.STAND_INS_KEPT`).
2. **The exclude filters:** in the three "... Release" presets. `export_presets.cfg` is kept out of git, so a copy is in
   `tools/release_presets.cfg`, which `tools/release.sh` adds to a machine that lacks them.
3. **The release check:** `tests/run.sh release`, which `tools/release.sh --release` runs first. Its report, with every empty
   sound and picture slot, is written to `export/release_report.md`.
4. **One stand-in picture:** `art/placeholders/stand_in.png`, a grey checker. The eight items that borrowed Study's icon (the four
   keepsakes, the archive ledger, the forged letter, the magnifying glass and the sealed requisition) point at it now, and a
   release stops while any does, unless `--allow-stand-ins`.
5. **Two pages:** `tools/release.sh --publish` sends the playtest build to the restricted page (`eplogos/messengers-of-playtesting`,
   to be confirmed), and `--release --publish` sends the release to the public one.

The designer asked: "suggest ways on how, when we publish to itch again, to not include the test stages and any placeholder art and
sound you have made for me". Itch stays untouched until the designer says (2026-10-30). These are for when that time comes, and
none of them is built.

## What there is to keep out

- **Test and demo content.**
  - On the title screen: Arena Mode, Stealth Stages, Clues Demo and Dungeon Demo. Stealth Stages holds ten stages: the nine plus The
    Wanderer's Quarter, and its dream.
  - `demos/`.
  - The demos' pictures: `pictures/clues_*.tscn` and `demo_notice_board.tscn`.
  - The Dungeon Demo itself, `data/dungeons/dungeon_demo.tres`.
  - The laboratory sequence (`data/dungeons/lab_chapter1_sequence*.tres`, `data/encounters/lab/`), which CLAUDE.md calls a
    temporary test harness.
  - Their conversations: `dialogue/stealth_stages`, `light_stage`, `wander`, `oddities`, `demo_stealth` and `clues_demo`, plus three
    examples nothing uses: `test`, `flag_example` and `walking_example`.
  - `tests/` and `docs/` are never exported already, because each has a `.gdignore`.
- **Placeholders.** Almost none of mine are files.
  - The art is drawn in code: the notes on walls, ladders, ledges, stashes, hidden marks, rest spots, the oddities, the dream's lamps,
    and so on. The four keepsakes added today (the stopped clock, the lens, the shoe, the button) borrow Study's icon.
  - The sounds are made on the spot from recipes (PlaceholderSounds).
  - Each one sits behind a slot that your file replaces the moment it is there. So there is little to strip out. What matters is that
    a release plays no stand-in where you would rather have silence, and that you know exactly which slots are still empty.
- **Today's export presets** take every resource (`export_filter="all_resources"`), with no include or exclude filters and no custom
  features. So everything above goes into every build.

## Ways to do it

| | What it is | Size |
|---|---|---|
| **1. A "release" feature** | Each export preset gets `custom_features="release"`, and the game asks `OS.has_feature("release")`. The title screen then leaves out Arena Mode, Stealth Stages and the two demos. By your choice, the stand-in sounds play as silence rather than beeps; this can be decided kind by kind, since a stand-in footstep may be better than none | Small |
| **2. Exclude filters** | The presets' `exclude_filter` drops the test content from the download itself: `maps/stealth_stages/*`, `demos/*`, the demo pictures, `data/dungeons/dungeon_demo.tres`, `data/dungeons/lab_*`, `data/encounters/lab/*` and the conversations above. This is only safe together with 1 and 3, because anything left that still points at an excluded file fails when it loads | Small |
| **3. A release check** | A suite that plays nothing. It follows everything the release can reach from its start: the title screen as the release shows it, and the story's maps, fights and conversations. It reports three things. Anything it reaches under the excluded paths counts as a failure, so a broken build never goes out. Every slot still empty, picture and sound, comes as a list to hand your artist. Every stand-in sound still in use is listed too | Medium |
| **4. Stand-ins marked as such** | Nothing more of her art is used: the opposite. Today four new keepsakes show the icon she drew for Study, borrowed because they had none. Every borrowed picture like that would point at one plain placeholder of mine instead, `art/placeholders/stand_in.png`. Her art then only appears where it belongs, the check lists whatever still shows the placeholder, and a release can refuse to go out while anything does | Small |
| **5. A playtest build beside the release** | `tools/release.sh` gets a `--release` switch that exports with the filters and the feature, and butler pushes that to the public page. The playtest build (stages and demos in) goes to a second itch page set to Restricted with a password: it stays out of itch's browse and search, and testers get its link with the password in it. Download keys for named testers work too. A second channel on the same public page would be downloadable by anybody, and a Draft page's secret link is meant for previewing, not for downloadable builds | Small |

**My pick:** 1, 2 and 3 together. The feature hides the test content, the filters keep it out of the download, and the check makes sure
nothing reaches what was left out and tells you which slots still want your art and sound. Do 4 alongside them, and 5 once you have
testers to give the stages to.

## Two versions, 2026-11-27

The designer: "The playtesting version in the restricted site doesnt have the stuff i can see... I want two different versions"
- "Restricted page: As I see it for now, playtesting, keeping your placeholders, access to all the stages, modes etc"
- "Public page: No art or sound you have generated (except for the simple placeholder for the slots that are unfilled), only the
  Play section and the first stages of arena and anything else i tell you"

**Why the playtest build hid Arena Mode, the demos and the Card Game:** `Release.on()` asked `OS.has_feature("release")`, and Godot
gives every build exported from a release template a feature of that very name. So every export, the playtest one too, behaved
as the public one. The public build's own feature is now `public_build` (the three "... Release" presets in `export_presets.cfg`
and `tools/release_presets.cfg`); the playtest presets have none, so the playtest build shows everything again.

**The public build now** (`campaign/Release.gd`): the title screen has Continue and Load Game (once there are saves), Play, Arena
Mode with only its first stages (`Release.PUBLIC_ARENA_STAGES`, 3: the Ambush, the Sappers, the Watcher), Options and Exit -
no Players, Stealth Stages, demos, Card Game, Town Demo or Glossary. Every stand-in sound is silent, footsteps too
(`STAND_INS_KEPT` is empty). My stand-in picture files (`Release.GENERATED_PICTURES`: the sacred tree's, the door's) show the
plain grey stand-in in their place; what is drawn in code is unchanged so far (open: whether that counts as "art you have
generated"). The release check no longer stops a release for the stand-in picture: it lists where it still shows.

**The playtest build** has everything, as in the editor, and the Town Demo on the title screen too.
