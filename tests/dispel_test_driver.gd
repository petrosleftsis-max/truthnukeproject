extends Node
## Dispel Magic (Combat "Dispelling"): what spells left on somebody - theirs or
## the other side's - ended by the gate it is cast through or a shallower one,
## and what came through a deeper gate left alone; a spell's zone undone at its
## ground; what a spell called up or made undone with it; and what no spell did
## left be.

var LOG_PATH := HarnessLog.path_for("dispel")
const WATCHER := "res://data/encounters/encounter_03_watcher.tres"

var _log: FileAccess = null
var _fail = 0
var game: Node = null
var combat = null


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
	get_tree().create_timer(300.0, true, false, true).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	var booted = get_tree().current_scene
	if booted != null:
		booted.queue_free()
		await settle()
	await dispelling()
	if game != null and is_instance_valid(game):
		game.queue_free()
		await settle(3)
	await the_sorcerers_mind()
	if game != null and is_instance_valid(game):
		game.queue_free()
		await settle(3)
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


func open_fight():
	Campaign.reset()
	Campaign.set_party(["cyrus", "enfina", "prometheus", "alithia"], 64)
	for spell in Campaign.learnable_spells("prometheus"):
		Campaign.learn("prometheus", spell)
	Campaign.current_map = "res://maps/crossroads_explore.tscn"
	Campaign.return_to_position = true
	Campaign.current_encounter = load(WATCHER)
	game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(6)
	combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(2)
	combat.reaction_prompt = null
	for comb in combat.combatants:
		if comb.alive:
			comb.max_hp = 9999
			comb.hp = 9999


func who(key: String) -> Dictionary:
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == key and not comb.get("illusion", false):
			return comb
	return {}


func enemies() -> Array:
	return combat.combatants.filter(func(c): return c.side == 1 and c.alive and not c.has("object"))


func put(comb: Dictionary, tile: Vector2i):
	var from: Vector2i = comb.position
	comb.position = tile
	if comb.get("sprite") != null:
		comb.sprite.position = combat.controller.tile_map.map_to_local(tile)
	combat.controller.reposition_combatant(from, tile)


func open(tile: Vector2i) -> bool:
	return combat.controller.is_in_bounds(tile) and combat.controller.is_on_map(tile) \
		and combat.get_combatant_at(tile).is_empty() and not combat.controller.is_tile_blocking(tile, 0)


## The nearest free tile to `near` that passes `test`.
func a_tile(near: Vector2i, test: Callable) -> Vector2i:
	var region: Rect2i = combat.controller._astargrid.region
	var best := Vector2i(-1, -1)
	var best_gap := 999999
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var there := Vector2i(x, y)
			var gap: int = combat.get_position_distance(near, there)
			if gap >= best_gap or not open(there) or not test.call(there):
				continue
			best = there
			best_gap = gap
	return best


func give_turn(comb: Dictionary):
	combat.current_combatant = combat.combatants.find(comb)
	combat.controller.set_controlled_combatant(comb)
	combat.controller.player_turn = comb.side == 0
	combat.controller.action_locked = false
	comb.skill_used_this_turn = false
	comb.secondary_used_this_turn = false


func has_condition(comb: Dictionary, name: String) -> bool:
	return combat.conditions_of(comb).any(func(c): return c.resource_path.get_file().get_basename() == name)


## What `skill`'s condition effect does to `target`, from `caster`, as though cast.
func put_on(caster: Dictionary, target: Dictionary, key: String):
	var skill: SkillDefinition = SkillDatabase.skills[key]
	for effect in skill.effects:
		if effect != null and effect.type != EffectDefinition.EffectType.DAMAGE:
			combat.apply_effect(caster, target, effect, skill, false)


## Prometheus casts Dispel Magic at `aim`, through `gate`.
func dispel(prometheus: Dictionary, aim: Vector2i, gate: int):
	give_turn(prometheus)
	prometheus["cast_through"] = gate
	await combat.use_skill("dispel_magic", prometheus, aim, false)
	await settle(2)


