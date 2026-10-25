extends Node
## The twelve paths at work in a fight, at level 64 with every tier open: each
## one's passives and skills doing what its description says (docs/
## progression_plan.md, "Subclasses"), the choice coming at level 24, and an old
## save's path carried over to the one that replaced it.

var LOG_PATH := HarnessLog.path_for("paths")
const WATCHER := "res://data/encounters/encounter_03_watcher.tres"

var _log: FileAccess = null
var _fail = 0
var game: Node = null
var combat = null
var heard: Array = []


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
	get_tree().create_timer(400.0, true, false, true).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	var booted = get_tree().current_scene
	if booted != null:
		booted.queue_free()
		await settle()
	choosing()
	await enfina_paths()
	await cyrus_paths()
	await prometheus_paths()
	await alithia_paths()
	await all_fit()
	await close_fight()
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


## The watcher fight in the story, the party at `level` on the paths given.
func open_fight(paths: Dictionary, level: int = 64):
	await close_fight()
	Campaign.reset()
	Campaign.set_party(["cyrus", "enfina", "prometheus", "alithia"], level)
	for key in paths:
		Campaign.choose_subclass(key, paths[key])
	# Prometheus learns his spells from books (Campaign "Spellbooks"), his path's
	# too; it is the paths being measured here, so he knows every one.
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
	# Nobody at the keyboard: a reaction is taken without asking.
	combat.reaction_prompt = null
	heard = []
	combat.update_information.connect(func(text): heard.append(text))
	for comb in combat.combatants:
		if comb.side == 1:
			sturdy(comb)


func close_fight():
	if game != null and is_instance_valid(game):
		game.queue_free()
		await settle(3)
	game = null
	combat = null


func heard_since(mark: int, words: String) -> bool:
	for i in range(mark, heard.size()):
		if words in heard[i]:
			return true
	return false


func who(key: String) -> Dictionary:
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == key and not comb.get("illusion", false):
			return comb
	return {}


func enemies() -> Array:
	return combat.combatants.filter(func(c): return c.side == 1 and c.alive and not c.has("object"))


func sturdy(comb: Dictionary, hp: int = 9999):
	comb.max_hp = hp
	comb.hp = hp


## Moves `comb` to `tile`.
func put(comb: Dictionary, tile: Vector2i):
	var from: Vector2i = comb.position
	comb.position = tile
	if comb.get("sprite") != null:
		comb.sprite.position = combat.controller.tile_map.map_to_local(tile)
	combat.controller.reposition_combatant(from, tile)


func open(tile: Vector2i) -> bool:
	return combat.controller.is_in_bounds(tile) and combat.controller.is_on_map(tile) \
		and combat.get_combatant_at(tile).is_empty() and not combat.controller.is_tile_blocking(tile, 0)


## A free tile `steps` straight to the right of `tile`, every tile on the way
## clear, or the first such going another way.
func free_beside(tile: Vector2i, steps: int = 1) -> Vector2i:
	for way in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var clear := true
		for step in range(1, steps + 1):
			if not open(tile + way * step):
				clear = false
		if clear:
			return tile + way * steps
	return Vector2i(-1, -1)


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


## Gives `comb` the turn, nothing in the way of acting.
func give_turn(comb: Dictionary):
	combat.current_combatant = combat.combatants.find(comb)
	combat.controller.set_controlled_combatant(comb)
	combat.controller.player_turn = comb.side == 0
	combat.controller.action_locked = false
	comb.skill_used_this_turn = false
	comb.secondary_used_this_turn = false
	comb.reaction_used = false


## Runs a skill without waiting on it, so a question it asks can be answered.
func start_skill(key: String, caster: Dictionary, aim: Vector2i) -> Array:
	var done := [false]
	var run := func():
		await combat.use_skill(key, caster, aim, false)
		done[0] = true
	run.call()
	return done


func wait_for(check: Callable, seconds: float = 10.0) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		if check.call():
			return true
		await get_tree().process_frame
	return check.call()


func has_condition(comb: Dictionary, name: String) -> bool:
	return combat.conditions_of(comb).any(func(c): return c.resource_path.get_file().get_basename() == name)


func condition(name: String) -> ConditionDefinition:
	return load("res://data/conditions/%s.tres" % name)


## A foe's blow at `target`, landing for sure.
func strike(foe: Dictionary, target: Dictionary, key: String = "greatsword_attack"):
	foe.status_effects.append({"stat": "accuracy", "amount": 200, "duration": 99, "source_name": "test"})
	give_turn(foe)
	await combat.use_skill(key, foe, target.position, false)
	await settle(3)


func bonus(attacker: Dictionary, target: Dictionary, key: String) -> float:
	return combat.progression_damage_bonus(attacker, target, SkillDatabase.skills[key])


