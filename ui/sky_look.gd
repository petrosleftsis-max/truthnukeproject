class_name SkyLook
## The interface's look: T, "K, lighter" (the designer, 2026-11-17, of the looks drawn on 2026-11-13: "Do T: K, Lighter"). Every
## panel is a smooth blue night, deeper at the top, with stars strewn over it as real ones are, never on a pattern; and at its
## lower left corner a few small pixels have come loose, the rest of its edge smooth: the sky beginning to come apart, which the
## story is about. Buttons are rings of light on it (the main one, End Turn, filled), bars are dark with a pale blue fill.
##
## Put on the project theme as the game starts, as the fonts are (GameFonts says why not in ui/blue_theme.tres): `apply()`, from
## the SceneTransition autoload. Drawn in code until the artist's pictures are in their slots (SLOTS, "Slots" in
## docs/feel_built.md, sized as the interface page's "Art to ask for" table): each picture found takes the place of what code
## draws for it. Only to look at: no rule reads any of it.

const SLOTS := "res://art/ui/sky/"

## K's night, top to bottom (the page's #0c1640, #1b3480 at 70%, #2a4ea8).
const NIGHT_TOP := Color("0c1640")
const NIGHT_MIDDLE := Color("1b3480")
const NIGHT_MIDDLE_AT := 0.7
const NIGHT_BOTTOM := Color("2a4ea8")
const EDGE := Color("5b72c4")
const TEXT := Color("e3eaff")
const NAME := Color("f2f5ff")
const BUTTON_TEXT := Color("eef2ff")
const BUTTON_TEXT_OFF := Color("7d89b8")
const BUTTON_EDGE := Color("b9c4ea")
const BUTTON_FILL := Color(0.03, 0.06, 0.19, 0.45)
const BUTTON_HOVER_FILL := Color(0.23, 0.29, 0.6, 0.55)
const BUTTON_HOVER_EDGE := Color("dfe6ff")
const MAIN_FILL := Color("3a4a9a")
const MAIN_EDGE := Color("8fa2ef")
const BAR_TRACK := Color("081030")
const BAR_EDGE := Color("6f84d6")
const BAR_FILL := Color("8fbdf0")
## The loose pixels: two blues, as on the page.
const CRUMB_DARK := Color("2a4ea8")
const CRUMB_LIGHT := Color("3c64c4")
## Stars: white, a cool blue, a warm cream.
const STAR_COLOURS := [Color("ffffff"), Color("cfe0ff"), Color("fff3d6")]
## The old palette's places, in T, for the screens that draw their own cards (the journal, the menus, the sheet, the bags, a
## conversation's answers): a heading, body text, a focus edge, a panel's flat fill, a card at rest, a card lit, a card's edge.
const INK := NAME
const INK_DIM := TEXT
const ACCENT := MAIN_EDGE
const PANEL := Color("0f1b4c")
const CARD := Color(0.04, 0.08, 0.24, 0.72)
const CARD_LIT := Color(0.23, 0.29, 0.6, 0.85)
const CARD_EDGE := Color(0.73, 0.77, 0.92, 0.32)

## How much sky each star has to itself, in square pixels (the page's panel had 40 in about 54,000), and the most on one panel.
const STAR_AREA := 1500.0
const STARS_MOST := 140
## How many of the stars gather about a few places, as a real sky's do, and how many of them are bright ones.
const STARS_GATHERED := 0.3
const STARS_BRIGHT := 0.04
## How rounded a panel and a tooltip are, and how much of the lower edge, from the left corner, has come apart (a share of the
## width, at most LOOSE_MOST pixels; and LOOSE_UP pixels up the left side), with how many loose pixels about it.
const PANEL_CORNER := 8.0
const TOOLTIP_CORNER := 6.0
const LOOSE_SHARE := 0.22
const LOOSE_MOST := 80.0
const LOOSE_UP := 10.0
const CRUMBS := 12

## Theme types for the two other kinds of button: the main one (End Turn) and a skill's slot, which is square, so it is a
## rounded square rather than a pill.
const MAIN_BUTTON := &"MainButton"
const SLOT_BUTTON := &"SlotButton"

