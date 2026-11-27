extends Control
class_name CardIcon
## A small picture of the card game: the picture given it (a relic's own), else its slot's (CardLooks), else, while that slot is
## empty, a stand-in drawn here in code: a sword for an attack, a shield for Block, a letter in a circle for a status, and so on.
## Placeholders all of them (the designer makes the real art).

const GOLD := Color("e8c872")
const STEEL := Color("c9d6e3")
const STEEL_DARK := Color("6f7f90")
const BLOCK_BLUE := Color("7fb4ea")
const BLOCK_DARK := Color("2d5a8c")
const RED := Color("e07a6a")
const GREEN := Color("8fd6a0")
const FIRE := Color("f0a050")
const FIRE_CORE := Color("ffe08a")
const WOOD := Color("7a5236")
const WOOD_DARK := Color("4a3020")
const INK := Color("dce8f5")
const NIGHT := Color("1c2531")

## Which slot it shows (CardLooks), and so which stand-in.
var what: StringName = &""
## A picture of its own, over the slot's (a relic's, a status's when given).
var texture: Texture2D = null
## The stand-in's colour (a status's, a relic's).
var tint := Color.WHITE
## The letter a stand-in circle shows (a status, a relic).
var letter := ""


func _init():
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows slot `slot`, or `own` over it, the stand-in in `colour` with `initial` when it has to be drawn.
func show_icon(slot: StringName, own: Texture2D = null, colour: Color = Color.WHITE, initial: String = "") -> CardIcon:
	what = slot
	texture = own
	tint = colour
	letter = initial
	queue_redraw()
	return self


## Whether it shows a picture rather than a stand-in.
func has_picture() -> bool:
	return texture != null or CardLooks.picture(what) != null


func _draw():
	var rect := Rect2(Vector2.ZERO, size)
	var picture: Texture2D = texture if texture != null else CardLooks.picture(what)
	if picture != null:
		draw_texture_rect(picture, fit(picture.get_size(), rect), false)
		return
	CardIcon.stand_in(self, what, rect, tint, letter)


## `texture_size` fitted inside `rect`, keeping its shape, in the middle.
static func fit(texture_size: Vector2, rect: Rect2) -> Rect2:
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return rect
	var scale := minf(rect.size.x / texture_size.x, rect.size.y / texture_size.y)
	var drawn := texture_size * scale
	return Rect2(rect.position + (rect.size - drawn) / 2.0, drawn)


