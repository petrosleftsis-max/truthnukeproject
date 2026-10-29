extends Node
## The ways of dealing with enemies besides hitting them: Enfina's hits studying,
## Alithia's Intuition reading a turn and holding them to it, changing sides,
## a champion hemming the party in and Exposing them, nerve (fleeing,
## surrendering, leaders), taking them alive and questioning them, Intimidate / Persuade / Deceive and the leverage they need,
## bribes and parleys, body parts, Hurl and Climb, rebinding a bound creature,
## and quick time events.

var LOG_PATH := HarnessLog.path_for("enemies")
const BLADES := "res://data/encounters/encounter_hired_blades.tres"
const GOLEM := "res://data/encounters/encounter_bound_golem.tres"

var _log: FileAccess = null
var _fail = 0
var game: Node = null
var combat = null
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
	get_tree().create_timer(300.0, true, false, true).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	var booted = get_tree().current_scene
	if booted != null:
		booted.queue_free()
		await settle()
	Campaign.reset()
	await open_fight(BLADES)
	the_encounter_is_there()
	measured_eye()
	await the_codex()
	await intuition()
	holding_attention()
	switching_sides()
	leverage()
	await talking_them_round()
	await cyrus_picks_a_slot()
	bribes()
	await hurling()
	await grabbing()
	ignoring_defense()
	await nerve()
	await running_for_a_way_out()
	await taking_them_alive()
	await questioning()
	await close_fight()
	await parley()
	await open_fight(GOLEM)
	body_parts()
	after_something_big()
	shooting_something_big()
	await watching_something_big()
	await climbing()
	melee_and_ranged()
	await riders_cannot_shove()
	await rebinding()
	await the_party_falling()
	await close_fight()
	await the_boss_codex()
	await quick_time()
	await the_conversation_after()
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


func until(check: Callable, seconds: float = 5.0) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		if check.call():
			return true
		await get_tree().process_frame
	return check.call()


func open_fight(path: String):
	Campaign.current_encounter = load(path)
	game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(6)
	combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(2)
	heard.clear()
	combat.update_information.connect(func(text): heard.append(text))
	for comb in combat.combatants:
		# A reaction would stop and ask a player who is not there.
		if comb.side == 0:
			comb.reaction_used = true


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


func named(name: String) -> Dictionary:
	for comb in combat.combatants:
		if comb.name == name:
			return comb
	return {}


func sturdy(comb: Dictionary, hp: int = 900):
	comb.max_hp = hp
	comb.hp = hp


func heard_since(mark: int, words: String) -> bool:
	for i in range(mark, heard.size()):
		if words in heard[i]:
			return true
	return false


## A free tile for `comb` passing `test`, nearest `near`.
func a_tile(comb: Dictionary, test: Callable, near = null) -> Vector2i:
	var from: Vector2i = near if near != null else comb.position
	var best := Vector2i(-99999, -99999)
	var best_gap := 99999
	var region: Rect2i = combat.controller._astargrid.region
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var tile := Vector2i(x, y)
			if tile != comb.position and combat.room_for(comb, tile) and test.call(tile):
				var gap: int = combat.get_position_distance(from, tile)
				if gap < best_gap:
					best_gap = gap
					best = tile
	return best


## Puts `comb` right beside `target`, on a free tile.
func beside(comb: Dictionary, target: Dictionary) -> bool:
	var spot := a_tile(comb, func(tile): return combat.distance_to(target, tile) == 1, target.position)
	if spot.x == -99999:
		return false
	return spot == comb.position or combat.teleport_to(comb, spot)


func give_turn(comb: Dictionary):
	combat.current_combatant = combat.combatants.find(comb)
	combat.controller.set_controlled_combatant(comb)
	combat.controller.action_locked = false
	comb.skill_used_this_turn = false
	comb.secondary_used_this_turn = false


## `enemy`'s turn, handed back to `player` after it.
func enemy_turn(enemy: Dictionary, player: Dictionary):
	# A reaction would stop and ask a player who is not there - and the party's
	# come back at the start of each of their own turns, which these hand round.
	for comb in combat.combatants:
		if comb.side == 0:
			comb.reaction_used = true
	var p: int = combat.combatants.find(player)
	var e: int = combat.combatants.find(enemy)
	combat.turn_queue = [p, e, p]
	combat.turn = 0
	combat.current_combatant = p
	await combat.advance_turn()
	await settle(2)


func set_stat(comb: Dictionary, type: int, value: int):
	comb.stats[Stats.stat_key(type)] = value


func condition(name: String) -> ConditionDefinition:
	return load("res://data/conditions/%s.tres" % name)


func has_condition(comb: Dictionary, name: String) -> bool:
	return combat.conditions_of(comb).any(func(c): return c.resource_path.get_file().get_basename() == name)


func the_encounter_is_there():
	log_line("======== Hired Blades ========")
	ok(not who("pit_champion").is_empty(), "the pit champion is fighting")
	ok(combat.combatants.filter(func(c): return c.get("combatant_key", "") == "sellsword").size() == 2, "two sellswords")
	ok(combat.combatants.filter(func(c): return c.get("combatant_key", "") == "hired_bow").size() == 2, "two hired bows")
	ok(who("pit_champion").get("leads", false), "the champion leads them")
	log_line("")


func measured_eye():
	log_line("======== Enfina's hits study ========")
	var enfina := who("enfina")
	var target := named("Sellsword 1")
	sturdy(target)
	ok(combat.studies_on_hit(enfina), "Enfina's Measured Eye studies with every hit")
	ok(not combat.studies_on_hit(who("cyrus")), "and nobody else's does")
	var mark := heard.size()
	combat.do_damage(enfina, target, EffectDefinition.new(), SkillDatabase.skills.greatsword_attack)
	ok(target.get("studied_by", []).has(enfina.id), "a hit studies whoever it lands on", "%s" % [target.get("studied_by", [])])
	ok(heard_since(mark, "takes the measure"), "and says so")
	mark = heard.size()
	combat.do_damage(enfina, target, EffectDefinition.new(), SkillDatabase.skills.greatsword_attack)
	ok(not heard_since(mark, "measure"), "the second time, nothing more is said")
	log_line("")


func intuition():
	log_line("======== Intuition ========")
	var alithia := who("alithia")
	var foe := named("Sellsword 2")
	var skill: SkillDefinition = SkillDatabase.skills.intuition
	ok(skill.is_secondary, "Intuition is a secondary action")
	ok(alithia.skill_list.has("intuition"), "and it is Alithia's")
	sturdy(foe)
	# Whoever it turns on instead - more than once - lives through it.
	sturdy(alithia)
	sturdy(who("prometheus"))
	# Somebody for it to go for, within its reach.
	var cyrus := who("cyrus")
	sturdy(cyrus)
	ok(beside(cyrus, foe), "Cyrus stands beside a sellsword")
	await settle(1)
	var mark := heard.size()
	combat.read_intent(alithia, foe)
	ok(foe.has("intent"), "she reads what it means to do", "%s" % [foe.get("intent", {})])
	ok(heard_since(mark, "reads"), "and says it")
	var intent: Dictionary = foe.get("intent", {})
	var marked: Array = intent.get("tiles", [])
	var aimed_at: Array = combat.combatants.filter(func(c): return c.alive and c.side == 0 and marked.has(c.position))
	ok(intent.get("skill", "") != "" and not aimed_at.is_empty(), "it means to hit somebody, and the tiles say where",
		"%s" % [aimed_at.map(func(c): return c.name)])
	ok(not combat.intent_marks().is_empty(), "the board has it to draw")
	ok("Read:" in combat.game_ui._queue_tip(foe), "and the turn queue says it", combat.game_ui._queue_tip(foe).replace("\n", " | "))
	# Whoever it meant to hit gets out of the way; the blow is held to the
	# tiles it was read on.
	var before := {}
	for comb in combat.combatants:
		if comb.side == 0 and comb.alive:
			before[comb.id] = comb.hp
	for comb in aimed_at:
		sturdy(comb)
		before[comb.id] = comb.hp
		var away := a_tile(comb, func(tile): return not marked.has(tile) and combat.get_position_distance(tile, foe.position) >= 6)
		ok(away.x != -99999 and combat.teleport_to(comb, away), "%s steps off the marked tiles" % comb.name)
	await enemy_turn(foe, alithia)
	var hurt: Array = combat.combatants.filter(func(c): return before.has(c.id) and c.hp < before[c.id])
	ok(hurt.is_empty(), "the blow lands where it was read, on nobody", "%s" % [hurt.map(func(c): return c.name)])
	ok(not foe.has("intent"), "and the reading is spent")
	# Somebody stands on the tile it meant to step to: it has to adapt, and says so.
	var reachable := a_tile(cyrus, func(tile): return combat.distance_to(foe, tile) == 3)
	combat.teleport_to(cyrus, reachable)
	await settle(1)
	combat.read_intent(alithia, foe)
	var plan: Dictionary = foe.get("intent", {})
	var stand: Vector2i = plan.get("tile", foe.position)
	if stand == foe.position:
		log_line("  NOTE  it meant to stay where it stood, so there was no tile to take")
	else:
		var blocker := who("enfina")
		sturdy(blocker)
		ok(combat.teleport_to(blocker, stand), "Enfina takes the tile it meant to stand on", "%s" % [stand])
		mark = heard.size()
		var made: Array = []
		var watching := func(node): made.append(String(node.name))
		combat.controller.child_entered_tree.connect(watching)
		await enemy_turn(foe, alithia)
		combat.controller.child_entered_tree.disconnect(watching)
		ok(heard_since(mark, "The party managed to change the future that Alithia foresaw and the [color=red]Sellsword 2[/color] is forced to adapt."),
			"so it has to adapt, and the log says the party changed the future", "%s" % [heard.slice(mark)])
		ok(made.any(func(name): return name.begins_with("FutureShards")), "the marks shatter", "%s" % [made])
		ok(heard_since(mark, "[color=yellow]Alithia[/color]: \""), "and Alithia has something to say about it")
		ok(foe.get("thwarted", false), "it is thwarted until its next turn")
		var faces: Array = combat.game_ui._queue_faces_for(foe)
		ok(not faces.is_empty() and faces.all(func(face): return face.get_node_or_null("Crack") != null), "its face in the turn queue is cracked")
		await enemy_turn(foe, alithia)
		ok(not foe.get("thwarted", false), "and mended once its next turn begins")
		faces = combat.game_ui._queue_faces_for(foe)
		ok(faces.all(func(face): return face.get_node_or_null("Crack") == null), "face and all")
	# A death in the vision: somebody the read blow would knock out is marked red.
	combat.teleport_to(cyrus, a_tile(cyrus, func(tile): return combat.distance_to(foe, tile) == 1))
	var cyrus_hp: int = cyrus.hp
	cyrus.hp = 1
	foe["intent"] = {"skill": "greatsword_attack", "tile": foe.position, "aim": cyrus.position, "tiles": [cyrus.position],
		"target": cyrus.id, "read_by": "Alithia", "reader_id": alithia.id}
	ok(combat.foreseen_doom(foe).has(cyrus), "a blow that would finish Cyrus is a death in the vision")
	ok(combat.intent_marks().any(func(m): return not m.doomed.is_empty()), "marked for the board to draw red")
	ok("would finish Cyrus" in combat.intent_text(foe), "and said", combat.intent_text(foe))
	cyrus.hp = cyrus_hp
	ok(combat.foreseen_doom(foe).is_empty(), "healed, the death is gone from the vision")
	foe.erase("intent")
	# A path can add to a reading (PassiveDefinition, Intuition).
	var path := PassiveDefinition.new()
	path.name = "Test path"
	var fright := EffectDefinition.new()
	fright.type = EffectDefinition.EffectType.CONDITION
	fright.condition = condition("fear")
	path.on_read_effects = [fright]
	var shield := EffectDefinition.new()
	shield.type = EffectDefinition.EffectType.CONDITION
	shield.condition = condition("hesitating")
	path.forewarn_effects = [shield]
	path.thwarted_damage_bonus = 0.5
	var kept_passives: Array = alithia.get("passives", []).duplicate()
	alithia["passives"] = kept_passives + [path]
	combat.teleport_to(cyrus, a_tile(cyrus, func(tile): return combat.distance_to(foe, tile) == 1))
	combat.read_intent(alithia, foe)
	ok(has_condition(foe, "fear"), "reading puts what the path says on the one read")
	var victims: Array = combat.foreseen_victims(foe)
	ok(victims.is_empty() or victims.all(func(victim): return has_condition(victim, "hesitating")), "and on whoever its blow is aimed at",
		"%s" % [victims.map(func(v): return v.name)])
	var plain: float = combat.damage_dealt_multiplier(alithia, foe, SkillDatabase.skills.sass_club)
	foe["thwarted"] = true
	var thwarted: float = combat.damage_dealt_multiplier(alithia, foe, SkillDatabase.skills.sass_club)
	ok(is_equal_approx(thwarted, plain * 1.5), "and her hits on somebody thwarted land harder", "%.2f vs %.2f" % [thwarted, plain])
	foe.erase("thwarted")
	foe.erase("intent")
	alithia["passives"] = kept_passives
	for comb in [foe] + victims:
		comb.status_effects = comb.status_effects.filter(func(e): return e.get("condition") == null or not (e.condition.resource_path.get_file().get_basename() in ["fear", "hesitating"]))
	var golem_like := {"name": "Test", "side": 1, "immune_to": [Immunity.Kind.READ], "position": Vector2i(-50, -50), "status_effects": []}
	mark = heard.size()
	combat.read_intent(alithia, golem_like)
	ok(not golem_like.has("intent") and heard_since(mark, "immune"), "immune to being read, nothing is", "%s" % [heard.slice(mark)])
	log_line("")


