extends Node2D
class_name StealthWatch
## The stealth half of an exploration map with a StealthSetup in it: runs the
## guards, draws what they can see, and decides when somebody has been seen.
##
## Not turn based. Every frame each guard looks along their cone (see
## StealthSight), and anybody in the party standing on a tile they can see
## fills that guard's meter - quickly up close, slowly far off. Break the line
## before it fills and the doubt drains away again; let it fill and the fight
## starts where everyone stands: the guards on their tiles, the party on theirs.
##
## What is drawn on the map is what the guards see - the same tiles spotting is
## judged by - so a tile that is not lit up is a tile nobody is watching.

## How long somebody has to stay in view before a guard is sure, in seconds:
## this quick right beside them...
const SURE_WHEN_CLOSE := 0.4
## ...and this slow at FAR_TILES or beyond.
const SURE_WHEN_FAR := 1.6
const FAR_TILES := 10.0
## How fast a guard's doubt fades once nobody is in view: a full meter's worth
## in two seconds.
const DOUBT_FADES := 0.5
## How long the "!" hangs over whoever spotted them before the fight starts.
const CAUGHT_PAUSE := 0.8

## The dash (Shift): this many tiles, over this many seconds, and then not again
## for DASH_COOLDOWN seconds.
const DASH_TILES := 3.0
const DASH_SECONDS := 0.2
const DASH_COOLDOWN := 5.0
## How much faster a guard grows sure of somebody dashing across their view -
## a blur of movement is the one thing a watchman does notice. Meant to be done
## where nobody is looking.
const DASH_NOTICE := 3.0
## The facing is rounded to this many degrees before what a guard sees is
## worked out again, so a sweeping gaze is not recomputed every frame.
const FACING_STEP_DEGREES := 4.0

## The tint on everything a guard can see: combat's colour for where the enemy
## is looking, so it reads the same in both modes.
const SEEN_FILL := Color(0.62, 0.38, 0.9, 0.22)
const SEEN_EDGE := Color(0.72, 0.5, 1.0, 0.7)
const METER_BACK := Color(0.08, 0.1, 0.14, 0.8)
const METER_DOUBT := Color("e0b04a")
const METER_SURE := Color("e05a4a")

## How see-through anyone sneaking is drawn - combat's look for a hidden ally.
const SNEAKING_ALPHA := 0.55

## --- Feeling watched ---
## How solid the amber round the screen's edges gets as the fullest meter fills,
## and the red it turns once a guard is sure.
const VIGNETTE_AT_FULL := 0.6
const VIGNETTE_CAUGHT := 0.85
## How far the camera leans in while somebody is watching: 6% at a full meter.
## Enough to feel, not enough to lose sight of anything.
const PRESSURE_ZOOM := 0.06
## How quickly the camera settles on that - and back out again, the moment
## nobody is looking. Higher is quicker.
const PRESSURE_EASE := 6.0

## The "?" over a guard pulses, faster the surer they are: from this many
## radians a second at the first flicker of doubt to this many at nearly sure,
## by this share of its size.
const PULSE_SLOW := 4.0
const PULSE_FAST := 18.0
const PULSE_SIZE := 0.1
## Cyrus starting at being noticed: a "!" over him for this long, and a flinch.
const STARTLE_SECONDS := 0.7

## --- Caught ---
## Time crawls for a moment when the "!" lands: this fast, for this many real
## seconds. The screen shakes this many pixels, and the "!" grows in from
## CAUGHT_POP_FROM of a "?"'s size, overshoots, and settles at CAUGHT_SIZE.
const CAUGHT_TIME_SCALE := 0.3
const CAUGHT_SLOW_SECONDS := 0.5
const CAUGHT_SHAKE := 26.0
const CAUGHT_POP_FROM := 0.4
const CAUGHT_SIZE := 1.3
const POP_SECONDS := 0.5

## --- Sound ---
## A heartbeat while anyone is growing sure: a beat every HEART_SLOW seconds at
## the first doubt, every HEART_FAST at nearly sure, and louder as it goes.
const HEART_SLOW := 1.0
const HEART_FAST := 0.32
const HEART_QUIET_DB := -22.0
const HEART_LOUD_DB := -4.0
## The music muffles as the fullest meter fills: the cutoff of the low-pass on
## the Music bus with nobody sure, and at a full meter.
const MUSIC_CLEAR_HZ := 20500.0
const MUSIC_MUFFLED_HZ := 650.0

## The prompt over whoever a click is for, and the ring at their feet.
const PROMPT_RING := Color(0.96, 0.84, 0.52, 0.9)
const PROMPT_KEY := Color("f2d38a")
const PROMPT_CANNOT := Color("8a919c")

## Off-screen guards who are growing sure get an arrow at the screen's edge,
## this far in from it.
const ARROW_MARGIN := 36.0
const ARROW_SIZE := 22.0

## --- The tools ---
## A dash is heard this far away: guards within it turn to the sound.
const DASH_NOISE_TILES := 4.0
## How far something can be thrown, in tiles, and it needs a clear line.
const THROW_TILES := 7.0
## Cat's Ears (Q): every guard heard, walls or not, for this long - then not
## again for EARS_COOLDOWN seconds after it wears off.
const EARS_SECONDS := 4.0
const EARS_COOLDOWN := 4.0
## "Right beside": close enough to take a guard down or pick their pockets, and
## close enough for a guard to find somebody in a hiding spot. In tiles.
const REACH_TILES := 1.3
## A guard going to look for somebody he saw looks into every hiding spot this
## many tiles about where he saw them, from anywhere he can see it - a body
## stuffed into one included.
const SEARCH_SPOTS_TILES := 3.0
## How see-through somebody tucked into a hiding spot is drawn.
const HIDDEN_ALPHA := 0.3
## How sure a guard with questions grows before stopping a disguised party.
const QUESTION_AT := 0.5
## How much quicker a guard who sees through a disguise grows sure: whoever is
## in it is walking about openly, not skulking - which is why taking it off
## (Hide) before passing somebody it will not fool is worth doing.
const DISGUISE_EXPOSED := 2.0
## Putting a disguise on takes this long, standing still - and anybody who
## sees him at it knows him at once (see caught_red_handed).
const DISGUISE_SECONDS := 3.0
## A takedown is heard this far off: guards within it come to see what it was.
const TAKEDOWN_NOISE_TILES := 5.0
## Dragging a body, he walks at this share of his usual pace - and a guard who
## sees him at it, or at changing clothes, knows him at once (see
## caught_red_handed).
const DRAG_PACE := 0.5

## --- The map's alert ---
## Raised by every investigation a doubtful guard sets off, a level by a body
## found - pinned there for good - and all the way by a captain's shout. It
## never eases by itself: a word from somebody in a disguise a guard trusts
## (R, see reassure) settles it a level at a time, and never below where a
## found body pinned it. While it is up every guard walks up to ALERT_PACE
## quicker, looks ALERT_CONE degrees wider either side and grows sure up to
## ALERT_FILL quicker.
const ALERT_PER_INVESTIGATION := 0.5
const ALERT_WARY := 0.34
const ALERT_ALARMED := 0.67
## Where each level starts - Calm, Wary, Alarmed - and what each is called.
const ALERT_LEVELS := [0.0, ALERT_WARY, ALERT_ALARMED]
const ALERT_NAMES := ["Calm", "Wary", "Alarmed"]
const ALERT_PACE := 0.4
const ALERT_CONE := 20.0
const ALERT_FILL := 0.6
## How long a guard takes to bring round somebody knocked out, once beside them.
const WAKE_SECONDS := 3.0
## How long a word in a guard's ear takes, standing still.
const REASSURE_SECONDS := 2.0
## How long a noise's ripple is drawn for.
const RIPPLE_SECONDS := 0.7

var scene: Node = null
var setup: StealthSetup = null
## The map's root, which guards and hiding spots are named from.
var _map: Node = null
var sight: StealthSight = null
var guards: Array = []
## Guard -> 0..1, how sure they are.
var suspicion := {}
## Whoever filled their meter, once somebody has.
var spotted_by: Guard = null
## Off in tests, which want the fight built and handed to Campaign without the
## scene changing under them.
var leave_for_battle := true

var _tile_map: TileMap = null
var _seen := {}
var _seen_key := {}
var _meters: Node2D = null
## Party member key -> the disguise they have on (an item key). Nobody listed is
## sneaking in their own clothes.
var _worn := {}
var _bar: StealthBar = null
## Seconds until the dash can be used again.
var _dash_cooldown := 0.0
var _vignette: PressureVignette = null
## How far the camera is leaning in for being watched, and how much of that is
## on it right now - kept apart from whatever zoom the player chose with the
## wheel, so the two never fight.
var _pressure_zoom := 0.0
var _applied_zoom := 0.0
var _was_watched := false
## When Cyrus last started at being noticed, in seconds since start-up.
var _startled_at := -1000.0
## How much bigger than it settles the "!" is drawn right now.
var _pop := 1.0
## Whether time has been slowed for the catch and not yet put back.
var _slowed := false
var _heart: AudioStreamPlayer = null
var _sting: AudioStreamPlayer = null
var _beat_in := 0.0
var _muffle: AudioEffectLowPassFilter = null
var _music_bus := -1
var _arrows: Control = null
var _prompt: PanelContainer = null
## How on edge the whole map is, 0 to 1. See the constants above.
var alert := 0.0
## How low it can ever be settled again: where a body found pinned it.
var alert_floor := 0.0
## Bodies whose finding has already put the map a level up, so one body found
## twice - dragged off before the finder got to it, and found again - does not
## put it up twice.
var _alarmed_by := {}
## Knocked-out guard -> whoever is on the way to bring them round.
var _waking := {}
## The guard a disguised party is having a word with, while they are at it.
var _reassuring: Guard = null
## Whether any guard has ever so much as begun to notice anybody here.
var _noticed_ever := false
var _ears_left := 0.0
var _ears_cooldown := 0.0
## The item being aimed to throw, or "".
var _aiming := ""
## The last thing thrown, which T picks up again while there is one to throw.
var _last_thrown := ""
var _hiding_spots: Array = []
## Knocked-out guard -> whether another guard has found them yet.
var _bodies := {}
## Guards a captain's shout has brought running: they start the fight with
## him, however far off they were.
var _called := {}
## Noises just made: [where, when], for the ripple.
var _ripples: Array = []
## The body being dragged, and the way the leader has walked since picking it
## up - the body follows along it, a place behind the last of the party.
var _dragging: Guard = null
var _drag_path: Array = []
## Knocked-out guard -> the hiding spot they have been stuffed into.
var _stashed := {}
## Stashed bodies a hunting guard has found in their hiding spot anyway.
var _stashed_found := {}
## The disguise being put on, and how long it has left.
var _changing_into := ""
var _change_left := 0.0
var _shuffle: Tween = null
var _shuffle_left := false


## Starts watching. Called by ExplorationScene once the map and the party are
## up; the guards are whatever Guard nodes the map holds.
func begin(the_scene: Node, the_setup: StealthSetup, tile_map: TileMap):
	scene = the_scene
	Campaign.stealth_watch = self
	setup = the_setup
	_tile_map = tile_map
	sight = StealthSight.new(tile_map)
	# Pulling back to see where the guards are looking is part of playing a
	# stealth map, so here the wheel zooms the camera an ordinary map keeps at
	# one framing. It still follows the party - zooming closes in and pulls back
	# around them rather than wandering off towards the pointer.
	var camera = scene.get("camera")
	if camera != null and "allow_zoom" in camera:
		camera.allow_zoom = true
	z_index = 1
	_meters = _Meters.new()
	_meters.watch = self
	_meters.z_as_relative = false
	_meters.z_index = ExplorationParty.PARTY_Z_TOP + 10
	add_child(_meters)
	guards = []
	_map = scene.get_node_or_null("Map")
	if _map != null:
		for node in _map.find_children("*", "Guard", true, false):
			guards.append(node)
		_hiding_spots = _map.find_children("*", "HidingSpot", true, false)
	_collect_floors()
	_collect_world()
	# On edge from the start, if the map says so. A map walked back onto after
	# a fight has the alert it was left with instead - see _restore.
	if setup != null:
		alert = ALERT_LEVELS[clampi(setup.starting_alert, 0, 2)]
	# Back after a fight here: whoever fought and lost is gone, and the rest
	# carry on from where things stood - see snapshot().
	var before = Campaign.stealth_state.get(scene.map_path())
	if before != null:
		for guard in guards.duplicate():
			if before.defeated.has(_id_of(guard)):
				guards.erase(guard)
				guard.queue_free()
	elif Campaign.is_trigger_cleared(trigger()):
		# Beaten, with nothing remembered of how: nobody is watching any more.
		for guard in guards:
			guard.queue_free()
		guards = []
		return
	for guard in guards:
		suspicion[guard] = 0.0
		var points := []
		for waypoint in guard.patrol:
			var at = Actors.waypoint_position(waypoint)
			if at == null:
				push_warning("Guard '%s' patrols to a waypoint called '%s', which this map does not have." % [guard.name, waypoint])
				continue
			points.append(at)
		guard.start(points, Actors.route)
	_collect_chats()
	_collect_edibles()
	_collect_objectives()
	# The disguises and Hide, on their own strip of the screen.
	var layer := CanvasLayer.new()
	layer.name = "StealthHud"
	add_child(layer)
	# Under the bar, so the bar is never tinted.
	_vignette = PressureVignette.new()
	layer.add_child(_vignette)
	_arrows = _EdgeArrows.new()
	_arrows.watch = self
	layer.add_child(_arrows)
	_prompt = _Prompt.new()
	_prompt.watch = self
	layer.add_child(_prompt)
	_heart = _player("Heartbeat", setup.heartbeat_sound if setup.heartbeat_sound != null else StealthWatch.heartbeat_placeholder())
	_sting = _player("Sting", setup.caught_sound if setup.caught_sound != null else StealthWatch.sting_placeholder())
	_add_muffle()
	_bar = StealthBar.new()
	_bar.watch = self
	layer.add_child(_bar)
	var listed = _ObjectiveList.new()
	listed.watch = self
	layer.add_child(listed)
	if before != null:
		_restore(before)


## --- Carrying on after a fight ---
##
## Caught, the map is written down before the fight - who is knocked out and
## where, whose pockets are picked, who has been talked round, what he has on,
## how on edge everybody is - and read back when the party walks in again, so
## the stage carries on rather than starting over. Campaign fills in who fought
## and lost once the fight is won; they are not there any more.


## A guard or a hiding spot's name for the record: its path from the map.
func _id_of(node: Node) -> String:
	return String(_map.get_path_to(node)) if _map != null else String(node.name)


## How things stand, with `fight` about to be fought.
func snapshot(fight: EncounterDefinition) -> Dictionary:
	var before = Campaign.stealth_state.get(scene.map_path(), {})
	var state := {
		"fighting": [],
		"defeated": before.get("defeated", []).duplicate(),
		"down": {},
		"picked": [],
		"talked_round": [],
		"worn": _worn.duplicate(),
		"alert": alert,
		"alert_floor": alert_floor,
		"noticed": _noticed_ever,
		"reassured": [],
		"lamps_out": _lamps.filter(func(lamp): return is_instance_valid(lamp) and not lamp.lit).map(_id_of),
		"doors_open": _doors.filter(func(door): return is_instance_valid(door) and door.is_open).map(_id_of),
		"taken": _pickups.filter(func(pickup): return is_instance_valid(pickup) and pickup.taken).map(_id_of),
		"stats": stats.duplicate(),
		"ever_alarmed": _ever_alarmed,
		"carried": _carried.keys().filter(func(objective): return is_instance_valid(objective)).map(_id_of),
		"eaten": _edibles.filter(func(edible): return is_instance_valid(edible) and edible.eaten).map(_id_of),
		"laced": {},
	}
	for edible in _edibles:
		if is_instance_valid(edible) and edible.poisoned_with != "" and not edible.eaten:
			state.laced[_id_of(edible)] = edible.poisoned_with
	for spawn in fight.spawns:
		if spawn.side == 1 and spawn.has_meta("guard"):
			state.fighting.append(spawn.get_meta("guard"))
	for guard in guards:
		if not is_instance_valid(guard):
			continue
		var id = _id_of(guard)
		if guard.picked:
			state.picked.append(id)
		if guard.questioned:
			state.talked_round.append([id, guard.fooled])
		if guard.reassured:
			state.reassured.append(id)
		if guard.knocked_out:
			state.down[id] = {
				"at": guard.global_position,
				# Found, somebody was on the way to bring him round - and by the
				# time the fight is over, has.
				"found": _bodies.get(guard, false) or _stashed_found.has(guard),
				"stashed": _id_of(_stashed[guard]) if _stashed.has(guard) else "",
			}
	return state


## The doors, lamps and things lying about as they were left - and anything
## out of place still there to be noticed.
func _restore_world(state: Dictionary):
	for lamp in _lamps:
		if state.get("lamps_out", []).has(_id_of(lamp)):
			lamp.set_lit(false)
			if lamp.starts_lit:
				_add_oddity(lamp, "lamp", INF)
	for door in _doors:
		var open = state.get("doors_open", []).has(_id_of(door))
		if open != door.is_open:
			door.set_open(open)
			_apply_door(door)
		if open != door.starts_open:
			_add_oddity(door, "door", INF)
	for pickup in _pickups:
		if state.get("taken", []).has(_id_of(pickup)):
			pickup.taken = true
			pickup.queue_redraw()
			if pickup.missed_when_taken:
				_add_oddity(pickup, "item", MISSED_TILES)
	for edible in _edibles:
		if state.get("eaten", []).has(_id_of(edible)):
			edible.mark_eaten()
		edible.poisoned_with = state.get("laced", {}).get(_id_of(edible), "")
	_relight()


func _restore(state: Dictionary):
	alert = state.get("alert", 0.0)
	_restore_world(state)
	stats.merge(state.get("stats", {}), true)
	_ever_alarmed = state.get("ever_alarmed", false)
	for objective in _objectives:
		if state.get("carried", []).has(_id_of(objective)):
			_carried[objective] = true
	alert_floor = state.get("alert_floor", 0.0)
	_noticed_ever = state.get("noticed", false)
	_worn = state.get("worn", {}).duplicate()
	var talked := {}
	for pair in state.get("talked_round", []):
		talked[pair[0]] = pair[1]
	for guard in guards:
		var id = _id_of(guard)
		guard.picked = state.get("picked", []).has(id)
		guard.reassured = state.get("reassured", []).has(id)
		if talked.has(id):
			guard.questioned = true
			guard.fooled = talked[id]
		var down = state.get("down", {}).get(id)
		if down == null:
			continue
		# Found before the fight: brought round while it was fought, and back on
		# his beat - the alert already went up for him.
		if down.found:
			_alarmed_by[guard] = true
			continue
		guard.global_position = down.at
		guard.knock_out()
		guard.visible = true
		_bodies[guard] = false
		var spot = _map.get_node_or_null(down.stashed) if down.stashed != "" else null
		if spot is HidingSpot:
			guard.global_position = spot.global_position
			guard.visible = false
			spot.holds_body = guard
			_stashed[guard] = spot
			_bodies.erase(guard)
			_add_oddity(spot, "spot", DISTURBED_TILES)


## --- Disguises and hiding ---
##
## Whoever leads can put on a disguise they are carrying and walk about in it
## openly: drawn as whoever it copies, and past any guard it fools (see
## Guard.recognises). Hide takes it off again and puts them back to sneaking -
## but only out of everybody's sight, the rule combat's Stealth goes by.


