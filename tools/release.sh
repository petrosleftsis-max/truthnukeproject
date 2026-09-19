#!/usr/bin/env bash
# Builds the web and Windows releases, and optionally publishes them to itch.
#
#   tools/release.sh              build both, and zip them
#   tools/release.sh --publish    build both, zip them, and push to itch
#
# Run it from anywhere; it finds the project itself.
#
# The zips are for anywhere that is not itch. Butler does not want a zip - it
# takes the folder and packages it itself, which is also why publishing cannot
# get the layout wrong. By hand, the layout matters and is easy to get wrong in
# two different ways, so the zipping here is deliberate:
#
#   web      zipped by its CONTENTS, because itch serves index.html from the
#            root of the archive and will not look inside a folder for it
#   windows  zipped as a FOLDER, because the .exe is useless without the .pck
#            beside it and two loose files at an archive root are easy to
#            separate on the way out
set -eu

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-/c/Users/ortin/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe}"
ITCH="eplogos/messengersoftruth"

publish=false
[ "${1:-}" = "--publish" ] && publish=true

if [ ! -x "$GODOT" ] && ! command -v "$GODOT" >/dev/null 2>&1; then
	echo "Godot not found at: $GODOT"
	echo "Set GODOT to wherever it lives, e.g. GODOT=/path/to/godot tools/release.sh"
	exit 1
fi

rm -rf "$ROOT/export"
mkdir -p "$ROOT/export/web" "$ROOT/export/windows"
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true

echo "===== Web ====="
"$GODOT" --headless --path "$ROOT" --export-release "Web" "$ROOT/export/web/index.html" 2>&1 | tail -5
echo "===== Windows ====="
"$GODOT" --headless --path "$ROOT" --export-release "Windows Desktop" \
	"$ROOT/export/windows/MessengersOfTruth.exe" 2>&1 | tail -5

# A build with no game in it is the failure worth catching here: the export
# templates going missing leaves the wrapper behind and nothing else.
for must in "$ROOT/export/web/index.pck" "$ROOT/export/windows/MessengersOfTruth.pck"; do
	if [ ! -s "$must" ]; then
		echo "MISSING or empty: $must - the export did not produce a game."
		exit 1
	fi
done

echo "===== Zipping ====="
# Through PowerShell, because Git Bash ships no zip and Compress-Archive is
# always there on Windows. cygpath because PowerShell wants Windows paths.
win_path() { cygpath -w "$1"; }
mkdir -p "$ROOT/export/MessengersOfTruth"
cp "$ROOT/export/windows/"* "$ROOT/export/MessengersOfTruth/"
powershell -NoProfile -NonInteractive -Command "
	\$ErrorActionPreference = 'Stop'
	foreach (\$z in @('$(win_path "$ROOT/messengers-of-truth-web.zip")',
	                  '$(win_path "$ROOT/messengers-of-truth-windows.zip")')) {
		if (Test-Path \$z) { Remove-Item \$z -Force }
	}
	Compress-Archive -Path '$(win_path "$ROOT/export/web")\*' -DestinationPath '$(win_path "$ROOT/messengers-of-truth-web.zip")' -CompressionLevel Optimal
	Compress-Archive -Path '$(win_path "$ROOT/export/MessengersOfTruth")' -DestinationPath '$(win_path "$ROOT/messengers-of-truth-windows.zip")' -CompressionLevel Optimal
"
ls -la "$ROOT"/messengers-of-truth-*.zip

if [ "$publish" = false ]; then
	echo
	echo "Built. To publish these to itch as well: tools/release.sh --publish"
	exit 0
fi

if ! command -v butler >/dev/null 2>&1; then
	echo
	echo "butler is not installed. Get it from https://itch.io/docs/butler,"
	echo "put it on PATH, then run 'butler login' once - it opens a browser and"
	echo "caches a key, so this script never handles your credentials."
	exit 1
fi

# The build is tied to a commit, so a report of "the itch build is broken" can
# be traced back to exactly what was in it.
version="$(git -C "$ROOT" describe --always --dirty 2>/dev/null || echo unknown)"
echo "===== Publishing $version to $ITCH ====="
# The channel name is what tells itch the platform, so these two names matter.
butler push "$ROOT/export/web" "$ITCH:web" --userversion "$version"
butler push "$ROOT/export/windows" "$ITCH:windows" --userversion "$version"
echo
butler status "$ITCH"
