class_name TooltipText
## Tooltips that fit on the screen.
##
## Godot's own tooltip is a Label that never wraps, so each line is exactly as
## wide as it is long - and a skill's description is written as a sentence or
## three on one line. Study's ran off both sides of the screen. Anything written
## at length goes through here on its way into tooltip_text, and comes out
## broken at the spaces into lines no wider than MAX_WIDTH, measured in the font
## the tooltip is actually drawn in.
##
## Only for showing. What build_skill_tooltip and the like hand back stays one
## line per thought, so nothing reading them - the tests least of all - meets a
## phrase split across two lines.


## Wide enough for a whole stat line, narrow enough to leave most of the battle
## showing beside it.
const MAX_WIDTH := 420.0

## An effect listed as "- ..." carries on indented under itself, so a wrapped
## effect still reads as one effect rather than as two.
const BULLET := "- "
const HANGING_INDENT := "  "

static var _font: Font = null
static var _font_size := 0


## `text` with every line longer than `max_width` broken into several. Lines
## already short enough, blank ones included, are left exactly as they were.
static func wrap(text: String, max_width: float = MAX_WIDTH) -> String:
	var wrapped: PackedStringArray = []
	for line in text.split("\n"):
		wrapped.append_array(_wrap_line(line, max_width))
	return "\n".join(wrapped)


## How wide `line` is drawn in a tooltip.
static func width_of(line: String) -> float:
	_learn_font()
	return _font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x


static func _wrap_line(line: String, max_width: float) -> PackedStringArray:
	var lines: PackedStringArray = []
	if width_of(line) <= max_width:
		lines.append(line)
		return lines
	var indent = HANGING_INDENT if line.begins_with(BULLET) else ""
	var current := ""
	for word in line.split(" ", false):
		var longer = word if current == "" else current + " " + word
		if current != "" and current != indent and width_of(longer) > max_width:
			lines.append(current)
			current = indent + word
		else:
			current = longer
	if current != "":
		lines.append(current)
	return lines


## The font and size a tooltip's label resolves to, asked of a label dressed
## the way Godot dresses its own - so a theme that ever sets one is followed
## without this needing to be told.
static func _learn_font():
	if _font != null:
		return
	var probe := Label.new()
	probe.theme_type_variation = &"TooltipLabel"
	_font = probe.get_theme_font(&"font")
	_font_size = probe.get_theme_font_size(&"font_size")
	probe.free()
