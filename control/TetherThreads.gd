extends Node2D
## A tether's thread, to look at (the designer, 2026-11-17, of the ways to make it look better: "Do all", and "if the spell
## effect is connected to something invisible or hidden, have it also hide if it is an opponent's, or keep it without light
## if its an ally"). Combat.tether_threads says where each one goes and whether it is lit; nothing here decides anything,
## waits on anything but its own clock or rolls on Combat.rng (what scatters comes from a generator of its own), so a fight
## played on two machines comes out the same with it.
##
## A lit thread runs from the middle of whoever holds it to the middle of what it holds, at their height, up on raised
## ground too, hanging a little and swaying. A soft glow lies under a bright core in its gate's colour, neither darkened by
## the dark nor by the hour (unshaded), with a knot of light at each end, and motes in the stars' colours (SkyLook) drift
## along it from the caster, slower as the tether wears. Its core is a string of twisted strands (A string, fraying in the
## air): as it wears they loosen and splay, its worn bits hold by one strand with frayed ends, fibres drift off it and float,
## and when it is nearly gone it flickers. Whatever frays it sends a shiver along it, a blow the most; when it ends it snaps,
## both halves whipping back to their ends, unravelling, and fading, fibres flying from the break. Pointing at whoever holds it, or at
## anything it holds, lights it up.
## An unlit thread (the party's, with somebody hidden or invisible at either end, faded into the dark too) is the same
## thread, plain: no glow, no knots, no motes, nothing unshaded about it, under the figures and in the hour's tone as the
## board's own marks are. Nothing about it shines to give them away, and it is still there to see and to right click.
##
## Two of these, kept by CController._keep_the_threads: the lit one over the figures, the unlit one with the board's marks.
## Slot: a picture at art/fx/tether_thread.png is laid along the core in place of the drawn line, tiled along it and tinted
## its gate's colour; the picture's left to right runs along the thread, its top to bottom across it. The glow, the knots,
## the motes and the loose pixels stay drawn.
## Headless nothing is drawn (unless plays_headless), nor while a fight joined under way is being caught up with.
## Every number here is a PROPOSAL, to be judged by eye.

const SLOT := "res://art/fx/tether_thread.png"


## Another layer of the lit thread's drawing, in a blend of its own: its glow under the core, or its motes and what comes
## loose over it.
class _Layer extends Node2D:
	var threads = null
	var kind := &""

	func _draw():
		if threads != null and is_instance_valid(threads):
			threads.draw_layer(self, kind)


## Set by a test that wants to see them made with nobody watching.
static var plays_headless := false

## Over the figures and the weather, under what flies and what lands (Projectile 900, MoveFeel 905).
const LIT_Z := 880
## A thread whose spell came through no gate, in the colour of the bar under whoever holds it (CController.TETHER_COLOUR).
const UNGATED := Color("9d7fe0")
## How thick the core is, worn to full strength; how much paler than its gate's colour it is, lit.
const THINNEST := 2.0
const THICKEST := 7.0
const CORE_WHITENS := 0.35
## The glow: this many times as wide as the core, and how strong.
const GLOW_TIMES := 4.0
const GLOW_ALPHA := 0.16
## Pointed at: its glow this much stronger, the core this much thicker and paler.
const POINTED_GLOW := 1.9
const POINTED_WIDER := 2.0
const POINTED_WHITENS := 0.25
## How far it hangs in the middle: a share of its length, held between these (pixels), breathing by this much.
const SAG_SHARE := 0.08
const SAG_LEAST := 8.0
const SAG_MOST := 48.0
const SAG_BREATH := 0.12
## How far it sways across itself, and how many times a second.
const SWAY_PIXELS := 5.0
const SWAY_RATE := 0.2
## How high above the ground it lands on what lies there (a wall's pieces, a zone), a share of a tile, over raised ground.
const LANDS_ABOVE := 0.12
## Its points, this many pixels apart, between the fewest and the most.
const STEP_PIXELS := 18.0
const STEPS_FEWEST := 12
const STEPS_MOST := 48
## Motes: about this far apart, two at the fewest and this many at most; how fast at full strength (pixels a second), the
## share of that left when worn through, and how big.
const MOTE_SPACING := 110.0
const MOTES_MOST := 8
const MOTE_SPEED := 170.0
const MOTE_SLOWEST := 0.3
const MOTE_RADIUS := 3.5
## Fraying, from this share of its strength down: bits worn through to one strand over at most this much of it, in bits
## this long; up to this many fibres a second coming loose, each for about as long as these seconds (A string, below).
const FRAYS_BELOW := 0.6
const GAPS_MOST := 0.5
const GAP_PIXELS := 28.0
const LOOSE_A_SECOND := 14.0
const LOOSE_LIFE := 0.9
const LOOSE_MOST := 240
## It flickers below this share, by as much as this.
const FLICKERS_BELOW := 0.25
const FLICKER_MOST := 0.6
## A shiver: how long, and how far across itself at its strongest.
const SHIVER_SECONDS := 0.45
const SHIVER_PIXELS := 14.0
## A snap: how long, how far its ends whip, how many bits fly from the break.
const SNAP_SECONDS := 0.4
const SNAP_WHIP := 22.0
const SNAP_BITS := 10

