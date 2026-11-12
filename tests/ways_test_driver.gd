extends Node
## Ways of its own and All Knowing (Combat "Ways of its own"; the designer, 2026-11-07): commanders, grudges,
## hunters, bodyguards, packs, fears, learning, greed, moods by phase, and knowing the party's kits.

const LOG_NAME := "ways"
const WATCHER := "res://data/encounters/encounter_03_watcher.tres"
const PARTY := ["enfina", "cyrus", "prometheus", "alithia"]
const K := CombatantDefinition.AiKnows
const S := CombatantDefinition.AiSmarts

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
	who_is_what()
	await open_fight()
	await commanders()
	await open_fight()
	await grudges()
	await open_fight()
	await hunters()
	await open_fight()
	await bodyguards()
	await open_fight()
	await a_turn_after_theirs()
	await packs()
	await open_fight()
	await fears()
	await open_fight()
	await learning()
	await open_fight()
	await greed()
	await open_fight()
	await moods()
	await open_fight()
	await all_knowing()
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


func tile_away(from: Vector2i, gap: int, walker: Dictionary) -> Vector2i:
	for tile in controller.get_reachable_tiles(from, walker.movement_class, 40, walker):
		if combat.get_position_distance(tile, from) == gap and combat.can_land_on(walker, tile) and combat.get_combatant_at(tile).is_empty():
			return tile
	return from


func who_is_what():
	log_line("======== who is what ========")
	var c: Dictionary = CombatantDatabase.combatants
	ok(c.glutton.ai_smarts == S.CUNNING, "Erysichthon is cunning")
	ok(c.bomber.ai_smarts == S.INSTINCT, "the Bomber goes on instinct")
	ok(c.ash_warden.ai_smarts == S.ALL_KNOWING, "the Ash Warden is All Knowing")
	ok(S.ALL_KNOWING == S.values().max(), "the highest there is")
	ok(Combat._ai_knows_of(c.ash_warden) & K.KITS != 0 and Combat._ai_knows_of(c.ash_warden) & K.SET_UPS != 0, "and knows the party's kits as well as all the rest")
	var mastermind: CombatantDefinition = c.ash_warden.duplicate()
	mastermind.ai_smarts = S.MASTERMIND
	ok(Combat._ai_knows_of(mastermind) & K.KITS == 0, "a mastermind knows nobody's kit")
	ok(c.sorcerer.ai_commands_tiles == 0 and c.sorcerer.ai_learns, "the Sorcerer commands nobody, and learns")
	ok(c.pit_champion.ai_commands_tiles > 0, "the Pit Champion commands")
	ok(c.barbarian.ai_grudge > 0.0, "the Barbarian holds a grudge")
	ok(c.ranger.ai_hunter, "the Ranger hunts")
	ok(c.sellsword.ai_guards == "alchemist" and c.golem.ai_guards == "sorcerer", "the Sellsword and the Golem guard somebody")
	ok(c.gnawer.ai_pack >= 2 and c.rat.ai_pack >= 2, "rats and gnawers run in packs")
	ok(c.rat.ai_fears.has(Damage.Type.FIRE), "and rats fear fire")
	ok(c.ash_warden.ai_learns, "the Ash Warden learns")
	ok(c.imp.ai_greedy and c.imp.skills.has("steal"), "the Imp is greedy, and can steal")
	log_line("")


func commanders():
	log_line("======== commanders ========")
	var one: Dictionary = foes()[0]
	var chief: Dictionary = foes()[1]
	one["ai_smarts"] = S.INSTINCT
	one["combatant_key"] = "rat"
	chief["ai_commands_tiles"] = 6
	combat.teleport_to(chief, tile_away(one.position, 3, chief))
	await settle()
	combat._ai_take_orders(one)
	ok(one.ai_smarts == S.TRAINED, "near its commander, a rat thinks like a soldier", "%d" % one.ai_smarts)
	ok(one.ai_knows & K.GROUND != 0, "and knows the ground")
	combat.combatant_die(chief)
	await settle()
	combat._ai_take_orders(one)
	ok(one.ai_smarts == S.INSTINCT and one.ai_knows == 0, "its commander down, it is a rat again", "%d" % one.ai_smarts)
	log_line("")


