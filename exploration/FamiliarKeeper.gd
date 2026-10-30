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
##
## In co-op it is steered by one player (`steerer`), with their own device, and
## it is their group that stands rooted meanwhile. Its caster's player takes it
## with Tab as ever; the other player's Tab, while it is off the caster's
## shoulder, asks the caster's player for it (request_control,
## ui/familiar_request.gd - the designer, 2026-10-29), and Tab again hands it
## back. Only the caster's player lets it go.
##
## Over a network (Net) the host's keeper decides all of that, and the joiner's
## shows what it says (apply_net_state). Whoever steers it walks it on their own
## machine, seeing through its eyes there; on the other it is a puppet
## (Familiar.puppet), put where they say.

## The animal for a map that names none.
const DEFAULT_FORM := "res://data/familiars/rat.tres"

var scene: Node = null
## The familiar, while there is one.
var familiar: Familiar = null
## Whether the player is steering it now, rather than the party.
var controlling := false
## In co-op, which player steers it (Coop), or -1.
var steerer := -1
## The question put to the caster's player, while it is up.
var asking: Control = null
## Who called it.
var caster := ""
## Whether it was the familiar that rooted the party, to be let go with it -
## and which group (in co-op, its steerer's).
var _rooted_by_it := false
var _rooted_group: Node = null
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
	take_control(true, caster_player())
	return familiar


## Hands the player's control to the familiar (`to_it`) or back to the party -
## the camera with it, and the party rooted while it is not theirs. In co-op,
## `by` is the player who steers it (their group is the one rooted).
func take_control(to_it: bool, by: int = -1):
	if familiar == null:
		to_it = false
	if _rooted_by_it and _rooted_group != null and is_instance_valid(_rooted_group):
		_rooted_group.rooted = false
	_rooted_by_it = false
	_rooted_group = null
	controlling = to_it
	steerer = by if to_it and Coop.on() else -1
	if familiar != null:
		familiar.controlled = to_it
		familiar.player = steerer
		# Steered from another machine, it goes where they walk it (Net).
		familiar.puppet = to_it and not steered_here()
		if to_it:
			familiar.perched_on = null
	var party = _group_of(steerer) if to_it else null
	if party != null and is_instance_valid(party) and not party.rooted:
		party.rooted = true
		_rooted_by_it = true
		_rooted_group = party
	var leading = scene.get("party") if scene != null else null
	if scene != null and scene.has_method("_follow_camera") and leading != null and is_instance_valid(leading) and steered_here():
		scene._follow_camera(familiar.global_position if to_it and familiar != null else leading.position_of_leader())
	# Seeing through its eyes is for whoever's screen that is.
	_show_eyes(to_it and steered_here())


## Whether its steerer - anybody, outside co-op - plays on this machine.
func steered_here() -> bool:
	return steerer < 0 or Coop.is_local(steerer)


## The co-op player who steers the familiar's caster (Coop.controller_of).
func caster_player() -> int:
	return Coop.controller_of(caster) if Coop.on() else -1


## The group `player` walks - the party, outside co-op.
func _group_of(player: int) -> Node:
	if scene == null:
		return null
	var groups = scene.get("groups")
	if player >= 0 and groups is Dictionary and groups.has(player):
		return groups[player]
	return scene.get("_main_party") if scene.get("_main_party") != null else scene.get("party")


## Tab, for `player` (Coop.acting, or whoever outside co-op): the caster's
## player takes it or gives it back as ever; the other player gives it back if
## they steer it, or else asks the caster's player for it - while it is not on
## the caster's shoulder. True when something was done (asked included).
func swap_for(player: int) -> bool:
	if familiar == null:
		return false
	if not Coop.on() or player < 0:
		return toggle()
	if controlling and steerer == player:
		take_control(false)
		return true
	if player == caster_player():
		take_control(true, player)
		return true
	return request_control(player)


