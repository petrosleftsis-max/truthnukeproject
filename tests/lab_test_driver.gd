extends Node
## The late-Chapter-I laboratory sequence - a TEMPORARY test harness, not story
## content (data/dungeons/lab_chapter1_sequence.tres): its three fights the same
## as the ones they copy but for their levels, a short rest between them (half
## of what was lost back, no gates, the fallen down unless Resuscitated there), a
## kit of consumables filling every belt and used up as it goes, and every
## fight logged (LabMetrics) - a tick laid at its source's door. Its boss is
## Erysichthon; the Ash Warden variant (lab_chapter1_sequence_ash_warden.tres)
## differs only in the last fight.

var LOG_PATH := HarnessLog.path_for("lab")
const LAB := "res://data/dungeons/lab_chapter1_sequence.tres"
const ASH_WARDEN_LAB := "res://data/dungeons/lab_chapter1_sequence_ash_warden.tres"
const DEMO := "res://data/dungeons/dungeon_demo.tres"
const SOURCES := ["res://data/encounters/encounter_03_watcher.tres", "res://data/encounters/encounter_hired_blades.tres",
	"res://data/encounters/boss_glutton.tres"]
const ASH_WARDEN := "res://data/encounters/boss_ash_warden.tres"
const LEVELS := [16, 17, 18, 18]

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
	get_tree().create_timer(280.0, true, false, true).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	var booted = get_tree().current_scene
	if booted != null:
		booted.queue_free()
		await settle()
	the_data()
	await the_run()
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


func arrived_at(path: String, seconds: float = 10.0) -> bool:
	var waited := 0.0
	while waited < seconds:
		var scene = get_tree().current_scene
		if scene != null and scene.scene_file_path == path and scene.is_node_ready() and not SceneTransition.is_changing():
			await settle(6)
			return true
		await get_tree().process_frame
		waited += get_process_delta_time()
	return false


func fighter(combat, key: String) -> Dictionary:
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == key and not comb.get("illusion", false):
			return comb
	return {}


func is_object(key: String) -> bool:
	return CombatantDatabase.combatants.has(key) and CombatantDatabase.combatants[key] is BattleObjectDefinition


