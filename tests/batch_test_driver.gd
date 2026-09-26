extends Node
## Duplicates in a fight, skills from the database alone, a tooltip that shows
## the damage, Study, and the condition marks on the HUD.

var LOG_PATH := HarnessLog.path_for("batch")

var _log: FileAccess = null
var _fail = 0
var game: Node = null
var combat: Combat = null
var ui = null

## What an interactable says to the scene it is standing in. This driver stands
## in for the exploration scene below, so it has to answer the same call:
## ExamineInteractable reaches for it, and without it the examine path died
## partway through with a script error that nothing was reading.
var _logged: Array = []


func log_message(text: String):
	_logged.append(text)


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
	get_tree().create_timer(180.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


func start_battle() -> Node:
	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_01_ambush.tres")
	game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	combat = game.get_node("VisualCombat")
	combat.finish_deployment()
	await get_tree().process_frame
	ui = game.get_node_or_null("CanvasLayer/UI")
	if ui == null:
		for child in game.find_children("*", "Control", true, false):
			if child.has_method("build_skill_tooltip"):
				ui = child
				break
	return game


func enemies() -> Array:
	var found = []
	for comb in combat.combatants:
		if comb.side == 1 and comb.alive:
			found.append(comb)
	return found


func run_test():
	await start_battle()
	ok(combat != null and ui != null, "a battle is up and the HUD with it")

	log_line("======== an encounter can field several of the same ========")
	# Whoever this encounter happens to double up on. Which combatant that is, or
	# whether there is one at all, is content and gets rewritten.
	var counts := {}
	for comb in combat.combatants:
		var key = comb.get("combatant_key", "")
		counts[key] = counts.get(key, 0) + 1
	var doubled = ""
	for key in counts:
		if counts[key] >= 2:
			doubled = key
	var barbarians = []
	for comb in combat.combatants:
		if doubled != "" and comb.get("combatant_key", "") == doubled:
			barbarians.append(comb)
	if doubled == "":
		log_line("  NOTE  this encounter fields nobody twice, so there are no names to tell apart")
		ok(true, "which is not a failure")
	else:
		ok(barbarians.size() >= 2, "the encounter fields more than one %s" % doubled, "%d" % barbarians.size())
	var ids = {}
	for comb in combat.combatants:
		ids[comb.get("id", -1)] = true
	ok(ids.size() == combat.combatants.size(), "everyone in the fight has an id of their own",
		"%d ids for %d combatants" % [ids.size(), combat.combatants.size()])
	var names = {}
	for comb in barbarians:
		names[comb.name] = true
	ok(names.size() == barbarians.size(), "and a name of their own, numbered apart",
		"%s" % [names.keys()])

	# The HUD used to find an icon by name, which is what made duplicates
	# dangerous: killing one could take another's icon off the screen.
	var queue = ui.get_node("TurnQueue/Queue")
	var before = queue.get_child_count()
	var doomed = barbarians[0]
	var survivor = barbarians[1]
	var survivor_icon = ui._icon_for(queue, survivor)
	ok(survivor_icon != null, "each duplicate has its own queue icon")
	combat.combatant_die(doomed)
	await get_tree().process_frame
	ok(queue.get_child_count() == before - 1, "killing one takes one icon off",
		"%d -> %d" % [before, queue.get_child_count()])
	ok(is_instance_valid(survivor_icon) and ui._icon_for(queue, survivor) == survivor_icon,
		"and it is not the survivor's")
	log_line("")

	log_line("======== skills are the database's, and only those ========")
	for comb in combat.combatants:
		var definition: CombatantDefinition = CombatantDatabase.combatants.get(comb.get("combatant_key", ""))
		if definition == null:
			continue
		var extra = []
		for key in comb.skill_list:
			if not (key in definition.skills):
				extra.append(key)
		ok(extra.is_empty(), "%s knows nothing their entry does not list" % comb.name, "%s" % [extra])
		var missing = []
		for key in definition.skills:
			if not (key in comb.skill_list):
				missing.append(key)
		ok(missing.is_empty(), "and everything it does" % [], "%s" % [missing])
	log_line("")

	log_line("======== the tooltip says what the move will do ========")
	var cyrus = null
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == "cyrus":
			cyrus = comb
	if cyrus != null:
		combat.current_combatant = combat.combatants.find(cyrus)
		var attack: SkillDefinition = SkillDatabase.skills[cyrus.skill_list[1]]
		var tooltip = ui.build_skill_tooltip(attack)
		ok(tooltip.contains(attack.name), "the tooltip names the skill")
		var damage_line = ""
		for line in tooltip.split("\n"):
			if line.begins_with("- Base Damage:"):
				damage_line = line
		if attack.deals_damage:
			ok(damage_line != "", "and carries a Base Damage line", damage_line)
			ok(not damage_line.contains("x%s" % attack.ability_modifier),
				"which is a number rather than the rule behind it", damage_line)
			# What the skill is worth before any defence, so it does not move with
			# whoever happens to be standing on the board.
			var worth = combat.base_skill_damage(cyrus, attack)
			ok(damage_line.contains(str(worth)),
				"and it is what the skill swings for", "%s vs %d" % [damage_line, worth])
	log_line("")

	log_line("======== Study ========")
	var study: SkillDefinition = SkillDatabase.skills.get("study")
	ok(study != null, "the skill is in the database")
	if study != null:
		ok(study.is_secondary, "it is a secondary action")
		ok(not study.deals_damage, "and does no damage")
		var reveals = false
		for effect in study.all_effects():
			if effect.type == EffectDefinition.EffectType.REVEAL:
				reveals = true
		ok(reveals, "what it does is lay the target open")
		# Whoever carries it is a decision about the party, not about the skill.
		var students = []
		for key in CombatantDatabase.combatants:
			var definition: CombatantDefinition = CombatantDatabase.combatants[key]
			if "study" in definition.skills or "study" in definition.secondary_skills:
				students.append(key)
		ok(not students.is_empty(), "somebody in the game knows it", "%s" % [students])

		var subject = enemies()[0]
		ok(not subject.get("studied", false), "an enemy starts unmeasured")
		var sheet = game.get_node_or_null("CharacterSheet")
		ok(sheet != null, "the character sheet is in the scene")
		if sheet != null:
			var listed_before = sheet._gather()
			var found_before = false
			for entry in listed_before:
				if entry.name == subject.name:
					found_before = true
			ok(not found_before, "and cannot be read before being studied")
		combat.apply_effect(cyrus, subject, study.all_effects()[0], study)
		ok(subject.get("studied", false), "studying them marks them read")
		if sheet != null:
			var listed = sheet._gather()
			var entry = {}
			for candidate in listed:
				if candidate.name == subject.name:
					entry = candidate
			ok(not entry.is_empty(), "after which they are on the sheet")
			if not entry.is_empty():
				ok(entry.has("hp") and entry.has("max_hp"), "with their health")
				ok(entry.get("stats", {}).size() > 0, "their attributes", "%s" % [entry.stats.keys()])
				ok(entry.has("movement"), "their movement", "%s" % entry.get("movement"))
				ok(entry.has("resistances"), "what they resist")
				ok(entry.get("skills", []).size() > 0, "and everything they can do",
					"%s" % [entry.get("skills", [])])
			ok(sheet.is_open(), "and the sheet opened on the finding")
			sheet.close()
	log_line("")

	log_line("======== studying someone makes them easier to hit ========")
	if study != null and cyrus != null:
		var mark: SkillDefinition = SkillDatabase.skills[cyrus.skill_list[1]]
		# Room for the bonus to show: at 100% accuracy the clamp swallows it and
		# the test would pass while proving nothing.
		var written_accuracy = mark.accuracy
		mark.accuracy = 50
		var fresh = enemies()[1] if enemies().size() > 1 else enemies()[0]
		var plain = combat.hit_chance(cyrus, mark, fresh)
		ok(plain == clampi(mark.accuracy + combat.get_effective_stat(cyrus, "accuracy"), 0, 100),
			"an unstudied enemy is the skill's own accuracy", "%d%%" % plain)
		combat.apply_effect(cyrus, fresh, study.all_effects()[0], study)
		var after = combat.hit_chance(cyrus, mark, fresh)
		# Studying somebody used to be worth ten points of accuracy to whoever
		# did it. What Study is worth now is the reading alone - the sheet, and
		# knowing what you are walking into - with no thumb on the scale after.
		ok(after == plain, "studying them does not steady the hand that did it",
			"%d%% before, %d%% after" % [plain, after])
		ok(fresh.get("studied", false), "though it does open them up to be read")
		var bystander = null
		for comb in combat.combatants:
			if comb.side == 0 and comb.alive and comb != cyrus:
				bystander = comb
		if bystander != null:
			var theirs = combat.hit_chance(bystander, mark, fresh)
			ok(theirs == clampi(mark.accuracy + combat.get_effective_stat(bystander, "accuracy"), 0, 100),
				"and neither does anybody else's reading", "%d%%" % theirs)
		ok(combat.hit_chance(cyrus, mark, {}) == plain, "and aiming at nobody is unchanged")
		mark.accuracy = written_accuracy
	log_line("")

	log_line("======== an interactable can move where it stands ========")
	var torch = ExamineInteractable.new()
	torch.text = "It burns steadily."
	add_child(torch)
	await get_tree().process_frame
	ok(torch._animated == null, "with no frames it has nothing animating")

	# Frames built here rather than borrowed, so this tests the wiring and not
	# whatever art happens to be in the project.
	var frames := SpriteFrames.new()
	frames.add_animation("burning")
	frames.set_animation_speed("burning", 8.0)
	for i in 3:
		var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		image.fill(Color(1.0, 0.5 + i * 0.1, 0.0))
		frames.add_frame("burning", ImageTexture.create_from_image(image))
	torch.animation = "burning"
	torch.sprite_frames = frames
	await get_tree().process_frame
	ok(torch._animated != null, "giving it frames gives it something that animates")
	if torch._animated != null:
		ok(torch._animated.animation == "burning", "playing the animation it was told to",
			torch._animated.animation)
		ok(torch._animated.is_playing(), "and actually playing, rather than sitting on frame one")
		ok(torch._animated.sprite_frames == frames, "from the frames it was given")
		torch.animation_speed = 2.0
		ok(is_equal_approx(torch._animated.speed_scale, 2.0), "speed can be trimmed per interactable",
			"%s" % torch._animated.speed_scale)
		# A name that is not in the set should still show something.
		torch.animation = "no_such_animation"
		await get_tree().process_frame
		ok(torch._animated.animation == "burning",
			"a name the set does not have falls back to what it does have", torch._animated.animation)

	# Taking the frames away puts it back to a still.
	torch.sprite_frames = null
	await get_tree().process_frame
	ok(torch._animated == null or not is_instance_valid(torch._animated),
		"and taking them away leaves nothing behind")

	# None of this disturbs what an interactable is for.
	Campaign.reset()
	torch.sets_flag = "torch_lit"
	_logged.clear()
	torch.use(self)
	ok(Campaign.flag("torch_lit"), "it still does its job when used")
	torch.queue_free()
	log_line("")

	log_line("======== how many castings a level buys ========")
	var ladder = {1: [0, 2, 0, 0], 2: [0, 3, 2, 1], 3: [0, 3, 3, 2]}
	for level in ladder:
		ok(Stats.gates_for_level(level) == ladder[level],
			"a level %d caster has %s" % [level, ladder[level].slice(1)],
			"%s" % [Stats.gates_for_level(level).slice(1)])
	var first = Stats.gates_for_level(2)
	first[1] = 99
	ok(Stats.gates_for_level(2)[1] == 3,
		"and spending one caster's allowance does not spend everyone's", "%d" % Stats.gates_for_level(2)[1])

	# On real characters, through the path the game actually takes.
	var mage: CombatantDefinition = null
	var fighter: CombatantDefinition = null
	for key in CombatantDatabase.combatants:
		var definition: CombatantDefinition = CombatantDatabase.combatants[key]
		if definition.casts_spells() and mage == null:
			mage = definition
		if not definition.casts_spells() and fighter == null:
			fighter = definition
	ok(mage != null, "somebody in the game casts", mage.name if mage else "nobody")
	if mage != null:
		for level in [1, 2, 3]:
			var spawn = SpawnDefinition.new()
			spawn.level = level
			var cast = combat.create_combatant(mage, "", "", spawn)
			ok(cast.max_spell_slots == ladder[level],
				"%s at level %d gets %s" % [mage.name, level, ladder[level].slice(1)],
				"%s" % [cast.max_spell_slots.slice(1)])
			ok(cast.spell_slots == cast.max_spell_slots, "starting the fight with all of them unspent")
	if fighter != null:
		var swordsman = combat.create_combatant(fighter, "", "", null)
		ok(swordsman.max_spell_slots == [0, 0, 0, 0],
			"%s, who casts nothing, has no castings at all" % fighter.name,
			"%s" % [swordsman.max_spell_slots])
	log_line("")

	log_line("======== the gates ========")
	ok(Stats.gate_name(1) == "Gates of World", "level 1 is the Gates of World", Stats.gate_name(1))
	ok(Stats.gate_name(2) == "Gates of Hermes", "level 2 the Gates of Hermes", Stats.gate_name(2))
	ok(Stats.gate_name(3) == "Gates of Yaldabaoth", "level 3 the Gates of Yaldabaoth", Stats.gate_name(3))
	ok(Stats.gate_name(0) == "", "and a skill that costs nothing names no gate")
	var caster = null
	for comb in combat.combatants:
		if comb.side == 0 and comb.get("max_spell_slots", [0,0,0,0])[1] > 0:
			caster = comb
	if caster != null:
		combat.current_combatant = combat.combatants.find(caster)
		ui._update_spell_slots(caster)
		var tag = ui.get_node_or_null("Actions/SpellSlots/Gate1")
		ok(tag != null and tag.tooltip_text.contains("Gates of World"),
			"the HUD names the gate rather than numbering it", tag.tooltip_text if tag != null else "no tag")
		ok(tag != null and tag.uses() == Vector2i(caster.spell_slots[1], caster.max_spell_slots[1]),
			"and shows how many are left", "%s" % (tag.uses() if tag != null else Vector2i(-1, -1)))
	# A spell says what it costs in the same words.
	var spell = null
	for key in SkillDatabase.skills:
		if SkillDatabase.skills[key].spell_slot_level > 0:
			spell = SkillDatabase.skills[key]
			break
	if spell != null:
		var tip = ui.build_skill_tooltip(spell)
		# The HUD says the name on its own - "Hermes", not "Gates of Hermes" -
		# since a row of slots is too narrow for the prefix and whoever is
		# reading it has just read it twice already.
		ok(tip.contains(Stats.short_gate_name(spell.spell_slot_level)),
			"a spell's tooltip names the gate it is cast through",
			"%s costs %s" % [spell.name, Stats.gate_name(spell.spell_slot_level)])
		ok(not tip.contains("spell slot"), "and nothing still calls it a slot")
	log_line("")

	log_line("======== conditions are visible on the HUD ========")
	var victim = null
	for comb in combat.combatants:
		if comb.side == 0 and comb.alive:
			victim = comb
	var burn: ConditionDefinition = load("res://conditions/burn.tres")
	var condition_effect := EffectDefinition.new()
	condition_effect.type = EffectDefinition.EffectType.CONDITION
	condition_effect.condition = burn
	condition_effect.condition_duration = 3
	# With a skill behind it, as every condition in the game has: a tick with no
	# caster falls back to a flat random roll, which is a different number every
	# time anything asks for it.
	var burner: SkillDefinition = SkillDatabase.skills["fireball"]
	combat.apply_effect(enemies()[0], victim, condition_effect, burner)
	ok(victim.status_effects.size() > 0, "the condition is on them", "%d effects" % victim.status_effects.size())
	combat.update_combatants.emit(combat.combatants)
	await get_tree().process_frame
	var portrait = ui._icon_for(ui.get_node("Status"), victim)
	ok(portrait != null, "they have a portrait in the party column")
	if portrait != null:
		var strip = portrait.get_node_or_null("Layout/Icon/Conditions")
		ok(strip != null, "which now carries a strip of marks")
		if strip != null:
			ok(strip.get_child_count() == victim.status_effects.size(),
				"one mark per effect", "%d marks" % strip.get_child_count())
			# The fight is live and the AI may already have put something on them, so
			# the Burn is found rather than assumed to be first.
			var burn_index = 0
			for i in victim.status_effects.size():
				if victim.status_effects[i].get("condition") == burn:
					burn_index = i
			var burning = victim.status_effects[burn_index]
			var mark = strip.get_child(burn_index)
			ok(mark.tooltip_text != "", "each mark says what it is on hover")
			ok(mark.tooltip_text.contains(burn.display_name), "naming the condition", mark.tooltip_text)
			ok(mark.tooltip_text.contains("a turn"), "with what it costs per turn")
			# Read off the effect rather than written in: a condition landing on
			# whoever is already acting loses a turn, because their tick has been
			# and gone, and that is the behaviour rather than a rounding error.
			var left = burning.get("duration", 0)
			ok(mark.tooltip_text.contains("%d turns" % left) or mark.tooltip_text.contains("1 turn"),
				"and how long it lasts", "%d turns left" % left)
			# The number shown has to be the number the tick will take. Asked of the
			# strip here rather than read off the tooltip built earlier: the fight is
			# live, and between the two the target can be debuffed, healed or take a
			# turn - which would be the test racing the battle rather than checking
			# the arithmetic.
			var per_turn = combat.resisted_damage(victim, burn.dot_type,
				combat.dot_tick(victim, burning.get("dot_base", 0.0), burn.dot_min, burn.dot_max))
			ok(strip.describe(victim, burning).contains(str(per_turn)),
				"matching what a tick actually takes off", "%d, said: %s" % [per_turn, strip.describe(victim, burning)])
			ok(mark.mouse_filter == Control.MOUSE_FILTER_STOP, "and the mouse can reach it")

	# The enemies carry theirs under the turn queue rather than beside a portrait.
	var studied_enemy = enemies()[0]
	combat.apply_effect(victim, studied_enemy, condition_effect, burner)
	combat.update_combatants.emit(combat.combatants)
	await get_tree().process_frame
	var queue_icon = ui._icon_for(ui.get_node("TurnQueue/Queue"), studied_enemy)
	ok(queue_icon != null, "an enemy has a queue icon")
	if queue_icon != null:
		var enemy_strip = queue_icon.get_node_or_null("Conditions")
		ok(enemy_strip != null and enemy_strip.get_child_count() > 0,
			"with its own marks underneath")
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
