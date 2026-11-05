extends Node
## What aiming shows of a shove (Combat "Shoves, foreseen"; the designer, 2026-11-05,
## option A): where somebody would land, an arrow, a red burst where they would run into
## something, and what that would cost, in the prompt - whatever does the shoving: the
## skill, Push Extra, Tremor. The one walk does the shove and the preview, so each case
## here is foreseen and then done, and the two compared. Nothing is left changed.

const LOG_NAME := "shoveaim"
const WATCHER := "res://data/encounters/encounter_03_watcher.tres"
const PARTY := ["enfina", "cyrus", "alithia"]
const NOWHERE := Vector2i(-99999, -99999)
const WAYS := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]

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
	await open_fight({}, 14)
	await open_ground()
	await into_a_wall()
	await into_somebody()
	await a_pull()
	await who_stays()
	await nothing_changes()
	await push_extra()
	await an_area()
	await windswept()
	await open_fight({"enfina": "juggernaut"}, 64)
	await tremor()
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
	combat.reaction_prompt = null
	for comb in combat.combatants:
		comb.reaction_used = true
		if comb.has("max_hp") and comb.side == 1:
			comb.hp = 999
			comb.max_hp = 999


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


func foes() -> Array:
	return combat.combatants.filter(func(comb): return comb.side == 1 and comb.alive and not comb.has("object") and not comb.get("illusion", false))


func their_turn(comb: Dictionary):
	combat.current_combatant = combat.combatants.find(comb)
	comb.skill_used_this_turn = false
	comb.secondary_used_this_turn = false
	comb.status_effects = comb.status_effects.filter(func(entry): return entry.get("stat", "") != "accuracy")
	# Every blow lands: a miss is not what is measured.
	comb.status_effects.append({"stat": "accuracy", "amount": 100, "op": "add", "duration": 99, "source_name": "test"})
	controller.set_controlled_combatant(comb)
	await settle()


## Whether a tile is open for somebody to stand on, with nobody there?
func open_tile(tile: Vector2i, anyone: Dictionary) -> bool:
	return controller.is_in_bounds(tile) and not controller.is_tile_blocking(tile, 0) and combat.get_combatant_at(tile).is_empty() and combat.can_land_on(anyone, tile)


## A straight run of `length` free tiles, as [first tile, way]: for a shover at the
## first and whoever is shoved beside them. With `wall`, ending against something solid.
func a_run(length: int, wall: bool, anyone: Dictionary) -> Array:
	for x in range(-2, 40):
		for y in range(-2, 40):
			for way in WAYS:
				var first := Vector2i(x, y)
				var clear := true
				for i in length:
					if not open_tile(first + way * i, anyone) and first + way * i != anyone.position:
						clear = false
						break
				if not clear:
					continue
				var end: Vector2i = first + way * length
				if wall and (not controller.is_in_bounds(end) or controller.is_tile_blocking(end, 0)):
					return [first, way]
				if not wall and open_tile(end, anyone):
					return [first, way]
	return []


## Puts everybody but `keeping` out of the way, far along the map's own free tiles.
func put(comb: Dictionary, tile: Vector2i):
	comb.position = tile
	comb.sprite.position = combat.sprite_point(comb)
	controller.refresh_occupancy()


func prompt_says(skill: String, aim: Vector2i) -> String:
	ui.show_hit_preview(skill, aim)
	var found := []
	if ui._hit_preview != null and ui._hit_preview.visible:
		for label in ui._hit_preview.find_children("*", "Label", true, false):
			found.append(label.text)
	ui.hide_hit_preview()
	return " / ".join(found)


func open_ground():
	log_line("======== on open ground ========")
	var enfina := who("enfina")
	var foe: Dictionary = foes()[0]
	var run := a_run(6, false, foe)
	ok(not run.is_empty(), "a clear run", "%s" % [run])
	put(enfina, run[0])
	put(foe, run[0] + run[1])
	await their_turn(enfina)
	var skill: SkillDefinition = SkillDatabase.skills.shoving_strike
	var seen: Array = combat.foresee_shoves(enfina, skill, [foe])
	ok(seen.size() == 1 and seen[0].who == foe, "Shoving Strike: one shove, of who it is aimed at")
	ok(seen[0].from == foe.position and seen[0].to == foe.position + run[1] * 3 and seen[0].steps == 3, "three tiles straight back", "%s -> %s" % [seen[0].from, seen[0].to])
	ok(seen[0].at == Combat.NO_AREA and not seen[0].wall and seen[0].into.is_empty(), "nothing in the way, no burst")
	var says := prompt_says("shoving_strike", foe.position)
	ok(says.contains("Shoved 3 tiles"), "the prompt says so", says)
	ok(not says.contains("no damage"), "rather than \"no damage\", which is all it would have said", says)
	var predicted: Vector2i = seen[0].to
	await combat.use_skill("shoving_strike", enfina, foe.position, false)
	await settle()
	ok(foe.position == predicted, "and that is where it lands", "%s" % foe.position)
	# The board has it to draw.
	put(foe, run[0] + run[1])
	await their_turn(enfina)
	controller._selected_skill = "shoving_strike"
	controller._skill_selected = true
	controller._range_preview_positions = combat.get_range_tiles(skill, enfina.position, 0, enfina)
	controller._preview_shoves(enfina, skill, foe.position)
	ok(controller._shove_preview.size() == 1 and controller._shove_preview[0].to == predicted, "the board has the figure, the arrow and where to put them")
	controller.queue_redraw()
	await settle()
	controller._clear_aim_marks()
	controller._skill_selected = false
	ok(controller._shove_preview.is_empty(), "and lets go of them once the aim moves off")
	log_line("")


