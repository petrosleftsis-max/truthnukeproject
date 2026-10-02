@tool
extends Node2D
class_name Guard
## Somebody on watch on a stealth map (see StealthSetup). Walks a patrol of
## waypoints, stopping at each to look about, and sees what StealthSight says a
## guard facing their way sees: a 160-degree cone, as far as the walls allow.
##
## Who they are comes from the combatant database, so a guard is the same
## Barbarian or Priest the fight will field if they catch anybody - at the level
## set here.

@export var combatant_key: String = "barbarian"
@export_range(1, 3) var level: int = 1
## What the fight calls them. Empty: the combatant's own name, numbered when
## there are several.
@export var display_name: String = ""

## What sort of watcher they are. Stored by number, so a new one goes on the end.
enum Kind {
	WATCHMAN,  ## Sees a cone, patrols, investigates. Everything above and below.
	DOG,       ## No cone: smells anybody within Smell Tiles, walls or not, and no disguise fools a nose.
	WARD,      ## A statue or a charm: turns in place for ever, sees through every disguise, never moves, never fights.
	CAPTAIN,   ## A watchman whose shout, once sure, brings every guard within Shout Tiles into the fight.
	CIVILIAN,  ## Nobody's guard, and never in a fight. Sure of somebody - or seeing a takedown, a body, a body dragged - they run to the nearest guard and tell them where.
}
@export var kind: Kind = Kind.WATCHMAN : set = _set_kind
## A dog's nose, in tiles.
@export var smell_tiles: float = 3.0 : set = _set_smell_tiles
## How fast a ward turns, in degrees a second. Negative turns it the other way.
@export var ward_turn_degrees: float = 30.0
## How far a captain's shout carries, in tiles.
@export var shout_tiles: float = 12.0

@export_group("Watching")
## Where they look to begin with, and while standing with no patrol to walk:
## 0 is right, 90 down, 180 left, -90 up. Drawn in the editor as their cone.
@export_range(-180, 180) var facing_degrees: float = 0.0 : set = _set_facing_degrees
## Whether they sweep their gaze from side to side while standing still.
@export var looks_around: bool = true
## Asleep at their post: they see nothing, and wake to a noise near enough to
## hear - and go to see what it was. Their pockets can be picked and they can
## be taken down from any side.
@export var asleep: bool = false

## Which disguises they see through. Stored by number, so a new one goes on
## the end.
enum Recognises {
	OWN_ROLE,      ## Their own kind: dressed as one of them, he is caught; as anyone else, he walks past.
	ANY_DISGUISE,  ## Nothing fools them - disguised or not, he is who he is.
	NO_DISGUISE,   ## Any disguise at all does.
}
## Whether a disguise gets past them. A Priest set to Own Role knows every
## Priest there is, so Cyrus in Priest's robes is caught - but passes as a
## Priest in front of anybody else set that way.
@export var recognises: Recognises = Recognises.OWN_ROLE

@export_group("Patrol")
## Waypoint names, walked in order. Empty: they stand where they are placed.
@export var patrol: Array[String] = []
## After the last waypoint, walk the list back the other way rather than going
## straight back to the first.
@export var back_and_forth: bool = false
## How long they stop at each waypoint.
@export var pause_seconds: float = 1.5
## How fast they walk, in tiles a second. Slower than the party, so a patrol can
## be followed.
@export var walk_speed_tiles: float = 1.6
## Their round, found out: once this flag is set - a duty roster read, a
## pocket picked, a conversation overheard - their patrol is drawn while
## listening (Q), or with the pointer on them. Empty: nobody ever learns it.
@export var route_known_flag: String = ""

@export_group("Taken down, and robbed")
## Whether sneaking up behind them and left clicking knocks them out. Off for
## anybody who should not go down that easily. A ward never can.
@export var can_be_taken_down: bool = true
## What is in their pockets, by item key - lifted by standing behind them
## unnoticed and right clicking. A key to a door is the usual thing.
@export var pockets: Array[String] = []
## Set once their pockets are picked, so a door or a conversation can wait on it.
@export var picked_flag: String = ""
## What the log says was taken besides any items - "a ring of keys" - for
## pockets whose point is the flag.
@export var picked_message: String = ""

