extends Resource
class_name EncounterDefinition
## One battle: which map it is fought on, and who starts where.
##
## To add an encounter: right-click in the FileSystem dock -> New Resource ->
## EncounterDefinition, fill it in, and add it to the Encounters list on the
## LevelSelect scene's root node. No new code and no duplicated scene - the
## same scenes/game.tscn plays every encounter.


@export var display_name: String = "Encounter"
## Shown under the name on the level select button. Optional.
@export_multiline var description: String = ""
## The map this is fought on. Its root must be a Node2D with a TileMap child
## named "TileMap" - scenes/terrain.tscn is the template; duplicate it and
## repaint to make a new map. Instantiated at runtime by GameScene, which is
## what lets every encounter have its own terrain without duplicating the rest
## of the scene.
@export var terrain_scene: PackedScene
@export_group("When it ends")
## A conversation to play the moment this battle is won, before the result
## panel comes up. Leave it empty and the panel comes up straight away.
##
## Written like any other: a .dialogue file in res://Dialogue. The result panel
## waits for it to finish, so it can be as long as it needs to be.
@export var victory_dialogue: Resource
## Which title inside that file to start at. "start" unless you say otherwise.
@export var victory_dialogue_title: String = "start"
## The same, for losing it. A defeat is worth a word as much as a win is.
@export var defeat_dialogue: Resource
@export var defeat_dialogue_title: String = "start"
## Winning this one is the end of the story it belongs to, so the result panel
## offers the title screen and nothing else - no Back to the battle list, no
## Continue on to the map. For a fight that finishes a demo, or a chapter.
##
## Only on a win. Losing the last fight of a chapter still wants the way back,
## because the player is going to want another go at it.
@export var victory_ends_the_run: bool = false
@export var spawns: Array[SpawnDefinition]
## The track this fight opens on, by name - "battle" finds audio/music/battle
## with any supported extension, the same names dialogue uses.
##
## Left empty means "leave the music alone", so an encounter without one keeps
## whatever was already playing rather than dropping into silence. Starting the
## track already playing does nothing, so walking into a second fight with the
## same music does not restart it.
@export var music: String = ""
## Optional. Restricts the playable area to these tile coordinates, for
## fencing off a decorative border that units should not be able to walk into.
## Leave the size at zero to use every tile the map actually has painted,
## which is what you want unless you have a reason otherwise.
@export var playable_region: Rect2i = Rect2i()


## The tiles units are allowed to occupy on this encounter's map: the explicit
## playable_region if one is set, otherwise everything `tile_map` has painted.
## Never a hard-coded size - that is what previously limited every battle to
## the same 36x21 area regardless of the map.
func resolve_playable_region(tile_map: TileMap) -> Rect2i:
	if playable_region.size.x > 0 and playable_region.size.y > 0:
		return playable_region
	return tile_map.get_used_rect()
