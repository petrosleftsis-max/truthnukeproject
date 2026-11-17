extends Node2D
class_name MapFeel
## The small things that move on a map (the proposals of 2026-11-16, sections 1, 3 and 5; the designer, 2026-11-17): a puff of
## dust where a dash skids to its end, the streak it leaves, smoke from a lamp put out, rubble thrown from a wall broken, a ring
## and a splash where something lands in water, what is picked up flying to the bag. What MoveFeel is to a fight, far smaller.
##
## Only to look at: nothing here is a rule, nothing is rolled on a fight's dice (it has a generator of its own, seeded from where
## it is), and headless nothing is made unless `plays_headless` (a suite). Every shape is a placeholder drawn in code; the
## pictures that may take their place are named where they are used (`RUBBLE_PICTURE`). All numbers PROPOSAL.

static var plays_headless := false
## How many were made, for a suite: kind -> count.
static var made := {}

## Rubble's own picture once the designer adds it (64 x 64, a handful of stones on nothing): until then, drawn stones.
const RUBBLE_PICTURE := "res://art/fx/rubble.png"

const SECONDS := {
	&"dust": 0.45, &"skid": 0.5, &"streak": 0.28, &"smoke": 1.1, &"rubble": 0.8, &"hang": 2.2, &"ring": 0.9, &"splash": 0.5,
	&"hop_dust": 0.4, &"leaf": 1.6, &"thrown": 0.4, &"dart": 0.12, &"skitter": 0.45,
}

var kind: StringName = &""
var seconds := 0.5
var toward := Vector2.RIGHT
var strength := 1.0
var colour := Color(0.78, 0.74, 0.66)
var reach := 0.0
var texture: Texture2D = null

var _clock := 0.0
var _rng := RandomNumberGenerator.new()
var _bits: Array = []


## How many times each sound was asked for, for a suite: slot -> count.
static var heard := {}


## Plays the SoundBank's `slot`, or its stand-in of the same name (PlaceholderSounds) while the slot is empty. Counted even
## headless, where nothing plays.
static func sound(slot: StringName, volume_db: float = -6.0, pitch: float = 1.0, at: Vector2 = Vector2.INF):
	heard[slot] = int(heard.get(slot, 0)) + 1
	if DisplayServer.get_name() == "headless":
		return
	var stream: AudioStream = GameSounds.stream(slot)
	if stream == null:
		stream = PlaceholderSounds.make(String(slot))
	# Somewhere in the world, heard from there (SoundFollows "Sound with a place"); else in the middle.
	var player = GameSounds._start_at(stream, at, volume_db) if at.is_finite() else GameSounds._start(stream, volume_db)
	if player != null:
		player.pitch_scale = pitch


