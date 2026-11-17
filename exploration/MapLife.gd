@tool
@icon("res://art/editor_icons/map_life.svg")
class_name MapLife
extends Node2D
## Life about the place (the proposals of 2026-11-16, section 11; the designer, 2026-11-16: "add all"). Placed on a map, or on a
## terrain so its fights have it too, over a patch of ground (Size Tiles, right and down from its tile):
##
## - **Birds** pecking about, that take off as the party comes near, away from them, and come back once they have gone.
## - **Rats** scurrying about, that bolt from the party and come back later.
## - **A cat** that watches the party from where it sits (on a wall top, drawn up there), and leaps off if they come too near.
## - **Grass** that bends with the wind, away from whoever walks through it, and away from a blast beside it (`blast_at`).
## - **Chatter**: somebody (Speaker, or this node itself) says one of its Lines in a bubble now and then while the party is near.
##
## Only to look at: nothing stops anybody, nothing is seen or heard by a guard, nothing rolls on a fight's dice. Drawn in code until
## the artist's Picture, or the slot art/fx/<kind>.png, is there. Every number PROPOSAL; headless it thinks but draws nothing.

enum Kind { BIRDS, RATS, CAT, GRASS, CHATTER }

@export var kind: Kind = Kind.BIRDS : set = _set_kind
@export var size_tiles: Vector2i = Vector2i(3, 2) : set = _set_size_tiles
## How many birds, rats or tufts.
@export_range(1, 40) var count: int = 5
## The artist's picture, in place of the slot art/fx/<kind>.png; empty, drawn in code.
@export var picture: Texture2D
@export_group("Chatter")
## What they say, one at a time, in turn.
@export var lines: PackedStringArray = PackedStringArray()
## Who says it; empty, this node itself.
@export var speaker: NodePath
@export_group("")

const GROUP := &"map_life"
## How near the party comes before birds take off, rats bolt and the cat leaps; how far off they must be for it to come back, and
## after how long.
const FLEE_TILES := {Kind.BIRDS: 2.6, Kind.RATS: 2.2, Kind.CAT: 1.5}
const BACK_FROM_TILES := 5.0
const BACK_SECONDS := {Kind.BIRDS: 18.0, Kind.RATS: 12.0, Kind.CAT: 15.0}
const FLY_SPEED := 3.2
const RAT_SPEED := 0.9
const BOLT_SPEED := 3.4
## Grass: how far it leans with the wind and from somebody in it, and how near they must be.
const GRASS_WIND := 0.45
const GRASS_PUSHED := 0.75
const GRASS_NEAR_TILES := 0.7
## How long a blast's push lasts.
const BLAST_SECONDS := 0.9
## Chatter: once every so many seconds, from so near.
const CHATTER_EVERY := Vector2(9.0, 17.0)
const CHATTER_TILES := 6.0

static var plays_headless := false

var _members: Array = []
var _clock := 0.0
var _chatter_in := 0.0
var _next_line := 0
## What a blast left: a push away from it, easing off.
var _blast := Vector2.ZERO
var _rng := RandomNumberGenerator.new()


static func shown() -> bool:
	return plays_headless or DisplayServer.get_name() != "headless"


func _set_kind(value: Kind):
	kind = value
	_members.clear()
	queue_redraw()


func _set_size_tiles(value: Vector2i):
	size_tiles = Vector2i(maxi(value.x, 1), maxi(value.y, 1))
	_members.clear()
	queue_redraw()


func _ready():
	if not Engine.is_editor_hint():
		add_to_group(GROUP)
		z_as_relative = false
		z_index = ExplorationParty.PARTY_Z_BOTTOM - 1
		_rng.seed = hash([name, global_position])
		_chatter_in = _rng.randf_range(CHATTER_EVERY.x * 0.4, CHATTER_EVERY.y)
	queue_redraw()


## The patch of ground it is about, in its own pixels: from its tile's north-west corner.
func ground() -> Rect2:
	var tile := float(Grid.TILE_SIZE)
	return Rect2(Vector2(-tile, -tile) * 0.5, Vector2(size_tiles) * tile)


## Everybody of the party in its scene, where they stand.
func _party() -> Array:
	var at := []
	for one in get_tree().get_nodes_in_group(Depth.PARTY):
		if is_instance_valid(one) and one is Node2D and one.is_inside_tree() and Depth.same_scene(one, self):
			at.append(one.global_position)
	return at


## How near the nearest of the party is to `point` (world pixels), and where they are.
func _nearest(point: Vector2, party: Array) -> Dictionary:
	var best := {"far": INF, "at": point}
	for at in party:
		var far: float = point.distance_to(at)
		if far < best.far:
			best = {"far": far, "at": at}
	return best


