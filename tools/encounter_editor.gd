@tool
@icon("res://art/editor_icons/fight_spot.svg")
extends Node2D
class_name EncounterEditor
## Editor-only tool for placing an encounter's combatants on its actual map,
## instead of typing tile coordinates into a .tres by hand.
##
## How to use it:
##   1. Open tools/encounter_editor.tscn.
##   2. Select the root node and pick an Encounter in the inspector. The map
##      appears with a marker for every spawn already in it.
##   3. Drag the markers. They snap to tile centres.
##      - To add a combatant: duplicate a marker (Ctrl+D) and change its
##        Combatant Key / Side in the inspector.
##      - To remove one: delete the marker.
##   4. Ways out - the tiles a broken enemy runs for (escape_points): press
##      "Add a way out" for a marker, drag it where the way out is, Ctrl+D for
##      another, delete to take one away.
##   5. Climb tiles - where a walker climbs up onto high ground or a floor
##      above (climb_points): "Add a climb tile", the same way.
##   6. Press "Save spawns to encounter". It saves the ways out and climb tiles too.
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
@export_tool_button("Add a way out") var escape_action = add_escape_point
@export_tool_button("Add a climb tile") var climb_action = add_climb_point

## What the editor makes of the markers right now, and what happened the last
## time Save was pressed. Shown here rather than only pushed to the Output
## panel because a refused save is otherwise completely silent: the button is
## pressed, nothing changes, and the reason is on a dock that may not even be
## open. Read-only - anything typed here is overwritten within the second.
@export_multiline var status: String = ""

var _status_countdown := 0.0

const TERRAIN_NODE = "TerrainPreview"
const SPAWNS_NODE = "Spawns"
const ESCAPES_NODE = "WaysOut"
const CLIMBS_NODE = "ClimbPoints"


## Set in _ready, acted on in _process. Rebuilding cannot happen during _ready
## itself: the editor is still registering this scene's nodes in its own
## bookkeeping at that point, and clearing them out from under it raises
## "Condition !p_node->is_inside_tree() is true" from EditorData::add_node.
## One frame later the scene is fully open and its nodes are ours to replace.
var _needs_rebuild := false


func _ready():
	if not Engine.is_editor_hint():
		return
	# Always rebuild, even though there are already children. The preview and
	# markers are nodes like any other, so saving this scene saves them too -
	# a snapshot of whichever encounter was assigned at the time. Keeping that
	# snapshot means opening the scene shows the last session's markers rather
	# than the assigned encounter's, and adding spawns to the encounter appears
	# to do nothing at all. rebuild() throws the snapshot away.
	_needs_rebuild = true


## Puts the map back if it has gone missing - the preview was deleted by hand,
## or a terrain_scene was assigned to an encounter that had none, which leaves
## the editor showing markers floating over nothing. Cheap to check, and it
## saves knowing that Reload is the button that fixes it.
##
## Deliberately not triggered by markers being absent: an encounter with no
## spawns yet legitimately has none, and rebuilding every frame over that would
## make new markers impossible to keep.
func _process(delta):
	if not Engine.is_editor_hint():
		return
	if _needs_rebuild:
		_needs_rebuild = false
		rebuild()
		return
	_status_countdown -= delta
	if _status_countdown <= 0.0:
		_status_countdown = 0.5
		_sync_if_encounter_changed()
		_refresh_status()
	if encounter == null or encounter.terrain_scene == null:
		return
	if get_node_or_null(TERRAIN_NODE) == null:
		rebuild()


## Picks up edits made to the encounter itself - typing gear or a level into
## its spawn list in the inspector, or editing the .tres by hand - while this
## scene sits open in another tab.
##
## Only while nothing has been changed here, where there is nothing to lose by
## replacing the markers. If both sides have moved on, the markers are left
## alone and Save refuses instead: quietly throwing away one of the two sets of
## edits is the one thing this must not do, and there is no way to tell from
## here which of them was meant.
func _sync_if_encounter_changed():
	if encounter == null or _encounter_fingerprint() == _built_from:
		return
	if _marker_fingerprint() != _built_from:
		return
	rebuild()


