extends Node
## The designer's control trial of 2026-10-24 (APPROVED_TRIAL; Dazed a PROPOSAL
## test value), at level 64 with Enfina a Juggernaut: Titanfall the damage and
## Tremor the control. Titanfall shoves nobody; where its splash and Tremor's
## meet, the harder only; Tremor shoves everybody beside whoever she hits and
## the one struck, and into something solid they are Dazed rather than
## Stunned; Dazed never stacks and never lasts past the target's next turn; she
## can step after whoever she threw, for a tile of movement; Stunning Blow has
## 1 / 2 / 3 uses a short rest.

var LOG_PATH := HarnessLog.path_for("tremor")
const WATCHER := "res://data/encounters/encounter_03_watcher.tres"
const DAZED := "res://data/conditions/dazed.tres"

var _log: FileAccess = null
var _fail = 0
var game: Node = null
var combat = null
## Damage landed, by the id of whoever took it (Combat's "damage" metric).
var damage_to := {}


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
	await open_fight({"enfina": "juggernaut"})
	dazed()
	await together()
	await the_step()
	await stunning_blow()
	await close_fight()
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


## The watcher fight in the story, the party at `level` on the paths given.
func open_fight(paths: Dictionary, level: int = 64):
	await close_fight()
	Campaign.reset()
	Campaign.set_party(["cyrus", "enfina", "prometheus", "alithia"], level)
	for key in paths:
		Campaign.choose_subclass(key, paths[key])
	Campaign.current_map = "res://maps/crossroads_explore.tscn"
	Campaign.return_to_position = true
	Campaign.current_encounter = load(WATCHER)
	game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(6)
	combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(2)
	# Nobody at the keyboard: a reaction is taken without asking.
	combat.reaction_prompt = null
	combat.metric.connect(_on_metric)
	for comb in combat.combatants:
		sturdy(comb)


func close_fight():
	if game != null and is_instance_valid(game):
		game.queue_free()
		await settle(3)
	game = null
	combat = null


func _on_metric(event: String, data: Dictionary):
	if event == "damage":
		var id: int = data.get("target", {}).get("id", -1)
		damage_to[id] = damage_to.get(id, 0) + 1


func who(key: String) -> Dictionary:
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == key and not comb.get("illusion", false):
			return comb
	return {}


## Those of the other side that can be shoved and dazed, the ones measured here.
func enemies() -> Array:
	var daze: ConditionDefinition = load(DAZED)
	return combat.combatants.filter(func(c): return (c.side == 1 and c.alive and not c.has("object")
		and not combat.immune_to(c, Immunity.Kind.SHOVED) and not combat.immune_to_condition(c, daze)))


func sturdy(comb: Dictionary, hp: int = 9999):
	comb.max_hp = hp
	comb.hp = hp


## Moves `comb` to `tile`.
func put(comb: Dictionary, tile: Vector2i):
	var from: Vector2i = comb.position
	comb.position = tile
	if comb.get("sprite") != null:
		comb.sprite.position = combat.controller.tile_map.map_to_local(tile)
	combat.controller.reposition_combatant(from, tile)


func open(tile: Vector2i) -> bool:
	return combat.controller.is_in_bounds(tile) and combat.controller.is_on_map(tile) \
		and combat.get_combatant_at(tile).is_empty() and not combat.controller.is_tile_blocking(tile, 0)


## The nearest tile to `near` with open ground for two tiles all round it -
## room for every shove measured here - or (-1, -1), said in the log.
func clearing(near: Vector2i) -> Vector2i:
	var found := _clearing(near)
	if found == Vector2i(-1, -1):
		ok(false, "an open patch of five by five tiles to measure on")
	return found


func _clearing(near: Vector2i) -> Vector2i:
	var region: Rect2i = combat.controller._astargrid.region
	var best := Vector2i(-1, -1)
	var best_gap := 999999
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var there := Vector2i(x, y)
			var gap: int = combat.get_position_distance(near, there)
			if gap >= best_gap:
				continue
			var clear := true
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					if not open(there + Vector2i(dx, dy)):
						clear = false
			if clear:
				best = there
				best_gap = gap
	return best


## Gives `comb` the turn, nothing in the way of acting.
func give_turn(comb: Dictionary):
	combat.current_combatant = combat.combatants.find(comb)
	combat.controller.set_controlled_combatant(comb)
	combat.controller.player_turn = comb.side == 0
	combat.controller.action_locked = false
	comb.skill_used_this_turn = false
	comb.secondary_used_this_turn = false
	comb.reaction_used = false


## Runs a skill without waiting on it, so a question it asks can be answered.
func start_skill(key: String, caster: Dictionary, aim: Vector2i) -> Array:
	var done := [false]
	var run := func():
		await combat.use_skill(key, caster, aim, false)
		done[0] = true
	run.call()
	return done


func wait_for(check: Callable, seconds: float = 10.0) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		if check.call():
			return true
		await get_tree().process_frame
	return check.call()


