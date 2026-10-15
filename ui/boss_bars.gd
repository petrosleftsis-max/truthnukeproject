extends PanelContainer
class_name BossBars
## The bosses on the field, along the top of the screen (Combat's "Bosses"):
## each one's name and title, its health with a mark where each of its phases
## begins, and - for a boss with one - its stagger bar under that, with the
## fight's hint for filling it. There from the moment a boss is announced, gone
## when it falls.

const WIDTH := 540.0
const TOP := 10.0
const HEALTH_HEIGHT := 14.0
const STAGGER_HEIGHT := 9.0
const NAME_COLOUR := Color("ff8a5c")
const TITLE_COLOUR := Color("b9c4d0")
const PHASE_COLOUR := Color("ffb38a")
const HEALTH_FILL := Color("c0392b")
const STAGGER_FILL := Color("e8b84a")
const STAGGERED_FILL := Color("fff1b8")

var _rows: VBoxContainer = null
## Each boss's row, by combatant id.
var _by_id := {}


func _init():
	name = "BossBars"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var band := StyleBoxFlat.new()
	band.bg_color = Color(0.06, 0.08, 0.11, 0.9)
	band.border_color = Color("8a3a2a")
	band.set_border_width_all(1)
	band.set_corner_radius_all(4)
	band.content_margin_left = 14
	band.content_margin_right = 14
	band.content_margin_top = 6
	band.content_margin_bottom = 8
	add_theme_stylebox_override("panel", band)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 8)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rows)


## Shows a row for every boss in `combatants` that has been announced and is
## standing, and none for anybody else.
func show_for(combatants: Array, combat):
	var wanted := {}
	for comb in combatants:
		if comb.get("alive", false) and comb.has("boss") and comb.get("announced", false):
			wanted[comb.get("id", -1)] = comb
	for id in _by_id.keys():
		if not wanted.has(id):
			_by_id[id].queue_free()
			_by_id.erase(id)
	for id in wanted:
		if not _by_id.has(id):
			_by_id[id] = _make_row(wanted[id])
		_fill(_by_id[id], wanted[id], combat)
	visible = not wanted.is_empty()
	if visible:
		custom_minimum_size.x = WIDTH
		reset_size()
		var screen := get_viewport_rect().size
		position = Vector2(roundf((screen.x - size.x) * 0.5), TOP)


## The row for the boss whose id is `id`, or null.
func row_for(id: int) -> Control:
	return _by_id.get(id)


func _make_row(comb: Dictionary) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.name = "Boss%d" % comb.get("id", -1)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 3)
	_rows.add_child(row)
	var top := HBoxContainer.new()
	top.name = "Top"
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 10)
	row.add_child(top)
	top.add_child(_label("Name", 19, NAME_COLOUR, true))
	top.add_child(_label("Title", 13, TITLE_COLOUR))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(gap)
	top.add_child(_label("Phase", 13, PHASE_COLOUR))
	top.add_child(_label("Health", 13, TITLE_COLOUR))
	var health := Gauge.new()
	health.name = "HealthBar"
	health.fill = HEALTH_FILL
	health.custom_minimum_size = Vector2(0, HEALTH_HEIGHT)
	row.add_child(health)
	var stagger_row := HBoxContainer.new()
	stagger_row.name = "Stagger"
	stagger_row.add_theme_constant_override("separation", 8)
	stagger_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(stagger_row)
	stagger_row.add_child(_label("Word", 12, STAGGER_FILL))
	var stagger := Gauge.new()
	stagger.name = "StaggerBar"
	stagger.fill = STAGGER_FILL
	stagger.custom_minimum_size = Vector2(0, STAGGER_HEIGHT)
	stagger.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stagger.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Hovered, it says how it fills and what a full one does.
	stagger.mouse_filter = Control.MOUSE_FILTER_STOP
	stagger_row.add_child(stagger)
	var hint := _label("Hint", 12, TITLE_COLOUR)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Wrapped to the bar's width: left to itself, a wrapping label works out its
	# height at no width at all, a letter a line.
	hint.custom_minimum_size.x = WIDTH - 28.0
	row.add_child(hint)
	return row


func _fill(row: VBoxContainer, comb: Dictionary, combat):
	var boss: BossDefinition = comb.boss
	var top := row.get_node("Top")
	top.get_node("Name").text = comb.name
	top.get_node("Title").text = boss.title
	top.get_node("Phase").text = comb.get("phase_name", "")
	var most: int = combat.get_effective_stat(comb, "max_hp") if combat != null else comb.get("max_hp", 1)
	top.get_node("Health").text = "%d / %d" % [maxi(comb.hp, 0), most]
	var health: Gauge = row.get_node("HealthBar")
	health.value = float(comb.hp) / float(maxi(most, 1))
	health.marks = boss.phases_in_order().map(func(phase): return phase.at_health)
	health.queue_redraw()
	var bar: StaggerDefinition = comb.get("stagger_def")
	var stagger_row := row.get_node("Stagger")
	var hint: Label = row.get_node("Hint")
	stagger_row.visible = bar != null
	hint.visible = bar != null and bar.hint != ""
	if bar == null:
		return
	var staggered: bool = combat != null and combat.is_staggered(comb)
	var gauge: Gauge = stagger_row.get_node("StaggerBar")
	gauge.value = 1.0 if staggered else comb.get("stagger", 0.0) / maxf(comb.get("stagger_max", 1.0), 1.0)
	gauge.fill = STAGGERED_FILL if staggered else STAGGER_FILL
	gauge.tooltip_text = TooltipText.wrap(bar.describe())
	gauge.queue_redraw()
	stagger_row.get_node("Word").text = "STAGGERED" if staggered else "Stagger"
	hint.text = bar.hint


func _label(called: String, font_size: int, colour: Color, heading: bool = false) -> Label:
	var label := Label.new()
	label.name = called
	if heading:
		label.theme_type_variation = GameFonts.HEADER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## A bar: dark, filled from the left to `value` (0 to 1), with a tick at each of
## `marks` - where a boss's phases begin.
class Gauge extends Control:
	var value := 0.0
	var fill := Color.RED
	var marks: Array = []

	func _draw():
		var whole := Rect2(Vector2.ZERO, size)
		draw_rect(whole, Color(0.04, 0.05, 0.07, 0.95))
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * clampf(value, 0.0, 1.0), size.y)), fill)
		for mark in marks:
			var x: float = size.x * clampf(mark, 0.0, 1.0)
			draw_line(Vector2(x, -2.0), Vector2(x, size.y + 2.0), Color(1, 1, 1, 0.85), 2.0)
		draw_rect(whole, Color(0.35, 0.42, 0.52, 0.9), false, 1.0)
