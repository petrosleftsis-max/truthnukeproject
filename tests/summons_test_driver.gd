extends Node
## Summons and tethers (Combat "Summons", "Tethers"): Prometheus's
## Kindled Hound held on a tether - the bar, what frays it and what goes when
## it breaks - and commanded on his turn, on guard when it is not, fending for
## itself when his turn is lost, gone when he is; his Illusory Dragon, which
## nothing touches; the Summoner, who keeps safe and sends its Bound Beast in;
## and every spell of a creature worked out from its one spellcasting stat.

var LOG_PATH := HarnessLog.path_for("summons")
const DEN := "res://data/encounters/summoner_den.tres"

var _log: FileAccess
var _fail = 0
var game: Node = null
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
	get_tree().create_timer(280.0, true, false, true).timeout.connect(func():
		log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await tether_and_command()
	await the_dragon()
	await the_summoner()
	await spellcasting_stat()
	await mist_step()
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


func open_fight():
	if game != null and is_instance_valid(game):
		game.queue_free()
		await settle(3)
	Campaign.reset()
	Campaign.current_encounter = load(DEN)
	game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(8)
	combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(2)
	combat.reaction_prompt = null
	said.clear()
	combat.update_information.connect(func(line): said.append(line))
	for comb in combat.combatants:
		comb.max_hp = maxi(comb.max_hp, 400)
		comb.hp = comb.max_hp


func heard(words: String) -> bool:
	return said.any(func(line): return words in line)


func who(key: String) -> Dictionary:
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == key and comb.alive:
			return comb
	return {}


func put(comb: Dictionary, tile: Vector2i):
	var from: Vector2i = comb.position
	comb.position = tile
	combat.controller.reposition_combatant(from, tile)
	var sprite = comb.get("sprite")
	if sprite != null and is_instance_valid(sprite):
		sprite.position = combat.sprite_point(comb)


func give_turn(comb: Dictionary):
	combat.current_combatant = combat.combatants.find(comb)
	combat.controller.set_controlled_combatant(comb)
	combat.controller.player_turn = comb.side == 0
	combat.controller.action_locked = false
	comb.skill_used_this_turn = false
	comb.secondary_used_this_turn = false
	comb.reaction_used = false


## A free tile `steps` along from `tile`, every tile on the way clear.
func free_beside(tile: Vector2i, steps: int = 1) -> Vector2i:
	for way in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var clear := true
		for step in range(1, steps + 1):
			var there: Vector2i = tile + way * step
			if not combat.controller.is_on_map(there) or not combat.get_combatant_at(there).is_empty() \
					or combat.controller.is_tile_blocking(there, 0):
				clear = false
		if clear:
			return tile + way * steps
	return Vector2i(-99999, -99999)


func tether_and_command():
	log_line("======== Kindled Hound, held on a tether ========")
	await open_fight()
	var prometheus := who("prometheus")
	var hound_spell: SkillDefinition = SkillDatabase.skills["kindled_hound"]
	ok(prometheus.skill_list.has("kindled_hound") and hound_spell.tethered and Combat.summons_with(hound_spell) == "kindled_hound",
		"Prometheus has Kindled Hound, held on a tether")
	give_turn(prometheus)
	var spot := free_beside(prometheus.position, 2)
	await combat.use_skill("kindled_hound", prometheus, spot, false)
	await settle(2)
	var hound := who("kindled_hound")
	ok(not hound.is_empty() and hound.position == spot and hound.side == 0 and hound.summoner == prometheus.id,
		"a hound of his, where he called it", "%s" % hound.get("position", "none"))
	ok(not combat.turn_queue.has(combat.combatants.find(hound)), "with no turn of its own")
	# On the HUD: small, beside him - not a portrait of its own in the party column.
	var ui = combat.game_ui
	combat.update_combatants.emit(combat.combatants)
	await settle(2)
	var his_status = ui._icon_for(ui.get_node("Status"), prometheus)
	ok(ui._icon_for(ui.get_node("Status"), hound) == null and his_status != null
		and his_status.get_node_or_null("Summons/Summon%d" % hound.id) != null,
		"on the HUD a small portrait beside his, not one of the party's")
	var faces: Array = ui._queue_faces_for(prometheus)
	ok(not faces.is_empty() and faces[0].get_node_or_null("Summons/Summon%d" % hound.id) != null,
		"and in the corner of his face in the turn queue")
	ok(Combat.holds_tether(prometheus) and is_equal_approx(prometheus.tether.bar, 100.0), "his tether holds it: a full bar")
	ok(hound.get("tether_of", -1) == prometheus.tether.id, "and the hound is the tether's")
	ok(combat.secondary_skills_of(prometheus).has("command"), "Command on his secondary panel, with a summon standing")
	var most: int = combat.get_effective_stat(prometheus, "max_hp")
	combat.lose_hp(prometheus, most / 4)
	var after_hit: float = prometheus.tether.bar
	ok(absf(after_hit - (100.0 - 25.0 * hound_spell.tether_per_damage)) < 1.5, "a quarter of his health lost: a quarter of the bar, times its weight",
		"%.1f" % after_hit)
	combat._tether_turn(prometheus)
	ok(absf(prometheus.tether.bar - (after_hit - hound_spell.tether_per_turn)) < 0.01, "a turn of his: Tether Per Turn more",
		"%.1f" % prometheus.tether.bar)
	log_line("")

	log_line("======== Command, and on guard ========")
	ok(combat.refusal_for(prometheus, SkillDatabase.skills["command"], who("enfina").position) != "", "nobody but his own summon can be commanded")
	combat.controller.movement = 3
	await combat.use_skill("command", prometheus, hound.position, false, true)
	await settle(2)
	ok(combat.get_current_combatant() == hound and combat.controller.player_turn and prometheus.secondary_used_this_turn,
		"commanded, the hound has the turn - his secondary spent", "%s" % combat.get_current_combatant().get("name"))
	ok(not hound.skill_used_this_turn and combat.controller.movement == combat.get_effective_stat(hound, "movement"),
		"with its own move and action")
	await combat.advance_turn()
	await settle(2)
	ok(combat.get_current_combatant() == prometheus and combat.controller.movement == 3, "its moment over, back to him, with what he had left",
		"%d" % combat.controller.movement)
	ok(combat.refusal_for(prometheus, SkillDatabase.skills["command"], hound.position) != "", "once a turn")
	hound.erase("commanded")
	combat._summons_turn_ends(prometheus)
	ok(hound.status_effects.any(func(e): return e.get("stat", "") == "defense" and e.get("op", "") == "multiply"),
		"not commanded, it stands on guard as his turn ends")
	log_line("")

	log_line("======== his turn lost ========")
	hound.status_effects.clear()
	var foe := who("hired_bow")
	var near := free_beside(prometheus.position, 1)
	put(foe, near)
	var before: int = combat.get_position_distance(hound.position, prometheus.position)
	await combat._summons_fend(prometheus)
	await settle(2)
	ok(combat.get_current_combatant() == prometheus, "it fends for itself, and the turn is his again after")
	ok(combat.get_position_distance(hound.position, prometheus.position) <= maxi(before, 2) or foe.hp < foe.max_hp,
		"somebody close to him: it stands by him, or strikes", "%d -> %d" % [before, combat.get_position_distance(hound.position, prometheus.position)])
	put(foe, Vector2i(56, -8))
	var far_before: int = combat._distance_to_nearest_foe(hound, hound.position)
	hound.erase("commanded")
	await combat._summons_fend(prometheus)
	await settle(2)
	ok(combat._distance_to_nearest_foe(hound, hound.position) >= far_before, "nobody near him: it keeps itself safe",
		"%d -> %d" % [far_before, combat._distance_to_nearest_foe(hound, hound.position)])
	log_line("")

	log_line("======== what a tether held, let go ========")
	var growth: SkillDefinition = SkillDatabase.skills["growth"].duplicate()
	growth.tethered = true
	SkillDatabase.skills["tethered_growth"] = growth
	var enfina := who("enfina")
	var room := open_block(4, 4)
	put(prometheus, room)
	put(enfina, room + Vector2i(1, 1))
	give_turn(prometheus)
	await combat.use_skill("tethered_growth", prometheus, enfina.position, false)
	await settle(2)
	ok(enfina.size == Sizes.Size.LARGE and enfina.status_effects.any(func(e): return e.has("tether_of")),
		"a spell on a tether: what it put on her is the tether's", "%d" % enfina.size)
	ok(not hound.alive and heard("turns to"), "another spell tethered, the first lets go - the hound with it")
	combat.fray_tether(prometheus, 999.0, "test")
	ok(not Combat.holds_tether(prometheus) and enfina.size == Sizes.Size.HUMAN and not enfina.status_effects.any(func(e): return e.has("tether_of")),
		"the tether snapped: it all comes off her", "%d" % enfina.size)
	SkillDatabase.skills.erase("tethered_growth")
	log_line("")

	log_line("======== gone with him ========")
	give_turn(prometheus)
	prometheus.spell_slots = Stats.gates_for_level(22)
	await combat.use_skill("kindled_hound", prometheus, free_beside(prometheus.position, 2), false)
	await settle(2)
	hound = who("kindled_hound")
	ok(not hound.is_empty(), "another hound")
	prometheus.hp = 0
	combat.combatant_die(prometheus)
	await settle(2)
	ok(not hound.alive and hound.get("taken", "") == "unsummoned" and hound.get("sprite") == null,
		"he falls: it goes with him, and leaves nothing")
	log_line("")


func the_dragon():
	log_line("======== Illusory Dragon ========")
	await open_fight()
	var prometheus := who("prometheus")
	var spell: SkillDefinition = SkillDatabase.skills["illusory_dragon"]
	ok(spell.spell_slot_level == 8 and spell.required_level == 47 and spell.tethered, "a spell of the Ogdoad, from level 47, held on a tether")
	prometheus.level = 47
	prometheus.spell_slots = Stats.gates_for_level(47)
	var foe := who("hired_bow")
	var block := open_block(9, 3)
	ok(block.x != -99999, "open ground for it", "%s" % block)
	if block.x == -99999:
		return
	put(prometheus, block + Vector2i(8, 2))
	put(foe, block + Vector2i(4, 0))
	# Two within its presence: a weak mind, and one a match for his.
	var steady := who("bound_beast")
	put(steady, block + Vector2i(4, 1))
	foe.stats[Stats.stat_key(Stats.Type.MINDFULNESS)] = 1
	steady.stats[Stats.stat_key(Stats.Type.MINDFULNESS)] = 999
	give_turn(prometheus)
	await combat.use_skill("illusory_dragon", prometheus, block, false)
	await settle(2)
	var dragon := who("illusory_dragon")
	ok(not dragon.is_empty() and dragon.get("untouchable", false) and dragon.size == Sizes.Size.LARGE and dragon.summoner == prometheus.id \
		and dragon.position == block, "a Large dragon of his where he called it, untouchable", "%s" % dragon.get("position", "none"))
	ok(dragon.stats.hash() == prometheus.stats.hash(), "as strong as his mind: his attributes")
	ok(combat.conditions_of(foe).any(func(c): return c.display_name == "Fear"), "the archer, weaker of mind than his Intellect, gripped by fear as it appears")
	ok(not combat.conditions_of(steady).any(func(c): return c.display_name == "Fear") and heard("stands firm"),
		"one whose Mindfulness beats his Intellect stands firm")
	var sharper := EffectDefinition.new()
	sharper.type = EffectDefinition.EffectType.STAT_MODIFIER
	sharper.stat = Stats.stat_key(Stats.Type.INTELLECT)
	sharper.modifier_amount = 20
	combat.apply_effect(prometheus, prometheus, sharper, null, false)
	ok(combat.stat_of(dragon, Stats.Type.INTELLECT) == combat.stat_of(prometheus, Stats.Type.INTELLECT),
		"and its mind is his as he is now - his Intellect raised, so is its", "%d" % combat.stat_of(dragon, Stats.Type.INTELLECT))
	ok(combat.hit_chance(foe, SkillDatabase.skills["nail_projectile"], dragon) == 0, "every attack on it misses")
	var hp_was: int = dragon.hp
	combat.lose_hp(dragon, 50)
	ok(dragon.hp == hp_was, "and nothing hurts it")
	ok(combat.ai_target_value(foe, dragon, SkillDatabase.skills["nail_projectile"]) == 0.0, "the other side does not bother with it")
	var before: int = foe.hp
	give_turn(dragon)
	await combat.use_skill("fire_breath", dragon, foe.position, false)
	await settle(2)
	ok(foe.hp < before, "its breath burns whoever is in the cone", "%d -> %d" % [before, foe.hp])
	combat.fray_tether(prometheus, 999.0, "test")
	ok(not dragon.alive, "his tether snapped, it is gone")
	log_line("")


## The top-left of a `w` x `h` block of open ground with nobody on it.
func open_block(w: int, h: int) -> Vector2i:
	var region: Rect2i = combat.controller._astargrid.region
	for y in range(region.position.y, region.end.y - h + 1):
		for x in range(region.position.x, region.end.x - w + 1):
			var free := true
			for dy in h:
				for dx in w:
					var t := Vector2i(x + dx, y + dy)
					if not combat.controller.is_on_map(t) or combat.controller.is_tile_blocking(t, 0) or not combat.get_combatant_at(t).is_empty():
						free = false
			if free:
				return Vector2i(x, y)
	return Vector2i(-99999, -99999)


func the_summoner():
	log_line("======== the Summoner ========")
	await open_fight()
	var summoner := who("summoner")
	var beast := who("bound_beast")
	ok(not summoner.is_empty() and not beast.is_empty() and beast.summoner == summoner.id, "the Summoner, its Bound Beast beside it from the start")
	ok(not combat.turn_queue.has(combat.combatants.find(beast)), "the beast with no turn of its own")
	var sorcerer: Dictionary = combat.create_combatant(CombatantDatabase.combatants.sorcerer, "sorcerer", "", null, 22)
	var mine: Dictionary = combat.create_combatant(CombatantDatabase.combatants.summoner, "summoner", "", null, 22)
	ok(mine.max_hp < sorcerer.max_hp, "frailer than a sorcerer", "%d < %d" % [mine.max_hp, sorcerer.max_hp])
	var barbarian: Dictionary = combat.create_combatant(CombatantDatabase.combatants.barbarian, "barbarian", "", null, 22)
	var target := who("enfina")
	var bite: SkillDefinition = SkillDatabase.skills["savage_bite"]
	var sword: SkillDefinition = SkillDatabase.skills["greatsword_attack"]
	var plain: int = combat.skill_damage(beast, target, bite)
	var axe: int = combat.skill_damage(barbarian, target, sword)
	give_turn(summoner)
	await combat.use_skill("empower_the_bound", summoner, beast.position, false)
	var empowered: int = combat.skill_damage(beast, target, bite)
	ok(empowered > axe, "empowered, the beast hits harder than a barbarian", "%d (plain %d) against %d" % [empowered, plain, axe])
	beast.status_effects.clear()
	beast.hp = int(beast.max_hp * 0.4)
	var party_near: int = combat._distance_to_nearest_foe(summoner, summoner.position)
	said.clear()
	give_turn(summoner)
	combat.controller.movement = combat.get_effective_stat(summoner, "movement")
	await combat.ai_summoner(summoner)
	await settle(4)
	ok(beast.hp > int(beast.max_hp * 0.4) or not beast.alive, "its beast hurt, it mends it", "%d" % beast.hp)
	ok(heard("commands [color=lightgreen]Bound Beast"), "and sends it in", "%s" % [said.slice(0, 6)])
	ok(not summoner.alive or combat._distance_to_nearest_foe(summoner, summoner.position) >= mini(party_near, 4),
		"keeping itself back", "%d -> %d" % [party_near, combat._distance_to_nearest_foe(summoner, summoner.position)])
	if summoner.alive and beast.alive:
		combat.combatant_die(summoner)
		await settle(2)
		ok(not beast.alive and beast.get("taken", "") == "unsummoned", "the Summoner down, its beast goes with it")
	log_line("")
	game.queue_free()
	await settle(3)


func spellcasting_stat():
	log_line("======== every spell, one stat ========")
	await open_fight()
	var prometheus := who("prometheus")
	var alithia := who("alithia")
	var quicken: SkillDefinition = SkillDatabase.skills["quicken"]
	var fireball: SkillDefinition = SkillDatabase.skills["fireball"]
	var dart: SkillDefinition = SkillDatabase.skills["zephyr_dart"]
	ok(prometheus.spellcasting_stat == Stats.Type.INTELLECT and alithia.spellcasting_stat == Stats.Type.MINDFULNESS,
		"Prometheus casts with his Intellect, Alithia with her Mindfulness")
	ok(combat.scaling_stat_of(prometheus, quicken) == Stats.Type.INTELLECT and combat.scaling_stat_of(alithia, SkillDatabase.skills["heal"]) == Stats.Type.MINDFULNESS,
		"every spell of theirs on it, whatever stat the spell itself was written with")
	ok(dart.spell_slot_level > 0 or combat.scaling_stat_of(prometheus, dart) == dart.scaling_stat, "a skill that costs no gate keeps its own")
	prometheus.spellcasting_stat = Stats.Type.SELF
	prometheus.stats[Stats.stat_key(Stats.Type.SELF)] = 77
	var worth: float = combat.power_behind(prometheus, fireball)
	ok(is_equal_approx(worth, Stats.base_damage(combat.stat_of(prometheus, Stats.Type.SELF), prometheus.get("weapon_base", Stats.WEAPON_BASE))),
		"his spellcasting stat changed to Self: his Fireball is worked out from Self", "%.1f" % worth)
	log_line("")
	game.queue_free()
	await settle(3)


func mist_step():
	log_line("======== Mist Step ========")
	await open_fight()
	var prometheus := who("prometheus")
	var step: SkillDefinition = SkillDatabase.skills["mist_step"]
	ok(prometheus.skill_list.has("mist_step") and step.is_secondary and step.teleports == SkillDefinition.TeleportWho.CASTER \
		and not step.respects_blocking and step.max_range == 6, "Prometheus's Mist Step: a secondary teleport, six tiles, past any cover")
	prometheus.level = 22
	prometheus.spell_slots = Stats.gates_for_level(22)
	give_turn(prometheus)
	var hidden_spot := Vector2i(-99999, -99999)
	for tile in combat.get_range_tiles(step, prometheus.position, 0, prometheus):
		if combat.can_land_on(prometheus, tile) and not combat.has_line_of_sight(prometheus.position, tile, 0):
			hidden_spot = tile
			break
	ok(hidden_spot.x != -99999, "somewhere in reach he cannot see", "%s" % hidden_spot)
	if hidden_spot.x != -99999:
		await combat.use_skill("mist_step", prometheus, hidden_spot, false, true)
		await settle(2)
		ok(prometheus.position == hidden_spot, "and he is there, wall or no wall", "%s" % prometheus.position)
		ok(prometheus.secondary_used_this_turn and not prometheus.skill_used_this_turn, "on his secondary action - the main one still his")
	log_line("")
	game.queue_free()
	await settle(3)
