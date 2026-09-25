#!/usr/bin/env bash
# Builds the web and Windows releases, and optionally publishes them to itch.
#
#   tools/release.sh                    build both, and zip them
#   tools/release.sh --publish          build, zip, and push to itch (asks first)
#   tools/release.sh --publish --yes    the same without being asked
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
. "$ROOT/tools/find_godot.sh"
ITCH="eplogos/messengersoftruth"

publish=false
assume_yes=false
for arg in "$@"; do
	case "$arg" in
		--publish) publish=true ;;
		--yes|-y) assume_yes=true ;;
		*) echo "Unknown option: $arg"; echo "Usage: tools/release.sh [--publish] [--yes]"; exit 1 ;;
	esac
done

# Everything that has to be true before a two minute build, checked first.
#
# butler is found here rather than at the point of pushing because a --publish
# that discovers it is missing after building has wasted the build. And the yes
# is asked for here for a better reason: --publish uploads to a public page,
# and it should not be reachable by accident - it was, once, by a run that
# expected this very check to stop it.
if [ "$publish" = true ]; then
	BUTLER="$(command -v butler 2>/dev/null || true)"
	if [ -z "$BUTLER" ]; then
		# The copy the itch app keeps for itself, under a version folder it
		# changes whenever it updates - found by looking, newest last.
		BUTLER="$(ls -1d "$APPDATA/itch/broth/butler/versions"/*/butler.exe 2>/dev/null | sort -V | tail -1 || true)"
		[ -n "$BUTLER" ] && echo "Using the copy the itch app keeps: $BUTLER"
	fi
	if [ -z "$BUTLER" ]; then
		echo "butler not found, either on PATH or inside the itch app."
		echo "Get it from https://itch.io/docs/butler, or install the itch app,"
		echo "which bundles it. Either way run 'butler login' once - it opens a"
		echo "browser and caches a key, so this script never handles credentials."
		exit 1
	fi
	if [ "$assume_yes" = false ]; then
		if [ -t 0 ]; then
			printf 'This will upload to https://%s.itch.io/%s - everyone sees it. Continue? [y/N] ' 				"${ITCH%%/*}" "${ITCH##*/}"
			read -r answer </dev/tty || answer=""
			case "$answer" in
				[yY]*) ;;
				*) echo "Not publishing. Built nothing."; exit 1 ;;
			esac
		else
			echo "Refusing to publish without being asked to: this uploads to a public page."
			echo "Run it in a terminal, or pass --yes if you really mean it."
			exit 1
		fi
	fi
fi

if [ -z "$GODOT" ] || { [ ! -x "$GODOT" ] && ! command -v "$GODOT" >/dev/null 2>&1; }; then
	echo "Godot not found${GODOT:+ at: $GODOT}"
	echo "Set GODOT to wherever it lives, e.g. GODOT=/path/to/godot tools/release.sh,"
	echo "or add where it is unpacked to tools/find_godot.sh"
	exit 1
fi

rm -rf "$ROOT/export"
mkdir -p "$ROOT/export/web" "$ROOT/export/windows"
# The builds land inside the project, and Godot scans the project before every
# export. Without this the Windows export found the web build's icons sitting
# in export/web, imported them - leaving .import files in the folder that gets
# zipped for itch - and packed them into the Windows game as resources.
: > "$ROOT/export/.gdignore"
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

# The build is tied to a commit, so a report of "the itch build is broken" can
# be traced back to exactly what was in it.
version="$(git -C "$ROOT" describe --always --dirty 2>/dev/null || echo unknown)"
echo "===== Publishing $version to $ITCH ====="
# The channel name is what tells itch the platform, so these two names matter.
"$BUTLER" push "$ROOT/export/web" "$ITCH:web" --userversion "$version"
"$BUTLER" push "$ROOT/export/windows" "$ITCH:windows" --userversion "$version"
echo
"$BUTLER" status "$ITCH"