func the_data():
	log_line("======== the sequence, and its fights ========")
	var lab: DungeonDefinition = load(LAB)
	ok(lab != null and lab.stages.size() == 3, "three stages")
	ok(lab.party == ["enfina", "cyrus", "prometheus", "alithia"] and lab.level == 18, "the whole party, at 18", "%s at %d" % [lab.party, lab.level])
	ok(lab.short_rests and not lab.skips_rests and lab.logs_metrics, "a short rest between, and logged")
	ok(not lab.rest_revives and lab.gate_recoveries == 0 and lab.store == "", "no gates given back, nobody up by themselves, and no store")
	var kit_ok := true
	for key in lab.party:
		var kit: Array = lab.kit.get(key, [])
		kit_ok = kit_ok and kit.size() == 4 and kit.all(func(item): return ItemDatabase.items.has(item))
	ok(kit_ok, "a kit for each: four things, one for every slot of a Simple Baldric", "%s" % [lab.kit])
	var salts: ItemDefinition = ItemDatabase.item("smelling_salts")
	ok(Array(lab.kit.cyrus).count("smelling_salts") == 1 and Array(lab.kit.cyrus).count("small_bomb") == 1 and salts != null
		and salts.targets_fallen, "  Cyrus carries Smelling Salts, to bring somebody fallen round, in place of his second Small Bomb", "%s" % [lab.kit.cyrus])
	var demo: DungeonDefinition = load(DEMO)
	ok(not demo.skips_rests and demo.short_rests and not demo.logs_metrics and demo.kit.is_empty(),
		"the Dungeon Demo takes short rests too (2026-10-25), carries no kit, and logs nothing")
	var variant: DungeonDefinition = load(ASH_WARDEN_LAB)
	ok(variant != null and variant.stages.size() == 3, "the Ash Warden variant: three stages")
	ok(variant.party == lab.party and variant.level == lab.level and variant.knows_every_spell == lab.knows_every_spell
		and variant.short_rests and not variant.skips_rests and variant.logs_metrics and not variant.rest_revives and variant.gate_recoveries == 0
		and variant.store == "" and variant.kit == lab.kit, "  the same party, level, rules, kit and logging")
	ok(variant.stages[0].encounter == lab.stages[0].encounter and variant.stages[1].encounter == lab.stages[1].encounter,
		"  the same first two fights")
	ok(lab.stages[2].encounter.resource_path.ends_with("lab_c_erysichthon.tres")
		and variant.stages[2].encounter.resource_path.ends_with("lab_c_ash_warden.tres"),
		"  the last: Erysichthon in the primary, the Ash Warden in the variant")
	var copies := lab.stages.map(func(stage): return stage.encounter)
	copies.append(variant.stages[2].encounter)
	var sources := SOURCES.duplicate()
	sources.append(ASH_WARDEN)
	for i in 4:
		var copy: EncounterDefinition = copies[i]
		var source: EncounterDefinition = load(sources[i])
		var same := copy.spawns.size() == source.spawns.size()
		var levels_right := true
		for s in mini(copy.spawns.size(), source.spawns.size()):
			var a: SpawnDefinition = copy.spawns[s]
			var b: SpawnDefinition = source.spawns[s]
			same = same and a.combatant_key == b.combatant_key and a.side == b.side and a.position == b.position \
				and a.starting_items == b.starting_items and a.equipment == b.equipment and a.defense == b.defense and a.weapon_base == b.weapon_base
			if is_object(a.combatant_key):
				levels_right = levels_right and a.level == b.level
			else:
				levels_right = levels_right and a.level == (18 if a.side == 0 else LEVELS[i])
		ok(same, "%s: the same spawns as %s - who, where, what they carry, their weapon and Defense" % [copy.display_name, source.display_name])
		ok(levels_right, "  every enemy at %d, the party's tiles at 18, the objects as they were" % LEVELS[i])
		ok(copy.terrain_scene == source.terrain_scene and copy.hazards == source.hazards and copy.escape_points == source.escape_points
			and copy.gold_reward == source.gold_reward, "  the same map, hazards, ways out and pay")
		ok(copy.victory_dialogue == null and not copy.dialogue_decides_prisoners, "  and no story conversation after it")
	log_line("")


