extends Node2D
class_name ConditionLook
## What a condition looks like on the figure that has it (the designer, 2026-11-07, from
## docs/proposals_2026-11-07.md section 9: everything but icons over the head). To look at only: nothing here
## rolls or decides, and headless none of it is made (MoveFeel.shown). Each condition says how it shows, on
## ConditionDefinition's "On The Figure" group, with a placeholder drawn here and a slot for the real art.
##
## A figure with six things on it would be a mess, so one at a time shows: the highest Figure Priority, and those
## equal to it taking turns every TURN_SECONDS. A ring under the feet says only whether something is helping or
## hurting, and pulses when it is about to end. CombatantSprite owns one of these, under nothing else of its own.

## How long each of several equal conditions shows before the next.
const TURN_SECONDS := 1.3
const RING_HELPS := Color(0.45, 0.85, 0.55)
const RING_HURTS := Color(1.0, 0.4, 0.35)
## How long what is going fades for, and how fast a colour breathes.
const FADE_SECONDS := 0.4
const BREATH_RATE := 2.6

## Every condition on them now: {"condition", "helps", "ends_soon"}. What is shown is worked out from it.
var entries: Array = []
var _shown: ConditionDefinition = null
var _clock := 0.0
var _since_turn := 0.0
var _fade := 0.0
var _faded_from: ConditionDefinition = null
var _particles: CPUParticles2D = null
var _particles_for: int = -1
var _figure: CombatantSprite = null


func _ready():
	_figure = get_parent() as CombatantSprite
	z_index = 1
	light_mask = 0
	# Under the figure, where this is over it.
	_ring = _Ring.new()
	_ring.look = self
	_put_the_ring_under.call_deferred()


func _put_the_ring_under():
	if _figure == null or not is_instance_valid(_figure) or _ring == null:
		return
	_figure.add_child(_ring)
	_figure.move_child(_ring, 0)
	_ring.queue_redraw()


## Says what is on them. An empty list and it all goes, quietly.
func show_entries(new_entries: Array):
	entries = new_entries
	_choose()
	queue_redraw()


## The condition shown now, for tests and the figure: the highest Figure Priority, those equal taking turns.
static func choose_from(list: Array, turn: int) -> ConditionDefinition:
	if list.is_empty():
		return null
	var best := -1
	for entry in list:
		best = maxi(best, entry.condition.figure_priority)
	var top: Array = list.filter(func(entry): return entry.condition.figure_priority == best)
	return top[posmod(turn, top.size())].condition


var _turn := 0


func _choose():
	var was: ConditionDefinition = _shown
	# Only what has something to show takes a turn at showing it.
	var showing: Array = entries.filter(func(entry): return _has_a_look(entry.condition))
	_shown = choose_from(showing, _turn)
	if _shown != was:
		if was != null:
			_faded_from = was
			_fade = FADE_SECONDS
		_set_particles(_shown)
	if _figure != null:
		_figure.set_pose(_pose_wanted())


## The pose of whatever of those on them has one, the strongest first. Idle, if they have none of it (CombatantSprite.set_pose).
func _pose_wanted() -> StringName:
	var best: StringName = &""
	var priority := -1
	for entry in entries:
		if entry.condition.figure_pose != &"" and entry.condition.figure_priority > priority:
			best = entry.condition.figure_pose
			priority = entry.condition.figure_priority
	return best


static func _has_a_look(condition: ConditionDefinition) -> bool:
	return condition.figure_tint.a > 0.0 or condition.round_them != ConditionDefinition.RoundThem.NONE \
		or condition.off_them != ConditionDefinition.OffThem.NONE or condition.round_them_picture != null \
		or condition.off_them_picture != null


func _process(delta: float):
	_clock += delta
	_since_turn += delta
	if _since_turn >= TURN_SECONDS:
		_since_turn = 0.0
		_turn += 1
		_choose()
	if _fade > 0.0:
		_fade = maxf(_fade - delta, 0.0)
		if _fade <= 0.0:
			_faded_from = null
	if _figure != null:
		modulate.a = _figure.hidden_alpha
		_figure.set_condition_tint(_tint_now())
	if not entries.is_empty() or _faded_from != null:
		queue_redraw()
		if _ring != null:
			_ring.queue_redraw()


## The colour over them now, breathing, easing out as what gave it goes.
func _tint_now() -> Color:
	var colour: Color = Color(1, 1, 1, 0)
	if _shown != null and _shown.figure_tint.a > 0.0:
		colour = _shown.figure_tint
	elif _faded_from != null and _faded_from.figure_tint.a > 0.0:
		colour = Color(_faded_from.figure_tint, _faded_from.figure_tint.a * (_fade / FADE_SECONDS))
	if colour.a <= 0.0:
		return Color.WHITE
	var breath: float = 0.75 + 0.25 * sin(_clock * BREATH_RATE)
	return Color.WHITE.lerp(Color(colour.r, colour.g, colour.b), colour.a * breath)


