extends "res://StealthHarness.gd"
## Moves outside a fight, Phase 1 (docs/outside_combat_plan.md; the designer,
## 2026-10-26): every move on the map's panel, what each does out there, paying
## real gates - and the Gates of Iris first for a spell marked Out Of Combat -
## the out-of-combat toggle, noise marks heard by guards, the Outside Spell key
## on a map nobody watches, the Hide UI key, and the sheet's castings on a map.


func suite() -> String:
	return "outside"


func time_limit() -> float:
	return 420.0


func run_sections():
	the_marks()
	the_uses()
	paying()
	await on_a_plain_map()
	await the_toggle()
	await bringing_back_and_hurrying()
	await noise()
	await hiding_the_ui()
	await the_sheet()
	await familiar_anywhere()
	await on_guards()
	await the_opening_blow()
	await walls_and_moving()
	await lures_cover_traps()
	await the_familiar_stage()
	await magic_traps()
	await walls_in_a_fight()


func skill(key: String) -> SkillDefinition:
	return SkillDatabase.skills[key]


## Whoever else walks with Alithia.
func ally() -> String:
	for key in Campaign.living_party():
		if key != "alithia":
			return key
	return ""


func the_marks():
	log_line("======== the marks ========")
	var marked_damaging := []
	var unmarked := 0
	for key in SkillDatabase.skills:
		var move: SkillDefinition = SkillDatabase.skills[key]
		if move.out_of_combat and move.deals_damage:
			marked_damaging.append(key)
		if move.noise == SkillDefinition.Loudness.UNMARKED and not move is ItemDefinition:
			unmarked += 1
	ok(marked_damaging.is_empty(), "nothing that deals damage is marked Out Of Combat", ", ".join(marked_damaging))
	log_line("  %d moves still have no noise marked (they play as silent)" % unmarked)
	var test := SkillDefinition.new()
	ok(OutsideMoves.noise_fact(test) == "Noise unmarked", "unmarked says so")
	test.noise = SkillDefinition.Loudness.LOUD
	test.noise_tiles = 6.0
	ok(OutsideMoves.noise_fact(test) == "Loud: 6 tiles", "a loud one says how far", OutsideMoves.noise_fact(test))
	test.noise = SkillDefinition.Loudness.SILENT
	ok(OutsideMoves.noise_fact(test) == "Silent", "  a silent one, that it is silent")
	log_line("")


func the_uses():
	log_line("======== what each does out there ========")
	var wanted := {
		"heal": OutsideMoves.Use.MEND, "light_heal": OutsideMoves.Use.MEND, "communion": OutsideMoves.Use.MEND,
		"resuscitate": OutsideMoves.Use.REVIVE, "run": OutsideMoves.Use.NONE, "quicken": OutsideMoves.Use.SPEED,
		"find_familiar": OutsideMoves.Use.FAMILIAR, "invisibility": OutsideMoves.Use.INVISIBILITY,
		"votive_flame": OutsideMoves.Use.AMBUSH, "light_swing": OutsideMoves.Use.AMBUSH, "guard": OutsideMoves.Use.NONE,
		"growth": OutsideMoves.Use.NONE, "flash": OutsideMoves.Use.BLIND, "dread_visage": OutsideMoves.Use.SCARE,
		"intimidate": OutsideMoves.Use.SCARE, "bewilder": OutsideMoves.Use.CONFUSE, "study": OutsideMoves.Use.READ,
		"intuition": OutsideMoves.Use.READ, "dispel_magic": OutsideMoves.Use.SWITCH_OFF_MAGIC, "instahack": OutsideMoves.Use.COUNTER_TRAP,
		"hermes_step": OutsideMoves.Use.BLINK, "mist_step": OutsideMoves.Use.BLINK, "cover_leap": OutsideMoves.Use.BLINK,
		"hover": OutsideMoves.Use.FLY, "climb": OutsideMoves.Use.FLY, "phantom_body": OutsideMoves.Use.LURE,
		"kindled_hound": OutsideMoves.Use.LURE, "illusory_cover": OutsideMoves.Use.HIDING_SPOT, "stealth": OutsideMoves.Use.HIDING_SPOT,
		"snare": OutsideMoves.Use.TRAP, "tripwire": OutsideMoves.Use.TRAP, "purification": OutsideMoves.Use.MEND,
	}
	for key in wanted:
		var got := OutsideMoves.use_of(skill(key))
		ok(got == wanted[key], "%s: %s" % [skill(key).name, OutsideMoves.USE_NAMES[wanted[key]]], OutsideMoves.USE_NAMES.get(got, "?"))
	ok(OutsideMoves.shown_out_of_combat(skill("find_familiar")) and OutsideMoves.shown_out_of_combat(skill("invisibility"))
		and not OutsideMoves.shown_out_of_combat(skill("heal")), "out of combat by nature: Find Familiar and Invisibility; Heal only once marked")
	log_line("")


