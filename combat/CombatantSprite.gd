extends Node2D
class_name CombatantSprite
## The visual representation of one combatant on the map. Combat.gd and
## CController.gd only ever talk to this - never to an underlying
## Sprite2D/AnimatedSprite2D directly - so a combatant can be upgraded from
## a static sprite to full animations just by setting sprite_frames on its
## CombatantDefinition, with nothing else in the codebase needing to change.
##
## To animate a combatant: create a SpriteFrames resource (Godot's built-in
## animated-sprite tool - select an AnimatedSprite2D node, open the
## "Animations" panel at the bottom, and either build one from scratch or
## import your existing spritesheet/frames into it) with any of these named
## animations:
##   "idle" - played whenever this combatant isn't moving or using a skill.
##            Required for animations to do anything at all.
##   "walk" - played for the duration of each movement step.
##   "skill" - played once when this combatant uses a skill. Combat.gd
##             awaits this before the skill's actual effect resolves and
##             before that combatant can act or move again - so with a
##             skill animation set, using a skill genuinely pauses them
##             (and locks player input) for its duration, not just a visual
##             flourish alongside an instant result.
##   "dead" - played once a combatant dies, instead of falling back to the
##            plain "second frame of the sheet" a static sprite uses.
## Then set that resource as the CombatantDefinition's sprite_frames. Leave
## sprite_frames empty to keep using the plain static map_sprite, exactly as
## every existing combatant does today.
##
## Frames can be taller than one tile - see Grid.TILE_SIZE for what a tile
## actually measures - and any extra height automatically shifts the sprite up
## so its feet still stand at the bottom of its own tile, instead of it
## centring on the tile and sinking into the ground. A frame twice the height
## of a tile therefore stands a whole tile above it, which is the point.
##
## Width is a choice rather than a rule. At tile width nobody overlaps a
## neighbour; wider than that, they overhang each other, which reads as a
## crowd rather than a fault because the combatant layer is y-sorted (see
## Combat.combatant_layer) and whoever is nearer the bottom of the screen
## draws in front.
##
## Computed from the actual frame size rather than a fixed assumption, so any
## height works with no extra setup - and measured afresh whenever the
## animation changes, so one combatant's animations can be different sizes: a
## set part-redrawn bigger (a 384-pixel idle beside 192-pixel walks) keeps its
## feet on the ground in every one of them. How far above the head things go
## (head_height) is still the idle's.

var _animated: AnimatedSprite2D = null
var _static: Sprite2D = null

## How solid this combatant is drawn, for hiding.
##
## Kept off `modulate` on purpose: that one is already spoken for by the hit
## flash and the death fade, both of which tween it back to a colour of their
## own choosing and would wipe a hidden combatant back into view mid-fight. The
## child sprite's own self_modulate is a separate channel that multiplies with
## the parent's, so a hidden combatant can still flash when hit without either
## effect undoing the other.
var hidden_alpha := 1.0
## Their colour on the map (CombatantDefinition.tint) - on self_modulate too,
## under the hiding alpha, so neither undoes the other.
var tint := Color.WHITE


func set_hidden_alpha(alpha: float):
	hidden_alpha = alpha
	for sprite in [_animated, _static]:
		if sprite != null and is_instance_valid(sprite):
			var lit: Color = Color.WHITE if _figure_material != null and sprite.material == _figure_material and shade_map != null else lit_by
			sprite.self_modulate = Color(tint * lit * condition_tint, alpha)


## --- What is on them, on them (ConditionLook) ---

## The colour over them for what is on them, breathing: white for none.
var condition_tint := Color.WHITE
var _condition_look: ConditionLook = null
## What was on them the last time it was said, by condition, so that what is new can pop up as it lands.
var conditions_on_show := {}


func set_condition_tint(colour: Color):
	if colour != condition_tint:
		condition_tint = colour
		set_hidden_alpha(hidden_alpha)


## What is on them: [{"condition", "helps", "ends_soon"}].
func show_conditions(entries: Array):
	if _condition_look == null:
		if entries.is_empty():
			return
		_condition_look = ConditionLook.new()
		add_child(_condition_look)
	_condition_look.show_entries(entries)


## The animation they stand in, in place of idle, while it is wanted (ConditionLook). None by that name, and they stand idle.
var pose: StringName = &""


func set_pose(wanted: StringName):
	if wanted == pose:
		return
	var was: StringName = pose
	pose = wanted
	if _animated != null and (_animated.animation == &"idle" or _animated.animation == was):
		play_idle()


## --- A shadow under them ---
##
## View only (the designer, 2026-11-07, docs/proposals_2026-11-07.md section 10). Their own shape, the frame they are showing, black
## and laid along the ground away from whatever lights them: one for each of the nearest lights, up to MOST_SHADOWS, each as
## strong as its light, long when the light is far and short when it is close, and blurring and fading towards its far end. A wall
## stops it. With no light near them, the sun's or the moon's: its lean and length go with the hour, and its colour too
## (Light.shadow_at). A dark patch where they stand, unless they are off the ground, when it is all smaller, fainter and further off.
## A picture at SHADOW_PICTURE is drawn for that patch, in place of the soft round light in black.

const SHADOW_PICTURE := "res://art/fx/figure_shadow.png"
static var shadow_lean := 0.12
static var shadow_strength := 0.35
static var shadow_colour := Color.BLACK
## How soft the sun's or the moon's shadow is, against a lamp's: hard at noon and soft at either end of the day or under cloud.
static var shadow_soft := 1.0
## Counts changes, for each shadow to see that it has to draw itself again.
static var shadow_version := 0
## Each light here: {"at", "reach", "colour", "node", "energy"}: for shadows to point away from, and the figures' colour (LightView).
static var light_points: Array = []
## How fast anybody under the open sky gets wet now: rain, sleet, a little for snow (LightView._put_on_the_sky). 0: they dry.
static var soaking := 0.0
## Whether a place in the world is under the open sky (LightView), or nothing to ask.
static var under_the_sky := Callable()
## The shine masks found, by the frame's own file (shine_mask_for): a texture, or null for none.
static var _shine_masks := {}
## How wet they are, 0 to 1: soaking under the rain, drying out of it (the designer, 2026-11-07: "make them seem slowly getting
## wet when it rains").
var wetness := 0.0
## Whether something at a place on the map stops a shadow (LightView), or nothing to ask.
static var stops_shadow: Callable = Callable()
const MOST_SHADOWS := 3
## How far a shadow goes, in figure heights: from a light close by, from one at the end of its reach, and at most from the sun.
const SHADOW_CLOSE := 0.3
const SHADOW_FAR := 1.15
const SUN_SHADOW_MOST := 1.2
## How much a shadow slants down the screen, whichever way the sun leans it.
const SUN_SLANT := 0.35
## How much the floor's slant shortens what lies along the screen's height.
const FLOOR_SLANT := 0.6
## How soft a shadow is at their feet and at its far end, as shares of the frame.
const SHADOW_SHARP := 0.004
const SHADOW_SOFT := 0.045
## Their shape, from the alpha only, blurred more the further along it is. The vertex colour's red says how far along it is
## (the shadow's own colour is a uniform: only the sun's has one) and its alpha how strong.
const SHADOW_SHADER := """
shader_type canvas_item;
uniform vec3 shade_colour = vec3(0.0);
uniform vec2 sharp = vec2(0.001);
uniform vec2 soft = vec2(0.02);
varying vec4 tint;
void vertex() {
	tint = COLOR;
}
void fragment() {
	vec2 reach = mix(sharp, soft, tint.r);
	float sum = texture(TEXTURE, UV).a * 2.0;
	sum += texture(TEXTURE, UV + reach * vec2(1.0, 0.0)).a;
	sum += texture(TEXTURE, UV + reach * vec2(-1.0, 0.0)).a;
	sum += texture(TEXTURE, UV + reach * vec2(0.0, 1.0)).a;
	sum += texture(TEXTURE, UV + reach * vec2(0.0, -1.0)).a;
	sum += texture(TEXTURE, UV + reach * vec2(0.7, 0.7)).a;
	sum += texture(TEXTURE, UV + reach * vec2(-0.7, 0.7)).a;
	sum += texture(TEXTURE, UV + reach * vec2(0.7, -0.7)).a;
	sum += texture(TEXTURE, UV + reach * vec2(-0.7, -0.7)).a;
	sum += texture(TEXTURE, UV + reach * vec2(0.4, 0.0)).a;
	sum += texture(TEXTURE, UV + reach * vec2(-0.4, 0.0)).a;
	sum += texture(TEXTURE, UV + reach * vec2(0.0, 0.4)).a;
	sum += texture(TEXTURE, UV + reach * vec2(0.0, -0.4)).a;
	COLOR = vec4(shade_colour, tint.a * sum / 14.0);
}
"""
static var _shadow_shader: Shader = null
## Off the ground: how big, how strong, and how much further down the screen.
const OFF_GROUND_SCALE := 0.7
const OFF_GROUND_STRENGTH := 0.6
const OFF_GROUND_DROP := 0.28


