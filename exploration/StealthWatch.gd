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
const TAKEDOWN_NOISE_TILES := 3.0
## Dragging a body, he walks at this share of his usual pace - and a guard who
## sees him at it, or at changing clothes, knows him at once (see
## caught_red_handed).
const DRAG_PACE := 0.5

## --- The map's alert ---
## Raised by every investigation a doubtful guard sets off; a found body or a
## captain's shout sends it to the top. It fades back (StealthSetup's Alert
## Fades Per Second), and while it is up every guard walks up to ALERT_PACE
## quicker, looks ALERT_CONE degrees wider either side and grows sure up to
## ALERT_FILL quicker.
const ALERT_PER_INVESTIGATION := 0.5
const ALERT_WARY := 0.34
const ALERT_ALARMED := 0.67
const ALERT_PACE := 0.4
const ALERT_CONE := 20.0
const ALERT_FILL := 0.6
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
## Whether any guard has ever so much as begun to notice anybody here.
var _noticed_ever := false
var _ears_left := 0.0
var _ears_cooldown := 0.0
## The item being aimed to throw, or "".
var _aiming := ""
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
		"noticed": _noticed_ever,
	}
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
		if guard.knocked_out:
			state.down[id] = {
				"at": guard.global_position,
				"found": not body_unfound(guard) and not _stashed.has(guard),
				"stashed": _id_of(_stashed[guard]) if _stashed.has(guard) else "",
			}
	return state


func _restore(state: Dictionary):
	alert = state.get("alert", 0.0)
	_noticed_ever = state.get("noticed", false)
	_worn = state.get("worn", {}).duplicate()
	var talked := {}
	for pair in state.get("talked_round", []):
		talked[pair[0]] = pair[1]
	for guard in guards:
		var id = _id_of(guard)
		guard.picked = state.get("picked", []).has(id)
		if talked.has(id):
			guard.questioned = true
			guard.fooled = talked[id]
		var down = state.get("down", {}).get(id)
		if down == null:
			continue
		guard.global_position = down.at
		guard.knock_out()
		guard.visible = true
		_bodies[guard] = down.found
		var spot = _map.get_node_or_null(down.stashed) if down.stashed != "" else null
		if spot is HidingSpot:
			guard.global_position = spot.global_position
			guard.visible = false
			spot.holds_body = guard
			_stashed[guard] = spot
			_bodies.erase(guard)


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
	return ""


## Whether the leader is doing something nobody innocent does - dragging a
## body, or changing into a disguise - so that any guard who sees him at it is
## sure of him on the spot, rather than growing sure.
func caught_red_handed() -> bool:
	return _dragging != null or _changing_into != ""


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


## "Calm", "Wary" or "Alarmed", for the bar.
func alert_level() -> String:
	if alert >= ALERT_ALARMED:
		return "Alarmed"
	if alert >= ALERT_WARY:
		return "Wary"
	return "Calm"


## Lets the alert fade, and hands every guard what it adds to them right now.
## The cone's share is rounded to whole steps, so a guard's view is not worked
## out afresh every frame the alert eases down.
func _calm_down(delta: float):
	var fades = setup.alert_fades_per_second if setup != null else 0.02
	alert = maxf(0.0, alert - fades * delta)
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


## --- Throwing (T) ---


## The first thing the leader carries to throw, or "".
func throwable() -> String:
	var carried = Campaign.distractions_of(leader_key())
	return carried[0] if not carried.is_empty() else ""


## Starts aiming a throw - the next click on the map says where. False when
## there is nothing to throw.
func begin_throw() -> bool:
	if spotted_by != null or throwable() == "":
		return false
	_aiming = throwable()
	return true


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


## Throws the item being aimed onto `tile`: gone from the bag, and a noise there
## that the guards within its radius go to look at. False, and nothing thrown,
## when it cannot land there.
func throw_at(tile: Vector2i) -> bool:
	var item_key = _aiming if _aiming != "" else throwable()
	var item: ItemDefinition = ItemDatabase.item(item_key) if item_key != "" else null
	if item == null or not can_throw_to(tile):
		return false
	Campaign.take_item(leader_key(), item_key)
	_aiming = ""
	make_noise(_tile_map.to_global(_tile_map.map_to_local(tile)), item.distraction_radius, true)
	if scene.has_method("log_message"):
		scene.log_message("[color=yellow]%s[/color] lands with a clatter.\n" % item.name)
	return true