func paying():
	log_line("======== paying ========")
	Campaign.reset()
	Campaign.set_party(["alithia", "enfina"], 14)
	var heal := skill("heal")
	var most: Array = Campaign.gates_most("alithia")
	ok(OutsideMoves.payment("alithia", heal) == {"gate": 1}, "Heal pays a World casting")
	for i in most[1]:
		OutsideMoves.pay("alithia", heal)
	ok(Campaign.gates_left_outside("alithia")[1] == 0, "  off the next fight's gates, every one of them", "%s" % [Campaign.gates_left_outside("alithia")])
	ok(OutsideMoves.payment("alithia", heal) == {"gate": 2}, "  then through the deeper Hermes, as in a fight", "%s" % [OutsideMoves.payment("alithia", heal)])
	ok(OutsideMoves.payment("alithia", skill("find_familiar"), true).is_empty()
		and OutsideMoves.cannot_pay("alithia", skill("find_familiar"), true) == "Alithia has no castings of World left",
		"  but Find Familiar only ever its own World", OutsideMoves.cannot_pay("alithia", skill("find_familiar"), true))
	# Marked Out Of Combat: the Gates of Iris first.
	heal.out_of_combat = true
	ok(OutsideMoves.iris_gate_for(heal) == 1, "marked, Heal may be paid through Iris (World is no deeper than the Hermes it matches)")
	ok(Campaign.outside_gates_most("alithia")[1] == most[2], "  which Alithia now has, as many as her Hermes",
		"%s vs %s" % [Campaign.outside_gates_most("alithia"), most])
	ok(OutsideMoves.payment("alithia", heal) == {"iris": 1}, "  and spends first")
	var before: int = Campaign.outside_gates_left("alithia")[1]
	ok(not OutsideMoves.pay("alithia", heal).is_empty() and Campaign.outside_gates_left("alithia")[1] == before - 1, "  one casting of it")
	var deep := skill("resuscitate").duplicate()
	deep.out_of_combat = true
	ok(OutsideMoves.iris_gate_for(deep) == 0, "a marked Pandora spell is deeper than Iris: its own gates only")
	var hurting := skill("votive_flame").duplicate()
	hurting.out_of_combat = true
	ok(OutsideMoves.iris_gate_for(hurting) == 0, "a damaging one never goes through Iris, marked or not")
	heal.out_of_combat = false
	ok(Campaign.outside_gates_most("alithia")[1] == 0, "unmarked again: no Iris for her", "%s" % [Campaign.outside_gates_most("alithia")])
	log_line("")


## A crossroads nobody watches, Alithia leading at `level`.
func plain_map(level: int = 1) -> Dictionary:
	var m := await open_map()
	Campaign.add_member("alithia")
	Campaign.reach_level(level, true)
	Campaign.set_leader("alithia")
	await settle(3)
	return m


func on_a_plain_map():
	log_line("======== on a map nobody watches ========")
	var m := await plain_map()
	var scene: ExplorationScene = m.scene
	var panel: OutsideMovesPanel = scene.moves_panel
	ok(panel != null and panel.is_inside_tree() and panel.visible, "the moves panel stands in the action bar's place")
	if panel == null:
		await close_map(m)
		return
	ok(not scene.game_ui.get_node("Actions/ActionsPanel").visible, "  the fight's grid out of the way")
	panel.show_spells(false)
	ok(panel.button_for("run") != null and panel.button_for("votive_flame") != null, "her skills on it, Run and Votive Flame")
	ok(panel.button_for("run").disabled, "  Run greyed: no sprinting out of a fight")
	ok(panel.button_for("votive_flame").disabled and OutsideMoves.refusal(scene, "alithia", "votive_flame") == "No wall in reach to break",
		"  a damaging one greyed with no wall about to break", OutsideMoves.refusal(scene, "alithia", "votive_flame"))
	panel.show_spells(true)
	ok(panel.button_for("heal") != null and panel.button_for("find_familiar") != null, "her spells, on the Spells tab")
	ok(panel.button_for("heal").disabled and OutsideMoves.refusal(scene, "alithia", "heal") == "Nobody is hurt", "  Heal greyed with nobody hurt")
	ok(OutsideMoves.refusal(scene, "alithia", "find_familiar") == "", "  Find Familiar here too, with nobody watching",
		OutsideMoves.refusal(scene, "alithia", "find_familiar"))
	var gate_label = panel.find_child("Gate_World", true, false)
	ok(gate_label != null and gate_label.text == "World 2/2", "  her World castings beside them", gate_label.text if gate_label != null else "none")
	var other := ally()
	Campaign.strain(other, 12)
	var hurt: int = Campaign.party_state[other].hp
	panel.refresh()
	ok(not panel.button_for("heal").disabled, "%s hurt: Heal can be cast" % other, OutsideMoves.refusal(scene, "alithia", "heal"))
	panel.button_for("heal").pressed.emit()
	await settle()
	ok(Campaign.party_state[other].hp > hurt, "  pressed, it mends them", "%d -> %d" % [hurt, Campaign.party_state[other].hp])
	ok(Campaign.gates_left_outside("alithia")[1] == 1, "  for a World casting, off the next fight", "%s" % [Campaign.gates_left_outside("alithia")])
	ok(panel.find_child("Gate_World", true, false).text == "World 1/2", "  and the panel says so", panel.find_child("Gate_World", true, false).text)
	# The Outside Spell key here: the one spell with a purpose, cast.
	Campaign.strain(other, 12)
	var ready := OutsideMoves.ready_spells(scene)
	ok(ready.size() >= 1 and ready.all(func(spell): return OutsideMoves.use_of(skill(spell.move)) == OutsideMoves.Use.MEND), "G would offer only the mends",
		"%s" % [ready])
	var before: int = Campaign.party_state[other].hp
	scene.outside_spell()
	await settle(3)
	ok(is_instance_valid(scene.spell_choice) and scene.spell_choice.find_child("Familiar", true, false) != null,
		"  with Find Familiar too: which?")
	if is_instance_valid(scene.spell_choice):
		scene.spell_choice.find_child(ready[0].move, true, false).pressed.emit()
		await settle(3)
	ok(Campaign.party_state[other].hp > before, "  a mend chosen: cast")
	MenuPause.clear(get_tree())
	await close_map(m)