## The map under it: the TileMap beside it in its scene, or the one the depth is drawn for.
func _tile_map() -> TileMap:
	var beside = get_parent().get_node_or_null("TileMap") if get_parent() != null else null
	if beside is TileMap:
		return beside
	if DepthView.showing != null and is_instance_valid(DepthView.showing):
		return DepthView.showing._tile_map
	return null


## A spot in the patch, on bare floor if the map says where that is (birds, rats and grass keep off walls and barrels).
func _floor_point() -> Vector2:
	var patch := ground()
	var tile_map := _tile_map()
	var spot := patch.position + Vector2(_rng.randf(), _rng.randf()) * patch.size
	if tile_map == null:
		return spot
	for i in 16:
		var tile: Vector2i = tile_map.local_to_map(tile_map.to_local(to_global(spot)))
		if Depth.kind_at(tile_map, tile) == Depth.Kind.FLOOR:
			return spot
		spot = patch.position + Vector2(_rng.randf(), _rng.randf()) * patch.size
	return spot


func _make_members():
	_members.clear()
	var many: int = 1 if kind == Kind.CAT or kind == Kind.CHATTER else count
	for i in many:
		var at := Vector2.ZERO if kind == Kind.CAT or kind == Kind.CHATTER else _floor_point()
		_members.append({"at": at, "home": at, "state": &"here", "time": _rng.randf() * 3.0, "facing": 1.0 if _rng.randf() < 0.5 else -1.0,
			"up": 0.0, "alpha": 1.0, "way": Vector2.ZERO, "bend": 0.0, "hop": 0.0})


func _process(delta: float):
	if Engine.is_editor_hint():
		return
	_clock += delta
	if _members.is_empty():
		_make_members()
	var party := _party()
	match kind:
		Kind.BIRDS, Kind.RATS, Kind.CAT:
			_creatures(delta, party)
		Kind.GRASS:
			_grass(delta, party)
		Kind.CHATTER:
			_chatter(delta, party)
	_blast = _blast.move_toward(Vector2.ZERO, delta / BLAST_SECONDS)
	if shown():
		queue_redraw()


## Birds, rats and the cat: here, then off and away when the party comes near, then back once they have gone a while.
func _creatures(delta: float, party: Array):
	var tile := float(Grid.TILE_SIZE)
	var flee: float = FLEE_TILES.get(kind, 2.0) * tile
	for one in _members:
		var world: Vector2 = to_global(one.at)
		var near := _nearest(world, party)
		match one.state:
			&"here":
				one.alpha = move_toward(one.alpha, 1.0, delta * 2.0)
				one.time -= delta
				if kind == Kind.CAT:
					if not party.is_empty():
						one.facing = signf(near.at.x - world.x) if absf(near.at.x - world.x) > 4.0 else one.facing
				elif one.time <= 0.0:
					# A peck and a hop, or a scurry to another spot in the patch.
					one.time = _rng.randf_range(0.6, 2.6)
					if kind == Kind.RATS:
						one.way = _floor_point() - one.at
					else:
						one.hop = 1.0
						one.facing = -one.facing if _rng.randf() < 0.4 else one.facing
				if kind == Kind.RATS and one.way.length() > 1.0:
					var step: Vector2 = one.way.limit_length(RAT_SPEED * tile * delta)
					one.at += step
					one.way -= step
					one.facing = signf(step.x) if absf(step.x) > 0.01 else one.facing
				one.hop = move_toward(one.hop, 0.0, delta * 5.0)
				if near.far < flee:
					one.state = &"off"
					one.way = (world - near.at).normalized() if world != near.at else Vector2.RIGHT
					one.time = BACK_SECONDS.get(kind, 15.0)
			&"off":
				if kind == Kind.BIRDS:
					one.at += (one.way * FLY_SPEED + Vector2(0.0, -0.6)) * tile * delta
					one.up = minf(one.up + delta * tile * 1.4, tile * 2.5)
					one.alpha = move_toward(one.alpha, 0.0, delta * 0.8)
				elif kind == Kind.RATS:
					one.at += one.way * BOLT_SPEED * tile * delta
					one.alpha = move_toward(one.alpha, 0.0, delta * 1.6)
				else:
					one.up = minf(one.up + delta * tile * 2.0, tile * 0.6)
					one.alpha = move_toward(one.alpha, 0.0, delta * 3.0)
				one.facing = signf(one.way.x) if absf(one.way.x) > 0.01 else one.facing
				one.time -= delta
				if one.time <= 0.0 and near.far > BACK_FROM_TILES * tile:
					# Back where it was, or somewhere else in the patch.
					one.at = one.home if kind == Kind.CAT else _floor_point()
					one.up = 0.0
					one.state = &"here"
					one.time = _rng.randf_range(0.5, 2.0)


