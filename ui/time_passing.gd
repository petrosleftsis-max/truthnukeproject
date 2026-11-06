extends CanvasLayer
class_name TimePassing
## Time seen passing, fast (Campaign.watch_time_pass; the designer, 2026-11-07: "allow the smooth
## transition as we see time pass faster from one point to another, but not necessarily always"). The clock
## runs from where it is by `minutes` over `seconds`, easing in and out, so the light, the shadows and
## the tone of the hour all go round with it. A big clock and the date stand in the middle of the screen
## meanwhile. Nothing here decides anything. A placeholder look.

signal finished

const INK := Color("dce8f5")
const MUTED := Color("a9b8c7")
const FADE_SECONDS := 0.3

var minutes := 0
var seconds := 5.0

var _from := 0
var _elapsed := 0.0
var _clock: Label = null
var _date: Label = null
var _holder: VBoxContainer = null


func _ready():
	name = "TimePassing"
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_from = Campaign.calendar_minutes
	Campaign.time_passing = true
	_holder = VBoxContainer.new()
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_theme_constant_override("separation", 2)
	_holder.modulate.a = 0.0
	add_child(_holder)
	_clock = Label.new()
	_clock.name = "Clock"
	_clock.theme_type_variation = GameFonts.HEADER
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock.add_theme_font_size_override("font_size", 54)
	_clock.add_theme_color_override("font_color", INK)
	_clock.add_theme_color_override("font_outline_color", Color.BLACK)
	_clock.add_theme_constant_override("outline_size", 8)
	_holder.add_child(_clock)
	_date = Label.new()
	_date.name = "Date"
	_date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_date.add_theme_font_size_override("font_size", 20)
	_date.add_theme_color_override("font_color", MUTED)
	_date.add_theme_color_override("font_outline_color", Color.BLACK)
	_date.add_theme_constant_override("outline_size", 6)
	_holder.add_child(_date)
	_say()


func _process(delta: float):
	_elapsed += delta
	var share: float = clampf(_elapsed / maxf(seconds, 0.01), 0.0, 1.0)
	var eased := smoothstep(0.0, 1.0, share)
	Campaign.clock_to(_from + roundi(float(minutes) * eased))
	_say()
	_holder.modulate.a = clampf(minf(_elapsed, seconds - _elapsed) / FADE_SECONDS, 0.0, 1.0)
	_holder.reset_size()
	_holder.position = Vector2((_holder.get_viewport_rect().size.x - _holder.size.x) / 2.0, _holder.get_viewport_rect().size.y * 0.16).round()
	if share >= 1.0:
		_done()


func _say():
	_clock.text = Campaign.clock_text()
	_date.text = "Day %d    %s" % [Campaign.day_number(), Campaign.date_text()]


func _done():
	Campaign.time_passing = false
	finished.emit()
	queue_free()


func _exit_tree():
	Campaign.time_passing = false