func the_toggle():
	log_line("======== out of combat only ========")
	var m := await plain_map()
	var panel: OutsideMovesPanel = m.scene.moves_panel
	panel.show_spells(true)
	panel.set_out_of_combat_only(true)
	await settle()
	ok(panel.button_for("heal") == null and panel.button_for("find_familiar") != null, "ticked: Heal goes, Find Familiar stays")
	skill("heal").out_of_combat = true
	panel.refresh()
	ok(panel.button_for("heal") != null, "  Heal marked by the designer: it is back")
	skill("heal").out_of_combat = false
	panel.show_spells(false)
	ok(panel.button_for("run") != null, "  the skills are left alone")
	await close_map(m)
	m = await plain_map()
	panel = m.scene.moves_panel
	ok(panel.out_of_combat_only and panel.find_child("OutOfCombatOnly", true, false).button_pressed, "the next map remembers it")
	panel.set_out_of_combat_only(false)
	await close_map(m)


func bringing_back_and_hurrying():
	log_line("======== bringing back, and hurrying ========")
	var m := await plain_map(14)
	var scene: ExplorationScene = m.scene
	var other := ally()
	Campaign.party_state[other] = {"hp": 0, "max_hp": CombatantDatabase.combatants[other].hp_at(14), "alive": false}
	Campaign.party_changed.emit()
	await settle(3)
	ok(Campaign.fallen_members() == [other], "%s down" % other, "%s" % [Campaign.fallen_members()])
	var pandora: int = Campaign.gates_left_outside("alithia")[3]
	ok(OutsideMoves.refusal(scene, "alithia", "resuscitate") == "", "Resuscitate can be cast", OutsideMoves.refusal(scene, "alithia", "resuscitate"))
	ok(OutsideMoves.use(scene, "alithia", "resuscitate"), "  cast")
	await settle(3)
	var state: Dictionary = Campaign.party_state[other]
	ok(state.alive and state.hp > 0 and state.frailty < 1.0, "  back up, and weaker until a long rest", "%s" % [state])
	ok(Campaign.living_party().has(other) and scene.party.sprite_for(other) != null, "  and walking with them again")
	ok(Campaign.gates_left_outside("alithia")[3] == pandora - 1, "  for a Pandora casting")
	ok(OutsideMoves.refusal(scene, "alithia", "resuscitate") == "Nobody has fallen", "  then nobody has fallen")
	var walking: float = scene.party.move_speed
	ok(OutsideMoves.refusal(scene, "alithia", "run") == "Only in a fight", "Run: only in a fight - no sprinting out here")
	Campaign.add_member("prometheus")
	Campaign.set_leader("prometheus")
	await settle(3)
	ok(OutsideMoves.use(scene, "prometheus", "quicken") and is_equal_approx(scene.hurry_left(), skill("quicken").outside_seconds),
		"Quicken: for its Outside Seconds (%d), through a World casting" % skill("quicken").outside_seconds)
	ok(scene.hurried() and is_equal_approx(scene.party.hurry, OutsideMoves.HURRY), "  the party hurries, %.1f times as fast" % OutsideMoves.HURRY)
	ok(OutsideMoves.refusal(scene, "prometheus", "quicken") == "Already hurrying", "  not twice at once")
	scene._hurry_on(skill("quicken").outside_seconds + 1.0)
	ok(not scene.hurried() and is_equal_approx(scene.party.hurry, 1.0) and is_equal_approx(scene.party.move_speed, walking), "  then it wears off")
	ok(m.scene.moves_panel.who() == "prometheus", "the panel follows the lead")
	await close_map(m)


