extends CanvasLayer
class_name HurtVignette
## A coloured glow that blooms in from the edges of the screen when one of the
## player's own combatants is hurt, then fades.
##
## Everything else that shows a hit lives out on the map, which means it is
## competing with the map for attention and can be missed entirely when you are
## looking at the far side of the board. This does not: it frames the whole
## screen, so it registers wherever you happen to be looking, and it is the one
## piece of feedback that says "this happened to you" rather than "this
## happened". Fire reds the edges, poison greens them, psychic purples them, so
## it doubles as a read on what is hurting you without a single word.
##
## Only for the player's side. An enemy taking a hit is good news, and framing
## the screen for it would train the player to ignore the frame.
##
## Drawn as four gradient strips rather than a single texture, so it needs no
## art and scales to any window: each edge fades from the damage colour at the
## screen border to transparent a little way in.


## How thick the glow is, as a fraction of the screen's shorter side.
const THICKNESS = 0.14
## Peak opacity at the very edge. Deliberately low - this is meant to be felt
## at the corner of the eye, not to obscure the fight.
const PEAK_ALPHA = 0.5
const IN_SECONDS = 0.08
const OUT_SECONDS = 0.45

var _edges: Array[TextureRect] = []
var _tween: Tween = null

## Everything is parented to this rather than to the layer itself. A
## CanvasLayer is not a CanvasItem, so it has no modulate to tint or fade -
## one Control holding the four strips gives the whole frame a single colour
## and a single opacity to animate.
var _frame: Control = null


func _ready():
	layer = 5
	_frame = Control.new()
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	_build_edges()
	_frame.modulate.a = 0.0


## One strip per edge, each a two-stop gradient running inward from the border.
func _build_edges():
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, PEAK_ALPHA))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 64
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)

	# anchor preset, and the rotation that points the gradient inward.
	var edges = [
		[Control.PRESET_TOP_WIDE, 0.0],
		[Control.PRESET_BOTTOM_WIDE, 180.0],
		[Control.PRESET_LEFT_WIDE, 90.0],
		[Control.PRESET_RIGHT_WIDE, 270.0],
	]
	for spec in edges:
		var strip := TextureRect.new()
		strip.texture = texture
		strip.stretch_mode = TextureRect.STRETCH_SCALE
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.set_anchors_preset(spec[0])
		strip.pivot_offset = Vector2.ZERO
		strip.rotation_degrees = spec[1]
		_frame.add_child(strip)
		_edges.append(strip)
	_resize_edges()
	get_viewport().size_changed.connect(_resize_edges)


## Sized in code rather than by anchors alone, because each strip is rotated
## about its own corner and the anchor presets do not account for that.
func _resize_edges():
	var screen = get_viewport().get_visible_rect().size
	var depth = minf(screen.x, screen.y) * THICKNESS
	if _edges.size() < 4:
		return
	_edges[0].position = Vector2.ZERO
	_edges[0].size = Vector2(screen.x, depth)
	_edges[1].position = Vector2(screen.x, screen.y)
	_edges[1].size = Vector2(screen.x, depth)
	_edges[2].position = Vector2(0, screen.y)
	_edges[2].size = Vector2(screen.y, depth)
	_edges[3].position = Vector2(screen.x, 0)
	_edges[3].size = Vector2(screen.y, depth)


## Blooms the edges in `colour` and fades them out. `strength` scales how hard
## it hits, so a scratch barely registers and a near-fatal blow is unmissable.
func flare(colour: Color, strength: float = 1.0):
	if _edges.is_empty() or _frame == null:
		return
	strength = clampf(strength, 0.0, 1.0)
	if strength <= 0.0:
		return
	_frame.modulate = Color(colour.r, colour.g, colour.b, _frame.modulate.a)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_frame, "modulate:a", strength, IN_SECONDS)
	_tween.tween_property(_frame, "modulate:a", 0.0, OUT_SECONDS)
