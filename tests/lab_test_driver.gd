extends Node
## The late-Chapter-I laboratory sequence - a TEMPORARY test harness, not story
## content (data/dungeons/lab_chapter1_sequence.tres): its three fights the same
## as the ones they copy but for their levels, no rest between them so health
## and spent gates carry forward, and every fight logged (LabMetrics). Its boss
## is Erysichthon; the Ash Warden variant (lab_chapter1_sequence_ash_warden.tres)
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
	ok(lab.skips_rests and lab.logs_metrics, "no rest between, and logged")
	ok(not lab.rest_revives and lab.gate_recoveries == 0 and lab.store == "", "nothing given back, and no store")
	var demo: DungeonDefinition = load(DEMO)
	ok(not demo.skips_rests and not demo.logs_metrics, "the Dungeon Demo still rests, and logs nothing")
	var variant: DungeonDefinition = load(ASH_WARDEN_LAB)
	ok(variant != null and variant.stages.size() == 3, "the Ash Warden variant: three stages")
	ok(variant.party == lab.party and variant.level == lab.level and variant.knows_every_spell == lab.knows_every_spell
		and variant.skips_rests and variant.logs_metrics and not variant.rest_revives and variant.gate_recoveries == 0
		and variant.store == "", "  the same party, level, rules and logging")
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
	log_line("======== no rest: health and gates carry forward ========")
	var lab: DungeonDefinition = load(LAB)
	LabMetrics.begin_run("test-harness")
	Campaign.start_dungeon(lab)
	ok(await arrived_at("res://scenes/game.tscn"), "into the first fight")
	var game = get_tree().current_scene
	var combat = game.get_node("VisualCombat")
	combat.reaction_prompt = null
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(2)
	ok(combat.get_children().any(func(c): return c is LabMetrics), "the fight is being logged")
	ok(combat.encounter == lab.stages[0].encounter, "the City Fight's enemies at 16", combat.encounter.display_name)
	var cyrus := fighter(combat, "cyrus")
	var prometheus := fighter(combat, "prometheus")
	ok(cyrus.level == 18 and prometheus.level == 18, "the party at 18")
	cyrus.hp = 20
	var hermes_before: int = prometheus.spell_slots[2]
	prometheus.spell_slots[2] = maxi(hermes_before - 2, 0)
	var hermes_left: int = prometheus.spell_slots[2]
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
	ok(result.rest == null and result.get_node("Panel").visible, "won: the result, and no rest")
	ok(result.get_node("Panel/VBox/BackButton").visible and result.get_node("Panel/VBox/BackButton").text == "On to the next fight (no rest)",
		"with a way straight on", result.get_node("Panel/VBox/BackButton").text)
	ok(Campaign.party_state.cyrus.hp == 20, "Cyrus is not healed", "%d" % Campaign.party_state.cyrus.hp)
	ok(Campaign.party_state.prometheus.spell_slots[2] == hermes_left, "Prometheus's spent Hermes castings stay spent",
		"%d of %d" % [Campaign.party_state.prometheus.spell_slots[2], hermes_before])
	ok(FileAccess.file_exists(LabMetrics.summary_path()) and FileAccess.file_exists(LabMetrics.events_path()), "the run's summary and events are written",
		ProjectSettings.globalize_path(LabMetrics.summary_path()))
	var summary := FileAccess.get_file_as_string(LabMetrics.summary_path())
	ok(summary.contains("# Laboratory run: test-harness") and summary.contains("## Stage 1: Lab A") and summary.contains("Checkpoint, as it began")
		and summary.contains("Checkpoint, as it ended"), "stage 1 in it, with its checkpoints")
	ok(summary.contains("Hermes"), "and the gates left, by depth")
	ok(FileAccess.get_file_as_string(LabMetrics.events_path()).contains(",damage,"), "the hit is in the events")

	result._on_back_pressed()
	ok(await arrived_at("res://scenes/game.tscn"), "on to the second fight")
	game = get_tree().current_scene
	combat = game.get_node("VisualCombat")
	combat.reaction_prompt = null
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(2)
	ok(combat.encounter == lab.stages[1].encounter, "the Hired Blades at 17", combat.encounter.display_name)
	ok(fighter(combat, "cyrus").hp == 20, "Cyrus comes in as he left", "%d" % fighter(combat, "cyrus").hp)
	ok(fighter(combat, "prometheus").spell_slots[2] == hermes_left, "and Prometheus's gates as they were", "%d" % fighter(combat, "prometheus").spell_slots[2])
	combat.groups[Combat.Group.ENEMIES].clear()
	combat.combat_finish()
	await settle(4)
	result = game.get_node("ResultUI")
	result._on_back_pressed()
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
	var enfina := fighter(combat, "enfina")
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
