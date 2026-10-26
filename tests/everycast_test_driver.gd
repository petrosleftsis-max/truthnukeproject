extends Node
## Uses every skill in the game once, in a real fight, and reports the ones
## where nothing whatever happened.
##
## The generalisation of the Guard bug: a skill can be perfectly well formed,
## pass every other check, and still be unable to reach anybody - so the only
## way to know it works is to use it and watch. Judged by what changed on the
## two people involved rather than by whether the cast was accepted, because
## Guard's cast was accepted and did nothing.

var LOG_PATH := HarnessLog.path_for("everycast")
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
	get_tree().create_timer(600.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


## Everything about a person that a skill could plausibly change.
func snapshot(comb: Dictionary) -> Dictionary:
	return {
		"hp": comb.hp,
		"effects": comb.status_effects.size(),
		"position": comb.position,
		"hidden": comb.get("hidden", false),
		"alive": comb.alive,
		"movement_class": comb.movement_class,
		"slots": "%s" % [comb.get("spell_slots", [])],
		# Study leaves no mark on anybody's health, and Slip Past none on
		# anybody at all except a flag that lasts the turn.
		"studied_by": "%s" % [comb.get("studied_by", [])],
		"reactions_suppressed": comb.get("reactions_suppressed", false),
		"restrictions": "%s" % [comb.get("restrictions", {})],
		"pocket": "%s" % [comb.get("pocket", [])],
		# Intuition leaves nothing on them but what they mean to do next.
		"intent": "%s" % [comb.get("intent", {})],
		"shaken": comb.get("shaken", 0),
	}


## A handful of tiles with no line of sight to `watched`, so somebody standing
## on one is genuinely not looking at it.
func tiles_that_cannot_see(combat, controller, watched: Vector2i) -> Array:
	var found := []
	var region: Rect2i = controller._astargrid.region
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			if found.size() >= 6:
				return found
			var tile := Vector2i(x, y)
			if controller.is_tile_blocking(tile, 0) or tile == watched:
				continue
			if not combat.has_line_of_sight(tile, watched, 0):
				found.append(tile)
	return found


## Whether `skill` takes somebody out of sight - the one thing the game refuses
## to do while an enemy is watching.
func hides_somebody(skill: SkillDefinition) -> bool:
	for effect in skill.all_effects():
		if effect != null and effect.type == EffectDefinition.EffectType.HIDE:
			return true
	return false


func differences(before: Dictionary, after: Dictionary) -> Array:
	var moved := []
	for key in before:
		if before[key] != after[key]:
			moved.append("%s %s->%s" % [key, before[key], after[key]])
	return moved


func run_test():
	Campaign.reset()
	Campaign.current_encounter = load("res://data/encounters/encounter_02_sappers.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	for i in 6:
		await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	# Nobody here to answer a question - which container a Steal empties, what
	# comes out of a pouch: whoever is asked takes the first.
	combat.reaction_prompt = null
	if combat.deployment_active:
		combat.finish_deployment()
		await get_tree().process_frame
	var controller = combat.controller

	# Three people: somebody to cast, an ally to aim helpful things at, and an
	# enemy to aim the rest at.
	var caster = {}
	var ally = {}
	var foe = {}
	for comb in combat.combatants:
		if not comb.alive:
			continue
		if comb.side == 0 and caster.is_empty():
			caster = comb
		elif comb.side == 0 and ally.is_empty():
			ally = comb
		elif comb.side != 0 and foe.is_empty():
			foe = comb
	ok(not caster.is_empty() and not ally.is_empty() and not foe.is_empty(),
		"a caster, an ally and an enemy", "%s, %s, %s"
			% [caster.get("name", "-"), ally.get("name", "-"), foe.get("name", "-")])
	if caster.is_empty() or ally.is_empty() or foe.is_empty():
		finish(game)
		return

	# A clear stretch of floor to stand the three of them on.
	var lane = Vector2i.ZERO
	var found := false
	var region: Rect2i = controller._astargrid.region
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x - 8):
			if found:
				break
			var clear := true
			for step in 9:
				if controller.is_tile_blocking(Vector2i(x + step, y), 0):
					clear = false
			if clear:
				lane = Vector2i(x, y)
				found = true
	ok(found, "a clear lane to stand them in", "%s" % lane)
	if not found:
		finish(game)
		return

	log_line("")
	log_line("======== using everything once ========")
	var dead := []
	var refused := []
	var worked := 0
	for key in SkillDatabase.skills:
		var skill: SkillDefinition = SkillDatabase.skills[key]
		if skill == null:
			continue
		# A disguise is never offered in a fight (Campaign.combat_items_of), so
		# there is nothing to use it for here.
		if skill is ItemDefinition and skill.stealth_only():
			continue
		# Use works on things on the map, of which this fight has none - the
		# bosses suite rings bells and lights kegs with it.
		if Combat._interacts(skill):
			continue
		# Hack plays a minigame on a foe winding something up - the hacking suite
		# plays it.
		if Combat._hacks(skill):
			continue
		# Only ever a reaction (InstaHack, as a spell is cast) - refused on its
		# user's own turn by design; the triggers suite sets it off.
		if skill.reaction_only:
			continue
		# Devour swallows only somebody already held - the glutton suite plays it.
		if Combat._swallows(skill):
			continue
		# Loot wants somebody fallen with something on them - the loot suite
		# plays it.
		if Combat.loots(skill):
			continue
		# Rummage wants a pouch with something in it - the containers suite plays it.
		if Combat.draws(skill):
			continue
		# A trap changes the ground, not anybody standing on it, and Catalyst wants
		# the caster's own conditions lingering on somebody - the paths suite plays
		# them.
		if Combat.sets_traps(skill) or skill.effects.any(func(effect): return effect != null and effect.type == EffectDefinition.EffectType.CATALYST):
			continue
		# Dispel Magic undoes what spells left, and here nobody has anything on
		# them - the dispel suite plays it.
		if Combat.dispels_magic(skill):
			continue
		# Cast only outside a fight (Find Familiar), and in nobody's kit in one -
		# the familiar suite plays it.
		if skill.outside_only():
			continue
		# Bribe wants somebody with a price, Climb something Monstrous, Climb
		# Down somebody up on it, and Break Free somebody held - none of them
		# here; the enemies suite plays them.
		if Combat._bribes(skill) or Combat._climbs(skill) or key == Combat.CLIMB_DOWN_SKILL \
				or key == Combat.BREAK_FREE_SKILL:
			continue
		# A bottle is spent when it is thrown, and the bag lives on the campaign
		# rather than on the combatant - so it is topped up there, or the throw
		# reports an empty hand and reads as a fault.
		if ItemDatabase.is_item(key):
			Campaign.give_item(caster.get("combatant_key", ""), key)

		# Everyone back on their feet, where they were, with nothing on them.
		for who in [caster, ally, foe]:
			who.alive = true
			who.status_effects.clear()
			# Back to their own size, too - Growth may have been the last thing used.
			combat.resync_size(who)
			who.erase("studied_by")
			who.erase("studied")
			who["reactions_suppressed"] = false
			# Hurt, so a heal has something to mend, and slowed, so a cleanse
			# has something to lift. Both were invisible against somebody at
			# full health with nothing wrong with them.
			who.hp = maxi(int(combat.get_effective_stat(who, "max_hp") / 2), 1)
			var ailment := EffectDefinition.new()
			ailment.type = EffectDefinition.EffectType.STAT_MODIFIER
			ailment.stat = "movement"
			ailment.modifier_amount = -1
			ailment.duration = 5
			combat.apply_effect(who, who, ailment, null, false)
		# Park first, at tiles none of the three will be placed on, so nobody is
		# ever asked to step onto a tile somebody has not left.
		combat.teleport_to(caster, lane + Vector2i(6, 0))
		combat.teleport_to(ally, lane + Vector2i(7, 0))
		combat.teleport_to(foe, lane + Vector2i(8, 0))
		await get_tree().process_frame
		# Near enough to be reached, and no nearer than the skill allows.
		var gap = maxi(skill.min_range, 1)
		if gap > skill.max_range:
			gap = skill.max_range
		var mark = foe if not skill.targets_ally else ally
		if gap <= 0:
			# A skill that reaches nobody but its caster is aimed at themselves.
			mark = caster
		combat.teleport_to(caster, lane)
		if hides_somebody(skill):
			# Watched, they cannot slip away - which is the rule, not a fault.
			# Distance alone does not do it down a clear lane, so the enemies go
			# somewhere the caster genuinely cannot be seen from.
			var blind_spots = tiles_that_cannot_see(combat, controller, lane)
			var put := 0
			for other_comb in combat.combatants:
				if other_comb.alive and other_comb.side != 0 and put < blind_spots.size():
					combat.teleport_to(other_comb, blind_spots[put])
					put += 1
			await get_tree().process_frame
		if not is_same(mark, caster):
			combat.teleport_to(mark, lane + Vector2i(gap, 0))
		var other = ally if not skill.targets_ally else foe
		if not is_same(other, mark):
			combat.teleport_to(other, lane + Vector2i(4, 0))
		await get_tree().process_frame

		caster["level"] = Stats.MAX_LEVEL
		for stat_key in Stats.KEYS:
			caster["stats"][stat_key] = 99
		caster.skill_used_this_turn = false
		caster.secondary_used_this_turn = false
		# Every gate open without holding one - the Mimic's passive, borrowed.
		var gateless := PassiveDefinition.new()
		gateless.casts_without_gates = true
		caster["passives"] = [gateless]
		combat.current_combatant = combat.combatants.find(caster)
		if not key in caster.skill_list:
			caster.skill_list.append(key)

		# Contests are not what this is measuring: a skill shrugged off does
		# nothing on purpose. Stacking the caster settled it for skills, and
		# settles nothing for a bottle, which weighs its own power against the
		# target - so the target is lowered instead, and put back after.
		var contested_key = ""
		var contested_was = 0
		if skill.uses_stat_contest:
			contested_key = Stats.stat_key(skill.contest_stat)
			if contested_key != "" and mark["stats"].has(contested_key):
				contested_was = mark["stats"][contested_key]
				mark["stats"][contested_key] = 0
		if skill.targets_fallen:
			# Aimed at somebody fallen - Resuscitate - so the ally goes down
			# first, where they stand. Standing, there is nobody for it.
			mark.hp = 0
			combat.combatant_die(mark)
		if Combat.steals(skill):
			# Something on the enemy to take, and room in the caster's bag to
			# take it to. Empty-handed, there is nothing for it.
			mark["pocket"] = ["cure_potion"]
			Campaign.empty_inventory(caster.get("combatant_key", ""))
		if skill.needs_leverage:
			# Intimidate, Persuade, Deceive: something on them to work with.
			Campaign.set_flag(Campaign.LEVERAGE_PREFIX + mark.get("combatant_key", ""))
		mark.erase("intent")
		if skill.needs_read:
			# Accusation, Recant: their next turn read by the caster, as Intuition reads it.
			combat.read_intent(caster, mark)
		var aim = mark.position if gap > 0 else caster.position
		# A step and nothing else (Mist Step) goes to a free tile: aimed at
		# somebody, there is nowhere for it to land.
		if skill.teleports == SkillDefinition.TeleportWho.CASTER and skill.all_effects().is_empty():
			aim = lane + Vector2i(3, 0)
			# One that has to land in cover (Cover Leap): a free tile in reach that is.
			if skill.lands_in_cover:
				for dy in range(-skill.max_range, skill.max_range + 1):
					for dx in range(-skill.max_range, skill.max_range + 1):
						var spot: Vector2i = caster.position + Vector2i(dx, dy)
						if combat.distance_to(caster, spot) <= skill.max_range and spot != caster.position \
								and combat.can_land_on(caster, spot) and combat.in_cover(caster, spot):
							aim = spot
		var destination = Vector2i(-99999, -99999)
		if skill.teleports == SkillDefinition.TeleportWho.TARGET:
			destination = lane + Vector2i(3, 0)
		# Command is for a summon of theirs: the ally, made one for it.
		if Combat.commands(skill):
			mark["summoner"] = caster.get("id", -1)
		var before_caster = snapshot(caster)
		var before_mark = snapshot(mark)
		# Somebody new on the board - an image put up - is something done too.
		var standing_before: int = combat.combatants.size()
		var heard: Array = []
		var listening = func(text): heard.append(text.strip_edges())
		combat.update_information.connect(listening)
		await combat.use_skill(key, caster, aim, false, false, destination)
		if skill.declared and caster.has("declared"):
			# Called now, landing next turn: what it does is what lands.
			await combat.land_declared(caster)
		for i in 3:
			await get_tree().process_frame
		combat.update_information.disconnect(listening)
		# An image put up would be standing on the lane for the next one - and so
		# would anything called up, held on the caster's tether.
		var commanded: bool = combat.is_commanding()
		if commanded:
			combat._end_command()
		mark.erase("summoner")
		mark.erase("commanded")
		combat.snap_tether(caster, "the next one")
		for stray in combat.combatants.duplicate():
			if stray.get("illusion", false) and stray.alive:
				combat._shatter(stray)
			elif stray.has("summoner") and stray.alive:
				combat._unsummon(stray, "is put away")

		if contested_key != "" and mark["stats"].has(contested_key):
			mark["stats"][contested_key] = contested_was
		var moved = differences(before_caster, snapshot(caster))
		var landed = differences(before_mark, snapshot(mark))
		var said := []
		for line in heard:
			if line != "":
				said.append(line)
		if combat.combatants.size() != standing_before:
			landed.append("somebody new on the board")
		if commanded:
			landed.append("its moment, given")
		if moved.is_empty() and landed.is_empty():
			dead.append(key)
			log_line("  DEAD  %-20s nothing changed. caster %s, %s %s, aim %s, reach %d-%d. log: %s"
				% [key, caster.position, mark.name, mark.position, aim,
					skill.min_range, skill.max_range, said])
		elif said.is_empty():
			refused.append(key)
			log_line("  QUIET %-20s something changed but nothing was said: %s %s"
				% [key, moved, landed])
		else:
			worked += 1
	log_line("")
	log_line("  NOTE  %d did something, %d did nothing" % [worked, dead.size()])
	ok(dead.is_empty(), "every skill and every bottle does something when used",
		"%s" % [dead])
	finish(game)


func finish(game):
	game.queue_free()
	await get_tree().process_frame
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
