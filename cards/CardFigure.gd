extends Control
class_name CardFigure
## A main-game figure standing in the card game: the combatant's own animations (CombatantDefinition.sprite_frames) fitted into its
## place, facing the player. Its idle loops at the main game's own pace for how hurt it is (the designer, 2026-11-26: "just use the
## existing idle animations and slow them when lower hp": under CombatantSprite.HURT_BELOW of its health, from HURT_PACE down to
## HURT_SLOWEST with nothing left), and its attack or skill plays once when it acts (`act`). Only to look at.

## How much bigger than its place a frame is drawn: 1, the whole frame fits (a bigger one spilt over the intent and the name).
const ZOOM := 1.0
## The share of an act's animation that passes before its blow lands.
const LANDS_AT := 0.65
## The share of a frame's height left empty under the figure's feet.
const BELOW_FEET := 0.02

var sprite: AnimatedSprite2D = null
var _share := 1.0
var _frame := Vector2.ZERO


func _init():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_fit)


## Shows `frames` (turned round when `flip`), its idle playing.
func setup(frames: SpriteFrames, flip: bool = false):
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.flip_h = flip
	sprite.centered = true
	add_child(sprite)
	_frame = _frame_size(frames)
	sprite.animation_finished.connect(_back_to_idle)
	_fit()
	_back_to_idle()


static func _frame_size(frames: SpriteFrames) -> Vector2:
	for animation in [&"idle", &"walk", &"skill", &"attack"]:
		if frames.has_animation(animation) and frames.get_frame_count(animation) > 0:
			var texture := frames.get_frame_texture(animation, 0)
			if texture != null:
				return texture.get_size()
	return Vector2(192, 192)


func _fit():
	if sprite == null or _frame.x <= 0.0 or _frame.y <= 0.0:
		return
	var scale_now := minf(size.x / _frame.x, size.y / _frame.y) * ZOOM
	sprite.scale = Vector2.ONE * scale_now
	# Its feet at the bottom of its place, in the middle: the frame's foot, less the room a frame leaves under the feet.
	var drawn := _frame * scale_now
	sprite.position = Vector2(size.x / 2.0, size.y - drawn.y / 2.0 + drawn.y * BELOW_FEET)


## How much of its health it has, 0 to 1: the pace of its idle.
func set_health_share(share: float):
	_share = clampf(share, 0.0, 1.0)


## The pace its idle plays at: the main game's own (CombatantSprite.idle_pace, but for a broken nerve or a heal's settling).
func idle_pace() -> float:
	if _share < CombatantSprite.HURT_BELOW:
		return lerpf(CombatantSprite.HURT_SLOWEST, CombatantSprite.HURT_PACE, _share / CombatantSprite.HURT_BELOW)
	return 1.0


func has_animation(which: StringName) -> bool:
	return sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(which) \
		and sprite.sprite_frames.get_frame_count(which) > 0


## Which of its own animations a move plays: its attack for one that hits (else its skill), its skill for anything else; &"" when
## it has neither.
func animation_for(attacks: bool) -> StringName:
	if attacks and has_animation(&"attack"):
		return &"attack"
	if has_animation(&"skill"):
		return &"skill"
	return &""


## Plays `which` once at `speed` (2 for twice as fast), then its idle again. How long it lasts, in seconds (0 when it has no such
## animation).
func act(which: StringName, speed: float = 1.0) -> float:
	if which == &"" or not has_animation(which):
		return 0.0
	var frames := sprite.sprite_frames
	var seconds := 0.0
	for i in frames.get_frame_count(which):
		seconds += frames.get_frame_duration(which, i)
	seconds /= maxf(frames.get_animation_speed(which), 0.01)
	sprite.speed_scale = maxf(speed, 0.01)
	sprite.play(which)
	return seconds / maxf(speed, 0.01)


func _back_to_idle():
	if sprite != null and has_animation(&"idle"):
		sprite.play(&"idle")


func _process(_delta: float):
	if sprite != null and sprite.animation == &"idle":
		sprite.speed_scale = idle_pace()