## Whoever is steering, by combatant key.
func leader_key() -> String:
	var members = Campaign.party_members()
	return members[0].key if not members.is_empty() else ""


## The disguises the leader is carrying.
func disguises() -> Array:
	return Campaign.disguises_of(leader_key())


## What `key` has on, as an item key, or "".
func worn_by(key: String) -> String:
	var item_key: String = _worn.get(key, "")
	# Given away or used up since, and so no longer on them.
	if item_key != "" and Campaign.count_of(key, item_key) == 0:
		_worn.erase(key)
		return ""
	return item_key


## Starts putting on `item_key`, if the leader is carrying it and it is a
## disguise: DISGUISE_SECONDS standing still, shuffling into it, and only then
## is he wearing it. False, and nothing started, when he cannot right now.
func wear(item_key: String) -> bool:
	if wear_refusal() != "" or not disguises().has(item_key) or worn_by(leader_key()) == item_key:
		return false
	_changing_into = item_key
	_change_left = DISGUISE_SECONDS
	var party = scene.get("party")
	if party != null:
		party.rooted = true
		_start_shuffle(party)
	return true


## Why the leader could not start putting a disguise on right now, or "".
func wear_refusal() -> String:
	if spotted_by != null:
		return "Too late for that"
	if _changing_into != "":
		return "Already changing"
	if _dragging != null:
		return "Not while dragging a body"
	if _reassuring != null:
		return "Not while talking"
	if _lacing != null:
		return "Not while poisoning"
	return ""


## Whether the leader is doing something nobody innocent does - dragging a
## body, changing into a disguise, or stirring poison into somebody's supper -
## so that any guard who sees him at it is sure of him on the spot, rather than
## growing sure.
func caught_red_handed() -> bool:
	return _dragging != null or _changing_into != "" or _lacing != null


## The disguise being put on right now, or "".
func changing_into() -> String:
	return _changing_into


## Seconds until the disguise being put on is on.
func change_left() -> float:
	return _change_left


## The disguise is on: drawn as whoever it copies from here.
func _finish_change():
	if _changing_into != "":
		_worn[leader_key()] = _changing_into
	_stop_changing()
	# Seen in it from this very frame, so he is drawn in it from this one too.
	_dress_the_party()


## Stops a change part-way - caught at it, say. Nothing is put on.
func _stop_changing():
	_changing_into = ""
	_change_left = 0.0
	var party = scene.get("party") if scene != null else null
	if party != null and is_instance_valid(party):
		party.rooted = false
		_stop_shuffle(party)


## Shuffling about, turning this way and that, while he changes - a stand-in
## until there is an animation for it.
func _start_shuffle(party):
	var leader: Node2D = party.leader
	if leader == null:
		return
	_stop_shuffle(party)
	_shuffle_left = party.facing_left()
	_shuffle = leader.create_tween().set_loops()
	_shuffle.tween_property(leader, "rotation", deg_to_rad(-7.0), 0.12)
	_shuffle.parallel().tween_property(leader, "scale", Vector2(1.06, 0.94), 0.12)
	_shuffle.tween_property(leader, "rotation", deg_to_rad(6.0), 0.14)
	_shuffle.parallel().tween_property(leader, "scale", Vector2(0.95, 1.05), 0.14)
	_shuffle.tween_callback(_turn_about.bind(leader))
	_shuffle.tween_property(leader, "rotation", 0.0, 0.1)
	_shuffle.parallel().tween_property(leader, "scale", Vector2.ONE, 0.1)


func _turn_about(leader):
	if not is_instance_valid(leader):
		return
	_shuffle_left = not _shuffle_left
	leader.set_facing(_shuffle_left)


func _stop_shuffle(party):
	if _shuffle != null and _shuffle.is_valid():
		_shuffle.kill()
	_shuffle = null
	var leader = party.leader
	if leader != null and is_instance_valid(leader):
		leader.rotation = 0.0
		leader.scale = Vector2.ONE
		leader.set_facing(party.facing_left())


## Why the leader could not hide right now, or "" when they could.
func hide_refusal() -> String:
	var key = leader_key()
	if worn_by(key) == "":
		return "Already out of sight"
	var party = scene.get("party")
	var sprite = party.sprite_for(key) if party != null else null
	if sprite != null:
		var tile = tile_of(sprite.global_position)
		for guard in guards:
			if is_instance_valid(guard) and sees(guard, tile):
				return "Can't hide while %s can see him" % _name_of(guard)
	return ""


## Takes the leader's disguise off and puts them back to sneaking, if nobody
## is looking. False, and nothing changed, when somebody is. Not called hide(),
## which is every Node2D's own and means "stop drawing".
func hide_again() -> bool:
	if spotted_by != null or hide_refusal() != "":
		return false
	_worn.erase(leader_key())
	return true


## --- The dash ---


## Dashes the leader DASH_TILES the way the keys are held (or the way they
## face), if the dash is ready. False, and nothing done, when it is not.
func dash() -> bool:
	if spotted_by != null or _dash_cooldown > 0.0 or dash_refusal() != "":
		return false
	if scene.has_method("is_holding") and scene.is_holding():
		return false
	var party = scene.get("party")
	if party == null or not party.dash(party.held_direction(), Grid.tiles(DASH_TILES), DASH_SECONDS):
		return false
	_dash_cooldown = DASH_COOLDOWN
	# Heard, if not seen: guards near enough turn to the sound.
	make_noise(party.leader.global_position, DASH_NOISE_TILES, false)
	return true


## Seconds until the dash is ready again; zero when it is.
func dash_cooldown() -> float:
	return _dash_cooldown


## --- The vault (V) ---
##
## Over a tile that stops somebody walking but not somebody flying - a barrel,
## a crate, anything waist-high - to the free tile straight across it. A wall
## stops fliers too, and is not vaulted.

const VAULT_SECONDS := 0.35


## Whether `tile` is something to vault: in the way on foot, clear in the air.
func is_cover(tile: Vector2i) -> bool:
	var data = _tile_map.get_cell_tile_data(0, tile) if _tile_map != null else null
	if data == null:
		return false
	var blocks = data.get_custom_data("Blocks")
	return 0 in blocks and not 1 in blocks


## [the cover, the tile beyond it] for the vault the leader could make right
## now - the way the keys are held, or he faces, first - or [] for none.
func vault_over() -> Array:
	var party = scene.get("party") if scene != null else null
	if party == null or party.leader == null or vault_refusal() != "":
		return []
	var at = tile_of(party.leader.global_position)
	var ways := []
	var held: Vector2 = party.held_direction()
	if held != Vector2.ZERO:
		ways.append(Vector2i(roundi(held.x), 0) if absf(held.x) >= absf(held.y) else Vector2i(0, roundi(held.y)))
	ways.append(Vector2i.LEFT if party.facing_left() else Vector2i.RIGHT)
	ways.append_array([Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP])
	for way in ways:
		var cover: Vector2i = at + way
		var landing: Vector2i = at + way * 2
		if is_cover(cover) and _free_to_land(landing):
			return [cover, landing]
	return []


func _free_to_land(tile: Vector2i) -> bool:
	if not scene.has_method("is_walkable") or not scene.is_walkable(_tile_map.to_global(_tile_map.map_to_local(tile))):
		return false
	for guard in guards:
		# Anybody standing or lying there - not one stuffed out of the way.
		if is_instance_valid(guard) and tile_of(guard.global_position) == tile and not _stashed.has(guard):
			return false
	return true


## Why he could not vault right now, or "".
func vault_refusal() -> String:
	if spotted_by != null:
		return "Too late for that"
	if _dragging != null:
		return "Not while dragging a body"
	if _changing_into != "":
		return "Not while changing"
	if _lacing != null:
		return "Not while poisoning"
	var party = scene.get("party") if scene != null else null
	if party != null and (party.dashing or party.vaulting):
		return "Already moving"
	return ""


## Hops over the cover beside him to the far side. False, and nothing done,
## when there is none to hop.
func vault() -> bool:
	if scene.has_method("is_holding") and scene.is_holding():
		return false
	var over = vault_over()
	var party = scene.get("party")
	if over.is_empty() or party == null:
		return false
	var landing = _tile_map.to_global(_tile_map.map_to_local(over[1]))
	return party.vault(party.to_local(landing), VAULT_SECONDS)


## Why he could not dash right now, cooldown aside, or "".
func dash_refusal() -> String:
	if _dragging != null:
		return "Not while dragging a body"
	if _changing_into != "":
		return "Not while changing"
	if _lacing != null:
		return "Not while poisoning"
	return ""


## How much of a guard's meter somebody `tiles` away fills in a second -
## quicker up close, and DASH_NOTICE times quicker while they dash.
func fill_rate(tiles: float, dashing: bool) -> float:
	var seconds = lerpf(SURE_WHEN_CLOSE, SURE_WHEN_FAR, clampf(tiles / FAR_TILES, 0.0, 1.0))
	return (1.0 / seconds) * (DASH_NOTICE if dashing else 1.0)


## --- The map's alert ---


## Puts the map `amount` more on edge, up to fully alarmed.
func raise_alert(amount: float):
	alert = clampf(alert + amount, 0.0, 1.0)


## Which level `value` is at: 0 Calm, 1 Wary, 2 Alarmed.
static func level_of(value: float) -> int:
	if value >= ALERT_ALARMED:
		return 2
	if value >= ALERT_WARY:
		return 1
	return 0


## "Calm", "Wary" or "Alarmed", for the bar.
func alert_level() -> String:
	return ALERT_NAMES[level_of(alert)]


## Puts the map a level more on edge - to the top of it, from Alarmed - and,
## `pinned`, never lets it be settled below that level again.
func raise_alert_level(pinned: bool = false):
	var level = level_of(alert)
	alert = 1.0 if level == 2 else maxf(alert, ALERT_LEVELS[level + 1])
	if pinned:
		alert_floor = maxf(alert_floor, ALERT_LEVELS[level_of(alert)])


## Settles the map a level, as far as the floor allows. False, and nothing
## changed, when it will not settle any further.
func lower_alert_level() -> bool:
	var level = level_of(alert)
	if level <= level_of(alert_floor):
		return false
	alert = maxf(ALERT_LEVELS[level - 1], alert_floor)
	return true


## Hands every guard what the alert adds to them right now. The cone's share
## is rounded to whole steps, so a guard's view is not worked out afresh for
## every hair the alert moves.
func _apply_alert():
	if level_of(alert) == 2:
		_ever_alarmed = true
	for guard in guards:
		if is_instance_valid(guard):
			guard.alert_pace = ALERT_PACE * alert
			guard.alert_cone = snappedf(ALERT_CONE * alert, FACING_STEP_DEGREES)


## --- Noise ---


## A noise at `at` (a world position): every guard within `tiles` of it turns
## to it - or, given `go_look`, goes to see what it was. Heard through walls:
## that is what makes it a noise.
func make_noise(at: Vector2, tiles: float, go_look: bool):
	_ripples.append([at, Time.get_ticks_msec() / 1000.0, tiles])
	for guard in guards:
		if not is_instance_valid(guard) or guard.knocked_out:
			continue
		if guard.global_position.distance_to(at) <= Grid.tiles(tiles):
			guard.hear(at, go_look)


## --- Doors, lamps, and things lying about ---
##
## A door (StealthDoor) shut stops walking and sight both; a guard walking
## through holds it open as he goes. A dark map (StealthSetup's Dark) is lit
## only by its lamps (Lamp) and wall torches, and a guard makes somebody out
## in the dark only close up. Things lying about (StealthPickup) can be taken.
##
## And guards notice what has changed: a door left open that should be shut,
## a lamp out that should be lit, something gone that should be there, a
## hiding spot with a body stuffed in it. Seeing one, a guard goes to look -
## the map a little more on edge for it - and puts it right if he can: shuts
## the door, lights the lamp, pulls the body out.

## How dark the dark is drawn, where no light reaches.
const DARK_ALPHA := 0.62
## The wall torch in the laboratory tileset - see StagePainter.
const TORCH_TILE := Vector2i(2, 4)
## How near a guard has to be to notice something gone from where it stood,
## and to notice a hiding spot has somebody stuffed in it. A door left open
## or a lamp gone dark is noticed from anywhere it can be seen.
const MISSED_TILES := 5.0
const DISTURBED_TILES := 2.0

var _doors: Array = []
var _lamps: Array = []
var _pickups: Array = []
## Map tile -> how brightly lit, 0 to 1, on a dark map.
var _lit := {}
## Bumped whenever a door or a lamp changes, so every guard's view is worked
## out again.
var _world_version := 0
## Things out of place: [{node, what, near, by, alarmed}] - `by` the guard on
## his way to look, `alarmed` once noticing it has put the map up.
var _oddities: Array = []
var _dark: Node2D = null


func _collect_world():
	_doors = []
	_lamps = []
	_pickups = []
	if _map != null:
		_doors = _map.find_children("*", "StealthDoor", true, false)
		_lamps = _map.find_children("*", "Lamp", true, false)
		_pickups = _map.find_children("*", "StealthPickup", true, false)
	for door in _doors:
		_apply_door(door)
	_dark = _Dark.new()
	_dark.watch = self
	_dark.z_index = -1
	add_child(_dark)
	_relight()


## Whether this map is dark but for its lights.
func is_dark() -> bool:
	return setup != null and setup.dark


## How lit `tile` is, 0 to 1. Everywhere is lit on a map that is not dark.
func lit_at(tile: Vector2i) -> float:
	return _lit.get(tile, 0.0) if is_dark() else 1.0


## Whether the leader is standing somewhere no light reaches.
func leader_in_shadow() -> bool:
	var party = scene.get("party") if scene != null else null
	if not is_dark() or party == null or party.leader == null:
		return false
	return lit_at(tile_of(party.leader.global_position)) <= 0.0


## Works out afresh what every lamp and torch lights.
func _relight():
	_lit = {}
	_world_version += 1
	if _dark != null:
		_dark.queue_redraw()
	if not is_dark() or sight == null:
		return
	for source in _light_sources():
		var from: Vector2i = source[0]
		var reach: float = source[1]
		var r = ceili(reach)
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var tile = from + Vector2i(dx, dy)
				var d = Vector2(dx, dy).length()
				if d > reach or not sight.region().has_point(tile):
					continue
				if tile != from and not sight.clear(from, tile):
					continue
				# Brightest at the flame, fading towards the edge.
				var bright = 1.0 - 0.6 * pow(d / maxf(reach, 0.01), 2.0)
				_lit[tile] = maxf(_lit.get(tile, 0.0), bright)


## [tile, reach] for every lit lamp, and every torch on the walls.
func _light_sources() -> Array:
	var sources := []
	for lamp in _lamps:
		if is_instance_valid(lamp) and lamp.lit and lamp.light_tiles > 0.0:
			sources.append([tile_of(lamp.global_position), lamp.light_tiles])
	if setup != null and setup.torch_light_tiles > 0.0 and _tile_map != null:
		var region = sight.region()
		for x in range(region.position.x, region.end.x):
			for y in range(region.position.y, region.end.y):
				if _tile_map.get_cell_atlas_coords(0, Vector2i(x, y)) == TORCH_TILE:
					sources.append([Vector2i(x, y), setup.torch_light_tiles])
	return sources


## Opens or shuts `door`. `by_hand`: the party did it - so a door meant to be
## shut, left open, is something a guard will notice. False, and nothing
## changed, when somebody is standing in it.
func set_door(door: StealthDoor, open: bool, by_hand: bool = false, shut_by: Node = null) -> bool:
	if not open and _someone_in(door, shut_by):
		if by_hand and scene.has_method("log_message"):
			scene.log_message("Somebody is in the way.\n")
		return false
	door.set_open(open)
	_apply_door(door)
	if by_hand:
		if open != door.starts_open:
			_add_oddity(door, "door", INF)
		else:
			_remove_oddity(door)
	return true


## Keeps the map's walls - for walking and for sight - in step with the door.
func _apply_door(door: StealthDoor):
	var tile = tile_of(door.global_position)
	var shut = not door.passable()
	sight.set_shut(tile, shut)
	if scene.has_method("set_tile_shut"):
		scene.set_tile_shut(tile, shut)
	door.queue_redraw()
	_relight()


## Whether anybody but `but` is standing in the doorway.
func _someone_in(door: StealthDoor, but: Node = null) -> bool:
	var tile = tile_of(door.global_position)
	for someone in _party_standing():
		if someone.tile == tile:
			return true
	for guard in guards:
		if is_instance_valid(guard) and guard != but and tile_of(guard.global_position) == tile:
			return true
	return false


## A guard coming through a shut door opens it as he gets to it, and it
## swings shut behind him.
func _update_doors():
	for door in _doors:
		if not is_instance_valid(door):
			continue
		var held := false
		for guard in guards:
			if is_instance_valid(guard) and not guard.knocked_out \
					and guard.global_position.distance_to(door.global_position) < Grid.tiles(0.8):
				held = true
				break
		if held != door.held:
			door.held = held
			_apply_door(door)


## Puts out `lamp` - `knocked`: by something thrown, which is not quiet about
## it. False when it was not lit, or cannot be put out.
func put_out(lamp: Lamp, knocked: bool = false) -> bool:
	if not is_instance_valid(lamp) or not lamp.lit or not lamp.can_be_put_out:
		return false
	lamp.set_lit(false)
	_relight()
	if lamp.starts_lit:
		_add_oddity(lamp, "lamp", INF)
	if scene.has_method("log_message"):
		scene.log_message("The lamp goes out.\n" if knocked else "You pinch out the lamp.\n")
	return true


## Takes `pickup` into the leader's bag. False when there is no room.
func take_pickup(pickup: StealthPickup) -> bool:
	if not is_instance_valid(pickup) or pickup.taken:
		return false
	if not Campaign.give_item(leader_key(), pickup.item_key):
		if scene.has_method("log_message"):
			scene.log_message("No room to carry it.\n")
		return false
	pickup.mark_taken()
	if pickup.missed_when_taken:
		_add_oddity(pickup, "item", MISSED_TILES)
	return true


func _add_oddity(node: Node2D, what: String, near: float):
	for odd in _oddities:
		if odd.node == node:
			return
	_oddities.append({"node": node, "what": what, "near": near, "by": null, "alarmed": false})


func _remove_oddity(node: Node2D):
	_oddities = _oddities.filter(func(odd): return odd.node != node)


## Whether `node`'s tile is in `guard`'s view - light or no light, and a wall
## lamp counting as seen from the floor in front of it.
func _in_view_of(guard: Guard, node: Node2D, near: float) -> bool:
	var from = tile_of(guard.global_position)
	var tile = tile_of(node.global_position)
	var towards = Vector2(tile - from)
	if towards.length() > near:
		return false
	if from != tile and absf(rad_to_deg(guard.facing.angle_to(towards))) > guard.half_cone():
		return false
	return from == tile or sight.clear(from, tile)


## A guard about his business notices what is out of place, and goes to look.
func _notice_oddities(guard: Guard):
	if guard.sees_nothing() or not guard.moves() or guard.kind == Guard.Kind.CIVILIAN:
		return
	if not guard.mood in [Guard.Mood.PATROLLING, Guard.Mood.RETURNING, Guard.Mood.LISTENING, Guard.Mood.SEARCHING]:
		return
	for odd in _oddities:
		if odd.by != null or not is_instance_valid(odd.node) or not _in_view_of(guard, odd.node, odd.near):
			continue
		odd.by = guard
		guard.investigate(odd.node.global_position)
		if not odd.alarmed:
			odd.alarmed = true
			raise_alert(ALERT_PER_INVESTIGATION)
		if scene.has_method("log_message"):
			scene.log_message("[color=yellow]%s[/color] %s.\n" % [_name_of(guard), {
				"door": "notices a door left open",
				"lamp": "notices a lamp gone out",
				"item": "notices something gone",
				"spot": "notices something odd about a hiding spot",
			}.get(odd.what, "notices something")])
		return


