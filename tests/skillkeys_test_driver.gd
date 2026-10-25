extends Node
## Every skill key anybody carries resolves, and resolves to the right file.
##
## Both halves matter and they fail differently: an unknown key crashes the
## moment something looks it up, while a key wired to the wrong file never
## crashes at all - the combatant just quietly casts somebody else's spell.

var LOG_PATH := HarnessLog.path_for("skillkeys")
var _log: FileAccess
var _fail = 0

func log_line(t): _log.store_line(t); _log.flush()

func ok(condition: bool, label: String, detail: String = ""):
	if condition:
		log_line("  PASS  %s %s" % [label, detail])
	else:
		_fail += 1
		log_line("  FAIL  %s %s" % [label, detail])

func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	await get_tree().process_frame
	await run_test()

func run_test():
	log_line("======== every skill anybody carries is in the database ========")
	for key in CombatantDatabase.combatants:
		var definition: CombatantDefinition = CombatantDatabase.combatants[key]
		for skill_key in definition.skills:
			ok(SkillDatabase.skills.has(skill_key),
				"%s's '%s' resolves" % [key, skill_key])
	log_line("")

	log_line("======== every key points at the file of the same name ========")
	for skill_key in SkillDatabase.skills:
		var skill: SkillDefinition = SkillDatabase.skills[skill_key]
		ok(skill != null, "'%s' has a resource" % skill_key)
		if skill == null:
			continue
		var file = skill.resource_path.get_file().get_basename()
		ok(file == String(skill_key), "'%s' loads %s.tres" % [skill_key, file], skill.name)
	log_line("")

	log_line("======== a key is its display name, so the editor reads straight ========")
	for skill_key in SkillDatabase.skills:
		var text = String(skill_key)
		ok(text == text.to_lower(), "'%s' is lower case like the rest" % text)
		var skill: SkillDefinition = SkillDatabase.skills[skill_key]
		if skill == null:
			continue
		# Nothing enforces this but the convention itself, and a key that has
		# drifted from the name shown in the inspector is exactly the confusion
		# the rename was meant to end.
		# An apostrophe has no place in a file name, and is left out of the key:
		# Reality's Reflection is realitys_reflection.
		var expected = skill.name.to_lower().replace(" ", "_").replace("'", "")
		# An enemy's own copy of one of the party's moves, kept as the move was
		# (data/skills/enemies/enemy_*.tres), is enemy_ and the name.
		ok(text == expected or text == "enemy_" + expected, "'%s' matches its name %s" % [text, skill.name], expected)
	log_line("")

	log_line("======== reactive skills, the ones the crash was scanning for ========")
	for skill_key in SkillDatabase.skills:
		var skill: SkillDefinition = SkillDatabase.skills[skill_key]
		if skill != null and skill.is_reactive:
			log_line("  NOTE  '%s' (%s) reacts" % [skill_key, skill.name])
	# Communion took Revitalizer's place (2026-10-23): the group heal is Communion's.
	var carriers := []
	var retired := []
	for key in CombatantDatabase.combatants:
		if "communion" in CombatantDatabase.combatants[key].skills:
			carriers.append(key)
		if "revitalizer" in CombatantDatabase.combatants[key].skills:
			retired.append(key)
	ok(carriers.has("alithia") and carriers.has("priest"), "Alithia and the Priest carry Communion", "%s" % [carriers])
	ok(retired.is_empty(), "and nobody Revitalizer, which it replaced", "%s" % [retired])
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