func holding_attention():
	log_line("======== Hemmed In and Exposed ========")
	var champion := who("pit_champion")
	var enfina := who("enfina")
	sturdy(champion)
	ok(beside(enfina, champion), "Enfina starts beside the champion")
	# Hemmed In: twice the movement within two tiles, for the other side only.
	var hemmed: Dictionary = combat.hemmed_tiles(enfina)
	ok(hemmed.has(enfina.position) and combat.hem_cost(enfina, enfina.position) == 2, "beside the champion, every tile costs her twice")
	var far: Vector2i = enfina.position + Vector2i(30, 30)
	ok(combat.hem_cost(enfina, far) == 1, "far off, once")
	var sellsword := named("Sellsword 1")
	ok(combat.hemmed_tiles(sellsword).is_empty(), "and the champion's own side walks as ever")
	var step := Vector2i(-99999, -99999)
	for offset in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
		var tile: Vector2i = enfina.position + offset
		if hemmed.has(tile) and not combat.controller.is_tile_blocking(tile, 0) and combat.get_combatant_at(tile).is_empty() \
				and combat.controller.get_tile_cost_for_class(tile, 0) == 1:
			step = tile
			break
	if step.x != -99999:
		var reach: Dictionary = combat.controller.get_reachable_tiles(enfina.position, 0, 6, enfina)
		ok(reach.get(step, -1) == 2, "a step beside it takes two of her movement", "%s" % [reach.get(step, -1)])
	# Exposed: ending a turn near it without having hurt it.
	enfina.erase("struck_this_turn")
	combat.end_of_turn_effects(enfina)
	ok(has_condition(enfina, "exposed"), "ending her turn beside it without a blow at it, she is Exposed")
	var swing: SkillDefinition = SkillDatabase.skills.greatsword_attack
	ok(is_equal_approx(combat.progression_damage_bonus(champion, enfina, swing), 1.2), "a fifth more from the champion",
		"%s" % combat.progression_damage_bonus(champion, enfina, swing))
	ok(is_equal_approx(combat.progression_damage_bonus(sellsword, enfina, swing), 1.0), "and nothing more from anybody else")
	var entry: Dictionary = {}
	for eff in enfina.status_effects:
		if eff.get("condition") == condition("exposed"):
			entry = eff
	ok(Combat.gone_by_their_turn(entry), "gone as her next turn starts")
	enfina.status_effects = enfina.status_effects.filter(func(e): return e.get("condition") != condition("exposed"))
	enfina["struck_this_turn"] = [champion.id]
	combat.end_of_turn_effects(enfina)
	ok(not has_condition(enfina, "exposed"), "having hit it, she is not")
	enfina.erase("struck_this_turn")
	var cyrus := who("cyrus")
	if combat.distance_to(champion, cyrus.position) > 2:
		combat.end_of_turn_effects(cyrus)
		ok(not has_condition(cyrus, "exposed"), "nor is anybody further off")
	log_line("")


func switching_sides():
	log_line("======== Changing sides ========")
	var foe := named("Hired Bow 1")
	var index: int = combat.combatants.find(foe)
	combat.switch_sides(foe, 2, "test switch\n")
	ok(foe.side == 0 and combat.groups[0].has(index) and not combat.groups[1].has(index), "it fights for the party now")
	ok(foe.get("ai_controlled", false) and combat.ai_plays(foe) and not combat.plays_for_party(foe), "but the AI plays it")
	combat.controller.set_controlled_combatant(foe)
	ok(not combat.controller.player_turn, "its turn is never the player's")
	ok("other side" in combat.game_ui._queue_tip(foe), "the queue says it has turned")
	combat._turncoat_turn_ends(foe)
	ok(foe.side == 0 and foe.turncoat.turns == 1, "a turn down, one to go")
	combat._turncoat_turn_ends(foe)
	ok(foe.side == 1 and not foe.has("turncoat") and combat.groups[1].has(index), "then it turns back")
	var record_before: Dictionary = Campaign.party_state.duplicate(true)
	combat.switch_sides(foe, 0)
	Campaign.record_party(combat.combatants)
	ok(not Campaign.party_state.has("hired_bow"), "and is never written into the party's state")
	combat.switch_sides(foe, 0)
	Campaign.party_state = record_before
	log_line("")


func leverage():
	log_line("======== Leverage ========")
	var enfina := who("enfina")
	var foe := named("Sellsword 1")
	var intimidate: SkillDefinition = SkillDatabase.skills.intimidate
	ok(intimidate.needs_leverage and SkillDatabase.skills.persuade.needs_leverage and SkillDatabase.skills.deceive.needs_leverage,
		"Intimidate, Persuade and Deceive need something on them")
	ok(enfina.skill_list.has("intimidate") and who("alithia").skill_list.has("persuade") and who("cyrus").skill_list.has("deceive"),
		"Enfina intimidates, Alithia persuades, Cyrus deceives")
	ok(not combat.has_leverage(foe), "nothing known, there is no leverage")
	var refused: String = combat.refusal_for(enfina, intimidate, foe.position)
	ok("nothing on" in refused, "and it is refused, saying why", refused)
	var hud = combat.game_ui
	var talk_tab: Button = hud._tab(hud.SkillPanel.TALK)
	ok(not combat.main_skills_of(enfina).has("intimidate") and combat.talk_skills_of(enfina) == ["intimidate"],
		"Intimidate is not on the Main tab but the Skills tab")
	hud._refresh_tabs(enfina)
	ok(talk_tab != null and not talk_tab.visible, "and with nothing on anybody here, there is no Skills tab")
	ok(Campaign.learn_clue("sellsword_contract"), "the sellswords' contract is learned")
	ok(combat.has_leverage(foe) and combat.has_leverage(who("pit_champion")), "now there is leverage on them")
	ok(combat.refusal_for(enfina, intimidate, foe.position) == "", "and it is allowed")
	hud._refresh_tabs(enfina)
	ok(talk_tab.visible and talk_tab.text == "Skills", "and the Skills tab is there")
	ok(not combat._ai_plannable(foe, intimidate), "the AI never plans one")
	log_line("")


func talking_them_round():
	log_line("======== Talking them round ========")
	var alithia := who("alithia")
	var cyrus := who("cyrus")
	var enfina := who("enfina")
	var foe := named("Sellsword 1")
	var mate := named("Sellsword 2")
	sturdy(foe)
	sturdy(mate)
	set_stat(alithia, Stats.Type.MINDFULNESS, 99)
	set_stat(foe, Stats.Type.SELF, 1)
	set_stat(foe, Stats.Type.INTELLECT, 1)
	set_stat(cyrus, Stats.Type.SELF, 99)
	set_stat(enfina, Stats.Type.PHYSICAL, 99)
	# Persuade: stands down, until hurt.
	var spot := a_tile(alithia, func(tile): return combat.get_position_distance(tile, foe.position) == 2)
	combat.teleport_to(alithia, spot)
	give_turn(alithia)
	await combat.use_skill("persuade", alithia, foe.position, false)
	ok(has_condition(foe, "hesitating"), "persuaded, it hesitates")
	combat.do_damage(enfina, foe, EffectDefinition.new(), SkillDatabase.skills.greatsword_attack)
	ok(not has_condition(foe, "hesitating"), "and is hurt out of it")
	# Intimidate: afraid, and shaken.
	spot = a_tile(enfina, func(tile): return combat.get_position_distance(tile, foe.position) == 2)
	combat.teleport_to(enfina, spot)
	give_turn(enfina)
	foe.nerve = 999
	await combat.use_skill("intimidate", enfina, foe.position, false)
	ok(has_condition(foe, "fear"), "intimidated, it is afraid")
	ok(foe.get("shaken", 0) >= 25, "and its nerve is shaken", "%d" % foe.get("shaken", 0))
	foe.nerve = 50
	foe.shaken = 0
	foe.status_effects = foe.status_effects.filter(func(e): return e.get("condition") == null or e.condition.resource_path.get_file() != "fear.tres")
	# Deceive: its turn goes on its own side.
	spot = a_tile(cyrus, func(tile): return combat.get_position_distance(tile, foe.position) == 2)
	combat.teleport_to(cyrus, spot)
	give_turn(cyrus)
	await combat.use_skill("deceive", cyrus, foe.position, false)
	ok(has_condition(foe, "deceived"), "deceived, it thinks it has been sold out")
	var mark := heard.size()
	# Side by side, so what is tested is who it hits, not how far it can walk.
	beside(mate, foe)
	var mate_hp: int = mate.hp
	await enemy_turn(foe, cyrus)
	ok(heard_since(mark, "has been deceived, and turns on"), "and turns on its own side", "%s" % [heard.slice(mark, mark + 4)])
	ok(mate.hp < mate_hp, "and its blow lands on them", "%d -> %d" % [mate_hp, mate.hp])
	foe.status_effects = foe.status_effects.filter(func(e): return e.get("condition") == null or not e.condition.turns_on_own_side)
	log_line("")