static var _pictures := {}
static var _gradient: Texture2D = null


## Dresses the project theme in T. Called once, by an autoload, after GameFonts.apply.
static func apply() -> void:
	var theme := ThemeDB.get_project_theme()
	if theme == null:
		return
	var sky := panel()
	for type in [&"Panel", &"PanelContainer", &"PopupPanel", &"TabContainer"]:
		theme.set_stylebox(&"panel", type, sky)
	theme.set_stylebox(&"panel", &"TooltipPanel", panel(true, Vector4(9, 7, 9, 7), "tooltip_frame", TOOLTIP_CORNER))
	theme.set_stylebox(&"panel", &"PopupMenu", panel(true, Vector4(6, 6, 6, 6), "tooltip_frame", TOOLTIP_CORNER))
	# Buttons: rings of light on the night. The main kind is filled; a skill's slot is a rounded square.
	theme.set_type_variation(MAIN_BUTTON, &"Button")
	theme.set_type_variation(SLOT_BUTTON, &"Button")
	for state in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		for type in [&"Button", &"OptionButton", &"MenuButton"]:
			theme.set_stylebox(state, type, button(state, &""))
		theme.set_stylebox(state, MAIN_BUTTON, button(state, &"main"))
		theme.set_stylebox(state, SLOT_BUTTON, button(state, &"slot"))
	for type in [&"Button", &"OptionButton", &"MenuButton", &"CheckBox", &"CheckButton"]:
		theme.set_color(&"font_color", type, BUTTON_TEXT)
		theme.set_color(&"font_hover_color", type, NAME)
		theme.set_color(&"font_pressed_color", type, NAME)
		theme.set_color(&"font_focus_color", type, NAME)
		theme.set_color(&"font_hover_pressed_color", type, NAME)
		theme.set_color(&"font_disabled_color", type, BUTTON_TEXT_OFF)
	# Words.
	theme.set_color(&"font_color", &"Label", TEXT)
	theme.set_color(&"font_color", GameFonts.HEADER, NAME)
	theme.set_color(&"default_color", &"RichTextLabel", TEXT)
	theme.set_color(&"font_color", &"TooltipLabel", BUTTON_TEXT)
	theme.set_color(&"font_color", &"PopupMenu", TEXT)
	theme.set_color(&"font_hover_color", &"PopupMenu", NAME)
	theme.set_stylebox(&"hover", &"PopupMenu", _flat(BUTTON_HOVER_FILL, Color.TRANSPARENT, 0, 6.0))
	# Bars: dark, with a pale blue fill. Flat boxes still, since the HUD colours its health bars' fills itself.
	theme.set_stylebox(&"background", &"ProgressBar", _flat(BAR_TRACK, BAR_EDGE, 1, 3.0))
	theme.set_stylebox(&"fill", &"ProgressBar", _flat(BAR_FILL, Color.TRANSPARENT, 0, 2.0))
	# Tabs: the chosen one lit as the main button is.
	var chosen := _picture("tab_chosen")
	var other := _picture("tab")
	theme.set_stylebox(&"tab_selected", &"TabBar", _nine(chosen, 8.0, Vector4(12, 5, 12, 5)) if chosen != null else _tab(MAIN_FILL, MAIN_EDGE))
	theme.set_stylebox(&"tab_unselected", &"TabBar", _nine(other, 8.0, Vector4(12, 5, 12, 5)) if other != null else _tab(BUTTON_FILL, Color(BUTTON_EDGE, 0.5)))
	theme.set_stylebox(&"tab_hovered", &"TabBar", _tab(BUTTON_HOVER_FILL, BUTTON_EDGE))
	for type in [&"TabBar", &"TabContainer"]:
		theme.set_stylebox(&"tab_selected", type, theme.get_stylebox(&"tab_selected", &"TabBar"))
		theme.set_stylebox(&"tab_unselected", type, theme.get_stylebox(&"tab_unselected", &"TabBar"))
		theme.set_stylebox(&"tab_hovered", type, theme.get_stylebox(&"tab_hovered", &"TabBar"))
		theme.set_color(&"font_selected_color", type, NAME)
		theme.set_color(&"font_unselected_color", type, Color(TEXT, 0.75))
		theme.set_color(&"font_hovered_color", type, NAME)
	# Typing: a dark well with a pale edge.
	var well := _flat(BAR_TRACK, Color(BAR_EDGE, 0.8), 1, 6.0)
	well.content_margin_left = 8
	well.content_margin_right = 8
	well.content_margin_top = 4
	well.content_margin_bottom = 4
	theme.set_stylebox(&"normal", &"LineEdit", well)
	theme.set_stylebox(&"read_only", &"LineEdit", well)
	var typing := _flat(Color.TRANSPARENT, BUTTON_EDGE, 2, 6.0)
	typing.draw_center = false
	theme.set_stylebox(&"focus", &"LineEdit", typing)
	theme.set_color(&"font_color", &"LineEdit", TEXT)
	theme.set_color(&"font_placeholder_color", &"LineEdit", Color(TEXT, 0.45))
	theme.set_color(&"caret_color", &"LineEdit", NAME)


