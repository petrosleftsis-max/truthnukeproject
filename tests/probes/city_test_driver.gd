extends Node
## The City Fight, turn by turn, with a watchdog on every single turn.
##
## The sweep hung here rather than failing, which says a turn never returned
## rather than a fight never ending. This logs who is acting before each turn
## so the last line names whoever it stopped on.

var LOG_PATH := HarnessLog.path_for("city")
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
	get_tree().create_timer(200.0).timeout.connect(func():
		log_line("")
		log_line("WATCHDOG: the run never finished - the last turn above is where it stopped.")
		_log.flush()
		get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


func run_test():
	var encounter: EncounterDefinition = null
	for file in DirAccess.open("res://encounters").get_files():
		if not file.ends_with(".tres"):
			continue
		var candidate: EncounterDefinition = load("res://encounters/".path_join(file))
		if candidate.display_name.to_lower().contains("city"):
			encounter = candidate
	ok(encounter != null, "the City Fight is there")
	if encounter == null:
		log_line("FAILURES: %d" % _fail)
		get_tree().quit(1)
		return
	log_line("======== %s, on %s ========" % [encounter.display_name,
		encounter.terrain_scene.resource_path.get_file()])

	Campaign.reset()
	Campaign.current_encounter = encounter
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	for i in 6:
		await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	# Nobody is here to answer a reaction prompt, and while one is up the
	# AI's move timeout deliberately stops counting so it does not give up
	# while a player is deciding. Unassigned, reactions simply fire - which
	# is the documented behaviour for a battle with no prompt wired up, and
	# what this suite wants: a fight that plays itself to a conclusion.
	combat.reaction_prompt = null
	if combat.deployment_active:
		combat.finish_deployment()
		await get_tree().process_frame

	for comb in combat.combatants:
		log_line("   %-14s side %d  %-18s at %s" % [
			comb.name, comb.side, comb.get("ai_function", "-"), comb.position])
	log_line("")

	var turns = 0
	while turns < 60 and combat.groups[combat.Group.PLAYERS].size() > 0 \
			and combat.groups[combat.Group.ENEMIES].size() > 0:
		var acting = combat.get_current_combatant()
		log_line("turn %2d: %s (%s) at %s, hp %d" % [turns + 1, acting.name,
			acting.get("ai_function", "player"), acting.position, acting.hp])
		await combat.advance_turn()
		turns += 1
	log_line("")
	ok(turns > 0, "it ran %d turns" % turns)
	ok(turns < 60 or combat.groups[combat.Group.ENEMIES].size() == 0
		or combat.groups[combat.Group.PLAYERS].size() == 0,
		"and reached an end rather than running out of patience",
		"%d players, %d enemies left" % [combat.groups[combat.Group.PLAYERS].size(),
			combat.groups[combat.Group.ENEMIES].size()])
	log_line("")

	game.queue_free()
	await get_tree().process_frame
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
