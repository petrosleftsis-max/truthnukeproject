extends Node2D
## The marks of a foreseen turn breaking apart, once the party has changed it
## (Combat._future_changed): every marked tile cracks into four pieces that fly
## out, turn over and fall, fading as they go. Made by CController.shatter_future
## and gone by itself.

## How long the pieces last, in seconds.
const LIFE := 0.75
## How hard they fly out, and how hard they fall back, in pixels a second.
const BURST_MIN := 260.0
const BURST_MAX := 520.0
const GRAVITY := 1400.0

var fill := Color(0.15, 0.95, 0.85, 0.42)
var edge := Color(0.4, 1.0, 0.95, 1.0)
var width := 6.0

var _shards: Array = []
var _age := 0.0


## Breaks each of `rects` (map space) into its pieces.
func setup(rects: Array):
	for rect in rects:
		var centre: Vector2 = rect.get_center()
		var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
		for i in 4:
			var a: Vector2 = corners[i]
			var b: Vector2 = corners[(i + 1) % 4]
			var middle := (a + b + centre) / 3.0
			var out := (middle - centre).normalized()
			_shards.append({
				"points": PackedVector2Array([a - middle, b - middle, centre - middle]),
				"at": middle,
				"velocity": out * randf_range(BURST_MIN, BURST_MAX) + Vector2(randf_range(-60.0, 60.0), -randf_range(80.0, 220.0)),
				"spin": randf_range(-7.0, 7.0),
				"angle": 0.0,
			})


func _process(delta: float):
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	for shard in _shards:
		shard.at += shard.velocity * delta
		shard.velocity.y += GRAVITY * delta
		shard.angle += shard.spin * delta
	queue_redraw()


func _draw():
	var left := 1.0 - _age / LIFE
	for shard in _shards:
		var points := PackedVector2Array()
		for point in shard.points:
			points.append(shard.at + point.rotated(shard.angle))
		draw_colored_polygon(points, Color(fill, minf(fill.a * 1.6, 1.0) * left))
		var outline := points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, Color(edge, edge.a * left), width * 0.5)
