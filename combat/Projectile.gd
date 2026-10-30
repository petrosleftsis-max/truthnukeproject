extends Node2D
class_name Projectile
## A move seen travelling from whoever used it to where it was aimed, so that
## it is clear on the board who does what (the designer, 2026-10-30): an orb
## in the move's colour - its element's (Damage.type_colour), a mend's green -
## with a fading trail behind it, and a burst in its element's own way where it
## lands (MoveFeel.burst). A move with an area lights the tiles it lands on: a
## line's and a cone's as it goes past them, an area's going out from where it
## lands. How it goes is the move's Projectile Style; Automatic is worked out
## from the move (style_for): nothing for a melee blow or one at its user's own
## tile, a streak the length of a line, a fan for a cone, an arc for anything
## that goes over what is in the way (Respects Blocking off), and a straight
## bolt for the rest. A beam holds a moment and fades; a spray fills a cone for
## half a second; Back To User comes from where it was aimed to its user. What
## flies is the move's Projectile Look: the orb, a tracer, a dart, a rock, a
## chain... (SkillDefinition.ProjectileLook).
##
## The blow lands as it arrives: Combat awaits fly() before resolving anything,
## and tells it what became of the blow (verdict) - a miss flies on past and
## fades, a graze bursts dimly, a copy taking it shatters. Cast through a raised
## element (Plasma for Fire), it flares mid-flight from the first colour into
## the raised one. Purely to look at - nothing in it rolls, nothing waits on
## anything but its own clock, and it changes nothing in the fight, so a fight
## played on two machines (Net) comes out the same with it. Its clock is the
## game's, so a fast enemy turn, or a fight being caught up with, plays it fast
## too.
##
## A slot to fill (the designer's placeholder-with-slot way): a move's
## Projectile Texture flies in place of what is drawn, trail and all; its
## Projectile Scene in place of everything drawn here; its Travel Sound plays
## under it and its Impact Sound as it lands (empty: stand-ins). Left empty,
## these stand-ins are drawn - the designer makes the real art.
##
## Headless - the test harness - it lands at once, unless plays_headless is set.

## Emitted as it arrives, once.
signal landed

## Set by a test that wants to see one fly with nobody watching.
static var plays_headless := false

## What became of the blow on whoever it flew at (verdict).
enum Verdict { NONE, HIT, MISSED, GRAZED, IMAGE }

## How long a flight takes: a moment, and so much more a tile, within bounds.
const BASE_SECONDS := 0.12
const SECONDS_A_TILE := 0.035
const LEAST_SECONDS := 0.16
const MOST_SECONDS := 0.5
## A thrown thing takes a little longer, going up and coming down.
const ARC_SLOWER := 1.2
## How high an arc goes, for its length, and at most - in tiles.
const ARC_RISE := 0.22
const ARC_MOST_TILES := 1.6
## A streak along a line goes this fast, whatever the line.
const STREAK_SECONDS := 0.2
## The orb's radius, a tile's share - the glow round it twice that.
const ORB_TILES := 0.11
## How long the trail behind it reaches back, in seconds.
const TRAIL_SECONDS := 0.16
const STREAK_TRAIL_SECONDS := 0.3
## The burst where it lands: how long, and how wide its ring.
const BURST_SECONDS := 0.28
const BURST_TILES := 0.45
## An area's tiles light up a moment apart going out from where it landed -
## so much later a tile further out.
const RIPPLE_SECONDS_A_TILE := 0.025
## A beam: how long it takes to reach, how long it holds, how long it fades.
const BEAM_REACH_SECONDS := 0.07
const BEAM_HOLD_SECONDS := 0.22
const BEAM_FADE_SECONDS := 0.2
## A spray: how long it pours, and when the blow lands in it.
const SPRAY_SECONDS := 0.5
const SPRAY_LANDS_AT := 0.28
## Looks that go faster or slower than an orb would.
const LOOK_PACE := {
	SkillDefinition.ProjectileLook.TRACER: 0.6, SkillDefinition.ProjectileLook.TWIN_TRACER: 0.7,
	SkillDefinition.ProjectileLook.DART: 1.25, SkillDefinition.ProjectileLook.CANDLE: 1.5,
	SkillDefinition.ProjectileLook.BUBBLE: 1.3, SkillDefinition.ProjectileLook.ROCK: 1.1,
	SkillDefinition.ProjectileLook.LIMB: 1.1, SkillDefinition.ProjectileLook.GREAT_ORB: 1.15,
}
## How long a blow's verdict is waited for once it has arrived, before it is
## taken to have hit.
const VERDICT_SECONDS := 0.12
## A miss flies on past whoever it missed, this far and this long, fading.
const MISS_TILES := 0.9
const MISS_SECONDS := 0.22
## A mend's colour, and what a move that neither hurts nor mends goes in.
const MEND := Color("7ee08a")
const SPELLWORK := Color("c9b6ff")

## The projectiles of the move flying now, for Combat to tell what became of
## each blow (verdict).
static var _flying: Array = []

