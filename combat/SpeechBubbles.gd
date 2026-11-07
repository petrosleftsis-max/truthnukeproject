extends CanvasLayer
class_name SpeechBubbles
## A line in a bubble over somebody's head, gone by itself (the designer, 2026-11-07, section 15 of docs/proposals_2026-11-07.md, in place of a
## tally of commendations). Only to look at: nothing here decides anything or rolls on Combat.rng, and which line comes up may differ from
## one machine to the other. Headless nothing is made (plays_headless), nor while a fight is being caught up on.
##
## In a fight: on_event, from Combat, says whatever the creature's CombatLines has for the moment, now and then. In a conversation:
## `do Campaign.say_bubble("enfina", "Keep up.")`, on a map or in a fight. One placed by hand: say_over.

const LAYER := 6
const WIDTH := 260.0
## How long one stays: this long, and this much for each letter, up to the most.
const SECONDS_AT_LEAST := 1.8
const SECONDS_A_LETTER := 0.045
const SECONDS_AT_MOST := 5.0
const FADE_SECONDS := 0.25
## So that nobody chatters: how long after a line they say another.
const QUIET_FOR_MS := 7000
## How often each moment comes to anything. Those not named here always do.
const CHANCES := {&"first_blow": 0.6, &"fells_somebody": 0.7, &"badly_hurt": 0.8, &"healed": 0.5, &"reacts": 0.4, &"using": 0.7,
	&"afflicted": 0.5, &"studies": 0.5, &"seen_through": 0.8, &"deep_spell": 0.8}
## Those that are said whoever spoke a moment ago.
const WONT_WAIT := [&"ally_falls", &"won", &"phase", &"takes_a_blow"]
const INK := Color("eef4fb")
const BACK := Color(0.07, 0.09, 0.12, 0.94)
const PARTY_EDGE := Color("7fb4ea")
const FOE_EDGE := Color("e08a8a")
const OTHER_EDGE := Color("b8c6d6")

static var plays_headless := false
## Every moment comes to something, for a test.
static var always := false
## What has been said, for a test: {"who", "line", "event"}.
static var said: Array = []
static var _here: SpeechBubbles = null
static var _last_at := {}
static var _next_of := {}

var _on_figure := {}


static func shown() -> bool:
	return plays_headless or MoveFeel.shown()


## Forgets who has spoken, for a new start.
static func forget():
	said = []
	_last_at = {}
	_next_of = {}


## `event` has happened to or by `comb`: they say something about it, if they have anything and it is the moment. True if they did.
static func on_event(combat: Combat, comb: Dictionary, event: StringName, about: String = "") -> bool:
	if not shown() or comb.is_empty() or not comb.get("alive", false):
		return false
	var definition = CombatantDatabase.combatants.get(comb.get("combatant_key", ""))
	if definition == null or definition.lines == null:
		return false
	var lines: Array = definition.lines.lines_for(event, about)
	if lines.is_empty():
		return false
	if not always and randf() > float(CHANCES.get(event, 1.0)):
		return false
	var id: int = comb.get("id", -1)
	var now := Time.get_ticks_msec()
	if not always and not WONT_WAIT.has(event) and now - int(_last_at.get(id, -QUIET_FOR_MS)) < QUIET_FOR_MS:
		return false
	var key := "%s:%s:%s" % [comb.get("combatant_key", ""), event, about]
	var turn: int = _next_of.get(key, randi() % lines.size())
	_next_of[key] = turn + 1
	if not say_line(combat, comb, String(lines[turn % lines.size()])):
		return false
	_last_at[id] = now
	said.append({"who": comb.get("combatant_key", ""), "line": lines[turn % lines.size()], "event": event})
	return true


## One of those in the fight who have a line for `event` says it (as it starts, as it is won). Which of them doesn't matter to anything.
static func somebody_says(combat: Combat, event: StringName):
	if not shown():
		return
	var those: Array = combat.combatants.filter(func(comb): return comb.get("alive", false) and not comb.has("object") and not comb.get("illusion", false))
	those.shuffle()
	for comb in those:
		if on_event(combat, comb, event):
			return


## `line` over `comb`, unless nobody can see them. True if it was said.
static func say_line(combat: Combat, comb: Dictionary, line: String) -> bool:
	if not shown() or comb.is_empty() or combat == null or combat.unseen_by_party(comb):
		return false
	var figure = comb.get("sprite")
	if figure == null or not is_instance_valid(figure):
		return false
	var edge: Color = PARTY_EDGE if comb.get("side", 0) == 0 else FOE_EDGE
	say_over(combat.get_tree(), figure, line, edge)
	return true


