extends Node
## Prone (Combat "Prone"; the designer, 2026-11-05): anybody lies down for nothing
## and gets up for half their movement, walking only once up; lying there, half from
## ranged moves and areas, double from melee, which the prompt and the blow agree on.
## Cyrus's Low Shot takes the cover away from his ranged moves; the Saboteur's Kip-Up
## takes the cost away from his getting up. Undo Move takes lying down and getting
## up back ("allow undo move to work on prone").

const LOG_NAME := "prone"
const WATCHER := "res://data/encounters/encounter_03_watcher.tres"
const PARTY := ["enfina", "cyrus", "alithia"]
const NOWHERE := Vector2i(-99999, -99999)

var LOG_PATH := HarnessLog.path_for(LOG_NAME)
var _log: FileAccess = null
var _fail := 0
var game = null
var combat: Combat = null
var controller = null
var ui = null


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
	await open_fight({}, 8)
	await down_and_up()
	await what_it_does_to_a_blow()
	await low_shot()
	await nothing_lifts_it()
	await who_cannot()
	await undoing()
	await the_button()
	await enemies()
	await open_fight({"cyrus": "saboteur"}, 24)
	await kip_up()
	await close_fight()
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


func open_fight(paths: Dictionary, level: int):
	await close_fight()
	Campaign.reset()
	Campaign.set_party(PARTY, level)
	for key in paths:
		Campaign.choose_subclass(key, paths[key])
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
	# Nobody at the keyboard: a reaction is taken without asking, and none goes off.
	combat.reaction_prompt = null
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


func first_foe() -> Dictionary:
	for comb in combat.combatants:
		if comb.side == 1 and comb.alive and not comb.has("object"):
			return comb
	return {}


## `comb`'s turn, from its beginning, on the player's side of the board.
func their_turn(comb: Dictionary):
	combat.current_combatant = combat.combatants.find(comb)
	comb.skill_used_this_turn = false
	comb.secondary_used_this_turn = false
	comb.erase("movement_left_when_down")
	controller.set_controlled_combatant(comb)
	await settle()


func stand_everybody():
	for comb in combat.combatants:
		if comb.has("status_effects") and combat.is_prone(comb):
			combat._stand(comb)


func prompt_text() -> String:
	if ui._hit_preview == null or not ui._hit_preview.visible:
		return ""
	var found := []
	for label in ui.find_children("*", "Label", true, false):
		if ui._hit_preview.is_ancestor_of(label):
			found.append(label.text)
	return " / ".join(found)


func down_and_up():
	log_line("======== going down, for nothing, and getting up, for half ========")
	var enfina := who("enfina")
	await their_turn(enfina)
	var whole: int = controller.movement
	ok(whole > 0 and not combat.is_prone(enfina), "standing, with all her movement", "%d" % whole)
	ok(controller.toggle_prone() and combat.is_prone(enfina), "she goes down")
	ok(not enfina.skill_used_this_turn and not enfina.secondary_used_this_turn, "  for no action")
	ok(controller.movement == 0, "  and she cannot walk now", "%d" % controller.movement)
	ok(combat.can_still_walk(enfina), "  though she could still get up and walk: the turn does not run out")
	var cost: int = combat.get_up_cost(enfina)
	ok(cost == ceili(whole / 2.0), "getting up takes half her movement, rounded up", "%d of %d" % [cost, whole])
	ok(controller.toggle_prone() and not combat.is_prone(enfina), "she gets up")
	ok(controller.movement == whole - cost, "  and has the rest to walk with", "%d" % controller.movement)
	ok(not enfina.skill_used_this_turn and not enfina.secondary_used_this_turn, "  for no action either")
	# Spent too much to get up again this turn.
	controller.set_movement(cost - 1)
	ok(controller.toggle_prone(), "down again, with less left than getting up takes")
	ok(combat.get_up_refusal(enfina) != "" and not controller.toggle_prone() and combat.is_prone(enfina),
		"  and she stays down", combat.get_up_refusal(enfina))
	ok(not combat.can_still_walk(enfina), "  so her feet have nothing left this turn")
	# Next turn, all of it is there again.
	enfina.reaction_used = true
	await their_turn(enfina)
	ok(combat.is_prone(enfina) and controller.movement == 0, "her next turn she begins down, walking nowhere")
	ok(combat.get_up_refusal(enfina) == "" and controller.toggle_prone(), "  and can get up")
	ok(controller.movement == whole - cost, "  with half of a whole turn's movement left", "%d" % controller.movement)
	# A blow from down there is fine.
	ok(controller.toggle_prone() and enfina.status_effects.any(func(entry): return Combat._lying_down(entry)), "down once more")
	combat.current_combatant = combat.combatants.find(enfina)
	var foe := first_foe()
	combat.teleport_to(foe, enfina.position + Vector2i(1, 0)) if combat.can_land_on(foe, enfina.position + Vector2i(1, 0)) else combat.teleport_to(foe, enfina.position + Vector2i(-1, 0))
	var before: int = foe.hp
	foe.hp = 999
	before = foe.hp
	await combat.use_skill("greatsword_attack", enfina, foe.position, false)
	ok(foe.hp < before or foe.get("alive", false), "lying down she can still swing")
	ok(combat.is_prone(enfina), "  and is still down after it")
	await settle()
	stand_everybody()
	log_line("")