## A panel's night, for the theme and for a panel that makes its own: `stars` strewn on it, its content `margins` (left, top,
## right, bottom), the artist's frame from `frame_slot` drawn over its edge if there is one, rounded `corner`.
static func panel(stars: bool = true, margins: Vector4 = Vector4(10, 8, 10, 8), frame_slot: String = "frame", corner: float = PANEL_CORNER) -> StyleBox:
	var box := SkyPanel.new()
	box.stars = stars
	box.corner = corner
	box.content_margin_left = margins.x
	box.content_margin_top = margins.y
	box.content_margin_right = margins.z
	box.content_margin_bottom = margins.w
	box.night = _picture("night")
	box.bright = _picture("star_bright")
	box.frame = _picture(frame_slot)
	box.frame_corner = 14.0 if frame_slot == "tooltip_frame" else 32.0
	return box


## A skill's slot: its icon reaches the slot's ring of light, and the corners are rounded only as far as a square icon can follow
## (the designer, 2026-11-17: "make sure the skill icons occupy the entire skill slot of the UI, right now there are gaps around
## it"; it was 6 and 5 in, with corners of 10; and then "make the skill outlines a bit thicker": the ring 2 for 1, the icon just
## inside it).
const SLOT_RING := 2
const SLOT_EDGE := 2.0
const SLOT_CORNER := 3


## A button in one `state` (normal, hover, pressed, disabled, focus) of a `kind`: &"" a ring of light (a pill), &"main" filled,
## &"slot" a rounded square for a skill's icon. The artist's picture from its slot if there is one (a nine-slice 64 x 32,
## corners 10).
static func button(state: StringName, kind: StringName) -> StyleBox:
	var slot := kind == &"slot"
	var picture := _picture(("main_button_" if kind == &"main" else "button_") + String(state))
	if picture != null:
		return _nine(picture, 10.0, Vector4.ONE * SLOT_EDGE if slot else Vector4(14, 5, 14, 5))
	var main := kind == &"main"
	var box := StyleBoxFlat.new()
	box.anti_aliasing = true
	box.corner_detail = 10
	box.set_corner_radius_all(SLOT_CORNER if slot else 64)
	box.set_border_width_all((SLOT_RING if slot else 1) + (1 if state == &"focus" else 0))
	box.content_margin_left = SLOT_EDGE if slot else 14.0
	box.content_margin_right = SLOT_EDGE if slot else 14.0
	box.content_margin_top = SLOT_EDGE if slot else 5.0
	box.content_margin_bottom = SLOT_EDGE if slot else 5.0
	match state:
		&"hover":
			box.bg_color = MAIN_FILL.lightened(0.15) if main else BUTTON_HOVER_FILL
			box.border_color = BUTTON_HOVER_EDGE
		&"pressed":
			box.bg_color = MAIN_FILL.darkened(0.2) if main else MAIN_FILL
			box.border_color = MAIN_EDGE
		&"disabled":
			box.bg_color = Color(MAIN_FILL, 0.35) if main else Color(BUTTON_FILL, 0.25)
			box.border_color = Color(BUTTON_EDGE, 0.3)
		&"focus":
			box.draw_center = false
			box.border_color = NAME
		_:
			box.bg_color = MAIN_FILL if main else BUTTON_FILL
			box.border_color = MAIN_EDGE if main else BUTTON_EDGE
	return box