func noise():
	log_line("======== noise ========")
	var m := await plain_map()
	var listener_tile := find_tile(m, func(tile): return gap(tile, m.post) >= 3.0 and gap(tile, m.post) <= 4.0)
	var guard := add_guard(m, "Watchman", m.post, 0.0)
	var away := out_of_sight_of(m, [m.post])
	var watch: StealthWatch = await watch_it(m, listener_tile if listener_tile != NOWHERE else away)
	var scene: ExplorationScene = m.scene
	Campaign.set_leader("alithia")
	await settle()
	var heal := skill("heal")
	var near: float = m.party.sprite_for("alithia").global_position.distance_to(guard.global_position) / Grid.TILE_SIZE
	log_line("  Alithia %.1f tiles from the watchman" % near)
	heal.noise = SkillDefinition.Loudness.LOUD
	heal.noise_tiles = near + 2.0
	Campaign.strain(ally(), 12)
	if watch.spotted_by != null:
		ok(false, "the party was seen before the test began")
	else:
		ok(OutsideMoves.use(scene, "alithia", "heal"), "a loud Heal cast")
		ok(guard.mood == Guard.Mood.INVESTIGATING, "  the watchman comes to see what it was", "%s" % [Guard.Mood.keys()[guard.mood]])
	heal.noise = SkillDefinition.Loudness.UNMARKED
	heal.noise_tiles = 0.0
	await close_map(m)


func hiding_the_ui():
	log_line("======== hiding the UI ========")
	var m := await open_map()
	var watch: StealthWatch = await watch_it(m, out_of_sight_of(m, [m.post]))
	var scene: ExplorationScene = m.scene
	var hud: Control = scene.game_ui
	var key := InputEventKey.new()
	key.physical_keycode = KEY_U
	key.pressed = true
	scene._unhandled_input(key)
	await settle()
	ok(scene.ui_hidden, "U hides the UI")
	ok(not hud.get_node("Status").visible and not hud.get_node("Actions/StatusIcon").visible and not scene.moves_panel.visible,
		"  the portraits and the moves go")
	ok(hud.get_node("Actions/Information").visible, "  the log stays")
	ok(not watch.stealth_bar().visible, "  and the stealth bar goes")
	scene.game_ui.set_interaction_prompt("Press E to talk")
	ok(not hud.get_node("Actions/SelectTargetMessage").visible, "  no prompt while hidden")
	scene._unhandled_input(key)
	await settle()
	ok(not scene.ui_hidden and hud.get_node("Status").visible and scene.moves_panel.visible and watch.stealth_bar().visible, "again: all of it back")
	ok(InputMap.action_get_events(&"hide_ui").any(func(event): return event is InputEventJoypadButton), "a pad's button for it too")
	await close_map(m)


func the_sheet():
	log_line("======== the sheet's castings on a map ========")
	var m := await plain_map()
	OutsideMoves.pay("alithia", skill("heal"))
	var sheet := CharacterSheet.new()
	var member: Dictionary = Campaign.party_members().filter(func(each): return each.key == "alithia")[0]
	var pools: Array = sheet._pools_of(CharacterSheet.map_entry_of(member))
	var world: Array = pools.filter(func(pool): return pool.name == Stats.short_gate_name(1))
	ok(not world.is_empty() and world[0].left == 1 and world[0].most == 2, "a casting spent on the map is off the sheet's World pips",
		"%s" % [world])
	sheet.free()
	await close_map(m)


func press_key(scene: Node, keycode: Key):
	var key := InputEventKey.new()
	key.physical_keycode = keycode
	key.pressed = true
	scene._unhandled_input(key)