func what_it_does_to_a_blow():
	log_line("======== half from afar and from areas, double from melee ========")
	var alithia := who("alithia")
	var enfina := who("enfina")
	var foe := first_foe()
	foe.hp = 9999
	foe.max_hp = 9999
	var ranged: SkillDefinition = SkillDatabase.skills["fireball"]
	var melee: SkillDefinition = SkillDatabase.skills["greatsword_attack"]
	var sweep: SkillDefinition = SkillDatabase.skills["sweep_strike"]
	ok(not Combat.is_melee(ranged) and ranged.aoe_radius > 0, "Fireball: an area, sent across the room")
	ok(Combat.is_melee(melee) and melee.aoe_radius == 0, "Greatsword: melee")
	ok(combat.prone_damage_factor(alithia, foe, ranged) == 1.0 and combat.prone_damage_factor(enfina, foe, melee) == 1.0, "standing: nothing changes")
	var full_melee: int = combat.skill_damage(enfina, foe, melee)
	var half_area: int = combat.skill_damage(alithia, foe, ranged, 0.5)
	var double_melee: int = combat.skill_damage(enfina, foe, melee, 2.0)
	ok(combat.lie_down(foe) and combat.is_prone(foe), "the foe goes down")
	ok(combat.prone_damage_factor(alithia, foe, ranged) == 0.5, "an area: half")
	ok(combat.skill_damage(alithia, foe, ranged) == half_area, "  to the point", "%d" % half_area)
	ok(combat.prone_damage_factor(enfina, foe, melee) == 2.0, "melee: double")
	ok(combat.skill_damage(enfina, foe, melee) == double_melee and double_melee > full_melee, "  to the point", "%d against %d" % [double_melee, full_melee])
	ok(combat.prone_damage_factor(enfina, foe, sweep) == 2.0, "a melee swing with an area: melee")
	combat._splashing = true
	ok(combat.prone_damage_factor(enfina, foe, melee) == 0.5, "the shock spreading from a blow: an area")
	combat._splashing = false
	ok(combat.prone_damage_factor(enfina, foe, null) == 1.0, "nothing behind it, a burn or a wall: as ever")
	# What the prompt promises is what lands.
	await their_turn(enfina)
	enfina.reaction_used = true
	combat.teleport_to(foe, enfina.position + Vector2i(1, 0)) if combat.can_land_on(foe, enfina.position + Vector2i(1, 0)) else combat.teleport_to(foe, enfina.position + Vector2i(-1, 0))
	var said: Dictionary = combat.predict_hit(enfina, foe, melee)
	ok(said.prone != "", "the prompt has a line for it", said.prone)
	controller.set_selected_skill("greatsword_attack")
	controller.begin_target_selection()
	controller._preview_hits(foe.position)
	ok(prompt_text().contains(said.prone) and prompt_text().contains("%d damage" % said.damage), "  and shows it", prompt_text())
	controller.cancel_skill_selection()
	await settle()
	var before: int = foe.hp
	await combat.use_skill("greatsword_attack", enfina, foe.position, false)
	ok(before - foe.hp == said.damage, "and the blow lands for what it promised", "promised %d, dealt %d" % [said.damage, before - foe.hp])
	await settle()
	stand_everybody()
	log_line("")


