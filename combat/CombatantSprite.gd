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
## Computed from the actual "idle" frame size rather than a fixed assumption,
## so any height works with no extra setup - just keep every animation for the
## same combatant (idle/walk/skill/dead) the same frame size as each other,
## since the offset is only measured once.

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


func set_hidden_alpha(alpha: float):
	hidden_alpha = alpha
	for sprite in [_animated, _static]:
		if sprite != null and is_instance_valid(sprite):
			sprite.self_modulate.a = alpha


## The height of this sprite's frames, measured once when it was set up. Zero
## for a static sprite, which has no frames to measure.
var _frame_height := 0.0


func setup(combatant_sprite_frames: SpriteFrames, map_sprite: Texture2D, facing_flip: bool):
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


## Shifts the sprite's drawn position upward via `offset` - which only
## affects rendering, unlike `position`, which movement/knockback/etc. all
## depend on being the exact tile centre - by however much its frame height
## exceeds one tile, so the extra height grows upward from the tile's floor
## instead of the sprite centring on the tile. A tile-sized frame gets an
## offset of 0, matching every existing static sprite exactly.
func _align_feet_to_tile():
	_frame_height = _get_reference_frame_height()
	if _frame_height > 0:
		_animated.offset.y = Grid.HALF_TILE.y - _frame_height / 2.0


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
		if _animated.sprite_frames.has_animation(anim_name) and _animated.sprite_frames.get_frame_count(anim_name) > 0:
			var frame_texture = _animated.sprite_frames.get_frame_texture(anim_name, 0)
			if frame_texture != null:
				return frame_texture.get_height()
	return 0.0


func play_idle():
	if _animated and _animated.sprite_frames.has_animation("idle"):
		_animated.play("idle")


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
		await get_tree().process_frame
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

var _flash_tween: Tween = null
var _recoil_tween: Tween = null


## The node that actually draws this combatant - an AnimatedSprite2D or a plain
## Sprite2D depending on whether it has SpriteFrames. Recoil moves this rather
## than the CombatantSprite itself, because the outer node's position is the
## tile it occupies and movement, knockback and line of sight all read it.
func _drawn() -> Node2D:
	return _animated if _animated != null else _static


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
func recoil(direction: Vector2):
	var drawn = _drawn()
	if drawn == null or direction == Vector2.ZERO:
		return
	if _recoil_tween != null and _recoil_tween.is_valid():
		_recoil_tween.kill()
		drawn.position = Vector2.ZERO
	var away = direction.normalized() * RECOIL_DISTANCE
	_recoil_tween = create_tween()
	_recoil_tween.tween_property(drawn, "position", away, RECOIL_SECONDS * 0.3).set_ease(Tween.EASE_OUT)
	# Springs back rather than easing, so it reads as a body absorbing a blow
	# instead of sliding.
	_recoil_tween.tween_property(drawn, "position", Vector2.ZERO, RECOIL_SECONDS * 0.7).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


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
	var drawn = _drawn()
	var fade = create_tween()
	fade.set_parallel(true)
	fade.tween_property(self, "modulate", Color(0.6, 0.6, 0.6, DEATH_ALPHA), DEATH_SECONDS)
	if drawn != null:
		fade.tween_property(drawn, "position:y", drawn.position.y + DEATH_SINK, DEATH_SECONDS).set_ease(Tween.EASE_OUT)