## --- A string, fraying in the air ---
##
## The designer, 2026-11-20: "Have the tether act a bit more like a string which frays in space ... visually, no change gameplay
## wise". Its core is STRANDS thin strands twisted round each other, a turn every TWIST_PIXELS, tight while it is whole; as it
## wears they work loose and splay apart (to SPLAY_MOST of its width); where it is worn through (its gaps) it holds by one strand,
## with the broken ones' frayed ends (WHISKERS) sticking out either side; what comes off it is fibres that drift and turn slowly
## where they came loose (FIBRE_DRIFT, FIBRE_SPIN), slowing to a float, nothing falling; and a slow ripple runs along it. A snap
## unravels the halves' free ends. Only the drawing: Combat.tether_threads and the tether itself are as they were.
const STRANDS := 3
const TWIST_PIXELS := 26.0
const TWIST_RATE := 0.25
const SPLAY_MOST := 1.6
const WHISKERS := 3
const WHISKER_PIXELS := 9.0
const FIBRE_DRIFT := 16.0
const FIBRE_SPIN := 1.6
const FIBRE_SLOWS := 1.2
const RIPPLE_PIXELS := 2.5
const RIPPLE_RATE := 0.35

var combat: Combat = null
## Whose pointer lights a thread up (its _hover_tile).
var controller = null
## The one over the figures, glowing, or the plain one under them.
var lit := true
## The picture in the slot, or null.
var picture: Texture2D = null

## What is drawn now: {"id", "holder", "points", "colour", "width", "share", "pointed", "gaps", "flicker", "phase", "seed",
## "state"}, one to a thread. Read by a test, and by the snap when a tether goes.
var threads_now: Array = []
## Snaps playing: {"points", "colour", "width", "age"}.
var snaps: Array = []
## What has come loose: {"p", "v", "colour", "age", "life", "size"}.
var loose: Array = []
## For each tether by its id: the bar last seen, the shiver left and how strong, how far its motes have gone, loose pixels owed.
var _seen := {}
var _clock := 0.0
var _rng := RandomNumberGenerator.new()
var _drawn_last := false
var _glow: _Layer = null
var _sparks: _Layer = null


static func shown() -> bool:
	if DisplayServer.get_name() == "headless" and not plays_headless:
		return false
	return not Net.catching_up()


## Where `at`, in tiles (Combat.tether_threads), is on the ground, in the board's own space (the figures' layer's): a whole
## number the middle of a tile, a half the line between two.
static func ground_of(at: Vector2) -> Vector2:
	return at * float(Grid.TILE_SIZE) + Grid.HALF_TILE


