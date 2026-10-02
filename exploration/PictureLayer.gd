@tool
extends TextureRect
class_name PictureLayer
## An image in a Picture that comes and goes with the story - the drawer drawn
## open, the candle lit - by a flag. Place it over the background like any
## TextureRect; anything under it comes and goes with it.

enum Transition {
	FADE, ## Fades in, and out drifting up a little - something lifted away.
	NONE, ## Simply there, or not.
}

@export_group("Flags")
## Only shown while this flag is set. Empty: shown from the start.
@export var shown_while_flag: String = ""
## Gone for good once this flag is set. Empty: never goes.
@export var hidden_once_flag: String = ""

@export_group("Looking")
## Only seen through a lens - a magnifying glass, a lamp (an item with Reveals
## Hidden Details): writing pressed into a blotter, a mark under the dust. It
## is drawn just where the lens is held, and nowhere else.
@export var hidden_detail: bool = false

@export_group("Animation")
## How it comes and goes once the picture is up. What it looks like when the
## picture opens is never animated.
@export var transition: Transition = Transition.FADE
## Your own instead: an AnimationPlayer anywhere under this layer with an
## animation called "appear" plays when it comes, "disappear" when it goes. Its
## tracks should be relative to the layer (scale, modulate, a child's position).

const LENS_SHADER := """
shader_type canvas_item;
uniform vec2 lens_center = vec2(-100000.0);
uniform float lens_radius = 0.0;
varying vec2 world;
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	float d = distance(world, lens_center);
	COLOR.a *= 1.0 - smoothstep(lens_radius * 0.75, lens_radius, d);
}
"""

static var _lens_shader: Shader = null

## Whether it was showing at the last refresh: -1 before the first, so the
## state a picture opens with is never animated; GHOST for a copy left fading.
var _was_shown := -1
const GHOST := -2


func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A copy left fading behind (see _disappear) has nothing to work out.
	if Engine.is_editor_hint() or _was_shown == GHOST:
		return
	if hidden_detail:
		_wear_lens()
	refresh_from_flags()


func refresh_from_flags():
	if _was_shown == GHOST:
		return
	var shown := Picture.shown_by_flags(shown_while_flag, hidden_once_flag)
	var before := _was_shown
	_was_shown = int(shown)
	# Only a change seen happening is animated: not the state the picture opens
	# in, and not one under another picture on the stack.
	var on_show = get_parent() is CanvasItem and get_parent().is_visible_in_tree()
	if before == -1 or before == int(shown) or not on_show:
		visible = shown
		return
	visible = shown
	if shown:
		_appear()
	else:
		_disappear()


## Where the lens is, in the canvas the picture is drawn on, and how big:
## Pictures moves it every frame. A radius of nothing hides it entirely.
func set_lens(center: Vector2, radius: float):
	if material is ShaderMaterial:
		material.set_shader_parameter("lens_center", center)
		material.set_shader_parameter("lens_radius", radius)


func _wear_lens():
	if _lens_shader == null:
		_lens_shader = Shader.new()
		_lens_shader.code = LENS_SHADER
	var lens := ShaderMaterial.new()
	lens.shader = _lens_shader
	material = lens
	set_lens(Vector2(-100000, -100000), 0.0)
	# Everything under it is drawn through the same lens.
	for node in find_children("*", "CanvasItem", true, false):
		node.use_parent_material = true


func _animator() -> AnimationPlayer:
	var found = find_children("*", "AnimationPlayer", true, false)
	return found[0] if not found.is_empty() else null


func _animating() -> bool:
	return transition != Transition.NONE and PictureFeedback.current().animate


func _appear():
	var own = _animator()
	if own != null and own.has_animation("appear"):
		own.play("appear")
		return
	if not _animating():
		return
	var seconds = PictureFeedback.current().fade_seconds
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, seconds)


## Gone at once - nothing waits on it - with a copy left behind to fade away
## (or to play your "disappear" on), which then goes too.
func _disappear():
	var own = _animator()
	var plays_own = own != null and own.has_animation("disappear")
	if not plays_own and not _animating():
		return
	var ghost: PictureLayer = duplicate()
	ghost._was_shown = GHOST
	ghost.visible = true
	ghost.shown_while_flag = ""
	ghost.hidden_once_flag = ""
	get_parent().add_child(ghost)
	get_parent().move_child(ghost, get_index())
	if plays_own:
		var ghost_own = ghost._animator()
		ghost_own.play("disappear")
		ghost_own.animation_finished.connect(func(_name): ghost.queue_free(), CONNECT_ONE_SHOT)
		return
	var seconds = PictureFeedback.current().fade_seconds
	var going := ghost.create_tween().set_parallel()
	going.tween_property(ghost, "modulate:a", 0.0, seconds)
	going.tween_property(ghost, "position:y", ghost.position.y - 14.0, seconds)
	going.chain().tween_callback(ghost.queue_free)