## Whoever went to look at something out of place, once there, puts it right.
func _see_to_oddities():
	for odd in _oddities.duplicate():
		var guard = odd.by
		if guard == null:
			continue
		if not is_instance_valid(guard) or guard.knocked_out or not (guard.mood == Guard.Mood.INVESTIGATING or guard.mood == Guard.Mood.SEARCHING):
			# Drawn off it: there to be noticed again, without putting the map
			# up a second time.
			odd.by = null
			continue
		if guard.mood != Guard.Mood.SEARCHING or guard.global_position.distance_to(odd.node.global_position) > Grid.tiles(1.6):
			continue
		var node = odd.node
		match odd.what:
			"lamp":
				node.set_lit(true)
				_relight()
				_remove_oddity(node)
				if scene.has_method("log_message"):
					scene.log_message("[color=yellow]%s[/color] lights the lamp again.\n" % _name_of(guard))
			"door":
				if set_door(node, node.starts_open, false, guard):
					_remove_oddity(node)
					if scene.has_method("log_message"):
						scene.log_message("[color=yellow]%s[/color] shuts the door.\n" % _name_of(guard))
			"item":
				_remove_oddity(node)
			"spot":
				_remove_oddity(node)
				var body = node.holds_body
				if body is Guard and _stashed.has(body):
					_found(body, guard)


## --- Guards who meet to talk (see GuardChat) ---

## [{node, a, b, clock, phase, line, line_left, heard, missing}] - phase one of
## "waiting", "gathering" or "talking".
var _chats: Array = []
## Guard -> [what they are saying, whether the party can make it out].
var saying := {}


func _collect_chats():
	_chats = []
	if _map == null:
		return
	for chat in _map.find_children("*", "GuardChat", true, false):
		var a = _guard_named(chat.first_guard)
		var b = _guard_named(chat.second_guard)
		if a == null or b == null:
			push_warning("GuardChat '%s' names a guard this map does not have ('%s', '%s')." % [chat.name, chat.first_guard, chat.second_guard])
			continue
		_chats.append({"node": chat, "a": a, "b": b, "clock": chat.first_after_seconds, "phase": "waiting",
			"line": 0, "line_left": 0.0, "heard": [], "missing": null})


func _guard_named(called: String) -> Guard:
	for guard in guards:
		if is_instance_valid(guard) and String(guard.name) == called:
			return guard
	return null


## Whether `guard` is in no state to keep an appointment: out cold, being
## sick, too ill to stand.
func _away(guard) -> bool:
	return not is_instance_valid(guard) or guard.knocked_out or guard.mood == Guard.Mood.RETCHING or guard.mood == Guard.Mood.SICK


func _run_chats(delta: float):
	for chat in _chats:
		var node: GuardChat = chat.node
		match chat.phase:
			"waiting":
				chat.clock -= delta
				if chat.clock > 0.0:
					continue
				var a_away = _away(chat.a)
				var b_away = _away(chat.b)
				if a_away or b_away:
					chat.clock = node.every_seconds
					if node.check_in and not (a_away and b_away):
						var here: Guard = chat.b if a_away else chat.a
						if here.is_free():
							_missed(here, chat.a if a_away else chat.b, chat)
						else:
							chat.clock = 5.0
					continue
				if not chat.a.is_free() or not chat.b.is_free():
					# Busy - on the way back from something. Soon, then.
					chat.clock = 5.0
					continue
				_gather(chat)
			"gathering":
				if not _still_chatting(chat):
					_break_up(chat)
				elif chat.a.errand_arrived() and chat.b.errand_arrived():
					chat.phase = "talking"
					chat.line = 0
					chat.line_left = node.seconds_per_line
					chat.heard = []
					_talk(chat, 0.0)
			"talking":
				if not _still_chatting(chat):
					_break_up(chat)
					continue
				_talk(chat, delta)


## The line being said, heard or not, and on to the next once its time is up.
func _talk(chat: Dictionary, delta: float):
	var node: GuardChat = chat.node
	var lines: Array = node.lines
	var speaker: Guard = chat.a if chat.line % 2 == 0 else chat.b
	var other: Guard = chat.b if speaker == chat.a else chat.a
	var said: String = lines[chat.line] if chat.line < lines.size() else "..."
	var heard = chat.line < lines.size() and _overhears(speaker, node)
	saying[speaker] = [said, heard]
	saying.erase(other)
	if heard and not chat.heard.has(chat.line):
		chat.heard.append(chat.line)
		if scene.has_method("log_message"):
			scene.log_message("[color=yellow]%s[/color]: %s\n" % [_name_of(speaker), said])
	chat.line_left -= delta
	if chat.line_left > 0.0:
		return
	chat.line += 1
	chat.line_left = node.seconds_per_line
	if chat.line < maxi(lines.size(), 2):
		return
	if not lines.is_empty() and chat.heard.size() == lines.size() and node.overheard_flag != "" \
			and not Campaign.flag(node.overheard_flag):
		Campaign.set_flag(node.overheard_flag)
		if scene.has_method("log_message"):
			scene.log_message("[color=lightgreen]You heard every word of it.[/color]\n")
	_break_up(chat)


## Sends the two to their spots to talk.
func _gather(chat: Dictionary):
	var node: GuardChat = chat.node
	var a_at: Vector2 = chat.a.global_position
	if node.first_stands_at != "":
		var at = Actors.waypoint_position(node.first_stands_at)
		if at != null:
			a_at = at
	var b_at = null
	if node.second_stands_at != "":
		b_at = Actors.waypoint_position(node.second_stands_at)
	if b_at == null:
		# Beside the first, on the side he comes from.
		var beside = _free_tile_near(tile_of(a_at) + Vector2i(signi(tile_of(chat.b.global_position).x - tile_of(a_at).x), 0),
			{tile_of(a_at): true})
		b_at = _tile_map.to_global(_tile_map.map_to_local(beside))
	chat.a.send_on_errand(Guard.Mood.CHATTING, a_at, INF, Callable(), Callable(), 1.0, b_at)
	chat.b.send_on_errand(Guard.Mood.CHATTING, b_at, INF, Callable(), Callable(), 1.0, a_at)
	chat.phase = "gathering"


## Whether both are still at it - a noise turning a head does not end it.
func _still_chatting(chat: Dictionary) -> bool:
	for guard in [chat.a, chat.b]:
		if not is_instance_valid(guard) or guard.knocked_out:
			return false
		if guard.mood != Guard.Mood.CHATTING and not (guard.mood == Guard.Mood.LISTENING and guard._before_listening == Guard.Mood.CHATTING):
			return false
	return true


func _break_up(chat: Dictionary):
	for guard in [chat.a, chat.b]:
		saying.erase(guard)
		if is_instance_valid(guard) and guard.mood == Guard.Mood.CHATTING:
			guard.end_errand()
	chat.phase = "waiting"
	chat.clock = chat.node.every_seconds


## Whether the party can make out what `speaker` says: within earshot, or
## twice that listening.
func _overhears(speaker: Guard, chat: GuardChat) -> bool:
	var party = scene.get("party")
	if party == null or party.leader == null:
		return false
	var reach = chat.earshot_tiles * (2.0 if _ears_left > 0.0 else 1.0)
	return party.leader.global_position.distance_to(speaker.global_position) <= Grid.tiles(reach)


## Time to meet, and `missing` is not there: `here` puts the map on edge -
## once for him - and goes to look where he should be.
func _missed(here: Guard, missing, chat: Dictionary):
	if chat.missing != missing:
		chat.missing = missing
		raise_alert(ALERT_PER_INVESTIGATION)
	var where: Vector2 = here.global_position
	if is_instance_valid(missing):
		where = missing.post() if _stashed.has(missing) else missing.global_position
	here.investigate(where)
	if scene.has_method("log_message"):
		scene.log_message("[color=yellow]%s[/color] waits for [color=yellow]%s[/color], who does not come - and goes looking.\n" % [
			_name_of(here), _name_of(missing) if is_instance_valid(missing) else "somebody"])


## --- Nobody's guards (Guard.Kind.CIVILIAN) ---
##
## Somebody who is nobody's guard never fights. Sure of somebody - or seeing
## him at something no innocent does, or a takedown, or a body - they run to
## the nearest guard and tell him where, and he goes to look, hunting. Stop
## them before they get there, and nobody is told.

## How much quicker than their walk somebody runs to tell a guard.
const RUN_PACE := 1.8

## Civilian -> [where, the guard they are running to].
var _reporting := {}


## Whether `civilian` is off to tell somebody what they saw.
func is_reporting(civilian: Guard) -> bool:
	return _reporting.has(civilian)


func _run_to_tell(civilian: Guard, where: Vector2):
	if _reporting.has(civilian) or civilian.knocked_out:
		return
	suspicion[civilian] = 0.0
	var guard = _nearest_teller(civilian.global_position)
	if guard == null:
		return
	_reporting[civilian] = [where, guard]
	civilian.send_on_errand(Guard.Mood.REPORTING, guard.global_position, INF, Callable(), Callable(), RUN_PACE, guard.global_position)
	if scene.has_method("log_message"):
		scene.log_message("[color=yellow]%s[/color] runs to tell somebody!\n" % _name_of(civilian))


## The nearest guard somebody could run and tell.
func _nearest_teller(from: Vector2) -> Guard:
	var best: Guard = null
	var best_gap := INF
	for guard in guards:
		if not _can_wake(guard):
			continue
		var gap = guard.global_position.distance_to(from)
		if gap < best_gap:
			best = guard
			best_gap = gap
	return best


func _check_on_reporters():
	for civilian in _reporting.keys():
		var where: Vector2 = _reporting[civilian][0]
		var guard = _reporting[civilian][1]
		if not is_instance_valid(civilian) or civilian.knocked_out or civilian.mood != Guard.Mood.REPORTING:
			# Stopped on the way: nobody is told.
			_reporting.erase(civilian)
			continue
		if not _can_wake(guard):
			guard = _nearest_teller(civilian.global_position)
			if guard == null:
				_reporting.erase(civilian)
				civilian.end_errand()
				continue
			_reporting[civilian][1] = guard
		if civilian.global_position.distance_to(guard.global_position) <= Grid.tiles(1.6):
			_reporting.erase(civilian)
			civilian.end_errand()
			raise_alert(ALERT_PER_INVESTIGATION)
			guard.investigate(where)
			guard.hunting = guard.mood == Guard.Mood.INVESTIGATING
			if scene.has_method("log_message"):
				scene.log_message("[color=yellow]%s[/color] tells [color=yellow]%s[/color] what they saw - he goes to look.\n" % [
					_name_of(civilian), _name_of(guard)])
			continue
		# He has moved on since: after him.
		if civilian.errand_arrived() or civilian.errand_at().distance_to(guard.global_position) > Grid.tiles(1.5):
			civilian.send_on_errand(Guard.Mood.REPORTING, guard.global_position, INF, Callable(), Callable(), RUN_PACE, guard.global_position)


## A takedown seen by somebody who is nobody's guard: they run to tell.
func _witnesses(at: Vector2):
	var tile = tile_of(at)
	for guard in guards:
		if is_instance_valid(guard) and guard.kind == Guard.Kind.CIVILIAN and not guard.knocked_out and sees(guard, tile):
			_run_to_tell(guard, at)


## --- How it is going: the tally, and what there is to do ---
##
## Counted as the map is played - and carried through a fight in the
## snapshot - for the card at the way out (see scorecard) and the objectives
## under the bar (StealthObjective).

var stats := {"seconds": 0.0, "noticed": 0, "caught": 0, "ambushes": 0, "takedowns": 0,
	"sedated": 0, "poisoned": 0, "bodies_found": 0, "pockets": 0}
var _objectives: Array = []
## Objective -> true once something carried has made it done for good.
var _carried := {}
var _ever_alarmed := false

## What each rank means, for the card and the stage list.
const RANK_SAYS := {
	"Ghost": "Nobody so much as noticed.",
	"Shadow": "Noticed, but never caught.",
	"Brawler": "It came to blows.",
}


func _collect_objectives():
	_objectives = _map.find_children("*", "StealthObjective", true, false) if _map != null else []


## How an objective stands right now: "done", "lost" for good, or "open".
func objective_state(objective: StealthObjective) -> String:
	match objective.kind:
		StealthObjective.Kind.FLAG:
			return "done" if objective.flag != "" and Campaign.flag(objective.flag) else "open"
		StealthObjective.Kind.CARRY_ITEM:
			if not _carried.has(objective):
				for member in Campaign.party_members():
					if Campaign.count_of(member.key, objective.item_key) > 0:
						_carried[objective] = true
			return "done" if _carried.has(objective) else "open"
		StealthObjective.Kind.NO_TAKEDOWNS:
			return "lost" if stats.takedowns + stats.sedated > 0 else "open"
		StealthObjective.Kind.NEVER_ALARMED:
			return "lost" if _ever_alarmed else "open"
		StealthObjective.Kind.NOBODY_HARMED:
			return "lost" if stats.takedowns + stats.poisoned > 0 else "open"
	return "open"


## Every objective, as [what it says, how it stands] - at the way out, one
## that holds for as long as nothing goes wrong is done if nothing did.
func objectives(at_the_end: bool = false) -> Array:
	var listed := []
	for objective in _objectives:
		if not is_instance_valid(objective):
			continue
		var state = objective_state(objective)
		if at_the_end and state == "open":
			match objective.kind:
				StealthObjective.Kind.CALM_AT_THE_END:
					state = "done" if level_of(alert) == 0 else "lost"
				StealthObjective.Kind.NO_TAKEDOWNS, StealthObjective.Kind.NEVER_ALARMED, StealthObjective.Kind.NOBODY_HARMED:
					state = "done"
		listed.append([objective.description, state])
	return listed


## How it went: Ghost - nobody so much as noticed; Shadow - noticed, never
## caught; Brawler - it came to a fight.
func rank() -> String:
	if never_noticed():
		return "Ghost"
	if stats.caught == 0 and stats.ambushes == 0:
		return "Shadow"
	return "Brawler"


## Everything the card at the way out shows.
func scorecard() -> Dictionary:
	return {
		"rank": rank(),
		"says": RANK_SAYS[rank()],
		"seconds": stats.seconds,
		"noticed": stats.noticed,
		"fights": stats.caught + stats.ambushes,
		"takedowns": stats.takedowns,
		"poisoned": stats.poisoned,
		"bodies_found": stats.bodies_found,
		"pockets": stats.pockets,
		"objectives": objectives(true),
	}


## --- Poisons ---
##
## Three kinds (ItemDefinition.Poison): an emetic sends a guard off to be sick
## at the nearest RetchSpot for EMETIC_SECONDS, seeing nothing; a sedative
## drops him where he stands, a body like any other; a disease leaves him too
## unwell to move for DISEASE_SECONDS, and whoever is nearest comes to see to
## him - both of them watching half as wide. Each takes hold the moment it is
## swallowed or lands (Instant), POISON_SOON seconds after (Shortly), or
## POISON_DELAY seconds after (Delayed). Darts land where they are thrown; the
## rest go into something left out for a guard to eat (Edible).

const POISON_SOON := 5.0
const POISON_DELAY := 15.0
## Stirring a poison into somebody's supper takes this long, standing still -
## and anybody who sees him at it knows him at once (see caught_red_handed).
const LACE_SECONDS := 3.0
const EMETIC_SECONDS := 300.0
const DISEASE_SECONDS := 300.0
## How long a guard spends over his supper.
const EAT_SECONDS := 4.0
## How much quicker than his walk somebody who is about to be sick hurries.
const RETCH_PACE := 1.4

var _edibles: Array = []
## The supper being poisoned right now, with what, and how long it has left.
var _lacing: Edible = null
var _lacing_with := ""
var _lace_left := 0.0
var _fidget: Tween = null
## Edible -> seconds until its eater comes for it.
var _meal_clock := {}
## Edible -> the guard on his way to eat it.
var _eating := {}
## Guard -> [poison, seconds until it takes hold].
var _brewing := {}
## Carer -> the sick guard they are seeing to.
var _tending := {}


func _collect_edibles():
	_edibles = _map.find_children("*", "Edible", true, false) if _map != null else []
	for edible in _edibles:
		_meal_clock[edible] = edible.eaten_after_seconds


## Stirs `item_key` into `edible` - with nobody looking, or they know him at
## once, the way changing clothes in view does. False when it cannot be done.
func lace(edible: Edible, item_key: String) -> bool:
	var item: ItemDefinition = ItemDatabase.item(item_key) if item_key != "" else null
	if item == null or not item.is_poison() or item.poison_shootable or edible.eaten or edible.poisoned_with != "":
		return false
	if lace_refusal() != "" or Campaign.count_of(leader_key(), item_key) == 0 or _eating.has(edible):
		return false
	var party = scene.get("party")
	if party == null or party.leader == null:
		return false
	_lacing = edible
	_lacing_with = item_key
	_lace_left = LACE_SECONDS
	party.rooted = true
	_start_fidget(party.leader)
	return true


## Why he could not start stirring something into somebody's supper right
## now, or "".
func lace_refusal() -> String:
	if spotted_by != null:
		return "Too late for that"
	if _lacing != null:
		return "Already at it"
	if _changing_into != "":
		return "Not while changing"
	if _dragging != null:
		return "Not while dragging a body"
	if _reassuring != null:
		return "Not while talking"
	return ""


## The poison being stirred in right now, by item key, or "".
func lacing() -> String:
	return _lacing_with if _lacing != null else ""


## Seconds until it is in.
func lace_left() -> float:
	return _lace_left


## Time up: it is in, and out of the bag. Somebody got to it first - it was
## eaten, or its eater has sat down to it - and nothing is used.
func _finish_lacing():
	var edible = _lacing
	var item_key = _lacing_with
	_stop_lacing()
	if not is_instance_valid(edible) or edible.eaten or _eating.has(edible) or edible.poisoned_with != "":
		return
	if not Campaign.take_item(leader_key(), item_key):
		return
	edible.poisoned_with = item_key
	if scene.has_method("log_message"):
		var item: ItemDefinition = ItemDatabase.item(item_key)
		scene.log_message("You stir the %s into the %s.\n" % [item.name, edible.called])


## Stops, finished or not - caught at it, say. Nothing is used up.
func _stop_lacing():
	_lacing = null
	_lacing_with = ""
	_lace_left = 0.0
	var party = scene.get("party") if scene != null else null
	if party != null and is_instance_valid(party) and _changing_into == "" and _reassuring == null:
		party.rooted = false
	if _fidget != null and _fidget.is_valid():
		_fidget.kill()
	_fidget = null
	if party != null and is_instance_valid(party) and party.leader != null:
		party.leader.scale = Vector2.ONE


## Crouched over it, working: a bob up and down - a stand-in until there is an
## animation for it.
func _start_fidget(leader: Node2D):
	if _fidget != null and _fidget.is_valid():
		_fidget.kill()
	_fidget = leader.create_tween().set_loops()
	_fidget.tween_property(leader, "scale", Vector2(1.05, 0.9), 0.18)
	_fidget.tween_property(leader, "scale", Vector2(0.97, 1.02), 0.22)