func cyrus_picks_a_slot():
	log_line("======== Cyrus picks which action an item spends ========")
	var cyrus := who("cyrus")
	var hud = combat.game_ui
	var bag: Array = combat.items_of(cyrus)
	ok(not bag.is_empty(), "Cyrus has something to hand", "%s" % [bag])
	if bag.is_empty():
		return
	var item: SkillDefinition = SkillDatabase.skills[bag[0]]
	give_turn(cyrus)
	ok(hud.item_slot_is_a_choice(cyrus, item), "with both actions there, it is a choice")
	hud.open_slot_picker(cyrus, bag[0])
	ok(hud.slot_picker != null and hud.slot_picker.find_child("Main", true, false) != null
		and hud.slot_picker.find_child("Secondary", true, false) != null, "and he is asked: main or secondary")
	(hud.slot_picker.find_child("Secondary", true, false) as Button).pressed.emit()
	await settle(1)
	ok(hud.slot_picker == null and combat.controller.is_skill_selected() and combat.controller._selected_skill_is_secondary,
		"picked, it is aimed with the secondary action")
	combat.controller.cancel_skill_selection()
	cyrus.secondary_used_this_turn = true
	ok(not hud.item_slot_is_a_choice(cyrus, item), "with one of them spent, there is no asking")
	cyrus.secondary_used_this_turn = false
	ok(not hud.item_slot_is_a_choice(who("enfina"), item), "and nobody without Quick Hands is asked")
	log_line("")


func bribes():
	log_line("======== Bribes ========")
	var cyrus := who("cyrus")
	ok(cyrus.skill_list.has("bribe"), "with somebody buyable fighting, the party can Bribe")
	var bow := named("Hired Bow 2")
	Campaign.gold = 10
	var refused: String = combat.refusal_for(cyrus, SkillDatabase.skills.bribe, bow.position)
	ok("wants 40" in refused, "short of the price, it is refused", refused)
	ok("cannot be bought" in combat.refusal_for(cyrus, SkillDatabase.skills.bribe, who("pit_champion").position), "the champion cannot be bought")
	Campaign.gold = 100
	combat.pay_off(cyrus, bow)
	ok(Campaign.gold == 60 and bow.get("taken", "") == "bought", "paid, it walks away", "%d gold, %s" % [Campaign.gold, bow.get("taken", "")])
	ok(not combat.groups[1].has(combat.combatants.find(bow)), "and is off its side")
	ok(not combat.prisoners().has(bow), "and is nobody's prisoner")
	log_line("")


func hurling():
	log_line("======== Hurl ========")
	var enfina := who("enfina")
	var hurl: SkillDefinition = SkillDatabase.skills.hurl
	ok(enfina.skill_list.has("hurl"), "Enfina can Hurl")
	ok(CombatantDatabase.combatants.barbarian.skills.has("hurl"), "and so can the Barbarian")
	var thrown := named("Sellsword 2")
	var into := named("Hired Bow 1")
	sturdy(thrown)
	sturdy(into)
	var champion := who("pit_champion")
	ok(pair_up(enfina, thrown), "Enfina beside a sellsword", "%s at %s alive %s taken %s, enfina at %s riding %s" % [thrown.name, thrown.position, thrown.alive, thrown.get("taken", "-"), enfina.position, enfina.has("riding")])
	await settle(1)
	ok(combat.throw_reach(enfina, hurl) == hurl.throw_range + floori(combat.stat_of(enfina, Stats.Type.PHYSICAL) / 30.0),
		"her throw reaches further the stronger she is", "%d" % combat.throw_reach(enfina, hurl))
	# Somebody within her reach to throw it into.
	var near := a_tile(into, func(tile): return combat.get_position_distance(tile, enfina.position) <= combat.throw_reach(enfina, hurl) \
		and combat.get_position_distance(tile, enfina.position) >= 2 and tile != thrown.position)
	combat.teleport_to(into, near)
	await settle(1)
	var landing: Array = combat.throw_destinations(enfina, hurl, thrown)
	ok(landing.has(into.position), "she can throw it at the bow", "%s" % [into.position])
	var golem_like := {"name": "Golem", "side": 1, "size": Sizes.Size.ENORMOUS, "immune_to": [], "position": Vector2i.ZERO}
	ok("too big" in combat._grip_refusal(enfina, hurl, golem_like), "something two sizes bigger is too heavy")
	var ogre_like := {"name": "Ogre", "side": 1, "size": Sizes.Size.LARGE, "immune_to": [], "position": Vector2i.ZERO}
	ok(combat._grip_refusal(enfina, hurl, ogre_like) == "", "one size bigger she can lift")
	var stone := {"name": "Stone", "side": 1, "size": Sizes.Size.HUMAN, "immune_to": [Immunity.Kind.SHOVED], "position": Vector2i.ZERO}
	ok("cannot be thrown" in combat._grip_refusal(enfina, hurl, stone), "nobody immune to shoving is thrown")
	var hp_thrown: int = thrown.hp
	var hp_into: int = into.hp
	give_turn(enfina)
	var mark := heard.size()
	await combat.use_skill("hurl", enfina, thrown.position, false, false, into.position)
	await settle(2)
	ok(thrown.hp < hp_thrown and into.hp < hp_into, "both are hurt", "%d -> %d, %d -> %d" % [hp_thrown, thrown.hp, hp_into, into.hp])
	ok(thrown.position != into.position and combat.distance_to(thrown, into.position) <= 3, "and the thrown one lands beside", "%s" % [thrown.position])
	ok(heard_since(mark, "hurls"), "and it is told")
	ok(enfina.skill_used_this_turn, "it was her main action")
	log_line("")


## `holder` grabs `held`, beside them, as their main action. A contest of
## Physical: it takes only if `holder` is the stronger.
func hold(holder: Dictionary, held: Dictionary):
	give_turn(holder)
	await combat.use_skill("grab", holder, combat.nearest_tile_of(held, holder.position), false)
	await settle(1)


func held_by(held: Dictionary, holder: Dictionary) -> bool:
	return combat.holder_of(held).get("id", -2) == holder.get("id", -1)


## How many steps of a walk apart two tiles are - a diagonal is one, where
## get_position_distance counts it as two.
func steps_between(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## The first of `count` free tiles in a row, left to right: ground to stand on
## and nobody there. (-99999, -99999) for none.
func free_row(count: int) -> Vector2i:
	var region: Rect2i = combat.controller._astargrid.region
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x - count):
			var clear := true
			for i in count:
				var tile := Vector2i(x + i, y)
				if combat.controller.is_tile_blocking(tile, 0) or not combat.get_combatant_at(tile).is_empty():
					clear = false
			if clear:
				return Vector2i(x, y)
	return Vector2i(-99999, -99999)


## Moves `comb` to `tile` as a step of a walk would - no teleport.
func step_to(comb: Dictionary, tile: Vector2i):
	var from: Vector2i = comb.position
	comb.position = tile
	comb.sprite.position = combat.sprite_point(comb)
	combat.controller.reposition_combatant(from, tile)


