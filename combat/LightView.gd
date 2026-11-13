extends Node2D
class_name LightView
## How light looks (Light, LightMap): placeholders drawn in code, none of it deciding anything, and
## nothing in it rolls from Combat.rng. The rule is LightMap's. The designer, 2026-11-07: "do all the
## light improvement ideas".
##
## Under the figures:
## - the shade, one pixel to a tile and filtered, so light fades across the tiles where the rule steps
##   from one level to the next. It drains what is under it of colour as well as darkening it, a little
##   in Dim and much more in Dark (SHADE_SHADER), and a change eases over EASE_SECONDS rather than
##   snapping, however it came about (a lamp broken, a door opened, somebody burning);
## - fog, drifting slowly over the Dark (FOG_SHADER).
## Over everything but the HUD:
## - a real light on each source, in its colour, breathing where it is a flame (_sync_lights), easing on
##   and off, gliding after a light that is carried, and stopped by walls: the Blocks tiles are made into
##   occluders (_build_occluders), so walls, pillars and a Phantom Wall cast shadows across the floor;
## - what hangs in the air: embers round a flame, dust in other light, shafts of light from an opening;
## - the tone and the grade of the hour, by the clock (Light.tone_at, Light.grade_at): gold at dusk, blue
##   at night, grey at dawn.
## Slots: a picture at art/fx/ember.png, dust.png or light_shaft.png is used in place of what is
## drawn here. dithered gives the shade a dithered edge, for if the art ends up pixel art.
##
## The sky goes round with the clock, and each day has its own (Light.sky, Campaign.sky_now; section 14 of docs/proposals_2026-11-07.md).
## How dark a place looks follows the sun by the minute, though the rule only changes at four moments. Clouds' shadows pass over
## everything outdoors, mist lies low at dawn or on a foggy morning, rain falls, dust hangs at noon and insects come out at dusk, with a
## sound slot for each in the SoundBank. An opening's light takes the sky's colour.

## How heavy the shade is where no light reaches at all, and how blue.
const SHADE_MOST := 0.86
const NIGHT_EYES_MOST := 0.52
const SHADE_COLOUR := Color(0.015, 0.02, 0.06)
const NIGHT_EYES_COLOUR := Color(0.1, 0.14, 0.24)
const TONE_SECONDS := 1.2
## How long the shade takes to change, and a light to come on or go out.
const EASE_SECONDS := 0.8
## How much colour goes from what is under the shade, at its heaviest.
const DRAIN := 0.9
## How strong a light is, and how far it breathes and how fast, where a flame is the light.
const ENERGY := 0.5
const OPENING_ENERGY := 0.34
## How much a light is lost in what is lit already, in full sun.
const LOST_IN_THE_SUN := 0.65
const FLICKER := 0.09
## How strong the fog is, and how strong for whoever sees in the dark (the designer, 2026-11-07: "i'd like it
## to still be somewhat visible when cyrus plays"): it goes by how heavy the shade is, which is lighter
## for them, so this is about half as strong on the screen.
const FOG_STRENGTH := 0.24
const FOG_WITH_NIGHT_EYES := 0.8
const FLICKER_RATE := 7.0
const GLIDE_RATE := 9.0
## How far a light may have gone and still be taken for the same one, between one look and the next.
const SAME_LIGHT_TILES := 2.5
const LIGHT_TEXTURE_SIZE := 256

const EMBER_PICTURE := "res://art/fx/ember.png"
const DUST_PICTURE := "res://art/fx/dust.png"
const SHAFT_PICTURE := "res://art/fx/light_shaft.png"

const SHADE_SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D previous : filter_linear, repeat_disable;
uniform float blend = 1.0;
uniform float drain = 0.9;
uniform float most = 0.86;
uniform float dither = 0.0;
uniform float pixels = 0.0;
uniform vec2 tiles = vec2(16.0, 16.0);
void fragment() {
	vec4 shade = mix(texture(previous, UV), texture(TEXTURE, UV), blend);
	// The sky's pixels showing ("More to look at"): for a moment the light's edges step, four steps to a tile.
	if (pixels > 0.0) {
		vec2 steps = tiles * 4.0;
		vec2 stepped = (floor(UV * steps) + 0.5) / steps;
		shade = mix(shade, mix(texture(previous, stepped), texture(TEXTURE, stepped), blend), pixels);
	}
	float amount = shade.a;
	if (dither > 0.0) {
		int x = int(FRAGCOORD.x / dither) % 4;
		int y = int(FRAGCOORD.y / dither) % 4;
		float threshold = float((x * 2 + y * 3 + x * y) % 16) / 16.0 - 0.5;
		amount = clamp(amount + threshold * 0.14, 0.0, 1.0);
	}
	vec3 under = texture(screen, SCREEN_UV).rgb;
	float grey = dot(under, vec3(0.299, 0.587, 0.114));
	vec3 drained = mix(under, vec3(grey), clamp(amount / most, 0.0, 1.0) * drain);
	COLOR = vec4(mix(drained, shade.rgb, amount), 1.0);
}
"""

const FOG_SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D noise : repeat_enable, filter_linear;
uniform vec2 tiles = vec2(16.0, 16.0);
uniform float strength = 0.24;
uniform sampler2D previous : filter_linear, repeat_disable;
uniform float blend = 1.0;
void fragment() {
	float dark = mix(texture(previous, UV).a, texture(TEXTURE, UV).a, blend);
	vec2 at = UV * tiles / 6.0;
	float one = texture(noise, at + vec2(TIME * 0.012, TIME * 0.005)).r;
	float two = texture(noise, at * 1.7 - vec2(TIME * 0.008, TIME * 0.011)).r;
	COLOR = vec4(0.55, 0.62, 0.78, smoothstep(0.35, 0.9, (one + two) * 0.5) * dark * dark * strength);
}
"""

## A layer over a whole map: clouds' shadows going over it, or mist. Nothing to do with the rule.
const SKY_LAYER_SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D noise : repeat_enable, filter_linear;
uniform vec2 tiles = vec2(16.0, 16.0);
uniform float cover = 0.0;
uniform float mist = 0.0;
uniform vec3 mist_colour = vec3(0.86, 0.88, 0.92);
uniform float speed = 1.0;
uniform vec2 drift = vec2(1.0, 0.3);
uniform sampler2D sky_mask : hint_default_white, filter_linear, repeat_disable;
uniform float pixels = 0.0;
void fragment() {
	vec2 uv = UV;
	// The sky's pixels showing ("More to look at"): for a moment, two steps to a tile.
	if (pixels > 0.0) {
		vec2 steps = tiles * 2.0;
		uv = mix(UV, (floor(UV * steps) + 0.5) / steps, pixels);
	}
	vec2 at = uv * tiles / 14.0;
	// Drifting with the wind, the way it blows (Campaign.wind_now): one layer along it, a slower one a little across it.
	vec2 with_wind = normalize(drift + vec2(0.0001));
	vec2 across = vec2(-with_wind.y, with_wind.x);
	float one = texture(noise, at - with_wind * TIME * 0.0065 * speed).r;
	float two = texture(noise, at * 0.6 - (with_wind * 0.8 + across * 0.3) * TIME * 0.004 * speed).r;
	float cloud = smoothstep(0.42, 0.7, (one + two) * 0.5) * cover * 0.38;
	vec2 low = uv * tiles / 5.0;
	float wisps = smoothstep(0.32, 0.8, texture(noise, low - with_wind * TIME * 0.01 * speed).r) * mist * 0.5;
	// A thick fog is a veil over everything, the wisps drifting through it; a morning's mist only the wisps.
	wisps = max(wisps, smoothstep(0.4, 1.0, mist) * (0.26 + 0.08 * texture(noise, low * 0.35 - with_wind * TIME * 0.004 * speed).r));
	if (wisps > cloud) {
		COLOR = vec4(mist_colour, wisps);
	} else {
		COLOR = vec4(0.02, 0.03, 0.08, cloud);
	}
	COLOR.a *= texture(sky_mask, UV).r;
}
"""

const GRADE_SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen : hint_screen_texture, filter_linear, repeat_disable;
uniform float saturation = 1.0;
uniform float contrast = 1.0;
uniform float shimmer = 0.0;
// The night's darker edges, and the sky's pixels showing ("More to look at"): the open sky's mask, read by where on the screen.
uniform float vignette = 0.0;
uniform float pixels = 0.0;
uniform sampler2D sky_mask : hint_default_white, filter_linear, repeat_disable;
uniform vec2 mask_origin = vec2(0.0);
uniform vec2 mask_size = vec2(0.0);
uniform vec2 screen_origin = vec2(0.0);
uniform vec2 screen_extent = vec2(0.0);
varying vec2 world;
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	// Held to the ground, so walking does not set the whole view swimming; slow, in patches that come and go (the designer,
	// 2026-11-13: "i love the heat visual effect, but its too tiring when walking around").
	float patch = 0.5 + 0.5 * sin(world.x * 0.0021 + TIME * 0.21) * sin(world.y * 0.0017 - TIME * 0.17);
	vec2 wave = vec2(sin(world.y * 0.045 + TIME * 1.7), cos(world.x * 0.033 + TIME * 1.3));
	vec2 at = SCREEN_UV + wave * 0.00055 * shimmer * (0.35 + 0.65 * patch);
	if (pixels > 0.0) {
		float open = 1.0;
		if (mask_size.x > 0.0 && screen_extent.x != 0.0) {
			vec2 on_map = (screen_origin + SCREEN_UV * screen_extent - mask_origin) / mask_size;
			if (on_map.x >= 0.0 && on_map.y >= 0.0 && on_map.x <= 1.0 && on_map.y <= 1.0) {
				open = texture(sky_mask, on_map).r;
			}
		}
		vec2 block = SCREEN_PIXEL_SIZE * 6.0;
		at = mix(at, (floor(at / block) + 0.5) * block, step(0.5, pixels * open));
	}
	vec3 under = texture(screen, at).rgb;
	float grey = dot(under, vec3(0.299, 0.587, 0.114));
	vec3 graded = (mix(vec3(grey), under, saturation) - 0.5) * contrast + 0.5;
	graded *= 1.0 - vignette * smoothstep(0.45, 1.0, length(SCREEN_UV - 0.5) * 1.414);
	COLOR = vec4(graded, 1.0);
}
"""

## An aurora's bands, by night: light added, drifting (Light.WEATHERS "aurora").
const AURORA_SHADER := """
shader_type canvas_item;
render_mode unshaded, blend_add;
uniform sampler2D noise : repeat_enable, filter_linear;
uniform vec2 tiles = vec2(16.0, 16.0);
uniform float aurora = 0.0;
uniform sampler2D sky_mask : hint_default_white, filter_linear, repeat_disable;
void fragment() {
	vec2 at = UV * tiles / 22.0;
	float band = texture(noise, vec2(at.x * 0.5 + TIME * 0.01, at.y * 2.0 + sin(at.x * 3.0 + TIME * 0.2) * 0.3)).r;
	float glow = smoothstep(0.55, 0.85, band) * aurora * 0.22;
	vec3 hue = mix(vec3(0.2, 1.0, 0.55), vec3(0.65, 0.35, 1.0), smoothstep(0.3, 0.8, texture(noise, at * 0.7 + TIME * 0.004).r));
	COLOR = vec4(hue * glow * texture(sky_mask, UV).r, 1.0);
}
"""

## --- Only under the open sky ---
##
## The designer, 2026-11-12: "outdoor effects like rain shouldn't appear indoor, keep them shown outside still". Everything the
## sky brings - what falls and blows (rain, snow, hail, sand, ash, the wind's streaks), the insects and motes, the mist, the
## clouds' shadows, an aurora, a rainbow - fades out over every tile that is not open to the sky (LightMap.under_the_sky),
## through a mask a pixel a tile that the linear filter softens over a tile's width (_mask_the_sky). The sky layers read it by
## their own UV, being the map's size; what moves with the view reads it by where on the screen it is drawn, the screen's place
## on the map told it every frame (AIR_SHADER's screen_origin and screen_extent, from _keep_the_air_on_the_screen) - drawn as
## particles, a drop's own place never reaches the shader. A lightning flash keeps FLASH_INDOORS of itself there: its light at a
## window. Past the map's edges, as before.

const FLASH_INDOORS := 0.15
const AIR_SHADER := """
shader_type canvas_item;
uniform sampler2D sky_mask : hint_default_white, filter_linear, repeat_disable;
uniform vec2 mask_origin = vec2(0.0);
uniform vec2 mask_size = vec2(0.0);
uniform float indoors = 0.0;
uniform vec2 screen_origin = vec2(0.0);
uniform vec2 screen_extent = vec2(0.0);
void fragment() {
	float open = 1.0;
	if (mask_size.x > 0.0 && screen_extent.x != 0.0) {
		vec2 world = screen_origin + SCREEN_UV * screen_extent;
		vec2 on_map = (world - mask_origin) / mask_size;
		if (on_map.x >= 0.0 && on_map.y >= 0.0 && on_map.x <= 1.0 && on_map.y <= 1.0) {
			open = texture(sky_mask, on_map).r;
		}
	}
	COLOR.a *= mix(indoors, 1.0, open);
}
"""
## One for everything that falls and floats; the flash its own, for how much of it shows indoors.
var _air_material: ShaderMaterial = null
var _sky_mask_made := false


## The mask of the open sky, put on everything that reads it: again whenever the light map is (_build_occluders), and only
## when it has changed.
var _sky_mask_bytes := PackedByteArray()


func _mask_the_sky():
	if _sky_mask_made or light == null or _tile_map == null or _region.size.x <= 0 or _region.size.y <= 0:
		return
	_sky_mask_made = true
	var image := Image.create(_region.size.x, _region.size.y, false, Image.FORMAT_L8)
	for y in _region.size.y:
		for x in _region.size.x:
			image.set_pixel(x, y, Color.WHITE if light.under_the_sky(_region.position + Vector2i(x, y)) else Color.BLACK)
	if image.get_data() == _sky_mask_bytes:
		return
	_sky_mask_bytes = image.get_data()
	var mask := ImageTexture.create_from_image(image)
	var half := Vector2(Grid.TILE_SIZE, Grid.TILE_SIZE) / 2.0
	var origin: Vector2 = _tile_map.to_global(_tile_map.map_to_local(_region.position) - half)
	var far: Vector2 = _tile_map.to_global(_tile_map.map_to_local(_region.end) - half)
	for layer in [_mist, _clouds, _aurora]:
		if layer != null:
			layer.material.set_shader_parameter("sky_mask", mask)
	if _air_material == null:
		_air_material = _material(AIR_SHADER)
	for material in [_air_material, _glow_material, _rainbow.material if _rainbow != null else null, _flash.material if _flash != null else null,
			_far_flash.material if _far_flash != null else null, _grade.material if _grade != null else null]:
		if material != null:
			material.set_shader_parameter("sky_mask", mask)
			material.set_shader_parameter("mask_origin", origin)
			material.set_shader_parameter("mask_size", far - origin)