func low_shot():
	log_line("======== Low Shot: Cyrus's ranged moves give no cover ========")
	var cyrus := who("cyrus")
	var alithia := who("alithia")
	var enfina := who("enfina")
	var foe := first_foe()
	var gun: SkillDefinition = SkillDatabase.skills["gun"]
	var rapier: SkillDefinition = SkillDatabase.skills["rapier"]
	var fireball: SkillDefinition = SkillDatabase.skills["fireball"]
	ok(combat.active_passives(cyrus).any(func(passive): return passive.ignores_prone_cover), "he has it, from the start")
	ok(not Combat.is_melee(gun), "Gun is a ranged move")
	combat.lie_down(foe)
	ok(combat.prone_damage_factor(cyrus, foe, gun) == 1.0, "his Gun at a foe lying down: nothing off", combat.prone_note(cyrus, foe, gun))
	ok(combat.prone_note(cyrus, foe, gun).contains("no cover"), "  and the prompt says so")
	ok(combat.prone_damage_factor(cyrus, foe, rapier) == 2.0, "his Rapier: still double")
	ok(combat.prone_damage_factor(alithia, foe, fireball) == 0.5, "anybody else's: still half")
	combat.lie_down(enfina)
	ok(combat.prone_damage_factor(cyrus, enfina, gun) == 0.5, "and it is for enemies: at somebody of his own, still half")
	stand_everybody()
	log_line("")


func nothing_lifts_it():
	log_line("======== nothing lifts it ========")
	var enfina := who("enfina")
	combat.lie_down(enfina)
	var entry: Dictionary = enfina.status_effects.filter(func(status): return Combat._lying_down(status))[0]
	ok(not Combat._harmful(entry), "no heal that lifts harm takes it")
	var cleanse := EffectDefinition.new()
	cleanse.dispel_scope = EffectDefinition.DispelScope.DEBUFFS_ONLY
	ok(not combat.should_dispel(entry, cleanse), "no cleanse")
	cleanse.dispel_scope = EffectDefinition.DispelScope.BOTH
	ok(not combat.should_dispel(entry, cleanse), "no dispel")
	stand_everybody()
	log_line("")


func who_cannot():
	log_line("======== who cannot ========")
	var enfina := who("enfina")
	enfina.movement_class = 1
	ok(combat.lie_down_refusal(enfina) != "" and not combat.lie_down(enfina), "up in the air", combat.lie_down_refusal(enfina))
	enfina.movement_class = 0
	var immune: Array = enfina.get("immune_conditions", [])
	enfina["immune_conditions"] = [Combat.PRONE.resource_path]
	ok(combat.lie_down_refusal(enfina) != "", "immune to it", combat.lie_down_refusal(enfina))
	enfina["immune_conditions"] = immune
	ok(combat.lie_down_refusal(enfina) == "" and combat.lie_down(enfina), "on her feet, she can")
	ok(combat.lie_down_refusal(enfina) != "", "  but not twice")
	# Held down by something else: no getting up.
	var held: ConditionDefinition = load("res://data/conditions/grappled.tres")
	combat.put_condition(enfina, held, 999, "test", true)
	ok(combat.get_up_refusal(enfina).contains("Grappled"), "grappled, she cannot get up", combat.get_up_refusal(enfina))
	enfina.status_effects = enfina.status_effects.filter(func(status): return status.get("condition") != held)
	stand_everybody()
	log_line("")


## Walks the one acting to a tile near them, through the same calls a click makes.
func walk_a_little(comb: Dictionary) -> Vector2i:
	var to := NOWHERE
	for tile in controller.get_reachable_tiles(comb.position, comb.movement_class, 2):
		if tile != comb.position and combat.get_position_distance(comb.position, tile) == 2 and combat.can_land_on(comb, tile):
			to = tile
			break
	if to == NOWHERE:
		return to
	controller.find_path(to)
	controller.move_player()
	var frames := 0
	await get_tree().process_frame
	while not controller.is_idle() and frames < 3000:
		await get_tree().process_frame
		frames += 1
	await settle()
	return to