func the_run():
	log_line("======== a short rest: half of what was lost, no gates, the fallen down but for Resuscitate ========")
	var lab: DungeonDefinition = load(LAB)
	LabMetrics.begin_run("test-harness")
	Campaign.start_dungeon(lab)
	var stocked := true
	for key in lab.party:
		var belt: Array = Campaign.inventory_of(key).slice(0, Campaign.combat_slots_of(key))
		stocked = stocked and belt == Array(lab.kit[key])
	ok(stocked, "every belt filled with its kit")
	ok(await arrived_at("res://scenes/game.tscn"), "into the first fight")
	var game = get_tree().current_scene
	var combat = game.get_node("VisualCombat")
	combat.reaction_prompt = null
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(2)
	ok(combat.get_children().any(func(c): return c is LabMetrics), "the fight is being logged")
	ok(combat.encounter == lab.stages[0].encounter, "the City Fight's enemies at 16", combat.encounter.display_name)
	var ranger := fighter(combat, "ranger")
	var priest := fighter(combat, "priest")
	ok(ranger.max_spell_slots == Stats.half_caster_gates(16) and Stats.half_caster_gates(16) == Stats.gates_for_level(8)
		and priest.max_spell_slots == Stats.gates_for_level(16), "a Ranger at 16 has a half caster's gates - those of 8 - and a Priest a full caster's",
		"%s against %s" % [ranger.max_spell_slots.slice(1, 4), priest.max_spell_slots.slice(1, 4)])
	var cyrus := fighter(combat, "cyrus")
	var prometheus := fighter(combat, "prometheus")
	var enfina := fighter(combat, "enfina")
	var alithia := fighter(combat, "alithia")
	ok(cyrus.level == 18 and prometheus.level == 18, "the party at 18")
	cyrus.hp = 20
	var hermes_before: int = prometheus.spell_slots[2]
	prometheus.spell_slots[2] = maxi(hermes_before - 2, 0)
	var hermes_left: int = prometheus.spell_slots[2]
	var pandora_before: int = alithia.spell_slots[3]
	combat.consume_item(cyrus, "mediocre_cure_potion")
	# A Ranger's Burn ticking on Cyrus: laid at the Ranger's door, not his.
	var burn: ConditionDefinition = load("res://data/conditions/burn.tres")
	combat.tick_condition_damage(cyrus, burn, 0.0, 1.0, ranger)
	cyrus.hp = 20
	enfina.hp = 0
	enfina.alive = false
	var foe: Dictionary = {}
	for comb in combat.combatants:
		if comb.side == 1 and comb.alive and not comb.has("object"):
			foe = comb
			break
	combat.lose_hp(foe, 7)
	combat.groups[Combat.Group.ENEMIES].clear()
	combat.combat_finish()
	await settle(4)
	var result = game.get_node("ResultUI")
	ok(result.rest != null and result.rest.find_child("Rested", true, false).text.contains("short rest"), "won: a short rest",
		result.rest.find_child("Rested", true, false).text if result.rest != null else "no rest")
	var most: int = Campaign.party_state.cyrus.max_hp
	ok(Campaign.party_state.cyrus.hp == 20 + roundi((most - 20) * Campaign.SHORT_REST_MENDS), "Cyrus gets back half of what he lost",
		"%d of %d" % [Campaign.party_state.cyrus.hp, most])
	ok(Campaign.party_state.prometheus.spell_slots[2] == hermes_left, "Prometheus's spent Hermes castings stay spent",
		"%d of %d" % [Campaign.party_state.prometheus.spell_slots[2], hermes_before])
	ok(not Campaign.party_state.enfina.alive, "Enfina, fallen, stays down")
	var button = result.rest.find_child("Resuscitate_enfina", true, false)
	ok(button != null and not button.disabled and Campaign.resuscitator() == "alithia", "  with Alithia's Resuscitate offered for her")
	var enfina_most: int = Campaign.party_state.enfina.max_hp
	ok(result.rest.resuscitate("enfina"), "  cast")
	await settle(2)
	var weakened := roundi(enfina_most * 0.9)
	var revived := roundi(weakened * 0.5)
	ok(Campaign.party_state.enfina.alive and Campaign.party_state.enfina.hp == revived + roundi((weakened - revived) * Campaign.SHORT_REST_MENDS)
		and is_equal_approx(Campaign.party_state.enfina.get("frailty", 1.0), 0.9),
		"  she is back up with half her health, then rested like the rest - a tenth weaker until a long rest",
		"%d of %d" % [Campaign.party_state.enfina.hp, Campaign.party_state.enfina.max_hp])
	ok(Campaign.party_state.alithia.spell_slots[3] == pandora_before - 1, "  for one of Alithia's Pandora castings",
		"%d of %d" % [Campaign.party_state.alithia.spell_slots[3], pandora_before])
	ok(result.rest.find_child("Resuscitate_enfina", true, false) == null or result.rest.find_child("Resuscitate_enfina", true, false).is_queued_for_deletion(),
		"  and nobody fallen is offered any more")
	ok(FileAccess.file_exists(LabMetrics.summary_path()) and FileAccess.file_exists(LabMetrics.events_path()), "the run's summary and events are written",
		ProjectSettings.globalize_path(LabMetrics.summary_path()))
	var summary := FileAccess.get_file_as_string(LabMetrics.summary_path())
	ok(summary.contains("# Laboratory run: test-harness") and summary.contains("## Stage 1: Lab A") and summary.contains("Checkpoint, as it began")
		and summary.contains("Checkpoint, as it ended"), "stage 1 in it, with its checkpoints")
	ok(summary.contains("Hermes"), "and the gates left, by depth")
	var events_now := FileAccess.get_file_as_string(LabMetrics.events_path())
	ok(events_now.contains(",damage,"), "the hit is in the events")
	ok(events_now.contains(",damage,%s,enemies,Cyrus," % ranger.name) and events_now.contains("lingering: Burn"),
		"the Burn's tick on Cyrus is the Ranger's, and says so", ranger.name)

	result.rest.continued.emit()
	ok(await arrived_at("res://scenes/game.tscn"), "on to the second fight")
	game = get_tree().current_scene
	combat = game.get_node("VisualCombat")
	combat.reaction_prompt = null
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(2)
	ok(combat.encounter == lab.stages[1].encounter, "the Hired Blades at 17", combat.encounter.display_name)
	ok(fighter(combat, "cyrus").hp == Campaign.party_state.cyrus.hp, "Cyrus comes in as he left the rest", "%d" % fighter(combat, "cyrus").hp)
	ok(fighter(combat, "prometheus").spell_slots[2] == hermes_left, "and Prometheus's gates as they were", "%d" % fighter(combat, "prometheus").spell_slots[2])
	enfina = fighter(combat, "enfina")
	ok(enfina.alive and enfina.hp == Campaign.party_state.enfina.hp and enfina.max_hp < CombatantDatabase.combatants.enfina.hp_at(18),
		"Enfina fights again, weakened", "%d / %d" % [enfina.hp, enfina.max_hp])
	ok(Campaign.count_of("cyrus", "mediocre_cure_potion") == 0 and Campaign.count_of("cyrus", "small_bomb") == 1
		and Campaign.count_of("cyrus", "smelling_salts") == 1, "Cyrus's potion is gone, his bomb and Smelling Salts still there")
	combat.groups[Combat.Group.ENEMIES].clear()
	combat.combat_finish()
	await settle(4)
	result = game.get_node("ResultUI")
	result.rest.continued.emit()
	ok(await arrived_at("res://scenes/game.tscn"), "on to the boss")
	game = get_tree().current_scene
	combat = game.get_node("VisualCombat")
	combat.reaction_prompt = null
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(2)
	log_line("")

	log_line("======== the boss: Erysichthon - telegraphs, stagger, what is put on it, what it eats ========")
	var boss := fighter(combat, "glutton")
	ok(not boss.is_empty() and boss.level == 18, "Erysichthon, at 18", "%d" % boss.get("level", 0))
	enfina = fighter(combat, "enfina")
	cyrus = fighter(combat, "cyrus")
	await combat.declare(boss, "devour", enfina.position)
	combat.add_stagger(boss, 10.0, "damage")
	combat.drop_declared(boss, "a test")
	combat.put_condition(boss, load("res://data/conditions/poisoned.tres"), 2, cyrus.name, true, cyrus.id)
	combat.shrug_off(boss, "Stunned", true)
	combat.cue("ate:Carrion Heap")
	combat.groups[Combat.Group.ENEMIES].clear()
	combat.combat_finish()
	await settle(4)
	result = game.get_node("ResultUI")
	ok(result.get_node("Panel/VBox/BackButton").text == "Finish", "the last fight won: Finish", result.get_node("Panel/VBox/BackButton").text)
	summary = FileAccess.get_file_as_string(LabMetrics.summary_path())
	ok(summary.contains("## Stage 2: Lab B") and summary.contains("## Stage 3: Lab C"), "all three stages in the one summary")
	ok(summary.contains("Devour - dropped (a test)") and summary.contains("Enfina"), "the declared move: dropped, and who stood in it")
	ok(summary.contains("Stagger gained, by source") and summary.contains("damage 10") and summary.contains("blocked condition 15"),
		"its stagger, by source - a blow and a condition it shrugged off")
	ok(summary.contains("### The boss: Erysichthon") and summary.contains("- Turns offered:") and summary.contains("- Lost, by cause:")
		and summary.contains("- Longest run of turns not its own"), "its own section: its turns, and how many it lost and why")
	ok(summary.contains("- Put on it: Poisoned (Cyrus x1)"), "  what was put on it, and by whom")
	ok(summary.contains("- Shrugged off: Stunned x1"), "  what it shrugged off")
	ok(summary.contains(": eats Carrion Heap"), "  and what it ate")
	var events := FileAccess.get_file_as_string(LabMetrics.events_path())
	ok(events.contains(",declared,") and events.contains(",declared dropped,") and events.contains(",stagger,")
		and events.contains(",condition,Cyrus,") and events.contains(",blocked,") and events.contains(",cue,"), "and in the events")
	Campaign.reset()
	log_line("")
