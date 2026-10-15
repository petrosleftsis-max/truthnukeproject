extends Node
## The twelve paths at work in a fight: each one's passives and skills doing
## what its description says - the step after a Rapier, two loads in one shot,
## a free bomb and a longer Steal, a swifter Prometheus with blades of each
## element, amplified spells, wards and overheal, holy weapons, stronger heals,
## images and confusion, a burning Enfina, a guarding one and a controlling one.

var LOG_PATH := HarnessLog.path_for("paths")
const WATCHER := "res://data/encounters/encounter_03_watcher.tres"

var _log: FileAccess = null
var _fail = 0
var game: Node = null
var combat = null


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
	get_tree().create_timer(400.0, true, false, true).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	var booted = get_tree().current_scene
	if booted != null:
		booted.queue_free()
		await settle()
	await cyrus_paths()
	await prometheus_paths()
	await alithia_paths()
	await enfina_paths()
	await all_fit()
	await close_fight()
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


## The watcher fight in the story, the party at `level` on the paths given.
func open_fight(paths: Dictionary, level: int = 20):
	await close_fight()
	Campaign.reset()
	Campaign.set_party(["cyrus", "enfina", "prometheus", "alithia"], level)
	for key in paths:
		Campaign.choose_subclass(key, paths[key])
	Campaign.current_map = "res://maps/crossroads_explore.tscn"
	Campaign.return_to_position = true
	Campaign.current_encounter = load(WATCHER)
	game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(6)
	combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(2)


func close_fight():
	if game != null and is_instance_valid(game):
		game.queue_free()
		await settle(3)
	game = null
	combat = null


func who(key: String) -> Dictionary:
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == key and not comb.get("illusion", false):
			return comb
	return {}


func enemies() -> Array:
	return combat.combatants.filter(func(c): return c.side == 1 and c.alive)


## Moves `comb` to `tile`.
func put(comb: Dictionary, tile: Vector2i):
	var from: Vector2i = comb.position
	comb.position = tile
	if comb.get("sprite") != null:
		comb.sprite.position = combat.controller.tile_map.map_to_local(tile)
	combat.controller.reposition_combatant(from, tile)


## A free tile `steps` straight to the right of `tile`, every tile on the way
## clear, or the first such going another way.
func free_beside(tile: Vector2i, steps: int = 1) -> Vector2i:
	for way in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var clear := true
		for step in range(1, steps + 1):
			var there: Vector2i = tile + way * step
			if not combat.controller.is_in_bounds(there) or not combat.get_combatant_at(there).is_empty() \
					or combat.controller.is_tile_blocking(there, 0):
				clear = false
		if clear:
			return tile + way * steps
	return Vector2i(-1, -1)


## Gives `comb` the turn, nothing in the way of acting.
func give_turn(comb: Dictionary):
	combat.current_combatant = combat.combatants.find(comb)
	combat.controller.set_controlled_combatant(comb)
	combat.controller.player_turn = comb.side == 0
	combat.controller.action_locked = false
	comb.skill_used_this_turn = false
	comb.secondary_used_this_turn = false
	comb.reaction_used = false


## Runs a skill without waiting on it, so a question it asks can be answered.
## Returns an array that becomes [true] once it is done.
func start_skill(key: String, caster: Dictionary, aim: Vector2i) -> Array:
	var done := [false]
	var run := func():
		await combat.use_skill(key, caster, aim, false)
		done[0] = true
	run.call()
	return done


## Waits until `check` holds, for up to `seconds` - by the clock rather than by
## frames, since an animation plays out over time however fast frames come.
func wait_for(check: Callable, seconds: float = 10.0) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		if check.call():
			return true
		await get_tree().process_frame
	return check.call()


