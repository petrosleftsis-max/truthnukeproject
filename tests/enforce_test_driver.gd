extends Node
## Every condition, checked against what it actually promises.
##
## The definitions are only data; what matters is whether the rules are
## enforced on the map, for the AI as well as the player. Crystallised claims
## to stop somebody moving, Windswept claims to blow them about - so this puts
## each one on a real combatant in a real battle and watches what happens.

var LOG_PATH := HarnessLog.path_for("enforce")
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
	get_tree().create_timer(240.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


## Puts `condition` on `comb` the way apply_effect does.
func afflict(comb: Dictionary, name: String, turns: int = 3) -> ConditionDefinition:
	var condition: ConditionDefinition = load("res://conditions/%s.tres" % name)
	comb.status_effects.append({
		"stat": "condition",
		"condition": condition,
		"dot_base": 4.0,
		"duration": turns,
		"source_name": "the test",
	})
	return condition


func cure(comb: Dictionary):
	comb.status_effects.clear()


func act_as(combat, controller, comb: Dictionary):
	for i in combat.combatants.size():
		if is_same(combat.combatants[i], comb):
			combat.current_combatant = i
	controller.set_controlled_combatant(comb)


## Walks `comb` at `tile` the way a player's click does, and waits it out.
func try_to_walk(combat, controller, comb: Dictionary, tile: Vector2i):
	act_as(combat, controller, comb)
	controller.find_path(tile)
	controller.move_player()
	var waited = 0
	while not controller._arrived and waited < 180:
		await get_tree().process_frame
		waited += 1


func free_tile_near(combat, comb, from: Vector2i, reach: int) -> Vector2i:
	for radius in range(1, reach + 1):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				var tile = from + Vector2i(dx, dy)
				if combat.get_position_distance(from, tile) > reach:
					continue
				if tile == comb.position:
					continue
				if combat.can_land_on(comb, tile):
					return tile
	return Vector2i(-99999, -99999)


func run_test():
	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_02_sappers.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	for i in 6:
		await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	var controller = combat.controller
	if combat.deployment_active:
		combat.finish_deployment()
		await get_tree().process_frame

	var hero = null
	var enemy = null
	for comb in combat.combatants:
		if comb.alive and comb.side == 0 and hero == null:
			hero = comb
		elif comb.alive and comb.side == 1 and enemy == null:
			enemy = comb
	ok(hero != null and enemy != null, "somebody to afflict")

	log_line("======== Crystallised: cannot move ========")
	cure(hero)
	afflict(hero, "crystallised")
	ok(combat.has_restriction(hero, "prevents_movement"), "the restriction is read off it")
	ok(combat.movement_budget_of(hero) == 0, "their budget is nothing",
		"%d" % combat.movement_budget_of(hero))
	act_as(combat, controller, hero)
	ok(controller.movement == 0, "and the controller agrees", "%d" % controller.movement)
	var stood_on = hero.position
	var step = free_tile_near(combat, hero, hero.position, 1)
	if step != Vector2i(-99999, -99999):
		await try_to_walk(combat, controller, hero, step)
		ok(hero.position == stood_on, "clicking a tile moves them nowhere at all",
			"%s -> %s" % [stood_on, hero.position])
	# Which restrictions Crystallised carries is a design dial, and it has been
	# turned - it rooted you AND cost you the secondary action, now only the
	# first. Read off the resource so retuning it again does not read as a bug.
	var rooted: ConditionDefinition = load("res://conditions/crystallised.tres")
	ok(combat.has_restriction(hero, "prevents_secondary") == rooted.prevents_secondary,
		"and the secondary action agrees with what the condition claims",
		"prevents_secondary is %s" % rooted.prevents_secondary)
	cure(hero)
	log_line("")

	log_line("======== Crystallised: the AI cannot move either ========")
	cure(enemy)
	afflict(enemy, "crystallised")
	var enemy_stood_on = enemy.position
	act_as(combat, controller, enemy)
	var towards = free_tile_near(combat, enemy, hero.position, 2)
	if towards != Vector2i(-99999, -99999):
		await controller.ai_process(towards)
		ok(enemy.position == enemy_stood_on, "a crystallised enemy stays put on its turn",
			"%s -> %s" % [enemy_stood_on, enemy.position])
	cure(enemy)
	log_line("")

	log_line("======== Windswept: slowed, and blown about ========")
	cure(hero)
	var walking = combat.get_effective_stat(hero, "movement")
	afflict(hero, "windswept")
	ok(combat.get_effective_stat(hero, "movement") == walking - 3,
		"three tiles slower", "%d -> %d" % [walking, combat.get_effective_stat(hero, "movement")])
	# Somewhere with room on every side, so being blocked cannot be the reason
	# nothing happens.
	var open = Vector2i(-99999, -99999)
	for x in range(controller._astargrid.region.position.x + 2, controller._astargrid.region.end.x - 2):
		for y in range(controller._astargrid.region.position.y + 2, controller._astargrid.region.end.y - 2):
			var middle = Vector2i(x, y)
			var clear = true
			for dx in [-3, -2, -1, 0, 1, 2, 3]:
				for dy in [-3, -2, -1, 0, 1, 2, 3]:
					var around = middle + Vector2i(dx, dy)
					if around != middle and not combat.can_land_on(hero, around):
						clear = false
			if clear:
				open = middle
				break
		if open != Vector2i(-99999, -99999):
			break
	if open != Vector2i(-99999, -99999):
		combat.teleport_to(hero, open)
		var blown_from = hero.position
		combat.apply_drift(hero)
		ok(hero.position != blown_from, "and blown off their tile with room all round",
			"%s -> %s" % [blown_from, hero.position])
		ok(hero.sprite.position == Grid.tile_to_world(hero.position),
			"the sprite goes with them")
	else:
		log_line("  (no open ground on this map to test drift in)")
	# And hemmed in on most sides, it should still find the way that is open.
	var boxed = Vector2i(-99999, -99999)
	for comb in combat.combatants:
		if comb.alive and not is_same(comb, hero):
			var beside = free_tile_near(combat, hero, comb.position, 1)
			if beside != Vector2i(-99999, -99999):
				boxed = beside
				break
	if boxed != Vector2i(-99999, -99999):
		combat.teleport_to(hero, boxed)
		var pressed_from = hero.position
		var moved_at_all = false
		for attempt in 6:
			combat.apply_drift(hero)
			if hero.position != pressed_from:
				moved_at_all = true
				break
		ok(moved_at_all, "and blown about even with a body beside them",
			"%s -> %s" % [pressed_from, hero.position])
	cure(hero)
	log_line("")

	log_line("======== Stunned: loses the turn ========")
	cure(enemy)
	afflict(enemy, "stunned")
	ok(combat.has_restriction(enemy, "skips_turn"), "the restriction is read off it")
	var where = enemy.position
	var health = enemy.hp
	# Hand the turn to them and let the loop deal with it.
	for i in combat.combatants.size():
		if is_same(combat.combatants[i], enemy):
			combat.current_combatant = i - 1 if i > 0 else combat.combatants.size() - 1
	await combat.advance_turn()
	ok(not is_same(combat.get_current_combatant(), enemy) or not enemy.alive,
		"the turn passes them by", combat.get_current_combatant().name)
	ok(enemy.position == where, "and they do not act", "%s" % enemy.position)
	cure(enemy)
	log_line("")

	log_line("======== Blind: everything reaches one tile ========")
	cure(hero)
	afflict(hero, "blind")
	var far_skill: SkillDefinition = null
	for key in hero.skill_list:
		var skill: SkillDefinition = SkillDatabase.skills[key]
		if skill.max_range > 1:
			far_skill = skill
			break
	if far_skill != null:
		ok(combat.effective_max_range(hero, far_skill) == 1,
			"%s reaches one tile instead of %d" % [far_skill.name, far_skill.max_range],
			"%d" % combat.effective_max_range(hero, far_skill))
	cure(hero)
	log_line("")

	log_line("======== Burn: it drives them on ========")
	cure(hero)
	var before_burn = combat.get_effective_stat(hero, "movement")
	afflict(hero, "burn")
	ok(combat.get_effective_stat(hero, "movement") == before_burn + 2,
		"two tiles faster while alight", "%d -> %d" % [before_burn, combat.get_effective_stat(hero, "movement")])
	var burning = hero.hp
	combat.process_status_effects(hero)
	ok(hero.hp < burning, "and it burns them each turn", "%d -> %d" % [burning, hero.hp])
	cure(hero)
	log_line("")

	log_line("======== Fear: cannot advance ========")
	cure(hero)
	var accurate = combat.get_effective_stat(hero, "accuracy")
	afflict(hero, "fear")
	ok(combat.get_effective_stat(hero, "accuracy") == accurate - 20,
		"shaken, and less accurate", "%d -> %d" % [accurate, combat.get_effective_stat(hero, "accuracy")])
	act_as(combat, controller, hero)
	var nearest = combat.find_nearest_enemy_of(hero)
	if not nearest.is_empty():
		var closer = hero.position + combat.get_cardinal_direction(hero.position, nearest.position)
		ok(not controller.can_move_to(closer), "and will not close the distance", "%s" % closer)
	cure(hero)
	log_line("")

	log_line("======== Frozen: no secondary action ========")
	cure(hero)
	afflict(hero, "frozen")
	ok(combat.has_restriction(hero, "prevents_secondary"), "the restriction is read off it")
	hero.secondary_used_this_turn = false
	var offered := []
	for key in combat.secondary_skills_of(hero):
		offered.append(key)
	ok(not combat.has_action_left(hero) or offered.is_empty()
		or combat.has_restriction(hero, "prevents_secondary"),
		"and nothing secondary is theirs to spend")
	cure(hero)
	log_line("")

	log_line("======== Poisoned: too sick to react ========")
	cure(enemy)
	afflict(enemy, "poisoned")
	ok(combat.has_restriction(enemy, "prevents_reactions"), "the restriction is read off it")
	for comb in combat.combatants:
		comb.reaction_used = false
	hero.reactions_suppressed = false
	await combat.check_reactive_skills(hero, enemy.position, enemy.position + Vector2i(6, 6))
	ok(not enemy.reaction_used, "and takes no free swing as somebody leaves")
	cure(enemy)
	log_line("")

	game.queue_free()
	await get_tree().process_frame
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
