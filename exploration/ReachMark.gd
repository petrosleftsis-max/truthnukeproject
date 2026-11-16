extends Node2D
class_name ReachMark
## "In reach, it shows" (the proposals of 2026-11-16, section 3; the designer, 2026-11-17). The thing the interact key would use
## right now gets a soft outline, and its prompt - the key and the word - slides in beside it. One of these belongs to the map
## (ExplorationScene._update_prompt tells it); it draws nothing with nothing in reach.
##
## Only to look at. The outline goes round what the thing says it covers (`reach_rect()`, in its own space: a door standing says
## its whole height), else its picture, else its tile. Numbers PROPOSAL.

const TINT := Color(1.0, 0.93, 0.74)
const SLIDE_SECONDS := 0.14
const SLIDE_PIXELS := 16.0
const PULSE_SECONDS := 1.6
## How thick the outline is on the screen, in pixels, whatever the zoom.
const LINE_PIXELS := 2.5
const CHIP_GAP := 12.0

var target: Node2D = null
var _text := ""
var _key := ""
var _since := 0.0
var _layer: CanvasLayer = null
var _chip: PanelContainer = null
var _key_label: Label = null
var _word_label: Label = null
## How many times something came into reach, for a suite.
var shown_times := 0


func _ready():
	z_as_relative = false
	z_index = ExplorationParty.PARTY_Z_TOP + 4
	_layer = CanvasLayer.new()
	_layer.layer = 1
	add_child(_layer)
	_chip = PanelContainer.new()
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.07, 0.11, 0.86)
	box.border_color = Color(TINT, 0.55)
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	box.content_margin_left = 8
	box.content_margin_right = 10
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	_chip.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_key_label = Label.new()
	_key_label.add_theme_font_size_override("font_size", 15)
	_key_label.add_theme_color_override("font_color", Color(0.05, 0.07, 0.11))
	var cap := StyleBoxFlat.new()
	cap.bg_color = TINT
	cap.set_corner_radius_all(4)
	cap.content_margin_left = 6
	cap.content_margin_right = 6
	_key_label.add_theme_stylebox_override("normal", cap)
	row.add_child(_key_label)
	_word_label = Label.new()
	_word_label.add_theme_font_size_override("font_size", 15)
	_word_label.add_theme_color_override("font_color", Color(0.93, 0.95, 0.98))
	row.add_child(_word_label)
	_chip.add_child(row)
	_chip.visible = false
	_layer.add_child(_chip)


## Shows `thing` as in reach, to be used with `key` to do `word` - or nothing, with null.
func show_on(thing: Node2D, key: String = "", word: String = ""):
	if thing == target and key == _key and word == _text:
		return
	var new_thing := thing != target
	target = thing
	_key = key
	_text = word
	if thing == null:
		_chip.visible = false
		queue_redraw()
		return
	if new_thing:
		_since = 0.0
		shown_times += 1
	_key_label.text = key
	_word_label.text = word.capitalize() if word == word.to_lower() else word
	_chip.visible = visible and word != ""
	_chip.reset_size()
	queue_redraw()


## What the outline goes round, in the world.
func outline() -> Rect2:
	if target == null or not is_instance_valid(target):
		return Rect2()
	var rect := Rect2(-Vector2.ONE * Grid.TILE_SIZE * 0.5, Vector2.ONE * Grid.TILE_SIZE)
	if target.has_method("reach_rect"):
		rect = target.reach_rect()
	elif target.get("texture") != null:
		var size: Vector2 = target.texture.get_size()
		rect = Rect2(-size * 0.5, size)
	rect.position *= target.global_scale
	rect.size *= target.global_scale
	rect.position += target.global_position
	return rect.grow(Grid.TILE_SIZE * 0.04)


func _process(delta: float):
	if target != null and not is_instance_valid(target):
		show_on(null)
	_chip.visible = visible and target != null and _text != ""
	if target == null:
		return
	_since += delta
	var rect := outline()
	var to_screen := get_viewport().get_canvas_transform()
	# Beside it, to the east and level with its top; on the other side when that would leave the screen.
	var slide := 1.0 - clampf(_since / SLIDE_SECONDS, 0.0, 1.0)
	var at: Vector2 = to_screen * Vector2(rect.end.x, rect.position.y) + Vector2(CHIP_GAP + SLIDE_PIXELS * slide * slide, 0.0)
	var screen: Vector2 = get_viewport().get_visible_rect().size
	if at.x + _chip.size.x > screen.x - 8.0:
		at.x = (to_screen * rect.position).x - CHIP_GAP - _chip.size.x - SLIDE_PIXELS * slide * slide
	at.y = clampf(at.y, 8.0, screen.y - _chip.size.y - 8.0)
	_chip.position = at.round()
	_chip.modulate.a = 1.0 - slide
	queue_redraw()


func _draw():
	if target == null or not is_instance_valid(target):
		return
	var rect := outline()
	rect.position = to_local(rect.position)
	var zoom: float = maxf(get_viewport().get_canvas_transform().get_scale().x, 0.001)
	var line := LINE_PIXELS / zoom
	var arrive := clampf(_since / SLIDE_SECONDS, 0.0, 1.0)
	var pulse := 0.75 + 0.25 * sin(_since * TAU / PULSE_SECONDS)
	# A soft outline: a wide faint one under a thin bright one, rounded, a little larger as it arrives.
	rect = rect.grow((1.0 - arrive) * 10.0 / zoom)
	for pass_at in [[4.0, 0.1], [2.2, 0.2], [1.0, 0.8]]:
		var box := StyleBoxFlat.new()
		box.draw_center = false
		box.border_color = Color(TINT, float(pass_at[1]) * pulse * arrive)
		box.set_border_width_all(maxi(roundi(line * float(pass_at[0])), 1))
		box.set_corner_radius_all(roundi(Grid.TILE_SIZE * 0.08))
		box.anti_aliasing = true
		box.draw(get_canvas_item(), rect.grow(line * float(pass_at[0]) * 0.5))
