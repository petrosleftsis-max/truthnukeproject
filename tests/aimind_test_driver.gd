extends Node
## The AI's mind (Combat "The AI's mind"; the designer, 2026-11-06): each thing a creature may know, one
## at a time, and that those who do not know it do not act on it.

const LOG_NAME := "aimind"
const WATCHER := "res://data/encounters/encounter_03_watcher.tres"
const PARTY := ["enfina", "cyrus", "prometheus", "alithia"]
const K := CombatantDefinition.AiKnows

var LOG_PATH := HarnessLog.path_for(LOG_NAME)
var _log: FileAccess = null
var _fail := 0
var game = null
var combat: Combat = null
var controller = null
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
	smarts_table()
	await open_fight()
	await instinct()
	await open_fight()
	await dials()
	await open_fight()
	await the_ground()
	await open_fight()
	await telegraphs()
	await open_fight()
	await hazards()
	await open_fight()
	await shoves()
	await open_fight()
	await tethers()
	await open_fight()
	await reach_and_spreading()
	await open_fight()
	await set_ups()
	await open_fight()
	await hemming_and_blocking()
	await open_fight()
	await triage()
	await open_fight()
	await gates()
	await open_fight()
	await in_the_dark()
	await open_fight()
	await falling_back()
	await open_fight()
	await whole_turns()
	await close_fight()
	log_line("FAILURES: %d" % _fail)
	_log.close()
	get_tree().quit(0 if _fail == 0 else 1)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


func open_fight():
	await close_fight()
	Campaign.reset()
	Campaign.set_party(PARTY, 32)
	Campaign.current_map = "res://maps/crossroads_explore.tscn"
	Campaign.return_to_position = true
	Campaign.current_encounter = load(WATCHER)
	game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(6)
	combat = game.get_node("VisualCombat")
	controller = game.get_node("Controller")
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(2)
	prompt = combat.reaction_prompt
	for comb in combat.combatants:
		comb.reaction_used = true
		if comb.has("stats"):
			comb.hp = 900
			comb.max_hp = 900


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
	return combat.combatants.filter(func(comb): return comb.side == 1 and comb.alive and not comb.has("object") and not comb.get("illusion", false))


func their_turn(comb: Dictionary):
	combat.current_combatant = combat.combatants.find(comb)
	comb.skill_used_this_turn = false
	comb.secondary_used_this_turn = false
	controller.set_controlled_combatant(comb)
	await settle()


## A tile `gap` from `from` that `walker` could stand on.
func tile_away(from: Vector2i, gap: int, walker: Dictionary) -> Vector2i:
	for tile in controller.get_reachable_tiles(from, walker.movement_class, 40, walker):
		if combat.get_position_distance(tile, from) == gap and combat.can_land_on(walker, tile) and combat.get_combatant_at(tile).is_empty():
			return tile
	return from


## The first clear stretch of `length` tiles along `way` out of `from`, or `from` when there is none.
func clear_row(from: Vector2i, way: Vector2i, length: int) -> Vector2i:
	for gap in range(1, 16):
		var start: Vector2i = from + way * gap
		var fits := true
		for step in length:
			var tile: Vector2i = start + way * step
			if not controller.is_on_map(tile) or controller.is_tile_blocking(tile, 0) or not combat.get_combatant_at(tile).is_empty():
				fits = false
				break
		if fits:
			return start
	return from


