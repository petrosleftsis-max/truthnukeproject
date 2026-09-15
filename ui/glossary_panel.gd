extends VBoxContainer
class_name GlossaryPanel
## The glossary: what the game's own words mean.
##
## Half of every page is written and half is read off the game itself. The
## prose lives in res://glossary/glossary_book.tres and, for the characters, on
## each CombatantDefinition; the numbers - a condition's duration, a gate's
## allowance per level, a skill's reach and cost - are taken from the same data
## the battle uses, so a page here cannot quietly disagree with the game it
## describes.
##
## Its own panel with its own little stack of views, rather than six more
## panels bolted onto the main menu: the menu hands it the screen, and gets it
## back when the reader runs out of Backs.


## Asked for when Back is pressed on the first screen - the menu takes the
## screen back from there.
signal closed()

const GLOSSARY_BOOK := "res://glossary/glossary_book.tres"
## Who the glossary introduces, in the order they turn up in the story.
const CAST := ["cyrus", "enfina", "prometheus", "alithia"]
## Said on every condition page, because the numbers on it are only the default
## ones - a skill is free to inflict the same condition differently.
const DEFAULTS_NOTE := "These are the defaults, and subject to change: a skill that inflicts this can carry its own duration, and any damage it deals scales with whoever inflicted it."

const INK := Color("dce8f5")
const INK_DIM := Color("c2ceda")
const MUTED := Color("8296a9")
const ACCENT := Color("4a86c8")
const CARD := Color("1c2531")
const CARD_LIT := Color("24344a")
const CARD_EDGE := Color("2b3947")

var _title: Label
var _blurb: Label
var _list: VBoxContainer
var _body: RichTextLabel
var _body_scroll: ScrollContainer
var _list_scroll: ScrollContainer
## Where Back goes, innermost last. Each entry is a Callable that redraws a view.
var _trail: Array[Callable] = []


func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 14)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 34)
	_title.add_theme_color_override("font_color", INK)
	add_child(_title)

	_blurb = Label.new()
	_blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_blurb.custom_minimum_size = Vector2(560, 0)
	_blurb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_blurb.add_theme_font_size_override("font_size", 14)
	_blurb.add_theme_color_override("font_color", MUTED)
	add_child(_blurb)

	_list_scroll = ScrollContainer.new()
	_list_scroll.custom_minimum_size = Vector2(320, 300)
	_list_scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.custom_minimum_size = Vector2(300, 0)
	_list_scroll.add_child(_list)
	add_child(_list_scroll)

	_body_scroll = ScrollContainer.new()
	_body_scroll.custom_minimum_size = Vector2(600, 320)
	_body_scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.custom_minimum_size = Vector2(580, 0)
	_body.add_theme_font_size_override("normal_font_size", 15)
	_body.add_theme_color_override("default_color", INK_DIM)
	_body_scroll.add_child(_body)
	add_child(_body_scroll)

	# Not remembered: Back is how you leave a view, not a view to arrive at.
	# Routed through _go_to like everything else, it pushed itself onto the
	# trail and then popped itself straight off again, landing exactly where it
	# started - which looked like a button that did nothing at all.
	var back := _button("Back", _go_back, false)
	back.custom_minimum_size = Vector2(180, 36)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(back)

	show_contents()


## Back to the first screen, for the menu to call when it opens the glossary
## fresh rather than resuming where the last reader left off.
func show_contents():
	_trail.clear()
	_go_to(_view_contents)


## --- The views ---


func _view_contents():
	var book := _book()
	_heading("Glossary", book.foreword if book != null else "")
	_offer([
		["Character intros", _view_cast],
		["Conditions", _view_conditions],
		["Gates", _view_gates],
		["Skills", _view_skills],
	])


func _view_cast():
	var book := _book()
	_heading("Character intros", book.cast_intro if book != null else "")
	var entries := []
	for key in CAST:
		var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
		if definition == null:
			continue
		entries.append([definition.name, _page_for_character.bind(key)])
	_offer(entries)