func _unhandled_input(event):
	if scene == null:
		return
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
	if spotted_by != null or (scene.has_method("is_holding") and scene.is_holding()):
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
	if scene.has_method("log_message"):
		scene.log_message("[color=yellow]%s[/color] is out cold.\n" % _name_of(guard))
	# Not quietly: anybody near enough comes to see what that was.
	make_noise(guard.global_position, TAKEDOWN_NOISE_TILES, true)
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
	if _dragging != null or _changing_into != "":
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
	party.pace = DRAG_PACE
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
## the one on `tile`, given one - where no guard will ever find it, or else
## on the ground where it is.
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
	if scene.has_method("log_message"):
		scene.log_message("[color=yellow]%s[/color] is out of sight for good.\n" % _name_of(body))
	return true


## Whether `guard` is knocked out and stuffed into a hiding spot.
func is_stashed(guard) -> bool:
	return _stashed.has(guard)


func _let_go():
	_dragging = null
	_drag_path = []
	var party = scene.get("party") if scene != null else null
	if party != null and is_instance_valid(party):
		party.pace = 1.0


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
	if guard.picked_flag != "":
		Campaign.set_flag(guard.picked_flag)
	if scene.has_method("log_message"):
		scene.log_message("Lifted from [color=yellow]%s[/color]: %s.\n" % [_name_of(guard), ", ".join(names)])
	return true


## Whether `guard` is lying knocked out where somebody could find them, and
## has not been found yet.
func body_unfound(guard: Guard) -> bool:
	return _bodies.has(guard) and not _bodies[guard]


## A guard whose view falls on somebody knocked out raises the alarm, and goes
## to see.
func _look_for_bodies(finder: Guard):
	if finder.kind == Guard.Kind.WARD:
		return
	for body in _bodies:
		if _bodies[body] or not is_instance_valid(body):
			continue
		if _seen.get(finder, {}).has(tile_of(body.global_position)):
			_bodies[body] = true
			raise_alert(1.0)
			finder.investigate(body.global_position)
			if scene.has_method("log_message"):
				scene.log_message("[color=red]%s has found %s - the alarm is up![/color]\n" % [_name_of(finder), _name_of(body)])
	# Hunting for somebody, he looks into the hiding spots about where he saw
	# them - and a body stuffed into one is as good as found.
	if not finder.is_hunting():
		return
	for body in _stashed:
		if _stashed_found.has(body) or not is_instance_valid(body):
			continue
		var tile = tile_of(_stashed[body].global_position)
		if _seen.get(finder, {}).has(tile) and looks_behind_cover(finder, tile):
			_stashed_found[body] = true
			raise_alert(1.0)
			if scene.has_method("log_message"):
				scene.log_message("[color=red]%s has found %s, hidden away - the alarm is up![/color]\n" % [_name_of(finder), _name_of(body)])


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
	if holding:
		return
	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	_ears_cooldown = maxf(0.0, _ears_cooldown - delta)
	_ears_left = maxf(0.0, _ears_left - delta)
	if _changing_into != "":
		_change_left -= delta
		if _change_left <= 0.0:
			_finish_change()
	_drag_along()
	_calm_down(delta)
	var party = scene.get("party")
	var dashing: bool = party != null and party.dashing
	var standing := _party_standing()
	var watched := false
	for guard in guards:
		if not is_instance_valid(guard) or guard.knocked_out:
			continue
		_refresh_seen(guard)
		var from = tile_of(guard.global_position)
		# Whoever in view they are growing sure of fastest, and where they are.
		var rate := 0.0
		var seen_at := Vector2.ZERO
		var seen_disguised := false
		var caught_at_it := false
		for someone in standing:
			if not can_perceive(guard, someone):
				continue
			# Seen dragging a body or changing clothes, there is no doubt at
			# all who he is - whatever he has on.
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
			suspicion[guard] = 1.0
			guard.watching(seen_at)
			_caught_by(guard)
			break
		if rate > 0.0:
			watched = true
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
	if _slowed:
		Engine.time_scale = 1.0
		_slowed = false
	_remove_muffle()
	# The party outlives a watch that is started again on the same map.
	_stop_changing()
	_let_go()


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
	var from = tile_of(guard.global_position)
	if guard.kind == Guard.Kind.DOG:
		# A nose: every tile within smell, walls or no walls.
		if _seen_key.get(guard) == [from]:
			return
		_seen_key[guard] = [from]
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
	# The width too: a guard investigating sees 340 degrees rather than 160.
	var key = [from, facing_step, guard.half_cone()]
	if _seen_key.get(guard) == key:
		return
	_seen_key[guard] = key
	var looking = Vector2.RIGHT.rotated(deg_to_rad(facing_step * FACING_STEP_DEGREES))
	_seen[guard] = sight.seen_from(from, looking, guard.half_cone())