func smarts_table():
	log_line("======== who knows what ========")
	var rat: CombatantDefinition = CombatantDatabase.combatants.rat
	var barbarian: CombatantDefinition = CombatantDatabase.combatants.barbarian
	var sorcerer: CombatantDefinition = CombatantDatabase.combatants.sorcerer
	var warden: CombatantDefinition = CombatantDatabase.combatants.ash_warden
	ok(rat.ai_smarts == CombatantDefinition.AiSmarts.INSTINCT and Combat._ai_knows_of(rat) == 0, "a rat knows nothing")
	ok(barbarian.ai_smarts == CombatantDefinition.AiSmarts.TRAINED and Combat._ai_knows_of(barbarian) & K.GROUND != 0, "a barbarian is trained: he knows the ground")
	ok(Combat._ai_knows_of(barbarian) & K.TETHERS == 0, "not what a tether is")
	ok(sorcerer.ai_smarts == CombatantDefinition.AiSmarts.CUNNING and Combat._ai_knows_of(sorcerer) & K.TETHERS != 0, "a sorcerer is cunning: she does")
	ok(Combat._ai_knows_of(sorcerer) & K.SET_UPS == 0, "not set-ups")
	ok(warden.ai_smarts == CombatantDefinition.AiSmarts.ALL_KNOWING and Combat._ai_knows_of(warden) & K.KITS != 0, "the Ash Warden has everything, kits too", "%d" % Combat._ai_knows_of(warden))
	var tweaked: CombatantDefinition = rat.duplicate()
	tweaked.ai_also_knows = K.GROUND
	ok(Combat._ai_knows_of(tweaked) == K.GROUND, "one creature can know more than its smarts")
	var other: CombatantDefinition = barbarian.duplicate()
	other.ai_never_knows = K.GROUND
	ok(Combat._ai_knows_of(other) & K.GROUND == 0, "or less")
	ok(barbarian.ai_aggression > 1.0 and barbarian.ai_caution < 1.0, "and the barbarian's dials are his own")
	log_line("")


func instinct():
	log_line("======== Instinct ========")
	var foe: Dictionary = who("barbarian")
	var near: Dictionary = who("enfina")
	var far: Dictionary = who("prometheus")
	combat.teleport_to(near, tile_away(foe.position, 2, near))
	combat.teleport_to(far, tile_away(foe.position, 6, far))
	await settle()
	# The far one all but dead: the trained go for the kill.
	far.hp = 1
	var blow: SkillDefinition = SkillDatabase.skills.greatsword_attack
	ok(combat.ai_target_value(foe, far, blow) > combat.ai_target_value(foe, near, blow), "the trained go for the kill, wherever it is")
	foe["ai_smarts"] = CombatantDefinition.AiSmarts.INSTINCT
	ok(combat.ai_target_value(foe, near, blow) > combat.ai_target_value(foe, far, blow), "Instinct goes for whoever is nearest")
	log_line("")


func dials():
	log_line("======== the dials ========")
	var foe: Dictionary = who("barbarian")
	var target: Dictionary = who("enfina")
	var blow: SkillDefinition = SkillDatabase.skills.greatsword_attack
	foe["ai_aggression"] = 1.0
	foe["ai_focus"] = 1.0
	target.hp = 450
	var base: float = combat.ai_target_value(foe, target, blow)
	foe["ai_aggression"] = 2.0
	ok(combat.ai_target_value(foe, target, blow) > base, "aggression: a blow is worth more")
	foe["ai_aggression"] = 1.0
	foe["ai_focus"] = 3.0
	ok(combat.ai_target_value(foe, target, blow) > base, "focus: so is whoever is already hurt")
	foe["ai_focus"] = 1.0
	combat._ai_focus_id = target.id
	var focused: float = combat.ai_target_value(foe, target, blow)
	foe["ai_focus"] = 2.0
	ok(combat.ai_target_value(foe, target, blow) > focused, "and whoever its side last went for")
	combat._ai_focus_id = -1
	log_line("")


