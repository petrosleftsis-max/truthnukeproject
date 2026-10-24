@icon("res://art/editor_icons/encounter.svg")
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
## named "TileMap" - maps/terrain_template.tscn is the template; duplicate it and
## repaint to make a new map. Instantiated at runtime by GameScene, which is
## what lets every encounter have its own terrain without duplicating the rest
## of the scene.
@export var terrain_scene: PackedScene
@export_group("When it ends")
## A conversation to play the moment this battle is won, before the result
## panel comes up. Leave it empty and the panel comes up straight away.
##
## Written like any other: a .dialogue file in res://dialogue. The result panel
## waits for it to finish, so it can be as long as it needs to be.
@export var victory_dialogue: Resource
## Which title inside that file to start at. "start" unless you say otherwise.
@export var victory_dialogue_title: String = "start"
## The same, for losing it. A defeat is worth a word as much as a win is.
@export var defeat_dialogue: Resource
@export var defeat_dialogue_title: String = "start"
## The Victory Dialogue decides what becomes of whoever was taken alive, and the
## results offer no Question the Prisoners. It can ask how the fight went and
## act on it - Campaign.taken_alive("sellsword"), got_away, fell, question,
## let_go, hand_over (Campaign "The last fight").
@export var dialogue_decides_prisoners: bool = false
## Winning this one is the end of the story it belongs to, so the result panel
## offers the title screen and nothing else - no Back to the battle list, no
## Continue on to the map. For a fight that finishes a demo, or a chapter.
##
## Only on a win. Losing the last fight of a chapter still wants the way back,
## because the player is going to want another go at it.
@export var victory_ends_the_run: bool = false
## A milestone: winning this fight in the story takes the party to this level
## (Campaign.reach_level). 0 for none. Only when the fight was walked into from
## a map - a fight opened from Battle Select is played at its spawns' levels and
## changes nobody.
@export_range(0, 20) var party_reaches_level: int = 0
## Gold the party is given for winning it, in the story or a dungeon
## (Campaign.give_gold). Not from Battle Select, which has no purse to fill.
@export_range(0, 9999) var gold_reward: int = 0
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

@export_group("Who fights")
## Who fills the player tiles, in order, instead of the travelling party. Empty
## - which is every encounter written by hand - means the party. A stealth map
## sets it for the fight it starts: whoever was sneaking, and whatever backup
## that map says comes running (see StealthSetup).
@export var fighters: Array[String] = []
## Starts the fight straight away, everybody on the tile they spawn on, with no
## arranging the party first. For a fight whose starting positions are the
## point - somebody caught exactly where they stood.
@export var skip_deployment: bool = false

@export_group("The arena")
## What the arena does by itself from the start - rocks falling, the floor
## burning (HazardDefinition). A boss's phase can start more.
@export var hazards: Array[HazardDefinition] = []
## The ways out, as tiles: somebody broken and running gets away once they stand
## on one, and does all they can to reach one - walking, and their skills for
## getting about (Combat "Getting away"). Place them in the encounter editor.
## Empty, there is no getting away: whoever breaks and runs only keeps their
## distance (runners_with_nowhere_to_run says who that would be).
@export var escape_points: Array[Vector2i] = []

@export_group("Heights")
## Tiles to climb up from, as tiles (Combat "Heights"): from one, a walker can
## step up onto the high ground beside it - a tile that stops a walker but not a
## flier, and is not see-through (barrels, a low wall; not water) - or, under a
## floor above, up onto it (stairs, a ladder). Getting down is from anywhere.
## The TileSet can mark tiles Climb as well. Place them in the encounter editor.
@export var climb_points: Array[Vector2i] = []
## For a map with more than one floor: which area of the terrain is which, and
## how they lie over each other (FloorDefinition). Empty is one floor.
@export var floors: Array[FloorDefinition] = []


## The enemies here who run when they break (When Broken: Flee), by name, if
## this map has no ways out for them to run to - for the encounter editor and
## the fight to warn about. Empty when there are ways out. `definitions` is
## key -> CombatantDefinition; left out, they are read from their folders.
func runners_with_nowhere_to_run(definitions: Dictionary = {}) -> Array[String]:
	var names: Array[String] = []
	if not escape_points.is_empty():
		return names
	var everybody: Dictionary = definitions if not definitions.is_empty() else DataFolder.combatants()
	for spawn in spawns:
		if spawn == null or spawn.side != 1:
			continue
		var definition: CombatantDefinition = everybody.get(spawn.combatant_key)
		if runs_when_broken(definition) and not names.has(definition.name):
			names.append(definition.name)
	return names


## Whether `definition` is somebody who breaks and runs - not a thing on the
## map, not immune to breaking, and not one to surrender instead.
static func runs_when_broken(definition: CombatantDefinition) -> bool:
	return definition != null and not definition is BattleObjectDefinition and definition.when_broken == 0 \
		and not definition.immune_to.has(Immunity.Kind.BREAKING)


## The tiles units are allowed to occupy on this encounter's map: the explicit
## playable_region if one is set, otherwise everything `tile_map` has painted.
## Never a hard-coded size - that is what previously limited every battle to
## the same 36x21 area regardless of the map.
func resolve_playable_region(tile_map: TileMap) -> Rect2i:
	if playable_region.size.x > 0 and playable_region.size.y > 0:
		return playable_region
	return tile_map.get_used_rect()