func grabbing():
	log_line("======== Grab ========")
	var enfina := who("enfina")
	var grab: SkillDefinition = SkillDatabase.skills.grab
	var grappled := condition("grappled")
	ok(enfina.skill_list.has("grab") and CombatantDatabase.combatants.barbarian.skills.has("grab"), "Enfina and the Barbarian can Grab")
	ok(grab.is_reactive and not grab.is_secondary, "a main action, and a reaction")
	ok(grappled.holds and grappled.prevents_movement, "Grappled holds them still")
	var foe := named("Sellsword 2")
	var other := named("Hired Bow 1")
	sturdy(foe)
	sturdy(other)
	sturdy(enfina)
	var her_physical: int = enfina.stats.get("physical", 10)
	var its_physical: int = foe.stats.get("physical", 10)
	var bow_physical: int = other.stats.get("physical", 10)
	# A grab is a contest of Physical: she is the stronger here, so it takes.
	set_stat(enfina, Stats.Type.PHYSICAL, 99)
	set_stat(foe, Stats.Type.PHYSICAL, 50)
	set_stat(other, Stats.Type.PHYSICAL, 50)
	var golem_like := {"name": "Golem", "side": 1, "size": Sizes.Size.ENORMOUS, "immune_to": [], "position": Vector2i.ZERO}
	ok("too big for Enfina to get hold of" in combat._grip_refusal(enfina, grab, golem_like), "something two sizes bigger is too big to hold",
		combat._grip_refusal(enfina, grab, golem_like))
	var slippery := {"name": "Eel", "side": 1, "size": Sizes.Size.HUMAN, "immune_to": [], "position": Vector2i.ZERO,
		"immune_conditions": [grappled.resource_path]}
	ok("cannot be held" in combat._grip_refusal(enfina, grab, slippery), "nor anybody immune to being Grappled")
	# On her turn.
	ok(pair_up(enfina, foe), "Enfina beside a sellsword")
	await settle(1)
	var mark := heard.size()
	await hold(enfina, foe)
	ok(held_by(foe, enfina), "she has hold of it", "%s" % [combat.conditions_of(foe).map(func(c): return c.display_name)])
	ok(combat.movement_budget_of(foe) == 0, "it cannot move")
	ok(foe.skill_list.has("break_free"), "and can try to break free")
	ok(enfina.skill_used_this_turn, "Grab was her main action")
	# How likely breaking free is.
	set_stat(enfina, Stats.Type.PHYSICAL, 50)
	set_stat(foe, Stats.Type.PHYSICAL, 50)
	ok(combat.break_free_chance(foe, enfina) == combat.GRIP_CHANCE, "half the time against somebody as strong")
	set_stat(foe, Stats.Type.PHYSICAL, 60)
	ok(combat.break_free_chance(foe, enfina) == combat.GRIP_CHANCE + 10, "a point more for every point stronger")
	set_stat(foe, Stats.Type.PHYSICAL, 300)
	ok(combat.break_free_chance(foe, enfina) == combat.GRIP_MAX, "never more than the most")
	set_stat(foe, Stats.Type.PHYSICAL, 0)
	ok(combat.break_free_chance(foe, enfina) == combat.GRIP_MIN, "never less than the least")
	# Getting hold is a contest of Physical, with no roll: never a miss on
	# anybody weaker, never a hold on anybody as strong.
	ok(grab.uses_stat_contest and grab.contest_stat == Stats.Type.PHYSICAL and grab.scaling_stat == Stats.Type.PHYSICAL,
		"a grab is her Physical against theirs, with no hit roll")
	set_stat(foe, Stats.Type.PHYSICAL, 49)
	ok(combat.wins_contest(enfina, foe, grab), "anybody weaker is always grabbed")
	set_stat(foe, Stats.Type.PHYSICAL, 50)
	ok(not combat.wins_contest(enfina, foe, grab) and not combat.predict_hit(enfina, foe, grab).wins,
		"anybody as strong never is, and the hover says so")
	set_stat(foe, Stats.Type.PHYSICAL, 0)
	# Held, it fights from where it stands while it can.
	ok(combat._ai_can_strike_from_here(foe), "held beside her, it can still hit her from there")
	# Its swing meant for somebody it can no longer reach - grabbed on the way -
	# goes on whoever it can.
	var far_one := who("prometheus")
	combat.teleport_to(far_one, a_tile(far_one, func(tile): return combat.distance_to(foe, tile) >= 4))
	var hp_before: int = enfina.hp
	give_turn(foe)
	await combat.use_skill("greatsword_attack", foe, far_one.position, false)
	await settle(1)
	ok(foe.skill_used_this_turn and enfina.hp < hp_before, "grabbed short of its mark, it hits the one holding it instead of nothing",
		"%d -> %d" % [hp_before, enfina.hp])
	# Its main action goes on breaking free.
	give_turn(foe)
	await combat.use_skill("break_free", foe, combat.nearest_tile_of(enfina, foe.position), false)
	await settle(1)
	ok(foe.skill_used_this_turn, "breaking free is the main action")
	ok(heard_since(mark, "strains against") or heard_since(mark, "breaks free"), "and it is told")
	combat.seed_rolls(7)
	var tries := 0
	while combat.is_held(foe) and tries < 80:
		combat.break_free(foe, enfina)
		tries += 1
	ok(not combat.is_held(foe) and not foe.skill_list.has("break_free"), "in the end it breaks free, and Break Free is gone", "%d tries" % tries)
	ok(heard_since(mark, "breaks free of Enfina"), "and it is told")
	set_stat(enfina, Stats.Type.PHYSICAL, 99)
	set_stat(foe, Stats.Type.PHYSICAL, 50)
	# Freed in the turn it was grabbed, what was left of its walk comes back.
	await hold(enfina, foe)
	give_turn(foe)
	combat.controller.movement = 0
	foe["movement_left_when_grabbed"] = 2
	combat._let_go(foe)
	ok(combat.controller.movement == 2, "freed the turn it was grabbed, it has what was left of its walk", "%d" % combat.controller.movement)
	# Weaker than what she grabs at, a grab always slips.
	set_stat(enfina, Stats.Type.PHYSICAL, 0)
	set_stat(foe, Stats.Type.PHYSICAL, 300)
	var slipped := heard.size()
	for i in 40:
		if heard_since(slipped, "twists out of"):
			break
		give_turn(enfina)
		await combat.use_skill("grab", enfina, combat.nearest_tile_of(foe, enfina.position), false)
		combat._let_go(foe)
	ok(heard_since(slipped, "twists out of") and not combat.is_held(foe), "a grab on somebody stronger: it twists out of her grab")
	set_stat(enfina, Stats.Type.PHYSICAL, 99)
	set_stat(foe, Stats.Type.PHYSICAL, 50)
	# One at a time.
	await hold(enfina, foe)
	ok(beside(other, enfina), "a hired bow beside her too")
	await hold(enfina, other)
	ok(held_by(other, enfina) and not combat.is_held(foe), "grabbing another lets the first go")
	# Teleported.
	combat.teleport_to(enfina, a_tile(enfina, func(tile): return combat.distance_to(other, tile) >= 3))
	ok(not combat.is_held(other), "teleported, she lets go")
	# Walked away: she drags it after her (Combat "Dragging"), every tile at twice
	# the movement - it is no smaller than she is.
	# Three free tiles in a row: the sellsword on the last, Enfina beside it, and
	# room for her to step away.
	var lane := free_row(3)
	ok(lane.x != -99999, "three free tiles in a row", "%s" % lane)
	step_to(foe, lane + Vector2i(2, 0))
	step_to(enfina, lane + Vector2i(1, 0))
	await hold(enfina, foe)
	ok(combat.drag_cost(enfina) == 2, "holding somebody her own size, every tile costs her two")
	var free_reach: int = 0
	var dragging_reach: int = 0
	for tile in combat.controller.get_reachable_tiles(enfina.position, 0, 6, enfina):
		dragging_reach = maxi(dragging_reach, steps_between(tile, enfina.position))
	var foe_size: int = foe.size
	foe.size = Sizes.Size.SMALL
	ok(combat.drag_cost(enfina) == 1, "somebody a size smaller costs her nothing more")
	for tile in combat.controller.get_reachable_tiles(enfina.position, 0, 6, enfina):
		free_reach = maxi(free_reach, steps_between(tile, enfina.position))
	foe.size = foe_size
	ok(dragging_reach <= 3 and free_reach > dragging_reach, "so six movement takes her three tiles with it, and further without",
		"%d and %d" % [dragging_reach, free_reach])
	var foe_was: Vector2i = foe.position
	var enfina_was: Vector2i = enfina.position
	step_to(enfina, lane)
	var dragged: bool = combat.drag_held(enfina)
	combat.check_holds()
	ok(dragged and combat.is_held(foe) and foe.position != foe_was and combat.rect_gap(combat.rect_of(enfina), combat.rect_of(foe)) <= 1,
		"a step away, and she drags it along beside her", "she %s -> %s, it %s -> %s, dragged %s, held %s" % [
			enfina_was, enfina.position, foe_was, foe.position, dragged, combat.is_held(foe)])
	# Somewhere it was not walked to, nobody is dragged after her: she lets go.
	step_to(enfina, a_tile(enfina, func(tile): return combat.distance_to(foe, tile) >= 3))
	combat.check_holds()
	ok(not combat.is_held(foe), "not beside it any more, and not by walking, she has let go")
	# Shoved - the held, and the holder.
	var push := EffectDefinition.new()
	push.type = EffectDefinition.EffectType.PUSH
	push.knockback_distance = 1
	ok(pair_up(enfina, foe), "beside it again")
	await hold(enfina, foe)
	combat.apply_knockback(other, foe, push, false)
	ok(not combat.is_held(foe), "shoved, it is out of her grip")
	ok(pair_up(enfina, foe), "and again")
	await hold(enfina, foe)
	combat.apply_knockback(foe, enfina, push, false)
	ok(not combat.is_held(foe), "and so it is when she is the one shoved")
	# Thrown: Grab, then Hurl.
	ok(pair_up(enfina, foe), "and again")
	await hold(enfina, foe)
	give_turn(enfina)
	var landing: Array = combat.throw_destinations(enfina, SkillDatabase.skills.hurl, foe)
	ok(not landing.is_empty(), "somewhere to throw it")
	if not landing.is_empty():
		await combat.use_skill("hurl", enfina, foe.position, false, false, landing[0])
		await settle(1)
	ok(not combat.is_held(foe), "thrown, it is free")
	# Down, she holds nobody.
	ok(pair_up(enfina, foe), "and again")
	await hold(enfina, foe)
	enfina.alive = false
	combat.check_holds()
	enfina.alive = true
	ok(not combat.is_held(foe), "with her down, nobody holds it")
	# As a reaction: grabbed on the way out, and dragged back - tried again
	# until the grab takes, since it can miss.
	set_stat(enfina, Stats.Type.PHYSICAL, 300)
	set_stat(foe, Stats.Type.PHYSICAL, 0)
	var asked := false
	var names: Array = []
	var was := Vector2i.ZERO
	for attempt in 10:
		ok(pair_up(enfina, foe), "beside it once more")
		await settle(1)
		was = foe.position
		var out := a_tile(foe, func(tile): return combat.distance_to(enfina, tile) == 2 and combat.get_position_distance(tile, was) == 1)
		if out.x == -99999:
			ok(false, "a step out of her reach")
			break
		step_to(foe, out)
		enfina.reaction_used = false
		var done := [false]
		var leave := func():
			await combat.check_reactive_skills(foe, was, out)
			done[0] = true
		leave.call()
		asked = await until(func(): return combat.reaction_prompt.is_asking())
		if not asked:
			break
		var buttons: Array = combat.reaction_prompt.get_node("Panel/VBox/Buttons").get_children().filter(func(b): return b is Button and b.visible)
		names = buttons.map(func(b): return b.text)
		combat.reaction_prompt._choose(names.find("Grab"))
		await until(func(): return done[0])
		if held_by(foe, enfina):
			break
	ok(asked, "she is asked")
	ok(names.has("Greatsword Attack") and names.has("Grab") and names.has("Skip"), "a swing, a grab, or neither", "%s" % [names])
	ok(held_by(foe, enfina), "it is grabbed")
	ok(foe.position == was, "and dragged back beside her", "%s, was %s" % [foe.position, was])
	ok(enfina.reaction_used, "spending her reaction")
	await settle(2)
	ok(combat.reaction_prompt.get_node("Panel/VBox/Buttons").get_children().filter(func(b): return b is Button and b.visible).size() == 2,
		"the prompt is back to Use and Skip")
	combat._let_go(foe)
	combat._let_go(other)
	set_stat(enfina, Stats.Type.PHYSICAL, her_physical)
	set_stat(foe, Stats.Type.PHYSICAL, its_physical)
	set_stat(other, Stats.Type.PHYSICAL, bow_physical)
	log_line("")