func cyrus_paths():
	log_line("======== Swashbuckler: a step after the Rapier ========")
	await open_fight({"cyrus": "swashbuckler"})
	var cyrus := who("cyrus")
	var foe: Dictionary = enemies()[0]
	put(foe, free_beside(cyrus.position))
	give_turn(cyrus)
	var started_at: Vector2i = cyrus.position
	var done := start_skill("rapier", cyrus, foe.position)
	ok(await wait_for(func(): return combat.controller.is_stepping()), "after the strike, a step is offered")
	var marked: Array = combat.controller.pad_tiles()
	var away := Vector2i(-1, -1)
	for tile in marked:
		if combat.get_position_distance(tile, started_at) == 2:
			away = tile
	ok(away.x != -1 and marked.all(func(tile): return combat.get_position_distance(tile, started_at) <= 2),
		"up to two tiles away, marked for a pad too", "%d tiles" % marked.size())
	combat.controller.step_to(away)
	await wait_for(func(): return done[0])
	ok(cyrus.position == away, "chosen, he steps there", "%s" % cyrus.position)
	ok(not foe.get("reaction_used", false), "and nothing reacts to it")
	give_turn(cyrus)
	put(foe, free_beside(cyrus.position))
	var stood: Vector2i = cyrus.position
	done = start_skill("rapier", cyrus, foe.position)
	await wait_for(func(): return combat.controller.is_stepping())
	combat.controller.stay_put()
	await wait_for(func(): return done[0])
	ok(cyrus.position == stood, "or he can stay put")
	give_turn(cyrus)
	put(foe, free_beside(cyrus.position, 3))
	var shot_from: Vector2i = cyrus.position
	done = start_skill("gun", cyrus, foe.position)
	await wait_for(func(): return done[0])
	ok(not combat.controller.is_stepping() and done[0], "nothing is offered after anything but the Rapier",
		"stepping %s, done %s, from %s at %s" % [combat.controller.is_stepping(), done[0], shot_from, foe.position])

	log_line("")
	log_line("======== Gunner: two loads in one shot ========")
	await open_fight({"cyrus": "gunner"})
	cyrus = who("cyrus")
	ok(cyrus.skill_list.has("frost_round") and cyrus.skill_list.has("combined_load") and cyrus.skill_list.has("shock_round"),
		"new ammunition, and Combined Load")
	var ui = combat.game_ui
	var ammo: Array = ui.ammo_of(cyrus)
	ok(ammo.has("poison_dart") and ammo.has("frost_round") and ammo.has("burning_shot"), "his loads", "%s" % [ammo])
	var key := SkillDefinition.combined("burning_shot", "poison_dart")
	var both: SkillDefinition = SkillDatabase.skills.get(key)
	ok(both != null and both.name == "Burning Shot + Poison Dart", "two loads make one shot", key)
	foe = enemies()[0]
	put(foe, free_beside(cyrus.position, 3))
	give_turn(cyrus)
	foe.status_effects.clear()
	await combat.use_skill(key, cyrus, foe.position, false)
	await settle(3)
	var names: Array = combat.conditions_of(foe).map(func(c): return c.display_name)
	ok(names.has("Burn") or names.has("Burned") or names.has("Burning"), "burning", "%s" % [names])
	ok(foe.status_effects.any(func(e): return e.get("stat", "") == "dot" or (e.get("condition") != null and e.condition.display_name.to_lower().contains("pois"))),
		"and poisoned, from the one shot", "%s" % [foe.status_effects.map(func(e): return e.get("stat"))])
	ok(cyrus.skill_used_this_turn, "for the one action")
	give_turn(cyrus)
	ui.open_ammo_picker(cyrus, false)
	await settle(1)
	var load_button: Button = ui.ammo_picker.find_child("Load", true, false)
	ok(load_button.disabled, "the picker waits for two")
	(ui.ammo_picker.find_child("Ammo_frost_round", true, false) as Button).button_pressed = true
	(ui.ammo_picker.find_child("Ammo_poison_dart", true, false) as Button).button_pressed = true
	ok(not load_button.disabled, "two picked, they can be loaded")
	load_button.pressed.emit()
	await settle(1)
	ok(combat.controller.is_skill_selected() and SkillDatabase.skills[combat.controller._selected_skill].name == "Frost Round + Poison Dart",
		"and are aimed as one")
	combat.controller.cancel_skill_selection()

	log_line("")
	log_line("======== Bombardier: a free bomb, a longer Steal ========")
	await open_fight({"cyrus": "bombardier"})
	cyrus = who("cyrus")
	Campaign.set_inventory("cyrus", [])
	ok(combat.items_of(cyrus) == ["small_bomb"], "an empty bag, and still a bomb to hand", "%s" % [combat.items_of(cyrus)])
	var steal: SkillDefinition = SkillDatabase.skills.steal
	ok(combat.effective_max_range(cyrus, steal) == steal.max_range + 3, "Steal reaches three tiles further",
		"%d" % combat.effective_max_range(cyrus, steal))
	foe = enemies()[0]
	put(foe, free_beside(cyrus.position, 3))
	give_turn(cyrus)
	await combat.use_skill("small_bomb", cyrus, foe.position, false)
	await settle(3)
	ok(not combat.items_of(cyrus).has("small_bomb") and Campaign.count_of("cyrus", "small_bomb") == 0, "thrown, it is gone for this fight")
	log_line("")