func the_ground():
	log_line("======== it knows the ground ========")
	var alithia := who("alithia")
	var prometheus := who("prometheus")
	var foe: Dictionary = who("barbarian")
	# Burner's ground under them.
	await their_turn(prometheus)
	combat.teleport_to(foe, tile_away(prometheus.position, 5, foe))
	await settle()
	prometheus.spell_slots[SkillDatabase.skills.burner.spell_slot_level] = 5
	await combat.use_skill("burner", prometheus, foe.position, false)
	await settle()
	var zone: Dictionary = combat.zones.filter(func(each): return each.effect != null and each.effect.zone_hurts_each_step)[0] if combat.zones.any(func(each): return each.effect != null and each.effect.zone_hurts_each_step) else {}
	ok(not zone.is_empty(), "Burner lies on the ground")
	if zone.is_empty():
		return
	foe.ai_knows = K.GROUND
	combat._ai_read_the_field(foe)
	ok(combat._ai_tile_worth(foe, zone.tiles[0]) < 0.0, "it knows that ground is bad")
	foe.ai_knows = 0
	combat._ai_read_the_field(foe)
	ok(combat._ai_tile_worth(foe, zone.tiles[0]) == 0.0, "Instinct does not")
	# It walks off.
	foe.ai_knows = K.GROUND
	await their_turn(foe)
	controller.movement = 12
	await combat._ai_leave_bad_ground(foe)
	await settle()
	ok(not foe.position in zone.tiles, "standing on it, it walks off by the shortest way", "%s" % foe.position)
	ok(foe.get("ran_this_turn", false), "and goes on with the movement left")
	# Silence, for whoever casts.
	combat.zones.clear()
	await their_turn(alithia)
	alithia.spell_slots[SkillDatabase.skills.silence.spell_slot_level] = 5
	var sorcerer: Dictionary = who("sorcerer")
	combat.teleport_to(sorcerer, tile_away(alithia.position, 5, sorcerer))
	await settle()
	await combat.use_skill("silence", alithia, sorcerer.position, false)
	await settle()
	sorcerer.ai_knows = K.GROUND
	ok(not combat.zones.is_empty(), "Silence lies over the sorcerer", "%d" % combat.zones.size())
	combat._ai_read_the_field(sorcerer)
	ok(combat._ai_tile_worth(sorcerer, sorcerer.position) < 0.0, "whoever casts wants out of it")
	var bruiser: Dictionary = who("barbarian")
	bruiser.ai_knows = K.GROUND
	combat._ai_read_the_field(bruiser)
	ok(combat._ai_tile_worth(bruiser, sorcerer.position) == 0.0, "whoever only swings does not care")

	log_line("")


func telegraphs():
	log_line("======== it steps off telegraphs ========")
	var foe: Dictionary = who("barbarian")
	var enfina := who("enfina")
	foe.ai_knows = K.TELEGRAPHS
	var spot: Vector2i = foe.position
	enfina["declared"] = {"skill": "greatsword_attack", "tiles": [spot], "waiting": []}
	combat._ai_read_the_field(foe)
	ok(combat._ai_tile_worth(foe, spot) < 0.0, "somebody's declared blow is about to land there")
	await their_turn(foe)
	controller.movement = 6
	await combat._ai_leave_bad_ground(foe)
	await settle()
	ok(foe.position != spot, "so it steps off", "%s" % foe.position)
	enfina.erase("declared")
	combat._hazard_marks.append({"hazard": null, "tiles": [foe.position], "lands": 99})
	combat._ai_read_the_field(foe)
	ok(combat._ai_tile_worth(foe, foe.position) < 0.0, "and off what the arena has marked")
	combat._hazard_marks.clear()
	foe.ai_knows = 0
	enfina["declared"] = {"skill": "greatsword_attack", "tiles": [foe.position], "waiting": []}
	combat._ai_read_the_field(foe)
	ok(combat._ai_tile_worth(foe, foe.position) == 0.0, "Instinct stands there")
	enfina.erase("declared")
	log_line("")


