@icon("res://art/editor_icons/item.svg")
extends ItemDefinition
class_name GateNadeDefinition
## A Gate Nade: a spell sealed in a shell, like a scroll in other games. Throw
## it and the spell goes off - its reach, its area, its effects, whatever it
## does - with no gate of the thrower's opened and no level needed. Then it is
## gone. Only somebody who knows the spell, or could learn it, can throw it
## (Combat.can_use_gate_nade): a Revitalizer Nade is Alithia's, not Enfina's.
##
## Only the spell is chosen here. When the game starts (ItemDatabase) the nade
## takes the spell's whole shape (take_on); what it keeps of its own is what
## makes it an item: its name, description, icon and sound if it has them, its
## Item Power (a nade is the same nade whoever throws it, like a bomb) and its
## price. So a change to the spell changes every nade of it.
##
## Which action it costs is the spell's. Cyrus's Nade Juggler throws any of
## them, whatever spell is in it (PassiveDefinition.any_gate_nade), and with the
## secondary action (gate_nades_as_secondary).

## The spell inside, by key: a skill in data/skills/ with a gate - "fireball".
## A key that is not one is reported when the game starts.
@export var spell: String = ""

## What the nade keeps of its own when it takes on the spell.
const OWN := ["name", "description", "icon", "sound", "sound_volume_db"]

## The spell it was given, once it has taken it on; null before.
var cast: SkillDefinition = null


## Takes on `from`'s whole shape - everything a skill is - keeping its own name,
## description, icon and sound where it has them. Opens no gate, needs no level.
func take_on(from: SkillDefinition):
	if from == null:
		return
	cast = from
	var own_sound := sound != null
	for property in from.get_script().get_script_property_list():
		if not (property.usage & PROPERTY_USAGE_STORAGE):
			continue
		var key: String = property.name
		# Its own where it has them; a name and a description are made for it
		# below where it has none, rather than taken from the spell. Its sound's
		# loudness goes with whichever sound it ends up with.
		if key == "sound_volume_db":
			if own_sound:
				continue
		elif key in OWN and (_has_its_own(key) or key in ["name", "description"]):
			continue
		set(key, from.get(key))
	spell_slot_level = 0
	required_level = 1
	can_be_copied = false
	if name == "":
		name = "%s Gate Nade" % from.name
	if description == "":
		description = "%s, sealed in a shell: throw it and the spell goes off with no gate of your own opened - if you know the spell or could learn it. Gone once thrown." % from.name


func _has_its_own(key: String) -> bool:
	var value = get(key)
	return value != null and not (value is String and value == "")