var from := Vector2.ZERO
var to := Vector2.ZERO
var colour := Color.WHITE
## The first colour of one raised mid-flight (flares into `colour` half way),
## or clear.
var colour_from := Color(0, 0, 0, 0)
## The second of two twisting tracers.
var colour_b := Color.WHITE
var style: int = SkillDefinition.ProjectileStyle.BOLT
var look: int = SkillDefinition.ProjectileLook.ORB
## The burst's ring where it lands, in pixels.
var burst_radius := 0.0
## The middles of the tiles a move with an area lands on, lit as it bursts.
var area_points: Array = []
## Who it is flying at, followed if they move while it flies - or {} - and
## where their middle is drawn off their sprite.
var target: Dictionary = {}
var target_offset := Vector2.ZERO
var texture: Texture2D = null
var art: Node2D = null
## The fight and the move, for its burst and its sounds; the element it lands as.
var combat: Combat = null
var skill: SkillDefinition = null
var element := -1
## Whether it bursts and sounds as it lands - the first of a fan does.
var leads := true
## A roar pours out as rings rather than a stream.
var roar := false
## Whether it lands as the blow on its target went (verdict): a blow at one.
var judged := false

var _seconds := 0.3
var _clock := 0.0
var _arrived := false
var _burst_clock := 0.0
## Where it has been, and when: [position, time] - drawn as its trail.
var _trail: Array = []
var _verdict: int = Verdict.NONE
var _settled := false
var _since_arrived := 0.0
## What it leaves behind and pours out: [{p, v, born, r}].
var _bits: Array = []
var _rng := RandomNumberGenerator.new()


## How `skill`, used by `user` aimed at `aim`, is seen to travel: its own
## Projectile Style, or worked out from the move.
static func style_for(combat: Combat, user: Dictionary, skill: SkillDefinition, aim: Vector2i) -> int:
	if skill.projectile_style != SkillDefinition.ProjectileStyle.AUTOMATIC:
		return skill.projectile_style
	if Combat.is_melee(skill) or skill.max_range <= 0 or Combat.covers(user, aim):
		return SkillDefinition.ProjectileStyle.NONE
	# Whoever moves is what is seen going: a blink, a throw of somebody.
	if skill.teleports != SkillDefinition.TeleportWho.NOBODY:
		return SkillDefinition.ProjectileStyle.NONE
	match combat.aoe_shape_of(user, skill):
		SkillDefinition.AoEShape.LINE:
			return SkillDefinition.ProjectileStyle.STREAK
		SkillDefinition.AoEShape.CONE:
			return SkillDefinition.ProjectileStyle.FAN
	return SkillDefinition.ProjectileStyle.BOLT if skill.respects_blocking else SkillDefinition.ProjectileStyle.ARC


## The colour `skill` flies in: its own, or its element's, or a mend's.
static func colour_for(skill: SkillDefinition, element: int = -1) -> Color:
	if skill.projectile_colour.a > 0.0:
		return skill.projectile_colour
	for effect in skill.all_effects():
		# A mend for whoever it lands on - not one its user gives themself (Light Swing).
		if effect != null and effect.type == EffectDefinition.EffectType.HEAL and not effect.applies_to_caster:
			return MEND
	var type := element if element >= 0 else int(skill.damage_type)
	if skill.deals_damage or type != Damage.Type.PHYSICAL:
		return Damage.type_colour(type)
	return SPELLWORK


## What `skill` is seen flying as: its own Projectile Look, or the orb.
static func look_for(skill: SkillDefinition) -> int:
	return skill.projectile_look if skill.projectile_look != SkillDefinition.ProjectileLook.AUTOMATIC else SkillDefinition.ProjectileLook.ORB