@export_group("Questioning")
## A conversation they stop a disguised party with once they grow half sure,
## rather than simply growing sure. Talk your way out and they are fooled for
## good; fail, and it is a fight. Empty: no questions, just the meter.
@export var questions: Resource
@export var questions_title: String = "start"
## The flag the conversation sets when the answers were good enough. Set, they
## wave him on; not set when it ends, they are sure.
@export var passed_flag: String = ""
## A conversation E beside them plays, in a disguise they take at face value,
## instead of the few words that settle the map a level - once. Whatever it
## does is up to it: `do Campaign.settle_alert()` settles the map. Empty: the
## few words.
@export var small_talk: Resource
@export var small_talk_title: String = "start"

## How quickly they turn to face where they are going, in radians a second.
const TURN_SPEED := 4.0
## How far either side a look about sweeps, and how long one sweep takes.
const LOOK_AROUND_DEGREES := 50.0
const LOOK_AROUND_SECONDS := 2.4

## --- Reacting to somebody ---
##
## What a guard is up to. The StealthWatch moves them between these by how sure
## they are: watching while their meter fills, staring after whoever broke the
## line while it drains, and - once it has drained without them being sure -
## walking to where that somebody was last seen, searching there with their
## eyes open wider, and going back to their beat.
##
## Stored by number, so a new one goes on the end.
enum Mood {
	PATROLLING,     ## Walking their beat, or standing their post.
	WATCHING,       ## Somebody is in view: stopped dead, turned to them.
	SUSPICIOUS,     ## Lost sight while not yet sure: staring where they were.
	INVESTIGATING,  ## Walking to where they were last seen.
	SEARCHING,      ## Looking about the spot.
	RETURNING,      ## Back to their beat.
	LISTENING,      ## Heard something nearby: stopped, turned to it, for a moment.
	CHATTING,       ## Off to talk with somebody, or talking - their mind on it, and their view narrower.
	EATING,         ## Off to eat or drink what was left out for them, or at it.
	RETCHING,       ## Poisoned with an emetic: off to be sick, and being sick. Sees nothing.
	SICK,           ## Poisoned with a disease: too unwell to move, seeing only a little.
	TENDING,        ## Seeing to somebody sick, their view as narrow as the patient's.
	REPORTING,      ## Nobody's guard, running to a guard with what they saw.
	ASLEEP,         ## Asleep at their post. Sees nothing; a noise wakes them.
	WAKING,         ## Off to bring round somebody knocked out, or bringing them round.
}
var mood: Mood = Mood.PATROLLING
## Knocked out: lying where they fell, watching nothing, fighting nobody -
## until another guard finds them.
var knocked_out := false
## Whether their pockets have been picked already.
var picked := false
## Whether they have already stopped the party to ask questions, and whether
## the answers fooled them for good.
var questioned := false
var fooled := false
## Whether a disguised party has already had a word with them to settle the
## map (see StealthWatch.reassure) - once each.
var reassured := false
## Whether what they are going to look into is somebody they saw - rather
## than a noise or a body - so they look behind the barrels too (see
## StealthWatch.SEARCH_SPOTS_TILES).
var hunting := false
## What the map's alert level adds, set by the StealthWatch: how much quicker
## they walk, and how many degrees wider either side they look.
var alert_pace := 0.0
var alert_cone := 0.0
## How long a noise holds their attention.
const LISTEN_SECONDS := 2.0
var _listen_left := 0.0
## Where whoever they were watching was last seen.
var last_seen := Vector2.ZERO
## How long they look about the spot before giving it up.
@export var search_seconds: float = 3.0
## Whether they are looking into somebody they saw, right now: on the way
## there, searching the spot - or watching whoever they found there, which is
## no time to stop looking behind the barrels. Over once they give it up.
func is_hunting() -> bool:
	return hunting and mood != Mood.PATROLLING and mood != Mood.RETURNING and mood != Mood.LISTENING


## Half their view, either side of where they face: the usual 160 degrees, and
## 340 while investigating or searching - somebody who knows something is off
## watches their flanks too.
const HALF_CONE := 80.0
const HALF_CONE_ALERT := 170.0
## How much of their usual view somebody sick, or seeing to them, still has.
const UNWELL_CONE := 0.5
## How much of it somebody deep in conversation has.
const CHATTING_CONE := 0.6
## How much quicker than their patrol they walk to where somebody was seen.
const INVESTIGATE_PACE := 1.3
## How quickly they turn to face somebody they have noticed.
const WATCH_TURN_SPEED := 6.0

