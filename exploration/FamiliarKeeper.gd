extends Node
class_name FamiliarKeeper
## Alithia's familiar on a map (Find Familiar), watched or not: calling it
## beside her, handing the player's control to it and back, the frame round the
## screen while seeing through its eyes, sending it back to her shoulder, and
## letting it go. ExplorationScene owns one; on a stealth map StealthWatch puts
## the guards' side on top ("Familiar" there) and asks this for the rest.
##
## Swap Leader (Tab) hands control to it and back; Interact (E) while steering
## it sends it back to its caster's shoulder, where it rides along until sent
## off again; Outside Spell (G) lets it go. The first casting after a long rest
## is free (Campaign.free_familiar_used - the designer, 2026-10-29).

## The animal for a map that names none.
const DEFAULT_FORM := "res://data/familiars/rat.tres"

var scene: Node = null
## The familiar, while there is one.
var familiar: Familiar = null
## Whether the player is steering it now, rather than the party.
var controlling := false
## Who called it.
var caster := ""
## Whether it was the familiar that rooted the party, to be let go with it.
var _rooted_by_it := false
var _layer: CanvasLayer = null
var _eyes: Control = null


## The spell that calls a familiar and who among `keys` would cast it -
## {"skill", "caster"} - or {} when none of them knows one at the party's level.
static func spell_among(keys: Array) -> Dictionary:
	for key in keys:
		var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
		if definition == null:
			continue
		var known: Array = Array(definition.skills) + Array(definition.secondary_skills)
		var path := SubclassDefinition.named(Campaign.subclass_of(key))
		if path != null:
			known.append_array(path.skills)
		for skill_key in known:
			var skill: SkillDefinition = SkillDatabase.skills.get(skill_key)
			if skill != null and skill.outside_only() and skill.required_level <= Campaign.party_level \
					and Campaign.gates_most(key)[skill.spell_slot_level] > 0:
				return {"skill": skill_key, "caster": key}
	return {}


## Pays for a casting of `skill` by `by`: nothing for the first since a long
## rest, otherwise its own gate exactly (OutsideMoves.pay). What was paid, or {}.
static func pay(by: String, skill: SkillDefinition) -> Dictionary:
	if not Campaign.free_familiar_used:
		Campaign.free_familiar_used = true
		return {"free": true}
	return OutsideMoves.pay(by, skill, true)


## Why `by` could not pay for a casting of `skill` now, or "".
static func cannot_pay(by: String, skill: SkillDefinition) -> String:
	return "" if not Campaign.free_familiar_used else OutsideMoves.cannot_pay(by, skill, true)


## What paying `paid` reads as in the log.
static func paid_words(paid: Dictionary) -> String:
	return " - free, the first since a long rest" if paid.has("free") else OutsideMoves.paid_through(paid)


## Calls the familiar, in `form`, beside `by`, and hands it the player's
## control. Paying is the caller's.
func summon(by: String, form: FamiliarForm) -> Familiar:
	var party = scene.get("party")
	var sprite = party.sprite_for(by) if party != null else null
	var at: Vector2 = sprite.global_position if sprite != null else scene.party_position()
	familiar = Familiar.new()
	familiar.name = "Familiar"
	scene.add_child(familiar)
	familiar.setup(form, at, Callable(scene, "is_walkable_for"))
	familiar.moved.connect(_on_moved)
	caster = by
	take_control(true)
	return familiar


## Hands the player's control to the familiar (`to_it`) or back to the party -
## the camera with it, and the party rooted while it is not theirs.
func take_control(to_it: bool):
	if familiar == null:
		to_it = false
	controlling = to_it
	if familiar != null:
		familiar.controlled = to_it
		if to_it:
			familiar.perched_on = null
	var party = scene.get("party") if scene != null else null
	if party != null and is_instance_valid(party):
		if to_it and not party.rooted:
			party.rooted = true
			_rooted_by_it = true
		elif not to_it and _rooted_by_it:
			party.rooted = false
			_rooted_by_it = false
		if scene.has_method("_follow_camera"):
			scene._follow_camera(familiar.global_position if to_it else party.position_of_leader())
	_show_eyes(to_it)


## Swaps who the player steers, while there is a familiar. False with none.
func toggle() -> bool:
	if familiar == null:
		return false
	take_control(not controlling)
	return true


