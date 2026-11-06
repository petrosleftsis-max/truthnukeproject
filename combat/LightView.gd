extends Node2D
class_name LightView
## How light looks (Light, LightMap): a placeholder drawn in code, none of it deciding anything.
## Two soft layers laid over the tiles and under the figures. One is the shade, heaviest where no
## light reaches; the other the warm glow of whatever is lit, added on top. One pixel to a tile,
## filtered, so light fades across the tiles where the rule steps from one level to the next. Over
## everything but the HUD goes a tone, by the hour. Whoever sees in the dark sees it as a grey-blue
## half-light (night_eyes). The art will replace all of this; the rule is LightMap's.

## How heavy the shade is where no light reaches at all, and how blue.
const SHADE_MOST := 0.86
const NIGHT_EYES_MOST := 0.42
const SHADE_COLOUR := Color(0.015, 0.02, 0.06)
const NIGHT_EYES_COLOUR := Color(0.1, 0.14, 0.24)
const TONE_SECONDS := 1.2
## How far the glow breathes, and how fast, where a flame is the light.
const FLICKER := 0.09
const FLICKER_RATE := 7.0

## Whether to draw any of it: not headless, unless a test asks.
static var plays_headless := false

var light: LightMap = null
var night_eyes := false : set = _set_night_eyes

var _tile_map: TileMap = null
var _region := Rect2i()
var _shade: Sprite2D = null
var _glow: Sprite2D = null
var _tone: CanvasModulate = null
var _clock := 0.0


static func shown() -> bool:
	return plays_headless or DisplayServer.get_name() != "headless"


## Starts drawing `map` over `tile_map`, from `region`'s tiles.
func start(map: LightMap, tile_map: TileMap, region: Rect2i):
	light = map
	_tile_map = tile_map
	_region = region
	name = "LightView"
	_shade = _layer("Shade", false)
	_glow = _layer("Glow", true)
	_tone = CanvasModulate.new()
	_tone.name = "Tone"
	_tone.color = Color.WHITE
	add_child(_tone)
	refresh()


func _layer(called: String, adds: bool) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = called
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if adds:
		var material := CanvasItemMaterial.new()
		material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		sprite.material = material
	add_child(sprite)
	return sprite


func _set_night_eyes(value: bool):
	if value != night_eyes:
		night_eyes = value
		refresh()


## Draws what the map says now.
func refresh():
	if light == null or _tile_map == null or _region.size.x <= 0 or _region.size.y <= 0:
		return
	visible = light.varies or not light.glow.is_empty()
	if not visible:
		return
	var shade := Image.create(_region.size.x, _region.size.y, false, Image.FORMAT_RGBA8)
	var glow := Image.create(_region.size.x, _region.size.y, false, Image.FORMAT_RGBA8)
	var most := NIGHT_EYES_MOST if night_eyes else SHADE_MOST
	var colour := NIGHT_EYES_COLOUR if night_eyes else SHADE_COLOUR
	for x in _region.size.x:
		for y in _region.size.y:
			var tile := _region.position + Vector2i(x, y)
			var amount := light.amount_at(tile)
			shade.set_pixel(x, y, Color(colour, most * pow(1.0 - amount, 1.3)))
			var lit: Color = light.glow.get(tile, Color(0, 0, 0, 0))
			glow.set_pixel(x, y, Color(lit.r * lit.a, lit.g * lit.a, lit.b * lit.a, 1.0))
	_put_on(_shade, shade)
	_put_on(_glow, glow)
	_glow.visible = not light.glow.is_empty()


func _put_on(sprite: Sprite2D, image: Image):
	sprite.texture = ImageTexture.create_from_image(image)
	var tile_size := Vector2(Grid.TILE_SIZE, Grid.TILE_SIZE)
	sprite.scale = tile_size
	sprite.position = to_local(_tile_map.to_global(_tile_map.map_to_local(_region.position))) - tile_size / 2.0


## The colour over everything: at once, or easing there.
func set_tone(colour: Color, at_once: bool = false):
	if _tone == null:
		return
	if at_once or not is_inside_tree():
		_tone.color = colour
		return
	var easing := create_tween()
	easing.tween_property(_tone, "color", colour, TONE_SECONDS)


func _process(delta: float):
	if _glow == null or light == null or not light.flickers:
		return
	_clock += delta
	var wobble := sin(_clock * FLICKER_RATE) * 0.55 + sin(_clock * FLICKER_RATE * 2.3 + 1.3) * 0.45
	_glow.modulate = Color(1.0 + wobble * FLICKER, 1.0 + wobble * FLICKER, 1.0 + wobble * FLICKER, 1.0)