## Where they look right now.
var facing := Vector2.RIGHT
## Walking and looking about. Set by the StealthWatch once the map is up.
var active := false
## Stood still with their gaze held - a conversation, a menu, or having just
## spotted somebody.
var holding := false
var sprite: CombatantSprite = null

var _points: Array = []
var _router: Callable = Callable()
var _leg: Array = []
var _next := 0
var _step := 1
var _pause_left := 0.0
var _rest_facing := Vector2.RIGHT
var _look_clock := 0.0
## Where a guard with no patrol stands, and which way they look there, to go
## back to after a search.
var _post := Vector2.ZERO
var _post_facing := Vector2.RIGHT
var _search_left := 0.0


func _set_facing_degrees(value: float):
	facing_degrees = value
	facing = Vector2.RIGHT.rotated(deg_to_rad(value))
	queue_redraw()


func _set_kind(value: Kind):
	kind = value
	queue_redraw()


func _set_smell_tiles(value: float):
	smell_tiles = value
	queue_redraw()


func _ready():
	facing = Vector2.RIGHT.rotated(deg_to_rad(facing_degrees))
	if Engine.is_editor_hint():
		queue_redraw()
		return
	var definition: CombatantDefinition = CombatantDatabase.combatants.get(combatant_key)
	if definition == null:
		push_warning("Guard '%s' is a '%s', which is not in the combatant database." % [name, combatant_key])
		return
	sprite = CombatantSprite.new()
	add_child(sprite)
	sprite.setup(definition.sprite_frames, definition.map_sprite, false)
	sprite.z_as_relative = false
	sprite.z_index = ExplorationParty.PARTY_Z_TOP
	_face_sprite()


## Sets them walking. `points` are the patrol's waypoints as positions, in
## order; `router` finds the way between two positions.
func start(points: Array, router: Callable):
	_points = points
	_router = router
	_rest_facing = facing
	_post = global_position
	_post_facing = facing
	active = true
	hunting = false
	mood = Mood.PATROLLING
	if asleep and moves():
		mood = Mood.ASLEEP
		_leg = []
		return
	if not _points.is_empty():
		_next = 0
		_leg = _router.call(global_position, _points[0])


## Half of how wide they see right now, in degrees - wider still the more
## alert the map is, and never past all the way round.
func half_cone() -> float:
	var half := HALF_CONE
	match mood:
		Mood.INVESTIGATING, Mood.SEARCHING:
			half = HALF_CONE_ALERT
		Mood.SICK, Mood.TENDING:
			half = HALF_CONE * UNWELL_CONE
		Mood.CHATTING:
			if _errand_there:
				half = HALF_CONE * CHATTING_CONE
	return minf(half + alert_cone, 180.0)


## Whether they are still watching anything at all.
func is_awake() -> bool:
	return not knocked_out


## Whether they see nothing whatever right now: out cold, asleep, or being sick.
func sees_nothing() -> bool:
	return knocked_out or mood == Mood.ASLEEP or mood == Mood.RETCHING


## Whether they walk about and react - everything but a ward.
func moves() -> bool:
	return kind != Kind.WARD


## Whether they would be in a fight here - not a ward, and not somebody who is
## nobody's guard.
func fights() -> bool:
	return kind != Kind.WARD and kind != Kind.CIVILIAN


## Where their patrol takes them, in order, as positions - empty for somebody
## who stands at their post.
func patrol_points() -> Array:
	return _points


## Where they stand when they have no patrol, and which way they look there.
func post() -> Vector2:
	return _post


## Whether they are about their ordinary business and could be sent on an
## errand: awake, walking their beat or back to it, with nothing else on.
func is_free() -> bool:
	return not knocked_out and moves() and (mood == Mood.PATROLLING or mood == Mood.RETURNING) and not holding


## --- Errands ---
##
## Somewhere to go and something to do there - eat, talk, be sick, see to a
## sick colleague, bring round a knocked-out one, tell a guard what they saw -
## after which they go back to their beat. The StealthWatch sends them, and
## says what the errand is for.

## The moods that are errands: walked to, stayed at, then left for the beat.
const ERRANDS := [Mood.CHATTING, Mood.EATING, Mood.RETCHING, Mood.SICK, Mood.TENDING, Mood.REPORTING, Mood.WAKING]
## The moods nothing draws them out of: being sick, too unwell to stand, or
## asleep. Somebody running to tell a guard what they saw has no mind for
## anything else either.
const ABSORBED := [Mood.RETCHING, Mood.SICK, Mood.ASLEEP, Mood.REPORTING]