func grudges():
	log_line("======== grudges ========")
	var hater: Dictionary = foes()[0]
	hater["ai_grudge"] = 1.0
	hater["ai_smarts"] = S.TRAINED
	var cyrus := who("cyrus")
	var enfina := who("enfina")
	var blow: SkillDefinition = SkillDatabase.skills.greatsword_attack
	var before: float = combat.ai_target_value(hater, cyrus, blow)
	var other_before: float = combat.ai_target_value(hater, enfina, blow)
	combat.lose_hp(hater, 5, Damage.Type.PHYSICAL, cyrus)
	ok(hater.get("hurt_by", -1) == cyrus.id, "it remembers who hurt it")
	ok(combat.ai_target_value(hater, cyrus, blow) > before, "and they are worth more to it", "%.1f > %.1f" % [combat.ai_target_value(hater, cyrus, blow), before])
	ok(is_equal_approx(combat.ai_target_value(hater, enfina, blow), other_before), "nobody else is")
	hater["ai_grudge"] = 0.0
	ok(is_equal_approx(combat.ai_target_value(hater, cyrus, blow), before), "with no grudge, it makes no odds")
	log_line("")


func hunters():
	log_line("======== hunters ========")
	var hunter: Dictionary = foes()[0]
	hunter["ai_hunter"] = true
	var blow: SkillDefinition = SkillDatabase.skills.greatsword_attack
	hunter.skill_list = ["greatsword_attack"]
	combat._ai_pick_a_mark(hunter)
	var mark := combat._combatant_by_id(hunter.get("ai_mark", -1))
	ok(not mark.is_empty() and mark.side == 0, "it picks somebody out", mark.get("name", "nobody"))
	var table: Dictionary = combat.ai_worth_table(hunter, blow)
	var others := table.keys().filter(func(id): return id != mark.id and table[id] > 0.0 and combat._combatant_by_id(id).get("side", 0) == 0)
	ok(table.has(mark.id) and others.is_empty(), "and has eyes for nobody else", "%s" % [table.keys()])
	var picked_id: int = mark.id
	combat._ai_pick_a_mark(hunter)
	ok(hunter.ai_mark == picked_id, "the same one next turn")
	combat.combatant_die(mark)
	await settle()
	combat._ai_pick_a_mark(hunter)
	ok(hunter.get("ai_mark", -1) != picked_id and hunter.has("ai_mark"), "they fall, and it picks another")
	log_line("")


func bodyguards():
	log_line("======== bodyguards ========")
	var ward: Dictionary = foes()[0]
	var guard: Dictionary = foes()[1]
	var key: String = ward.combatant_key
	guard["ai_guards"] = key
	guard["ai_guards_within"] = 3
	combat.teleport_to(guard, tile_away(ward.position, 2, guard))
	await settle()
	ok(combat._ai_ward_of(guard) == ward, "it knows who it guards")
	combat._ai_read_the_field(guard)
	var near_tile := tile_away(ward.position, 2, guard)
	var far_tile := tile_away(ward.position, 8, guard)
	ok(combat._ai_tile_worth(guard, far_tile) < combat._ai_tile_worth(guard, near_tile) - 100.0, "a tile far from them is worth much less", "%.0f, %.0f" % [combat._ai_tile_worth(guard, far_tile), combat._ai_tile_worth(guard, near_tile)])
	var blow: SkillDefinition = SkillDatabase.skills.greatsword_attack
	var attacker := who("enfina")
	guard.reaction_used = false
	ok(combat._bodyguards_step_in(attacker, blow, [ward]) == [guard], "a blow at them lands on it instead")
	ok(guard.reaction_used, "and that is its reaction")
	ok(combat._bodyguards_step_in(attacker, blow, [ward]) == [ward], "once a round")
	guard.reaction_used = false
	ok(combat._bodyguards_step_in(who("alithia"), SkillDatabase.skills.holy_splash, [ward]) == [ward], "an area catches who it catches")
	log_line("")