## The other player asks the caster's player for the familiar (the designer,
## 2026-10-29) - not while it rides on its caster's shoulder. True when asked.
func request_control(player: int) -> bool:
	if familiar == null or is_instance_valid(asking):
		return false
	if perched():
		_say("The %s is on [color=yellow]%s[/color]'s shoulder - nobody else can take it from there.\n" % [
			familiar.form.name.to_lower(), Campaign.display_name_of(caster)])
		return false
	var asked := caster_player()
	if asked == player:
		take_control(true, player)
		return true
	# Over a network, put to the caster's player on their own machine (Net).
	if Net.plays_afar(asked):
		Net.ask_for_the_familiar(player, asked)
		return true
	asking = FamiliarRequest.new()
	asking.keeper = self
	asking.asker = player
	asking.asked = asked
	asking.answered.connect(_on_answered.bind(player))
	var layer := CanvasLayer.new()
	layer.name = "FamiliarRequest"
	layer.layer = 60
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	scene.add_child(layer)
	layer.add_child(asking)
	asking.tree_exited.connect(layer.queue_free)
	return true


func _on_answered(yes: bool, player: int):
	asking = null
	if familiar == null:
		return
	if yes:
		take_control(true, player)
		_say("[color=yellow]%s[/color] hands the %s to %s.\n" % [Coop.name_of(caster_player()), familiar.form.name.to_lower(), Coop.name_of(player)])
	else:
		_say("[color=yellow]%s[/color] keeps the %s.\n" % [Coop.name_of(caster_player()), familiar.form.name.to_lower()])


## Whether `player` may let it go: its caster's, in co-op.
func may_dismiss(player: int) -> bool:
	return not Coop.on() or player < 0 or player == caster_player()


func _say(line: String):
	if scene != null and scene.has_method("log_message"):
		scene.log_message(line)


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


## Whether the player is steering the familiar now - in co-op, the player whose
## press this is (Coop.acting), or anybody when nobody is pressing.
func controlling_it() -> bool:
	if familiar == null or not controlling:
		return false
	if not Coop.on() or steerer < 0:
		return true
	return Coop.acting == Coop.ANYONE or Coop.acting == steerer


## Kept rooted while it is steered - something else may have let the party go.
func keep_party_rooted():
	var party = _group_of(steerer)
	if controlling and party != null and not party.rooted:
		party.rooted = true
		_rooted_by_it = true
		_rooted_group = party


func _on_moved(at: Vector2):
	if controlling and steered_here() and scene.has_method("_follow_camera"):
		scene._follow_camera(at)


## --- Over a network ---


## How it stands, for the joiner's keeper: {} with none out.
func net_state() -> Dictionary:
	if familiar == null or not is_instance_valid(familiar) or familiar.form == null:
		return {}
	return {"form": familiar.form.resource_path, "caster": caster, "controlling": controlling, "steerer": steerer,
		"perched": perched(), "at": familiar.global_position, "left": familiar._facing_left}


## On the joiner: the host's keeper as it stands (net_state there) - called,
## steered, perched or let go. Walked here only while this machine's player
## steers it.
func apply_net_state(state: Dictionary):
	if state.is_empty():
		if familiar != null:
			take_control(false)
			familiar.queue_free()
			familiar = null
		return
	var path := str(state.get("form", ""))
	if not path.begins_with("res://") or not ResourceLoader.exists(path) or typeof(state.get("at")) != TYPE_VECTOR2:
		return
	if familiar == null:
		var form = load(path)
		if not form is FamiliarForm:
			return
		familiar = Familiar.new()
		familiar.name = "Familiar"
		scene.add_child(familiar)
		familiar.setup(form, state.at, Callable(scene, "is_walkable_for"))
		familiar.moved.connect(_on_moved)
	caster = str(state.get("caster", caster))
	var steering := int(state.get("steerer", -1))
	var steered := bool(state.get("controlling", false))
	if steered != controlling or steering != steerer:
		take_control(steered, steering)
	if not (steered and steered_here()):
		familiar.puppet = true
		familiar.puppet_to(state.at, bool(state.get("left", false)))
	var party = scene.get("party") if scene != null else null
	var sprite = party.sprite_for(caster) if party != null and bool(state.get("perched", false)) else null
	familiar.perched_on = sprite if sprite != null and not steered else null


func _exit_tree():
	if familiar != null and is_instance_valid(familiar):
		familiar.queue_free()
	familiar = null
	if _rooted_group != null and is_instance_valid(_rooted_group) and _rooted_by_it:
		_rooted_group.rooted = false
	_rooted_by_it = false
	_rooted_group = null


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