## A rainbow across the map, from a middle far below it (Light.WEATHERS "rainbow"). A placeholder.
const RAINBOW_SHADER := """
shader_type canvas_item;
render_mode unshaded, blend_add;
uniform float rainbow = 0.0;
uniform float aspect = 1.0;
uniform sampler2D sky_mask : hint_default_white, filter_linear, repeat_disable;
uniform vec2 mask_origin = vec2(0.0);
uniform vec2 mask_size = vec2(0.0);
varying vec2 world;
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	vec2 at = vec2((UV.x - 0.5) * aspect, UV.y - 1.6);
	float from_middle = length(at);
	float across = clamp((from_middle - 1.05) / 0.12, 0.0, 1.0);
	float in_band = step(0.0, across) * step(across, 0.999) * smoothstep(0.0, 0.15, across) * (1.0 - smoothstep(0.85, 1.0, across));
	vec3 hue = clamp(abs(fract(across + vec3(0.0, 0.66, 0.33)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
	float open = 1.0;
	if (mask_size.x > 0.0) {
		vec2 on_map = (world - mask_origin) / mask_size;
		if (on_map.x >= 0.0 && on_map.y >= 0.0 && on_map.x <= 1.0 && on_map.y <= 1.0) {
			open = texture(sky_mask, on_map).r;
		}
	}
	COLOR = vec4(hue * in_band * rainbow * 0.08 * open, 1.0);
}
"""

## What is shown goes to what the sky wants over sky_ease_seconds: the clock's minutes and the day's weather alike, never at
## once but the first time (the designer, 2026-11-07). The shade the sun moves eases over SKY_SHADE_SECONDS.
const SKY_SHADE_SECONDS := 1.6
## The sky's numbers that ease; tone and colour ease as colours.
const EASED := ["strength", "soft", "saturation", "contrast", "amount", "clouds", "rain", "mist", "lean", "snow", "hail", "lightning", "wind", "sand",
	"ash", "shimmer", "aurora", "rainbow", "eclipse"]
## Getting wet in rain, and drying (CombatantSprite.wetness): how long under it to be soaked, and to dry off out of it.
const SOAKED_SECONDS := 25.0
const DRY_SECONDS := 90.0
## Lightning, by the storm: seconds between flashes at the most and the least, and how long the thunder takes after.
const FLASH_GAP := [3.0, 11.0]
const THUNDER_AFTER := [0.4, 2.2]

## Whether to draw any of it: not headless, unless a test asks.
static var plays_headless := false
## How long the sky takes to get most of the way to a change (show_hour). 0, at once: for a test that wants it so.
static var sky_ease_seconds := 2.5
## The view showing now, for what asks whether it is raining somewhere (rainy_at: footsteps).
static var showing: LightView = null
## A dithered edge on the shade, for pixel art.
static var dithered := false
## Whether embers, dust, fog and shafts of light are drawn.
static var air_on := true
static var _light_picture: Texture2D = null

var light: LightMap = null
var night_eyes := false : set = _set_night_eyes

var _tile_map: TileMap = null
var _region := Rect2i()
var _shade: Sprite2D = null
var _fog: Sprite2D = null
var _grade: ColorRect = null
var _grade_copy: BackBufferCopy = null
var _tone: CanvasModulate = null
var _occluders: Node2D = null
var _occluder_key := 0
var _clock := 0.0
## {"node": PointLight2D, "source", "at": where it is going, "energy": how strong it should be, "phase"}.
var _lights: Array = []
var _shade_easing: Tween = null
## The sky: clouds over everything, mist under the figures, what falls and hangs in the air, what is heard.
var _clouds: Sprite2D = null
var _mist: Sprite2D = null
var _rain: CPUParticles2D = null
var _life: CPUParticles2D = null
var _life_is := ""
var _day_sound: AudioStreamPlayer = null
var _day_sound_is: StringName = &""
## More of the sky: snow, sleet, sand, ash and a wind's streaks falling or blowing; an aurora and a rainbow over the map; a flash.
var _snow: CPUParticles2D = null
var _hail: CPUParticles2D = null
var _sand: CPUParticles2D = null
var _ash: CPUParticles2D = null
var _gusts: CPUParticles2D = null
var _aurora: Sprite2D = null
var _rainbow: ColorRect = null
var _flash: ColorRect = null
var _next_flash := 0.0
## What the sky wants, and what is shown on the way to it (show_hour).
var _sky_wanted := {}
var _sky_shown := {}
var _sky_easing := false
## How lit the sun makes things now, 0 to 1, or below 0 where it has no say.
var _sun := -1.0
var _opening_colour := Color(1.0, 0.96, 0.85)


static func shown() -> bool:
	return plays_headless or DisplayServer.get_name() != "headless"


## A soft round light, for anything that wants one (Projectile too).
static func light_picture() -> Texture2D:
	if _light_picture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 0.8))
		gradient.set_color(1, Color(1, 1, 1, 0))
		gradient.add_point(0.45, Color(1, 1, 1, 0.34))
		var round_one := GradientTexture2D.new()
		round_one.gradient = gradient
		round_one.fill = GradientTexture2D.FILL_RADIAL
		round_one.fill_from = Vector2(0.5, 0.5)
		round_one.fill_to = Vector2(1.0, 0.5)
		round_one.width = LIGHT_TEXTURE_SIZE
		round_one.height = LIGHT_TEXTURE_SIZE
		_light_picture = round_one
	return _light_picture


## How far a light of `tiles` tiles has to be scaled to reach that far.
static func light_scale(tiles: float) -> float:
	return tiles * 2.0 * float(Grid.TILE_SIZE) / float(LIGHT_TEXTURE_SIZE)


## Starts drawing `map` over `tile_map`, from `region`'s tiles.
func start(map: LightMap, tile_map: TileMap, region: Rect2i):
	light = map
	_tile_map = tile_map
	_region = region
	name = "LightView"
	# What lies on open ground, under the shade so the dark darkens it too ("The weather on the ground").
	_make_the_ground(region)
	_shade = Sprite2D.new()
	_shade.name = "Shade"
	_shade.centered = false
	_shade.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_shade.light_mask = 0
	_shade.material = _material(SHADE_SHADER)
	_shade.material.set_shader_parameter("drain", DRAIN)
	_shade.material.set_shader_parameter("tiles", Vector2(region.size))
	add_child(_shade)
	_fog = Sprite2D.new()
	_fog.name = "Fog"
	_fog.centered = false
	_fog.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_fog.light_mask = 0
	_fog.material = _material(FOG_SHADER)
	var noise := NoiseTexture2D.new()
	noise.seamless = true
	noise.width = 256
	noise.height = 256
	var pattern := FastNoiseLite.new()
	pattern.frequency = 0.012
	pattern.seed = 7
	noise.noise = pattern
	_fog.material.set_shader_parameter("noise", noise)
	_fog.material.set_shader_parameter("tiles", Vector2(region.size))
	_fog.visible = false
	add_child(_fog)
	# Over the dark, under the figures: lights mirrored in the wet and in water, and the low mist of a night ("More to look at").
	_make_the_reflections(region)
	_ground_mist = _sky_layer("GroundMist", noise, region, GROUND_MIST_SHADER)
	_mist = _sky_layer("Mist", noise, region)
	_clouds = _sky_layer("Clouds", noise, region)
	_clouds.z_as_relative = false
	_clouds.z_index = ExplorationParty.PARTY_Z_TOP
	_aurora = _sky_layer("Aurora", noise, region, AURORA_SHADER)
	_aurora.z_as_relative = false
	_aurora.z_index = ExplorationParty.PARTY_Z_TOP
	_birds = _Birds.new()
	_birds.name = "BirdShadows"
	_birds.z_as_relative = false
	_birds.z_index = ExplorationParty.PARTY_Z_TOP
	_birds.light_mask = 0
	if _air_material == null:
		_air_material = _material(AIR_SHADER)
	_birds.material = _air_material
	if ResourceLoader.exists(BIRD_PICTURE):
		_birds.picture = load(BIRD_PICTURE)
	add_child(_birds)
	# Across the view, wherever it goes, as the grade is.
	_rainbow = ColorRect.new()
	_rainbow.name = "Rainbow"
	_rainbow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rainbow.z_as_relative = false
	_rainbow.z_index = ExplorationParty.PARTY_Z_TOP
	_rainbow.light_mask = 0
	_rainbow.material = _material(RAINBOW_SHADER)
	_rainbow.visible = false
	add_child(_rainbow)
	_flash = ColorRect.new()
	_flash.name = "Flash"
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(0.92, 0.95, 1.0, 0.0)
	_flash.material = _material(AIR_SHADER)
	_flash.material.set_shader_parameter("indoors", FLASH_INDOORS)
	_flash.z_as_relative = false
	_flash.z_index = 4001
	_flash.light_mask = 0
	_flash.visible = false
	add_child(_flash)
	_far_flash = ColorRect.new()
	_far_flash.name = "FarFlash"
	_far_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_far_flash.material = _material(FAR_FLASH_SHADER)
	_far_flash.z_as_relative = false
	_far_flash.z_index = 4001
	_far_flash.light_mask = 0
	_far_flash.visible = false
	add_child(_far_flash)
	showing = self
	_occluders = Node2D.new()
	_occluders.name = "Occluders"
	add_child(_occluders)
	# A shader reading the screen only sees what was there the first time anything read it (the shade,
	# under the figures), unless it is copied again just before.
	_grade_copy = BackBufferCopy.new()
	_grade_copy.name = "GradeCopy"
	_grade_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_grade_copy.z_as_relative = false
	_grade_copy.z_index = 3999
	_grade_copy.visible = false
	add_child(_grade_copy)
	_grade = ColorRect.new()
	_grade.name = "Grade"
	_grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grade.z_as_relative = false
	_grade.z_index = 4000
	_grade.light_mask = 0
	_grade.material = _material(GRADE_SHADER)
	_grade.visible = false
	add_child(_grade)
	_tone = CanvasModulate.new()
	_tone.name = "Tone"
	_tone.color = Color.WHITE
	add_child(_tone)
	_gather_the_water()
	refresh()


func _exit_tree():
	if showing == self:
		showing = null


## Whether it is raining (or sleeting) on `at` now, under the sky: for steps that splash (Footsteps).
static func rainy_at(at: Vector2) -> bool:
	if showing == null or not is_instance_valid(showing) or showing._sky_shown.is_empty():
		return false
	var wet: float = float(showing._sky_shown.get("rain", 0.0)) + float(showing._sky_shown.get("hail", 0.0))
	return wet > 0.1 and showing._under_the_sky(at)


## Whether `at`, a place in the world, is a tile under the open sky.
func _under_the_sky(at: Vector2) -> bool:
	if light == null or _tile_map == null:
		return false
	return light.under_the_sky(_tile_map.local_to_map(_tile_map.to_local(at)))


func _sky_layer(called: String, noise: Texture2D, region: Rect2i, code: String = SKY_LAYER_SHADER) -> Sprite2D:
	var layer := Sprite2D.new()
	layer.name = called
	layer.centered = false
	layer.light_mask = 0
	var white := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	white.fill(Color.WHITE)
	layer.texture = ImageTexture.create_from_image(white)
	layer.material = _material(code)
	layer.material.set_shader_parameter("noise", noise)
	layer.material.set_shader_parameter("tiles", Vector2(region.size))
	var tile_size := Vector2(Grid.TILE_SIZE, Grid.TILE_SIZE)
	layer.scale = Vector2(region.size) * tile_size
	layer.position = to_local(_tile_map.to_global(_tile_map.map_to_local(region.position))) - tile_size / 2.0
	layer.visible = false
	add_child(layer)
	return layer