## `skill`, used by `user` on `combat`'s board aimed at `aim` - over `tiles`,
## what it lands on - flown there, and waited for until it arrives. `following`
## is who it is aimed at, followed if they move meanwhile.
static func fly(combat: Combat, user: Dictionary, skill: SkillDefinition, aim: Vector2i, tiles: Array = [], following: Dictionary = {}) -> void:
	_flying = []
	if DisplayServer.get_name() == "headless" and not plays_headless:
		return
	var sprite = user.get("sprite")
	if sprite == null or not is_instance_valid(sprite) or not sprite.is_inside_tree():
		return
	var how := style_for(combat, user, skill, aim)
	if how == SkillDefinition.ProjectileStyle.NONE:
		return
	var board: Node = sprite.get_parent()
	var start: Vector2 = sprite.position + combat.drawing_offset(user) + Vector2(0.0, -Grid.TILE_SIZE * 0.2)
	var flights := []
	var radius := combat.aoe_radius_of(user, skill)
	match how:
		SkillDefinition.ProjectileStyle.STREAK, SkillDefinition.ProjectileStyle.SPRAY:
			flights.append(_far_along(combat, start, aim, tiles))
		SkillDefinition.ProjectileStyle.FAN:
			flights.append_array(_fan_ends(combat, start, aim, tiles))
		SkillDefinition.ProjectileStyle.BEAM when combat.aoe_shape_of(user, skill) == SkillDefinition.AoEShape.LINE:
			flights.append(_far_along(combat, start, aim, tiles))
		_:
			var there := combat.get_combatant_at(aim) if following.is_empty() else following
			flights.append(combat.sprite_point(there) + combat.drawing_offset(there) if not there.is_empty() and there.has("position")
				else combat.sprite_point({}, aim))
			if following.is_empty() and not there.is_empty():
				following = there
	# The element it lands as - raised, for a cast an upgrade was spent on - and
	# the one it was, to flare from.
	var element := int(skill.damage_type)
	var thrown: Array = combat.elements_of(skill)
	if not thrown.is_empty():
		element = int(thrown[0])
	var first := element
	element = combat.effective_damage_type(user, element)
	# An area's tiles, lit as it lands - by the first of a fan, not all three.
	var lit := []
	if radius > 0 or how in [SkillDefinition.ProjectileStyle.STREAK, SkillDefinition.ProjectileStyle.FAN,
			SkillDefinition.ProjectileStyle.SPRAY, SkillDefinition.ProjectileStyle.BEAM]:
		for tile in tiles:
			if typeof(tile) == TYPE_VECTOR2I:
				lit.append(combat.sprite_point({}, tile))
	var look := look_for(skill)
	# Warning Shot: down beside whoever it was aimed at, not on them.
	var beside := skill.impact_look == SkillDefinition.ImpactLook.SPARK_BESIDE
	var made := []
	for end in flights:
		var flying := Projectile.new()
		flying.from = start
		flying.to = end
		flying.style = how
		flying.look = look
		flying.combat = combat
		flying.skill = skill
		flying.element = element
		flying.colour = colour_for(skill, element)
		if first != element and skill.projectile_colour.a <= 0.0:
			flying.colour_from = colour_for(skill, first)
		if thrown.size() > 1:
			flying.colour_b = colour_for(skill, int(thrown[1]))
		else:
			flying.colour_b = flying.colour.lerp(Color.WHITE, 0.5)
		flying.texture = skill.projectile_texture
		flying.target = following if flights.size() == 1 else {}
		if not flying.target.is_empty():
			flying.target_offset = combat.drawing_offset(following)
		if beside:
			flying.target = {}
			flying.to = end + Vector2(Grid.TILE_SIZE * 0.42, Grid.TILE_SIZE * 0.25)
		if how == SkillDefinition.ProjectileStyle.BACK_TO_USER:
			# From where it was aimed to its user - who it homes in on.
			flying.from = flying.to
			flying.to = start
			flying.target = user
			flying.target_offset = combat.drawing_offset(user) + Vector2(0.0, -Grid.TILE_SIZE * 0.2)
		flying.roar = skill.hand_look == SkillDefinition.HandLook.ROAR
		# A blow at one alone lands as it went for them (verdict); an area
		# lands on all of it whatever became of whoever stood in the middle.
		flying.judged = radius == 0 and not flying.target.is_empty() and how != SkillDefinition.ProjectileStyle.BACK_TO_USER
		flying.burst_radius = Grid.TILE_SIZE * BURST_TILES
		flying.leads = made.is_empty()
		if made.is_empty():
			flying.area_points = lit
		if skill.projectile_scene != null:
			var scene := skill.projectile_scene.instantiate()
			if scene is Node2D:
				flying.art = scene
			else:
				scene.free()
		flying.z_as_relative = false
		flying.z_index = 900
		board.add_child(flying)
		made.append(flying)
	_flying = made.duplicate()
	var travel := "travel"
	match how:
		SkillDefinition.ProjectileStyle.BEAM:
			travel = "travel_beam"
		SkillDefinition.ProjectileStyle.SPRAY:
			travel = "travel_spray"
	MoveFeel.sound(combat, skill.travel_sound, travel, user, -6.0)
	# All of them in: the first to land is as good as any, they fly together.
	for flying in made:
		if is_instance_valid(flying) and not flying._arrived:
			await flying.landed


## What became of the blow on `target`, told by Combat as it resolves it: the
## projectile flown at them misses past them, bursts dimly for a graze, or
## shatters a copy of them.
static func verdict(target: Dictionary, outcome: int):
	for flying in _flying:
		if is_instance_valid(flying) and flying.judged and flying.target.get("id", -1) == target.get("id", -2):
			flying._verdict = outcome


## Every blow of the move resolved: whatever was told nothing has hit.
static func settle():
	for flying in _flying:
		if is_instance_valid(flying) and flying._verdict == Verdict.NONE:
			flying._verdict = Verdict.HIT
	_flying = []


## Where a line move ends: the furthest of its tiles from where it starts.
static func _far_along(combat: Combat, start: Vector2, aim: Vector2i, tiles: Array) -> Vector2:
	var furthest := combat.sprite_point({}, aim)
	for tile in tiles:
		var at := combat.sprite_point({}, tile)
		if at.distance_to(start) > furthest.distance_to(start):
			furthest = at
	return furthest


