#!/usr/bin/env bash
# Runs the headless suites against a throwaway copy of the project.
#
#   tests/run.sh                 every suite in suites.txt
#   tests/run.sh dot flags       just those two
#   tests/run.sh scale           a probe works the same way
#   tests/run.sh --list          what there is to run
#
# Nothing is run against the project folder itself. Every suite drives the real
# game - loading scenes, taking turns, writing settings - and doing that in
# place would leave its fingerprints on the thing being measured.
#
# Godot is found on PATH or named in $GODOT. The working copy lands in the
# system temp folder, or wherever $MOT_TEST_WORK says.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$(cd "$HERE/.." && pwd)"

. "$SRC/tools/find_godot.sh"
if [ ! -x "$GODOT" ]; then
	echo "Godot not found. Put it on PATH, or say where it is:" >&2
	echo "  GODOT=/path/to/godot tests/run.sh" >&2
	echo "On Windows use the _console build - the plain one writes nothing to the terminal." >&2
	exit 1
fi

WORK="${MOT_TEST_WORK:-${TMPDIR:-/tmp}/mot-test-harness}"
DST="$WORK/copy"
LOGS="$WORK/logs"

if [ "${1:-}" = "--list" ]; then
	echo "suites:"
	grep -v '^[[:space:]]*#' "$HERE/suites.txt" | grep -v '^[[:space:]]*$' | tr '\n' ' ' | fmt -w 72 | sed 's/^/  /'
	echo "probes:"
	for f in "$HERE"/probes/*_test_driver.gd; do basename "$f" _test_driver.gd; done | tr '\n' ' ' | fmt -w 72 | sed 's/^/  /'
	exit 0
fi

if [ "$#" -gt 0 ]; then
	DRIVERS="$*"
else
	DRIVERS="${SUITES:-$(grep -v '^[[:space:]]*#' "$HERE/suites.txt" | grep -v '^[[:space:]]*$' | tr '\n' ' ')}"
fi

mkdir -p "$WORK"

# One run at a time. Two of these share $DST and the per-suite result files, so
# a second one started while the first is going quietly rewrites the answers the
# first is still producing - which has twice now produced a summary and a log
# that disagreed with each other.
LOCK="$WORK/.run.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
	echo "Another run is already going (remove $LOCK if that is wrong)."
	exit 1
fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

# Godot wants a Windows path even when bash hands it a posix one.
LOGS_FOR_GODOT="$LOGS"
if command -v cygpath >/dev/null 2>&1; then
	LOGS_FOR_GODOT="$(cygpath -m "$LOGS")"
fi
export MOT_TEST_LOG_DIR="$LOGS_FOR_GODOT"

rm -rf "$DST"
mkdir -p "$DST" "$LOGS"
tar -C "$SRC" --exclude="./.git" --exclude="./export" --exclude="./tests" -cf - . | tar -C "$DST" -xf -

# The drivers sit at the root of the copy, where an autoload path can reach
# them. In the real project they live under tests/, which carries a .gdignore
# so the editor never parses them and no build ever carries them.
cp "$HERE/HarnessLog.gd" "$DST/HarnessLog.gd"
missing=""
for d in $DRIVERS; do
	if [ -f "$HERE/${d}_test_driver.gd" ]; then
		cp "$HERE/${d}_test_driver.gd" "$DST/${d}_test_driver.gd"
	elif [ -f "$HERE/probes/${d}_test_driver.gd" ]; then
		cp "$HERE/probes/${d}_test_driver.gd" "$DST/${d}_test_driver.gd"
	else
		missing="$missing $d"
	fi
done
if [ -n "$missing" ]; then
	echo "No driver for:$missing" >&2
	echo "tests/run.sh --list shows what there is." >&2
	exit 1
fi

sed -i 's|run/main_scene="[^"]*"|run/main_scene="res://scenes/game.tscn"|' "$DST/project.godot"

# The copy declares the same project name as the real game, so user:// resolved
# to the player's own save folder: suites were writing settings.cfg and leaving
# files behind in it, and a headless run holding one made the editor fail to
# read its own config. The harness gets a user:// of its own.
awk '{print} /^config\/name=/{print "config/use_custom_user_dir=true"; print "config/custom_user_dir_name=\"Messengers of Truth test harness\""}' "$DST/project.godot" > "$DST/project.godot.new"
mv "$DST/project.godot.new" "$DST/project.godot"

# The copy carries the real project's .godot, whose class cache can still name
# a script that has since been renamed. One scan puts it right.
"$GODOT" --headless --path "$DST" --import >/dev/null 2>&1

cp "$DST/project.godot" "$WORK/_project_base.godot"

overall=0
echo "===== SUMMARY ====="
for d in $DRIVERS; do
	# The driver goes LAST in the autoload list, so every database and autoload
	# it reads is already up before its _ready runs.
	awk -v drv="$d" '{print} /^Actors="\*res:\/\/exploration\/Actors.gd"$/{printf "T=\"*res://%s_test_driver.gd\"\n", drv}' "$WORK/_project_base.godot" > "$DST/project.godot"
	LOG="$LOGS/${d}_test_result.txt"
	rm -f "$LOG"
	if [ "$d" = "halt" ]; then
		# A conversation with something in the middle of it that has to happen
		# whether it is read or skipped, and a question that a skip must stop at.
		printf '~ start
Cyrus: One.
Cyrus: Two.
do Campaign.add_member("prometheus")
Cyrus: Three.
do Campaign.set_flag("skip_probe_reached_the_end")
Cyrus: Four.
=> END

~ asks
Cyrus: Well?
- Yes
	do Campaign.set_flag("skip_probe_answered")
- No
	do Campaign.set_flag("skip_probe_answered")
=> END
' > "$DST/Dialogue/_skip_probe.dialogue"
		"$GODOT" --headless --path "$DST" --import >/dev/null 2>&1
	fi
	if [ "$d" = "bailout" ]; then
		printf '~ start
Somebody: That is enough of that.
do Campaign.to_main_menu()
' > "$DST/Dialogue/_bailout_probe.dialogue"
		"$GODOT" --headless --path "$DST" --import >/dev/null 2>&1
	fi
	if [ "$d" = "glossary" ] || [ "$d" = "bailout" ]; then
		sed -i 's|run/main_scene="[^"]*"|run/main_scene="res://main_menu.tscn"|' "$DST/project.godot"
	fi
	# The sweep plays every encounter out; the rest are quick by comparison.
	budget=300
	if [ "$d" = "sweep" ]; then budget=900; fi
	timeout $budget "$GODOT" --headless --path "$DST" >/dev/null 2>"$LOGS/_err.txt"
	code=$?
	# Godot's own errors went to _err.txt and were never looked at, so a script
	# error during a suite was invisible as long as the assertions passed. A
	# coroutine resuming onto a freed scene is exactly that shape.
	errs=$(grep -c "SCRIPT ERROR" "$LOGS/_err.txt" 2>/dev/null || true)
	noise=""
	if [ "${errs:-0}" -gt 0 ]; then
		noise=" [SCRIPT ERRORS: $errs]"
		cp "$LOGS/_err.txt" "$LOGS/${d}_err.txt"
		overall=1
	fi
	if [ -f "$LOG" ]; then
		fails=$(grep -c "FAIL " "$LOG" || true)
		line=$(grep "FAILURES:" "$LOG" | tail -1 || true)
		echo "$d : exit=$code $line (FAIL lines: $fails)$noise"
		if [ "$code" -ne 0 ] || [ "${fails:-0}" -gt 0 ] || [ "$line" != "FAILURES: 0" ]; then
			overall=1
		fi
	else
		echo "$d : exit=$code NO LOG$noise"
		overall=1
	fi
done

echo
if [ "$overall" -eq 0 ]; then
	echo "all clean. logs in $LOGS"
else
	echo "something is wrong above. logs in $LOGS"
fi
exit $overall
