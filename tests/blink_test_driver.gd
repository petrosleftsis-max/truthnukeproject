extends Node
## Aiming a skill that moves whoever casts it.
##
## What such a skill aims at is where its caster arrives, and nobody arrives on
## a tile somebody is already standing on. The Mimic copied Blink Strike and
## pointed it straight at a player: the teleport was refused, the radius-1 burst
## still caught them from their own tile, and it read as an attack whose blink
## had gone missing.

var LOG_PATH := HarnessLog.path_for("blink")

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
	get_tree().create_timer(180.0, true, false, true).timeout.connect(func():
		log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


func run_test():
	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_01_ambush.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	for i in 8:
		await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await get_tree().process_frame

	log_line("======== the skill, as written ========")
	var blink: SkillDefinition = SkillDatabase.skills.get("blink_strike")
	ok(blink != null, "Blink Strike is in the database")
	if blink == null:
		log_line("FAILURES: %d" % (_fail + 1))
		get_tree().quit(1)
		return
	ok(blink.teleports == SkillDefinition.TeleportWho.CASTER, "it moves its caster",
		"%d" % blink.teleports)
	ok(blink.aoe_radius >= 1, "and bursts around where they land",
		"radius %d" % blink.aoe_radius)
	log_line("")

	var player = {}
	var foe = {}
	for comb in combat.combatants:
		if not comb.alive:
			continue
		if comb.side == 0 and player.is_empty():
			player = comb
		elif comb.side == 1 and foe.is_empty():
			foe = comb
	ok(not player.is_empty() and not foe.is_empty(), "somebody on each side")

	# Stood a few tiles off, close enough that open ground beside the player is
	# within reach. Found rather than assumed, so a redrawn map does not rot it.
	var start = Vector2i.ZERO
	var placed := false
	for radius in range(2, blink.max_range + 1):
		for dx in range(-radius, radius + 1):
			var dy = radius - absi(dx)
			for candidate in [player.position + Vector2i(dx, dy), player.position + Vector2i(dx, -dy)]:
				if placed or not combat.can_land_on(foe, candidate):
					continue
				start = candidate
				placed = true
	ok(placed, "there is somewhere to stand within reach of a player", "%s" % start)
	if not placed:
		log_line("FAILURES: %d" % _fail)
		get_tree().quit(1)
		return
	combat.teleport_to(foe, start)
	await get_tree().process_frame

	log_line("======== what the copycat now points it at ========")
	var aim = combat.aim_for_copied_skill(foe, blink, player)
	ok(aim != player.position, "not at the tile the player is standing on",
		"aimed %s, player on %s" % [aim, player.position])
	ok(combat.can_land_on(foe, aim), "somewhere it can actually arrive", "%s" % aim)
	ok(combat.get_position_distance(aim, player.position) <= blink.aoe_radius,
		"and close enough that the burst still catches them",
		"%d tiles" % combat.get_position_distance(aim, player.position))
	log_line("")

	log_line("======== and the blink actually happens ========")
	var stood_at = foe.position
	var hp_before = player.hp
	# Accuracy is 90, and a test that loses a coin toss one run in ten is worse
	# than no test. The copy keeps everything else about the skill.
	var certain: SkillDefinition = blink.duplicate(true)
	certain.accuracy = 100
	SkillDatabase.skills["_certain_blink"] = certain
	await combat.use_skill("_certain_blink", foe, aim, false)
	for i in 6:
		await get_tree().process_frame
	ok(foe.position == aim, "the caster is where they aimed",
		"%s -> %s, wanted %s" % [stood_at, foe.position, aim])
	ok(player.hp < hp_before, "and the player beside them is cut",
		"%d -> %d" % [hp_before, player.hp])
	log_line("")

	log_line("======== the old behaviour, for the record ========")
	# Aimed at the player rather than beside them: the teleport is refused and
	# the burst lands anyway. This is what was being seen in a fight.
	combat.teleport_to(foe, start)
	await get_tree().process_frame
	var before_again = player.hp
	var stood_again = foe.position
	await combat.use_skill("_certain_blink", foe, player.position, false)
	for i in 6:
		await get_tree().process_frame
	ok(foe.position == stood_again, "aiming at somebody teleports nowhere",
		"%s" % foe.position)
	ok(player.hp < before_again, "while still hitting them, which is why it looked like a working attack",
		"%d -> %d" % [before_again, player.hp])
	SkillDatabase.skills.erase("_certain_blink")
	log_line("")

	log_line("======== the search never offers a tile you cannot stand on ========")
	# Asked from everywhere the caster might reasonably be, rather than the one
	# spot the test happened to put them.
	var offered_occupied := []
	var tried := 0
	for dx in range(-4, 5):
		for dy in range(-4, 5):
			var from = player.position + Vector2i(dx, dy)
			if not combat.can_land_on(foe, from):
				continue
			tried += 1
			var result = combat.find_best_aim_and_count(blink, from, foe.movement_class, foe)
			if result.count > 0 and not combat.can_land_on(foe, result.position):
				offered_occupied.append("from %s it aimed at %s" % [from, result.position])
	ok(tried > 0, "there were places to try it from", "%d" % tried)
	ok(offered_occupied.is_empty(), "every aim it returned is one the caster can arrive on",
		"%s" % [offered_occupied.slice(0, 3)])
	log_line("")

	log_line("======== nothing else changes where it aims ========")
	# The rule is about skills that move their caster. Everything else the
	# copycat picks up still goes straight at whoever it is chasing.
	var unmoved := []
	for key in SkillDatabase.skills:
		var skill: SkillDefinition = SkillDatabase.skills[key]
		if skill.teleports == SkillDefinition.TeleportWho.CASTER or skill.targets_ally:
			continue
		if combat.aim_for_copied_skill(foe, skill, player) != player.position:
			unmoved.append(skill.name)
	ok(unmoved.is_empty(), "every other skill is still pointed at the target",
		"%s" % [unmoved.slice(0, 4)])
	# Hermes Step moves its TARGET, not its caster, so it is deliberately not
	# covered by any of this.
	var step: SkillDefinition = SkillDatabase.skills.get("hermes_step")
	if step != null:
		ok(step.teleports == SkillDefinition.TeleportWho.TARGET,
			"Hermes Step moves whoever it lands on, and is left alone")
	log_line("")

	game.queue_free()
	await get_tree().process_frame
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