## `line` over `figure`, wherever it goes, until it is done.
static func say_over(tree: SceneTree, figure: Node2D, line: String, edge: Color = OTHER_EDGE):
	if not shown() or tree == null or figure == null or not is_instance_valid(figure):
		return
	if _here == null or not is_instance_valid(_here):
		_here = SpeechBubbles.new()
		_here.name = "SpeechBubbles"
		_here.layer = LAYER
		tree.root.add_child(_here)
	_here._say(figure, line, edge)


## The bubble over `figure` now, or null, for a test.
static func bubble_over(figure: Node2D):
	return _here._on_figure.get(figure) if _here != null and is_instance_valid(_here) else null


func _say(figure: Node2D, line: String, edge: Color):
	var old = _on_figure.get(figure)
	if old != null and is_instance_valid(old):
		old.queue_free()
	var bubble := _Bubble.new()
	bubble.figure = figure
	bubble.text = line
	bubble.edge = edge
	bubble.seconds = clampf(SECONDS_AT_LEAST + SECONDS_A_LETTER * float(line.length()), SECONDS_AT_LEAST, SECONDS_AT_MOST)
	add_child(bubble)
	_on_figure[figure] = bubble
	for each in _on_figure.keys():
		if not is_instance_valid(each) or not is_instance_valid(_on_figure[each]):
			_on_figure.erase(each)


class _Bubble extends Control:
	var figure: Node2D = null
	var text := ""
	var edge := SpeechBubbles.OTHER_EDGE
	var seconds := 2.0
	var _age := 0.0
	var _label: Label = null

	func _ready():
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label = Label.new()
		_label.text = text
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.add_theme_font_size_override("font_size", 14)
		_label.add_theme_color_override("font_color", SpeechBubbles.INK)
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.custom_minimum_size.x = minf(SpeechBubbles.WIDTH, 40.0 + float(text.length()) * 8.0)
		add_child(_label)
		_label.position = Vector2(10.0, 6.0)
		scale = Vector2.ONE * GameSettings.ui_scale()
		_place()

	func _process(delta: float):
		_age += delta
		if figure == null or not is_instance_valid(figure) or _age >= seconds:
			queue_free()
			return
		modulate.a = clampf(minf(_age, seconds - _age) / SpeechBubbles.FADE_SECONDS, 0.0, 1.0)
		_place()
		queue_redraw()

	## Over their head, and on the screen.
	func _place():
		if figure == null or not is_instance_valid(figure):
			return
		var height: float = figure.head_height() if figure.has_method("head_height") else 0.0
		var head: Vector2 = figure.global_position + Vector2(0.0, -height - float(Grid.TILE_SIZE) * 0.42)
		var at: Vector2 = figure.get_viewport().get_canvas_transform() * head
		var box: Vector2 = _box()
		var screen: Vector2 = get_viewport_rect().size
		position = Vector2(clampf(at.x - box.x * scale.x / 2.0, 4.0, maxf(screen.x - box.x * scale.x - 4.0, 4.0)),
			clampf(at.y - (box.y + 10.0) * scale.y, 4.0, maxf(screen.y - box.y * scale.y - 4.0, 4.0)))

	func _box() -> Vector2:
		return _label.get_combined_minimum_size() + Vector2(20.0, 12.0) if _label != null else Vector2(40.0, 24.0)

	func _draw():
		var box := _box()
		var style := StyleBoxFlat.new()
		style.bg_color = SpeechBubbles.BACK
		style.border_color = edge
		style.set_border_width_all(1)
		style.set_corner_radius_all(8)
		draw_style_box(style, Rect2(Vector2.ZERO, box))
		var middle: float = box.x / 2.0
		draw_colored_polygon(PackedVector2Array([Vector2(middle - 7.0, box.y - 1.0), Vector2(middle + 7.0, box.y - 1.0), Vector2(middle, box.y + 9.0)]), SpeechBubbles.BACK)
		draw_line(Vector2(middle - 7.0, box.y), Vector2(middle, box.y + 9.0), edge, 1.0, true)
		draw_line(Vector2(middle + 7.0, box.y), Vector2(middle, box.y + 9.0), edge, 1.0, true)