func ignoring_defense():
	log_line("======== Ignores Defense ========")
	var alithia := who("alithia")
	var foe := named("Hired Bow 1")
	var kept: int = foe.stats.get("defense", 10)
	set_stat(foe, Stats.Type.DEFENSE, 60)
	var spike: SkillDefinition = SkillDatabase.skills.water_spike.duplicate()
	spike.ignores_defense = 0
	var none: int = combat.skill_damage(alithia, foe, spike)
	ok(combat.defense_against(foe, spike) == 60, "ignoring none of it, a hit meets all of their Defense")
	spike.ignores_defense = 50
	var half: int = combat.skill_damage(alithia, foe, spike)
	ok(combat.defense_against(foe, spike) == 30, "ignoring half, it meets half")
	spike.ignores_defense = 100
	var all: int = combat.skill_damage(alithia, foe, spike)
	ok(none < half and half < all, "and lands harder the more it ignores", "%d, %d, %d" % [none, half, all])
	var bare := Stats.final_damage(combat.power_behind(alithia, spike),
		spike.ability_modifier * combat.damage_dealt_multiplier(alithia, foe, spike), 0)
	ok(all == bare, "ignoring all of it is a hit on no Defense at all", "%d vs %d" % [all, bare])
	set_stat(foe, Stats.Type.DEFENSE, kept)
	log_line("")


func nerve():
	log_line("======== Nerve ========")
	var champion := who("pit_champion")
	var sellsword := named("Sellsword 1")
	var bow := named("Hired Bow 1")
	ok(combat.can_break(sellsword), "a sellsword can break")
	var reasons: Array = combat.shaken_by(sellsword)
	ok(not reasons.any(func(r): return r[0] == "their leader is down"), "nothing has shaken it yet", "%s" % [reasons])
	combat.lose_hp(champion, champion.hp)
	combat.combatant_die(champion)
	reasons = combat.shaken_by(sellsword)
	ok(reasons.any(func(r): return r[0] == "their leader is down"), "the champion down shakes them", "%s" % [reasons])
	# Badly hurt as well: the sellsword gives up.
	sellsword.hp = maxi(roundi(sellsword.max_hp * 0.2), 1)
	ok(combat.check_nerve(sellsword), "badly hurt, with its leader down, it breaks", "%d of %d" % [combat.shaken(sellsword), sellsword.nerve])
	ok(sellsword.get("taken", "") == "surrendered" and not sellsword.alive, "and surrenders")
	ok(combat.prisoners().has(sellsword), "a prisoner")
	# The bow runs - on a map with no ways out, for nowhere (running_for_a_way_out()
	# runs for one).
	var ways_out: Array = combat.escape_points
	combat.escape_points = []
	bow.hp = bow.max_hp
	var alithia := who("alithia")
	ok(combat.check_nerve(bow), "a hired bow breaks at its leader's fall", "%d of %d" % [combat.shaken(bow), bow.nerve])
	ok(bow.get("fleeing", 0) == combat.FLEE_TURNS and bow.alive, "and runs")
	ok(heard.any(func(line): return "There is none" in line), "and with no way out, it is told so")
	var foe: Dictionary = combat.find_nearest_enemy_of(bow)
	var gap: int = combat.get_position_distance(bow.position, foe.position)
	await enemy_turn(bow, alithia)
	ok(combat.get_position_distance(bow.position, foe.position) >= gap, "away from the party", "%d -> %d" % [gap, combat.get_position_distance(bow.position, foe.position)])
	for i in 3:
		await enemy_turn(bow, alithia)
	ok(bow.alive and not bow.has("taken") and bow.get("fleeing", 0) > 0, "with no way out of the fight, it never gets away", bow.get("taken", "still here"))
	# A way out right beside it, and it is gone.
	var door := a_tile(bow, func(tile): return combat.get_position_distance(tile, bow.position) == 1)
	combat.escape_points = [door]
	await enemy_turn(bow, alithia)
	ok(bow.get("taken", "") == "fled", "given a way out, it is gone", bow.get("taken", "still here"))
	ok(not combat.prisoners().has(bow), "and nobody's prisoner")
	log_line("")

	log_line("======== Getting away ========")
	ok(Campaign.flag("hired_bow_got_away"), "the bow got away, and the flag says so")
	var due: Array = combat._returning.filter(func(entry): return entry.comb == bow)
	ok(due.size() == 1 and due[0].round == combat.round_number + bow.back_after_rounds, "it is coming back",
		"round %d" % (due[0].round if not due.is_empty() else -1))
	var help: Array = combat.arriving().filter(func(spawn): return spawn.combatant_key == "sellsword")
	ok(help.size() == 1, "with a sellsword beside it")
	var swords_before: int = combat.combatants.filter(func(c): return c.get("combatant_key", "") == "sellsword").size()
	if not due.is_empty():
		combat.round_number = due[0].round
	combat._bring_back_the_fled()
	combat._bring_in_arrivals()
	await settle(2)
	ok(bow.alive and not bow.has("taken") and combat.groups[1].has(combat.combatants.find(bow)), "and back it comes",
		"%s" % [bow.position])
	ok(bow.get("shaken", 0) == 0, "its nerve steadied")
	ok(combat.combatants.filter(func(c): return c.get("combatant_key", "") == "sellsword").size() == swords_before + 1,
		"with the help it brought")
	combat.escape_points = ways_out
	log_line("")


## Ways out (EncounterDefinition.escape_points): a broken enemy runs for one by
## every means it has, and is gone once it stands on one.
func running_for_a_way_out():
	log_line("======== Ways out ========")
	ok(combat.escape_points.size() == 2, "Hired Blades has two ways out", "%s" % [combat.escape_points])
	var alithia := who("alithia")
	# Back after getting away (nerve()), and with Run.
	var bow := named("Hired Bow 1")
	ok(bow.alive and bow.skill_list.has("run"), "a hired bow with Run to run with", "%s %s" % [bow.alive, bow.skill_list])
	sturdy(bow)
	var budget: int = combat.movement_budget_of(bow)
	# Somewhere it can only reach this turn by running: further than it walks,
	# no further than Run doubles that to.
	var reach: Dictionary = combat.controller.get_reachable_tiles(bow.position, bow.movement_class, budget * 2, bow)
	var far := Vector2i(-99999, -99999)
	for tile in reach:
		if reach[tile] > budget + 1 and combat.get_combatant_at(tile).is_empty():
			far = tile
			break
	ok(far.x != -99999, "a tile only Run gets it to this turn", "%s" % [far])
	var kept: Array = combat.escape_points
	combat.escape_points = [far]
	ok(combat._left_to_run(bow, bow.position, combat._escape_field(bow)) > budget, "too far to walk")
	bow["fleeing"] = combat.FLEE_TURNS
	var mark := heard.size()
	await enemy_turn(bow, alithia)
	ok(bow.get("taken", "") == "fled", "it runs for it - Run, then its feet - and is gone once it stands on it",
		"%s at %s, %s" % [bow.get("taken", "still here"), bow.position, far])
	ok(heard_since(mark, "Run"), "and Run was what got it there")
	# A way out with somebody standing on it is shut.
	var bow_one := named("Sellsword 2")
	ok(bow_one.alive, "somebody else to run", bow_one.get("name", "nobody"))
	sturdy(bow_one)
	var door: Vector2i = a_tile(alithia, func(tile): return combat.get_position_distance(tile, bow_one.position) >= 3, bow_one.position)
	combat.teleport_to(alithia, door)
	combat.escape_points = [door]
	ok(combat._escape_field(bow_one).is_empty(), "Alithia stands on the only way out, and it is shut")
	bow_one["fleeing"] = combat.FLEE_TURNS
	await enemy_turn(bow_one, alithia)
	ok(bow_one.alive and not bow_one.has("taken"), "so it cannot get away", bow_one.get("taken", ""))
	bow_one.erase("fleeing")
	combat.escape_points = kept
	log_line("")


func taking_them_alive():
	log_line("======== Taking them alive ========")
	ok(combat.game_ui.get_node_or_null("Actions/TakeAliveButton") == null, "there is no switch: it is always so")
	ok(named("Pit Champion").get("taken", "") == "knocked_out", "the champion, felled, was knocked out")
	var enfina := who("enfina")
	var last := named("Sellsword 2")
	last.hp = 1
	var mark := heard.size()
	combat.do_damage(enfina, last, EffectDefinition.new(), SkillDatabase.skills.greatsword_attack)
	ok(last.get("taken", "") == "knocked_out", "a killing blow knocks out instead", last.get("taken", "dead"))
	ok(heard_since(mark, "knocked out"), "and it says so")
	ok(combat.prisoners().has(last), "a prisoner")
	var stone := {"name": "Stone", "side": 1, "immune_to": [Immunity.Kind.TAKEN_ALIVE], "status_effects": []}
	ok(not combat._knocks_out(stone), "somebody who cannot be taken alive is not")
	var bomber := {"name": "Bomber", "side": 1, "immune_to": [], "status_effects": [], "killed_itself": true}
	ok(not combat._knocks_out(bomber), "nor somebody who blew themselves up")
	ok(not combat._knocks_out(who("alithia")), "and nobody of the party's")
	log_line("")


func questioning():
	log_line("======== Questioning ========")
	var gold: int = Campaign.gold
	var learned: Array = Campaign.interrogate("sellsword")
	ok(learned.any(func(line): return "stashed" in line) and Campaign.gold == gold + 30, "a sellsword gives up its stash", "%s" % [learned])
	ok(Campaign.flag(Campaign.LEVERAGE_PREFIX + "sellsword"), "and leverage on its kind")
	ok(Campaign.interrogate("sellsword").is_empty(), "questioned again, nothing new")
	var panel := InterrogationPanel.new()
	combat.game_ui.add_child(panel)
	var prisoners: Array = combat.prisoners()
	panel.show_prisoners(prisoners)
	ok(prisoners.size() >= 2, "both taken are there to question", "%d" % prisoners.size())
	var row := panel.row_of(prisoners[0].name)
	(row.find_child("Question", true, false) as Button).pressed.emit()
	await settle(2)
	var said: Label = row.find_child("Learned", true, false)
	ok(said.visible and said.text != "", "questioned, it says what they told", said.text.replace("\n", " | "))
	(row.find_child("HandOver", true, false) as Button).pressed.emit()
	await settle(2)
	ok(int(Campaign.flags.get("prisoners_handed_over", 0)) == 1, "handed over, and counted")
	var done := [false]
	panel.done.connect(func(): done[0] = true)
	panel._done_button.pressed.emit()
	ok(done[0], "Done hands back to the results")
	panel.queue_free()
	log_line("")


