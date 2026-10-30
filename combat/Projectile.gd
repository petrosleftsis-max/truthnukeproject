extends Node2D
class_name Projectile
## A move seen travelling from whoever used it to where it was aimed, so that
## it is clear on the board who does what (the designer, 2026-10-30): an orb
## in the move's colour - its element's (Damage.type_colour), a mend's green -
## with a fading trail behind it, and a burst where it lands. A move with an
## area lights the tiles it lands on: a line's and a cone's as it goes past
## them, an area's going out from where it lands. How it goes is the move's Projectile Style;
## Automatic is worked out from the move (style_for): nothing for a melee blow
## or one at its user's own tile, a streak the length of a line, a fan for a
## cone, an arc for anything that goes over what is in the way (Respects
## Blocking off - thrown, lobbed), and a straight bolt for the rest.
##
## The blow lands as it arrives: Combat awaits fly() before resolving anything.
## Purely to look at - nothing in it rolls, nothing waits on anything but its
## own clock, and it changes nothing in the fight, so a fight played on two
## machines (Net) comes out the same with it. Its clock is the game's, so a fast
## enemy turn, or a fight being caught up with, plays it fast too.
##
## A slot to fill (the designer's placeholder-with-slot way): a move's
## Projectile Texture flies in place of the orb, trail and all; its Projectile
## Scene in place of everything drawn here. Left empty, this stand-in is drawn.
##
## Headless - the test harness - it lands at once, unless plays_headless is set.

## Emitted as it arrives, once.
signal landed

## Set by a test that wants to see one fly with nobody watching.
static var plays_headless := false

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
## A mend's colour, and what a move that neither hurts nor mends goes in.
const MEND := Color("7ee08a")
const SPELLWORK := Color("c9b6ff")

var from := Vector2.ZERO
var to := Vector2.ZERO
var colour := Color.WHITE
var style: int = SkillDefinition.ProjectileStyle.BOLT
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

var _seconds := 0.3
var _clock := 0.0
var _arrived := false
var _burst_clock := 0.0
## Where it has been, and when: [position, time] - drawn as its trail.
var _trail: Array = []


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
		if effect != null and effect.type == EffectDefinition.EffectType.HEAL:
			return MEND
	var type := element if element >= 0 else int(skill.damage_type)
	if skill.deals_damage or type != Damage.Type.PHYSICAL:
		return Damage.type_colour(type)
	return SPELLWORK


## `skill`, used by `user` on `combat`'s board aimed at `aim` - over `tiles`,
## what it lands on - flown there, and waited for until it arrives. `following`
## is who it is aimed at, followed if they move meanwhile.
static func fly(combat: Combat, user: Dictionary, skill: SkillDefinition, aim: Vector2i, tiles: Array = [], following: Dictionary = {}) -> void:
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
		SkillDefinition.ProjectileStyle.STREAK:
			flights.append(_far_along(combat, start, aim, tiles))
		SkillDefinition.ProjectileStyle.FAN:
			flights.append_array(_fan_ends(combat, start, aim, tiles))
		_:
			var there := combat.get_combatant_at(aim) if following.is_empty() else following
			flights.append(combat.sprite_point(there) + combat.drawing_offset(there) if not there.is_empty() and there.has("position")
				else combat.sprite_point({}, aim))
			if following.is_empty() and not there.is_empty():
				following = there
	# The element it lands as - raised, for a cast an upgrade was spent on.
	var element := int(skill.damage_type)
	var thrown: Array = combat.elements_of(skill)
	if not thrown.is_empty():
		element = int(thrown[0])
	element = combat.effective_damage_type(user, element)
	# An area's tiles, lit as it lands - by the first of a fan, not all three.
	var lit := []
	if radius > 0 or how == SkillDefinition.ProjectileStyle.STREAK or how == SkillDefinition.ProjectileStyle.FAN:
		for tile in tiles:
			if typeof(tile) == TYPE_VECTOR2I:
				lit.append(combat.sprite_point({}, tile))
	var made := []
	for end in flights:
		var flying := Projectile.new()
		flying.from = start
		flying.to = end
		flying.style = how
		flying.colour = colour_for(skill, element)
		flying.texture = skill.projectile_texture
		flying.target = following if flights.size() == 1 else {}
		if not flying.target.is_empty():
			flying.target_offset = combat.drawing_offset(following)
		flying.burst_radius = Grid.TILE_SIZE * BURST_TILES
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
	# All of them in: the first to land is as good as any, they fly together.
	for flying in made:
		if is_instance_valid(flying) and not flying._arrived:
			await flying.landed


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
	var tiles := from.distance_to(to) / float(Grid.TILE_SIZE)
	_seconds = clampf(BASE_SECONDS + SECONDS_A_TILE * tiles, LEAST_SECONDS, MOST_SECONDS)
	if style == SkillDefinition.ProjectileStyle.ARC:
		_seconds *= ARC_SLOWER
	elif style == SkillDefinition.ProjectileStyle.STREAK:
		_seconds = STREAK_SECONDS
	position = Vector2.ZERO
	if art != null:
		add_child(art)
		art.position = from
	_trail.append([from, 0.0])
	# When each of its area's tiles lights: a line's and a cone's as it goes
	# past them, an area's going out from where it lands once it has.
	var length := maxf(from.distance_to(to), 1.0)
	var passes := style == SkillDefinition.ProjectileStyle.STREAK or style == SkillDefinition.ProjectileStyle.FAN
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