func into_a_wall():
	log_line("======== into a wall ========")
	var enfina := who("enfina")
	var foe: Dictionary = foes()[0]
	var run := a_run(3, true, foe)
	ok(not run.is_empty(), "a run ending in something solid", "%s" % [run])
	put(enfina, run[0])
	put(foe, run[0] + run[1])
	await their_turn(enfina)
	var skill: SkillDefinition = SkillDatabase.skills.shoving_strike
	var seen: Array = combat.foresee_shoves(enfina, skill, [foe])
	ok(seen[0].wall and seen[0].to == run[0] + run[1] * 2 and seen[0].steps == 1, "a tile, then the wall", "%s" % seen[0].to)
	ok(seen[0].at == run[0] + run[1] * 3, "the burst is at the wall")
	ok(seen[0].damage > 0, "and it costs them", "%d" % seen[0].damage)
	var says := prompt_says("shoving_strike", foe.position)
	ok(says.contains("Shoved 1 tile, into a wall: %d damage" % seen[0].damage), "said in the prompt", says)
	var hp: int = foe.hp
	var blow: int = combat.predict_hit(enfina, foe, skill).damage
	await combat.use_skill("shoving_strike", enfina, foe.position, false)
	await settle()
	ok(foe.position == seen[0].to and hp - foe.hp == blow + seen[0].damage, "the blow and the slam come to exactly that", "%d = %d + %d" % [hp - foe.hp, blow, seen[0].damage])
	# Already against it: it does not move at all, and still says so.
	put(foe, run[0] + run[1] * 2)
	put(enfina, run[0] + run[1])
	await their_turn(enfina)
	seen = combat.foresee_shoves(enfina, skill, [foe])
	ok(seen[0].steps == 0 and seen[0].wall and seen[0].to == seen[0].from, "with its back to it, it goes nowhere")
	ok(prompt_says("shoving_strike", foe.position).contains("Shoved into a wall"), "and is still slammed")
	log_line("")


func into_somebody():
	log_line("======== into somebody ========")
	var enfina := who("enfina")
	var the_foes := foes()
	var foe: Dictionary = the_foes[0]
	var other: Dictionary = the_foes[1]
	var run := a_run(5, false, foe)
	put(enfina, run[0])
	put(foe, run[0] + run[1])
	put(other, run[0] + run[1] * 3)
	await their_turn(enfina)
	var skill: SkillDefinition = SkillDatabase.skills.shoving_strike
	var seen: Array = combat.foresee_shoves(enfina, skill, [foe])
	ok(seen[0].into == other and seen[0].steps == 1, "a tile, and then the one standing there", "%d" % seen[0].steps)
	ok(seen[0].damage > 0 and seen[0].bump > 0, "both are hurt", "%d, %d" % [seen[0].damage, seen[0].bump])
	var says := prompt_says("shoving_strike", foe.position)
	ok(says.contains("into %s" % other.name) and says.contains("Run into: %d damage" % seen[0].bump), "and the prompt names who, and what it costs them", says)
	var hp: int = foe.hp
	var other_hp: int = other.hp
	var blow: int = combat.predict_hit(enfina, foe, skill).damage
	await combat.use_skill("shoving_strike", enfina, foe.position, false)
	await settle()
	ok(hp - foe.hp == blow + seen[0].damage and other_hp - other.hp == seen[0].bump, "and it comes to that, on both", "%d, %d" % [hp - foe.hp, other_hp - other.hp])
	# Somebody hidden behind them is not given away: the preview walks on through.
	put(foe, run[0] + run[1])
	put(other, run[0] + run[1] * 3)
	combat.set_hidden(other, true)
	await their_turn(enfina)
	seen = combat.foresee_shoves(enfina, skill, [foe])
	ok(seen[0].into.is_empty() and seen[0].steps == 3, "somebody hidden in the way is not given away", "%d" % seen[0].steps)
	ok(other.position == run[0] + run[1] * 3, "and is back where they stood")
	combat.set_hidden(other, false)
	log_line("")


