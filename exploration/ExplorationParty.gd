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
## The box tested against the map: small, and at their feet (the designer, 2026-11-14: "The hitboxes of the characters are a bit
## too big, making them unable to go close to walls, which make one tile hallways annoying to traverse. Maybe a simple solution is
## to have a small hitbox at their feet"). It is about the point they stand on - this node's leader, which is what says which
## tile they are on, so that point itself never leaves ground they can walk on: narrow to either side of it, a little above it,
## and down to about their feet (which are drawn 0.42 of a tile under it). It was a box 0.3125 of a tile every way: 96 pixels of
## play in a corridor one tile wide, and now 184 across one and 162 along one. The numbers are PROPOSAL.
const BODY_HALF_WIDTH_TILES := 0.14
const BODY_ABOVE_TILES := 0.06
const BODY_BELOW_TILES := 0.3125
@export var body_half_width: float = Grid.tiles(BODY_HALF_WIDTH_TILES)
@export var body_above: float = Grid.tiles(BODY_ABOVE_TILES)
@export var body_below: float = Grid.tiles(BODY_BELOW_TILES)

signal moved(position: Vector2)

## Draw layers. Everybody on a map is drawn between PARTY_Z_BOTTOM and PARTY_Z_TOP, by where they stand, so the nearer is over
## the further and a lifted wall over whoever is behind it (Depth.z_at, DepthView). What lies on the ground under them is under
## PARTY_Z_BOTTOM, and what is over everybody is PARTY_Z_TOP or over it. Until the view sorts them (and headless), the leader is
## at the top and each follower one below.
const PARTY_Z_BOTTOM := 20
const PARTY_Z_TOP := 620
## How far the stick can be pushed and still count as a light touch - see
## light_touch(). Past the stick's dead zone, so a little over half its travel.
const LIGHT_TOUCH := 0.45

var leader: CombatantSprite = null
var followers: Array[CombatantSprite] = []
## Told to stay where they are (ExplorationScene.stay_here): out of the line,
## standing still, until the leader walks back up to them.
var stayers: Array[CombatantSprite] = []
## In co-op (Coop), the player who walks this group with their own device, or
## -1 for whoever presses, as outside co-op.
var player := -1
## The other players' groups (ExplorationScene "Co-op"), whose people
## sprite_for finds too - so whatever asks who of the party is where (the
## guards, a fight built on the spot, a conversation) sees all of them.
var companions: Array = []
## Walked from somewhere else - another machine's player (Net): no input here,
## and walk_to puts it where it is said to be.
var puppet := false
## A puppet: whether its machine says it creeps (StealthWatch.creeping_in), so
## its steps are not heard here either.
var creeping_there := false
## How far the leader has walked since the last step was heard (Footsteps).
var _strode := 0.0
## A puppet: where its machine last said it is (walk_to), which it eases to, and
## whether it said it was walking. The words come a score of times a second at
## best, and not evenly - put there each time, it stuttered along in jumps.
var _said_at := Vector2.ZERO
var _said_walking := false
var _said_anything := false
## How quickly a puppet closes on where it was said to be: the share of the way
## left covered in a second is 1 - e^-this. Quick enough to be no more than a
## fraction of a tile behind, slow enough to hide the gaps between the words.
const PUPPET_EASE := 14.0
## Nearer than this it is there, in pixels.
const PUPPET_THERE := 1.0
## Asked of every step in co-op: Callable(group, to) -> bool, false where the
## group would leave the others too far behind (ExplorationScene._within_leash).
var leash: Callable = Callable()
var frozen := false
## Held where they stand by something they are doing - changing into a
## disguise - while the world goes on around them. `frozen` holds everything:
## a conversation, a menu, a catch.
var rooted := false
## Over a network: a menu is open on this machine, which stops nothing else -
## only this group, which stands where it is until it closes (Net).
var in_a_menu := false
## How fast they walk, as a share of move_speed - slower dragging a body.
var pace := 1.0
## And faster for a while, by a move used on the map (OutsideMoves, Speed) -
## kept apart from pace, which dragging sets and puts back.
var hurry := 1.0

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
	stayers.clear()
	_trail.clear()
	_trail_length = 0.0
	_said_anything = false
	_fan.clear()
	_fan_walks.clear()
	_gait = 0.0
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
		# One of the party: a roof fades for them (DepthPiece).
		sprite.add_to_group(Depth.PARTY)
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
	for group in companions:
		if is_instance_valid(group) and group != self:
			var found = group.own_sprite_for(combatant_key)
			if found != null:
				return found
	return null


