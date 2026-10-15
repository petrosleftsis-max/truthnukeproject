extends Node
## Factions: the side an enemy belongs to, and what learning about it is worth -
## a clue that names the faction opens every member's sheet from the start of a
## fight and has the party hit them harder, by the faction's own dial, in what
## lands and in what the aim prompt promises alike.

var LOG_PATH := HarnessLog.path_for("factions")
const AMBUSH := "res://data/encounters/encounter_01_ambush.tres"

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
		await settle()
	await run_test()
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


func open_fight() -> Node:
	Campaign.current_encounter = load(AMBUSH)
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(6)
	var combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(2)
	return game


func run_test():
	log_line("======== a faction, and who is in it ========")
	# Made here rather than read from data/factions: which sides there are and
	# who is on them is the story's to say.
	var faction := FactionDefinition.new()
	faction.name = "The Testing Order"
	faction.known_damage_bonus = 0.5
	FactionDefinition.all()["testing_order"] = faction
	ok(FactionDefinition.named("testing_order") == faction, "a faction can be looked up by key")
	var game = await open_fight()
	var combat = game.get_node("VisualCombat")
	var foe: Dictionary = {}
	for comb in combat.combatants:
		if comb.side == 1:
			foe = comb
			break
	var member_key: String = foe.combatant_key
	var definition: CombatantDefinition = CombatantDatabase.combatants[member_key]
	var faction_was := definition.faction
	definition.faction = "testing_order"
	game.queue_free()
	await settle(3)

	log_line("")
	log_line("======== not known ========")
	Campaign.reset()
	game = await open_fight()
	combat = game.get_node("VisualCombat")
	var cyrus: Dictionary = {}
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == "cyrus":
			cyrus = comb
		if comb.side == 1 and comb.combatant_key == member_key:
			foe = comb
	ok(foe.get("faction", "") == "testing_order", "they fight as one of them")
	ok(not foe.get("studied", false), "and with nothing known, their sheet is closed")
	var rapier: SkillDefinition = SkillDatabase.skills.rapier
	var plain: int = combat.skill_damage(cyrus, foe, rapier)
	game.queue_free()
	await settle(3)

	log_line("")
	log_line("======== known ========")
	# A clue of the story's, made to name them for the length of this.
	var clue_key := "duty_roster"
	var clue: ClueDefinition = ClueBook.clue(clue_key)
	var reveals_were: Array[String] = clue.reveals_factions.duplicate()
	clue.reveals_factions.append("testing_order")
	Campaign.reset()
	ok(not Campaign.knows_faction("testing_order"), "the clue unlearned, the party knows nothing")
	Campaign.learn_clue(clue_key)
	ok(Campaign.knows_faction("testing_order"), "learning a clue that names them, it does")
	game = await open_fight()
	combat = game.get_node("VisualCombat")
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == "cyrus":
			cyrus = comb
		if comb.side == 1 and comb.combatant_key == member_key:
			foe = comb
	ok(foe.get("studied", false), "every one of them has their sheet open from the start")
	ok(foe.get("known_faction", "") == "testing_order", "known to be one of them")
	var known: int = combat.skill_damage(cyrus, foe, rapier)
	ok(known > plain, "and the party hits them harder for it", "%d -> %d" % [plain, known])
	var expected: int = Stats.final_damage(combat.power_behind(cyrus, rapier), rapier.ability_modifier * 1.5,
		combat.stat_of(foe, Stats.Type.DEFENSE))
	ok(known == expected, "by the faction's own dial, a half again here", "%d, wanted %d" % [known, expected])
	var prompt: Dictionary = combat.predict_hit(cyrus, foe, rapier)
	ok(prompt.damage == combat.resisted_damage(foe, Damage.Type.PHYSICAL, known), "the aim prompt promises the same",
		"%d" % prompt.damage)
	ok(combat.skill_damage(foe, cyrus, rapier) == Stats.final_damage(combat.power_behind(foe, rapier), rapier.ability_modifier,
		combat.stat_of(cyrus, Stats.Type.DEFENSE)), "while they hit the party no harder than before")
	game.queue_free()
	await settle(3)

	clue.reveals_factions = reveals_were
	definition.faction = faction_was
	FactionDefinition.all().erase("testing_order")
	Campaign.reset()
	log_line("")