func hazards():
	log_line("======== hazards ========")
	var foe: Dictionary = who("ranger")
	var enfina := who("enfina")
	var charge_def: CombatantDefinition = load("res://data/objects/demolition_charge.tres")
	var charge: Dictionary = combat.create_combatant(charge_def, "demolition_charge")
	combat.add_combatant(charge, 1, tile_away(enfina.position, 1, enfina))
	charge.hp = 1
	await settle()
	# All the party round it.
	foe.ai_knows = K.KEEPS_FROM_HAZARDS | K.SETS_OFF_HAZARDS
	combat.teleport_to(foe, tile_away(charge.position, 5, foe))
	await settle()
	combat._ai_read_the_field(foe)
	ok(combat._ai_tile_worth(foe, tile_away(charge.position, 1, foe)) < 0.0, "it keeps away from what goes off")
	var worth: float = combat._ai_blast_worth(foe, charge)
	ok(worth > 0.0, "with the party round it, setting it off is worth something", "%.0f" % worth)
	# Nobody of theirs near, worthless; somebody of its own, a cost.
	var bruiser: Dictionary = who("barbarian")
	combat.teleport_to(bruiser, tile_away(charge.position, 1, bruiser))
	await settle()
	ok(combat._ai_blast_worth(foe, charge) < worth, "one of its own there, it is worth less")
	combat.teleport_to(bruiser, tile_away(charge.position, 8, bruiser))
	await settle()
	# It shoots it.
	await their_turn(foe)
	controller.movement = 8
	Campaign.current_encounter.ai_leaves_hazards = true
	combat.encounter = Campaign.current_encounter
	ok(not await combat._ai_set_off_a_hazard(foe), "an encounter can tell it to leave them be")
	combat._ai_read_the_field(foe)
	ok(combat._ai_tile_worth(foe, tile_away(charge.position, 1, foe)) == 0.0, "and it stops minding them")
	Campaign.current_encounter.ai_leaves_hazards = false
	var hp: int = enfina.hp
	var did: bool = await combat._ai_set_off_a_hazard(foe)
	await settle()
	ok(did and not charge.alive, "it shoots the charge", "%s" % did)
	ok(enfina.hp < hp, "and the blast catches whoever was round it", "%d -> %d" % [hp, enfina.hp])
	ok(combat._ai_shooting_thing == -1, "and it goes back to aiming at people")
	log_line("")


func shoves():
	log_line("======== it uses shoves ========")
	var foe: Dictionary = who("barbarian")
	var enfina := who("enfina")
	foe.ai_knows = K.SHOVES
	var skill: SkillDefinition = SkillDatabase.skills.shoving_strike
	# One beside a body: a throw into it hurts.
	var row: Vector2i = clear_row(foe.position, Vector2i.RIGHT, 2)
	ok(row != foe.position, "room to try it", "%s" % row)
	var blocker: Dictionary = who("cyrus")
	combat.teleport_to(enfina, row)
	combat.teleport_to(foe, row + Vector2i.LEFT)
	combat.teleport_to(blocker, row + Vector2i.RIGHT)
	await settle()
	var into_someone: float = combat._ai_shove_worth(foe, skill, foe.position, enfina.position)
	combat.teleport_to(blocker, tile_away(row, 8, blocker))
	await settle()
	var into_air: float = combat._ai_shove_worth(foe, skill, foe.position, enfina.position)
	ok(into_someone > into_air, "a throw into somebody is worth more than one into the open", "%.0f, %.0f" % [into_someone, into_air])
	# Nothing moved by asking.
	ok(foe.position == row + Vector2i.LEFT, "and asking moves nobody")
	# One of its own in the way: a cost.
	var ally: Dictionary = who("sorcerer")
	combat.teleport_to(ally, row + Vector2i.RIGHT)
	await settle()
	ok(combat._ai_shove_worth(foe, skill, foe.position, enfina.position) < into_someone, "into one of its own, it is worth less")
	log_line("")


func tethers():
	log_line("======== tethers ========")
	var alithia := who("alithia")
	var foe: Dictionary = who("sorcerer")
	var other: Dictionary = who("barbarian")
	foe.stats["mindfulness"] = 1
	combat.teleport_to(foe, tile_away(alithia.position, 3, foe))
	await settle()
	await their_turn(alithia)
	alithia.spell_slots[3] = 3
	await combat.use_skill("mesmerise", alithia, foe.position, false)
	await settle()
	ok(combat.holds_tether(alithia), "Mesmerise held on her tether")
	var blow: SkillDefinition = SkillDatabase.skills.greatsword_attack
	other.ai_knows = 0
	other["ai_smarts"] = CombatantDefinition.AiSmarts.TRAINED
	var plain: float = combat.ai_target_value(other, alithia, blow)
	other.ai_knows = K.TETHERS
	ok(combat.ai_target_value(other, alithia, blow) > plain, "whoever holds it is worth more to whoever knows", "%.0f -> %.0f" % [plain, combat.ai_target_value(other, alithia, blow)])
	# Somebody beside the stunned one slaps them awake.
	ok(combat.has_restriction(foe, "skips_turn"), "she is stunned")
	combat.teleport_to(other, tile_away(foe.position, 1, other))
	await settle()
	other.ai_knows = K.WAKES_ALLIES
	await their_turn(other)
	await combat._ai_slap_awake(other)
	await settle()
	ok(not combat.has_restriction(foe, "skips_turn"), "a slap, and she is awake")
	ok(other.secondary_used_this_turn and not other.skill_used_this_turn, "for its secondary action")
	log_line("")


