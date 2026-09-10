extends Node
## Characters walking about the map during a conversation, driven from the
## dialogue itself.
##
## Registered as a Dialogue Manager state autoload, so a .dialogue file steers
## the scene with `do` lines next to the words they belong with:
##
##     ~ village_gate
##     do Actors.enter("guard", "gate")
##     Guard: Halt. State your business.
##     do Actors.walk("cyrus", "gate")
##     Cyrus: We're only passing through.
##     do Actors.face("guard", "cyrus")
##     do Actors.walk_behind("alithia", 3, 9)
##     Guard: ...go on, then.
##     do Actors.exit("guard", "gate")
##
## A `do` line waits for what it started: the addon awaits the call, so `walk`
## holds the conversation until the walk finishes and the next line lands as
## the character arrives. The `_behind` variants return straight away, for
## someone crossing the scene while the talking carries on.
##
## Destinations are a waypoint name or a tile - walk("cyrus", "gate") and
## walk("cyrus", 12, 7) both work.
##
## Actors are found in this order: a party member by their combatant key, a
## node already in the map with that name, someone this spawned earlier in the
## scene, and failing all of those, a fresh character built from the combatant
## database - so a guard who exists only for one conversation needs nothing
## placed in advance.
##
## Exploration only. Combat moves its units through the turn loop rather than
## by walking them, so a scripted walk there would be arguing with whoever's
## turn it is.

## How fast a scripted walk moves, in world units per second. The party's own
## walking speed, so someone crossing a scene moves like a character rather
## than like a cursor.
const WALK_SPEED := 660.0

## How far outside the map someone entering starts, and someone leaving ends.
const OFF_MAP_TILES := 2

## The scene being talked over. Set by ExplorationScene itself, so nothing here
## goes looking for it, and everything here is harmlessly inert when the
## current scene is not an exploration map at all.
var _scene: Node = null
var _tile_map: TileMap = null
var _grid: AStarGrid2D = null
## Lowercased actor name -> {sprite, path, index, remove_when_done}
var _jobs := {}
## Characters spawned for this scene, by name, so a second mention of the same
## guard is the same guard.
var _spawned := {}


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS


## Called by ExplorationScene once its map exists, and again whenever the map
## is rebuilt. Everything in flight is dropped at that point: the characters it
## was moving belonged to the map that has just gone.
func use_scene(scene: Node, tile_map: TileMap):
	_scene = scene
	_tile_map = tile_map
	_jobs.clear()
	_spawned.clear()
	_grid = null
	if tile_map != null:
		_build_grid()


func _build_grid():
	_grid = AStarGrid2D.new()
	_grid.region = _tile_map.get_used_rect()
	_grid.cell_size = Vector2(Grid.TILE_VECTOR)
	# Points sit at tile centres, which is where characters stand.
	_grid.offset = Grid.HALF_TILE
	# Corners are not squeezed through, so nobody clips through a wall corner.
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.update()
	var region = _grid.region
	for x in range(region.position.x, region.position.x + region.size.x):
		for y in range(region.position.y, region.position.y + region.size.y):
			var tile = Vector2i(x, y)
			# The same test the party walks by, so a scripted character can go
			# exactly where a played one could.
			_grid.set_point_solid(tile, not _walkable(tile))


func _walkable(tile: Vector2i) -> bool:
	if _scene == null or not _scene.has_method("is_walkable"):
		return true
	return _scene.is_walkable(_tile_map.map_to_local(tile))


# --- What dialogue calls ---


## Walks `actor` to `where`, holding the conversation until they arrive.
func walk(actor: String, where, y = null) -> void:
	walk_behind(actor, where, y)
	await finished(actor)


## Starts the walk and lets the conversation carry on over it. Two characters
## can cross the scene at once this way, and a line can be spoken while someone
## is still on their way.
func walk_behind(actor: String, where, y = null) -> void:
	var sprite = _actor(actor)
	if sprite == null:
		return
	var to = _point(where, y)
	if to == null:
		push_warning("Actors.walk('%s', ...): no waypoint or tile called '%s' on this map." % [actor, where])
		return
	sprite.visible = true
	_start(actor, sprite, _route(sprite.position, to), false)


## Walks `actor` in from off the map and leaves them at `where` - someone
## arriving mid-scene, genuinely walking in rather than appearing and then
## moving.
func enter(actor: String, where, y = null) -> void:
	enter_behind(actor, where, y)
	await finished(actor)


func enter_behind(actor: String, where, y = null) -> void:
	var to = _point(where, y)
	if to == null:
		push_warning("Actors.enter('%s', ...): no waypoint or tile called '%s' on this map." % [actor, where])
		return
	var sprite = _actor(actor)
	if sprite == null:
		return
	var edge = _edge_tile_towards(_tile(to))
	sprite.position = _off_map_point(edge)
	sprite.visible = true
	var path: Array[Vector2] = [_tile_map.map_to_local(edge)]
	path.append_array(_route(_tile_map.map_to_local(edge), to))
	_start(actor, sprite, path, false)


