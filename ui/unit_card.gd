extends PanelContainer
class_name UnitCard
## A small card beside the cursor naming whoever is under it on the map: who,
## how they are doing, and what is on them. Hovering somebody used to say
## nothing at all - this is the glance before the character sheet's read.
##
## Nobody hidden from the player is ever shown: the map does not draw them, and
## a card would say exactly where they stand.

const OFFSET := Vector2(22, 22)
const ALLY := Color("7fb4ea")
const ENEMY := Color("e08a8a")
const INK := Color("dce8f5")
const MUTED := Color("8296a9")
## The health bar colours of the portraits and the turn queue.
const HEALTH_FULL := Color("6fb26a")
const HEALTH_HURT := Color("c8913f")
const HURT_BELOW := 0.34

var _rows: VBoxContainer = null
var shown_id := -1


func _init():
	name = "UnitCard"
	theme_type_variation = &"TooltipPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 3)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rows)


## Shows `comb`, beside the cursor.
func show_for(comb: Dictionary, combat: Combat):
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	shown_id = comb.get("id", -1)
	var ally = comb.side == 0
	var title := _label(comb.name, 17, ALLY if ally else ENEMY)
	title.theme_type_variation = GameFonts.HEADER
	_rows.add_child(title)
	var most = combat.get_effective_stat(comb, "max_hp")
	_rows.add_child(_label("Level %d     %d / %d HP" % [comb.get("level", 1), comb.hp, most], 14, INK))
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(170, 6)
	bar.show_percentage = false
	bar.max_value = maxi(most, 1)
	bar.value = clampi(comb.hp, 0, maxi(most, 1))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Green, amber below a third - the colours every other health bar uses.
	var fill := StyleBoxFlat.new()
	fill.bg_color = HEALTH_FULL if float(comb.hp) / float(maxi(most, 1)) > HURT_BELOW else HEALTH_HURT
	bar.add_theme_stylebox_override("fill", fill)
	_rows.add_child(bar)
	# What is on them, named and tinted the way their marks are - the sheet
	# and the marks' own tooltips say what each one means.
	var on_them := HFlowContainer.new()
	on_them.add_theme_constant_override("h_separation", 8)
	on_them.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if combat.is_hidden(comb):
		on_them.add_child(_label("Hidden", 13, ConditionStrip.HELPFUL))
	var reader := ConditionStrip.new()
	for state in reader.states_of(comb, combat):
		on_them.add_child(_label(state.text.split("\n")[0], 13,
			ConditionStrip.HELPFUL if state.helpful else ConditionStrip.HARMFUL))
	reader.free()
	if on_them.get_child_count() > 0:
		_rows.add_child(on_them)
	else:
		on_them.free()
	visible = true
	reset_size()
	place()


func hide_card():
	visible = false
	shown_id = -1


## Beside the cursor, and on the screen: it flips to the cursor's other side
## rather than running off an edge.
func place():
	if not visible or not is_inside_tree():
		return
	var screen = get_viewport_rect().size
	var mouse = get_viewport().get_mouse_position()
	var size_now = get_combined_minimum_size()
	var at = mouse + OFFSET
	if at.x + size_now.x > screen.x:
		at.x = mouse.x - OFFSET.x - size_now.x
	if at.y + size_now.y > screen.y:
		at.y = mouse.y - OFFSET.y - size_now.y
	global_position = at.clamp(Vector2.ZERO, (screen - size_now).max(Vector2.ZERO))


func _label(text: String, size_px: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