func parley():
	log_line("======== Parley ========")
	Campaign.gold = 200
	Campaign.parley_remove("sellsword", 1)
	ok(Campaign.can_afford_bribe("hired_bow", true), "the party can buy a bow onto their side")
	ok(Campaign.bribe("hired_bow", true) and Campaign.gold == 200 - 80, "and does - twice its price", "%d" % Campaign.gold)
	ok(not Campaign.bribe("pit_champion"), "the champion cannot be bought")
	Campaign.parley_surprise()
	await open_fight(BLADES)
	var swords: Array = combat.combatants.filter(func(c): return c.get("combatant_key", "") == "sellsword")
	ok(swords.size() == 1, "one sellsword agreed to stay out of it", "%d" % swords.size())
	var bows: Array = combat.combatants.filter(func(c): return c.get("combatant_key", "") == "hired_bow")
	ok(bows.any(func(b): return b.side == 0 and b.has("turncoat")), "a bow fights for the party")
	ok(combat.combatants.filter(func(c): return c.side == 1 and c.alive).all(func(c): return has_condition(c, "surprised")),
		"and the rest are caught off guard")
	ok(Campaign.parley.is_empty(), "the agreement is spent")
	await close_fight()
	log_line("")


## The grid fitted to the golem on its turn - every tile its square does not fit
## closed - is open again for whoever is next. It once was not: after a golem's
## turn the party could step nowhere but a tile somebody had just left.
func after_something_big():
	log_line("======== After something big ========")
	var golem := who("golem")
	var cyrus := who("cyrus")
	var grid: AStarGrid2D = combat.controller._astargrid
	# A free tile right beside somebody else: Cyrus fits there, the golem's square
	# anchored there does not.
	var beside_somebody := a_tile(cyrus, func(tile):
		var right: Dictionary = combat.get_combatant_at(tile + Vector2i.RIGHT)
		return not right.is_empty() and right != golem and right != cyrus)
	ok(beside_somebody.x != -99999, "a free tile beside somebody", "%s" % [beside_somebody])
	give_turn(golem)
	ok(grid.is_point_solid(beside_somebody), "on the golem's turn it is shut - its square does not fit there")
	give_turn(cyrus)
	ok(not grid.is_point_solid(beside_somebody), "on Cyrus's, it is open again")
	var path: PackedVector2Array = grid.get_point_path(cyrus.position, beside_somebody)
	ok(not path.is_empty(), "and he can walk there", "%d points" % path.size())
	log_line("")


## Cyrus's gun on the golem, from below and to the right of it - where a line to
## its top-left corner crosses the rest of it. Its own body is no cover to it:
## once, aiming checked the line to that corner and refused every shot.
func shooting_something_big():
	log_line("======== Shooting something big ========")
	var golem := who("golem")
	var cyrus := who("cyrus")
	var rect: Rect2i = combat.rect_of(golem)
	ok(rect.size.x > 1, "the golem is bigger than a tile", "%s" % [rect.size])
	var spot := a_tile(cyrus, func(tile): return tile.x >= rect.end.x and tile.y >= rect.end.y \
		and combat.distance_to(golem, tile) >= 3 and combat.distance_to(golem, tile) <= 6, rect.end)
	ok(spot.x != -99999 and combat.teleport_to(cyrus, spot) or cyrus.position == spot, "Cyrus below and right of it", "%s" % [spot])
	give_turn(cyrus)
	var controller = combat.controller
	controller.set_selected_skill("gun")
	controller.begin_target_selection()
	var near: Vector2i = combat.nearest_tile_of(golem, cyrus.position)
	var corner_line: bool = combat.has_line_of_sight(cyrus.position, golem.position, cyrus.movement_class)
	log_line("  NOTE  a line to its corner %s" % ("is clear" if corner_line else "crosses its own body"))
	ok(controller.refusal_at(near, golem) == "", "the nearest of it can be shot", controller.refusal_at(near, golem))
	ok(controller.aim_refusal(golem) == "", "and so can its face in the queue", controller.aim_refusal(golem))
	var seen: Array = combat.tiles_of(golem).filter(func(tile): return tile in controller._range_preview_positions)
	ok(seen.size() > 1, "more of it than its nearest tile is in sight - it is no cover to itself", "%d of %d" % [seen.size(), combat.tiles_of(golem).size()])
	controller.cancel_skill_selection()
	# Not only Cyrus: every one of the party, from the same spot, one at a time -
	# with nobody else in the way, who would be cover - with every shot of theirs
	# that needs a clear line.
	var refused := []
	var tried := 0
	var homes := {}
	for key in ["alithia", "enfina", "prometheus"]:
		var other := who(key)
		if not other.is_empty():
			homes[key] = other.position
	combat.teleport_to(cyrus, a_tile(cyrus, func(tile): return combat.distance_to(golem, tile) >= 8))
	for key in ["alithia", "enfina", "prometheus", "cyrus"]:
		var shooter := who(key)
		if shooter.is_empty() or not (combat.teleport_to(shooter, spot) or shooter.position == spot):
			continue
		give_turn(shooter)
		for skill_key in shooter.skill_list:
			var skill: SkillDefinition = SkillDatabase.skills.get(skill_key)
			if skill == null or not skill.respects_blocking or skill.aoe_radius > 0 or skill.targets_ally or skill.targets_fallen \
					or not skill.deals_damage or not combat.meets_level_for(shooter, skill):
				continue
			var aim: Vector2i = combat.nearest_tile_of(golem, shooter.position)
			var gap: int = combat.distance_to(shooter, aim)
			if gap < skill.min_range or gap > combat.effective_max_range(shooter, skill):
				continue
			controller.set_selected_skill(skill_key)
			controller.begin_target_selection()
			tried += 1
			var why: String = controller.refusal_at(aim, golem)
			if why != "":
				refused.append("%s's %s: %s" % [shooter.name, skill.name, why])
			controller.cancel_skill_selection()
		# Back where they were, out of the next one's way.
		if key != "cyrus":
			combat.teleport_to(shooter, homes[key])
	ok(tried >= 3 and refused.is_empty(), "and so can every one of the party, with every shot that needs a clear line",
		"%d tried, refused: %s" % [tried, refused])
	log_line("")


## The view on the golem's turn: on the middle of the square it stands on, not
## the corner its node is at, and pulled back until all of it fits - then back
## in again once its turn is done.
func watching_something_big():
	log_line("======== Watching something big ========")
	var golem := who("golem")
	var camera = combat.camera
	var span: int = golem.span
	camera.zoom = Vector2.ONE * camera.max_zoom
	await settle(1)
	var before: float = camera.zoom.x
	combat.watch_combatant(golem)
	await get_tree().create_timer(0.8).timeout
	var middle: Vector2 = golem.sprite.global_position + Vector2(Grid.TILE_SIZE, Grid.TILE_SIZE) * 0.5 * (span - 1)
	ok(camera.position.distance_to(middle) < Grid.TILE_SIZE * 0.25, "it watches the middle of the golem, not its corner",
		"%s vs %s" % [camera.position, middle])
	var shown: Vector2 = camera.get_visible_world_size()
	var big: float = Grid.TILE_SIZE * span
	ok(camera.zoom.x < before and shown.x >= big and shown.y >= big, "pulled back until all of it fits",
		"zoom %.2f -> %.2f, %s on screen for %d" % [before, camera.zoom.x, shown, big])
	combat.stop_watching()
	await get_tree().create_timer(0.8).timeout
	ok(is_equal_approx(camera.zoom.x, before), "and back in once its turn is done", "%.2f" % camera.zoom.x)
	log_line("")


## Melee and ranged moves (SkillDefinition.melee): every skill reaching only the
## tile beside, and everything Enfina has but Fire Burst, is melee.
func melee_and_ranged():
	log_line("======== Melee and ranged ========")
	var wrong := []
	for key in SkillDatabase.skills:
		var skill: SkillDefinition = SkillDatabase.skills[key]
		if skill is ItemDefinition:
			continue
		if skill.max_range == 1 and not Combat.is_melee(skill):
			wrong.append(key)
	ok(wrong.is_empty(), "everything that reaches only the tile beside is melee", "%s" % [wrong])
	var hers: Array = CombatantDatabase.combatants.enfina.skills.duplicate()
	for path in ["vanguard", "juggernaut", "warden_of_cover"]:
		var definition = load("res://data/subclasses/%s.tres" % path)
		if definition != null:
			hers.append_array(definition.skills)
	var not_melee: Array = hers.filter(func(key): return key != "fire_burst" and SkillDatabase.skills.has(key) and not Combat.is_melee(SkillDatabase.skills[key]))
	ok(not_melee.is_empty(), "and everything Enfina has, her paths' too", "%s" % [not_melee])
	ok(not Combat.is_melee(SkillDatabase.skills.fire_burst), "but Fire Burst")
	ok(not Combat.is_melee(SkillDatabase.skills.gun) and not Combat.is_melee(SkillDatabase.skills.fireball), "and a shot or a spell is ranged")
	log_line("")


## Up on something, a melee shove at it moves it nowhere.
func riders_cannot_shove():
	log_line("======== Riders cannot shove ========")
	var enfina := who("enfina")
	var behemoth := who("behemoth")
	sturdy(enfina)
	sturdy(behemoth, 3000)
	ok(beside(enfina, behemoth), "Enfina beside the behemoth")
	give_turn(enfina)
	await combat.use_skill("climb", enfina, combat.nearest_tile_of(behemoth, enfina.position), false)
	await settle(1)
	ok(enfina.get("riding", -1) == behemoth.id, "up on it")
	var shove: SkillDefinition = SkillDatabase.skills.shoving_strike
	var push: EffectDefinition = shove.effects.filter(func(effect): return effect != null and effect.type == EffectDefinition.EffectType.PUSH)[0]
	var was: Vector2i = behemoth.position
	var mark := heard.size()
	combat.apply_knockback(enfina, behemoth, push, false, shove)
	ok(behemoth.position == was, "a melee shove from up there moves it nowhere", "%s -> %s" % [was, behemoth.position])
	ok(heard_since(mark, "cannot shift"), "and says so")
	give_turn(enfina)
	var jump := a_tile(enfina, func(tile): return combat.distance_to(enfina, tile) <= 3 and combat.distance_to(enfina, tile) >= 1)
	await combat.use_skill("climb_down", enfina, jump, false, true)
	log_line("")