func _ready():
	name = "TetherThreads" if lit else "TetherThreadsUnlit"
	_rng.seed = 20261117
	if ResourceLoader.exists(SLOT):
		picture = load(SLOT)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	if not lit:
		return
	material = _unshaded(CanvasItemMaterial.BLEND_MODE_MIX)
	light_mask = 0
	_glow = _layer(&"glow")
	_glow.show_behind_parent = true
	_sparks = _layer(&"sparks")


func _layer(kind: StringName) -> _Layer:
	var made := _Layer.new()
	made.name = "Glow" if kind == &"glow" else "Sparks"
	made.threads = self
	made.kind = kind
	made.material = _unshaded(CanvasItemMaterial.BLEND_MODE_ADD)
	made.light_mask = 0
	add_child(made)
	return made


static func _unshaded(blend: CanvasItemMaterial.BlendMode) -> CanvasItemMaterial:
	var made := CanvasItemMaterial.new()
	made.blend_mode = blend
	made.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return made


func _process(delta: float):
	if combat == null or not is_instance_valid(combat) or not shown():
		if _drawn_last or not threads_now.is_empty() or not snaps.is_empty() or not loose.is_empty():
			threads_now = []
			snaps = []
			loose = []
			_seen = {}
			_redraw()
		return
	_clock += delta
	var was := {}
	for thread in threads_now:
		if not was.has(thread.id):
			was[thread.id] = []
		was[thread.id].append(thread)
	threads_now = []
	var held := {}
	for holder in combat.combatants:
		if not holder.get("alive", false) or not Combat.holds_tether(holder) or holder.has("riding"):
			continue
		var tether: Dictionary = holder.tether
		held[tether.id] = true
		var state: Dictionary = _state_of(tether)
		# Whatever frayed it, a shiver along it: the more it lost, the stronger.
		if float(tether.bar) < state.bar - 0.001:
			state.shiver = SHIVER_SECONDS
			state.shake = clampf((state.bar - float(tether.bar)) / maxf(float(tether.max), 1.0) * 4.0, 0.35, 1.0)
		state.bar = float(tether.bar)
		state.shiver = maxf(state.shiver - delta, 0.0)
		var share := clampf(float(tether.bar) / maxf(float(tether.max), 1.0), 0.0, 1.0)
		state.phase += delta * MOTE_SPEED * lerpf(MOTE_SLOWEST, 1.0, share)
		var index := 0
		for thread in combat.tether_threads(holder):
			if (thread.light == Combat.ThreadLight.LIT) != lit:
				continue
			threads_now.append(_lay(holder, tether, thread, state, share, index))
			index += 1
	# A tether that has gone snaps where it was drawn. One only out of sight, or drawn by the other of these now, does not.
	for id in was:
		if not held.has(id):
			for thread in was[id]:
				_snap(thread)
	for id in _seen.keys():
		if not held.has(id):
			_seen.erase(id)
	for snap in snaps:
		snap.age += delta
	snaps = snaps.filter(func(snap): return snap.age < SNAP_SECONDS)
	_shed(delta)
	_redraw()


func _state_of(tether: Dictionary) -> Dictionary:
	if not _seen.has(tether.id):
		_seen[tether.id] = {"bar": float(tether.bar), "shiver": 0.0, "shake": 0.0, "phase": 0.0, "owed": 0.0}
	return _seen[tether.id]


func _redraw():
	var drawing := not threads_now.is_empty() or not snaps.is_empty() or not loose.is_empty()
	if not drawing and not _drawn_last:
		return
	_drawn_last = drawing
	queue_redraw()
	if _glow != null:
		_glow.queue_redraw()
	if _sparks != null:
		_sparks.queue_redraw()