func _material(code: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = code
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _set_night_eyes(value: bool):
	if value != night_eyes:
		night_eyes = value
		refresh()


## Draws what the map says now: `slowly` for the sun's moving (SKY_SHADE_SECONDS), not a light lit or put out.
func refresh(slowly: bool = false):
	if light == null or _tile_map == null or _region.size.x <= 0 or _region.size.y <= 0:
		return
	visible = light.varies or not light.glow.is_empty() or _sky_to_show() or not _water_tiles.is_empty()
	_sync_lights()
	if not visible:
		return
	var shade := Image.create(_region.size.x, _region.size.y, false, Image.FORMAT_RGBA8)
	var most := NIGHT_EYES_MOST if night_eyes else SHADE_MOST
	var colour := NIGHT_EYES_COLOUR if night_eyes else SHADE_COLOUR
	var any_dark := false
	for x in _region.size.x:
		for y in _region.size.y:
			var tile := _region.position + Vector2i(x, y)
			var amount := _how_lit_it_looks(tile)
			any_dark = any_dark or amount <= 0.02
			shade.set_pixel(x, y, Color(colour, most * pow(1.0 - amount, 1.3)))
	_fog_wanted = any_dark
	# Shown at once when it comes, so it can fade in; kept until the shade has got there when it goes (_put_on_the_shade).
	if air_on and any_dark:
		_fog.visible = true
	elif not air_on or _shade_easing == null or not _shade_easing.is_valid() or not _shade_easing.is_running():
		_fog.visible = false
	_put_on_the_shade(shade, most, SKY_SHADE_SECONDS if slowly else EASE_SECONDS)
	_tell_the_shadows()
	_fog.material.set_shader_parameter("strength", FOG_WITH_NIGHT_EYES if night_eyes else FOG_STRENGTH)
	_build_occluders()


## How lit `tile` looks: as the map says, but where the sky reaches it, by the sun as it stands at this minute. The rule's level is
## unchanged. A night with no moon is Dark all the same, and so is what a spell has darkened.
func _how_lit_it_looks(tile: Vector2i) -> float:
	var amount := light.amount_at(tile)
	if _sun < 0.0 or light.base == Light.Level.DARK or not light.under_the_sky(tile):
		return amount
	return maxf(light.amounts[tile], _sun) if light.amounts.has(tile) else _sun


## Whether there is anything of the sky to draw, with the map all one level.
func _sky_to_show() -> bool:
	return (_sun >= 0.0 and _sun < 0.99) or (_clouds != null and _clouds.visible) or (_mist != null and _mist.visible) \
		or (_rain != null and _rain.emitting) or (_life != null and _life.emitting) or (_aurora != null and _aurora.visible) \
		or (_rainbow != null and _rainbow.visible) or [_snow, _hail, _sand, _ash, _gusts, _leaves].any(func(bits): return bits != null and bits.emitting) \
		or (_ground_mist != null and _ground_mist.visible) or (_birds != null and not _birds.flocks.is_empty()) \
		or (not _sky_shown.is_empty() and _birds_wanted(_sky_shown) > 0.05)


## --- Darkness comes on slowly ---
##
## The designer, 2026-11-12: "Add a smooth transition to when darkness appears in any way". Whatever darkens - a dark zone
## laid, a lamp or a torch out, the night, a door shut - the shade crossfades from what it was (at least DARKEN_SECONDS when
## anything gets darker, EASE_SECONDS otherwise), and so do the fog over the Dark and the darkness on the figures, from the
## same two pictures and the same blend (CombatantSprite.shade_previous, shade_blend). One coming before the last is done goes
## on from where that had got to (_shade_shown), not from its end. The figures' own (their rim and eyes in the dark, fading
## out of sight into it) ease in CombatantSprite.

const DARKEN_SECONDS := 1.2
## The picture the shade is going to, the one it came from, and how far between them it is, to go on from.
var _shade_target: Image = null
var _shade_from: Image = null
var _shade_blend := 1.0
## Whether the fog over the Dark is wanted once the shade gets where it is going.
var _fog_wanted := false


## The shade as it shows now, between where it came from and where it is going.
func _shade_shown() -> Image:
	if _shade_target == null:
		return null
	if _shade_from == null or _shade_blend >= 0.999 or _shade_from.get_size() != _shade_target.get_size():
		return _shade_target
	var shown := Image.create(_shade_target.get_width(), _shade_target.get_height(), false, Image.FORMAT_RGBA8)
	for y in shown.get_height():
		for x in shown.get_width():
			shown.set_pixel(x, y, _shade_from.get_pixel(x, y).lerp(_shade_target.get_pixel(x, y), _shade_blend))
	return shown


## Whether anywhere in `image` is darker than in `before`.
static func _darker_somewhere(before: Image, image: Image) -> bool:
	if before == null or before.get_size() != image.get_size():
		return false
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > before.get_pixel(x, y).a + 0.04:
				return true
	return false


## The shade's new picture, eased into from the one it shows now.
func _put_on_the_shade(image: Image, most: float, seconds: float = EASE_SECONDS):
	var old: Texture2D = _shade.texture
	var was := _shade_shown()
	var picture := ImageTexture.create_from_image(image)
	var from_picture: Texture2D = ImageTexture.create_from_image(was) if was != null and was != _shade_target else old
	_shade.texture = picture
	_fog.texture = picture
	var tile_size := Vector2(Grid.TILE_SIZE, Grid.TILE_SIZE)
	for sprite in [_shade, _fog]:
		sprite.scale = tile_size
		sprite.position = to_local(_tile_map.to_global(_tile_map.map_to_local(_region.position))) - tile_size / 2.0
	var material: ShaderMaterial = _shade.material
	var fog: ShaderMaterial = _fog.material
	material.set_shader_parameter("most", most)
	material.set_shader_parameter("dither", 12.0 if dithered else 0.0)
	material.set_shader_parameter("previous", from_picture if from_picture != null else picture)
	fog.set_shader_parameter("previous", from_picture if from_picture != null else picture)
	CombatantSprite.shade_previous = from_picture if from_picture != null else picture
	if _shade_easing != null and _shade_easing.is_valid():
		_shade_easing.kill()
	_shade_from = was
	_shade_target = image
	if old == null or not is_inside_tree():
		_set_shade_blend(1.0)
		return
	if seconds < DARKEN_SECONDS and _darker_somewhere(was, image):
		seconds = DARKEN_SECONDS
	_set_shade_blend(0.0)
	_shade_easing = create_tween()
	_shade_easing.tween_method(_set_shade_blend, 0.0, 1.0, seconds)
	_shade_easing.finished.connect(func(): _fog.visible = air_on and _fog_wanted)


## How far the shade, the fog and the figures' darkness are from the last picture to the new one.
func _set_shade_blend(value: float):
	_shade_blend = value
	if _shade != null:
		_shade.material.set_shader_parameter("blend", value)
	if _fog != null:
		_fog.material.set_shader_parameter("blend", value)
	CombatantSprite.shade_blend = value


## --- Real lights ---


## A light for each source there is now: the same one as last time where it can be taken for it, so
## one that is carried glides there; those no longer wanted go out slowly.
func _sync_lights():
	var wanted: Array = light.sources if visible else []
	var left := _lights.duplicate()
	var kept := []
	for source in wanted:
		var at := to_local(_tile_map.to_global(_tile_map.map_to_local(source.tile)))
		var entry = _same_light_in(left, source, at)
		if entry == null:
			entry = _new_light(source, at)
		else:
			left.erase(entry)
		entry.source = source
		entry.at = at
		entry.energy = _energy_of(source)
		entry["dark"] = _dark_round(source)
		entry.node.color = _opening_colour if source.get("opening", false) else source.get("colour", Color.WHITE)
		entry.node.texture_scale = light_scale(maxf(source.dim, source.bright))
		kept.append(entry)
	for entry in left:
		_put_out(entry)
	_lights = kept
	_tell_the_shadows()


## How strong it is for how lit it would be without it: a torch is little by day.
func _energy_of(source: Dictionary) -> float:
	var strength: float = OPENING_ENERGY if source.get("opening", false) else ENERGY
	return strength * (1.0 - LOST_IN_THE_SUN * light.ambient_amount_at(source.tile))


func _same_light_in(entries: Array, source: Dictionary, at: Vector2):
	for entry in entries:
		if entry.source.get("colour") == source.get("colour") and entry.source.get("opening", false) == source.get("opening", false) \
				and entry.at.distance_to(at) <= float(Grid.TILE_SIZE) * SAME_LIGHT_TILES:
			return entry
	return null


func _new_light(source: Dictionary, at: Vector2) -> Dictionary:
	var node := PointLight2D.new()
	node.texture = light_picture()
	node.blend_mode = Light2D.BLEND_MODE_ADD
	node.shadow_enabled = true
	node.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	node.shadow_filter_smooth = 3.0
	node.range_z_max = 4096
	node.range_z_min = -4096
	node.energy = 0.0
	# Above the ground, for a normal map to have somewhere to catch it from (docs/light_on_maps.md).
	node.height = float(Grid.TILE_SIZE) * 0.5
	node.position = at
	add_child(node)
	if air_on:
		_add_what_hangs_in_the_air(node, source)
	_add_bloom(node, source)
	return {"node": node, "source": source, "at": at, "energy": _energy_of(source), "phase": float(source.tile.x * 13 + source.tile.y * 7) * 0.37,
		"dark": _dark_round(source), "bloom": node.get_node_or_null("Bloom"), "smoke": node.get_node_or_null("Smoke")}


func _put_out(entry: Dictionary):
	var node: PointLight2D = entry.node
	if not is_inside_tree():
		node.queue_free()
		return
	var going := create_tween()
	going.tween_property(node, "energy", 0.0, EASE_SECONDS)
	going.tween_callback(node.queue_free)
	for child in node.get_children():
		if child is CPUParticles2D:
			child.emitting = false


## Where each light is and how far it reaches, for the figures' shadows to point away from.
func _tell_the_shadows():
	var points := []
	for entry in _lights:
		points.append({"at": to_global(entry.at), "reach": maxf(entry.source.dim, entry.source.bright) * float(Grid.TILE_SIZE),
			"colour": entry.source.get("colour", Color.WHITE), "node": entry.node, "energy": maxf(entry.energy, 0.01)})
	CombatantSprite.light_points = points
	CombatantSprite.figures_lit = shown()
	CombatantSprite.stops_shadow = _stops_a_shadow if light != null and light.blocks_light != null and light.blocks_light.is_valid() else Callable()
	if _shade != null and _shade.texture != null and visible:
		CombatantSprite.shade_map = _shade.texture
		var at: Vector2 = _shade.global_position
		var size: Vector2 = _shade.texture.get_size() * _shade.global_scale
		CombatantSprite.shade_rect = Rect2(at, size)
	else:
		CombatantSprite.shade_map = null


## Whether something at a place on the map stops a figure's shadow: what stops light.
func _stops_a_shadow(at: Vector2) -> bool:
	if light == null or _tile_map == null or light.blocks_light == null or not light.blocks_light.is_valid():
		return false
	return light.blocks_light.call(_tile_map.local_to_map(_tile_map.to_local(at)))


## --- What stops them ---


## The Blocks tiles, and whatever else stops light, as occluders, merged into as few rectangles as
## they go into. Only when that has changed.
func _build_occluders():
	_ground_mask_made = false
	_ground_mist_made = false
	# The roofs as the light map has them now: the sky's mask again too, once anything of the sky wants it (_mask_the_sky).
	_sky_mask_made = false
	if light.blocks_light == null or not light.blocks_light.is_valid() or not light.varies:
		return
	var rows := {}
	var key := 17
	for y in range(_region.position.y, _region.end.y):
		var run_start := -99999
		for x in range(_region.position.x, _region.end.x + 1):
			var blocked: bool = x < _region.end.x and light.blocks_light.call(Vector2i(x, y))
			if blocked:
				key = (key * 31 + x * 7919 + y) & 0x7FFFFFFF
				if run_start == -99999:
					run_start = x
			elif run_start != -99999:
				var run := Vector2i(run_start, x)
				if not rows.has(run):
					rows[run] = []
				rows[run].append(y)
				run_start = -99999
	if key == _occluder_key:
		return
	_occluder_key = key
	for child in _occluders.get_children():
		child.queue_free()
	var tile := float(Grid.TILE_SIZE)
	var half := Vector2(tile, tile) / 2.0
	for run in rows:
		var ys: Array = rows[run]
		var first: int = ys[0]
		for i in ys.size():
			var ended: bool = i == ys.size() - 1 or ys[i + 1] != ys[i] + 1
			if not ended:
				continue
			var top_left := to_local(_tile_map.to_global(_tile_map.map_to_local(Vector2i(run.x, first)))) - half
			var bottom_right := to_local(_tile_map.to_global(_tile_map.map_to_local(Vector2i(run.y - 1, ys[i])))) + half
			var polygon := OccluderPolygon2D.new()
			polygon.cull_mode = OccluderPolygon2D.CULL_DISABLED
			polygon.polygon = PackedVector2Array([top_left, Vector2(bottom_right.x, top_left.y), bottom_right, Vector2(top_left.x, bottom_right.y)])
			var occluder := LightOccluder2D.new()
			occluder.occluder = polygon
			_occluders.add_child(occluder)
			if i < ys.size() - 1:
				first = ys[i + 1]


## --- What hangs in the air ---


func _add_what_hangs_in_the_air(node: PointLight2D, source: Dictionary):
	if source.get("opening", false):
		var shaft := _Shaft.new()
		shaft.reach = maxf(source.dim, source.bright)
		node.add_child(shaft)
		return
	var tile := float(Grid.TILE_SIZE)
	var flame: bool = source.get("flickers", false)
	var bits := CPUParticles2D.new()
	bits.name = "Embers" if flame else "Dust"
	bits.local_coords = false
	bits.light_mask = 0
	bits.z_as_relative = false
	bits.z_index = ExplorationParty.PARTY_Z_TOP
	var picture_at: String = EMBER_PICTURE if flame else DUST_PICTURE
	if ResourceLoader.exists(picture_at):
		bits.texture = load(picture_at)
	var fade := Gradient.new()
	if flame:
		bits.amount = 6
		bits.lifetime = 1.5
		bits.direction = Vector2.UP
		bits.spread = 25.0
		bits.gravity = Vector2(0.0, -tile * 0.12)
		bits.initial_velocity_min = tile * 0.08
		bits.initial_velocity_max = tile * 0.25
		bits.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		bits.emission_sphere_radius = tile * 0.08
		bits.scale_amount_min = tile * 0.012
		bits.scale_amount_max = tile * 0.028
		fade.set_color(0, Color(1.0, 0.75, 0.3, 0.95))
		fade.set_color(1, Color(0.9, 0.25, 0.05, 0.0))
		# Out under the sky, a flame smokes, leaning the way the wind blows ("More to look at").
		if light != null and source.has("tile") and light.under_the_sky(source.tile):
			var smoke := ChimneySmoke.make_smoke(0.3, Color(0.7, 0.7, 0.72))
			smoke.position = Vector2(0.0, -tile * 0.1)
			node.add_child(smoke)
	else:
		bits.amount = 8
		bits.lifetime = 5.0
		bits.preprocess = 3.0
		bits.direction = Vector2.UP
		bits.spread = 180.0
		bits.gravity = Vector2.ZERO
		bits.initial_velocity_min = tile * 0.01
		bits.initial_velocity_max = tile * 0.05
		bits.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		bits.emission_sphere_radius = tile * maxf(source.bright, 1.0) * 0.7
		bits.scale_amount_min = tile * 0.008
		bits.scale_amount_max = tile * 0.016
		fade.set_color(0, Color(1.0, 0.95, 0.85, 0.0))
		fade.add_point(0.5, Color(1.0, 0.95, 0.85, 0.28))
		fade.set_color(fade.get_point_count() - 1, Color(1.0, 0.95, 0.85, 0.0))
	bits.color_ramp = fade
	node.add_child(bits)


## Shafts of light slanting in from an opening, leaning with the hour.
class _Shaft extends Node2D:
	var reach := 4.0
	var picture: Texture2D = null

	func _ready():
		z_as_relative = false
		z_index = ExplorationParty.PARTY_Z_TOP
		light_mask = 0
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = add
		if ResourceLoader.exists(LightView.SHAFT_PICTURE):
			picture = load(LightView.SHAFT_PICTURE)

	var _motes: CPUParticles2D = null

	func _process(_delta):
		queue_redraw()
		_keep_the_motes()

	## Dust drifting slowly in the beam, faint, as bright as the shaft is (LightView "Light that moves").
	func _keep_the_motes():
		var tile := float(Grid.TILE_SIZE)
		if _motes == null:
			_motes = CPUParticles2D.new()
			_motes.name = "Motes"
			_motes.use_parent_material = true
			_motes.light_mask = 0
			_motes.amount = 14
			_motes.lifetime = 7.0
			_motes.preprocess = 5.0
			_motes.gravity = Vector2(0.0, tile * 0.004)
			_motes.direction = Vector2.UP
			_motes.spread = 180.0
			_motes.initial_velocity_min = tile * 0.005
			_motes.initial_velocity_max = tile * 0.03
			_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			_motes.scale_amount_min = tile * 0.006
			_motes.scale_amount_max = tile * 0.013
			var fade := Gradient.new()
			fade.set_color(0, Color(1.0, 0.96, 0.86, 0.0))
			fade.add_point(0.5, Color(1.0, 0.96, 0.86, 0.5))
			fade.set_color(fade.get_point_count() - 1, Color(1.0, 0.96, 0.86, 0.0))
			_motes.color_ramp = fade
			add_child(_motes)
		var lean: float = CombatantSprite.shadow_lean
		_motes.position = Vector2(lean * tile * reach * 0.25, tile * reach * 0.4)
		_motes.emission_rect_extents = Vector2(tile * 0.45, tile * reach * 0.38)
		var parent_light := get_parent() as PointLight2D
		_motes.modulate.a = clampf(parent_light.energy / LightView.OPENING_ENERGY, 0.0, 1.0) if parent_light != null else 1.0
		_motes.emitting = _motes.modulate.a > 0.05

	func _draw():
		var tile := float(Grid.TILE_SIZE)
		var parent_light := get_parent() as PointLight2D
		var strength: float = 0.14 * clampf(parent_light.energy / LightView.OPENING_ENERGY, 0.0, 1.0) if parent_light != null else 0.14
		var lean: float = CombatantSprite.shadow_lean
		var time := Time.get_ticks_msec() / 1000.0
		for i in 3:
			var across := (float(i) - 1.0) * tile * 0.32
			var breath := 0.8 + 0.2 * sin(time * 0.7 + float(i) * 1.9)
			var top := Vector2(across, 0.0)
			var foot := top + Vector2(lean * tile * reach * 0.5, tile * reach * 0.8)
			var width := tile * 0.13
			var sky_is: Color = parent_light.color if parent_light != null else Color(1.0, 0.96, 0.85)
			var near := Color(sky_is, strength * breath)
			var far := Color(sky_is, 0.0)
			if picture != null:
				draw_texture_rect(picture, Rect2(top - Vector2(width, 0.0), Vector2(width * 2.0, foot.y)), false, near)
				continue
			# Fading in from nothing at the top, and out again at the foot.
			var waist: Vector2 = top.lerp(foot, 0.22)
			draw_polygon(PackedVector2Array([top - Vector2(width, 0.0), top + Vector2(width, 0.0), waist + Vector2(width * 1.1, 0.0), waist - Vector2(width * 1.1, 0.0)]),
				PackedColorArray([far, far, near, near]))
			draw_polygon(PackedVector2Array([waist - Vector2(width * 1.1, 0.0), waist + Vector2(width * 1.1, 0.0), foot + Vector2(width * 1.5, 0.0), foot - Vector2(width * 1.5, 0.0)]),
				PackedColorArray([near, near, far, far]))


## --- The hour ---


## The colour over everything: at once, or easing there.
func set_tone(colour: Color, at_once: bool = false):
	if _tone == null:
		return
	if at_once or not is_inside_tree():
		_tone.color = colour
		return
	var easing := create_tween()
	easing.tween_property(_tone, "color", colour, TONE_SECONDS)


## The tone and the grade of `minute` of the day, in `ambient`: at once the first time or when asked, and otherwise eased to over
## sky_ease_seconds, so that neither the clock's minutes nor a change of weather jump.
func show_hour(ambient: int, minute: int, at_once: bool = false):
	_sky_wanted = Campaign.sky_now(ambient, minute)
	_ground_wanted = Campaign.ground_now(ambient, minute)
	if at_once or sky_ease_seconds <= 0.0 or _sky_shown.is_empty() or not is_inside_tree():
		_sky_shown = _sky_wanted.duplicate()
		_sky_easing = false
		_put_on_the_sky(true)
	else:
		_sky_easing = true


## One step of what is shown towards what the sky wants.
func _ease_the_sky(delta: float):
	var k: float = 1.0 - exp(-delta / maxf(sky_ease_seconds, 0.001))
	var still := true
	for key in EASED:
		var want: float = float(_sky_wanted.get(key, 0.0))
		var have: float = float(_sky_shown.get(key, want))
		var now: float = want if absf(want - have) < 0.002 else lerpf(have, want, k)
		_sky_shown[key] = now
		still = still and now == want
	for key in ["tone", "colour"]:
		var want: Color = _sky_wanted.get(key, Color.WHITE)
		var have: Color = _sky_shown.get(key, want)
		var now: Color = want if (absf(want.r - have.r) + absf(want.g - have.g) + absf(want.b - have.b)) < 0.003 else have.lerp(want, k)
		_sky_shown[key] = now
		still = still and now == want
	_sky_shown.life = _sky_wanted.get("life", "")
	_sky_shown.sound = _sky_wanted.get("sound", &"")
	_put_on_the_sky(false)
	if still:
		_sky_easing = false


## Shows `_sky_shown`: the tone, the grade, the sun's shadows, everything in the air.
func _put_on_the_sky(at_once: bool):
	var sky := _sky_shown
	set_tone(sky.tone, true)
	if _grade != null:
		var shimmer: float = float(sky.get("shimmer", 0.0))
		_grade.material.set_shader_parameter("saturation", sky.saturation)
		_grade.material.set_shader_parameter("contrast", sky.contrast)
		_grade.material.set_shader_parameter("shimmer", shimmer if air_on else 0.0)
		_grade.material.set_shader_parameter("vignette", VIGNETTE_MOST * _night_share(sky) if air_on else 0.0)
		_grade.visible = _grade_wanted(sky)
		_grade_copy.visible = _grade.visible
	CombatantSprite.set_shadows(sky)
	CombatantSprite.soaking = float(sky.get("rain", 0.0)) + float(sky.get("hail", 0.0)) * 0.8 + float(sky.get("snow", 0.0)) * 0.3
	CombatantSprite.under_the_sky = _under_the_sky
	# What the weather puts on the figures ("The weather on the creatures").
	CombatantSprite.snowing = float(sky.get("snow", 0.0))
	CombatantSprite.ashing = float(sky.get("ash", 0.0))
	CombatantSprite.sanding = float(sky.get("sand", 0.0))
	CombatantSprite.cold_air = 1.0 if Light.cold(sky, _ground_wanted) else 0.0
	CombatantSprite.hot_air = float(sky.get("shimmer", 0.0))
	CombatantSprite.hard_rain = Light.rain_loudness(sky) >= Light.LOUD_RAIN
	CombatantSprite.wind_blows = Vector2(Campaign.wind_now()).normalized() * float(sky.get("wind", 0.0))
	_put_on_the_ground(sky)
	_show_the_sky(sky, at_once)


## How much the sun has to have moved for the shade to be drawn again.
const SUN_STEP := 0.012


## --- The weather on the ground ---
##
## The designer, 2026-11-07 (section 18). View only, placeholders all of it. A layer over open ground, under the shade
## (GROUND_SHADER): puddles darkening and gathering shine the longer it rains, and a ripple where drops land; snow lying, thinner
## in the lee of walls; a pale rim of frost on a cold clear night; ash settling; sand drifted against walls. All of it from
## Campaign.ground_now (Light.ground) at the hour shown, and a mask a pixel a tile (_ground_mask: red, open to the sky and not a
## wall; green, how much of the snow lies there; blue, how much sand: Light.lying_on). Prints where somebody steps on wet ground or
## in snow, fading (leave_print, from Footsteps; PRINT_MUD_SECONDS, PRINT_SNOW_SECONDS), and a splash under each step in the rain
## (splash).

const GROUND_SHADER := """
shader_type canvas_item;
uniform sampler2D mask : filter_linear, repeat_disable;
uniform sampler2D noise : repeat_enable, filter_linear;
uniform vec2 tiles = vec2(1.0);
uniform float wet = 0.0;
uniform float raining = 0.0;
uniform float snow = 0.0;
uniform float frost = 0.0;
uniform float ash = 0.0;
uniform float sand = 0.0;
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
void fragment() {
	vec4 m = texture(mask, UV);
	vec2 cell = UV * tiles;
	vec2 in_tile = fract(cell);
	float n1 = texture(noise, cell * 0.21).r;
	float n2 = texture(noise, cell * 0.57 + vec2(0.31, 0.77)).r;
	vec4 col = vec4(0.0);
	if (wet > 0.01) {
		// The water itself darkens the ground in WET_SHADER, under this: here only its shine, and the rings where drops land.
		float pool = smoothstep(0.6 - wet * 0.28, 0.48 - wet * 0.28, texture(noise, cell * 0.09).r) * clamp(wet * 1.4, 0.0, 1.0);
		float sheen = smoothstep(0.55, 0.85, texture(noise, cell * 0.3 + vec2(TIME * 0.015, TIME * 0.01)).r) * pool;
		col = vec4(vec3(0.82, 0.88, 0.97), sheen * 0.22);
		if (raining > 0.01 && pool > 0.3) {
			vec2 drop_cell = floor(cell * 3.0);
			float t = fract(TIME * 0.9 + hash(drop_cell));
			vec2 centre = (drop_cell + vec2(hash(drop_cell + 1.3), hash(drop_cell + 7.1))) / 3.0;
			float d = length(cell - centre) * 3.0;
			float ring = smoothstep(0.06, 0.0, abs(d - t * 0.9)) * (1.0 - t) * raining;
			col.rgb = mix(col.rgb, vec3(0.85, 0.9, 1.0), ring * 0.7);
			col.a = max(col.a, ring * 0.5);
		}
	}
	if (ash > 0.01) {
		float a = clamp(ash * (0.55 + 0.45 * n2) - 0.1, 0.0, 1.0) * 0.6;
		col.rgb = mix(col.rgb, vec3(0.42, 0.4, 0.4), a);
		col.a = max(col.a, a);
	}
	if (sand > 0.01) {
		float a = clamp(sand * m.b * 1.3 - (1.0 - n1) * 0.35, 0.0, 1.0) * 0.75;
		col.rgb = mix(col.rgb, vec3(0.8, 0.66, 0.42), a);
		col.a = max(col.a, a);
	}
	if (frost > 0.01) {
		float edge = min(min(in_tile.x, 1.0 - in_tile.x), min(in_tile.y, 1.0 - in_tile.y));
		float a = frost * smoothstep(0.16, 0.0, edge) * (0.6 + 0.4 * n2) * 0.6;
		col.rgb = mix(col.rgb, vec3(0.88, 0.94, 1.0), a);
		col.a = max(col.a, a);
	}
	if (snow > 0.01) {
		float lying = texture(noise, cell * 0.25 + vec2(0.13, 0.41)).r;
		float a = clamp(snow * m.g * 1.5 - (1.0 - lying) * 0.7, 0.0, 1.0) * 0.8;
		col.rgb = mix(col.rgb, vec3(0.94, 0.96, 1.0) - n1 * 0.06, a);
		col.a = max(col.a, a);
	}
	COLOR = vec4(col.rgb, col.a * step(0.5, m.r));
}
"""
## Wet ground, darker and cooler, and the pools on it: multiplied over what is there, so the tiles show through.
const WET_SHADER := """
shader_type canvas_item;
render_mode blend_mul;
uniform sampler2D mask : filter_linear, repeat_disable;
uniform sampler2D noise : repeat_enable, filter_linear;
uniform vec2 tiles = vec2(1.0);
uniform float wet = 0.0;
void fragment() {
	vec4 m = texture(mask, UV);
	vec2 cell = UV * tiles;
	float pool = smoothstep(0.6 - wet * 0.28, 0.48 - wet * 0.28, texture(noise, cell * 0.09).r) * clamp(wet * 1.4, 0.0, 1.0);
	vec3 damp = vec3(1.0 - 0.16 * wet);
	vec3 under = mix(damp, damp * vec3(0.68, 0.74, 0.86), pool);
	COLOR = vec4(mix(vec3(1.0), under, step(0.5, m.r)), 1.0);
}
"""
const PRINT_MUD_SECONDS := 20.0
const PRINT_SNOW_SECONDS := 60.0
const PRINTS_MOST := 160
var _ground: Sprite2D = null
var _wet_ground: Sprite2D = null
var _ground_wanted := {}
var _ground_mask_made := false
var _prints: _Prints = null


## Somebody's prints in the mud or the snow, each fading away.
class _Prints extends Node2D:
	## [{at, way, born, snow, left}]
	var marks: Array = []

	func _process(_delta: float):
		if marks.is_empty():
			return
		var now := Time.get_ticks_msec() / 1000.0
		marks = marks.filter(func(mark): return now - float(mark.born) < (LightView.PRINT_SNOW_SECONDS if mark.snow else LightView.PRINT_MUD_SECONDS))
		queue_redraw()

	func _draw():
		var now := Time.get_ticks_msec() / 1000.0
		var foot := float(Grid.TILE_SIZE) * 0.055
		for mark in marks:
			var lasts: float = LightView.PRINT_SNOW_SECONDS if mark.snow else LightView.PRINT_MUD_SECONDS
			var fade: float = clampf(1.0 - (now - float(mark.born)) / lasts, 0.0, 1.0)
			var colour := Color(0.62, 0.68, 0.8, 0.45 * fade) if mark.snow else Color(0.16, 0.12, 0.09, 0.45 * fade)
			var way: Vector2 = mark.way if mark.way.length_squared() > 0.001 else Vector2.RIGHT
			var side := way.orthogonal().normalized() * foot * (0.9 if mark.left else -0.9)
			draw_set_transform(to_local(mark.at) + side, way.angle(), Vector2(1.0, 0.55))
			draw_circle(Vector2.ZERO, foot, colour)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _make_the_ground(region: Rect2i):
	var noise := _ground_noise()
	_ground_noise_texture = noise
	_wet_ground = _sky_layer("WetGround", noise, region, WET_SHADER)
	_wet_ground.visible = false
	_ground = _sky_layer("Ground", noise, region, GROUND_SHADER)
	_ground.visible = false
	# A map's water, over the ground and under the dark ("More to look at"), lit by its lamps.
	_water = _sky_layer("Water", noise, region, WATER_SHADER)
	_water.light_mask = 1
	_water.visible = false
	_prints = _Prints.new()
	_prints.name = "Prints"
	add_child(_prints)


func _ground_noise() -> NoiseTexture2D:
	var noise := NoiseTexture2D.new()
	noise.seamless = true
	noise.width = 256
	noise.height = 256
	var pattern := FastNoiseLite.new()
	pattern.frequency = 0.03
	pattern.seed = 23
	noise.noise = pattern
	return noise


## The mask for the ground: a pixel a tile.
func _ground_mask() -> ImageTexture:
	var image := Image.create(maxi(_region.size.x, 1), maxi(_region.size.y, 1), false, Image.FORMAT_RGBA8)
	var wind := Campaign.wind_now()
	var wall_at := func(tile: Vector2i) -> bool:
		return light != null and light.blocks_light != null and light.blocks_light.is_valid() and light.blocks_light.call(tile)
	for y in _region.size.y:
		for x in _region.size.x:
			var tile := _region.position + Vector2i(x, y)
			var open: bool = light != null and light.under_the_sky(tile) and not wall_at.call(tile)
			var share := Light.lying_on({"snow": 1.0, "sand": 1.0}, tile, wind, wall_at)
			image.set_pixel(x, y, Color(1.0 if open else 0.0, float(share.snow), float(share.sand), 1.0))
	return ImageTexture.create_from_image(image)


func _put_on_the_ground(sky: Dictionary):
	if _ground == null:
		return
	var lying: Dictionary = _ground_wanted
	var any: bool = lying.values().any(func(amount): return float(amount) > 0.01)
	_ground.visible = air_on and any
	_wet_ground.visible = air_on and float(lying.get("wet", 0.0)) > 0.01
	if not _ground.visible:
		return
	if not _ground_mask_made:
		var mask := _ground_mask()
		_ground.material.set_shader_parameter("mask", mask)
		_wet_ground.material.set_shader_parameter("mask", mask)
		if _reflections != null:
			_reflections.material.set_shader_parameter("ground", mask)
		_ground_mask_made = true
	_wet_ground.material.set_shader_parameter("wet", float(lying.get("wet", 0.0)))
	for key in ["wet", "snow", "frost", "ash", "sand"]:
		_ground.material.set_shader_parameter(key, float(lying.get(key, 0.0)))
	_ground.material.set_shader_parameter("raining", clampf(Light.rain_loudness(sky), 0.0, 1.0))


## A print where somebody stepped at `at`, going `way`, if the ground there takes one.
static func leave_print(at: Vector2, way: Vector2):
	if showing == null or not is_instance_valid(showing) or showing._prints == null or not shown():
		return
	showing._leave_print(at, way)


func _leave_print(at: Vector2, way: Vector2):
	if not _under_the_sky(at):
		return
	var in_snow: bool = float(_ground_wanted.get("snow", 0.0)) >= 0.2
	if not in_snow and float(_ground_wanted.get("wet", 0.0)) < 0.3:
		return
	var left: bool = _prints.marks.is_empty() or not _prints.marks.back().left
	_prints.marks.append({"at": at, "way": way, "born": Time.get_ticks_msec() / 1000.0, "snow": in_snow, "left": left})
	while _prints.marks.size() > PRINTS_MOST:
		_prints.marks.pop_front()


## A splash under a step at `at`, in the rain.
static func splash(at: Vector2):
	if showing == null or not is_instance_valid(showing) or not shown() or not rainy_at(at):
		return
	var drops := CPUParticles2D.new()
	drops.one_shot = true
	drops.amount = 10
	drops.lifetime = 0.35
	drops.explosiveness = 1.0
	drops.direction = Vector2.UP
	drops.spread = 70.0
	drops.initial_velocity_min = Grid.tiles(0.6)
	drops.initial_velocity_max = Grid.tiles(1.2)
	drops.gravity = Vector2(0, Grid.tiles(6.0))
	drops.scale_amount_min = 2.0
	drops.scale_amount_max = 3.5
	drops.color = Color(0.82, 0.88, 0.98, 0.7)
	drops.z_index = 2
	showing.add_child(drops)
	drops.global_position = at
	drops.emitting = true
	drops.finished.connect(drops.queue_free)


func _show_the_sky(sky: Dictionary, at_once: bool = true):
	_mask_the_sky()
	var had: bool = _sky_to_show()
	var wind: float = float(sky.get("wind", 0.0))
	var sand: float = float(sky.get("sand", 0.0))
	var snow: float = float(sky.get("snow", 0.0))
	if _clouds != null:
		_clouds.visible = air_on and sky.clouds > 0.01
		_clouds.material.set_shader_parameter("cover", sky.clouds)
		_clouds.material.set_shader_parameter("speed", 1.0 + wind * 3.0)
		var way := Vector2(Campaign.wind_now())
		_clouds.material.set_shader_parameter("drift", way)
		_mist.material.set_shader_parameter("drift", way)
		# Sand in the air, or a whiteout, is a mist of its own colour.
		var haze: float = maxf(sky.mist, sand * 0.85)
		_mist.visible = air_on and haze > 0.01
		_mist.material.set_shader_parameter("mist", haze)
		_mist.material.set_shader_parameter("speed", 1.0 + wind * 4.0)
		var mist_colour := Color(0.86, 0.88, 0.92).lerp(Color(0.9, 0.7, 0.45), clampf(sand / maxf(haze, 0.01), 0.0, 1.0))
		_mist.material.set_shader_parameter("mist_colour", Vector3(mist_colour.r, mist_colour.g, mist_colour.b))
		_aurora.visible = air_on and float(sky.get("aurora", 0.0)) > 0.01
		_aurora.material.set_shader_parameter("aurora", float(sky.get("aurora", 0.0)))
		_rainbow.visible = air_on and float(sky.get("rainbow", 0.0)) > 0.01
		_rainbow.material.set_shader_parameter("rainbow", float(sky.get("rainbow", 0.0)))
	_set_rain(sky.rain if air_on else 0.0, wind)
	_set_falling("snow", snow if air_on else 0.0, wind)
	_set_falling("hail", float(sky.get("hail", 0.0)) if air_on else 0.0, wind)
	_set_falling("sand", sand if air_on else 0.0, wind)
	_set_falling("ash", float(sky.get("ash", 0.0)) if air_on else 0.0, wind)
	_set_falling("gusts", wind * (1.0 - snow) * (1.0 - sand) if air_on else 0.0, wind)
	_set_life(sky.life if air_on else "")
	_set_fireflies(_fireflies_wanted(sky))
	_set_leaves(_leaves_wanted(sky), wind)
	_set_ground_mist(_ground_mist_wanted(sky))
	_put_on_the_water(sky)
	_put_on_the_reflections(sky)
	_set_day_sound(sky.sound)
	# What comes in at a window is the sky's colour at this minute, paler than the tone over everything.
	_opening_colour = Color(sky.tone).lerp(Color.WHITE, 0.25)
	for entry in _lights:
		if entry.source.get("opening", false) and is_instance_valid(entry.node):
			entry.node.color = _opening_colour
	var sun: float = sky.amount
	if absf(sun - _sun) >= SUN_STEP or (sun >= 0.0) != (_sun >= 0.0) or had != _sky_to_show():
		_sun = sun
		refresh(not at_once)


func _air_bits(called: String) -> CPUParticles2D:
	var bits := CPUParticles2D.new()
	bits.name = called
	bits.local_coords = false
	bits.light_mask = 0
	bits.z_as_relative = false
	bits.z_index = ExplorationParty.PARTY_Z_TOP
	bits.emitting = false
	bits.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	# Faded where the sky does not reach ("Only under the open sky").
	if _air_material == null:
		_air_material = _material(AIR_SHADER)
	bits.material = _air_material
	add_child(bits)
	return bits


func _set_rain(how_much: float, wind: float = 0.0):
	if how_much <= 0.01:
		if _rain != null:
			_rain.emitting = false
		return
	var tile := float(Grid.TILE_SIZE)
	if _rain == null:
		_rain = _air_bits("Rain")
		var streak := GradientTexture2D.new()
		streak.width = 4
		streak.height = 64
		var fade := Gradient.new()
		fade.set_color(0, Color(0.8, 0.86, 1.0, 0.0))
		fade.set_color(1, Color(0.8, 0.86, 1.0, 0.6))
		streak.gradient = fade
		streak.fill_from = Vector2(0.5, 0.0)
		streak.fill_to = Vector2(0.5, 1.0)
		_rain.texture = streak
		_rain.particle_flag_align_y = true
		_rain.direction = Vector2(0.18, 1.0)
		_rain.spread = 2.0
		_rain.gravity = Vector2.ZERO
		_rain.initial_velocity_min = tile * 16.0
		_rain.initial_velocity_max = tile * 20.0
		_rain.lifetime = 0.35
		_rain.scale_amount_min = 1.5
		_rain.scale_amount_max = 3.0
	# Only a big change of it restarts the drops; the rest is how much of them shows, easing with the sky.
	var wanted: int = roundi(lerpf(80.0, 320.0, how_much))
	if absf(float(_rain.amount - wanted)) > float(_rain.amount) * 0.35:
		_rain.amount = wanted
	_rain.modulate.a = clampf(how_much * 2.5, 0.0, 1.0)
	_rain.direction = Vector2(_wind_lean(0.18) + _wind_way().x * wind * 0.5, 1.0)
	_rain.emitting = true


## Snow, sleet, sand, ash or a wind's streaks: `how_much` of it, 0 to 1, leaning with `wind`. Each made as first needed.
func _set_falling(what: String, how_much: float, wind: float):
	var bits: CPUParticles2D = get("_" + what)
	if how_much <= 0.01:
		if bits != null:
			bits.emitting = false
		return
	var tile := float(Grid.TILE_SIZE)
	if bits == null:
		bits = _air_bits(what.capitalize())
		bits.gravity = Vector2.ZERO
		var dot := GradientTexture2D.new()
		var fade := Gradient.new()
		match what:
			"snow":
				dot.width = 16
				dot.height = 16
				dot.fill = GradientTexture2D.FILL_RADIAL
				dot.fill_from = Vector2(0.5, 0.5)
				dot.fill_to = Vector2(1.0, 0.5)
				fade.set_color(0, Color(1.0, 1.0, 1.0, 0.9))
				fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
				bits.amount = 220
				bits.lifetime = 3.2
				bits.initial_velocity_min = tile * 0.9
				bits.initial_velocity_max = tile * 1.6
				bits.scale_amount_min = 0.6
				bits.scale_amount_max = 1.6
				bits.orbit_velocity_min = -0.05
				bits.orbit_velocity_max = 0.05
			"hail":
				dot.width = 4
				dot.height = 18
				dot.fill_from = Vector2(0.5, 0.0)
				dot.fill_to = Vector2(0.5, 1.0)
				fade.set_color(0, Color(0.95, 0.97, 1.0, 0.0))
				fade.set_color(1, Color(0.95, 0.97, 1.0, 0.9))
				bits.particle_flag_align_y = true
				bits.amount = 160
				bits.lifetime = 0.3
				bits.initial_velocity_min = tile * 14.0
				bits.initial_velocity_max = tile * 18.0
				bits.scale_amount_min = 1.0
				bits.scale_amount_max = 1.6
			"sand":
				dot.width = 6
				dot.height = 6
				dot.fill = GradientTexture2D.FILL_RADIAL
				dot.fill_from = Vector2(0.5, 0.5)
				dot.fill_to = Vector2(1.0, 0.5)
				fade.set_color(0, Color(0.95, 0.78, 0.5, 0.75))
				fade.set_color(1, Color(0.95, 0.78, 0.5, 0.0))
				bits.amount = 260
				bits.lifetime = 1.1
				bits.initial_velocity_min = tile * 6.0
				bits.initial_velocity_max = tile * 10.0
				bits.scale_amount_min = 0.8
				bits.scale_amount_max = 2.0
			"ash":
				dot.width = 12
				dot.height = 12
				dot.fill = GradientTexture2D.FILL_RADIAL
				dot.fill_from = Vector2(0.5, 0.5)
				dot.fill_to = Vector2(1.0, 0.5)
				fade.set_color(0, Color(0.55, 0.53, 0.52, 0.85))
				fade.set_color(1, Color(0.55, 0.53, 0.52, 0.0))
				bits.amount = 140
				bits.lifetime = 4.5
				bits.initial_velocity_min = tile * 0.4
				bits.initial_velocity_max = tile * 0.9
				bits.scale_amount_min = 0.5
				bits.scale_amount_max = 1.4
				bits.orbit_velocity_min = -0.08
				bits.orbit_velocity_max = 0.08
			_:
				dot.width = 64
				dot.height = 3
				dot.fill_from = Vector2(0.0, 0.5)
				dot.fill_to = Vector2(1.0, 0.5)
				fade.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
				fade.add_point(0.5, Color(1.0, 1.0, 1.0, 0.22))
				fade.set_color(fade.get_point_count() - 1, Color(1.0, 1.0, 1.0, 0.0))
				bits.particle_flag_align_y = true
				bits.amount = 40
				bits.lifetime = 0.9
				bits.initial_velocity_min = tile * 9.0
				bits.initial_velocity_max = tile * 13.0
				bits.scale_amount_min = 1.0
				bits.scale_amount_max = 2.5
		dot.gradient = fade
		bits.texture = dot
		set("_" + what, bits)
	bits.modulate.a = clampf(how_much * 1.6, 0.0, 1.0)
	# Down, leaning with the wind; sand and the wind's streaks along it, the way it blows (the designer, 2026-11-13: "show the wind's
	# direction").
	var way := _wind_way()
	bits.direction = way if what == "sand" or what == "gusts" else Vector2(_wind_lean(0.0) + way.x * wind * 1.2, 1.0)
	bits.spread = 25.0 if what == "snow" or what == "ash" else 4.0
	bits.emitting = true


## The way the wind blows today, as a unit on the screen (Campaign.wind_now: east is right, south down).
func _wind_way() -> Vector2:
	var way := Vector2(Campaign.wind_now())
	return way.normalized() if way.length_squared() > 0.0 else Vector2.RIGHT


## A slant of `still_air` for what falls, to the side the wind blows from, so even rain on a calm day leans its way.
func _wind_lean(still_air: float) -> float:
	var x := _wind_way().x
	return still_air * (1.0 if x >= 0.0 else -1.0) if absf(x) > 0.01 else 0.0


func _set_life(what: String):
	if what == _life_is:
		return
	_life_is = what
	if what == "":
		if _life != null:
			_life.emitting = false
		return
	var tile := float(Grid.TILE_SIZE)
	if _life == null:
		_life = _air_bits("Life")
		_life.gravity = Vector2.ZERO
		_life.spread = 180.0
	var fade := Gradient.new()
	match what:
		"insects":
			_life.amount = 28
			_life.lifetime = 2.4
			_life.direction = Vector2.UP
			_life.initial_velocity_min = tile * 0.1
			_life.initial_velocity_max = tile * 0.5
			_life.orbit_velocity_min = -0.5
			_life.orbit_velocity_max = 0.5
			_life.scale_amount_min = tile * 0.006
			_life.scale_amount_max = tile * 0.012
			fade.set_color(0, Color(1.0, 0.95, 0.6, 0.0))
			fade.add_point(0.5, Color(1.0, 0.95, 0.6, 0.55))
			fade.set_color(fade.get_point_count() - 1, Color(1.0, 0.95, 0.6, 0.0))
		_:
			_life.amount = 24
			_life.lifetime = 6.0
			_life.direction = Vector2.UP
			_life.initial_velocity_min = tile * 0.01
			_life.initial_velocity_max = tile * 0.05
			_life.orbit_velocity_min = 0.0
			_life.orbit_velocity_max = 0.0
			_life.scale_amount_min = tile * 0.006
			_life.scale_amount_max = tile * 0.012
			fade.set_color(0, Color(1.0, 0.97, 0.88, 0.0))
			fade.add_point(0.5, Color(1.0, 0.97, 0.88, 0.2))
			fade.set_color(fade.get_point_count() - 1, Color(1.0, 0.97, 0.88, 0.0))
	_life.color_ramp = fade
	_life.emitting = true


## What is heard at this hour, for as long as it is this hour: the SoundBank's, and silence with nothing in its slot.
func _set_day_sound(slot: StringName):
	if slot == _day_sound_is:
		return
	_day_sound_is = slot
	if _day_sound == null:
		_day_sound = AudioStreamPlayer.new()
		_day_sound.name = "DaySound"
		_day_sound.bus = &"SFX"
		_day_sound.volume_db = -10.0
		add_child(_day_sound)
	var sound: AudioStream = GameSounds.stream(slot) if slot != &"" else null
	if sound is AudioStreamWAV:
		sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif sound != null and "loop" in sound:
		sound.loop = true
	_day_sound.stream = sound
	if sound != null:
		_day_sound.play()
	else:
		_day_sound.stop()


## What falls and hangs in the air fills what can be seen of the map, wherever the view goes.
func _keep_the_air_on_the_screen():
	# Where the screen is on the map, for what reads the sky's mask by it (AIR_SHADER).
	if _air_material != null:
		_mask_the_sky()
		var to_map := get_canvas_transform().affine_inverse()
		var screen := get_viewport_rect().size
		var origin: Vector2 = to_map * Vector2.ZERO
		var extent: Vector2 = to_map * screen - origin
		for material in [_air_material, _glow_material, _flash.material if _flash != null else null, _far_flash.material if _far_flash != null else null,
				_grade.material if _grade != null else null]:
			if material != null:
				material.set_shader_parameter("screen_origin", origin)
				material.set_shader_parameter("screen_extent", extent)
	var falling := [_rain, _life, _snow, _hail, _sand, _ash, _gusts, _fireflies, _leaves]
	if not falling.any(func(bits): return bits != null and bits.emitting):
		return
	var from_screen := get_canvas_transform().affine_inverse()
	var view := get_viewport_rect().size * from_screen.get_scale()
	var middle: Vector2 = from_screen * (get_viewport_rect().size / 2.0)
	for bits in falling:
		if bits != null and bits.emitting:
			var sideways: bool = bits == _sand or bits == _gusts or bits == _leaves
			# Blowing in from upwind, so the screen fills the way they go.
			bits.global_position = middle - (_wind_way() * view * 0.15 if sideways else (Vector2(0.0, view.y * 0.15) if bits == _rain or bits == _hail else Vector2.ZERO))
			bits.emission_rect_extents = view / 2.0


## A storm's lightning: now and then the whole view flashes, and thunder follows (SoundBank "thunder"). Only to look at.
func _storm(delta: float):
	if _flash == null:
		return
	var lightning: float = float(_sky_shown.get("lightning", 0.0)) if air_on else 0.0
	if lightning <= 0.05:
		_flash.visible = false
		return
	_next_flash -= delta
	if _next_flash > 0.0:
		return
	_next_flash = lerpf(FLASH_GAP[1], FLASH_GAP[0], lightning) * randf_range(0.6, 1.4)
	_flash_the_sky(lightning)


## Lightning striking the field (Combat "Weather", a hazard that `flashes`): the flash, and thunder close behind.
func lightning_now():
	if _flash == null:
		return
	_next_flash = maxf(_next_flash, FLASH_GAP[0])
	_flash_the_sky(1.0, 0.1)


## The whole view flashes, `lightning` strong, and thunder follows after `thunder_after` seconds (a random wait when -1).
func _flash_the_sky(lightning: float, thunder_after: float = -1.0):
	var from_screen := get_canvas_transform().affine_inverse()
	_flash.global_position = from_screen * Vector2.ZERO
	_flash.size = get_viewport_rect().size * from_screen.get_scale()
	_flash.visible = true
	var flash := create_tween()
	flash.tween_property(_flash, "color:a", 0.55 * lightning, 0.05)
	flash.tween_property(_flash, "color:a", 0.0, 0.12)
	flash.tween_property(_flash, "color:a", 0.35 * lightning, 0.04)
	flash.tween_property(_flash, "color:a", 0.0, 0.35)
	flash.tween_interval(thunder_after if thunder_after >= 0.0 else randf_range(THUNDER_AFTER[0], THUNDER_AFTER[1]))
	flash.tween_callback(func(): GameSounds.play(&"thunder", -4.0 if thunder_after < 0.0 else 0.0))


func _process(delta: float):
	if _sky_easing:
		_ease_the_sky(delta)
	_keep_the_grade_on_the_screen()
	_keep_the_air_on_the_screen()
	_storm(delta)
	_more_to_look_at(delta)
	if light == null:
		return
	_clock += delta
	for entry in _lights:
		var node: PointLight2D = entry.node
		if not is_instance_valid(node):
			continue
		var base: Vector2 = entry.get("base", node.position)
		base = base.lerp(entry.at, minf(GLIDE_RATE * delta, 1.0))
		entry["base"] = base
		node.position = base + _light_moves(entry)
		var wobble := 0.0
		if entry.source.get("flickers", false):
			wobble = sin(_clock * FLICKER_RATE + entry.phase) * 0.55 + sin(_clock * FLICKER_RATE * 2.3 + 1.3 + entry.phase) * 0.45
		var wanted: float = entry.energy * (1.0 + wobble * FLICKER)
		node.energy = move_toward(node.energy, wanted, entry.energy / EASE_SECONDS * delta) if node.energy < wanted - entry.energy * FLICKER * 2.0 else wanted
		# Its glow after dark, breathing with it; its smoke leaning with the wind ("More to look at").
		var bloom = entry.get("bloom")
		if bloom != null and is_instance_valid(bloom):
			bloom.modulate = Color(node.color, BLOOM * float(entry.get("dark", 0.0)) * clampf(node.energy / ENERGY, 0.0, 1.3) if air_on else 0.0)
		var smoke = entry.get("smoke")
		if smoke != null and is_instance_valid(smoke):
			ChimneySmoke.lean(smoke)


## --- Light that moves ---
##
## The designer, 2026-11-13 (proposals 21: "Do light that moves"). A flame dances a little about where it burns, so the shadows it throws
## waver with it (the figures' shadows read the light's own node); out under the sky in a wind, a light sways along the wind's way, more
## the harder it blows. Fireflies blink in the warm months' nights under a still, dry sky (_fireflies_wanted), and dust drifts in a shaft
## of light from a window (_Shaft). View only, numbers PROPOSAL.
const FLAME_DANCE_TILES := 0.018
const SWAY_TILES := 0.05
var _fireflies: CPUParticles2D = null
var _glow_material: ShaderMaterial = null


## How far a light is about where it stands this moment: its flame's dance and its sway in the wind.
func _light_moves(entry: Dictionary) -> Vector2:
	var tile := float(Grid.TILE_SIZE)
	var moved := Vector2.ZERO
	var phase: float = entry.get("phase", 0.0)
	if entry.source.get("flickers", false):
		moved += Vector2(sin(_clock * 6.3 + phase), cos(_clock * 4.7 + phase * 1.7)) * tile * FLAME_DANCE_TILES
	var wind: float = float(_sky_shown.get("wind", 0.0)) if air_on else 0.0
	if wind > 0.05 and entry.source.has("tile") and light.under_the_sky(entry.source.tile):
		moved += _wind_way() * sin(_clock * 1.4 + phase) * tile * SWAY_TILES * wind
	return moved


## How many fireflies there are, 0 to 1: the warm months' evenings and nights, out of doors, with no rain, snow or wind to speak of.
func _fireflies_wanted(sky: Dictionary) -> float:
	if not air_on or float(sky.get("amount", -1.0)) < 0.0 or not ["spring", "summer"].has(Campaign.season_now()):
		return 0.0
	if float(sky.get("rain", 0.0)) > 0.01 or float(sky.get("snow", 0.0)) > 0.01 or float(sky.get("hail", 0.0)) > 0.01 or float(sky.get("wind", 0.0)) > 0.45:
		return 0.0
	var at := float(Campaign.minute_of_day())
	return smoothstep(1110.0, 1200.0, at) if at >= 720.0 else 1.0 - smoothstep(0.0, 90.0, at)


func _set_fireflies(how_many: float):
	if how_many <= 0.01:
		if _fireflies != null:
			_fireflies.emitting = false
		return
	var tile := float(Grid.TILE_SIZE)
	if _fireflies == null:
		_fireflies = _air_bits("Fireflies")
		if _glow_material == null:
			_glow_material = _material(AIR_SHADER.replace("shader_type canvas_item;", "shader_type canvas_item;\nrender_mode blend_add;"))
			_sky_mask_made = false
		_fireflies.material = _glow_material
		var dot := GradientTexture2D.new()
		dot.width = 24
		dot.height = 24
		dot.fill = GradientTexture2D.FILL_RADIAL
		dot.fill_from = Vector2(0.5, 0.5)
		dot.fill_to = Vector2(1.0, 0.5)
		var soft := Gradient.new()
		soft.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
		soft.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		dot.gradient = soft
		_fireflies.texture = dot
		_fireflies.gravity = Vector2.ZERO
		_fireflies.direction = Vector2.UP
		_fireflies.spread = 180.0
		_fireflies.lifetime = 6.0
		_fireflies.preprocess = 4.0
		_fireflies.initial_velocity_min = tile * 0.03
		_fireflies.initial_velocity_max = tile * 0.12
		_fireflies.orbit_velocity_min = -0.06
		_fireflies.orbit_velocity_max = 0.06
		_fireflies.scale_amount_min = 1.6
		_fireflies.scale_amount_max = 2.6
		# Each blinks a few times as it drifts.
		var blink := Gradient.new()
		var glow := Color(0.82, 1.0, 0.42)
		blink.set_color(0, Color(glow, 0.0))
		for step in [[0.06, 1.0], [0.2, 1.0], [0.3, 0.0], [0.4, 0.0], [0.48, 1.0], [0.62, 0.9], [0.7, 0.0], [0.78, 0.0], [0.84, 0.9], [0.94, 0.0]]:
			blink.add_point(step[0], Color(glow, step[1]))
		blink.set_color(blink.get_point_count() - 1, Color(glow, 0.0))
		_fireflies.color_ramp = blink
	_fireflies.amount = maxi(roundi(48.0 * how_many), 4)
	_fireflies.modulate.a = clampf(how_many * 1.5, 0.0, 1.0)
	_fireflies.emitting = true


func _keep_the_grade_on_the_screen():
	# A lightning flash covers the view however the view moves while it lasts (the designer, 2026-11-13: walking, "I walk away from the
	# rectangle that has the lighting effect").
	if _flash != null and _flash.visible:
		var where_now := get_canvas_transform().affine_inverse()
		_flash.global_position = where_now * Vector2.ZERO
		_flash.size = get_viewport_rect().size * where_now.get_scale()
	if _far_flash != null and _far_flash.visible:
		var where_now := get_canvas_transform().affine_inverse()
		_far_flash.global_position = where_now * Vector2.ZERO
		_far_flash.size = get_viewport_rect().size * where_now.get_scale()
	if _rainbow != null and _rainbow.visible:
		var on_screen := get_canvas_transform().affine_inverse()
		_rainbow.global_position = on_screen * Vector2.ZERO
		_rainbow.size = get_viewport_rect().size * on_screen.get_scale()
		_rainbow.material.set_shader_parameter("aspect", _rainbow.size.x / maxf(_rainbow.size.y, 1.0))
	if _grade == null or not _grade.visible:
		return
	var from_screen := get_canvas_transform().affine_inverse()
	_grade.global_position = from_screen * Vector2.ZERO
	_grade.size = get_viewport_rect().size * from_screen.get_scale()



## --- More to look at ---
##
## The designer, 2026-11-13 (proposals 21: "I like all the new suggestions you can do them"). View only, placeholders, every number
## PROPOSAL, nothing rolled from Combat.rng:
## - Wet reflections: after rain, each light is mirrored in the puddles below it (the ground's own, WET_SHADER's) and in a map's water,
##   broken up by ripples, more in the rain (_Reflections, REFLECTION_SHADER, REFLECTION, REFLECTION_TILES).
## - Leaves and petals on the wind: blossom in spring, leaves in autumn, a few green ones in a summer gale, crossing the board the way
##   it blows, more the harder (_leaves_wanted, _set_leaves). Slots: art/fx/petal.png, art/fx/leaf.png.
## - Birds' shadows: by day, now and then, a flock's shadows passing over the open ground the way the wind blows, fainter under cloud
##   (_Birds, _birds_wanted, BIRDS_EVERY, BIRD_SHADOW; birds_now for a look). Slot: art/fx/bird_shadow.png.
## - Smoke in the wind: from a flame out under the sky, leaning the wind's way (ChimneySmoke.make_smoke); a map's ChimneySmoke and
##   WindBanner nodes (banners, pennants, washing lines) do the same.
## - Light that blooms: a soft glow round each light after dark (BLOOM, _add_bloom), and the edges of the view a little darker after
##   dusk (GRADE_SHADER's vignette, VIGNETTE_MOST, _night_share).
## - Ground mist: low mist lying in sheltered ground and by water at night, thinning as the sun climbs, blown away by a wind
##   (_ground_mist_wanted, GROUND_MIST_SHADER, where it lies from _ground_mist_mask, GROUND_MIST_MOST).
## - Distant lightning: on a close summer night before a storm, far flashes at one edge of the view, with no thunder
##   (_far_lightning_wanted, FAR_FLASH, FAR_FLASH_GAP; far_lightning_now for a look).
## - The sky's pixels showing: at dawn and dusk, now and then, for a moment the light's edges step into pixels and the open sky with
##   them, a hint that it is not what it seems (_pixels_due, PIXELS_EVERY; sky_pixels_now for a look; the shaders' `pixels`).
## - Water that moves: a map's WaterPatch ripples the way the wind blows, foams where it meets the land, takes the rain's rings, and
##   the sun glints on it on the side where the sun stands at the hour, the moon faintly at night (_water, WATER_SHADER, under the dark
##   as the ground is, and lit by lamps).

const BLOOM := 0.3
const VIGNETTE_MOST := 0.36
const REFLECTION := 0.6
const REFLECTION_TILES := 2.4
const LEAVES_MOST := 70
const BIRDS_EVERY := [28.0, 80.0]
const BIRD_SHADOW := 0.28
const GROUND_MIST_MOST := 0.42
const FAR_FLASH := 0.22
const FAR_FLASH_GAP := [4.0, 15.0]
const PIXELS_EVERY := [45.0, 120.0]
## The next day's weathers a far flash comes before.
const STORMY := ["storm", "thunderstorm", "rain"]
const LEAF_PICTURE := "res://art/fx/leaf.png"
const PETAL_PICTURE := "res://art/fx/petal.png"
const BIRD_PICTURE := "res://art/fx/bird_shadow.png"

var _reflections: _Reflections = null
var _ground_noise_texture: NoiseTexture2D = null
var _leaves: CPUParticles2D = null
var _leaves_are := ""
var _birds: _Birds = null
var _next_birds := 12.0
var _ground_mist: Sprite2D = null
var _ground_mist_made := false
var _far_flash: ColorRect = null
var _next_far_flash := 3.0
var _pixels := 0.0
var _next_pixels := 15.0
var _water: Sprite2D = null
## The tiles water lies on, {tile: WaterPatch}.
var _water_tiles := {}
static var _leaf_pictures := {}

## The map's water: a pixel a tile in `water` (its colour, and in alpha whether there is any, 1 with foam at its edges and 0.6
## without).
const WATER_SHADER := """
shader_type canvas_item;
uniform sampler2D water : filter_nearest, repeat_disable;
uniform sampler2D picture : hint_default_white, repeat_enable, filter_linear;
uniform bool has_picture = false;
uniform vec2 tiles = vec2(16.0, 16.0);
uniform float glint = 0.0;
uniform vec3 glint_colour = vec3(1.0, 0.96, 0.84);
uniform float sun_at = 0.5;
uniform float raining = 0.0;
uniform vec2 drift = vec2(0.0);
uniform float pixels = 0.0;
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float wobble(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float water_at(vec2 tile) {
	if (tile.x < 0.0 || tile.y < 0.0 || tile.x >= tiles.x || tile.y >= tiles.y) {
		return 0.0;
	}
	return step(0.4, texture(water, (tile + 0.5) / tiles).a);
}
void fragment() {
	vec2 cell = UV * tiles;
	if (pixels > 0.0) {
		cell = mix(cell, floor(cell * 4.0) / 4.0 + 0.125, pixels);
	}
	vec2 tile = floor(cell);
	vec4 here = texture(water, (tile + 0.5) / tiles);
	if (here.a < 0.4) {
		discard;
	}
	vec2 in_tile = cell - tile;
	vec3 colour = here.rgb;
	if (has_picture) {
		colour *= texture(picture, cell).rgb;
	}
	// Ripples, two slow layers going the way the wind blows.
	vec2 flow = drift * 0.4 + vec2(0.05, 0.02);
	float one = wobble(cell * 3.0 - flow * TIME * 1.6);
	float two = wobble(cell * 5.3 + vec2(-flow.y, flow.x) * TIME * 1.1 + vec2(TIME * 0.07, 0.0));
	float wave = one * 0.6 + two * 0.4;
	colour *= 0.9 + 0.2 * wave;
	// Rings where the rain lands on it.
	if (raining > 0.01) {
		vec2 drop_cell = floor(cell * 4.0);
		float t = fract(TIME * 1.1 + hash(drop_cell));
		vec2 centre = (drop_cell + vec2(hash(drop_cell + 1.3), hash(drop_cell + 7.1))) / 4.0;
		float d = length(cell - centre) * 4.0;
		float ring = smoothstep(0.07, 0.0, abs(d - t * 0.8)) * (1.0 - t) * raining;
		colour = mix(colour, vec3(0.85, 0.92, 1.0), ring * 0.6);
	}
	// The sun's glint, on the side of the view where it stands at the hour; the moon's, fainter, by night.
	float band = exp(-pow((SCREEN_UV.x - sun_at) * 2.6, 2.0));
	vec2 spark_cell = floor(cell * 9.0);
	float spark = step(0.955, hash(spark_cell + floor(TIME * 2.5 + hash(spark_cell) * 9.0)));
	float crest = smoothstep(0.6, 0.82, wave);
	colour += glint_colour * glint * band * (spark * crest * 0.85 + crest * 0.1);
	// Foam where it meets the land: along each side with no water beyond it, broken up, coming and going.
	if (here.a > 0.9) {
		float edge = 9.0;
		if (water_at(tile + vec2(-1.0, 0.0)) < 0.5) { edge = min(edge, in_tile.x); }
		if (water_at(tile + vec2(1.0, 0.0)) < 0.5) { edge = min(edge, 1.0 - in_tile.x); }
		if (water_at(tile + vec2(0.0, -1.0)) < 0.5) { edge = min(edge, in_tile.y); }
		if (water_at(tile + vec2(0.0, 1.0)) < 0.5) { edge = min(edge, 1.0 - in_tile.y); }
		float froth = smoothstep(0.17, 0.02, edge + (wobble(cell * 8.0 + TIME * 0.35) - 0.5) * 0.12);
		colour = mix(colour, vec3(0.9, 0.95, 0.97), froth * (0.5 + 0.25 * sin(TIME * 1.2 + cell.x * 2.3 + cell.y * 1.9)));
	}
	COLOR = vec4(colour, 0.94);
}
"""

## A light mirrored below it, where the ground is wet (the ground's own puddles, as WET_SHADER lays them) or there is water.
const REFLECTION_SHADER := """
shader_type canvas_item;
render_mode unshaded, blend_add;
uniform sampler2D noise : repeat_enable, filter_linear;
uniform sampler2D ground : filter_linear, repeat_disable;
uniform sampler2D water : filter_nearest, repeat_disable;
uniform vec2 map_origin = vec2(0.0);
uniform vec2 map_size = vec2(1.0);
uniform float tile = 256.0;
uniform float wet = 0.0;
uniform float raining = 0.0;
uniform float strength = 0.6;
varying vec2 world;
varying vec4 tint;
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	tint = COLOR;
}
void fragment() {
	vec2 on_map = (world - map_origin) / map_size;
	if (on_map.x < 0.0 || on_map.y < 0.0 || on_map.x > 1.0 || on_map.y > 1.0) {
		discard;
	}
	vec2 cell = (world - map_origin) / tile;
	float open = step(0.5, texture(ground, on_map).r);
	float pool = smoothstep(0.6 - wet * 0.28, 0.48 - wet * 0.28, texture(noise, cell * 0.09).r) * clamp(wet * 1.4, 0.0, 1.0) * open;
	float mirror = max(pool, step(0.4, texture(water, on_map).a));
	float wave = sin(world.y * 0.09 + TIME * (1.8 + raining * 3.0)) * (0.05 + 0.1 * raining)
		+ (texture(noise, cell * 0.7 + vec2(TIME * 0.05, 0.0)).r - 0.5) * 0.12;
	float streak = texture(TEXTURE, vec2(UV.x + wave, UV.y)).a;
	float bands = 0.6 + 0.4 * sin(world.y * 0.06 - TIME * 1.4 + texture(noise, cell * 0.35 + vec2(0.0, TIME * 0.03)).r * 6.283);
	COLOR = vec4(tint.rgb, tint.a * streak * mirror * bands * strength);
}
"""

## Low mist where `lies` says, a pixel a tile, drifting slowly the way the wind blows.
const GROUND_MIST_SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D noise : repeat_enable, filter_linear;
uniform sampler2D lies : filter_linear, repeat_disable;
uniform vec2 tiles = vec2(16.0, 16.0);
uniform float amount = 0.0;
uniform vec2 drift = vec2(1.0, 0.3);
uniform float pixels = 0.0;
void fragment() {
	vec2 uv = UV;
	if (pixels > 0.0) {
		vec2 steps = tiles * 2.0;
		uv = mix(UV, (floor(UV * steps) + 0.5) / steps, pixels);
	}
	vec2 at = uv * tiles / 3.0;
	vec2 way = normalize(drift + vec2(0.0001));
	float one = texture(noise, at - way * TIME * 0.006).r;
	float two = texture(noise, at * 1.9 + vec2(way.y, -way.x) * TIME * 0.004).r;
	float wisp = smoothstep(0.3, 0.75, one * 0.6 + two * 0.4);
	COLOR = vec4(0.8, 0.84, 0.9, wisp * texture(lies, UV).r * amount);
}
"""

## A far flash beyond one edge of the view (`side`, the way to it from the middle), only under the open sky.
const FAR_FLASH_SHADER := """
shader_type canvas_item;
render_mode unshaded, blend_add;
uniform sampler2D sky_mask : hint_default_white, filter_linear, repeat_disable;
uniform vec2 mask_origin = vec2(0.0);
uniform vec2 mask_size = vec2(0.0);
uniform vec2 screen_origin = vec2(0.0);
uniform vec2 screen_extent = vec2(0.0);
uniform vec2 side = vec2(1.0, -0.4);
uniform float flash = 0.0;
void fragment() {
	float open = 1.0;
	if (mask_size.x > 0.0 && screen_extent.x != 0.0) {
		vec2 on_map = (screen_origin + SCREEN_UV * screen_extent - mask_origin) / mask_size;
		if (on_map.x >= 0.0 && on_map.y >= 0.0 && on_map.x <= 1.0 && on_map.y <= 1.0) {
			open = texture(sky_mask, on_map).r;
		}
	}
	float towards = clamp(dot(SCREEN_UV - 0.5, normalize(side)) + 0.5, 0.0, 1.0);
	COLOR = vec4(vec3(0.62, 0.7, 1.0) * flash * pow(towards, 2.2) * open, 1.0);
}
"""


func _more_to_look_at(delta: float):
	if _sky_shown.is_empty() or not visible:
		return
	if _birds != null:
		_next_birds -= delta
		if _next_birds <= 0.0:
			_next_birds = randf_range(BIRDS_EVERY[0], BIRDS_EVERY[1])
			var how_dark := _birds_wanted(_sky_shown)
			if how_dark > 0.05:
				birds_now(how_dark)
	_next_far_flash -= delta
	if _next_far_flash <= 0.0:
		var far := _far_lightning_wanted(_sky_shown)
		_next_far_flash = lerpf(FAR_FLASH_GAP[1], FAR_FLASH_GAP[0], far) * randf_range(0.7, 1.3) if far > 0.0 else FAR_FLASH_GAP[0]
		if far > 0.0:
			far_lightning_now(randf_range(0.5, 1.0))
	_pixels_due(delta)


## How far into the dark of the night it is, 0 by day to 1: by the sun where the sky has a say, by the place's own light where not.
func _night_share(sky: Dictionary) -> float:
	var amount := float(sky.get("amount", -1.0))
	if amount >= 0.0:
		return clampf((0.8 - amount) / 0.34, 0.0, 1.0)
	if light == null:
		return 0.0
	return [1.0, 0.5, 0.0][clampi(light.base, 0, 2)]


## How dark it is round a light, 0 to 1, for its glow: by what the place would be without it.
func _dark_round(source: Dictionary) -> float:
	if light == null or not source.has("tile"):
		return 0.0
	return clampf((1.0 - light.ambient_amount_at(source.tile)) / 0.6, 0.0, 1.0)


## Whether the grade over the view is wanted: a change of colour, the heat's shimmer, the night's darker edges, or the sky's pixels.
func _grade_wanted(sky: Dictionary) -> bool:
	return not (is_equal_approx(float(sky.get("saturation", 1.0)), 1.0) and is_equal_approx(float(sky.get("contrast", 1.0)), 1.0)) \
		or (air_on and (float(sky.get("shimmer", 0.0)) > 0.01 or _night_share(sky) > 0.01 or _pixels > 0.0))


## A soft glow round a light, on its own node, shown after dark (_process); none for a window.
func _add_bloom(node: PointLight2D, source: Dictionary):
	if source.get("opening", false):
		return
	var glow := Sprite2D.new()
	glow.name = "Bloom"
	glow.texture = light_picture()
	glow.light_mask = 0
	glow.z_as_relative = false
	glow.z_index = ExplorationParty.PARTY_Z_TOP
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	glow.material = add
	glow.scale = Vector2.ONE * light_scale(maxf(float(source.get("bright", 1.0)), 1.0) * 0.6)
	glow.modulate = Color(source.get("colour", Color.WHITE), 0.0)
	node.add_child(glow)


## The colour a thing standing at `at` takes from the dark about it (a banner, smoke): white where it is lit, nearer the shade's own
## colour the heavier the shade is there.
static func lit_colour_at(at: Vector2) -> Color:
	if showing == null or not is_instance_valid(showing) or not showing.visible:
		return Color.WHITE
	return Color.WHITE.lerp(Color(SHADE_COLOUR, 1.0), clampf(showing._shade_at(at), 0.0, 1.0))


## How heavy the shade is at `at`, a place in the world: where it is going, not where it is on the way.
func _shade_at(at: Vector2) -> float:
	if _shade_target == null or _tile_map == null:
		return 0.0
	var tile := _tile_map.local_to_map(_tile_map.to_local(at)) - _region.position
	if tile.x < 0 or tile.y < 0 or tile.x >= _shade_target.get_width() or tile.y >= _shade_target.get_height():
		return 0.0
	return _shade_target.get_pixel(tile.x, tile.y).a


func _wall_at(tile: Vector2i) -> bool:
	return light != null and light.blocks_light != null and light.blocks_light.is_valid() and light.blocks_light.call(tile)


## Whether `tile` is high ground (the TileSet's Climb).
func _high_ground(tile: Vector2i) -> bool:
	if _tile_map == null or _tile_map.tile_set == null or _tile_map.tile_set.get_custom_data_layer_by_name("Climb") < 0:
		return false
	var data := _tile_map.get_cell_tile_data(0, tile)
	return data != null and bool(data.get_custom_data("Climb"))


## --- Wet reflections ---


func _make_the_reflections(region: Rect2i):
	_reflections = _Reflections.new()
	_reflections.name = "Reflections"
	_reflections.view = self
	_reflections.light_mask = 0
	_reflections.streak = _streak_picture()
	_reflections.material = _material(REFLECTION_SHADER)
	_reflections.visible = false
	var half := Vector2(Grid.TILE_SIZE, Grid.TILE_SIZE) / 2.0
	var origin: Vector2 = _tile_map.to_global(_tile_map.map_to_local(region.position) - half)
	var far: Vector2 = _tile_map.to_global(_tile_map.map_to_local(region.end) - half)
	_reflections.material.set_shader_parameter("map_origin", origin)
	_reflections.material.set_shader_parameter("map_size", far - origin)
	_reflections.material.set_shader_parameter("tile", float(Grid.TILE_SIZE))
	_reflections.material.set_shader_parameter("noise", _ground_noise_texture)
	_reflections.material.set_shader_parameter("strength", REFLECTION)
	add_child(_reflections)


## A light's streak on wet ground: bright where it begins, fading away from the light and to either side.
static func _streak_picture() -> Texture2D:
	var image := Image.create(32, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 32:
			var across := (float(x) + 0.5) / 16.0 - 1.0
			var along := (float(y) + 0.5) / 128.0
			var a := pow(maxf(1.0 - across * across, 0.0), 1.5) * pow(1.0 - along, 1.4)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(image)


func _put_on_the_reflections(sky: Dictionary):
	if _reflections == null:
		return
	var wet := float(_ground_wanted.get("wet", 0.0))
	_reflections.visible = air_on and not _lights.is_empty() and (wet > 0.05 or not _water_tiles.is_empty())
	if not _reflections.visible:
		return
	_reflections.material.set_shader_parameter("wet", wet)
	_reflections.material.set_shader_parameter("raining", clampf(Light.rain_loudness(sky), 0.0, 1.0))


## Each light mirrored below it, drawn through REFLECTION_SHADER, which keeps only what falls on the wet and the water.
class _Reflections extends Node2D:
	var view: LightView = null
	var streak: Texture2D = null

	func _process(_delta: float):
		if visible:
			queue_redraw()

	func _draw():
		if view == null or not is_instance_valid(view) or streak == null:
			return
		var tile := float(Grid.TILE_SIZE)
		for entry in view._lights:
			var node: PointLight2D = entry.node
			if not is_instance_valid(node) or entry.source.get("opening", false):
				continue
			var strength: float = clampf(node.energy / LightView.ENERGY, 0.0, 1.4)
			if strength < 0.03:
				continue
			var reach: float = maxf(float(entry.source.get("bright", 1.0)), 1.0)
			var size := Vector2(tile * (0.3 + 0.1 * reach), tile * LightView.REFLECTION_TILES * (0.7 + 0.15 * reach))
			draw_texture_rect(streak, Rect2(node.position + Vector2(-size.x / 2.0, tile * 0.15), size), false, Color(node.color, strength))


## --- Leaves and petals on the wind ---


## What blows across the board now, and how much of it, 0 to 1: blossom in spring, leaves in autumn, a few green ones in a summer
## gale; none where there is no sky, nor in snow, hail, sand or ash.
func _leaves_wanted(sky: Dictionary) -> Dictionary:
	var none := {"what": "", "amount": 0.0}
	if not air_on or float(sky.get("amount", -1.0)) < 0.0:
		return none
	for key in ["snow", "hail", "sand", "ash"]:
		if float(sky.get(key, 0.0)) > 0.05:
			return none
	var wind := float(sky.get("wind", 0.0))
	match Campaign.season_now():
		"spring":
			return {"what": "petals", "amount": clampf(0.12 + wind * 1.1, 0.0, 1.0)}
		"autumn":
			return {"what": "leaves", "amount": clampf(0.15 + wind * 1.1, 0.0, 1.0)}
		"summer":
			if wind >= 0.5:
				return {"what": "green", "amount": clampf((wind - 0.4) * 0.8, 0.0, 0.5)}
	return none


func _set_leaves(wanted: Dictionary, wind: float):
	var amount: float = wanted.amount
	if amount <= 0.01:
		if _leaves != null:
			_leaves.emitting = false
		_leaves_are = ""
		return
	var tile := float(Grid.TILE_SIZE)
	if _leaves == null:
		_leaves = _air_bits("Leaves")
		_leaves.gravity = Vector2.ZERO
		_leaves.lifetime = 5.5
		_leaves.spread = 22.0
		_leaves.angle_min = 0.0
		_leaves.angle_max = 360.0
		_leaves.angular_velocity_min = -160.0
		_leaves.angular_velocity_max = 160.0
		_leaves.tangential_accel_min = -tile * 0.4
		_leaves.tangential_accel_max = tile * 0.4
		_leaves.scale_amount_min = 2.2
		_leaves.scale_amount_max = 3.4
		var fade := Gradient.new()
		fade.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
		fade.add_point(0.08, Color(1.0, 1.0, 1.0, 0.95))
		fade.add_point(0.85, Color(1.0, 1.0, 1.0, 0.9))
		fade.set_color(fade.get_point_count() - 1, Color(1.0, 1.0, 1.0, 0.0))
		_leaves.color_ramp = fade
	if wanted.what != _leaves_are:
		_leaves_are = wanted.what
		_leaves.texture = _leaf_picture(wanted.what)
		_leaves.color_initial_ramp = _leaf_colours(wanted.what)
	var count := maxi(roundi(float(LEAVES_MOST) * amount), 6)
	if absi(_leaves.amount - count) > maxi(_leaves.amount / 3, 2):
		_leaves.amount = count
	_leaves.direction = (_wind_way() + Vector2(0.0, 0.35)).normalized()
	_leaves.initial_velocity_min = tile * (0.4 + 2.2 * wind)
	_leaves.initial_velocity_max = tile * (0.8 + 3.6 * wind)
	_leaves.modulate.a = clampf(amount * 3.0, 0.0, 1.0)
	_leaves.emitting = true


## A petal or a leaf, drawn here unless its slot has a picture: white, to take each one's colour (_leaf_colours).
static func _leaf_picture(what: String) -> Texture2D:
	var slot := PETAL_PICTURE if what == "petals" else LEAF_PICTURE
	if ResourceLoader.exists(slot):
		return load(slot)
	if _leaf_pictures.has(what):
		return _leaf_pictures[what]
	var size := Vector2i(12, 9) if what == "petals" else Vector2i(18, 10)
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			var u := (float(x) + 0.5) / float(size.x)
			var v := (float(y) + 0.5) / float(size.y) * 2.0 - 1.0
			var half := sqrt(maxf(1.0 - pow(u * 2.0 - 1.0, 2.0), 0.0)) if what == "petals" else sin(PI * u)
			var inside := clampf((half - absf(v)) * float(size.y) * 0.5, 0.0, 1.0)
			# A leaf's vein down its middle, a little darker.
			var shade := 0.8 if what != "petals" and absf(v) < 0.14 and u > 0.08 and u < 0.92 else 1.0
			image.set_pixel(x, y, Color(shade, shade, shade, inside))
	var picture := ImageTexture.create_from_image(image)
	_leaf_pictures[what] = picture
	return picture


## The colours they come in, one each, at random.
static func _leaf_colours(what: String) -> Gradient:
	var colours: Array
	match what:
		"petals":
			colours = [Color(1.0, 0.82, 0.88), Color(1.0, 0.97, 0.97), Color(0.98, 0.7, 0.8), Color(1.0, 0.9, 0.93)]
		"green":
			colours = [Color(0.38, 0.6, 0.22), Color(0.5, 0.7, 0.28), Color(0.3, 0.5, 0.2)]
		_:
			colours = [Color(0.86, 0.45, 0.14), Color(0.72, 0.2, 0.1), Color(0.9, 0.72, 0.22), Color(0.5, 0.32, 0.16), Color(0.8, 0.55, 0.2)]
	var ramp := Gradient.new()
	ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	ramp.set_color(0, colours[0])
	ramp.set_color(1, colours[colours.size() - 1])
	for i in range(1, colours.size()):
		ramp.add_point(float(i) / float(colours.size()), colours[i])
	return ramp


## --- Birds' shadows ---


## Whether birds' shadows would pass now, and how dark, 0 to 1: by day under the open sky, fainter the more cloud; none in rain,
## snow, hail, sand, ash, fog or a storm.
func _birds_wanted(sky: Dictionary) -> float:
	if not air_on or float(sky.get("amount", -1.0)) < 0.7:
		return 0.0
	var minute := Campaign.minute_of_day()
	if minute < 390 or minute > 1110:
		return 0.0
	if float(sky.get("rain", 0.0)) > 0.2 or float(sky.get("snow", 0.0)) > 0.05 or float(sky.get("hail", 0.0)) > 0.05 \
			or float(sky.get("sand", 0.0)) > 0.05 or float(sky.get("ash", 0.0)) > 0.05 or float(sky.get("mist", 0.0)) > 0.5 \
			or float(sky.get("lightning", 0.0)) > 0.05:
		return 0.0
	return clampf(1.0 - float(sky.get("clouds", 0.0)) * 0.75, 0.0, 1.0)


## A flock's shadows across the view now, `how_dark` of them (and for a look, whatever the sky).
func birds_now(how_dark: float = 1.0):
	if _birds == null or not is_inside_tree():
		return
	var tile := float(Grid.TILE_SIZE)
	var from_screen := get_canvas_transform().affine_inverse()
	var view := get_viewport_rect().size * from_screen.get_scale()
	var middle: Vector2 = to_local(from_screen * (get_viewport_rect().size / 2.0))
	var way := _wind_way().rotated(randf_range(-0.7, 0.7)) if float(_sky_shown.get("wind", 0.0)) > 0.1 else Vector2.RIGHT.rotated(randf() * TAU)
	var across := view.length() * 0.62
	var speed := tile * randf_range(3.0, 4.6)
	var flock := {"at": middle - way * across + way.orthogonal() * randf_range(-0.3, 0.3) * view.y, "way": way, "speed": speed,
		"lasts": across * 2.0 / speed, "left": across * 2.0 / speed, "strength": how_dark, "birds": []}
	var in_a_v := randf() < 0.5
	for i in randi_range(3, 9):
		var offset: Vector2
		if in_a_v:
			var rank := floorf(float(i + 1) / 2.0)
			offset = -way * rank * tile * 0.45 + way.orthogonal() * rank * tile * 0.38 * (1.0 if i % 2 == 0 else -1.0)
		else:
			offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * tile * 1.1
		flock.birds.append({"offset": offset, "size": randf_range(0.5, 0.75), "rate": randf_range(7.0, 10.0), "phase": randf() * TAU,
			"glide": randf_range(1.5, 4.0)})
	_birds.flocks.append(flock)


## The flocks going over, each a shadow a bird, flapping and now and then gliding.
class _Birds extends Node2D:
	## [{"at", "way", "speed", "lasts", "left", "strength", "birds": [{"offset", "size", "rate", "phase", "glide"}]}]
	var flocks: Array = []
	var picture: Texture2D = null

	func _process(delta: float):
		if flocks.is_empty():
			return
		for flock in flocks:
			flock["at"] = flock["at"] + flock["way"] * float(flock["speed"]) * delta
			flock["left"] = float(flock["left"]) - delta
		flocks = flocks.filter(func(flock): return flock.left > 0.0)
		queue_redraw()

	func _draw():
		var tile := float(Grid.TILE_SIZE)
		var now := Time.get_ticks_msec() / 1000.0
		for flock in flocks:
			var fade: float = clampf(flock.left / 1.5, 0.0, 1.0) * clampf((flock.lasts - flock.left) / 1.5, 0.0, 1.0)
			var colour := Color(0.02, 0.03, 0.08, LightView.BIRD_SHADOW * float(flock.strength) * fade)
			var forward: Vector2 = flock.way
			var side := forward.orthogonal()
			for bird in flock.birds:
				var at: Vector2 = flock.at + bird.offset
				var span: float = tile * float(bird.size)
				var flapping: bool = fmod(now + float(bird.phase), float(bird.glide) + 1.4) < 1.4
				var reach := span * ((0.6 + 0.4 * absf(cos(now * float(bird.rate) + float(bird.phase)))) if flapping else 1.0)
				if picture != null:
					draw_set_transform(at, forward.angle() + PI / 2.0, Vector2(reach / span, 1.0))
					draw_texture_rect(picture, Rect2(-Vector2(span, span) / 2.0, Vector2(span, span)), false, colour)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
					continue
				var nose := at + forward * span * 0.18
				var tail := at - forward * span * 0.1
				var left_tip := at + side * reach * 0.5 - forward * span * 0.22
				var right_tip := at - side * reach * 0.5 - forward * span * 0.22
				draw_colored_polygon(PackedVector2Array([nose, left_tip, tail, right_tip]), colour)


## --- Ground mist ---


## How much low mist lies in the hollows now, 0 to 1: through the night and the early morning, thinning as the sun climbs and gone
## by half past nine, coming in again after dusk; blown away by a wind; thinner in rain; none in snow, sand, ash, heat or a storm.
func _ground_mist_wanted(sky: Dictionary) -> float:
	if not air_on or float(sky.get("amount", -1.0)) < 0.0:
		return 0.0
	if float(sky.get("snow", 0.0)) > 0.1 or float(sky.get("sand", 0.0)) > 0.05 or float(sky.get("ash", 0.0)) > 0.05 \
			or float(sky.get("shimmer", 0.0)) > 0.1 or float(sky.get("lightning", 0.0)) > 0.05:
		return 0.0
	var minute := float(Campaign.minute_of_day())
	var by_hour: float
	if minute >= 1140.0:
		by_hour = smoothstep(1140.0, 1260.0, minute)
	elif minute < 420.0:
		by_hour = 1.0
	else:
		by_hour = 1.0 - smoothstep(420.0, 570.0, minute)
	var still := 1.0 - smoothstep(0.2, 0.6, float(sky.get("wind", 0.0)))
	var wet := 0.6 if float(sky.get("rain", 0.0)) > 0.4 else 1.0
	var season: float = {"spring": 1.0, "summer": 0.7, "autumn": 1.0, "winter": 0.85}.get(Campaign.season_now(), 1.0)
	return by_hour * still * wet * season


func _set_ground_mist(amount: float):
	if _ground_mist == null:
		return
	_ground_mist.visible = air_on and amount > 0.01
	if not _ground_mist.visible:
		return
	if not _ground_mist_made:
		_ground_mist_made = true
		_ground_mist.material.set_shader_parameter("lies", _ground_mist_mask())
	_ground_mist.material.set_shader_parameter("amount", amount * GROUND_MIST_MOST)
	_ground_mist.material.set_shader_parameter("drift", Vector2(Campaign.wind_now()))


## Where the low mist lies, a pixel a tile: open ground, more where it is sheltered (walls and high ground about it) and by water;
## none on a wall, up on high ground or under a roof.
func _ground_mist_mask() -> ImageTexture:
	var image := Image.create(maxi(_region.size.x, 1), maxi(_region.size.y, 1), false, Image.FORMAT_L8)
	var steps := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
	for y in _region.size.y:
		for x in _region.size.x:
			var tile := _region.position + Vector2i(x, y)
			var lies := 0.0
			if light != null and light.under_the_sky(tile) and not _wall_at(tile) and not _high_ground(tile):
				var about := 0
				for step in steps:
					if _wall_at(tile + step) or _high_ground(tile + step):
						about += 1
				var by_water := 0.0
				if not _water_tiles.is_empty():
					for dy in range(-2, 3):
						for dx in range(-2, 3):
							if _water_tiles.has(tile + Vector2i(dx, dy)):
								by_water = maxf(by_water, 1.0 - Vector2(dx, dy).length() / 3.0)
				lies = clampf(0.3 + float(about) / 8.0 * 0.5 + by_water * 0.5, 0.0, 1.0)
			image.set_pixel(x, y, Color(lies, lies, lies))
	return ImageTexture.create_from_image(image)


## --- Distant lightning ---


## How often far flashes come now, 0 to 1: a summer night under the open sky before a storm (the next day's weather a storm or
## rain), or a close one (a day of heat); never in a storm itself, nor in rain or snow.
func _far_lightning_wanted(sky: Dictionary) -> float:
	if not air_on or float(sky.get("amount", -1.0)) < 0.0 or Campaign.season_now() != "summer":
		return 0.0
	if float(sky.get("lightning", 0.0)) > 0.05 or float(sky.get("rain", 0.0)) > 0.1 or float(sky.get("snow", 0.0)) > 0.01:
		return 0.0
	var minute := Campaign.minute_of_day()
	if minute < 1230 and minute >= 270:
		return 0.0
	if STORMY.has(Campaign.weather_on(Campaign.day_number() + (1 if minute >= 720 else 0))):
		return 1.0
	return 0.6 if Campaign.weather_today() == "heat" else 0.0


## A far flash at one edge of the view, with no thunder (and for a look, whatever the sky).
func far_lightning_now(strength: float = 1.0):
	if _far_flash == null or not is_inside_tree():
		return
	var from_screen := get_canvas_transform().affine_inverse()
	_far_flash.global_position = from_screen * Vector2.ZERO
	_far_flash.size = get_viewport_rect().size * from_screen.get_scale()
	_far_flash.material.set_shader_parameter("side", Vector2.RIGHT.rotated(randf() * TAU))
	_far_flash.visible = true
	var most := FAR_FLASH * strength
	var flash := create_tween()
	flash.tween_method(_set_far_flash, 0.0, most, 0.06)
	flash.tween_method(_set_far_flash, most, most * 0.25, 0.12)
	flash.tween_method(_set_far_flash, most * 0.25, most * 0.8, 0.05)
	flash.tween_method(_set_far_flash, most * 0.8, 0.0, 0.5)
	flash.tween_callback(func(): _far_flash.visible = false)


func _set_far_flash(value: float):
	_far_flash.material.set_shader_parameter("flash", value)


## --- The sky's pixels showing ---


func _pixels_due(delta: float):
	_next_pixels -= delta
	if _next_pixels > 0.0:
		return
	_next_pixels = randf_range(PIXELS_EVERY[0], PIXELS_EVERY[1])
	if not air_on or float(_sky_shown.get("amount", -1.0)) < 0.0:
		return
	var minute := Campaign.minute_of_day()
	if (minute >= 300 and minute < 480) or (minute >= 1020 and minute < 1200):
		sky_pixels_now()


## For a moment, the light's edges and the open sky step into pixels (and for a look, whatever the hour).
func sky_pixels_now():
	if not is_inside_tree():
		return
	var moment := create_tween()
	for step in [[1.0, 0.16], [0.0, 0.08], [1.0, 0.45], [0.5, 0.1], [1.0, 0.3], [0.0, 0.0]]:
		moment.tween_callback(_set_pixels.bind(step[0]))
		if step[1] > 0.0:
			moment.tween_interval(step[1])


func _set_pixels(value: float):
	_pixels = value
	for layer in [_shade, _clouds, _mist, _ground_mist, _water]:
		if layer != null:
			layer.material.set_shader_parameter("pixels", value)
	if _grade != null:
		_grade.material.set_shader_parameter("pixels", value)
		if not _sky_shown.is_empty():
			_grade.visible = _grade_wanted(_sky_shown)
			_grade_copy.visible = _grade.visible


## --- Water that moves ---


## The map's water (WaterPatch), gathered once: the tiles it covers, and a picture of it a pixel a tile for WATER_SHADER.
func _gather_the_water():
	_water_tiles.clear()
	if _tile_map == null or _water == null or not is_inside_tree():
		return
	var top: Node = _tile_map
	while top.get_parent() != null and top.get_parent() != get_tree().root:
		top = top.get_parent()
	for patch in top.find_children("*", "WaterPatch", true, false):
		for tile in patch.covers(patch.first_tile(_tile_map)):
			_water_tiles[tile] = patch
	if _water_tiles.is_empty():
		return
	var image := Image.create(maxi(_region.size.x, 1), maxi(_region.size.y, 1), false, Image.FORMAT_RGBA8)
	for tile in _water_tiles:
		var at: Vector2i = tile - _region.position
		if at.x < 0 or at.y < 0 or at.x >= _region.size.x or at.y >= _region.size.y:
			continue
		var patch: WaterPatch = _water_tiles[tile]
		image.set_pixel(at.x, at.y, Color(patch.colour, 1.0 if patch.foam else 0.6))
	var mask := ImageTexture.create_from_image(image)
	_water.material.set_shader_parameter("water", mask)
	if _reflections != null:
		_reflections.material.set_shader_parameter("water", mask)
	if ResourceLoader.exists(WaterPatch.PICTURE):
		_water.material.set_shader_parameter("picture", load(WaterPatch.PICTURE))
		_water.material.set_shader_parameter("has_picture", true)
	_water.visible = true


func _put_on_the_water(sky: Dictionary):
	if _water == null or not _water.visible:
		return
	var clouds := float(sky.get("clouds", 0.0))
	var by_day := clampf((float(sky.get("amount", 1.0)) - 0.5) / 0.4, 0.0, 1.0)
	var sun := by_day * (1.0 - clouds * 0.8)
	var moon := 0.0 if Campaign.no_moon_now() else 0.25 * (1.0 - by_day) * (1.0 - clouds)
	_water.material.set_shader_parameter("glint", maxf(sun, moon))
	_water.material.set_shader_parameter("glint_colour", Vector3(1.0, 0.96, 0.84) if sun >= moon else Vector3(0.75, 0.82, 1.0))
	_water.material.set_shader_parameter("sun_at", clampf(0.5 - float(sky.get("lean", 0.0)) * 0.34, 0.08, 0.92))
	_water.material.set_shader_parameter("raining", clampf(Light.rain_loudness(sky), 0.0, 1.0))
	_water.material.set_shader_parameter("drift", Vector2(Campaign.wind_now()).normalized() * float(sky.get("wind", 0.0)))
