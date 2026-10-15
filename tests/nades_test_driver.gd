extends Node
## Gate Nades: a spell sealed in a shell - the spell's whole shape, no gate
## opened, no level needed, the nade's own power - and gone once thrown. But only
## by somebody who knows the spell or could learn it (their skills, at any level,
## or any of their paths): a Revitalizer Nade is Alithia's, not Prometheus's or
## Enfina's. Cyrus's Nade Juggler throws any of them, and with the secondary
## action.

var LOG_PATH := HarnessLog.path_for("nades")
const FIGHT := "res://data/encounters/encounter_03_watcher.tres"

var _log: FileAccess = null
var _fail = 0
var game: Node = null
var combat = null
var ui = null
var heard: Array = []


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
	the_nade_is_its_spell()
	await open_fight()
	await whose_nade_it_is()
	await throwing_them()
	await the_juggler()
	await close_fight()
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


func open_fight():
	Campaign.reset()
	Campaign.current_encounter = load(FIGHT)
	game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(6)
	combat = game.get_node("VisualCombat")
	ui = combat.game_ui
	combat.update_information.connect(func(text): heard.append(text))
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(3)


func close_fight():
	if game != null and is_instance_valid(game):
		game.queue_free()
		await settle(3)
	game = null


func who(key: String) -> Dictionary:
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == key and comb.alive:
			return comb
	return {}


func a_foe() -> Dictionary:
	for comb in combat.combatants:
		if comb.alive and comb.side == 1 and not comb.has("object"):
			return comb
	return {}


## `comb` acting now, everything they have spent this turn back.
func give_turn(comb: Dictionary):
	combat.current_combatant = combat.combatants.find(comb)
	combat.controller.set_controlled_combatant(comb)
	combat.controller.player_turn = comb.side == 0
	combat.controller.action_locked = false
	comb.skill_used_this_turn = false
	comb.secondary_used_this_turn = false


## Somewhere `comb` can stand within `reach` of `target`.
func within(comb: Dictionary, target: Dictionary, reach: int) -> Vector2i:
	var region: Rect2i = combat.controller._astargrid.region
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var tile := Vector2i(x, y)
			var gap: int = combat.get_position_distance(tile, target.position)
			if gap >= 2 and gap <= reach and combat.room_for(comb, tile):
				return tile
	return Vector2i(-99999, -99999)


func nade(key: String) -> GateNadeDefinition:
	return ItemDatabase.item(key)


## Whether the button for `key` on `comb`'s Items panel can be pressed, and what
## it says - "" for no such button.
func items_button(comb: Dictionary, key: String) -> Array:
	ui.showing_panel = ui.SkillPanel.ITEMS
	ui.showing_spells = false
	ui._show_skills_for(comb)
	var found := ["", false]
	for button in ui.action_buttons():
		if button.get_meta(ui.SKILL_META, "") == key and button.tooltip_text != "":
			found = [button.tooltip_text, not button.disabled]
	ui.showing_panel = ui.SkillPanel.MAIN
	return found


func the_nade_is_its_spell():
	log_line("======== a nade is its spell ========")
	var fireball_nade := nade("fireball_gate_nade")
	var fireball: SkillDefinition = SkillDatabase.skills.fireball
	ok(fireball_nade != null and fireball_nade.cast == fireball, "the Fireball Gate Nade holds Fireball")
	ok(fireball_nade.name == "Fireball Gate Nade" and fireball_nade.description.contains("Fireball"), "named for it", fireball_nade.name)
	ok(fireball_nade.aoe_radius == fireball.aoe_radius and fireball_nade.max_range == fireball.max_range
		and fireball_nade.effects == fireball.effects and fireball_nade.ability_modifier == fireball.ability_modifier
		and fireball_nade.damage_type == fireball.damage_type,
		"it takes the spell's whole shape: reach, area, effects, how hard and of what")
	ok(fireball_nade.spell_slot_level == 0 and fireball.spell_slot_level > 0, "but opens no gate")
	ok(fireball_nade.required_level == 1 and fireball.required_level > 1, "and needs no level", "Fireball needs %d" % fireball.required_level)
	ok(fireball_nade.icon != null and fireball_nade.sound == fireball.sound, "with the consumables' picture and the spell's sound")
	ok(fireball_nade.item_power == 50 and fireball_nade.price > 0, "its power and price its own", "%d, %d gold" % [fireball_nade.item_power, fireball_nade.price])
	ok(nade("revitalizer_gate_nade").targets_ally, "a Revitalizer nade is thrown at friends")
	var merchant: StoreDefinition = load("res://data/stores/travelling_merchant.tres")
	ok(merchant.stock.has("fireball_gate_nade") and merchant.stock.has("revitalizer_gate_nade"), "the travelling merchant sells them")
	log_line("")