## One thread from `holder` laid out for drawing.
func _lay(holder: Dictionary, tether: Dictionary, thread: Dictionary, state: Dictionary, share: float, index: int) -> Dictionary:
	var seed: int = int(tether.id) * 31 + index * 7
	var pointed := _pointed_at(holder, thread)
	var spell: SkillDefinition = SkillDatabase.skills.get(tether.get("skill", ""))
	var colour: Color = Stats.gate_colour(spell.spell_slot_level) if spell != null and spell.spell_slot_level > 0 else UNGATED
	return {"id": tether.id, "holder": holder, "points": _curve(_figure_middle(holder), _end_of(thread), seed, state),
		"colour": colour, "share": share, "pointed": pointed, "seed": seed, "state": state, "phase": state.phase,
		"width": lerpf(THINNEST, THICKEST, share) + (POINTED_WIDER if pointed else 0.0),
		"gaps": 0.0 if share >= FRAYS_BELOW else (FRAYS_BELOW - share) / FRAYS_BELOW * GAPS_MOST,
		"flicker": _flicker(seed, share)}


## The middle of `comb` as drawn, in this one's own space: their picture's middle, wherever it is lifted, hopped or knocked.
func _figure_middle(comb: Dictionary) -> Vector2:
	var sprite = comb.get("sprite")
	if sprite != null and is_instance_valid(sprite) and sprite.has_method("_drawn"):
		var drawn = sprite._drawn()
		if drawn != null and is_instance_valid(drawn):
			return to_local(drawn.to_global(drawn.offset))
	return to_local(combat.combatant_layer().to_global(MoveFeel.middle_of(combat, comb)))


## Whether `comb` lies on the ground rather than standing up on it: a piece of a wall, or nothing drawn at all.
func _lies_flat(comb: Dictionary) -> bool:
	var sprite = comb.get("sprite")
	return sprite == null or not is_instance_valid(sprite) or sprite.get("laid") == true


## Where a thread ends: at the middle of whoever it goes to, as drawn; between several standing side by side, at their
## height; or a little above the ground in the middle of what lies there, a wall's pieces or a zone, up on raised ground too.
func _end_of(thread: Dictionary) -> Vector2:
	var standing: Array = thread.held.filter(func(comb): return not _lies_flat(comb))
	if thread.held.size() == 1 and thread.zones.is_empty() and standing.size() == 1:
		return _figure_middle(standing[0])
	var layer: Node2D = combat.combatant_layer()
	var ground := to_local(layer.to_global(ground_of(thread.at)))
	if standing.is_empty() or not thread.zones.is_empty():
		var tile := Vector2i(roundi(thread.at.x), roundi(thread.at.y))
		var raised := 0.0
		if combat.depth_view != null and is_instance_valid(combat.depth_view):
			raised = combat.depth_view.height_at(tile)
		return ground - Vector2(0.0, raised + float(Grid.TILE_SIZE) * LANDS_ABOVE)
	var rise := 0.0
	for comb in standing:
		rise += to_local(layer.to_global(MoveFeel.middle_of(combat, comb))).y - _figure_middle(comb).y
	return ground - Vector2(0.0, rise / float(standing.size()))


## Whether the pointer is on whoever holds it, or on anything this thread goes to.
func _pointed_at(holder: Dictionary, thread: Dictionary) -> bool:
	if controller == null or not is_instance_valid(controller):
		return false
	var tile = controller.get("_hover_tile")
	if not (tile is Vector2i) or tile.x == -99999:
		return false
	if Combat.covers(holder, tile) or thread.held.any(func(comb): return Combat.covers(comb, tile)):
		return true
	return thread.zones.any(func(zone): return tile in zone.tiles)


## The thread from `from` to `to`, hanging a little in the middle, swaying, and shivering while it does.
func _curve(from: Vector2, to: Vector2, seed: int, state: Dictionary) -> PackedVector2Array:
	var points := PackedVector2Array()
	var line := to - from
	var length := line.length()
	if length < 1.0:
		points.append(from)
		points.append(to)
		return points
	var across := Vector2(-line.y, line.x) / length
	var hangs := clampf(length * SAG_SHARE, SAG_LEAST, SAG_MOST) * (1.0 + SAG_BREATH * sin(_clock * 1.1 + float(seed)))
	var sways := SWAY_PIXELS * sin(_clock * SWAY_RATE * TAU + float(seed) * 1.7)
	# The curve's lowest point is half of its pull's.
	var pull := (from + to) * 0.5 + Vector2(0.0, hangs * 2.0) + across * sways * 2.0
	var steps := clampi(int(length / STEP_PIXELS), STEPS_FEWEST, STEPS_MOST)
	var shiver: float = state.shiver / SHIVER_SECONDS
	for step in steps + 1:
		var t := float(step) / float(steps)
		var at := from.lerp(pull, t).lerp(pull.lerp(to, t), t)
		# A slow ripple along it, still at its ends: a string, not a rod.
		at += across * RIPPLE_PIXELS * sin(PI * t) * sin(TAU * (2.0 * t - _clock * RIPPLE_RATE) + float(seed))
		if shiver > 0.0:
			at += across * SHIVER_PIXELS * float(state.shake) * shiver * sin(PI * t) * sin(TAU * (3.0 * t - _clock * 4.0))
		points.append(at)
	return points