## Draws the stand-in for `slot` on `canvas` inside `rect`.
static func stand_in(canvas: CanvasItem, slot: StringName, rect: Rect2, colour: Color = Color.WHITE, initial: String = ""):
	var centre := rect.get_center()
	var side := minf(rect.size.x, rect.size.y)
	match slot:
		&"card_back":
			_card_back(canvas, rect)
		&"energy_orb":
			_orb(canvas, centre, side * 0.5)
		&"block_shield", &"intent_block":
			_shield(canvas, centre, side, BLOCK_BLUE, BLOCK_DARK)
		&"intent_attack":
			_sword(canvas, centre, side * 0.9, 45.0)
		&"intent_attack_heavy":
			_sword(canvas, centre, side * 1.05, 45.0, 1.5)
		&"intent_grow":
			_arrow_up(canvas, centre, side, RED.lightened(0.1))
		&"intent_curse":
			_skull(canvas, centre, side * 0.8, Color("b48ad8"))
		&"intent_unknown", &"room_event":
			_letter(canvas, centre, side, "?", Color("8296a9"), INK)
		&"intent_asleep":
			_letter(canvas, centre, side, "Z", Color("3a4a78"), Color("9ab0f0"))
		&"intent_encrypted":
			# Ciphertext: a block of green code-marks.
			_letter(canvas, centre, side, "#", Color("1d3a28"), Color("6fe08a"))
		&"fragment":
			_letter(canvas, centre, side, "{}", Color("2a3a5a"), Color("9cc8f0"))
		# The designer's "try them all" (2026-11-27): Tethers, the Message's word, a Blessing.
		&"intent_tether":
			_letter(canvas, centre, side, "~", Color("1e4a44"), Color("7fe0c8"))
		&"intent_cut":
			_letter(canvas, centre, side, "X", Color("4a2424"), Color("ff9a8a"))
		&"message_word":
			_letter(canvas, centre, side, "\"", Color("4a4026"), Color("e8d8a0"))
		&"blessing":
			_letter(canvas, centre, side, "*", Color("3a3058"), Color("e0d0ff"))
		&"intent_curled":
			_shield(canvas, centre, side, Color("5a8ab0"), Color("2a4a68"))
			canvas.draw_circle(centre, side * 0.12, Color("c9d6e3"))
		&"intent_help":
			_shield(canvas, centre, side * 0.9, GREEN.darkened(0.2), GREEN.darkened(0.6))
		&"intent_heal":
			canvas.draw_rect(Rect2(centre.x - side * 0.12, centre.y - side * 0.36, side * 0.24, side * 0.72), GREEN)
			canvas.draw_rect(Rect2(centre.x - side * 0.36, centre.y - side * 0.12, side * 0.72, side * 0.24), GREEN)
		&"intent_summon":
			_letter(canvas, centre, side, "+", Color("6a4a2a"), GOLD)
		&"intent_card", &"card_face_status":
			var card := Rect2(centre.x - side * 0.26, centre.y - side * 0.38, side * 0.52, side * 0.76)
			canvas.draw_rect(card, Color("6a6470"))
			canvas.draw_rect(card, Color("2a2430"), false, maxf(side * 0.05, 1.2))
			canvas.draw_line(card.position + Vector2(side * 0.1, side * 0.2), card.end - Vector2(side * 0.1, side * 0.2), RED, maxf(side * 0.06, 1.5))
		&"intent_steal":
			_arrow_up(canvas, centre, side * 0.8, Color("b0a080"))
		&"intent_countdown":
			_letter(canvas, centre, side, "!", Color("8a3a2a"), FIRE_CORE)
		&"room_fight":
			_sword(canvas, centre, side * 0.9, 45.0)
			_sword(canvas, centre, side * 0.9, -45.0)
		&"room_elite":
			_horns(canvas, centre, side)
			_skull(canvas, centre + Vector2(0, side * 0.06), side * 0.72, Color("e0d6c8"))
		&"room_rest":
			_flame(canvas, centre, side * 0.85)
		&"room_shop":
			_coin(canvas, centre + Vector2(-side * 0.12, side * 0.08), side * 0.3)
			_coin(canvas, centre + Vector2(side * 0.14, -side * 0.06), side * 0.3)
		&"room_chest", &"chest_closed":
			_chest(canvas, rect, false)
		&"chest_open":
			_chest(canvas, rect, true)
		&"room_boss":
			_crown(canvas, centre, side)
		&"map_marker":
			_marker(canvas, centre, side * 0.42)
		&"coin":
			_coin(canvas, centre, side * 0.5)
		&"rest_fire":
			_flame(canvas, centre, side)
		_:
			# A status (a letter in a circle of its colour), or a relic with no picture.
			_letter(canvas, centre, side, initial if initial != "" else String(slot).trim_prefix("status_").substr(0, 1).to_upper(),
				colour.darkened(0.35), colour.lightened(0.45))


static func _font() -> Font:
	return ThemeDB.fallback_font