## Walks `actor` off the map and out of the scene. Anyone this spawned is
## removed outright; a party member is only walked off and hidden, since the
## party they belong to is still the player's.
func exit(actor: String, where = null, y = null) -> void:
	exit_behind(actor, where, y)
	await finished(actor)


func exit_behind(actor: String, where = null, y = null) -> void:
	var sprite = _actor(actor, false)
	if sprite == null:
		return
	var leaving_from = sprite.position
	var path: Array[Vector2] = []
	if where != null:
		var to = _point(where, y)
		if to != null:
			path = _route(sprite.position, to)
			leaving_from = to
	var edge = _edge_tile_towards(_tile(leaving_from))
	path.append_array(_route(leaving_from, _tile_map.map_to_local(edge)))
	path.append(_off_map_point(edge))
	_start(actor, sprite, path, true)


## Puts `actor` somewhere with no walking, for setting a scene up rather than
## playing it out.
func place(actor: String, where, y = null) -> void:
	var sprite = _actor(actor)
	var to = _point(where, y)
	if sprite == null or to == null:
		return
	_jobs.erase(actor.to_lower())
	sprite.position = to
	sprite.visible = true
	sprite.play_idle()


## Turns `actor` to face "left", "right", another actor, or a waypoint.
func face(actor: String, towards) -> void:
	var sprite = _actor(actor, false)
	if sprite == null:
		return
	if typeof(towards) == TYPE_STRING:
		match String(towards).to_lower():
			"left":
				sprite.set_facing(true)
				return
			"right":
				sprite.set_facing(false)
				return
	var to = null
	if typeof(towards) == TYPE_STRING:
		var other = _actor(String(towards), false)
		if other != null:
			to = other.position
	if to == null:
		to = _point(towards)
	if to == null:
		return
	sprite.set_facing(to.x < sprite.position.x)


## Whether `actor` is still on their way somewhere.
func is_walking(actor: String) -> bool:
	return _jobs.has(actor.to_lower())


## Waits for a walk started with one of the `_behind` calls, so a scene can
## start two people moving and then wait for both.
func finished(actor: String) -> void:
	var key = actor.to_lower()
	while _jobs.has(key):
		await get_tree().process_frame


# --- Doing the walking ---


func _start(actor: String, sprite: Node2D, path: Array, remove_when_done: bool):
	if path.is_empty():
		return
	_jobs[actor.to_lower()] = {
		"sprite": sprite,
		"path": path,
		"index": 0,
		"remove_when_done": remove_when_done
	}
	sprite.play_walk()


func _process(delta):
	if _jobs.is_empty():
		return
	for key in _jobs.keys():
		var job = _jobs[key]
		if not is_instance_valid(job.sprite):
			_jobs.erase(key)
			continue
		var budget = WALK_SPEED * delta
		while budget > 0.0 and job.index < job.path.size():
			var target: Vector2 = job.path[job.index]
			var offset = target - job.sprite.position
			var distance = offset.length()
			if absf(offset.x) > 0.01:
				# Only a sideways run turns them, the same rule the party walks
				# by: heading straight up should not snap them back to facing
				# right.
				job.sprite.set_facing(offset.x < 0.0)
			if distance <= budget:
				# Clamped rather than stepped: a fixed step only lands on the
				# target when the distance happens to divide by it, and
				# otherwise walks past it and comes back, forever.
				job.sprite.position = target
				budget -= distance
				job.index += 1
			else:
				job.sprite.position += offset / distance * budget
				budget = 0.0
		if job.index >= job.path.size():
			_arrive(key, job)


func _arrive(key: String, job: Dictionary):
	_jobs.erase(key)
	if job.remove_when_done:
		if _spawned.has(key):
			_spawned.erase(key)
			job.sprite.queue_free()
		else:
			# Not ours to remove - the party is the player's. Out of sight is as
			# far as this goes.
			job.sprite.visible = false
		return
	job.sprite.play_idle()


# --- Finding things ---


## The character called `actor`, building one from the database if nothing on
## the map answers to the name.
func _actor(actor: String, may_spawn: bool = true) -> Node2D:
	var key = actor.to_lower()
	if _spawned.has(key) and is_instance_valid(_spawned[key]):
		return _spawned[key]
	if _scene != null:
		var party = _scene.get("party")
		if party != null and party.has_method("sprite_for"):
			var member = party.sprite_for(actor)
			if member != null:
				return member
		var named = _find_named(_scene, actor)
		if named != null:
			return named
	if not may_spawn:
		push_warning("Actors: nobody called '%s' is in this scene." % actor)
		return null
	return _spawn(actor)


## Any Node2D in the scene answering to `wanted`, so an NPC placed on the map by
## hand can be walked about without being in the party or the database.
func _find_named(node: Node, wanted: String) -> Node2D:
	for child in node.get_children():
		if child is Node2D and not (child is Waypoint) and child.name.to_lower() == wanted.to_lower():
			return child
		var found = _find_named(child, wanted)
		if found != null:
			return found
	return null