## How bright it is, worn: whole, until nearly gone, then flickering, the more the closer it is to going.
func _flicker(seed: int, share: float) -> float:
	if share >= FLICKERS_BELOW:
		return 1.0
	var depth := (FLICKERS_BELOW - share) / FLICKERS_BELOW
	var wobble := 0.5 + 0.5 * sin(_clock * 23.0 + float(seed)) * sin(_clock * 7.3 + float(seed) * 0.5)
	return 1.0 - depth * FLICKER_MOST * wobble


## The same number for the same thread and bit of it, between 0 and 1: where its gaps are stays put as it wears.
static func _noise(seed: int, bit: int) -> float:
	return fposmod(sin(float(seed) * 12.9898 + float(bit) * 78.233) * 43758.5453, 1.0)


static func _length_of(points: PackedVector2Array) -> float:
	var length := 0.0
	for index in range(1, points.size()):
		length += points[index].distance_to(points[index - 1])
	return length


## The point `t` of the way along `points`.
static func _point_along(points: PackedVector2Array, t: float) -> Vector2:
	var goal := _length_of(points) * clampf(t, 0.0, 1.0)
	for index in range(1, points.size()):
		var step := points[index].distance_to(points[index - 1])
		if goal <= step and step > 0.0:
			return points[index - 1].lerp(points[index], goal / step)
		goal -= step
	return points[points.size() - 1]


## The thread's points in runs, with the gaps its fraying has opened left out. Never at its ends. (Drawn, a gap is where
## it holds by one strand: _draw_strands.)
func pieces_of(thread: Dictionary) -> Array:
	var points: PackedVector2Array = thread.points
	if float(thread.gaps) <= 0.0 or points.size() < 3:
		return [points]
	var through := worn_through(thread)
	var runs := []
	var run := PackedVector2Array()
	for index in points.size():
		if through[index]:
			if run.size() >= 2:
				runs.append(run)
			run = PackedVector2Array()
		else:
			run.append(points[index])
	if run.size() >= 2:
		runs.append(run)
	return runs


## For each of the thread's points, whether it is in a bit worn through: the same bits as it wears, never at its ends.
func worn_through(thread: Dictionary) -> Array:
	var points: PackedVector2Array = thread.points
	var through := []
	through.resize(points.size())
	through.fill(false)
	if float(thread.gaps) <= 0.0 or points.size() < 3:
		return through
	var total := _length_of(points)
	var along := 0.0
	for index in points.size():
		if index > 0:
			along += points[index].distance_to(points[index - 1])
		var bit := int(along / GAP_PIXELS)
		through[index] = along > GAP_PIXELS and along < total - GAP_PIXELS and _noise(int(thread.seed), bit) < float(thread.gaps)
	return through


## How worn it is: nothing until it frays, all the way at nothing left.
static func _worn(share: float) -> float:
	return 0.0 if share >= FRAYS_BELOW else (FRAYS_BELOW - share) / FRAYS_BELOW


## Across the line at each of `points`, a unit long.
static func _normals_of(points: PackedVector2Array) -> PackedVector2Array:
	var normals := PackedVector2Array()
	for index in points.size():
		var before: Vector2 = points[maxi(index - 1, 0)]
		var after: Vector2 = points[mini(index + 1, points.size() - 1)]
		var along := after - before
		normals.append(Vector2(-along.y, along.x).normalized() if along.length() > 0.001 else Vector2.UP)
	return normals


