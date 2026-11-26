@tool
@icon("res://art/editor_icons/interactable.svg")
extends Node2D
class_name DreamPlace
## The dream-place (the proposals of 2026-11-19, "A dream-place"; the designer: "Do all"), reached in sleep from a rest spot that
## says so (RestSpot.dream_map). One on the dream's map: it lays the dream's look over the world - colours drifting, the edges soft,
## the ground breathing - plays its bed of sound, and keeps its zones: within a DreamZone the party is drawn bigger or smaller, or
## carried along as if the ground were tilted. A DreamLamp puzzle and a Rehearsal are its own pieces; a DreamWake goes back to the
## rest spot slept at. PROPOSAL.

const DREAM_SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float time_scale = 1.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	uv.x += sin(uv.y * 14.0 + TIME * 0.9 * time_scale) * 0.0025;
	uv.y += cos(uv.x * 11.0 + TIME * 0.7 * time_scale) * 0.0025;
	vec3 colour = texture(screen, uv).rgb;
	float shift = sin(TIME * 0.25) * 0.5 + 0.5;
	vec3 tinted = mix(colour, colour.gbr, 0.18 + 0.12 * shift);
	float edge = smoothstep(0.35, 0.95, length(SCREEN_UV - vec2(0.5)) * 1.3);
	COLOR = vec4(mix(tinted, tinted * vec3(0.55, 0.45, 0.85), edge * 0.7), 1.0);
}
"""

var _overlay: CanvasLayer = null
## For a suite: the zone the leader is in now, or null.
var zone_now: Node = null


func _ready():
	if Engine.is_editor_hint():
		return
	if DisplayServer.get_name() != "headless":
		_overlay = CanvasLayer.new()
		_overlay.layer = 1
		add_child(_overlay)
		var copy := BackBufferCopy.new()
		copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		_overlay.add_child(copy)
		var veil := ColorRect.new()
		veil.set_anchors_preset(Control.PRESET_FULL_RECT)
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var shader := Shader.new()
		shader.code = DREAM_SHADER
		var material := ShaderMaterial.new()
		material.shader = shader
		veil.material = material
		_overlay.add_child(veil)
	MapFeel.sound(&"dream", -4.0)


func _scene() -> Node:
	var up := get_parent()
	while up != null:
		if up.has_method("party_position") and up.get("party") != null:
			return up
		up = up.get_parent()
	return null


func _process(delta: float):
	if Engine.is_editor_hint():
		return
	var scene := _scene()
	if scene == null:
		return
	var at: Vector2 = scene.party_position()
	zone_now = null
	for zone in get_parent().find_children("*", "DreamZone", true, false):
		if zone.covers_rect().has_point(at):
			zone_now = zone
			break
	var wanted_scale := 1.0 if zone_now == null else float(zone_now.figure_scale)
	var party = scene.party
	for sprite in party.find_children("*", "CombatantSprite", true, false):
		var now: float = sprite.scale.x
		var to := move_toward(now, wanted_scale, delta * 1.5)
		sprite.scale = Vector2.ONE * to
	if zone_now != null and zone_now.drift != Vector2.ZERO and not scene.is_holding():
		party._step(Vector2(zone_now.drift).normalized(), delta, Grid.tiles(Vector2(zone_now.drift).length()))
