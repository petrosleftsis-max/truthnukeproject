extends Node2D
class_name ExplorationParty
## The party walking around an exploration map: a leader you steer with WASD /
## the arrow keys, and the rest trailing behind in single file.
##
## Movement is free (pixel, not tile) but collision comes from the very same
## TileMap "Blocks" custom data combat uses, so a wall is a wall in both modes
## and a new map needs no extra collision authoring. The walkability test is
## owned by ExplorationScene; this just asks.
##
## Followers walk the leader's actual route rather than steering themselves -
## they replay a trail of positions the leader has already stood on, so they
## can never get stuck on a corner the leader has just rounded, and they never
## need collision logic of their own.


## Pixels per second.
@export var move_speed: float = 110.0
## How far apart party members sit along the trail, in pixels. One tile is 32.
@export var follow_spacing: float = 26.0
## Half-width of the box tested against the map. Smaller than a tile so you can
## walk down a one-tile corridor without catching on the walls.
@export var body_radius: float = 10.0

signal moved(position: Vector2)

## Draw layer for the leader; each follower sits one below, so a party of any
## realistic size still clears the map underneath.
const PARTY_Z_TOP := 20

var leader: Sprite2D = null
var followers: Array = []
var frozen := false

## Positions the leader has occupied, newest last, with the distance walked to
## reach each. Followers index into this by distance behind the leader.
var _trail: Array = []
var _trail_length := 0.0
var _walkable_test: Callable = Callable()


## `walkable_test` takes a world Vector2 and returns whether the party may
## stand there. Supplied by ExplorationScene, which owns the map.
func setup(members: Array, start_position: Vector2, walkable_test: Callable):
	_walkable_test = walkable_test
	for child in get_children():
		child.queue_free()
	leader = null
	followers.clear()
	_trail.clear()
	_trail_length = 0.0
	for i in members.size():
		var sprite = Sprite2D.new()
		sprite.texture = members[i]
		sprite.position = start_position
		# Above the map, descending so the line reads front-to-back with the
		# leader on top. Absolute rather than relative, and never at or below
		# the terrain's own z_index of 0 - followers were previously at -1 and
		# -2, which drew them underneath the map and made them invisible.
		sprite.z_as_relative = false
		sprite.z_index = PARTY_Z_TOP - i
		add_child(sprite)
		if i == 0:
			leader = sprite
		else:
			followers.append(sprite)
	_trail.append({"position": start_position, "distance": 0.0})


func _process(delta):
	if leader == null or frozen:
		return
	var direction = Vector2(
		_axis(KEY_D, KEY_RIGHT) - _axis(KEY_A, KEY_LEFT),
		_axis(KEY_S, KEY_DOWN) - _axis(KEY_W, KEY_UP)
	)
	if direction == Vector2.ZERO:
		return
	var step = direction.normalized() * move_speed * delta
	var before = leader.position
	# Each axis separately, so running into a wall at an angle slides along it
	# instead of stopping dead.
	var moved_to = leader.position
	var candidate = Vector2(moved_to.x + step.x, moved_to.y)
	if _can_stand(candidate):
		moved_to = candidate
	candidate = Vector2(moved_to.x, moved_to.y + step.y)
	if _can_stand(candidate):
		moved_to = candidate
	if moved_to == before:
		return
	leader.position = moved_to
	_record_trail(before, moved_to)
	_place_followers()
	moved.emit(moved_to)


func _axis(key_a: Key, key_b: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(key_a) or Input.is_physical_key_pressed(key_b) else 0.0


## Whether the party's body fits at `centre`. Tests the corners of a box rather
## than a single point, so a member can't stand half-buried in a wall.
func _can_stand(centre: Vector2) -> bool:
	if not _walkable_test.is_valid():
		return true
	for offset in [
		Vector2(-body_radius, -body_radius), Vector2(body_radius, -body_radius),
		Vector2(-body_radius, body_radius), Vector2(body_radius, body_radius)
	]:
		if not _walkable_test.call(centre + offset):
			return false
	return true


func _record_trail(from: Vector2, to: Vector2):
	_trail_length += from.distance_to(to)
	_trail.append({"position": to, "distance": _trail_length})
	# Keep only as much history as the tail actually needs.
	var needed = follow_spacing * (followers.size() + 1)
	while _trail.size() > 2 and _trail_length - _trail[0].distance > needed:
		_trail.pop_front()


func _place_followers():
	for i in followers.size():
		followers[i].position = _trail_position(follow_spacing * (i + 1))


## Where the leader was, `distance_back` pixels ago along the route actually
## walked. Interpolates between the two recorded points either side, so
## followers glide rather than snapping between samples.
func _trail_position(distance_back: float) -> Vector2:
	var target = _trail_length - distance_back
	if _trail.is_empty():
		return Vector2.ZERO
	if target <= _trail[0].distance:
		return _trail[0].position
	for i in range(_trail.size() - 1, 0, -1):
		var ahead = _trail[i]
		var behind = _trail[i - 1]
		if behind.distance <= target and target <= ahead.distance:
			var span = ahead.distance - behind.distance
			if span <= 0.0:
				return behind.position
			return behind.position.lerp(ahead.position, (target - behind.distance) / span)
	return _trail[-1].position


## Drops the whole party onto one spot and forgets the trail - used when a map
## is entered, so nobody trails in from where they stood in the last one.
func teleport(to: Vector2):
	_trail.clear()
	_trail_length = 0.0
	_trail.append({"position": to, "distance": 0.0})
	if leader != null:
		leader.position = to
	for follower in followers:
		follower.position = to


func position_of_leader() -> Vector2:
	return leader.position if leader != null else Vector2.ZERO