## Keeps the status line describing what Save would do if pressed now, so a
## problem is visible before the button is reached rather than after.
func _refresh_status():
	var problems = _problems_with_layout()
	var summary = _map_extent_note() + "\n"
	if problems.is_empty():
		summary += "Ready: %d spawns, %d ways out and %d climb tiles to save." % [markers().size(), escape_markers().size(), climb_markers().size()]
	else:
		summary += "Cannot save yet:\n  - %s" % "\n  - ".join(problems)
	var stuck = runner_note()
	if stuck != "":
		summary += "\n" + stuck
	if summary == status:
		return
	status = summary
	notify_property_list_changed()


## Where the painted floor actually is, in tiles.
##
## A map is far bigger than one screenful and its corners are usually empty, so
## a marker left at the origin can be standing on nothing with nothing nearby to
## see. From behind the viewport, "the terrain didn't load" and "you are looking
## at an unpainted corner of it" are the same black rectangle; this says which.
func _map_extent_note() -> String:
	var terrain = get_node_or_null(TERRAIN_NODE)
	var tile_map: TileMap = terrain.get_node_or_null("TileMap") if terrain != null else null
	if tile_map == null:
		return "No terrain loaded - set the encounter's Terrain Scene, then press Reload."
	var rect = tile_map.get_used_rect()
	if rect.size == Vector2i.ZERO:
		return "The terrain loaded, but nothing is painted on it yet."
	# Inclusive corners: end is one past the last tile, and a range quoted to
	# somebody about to type coordinates has to name a tile that exists.
	return "Map: tiles %s to %s are painted. Select a marker and press F to look at it." % [
		rect.position, rect.end - Vector2i.ONE]


## Puts a message in the status line and holds it there. Without the hold, the
## live refresh above would replace "Saved 6 spawns" with "Ready to save"
## within half a second - which looks exactly like the button doing nothing,
## the very thing this whole status line exists to stop.
func _announce():
	_status_countdown = 8.0
	notify_property_list_changed()


## Rebuilds both the map preview and the markers from the encounter resource,
## throwing away any unsaved dragging.
func rebuild():
	# A hidden root hides the map, the grid and every marker at once, while the
	# Scene dock goes on listing them - which looks exactly like the terrain
	# failing to load, and sends you looking for the bug anywhere but the eye
	# icon. This scene is nothing but the tool for placing spawns; there is no
	# version of using it where it should be invisible.
	visible = true
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


## Gives `node` to the scene, so it shows in the Scene dock and is saved with
## everything else.
##
## Only when there is genuinely a scene tree to give it to. The editor
## instantiates this scene for its own purposes too - scanning the project,
## making thumbnails - and those copies are built outside any tree, where
## assigning an owner is an error rather than a no-op.
func _adopt(node: Node):
	var scene_owner = _scene_owner()
	if scene_owner == null or not scene_owner.is_inside_tree() or not node.is_inside_tree():
		return
	node.owner = scene_owner


func _build_terrain() -> TileMap:
	if encounter.terrain_scene == null:
		push_warning("Encounter '%s' has no terrain_scene, so there is no map to place anything on." % encounter.display_name)
		return null
	var terrain = encounter.terrain_scene.instantiate()
	terrain.name = TERRAIN_NODE
	add_child(terrain)
	_adopt(terrain)
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
	_adopt(container)
	var tile_size = _tile_size(tile_map)
	for spawn in encounter.spawns:
		var marker = SpawnMarker.new()
		marker.name = "Spawn_%s" % spawn.combatant_key
		marker.tile_size = tile_size
		marker.combatant_key = spawn.combatant_key
		marker.side = spawn.side
		marker.display_name = spawn.display_name
		marker.level = spawn.level
		marker.weapon_base = spawn.weapon_base
		marker.defense = spawn.defense
		marker.starting_items = spawn.starting_items.duplicate()
		marker.equipment = spawn.equipment.duplicate()
		marker.arrives_on_round = spawn.arrives_on_round
		marker.arrives_after_deaths = spawn.arrives_after_deaths
		marker.arrives_on_cue = spawn.arrives_on_cue
		marker.surprised = spawn.surprised
		marker.invisible = spawn.invisible
		marker.subclass = spawn.subclass
		marker.position = Vector2(spawn.position * tile_size) + Vector2(tile_size, tile_size) * 0.5
		container.add_child(marker)
		_adopt(marker)
	var ways_out = _escape_container()
	for tile in encounter.escape_points:
		_put_escape_marker(ways_out, tile, tile_size)
	var climbs = _climb_container()
	for tile in encounter.climb_points:
		_put_climb_marker(climbs, tile, tile_size)
	_built_from = _encounter_fingerprint()


