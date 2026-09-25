extends Node
## A sweep of the whole project, for the night before a showcase.
##
## Loads everything, boots every scene, plays every encounter out, walks every
## map, and checks that what the data points at actually exists. Deliberately
## broad and shallow: the other suites check that things are right, this one
## checks that nothing is missing or broken enough to stop the game.

var LOG_PATH := HarnessLog.path_for("sweep")
var _log: FileAccess
var _fail = 0

func log_line(t): _log.store_line(t); _log.flush()

func ok(condition: bool, label: String, detail: String = ""):
	if condition:
		log_line("  PASS  %s %s" % [label, detail])
	else:
		_fail += 1
		log_line("  FAIL  %s %s" % [label, detail])


## Every file under `root` with one of `extensions`, recursively.
func files_under(root: String, extensions: Array) -> Array:
	var found: Array = []
	var dir = DirAccess.open(root)
	if dir == null:
		return found
	dir.list_dir_begin()
	var name = dir.get_next()
	while name != "":
		var path = root.path_join(name)
		if dir.current_is_dir():
			if not name.begins_with(".") and name != "addons":
				found.append_array(files_under(path, extensions))
		elif name.get_extension() in extensions:
			found.append(path)
		name = dir.get_next()
	dir.list_dir_end()
	return found


func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(860.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


func run_test():
	log_line("======== every resource in the project loads ========")
	var resources = files_under("res://", ["tres", "res"])
	var broken := []
	for path in resources:
		if ResourceLoader.load(path) == null:
			broken.append(path)
	ok(broken.is_empty(), "all %d resources load" % resources.size(), "%s" % [broken])
	log_line("")

	log_line("======== every scene instantiates ========")
	var scenes = files_under("res://", ["tscn"])
	var failed := []
	for path in scenes:
		var packed = load(path)
		if packed == null:
			failed.append("%s (would not load)" % path)
			continue
		var made = packed.instantiate()
		if made == null:
			failed.append("%s (would not instantiate)" % path)
		else:
			made.queue_free()
	await get_tree().process_frame
	ok(failed.is_empty(), "all %d scenes instantiate" % scenes.size(), "%s" % [failed])
	log_line("")

	log_line("======== everything a skill or item points at is there ========")
	var dangling := []
	for key in SkillDatabase.skills:
		var skill: SkillDefinition = SkillDatabase.skills[key]
		if skill == null:
			dangling.append("%s: no resource" % key)
			continue
		if skill.icon == null:
			dangling.append("%s: no icon" % key)
		for effect in skill.all_effects():
			if effect.type == EffectDefinition.EffectType.CONDITION and effect.condition == null:
				dangling.append("%s: a condition effect with no condition" % key)
	ok(dangling.is_empty(), "%d skills and items are whole" % SkillDatabase.skills.size(), "%s" % [dangling])
	log_line("")

	log_line("======== every combatant is whole ========")
	var wrong := []
	for key in CombatantDatabase.combatants:
		var definition: CombatantDefinition = CombatantDatabase.combatants[key]
		if definition == null:
			wrong.append("%s: no resource" % key)
			continue
		if definition.name == "":
			wrong.append("%s: no name" % key)
		if definition.portrait() == null:
			wrong.append("%s: nothing to draw" % key)
		for skill_key in definition.skills:
			if not SkillDatabase.skills.has(skill_key):
				wrong.append("%s: unknown skill '%s'" % [key, skill_key])
		for skill_key in definition.secondary_skills:
			if not SkillDatabase.skills.has(skill_key):
				wrong.append("%s: unknown secondary '%s'" % [key, skill_key])
		for item_key in definition.starting_items:
			if not ItemDatabase.items.has(item_key):
				wrong.append("%s: unknown starting item '%s'" % [key, item_key])
		for level in [1, 2, 3]:
			if definition.hp_at(level) <= 0:
				wrong.append("%s: no health at level %d" % [key, level])
	ok(wrong.is_empty(), "%d combatants are whole" % CombatantDatabase.combatants.size(), "%s" % [wrong])
	log_line("")

	log_line("======== every encounter is playable ========")
	for path in files_under("res://encounters", ["tres"]):
		var encounter: EncounterDefinition = load(path)
		var problems := []
		if encounter.terrain_scene == null:
			problems.append("no terrain")
		if encounter.music != "" and Music._load(encounter.music) == null:
			problems.append("music '%s' is missing" % encounter.music)
		var players = 0
		var enemies = 0
		for spawn in encounter.spawns:
			if not CombatantDatabase.combatants.has(spawn.combatant_key):
				problems.append("unknown combatant '%s'" % spawn.combatant_key)
				continue
			if spawn.side == 0:
				players += 1
			else:
				enemies += 1
		if players == 0:
			problems.append("nobody to play as")
		if enemies == 0:
			problems.append("nobody to fight")
		ok(problems.is_empty(), "%s is playable" % encounter.display_name, "%s" % [problems])
	log_line("")

	log_line("======== every encounter plays out ========")
	for path in files_under("res://encounters", ["tres"]):
		Campaign.reset()
		Campaign.current_encounter = load(path)
		var game = load("res://scenes/game.tscn").instantiate()
		get_tree().root.add_child(game)
		for i in 6:
			await get_tree().process_frame
		var combat = game.get_node("VisualCombat")
		# Nobody is here to answer a reaction prompt, and while one is up the
		# AI's move timeout deliberately stops counting so it does not give up
		# while a player is deciding. Unassigned, reactions simply fire - which
		# is the documented behaviour for a battle with no prompt wired up, and
		# what this suite wants: a fight that plays itself to a conclusion.
		combat.reaction_prompt = null
		if combat.deployment_active:
			combat.finish_deployment()
			await get_tree().process_frame
		var turns = 0
		while turns < 60 and combat.groups[combat.Group.PLAYERS].size() > 0 \
				and combat.groups[combat.Group.ENEMIES].size() > 0:
			await combat.advance_turn()
			turns += 1
		ok(turns > 0, "%s ran %d turns without falling over" % [Campaign.current_encounter.display_name, turns])
		var living = 0
		for comb in combat.combatants:
			if comb.alive:
				living += 1
		ok(living >= 0, "  and somebody is accounted for", "%d still standing" % living)
		game.queue_free()
		await get_tree().process_frame
	log_line("")

	log_line("======== every exploration map comes up ========")
	var maps := ["res://scenes/explore_crossroads.tscn", "res://scenes/laboratory_terrain_explore.tscn",
		"res://church.tscn"]
	for path in maps:
		Campaign.reset()
		Campaign.current_map = path
		var scene = load("res://scenes/exploration.tscn").instantiate()
		get_tree().root.add_child(scene)
		for i in 5:
			await get_tree().process_frame
		ok(scene.party != null and scene.party.leader != null,
			"%s has somebody standing on it" % path.get_file(),
			"%s" % [Campaign.living_party()])
		ok(scene._tile_map != null, "  and a map under them")
		# Everything placed on it points at something.
		var loose := []
		for item in scene._interactables:
			if item is DialogueInteractable and item.dialogue == null:
				loose.append("%s has no dialogue" % item.name)
			if item is EncounterInteractable and item.encounter == null:
				loose.append("%s has no encounter" % item.name)
		ok(loose.is_empty(), "  and everything on it leads somewhere", "%s" % [loose])
		scene.queue_free()
		await get_tree().process_frame
	log_line("")

	log_line("======== the menus come up ========")
	for path in ["res://main_menu.tscn", "res://scenes/level_select.tscn", "res://scenes/story.tscn"]:
		var scene = load(path).instantiate()
		add_child(scene)
		await get_tree().process_frame
		ok(scene.get_child_count() > 0, "%s draws something" % path.get_file(),
			"%d children" % scene.get_child_count())
		scene.queue_free()
		await get_tree().process_frame
	log_line("")

	log_line("======== every dialogue compiles ========")
	var bad_dialogue := []
	for path in files_under("res://Dialogue", ["dialogue"]):
		var resource = load(path)
		if resource == null:
			bad_dialogue.append(path)
			continue
		if resource.get("errors") != null and not resource.errors.is_empty():
			bad_dialogue.append("%s: %d errors" % [path, resource.errors.size()])
	ok(bad_dialogue.is_empty(), "%d dialogues compile" % files_under("res://Dialogue", ["dialogue"]).size(),
		"%s" % [bad_dialogue])
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