## Somebody is sure. Everyone stops, the "!" goes up, and the fight is handed to
## Campaign to be fought where everybody stands.
func _caught_by(guard: Guard):
	spotted_by = guard
	# Caught is noticed, however it came about - talked into a corner included.
	_noticed_ever = true
	# Whatever he was in the middle of stops where it is.
	_stop_changing()
	_let_go()
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
		scene.log_message("[color=yellow]%s[/color] has spotted you!\n" % _name_of(guard))
	if guard.kind == Guard.Kind.CAPTAIN:
		_shout(guard)
	var fight = build_fight()
	# Written down before the scene goes, for walking back in after the fight.
	Campaign.stealth_state[scene.map_path()] = snapshot(fight)
	Campaign.begin_battle_from_exploration(fight, scene.map_path(), scene.party_position(), trigger())
	if not leave_for_battle:
		return
	await get_tree().create_timer(CAUGHT_PAUSE, true, false, true).timeout
	if is_inside_tree():
		SceneTransition.change_scene(scene.battle_scene)


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
## rearranged before it starts - where they were caught is the point.
func build_fight() -> EncounterDefinition:
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
	var per_round = setup.tiles_per_late_round if setup != null else 0.0
	for guard in guards:
		if not is_instance_valid(guard) or not CombatantDatabase.combatants.has(guard.combatant_key):
			continue
		if guard.knocked_out or guard.kind == Guard.Kind.WARD:
			continue
		var arrives := 1
		var gap = Vector2(tile_of(guard.global_position) - caught_at).length()
		if near > 0.0 and gap > near and guard != spotted_by and not _called.has(guard):
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
		spawns.append(spawn)
	fight.spawns = spawns
	fight.fighters = fighters
	return fight


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


## What the guards can see, as a tint over the ground.
func _draw():
	var seen := seen_tiles()
	var half := Vector2(Grid.HALF_TILE)
	for tile in seen:
		var centre = to_local(_tile_map.to_global(_tile_map.map_to_local(tile)))
		draw_rect(Rect2(centre - half, half * 2.0), SEEN_FILL)
		# An edge only where the watched ground stops, so the view reads as one
		# shape rather than a grid of boxes.
		for side in [[Vector2i.UP, Vector2(-1, -1), Vector2(1, -1)], [Vector2i.DOWN, Vector2(-1, 1), Vector2(1, 1)],
				[Vector2i.LEFT, Vector2(-1, -1), Vector2(-1, 1)], [Vector2i.RIGHT, Vector2(1, -1), Vector2(1, 1)]]:
			if not seen.has(tile + side[0]):
				draw_line(centre + half * side[1], centre + half * side[2], SEEN_EDGE, 6.0)
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
		var ok = can_throw_to(target)
		var colour = Color(0.45, 0.95, 0.5, 0.9) if ok else Color(0.95, 0.35, 0.3, 0.9)
		draw_line(to_local(leader.global_position), at, Color(colour, 0.5), 4.0)
		draw_arc(at, Grid.tiles(0.3), 0.0, TAU, 24, colour, 8.0)
		var item: ItemDefinition = ItemDatabase.item(_aiming)
		if ok and item != null:
			draw_arc(at, Grid.tiles(item.distraction_radius), 0.0, TAU, 64, Color(colour, 0.35), 4.0)
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
			var sure: float = watch.suspicion.get(guard, 0.0)
			var caught = watch.spotted_by == guard
			if sure <= 0.0 and not caught:
				continue
			var grow = watch.pop_scale() if caught \
					else 1.0 + StealthWatch.PULSE_SIZE * sin(now * StealthWatch.pulse_rate(sure))
			var colour = StealthWatch.METER_SURE if caught else StealthWatch.METER_DOUBT
			_mark(to_local(guard.global_position) + Vector2(0, -Grid.tiles(1.05)), sure, "!" if caught else "?", colour, grow)
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
