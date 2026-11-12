extends Node
## The lab's City Fight played by the enemies, with a Light Void laid over the party, every spell of theirs that wants a clear
## line checked as it is cast: did the caster have one? (The designer, 2026-11-07: "the caster in the lab fight could use spells
## without respecting the walls, but I couldn't see them at the time as they were hidden from the light void".)

var LOG_PATH := HarnessLog.path_for("wallcheck")
var _log: FileAccess
var _fail = 0
var combat = null
var checked := 0
var through := []

func log_line(t): _log.store_line(t); _log.flush()

func ok(condition: bool, label: String, detail: String = ""):
	if condition:
		log_line("  PASS  %s %s" % [label, detail])
	else:
		_fail += 1
		log_line("  FAIL  %s %s" % [label, detail])

func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(280.0).timeout.connect(func():
		log_line("WATCHDOG: the run never finished.")
		log_line("FAILURES: %d" % (_fail + 1))
		get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


func _on_metric(event: String, data: Dictionary):
	if event != "action":
		return
	var who: Dictionary = data.get("who", {})
	var skill: SkillDefinition = data.get("skill")
	if who.get("side", 0) != 1 or skill == null or not skill.respects_blocking or Combat.is_melee(skill) or not data.has("aim"):
		return
	var aim: Vector2i = data.aim
	var from: Vector2i = combat.nearest_tile_of(who, aim)
	checked += 1
	var clear: bool = combat.has_line_of_sight(from, aim, combat.terrain_class(who), who.get("size", Sizes.Size.HUMAN), combat.get_combatant_at(aim))
	log_line("   %s casts %s from %s at %s: %s%s" % [who.name, skill.name, from, aim, "clear" if clear else "NO CLEAR LINE",
		", in the dark" if combat.in_darkness(who) else ""])
	if not clear:
		through.append("%s's %s from %s at %s" % [who.name, skill.name, from, aim])


func run_test():
	Campaign.reset()
	Campaign.set_party(["enfina", "cyrus", "prometheus", "alithia"], 18)
	Campaign.current_encounter = load("res://data/encounters/lab/lab_a_city.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	for i in 6:
		await get_tree().process_frame
	combat = game.get_node("VisualCombat")
	combat.reaction_prompt = null
	if combat.deployment_active:
		combat.finish_deployment()
		await get_tree().process_frame
	combat.metric.connect(_on_metric)
	# A Light Void over the party, as the designer had.
	var prometheus: Dictionary = {}
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == "prometheus":
			prometheus = comb
	if not prometheus.is_empty():
		prometheus.spell_slots = Stats.gates_for_level(64)
		if not prometheus.skill_list.has("light_void"):
			prometheus.skill_list.append("light_void")
		combat.current_combatant = combat.combatants.find(prometheus)
		combat.controller.set_controlled_combatant(prometheus)
		prometheus.skill_used_this_turn = false
		await combat.use_skill("light_void", prometheus, prometheus.position, false)
		for i in 3:
			await get_tree().process_frame
	ok(not combat.zones.is_empty(), "a Light Void over the party", "%d zones" % combat.zones.size())
	var turns := 0
	while turns < 60 and combat.groups[combat.Group.PLAYERS].size() > 0 and combat.groups[combat.Group.ENEMIES].size() > 0:
		await combat.advance_turn()
		turns += 1
	log_line("")
	ok(checked > 0, "the enemies cast what wants a clear line", "%d times in %d turns" % [checked, turns])
	ok(through.is_empty(), "every time with one", "%s" % [through])
	game.queue_free()
	await get_tree().process_frame
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
