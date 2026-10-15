extends PanelContainer
class_name BossBanner
## A boss's name brought up across the middle of the screen as it appears, and
## a phase's under it as one begins - or "Staggered!" (Combat._banner): a dark
## band the width of the screen, the name large in Cinzel, the line under it
## smaller, coming in a little larger than it settles and going after a moment.
## It takes no input and holds nothing up: the fight carries on under it.

const FADE_IN := 0.35
const HOLD := 1.8
const FADE_OUT := 0.6
## Where the band's middle sits, as a share of the screen's height.
const HEIGHT_AT := 0.38

var _title: Label = null
var _subtitle: Label = null
var _tween: Tween = null


func _init():
	name = "BossBanner"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var band := StyleBoxFlat.new()
	band.bg_color = Color(0.03, 0.04, 0.06, 0.82)
	band.border_color = Color("8a3a2a")
	band.border_width_top = 2
	band.border_width_bottom = 2
	band.content_margin_top = 18
	band.content_margin_bottom = 20
	add_theme_stylebox_override("panel", band)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	add_child(column)
	_title = _line(52)
	column.add_child(_title)
	_subtitle = _line(24)
	column.add_child(_subtitle)


func _line(font_size: int) -> Label:
	var label := Label.new()
	label.theme_type_variation = GameFonts.HEADER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	label.add_theme_constant_override("outline_size", 6)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Brings `title` up with `subtitle` under it ("" for none), in `colour`.
func announce(title: String, subtitle: String, colour: Color):
	if not is_inside_tree():
		return
	_title.text = title
	_title.add_theme_color_override("font_color", colour)
	_subtitle.text = subtitle
	_subtitle.add_theme_color_override("font_color", colour.lightened(0.35))
	_subtitle.visible = subtitle != ""
	visible = true
	var screen := get_viewport_rect().size
	custom_minimum_size.x = screen.x
	reset_size()
	position = Vector2(0.0, roundf(screen.y * HEIGHT_AT - size.y * 0.5))
	pivot_offset = size * 0.5
	if _tween != null and _tween.is_valid():
		_tween.kill()
	modulate.a = 0.0
	scale = Vector2(1.08, 1.08)
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN)
	_tween.tween_property(self, "scale", Vector2.ONE, FADE_IN * 1.4).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_interval(HOLD)
	_tween.chain().tween_property(self, "modulate:a", 0.0, FADE_OUT)
	_tween.chain().tween_callback(func(): visible = false)


## What is on it right now - "Name | line" - or "" when it is not showing.
func showing() -> String:
	if not visible:
		return ""
	return _title.text + (" | " + _subtitle.text if _subtitle.text != "" else "")
