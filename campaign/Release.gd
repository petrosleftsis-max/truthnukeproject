extends RefCounted
class_name Release
## Whether this is the build for the public itch page: the export presets' "public_build" feature, which only the "... Release"
## presets carry (tools/release.sh --release; the designer, 2026-11-19, docs/itch_release_proposals.md).
##
## Named "public_build", not "release": Godot gives every export made from a release template a "release" feature of its own, so
## asking for that one hid Arena Mode, the demos and the Card Game from the playtest build too (the designer, 2026-11-27: "i cant
## find access to arena, dungeon and card mode").
##
## In the public build (the designer, 2026-11-27: "only the Play section and the first stages of arena and anything else i tell
## you", "No art or sound you have generated"): the title screen has Play, the saves, Arena Mode with its first stages only
## (PUBLIC_ARENA_STAGES), Options and Exit (MainMenu, LevelSelect); every stand-in sound is silent (PlaceholderSounds). The
## playtest build, the editor and the tests have everything.

## How many of Arena Mode's stages the public build offers, from the top of its list.
const PUBLIC_ARENA_STAGES := 3

## Stand-in sounds still heard in the public build, by PlaceholderSounds' names. Empty: every one of them is silent (the
## designer, 2026-11-27: "No art or sound you have generated"; until then the stand-in footsteps were kept).
const STAND_INS_KEPT: Array[String] = []

## Picture files I made as stand-ins (the designer, 2026-11-27: "No art or sound you have generated (except for the simple
## placeholder for the slots that are unfilled)"): in the public build each shows the plain stand-in picture in its place
## (picture). Add one here whenever a stand-in is a file rather than drawn in code.
const GENERATED_PICTURES: Array[String] = [
	"res://art/objects/sacred_tree_icon.png",
	"res://art/objects/sacred_tree_sheet.png",
	"res://art/objects/door_icon.png",
	"res://art/objects/door_sheet.png",
]
## The plain stand-in picture: a grey checker (docs/itch_release_proposals.md, 4).
const STAND_IN_PICTURE := "res://art/placeholders/stand_in.png"

## For a suite: behave as the public build would, in the editor or the harness.
static var pretend := false


## Whether this is the public build.
static func on() -> bool:
	return pretend or OS.has_feature("public_build")


## Whether the stand-in sound `event` is silent here: in the public build, all but those kept.
static func silences(event: String) -> bool:
	return on() and not STAND_INS_KEPT.has(event)


## `texture` as this build shows it: in the public build, one of my stand-in picture files (GENERATED_PICTURES) is the plain
## stand-in picture instead; anything else is itself.
static func picture(texture: Texture2D) -> Texture2D:
	if texture == null or not on() or not GENERATED_PICTURES.has(texture.resource_path):
		return texture
	return load(STAND_IN_PICTURE)


## Of Arena Mode's `encounters`, those this build offers: every one, or the public build's first few.
static func arena_stages(encounters: Array) -> Array:
	var offered := encounters.filter(func(encounter): return encounter != null)
	return offered.slice(0, PUBLIC_ARENA_STAGES) if on() else offered