## Grass: each tuft bends with the wind, away from anybody in it, and away from a blast.
func _grass(delta: float, party: Array):
	var tile := float(Grid.TILE_SIZE)
	var wind: Vector2 = CombatantSprite.wind_blows
	for one in _members:
		var world: Vector2 = to_global(one.at)
		var aim: float = wind.x * GRASS_WIND + sin(_clock * 2.1 + one.at.x * 0.03) * 0.06 * (0.3 + wind.length())
		var near := _nearest(world, party)
		if near.far < GRASS_NEAR_TILES * tile:
			aim += signf(world.x - near.at.x) * GRASS_PUSHED * (1.0 - near.far / (GRASS_NEAR_TILES * tile))
		aim += _blast.x * 0.9
		one.bend = lerpf(one.bend, clampf(aim, -1.1, 1.1), 1.0 - exp(-8.0 * delta))


## Chatter: now and then, with the party near and nobody else talking, the next of its lines in a bubble.
func _chatter(delta: float, party: Array):
	if lines.is_empty():
		return
	_chatter_in -= delta
	if _chatter_in > 0.0:
		return
	_chatter_in = _rng.randf_range(CHATTER_EVERY.x, CHATTER_EVERY.y)
	var who: Node2D = get_node_or_null(speaker) as Node2D if not speaker.is_empty() else self
	if who == null or Coop.talking():
		return
	if _nearest(who.global_position, party).far > CHATTER_TILES * float(Grid.TILE_SIZE):
		return
	say_next(who)


## Says the next of its lines over `who` (a suite calls it too).
func say_next(who: Node2D = null):
	if lines.is_empty():
		return
	if who == null:
		who = get_node_or_null(speaker) as Node2D if not speaker.is_empty() else self
	SpeechBubbles.say_over(get_tree(), who, lines[_next_line % lines.size()])
	_next_line += 1


## A blast went off at `at` (world pixels) reaching `radius_tiles`: the grass there bends away from it, and the banners are pushed.
static func blast_at(tree: SceneTree, at: Vector2, radius_tiles: float):
	if tree == null:
		return
	var reach := (radius_tiles + 1.0) * float(Grid.TILE_SIZE)
	for life in tree.get_nodes_in_group(GROUP):
		if life is MapLife and life.kind == Kind.GRASS:
			var middle: Vector2 = life.to_global(life.ground().get_center())
			if middle.distance_to(at) < reach + life.ground().size.length() * 0.5:
				life._blast = (middle - at).normalized() * clampf(1.0 - middle.distance_to(at) / (reach * 2.0), 0.3, 1.0)
	for banner in tree.get_nodes_in_group(WindBanner.GROUP):
		if banner is WindBanner and banner.global_position.distance_to(at) < reach:
			banner.push((banner.global_position - at).normalized() * 1.2)


## Where each of them is now, for a suite: [{at, state, alpha, bend}].
func members() -> Array:
	return _members.duplicate(true)


## --- What it looks like ---

func _picture() -> Texture2D:
	if picture != null:
		return picture
	var path := "res://art/fx/%s.png" % String(Kind.keys()[kind]).to_lower()
	return load(path) if ResourceLoader.exists(path) else null


func _draw():
	var tile := float(Grid.TILE_SIZE)
	if Engine.is_editor_hint():
		draw_rect(ground(), Color(0.55, 0.9, 0.55, 0.7), false, 4.0)
		draw_string(ThemeDB.fallback_font, ground().position + Vector2(8, 28), String(Kind.keys()[kind]).capitalize(), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.7, 1.0, 0.7))
		return
	if not shown():
		return
	var art := _picture()
	var lit := LightView.lit_colour_at(global_position)
	for one in _members:
		var at: Vector2 = one.at
		var colour := Color(lit, float(one.alpha))
		match kind:
			Kind.BIRDS:
				_draw_bird(at, one, colour, art, tile)
			Kind.RATS:
				_draw_rat(at, one, colour, art, tile)
			Kind.CAT:
				_draw_cat(at, one, colour, art, tile)
			Kind.GRASS:
				_draw_tuft(at, one, lit, art, tile)