func prometheus_paths():
	log_line("======== Spellsword: swift, with blades of each element ========")
	await open_fight({"prometheus": "spellsword"})
	var prometheus := who("prometheus")
	ok(combat.get_effective_stat(prometheus, "movement") == 6, "six tiles of movement", "%d" % combat.get_effective_stat(prometheus, "movement"))
	ok(["flame_edge", "frost_edge", "storm_edge", "stone_edge"].all(func(key): return prometheus.skill_list.has(key)), "four blades")
	ok(combat.secondary_skills_of(prometheus).has("slip_past") and combat.main_skills_of(prometheus).has("slip_past"),
		"and Slip Past as a secondary action as well as a main one")
	var foe: Dictionary = enemies()[0]
	put(foe, free_beside(prometheus.position))
	foe.status_effects.clear()
	give_turn(prometheus)
	await combat.use_skill("flame_edge", prometheus, foe.position, false)
	await settle(3)
	ok(not combat.conditions_of(foe).is_empty(), "Flame Edge leaves them burning")

	log_line("")
	log_line("======== Demolitionist: amplified spells ========")
	await open_fight({"prometheus": "demolitionist"})
	prometheus = who("prometheus")
	foe = enemies()[0]
	put(foe, free_beside(prometheus.position, 3))
	var blast: SkillDefinition = SkillDatabase.skills.fire_blast
	ok(combat.free_amplifies(prometheus) == 3, "three free amplifications at level 20")
	var plain: int = combat.predict_hit(prometheus, foe, blast).damage
	prometheus["amplify"] = 1
	var stronger: int = combat.predict_hit(prometheus, foe, blast).damage
	ok(stronger > plain, "amplified, the prompt promises more", "%d -> %d" % [plain, stronger])
	var gates_before: Array = prometheus.spell_slots.duplicate()
	give_turn(prometheus)
	var hp_before: int = foe.hp
	await combat.use_skill("fire_blast", prometheus, foe.position, false)
	await settle(3)
	ok(prometheus.get("free_amplifies_used", 0) == 1 and prometheus.spell_slots[1] == gates_before[1] - 1 and prometheus.spell_slots[2] == gates_before[2],
		"a free one spends only the spell's own gate", "%s" % [prometheus.spell_slots])
	ok(hp_before - foe.hp >= stronger - 1, "and hits as promised", "%d" % (hp_before - foe.hp))
	ok(prometheus.get("amplify", 0) == 0, "an amplification is for one spell")
	prometheus["free_amplifies_used"] = 3
	prometheus["amplify"] = 1
	gates_before = prometheus.spell_slots.duplicate()
	give_turn(prometheus)
	await combat.use_skill("fire_blast", prometheus, foe.position, false)
	await settle(3)
	ok(prometheus.spell_slots[2] == gates_before[2] - 1 and prometheus.spell_slots[1] == gates_before[1],
		"with none free left, it spends the gate deeper instead", "%s" % [prometheus.spell_slots])

	log_line("")
	log_line("======== Abjurer: a ward, and overheal ========")
	await open_fight({"prometheus": "abjurer"})
	prometheus = who("prometheus")
	var alithia := who("alithia")
	foe = enemies()[0]
	put(alithia, free_beside(prometheus.position))
	put(foe, free_beside(alithia.position))
	var swing: SkillDefinition = SkillDatabase.skills.rapier
	var full_hit: int = combat.resisted_damage(alithia, Damage.Type.PHYSICAL, combat.skill_damage(foe, alithia, swing))
	var warded_hit: int = combat.resisted_damage(alithia, Damage.Type.PHYSICAL, combat.skill_damage(foe, alithia, swing, 0.6))
	give_turn(foe)
	prometheus.reaction_used = false
	hp_before = alithia.hp
	var done := start_skill("rapier", foe, alithia.position)
	ok(await wait_for(func(): return combat.reaction_prompt.is_asking()), "an enemy swinging at Alithia, Prometheus is asked to ward her")
	combat.reaction_prompt._answer_with(true)
	await wait_for(func(): return done[0])
	ok(hp_before - alithia.hp == warded_hit and warded_hit < full_hit, "and four tenths come off it", "%d, not %d" % [hp_before - alithia.hp, full_hit])
	ok(prometheus.reaction_used, "for his reaction")
	give_turn(prometheus)
	alithia["temp_hp"] = 0
	var quicken_key := "quicken" if prometheus.skill_list.has("quicken") else "hover"
	await combat.use_skill(quicken_key, prometheus, alithia.position, false)
	await settle(3)
	ok(alithia.get("temp_hp", 0) > 0, "a spell of his on her leaves her overhealed", "%d" % alithia.get("temp_hp", 0))
	var shield: int = alithia.temp_hp
	hp_before = alithia.hp
	combat.lose_hp(alithia, shield + 3)
	ok(alithia.temp_hp == 0 and alithia.hp == hp_before - 3, "which is taken before her health")
	log_line("")


