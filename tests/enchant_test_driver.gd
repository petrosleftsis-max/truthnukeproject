extends Node
## Alithia's enchantments (the designer, 2026-11-05): Compel gives an order the target
## spends its next turn on and nothing else; Steady Heart is four turns of no Fear;
## Mesmerise stuns who loses in an area, Ecstasy downs and stuns one, each for as long
## as the tether holds; Silence is ground no spell is cast on. Every tether's size is
## in the preview, and a passive can make somebody immune as they reach its level.

const LOG_NAME := "enchant"
const WATCHER := "res://data/encounters/encounter_03_watcher.tres"
const PARTY := ["enfina", "cyrus", "alithia"]
const STUNNED := preload("res://data/conditions/stunned.tres")
const FEAR := preload("res://data/conditions/fear.tres")
const SILENCED := preload("res://data/conditions/silenced.tres")
const COMPELLED := preload("res://data/conditions/compelled.tres")

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
	get_tree().create_timer(200.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await settle()
	var booted = get_tree().current_scene
	if booted != null:
		booted.queue_free()
		await settle()
	await open_fight()
	await her_kit()
	await compel()
	await compel_each_order()
	await compel_on_the_immune_and_the_winner()
	await compel_by_the_ai()
	await open_fight()
	await steady_heart()
	await mesmerise()
	await open_fight()
	await ecstasy()
	await open_fight()
	await silence()
	await open_fight()
	await the_preview()
	await a_passive_grows()
	await close_fight()
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


func open_fight():
	await close_fight()
	Campaign.reset()
	Campaign.set_party(PARTY, 14)
	Campaign.current_map = "res://maps/crossroads_explore.tscn"
	Campaign.return_to_position = true
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
	# Nobody at the keyboard: the reactions of others are spent, so none goes off.
	for comb in combat.combatants:
		comb.reaction_used = true


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


## The enemies, in the order they stand, with no will to speak of.
func foes() -> Array:
	var found := []
	for comb in combat.combatants:
		if comb.side == 1 and comb.alive and not comb.has("object") and not comb.has("summoner") and not comb.get("illusion", false):
			comb.stats["mindfulness"] = 1
			found.append(comb)
	return found


func their_turn(comb: Dictionary):
	combat.current_combatant = combat.combatants.find(comb)
	comb.skill_used_this_turn = false
	comb.secondary_used_this_turn = false
	controller.set_controlled_combatant(comb)
	await settle()


## Plays the real turn of `comb`, handed over by whoever is `before` them.
func real_turn(before: Dictionary, comb: Dictionary):
	# Nobody at the keyboard to be asked about a reaction.
	for each in combat.combatants:
		each.reaction_used = true
	var b: int = combat.combatants.find(before)
	var c: int = combat.combatants.find(comb)
	combat.turn_queue = [b, c, b]
	combat.turn = 0
	combat.current_combatant = b
	await combat.advance_turn()
	await settle(4)


## Answers the next question put up with button `index`, once it is up.
func answer_with(index: int):
	for i in 600:
		if prompt.is_asking() and prompt._waiting:
			prompt._choose(index)
			return
		await get_tree().process_frame


## A free tile `gap` from `from`, clear to walk to, on the same ground.
func tile_away(from: Vector2i, gap: int, walker: Dictionary) -> Vector2i:
	for tile in controller.get_reachable_tiles(from, walker.movement_class, 40, walker):
		if combat.get_position_distance(tile, from) == gap and combat.can_land_on(walker, tile) and combat.get_combatant_at(tile).is_empty():
			return tile
	return from


func her_kit():
	log_line("======== Alithia's new spells ========")
	var alithia := who("alithia")
	for key in ["compel", "steady_heart", "ecstasy", "silence", "mesmerise"]:
		ok(alithia.skill_list.has(key), "she has %s" % key)
	var skills: Dictionary = SkillDatabase.skills
	ok(skills.compel.spell_slot_level == 1 and skills.compel.uses_stat_contest and skills.compel.contest_stat == Stats.Type.MINDFULNESS, "Compel: World, a contest of Mindfulness")
	ok(skills.steady_heart.spell_slot_level == 1 and skills.steady_heart.targets_ally and skills.steady_heart.effects[0].condition_duration == 4, "Steady Heart: World, on an ally, 4 turns")
	ok(skills.ecstasy.spell_slot_level == 1 and skills.ecstasy.tether_strength == 200 and skills.ecstasy.tethered, "Ecstasy: World, tether 200")
	ok(skills.silence.spell_slot_level == 2 and skills.silence.tether_strength == 400 and skills.silence.tethered, "Silence: Hermes, tether 400")
	ok(skills.mesmerise.spell_slot_level == 3 and skills.mesmerise.tether_strength == 200 and skills.mesmerise.tethered and skills.mesmerise.contest_stat == Stats.Type.INTELLECT and skills.mesmerise.aoe_radius > 0,
		"Mesmerise: Pandora, an area contesting Intellect, tether 200")
	log_line("")


func compel():
	log_line("======== Compel: she gives the order, as it lands ========")
	var alithia := who("alithia")
	var foe: Dictionary = foes()[0]
	combat.teleport_to(foe, tile_away(alithia.position, 3, foe))
	await their_turn(alithia)
	var gates: int = alithia.spell_slots[1]
	answer_with(3)
	await combat.use_skill("compel", alithia, foe.position, false)
	await settle()
	ok(alithia.spell_slots[1] == gates - 1, "a World casting spent", "%s" % [alithia.spell_slots])
	ok(combat.has_restriction(foe, "obeys_order"), "the one who lost is Compelled")
	ok(combat._order_on(foe).get("order") == Combat.Order.NOTHING, "under the order she chose")
	ok(not prompt.is_asking(), "and the question is gone")
	log_line("")


func compel_each_order():
	log_line("======== each order, on the turn it was for ========")
	var alithia := who("alithia")
	var the_foes := foes()
	var foe: Dictionary = the_foes[0]
	# Nothing: the turn ends with nothing done.
	foe.status_effects = []
	combat.teleport_to(foe, tile_away(alithia.position, 3, foe))
	await their_turn(alithia)
	answer_with(3)
	await combat.use_skill("compel", alithia, foe.position, false)
	await settle()
	var hp_before: int = alithia.hp
	var from: Vector2i = foe.position
	var slots: Array = foe.get("spell_slots", []).duplicate()
	await real_turn(alithia, foe)
	ok(foe.position == from and alithia.hp == hp_before and foe.get("spell_slots", []) == slots, "Do Nothing: nothing", "%s" % foe.position)
	ok(combat.current_combatant != combat.combatants.find(foe) or foe.turn_taken, "and its turn is over")
	ok(not combat.has_restriction(foe, "obeys_order"), "and the order is spent")

	# Come to me: all the way it can get, and no blow when it arrives.
	var far := tile_away(alithia.position, 4, foe)
	combat.teleport_to(foe, far)
	await their_turn(alithia)
	alithia.spell_slots[1] = 3
	answer_with(0)
	await combat.use_skill("compel", alithia, foe.position, false)
	await settle()
	hp_before = alithia.hp
	await real_turn(alithia, foe)
	ok(combat.get_position_distance(foe.position, alithia.position) == 1, "Come To Me: beside her", "%s, %s" % [foe.position, alithia.position])
	ok(alithia.hp == hp_before, "and it does not strike", "%d" % alithia.hp)

	# Go away: as far as it can get.
	await their_turn(alithia)
	alithia.spell_slots[1] = 3
	answer_with(1)
	await combat.use_skill("compel", alithia, foe.position, false)
	await settle()
	var furthest := 0
	var reach: Dictionary = controller.get_reachable_tiles(foe.position, foe.movement_class, combat._whole_movement(foe), foe)
	for tile in reach:
		furthest = maxi(furthest, combat.get_position_distance(tile, alithia.position))
	hp_before = alithia.hp
	await real_turn(alithia, foe)
	ok(combat.get_position_distance(foe.position, alithia.position) == furthest, "Go Away: as far from her as it could get", "%d" % furthest)
	ok(alithia.hp == hp_before and combat.get_combatant_at(foe.position) == foe, "on a tile of its own, and it does not strike")

	# Fall prone.
	await their_turn(alithia)
	alithia.spell_slots[1] = 3
	answer_with(2)
	combat.teleport_to(foe, tile_away(alithia.position, 3, foe))
	await combat.use_skill("compel", alithia, foe.position, false)
	await settle()
	from = foe.position
	await real_turn(alithia, foe)
	ok(combat.is_prone(foe) and foe.position == from, "Fall Prone: down where it stood")

	# Down already, it gets up first to do what it was told.
	await their_turn(alithia)
	alithia.spell_slots[1] = 3
	answer_with(0)
	await combat.use_skill("compel", alithia, foe.position, false)
	await settle()
	var gap_before: int = combat.get_position_distance(foe.position, alithia.position)
	await real_turn(alithia, foe)
	ok(not combat.is_prone(foe) and combat.get_position_distance(foe.position, alithia.position) < gap_before, "down, it gets up to come to her")
	log_line("")


func compel_on_the_immune_and_the_winner():
	log_line("======== who it does not take ========")
	var alithia := who("alithia")
	var the_foes := foes()
	var foe: Dictionary = the_foes[1] if the_foes.size() > 1 else the_foes[0]
	await their_turn(alithia)
	alithia.spell_slots[1] = 3
	combat.teleport_to(foe, tile_away(alithia.position, 3, foe))
	foe.stats["mindfulness"] = 999
	await combat.use_skill("compel", alithia, foe.position, false)
	await settle()
	ok(not prompt.is_asking(), "winning the contest, no question is asked")
	ok(not combat.has_restriction(foe, "obeys_order"), "and it obeys nothing")
	foe.stats["mindfulness"] = 1
	foe["immune_conditions"] = [COMPELLED.resource_path]
	await their_turn(alithia)
	await combat.use_skill("compel", alithia, foe.position, false)
	await settle()
	ok(not prompt.is_asking() and not combat.has_restriction(foe, "obeys_order"), "and nor does one immune to it, who is asked about by nobody")
	foe["immune_conditions"] = []
	log_line("")


func compel_by_the_ai():
	log_line("======== in the AI's hands ========")
	var alithia := who("alithia")
	var foe: Dictionary = foes()[0]
	ok(combat._ai_order(foe, alithia) in [Combat.Order.FALL_PRONE, Combat.Order.NOTHING], "the AI gives an order without asking anybody")
	# An enemy's order on one of the party plays their turn for them.
	combat.put_condition(alithia, COMPELLED, 1, "test")
	alithia.status_effects.back()["order"] = Combat.Order.NOTHING
	alithia.status_effects.back()["order_by"] = foe.get("id", -1)
	var other := who("cyrus")
	var from: Vector2i = alithia.position
	await real_turn(other, alithia)
	ok(alithia.position == from and not combat.has_restriction(alithia, "obeys_order"), "on the party's side, the same: played for them, and over")
	log_line("")


func steady_heart():
	log_line("======== Steady Heart ========")
	var alithia := who("alithia")
	var enfina := who("enfina")
	combat.put_condition(enfina, FEAR, 3, "test")
	ok(combat.has_restriction(enfina, "prevents_approach"), "Enfina is afraid")
	combat.teleport_to(enfina, tile_away(alithia.position, 2, enfina))
	await their_turn(alithia)
	await combat.use_skill("steady_heart", alithia, enfina.position, false)
	await settle()
	ok(not combat.has_restriction(enfina, "prevents_approach"), "the fear she had goes")
	ok(combat.immune_to_condition(enfina, FEAR), "and she is immune to it")
	ok(not combat.put_condition(enfina, FEAR, 2, "test", true) and not combat.has_restriction(enfina, "prevents_approach"), "so a new one does not take")
	for i in 3:
		combat.end_of_turn_effects(enfina)
	ok(combat.immune_to_condition(enfina, FEAR), "still immune after three of her turns")
	combat.end_of_turn_effects(enfina)
	ok(not combat.immune_to_condition(enfina, FEAR), "and not after the fourth")
	log_line("")


func mesmerise():
	log_line("======== Mesmerise ========")
	var alithia := who("alithia")
	var the_foes := foes()
	var strong: Dictionary = the_foes[1]
	var weak: Dictionary = the_foes[0]
	strong.stats["intellect"] = 999
	weak.stats["intellect"] = 1
	combat.teleport_to(weak, tile_away(alithia.position, 4, weak))
	var beside := tile_away(weak.position, 1, strong)
	combat.teleport_to(strong, beside)
	await their_turn(alithia)
	alithia.spell_slots[3] = 2
	await combat.use_skill("mesmerise", alithia, weak.position, false)
	await settle()
	ok(combat.has_restriction(weak, "skips_turn"), "who loses to her Intellect is stunned")
	ok(not combat.has_restriction(strong, "skips_turn"), "who beats it is not")
	ok(Combat.holds_tether(alithia) and alithia.tether.max == 200.0, "held on a tether of 200", "%s" % [alithia.get("tether")])
	# It lasts as long as the tether does, not a count of turns.
	for i in 10:
		combat.end_of_turn_effects(weak)
	ok(combat.has_restriction(weak, "skips_turn"), "ten of their turns on, still stunned")
	combat.fray_tether(alithia, 25.0, "test")
	ok(Combat.holds_tether(alithia) and combat.has_restriction(weak, "skips_turn"), "frayed, it holds")
	combat.snap_tether(alithia, "test")
	ok(not combat.has_restriction(weak, "skips_turn"), "snapped, they are free")
	log_line("")


func ecstasy():
	log_line("======== Ecstasy ========")
	var alithia := who("alithia")
	var foe: Dictionary = foes()[0]
	combat.teleport_to(foe, tile_away(alithia.position, 3, foe))
	await their_turn(alithia)
	await combat.use_skill("ecstasy", alithia, foe.position, false)
	await settle()
	ok(combat.is_prone(foe), "down")
	ok(combat.has_restriction(foe, "skips_turn"), "and stunned")
	ok(alithia.tether.max == 200.0, "on a tether of 200")
	var from: Vector2i = foe.position
	await real_turn(alithia, foe)
	ok(foe.position == from and combat.is_prone(foe) and combat.has_restriction(foe, "skips_turn"), "its turn comes and goes, and it lies there")
	# Two hundred, at 25 a turn of hers: gone as her eighth turn begins. That turn of its
	# was followed by her first.
	ok(Combat.holds_tether(alithia) and alithia.tether.bar == 175.0, "one of her turns: it holds, with 175 left", "%s" % [alithia.get("tether")])
	for turn in 7:
		combat._tether_turn(alithia)
	ok(not Combat.holds_tether(alithia), "eight: worn through")
	ok(not combat.has_restriction(foe, "skips_turn"), "the stun goes with it")
	ok(combat.is_prone(foe), "and it is still down: getting up is its own to do")
	# Somebody immune to Prone is only stunned (Erysichthon).
	combat._stand(foe)
	foe["immune_conditions"] = [Combat.PRONE.resource_path]
	await their_turn(alithia)
	alithia.spell_slots[1] = 3
	await combat.use_skill("ecstasy", alithia, foe.position, false)
	await settle()
	ok(not combat.is_prone(foe) and combat.has_restriction(foe, "skips_turn"), "immune to Prone: stunned, on its feet")
	combat.snap_tether(alithia, "test")
	foe["immune_conditions"] = []
	# Something in the air cannot be knocked down, and is still stunned.
	foe["movement_class"] = 1
	await their_turn(alithia)
	alithia.spell_slots[1] = 3
	await combat.use_skill("ecstasy", alithia, foe.position, false)
	await settle()
	ok(not combat.is_prone(foe) and combat.has_restriction(foe, "skips_turn"), "in the air: stunned, not down")
	foe["movement_class"] = 0
	combat.snap_tether(alithia, "test")
	log_line("")


func silence():
	log_line("======== Silence ========")
	var alithia := who("alithia")
	var foe: Dictionary = foes()[0]
	var heal: SkillDefinition = SkillDatabase.skills.heal
	await their_turn(alithia)
	var there := tile_away(alithia.position, 5, foe)
	var gates: int = alithia.spell_slots[2]
	await combat.use_skill("silence", alithia, there, false)
	await settle()
	ok(alithia.spell_slots[2] == gates - 1, "a Hermes casting spent", "%s" % [alithia.spell_slots])
	ok(combat.zones.size() == 1 and combat.zones[0]["for"] == 2, "ground that holds anybody")
	ok(Combat.holds_tether(alithia) and alithia.tether.max == 400.0, "on a tether of 400, though it landed on nobody", "%s" % [alithia.get("tether")])
	# Somebody standing in it.
	combat.teleport_to(foe, there)
	combat.sync_zones()
	ok(combat.has_restriction(foe, "prevents_spells"), "whoever stands in it is Silenced")
	ok(not combat.can_afford_skill(foe, heal), "and cannot cast")
	ok(combat.wasted_on(foe, heal).contains("cannot cast"), "and the panel can say why", combat.wasted_on(foe, heal))
	ok(combat.can_afford_skill(foe, SkillDatabase.skills.gun if SkillDatabase.skills.has("gun") else SkillDatabase.skills.greatsword_attack), "though a blow is as good as ever")
	# A nade is thrown, not cast.
	ok(combat.can_afford_skill(foe, ItemDatabase.item("heal_gate_nade")), "and a Gate Nade is thrown, not cast")
	# Cast anyway, it comes to nothing and costs nothing.
	foe.spell_slots = [0, 2, 0, 0]
	combat.current_combatant = combat.combatants.find(foe)
	await combat.use_skill("heal", foe, foe.position, false)
	await settle()
	ok(foe.spell_slots[1] == 2, "casting anyway, nothing is spent", "%s" % [foe.spell_slots])
	# Her own side too.
	combat.teleport_to(alithia, tile_away(there, 1, alithia))
	combat.sync_zones()
	ok(not combat.can_afford_skill(alithia, heal), "her side too, standing in it")
	# Stepping out.
	combat.teleport_to(foe, tile_away(there, 6, foe))
	combat.sync_zones()
	ok(combat.can_afford_skill(foe, heal) and not combat.has_restriction(foe, "prevents_spells"), "stepping out, they can again")
	# A turn of hers does not run it out while the tether holds.
	var turns: int = combat.zones[0].turns
	combat._zones_at_turn_start(alithia)
	ok(combat.zones.size() == 1 and combat.zones[0].turns == turns, "a turn of hers takes nothing off the ground: the tether's its time")
	# A readied spell comes to nothing there.
	alithia["readied"] = {"skill": "heal", "trigger": SkillDefinition.Trigger.CASTS}
	await combat._fire_readied(alithia, foe, "test")
	ok(not alithia.has("readied"), "a readied spell dies with nobody hurt or healed")
	combat.snap_tether(alithia, "test")
	ok(combat.zones.is_empty(), "the tether gone, the ground goes")
	ok(not combat.has_restriction(alithia, "prevents_spells") and combat.can_afford_skill(alithia, heal), "and she can cast again")
	# Taken off by Dispel Magic, the tether has nothing left to hold.
	await their_turn(alithia)
	alithia.spell_slots[2] = 2
	await combat.use_skill("silence", alithia, there, false)
	await settle()
	ok(Combat.holds_tether(alithia), "laid again")
	combat._zone_fades(combat.zones[0], "is dispelled")
	ok(not Combat.holds_tether(alithia), "ended by somebody else, she lets go of the tether")
	log_line("")


func the_preview():
	log_line("======== the tether in every preview ========")
	var alithia := who("alithia")
	await their_turn(alithia)
	var skills: Dictionary = SkillDatabase.skills
	var said: String = ui.build_skill_tooltip(skills.ecstasy, alithia)
	ok(said.contains("Tether: 200"), "Ecstasy's tooltip says 200", said)
	ok(said.contains("for as long as the tether holds"), "and how long what it does lasts")
	ok(said.contains("until they get up"), "and that the Prone lasts till they get up")
	ok(ui.build_skill_tooltip(skills.silence, alithia).contains("Tether: 400"), "Silence's says 400")
	ok(ui.build_skill_tooltip(skills.mesmerise, alithia).contains("Tether: 200"), "Mesmerise's says 200")
	ok(ui.build_skill_tooltip(skills.bewilder, alithia).contains("Tether: 200"), "Bewilder's, a spell of the designer's, says 200")
	ok(ui.build_skill_tooltip(skills.illusory_dragon, who("cyrus")).contains("Tether: %d" % skills.illusory_dragon.tether_strength), "and Illusory Dragon's its own")
	ok(not ui.build_skill_tooltip(skills.heal, alithia).contains("Tether"), "one with none says nothing of it")
	ok(CharacterSheet.facts_of(skills.silence, alithia).has("Tether 400"), "the sheet's Moves page says it too", "%s" % [CharacterSheet.facts_of(skills.silence, alithia)])
	# And the prompt while aiming it.
	var foe: Dictionary = foes()[0]
	combat.teleport_to(foe, tile_away(alithia.position, 3, foe))
	controller._selected_skill = "ecstasy"
	ui.show_hit_preview("ecstasy", foe.position)
	await settle(1)
	var found := []
	for label in ui._hit_preview.find_children("*", "Label", true, false):
		found.append(label.text)
	ok(" / ".join(found).contains("Tether 200"), "and so does the prompt while aiming", " / ".join(found))
	ui.hide_hit_preview()
	controller._selected_skill = ""
	log_line("")


func a_passive_grows():
	log_line("======== a passive that makes somebody immune, level by level ========")
	# The switch her progression will be set on: a condition on the passive, given at
	# its Required Level (active_passives).
	var passive := PassiveDefinition.new()
	passive.name = "Test"
	passive.required_level = 20
	passive.immune_to_conditions = [STUNNED]
	var young: Dictionary = combat.create_combatant(CombatantDatabase.combatants.alithia, "alithia", "", null, 19)
	young.passives.append(passive)
	ok(not combat.immune_to_condition(young, STUNNED), "not yet, below its level")
	young.level = 20
	ok(combat.immune_to_condition(young, STUNNED), "from its level on")
	log_line("")
