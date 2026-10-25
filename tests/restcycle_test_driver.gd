extends Node
## The rest cycle (the designer, 2026-10-25). Short rests whenever something
## calls for one - in a dungeon of them, between its fights (the Dungeon Demo,
## the lab); a long rest brings everything back: everybody up and whole, the
## weakening of being brought back lifted, every gate (Iris's too), Meditate and
## Devotion. Resuscitate at a short rest rests whoever it brings back too.
## Prometheus's Meditate (option A of the rest proposal); Alithia's Devotion (two
## castings of her own, for Heal or Dread Visage, one back a short rest); the
## Trapper's bomb once a short rest; the lab's Smelling Salts.

var LOG_PATH := HarnessLog.path_for("restcycle")
const LAB := "res://data/dungeons/lab_chapter1_sequence.tres"
const DEMO := "res://data/dungeons/dungeon_demo.tres"
const WATCHER := "res://data/encounters/encounter_03_watcher.tres"
const PARTY := ["enfina", "cyrus", "prometheus", "alithia"]

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
	the_short_rest()
	the_long_rest()
	resuscitated_at_a_rest()
	meditating()
	await meditating_at_a_rest()
	await devotion()
	await the_salts()
	the_bomb()
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
	combat.reaction_prompt = null
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
	who.secondary_used_this_turn = false


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


## The lab's party at `level`, in a dungeon of short rests.
func in_the_lab(level: int = 18):
	Campaign.reset()
	Campaign.set_party(PARTY, level)
	Campaign.dungeon = load(LAB)


## Somebody of the party as a fight makes them, before what they carry in.
func fresh() -> Dictionary:
	return {"hp": 999, "max_hp": 999, "alive": true, "spell_slots": [0, 4, 3, 3], "max_spell_slots": [0, 4, 3, 3]}


func carried(key: String) -> Dictionary:
	var comb := fresh()
	Campaign.apply_carried_state(comb, key)
	return comb


func the_short_rest():
	log_line("======== a short rest ========")
	in_the_lab()
	Campaign.party_state.alithia = {"hp": 40, "max_hp": 86, "alive": true,
		"spent_until_rest": {"spare_spent": 2, "uses": {"stunning_blow": 1}}}
	Campaign.party_state.enfina = {"hp": 46, "max_hp": 146, "alive": true}
	Campaign.party_state.cyrus = {"hp": 0, "max_hp": 86, "alive": false}
	Campaign.short_rest()
	ok(Campaign.party_state.alithia.hp == 40 + roundi(46 * Campaign.SHORT_REST_MENDS)
		and Campaign.party_state.enfina.hp == 46 + roundi(100 * Campaign.SHORT_REST_MENDS), "everybody standing gets back half of what they lost",
		"%d, %d" % [Campaign.party_state.alithia.hp, Campaign.party_state.enfina.hp])
	ok(not Campaign.party_state.cyrus.alive and Campaign.party_state.cyrus.hp == 0, "nobody fallen gets up by themselves")
	ok(Campaign.spares_back_at_short_rest("alithia") == 1 and Campaign.party_state.alithia.get("spent_until_rest", {}) == {"spare_spent": 1},
		"one of Alithia's two Devotion castings comes back, and every use spent until a rest", "%s" % [Campaign.party_state.alithia.get("spent_until_rest")])
	ok(carried("alithia").get("spare_spent", 0) == 1, "  so the next fight in the dungeon has one of the two")
	Campaign.short_rest()
	ok(not Campaign.party_state.alithia.has("spent_until_rest"), "  and a second short rest the other")
	Campaign.reset()
	log_line("")