func a_pull():
	log_line("======== a pull ========")
	var enfina := who("enfina")
	var foe: Dictionary = foes()[0]
	var run := a_run(6, false, foe)
	put(enfina, run[0])
	put(foe, run[0] + run[1] * 5)
	await their_turn(enfina)
	var skill: SkillDefinition = SkillDatabase.skills.wind_vacuum
	foe.stats[Stats.KEYS[skill.contest_stat]] = 0
	var seen: Array = combat.foresee_shoves(enfina, skill, [foe])
	ok(seen.size() == 1 and seen[0].pulled and seen[0].steps == 3 and seen[0].to == run[0] + run[1] * 2, "Wind Vacuum: three tiles nearer", "%s" % [seen[0].to if not seen.is_empty() else null])
	ok(prompt_says("wind_vacuum", foe.position).contains("Dragged 3 tiles"), "said as a drag")
	var effect: EffectDefinition = skill.effects[0]
	combat.apply_knockback(enfina, foe, effect, true, skill)
	ok(foe.position == seen[0].to, "and that is where it ends up", "%s" % foe.position)
	# Never past whoever pulls.
	put(foe, run[0] + run[1] * 2)
	seen = combat.foresee_shoves(enfina, skill, [foe])
	ok(seen[0].to == run[0] + run[1], "a pull stops beside them", "%s" % seen[0].to)
	log_line("")


func who_stays():
	log_line("======== who stays put ========")
	var enfina := who("enfina")
	var foe: Dictionary = foes()[0]
	var run := a_run(6, false, foe)
	put(enfina, run[0])
	put(foe, run[0] + run[1])
	await their_turn(enfina)
	var skill: SkillDefinition = SkillDatabase.skills.shoving_strike
	foe["immune_to"] = [Immunity.Kind.SHOVED]
	var seen: Array = combat.foresee_shoves(enfina, skill, [foe])
	ok(seen[0].stays == "immune to being shoved" and seen[0].to == seen[0].from, "immune", seen[0].stays)
	ok(prompt_says("shoving_strike", foe.position).contains("Stays put: immune to being shoved"), "and the prompt says so")
	foe["immune_to"] = []
	var other: Dictionary = foes()[1]
	var line_holder := PassiveDefinition.new()
	line_holder.holds_the_line = true
	line_holder.aura_radius = 99
	other.passives.append(line_holder)
	seen = combat.foresee_shoves(enfina, skill, [foe])
	ok(seen[0].stays == "holds the line", "somebody holding the line round them", seen[0].stays)
	other.passives.erase(line_holder)
	# A contest shrugged off drops the shove, as the blow does.
	var gust: SkillDefinition = SkillDatabase.skills.gust_blast
	ok(gust.uses_stat_contest, "(Gust Blast is contested)")
	foe.stats[Stats.KEYS[gust.contest_stat]] = 999
	ok(combat.foresee_shoves(enfina, gust, [foe]).is_empty(), "who wins the contest is not moved")
	foe.stats[Stats.KEYS[gust.contest_stat]] = 1
	# Felled by the blow, nobody is shoved.
	var blow: SkillDefinition = SkillDatabase.skills.sweep_strike
	foe.hp = 1
	ok(combat.foresee_shoves(enfina, blow, [foe]).is_empty(), "felled by the blow itself, nobody is shoved")
	foe.hp = 999
	log_line("")


func nothing_changes():
	log_line("======== nothing is changed by looking ========")
	var enfina := who("enfina")
	var the_foes := foes()
	var run := a_run(5, false, the_foes[0])
	put(enfina, run[0])
	put(the_foes[0], run[0] + run[1])
	put(the_foes[1], run[0] + run[1] * 2)
	await their_turn(enfina)
	var before: String = combat.board_fingerprint(enfina)
	var state = combat.rng.state
	var where := []
	for comb in combat.combatants:
		where.append(comb.get("position"))
	for i in 5:
		combat.foresee_shoves(enfina, SkillDatabase.skills.shoving_strike, [the_foes[0]])
	var after := []
	for comb in combat.combatants:
		after.append(comb.get("position"))
	ok(where == after and before == combat.board_fingerprint(enfina), "everybody where they stood")
	ok(combat.rng.state == state, "and not a roll spent")
	log_line("")