## A cone's three: to the furthest of its tiles on each edge and in the middle.
static func _fan_ends(combat: Combat, start: Vector2, aim: Vector2i, tiles: Array) -> Array:
	var middle := combat.sprite_point({}, aim)
	if tiles.is_empty():
		return [middle]
	var reach := 0.0
	for tile in tiles:
		reach = maxf(reach, combat.sprite_point({}, tile).distance_to(start))
	var heading := (middle - start).angle()
	var far := []
	for tile in tiles:
		var at := combat.sprite_point({}, tile)
		if at.distance_to(start) >= reach - Grid.TILE_SIZE * 0.75:
			far.append(at)
	far.sort_custom(func(a, b): return angle_difference(heading, (a - start).angle()) < angle_difference(heading, (b - start).angle()))
	if far.size() < 3:
		return far if not far.is_empty() else [middle]
	return [far[0], start + (middle - start).normalized() * reach, far[far.size() - 1]]


func _ready():
	_rng.seed = hash([from.round(), to.round(), look])
	var tiles := from.distance_to(to) / float(Grid.TILE_SIZE)
	_seconds = clampf(BASE_SECONDS + SECONDS_A_TILE * tiles, LEAST_SECONDS, MOST_SECONDS) * LOOK_PACE.get(look, 1.0)
	match style:
		SkillDefinition.ProjectileStyle.ARC:
			_seconds *= ARC_SLOWER
		SkillDefinition.ProjectileStyle.STREAK:
			_seconds = STREAK_SECONDS
		SkillDefinition.ProjectileStyle.BEAM:
			_seconds = BEAM_REACH_SECONDS
		SkillDefinition.ProjectileStyle.SPRAY:
			_seconds = SPRAY_LANDS_AT
	position = Vector2.ZERO
	if art != null:
		add_child(art)
		art.position = from
	_trail.append([from, 0.0])
	# When each of its area's tiles lights: a line's and a cone's as it goes
	# past them, an area's going out from where it lands once it has.
	var length := maxf(from.distance_to(to), 1.0)
	var passes := style in [SkillDefinition.ProjectileStyle.STREAK, SkillDefinition.ProjectileStyle.FAN,
		SkillDefinition.ProjectileStyle.SPRAY, SkillDefinition.ProjectileStyle.BEAM]
	for point in area_points:
		_lit_at.append(minf(from.distance_to(point) / length, 1.0) * _seconds if passes
			else _seconds + to.distance_to(point) / float(Grid.TILE_SIZE) * RIPPLE_SECONDS_A_TILE)


## When each of area_points lights up, on its clock.
var _lit_at: Array = []


## Where it is `t` of the way there (0 to 1), and its shadow on the ground.
func _head(t: float) -> Vector2:
	var ground := from.lerp(_end(), t)
	if style != SkillDefinition.ProjectileStyle.ARC:
		return ground
	var rise := minf(from.distance_to(_end()) * ARC_RISE, Grid.TILE_SIZE * ARC_MOST_TILES)
	return ground + Vector2(0.0, -rise * 4.0 * t * (1.0 - t))


## Where it is going: who it was aimed at, wherever they are now.
func _end() -> Vector2:
	var sprite = target.get("sprite") if not target.is_empty() else null
	if sprite != null and is_instance_valid(sprite):
		return sprite.position + target_offset
	return to


## The colour it is now: the first, until it flares into the raised one.
func _colour_now() -> Color:
	if colour_from.a > 0.0 and _clock < _seconds * 0.5:
		return colour_from
	return colour


func _process(delta: float):
	if not _arrived:
		_clock += delta
		var t := minf(_clock / _seconds, 1.0)
		var at := _head(t)
		_trail.append([at, _clock])
		_leave_behind(at, delta)
		if art != null:
			var going: Vector2 = at - art.position
			art.position = at
			if going.length() > 0.01:
				art.rotation = going.angle()
		if t >= 1.0:
			_arrived = true
			if art != null and art.has_method("landed"):
				art.landed()
			landed.emit()
			# Combat has told what became of the blow by now, if it has anything
			# to tell (verdict) - or does within a moment.
			if not judged or _verdict != Verdict.NONE:
				_land()
	else:
		_clock += delta
		_since_arrived += delta
		if not _settled and (_verdict != Verdict.NONE or _since_arrived >= VERDICT_SECONDS):
			_land()
		if _settled:
			_burst_clock += delta
		if _verdict == Verdict.MISSED and _settled:
			# On past whoever it missed, fading.
			var past := _end() + (_end() - from).normalized() * Grid.TILE_SIZE * MISS_TILES * minf(_burst_clock / MISS_SECONDS, 1.0)
			_trail.append([past, _clock])
		_leave_behind(_end(), delta)
		if _settled and _burst_clock >= _lingers() and _clock >= _last_lit() + BURST_SECONDS:
			queue_free()
	# The trail fades from behind.
	var reach := _trail_seconds()
	while _trail.size() > 2 and _clock - _trail[0][1] > reach:
		_trail.pop_front()
	_bits = _bits.filter(func(bit): return _clock - bit.born < 0.6)
	queue_redraw()


## How long it stays once it has landed: its trail fading, a beam holding, a
## spray still pouring, a chain drawn back.
func _lingers() -> float:
	match style:
		SkillDefinition.ProjectileStyle.BEAM:
			return BEAM_HOLD_SECONDS + BEAM_FADE_SECONDS
		SkillDefinition.ProjectileStyle.SPRAY:
			return SPRAY_SECONDS - SPRAY_LANDS_AT + 0.3
	if _verdict == Verdict.MISSED:
		return MISS_SECONDS + _trail_seconds()
	return BURST_SECONDS + _trail_seconds()


