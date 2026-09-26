class_name SkillLook
## Telling apart skills that share one picture.
##
## Most skills and items do not have art of their own yet: seventeen share the
## fire icon, sixteen the bottle and twelve the sword, so an action panel could
## be a row of six identical swords. Until they each get art, an icon used by
## more than one skill gets a badge with the skill's initials and a tint of its
## element - so Water Spike stops wearing Fire Blast's flame untouched. An icon
## that belongs to one skill alone is left exactly as drawn.

const BADGE := "SkillBadge"
const INK := Color("dce8f5")
## How far towards its element's colour a shared icon is pulled - enough to tell
## a water spell from a fire one, not so much the art stops reading.
const TINT_STRENGTH := 0.55
const HEAL_TINT := Color("7fe08a")

static var _uses := {}


## Whether `skill`'s icon is one it shares with any other skill or item.
static func is_shared(skill: SkillDefinition) -> bool:
	if skill == null or skill.icon == null:
		return false
	if _uses.is_empty():
		for key in SkillDatabase.skills:
			var other: SkillDefinition = SkillDatabase.skills[key]
			if other != null and other.icon != null:
				_uses[other.icon] = _uses.get(other.icon, 0) + 1
	return _uses.get(skill.icon, 0) > 1


## Two letters to tell it by: the first of each of two words, or the first two
## of one - Fire Blast is FB, Rapier is Ra.
static func initials(skill_name: String) -> String:
	var words = skill_name.split(" ", false)
	if words.size() >= 2:
		return (words[0].left(1) + words[1].left(1)).to_upper()
	if words.size() == 1:
		return words[0].left(1).to_upper() + words[0].substr(1, 1).to_lower()
	return ""


## The colour of what it does: the element it strikes with, green for a heal,
## and nothing for a plain physical blow or something with no element at all.
static func tint(skill: SkillDefinition) -> Color:
	var type := -1
	if skill.deals_damage:
		type = skill.damage_type
	for effect in skill.all_effects():
		if effect == null or effect.applies_to_caster:
			continue
		if effect.type == EffectDefinition.EffectType.HEAL:
			return HEAL_TINT
		if type < 0 and effect.type == EffectDefinition.EffectType.CONDITION \
				and effect.condition != null and effect.condition.dot_strength != ConditionDefinition.DotStrength.NONE:
			type = effect.condition.dot_type
	if type < 0 or type == Damage.Type.PHYSICAL:
		return Color.WHITE
	return Color.WHITE.lerp(Damage.type_colour(type), TINT_STRENGTH)


## The badge each of `skills` wears when they are shown together - a panel, a
## bag, a sheet - in the same order. Two letters where that tells them apart;
## where two would match, those grow a third, whichever way separates them:
## Wind Shot and Wind Swoon become WSh and WSw, Big Bomb and Blinding Bomb BiB
## and BlB. Worked out per group rather than for the whole game, so a badge
## only grows when there is something on screen to tell it from.
static func tags_for(skills: Array) -> Array:
	var tags := []
	var by_tag := {}
	for i in skills.size():
		var skill: SkillDefinition = skills[i]
		var tag := initials(skill.name) if skill != null and is_shared(skill) else ""
		tags.append(tag)
		if tag != "":
			if not by_tag.has(tag):
				by_tag[tag] = []
			by_tag[tag].append(i)
	for tag in by_tag:
		# Two of the same thing - two Tiny Bombs in one bag - are no clash:
		# only different names wearing the same letters are.
		var names := {}
		for i in by_tag[tag]:
			names[skills[i].name] = true
		if names.size() < 2:
			continue
		for way in 3:
			var grown := {}
			for skill_name in names:
				grown[_grown(skill_name, way)] = true
			if grown.size() == names.size():
				for i in by_tag[tag]:
					tags[i] = _grown(skills[i].name, way)
				break
	return tags


## One way of growing a badge by a letter, tried in order until a clashing
## group tells apart.
static func _grown(skill_name: String, way: int) -> String:
	match way:
		0:
			return _grow_second_word(skill_name)
		1:
			return _grow_first_word(skill_name)
	return _grow_both(skill_name)


## "WSh" from Wind Shot; "Gun" from a one-word Gun.
static func _grow_second_word(skill_name: String) -> String:
	var words = skill_name.split(" ", false)
	if words.size() < 2:
		return skill_name.left(3).capitalize()
	return words[0].left(1).to_upper() + words[1].left(1).to_upper() + words[1].substr(1, 1).to_lower()


## "BiB" from Big Bomb.
static func _grow_first_word(skill_name: String) -> String:
	var words = skill_name.split(" ", false)
	if words.size() < 2:
		return skill_name.left(3).capitalize()
	return words[0].left(1).to_upper() + words[0].substr(1, 1).to_lower() + words[1].left(1).to_upper()


## The last resort, four letters: two of each word.
static func _grow_both(skill_name: String) -> String:
	var words = skill_name.split(" ", false)
	if words.size() < 2:
		return skill_name.left(4).capitalize()
	return words[0].left(2).capitalize() + words[1].left(2).capitalize()


## Badges and tints `holder` - an action button or an icon on the sheet - for
## `skill`, or takes both off again when `skill` has art of its own or is null.
## `tag` is the badge's text when it has been worked out alongside others (see
## tags_for); left empty, the skill's own two letters.
static func decorate(holder: Control, skill: SkillDefinition, tag: String = ""):
	var badge: Label = holder.get_node_or_null(BADGE)
	if not is_shared(skill):
		if badge != null:
			badge.visible = false
		_tint(holder, Color.WHITE)
		return
	if badge == null:
		badge = letter_badge(holder, "")
	badge.text = tag if tag != "" else initials(skill.name)
	badge.visible = true
	_tint(holder, tint(skill))


## A small outlined letter or two in the corner of `holder`.
static func letter_badge(holder: Control, text: String, size_px: int = 12) -> Label:
	var badge := Label.new()
	badge.name = BADGE
	badge.text = text
	badge.add_theme_font_size_override("font_size", size_px)
	badge.add_theme_color_override("font_color", INK)
	badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	badge.add_theme_constant_override("outline_size", 4)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(badge)
	badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	badge.offset_right = -3
	badge.offset_bottom = -1
	return badge


static func _tint(holder: Control, colour: Color):
	if holder is Button:
		if colour == Color.WHITE:
			for role in ["icon_normal_color", "icon_hover_color", "icon_pressed_color",
					"icon_focus_color", "icon_hover_pressed_color", "icon_disabled_color"]:
				holder.remove_theme_color_override(role)
			return
		for role in ["icon_normal_color", "icon_hover_color", "icon_pressed_color",
				"icon_focus_color", "icon_hover_pressed_color"]:
			holder.add_theme_color_override(role, colour)
		holder.add_theme_color_override("icon_disabled_color", Color(colour, 0.4))
	else:
		holder.self_modulate = colour