func the_long_rest():
	log_line("======== a long rest ========")
	in_the_lab()
	Campaign.party_state.cyrus = {"hp": 0, "max_hp": roundi(86 * 0.81), "unweakened_max_hp": 86, "frailty": 0.81, "alive": false}
	Campaign.party_state.enfina = {"hp": 20, "max_hp": 131, "frailty": 0.9, "alive": true}
	Campaign.party_state.prometheus = {"hp": 5, "max_hp": 38, "alive": true, "spell_slots": [0, 0, 1, 0], "max_spell_slots": [0, 4, 3, 3]}
	Campaign.party_state.alithia = {"hp": 86, "max_hp": 86, "alive": true, "spent_until_rest": {"spare_spent": 2, "uses": {"recant": 1}}}
	Campaign.outside_spent["prometheus"] = [0, 2]
	Campaign.gates_spent_outside["prometheus"] = [0, 1]
	Campaign.meditated = ["prometheus"]
	Campaign.long_rest()
	ok(Campaign.party_state.cyrus.alive and Campaign.party_state.cyrus.hp == 86 and Campaign.party_state.cyrus.max_hp == 86,
		"the fallen up, whole", "%d/%d" % [Campaign.party_state.cyrus.hp, Campaign.party_state.cyrus.max_hp])
	ok(not Campaign.party_state.cyrus.has("frailty") and not Campaign.party_state.cyrus.has("unweakened_max_hp"),
		"  and no longer weaker for having been brought back")
	ok(Campaign.party_state.enfina.max_hp == 146 and Campaign.party_state.enfina.hp == 146 and not Campaign.party_state.enfina.has("frailty"),
		"  worked back from the weakening where the health before it was not kept", "%d/%d" % [Campaign.party_state.enfina.hp, Campaign.party_state.enfina.max_hp])
	ok(Campaign.party_state.prometheus.hp == 38 and Campaign.party_state.prometheus.spell_slots == [0, 4, 3, 3], "full health, and every gate back",
		"%s" % [Campaign.party_state.prometheus.spell_slots])
	ok(Campaign.outside_spent.is_empty() and Campaign.gates_spent_outside.is_empty(), "  those opened outside a fight (Iris) too")
	ok(not Campaign.party_state.alithia.has("spent_until_rest"), "both Devotion castings back, and every use")
	ok(Campaign.meditated.is_empty(), "and Meditate")
	var next := carried("cyrus")
	ok(not next.has("frailty") and next.hp == 86, "into the next fight at their full strength", "%d" % next.hp)
	Campaign.reset()
	log_line("")


func resuscitated_at_a_rest():
	log_line("======== Resuscitate at a short rest rests them too ========")
	in_the_lab()
	Campaign.party_state.alithia = {"hp": 60, "max_hp": 86, "alive": true, "spell_slots": [0, 4, 3, 3], "max_spell_slots": [0, 4, 3, 3]}
	Campaign.party_state.cyrus = {"hp": 0, "max_hp": 86, "alive": false}
	ok(Campaign.resuscitator() == "alithia" and Campaign.resuscitate_at_rest("alithia", "cyrus"), "Alithia brings Cyrus back")
	var weakened := roundi(86 * 0.9)
	var up := roundi(weakened * 0.5)
	ok(Campaign.party_state.cyrus.max_hp == weakened and Campaign.party_state.cyrus.hp == up + roundi((weakened - up) * Campaign.SHORT_REST_MENDS),
		"at half his health, a tenth weaker - and then rested, half of what he is still missing",
		"%d/%d" % [Campaign.party_state.cyrus.hp, Campaign.party_state.cyrus.max_hp])
	ok(Campaign.party_state.cyrus.get("unweakened_max_hp", 0) == 86, "  what he had before it kept, for the long rest")
	Campaign.long_rest()
	ok(Campaign.party_state.cyrus.max_hp == 86 and Campaign.party_state.cyrus.hp == 86 and not Campaign.party_state.cyrus.has("frailty"),
		"a long rest lifts it")
	Campaign.reset()
	log_line("")


func meditating():
	log_line("======== Meditate ========")
	in_the_lab(14)
	ok(Campaign.meditates("prometheus") and not Campaign.meditates("alithia") and not Campaign.meditates("cyrus"),
		"Prometheus meditates; Alithia does not (the designer: she gets none of it)")
	ok(Campaign.SAVED.has("meditated"), "who has meditated is kept in a save")
	var points := {1: 1, 8: 2, 14: 3, 18: 3, 24: 4, 33: 6, 45: 8, 55: 10, 64: 11}
	var deepest := {1: 1, 8: 1, 14: 2, 18: 2, 24: 2, 33: 3, 45: 4, 55: 5, 64: 5}
	var wrong := []
	for level in points:
		Campaign.party_level = level
		if Campaign.meditation_points("prometheus") != points[level] or Campaign.meditation_deepest("prometheus") != deepest[level]:
			wrong.append("%d: %d points, gate %d" % [level, Campaign.meditation_points("prometheus"), Campaign.meditation_deepest("prometheus")])
	ok(wrong.is_empty(), "a point every six levels, up to the shallower half of his open gates - the proposal's option A, level by level", "%s" % [wrong])
	Campaign.party_level = 14
	Campaign.party_state.prometheus = {"hp": 30, "max_hp": 38, "alive": true, "spell_slots": [0, 1, 0, 0], "max_spell_slots": [0, 4, 3, 2]}
	ok(Campaign.can_meditate("prometheus"), "at 14, spent: he can")
	ok(Campaign.meditation_cost("prometheus", 1) == 1 and Campaign.meditation_cost("prometheus", 2) == 2 and Campaign.meditation_cost("prometheus", 3) == 0,
		"  World 1, Hermes 2, Pandora not at all")
	ok(not Campaign.meditate("prometheus", [0, 0, 0, 1]), "  no Pandora")
	ok(not Campaign.meditate("prometheus", [0, 2, 1, 0]), "  nor four points' worth")
	ok(not Campaign.meditate("prometheus", [0, 0, 0, 0]), "  nor nothing")
	ok(Campaign.meditate("prometheus", [0, 1, 1, 0]), "a World and a Hermes")
	ok(Campaign.gates_left("prometheus") == [0, 2, 1, 0], "  come back", "%s" % [Campaign.gates_left("prometheus")])
	ok(not Campaign.can_meditate("prometheus"), "once")
	Campaign.short_rest()
	ok(not Campaign.can_meditate("prometheus"), "  not again at the next short rest")
	Campaign.long_rest()
	Campaign.party_state.prometheus.spell_slots = [0, 3, 3, 2]
	ok(Campaign.can_meditate("prometheus"), "  but again after a long rest")
	Campaign.party_state.prometheus.alive = false
	ok(not Campaign.can_meditate("prometheus"), "nobody fallen meditates")
	Campaign.reset()
	log_line("")