var _errand_at := Vector2.ZERO
var _errand_face := Vector2.ZERO
var _errand_left := 0.0
var _errand_there := false
var _errand_pace := 1.0
var _on_arrival := Callable()
var _on_done := Callable()
## What they were at when a noise turned their head, to go back to after.
var _before_listening: Mood = Mood.PATROLLING


## Sends them off to `at`, to be `what` (one of ERRANDS) there for `seconds` -
## INF for until end_errand(). `arrived` is called when they get there and
## `done` when the time is up, after which they go back to their beat. While
## there they look at `face`, if given, walking there at `pace` times their
## usual speed.
func send_on_errand(what: Mood, at: Vector2, seconds: float, arrived := Callable(), done := Callable(),
		pace := 1.0, face := Vector2.ZERO):
	mood = what
	hunting = false
	_errand_at = at
	_errand_face = face
	_errand_left = seconds
	_errand_pace = pace
	_errand_there = false
	_on_arrival = arrived
	_on_done = done
	_leg = _route_to(at) if global_position.distance_to(at) > 1.0 else []


## Whether they are on an errand - on the way, or there.
func on_errand() -> bool:
	return mood in ERRANDS


## Whether they have got where their errand takes them.
func errand_arrived() -> bool:
	return on_errand() and _errand_there


## Where their errand takes them.
func errand_at() -> Vector2:
	return _errand_at


## Seconds left of the errand once there - INF for one that lasts until ended.
func errand_left() -> float:
	return _errand_left


## Ends the errand here and now, without its `done`, and back to the beat.
func end_errand():
	if not on_errand():
		return
	_on_arrival = Callable()
	_on_done = Callable()
	back_to_beat()


## Back to where their patrol was heading, or to their post.
func back_to_beat():
	mood = Mood.RETURNING
	hunting = false
	_errand_there = false
	_leg = _route_to(_points[_next] if not _points.is_empty() else _post)


## Forgets any errand's calls, so nothing is done on their behalf after
## they were drawn off it.
func _drop_errand():
	_on_arrival = Callable()
	_on_done = Callable()
	_errand_there = false


## --- What the watch tells them ---


## Somebody is in view at `at`: stop, and turn to them. A ward only notes it,
## and so does anybody too taken up with something to do anything about it.
func watching(at: Vector2):
	last_seen = at
	if moves() and not mood in ABSORBED:
		_drop_errand()
		mood = Mood.WATCHING


## Nobody in view now, but they are not done wondering: they stay put and keep
## looking where whoever it was was last.
func lost_sight():
	if mood == Mood.WATCHING:
		mood = Mood.SUSPICIOUS


## Their doubt has drained away without them being sure. Having seen something,
## they go and look.
func doubt_gone():
	if mood != Mood.WATCHING and mood != Mood.SUSPICIOUS:
		return
	investigate(last_seen)
	hunting = mood == Mood.INVESTIGATING


## Goes to look at `at` - where somebody was, a noise, a body.
func investigate(at: Vector2):
	if not moves() or knocked_out or mood in ABSORBED:
		return
	_drop_errand()
	hunting = false
	last_seen = at
	mood = Mood.INVESTIGATING
	_leg = _route_to(at)


## A noise at `at`. Close enough to matter, they turn to it for a moment - or,
## given `go_look`, go and see what it was. Somebody already watching somebody
## has better things to look at, and somebody being sick or too ill to stand
## has no mind for it. Asleep, it wakes them - and they go to see what it was.
func hear(at: Vector2, go_look: bool):
	if not moves() or knocked_out or mood == Mood.WATCHING:
		return
	if mood == Mood.ASLEEP:
		mood = Mood.PATROLLING
		investigate(at)
		return
	if mood in ABSORBED:
		return
	# Nobody's guard turns to a noise, but it is not their business to go and
	# see what it was.
	if go_look and kind != Kind.CIVILIAN:
		investigate(at)
		return
	# Turned for a moment from whatever they were at, and back to it after.
	_before_listening = mood if mood in ERRANDS else Mood.PATROLLING
	last_seen = at
	mood = Mood.LISTENING
	_listen_left = LISTEN_SECONDS


