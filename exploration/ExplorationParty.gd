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
@export var move_speed: float = Grid.tiles(3.4375)
## How far apart party members sit along the trail, in pixels. One tile is 32.
@export var follow_spacing: float = Grid.tiles(0.8125)
## Half-width of the box tested against the map. Smaller than a tile so you can
## walk down a one-tile corridor without catching on the walls.
@export var body_radius: float = Grid.tiles(0.3125)

signal moved(position: Vector2)

## Draw layer for the leader; each follower sits one below, so a party of any
## realistic size still clears the map underneath.
const PARTY_Z_TOP := 20

var leader: CombatantSprite = null
var followers: Array[CombatantSprite] = []
var frozen := false
## Held where they stand by something they are doing - changing into a
## disguise - while the world goes on around them. `frozen` holds everything:
## a conversation, a menu, a catch.
var rooted := false
## How fast they walk, as a share of move_speed - slower dragging a body.
var pace := 1.0

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
		# The same CombatantSprite battles use, so the party walks with the
		# animation set it fights with rather than sliding along as a still. It
		# falls back to the flat map sprite on its own for anyone with no
		# SpriteFrames, so nothing has to be animated for this to work.
		var sprite = CombatantSprite.new()
		sprite.position = start_position
		add_child(sprite)
		sprite.setup(members[i].get("sprite_frames"), members[i].get("map_sprite"), false)
		# Who this actually is, so a conversation can send "cyrus" somewhere
		# rather than "the second one in the line".
		sprite.set_meta("combatant_key", members[i].get("key", ""))
		# Above the map, descending so the line reads front-to-back with the
		# leader on top. Absolute rather than relative, and never at or below
		# the terrain's own z_index of 0 - followers were previously at -1 and
		# -2, which drew them underneath the map and made them invisible.
		sprite.z_as_relative = false
		sprite.z_index = PARTY_Z_TOP - i
		if i == 0:
			leader = sprite
		else:
			followers.append(sprite)
	_trail.append({"position": start_position, "distance": 0.0})
	# The line has just been rebuilt, and the new sprites know nothing of which
	# way it was facing or whether it was walking - they all start idle, facing
	# right. _set_walking and _set_facing only act on a change, so without this
	# they would both decide there was nothing to do and leave everyone sliding
	# along in their idle pose until the player stopped and set off again. Which
	# is exactly what passing the lead mid-stride looked like.
	for sprite in _members():
		sprite.set_facing(_facing_left)
		if _walking:
			sprite.play_walk()
		else:
			sprite.play_idle()


## The party member with this combatant key, or null for anyone not in the
## line. How dialogue addresses the people the player is already walking with.
func sprite_for(combatant_key: String) -> CombatantSprite:
	for sprite in _members():
		if String(sprite.get_meta("combatant_key", "")).to_lower() == combatant_key.to_lower():
			return sprite
	return null


## Whether the line is currently walking, and which way it faces. Kept rather
## than set every frame so the animation is only told to change when it
## actually changes - restarting "walk" sixty times a second would hold it on
## its first frame and look like no animation at all.
var _walking := false
var _facing_left := false


## True while something other than the player is walking the line - a retreat
## out of a trigger they turned down. The keys are ignored for the duration
## rather than fought with.
var _scripted := false


## --- A dash ---
##
## A burst of speed over a set distance - the stealth map's Shift. Taken over
## the frames it lasts rather than in one jump, and by the same stepping as
## walking, so it slides along a wall and stops dead at one rather than
## passing through it.

## Whether a dash is under way. The keys wait until it is over.
var dashing := false
var _dash_direction := Vector2.ZERO
var _dash_left := 0.0
var _dash_speed := 0.0


## Dashes `distance` along `direction` - or the way the line faces, given none -
## over `seconds`. False, and nothing started, when the line cannot move now.
func dash(direction: Vector2, distance: float, seconds: float) -> bool:
	if leader == null or frozen or rooted or _scripted or dashing or vaulting or distance <= 0.0:
		return false
	if direction == Vector2.ZERO:
		direction = Vector2.LEFT if _facing_left else Vector2.RIGHT
	_dash_direction = direction.normalized()
	_dash_left = distance
	_dash_speed = distance / maxf(seconds, 0.01)
	dashing = true
	return true


## --- A vault ---
##
## A hop over something waist-high to the far side of it - the stealth map's
## V. Straight there along an arc, through what walking would stop at: whatever
## is in the way is exactly what is being jumped. Followers hop after, since
## they walk the same trail.

## Whether a vault is under way. The keys wait until it is over.
var vaulting := false
## How high the hop goes, at its top.
const VAULT_HEIGHT := 0.35
var _vault_from := Vector2.ZERO
var _vault_to := Vector2.ZERO
var _vault_seconds := 0.0
var _vault_elapsed := 0.0