## `thread` has gone with its tether: it breaks in the middle, each half whipping back to its end (_draw_snap), and bits
## fly from the break.
func _snap(thread: Dictionary):
	var points: PackedVector2Array = thread.points
	if points.size() < 2:
		return
	snaps.append({"points": points, "colour": thread.colour, "width": thread.width, "age": 0.0})
	var middle := points[points.size() / 2]
	for each in SNAP_BITS:
		loose.append(_fibre(middle, Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(60.0, 160.0),
			Color(thread.colour).lerp(Color.WHITE, 0.3), LOOSE_LIFE * _rng.randf_range(0.5, 1.0)))


## A fibre come loose at `at`, going off at `velocity` and slowing to a float, turning as it goes.
func _fibre(at: Vector2, velocity: Vector2, colour: Color, life: float) -> Dictionary:
	return {"p": at, "v": velocity, "colour": colour, "age": 0.0, "life": life, "size": _rng.randf_range(2.5, 4.5),
		"angle": _rng.randf() * TAU, "spin": _rng.randf_range(-FIBRE_SPIN, FIBRE_SPIN), "curl": _rng.randf_range(-0.6, 0.6)}


## What comes loose from the worn: owed by how worn each is, from anywhere along it, drifting off and fading where it came
## loose, never falling.
func _shed(delta: float):
	for thread in threads_now:
		var worn: float = _worn(thread.share)
		if worn <= 0.0:
			continue
		var state: Dictionary = thread.state
		state.owed += delta * LOOSE_A_SECOND * worn * clampf(_length_of(thread.points) / 400.0, 0.5, 2.0)
		while state.owed >= 1.0 and loose.size() < LOOSE_MOST:
			state.owed -= 1.0
			loose.append(_fibre(_point_along(thread.points, _rng.randf()), Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(4.0, FIBRE_DRIFT),
				thread.colour, LOOSE_LIFE * _rng.randf_range(1.0, 1.8)))
		state.owed = minf(state.owed, 1.0)
	for bit in loose:
		bit.age += delta
		bit.p = bit.p + bit.v * delta
		bit.v = bit.v * maxf(1.0 - FIBRE_SLOWS * delta, 0.0)
		bit.angle = float(bit.get("angle", 0.0)) + float(bit.get("spin", 0.0)) * delta
	loose = loose.filter(func(bit): return bit.age < bit.life)


func _draw():
	for thread in threads_now:
		_draw_core(self, thread)
	for snap in snaps:
		_draw_snap(self, snap, false)
	# The unlit one has no layers of its own: what comes off it is drawn with it, as plain as it is.
	if not lit:
		_draw_loose(self)


## The glow under the core, or the motes and loose pixels over it (_Layer).
func draw_layer(canvas: CanvasItem, kind: StringName):
	if kind == &"glow":
		for thread in threads_now:
			_draw_glow(canvas, thread)
		for snap in snaps:
			_draw_snap(canvas, snap, true)
		return
	for thread in threads_now:
		_draw_motes(canvas, thread)
	_draw_loose(canvas)


func _draw_core(canvas: CanvasItem, thread: Dictionary):
	var colour: Color = thread.colour
	var alpha: float
	if lit:
		colour = colour.lerp(Color.WHITE, CORE_WHITENS + (POINTED_WHITENS if thread.pointed else 0.0))
		alpha = (0.6 + 0.35 * float(thread.share)) * float(thread.flicker)
	else:
		alpha = (0.35 + 0.35 * float(thread.share) + (0.2 if thread.pointed else 0.0)) * float(thread.flicker)
	if picture != null:
		for piece in pieces_of(thread):
			_strip(canvas, piece, float(thread.width) * 2.0, Color(colour, alpha))
		return
	_draw_strands(canvas, thread, Color(colour, alpha))