func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func familiar_anywhere():
	log_line("======== the familiar, on any map ========")
	var m := await plain_map()
	var scene: ExplorationScene = m.scene
	var keeper: FamiliarKeeper = scene.familiar_keeper
	var world: int = Campaign.gates_left_outside("alithia")[1]
	ok(scene.stealth == null and scene.familiar_refusal() == "", "nobody watching, and Alithia can call it", scene.familiar_refusal())
	ok(scene.summon_familiar() and keeper.familiar != null and scene.controlling_familiar() and m.party.rooted,
		"called and steered, the party waiting")
	ok(Campaign.free_familiar_used and Campaign.gates_left_outside("alithia")[1] == world, "  free: the first since a long rest")
	press_key(scene, KEY_E)
	await settle(2)
	var sprite = m.party.sprite_for("alithia")
	ok(keeper.perched() and not scene.controlling_familiar() and not m.party.rooted, "E: onto her shoulder, the party hers again")
	ok(keeper.familiar.global_position.distance_to(sprite.global_position + Familiar.SHOULDER) < 1.0, "  sitting up there, riding along")
	ok(OutsideMoves.refusal(scene, "alithia", "find_familiar").begins_with("On Alithia's shoulder"), "  the panel says where it is",
		OutsideMoves.refusal(scene, "alithia", "find_familiar"))
	press_key(scene, KEY_TAB)
	ok(scene.controlling_familiar() and not keeper.perched(), "Tab: off her shoulder and steered again")
	ok(OutsideMoves.use(scene, "alithia", "find_familiar") and keeper.perched(), "  Find Familiar on the panel, while it is out, sends it back too")
	scene.outside_spell()
	ok(keeper.familiar == null, "G lets it go")
	ok(scene.summon_familiar() and Campaign.gates_left_outside("alithia")[1] == world - 1, "the next one pays a World casting")
	scene.dismiss_familiar()
	Campaign.long_rest()
	ok(not Campaign.free_familiar_used, "a long rest, and the next is free again")
	await close_map(m)


## A crossroads watched, Alithia leading at 14 with Prometheus and Enfina, and a
## watchman `reach` tiles off (the fight's count) in a clear line, facing away.
func watched_with_guard(reach: int, extra: Callable = Callable()) -> Dictionary:
	var m := await open_map()
	for key in ["alithia", "prometheus", "enfina", "cyrus"]:
		if not Campaign.party_order.has(key):
			Campaign.add_member(key)
	Campaign.reach_level(14, true)
	Campaign.set_leader("alithia")
	await settle(3)
	var from := tile_at(m, m.party.position_of_leader())
	var spot := find_tile(m, func(tile): return manhattan(tile, from) == reach and standable(m, tile) and m.sight.clear(from, tile))
	var facing := rad_to_deg(Vector2(spot - from).angle())
	m.guard = add_guard(m, "Watchman", spot, facing)
	if extra.is_valid():
		extra.call(m, from)
	m.watch = await watch_it(m, from)
	settle_guard(m.watch, m.guard, facing)
	await settle(2)
	return m


## A magic sensor two tiles from the party.
func _add_sensor(map: Dictionary, from: Vector2i):
	var near := find_tile(map, func(tile): return manhattan(tile, from) == 2 and standable(map, tile) and tile != from)
	map.sensor = add_guard(map, "Ward Stone", near, 0.0, "mimic")
	map.sensor.kind = Guard.Kind.SENSOR


## A watchman far off, out of the party's sight.
func _add_walker(map: Dictionary, from: Vector2i):
	var far := find_tile(map, func(tile): return gap(tile, from) >= 9.0 and standable(map, tile) and not map.sight.clear(from, tile))
	map.walker = add_guard(map, "Walker", far, 0.0) if far != NOWHERE else null


func on_guards():
	log_line("======== on guards ========")
	var m := await watched_with_guard(3, _add_sensor)
	var scene: ExplorationScene = m.scene
	var watch: StealthWatch = m.watch
	var guard: Guard = m.guard
	ok(watch.spotted_by == null and OutsideMoves.refusal(scene, "alithia", "flash") == "", "Flash: a watchman in reach",
		OutsideMoves.refusal(scene, "alithia", "flash"))
	ok(OutsideMoves.use(scene, "alithia", "flash") and guard.mood == Guard.Mood.BLINDED and guard.sees_nothing(), "  struck blind: he sees nothing")
	watch._refresh_seen(guard)
	ok(watch._seen.get(guard, {}).is_empty(), "  nothing at all")
	ok(OutsideMoves.refusal(scene, "alithia", "flash") == "Nobody in reach it could take hold of", "  and not twice at once")
	guard.end_errand()
	ok(not guard.sees_nothing(), "  the spell over, he sees again")
	var from: Vector2 = m.party.position_of_leader()
	ok(OutsideMoves.use(scene, "alithia", "dread_visage") and guard.mood == Guard.Mood.FRIGHTENED, "Dread Visage: he runs")
	ok(guard.errand_at().distance_to(from) >= guard.global_position.distance_to(from), "  away from her",
		"%.0f vs %.0f" % [guard.errand_at().distance_to(from), guard.global_position.distance_to(from)])
	guard.end_errand()
	ok(OutsideMoves.use(scene, "alithia", "bewilder") and guard.mood == Guard.Mood.BEWILDERED and guard.sees_nothing(), "Bewilder: he wanders, seeing nothing")
	guard.end_errand()
	ok(OutsideMoves.refusal(scene, "alithia", "intuition") == "Nobody in reach with a round still to learn", "Intuition: a man at his post has no round to learn")
	watch.learn_route(guard)
	ok(watch.route_known(guard), "  one read is known")
	ok(OutsideMoves.use(scene, "prometheus", "dispel_magic") and m.sensor.switched_off() and m.sensor.sees_nothing(),
		"Dispel Magic: the magic sensor stilled", OutsideMoves.refusal(scene, "prometheus", "dispel_magic"))
	ok(OutsideMoves.use(scene, "enfina", "intimidate") and guard.mood == Guard.Mood.FRIGHTENED, "Intimidate, with no gate to pay: he runs",
		OutsideMoves.refusal(scene, "enfina", "intimidate"))
	guard.end_errand()
	ok(OutsideMoves.use(scene, "enfina", "intimidate"), "  and again at once: no waiting", OutsideMoves.refusal(scene, "enfina", "intimidate"))
	guard.end_errand()
	await settle()
	ok(OutsideMoves.refusal(scene, "alithia", "votive_flame") == "", "Votive Flame at an unaware watchman", OutsideMoves.refusal(scene, "alithia", "votive_flame"))
	ok(OutsideMoves.use(scene, "alithia", "votive_flame") and watch.spotted_by == guard, "  springs an ambush")
	var fight: EncounterDefinition = Campaign.current_encounter
	ok(fight != null and fight.has_meta("opener") and fight.get_meta("opener").move == "votive_flame", "  with it as the opening blow")
	var marked := fight.spawns.filter(func(spawn): return spawn.has_meta("opened_on")) if fight != null else []
	ok(marked.size() == 1 and marked[0].surprised, "  on him, caught off guard")
	await close_map(m)


