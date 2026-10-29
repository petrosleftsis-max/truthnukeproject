#!/usr/bin/env bash
# Builds the Windows, macOS and Linux releases, and optionally publishes them to
# itch. The game is a download only (the designer, 2026-10-29): the browser
# build was dropped - the game had got too heavy for it - and macOS and Linux
# joined Windows the same day.
#
#   tools/release.sh                    build all three, and pack them
#   tools/release.sh --publish          build, pack, and push to itch (asks first)
#   tools/release.sh --publish --yes    the same without being asked
#
# Run it from anywhere; it finds the project itself.
#
# The archives are for anywhere that is not itch. Butler does not want them - it
# takes the folder and packages it itself, which is also why publishing cannot
# get the layout wrong. By hand, the layout matters, so the packing here is
# deliberate:
#
#   windows  zipped as a FOLDER, because the .exe is useless without the .pck
#            beside it and two loose files at an archive root are easy to
#            separate on the way out
#   linux    the same folder as a .tar.gz, because a zip made on Windows cannot
#            say the game may be run, and a tarball can
#   macos    Godot's own zip of the .app, as it comes: it is the one thing here
#            that knows which file in the bundle runs, so butler is handed the
#            zip too
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
mkdir -p "$ROOT/export/windows" "$ROOT/export/linux" "$ROOT/export/macos" "$ROOT/export/tmp"
# The builds land inside the project, and Godot scans the project before every
# export. Without this a build's own files go into the next game's pack: the
# web build's icons once went into the Windows game, and the Mac's icon, made in
# export/tmp, went into the Mac game.
: > "$ROOT/export/.gdignore"
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true

echo "===== Windows ====="
"$GODOT" --headless --path "$ROOT" --export-release "Windows Desktop" \
	"$ROOT/export/windows/MessengersOfTruth.exe" 2>&1 | tail -5
echo "===== Linux ====="
"$GODOT" --headless --path "$ROOT" --export-release "Linux" \
	"$ROOT/export/linux/MessengersOfTruth.x86_64" 2>&1 | tail -5
echo "===== macOS ====="
# The .app is put together in the temp folder before it is zipped. In the
# system's one, on this PC, the export stalled for good writing the 170 MB
# program (twice in three runs: Godot idle, the file a few hundred bytes short)
# - most likely something scanning big new programs there. In export/tmp it
# has not.
TMP="$(cygpath -w "$ROOT/export/tmp")" TEMP="$(cygpath -w "$ROOT/export/tmp")" \
	"$GODOT" --headless --path "$ROOT" --export-release "macOS" \
	"$ROOT/export/macos/MessengersOfTruth.zip" 2>&1 | tail -5

# A build with no game in it is the failure worth catching here: the export
# templates going missing leaves the wrapper behind and nothing else. The Mac's
# game is inside its zip, in the .app's Resources.
for must in "$ROOT/export/windows/MessengersOfTruth.pck" "$ROOT/export/linux/MessengersOfTruth.pck" \
		"$ROOT/export/macos/MessengersOfTruth.zip"; do
	if [ ! -s "$must" ]; then
		echo "MISSING or empty: $must - the export did not produce a game."
		exit 1
	fi
done
if ! unzip -Z1 "$ROOT/export/macos/MessengersOfTruth.zip" | grep -q '\.app/Contents/Resources/.*\.pck$'; then
	echo "The macOS zip has no .pck in its .app - the export did not produce a game."
	exit 1
fi

echo "===== Packing ====="
# Each archive holds one folder, MessengersOfTruth, with the game in it.
mkdir -p "$ROOT/export/pack/windows/MessengersOfTruth" "$ROOT/export/pack/linux/MessengersOfTruth"
cp "$ROOT/export/windows/"* "$ROOT/export/pack/windows/MessengersOfTruth/"
cp "$ROOT/export/linux/"* "$ROOT/export/pack/linux/MessengersOfTruth/"
# Zipped through PowerShell, because Git Bash ships no zip and Compress-Archive
# is always there on Windows. cygpath because PowerShell wants Windows paths.
win_path() { cygpath -w "$1"; }
powershell -NoProfile -NonInteractive -Command "
	\$ErrorActionPreference = 'Stop'
	\$z = '$(win_path "$ROOT/messengers-of-truth-windows.zip")'
	if (Test-Path \$z) { Remove-Item \$z -Force }
	Compress-Archive -Path '$(win_path "$ROOT/export/pack/windows/MessengersOfTruth")' -DestinationPath \$z -CompressionLevel Optimal
"
# Nothing on this disk says the Linux game may be run, so the tarball is told:
# the folder and the game 755, the pack 644, and no name from this machine as
# their owner.
linux_tar="$ROOT/messengers-of-truth-linux.tar"
rm -f "$linux_tar" "$linux_tar.gz"
tar_linux() { tar -C "$ROOT/export/pack/linux" --owner=0 --group=0 --numeric-owner "$@"; }
tar_linux -cf "$linux_tar" --no-recursion --mode=755 MessengersOfTruth
tar_linux -rf "$linux_tar" --mode=644 MessengersOfTruth/MessengersOfTruth.pck
tar_linux -rf "$linux_tar" --mode=755 MessengersOfTruth/MessengersOfTruth.x86_64
gzip -9 "$linux_tar"
cp "$ROOT/export/macos/MessengersOfTruth.zip" "$ROOT/messengers-of-truth-macos.zip"
ls -la "$ROOT/messengers-of-truth-windows.zip" "$ROOT/messengers-of-truth-linux.tar.gz" \
	"$ROOT/messengers-of-truth-macos.zip"

if [ "$publish" = false ]; then
	echo
	echo "Built. To publish these to itch as well: tools/release.sh --publish"
	exit 0
fi

# The build is tied to a commit, so a report of "the itch build is broken" can
# be traced back to exactly what was in it.
version="$(git -C "$ROOT" describe --always --dirty 2>/dev/null || echo unknown)"
echo "===== Publishing $version to $ITCH ====="
# The channel name is what tells itch the platform, so these names matter. Files
# pushed from Windows say nothing about being runnable; --fix-permissions has
# butler find the Mac and Linux programs and mark them.
"$BUTLER" push "$ROOT/export/windows" "$ITCH:windows" --userversion "$version"
"$BUTLER" push --fix-permissions "$ROOT/export/linux" "$ITCH:linux" --userversion "$version"
"$BUTLER" push --fix-permissions "$ROOT/export/macos/MessengersOfTruth.zip" "$ITCH:mac" --userversion "$version"
echo
"$BUTLER" status "$ITCH"