## The thread as STRANDS twisted round its line, meeting at its ends, tight while whole and splaying apart as it wears; where
## it is worn through it holds by one strand, close to the line, with frayed ends sticking out where the others broke.
func _draw_strands(canvas: CanvasItem, thread: Dictionary, colour: Color):
	var points: PackedVector2Array = thread.points
	if points.size() < 2:
		return
	var width: float = thread.width
	var worn := _worn(float(thread.share))
	var spread: float = width * (0.35 + SPLAY_MOST * worn)
	var strand_width: float = maxf(width / float(STRANDS) * 1.5, 1.2)
	var total := _length_of(points)
	var normals := _normals_of(points)
	var through := worn_through(thread)
	var seed: int = int(thread.seed)
	for strand in STRANDS:
		var run := PackedVector2Array()
		var along := 0.0
		for index in points.size():
			if index > 0:
				along += points[index].distance_to(points[index - 1])
			if through[index] and strand > 0:
				if run.size() >= 2:
					canvas.draw_polyline(run, colour, strand_width, true)
				run = PackedVector2Array()
				continue
			var turn := along / TWIST_PIXELS * TAU + float(strand) * TAU / float(STRANDS) + (_clock * TWIST_RATE + float(seed) * 0.13) * TAU
			var ends := minf(minf(along, total - along) / 18.0, 1.0)
			var off := sin(turn) * spread * 0.5 * ends * (0.3 if through[index] else 1.0)
			run.append(points[index] + normals[index] * off)
		if run.size() >= 2:
			canvas.draw_polyline(run, colour, strand_width, true)
	# Where a worn bit begins and ends, the broken strands' ends stick out, stirring a little.
	for index in range(1, points.size()):
		if through[index] == through[index - 1]:
			continue
		var at: Vector2 = points[index - 1] if through[index] else points[index]
		var way: Vector2 = (points[index] - points[index - 1]).normalized() * (1.0 if through[index] else -1.0)
		for whisker in WHISKERS:
			var lean := (float(whisker) - float(WHISKERS - 1) * 0.5) * 0.7 + 0.25 * sin(_clock * 1.7 + float(seed + index + whisker))
			var length := WHISKER_PIXELS * (0.6 + 0.6 * _noise(seed + index, whisker))
			var root: Vector2 = at + normals[index] * (float(whisker) - 1.0) * spread * 0.3
			var tip := root + way.rotated(lean) * length
			canvas.draw_polyline(PackedVector2Array([root, root.lerp(tip, 0.5) + normals[index] * lean * 2.0, tip]), Color(colour, colour.a * 0.8),
				maxf(strand_width * 0.7, 1.0), true)


func _draw_glow(canvas: CanvasItem, thread: Dictionary):
	var strength: float = GLOW_ALPHA * (POINTED_GLOW if thread.pointed else 1.0) * (0.5 + 0.5 * float(thread.share)) * float(thread.flicker)
	var width: float = thread.width
	for piece in pieces_of(thread):
		canvas.draw_polyline(piece, Color(thread.colour, strength), width * GLOW_TIMES + 6.0, true)
		canvas.draw_polyline(piece, Color(thread.colour, strength * 1.6), width * 2.0 + 2.0, true)
	# Where it leaves them, and where it lands: a soft knot of light.
	var points: PackedVector2Array = thread.points
	canvas.draw_circle(points[0], width * 2.2, Color(thread.colour, strength * 1.5))
	canvas.draw_circle(points[points.size() - 1], width * 2.6, Color(thread.colour, strength * 1.5))


func _draw_motes(canvas: CanvasItem, thread: Dictionary):
	var points: PackedVector2Array = thread.points
	var length := _length_of(points)
	if length < 4.0:
		return
	var count := clampi(int(length / MOTE_SPACING), 2, MOTES_MOST)
	for index in count:
		var t := fposmod(float(thread.phase) / length + float(index) / float(count), 1.0)
		var fade := minf(minf(t, 1.0 - t) / 0.1, 1.0) * float(thread.flicker)
		var at := _point_along(points, t)
		var colour: Color = SkyLook.STAR_COLOURS[(index + int(thread.seed)) % SkyLook.STAR_COLOURS.size()]
		canvas.draw_circle(at, MOTE_RADIUS * 2.6, Color(colour, 0.22 * fade))
		canvas.draw_circle(at, MOTE_RADIUS, Color(colour, 0.85 * fade))


