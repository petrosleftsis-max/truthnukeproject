extends Node
## Named flags: set by dialogue or by an interactable, read by both.

var LOG_PATH := HarnessLog.path_for("flags")

var _log: FileAccess = null
var _fail = 0
## What an interactable's locked message was told to say, so the test can read
## what the player would have been told.
var logged: Array = []


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


## Stands in for the ExplorationScene as far as an interactable can tell.
func log_message(text: String):
	logged.append(text)


func run_test():
	Campaign.reset()

	log_line("======== a flag is a fact about this playthrough ========")
	ok(not Campaign.flag("never_set"), "one never set reads false, so conditions can be written first")
	Campaign.set_flag("pulled_lever")
	ok(Campaign.flag("pulled_lever"), "setting one makes it true")
	ok(Campaign.flag_value("pulled_lever") == true, "stored as true when no value is given")
	Campaign.set_flag("times_asked", 3)
	ok(Campaign.flag_value("times_asked") == 3, "and holds a count when one is", "%s" % Campaign.flag_value("times_asked"))
	ok(Campaign.flag("times_asked"), "which also reads as set")
	ok(Campaign.flag_value("nothing_here", "fallback") == "fallback", "an unset one gives the fallback")
	Campaign.set_flag("times_asked", 0)
	ok(not Campaign.flag("times_asked"), "a count of zero reads as not set")
	Campaign.set_flag("switched_off", false)
	ok(not Campaign.flag("switched_off"), "and so does an explicit false")
	Campaign.clear_flag("pulled_lever")
	ok(not Campaign.flag("pulled_lever"), "clearing one puts it back to never having happened")
	log_line("")

	log_line("======== flags last as long as the playthrough ========")
	Campaign.set_flag("read_the_notice")
	# Off to a battle and back, which is the longest gap anything has to survive.
	Campaign.begin_battle_from_exploration(
		load("res://encounters/encounter_01_ambush.tres"),
		"res://scenes/explore_crossroads.tscn", Vector2(100, 100), "some_trigger")
	Campaign.finish_battle_from_exploration(true)
	ok(Campaign.flag("read_the_notice"), "a flag survives a battle")
	Campaign.travel_to_map("res://scenes/explore_crossroads.tscn", "east")
	ok(Campaign.flag("read_the_notice"), "and walking to another map")
	Campaign.reset()
	ok(not Campaign.flag("read_the_notice"), "starting the campaign over forgets it")
	log_line("")

	log_line("======== a button and a door, with no code between them ========")
	var door = ExamineInteractable.new()
	door.prompt = "Open"
	door.requires_flag = "power_on"
	door.locked_message = "The door doesn't budge."
	door.text = "The door slides open."
	add_child(door)

	var button = ExamineInteractable.new()
	button.prompt = "Press"
	button.sets_flag = "power_on"
	button.text = "Something hums into life."
	add_child(button)

	ok(door.is_available(), "the locked door still offers its prompt, so it reads as a door")
	ok(not door.is_unlocked(), "but it is locked")
	logged.clear()
	door.use(self)
	ok(logged.size() == 1 and logged[0] == "The door doesn't budge.",
		"using it says so rather than doing nothing", "%s" % [logged])

	logged.clear()
	button.use(self)
	ok(Campaign.flag("power_on"), "the button sets its flag")
	ok(logged.size() == 1 and logged[0].begins_with("Something hums into life."),
		"and still does its own thing", "%s" % [logged])

	logged.clear()
	ok(door.is_unlocked(), "which unlocks the door")
	door.use(self)
	ok(logged.size() == 1 and logged[0].begins_with("The door slides open."), "and now it opens", "%s" % [logged])
	log_line("")

	log_line("======== an interactable can record more than yes ========")
	var choice = ExamineInteractable.new()
	choice.sets_flag = "ending"
	choice.flag_value = "merciful"
	choice.text = "You let him go."
	add_child(choice)
	choice.use(self)
	ok(Campaign.flag_value("ending") == "merciful", "the value it was given is what is stored",
		"%s" % Campaign.flag_value("ending"))
	log_line("")

	log_line("======== a number typed into an interactable is stored as a number ========")
	var counter = ExamineInteractable.new()
	counter.sets_flag = "coins"
	counter.flag_value = "3"
	counter.text = "Three coins."
	add_child(counter)
	counter.use(self)
	ok(typeof(Campaign.flag_value("coins")) == TYPE_INT, "stored as an int, not the text '3'",
		"%s" % type_string(typeof(Campaign.flag_value("coins"))))
	ok(Campaign.flag_value("coins") > 2, "so a condition can count with it")
	var switch = ExamineInteractable.new()
	switch.sets_flag = "lever_down"
	switch.flag_value = "false"
	switch.text = "Click."
	add_child(switch)
	switch.use(self)
	ok(not Campaign.flag("lever_down"), "and writing false really does set it off")
	log_line("")

	log_line("======== a lingering wound is scaled, not a flat range ========")
	var burn: ConditionDefinition = load("res://conditions/burn.tres")
	ok(burn.dot_modifier > 0.0, "Burn scales off whoever inflicted it", "x%s" % burn.dot_modifier)
	var weak = combat_for_dot()
	# Cyrus, because Poison Dart scales from Physical and Physical is a stat he
	# actually grows - pairing a caster with a skill that scales from something
	# they never develop would prove nothing either way.
	var novice = weak.create_combatant(CombatantDatabase.combatants["cyrus"], "cyrus")
	var veteran_spawn = SpawnDefinition.new()
	veteran_spawn.combatant_key = "cyrus"
	veteran_spawn.level = 3
	var veteran = weak.create_combatant(CombatantDatabase.combatants["cyrus"], "cyrus", "", veteran_spawn)
	var poison: SkillDefinition = SkillDatabase.skills["poison_dart"]
	var small = weak.dot_base_damage(novice, poison, burn.dot_modifier)
	var large = weak.dot_base_damage(veteran, poison, burn.dot_modifier)
	ok(large > small * 2, "a stronger caster leaves a worse burn", "%.1f -> %.1f" % [small, large])
	var target = weak.create_combatant(CombatantDatabase.combatants["barbarian"], "barbarian")
	ok(weak.dot_tick(target, large, burn.dot_min, burn.dot_max) > burn.dot_max,
		"and the tick is the scaled number, not the flat one", "flat max was %d" % burn.dot_max)
	# The flat pair is only for a condition with nothing at all behind it now.
	ok(weak.dot_base_damage(novice, null, burn.dot_modifier) == 0.0, "with no skill there is nothing to scale")
	# A bottle does scale - off itself. So the novice and the veteran leave the
	# same burn, which is the claim; it is simply kept by the base being the
	# bottle's rather than by there being no base at all.
	var bottle = ItemDatabase.items["burn_bottle"]
	var thrown_weak = weak.dot_base_damage(novice, bottle, burn.dot_modifier)
	var thrown_strong = weak.dot_base_damage(veteran, bottle, burn.dot_modifier)
	ok(is_equal_approx(thrown_weak, thrown_strong),
		"and a bottle burns the same however strong the arm that throws it",
		"%.1f from the novice, %.1f from the veteran" % [thrown_weak, thrown_strong])
	ok(thrown_weak > 0.0, "off its own power rather than off nobody",
		"%.1f behind it" % thrown_weak)
	var flat = weak.dot_tick(target, 0.0, 4, 4)
	ok(flat == 4, "so the flat range stands in", "%d" % flat)
	log_line("")

	log_line("======== nothing that sets no flag is changed by any of this ========")
	var plain = ExamineInteractable.new()
	plain.text = "An old boot."
	add_child(plain)
	var before = Campaign.flags.size()
	logged.clear()
	plain.use(self)
	ok(Campaign.flags.size() == before, "an ordinary interactable records nothing")
	ok(logged.size() == 1, "and just does its thing", "%s" % [logged])
	log_line("")

	log_line("======== dialogue branches on a flag ========")
	var script: Resource = load("res://Dialogue/flag_example.dialogue")
	ok(script != null, "the example script loads")
	if script != null:
		Campaign.reset()
		var line = await DialogueManager.get_next_dialogue_line(script, "start")
		var without = line.text if line != null else ""
		ok(without.contains("Turn back"), "with the flag unset, the guard turns you away", without)

		Campaign.reset()
		Campaign.set_flag("read_the_notice")
		line = await DialogueManager.get_next_dialogue_line(script, "start")
		var with_flag = line.text if line != null else ""
		ok(with_flag.contains("read the notice"), "with it set, he says something else", with_flag)
		ok(without != with_flag, "so the same title plays differently for what was done before")

		# The `do` lines only run as the script is stepped past them, so this has
		# to play the conversation out rather than read its first line.
		Campaign.reset()
		line = await DialogueManager.get_next_dialogue_line(script, "start")
		while line != null:
			line = await DialogueManager.get_next_dialogue_line(script, line.next_id)
		ok(Campaign.flag_value("times_asked", 0) == 1,
			"a dialogue line counted up on Campaign", "%s" % Campaign.flag_value("times_asked", 0))
		ok(Campaign.flag("spoke_to_guard"), "and another set a plain flag as it went")

		Campaign.reset()
		line = await DialogueManager.get_next_dialogue_line(script, "notice")
		while line != null:
			line = await DialogueManager.get_next_dialogue_line(script, line.next_id)
		ok(Campaign.flag("read_the_notice"), "and reading the notice is what sets the flag in the first place")
	log_line("")

	log_line("======== the church door, as written ========")
	var church: Resource = load("res://Dialogue/church_after_reveal_door_blocked.dialogue")
	ok(church != null, "the script loads")
	if church != null:
		Campaign.reset()
		var first = await DialogueManager.get_next_dialogue_line(church, "start")
		var untouched = first.text if first != null else ""
		ok(untouched.begins_with("I..."),
			"with nothing done yet, the last branch is what plays", untouched)

		Campaign.reset()
		Campaign.set_flag("after_reveal_door_blocked")
		first = await DialogueManager.get_next_dialogue_line(church, "start")
		var blocked = first.text if first != null else ""
		ok(blocked.contains("still in my way"), "having been blocked once, she says so instead", blocked)

		Campaign.reset()
		for who in ["enfina", "cyrus", "prometheus", "clown"]:
			Campaign.set_flag("after_reveal_reminisced_%s" % who)
		first = await DialogueManager.get_next_dialogue_line(church, "start")
		var opened = first.text if first != null else ""
		ok(opened.contains("To live"), "and with all four remembered, the first branch plays", opened)

		Campaign.reset()
		for who in ["enfina", "cyrus", "prometheus"]:
			Campaign.set_flag("after_reveal_reminisced_%s" % who)
		first = await DialogueManager.get_next_dialogue_line(church, "start")
		ok(not first.text.contains("To live"),
			"three of the four is not enough - the && really is an and", first.text)
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


## A Combat with nothing in it, just to work damage out with.
func combat_for_dot() -> Combat:
	var combat = Combat.new()
	add_child(combat)
	return combat