func push_extra():
	log_line("======== a passive's extra push ========")
	var enfina := who("enfina")
	var foe: Dictionary = foes()[0]
	var run := a_run(7, false, foe)
	put(enfina, run[0])
	put(foe, run[0] + run[1])
	await their_turn(enfina)
	var harder := PassiveDefinition.new()
	harder.push_extra = 2
	enfina.passives.append(harder)
	var seen: Array = combat.foresee_shoves(enfina, SkillDatabase.skills.shoving_strike, [foe])
	ok(seen[0].steps == 5, "Push Extra: two tiles further", "%d" % seen[0].steps)
	var predicted: Vector2i = seen[0].to
	await combat.use_skill("shoving_strike", enfina, foe.position, false)
	await settle()
	ok(foe.position == predicted, "and that is where it lands", "%s" % foe.position)
	enfina.passives.erase(harder)
	log_line("")


func an_area():
	log_line("======== an area ========")
	var prometheus: Dictionary = combat.create_combatant(CombatantDatabase.combatants.prometheus, "prometheus", "", null, 14)
	var enfina := who("enfina")
	var the_foes := foes()
	var run := a_run(7, false, the_foes[0])
	put(enfina, run[0])
	put(the_foes[0], run[0] + run[1] * 2)
	put(the_foes[1], run[0] + run[1] * 3)
	await their_turn(enfina)
	for foe in the_foes:
		foe.stats[Stats.KEYS[SkillDatabase.skills.gust_blast.contest_stat]] = 1
	# Whoever is nearer is shoved first, and into the other - unless that one moved.
	var seen: Array = combat.foresee_shoves(enfina, SkillDatabase.skills.gust_blast, [the_foes[1], the_foes[0]])
	ok(seen.size() == 2, "each caught has their own")
	ok(seen[0].to == run[0] + run[1] * 6, "the further one goes first, its way clear", "%s" % seen[0].to)
	ok(seen[1].to == run[0] + run[1] * 5 and seen[1].into.is_empty(), "and the nearer follows into the room it left", "%s" % seen[1].to)
	log_line("")


func windswept():
	log_line("======== Windswept: any way the wind blows ========")
	var enfina := who("enfina")
	var foe: Dictionary = foes()[0]
	var run := a_run(5, false, foe)
	put(enfina, run[0])
	put(foe, run[0] + run[1] * 2)
	await their_turn(enfina)
	var skill: SkillDefinition = SkillDatabase.skills.wind_swoon
	foe.stats[Stats.KEYS[skill.contest_stat]] = 1
	var seen: Array = combat.foresee_shoves(enfina, skill, [foe])
	ok(seen.size() == 1 and not seen[0].drift.is_empty(), "the tiles it could be blown to", "%s" % [seen[0].drift if not seen.is_empty() else null])
	ok(seen[0].to == seen[0].from and seen[0].steps == 0, "and no one of them is promised")
	ok(prompt_says("wind_swoon", foe.position).contains("any of the tiles marked"), "the prompt says as much")
	var windswept_on: ConditionDefinition = load("res://data/conditions/windswept.tres")
	combat.put_condition(foe, windswept_on, 2, "test")
	var from: Vector2i = foe.position
	combat.apply_drift(foe)
	ok(foe.position == from or seen[0].drift.has(foe.position), "and where it did blow them is one of them", "%s" % foe.position)
	log_line("")


func tremor():
	log_line("======== Tremor shoves what the blow does not ========")
	var enfina := who("enfina")
	var the_foes := foes()
	var struck: Dictionary = the_foes[0]
	var beside: Dictionary = the_foes[1]
	var run := a_run(5, false, struck)
	put(enfina, run[0])
	put(struck, run[0] + run[1])
	var across: Vector2i = Vector2i(run[1].y, run[1].x)
	var side: Vector2i = struck.position + across
	if not open_tile(side, beside) or not open_tile(side + across, beside):
		side = struck.position - across
	put(beside, side)
	await their_turn(enfina)
	var skill: SkillDefinition = SkillDatabase.skills.greatsword_attack
	var seen: Array = combat.foresee_shoves(enfina, skill, [struck])
	var of_struck: Array = seen.filter(func(entry): return entry.who == struck)
	var of_beside: Array = seen.filter(func(entry): return entry.who == beside)
	ok(of_struck.size() == 1 and of_beside.size() == 1, "whoever it strikes and whoever stands beside them", "%d" % seen.size())
	var says := prompt_says("greatsword_attack", struck.position)
	ok(says.contains(beside.name) and says.contains("Shoved 1 tile"), "the prompt names who else it moves", says)
	var to_struck: Vector2i = of_struck[0].to
	var to_beside: Vector2i = of_beside[0].to
	await combat.use_skill("greatsword_attack", enfina, struck.position, false)
	await settle(6)
	ok(struck.position == to_struck and beside.position == to_beside, "both end up where it said", "%s, %s / %s, %s" % [struck.position, to_struck, beside.position, to_beside])
	log_line("")