## It has arrived and what became of it is known: its burst in its element's
## way, and the sound of it landing - or, missing, a whiff past them.
func _land():
	if _settled:
		return
	_settled = true
	if _verdict == Verdict.NONE:
		_verdict = Verdict.HIT
	if combat == null or not is_instance_valid(combat) or skill == null:
		return
	var at := _end()
	var mend := colour == MEND
	match _verdict:
		Verdict.MISSED:
			if leads:
				MoveFeel.sound(combat, null, "impact_miss", target)
			return
		Verdict.IMAGE:
			MoveFeel.shatter(combat, at)
			return
	var grazed := _verdict == Verdict.GRAZED
	if skill.deals_damage or mend:
		MoveFeel.burst(combat, at, element, 0.55 if grazed else 1.0, mend)
	elif style != SkillDefinition.ProjectileStyle.SPRAY:
		MoveFeel.burst(combat, at, -1, 0.5)
	if look == SkillDefinition.ProjectileLook.ROCK:
		MoveFeel.spawn(combat, &"rock_break", at)
	if skill.impact_look == SkillDefinition.ImpactLook.SPARK_BESIDE:
		MoveFeel.spawn(combat, &"spark_beside", at)
	if skill.impact_look == SkillDefinition.ImpactLook.PUFF:
		MoveFeel.puff(combat, at, colour.lerp(Color.WHITE, 0.3))
	# A trap lobbed: settling into the ground with a click and a glint.
	if skill.impact_look == SkillDefinition.ImpactLook.SETTLE:
		MoveFeel.spawn(combat, &"settle", at)
	if leads:
		MoveFeel.sound(combat, skill.impact_sound, MoveFeel._impact_sound_of(skill, element, grazed), target)


## What it leaves behind as it goes: embers, frost, drips off a special round;
## flames off a burning limb or a jet; and what a spray pours out.
func _leave_behind(at: Vector2, delta: float):
	if style == SkillDefinition.ProjectileStyle.SPRAY and _clock < SPRAY_SECONDS:
		var pours := 3 if roar else 9
		for i in pours:
			var aim: Vector2 = area_points[_rng.randi() % area_points.size()] if not area_points.is_empty() else to
			aim += Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * Grid.TILE_SIZE * 0.35
			_bits.append({"p": from, "v": (aim - from) / 0.32, "born": _clock, "r": Grid.TILE_SIZE * _rng.randf_range(0.03, 0.07)})
		return
	if _arrived:
		return
	var trails := look == SkillDefinition.ProjectileLook.LIMB or look == SkillDefinition.ProjectileLook.JET \
		or (look == SkillDefinition.ProjectileLook.TRACER and element in [Damage.Type.FIRE, Damage.Type.ICE, Damage.Type.ACID, Damage.Type.POISON])
	if not trails:
		return
	var fall := Vector2(0.0, 60.0)
	match element:
		Damage.Type.FIRE:
			fall = Vector2(0.0, -70.0)
		Damage.Type.ICE:
			fall = Vector2(0.0, 25.0)
	for i in (3 if look == SkillDefinition.ProjectileLook.JET else 1):
		_bits.append({"p": at + Vector2(_rng.randf_range(-6.0, 6.0), _rng.randf_range(-6.0, 6.0)),
			"v": fall + Vector2(_rng.randf_range(-25.0, 25.0), 0.0), "born": _clock, "r": Grid.TILE_SIZE * _rng.randf_range(0.015, 0.03)})


func _trail_seconds() -> float:
	return STREAK_TRAIL_SECONDS if style == SkillDefinition.ProjectileStyle.STREAK else TRAIL_SECONDS


