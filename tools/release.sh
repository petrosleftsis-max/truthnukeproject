#!/usr/bin/env bash
# Builds the Windows, macOS and Linux games, and optionally publishes them to
# itch. The game is a download only (the designer, 2026-10-29): the browser
# build was dropped - the game had got too heavy for it - and macOS and Linux
# joined Windows the same day.
#
# Two builds (the designer, 2026-11-19, docs/itch_release_proposals.md):
#
#   the playtest build   everything in, the Stealth Stages, the demos and the
#                        lab sequence too - for the private, restricted page
#                        ("Messengers of Playtesting"), for testers
#   the release build    the "... Release" export presets: their "release"
#                        feature hides the stages and demos from the title
#                        screen and quiets the stand-in sounds (Release), and
#                        their Exclude Filter leaves the test content out of the
#                        download - for the public page. The release check
#                        (tests/run.sh release) runs first, and a release is not
#                        built while anything still points at what it leaves
#                        out, or still shows the stand-in picture
#
#   tools/release.sh                              the playtest build, packed
#   tools/release.sh --release                    the release build, packed
#   tools/release.sh --release --allow-stand-ins  the same, letting stand-in
#                                                 pictures through this once
#   tools/release.sh [--release] --publish        and push it to its page:
#                                                 the playtest build to the
#                                                 private one, the release to
#                                                 the public one (asks first)
#   ... --publish --yes                           without being asked
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
# The public page, and the private, restricted one for testers.
PUBLIC="eplogos/messengersoftruth"
PLAYTEST="eplogos/messengers-of-playtesting"

publish=false
assume_yes=false
release=false
allow_stand_ins=false
for arg in "$@"; do
	case "$arg" in
		--publish) publish=true ;;
		--yes|-y) assume_yes=true ;;
		--release) release=true ;;
		--allow-stand-ins) allow_stand_ins=true ;;
		*) echo "Unknown option: $arg"
			echo "Usage: tools/release.sh [--release [--allow-stand-ins]] [--publish [--yes]]"
			exit 1 ;;
	esac
done

if [ "$release" = true ]; then
	ITCH="$PUBLIC"
	WHO_SEES="everyone sees it"
	WIN_PRESET="Windows Desktop Release"
	LINUX_PRESET="Linux Release"
	MAC_PRESET="macOS Release"
	NAME="messengers-of-truth"
else
	ITCH="$PLAYTEST"
	WHO_SEES="the private page, for testers"
	WIN_PRESET="Windows Desktop"
	LINUX_PRESET="Linux"
	MAC_PRESET="macOS"
	NAME="messengers-of-truth-playtest"
fi

# Everything that has to be true before a two minute build, checked first.
#
# butler is found here rather than at the point of pushing because a --publish
# that discovers it is missing after building has wasted the build. And the yes
# is asked for here for a better reason: --publish uploads to a page people
# see, and it should not be reachable by accident - it was, once, by a run that
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
			printf 'This will upload to https://%s.itch.io/%s - %s. Continue? [y/N] ' \
				"${ITCH%%/*}" "${ITCH##*/}" "$WHO_SEES"
			read -r answer </dev/tty || answer=""
			case "$answer" in
				[yY]*) ;;
				*) echo "Not publishing. Built nothing."; exit 1 ;;
			esac
		else
			echo "Refusing to publish without being asked to: this uploads to https://${ITCH%%/*}.itch.io/${ITCH##*/}."
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

# The release presets live in export_presets.cfg, which git keeps out (it is this
# machine's own); one without them gets them from tools/release_presets.cfg,
# numbered after the presets it has.
if [ "$release" = true ] && ! grep -q '^name="Windows Desktop Release"' "$ROOT/export_presets.cfg" 2>/dev/null; then
	next="$(grep -c '^\[preset\.[0-9]*\]$' "$ROOT/export_presets.cfg" 2>/dev/null || true)"
	next="${next:-0}"
	sed -e "s/^\[preset\.4\]$/[preset.$next]/; s/^\[preset\.4\.options\]$/[preset.$next.options]/" \
		-e "s/^\[preset\.5\]$/[preset.$((next + 1))]/; s/^\[preset\.5\.options\]$/[preset.$((next + 1)).options]/" \
		-e "s/^\[preset\.6\]$/[preset.$((next + 2))]/; s/^\[preset\.6\.options\]$/[preset.$((next + 2)).options]/" \
		-e '/^;/d' "$ROOT/tools/release_presets.cfg" >> "$ROOT/export_presets.cfg"
	echo "Added the release presets to export_presets.cfg, from tools/release_presets.cfg."