func reach_and_spreading():
	log_line("======== it avoids the party's reach, and spreads out ========")
	var foe: Dictionary = who("ranger")
	var enfina := who("enfina")
	foe.ai_knows = K.AVOIDS_REACH
	combat._ai_read_the_field(foe)
	ok(combat._ai_tile_worth(foe, tile_away(enfina.position, 1, foe)) < combat._ai_tile_worth(foe, tile_away(enfina.position, 30, foe)) or combat._ai_mind.reaches.size() > 0, "beside them is worse than far off")
	var beside: float = combat._ai_tile_worth(foe, tile_away(enfina.position, 1, foe))
	foe["ai_caution"] = 2.0
	ok(combat._ai_tile_worth(foe, tile_away(enfina.position, 1, foe)) < beside, "caution makes it worse still")
	foe["ai_caution"] = 1.0
	# Spreading: nothing until the other side has shown an area.
	foe.ai_knows = K.SPREADS_OUT
	var ally: Dictionary = who("barbarian")
	var next_to: Vector2i = tile_away(ally.position, 1, foe)
	combat._ai_read_the_field(foe)
	ok(combat._ai_tile_worth(foe, next_to) == 0.0, "bunched up is fine until an area has been shown")
	combat._areas_shown_by[0] = true
	combat._ai_read_the_field(foe)
	ok(combat._ai_tile_worth(foe, next_to) < 0.0, "and after that it is not")
	log_line("")


func set_ups():
	log_line("======== set-ups ========")
	var foe: Dictionary = who("ranger")
	var melee: Dictionary = who("barbarian")
	var target: Dictionary = who("enfina")
	var prone: ConditionDefinition = load("res://data/conditions/prone.tres")
	foe.ai_knows = K.SET_UPS
	# With the barbarian next and before the target: worth it.
	var f: int = combat.combatants.find(foe)
	var m: int = combat.combatants.find(melee)
	var t: int = combat.combatants.find(target)
	combat.turn_queue = [f, m, t]
	combat.turn = 0
	ok(combat._ai_set_up_worth(foe, target, prone) > 0.0, "knocking somebody down, with melee acting next, is worth it")
	combat.turn_queue = [f, t, m]
	ok(combat._ai_set_up_worth(foe, target, prone) < 0.0, "with them up before the blow comes, it is not")
	var burn: ConditionDefinition = load("res://data/conditions/burn.tres")
	ok(combat._ai_set_up_worth(foe, target, burn) == 0.0, "a burn sets nothing up")
	log_line("")


func hemming_and_blocking():
	log_line("======== hemming and blocking ========")
	var foe: Dictionary = who("barbarian")
	var enfina := who("enfina")
	var caster: Dictionary = who("sorcerer")
	foe.ai_knows = K.BLOCKS
	# Enfina a row from the sorcerer: the tile between them is worth standing on.
	var row: Vector2i = clear_row(foe.position, Vector2i.RIGHT, 5)
	ok(row != foe.position, "room to try it")
	combat.teleport_to(enfina, row)
	combat.teleport_to(caster, row + Vector2i.RIGHT * 4)
	await settle()
	combat._ai_read_the_field(foe)
	var between: Vector2i = row + Vector2i.RIGHT * 2
	ok(combat._ai_tile_worth(foe, between) > 0.0, "between their melee and its caster is worth standing on", "%.0f" % combat._ai_tile_worth(foe, between))
	ok(combat._ai_tile_worth(foe, row + Vector2i(2, 8)) == 0.0, "somewhere else is not")
	# Hemming: only for somebody who hems.
	foe.ai_knows = K.HEMS
	combat._ai_read_the_field(foe)
	ok(combat._ai_mind.hems == 0 and combat._ai_tile_worth(foe, row + Vector2i.UP) == 0.0, "nothing to hem with, nothing in it")
	combat._ai_mind.hems = 1
	combat._ai_mind.foes = [enfina.position]
	ok(combat._ai_tile_worth(foe, row + Vector2i.UP) > 0.0, "with a hem, a tile that hems somebody in is worth more")
	log_line("")


