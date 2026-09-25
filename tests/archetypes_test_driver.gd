extends Node
## What each kind of enemy actually does with its turn.
##
## The ai suite drives four turns of a real fight and reads the trace by eye,
## so it catches a crash or a hang and nothing else - an archetype could stop
## doing its job entirely and it would stay green. This one asserts the job.
##
## Every scenario is the same shape. A fight is built with only the people it
## needs, all standing on one stretch of plain open ground - nothing to hide
## behind, nothing slow to cross, so what the AI decides is down to who is
## standing where rather than to the map - and exactly one enemy turn is run:
## the turn order is set to player, that enemy, player, so the enemy's own
## advance_turn hands straight back to somebody who waits.

var LOG_PATH := HarnessLog.path_for("archetypes")

var _log: FileAccess = null
var _fail = 0
var _game: Node = null

## Encounters whose maps might hold a stretch of open ground big enough, tried
## in order. Both field every archetype.
const SOURCES := ["res://encounters/encounter_02_sappers.tres", "res://encounters/encounter_03_watcher.tres"]
## The open ground every scenario is laid out on, in tiles. The laboratory has
## one this size; the maps are rooms and corridors, and nothing larger fits.
const FIELD := Vector2i(12, 7)

var _source: EncounterDefinition = null
var _origin := Vector2i.ZERO


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
	get_tree().create_timer(270.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


## --- Setting a scene ---


## Builds a fight holding only `cast`, and stops before anybody takes a turn.
##
## Each entry is [combatant_key, side] or [combatant_key, side, offset]. The
## spawn is the source encounter's own, so everybody arrives at the level and
## with the gear that fight gives them - but a copy of it, standing at `offset`
## inside the open ground when one is given. Players take their tiles in the
## order they are listed, since the roster is seeded from exactly this list.
##
## Always at least two players, or the battle skips deployment and starts its
## first turn by itself, which may be an enemy's.
func start_fight(cast: Array) -> Combat:
	var encounter := EncounterDefinition.new()
	encounter.display_name = "Archetype scenario"
	encounter.terrain_scene = _source.terrain_scene
	var spawns: Array[SpawnDefinition] = []
	var used := []
	for wanted in cast:
		for spawn in _source.spawns:
			if spawn.combatant_key != wanted[0] or spawn.side != wanted[1] or used.has(spawn):
				continue
			used.append(spawn)
			var standing: SpawnDefinition = spawn.duplicate()
			if wanted.size() > 2:
				standing.position = _origin + wanted[2]
			# A fourth entry brings them in at another level - what a Follow-up
			# needs, which is not learned until level 3.
			if wanted.size() > 3:
				standing.level = wanted[3]
			spawns.append(standing)
			break
	encounter.spawns = spawns
	Campaign.reset()
	Campaign.current_encounter = encounter
	_game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(_game)
	for i in 4:
		await get_tree().process_frame
	var combat: Combat = _game.get_node("VisualCombat")
	# Deployment ended by hand rather than through finish_deployment, which would
	# also start the first turn - and whose turn it is, is the scenario's to say.
	if combat.deployment_active:
		combat.deployment_active = false
		combat.controller.end_deployment()
		combat.game_ui.set_deployment_mode(false)
	await get_tree().process_frame
	return combat


func end_fight():
	if _game != null:
		_game.queue_free()
		_game = null
	await get_tree().process_frame
	await get_tree().process_frame


## The top-left corner of a FIELD-sized block of plain open ground, or null
## when the map has none.
func find_field(combat: Combat):
	var ctl = combat.controller
	var used: Rect2i = ctl.tile_map.get_used_rect()
	for y in range(used.position.y, used.end.y - FIELD.y + 1):
		for x in range(used.position.x, used.end.x - FIELD.x + 1):
			if _is_open(combat, Vector2i(x, y)):
				return Vector2i(x, y)
	return null


func _is_open(combat: Combat, origin: Vector2i) -> bool:
	var ctl = combat.controller
	for dy in FIELD.y:
		for dx in FIELD.x:
			var tile = origin + Vector2i(dx, dy)
			if not ctl.is_in_bounds(tile) or ctl.is_tile_blocking(tile, 0) or ctl.terrain_blocks_sight(tile, 0):
				return false
			if ctl.get_tile_cost_for_class(tile, 0) != 1:
				return false
	return true


## Who in this fight came from `key` on `side`.
func who(combat: Combat, key: String, side: int) -> Dictionary:
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == key and comb.side == side:
			return comb
	return {}


## Everybody in this fight who came from `key` on `side`, in spawn order.
func all_of(combat: Combat, key: String, side: int) -> Array:
	var found = []
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == key and comb.side == side:
			found.append(comb)
	return found


## Says so when somebody is not where the scenario put them, since every
## assertion after that would be about a different fight.
func standing_as_laid_out(combat: Combat, cast: Array) -> bool:
	var wrong := []
	for wanted in cast:
		if wanted.size() < 3:
			continue
		var comb = who(combat, wanted[0], wanted[1])
		if comb.is_empty() or comb.position != _origin + wanted[2]:
			wrong.append("%s at %s" % [wanted[0], comb.get("position", "nowhere")])
	ok(wrong.is_empty(), "everybody stands where the scenario put them", "%s" % [wrong])
	return wrong.is_empty()


## Runs `enemy`'s turn and nobody else's.
func enemy_turn(combat: Combat, enemy: Dictionary):
	var player = {}
	for comb in combat.combatants:
		if comb.side == 0 and comb.alive:
			if player.is_empty():
				player = comb
			# A reaction of theirs would stop and ask the player, who is not
			# there. Walking past them is not what is being measured.
			comb.reaction_used = true
	var p = combat.combatants.find(player)
	var e = combat.combatants.find(enemy)
	combat.turn_queue = [p, e, p]
	combat.turn = 0
	combat.current_combatant = p
	await combat.advance_turn()


func distance(combat: Combat, a: Dictionary, b: Dictionary) -> int:
	return combat.get_position_distance(a.position, b.position)


## Whether something landed on `comb`: health lost, or a condition picked up.
func was_touched(comb: Dictionary, hp_before: int, effects_before: int) -> bool:
	return comb.hp < hp_before or comb.status_effects.size() > effects_before or not comb.alive


## --- The scenarios ---


func run_test():
	log_line("======== open ground to fight on ========")
	for path in SOURCES:
		_source = load(path)
		var probe = await start_fight([["cyrus", 0], ["enfina", 0]])
		var found = find_field(probe)
		await end_fight()
		if found != null:
			_origin = found
			break
		_source = null
	ok(_source != null, "a map has %dx%d tiles of plain open ground" % [FIELD.x, FIELD.y],
		"%s at %s" % [_source.display_name if _source else "none", _origin])
	if _source == null:
		log_line("FAILURES: %d" % _fail)
		get_tree().quit(1)
		return
	log_line("")

	await melee_rush()
	await ranger()
	await healer()
	await caster()
	await copycat()
	await bomber()
	await whole_kit()
	await own_side()
	await focus()
	await uncopyable()
	await hiding()

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func melee_rush():
	log_line("======== a melee enemy closes in and swings ========")
	var cast = [["cyrus", 0, Vector2i(4, 3)], ["enfina", 0, Vector2i(11, 6)], ["barbarian", 1, Vector2i(0, 3)]]
	var combat = await start_fight(cast)
	var cyrus = who(combat, "cyrus", 0)
	var striker = who(combat, "barbarian", 1)
	if standing_as_laid_out(combat, cast):
		ok(striker.get("ai_function", "") == "ai_melee_rush", "the Barbarian rushes", striker.get("ai_function", ""))
		var hp = cyrus.hp
		await enemy_turn(combat, striker)
		ok(distance(combat, striker, cyrus) == 1, "it ends beside the nearest player", "%s -> %s" % [striker.position, cyrus.position])
		ok(cyrus.hp < hp, "and hits them", "%d -> %d" % [hp, cyrus.hp])
	await end_fight()

	cast = [["cyrus", 0, Vector2i(11, 3)], ["enfina", 0, Vector2i(11, 6)], ["barbarian", 1, Vector2i(0, 3)]]
	combat = await start_fight(cast)
	cyrus = who(combat, "cyrus", 0)
	striker = who(combat, "barbarian", 1)
	if standing_as_laid_out(combat, cast):
		var hp = cyrus.hp
		var before = distance(combat, striker, cyrus)
		await enemy_turn(combat, striker)
		ok(distance(combat, striker, cyrus) < before, "out of reach, it still closes the distance",
			"%d -> %d" % [before, distance(combat, striker, cyrus)])
		ok(cyrus.hp == hp, "without hitting anybody")
	await end_fight()
	log_line("")


func ranger():
	log_line("======== a ranger shoots the weakest and keeps its distance ========")
	var cast = [["cyrus", 0, Vector2i(6, 1)], ["enfina", 0, Vector2i(5, 5)], ["ranger", 1, Vector2i(0, 3)]]
	var combat = await start_fight(cast)
	var cyrus = who(combat, "cyrus", 0)
	var enfina = who(combat, "enfina", 0)
	var archer = who(combat, "ranger", 1)
	if standing_as_laid_out(combat, cast):
		# Cyrus the weaker by a distance, and not the nearer, so the choice shows.
		cyrus.hp = 40
		var cyrus_hp = cyrus.hp
		var enfina_hp = enfina.hp
		var before = combat.distance_to_nearest_player(archer.position)
		await enemy_turn(combat, archer)
		ok(cyrus.hp < cyrus_hp, "it shoots whoever has the least health left", "Cyrus %d -> %d" % [cyrus_hp, cyrus.hp])
		ok(enfina.hp == enfina_hp, "and not the nearer, healthier one", "Enfina %d" % enfina.hp)
		var after = combat.distance_to_nearest_player(archer.position)
		ok(after >= before, "without walking into reach to take the shot", "%d -> %d tiles" % [before, after])
	await end_fight()

	combat = await start_fight(cast)
	cyrus = who(combat, "cyrus", 0)
	enfina = who(combat, "enfina", 0)
	archer = who(combat, "ranger", 1)
	if standing_as_laid_out(combat, cast):
		var full = combat.get_effective_stat(archer, "max_hp")
		archer.hp = full * 2 / 5
		var archer_hp = archer.hp
		var cyrus_hp = cyrus.hp
		var enfina_hp = enfina.hp
		await enemy_turn(combat, archer)
		ok(archer.hp > archer_hp, "badly hurt, it heals itself instead", "%d -> %d of %d" % [archer_hp, archer.hp, full])
		ok(cyrus.hp == cyrus_hp and enfina.hp == enfina_hp, "and shoots nobody that turn")
	await end_fight()
	log_line("")


func healer():
	log_line("======== a healer mends whoever is worst off ========")
	var cast = [["cyrus", 0, Vector2i(11, 1)], ["enfina", 0, Vector2i(11, 6)],
		["priest", 1, Vector2i(1, 3)], ["barbarian", 1, Vector2i(3, 2)], ["bomber", 1, Vector2i(3, 5)]]
	var combat = await start_fight(cast)
	var priest = who(combat, "priest", 1)
	var striker = who(combat, "barbarian", 1)
	var bomber = who(combat, "bomber", 1)
	if standing_as_laid_out(combat, cast):
		ok(priest.get("ai_function", "") == "ai_healer", "the Priest heals", priest.get("ai_function", ""))
		striker.hp = combat.get_effective_stat(striker, "max_hp") - 100
		bomber.hp = combat.get_effective_stat(bomber, "max_hp") - 5
		var striker_hp = striker.hp
		var bomber_hp = bomber.hp
		await enemy_turn(combat, priest)
		ok(striker.hp > striker_hp, "the ally missing the most is healed", "%d -> %d" % [striker_hp, striker.hp])
		ok(bomber.hp == bomber_hp, "rather than the one barely scratched", "%d" % bomber.hp)
		var heal: SkillDefinition = SkillDatabase.skills["heal"]
		var reach = combat.movement_budget_of(priest) + heal.max_range
		ok(distance(combat, priest, striker) <= reach, "and it stays where it can reach them next turn",
			"%d of %d tiles" % [distance(combat, priest, striker), reach])
	await end_fight()
	log_line("")


func caster():
	log_line("======== a caster puts its blast where it catches the most ========")
	var cast = [["cyrus", 0, Vector2i(7, 2)], ["enfina", 0, Vector2i(7, 4)], ["prometheus", 0, Vector2i(11, 6)],
		["sorcerer", 1, Vector2i(0, 3)]]
	var combat = await start_fight(cast)
	var cyrus = who(combat, "cyrus", 0)
	var enfina = who(combat, "enfina", 0)
	var prometheus = who(combat, "prometheus", 0)
	var sorcerer = who(combat, "sorcerer", 1)
	if standing_as_laid_out(combat, cast):
		ok(sorcerer.get("ai_function", "") == "ai_caster", "the Sorcerer casts", sorcerer.get("ai_function", ""))
		# Contests are not what this measures. Flattened, every player loses one
		# to the Sorcerer, so a spell that lands does its whole job on them.
		for comb in [cyrus, enfina, prometheus]:
			for key in Stats.KEYS:
				comb.stats[key] = 1
		var marks = {}
		for comb in [cyrus, enfina]:
			marks[comb.name] = [comb.hp, comb.status_effects.size()]
		var gates_before = str(sorcerer.spell_slots)
		await enemy_turn(combat, sorcerer)
		ok(str(sorcerer.spell_slots) != gates_before, "it casts an area spell rather than walking up to swing",
			"%s -> %s" % [gates_before, sorcerer.spell_slots])
		var caught = []
		for comb in [cyrus, enfina]:
			if was_touched(comb, marks[comb.name][0], marks[comb.name][1]):
				caught.append(comb.name)
		ok(caught.size() == 2, "the two players standing together are both caught", "%s" % [caught])
		ok(combat.distance_to_nearest_player(sorcerer.position) > 1, "and it does not end the turn beside anybody",
			"%d tiles" % combat.distance_to_nearest_player(sorcerer.position))
	await end_fight()
	log_line("")


func copycat():
	log_line("======== a copycat does what the party did last ========")
	var cast = [["cyrus", 0, Vector2i(4, 3)], ["enfina", 0, Vector2i(11, 6)], ["mimic", 1, Vector2i(0, 3)]]
	var combat = await start_fight(cast)
	var cyrus = who(combat, "cyrus", 0)
	var mimic = who(combat, "mimic", 1)
	if standing_as_laid_out(combat, cast):
		# A spell through a gate, and the Mimic has none: only its passive pays.
		combat.last_player_skill_used = "fire_blast"
		ok(SkillDatabase.skills["fire_blast"].spell_slot_level > 0, "Fire Blast is cast through a gate")
		ok(str(mimic.spell_slots) == str([0, 0, 0, 0]), "and the Mimic holds none", "%s" % [mimic.spell_slots])
		var hp = cyrus.hp
		await enemy_turn(combat, mimic)
		ok(cyrus.hp < hp, "it casts the copied spell on the nearest player all the same", "%d -> %d" % [hp, cyrus.hp])
	await end_fight()

	combat = await start_fight(cast)
	cyrus = who(combat, "cyrus", 0)
	mimic = who(combat, "mimic", 1)
	if standing_as_laid_out(combat, cast):
		combat.last_player_skill_used = ""
		var hp = cyrus.hp
		var stood = mimic.position
		await enemy_turn(combat, mimic)
		ok(mimic.position == stood and cyrus.hp == hp, "with nothing done yet, it has nothing to copy and waits",
			"%s -> %s" % [stood, mimic.position])
	await end_fight()
	log_line("")


func bomber():
	log_line("======== a bomber runs in and goes off ========")
	var cast = [["cyrus", 0, Vector2i(5, 3)], ["enfina", 0, Vector2i(11, 6)], ["bomber", 1, Vector2i(0, 3)]]
	var combat = await start_fight(cast)
	var cyrus = who(combat, "cyrus", 0)
	var enfina = who(combat, "enfina", 0)
	var bomb = who(combat, "bomber", 1)
	if standing_as_laid_out(combat, cast):
		var cyrus_hp = cyrus.hp
		var enfina_hp = enfina.hp
		await enemy_turn(combat, bomb)
		ok(not bomb.alive, "within reach of a blast, it sets itself off")
		ok(cyrus.hp < cyrus_hp, "catching the player it ran at", "%d -> %d" % [cyrus_hp, cyrus.hp])
		ok(enfina.hp == enfina_hp, "and nobody standing clear of it", "%d" % enfina.hp)
	await end_fight()

	cast = [["cyrus", 0, Vector2i(11, 3)], ["enfina", 0, Vector2i(11, 6)], ["bomber", 1, Vector2i(0, 3)]]
	combat = await start_fight(cast)
	cyrus = who(combat, "cyrus", 0)
	bomb = who(combat, "bomber", 1)
	if standing_as_laid_out(combat, cast):
		var cyrus_hp = cyrus.hp
		var before = distance(combat, bomb, cyrus)
		await enemy_turn(combat, bomb)
		ok(bomb.alive, "too far to catch anybody, it does not waste itself")
		ok(distance(combat, bomb, cyrus) < before, "and runs at them instead",
			"%d -> %d tiles" % [before, distance(combat, bomb, cyrus)])
		ok(cyrus.hp == cyrus_hp, "hurting nobody yet")
	await end_fight()
	log_line("")


func whole_kit():
	log_line("======== the whole kit, not just one swing ========")
	# Two players in a line from the Barbarian: a Sweep Strike runs through both,
	# where the Greatsword would take only the first.
	var cast = [["cyrus", 0, Vector2i(1, 3)], ["enfina", 0, Vector2i(2, 3)], ["barbarian", 1, Vector2i(0, 3)]]
	var combat = await start_fight(cast)
	var cyrus = who(combat, "cyrus", 0)
	var enfina = who(combat, "enfina", 0)
	var striker = who(combat, "barbarian", 1)
	if standing_as_laid_out(combat, cast):
		ok(combat.meets_level_for(striker, SkillDatabase.skills["sweep_strike"]), "the Barbarian knows Sweep Strike here")
		var hp = [cyrus.hp, enfina.hp]
		await enemy_turn(combat, striker)
		ok(cyrus.hp < hp[0] and enfina.hp < hp[1], "two in a line both take the sweep",
			"Cyrus %d -> %d, Enfina %d -> %d" % [hp[0], cyrus.hp, hp[1], enfina.hp])
	await end_fight()

	# Nothing in reach: Run, and cover twice the ground.
	cast = [["cyrus", 0, Vector2i(11, 3)], ["enfina", 0, Vector2i(11, 6)], ["barbarian", 1, Vector2i(0, 3)]]
	combat = await start_fight(cast)
	cyrus = who(combat, "cyrus", 0)
	striker = who(combat, "barbarian", 1)
	if standing_as_laid_out(combat, cast):
		var walk = combat.movement_budget_of(striker)
		var before = distance(combat, striker, cyrus)
		await enemy_turn(combat, striker)
		ok(before - distance(combat, striker, cyrus) > walk, "with nothing in reach it runs, covering more than it could walk",
			"%d closer, walking alone would be %d" % [before - distance(combat, striker, cyrus), walk])
	await end_fight()

	# At level 3 it has learned Follow-up, a secondary: a swing and then another.
	cast = [["cyrus", 0, Vector2i(4, 3)], ["enfina", 0, Vector2i(11, 6)], ["barbarian", 1, Vector2i(0, 3), 3]]
	combat = await start_fight(cast)
	cyrus = who(combat, "cyrus", 0)
	striker = who(combat, "barbarian", 1)
	if standing_as_laid_out(combat, cast):
		ok(striker.level == 3 and combat.meets_level_for(striker, SkillDatabase.skills["follow_up_attack"]),
			"a level 3 Barbarian knows Follow-up", "level %d" % striker.level)
		cyrus.hp = 999
		var one_swing = combat.predict_hit(striker, cyrus, SkillDatabase.skills["greatsword_attack"]).damage
		await enemy_turn(combat, striker)
		ok(striker.get("secondary_used_this_turn", false), "and spends its secondary action on it")
		ok(999 - cyrus.hp > one_swing, "landing more than one swing's worth", "%d, one swing %d" % [999 - cyrus.hp, one_swing])
	await end_fight()
	log_line("")


func own_side():
	log_line("======== a caster keeps its own side out of it ========")
	# An ally stood between two players. Fireball would catch all three; the
	# smaller blasts reach both players and cannot touch an ally at all.
	var cast = [["cyrus", 0, Vector2i(8, 1)], ["enfina", 0, Vector2i(8, 5)], ["prometheus", 0, Vector2i(11, 0)],
		["sorcerer", 1, Vector2i(0, 3)], ["barbarian", 1, Vector2i(8, 3)]]
	var combat = await start_fight(cast)
	var sorcerer = who(combat, "sorcerer", 1)
	var ally = who(combat, "barbarian", 1)
	if standing_as_laid_out(combat, cast):
		# Flattened, so every contest is won; and too hardy to be finished, so a
		# kill cannot tip it one way or the other.
		for comb in [who(combat, "cyrus", 0), who(combat, "enfina", 0), who(combat, "prometheus", 0)]:
			for key in Stats.KEYS:
				comb.stats[key] = 1
			comb.hp = 999
		ok(SkillDatabase.skills["fireball"].affects_both_sides, "Fireball burns both sides")
		ok(combat.can_afford_skill(sorcerer, SkillDatabase.skills["fireball"]), "and the Sorcerer can cast it")
		var ally_hp = ally.hp
		var marks = {}
		for comb in combat.combatants:
			if comb.side == 0:
				marks[comb.name] = [comb.hp, comb.status_effects.size()]
		await enemy_turn(combat, sorcerer)
		var caught = []
		for comb in combat.combatants:
			if comb.side == 0 and was_touched(comb, marks[comb.name][0], marks[comb.name][1]):
				caught.append(comb.name)
		ok(not caught.is_empty(), "it still hits the players", "%s" % [caught])
		ok(ally.hp == ally_hp, "without burning the ally standing among them", "%d -> %d" % [ally_hp, ally.hp])
	await end_fight()

	# Standing close enough to be inside its own Fireball: it steps out of the
	# blast before throwing it, rather than throwing it anyway.
	cast = [["cyrus", 0, Vector2i(6, 2)], ["enfina", 0, Vector2i(6, 4)], ["sorcerer", 1, Vector2i(4, 3)]]
	combat = await start_fight(cast)
	sorcerer = who(combat, "sorcerer", 1)
	if standing_as_laid_out(combat, cast):
		for comb in [who(combat, "cyrus", 0), who(combat, "enfina", 0)]:
			for key in Stats.KEYS:
				comb.stats[key] = 1
		var own_hp = sorcerer.hp
		await enemy_turn(combat, sorcerer)
		ok(sorcerer.alive and sorcerer.hp == own_hp, "it never catches itself in its own blast", "%d -> %d" % [own_hp, sorcerer.hp])
	await end_fight()
	log_line("")


func focus():
	log_line("======== enemies finish what the last one started ========")
	# Two Barbarians, and two players each could reach. The second goes for
	# whoever the first went for rather than spreading the damage.
	var cast = [["cyrus", 0, Vector2i(6, 3)], ["enfina", 0, Vector2i(2, 3)],
		["barbarian", 1, Vector2i(4, 1)], ["barbarian", 1, Vector2i(4, 5)]]
	var combat = await start_fight(cast)
	var cyrus = who(combat, "cyrus", 0)
	var enfina = who(combat, "enfina", 0)
	var strikers = all_of(combat, "barbarian", 1)
	ok(strikers.size() == 2, "two Barbarians", "%d" % strikers.size())
	if strikers.size() == 2:
		for comb in [cyrus, enfina]:
			comb.hp = 999
		await enemy_turn(combat, strikers[0])
		var first = cyrus if cyrus.hp < 999 else (enfina if enfina.hp < 999 else {})
		ok(not first.is_empty(), "the first goes for one of them", first.get("name", "nobody"))
		if not first.is_empty():
			var other = enfina if first == cyrus else cyrus
			var hit_once = first.hp
			await enemy_turn(combat, strikers[1])
			ok(first.hp < hit_once and other.hp == 999, "and the second goes for the same one",
				"%s %d -> %d, %s untouched at %d" % [first.name, hit_once, first.hp, other.name, other.hp])
	await end_fight()
	log_line("")


func uncopyable():
	log_line("======== what the Mimic cannot copy ========")
	var cast = [["prometheus", 0, Vector2i(4, 3)], ["enfina", 0, Vector2i(11, 6)], ["mimic", 1, Vector2i(0, 3)]]
	var combat = await start_fight(cast)
	var caster = who(combat, "prometheus", 0)
	var mimic = who(combat, "mimic", 1)
	if standing_as_laid_out(combat, cast):
		for key in ["run", "slip_past", "study"]:
			ok(not SkillDatabase.skills[key].can_be_copied, "%s cannot be copied" % SkillDatabase.skills[key].name)
		caster.spell_slots = [0, 9, 9, 9]
		await combat.use_skill("study", caster, mimic.position, false, true)
		ok(combat.last_player_skill_used == "", "with only Study used so far, there is nothing to copy",
			"'%s'" % combat.last_player_skill_used)
		caster.skill_used_this_turn = false
		await combat.use_skill("fire_blast", caster, mimic.position, false)
		caster.skill_used_this_turn = false
		await combat.use_skill("run", caster, caster.position, false)
		ok(combat.last_player_skill_used == "fire_blast", "Run after Fire Blast leaves Fire Blast to be copied",
			"'%s'" % combat.last_player_skill_used)
	await end_fight()
	log_line("")


func hiding():
	log_line("======== nobody hidden is seen ========")
	# A Bomber with a hidden player inside its blast, and the only visible one
	# far off. Counting the hidden one, it went off on the spot.
	var cast = [["cyrus", 0, Vector2i(3, 3)], ["enfina", 0, Vector2i(11, 6)], ["bomber", 1, Vector2i(0, 3)]]
	var combat = await start_fight(cast)
	var cyrus = who(combat, "cyrus", 0)
	var bomb = who(combat, "bomber", 1)
	if standing_as_laid_out(combat, cast):
		combat.set_hidden(cyrus, true)
		var hp = cyrus.hp
		await enemy_turn(combat, bomb)
		ok(bomb.alive, "a Bomber does not go off beside somebody it cannot see")
		ok(cyrus.hp == hp, "and the hidden player is untouched", "%d -> %d" % [hp, cyrus.hp])
	await end_fight()

	# A Ranger with a badly hurt hidden player in range: the obvious mark, and
	# one it has no way of knowing about.
	cast = [["cyrus", 0, Vector2i(5, 2)], ["enfina", 0, Vector2i(6, 5)], ["ranger", 1, Vector2i(0, 3)]]
	combat = await start_fight(cast)
	cyrus = who(combat, "cyrus", 0)
	var enfina = who(combat, "enfina", 0)
	var archer = who(combat, "ranger", 1)
	if standing_as_laid_out(combat, cast):
		cyrus.hp = 20
		combat.set_hidden(cyrus, true)
		var enfina_hp = enfina.hp
		await enemy_turn(combat, archer)
		ok(cyrus.hp == 20, "a Ranger does not shoot the hidden one, however hurt", "%d" % cyrus.hp)
		ok(enfina.hp < enfina_hp, "it shoots the one it can see", "%d -> %d" % [enfina_hp, enfina.hp])
	await end_fight()

	# And everything the archetypes weigh a board with, asked directly.
	# The Ranger stands right beside the hidden player, the Barbarian a little
	# way from the visible one: the ally a healer should keep up with is the
	# Barbarian, since nobody is about to hit the Ranger that it knows of.
	cast = [["cyrus", 0, Vector2i(1, 3)], ["enfina", 0, Vector2i(11, 6)],
		["ranger", 1, Vector2i(0, 3)], ["priest", 1, Vector2i(0, 5)], ["barbarian", 1, Vector2i(8, 6)]]
	combat = await start_fight(cast)
	cyrus = who(combat, "cyrus", 0)
	enfina = who(combat, "enfina", 0)
	archer = who(combat, "ranger", 1)
	var priest = who(combat, "priest", 1)
	var front = who(combat, "barbarian", 1)
	if standing_as_laid_out(combat, cast):
		cyrus.hp = 1
		combat.set_hidden(cyrus, true)
		ok(combat.find_lowest_hp_enemy_of(archer) == enfina, "the weakest enemy it knows of is not the hidden one",
			combat.find_lowest_hp_enemy_of(archer).get("name", "nobody"))
		ok(combat.distance_to_nearest_player(archer.position) == distance(combat, archer, enfina),
			"nor is the nearest, when it works out where is safe", "%d" % combat.distance_to_nearest_player(archer.position))
		ok(combat.count_players_in_blast(SkillDatabase.skills["self_destruct"], archer.position, archer.movement_class) == 0,
			"a blast reaching only the hidden one reaches nobody")
		ok(combat.ally_nearest_the_enemy(priest) == front,
			"a healer keeps up with whoever is nearest an enemy it can see, not a hidden one",
			combat.ally_nearest_the_enemy(priest).get("name", "nobody"))
		var plan = combat.ai_plan_attack(archer, combat._ai_main_keys(archer), combat.movement_budget_of(archer))
		ok(plan.skill == "" or plan.aim != cyrus.position, "and no plan is aimed at them",
			"%s at %s" % [plan.skill, plan.aim])
	await end_fight()
	log_line("")