## A new place: nothing of the last one's light is left to read.
static func forget_the_light():
	light_points = []
	figures_lit = false
	stops_shadow = Callable()
	shade_map = null


static func set_shadows(lying: Dictionary):
	shadow_lean = lying.lean
	shadow_strength = lying.strength
	shadow_colour = lying.get("colour", Color.BLACK)
	shadow_soft = lying.get("soft", 1.0)
	shadow_version += 1


## Whether they are off the ground (a flier), for their shadow (Combat, as the light is seen).
var off_ground := false


class _Shadow extends Node2D:
	var picture: Texture2D = null
	var seen := -1
	var alpha_seen := 1.0
	var frame_seen: Variant = null

	var casting: _Casting = null

	func _ready():
		if ResourceLoader.exists(CombatantSprite.SHADOW_PICTURE):
			picture = load(CombatantSprite.SHADOW_PICTURE)
		casting = _Casting.new()
		add_child(casting)

	func _process(_delta):
		var figure: CombatantSprite = get_parent()
		var alpha: float = figure.hidden_alpha
		var frame: Variant = figure.frame_stamp()
		# With a light about, it turns as they move, and it walks as they do.
		if seen != CombatantSprite.shadow_version or alpha_seen != alpha or frame != frame_seen or not CombatantSprite.light_points.is_empty():
			seen = CombatantSprite.shadow_version
			alpha_seen = alpha
			frame_seen = frame
			queue_redraw()
			casting.queue_redraw()

	## What is throwing a shadow from them: {"way", "length", "strength", "colour"}, the strongest first.
	func _casts(feet: Vector2) -> Array:
		var found := []
		for point in CombatantSprite.light_points:
			var node = point.get("node")
			var from_it: Vector2 = global_position + feet - (node.global_position if node != null and is_instance_valid(node) else point.at)
			var gap: float = from_it.length()
			var closeness: float = 1.0 - gap / maxf(point.reach, 1.0)
			if closeness <= 0.0 or gap < 1.0:
				continue
			var lit: float = clampf(float(node.energy) / maxf(point.get("energy", 1.0), 0.01), 0.0, 1.5) if node != null and is_instance_valid(node) else 1.0
			found.append({"way": from_it / gap, "length": lerpf(CombatantSprite.SHADOW_CLOSE, CombatantSprite.SHADOW_FAR, 1.0 - closeness),
				"strength": clampf(0.2 + 0.5 * closeness, 0.0, 0.65) * lit, "colour": Color.BLACK})
		if found.is_empty():
			var strength: float = CombatantSprite.shadow_strength
			if strength <= 0.01:
				return []
			var lean: float = CombatantSprite.shadow_lean
			var way := Vector2(lean, CombatantSprite.SUN_SLANT).normalized()
			return [{"way": way, "length": minf(absf(lean) * 1.4 + 0.25, CombatantSprite.SUN_SHADOW_MOST), "strength": strength, "colour": CombatantSprite.shadow_colour, "soft": CombatantSprite.shadow_soft}]
		found.sort_custom(func(one, other): return one.strength > other.strength)
		return found.slice(0, CombatantSprite.MOST_SHADOWS)

	func feet_at() -> Vector2:
		var figure: CombatantSprite = get_parent()
		var feet := Vector2(0.0, float(Grid.TILE_SIZE) * 0.42)
		if figure.off_ground:
			feet.y += float(Grid.TILE_SIZE) * CombatantSprite.OFF_GROUND_DROP
		return feet

	func _draw():
		var figure: CombatantSprite = get_parent()
		# Where they stand, a dark patch: on the ground, and only then.
		if not figure.off_ground:
			_draw_patch(feet_at(), float(Grid.TILE_SIZE), 0.3 * alpha_seen)

	func _draw_patch(feet: Vector2, tile: float, alpha: float):
		if picture != null:
			var size := Vector2(tile * 0.5, tile * 0.16)
			draw_texture_rect(picture, Rect2(feet - size / 2.0, size), false, Color(0, 0, 0, alpha))
			return
		draw_set_transform(feet, 0.0, Vector2(1.0, 0.28))
		var across := tile * 0.3
		draw_texture_rect(LightView.light_picture(), Rect2(-across, -across, across * 2.0, across * 2.0), false, Color(0, 0, 0, minf(alpha * 1.6, 1.0)))
		draw_set_transform(Vector2.ZERO)

	## What is throwing a shadow from them: {"way", "length", "strength", "colour"}, the strongest first.
	func casts(feet: Vector2) -> Array:
		return _casts(feet)

	## How far along `way` a shadow of `length` goes before something stops it (the designer's wish: it ends at a wall).
	func as_far_as_a_wall(feet: Vector2, way: Vector2, length: float) -> float:
		var stops: Callable = CombatantSprite.stops_shadow
		if not stops.is_valid():
			return length
		var step := float(Grid.TILE_SIZE) * 0.5
		var went := step
		while went < length:
			if stops.call(global_position + feet + way * went):
				return went
			went += step
		return length


## Where a shadow `length` long and `width` across lies, from `feet` the way `way` points: the corners for the picture's
## bottom left, bottom right, top right and top left. Their right stays on the right: a shadow thrown down the screen (a
## light above them) is the picture upside down, not turned round, which would mirror it - walking right, it walked left
## (the designer, 2026-11-07).
static func cast_corners(feet: Vector2, way: Vector2, length: float, width: float) -> PackedVector2Array:
	var across := Vector2(-way.y, way.x * FLOOR_SLANT) * (-1.0 if way.y > 0.0 else 1.0)
	var half: Vector2 = across * width * 0.5
	var far_end: Vector2 = feet + way * length
	return PackedVector2Array([feet - half, feet + half, far_end + half, far_end - half])


## Their frame laid along the ground away from each light, through SHADOW_SHADER. A node of its own, for the material: the patch is drawn plain.
class _Casting extends Node2D:
	var _material: ShaderMaterial = null

	func _ready():
		if CombatantSprite._shadow_shader == null:
			CombatantSprite._shadow_shader = Shader.new()
			CombatantSprite._shadow_shader.code = CombatantSprite.SHADOW_SHADER
		_material = ShaderMaterial.new()
		_material.shader = CombatantSprite._shadow_shader
		material = _material

	func _draw():
		var shadow: _Shadow = get_parent()
		var figure: CombatantSprite = shadow.get_parent()
		if figure.lying:
			return
		var frame: Dictionary = figure.current_frame()
		if frame.is_empty():
			return
		var size_share: float = CombatantSprite.OFF_GROUND_SCALE if figure.off_ground else 1.0
		var strength_share: float = CombatantSprite.OFF_GROUND_STRENGTH if figure.off_ground else 1.0
		var feet: Vector2 = shadow.feet_at()
		for cast in shadow.casts(feet):
			_draw_cast(figure, shadow, frame, feet, cast, size_share, strength_share * shadow.alpha_seen)

	func _draw_cast(figure: CombatantSprite, shadow: _Shadow, frame: Dictionary, feet: Vector2, cast: Dictionary, size_share: float, strength_share: float):
		var texture: Texture2D = frame.texture
		var region: Rect2 = frame.region
		var drawn: Node2D = figure._drawn()
		var scale_of: Vector2 = drawn.scale if drawn != null else Vector2.ONE
		var height: float = region.size.y * absf(scale_of.y) * size_share
		var width: float = region.size.x * absf(scale_of.x) * size_share
		var way: Vector2 = cast.way
		# The floor is seen at a slant: a shadow coming down the screen looks shorter, one going across it flatter.
		var whole: float = height * cast.length * lerpf(1.0, CombatantSprite.FLOOR_SLANT, absf(way.y))
		var length: float = shadow.as_far_as_a_wall(feet, way, whole)
		if length <= 1.0:
			return
		var share: float = length / whole
		# The picture's own corners: an atlas's are its part of the whole.
		var source: Texture2D = texture
		var origin: Vector2 = region.position
		if texture is AtlasTexture:
			source = texture.atlas
			origin += texture.region.position
		if source == null:
			return
		var whole_size: Vector2 = source.get_size()
		var left: float = origin.x / whole_size.x
		var right: float = (origin.x + region.size.x) / whole_size.x
		var top: float = origin.y / whole_size.y
		var bottom: float = (origin.y + region.size.y) / whole_size.y
		if frame.get("flip", false):
			var swapped := left
			left = right
			right = swapped
		var far_v: float = lerpf(bottom, top, share)
		var uvs := PackedVector2Array([Vector2(left, bottom), Vector2(right, bottom), Vector2(right, far_v), Vector2(left, far_v)])
		var c: Color = cast.colour
		_material.set_shader_parameter("shade_colour", Vector3(c.r, c.g, c.b))
		var frame_uv := region.size / whole_size
		_material.set_shader_parameter("sharp", frame_uv * CombatantSprite.SHADOW_SHARP)
		_material.set_shader_parameter("soft", frame_uv * CombatantSprite.SHADOW_SOFT * float(cast.get("soft", 1.0)))
		var near_alpha: float = cast.strength * strength_share
		# Red says how far along it is: see SHADOW_SHADER.
		var near := Color(0.0, 0.0, 0.0, near_alpha)
		var far := Color(share, 0.0, 0.0, near_alpha * lerpf(1.0, 0.2, share))
		draw_polygon(CombatantSprite.cast_corners(feet, way, length, width),
			PackedColorArray([near, near, far, far]), uvs, source)