## Her blow, landing for sure, in her own turn with `movement` left to walk.
func swing(enfina: Dictionary, target: Dictionary, key: String, movement: int) -> Array:
	enfina.status_effects.append({"stat": "accuracy", "amount": 200, "duration": 99, "source_name": "test"})
	give_turn(enfina)
	combat.controller.movement = movement
	return start_skill(key, enfina, target.position)


## Declines a step if one is offered, and waits for the skill to finish.
func finish(done: Array):
	await wait_for(func(): return done[0] or combat.controller.is_stepping())
	if combat.controller.is_stepping():
		combat.controller.stay_put()
	await wait_for(func(): return done[0])
	await settle(2)


func dazed_entries(comb: Dictionary) -> Array:
	return comb.status_effects.filter(func(entry): return (entry.get("stat", "") == "condition" and entry.get("condition") != null
		and entry.condition.resource_path == DAZED))


func dazed():
	log_line("======== Dazed ========")
	var daze: ConditionDefinition = load(DAZED)
	ok(daze.duration == 1 and daze.movement_change == -2 and daze.prevents_secondary and daze.prevents_reactions
		and not daze.skips_turn and not daze.wears_off_at_start,
		"Dazed: a turn of two tiles less, no secondary action and no reactions - the main action kept (a PROPOSAL test value)")
	var enfina := who("enfina")
	var tremor: Array = combat.active_passives(enfina).filter(func(passive): return passive.tremor_share > 0.0)
	ok(tremor.size() == 1 and tremor[0].tremor_impact_condition == daze and tremor[0].tremor_follow,
		"Tremor: into something solid, dazed - and she can step after them")
	var foe: Dictionary = enemies()[0]
	foe.status_effects.clear()
	var walk: int = combat.get_effective_stat(foe, "movement")
	give_turn(enfina)
	combat._tremor_impact(enfina, foe)
	ok(dazed_entries(foe).size() == 1 and dazed_entries(foe)[0].duration == 1, "slammed in her turn: dazed for their next turn",
		"%s" % [dazed_entries(foe).map(func(entry): return entry.duration)])
	ok(combat.get_effective_stat(foe, "movement") == maxi(walk - 2, 0), "  two tiles less to walk",
		"%d -> %d" % [walk, combat.get_effective_stat(foe, "movement")])
	ok(combat.has_restriction(foe, "prevents_secondary") and combat.has_restriction(foe, "prevents_reactions")
		and not combat.has_restriction(foe, "skips_turn"), "  no secondary action, no reactions - their turn still theirs")
	for i in 3:
		combat._tremor_impact(enfina, foe)
	ok(dazed_entries(foe).size() == 1 and dazed_entries(foe)[0].duration == 1,
		"slammed again and again before their turn: one Dazed, and still the one turn - never stacked, never longer",
		"%s" % [dazed_entries(foe).map(func(entry): return entry.duration)])
	combat.end_of_turn_effects(foe)
	ok(dazed_entries(foe).is_empty(), "  gone as their next turn ends")
	# Landing in their own turn (a reaction of hers): the rest of it and the
	# next, as every "N turns" does (the duration rule) - and no more for a
	# second impact.
	give_turn(foe)
	combat._tremor_impact(enfina, foe)
	combat._tremor_impact(enfina, foe)
	ok(dazed_entries(foe).size() == 1 and dazed_entries(foe)[0].duration == 2,
		"slammed in their own turn, twice: the rest of it and their next, no more",
		"%s" % [dazed_entries(foe).map(func(entry): return entry.duration)])
	combat.end_of_turn_effects(foe)
	ok(dazed_entries(foe).size() == 1, "  on through their next turn")
	combat.end_of_turn_effects(foe)
	ok(dazed_entries(foe).is_empty(), "  and gone as it ends")
	foe.status_effects.clear()
	log_line("")


func together():
	log_line("======== Titanfall and Tremor together ========")
	var enfina := who("enfina")
	var sword: SkillDefinition = SkillDatabase.skills["greatsword_attack"]
	ok(is_equal_approx(Combat.modifier_of(enfina, sword), 3.0), "her Greatsword Attack is Titanfall at 64: x3.0")
	var foes := enemies()
	if foes.size() < 3:
		log_line("  NOTE  fewer than three to place: %d" % foes.size())
		return
	var struck: Dictionary = foes[0]
	var beside: Dictionary = foes[1]
	var off: Dictionary = foes[2]
	for foe in foes:
		foe.status_effects.clear()
	var at := clearing(enfina.position)
	put(struck, at)
	put(enfina, at + Vector2i.LEFT)
	put(beside, at + Vector2i.DOWN)
	put(off, at + Vector2i.RIGHT * 2)
	var beside_at: Vector2i = beside.position
	var hp := {struck.id: struck.hp, beside.id: beside.hp, off.id: off.hp}
	damage_to.clear()
	give_turn(enfina)
	combat._splash(enfina, struck, sword)
	await settle(4)
	enfina.erase("tremor_struck")
	ok(damage_to.get(beside.id, 0) == 1 and beside.hp < hp[beside.id],
		"beside her target, in reach of both splashes: hit once, at the harder (x1.5 either way) - never twice",
		"%d hit(s), %d" % [damage_to.get(beside.id, 0), hp[beside.id] - beside.hp])
	ok(beside.position != beside_at or has_dazed(beside), "  and shoved a tile by Tremor - or dazed against something solid",
		"%s -> %s" % [beside_at, beside.position])
	ok(damage_to.get(off.id, 0) == 1 and off.position == at + Vector2i.RIGHT * 2,
		"two tiles off: Titanfall's splash, and no shove", "%d hit(s), %s" % [damage_to.get(off.id, 0), off.position])
	ok(struck.position == at + Vector2i.RIGHT and damage_to.get(struck.id, 0) == 0,
		"the one she struck: shoved a tile by Tremor, not caught by the splash again", "%s" % struck.position)
	log_line("")


