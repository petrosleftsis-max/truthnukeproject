extends PanelContainer
class_name TurnBanner
## "Cyrus's Turn" across the top of the screen for a moment whenever the turn
## passes. The turn queue has always said whose turn it is, but only to
## somebody reading it; this says it to somebody looking at the map.

const FADE_IN := 0.15
const HOLD := 0.9
const FADE_OUT := 0.35
## How far below the top of the screen it sits - under the turn queue.
const TOP := 92.0

var _label: Label = null
var _tween: Tween = null


func _init():
	name = "TurnBanner"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var band := StyleBoxFlat.new()
	band.bg_color = Color(0.098, 0.129, 0.173, 0.92)
	band.border_color = Color("4a86c8")
	band.border_width_top = 1
	band.border_width_bottom = 1
	band.content_margin_left = 40
	band.content_margin_right = 40
	band.content_margin_top = 6
	band.content_margin_bottom = 8
	add_theme_stylebox_override("panel", band)
	_label = Label.new()
	_label.theme_type_variation = GameFonts.HEADER
	_label.add_theme_font_size_override("font_size", 30)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


## Says `text` for a moment, in `colour`.
func announce(text: String, colour: Color):
	if not is_inside_tree():
		return
	_label.text = text
	_label.add_theme_color_override("font_color", colour)
	visible = true
	reset_size()
	var screen = get_viewport_rect().size
	global_position = Vector2((screen.x - size.x) * 0.5, TOP)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN)
	_tween.tween_interval(HOLD)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT)
	_tween.tween_callback(func(): visible = false)


## Takes it away at once - for placing the party, which the first turn's
## banner would otherwise sit over.
func dismiss():
	if _tween != null and _tween.is_valid():
		_tween.kill()
	visible = false


## What is on it right now, or "" when it is not showing.
func showing() -> String:
	return _label.text if visible else ""
