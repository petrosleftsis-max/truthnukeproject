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
	ok(definition.hp_at(10) == 10 and definition.hp_at(20) == 10,
		"with nothing else set, every level matches it",
		"%d, %d" % [definition.hp_at(10), definition.hp_at(20)])
	definition.max_hp_level_20 = 48
	ok(definition.hp_at(20) == 48, "a level 20 figure is used at level 20", "%d" % definition.hp_at(20))
	ok(definition.hp_at(1) == 10, "level 1 is unmoved", "%d" % definition.hp_at(1))
	ok(definition.hp_at(10) == 28, "and level 10 is as far along between them as it is between the levels", "%d" % definition.hp_at(10))
	var climbs := true
	for level in range(1, 20):
		climbs = climbs and definition.hp_at(level + 1) > definition.hp_at(level)
	ok(climbs, "every level a step up")
	log_line("")

	log_line("======== a combatant is built with their level's health ========")
	# On a real character, so this is the path the game actually takes.
	var alithia: CombatantDefinition = CombatantDatabase.combatants["alithia"]
	var written = alithia.max_hp
	var written_top = alithia.max_hp_level_20
	alithia.max_hp_level_20 = written + 38
	var novice = combat.create_combatant(alithia, "alithia", "", spawn_at("alithia", 1))
	var seasoned = combat.create_combatant(alithia, "alithia", "", spawn_at("alithia", 10))
	var veteran = combat.create_combatant(alithia, "alithia", "", spawn_at("alithia", 20))
	ok(novice.max_hp == written, "level 1 fights with the level 1 figure", "%d" % novice.max_hp)
	ok(seasoned.max_hp == written + 18, "level 10 with its step of the way", "%d" % seasoned.max_hp)
	ok(veteran.max_hp == written + 38, "level 20 with the top figure", "%d" % veteran.max_hp)
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
	ok(Campaign.party_state["alithia"].max_hp == written + 38,
		"is remembered against the health she actually had",
		"%d" % Campaign.party_state["alithia"].max_hp)
	var listed = Campaign.party_members()
	var entry = {}
	for member in listed:
		if member.key == "alithia":
			entry = member
	ok(not entry.is_empty(), "she is in the party list")
	if not entry.is_empty():
		ok(entry.max_hp == written + 38, "which reads her bar against that, not against level 1",
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
	Campaign.party_state["alithia"] = {"hp": 3, "max_hp": written + 38, "alive": true}
	var wounded = combat.create_combatant(alithia, "alithia", "", spawn_at("alithia", 1))
	Campaign.apply_carried_state(wounded, "alithia")
	ok(wounded.hp == 3, "a wound that fits is carried as it was", "%d" % wounded.hp)
	log_line("")

	log_line("======== nobody who says nothing is affected ========")
	var unchanging := CombatantDefinition.new()
	unchanging.name = "Unchanging"
	unchanging.max_hp = 12
	var young = combat.create_combatant(unchanging, "", "", spawn_at("", 1))
	var old = combat.create_combatant(unchanging, "", "", spawn_at("", 20))
	ok(young.max_hp == 12 and old.max_hp == 12,
		"somebody with no level 20 figure has the same health at every level",
		"%d at 1, %d at 20" % [young.max_hp, old.max_hp])
	log_line("")

	alithia.max_hp_level_20 = written_top
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
