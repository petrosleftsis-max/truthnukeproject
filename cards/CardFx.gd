extends Control
class_name CardFx
## What jumps, flies and flashes over the card game's screen (docs/card_game.md "How it feels"): the numbers that jump out of
## whoever is hit or mended, a blow's slash, sparks, embers, drops of poison, shards of broken Block, spikes, coins, rings of light,
## light flowing from one place to another, and any picture flown along an arc. Placeholders drawn in code, each with its picture
## slot in CardLooks (hit_slash, spark, ember, drop, spike, shard, coin). Only to look at: what scatters comes from a generator of
## its own, never from a fight's numbers, and nothing is made where nothing moves (CardFeel.shown).
##
## Places are global (the screen's), as everything that calls it knows them.

const OUTLINE := Color(0.03, 0.04, 0.06, 0.85)
const SPARK := Color("ffe9b0")
const EMBER := Color("ff9a40")
const POISON := Color("8fd66a")
const SHARD := Color("9cc8f0")
const SPIKE := Color("c9d2b0")
const GOLD := Color("e8c872")

var _rng := RandomNumberGenerator.new()


func _init():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 7351


func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _local(at: Vector2) -> Vector2:
	return at - global_position


## A number (or a word) jumping out at `at`: it pops, rises `rise` pixels and fades over `seconds`.
func number(at: Vector2, text: String, colour: Color, font_size: int = 30, rise: float = 46.0, seconds: float = 0.8) -> Label:
	if not CardFeel.shown():
		return null
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.theme_type_variation = GameFonts.HEADER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", OUTLINE)
	label.add_theme_constant_override("outline_size", maxi(int(font_size / 4.0), 4))
	add_child(label)
	label.reset_size()
	label.pivot_offset = label.size / 2.0
	label.position = _local(at) - label.size / 2.0 + Vector2(_rng.randf_range(-10.0, 10.0), 0.0)
	label.scale = Vector2.ONE * 1.6
	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector2.ONE, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(label, "position:y", label.position.y - rise, seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(label, "modulate:a", 0.0, seconds * 0.4).set_delay(seconds * 0.6)
	tween.tween_callback(label.queue_free)
	return label


## A blow's slash across `at`, turned `angle` radians, `length` long.
func slash(at: Vector2, angle: float, colour: Color = Color.WHITE, length: float = 150.0):
	if not CardFeel.shown():
		return
	var cut := _Slash.new()
	cut.position = _local(at)
	cut.rotation = angle
	cut.length = length
	cut.colour = colour
	cut.texture = CardLooks.picture(&"hit_slash")
	add_child(cut)


## `count` bits of `kind` thrown out from `at`: spark (off a blow), ember (a card burning), drop (poison), shard (Block broken),
## coin. `spread` pixels a second at most; `toward` leans them that way.
func burst(at: Vector2, kind: StringName, count: int, spread: float = 260.0, toward: Vector2 = Vector2.ZERO, area: Vector2 = Vector2.ZERO):
	if not CardFeel.shown():
		return
	var bits := _Bits.new()
	bits.kind = kind
	bits.texture = CardLooks.picture(kind)
	bits.position = _local(at)
	match kind:
		&"spark":
			bits.pull = 380.0
			bits.drag = 2.5
		&"ember":
			bits.pull = -90.0
			bits.drag = 1.2
		&"drop":
			bits.pull = 520.0
			bits.drag = 0.5
		&"shard":
			bits.pull = 620.0
			bits.drag = 0.8
		&"coin":
			bits.pull = 700.0
			bits.drag = 0.4
	for i in count:
		var angle := _rng.randf_range(0.0, TAU)
		var speed := _rng.randf_range(spread * 0.35, spread)
		var velocity := Vector2.from_angle(angle) * speed + toward
		var start := Vector2(_rng.randf_range(-area.x, area.x), _rng.randf_range(-area.y, area.y)) / 2.0
		if kind == &"ember":
			velocity = Vector2(_rng.randf_range(-40.0, 40.0), _rng.randf_range(-120.0, -40.0))
		elif kind == &"drop":
			velocity = Vector2(_rng.randf_range(-30.0, 30.0), _rng.randf_range(-60.0, 20.0))
		bits.bits.append({"p": start, "v": velocity, "age": -_rng.randf_range(0.0, 0.12) if kind in [&"ember", &"drop"] else 0.0,
			"life": _rng.randf_range(0.45, 0.85), "size": _rng.randf_range(3.0, 7.0), "spin": _rng.randf_range(-9.0, 9.0),
			"angle": _rng.randf_range(0.0, TAU)})
	add_child(bits)


## A ring of light at `at`, from `from_radius` to `to_radius` over `seconds`, fading.
func ring(at: Vector2, colour: Color, from_radius: float = 20.0, to_radius: float = 90.0, seconds: float = 0.45, width: float = 5.0):
	if not CardFeel.shown():
		return
	var made := _Ring.new()
	made.position = _local(at)
	made.colour = colour
	made.from_radius = from_radius
	made.to_radius = to_radius
	made.seconds = seconds
	made.width = width
	add_child(made)


## `count` bits flowing from `from` to `to` (light into the player's side, spikes back at a striker, coins into the purse), each
## a little after the last; `each` is called as each lands (a coin's tick).
func flow(from: Vector2, to: Vector2, kind: StringName, count: int, colour: Color, seconds: float = 0.4, each: Callable = Callable()):
	if not CardFeel.shown():
		return
	var made := _Flow.new()
	made.kind = kind
	made.colour = colour
	made.texture = CardLooks.picture(kind) if kind in [&"coin", &"spike", &"spark"] else null
	made.each = each
	made.from = _local(from)
	made.to = _local(to)
	for i in count:
		made.bits.append({"delay": i * 0.045, "seconds": seconds * _rng.randf_range(0.85, 1.15), "bend": _rng.randf_range(-70.0, 70.0),
			"landed": false})
	add_child(made)


## Flies `what` (any control, taken from where it is) from `from` to `to` (its middle, global) along an arc `arc` pixels high over
## `seconds`, to `end_scale` of its size, upright by the end, `delay` seconds from now; then frees it and calls `landed`.
func fly(what: Control, from: Vector2, to: Vector2, seconds: float = 0.45, arc: float = 80.0, end_scale: float = 0.4,
		landed: Callable = Callable(), delay: float = 0.0):
	if not CardFeel.shown() or what == null:
		if what != null and is_instance_valid(what):
			what.queue_free()
		if landed.is_valid():
			landed.call()
		return
	if what.get_parent() == null:
		add_child(what)
	elif what.get_parent() != self:
		what.reparent(self, false)
	what.pivot_offset = what.size / 2.0
	what.position = _local(from) - what.pivot_offset
	var start_scale := what.scale
	var tween := what.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_method(_fly_step.bind(what, _local(from), _local(to), arc, start_scale, Vector2.ONE * end_scale, what.rotation), 0.0, 1.0,
		seconds).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(what.queue_free)
	if landed.is_valid():
		tween.tween_callback(landed)


func _fly_step(t: float, what: Control, from: Vector2, to: Vector2, arc: float, start_scale: Vector2, end_scale: Vector2, turn: float):
	if not is_instance_valid(what):
		return
	var top := (from + to) / 2.0 + Vector2(0.0, -arc)
	var at := from.lerp(top, t).lerp(top.lerp(to, t), t)
	what.position = at - what.pivot_offset
	what.scale = start_scale.lerp(end_scale, t)
	what.rotation = lerpf(turn, 0.0, t)


## A picture flown from `from` to `to`: a status's badge, a relic, a coin (CardIcon's slot, or `own`).
func fly_icon(slot: StringName, own: Texture2D, tint: Color, initial: String, from: Vector2, to: Vector2, side: float = 34.0,
		seconds: float = 0.4, arc: float = 60.0, landed: Callable = Callable(), end_scale: float = 0.8):
	if not CardFeel.shown():
		if landed.is_valid():
			landed.call()
		return
	var icon := CardIcon.new()
	icon.size = Vector2.ONE * side
	icon.show_icon(slot, own, tint, initial)
	add_child(icon)
	icon.position = _local(from) - icon.size / 2.0
	fly(icon, from, to, seconds, arc, end_scale, landed)


## Light spilling up out of `at` (a chest opening): rays turning slowly, fading over `seconds`.
func rays(at: Vector2, colour: Color, seconds: float = 1.4):
	if not CardFeel.shown():
		return
	var made := _Rays.new()
	made.position = _local(at)
	made.colour = colour
	made.seconds = seconds
	add_child(made)


## A word across the middle of the screen: "Victory", a boss's name. It comes in hard (from `from_scale`, over `fade_in`), holds
## `hold` seconds and fades (a `hold` under 0 keeps it, for the caller to free); the label is handed back.
func title(at: Vector2, text: String, colour: Color, font_size: int = 64, hold: float = 1.0, from_scale: float = 2.6,
		fade_in: float = 0.1) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.theme_type_variation = GameFonts.HEADER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", OUTLINE)
	label.add_theme_constant_override("outline_size", maxi(int(font_size / 5.0), 6))
	add_child(label)
	label.reset_size()
	label.pivot_offset = label.size / 2.0
	label.position = _local(at) - label.size / 2.0
	if not CardFeel.shown():
		label.visible = false
		label.queue_free()
		return label
	label.scale = Vector2.ONE * from_scale
	label.modulate.a = 0.0
	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector2.ONE, 0.16).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(label, "modulate:a", 1.0, fade_in)
	if hold >= 0.0:
		tween.tween_interval(hold)
		tween.tween_property(label, "modulate:a", 0.0, 0.4)
		tween.tween_callback(label.queue_free)
	return label