## Knocked out: down where they stand, and done watching.
func knock_out():
	knocked_out = true
	_drop_errand()
	mood = Mood.PATROLLING
	_leg = []
	if sprite != null and sprite.has_method("set_dead"):
		sprite.set_dead()


## Brought round by whoever found them: back on their feet, and back to their
## beat.
func wake_up():
	knocked_out = false
	if sprite != null and sprite.has_method("set_alive"):
		sprite.set_alive()
	back_to_beat()


func _process(delta):
	if Engine.is_editor_hint() or not active:
		return
	if knocked_out:
		return
	if holding:
		if sprite != null:
			sprite.play_idle()
		return
	if kind == Kind.WARD:
		# Round and round, whatever happens.
		facing = facing.rotated(deg_to_rad(ward_turn_degrees) * delta)
		_face_sprite()
		return
	match mood:
		Mood.LISTENING:
			if sprite != null:
				sprite.play_idle()
			var towards_noise = last_seen - global_position
			if towards_noise.length() > 1.0:
				facing = _turned_toward(facing, towards_noise, delta, WATCH_TURN_SPEED)
			_face_sprite()
			_listen_left -= delta
			if _listen_left <= 0.0:
				# Nothing more to it. On with whatever they were doing.
				mood = _before_listening
				_before_listening = Mood.PATROLLING
			return
		Mood.ASLEEP:
			if sprite != null:
				sprite.play_idle()
			return
		Mood.CHATTING, Mood.EATING, Mood.RETCHING, Mood.SICK, Mood.TENDING, Mood.REPORTING, Mood.WAKING:
			_run_errand(delta)
			return
		Mood.WATCHING, Mood.SUSPICIOUS:
			# Stopped dead, turned to face them.
			if sprite != null:
				sprite.play_idle()
			var towards = last_seen - global_position
			if towards.length() > 1.0:
				facing = _turned_toward(facing, towards, delta, WATCH_TURN_SPEED)
			_face_sprite()
			return
		Mood.INVESTIGATING:
			if _walk(delta, INVESTIGATE_PACE):
				mood = Mood.SEARCHING
				_search_left = search_seconds
				_rest_facing = facing
				_look_clock = 0.0
			return
		Mood.SEARCHING:
			_search_left -= delta
			_look_about(delta)
			if _search_left <= 0.0:
				# Nothing there. Back to their beat - to where their patrol was
				# heading, or to their post.
				mood = Mood.RETURNING
				hunting = false
				_leg = _route_to(_points[_next] if not _points.is_empty() else _post)
			return
		Mood.RETURNING:
			if _walk(delta):
				mood = Mood.PATROLLING
				if _points.is_empty():
					facing = _post_facing
					_rest_facing = _post_facing
				_pause_left = pause_seconds
			return
	if not _leg.is_empty():
		if _walk(delta):
			# Arrived: a stop to look about, facing the way they came in.
			_pause_left = pause_seconds
			_rest_facing = facing
			_look_clock = 0.0
		return
	if _points.size() < 2:
		# Nowhere else to be: stand, and keep an eye out.
		_stand(delta)
		return
	_pause_left -= delta
	_stand(delta)
	if _pause_left <= 0.0:
		_head_for_next()


## On the way to their errand, or at it until its time is up.
func _run_errand(delta: float):
	if not _errand_there:
		if not _walk(delta, _errand_pace):
			return
		_errand_there = true
		var arrived = _on_arrival
		_on_arrival = Callable()
		if arrived.is_valid():
			arrived.call()
		# Arriving may have been the end of it.
		if not on_errand():
			return
	if sprite != null:
		sprite.play_idle()
	if _errand_face != Vector2.ZERO:
		var towards = _errand_face - global_position
		if towards.length() > 1.0:
			facing = _turned_toward(facing, towards, delta, WATCH_TURN_SPEED)
		_face_sprite()
	if _errand_left == INF:
		return
	_errand_left -= delta
	if _errand_left <= 0.0:
		var done = _on_done
		_on_done = Callable()
		back_to_beat()
		# After going back, so what it calls can send them off again.
		if done.is_valid():
			done.call()


func _route_to(where: Vector2) -> Array:
	return _router.call(global_position, where) if _router.is_valid() else [where]