## Something that changes as they animate, for the shadow to see.
func frame_stamp() -> Variant:
	if _animated != null:
		return [_animated.animation, _animated.frame, _animated.flip_h]
	return null


## --- How light falls on them ---
##
## View only (the same section 10): one shader on the figure, its uniforms set here each frame from the lights near them. The colour of
## the nearest lights, mixed by how close, breathing as a flame does. The edge of the figure facing the light lit in its colour, and the far side
## darker. Lit from below by a fire on the floor, or from above by the sun. Back lit, with the light behind them from where
## we look: the front goes dark, and only the rim shows. And half in the dark: each pixel reads how dark it is where that pixel is, so
## somebody stepping out of a doorway is lit on one half. In the Dark, a faint rim, so a figure is still there to look at. Those who see
## in it have eyes that glow: a picture at EYES_PICTURE is drawn for the eyes.

const EYES_PICTURE := "res://art/fx/glowing_eyes.png"
const FIGURE_SHADER := """
shader_type canvas_item;
uniform vec4 rim : source_color = vec4(0.5, 0.62, 1.0, 0.8);
uniform float rim_on = 0.0;
uniform float figure_alpha = 1.0;
uniform vec3 lit_colour = vec3(1.0);
uniform float lit_strength = 0.0;
uniform vec2 light_way = vec2(0.0);
uniform float side_strength = 0.0;
uniform float far_dark = 0.0;
uniform float from_above = 0.0;
uniform float back_lit = 0.0;
uniform float feet_y = 128.0;
uniform float figure_height = 256.0;
uniform sampler2D shade_map : filter_linear, repeat_disable;
uniform vec4 shade_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float shade_on = 0.0;
uniform float shapes_on = 0.0;
uniform float light_height = 0.6;
uniform float wet = 0.0;
uniform sampler2D shine_mask : filter_linear, repeat_disable;
uniform float shine_on = 0.0;
uniform float snow_on = 0.0;
uniform float ash_on = 0.0;
uniform float dust = 0.0;
uniform float cold_on = 0.0;
uniform float heat_on = 0.0;
uniform vec2 wind_wave = vec2(0.0);
varying vec2 world;
varying float up;
varying vec4 vertex_colour;
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	up = clamp((feet_y - VERTEX.y) / max(figure_height, 1.0), 0.0, 1.0);
	vertex_colour = COLOR;
}
void fragment() {
	vec4 base = COLOR;
	float here = texture(TEXTURE, UV).a;
	vec2 pixel = TEXTURE_PIXEL_SIZE;
	// Loose cloth and hair moving in the wind: the shine mask's blue (docs/shine_masks.md).
	if (shine_on > 0.5 && length(wind_wave) > 0.01) {
		vec4 cloth = texture(shine_mask, UV);
		float loose = cloth.b * cloth.a;
		if (loose > 0.01) {
			vec2 sway = wind_wave * pixel * 4.0 * loose * (0.6 + 0.4 * sin(TIME * 7.0 + UV.y * 24.0 + UV.x * 9.0));
			base = texture(TEXTURE, UV - sway) * vertex_colour;
		}
	}
	vec3 rgb = base.rgb;
	rgb = mix(rgb, rgb * lit_colour * 1.5, lit_strength);
	// Where on the figure this is, as a smooth rounded body: across from the middle of the frame, and down from about the
	// chest. Nothing is read off the drawing's own edges, so a line or a gap inside it (a scarf, an arm against the body)
	// is never taken for an outline and drawn again shifted (the designer, 2026-11-07: parts looked smeared, with "part of
	// his outline inside of his scarf").
	float across = clamp((UV.x - 0.5) / 0.32, -1.0, 1.0);
	float down = clamp((UV.y - 0.55) / 0.42, -1.0, 1.0);
	vec3 n = normalize(vec3(across * 0.9, down * 0.45, 1.0));
	float towards = clamp(across * light_way.x + down * 0.5 * light_way.y, -1.0, 1.0);
	// The side towards the light lighter, the far side darker.
	rgb += rgb * lit_colour * max(towards, 0.0) * side_strength * 0.6;
	rgb *= 1.0 - max(-towards, 0.0) * far_dark;
	rgb *= 1.0 + from_above * (up - 0.5);
	// Lit from behind: darker, with a glow towards their sides.
	if (back_lit > 0.001) {
		rgb = mix(rgb, rgb * 0.5 + lit_colour * abs(across) * 0.3, back_lit);
	}
	// What shines (the shine mask: red how much, green how much like metal) and what is wet takes a highlight.
	float shine = 0.0;
	float metal = 0.0;
	if (shine_on > 0.5) {
		vec4 mask = texture(shine_mask, UV);
		shine = mask.r * mask.a;
		metal = mask.g * mask.a;
	}
	if (shapes_on > 0.5 || wet > 0.001 || shine > 0.001) {
		vec3 lum = vec3(0.299, 0.587, 0.114);
		vec3 l = normalize(vec3(light_way, light_height));
		// More of a body's roundness, the light falling across it.
		if (shapes_on > 0.5) {
			float directional = clamp(side_strength * 1.4 + lit_strength, 0.0, 1.0);
			rgb *= mix(1.0, 0.74 + 0.45 * clamp(dot(n, l), 0.0, 1.0), directional);
		}
		rgb = mix(rgb, rgb * 0.8, wet * 0.6);
		rgb = mix(vec3(dot(rgb, lum)), rgb, 1.0 + 0.18 * wet);
		float gloss = pow(max(dot(n, normalize(l + vec3(0.0, 0.0, 1.0))), 0.0), 28.0);
		float how_shiny = clamp(shine + wet * 0.55, 0.0, 1.5) * clamp(side_strength * 1.2 + lit_strength + 0.25, 0.0, 1.2);
		rgb += gloss * how_shiny * mix(lit_colour, rgb * lit_colour * 1.6, metal) * 0.9;
	}
	// Snow and ash on what faces up, dust from the feet, the cold's blue and the heat's glint (the weather on the creatures).
	if (snow_on > 0.01 || ash_on > 0.01) {
		float near_top = clamp(here - texture(TEXTURE, UV - vec2(0.0, pixel.y * 3.0)).a, 0.0, 1.0);
		float further = clamp(here - texture(TEXTURE, UV - vec2(0.0, pixel.y * 6.0)).a, 0.0, 1.0) * 0.6;
		float top = max(near_top, further) * here;
		rgb = mix(rgb, vec3(0.95, 0.97, 1.0), top * snow_on);
		rgb = mix(rgb, vec3(0.45, 0.43, 0.42), top * ash_on * 0.8);
	}
	if (dust > 0.01) {
		rgb = mix(rgb, rgb * vec3(1.05, 0.92, 0.72) + vec3(0.12, 0.08, 0.02), smoothstep(0.45, 1.0, UV.y) * dust * 0.7);
	}
	if (cold_on > 0.01) {
		rgb = mix(rgb, rgb * vec3(0.84, 0.92, 1.12), cold_on * 0.45);
	}
	if (heat_on > 0.01 && shine > 0.001) {
		rgb += vec3(1.0, 0.95, 0.85) * shine * heat_on * 0.35 * (0.5 + 0.5 * sin(TIME * 3.0 + UV.y * 30.0));
	}
	if (shade_on > 0.5) {
		float dark = texture(shade_map, (world - shade_rect.xy) / shade_rect.zw).a;
		rgb *= 1.0 - clamp(dark, 0.0, 1.0) * 0.55;
	}
	COLOR = vec4(rgb, base.a);
	if (rim_on > 0.5) {
		vec2 step_by = pixel * 4.0;
		float near = texture(TEXTURE, UV + vec2(step_by.x, 0.0)).a + texture(TEXTURE, UV - vec2(step_by.x, 0.0)).a
			+ texture(TEXTURE, UV + vec2(0.0, step_by.y)).a + texture(TEXTURE, UV - vec2(0.0, step_by.y)).a;
		float edge = clamp(near, 0.0, 1.0) * (1.0 - clamp(here * 4.0, 0.0, 1.0));
		COLOR = mix(COLOR, vec4(rim.rgb, rim.a * figure_alpha), edge);
	}
}
"""
## Everything that is on from when a place is lit at all (LightView, Combat, the map): off, the figures are as drawn.
static var figures_lit := false
## How dark each tile is, for half in the dark: the shade's own picture, and where it lies.
static var shade_map: Texture2D = null
static var shade_rect := Rect2()
const SIDE_MOST := 0.9
const FAR_DARK_MOST := 0.4
const FROM_BELOW_MOST := 0.5
const SUN_ABOVE := 0.25
const SUN_SIDE := 0.3
const BACK_LIT_MOST := 0.65
static var _figure_shader: Shader = null
var _figure_material: ShaderMaterial = null
var _in_the_dark := false
var _sees_in_it := false
var _eyes: Node2D = null