## --- What is drawn ---


class _Slash extends Node2D:
	var length := 150.0
	var colour := Color.WHITE
	var texture: Texture2D = null
	var age := 0.0
	const SECONDS := 0.24

	func _process(delta: float):
		age += delta
		if age >= SECONDS:
			queue_free()
		queue_redraw()

	func _draw():
		var grown := minf(age / 0.06, 1.0)
		var fade := 1.0 - clampf((age - 0.06) / (SECONDS - 0.06), 0.0, 1.0)
		var tint := Color(colour, colour.a * fade)
		if texture != null:
			var drawn := Vector2(length * grown, length * 0.26)
			draw_texture_rect(texture, Rect2(-drawn / 2.0, drawn), false, tint)
			return
		var half := length * 0.5 * grown
		# A curved stroke, thickest in the middle.
		var points := PackedVector2Array()
		for i in 9:
			var t := float(i) / 8.0
			points.append(Vector2(lerpf(-half, half, t), -sin(t * PI) * length * 0.12))
		for i in points.size() - 1:
			var middle := 1.0 - absf(float(i) / (points.size() - 2) - 0.5) * 2.0
			draw_line(points[i], points[i + 1], tint, lerpf(2.0, 9.0, middle), true)
		draw_line(points[2], points[6], Color(1, 1, 1, fade), 2.0, true)


