extends Node
## Four small things that were wrong where the player could see them.
##
## A debuff icon that outstayed the debuff, a combatant walking backwards, the
## map taking clicks meant for the character sheet, and shake tags written the
## wrong way round.

var LOG_PATH := HarnessLog.path_for("mend")
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
	get_tree().create_timer(200.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


func act_as(combat, controller, comb: Dictionary):
	for i in combat.combatants.size():
		if is_same(combat.combatants[i], comb):
			combat.current_combatant = i
	controller.set_controlled_combatant(comb)


## How many condition icons are showing beside `comb`'s portrait.
func icons_beside(ui, comb: Dictionary) -> int:
	for child in ui.get_node("Status").get_children():
		if child.get_meta("combatant_id", -2) != comb.get("id", 0):
			continue
		var strip = child.get_node_or_null("Layout/Icon/Conditions")
		if strip == null:
			return 0
		return strip.get_child_count()
	return -1


func run_test():
	log_line("======== shake is written the way BBCode reads it ========")
	# [/shake] before [shake] is the pair inside out: the closing tag is
	# ignored and the opening one never closes, so nothing ever shook.
	var backwards := []
	var dir = DirAccess.open("res://Dialogue")
	for file in dir.get_files():
		if not file.ends_with(".dialogue"):
			continue
		var text = FileAccess.get_file_as_string("res://Dialogue/".path_join(file))
		for line in text.split("\n"):
			var closes = line.find("[/shake]")
			var opens = line.find("[shake")
			if closes >= 0 and (opens < 0 or closes < opens):
				backwards.append("%s: %s" % [file, line.strip_edges().substr(0, 40)])
	ok(backwards.is_empty(), "no dialogue closes a shake before it opens one", "%s" % [backwards])
	log_line("")

	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_02_sappers.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	for i in 6:
		await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	var controller = combat.controller
	var ui = combat.game_ui
	if combat.deployment_active:
		combat.finish_deployment()
		await get_tree().process_frame

	var hero = null
	for comb in combat.combatants:
		if comb.alive and comb.side == 0:
			hero = comb
			break
	ok(hero != null, "somebody of the party to watch")

	log_line("======== a debuff arrives and leaves while the turn runs ========")
	act_as(combat, controller, hero)
	ui.show_combatant_status_main(hero)
	await get_tree().process_frame
	var bare = icons_beside(ui, hero)
	ok(bare == 0, "no icons to start with", "%d" % bare)
	var poison := EffectDefinition.new()
	poison.type = EffectDefinition.EffectType.CONDITION
	poison.condition = load("res://conditions/poisoned.tres")
	combat.apply_effect(hero, hero, poison, SkillDatabase.skills["cleanse"], false)
	await get_tree().process_frame
	ok(icons_beside(ui, hero) == 1, "the icon appears as the condition lands, not next turn",
		"%d" % icons_beside(ui, hero))
	# Cleanse it off, still without the turn changing.
	# The real skill's own effect, not one built for the test, so this is
	# exactly what a player pressing Cleanse does.
	var cleanse_skill: SkillDefinition = SkillDatabase.skills["cleanse"]
	for effect in cleanse_skill.all_effects():
		combat.apply_effect(hero, hero, effect, cleanse_skill, false)
	await get_tree().process_frame
	ok(combat.conditions_of(hero).is_empty(), "the cleanse lifts it")
	ok(icons_beside(ui, hero) == 0, "and the icon goes with it, there and then",
		"%d" % icons_beside(ui, hero))
	log_line("")

	log_line("======== walking the way you are facing ========")
	act_as(combat, controller, hero)
	var sprite = hero.sprite
	ok(sprite.has_method("set_facing"), "the sprite can be turned around")
	# Walking left.
	controller.controlled_node = sprite
	controller._next_position = sprite.position - Vector2(Grid.TILE_SIZE, 0)
	controller._face_along_the_walk()
	var facing_left = sprite._animated.flip_h if sprite._animated != null else sprite._static.flip_h
	ok(facing_left, "walking left turns them left")
	# Walking right.
	controller._next_position = sprite.position + Vector2(Grid.TILE_SIZE, 0)
	controller._face_along_the_walk()
	var facing_right = sprite._animated.flip_h if sprite._animated != null else sprite._static.flip_h
	ok(not facing_right, "and walking right turns them back")
	# Straight up: whatever they were, they stay.
	controller._next_position = sprite.position - Vector2(0, Grid.TILE_SIZE)
	controller._face_along_the_walk()
	var after_vertical = sprite._animated.flip_h if sprite._animated != null else sprite._static.flip_h
	ok(after_vertical == facing_right, "walking straight up does not spin them round")
	log_line("")

	log_line("======== the sheet takes its own clicks ========")
	var sheet = game.get_node_or_null("CharacterSheet")
	ok(sheet != null, "there is a character sheet")
	if sheet != null:
		ok(not controller.reading_a_character_sheet(), "closed, the map is the player's")
		hero["studied"] = true
		sheet.open()
		await get_tree().process_frame
		if sheet.is_open():
			ok(controller.reading_a_character_sheet(),
				"open, the map stops listening")
			sheet.close()
			await get_tree().process_frame
			ok(not controller.reading_a_character_sheet(), "and listens again once it is shut")
		else:
			log_line("  (the sheet had nobody to show, so there was nothing to open)")
	log_line("")

	log_line("======== the panel says what a skill is worth ========")
	# One number, before anybody's defence - not the spread across whoever
	# happens to be standing on the board, which read as the skill rolling dice.
	act_as(combat, controller, hero)
	var swing: SkillDefinition = null
	for key in combat.main_skills_of(hero):
		if SkillDatabase.skills[key].deals_damage:
			swing = SkillDatabase.skills[key]
			break
	ok(swing != null, "they know something that hurts")
	if swing != null:
		var tooltip = ui.build_skill_tooltip(swing)
		ok("Base Damage:" in tooltip, "it reads Base Damage", tooltip.split("
")[0])
		ok(not ("Damage: " in tooltip and not "Base Damage: " in tooltip),
			"and never the bare word Damage on its own")
		var expected = combat.base_skill_damage(hero, swing)
		ok("Base Damage: %d" % expected in tooltip,
			"the number is what the skill is worth before defences", "%d" % expected)
		# Nobody else's defence is in it: the same skill reads the same however
		# tough the enemies happen to be.
		for comb in combat.combatants:
			if comb.side == 1 and comb.alive:
				comb.stats["defense"] = 99
		ok("Base Damage: %d" % expected in ui.build_skill_tooltip(swing),
			"and armouring the enemy does not change it")
	log_line("")

	log_line("======== the study bonus is mentioned once, where it belongs ========")
	act_as(combat, controller, hero)
	var mentions := []
	for key in SkillDatabase.skills:
		var skill: SkillDefinition = SkillDatabase.skills[key]
		if skill == null:
			continue
		if "studied" in ui.build_skill_tooltip(skill):
			mentions.append(skill.name)
	# Studying somebody no longer moves the odds, so no tooltip has a bonus to
	# explain - including Study's own, which used to be the one place it was
	# spelled out.
	ok(mentions.is_empty(), "nothing promises anything for having studied", "%s" % [mentions])
	log_line("")

	log_line("======== a skill says which attribute it is worked out from ========")
	# The panel now names the scaling stat, so a player can see why the same
	# Fireball is worth more in one pair of hands - and which attribute to
	# raise. Only where something actually scales off it, though: every skill
	# carries the field whether it uses it or not.
	var silent := []
	var noisy := []
	for key in SkillDatabase.skills:
		var skill: SkillDefinition = SkillDatabase.skills[key]
		if skill == null:
			continue
		var says = "Scales with: %s" % Stats.stat_name(skill.scaling_stat) in ui.build_skill_tooltip(skill)
		if ui._scales_off_the_caster(skill):
			if not says:
				silent.append(skill.name)
		elif says:
			noisy.append(skill.name)
	ok(silent.is_empty(), "every skill whose numbers scale names the attribute", "%s" % [silent])
	ok(noisy.is_empty(), "and one whose numbers do not stays quiet about it", "%s" % [noisy])
	# The two ends of it, on skills that are what they are.
	var lance: SkillDefinition = SkillDatabase.skills["holy_lance"]
	ok("Scales with: %s" % Stats.stat_name(lance.scaling_stat) in ui.build_skill_tooltip(lance),
		"Holy Lance says what it scales off", Stats.stat_name(lance.scaling_stat))
	var potion = ItemDatabase.items["cure_potion"] if ItemDatabase.items.has("cure_potion") else null
	if potion != null:
		ok(not ("Scales with" in ui.build_skill_tooltip(potion)),
			"and a bottle is worth what is written on it, whoever uncorks it")
	log_line("")

	log_line("======== a shove says when it hurts ========")
	var shove: SkillDefinition = SkillDatabase.skills["shoving_strike"]
	var shove_tip = ui.build_skill_tooltip(shove)
	ok(not ("hit a wall" in shove_tip),
		"it no longer claims only a wall hurts", shove_tip.split("
")[-2])
	ok("on collision" in shove_tip, "it says on collision instead")
	# Which is the truth: a shove stopped by a body hurts both of them.
	var shover = null
	var blocker = null
	for comb in combat.combatants:
		if comb.alive and comb.side == 1 and shover == null:
			shover = comb
		elif comb.alive and comb.side == 1 and blocker == null:
			blocker = comb
	ok(shover != null and blocker != null, "two bodies to shove together")
	log_line("")

	game.queue_free()
	await get_tree().process_frame
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