func _draw():
	if art != null:
		_draw_area()
		return
	match style:
		SkillDefinition.ProjectileStyle.BEAM:
			_draw_beam()
			_draw_area()
			return
		SkillDefinition.ProjectileStyle.SPRAY:
			_draw_spray()
			_draw_area()
			return
	var orb := Grid.TILE_SIZE * ORB_TILES * (1.7 if look == SkillDefinition.ProjectileLook.GREAT_ORB else 1.0)
	var reach := _trail_seconds()
	var tint := _colour_now()
	var fading := 1.0 - clampf(_burst_clock / MISS_SECONDS, 0.0, 1.0) if _verdict == Verdict.MISSED and _settled else 1.0
	# A shadow along the ground under something thrown, for how high it is.
	if style == SkillDefinition.ProjectileStyle.ARC and not _arrived:
		var t := minf(_clock / _seconds, 1.0)
		var ground := from.lerp(_end(), t)
		draw_set_transform(ground, 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, orb * 0.9, Color(0, 0, 0, 0.28))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# The trail: a glow, and a brighter core inside it, each narrowing and
	# fading towards its tail - thin behind a tracer, none behind a chain.
	var thin := 0.45 if look in [SkillDefinition.ProjectileLook.TRACER, SkillDefinition.ProjectileLook.TWIN_TRACER,
		SkillDefinition.ProjectileLook.DART, SkillDefinition.ProjectileLook.NAIL] else 1.0
	if look != SkillDefinition.ProjectileLook.CHAIN and look != SkillDefinition.ProjectileLook.SWIRL \
			and look != SkillDefinition.ProjectileLook.VACUUM:
		for i in range(1, _trail.size()):
			var age: float = _clock - _trail[i][1]
			var fresh := clampf(1.0 - age / reach, 0.0, 1.0) * fading
			var a: Vector2 = _trail[i - 1][0]
			var b: Vector2 = _trail[i][0]
			draw_line(a, b, Color(tint, 0.22 * fresh), orb * 2.6 * fresh * thin + 1.0)
			draw_line(a, b, Color(tint.lerp(Color.WHITE, 0.35), 0.85 * fresh), orb * 1.1 * fresh * thin + 1.0)
	_draw_bits()
	var flying := not _arrived or (_verdict == Verdict.MISSED and _settled and fading > 0.0)
	if look == SkillDefinition.ProjectileLook.CHAIN:
		_draw_chain()
	elif flying:
		var head: Vector2 = _trail.back()[0]
		var going: Vector2 = head - (_trail[_trail.size() - 2][0] if _trail.size() > 1 else from)
		var angle := going.angle() if going.length() > 0.01 else (to - from).angle()
		if texture != null:
			var size := texture.get_size()
			draw_set_transform(head, angle, Vector2.ONE)
			draw_texture(texture, -size / 2.0, Color(1, 1, 1, fading))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			_draw_head(head, angle, orb, tint, fading)
	# Raised mid-flight: a flare where it changes colour.
	if colour_from.a > 0.0 and not _arrived:
		var flare := (_clock - _seconds * 0.5) / 0.12
		if flare >= 0.0 and flare < 1.0:
			var head: Vector2 = _trail.back()[0]
			draw_circle(head, orb * (2.0 + 3.0 * flare), Color(1, 1, 1, 0.7 * (1.0 - flare)))
			draw_arc(head, orb * (2.5 + 4.0 * flare), 0.0, TAU, 24, Color(colour, 0.9 * (1.0 - flare)), 3.0)
	_draw_area()


