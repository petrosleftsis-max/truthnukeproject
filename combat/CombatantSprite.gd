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
			sprite.self_modulate = Color(tint * lit_by, alpha)


## --- A shadow under them ---
##
## View only, as Light.shadow_of says: how far every figure's leans and how dark it is, set for all of
## them at once as the place or the hour changes (set_shadows). A placeholder drawn in code, behind a
## slot: a picture at SHADOW_PICTURE is drawn in its place.

const SHADOW_PICTURE := "res://art/fx/figure_shadow.png"
static var shadow_lean := 0.12
static var shadow_strength := 0.35
## Counts changes, for each shadow to see that it has to draw itself again.
static var shadow_version := 0
## Each light here: [where it is, how far it reaches], for a shadow to point away from (LightView).
static var light_points: Array = []
## How much further a shadow goes, at its strongest, from a light close by.
const AWAY_FROM_A_LIGHT := 0.55


static func set_shadows(lying: Dictionary):
	shadow_lean = lying.lean
	shadow_strength = lying.strength
	shadow_version += 1


class _Shadow extends Node2D:
	var picture: Texture2D = null
	var seen := -1
	var alpha_seen := 1.0

	func _ready():
		if ResourceLoader.exists(CombatantSprite.SHADOW_PICTURE):
			picture = load(CombatantSprite.SHADOW_PICTURE)

	func _process(_delta):
		var alpha: float = get_parent().hidden_alpha
		# With a light about, it turns as they move.
		if seen != CombatantSprite.shadow_version or alpha_seen != alpha or not CombatantSprite.light_points.is_empty():
			seen = CombatantSprite.shadow_version
			alpha_seen = alpha
			queue_redraw()

	## Which way from a light close enough to matter, and how much it does, or nothing.
	func _away_from_a_light() -> Vector2:
		var best := Vector2.ZERO
		var best_strength := 0.0
		for point in CombatantSprite.light_points:
			var from: Vector2 = global_position - point[0]
			var strength: float = 1.0 - from.length() / maxf(point[1], 1.0)
			if strength > best_strength and from.length() > 1.0:
				best_strength = strength
				best = from.normalized() * strength
		return best

	func _draw():
		var tile := float(Grid.TILE_SIZE)
		var away := _away_from_a_light()
		var strength: float = CombatantSprite.shadow_strength
		var way := Vector2(CombatantSprite.shadow_lean, 0.0)
		if away != Vector2.ZERO:
			way = away * CombatantSprite.AWAY_FROM_A_LIGHT * 2.0
			strength = maxf(strength, 0.3)
		var at: Vector2 = Vector2(0.0, tile * 0.42) + way * tile * 0.3
		var stretch := 1.0 + way.length()
		var colour := Color(0.0, 0.0, 0.0, strength * alpha_seen)
		if picture != null:
			var size := Vector2(tile * 0.8 * stretch, tile * 0.24)
			draw_set_transform(at, way.angle() if way != Vector2.ZERO else 0.0)
			draw_texture_rect(picture, Rect2(-size / 2.0, size), false, colour)
			return
		# Soft at the edge: what lights things round, in black.
		draw_set_transform(at, way.angle() if way != Vector2.ZERO else 0.0, Vector2(stretch, 0.3))
		var across := tile * 0.5
		draw_texture_rect(LightView.light_picture(), Rect2(-across, -across, across * 2.0, across * 2.0), false, Color(colour, minf(colour.a * 1.6, 1.0)))


## --- Against the dark ---
##
## Whoever stands in the Dark has a faint rim, so a figure is still there to look at, and those who see
## in it have eyes that glow. To look at only. Slots: a picture at EYES_PICTURE is drawn for the eyes.

const EYES_PICTURE := "res://art/fx/glowing_eyes.png"
const RIM_SHADER := """
shader_type canvas_item;
uniform vec4 rim : source_color = vec4(0.5, 0.62, 1.0, 0.8);
uniform float width = 4.0;
void fragment() {
	vec4 own = texture(TEXTURE, UV) * COLOR;
	vec2 step_by = TEXTURE_PIXEL_SIZE * width;
	float near = texture(TEXTURE, UV + vec2(step_by.x, 0.0)).a + texture(TEXTURE, UV - vec2(step_by.x, 0.0)).a
		+ texture(TEXTURE, UV + vec2(0.0, step_by.y)).a + texture(TEXTURE, UV - vec2(0.0, step_by.y)).a;
	float edge = clamp(near, 0.0, 1.0) * (1.0 - clamp(own.a * 4.0, 0.0, 1.0));
	COLOR = mix(own, vec4(rim.rgb, rim.a * COLOR.a), edge);
}
"""
static var _rim_material: ShaderMaterial = null
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
	if _rim_material == null:
		var shader := Shader.new()
		shader.code = RIM_SHADER
		_rim_material = ShaderMaterial.new()
		_rim_material.shader = shader
	for sprite in [_animated, _static]:
		if sprite != null and is_instance_valid(sprite):
			sprite.material = _rim_material if dark else null
	if dark and sees and _eyes == null:
		_eyes = _Eyes.new()
		add_child(_eyes)
	if _eyes != null:
		_eyes.visible = dark and sees


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