func _process(delta: float):
	if not _arrived:
		_clock += delta
		var t := minf(_clock / _seconds, 1.0)
		var at := _head(t)
		_trail.append([at, _clock])
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
	else:
		_burst_clock += delta
		_clock += delta
		if _burst_clock >= BURST_SECONDS + _trail_seconds() and _clock >= _last_lit() + BURST_SECONDS:
			queue_free()
	# The trail fades from behind.
	var reach := _trail_seconds()
	while _trail.size() > 2 and _clock - _trail[0][1] > reach:
		_trail.pop_front()
	queue_redraw()


func _trail_seconds() -> float:
	return STREAK_TRAIL_SECONDS if style == SkillDefinition.ProjectileStyle.STREAK else TRAIL_SECONDS


func _draw():
	if art != null:
		_draw_area()
		_draw_burst()
		return
	var orb := Grid.TILE_SIZE * ORB_TILES
	var reach := _trail_seconds()
	# A shadow along the ground under something thrown, for how high it is.
	if style == SkillDefinition.ProjectileStyle.ARC and not _arrived:
		var t := minf(_clock / _seconds, 1.0)
		var ground := from.lerp(_end(), t)
		draw_set_transform(ground, 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, orb * 0.9, Color(0, 0, 0, 0.28))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# The trail: a glow, and a brighter core inside it, each narrowing and
	# fading towards its tail.
	for i in range(1, _trail.size()):
		var age: float = _clock - _trail[i][1]
		var fresh := clampf(1.0 - age / reach, 0.0, 1.0)
		var a: Vector2 = _trail[i - 1][0]
		var b: Vector2 = _trail[i][0]
		draw_line(a, b, Color(colour, 0.22 * fresh), orb * 2.6 * fresh + 1.0)
		draw_line(a, b, Color(colour.lerp(Color.WHITE, 0.35), 0.85 * fresh), orb * 1.1 * fresh + 1.0)
	if not _arrived:
		var head: Vector2 = _trail.back()[0]
		if texture != null:
			var going: Vector2 = head - (_trail[_trail.size() - 2][0] if _trail.size() > 1 else from)
			var size := texture.get_size()
			draw_set_transform(head, going.angle() if going.length() > 0.01 else 0.0, Vector2.ONE)
			draw_texture(texture, -size / 2.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_circle(head, orb * 2.2, Color(colour, 0.22))
			draw_circle(head, orb * 1.4, Color(colour, 0.55))
			draw_circle(head, orb, colour.lerp(Color.WHITE, 0.25))
			draw_circle(head, orb * 0.5, Color(1, 1, 1, 0.95))
	_draw_area()
	_draw_burst()


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


## Where it landed: a flash, and a ring going out to the burst's size.
func _draw_burst():
	if not _arrived:
		return
	var at := _end()
	var t := clampf(_burst_clock / BURST_SECONDS, 0.0, 1.0)
	var ring := lerpf(burst_radius * 0.25, burst_radius, 1.0 - pow(1.0 - t, 3.0))
	draw_circle(at, ring * 0.8, Color(colour, 0.35 * (1.0 - t)))
	draw_arc(at, ring, 0.0, TAU, 40, Color(colour.lerp(Color.WHITE, 0.3), 0.9 * (1.0 - t)), 4.0 * (1.0 - t) + 1.0)
	if t < 0.35:
		draw_circle(at, Grid.TILE_SIZE * ORB_TILES * 2.0 * (1.0 - t / 0.35), Color(1, 1, 1, 0.9 * (1.0 - t / 0.35)))
