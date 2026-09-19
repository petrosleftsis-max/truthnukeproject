extends Node
class_name GameScene
## Root of a battle. Works out which encounter is being fought, builds that
## encounter's map, and hands it to Combat - all before anything else in the
## scene starts up.
##
## This is what lets a single scene play every encounter. The terrain is not
## part of game.tscn; it is instantiated from the EncounterDefinition, so
## adding a battle on a new map needs no new scene and no duplicated wiring.
##
## Timing matters here: this runs in _enter_tree rather than _ready because
## Godot sends _enter_tree top-down but _ready bottom-up, so a parent's _ready
## fires *after* its children's. CController and Combat both look for
## "../Terrain/TileMap" in their own _ready, so the terrain has to exist before
## then - which _enter_tree guarantees and _ready would not.


## Used when this scene is run directly (F6 in the editor) instead of being
## entered through the level select, so a battle is still playable on its own
## while you work on it. Ignored whenever the level select has chosen one.
@export var fallback_encounter: EncounterDefinition
@export var combat: Combat


func _enter_tree():
	var encounter = Campaign.current_encounter
	if encounter == null:
		encounter = fallback_encounter
	if encounter == null:
		push_error("GameScene has no encounter to run: Campaign.current_encounter is unset and no fallback_encounter is assigned.")
		return
	if combat == null:
		push_error("GameScene has no Combat node assigned.")
		return
	combat.encounter = encounter
	_build_terrain(encounter)
	# Named rather than a stream so it matches what dialogue writes, and so
	# Music can tell "already playing" from "start this" by name.
	if encounter.music != "":
		Music.play(encounter.music)


## Instantiates the encounter's map and puts it in as "Terrain" - the name the
## rest of the scene addresses it by. Added as the first child so it draws
## underneath the movement/skill overlays CController draws, matching the node
## order the scene used when the terrain was a fixed part of it.
func _build_terrain(encounter: EncounterDefinition):
	if encounter.terrain_scene == null:
		push_error("Encounter '%s' has no terrain_scene assigned - there is no map to fight on." % encounter.display_name)
		return
	var terrain = encounter.terrain_scene.instantiate()
	terrain.name = "Terrain"
	add_child(terrain)
	move_child(terrain, 0)
	# A battle is played on tiles, so it gets the grid. Which terrain scenes
	# happened to save it switched on was a coin toss - the crossroads shipped
	# without one while the lab and the city had one - and the crossroads
	# terrain is the same scene exploration walks about on, so no per-scene
	# setting could tell the two apart. The mode decides instead, exactly as
	# ExplorationScene switches it off at its end.
	_show_grid(terrain)


## Turns on any grid overlay the terrain brought with it, wherever it sits.
func _show_grid(node: Node):
	for child in node.get_children():
		if child is GridOverlay:
			child.visible = true
		else:
			_show_grid(child)