## Walks the leg under way, `pace` times their patrol speed. True once it is
## walked to its end.
func _walk(delta: float, pace: float = 1.0) -> bool:
	if _leg.is_empty():
		return true
	var budget = Grid.tiles(walk_speed_tiles * pace * (1.0 + alert_pace)) * delta
	while budget > 0.0 and not _leg.is_empty():
		var target: Vector2 = _leg[0]
		var offset = target - global_position
		var distance = offset.length()
		if distance > 0.01:
			facing = _turned_toward(facing, offset, delta)
		if distance <= budget:
			global_position = target
			budget -= distance
			_leg.pop_front()
		else:
			global_position += offset / distance * budget
			budget = 0.0
	if sprite != null:
		sprite.play_walk()
	_face_sprite()
	return _leg.is_empty()


func _stand(delta: float):
	if looks_around:
		_look_about(delta)
		return
	if sprite != null:
		sprite.play_idle()
	_face_sprite()


## Sweeps their gaze from side to side about the way they last faced.
func _look_about(delta: float):
	if sprite != null:
		sprite.play_idle()
	_look_clock += delta
	var sweep = deg_to_rad(LOOK_AROUND_DEGREES) * sin(_look_clock / LOOK_AROUND_SECONDS * TAU)
	facing = _rest_facing.rotated(sweep)
	_face_sprite()


func _head_for_next():
	if _points.size() < 2:
		return
	if back_and_forth:
		if _next + _step >= _points.size() or _next + _step < 0:
			_step = -_step
		_next += _step
	else:
		_next = (_next + 1) % _points.size()
	_leg = _router.call(global_position, _points[_next]) if _router.is_valid() else [_points[_next]]


## Whether they see who is under `disguise` - an ItemDefinition worn, or null
## for somebody wearing nothing, who is always seen for who they are.
func sees_through(disguise: ItemDefinition) -> bool:
	if disguise == null or not disguise.is_disguise():
		return true
	# Talked round already, whatever they would otherwise have seen.
	if fooled:
		return false
	# No disguise fools a nose, or a charm.
	if kind == Kind.DOG or kind == Kind.WARD:
		return true
	match recognises:
		Recognises.ANY_DISGUISE:
			return true
		Recognises.NO_DISGUISE:
			return false
	return disguise.disguise_as == combatant_key


## `current` turned towards `wanted` by no more than a turn's worth, so a guard
## coming round a corner sweeps their gaze round it rather than snapping.
func _turned_toward(current: Vector2, wanted: Vector2, delta: float, speed: float = TURN_SPEED) -> Vector2:
	var angle = current.angle_to(wanted)
	var most = speed * delta
	return current.rotated(clampf(angle, -most, most))


func _face_sprite():
	if sprite != null and absf(facing.x) > 0.01:
		sprite.set_facing(facing.x < 0.0)


## In the editor: which way they look, as the edges of their cone.
func _draw():
	if not Engine.is_editor_hint():
		return
	var reach = Grid.tiles(1.5)
	var half = deg_to_rad(StealthSight.HALF_CONE_DEGREES)
	var colour = Color(1.0, 0.45, 0.35, 0.9)
	draw_circle(Vector2.ZERO, Grid.tiles(0.25), Color(colour, 0.35))
	match kind:
		Kind.DOG:
			# A nose, not eyes: everything within smell, all the way round.
			draw_arc(Vector2.ZERO, Grid.tiles(smell_tiles), 0.0, TAU, 48, colour, 4.0)
		Kind.WARD:
			draw_arc(Vector2.ZERO, reach, 0.0, TAU, 32, Color(colour, 0.4), 3.0)
			draw_line(Vector2.ZERO, facing.rotated(-half) * reach, colour, 6.0)
			draw_line(Vector2.ZERO, facing.rotated(half) * reach, colour, 6.0)
		_:
			draw_line(Vector2.ZERO, facing.rotated(-half) * reach, colour, 6.0)
			draw_line(Vector2.ZERO, facing.rotated(half) * reach, colour, 6.0)
			draw_arc(Vector2.ZERO, reach, facing.angle() - half, facing.angle() + half, 24, colour, 4.0)
	if kind != Kind.WATCHMAN:
		draw_string(ThemeDB.fallback_font, Vector2(-40, -Grid.tiles(0.4)), Kind.keys()[kind].capitalize(),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 28, colour)
	if asleep:
		draw_string(ThemeDB.fallback_font, Vector2(-40, -Grid.tiles(0.4) + 32), "Asleep",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 28, colour)