func choosing():
	log_line("======== the choice comes at 24 ========")
	ok(Stats.SUBCLASS_LEVEL == 24, "paths open at level 24")
	Campaign.reset()
	Campaign.set_party(["cyrus", "enfina", "prometheus", "alithia"], 23)
	ok(not Campaign.needs_path("cyrus"), "not at 23")
	Campaign.party_level = 24
	ok(Campaign.needs_path("cyrus"), "at 24, a path to choose")
	ok(Array(CombatantDatabase.combatants["enfina"].subclasses) == ["vanguard", "juggernaut", "warden_of_cover"]
		and Array(CombatantDatabase.combatants["cyrus"].subclasses) == ["skirmisher", "saboteur", "trapper"]
		and Array(CombatantDatabase.combatants["prometheus"].subclasses) == ["elemental_vanguard", "elemental_tactician", "elemental_conductor"]
		and Array(CombatantDatabase.combatants["alithia"].subclasses) == ["battle_chaplain", "illusory_shepherd", "inquisitor"],
		"three each, the new ones")
	Campaign.subclasses = {"cyrus": "gunner", "alithia": "carer", "enfina": "berserker"}
	Campaign._carry_old_paths()
	ok(Campaign.subclass_of("cyrus") == "saboteur" and Campaign.subclass_of("enfina") == "vanguard" and Campaign.subclass_of("alithia") == "",
		"an old save's path carries over to the one that replaced it - the Carer's choice is open again", "%s" % [Campaign.subclasses])
	Campaign.reset()
	log_line("")


func enfina_paths():
	log_line("======== Vanguard ========")
	await open_fight({"enfina": "vanguard"})
	var enfina := who("enfina")
	var foe: Dictionary = enemies()[0]
	put(foe, free_beside(enfina.position))
	var still := bonus(enfina, foe, "greatsword_attack")
	enfina["walked_this_turn"] = 3
	ok(is_equal_approx(bonus(enfina, foe, "greatsword_attack") - still, 0.2), "three tiles walked, her next hit a fifth harder (Leading Charge)",
		"%.2f" % (bonus(enfina, foe, "greatsword_attack") - still))
	enfina["charge_spent"] = true
	ok(is_equal_approx(bonus(enfina, foe, "greatsword_attack"), still), "only the next")
	enfina.erase("walked_this_turn")
	enfina.erase("charge_spent")
	var pin: SkillDefinition = SkillDatabase.skills.pin_down
	combat.apply_effect(foe, enfina, pin.effects[0], pin, false)
	combat.put_condition(enfina, condition("snared"), 2, "test", true)
	ok(combat.get_effective_stat(enfina, "movement") >= enfina.movement and not combat.has_restriction(enfina, "prevents_movement"),
		"pinned and snared, she walks as ever (Unstoppable)", "%d" % combat.get_effective_stat(enfina, "movement"))
	ok(combat.immune_to_condition(enfina, condition("grappled")), "and nobody gets a grip on her")
	enfina.status_effects.clear()
	ok(enfina.skill_list.has("daunting_roar") and SkillDatabase.skills.daunting_roar.deals_damage
		and is_equal_approx(SkillDatabase.skills.daunting_roar.ability_modifier, 0.6), "Daunting Roar hits now, x0.6")
	foe.hp = 1
	give_turn(enfina)
	combat.controller.movement = 0
	await combat.use_skill("greatsword_attack", enfina, foe.position, false)
	await settle(3)
	ok(not foe.alive and not enfina.skill_used_this_turn and combat.controller.movement == 3,
		"felling him gives her action back, and three tiles (Rampage)", "%s, %d" % [enfina.skill_used_this_turn, combat.controller.movement])

	log_line("")
	log_line("======== Juggernaut ========")
	await open_fight({"enfina": "juggernaut"})
	enfina = who("enfina")
	ok(combat.immune_to(enfina, Immunity.Kind.SHOVED), "nothing shoves her (Immovable)")
	ok(["chain_hook", "hamstring", "pin_down"].all(func(key): return enfina.skill_list.has(key)), "Chain Hook, Hamstring, Pin Down")
	var foes := enemies()
	var struck: Dictionary = foes[0]
	var near: Dictionary = foes[1]
	put(struck, free_beside(enfina.position))
	var away: Vector2i = struck.position + (struck.position - enfina.position)
	var spot := a_tile(struck.position, func(tile): return tile != away and combat._beside({"position": tile}, struck) \
		and combat.get_position_distance(tile, enfina.position) >= 2)
	put(near, spot)
	for other in foes.slice(2):
		put(other, a_tile(other.position + Vector2i(15, 15), func(tile): return combat.get_position_distance(tile, enfina.position) > 6))
	var near_hp: int = near.hp
	var struck_at: Vector2i = struck.position
	await strike(enfina, struck)
	ok(near.hp < near_hp, "the one beside whoever she hits is hit too (Tremor)", "%d" % (near_hp - near.hp))
	ok(struck.position != struck_at or has_condition(struck, "dazed"), "and the one she hit is shoved - or, against something solid, dazed",
		"%s -> %s" % [struck_at, struck.position])
	var wall_foe: Dictionary = foes[2]
	put(wall_foe, a_tile(enfina.position, func(tile): return combat.controller.is_tile_blocking(tile + Vector2i.RIGHT, 0) \
		and open(tile + Vector2i.LEFT)))
	put(enfina, wall_foe.position + Vector2i.LEFT)
	wall_foe.status_effects.clear()
	combat._shove(enfina, wall_foe, 1, SkillDatabase.skills.greatsword_attack)
	await settle(2)
	ok(has_condition(wall_foe, "dazed") and not has_condition(wall_foe, "stunned"), "shoved into a wall, dazed - stunned no more (the trial)")

	log_line("")
	log_line("======== Warden of Cover ========")
	await open_fight({"enfina": "warden_of_cover"})
	enfina = who("enfina")
	var cyrus := who("cyrus")
	put(cyrus, free_beside(enfina.position))
	cyrus.status_effects.clear()
	give_turn(enfina)
	await combat.use_skill("guard", enfina, enfina.position, false)
	await settle(2)
	ok(cyrus.status_effects.any(func(e): return e.get("stat", "") == "defense"), "her Guard covers Cyrus beside her (Covering Stance)")
	foe = enemies()[0]
	put(foe, free_beside(cyrus.position))
	var before: Vector2i = cyrus.position
	combat._shove(foe, cyrus, 2, SkillDatabase.skills.greatsword_attack)
	await settle(2)
	ok(cyrus.position == before, "inside her Bulwark, Cyrus is not shoved (Hold the Line)", "%s" % cyrus.position)
	sturdy(enfina)
	cyrus.hp = 5
	cyrus.max_hp = 9999
	var enfina_hp: int = enfina.hp
	await strike(foe, cyrus)
	ok(cyrus.alive and cyrus.hp == 1 and enfina.hp < enfina_hp, "a blow that would fell him stops at 1, the rest is hers (Last Wall)",
		"%d / %d" % [cyrus.hp, enfina_hp - enfina.hp])
	log_line("")