## sprite_for among this group's own, not its companions'.
func own_sprite_for(combatant_key: String) -> CombatantSprite:
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
	if leader == null or frozen or rooted or in_a_menu or _scripted or dashing or vaulting or distance <= 0.0:
		return false
	if direction == Vector2.ZERO:
		direction = Vector2.LEFT if _facing_left else Vector2.RIGHT
	_dash_direction = direction.normalized()
	_dash_left = distance
	_dash_speed = distance / maxf(seconds, 0.01)
	dashing = true
	# A dash ends where it ends: nothing of the walk's glide is added to it.
	_gait = 0.0
	# Felt (the proposals of 2026-11-16, section 1): the leader stretched along the way, and a streak left behind.
	leader.stretch_along(_dash_direction, DASH_STRETCH, seconds)
	MapFeel.spawn(self, &"streak", leader.position + FEET, {"toward": _dash_direction, "reach": distance * 0.6, "seconds": seconds + 0.12, "z": PARTY_Z_BOTTOM - 1})
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
	if leader == null or frozen or rooted or in_a_menu or _scripted or dashing or vaulting:
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


## Which way the movement keys or the left stick are held right now, or zero.
## As long as the stick is pushed - shorter for a light touch - and always a
## full length from the keys.
func held_direction() -> Vector2:
	# Keys or stick, never the two added together (Pad.direction): a pad's
	# stick resting a little off centre walked a party on the keys slowly down.
	if puppet:
		return Vector2.ZERO
	if player >= 0 and Coop.on():
		return Coop.direction(player, &"move_left", &"move_right", &"move_up", &"move_down")
	# Looking about with the keys (ExplorationScene "The map's camera, softer"): the view slides and nobody walks.
	if not Pad.using_pad and InputMap.has_action(&"look_about") and Input.is_action_pressed(&"look_about"):
		return Vector2.ZERO
	return Pad.direction(&"move_left", &"move_right", &"move_up", &"move_down")


## Whether the stick is pushed only a little way, which is creeping on a
## stealth map (see StealthWatch.creeping). Never from the keys, which are all
## or nothing.
func light_touch() -> bool:
	var held := held_direction()
	return held != Vector2.ZERO and held.length() < LIGHT_TOUCH


func _process(delta):
	if _scripted:
		return
	if puppet:
		_ease_to_where_said(delta)
		return
	if leader == null or frozen or rooted or in_a_menu or _held_by_another():
		dashing = false
		_gait = 0.0
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
			_gait = 0.0
			# A skid of dust where it ends, thrown on the way it was going.
			MapFeel.spawn(self, &"skid", leader.position + FEET, {"toward": _dash_direction, "z": PARTY_Z_BOTTOM - 1})
		return
	var direction = held_direction()
	if direction == Vector2.ZERO:
		# Easing out: a moment's glide the way they were going, and then still.
		if _gait > 0.0 and _going != Vector2.ZERO:
			_gait = maxf(_gait - delta / EASE_OUT_SECONDS, 0.0)
			if _gait > 0.0 and _step(_going, delta, move_speed * pace * hurry * _gait):
				return
		_gait = 0.0
		_set_walking(false)
		_fan_step(delta, true)
		return
	# Easing in: from EASE_FROM of their pace to all of it over EASE_IN_SECONDS. Turning costs nothing.
	_gait = minf(_gait + delta / EASE_IN_SECONDS, 1.0)
	_going = direction
	_fan_step(delta, false)
	if not _step(direction, delta, move_speed * pace * hurry * lerpf(EASE_FROM, 1.0, _gait)):
		_gait = 0.0


## Whether another player's group is held - a conversation, a catch: in co-op
## everybody holds together (ExplorationScene "Co-op").
## --- Weight, and followers with a mind ---
##
## The proposals of 2026-11-16, section 1 (the designer, 2026-11-17). The party reaches its pace over a moment and stops over a
## shorter one, so it has weight; turning stays instant. Those behind fan out a little to either side once the leader has stood a
## while, instead of standing in a line, and fall back in as it sets off. Only the keys' own walking eases: a dash, a retreat and a
## puppet (another machine's player) go as they went. All numbers PROPOSAL.

const EASE_IN_SECONDS := 0.12
const EASE_OUT_SECONDS := 0.09
## The share of their pace they set off at.
const EASE_FROM := 0.35
## How long the leader stands before those behind fan out, how far to the side and how much closer, and how fast they go.
const FAN_AFTER_SECONDS := 0.5
const FAN_TILES := 0.3
const FAN_CLOSER_TILES := 0.12
const FAN_RATE := 5.0
const FAN_BACK_RATE := 8.0
## How much longer the leader is drawn along a dash's way.
const DASH_STRETCH := 0.22
## Where their feet are from the point they stand on.
const FEET := Vector2(0.0, Grid.TILE_SIZE * 0.4)