## Where the climb tiles go, made if it is not there yet.
func _climb_container() -> Node2D:
	var container = get_node_or_null(CLIMBS_NODE)
	if container == null:
		container = Node2D.new()
		container.name = CLIMBS_NODE
		add_child(container)
		_adopt(container)
	return container


func _put_climb_marker(container: Node2D, tile: Vector2i, tile_size: int) -> ClimbMarker:
	var marker = ClimbMarker.new()
	marker.name = "Climb"
	marker.tile_size = tile_size
	marker.position = Vector2(tile * tile_size) + Vector2(tile_size, tile_size) * 0.5
	container.add_child(marker, true)
	_adopt(marker)
	return marker


## A climb tile (Combat "Heights"), put in the middle of the map to be dragged
## beside the high ground or under the floor above it climbs to - or beside the
## last one.
func add_climb_point():
	if encounter == null:
		status = "Pick an encounter first."
		_announce()
		return
	var terrain = get_node_or_null(TERRAIN_NODE)
	var tile_map: TileMap = terrain.get_node_or_null("TileMap") if terrain != null else null
	var tile_size = _tile_size(tile_map)
	var existing = climb_markers()
	var tile := Vector2i.ZERO
	if not existing.is_empty():
		tile = existing[-1].grid_position() + Vector2i.RIGHT
	elif tile_map != null:
		var rect = tile_map.get_used_rect()
		tile = rect.position + rect.size / 2
	_put_climb_marker(_climb_container(), tile, tile_size)
	status = "A climb tile added at %s - find it under %s in the Scene dock, drag it where it belongs, then Save." % [tile, CLIMBS_NODE]
	_announce()


## The climb-tile markers (ClimbMarker).
func climb_markers() -> Array:
	var container = get_node_or_null(CLIMBS_NODE)
	if container == null:
		return []
	return container.get_children().filter(func(child): return child is ClimbMarker)


## The tiles the climb markers are on, in reading order.
func _climb_tiles() -> Array:
	var tiles := climb_markers().map(func(marker): return marker.grid_position())
	tiles.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
	return tiles


## Where the ways out go, made if it is not there yet.
func _escape_container() -> Node2D:
	var container = get_node_or_null(ESCAPES_NODE)
	if container == null:
		container = Node2D.new()
		container.name = ESCAPES_NODE
		add_child(container)
		_adopt(container)
	return container


func _put_escape_marker(container: Node2D, tile: Vector2i, tile_size: int) -> EscapeMarker:
	var marker = EscapeMarker.new()
	marker.name = "WayOut"
	marker.tile_size = tile_size
	marker.position = Vector2(tile * tile_size) + Vector2(tile_size, tile_size) * 0.5
	container.add_child(marker, true)
	_adopt(marker)
	return marker


## A way out, put in the middle of the map to be dragged where it belongs -
## or beside the last one, so a second does not land on the first.
func add_escape_point():
	if encounter == null:
		status = "Pick an encounter first."
		_announce()
		return
	var terrain = get_node_or_null(TERRAIN_NODE)
	var tile_map: TileMap = terrain.get_node_or_null("TileMap") if terrain != null else null
	var tile_size = _tile_size(tile_map)
	var existing = escape_markers()
	var tile := Vector2i.ZERO
	if not existing.is_empty():
		tile = existing[-1].grid_position() + Vector2i.RIGHT
	elif tile_map != null:
		var rect = tile_map.get_used_rect()
		tile = rect.position + rect.size / 2
	_put_escape_marker(_escape_container(), tile, tile_size)
	status = "A way out added at %s - find it under %s in the Scene dock, drag it where it belongs, then Save." % [tile, ESCAPES_NODE]
	_announce()


## What the encounter said when these markers were made from it. The markers
## are a copy, not a live view, so anything done to the encounter itself after
## this point is invisible here - and Save writes the markers, which would put
## the old values back over it. Remembering what was copied is what lets that
## be noticed instead of silently happening.
var _built_from := ""


## One line per spawn, in encounter order. Text rather than the spawn objects
## themselves so two snapshots can just be compared, with no dependence on how
## Godot decides two Resources or two Dictionaries are equal.
func _encounter_fingerprint() -> String:
	if encounter == null:
		return ""
	return _fingerprint(encounter.spawns) + _escape_fingerprint(encounter.escape_points) \
		+ "\nclimbs: %s" % [_sorted(encounter.climb_points)]