func body_parts():
	log_line("======== Body parts ========")
	var golem := who("golem")
	var enfina := who("enfina")
	sturdy(golem, 2000)
	ok(golem.get("parts", []).size() == 3, "the golem has legs, arms and a core to break")
	var legs: Vector2i = golem.position + Vector2i(1, 3)
	ok("Legs" in combat.part_note(golem, legs), "aimed at its legs, the hover says so", combat.part_note(golem, legs))
	ok(combat.part_note(golem, golem.position) == "", "a tile with no part says nothing")
	ok(not combat.part_marks().is_empty(), "the board has the parts to outline")
	var leg_mark: Array = combat.part_marks().filter(func(mark): return mark.id == golem.id and legs in mark.tiles)
	ok(leg_mark.size() == 1 and leg_mark[0].name == "Legs" and leg_mark[0].kind == BodyPartDefinition.Broken.ROOTED,
		"each mark says whose, what it is called and what breaking it does - for its colour and its name on the board",
		"%s" % [leg_mark])
	ok(BodyPartDefinition.Broken.values().all(func(kind): return combat.controller.PART_COLOURS.has(kind)),
		"every way a part breaks has its own colour")
	combat.controller._note_hover(legs)
	ok(combat.controller._hover_tile == legs, "the pointer on its legs is remembered, to light them")
	var legs_hp: int = golem.parts_hp[0]
	ok(legs_hp > 0, "each part has its share of health", "%d" % legs_hp)
	# Something with an area, aimed at its legs, lands on the whole golem.
	ok(combat.aims_at_parts(enfina, SkillDatabase.skills.greatsword_attack) and not combat.aims_at_parts(enfina, SkillDatabase.skills.sweep_strike),
		"a blow at one tile can be aimed at a part, and one with an area cannot")
	var blast: SkillDefinition = SkillDatabase.skills.greatsword_attack.duplicate(true)
	blast.max_range = 99
	blast.aoe_radius = 1
	blast.melee = false
	blast.respects_blocking = false
	SkillDatabase.skills["_test_blast"] = blast
	enfina.skill_list.append("_test_blast")
	var golem_hp: int = golem.hp
	give_turn(enfina)
	await combat.use_skill("_test_blast", enfina, legs, false)
	await settle(3)
	ok(golem.hp < golem_hp and golem.parts_hp[0] == legs_hp, "a blast on its legs hurts the golem and leaves its legs be",
		"%d -> %d, legs %d -> %d" % [golem_hp, golem.hp, legs_hp, golem.parts_hp[0]])
	enfina.skill_list.erase("_test_blast")
	SkillDatabase.skills.erase("_test_blast")
	combat._aimed_tile = legs
	var guard := 0
	while not combat.part_broken(golem, 0) and guard < 200:
		combat.do_damage(enfina, golem, EffectDefinition.new(), SkillDatabase.skills.greatsword_attack)
		guard += 1
	combat._aimed_tile = null
	ok(combat.part_broken(golem, 0), "hit there enough, the legs break")
	ok(combat.has_restriction(golem, "prevents_movement"), "and it cannot move")
	golem["parts_broken"].append(1)
	golem["parts_broken"].append(2)
	ok(is_equal_approx(combat.parts_multiplier(golem, enfina), 0.6), "arms broken, it hits for less")
	ok(is_equal_approx(combat.parts_multiplier(enfina, golem), 1.3), "plate broken, it is hit harder")
	var behemoth := who("behemoth")
	ok(behemoth.skill_list.has("ground_pound"), "the behemoth can pound the ground")
	combat._break_part(behemoth, 1)
	ok(not behemoth.skill_list.has("ground_pound"), "until its tusks are broken")
	log_line("")


func climbing():
	log_line("======== Climb ========")
	var enfina := who("enfina")
	var behemoth := who("behemoth")
	var golem := who("golem")
	var climb: SkillDefinition = SkillDatabase.skills.climb
	sturdy(enfina)
	sturdy(behemoth, 3000)
	ok("not big enough" in combat._grip_refusal(enfina, climb, golem), "an enormous golem is not big enough to climb")
	ok(beside(enfina, behemoth), "Enfina beside the behemoth")
	await settle(1)
	give_turn(enfina)
	var target_tile: Vector2i = combat.nearest_tile_of(behemoth, enfina.position)
	await combat.use_skill("climb", enfina, target_tile, false)
	await settle(1)
	ok(enfina.get("riding", -1) == behemoth.id, "she climbs up onto it")
	ok(combat.tiles_of(enfina).is_empty() and combat.get_combatant_at(enfina.position) == behemoth, "standing on none of the ground")
	ok(enfina.skill_list.has("climb_down") and has_condition(enfina, "riding"), "riding, with a way down")
	ok(not combat.ai_worth_table(behemoth, SkillDatabase.skills.greatsword_attack).has(enfina.id), "nobody can reach her up there")
	var up: float = combat.damage_dealt_multiplier(enfina, behemoth, SkillDatabase.skills.greatsword_attack)
	var far_tile: Vector2i = behemoth.position + Vector2i(7, 7)
	ok(combat.distance_to(enfina, far_tile) > 1, "the far side of it is out of a sword's reach from where she sits")
	var refused_far: String = combat.refusal_for(enfina, SkillDatabase.skills.greatsword_attack, far_tile)
	ok(refused_far == "", "but nothing rules a blow on it out", refused_far)
	var offset: Vector2i = enfina.position - behemoth.position
	var moved := a_tile(behemoth, func(tile): return combat.get_position_distance(tile, behemoth.position) >= 2)
	ok(combat.teleport_to(behemoth, moved), "the behemoth goes elsewhere")
	ok(enfina.position == behemoth.position + offset, "and carries her with it")
	var hp: int = enfina.hp
	set_stat(enfina, Stats.Type.PHYSICAL, 0)
	set_stat(behemoth, Stats.Type.PHYSICAL, 99)
	var tries := 0
	while enfina.has("riding") and tries < 30:
		combat._ai_shake_off(behemoth)
		tries += 1
	ok(enfina.hp < hp, "shaking her hurts")
	ok(not enfina.has("riding") and combat.room_for(enfina, enfina.position), "and in the end she is thrown clear", "%d tries" % tries)
	ok(not enfina.skill_list.has("climb_down") and not has_condition(enfina, "riding"), "with nothing of riding left")
	var down: float = combat.damage_dealt_multiplier(enfina, behemoth, SkillDatabase.skills.greatsword_attack)
	ok(is_equal_approx(up, down * combat.RIDING_BONUS), "her blows on it landed harder from up there", "%.2f vs %.2f" % [up, down])
	# Up again, and down by her own choice.
	ok(beside(enfina, behemoth), "beside it again")
	give_turn(enfina)
	await combat.use_skill("climb", enfina, combat.nearest_tile_of(behemoth, enfina.position), false)
	give_turn(enfina)
	var jump := a_tile(enfina, func(tile): return combat.distance_to(enfina, tile) <= 3 and combat.distance_to(enfina, tile) >= 1)
	await combat.use_skill("climb_down", enfina, jump, false, true)
	ok(not enfina.has("riding") and enfina.position == jump, "Climb Down puts her on the ground", "%s" % [enfina.position])
	log_line("")


func rebinding():
	log_line("======== Rebind ========")
	var golem := who("golem")
	var prometheus := who("prometheus")
	ok(golem.get("bound_to", "") != "" and golem.get("rebind_hack") != null, "the golem is bound, with a binding to hack")
	ok("rebind" in combat.game_ui._queue_tip(golem), "the queue says so")
	var spot := a_tile(prometheus, func(tile): return combat.distance_to(golem, tile) <= 3 and combat.distance_to(golem, tile) >= 1)
	combat.teleport_to(prometheus, spot)
	give_turn(prometheus)
	var running := func(): await combat.use_skill("hack", prometheus, combat.nearest_tile_of(golem, prometheus.position), false)
	running.call()
	ok(await until(func(): return Hacking.running() and Hacking.board() != null), "the hack begins")
	var board: RewriteBoard = Hacking.board()
	ok(board != null and board.hack.title == "The Golem's Binding", "on its binding")
	for move in board.solve_moves(board.values, board.budget - board.spent):
		board.change(move[0], move[1])
	board.commit()
	await until(func(): return not Hacking.running())
	await settle(3)
	ok(golem.side == 0 and golem.has("turncoat"), "rewritten, it fights for the party")
	ok(golem.turncoat.turns == golem.rebind_turns, "for as many turns as it says", "%d" % golem.turncoat.get("turns", -1))
	log_line("")


func the_party_falling():
	log_line("======== The party falling ========")
	var golem := who("golem")
	ok(golem.side == 0, "the golem is still the party's")
	for comb in combat.combatants.duplicate():
		if comb.side == 0 and comb.alive and not comb.has("turncoat"):
			combat.lose_hp(comb, comb.hp)
			combat.combatant_die(comb)
	await settle(2)
	ok(golem.side == 1, "with the party fallen, it turns back")
	ok(combat.combat_over, "and the fight is lost")
	log_line("")


func quick_time():
	log_line("======== Quick time ========")
	ok(SkillDatabase.skills.hurl.quick_time != null and SkillDatabase.skills.ground_pound.quick_time != null,
		"Hurl and Ground Pound have one")
	var wasd := {&"qte_north": KEY_W, &"qte_west": KEY_A, &"qte_south": KEY_S, &"qte_east": KEY_D}
	var missing := []
	for action in wasd:
		var keys: Array = InputMap.action_get_events(action).filter(func(e): return e is InputEventKey).map(func(e): return e.physical_keycode)
		var pads: Array = InputMap.action_get_events(action).filter(func(e): return e is InputEventJoypadButton)
		if not keys.has(wasd[action]) or not keys.has(int({&"qte_north": KEY_UP, &"qte_west": KEY_LEFT, &"qte_south": KEY_DOWN, &"qte_east": KEY_RIGHT}[action])) or pads.is_empty():
			missing.append(action)
	ok(missing.is_empty(), "each of the four is a WASD key, an arrow key and a pad button", "%s" % [missing])
	# The golem fight ended with the party fallen: a fresh start, all of them up.
	Campaign.reset()
	await open_fight(BLADES)
	var enfina := who("enfina")
	var foe := named("Sellsword 1")
	var hurl: SkillDefinition = SkillDatabase.skills.hurl
	var pound: SkillDefinition = SkillDatabase.skills.ground_pound
	QuickTime.answer = 1
	ok(is_equal_approx(await combat.quick_time_power(enfina, [foe], hurl), 1.0 + hurl.quick_time_bonus), "a throw done in time lands harder")
	ok(is_equal_approx(await combat.quick_time_power(foe, [enfina], pound), 1.0 - pound.quick_time_bonus), "a blow braced in time lands softer")
	ok(is_equal_approx(await combat.quick_time_power(foe, [foe], hurl), 1.0), "nobody asks the AI")
	QuickTime.answer = 0
	ok(is_equal_approx(await combat.quick_time_power(enfina, [foe], hurl), 1.0), "missed, it is as written")
	QuickTime.answer = -1
	ok(is_equal_approx(await combat.quick_time_power(enfina, [foe], hurl), 1.0), "headless with nobody to press, it is missed")
	ok(Combat.quick_time_governs(pound, enfina) and not Combat.quick_time_governs(pound, foe), "bracing only spares the party")
	await the_prisoners_button()
	await close_fight()
	# Played for real.
	QuickTime.play_headless = true
	var paused_before := get_tree().paused
	log_line("  NOTE  the tree is %s before" % ("paused" if paused_before else "running"))
	get_tree().paused = false
	paused_before = false
	for kind in ["press", "sequence", "mash", "timing"]:
		var good := await play(kind, true)
		ok(good, "%s: done right, it passes" % kind)
		ok(get_tree().paused == paused_before, "and the world is as it was after")
	ok(not await play("press", false), "press: the wrong button misses")
	ok(not await play("sequence", false), "sequence: one wrong and it is over")
	ok(not await play("timing", false), "timing: pressed outside the zone, it misses")
	QuickTime.answer = 1
	QuickTime.play_headless = false
	ok(await QuickTime.start("dodge_the_bolt") and QuickTime.passed and Campaign.flag("qte:dodge_the_bolt"), "a conversation's leaves its flag")
	QuickTime.answer = -1
	log_line("")