## Back on its caster's shoulder, at once, riding along with them - and the
## party the player's again. False with no familiar, or nobody to perch on.
func perch() -> bool:
	if familiar == null:
		return false
	var party = scene.get("party")
	var sprite = party.sprite_for(caster) if party != null else null
	if sprite == null:
		return false
	familiar.perch_on(sprite)
	take_control(false)
	if scene.has_method("log_message"):
		scene.log_message("The %s is back on [color=yellow]%s[/color]'s shoulder.\n" % [
			familiar.form.name.to_lower(), Campaign.display_name_of(caster)])
	return true


## Whether it is riding on its caster's shoulder.
func perched() -> bool:
	return familiar != null and familiar.perched_on != null


## Lets it go, saying `line` - or a plain parting.
func dismiss(line: String = ""):
	if familiar == null:
		return
	var what := familiar.form.name.to_lower()
	take_control(false)
	familiar.queue_free()
	familiar = null
	if scene != null and scene.has_method("log_message"):
		scene.log_message(line if line != "" else "[color=yellow]%s[/color] lets the %s go.\n" % [Campaign.display_name_of(caster), what])


## Whether the player is steering the familiar now.
func controlling_it() -> bool:
	return familiar != null and controlling


## Kept rooted while it is steered - something else may have let the party go.
func keep_party_rooted():
	var party = scene.get("party") if scene != null else null
	if controlling and party != null and not party.rooted:
		party.rooted = true
		_rooted_by_it = true


func _on_moved(at: Vector2):
	if controlling and scene.has_method("_follow_camera"):
		scene._follow_camera(at)


func _exit_tree():
	if familiar != null and is_instance_valid(familiar):
		familiar.queue_free()
	familiar = null
	var party = scene.get("party") if scene != null else null
	if party != null and is_instance_valid(party) and _rooted_by_it:
		party.rooted = false
		_rooted_by_it = false


## The frame round the screen while seeing through its eyes, and the line
## saying so.
func _show_eyes(on: bool):
	if _eyes == null and on:
		_layer = CanvasLayer.new()
		_layer.name = "FamiliarEyes"
		_layer.layer = 2
		add_child(_layer)
		_eyes = _Eyes.new()
		_eyes.keeper = self
		_layer.add_child(_eyes)
	if _eyes != null:
		_eyes.visible = on
		_eyes.refresh()


## A violet frame round the screen and a line along the top.
class _Eyes extends Control:
	var keeper: FamiliarKeeper = null
	var _line: Label = null

	## How far down the screen the line sits: under the stealth bar.
	const LINE_TOP := 104.0

	func _ready():
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_line = Label.new()
		_line.name = "EyesLine"
		_line.add_theme_font_size_override("font_size", 18)
		_line.add_theme_color_override("font_color", Color(0.88, 0.8, 1.0))
		_line.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		_line.add_theme_constant_override("outline_size", 6)
		add_child(_line)
		if not Pad.changed.is_connected(refresh):
			Pad.changed.connect(refresh)
		refresh()

	func refresh():
		if _line == null or keeper == null or keeper.familiar == null:
			return
		_line.text = "Through the %s's eyes    %s    %s    %s" % [keeper.familiar.form.name.to_lower(),
			Pad.hint("Back to the party", &"swap_leader"),
			Pad.hint("To %s's shoulder" % Campaign.display_name_of(keeper.caster), &"interact"),
			Pad.hint("Let it go", &"outside_spell")]
		queue_redraw()

	func _process(_delta):
		# Sized and placed by hand: anchors resolve against nothing under a bare
		# CanvasLayer.
		var screen := get_viewport_rect().size
		if size != screen:
			position = Vector2.ZERO
			size = screen
			queue_redraw()
		_line.reset_size()
		_line.position = Vector2(roundf((screen.x - _line.size.x) / 2.0), LINE_TOP)

	func _draw():
		var edge := 14.0
		var colour := Color(0.62, 0.45, 0.95, 0.45)
		var r := get_rect()
		draw_rect(Rect2(0, 0, r.size.x, edge), colour)
		draw_rect(Rect2(0, r.size.y - edge, r.size.x, edge), colour)
		draw_rect(Rect2(0, 0, edge, r.size.y), colour)
		draw_rect(Rect2(r.size.x - edge, 0, edge, r.size.y), colour)
