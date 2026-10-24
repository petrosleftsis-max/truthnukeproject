extends Node
## Probe: plays the Sixty-Four encounter out the way the sweep does and logs
## how long each turn takes, to see what a level 64 fight costs.

var LOG_PATH := HarnessLog.path_for("sixtyfour")
var _log: FileAccess = null


func log_line(t: String):
	if _log:
		_log.store_line(t)
		_log.flush()


func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(1500.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	Campaign.reset()
	Campaign.current_encounter = load("res://data/encounters/level_64_showdown.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	for i in 6:
		await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	combat.reaction_prompt = null
	if combat.deployment_active:
		combat.finish_deployment()
		await get_tree().process_frame
	var tags := RegEx.new()
	tags.compile("\\[[^\\]]*\\]")
	combat.update_information.connect(func(text): log_line("    | " + tags.sub(str(text), "", true).strip_edges()))
	var started := Time.get_ticks_msec()
	var turns = 0
	while turns < 60 and combat.groups[combat.Group.PLAYERS].size() > 0 \
			and combat.groups[combat.Group.ENEMIES].size() > 0:
		var at := Time.get_ticks_msec()
		log_line("-- turn %d" % (turns + 1))
		await combat.advance_turn()
		turns += 1
		var party := []
		for comb in combat.combatants:
			if comb.get("side", 1) == 0:
				party.append("%s %d/%d" % [comb.name, comb.hp, comb.max_hp])
		log_line("   %d ms; party %s" % [Time.get_ticks_msec() - at, party])
	var living := []
	for comb in combat.combatants:
		if comb.alive:
			living.append("%s %d/%d" % [comb.name, comb.hp, comb.max_hp])
	log_line("%d turns in %d s; standing: %s" % [turns, (Time.get_ticks_msec() - started) / 1000, living])
	log_line("FAILURES: 0")
	get_tree().quit(0)