## Plays a made-up quick time event of `kind`, pressing right or wrong.
func play(kind: String, right: bool) -> bool:
	var definition := QuickTimeDefinition.new()
	definition.time = 6.0
	definition.count = 3
	definition.zone = 0.3
	definition.speed = 0.5
	definition.kind = {"press": QuickTimeDefinition.Kind.PRESS, "sequence": QuickTimeDefinition.Kind.SEQUENCE,
		"mash": QuickTimeDefinition.Kind.MASH, "timing": QuickTimeDefinition.Kind.TIMING}[kind]
	var result := []
	var running := func(): result.append(await QuickTime.run(definition))
	running.call()
	await until(func(): return QuickTime.running())
	ok(get_tree().paused, "%s: the world waits while it is up" % kind)
	match kind:
		"press", "mash":
			for i in definition.count:
				if not QuickTime.running():
					break
				QuickTime.press(QuickTime.wanted() if right else _other(QuickTime.wanted()))
				await settle(1)
		"sequence":
			for i in definition.count:
				if not QuickTime.running():
					break
				QuickTime.press(QuickTime.wanted() if right else _other(QuickTime.wanted()))
				await settle(1)
		"timing":
			await until(func(): return QuickTime.in_zone() == right, 6.0)
			QuickTime.press(&"qte_south")
	await until(func(): return not result.is_empty())
	return result[0] if not result.is_empty() else false


func _other(action: StringName) -> StringName:
	for each in QuickTime.BUTTONS:
		if each != action:
			return each
	return action


## Puts `target` somewhere with room beside it, and `mover` there.
func pair_up(mover: Dictionary, target: Dictionary) -> bool:
	if beside(mover, target):
		return true
	var region: Rect2i = combat.controller._astargrid.region
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var tile := Vector2i(x, y)
			if not combat.room_for(target, tile):
				continue
			for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var next: Vector2i = tile + step
				if next != tile and combat.room_for(mover, next) and not combat.covers(target, next):
					if (tile == target.position or combat.teleport_to(target, tile)) and (next == mover.position or combat.teleport_to(mover, next)):
						return true
	return false


func the_codex():
	log_line("======== The enemy codex ========")
	ok(Campaign.codex_enemies().has("sellsword") and Campaign.codex_enemies().has("ash_warden"), "every enemy has a page")
	ok(not Campaign.codex_enemies().has("enfina") and not Campaign.codex_enemies().has("powder_keg"), "and nobody else does")
	ok(Campaign.codex_pages("sellsword") == 1, "Enfina's blow wrote the sellsword's page")
	var cyrus := who("cyrus")
	var bow := named("Hired Bow 2")
	combat.study(cyrus, bow)
	ok(Campaign.codex_pages("hired_bow") == 0, "Cyrus studying writes nothing - he does not keep it")
	combat.study(who("prometheus"), bow)
	ok(Campaign.codex_pages("hired_bow") == 1, "Prometheus studying does")
	ok(Campaign.codex_pages("hired_bow") == 1 and not Campaign.write_codex("hired_bow", 2), "and somebody who is no boss has the one page")
	# Study opens the character sheet, which holds the game; put it away.
	for menu in get_tree().get_nodes_in_group(&"pad_menu"):
		if menu.has_method("pad_menu_is_open") and menu.pad_menu_is_open() and menu != Journal:
			menu.pad_menu_close()
	await settle(1)
	Journal.open()
	await settle(2)
	Journal.toggle_codex()
	Journal.show_codex("sellsword")
	await settle(1)
	ok(Journal.codex_showing() and "50 gold" in Journal.codex_text(), "the journal shows the page in its codex", Journal.codex_text().left(80).replace("\n", " | "))
	Journal.show_codex("pit_champion")
	ok(Campaign.codex_pages("pit_champion") == 0 and "50 gold" in Journal.codex_text(), "an unwritten page cannot be opened")
	Journal.close()
	await settle(1)


func the_boss_codex():
	log_line("======== A boss's second page ========")
	Campaign.reset()
	await open_fight("res://data/encounters/boss_ash_warden.tres")
	var warden := who("ash_warden")
	var enfina := who("enfina")
	ok(CodexPage.pages_of(CombatantDatabase.combatants.ash_warden) == 2, "a boss has two pages")
	combat.study(enfina, warden)
	ok(Campaign.codex_pages("ash_warden") == 1, "studied, the first is written")
	combat.study(enfina, warden)
	ok(Campaign.codex_pages("ash_warden") == 1, "studied again in its first phase, nothing more")
	warden.phase = 1
	combat.study(enfina, warden)
	ok(Campaign.codex_pages("ash_warden") == 2, "past its first phase, the second is written")
	ok("Stagger" in CodexPage.second_page(CombatantDatabase.combatants.ash_warden), "with its stagger bar on it")
	log_line("======== Somebody who must not get away ========")
	warden.when_fled = 2
	combat._taken(warden, "fled")
	await settle(3)
	ok(combat.combat_over and combat.lost_because != "", "it gets away, and the fight is lost", combat.lost_because)
	var result = game.get_node("ResultUI")
	ok(result.get_node("Panel/VBox/Title").text == "Defeat", "the results say so", result.get_node("Panel/VBox/Title").text)
	await close_fight()


func the_prisoners_button():
	log_line("======== Questioning, from the results ========")
	# Hired Blades leaves them to its own conversation (the_conversation_after);
	# without one, the results offer the questioning panel.
	var blades: EncounterDefinition = combat.encounter
	var deciding: bool = blades.dialogue_decides_prisoners
	var closing: Resource = blades.victory_dialogue
	blades.dialogue_decides_prisoners = false
	blades.victory_dialogue = null
	for comb in combat.combatants.duplicate():
		if comb.alive and comb.side == 1 and not comb.has("object"):
			combat.lose_hp(comb, comb.hp)
			combat.combatant_die(comb)
	await settle(3)
	ok(combat.combat_over and combat.lost_because == "", "every one of them down, the fight is won")
	ok(combat.prisoners().size() >= 5, "and every one of them taken", "%d" % combat.prisoners().size())
	var result = game.get_node("ResultUI")
	var button: Button = result.get_node_or_null("Panel/VBox/PrisonersButton")
	ok(button != null and button.visible and "(3)" in button.text, "the results offer them - one of each kind", button.text if button != null else "")
	ok(result.get_node("Panel").visible, "without holding the results back")
	button.pressed.emit()
	await settle(2)
	ok(result.prisoners_panel != null, "pressed, they are put up to question")
	result.prisoners_panel._done_button.pressed.emit()
	await settle(2)
	ok(result.prisoners_panel == null and not button.visible, "and once done with, the button goes")
	blades.dialogue_decides_prisoners = deciding
	blades.victory_dialogue = closing


## An encounter whose own conversation decides what becomes of the prisoners
## (EncounterDefinition.dialogue_decides_prisoners, Campaign "The last fight").
func the_conversation_after():
	log_line("======== The conversation after ========")
	Campaign.reset()
	await open_fight(BLADES)
	ok(combat.encounter.dialogue_decides_prisoners and combat.encounter.victory_dialogue != null,
		"Hired Blades has its say about the prisoners")
	var away := named("Hired Bow 2")
	combat._taken(away, "fled")
	for comb in combat.combatants.duplicate():
		if comb.alive and comb.side == 1 and not comb.has("object"):
			combat.lose_hp(comb, comb.hp)
			combat.combatant_die(comb)
	await settle(3)
	ok(combat.combat_over, "the fight is over")
	ok(Campaign.taken_alive("sellsword") == 2 and Campaign.taken_alive("pit_champion") == 1 and Campaign.taken_alive("hired_bow") == 1,
		"the last fight says who was taken alive", "%s" % [Campaign.last_fight])
	ok(Campaign.taken_alive() == 4, "four in all")
	ok(Campaign.got_away("hired_bow") == 1, "and who got away")
	ok(Campaign.fell() == 0, "and that nobody fell for good")
	var result = game.get_node("ResultUI")
	ok(not result.get_node("Panel").visible, "the conversation comes first")
	ok(result.prisoners_to_question().is_empty(), "with nobody left for the questioning panel")
	var gold: int = Campaign.gold
	ok(Campaign.question("sellsword") and Campaign.questioned("sellsword"), "a sellsword questioned from the conversation")
	ok(Campaign.gold == gold + 30, "gives up its stash", "%d" % (Campaign.gold - gold))
	ok(not Campaign.question("bandit"), "nobody to question who was not taken")
	Campaign.let_go("sellsword")
	ok(Campaign.taken_alive("sellsword") == 0 and int(Campaign.flags.get("prisoners_released", 0)) == 2, "both sellswords let go")
	Campaign.hand_over("", 1)
	ok(Campaign.taken_alive() == 1 and int(Campaign.flags.get("prisoners_handed_over", 0)) == 1, "one of the rest handed over")
	Campaign.hand_over()
	ok(Campaign.taken_alive() == 0 and int(Campaign.flags.get("prisoners_handed_over", 0)) == 2, "and then the rest")
	DialogueManager.dialogue_ended.emit(combat.encounter.victory_dialogue)
	await settle(2)
	ok(result.get_node("Panel").visible, "then the results")
	var button: Button = result.get_node_or_null("Panel/VBox/PrisonersButton")
	ok(button == null or not button.visible, "with no questioning to offer")
	for balloon in get_tree().root.find_children("*", "", true, false):
		if balloon.scene_file_path == "res://ui/dialogue_balloon.tscn":
			balloon.queue_free()
	await close_fight()
	log_line("")