## A character built from the combatant database for this scene only - what
## makes a guard who exists for one conversation possible with nothing placed
## in advance.
func _spawn(actor: String) -> Node2D:
	if _scene == null or not CombatantDatabase.combatants.has(actor.to_lower()):
		push_warning("Actors: nobody called '%s' is in this scene, and the combatant database has no such key." % actor)
		return null
	var definition = CombatantDatabase.combatants[actor.to_lower()]
	var sprite = CombatantSprite.new()
	_scene.add_child(sprite)
	sprite.setup(definition.sprite_frames, definition.map_sprite, false)
	sprite.z_as_relative = false
	# Level with the party rather than above or below it, so a scene reads as
	# one group of people rather than two layers.
	sprite.z_index = ExplorationParty.PARTY_Z_TOP
	sprite.visible = false
	_spawned[actor.to_lower()] = sprite
	return sprite


## A world position from either a waypoint name or a tile.
func _point(where, y = null):
	if _tile_map == null:
		return null
	if y != null:
		return _tile_map.map_to_local(Vector2i(int(where), int(y)))
	if typeof(where) == TYPE_VECTOR2I:
		return _tile_map.map_to_local(where)
	if typeof(where) == TYPE_VECTOR2:
		return where
	var found = _waypoint(String(where))
	return found.global_position if found != null else null


func _waypoint(wanted: String) -> Waypoint:
	return _find_waypoint(_scene, wanted) if _scene != null else null


func _find_waypoint(node: Node, wanted: String) -> Waypoint:
	for child in node.get_children():
		if child is Waypoint and child.matches(wanted):
			return child
		var found = _find_waypoint(child, wanted)
		if found != null:
			return found
	return null


func _tile(point: Vector2) -> Vector2i:
	return _tile_map.local_to_map(point)


## The way there, as world positions. Straight there when there is no grid to
## think with, which is also what happens on a map with no tiles painted.
func _route(from: Vector2, to: Vector2) -> Array:
	var path: Array[Vector2] = []
	if _grid == null:
		path.append(to)
		return path
	var from_tile = _clamped_tile(_tile(from))
	var to_tile = _clamped_tile(_tile(to))
	if _grid.is_point_solid(to_tile):
		# Asked to stand where nobody can stand. Walking to the nearest place
		# they can is friendlier than refusing, and reads the same in the scene.
		to_tile = _nearest_open_tile(to_tile)
	if _grid.is_point_solid(from_tile):
		# Standing somewhere unwalkable - just off the map, mid-entrance. The
		# route starts wherever they can first legally be.
		from_tile = _nearest_open_tile(from_tile)
	for point in _grid.get_point_path(from_tile, to_tile):
		path.append(point)
	if path.is_empty():
		path.append(to)
	return path


func _clamped_tile(tile: Vector2i) -> Vector2i:
	var region = _grid.region
	return Vector2i(
		clampi(tile.x, region.position.x, region.position.x + region.size.x - 1),
		clampi(tile.y, region.position.y, region.position.y + region.size.y - 1)
	)


## The closest tile anyone can stand on, searched outward. Used when a scene
## names a spot that turns out to be a wall.
func _nearest_open_tile(around: Vector2i) -> Vector2i:
	var region = _grid.region
	var reach = maxi(region.size.x, region.size.y)
	for radius in range(1, reach):
		for x in range(around.x - radius, around.x + radius + 1):
			for y in range(around.y - radius, around.y + radius + 1):
				if maxi(absi(x - around.x), absi(y - around.y)) != radius:
					continue
				var tile = Vector2i(x, y)
				if region.has_point(tile) and not _grid.is_point_solid(tile):
					return tile
	return around


## The tile on the map's edge nearest `from` - where someone entering arrives,
## and where someone leaving heads for.
func _edge_tile_towards(from: Vector2i) -> Vector2i:
	var region = _tile_map.get_used_rect()
	var left = from.x - region.position.x
	var right = region.position.x + region.size.x - 1 - from.x
	var top = from.y - region.position.y
	var bottom = region.position.y + region.size.y - 1 - from.y
	var nearest = mini(mini(left, right), mini(top, bottom))
	var edge = from
	if nearest == left:
		edge = Vector2i(region.position.x, from.y)
	elif nearest == right:
		edge = Vector2i(region.position.x + region.size.x - 1, from.y)
	elif nearest == top:
		edge = Vector2i(from.x, region.position.y)
	else:
		edge = Vector2i(from.x, region.position.y + region.size.y - 1)
	if _grid != null and _grid.is_point_solid(edge):
		edge = _nearest_open_tile(edge)
	return edge


## Just outside the map, straight out from `edge` - where someone entering
## starts and someone leaving ends up.
func _off_map_point(edge: Vector2i) -> Vector2:
	var region = _tile_map.get_used_rect()
	var outward = Vector2i.DOWN
	if edge.x == region.position.x:
		outward = Vector2i.LEFT
	elif edge.x == region.position.x + region.size.x - 1:
		outward = Vector2i.RIGHT
	elif edge.y == region.position.y:
		outward = Vector2i.UP
	return _tile_map.map_to_local(edge + outward * OFF_MAP_TILES)