## What is flying, at `head`, turned `angle` - its Projectile Look.
func _draw_head(head: Vector2, angle: float, orb: float, tint: Color, fading: float):
	var tile := float(Grid.TILE_SIZE)
	var along := Vector2.from_angle(angle)
	var across := along.orthogonal()
	match look:
		SkillDefinition.ProjectileLook.TRACER:
			draw_line(head - along * tile * 0.45, head, Color(tint, 0.5 * fading), orb * 0.9)
			draw_line(head - along * tile * 0.4, head, Color(1, 1, 1, 0.95 * fading), orb * 0.35)
		SkillDefinition.ProjectileLook.TWIN_TRACER:
			var t := minf(_clock / _seconds, 1.0)
			for k in 2:
				var sway := across * sin(t * TAU * 2.0 + PI * k) * tile * 0.1
				var shade := tint if k == 0 else colour_b
				draw_line(head + sway - along * tile * 0.35, head + sway, Color(shade, 0.9 * fading), orb * 0.45)
				draw_circle(head + sway, orb * 0.35, Color(1, 1, 1, fading))
		SkillDefinition.ProjectileLook.DART:
			draw_line(head - along * tile * 0.22, head, Color(0.55, 0.42, 0.3, fading), 4.0)
			draw_colored_polygon(PackedVector2Array([head + along * tile * 0.07, head + across * tile * 0.03, head - across * tile * 0.03]),
				Color(tint.lerp(Color(0.8, 0.8, 0.8), 0.3), fading))
			for side in [-1.0, 1.0]:
				draw_line(head - along * tile * 0.2, head - along * tile * 0.27 + across * tile * 0.05 * side, Color(tint, fading), 3.0)
		SkillDefinition.ProjectileLook.ROCK, SkillDefinition.ProjectileLook.NAIL, SkillDefinition.ProjectileLook.LIMB:
			var turn := _clock * (22.0 if look == SkillDefinition.ProjectileLook.NAIL else 9.0)
			match look:
				SkillDefinition.ProjectileLook.ROCK:
					var rock := PackedVector2Array()
					for i in 7:
						rock.append(head + Vector2.from_angle(turn + TAU * i / 7.0) * orb * (1.3 + 0.35 * sin(i * 2.3)))
					draw_colored_polygon(rock, Color(0.5, 0.4, 0.3, fading))
					var outline := rock.duplicate()
					outline.append(rock[0])
					draw_polyline(outline, Color(0.3, 0.22, 0.15, fading), 2.0)
				SkillDefinition.ProjectileLook.NAIL:
					var spin := Vector2.from_angle(turn)
					draw_line(head - spin * tile * 0.13, head + spin * tile * 0.13, Color(0.75, 0.78, 0.82, fading), 5.0)
					draw_line(head - spin * tile * 0.13 - spin.orthogonal() * tile * 0.04, head - spin * tile * 0.13 + spin.orthogonal() * tile * 0.04,
						Color(0.6, 0.62, 0.66, fading), 6.0)
				SkillDefinition.ProjectileLook.LIMB:
					var spin := Vector2.from_angle(turn)
					draw_line(head - spin * tile * 0.2, head + spin * tile * 0.2, Color(0.4, 0.25, 0.15, fading), 12.0)
					for i in 3:
						draw_circle(head + spin * tile * (0.1 * i - 0.05) + Vector2(0, -6), orb * (0.7 - 0.15 * i), Color(1.0, 0.6 + 0.12 * i, 0.2, 0.8 * fading))
		SkillDefinition.ProjectileLook.SWIRL, SkillDefinition.ProjectileLook.VACUUM:
			var inward := look == SkillDefinition.ProjectileLook.VACUUM
			for i in 3:
				var cycle := fmod(_clock * 3.0 + float(i) / 3.0, 1.0)
				var radius := orb * (3.0 - 2.4 * cycle if inward else 0.8 + 2.4 * cycle)
				var start := _clock * 10.0 + TAU * float(i) / 3.0
				draw_arc(head, radius, start, start + 1.8, 14, Color(tint.lerp(Color.WHITE, 0.4), 0.9 * fading * (1.0 - cycle if not inward else cycle)), 4.0)
			draw_circle(head, orb * 0.4, Color(1, 1, 1, 0.8 * fading))
		SkillDefinition.ProjectileLook.CODE:
			draw_set_transform(head, _clock * 2.0, Vector2.ONE)
			draw_rect(Rect2(Vector2(-orb, -orb), Vector2(orb, orb) * 2.0), Color(0.05, 0.2, 0.1, 0.8 * fading))
			draw_rect(Rect2(Vector2(-orb, -orb), Vector2(orb, orb) * 2.0), Color(0.35, 1.0, 0.5, fading), false, 3.0)
			draw_line(Vector2(-orb * 0.5, -orb * 0.5), Vector2(-orb * 0.5, orb * 0.5), Color(0.35, 1.0, 0.5, fading), 3.0)
			draw_arc(Vector2(orb * 0.35, 0.0), orb * 0.35, 0.0, TAU, 10, Color(0.35, 1.0, 0.5, fading), 3.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		SkillDefinition.ProjectileLook.ITEM:
			draw_circle(head, orb * 1.2, Color(0.6, 0.42, 0.22, fading))
			draw_line(head + Vector2(-orb * 0.6, -orb * 0.9), head + Vector2(orb * 0.6, -orb * 0.9), Color(0.85, 0.7, 0.4, fading), 4.0)
		SkillDefinition.ProjectileLook.DROPLETS:
			for k in 3:
				var spot := head + across * (float(k) - 1.0) * tile * 0.12 - along * tile * 0.05 * absf(float(k) - 1.0)
				draw_circle(spot, orb * 0.55, Color(tint.lerp(Color.WHITE, 0.25), fading))
				draw_colored_polygon(PackedVector2Array([spot - along * orb * 1.4, spot + across * orb * 0.5, spot - across * orb * 0.5]),
					Color(tint.lerp(Color.WHITE, 0.25), fading))
		SkillDefinition.ProjectileLook.CANDLE:
			var flicker := 1.0 + 0.15 * sin(_clock * 30.0)
			var up := Vector2(0, -1)
			draw_colored_polygon(PackedVector2Array([head + up * orb * 2.2 * flicker, head + Vector2(orb * 0.8, 0), head + Vector2(0, orb * 0.8),
				head + Vector2(-orb * 0.8, 0)]), Color(1.0, 0.6, 0.15, 0.9 * fading))
			draw_circle(head + Vector2(0, -orb * 0.2), orb * 0.45, Color(1.0, 0.95, 0.7, fading))
		SkillDefinition.ProjectileLook.BUBBLE:
			var box := Rect2(head - Vector2(orb * 2.2, orb * 1.6), Vector2(orb * 4.4, orb * 2.8))
			draw_rect(box, Color(1, 1, 1, 0.92 * fading))
			draw_colored_polygon(PackedVector2Array([box.position + Vector2(orb * 0.8, box.size.y), box.position + Vector2(orb * 1.8, box.size.y),
				box.position + Vector2(orb * 0.4, box.size.y + orb * 1.0)]), Color(1, 1, 1, 0.92 * fading))
			var ink := Color(0.25, 0.2, 0.1, fading)
			var middle := box.get_center()
			draw_line(middle + Vector2(-orb * 1.2, -orb * 0.5), middle + Vector2(orb * 1.2, -orb * 0.5), ink, 3.0)
			draw_line(middle + Vector2(0, -orb * 0.9), middle + Vector2(0, orb * 0.7), ink, 3.0)
			for side in [-1.0, 1.0]:
				draw_arc(middle + Vector2(orb * 1.0 * side, orb * 0.05), orb * 0.4, 0.0, PI, 8, ink, 3.0)
		SkillDefinition.ProjectileLook.JET:
			draw_circle(head, orb * 1.3, Color(1.0, 0.75, 0.3, 0.7 * fading))
			draw_circle(head, orb * 0.6, Color(1, 1, 0.85, fading))
		_:
			draw_circle(head, orb * 2.2, Color(tint, 0.22 * fading))
			draw_circle(head, orb * 1.4, Color(tint, 0.55 * fading))
			var core := orb * (0.85 + 0.25 * sin(_clock * 40.0) if look == SkillDefinition.ProjectileLook.GREAT_ORB else 1.0)
			draw_circle(head, core, Color(tint.lerp(Color.WHITE, 0.25), fading))
			draw_circle(head, core * 0.5, Color(1, 1, 1, 0.95 * fading))


## A chain out from its user to where it is now - and, landed, drawn back.
func _draw_chain():
	var head: Vector2 = _trail.back()[0] if not _arrived else _end()
	if _arrived:
		head = _end().lerp(from, minf(_burst_clock / 0.18, 1.0))
	var length := from.distance_to(head)
	if length < 4.0:
		return
	var along := (head - from) / length
	var links := int(length / 16.0)
	for i in links:
		var at := from + along * (16.0 * i + 8.0)
		draw_set_transform(at, along.angle() + (PI / 2.0 if i % 2 else 0.0), Vector2(1.0, 0.55))
		draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 10, Color(0.72, 0.74, 0.78), 3.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_colored_polygon(PackedVector2Array([head + along * 14.0, head + along.orthogonal() * 9.0, head - along.orthogonal() * 9.0]),
		Color(0.8, 0.82, 0.86))


## What it leaves behind and pours out.
func _draw_bits():
	for bit in _bits:
		var age: float = _clock - bit.born
		var at: Vector2 = bit.p + bit.v * age
		var share := clampf(age / 0.5, 0.0, 1.0)
		var tint := _colour_now()
		if look == SkillDefinition.ProjectileLook.LIMB or look == SkillDefinition.ProjectileLook.JET or element == Damage.Type.FIRE:
			tint = Color(1.0, 0.85, 0.4).lerp(Color(1.0, 0.3, 0.05), share)
		draw_circle(at, bit.r * (1.0 - share * 0.5), Color(tint, 0.9 * (1.0 - share)))


## A beam: a line of light from its user to where it reaches, holding a moment
## and fading, a flare where it leaves them.
func _draw_beam():
	var end := _end()
	var reached := minf(_clock / BEAM_REACH_SECONDS, 1.0)
	var fade := 1.0
	if _arrived:
		fade = 1.0 - clampf((_burst_clock - BEAM_HOLD_SECONDS) / BEAM_FADE_SECONDS, 0.0, 1.0)
	var tip := from.lerp(end, reached)
	var pulse := 1.0 + 0.2 * sin(_clock * 40.0)
	var width := Grid.TILE_SIZE * ORB_TILES
	draw_line(from, tip, Color(colour, 0.3 * fade), width * 2.6 * pulse)
	draw_line(from, tip, Color(colour.lerp(Color.WHITE, 0.4), 0.8 * fade), width * 1.1 * pulse)
	draw_line(from, tip, Color(1, 1, 1, 0.95 * fade), width * 0.4)
	draw_circle(from, width * 1.6 * pulse, Color(colour, 0.5 * fade))
	draw_colored_polygon(MoveFeel._star(from, 4, width * 3.2 * pulse, width * 0.35, _clock), Color(1, 1, 1, 0.9 * fade))


## A spray: what it pours out, filling its cone - or, for a roar, rings going out.
func _draw_spray():
	if roar:
		var angle := (to - from).angle()
		var length := from.distance_to(to)
		for i in 4:
			var own := fmod(_clock / 0.45 + float(i) * 0.25, 1.0)
			if _clock > SPRAY_SECONDS and own < 0.3:
				continue
			draw_arc(from, length * own, angle - 0.6, angle + 0.6, 20, Color(colour.lerp(Color.WHITE, 0.6), 0.8 * (1.0 - own)), 8.0 * (1.0 - own) + 2.0)
		return
	for bit in _bits:
		var age: float = _clock - bit.born
		var share := clampf(age / 0.32, 0.0, 1.0)
		var at: Vector2 = bit.p + bit.v * age
		var tint := colour.lerp(Color.WHITE, 0.4 * (1.0 - share))
		draw_circle(at, bit.r * (0.6 + 1.2 * share), Color(tint, 0.75 * (1.0 - share)))


## The last moment anything of its area lights up.
func _last_lit() -> float:
	var last := 0.0
	for when in _lit_at:
		last = maxf(last, when)
	return last


## Its area's tiles, each lit a moment and fading (_lit_at).
func _draw_area():
	var half := Vector2.ONE * Grid.TILE_SIZE * 0.5
	for i in area_points.size():
		var lit := (_clock - float(_lit_at[i])) / BURST_SECONDS
		if lit < 0.0 or lit >= 1.0:
			continue
		var square := Rect2(area_points[i] - half, half * 2.0)
		draw_rect(square, Color(colour, 0.32 * (1.0 - lit)))
		draw_rect(square, Color(colour.lerp(Color.WHITE, 0.3), 0.5 * (1.0 - lit)), false, 2.0)