func undoing():
	log_line("======== Undo Move takes it back ========")
	var enfina := who("enfina")
	stand_everybody()
	await their_turn(enfina)
	var whole: int = controller.movement
	var start: Vector2i = enfina.position
	ok(not controller.has_walked() and not controller.can_undo_move(), "nothing to take back yet")
	controller.toggle_prone()
	ok(controller.has_walked() and controller.can_undo_move(), "gone down, it can be taken back")
	ok(ui._undo_button.visible and not ui._undo_button.disabled, "  with Undo Move there to press")
	ok(controller.undo_move() and not combat.is_prone(enfina) and controller.movement == whole, "taken back: on her feet, all her movement", "%d" % controller.movement)
	ok(not enfina.has("movement_left_when_down"), "  nothing kept")
	ok(not controller.has_walked(), "  and nothing left to take back")
	# Down and straight up again: on her feet as she was, but for what it took.
	controller.toggle_prone()
	controller.toggle_prone()
	ok(not combat.is_prone(enfina) and controller.movement < whole and controller.can_undo_move(), "down and up again, that can be taken back", "%d" % controller.movement)
	ok(controller.undo_move() and not combat.is_prone(enfina) and controller.movement == whole, "  with all her movement", "%d" % controller.movement)
	# Begun down: getting up, taken back, she is down again and has nothing to walk with.
	controller.toggle_prone()
	await their_turn(enfina)
	ok(combat.is_prone(enfina) and controller.movement == 0, "another turn, begun down")
	controller.toggle_prone()
	var up: int = controller.movement
	ok(up > 0 and controller.can_undo_move(), "got up, it can be taken back", "%d" % up)
	ok(controller.undo_move() and combat.is_prone(enfina) and controller.movement == 0, "taken back: down again, and walking nowhere")
	ok(controller.toggle_prone() and controller.movement == up, "  and getting up costs what it did", "%d" % controller.movement)
	# Got up, walked: both go back together.
	var walked_to: Vector2i = await walk_a_little(enfina)
	ok(walked_to != NOWHERE and enfina.position == walked_to, "got up and walked", "%s" % walked_to)
	ok(controller.undo_move() and combat.is_prone(enfina) and enfina.position == start and controller.movement == 0, "taken back: where she lay, lying there")
	# Walked, then down: both go back together.
	stand_everybody()
	enfina["walked_this_turn"] = 0
	enfina.erase("moved_this_turn")
	await their_turn(enfina)
	walked_to = await walk_a_little(enfina)
	var left: int = controller.movement
	ok(left < whole, "walked", "%d of %d" % [left, whole])
	controller.toggle_prone()
	ok(controller.can_undo_move() and controller.undo_move() and not combat.is_prone(enfina) and enfina.position == start and controller.movement == whole,
		"walked and went down, taken back: where she began, on her feet, all her movement")
	ok(enfina.get("walked_this_turn", 0) == 0 and not enfina.get("moved_this_turn", false),
		"  and as if she never walked: no Charge from it, and the bonus for standing still is back")
	# Once something else has happened, it stays happened.
	stand_everybody()
	await their_turn(enfina)
	controller.toggle_prone()
	var foe := first_foe()
	foe.hp = 9999
	combat.teleport_to(foe, enfina.position + Vector2i(1, 0)) if combat.can_land_on(foe, enfina.position + Vector2i(1, 0)) else combat.teleport_to(foe, enfina.position + Vector2i(-1, 0))
	await combat.use_skill("greatsword_attack", enfina, foe.position, false)
	await settle()
	ok(not controller.can_undo_move() and combat.is_prone(enfina), "down, then a blow struck: too late, and she stays down")
	stand_everybody()
	log_line("")


func the_button():
	log_line("======== the button, and Ctrl ========")
	var enfina := who("enfina")
	await their_turn(enfina)
	var whole: int = controller.movement
	ui._refresh_prone()
	ok(ui._prone_button.visible and ui._prone_button.text == "Go Prone" and not ui._prone_button.disabled, "on her turn, Go Prone", ui._prone_button.text)
	ok(ui._prone_button.tooltip_text.contains("half damage"), "  saying what it does")
	ok(InputMap.has_action(&"prone"), "there is a key for it", Pad.key(&"prone"))
	ui._prone_button.pressed.emit()
	await settle()
	ok(combat.is_prone(enfina), "pressed, she is down")
	ok(ui._prone_button.text == "Get Up (%d)" % ceili(whole / 2.0), "  and it says what getting up takes", ui._prone_button.text)
	ok(ui.get_node("Actions/Movement").text.contains("Prone"), "  and so does the counter", ui.get_node("Actions/Movement").text)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_CTRL
	key.keycode = KEY_CTRL
	key.pressed = true
	Input.parse_input_event(key)
	await settle()
	var release := InputEventKey.new()
	release.physical_keycode = KEY_CTRL
	release.keycode = KEY_CTRL
	release.pressed = false
	Input.parse_input_event(release)
	await settle()
	ok(not combat.is_prone(enfina), "Ctrl gets her up", ui._prone_button.text)
	ui._refresh_prone()
	ok(ui._prone_button.text == "Go Prone", "  and it offers Go Prone again")
	# Aiming, it is out of the way, and it comes back with the rest.
	controller.set_selected_skill("greatsword_attack")
	controller.begin_target_selection()
	await settle()
	ok(not controller.can_change_stance() and not ui._prone_button.visible, "aiming, it is not there")
	ok(not controller.toggle_prone() and not combat.is_prone(enfina), "  and nothing happens")
	controller.cancel_skill_selection()
	await settle()
	ok(ui._prone_button.visible, "  and it comes back with the rest")
	# On an enemy's turn: not there.
	var foe := first_foe()
	combat.current_combatant = combat.combatants.find(foe)
	controller.player_turn = false
	ui._refresh_prone()
	ok(not ui._prone_button.visible, "on an enemy's turn, not there")
	controller.player_turn = true
	stand_everybody()
	log_line("")


