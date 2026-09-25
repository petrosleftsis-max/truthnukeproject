# Sourced, not run, by everything that drives Godot - tests/run.sh,
# tests/run_packed.sh and tools/release.sh - so they all look in the same
# places in the same order, and a new machine is one line here rather than one
# in each of them:
#
#   1. $GODOT, when it is set
#   2. godot on PATH
#   3. wherever it has been unpacked on the machines this is worked on
#
# Leaves GODOT set to what it found, or empty for the caller to complain about.
# On Windows it has to be the _console build: the plain one writes nothing to a
# terminal, so a headless run looks like it did nothing at all.

GODOT="${GODOT:-}"
if [ -z "$GODOT" ] && command -v godot >/dev/null 2>&1; then
	GODOT="$(command -v godot)"
fi
if [ -z "$GODOT" ]; then
	# The second ends in ".exe" as a folder, not the binary - the console build
	# is inside it.
	for candidate in \
		"/e/Godot/Godot_v4.7.2-stable_win64_console.exe" \
		"/c/Users/ortin/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
	do
		if [ -x "$candidate" ]; then
			GODOT="$candidate"
			break
		fi
	done
fi