static func _flat(fill: Color, edge: Color, width: int, corner: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.anti_aliasing = true
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(width)
	box.set_corner_radius_all(int(corner))
	return box


static func _tab(fill: Color, edge: Color) -> StyleBoxFlat:
	var box := _flat(fill, edge, 1, 8.0)
	box.corner_radius_bottom_left = 0
	box.corner_radius_bottom_right = 0
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	return box


static func _nine(picture: Texture2D, corner: float, margins: Vector4) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = picture
	box.texture_margin_left = corner
	box.texture_margin_top = corner
	box.texture_margin_right = corner
	box.texture_margin_bottom = corner
	box.content_margin_left = margins.x
	box.content_margin_top = margins.y
	box.content_margin_right = margins.z
	box.content_margin_bottom = margins.w
	return box


## The artist's picture in the slot `name` (without ".png"), or null.
static func _picture(name: String) -> Texture2D:
	var path := SLOTS + name + ".png"
	if not _pictures.has(path):
		_pictures[path] = load(path) if ResourceLoader.exists(path) else null
	return _pictures[path]


## K's night as a picture, top to bottom, made once: what a panel shows while the slot "night" is empty.
static func gradient() -> Texture2D:
	if _gradient == null:
		var stops := Gradient.new()
		stops.offsets = PackedFloat32Array([0.0, NIGHT_MIDDLE_AT, 1.0])
		stops.colors = PackedColorArray([NIGHT_TOP, NIGHT_MIDDLE, NIGHT_BOTTOM])
		var picture := GradientTexture2D.new()
		picture.gradient = stops
		picture.width = 4
		picture.height = 128
		picture.fill_from = Vector2(0.0, 0.0)
		picture.fill_to = Vector2(0.0, 1.0)
		_gradient = picture
	return _gradient


## The outline of `rect` with its corners rounded by `radius`, clockwise from the top left, each corner a quarter circle.
static func rounded(rect: Rect2, radius: float, steps: int = 5) -> PackedVector2Array:
	if radius <= 0.5:
		return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	var points := PackedVector2Array()
	var centres := [rect.position + Vector2(radius, radius), Vector2(rect.end.x - radius, rect.position.y + radius),
		rect.end - Vector2(radius, radius), Vector2(rect.position.x + radius, rect.end.y - radius)]
	for corner in 4:
		var start: float = PI + PI * 0.5 * corner
		for step in steps + 1:
			var angle: float = start + PI * 0.5 * step / steps
			points.append(centres[corner] + Vector2(cos(angle), sin(angle)) * radius)
	return points


## The stars on a panel: strewn, a few gathered about places, fewer and dimmer lower down where the night is paler; a few of them
## bright (the artist's `bright` picture, else a cross of pixels).
static func strew_stars(item: RID, rect: Rect2, random: RandomNumberGenerator, bright: Texture2D) -> int:
	var count := clampi(int(rect.size.x * rect.size.y / STAR_AREA), 2, STARS_MOST)
	var places := []
	for i in 3:
		places.append(Vector2(random.randf(), pow(random.randf(), 1.4)))
	var drawn := 0
	for i in count:
		var at: Vector2
		if random.randf() < STARS_GATHERED:
			var place: Vector2 = places[random.randi() % places.size()]
			at = place + Vector2(random.randfn(0.0, 0.07), random.randfn(0.0, 0.06))
		else:
			at = Vector2(random.randf(), pow(random.randf(), 1.7))
		if at.x < 0.02 or at.x > 0.98 or at.y < 0.03 or at.y > 0.94:
			continue
		var point := (rect.position + at * rect.size).floor()
		var colour: Color = STAR_COLOURS[random.randi() % STAR_COLOURS.size()]
		colour.a = lerpf(0.3, 0.95, random.randf()) * (1.0 - at.y * 0.55)
		if random.randf() < STARS_BRIGHT:
			if bright != null:
				RenderingServer.canvas_item_add_texture_rect(item, Rect2(point - bright.get_size() * 0.5, bright.get_size()), bright.get_rid(), false, colour)
			else:
				RenderingServer.canvas_item_add_rect(item, Rect2(point, Vector2(2, 2)), Color(colour, minf(colour.a + 0.2, 1.0)))
				RenderingServer.canvas_item_add_rect(item, Rect2(point + Vector2(-2, 0.5), Vector2(6, 1)), Color(colour, colour.a * 0.45))
				RenderingServer.canvas_item_add_rect(item, Rect2(point + Vector2(0.5, -2), Vector2(1, 6)), Color(colour, colour.a * 0.45))
		else:
			var size := 1.0 if random.randf() < 0.62 else (2.0 if random.randf() < 0.8 else 3.0)
			RenderingServer.canvas_item_add_rect(item, Rect2(point, Vector2(size, size)), colour)
		drawn += 1
	return drawn


## The edge of a panel: whole but for its lower left corner, if `loose`, where it is only pixels here and there.
static func edge(item: RID, rect: Rect2, radius: float, loose: bool):
	var outline := rounded(rect, radius)
	if not loose or rect.size.x < 40.0 or rect.size.y < 30.0:
		var closed := outline.duplicate()
		closed.append(outline[0])
		RenderingServer.canvas_item_add_polyline(item, closed, PackedColorArray([EDGE]), 1.0, true)
		return
	# From up the left side, round over the top and down, and along the bottom to where it comes apart.
	var steps := outline.size() / 4 - 1
	var apart_x := rect.position.x + radius + minf(rect.size.x * LOOSE_SHARE, LOOSE_MOST)
	var apart_y := rect.end.y - radius - LOOSE_UP
	var whole := PackedVector2Array([Vector2(rect.position.x, apart_y)])
	for i in range(0, (steps + 1) * 3):
		whole.append(outline[i])
	whole.append(Vector2(apart_x, rect.end.y))
	RenderingServer.canvas_item_add_polyline(item, whole, PackedColorArray([EDGE]), 1.0, true)
	# What is left of the edge there: a pixel now and then, more of them nearer where it is whole.
	var corner_path := PackedVector2Array([Vector2(apart_x, rect.end.y)])
	for i in range((steps + 1) * 3, outline.size()):
		corner_path.append(outline[i])
	corner_path.append(Vector2(rect.position.x, apart_y))
	var random := RandomNumberGenerator.new()
	random.seed = hash([item.get_id(), "edge"])
	var length := 0.0
	var total := 0.0
	for i in corner_path.size() - 1:
		total += corner_path[i].distance_to(corner_path[i + 1])
	for i in corner_path.size() - 1:
		var from := corner_path[i]
		var to := corner_path[i + 1]
		var piece := from.distance_to(to)
		var walked := 0.0
		while walked < piece:
			var share := (length + walked) / maxf(total, 1.0)
			# Most of it near the whole edge's ends, least at the corner itself.
			var keep := 0.85 - 0.6 * sin(share * PI)
			if random.randf() < keep:
				var at := from.lerp(to, walked / piece).floor() + Vector2(random.randi_range(-1, 0), random.randi_range(-1, 0))
				RenderingServer.canvas_item_add_rect(item, Rect2(at, Vector2(2, 2)) if random.randf() < 0.3 else Rect2(at, Vector2(1, 1)), EDGE)
			walked += 3.0
		length += piece


## The loose pixels at a panel's lower left corner: a few just inside it, lighter than the night there, and a few fallen just
## outside it.
static func loosen(item: RID, rect: Rect2, random: RandomNumberGenerator) -> int:
	if rect.size.x < 40.0 or rect.size.y < 30.0:
		return 0
	var reach := minf(rect.size.x * LOOSE_SHARE, LOOSE_MOST) + PANEL_CORNER
	var drawn := 0
	for i in CRUMBS:
		var size := float([2, 2, 3, 4][random.randi() % 4])
		var x := rect.position.x + 2.0 + pow(random.randf(), 1.3) * reach
		var fallen := random.randf() < 0.35
		var y: float
		if fallen:
			y = rect.end.y + 1.0 + random.randf() * 6.0
		else:
			y = rect.end.y - 3.0 - size - pow(random.randf(), 1.5) * 14.0
			# Inside the rounded corner only.
			var centre := Vector2(rect.position.x + PANEL_CORNER, rect.end.y - PANEL_CORNER)
			if x < centre.x and y > centre.y and Vector2(x, y).distance_to(centre) > PANEL_CORNER - 1.0:
				continue
		var colour := (CRUMB_DARK if random.randf() < 0.5 else EDGE) if fallen else CRUMB_LIGHT
		colour.a = 0.75 if fallen else 0.9
		RenderingServer.canvas_item_add_rect(item, Rect2(Vector2(x, y).floor(), Vector2(size, size)), colour)
		drawn += 1
	return drawn


## A panel's night, drawn by SkyLook: the sky inside its rounded edge, the stars, the edge (or the artist's frame over it) and the
## loose pixels at its lower left corner. The stars and the pixels fall where a number made from the panel's own canvas item and
## size says, so each panel has a sky of its own that stays put while it is open.
class SkyPanel extends StyleBox:
	var corner := 8.0
	var stars := true
	var loose := true
	## The artist's, from SkyLook's slots: the night stretched top to bottom, a bright star, a frame over the edge (a nine-slice
	## with `frame_corner` corners).
	var night: Texture2D = null
	var bright: Texture2D = null
	var frame: Texture2D = null
	var frame_corner := 32.0
	## Lit up under the pointer (`lit`): a whole ring in this colour over the edge or the frame, when it has any alpha, and a
	## little light over the sky.
	var ring := Color(0, 0, 0, 0)
	var ring_width := 2.0
	var lift := 0.0

	## A copy of this night lit up, as a portrait under the pointer is: ringed in `colour`, the sky lifted by `lifted`. Made
	## by hand, since a duplicate() of a scripted box keeps none of its own settings.
	func lit(colour: Color, width: float = 2.0, lifted: float = 0.06) -> SkyPanel:
		var copy := SkyPanel.new()
		copy.corner = corner
		copy.stars = stars
		copy.loose = loose
		copy.night = night
		copy.bright = bright
		copy.frame = frame
		copy.frame_corner = frame_corner
		copy.content_margin_left = content_margin_left
		copy.content_margin_top = content_margin_top
		copy.content_margin_right = content_margin_right
		copy.content_margin_bottom = content_margin_bottom
		copy.ring = colour
		copy.ring_width = width
		copy.lift = lifted
		return copy

	func _draw(item: RID, rect: Rect2) -> void:
		if rect.size.x < 2.0 or rect.size.y < 2.0:
			return
		var radius := minf(corner, minf(rect.size.x, rect.size.y) * 0.5)
		var outline := SkyLook.rounded(rect, radius)
		var uvs := PackedVector2Array()
		for point in outline:
			uvs.append((point - rect.position) / rect.size)
		var sky: Texture2D = night if night != null else SkyLook.gradient()
		RenderingServer.canvas_item_add_polygon(item, outline, PackedColorArray([Color.WHITE]), uvs, sky.get_rid())
		if lift > 0.0:
			RenderingServer.canvas_item_add_polygon(item, outline, PackedColorArray([Color(1, 1, 1, lift)]))
		var random := RandomNumberGenerator.new()
		random.seed = hash([item.get_id(), int(rect.size.x), int(rect.size.y)])
		if stars:
			SkyLook.strew_stars(item, rect, random, bright)
		if frame != null:
			var corners := Vector2(frame_corner, frame_corner)
			RenderingServer.canvas_item_add_nine_patch(item, rect, Rect2(Vector2.ZERO, frame.get_size()), frame.get_rid(), corners, corners)
		else:
			SkyLook.edge(item, rect, radius, loose)
		if loose and frame == null:
			SkyLook.loosen(item, rect, random)
		if ring.a > 0.0:
			var inside := rect.grow(-ring_width * 0.5)
			var closed := SkyLook.rounded(inside, maxf(radius - ring_width * 0.5, 0.0))
			closed.append(closed[0])
			RenderingServer.canvas_item_add_polyline(item, closed, PackedColorArray([ring]), ring_width, true)
