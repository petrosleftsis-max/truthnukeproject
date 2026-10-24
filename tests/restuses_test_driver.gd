extends Node
## Per fight to per short rest (the designer's change of 2026-10-24,
## APPROVED_TRIAL): what can be used only so often - a skill's uses, a free
## amplification, a Conduit - is spent until a short or long rest. In a dungeon
## it is carried from fight to fight (Campaign.record_party, apply_carried_state)
## until a rest; every fight elsewhere starts with all of it, as with gates.
## Stunning Blow among them, 1 / 2 / 3 at 41 / 54 / 64. What counts per fight as
## a trigger - a first hit, a first blow, a round's first attack - stays.

var LOG_PATH := HarnessLog.path_for("restuses")
const DUNGEON := "res://data/dungeons/lab_chapter1_sequence.tres"

var _log: FileAccess = null
var _fail = 0


func log_line(t: String):
	if _log:
		_log.store_line(t)
		_log.flush()


func ok(condition: bool, label: String, detail: String = ""):
	if condition:
		log_line("  PASS  %s %s" % [label, detail])
	else:
		_fail += 1
		log_line("  FAIL  %s %s" % [label, detail])


func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(120.0, true, false, true).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	var booted = get_tree().current_scene
	if booted != null:
		booted.queue_free()
		await get_tree().process_frame
	the_limits()
	the_triggers()
	the_carry()
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func the_limits():
	log_line("======== spent until a short rest ========")
	for key in ["recant", "catalyst", "minefield", "grand_design", "stunning_blow"]:
		var skill: SkillDefinition = SkillDatabase.skills.get(key)
		ok(skill != null and skill.uses_per_short_rest == 1 and "short rest" in skill.description and not "a fight" in skill.description,
			"%s: once a short rest, and says so" % key, skill.description if skill != null else "missing")
	var blow: SkillDefinition = SkillDatabase.skills["stunning_blow"]
	ok(Array(blow.more_uses_at) == [54, 64] and blow.required_level == 41, "  Stunning Blow: learned at 41, more at 54 and 64")
	ok(Combat.SPENT_UNTIL_REST == ["uses", "free_amplifies_used", "conduit_spent"],
		"kept until a rest: a skill's uses, a free amplification, a Conduit", "%s" % [Combat.SPENT_UNTIL_REST])
	var conductor: SubclassDefinition = load("res://data/subclasses/elemental_conductor.tres")
	var spoken: Array = conductor.passives.filter(func(passive): return passive.free_amplifies_at.size() > 0 or passive.conduit)
	ok(spoken.size() == 3 and spoken.all(func(passive): return "short rest" in passive.description and not "a fight" in passive.description),
		"the Conductor's Overcharge, Deep Current and Conduit say a short rest", "%s" % [spoken.map(func(passive): return passive.name)])
	ok(spoken.all(func(passive): return not "a fight" in " ".join(passive.describe_effects())), "  and so does what is written for them")
	log_line("")


func the_triggers():
	log_line("======== what stays per fight or per round ========")
	var skirmisher: SubclassDefinition = load("res://data/subclasses/skirmisher.tres")
	ok(skirmisher.passives.any(func(passive): return passive.opener_bonus > 0.0 and "in a fight" in passive.description),
		"Ambush Strike: the first hit on each enemy in a fight (a trigger)")
	ok(skirmisher.passives.any(func(passive): return passive.afterimage), "Afterimage: the first attack each round (a trigger)")
	var shepherd: SubclassDefinition = load("res://data/subclasses/illusory_shepherd.tres")
	ok(shepherd.passives.any(func(passive): return passive.guards_first_blow and "in a fight" in passive.description),
		"Illusory Guardian: each ally's first blow taken in a fight (a trigger)")
	var trapper: SubclassDefinition = load("res://data/subclasses/trapper.tres")
	ok(trapper.passives.any(func(passive): return passive.free_item_each_fight == "small_bomb" and "every fight" in passive.description),
		"the Trapper's free Small Bomb: every fight still - OPEN, for the designer")
	ok(not "free_items_used" in Combat.SPENT_UNTIL_REST, "  so it is not carried")
	log_line("")


## Somebody of the party as a fight leaves them, `spent` spent.
func fought(key: String, spent: Dictionary) -> Dictionary:
	var comb := {"combatant_key": key, "side": 0, "hp": 50, "max_hp": 100, "alive": true,
		"spell_slots": [0, 1, 1], "max_spell_slots": [0, 1, 1]}
	comb.merge(spent.duplicate(true))
	return comb


## Somebody of the party as a fight makes them, before what they carry in.
func fresh() -> Dictionary:
	return {"hp": 100, "max_hp": 100, "alive": true, "spell_slots": [0, 1, 1], "max_spell_slots": [0, 1, 1]}


func carried(key: String) -> Dictionary:
	var comb := fresh()
	Campaign.apply_carried_state(comb, key)
	return comb


func the_carry():
	log_line("======== carried fight to fight ========")
	var spent := {"uses": {"stunning_blow": 2}, "free_amplifies_used": 1, "conduit_spent": true}
	Campaign.reset()
	Campaign.set_party(["cyrus", "enfina", "prometheus", "alithia"], 64)
	Campaign.dungeon = load(DUNGEON)
	Campaign.record_party([fought("enfina", spent)])
	var next := carried("enfina")
	ok(next.get("uses", {}).get("stunning_blow", 0) == 2 and next.get("free_amplifies_used", 0) == 1 and next.get("conduit_spent", false),
		"in a dungeon, into the next fight: what was spent stays spent", "%s" % [next])
	ok(Combat.uses_a_rest({"level": 64}, SkillDatabase.skills["stunning_blow"]) - next.get("uses", {}).get("stunning_blow", 0) == 1,
		"  Stunning Blow: one of her three left")
	var saved: Dictionary = str_to_var(var_to_str(Campaign.party_state))
	ok(saved.enfina.get("spent_until_rest", {}) == spent, "  a save keeps it", "%s" % [saved.enfina.get("spent_until_rest", {})])
	Campaign.short_rest()
	next = carried("enfina")
	ok(not next.has("uses") and not next.has("free_amplifies_used") and not next.has("conduit_spent"), "a short rest brings it all back")
	Campaign.record_party([fought("enfina", spent)])
	Campaign.long_rest()
	ok(not carried("enfina").has("uses"), "a long rest too")
	Campaign.record_party([fought("enfina", spent)])
	Campaign.rest_party()
	ok(not carried("enfina").has("uses"), "the rest between a dungeon's stages counts as a short rest, for now")

	Campaign.record_party([fought("enfina", spent)])
	Campaign.dungeon = null
	ok(not carried("enfina").has("uses"), "outside a dungeon every fight starts with all of them, as with gates")
	Campaign.record_party([fought("enfina", spent)])
	ok(not Campaign.party_state.enfina.has("spent_until_rest"), "  and nothing is kept between them")
	Campaign.reset()
	log_line("")
