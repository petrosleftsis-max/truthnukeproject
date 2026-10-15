extends Node
## Resuscitate: Alithia spends a Yaldabaoth gate to stand a fallen ally back up
## at half their health - and they are a tenth less of everything but their
## movement afterwards, for good, compounding each time. And the party's tiles:
## everybody on the one written for them, with their own numbers.

var LOG_PATH := HarnessLog.path_for("resuscitate")

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
	get_tree().create_timer(240.0, true, false, true).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	var booted = get_tree().current_scene
	if booted != null:
		booted.queue_free()
		await settle()
	await the_skill()
	await in_a_fight()
	await own_tiles()
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


func open_fight(path: String) -> Node:
	Campaign.current_encounter = load(path)
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(6)
	var combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(2)
	return game


func fighter(combat, key: String) -> Dictionary:
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == key:
			return comb
	return {}


## Hands `who` the turn, with nothing in the way of acting.
func give_turn(combat, who: Dictionary):
	combat.current_combatant = combat.combatants.find(who)
	combat.controller.set_controlled_combatant(who)
	combat.controller.player_turn = true
	combat.controller.action_locked = false
	who.skill_used_this_turn = false


## Moves `who` to `tile` on the board.
func put(combat, who: Dictionary, tile: Vector2i):
	var from: Vector2i = who.position
	who.position = tile
	who.sprite.position = combat.controller.tile_map.map_to_local(tile)
	combat.controller.reposition_combatant(from, tile)


## A free tile beside `tile` that anybody can stand on.
func free_beside(combat, tile: Vector2i, movement_class: int) -> Vector2i:
	for way in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP, Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
		var there: Vector2i = tile + way
		if combat.controller.is_in_bounds(there) and combat.get_combatant_at(there).is_empty() \
				and not combat.controller.is_tile_blocking(there, movement_class):
			return there
	return Vector2i(-1, -1)


func the_skill():
	log_line("======== the skill ========")
	var skill: SkillDefinition = SkillDatabase.skills.get("resuscitate")
	ok(skill != null and skill.name == "Resuscitate", "there is a Resuscitate")
	ok(skill != null and skill.spell_slot_level == 3, "through the Gates of Yaldabaoth")
	ok(skill != null and skill.targets_ally and skill.targets_fallen, "aimed at a fallen ally")
	var revive: EffectDefinition = skill.effects[0] if skill != null and not skill.effects.is_empty() else null
	ok(revive != null and revive.type == EffectDefinition.EffectType.REVIVE and is_equal_approx(revive.revive_health, 0.5)
		and is_equal_approx(revive.revive_weakening, 0.1), "back at half their health, a tenth weaker")
	ok(CombatantDatabase.combatants.alithia.skills.has("resuscitate"), "and it is Alithia's")
	log_line("")


