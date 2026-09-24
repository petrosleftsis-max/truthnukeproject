extends Node
## Hiding, and what it takes to be given away.

var LOG_PATH := HarnessLog.path_for("stealth")
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
	get_tree().create_timer(240.0, true, false, true).timeout.connect(func():
		log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


## Somewhere on the map out of sight of everyone on the other side, so hiding is
## actually allowed - found rather than assumed, since the maps get redrawn.
func find_a_hiding_place(combat, comb: Dictionary) -> Vector2i:
	var was = comb.position
	for radius in range(1, 14):
		for dx in range(-radius, radius + 1):
			var dy = radius - absi(dx)
			for candidate in [was + Vector2i(dx, dy), was + Vector2i(dx, -dy)]:
				if combat.controller.is_tile_blocking(candidate, comb.movement_class):
					continue
				if not combat.get_combatant_at(candidate).is_empty():
					continue
				comb.position = candidate
				if not combat.is_seen_by_opponents(comb):
					comb.position = was
					return candidate
	comb.position = was
	return was


## The one line of a tooltip that says which action it costs, so an assertion
## about it cannot be satisfied by "Main or Secondary" containing "Main".
func action_line(tooltip: String) -> String:
	for line in tooltip.split("
"):
		if line.begins_with("Action: "):
			return line
	return ""


## Whether the long walk from one point to the other is unobstructed - terrain
## and bodies both, with a see-through wall stopping neither.
func clear_along(combat, from: Vector2i, to: Vector2i, movement_class: int) -> bool:
	for tile in combat.get_tiles_between(from, to):
		if combat.controller.blocks_line_of_sight(tile, movement_class):
			return false
	return true


func run_test():
	log_line("======== the skill, as asked for ========")
	ok(SkillDatabase.skills.has("stealth"), "Stealth is in the database")
	var stealth: SkillDefinition = SkillDatabase.skills.get("stealth")
	if stealth == null:
		log_line("FAILURES: %d" % (_fail + 1))
		get_tree().quit(1)
		return
	# Granted to Cyrus as a secondary through his own list rather than marked
	# secondary on the skill, which is how Run and Slip Past already worked -
	# the skill is a main action for anybody else who learns it.
	var cyrus_grants: Array = CombatantDatabase.combatants["cyrus"].secondary_skills
	ok("stealth" in cyrus_grants, "Cyrus casts it from his secondary action",
		"%s" % [cyrus_grants])
	ok(not stealth.is_secondary,
		"and the skill itself is a main action, as its siblings are")
	ok(stealth.spell_slot_level == 0, "costing no gate")
	ok(not stealth.deals_damage, "and doing no damage")
	ok("HIDE" in EffectDefinition.EffectType.keys(), "there is an effect type for hiding")
	ok(EffectDefinition.EffectType.MOVEMENT_CLASS == 10,
		"and the types before it still mean what resources think they mean",
		"%d" % EffectDefinition.EffectType.MOVEMENT_CLASS)
	log_line("")

	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_02_sappers.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	for i in 8:
		await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await get_tree().process_frame

	var hero = {}
	var foe = {}
	for comb in combat.combatants:
		if comb.alive and comb.side == 0 and hero.is_empty():
			hero = comb
		elif comb.alive and comb.side == 1 and foe.is_empty():
			foe = comb
	ok(not hero.is_empty() and not foe.is_empty(), "somebody to hide and somebody to hide from")

	log_line("======== Cyrus carries it, as a secondary ========")
	var cyrus = CombatantDatabase.combatants.get("cyrus")
	ok(cyrus != null and "stealth" in cyrus.skills, "it is in his kit")
	ok(cyrus != null and "stealth" in cyrus.secondary_skills, "and offered as a secondary")
	log_line("")

	log_line("======== you cannot slip away while you are watched ========")
	# Standing where an enemy can see them.
	hero.position = foe.position + Vector2i(1, 0)
	ok(combat.is_seen_by_opponents(hero), "they are in plain view")
	await combat.use_skill("stealth", hero, hero.position, false, true)
	for i in 3:
		await get_tree().process_frame
	ok(not combat.is_hidden(hero), "so hiding is refused")
	log_line("")

	log_line("======== out of sight, they can ========")
	var spot = find_a_hiding_place(combat, hero)
	ok(spot != hero.position or not combat.is_seen_by_opponents(hero),
		"there is somewhere out of sight to stand", "%s" % spot)
	hero.position = spot
	hero.secondary_used_this_turn = false
	ok(not combat.is_seen_by_opponents(hero), "and nobody can see it")
	await combat.use_skill("stealth", hero, hero.position, false, true)
	for i in 3:
		await get_tree().process_frame
	ok(combat.is_hidden(hero), "they hide")
	log_line("")

	log_line("======== and the enemies carry on as if they were not there ========")
	# The whole point: not harder to hit, but absent.
	var sought = combat.find_nearest_enemy_of(foe)
	ok(sought.is_empty() or not is_same(sought, hero),
		"nobody goes looking for them",
		"looking at: %s" % ("nobody" if sought.is_empty() else sought.name))
	var counted := 0
	for comb in combat.combatants:
		if comb.side == 0 and comb.alive and not combat.is_hidden(comb):
			counted += 1
	log_line("  (%d of the party are still visible to the enemy)" % counted)
	log_line("")

	log_line("======== they are drawn differently while hidden ========")
	# An ally faintly, so the player can find their own character; an enemy not
	# at all, because not knowing where it is is the point.
	ok(combat.HIDDEN_ALLY_ALPHA > 0.0, "a hidden ally is still drawn",
		"alpha %s" % combat.HIDDEN_ALLY_ALPHA)
	ok(combat.HIDDEN_ALLY_ALPHA < 1.0, "but faintly")
	ok(combat.HIDDEN_ENEMY_ALPHA == 0.0, "a hidden enemy is not drawn at all",
		"alpha %s" % combat.HIDDEN_ENEMY_ALPHA)
	if hero.get("sprite") != null and is_instance_valid(hero.sprite):
		# Not modulate: that one belongs to the hit flash and the death fade,
		# which tween it back to their own colour and would pull a hidden
		# combatant into view in the middle of a fight.
		ok(is_equal_approx(hero.sprite.hidden_alpha, combat.HIDDEN_ALLY_ALPHA),
			"and the sprite actually went faint", "%s" % hero.sprite.hidden_alpha)
	log_line("")

	log_line("======== somebody walking into view gives them away ========")
	# Which is the reveal: an enemy comes round the corner, and there he is.
	var watcher_was = foe.position
	foe.position = hero.position + Vector2i(1, 0)
	var revealed = combat.reveal_anyone_now_seen()
	ok(revealed.size() == 1, "one person is spotted", "%d" % revealed.size())
	ok(not combat.is_hidden(hero), "and is hidden no longer")
	if hero.get("sprite") != null and is_instance_valid(hero.sprite):
		ok(is_equal_approx(hero.sprite.hidden_alpha, 1.0),
			"drawn in full again", "%s" % hero.sprite.hidden_alpha)
	foe.position = watcher_was
	log_line("")

	log_line("======== being spotted stops the walk on that step ========")
	# The reveal is checked after every step, by whoever is walking, and cuts
	# the move where it happens rather than at the end of the run.
	hero.position = spot
	hero.secondary_used_this_turn = false
	combat.set_hidden(hero, true)
	ok(combat.is_hidden(hero), "hidden again")
	var cut = combat.controller.has_method("_handle_step_arrival")
	ok(cut, "there is a per-step hook to cut the walk in")
	var source = FileAccess.open("res://control/CController.gd", FileAccess.READ)
	if source != null:
		var text = source.get_as_text()
		ok(text.contains("reveal_anyone_now_seen"),
			"and the walk asks after every step who can now be seen")
		var after = text.split("reveal_anyone_now_seen")[1].split("\n\n")[0]
		ok(after.contains("finished_move.emit()") and after.contains("_path = []"),
			"stopping the mover where they stand when somebody is")
	log_line("")

	log_line("======== nobody reacts to what they cannot see ========")
	combat.set_hidden(hero, true)
	var provoked = combat.find_triggering_reactions_along_path(
		hero, [hero.position, hero.position + Vector2i(1, 0)])
	ok(provoked.is_empty(), "a hidden mover provokes nothing", "%d" % provoked.size())
	combat.set_hidden(hero, false)
	log_line("")

	log_line("======== nothing Cyrus carries can shoot through cover ========")
	# The reveal below leans on it: if he can hit you, you can see him, and the
	# check after every action finds that. A skill that ignored cover would let
	# him shoot from behind a wall and stay hidden, so he must not have one.
	var through_walls := []
	var arrives_in_the_open := []
	for key in CombatantDatabase.combatants["cyrus"].skills:
		var skill: SkillDefinition = SkillDatabase.skills.get(key)
		if skill == null or not skill.deals_damage or skill.respects_blocking:
			continue
		# Unless it carries him to where it lands. A skill that moves its own
		# caster cannot be used from behind a wall, because he stops being
		# behind it - he is the thing that went through. Blink Strike arrives
		# on the tile and cuts everything beside it, in the open.
		if skill.teleports == SkillDefinition.TeleportWho.CASTER:
			arrives_in_the_open.append(skill.name)
			continue
		through_walls.append("%s (reaches %d)" % [skill.name, skill.max_range])
	ok(through_walls.is_empty(),
		"every damaging move of his either needs a clear line or moves him into the open",
		"ignores cover and stays put: %s" % [through_walls])
	if not arrives_in_the_open.is_empty():
		log_line("  NOTE  ignores cover but carries him with it: %s" % [arrives_in_the_open])
	log_line("")

	log_line("======== shooting somebody gives you away ========")
	# A clear line runs both ways.
	hero.position = spot
	hero.skill_used_this_turn = false
	hero.secondary_used_this_turn = false
	combat.set_hidden(hero, true)
	ok(combat.is_hidden(hero), "hidden, and out of sight")
	# Stand where he can be shot at, which is where he can shoot from.
	var mark = {}
	for comb in combat.combatants:
		if comb.alive and comb.side == 1:
			mark = comb
			break
	hero.position = mark.position + Vector2i(1, 0)
	await combat.use_skill("rapier", hero, mark.position, false)
	for i in 4:
		await get_tree().process_frame
	ok(not combat.is_hidden(hero), "taking a shot reveals the shooter")

	# And the move that ignores cover gives him away too, because it puts him
	# where the blow lands. This is what earns Blink Strike its exemption from
	# the rule above - the proxy is respects_blocking, but the property that
	# actually matters is that striking from hiding cannot be done unseen.
	var blink: SkillDefinition = SkillDatabase.skills.get("blink_strike")
	if blink != null and blink.teleports == SkillDefinition.TeleportWho.CASTER:
		var landing = mark.position + Vector2i(1, 0)
		# Within its own reach of the tile he is aiming at, or the cast is
		# refused as too far and the test proves nothing.
		hero.position = landing + Vector2i(blink.max_range - 1, 0)
		hero.skill_used_this_turn = false
		hero.secondary_used_this_turn = false
		combat.set_hidden(hero, true)
		ok(combat.is_hidden(hero), "hidden once more, %d tiles off"
			% combat.get_position_distance(hero.position, landing))
		var said: Array = []
		var listening = func(text): said.append(text.strip_edges())
		combat.update_information.connect(listening)
		await combat.use_skill("blink_strike", hero, landing, false)
		for i in 4:
			await get_tree().process_frame
		combat.update_information.disconnect(listening)
		for line in said:
			if line != "":
				log_line("  NOTE  log: %s" % line)
		ok(hero.position == landing, "the blink carried him to where it landed",
			"%s, aiming at %s" % [hero.position, landing])
		ok(not combat.is_hidden(hero), "so the one move that ignores cover reveals him as well")
	log_line("")

	log_line("======== and so does being caught by something ========")
	# The case asked for: a blast aimed at somebody else that happens to land on
	# a hidden combatant nobody knew was there.
	hero.position = spot
	hero.hp = maxi(hero.hp, 20)
	combat.set_hidden(hero, true)
	ok(combat.is_hidden(hero), "hidden again, and nobody is looking")
	var was_hp = hero.hp
	var blow := EffectDefinition.new()
	blow.type = EffectDefinition.EffectType.DAMAGE
	blow.min_amount = 3
	blow.max_amount = 3
	combat.do_damage(mark, hero, blow)
	await get_tree().process_frame
	ok(hero.hp < was_hp, "the blast finds them anyway", "%d -> %d" % [was_hp, hero.hp])
	ok(not combat.is_hidden(hero), "and their cover is blown by it")
	log_line("")

	log_line("======== a hidden player is shown where the enemy is looking ========")
	# The point of it: somewhere to plan a route that stays out of sight.
	hero.position = spot
	combat.set_hidden(hero, false)
	combat.controller.refresh_watched_tiles(hero)
	ok(combat.controller._watched_tiles.is_empty(),
		"nothing is drawn for somebody standing in the open",
		"%d tiles" % combat.controller._watched_tiles.size())

	combat.set_hidden(hero, true)
	var started = Time.get_ticks_msec()
	combat.controller.refresh_watched_tiles(hero)
	var spent = Time.get_ticks_msec() - started
	var watched = combat.controller._watched_tiles
	ok(not watched.is_empty(), "and the enemy's field of view is drawn once they hide",
		"%d tiles" % watched.size())
	# Worked out once a turn, not once a frame - it is a line of sight from
	# every enemy to every tile on the map.
	ok(spent < 500, "worked out quickly enough to do on a turn", "%d ms" % spent)

	var wrong := []
	for tile in watched.slice(0, 200):
		var seen := false
		for other in combat.combatants:
			if other.alive and other.side != hero.side \
					and combat.has_line_of_sight(other.position, tile, other.movement_class):
				seen = true
				break
		if not seen:
			wrong.append(tile)
	ok(wrong.is_empty(), "every tile drawn is genuinely watched by somebody",
		"%s" % [wrong.slice(0, 3)])

	var solid := []
	for tile in watched.slice(0, 200):
		if combat.controller.is_tile_blocking(tile, hero.movement_class):
			solid.append(tile)
	ok(solid.is_empty(), "and none of them is a wall they could not stand on anyway",
		"%s" % [solid.slice(0, 3)])

	ok(not (spot in watched), "the hiding place itself is not among them", "%s" % spot)
	var beside_a_watcher = foe.position + Vector2i(1, 0)
	if not combat.controller.is_tile_blocking(beside_a_watcher, hero.movement_class):
		ok(beside_a_watcher in watched, "but the tile beside an enemy is",
			"%s" % beside_a_watcher)
	log_line("")

	log_line("======== the quick line-of-sight walk agrees with the long one ========")
	# has_line_of_sight no longer builds the list of tiles between two points,
	# because it threw the list away immediately and was doing so tens of
	# thousands of times a turn. It has to give the same answer.
	var disagreements := []
	var pairs := 0
	for other in combat.combatants:
		if not other.alive:
			continue
		for dx in range(-9, 10):
			for dy in range(-9, 10):
				var there = other.position + Vector2i(dx, dy)
				if not combat.controller.is_in_bounds(there):
					continue
				pairs += 1
				var quick = combat.has_line_of_sight(other.position, there, other.movement_class)
				# Walked from the same end the quick one picks, since a line that
				# clips a wall corner steps one side of it going out and the other
				# coming back.
				var ask_from = other.position
				var ask_to = there
				if ask_to.x < ask_from.x or (ask_to.x == ask_from.x and ask_to.y < ask_from.y):
					ask_from = there
					ask_to = other.position
				var slow = clear_along(combat, ask_from, ask_to, other.movement_class)
				if quick != slow:
					disagreements.append("%s -> %s: %s vs %s" % [other.position, there, quick, slow])
	ok(disagreements.is_empty(),
		"the two agree everywhere (%d pairs)" % pairs, "%s" % [disagreements.slice(0, 3)])

	# And the rule that makes both of them answerable at all: whichever end you
	# ask from, you get the same answer. Without it somebody could shoot from
	# where nobody could shoot back, which is what the reveal check assumes
	# cannot happen.
	var lopsided := []
	var tested := 0
	for other in combat.combatants:
		if not other.alive:
			continue
		for dx in range(-6, 7):
			for dy in range(-6, 7):
				var there = other.position + Vector2i(dx, dy)
				if not combat.controller.is_in_bounds(there):
					continue
				tested += 1
				if combat.has_line_of_sight(other.position, there, 0) \
						!= combat.has_line_of_sight(there, other.position, 0):
					lopsided.append("%s/%s" % [other.position, there])
	ok(lopsided.is_empty(), "and sight runs both ways (%d pairs)" % tested,
		"%s" % [lopsided.slice(0, 3)])
	log_line("")

	log_line("======== and it is not drawn for anybody else ========")
	combat.controller.refresh_watched_tiles(foe)
	ok(combat.controller._watched_tiles.is_empty(),
		"an enemy's own turn draws none of it",
		"%d tiles" % combat.controller._watched_tiles.size())
	combat.set_hidden(hero, false)
	log_line("")

	log_line("======== the last one standing cannot hide ========")
	# Hiding is something you do while the enemy has somebody else to look at.
	hero.position = spot
	combat.set_hidden(hero, false)
	hero.skill_used_this_turn = false
	hero.secondary_used_this_turn = false
	ok(not combat.alone_on_their_side(hero), "he is not alone yet")
	await combat.use_skill("stealth", hero, hero.position, false, true)
	for i in 3:
		await get_tree().process_frame
	ok(combat.is_hidden(hero), "so he can still slip away")

	# And now everybody else on his side falls.
	for comb in combat.combatants:
		if comb.alive and comb.side == hero.side and not is_same(comb, hero):
			comb.hp = 0
			combat.combatant_die(comb)
	await get_tree().process_frame
	ok(combat.alone_on_their_side(hero), "he is the last one standing")
	ok(not combat.is_hidden(hero), "which gives him away on its own")

	hero.secondary_used_this_turn = false
	await combat.use_skill("stealth", hero, hero.position, false, true)
	for i in 3:
		await get_tree().process_frame
	ok(not combat.is_hidden(hero), "and he cannot slip away again")
	log_line("")

	log_line("======== whose action a consumable spends ========")
	# It depends on who is holding it: Cyrus can spend a bottle from his
	# secondary, where everybody else spends their main action on one.
	var ui = combat.game_ui
	var bottle: SkillDefinition = null
	for key in ItemDatabase.items:
		bottle = ItemDatabase.items[key]
		break
	ok(bottle != null, "there is a consumable to read", bottle.name if bottle else "none")
	if bottle != null:
		var thief = {}
		var ordinary = {}
		for comb in combat.combatants:
			if comb.get("items_as_secondary", false) and thief.is_empty():
				thief = comb
			elif not comb.get("items_as_secondary", false) and ordinary.is_empty():
				ordinary = comb
		if not thief.is_empty():
			ok(action_line(ui.build_skill_tooltip(bottle, thief)) == "Action: Main or Secondary",
				"%s can spend either on one" % thief.name,
				action_line(ui.build_skill_tooltip(bottle, thief)))
			# And which one it actually takes: the secondary while it is there.
			thief.skill_used_this_turn = false
			thief.secondary_used_this_turn = false
			ok(ui._consumable_spends_secondary(thief, bottle),
				"  and reaches for the secondary first, with both still open")
			thief.secondary_used_this_turn = true
			ok(not ui._consumable_spends_secondary(thief, bottle),
				"  falling back to the main action once the secondary is gone")
			thief.secondary_used_this_turn = false
			thief.skill_used_this_turn = true
			ok(ui._consumable_spends_secondary(thief, bottle),
				"  and still taking the secondary when the main action is the one spent")
			thief.skill_used_this_turn = false
		else:
			ok(false, "somebody in this fight uses items as a secondary")
		if not ordinary.is_empty():
			ok(action_line(ui.build_skill_tooltip(bottle, ordinary)) == "Action: Main",
				"and %s spends their main action, with no choice about it" % ordinary.name,
				action_line(ui.build_skill_tooltip(bottle, ordinary)))
			ok(not ui._consumable_spends_secondary(ordinary, bottle),
				"  which is what it actually takes")
		# An ordinary skill is unaffected by whose hands it is in.
		var swing: SkillDefinition = SkillDatabase.skills["greatsword_attack"]
		ok(action_line(ui.build_skill_tooltip(swing, thief)) == "Action: Main",
			"a plain skill still reads off the skill, in anybody's hands",
			action_line(ui.build_skill_tooltip(swing, thief)))
		# Something marked secondary on the skill itself - Stealth is not one,
		# it is granted as a secondary to Cyrus in particular.
		var truly_secondary: SkillDefinition = null
		for key in SkillDatabase.skills:
			if SkillDatabase.skills[key].is_secondary:
				truly_secondary = SkillDatabase.skills[key]
				break
		if truly_secondary != null:
			ok(action_line(ui.build_skill_tooltip(truly_secondary, thief)) == "Action: Secondary",
				"and a secondary skill still reads as one", truly_secondary.name)
	log_line("")

	log_line("======== dying is not a hiding place ========")
	combat.set_hidden(hero, true)
	hero.hp = 0
	combat.combatant_die(hero)
	ok(not combat.is_hidden(hero), "somebody killed while hidden stops being hidden")
	log_line("")

	log_line("======== and shown it while deciding whether to hide at all ========")
	# Where the enemy is looking is the whole decision behind hiding, so it is
	# worth seeing before committing rather than only after.
	var aiming = combat.controller
	combat.set_hidden(hero, false)
	combat.current_combatant = combat.combatants.find(hero)
	aiming.set_controlled_combatant(hero)
	aiming.refresh_watched_tiles(hero)
	ok(aiming._watched_tiles.is_empty(),
		"nothing is drawn while they are simply standing about",
		"%d tiles" % aiming._watched_tiles.size())

	var vanishing: SkillDefinition = SkillDatabase.skills["stealth"]
	ok(aiming.hides_its_caster(vanishing), "Stealth is known to hide its caster")
	var ordinary: SkillDefinition = SkillDatabase.skills["gun"]
	ok(not aiming.hides_its_caster(ordinary), "while a gun is not", ordinary.name)

	aiming.set_selected_skill("stealth", vanishing.is_secondary)
	aiming.begin_target_selection()
	ok(not aiming._watched_tiles.is_empty(),
		"aiming it shows what the enemy can see",
		"%d tiles" % aiming._watched_tiles.size())

	# Backing out puts it away again.
	aiming.cancel_skill_selection()
	ok(aiming._watched_tiles.is_empty(),
		"and backing out of the aim puts it away",
		"%d tiles" % aiming._watched_tiles.size())

	# Aiming something that does not hide anybody shows nothing, so the overlay
	# means one thing rather than appearing for every skill.
	aiming.set_selected_skill("gun", ordinary.is_secondary)
	aiming.begin_target_selection()
	ok(aiming._watched_tiles.is_empty(),
		"aiming anything else shows nothing",
		"%d tiles" % aiming._watched_tiles.size())
	aiming.cancel_skill_selection()
	log_line("")

	game.queue_free()
	await get_tree().process_frame
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