func whose_nade_it_is():
	log_line("======== only those who know the spell, or could learn it ========")
	var alithia := who("alithia")
	var prometheus := who("prometheus")
	var enfina := who("enfina")
	var cyrus := who("cyrus")
	var revitalizer := nade("revitalizer_gate_nade")
	ok(combat.can_use_gate_nade(alithia, revitalizer), "a Revitalizer nade is Alithia's")
	ok(not combat.can_use_gate_nade(prometheus, revitalizer) and not combat.can_use_gate_nade(enfina, revitalizer),
		"not Prometheus's or Enfina's")
	ok(combat.can_use_gate_nade(prometheus, nade("fireball_gate_nade")) and not combat.can_use_gate_nade(alithia, nade("fireball_gate_nade")),
		"a Fireball nade is Prometheus's, not Alithia's")
	ok(not prometheus.skill_list.has("flame_edge") and combat.knows_or_can_learn(prometheus, "flame_edge")
		and not combat.knows_or_can_learn(enfina, "flame_edge"),
		"a spell only one of his paths teaches is one he could learn")
	var young: Dictionary = combat.create_combatant(CombatantDatabase.combatants.alithia, "alithia", "", null, 1)
	young["side"] = 0
	ok(not combat.meets_level_for(young, SkillDatabase.skills.revitalizer) and combat.can_use_gate_nade(young, revitalizer),
		"a spell she is not old enough for yet is one she could learn")
	ok(combat.can_use_gate_nade(cyrus, revitalizer) and combat.can_use_gate_nade(cyrus, nade("fireball_gate_nade")),
		"and Cyrus, through Nade Juggler, can throw any of them")
	log_line("")
	log_line("======== on the panel ========")
	Campaign.set_inventory("prometheus", ["revitalizer_gate_nade", "fireball_gate_nade"])
	give_turn(prometheus)
	var refused := items_button(prometheus, "revitalizer_gate_nade")
	ok(not refused[1] and refused[0].contains("Only somebody who knows Revitalizer"), "Prometheus's Revitalizer nade is greyed out, saying why")
	ok(items_button(prometheus, "fireball_gate_nade")[1], "his Fireball nade is not")
	log_line("")


func throwing_them():
	log_line("======== throwing them ========")
	var prometheus := who("prometheus")
	var alithia := who("alithia")
	var foe := a_foe()
	foe.hp = 999
	foe.max_hp = 999
	alithia.hp = 10
	combat.teleport_to(alithia, within(alithia, prometheus, 2))
	await settle(1)
	give_turn(prometheus)
	var mark := heard.size()
	await combat.use_skill("revitalizer_gate_nade", prometheus, alithia.position, false)
	await settle(2)
	ok(alithia.hp == 10 and combat.items_of(prometheus).has("revitalizer_gate_nade") and not prometheus.skill_used_this_turn,
		"thrown by Prometheus anyway, it is refused: nothing spent, nothing mended")
	ok(heard.slice(mark).any(func(line): return "Only somebody who knows" in line), "and the log says why")
	Campaign.set_inventory("alithia", ["revitalizer_gate_nade"])
	give_turn(alithia)
	var gates_before: Array = alithia.spell_slots.duplicate()
	await combat.use_skill("revitalizer_gate_nade", alithia, alithia.position, false)
	await settle(3)
	ok(alithia.hp > 10, "Alithia's mends", "%d" % alithia.hp)
	ok(not combat.items_of(alithia).has("revitalizer_gate_nade") and alithia.spell_slots == gates_before,
		"and is gone, with no gate of hers opened")
	ok(alithia.skill_used_this_turn, "it took her main action")
	combat.teleport_to(prometheus, within(prometheus, foe, 6))
	await settle(1)
	give_turn(prometheus)
	prometheus.status_effects.append({"stat": "accuracy", "amount": 100, "duration": 99, "source_name": "test"})
	await combat.use_skill("fireball_gate_nade", prometheus, foe.position, false)
	await settle(3)
	ok(foe.hp < 999, "Prometheus's Fireball nade goes off", "%d" % foe.hp)
	var priest: Dictionary = combat.create_combatant(CombatantDatabase.combatants.priest, "priest")
	priest["side"] = 1
	ok(combat._ai_plannable(priest, nade("fireball_gate_nade")) == false, "an enemy will not throw one whose spell is no part of theirs")
	log_line("")


func the_juggler():
	log_line("======== Cyrus's Nade Juggler ========")
	var cyrus := who("cyrus")
	var foe := a_foe()
	foe.hp = 999
	foe.max_hp = 999
	var juggler: PassiveDefinition = load("res://data/passives/nade_juggler.tres")
	ok(juggler.any_gate_nade and juggler.gate_nades_as_secondary, "any nade at all, and with the secondary action")
	ok(" ".join(juggler.describe_effects()).contains("any Gate Nade"), "and his sheet says so")
	# Quick Hands takes every item to the secondary anyway, so it is set aside to
	# see Nade Juggler do it on its own.
	var quick_hands: PassiveDefinition = load("res://data/passives/quick_hands.tres")
	cyrus.passives.erase(quick_hands)
	var fireball: SkillDefinition = nade("fireball_gate_nade")
	ok(ui._consumable_spends_secondary(cyrus, fireball), "a nade goes from his secondary action")
	ok(not ui._consumable_spends_secondary(cyrus, SkillDatabase.skills.small_bomb), "a bomb, without Quick Hands, does not")
	ok(ui.build_skill_tooltip(fireball, cyrus).contains("Secondary through Nade Juggler"), "and the nade's preview says whose doing that is")
	Campaign.set_inventory("cyrus", ["fireball_gate_nade", "revitalizer_gate_nade"])
	combat.teleport_to(cyrus, within(cyrus, foe, 6))
	await settle(1)
	give_turn(cyrus)
	cyrus.status_effects.append({"stat": "accuracy", "amount": 100, "duration": 99, "source_name": "test"})
	await combat.use_skill("fireball_gate_nade", cyrus, foe.position, false, ui._consumable_spends_secondary(cyrus, fireball))
	await settle(3)
	ok(foe.hp < 999 and cyrus.secondary_used_this_turn and not cyrus.skill_used_this_turn,
		"he throws Prometheus's Fireball with his secondary action, his main still to come", "%d" % foe.hp)
	ok(items_button(cyrus, "revitalizer_gate_nade")[1], "and Alithia's Revitalizer nade is his to throw too")
	cyrus.passives.append(quick_hands)
	log_line("")
