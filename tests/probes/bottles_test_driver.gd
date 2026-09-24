extends Node
## Whether a bottle is really the same bottle whoever throws it.
##
## Its damage is - item_power, no thrower. But a contested item still asks
## wins_contest, which weighs the target's contest_stat against the THROWER's
## scaling_stat, and ItemDefinition hides scaling_stat from the inspector. So
## every bottle in the game contests on a stat nobody chose and nobody can see.

var LOG_PATH := HarnessLog.path_for("bottles")
var _log: FileAccess

func log_line(t): _log.store_line(t); _log.flush()


func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(120.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_probe()


func run_probe():
	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_02_sappers.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	for i in 6:
		await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await get_tree().process_frame

	log_line("======== what each thrower brings to a contest ========")
	var throwers := []
	for comb in combat.combatants:
		if comb.alive and comb.side == 0:
			throwers.append(comb)
			var line = "  %-12s" % comb.name
			for type in Stats.Type.values():
				line += " %s %d" % [Stats.NAMES[type].substr(0, 3), combat.stat_of(comb, type)]
			log_line(line)
	log_line("")

	log_line("======== the same bottle, different hands ========")
	var mark = {}
	for comb in combat.combatants:
		if comb.alive and comb.side != 0:
			mark = comb
			break
	log_line("  against %s" % mark.name)
	for key in ItemDatabase.items:
		var item = ItemDatabase.items[key]
		if not item.uses_stat_contest:
			continue
		var outcomes := []
		for thrower in throwers:
			outcomes.append("%s:%s" % [thrower.name.substr(0, 4),
				"lands" if combat.wins_contest(thrower, mark, item) else "shrugged"])
		log_line("  %-16s target's %-12s vs the bottle's %-4d  %s" % [
			key, Stats.NAMES[item.contest_stat], item.item_power,
			" ".join(outcomes)])
	log_line("")

	log_line("======== and its damage, which really is the same ========")
	for key in ItemDatabase.items:
		var item = ItemDatabase.items[key]
		if not item.deals_damage:
			continue
		var figures := []
		for thrower in throwers:
			figures.append("%s:%d" % [thrower.name.substr(0, 4),
				combat.skill_damage(thrower, mark, item)])
		log_line("  %-16s %s" % [key, " ".join(figures)])

	log_line("")
	log_line("======== what touches a bottle's two numbers ========")
	# A bottle given both numbers, thrown at two targets whose defence differs,
	# to see which of the two the defence actually reaches.
	var bottle: ItemDefinition = ItemDatabase.items["burn_bottle"]
	bottle.item_power = 40
	bottle.deals_damage = true
	var soft = throwers[0]
	var hard = throwers[0]
	for comb in throwers:
		if combat.stat_of(comb, Stats.Type.DEFENSE) < combat.stat_of(soft, Stats.Type.DEFENSE):
			soft = comb
		if combat.stat_of(comb, Stats.Type.DEFENSE) > combat.stat_of(hard, Stats.Type.DEFENSE):
			hard = comb
	log_line("  item_power 40, burning at Burn's own dial")
	for who in [soft, hard]:
		var armour = combat.stat_of(who, Stats.Type.DEFENSE)
		var hit = combat.skill_damage(throwers[0], who, bottle)
		var burn = load("res://conditions/burn.tres")
		var tick_base = combat.dot_base_damage(throwers[0], bottle, burn.dot_modifier)
		var tick = combat.dot_tick(who, tick_base, burn.dot_min, burn.dot_max)
		log_line("  %-12s defence %-3d  damage %-4d  tick %d" % [who.name, armour, hit, tick])
	# And the dials a skill would use, to show they reach neither.
	log_line("  the base behind it: %.1f, against a skill's %.1f in the same hand"
		% [combat.power_behind(throwers[0], bottle),
			combat.power_behind(throwers[0], SkillDatabase.skills["burner"])])

	game.queue_free()
	await get_tree().process_frame
	log_line("FAILURES: 0")
	get_tree().quit(0)
