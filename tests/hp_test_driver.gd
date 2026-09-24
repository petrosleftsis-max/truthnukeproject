extends Node
## Health chosen per level, and the places a carried-over wound could read wrong.

var LOG_PATH := HarnessLog.path_for("hp")

var _log: FileAccess = null
var _fail = 0
var combat: Combat = null


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
	get_tree().create_timer(120.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


func spawn_at(key: String, level: int) -> SpawnDefinition:
	var spawn = SpawnDefinition.new()
	spawn.combatant_key = key
	spawn.level = level
	return spawn


func run_test():
	combat = Combat.new()
	add_child(combat)
	Campaign.reset()

	log_line("======== the rule ========")
	var definition := CombatantDefinition.new()
	definition.name = "Test Subject"
	definition.max_hp = 10
	ok(definition.hp_at(1) == 10, "level 1 is the health written on the character", "%d" % definition.hp_at(1))
	ok(definition.hp_at(2) == 10 and definition.hp_at(3) == 10,
		"with nothing else set, every level matches it - so an existing character is unchanged",
		"%d, %d" % [definition.hp_at(2), definition.hp_at(3)])
	definition.max_hp_level_3 = 30
	ok(definition.hp_at(3) == 30, "a level 3 figure is used at level 3", "%d" % definition.hp_at(3))
	ok(definition.hp_at(2) == 10, "and level 2 still takes level 1's, since it says nothing",
		"%d" % definition.hp_at(2))
	definition.max_hp_level_2 = 18
	ok(definition.hp_at(2) == 18, "until it does", "%d" % definition.hp_at(2))
	ok(definition.hp_at(1) == 10 and definition.hp_at(3) == 30, "the others are unmoved",
		"%d, %d" % [definition.hp_at(1), definition.hp_at(3)])
	log_line("")

	log_line("======== a combatant is built with their level's health ========")
	# On a real character, so this is the path the game actually takes.
	var alithia: CombatantDefinition = CombatantDatabase.combatants["alithia"]
	var written = alithia.max_hp
	alithia.max_hp_level_2 = written + 6
	alithia.max_hp_level_3 = written + 14
	var novice = combat.create_combatant(alithia, "alithia", "", spawn_at("alithia", 1))
	var seasoned = combat.create_combatant(alithia, "alithia", "", spawn_at("alithia", 2))
	var veteran = combat.create_combatant(alithia, "alithia", "", spawn_at("alithia", 3))
	ok(novice.max_hp == written, "level 1 fights with the level 1 figure", "%d" % novice.max_hp)
	ok(seasoned.max_hp == written + 6, "level 2 with its own", "%d" % seasoned.max_hp)
	ok(veteran.max_hp == written + 14, "level 3 with its own", "%d" % veteran.max_hp)
	ok(veteran.hp == veteran.max_hp, "and they start a fight full up", "%d/%d" % [veteran.hp, veteran.max_hp])
	var no_spawn = combat.create_combatant(alithia, "alithia")
	ok(no_spawn.max_hp == written, "no spawn means level 1, as it does for everything else",
		"%d" % no_spawn.max_hp)
	log_line("")

	log_line("======== a wound carried out of one fight ========")
	# She has to be on the roster for the party list to have anything to say
	# about her.
	Campaign.seed_party(["alithia"])
	veteran.hp = veteran.max_hp - 5
	veteran["side"] = 0
	Campaign.record_party([veteran])
	ok(Campaign.party_state["alithia"].max_hp == written + 14,
		"is remembered against the health she actually had",
		"%d" % Campaign.party_state["alithia"].max_hp)
	var listed = Campaign.party_members()
	var entry = {}
	for member in listed:
		if member.key == "alithia":
			entry = member
	ok(not entry.is_empty(), "she is in the party list")
	if not entry.is_empty():
		ok(entry.max_hp == written + 14, "which reads her bar against that, not against level 1",
			"%d/%d" % [entry.hp, entry.max_hp])
		ok(entry.hp <= entry.max_hp, "so the bar never shows more than full",
			"%d/%d" % [entry.hp, entry.max_hp])
	ok(not Campaign.describe_party().contains("/%d" % written) or written == veteran.max_hp,
		"and the level select says the same", Campaign.describe_party())
	log_line("")

	log_line("======== and carried into the next one ========")
	# The next fight fields her at level 1, where that wound is more than she has.
	var next_fight = combat.create_combatant(alithia, "alithia", "", spawn_at("alithia", 1))
	Campaign.apply_carried_state(next_fight, "alithia")
	ok(next_fight.max_hp == written, "she is level 1 again", "%d" % next_fight.max_hp)
	ok(next_fight.hp <= next_fight.max_hp, "and cannot start above full",
		"%d/%d" % [next_fight.hp, next_fight.max_hp])
	# A wound that does fit is carried untouched.
	Campaign.party_state["alithia"] = {"hp": 3, "max_hp": written + 14, "alive": true}
	var wounded = combat.create_combatant(alithia, "alithia", "", spawn_at("alithia", 1))
	Campaign.apply_carried_state(wounded, "alithia")
	ok(wounded.hp == 3, "a wound that fits is carried as it was", "%d" % wounded.hp)
	log_line("")

	log_line("======== nobody who says nothing is affected ========")
	# Whoever has not been given per-level health, since who has is balance.
	var cyrus: CombatantDefinition = null
	for key in CombatantDatabase.combatants:
		var candidate: CombatantDefinition = CombatantDatabase.combatants[key]
		if candidate.max_hp_level_2 == 0 and candidate.max_hp_level_3 == 0:
			cyrus = candidate
			break
	if cyrus == null:
		cyrus = CombatantDefinition.new()
		cyrus.name = "Unchanging"
		cyrus.max_hp = 12
	ok(cyrus.max_hp_level_2 == 0 and cyrus.max_hp_level_3 == 0,
		"%s sets no per-level health" % cyrus.name)
	var young = combat.create_combatant(cyrus, "", "", spawn_at("", 1))
	var old = combat.create_combatant(cyrus, "", "", spawn_at("", 3))
	ok(young.max_hp == cyrus.max_hp and old.max_hp == cyrus.max_hp,
		"so they have the same health at every level, exactly as before",
		"%d at 1, %d at 3" % [young.max_hp, old.max_hp])
	log_line("")

	alithia.max_hp_level_2 = 0
	alithia.max_hp_level_3 = 0
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