func triage():
	log_line("======== triage ========")
	var priest: Dictionary = who("sorcerer")
	var hurt: Dictionary = who("barbarian")
	var fragile: Dictionary = who("ranger")
	var enfina := who("enfina")
	# Somebody missing a great deal but in no danger; somebody missing little, about to fall.
	priest.skill_list.append("heal")
	priest.spell_slots[SkillDatabase.skills.heal.spell_slot_level] = 5
	hurt.hp = 300
	hurt.max_hp = 900
	combat.teleport_to(hurt, tile_away(enfina.position, 30, hurt))
	combat.teleport_to(fragile, tile_away(enfina.position, 1, fragile))
	await settle()
	var coming: float = combat._ai_blows_coming(fragile)
	var mends: float = float(combat.heal_amount(priest, SkillDatabase.skills.heal))
	ok(coming > 1.0 and mends > 1.0, "somebody means to hit them, and there is a heal", "%.0f coming, %.0f mended" % [coming, mends])
	fragile.max_hp = int(coming + mends) + 10
	fragile.hp = int(coming) - 1
	priest.ai_knows = 0
	ok(combat._ai_patient(priest) == hurt, "the untaught heal whoever is missing most")
	priest.ai_knows = K.TRIAGE
	ok(combat._ai_patient(priest) == fragile, "triage: whoever would otherwise fall next round", "%.0f coming" % coming)
	# Past mending: even whole, they would fall.
	fragile.max_hp = int(coming) - 1
	fragile.hp = int(coming) - 2
	ok(combat._ai_patient(priest) == hurt, "not somebody no heal would save")
	fragile.max_hp = int(coming + mends) + 10
	fragile.hp = 20
	# Conditions: not how many, but what they cost.
	var stunned: ConditionDefinition = load("res://data/conditions/stunned.tres")
	hurt.status_effects.clear()
	fragile.status_effects.clear()
	hurt.status_effects.append({"stat": "movement", "amount": -1, "op": "add", "duration": 3})
	hurt.status_effects.append({"stat": "movement", "amount": -1, "op": "add", "duration": 3})
	fragile.status_effects.append({"stat": "condition", "condition": stunned, "dot_base": 0.0, "duration": 2})
	priest.ai_knows = K.TRIAGE
	ok(combat._ai_most_afflicted(priest) == fragile, "and lifts what costs most, not whoever has most")
	# A zone of theirs held on a tether, with Dispel Magic to hand.
	var alithia := who("alithia")
	priest.skill_list.append("dispel_magic")
	priest.spell_slots[SkillDatabase.skills.dispel_magic.spell_slot_level] = 5
	await their_turn(alithia)
	alithia.spell_slots[SkillDatabase.skills.silence.spell_slot_level] = 5
	combat.teleport_to(priest, tile_away(alithia.position, 4, priest))
	combat.teleport_to(fragile, tile_away(priest.position, 1, fragile))
	await settle()
	await combat.use_skill("silence", alithia, priest.position + Vector2i.RIGHT * 2, false)
	await settle()
	var zoned: bool = not combat.zones.is_empty() and combat.zones[0].has("tether_of")
	if zoned:
		# Out of the silence itself, it can cast.
		var out: Vector2i = priest.position
		for tile in controller.get_reachable_tiles(priest.position, 0, 40, priest):
			if not tile in combat.zones[0].tiles and combat.can_land_on(priest, tile) and combat.get_position_distance(tile, combat.zones[0].centre) <= 6:
				out = tile
				break
		combat.teleport_to(priest, out)
		combat.sync_zones()
		await their_turn(priest)
		var count: int = combat.zones.size()
		var dispelled: bool = await combat._ai_dispel_a_zone(priest)
		await settle()
		ok(dispelled and combat.zones.size() < count, "and undoes a tether's zone, rather than healing through it", "%s" % dispelled)
	else:
		ok(false, "no zone was laid to test")
	log_line("")


