# Carrying on from another machine

Written 2026-11-28, before the designer's own PC is switched off for a few weeks. Everything the game needs is on GitHub but the
designer's sounds, which are kept off it by choice (2026-11-06) and live on their Google Drive.

## 1. The project

1. Install **Godot 4.7.2** (the standard build, not .NET) and its **export templates** (Editor > Manage Export Templates) - the
   templates are only needed to build for itch.
2. Clone `https://github.com/petrosleftsis-max/truthnukeproject`.
3. Open the project in the Godot editor once and let it import everything (the `.godot` folder is never on GitHub). Running it
   from the Project Manager before that first import can open on a black screen.

## 2. The sounds (not on GitHub)

The game uses 45 sound files, 326 MB, git-ignored: `audio/music/*.wav` and `audio/sfx/fights`, `moves`, `world` and `menus`
`*.wav`. Their `.import` files are on GitHub, so each one only has to be put back where it was. Copy those five folders' `.wav`
files from the Drive into the same folders of the clone (or put the originals in `audio/sfx/New folder/` and run
`tools/place_sfx.ps1`, which places what `tools/sfx_list.txt` names). Without them the game plays with placeholder sounds where a
sound is missing, and runs. `audio/ambience/` (3 GB) is not used by anything yet.

## 3. Building and publishing

- `tools/release.sh` (Git Bash) builds the playtest version; `--publish --yes` sends it to the restricted page. A machine with no
  `export_presets.cfg` takes the copy in `tools/export_presets.cfg` (no keys or passwords in it). `tools/find_godot.sh` looks for
  Godot on `GODOT`, on PATH, then in this PC's folders: set `GODOT` to the new one's `..._console.exe` on Windows.
- Publishing needs **butler** (from the itch app, or itch.io/docs/butler) and `butler login` once, by the designer.
- Pushing to GitHub may ask the Git Credential Manager to sign in the first time.

## 4. Tests

`tests/run.sh <suites>` runs suites against a copy of the project (`tests/run.sh --list` names them); with no names it runs all of
them - about 70 minutes on the designer's PC, longer on a slower machine. Running only the suites a change touches is the usual way.

## 5. Claude

- `CLAUDE.md` is in the project, so a session on the new machine reads it as before.
- My notes on how the designer works (`docs/claude_memory/`, copied 2026-11-28) live on the old PC in
  `C:\Users\ortin\.claude\projects\E--My-projects-MessengersOfTruth\memory\`. On the new machine, open a Claude Code session in the
  project once, then copy the files from `docs/claude_memory/` into that session's own memory folder (the session can do it when
  asked: "copy docs/claude_memory into your memory"). `MEMORY.md` is the index.
- Sessions on the old PC cannot be reached while it is off, Remote Control included. Cloud sessions work from GitHub, but have no
  sounds, no Godot unless their environment installs it, and cannot publish to itch.

## 6. The encounter editor's scratch

`tools/encounter_editor.tscn` is the designer's scratch space, kept out of commits on the old PC (`git update-index --skip-worktree`).
Its last state is in `docs/encounter_editor_scratch.tscn`: copy it over `tools/encounter_editor.tscn` to carry on with it.