static func _letter(canvas: CanvasItem, centre: Vector2, side: float, text: String, fill: Color, edge: Color):
	var radius := side * 0.46
	canvas.draw_circle(centre, radius, fill)
	canvas.draw_arc(centre, radius, 0.0, TAU, 32, edge, maxf(side * 0.07, 1.5), true)
	var font := _font()
	var font_size := int(side * 0.58)
	var baseline := centre.y + (font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0
	canvas.draw_string(font, Vector2(centre.x - radius, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size, Color.WHITE)


static func _card_back(canvas: CanvasItem, rect: Rect2):
	var box := StyleBoxFlat.new()
	box.bg_color = Color("22344c")
	box.border_color = Color("4a86c8")
	box.set_border_width_all(maxi(int(rect.size.x * 0.03), 2))
	box.set_corner_radius_all(int(rect.size.x * 0.06))
	canvas.draw_style_box(box, rect)
	var inner := rect.grow(-rect.size.x * 0.1)
	canvas.draw_rect(inner, Color("2d4766"), false, maxf(rect.size.x * 0.015, 1.0))
	var centre := rect.get_center()
	var r := minf(rect.size.x, rect.size.y) * 0.18
	var diamond := PackedVector2Array([centre + Vector2(0, -r * 1.3), centre + Vector2(r, 0), centre + Vector2(0, r * 1.3), centre + Vector2(-r, 0)])
	canvas.draw_colored_polygon(diamond, Color("4a86c8"))
	var small := PackedVector2Array([centre + Vector2(0, -r * 0.6), centre + Vector2(r * 0.45, 0), centre + Vector2(0, r * 0.6), centre + Vector2(-r * 0.45, 0)])
	canvas.draw_colored_polygon(small, Color("9cc3ee"))


static func _orb(canvas: CanvasItem, centre: Vector2, radius: float):
	for step in 6:
		var share := 1.0 - float(step) / 6.0
		canvas.draw_circle(centre, radius * share, Color("1d4f86").lerp(Color("7fc2ff"), float(step) / 5.0))
	canvas.draw_circle(centre + Vector2(-radius * 0.3, -radius * 0.35), radius * 0.18, Color(1, 1, 1, 0.45))
	canvas.draw_arc(centre, radius, 0.0, TAU, 48, Color("bfe0ff"), maxf(radius * 0.08, 1.5), true)


static func _shield(canvas: CanvasItem, centre: Vector2, side: float, fill: Color, edge: Color):
	var w := side * 0.36
	var h := side * 0.44
	var points := PackedVector2Array([
		centre + Vector2(-w, -h * 0.85), centre + Vector2(0, -h), centre + Vector2(w, -h * 0.85),
		centre + Vector2(w, h * 0.05), centre + Vector2(w * 0.6, h * 0.6), centre + Vector2(0, h),
		centre + Vector2(-w * 0.6, h * 0.6), centre + Vector2(-w, h * 0.05)])
	canvas.draw_colored_polygon(points, fill)
	var outline := points.duplicate()
	outline.append(points[0])
	canvas.draw_polyline(outline, edge, maxf(side * 0.06, 1.5), true)
	canvas.draw_line(centre + Vector2(0, -h * 0.75), centre + Vector2(0, h * 0.7), edge.lerp(fill, 0.5), maxf(side * 0.04, 1.0), true)


static func _sword(canvas: CanvasItem, centre: Vector2, length: float, degrees: float, heft: float = 1.0):
	canvas.draw_set_transform(centre, deg_to_rad(degrees), Vector2.ONE)
	var w := length * 0.075 * heft
	var blade := PackedVector2Array([Vector2(-w, length * 0.12), Vector2(-w, -length * 0.36), Vector2(0, -length * 0.5),
		Vector2(w, -length * 0.36), Vector2(w, length * 0.12)])
	canvas.draw_colored_polygon(blade, STEEL)
	canvas.draw_line(Vector2(0, -length * 0.42), Vector2(0, length * 0.1), STEEL_DARK, maxf(w * 0.35, 1.0), true)
	canvas.draw_rect(Rect2(-length * 0.2 * heft, length * 0.12, length * 0.4 * heft, length * 0.07), GOLD)
	canvas.draw_rect(Rect2(-w * 0.8, length * 0.19, w * 1.6, length * 0.2), WOOD)
	canvas.draw_circle(Vector2(0, length * 0.42), w * 1.3, GOLD)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _arrow_up(canvas: CanvasItem, centre: Vector2, side: float, colour: Color):
	var w := side * 0.36
	var h := side * 0.42
	var points := PackedVector2Array([centre + Vector2(0, -h), centre + Vector2(w, -h * 0.05), centre + Vector2(w * 0.42, -h * 0.05),
		centre + Vector2(w * 0.42, h), centre + Vector2(-w * 0.42, h), centre + Vector2(-w * 0.42, -h * 0.05), centre + Vector2(-w, -h * 0.05)])
	canvas.draw_colored_polygon(points, colour)
	var outline := points.duplicate()
	outline.append(points[0])
	canvas.draw_polyline(outline, colour.darkened(0.45), maxf(side * 0.05, 1.2), true)


static func _skull(canvas: CanvasItem, centre: Vector2, side: float, colour: Color):
	var r := side * 0.4
	canvas.draw_circle(centre + Vector2(0, -r * 0.15), r, colour)
	canvas.draw_rect(Rect2(centre.x - r * 0.55, centre.y + r * 0.45, r * 1.1, r * 0.5), colour)
	var hollow := colour.darkened(0.7)
	canvas.draw_circle(centre + Vector2(-r * 0.38, -r * 0.1), r * 0.24, hollow)
	canvas.draw_circle(centre + Vector2(r * 0.38, -r * 0.1), r * 0.24, hollow)
	for tooth in [-0.3, 0.0, 0.3]:
		canvas.draw_line(centre + Vector2(r * tooth, r * 0.5), centre + Vector2(r * tooth, r * 0.92), hollow, maxf(r * 0.08, 1.0))


static func _horns(canvas: CanvasItem, centre: Vector2, side: float):
	var colour := Color("c9b99a")
	for way in [-1.0, 1.0]:
		var horn := PackedVector2Array([centre + Vector2(way * side * 0.18, -side * 0.12), centre + Vector2(way * side * 0.46, -side * 0.46),
			centre + Vector2(way * side * 0.34, -side * 0.06)])
		canvas.draw_colored_polygon(horn, colour)


static func _flame(canvas: CanvasItem, centre: Vector2, side: float):
	var outer := _drop(centre + Vector2(0, side * 0.08), side * 0.32, side * 0.44)
	canvas.draw_colored_polygon(outer, FIRE)
	var inner := _drop(centre + Vector2(0, side * 0.16), side * 0.17, side * 0.26)
	canvas.draw_colored_polygon(inner, FIRE_CORE)
	canvas.draw_rect(Rect2(centre.x - side * 0.34, centre.y + side * 0.36, side * 0.68, side * 0.08), WOOD)


## A drop shape: round at the bottom, a point at the top, about `centre`.
static func _drop(centre: Vector2, radius: float, rise: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.append(centre + Vector2(0, -rise - radius * 0.4))
	for i in 13:
		var angle := lerpf(-PI * 0.15, PI * 1.15, float(i) / 12.0)
		points.append(centre + Vector2(cos(angle), sin(angle)) * radius)
	return points


static func _coin(canvas: CanvasItem, centre: Vector2, radius: float):
	canvas.draw_circle(centre, radius, GOLD.darkened(0.25))
	canvas.draw_circle(centre + Vector2(-radius * 0.06, -radius * 0.06), radius * 0.86, GOLD)
	canvas.draw_arc(centre, radius * 0.6, 0.0, TAU, 24, GOLD.darkened(0.3), maxf(radius * 0.1, 1.0), true)


static func _chest(canvas: CanvasItem, rect: Rect2, open: bool):
	var w := rect.size.x * 0.8
	var h := rect.size.y * 0.5
	var body := Rect2(rect.get_center().x - w / 2.0, rect.position.y + rect.size.y * 0.42, w, h)
	canvas.draw_rect(body, WOOD)
	canvas.draw_rect(body, WOOD_DARK, false, maxf(w * 0.03, 1.5))
	canvas.draw_rect(Rect2(body.position.x, body.position.y + h * 0.35, w, h * 0.12), GOLD.darkened(0.3))
	if open:
		var lid := PackedVector2Array([body.position, body.position + Vector2(w, 0), body.position + Vector2(w * 0.92, -h * 0.7),
			body.position + Vector2(w * 0.08, -h * 0.7)])
		canvas.draw_colored_polygon(lid, WOOD_DARK)
		canvas.draw_rect(Rect2(body.position.x + w * 0.1, body.position.y - h * 0.08, w * 0.8, h * 0.14), FIRE_CORE)
	else:
		canvas.draw_rect(Rect2(body.position.x, body.position.y - h * 0.42, w, h * 0.42), WOOD.lightened(0.08))
		canvas.draw_rect(Rect2(body.position.x, body.position.y - h * 0.42, w, h * 0.42), WOOD_DARK, false, maxf(w * 0.03, 1.5))
		canvas.draw_rect(Rect2(body.get_center().x - w * 0.06, body.position.y - h * 0.12, w * 0.12, h * 0.26), GOLD)


static func _crown(canvas: CanvasItem, centre: Vector2, side: float):
	var w := side * 0.42
	var h := side * 0.32
	var points := PackedVector2Array([centre + Vector2(-w, h), centre + Vector2(-w, -h * 0.5), centre + Vector2(-w * 0.5, 0),
		centre + Vector2(0, -h), centre + Vector2(w * 0.5, 0), centre + Vector2(w, -h * 0.5), centre + Vector2(w, h)])
	canvas.draw_colored_polygon(points, GOLD)
	var outline := points.duplicate()
	outline.append(points[0])
	canvas.draw_polyline(outline, GOLD.darkened(0.45), maxf(side * 0.04, 1.2), true)
	canvas.draw_circle(centre + Vector2(0, h * 0.45), side * 0.06, RED)


static func _marker(canvas: CanvasItem, centre: Vector2, radius: float):
	var points := PackedVector2Array([centre + Vector2(0, -radius), centre + Vector2(radius * 0.75, 0), centre + Vector2(0, radius),
		centre + Vector2(-radius * 0.75, 0)])
	canvas.draw_colored_polygon(points, Color("4a86c8"))
	var outline := points.duplicate()
	outline.append(points[0])
	canvas.draw_polyline(outline, Color.WHITE, maxf(radius * 0.18, 1.5), true)