func dispelling():
	log_line("======== Dispel Magic ========")
	await open_fight()
	var prometheus := who("prometheus")
	var alithia := who("alithia")
	var cyrus := who("cyrus")
	var spell: SkillDefinition = SkillDatabase.skills.dispel_magic
	ok(prometheus.skill_list.has("dispel_magic") and spell.spell_slot_level == 3 and spell.chooses_gate,
		"Prometheus's, a Pandora spell cast through whichever gate he likes")
	# Sure of hand, so nothing here misses.
	prometheus.status_effects.append({"stat": "accuracy", "amount": 200, "duration": 99, "source_name": "test"})
	prometheus.spell_slots = Stats.gates_for_level(64)
	ok(await combat._choose_gate(prometheus, spell) == 3, "asked of nobody, it goes through its own gate")

	var foe: Dictionary = enemies()[0]
	put(foe, a_tile(prometheus.position, func(tile): return combat.get_position_distance(tile, prometheus.position) in [2, 3, 4]))
	foe.status_effects.clear()
	put_on(prometheus, foe, "wind_swoon")
	put_on(alithia, foe, "glacial_tide")
	put_on(cyrus, foe, "poison_dart")
	var swoon: Dictionary = foe.status_effects.filter(func(e): return e.get("condition") != null and e.condition.display_name == "Windswept")[0]
	ok(swoon.get("spell_gate", 0) == 2, "what a spell leaves carries its gate", "%s" % swoon.get("spell_gate", "none"))
	var pandora: int = prometheus.spell_slots[3]
	await dispel(prometheus, foe.position, 3)
	ok(not has_condition(foe, "windswept"), "through Pandora's gate, a Hermes spell's windswept is undone")
	ok(has_condition(foe, "frozen"), "but not Glacial Tide's frozen - a Sophia spell, deeper")
	ok(has_condition(foe, "poisoned"), "nor a poison that was never a spell's")
	ok(prometheus.spell_slots[3] == pandora - 1, "one casting through Pandora's gate")
	var sophia: int = prometheus.spell_slots[7]
	await dispel(prometheus, foe.position, 7)
	ok(not has_condition(foe, "frozen") and prometheus.spell_slots[7] == sophia - 1, "cast through Sophia's, the frozen too")

	put(cyrus, a_tile(prometheus.position, func(tile): return combat.get_position_distance(tile, prometheus.position) in [2, 3]))
	cyrus.status_effects.clear()
	put_on(prometheus, cyrus, "quicken")
	put_on(prometheus, cyrus, "invisibility")
	ok(not cyrus.status_effects.is_empty() and combat.is_invisible(cyrus), "Cyrus quickened and invisible, by spells")
	await dispel(prometheus, cyrus.position, 3)
	ok(cyrus.status_effects.filter(func(e): return e.has("spell_gate")).is_empty() and not combat.is_invisible(cyrus),
		"his own side's undone just the same")

	# A zone: Sanctuary of Light, through Nemesis's gate.
	var ground := a_tile(prometheus.position + Vector2i(3, 0), func(tile): return combat.get_position_distance(tile, prometheus.position) in [3, 4, 5] \
		and combat.get_position_distance(tile, alithia.position) <= 6)
	give_turn(alithia)
	alithia.spell_slots = Stats.gates_for_level(64)
	await combat.use_skill("sanctuary_of_light", alithia, ground, false)
	await settle(2)
	var bare := a_tile(ground, func(tile): return combat.zones_at(tile).size() > 0 and combat.get_position_distance(tile, prometheus.position) <= 10)
	ok(not combat.zones.is_empty() and combat.zones[0].gate == 6, "a sanctuary on the ground, through Nemesis's gate", "%s" % [combat.zones.map(func(zone): return zone.gate)])
	ok(combat.refusal_for(prometheus, spell, bare) == "", "bare ground in it can be aimed at")
	await dispel(prometheus, bare, 3)
	ok(combat.zones.size() == 1, "through Pandora's, it holds")
	await dispel(prometheus, bare, 6)
	ok(combat.zones.is_empty(), "through Nemesis's, it is gone")
	var nothing := a_tile(prometheus.position, func(tile): return combat.zones_at(tile).is_empty() and combat.get_position_distance(tile, prometheus.position) in [2, 3])
	ok(combat.refusal_for(prometheus, spell, nothing) != "", "bare ground with no spell's work on it, nothing to aim at")

	# What a spell called up or made.
	var spot := a_tile(prometheus.position, func(tile): return combat.get_position_distance(tile, prometheus.position) in [2, 3, 4])
	give_turn(prometheus)
	# Pandora's castings back - spent, it would come through a deeper gate.
	prometheus.spell_slots = Stats.gates_for_level(64)
	await combat.use_skill("kindled_hound", prometheus, spot, false)
	await settle(2)
	var hound: Dictionary = combat.summons_of(prometheus)[0] if not combat.summons_of(prometheus).is_empty() else {}
	ok(hound.get("spell_gate", 0) == 3, "the hound a spell called up carries its gate", "%s, %s, %s" % [hound.get("name", "no hound"), hound.get("spell_gate", "no gate"), prometheus.spell_slots])
	if not hound.is_empty():
		await dispel(prometheus, hound.position, 3)
		ok(not hound.alive, "and is dispelled")
	var count: int = combat.combatants.size()
	combat.summon_decoy(alithia, cyrus, SkillDatabase.skills.mirror_image)
	var image: Dictionary = combat.combatants.back() if combat.combatants.size() > count else {}
	if not image.is_empty():
		await dispel(prometheus, image.position, 3)
		ok(not image.alive, "an image, shattered")
	var cover_at := a_tile(prometheus.position, func(tile): return combat.get_position_distance(tile, prometheus.position) in [3, 4])
	give_turn(alithia)
	await combat.use_skill("illusory_cover", alithia, cover_at, false)
	await settle(2)
	var cover: Dictionary = combat.get_combatant_at(cover_at)
	ok(cover.get("name", "") == "Illusory Cover", "cover that is not there")
	await dispel(prometheus, cover_at, 3)
	ok(not cover.get("alive", true), "dispelled - the one thing that touches it")
	log_line("")


