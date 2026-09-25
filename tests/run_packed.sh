#!/usr/bin/env bash
# Runs one suite against an actual exported pack rather than the project folder.
#
#   tests/run_packed.sh glossary
#
# The difference matters: the exporter converts every .tres to binary, moves it
# into .godot/exported/ and leaves a "name.tres.remap" in its place, so a folder
# looks quite different from the inside of a build than it does in the editor.
# A suite that only ever runs against the project folder cannot see that.
#
# It needs an export preset named "Windows Desktop", which lives in
# export_presets.cfg - a file git ignores, so a fresh clone has to open the
# project in Godot once and set its presets up before this will work.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$(cd "$HERE/.." && pwd)"
SUITE="${1:-glossary}"

. "$SRC/tools/find_godot.sh"
if [ ! -x "$GODOT" ]; then
	echo "Godot not found. GODOT=/path/to/godot tests/run_packed.sh $SUITE" >&2
	exit 1
fi

DRIVER="$HERE/${SUITE}_test_driver.gd"
if [ ! -f "$DRIVER" ]; then DRIVER="$HERE/probes/${SUITE}_test_driver.gd"; fi
if [ ! -f "$DRIVER" ]; then
	echo "No driver for $SUITE. tests/run.sh --list shows what there is." >&2
	exit 1
fi

WORK="${MOT_TEST_WORK:-${TMPDIR:-/tmp}/mot-test-harness}"
DST="$WORK/packed"
LOGS="$WORK/logs"
mkdir -p "$DST" "$LOGS"

LOGS_FOR_GODOT="$LOGS"
if command -v cygpath >/dev/null 2>&1; then
	LOGS_FOR_GODOT="$(cygpath -m "$LOGS")"
fi
export MOT_TEST_LOG_DIR="$LOGS_FOR_GODOT"

rm -rf "$DST"
mkdir -p "$DST"
tar -C "$SRC" --exclude="./.git" --exclude="./export" --exclude="./tests" -cf - . | tar -C "$DST" -xf -
cp "$HERE/HarnessLog.gd" "$DST/HarnessLog.gd"
cp "$DRIVER" "$DST/${SUITE}_test_driver.gd"

sed -i 's|run/main_scene="[^"]*"|run/main_scene="res://main_menu.tscn"|' "$DST/project.godot"

# A user:// of its own, so a packed test run never touches the player's saves.
awk '{print} /^config\/name=/{print "config/use_custom_user_dir=true"; print "config/custom_user_dir_name=\"Messengers of Truth test harness\""}' "$DST/project.godot" > "$DST/project.godot.new"
mv "$DST/project.godot.new" "$DST/project.godot"
awk -v drv="$SUITE" '{print} /^Actors="\*res:\/\/exploration\/Actors.gd"$/{printf "T=\"*res://%s_test_driver.gd\"\n", drv}' "$DST/project.godot" > "$DST/project.godot.new"
mv "$DST/project.godot.new" "$DST/project.godot"

"$GODOT" --headless --path "$DST" --import >/dev/null 2>&1
rm -f "$LOGS/${SUITE}_test_result.txt"
mkdir -p "$DST/_pack"
"$GODOT" --headless --path "$DST" --export-pack "Windows Desktop" "$DST/_pack/out.pck" 2>&1 | tail -5
ls -la "$DST/_pack/out.pck" || exit 1
timeout 300 "$GODOT" --headless --main-pack "$DST/_pack/out.pck" >/dev/null 2>"$LOGS/_pack_err.txt"
echo "exit=$?"
grep "FAILURES:" "$LOGS/${SUITE}_test_result.txt" || echo "NO LOG"
