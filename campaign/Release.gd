extends RefCounted
class_name Release
## Whether this is the build for the public itch page: the export presets' "release" feature, which only the "... Release" presets
## carry (tools/release.sh --release; the designer, 2026-11-19, docs/itch_release_proposals.md). In one, the title screen leaves out
## Arena Mode, the Stealth Stages and the two demos (MainMenu), and the stand-in sounds are silent but those in STAND_INS_KEPT
## (PlaceholderSounds). The playtest build, the editor and the tests have everything.

## Stand-in sounds still heard in a release, by PlaceholderSounds' names: a stand-in footstep is better than none. Empty, and every
## stand-in is silent.
const STAND_INS_KEPT := ["step", "step_wet", "step_stone", "step_wood", "step_grass"]

## For a suite: behave as a release would, in the editor or the harness.
static var pretend := false


## Whether this is a release build.
static func on() -> bool:
	return pretend or OS.has_feature("release")


## Whether the stand-in sound `event` is silent here: in a release, all but those kept.
static func silences(event: String) -> bool:
	return on() and not STAND_INS_KEPT.has(event)