func the_opening_blow():
	log_line("======== the opening blow, in the fight ========")
	Campaign.reset()
	Campaign.set_party(["alithia"], 8)
	var encounter: EncounterDefinition = load("res://data/encounters/encounter_02_sappers.tres").duplicate(true)
	encounter.fighters.assign(["alithia"])
	encounter.skip_deployment = true
	var marked: SpawnDefinition = null
	for spawn in encounter.spawns:
		if spawn.side == 1 and marked == null:
			marked = spawn
	marked.display_name = "Marked"
	marked.set_meta("opened_on", true)
	encounter.set_meta("opener", {"key": "alithia", "move": "votive_flame"})
	Campaign.current_encounter = encounter
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(6)
	var combat: Combat = game.get_node("VisualCombat")
	var log_text: RichTextLabel = combat.game_ui.get_node("Actions/Information/Text")
	await until(func(): return "opens with" in log_text.get_parsed_text() or "falls short" in log_text.get_parsed_text(), 10.0)
	await wait(4.0)
	var alithia: Dictionary = {}
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == "alithia":
			alithia = comb
	var said: String = log_text.get_parsed_text()
	ok(combat._opening_done and ("opens with Votive Flame" in said or "falls short" in said), "before the first turn, the opening blow", said.right(300))
	ok(not alithia.is_empty() and not alithia.get("skill_used_this_turn", false), "  free: her own first turn untouched")
	game.queue_free()
	await settle()
	log_line("")


func walls_and_moving():
	log_line("======== walls, blinking, flying ========")
	var m := await plain_map(14)
	Campaign.add_member("prometheus")
	await settle(3)
	var scene: ExplorationScene = m.scene
	var from := tile_at(m, m.party.position_of_leader())
	var spot := find_tile(m, func(tile): return manhattan(tile, from) == 1 and standable(m, tile))
	var wall := BreakableWall.new()
	wall.name = "TestWall"
	m.map.add_child(wall)
	wall.global_position = at(m, spot)
	scene._collect_walls(m.map)
	ok(not scene.is_walkable(at(m, spot)), "a breakable wall: nobody walks through it")
	ok(OutsideMoves.refusal(scene, "alithia", "votive_flame") == "Only a spell, an item or Enfina's strength knocks a wall down",
		"  not Votive Flame, a skill of hers", OutsideMoves.refusal(scene, "alithia", "votive_flame"))
	ok(OutsideMoves.refusal(scene, "alithia", "holy_lance") == "", "  but Holy Lance, a spell", OutsideMoves.refusal(scene, "alithia", "holy_lance"))
	ok(OutsideMoves.refusal(scene, "cyrus", "rapier") == "Only a spell, an item or Enfina's strength knocks a wall down",
		"  not Cyrus's rapier", OutsideMoves.refusal(scene, "cyrus", "rapier"))
	ok(OutsideMoves.refusal(scene, "enfina", "greatsword_attack") == "", "  but Enfina's greatsword", OutsideMoves.refusal(scene, "enfina", "greatsword_attack"))
	Campaign.give_item("alithia", "tiny_bomb")
	m.scene.moves_panel.show_tab(OutsideMovesPanel.Tab.ITEMS)
	ok(m.scene.moves_panel.button_for("tiny_bomb") != null, "  a bomb she carries, on the panel's Items")
	ok(OutsideMoves.refusal(scene, "alithia", "tiny_bomb") == "", "  which could do it too", OutsideMoves.refusal(scene, "alithia", "tiny_bomb"))
	m.scene.moves_panel.show_tab(OutsideMovesPanel.Tab.SKILLS)
	ok(OutsideMoves.use(scene, "alithia", "holy_lance") and wall.broken and scene.is_walkable(at(m, spot)), "  Holy Lance brings it down")
	ok(Campaign.flag(wall.flag_for(scene.map_path())), "  for good: kept in the flags")
	var before: Vector2 = m.party.position_of_leader()
	ok(OutsideMoves.use(scene, "prometheus", "hermes_step") and m.party.position_of_leader().distance_to(before) >= Grid.tiles(1.0),
		"Hermes Step: the party steps ahead", OutsideMoves.refusal(scene, "prometheus", "hermes_step"))
	ok(OutsideMoves.use(scene, "prometheus", "hover") and scene.flying(), "Hover: the party flies")
	var crate := find_tile(m, func(tile): return scene._blocking.has(tile) and not scene._blocking_fliers.has(tile) and not scene._small_gaps.has(tile))
	if crate != NOWHERE:
		ok(scene.is_walkable(at(m, crate)), "  over a barrel")
	ok(OutsideMoves.refusal(scene, "prometheus", "hover") == "Already flying", "  not twice at once")
	scene._fly_on(1000.0)
	ok(not scene.flying() and (crate == NOWHERE or not scene.is_walkable(at(m, crate))), "  and down when the time is up")
	await close_map(m)