## The same, read off the markers, so it can be told whether the markers or the
## encounter is the side that has moved on.
func _marker_fingerprint() -> String:
	return _fingerprint(markers().map(_spawn_from)) + _escape_fingerprint(_escape_tiles()) \
		+ "\nclimbs: %s" % [_sorted(_climb_tiles())]


## `tiles` in a set order.
static func _sorted(tiles: Array) -> Array:
	var sorted := tiles.duplicate()
	sorted.sort()
	return sorted


## The ways out, in a set order, as a line.
static func _escape_fingerprint(tiles: Array) -> String:
	var sorted := tiles.duplicate()
	sorted.sort()
	return "\nways out: %s" % [sorted]


## The tiles the way-out markers are on, in reading order.
func _escape_tiles() -> Array:
	var tiles := escape_markers().map(func(marker): return marker.grid_position())
	tiles.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
	return tiles


## Every field Save writes, a spawn to a line. A field missing here is one that
## can be edited on one side without the other noticing, and Save then writes
## over it - which is how gear typed into the encounter used to be lost.
static func _fingerprint(spawns: Array) -> String:
	var lines := PackedStringArray()
	for spawn in spawns:
		lines.append("%s|%d|%s|%s|%d|%s|%d|%d|%s|%s|%d|%d|%s|%s|%s" % [spawn.combatant_key, spawn.side, spawn.position,
			spawn.display_name, spawn.level, spawn.subclass, spawn.weapon_base, spawn.defense,
			",".join(spawn.starting_items), ",".join(spawn.equipment), spawn.arrives_on_round, spawn.arrives_after_deaths, spawn.arrives_on_cue,
			spawn.surprised, spawn.invisible])
	return "\n".join(lines)


## The SpawnDefinition Save writes for `marker`. Every field a spawn has must be
## carried here, and back in rebuild(): one that is not goes back to its default
## on every Save. Late arrivals and the surprised flag once did.
func _spawn_from(marker: SpawnMarker) -> SpawnDefinition:
	var spawn = SpawnDefinition.new()
	spawn.combatant_key = marker.combatant_key
	spawn.side = marker.side
	spawn.position = marker.grid_position()
	spawn.display_name = marker.display_name
	spawn.level = marker.level
	spawn.weapon_base = marker.weapon_base
	spawn.defense = marker.defense
	spawn.starting_items = marker.starting_items.duplicate()
	spawn.equipment = marker.equipment.duplicate()
	spawn.arrives_on_round = marker.arrives_on_round
	spawn.arrives_after_deaths = marker.arrives_after_deaths
	spawn.arrives_on_cue = marker.arrives_on_cue
	spawn.surprised = marker.surprised
	spawn.invisible = marker.invisible
	spawn.subclass = marker.subclass
	return spawn


func _tile_size(tile_map: TileMap) -> int:
	if tile_map != null and tile_map.tile_set != null:
		return tile_map.tile_set.tile_size.x
	return Grid.TILE_SIZE


## A marker works out its tile from its own position, which is only the tile
## you can see it on while the container holding it sits at the origin. It is
## easy to nudge that container by accident in the 2D viewport - and then every
## marker reads as being several tiles from where it looks. Rather than refuse
## to save, push the offset down into the markers: they stay exactly where they
## appear on the map, and now agree about which tile that is.
func _reanchor_spawn_container():
	for node_name in [SPAWNS_NODE, ESCAPES_NODE, CLIMBS_NODE]:
		var container = get_node_or_null(node_name)
		if container == null or container.position == Vector2.ZERO:
			continue
		var offset = container.position
		for marker in container.get_children():
			if marker is Node2D:
				marker.position += offset
		container.position = Vector2.ZERO


## Whether the encounter's named track resolves to a file, so a typo shows up
## here rather than as a fight that opens in unexplained silence.
##
## The lookup rules live on Music; this only mirrors where it looks, because a
## @tool script cannot call into an autoload that is not running in the editor.
func _music_exists(track: String) -> bool:
	if track.begins_with("res://") or track.begins_with("user://"):
		return ResourceLoader.exists(track)
	for extension in Music.EXTENSIONS:
		if ResourceLoader.exists("%s/%s.%s" % [Music.MUSIC_DIR, track, extension]):
			return true
	return false