## Every guard whose supper time has come goes to eat it; whoever has eaten
## it gets whatever was in it.
func _run_meals(delta: float):
	for edible in _edibles:
		if not is_instance_valid(edible) or edible.eaten:
			continue
		if _eating.has(edible):
			var eater = _eating[edible]
			if not is_instance_valid(eater) or eater.mood != Guard.Mood.EATING:
				# Called away from it: he comes back for it later.
				_eating.erase(edible)
				_meal_clock[edible] = 10.0
			continue
		_meal_clock[edible] = _meal_clock.get(edible, 0.0) - delta
		if _meal_clock[edible] > 0.0:
			continue
		var eater = _guard_named(edible.eater)
		if eater == null or eater.knocked_out:
			continue
		if not eater.is_free():
			_meal_clock[edible] = 5.0
			continue
		_eating[edible] = eater
		eater.send_on_errand(Guard.Mood.EATING, edible.global_position, EAT_SECONDS, Callable(), _ate.bind(edible, eater),
			1.0, edible.global_position)


func _ate(edible: Edible, eater: Guard):
	_eating.erase(edible)
	edible.mark_eaten()
	if scene.has_method("log_message"):
		scene.log_message("[color=yellow]%s[/color] has his %s.\n" % [_name_of(eater), edible.called])
	if edible.poisoned_with != "":
		dose(eater, ItemDatabase.item(edible.poisoned_with))


## `guard` has had `item`: it takes hold now, or - delayed - in a while.
func dose(guard: Guard, item: ItemDefinition):
	if item == null or not item.is_poison() or not is_instance_valid(guard) or guard.knocked_out:
		return
	stats.poisoned += 1
	match item.poison_onset:
		ItemDefinition.Onset.INSTANT:
			_poison_takes(guard, item.poison)
		ItemDefinition.Onset.DELAYED:
			_brewing[guard] = [item.poison, POISON_DELAY]
		_:
			_brewing[guard] = [item.poison, POISON_SOON]


func _brew(delta: float):
	for guard in _brewing.keys():
		if not is_instance_valid(guard) or guard.knocked_out:
			_brewing.erase(guard)
			continue
		_brewing[guard][1] -= delta
		if _brewing[guard][1] <= 0.0:
			var poison = _brewing[guard][0]
			_brewing.erase(guard)
			_poison_takes(guard, poison)


## Seconds until a delayed poison in `guard` takes hold, or -1 for none.
func brewing_in(guard: Guard) -> float:
	return _brewing[guard][1] if _brewing.has(guard) else -1.0


func _poison_takes(guard: Guard, poison: int):
	var say := ""
	match poison:
		ItemDefinition.Poison.EMETIC:
			guard.send_on_errand(Guard.Mood.RETCHING, _retch_spot_for(guard), EMETIC_SECONDS, Callable(), Callable(), RETCH_PACE)
			say = "clutches his stomach and hurries off"
		ItemDefinition.Poison.SEDATIVE:
			stats.sedated += 1
			guard.knock_out()
			suspicion[guard] = 0.0
			_bodies[guard] = false
			say = "slumps where he stands, out cold"
		ItemDefinition.Poison.DISEASE:
			guard.send_on_errand(Guard.Mood.SICK, guard.global_position, DISEASE_SECONDS, Callable(), _recovered.bind(guard))
			say = "sways, and sinks down, too ill to stand"
			var carer = _nearest_carer(guard)
			if carer != null:
				_tending[carer] = guard
				var beside = _tile_map.to_global(_tile_map.map_to_local(
					_free_tile_near(tile_of(guard.global_position) + Vector2i.RIGHT, {tile_of(guard.global_position): true})))
				carer.send_on_errand(Guard.Mood.TENDING, beside, INF, Callable(), Callable(), Guard.INVESTIGATE_PACE, guard.global_position)
	if scene.has_method("log_message") and say != "":
		scene.log_message("[color=yellow]%s[/color] %s.\n" % [_name_of(guard), say])


## Where `guard` goes to be sick: the nearest RetchSpot, or where he stands.
func _retch_spot_for(guard: Guard) -> Vector2:
	var best := guard.global_position
	var best_gap := INF
	if _map != null:
		for spot in _map.find_children("*", "RetchSpot", true, false):
			var gap = spot.global_position.distance_to(guard.global_position)
			if gap < best_gap:
				best = spot.global_position
				best_gap = gap
	return best


## Whoever is nearest `patient` and free to see to him.
func _nearest_carer(patient: Guard) -> Guard:
	var best: Guard = null
	var best_gap := INF
	for guard in guards:
		if not is_instance_valid(guard) or guard == patient or not guard.is_free() or guard.kind == Guard.Kind.DOG:
			continue
		var gap = guard.global_position.distance_to(patient.global_position)
		if gap < best_gap:
			best = guard
			best_gap = gap
	return best


## Better: and whoever was seeing to him goes back to his round too.
func _recovered(patient: Guard):
	for carer in _tending.keys():
		if _tending[carer] == patient:
			_tending.erase(carer)
			if is_instance_valid(carer) and carer.mood == Guard.Mood.TENDING:
				carer.end_errand()


## Whoever is seeing to somebody no longer sick - knocked out, or better -
## goes back to his round.
func _check_on_carers():
	for carer in _tending.keys():
		var patient = _tending[carer]
		if not is_instance_valid(carer) or carer.mood != Guard.Mood.TENDING:
			_tending.erase(carer)
		elif not is_instance_valid(patient) or patient.mood != Guard.Mood.SICK:
			_tending.erase(carer)
			carer.end_errand()


## Who `guard` is seeing to, or null.
func tending(guard: Guard) -> Guard:
	return _tending.get(guard)


## --- Patience (hold P) ---
##
## Held, time runs PATIENCE_SCALE times as fast - everybody's, his too - for
## waiting out a patrol. Let go, or have anything hold the game (a
## conversation, a menu, a catch), and it is back to normal.

const PATIENCE_SCALE := 2.0

## Whether the bar's Patience button is being held down.
var patience_held := false
## Whether time is running fast for it right now.
var _hurried := false


## Whether Patience is being held: the button, or P.
func patient() -> bool:
	return patience_held or Input.is_physical_key_pressed(KEY_P)


## Whether time is running fast for Patience this moment.
func hurried() -> bool:
	return _hurried


func _hurry(on: bool):
	if on == _hurried:
		return
	_hurried = on
	# The slow moment of a catch has the clock, and gives it back itself.
	if not _slowed:
		Engine.time_scale = PATIENCE_SCALE if on else 1.0


func _notification(what: int):
	# A menu paused everything: nothing is waited out behind it, and the menu
	# is not to run at double speed either.
	if what == NOTIFICATION_PAUSED:
		_hurry(false)


## --- Noisy ground, and creeping (hold Ctrl) ---
##
## Gravel, puddles and broken glass (see NoisyFloor) give away whoever walks
## across them at an ordinary pace: a noise every STEP_SECONDS, heard as far as
## the ground says. Creeping crosses them without a sound, at CREEP_PACE.

const STEP_SECONDS := 0.5
const CREEP_PACE := 0.45

## Map tile -> the NoisyFloor covering it.
var _noisy := {}
## Party member key -> seconds to their next step being heard.
var _step_in := {}
## Where each of the party stood last frame, to tell walking from standing.
var _stood := {}
var _creep_kept := false


func _collect_floors():
	_noisy = {}
	if _map == null:
		return
	for patch in _map.find_children("*", "NoisyFloor", true, false):
		for tile in patch.covers(tile_of(patch.global_position)):
			_noisy[tile] = patch


## The noisy ground on `tile`, or null.
func noisy_floor_at(tile: Vector2i) -> NoisyFloor:
	return _noisy.get(tile)


## Whether the party is creeping: Ctrl held, or the bar's Creep kept on.
func creeping() -> bool:
	return _creep_kept or Input.is_physical_key_pressed(KEY_CTRL)


## Keeps creeping on, or lets it go - the bar's Creep, for playing with the mouse.
func toggle_creep():
	_creep_kept = not _creep_kept
	_set_pace()


## The party's pace for whatever they are doing: slower dragging a body,
## slower still creeping.
func _set_pace():
	var party = scene.get("party") if scene != null else null
	if party == null or not is_instance_valid(party):
		return
	party.pace = (DRAG_PACE if _dragging != null else 1.0) * (CREEP_PACE if creeping() else 1.0)


## Every member of the party walking noisy ground at an ordinary pace is heard,
## a step at a time.
func _listen_to_feet(delta: float):
	var party = scene.get("party")
	var quiet = creeping()
	for someone in _party_standing():
		var at: Vector2 = someone.sprite.global_position
		# Walking, not put somewhere: a teleport - arriving on the map - is no step.
		var stride = _stood[someone.key].distance_to(at) if _stood.has(someone.key) else 0.0
		var moved = stride > 0.5 and stride < Grid.tiles(1.0)
		_stood[someone.key] = at
		var ground = noisy_floor_at(someone.tile)
		if ground == null or not moved or (quiet and not (party != null and party.dashing)):
			_step_in[someone.key] = 0.0
			continue
		_step_in[someone.key] = _step_in.get(someone.key, 0.0) - delta
		if _step_in[someone.key] > 0.0:
			continue
		_step_in[someone.key] = STEP_SECONDS
		make_noise(at, ground.noise_tiles(), ground.brings_them())


## --- Throwing (T) ---


## Everything the leader carries to throw, each once: things to make a noise
## with, then darts.
func throwables() -> Array:
	return Campaign.distractions_of(leader_key()) + Campaign.darts_of(leader_key())


## What T would throw: the last thing thrown, while he still has one, or else
## the first he carries - or "".
func throwable() -> String:
	var carried = throwables()
	if carried.is_empty():
		return ""
	return _last_thrown if carried.has(_last_thrown) else carried[0]


## Starts aiming a throw of `item_key` - or of what T would throw - and the next
## click on the map says where. False when there is nothing to throw.
func begin_throw(item_key: String = "") -> bool:
	if spotted_by != null:
		return false
	if item_key == "":
		item_key = throwable()
	if item_key == "" or not throwables().has(item_key):
		return false
	_aiming = item_key
	_last_thrown = item_key
	return true


## Aiming already: on to the next thing he carries to throw, round and round.
func next_throwable():
	var carried = throwables()
	if _aiming == "" or carried.is_empty():
		return
	_aiming = carried[(carried.find(_aiming) + 1) % carried.size()]
	_last_thrown = _aiming
	queue_redraw()


## The item being aimed, or "".
func aiming() -> String:
	return _aiming


func cancel_throw():
	_aiming = ""
	queue_redraw()


func is_aiming() -> bool:
	return _aiming != ""


## Whether a throw from the leader can land on `tile`: near enough, with a clear
## line, on somewhere a thing can land.
func can_throw_to(tile: Vector2i) -> bool:
	var party = scene.get("party")
	if party == null or party.leader == null:
		return false
	var from = tile_of(party.leader.global_position)
	return Vector2(tile - from).length() <= THROW_TILES and not sight.stops_sight(tile) and sight.clear(from, tile)


## Whoever a dart landing on `tile` would find: somebody standing - or
## sleeping - on it.
func dart_target(tile: Vector2i) -> Guard:
	for guard in guards:
		if is_instance_valid(guard) and not guard.knocked_out and tile_of(guard.global_position) == tile:
			return guard
	return null


## Throws the item being aimed onto `tile`: gone from the bag, and a noise there
## that the guards within its radius go to look at - or, a dart, whatever its
## poison does to whoever it finds there. False, and nothing thrown, when it
## cannot land there.
func throw_at(tile: Vector2i) -> bool:
	var item_key = _aiming if _aiming != "" else throwable()
	var item: ItemDefinition = ItemDatabase.item(item_key) if item_key != "" else null
	if item == null or not can_throw_to(tile):
		return false
	Campaign.take_item(leader_key(), item_key)
	_aiming = ""
	_last_thrown = item_key
	if item.is_poison():
		var target = dart_target(tile)
		if scene.has_method("log_message"):
			scene.log_message("The dart finds [color=yellow]%s[/color].\n" % _name_of(target) if target != null
				else "The dart misses, and is lost.\n")
		if target != null:
			dose(target, item)
		_given_away_by_throwing()
		return true
	make_noise(_tile_map.to_global(_tile_map.map_to_local(tile)), item.distraction_radius, true)
	# Landing beside a lamp knocks it out.
	for lamp in _lamps:
		if is_instance_valid(lamp) and lamp.lit and Vector2(tile_of(lamp.global_position) - tile).length() <= 1.0:
			put_out(lamp, true)
	if scene.has_method("log_message"):
		scene.log_message("[color=yellow]%s[/color] lands with a clatter.\n" % item.name)
	_given_away_by_throwing()
	return true


## Who a throw from where the leader is would give him away to: tucked into a
## hiding spot, the arm going up over the barrels is the one thing about him
## that is not hidden - anybody with the spot in view sees it. Nobody, out in
## the open, where he is as seen as he is anyway.
func throw_watchers() -> Array:
	var watchers := []
	var party = scene.get("party") if scene != null else null
	if not leader_hiding() or party == null or party.leader == null:
		return watchers
	var tile = tile_of(party.leader.global_position)
	for guard in guards:
		if is_instance_valid(guard) and not guard.knocked_out and sees(guard, tile):
			watchers.append(guard)
	return watchers


## Thrown from a hiding spot somebody has in view: he is known at once - or,
## by somebody who is nobody's guard, off they run to tell.
func _given_away_by_throwing():
	if spotted_by != null:
		return
	var party = scene.get("party")
	var at: Vector2 = party.leader.global_position
	for guard in throw_watchers():
		if guard.kind == Guard.Kind.CIVILIAN:
			_run_to_tell(guard, at)
			continue
		if scene.has_method("log_message"):
			scene.log_message("[color=yellow]%s[/color] saw that thrown.\n" % _name_of(guard))
		suspicion[guard] = 1.0
		guard.watching(at)
		_caught_by(guard)
		return


func _unhandled_input(event):
	if scene == null:
		return
	if event is InputEventMouseMotion:
		# Whose round to show, if it is known.
		_hovered = _guard_on(tile_of(_world_at(event.position)))
	if _aiming == "":
		_click_on_guard(event)
		return
	if event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()
		if event.button_index == MOUSE_BUTTON_LEFT:
			throw_at(tile_of(_world_at(event.position)))
		else:
			cancel_throw()
	elif event is InputEventMouseMotion:
		queue_redraw()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cancel_throw()