func lures_cover_traps():
	log_line("======== lures, cover, traps ========")
	var m := await watched_with_guard(3, _add_walker)
	var scene: ExplorationScene = m.scene
	var watch: StealthWatch = m.watch
	ok(OutsideMoves.use(scene, "prometheus", "kindled_hound"), "Kindled Hound, as a lure", OutsideMoves.refusal(scene, "prometheus", "kindled_hound"))
	var lures := scene.get_children().filter(func(node): return node is OutsideMoves.Decoy)
	ok(lures.size() == 1, "  something stirs ahead")
	ok(not watch._ripples.is_empty() and is_equal_approx(watch._ripples.back()[2], OutsideMoves.LURE_TILES), "  heard %d tiles about" % OutsideMoves.LURE_TILES)
	ok(not watch.leader_hiding() and OutsideMoves.use(scene, "cyrus", "stealth") and watch.leader_hiding(), "Stealth: cover where she stands, and she is hidden in it",
		OutsideMoves.refusal(scene, "cyrus", "stealth"))
	ok(OutsideMoves.use(scene, "cyrus", "snare"), "Snare: a trap laid", OutsideMoves.refusal(scene, "cyrus", "snare"))
	var traps := scene.get_children().filter(func(node): return node is OutsideMoves.Trap)
	ok(traps.size() == 1, "  where she stands")
	if not traps.is_empty() and m.walker != null:
		m.walker.global_position = traps[0].global_position
		await settle(3)
		ok(m.walker.knocked_out and not is_instance_valid(traps[0]), "  a guard walks onto it, and is down")
	await close_map(m)


func the_familiar_stage():
	log_line("======== the familiar's stage ========")
	Campaign.reset()
	Campaign.current_map = "res://maps/stealth_stages/stealth_8.tscn"
	var scene: ExplorationScene = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(scene)
	await settle(6)
	scene.end_blocking_interaction()
	ok(Campaign.party_order.has("alithia") and scene.stealth != null, "Alithia on a watched stage", "%s" % [Campaign.party_order])
	var grate := Vector2i(7, 2)
	var at: Vector2 = scene._tile_map.to_global(scene._tile_map.map_to_local(grate))
	ok(scene.is_small_gap(grate) and not scene.is_walkable(at), "a grate: no way through for the party")
	ok(scene.is_walkable_for(at, Sizes.Size.TINY), "  but a rat fits")
	ok(scene.walls().size() == 1 and not scene.is_walkable(scene.walls()[0].global_position), "a cracked wall standing in the way")
	ok(scene.familiar_refusal() == "", "the familiar can be called", scene.familiar_refusal())
	scene.queue_free()
	await settle()
	log_line("")