func alithia_paths():
	log_line("======== Punisher: holy weapons ========")
	await open_fight({"alithia": "punisher"})
	var alithia := who("alithia")
	ok(["holy_spear", "censure", "judgement_hammer"].all(func(key): return alithia.skill_list.has(key)), "three holy weapons")
	var spear: SkillDefinition = SkillDatabase.skills.holy_spear
	ok(spear.damage_type == Damage.Type.IDOL and spear.aoe_shape == SkillDefinition.AoEShape.LINE, "Holy Spear is Idol, down a line")
	ok(SkillDatabase.skills.censure.aoe_shape == SkillDefinition.AoEShape.CONE, "Censure, a cone")

	log_line("")
	log_line("======== Carer: stronger heals, a share back, a spur ========")
	await open_fight({"alithia": "carer"})
	alithia = who("alithia")
	var cyrus := who("cyrus")
	var heal: SkillDefinition = SkillDatabase.skills.heal
	var mended: int = combat.heal_amount(alithia, heal)
	var plain_mended := roundi(combat.power_behind(alithia, heal) * combat.heal_strength(heal, null))
	ok(mended == roundi(plain_mended * 1.25), "her heals mend a quarter more", "%d, not %d" % [mended, plain_mended])
	cyrus.hp = 10
	alithia.hp = 10
	put(cyrus, free_beside(alithia.position))
	give_turn(alithia)
	await combat.use_skill("heal", alithia, cyrus.position, false)
	await settle(3)
	ok(alithia.hp == 10 + roundi(mended * 0.25), "and a quarter of it comes back to her", "%d" % alithia.hp)
	ok(cyrus.status_effects.any(func(e): return e.get("stat", "") == "movement" and e.get("amount", 0) == 2),
		"and he is spurred on, two tiles", "%s" % [cyrus.status_effects])

	log_line("")
	log_line("======== Illusionist: images and confusion ========")
	await open_fight({"alithia": "illusionist"})
	alithia = who("alithia")
	cyrus = who("cyrus")
	put(cyrus, free_beside(alithia.position))
	give_turn(alithia)
	var count_before: int = combat.combatants.size()
	await combat.use_skill("mirror_image", alithia, cyrus.position, false)
	await settle(3)
	var image: Dictionary = combat.combatants.back() if combat.combatants.size() > count_before else {}
	ok(image.get("illusion", false) and image.name == "Cyrus (image)" and image.hp == 1 and image.side == 0,
		"an image of Cyrus beside him", "%s" % image.get("name", "none"))
	ok(maxi(absi(image.position.x - cyrus.position.x), absi(image.position.y - cyrus.position.y)) == 1, "right beside him",
		"%s, he is on %s" % [image.position, cyrus.position])
	ok(combat.side_standing(0), "the party is standing")
	var foe: Dictionary = enemies()[0]
	put(foe, free_beside(image.position))
	give_turn(foe)
	await combat.use_skill("rapier", foe, image.position, false)
	await settle(3)
	ok(not image.alive and image.get("sprite") == null, "one hit and it shatters, leaving nothing")
	ok(not combat.anyone_fallen(0),
		"an image is nobody to bring back")
	give_turn(alithia)
	await combat.use_skill("mirror_image", alithia, cyrus.position, false)
	await settle(2)
	image = combat.combatants.back()
	for comb in combat.combatants:
		if comb.side == 0 and comb.alive and not comb.get("illusion", false):
			comb.hp = 0
			combat.combatant_die(comb)
	await settle(2)
	ok(not image.alive and combat.combat_over, "the party down, their images go with them and the fight is over")

	log_line("")
	log_line("======== confused ========")
	await open_fight({"alithia": "illusionist"})
	alithia = who("alithia")
	var foes := enemies()
	var victim: Dictionary = foes[0]
	var confused: Dictionary = foes[1]
	put(confused, free_beside(victim.position))
	victim.hp = 999
	var hp_was: int = victim.hp
	var condition: ConditionDefinition = load("res://data/conditions/confused.tres")
	var bewilder := EffectDefinition.new()
	bewilder.type = EffectDefinition.EffectType.CONDITION
	bewilder.condition = condition
	combat.apply_effect(alithia, confused, bewilder, null, false)
	ok(combat.has_restriction(confused, "confuses"), "confused")
	give_turn(confused)
	await combat.ai_confused(confused)
	await settle(4)
	ok(victim.hp < hp_was, "it goes for whoever is nearest - its own side", "%d -> %d" % [hp_was, victim.hp])
	log_line("")


