extends Node
## Tests secondary skills, the HUD panels, status durations, and the new log
## wording.

var LOG_PATH := HarnessLog.path_for("skills")

var _log: FileAccess = null
var _fail = 0


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


func run_test():
	log_line("======== renamed keys ========")
	for key in ["enfina", "cyrus", "prometheus"]:
		ok(CombatantDatabase.combatants.has(key), "database has '%s'" % key)
	for key in ["steve", "bob", "alexandra"]:
		ok(not CombatantDatabase.combatants.has(key), "old key '%s' is gone" % key)
	log_line("")

	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_01_ambush.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	var controller = game.get_node("Controller")
	var ui = game.get_node("CanvasLayer/UI")

	var cyrus = null
	var prometheus = null
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == "cyrus":
			cyrus = comb
		elif comb.get("combatant_key", "") == "prometheus":
			prometheus = comb

	log_line("======== main vs secondary skill lists ========")
	ok(cyrus != null, "Cyrus deployed")
	var cyrus_main = combat.main_skills_of(cyrus)
	var cyrus_secondary = combat.secondary_skills_of(cyrus)
	ok(cyrus_main.has("run"), "Run is a main skill for Cyrus", "%s" % [cyrus_main])
	ok(cyrus_secondary.has("run"), "and also a secondary one, for him specifically", "%s" % [cyrus_secondary])
	ok(not cyrus_main.has("cleanse"), "Cleanse is not a main skill")
	# Built from the database rather than found on the field: which encounter
	# happens to deploy him is content, and this is about what his kit offers.
	if prometheus == null:
		prometheus = combat.create_combatant(CombatantDatabase.combatants["prometheus"], "prometheus")
	var prom_main = combat.main_skills_of(prometheus)
	var prom_secondary = combat.secondary_skills_of(prometheus)
	# Cleanse is Alithia's kit now rather than every caster's, so it is checked
	# on whoever actually carries it rather than on whoever happens to be a mage.
	var alithia = combat.create_combatant(CombatantDatabase.combatants["alithia"], "alithia")
	# A secondary skill that costs a slot is shown on the Spells panel instead,
	# spent from the same action - so where Cleanse appears follows its own cost
	# rather than a fixed expectation.
	var cleanse_panel = combat.spell_skills_of(alithia) if SkillDatabase.skills["cleanse"].spell_slot_level > 0 else combat.secondary_skills_of(alithia)
	ok(cleanse_panel.has("cleanse"), "Cleanse is on Alithia's %s panel" % ("spells" if SkillDatabase.skills["cleanse"].spell_slot_level > 0 else "secondary"),
		"%s" % [combat.secondary_skills_of(alithia)])
	ok(not prom_secondary.has("cleanse"), "and not for Prometheus", "%s" % [prom_secondary])
	ok(not prom_secondary.has("run"), "but Run is not - that's Cyrus only", "%s" % [prom_secondary])
	ok(not prom_main.has("cleanse"), "and Cleanse has left the main panel", "%s" % [prom_main])
	log_line("")

	log_line("======== the two slots are spent separately ========")
	ok(combat.has_action_left(cyrus), "both slots available at the start of a turn")
	cyrus.skill_used_this_turn = true
	ok(combat.has_action_left(cyrus), "main spent, secondary still available")
	cyrus.secondary_used_this_turn = true
	ok(not combat.has_action_left(cyrus), "both spent, nothing left")
	cyrus.skill_used_this_turn = false
	cyrus.secondary_used_this_turn = false
	log_line("")

	log_line("======== HUD panel switching ========")
	combat.finish_deployment()
	await get_tree().process_frame
	ui.combat = combat
	ui.show_combatant_status_main(cyrus)
	ok(not ui.showing_secondary, "a turn opens on the main panel")
	ok(not ui.showing_spells, "showing what they swing rather than what they cast")
	var tab_row = ui.get_node("Actions/SkillPanelTabs")
	ok(tab_row.get_node("MainTab").button_pressed, "with the Main tab reading as selected")
	ui.set_skill_panel(ui.SkillPanel.SECONDARY)
	ok(ui.showing_secondary, "moved to secondary")
	ok(tab_row.get_node("SecondaryTab").button_pressed, "and that tab is the selected one now")
	ui.set_skill_panel(ui.SkillPanel.MAIN)
	ok(tab_row.get_node("MainTab").button_pressed, "and back again")
	log_line("")

	log_line("======== skills locked while walking ========")
	var first_button = ui.get_node("Actions/ActionsPanel/ActionsGrid/Slot1")
	controller.set_controlled_combatant(cyrus)
	ui.show_combatant_status_main(cyrus)
	ok(controller.is_idle(), "standing still to begin with")
	ok(not first_button.disabled, "skills selectable when idle")
	controller._arrived = false
	ui.refresh_action_buttons()
	ok(first_button.disabled, "skills locked out mid-walk")
	controller._arrived = true
	controller.action_locked = true
	ui.refresh_action_buttons()
	ok(first_button.disabled, "and locked during an animation")
	controller.action_locked = false
	ui.refresh_action_buttons()
	ok(not first_button.disabled, "available again once still and idle")
	log_line("")

	log_line("======== HUD clears while aiming ========")
	ui._target_selection_started()
	ok(not ui.get_node("Actions/ActionsPanel").visible, "skill panel hidden while aiming")
	ok(not ui.get_node("Actions/Information").visible, "message log hidden")
	ok(not ui.get_node("Actions/EndTurnButton").visible, "End Turn hidden")
	ok(ui.get_node("Status").visible, "party portraits stay")
	ok(ui.get_node("TurnQueue").visible, "turn queue stays")
	ok(not ui.get_node("Actions/SelectTargetMessage").visible, "aiming banner hidden too - it only ever held deployment text")
	ui._target_selection_finished()
	ok(ui.get_node("Actions/ActionsPanel").visible, "everything returns afterwards")
	ok(ui.get_node("Actions/EndTurnButton").visible, "including End Turn")
	ok(not ui.get_node("Actions/SelectTargetMessage").visible, "banner cleared")
	log_line("")

	log_line("======== status duration means what it says ========")
	for wanted in [1, 2, 3]:
		var victim = {"status_effects": [], "hp": 20, "max_hp": 20, "alive": true, "name": "Dummy", "side": 0}
		victim.status_effects.append({"stat": "movement", "op": "add", "amount": -1, "duration": wanted, "source_name": "T"})
		var active_turns = 0
		for turn in range(0, 10):
			combat.process_status_effects(victim)
			if victim.status_effects.is_empty():
				break
			active_turns += 1
		ok(active_turns == wanted, "duration %d lasts %d turn(s)" % [wanted, wanted], "measured %d" % active_turns)
	log_line("")

	log_line("======== log names the skill and the condition ========")
	var messages: Array = []
	combat.update_information.connect(func(text): messages.append(text))
	var attacker = combat.combatants[0]
	var target = combat.combatants[1]
	var poison: SkillDefinition = SkillDatabase.skills["poison_dart"]
	var first = true
	for effect in poison.all_effects():
		combat.apply_effect(attacker, target, effect, poison, first)
		first = false
	var joined = "".join(messages)
	ok(joined.contains("used %s on" % poison.name), "first line names the skill", "%s" % joined.strip_edges().split("\n")[0])
	ok(joined.contains("dealing"), "and reads as one action with the damage")
	ok(messages.size() >= 2, "the second effect gets its own line", "%d lines" % messages.size())
	var dot_line = messages[messages.size() - 1]
	ok(not dot_line.contains("used %s" % poison.name), "which doesn't repeat the skill name", "%s" % dot_line.strip_edges())
	log_line("")

	log_line("======== a turn cannot be ended halfway between two tiles ========")
	# The keyboard already refused, because it goes through _unhandled_input and
	# that asks the controller whether it is idle. A Button press does not - it
	# goes through its own pressed signal - so the mouse was allowed to do what
	# the keyboard would not, and a turn could end mid-walk.
	var end_turn = ui.get_node("Actions/EndTurnButton")
	var mover = combat.get_current_combatant()
	if mover.is_empty() or mover.side != 0:
		log_line("  NOTE  it is not a player's turn here, so there is nothing to walk")
	else:
		controller.set_controlled_combatant(mover)
		ui.refresh_action_buttons()
		ok(controller.is_idle(), "they are standing still to begin with")
		ok(not end_turn.disabled, "and the turn is theirs to end")

		# Somewhere they can actually walk to, found rather than assumed.
		var step = Vector2i(-99999, -99999)
		for tile in controller.get_reachable_tiles(mover.position, mover.movement_class, controller.movement):
			if tile != mover.position:
				step = tile
				break
		if step == Vector2i(-99999, -99999):
			log_line("  NOTE  nowhere to walk from here")
		else:
			# find_path only plans the route; move_on_path is what sets off along
			# it, which is the state this is about.
			controller.find_path(step)
			controller.move_on_path(mover.position)
			await get_tree().process_frame
			if controller.is_idle():
				log_line("  NOTE  the walk finished within a frame, so there was no mid-walk to catch")
			else:
				ok(end_turn.disabled, "while walking, End Turn is greyed out")
				# And pressing it anyway does nothing, which is what makes the
				# greying true rather than decorative.
				var ended = false
				var watch = func(): ended = true
				ui.turn_ended.connect(watch)
				ui._on_end_turn_button_pressed()
				await get_tree().process_frame
				ok(not ended, "and pressing it regardless does not end the turn")
				ui.turn_ended.disconnect(watch)
				# Once they arrive it is theirs again.
				for i in 240:
					await get_tree().process_frame
					if controller.is_idle():
						break
				ok(controller.is_idle(), "the walk finishes", "%s" % mover.position)
				ui.refresh_action_buttons()
				ok(not end_turn.disabled, "and the turn is theirs to end once more")
	log_line("")

	log_line("======== a blast rolls once per target, not once per cast ========")
	# With one roll for the whole use, two enemies caught by the same blast are
	# always both hit or both missed. With a roll each, the interesting outcome
	# exists: one of them is caught and the other is not.
	var pair := []
	for comb in combat.combatants:
		if comb.alive and comb.side == 1 and pair.size() < 2:
			pair.append(comb)
	ok(pair.size() == 2, "there are two of them to catch", "%d" % pair.size())
	if pair.size() == 2:
		# Stood together so one blast covers both, and a coin-toss accuracy so
		# a split outcome is the common case rather than a rare one.
		# Somebody on the other side, so the blast has enemies to catch rather
		# than standing on one of them - combatants[0] is whoever the encounter
		# happened to list first, which here was one of the two.
		var caster = {}
		for comb in combat.combatants:
			if comb.alive and comb.side == 0:
				caster = comb
				break
		var coin: SkillDefinition = SkillDatabase.skills["fireball"].duplicate(true)
		coin.resource_name = "Coin Blast"
		# Nothing standing between the caster and casting it: no gate to pay,
		# no level to have reached, and it is their turn.
		coin.spell_slot_level = 0
		coin.required_level = 1
		coin.is_secondary = false
		combat.current_combatant = combat.combatants.find(caster)
		if not "_coin_blast" in caster.skill_list:
			caster.skill_list.append("_coin_blast")
		coin.uses_stat_contest = false
		# Enemies only. Fireball catches both sides, and at radius 5 the caster
		# standing four tiles off is inside his own blast - so over sixty casts
		# he killed himself, and every cast after that landed on nobody, which
		# reads exactly like one roll for the pair.
		coin.affects_both_sides = false
		# hit_chance is the skill's accuracy PLUS the caster's own, clamped to
		# 100 - so a 50 on the skill alone was landing every time. Set so the
		# pair of them comes to a coin toss.
		coin.accuracy = clampi(50 - combat.get_effective_stat(caster, "accuracy"), 0, 100)
		SkillDatabase.skills["_coin_blast"] = coin
		ok(combat.hit_chance(caster, coin, pair[0]) > 20 and combat.hit_chance(caster, coin, pair[0]) < 80,
			"the test blast is a genuine coin toss",
			"%d%%" % combat.hit_chance(caster, coin, pair[0]))
		# Stood together, and far enough from the caster to clear the skill's own
		# minimum range - aiming at your own feet is refused as too close.
		var spot = caster.position + Vector2i(mini(coin.max_range - 1, 4), 0)
		pair[0].position = spot
		pair[1].position = spot + Vector2i(1, 0)
		ok(combat.is_effectively_in_range(coin, caster.position, spot, caster.movement_class, caster),
			"the blast can actually reach where they are standing",
			"%s to %s" % [caster.position, spot])
		# One cast with the log attached, so a refusal says why instead of just
		# not happening. After they are placed, or it reports a staleness of
		# its own.
		var heard: Array = []
		var listen = func(text): heard.append(text.strip_edges())
		combat.update_information.connect(listen)
		caster.skill_used_this_turn = false
		await combat.use_skill("_coin_blast", caster, pair[0].position, false)
		for i in 3:
			await get_tree().process_frame
		combat.update_information.disconnect(listen)
		log_line("  NOTE  caster %s at %s, targets at %s and %s, reach %d" % [
			caster.name, caster.position, pair[0].position, pair[1].position, coin.max_range])
		for line in heard:
			if line != "":
				log_line("  NOTE  log: %s" % line)
		if heard.is_empty():
			log_line("  NOTE  log: (nothing at all - the cast never started)")

		var split = 0
		var tries = 0
		var landed_a = 0
		var landed_b = 0
		for attempt in 60:
			tries += 1
			caster.skill_used_this_turn = false
			caster.secondary_used_this_turn = false
			for who in pair + [caster]:
				who.hp = combat.get_effective_stat(who, "max_hp")
				who.alive = true
			var before_a = pair[0].hp
			var before_b = pair[1].hp
			await combat.use_skill("_coin_blast", caster, pair[0].position, false)
			for i in 2:
				await get_tree().process_frame
			var hit_a = pair[0].hp < before_a
			var hit_b = pair[1].hp < before_b
			if hit_a:
				landed_a += 1
			if hit_b:
				landed_b += 1
			if hit_a != hit_b:
				split += 1
				break
		SkillDatabase.skills.erase("_coin_blast")
		log_line("  NOTE  over %d casts: the first was hit %d times, the second %d"
			% [tries, landed_a, landed_b])
		ok(split > 0,
			"one of the two can be hit while the other is missed",
			"after %d cast(s) of a 50%% blast over both: %d and %d landed"
				% [tries, landed_a, landed_b])

	# And the roll is judged against the target rather than against nobody,
	# which is what having studied somebody is worth.
	var gun: SkillDefinition = SkillDatabase.skills["gun"]
	if pair.size() == 2:
		pair[0]["studied"] = true
		pair[1]["studied"] = false
		var caster = combat.combatants[0]
		var against_studied = combat.hit_chance(caster, gun, pair[0])
		var against_stranger = combat.hit_chance(caster, gun, pair[1])
		ok(against_studied >= against_stranger,
			"a studied target is no harder to hit than an unstudied one",
			"%d%% against the studied one, %d%% against the other" % [
				against_studied, against_stranger])
		# The roll is still made per target - a condition on one of them is
		# theirs rather than the whole cast's - even though having studied
		# somebody no longer changes anything.
		ok(against_studied == against_stranger,
			"and studying one of them does not single them out",
			"%d%% either way" % against_studied)
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