func _view_conditions():
	var book := _book()
	_heading("Conditions", book.conditions_intro if book != null else "")
	var entries := []
	for condition in conditions():
		entries.append([_condition_name(condition), _page_for_condition.bind(condition)])
	_offer(entries)


## One page rather than three buttons: the gates are a single idea explained
## together - what they are, how they are spent, and how the three of them
## differ - and splitting that across three entries made the reader assemble it.
func _view_gates():
	var book := _book()
	var written = book.gates if book != null else ""
	_read("The Gates", written if written != "" else _unwritten("glossary/glossary_book.tres"))


func _view_skills():
	var book := _book()
	_heading("Skills", book.skills_intro if book != null else "")
	var named := []
	for key in SkillDatabase.skills:
		var skill: SkillDefinition = SkillDatabase.skills[key]
		# Consumables are things you carry, not things you know how to do.
		if skill == null or skill is ItemDefinition:
			continue
		named.append([skill.name if skill.name != "" else String(key), skill])
	named.sort_custom(func(a, b): return a[0].naturalnocasecmp_to(b[0]) < 0)
	var entries := []
	for pair in named:
		entries.append([pair[0], _page_for_skill.bind(pair[1])])
	_offer(entries)


## --- The pages ---


func _page_for_character(key: String):
	var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
	if definition == null:
		return
	var written = definition.glossary_text
	if written == "":
		written = _unwritten("their entry in databases/combatant_database.tscn, under Glossary Text")
	_read(definition.name, written)


func _page_for_condition(condition: ConditionDefinition):
	var lines := []
	if condition.description != "":
		lines.append(condition.description)
		lines.append("")
	lines.append("[b]Defaults[/b]")
	lines.append("Lasts %d of the afflicted's own turns." % condition.duration)
	if condition.dot_min > 0 or condition.dot_max > 0:
		lines.append("Takes %d-%d %s damage off them at the start of each one." % [
			condition.dot_min, condition.dot_max,
			Damage.type_name(condition.dot_type).to_lower()])
	if condition.movement_change != 0:
		lines.append("Movement %+d tile(s)." % condition.movement_change)
	if condition.accuracy_change != 0:
		lines.append("Accuracy %+d." % condition.accuracy_change)
	if condition.max_range > 0:
		lines.append("Every skill they use reaches %d tile(s), however far it normally goes." % condition.max_range)
	if condition.drift_tiles > 0:
		lines.append("Blown up to %d tile(s) across the map at the start of each of their turns." % condition.drift_tiles)
	var stops := []
	if condition.skips_turn:
		stops.append("taking their turn at all")
	if condition.prevents_movement:
		stops.append("moving")
	if condition.prevents_secondary:
		stops.append("secondary actions")
	if condition.prevents_reactions:
		stops.append("reacting when somebody leaves their reach")
	if condition.prevents_approach:
		stops.append("closing on their nearest enemy")
	if not stops.is_empty():
		lines.append("Stops them " + ", ".join(stops) + ".")
	lines.append("")
	lines.append("[i]%s[/i]" % DEFAULTS_NOTE)
	_read(_condition_name(condition), "\n".join(lines))


func _page_for_skill(skill: SkillDefinition):
	var lines := []
	if skill.description != "":
		lines.append(skill.description)
		lines.append("")
	lines.append("[b]How it works[/b]")
	if skill.max_range <= 1 and skill.min_range <= 1:
		lines.append("Reaches the tile beside them.")
	else:
		lines.append("Reaches %d to %d tiles." % [maxi(skill.min_range, 0), skill.max_range])
	if skill.aoe_radius > 0:
		lines.append("Catches everything within %d tile(s) of where it lands." % skill.aoe_radius)
	if skill.spell_slot_level > 0:
		lines.append("Cast through the %s." % Stats.gate_name(skill.spell_slot_level))
	else:
		lines.append("Costs no gate.")
	lines.append("Spent from the %s action." % ("secondary" if skill.is_secondary else "main"))
	if skill.required_level > 1:
		lines.append("Learned at level %d." % skill.required_level)
	if skill.uses_stat_contest:
		lines.append("Never misses: it lands in full on anyone whose %s it beats, and as a graze on anyone it does not." % Stats.stat_name(skill.contest_stat))
	else:
		lines.append("Hits %d%% of the time." % skill.accuracy)
	if skill.is_reactive:
		lines.append("Goes off on its own when somebody leaves its reach.")
	_read(skill.name, "\n".join(lines))