func _draw_bird(at: Vector2, one: Dictionary, colour: Color, art: Texture2D, tile: float):
	var up: float = one.up
	if up > 2.0:
		# Its shadow on the ground below it.
		draw_circle(at, tile * 0.045, Color(0, 0, 0, 0.25 * colour.a))
	var body := at - Vector2(0.0, up + tile * 0.04 + one.hop * tile * 0.05)
	if art != null:
		draw_set_transform(body, 0.0, Vector2(float(one.facing), 1.0))
		draw_texture(art, -art.get_size() * 0.5, colour)
		draw_set_transform(Vector2.ZERO)
		return
	var ink := Color(colour.r * 0.22, colour.g * 0.2, colour.b * 0.22, colour.a)
	if one.state == &"off":
		var flap := sin(_clock * 22.0) * tile * 0.05
		draw_polyline(PackedVector2Array([body + Vector2(-tile * 0.09, -flap), body, body + Vector2(tile * 0.09, -flap)]), ink, 5.0)
	else:
		draw_circle(body, tile * 0.045, ink)
		draw_circle(body + Vector2(tile * 0.04 * float(one.facing), -tile * 0.03), tile * 0.026, ink)


func _draw_rat(at: Vector2, one: Dictionary, colour: Color, art: Texture2D, tile: float):
	if art != null:
		draw_set_transform(at, 0.0, Vector2(float(one.facing), 1.0))
		draw_texture(art, -art.get_size() * Vector2(0.5, 1.0), colour)
		draw_set_transform(Vector2.ZERO)
		return
	var fur := Color(colour.r * 0.42, colour.g * 0.4, colour.b * 0.44, colour.a)
	var facing: float = one.facing
	draw_set_transform(at, 0.0, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, tile * 0.06, fur)
	draw_circle(Vector2(tile * 0.06 * facing, 0.0), tile * 0.035, fur)
	draw_set_transform(Vector2.ZERO)
	draw_line(at - Vector2(tile * 0.05 * facing, 0.0), at - Vector2(tile * 0.15 * facing, -tile * 0.02), Color(fur, colour.a * 0.8), 3.0)


func _draw_cat(at: Vector2, one: Dictionary, colour: Color, art: Texture2D, tile: float):
	# Up on whatever it sits on: a wall top is drawn lifted (Depth), so it sits there too.
	var lift := 0.0
	if DepthView.showing != null and is_instance_valid(DepthView.showing):
		lift = DepthView.showing.height_at(Vector2i((global_position / tile).floor()))
	var seat := at - Vector2(0.0, lift + float(one.up))
	if art != null:
		draw_set_transform(seat, 0.0, Vector2(float(one.facing), 1.0))
		draw_texture(art, -art.get_size() * Vector2(0.5, 1.0), colour)
		draw_set_transform(Vector2.ZERO)
		return
	var fur := Color(colour.r * 0.2, colour.g * 0.18, colour.b * 0.2, colour.a)
	var facing: float = one.facing
	draw_set_transform(seat - Vector2(0.0, tile * 0.09), 0.0, Vector2(0.8, 1.0))
	draw_circle(Vector2.ZERO, tile * 0.09, fur)
	draw_set_transform(Vector2.ZERO)
	var head := seat - Vector2(-tile * 0.03 * facing, tile * 0.21)
	draw_circle(head, tile * 0.055, fur)
	for side in [-1.0, 1.0]:
		var ear := head + Vector2(side * tile * 0.035, -tile * 0.04)
		draw_colored_polygon(PackedVector2Array([ear + Vector2(-tile * 0.02, 0.0), ear + Vector2(tile * 0.02, 0.0), ear + Vector2(side * tile * 0.008, -tile * 0.05)]), fur)
	var sway := sin(_clock * 1.7) * tile * 0.03
	draw_polyline(PackedVector2Array([seat + Vector2(-tile * 0.07 * facing, -tile * 0.02), seat + Vector2(-tile * 0.15 * facing, -tile * 0.04 + sway),
		seat + Vector2(-tile * 0.13 * facing, -tile * 0.14 + sway)]), fur, 5.0)


func _draw_tuft(at: Vector2, one: Dictionary, lit: Color, art: Texture2D, tile: float):
	var bend: float = one.bend
	if art != null:
		draw_set_transform(at, bend * 0.5, Vector2.ONE)
		draw_texture(art, -art.get_size() * Vector2(0.5, 1.0), lit)
		draw_set_transform(Vector2.ZERO)
		return
	var green := Color(0.32, 0.5, 0.24) * lit
	for blade in 5:
		var spread := (float(blade) - 2.0) * tile * 0.025
		var height := tile * (0.14 + 0.04 * sin(float(blade) * 1.7 + at.x))
		var tip := at + Vector2(spread + bend * height * 0.8, -height * (1.0 - absf(bend) * 0.25))
		var middle := at + Vector2(spread * 0.6 + bend * height * 0.25, -height * 0.5)
		draw_polyline(PackedVector2Array([at + Vector2(spread * 0.4, 0.0), middle, tip]), Color(green, 0.95).lightened(0.08 * float(blade % 2)), 4.0)