func cyrus_paths():
	log_line("======== Cyrus, every path: Elusive and Catalyst ========")
	await open_fight({})
	var cyrus := who("cyrus")
	ok(combat.secondary_skills_of(cyrus).has("slip_past"), "Slip Past as a secondary action, on no path at all (Elusive)")
	var young: Dictionary = combat.create_combatant(CombatantDatabase.combatants["cyrus"], "cyrus", "", null, 1)
	ok(combat.secondary_skills_of(young).has("slip_past"), "from level 1")
	var foe: Dictionary = enemies()[0]
	put(foe, free_beside(cyrus.position, 3))
	foe.status_effects.clear()
	var burning: SkillDefinition = SkillDatabase.skills.burning_shot
	for effect in burning.effects:
		combat.apply_effect(cyrus, foe, effect, burning, false)
	var burn: Dictionary = foe.status_effects.filter(func(e): return e.get("stat", "") == "condition" and e.condition.display_name == "Burn")[0]
	var full: int = burn.full_duration
	burn.duration = 2
	var hp_was: int = foe.hp
	var tick: int = combat.resisted_damage(foe, burn.condition.dot_type, combat.dot_tick(foe, burn.dot_base, 0, 0))
	give_turn(cyrus)
	await combat.use_skill("catalyst", cyrus, cyrus.position, false)
	await settle(3)
	ok(abs((hp_was - foe.hp) - tick * 2 * 2) <= 2, "the burn goes off: its two turns left, twice over (Catalyst)",
		"%d, a tick %d" % [hp_was - foe.hp, tick])
	ok(burn.duration == full, "and starts again as long as it ever was", "%d of %d" % [burn.duration, full])
	ok(combat.refusal_for(cyrus, SkillDatabase.skills.catalyst, cyrus.position) != "", "once a short rest")

	log_line("")
	log_line("======== Skirmisher ========")
	await open_fight({"cyrus": "skirmisher"})
	cyrus = who("cyrus")
	var enfina := who("enfina")
	foe = enemies()[0]
	put(foe, free_beside(cyrus.position))
	var opener := bonus(cyrus, foe, "rapier")
	cyrus["opened_on"] = [foe.id]
	ok(is_equal_approx(opener - bonus(cyrus, foe, "rapier"), 1.0), "his first hit on each of them, double (Ambush Strike)")
	var lone := bonus(cyrus, foe, "rapier")
	put(enfina, a_tile(foe.position, func(tile): return combat._beside({"position": tile}, foe)))
	ok(is_equal_approx(bonus(cyrus, foe, "rapier") - lone, 0.25), "beside one of his, a quarter harder with the Rapier (Flanker)")
	cyrus["repeat_hits"] = {"rapier": 1}
	ok(combat.secondary_skills_of(cyrus).has("rapier") and is_equal_approx(bonus(cyrus, foe, "rapier") - lone, 0.5),
		"the Rapier as a secondary action, a quarter harder the second time (Thousand Cuts)")
	cyrus.erase("repeat_hits")
	var covered := a_tile(cyrus.position, func(tile): return combat.in_cover(cyrus, tile) and open(tile + Vector2i.RIGHT) \
		and not combat.controller.is_tile_blocking(tile + Vector2i.RIGHT, 0))
	if covered.x != -1:
		put(cyrus, covered)
		put(foe, free_beside(cyrus.position))
		sturdy(cyrus)
		await strike(foe, cyrus)
		ok(cyrus.hp == 9999 and cyrus.get("afterimage_spent", false), "in cover, the first blow of the round finds an afterimage (Afterimage)")
		await strike(foe, cyrus)
		ok(cyrus.hp < 9999, "the second does not")
	else:
		log_line("  NOTE  no cover on this map for Afterimage")
	give_turn(cyrus)
	put(foe, free_beside(cyrus.position))
	var done := start_skill("rapier", cyrus, foe.position)
	ok(await wait_for(func(): return combat.controller.is_stepping()), "after the Rapier, a step is offered (Riposte Step)")
	combat.controller.stay_put()
	await wait_for(func(): return done[0])

	log_line("")
	log_line("======== Saboteur ========")
	await open_fight({"cyrus": "saboteur"})
	cyrus = who("cyrus")
	ok(["frost_round", "corrosive_round", "combined_load"].all(func(key): return cyrus.skill_list.has(key))
		and not SkillDatabase.skills.has("shock_round"), "Frost Round, Corrosive Round, Combined Load - no Shock Round")
	var foes := enemies()
	foe = foes[0]
	put(foe, free_beside(cyrus.position, 3))
	foe.status_effects.clear()
	var defence: int = combat.get_effective_stat(foe, "defense")
	# Corroded, or from 41 Deep Corrosion's Deeply Corroded.
	var round: SkillDefinition = SkillDatabase.skills.corrosive_round
	var corrosion: ConditionDefinition = Combat.ranked_condition_effect(cyrus, round, round.effects[0]).condition
	var corroded := corrosion.resource_path.get_file().get_basename()
	give_turn(cyrus)
	await combat.use_skill("corrosive_round", cyrus, foe.position, false)
	await settle(3)
	ok(has_condition(foe, corroded) and (combat.get_effective_stat(foe, "defense") < defence or defence == 0),
		"%s, and worse armour while it lasts" % corrosion.display_name.to_lower(), "%d -> %d" % [defence, combat.get_effective_stat(foe, "defense")])
	var mark := heard.size()
	give_turn(cyrus)
	await combat.use_skill("gun", cyrus, foe.position, false)
	await settle(3)
	ok(heard_since(mark, "sets the %s off" % corrosion.display_name.to_lower()), "a Gun hit sets it off once more (Overload)")
	var beside: Dictionary = foes[1]
	put(beside, a_tile(foe.position, func(tile): return combat._beside({"position": tile}, foe)))
	beside.status_effects.clear()
	combat._paths_at_turn_start(foe)
	ok(has_condition(beside, corroded), "as its turn starts, it spreads to the one beside it (Contagion)")

	log_line("")
	log_line("======== Trapper ========")
	await open_fight({"cyrus": "trapper"})
	cyrus = who("cyrus")
	Campaign.set_inventory("cyrus", [])
	ok(combat.items_of(cyrus) == ["small_bomb"], "a free bomb (Bombardier's Kit)", "%s" % [combat.items_of(cyrus)])
	ok(combat.secondary_skills_of(cyrus).has("snare") and combat.main_skills_of(cyrus).has("snare"), "Snare as a secondary action too (Field of Traps)")
	var ground := a_tile(cyrus.position + Vector2i(2, 0), func(tile): return combat.get_position_distance(tile, cyrus.position) >= 2 \
		and combat.get_position_distance(tile, cyrus.position) <= 3)
	give_turn(cyrus)
	await combat.use_skill("snare", cyrus, ground, false)
	await settle(2)
	ok(combat.trap_tiles().has(ground), "a snare set, and the party can see it", "%s" % ground)
	var second := a_tile(ground + Vector2i(0, 2), func(tile): return combat.trap_fits(tile) and combat.get_position_distance(tile, cyrus.position) <= 3)
	var third := a_tile(ground + Vector2i(0, -2), func(tile): return combat.trap_fits(tile) and tile != second and combat.get_position_distance(tile, cyrus.position) <= 3)
	give_turn(cyrus)
	await combat.use_skill("snare", cyrus, second, false)
	give_turn(cyrus)
	await combat.use_skill("tripwire", cyrus, third, false)
	await settle(2)
	ok(combat.traps.size() == 2 and not combat.trap_tiles().has(ground), "two at once - the oldest gives way", "%d" % combat.traps.size())
	foes = enemies()
	foe = foes[0]
	var caught: Dictionary = foes[1]
	put(caught, a_tile(third, func(tile): return combat._beside({"position": tile}, {"position": third})))
	var caught_hp: int = caught.hp
	foe.status_effects.clear()
	ok(combat.spring_trap(foe, third) and has_condition(foe, "snared"), "stepping onto the tripwire, held fast")
	ok(caught.hp < caught_hp, "and it bursts on the one beside it", "%d" % (caught_hp - caught.hp))
	var held := bonus(cyrus, foe, "gun")
	foe.erase("trapped_by")
	ok(is_equal_approx(held - bonus(cyrus, foe, "gun"), 0.25), "held by his trap, a quarter more from him (Grand Snare)", "%.2f" % (held - bonus(cyrus, foe, "gun")))
	foe["trapped_by"] = cyrus.id
	var field := a_tile(cyrus.position + Vector2i(0, 4), func(tile): return combat.get_position_distance(tile, cyrus.position) <= 6)
	var count: int = combat.traps.size()
	give_turn(cyrus)
	await combat.use_skill("minefield", cyrus, field, false)
	await settle(2)
	ok(combat.traps.size() > count + 3, "a minefield: a trap on every free tile round it", "%d more" % (combat.traps.size() - count))
	ok(combat.refusal_for(cyrus, SkillDatabase.skills.minefield, field) != "", "once a short rest")
	log_line("")


