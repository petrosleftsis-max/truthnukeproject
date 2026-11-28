@icon("res://art/editor_icons/hiding.svg")
extends Node2D
class_name HiddenPlaces
## What the party has not seen on this map, in darkness (the designer, 2026-11-27: "Any place the players 'haven't seen' because
## there is a cover in between them for example, show it with some darkness"). Put one in a map, anywhere.
##
## Each of the party sees as far as Reach, and as far as the walls, shut doors and standing breakable walls let them - the guards'
## own rule for a look (StealthSight.clear). What they have seen stays seen, kept in the flags with the map; what they cannot see
## right now is dimmer than the rest, what they have never seen is dark. A breakable wall that Hides tiles keeps them out of sight
## while it stands; broken, they are seen at once (BreakableWall "What it hides"). PROPOSAL: the reach, the two darknesses.

## How far anybody of the party sees, in tiles.
@export_range(4, 40, 1, "suffix:tiles") var reach: int = 14
## Over what has never been seen.
@export var never_seen: Color = Color(0.0, 0.0, 0.02, 0.93)
## Over what was seen before, out of sight now.
@export var out_of_sight: Color = Color(0.0, 0.0, 0.03, 0.42)

## Kept in the flags as "places_seen:" and the map, "x,y" a tile.
const FLAG := "places_seen:%s"

var _scene: Node = null
var _tile_map: TileMap = null
var _sight: StealthSight = null
var _seen := {}
var _in_sight := {}
## What was looked from last, and what the doors and walls were, so a look is only taken again when something changed.
var _looked := ""
## The map's doors, found once.
var _doors: Array = []


func _ready():
	z_as_relative = false
	z_index = ExplorationParty.PARTY_Z_TOP + 5
	_scene = _exploration_scene()
	if _scene == null:
		set_process(false)
		return
	_tile_map = _scene.get("_tile_map")
	if _tile_map == null:
		set_process(false)
		return
	_sight = StealthSight.new(_tile_map)
	_doors = get_parent().find_children("*", "StealthDoor", true, false) if get_parent() != null else []
	for each in String(Campaign.flags.get(FLAG % _map(), "")).split(";", false):
		var parts := each.split(",")
		if parts.size() == 2:
			_seen[Vector2i(int(parts[0]), int(parts[1]))] = true


## The exploration scene this map is open in, or null - a map opened for a fight, or in the editor.
func _exploration_scene() -> Node:
	var at := get_parent()
	while at != null:
		if at.has_method("party_position") and at.get("_tile_map") != null:
			return at
		at = at.get_parent()
	return null


func _map() -> String:
	return _scene.map_path() if _scene != null and _scene.has_method("map_path") else ""


func _process(_delta):
	var from := _looking_from()
	var key := "%s|%s" % [from, _what_stands()]
	if key == _looked:
		return
	_looked = key
	look(from)


## Every tile the party looks from now: each of them on the map.
func _looking_from() -> Array:
	var tiles := []
	var party = _scene.get("party")
	if party == null:
		return tiles
	for member in Campaign.party_members():
		var sprite = party.sprite_for(member.key)
		if sprite != null and is_instance_valid(sprite) and sprite.visible:
			var tile := _tile_map.local_to_map(_tile_map.to_local(sprite.global_position))
			if not tiles.has(tile):
				tiles.append(tile)
	if tiles.is_empty() and _scene.has_method("party_position"):
		tiles.append(_tile_map.local_to_map(_tile_map.to_local(_scene.party_position())))
	return tiles


## The doors and breakable walls as they stand, shut or open, for knowing when to look again.
func _what_stands() -> String:
	var said := ""
	for door in _doors:
		said += "1" if door.passable() else "0"
	for wall in _walls():
		said += "1" if wall.broken else "0"
	return said


func _walls() -> Array:
	return _scene.walls() if _scene.has_method("walls") else []


## Looks from `from` (tiles): whatever is in reach and in sight is seen, for good - but not what a standing wall hides.
func look(from: Array):
	if _sight == null:
		return
	# What stops a look right now, besides the painted walls: shut doors and standing walls.
	for door in _doors:
		_sight.set_shut(_tile_of(door), not door.passable())
	var kept_hidden := {}
	for wall in _walls():
		if not is_instance_valid(wall):
			continue
		_sight.set_shut(_tile_of(wall), not wall.broken)
		for tile in wall.hidden_tiles():
			if wall.broken:
				_seen[tile] = true
			else:
				kept_hidden[tile] = true
	_in_sight.clear()
	var region := _tile_map.get_used_rect()
	for tile in from:
		for dx in range(-reach, reach + 1):
			for dy in range(-reach, reach + 1):
				var other: Vector2i = tile + Vector2i(dx, dy)
				if _in_sight.has(other) or kept_hidden.has(other) or not region.has_point(other) or dx * dx + dy * dy > reach * reach:
					continue
				if other == tile or _sight.clear(tile, other):
					_in_sight[other] = true
					_seen[other] = true
	_remember()
	queue_redraw()


func _tile_of(node: Node2D) -> Vector2i:
	return _tile_map.local_to_map(_tile_map.to_local(node.global_position))


func _remember():
	var tiles := PackedStringArray()
	for tile in _seen:
		tiles.append("%d,%d" % [tile.x, tile.y])
	Campaign.flags[FLAG % _map()] = ";".join(tiles)


## Whether `tile` has ever been seen by the party, and whether it is in sight now.
func seen(tile: Vector2i) -> bool:
	return _seen.has(tile)


func in_sight(tile: Vector2i) -> bool:
	return _in_sight.has(tile)


func _draw():
	if _tile_map == null:
		return
	var size := Vector2(Grid.TILE_SIZE, Grid.TILE_SIZE)
	var region := _tile_map.get_used_rect()
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var tile := Vector2i(x, y)
			if _in_sight.has(tile):
				continue
			var middle := to_local(_tile_map.to_global(_tile_map.map_to_local(tile)))
			draw_rect(Rect2(middle - size / 2.0, size), out_of_sight if _seen.has(tile) else never_seen)