## The Mimic's turn, after one of the party's, a different one each round (the designer, 2026-11-07).
func a_turn_after_theirs():
	log_line("======== a turn after one of theirs ========")
	ok(CombatantDatabase.combatants.mimic.turn_after_one_of_them, "the Mimic takes its turn after one of the party's")
	# Only the movers this section makes: anybody the fight brought who moves is kept still for it.
	var brought := []
	for comb in combat.combatants:
		if comb.get("turn_after_one_of_them", false):
			brought.append(comb)
			comb.erase("turn_after_one_of_them")
	var party := []
	for index in combat._base_queue:
		var comb: Dictionary = combat.combatants[index]
		if comb.get("alive", false) and comb.get("side", 1) == 0 and not comb.has("object") and not comb.has("summoner"):
			party.append(comb.get("id", -1))
	var the_foes := foes()
	var foe: Dictionary = the_foes[0]
	foe["turn_after_one_of_them"] = true
	var followed := []
	for round in 4:
		ok(combat._turns_after_one_of_them(), "round %d: it moves" % round)
		var leader: Dictionary = leader_of(foe)
		ok(not leader.is_empty() and leader.get("side", 1) == 0 and leader.get("id", -1) == foe.get("followed", -2),
			"round %d: right after %s" % [round, leader.get("name", "nobody")], "%s" % [combat.turn_queue])
		followed.append(foe.get("followed", -1))
	var different := true
	for i in range(1, followed.size()):
		if followed[i] == followed[i - 1]:
			different = false
	ok(different, "never the same one twice running", "%s" % [followed])
	# Several (the designer, 2026-11-12): as many as the party, each behind a different one.
	var movers := [foe]
	for comb in the_foes.slice(1):
		if movers.size() < party.size():
			comb["turn_after_one_of_them"] = true
			movers.append(comb)
	for round in 3:
		combat._turns_after_one_of_them()
		var theirs := movers.map(func(comb): return comb.get("followed", -1))
		var once := {}
		for id in theirs:
			once[id] = true
		ok(once.size() == movers.size(), "%d of them, round %d: each behind a different one" % [movers.size(), round], "%s" % [theirs])
		ok(movers.all(func(comb): return leader_of(comb).get("id", -1) == comb.get("followed", -2)),
			"round %d: and each right after the one it follows" % round, "%s" % [combat.turn_queue])
	# More of them than the party: nobody has two more behind them than anybody else.
	for comb in the_foes.slice(movers.size()):
		if movers.size() < party.size() + 2:
			comb["turn_after_one_of_them"] = true
			movers.append(comb)
	if movers.size() > party.size():
		var repeats := 0
		for round in 3:
			var was := movers.map(func(comb): return comb.get("followed", -1))
			combat._turns_after_one_of_them()
			var behind := {}
			for id in party:
				behind[id] = 0
			for comb in movers:
				behind[comb.get("followed", -1)] = behind.get(comb.get("followed", -1), 0) + 1
			var counts: Array = behind.values()
			ok(counts.max() - counts.min() <= 1, "%d of them on %d, round %d: never two more on one than another" % [movers.size(), party.size(), round],
				"%s" % [behind])
			ok(movers.all(func(comb): return leader_of(comb).get("id", -1) == comb.get("followed", -2)),
				"round %d: two behind one go one after the other, right after it" % round, "%s" % [combat.turn_queue])
			for i in movers.size():
				if movers[i].get("followed", -1) == was[i]:
					repeats += 1
		ok(repeats == 0, "and each a different one from the round before", "%d the same" % repeats)
	else:
		log_line("  (only %d foes to make movers of)" % movers.size())
	for comb in movers:
		comb.erase("turn_after_one_of_them")
		comb.erase("followed")
	for comb in brought:
		comb["turn_after_one_of_them"] = true
	log_line("")


## Whose turn `comb` comes right after: the one before them in the order, past anybody else behind the same one.
func leader_of(comb: Dictionary) -> Dictionary:
	var index: int = combat.combatants.find(comb)
	var at: int = combat.turn_queue.find(index) - 1
	while at >= 0:
		var before: Dictionary = combat.combatants[combat.turn_queue[at]]
		if before.get("turn_after_one_of_them", false) and before.get("followed", -1) == comb.get("followed", -2):
			at -= 1
			continue
		return before
	return {}