func prometheus_paths():
	log_line("======== Elemental Vanguard ========")
	await open_fight({"prometheus": "elemental_vanguard"})
	var prometheus := who("prometheus")
	var own: int = CombatantDatabase.combatants["prometheus"].movement
	ok(combat.get_effective_stat(prometheus, "movement") == own + 2, "two more tiles (Fleet Blade)", "%d" % combat.get_effective_stat(prometheus, "movement"))
	ok(["flame_edge", "frost_edge", "storm_edge", "stone_edge"].all(func(key): return prometheus.skill_list.has(key))
		and SkillDatabase.skills.flame_edge.spell_slot_level == 3 and SkillDatabase.skills.storm_edge.spell_slot_level == 4,
		"four Edges, through gates 3 and 4")
	var foe: Dictionary = enemies()[0]
	put(foe, free_beside(prometheus.position))
	prometheus["spells_cast"] = 0
	var edge := bonus(prometheus, foe, "flame_edge")
	var blast := bonus(prometheus, foe, "fire_blast")
	ok(is_equal_approx(edge - blast, 0.5), "his Edges half as hard again (Avatar)", "%.2f" % (edge - blast))
	var mark := heard.size()
	give_turn(prometheus)
	await combat.use_skill("flame_edge", prometheus, foe.position, false)
	await settle(3)
	ok(heard_since(mark, "carries a spell"), "an Edge that lands strikes again (Spellstrike)")
	ok(prometheus.get("last_element", -1) == Damage.Type.FIRE
		and combat.resisted_damage(prometheus, Damage.Type.FIRE, 100) == roundi(Damage.after_resistance(100, combat.resistance_of(prometheus, Damage.Type.FIRE)) * 0.8),
		"a fifth less of fire, having just used it (Elemental Armour)")

	log_line("")
	log_line("======== Elemental Tactician ========")
	await open_fight({"prometheus": "elemental_tactician"})
	prometheus = who("prometheus")
	var alithia := who("alithia")
	ok(combat.wards_a_round(prometheus) == 2, "two Wards a round (Shared Ward)")
	ok(combat.push_extra_of(prometheus) == 1 and combat._control_extra(prometheus, SkillDatabase.skills.hamstring.effects[0]) == 1,
		"shoves a tile further, slows a turn longer (Battlefield Control)")
	foe = enemies()[0]
	put(alithia, free_beside(prometheus.position))
	put(foe, free_beside(alithia.position))
	prometheus.reaction_used = false
	await strike(foe, alithia)
	ok(prometheus.reaction_used and prometheus.get("wards_this_round", 0) == 1, "he wards her", "%s" % prometheus.get("wards_this_round", 0))
	prometheus.reaction_used = true
	mark = heard.size()
	await strike(foe, alithia)
	ok(prometheus.get("wards_this_round", 0) == 2 and heard_since(mark, "wards"), "and again, the same round")
	give_turn(prometheus)
	var gates: Array = prometheus.spell_slots.duplicate()
	await combat.use_skill("grand_design", prometheus, prometheus.position, false, true)
	await settle(2)
	ok(combat.casts_without_gates(prometheus), "Grand Design: every gate open")
	put(foe, free_beside(prometheus.position, 3))
	await combat.use_skill("fire_blast", prometheus, foe.position, false)
	await settle(3)
	ok(prometheus.spell_slots == gates and not prometheus.skill_used_this_turn, "a spell for nothing, and the action still his", "%s" % [prometheus.spell_slots])

	log_line("")
	log_line("======== Elemental Conductor ========")
	await open_fight({"prometheus": "elemental_conductor"})
	prometheus = who("prometheus")
	ok(combat.free_amplifies(prometheus) == 2, "two free Overcharges a short rest at 64 (Overcharge, Deep Current)", "%d" % combat.free_amplifies(prometheus))
	var foes := enemies()
	foe = foes[0]
	var next: Dictionary = foes[1]
	put(foe, free_beside(prometheus.position, 3))
	put(next, a_tile(foe.position, func(tile): return combat.get_position_distance(tile, foe.position) == 2 \
		and combat.get_position_distance(tile, prometheus.position) > 2))
	for other in foes.slice(2):
		put(other, a_tile(other.position + Vector2i(15, 15), func(tile): return combat.get_position_distance(tile, foe.position) > 5))
	var next_hp: int = next.hp
	prometheus["last_spell_element"] = Damage.Type.ICE
	var changed := bonus(prometheus, foe, "fire_blast")
	prometheus["last_spell_element"] = Damage.Type.FIRE
	ok(is_equal_approx(changed - bonus(prometheus, foe, "fire_blast"), 0.15), "another element than the last, 15% harder (Resonance)")
	foe.status_effects.append({"stat": "accuracy", "amount": 0, "duration": 9, "source_name": "test"})
	prometheus.status_effects.append({"stat": "accuracy", "amount": 200, "duration": 99, "source_name": "test"})
	give_turn(prometheus)
	await combat.use_skill("fire_blast", prometheus, foe.position, false)
	await settle(3)
	ok(next.hp < next_hp, "fire leaps to one more within two (Chain)", "%d" % (next_hp - next.hp))
	ok(combat._conduit_ready(prometheus, SkillDatabase.skills.stolen_sun) and not combat._conduit_ready(prometheus, SkillDatabase.skills.fire_blast),
		"a spell through his deepest gate comes through twice - once (Conduit)")
	log_line("")