## --- The furniture ---


## Every condition the game can inflict, in alphabetical order.
##
## Read from the skills and items that inflict them rather than by listing
## res://conditions/, because an exported build does not have that folder in
## the shape the editor does: the .tres files are converted to binary and
## renamed on the way into the pack, so a scan for "*.tres" came back empty and
## the Conditions page was blank in the export while working perfectly in the
## editor. What a skill points at survives the conversion, so this asks the
## skills.
##
## It still scans the folder as well, so a condition written but not yet given
## to anybody shows up while it is being worked on.
static func conditions() -> Array:
	var found := {}
	for source in [SkillDatabase.skills, ItemDatabase.items]:
		for key in source:
			var skill: SkillDefinition = source[key]
			if skill == null:
				continue
			for effect in skill.effects:
				if effect != null and effect.condition != null:
					found[effect.condition.resource_path] = effect.condition
	var dir = DirAccess.open("res://conditions")
	if dir != null:
		for file in dir.get_files():
			# What the export leaves in this folder is "blind.tres.remap" and
			# nothing else - the resource itself has been converted to binary
			# and moved. The name it is still known by is underneath.
			if file.ends_with(".remap"):
				file = file.get_basename()
			var path = "res://conditions/".path_join(file)
			if not ResourceLoader.exists(path):
				continue
			var loaded = load(path)
			if loaded is ConditionDefinition and not found.has(loaded.resource_path):
				found[loaded.resource_path] = loaded
	var listed := found.values()
	listed.sort_custom(func(a, b): return _condition_name(a).naturalnocasecmp_to(_condition_name(b)) < 0)
	return listed


static func _condition_name(condition: ConditionDefinition) -> String:
	if condition.display_name != "":
		return condition.display_name
	return condition.resource_path.get_file().get_basename().capitalize()


func _book() -> GlossaryBook:
	var book = load(GLOSSARY_BOOK)
	return book if book is GlossaryBook else null


## Text nobody has written yet, said plainly enough to be actionable rather
## than looking like a bug.
func _unwritten(where: String) -> String:
	return "[i]Nothing written here yet. Write it in %s.[/i]" % where


func _heading(text: String, blurb: String):
	_title.text = text
	_blurb.text = blurb
	_blurb.visible = blurb != ""


## Shows a list of places to go, and hides the reading pane.
func _offer(entries: Array):
	for child in _list.get_children():
		child.queue_free()
	for entry in entries:
		_list.add_child(_button(entry[0], entry[1]))
	_list_scroll.visible = not entries.is_empty()
	_body_scroll.visible = false


## Shows one page, and hides the list.
func _read(heading: String, text: String):
	_heading(heading, "")
	for child in _list.get_children():
		child.queue_free()
	_list_scroll.visible = false
	_body.text = text
	_body_scroll.visible = true


## Goes somewhere and remembers where from, so Back always means "where I was".
func _go_to(view: Callable):
	_trail.append(view)
	view.call()


func _go_back():
	if _trail.size() <= 1:
		closed.emit()
		return
	_trail.pop_back()
	_trail.back().call()


func _button(text: String, on_press: Callable, remember: bool = true) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 40)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_focus_color", INK)
	button.add_theme_stylebox_override("normal", _box(CARD))
	button.add_theme_stylebox_override("hover", _box(CARD_LIT))
	button.add_theme_stylebox_override("focus", _box(CARD_LIT, ACCENT))
	button.add_theme_stylebox_override("pressed", _box(CARD_LIT, ACCENT))
	# A page is one of these too, so going there has to be remembered the same
	# way going to a list is.
	if remember:
		button.pressed.connect(func(): _go_to(on_press))
	else:
		button.pressed.connect(on_press)
	return button


func _box(fill: Color, edge: Color = CARD_EDGE) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box