func enemies():
	log_line("======== enemies ========")
	var cyrus := who("cyrus")
	var foe := first_foe()
	ok(load("res://data/enemies/ranger.tres").goes_prone and not load("res://data/enemies/priest.tres").goes_prone, "the Ranger goes prone by its nature; one not ticked does not")
	foe["goes_prone"] = false
	# Put down by something else, it gets up to walk.
	foe.reaction_used = true
	await their_turn(foe)
	combat.lie_down(foe)
	ok(not combat._ai_stays_down(foe), "put down, one not ticked does not stay there")
	# Ticked: down with nobody coming, up when somebody is.
	foe["goes_prone"] = true
	for comb in combat.combatants:
		if comb.side == 0 and comb.has("movement"):
			comb["was_movement"] = comb.movement
			comb.movement = 1
	stand_everybody()
	await their_turn(foe)
	var far := NOWHERE
	# Past the longest melee move anybody has, after the one tile they can walk.
	var longest := 1
	for comb in combat.combatants:
		if comb.side == 0 and comb.alive:
			longest = maxi(longest, combat._melee_reach_of(comb))
	for tile in controller.get_reachable_tiles(foe.position, foe.movement_class, 40):
		var gap := 999
		for comb in combat.combatants:
			if comb.side == 0 and comb.alive:
				gap = mini(gap, combat.get_position_distance(tile, comb.position))
		if gap >= longest + 2 and gap <= longest + 5 and combat.can_land_on(foe, tile):
			far = tile
			break
	ok(far != NOWHERE, "somewhere nobody can reach in a turn", "%s" % far)
	combat.teleport_to(foe, far)
	ok(not combat._could_be_reached_in_melee(foe), "nobody can get to it from there")
	combat._ai_consider_lying_down(foe)
	ok(combat.is_prone(foe), "so it lies down as its turn ends")
	foe.skill_list.append("gun")
	ok(combat._ai_stays_down(foe) or not combat._ai_can_strike_this_turn(foe), "and stays down while it has somebody to hit from there")
	if combat._ai_can_strike_this_turn(foe):
		ok(combat._ai_stays_down(foe), "  it has", "")
	combat.teleport_to(foe, cyrus.position + Vector2i(1, 0)) if combat.can_land_on(foe, cyrus.position + Vector2i(1, 0)) else combat.teleport_to(foe, cyrus.position + Vector2i(-1, 0))
	ok(combat._could_be_reached_in_melee(foe) and not combat._ai_stays_down(foe), "with somebody on it, it does not stay")
	var left_before: int = combat.movement_if_up(foe)
	ok(combat.get_up(foe) and not combat.is_prone(foe), "it gets up")
	ok(controller.movement == left_before - ceili(combat._whole_movement(foe) / 2.0), "  paying for it, and has the rest for its turn", "%d" % controller.movement)
	foe.skill_list.erase("gun")
	foe["goes_prone"] = false
	for comb in combat.combatants:
		if comb.has("was_movement"):
			comb.movement = comb.was_movement
			comb.erase("was_movement")
	stand_everybody()
	log_line("")


func kip_up():
	log_line("======== Kip-Up: the Saboteur gets up for nothing ========")
	var cyrus := who("cyrus")
	ok(combat.active_passives(cyrus).any(func(passive): return passive.gets_up_free), "a Saboteur at 24 has it")
	await their_turn(cyrus)
	var whole: int = controller.movement
	ok(whole > 0 and controller.toggle_prone() and combat.is_prone(cyrus), "he goes down")
	ok(combat.get_up_cost(cyrus) == 0, "getting up takes none of his movement")
	ui._refresh_prone()
	ok(ui._prone_button.text == "Get Up (0)", "  and the button says so", ui._prone_button.text)
	ok(controller.toggle_prone() and not combat.is_prone(cyrus) and controller.movement == whole, "up, with all of it left", "%d" % controller.movement)
	# Nobody else's getting up is free.
	var enfina := who("enfina")
	combat.lie_down(enfina)
	ok(combat.get_up_cost(enfina) > 0, "anybody else's still costs", "%d" % combat.get_up_cost(enfina))
	stand_everybody()
	# Not a Saboteur, or not yet.
	await open_fight({}, 24)
	cyrus = who("cyrus")
	combat.lie_down(cyrus)
	ok(combat.get_up_cost(cyrus) > 0, "Cyrus on no path pays", "%d" % combat.get_up_cost(cyrus))
	log_line("")