func alithia_paths():
	log_line("======== Battle Chaplain ========")
	await open_fight({"alithia": "battle_chaplain"})
	var alithia := who("alithia")
	var cyrus := who("cyrus")
	ok(SkillDatabase.skills.holy_spear.spell_slot_level == 3 and SkillDatabase.skills.censure.spell_slot_level == 5
		and SkillDatabase.skills.judgement_hammer.spell_slot_level == 6, "Holy Spear, Censure, Judgement Hammer through gates 3, 5 and 6")
	put(cyrus, free_beside(alithia.position))
	var foe: Dictionary = enemies()[0]
	put(foe, free_beside(cyrus.position, 3))
	var near_bonus := bonus(cyrus, foe, "gun")
	var was_at: Vector2i = cyrus.position
	put(cyrus, a_tile(alithia.position, func(tile): return combat.get_position_distance(tile, alithia.position) > 4))
	ok(is_equal_approx(near_bonus - bonus(cyrus, foe, "gun"), 0.15), "beside her, Cyrus hits 15% harder (Crusade)", "%.2f" % (near_bonus - bonus(cyrus, foe, "gun")))
	put(cyrus, was_at)
	cyrus.hp = 10
	alithia.status_effects.append({"stat": "accuracy", "amount": 200, "duration": 99, "source_name": "test"})
	put(foe, free_beside(alithia.position, 3) if free_beside(alithia.position, 3).x != -1 else foe.position)
	give_turn(alithia)
	await combat.use_skill("water_spike", alithia, foe.position, false)
	await settle(2)
	ok(cyrus.hp == 10, "a cantrip is no spell to be Righteous with")
	give_turn(alithia)
	await combat.use_skill("judgment", alithia, foe.position, false)
	await settle(3)
	ok(cyrus.hp > 10, "her damaging spell mends Cyrus beside her (Righteous)", "%d" % cyrus.hp)

	log_line("")
	log_line("======== Illusory Shepherd ========")
	await open_fight({"alithia": "illusory_shepherd"})
	alithia = who("alithia")
	cyrus = who("cyrus")
	var enfina := who("enfina")
	put(cyrus, free_beside(alithia.position))
	cyrus.hp = 10
	cyrus.status_effects.clear()
	give_turn(alithia)
	await combat.use_skill("heal", alithia, cyrus.position, false)
	await settle(2)
	ok(has_condition(cyrus, "veiled") and has_condition(cyrus, "blurred"), "healed, veiled and blurred (Veil of Mercy I, II)")
	ok(cyrus.get("temp_hp", 0) > 0 and cyrus.get("temp_hp_turns", 0) == 2, "and shielded for two turns (Veil of Mercy III)", "%d" % cyrus.get("temp_hp", 0))
	ok(cyrus.status_effects.any(func(e): return e.get("stat", "") == "movement" and e.get("amount", 0) == 2), "and guided on, two tiles (Guiding Phantasm)")
	combat._paths_at_turn_start(cyrus)
	combat._paths_at_turn_start(cyrus)
	ok(cyrus.get("temp_hp", 0) == 0, "the shield gone after two of his turns")
	var foe2: Dictionary = enemies()[0]
	put(foe2, free_beside(enfina.position))
	sturdy(enfina)
	await strike(foe2, enfina)
	ok(enfina.hp == 9999 and enfina.get("first_blow_missed", false), "the first blow on Enfina finds an illusion (Illusory Guardian)")
	cyrus.first_blow_missed = true
	cyrus.status_effects.clear()
	sturdy(cyrus)
	give_turn(alithia)
	await combat.use_skill("phantom_body", alithia, cyrus.position, false)
	await settle(2)
	put(foe2, free_beside(cyrus.position))
	await strike(foe2, cyrus)
	ok(cyrus.hp == 9999 and not has_condition(cyrus, "phantom_body"), "a phantom over Cyrus takes the next blow (Phantom Body)")
	var spot := a_tile(alithia.position + Vector2i(2, 0), func(tile): return combat.get_position_distance(tile, alithia.position) >= 2 \
		and combat.get_position_distance(tile, alithia.position) <= 5)
	give_turn(alithia)
	await combat.use_skill("illusory_cover", alithia, spot, false)
	await settle(2)
	var cover: Dictionary = combat.get_combatant_at(spot)
	ok(cover.get("object") != null and cover.name == "Illusory Cover", "cover that is not there (Illusory Cover)", "%s" % cover.get("name", "nothing"))
	var by_it := a_tile(spot, func(tile): return combat._beside({"position": tile}, {"position": spot}))
	combat.ai_believes = true
	ok(combat.in_cover(cyrus, by_it), "to the other side's mind, beside it is cover")
	combat.ai_believes = false
	ok(not combat.in_cover(cyrus, by_it), "and in truth it is not")
	var west: Vector2i = spot + Vector2i(-2, 0)
	var east: Vector2i = spot + Vector2i(2, 0)
	if combat.controller.is_on_map(west) and combat.controller.is_on_map(east) and combat.has_line_of_sight(west, east, 0):
		combat.ai_believes = true
		ok(not combat.has_line_of_sight(west, east, 0), "to their mind it blocks the line past it; in truth the line is clear")
		combat.ai_believes = false
	ok(cover.get("illusion", false) and not combat.get_targets_in_tiles([spot], enemies()[0], false, true).has(cover),
		"a blast goes straight through it")
	for i in 3:
		combat._paths_at_turn_start(alithia)
	ok(not cover.get("alive", true), "it fades after three of her turns")

	cyrus.status_effects.clear()
	alithia.status_effects.clear()
	put(cyrus, free_beside(alithia.position))
	give_turn(alithia)
	await combat.use_skill("sanctuary_of_light", alithia, alithia.position, false)
	await settle(2)
	ok(combat.zones.size() == 1 and has_condition(cyrus, "sanctified") and has_condition(alithia, "sanctified"),
		"a sanctuary left on the ground round her, and her side in it sanctified (Sanctuary of Light)")
	var inside_at: Vector2i = cyrus.position
	put(cyrus, a_tile(alithia.position, func(tile): return combat.get_position_distance(tile, alithia.position) > 4))
	combat.sync_zones()
	ok(not has_condition(cyrus, "sanctified"), "stepping out of it, no longer")
	put(cyrus, inside_at)
	combat.sync_zones()
	ok(has_condition(cyrus, "sanctified"), "back in, again")
	var foe_in: Dictionary = enemies()[0]
	put(foe_in, a_tile(alithia.position, func(tile): return combat.get_position_distance(tile, alithia.position) <= 2))
	combat.sync_zones()
	ok(not has_condition(foe_in, "sanctified"), "only for her side")
	put(foe_in, a_tile(alithia.position, func(tile): return combat.get_position_distance(tile, alithia.position) > 6))
	combat._paths_at_turn_start(alithia)
	ok(combat.zones.size() == 1 and has_condition(cyrus, "sanctified"), "one of her turns on, still there")
	combat._paths_at_turn_start(alithia)
	ok(combat.zones.is_empty() and not has_condition(cyrus, "sanctified"), "two, and it fades - and what it gave with it")
	give_turn(alithia)
	await combat.use_skill("mass_mirage", alithia, alithia.position, false)
	await settle(2)
	ok(has_condition(cyrus, "mirage") and has_condition(alithia, "mirage"), "a mirage on the ground round her (Mass Mirage)")
	combat._paths_at_turn_start(alithia)
	ok(combat.zones.is_empty() and not has_condition(cyrus, "mirage"), "gone as her next turn begins")
	# The whole party gathered round her, every one of them caught.
	var party: Array = combat.combatants.filter(func(c): return c.side == 0 and c.alive and not c.get("illusion", false) and not c.has("object"))
	for member in party:
		if member != alithia and combat.get_position_distance(member.position, alithia.position) > 2:
			put(member, a_tile(alithia.position, func(tile): return combat.get_position_distance(tile, alithia.position) <= 2))
	var count: int = combat.combatants.size()
	give_turn(alithia)
	await combat.use_skill("realitys_reflection", alithia, alithia.position, false)
	await settle(3)
	ok(combat.combatants.size() > count, "an image of each beside them (Reality's Reflection)")
	ok(party.all(func(member): return combat.is_invisible(member)), "and every one of the party invisible - the images hold the eye",
		"%s" % [party.map(func(member): return "%s %s" % [member.name, combat.is_invisible(member)])])
	ok(combat.zones.any(func(zone): return zone.condition == condition("reflected")) and not combat.zone_tiles().is_empty(),
		"a reflection left on the ground, which the party can see")
	var cyrus_was_at: Vector2i = cyrus.position
	put(cyrus, a_tile(alithia.position, func(tile): return combat.get_position_distance(tile, alithia.position) > 5))
	combat.sync_zones()
	ok(not combat.is_invisible(cyrus), "stepping out of it, Cyrus can be seen")
	put(cyrus, cyrus_was_at)
	combat.sync_zones()
	ok(combat.is_invisible(cyrus), "back in, he cannot")
	combat._invisibility_ends(cyrus)
	combat.sync_zones()
	ok(not combat.is_invisible(cyrus), "acting against an enemy gives him away, in it or not")
	combat._paths_at_turn_start(cyrus)
	ok(combat.is_invisible(cyrus), "until his next turn starts, still in it")
	for image in combat.combatants.duplicate():
		if image.get("illusion", false) and image.alive and image.has("image_of"):
			combat._shatter(image)
	ok(not combat.is_hidden(alithia) and party.all(func(member): return member == alithia or combat.is_invisible(member)),
		"the last image gone, she is given away - the others stay hidden behind her")
	# Her next turn: given away, she is seen until it starts.
	combat._paths_at_turn_start(alithia)
	alithia.spell_slots = Stats.gates_for_level(64)
	give_turn(alithia)
	await combat.use_skill("realitys_reflection", alithia, alithia.position, false)
	await settle(3)
	ok(party.all(func(member): return combat.is_invisible(member)), "cast again, all of them out of sight")
	alithia.hp = 0
	combat.combatant_die(alithia)
	await settle(2)
	ok(party.all(func(member): return not combat.is_hidden(member)), "and with her fallen, everybody is in sight again",
		"%s" % [party.map(func(member): return "%s %s" % [member.name, combat.is_hidden(member)])])
	ok(combat.zones.any(func(zone): return zone.owner_id == alithia.id), "her reflection stays on the ground")
	combat.sync_zones()
	ok(party.all(func(member): return member == alithia or not combat.is_hidden(member)), "and hides nobody again before their next turn")
	var reflection: Dictionary = combat.zones.filter(func(zone): return zone.owner_id == alithia.id)[0]
	var left: int = reflection.turns
	combat._zones_round_begins()
	ok(reflection.turns == left - 1, "its time counted by the round, with her down", "%d -> %d" % [left, reflection.turns])

	log_line("")
	log_line("======== illusions, the other side's ========")
	var foes := enemies()
	var maker: Dictionary = foes[0]
	var of: Dictionary = foes[1]
	var before_count: int = combat.combatants.size()
	combat.summon_decoy(maker, of, SkillDatabase.skills.mirror_image)
	var theirs: Dictionary = combat.combatants.back() if combat.combatants.size() > before_count else {}
	ok(theirs.get("illusion", false) and theirs.get("name", "") == of.name and theirs.sprite.modulate == Color.WHITE,
		"an image of one of them looks just like them to the party", "%s" % theirs.get("name", "none"))
	var spot_for_ours := a_tile(cyrus.position, func(tile): return combat._beside({"position": tile}, cyrus))
	combat._placing_at = spot_for_ours
	combat.summon_decoy(cyrus, cyrus, SkillDatabase.skills.mirror_image)
	combat._placing_at = Combat.NO_AREA
	var ours: Dictionary = combat.combatants.back()
	give_turn(cyrus)
	combat.controller._skill_selected = true
	ok(combat.party_believes() and combat.believes_illusion(theirs) and not combat.believes_illusion(ours),
		"aiming, the party takes theirs for real - not its own")
	combat.controller._skill_selected = false
	ok(not combat.believes_illusion(theirs) and not combat.believes_illusion(ours), "and what happens goes through both")
	combat.ai_believes = true
	combat._believer_side = Combat.Group.ENEMIES
	ok(combat.believes_illusion(ours) and not combat.believes_illusion(theirs), "the other side takes ours for real - not its own")
	combat.ai_believes = false
	var hiding := EffectDefinition.new()
	hiding.type = EffectDefinition.EffectType.ZONE
	hiding.zone_condition = condition("reflected")
	hiding.zone_unseen = true
	var drawn: int = combat.zone_tiles().size()
	combat.lay_zone(maker, hiding, [maker.position], SkillDatabase.skills.realitys_reflection)
	ok(combat.zones.size() > 0 and combat.zone_tiles().size() == drawn, "a reflection of theirs is not drawn for the party")

	log_line("")
	log_line("======== Inquisitor ========")
	await open_fight({"alithia": "inquisitor"})
	alithia = who("alithia")
	foe = enemies()[0]
	put(foe, free_beside(alithia.position, 3))
	ok(combat.refusal_for(alithia, SkillDatabase.skills.accusation, foe.position) != "", "Accusation only on somebody read")
	foe.erase("studied")
	combat.read_intent(alithia, foe)
	ok(foe.has("intent") and foe.get("studied", false), "reading studies him too (Inquest)")
	ok(combat.refusal_for(alithia, SkillDatabase.skills.accusation, foe.position) == "", "read, he can be accused")
	var plain: float = combat.progression_damage_bonus(alithia, enemies()[1], SkillDatabase.skills.judgment)
	ok(bonus(alithia, foe, "judgment") > plain, "read, he is hit a quarter harder (Sentence)")
	ok(combat._pierces_read(alithia, foe, SkillDatabase.skills.judgment), "and her Judgment goes through all his defence (Final Judgment)")
	give_turn(alithia)
	await combat.use_skill("accusation", alithia, foe.position, false)
	await settle(2)
	ok(has_condition(foe, "accused"), "accused")
	give_turn(alithia)
	await combat.use_skill("recant", alithia, foe.position, false, true)
	await settle(2)
	ok(combat.has_restriction(foe, "skips_turn"), "and his foreseen turn simply lost (Recant)")
	log_line("")