## Hops the leader to `to` (in the party's own space) over `seconds`. False, and
## nothing started, when the line cannot move now.
func vault(to: Vector2, seconds: float) -> bool:
	if leader == null or frozen or rooted or _scripted or dashing or vaulting:
		return false
	_vault_from = leader.position
	_vault_to = to
	_vault_seconds = maxf(seconds, 0.01)
	_vault_elapsed = 0.0
	vaulting = true
	if not is_equal_approx(to.x, _vault_from.x):
		_set_facing(to.x < _vault_from.x)
	return true


func _vault_along(delta: float):
	_vault_elapsed = minf(_vault_elapsed + delta, _vault_seconds)
	var t = _vault_elapsed / _vault_seconds
	var before = leader.position
	leader.position = _vault_from.lerp(_vault_to, t) + Vector2(0.0, -sin(PI * t) * Grid.tiles(VAULT_HEIGHT))
	_record_trail(before, leader.position)
	_place_followers()
	moved.emit(leader.position)
	if t >= 1.0:
		leader.position = _vault_to
		vaulting = false


## Which way the movement keys are held right now, or zero.
func held_direction() -> Vector2:
	return Vector2(
		_axis(KEY_D, KEY_RIGHT) - _axis(KEY_A, KEY_LEFT),
		_axis(KEY_S, KEY_DOWN) - _axis(KEY_W, KEY_UP)
	)


func _process(delta):
	if _scripted:
		return
	if leader == null or frozen or rooted:
		dashing = false
		if vaulting:
			# Not left hanging over the barrel: down on the far side.
			leader.position = _vault_to
			vaulting = false
		_set_walking(false)
		return
	if vaulting:
		_vault_along(delta)
		return
	if dashing:
		var length = minf(_dash_speed * delta, _dash_left)
		_dash_left -= length
		# Stopped by a wall, or run its length: either way it is over.
		if not _step(_dash_direction, delta, length / maxf(delta, 0.0001)) or _dash_left <= 0.0:
			dashing = false
		return
	var direction = held_direction()
	if direction == Vector2.ZERO:
		_set_walking(false)
		return
	_step(direction, delta)


## One step of the line in `direction`, sliding along anything it runs into.
## False when it could not move at all, which is a wall.
##
## Shared by the player's own walking and by a scripted retreat, so a retreat
## respects the map exactly as walking does rather than sliding through it.
func _step(direction: Vector2, delta: float, speed: float = -1.0) -> bool:
	if leader == null:
		return false
	if direction.x != 0.0:
		# Only a horizontal press turns the line. Walking straight up or down
		# leaves everyone facing the way they last went, rather than snapping
		# back to the default every time the path turns a corner.
		_set_facing(direction.x < 0.0)
	var step = direction.normalized() * (speed if speed >= 0.0 else move_speed * pace) * delta
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
		# Pressed into a wall: still facing that way, but not walking anywhere.
		_set_walking(false)
		return false
	_set_walking(true)
	leader.position = moved_to
	_record_trail(before, moved_to)
	_place_followers()
	moved.emit(moved_to)
	return true


## Walks the line away from `point` until the leader is `clearance` clear of it.
##
## Under its own steam rather than put there: the same stepping the player's
## keys drive, so the party retreats at walking pace with the tail following,
## and stops dead against a wall instead of backing through it. Returns when
## they are clear, or when there is nowhere further to back into.
func retreat_from(point: Vector2, clearance: float) -> void:
	if leader == null or not is_inside_tree():
		return
	_scripted = true
	# A step is a frame's worth of walking, so a party wedged in a corner cannot
	# spin here for ever - at walking pace this is a few seconds of map at most.
	var steps = 0
	while leader.position.distance_to(point) < clearance and steps < 600:
		steps += 1
		var away = leader.position - point
		if away.length() < 0.001:
			# Standing exactly on it: any direction is away from here.
			away = Vector2.RIGHT
		if not _step(away.normalized(), get_process_delta_time()):
			break
		await get_tree().process_frame
	_set_walking(false)
	_scripted = false


## Everyone in the line, leader first.
func _members() -> Array:
	var all = []
	if leader != null:
		all.append(leader)
	all.append_array(followers)
	return all


func _set_walking(walking: bool):
	if walking == _walking:
		return
	_walking = walking
	for sprite in _members():
		if walking:
			sprite.play_walk()
		else:
			sprite.play_idle()


## Turns the whole line, followers included - they are walking the same path
## the leader just walked, so they face the same way.
func _set_facing(left: bool):
	if left == _facing_left:
		return
	_facing_left = left
	for sprite in _members():
		sprite.set_facing(left)


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
	vaulting = false
	dashing = false
	_trail.clear()
	_trail_length = 0.0
	_trail.append({"position": to, "distance": 0.0})
	if leader != null:
		leader.position = to
	for follower in followers:
		follower.position = to


func position_of_leader() -> Vector2:
	return leader.position if leader != null else Vector2.ZERO


## Whether the line faces left right now.
func facing_left() -> bool:
	return _facing_left