## Instahack and Dispel Magic on the Sorcerer, and its mind weighing when to use them (the designer, 2026-11-07).
func the_sorcerers_mind():
	log_line("======== The Sorcerer's mind ========")
	var kit: Array = CombatantDatabase.combatants.sorcerer.skills
	ok(kit.has("instahack") and kit.has("dispel_magic"), "the Sorcerer has Instahack and Dispel Magic")
	await open_fight()
	var prometheus := who("prometheus")
	var alithia := who("alithia")
	var cyrus := who("cyrus")
	var foes := enemies()
	var sorcerer: Dictionary = foes[0]
	var ally: Dictionary = foes[1] if foes.size() > 1 else {}
	# One of the fight's own, made a Sorcerer's mind and gates, as the Sixty-Four's are.
	sorcerer.skill_list.append_array(["instahack", "dispel_magic"])
	sorcerer["level"] = 64
	sorcerer.spell_slots = Stats.gates_for_level(64)
	sorcerer["max_spell_slots"] = Stats.gates_for_level(64)
	sorcerer["ai_knows"] = Combat._ai_knows_of(CombatantDatabase.combatants.sorcerer)
	ok(combat.meets_level_for(sorcerer, SkillDatabase.skills.instahack) and combat.meets_level_for(sorcerer, SkillDatabase.skills.dispel_magic),
		"with Pandora's gate open to it, it can use both")
	prometheus.spell_slots = Stats.gates_for_level(64)
	alithia.spell_slots = Stats.gates_for_level(64)

	# What a spell is worth cancelling.
	var blast: SkillDefinition = SkillDatabase.skills.fire_blast
	var hound: SkillDefinition = SkillDatabase.skills.kindled_hound
	ok(combat._ai_cancel_worth(sorcerer, prometheus, blast) < Combat.AI_CANCEL_WORTH, "a spell through the Gates of World alone is let go",
		"%.0f" % combat._ai_cancel_worth(sorcerer, prometheus, blast))
	ok(combat._ai_cancel_worth(sorcerer, prometheus, hound) >= Combat.AI_CANCEL_WORTH, "a hound called up through Pandora's is cancelled",
		"%.0f" % combat._ai_cancel_worth(sorcerer, prometheus, hound))
	ok(combat._ai_cancel_worth(sorcerer, alithia, SkillDatabase.skills.resuscitate) >= Combat.AI_CANCEL_WORTH, "somebody brought back is cancelled")
	if not ally.is_empty():
		ok(combat._ai_cancel_worth(sorcerer, ally, hound) == 0.0, "nothing of its own side's")

	# As a reaction, in sight and in reach of Prometheus casting.
	var spot := a_tile(prometheus.position, func(tile): return combat.get_position_distance(tile, prometheus.position) in [3, 4] \
		and combat.has_line_of_sight(tile, prometheus.position, 0))
	put(sorcerer, spot)
	for comb in combat.combatants:
		comb["reaction_used"] = comb != sorcerer
	var cancelled: bool = await combat._react_to_casting(prometheus, "fire_blast", blast)
	ok(not cancelled and not sorcerer.reaction_used, "Prometheus's Fire Blast it lets go, and keeps its reaction and its casting")
	var pandora: int = sorcerer.spell_slots[3]
	cancelled = await combat._react_to_casting(prometheus, "kindled_hound", hound)
	ok(cancelled and sorcerer.reaction_used, "his hound it cancels", "%s %s" % [cancelled, sorcerer.reaction_used])
	ok(sorcerer.spell_slots[3] == pandora - 1, "for a casting through Pandora's", "%d -> %d" % [pandora, sorcerer.spell_slots[3]])
	sorcerer["reaction_used"] = false
	# Cast for real and torn apart: whoever cast it keeps the gate (the designer, 2026-11-12).
	give_turn(prometheus)
	var his_pandora: int = prometheus.spell_slots[3]
	var hounds: int = combat.summons_of(prometheus).size()
	var its_pandora: int = sorcerer.spell_slots[3]
	await combat.use_skill("kindled_hound", prometheus, a_tile(prometheus.position, func(tile): return combat.get_position_distance(tile, prometheus.position) in [2, 3]), false)
	await settle(2)
	ok(combat.summons_of(prometheus).size() == hounds and sorcerer.spell_slots[3] == its_pandora - 1, "cast for real, it is torn apart: no hound",
		"%d hounds, its Pandora's %d -> %d" % [combat.summons_of(prometheus).size(), its_pandora, sorcerer.spell_slots[3]])
	ok(prometheus.spell_slots[3] == his_pandora, "and his Pandora's casting is his still", "%d -> %d" % [his_pandora, prometheus.spell_slots[3]])
	sorcerer["reaction_used"] = false
	# The deeper the gates open to it, the less a casting through Pandora's has to buy (the designer, 2026-11-12: "the worth of
	# instahack and dispel magic increases as higher gates are unlocked").
	var young: Dictionary = sorcerer.duplicate()
	young["level"] = 14
	young["spell_slots"] = Stats.gates_for_level(14)
	young["max_spell_slots"] = Stats.gates_for_level(14)
	var instahack: SkillDefinition = SkillDatabase.skills.instahack
	# Its gates full again, so the last casting through Pandora's asks nothing more of it.
	sorcerer.spell_slots = Stats.gates_for_level(64)
	var at_14: float = combat._ai_cancel_wanted(young, instahack)
	var at_64: float = combat._ai_cancel_wanted(sorcerer, instahack)
	ok(is_equal_approx(at_14, Combat.AI_CANCEL_WORTH), "at 14, with Pandora's its deepest, a cancelling has to be worth all of it", "%.1f" % at_14)
	ok(at_64 < at_14 and at_64 >= Combat.AI_CANCEL_WORTH * Combat.AI_GATE_COST_LEAST, "at 64, with nine gates open, less", "%.1f" % at_64)
	var plain := SkillDefinition.new()
	plain.name = "A plain spell through Hermes'"
	plain.spell_slot_level = 2
	plain.deals_damage = true
	var worth: float = combat._ai_cancel_worth(sorcerer, prometheus, plain)
	ok(worth < at_14 and worth >= at_64, "a plain spell through Hermes' it lets go at 14 and cancels at 64", "worth %.0f, %.1f and %.1f wanted" % [worth, at_14, at_64])
	ok(combat._ai_cancel_worth(sorcerer, prometheus, blast) < at_64, "one through the World's it lets go even at 64")
	ok(is_equal_approx(combat._ai_dispel_wanted(young, 3), Combat.AI_DISPEL_BLOWS) and combat._ai_dispel_wanted(sorcerer, 3) < Combat.AI_DISPEL_BLOWS,
		"undoing magic through Pandora's: all of a casting's worth at 14, less at 64",
		"%.2f and %.2f" % [combat._ai_dispel_wanted(young, 3), combat._ai_dispel_wanted(sorcerer, 3)])
	ok(combat._ai_dispel_wanted(sorcerer, 9) > combat._ai_dispel_wanted(sorcerer, 3), "and through a deeper gate, more")
	ok(Combat._ai_gate_worth(3) > Combat._ai_gate_worth(1), "what came through a deeper gate counts for more to undo",
		"%.2f and %.2f" % [Combat._ai_gate_worth(1), Combat._ai_gate_worth(3)])

	# Dispel Magic, on its turn. One of its own put to sleep by a spell of Alithia's: that is what to undo.
	if not ally.is_empty():
		ally.status_effects.clear()
		put_on(alithia, ally, "sleep")
		ok(has_condition(ally, "stunned"), "one of its own asleep, by Alithia's Sleep")
		var best: Dictionary = combat._ai_best_dispel(sorcerer)
		ok(best.get("target", {}) == ally and best.get("gate", 0) == SkillDatabase.skills.sleep.spell_slot_level, "that is what it would undo, through the gate it came through",
			"%s, gate %s, worth %s" % [best.get("target", {}).get("name", "nobody"), best.get("gate", 0), best.get("worth", 0)])
		put(sorcerer, a_tile(ally.position, func(tile): return combat.get_position_distance(tile, ally.position) in [2, 3, 4]))
		give_turn(sorcerer)
		ok(await combat._ai_dispel(sorcerer, 0), "and does")
		await settle(2)
		ok(not has_condition(ally, "stunned"), "awake again")
	# Nothing worth a casting: a single quickening of Cyrus's alone is not.
	cyrus.status_effects.clear()
	put_on(prometheus, cyrus, "quicken")
	ok(combat._ai_best_dispel(sorcerer).is_empty(), "a single quickening is not worth a casting", str(combat._ai_best_dispel(sorcerer).get("worth", 0)))
	# Quickened and invisible both, by spells: it is.
	put_on(prometheus, cyrus, "invisibility")
	var seen_cyrus: Dictionary = combat._ai_best_dispel(sorcerer)
	ok(seen_cyrus.get("target", {}) == cyrus or combat.hidden_from(sorcerer, cyrus), "quickened and invisible both is, if it can see him", "%s" % seen_cyrus.get("worth", 0))
	cyrus.status_effects.clear()
	combat.set_hidden(cyrus, false)
	# A hound a spell called up: worth more than any of that.
	give_turn(prometheus)
	await combat.use_skill("kindled_hound", prometheus, a_tile(prometheus.position, func(tile): return combat.get_position_distance(tile, prometheus.position) in [2, 3]), false)
	await settle(2)
	var called: Array = combat.summons_of(prometheus)
	if not called.is_empty():
		ok(combat._ai_best_dispel(sorcerer).get("target", {}) == called[0], "a hound of his, called up by a spell, it would undo")
	# An image it has not seen through is whoever it is of.
	var count: int = combat.combatants.size()
	combat.summon_decoy(alithia, cyrus, SkillDatabase.skills.mirror_image)
	var image: Dictionary = combat.combatants.back() if combat.combatants.size() > count else {}
	if not image.is_empty():
		for each in called:
			each.alive = false
		ok(combat._ai_best_dispel(sorcerer).get("target", {}) != image, "an image it has not seen through it takes for Cyrus, and leaves")
	log_line("")