func _draw():
	var tile := float(Grid.TILE_SIZE)
	if _shown != null:
		_draw_round_them(_shown, tile, 1.0)
	if _faded_from != null:
		_draw_round_them(_faded_from, tile, _fade / FADE_SECONDS)


var _ring: _Ring = null


## Under their feet: green for what helps, red for what hurts, both if they have both. Pulsing when something is about to end.
class _Ring extends Node2D:
	var look: ConditionLook = null

	func _draw():
		if look == null or not is_instance_valid(look):
			return
		var tile := float(Grid.TILE_SIZE)
		var helps := false
		var hurts := false
		var soon := false
		for entry in look.entries:
			if entry.condition.figure_no_ring:
				continue
			helps = helps or entry.helps
			hurts = hurts or not entry.helps
			soon = soon or entry.ends_soon
		if not helps and not hurts:
			return
		var pulse: float = 0.55 + 0.45 * sin(look._clock * 7.0) if soon else 0.8
		pulse *= look.modulate.a
		var feet := Vector2(0.0, tile * 0.42)
		var radius := tile * 0.36
		draw_set_transform(feet, 0.0, Vector2(1.0, 0.32))
		if hurts and helps:
			draw_arc(Vector2.ZERO, radius, 0.0, PI, 32, Color(ConditionLook.RING_HURTS, pulse), tile * 0.03)
			draw_arc(Vector2.ZERO, radius, PI, TAU, 32, Color(ConditionLook.RING_HELPS, pulse), tile * 0.03)
		else:
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(ConditionLook.RING_HURTS if hurts else ConditionLook.RING_HELPS, pulse), tile * 0.03)


func _draw_round_them(condition: ConditionDefinition, tile: float, strength: float):
	var head: float = -_figure.head_height() if _figure != null else -tile * 0.5
	if condition.round_them_picture != null:
		var size: Vector2 = condition.round_them_picture.get_size()
		var at := Vector2(0.0, head - size.y * 0.5)
		var spin: float = _clock * 1.6
		draw_set_transform(at, spin)
		draw_texture(condition.round_them_picture, -size * 0.5, Color(1, 1, 1, strength))
		draw_set_transform(Vector2.ZERO)
		return
	match condition.round_them:
		ConditionDefinition.RoundThem.STARS:
			for i in 3:
				var angle: float = _clock * 2.6 + TAU * float(i) / 3.0
				var at := Vector2(cos(angle) * tile * 0.22, head - tile * 0.05 + sin(angle) * tile * 0.06)
				_star(at, tile * 0.05, Color(1.0, 0.92, 0.4, strength))
		ConditionDefinition.RoundThem.SPIRAL:
			var points := PackedVector2Array()
			for i in 28:
				var t: float = float(i) / 27.0
				var angle: float = t * TAU * 2.2 + _clock * 3.0
				points.append(Vector2(cos(angle), sin(angle) * 0.55) * tile * 0.19 * t + Vector2(0.0, head - tile * 0.06))
			draw_polyline(points, Color(0.8, 0.6, 1.0, strength), tile * 0.016, true)
		ConditionDefinition.RoundThem.BAND_OVER_EYES:
			var y: float = head + tile * 0.1
			draw_line(Vector2(-tile * 0.1, y), Vector2(tile * 0.1, y), Color(0.08, 0.06, 0.1, 0.9 * strength), tile * 0.05)
		ConditionDefinition.RoundThem.SWEAT:
			for i in 3:
				var t: float = fmod(_clock * 0.9 + float(i) / 3.0, 1.0)
				var side: float = -1.0 if i % 2 == 0 else 1.0
				var at := Vector2(side * tile * (0.1 + t * 0.08), head + tile * (0.02 + t * 0.14))
				draw_circle(at, tile * 0.016, Color(0.6, 0.85, 1.0, (1.0 - t) * strength))
		ConditionDefinition.RoundThem.CHAIN:
			var feet := Vector2(0.0, tile * 0.42)
			for i in 8:
				var angle: float = _clock * 0.5 + TAU * float(i) / 8.0
				draw_circle(feet + Vector2(cos(angle) * tile * 0.26, sin(angle) * tile * 0.08), tile * 0.022, Color(0.72, 0.72, 0.78, strength))
		ConditionDefinition.RoundThem.GAG:
			var y: float = head + tile * 0.16
			draw_line(Vector2(-tile * 0.08, y - tile * 0.03), Vector2(tile * 0.08, y + tile * 0.03), Color(1.0, 0.4, 0.4, strength), tile * 0.02)
			draw_line(Vector2(-tile * 0.08, y + tile * 0.03), Vector2(tile * 0.08, y - tile * 0.03), Color(1.0, 0.4, 0.4, strength), tile * 0.02)
		ConditionDefinition.RoundThem.STRINGS:
			for side in [-0.14, 0.0, 0.14]:
				var sway: float = sin(_clock * 1.7 + side * 9.0) * tile * 0.012
				draw_line(Vector2(side * tile + sway, head - tile * 0.6), Vector2(side * tile, head + tile * 0.1), Color(0.95, 0.9, 1.0, 0.75 * strength), tile * 0.006)
		ConditionDefinition.RoundThem.ARROW:
			var bob: float = sin(_clock * 4.0) * tile * 0.02
			var tip := Vector2(0.0, head - tile * 0.06 + bob)
			draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-tile * 0.06, -tile * 0.1), tip + Vector2(tile * 0.06, -tile * 0.1)]), Color(1.0, 0.85, 0.3, strength))
		ConditionDefinition.RoundThem.EXCLAIM:
			var bob: float = sin(_clock * 5.0) * tile * 0.012
			var top := Vector2(0.0, head - tile * 0.2 + bob)
			draw_line(top, top + Vector2(0.0, tile * 0.1), Color(1.0, 0.9, 0.3, strength), tile * 0.03)
			draw_circle(top + Vector2(0.0, tile * 0.15), tile * 0.018, Color(1.0, 0.9, 0.3, strength))