func gates():
	log_line("======== gate economy ========")
	var foe: Dictionary = who("sorcerer")
	var target: Dictionary = who("enfina")
	combat.teleport_to(foe, tile_away(target.position, 4, foe))
	await settle()
	# Target all but dead: anything kills.
	target.hp = 1
	await their_turn(foe)
	foe.spell_slots = Stats.gates_for_level(64)
	var cheap := "fire_burst"
	var deep := "tartarus_flame"
	if not foe.skill_list.has(deep):
		foe.skill_list.append(deep)
	foe["level"] = 64
	foe.ai_knows = K.GATES
	var knows: Dictionary = combat.ai_plan_attack(foe, [cheap, deep], 0)
	ok(knows.skill != deep, "the cheapest blow that kills", knows.skill)
	var worth_of_deep: Dictionary = combat.ai_plan_attack(foe, [deep], 0)
	foe.ai_knows = 0
	var plain: Dictionary = combat.ai_plan_attack(foe, [deep], 0)
	if worth_of_deep.skill != "" and plain.skill != "":
		ok(worth_of_deep.score < plain.score, "a deep gate costs it something", "%.0f, %.0f" % [worth_of_deep.score, plain.score])
	else:
		ok(plain.skill == "" or worth_of_deep.skill == "", "a deep gate costs it something")
	log_line("")


func in_the_dark():
	log_line("======== in the dark ========")
	var foe: Dictionary = who("barbarian")
	foe.ai_knows = K.DARK
	foe.ai_function = "ai_melee_rush"
	var enfina := who("enfina")
	# Everybody out of its sight, somewhere it last saw one of them.
	var last: Vector2i = tile_away(foe.position, 6, foe)
	combat._ai_seen[1] = {enfina.id: last}
	var before: int = combat.get_position_distance(foe.position, last)
	await their_turn(foe)
	controller.movement = 3
	await combat._ai_search_the_dark(foe)
	await settle()
	ok(combat.get_position_distance(foe.position, last) < before, "it walks to where it last saw somebody", "%d from %d" % [combat.get_position_distance(foe.position, last), before])
	# Reaching it, it forgets.
	combat.teleport_to(foe, tile_away(last, 1, foe))
	await settle()
	await their_turn(foe)
	controller.movement = 3
	await combat._ai_search_the_dark(foe)
	await settle()
	ok(combat._ai_seen[1].is_empty(), "there, and nobody: it forgets", "%s" % [combat._ai_seen[1]])
	# With an area to throw there.
	var caster: Dictionary = who("sorcerer")
	caster.ai_knows = K.DARK
	await their_turn(caster)
	caster.spell_slots = Stats.gates_for_level(32)
	var spot: Vector2i = tile_away(caster.position, 4, caster)
	combat._ai_seen[1] = {enfina.id: spot}
	controller.movement = 0
	await combat._ai_search_the_dark(caster)
	await settle()
	ok(caster.skill_used_this_turn, "and throws an area there if it has one")
	log_line("")
	await open_fight()
	await towards_the_light()