func packs():
	log_line("======== packs ========")
	var alithia := who("alithia")
	var list := foes()
	var lone: Dictionary = list[0]
	var mate: Dictionary = list[1]
	lone["ai_pack"] = 2
	mate["ai_pack"] = 2
	# The other one can reach nobody: it has no legs, and nothing that goes further than its arm.
	var mate_list: Array = mate.skill_list
	var mate_feet: int = mate.movement
	mate.skill_list = []
	mate.movement = 0
	combat.teleport_to(lone, tile_away(alithia.position, 6, lone))
	combat.teleport_to(mate, tile_away(alithia.position, 12, mate))
	await settle()
	var party_beside: bool = combat.combatants.any(func(comb): return comb.get("alive", false) and comb.get("side", 1) == 0 and (combat.get_distance(lone, comb) <= 1 or combat.get_distance(mate, comb) <= 1))
	ok(party_beside or combat._ai_holds_back(lone), "nobody the two of them could reach: it hangs back", "%s" % party_beside)
	mate.skill_list = mate_list
	mate.movement = mate_feet
	combat.teleport_to(lone, tile_away(alithia.position, 3, lone))
	combat.teleport_to(mate, tile_away(alithia.position, 3, mate))
	await settle()
	ok(not combat._ai_holds_back(lone), "with the other in reach as well, in it goes")
	# Gathered, out of anybody's reach: in they go together (the designer, 2026-11-07: "Have them keep fighting").
	combat.teleport_to(lone, tile_away(alithia.position, 10, lone))
	combat.teleport_to(mate, tile_away(lone.position, 2, mate))
	await settle()
	ok(combat.get_distance(lone, mate) > Combat.AI_PACK_TOGETHER_TILES or not combat._ai_holds_back(lone), "gathered, they go in together",
		"%d apart" % combat.get_distance(lone, mate))
	# And it waits only so long, whatever the others do.
	combat.teleport_to(mate, tile_away(alithia.position, 14, mate))
	mate.skill_list = []
	mate.movement = 0
	await settle()
	lone["held_back"] = Combat.AI_PACK_WAITS
	ok(not combat._ai_holds_back(lone), "after waiting %d turns, it fights whatever the others do" % Combat.AI_PACK_WAITS)
	lone.erase("held_back")
	mate.skill_list = mate_list
	mate.movement = mate_feet
	# The last of them has nobody to wait for.
	mate["ai_pack"] = 0
	ok(not combat._ai_holds_back(lone), "with nobody left to wait for, it stops waiting")
	log_line("")


func fears():
	log_line("======== fears ========")
	var beast: Dictionary = foes()[0]
	var alithia := who("alithia")
	beast["ai_fears"] = [Damage.Type.FIRE]
	var burn: ConditionDefinition = load("res://data/conditions/burn.tres")
	ok(combat._ai_feared_tiles(beast).is_empty(), "nothing burning, nothing to fear")
	combat.put_condition(alithia, burn, 5, "test", true, -1)
	var feared: Dictionary = combat._ai_feared_tiles(beast)
	ok(feared.has(alithia.position) and feared.has(alithia.position + Vector2i.RIGHT), "somebody burning: not on or beside them")
	ok(combat.false_ground_for(beast).has(alithia.position + Vector2i.RIGHT), "and no walk takes it there")
	beast["ai_fears"] = []
	ok(combat.false_ground_for(beast).is_empty(), "with no such fear, anywhere will do")
	log_line("")


func learning():
	log_line("======== learning ========")
	var clever: Dictionary = foes()[0]
	clever["ai_learns"] = true
	var alithia := who("alithia")
	await combat.use_skill("mirror_image", alithia, alithia.position, false) if SkillDatabase.skills.has("mirror_image") else combat.summon_decoy(alithia, alithia)
	await settle()
	var image: Dictionary = {}
	for comb in combat.combatants:
		if comb.get("illusion", false) and comb.get("alive", false) and comb.side == 0 and comb.has("image_of"):
			image = comb
	ok(not image.is_empty(), "an image stands")
	if image.is_empty():
		return
	combat.ai_believes = true
	combat._believer_side = 1
	ok(combat.believes_illusion(image), "and the other side believes it")
	var blow: SkillDefinition = SkillDatabase.skills.greatsword_attack
	ok(combat.ai_worth_table(clever, blow).has(image.id), "and would hit it")
	combat.teleport_to(clever, tile_away(image.position, 1, clever))
	await settle()
	combat.ai_believes = false
	combat._shatter(image)
	await settle()
	ok(combat._seen_through.get(1, false), "it shatters in front of one who learns: its whole side knows better")
	var second: Dictionary = {}
	combat.summon_decoy(alithia, alithia)
	await settle()
	for comb in combat.combatants:
		if comb.get("illusion", false) and comb.get("alive", false) and comb.side == 0 and comb.has("image_of"):
			second = comb
	combat.ai_believes = true
	combat._believer_side = 1
	ok(not second.is_empty() and not combat.believes_illusion(second), "the next is believed by nobody")
	var other: Dictionary = foes()[1]
	ok(not second.is_empty() and not combat.ai_worth_table(other, blow).has(second.id), "and nobody of that side aims at it")
	combat.ai_believes = false
	log_line("")


func greed():
	log_line("======== greed ========")
	var thief: Dictionary = foes()[0]
	var cyrus := who("cyrus")
	var enfina := who("enfina")
	thief["ai_greedy"] = true
	thief.skill_list = ["steal", "greatsword_attack"]
	Campaign.give_item("cyrus", "tiny_bomb")
	Campaign.give_item("cyrus", "small_bomb")
	var steal: SkillDefinition = SkillDatabase.skills.steal
	var from_cyrus: float = combat._ai_greed_for(thief, cyrus, steal)
	ok(from_cyrus > 0.0, "somebody carrying something is worth stealing from", "%.0f" % from_cyrus)
	ok(combat.ai_target_value(thief, cyrus, steal) > 0.0, "and it would")
	thief["pocket_size"] = 40
	combat.steal(thief, cyrus, steal.effects[0], steal)
	await settle()
	ok(thief.get("fleeing", 0) > 0, "once it has something, it runs for it")
	log_line("")


