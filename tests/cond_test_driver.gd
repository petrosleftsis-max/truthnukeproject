extends Node
## Tests the eight conditions, plus both-sides targeting.

var LOG_PATH := HarnessLog.path_for("cond")

var _log: FileAccess = null
var _fail = 0
var combat = null
var controller = null


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
	get_tree().create_timer(120.0).timeout.connect(func(): get_tree().quit(2))
	await get_tree().process_frame
	await get_tree().process_frame
	await run_test()


func condition(name: String) -> ConditionDefinition:
	return load("res://conditions/%s.tres" % name)


## Puts `name` on `comb` directly, as a skill would.
func afflict(comb: Dictionary, name: String):
	var def = condition(name)
	comb.status_effects.append({
		"stat": "condition", "condition": def,
		"duration": def.duration, "source_name": "test"
	})


func run_test():
	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_01_ambush.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	combat = game.get_node("VisualCombat")
	controller = game.get_node("Controller")
	combat.finish_deployment()
	await get_tree().process_frame

	var hero = null
	var foe = null
	for comb in combat.combatants:
		if comb.side == 0 and hero == null:
			hero = comb
		elif comb.side == 1 and foe == null:
			foe = comb

	log_line("======== all eight conditions load ========")
	for name in ["stunned", "blind", "fear", "crystallised", "windswept", "poisoned", "burn", "frozen"]:
		var def = condition(name)
		ok(def != null and def.display_name != "", "%s" % name, "'%s' - %s" % [def.display_name, def.describe()])
	log_line("")

	log_line("======== Blind caps skill range at 1 ========")
	var bolt: SkillDefinition = SkillDatabase.skills["gun"]
	ok(combat.effective_max_range(hero, bolt) == bolt.max_range, "unaffected reach is the skill's own", "%d" % combat.effective_max_range(hero, bolt))
	afflict(hero, "blind")
	ok(combat.effective_max_range(hero, bolt) == 1, "blinded reach is 1", "%d" % combat.effective_max_range(hero, bolt))
	ok(combat.get_range_tiles(bolt, hero.position, 0, hero).size() < 10,
		"the range preview shrinks with it", "%d tiles" % combat.get_range_tiles(bolt, hero.position, 0, hero).size())
	hero.status_effects.clear()
	log_line("")

	log_line("======== Fear: -20 accuracy, and no advancing ========")
	var accuracy_before = combat.get_effective_stat(hero, "accuracy")
	afflict(hero, "fear")
	ok(combat.get_effective_stat(hero, "accuracy") == accuracy_before - 20, "accuracy drops by 20",
		"%d -> %d" % [accuracy_before, combat.get_effective_stat(hero, "accuracy")])
	combat.current_combatant = combat.combatants.find(hero)
	var nearest = combat.find_nearest_enemy_of(hero)
	var distance_now = combat.get_position_distance(hero.position, nearest.position)
	var closer = hero.position + (nearest.position - hero.position).sign()
	ok(not controller.can_move_to(closer), "can't step towards the nearest enemy", "%s -> %s" % [hero.position, closer])
	var away = hero.position - (nearest.position - hero.position).sign()
	ok(controller.can_move_to(away), "but can back away", "%s" % away)
	ok(controller.can_move_to(hero.position), "and can hold position")

	# The pathfinding grid itself should now refuse the closer tiles, so the
	# movement preview can only ever offer legal destinations.
	controller.set_controlled_combatant(hero)
	ok(controller._fear_blocked.size() > 0, "closer tiles closed off on the grid", "%d tiles" % controller._fear_blocked.size())
	# Take one the fear itself closed, so this isn't testing a wall by accident.
	var fear_tile = controller._fear_blocked[0]
	ok(combat.get_position_distance(fear_tile, nearest.position) < distance_now,
		"a closed tile really is nearer the enemy", "%s" % fear_tile)
	ok(controller._astargrid.is_point_solid(fear_tile), "it is unwalkable while afraid")
	ok(not controller._astargrid.is_point_solid(hero.position), "their own tile stays walkable")
	controller.find_path(fear_tile)
	ok(controller._path.size() == 0 or controller.tile_map.local_to_map(controller._path[controller._path.size() - 1]) != fear_tile,
		"no route can be planned onto it", "%d steps" % controller._path.size())
	var reachable = controller.get_reachable_tiles(hero.position, hero.movement_class, 6)
	ok(not reachable.has(fear_tile), "and the AI isn't offered it either")

	# Once the fear passes, the grid must open back up.
	hero.status_effects.clear()
	controller.set_controlled_combatant(hero)
	ok(controller._fear_blocked.is_empty(), "fear tiles released when it wears off")
	ok(not controller._astargrid.is_point_solid(fear_tile), "and that tile is walkable again", "%s" % fear_tile)
	log_line("")

	# What each condition forbids is a design dial, turned more than once
	# already, so these read the rule off the resource and check the battle
	# obeys it rather than writing yesterday's answer down a second time.
	hero.status_effects.clear()
	controller.set_controlled_combatant(hero)
	var free_movement = controller.movement

	log_line("======== Crystallised: rooted ========")
	var crystallised: ConditionDefinition = load("res://conditions/crystallised.tres")
	afflict(hero, "crystallised")
	controller.set_controlled_combatant(hero)
	ok(controller.movement == 0, "movement is zero", "%d" % controller.movement)
	ok(combat.secondary_skills_of(hero).is_empty() == crystallised.prevents_secondary,
		"the secondary slot agrees with the condition",
		"prevents_secondary is %s, offered %s" % [crystallised.prevents_secondary,
			combat.secondary_skills_of(hero)])
	var hp_before = hero.hp
	combat.process_status_effects(hero)
	ok(hero.hp < hp_before, "and it burns them each turn", "%d -> %d" % [hp_before, hero.hp])
	hero.status_effects.clear()
	log_line("")

	log_line("======== Frozen: stiff, and slowed ========")
	var frozen: ConditionDefinition = load("res://conditions/frozen.tres")
	afflict(hero, "frozen")
	controller.set_controlled_combatant(hero)
	ok(controller.movement == maxi(free_movement + frozen.movement_change, 0),
		"slowed by exactly what it says and no more",
		"%d free, %+d frozen, %d now" % [free_movement, frozen.movement_change, controller.movement])
	ok(combat.secondary_skills_of(hero).is_empty() == frozen.prevents_secondary,
		"the secondary slot agrees with the condition",
		"prevents_secondary is %s, offered %s" % [frozen.prevents_secondary,
			combat.secondary_skills_of(hero)])
	hero.status_effects.clear()
	log_line("")

	log_line("======== Poisoned: no reactions ========")
	afflict(foe, "poisoned")
	ok(combat.has_restriction(foe, "prevents_reactions"), "flagged as unable to react")
	foe.reaction_used = false
	var mover_from = hero.position
	# Walk the hero out of the poisoned foe's melee reach; normally that would
	# provoke an opportunity attack.
	hero.position = foe.position + Vector2i(1, 0)
	var hp_before_move = hero.hp
	await combat.check_reactive_skills(hero, hero.position, foe.position + Vector2i(5, 0))
	ok(hero.hp == hp_before_move, "a poisoned combatant doesn't take the opening", "%d" % hero.hp)
	hero.position = mover_from
	foe.status_effects.clear()
	log_line("")

	log_line("======== Burn: strong DOT, +2 movement ========")
	var movement_before = combat.get_effective_stat(hero, "movement")
	afflict(hero, "burn")
	ok(combat.get_effective_stat(hero, "movement") == movement_before + 2, "movement rises by 2",
		"%d -> %d" % [movement_before, combat.get_effective_stat(hero, "movement")])
	var burn_hp = hero.hp
	combat.process_status_effects(hero)
	ok(burn_hp - hero.hp >= 3, "and it hurts more than the others", "%d damage" % (burn_hp - hero.hp))
	hero.status_effects.clear()
	log_line("")

	# The Crystallised and Burn sections above both tick damage onto the hero,
	# and enough of it kills them - after which drift correctly refuses to move
	# a corpse, and every check below is vacuous. Put them back on their feet.
	hero.hp = combat.get_effective_stat(hero, "max_hp")
	hero.alive = true
	log_line("======== Windswept: slowed, and blown about ========")
	var wind_movement_before = combat.get_effective_stat(hero, "movement")
	afflict(hero, "windswept")
	ok(combat.get_effective_stat(hero, "movement") == wind_movement_before - 3, "movement drops by 3",
		"%d -> %d" % [wind_movement_before, combat.get_effective_stat(hero, "movement")])
	var drifted = 0
	# Somewhere with room around it. Wherever the encounter happens to put the
	# hero may be hemmed in on the current map, and drift correctly refusing to
	# move is not the same as drift being broken.
	var wind_start = open_tile(combat, controller, hero)
	ok(wind_start != Vector2i(-1, -1), "found somewhere open to be blown around in", "%s" % wind_start)
	hero.position = wind_start
	# Drift picks one of eight directions at random and gives up if that one is
	# blocked, so a single attempt proving nothing is expected. Enough attempts
	# that never moving means the feature is broken, not that the dice went cold.
	for attempt in range(0, 40):
		hero.position = wind_start
		var was = hero.position
		combat.apply_drift(hero)
		if hero.position != was:
			drifted += 1
			# Chebyshev, not Manhattan: movement here is 8-directional, so
			# three diagonal steps is three tiles travelled even though the
			# Manhattan distance is six. Same reason apply_knockback measures
			# a pull this way.
			var steps = maxi(absi(hero.position.x - was.x), absi(hero.position.y - was.y))
			ok(steps <= 3, "blown no further than 3 tiles", "%s -> %s, %d steps" % [was, hero.position, steps])
			break
	ok(drifted > 0, "the wind actually moves them")
	hero.status_effects.clear()
	log_line("")

	log_line("======== Stunned loses the turn ========")
	afflict(foe, "stunned")
	ok(combat.has_restriction(foe, "skips_turn"), "flagged as losing their turn")
	var turns_before = foe.get("turn_taken", false)
	hero.status_effects.clear()
	foe.status_effects.clear()
	log_line("")

	log_line("======== durations tick down and clear ========")
	afflict(hero, "poisoned")
	var poison_turns = 0
	for turn in range(0, 8):
		combat.process_status_effects(hero)
		if hero.status_effects.is_empty():
			break
		poison_turns += 1
	ok(poison_turns == condition("poisoned").duration,
		"Poisoned lasts its configured duration", "%d of %d" % [poison_turns, condition("poisoned").duration])
	log_line("")

	log_line("======== skills that affect both sides ========")
	# Every condition above has been chewing on the hero, and the damage is
	# random - patch them up so this section isn't testing a corpse.
	hero.hp = hero.max_hp
	hero.alive = true
	foe.hp = foe.max_hp
	foe.alive = true
	var tiles = [hero.position, foe.position]
	var enemies_only = combat.get_targets_in_tiles(tiles, hero, false, false)
	var everyone = combat.get_targets_in_tiles(tiles, hero, false, true)
	ok(enemies_only.size() == 1, "normally only the opposing side is hit", "%d" % enemies_only.size())
	ok(everyone.size() == 2, "with affects_both_sides, allies are caught too", "%d" % everyone.size())
	log_line("")

	log_line("======== push tooltip mentions damage once, as conditional ========")
	var ui = game.get_node("CanvasLayer/UI")
	var repel: SkillDefinition = SkillDatabase.skills["gust_blast"]
	var tooltip = ui.build_skill_tooltip(repel)
	# "only if they hit a wall" was wrong: a shove stopped by a body hurts both.
	ok(tooltip.contains("on collision"), "collision damage is marked as collision damage")
	ok(not tooltip.contains("hit a wall"), "and no longer claims a wall is needed")
	log_line("  tooltip effects: %s" % tooltip.split("Effects:")[-1].strip_edges().replace("\n", " | "))
	log_line("")

	log_line("======== the AI plans around its own conditions ========")
	var enemy = null
	for comb in combat.combatants:
		if comb.side == 1:
			enemy = comb
	enemy.hp = enemy.max_hp
	enemy.alive = true
	var free_budget = combat.movement_budget_of(enemy)
	ok(free_budget > 0, "unafflicted budget is its movement", "%d" % free_budget)
	afflict(enemy, "crystallised")
	ok(combat.movement_budget_of(enemy) == 0, "a rooted enemy plans for no movement", "%d" % combat.movement_budget_of(enemy))
	enemy.status_effects.clear()

	# Blind caps how far anything reaches to one tile. What that rules out is a
	# skill that has to be used from further away - a minimum range above one -
	# rather than simply a long-ranged one: a gun that can be fired point blank
	# is still a gun when you cannot see.
	var too_far := ""
	for key in SkillDatabase.skills:
		var candidate: SkillDefinition = SkillDatabase.skills[key]
		if candidate != null and not (candidate is ItemDefinition) 				and candidate.deals_damage and candidate.min_range > 1:
			too_far = key
			break
	if too_far != "" and not (too_far in enemy.skill_list):
		enemy.skill_list.append(too_far)
	var picked_clear = combat.find_best_single_target_skill(enemy)
	afflict(enemy, "blind")
	var picked_blind = combat.find_best_single_target_skill(enemy)
	# The rule, rather than a particular swap: whatever it settles on, it has to
	# be something it could actually use with everything one tile away.
	var chosen: SkillDefinition = SkillDatabase.skills[picked_blind]
	ok(combat.effective_max_range(enemy, chosen) >= chosen.min_range,
		"a blinded enemy picks something it can still use at one tile",
		"%s -> %s (reaches %d, needs %d)" % [picked_clear, picked_blind,
			combat.effective_max_range(enemy, chosen), chosen.min_range])
	if too_far != "":
		ok(picked_blind != too_far,
			"and gives up anything it would have to stand back for", too_far)
	else:
		log_line("  (no skill in the game has a minimum range above one to give up)")
	var aim = combat.find_best_aim_and_count(SkillDatabase.skills["fireball"], enemy.position, enemy.movement_class, enemy)
	ok(combat.get_position_distance(enemy.position, aim.position) <= 1,
		"its aim search is capped too", "aimed %d tiles away" % combat.get_position_distance(enemy.position, aim.position))
	enemy.status_effects.clear()
	log_line("")

	log_line("======== windswept drift respects the map ========")
	# Drift a rooted-in-place combatant many times and confirm it never lands
	# on a wall, a hole, another combatant, or off the map.
	afflict(hero, "windswept")
	var start = open_tile(combat, controller, hero)
	ok(start != Vector2i(-1, -1), "found somewhere walkable to drift from", "%s" % start)
	var bad_landings = 0
	for attempt in range(0, 200):
		hero.position = start
		combat.apply_drift(hero)
		var landed = hero.position
		if not controller.is_in_bounds(landed):
			bad_landings += 1
		elif controller.is_tile_blocking(landed, hero.movement_class):
			bad_landings += 1
		elif landed != start and not combat.get_combatant_at(landed).is_empty() and combat.get_combatant_at(landed) != hero:
			bad_landings += 1
	ok(bad_landings == 0, "200 drifts, never onto a wall, hole, occupant or off-map", "%d bad" % bad_landings)
	hero.status_effects.clear()
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)

## A walkable, unoccupied tile with at least one walkable neighbour, found on
## whatever map is loaded. Hardcoded coordinates keep silently turning into
## walls as the terrain gets repainted, and a drift that correctly refuses to
## move then reads as a broken drift.
func open_tile(combat, controller, comb) -> Vector2i:
	var region = controller._astargrid.region
	for x in range(region.position.x, region.position.x + region.size.x):
		for y in range(region.position.y, region.position.y + region.size.y):
			var tile = Vector2i(x, y)
			if controller.is_tile_blocking(tile, comb.movement_class):
				continue
			if not combat.get_combatant_at(tile).is_empty():
				continue
			var room = 0
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					var near = tile + Vector2i(dx, dy)
					if near == tile or not controller.is_in_bounds(near):
						continue
					if not controller.is_tile_blocking(near, comb.movement_class) and combat.get_combatant_at(near).is_empty():
						room += 1
			if room >= 5:
				return tile
	return Vector2i(-1, -1)
