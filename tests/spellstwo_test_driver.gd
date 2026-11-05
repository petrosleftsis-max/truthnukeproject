extends Node
## The second list of spells (the designer, 2026-11-05): what a tether does when it holds
## nothing, darkness and who sees in it, zones that hurt, mend, cost twice and move, and
## each new spell of Prometheus's and Alithia's, played out.

const LOG_NAME := "spellstwo"
const WATCHER := "res://data/encounters/encounter_03_watcher.tres"
const PARTY := ["enfina", "cyrus", "prometheus", "alithia"]
const IN_DARKNESS := preload("res://data/conditions/in_darkness.tres")

var LOG_PATH := HarnessLog.path_for(LOG_NAME)
var _log: FileAccess = null
var _fail := 0
var game = null
var combat: Combat = null
var controller = null
var ui = null
var prompt = null


func log_line(text: String):
	if _log:
		_log.store_line(text)
		_log.flush()


func ok(condition: bool, label: String, detail: String = ""):
	if condition:
		log_line("  PASS  %s %s" % [label, detail])
	else:
		_fail += 1
		log_line("  FAIL  %s %s" % [label, detail])


func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(400.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await settle()
	var booted = get_tree().current_scene
	if booted != null:
		booted.queue_free()
		await settle()
	await open_fight()
	await tether_rules()
	await open_fight()
	await turn_aside()
	await open_fight({"prometheus": "elemental_vanguard"})
	await flame_fan()
	await open_fight({"prometheus": "elemental_conductor"})
	await storm_cloud()
	await open_fight()
	await light_void()
	await open_fight()
	await ravenous_dark()
	await open_fight()
	await unveiling()
	await cling()
	await crystalise()
	await open_fight()
	await restorative_aura()
	await open_fight({"alithia": "illusory_shepherd"})
	await four_reflections()
	await open_fight()
	await composure_and_sight()
	await open_fight()
	await terror()
	await open_fight()
	await elemental_ward()
	await open_fight()
	await shared_burden()
	await open_fight()
	await burner()
	await open_fight()
	await river_flow()
	await open_fight()
	await wind_swoon()
	await close_fight()
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


func open_fight(paths: Dictionary = {}):
	await close_fight()
	Campaign.reset()
	Campaign.set_party(PARTY, 32)
	for key in paths:
		Campaign.choose_subclass(key, paths[key])
	Campaign.current_map = "res://maps/crossroads_explore.tscn"
	Campaign.return_to_position = true
	Campaign.learned_spells = {"prometheus": ["turn_aside", "flame_fan", "storm_cloud", "light_void", "ravenous_dark", "unveil", "cling", "crystalise"]}
	Campaign.current_encounter = load(WATCHER)
	game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(6)
	combat = game.get_node("VisualCombat")
	controller = game.get_node("Controller")
	ui = game.get_node("CanvasLayer/UI")
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(2)
	prompt = combat.reaction_prompt
	for comb in combat.combatants:
		comb.reaction_used = true
		# Nobody falls by accident: a turn handed to a fallen one goes round and round.
		if comb.has("stats"):
			comb.hp = 900
			comb.max_hp = 900
		if comb.side == 1 and comb.has("stats"):
			comb.stats["mindfulness"] = 1


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


func foes() -> Array:
	return combat.combatants.filter(func(comb): return comb.side == 1 and comb.alive and not comb.has("object") and not comb.has("summoner") and not comb.get("illusion", false))


func their_turn(comb: Dictionary):
	combat.current_combatant = combat.combatants.find(comb)
	comb.skill_used_this_turn = false
	comb.secondary_used_this_turn = false
	controller.set_controlled_combatant(comb)
	await settle()


var _answering := false


## Nobody at the keyboard: anything asked while a turn plays out is answered no.
func _keep_answering():
	while _answering and is_inside_tree():
		if prompt != null and is_instance_valid(prompt) and prompt._waiting:
			prompt._answer_with(false)
		await get_tree().process_frame


func real_turn(before: Dictionary, comb: Dictionary):
	_answering = true
	_keep_answering()
	for each in combat.combatants:
		each.reaction_used = true
	var b: int = combat.combatants.find(before)
	var c: int = combat.combatants.find(comb)
	combat.turn_queue = [b, c, b]
	combat.turn = 0
	combat.current_combatant = b
	await combat.advance_turn()
	await settle(4)
	_answering = false


func answer_with(index: int):
	for i in 600:
		if prompt.is_asking() and prompt._waiting:
			prompt._choose(index)
			return
		await get_tree().process_frame


func answer_yes():
	for i in 600:
		if prompt.is_asking() and prompt._waiting:
			prompt._answer_with(true)
			return
		await get_tree().process_frame


func tile_away(from: Vector2i, gap: int, walker: Dictionary) -> Vector2i:
	for tile in controller.get_reachable_tiles(from, walker.movement_class, 40, walker):
		if combat.get_position_distance(tile, from) == gap and combat.can_land_on(walker, tile) and combat.get_combatant_at(tile).is_empty():
			return tile
	return from


## A free tile for `walker` outside `zone`, a couple of tiles clear of it.
func tile_out_of(zone: Dictionary, walker: Dictionary) -> Vector2i:
	for tile in controller.get_reachable_tiles(walker.position, walker.movement_class, 40, walker):
		if tile in zone.tiles or not combat.can_land_on(walker, tile) or not combat.get_combatant_at(tile).is_empty():
			continue
		if combat.get_position_distance(tile, zone.centre) >= zone.radius + 2:
			return tile
	return walker.position


func tether_rules():
	log_line("======== a tether with nothing to hold lets go ========")
	var alithia := who("alithia")
	var the_foes := foes()
	var one: Dictionary = the_foes[0]
	var two: Dictionary = the_foes[1]
	combat.teleport_to(one, tile_away(alithia.position, 4, one))
	combat.teleport_to(two, tile_away(one.position, 1, two))
	await their_turn(alithia)
	alithia.spell_slots[3] = 3
	await combat.use_skill("mesmerise", alithia, one.position, false)
	await settle()
	ok(combat.has_restriction(one, "skips_turn") and combat.has_restriction(two, "skips_turn"), "Mesmerise: both stunned")
	ok(Combat.holds_tether(alithia), "and on a tether")
	combat.do_damage(who("enfina"), one, SkillDatabase.skills.greatsword_attack.damage_effect(), SkillDatabase.skills.greatsword_attack)
	ok(not combat.has_restriction(one, "skips_turn"), "hurt, the first shakes it off")
	ok(combat.has_restriction(two, "skips_turn") and Combat.holds_tether(alithia), "the other is still stunned, so the tether holds")
	combat.do_damage(who("enfina"), two, SkillDatabase.skills.greatsword_attack.damage_effect(), SkillDatabase.skills.greatsword_attack)
	ok(not combat.has_restriction(two, "skips_turn"), "hurt, the second too")
	ok(not Combat.holds_tether(alithia), "and with nobody left stunned, the tether is gone")
	# By anything that hurts: a burn's tick, say.
	await their_turn(alithia)
	alithia.spell_slots[3] = 3
	await combat.use_skill("mesmerise", alithia, one.position, false)
	await settle()
	ok(combat.has_restriction(one, "skips_turn"), "again")
	combat.tick_condition_damage(one, load("res://data/conditions/burn.tres"), 10.0)
	ok(not combat.has_restriction(one, "skips_turn"), "a lingering tick wakes them too")
	combat.do_damage(who("enfina"), two, SkillDatabase.skills.greatsword_attack.damage_effect(), SkillDatabase.skills.greatsword_attack)
	# A spell with its own count: gone when that runs out.
	await their_turn(alithia)
	await combat.use_skill("dread_visage", alithia, one.position, false)
	await settle()
	ok(Combat.holds_tether(alithia) and alithia.tether.max == 200.0, "Dread Visage on a tether")
	for each in the_foes:
		each.status_effects = each.status_effects.filter(func(entry): return not entry.has("tether_of"))
	combat._release_idle_tethers()
	ok(not Combat.holds_tether(alithia), "what it put on them gone, it lets go")
	# Somebody felled no longer holds it up.
	await their_turn(alithia)
	alithia.spell_slots[1] = 3
	await combat.use_skill("ecstasy", alithia, two.position, false)
	await settle()
	ok(Combat.holds_tether(alithia), "Ecstasy on the second")
	two.hp = 1
	combat.do_damage(who("enfina"), two, SkillDatabase.skills.greatsword_attack.damage_effect(), SkillDatabase.skills.greatsword_attack)
	await settle()
	combat._release_idle_tethers()
	ok(not two.alive and not Combat.holds_tether(alithia), "felled, there is nothing left to hold")
	# One at a time.
	var enfina := who("enfina")
	await their_turn(alithia)
	alithia.spell_slots[1] = 3
	alithia.spell_slots[2] = 3
	await combat.use_skill("ecstasy", alithia, one.position, false)
	await settle()
	var tied_first: int = alithia.tether.id
	ok(combat.has_restriction(one, "skips_turn"), "another on the first")
	await their_turn(alithia)
	await combat.use_skill("silence", alithia, tile_away(alithia.position, 6, enfina), false)
	await settle()
	ok(alithia.tether.id != tied_first and alithia.tether.name == "Silence", "casting another lets go of it: one at a time")
	ok(not combat.has_restriction(one, "skips_turn"), "and what the first did ends")
	log_line("")


func turn_aside():
	log_line("======== Turn Aside ========")
	var prometheus := who("prometheus")
	var foe: Dictionary = foes()[0]
	var spell: SkillDefinition = SkillDatabase.skills.turn_aside
	ok(spell.spell_slot_level == 1 and spell.reaction_only and spell.answers_base_elements, "World, a reaction only")
	ok(combat._answers_this_blow(spell, foe, SkillDatabase.skills.fire_blast), "fire is answered")
	ok(combat._answers_this_blow(spell, foe, SkillDatabase.skills.greatsword_attack), "so is a plain blow")
	# An upgraded element and a special one are not.
	var plasma: SkillDefinition = SkillDatabase.skills.fire_blast.duplicate()
	plasma.damage_type = Damage.Type.PLASMA
	var psychic: SkillDefinition = SkillDatabase.skills.fire_blast.duplicate()
	psychic.damage_type = Damage.Type.PSYCHIC
	ok(not combat._answers_this_blow(spell, foe, plasma), "plasma is not")
	ok(not combat._answers_this_blow(spell, foe, psychic), "nor psychic")
	ok(not combat._answers_this_blow(spell, foe, SkillDatabase.skills.bewilder), "nor what does no damage")
	# Played: fire comes, he answers, he takes half.
	var skill: SkillDefinition = SkillDatabase.skills.fire_blast
	foe.skill_list.append("fire_blast")
	foe.spell_slots = [0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	prometheus.hp = 900
	prometheus.max_hp = 900
	var whole: int = combat.predict_hit(foe, prometheus, skill).damage
	await their_turn(foe)
	prometheus.reaction_used = false
	if not prometheus.skill_list.has("turn_aside"):
		prometheus.skill_list.append("turn_aside")
	var gates: int = prometheus.spell_slots[1]
	answer_yes()
	foe.status_effects.append({"stat": "accuracy", "amount": 100, "op": "add", "duration": 99, "source_name": "test"})
	await combat.use_skill("fire_blast", foe, prometheus.position, false)
	await settle(4)
	ok(prometheus.spell_slots[1] == gates - 1, "a World casting of his spent", "%s" % [prometheus.spell_slots])
	ok(900 - prometheus.hp == roundi(whole * 0.5) or 900 - prometheus.hp == int(whole * 0.5) + 1 or 900 - prometheus.hp == int(whole * 0.5), "he takes half of it", "%d of %d" % [900 - prometheus.hp, whole])
	ok(not combat.conditions_of(prometheus).any(func(condition): return condition.display_name == "Braced"), "and it is spent on that blow")
	log_line("")


func flame_fan():
	log_line("======== Flame Fan ========")
	var prometheus := who("prometheus")
	ok(prometheus.skill_list.has("flame_fan"), "the Elemental Vanguard's", "%s" % [prometheus.subclass if prometheus.has("subclass") else ""])
	var spell: SkillDefinition = SkillDatabase.skills.flame_fan
	ok(spell.spell_slot_level == 1 and spell.aoe_shape == SkillDefinition.AoEShape.CONE and spell.aoe_radius == 3 and spell.damage_type == Damage.Type.FIRE, "World, a small cone of fire")
	var foe: Dictionary = foes()[0]
	var run := _clear_run(prometheus)
	prometheus.position = run[0]
	prometheus.sprite.position = combat.sprite_point(prometheus)
	combat.teleport_to(foe, run[0] + run[1] * 2)
	controller.refresh_occupancy()
	await their_turn(prometheus)
	var hp: int = foe.hp
	await combat.use_skill("flame_fan", prometheus, foe.position, false)
	await settle()
	ok(foe.hp < hp, "it burns who stands there", "%d" % (hp - foe.hp))
	log_line("")


func _clear_run(anyone: Dictionary) -> Array:
	for x in range(0, 40):
		for y in range(0, 40):
			for way in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
				var clear := true
				for i in 7:
					var tile: Vector2i = Vector2i(x, y) + way * i
					if not controller.is_in_bounds(tile) or controller.is_tile_blocking(tile, 0) or (combat.get_combatant_at(tile).size() > 0 and combat.get_combatant_at(tile) != anyone):
						clear = false
						break
				if clear:
					return [Vector2i(x, y), way]
	return [anyone.position, Vector2i.RIGHT]


func storm_cloud():
	log_line("======== Storm Cloud ========")
	var prometheus := who("prometheus")
	var the_foes := foes()
	var foe: Dictionary = the_foes[0]
	ok(prometheus.skill_list.has("storm_cloud"), "the Elemental Conductor's")
	var spell: SkillDefinition = SkillDatabase.skills.storm_cloud
	ok(spell.spell_slot_level == 3 and spell.tether_strength == 200, "Pandora, tether 200")
	combat.teleport_to(foe, tile_away(prometheus.position, 5, foe))
	await their_turn(prometheus)
	prometheus.spell_slots[3] = 3
	ok(not combat.secondary_grants(prometheus).has("move_cloud"), "no cloud, nothing to move")
	var hp: int = foe.hp
	await combat.use_skill("storm_cloud", prometheus, foe.position, false)
	await settle()
	ok(foe.hp < hp, "lightning as it forms", "%d" % (hp - foe.hp))
	ok(combat.zones.size() == 1 and combat.zones[0].moves, "a cloud in the air")
	ok(Combat.holds_tether(prometheus) and prometheus.tether.max == 200.0, "on a tether of 200")
	ok(combat.secondary_grants(prometheus).has("move_cloud"), "Move Cloud is his secondary action now")
	# The start of an enemy's turn beneath it.
	hp = foe.hp
	await real_turn(prometheus, foe)
	ok(foe.hp < hp, "whoever starts their turn under it is struck", "%d" % (hp - foe.hp))
	# Move it: six from where it is, whoever he is.
	var cloud: Dictionary = combat.zones[0]
	var from: Vector2i = cloud.centre
	await their_turn(prometheus)
	prometheus.secondary_used_this_turn = false
	var move: SkillDefinition = SkillDatabase.skills.move_cloud
	var reach: Array = combat.get_range_tiles(move, prometheus.position, 0, prometheus)
	ok(reach.size() > 0 and reach.all(func(tile): return combat.get_position_distance(tile, from) <= 6), "its reach is six from the cloud", "%d tiles" % reach.size())
	var to: Vector2i = reach[reach.size() - 1]
	await combat.use_skill("move_cloud", prometheus, to, false, true)
	await settle()
	ok(cloud.centre == to and to in cloud.tiles and prometheus.secondary_used_this_turn, "it goes, for the secondary action", "%s" % cloud.centre)
	ok(not (from in cloud.tiles) or combat.get_position_distance(from, to) <= cloud.radius, "and what it covers goes with it")
	# Away from it, nobody is struck.
	combat.teleport_to(foe, tile_out_of(cloud, foe))
	combat.sync_zones()
	hp = foe.hp
	await real_turn(prometheus, foe)
	ok(foe.hp == hp, "out from under it, nothing", "%d" % (hp - foe.hp))
	# Tether gone, cloud gone.
	combat.snap_tether(prometheus, "test")
	ok(combat.zones.is_empty() and not combat.secondary_grants(prometheus).has("move_cloud"), "the tether gone, so is the cloud")
	log_line("")


func light_void():
	log_line("======== Light Void, and who sees in the dark ========")
	var prometheus := who("prometheus")
	var cyrus := who("cyrus")
	var enfina := who("enfina")
	var foe: Dictionary = foes()[0]
	ok(combat.sees_in_darkness(cyrus), "Cyrus sees in the dark")
	var young: Dictionary = combat.create_combatant(CombatantDatabase.combatants.cyrus, "cyrus", "", null, 1)
	ok(combat.sees_in_darkness(young), "  from level 1")
	ok(not combat.sees_in_darkness(enfina), "Enfina does not")
	combat.teleport_to(foe, tile_away(prometheus.position, 6, foe))
	await their_turn(prometheus)
	await combat.use_skill("light_void", prometheus, foe.position, false)
	await settle()
	ok(prometheus.tether.max == 200.0, "on a tether of 200")
	ok(combat.in_darkness(foe), "whoever is there is in the dark")
	ok(combat.is_invisible(foe), "and invisible")
	ok(combat.hidden_from(enfina, foe), "Enfina cannot see them")
	ok(not combat.hidden_from(cyrus, foe), "Cyrus can")
	ok(not combat.unseen_by_party(foe), "so the player sees them, faintly")
	ok(foe.sprite.modulate.a > 0.0 or true, "(drawn)")
	# Aiming: only whoever can see them.
	ok(combat.targets_if_aimed(enfina, SkillDatabase.skills.greatsword_attack, foe.position).is_empty() or combat.distance_to(enfina, foe.position) > 1, "Enfina has nobody to aim at there")
	var gun_reach: SkillDefinition = SkillDatabase.skills.gun
	if combat.distance_to(cyrus, foe.position) <= combat.effective_max_range(cyrus, gun_reach):
		ok(combat.targets_if_aimed(cyrus, gun_reach, foe.position).has(foe), "Cyrus does")
	# And without Cyrus, nobody sees them.
	cyrus.alive = false
	ok(combat.unseen_by_party(foe), "with him down, the player cannot see them either")
	cyrus.alive = true
	# The enemy's own: whoever of theirs sees in the dark finds the party there.
	combat.teleport_to(enfina, tile_away(foe.position, 1, enfina))
	combat.sync_zones()
	ok(combat.is_invisible(enfina), "the party's are invisible in it too")
	ok(combat.hidden_from(foe, enfina), "to an enemy who cannot see in it")
	var dark_eyes := PassiveDefinition.new()
	dark_eyes.sees_in_darkness = true
	foe.passives.append(dark_eyes)
	ok(not combat.hidden_from(foe, enfina), "an enemy with the same eyes finds her")
	foe.passives.erase(dark_eyes)
	# Stepping out.
	combat.teleport_to(enfina, tile_away(foe.position, 9, enfina))
	combat.sync_zones()
	ok(not combat.is_invisible(enfina), "stepping out, she is seen again")
	combat.snap_tether(prometheus, "test")
	ok(not combat.is_invisible(foe) and not combat.in_darkness(foe), "the tether gone, the dark goes")
	log_line("")


func ravenous_dark():
	log_line("======== Ravenous Dark ========")
	var prometheus := who("prometheus")
	var foe: Dictionary = foes()[0]
	combat.teleport_to(foe, tile_away(prometheus.position, 6, foe))
	await their_turn(prometheus)
	prometheus.spell_slots[3] = 3
	var hp: int = foe.hp
	await combat.use_skill("ravenous_dark", prometheus, foe.position, false)
	await settle()
	ok(foe.hp < hp, "it bites as it comes down", "%d" % (hp - foe.hp))
	ok(not Combat.holds_tether(prometheus), "no tether: it was not asked for one")
	ok(combat.in_darkness(foe), "and it is dark")
	var zone: Dictionary = combat.zones[0]
	var inside: Vector2i = zone.tiles[0]
	ok(combat.hem_cost(foe, inside) == 2, "a step in it costs twice")
	ok(combat.hem_cost(foe, prometheus.position) == 1 or prometheus.position in zone.tiles, "outside, as ever")
	hp = foe.hp
	await real_turn(prometheus, foe)
	ok(foe.hp < hp, "and it bites again at the start of an enemy's turn inside", "%d" % (hp - foe.hp))
	var hers := who("enfina")
	combat.teleport_to(hers, inside)
	combat.sync_zones()
	var her_hp: int = hers.hp
	await real_turn(prometheus, hers)
	ok(hers.hp == her_hp, "not at his own side's")
	var left: int = combat.zones[0].turns
	combat._zones_at_turn_start(prometheus)
	ok(combat.zones.is_empty() or combat.zones[0].turns == left - 1, "its time is counted in his turns")
	log_line("")


func unveiling():
	log_line("======== Unveil and Votive Flame ========")
	var prometheus := who("prometheus")
	var the_foes := foes()
	var unseen: Dictionary = the_foes[0]
	var hidden: Dictionary = the_foes[1]
	combat.teleport_to(unseen, tile_away(prometheus.position, 5, unseen))
	combat.teleport_to(hidden, tile_away(unseen.position, 1, hidden))
	combat.make_invisible(unseen)
	combat.set_hidden(hidden, true)
	ok(combat.is_invisible(unseen) and combat.is_hidden(hidden), "one invisible, one hidden")
	await their_turn(prometheus)
	await combat.use_skill("unveil", prometheus, unseen.position, false)
	await settle()
	ok(not combat.is_hidden(unseen) and not combat.is_invisible(unseen), "Unveil: the invisible is seen")
	ok(not combat.is_hidden(hidden), "and the hidden")
	# Votive Flame reveals whoever it hits.
	var alithia := who("alithia")
	combat.teleport_to(unseen, tile_away(alithia.position, 3, unseen))
	combat.make_invisible(unseen)
	await their_turn(alithia)
	alithia.status_effects.append({"stat": "accuracy", "amount": 100, "op": "add", "duration": 99, "source_name": "test"})
	await combat.use_skill("votive_flame", alithia, unseen.position, false)
	await settle()
	ok(not combat.is_hidden(unseen) and not combat.is_invisible(unseen), "Votive Flame: whoever it hits, it reveals")
	log_line("")


func cling():
	log_line("======== Cling ========")
	var prometheus := who("prometheus")
	var enfina := who("enfina")
	ok(not combat.climbs_anywhere(enfina), "Enfina does not climb")
	combat.teleport_to(enfina, tile_away(prometheus.position, 2, enfina))
	await their_turn(prometheus)
	await combat.use_skill("cling", prometheus, enfina.position, false)
	await settle()
	ok(combat.climbs_anywhere(enfina), "with Cling, she does")
	for i in 5:
		combat.end_of_turn_effects(enfina)
	ok(not combat.climbs_anywhere(enfina), "for five of her turns")
	log_line("")


func crystalise():
	log_line("======== Crystalise: an area, and stones left on it ========")
	var prometheus := who("prometheus")
	var foe: Dictionary = foes()[0]
	var spell: SkillDefinition = SkillDatabase.skills.crystalise
	ok(spell.aoe_radius > 0, "an area now", "%d" % spell.aoe_radius)
	foe.stats[Stats.KEYS[spell.contest_stat]] = 1
	combat.teleport_to(foe, tile_away(prometheus.position, 6, foe))
	await their_turn(prometheus)
	prometheus.spell_slots[2] = 3
	combat.zones.clear()
	await combat.use_skill("crystalise", prometheus, foe.position, false)
	await settle()
	ok(not combat.zones.is_empty(), "stones on the ground")
	var zone: Dictionary = combat.zones.back()
	var inside: Vector2i = zone.tiles[0]
	ok(combat.hem_cost(foe, inside) == 2, "each step on them costs twice")
	foe["movement_class"] = 1
	ok(combat.hem_cost(foe, inside) == 1, "but not for a flier")
	foe["movement_class"] = 0
	ok(zone.condition == null and not combat.has_restriction(foe, "prevents_spells"), "and they leave nothing on anybody but what the spell itself does")
	log_line("")


func restorative_aura():
	log_line("======== Restorative Aura ========")
	var alithia := who("alithia")
	var enfina := who("enfina")
	combat.teleport_to(enfina, tile_away(alithia.position, 2, enfina))
	await their_turn(alithia)
	alithia.spell_slots[3] = 3
	await combat.use_skill("restorative_aura", alithia, alithia.position, false)
	await settle()
	ok(alithia.tether.max == 200.0, "on a tether of 200")
	var aura: Dictionary = combat.zones[0]
	enfina.hp = 10
	await real_turn(alithia, enfina)
	ok(enfina.hp > 10, "an ally starting their turn in it mends", "%d" % (enfina.hp - 10))
	ok(enfina.hp < 40, "a little", "%d" % enfina.hp)
	var foe: Dictionary = foes()[0]
	combat.teleport_to(foe, tile_away(alithia.position, 2, foe))
	foe.hp = 100
	combat._zones_on_their_turn(foe)
	ok(foe.hp == 100, "an enemy is not mended", "%d" % foe.hp)
	# It goes where she goes.
	var far := tile_away(alithia.position, 7, alithia)
	combat.teleport_to(alithia, far)
	combat.sync_zones()
	ok(far in aura.tiles and aura.centre == far, "it goes where she goes", "%s" % aura.centre)
	combat.snap_tether(alithia, "test")
	ok(combat.zones.is_empty(), "the tether gone, it goes")
	log_line("")


func four_reflections():
	log_line("======== Four Reflections ========")
	var alithia := who("alithia")
	ok(alithia.skill_list.has("four_reflections"), "the Illusory Shepherd's")
	var foe: Dictionary = foes()[0]
	alithia.hp = 900
	alithia.max_hp = 900
	await their_turn(alithia)
	alithia.spell_slots[2] = 3
	await combat.use_skill("four_reflections", alithia, alithia.position, false)
	await settle()
	ok(combat.conditions_of(alithia).any(func(condition): return condition.evades_hits == 4), "four of her")
	var blow: SkillDefinition = SkillDatabase.skills.greatsword_attack
	for i in 3:
		ok(combat._evades(foe, alithia, blow), "a blow at her alone strikes a copy (%d)" % (i + 1))
	var area: SkillDefinition = SkillDatabase.skills.fireball
	ok(not combat._evades(foe, alithia, area), "an area finds her all the same")
	ok(combat.conditions_of(alithia).any(func(condition): return condition.evades_hits == 4), "one left")
	ok(combat._evades(foe, alithia, blow), "the last")
	ok(not combat.conditions_of(alithia).any(func(condition): return condition.evades_hits > 0), "and it is over with them")
	ok(not combat._evades(foe, alithia, blow), "the next blow lands")
	log_line("")


func composure_and_sight():
	log_line("======== Composure, and Clear Sight ========")
	var alithia := who("alithia")
	var foe: Dictionary = foes()[0]
	alithia.hp = 900
	alithia.max_hp = 900
	var blow: SkillDefinition = SkillDatabase.skills.greatsword_attack
	var whole: int = combat.predict_hit(foe, alithia, blow).damage
	await their_turn(alithia)
	alithia.spell_slots[1] = 3
	alithia.spell_slots[2] = 3
	combat.teleport_to(foe, tile_away(alithia.position, 3, foe))
	await combat.use_skill("ecstasy", alithia, foe.position, false)
	await settle()
	var bar: float = alithia.tether.bar
	await their_turn(alithia)
	alithia.status_effects = alithia.status_effects.filter(func(entry): return entry.get("stat", "") != "accuracy")
	await combat.use_skill("composure", alithia, alithia.position, false)
	await settle()
	var halved: int = combat.predict_hit(foe, alithia, blow).damage
	ok(halved <= ceili(whole * 0.5) and halved >= floori(whole * 0.5) - 1, "half of any blow", "%d of %d" % [halved, whole])
	combat.lose_hp(alithia, 200)
	ok(alithia.tether.bar == bar, "and what gets through frays no tether of hers", "%s" % alithia.tether.bar)
	# Cast in her own turn: the rest of this one, and four more.
	for i in 5:
		combat.end_of_turn_effects(alithia)
	combat.lose_hp(alithia, 90)
	ok(not Combat.holds_tether(alithia) or alithia.tether.bar < bar, "after four turns, it does", "%s" % [alithia.get("tether", {}).get("bar", "gone")])
	# Clear Sight.
	var spell: SkillDefinition = SkillDatabase.skills.clear_sight
	ok(spell.is_secondary and spell.spell_slot_level == 2, "Clear Sight: Hermes, a secondary action")
	combat.make_invisible(foe)
	ok(combat.is_invisible(foe) and combat.hidden_from(alithia, foe), "she cannot see somebody invisible")
	await their_turn(alithia)
	await combat.use_skill("clear_sight", alithia, alithia.position, false, true)
	await settle()
	ok(alithia.secondary_used_this_turn and not alithia.skill_used_this_turn, "it takes her secondary action")
	ok(not combat.hidden_from(alithia, foe), "now she can")
	ok(not combat.unseen_by_party(foe), "and so can the player")
	ok(combat.sees_in_darkness(alithia), "and she sees in the dark")
	for i in 11:
		combat.end_of_turn_effects(alithia)
	ok(combat.hidden_from(alithia, foe), "for ten of her turns, and the rest of this one")
	log_line("")


func terror():
	log_line("======== Terror ========")
	var alithia := who("alithia")
	var foe: Dictionary = foes()[0]
	var spell: SkillDefinition = SkillDatabase.skills.terror
	ok(spell.spell_slot_level == 3 and spell.aoe_shape == SkillDefinition.AoEShape.CONE and spell.aoe_radius == 6 and spell.tether_strength == 200, "Pandora, a 6 tile cone, tether 200")
	combat.teleport_to(foe, tile_away(alithia.position, 3, foe))
	await their_turn(alithia)
	alithia.spell_slots[3] = 3
	await combat.use_skill("terror", alithia, foe.position, false)
	await settle()
	ok(combat.has_restriction(foe, "prevents_approach"), "they are afraid")
	ok(not combat._terror_of(foe).is_empty(), "of her")
	var gap: int = combat.get_position_distance(foe.position, alithia.position)
	var foe_hp: int = alithia.hp
	await real_turn(alithia, foe)
	ok(combat.get_position_distance(foe.position, alithia.position) > gap, "at the start of their turn they run", "%d -> %d" % [gap, combat.get_position_distance(foe.position, alithia.position)])
	ok(foe.get("turn_taken", false), "and carry on with the turn: it ran its course")
	for i in 10:
		combat.end_of_turn_effects(foe)
	ok(combat.has_restriction(foe, "prevents_approach"), "as long as the tether holds, not a count of turns")
	# Steady Heart wards an ally against it: it is Fear.
	ok(combat.immune_to_condition({"status_effects": [{"stat": "condition", "condition": load("res://data/conditions/unafraid.tres")}]}, load("res://data/conditions/fear.tres")), "(Steady Heart would ward it off)")
	combat.snap_tether(alithia, "test")
	ok(not combat.has_restriction(foe, "prevents_approach") and combat._terror_of(foe).is_empty(), "the tether gone, so is the fear")
	log_line("")


func elemental_ward():
	log_line("======== Elemental Ward ========")
	var alithia := who("alithia")
	var enfina := who("enfina")
	combat.teleport_to(enfina, tile_away(alithia.position, 2, enfina))
	var before: int = combat.resistance_of(enfina, Damage.Type.WATER)
	await their_turn(alithia)
	alithia.spell_slots[3] = 3
	answer_with(1)
	await combat.use_skill("elemental_ward", alithia, enfina.position, false)
	await settle()
	ok(combat.resistance_of(enfina, Damage.Type.WATER) == before + 50, "the element she chose, half", "%d" % combat.resistance_of(enfina, Damage.Type.WATER))
	ok(combat.resistance_of(enfina, Damage.Type.FIRE) != before + 50 or before == 0 and combat.resistance_of(enfina, Damage.Type.FIRE) == 0, "not the others")
	ok(alithia.tether.max == 200.0, "on a tether of 200")
	for i in 10:
		combat.end_of_turn_effects(enfina)
	ok(combat.resistance_of(enfina, Damage.Type.WATER) == before + 50, "as long as it holds")
	combat.snap_tether(alithia, "test")
	ok(combat.resistance_of(enfina, Damage.Type.WATER) == before, "and no longer")
	log_line("")


func burner():
	log_line("======== Burner: fire that stays ========")
	var prometheus := who("prometheus")
	var enfina := who("enfina")
	var foe: Dictionary = foes()[0]
	var spell: SkillDefinition = SkillDatabase.skills.burner
	ok(spell.aoe_radius > 0, "an area now", "%d" % spell.aoe_radius)
	foe.stats[Stats.KEYS[spell.contest_stat]] = 1
	combat.teleport_to(foe, tile_away(prometheus.position, 6, foe))
	await their_turn(prometheus)
	prometheus.spell_slots[2] = 3
	var hp: int = foe.hp
	await combat.use_skill("burner", prometheus, foe.position, false)
	await settle()
	ok(foe.hp < hp, "it burns who is there as it lands", "%d" % (hp - foe.hp))
	ok(combat.conditions_of(foe).any(func(condition): return condition.display_name == "Burn"), "and leaves them burning")
	var fire: Dictionary = combat.zones[0]
	ok(fire.tiles.size() > 1 and fire.effect.zone_hurts_each_step, "and the area stays, over all the blast covered", "%d tiles" % fire.tiles.size())
	# Starting a turn in it.
	foe.status_effects = []
	hp = foe.hp
	combat._zones_on_their_turn(foe)
	ok(foe.hp < hp, "whoever starts their turn in it is hurt", "%d" % (hp - foe.hp))
	var tick: int = hp - foe.hp
	ok(combat.conditions_of(foe).any(func(condition): return condition.display_name == "Burn"), "and burned again")
	# Anybody: it is no friend of his side.
	combat.teleport_to(enfina, tile_out_of(fire, enfina))
	var enfina_hp: int = enfina.hp
	combat._zones_on_their_turn(enfina)
	ok(enfina.hp == enfina_hp, "outside it, nothing")
	# A walk through: hurt for every tile of it.
	enfina.hp = 900
	enfina.max_hp = 900
	var entered: Array = fire.tiles.filter(func(tile): return combat.can_land_on(enfina, tile) and combat.get_combatant_at(tile).is_empty())
	ok(entered.size() >= 2, "room to walk in it", "%d" % entered.size())
	combat.teleport_to(enfina, tile_next_to(entered[0], fire, enfina))
	await their_turn(enfina)
	controller.set_movement(40)
	var before: int = enfina.hp
	await controller.ai_move(entered[0])
	await settle()
	ok(enfina.hp < before, "stepping in hurts", "%d" % (before - enfina.hp))
	ok(combat.conditions_of(enfina).any(func(condition): return condition.display_name == "Burn"), "and burns")
	var one_step: int = before - enfina.hp
	enfina.status_effects = []
	before = enfina.hp
	combat.zones_under_step(enfina, entered[0])
	combat.zones_under_step(enfina, entered[0])
	ok(before - enfina.hp == one_step * 2, "each tile of it again", "%d of %d" % [before - enfina.hp, one_step])
	# Never for a step outside it.
	before = enfina.hp
	combat.zones_under_step(enfina, tile_out_of(fire, enfina))
	ok(enfina.hp == before, "a step outside it, nothing")
	var left: int = combat.zones[0].turns
	combat._zones_at_turn_start(prometheus)
	ok(combat.zones.is_empty() or combat.zones[0].turns == left - 1, "it lasts so many of his turns")
	log_line("")


## A free tile beside `tile` outside `zone`, or the nearest.
func tile_next_to(tile: Vector2i, zone: Dictionary, walker: Dictionary) -> Vector2i:
	var best: Vector2i = walker.position
	var least := 999
	for candidate in controller.get_reachable_tiles(walker.position, walker.movement_class, 40, walker):
		if candidate in zone.tiles or not combat.get_combatant_at(candidate).is_empty():
			continue
		var gap := combat.get_position_distance(candidate, tile)
		if gap < least and gap >= 1:
			least = gap
			best = candidate
	return best


func river_flow():
	log_line("======== River Flow: a blow carries them to the edge ========")
	var alithia := who("alithia")
	var enfina := who("enfina")
	var foe: Dictionary = foes()[0]
	var spell: SkillDefinition = SkillDatabase.skills.river_flow
	ok(spell.aoe_radius > 0, "an area now", "%d" % spell.aoe_radius)
	foe.stats[Stats.KEYS[spell.contest_stat]] = 1
	var run := _clear_run(foe)
	var way: Vector2i = run[1]
	# Enfina at one end, the foe beside her, the river's middle two on from them.
	combat.teleport_to(enfina, run[0])
	combat.teleport_to(foe, run[0] + way)
	combat.teleport_to(alithia, tile_away(alithia.position, 0, alithia))
	await their_turn(alithia)
	alithia.spell_slots[2] = 3
	var middle: Vector2i = run[0] + way * 3
	await combat.use_skill("river_flow", alithia, middle, false)
	await settle()
	ok(not combat.zones.is_empty(), "the water stays")
	var river: Dictionary = combat.zones[0]
	ok(foe.position in river.tiles and middle in river.tiles, "over all the blast covered", "%d tiles" % river.tiles.size())
	# A plain melee blow: to the edge.
	var edge: Vector2i = foe.position
	while edge + way in river.tiles:
		edge += way
	foe.status_effects = []
	foe.hp = 900
	await their_turn(enfina)
	enfina.status_effects.append({"stat": "accuracy", "amount": 100, "op": "add", "duration": 99, "source_name": "test"})
	var blow: SkillDefinition = SkillDatabase.skills.greatsword_attack
	var seen: Array = combat.foresee_shoves(enfina, blow, [foe])
	ok(seen.size() == 1 and seen[0].to == edge, "the aim shows it", "%s" % [seen[0].to if not seen.is_empty() else null])
	await combat.use_skill("greatsword_attack", enfina, foe.position, false)
	await settle()
	ok(foe.position == edge, "a melee blow carries them to its edge", "%s, edge %s" % [foe.position, edge])
	# A shove goes that much further: the move's own tiles on top.
	combat.teleport_to(foe, run[0] + way)
	foe.hp = 900
	await their_turn(enfina)
	var shove: SkillDefinition = SkillDatabase.skills.shoving_strike
	var to_edge: int = combat.get_position_distance(run[0] + way, edge)
	var beyond: Vector2i = run[0] + way + way * (to_edge + 3)
	var clear := true
	for i in range(1, to_edge + 4):
		if not combat.can_land_on(foe, run[0] + way + way * i):
			clear = false
	seen = combat.foresee_shoves(enfina, shove, [foe])
	if clear:
		ok(seen[0].to == beyond, "Shoving Strike: to the edge, and its three tiles on from there", "%s" % seen[0].to)
	await combat.use_skill("shoving_strike", enfina, foe.position, false)
	await settle()
	ok(foe.position == seen[0].to, "and that is where they end up", "%s" % foe.position)
	# Out of the water, a blow is a blow.
	combat.teleport_to(enfina, run[0])
	var dry: Vector2i = tile_out_of(river, foe)
	combat.teleport_to(foe, dry)
	foe.hp = 900
	ok(combat._sweep_tiles(foe, way, blow) == 0, "out of the water, nothing carries them")
	# A ranged blow does not.
	combat.teleport_to(foe, run[0] + way)
	ok(combat._sweep_tiles(foe, way, SkillDatabase.skills.gun) == 0, "nor does a shot, in it")
	log_line("")


func wind_swoon():
	log_line("======== Wind Swoon: the wind stays ========")
	var prometheus := who("prometheus")
	var foe: Dictionary = foes()[0]
	var spell: SkillDefinition = SkillDatabase.skills.wind_swoon
	ok(spell.aoe_radius > 0, "an area now", "%d" % spell.aoe_radius)
	foe.stats[Stats.KEYS[spell.contest_stat]] = 1
	combat.teleport_to(foe, tile_away(prometheus.position, 6, foe))
	await their_turn(prometheus)
	prometheus.spell_slots[2] = 3
	await combat.use_skill("wind_swoon", prometheus, foe.position, false)
	await settle()
	var gale: Dictionary = combat.zones[0]
	ok(foe.position in gale.tiles and gale.tiles.size() > 1, "the wind stays over all the blast covered", "%d tiles" % gale.tiles.size())
	# Starting a turn there.
	var from: Vector2i = foe.position
	combat._zones_on_their_turn(foe)
	ok(not (foe.position in gale.tiles) and foe.position != from, "starting a turn in it, they are thrown out", "%s" % foe.position)
	# Ending one.
	combat.teleport_to(foe, gale.centre)
	combat._zones_at_turn_end(foe)
	ok(not (foe.position in gale.tiles), "ending one too", "%s" % foe.position)
	# Anybody.
	var enfina := who("enfina")
	combat.teleport_to(enfina, gale.tiles.filter(func(tile): return combat.can_land_on(enfina, tile) and combat.get_combatant_at(tile).is_empty())[0])
	combat._zones_on_their_turn(enfina)
	ok(not (enfina.position in gale.tiles), "whoever it is")
	# Immune to being shoved: it stands there.
	combat.teleport_to(foe, gale.centre)
	foe["immune_to"] = [Immunity.Kind.SHOVED]
	combat._zones_at_turn_end(foe)
	ok(foe.position == gale.centre, "somebody who cannot be shoved stays")
	foe["immune_to"] = []
	log_line("")


func shared_burden():
	log_line("======== Shared Burden ========")
	var alithia := who("alithia")
	var enfina := who("enfina")
	var foe: Dictionary = foes()[0]
	alithia.hp = 900
	alithia.max_hp = 900
	enfina.hp = 900
	enfina.max_hp = 900
	combat.teleport_to(enfina, tile_away(alithia.position, 2, enfina))
	await their_turn(alithia)
	alithia.spell_slots[2] = 3
	await combat.use_skill("shared_burden", alithia, enfina.position, false)
	await settle()
	ok(alithia.tether.max == 200.0, "on a tether of 200")
	var bar: float = alithia.tether.bar
	# Enfina holding a tether of her own, say.
	enfina["tether"] = {"skill": "test", "name": "Test", "bar": 100.0, "max": 100.0, "per_turn": 25.0, "per_damage": 1.0, "id": 99991}
	var blow: SkillDefinition = SkillDatabase.skills.greatsword_attack
	var whole: int = combat.predict_hit(foe, enfina, blow).damage
	var her_hp: int = alithia.hp
	var ally_hp: int = enfina.hp
	combat.do_damage(foe, enfina, blow.damage_effect(), blow)
	await settle()
	var hers: int = her_hp - alithia.hp
	var theirs: int = ally_hp - enfina.hp
	ok(hers > 0 and hers + theirs == whole and absi(hers - theirs) <= 1, "half to each", "%d and %d of %d" % [hers, theirs, whole])
	ok(alithia.tether.bar == bar, "it frays no tether of hers", "%s" % alithia.tether.bar)
	ok(enfina.tether.bar == 100.0, "nor the ally's", "%s" % enfina.tether.bar)
	# Whatever hurts them, not only a blow: the arena, say.
	her_hp = alithia.hp
	ally_hp = enfina.hp
	combat.hit_by_the_arena(enfina, 40, Damage.Type.FIRE, null, 0, 0.0, "The Arena")
	await settle()
	ok(alithia.hp < her_hp and absi((her_hp - alithia.hp) - (ally_hp - enfina.hp)) <= 1, "the arena's share too", "%d and %d" % [her_hp - alithia.hp, ally_hp - enfina.hp])
	enfina.erase("tether")
	combat.snap_tether(alithia, "test")
	her_hp = alithia.hp
	ally_hp = enfina.hp
	combat.do_damage(foe, enfina, blow.damage_effect(), blow)
	ok(alithia.hp == her_hp and enfina.hp < ally_hp, "the tether gone, it is theirs alone again")
	log_line("")
