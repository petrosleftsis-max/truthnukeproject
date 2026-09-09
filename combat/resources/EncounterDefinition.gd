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
@export var spawns: Array[SpawnDefinition]
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