func has_dazed(comb: Dictionary) -> bool:
	return not dazed_entries(comb).is_empty()


func the_step():
	log_line("======== the step after them ========")
	var enfina := who("enfina")
	var foes := enemies()
	var foe: Dictionary = foes[0]
	foe.status_effects.clear()
	var at := clearing(enfina.position)
	put(foe, at)
	put(enfina, at + Vector2i.LEFT)
	var done := swing(enfina, foe, "greatsword_attack", 3)
	ok(await wait_for(func(): return done[0] or combat.controller.is_stepping()) and combat.controller.is_stepping(),
		"her blow throws them back a tile: a step after them is offered")
	var offered: Array = combat.controller._step_tiles.duplicate()
	ok(foe.position == at + Vector2i.RIGHT and offered == [at], "  onto the tile they were thrown from, the only one nearer",
		"%s, %s" % [foe.position, offered])
	combat.controller.step_to(at)
	await wait_for(func(): return done[0])
	await settle(2)
	ok(enfina.position == at and combat.controller.movement == 2, "  she steps in, for a tile of movement - in reach of them again",
		"%s, %d left" % [enfina.position, combat.controller.movement])

	done = swing(enfina, foe, "greatsword_attack", 0)
	await wait_for(func(): return done[0] or combat.controller.is_stepping())
	ok(not combat.controller.is_stepping(), "with no movement left: no step", "%s" % foe.position)
	await finish(done)

	# What it never steps onto.
	put(foe, enfina.position + Vector2i.RIGHT * 2)
	give_turn(enfina)
	combat.controller.movement = 3
	var between: Vector2i = enfina.position + Vector2i.RIGHT
	enfina["tremor_struck"] = [foe.id]
	ok(combat.tremor_steps(enfina) == [between], "toward them, onto the free tile between", "%s" % [combat.tremor_steps(enfina)])
	combat._bad_ground.append({"hazard": HazardDefinition.new(), "tiles": [between], "from": 0, "until": 999999})
	ok(combat.tremor_steps(enfina).is_empty(), "  never onto ground that hurts")
	combat._bad_ground.pop_back()
	var other: Dictionary = foes[1] if foes.size() > 1 else {}
	if not other.is_empty():
		var other_at: Vector2i = other.position
		put(other, between)
		ok(combat.tremor_steps(enfina).is_empty(), "  nor onto anybody")
		put(other, other_at)
	enfina.erase("tremor_struck")

	# A blow of hers in somebody else's turn - a reaction - offers none.
	give_turn(foe)
	put(foe, enfina.position + Vector2i.RIGHT)
	combat._splash(enfina, foe, SkillDatabase.skills["greatsword_attack"])
	await settle(3)
	ok(not enfina.has("tremor_struck"), "a blow of hers in their turn (a reaction): no step after it")
	log_line("")


func stunning_blow():
	log_line("======== Stunning Blow ========")
	var blow: SkillDefinition = SkillDatabase.skills["stunning_blow"]
	var stun: Array = blow.all_effects().filter(func(effect): return effect != null and effect.condition != null)
	ok(is_equal_approx(blow.ability_modifier, 0.8) and stun.size() == 1 and stun[0].condition.resource_path.ends_with("stunned.tres")
		and stun[0].condition_duration == 1, "x0.8 and a one-turn Stun, as before")
	ok([41, 54, 64].map(func(level): return Combat.uses_a_rest({"level": level}, blow)) == [1, 2, 3],
		"1 / 2 / 3 uses a short rest at 41 / 54 / 64", "%s" % [[41, 54, 64].map(func(level): return Combat.uses_a_rest({"level": level}, blow))])
	var enfina := who("enfina")
	ok(combat.uses_left(enfina, blow) == 3, "at 64 she has three", str(combat.uses_left(enfina, blow)))
	var foe: Dictionary = enemies()[0]
	var at := clearing(enfina.position)
	for i in 3:
		foe.status_effects.clear()
		put(foe, at)
		put(enfina, at + Vector2i.LEFT)
		await finish(swing(enfina, foe, "stunning_blow", 3))
	ok(combat.uses_left(enfina, blow) == 0 and "short rest" in combat.refusal_for(enfina, blow, foe.position),
		"after three: spent until a short rest", "%d, \"%s\"" % [combat.uses_left(enfina, blow), combat.refusal_for(enfina, blow, foe.position)])
	log_line("")