func towards_the_light():
	log_line("======== nothing to go on ========")
	var foe: Dictionary = who("barbarian")
	foe.ai_knows = K.DARK
	var enfina := who("enfina")
	# Nothing to go on: towards the light.
	combat._ai_seen[1] = {}
	var lamp := LightSource.new()
	lamp.bright_tiles = 2.0
	lamp.dim_tiles = 3.0
	game.get_node("Terrain").add_child(lamp)
	var lit_at: Vector2i = tile_away(foe.position, 8, foe)
	lamp.global_position = game.get_node("Terrain/TileMap").to_global(game.get_node("Terrain/TileMap").map_to_local(lit_at))
	var encounter: EncounterDefinition = Campaign.current_encounter.duplicate()
	encounter.ambient = Light.Ambient.UNDERGROUND
	combat.encounter = encounter
	combat._begin_light()
	await settle()
	var gap: int = combat.get_position_distance(foe.position, lit_at)
	await their_turn(foe)
	controller.movement = 3
	await combat._ai_search_the_dark(foe)
	await settle()
	ok(combat.get_position_distance(foe.position, lit_at) < gap, "with nothing to go on, it makes for the light", "%d from %d" % [combat.get_position_distance(foe.position, lit_at), gap])
	log_line("")


func falling_back():
	log_line("======== falling back ========")
	var foe: Dictionary = who("barbarian")
	foe.ai_knows = K.FALLS_BACK
	foe["nerve"] = 60
	var priest: Dictionary = who("sorcerer")
	priest["ai_function"] = "ai_healer"
	combat.teleport_to(foe, tile_away(priest.position, 10, foe))
	await settle()
	foe.hp = foe.max_hp
	ok(not combat._ai_should_fall_back(foe), "whole, it holds its ground")
	foe.hp = int(foe.max_hp * 0.2)
	ok(combat._ai_should_fall_back(foe), "badly hurt, it goes", "%d of %d" % [combat.shaken(foe), foe.nerve])
	foe["ai_self_preservation"] = 0.1
	ok(not combat._ai_should_fall_back(foe), "not if it does not care for its skin")
	foe["ai_self_preservation"] = 1.0
	var healer: Dictionary = combat._ai_healer_of(foe)
	var gap: int = combat.get_position_distance(foe.position, healer.position)
	await their_turn(foe)
	controller.movement = 5
	await combat._ai_fall_back(foe)
	await settle()
	ok(combat.get_position_distance(foe.position, healer.position) < gap, "towards whoever mends", "%s, %d from %d" % [healer.name, combat.get_position_distance(foe.position, healer.position), gap])
	priest["ai_function"] = "ai_caster"
	foe.ai_knows = K.FALLS_BACK
	# Nobody to fall back on, it stands.
	for each in combat.combatants:
		if each != foe and each.get("side", -1) == 1:
			each["ai_function"] = "ai_melee_rush"
			each.skill_list = each.skill_list.filter(func(key): return SkillDatabase.skills.has(key) and not SkillDatabase.skills[key].all_effects().any(func(effect): return effect != null and effect.type == EffectDefinition.EffectType.HEAL))
	ok(not combat._ai_should_fall_back(foe), "with no healer it stands")
	log_line("")


## Whole turns, each with everything it knows, to see they come to an end.
func whole_turns():
	log_line("======== whole turns ========")
	var everything: int = 65535
	var prometheus := who("prometheus")
	prometheus.spell_slots[SkillDatabase.skills.burner.spell_slot_level] = 5
	await their_turn(prometheus)
	if combat.get_position_distance(prometheus.position, foes()[0].position) <= 8:
		await combat.use_skill("burner", prometheus, foes()[0].position, false)
	await settle()
	_answering = true
	_keep_answering()
	var finished := 0
	for foe in foes():
		foe.ai_knows = everything
		foe.hp = 900
		for each in combat.combatants:
			each.reaction_used = true
		var index: int = combat.combatants.find(foe)
		var last: int = combat.combatants.find(prometheus)
		combat.turn_queue = [last, index, last]
		combat.turn = 0
		combat.current_combatant = last
		await combat.advance_turn()
		await settle(4)
		if foe.get("turn_taken", false) or combat.get_current_combatant() == prometheus:
			finished += 1
	_answering = false
	ok(finished == foes().size(), "every kind of fighter, knowing everything, gets through its turn", "%d of %d" % [finished, foes().size()])
	log_line("")


var _answering := false


func _keep_answering():
	while _answering and is_inside_tree():
		if prompt != null and is_instance_valid(prompt) and prompt._waiting:
			prompt._answer_with(false)
		await get_tree().process_frame
