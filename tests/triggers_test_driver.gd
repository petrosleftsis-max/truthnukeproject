extends Node
## Reactions beyond leaving reach (Combat "Reactions"): each trigger a reactive
## skill can tick, and Ready - a move held back as its user's main action, gate
## spent there and then, going off as their reaction on the trigger it waits
## for, an area of their choosing included.

var LOG_PATH := HarnessLog.path_for("triggers")
var _log: FileAccess
var _fail = 0
var combat = null
var said: Array = []

const Trigger := SkillDefinition.Trigger


func log_line(t): _log.store_line(t); _log.flush()

func ok(condition: bool, label: String, detail: String = ""):
	if condition:
		log_line("  PASS  %s %s" % [label, detail])
	else:
		_fail += 1
		log_line("  FAIL  %s %s" % [label, detail])


func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(240.0, true, false, true).timeout.connect(func():
		log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


## A reactive skill made for the test: a light blow (or, aimed at allies, a
## small mend) that reacts to `trigger`, under `key`.
func reactive(key: String, trigger: int, ally: bool = false, reach: int = 6, by: int = SkillDefinition.SetOffBy.ENEMIES) -> String:
	var skill := SkillDefinition.new()
	skill.name = key.capitalize()
	skill.min_range = 0 if ally else 1
	skill.max_range = reach
	skill.is_reactive = true
	skill.reacts_when = trigger
	skill.set_off_by = by
	skill.targets_ally = ally
	if ally:
		skill.deals_damage = false
		var mend := EffectDefinition.new()
		mend.type = EffectDefinition.EffectType.HEAL
		mend.min_amount = 1
		mend.max_amount = 1
		skill.effects = [mend]
	else:
		skill.ability_modifier = 0.05
	SkillDatabase.skills[key] = skill
	return key


func who(key: String) -> Dictionary:
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == key and comb.alive:
			return comb
	return {}


func put(comb: Dictionary, tile: Vector2i):
	var from: Vector2i = comb.position
	comb.position = tile
	combat.controller.reposition_combatant(from, tile)


## Whether anybody could stand on `tile` right now.
func open(tile: Vector2i) -> bool:
	return not combat.controller.is_tile_blocking(tile, 0) and combat.get_combatant_at(tile).is_empty()


## Somewhere `comb` could mark an area with a move reaching `reach`: its middle
## in sight, an edge tile in sight and a free tile just past it to step in from
## - [middle, edge, past], or [] when there is nowhere.
func area_spot(comb: Dictionary, reach: int) -> Array:
	for dx in range(-reach, reach + 1):
		for dy in range(-reach, reach + 1):
			var middle: Vector2i = comb.position + Vector2i(dx, dy)
			var gap: int = combat.distance_to(comb, middle)
			if gap < 2 or gap > reach or not open(middle) or not combat.sees_tile(comb, middle):
				continue
			for step in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
				var edge: Vector2i = middle + step * 4
				var past: Vector2i = middle + step * 5
				if open(edge) and open(past) and combat.sees_tile(comb, edge):
					return [middle, edge, past]
	return []


## A free tile `gap` tiles to the right of `comb` (or as near as there is).
func free_near(comb: Dictionary, gap: int, in_sight: bool = false) -> Vector2i:
	for extra in range(0, 6):
		for step in [Vector2i(gap + extra, 0), Vector2i(-gap - extra, 0), Vector2i(0, gap + extra), Vector2i(0, -gap - extra)]:
			var tile: Vector2i = comb.position + step
			if not combat.controller.is_tile_blocking(tile, 0) and combat.get_combatant_at(tile).is_empty() \
					and (not in_sight or combat.has_line_of_sight(tile, comb.position, 0, Sizes.Size.HUMAN, comb)):
				return tile
	return comb.position


func fresh_round():
	for comb in combat.combatants:
		comb.reaction_used = false
		comb.erase("readied")
		comb.skill_used_this_turn = false
		comb.secondary_used_this_turn = false
	said.clear()


func reacted(name: String) -> bool:
	return said.any(func(line): return line.contains("%s[/color] reacts with" % name) or line.contains("%s[/color] reacts as" % name) \
		or line.contains("%s[/color]'s readied" % name))


func run_test():
	Campaign.reset()
	Campaign.current_encounter = load("res://data/encounters/encounter_02_sappers.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(8)
	combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(1)
	# The AI's way of answering, for the party too: no questions in a headless run.
	combat.reaction_prompt = null
	combat.update_information.connect(func(line): said.append(line))
	var enfina = who("enfina")
	var cyrus = who("cyrus")
	var alithia = who("alithia")
	var prometheus = who("prometheus")
	var foe := {}
	for comb in combat.combatants:
		if comb.alive and comb.side == 1 and not comb.has("object") and comb.get("combatant_key", "") == "barbarian":
			foe = comb
			break
	ok(not enfina.is_empty() and not foe.is_empty(), "the party and a barbarian to react to")
	for comb in combat.combatants:
		comb.hp = 999
		comb.max_hp = 999

	log_line("======== the triggers, on the skill ========")
	var greatsword: SkillDefinition = SkillDatabase.skills["greatsword_attack"]
	ok(greatsword.is_reactive and greatsword.reacts_when == Trigger.LEAVES_REACH,
		"a reaction from before has Leaves Reach, and nothing else", "%d" % greatsword.reacts_when)
	ok(greatsword.describe_triggers() == "an enemy leaves its reach", "and says so", greatsword.describe_triggers())
	log_line("")

	log_line("======== Enters Reach ========")
	fresh_round()
	enfina.skill_list.append(reactive("t_brace", Trigger.ENTERS_REACH, false, 1))
	var far := free_near(enfina, 3)
	var near := free_near(enfina, 1)
	# Where they arrive, as a step is checked once it is taken.
	put(foe, near)
	await combat.check_reactive_skills(foe, far, near)
	ok(reacted(enfina.name), "%s strikes whoever steps into her reach" % enfina.name)
	fresh_round()
	put(foe, far)
	await combat.check_reactive_skills(foe, near, far)
	ok(not said.any(func(line): return line.contains("T Brace")), "but not when they step out of it - that's Leaves Reach")
	enfina.skill_list.erase("t_brace")
	log_line("")

	log_line("======== Targeted, before the blow ========")
	fresh_round()
	put(foe, free_near(cyrus, 1))
	cyrus.skill_list.append(reactive("t_duck", Trigger.TARGETED, true))
	var strike: String = ""
	for key in foe.skill_list:
		var skill: SkillDefinition = SkillDatabase.skills.get(key)
		if skill != null and skill.deals_damage and not skill.declared and skill.max_range >= 1 and skill.spell_slot_level == 0:
			strike = key
			break
	ok(strike != "", "the barbarian has something to swing", strike)
	foe.skill_used_this_turn = false
	await combat.use_skill(strike, foe, cyrus.position, false)
	await settle()
	ok(reacted(cyrus.name), "%s reacts as he is about to be hit, on himself" % cyrus.name)
	cyrus.skill_list.erase("t_duck")
	log_line("")

	log_line("======== Struck, after it ========")
	fresh_round()
	cyrus.skill_list.append(reactive("t_rebuke", Trigger.STRUCK))
	foe.skill_used_this_turn = false
	await combat.use_skill(strike, foe, cyrus.position, false)
	await settle()
	ok(reacted(cyrus.name), "hit, %s answers it" % cyrus.name)
	cyrus.skill_list.erase("t_rebuke")
	log_line("")

	log_line("======== Ally Attacked ========")
	fresh_round()
	put(alithia, free_near(cyrus, 1))
	alithia.skill_list.append(reactive("t_ward", Trigger.ALLY_ATTACKED, true))
	foe.skill_used_this_turn = false
	await combat.use_skill(strike, foe, cyrus.position, false)
	await settle()
	ok(reacted(alithia.name), "%s answers a blow aimed at %s" % [alithia.name, cyrus.name])
	alithia.skill_list.erase("t_ward")
	log_line("")

	log_line("======== Casts ========")
	fresh_round()
	var caster := {}
	var spell := ""
	for comb in combat.combatants:
		if comb.alive and comb.side == 1:
			for key in comb.skill_list:
				var skill: SkillDefinition = SkillDatabase.skills.get(key)
				if skill != null and skill.spell_slot_level > 0 and skill.deals_damage and not skill.declared:
					caster = comb
					spell = key
					break
		if spell != "":
			break
	ok(spell != "", "somebody on their side casts", "%s: %s" % [caster.get("name", "nobody"), spell])
	if spell != "":
		caster.spell_slots = [0, 4, 3, 3, 1, 0, 0, 0, 0, 0, 0]
		# Far enough along to have learned it.
		caster.level = maxi(caster.level, SkillDatabase.skills[spell].required_level)
		put(caster, free_near(prometheus, 2))
		prometheus.skill_list.append(reactive("t_counter", Trigger.CASTS))
		caster.skill_used_this_turn = false
		await combat.use_skill(spell, caster, prometheus.position, false)
		await settle()
		ok(reacted(prometheus.name), "%s answers a spell he sees cast" % prometheus.name)
		prometheus.skill_list.erase("t_counter")
	log_line("")

	log_line("======== Declares ========")
	fresh_round()
	prometheus.skill_list.append(reactive("t_hack", Trigger.DECLARES, false, 30))
	put(foe, free_near(prometheus, 2))
	await combat.declare(foe, "ground_pound", prometheus.position)
	await settle()
	ok(reacted(prometheus.name), "a move called within his reach is answered")
	prometheus.skill_list.erase("t_hack")
	foe.erase("declared")
	log_line("")

	log_line("======== Foreseen Blow ========")
	fresh_round()
	put(foe, free_near(alithia, 1))
	alithia.skill_list.append(reactive("t_foresight", Trigger.FORESEEN_BLOW))
	foe["acting_foreseen"] = {"skill": strike}
	foe.skill_used_this_turn = false
	await combat.use_skill(strike, foe, alithia.position, false)
	foe.erase("acting_foreseen")
	await settle()
	ok(reacted(alithia.name), "the blow Intuition read comes, and she is ready for it")
	fresh_round()
	foe.skill_used_this_turn = false
	await combat.use_skill(strike, foe, alithia.position, false)
	await settle()
	ok(not reacted(alithia.name), "an unforeseen one sets nothing off")
	alithia.skill_list.erase("t_foresight")
	log_line("")

	log_line("======== Ready: a move, a trigger, the gate spent now ========")
	fresh_round()
	prometheus.spell_slots = [0, 4, 3, 3, 0, 0, 0, 0, 0, 0, 0]
	var ranged := ""
	for key in prometheus.skill_list:
		var skill: SkillDefinition = SkillDatabase.skills.get(key)
		if skill != null and skill.deals_damage and skill.spell_slot_level == 1 and not combat.is_melee(skill) and skill.max_range >= 5:
			ranged = key
			break
	ok(ranged != "", "Prometheus has a World spell that reaches", ranged)
	ok(combat.ready_refusal(prometheus, "greatsword_attack", Trigger.TARGETED) != "", "nobody readies what they don't know")
	ok(combat.ready_refusal(prometheus, ranged, Trigger.ENTERS_AREA) != "", "an area needs a place")
	ok(combat.ready_refusal(prometheus, ranged, Trigger.ENTERS_AREA, prometheus.position + Vector2i(40, 0)) != "",
		"and a place within the move's reach")
	# An area he can see the middle of, with an edge tile he can see and a free
	# tile just past it to step in from.
	var centre: Vector2i = combat.NO_AREA
	var inside := Vector2i.ZERO
	var outside := Vector2i.ZERO
	var reach: int = combat.effective_max_range(prometheus, SkillDatabase.skills[ranged])
	for dx in range(-reach, reach + 1):
		for dy in range(-reach, reach + 1):
			var middle: Vector2i = prometheus.position + Vector2i(dx, dy)
			var gap: int = combat.distance_to(prometheus, middle)
			if centre != combat.NO_AREA or gap < 2 or gap > reach or not open(middle) or not combat.sees_tile(prometheus, middle):
				continue
			for step in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
				var edge: Vector2i = middle + step * 4
				var past: Vector2i = middle + step * 5
				if open(edge) and open(past) and combat.sees_tile(prometheus, edge):
					centre = middle
					inside = edge
					outside = past
					break
	ok(combat.ready_refusal(prometheus, ranged, Trigger.ENTERS_AREA, centre) == "", "an area in sight and in reach can be marked", "%s" % centre)
	var worlds: int = prometheus.spell_slots[1]
	ok(combat.ready_action(prometheus, ranged, Trigger.ENTERS_AREA, centre), "readied, watching an area 4 tiles round", "%s" % centre)
	ok(prometheus.spell_slots[1] == worlds - 1, "a World spent there and then", "%s" % [prometheus.spell_slots])
	ok(prometheus.skill_used_this_turn, "and his main action")
	var area: Array = prometheus.readied.area
	ok(area.has(centre) and area.has(centre + Vector2i(4, 0)) and not area.has(centre + Vector2i(3, 2)) and area.size() <= 41,
		"a diamond, 4 out", "%d tiles" % area.size())
	ok(combat.ready_refusal(prometheus, ranged, Trigger.TARGETED) != "", "one thing readied at a time")
	enfina.skill_used_this_turn = false
	ok(combat.ready_refusal(enfina, "greatsword_attack", Trigger.ENTERS_AREA, free_near(enfina, 1)) != "",
		"a melee move can't watch an area")
	log_line("")

	log_line("======== an enemy steps into the area ========")
	put(foe, inside)
	await combat.check_reactive_skills(foe, outside, inside)
	await settle()
	ok(said.any(func(line): return line.contains("readied")), "it goes off as they step in")
	ok(not prometheus.has("readied") and prometheus.reaction_used, "once, as his reaction")
	ok(prometheus.spell_slots[1] == worlds - 1, "and costs nothing more")
	log_line("")

	log_line("======== it waits for one turn only ========")
	fresh_round()
	prometheus.spell_slots = [0, 4, 3, 3, 0, 0, 0, 0, 0, 0, 0]
	ok(combat.ready_action(prometheus, ranged, Trigger.TARGETED), "readied for when he is about to be hit")
	ok(prometheus.spell_slots[1] == 3, "the gate gone, whatever happens")
	combat.drop_readied(prometheus, "the moment passed")
	ok(not prometheus.has("readied") and prometheus.spell_slots[1] == 3, "lost if the moment never comes, gate and all")
	log_line("")

	log_line("======== held fast, only if it can't be done ========")
	fresh_round()
	prometheus.spell_slots = [0, 4, 3, 3, 0, 0, 0, 0, 0, 0, 0]
	combat.ready_action(prometheus, ranged, Trigger.TARGETED)
	var grip := EffectDefinition.new()
	grip.type = EffectDefinition.EffectType.CONDITION
	grip.condition = load("res://data/conditions/grappled.tres")
	put(foe, free_near(prometheus, 1))
	combat.apply_effect(foe, prometheus, grip)
	ok(combat.is_held(prometheus) and prometheus.has("readied"), "grabbed, a spell can still be cast: it stays")
	combat._break_holds_on(prometheus)
	prometheus.erase("readied")
	enfina.skill_used_this_turn = false
	enfina.reaction_used = false
	if SkillDatabase.skills.has("climb") and not enfina.skill_list.has("climb"):
		enfina.skill_list.append("climb")
	if enfina.skill_list.has("climb"):
		enfina["readied"] = {"skill": "climb", "trigger": Trigger.ENTERS_REACH, "area": [], "centre": combat.NO_AREA}
		put(foe, free_near(enfina, 1))
		combat.apply_effect(foe, enfina, grip)
		ok(not enfina.has("readied"), "but a climb, which needs her to move, is lost")
	log_line("")

	log_line("======== stunned, it does not go off ========")
	fresh_round()
	prometheus.spell_slots = [0, 4, 3, 3, 0, 0, 0, 0, 0, 0, 0]
	combat._break_holds_on(prometheus)
	put(foe, free_near(prometheus, 2))
	combat.ready_action(prometheus, ranged, Trigger.TARGETED)
	var stun := EffectDefinition.new()
	stun.type = EffectDefinition.EffectType.CONDITION
	stun.condition = load("res://data/conditions/stunned.tres")
	combat.apply_effect(foe, prometheus, stun)
	said.clear()
	foe.skill_used_this_turn = false
	await combat.use_skill(strike, foe, prometheus.position, false)
	await settle()
	ok(not said.any(func(line): return line.contains("readied") and line.contains("goes off")), "nothing goes off")
	log_line("")

	log_line("======== set off by an ally ========")
	fresh_round()
	put(foe, free_near(foe, 12))
	alithia.skill_list.append(reactive("t_welcome", Trigger.ENTERS_REACH, true, 3, SkillDefinition.SetOffBy.ALLIES))
	var far_off := free_near(alithia, 5)
	var close := free_near(alithia, 2)
	cyrus.hp = 990
	put(cyrus, close)
	await combat.check_reactive_skills(cyrus, far_off, close)
	ok(reacted(alithia.name) and cyrus.hp > 990, "an ally coming close is met with a mend - on him", "%d" % cyrus.hp)
	fresh_round()
	put(cyrus, far_off)
	put(foe, close)
	await combat.check_reactive_skills(foe, far_off, close)
	ok(not reacted(alithia.name), "an enemy coming close sets nothing off that is for allies")
	put(foe, free_near(foe, 12))
	alithia.skill_list.erase("t_welcome")
	fresh_round()
	alithia.skill_list.append(reactive("t_farewell", Trigger.LEAVES_REACH, true, 3, SkillDefinition.SetOffBy.ALLIES))
	cyrus.hp = 990
	put(cyrus, close)
	put(cyrus, far_off)
	await combat.check_reactive_skills(cyrus, close, far_off)
	ok(reacted(alithia.name) and cyrus.hp > 990, "and one walking off, with Leaves Reach")
	alithia.skill_list.erase("t_farewell")
	fresh_round()
	enfina.skill_list.append(reactive("t_swing", Trigger.ENTERS_REACH, false, 2, SkillDefinition.SetOffBy.EITHER))
	var enfina_far := free_near(enfina, 5)
	var enfina_close := free_near(enfina, 1)
	put(cyrus, enfina_close)
	await combat.check_reactive_skills(cyrus, enfina_far, enfina_close)
	ok(not reacted(enfina.name), "a blow set off by either side is still never swung at an ally")
	put(cyrus, free_near(cyrus, 8))
	put(foe, enfina_close)
	await combat.check_reactive_skills(foe, enfina_far, enfina_close)
	ok(reacted(enfina.name), "but is at an enemy")
	enfina.skill_list.erase("t_swing")
	put(foe, free_near(foe, 12))
	log_line("")

	log_line("======== a heal readied for allies stepping into an area ========")
	fresh_round()
	alithia.spell_slots = [0, 4, 3, 3, 0, 0, 0, 0, 0, 0, 0]
	var heal_reach: int = combat.effective_max_range(alithia, SkillDatabase.skills["heal"])
	var spot := area_spot(alithia, heal_reach)
	ok(not spot.is_empty(), "somewhere for her to mark", "%s" % [spot])
	if not spot.is_empty():
		ok(combat.ready_refusal(alithia, "heal", Trigger.ENTERS_AREA, spot[0]) != "", "a heal can't watch an area for enemies")
		ok(combat.ready_action(alithia, "heal", Trigger.ENTERS_AREA, spot[0], SkillDefinition.SetOffBy.ALLIES),
			"but can for allies")
		cyrus.hp = 900
		put(cyrus, spot[1])
		await combat.check_reactive_skills(cyrus, spot[2], spot[1])
		await settle()
		ok(not alithia.has("readied") and cyrus.hp > 900, "Cyrus steps in, and is healed", "%d" % cyrus.hp)
	log_line("")

	await enemies_ready()
	await instahack()
	game.queue_free()
	await settle()


## The sum of what is left in every one of `comb`'s gates.
func gates_left(comb: Dictionary) -> int:
	var total := 0
	for left in comb.get("spell_slots", []):
		total += left
	return total


## Whether the log says somebody's spell was cancelled.
func cancelled() -> bool:
	return said.any(func(line): return line.contains("[/color] cancels [color=red]"))


## Prometheus's InstaHack: only ever a reaction, to an enemy in reach casting a
## spell - which comes to nothing, its gate spent all the same.
func instahack():
	log_line("======== InstaHack ========")
	var prometheus = who("prometheus")
	var cyrus = who("cyrus")
	var alithia = who("alithia")
	var instahack: SkillDefinition = SkillDatabase.skills.get("instahack")
	ok(instahack != null and prometheus.skill_list.has("instahack"), "Prometheus knows InstaHack")
	if instahack == null:
		return
	ok(instahack.reaction_only and instahack.reacts_when == Trigger.CASTS and instahack.spell_slot_level == 3,
		"a reaction only, to a spell being cast, through the Gates of Pandora", instahack.describe_triggers())
	prometheus.level = maxi(prometheus.level, instahack.required_level)
	# Whatever the fights above left on him (a stun can't react).
	prometheus.status_effects.clear()
	fresh_round()
	ok(combat.refusal_for(prometheus, instahack, prometheus.position) != "", "it can't be picked on his own turn",
		combat.refusal_for(prometheus, instahack, prometheus.position))
	ok(combat.wasted_on(prometheus, instahack) != "", "so its button is greyed, saying why", combat.wasted_on(prometheus, instahack))
	ok(combat.ready_refusal(prometheus, "instahack", Trigger.CASTS) != "", "nor readied")
	ok(not combat._ai_plannable(prometheus, instahack), "and the AI never plans it")
	var caster := {}
	var spell := ""
	for comb in combat.combatants:
		if comb.alive and comb.side == 1:
			for key in comb.skill_list:
				var skill: SkillDefinition = SkillDatabase.skills.get(key)
				if skill != null and skill.spell_slot_level > 0 and skill.deals_damage and not skill.declared:
					caster = comb
					spell = key
					break
		if spell != "":
			break
	ok(spell != "", "somebody on their side casts", "%s: %s" % [caster.get("name", "nobody"), spell])
	if spell == "":
		return
	caster.level = maxi(caster.level, SkillDatabase.skills[spell].required_level)

	fresh_round()
	prometheus.spell_slots = [0, 4, 3, 2, 0, 0, 0, 0, 0, 0, 0]
	caster.spell_slots = [0, 4, 3, 3, 1, 0, 0, 0, 0, 0, 0]
	put(caster, free_near(prometheus, 2))
	prometheus.hp = 999
	var caster_gates := gates_left(caster)
	var why := "react %s, sees %s, target %s, afford %s, level %s, hidden %s" % [combat._can_react(prometheus),
		combat.sees_tile(prometheus, combat.nearest_tile_of(caster, prometheus.position), caster),
		not combat._reaction_target(prometheus, instahack, caster, prometheus).is_empty(),
		combat.can_afford_skill(prometheus, instahack), combat.meets_level_for(prometheus, instahack), combat.is_hidden(caster)]
	await combat.use_skill(spell, caster, prometheus.position, false)
	await settle()
	ok(cancelled() and prometheus.reaction_used, "%s casts %s in reach: Prometheus cancels it" % [caster.name, spell], why)
	ok(prometheus.hp == 999, "none of it lands", "%d" % prometheus.hp)
	ok(prometheus.spell_slots[3] == 1, "a Gate of Pandora spent on it", "%s" % [prometheus.spell_slots])
	ok(gates_left(caster) == caster_gates - 1 and caster.skill_used_this_turn,
		"and the caster's gate and action are spent all the same", "%d -> %d" % [caster_gates, gates_left(caster)])
	ok(not caster.has("casting") and not caster.has("cast_cancelled"), "nothing left behind on them")
	said.clear()
	caster.skill_used_this_turn = false
	await combat.use_skill(spell, caster, prometheus.position, false)
	await settle()
	ok(not cancelled() and caster.skill_used_this_turn, "his reaction spent, the next one goes ahead", "%d" % prometheus.hp)

	fresh_round()
	prometheus.hp = 999
	caster.hack_locked = true
	await combat.use_skill(spell, caster, prometheus.position, false)
	await settle()
	ok(not cancelled() and not prometheus.reaction_used, "spells locked against hacking are not offered to it")
	caster.erase("hack_locked")

	fresh_round()
	put(caster, free_near(prometheus, 9))
	put(cyrus, free_near(caster, 1))
	cyrus.hp = 999
	await combat.use_skill(spell, caster, cyrus.position, false)
	await settle()
	ok(combat.distance_to(prometheus, caster.position) > instahack.max_range and not cancelled() and not prometheus.reaction_used,
		"out of his reach, it goes ahead", "%d tiles" % combat.distance_to(prometheus, caster.position))

	fresh_round()
	put(caster, free_near(prometheus, 2))
	var strike := ""
	for key in caster.skill_list:
		var skill: SkillDefinition = SkillDatabase.skills.get(key)
		if skill != null and skill.deals_damage and not skill.declared and not combat.is_spell(skill):
			strike = key
	if strike != "":
		await combat.use_skill(strike, caster, prometheus.position, false)
		await settle()
		ok(not cancelled() and not prometheus.reaction_used, "a move with no gate is no spell, and is not answered", strike)
	else:
		log_line("  NOTE  %s has nothing without a gate" % caster.name)

	fresh_round()
	alithia.spell_slots = [0, 4, 3, 3, 0, 0, 0, 0, 0, 0, 0]
	put(alithia, free_near(prometheus, 1))
	cyrus.hp = 900
	put(cyrus, free_near(alithia, 1))
	await combat.use_skill("heal", alithia, cyrus.position, false)
	await settle()
	ok(not cancelled() and not prometheus.reaction_used, "nor is an ally's spell")

	var nade: SkillDefinition = null
	for key in SkillDatabase.skills:
		if SkillDatabase.skills[key] is GateNadeDefinition and SkillDatabase.skills[key].cast != null:
			nade = SkillDatabase.skills[key]
			break
	if nade != null:
		ok(combat.is_spell(nade), "a Gate Nade's spell is still a spell", nade.name)
	log_line("")


## As an enemy's turn ends with its main action unused, what it readies
## (CombatantDefinition.ai_readies) - called here as advance_turn would.
func ending(comb: Dictionary):
	fresh_round()
	comb.erase("readied")
	comb.skill_used_this_turn = false
	combat._ai_consider_ready(comb)


func enemies_ready():
	log_line("======== the enemy readies too ========")
	var sorcerer := {}
	var ranger := {}
	var barbarian := {}
	for comb in combat.combatants:
		if not comb.alive or comb.side != 1:
			continue
		match comb.get("combatant_key", ""):
			"sorcerer":
				sorcerer = comb
			"ranger":
				ranger = comb
			"barbarian":
				if barbarian.is_empty():
					barbarian = comb
	ok(CombatantDatabase.combatants["ranger"].ai_readies == 9 and CombatantDatabase.combatants["rat"].ai_readies == 2,
		"switched on per creature: the Ranger covers the approach and waits for the hidden, the Rat guards")
	var prometheus = who("prometheus")
	prometheus.spell_slots = [0, 4, 3, 3, 0, 0, 0, 0, 0, 0, 0]
	if not sorcerer.is_empty():
		sorcerer.spell_slots = [0, 4, 3, 3, 0, 0, 0, 0, 0, 0, 0]
		# Clear of whoever else stands between them.
		put(sorcerer, free_near(prometheus, 6, true))
		ok(combat._ai_caster_in_sight(sorcerer), "the Sorcerer sees Prometheus, who casts")
		ending(sorcerer)
		ok(sorcerer.get("readied", {}).get("trigger", 0) == Trigger.CASTS, "and readies for when he does",
			"%s" % [sorcerer.get("readied", {})])
		var note: String = combat.game_ui._standing_note(sorcerer)
		ok(note.contains("Ready:"), "its face in the queue says so", note.strip_edges())
		sorcerer.spell_slots = [0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0]
		var spell := ""
		for key in sorcerer.skill_list:
			var skill: SkillDefinition = SkillDatabase.skills.get(key)
			if skill != null and skill.spell_slot_level == 1:
				spell = key
		if spell != "":
			ok(not combat._ai_can_spare(sorcerer, SkillDatabase.skills[spell]), "but never with its last casting")
		sorcerer.erase("readied")
	if not barbarian.is_empty():
		var cyrus = who("cyrus")
		combat.set_hidden(cyrus, true)
		ending(barbarian)
		ok(barbarian.get("readied", {}).get("trigger", 0) == Trigger.ENTERS_REACH,
			"somebody hidden: the Barbarian readies for whoever steps into its reach", "%s" % [barbarian.get("readied", {})])
		var danger: Dictionary = combat.threat_map()
		ok(danger.reaction.has(free_near(barbarian, 1)), "and the danger view marks its reach")
		combat.set_hidden(cyrus, false)
		barbarian.erase("readied")
	if not ranger.is_empty():
		ending(ranger)
		var readied: Dictionary = ranger.get("readied", {})
		var nearest: Dictionary = combat.find_nearest_enemy_of(ranger)
		if readied.get("trigger", 0) == Trigger.ENTERS_AREA:
			ok(not readied.area.any(func(tile): return combat.tiles_of(nearest).has(tile)),
				"the Ranger covers the approach, just short of %s" % nearest.name, "%s" % readied.centre)
			ok(combat.threat_map().reaction.has(readied.centre), "and the danger view marks the area")
		else:
			log_line("  NOTE  nowhere in sight on the way to %s for the Ranger to cover: %s" % [nearest.get("name", "nobody"), readied])
		ranger.erase("readied")
	log_line("")

	log_line("======== a guard keeps its post ========")
	var rat: Dictionary = combat.create_combatant(CombatantDatabase.combatants["rat"], "rat")
	var far_off := Vector2i.ZERO
	for comb in combat.combatants:
		if comb.side == 1 and comb.alive:
			far_off = free_near(comb, 3)
	combat.add_combatant(rat, 1, far_off)
	for comb in combat.combatants:
		if comb.side == 0 and comb.alive:
			put(comb, free_near(comb, 0))
	ok(rat.post == far_off, "it knows where it started", "%s" % rat.post)
	if not combat._ai_can_strike_this_turn(rat):
		ok(combat._ai_guard_ready(rat) and rat.get("readied", {}).get("trigger", 0) == Trigger.ENTERS_REACH,
			"nothing in reach this turn: it readies its reach rather than chase", "%s" % [rat.get("readied", {})])
		ok(rat.position == far_off, "and has not moved")
	else:
		log_line("  NOTE  somebody was within the rat's reach this turn")
	log_line("")