## `icon` flying from `from` (a place on the screen) to `to`, rising first and shrinking as it goes, then `landed` is called:
## something picked up, on its way to the bag. On `host`'s own layer over the HUD.
static func fly_to_bag(host: Node, icon: Texture2D, from: Vector2, to: Vector2, landed: Callable = Callable()):
	made[&"pickup"] = int(made.get(&"pickup", 0)) + 1
	if host == null or not is_instance_valid(host) or not host.is_inside_tree() or not shown():
		if landed.is_valid():
			landed.call()
		return
	var layer := CanvasLayer.new()
	layer.layer = 30
	host.add_child(layer)
	var size := Vector2.ONE * 56.0
	var flier: Control
	if icon != null:
		var picture := TextureRect.new()
		picture.texture = icon
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		flier = picture
	else:
		var dot := ColorRect.new()
		dot.color = Color(0.95, 0.85, 0.4)
		flier = dot
	flier.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flier.size = size
	flier.pivot_offset = size * 0.5
	flier.position = from - size * 0.5
	layer.add_child(flier)
	var flight := flier.create_tween()
	# Up off where it lay, a breath, then away to the bag, smaller all the way.
	flight.tween_property(flier, "position", from - size * 0.5 + Vector2(0.0, -PICKUP_RISE), PICKUP_RISE_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	flight.tween_property(flier, "position", to - size * 0.5, PICKUP_FLY_SECONDS).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	flight.parallel().tween_property(flier, "scale", Vector2.ONE * 0.35, PICKUP_FLY_SECONDS).set_ease(Tween.EASE_IN)
	flight.tween_callback(func():
		if landed.is_valid():
			landed.call()
		layer.queue_free())


const PICKUP_RISE := 46.0
const PICKUP_RISE_SECONDS := 0.16
const PICKUP_FLY_SECONDS := 0.34


static func shown() -> bool:

	return plays_headless or DisplayServer.get_name() != "headless"


## Makes `kind` at `at` (a place in `parent`'s own space) and returns it, or null when nothing is shown.
static func spawn(parent: Node, kind: StringName, at: Vector2, settings: Dictionary = {}) -> MapFeel:
	made[kind] = int(made.get(kind, 0)) + 1
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree() or not shown():
		return null
	var feel := MapFeel.new()
	feel.kind = kind
	feel.seconds = float(SECONDS.get(kind, 0.5))
	for key in settings:
		feel.set(key, settings[key])
	feel.position = at
	feel.z_as_relative = false
	feel.z_index = int(settings.get("z", ExplorationParty.PARTY_Z_TOP + 1))
	parent.add_child(feel)
	return feel


func _ready():
	_rng.seed = hash(Vector2i(position)) + hash(kind)
	match kind:
		&"dust", &"hop_dust":
			_scatter(7, 0.5, 0.25, 0.7)
		&"skid":
			_scatter(12, 0.35, 0.5, 1.5)
		&"smoke":
			_scatter(6, 0.25, 0.15, 0.35)
		&"hang":
			_scatter(14, 1.0, 0.05, 0.2)
		&"rubble":
			_scatter(11, 0.6, 1.2, 3.2)
			if ResourceLoader.exists(RUBBLE_PICTURE):
				texture = load(RUBBLE_PICTURE)
		&"splash":
			_scatter(9, 0.9, 0.8, 1.8)
		&"leaf":
			_scatter(5, 1.0, 0.3, 0.8)


## `count` bits thrown about `toward` within `spread` of a half turn, between `slow` and `fast` tiles a second.
func _scatter(count: int, spread: float, slow: float, fast: float):
	for i in count:
		var way := toward.normalized().rotated(_rng.randf_range(-PI, PI) * spread) if toward != Vector2.ZERO else Vector2.RIGHT.rotated(_rng.randf() * TAU)
		_bits.append({
			"way": way * Grid.tiles(_rng.randf_range(slow, fast)),
			"size": _rng.randf_range(0.6, 1.3),
			"turn": _rng.randf() * TAU,
			"late": _rng.randf() * 0.25,
		})


## What happens where something in flight comes down (thrown, dart), called as it lands.
var landed: Callable = Callable()


func _process(delta: float):
	_clock += delta
	if _clock >= seconds:
		if landed.is_valid():
			var call := landed
			landed = Callable()
			call.call()
		queue_free()
		return
	queue_redraw()


## --- Stealth, felt (the proposals of 2026-11-17, section 5) ---
##
## Something thrown flies from the hand to where it was aimed, its shadow along the ground under it (`thrown`: `toward` from here to
## there, `reach` how high it arcs, `texture` the thing's icon), and skitters on a little as it lands (`skitter`); a dart is a quick
## streak (`dart`). What it does where it lands waits for it (`landed`; StealthWatch.throw_at). And a takedown's beat: the world
## still for a moment (`still`).
const THROWN_HAND := 0.45
const THROWN_ARC := 0.6
const STILL_SCALE := 0.02


## How long something thrown `tiles` tiles is in the air.
static func flight_seconds(tiles: float) -> float:
	return clampf(0.18 + 0.035 * tiles, 0.22, 0.55)


## The world still for `seconds` of real time: a takedown's beat. Not while time is already bent (a catch slowing it, a menu), and
## never headless.
static func still(tree: SceneTree, seconds: float):
	made[&"still"] = int(made.get(&"still", 0)) + 1
	if tree == null or not shown() or DisplayServer.get_name() == "headless" or not is_equal_approx(Engine.time_scale, 1.0):
		return
	Engine.time_scale = STILL_SCALE
	tree.create_timer(seconds, true, false, true).timeout.connect(func():
		if is_equal_approx(Engine.time_scale, STILL_SCALE):
			Engine.time_scale = 1.0
	)


## The thing itself, as drawn in flight and skittering: its icon, or a small stone.
func _draw_thing(unit: float, alpha: float = 1.0):
	if texture != null:
		var size := Vector2.ONE * unit * 0.24
		draw_texture_rect(texture, Rect2(-size / 2.0, size), false, Color(1, 1, 1, alpha))
		return
	var r := unit * 0.045
	draw_colored_polygon(PackedVector2Array([Vector2(-r, -r * 0.6), Vector2(r * 0.7, -r), Vector2(r, r * 0.5), Vector2(-r * 0.4, r)]),
		Color(0.55, 0.5, 0.45, alpha))


func _draw():
	var t := clampf(_clock / maxf(seconds, 0.001), 0.0, 1.0)
	var unit := float(Grid.TILE_SIZE)
	match kind:
		&"dust", &"skid", &"hop_dust":
			# Puffs low on the ground, slowing and swelling as they thin.
			for bit in _bits:
				var s := clampf((t - bit.late) / (1.0 - bit.late), 0.0, 1.0)
				var at: Vector2 = bit.way * seconds * (1.0 - (1.0 - s) * (1.0 - s)) * strength
				at.y = at.y * 0.45 - unit * 0.05 * s
				draw_circle(at, unit * 0.05 * bit.size * (0.6 + s), Color(colour.r, colour.g, colour.b, 0.42 * (1.0 - s)))
		&"streak":
			# Lines left along the way gone, shortening from their tail.
			var along := toward.normalized()
			var side := along.orthogonal()
			for i in 3:
				var off := side * unit * 0.12 * float(i - 1)
				var from := -along * reach * (1.0 - t) + off
				draw_line(from, off - along * reach * 0.05, Color(1.0, 1.0, 1.0, 0.5 * (1.0 - t)), unit * 0.035 * (1.0 - 0.5 * absf(float(i - 1))), true)
		&"smoke":
			# A lamp put out: grey puffs rising and leaning the way the wind goes.
			for bit in _bits:
				var s := clampf((t - bit.late) / (1.0 - bit.late), 0.0, 1.0)
				var at := Vector2(bit.way.x * seconds * s * 0.6 + toward.x * unit * 0.25 * s * s, -unit * 0.55 * s * bit.size)
				draw_circle(at, unit * 0.06 * bit.size * (0.7 + 1.6 * s), Color(0.72, 0.72, 0.76, 0.34 * (1.0 - s)))
		&"hang":
			# Dust that hangs where a wall came down, thinning slowly.
			for bit in _bits:
				var at: Vector2 = Vector2(cos(bit.turn), sin(bit.turn) * 0.5) * unit * 0.5 * bit.size + bit.way * seconds * t
				draw_circle(at, unit * 0.16 * bit.size * (0.8 + t), Color(colour.r, colour.g, colour.b, 0.2 * (1.0 - t) * minf(1.0, t * 8.0)))
		&"rubble":
			# Stones thrown the way of the blow, hopping once and lying still, then fading.
			for bit in _bits:
				var s := minf(t * 1.6, 1.0)
				var at: Vector2 = bit.way * seconds * 0.35 * (1.0 - (1.0 - s) * (1.0 - s))
				at.y -= absf(sin(s * PI)) * unit * 0.22 * bit.size
				var fade := 1.0 - clampf((t - 0.75) / 0.25, 0.0, 1.0)
				if texture != null:
					var size: Vector2 = Vector2.ONE * unit * 0.2 * bit.size
					draw_set_transform(at, bit.turn + s * 3.0, Vector2.ONE)
					draw_texture_rect(texture, Rect2(-size / 2.0, size), false, Color(1, 1, 1, fade))
				else:
					draw_set_transform(at, bit.turn + s * 3.0, Vector2.ONE)
					var r: float = unit * 0.045 * bit.size
					draw_colored_polygon(PackedVector2Array([Vector2(-r, -r * 0.6), Vector2(r * 0.7, -r), Vector2(r, r * 0.5), Vector2(-r * 0.4, r)]),
						Color(colour.r * 0.7, colour.g * 0.7, colour.b * 0.7, fade))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		&"ring":
			# Rings widening on water, flattened as the ground is seen.
			for i in 2:
				var s := clampf(t * 1.25 - 0.25 * float(i), 0.0, 1.0)
				if s <= 0.0:
					continue
				var radius := unit * (0.12 + 0.5 * s) * strength
				draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
				draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, Color(0.86, 0.93, 1.0, 0.55 * (1.0 - s)), unit * 0.014, true)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		&"splash":
			# Drops thrown up and falling back.
			for bit in _bits:
				var s := clampf((t - bit.late * 0.4) / (1.0 - bit.late * 0.4), 0.0, 1.0)
				var at := Vector2(bit.way.x * seconds * s * 0.5, -absf(bit.way.y) * seconds * s * 1.1 + unit * 1.6 * s * s) * strength
				draw_circle(at, unit * 0.018 * bit.size, Color(0.86, 0.93, 1.0, 0.8 * (1.0 - s * s)))
		&"leaf":
			# Leaves shaken loose, drifting down the way the wind goes.
			for bit in _bits:
				var s := clampf((t - bit.late) / (1.0 - bit.late), 0.0, 1.0)
				var at := Vector2(bit.way.x * seconds * s + toward.x * unit * 0.5 * s + sin(s * 9.0 + bit.turn) * unit * 0.06, unit * 0.9 * s * bit.size)
				draw_set_transform(at, bit.turn + s * 5.0, Vector2(1.0, 0.5))
				draw_circle(Vector2.ZERO, unit * 0.03 * bit.size, Color(colour.r, colour.g, colour.b, 0.85 * (1.0 - s * s)))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		&"thrown":
			# From the hand, up and down where it was aimed; its shadow along the ground, smaller the higher it is.
			var ground := toward * t
			var lift := unit * THROWN_HAND * (1.0 - t) + 4.0 * t * (1.0 - t) * maxf(reach, unit * THROWN_ARC)
			draw_set_transform(ground, 0.0, Vector2(1.0, 0.5))
			draw_circle(Vector2.ZERO, unit * 0.08 * (1.0 - 0.45 * clampf(lift / (unit * 1.2), 0.0, 1.0)), Color(0.0, 0.0, 0.0, 0.3))
			draw_set_transform(ground - Vector2(0.0, lift), t * 9.0, Vector2.ONE)
			_draw_thing(unit)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		&"skitter":
			# On a little past where it came down, a hop, and lying still as it fades.
			var s := 1.0 - (1.0 - t) * (1.0 - t)
			var on := (toward.normalized() if toward != Vector2.ZERO else Vector2.RIGHT) * unit * 0.3 * s
			draw_set_transform(on - Vector2(0.0, absf(sin(s * PI)) * unit * 0.08), s * 4.0, Vector2.ONE)
			_draw_thing(unit, 1.0 - clampf((t - 0.6) / 0.4, 0.0, 1.0))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		&"dart":
			# A quick streak to where it finds its mark.
			var tip := toward * t
			var tail := toward * maxf(t - 0.4, 0.0)
			draw_line(tail, tip, Color(0.95, 0.95, 1.0, 0.75), unit * 0.02, true)
