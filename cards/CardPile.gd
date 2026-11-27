extends Control
class_name CardPile
## One of a fight's piles (the draw pile, the discard pile, the exhausted) as a small stack of card backs (CardLooks' card_back) that
## grows and shrinks with it, its count on it and its name under it (docs/card_game.md "How it feels"). Pressed, it says so, for the
## screen to show what is in it.

signal pressed

## A card of the stack, and how far each sits above the last.
const CARD := Vector2(54, 76)
const LAYER := Vector2(2.0, -2.5)
const LAYERS_MOST := 5

var count := 0
var _count_label: Label
var _name_label: Label


func _init():
	custom_minimum_size = Vector2(CARD.x + 16, CARD.y + 40)
	size = custom_minimum_size
	pivot_offset = Vector2(size.x / 2.0, CARD.y / 2.0 + 14)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_count_label = Label.new()
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count_label.add_theme_font_size_override("font_size", 18)
	_count_label.add_theme_color_override("font_color", Color.WHITE)
	_count_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_count_label.add_theme_constant_override("outline_size", 6)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_count_label)
	_name_label = Label.new()
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.add_theme_font_size_override("font_size", 12)
	_name_label.add_theme_color_override("font_color", Color("c2ceda"))
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.position = Vector2(0, CARD.y + 18)
	_name_label.size = Vector2(size.x, 18)
	add_child(_name_label)


func setup(title: String, tip: String) -> CardPile:
	_name_label.text = title
	tooltip_text = tip
	return self


## Now `how_many`; with a small pop when `animated`.
func set_count(how_many: int, animated: bool = true):
	var before := count
	count = maxi(how_many, 0)
	_count_label.text = str(count)
	var top_rect := _card_rect(maxi(clampi(count, 0, LAYERS_MOST) - 1, 0))
	_count_label.position = top_rect.get_center() - Vector2(18, 14)
	_count_label.size = Vector2(36, 28)
	queue_redraw()
	if animated and before != count and CardFeel.shown() and is_inside_tree():
		var tween := create_tween()
		tween.tween_property(self, "scale", Vector2.ONE * 1.08, 0.06)
		tween.tween_property(self, "scale", Vector2.ONE, 0.12)


## The middle of its top card, global: where a card flies to or from.
func top() -> Vector2:
	var layers := clampi(count, 1, LAYERS_MOST)
	return global_position + _card_rect(layers - 1).get_center()


func _card_rect(layer: int) -> Rect2:
	return Rect2(Vector2(8, 12) + LAYER * layer, CARD)


func _draw():
	var layers := clampi(count, 0, LAYERS_MOST)
	if layers == 0:
		var empty := StyleBoxFlat.new()
		empty.bg_color = Color(0, 0, 0, 0)
		empty.border_color = Color("2b3947")
		empty.set_border_width_all(2)
		empty.set_corner_radius_all(5)
		draw_style_box(empty, _card_rect(0))
	var back := CardLooks.picture(&"card_back")
	for layer in layers:
		var rect := _card_rect(layer)
		if back != null:
			draw_texture_rect(back, rect, false)
		else:
			CardIcon.stand_in(self, &"card_back", rect)


func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		accept_event()
		pressed.emit()
