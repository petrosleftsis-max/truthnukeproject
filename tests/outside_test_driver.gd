extends "res://StealthHarness.gd"
## Moves outside a fight, Phase 1 (docs/outside_combat_plan.md; the designer,
## 2026-10-26): every move on the map's panel, what each does out there, paying
## real gates - and the Gates of Iris first for a spell marked Out Of Combat -
## the out-of-combat toggle, noise marks heard by guards, the Outside Spell key
## on a map nobody watches, the Hide UI key, and the sheet's castings on a map.


func suite() -> String:
	return "outside"


func time_limit() -> float:
	return 240.0


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
		"resuscitate": OutsideMoves.Use.REVIVE, "run": OutsideMoves.Use.SPEED, "quicken": OutsideMoves.Use.SPEED,
		"find_familiar": OutsideMoves.Use.FAMILIAR, "invisibility": OutsideMoves.Use.INVISIBILITY,
		"votive_flame": OutsideMoves.Use.NONE, "light_swing": OutsideMoves.Use.NONE, "guard": OutsideMoves.Use.NONE,
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
	ok(panel.button_for("votive_flame").disabled and OutsideMoves.refusal(scene, "alithia", "votive_flame") == "Only in a fight, for now",
		"  a damaging one greyed: only in a fight, for now")
	panel.show_spells(true)
	ok(panel.button_for("heal") != null and panel.button_for("find_familiar") != null, "her spells, on the Spells tab")
	ok(panel.button_for("heal").disabled and OutsideMoves.refusal(scene, "alithia", "heal") == "Nobody is hurt", "  Heal greyed with nobody hurt")
	ok(OutsideMoves.refusal(scene, "alithia", "find_familiar") == "Only on a watched map", "  Find Familiar only where guards watch")
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
	if ready.size() == 1:
		ok(Campaign.party_state[other].hp > before, "  one of them: cast at once")
	else:
		ok(is_instance_valid(scene.spell_choice), "  more than one: which?")
		if is_instance_valid(scene.spell_choice):
			scene.spell_choice.find_child(ready[0].move, true, false).pressed.emit()
			await settle(3)
		ok(Campaign.party_state[other].hp > before, "  chosen: cast")
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
	ok(OutsideMoves.use(scene, "alithia", "run"), "Run, out here")
	ok(scene.hurried() and is_equal_approx(scene.party.hurry, OutsideMoves.HURRY), "  the party hurries, %.1f times as fast" % OutsideMoves.HURRY)
	ok(is_equal_approx(scene.hurry_left(), OutsideMoves.HURRY_SECONDS), "  for %d seconds" % OutsideMoves.HURRY_SECONDS)
	ok(OutsideMoves.refusal(scene, "alithia", "run") == "Already hurrying", "  not twice at once")
	scene._hurry_on(OutsideMoves.HURRY_SECONDS + 1.0)
	ok(not scene.hurried() and is_equal_approx(scene.party.hurry, 1.0) and is_equal_approx(scene.party.move_speed, walking), "  then it wears off")
	Campaign.add_member("prometheus")
	Campaign.set_leader("prometheus")
	await settle(3)
	ok(OutsideMoves.use(scene, "prometheus", "quicken") and is_equal_approx(scene.hurry_left(), skill("quicken").outside_seconds),
		"Quicken: for its Outside Seconds (%d), through a World casting" % skill("quicken").outside_seconds)
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
