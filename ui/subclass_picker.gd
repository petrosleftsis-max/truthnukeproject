extends PanelContainer
class_name SubclassPicker
## The choice of a path at level 24 (Stats.SUBCLASS_LEVEL): a character's three
## SubclassDefinitions side by side, each with what it brings and from which
## level, and a button to take it. Taking one asks once more, since it holds
## until a long rest.
##
## Built in code. The map puts one up for whoever in the party still has a path
## to choose (ExplorationScene._offer_paths), and the character sheet does when
## asked - to choose, or after a long rest to change (`changing`);
## Campaign.choose_subclass and change_path do the choosing.

## A path was taken - Campaign already knows.
signal chosen(key: String, subclass: String)
## Put away without choosing - only offered where the choice can be come back to.
signal put_away

const INK := Color("dce8f5")
const MUTED := Color("8296a9")
const GOLD := Color(1.0, 0.84, 0.35)
const CARD_WIDTH := 300

## Whose path this is.
var key := ""
## Whether they are changing the path they are on (Campaign.change_path) rather
## than choosing their first.
var changing := false
## The path waiting to be confirmed, or "".
var picking := ""

var _cards: HBoxContainer = null
var _confirm_row: HBoxContainer = null
var _confirm_text: Label = null
var _take: Button = null
var _choose_buttons: Array = []


## Builds the choice for `who`. `can_put_away` adds a Later button - for the
## character sheet, where it was asked for and can be asked for again.
func offer(who: String, can_put_away: bool = false, change: bool = false):
	key = who
	changing = change
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	add_child(column)
	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = ("%s changes path" if changing else "%s chooses a path") % Campaign.display_name_of(who)
	column.add_child(title)
	var note := Label.new()
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_color_override("font_color", MUTED)
	note.text = "Rested, a path can be changed - until the party fights again. After that, only at the next long rest." if changing \
		else "One of three, kept until a long rest. Each teaches new things now and more at later levels."
	column.add_child(note)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 12)
	column.add_child(_cards)
	for subclass in SubclassDefinition.for_character(who):
		_cards.add_child(_card(subclass))
	_confirm_row = HBoxContainer.new()
	_confirm_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_confirm_row.add_theme_constant_override("separation", 12)
	_confirm_row.visible = false
	column.add_child(_confirm_row)
	_confirm_text = Label.new()
	_confirm_row.add_child(_confirm_text)
	_take = Button.new()
	_take.name = "Take"
	_take.text = "Take this path"
	_take.pressed.connect(_on_take)
	_confirm_row.add_child(_take)
	var back := Button.new()
	back.name = "Back"
	back.text = "Back"
	back.pressed.connect(_on_back)
	_confirm_row.add_child(back)
	if can_put_away:
		var later := Button.new()
		later.name = "Later"
		later.text = "Later"
		later.pressed.connect(func(): put_away.emit())
		column.add_child(later)
	FocusOnDemand.attach(self, _first_choice())


## One path: its name, what it is, what it teaches, and the button to take it.
func _card(subclass: String) -> Control:
	var path := SubclassDefinition.named(subclass)
	var card := PanelContainer.new()
	card.name = subclass
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)
	var heading := Label.new()
	heading.theme_type_variation = &"HeaderLabel"
	heading.add_theme_font_size_override("font_size", 24)
	heading.text = path.name
	column.add_child(heading)
	var description := Label.new()
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(CARD_WIDTH - 24, 0)
	description.text = path.description
	column.add_child(description)
	var teaches := Label.new()
	teaches.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	teaches.custom_minimum_size = Vector2(CARD_WIDTH - 24, 0)
	teaches.add_theme_color_override("font_color", GOLD)
	teaches.text = "\n".join(what_it_brings(path))
	column.add_child(teaches)
	var choose := Button.new()
	choose.name = "Choose"
	choose.text = "Choose %s" % path.name
	# The one they are on, when changing, is theirs already.
	if changing and Campaign.subclass_of(key) == subclass:
		choose.text = "Their path now"
		choose.disabled = true
	choose.size_flags_vertical = Control.SIZE_SHRINK_END | Control.SIZE_EXPAND
	choose.pressed.connect(_on_choose.bind(subclass))
	column.add_child(choose)
	_choose_buttons.append(choose)
	return card


## The first path there is to take - not the one they are on, when changing.
func _first_choice() -> Button:
	for button in _choose_buttons:
		if not button.disabled:
			return button
	return null


## What a path brings, a line each, with the level each comes at.
static func what_it_brings(path: SubclassDefinition) -> Array:
	var lines := []
	for skill_key in path.skills:
		var skill: SkillDefinition = SkillDatabase.skills.get(skill_key)
		if skill != null:
			lines.append("%s - level %d" % [skill.name, maxi(skill.required_level, Stats.SUBCLASS_LEVEL)])
	for passive in path.passives:
		if passive != null:
			lines.append("%s (passive) - level %d" % [passive.name, maxi(passive.required_level, Stats.SUBCLASS_LEVEL)])
	return lines


func _on_choose(subclass: String):
	picking = subclass
	_confirm_text.text = ("Turn to the path of the %s?" if changing else "Take the path of the %s? It holds until a long rest.") % SubclassDefinition.named(subclass).name
	_confirm_row.visible = true
	_take.grab_focus.call_deferred()


func _on_back():
	picking = ""
	_confirm_row.visible = false
	if _first_choice() != null:
		_first_choice().grab_focus.call_deferred()


func _on_take():
	if picking == "":
		return
	var took: bool = Campaign.change_path(key, picking) if changing else Campaign.choose_subclass(key, picking)
	if not took:
		return
	chosen.emit(key, picking)