## Every character on every path at level 64: the action panel offers every one
## of their main and secondary skills.
func all_fit():
	log_line("======== every kit has a button for everything ========")
	await open_fight({})
	var ui = combat.game_ui
	var buttons: int = ui.get_node("Actions/ActionsPanel/ActionsGrid").get_child_count()
	ui.showing_spells = false
	for key in ["cyrus", "enfina", "prometheus", "alithia"]:
		var definition: CombatantDefinition = CombatantDatabase.combatants[key]
		for path in definition.subclasses:
			var comb: Dictionary = combat.create_combatant(definition, key, "", null, Stats.MAX_LEVEL, path)
			comb["side"] = 0
			for panel in [ui.SkillPanel.MAIN, ui.SkillPanel.SECONDARY]:
				var wanted: Array = combat.main_skills_of(comb) if panel == ui.SkillPanel.MAIN else combat.secondary_skills_of(comb)
				ui.showing_panel = panel
				ui._show_skills_for(comb)
				var offered: Array = ui.action_buttons().filter(func(b): return b.tooltip_text != "").map(func(b): return b.get_meta(ui.SKILL_META, ""))
				var missing: Array = wanted.filter(func(skill): return not offered.has(skill))
				ok(missing.is_empty(), "%s the %s, %s" % [key.capitalize(), path.capitalize(), "main" if panel == ui.SkillPanel.MAIN else "secondary"],
					"%d skills%s%s" % [wanted.size(), " on a shelf that scrolls" if wanted.size() > buttons and ui.showing_shelves() else "",
						", missing %s" % [missing] if not missing.is_empty() else ""])
	ui.showing_panel = ui.SkillPanel.MAIN
	log_line("")
