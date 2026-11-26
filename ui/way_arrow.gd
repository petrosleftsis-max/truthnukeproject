extends CanvasLayer
class_name WayArrow
## The way, at the screen's edge (the proposals of 2026-11-19; the designer: "Do all"): while the newest pin on the map screen, or
## else a stealth map's goal, is off the screen, an arrow on the screen's edge points the way to it, as a ping's does (Pings), in the
## pins' own colour. Hidden with the HUD, and while a menu holds the game. PROPOSAL.

## How far in from the edge the arrow sits, and its size, in screen pixels.
const EDGE_ROOM := 54.0
const LENGTH := 30.0
const WIDTH := 15.0

var memory: MapMemory = null
var _drawn: Control = null
## Where the arrow is now, for a suite: on the screen in pixels, or INF while none is drawn.
var shown_at := Vector2.INF


func _ready():
	layer = 14
	# Heard while a menu holds the game, which pauses it, so the arrow is put away under the menu rather than left as it was.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_drawn = Control.new()
	_drawn.set_anchors_preset(Control.PRESET_FULL_RECT)
	_drawn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drawn.draw.connect(_draw_it)
	add_child(_drawn)


func _process(_delta: float):
	shown_at = Vector2.INF
	if memory != null and memory.scene != null and not memory.scene.get("ui_hidden") and MenuPause.holders().is_empty():
		var target := memory.way_target()
		if target.is_finite():
			var view := _drawn.get_viewport_rect().size
			var at: Vector2 = memory.scene.get_viewport().get_canvas_transform() * target
			if not Rect2(Vector2.ZERO, view).grow(-EDGE_ROOM).has_point(at):
				shown_at = Vector2(clampf(at.x, EDGE_ROOM, view.x - EDGE_ROOM), clampf(at.y, EDGE_ROOM, view.y - EDGE_ROOM))
				_way = (at - view / 2.0).normalized()
	_drawn.queue_redraw()


var _way := Vector2.RIGHT


func _draw_it():
	if not shown_at.is_finite():
		return
	var tip := shown_at
	var side := Vector2(-_way.y, _way.x)
	var pulse := 1.0 + 0.08 * sin(Time.get_ticks_msec() / 160.0)
	var back := tip - _way * LENGTH * pulse
	var shape := PackedVector2Array([tip, back + side * WIDTH, back - side * WIDTH])
	_drawn.draw_colored_polygon(shape, MapScreen.PIN)
	_drawn.draw_polyline(PackedVector2Array([tip, back + side * WIDTH, back - side * WIDTH, tip]), Color(0, 0, 0, 0.6), 2.0, true)
