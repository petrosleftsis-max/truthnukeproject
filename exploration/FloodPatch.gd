@tool
@icon("res://art/editor_icons/water_patch.svg")
extends Node2D
class_name FloodPatch
## Ground the rain floods (the proposals of 2026-11-19, "The hours and the weather change the map"; the designer: "Do all"): a low
## path, a sunken lane, a ford. While the ground is wet enough after rain (Campaign.ground_now's "wet" at Floods From or more) water
## lies over it and nobody walks through; dry, it is ground again. Placed on its top left tile, Size Tiles across, as Water is.
## Drawn here, darkened with the night, as a placeholder until it has a Picture. PROPOSAL.

@export var size_tiles: Vector2i = Vector2i(3, 1):
	set(value):
		size_tiles = Vector2i(maxi(value.x, 1), maxi(value.y, 1))
		queue_redraw()
@export_range(0.0, 1.0, 0.05) var floods_from: float = 0.6
@export var picture: Texture2D

const CHECK_EVERY := 1.0

var flooded := false
var _check := 0.0


func _ready():
	if not Engine.is_editor_hint():
		z_as_relative = false
		z_index = ExplorationParty.PARTY_Z_BOTTOM - 3
		_check = 0.0


func _process(delta: float):
	if Engine.is_editor_hint():
		return
	_check -= delta
	if _check > 0.0:
		return
	_check = CHECK_EVERY
	var wet := float(Campaign.ground_now().get("wet", 0.0))
	set_flooded(wet >= floods_from)
	self_modulate = LightView.lit_colour_at(global_position)


## Floods it or lets it drain, shutting its tiles to walking meanwhile.
func set_flooded(value: bool):
	if value == flooded:
		return
	flooded = value
	var scene := _scene()
	if scene != null and scene.get("_tile_map") != null:
		var tile_map: TileMap = scene._tile_map
		var first := tile_map.local_to_map(tile_map.to_local(global_position))
		for x in size_tiles.x:
			for y in size_tiles.y:
				scene.set_tile_shut(first + Vector2i(x, y), flooded)
	queue_redraw()


func _scene() -> Node:
	var up := get_parent()
	while up != null:
		if up.has_method("set_tile_shut") and up.has_method("party_position"):
			return up
		up = up.get_parent()
	return null


func _draw():
	var tile := float(Grid.TILE_SIZE)
	var rect := Rect2(-Vector2.ONE * tile / 2.0, Vector2(size_tiles) * tile)
	if Engine.is_editor_hint():
		draw_rect(rect, Color(0.3, 0.5, 0.8, 0.35))
		draw_rect(rect, Color(0.55, 0.8, 1.0, 0.9), false, 4.0)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(8, 28), "Floods", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.75, 0.92, 1.0))
		return
	if not flooded:
		return
	if picture != null:
		draw_texture_rect(picture, rect, true)
		return
	draw_rect(rect, Color(0.2, 0.36, 0.5, 0.85))
	for i in int(size_tiles.x * size_tiles.y * 3):
		var at := rect.position + Vector2(fmod(i * 97.0, rect.size.x), fmod(i * 61.0 + 40.0, rect.size.y))
		draw_line(at, at + Vector2(tile * 0.25, 0), Color(0.75, 0.88, 1.0, 0.35), 3.0)