func markers() -> Array:
	var container = get_node_or_null(SPAWNS_NODE)
	if container == null:
		return []
	var found = []
	for child in container.get_children():
		if child is SpawnMarker:
			found.append(child)
	return found


## A word about enemies placed here who run when they break, on a map with no
## ways out for them - they could never get away. "" when there is nothing to
## say. Only a note: such a fight still saves and plays.
func runner_note() -> String:
	if not escape_markers().is_empty():
		return ""
	var names := []
	for marker in markers():
		var found = marker.definition()
		if marker.side == 1 and EncounterDefinition.runs_when_broken(found) and not names.has(found.name):
			names.append(found.name)
	if names.is_empty():
		return ""
	return "Note: no ways out, so %s - who run when broken - can never get away. Add a way out, or set their When Broken to Surrender." % ", ".join(names)


## The way-out markers (EscapeMarker).
func escape_markers() -> Array:
	var container = get_node_or_null(ESCAPES_NODE)
	if container == null:
		return []
	return container.get_children().filter(func(child): return child is EscapeMarker)


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
	# Every tile of theirs, for somebody bigger than one - and for anything
	# Monstrous or bigger, only what stops a flier stops it (Combat.terrain_class).
	var ground: int = 1 if definition.size >= Sizes.Size.MONSTROUS else definition.class_m
	for tile in marker.footprint():
		if not tile_map.get_used_rect().has_point(tile):
			return "is at %s, off the edge of the map" % tile
		var data = tile_map.get_cell_tile_data(0, tile)
		if data == null:
			return "is at %s, on an unpainted hole in the map" % tile
		var blocks: Array = data.get_custom_data("Blocks")
		# Up on high ground is somewhere to start, on a map with heights (Combat
		# "Heights"): what stops a walker and not a flier, and is not see-through.
		var high: bool = blocks.has(0) and not blocks.has(1) and not blocks.has(3) \
			and (not climb_markers().is_empty() or encounter.floors.size() > 1)
		if ground in blocks and not (high and marker.footprint().size() == 1):
			return "is at %s, on terrain its movement class can't enter" % tile
	return ""


