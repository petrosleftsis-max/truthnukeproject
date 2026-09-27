extends ColorRect
class_name PressureVignette
## A tint round the edges of the screen, for how close somebody is to being
## caught on a stealth map: nothing at all while nobody is growing sure, the
## meter's amber creeping in as a guard does, and red once one is certain.
##
## Drawn by a shader rather than a picture, so it fits any window shape and
## stays clear of the middle of the screen, where the sneaking is being done.

const SHADER := """
shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.88, 0.69, 0.29, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// Distance from the middle, squashed so the tint follows a wide screen's
	// edges rather than drawing a circle in it.
	vec2 centred = (UV - vec2(0.5)) * vec2(2.0, 2.0);
	float edge = smoothstep(0.55, 1.35, length(centred * vec2(0.85, 1.0)));
	COLOR = vec4(tint.rgb, edge * strength * tint.a);
}
"""

var _material: ShaderMaterial = null


func _ready():
	name = "PressureVignette"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.WHITE
	var shader := Shader.new()
	shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	material = _material
	show_pressure(0.0, Color.WHITE)


func _process(_delta):
	# Sized by hand: a Control straight under a CanvasLayer has no parent rect
	# for anchors to fill.
	position = Vector2.ZERO
	size = get_viewport_rect().size


## Shows `amount` (0 to 1) of `colour` round the edges.
func show_pressure(amount: float, colour: Color):
	if _material == null:
		return
	_material.set_shader_parameter("strength", clampf(amount, 0.0, 1.0))
	_material.set_shader_parameter("tint", colour)
	visible = amount > 0.001


func strength() -> float:
	return _material.get_shader_parameter("strength") if _material != null else 0.0


func tint() -> Color:
	return _material.get_shader_parameter("tint") if _material != null else Color.WHITE