func meditating_at_a_rest():
	log_line("======== Meditate at the Dungeon Demo's rest ========")
	var demo: DungeonDefinition = load(DEMO)
	Campaign.reset()
	Campaign.dungeon = demo
	Campaign.set_party(demo.party, demo.level)
	Campaign.party_state.prometheus = {"hp": 30, "max_hp": 38, "alive": true, "spell_slots": [0, 1, 0, 0], "max_spell_slots": [0, 4, 3, 2]}
	var panel := RestPanel.new()
	add_child(panel)
	await settle(2)
	ok(panel.offered_to == "prometheus" and panel.meditating, "the rest offers Prometheus's Meditate, the demo having no recovery of its own")
	var question = panel.find_child("Question", true, false)
	var terms = panel.find_child("Terms", true, false)
	ok(question != null and question.text.contains("Meditate"), "  asking", question.text if question != null else "")
	ok(terms != null and terms.text.contains("3 points") and terms.text.contains("World costs 1") and terms.text.contains("Hermes costs 2")
		and not terms.text.contains("Pandora") and terms.text.contains("long rest"), "  what he has to spend, what each costs, and how often",
		terms.text if terms != null else "")
	ok(panel._row_for(3) == null and panel._row_for(1, true) == null, "  no row for Pandora, nor for Iris")
	panel.change(1, 1)
	panel.change(1, 1)
	panel.change(1, 1)
	panel.change(2, 1)
	ok(panel.chosen[1] == 3 and panel.chosen[2] == 0 and panel.points_left() == 0, "three Worlds, and nothing more", "%s" % [panel.chosen])
	ok(panel.recover(), "Meditate")
	ok(Campaign.gates_left("prometheus") == [0, 4, 0, 0] and Campaign.meditated.has("prometheus"), "  brings them back",
		"%s" % [Campaign.gates_left("prometheus")])
	panel.queue_free()
	await settle()
	var later := RestPanel.new()
	add_child(later)
	await settle(2)
	ok(later.offered_to == "", "the next short rest offers nothing")
	later.queue_free()
	Campaign.reset()
	await settle()
	log_line("")


func devotion():
	log_line("======== Alithia's Devotion ========")
	Campaign.reset()
	var game = await open_fight(WATCHER)
	var combat = game.get_node("VisualCombat")
	var alithia := fighter(combat, "alithia")
	var heal: SkillDefinition = SkillDatabase.skills.heal
	var visage: SkillDefinition = SkillDatabase.skills.dread_visage
	ok(combat.spares_most(alithia) == 2 and combat.spares_name(alithia) == "Devotion", "two castings of her own")
	ok(combat.spares_left(alithia, heal) == 2 and combat.spares_left(alithia, visage) == 2, "  for Heal or Dread Visage")
	ok(combat.spares_left(alithia, SkillDatabase.skills.holy_lance) == 0 and combat.spares_left(alithia, ItemDatabase.item("heal_gate_nade")) == 0,
		"  and nothing else - not a Heal Gate Nade either")
	ok(combat.spares_most(fighter(combat, "prometheus")) == 0, "nobody else has any")
	var world: int = alithia.spell_slots[1]
	alithia.hp = maxi(alithia.hp - 30, 1)
	give_turn(combat, alithia)
	await combat.use_skill("heal", alithia, alithia.position, false)
	await settle(2)
	ok(alithia.get("spare_spent", 0) == 1 and alithia.spell_slots[1] == world, "a Heal: one Devotion casting, before any gate",
		"%d spent, World %d of %d" % [alithia.get("spare_spent", 0), alithia.spell_slots[1], world])
	var foe := {}
	for comb in combat.combatants:
		if comb.side == 1 and comb.alive and not comb.has("object"):
			foe = comb
			break
	put(combat, foe, free_beside(combat, alithia.position, foe.movement_class))
	await settle(2)
	for gate in alithia.spell_slots.size():
		alithia.spell_slots[gate] = 0
	ok(combat.can_afford_skill(alithia, visage), "with no gates left, Dread Visage can still be cast")
	give_turn(combat, alithia)
	await combat.use_skill("dread_visage", alithia, foe.position, false)
	await settle(2)
	ok(alithia.get("spare_spent", 0) == 2 and alithia.spell_slots.all(func(left): return left == 0), "  on one person, for the other casting",
		"%d spent" % alithia.get("spare_spent", 0))
	ok(not combat.can_afford_skill(alithia, heal), "both spent and no World casting: no Heal")
	alithia.spell_slots[1] = 1
	give_turn(combat, alithia)
	await combat.use_skill("heal", alithia, alithia.position, false)
	await settle(2)
	ok(alithia.spell_slots[1] == 0 and alithia.get("spare_spent", 0) == 2, "with a World casting back, Heal spends it")
	Campaign.dungeon = load(LAB)
	Campaign.record_party(combat.combatants)
	ok(Campaign.party_state.alithia.get("spent_until_rest", {}).get("spare_spent", 0) == 2, "in a dungeon, carried out of the fight")
	Campaign.short_rest()
	ok(Campaign.party_state.alithia.get("spent_until_rest", {}).get("spare_spent", 0) == 1, "  a short rest gives one back")
	Campaign.long_rest()
	ok(not Campaign.party_state.alithia.has("spent_until_rest"), "  a long rest both")
	Campaign.dungeon = null
	game.queue_free()
	await settle(3)
	Campaign.reset()
	log_line("")