## Off for a map that wants its line kept (and for a suite that measures the line).
var fans := true
## 0 standing to 1 at full pace, and the way they last went.
var _gait := 0.0
var _going := Vector2.ZERO
var _stood := 0.0
## Where each follower is off its place on the trail, and whether it is walking there.
var _fan: Array = []
var _fan_walks: Array = []


## How much of their pace they have: 0 standing, 1 walking flat out.
func gait() -> float:
	return _gait


## A step of the fan: out while the leader has stood FAN_AFTER_SECONDS, back in as it walks.
func _fan_step(delta: float, standing: bool):
	_stood = _stood + delta if standing else 0.0
	if followers.is_empty():
		return
	while _fan.size() < followers.size():
		_fan.append(Vector2.ZERO)
		_fan_walks.append(false)
	for i in followers.size():
		var aim := Vector2.ZERO
		if standing and fans and _stood >= FAN_AFTER_SECONDS:
			aim = _fan_spot(i)
		var was: Vector2 = _fan[i]
		var now: Vector2 = was.lerp(aim, 1.0 - exp(-(FAN_RATE if standing else FAN_BACK_RATE) * delta))
		if now.distance_to(aim) < 0.75:
			now = aim
		_fan[i] = now
		if not standing:
			# _place_followers puts them, the fan with them.
			_fan_walks[i] = false
			continue
		if now != was:
			followers[i].position += now - was
			if absf(now.x - was.x) > 0.05:
				followers[i].set_facing(now.x < was.x)
		var walks: bool = now != aim
		if walks != bool(_fan_walks[i]):
			_fan_walks[i] = walks
			if walks:
				followers[i].play_walk()
			else:
				followers[i].play_idle()
				followers[i].set_facing(_facing_left)


## Where follower `i` stands off the trail once fanned out: to one side of the line and a little closer, on ground it fits on -
## the other side if not, and in the line where neither will do.
func _fan_spot(i: int) -> Vector2:
	var back := follow_spacing * (i + 1)
	var here := _trail_position(back)
	var along := _trail_position(maxf(back - follow_spacing * 0.5, 0.0)) - here
	if along.length() < 1.0:
		along = Vector2.LEFT if _facing_left else Vector2.RIGHT
	along = along.normalized()
	var side := along.orthogonal() * (1.0 if i % 2 == 0 else -1.0)
	for way in [side, -side]:
		var spot: Vector2 = way * Grid.tiles(FAN_TILES) + along * Grid.tiles(FAN_CLOSER_TILES)
		if _fits(here + spot):
			return spot
	return Vector2.ZERO


## Whether a body fits at `centre`, by the map alone (no leash: this is where a follower stands, not where the group goes).
func _fits(centre: Vector2) -> bool:
	if not _walkable_test.is_valid():
		return true
	for offset in body_corners(body_half_width, body_above, body_below):
		if not _walkable_test.call(centre + offset):
			return false
	return true


func _held_by_another() -> bool:
	for group in companions:
		if group != self and is_instance_valid(group) and group.frozen:
			return true
	return false


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
	var step = direction.normalized() * (speed if speed >= 0.0 else move_speed * pace * hurry) * delta
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
	# Heard as they go: a step every stride, softer at a creep's pace (Footsteps).
	_strode += before.distance_to(moved_to)
	if _strode >= Grid.tiles(Footsteps.STRIDE_TILES):
		_strode = 0.0
		Footsteps.step(leader.global_position, pace * hurry < 0.9)
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
	all.append_array(stayers)
	return all


## The leader and whoever follows - not those staying.
func _line() -> Array:
	var all = []
	if leader != null:
		all.append(leader)
	all.append_array(followers)
	return all


## Everybody in the line back where they stood (`places`: key -> position), the trail laid
## through them, so a lead passed in place moves nobody (Stay Here).
func keep_places(places: Dictionary):
	var line := _line()
	var trail := []
	var length := 0.0
	var behind = null
	for i in range(line.size() - 1, -1, -1):
		var sprite = line[i]
		var place: Vector2 = places.get(sprite.get_meta("combatant_key", ""), sprite.position)
		sprite.position = place
		if behind != null:
			length += behind.distance_to(place)
		trail.append({"position": place, "distance": length})
		behind = place
	if not trail.is_empty():
		_trail = trail
		_trail_length = length
	# Where they stood is where they are: nothing of the fan is left over.
	_fan.clear()
	_fan_walks.clear()
	_stood = 0.0