func set_in_the_dark(dark: bool, sees: bool = false):
	if dark == _in_the_dark and sees == _sees_in_it:
		return
	_in_the_dark = dark
	_sees_in_it = sees
	if not LightView.shown():
		return
	if dark and sees and _eyes == null:
		_eyes = _Eyes.new()
		add_child(_eyes)
	if _eyes != null:
		_eyes.visible = dark and sees


## Puts the light on them as it falls this frame.
## --- The weather on the creatures ---
##
## The designer, 2026-11-07 (section 18). View only, placeholders all of it. Out under the sky: snow settles on what faces up and ash
## too (`snow_on`, `ash_on`, over SETTLED_SECONDS, gone over MELT_SECONDS), sand dusts them from the feet up (`dust`), the cold tints
## them blue and the heat of the day glints on what shines (`cold_on`, `heat_on`); loose cloth and hair - the shine mask's blue - move
## in the wind (`wind_blows`). Drips fall from the wet, steam rises off the wet by a fire, breath shows in the cold; and a pose for
## it, which falls back on idle as every pose does (`weather_pose`: "shiver", "shield_eyes", "hunch" - slots to fill in their
## SpriteFrames). LightView._put_on_the_sky says what the sky is doing.
static var snowing := 0.0
static var ashing := 0.0
static var sanding := 0.0
static var cold_air := 0.0
static var hot_air := 0.0
static var hard_rain := false
static var wind_blows := Vector2.ZERO
const SETTLED_SECONDS := 40.0
const MELT_SECONDS := 60.0
const DUSTED_SECONDS := 30.0
const BREATH_EVERY := [2.4, 3.6]
var snow_on := 0.0
var ash_on := 0.0
var dust := 0.0
var cold_on := 0.0
var heat_on := 0.0
## The pose the weather wants them in, below any a condition wants.
var weather_pose: StringName = &""
var _open_sky := false
var _drips: CPUParticles2D = null
var _steam: CPUParticles2D = null
var _breath: CPUParticles2D = null
var _next_breath := 0.0


func _weather_on_me(delta: float):
	_open_sky = not laid and under_the_sky.is_valid() and under_the_sky.call(global_position)
	snow_on = move_toward(snow_on, 1.0 if _open_sky and snowing > 0.2 else 0.0, delta / (SETTLED_SECONDS if _open_sky and snowing > 0.2 else MELT_SECONDS))
	ash_on = move_toward(ash_on, 1.0 if _open_sky and ashing > 0.2 else 0.0, delta / (SETTLED_SECONDS if _open_sky and ashing > 0.2 else MELT_SECONDS))
	dust = move_toward(dust, 1.0 if _open_sky and sanding > 0.3 else 0.0, delta / (DUSTED_SECONDS if _open_sky and sanding > 0.3 else MELT_SECONDS))
	cold_on = move_toward(cold_on, cold_air if _open_sky else 0.0, delta / 20.0)
	heat_on = move_toward(heat_on, clampf(hot_air, 0.0, 1.0) if _open_sky else 0.0, delta / 10.0)
	var wanted: StringName = &""
	if _open_sky:
		if cold_air > 0.5:
			wanted = &"shiver"
		elif sanding > 0.5:
			wanted = &"shield_eyes"
		elif hard_rain:
			wanted = &"hunch"
	set_weather_pose(wanted)
	if not LightView.shown():
		return
	_keep_drips(wetness > 0.45 and not laid)
	_keep_steam(wetness > 0.2 and not laid and _by_a_fire())
	_breathe(delta, _open_sky and cold_air > 0.5)


## The pose the weather wants, falling back on idle where they have no such animation.
func set_weather_pose(wanted: StringName):
	if wanted == weather_pose:
		return
	var was: StringName = weather_pose
	weather_pose = wanted
	if _animated != null and (_animated.animation == &"idle" or _animated.animation == was):
		play_idle()


## Whether a fire is near enough to steam them dry: a warm light within a tile and a half.
func _by_a_fire() -> bool:
	for point in light_points:
		var colour: Color = point.get("colour", Color.WHITE)
		if colour.r > colour.b + 0.25 and global_position.distance_to(point.get("at", Vector2.INF)) <= Grid.tiles(1.5):
			return true
	return false


func _particles(called: String, colour: Color) -> CPUParticles2D:
	var made := CPUParticles2D.new()
	made.name = called
	made.z_index = 1
	made.color = colour
	made.emitting = false
	made.local_coords = false
	add_child(made)
	return made


func _keep_drips(on: bool):
	if not on and _drips == null:
		return
	if _drips == null:
		_drips = _particles("Drips", Color(0.75, 0.84, 0.98, 0.65))
		_drips.amount = 6
		_drips.lifetime = 0.55
		_drips.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		_drips.emission_rect_extents = Vector2(Grid.tiles(0.18), Grid.tiles(0.25))
		_drips.position = Vector2(0, -Grid.tiles(0.35))
		_drips.direction = Vector2.DOWN
		_drips.spread = 5.0
		_drips.gravity = Vector2(0, Grid.tiles(5.0))
		_drips.initial_velocity_min = 0.0
		_drips.initial_velocity_max = Grid.tiles(0.2)
		_drips.scale_amount_min = 2.0
		_drips.scale_amount_max = 3.0
	_drips.emitting = on


func _keep_steam(on: bool):
	if not on and _steam == null:
		return
	if _steam == null:
		_steam = _particles("Steam", Color(0.95, 0.95, 0.95, 0.35))
		_steam.amount = 10
		_steam.lifetime = 1.6
		_steam.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		_steam.emission_rect_extents = Vector2(Grid.tiles(0.2), Grid.tiles(0.3))
		_steam.position = Vector2(0, -Grid.tiles(0.5))
		_steam.direction = Vector2.UP
		_steam.spread = 25.0
		_steam.gravity = Vector2(0, -Grid.tiles(0.3))
		_steam.initial_velocity_min = Grid.tiles(0.2)
		_steam.initial_velocity_max = Grid.tiles(0.45)
		_steam.scale_amount_min = 6.0
		_steam.scale_amount_max = 12.0
		var fading := Gradient.new()
		fading.set_color(0, Color(1, 1, 1, 0.5))
		fading.set_color(1, Color(1, 1, 1, 0.0))
		_steam.color_ramp = fading
	_steam.emitting = on


func _breathe(delta: float, cold: bool):
	if not cold:
		return
	_next_breath -= delta
	if _next_breath > 0.0:
		return
	_next_breath = randf_range(BREATH_EVERY[0], BREATH_EVERY[1])
	if _breath == null:
		_breath = _particles("Breath", Color(0.95, 0.97, 1.0, 0.4))
		_breath.one_shot = true
		_breath.amount = 5
		_breath.lifetime = 1.1
		_breath.explosiveness = 0.85
		_breath.direction = Vector2.RIGHT
		_breath.spread = 20.0
		_breath.gravity = Vector2(0, -Grid.tiles(0.15))
		_breath.initial_velocity_min = Grid.tiles(0.15)
		_breath.initial_velocity_max = Grid.tiles(0.3)
		_breath.scale_amount_min = 5.0
		_breath.scale_amount_max = 9.0
		var fading := Gradient.new()
		fading.set_color(0, Color(1, 1, 1, 0.45))
		fading.set_color(1, Color(1, 1, 1, 0.0))
		_breath.color_ramp = fading
	var facing: float = -1.0 if (_animated != null and _animated.flip_h) or (_static != null and _static.flip_h) else 1.0
	_breath.position = Vector2(facing * Grid.tiles(0.08), -maxf(head_height(), Grid.tiles(0.6)))
	_breath.direction = Vector2(facing, -0.2)
	_breath.restart()