class _Bits extends Node2D:
	var kind: StringName = &"spark"
	var texture: Texture2D = null
	var bits: Array = []
	var pull := 0.0
	var drag := 0.0

	func _process(delta: float):
		var any := false
		for bit in bits:
			bit.age += delta
			if bit.age < 0.0:
				any = true
				continue
			if bit.age >= bit.life:
				continue
			any = true
			var velocity: Vector2 = bit.v
			velocity.y += pull * delta
			velocity *= maxf(0.0, 1.0 - drag * delta)
			bit.v = velocity
			bit.p = bit.p + velocity * delta
			bit.angle = bit.angle + bit.spin * delta
		if not any:
			queue_free()
		queue_redraw()

	func _draw():
		for bit in bits:
			if bit.age < 0.0 or bit.age >= bit.life:
				continue
			var fade: float = 1.0 - bit.age / bit.life
			var at: Vector2 = bit.p
			var bit_size: float = bit.size
			if texture != null:
				var side := bit_size * 2.4
				draw_set_transform(at, bit.angle, Vector2.ONE)
				draw_texture_rect(texture, Rect2(-Vector2.ONE * side / 2.0, Vector2.ONE * side), false, Color(1, 1, 1, fade))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				continue
			match kind:
				&"spark":
					var velocity: Vector2 = bit.v
					draw_line(at, at - velocity * 0.035, Color(CardFx.SPARK, fade), maxf(bit_size * 0.4, 1.5), true)
				&"ember":
					draw_circle(at, bit_size * 0.55 * fade + 1.0, Color(CardFx.EMBER, fade))
				&"drop":
					draw_circle(at, bit_size * 0.6, Color(CardFx.POISON, fade))
					draw_line(at, at + Vector2(0, -bit_size * 1.3), Color(CardFx.POISON, fade * 0.7), bit_size * 0.5, true)
				&"shard":
					draw_set_transform(at, bit.angle, Vector2.ONE)
					draw_colored_polygon(PackedVector2Array([Vector2(-bit_size, -bit_size * 0.5), Vector2(bit_size * 1.2, 0),
						Vector2(-bit_size * 0.3, bit_size)]), Color(CardFx.SHARD, fade))
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				&"coin":
					draw_circle(at, bit_size, Color(CardFx.GOLD.darkened(0.25), fade))
					draw_circle(at, bit_size * 0.75, Color(CardFx.GOLD, fade))
				_:
					draw_circle(at, bit_size * 0.5, Color(1, 1, 1, fade))