func enfina_paths():
	log_line("======== Berserker: burning, she burns ========")
	await open_fight({"enfina": "berserker"})
	var enfina := who("enfina")
	var foe: Dictionary = enemies()[0]
	put(foe, free_beside(enfina.position))
	var sword: SkillDefinition = SkillDatabase.skills.greatsword_attack
	var cool: int = combat.skill_damage(enfina, foe, sword)
	give_turn(enfina)
	await combat.use_skill("trailblaze", enfina, enfina.position, false, true)
	await settle(3)
	var hot: int = combat.skill_damage(enfina, foe, sword)
	ok(hot == Stats.final_damage(combat.power_behind(enfina, sword), sword.ability_modifier * 1.3, combat.stat_of(foe, Stats.Type.DEFENSE)) and hot > cool,
		"burning, she hits three tenths harder", "%d -> %d" % [cool, hot])
	foe.status_effects.clear()
	enfina.skill_used_this_turn = false
	await combat.use_skill("greatsword_attack", enfina, foe.position, false)
	await settle(3)
	ok(not combat.conditions_of(foe).is_empty(), "and sets them burning too")

	log_line("")
	log_line("======== Guardian: she takes half ========")
	await open_fight({"enfina": "guardian"})
	enfina = who("enfina")
	var cyrus := who("cyrus")
	ok(combat.stat_of(enfina, Stats.Type.DEFENSE) == enfina.stats.defense + 8, "eight better armour")
	put(cyrus, free_beside(enfina.position, 2))
	foe = enemies()[0]
	put(foe, free_beside(cyrus.position))
	var enfina_hp: int = enfina.hp
	var cyrus_hp: int = cyrus.hp
	var whole: int = combat.resisted_damage(cyrus, Damage.Type.PHYSICAL, combat.skill_damage(foe, cyrus, SkillDatabase.skills.rapier))
	give_turn(foe)
	await combat.use_skill("rapier", foe, cyrus.position, false)
	await settle(3)
	ok(enfina_hp - enfina.hp == roundi(whole * 0.5) and cyrus_hp - cyrus.hp == whole - roundi(whole * 0.5),
		"a hit on Cyrus two tiles from her, half of it is hers", "%d / %d of %d" % [enfina_hp - enfina.hp, cyrus_hp - cyrus.hp, whole])
	ok(enfina.skill_list.has("daunting_roar") and enfina.skill_list.has("shield_bash"), "and moves that frighten")

	log_line("")
	log_line("======== Controller: brought close, kept there ========")
	await open_fight({"enfina": "controller"})
	enfina = who("enfina")
	foe = enemies()[0]
	var far := free_beside(enfina.position, 4)
	put(foe, far)
	give_turn(enfina)
	await combat.use_skill("chain_hook", enfina, foe.position, false)
	await settle(3)
	ok(combat.get_position_distance(foe.position, enfina.position) < 4, "Chain Hook drags them to her",
		"%d tiles" % combat.get_position_distance(foe.position, enfina.position))
	give_turn(enfina)
	put(foe, free_beside(enfina.position))
	await combat.use_skill("pin_down", enfina, foe.position, false)
	await settle(3)
	ok(combat.get_effective_stat(foe, "movement") == 0, "Pin Down leaves them no movement")
	log_line("")