fi

# The release check, before a release is built: nothing kept may point at what is
# left out, and nothing may still show the stand-in picture unless allowed this
# once. Its report - and the lists of sounds and pictures still to make - goes
# beside the builds.
CHECK_WORK="${TMPDIR:-/tmp}/mot-release-check"
if [ "$release" = true ]; then
	echo "===== The release check ====="
	allow=""
	[ "$allow_stand_ins" = true ] && allow=1
	if ! MOT_ALLOW_STAND_INS="$allow" MOT_TEST_WORK="$CHECK_WORK" MOT_TEST_USER_DIR="Messengers of Truth release check" \
			"$ROOT/tests/run.sh" release; then
		echo
		cat "$CHECK_WORK/logs/release_report.md" 2>/dev/null || true
		echo
		echo "Not building a release: see the check above (the report: $CHECK_WORK/logs/release_report.md)."
		[ "$allow_stand_ins" = false ] && echo "If only stand-ins stopped it and you want them through this once: --allow-stand-ins"
		exit 1
	fi
fi

rm -rf "$ROOT/export"
mkdir -p "$ROOT/export/windows" "$ROOT/export/linux" "$ROOT/export/macos" "$ROOT/export/tmp"
# The builds land inside the project, and Godot scans the project before every
# export. Without this a build's own files go into the next game's pack: the
# web build's icons once went into the Windows game, and the Mac's icon, made in
# export/tmp, went into the Mac game.
: > "$ROOT/export/.gdignore"
[ "$release" = true ] && cp "$CHECK_WORK/logs/release_report.md" "$ROOT/export/release_report.md" 2>/dev/null || true
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true

echo "===== Windows ($WIN_PRESET) ====="
"$GODOT" --headless --path "$ROOT" --export-release "$WIN_PRESET" \
	"$ROOT/export/windows/MessengersOfTruth.exe" 2>&1 | tail -5
echo "===== Linux ($LINUX_PRESET) ====="
"$GODOT" --headless --path "$ROOT" --export-release "$LINUX_PRESET" \
	"$ROOT/export/linux/MessengersOfTruth.x86_64" 2>&1 | tail -5
echo "===== macOS ($MAC_PRESET) ====="
# The .app is put together in the temp folder before it is zipped. In the
# system's one, on this PC, the export stalled for good writing the 170 MB
# program (twice in three runs: Godot idle, the file a few hundred bytes short)
# - most likely something scanning big new programs there. In export/tmp it
# has not.
TMP="$(cygpath -w "$ROOT/export/tmp")" TEMP="$(cygpath -w "$ROOT/export/tmp")" \
	"$GODOT" --headless --path "$ROOT" --export-release "$MAC_PRESET" \
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
	\$z = '$(win_path "$ROOT/$NAME-windows.zip")'
	if (Test-Path \$z) { Remove-Item \$z -Force }
	Compress-Archive -Path '$(win_path "$ROOT/export/pack/windows/MessengersOfTruth")' -DestinationPath \$z -CompressionLevel Optimal
"
# Nothing on this disk says the Linux game may be run, so the tarball is told:
# the folder and the game 755, the pack 644, and no name from this machine as
# their owner.
linux_tar="$ROOT/$NAME-linux.tar"
rm -f "$linux_tar" "$linux_tar.gz"
tar_linux() { tar -C "$ROOT/export/pack/linux" --owner=0 --group=0 --numeric-owner "$@"; }
tar_linux -cf "$linux_tar" --no-recursion --mode=755 MessengersOfTruth
tar_linux -rf "$linux_tar" --mode=644 MessengersOfTruth/MessengersOfTruth.pck
tar_linux -rf "$linux_tar" --mode=755 MessengersOfTruth/MessengersOfTruth.x86_64
gzip -9 "$linux_tar"
cp "$ROOT/export/macos/MessengersOfTruth.zip" "$ROOT/$NAME-macos.zip"
ls -la "$ROOT/$NAME-windows.zip" "$ROOT/$NAME-linux.tar.gz" "$ROOT/$NAME-macos.zip"

if [ "$publish" = false ]; then
	echo
	echo "Built. To publish these to https://${ITCH%%/*}.itch.io/${ITCH##*/} as well: add --publish"
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