class _Ring extends Node2D:
	var colour := Color.WHITE
	var from_radius := 20.0
	var to_radius := 90.0
	var seconds := 0.45
	var width := 5.0
	var age := 0.0

	func _process(delta: float):
		age += delta
		if age >= seconds:
			queue_free()
		queue_redraw()

	func _draw():
		var t := clampf(age / seconds, 0.0, 1.0)
		var eased := 1.0 - (1.0 - t) * (1.0 - t)
		draw_arc(Vector2.ZERO, lerpf(from_radius, to_radius, eased), 0.0, TAU, 48, Color(colour, colour.a * (1.0 - t)), width * (1.0 - t * 0.6), true)


class _Flow extends Node2D:
	var kind: StringName = &"spark"
	var colour := Color.WHITE
	var texture: Texture2D = null
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var bits: Array = []
	var each: Callable = Callable()
	var age := 0.0

	func _process(delta: float):
		age += delta
		var any := false
		for bit in bits:
			var t: float = (age - bit.delay) / bit.seconds
			if t < 1.0:
				any = true
			elif not bit.landed:
				bit.landed = true
				if each.is_valid():
					each.call()
		if not any:
			queue_free()
		queue_redraw()

	func _draw():
		for bit in bits:
			var t: float = (age - bit.delay) / bit.seconds
			if t < 0.0 or t >= 1.0:
				continue
			var eased := t * t * (3.0 - 2.0 * t)
			var across := (to - from).normalized().orthogonal()
			var bend: float = bit.bend
			var top := (from + to) / 2.0 + across * bend + Vector2(0, -40.0)
			var at := from.lerp(top, eased).lerp(top.lerp(to, eased), eased)
			var ahead := from.lerp(top, minf(eased + 0.04, 1.0)).lerp(top.lerp(to, minf(eased + 0.04, 1.0)), minf(eased + 0.04, 1.0))
			var fade := minf(1.0, (1.0 - t) * 4.0)
			if texture != null:
				draw_texture_rect(texture, Rect2(at - Vector2.ONE * 8.0, Vector2.ONE * 16.0), false, Color(1, 1, 1, fade))
				continue
			match kind:
				&"card":
					var way_now := (ahead - at).normalized()
					draw_set_transform(at, way_now.angle() + PI / 2.0, Vector2.ONE)
					draw_rect(Rect2(-7, -10, 14, 20), Color(Color("22344c"), fade))
					draw_rect(Rect2(-7, -10, 14, 20), Color(Color("4a86c8"), fade), false, 1.5)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				&"coin":
					draw_circle(at, 6.0, Color(CardFx.GOLD.darkened(0.25), fade))
					draw_circle(at, 4.5, Color(CardFx.GOLD, fade))
				&"spike":
					var way := (ahead - at).normalized()
					if way == Vector2.ZERO:
						way = Vector2.RIGHT
					draw_colored_polygon(PackedVector2Array([at + way * 9.0, at + way.orthogonal() * 3.5, at - way.orthogonal() * 3.5]),
						Color(CardFx.SPIKE, fade))
				_:
					draw_line(at, ahead, Color(colour, fade), 4.0, true)
					draw_circle(at, 3.0, Color(colour.lightened(0.4), fade))


class _Rays extends Node2D:
	var colour := Color.WHITE
	var seconds := 1.4
	var age := 0.0

	func _process(delta: float):
		age += delta
		if age >= seconds:
			queue_free()
		queue_redraw()

	func _draw():
		var t := clampf(age / seconds, 0.0, 1.0)
		var fade := sin(t * PI)
		for i in 9:
			var angle := -PI / 2.0 + (float(i) - 4.0) * 0.22 + sin(age * 1.5 + i) * 0.04
			var reach := 90.0 + 70.0 * fade
			var a := Vector2.from_angle(angle - 0.05) * reach
			var b := Vector2.from_angle(angle + 0.05) * reach
			draw_colored_polygon(PackedVector2Array([Vector2.ZERO, a, b]), Color(colour, 0.35 * fade))
		draw_circle(Vector2.ZERO, 26.0 * fade + 4.0, Color(colour, 0.45 * fade))