## Wetter under the rain, drier out of it: over LightView.SOAKED_SECONDS and DRY_SECONDS.
func _soak(delta: float):
	var wanted := 0.0
	if soaking > 0.01 and not laid and under_the_sky.is_valid() and under_the_sky.call(global_position):
		wanted = clampf(soaking, 0.0, 1.0)
	if wetness < wanted:
		wetness = minf(wetness + delta / LightView.SOAKED_SECONDS, wanted)
	elif wetness > wanted:
		wetness = maxf(wetness - delta / LightView.DRY_SECONDS, wanted)


## The shine mask drawn for `texture`, a frame of theirs, or null: the same file with "_shine" for "_color" in its name
## (alithia_idle_color0003.png and alithia_idle_shine0003.png), or "_shine" before its ending. Red: how shiny. Green: how
## like metal, its highlight in its own colour rather than the light's. Black, or no file: matte.
static func shine_mask_for(texture: Texture2D) -> Texture2D:
	if texture == null or texture.resource_path == "":
		return null
	var path: String = texture.resource_path
	if _shine_masks.has(path):
		return _shine_masks[path]
	var mask_path := shine_path_for(path)
	var mask: Texture2D = load(mask_path) if ResourceLoader.exists(mask_path) else null
	_shine_masks[path] = mask
	return mask


## Where the shine mask for the frame at `path` would be.
static func shine_path_for(path: String) -> String:
	var file := path.get_file()
	var at := file.rfind("_color")
	var mask_file := (file.substr(0, at) + "_shine" + file.substr(at + 6)) if at >= 0 else (file.get_basename() + "_shine." + file.get_extension())
	return path.get_base_dir().path_join(mask_file)


func _fall_of_light():
	var drawn := _drawn()
	if drawn == null:
		return
	if _figure_material == null:
		if _figure_shader == null:
			_figure_shader = Shader.new()
			_figure_shader.code = FIGURE_SHADER
		_figure_material = ShaderMaterial.new()
		_figure_material.shader = _figure_shader
	if drawn.material != _figure_material:
		drawn.material = _figure_material
		# Half in the dark does what the tint did, pixel by pixel.
		set_hidden_alpha(hidden_alpha)
	var mixed := Color(0, 0, 0)
	var weight := 0.0
	var way := Vector2.ZERO
	var here: Vector2 = global_position
	for point in light_points:
		var node = point.get("node")
		var lit_at: Vector2 = node.global_position if node != null and is_instance_valid(node) else point.at
		var towards: Vector2 = lit_at - here
		var closeness: float = 1.0 - towards.length() / maxf(point.reach, 1.0)
		if closeness <= 0.0:
			continue
		# Breathing as it does: how bright it is this moment, for what it is at its steadiest.
		var breath: float = float(node.energy) / maxf(point.get("energy", 1.0), 0.01) if node != null and is_instance_valid(node) else 1.0
		var strength: float = closeness * closeness * clampf(breath, 0.0, 1.5)
		mixed += Color(point.colour.r, point.colour.g, point.colour.b) * strength
		weight += strength
		if towards.length() > 1.0:
			way += towards.normalized() * strength
	var material := _figure_material
	var colour := Color.WHITE
	var strength: float = clampf(weight, 0.0, 1.0)
	var side := 0.0
	var above := 0.0
	var behind := 0.0
	var lit_from := Vector2.ZERO
	if weight > 0.001:
		colour = Color(mixed.r / weight, mixed.g / weight, mixed.b / weight)
		lit_from = way.normalized() if way.length() > 0.001 else Vector2.ZERO
		side = strength * SIDE_MOST
		# A fire on the floor lights the feet more than the head.
		above = -strength * FROM_BELOW_MOST
		# The light behind them, from where we look.
		behind = clampf(-lit_from.y, 0.0, 1.0) * strength * BACK_LIT_MOST
	else:
		# The sun: from the other side from where their shadows lean, and from above.
		var sun: float = clampf(shadow_strength / 0.35, 0.0, 1.0)
		lit_from = Vector2(-signf(shadow_lean), -0.5).normalized() if absf(shadow_lean) > 0.01 else Vector2(0.0, -1.0)
		side = sun * SUN_SIDE * absf(shadow_lean)
		above = sun * SUN_ABOVE * (1.0 if absf(shadow_lean) > 0.01 else 0.0)
		strength = 0.0
	# A flipped frame reads its picture the other way.
	var flipped: bool = _animated.flip_h if _animated != null else (_static != null and _static.flip_h)
	var in_picture := Vector2(-lit_from.x if flipped else lit_from.x, lit_from.y)
	material.set_shader_parameter("lit_colour", Vector3(colour.r, colour.g, colour.b))
	material.set_shader_parameter("lit_strength", strength * 0.5)
	material.set_shader_parameter("light_way", in_picture)
	material.set_shader_parameter("side_strength", side)
	material.set_shader_parameter("far_dark", side * (FAR_DARK_MOST / SIDE_MOST))
	material.set_shader_parameter("from_above", above)
	material.set_shader_parameter("back_lit", behind)
	material.set_shader_parameter("rim_on", 1.0 if _in_the_dark else 0.0)
	material.set_shader_parameter("figure_alpha", hidden_alpha)
	# A shape from the picture; how high the light is: a lamp or a fire low, the sun high.
	material.set_shader_parameter("shapes_on", 1.0 if GameSettings.figure_shapes() else 0.0)
	material.set_shader_parameter("light_height", 0.45 if weight > 0.001 else 0.9)
	material.set_shader_parameter("wet", wetness)
	material.set_shader_parameter("snow_on", snow_on)
	material.set_shader_parameter("ash_on", ash_on)
	material.set_shader_parameter("dust", dust)
	material.set_shader_parameter("cold_on", cold_on)
	material.set_shader_parameter("heat_on", heat_on)
	material.set_shader_parameter("wind_wave", wind_blows if _open_sky else Vector2.ZERO)
	var frame := current_frame()
	var mask: Texture2D = shine_mask_for(frame.get("texture")) if not frame.is_empty() else null
	material.set_shader_parameter("shine_on", 1.0 if mask != null else 0.0)
	if mask != null:
		material.set_shader_parameter("shine_mask", mask)
	var height: float = _frame_height if _frame_height > 0.0 else float(Grid.TILE_SIZE)
	if _animated != null:
		material.set_shader_parameter("feet_y", _animated.offset.y + height * 0.5)
	else:
		material.set_shader_parameter("feet_y", height * 0.5)
	material.set_shader_parameter("figure_height", height)
	material.set_shader_parameter("shade_on", 1.0 if shade_map != null else 0.0)
	if shade_map != null:
		material.set_shader_parameter("shade_map", shade_map)
		material.set_shader_parameter("shade_rect", Vector4(shade_rect.position.x, shade_rect.position.y, shade_rect.size.x, shade_rect.size.y))


func _process(delta):
	_soak(delta)
	_weather_on_me(delta)
	if figures_lit and not laid:
		_fall_of_light()
	elif _figure_material != null and _drawn() != null and _drawn().material == _figure_material:
		_drawn().material = null
		set_hidden_alpha(hidden_alpha)


class _Eyes extends Node2D:
	var picture: Texture2D = null

	func _ready():
		z_index = 1
		light_mask = 0
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = add
		if ResourceLoader.exists(CombatantSprite.EYES_PICTURE):
			picture = load(CombatantSprite.EYES_PICTURE)

	func _process(_delta):
		var parent := get_parent() as CombatantSprite
		position = Vector2(0.0, -parent.head_height() - float(Grid.TILE_SIZE) * 0.18)
		modulate.a = parent.hidden_alpha

	func _draw():
		var tile := float(Grid.TILE_SIZE)
		if picture != null:
			draw_texture(picture, -picture.get_size() / 2.0)
			return
		for side in [-1.0, 1.0]:
			var at := Vector2(side * tile * 0.05, 0.0)
			draw_circle(at, tile * 0.028, Color(1.0, 0.85, 0.35, 0.5))
			draw_circle(at, tile * 0.012, Color(1.0, 0.95, 0.7, 1.0))


## How the light where they stand colours them (Light.FIGURE_TINTS).
var lit_by := Color.WHITE


func set_light(colour: Color):
	if colour != lit_by:
		lit_by = colour
		set_hidden_alpha(hidden_alpha)


## Tints them `colour` - white for as drawn.
func set_tint(colour: Color):
	tint = colour
	set_hidden_alpha(hidden_alpha)


## A still sprite shown as `texture` instead - something on the map that has
## turned into something else. An animated one keeps its frames (show_as).
func set_still(texture: Texture2D):
	if _static != null and texture != null:
		_static.texture = texture


