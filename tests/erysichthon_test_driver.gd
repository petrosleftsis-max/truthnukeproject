extends Node
## Erysichthon, started over by the designer on 2026-11-27 (docs/erysichthon.md), on his new stage
## (data/encounters/boss_erysichthon.tres): his numbers and immunities (Boss Immunities), Vitality Devour, Chomp, Gate Devour
## and its three reactions a round, the belly growing with what he devours and giving it all back when torn open (with its
## prize, and the Gnawers it calls), Feast at half health and every turn at a quarter, the Rotten Meal, Demeter's sacred trees,
## and a turn of his blows (Combat "Devouring", "A turn of several blows").

var LOG_PATH := HarnessLog.path_for("erysichthon")
var _log: FileAccess
var _fail = 0
var combat = null
var said: Array = []


func log_line(t): _log.store_line(t); _log.flush()

func ok(condition: bool, label: String, detail: String = ""):
	if condition:
		log_line("  PASS  %s %s" % [label, detail])
	else:
		_fail += 1
		log_line("  FAIL  %s %s" % [label, detail])


func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(300.0, true, false, true).timeout.connect(func():
		log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


func who(key: String) -> Dictionary:
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == key and comb.alive:
			return comb
	return {}


func all_of(key: String) -> Array:
	return combat.combatants.filter(func(comb): return comb.get("combatant_key", "") == key and comb.alive)


func put(comb: Dictionary, tile: Vector2i):
	var from: Vector2i = comb.position
	comb.position = tile
	combat.controller.reposition_combatant(from, tile)
	var sprite = comb.get("sprite")
	if sprite != null and is_instance_valid(sprite):
		sprite.position = combat.sprite_point(comb)


## A free tile `gap` tiles out from `boss` (1: right beside it) that `comb` has room on.
func near(boss: Dictionary, comb: Dictionary, gap: int = 1) -> Vector2i:
	var rect: Rect2i = combat.rect_of(boss)
	for y in range(rect.position.y - gap, rect.end.y + gap):
		for x in range(rect.position.x - gap, rect.end.x + gap):
			var tile := Vector2i(x, y)
			if combat.rect_gap(rect, Rect2i(tile, Vector2i.ONE)) != gap:
				continue
			if combat.room_for(comb, tile) and combat.get_combatant_at(tile).is_empty():
				return tile
	return Vector2i(-99999, -99999)


func heard(words: String) -> bool:
	return said.any(func(line): return words in line)


func open_fresh() -> Node:
	Campaign.reset()
	Campaign.current_encounter = load("res://data/encounters/boss_erysichthon.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(8)
	combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(1)
	combat.reaction_prompt = null
	said.clear()
	combat.update_information.connect(func(line): said.append(line))
	return game


func run_test():
	await the_stage()
	await draining()
	await gate_devour()
	await the_belly()
	await feast()
	await swallowing()
	await starving()
	await staggered()
	await hidden_phases()
	await the_trees()
	await his_turn()


func swallowing():
	log_line("======== swallowed whole ========")
	var game = await open_fresh()
	var boss := who("glutton")
	var cyrus := who("cyrus")
	var alithia := who("alithia")
	var enfina := who("enfina")
	for comb in combat.combatants:
		comb.reaction_used = true
	put(cyrus, near(boss, cyrus, 2))
	var most: int = combat.get_effective_stat(cyrus, "max_hp")
	cyrus.hp = maxi(int(most * 0.2), 1)
	var left: int = cyrus.hp
	await combat.use_skill("chomp", boss, cyrus.position, false)
	await settle()
	ok(combat.is_inside(cyrus) and cyrus.alive and cyrus.hp == left, "a Chomp on Cyrus under a quarter of his health: swallowed, not bitten",
		"%d / %d" % [cyrus.hp, most])
	ok(combat.belly_open(boss) and int(boss.belly.most) == left, "into the belly, which grows by what he has left", "%d" % int(boss.belly.most))
	# Feast swallows the badly hurt too, and lands on nobody already inside.
	var most_hp: int = combat.get_effective_stat(boss, "max_hp")
	boss.hp = roundi(most_hp * 0.55)
	combat.lose_hp(boss, roundi(most_hp * 0.06))
	alithia.hp = maxi(int(combat.get_effective_stat(alithia, "max_hp") * 0.2), 1)
	enfina.max_hp = maxi(enfina.max_hp, 400)
	enfina.hp = enfina.max_hp
	var enfina_was: int = enfina.hp
	var cyrus_was: int = cyrus.hp
	combat.current_combatant = combat.combatants.find(boss)
	combat.controller.set_controlled_combatant(boss)
	boss.skill_used_this_turn = false
	boss.secondary_used_this_turn = false
	await combat.use_skill("feast", boss, boss.position, false)
	await settle(3)
	ok(combat.is_inside(alithia) and enfina.hp < enfina_was and cyrus.hp == cyrus_was,
		"a Feast: Alithia, badly hurt, swallowed; Enfina hit; Cyrus, inside, untouched")
	# Torn open, it lets them out alive.
	combat._aimed_tile = boss.position + Vector2i(0, 2)
	combat._hit_part(boss, boss.parts_hp[boss.belly.index], enfina)
	combat._aimed_tile = null
	ok(not combat.is_inside(cyrus) and not combat.is_inside(alithia) and cyrus.alive and alithia.alive and heard("falls out of the torn belly"),
		"the belly torn open: out they fall, alive")
	# Left inside, they are digested in two of his turns.
	cyrus.hp = maxi(int(combat.get_effective_stat(cyrus, "max_hp") * 0.2), 1)
	put(cyrus, near(boss, cyrus, 2))
	boss.skill_used_this_turn = false
	await combat.use_skill("chomp", boss, cyrus.position, false)
	await settle()
	ok(combat.is_inside(cyrus) and cyrus.digest_left == 2, "swallowed again: two of his turns to get out", "%s" % cyrus.get("digest_left", 0))
	combat._digest(boss)
	ok(cyrus.alive and combat.is_inside(cyrus), "one of his turns: still inside")
	combat._digest(boss)
	ok(not cyrus.alive and not combat.is_inside(cyrus), "two: digested")
	game.queue_free()
	await settle()
	log_line("")


func starving():
	log_line("======== Starving ========")
	var game = await open_fresh()
	var boss := who("glutton")
	var cyrus := who("cyrus")
	var claw: SkillDefinition = SkillDatabase.skills["claw"]
	var fed_damage: int = combat.skill_damage(boss, cyrus, claw)
	combat._starving_turn_begins(boss)
	ok(is_zero_approx(combat.starving_bonus(boss)), "his first turn: no round behind it yet")
	combat._starving_turn_begins(boss)
	ok(is_equal_approx(combat.starving_bonus(boss), 0.1) and heard("is starving"), "a round devouring nothing: +10% Output Efficiency")
	combat._starving_turn_begins(boss)
	combat._starving_turn_begins(boss)
	combat._starving_turn_begins(boss)
	ok(is_equal_approx(combat.starving_bonus(boss), 0.3), "up to +30%, no more", "%s" % combat.starving_bonus(boss))
	var hungry_damage: int = combat.skill_damage(boss, cyrus, claw)
	ok(absi(hungry_damage - roundi(fed_damage * 1.3)) <= 1, "his Claw lands that much harder", "%d -> %d" % [fed_damage, hungry_damage])
	combat.drain_health(boss, cyrus, 10, 0.25)
	ok(is_zero_approx(combat.starving_bonus(boss)) and heard("its starving is over"), "the next thing he devours ends it")
	combat._starving_turn_begins(boss)
	ok(is_zero_approx(combat.starving_bonus(boss)), "and a round in which he devoured something starves him no more")
	game.queue_free()
	await settle()
	log_line("")


func staggered():
	log_line("======== staggered, his turn kept ========")
	var game = await open_fresh()
	var boss := who("glutton")
	var cyrus := who("cyrus")
	var alithia := who("alithia")
	combat.current_combatant = combat.combatants.find(cyrus)
	combat.add_stagger(boss, 200.0, "a test")
	ok(combat.is_staggered(boss) and boss.get("reeling_until", -1) == cyrus.id, "staggered in Cyrus's turn: Reeling until his next one")
	ok(not combat.has_restriction(boss, "skips_turn"), "his own turn not lost")
	ok(is_equal_approx(combat.damage_taken_multiplier(boss), 1.5), "hit harder meanwhile: +50%", "%s" % combat.damage_taken_multiplier(boss))
	combat.add_stagger(boss, 40.0, "a test")
	ok(is_zero_approx(boss.stagger), "his bar does not fill while he reels", "%s" % boss.stagger)
	combat._reeling_ends_for(alithia)
	ok(combat.is_staggered(boss), "Alithia's turn: still reeling")
	combat._reeling_ends_for(boss)
	ok(combat.is_staggered(boss), "his own: still reeling")
	combat._reeling_ends_for(cyrus)
	ok(not combat.is_staggered(boss) and heard("steadies itself"), "Cyrus's next turn: he steadies")
	combat.add_stagger(boss, 40.0, "a test")
	ok(is_equal_approx(boss.stagger, 40.0), "and his bar fills again", "%s" % boss.stagger)
	# Staggered in his own turn, he reels until his next.
	combat.current_combatant = combat.combatants.find(boss)
	combat.add_stagger(boss, 500.0, "a test")
	ok(boss.get("reeling_until", -1) == boss.id, "staggered in his own turn: until his next")
	combat._reeling_ends_for(boss)
	ok(not combat.is_staggered(boss), "which ends it")
	game.queue_free()
	await settle()
	log_line("")


func hidden_phases():
	log_line("======== what Study does not show ========")
	var game = await open_fresh()
	var boss := who("glutton")
	var definition: CombatantDefinition = CombatantDatabase.combatants["glutton"]
	var bars = combat.game_ui.get("_boss_bars")
	var row = bars.row_for(boss.id) if bars != null else null
	if row != null:
		ok(row.get_node("HealthBar").marks.is_empty(), "no marks on his health bar where a phase begins")
	var seen_one := CodexPage.second_page(definition, 1)
	ok(seen_one.contains("Famished") and not seen_one.contains("Insatiable"), "studied in his first phase past half: the codex tells of that one only")
	ok(not CodexPage.second_page(definition, 0).contains("Famished"), "studied before any: of none")
	Campaign.note_codex_phases("glutton", 1)
	Campaign.note_codex_phases("glutton", 0)
	ok(Campaign.codex_phases_seen("glutton") == 1, "the furthest he was studied in is kept")
	game.queue_free()
	await settle()
	log_line("")


func the_stage():
	log_line("======== the stage ========")
	var game = await open_fresh()
	var boss := who("glutton")
	var cyrus := who("cyrus")
	ok(not boss.is_empty() and boss.name == "Erysichthon" and combat.is_boss(boss), "Erysichthon is here, a boss")
	ok(boss.get("size", 0) == Sizes.Size.ENORMOUS and boss.span == 4 and boss.level == 22 and cyrus.level == 22,
		"four tiles a side, and the fight at level 22", "%d" % boss.get("level", 0))
	# The other side takes its place one lower in the order (Combat.add_combatant), so the party goes first on a tie.
	var his: CombatantDefinition = CombatantDatabase.combatants["glutton"]
	ok(his.movement == 8 and his.initiative == 6 and boss.movement == 8 and boss.initiative == 5, "movement 8, initiative 6",
		"%d / %d (%d in the order)" % [his.movement, his.initiative, boss.initiative])
	ok(combat.resistance_of(boss, Damage.Type.FIRE) == 100 and combat.resistance_of(boss, Damage.Type.EARTH) == 100
		and combat.resistance_of(boss, Damage.Type.POISON) < 0, "immune to fire and earth, weak to poison",
		"%d %d %d" % [combat.resistance_of(boss, Damage.Type.FIRE), combat.resistance_of(boss, Damage.Type.EARTH), combat.resistance_of(boss, Damage.Type.POISON)])
	var names: Array = boss.passives.map(func(passive): return passive.name)
	ok(names.has("Hollow Frame") and names.has("Vitality Devour") and names.has("Boss Immunities") and names.has("Starving"), "his passives",
		"%s" % [names])
	var shrugged := []
	for key in ["prone", "stunned", "hesitating", "confused", "deceived", "compelled", "fear", "blind", "deafened", "off_guard"]:
		if not combat.immune_to_condition(boss, load("res://data/conditions/%s.tres" % key)):
			shrugged.append(key)
	ok(shrugged.is_empty() and combat.immune_to(boss, Immunity.Kind.BREAKING),
		"Boss Immunities: Prone, Stunned, Hesitating, Confused, Deceived, Compelled, Fear, Blind, Deafened, Off Guard; never breaking",
		"not immune to %s" % [shrugged])
	ok(boss.skill_list.has("claw") and boss.skill_list.has("chomp") and boss.skill_list.has("gate_devour")
		and not boss.skill_list.has("feast") and boss.skill_list.size() == 3, "Claw, Chomp and Gate Devour - Feast not yet", "%s" % [boss.skill_list])
	ok(boss.get("reactions_per_round", 1) == 3 and boss.ai_function == "ai_attack_sets" and boss.attack_sets.size() == 1,
		"three reactions a round; one set of blows a turn")
	ok(boss.has("belly") and not combat.belly_open(boss) and combat.part_marks().is_empty()
		and combat.part_index_at(boss, boss.position + Vector2i(0, 2)) == -1, "no belly yet: nothing to aim at")
	var bar: StaggerDefinition = boss.get("stagger_def")
	ok(bar != null and bar.harder_until == StaggerDefinition.HarderUntil.THE_STAGGERERS_NEXT_TURN and is_equal_approx(bar.max_value, 150.0),
		"a stagger bar of 150 that costs him no turn")
	var trees := all_of("sacred_tree")
	ok(trees.size() == 4, "four sacred trees", "%d" % trees.size())
	# Where the encounter editor lets a spawn stand (tools/encounter_editor.gd, placement_problem): on the map's painted area,
	# on a painted tile, on ground a walker can enter.
	var tile_map: TileMap = combat.controller.tile_map
	var stands := func(tile: Vector2i) -> bool:
		return tile_map.get_used_rect().has_point(tile) and tile_map.get_cell_tile_data(0, tile) != null \
			and not combat.controller.is_tile_blocking(tile, 0)
	for tree in trees:
		var open: bool = stands.call(tree.position)
		var nearby := []
		if not open:
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					var tile: Vector2i = tree.position + Vector2i(dx, dy)
					if stands.call(tile) and combat.get_combatant_at(tile).is_empty():
						nearby.append(tile)
		ok(open, "  a tree where the editor lets it stand", "%s%s" % [tree.position, "" if open else " - open near it: %s" % [nearby]])
	ok(trees.all(func(tree): return combat.resistance_of(tree, Damage.Type.FIRE) < 0), "  and weak to fire")
	ok(combat.items_of(cyrus).size() > 0 and combat.items_of(cyrus)[0] == "rotten_meal", "Cyrus has a Rotten Meal ready, first",
		"%s" % [combat.items_of(cyrus)])
	ok(combat.arriving().size() == 6, "six Gnawers waiting", "%d" % combat.arriving().size())
	game.queue_free()
	await settle()
	log_line("")


func draining():
	log_line("======== Vitality Devour and Chomp ========")
	var game = await open_fresh()
	var boss := who("glutton")
	var cyrus := who("cyrus")
	for comb in combat.combatants:
		comb.reaction_used = true
	put(cyrus, near(boss, cyrus, 2))
	var most: int = combat.get_effective_stat(cyrus, "max_hp")
	cyrus.hp = most
	boss.hp = 300
	var claw: SkillDefinition = SkillDatabase.skills["claw"]
	ok(combat.effective_max_range(boss, claw) == 2 and combat.reach_gap(boss, cyrus, claw) == 2, "a Claw reaches two tiles")
	await combat.use_skill("claw", boss, cyrus.position, false)
	await settle()
	ok(combat.get_effective_stat(cyrus, "max_hp") == most - 10, "a Claw lands: 10 of Cyrus's maximum health drained",
		"%d -> %d" % [most, combat.get_effective_stat(cyrus, "max_hp")])
	ok(boss.hp > 300, "and Erysichthon healed by it", "%d" % boss.hp)
	ok(combat.belly_open(boss) and int(boss.belly.most) == 10 and boss.parts_hp[boss.belly.index] == 10,
		"his belly swells into being: 10 for 10 drained", "%d" % int(boss.belly.most))
	ok(combat.part_index_at(boss, boss.position + Vector2i(0, 2)) == boss.belly.index, "and can be aimed at")
	var main: int = cyrus.main_stat
	var had: int = combat.stat_of(cyrus, main)
	await combat.use_skill("chomp", boss, cyrus.position, false)
	await settle()
	ok(combat.stat_of(cyrus, main) == had - 5, "a Chomp: 5 of his %s gone" % Stats.stat_name(main), "%d -> %d" % [had, combat.stat_of(cyrus, main)])
	ok(int(boss.belly.most) == 10 + 10 + 15, "the belly: 10 more for the bite, 15 for the stat", "%d" % int(boss.belly.most))
	for i in 20:
		combat.drain_stat(boss, cyrus, 5, 10, 0.25)
	var floor_at: int = maxi(10, ceili(int(cyrus.stats[Stats.stat_key(main)]) * 0.25))
	ok(combat.stat_of(cyrus, main) == floor_at, "never below 10 or a quarter of it", "%d" % combat.stat_of(cyrus, main))
	for i in 40:
		combat.drain_health(boss, cyrus, 10, 0.25)
	ok(combat.get_effective_stat(cyrus, "max_hp") == ceili(most * 0.25), "nor his health below a quarter of what he had",
		"%d of %d" % [combat.get_effective_stat(cyrus, "max_hp"), most])
	ok(cyrus.hp <= combat.get_effective_stat(cyrus, "max_hp"), "his health no more than what is left of it")
	game.queue_free()
	await settle()
	log_line("")


func gate_devour():
	log_line("======== Gate Devour ========")
	var game = await open_fresh()
	var boss := who("glutton")
	for comb in combat.combatants:
		comb.reaction_used = comb != boss
	var caster := {}
	var spells: Array = []
	for key in ["prometheus", "alithia", "enfina", "cyrus"]:
		var them := who(key)
		var theirs: Array = combat.spell_skills_of(them).filter(func(spell_key): return Combat.is_spell(SkillDatabase.skills[spell_key]) \
			and not ItemDatabase.is_item(spell_key))
		if theirs.size() >= 3:
			caster = them
			spells = theirs
			break
	ok(not caster.is_empty(), "somebody with three spells to cast", "%s" % caster.get("name", "nobody"))
	if caster.is_empty():
		game.queue_free()
		await settle()
		return
	put(caster, near(boss, caster, 3))
	var first: SkillDefinition = SkillDatabase.skills[spells[0]]
	# The contest (a trial, 2026-11-27): the caster's casting stat under his Physical. At the same level they are equal.
	var casting_stat: int = combat.scaling_stat_of(caster, first)
	var theirs_now: int = combat.stat_of(caster, casting_stat)
	var his_now: int = combat.stat_of(boss, boss.main_stat)
	ok(not await combat._react_to_casting(caster, spells[0], first) and not boss.reaction_used and combat.devoured_by(caster, first).is_empty(),
		"%s's %s %d against his Physical %d: not swallowed, and no reaction spent" % [caster.name, Stats.stat_name(casting_stat), theirs_now, his_now])
	combat.drain_stat(boss, caster, 5, 10, 0.25)
	ok(combat.stat_of(caster, casting_stat) < his_now, "a Chomp's worth taken off it", "%d" % combat.stat_of(caster, casting_stat))
	boss.belly.inside.clear()
	boss.belly.most = 0
	boss.parts_hp[boss.belly.index] = 0
	var torn: bool = await combat._react_to_casting(caster, spells[0], first)
	ok(torn and heard("swallows"), "%s casts %s in his sight: torn apart and swallowed" % [caster.name, first.name], "%s" % [said.slice(-3)])
	ok(not combat.can_afford_skill(caster, first) and combat.wasted_on(caster, first) == "Devoured by Erysichthon.",
		"theirs to cast no more: \"Devoured by Erysichthon\"", combat.wasted_on(caster, first))
	ok(int(boss.belly.most) == 25 and not boss.reaction_used, "the belly: 25 for a spell; two reactions left", "%d" % int(boss.belly.most))
	var second: SkillDefinition = SkillDatabase.skills[spells[1]]
	await combat._react_to_casting(caster, spells[1], second)
	ok(not combat.devoured_by(caster, second).is_empty() and not boss.reaction_used, "a second: devoured too, one reaction left")
	var third: SkillDefinition = SkillDatabase.skills[spells[2]]
	await combat._react_to_casting(caster, spells[2], third)
	ok(not combat.devoured_by(caster, third).is_empty() and combat.devoured_by(caster, first).is_empty()
		and combat.can_afford_skill(caster, first), "a third pushes the first back out: %s is theirs again" % first.name)
	ok(boss.reaction_used, "three a round, and that was the third")
	boss.reaction_used = false
	boss.erase("reactions_spent")
	var nade: SkillDefinition = SkillDatabase.skills.get("heal_gate_nade")
	if nade != null:
		ok(not await combat._react_to_casting(caster, "heal_gate_nade", nade), "a spell out of a Gate Nade: left alone")
	put(caster, Vector2i(boss.position.x + 30, boss.position.y))
	if combat.controller.is_in_bounds(caster.position) and not combat.controller.is_tile_blocking(caster.position, 0):
		ok(not await combat._react_to_casting(caster, spells[0], first), "beyond 20 tiles: not reached")
	game.queue_free()
	await settle()
	log_line("")


func the_belly():
	log_line("======== the belly torn open ========")
	var game = await open_fresh()
	var boss := who("glutton")
	var cyrus := who("cyrus")
	var enfina := who("enfina")
	for comb in combat.combatants:
		comb.reaction_used = true
	var most: int = combat.get_effective_stat(cyrus, "max_hp")
	var main: int = cyrus.main_stat
	var had: int = combat.stat_of(cyrus, main)
	combat.drain_health(boss, cyrus, 10, 0.25)
	combat.drain_stat(boss, cyrus, 5, 10, 0.25)
	cyrus["casting"] = "instahack"
	cyrus["cast_cancelled"] = true
	combat.devour_spell(boss, cyrus)
	cyrus.erase("casting")
	cyrus.erase("cast_cancelled")
	var bag_before: int = Campaign.count_of("enfina", combat.items_of(enfina)[0]) if not combat.items_of(enfina).is_empty() else 0
	var item: String = combat.devour_item(boss, enfina)
	ok(item != "" and combat.belly_open(boss) and boss.belly.inside.size() == 4, "maximum health, a stat, a spell and an item inside",
		"%d inside" % boss.belly.inside.size())
	ok(combat.belly_marks().size() == 1 and combat.belly_marks()[0].icons.size() >= 1, "what it holds shown over it")
	var expected: int = 10 + 15 + 25 + 15
	ok(int(boss.belly.most) == expected, "its health: 10 + 15 + 25 + 15", "%d" % int(boss.belly.most))
	var prizes_before := {}
	for key in boss.belly.prize:
		prizes_before[key] = Campaign.count_of("cyrus", key)
	var boss_hp: int = boss.hp
	combat._aimed_tile = boss.position + Vector2i(0, 2)
	combat._hit_part(boss, expected, cyrus)
	combat._aimed_tile = null
	ok(not combat.belly_open(boss) and heard("torn open"), "struck for all of it: torn open")
	ok(combat.get_effective_stat(cyrus, "max_hp") == most and combat.stat_of(cyrus, main) == had,
		"Cyrus's maximum health and %s back" % Stats.stat_name(main))
	ok(cyrus.get("devoured_spells", {}).is_empty(), "his spell back")
	ok(item == "" or Campaign.count_of("enfina", item) == bag_before, "Enfina's %s back in her belt" % item)
	var prized := false
	for key in prizes_before:
		if Campaign.count_of("cyrus", key) > prizes_before[key]:
			prized = true
	ok(prized and heard("Out of the torn belly falls"), "and something an earlier victim carried falls out, for Cyrus")
	combat._bring_in_arrivals(true)
	ok(all_of("gnawer").size() == 2, "its belly broken: two Gnawers come", "%d" % all_of("gnawer").size())
	combat.drain_health(boss, cyrus, 10, 0.25)
	ok(combat.belly_open(boss) and int(boss.belly.most) == 10, "the next bite grows it again, from nothing")
	boss.hp = 1
	combat.lose_hp(boss, 5)
	combat.combatant_die(boss)
	ok(combat.get_effective_stat(cyrus, "max_hp") == most, "he falls: all of it comes back")
	game.queue_free()
	await settle()
	log_line("")


func feast():
	log_line("======== Feast ========")
	var game = await open_fresh()
	var boss := who("glutton")
	var cyrus := who("cyrus")
	for comb in combat.combatants:
		comb.reaction_used = true
	var most_hp: int = combat.get_effective_stat(boss, "max_hp")
	boss.hp = roundi(most_hp * 0.55)
	combat.lose_hp(boss, roundi(most_hp * 0.06))
	ok(boss.phase_name == "Famished" and boss.skill_list.has("feast") and boss.attack_sets.size() == 2, "below half: Feast, and a second set",
		boss.phase_name)
	var party: Array = combat.combatants.filter(func(comb): return comb.alive and comb.side == 0)
	var before := {}
	# The armour a party of 22 wears, the best each may (the level-17 tier; Prometheus has no cloth past his own): what the
	# designer asked the damage at (2026-11-27).
	var worn := {"cyrus": "hardened_leather", "alithia": "scale_coat", "prometheus": "basic_cloth_armour", "enfina": "plate_harness"}
	for member in party:
		var piece := EquipmentDefinition.named(worn.get(member.combatant_key, ""))
		if piece != null:
			member.stats["defense"] = piece.defense_at(member.level)
		member.max_hp = maxi(member.max_hp, 300)
		member.hp = member.max_hp
		before[member.id] = {"hp": member.hp, "most": combat.get_effective_stat(member, "max_hp"), "stat": combat.stat_of(member, member.main_stat),
			"first": combat.items_of(member)[0] if not combat.items_of(member).is_empty() else ""}
	var boss_before: int = boss.hp
	combat.current_combatant = combat.combatants.find(boss)
	combat.controller.set_controlled_combatant(boss)
	boss.skill_used_this_turn = false
	boss.secondary_used_this_turn = false
	await combat.use_skill("feast", boss, boss.position, false)
	await settle(4)
	var hit_all := true
	for member in party:
		var was: Dictionary = before[member.id]
		var lost: int = was.hp - member.hp
		log_line("    %s: %d damage (Defense %d), maximum health %d -> %d, %s %d -> %d, %s" % [member.name, lost,
			combat.stat_of(member, Stats.Type.DEFENSE), was.most, combat.get_effective_stat(member, "max_hp"), Stats.stat_name(member.main_stat),
			was.stat, combat.stat_of(member, member.main_stat), ("devoured: " + was.first) if was.first != "" else "nothing ready"])
		hit_all = hit_all and lost > 0 and combat.get_effective_stat(member, "max_hp") == was.most - 30 \
			and combat.stat_of(member, member.main_stat) == was.stat - 10
	ok(hit_all, "the whole party, wherever they stand: hurt, 30 maximum health and 10 of the main stat devoured")
	ok(boss.skill_used_this_turn and boss.secondary_used_this_turn, "his whole turn")
	ok(heard("Rotten Meal - and it does not sit well") and not boss.belly.inside.any(func(record): return record.get("key", "") == "rotten_meal"),
		"Cyrus's Rotten Meal eaten - not kept")
	log_line("    Erysichthon: %d -> %d (healed by what he drained, less the meal)" % [boss_before, boss.hp])
	# Four drains of 30 heal him 120; the Rotten Meal is poison, and he is weak to it: 25 lands as 31.
	ok(boss.hp == boss_before + 4 * 30 - 31, "the Rotten Meal's 25 poison lands on him as 31", "%d -> %d" % [boss_before, boss.hp])
	ok(combat.uses_left(boss, SkillDatabase.skills["feast"]) == 0, "once, at half")
	boss.hp = roundi(most_hp * 0.3)
	combat.lose_hp(boss, roundi(most_hp * 0.06))
	ok(boss.phase_name == "Insatiable" and combat.uses_left(boss, SkillDatabase.skills["feast"]) == -1, "under a quarter: every turn", boss.phase_name)
	var meal: ItemDefinition = ItemDatabase.item("rotten_meal")
	ok(meal != null and meal.devoured_like_eaten and not meal.description.contains("Erysichthon"), "the Rotten Meal says nothing of him")
	game.queue_free()
	await settle()
	log_line("")


func the_trees():
	log_line("======== Demeter's trees ========")
	var game = await open_fresh()
	var boss := who("glutton")
	for comb in combat.combatants:
		comb.reaction_used = true
	var tree: Dictionary = all_of("sacred_tree")[0]
	var spot := Vector2i(-99999, -99999)
	for y in range(tree.position.y - 6, tree.position.y + 3):
		for x in range(tree.position.x - 6, tree.position.x + 3):
			var anchor := Vector2i(x, y)
			if combat.room_for(boss, anchor) and combat.rect_gap(Rect2i(anchor, Vector2i(4, 4)), combat.rect_of(tree)) == 1:
				spot = anchor
	ok(spot.x != -99999, "room for him beside a tree", "%s" % spot)
	if spot.x == -99999:
		game.queue_free()
		await settle()
		return
	put(boss, spot)
	boss.hp = 200
	var tree_hp: int = tree.hp
	var claw: SkillDefinition = SkillDatabase.skills["claw"]
	ok(combat._ai_tree_in_reach(boss, claw).get("id", -1) == tree.id, "a tree in his Claw's reach")
	combat._ai_shooting_thing = tree.id
	await combat.use_skill("claw", boss, tree.position, false)
	combat._ai_shooting_thing = -1
	await settle()
	var eaten: int = tree_hp - tree.hp
	ok(eaten > 0 and boss.hp == 200 + eaten and heard("and eats it"), "a Claw at the tree: %d torn off and eaten" % eaten, "%d" % boss.hp)
	ok(combat.belly_open(boss) and int(boss.belly.most) == eaten, "into his belly")
	game.queue_free()
	await settle()
	log_line("")


func his_turn():
	log_line("======== his turn ========")
	var game = await open_fresh()
	var boss := who("glutton")
	var cyrus := who("cyrus")
	var enfina := who("enfina")
	for comb in combat.combatants:
		comb.reaction_used = true
		if comb.side == 0:
			comb.max_hp = maxi(comb.max_hp, 400)
			comb.hp = comb.max_hp
	put(cyrus, near(boss, cyrus, 2))
	combat.current_combatant = combat.combatants.find(boss)
	combat.controller.set_controlled_combatant(boss)
	boss.skill_used_this_turn = false
	boss.secondary_used_this_turn = false
	# Where he stands: no walk to somebody worth more, so whom he goes for is known.
	combat.controller.movement = 0
	said.clear()
	await combat.ai_attack_sets(boss)
	await settle(4)
	var claws := said.filter(func(line): return "Claw" in line and "Erysichthon" in line).size()
	var chomps := said.filter(func(line): return "Chomp" in line and "Erysichthon" in line).size()
	ok(claws >= 2 and chomps >= 1, "two Claws and a Chomp", "%d / %d" % [claws, chomps])
	# Below half: a second set, at somebody else, springing at them from up to 6 tiles.
	game.queue_free()
	await settle()
	game = await open_fresh()
	boss = who("glutton")
	cyrus = who("cyrus")
	enfina = who("enfina")
	for comb in combat.combatants:
		comb.reaction_used = true
		if comb.side == 0:
			comb.max_hp = maxi(comb.max_hp, 400)
			comb.hp = comb.max_hp
	var most_hp: int = combat.get_effective_stat(boss, "max_hp")
	boss.hp = roundi(most_hp * 0.55)
	combat.lose_hp(boss, roundi(most_hp * 0.06))
	boss["uses"] = {"feast": 1}
	put(cyrus, near(boss, cyrus, 2))
	put(enfina, near(boss, enfina, 5))
	var from: Vector2i = boss.position
	combat.current_combatant = combat.combatants.find(boss)
	combat.controller.set_controlled_combatant(boss)
	boss.skill_used_this_turn = false
	boss.secondary_used_this_turn = false
	var cyrus_hp: int = cyrus.hp
	combat.controller.movement = 0
	var enfina_hp: int = enfina.hp
	said.clear()
	await combat.ai_attack_sets(boss)
	await settle(4)
	ok(cyrus.hp < cyrus_hp and enfina.hp < enfina_hp, "a set at each of two", "%d -> %d, %d -> %d" % [cyrus_hp, cyrus.hp, enfina_hp, enfina.hp])
	ok(heard("lunges at") or boss.position == from, "springing at the far one when there is room", "%s -> %s" % [from, boss.position])
	ok(not boss.has("set_reach") or int(boss.set_reach) == 0, "and the long reach gone again with the turn")
	game.queue_free()
	await settle()
	log_line("")