## Every character on every path at level 20: the action panel offers every one
## of their main and secondary skills. The grid has twelve buttons; a kit with
## more goes on a shelf that scrolls (CombatUI._show_skills_for), rather than
## the grid showing twelve and dropping the rest without a word.
func all_fit():
	log_line("======== every kit has a button for everything ========")
	await open_fight({})
	var ui = combat.game_ui
	var buttons: int = ui.get_node("Actions/ActionsPanel/ActionsGrid").get_child_count()
	ui.showing_spells = false
	for key in ["cyrus", "enfina", "prometheus", "alithia"]:
		var definition: CombatantDefinition = CombatantDatabase.combatants[key]
		for path in definition.subclasses:
			var comb: Dictionary = combat.create_combatant(definition, key, "", null, Stats.MAX_LEVEL, path)
			comb["side"] = 0
			for panel in [ui.SkillPanel.MAIN, ui.SkillPanel.SECONDARY]:
				var wanted: Array = combat.main_skills_of(comb) if panel == ui.SkillPanel.MAIN else combat.secondary_skills_of(comb)
				ui.showing_panel = panel
				ui._show_skills_for(comb)
				var offered: Array = ui.action_buttons().filter(func(b): return b.tooltip_text != "").map(func(b): return b.get_meta(ui.SKILL_META, ""))
				var missing: Array = wanted.filter(func(skill): return not offered.has(skill))
				ok(missing.is_empty(), "%s the %s, %s" % [key.capitalize(), path.capitalize(), "main" if panel == ui.SkillPanel.MAIN else "secondary"],
					"%d skills%s%s" % [wanted.size(), " on a shelf that scrolls" if wanted.size() > buttons and ui.showing_shelves() else "",
						", missing %s" % [missing] if not missing.is_empty() else ""])
	ui.showing_panel = ui.SkillPanel.MAIN
	log_line("")
