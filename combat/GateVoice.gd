extends Node
class_name GateVoice
## A gate that speaks as it opens (the proposals of 2026-11-19, "Struck-out words"; the designer: "Do all"): the first time in a run
## that one of the party casts through a gate, a cold, official line across the top of the screen, set apart by its type - capitals,
## spaced out, typed out a letter at a time - and a low tone (SoundBank "gate_voice"). Once a gate, kept in the flags ("gate_voice:"
## and the gate). The lines are placeholders for the designer's own. Never headless unless plays_headless. PROPOSAL.

## Gate -> its line. {name} is the gate's name.
const LINES := {
	1: "ENTRY RECORDED.  {name}.  PROCEED.",
	2: "{name}.  YOUR PASSAGE IS NOTED.",
	3: "{name}.  WHAT IS OPENED IS ACCOUNTED FOR.",
	4: "{name}.  THE FERRY KEEPS A LEDGER.",
	5: "{name}.  BELOW IS ALSO A PLACE.",
	6: "{name}.  THE BALANCE IS INFORMED.",
	7: "{name}.  WISDOM IS ON FILE.",
	8: "{name}.  THE EIGHTH SPHERE ACKNOWLEDGES YOU.",
	9: "{name}.  KNOWING IS NOT PERMITTED.  NOTED.",
	10: "{name}.  YOU ARE EXPECTED.",
}
const TYPE_SECONDS := 1.4
const HOLD_SECONDS := 2.6
const FADE_SECONDS := 0.8

static var plays_headless := false
## For a suite: what was last said.
static var last_said := ""


## The first casting through `gate` in this run speaks; any after it says nothing.
static func speak(host: Node, gate: int):
	if gate <= 0 or gate >= Stats.GATE_NAMES.size():
		return
	var flag := "gate_voice:%d" % gate
	if Campaign.flag(flag):
		return
	Campaign.set_flag(flag)
	var gate_name: String = Stats.GATE_NAMES[gate].to_upper()
	last_said = String(LINES.get(gate, "{name}.")).format({"name": gate_name})
	if (DisplayServer.get_name() == "headless" and not plays_headless) or host == null or not host.is_inside_tree():
		return
	MapFeel.sound(&"gate_voice", -4.0)
	var layer := CanvasLayer.new()
	layer.layer = 22
	host.get_tree().root.add_child(layer)
	var line := Label.new()
	line.text = " ".join(last_said.split(""))
	line.add_theme_font_size_override("font_size", 20)
	line.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0))
	line.add_theme_constant_override("outline_size", 6)
	line.add_theme_color_override("font_outline_color", Color(0.0, 0.02, 0.08, 0.9))
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.set_anchors_preset(Control.PRESET_TOP_WIDE)
	line.offset_top = 70
	line.visible_ratio = 0.0
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(line)
	var tween := line.create_tween().set_ignore_time_scale(true)
	tween.tween_property(line, "visible_ratio", 1.0, TYPE_SECONDS)
	tween.tween_interval(HOLD_SECONDS)
	tween.tween_property(line, "modulate:a", 0.0, FADE_SECONDS)
	tween.tween_callback(layer.queue_free)