## What has come loose: fibres, short and a little curled, turning where they drift.
func _draw_loose(canvas: CanvasItem):
	for bit in loose:
		var fade: float = 1.0 - bit.age / bit.life
		var size: float = bit.size
		var way := Vector2.from_angle(float(bit.get("angle", 0.0))) * size * 1.4
		var bend := way.orthogonal() * float(bit.get("curl", 0.0))
		canvas.draw_polyline(PackedVector2Array([bit.p - way, bit.p + bend, bit.p + way]), Color(bit.colour, (0.8 if lit else 0.5) * fade),
			maxf(size * 0.45, 1.0), true)


## A snap playing: each half drawn back from the break to its end, its free end whipping, fading as it goes.
func _draw_snap(canvas: CanvasItem, snap: Dictionary, glow: bool):
	var points: PackedVector2Array = snap.points
	var t: float = clampf(snap.age / SNAP_SECONDS, 0.0, 1.0)
	var alpha := (1.0 - t) * (1.0 - t)
	var half := points.size() / 2
	var count := maxi(int(round(float(half) * (1.0 - t))), 1)
	for side in 2:
		var run := PackedVector2Array()
		for step in count + 1:
			var index: int = clampi(step if side == 0 else points.size() - 1 - step, 0, points.size() - 1)
			var before: Vector2 = points[maxi(index - 1, 0)]
			var after: Vector2 = points[mini(index + 1, points.size() - 1)]
			var across := (after - before).orthogonal().normalized()
			var free := float(step) / float(count)
			run.append(points[index] + across * SNAP_WHIP * free * free * sin(t * 18.0 + float(side) * PI) * (1.0 - t))
		if run.size() < 2:
			continue
		var width: float = snap.width
		if glow:
			canvas.draw_polyline(run, Color(snap.colour, GLOW_ALPHA * 1.5 * alpha), width * GLOW_TIMES, true)
		elif picture != null:
			var colour: Color = Color(snap.colour).lerp(Color.WHITE, CORE_WHITENS) if lit else snap.colour
			canvas.draw_polyline(run, Color(colour, 0.8 * alpha), width, true)
		else:
			# Its strands, unravelling towards the broken end.
			var colour: Color = Color(snap.colour).lerp(Color.WHITE, CORE_WHITENS) if lit else snap.colour
			var normals := _normals_of(run)
			for strand in STRANDS:
				var apart := PackedVector2Array()
				for index in run.size():
					var free := float(index) / float(maxi(run.size() - 1, 1))
					apart.append(run[index] + normals[index] * (float(strand) - float(STRANDS - 1) * 0.5) * width * (0.4 + 3.0 * free * free))
				canvas.draw_polyline(apart, Color(colour, 0.8 * alpha), maxf(width / float(STRANDS) * 1.5, 1.2), true)


## The slot's picture laid along `points`, `width` across, tiled along its length.
func _strip(canvas: CanvasItem, points: PackedVector2Array, width: float, colour: Color):
	var repeat := float(picture.get_width()) * width / maxf(float(picture.get_height()), 1.0)
	var along := 0.0
	for index in points.size() - 1:
		var a := points[index]
		var b := points[index + 1]
		var step := a.distance_to(b)
		if step <= 0.0:
			continue
		var side := (b - a).orthogonal().normalized() * width * 0.5
		var u0 := along / repeat
		var u1 := (along + step) / repeat
		canvas.draw_polygon(PackedVector2Array([a - side, b - side, b + side, a + side]), PackedColorArray([colour]),
			PackedVector2Array([Vector2(u0, 0.0), Vector2(u1, 0.0), Vector2(u1, 1.0), Vector2(u0, 1.0)]), picture)
		along += step
