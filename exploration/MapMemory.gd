extends Node
class_name MapMemory
## What the party has seen of a map, the pins put on it and the secrets in it (the proposals of 2026-11-19, section 2: "A map you
## can open", "The way, at the screen's edge", "Secrets worth finding"; the designer: "Do all"). ExplorationScene makes one on every
## map; it keeps Campaign.exploration[map] up to date as the leader walks, and owns the map screen (MapScreen) and the arrow at the
## screen's edge (WayArrow). Every number is PROPOSAL.

## How far round the leader the map fills in as they walk, in tiles; how many pins a map holds (a fourth takes the oldest's place).
const SEEN_TILES := 6
const MOST_PINS := 3
## How near a click to a pin takes it off again, in tiles.
const PIN_REACH := 1

## Group every secret joins (Interactable.secret, HiddenMark); each answers is_found().
const SECRETS := &"secrets"

## The ExplorationScene this belongs to.
var scene: Node = null
var screen: MapScreen = null
var arrow: WayArrow = null
var _last_tile := Vector2i(-99999, -99999)


func _ready():
	screen = MapScreen.new()
	screen.name = "MapScreen"
	screen.memory = self
	add_child(screen)
	arrow = WayArrow.new()
	arrow.name = "WayArrow"
	arrow.memory = self
	add_child(arrow)
	note_seen(true)


func _process(_delta: float):
	note_seen(false)


func _tile_map() -> TileMap:
	return scene.get("_tile_map") if scene != null else null


## The map as Campaign keeps it, made on the first visit and made afresh if the map's ground has changed size since.
func record() -> Dictionary:
	var tile_map := _tile_map()
	var rect := tile_map.get_used_rect() if tile_map != null else Rect2i()
	var path: String = scene.map_path()
	var mine: Dictionary = Campaign.exploration.get(path, {})
	if mine.is_empty() or mine.get("origin", Vector2i.ZERO) != rect.position or mine.get("size", Vector2i.ZERO) != rect.size:
		var seen := PackedByteArray()
		seen.resize((rect.size.x * rect.size.y + 7) / 8)
		mine = {"origin": rect.position, "size": rect.size, "seen": seen, "pins": []}
		Campaign.exploration[path] = mine
	return mine


## The tile the leader stands on.
func leader_tile() -> Vector2i:
	var tile_map := _tile_map()
	if tile_map == null:
		return Vector2i.ZERO
	return tile_map.local_to_map(tile_map.to_local(scene.party_position()))


## Fills in the map round the leader: every tile within SEEN_TILES of them. Only when they have come onto a new tile, unless `force`.
func note_seen(force: bool):
	if scene == null or _tile_map() == null:
		return
	var at := leader_tile()
	if at == _last_tile and not force:
		return
	_last_tile = at
	var mine := record()
	var seen: PackedByteArray = mine.seen
	var origin: Vector2i = mine.origin
	var size: Vector2i = mine.size
	var changed := false
	for dy in range(-SEEN_TILES, SEEN_TILES + 1):
		for dx in range(-SEEN_TILES, SEEN_TILES + 1):
			if dx * dx + dy * dy > SEEN_TILES * SEEN_TILES:
				continue
			var t := at + Vector2i(dx, dy) - origin
			if t.x < 0 or t.y < 0 or t.x >= size.x or t.y >= size.y:
				continue
			var i := t.y * size.x + t.x
			var bit := 1 << (i % 8)
			if seen[i / 8] & bit == 0:
				seen[i / 8] = seen[i / 8] | bit
				changed = true
	if changed:
		mine.seen = seen


## Whether the party has seen `tile` of this map.
func has_seen(tile: Vector2i) -> bool:
	var mine := record()
	var t: Vector2i = tile - mine.origin
	var size: Vector2i = mine.size
	if t.x < 0 or t.y < 0 or t.x >= size.x or t.y >= size.y:
		return false
	var i := t.y * size.x + t.x
	var seen: PackedByteArray = mine.seen
	return seen[i / 8] & (1 << (i % 8)) != 0


## How much of the map has been seen, 0 to 1, of the ground there is to see (anything that is not solid rock).
func share_seen() -> float:
	var tile_map := _tile_map()
	if tile_map == null:
		return 0.0
	var ground := 0
	var seen := 0
	for tile in tile_map.get_used_cells(0):
		ground += 1
		if has_seen(tile):
			seen += 1
	return float(seen) / float(maxi(ground, 1))


## --- Pins ---


func pins() -> Array:
	return record().pins


## Puts a pin on `tile`, or takes off the one already there or next to it. The newest is what the arrow points at.
func toggle_pin(tile: Vector2i):
	var mine := record()
	var list: Array = mine.pins
	for pin in list:
		var at: Vector2i = pin
		if absi(at.x - tile.x) <= PIN_REACH and absi(at.y - tile.y) <= PIN_REACH:
			list.erase(pin)
			mine.pins = list
			return
	list.append(tile)
	while list.size() > MOST_PINS:
		list.pop_front()
	mine.pins = list


## --- Secrets ---


## Every secret on this map (its own nodes only: in the tests the game's own fight runs behind it).
func secrets() -> Array:
	if scene == null or not is_inside_tree():
		return []
	return get_tree().get_nodes_in_group(SECRETS).filter(func(node): return scene.is_ancestor_of(node) and node.has_method("is_found"))


func secrets_found() -> int:
	return secrets().filter(func(node): return node.is_found()).size()


## --- The way ---


## Where the arrow at the screen's edge points, in the world: the newest pin, else a stealth map's goal, else nowhere (INF).
func way_target() -> Vector2:
	var tile_map := _tile_map()
	var list := pins()
	if tile_map != null and not list.is_empty():
		var tile: Vector2i = list[-1]
		return tile_map.to_global(tile_map.map_to_local(tile))
	var map: Node = scene.get_node_or_null("Map") if scene != null else null
	if map != null:
		for goal in map.find_children("*", "StealthGoal", true, false):
			if goal is Node2D and goal.visible:
				return (goal as Node2D).global_position
	return Vector2.INF


## A map's name to show: its MapSetup's Place Name, else its file's own.
func place_name() -> String:
	var setup = scene.call("_map_setup") if scene != null and scene.has_method("_map_setup") else null
	if setup != null and setup.get("place_name") != null and String(setup.place_name) != "":
		return setup.place_name
	return String(scene.map_path()).get_file().get_basename().replace("_", " ").capitalize() if scene != null else ""