## The height of this sprite's frames, measured once when it was set up. Zero
## for a static sprite, which has no frames to measure.
var _frame_height := 0.0


func setup(combatant_sprite_frames: SpriteFrames, map_sprite: Texture2D, facing_flip: bool):
	# Under everything else of theirs.
	if LightView.shown():
		add_child(_Shadow.new())
	else:
		set_process(false)
	if combatant_sprite_frames != null:
		_animated = AnimatedSprite2D.new()
		_animated.sprite_frames = combatant_sprite_frames
		_animated.flip_h = facing_flip
		add_child(_animated)
		_align_feet_to_tile()
		play_idle()
	else:
		_static = Sprite2D.new()
		_static.texture = map_sprite
		_static.hframes = 2
		_static.flip_h = facing_flip
		add_child(_static)
	set_hidden_alpha(hidden_alpha)


## Whoever this sprite was set up as, kept while it is showing somebody else.
var _own_frames: SpriteFrames = null


## Shows this sprite as somebody else - Cyrus in a Priest's robes on a stealth
## map - or, given null, as whoever it was set up as again. Only an animated
## sprite changes clothes; a still keeps its picture.
func show_as(frames: SpriteFrames):
	if _animated == null:
		return
	if _own_frames == null:
		_own_frames = _animated.sprite_frames
	var wanted: SpriteFrames = frames if frames != null else _own_frames
	if wanted == null or _animated.sprite_frames == wanted:
		return
	var playing = _animated.animation
	_animated.sprite_frames = wanted
	_align_feet_to_tile()
	if wanted.has_animation(playing):
		_animated.play(playing)
	else:
		play_idle()


## The animation set on show right now, or null for a still.
func showing() -> SpriteFrames:
	return _animated.sprite_frames if _animated != null else null


## What is on show this moment, for drawing a copy of it somewhere else - the
## ghost a stealth map leaves where a guard last saw him: {texture, region,
## offset, flip}, the region being the part of the texture that is the frame
## and the offset where its centre is drawn from this sprite's position.
## Empty when there is nothing to copy.
func current_frame() -> Dictionary:
	if _animated != null and _animated.sprite_frames != null and _animated.sprite_frames.has_animation(_animated.animation):
		var texture = _animated.sprite_frames.get_frame_texture(_animated.animation, _animated.frame)
		if texture != null:
			return {"texture": texture, "region": Rect2(Vector2.ZERO, texture.get_size()),
				"offset": _animated.offset, "flip": _animated.flip_h}
	if _static != null and _static.texture != null:
		var size = _static.texture.get_size()
		return {"texture": _static.texture, "region": Rect2(0, 0, size.x / 2.0, size.y), "offset": Vector2.ZERO,
			"flip": _static.flip_h}
	return {}


## Shifts the sprite's drawn position upward via `offset` - which only
## affects rendering, unlike `position`, which movement/knockback/etc. all
## depend on being the exact tile centre - by however much its frame height
## exceeds one tile, so the extra height grows upward from the tile's floor
## instead of the sprite centring on the tile. A tile-sized frame gets an
## offset of 0, matching every existing static sprite exactly.
func _align_feet_to_tile():
	_frame_height = _get_reference_frame_height()
	_fit_feet()
	if not _animated.animation_changed.is_connected(_fit_feet):
		_animated.animation_changed.connect(_fit_feet)


## Stands whatever is playing on the tile's floor, by its own frame height.
func _fit_feet():
	if laid:
		return
	# On their side (set_lying), drawn about their middle: on their own tile.
	if lying and not _animated.sprite_frames.has_animation(LYING_ANIMATION):
		_animated.offset.y = 0.0
		return
	var height = _height_of(_animated.animation)
	if height <= 0.0:
		height = _frame_height
	if height > 0.0:
		_animated.offset.y = Grid.HALF_TILE.y - height / 2.0


## The height of `animation_name`'s first frame, or 0 when it has none.
func _height_of(animation_name: StringName) -> float:
	var frames = _animated.sprite_frames
	if frames == null or not frames.has_animation(animation_name) or frames.get_frame_count(animation_name) == 0:
		return 0.0
	var texture = frames.get_frame_texture(animation_name, 0)
	return texture.get_height() if texture != null else 0.0


## How far above the tile centre this sprite reaches, for anything that should
## appear over their head rather than through their middle.
##
## Zero for a sprite no taller than its tile, which is where a floating number
## has always gone - so nothing moves until somebody is actually drawn taller.
func head_height() -> float:
	return maxf(_frame_height - Grid.TILE_SIZE, 0.0)


## The height of this sprite's first "idle" frame (falling back to whichever
## named animation exists first, in case idle wasn't set), used as the
## reference size for _align_feet_to_tile. 0 if there's no usable frame.
func _get_reference_frame_height() -> float:
	for anim_name in ["idle", "walk", "skill", "dead"]:
		var height = _height_of(anim_name)
		if height > 0.0:
			return height
	return 0.0


func play_idle():
	if lying and _animated and _animated.sprite_frames.has_animation(LYING_ANIMATION):
		_animated.play(LYING_ANIMATION)
	elif pose != &"" and _animated and _animated.sprite_frames.has_animation(pose):
		_animated.play(pose)
	elif weather_pose != &"" and _animated and _animated.sprite_frames.has_animation(weather_pose):
		_animated.play(weather_pose)
	elif _animated and _animated.sprite_frames.has_animation("idle"):
		_animated.play("idle")


## --- Lying down (Combat "Prone") ---
##
## A placeholder until there is art: whoever lies down is drawn on their side. An
## animation called "prone" in their SpriteFrames takes its place, when they have one.

const LYING_ANIMATION := &"prone"
const LYING_SECONDS := 0.18

var lying := false
var _lying_tween: Tween = null


func set_lying(on: bool):
	if lying == on:
		return
	lying = on
	if _animated and _animated.sprite_frames.has_animation(LYING_ANIMATION):
		play_idle()
		return
	var drawn := _drawn()
	if drawn == null:
		return
	if _lying_tween != null and _lying_tween.is_valid():
		_lying_tween.kill()
	_lying_tween = create_tween().set_parallel(true)
	_lying_tween.tween_property(drawn, "rotation", _lying_angle() if on else 0.0, LYING_SECONDS).set_ease(Tween.EASE_OUT)
	if _animated != null:
		var from: float = _animated.offset.y
		_fit_feet()
		var to: float = _animated.offset.y
		_animated.offset.y = from
		_lying_tween.tween_property(_animated, "offset:y", to, LYING_SECONDS).set_ease(Tween.EASE_OUT)


## On their side, their head the way they face.
func _lying_angle() -> float:
	var flipped: bool = _animated.flip_h if _animated != null else (_static != null and _static.flip_h)
	return -PI / 2.0 if flipped else PI / 2.0


func play_walk():
	if _animated and _animated.sprite_frames.has_animation("walk"):
		_animated.play("walk")


## Plays the "skill" animation once (if this combatant has one) and waits
## for it to finish before returning, then leaves it on idle - the caller is
## expected to await this, so the skill's actual effect only resolves once
## the animation has genuinely finished playing. For a combatant with no
## skill animation (or no animations at all), this returns immediately.
## Capped at SKILL_ANIMATION_TIMEOUT: animation_finished never fires for a
## looping animation, so without this, a "skill" animation accidentally left
## looping would freeze the whole game forever, waiting on a signal that
## can never come - this guarantees play resumes regardless, at the cost of
## the animation being cut short if it really does take that long.
const SKILL_ANIMATION_TIMEOUT = 5.0

## Set true by _on_skill_animation_finished() when the "skill" animation
## genuinely ends. A member variable rather than a local flipped by a captured
## lambda for the same reason CController._step_arrival_finished is one:
## GDScript lambdas capture locals BY VALUE, so writing to a captured local
## inside one only updates the lambda's own copy and is invisible to the
## enclosing function - which would leave the wait below always running its
## full timeout instead of ending when the animation actually did.
var _skill_animation_finished := false

