@tool
@icon("res://art/editor_icons/wind_banner.svg")
extends Node2D
class_name WindBanner
## Cloth in the wind (LightView "More to look at"; the designer, 2026-11-13, proposals 21: "Flags, washing lines and chimney smoke
## leaning the wind's way: the wind seen without an arrow"). A banner on a pole, a pennant, or a washing line strung from here Reach
## Tiles to the right with washing pegged on it. Each hangs slack in still air and streams out the way the wind blows, flapping the
## harder it blows (the day's wind, as CombatantSprite.wind_blows has it), and darkens with the place it stands in after dark.
## Placeholders drawn in code, only to look at; a picture can take the cloth's place later (a slot to make when the art comes).

enum Kind { BANNER, PENNANT, WASHING_LINE }
@export var kind: Kind = Kind.BANNER : set = _set_kind
## The cloth's colour; the washing takes it and two paler ones.
@export var cloth: Color = Color(0.2, 0.33, 0.66) : set = _set_cloth
## How tall the pole is, or the posts of a washing line, in tiles.
@export var pole_tiles: float = 1.4
## How far a washing line reaches, to the right, in tiles.
@export var reach_tiles: float = 3.0

const POLE := Color(0.33, 0.25, 0.18)
const ROPE := Color(0.78, 0.74, 0.64)
const SEGMENTS := 10
## In the editor, a wind to see it in.
const EDITOR_WIND := Vector2(0.55, 0.1)

var _clock := 0.0
var _phase := 0.0


func _set_kind(value: Kind):
	kind = value
	queue_redraw()


func _set_cloth(value: Color):
	cloth = value
	queue_redraw()


func _ready():
	_phase = fmod(absf(global_position.x * 0.013 + global_position.y * 0.007), TAU)


func _process(delta: float):
	_clock += delta
	if not Engine.is_editor_hint():
		modulate = LightView.lit_colour_at(global_position)
	queue_redraw()


## The wind as it blows on the screen, and how hard, 0 to 1: north and south foreshortened.
func _wind() -> Vector2:
	var wind: Vector2 = EDITOR_WIND if Engine.is_editor_hint() else CombatantSprite.wind_blows
	return Vector2(wind.x, wind.y * 0.45)


## Which way a cloth goes from where it is held: down, slack, in still air; out with the wind the harder it blows.
func _streams(wind: Vector2) -> Vector2:
	var hang := Vector2.DOWN
	if wind.length() < 0.01:
		return hang
	return hang.lerp(wind.normalized(), clampf(wind.length() * 1.7, 0.0, 1.0)).normalized()


func _draw():
	var tile := float(Grid.TILE_SIZE)
	var wind := _wind()
	match kind:
		Kind.WASHING_LINE:
			_draw_washing_line(tile, wind)
		_:
			_draw_flag(tile, wind)


func _draw_flag(tile: float, wind: Vector2):
	var top := Vector2(0.0, -tile * pole_tiles)
	draw_line(Vector2.ZERO, top, POLE, tile * 0.05)
	draw_circle(top, tile * 0.04, POLE.lightened(0.3))
	var strength := clampf(wind.length(), 0.0, 1.0)
	var way := _streams(wind)
	var across := -way.orthogonal()
	var length := tile * (0.75 if kind == Kind.BANNER else 0.85)
	var height := tile * (0.42 if kind == Kind.BANNER else 0.34)
	var speed := 2.0 + 8.0 * strength
	var swing := tile * (0.03 + 0.09 * strength)
	var upper := PackedVector2Array()
	var lower := PackedVector2Array()
	for i in SEGMENTS + 1:
		var t := float(i) / float(SEGMENTS)
		var wave := across * sin(_clock * speed - t * 4.2 + _phase) * swing * t
		upper.append(top + way * length * t + wave)
		var drop := height * (1.0 - t) if kind == Kind.PENNANT else height
		lower.append(top + across * drop + way * length * t * 0.94 + wave * 1.15)
	var outline := upper.duplicate()
	for i in range(lower.size() - 1, -1, -1):
		outline.append(lower[i])
	if not Geometry2D.triangulate_polygon(outline).is_empty():
		draw_colored_polygon(outline, cloth)
		draw_polyline(upper, cloth.lightened(0.18), tile * 0.012)


func _draw_washing_line(tile: float, wind: Vector2):
	var reach := tile * maxf(reach_tiles, 0.5)
	var post := tile * pole_tiles * 0.8
	var left := Vector2(0.0, -post)
	var right := Vector2(reach, -post)
	draw_line(Vector2.ZERO, left, POLE, tile * 0.045)
	draw_line(Vector2(reach, 0.0), right, POLE, tile * 0.045)
	var strength := clampf(wind.length(), 0.0, 1.0)
	var sag := tile * (0.16 - 0.06 * strength)
	var rope := PackedVector2Array()
	for i in SEGMENTS + 1:
		var t := float(i) / float(SEGMENTS)
		rope.append(left.lerp(right, t) + Vector2(0.0, sag * 4.0 * t * (1.0 - t)))
	draw_polyline(rope, ROPE, tile * 0.012)
	var colours := [cloth, cloth.lerp(Color.WHITE, 0.7), cloth.lerp(Color(0.9, 0.85, 0.7), 0.5)]
	var pieces := maxi(int(reach_tiles * 1.4), 2)
	for i in pieces:
		var t := (float(i) + 0.6) / (float(pieces) + 0.2)
		var at: Vector2 = left.lerp(right, t) + Vector2(0.0, sag * 4.0 * t * (1.0 - t))
		var width := tile * (0.26 if i % 2 == 0 else 0.2)
		var drop := tile * (0.34 if i % 3 == 1 else 0.28)
		# Swinging out the way the wind blows across the line, fluttering the harder it blows.
		var flutter := sin(_clock * (2.0 + 7.0 * strength) + float(i) * 1.7 + _phase)
		var lean := clampf(wind.x * 1.3, -1.1, 1.1) + flutter * (0.04 + 0.16 * strength)
		var down := Vector2(sin(lean), cos(lean)).normalized()
		var side := Vector2(down.y, -down.x)
		var shorter := 1.0 - 0.35 * absf(wind.y) * strength
		var corners := PackedVector2Array([at - side * width / 2.0, at + side * width / 2.0,
			at + side * width / 2.0 + down * drop * shorter, at - side * width / 2.0 + down * drop * shorter])
		draw_colored_polygon(corners, colours[i % colours.size()])
		draw_circle(at, tile * 0.015, ROPE.darkened(0.3))
