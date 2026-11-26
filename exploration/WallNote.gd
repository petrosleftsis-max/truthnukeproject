@tool
@icon("res://art/editor_icons/interactable.svg")
extends ExamineInteractable
class_name WallNote
## A note or a mark on a wall, read by pointing at it (the proposals of 2026-11-19, "Secrets worth finding": the world's own story;
## the designer: "Do all"). With the pointer over it its words show above it; walked up to, E reads it into the log as anything
## examined does. Either way it counts as read, and as found when it is a secret. A placeholder scrap of paper until it has a
## picture (Texture). PROPOSAL.

## How near the pointer has to be, in tiles.
const POINTED_TILES := 0.6

var _shown: Label = null
var _read := false


func _init():
	prompt = "Read"


func _process(_delta: float):
	if Engine.is_editor_hint() or text == "":
		return
	var near := get_global_mouse_position().distance_to(global_position) <= Grid.tiles(POINTED_TILES)
	if near and _shown == null:
		_shown = Label.new()
		_shown.text = text
		_shown.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_shown.custom_minimum_size = Vector2(Grid.tiles(3.0), 0)
		_shown.add_theme_font_size_override("font_size", 40)
		_shown.add_theme_constant_override("outline_size", 10)
		_shown.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		_shown.position = Vector2(-Grid.tiles(1.5), -Grid.tiles(1.6))
		_shown.z_index = 50
		add_child(_shown)
		_mark_read()
	elif not near and _shown != null:
		_shown.queue_free()
		_shown = null


func interact(scene: Node):
	super(scene)
	_mark_read()


## Read, one way or the other: a secret is found.
func _mark_read():
	if _read:
		return
	_read = true
	if sets_flag != "":
		Campaign.set_flag(sets_flag, _flag_value_to_store())
	if secret and not is_found():
		Campaign.set_flag(found_flag())
		MapFeel.sound(&"secret_found", 0.0, 1.0, global_position)


func is_read() -> bool:
	return _read


func _draw():
	super()
	if texture == null and sprite_frames == null:
		# A scrap of paper pinned to the wall, with lines of writing.
		var tile := float(Grid.TILE_SIZE)
		var rect := Rect2(-tile * 0.18, -tile * 0.24, tile * 0.36, tile * 0.42)
		draw_rect(rect, Color("e8dcc0"))
		for i in 4:
			var y := rect.position.y + rect.size.y * (0.22 + 0.18 * i)
			draw_line(Vector2(rect.position.x + 6, y), Vector2(rect.end.x - 6 - (i % 2) * 14, y), Color("5a4a36"), 3.0)
		draw_rect(rect, Color("5a4a36"), false, 3.0)
		draw_circle(Vector2(0, rect.position.y + 6), 5.0, Color("b0443a"))