func play_skill_and_wait(animation_name: String = "skill"):
	if _animated == null:
		return
	if not _animated.sprite_frames.has_animation(animation_name):
		# A skill can name its own animation ("attack", say); fall back to the
		# general one for a combatant who hasn't got that specific set.
		if animation_name == "skill" or not _animated.sprite_frames.has_animation("skill"):
			return
		animation_name = "skill"
	_skill_animation_finished = false
	# Only once, even if this is asked for again while the last one is still
	# playing - a reaction can fire in the middle of somebody's own animation,
	# and connecting a second time is an error Godot reports every time it
	# happens. The one connection serves whichever call is currently waiting.
	if not _animated.animation_finished.is_connected(_on_skill_animation_finished):
		_animated.animation_finished.connect(_on_skill_animation_finished, CONNECT_ONE_SHOT)
	_animated.play(animation_name)
	var elapsed = 0.0
	while not _skill_animation_finished and elapsed < SKILL_ANIMATION_TIMEOUT:
		# Out of the tree - the battle was left, or ended into the next scene,
		# while this was still playing - there is no next frame to wait on, and
		# reaching for get_tree() here was an error in the editor every time.
		if not is_inside_tree():
			return
		await get_tree().process_frame
		if not is_inside_tree():
			return
		elapsed += get_process_delta_time()
	if not _skill_animation_finished:
		if _animated.animation_finished.is_connected(_on_skill_animation_finished):
			_animated.animation_finished.disconnect(_on_skill_animation_finished)
		push_warning("%s's skill animation didn't finish within %s seconds (check it isn't set to loop) - continuing anyway." % [name, SKILL_ANIMATION_TIMEOUT])
	play_idle()


func _on_skill_animation_finished():
	_skill_animation_finished = true


## --- Being hit ---


## How long a hit flash lasts. Short enough to read as an impact rather than a
## state change - long enough to catch across a busy board.
const FLASH_SECONDS = 0.18

## How long the damage type's own colour shows before the flash settles into
## the side colour. Brief on purpose: the type is a detail, whose skill it was
## is the thing that has to register.
const TYPE_FLASH_SECONDS = 0.07

const FLASH_HOSTILE = Color(1.0, 0.35, 0.35)
const FLASH_FRIENDLY = Color(0.4, 1.0, 0.5)

## How far a struck combatant is knocked back before springing home, and how
## long the whole recoil takes. Purely cosmetic - it moves the drawn sprite
## inside its tile and never the tile the combatant is actually on.
const RECOIL_DISTANCE = Grid.TILE_SIZE * 0.16
const RECOIL_SECONDS = 0.22
## How much a single blow squashes the drawing along the way it came, and how
## much further it nudges it (MoveFeel - PROPOSAL values).
const SQUASH := 0.14
const NUDGE := 1.35

var _flash_tween: Tween = null
var _recoil_tween: Tween = null


## The node that actually draws this combatant - an AnimatedSprite2D or a plain
## Sprite2D depending on whether it has SpriteFrames. Recoil moves this rather
## than the CombatantSprite itself, because the outer node's position is the
## tile it occupies and movement, knockback and line of sight all read it.
func _drawn() -> Node2D:
	return _animated if _animated != null else _static


## --- A piece of a wall ---
##
## A piece of a wall called up along a line (the designer, 2026-11-07: "on diagonal placement, make the wall look
## diagonal too"). It does not stand up on its tile as a figure does: its picture lies along `way`, one of the eight
## steps, end to end with the next piece, corner to corner on a diagonal. A `filler` is there only to close a
## diagonal's corner (Combat.wall_line): it blocks like the rest and draws nothing, the wall running past it.
## Whatever picture the wall is given is drawn this way, so a slot filled later needs no more than that.
func lay_along(way: Vector2i, filler: bool = false):
	var drawn := _drawn()
	if drawn == null or way == Vector2i.ZERO:
		return
	for child in get_children():
		if child is _Shadow:
			child.visible = false
	if filler:
		drawn.visible = false
		return
	laid = true
	var frame_height: float = _static.texture.get_height() if _static != null and _static.texture != null else _frame_height
	if frame_height <= 0.0:
		frame_height = Grid.TILE_SIZE
	drawn.rotation = Vector2(way).angle() - PI / 2.0
	_rest_scale = Vector2(1.0, Grid.TILE_SIZE * Vector2(way).length() / frame_height)
	drawn.scale = _rest_scale
	if _animated != null:
		_animated.offset = Vector2.ZERO


## Whether this is a piece of a wall, lying along it (lay_along).
var laid := false
## The picture's size when nothing is happening to it: other than 1 for a piece of a wall.
var _rest_scale := Vector2.ONE


## Flashes this combatant to show something landed on them: red from the other
## side, green from their own. Colour rather than a wince animation because it
## works for every combatant, animated or static, without any art existing for
## it - and it reads at any zoom, which a 4-frame recoil would not.
##
## `damage_colour` briefly tints them the damage type's own colour first, so a
## hit says what it was as well as who sent it. Left null for anything that
## isn't damage - a heal, a buff, a shove.
##
## Tints the whole node rather than the sprite child so it works the same for
## an AnimatedSprite2D and a plain Sprite2D.
func flash_hit(hostile: bool, damage_colour = null):
	if _flash_tween != null and _flash_tween.is_valid():
		# A combatant caught by two effects of one skill flashes once, brightly,
		# rather than the second restarting a half-faded first.
		_flash_tween.kill()
	var settled = FLASH_HOSTILE if hostile else FLASH_FRIENDLY
	_flash_tween = create_tween()
	if damage_colour != null:
		modulate = damage_colour
		_flash_tween.tween_property(self, "modulate", settled, TYPE_FLASH_SECONDS)
	else:
		modulate = settled
	_flash_tween.tween_property(self, "modulate", Color.WHITE, FLASH_SECONDS)


## Knocks the drawn sprite back along `direction` and springs it home. Sells
## the hit as something that arrived from somewhere, which a flash alone does
## not - an area skill going off shoves everyone caught outward from its
## centre, and you can see where it landed from that alone.
##
## `single`: one blow at them alone, which nudges them further along the way it
## came and squashes them against it as it lands (MoveFeel).
func recoil(direction: Vector2, single: bool = false):
	var drawn = _drawn()
	if drawn == null or direction == Vector2.ZERO:
		return
	if _hop_tween != null and _hop_tween.is_valid():
		end_hop()
	if _recoil_tween != null and _recoil_tween.is_valid():
		_recoil_tween.kill()
		drawn.position = size_offset
	var away = direction.normalized() * RECOIL_DISTANCE * (NUDGE if single else 1.0)
	if single:
		squash(direction)
	_recoil_tween = create_tween()
	_recoil_tween.tween_property(drawn, "position", size_offset + away, RECOIL_SECONDS * 0.3).set_ease(Tween.EASE_OUT)
	# Springs back rather than easing, so it reads as a body absorbing a blow
	# instead of sliding.
	_recoil_tween.tween_property(drawn, "position", size_offset, RECOIL_SECONDS * 0.7).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## How far a corpse sinks, and how much of it is left showing.
const DEATH_SINK = Grid.TILE_SIZE * 0.12
const DEATH_ALPHA = 0.35
const DEATH_SECONDS = 0.45


## Puts a combatant down: whatever "dead" art they have, then a sink and a fade
## to a fraction of full opacity.
##
## Faded rather than removed, because a body still says something about the
## fight - where the line broke, which flank went badly - and a combatant
## vanishing between one frame and the next reads as a glitch rather than a
## death. Kept partly visible rather than gone, and clearly dimmer than anyone
## still standing, so the board is never ambiguous about who can still act.
## Turns this combatant around. Exploration flips the whole line to face the
## way it is walking; combat sets it once when the sprite is built.
func set_facing(flip: bool):
	if _animated != null:
		_animated.flip_h = flip
	elif _static != null:
		_static.flip_h = flip
	if lying and _drawn() != null and not (_animated != null and _animated.sprite_frames.has_animation(LYING_ANIMATION)):
		_drawn().rotation = _lying_angle()


## Stands somebody back up after set_dead - a guard on a stealth map, woken by
## whoever found him lying there.
func set_alive():
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	set_lying(false)
	if _static != null:
		_static.frame = 0
	play_idle()
	var drawn = _drawn()
	var rise = create_tween()
	rise.set_parallel(true)
	rise.tween_property(self, "modulate", Color.WHITE, DEATH_SECONDS)
	if drawn != null:
		rise.tween_property(drawn, "position", size_offset, DEATH_SECONDS).set_ease(Tween.EASE_OUT)
		rise.tween_property(drawn, "rotation", 0.0, DEATH_SECONDS)


func set_dead():
	if _animated:
		if _animated.sprite_frames.has_animation("dead"):
			_animated.play("dead")
		else:
			_animated.stop()
	else:
		_static.frame = 1
	# Any recoil still springing back would fight the sink for the same
	# property, and the corpse would end up wherever the two happened to stop.
	if _recoil_tween != null and _recoil_tween.is_valid():
		_recoil_tween.kill()
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	if _hop_tween != null and _hop_tween.is_valid():
		end_hop()
	if _shape_tween != null and _shape_tween.is_valid():
		_shape_tween.kill()
	var drawn = _drawn()
	if drawn != null:
		drawn.scale = _rest_scale
	var fade = create_tween()
	fade.set_parallel(true)
	fade.tween_property(self, "modulate", Color(0.6, 0.6, 0.6, DEATH_ALPHA), DEATH_SECONDS)
	if drawn != null:
		fade.tween_property(drawn, "position:y", drawn.position.y + DEATH_SINK, DEATH_SECONDS).set_ease(Tween.EASE_OUT)