## Where on the map a point on the screen is.
func _world_at(screen_position: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_position


## --- Cat's Ears (Q) ---


## Listens: every guard heard, and so shown, walls or not, for EARS_SECONDS.
## Only on a map that hides guards out of sight - anywhere else they are all on
## show already.
func listen() -> bool:
	if spotted_by != null or _ears_cooldown > 0.0 or not hides_guards():
		return false
	_ears_left = EARS_SECONDS
	# Counted from when it wears off, not from now.
	_ears_cooldown = EARS_SECONDS + EARS_COOLDOWN
	return true


func hides_guards() -> bool:
	return setup != null and setup.guards_seen_only_in_sight


func ears_left() -> float:
	return _ears_left


func ears_cooldown() -> float:
	return _ears_cooldown


## --- Knowing where they walk ---
##
## A guard's round is never shown for free. Found out - a duty roster read, a
## pocket picked, a conversation overheard, whatever sets his Route Known Flag
## - it is drawn while listening (Q), and while the pointer is on him.

## How a known round is drawn: a dotted line along it, a ring at each stop.
const ROUTE_COLOUR := Color(0.55, 0.85, 1.0, 0.75)
const ROUTE_DOT_TILES := 0.18

## The guard the pointer is on, for showing his round.
var _hovered: Guard = null


## Whether the party has found out `guard`'s round.
func route_known(guard: Guard) -> bool:
	return is_instance_valid(guard) and guard.route_known_flag != "" and Campaign.flag(guard.route_known_flag)


## Whether `guard`'s round is drawn right now: known, and listening or pointed at.
func route_shown(guard: Guard) -> bool:
	return route_known(guard) and not guard.knocked_out and (_ears_left > 0.0 or _hovered == guard)


## Every round drawn right now, as [guard, [positions...], whether it loops].
func shown_routes() -> Array:
	var shown := []
	for guard in guards:
		if is_instance_valid(guard) and route_shown(guard):
			var points: Array = guard.patrol_points()
			shown.append([guard, points if not points.is_empty() else [guard.post()], not guard.back_and_forth])
	return shown


func _draw_routes():
	for route in shown_routes():
		var points: Array = route[1]
		var stops := points.duplicate()
		if route[2] and points.size() > 2:
			stops.append(points[0])
		for i in range(stops.size() - 1):
			_dotted(to_local(stops[i]), to_local(stops[i + 1]))
		for point in points:
			draw_arc(to_local(point), Grid.tiles(0.28), 0.0, TAU, 24, ROUTE_COLOUR, 5.0)


func _dotted(from: Vector2, to: Vector2):
	var length := from.distance_to(to)
	var step: float = Grid.tiles(ROUTE_DOT_TILES * 2.0)
	var along: float = step * 0.5
	while along < length:
		draw_circle(from.lerp(to, along / length), Grid.tiles(0.05), ROUTE_COLOUR)
		along += step


## --- Where they think he is ---
##
## A guard out looking for somebody he saw is looking where he saw them: a
## ghost of the leader stands there, with a ring as far about it as the hiding
## spots he will look into (SEARCH_SPOTS_TILES) - so it is plain why a spot
## close by stopped being safe.

const GHOST_TINT := Color(0.8, 0.85, 1.0, 0.32)
const GHOST_RING := Color(0.8, 0.85, 1.0, 0.45)


## Where guards are looking for him right now, a tile apiece.
func sought_at() -> Array:
	var places := {}
	for guard in guards:
		if is_instance_valid(guard) and not guard.knocked_out and guard.is_hunting():
			places[tile_of(guard.last_seen)] = guard.last_seen
	return places.values()


func _draw_ghosts():
	var places := sought_at()
	if places.is_empty():
		return
	var party = scene.get("party")
	var leader = party.leader if party != null else null
	var frame: Dictionary = leader.current_frame() if leader != null and leader.has_method("current_frame") else {}
	for place in places:
		var centre = to_local(place)
		var segments := 20
		for i in segments:
			if i % 2 == 0:
				var a = TAU * i / segments
				draw_arc(centre, Grid.tiles(SEARCH_SPOTS_TILES), a, a + TAU / segments, 6, GHOST_RING, 5.0)
		if frame.is_empty():
			draw_circle(centre, Grid.tiles(0.3), GHOST_TINT)
			continue
		var size: Vector2 = frame.region.size
		draw_set_transform(centre + frame.offset, 0.0, Vector2(-1.0 if frame.flip else 1.0, 1.0))
		draw_texture_rect_region(frame.texture, Rect2(-size / 2.0, size), frame.region, GHOST_TINT)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## --- What the player sees ---


## Whether `guard` is on show to the player: always, unless this map hides
## guards out of sight - then only while the leader can see them, they are
## right beside him, they are growing sure of somebody, or he is listening.
func guard_shown(guard: Guard) -> bool:
	if _stashed.has(guard):
		return false
	if not hides_guards() or _ears_left > 0.0 or suspicion.get(guard, 0.0) > 0.0 or spotted_by == guard:
		return true
	var party = scene.get("party")
	if party == null or party.leader == null:
		return true
	var from = tile_of(party.leader.global_position)
	var to = tile_of(guard.global_position)
	return Vector2(to - from).length() <= REACH_TILES or sight.clear(from, to)


func _update_what_is_shown():
	for guard in guards:
		if is_instance_valid(guard):
			guard.visible = guard_shown(guard)


## --- Takedowns (left click) and pockets (right click) ---


## Whether `guard` is right beside the leader and has no idea: not watching,
## not wondering, and not looking at the tile he is on. Behind them, in short.
func unaware_beside(guard) -> bool:
	if not is_instance_valid(guard) or guard.knocked_out or not guard.moves():
		return false
	if suspicion.get(guard, 0.0) > 0.0 or guard.mood == Guard.Mood.WATCHING or guard.mood == Guard.Mood.SUSPICIOUS:
		return false
	var party = scene.get("party")
	if party == null or party.leader == null:
		return false
	var at = tile_of(party.leader.global_position)
	if Vector2(at - tile_of(guard.global_position)).length() > REACH_TILES:
		return false
	_refresh_seen(guard)
	return not _seen.get(guard, {}).has(at)


## Whether `guard` is within reach of the leader.
func _in_reach(guard) -> bool:
	var party = scene.get("party")
	if party == null or party.leader == null or not is_instance_valid(guard):
		return false
	return Vector2(tile_of(party.leader.global_position) - tile_of(guard.global_position)).length() <= REACH_TILES


## A left click on the map knocks a guard out, picks up a body beside him, or
## puts down the one he is dragging - into a hiding spot, if there is a free one
## within reach. A right click picks pockets, a body's included. The guard
## clicked on, if that is one it can be done to, or else whoever it can - so
## the click need not land on him exactly.
func _click_on_guard(event):
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index != MOUSE_BUTTON_LEFT and event.button_index != MOUSE_BUTTON_RIGHT:
		return
	if spotted_by != null or _lacing != null or (scene.has_method("is_holding") and scene.is_holding()):
		return
	var tile = tile_of(_world_at(event.position))
	var clicked = _guard_on(tile)
	var done := false
	if event.button_index == MOUSE_BUTTON_RIGHT:
		done = pick_pocket(clicked)
	elif _dragging != null:
		done = put_down(tile)
	elif _can_drag(clicked):
		done = drag(clicked)
	else:
		done = take_down(clicked) or drag()
	if done:
		get_viewport().set_input_as_handled()


## Whoever is on `tile` and on show - or stuffed into a hiding spot there -
## or null.
func _guard_on(tile: Vector2i) -> Guard:
	for guard in guards:
		if is_instance_valid(guard) and (guard.visible or _stashed.has(guard)) and tile_of(guard.global_position) == tile:
			return guard
	return null


func _can_take_down(guard) -> bool:
	return is_instance_valid(guard) and guard.can_be_taken_down and unaware_beside(guard)


## Somebody knocked out has no idea of anything, so a body's pockets can be
## picked as well as an unaware guard's - one stuffed into a hiding spot too,
## from beside the spot.
func _can_rob(guard) -> bool:
	if not is_instance_valid(guard) or guard.picked or (guard.pockets.is_empty() and guard.picked_flag == ""):
		return false
	if guard.knocked_out:
		return _in_reach(guard)
	return unaware_beside(guard)


func _can_drag(guard) -> bool:
	return is_instance_valid(guard) and guard.knocked_out and not _stashed.has(guard) and guard != _dragging and _in_reach(guard)


## Who a left click would knock out right now - `preferred`, if he can be -
## or null.
func takedown_target(preferred = null) -> Guard:
	if _lacing != null:
		return null
	if _can_take_down(preferred):
		return preferred
	for guard in guards:
		if _can_take_down(guard):
			return guard
	return null


## Knocks out whoever is unaware beside the leader - `preferred`, if he is.
## They drop where they stand and stay there - until another guard's view
## falls on them.
func take_down(preferred = null) -> bool:
	var guard = takedown_target(preferred)
	if guard == null or spotted_by != null:
		return false
	guard.knock_out()
	suspicion[guard] = 0.0
	_bodies[guard] = false
	guard.visible = true
	stats.takedowns += 1
	if scene.has_method("log_message"):
		scene.log_message("[color=yellow]%s[/color] is out cold.\n" % _name_of(guard))
	# Not quietly: anybody near enough comes to see what that was.
	make_noise(guard.global_position, TAKEDOWN_NOISE_TILES, true)
	# And seen by somebody who is nobody's guard, they run to tell.
	var party = scene.get("party")
	if party != null and party.leader != null:
		_witnesses(party.leader.global_position)
	return true


## --- The prompt ---
##
## What a click would do right now, shown right over whoever it would be done
## to - and, standing behind somebody who cannot be taken down, that he cannot,
## rather than nothing at all.


## [what it hangs over - a node, or a place on the map - [[button, what it
## does, whether it can], ...]], or [] when there is nothing to do.
func prompt() -> Array:
	if scene == null or spotted_by != null or (scene.has_method("is_holding") and scene.is_holding()):
		return []
	if _dragging != null:
		var spot = stash_spot()
		return [spot if spot != null else _dragging,
			[["Left click", "Hide the body here" if spot != null else "Put the body down", true]]]
	var over = null
	var lines := []
	var down = takedown_target()
	var body = drag_target()
	var rob = pocket_target()
	if down != null:
		over = down
		lines.append(["Left click", "Take down", true])
	elif body != null:
		over = body
		lines.append(["Left click", "Drag the body", true])
	else:
		var tough = _tough_one_behind()
		if tough != null:
			over = tough
			lines.append(["Left click", "Can't be taken down", false])
	if rob != null:
		if over == null:
			over = rob
		lines.append(["Right click", "Pick pocket" if rob == over else "Pick %s's pocket" % _name_of(rob), true])
	# Near enough to spring on somebody who has no idea he is there.
	var spring = ambush_target(over)
	if spring != null and ambush_refusal() == "":
		if over == null:
			over = spring
		lines.append(["F", "Ambush" if spring == over else "Ambush %s" % _name_of(spring), true])
	# In a disguise he takes at face value, beside a guard who could settle the
	# map - or who would, if a body had not been found. E, when E is not for
	# something else in reach.
	var calm = reassure_target()
	var no_word = reassure_refusal(calm)
	if calm != null and no_word != "Nothing to settle" and no_word != "Already talking" and scene.get("_current_target") == null:
		if over == null:
			over = calm
		lines.append(["E", "Have a word" if no_word == "" else no_word, no_word == ""])
	if over == null:
		# Nobody to deal with, but something to hop over.
		var hop = vault_over()
		if not hop.is_empty():
			return [_tile_map.to_global(_tile_map.map_to_local(hop[0])), [["V", "Vault over", true]]]
	return [] if over == null else [over, lines]


## A guard he is right behind and unseen by who can never be taken down - a
## ward, or one set that way - so the prompt can say so.
func _tough_one_behind() -> Guard:
	var party = scene.get("party")
	if party == null or party.leader == null:
		return null
	var at = tile_of(party.leader.global_position)
	for guard in guards:
		if not is_instance_valid(guard) or guard.knocked_out:
			continue
		if guard.can_be_taken_down and guard.moves():
			continue
		if _in_reach(guard) and not sees(guard, at):
			return guard
	return null


## --- Bodies: dragged, and hidden ---


## The body a left click would pick up right now - `preferred`, if it can be -
## or null.
func drag_target(preferred = null) -> Guard:
	if _dragging != null or _changing_into != "" or _lacing != null:
		return null
	if _can_drag(preferred):
		return preferred
	for guard in guards:
		if _can_drag(guard):
			return guard
	return null


## Picks up the body beside the leader - `preferred`, if it is one - to drag
## along behind the party at DRAG_PACE.
func drag(preferred = null) -> bool:
	var body = drag_target(preferred)
	var party = scene.get("party")
	if body == null or spotted_by != null or party == null or party.leader == null:
		return false
	_dragging = body
	_drag_path = [body.global_position, party.leader.global_position]
	_set_pace()
	return true


## The body being dragged, or null.
func dragging() -> Guard:
	return _dragging


## Where a body would go if put down now: a free hiding spot within reach -
## the one on `tile`, if that is one - or null to leave it where it lies.
func stash_spot(tile: Vector2i = Vector2i(-99999, -99999)) -> HidingSpot:
	var party = scene.get("party")
	if party == null or party.leader == null:
		return null
	var at = tile_of(party.leader.global_position)
	var best: HidingSpot = null
	var best_gap := INF
	for spot in _hiding_spots:
		if not is_instance_valid(spot) or not spot.is_free():
			continue
		var spot_tile = tile_of(spot.global_position)
		var gap = Vector2(spot_tile - at).length()
		if gap > REACH_TILES:
			continue
		if spot_tile == tile:
			return spot
		if gap < best_gap:
			best = spot
			best_gap = gap
	return best


## Puts down the body being dragged: into a free hiding spot within reach -
## the one on `tile`, given one - out of sight of any guard not close by it,
## or else on the ground where it is.
func put_down(tile: Vector2i = Vector2i(-99999, -99999)) -> bool:
	if _dragging == null:
		return false
	var body = _dragging
	var spot = stash_spot(tile)
	_let_go()
	if spot == null:
		return true
	body.global_position = spot.global_position
	body.visible = false
	spot.holds_body = body
	_stashed[body] = spot
	_bodies.erase(body)
	# A body stuffed in never quite fits: a guard close by notices.
	_add_oddity(spot, "spot", DISTURBED_TILES)
	if scene.has_method("log_message"):
		scene.log_message("[color=yellow]%s[/color] is stuffed out of sight.\n" % _name_of(body))
	return true


## Whether `guard` is knocked out and stuffed into a hiding spot.
func is_stashed(guard) -> bool:
	return _stashed.has(guard)


func _let_go():
	_dragging = null
	_drag_path = []
	var party = scene.get("party") if scene != null else null
	if party != null and is_instance_valid(party):
		_set_pace()


## Keeps the body being dragged a place behind the last of the party, along the
## way the leader has walked since picking it up - so it follows round corners
## rather than through them, and only moves once he has walked off from it.
func _drag_along():
	var party = scene.get("party")
	if _dragging == null or party == null or party.leader == null:
		return
	if not is_instance_valid(_dragging):
		_let_go()
		return
	var leader_at: Vector2 = party.leader.global_position
	if _drag_path.back().distance_to(leader_at) > 0.5:
		_drag_path.append(leader_at)
	var remaining: float = party.follow_spacing * (party.followers.size() + 1)
	var at: Vector2 = _drag_path[0]
	var i := _drag_path.size() - 1
	while i > 0:
		var span = _drag_path[i].distance_to(_drag_path[i - 1])
		if span >= remaining:
			at = _drag_path[i].lerp(_drag_path[i - 1], remaining / maxf(span, 0.001))
			break
		remaining -= span
		i -= 1
	_dragging.global_position = at
	# Nothing further back than where the body is will be needed again.
	if i > 1:
		_drag_path = _drag_path.slice(i - 1)


## Whose pockets a right click would pick right now - `preferred`'s, if his
## can be - or null.
func pocket_target(preferred = null) -> Guard:
	if _lacing != null:
		return null
	if _can_rob(preferred):
		return preferred
	for guard in guards:
		if _can_rob(guard):
			return guard
	return null


## Lifts everything in the pockets of whoever is unaware beside the leader -
## `preferred`, if he is.
func pick_pocket(preferred = null) -> bool:
	var guard = pocket_target(preferred)
	if guard == null or spotted_by != null:
		return false
	var names := []
	for item_key in guard.pockets:
		if Campaign.give_item(leader_key(), item_key):
			var item = ItemDatabase.item(item_key)
			names.append(item.name if item != null else item_key)
	if guard.picked_message != "":
		names.append(guard.picked_message)
	guard.picked = true
	stats.pockets += 1
	if guard.picked_flag != "":
		Campaign.set_flag(guard.picked_flag)
	if scene.has_method("log_message"):
		scene.log_message("Lifted from [color=yellow]%s[/color]: %s.\n" % [_name_of(guard), ", ".join(names)])
	return true


## Whether `guard` is lying knocked out where somebody could find them, and
## has not been found yet.
func body_unfound(guard: Guard) -> bool:
	return _bodies.has(guard) and not _bodies[guard]


## A guard whose view falls on somebody knocked out puts the map a level more
## on edge for good, and goes to bring them round - see _found.
func _look_for_bodies(finder: Guard):
	if finder.kind == Guard.Kind.WARD or finder.sees_nothing():
		return
	for body in _bodies.keys():
		if _bodies[body] or not is_instance_valid(body):
			continue
		if _seen.get(finder, {}).has(tile_of(body.global_position)):
			_found(body, finder)
	# Hunting for somebody, he looks into the hiding spots about where he saw
	# them - and a body stuffed into one is as good as found.
	if not finder.is_hunting():
		return
	for body in _stashed.keys():
		if _stashed_found.has(body) or not is_instance_valid(body):
			continue
		var tile = tile_of(_stashed[body].global_position)
		if _seen.get(finder, {}).has(tile) and looks_behind_cover(finder, tile):
			_found(body, finder)


## `finder` has found `body`. A body is the one thing a watch cannot talk
## itself out of: the map goes a level more on edge and stays at least there
## (see raise_alert_level). Then somebody goes to bring him round - the finder,
## or the nearest guard who can when the finder is a dog or nobody's guard -
## and until then, and only then, a knocked-out guard stays down.
func _found(body: Guard, finder: Guard):
	var hidden_away = _stashed.has(body)
	if hidden_away:
		_stashed_found[body] = true
	else:
		_bodies[body] = true
	if not _alarmed_by.has(body):
		stats.bodies_found += 1
		_alarmed_by[body] = true
		raise_alert_level(true)
	if scene.has_method("log_message"):
		scene.log_message("[color=red]%s %s %s%s - the alert goes up, and will not come down below %s![/color]\n" % [
			_name_of(finder), "screams: they have found" if finder.kind == Guard.Kind.CIVILIAN else "has found",
			_name_of(body), ", hidden away" if hidden_away else "", ALERT_NAMES[level_of(alert_floor)]])
	_send_to_wake(body, finder)


## Whether `guard` could bring somebody round: a watchman or captain, on their
## feet and with their wits about them.
func _can_wake(guard) -> bool:
	return is_instance_valid(guard) and (guard.kind == Guard.Kind.WATCHMAN or guard.kind == Guard.Kind.CAPTAIN) \
		and not guard.knocked_out and not guard.mood in Guard.ABSORBED


## The nearest guard who could bring somebody round, leaving out `but`.
func _nearest_waker(to: Vector2, but: Array = []) -> Guard:
	var best: Guard = null
	var best_gap := INF
	for guard in guards:
		if but.has(guard) or not _can_wake(guard):
			continue
		var gap = guard.global_position.distance_to(to)
		if gap < best_gap:
			best = guard
			best_gap = gap
	return best


func _send_to_wake(body: Guard, finder: Guard):
	if _waking.has(body):
		return
	var waker = finder if _can_wake(finder) else _nearest_waker(body.global_position, [body])
	if waker == null:
		return
	_waking[body] = waker
	var at: Vector2 = body.global_position
	waker.send_on_errand(Guard.Mood.WAKING, at, WAKE_SECONDS, Callable(), _woken.bind(body, waker),
		Guard.INVESTIGATE_PACE, at)


## `waker` has spent long enough over `body` to bring him round - if he is
## still there to be brought round.
func _woken(body: Guard, waker: Guard):
	_waking.erase(body)
	if not is_instance_valid(body) or not body.knocked_out:
		return
	if body == _dragging or body.global_position.distance_to(waker.global_position) > Grid.tiles(REACH_TILES):
		# Dragged off while he was on his way: lying somewhere else now, to be
		# found there all over again.
		_bodies[body] = false
		return
	if _stashed.has(body):
		_stashed[body].holds_body = null
		_remove_oddity(_stashed[body])
		_stashed.erase(body)
		_stashed_found.erase(body)
	_bodies.erase(body)
	body.visible = true
	body.wake_up()
	suspicion[body] = 0.0
	if scene.has_method("log_message"):
		scene.log_message("[color=yellow]%s[/color] brings [color=yellow]%s[/color] round.\n" % [_name_of(waker), _name_of(body)])


## Anybody on the way to wake a body who has been drawn off it - knocked out
## themselves, or off after somebody they saw: the body is lying there to be
## found again, without putting the map up a second time.
func _check_on_wakers():
	for body in _waking.keys():
		var waker = _waking[body]
		if is_instance_valid(waker) and waker.mood == Guard.Mood.WAKING and not waker.knocked_out:
			continue
		_waking.erase(body)
		if not is_instance_valid(body) or not body.knocked_out:
			continue
		if _stashed.has(body):
			_stashed_found.erase(body)
		else:
			_bodies[body] = false


## --- A word in the right ear (E, beside a guard) ---
##
## In a disguise a guard takes at face value, a word with him - been round, it
## is nothing - and he passes it on: the map settles a level. E beside him, when
## there is nothing else there to use; once a guard, never below where a found
## body pinned it, and standing still for it where anybody the disguise does
## not fool might be looking. A guard with Small Talk set plays that
## conversation instead, and it is the conversation that settles the map, if
## anything does - `do Campaign.settle_alert()`, as any conversation can.

## What gets said, a line each: his, then the guard's. Picked by the guard, so
## the same guard always says the same thing.
const WORD_SAID := ["All quiet out back.", "Been round the stores - nothing there.", "Rats, that's all it was.",
	"Nothing to worry about out there."]
const WORD_ANSWERED := ["Good. I'll pass it on.", "Thank the gods for that.", "Right. Back to it, then.",
	"Glad to hear it."]

## What the leader is saying this moment, over his head, or "".
var leader_says := ""


## Whether a word with `guard` could be had: beside him, in a disguise he takes
## at face value, and him calm and about his business.
func _can_reassure(guard) -> bool:
	if not is_instance_valid(guard) or guard.reassured or not _in_reach(guard):
		return false
	if guard.kind != Guard.Kind.WATCHMAN and guard.kind != Guard.Kind.CAPTAIN:
		return false
	if guard.sees_nothing() or suspicion.get(guard, 0.0) > 0.0 or not guard.is_free():
		return false
	var worn = worn_by(leader_key())
	return worn != "" and not guard.sees_through(ItemDatabase.item(worn))


## Who a word would be had with right now - `preferred`, if it can be - or null.
func reassure_target(preferred = null) -> Guard:
	if _can_reassure(preferred):
		return preferred
	for guard in guards:
		if _can_reassure(guard):
			return guard
	return null


## Why a word would come to nothing right now, or "". A guard with something
## of his own to say is always worth a word.
func reassure_refusal(guard = null) -> String:
	if spotted_by != null:
		return "Too late for that"
	if _reassuring != null:
		return "Already talking"
	if _dragging != null or _changing_into != "" or _lacing != null:
		return "Not now"
	if guard == null:
		guard = reassure_target()
	if is_instance_valid(guard) and guard.small_talk != null:
		return ""
	if level_of(alert) == 0:
		return "Nothing to settle"
	if level_of(alert) <= level_of(alert_floor):
		return "They won't settle - a body was found"
	return ""


## E beside a guard the disguise fools, with nothing else there to use: a word
## with him. True when it was had.
func talk_on_interact() -> bool:
	if scene.get("_current_target") != null:
		return false
	return reassure()


## Has a word with whoever is beside the leader and fooled by his disguise -
## `preferred`, if that is one: REASSURE_SECONDS standing still, a line each,
## and then the map is a level calmer - or his own conversation, if he has
## one. False, and nothing started, when there is nobody to have one with or
## it would come to nothing.
func reassure(preferred = null) -> bool:
	var guard = reassure_target(preferred)
	var party = scene.get("party")
	if guard == null or reassure_refusal(guard) != "" or party == null or party.leader == null:
		return false
	if scene.has_method("is_holding") and scene.is_holding():
		return false
	guard.reassured = true
	if guard.small_talk != null:
		_small_talk(guard)
		return true
	_reassuring = guard
	party.rooted = true
	guard.send_on_errand(Guard.Mood.CHATTING, guard.global_position, REASSURE_SECONDS, Callable(),
		_reassured.bind(guard), 1.0, party.leader.global_position)
	return true


## His own conversation, everything waiting on it.
func _small_talk(guard: Guard):
	var manager = get_node_or_null("/root/DialogueManager")
	if manager == null:
		return
	guard.facing = (scene.party.leader.global_position - guard.global_position).normalized()
	if scene.has_method("begin_blocking_interaction"):
		scene.begin_blocking_interaction()
	manager.dialogue_ended.connect(_after_small_talk, CONNECT_ONE_SHOT)
	manager.show_dialogue_balloon_scene("res://ui/dialogue_balloon.tscn", guard.small_talk,
		guard.small_talk_title if guard.small_talk_title != "" else "start")


func _after_small_talk(_resource):
	if scene != null and is_instance_valid(scene) and scene.has_method("end_blocking_interaction"):
		scene.end_blocking_interaction()


func _reassured(guard: Guard):
	_stop_reassuring()
	settle(1, "[color=yellow]%s[/color] passes it on" % _name_of(guard))


## Settles the map `levels` levels, as far as the floor allows, and says so -
## `who` passing it on, given. What a word with a guard does, and what a
## conversation or anything used can do too (see Campaign.settle_alert and
## Interactable's Settles Alert). True when it went down at all.
func settle(levels: int = 1, who: String = "") -> bool:
	var lowered := false
	for i in levels:
		if lower_alert_level():
			lowered = true
	if scene != null and scene.has_method("log_message"):
		if lowered:
			scene.log_message("%s - the guards settle. [color=lightgreen]%s[/color].\n" % [
				who if who != "" else "Word goes round", alert_level()])
		elif level_of(alert) > 0:
			scene.log_message("The guards will not settle below %s - a body was found.\n" % ALERT_NAMES[level_of(alert_floor)])
	return lowered


## The line each while a word is being had: his first, then the guard's.
func _say_the_word():
	if _reassuring == null or not is_instance_valid(_reassuring):
		return
	var pick = absi(hash(String(_reassuring.name))) % WORD_SAID.size()
	var said = REASSURE_SECONDS - _reassuring.errand_left() if _reassuring.errand_arrived() else 0.0
	if said < REASSURE_SECONDS / 2.0:
		leader_says = WORD_SAID[pick]
		saying.erase(_reassuring)
	else:
		leader_says = ""
		saying[_reassuring] = [WORD_ANSWERED[pick], true]


## Lets go of whoever he was talking to, finished or not.
func _stop_reassuring():
	if _reassuring != null and is_instance_valid(_reassuring):
		saying.erase(_reassuring)
	leader_says = ""
	_reassuring = null
	var party = scene.get("party") if scene != null else null
	if party != null and is_instance_valid(party) and _changing_into == "":
		party.rooted = false


## A word cut short - he was knocked out, or saw something - settles nothing.
func _check_on_reassuring():
	if _reassuring == null:
		return
	if not is_instance_valid(_reassuring) or _reassuring.mood != Guard.Mood.CHATTING or _reassuring.knocked_out:
		_stop_reassuring()
		return
	_say_the_word()


## --- Questioning ---


## `guard` stops the party for questions. Everything waits on the answers.
func _question(guard: Guard):
	guard.questioned = true
	var manager = get_node_or_null("/root/DialogueManager")
	if manager == null:
		return
	if scene.has_method("begin_blocking_interaction"):
		scene.begin_blocking_interaction()
	if scene.has_method("log_message"):
		scene.log_message("[color=yellow]%s[/color] stops you.\n" % _name_of(guard))
	manager.dialogue_ended.connect(_after_questions.bind(guard), CONNECT_ONE_SHOT)
	manager.show_dialogue_balloon_scene("res://ui/dialogue_balloon.tscn", guard.questions,
		guard.questions_title if guard.questions_title != "" else "start")


## How the questions went: the passed flag set, the guard is fooled for good and
## goes back to his business; not set, he is sure.
func _after_questions(_resource, guard: Guard):
	answered(guard)


## Settles a questioning by the passed flag - what happens when its
## conversation ends. Public so it can be settled without one, for testing.
func answered(guard: Guard):
	if scene != null and scene.has_method("end_blocking_interaction"):
		scene.end_blocking_interaction()
	if not is_instance_valid(guard):
		return
	if guard.passed_flag != "" and Campaign.flag(guard.passed_flag):
		guard.fooled = true
		suspicion[guard] = 0.0
		guard.mood = Guard.Mood.PATROLLING
		if scene.has_method("log_message"):
			scene.log_message("[color=yellow]%s[/color] waves you on.\n" % _name_of(guard))
	else:
		_caught_by(guard)


## --- A clean run ---


## Whether no guard has so much as begun to notice anybody on this map.
func never_noticed() -> bool:
	return not _noticed_ever


func _name_of(guard: Guard) -> String:
	if guard.display_name != "":
		return guard.display_name
	var definition = CombatantDatabase.combatants.get(guard.combatant_key)
	return definition.name if definition != null else String(guard.name)


## What marks this map's guards as dealt with once the fight is won.
func trigger() -> String:
	if setup != null and setup.trigger_id != "":
		return setup.trigger_id
	return "stealth:%s" % scene.map_path()


func tile_of(world_position: Vector2) -> Vector2i:
	return _tile_map.local_to_map(_tile_map.to_local(world_position))


## Every tile the guards can see between them right now.
func seen_tiles() -> Dictionary:
	var all := {}
	for guard in guards:
		# Only those on show and awake: a map that hides guards out of sight
		# hides what they are looking at too.
		if is_instance_valid(guard) and not guard.knocked_out and guard.visible:
			all.merge(_seen.get(guard, {}))
	return all


## --- Whose gaze matters, in a disguise ---
##
## Out of disguise every guard's view is danger. In one, some take it at face
## value and some see straight through it, and the tint says which: purple for
## a guard who sees through it, amber for one who sees through it but would
## stop him with questions first, a faint grey for one it fools. Hovering a
## disguise on the bar shows the same for that one, before he puts it on.

enum Gaze { SEES, ASKS, FOOLED }
const GAZE_FILL := [SEEN_FILL, Color(0.95, 0.66, 0.2, 0.2), Color(0.75, 0.78, 0.82, 0.1)]
const GAZE_EDGE := [SEEN_EDGE, Color(1.0, 0.75, 0.3, 0.75), Color(0.8, 0.83, 0.88, 0.55)]

## The disguise being looked at on the bar, by item key, or "" - drawn as if
## the leader had it on.
var preview_disguise := ""


## What `guard`'s gaze means to the party as they are dressed - or with the
## leader in `leader_in` instead, given one: SEES somebody for who they are
## (anybody out of disguise, or in one this guard sees through), ASKS if he sees
## through it but has questions to ask first, FOOLED if he takes everybody at
## face value.
func gaze_of(guard: Guard, leader_in: String = "") -> int:
	var standing := _party_standing()
	if standing.is_empty():
		return Gaze.SEES
	var asks := false
	for someone in standing:
		var worn: String = leader_in if leader_in != "" and someone.key == leader_key() else worn_by(someone.key)
		if worn == "":
			return Gaze.SEES
		if guard.sees_through(ItemDatabase.item(worn)):
			if guard.questions != null and not guard.questioned:
				asks = true
			else:
				return Gaze.SEES
	return Gaze.ASKS if asks else Gaze.FOOLED


## Every tile watched right now, by what the gaze on it means - where two
## overlap, the worse of the two: [SEES tiles, ASKS tiles, FOOLED tiles].
func seen_by_gaze() -> Array:
	var sorted := [{}, {}, {}]
	for guard in guards:
		if not is_instance_valid(guard) or guard.knocked_out or not guard.visible:
			continue
		var gaze: int = gaze_of(guard, preview_disguise)
		for tile in _seen.get(guard, {}):
			var worst: int = gaze
			if sorted[Gaze.SEES].has(tile):
				continue
			if sorted[Gaze.ASKS].has(tile):
				worst = mini(worst, Gaze.ASKS)
				sorted[Gaze.ASKS].erase(tile)
			sorted[Gaze.FOOLED].erase(tile)
			sorted[worst][tile] = true
	return sorted


## Whether `guard` can see `tile` right now - the same answer the map draws.
func sees(guard: Guard, tile: Vector2i) -> bool:
	_refresh_seen(guard)
	return _seen.get(guard, {}).has(tile)


func _process(delta):
	if scene == null:
		return
	_dress_the_party()
	if spotted_by != null:
		# Still drawing: the "!" is popping.
		_meters.queue_redraw()
		return
	var holding: bool = scene.has_method("is_holding") and scene.is_holding()
	for guard in guards:
		if is_instance_valid(guard):
			guard.holding = holding
	# Waiting things out, while nothing else holds the game.
	_hurry(patient() and not holding)
	if holding:
		return
	stats.seconds += delta
	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	_ears_cooldown = maxf(0.0, _ears_cooldown - delta)
	_ears_left = maxf(0.0, _ears_left - delta)
	if _changing_into != "":
		_change_left -= delta
		if _change_left <= 0.0:
			_finish_change()
	if _lacing != null:
		_lace_left -= delta
		if _lace_left <= 0.0:
			_finish_lacing()
	_update_doors()
	_drag_along()
	_set_pace()
	_listen_to_feet(delta)
	_apply_alert()
	var party = scene.get("party")
	var dashing: bool = party != null and party.dashing
	var standing := _party_standing()
	var watched := false
	for guard in guards:
		if not is_instance_valid(guard) or guard.knocked_out:
			continue
		_refresh_seen(guard)
		if guard.mood == Guard.Mood.REPORTING:
			# Running to tell somebody: no mind for anything else.
			continue
		var from = tile_of(guard.global_position)
		# Whoever in view they are growing sure of fastest, and where they are.
		var rate := 0.0
		var seen_at := Vector2.ZERO
		var seen_disguised := false
		var caught_at_it := false
		for someone in standing:
			if not can_perceive(guard, someone):
				continue
			# Seen dragging a body, changing clothes or poisoning a supper, there
			# is no doubt at all who he is - whatever he has on.
			if someone.key == leader_key() and caught_red_handed():
				caught_at_it = true
				seen_at = someone.sprite.global_position
				break
			# In plain view, but in a disguise this guard takes at face value.
			var worn = worn_by(someone.key)
			if worn != "" and not guard.sees_through(ItemDatabase.item(worn)):
				continue
			var this_rate = fill_rate(Vector2(someone.tile - from).length(), dashing) * (1.0 + ALERT_FILL * alert)
			if worn != "":
				this_rate *= DISGUISE_EXPOSED
			if this_rate > rate:
				rate = this_rate
				seen_at = someone.sprite.global_position
				seen_disguised = worn != ""
		if caught_at_it:
			if guard.kind == Guard.Kind.CIVILIAN:
				_run_to_tell(guard, seen_at)
				continue
			suspicion[guard] = 1.0
			guard.watching(seen_at)
			_caught_by(guard)
			break
		if rate > 0.0:
			watched = true
			if suspicion[guard] <= 0.0:
				stats.noticed += 1
			_noticed_ever = true
			guard.watching(seen_at)
			suspicion[guard] = minf(1.0, suspicion[guard] + delta * rate)
			# Somebody in a disguise this guard doubts: stopped for questions,
			# if he has any, before he is sure.
			if seen_disguised and guard.questions != null and not guard.questioned \
					and suspicion[guard] >= QUESTION_AT:
				_question(guard)
				return
			if suspicion[guard] >= 1.0:
				if guard.kind == Guard.Kind.CIVILIAN:
					_run_to_tell(guard, seen_at)
					continue
				_caught_by(guard)
				break
		else:
			var was: float = suspicion[guard]
			suspicion[guard] = maxf(0.0, was - DOUBT_FADES * delta)
			if suspicion[guard] > 0.0:
				guard.lost_sight()
			elif was > 0.0:
				# Drained without being sure: they go and look - and the map
				# is the more on edge for it.
				guard.doubt_gone()
				if guard.mood == Guard.Mood.INVESTIGATING:
					raise_alert(ALERT_PER_INVESTIGATION)
		_look_for_bodies(guard)
		_notice_oddities(guard)
	_check_on_wakers()
	_check_on_reassuring()
	_see_to_oddities()
	_run_chats(delta)
	_check_on_reporters()
	_run_meals(delta)
	_brew(delta)
	_check_on_carers()
	_update_what_is_shown()
	if spotted_by == null:
		# The moment somebody first comes into view, rather than every frame
		# they stay there.
		if watched and not _was_watched:
			_startle()
		_was_watched = watched
		_feel_watched(delta, watched)
	queue_redraw()
	_meters.queue_redraw()


## The fullest any guard's meter is right now.
func most_sure() -> float:
	var most := 0.0
	for guard in guards:
		if is_instance_valid(guard):
			most = maxf(most, suspicion.get(guard, 0.0))
	return most


## --- Sound ---


func _player(called: String, stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = called
	player.stream = stream
	if AudioServer.get_bus_index("SFX") >= 0:
		player.bus = "SFX"
	add_child(player)
	return player


## A heartbeat for as long as anybody is growing sure: slow and quiet at the
## first doubt, quick and loud nearly there.
func _beat(delta: float, sure: float):
	if sure < 0.05:
		_beat_in = 0.0
		return
	_beat_in -= delta
	if _beat_in > 0.0:
		return
	_beat_in = lerpf(HEART_SLOW, HEART_FAST, sure)
	_heart.volume_db = lerpf(HEART_QUIET_DB, HEART_LOUD_DB, sure)
	_heart.play()


## A low-pass on the Music bus, opened right up until somebody is growing sure.
## Taken off again when this map goes - see _exit_tree - or the title screen
## would play muffled too.
func _add_muffle():
	_music_bus = AudioServer.get_bus_index("Music")
	if _music_bus < 0:
		return
	_muffle = AudioEffectLowPassFilter.new()
	_muffle.cutoff_hz = MUSIC_CLEAR_HZ
	AudioServer.add_bus_effect(_music_bus, _muffle)


func _remove_muffle():
	if _muffle == null or _music_bus < 0:
		return
	for i in AudioServer.get_bus_effect_count(_music_bus):
		if AudioServer.get_bus_effect(_music_bus, i) == _muffle:
			AudioServer.remove_bus_effect(_music_bus, i)
			break
	_muffle = null


## Muffles the music by `sure` - by a ratio rather than a straight line, which
## is how an ear hears a cutoff falling.
func _set_muffle(sure: float):
	if _muffle != null:
		_muffle.cutoff_hz = MUSIC_CLEAR_HZ * pow(MUSIC_MUFFLED_HZ / MUSIC_CLEAR_HZ, clampf(sure, 0.0, 1.0))


## How far the music is muffled right now, as the low-pass's cutoff.
func music_cutoff() -> float:
	return _muffle.cutoff_hz if _muffle != null else MUSIC_CLEAR_HZ


## Anything this turned on for the whole game comes off with the map - slowed
## time most of all, which would otherwise carry into the fight and beyond.
func _exit_tree():
	if Campaign.stealth_watch == self:
		Campaign.stealth_watch = null
	if _slowed or _hurried:
		Engine.time_scale = 1.0
		_slowed = false
		_hurried = false
	_remove_muffle()
	# The party outlives a watch that is started again on the same map.
	_stop_changing()
	_let_go()
	_stop_reassuring()
	_stop_lacing()
	var party = scene.get("party") if scene != null else null
	if party != null and is_instance_valid(party):
		party.pace = 1.0


## Stand-ins until there are real sounds: a heartbeat's two low thumps, and a
## bright rising sting. Built from sine waves, so nothing has to be shipped.
static func heartbeat_placeholder() -> AudioStreamWAV:
	return _synth(0.45, func(t: float) -> float:
		return _thump(t, 0.0, 0.9) + _thump(t, 0.19, 0.6))


static func sting_placeholder() -> AudioStreamWAV:
	return _synth(0.55, func(t: float) -> float:
		var envelope = minf(t * 200.0, 1.0) * exp(-t * 6.5)
		var glide = 1.0 + t * 0.5
		return envelope * 0.3 * (sin(TAU * 660.0 * glide * t) + sin(TAU * 990.0 * glide * t)
			+ 0.6 * sin(TAU * 1320.0 * glide * t)))


static func _thump(t: float, start: float, loud: float) -> float:
	var since = t - start
	if since < 0.0:
		return 0.0
	return loud * sin(TAU * 55.0 * since) * exp(-since * 26.0)


static func _synth(seconds: float, wave: Callable) -> AudioStreamWAV:
	var rate := 22050
	var count := int(seconds * rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		data.encode_s16(i * 2, int(clampf(wave.call(float(i) / rate), -1.0, 1.0) * 32767.0))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = rate
	sound.stereo = false
	sound.data = data
	return sound


## --- Cyrus noticing he has been noticed ---


## A "!" over him for a moment, and a flinch - the instant somebody's view
## first falls on him, not every frame it stays there.
func _startle():
	_startled_at = Time.get_ticks_msec() / 1000.0
	var party = scene.get("party")
	var leader: Node2D = party.leader if party != null else null
	if leader == null:
		return
	var flinch = leader.create_tween()
	flinch.tween_property(leader, "scale", Vector2(1.12, 0.86), 0.07)
	flinch.tween_property(leader, "scale", Vector2.ONE, 0.13)


## Whether Cyrus's "!" is up right now.
func startled() -> bool:
	return Time.get_ticks_msec() / 1000.0 - _startled_at < STARTLE_SECONDS


## How fast the "?" over a guard `sure` of somebody pulses, in radians a second.
static func pulse_rate(sure: float) -> float:
	return lerpf(PULSE_SLOW, PULSE_FAST, clampf(sure, 0.0, 1.0))


## The screen answering how close this is: the amber round the edges follows
## the fullest meter, filling and draining with it, and the camera leans in
## while somebody is actually looking - and eases back out the moment nobody
## is, before the meter has had time to drain.
func _feel_watched(delta: float, watched: bool):
	var sure = most_sure()
	if _vignette != null:
		_vignette.show_pressure(sure * VIGNETTE_AT_FULL, METER_DOUBT)
	var target = PRESSURE_ZOOM * sure if watched else 0.0
	_pressure_zoom = lerpf(_pressure_zoom, target, 1.0 - exp(-PRESSURE_EASE * delta))
	_lean_camera()
	_beat(delta, sure)
	_set_muffle(sure)


## Puts the pressure's share on the camera's zoom, on top of whatever the
## wheel has it at: the share already on it comes off first, so turning the
## wheel mid-lean is kept rather than undone.
func _lean_camera():
	var camera = scene.get("camera")
	if camera == null or not (camera is Camera2D):
		return
	var chosen = camera.zoom.x / (1.0 + _applied_zoom)
	camera.zoom = Vector2.ONE * chosen * (1.0 + _pressure_zoom)
	_applied_zoom = _pressure_zoom


## How far the camera is leaning in right now, as a share of the chosen zoom.
func camera_lean() -> float:
	return _applied_zoom


## Who is on the map and where, leader first: [{key, sprite, tile}].
func _party_standing() -> Array:
	var standing := []
	var party = scene.get("party")
	if party == null:
		return standing
	for member in Campaign.party_members():
		var sprite = party.sprite_for(member.key)
		if sprite != null:
			var tile = tile_of(sprite.global_position)
			standing.append({"key": member.key, "sprite": sprite, "tile": tile, "hiding": is_hiding_spot(tile)})
	return standing


## Whether whoever leads is tucked into a hiding spot.
func leader_hiding() -> bool:
	var party = scene.get("party") if scene != null else null
	if party == null or party.leader == null:
		return false
	return is_hiding_spot(tile_of(party.leader.global_position))


## Whether there is a hiding spot on `tile` with room in it - not one a body
## has been stuffed into.
func is_hiding_spot(tile: Vector2i) -> bool:
	for spot in _hiding_spots:
		if is_instance_valid(spot) and spot.is_free() and tile_of(spot.global_position) == tile:
			return true
	return false


## Whether `guard` can make out `someone` ({key, tile, hiding}) where they are:
## in their view - a dog's nose, for a dog - and not tucked into a hiding spot,
## unless the guard is right beside it, it is a dog, whose nose finds them
## anyway, or the guard is hunting for somebody he saw near there.
func can_perceive(guard: Guard, someone: Dictionary) -> bool:
	if not _seen.get(guard, {}).has(someone.tile):
		return false
	if someone.get("hiding", false) and guard.kind != Guard.Kind.DOG:
		var gap = Vector2(someone.tile - tile_of(guard.global_position)).length()
		if gap > REACH_TILES and not looks_behind_cover(guard, someone.tile):
			return false
	return true


## Whether `guard` sees into a hiding spot on `tile`: he is going to look for
## somebody he saw, and it is within SEARCH_SPOTS_TILES of where he saw them.
## Somebody who ducked out of sight is somebody hiding nearby.
func looks_behind_cover(guard: Guard, tile: Vector2i) -> bool:
	if not guard.is_hunting():
		return false
	return Vector2(tile - tile_of(guard.last_seen)).length() <= SEARCH_SPOTS_TILES


## Anyone sneaking is drawn half-there, the way combat draws a hidden ally, so
## it reads at a glance that this is a map to be quiet on - and anyone in a
## disguise is drawn solid, as whoever it copies, walking about openly. Every
## frame, because the party's sprites are rebuilt whenever the roster changes.
func _dress_the_party():
	for someone in _party_standing():
		var sprite = someone.sprite
		var worn = worn_by(someone.key)
		var looks_like: SpriteFrames = null
		if worn != "":
			var copied = CombatantDatabase.combatants.get(ItemDatabase.item(worn).disguise_as)
			looks_like = copied.sprite_frames if copied != null else null
		if sprite.has_method("show_as"):
			sprite.show_as(looks_like)
		var alpha = 1.0 if worn != "" else SNEAKING_ALPHA
		if someone.hiding:
			alpha = HIDDEN_ALPHA
		if sprite.has_method("set_hidden_alpha") and sprite.hidden_alpha != alpha:
			sprite.set_hidden_alpha(alpha)


func _refresh_seen(guard: Guard):
	if guard.sees_nothing():
		# Asleep, out cold or being sick: nothing at all.
		if _seen_key.get(guard) != ["nothing"]:
			_seen_key[guard] = ["nothing"]
			_seen[guard] = {}
		return
	var from = tile_of(guard.global_position)
	if guard.kind == Guard.Kind.DOG:
		# A nose: every tile within smell, walls or no walls.
		if _seen_key.get(guard) == [from, _world_version]:
			return
		_seen_key[guard] = [from, _world_version]
		var smelt := {}
		var reach = ceili(guard.smell_tiles)
		for dx in range(-reach, reach + 1):
			for dy in range(-reach, reach + 1):
				var tile = from + Vector2i(dx, dy)
				if Vector2(dx, dy).length() <= guard.smell_tiles and not sight.stops_sight(tile):
					smelt[tile] = true
		_seen[guard] = smelt
		return
	var facing_step = roundi(rad_to_deg(guard.facing.angle()) / FACING_STEP_DEGREES)
	# The width too: a guard investigating sees 340 degrees rather than 160. And
	# the doors and lamps as they stand: a door shut or a lamp out changes it.
	var key = [from, facing_step, guard.half_cone(), _world_version]
	if _seen_key.get(guard) == key:
		return
	_seen_key[guard] = key
	var looking = Vector2.RIGHT.rotated(deg_to_rad(facing_step * FACING_STEP_DEGREES))
	_seen[guard] = sight.seen_from(from, looking, guard.half_cone())
	if is_dark():
		# In the dark he makes somebody out only close up; on a lit tile, as far
		# off as he sees anything.
		var near = setup.dark_sight_tiles
		var made_out := {}
		for tile in _seen[guard]:
			if _lit.has(tile) or Vector2(tile - from).length() <= near:
				made_out[tile] = true
		_seen[guard] = made_out


## Somebody is sure. Everyone stops, the "!" goes up, and the fight is handed to
## Campaign to be fought where everybody stands. `ambushed`: nobody was sure
## of anything - he sprang on `guard` (see ambush), and whoever had not noticed
## him loses their first turn.
func _caught_by(guard: Guard, ambushed: bool = false):
	spotted_by = guard
	if ambushed:
		stats.ambushes += 1
	else:
		stats.caught += 1
	# Caught is noticed, however it came about - talked into a corner included.
	_noticed_ever = true
	# Whatever he was in the middle of stops where it is.
	_stop_changing()
	_let_go()
	_stop_reassuring()
	_stop_lacing()
	for other in guards:
		if is_instance_valid(other):
			other.holding = true
	var party = scene.get("party")
	if party != null:
		party.frozen = true
	# Red round the edges for the moment before the fight. The camera stays
	# leaning in where it was.
	if _vignette != null:
		_vignette.show_pressure(VIGNETTE_CAUGHT, METER_SURE)
	# The moment lands: time crawls, the screen jolts, the "!" pops in big and
	# the one who saw flashes, a sting plays, and the music is at its most
	# muffled.
	_hurried = false
	Engine.time_scale = CAUGHT_TIME_SCALE
	_slowed = true
	get_tree().create_timer(CAUGHT_SLOW_SECONDS, true, false, true).timeout.connect(_end_slow)
	var camera = scene.get("camera")
	if camera != null and camera.has_method("shake"):
		camera.shake(CAUGHT_SHAKE)
	_pop = CAUGHT_POP_FROM
	var pop = create_tween()
	# Real time, like the slow motion's own timer: slowed, it would still be
	# popping when the fight began. Back-eased, so it overshoots once and
	# settles - a pop, rather than the wobble an elastic ease is over in a
	# few frames.
	pop.set_ignore_time_scale(true)
	pop.tween_property(self, "_pop", CAUGHT_SIZE, POP_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if guard.sprite != null and guard.sprite.has_method("flash_hit"):
		guard.sprite.flash_hit(true)
	if _sting != null:
		_sting.play()
	if _heart != null:
		_heart.stop()
	_set_muffle(1.0)
	queue_redraw()
	_meters.queue_redraw()
	if scene.has_method("log_message"):
		if ambushed:
			scene.log_message("You spring on [color=yellow]%s[/color]!\n" % _name_of(guard))
		else:
			scene.log_message("[color=yellow]%s[/color] has spotted you!\n" % _name_of(guard))
	# Sprung on, a captain has no time to shout for anybody.
	if guard.kind == Guard.Kind.CAPTAIN and not ambushed:
		_shout(guard)
	var fight = build_fight(ambushed)
	# Written down before the scene goes, for walking back in after the fight.
	Campaign.stealth_state[scene.map_path()] = snapshot(fight)
	Campaign.begin_battle_from_exploration(fight, scene.map_path(), scene.party_position(), trigger())
	if not leave_for_battle:
		return
	await get_tree().create_timer(CAUGHT_PAUSE, true, false, true).timeout
	if is_inside_tree():
		SceneTransition.change_scene(scene.battle_scene)


## --- An ambush (F) ---
##
## Starting the fight on purpose, on his terms: beside a guard who has no idea
## he is there, the fight begins where everybody stands - and every guard who
## had not noticed anything loses their first turn (SpawnDefinition.surprised).


## How near a guard who has not noticed him has to be to be sprung on.
const AMBUSH_TILES := 2.5


## Whether `guard` has no idea anybody is about: not growing sure, not
## staring after anybody, not out looking for somebody he saw.
func _unaware(guard: Guard) -> bool:
	if suspicion.get(guard, 0.0) > 0.0 or guard.is_hunting():
		return false
	return guard.mood != Guard.Mood.WATCHING and guard.mood != Guard.Mood.SUSPICIOUS


func _can_ambush(guard) -> bool:
	if not is_instance_valid(guard) or guard.knocked_out or not guard.fights():
		return false
	if not CombatantDatabase.combatants.has(guard.combatant_key) or not _unaware(guard):
		return false
	var party = scene.get("party")
	if party == null or party.leader == null:
		return false
	return Vector2(tile_of(party.leader.global_position) - tile_of(guard.global_position)).length() <= AMBUSH_TILES


## Who F would spring on right now - `preferred`, if he can be - or null.
func ambush_target(preferred = null) -> Guard:
	if _can_ambush(preferred):
		return preferred
	var best: Guard = null
	var best_gap := INF
	var party = scene.get("party")
	for guard in guards:
		if not _can_ambush(guard):
			continue
		var gap = guard.global_position.distance_to(party.leader.global_position)
		if gap < best_gap:
			best = guard
			best_gap = gap
	return best


## Why he could not spring an ambush right now, or "".
func ambush_refusal() -> String:
	if spotted_by != null:
		return "Too late for that"
	if _dragging != null:
		return "Not while dragging a body"
	if _changing_into != "":
		return "Not while changing"
	if _lacing != null:
		return "Not while poisoning"
	return ""


## Springs on whoever is unaware nearby - `preferred`, if he is: the fight
## starts here, and whoever had not noticed anything loses their first turn.
func ambush(preferred = null) -> bool:
	var guard = ambush_target(preferred)
	if guard == null or ambush_refusal() != "":
		return false
	if scene.has_method("is_holding") and scene.is_holding():
		return false
	_caught_by(guard, true)
	return true


## A captain, sure: the whole map on alarm, and every guard within earshot of
## the shout in the fight from its first round, however far off they were.
func _shout(captain: Guard):
	raise_alert(1.0)
	for other in guards:
		if is_instance_valid(other) and other != captain and not other.knocked_out \
				and other.global_position.distance_to(captain.global_position) <= Grid.tiles(captain.shout_tiles):
			_called[other] = true
	if scene.has_method("log_message"):
		scene.log_message("[color=red]%s shouts for the others![/color]\n" % _name_of(captain))


## Time back to normal after the slow moment of being caught.
func _end_slow():
	if _slowed:
		Engine.time_scale = 1.0
		_slowed = false


## How much bigger than it settles the "!" is drawn right now.
func pop_scale() -> float:
	return _pop


## The fight, as things stand: an encounter on the setup's battle terrain with
## the party and every guard on the tile they are standing on, and nobody
## rearranged before it starts - where they were caught is the point. Each
## guard fights with what is still in his pockets. `ambushed`: whoever had
## not noticed anything is caught off guard.
func build_fight(ambushed: bool = false) -> EncounterDefinition:
	var fight := EncounterDefinition.new()
	fight.display_name = setup.fight_name if setup != null else "Caught"
	fight.terrain_scene = setup.battle_terrain if setup != null else null
	fight.skip_deployment = true
	var taken := {}
	var spawns: Array[SpawnDefinition] = []
	var fighters: Array[String] = []
	# Everyone walking the map, where they stand, leader first - and the roster
	# fills player tiles in the order they are listed, so each lands on their own.
	var party = scene.get("party")
	for member in Campaign.party_members():
		var definition: CombatantDefinition = CombatantDatabase.combatants.get(member.key)
		if definition == null or not definition.can_fight:
			continue
		var sprite = party.sprite_for(member.key) if party != null else null
		if sprite == null:
			continue
		var tile = _free_tile_near(tile_of(sprite.global_position), taken)
		taken[tile] = true
		fighters.append(member.key)
		spawns.append(_spawn(member.key, 0, tile, Campaign.party_level))
	# Where those caught stand: whoever could hit one of them on his first turn
	# is in the fight from the start.
	var party_tiles: Array = spawns.map(func(spawn): return spawn.position)
	# Whoever comes running, if this map says anybody does.
	if setup != null and not setup.backup.is_empty():
		var arrive = spawns[0].position if not spawns.is_empty() else Vector2i.ZERO
		if setup.backup_arrives_at != "":
			var at = Actors.waypoint_position(setup.backup_arrives_at)
			if at != null:
				arrive = tile_of(at)
			else:
				push_warning("Stealth backup arrives at '%s', which this map has no waypoint called." % setup.backup_arrives_at)
		for key in setup.backup:
			if fighters.has(key) or not CombatantDatabase.combatants.has(key) or not Campaign.is_alive(key):
				continue
			var tile = _free_tile_near(arrive, taken)
			taken[tile] = true
			fighters.append(key)
			spawns.append(_spawn(key, 0, tile, Campaign.party_level))
	# The guards: whoever caught him and whoever is near enough start the fight;
	# the rest - if this map says they come at all - arrive a round later for
	# every so many tiles further off they were. Nobody knocked out fights, and
	# nor does a ward.
	var caught_at = spawns[0].position if not spawns.is_empty() else Vector2i.ZERO
	var near = setup.joins_within_tiles if setup != null else 0.0
	# The more on edge the map, the quicker the rest get there.
	var per_round = (setup.tiles_per_late_round if setup != null else 0.0) * (1.0 + alert)
	for guard in guards:
		if not is_instance_valid(guard) or not CombatantDatabase.combatants.has(guard.combatant_key):
			continue
		# Nobody knocked out fights, nor a ward, nor anybody who is nobody's
		# guard - and somebody busy being sick is in no state to.
		if guard.knocked_out or not guard.fights() or guard.mood == Guard.Mood.RETCHING:
			continue
		var arrives := 1
		var gap = Vector2(tile_of(guard.global_position) - caught_at).length()
		# Near enough to hit somebody on his first turn, he is there from the
		# start however far that is - nobody within a turn of the party waits.
		if near > 0.0 and gap > near and guard != spotted_by and not _called.has(guard) \
				and not threatens(guard, party_tiles):
			if per_round <= 0.0:
				continue
			arrives = 1 + ceili((gap - near) / per_round)
		var tile = _free_tile_near(tile_of(guard.global_position), taken)
		taken[tile] = true
		var spawn = _spawn(guard.combatant_key, 1, tile, guard.level)
		spawn.display_name = guard.display_name
		# Who this is on the map, so the map knows who it lost - see snapshot().
		spawn.set_meta("guard", _id_of(guard))
		spawn.arrives_on_round = arrives
		spawn.starting_items.assign(_pocket_for_fight(guard))
		spawn.surprised = ambushed and arrives == 1 and _unaware(guard)
		spawns.append(spawn)
	_send_for_reinforcements(spawns, taken, caught_at)
	fight.spawns = spawns
	fight.fighters = fighters
	return fight


## Whether `guard` could hit somebody standing on one of `targets` on his first
## turn of the fight: walk his Movement across the battle terrain - its walls in
## the way, nobody else - and have something that reaches from there, a skill
## he knows at his level or a bomb in his pockets, within its least and most
## range and, past arm's length, with a clear line: the walls a shot in the
## fight is stopped by.
func threatens(guard: Guard, targets: Array) -> bool:
	var definition: CombatantDefinition = CombatantDatabase.combatants.get(guard.combatant_key)
	if definition == null or targets.is_empty():
		return false
	var ranges = ranges_of(guard)
	var from = tile_of(guard.global_position)
	var steps_to := {from: 0}
	var frontier := [from]
	while not frontier.is_empty():
		var tile: Vector2i = frontier.pop_front()
		for target in targets:
			var apart = absi(tile.x - target.x) + absi(tile.y - target.y)
			for span in ranges:
				if apart >= span[0] and apart <= span[1] and (apart <= 1 or sight.clear(tile, target)):
					return true
		if steps_to[tile] >= definition.movement:
			continue
		for step in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var next: Vector2i = tile + step
			if steps_to.has(next) or not _standable(next):
				continue
			steps_to[next] = steps_to[tile] + 1
			frontier.append(next)
	return false


## Every [least, most] range `guard` can hit somebody at in the fight: anything
## that does damage he knows at his level, or has in his pockets - and a swing
## at somebody beside him, whatever else.
func ranges_of(guard: Guard) -> Array:
	var ranges := [[1, 1]]
	var definition: CombatantDefinition = CombatantDatabase.combatants.get(guard.combatant_key)
	if definition == null:
		return ranges
	var keys: Array = []
	keys.append_array(definition.skills)
	keys.append_array(definition.secondary_skills)
	keys.append_array(_pocket_for_fight(guard))
	for key in keys:
		var skill: SkillDefinition = SkillDatabase.skills.get(key)
		if skill == null or not skill.deals_damage or skill.targets_ally or skill.required_level > guard.level:
			continue
		ranges.append([maxi(skill.min_range, 1), maxi(skill.max_range, 1)])
	return ranges


## The furthest `guard` can hit somebody at in the fight.
func reach_of(guard: Guard) -> int:
	var reach := 1
	for span in ranges_of(guard):
		reach = maxi(reach, span[1])
	return reach


## What `guard` has to hand in the fight: whatever of his pockets is any use
## in one - nothing, once they have been picked.
func _pocket_for_fight(guard: Guard) -> Array:
	var kept := []
	if guard.picked:
		return kept
	for key in guard.pockets:
		var item: ItemDefinition = ItemDatabase.item(key) if key != "" else null
		if item != null and not item.stealth_only():
			kept.append(key)
	return kept


## The barracks turning out, when the map was on edge before the catch: half
## the setup's reinforcements on round 3 of a Wary map, all of them on round 2
## of an Alarmed one, and nobody at all on a Calm one.
func _send_for_reinforcements(spawns: Array, taken: Dictionary, caught_at: Vector2i):
	if setup == null or setup.reinforcements.is_empty():
		return
	var level = level_of(alert)
	if level == 0:
		return
	var coming: Array = setup.reinforcements if level == 2 \
		else setup.reinforcements.slice(0, ceili(setup.reinforcements.size() / 2.0))
	var arrive = caught_at
	if setup.reinforcements_arrive_at != "":
		var at = Actors.waypoint_position(setup.reinforcements_arrive_at)
		if at != null:
			arrive = tile_of(at)
		else:
			push_warning("Stealth reinforcements arrive at '%s', which this map has no waypoint called." % setup.reinforcements_arrive_at)
	for key in coming:
		if not CombatantDatabase.combatants.has(key):
			continue
		var tile = _free_tile_near(arrive, taken)
		taken[tile] = true
		var spawn = _spawn(key, 1, tile, Campaign.party_level)
		spawn.arrives_on_round = 2 if level == 2 else 3
		spawns.append(spawn)


func _spawn(key: String, side: int, tile: Vector2i, level: int) -> SpawnDefinition:
	var spawn := SpawnDefinition.new()
	spawn.combatant_key = key
	spawn.side = side
	spawn.position = tile
	spawn.level = clampi(level, 1, 3)
	return spawn


## The nearest tile to `around` somebody can stand on and nobody has claimed.
## Two people caught mid-stride can be on one tile; the fight needs them on two.
func _free_tile_near(around: Vector2i, taken: Dictionary) -> Vector2i:
	var frontier := [around]
	var visited := {around: true}
	while not frontier.is_empty():
		var tile: Vector2i = frontier.pop_front()
		if not taken.has(tile) and _standable(tile):
			return tile
		for step in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var next: Vector2i = tile + step
			if visited.has(next) or not sight.region().has_point(next):
				continue
			visited[next] = true
			frontier.append(next)
	return around


## Whether somebody can stand on `tile` in the fight. The battle terrain's own
## tiles decide, not the map's: a map can paint over its terrain - the
## crossroads lays planks across channels its battle terrain leaves as water -
## and somebody caught on a plank that is not in the fight has to start it on
## the nearest floor that is.
func _standable(tile: Vector2i) -> bool:
	var blocked = _battle_blocking()
	if blocked != null:
		return not blocked.has(tile) and _battle_region.has_point(tile)
	if not scene.has_method("is_walkable"):
		return true
	return scene.is_walkable(_tile_map.to_global(_tile_map.map_to_local(tile)))


var _battle_blocked = null
var _battle_region := Rect2i()


## The tiles nobody on foot can stand on in the battle terrain, read the way
## combat reads them: "Blocks" listing the ground, or no tile painted at all.
## Null when there is no terrain to read.
func _battle_blocking():
	if _battle_blocked != null:
		return _battle_blocked
	if setup == null or setup.battle_terrain == null:
		return null
	var terrain = setup.battle_terrain.instantiate()
	var tiles: TileMap = terrain.get_node_or_null("TileMap")
	if tiles == null:
		for child in terrain.get_children():
			if child is TileMap:
				tiles = child
	_battle_blocked = {}
	if tiles != null:
		_battle_region = tiles.get_used_rect()
		for x in range(_battle_region.position.x, _battle_region.end.x):
			for y in range(_battle_region.position.y, _battle_region.end.y):
				var data = tiles.get_cell_tile_data(0, Vector2i(x, y))
				if data == null or 0 in data.get_custom_data("Blocks"):
					_battle_blocked[Vector2i(x, y)] = true
	terrain.free()
	return _battle_blocked


## What the guards can see, as a tint over the ground - coloured, while he is
## in a disguise (or one is being looked at on the bar), by what it means to
## him: see gaze_of.
func _draw():
	var by_gaze := seen_by_gaze()
	var half := Vector2(Grid.HALF_TILE)
	for gaze in [Gaze.FOOLED, Gaze.ASKS, Gaze.SEES]:
		var seen: Dictionary = by_gaze[gaze]
		var fill: Color = GAZE_FILL[gaze]
		var edge: Color = GAZE_EDGE[gaze]
		for tile in seen:
			var centre = to_local(_tile_map.to_global(_tile_map.map_to_local(tile)))
			draw_rect(Rect2(centre - half, half * 2.0), fill)
			# An edge only where this kind of watched ground stops, so each
			# view reads as one shape rather than a grid of boxes.
			for side in [[Vector2i.UP, Vector2(-1, -1), Vector2(1, -1)], [Vector2i.DOWN, Vector2(-1, 1), Vector2(1, 1)],
					[Vector2i.LEFT, Vector2(-1, -1), Vector2(-1, 1)], [Vector2i.RIGHT, Vector2(1, -1), Vector2(1, 1)]]:
				if not seen.has(tile + side[0]):
					draw_line(centre + half * side[1], centre + half * side[2], edge, 6.0)
	_draw_routes()
	_draw_ghosts()
	var now = Time.get_ticks_msec() / 1000.0
	# Noises, as a ring spreading to how far they carry.
	var fresh := []
	for ripple in _ripples:
		var age = (now - ripple[1]) / RIPPLE_SECONDS
		if age >= 1.0:
			continue
		fresh.append(ripple)
		draw_arc(to_local(ripple[0]), Grid.tiles(ripple[2]) * age, 0.0, TAU, 48,
			Color(METER_DOUBT, 0.7 * (1.0 - age)), 8.0)
	_ripples = fresh
	var party = scene.get("party") if scene != null else null
	var leader: Node2D = party.leader if party != null else null
	# Listening: a slow ring about him, for as long as it lasts.
	if leader != null and _ears_left > 0.0:
		var pulse = fmod(now, 1.0)
		draw_arc(to_local(leader.global_position), Grid.tiles(1.0 + 3.0 * pulse), 0.0, TAU, 48,
			Color(0.55, 0.85, 1.0, 0.5 * (1.0 - pulse)), 6.0)
	# Aiming a throw: where it would land, and how far the noise would carry -
	# green where it can land, red where it cannot.
	if _aiming != "" and leader != null:
		var target = tile_of(get_global_mouse_position())
		var at = to_local(_tile_map.to_global(_tile_map.map_to_local(target)))
		var thrown: ItemDefinition = ItemDatabase.item(_aiming)
		# A dart is only any good with somebody there for it to find.
		var ok = can_throw_to(target) and (thrown == null or not thrown.is_poison() or dart_target(target) != null)
		var colour = Color(0.45, 0.95, 0.5, 0.9) if ok else Color(0.95, 0.35, 0.3, 0.9)
		draw_line(to_local(leader.global_position), at, Color(colour, 0.5), 4.0)
		draw_arc(at, Grid.tiles(0.3), 0.0, TAU, 24, colour, 8.0)
		var item: ItemDefinition = ItemDatabase.item(_aiming)
		if ok and item != null:
			draw_arc(at, Grid.tiles(item.distraction_radius), 0.0, TAU, 64, Color(colour, 0.35), 4.0)
		# Hidden, but where somebody has the spot in view: throw, and he is
		# seen. A red ring at his feet says so before he does.
		if not throw_watchers().is_empty():
			var feet = to_local(leader.global_position) + Vector2(0.0, Grid.tiles(0.3))
			draw_set_transform(feet, 0.0, Vector2(1.0, 0.45))
			draw_arc(Vector2.ZERO, Grid.tiles(0.5 + 0.05 * sin(now * 8.0)), 0.0, TAU, 40, METER_SURE, 8.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Whoever a click would be for: a ring pulsing at their feet.
	var shown := prompt()
	if not shown.is_empty() and (shown[0] is Vector2 or is_instance_valid(shown[0])) and shown[1].any(func(line): return line[2]):
		var anchor: Vector2 = shown[0] if shown[0] is Vector2 else shown[0].global_position
		var feet = to_local(anchor) + Vector2(0.0, Grid.tiles(0.3))
		var size = Grid.tiles(0.42 + 0.04 * sin(now * 6.0))
		draw_set_transform(feet, 0.0, Vector2(1.0, 0.45))
		draw_arc(Vector2.ZERO, size, 0.0, TAU, 40, PROMPT_RING, 6.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The meters over the guards' heads, drawn above everybody's sprites.
## Every mark is drawn around a point, at a scale: the "?" pulsing as it fills,
## the "!" popping in when a guard is sure, and the "!" over Cyrus when he is
## first seen.
class _Meters extends Node2D:
	var watch: StealthWatch = null

	func _draw():
		if watch == null:
			return
		var now = Time.get_ticks_msec() / 1000.0
		for guard in watch.guards:
			if not is_instance_valid(guard):
				continue
			var head = to_local(guard.global_position) + Vector2(0, -Grid.tiles(1.05))
			if guard.visible and watch.saying.has(guard):
				var said: Array = watch.saying[guard]
				_bubble(head + Vector2(0, -Grid.tiles(0.45)), said[0] if said[1] else "...")
			if watch.is_reporting(guard):
				# Off to tell somebody.
				_mark(head, 1.0, "!", StealthWatch.METER_DOUBT, 1.0 + StealthWatch.PULSE_SIZE * sin(now * StealthWatch.PULSE_FAST))
				continue
			var sure: float = watch.suspicion.get(guard, 0.0)
			var caught = watch.spotted_by == guard
			if sure <= 0.0 and not caught:
				if guard.visible and not guard.knocked_out:
					_state(head, guard, now)
				continue
			var grow = watch.pop_scale() if caught \
					else 1.0 + StealthWatch.PULSE_SIZE * sin(now * StealthWatch.pulse_rate(sure))
			var colour = StealthWatch.METER_SURE if caught else StealthWatch.METER_DOUBT
			_mark(to_local(guard.global_position) + Vector2(0, -Grid.tiles(1.05)), sure, "!" if caught else "?", colour, grow)
		# What he is saying, when he is having a word with somebody.
		if watch.leader_says != "":
			var talker = watch.scene.get("party") if watch.scene != null else null
			if talker != null and talker.leader != null:
				_bubble(to_local(talker.leader.global_position) + Vector2(0, -Grid.tiles(1.5)), watch.leader_says)
		# Cyrus, the moment a guard's view falls on him: a "!" on a dark disc,
		# rising a little - solid for most of its moment, fading at the end.
		if watch.startled():
			var party = watch.scene.get("party") if watch.scene != null else null
			var leader: Node2D = party.leader if party != null else null
			if leader != null:
				var age = (now - watch._startled_at) / StealthWatch.STARTLE_SECONDS
				var fade = clampf((1.0 - age) / 0.4, 0.0, 1.0)
				var over = to_local(leader.global_position) + Vector2(0, -Grid.tiles(1.05 + 0.2 * age))
				var radius = Grid.tiles(0.2)
				draw_circle(over, radius, Color(StealthWatch.METER_BACK, StealthWatch.METER_BACK.a * fade))
				var font = ThemeDB.fallback_font
				var size = 80
				var width = font.get_string_size("!", HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
				draw_string(font, over + Vector2(-width / 2.0, size * 0.35), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, size,
					Color(StealthWatch.METER_DOUBT, fade))

	## What somebody not watching anybody is up to, when it shows: asleep,
	## being sick, unwell.
	func _state(over: Vector2, guard: Guard, now: float):
		var font = ThemeDB.fallback_font
		match guard.mood:
			Guard.Mood.ASLEEP:
				var rise = fmod(now * 0.6, 1.0)
				draw_string(font, over + Vector2(10, -rise * 60.0), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 52,
					Color(0.8, 0.88, 1.0, 1.0 - rise))
				draw_string(font, over + Vector2(40, -30 - rise * 60.0), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 38,
					Color(0.8, 0.88, 1.0, 0.8 - rise * 0.8))
			Guard.Mood.RETCHING:
				draw_string(font, over + Vector2(-16, 20), "~", HORIZONTAL_ALIGNMENT_LEFT, -1, 72, Color(0.55, 0.85, 0.35))
			Guard.Mood.SICK:
				draw_string(font, over + Vector2(-14, 20), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Color(0.95, 0.6, 0.6))


	## A speech bubble with `text` in it, its bottom at `over`.
	func _bubble(over: Vector2, text: String):
		var font = ThemeDB.fallback_font
		var size := 40
		var width := minf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x, 1100.0)
		var lines := ceili(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 1100.0)
		var box = Rect2(over - Vector2(width / 2.0 + 20.0, lines * size * 1.2 + 24.0), Vector2(width + 40.0, lines * size * 1.2 + 24.0))
		draw_rect(box, Color(0.96, 0.94, 0.88, 0.92))
		draw_colored_polygon(PackedVector2Array([over + Vector2(-14, 0), over + Vector2(14, 0), over + Vector2(0, 22)]),
			Color(0.96, 0.94, 0.88, 0.92))
		draw_multiline_string(font, box.position + Vector2(20.0, size + 6.0), text, HORIZONTAL_ALIGNMENT_LEFT, width, size,
			-1, Color(0.12, 0.1, 0.08))


	## A meter: a ring filled to `sure` round a mark, `grow` times its size.
	func _mark(over: Vector2, sure: float, mark: String, colour: Color, grow: float):
		var radius = Grid.tiles(0.22) * grow
		draw_circle(over, radius + 8.0 * grow, StealthWatch.METER_BACK)
		draw_arc(over, radius, -PI / 2.0, -PI / 2.0 + TAU * clampf(sure, 0.0, 1.0), 32, colour, 14.0 * grow)
		var font = ThemeDB.fallback_font
		var size = int(64 * grow)
		var width = font.get_string_size(mark, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
		draw_string(font, over + Vector2(-width / 2.0, size * 0.35), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)


## Arrows at the edge of the screen for guards growing sure who are off it -
## the one you cannot see is the one that catches you, zoomed in.
class _EdgeArrows extends Control:
	var watch: StealthWatch = null

	func _ready():
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta):
		# Sized by hand, as the vignette is: nothing above to anchor to.
		position = Vector2.ZERO
		size = get_viewport_rect().size
		queue_redraw()

	## Where each arrow goes: [{guard, at, towards}] for every guard growing
	## sure whose head is off the screen.
	func arrows() -> Array:
		var found := []
		if watch == null:
			return found
		var inside = Rect2(Vector2.ZERO, size).grow(-StealthWatch.ARROW_MARGIN)
		var middle = size / 2.0
		for guard in watch.guards:
			if not is_instance_valid(guard):
				continue
			var sure: float = watch.suspicion.get(guard, 0.0)
			if sure <= 0.0 and watch.spotted_by != guard:
				continue
			var on_screen: Vector2 = guard.get_global_transform_with_canvas().origin
			if inside.has_point(on_screen):
				continue
			var towards = (on_screen - middle).normalized()
			# Out along that line from the middle until it meets the inset edge.
			var reach = INF
			if absf(towards.x) > 0.0001:
				reach = minf(reach, (inside.size.x / 2.0) / absf(towards.x))
			if absf(towards.y) > 0.0001:
				reach = minf(reach, (inside.size.y / 2.0) / absf(towards.y))
			found.append({"guard": guard, "at": middle + towards * reach, "towards": towards, "sure": sure})
		return found

	func _draw():
		for arrow in arrows():
			var caught = watch.spotted_by == arrow.guard
			var colour = StealthWatch.METER_SURE if caught else StealthWatch.METER_DOUBT
			colour.a = lerpf(0.55, 1.0, arrow.sure)
			var tip: Vector2 = arrow.at
			var back: Vector2 = tip - arrow.towards * StealthWatch.ARROW_SIZE * 1.6
			var side: Vector2 = arrow.towards.orthogonal() * StealthWatch.ARROW_SIZE * 0.8
			draw_colored_polygon(PackedVector2Array([tip, back + side, back - side]), colour)


## What a click would do, in a small panel right over whoever it is for - see
## prompt(). On the HUD rather than the map, so it stays one size however far
## the camera is zoomed.
class _Prompt extends PanelContainer:
	var watch: StealthWatch = null
	var _text: RichTextLabel = null
	## The lines last written, so the text is only rebuilt when it changes.
	var _written: Array = []

	func _ready():
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.06, 0.08, 0.11, 0.88)
		box.border_color = StealthWatch.PROMPT_RING
		box.set_border_width_all(2)
		box.set_corner_radius_all(6)
		box.content_margin_left = 12
		box.content_margin_right = 12
		box.content_margin_top = 6
		box.content_margin_bottom = 6
		add_theme_stylebox_override("panel", box)
		_text = RichTextLabel.new()
		_text.bbcode_enabled = true
		_text.fit_content = true
		_text.scroll_active = false
		_text.autowrap_mode = TextServer.AUTOWRAP_OFF
		_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_text.add_theme_font_size_override("normal_font_size", 18)
		add_child(_text)
		visible = false

	func _process(_delta):
		var shown: Array = watch.prompt() if watch != null else []
		if shown.is_empty() or not (shown[0] is Vector2 or is_instance_valid(shown[0])):
			visible = false
			return
		var lines: Array = shown[1]
		if lines != _written:
			_written = lines.duplicate(true)
			var written := PackedStringArray()
			for line in lines:
				if line[2]:
					written.append("[color=#%s]%s[/color]   %s" % [StealthWatch.PROMPT_KEY.to_html(false), line[0], line[1]])
				else:
					written.append("[color=#%s]%s   %s[/color]" % [StealthWatch.PROMPT_CANNOT.to_html(false), line[0], line[1]])
			_text.text = "\n".join(written)
			reset_size()
		visible = true
		# Just over their head: as high as they stand above their tile, and a
		# little more.
		var head := 0.0
		var anchor: Vector2
		if shown[0] is Vector2:
			anchor = shown[0]
		else:
			anchor = shown[0].global_position
			var sprite = shown[0].get("sprite")
			if sprite != null and is_instance_valid(sprite):
				head = sprite.head_height()
		var world = anchor - Vector2(0.0, Grid.HALF_TILE.y + head + Grid.tiles(0.2))
		var screen = get_viewport().get_canvas_transform() * world
		position = (screen - Vector2(size.x / 2.0, size.y)).round()


## The dark on a dark map: every tile no light reaches drawn over in shadow,
## and the edges of the light fading into it. Under what the guards can see.
class _Dark extends Node2D:
	var watch: StealthWatch = null

	func _draw():
		if watch == null or not watch.is_dark() or watch.sight == null:
			return
		var region: Rect2i = watch.sight.region()
		var half := Vector2(Grid.HALF_TILE)
		for x in range(region.position.x, region.end.x):
			for y in range(region.position.y, region.end.y):
				var tile := Vector2i(x, y)
				var shade = StealthWatch.DARK_ALPHA * (1.0 - watch.lit_at(tile))
				if shade <= 0.01:
					continue
				var centre = to_local(watch._tile_map.to_global(watch._tile_map.map_to_local(tile)))
				draw_rect(Rect2(centre - half, half * 2.0), Color(0.02, 0.03, 0.08, shade))


## What there is to do besides getting out, under the bar - ticked off as it
## is done, and struck when it can no longer be. Only on a map that has some.
class _ObjectiveList extends PanelContainer:
	var watch: StealthWatch = null
	var _text: RichTextLabel = null
	var _written := []

	func _ready():
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.06, 0.08, 0.11, 0.78)
		box.set_corner_radius_all(6)
		box.content_margin_left = 12
		box.content_margin_right = 12
		box.content_margin_top = 6
		box.content_margin_bottom = 6
		add_theme_stylebox_override("panel", box)
		_text = RichTextLabel.new()
		_text.bbcode_enabled = true
		_text.fit_content = true
		_text.scroll_active = false
		_text.autowrap_mode = TextServer.AUTOWRAP_OFF
		_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_text.add_theme_font_size_override("normal_font_size", 16)
		add_child(_text)

	func _process(_delta):
		var listed: Array = watch.objectives() if watch != null else []
		visible = not listed.is_empty()
		if not visible:
			return
		if listed != _written:
			_written = listed.duplicate(true)
			var lines := PackedStringArray()
			for objective in listed:
				match objective[1]:
					"done":
						lines.append("[color=#9fc7a4]Done: %s[/color]" % objective[0])
					"lost":
						lines.append("[color=#8a919c][s]%s[/s][/color]" % objective[0])
					_:
						lines.append("[color=#e8e2d4]%s[/color]" % objective[0])
			_text.text = "\n".join(lines)
			reset_size()
		var bar = watch._bar
		if bar != null and is_instance_valid(bar):
			position = Vector2(bar.position.x, bar.position.y + bar.size.y + 6.0)
