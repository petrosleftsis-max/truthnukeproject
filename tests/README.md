# The headless harness

88 suites that boot the real game without a window, play something out and
write down what happened.

```bash
tests/run.sh                 # every suite in suites.txt
tests/run.sh dot flags       # just those two
tests/run.sh scale           # a probe, run the same way
tests/run.sh --list          # what there is
```

Godot is found by `tools/find_godot.sh`: `$GODOT`, then PATH, then the places
it is unpacked on the machines this is worked on. Use the `_console` build on
Windows. The working copy and the logs land in the system temp folder, or
wherever `$MOT_TEST_WORK` points.

## Why it copies the project

Nothing runs against the project folder. Every suite drives the real game -
loading scenes, taking turns, writing settings - and doing that in place would
leave its fingerprints on the thing being measured. `run.sh` tars a throwaway
copy, drops the drivers into its root and edits *that* `project.godot`.

Two details in there were each a bug first:

**The copy gets a `user://` of its own.** It declares the same project name as
the real game, so `user://` resolved to the player's own save folder: suites
were writing `settings.cfg` into it and leaving files behind, and a headless
run holding one made the editor fail to read its own config.

**The driver goes last in the autoload list.** Every database and autoload it
reads has to be up before its `_ready` runs.

## What a driver is

One file, `<name>_test_driver.gd`, `extends Node`, installed as the autoload
`T`. The shape is the same throughout:

```gdscript
var LOG_PATH := HarnessLog.path_for("dot")

func ok(condition: bool, label: String, detail: String = ""):
	# writes "  PASS  ..." or "  FAIL  ...", counting the failures

func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(150.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()
```

and it ends by writing `FAILURES: %d` and quitting 0. The runner reads three
things: the exit code, that `FAILURES:` line, and any `FAIL ` lines. It also
counts `SCRIPT ERROR` on stderr - those used to go to a file nobody looked at,
so a script error during a suite was invisible as long as the assertions
passed, which is exactly the shape of a coroutine resuming onto a freed scene.

The timer is not optional. Without it a driver that never reaches its last line
hangs until the runner's own budget kills it, and you lose the log.

`HarnessLog.path_for()` reads `$MOT_TEST_LOG_DIR`, which the runner sets. Run a
driver by hand with no runner around it and the results go to the copy's own
`user://` instead - somewhere rather than nowhere.

## Suites and probes

`suites.txt` lists what a full run covers. One of them, `ai`, asserts nothing -
it traces what each archetype did with its turn and is read by eye. It stays in
the sweep because driving the AI through four turns catches a script error or a
hang, but do not read a green `ai` as the archetypes behaving. `archetypes` is
the suite that asserts the behaviour: it puts a handful of people on open
ground, runs exactly one enemy's turn - the turn order is set to player, that
enemy, player - and checks what that enemy did with it.

Everything in `probes/` is a driver
written to answer one question - why can this combatant see that one, what does
a bottle tick for beside the skill that inflicts the same condition - and kept
because the next question is usually nearby. They are snapshots of an
investigation, not assertions, and one may well have gone stale against content
that has since been renamed. They print rather than judge, so read the log.

## Adding one

Write `tests/<name>_test_driver.gd` on the shape above, add `<name>` to
`suites.txt`, and run `tests/run.sh <name>`. A suite needing a different main
scene or a fixture file is a special case in `run.sh` - `glossary` and
`bailout` start at the menu, `halt` and `bailout` get a dialogue file written
for them first.

**Make the test fail before you believe it.** The `flat_power` bug sat under a
green suite for a day because everything asserted each item did *something* and
nothing asserted the four tiers differed from each other. A guard that has
never been seen to bite is a guard you are guessing about: break the thing on
purpose, watch it go red, put it back.

## Against a real build

```bash
tests/run_packed.sh glossary
```

The exporter turns every `.tres` into binary, moves it into `.godot/exported/`
and leaves a `name.tres.remap` in its place, so a folder looks quite different
from inside a build than it does in the editor. A suite that only ever runs
against the project folder cannot see that. Needs export presets, which are
git-ignored - open the project in Godot once first.
