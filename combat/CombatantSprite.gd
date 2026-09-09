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
## Frames can be taller than one tile (32px) if you want more room for
## animation detail than a 32x32 sprite allows - keep the width at 32px
## (matching the tile, so units don't overlap their neighbors), and any
## extra height automatically shifts the sprite up so its feet still stand
## at the bottom of its own tile, instead of it centering on the tile and
## sinking into the ground. This is computed from the actual "idle" frame
## size, not a fixed assumption, so any height works with no extra setup -
## just keep every animation for the same combatant (idle/walk/skill/dead)
## the same frame size as each other, since the offset is only computed once.

var _animated: AnimatedSprite2D = null
var _static: Sprite2D = null


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


## Shifts the sprite's drawn position upward via `offset` - which only
## affects rendering, unlike `position`, which movement/knockback/etc. all
## depend on being the exact tile centre - by however much its frame height
## exceeds one tile (32px), so the extra height grows upward from the tile's
## floor instead of the sprite centring on the tile. A 32px-tall frame gets
## an offset of 0, matching every existing static sprite exactly.
func _align_feet_to_tile():
	var frame_height = _get_reference_frame_height()
	if frame_height > 0:
		_animated.offset.y = 16.0 - frame_height / 2.0


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

func play_skill_and_wait():
	if not (_animated and _animated.sprite_frames.has_animation("skill")):
		return
	_skill_animation_finished = false
	_animated.animation_finished.connect(_on_skill_animation_finished, CONNECT_ONE_SHOT)
	_animated.play("skill")
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


func set_dead():
	if _animated:
		if _animated.sprite_frames.has_animation("dead"):
			_animated.play("dead")
		else:
			_animated.stop()
	else:
		_static.frame = 1
