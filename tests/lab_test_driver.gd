extends Node
## Plays the Lab Fight out and checks, after every single turn, that everybody
## is still where the game thinks they are.
##
## A combatant is found for targeting by comparing the clicked tile against
## comb.position, while what the player sees is comb.sprite. If those two ever
## disagree - or if two bodies end up on one tile, so the first one found wins -
## somebody on screen becomes unclickable without being dead.

var LOG_PATH := HarnessLog.path_for("lab")
var _log: FileAccess
var _fail = 0

func log_line(t): _log.store_line(t); _log.flush()

func ok(condition: bool, label: String, detail: String = ""):
	if condition:
		log_line("  PASS  %s %s" % [label, detail])
	else:
		_fail += 1
		log_line("  FAIL  %s %s" % [label, detail])

func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(260.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


## Everything wrong with where people are standing, right now.
func survey(combat, controller) -> Array:
	var problems: Array = []
	var seen := {}
	for comb in combat.combatants:
		if not comb.alive:
			continue
		var where_drawn = Grid.tile_to_world(comb.position)
		if comb.sprite.position.distance_to(where_drawn) > 1.0:
			problems.append("%s is drawn at %s but the game says %s" % [
				comb.name, comb.sprite.position, comb.position])
		if seen.has(comb.position):
			problems.append("%s and %s are both on %s" % [
				seen[comb.position], comb.name, comb.position])
		seen[comb.position] = comb.name
		# The one the player's click would actually find.
		var found = controller.get_combatant_at_position(comb.position)
		if found == null or found.name != comb.name:
			problems.append("clicking %s finds %s" % [
				comb.position, "nobody" if found == null else found.name])
		if not controller.is_in_bounds(comb.position):
			problems.append("%s is standing off the grid at %s" % [comb.name, comb.position])
		if controller.is_tile_blocking(comb.position, comb.movement_class):
			problems.append("%s is standing inside a wall at %s" % [comb.name, comb.position])
	return problems


func run_test():
	var encounter: EncounterDefinition = load("res://encounters/encounter_02_sappers.tres")
	log_line("======== %s, on %s ========" % [
		encounter.display_name, encounter.terrain_scene.resource_path.get_file()])

	Campaign.reset()
	Campaign.current_encounter = encounter
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	for i in 6:
		await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	var controller = combat.controller
	if combat.deployment_active:
		combat.finish_deployment()
		await get_tree().process_frame

	var tile_map = game.get_node("Terrain/TileMap")
	log_line("map painted %s to %s" % [tile_map.get_used_rect().position,
		tile_map.get_used_rect().end - Vector2i.ONE])
	log_line("playable region %s" % [controller._astargrid.region])
	log_line("")

	log_line("======== nothing is drawn on the map but the fight ========")
	# A leftover Sprite2D sat in game.tscn drawing one grid square at (272, 208)
	# - near the top left, off the tile centres, in every battle ever played.
	var strays := []
	for child in game.get_children():
		if child is Sprite2D:
			strays.append("%s at %s" % [child.name, child.position])
	ok(strays.is_empty(), "no loose sprite decorating the battle scene", "%s" % [strays])
	for comb in combat.combatants:
		if comb.alive:
			var centre = Grid.tile_to_world(comb.position)
			if comb.sprite.position != centre:
				strays.append("%s off centre" % comb.name)
	ok(strays.is_empty(), "and everyone stands on a tile centre")
	log_line("")

	log_line("======== everybody starts where they are drawn ========")
	var opening = survey(combat, controller)
	ok(opening.is_empty(), "the fight opens sound", "%s" % [opening])
	for comb in combat.combatants:
		log_line("     %-12s %-14s %s" % [comb.name, comb.get("ai_function", "-"), comb.position])
	log_line("")

	log_line("======== and after every turn of it ========")
	var turns = 0
	var broke_on_turn = -1
	var first_problems: Array = []
	while turns < 80 and combat.groups[combat.Group.PLAYERS].size() > 0 \
			and combat.groups[combat.Group.ENEMIES].size() > 0:
		await combat.advance_turn()
		turns += 1
		var problems = survey(combat, controller)
		if not problems.is_empty() and broke_on_turn == -1:
			broke_on_turn = turns
			first_problems = problems
			log_line("  turn %d, after %s acted:" % [turns, combat.get_current_combatant().name])
			for problem in problems:
				log_line("      %s" % problem)
	ok(broke_on_turn == -1, "%d turns and everybody stayed put" % turns,
		"" if broke_on_turn == -1 else "broke on turn %d: %s" % [broke_on_turn, first_problems])
	log_line("")

	log_line("======== where the bombers ended up ========")
	for comb in combat.combatants:
		if comb.get("ai_function", "") == "ai_hit_and_explode":
			log_line("     %-12s alive=%s  position %s  sprite %s" % [
				comb.name, comb.alive, comb.position, comb.sprite.position])
	log_line("")

	game.queue_free()
	await get_tree().process_frame
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
