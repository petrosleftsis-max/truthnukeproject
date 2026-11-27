extends Control
class_name CardAim
## The arrow a card is aimed with (docs/card_game.md "How it feels"): a curve of chevrons from the chosen card to the enemy it is
## aimed at (or to the pointer while it is aimed at no one), drifting along, and corners closing in around the enemy aimed at. Over
## the whole screen, taking no input. Places are global.

const COLOUR := Color(0.62, 0.82, 1.0, 0.95)
const ON_TARGET := Color(1.0, 0.86, 0.5, 1.0)
const CHEVRONS := 16
## How far the corners start out from the enemy, and how long they take to close.
const CORNERS_FROM := 16.0
const CORNERS_SECONDS := 0.14

var from := Vector2.ZERO
var to := Vector2.ZERO
## Whether its end is on an enemy (it turns gold).
var on_target := false
## The enemy's place to close the corners round, or an empty rect for none.
var target := Rect2()
var _age := 0.0
var _closing := 1.0
var _was_target := Rect2()


func _init():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)


## Aims from `start` to `end`; `around`: the enemy aimed at (corners round it), or an empty rect.
func aim(start: Vector2, end: Vector2, around: Rect2 = Rect2()):
	from = start
	to = end
	on_target = around.has_area()
	if around != _was_target:
		_closing = 0.0
		_was_target = around
	target = around
	visible = true
	queue_redraw()


func stop():
	visible = false
	target = Rect2()
	_was_target = Rect2()


func _process(delta: float):
	if not visible:
		return
	_age += delta
	_closing = minf(_closing + delta / CORNERS_SECONDS, 1.0)
	queue_redraw()


func _draw():
	var start := from - global_position
	var end := to - global_position
	var top := Vector2((start.x + end.x) / 2.0, minf(start.y, end.y) - 110.0)
	var colour := ON_TARGET if on_target else COLOUR
	var drift := fmod(_age * 1.6, 1.0)
	for i in CHEVRONS:
		var t := (float(i) + drift) / float(CHEVRONS)
		if t > 0.97:
			continue
		var at := _curve(start, top, end, t)
		var ahead := _curve(start, top, end, minf(t + 0.02, 1.0))
		var way := (ahead - at).normalized()
		if way == Vector2.ZERO:
			continue
		var across := way.orthogonal()
		var grow := lerpf(5.0, 11.0, t)
		var fade := clampf(t * 4.0, 0.0, 1.0)
		draw_polyline(PackedVector2Array([at - way * grow + across * grow, at, at - way * grow - across * grow]), Color(colour, colour.a * fade),
			3.0, true)
	# The head.
	var last := _curve(start, top, end, 0.96)
	var head_way := (end - last).normalized()
	if head_way != Vector2.ZERO:
		var side := head_way.orthogonal()
		draw_colored_polygon(PackedVector2Array([end + head_way * 6.0, end - head_way * 18.0 + side * 13.0, end - head_way * 18.0 - side * 13.0]),
			colour)
	if target.has_area():
		_corners(Rect2(target.position - global_position, target.size), colour)


func _curve(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	return a.lerp(b, t).lerp(b.lerp(c, t), t)


func _corners(rect: Rect2, colour: Color):
	var out := CORNERS_FROM * (1.0 - _closing * _closing * (3.0 - 2.0 * _closing))
	var box := rect.grow(4.0 + out)
	var arm := minf(box.size.x, box.size.y) * 0.18
	var width := 4.0
	for corner in [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]:
		var x_way := 1.0 if corner.x <= box.get_center().x else -1.0
		var y_way := 1.0 if corner.y <= box.get_center().y else -1.0
		draw_line(corner, corner + Vector2(arm * x_way, 0), colour, width, true)
		draw_line(corner, corner + Vector2(0, arm * y_way), colour, width, true)