## `sprite` stays at `at`, out of the line.
func stay(sprite: CombatantSprite, at: Vector2):
	if sprite == null or sprite == leader:
		return
	followers.erase(sprite)
	if not stayers.has(sprite):
		stayers.append(sprite)
	sprite.position = at
	sprite.play_idle()


## `sprite` falls in at the back of the line again.
func rejoin(sprite: CombatantSprite):
	if not stayers.has(sprite):
		return
	stayers.erase(sprite)
	followers.append(sprite)
	sprite.z_index = PARTY_Z_TOP - followers.size()


func _set_walking(walking: bool):
	if walking == _walking:
		return
	_walking = walking
	for sprite in _line():
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
	for sprite in _line():
		sprite.set_facing(left)


## Whether the party's body fits at `centre`. Tests the corners of a box rather
## than a single point, so a member can't stand half-buried in a wall. The box is
## small and at their feet: see body_half_width.
func _can_stand(centre: Vector2) -> bool:
	if leash.is_valid() and not leash.call(self, centre):
		return false
	if not _walkable_test.is_valid():
		return true
	for offset in body_corners(body_half_width, body_above, body_below):
		if not _walkable_test.call(centre + offset):
			return false
	return true


## The corners of the box tested against the map, from the point somebody stands on: as it is made, with nothing given.
static func body_corners(half_width: float = -1.0, above: float = -1.0, below: float = -1.0) -> Array:
	if half_width < 0.0:
		half_width = Grid.tiles(BODY_HALF_WIDTH_TILES)
	if above < 0.0:
		above = Grid.tiles(BODY_ABOVE_TILES)
	if below < 0.0:
		below = Grid.tiles(BODY_BELOW_TILES)
	return [Vector2(-half_width, -above), Vector2(half_width, -above), Vector2(-half_width, below), Vector2(half_width, below)]


func _record_trail(from: Vector2, to: Vector2):
	_trail_length += from.distance_to(to)
	_trail.append({"position": to, "distance": _trail_length})
	# Keep only as much history as the tail actually needs.
	var needed = follow_spacing * (followers.size() + 1)
	while _trail.size() > 2 and _trail_length - _trail[0].distance > needed:
		_trail.pop_front()


func _place_followers():
	for i in followers.size():
		followers[i].position = _trail_position(follow_spacing * (i + 1)) + (_fan[i] if i < _fan.size() else Vector2.ZERO)


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
	_gait = 0.0
	_fan.clear()
	_fan_walks.clear()
	_stood = 0.0
	_said_at = to
	_trail.clear()
	_trail_length = 0.0
	_trail.append({"position": to, "distance": 0.0})
	if leader != null:
		leader.position = to
	for follower in followers:
		follower.position = to


## Where another machine says its player has walked (Net): a puppet's leader
## goes there, the rest trailing after as if walked - eased there frame by frame
## (_ease_to_where_said), or at once from too far to have walked: a door, a blink.
func walk_to(to: Vector2, facing_left: bool, walking: bool, creeping: bool = false):
	creeping_there = creeping
	if leader == null:
		return
	_set_facing(facing_left)
	_said_at = to
	_said_walking = walking
	_said_anything = true
	if leader.position.distance_to(to) > Grid.tiles(3.0):
		teleport(to)
		_set_walking(walking)
		moved.emit(to)


## A puppet, every frame: a step of the way to where it was last said to be, its
## walk playing for as long as it is on its way or was said to be walking.
func _ease_to_where_said(delta: float):
	if leader == null or not _said_anything:
		_set_walking(false)
		return
	# Walked by a conversation just now, which has the last word (Actors).
	if Actors.is_moving(leader):
		return
	var before := leader.position
	var gap := before.distance_to(_said_at)
	if gap > PUPPET_THERE:
		var to := before.lerp(_said_at, 1.0 - exp(-PUPPET_EASE * delta))
		leader.position = to
		_record_trail(before, to)
		_place_followers()
		moved.emit(to)
	elif gap > 0.0:
		leader.position = _said_at
		_record_trail(before, _said_at)
		_place_followers()
		moved.emit(_said_at)
	_set_walking(_said_walking or gap > Grid.tiles(0.1))
	_fan_step(delta, not _walking)


func position_of_leader() -> Vector2:
	if leader != null:
		return leader.position
	# Nobody in it standing - the whole party down: still where it was set up,
	# not the corner of the map, which a rebuild would put everybody in.
	return _trail.back().position if not _trail.is_empty() else Vector2.ZERO


## Whether the line faces left right now.
func facing_left() -> bool:
	return _facing_left
