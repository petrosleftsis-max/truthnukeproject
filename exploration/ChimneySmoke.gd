@tool
@icon("res://art/editor_icons/chimney_smoke.svg")
extends Node2D
class_name ChimneySmoke
## Smoke from a chimney, a forge or a cooking fire, leaning the way the wind blows and torn away faster the harder it blows
## (LightView "More to look at"; the designer, 2026-11-13, proposals 21). Drawn over the roofs, so it shows out of doors however
## high it rises, and darker against the night. A flame out under the sky smokes the same way of itself (LightView). A picture at
## art/fx/smoke.png takes the place of the drawn puff (a slot). Placeholders; only to look at.

## Whether it is smoking.
@export var lit: bool = true : set = _set_lit
## How thick it is, 0 to 1.
@export_range(0.0, 1.0) var thickness: float = 0.6
@export var colour: Color = Color(0.74, 0.74, 0.76)

const PICTURE := "res://art/fx/smoke.png"

var _smoke: CPUParticles2D = null


func _set_lit(value: bool):
	lit = value
	if _smoke != null:
		_smoke.emitting = lit
	queue_redraw()


func _ready():
	if Engine.is_editor_hint():
		return
	_smoke = make_smoke(thickness, colour)
	_smoke.emitting = lit
	add_child(_smoke)


func _process(_delta: float):
	if Engine.is_editor_hint() or _smoke == null:
		return
	lean(_smoke)
	_smoke.modulate = LightView.lit_colour_at(global_position)


## Smoke rising from where it is put, `thickness` of it, 0 to 1. Leaned by lean() every frame.
static func make_smoke(how_thick: float, tint: Color, high: bool = true) -> CPUParticles2D:
	var tile := float(Grid.TILE_SIZE)
	var bits := CPUParticles2D.new()
	bits.name = "Smoke"
	bits.local_coords = false
	bits.light_mask = 0
	if high:
		bits.z_as_relative = false
		bits.z_index = ExplorationParty.PARTY_Z_TOP + 1
	if ResourceLoader.exists(PICTURE):
		bits.texture = load(PICTURE)
	else:
		var puff := GradientTexture2D.new()
		puff.width = 64
		puff.height = 64
		puff.fill = GradientTexture2D.FILL_RADIAL
		puff.fill_from = Vector2(0.5, 0.5)
		puff.fill_to = Vector2(1.0, 0.5)
		var soft := Gradient.new()
		soft.set_color(0, Color(1.0, 1.0, 1.0, 0.9))
		soft.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		puff.gradient = soft
		bits.texture = puff
	bits.amount = maxi(roundi(16.0 * clampf(how_thick, 0.1, 1.0)), 3)
	bits.lifetime = 4.2
	bits.preprocess = 3.0
	bits.direction = Vector2.UP
	bits.spread = 10.0
	bits.initial_velocity_min = tile * 0.22
	bits.initial_velocity_max = tile * 0.36
	bits.angular_velocity_min = -20.0
	bits.angular_velocity_max = 20.0
	bits.scale_amount_min = 1.1
	bits.scale_amount_max = 1.6
	var grows := Curve.new()
	grows.add_point(Vector2(0.0, 0.6))
	grows.add_point(Vector2(1.0, 2.6))
	bits.scale_amount_curve = grows
	var fade := Gradient.new()
	fade.set_color(0, Color(tint, 0.0))
	fade.add_point(0.12, Color(tint, 0.34 * clampf(how_thick, 0.1, 1.0) + 0.06))
	fade.set_color(fade.get_point_count() - 1, Color(tint.darkened(0.15), 0.0))
	bits.color_ramp = fade
	return bits


## Smoke leaning the way the wind blows now, and carried off the faster the harder it blows.
static func lean(bits: CPUParticles2D):
	var tile := float(Grid.TILE_SIZE)
	var wind: Vector2 = CombatantSprite.wind_blows
	var along := Vector2(wind.x, wind.y * 0.5)
	bits.gravity = along * tile * 1.7 + Vector2(0.0, -tile * 0.06)
	bits.direction = (Vector2.UP + along * 1.4).normalized()


func _draw():
	if not Engine.is_editor_hint():
		return
	var tile := float(Grid.TILE_SIZE)
	draw_rect(Rect2(Vector2(-tile * 0.12, -tile * 0.1), Vector2(tile * 0.24, tile * 0.2)), Color(0.45, 0.3, 0.25, 0.9))
	for i in 3:
		draw_circle(Vector2(tile * 0.06 * float(i), -tile * (0.25 + 0.2 * float(i))), tile * (0.07 + 0.03 * float(i)), Color(colour, 0.6 - 0.15 * float(i)))