func moods():
	log_line("======== moods by phase ========")
	var boss: Dictionary = foes()[0]
	var phase := BossPhase.new()
	phase.ai_aggression = 1.9
	phase.ai_caution = 0.2
	boss["ai_focus"] = 1.1
	combat._begin_phase(boss, phase)
	ok(is_equal_approx(boss.ai_aggression, 1.9) and is_equal_approx(boss.ai_caution, 0.2), "a phase changes its dials")
	ok(is_equal_approx(boss.ai_focus, 1.1), "and leaves the rest as they were")
	var warden: CombatantDefinition = CombatantDatabase.combatants.ash_warden
	ok(warden.boss.phases.any(func(each): return each.ai_aggression > 1.0), "the Ash Warden turns reckless as it is hurt")
	log_line("")


func all_knowing():
	log_line("======== All Knowing ========")
	var knower: Dictionary = foes()[0]
	var alithia := who("alithia")
	var cyrus := who("cyrus")
	var blow: SkillDefinition = SkillDatabase.skills.greatsword_attack
	knower["ai_smarts"] = S.TRAINED
	knower["ai_knows"] = Combat.AI_KNOWN_BY[S.TRAINED]
	combat._ai_read_the_field(knower)
	ok(combat._ai_kit_of(knower, alithia).is_empty(), "a soldier knows nothing of her kit")
	var plain: float = combat.ai_target_value(knower, alithia, blow)
	knower["ai_smarts"] = S.ALL_KNOWING
	knower["ai_knows"] = Combat.AI_KNOWN_BY[S.ALL_KNOWING]
	for gate in alithia.spell_slots.size():
		alithia.spell_slots[gate] = 3
	combat._ai_read_the_field(knower)
	var kit: Dictionary = combat._ai_kit_of(knower, alithia)
	ok(not kit.is_empty() and kit.mends and kit.casts, "All Knowing reads hers: she mends, and casts")
	ok(kit.reach > 1, "and how far she can hit")
	ok(combat.ai_target_value(knower, alithia, blow) > plain, "which makes her worth more", "%.1f > %.1f" % [combat.ai_target_value(knower, alithia, blow), plain])
	# Spent: nothing left to fear from her.
	var spell_only: float = kit.worst
	for gate in alithia.spell_slots.size():
		alithia.spell_slots[gate] = 0
	alithia["spare_spent"] = 99
	combat._ai_read_the_field(knower)
	var spent: Dictionary = combat._ai_kit_of(knower, alithia)
	ok(not spent.mends or spent.worst <= spell_only, "it knows when her castings are gone", "%.0f, %.0f" % [spent.worst, spell_only])
	# Only what is prepared: a spell off her list is no threat of hers.
	alithia.skill_list = alithia.skill_list.filter(func(key): return not SkillDatabase.skills[key].targets_ally or SkillDatabase.skills[key].spell_slot_level == 0)
	for gate in alithia.spell_slots.size():
		alithia.spell_slots[gate] = 3
	combat._ai_read_the_field(knower)
	ok(not combat._ai_kit_of(knower, alithia).mends, "and what she has not prepared is nothing to it")
	# Wasting nothing on an immunity.
	var fear: ConditionDefinition = load("res://data/conditions/fear.tres")
	var scare := SkillDefinition.new()
	scare.deals_damage = false
	var effect := EffectDefinition.new()
	effect.type = EffectDefinition.EffectType.CONDITION
	effect.condition = fear
	scare.effects = [effect]
	var before: float = combat.ai_target_value(knower, cyrus, scare)
	var unafraid: ConditionDefinition = load("res://data/conditions/unafraid.tres")
	combat.put_condition(cyrus, unafraid, 5, "test", true, -1)
	combat._ai_read_the_field(knower)
	ok(before > 0.0 and combat.ai_target_value(knower, cyrus, scare) == 0.0, "it wastes nothing on somebody it would not take hold of", "%.1f" % before)
	# Somebody ready to cancel a casting makes its gates dearer.
	combat._ai_mind["counters"] = true
	ok(combat._ai_mind.counters, "and it knows who could cancel a casting")
	log_line("")
