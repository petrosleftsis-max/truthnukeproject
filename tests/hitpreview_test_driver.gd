extends Node
## The prompt shown while aiming: who a skill would catch and what it would do
## to each of them. Above all, that what it promises is what then happens.

var LOG_PATH := HarnessLog.path_for("hitpreview")

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
	get_tree().create_timer(150.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


## Every piece of text in the prompt, or nothing while it is not on screen.
func prompt_text(ui) -> String:
	if ui._hit_preview == null or not ui._hit_preview.visible:
		return ""
	var found = []
	for label in ui.find_children("*", "Label", true, false):
		if ui._hit_preview != null and ui._hit_preview.is_ancestor_of(label):
			found.append(label.text)
	return " / ".join(found)


## Somewhere `mover` can be put that `from` has a clear shot at, `near` tiles
## away.
func open_tile_near(combat: Combat, from: Dictionary, mover: Dictionary, near: int) -> Vector2i:
	for dx in range(-near, near + 1):
		for dy in range(-near, near + 1):
			var tile = from.position + Vector2i(dx, dy)
			if combat.get_position_distance(from.position, tile) != near:
				continue
			if combat.can_land_on(mover, tile) and combat.has_line_of_sight(from.position, tile, from.movement_class):
				return tile
	return Vector2i(-99999, -99999)


func run_test():
	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_02_sappers.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	for i in 4:
		await get_tree().process_frame
	var combat: Combat = game.get_node("VisualCombat")
	var ui = game.get_node("CanvasLayer/UI")
	var controller = game.get_node("Controller")
	combat.finish_deployment()
	await get_tree().process_frame

	var shooter = combat.get_current_combatant()
	var mark = {}
	for comb in combat.combatants:
		if comb.side == 1 and comb.alive and mark.is_empty():
			mark = comb
	# Nothing reacting to anything, and nobody asking the player about it.
	for comb in combat.combatants:
		comb.reaction_used = true

	log_line("======== a plain shot: what it promises is what it does ========")
	var gun: SkillDefinition = SkillDatabase.skills["gun"]
	var spot = open_tile_near(combat, shooter, mark, 3)
	ok(spot.x > -99999, "found a clear line to put the target on", "%s" % spot)
	combat.teleport_to(mark, spot)
	var caught = combat.targets_if_aimed(shooter, gun, mark.position)
	ok(caught.size() == 1 and caught[0] == mark, "aimed at them, it catches them", "%d caught" % caught.size())
	var said = combat.predict_hit(shooter, mark, gun)
	ok(not said.contested and said.deals_damage and said.damage > 0, "and says it would deal damage", "%d" % said.damage)
	var before = mark.hp
	await combat.use_skill("gun", shooter, mark.position, false)
	ok(before - mark.hp == said.damage, "which is exactly what it then does",
		"promised %d, dealt %d" % [said.damage, before - mark.hp])
	ok(combat.targets_if_aimed(shooter, gun, shooter.position + Vector2i(99, 0)).is_empty(),
		"aimed out of reach, it catches nobody")
	log_line("")

	log_line("======== a contest: who wins, and what that leaves ========")
	# Fireball is contested, blast and all. Its caster is stood a clear shot away
	# and outside the blast - it catches both sides, its caster included, which
	# is a thing the prompt says too - and given the gates to throw it twice.
	var caster = {}
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == "prometheus":
			caster = comb
	var fireball: SkillDefinition = SkillDatabase.skills["fireball"]
	ok(fireball.uses_stat_contest, "Fireball is decided by a contest")
	caster.spell_slots = [0, 9, 9, 9]
	caster.skill_used_this_turn = false
	var clear = open_tile_near(combat, mark, caster, fireball.aoe_radius + 2)
	ok(clear.x > -99999, "somewhere to throw it from outside its own blast", "%s" % clear)
	combat.teleport_to(caster, clear)
	# Stood inside it, the caster is among those it would catch.
	var inside = combat.targets_if_aimed(caster, fireball, caster.position + Vector2i(1, 0))
	ok(inside.has(caster), "aimed at their own feet, it would catch the caster too, and says so")
	var contest_key = Stats.stat_key(fireball.contest_stat)
	# Beaten: their number below the caster's. Enough health to take two of
	# them, since the first has to leave somebody for the second to hit.
	mark.hp = 999
	mark.stats[contest_key] = 1
	said = combat.predict_hit(caster, mark, fireball)
	ok(said.contested and said.wins, "with their %s at 1, it lands in full" % Stats.stat_name(fireball.contest_stat),
		"theirs %d vs %d" % [said.their_stat, said.our_stat])
	before = mark.hp
	await combat.use_skill("fireball", caster, mark.position, false)
	ok(before - mark.hp == said.damage, "for exactly the damage it promised",
		"promised %d, dealt %d" % [said.damage, before - mark.hp])
	var full = said.damage
	# Shrugged off: their number above.
	mark.stats[contest_key] = 99
	caster.skill_used_this_turn = false
	said = combat.predict_hit(caster, mark, fireball)
	ok(said.contested and not said.wins, "with it at 99, it is shrugged off", "theirs %d vs %d" % [said.their_stat, said.our_stat])
	ok(said.damage < full, "for less than the full hit", "%d against %d" % [said.damage, full])
	ok(said.also.is_empty(), "and nothing else lands with it", "%s" % [said.also])
	var had = mark.status_effects.size()
	before = mark.hp
	await combat.use_skill("fireball", caster, mark.position, false)
	ok(before - mark.hp == said.damage, "which is again exactly what it does",
		"promised %d, dealt %d" % [said.damage, before - mark.hp])
	ok(mark.status_effects.size() <= had, "and what it said would not land, did not")
	log_line("")

	log_line("======== the prompt itself ========")
	mark.stats[contest_key] = 1
	combat.current_combatant = combat.combatants.find(caster)
	caster.skill_used_this_turn = false
	controller.set_selected_skill("fireball")
	controller.begin_target_selection()
	controller._preview_hits(mark.position)
	ok(ui._hit_preview != null and ui._hit_preview.visible, "aiming at them brings the prompt up")
	var text = prompt_text(ui)
	said = combat.predict_hit(caster, mark, fireball)
	ok(text.contains(mark.name) and text.contains("%d damage" % said.damage), "naming them and the damage",
		text)
	ok(text.contains("Their %s %d vs your %s %d" % [said.their_stat_name, said.their_stat, said.our_stat_name, said.our_stat]),
		"and whose number wins the contest")
	ok(text.contains("lands in full"), "and that it lands in full")
	mark.stats[contest_key] = 99
	controller._preview_hits(mark.position)
	text = prompt_text(ui)
	ok(text.contains("shrugged off"), "or that it is shrugged off, when it would be", text)
	mark.stats[contest_key] = 1
	controller._preview_hits(caster.position + Vector2i(99, 0))
	ok(not ui._hit_preview.visible, "aimed at nothing it can reach, the prompt goes away")
	controller._preview_hits(mark.position)
	combat.set_hidden(mark, true)
	controller._preview_hits(mark.position)
	ok(not prompt_text(ui).contains(mark.name), "somebody hidden is never named, which would give them away",
		prompt_text(ui))
	combat.set_hidden(mark, false)
	controller._preview_hits(mark.position)
	ok(ui._hit_preview.visible, "back in sight, back in the prompt")
	controller.cancel_skill_selection()
	await get_tree().process_frame
	ok(not ui._hit_preview.visible, "and putting the skill away takes the prompt with it")
	var screen = ui.get_viewport_rect().size
	var box = Rect2(ui._hit_preview.global_position, ui._hit_preview.get_combined_minimum_size())
	ok(Rect2(Vector2.ZERO, screen).encloses(box), "it was kept on the screen", "%s in %s" % [box, screen])
	log_line("")

	game.queue_free()
	await get_tree().process_frame
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