## Validates every marker and writes them back to the encounter resource.
## Writes nothing at all unless everything checks out - a half-saved encounter
## would be worse than an unsaved one.
## Everything standing between the current markers and a saved encounter.
## Empty means Save will go through. The status line and the Save button both
## read this, so what the inspector reports and what the button does can never
## drift apart.
func _problems_with_layout() -> Array:
	var problems = []
	if encounter == null:
		problems.append("No encounter assigned - there is nothing to save to.")
		return problems
	if encounter.resource_path == "":
		problems.append("This encounter is built into the editor scene rather than being a file of its own, so there is nowhere to save it. Assign one of res://data/encounters/*.tres to Encounter and press Reload, or save this one to a file first (in the inspector, the dropdown next to the resource -> Save As).")
	if _encounter_fingerprint() != _built_from and _marker_fingerprint() != _built_from:
		problems.append("The encounter has been edited since these markers were built, and the markers have been changed here too - saving would write the markers over those edits. Press 'Reload from encounter' to take the encounter's version instead, which discards the changes made here.")
	if encounter.music != "" and not _music_exists(encounter.music):
		problems.append("Music track '%s' is not in %s - the fight would start in silence." % [encounter.music, Music.MUSIC_DIR])
	var terrain = get_node_or_null(TERRAIN_NODE)
	var tile_map: TileMap = terrain.get_node_or_null("TileMap") if terrain != null else null

	var claimed = {}
	var placed = markers()
	if placed.is_empty():
		problems.append("There are no markers to save.")
	for marker in placed:
		var problem = placement_problem(marker, tile_map)
		if problem != "":
			problems.append("%s %s" % [marker.effective_name(), problem])
			continue
		# Tile by tile of what they cover. Things smaller than a tile share one
		# with their own side, as long as it is not over-full (Sizes).
		var size: int = marker.definition().size
		var clash := ""
		for tile in marker.footprint():
			var there: Dictionary = claimed.get(tile, {"names": [], "side": marker.side, "space": 0, "shared": true})
			var fits: bool = there.names.is_empty() or (Sizes.shares(size) and there.shared and there.side == marker.side \
				and there.space + Sizes.share(size) <= Sizes.SPACE_IN_A_TILE)
			if not fits:
				clash = "%s and %s are both on %s" % [marker.effective_name(), there.names[0], tile]
				break
		if clash != "":
			problems.append(clash)
			continue
		for tile in marker.footprint():
			var there: Dictionary = claimed.get(tile, {"names": [], "side": marker.side, "space": 0, "shared": true})
			there.names.append(marker.effective_name())
			there.space += Sizes.share(size)
			there.shared = there.shared and Sizes.shares(size)
			claimed[tile] = there
	# A key typed rather than picked from the dropdown: the fight would quietly
	# hand them nothing in its place.
	for marker in placed:
		for key in marker.starting_items:
			if key != "" and not SpawnDefinition.item_keys().has(key):
				problems.append("%s carries '%s', which is not an item in %s" % [marker.effective_name(), key, DataFolder.ITEMS])
	var players = 0
	var enemies = 0
	for marker in placed:
		if marker.side == 0:
			players += 1
		else:
			enemies += 1
	if players == 0:
		problems.append("There are no player-side combatants - the encounter would be unplayable. Set a marker's Side to Players.")
	if enemies == 0:
		problems.append("There are no enemies - the encounter would be over immediately. Set a marker's Side to Enemies.")
	# Ways out: on the floor, somewhere a walker can stand, one to a tile.
	var ways_out := {}
	for marker in escape_markers():
		var tile: Vector2i = marker.grid_position()
		if ways_out.has(tile):
			problems.append("Two ways out are both on %s" % tile)
			continue
		ways_out[tile] = true
		if tile_map == null:
			continue
		var data = tile_map.get_cell_tile_data(0, tile)
		if not tile_map.get_used_rect().has_point(tile):
			problems.append("A way out at %s is off the edge of the map" % tile)
		elif data == null:
			problems.append("A way out at %s is on an unpainted hole in the map" % tile)
		elif 0 in data.get_custom_data("Blocks"):
			problems.append("A way out at %s is on a wall - nobody on foot could reach it" % tile)
	# Climb tiles: on the floor, where a walker can stand to climb from.
	var climbs := {}
	for marker in climb_markers():
		var tile: Vector2i = marker.grid_position()
		if climbs.has(tile):
			problems.append("Two climb tiles are both on %s" % tile)
			continue
		climbs[tile] = true
		if tile_map == null:
			continue
		var data = tile_map.get_cell_tile_data(0, tile)
		if data == null:
			problems.append("A climb tile at %s is off the map or on a hole in it" % tile)
		elif 0 in data.get_custom_data("Blocks"):
			problems.append("A climb tile at %s is on a wall - nobody could stand there to climb" % tile)
	return problems


## Validates every marker and writes them back to the encounter resource.
## Writes nothing at all unless everything checks out - a half-saved encounter
## would be worse than an unsaved one.
func save_to_encounter():
	_reanchor_spawn_container()
	var problems = _problems_with_layout()
	var placed = markers()
	var players = 0
	var enemies = 0
	for marker in placed:
		if marker.side == 0:
			players += 1
		else:
			enemies += 1
	if not problems.is_empty():
		var report = "Encounter not saved. Fix these first:\n  - %s" % "\n  - ".join(problems)
		status = report
		_announce()
		push_error(report)
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
		spawns.append(_spawn_from(marker))
	encounter.spawns = spawns
	var ways_out: Array[Vector2i] = []
	for tile in _escape_tiles():
		ways_out.append(tile)
	encounter.escape_points = ways_out
	var climbs: Array[Vector2i] = []
	for tile in _climb_tiles():
		climbs.append(tile)
	encounter.climb_points = climbs

	var error = ResourceSaver.save(encounter, encounter.resource_path)
	if error != OK:
		var failure = "Failed to save %s (error %d)." % [encounter.resource_path, error]
		status = failure
		_announce()
		push_error(failure)
		return
	# The markers and the encounter now say the same thing, so neither counts as
	# having moved on until one of them is edited again.
	_built_from = _encounter_fingerprint()
	var done = "Saved %d spawns (%d players, %d enemies) and %d ways out to %s" % [
		spawns.size(), players, enemies, ways_out.size(), encounter.resource_path
	]
	var stuck = runner_note()
	if stuck != "":
		done += "\n" + stuck
		push_warning(stuck)
	status = done
	notify_property_list_changed()
	print(done)