## Falls, seen (MoveFeel.falls): knocked back along `away`, then collapsing, ending as
## set_dead does. `element` tints them - ash for fire - and a "dead_<element>" animation,
## if they have one, plays in place of the rest.
func fall(away: Vector2, element: int):
	var drawn = _drawn()
	var own: StringName = StringName("dead_%s" % Damage.type_name(element).to_lower()) if element >= 0 else &""
	if drawn == null or (_animated != null and own != &"" and _animated.sprite_frames.has_animation(own)):
		set_dead()
		if drawn != null and _animated != null and own != &"" and _animated.sprite_frames.has_animation(own):
			_animated.play(own)
		return
	set_dead()
	var home: Vector2 = drawn.position
	var tile := float(Grid.TILE_SIZE)
	var flung := create_tween().set_ignore_time_scale(true)
	flung.tween_property(drawn, "position", home + away * tile * FALL_THROWN - Vector2(0.0, tile * 0.08), FALL_THROWN_SECONDS).set_ease(Tween.EASE_OUT)
	flung.tween_property(drawn, "position", home + away * tile * FALL_THROWN, FALL_THROWN_SECONDS * 0.6).set_ease(Tween.EASE_IN)
	var side := 1.0 if away.x >= 0.0 else -1.0
	flung.tween_property(drawn, "rotation", deg_to_rad(FALL_ANGLE) * side, FALL_COLLAPSE_SECONDS).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	match element:
		Damage.Type.FIRE, Damage.Type.PLASMA:
			var ash := create_tween().set_ignore_time_scale(true)
			ash.tween_property(self, "modulate", Color(0.22, 0.21, 0.2, DEATH_ALPHA), DEATH_SECONDS)
		Damage.Type.ICE, Damage.Type.METAL:
			var gone := create_tween().set_ignore_time_scale(true)
			gone.tween_property(self, "modulate:a", 0.12, DEATH_SECONDS * 0.6)


## How far a fall throws them, as a share of a tile, and over how long; how far they
## tip over as they go down, and how long that takes. PROPOSAL.
const FALL_THROWN := 0.38
const FALL_THROWN_SECONDS := 0.15
const FALL_ANGLE := 82.0
const FALL_COLLAPSE_SECONDS := 0.32


## --- Hops ---
##
## Up onto high ground or down off it, up a floor or down one, a walker hops
## (CController._begin_step): the drawing leaves the node in an arc and comes
## back to it. Only what is drawn moves, as with a recoil. Onto high ground the
## arc peaks late, a jump up landing on something; off it, early, a jump down. A
## floor is gone between at once (the walk snaps), so there the drawing rises
## into place from below, or drops into it from above.

enum Hop { NONE, UP, DOWN, FLOOR_UP, FLOOR_DOWN }

## How high a hop goes, as a share of a tile.
const HOP_HEIGHT := 0.35
## How far below or above a hop between floors starts, as a share of a tile.
const FLOOR_HOP_FROM := 0.55

var _hop_tween: Tween = null


## Hops, `kind` (Hop), over `seconds`.
func hop(kind: int, seconds: float):
	var drawn = _drawn()
	if drawn == null or kind == Hop.NONE:
		return
	end_hop()
	_hop_tween = create_tween()
	_hop_tween.tween_method(_hop_at.bind(kind), 0.0, 1.0, maxf(seconds, 0.05))
	_hop_tween.finished.connect(end_hop)


## Stops a hop where it is and puts the drawing home.
func end_hop():
	if _hop_tween != null and _hop_tween.is_valid():
		_hop_tween.kill()
	_hop_tween = null
	var drawn = _drawn()
	if drawn != null:
		drawn.position = size_offset


## The drawing `t` (0 to 1) of the way through a hop of `kind`.
func _hop_at(t: float, kind: int):
	var drawn = _drawn()
	if drawn == null:
		return
	var tile := float(Grid.TILE_SIZE)
	var lift := 0.0
	match kind:
		Hop.UP:
			lift = _arc(t, 0.6) * HOP_HEIGHT
		Hop.DOWN:
			lift = _arc(t, 0.3) * HOP_HEIGHT * 0.7
		Hop.FLOOR_UP:
			lift = _arc(t, 0.6) * HOP_HEIGHT - FLOOR_HOP_FROM * (1.0 - t)
		Hop.FLOOR_DOWN:
			lift = _arc(t, 0.25) * HOP_HEIGHT * 0.5 + FLOOR_HOP_FROM * (1.0 - t * t)
	# Up the screen is down the y axis; and in the node's own units, like
	# size_offset.
	drawn.position = size_offset + Vector2(0.0, -lift * tile / (scale.y if scale.y != 0.0 else 1.0))


## The drawing comes in from `from` (as measured on the map, off where it
## stands now) over `seconds`, on an arc `height` high - bounding out of a
## summoner, thrown (Hurl), lifted a moment off the ground (MoveFeel). Put
## home by end_hop, like a hop.
func fly_in(from: Vector2, seconds: float, height: float):
	var drawn = _drawn()
	if drawn == null:
		return
	end_hop()
	_hop_tween = create_tween()
	_hop_tween.tween_method(_fly_at.bind(from, height), 0.0, 1.0, maxf(seconds, 0.05))
	_hop_tween.finished.connect(end_hop)


func _fly_at(t: float, from: Vector2, height: float):
	var drawn = _drawn()
	if drawn == null:
		return
	var away := from * (1.0 - t) + Vector2(0.0, -height * 4.0 * t * (1.0 - t))
	drawn.position = size_offset + Vector2(away.x / (scale.x if scale.x != 0.0 else 1.0), away.y / (scale.y if scale.y != 0.0 else 1.0))


## The drawing dips a moment, legs cut from under it (MoveFeel).
func dip(seconds: float):
	fly_in(Vector2.ZERO, seconds, -Grid.TILE_SIZE * 0.1)


var _shape_tween: Tween = null


## The drawing shudders, squeezed one way and the other and settling - a mind
## struck (MoveFeel).
func wobble(seconds: float):
	var drawn = _drawn()
	if drawn == null:
		return
	if _shape_tween != null and _shape_tween.is_valid():
		_shape_tween.kill()
	_shape_tween = create_tween()
	_shape_tween.tween_method(_wobble_at, 0.0, 1.0, maxf(seconds, 0.05))


func _wobble_at(t: float):
	var drawn = _drawn()
	if drawn != null:
		var swing := 0.09 * sin(t * 28.0) * (1.0 - t)
		drawn.scale = Vector2(1.0 + swing, 1.0 - swing)


## The drawing squashed against a blow come along `direction`, and springing
## back (MoveFeel: pushed the way the blow came).
func squash(direction: Vector2):
	var drawn = _drawn()
	if drawn == null or direction == Vector2.ZERO:
		return
	if _shape_tween != null and _shape_tween.is_valid():
		_shape_tween.kill()
	var across := absf(direction.normalized().x)
	var squashed := Vector2(1.0 - SQUASH * across + SQUASH * 0.6 * (1.0 - across), 1.0 - SQUASH * (1.0 - across) + SQUASH * 0.6 * across)
	# In a moment rather than this very frame, as the recoil goes - and back.
	_shape_tween = create_tween()
	_shape_tween.tween_property(drawn, "scale", squashed, RECOIL_SECONDS * 0.15)
	_shape_tween.tween_property(drawn, "scale", Vector2.ONE, RECOIL_SECONDS).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## 0 at both ends and 1 at `peak` (0 to 1), a parabola either side of it.
static func _arc(t: float, peak: float) -> float:
	if t < peak:
		var before := (peak - t) / peak
		return 1.0 - before * before
	var after := (t - peak) / (1.0 - peak)
	return 1.0 - after * after


## --- Size ---
##
## Something bigger or smaller than a tile (Sizes) is drawn bigger or smaller
## - the node's scale - and off where the node is: the middle of the square a
## big one covers, or a small one's own corner of a tile it shares. The node
## stays on the tile they are on, since movement and sight read it; only what
## is drawn moves (Combat.place_drawing).

## Where the drawing sits off the node, in the node's own units.
var size_offset := Vector2.ZERO


## Puts the drawing `offset` away from the node, as measured on the map.
func set_size_offset(offset: Vector2):
	# Per side: somebody folded (Combat "Squeezing") is squashed one way only.
	size_offset = Vector2(offset.x / scale.x if scale.x != 0.0 else offset.x, offset.y / scale.y if scale.y != 0.0 else offset.y)
	var drawn = _drawn()
	if drawn != null:
		drawn.position = size_offset
