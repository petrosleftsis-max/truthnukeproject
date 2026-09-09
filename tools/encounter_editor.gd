@tool
extends Node2D
class_name EncounterEditor
## Editor-only tool for placing an encounter's combatants on its actual map,
## instead of typing tile coordinates into a .tres by hand.
##
## How to use it:
##   1. Open scenes/encounter_editor.tscn.
##   2. Select the root node and pick an Encounter in the inspector. The map
##      appears with a marker for every spawn already in it.
##   3. Drag the markers. They snap to tile centres.
##      - To add a combatant: duplicate a marker (Ctrl+D) and change its
##        Combatant Key / Side in the inspector.
##      - To remove one: delete the marker.
##   4. Press "Save spawns to encounter".
##
## Save refuses to write anything invalid - off the map, on a hole in a
## non-rectangular map, on terrain that blocks that unit's movement class, on
## a tile another marker already has, or with no combatant chosen - and tells
## you which marker is wrong. So a saved encounter is always playable.
##
## The terrain here is a read-only backdrop. Paint maps in the terrain scene
## itself, where the TileMap tools are set up; this tool never writes to it.


## The encounter being laid out. Assigning one rebuilds the map and markers.
@export var encounter: EncounterDefinition:
	set(value):
		encounter = value
		if is_node_ready():
			rebuild()

@export_tool_button("Reload from encounter") var reload_action = rebuild
@export_tool_button("Save spawns to encounter") var save_action = save_to_encounter

const TERRAIN_NODE = "TerrainPreview"
const SPAWNS_NODE = "Spawns"


func _ready():
	if Engine.is_editor_hint() and get_child_count() == 0:
		rebuild()


## Rebuilds both the map preview and the markers from the encounter resource,
## throwing away any unsaved dragging.
func rebuild():
	_clear()
	if encounter == null:
		return
	var tile_map = _build_terrain()
	_build_markers(tile_map)


func _clear():
	for child in get_children():
		remove_child(child)
		child.queue_free()


## The scene's own root, so nodes created here belong to it and can be clicked
## and dragged in the 2D viewport like any hand-placed node.
func _scene_owner() -> Node:
	if Engine.is_editor_hint() and get_tree() != null and get_tree().edited_scene_root != null:
		return get_tree().edited_scene_root
	return self


func _build_terrain() -> TileMap:
	if encounter.terrain_scene == null:
		push_warning("Encounter '%s' has no terrain_scene, so there is no map to place anything on." % encounter.display_name)
		return null
	var terrain = encounter.terrain_scene.instantiate()
	terrain.name = TERRAIN_NODE
	add_child(terrain)
	terrain.owner = _scene_owner()
	# The terrain scene ships with a grid overlay it normally keeps hidden -
	# exactly what's wanted while placing units, so turn it on for the preview
	# only. This never touches the terrain scene on disk.
	var grid = terrain.get_node_or_null("Grid")
	if grid != null:
		grid.visible = true
	return terrain.get_node_or_null("TileMap")


func _build_markers(tile_map: TileMap):
	var container = Node2D.new()
	container.name = SPAWNS_NODE
	add_child(container)
	container.owner = _scene_owner()
	var tile_size = _tile_size(tile_map)
	for spawn in encounter.spawns:
		var marker = SpawnMarker.new()
		marker.name = "Spawn_%s" % spawn.combatant_key
		marker.tile_size = tile_size
		marker.combatant_key = spawn.combatant_key
		marker.side = spawn.side
		marker.display_name = spawn.display_name
		marker.position = Vector2(spawn.position * tile_size) + Vector2(tile_size, tile_size) * 0.5
		container.add_child(marker)
		marker.owner = _scene_owner()


func _tile_size(tile_map: TileMap) -> int:
	if tile_map != null and tile_map.tile_set != null:
		return tile_map.tile_set.tile_size.x
	return 32


func markers() -> Array:
	var container = get_node_or_null(SPAWNS_NODE)
	if container == null:
		return []
	var found = []
	for child in container.get_children():
		if child is SpawnMarker:
			found.append(child)
	return found


## Why `marker` can't be placed where it is, or "" if it's fine. Mirrors the
## rules the game itself enforces, so anything this accepts is genuinely
## playable: on the map, on a real tile, and on terrain its movement class can
## actually enter.
func placement_problem(marker: SpawnMarker, tile_map: TileMap) -> String:
	if marker.combatant_key == "":
		return "has no combatant chosen"
	var definition = marker.definition()
	if definition == null:
		return "uses unknown combatant key '%s'" % marker.combatant_key
	if tile_map == null:
		return "has no map to stand on"
	var tile = marker.grid_position()
	if not tile_map.get_used_rect().has_point(tile):
		return "is at %s, off the edge of the map" % tile
	var data = tile_map.get_cell_tile_data(0, tile)
	if data == null:
		return "is at %s, on an unpainted hole in the map" % tile
	if definition.class_m in data.get_custom_data("Blocks"):
		return "is at %s, on terrain its movement class can't enter" % tile
	return ""


## Validates every marker and writes them back to the encounter resource.
## Writes nothing at all unless everything checks out - a half-saved encounter
## would be worse than an unsaved one.
func save_to_encounter():
	if encounter == null:
		push_error("No encounter assigned - nothing to save to.")
		return
	if encounter.resource_path == "":
		push_error("The assigned encounter has no file on disk to save to.")
		return
	var terrain = get_node_or_null(TERRAIN_NODE)
	var tile_map: TileMap = terrain.get_node_or_null("TileMap") if terrain != null else null

	var problems = []
	var claimed = {}
	var placed = markers()
	if placed.is_empty():
		problems.append("There are no markers to save.")
	for marker in placed:
		var problem = placement_problem(marker, tile_map)
		if problem != "":
			problems.append("%s %s" % [marker.effective_name(), problem])
			continue
		var tile = marker.grid_position()
		if claimed.has(tile):
			problems.append("%s and %s are both on %s" % [marker.effective_name(), claimed[tile], tile])
			continue
		claimed[tile] = marker.effective_name()
	var players = 0
	var enemies = 0
	for marker in placed:
		if marker.side == 0:
			players += 1
		else:
			enemies += 1
	if players == 0:
		problems.append("There are no player-side combatants - the encounter would be unplayable.")
	if enemies == 0:
		problems.append("There are no enemies - the encounter would be over immediately.")

	if not problems.is_empty():
		push_error("Encounter not saved. Fix these first:\n  - %s" % "\n  - ".join(problems))
		return

	# Players first, then enemies, each ordered top-to-bottom - purely so the
	# saved file reads in a predictable order rather than marker creation order.
	placed.sort_custom(func(a, b):
		if a.side != b.side:
			return a.side < b.side
		var pa = a.grid_position()
		var pb = b.grid_position()
		if pa.y != pb.y:
			return pa.y < pb.y
		return pa.x < pb.x
	)

	var spawns: Array[SpawnDefinition] = []
	for marker in placed:
		var spawn = SpawnDefinition.new()
		spawn.combatant_key = marker.combatant_key
		spawn.side = marker.side
		spawn.position = marker.grid_position()
		spawn.display_name = marker.display_name
		spawns.append(spawn)
	encounter.spawns = spawns

	var error = ResourceSaver.save(encounter, encounter.resource_path)
	if error != OK:
		push_error("Failed to save %s (error %d)." % [encounter.resource_path, error])
		return
	print("Saved %d spawns (%d players, %d enemies) to %s" % [spawns.size(), players, enemies, encounter.resource_path])