func _star(at: Vector2, size: float, colour: Color):
	var points := PackedVector2Array()
	for i in 10:
		var radius: float = size if i % 2 == 0 else size * 0.45
		var angle: float = TAU * float(i) / 10.0 - PI * 0.5
		points.append(at + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, colour)


## What comes off them, for the one shown. A picture in the slot takes the place of the placeholder's dots.
func _set_particles(condition: ConditionDefinition):
	var kind: int = condition.off_them if condition != null else ConditionDefinition.OffThem.NONE
	if kind == _particles_for:
		return
	_particles_for = kind
	if _particles != null and is_instance_valid(_particles):
		_particles.emitting = false
		_particles.finished.connect(_particles.queue_free)
		_particles = null
	if kind == ConditionDefinition.OffThem.NONE:
		return
	var tile := float(Grid.TILE_SIZE)
	var dots := CPUParticles2D.new()
	dots.local_coords = false
	dots.one_shot = false
	dots.amount = 10
	dots.lifetime = 1.0
	dots.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dots.emission_rect_extents = Vector2(tile * 0.16, tile * 0.3)
	dots.position = Vector2(0.0, -tile * 0.05)
	dots.scale_amount_min = tile * 0.012
	dots.scale_amount_max = tile * 0.024
	dots.gravity = Vector2.ZERO
	dots.spread = 25.0
	dots.texture = condition.off_them_picture
	match kind:
		ConditionDefinition.OffThem.EMBERS:
			dots.color = Color(1.0, 0.55, 0.2)
			dots.direction = Vector2(0.0, -1.0)
			dots.initial_velocity_min = tile * 0.25
			dots.initial_velocity_max = tile * 0.5
		ConditionDefinition.OffThem.DRIPS:
			dots.color = Color(0.55, 0.85, 0.3)
			dots.direction = Vector2(0.0, 1.0)
			dots.initial_velocity_min = tile * 0.2
			dots.initial_velocity_max = tile * 0.35
			dots.gravity = Vector2(0.0, tile * 0.5)
		ConditionDefinition.OffThem.FROST:
			dots.color = Color(0.75, 0.92, 1.0)
			dots.direction = Vector2(0.0, -1.0)
			dots.initial_velocity_min = tile * 0.04
			dots.initial_velocity_max = tile * 0.12
			dots.lifetime = 1.6
		ConditionDefinition.OffThem.SOFT_LIGHT:
			dots.color = Color(1.0, 0.95, 0.65)
			dots.direction = Vector2(0.0, -1.0)
			dots.initial_velocity_min = tile * 0.08
			dots.initial_velocity_max = tile * 0.18
			dots.lifetime = 1.5
			dots.amount = 8
		ConditionDefinition.OffThem.SPARKS:
			dots.color = Color(0.7, 0.8, 1.0)
			dots.direction = Vector2(0.0, -1.0)
			dots.spread = 180.0
			dots.initial_velocity_min = tile * 0.2
			dots.initial_velocity_max = tile * 0.45
			dots.lifetime = 0.5
		ConditionDefinition.OffThem.WIND:
			dots.color = Color(0.85, 0.95, 0.9, 0.7)
			dots.direction = Vector2(1.0, 0.0)
			dots.initial_velocity_min = tile * 0.4
			dots.initial_velocity_max = tile * 0.8
			dots.lifetime = 0.6
	add_child(dots)
	_particles = dots