func in_a_fight():
	Campaign.reset()
	var game = await open_fight("res://data/encounters/encounter_03_watcher.tres")
	var combat = game.get_node("VisualCombat")
	var controller = combat.controller
	var ui = combat.game_ui
	var skill: SkillDefinition = SkillDatabase.skills.resuscitate
	var alithia := fighter(combat, "alithia")
	var cyrus := fighter(combat, "cyrus")
	var enfina := fighter(combat, "enfina")
	var before := {"stats": cyrus.stats.duplicate(), "max_hp": cyrus.max_hp, "initiative": cyrus.initiative,
		"weapon_base": cyrus.weapon_base, "movement": cyrus.movement}

	log_line("======== nobody fallen ========")
	ok(combat.wasted_on(alithia, skill) != "", "with nobody down, it would do nothing, and says so", combat.wasted_on(alithia, skill))

	log_line("")
	log_line("======== aiming at the fallen ========")
	var spot := free_beside(combat, alithia.position, cyrus.movement_class)
	put(combat, cyrus, spot)
	cyrus.hp = 0
	combat.combatant_die(cyrus)
	await settle(2)
	ok(not cyrus.alive, "(Cyrus is down, beside Alithia)")
	ok(combat.wasted_on(alithia, skill) == "", "now there is somebody to bring back")
	give_turn(combat, alithia)
	controller.set_selected_skill("resuscitate")
	controller.begin_target_selection()
	await settle(2)
	ok(controller.aim_subject_at(cyrus.position) == cyrus, "aimed at his tile, it is him it means")
	ok(controller.refusal_at(cyrus.position, cyrus) == "", "and it can be let go there")
	ok(controller.pad_tiles() == [cyrus.position], "a pad goes straight to him", "%s" % [controller.pad_tiles()])
	var standing_tile: Vector2i = enfina.position
	ok(controller.refusal_at(standing_tile, controller.aim_subject_at(standing_tile)) != "",
		"nobody standing can be aimed at", controller.refusal_at(standing_tile, controller.aim_subject_at(standing_tile)))
	ok(controller.refusal_at(alithia.position, alithia) != "", "least of all herself")
	var foe = {}
	for comb in combat.combatants:
		if comb.side == 1 and comb.alive:
			foe = comb
			break
	foe.hp = 0
	combat.combatant_die(foe)
	ok(controller.aim_subject_at(foe.position).is_empty() and controller.refusal_at(foe.position, foe) != "",
		"nor an enemy who has fallen", controller.refusal_at(foe.position, foe))
	ok(ui.describe_effect(skill.effects[0]).contains("50%") and ui.describe_effect(skill.effects[0]).contains("10%"),
		"its tooltip says half health, a tenth weaker", ui.describe_effect(skill.effects[0]))
	controller.cancel_skill_selection()

	log_line("")
	log_line("======== back on his feet ========")
	var yaldabaoth_before: int = alithia.spell_slots[3]
	await combat.use_skill("resuscitate", alithia, cyrus.position, false)
	await settle(3)
	ok(cyrus.alive and combat.groups[Combat.Group.PLAYERS].has(combat.combatants.find(cyrus)), "Cyrus is back in the fight")
	ok(cyrus.max_hp == roundi(before.max_hp * 0.9) and cyrus.hp == roundi(cyrus.max_hp * 0.5),
		"at half of his health - which is a tenth less now", "%d/%d" % [cyrus.hp, cyrus.max_hp])
	var weaker := true
	for key in before.stats:
		weaker = weaker and cyrus.stats[key] == maxi(1, roundi(before.stats[key] * 0.9))
	ok(weaker, "every attribute a tenth down", "%s from %s" % [cyrus.stats, before.stats])
	ok(cyrus.initiative == roundi(before.initiative * 0.9) and cyrus.weapon_base == roundi(before.weapon_base * 0.9),
		"his initiative and weapon too", "%d, %d" % [cyrus.initiative, cyrus.weapon_base])
	ok(cyrus.movement == before.movement, "but not how far he can walk")
	ok(alithia.spell_slots[3] == yaldabaoth_before - 1, "a Yaldabaoth gate spent")
	ok(controller._occupied_spaces.has(cyrus.position), "his tile his again")
	ok(ui._icon_for(ui.get_node("TurnQueue/Queue"), cyrus) != null, "and his face back in the turn queue")

	log_line("")
	log_line("======== again, with somebody on the spot ========")
	var fell_at: Vector2i = cyrus.position
	cyrus.hp = 0
	combat.combatant_die(cyrus)
	put(combat, enfina, fell_at)
	await settle(2)
	alithia.skill_used_this_turn = false
	alithia.spell_slots[3] = 1
	await combat.use_skill("resuscitate", alithia, fell_at, false)
	await settle(3)
	ok(cyrus.alive and cyrus.position != fell_at and cyrus.position != enfina.position, "he gets up beside whoever is standing on the spot",
		"%s, Enfina on %s" % [cyrus.position, enfina.position])
	var twice := true
	for key in before.stats:
		twice = twice and cyrus.stats[key] == maxi(1, roundi(before.stats[key] * 0.81))
	ok(twice and cyrus.max_hp == roundi(before.max_hp * 0.81), "and a second time takes a tenth off what the first left",
		"%s, %d" % [cyrus.stats, cyrus.max_hp])

	log_line("")
	log_line("======== for good ========")
	Campaign.record_party(combat.combatants)
	ok(is_equal_approx(Campaign.party_state.cyrus.get("frailty", 1.0), 0.81), "the fight over, it is remembered",
		"%s" % Campaign.party_state.cyrus.get("frailty", 1.0))
	game.queue_free()
	await settle(3)
	game = await open_fight("res://data/encounters/encounter_03_watcher.tres")
	combat = game.get_node("VisualCombat")
	cyrus = fighter(combat, "cyrus")
	var carried := true
	for key in before.stats:
		carried = carried and cyrus.stats[key] == maxi(1, roundi(before.stats[key] * 0.81))
	ok(carried and cyrus.max_hp == roundi(before.max_hp * 0.81) and cyrus.movement == before.movement,
		"the next fight, he is still weaker", "%s, %d" % [cyrus.stats, cyrus.max_hp])
	game.queue_free()
	await settle(3)
	Campaign.reset()
	game = await open_fight("res://data/encounters/encounter_03_watcher.tres")
	combat = game.get_node("VisualCombat")
	ok(fighter(combat, "cyrus").stats == before.stats, "until the party is started over")
	game.queue_free()
	await settle(3)
	log_line("")


func own_tiles():
	log_line("======== everybody on their own tile ========")
	var lab: EncounterDefinition = load("res://data/encounters/encounter_02_sappers.tres")
	var loadouts: Array = lab.spawns.filter(func(spawn): return spawn.side == 0)
	var placed := Combat.party_tiles_for(["cyrus", "enfina", "prometheus", "alithia"], loadouts, loadouts.size())
	var written := {}
	for i in loadouts.size():
		written[loadouts[i].combatant_key] = i
	ok(placed.cyrus == written.cyrus and placed.enfina == written.enfina and placed.prometheus == written.prometheus
		and placed.alithia == written.alithia, "the lab's party, walking in another order, each on the tile written for them",
		"%s" % [placed])
	placed = Combat.party_tiles_for(["cyrus", "nobody_here", "enfina"], loadouts, loadouts.size())
	ok(placed.cyrus == written.cyrus and placed.enfina == written.enfina and placed.has("nobody_here")
		and not [written.cyrus, written.enfina].has(placed.nobody_here), "somebody with no tile of their own takes one left over")
	placed = Combat.party_tiles_for(["a", "b", "c", "d", "cyrus"], loadouts, loadouts.size())
	ok(placed.size() == 4 and placed.cyrus == written.cyrus and not placed.has("d"),
		"with too many, it is whoever has no tile and comes last who sits out", "%s" % [placed])
	Campaign.reset()
	Campaign.set_party(["cyrus", "enfina", "prometheus", "alithia"], 2)
	var game = await open_fight("res://data/encounters/encounter_02_sappers.tres")
	var combat = game.get_node("VisualCombat")
	var right := true
	var got := {}
	for spawn in loadouts:
		var comb := fighter(combat, spawn.combatant_key)
		got[spawn.combatant_key] = comb.stats.get("defense", -1)
		right = right and comb.stats.get("defense", -1) == spawn.defense
	ok(right, "in the fight, everybody's defence is their own", "%s" % [got])
	game.queue_free()
	await settle(3)
	Campaign.reset()
	log_line("")