func the_salts():
	log_line("======== Smelling Salts ========")
	var salts: ItemDefinition = ItemDatabase.item("smelling_salts")
	ok(salts != null and salts.targets_ally and salts.targets_fallen and salts.max_range == 1, "an item for somebody fallen beside you")
	var revive: EffectDefinition = salts.effects[0] if salts != null and not salts.effects.is_empty() else null
	ok(revive != null and revive.type == EffectDefinition.EffectType.REVIVE and is_equal_approx(revive.revive_health, 0.5)
		and is_equal_approx(revive.revive_weakening, 0.1), "  back at half their health, a tenth weaker, as after Resuscitate")
	Campaign.reset()
	var game = await open_fight(WATCHER)
	var combat = game.get_node("VisualCombat")
	var cyrus := fighter(combat, "cyrus")
	var enfina := fighter(combat, "enfina")
	ok(Campaign.give_item("cyrus", "smelling_salts"), "(Cyrus has some)")
	var most: int = enfina.max_hp
	put(combat, enfina, free_beside(combat, cyrus.position, enfina.movement_class))
	enfina.hp = 0
	combat.combatant_die(enfina)
	await settle(2)
	ok(combat.wasted_on(cyrus, salts) == "", "with Enfina down beside him, they would do something", combat.wasted_on(cyrus, salts))
	give_turn(combat, cyrus)
	await combat.use_skill("smelling_salts", cyrus, enfina.position, false)
	await settle(3)
	ok(enfina.alive and enfina.max_hp == roundi(most * 0.9) and enfina.hp == roundi(enfina.max_hp * 0.5), "Enfina is back up, at half her health, a tenth weaker",
		"%d/%d" % [enfina.hp, enfina.max_hp])
	ok(Campaign.count_of("cyrus", "smelling_salts") == 0, "  and they are used up")
	game.queue_free()
	await settle(3)
	Campaign.reset()
	log_line("")


func the_bomb():
	log_line("======== the Trapper's bomb, once a short rest ========")
	var trapper: SubclassDefinition = load("res://data/subclasses/trapper.tres")
	var kit: PassiveDefinition = null
	for passive in trapper.passives:
		if passive.free_item_each_fight != "":
			kit = passive
	ok(kit != null and kit.description.contains("once a short rest") and " ".join(kit.describe_effects()).contains("once a short rest"),
		"Bombardier's Kit says so", kit.description if kit != null else "")
	in_the_lab()
	var thrown := {"combatant_key": "cyrus", "side": 0, "hp": 50, "max_hp": 86, "alive": true, "free_items_used": ["small_bomb"]}
	Campaign.record_party([thrown])
	var next := carried("cyrus")
	ok(next.get("free_items_used", []) == ["small_bomb"], "thrown in one fight of a dungeon, it is not to hand in the next", "%s" % [next.get("free_items_used")])
	next.free_items_used.append("small_bomb")
	ok(Campaign.party_state.cyrus.spent_until_rest.free_items_used == ["small_bomb"], "  (each fight its own copy)")
	Campaign.short_rest()
	ok(not carried("cyrus").has("free_items_used"), "  until a short rest")
	Campaign.reset()
	log_line("")