func magic_traps():
	log_line("======== magical traps and InstaHack ========")
	var m := await plain_map(14)
	Campaign.add_member("prometheus")
	Campaign.learned_spells["prometheus"] = ["instahack"]
	await settle(3)
	var scene: ExplorationScene = m.scene
	ok(OutsideMoves.refusal(scene, "prometheus", "instahack") == "Only as a magical trap goes off", "InstaHack on the panel: only as a trap goes off")
	var from := tile_at(m, m.party.position_of_leader())
	var spots := []
	var first := find_tile(m, func(tile): return manhattan(tile, from) == 3 and standable(m, tile))
	if first != NOWHERE:
		spots.append(first)
		var second := find_tile(m, func(tile): return manhattan(tile, from) == 3 and manhattan(tile, first) >= 3 and standable(m, tile))
		if second != NOWHERE:
			spots.append(second)
	ok(spots.size() >= 2, "(two floor tiles for traps)")
	if spots.size() < 2:
		await close_map(m)
		return
	var traps := []
	for i in 2:
		var trap := MagicTrap.new()
		trap.name = "Glyph%d" % i
		m.map.add_child(trap)
		trap.global_position = at(m, spots[i])
		traps.append(trap)
	scene._traps = traps
	var pandora: int = Campaign.gates_left_outside("prometheus")[3]
	var hp: int = Campaign.party_members()[0].hp
	QuickTime.answer = 1
	m.party.teleport(at(m, spots[0]))
	await until(func(): return not traps[0].armed and scene.springing == null, 3.0)
	ok(not traps[0].armed and Campaign.gates_left_outside("prometheus")[3] == pandora - 1, "stepped on: InstaHack in time - hacked apart, for a Pandora casting")
	ok(Campaign.party_members()[0].hp == hp, "  and nobody hurt")
	QuickTime.answer = 0
	m.party.teleport(at(m, spots[1]))
	await until(func(): return not traps[1].armed and scene.springing == null, 3.0)
	var leader: String = Campaign.party_members()[0].key
	ok(not traps[1].armed and Campaign.party_state.get(leader, {}).get("hp", hp) < hp, "too late: the laser hits")
	ok(Campaign.flag(traps[1].flag_for(scene.map_path())), "  and the glyph is spent for good")
	QuickTime.answer = -1
	await close_map(m)


func walls_in_a_fight():
	log_line("======== walls in a fight ========")
	var m := await open_map()
	var from := tile_at(m, m.party.position_of_leader())
	var spot := find_tile(m, func(tile): return manhattan(tile, from) >= 2 and manhattan(tile, from) <= 3 and standable(m, tile))
	var wall := BreakableWall.new()
	wall.name = "FightWall"
	m.map.add_child(wall)
	wall.global_position = at(m, spot)
	m.scene._collect_walls(m.map)
	var watch: StealthWatch = await watch_it(m, from)
	var fight := watch.build_fight()
	var standing := fight.spawns.filter(func(spawn): return spawn.combatant_key == "breakable_wall")
	ok(standing.size() == 1 and standing[0].position == spot and standing[0].has_meta("wall_flag"), "a stealth fight brings the wall along")
	await close_map(m)
	Campaign.reset()
	Campaign.set_party(["alithia", "enfina", "cyrus"], 8)
	var encounter: EncounterDefinition = load("res://data/encounters/encounter_02_sappers.tres").duplicate(true)
	encounter.fighters.assign(["alithia", "enfina", "cyrus"])
	encounter.skip_deployment = true
	var replaced: SpawnDefinition = null
	for each in encounter.spawns:
		if each.side == 1 and replaced == null:
			replaced = each
	var stone := SpawnDefinition.new()
	stone.combatant_key = "breakable_wall"
	stone.side = 1
	stone.position = replaced.position
	stone.set_meta("wall_flag", "broken:test_wall")
	var spawns: Array[SpawnDefinition] = []
	for each in encounter.spawns:
		spawns.append(stone if each == replaced else each)
	encounter.spawns = spawns
	Campaign.current_encounter = encounter
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(8)
	var combat: Combat = game.get_node("VisualCombat")
	var thing: Dictionary = {}
	var by := {}
	for comb in combat.combatants:
		if comb.has("object") and comb.object.wall:
			thing = comb
		by[comb.get("combatant_key", "")] = comb
	ok(not thing.is_empty() and thing.get("wall_flag", "") == "broken:test_wall", "a cracked wall on the field")
	if thing.is_empty():
		game.queue_free()
		await settle()
		return
	var full: int = thing.hp
	var rapier: SkillDefinition = skill("rapier")
	combat.do_damage(by.cyrus, thing, rapier.all_effects()[0], rapier)
	ok(thing.hp == full, "Cyrus's rapier: it holds")
	var swing: SkillDefinition = skill("greatsword_attack")
	combat.do_damage(by.enfina, thing, swing.all_effects()[0], swing)
	ok(thing.hp < full, "Enfina's greatsword: it cracks", "%d -> %d" % [full, thing.hp])
	var lance: SkillDefinition = skill("holy_lance")
	for i in 8:
		if thing.alive:
			combat.do_damage(by.alithia, thing, lance.all_effects()[0], lance)
	await settle(3)
	ok(not thing.alive and Campaign.flag("broken:test_wall"), "a spell brings it down, and the map will know")
	game.queue_free()
	await settle()
	log_line("")
