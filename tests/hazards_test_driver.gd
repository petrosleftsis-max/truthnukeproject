extends Node
## Things on the map that go off (the designer, 2026-11-05: "for example I may want a
## mechanic of an encounter to be the players dealing enough damage on something so that it
## can deal even more damage on many enemies"): a Demolition Charge that blows up whoever
## and whatever is round it, a Gale Urn that throws them instead, hurting them on what they
## hit, and a Tar Cauldron whose ground costs twice to cross. Health, damage and area are
## all the object's own to set.

const LOG_NAME := "hazards"
const WATCHER := "res://data/encounters/encounter_03_watcher.tres"
const PARTY := ["enfina", "cyrus", "alithia"]

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
	get_tree().create_timer(150.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await settle()
	var booted = get_tree().current_scene
	if booted != null:
		booted.queue_free()
		await settle()
	await open_fight()
	await the_charge()
	await open_fight()
	await the_urn()
	await open_fight()
	await the_cauldron()
	await close_fight()
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


func open_fight():
	await close_fight()
	Campaign.reset()
	Campaign.set_party(PARTY, 14)
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
		if comb.has("stats"):
			comb.hp = 900
			comb.max_hp = 900


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
	controller.set_controlled_combatant(comb)
	comb.status_effects.append({"stat": "accuracy", "amount": 100, "op": "add", "duration": 99, "source_name": "test"})
	await settle()


## Puts a thing of `key` on the map at `tile`.
func put_thing(key: String, tile: Vector2i) -> Dictionary:
	var definition: CombatantDefinition = load("res://data/objects/%s.tres" % key)
	var thing: Dictionary = combat.create_combatant(definition, key)
	combat.add_combatant(thing, 1, tile)
	await settle()
	return thing


## A straight clear run of `length` tiles from the map's open ground.
func a_run(length: int, anyone: Dictionary) -> Array:
	for x in range(0, 40):
		for y in range(0, 40):
			for way in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
				var clear := true
				for i in length:
					var tile: Vector2i = Vector2i(x, y) + way * i
					if not controller.is_in_bounds(tile) or controller.is_tile_blocking(tile, 0) or (not combat.get_combatant_at(tile).is_empty() and combat.get_combatant_at(tile) != anyone):
						clear = false
						break
				if clear:
					return [Vector2i(x, y), way]
	return []


func place(comb: Dictionary, tile: Vector2i):
	comb.position = tile
	comb.sprite.position = combat.sprite_point(comb)
	controller.refresh_occupancy()


func the_charge():
	log_line("======== Demolition Charge ========")
	var enfina := who("enfina")
	var the_foes := foes()
	var near: Dictionary = the_foes[0]
	var far: Dictionary = the_foes[1]
	var run := a_run(9, enfina)
	ok(not run.is_empty(), "room for it", "%s" % [run])
	var charge := await put_thing("demolition_charge", run[0] + run[1] * 4)
	ok(charge.hp == 60 and charge.object.blast_radius == 3 and charge.object.blast_damage == 120, "its health, area and damage are its own to set", "%d" % charge.hp)
	place(near, run[0] + run[1] * 5)
	place(far, run[0] + run[1] * 8)
	place(enfina, run[0] + run[1] * 3)
	var keg := await put_thing("powder_keg", run[0] + run[1] * 6)
	await their_turn(enfina)
	var blow: SkillDefinition = SkillDatabase.skills.greatsword_attack
	# Enough damage needed: a blow that does not break it does nothing.
	charge.hp = 9999
	var near_hp: int = near.hp
	await combat.use_skill("greatsword_attack", enfina, charge.position, false)
	await settle()
	ok(charge.hp < 9999 and charge.alive and near.hp == near_hp, "hit, it takes it, and holds", "%d" % charge.hp)
	# Broken: everybody and everything round it, whichever side.
	charge.hp = 1
	near_hp = near.hp
	var her_hp: int = enfina.hp
	var far_hp: int = far.hp
	await their_turn(enfina)
	enfina.skill_used_this_turn = false
	await combat.use_skill("greatsword_attack", enfina, charge.position, false)
	await settle(4)
	ok(not charge.alive, "broken, it goes up")
	ok(near.hp < near_hp, "the enemy round it is hurt", "%d" % (near_hp - near.hp))
	ok(enfina.hp < her_hp, "and so is whoever set it off, on their own side", "%d" % (her_hp - enfina.hp))
	ok(far.hp == far_hp or combat.distance_to(far, charge.position) <= 3, "not those out of its area", "%d" % (far_hp - far.hp))
	ok(not keg.alive, "and the keg in its area goes off too: whatever is there")
	log_line("")


func the_urn():
	log_line("======== Gale Urn ========")
	var enfina := who("enfina")
	var the_foes := foes()
	var thrown: Dictionary = the_foes[0]
	var stopped: Dictionary = the_foes[1]
	var into: Dictionary = the_foes[2] if the_foes.size() > 2 else who("cyrus")
	var run := a_run(9, thrown)
	var urn := await put_thing("gale_urn", run[0] + run[1] * 2)
	ok(urn.object.blast_push == 3 and urn.object.blast_collision_damage > 0 and urn.object.blast_damage == 0, "it throws rather than hurts", "%d" % urn.object.blast_push)
	place(enfina, run[0])
	place(thrown, run[0] + run[1] * 3)
	await their_turn(enfina)
	var blow: SkillDefinition = SkillDatabase.skills.gun
	# Nothing in its way: three tiles, no harm.
	urn.hp = 1
	var seen: Array = combat.foresee_shoves(enfina, blow, [urn])
	var of_thrown: Array = seen.filter(func(entry): return entry.who == thrown)
	ok(of_thrown.size() == 1 and of_thrown[0].to == run[0] + run[1] * 6 and of_thrown[0].damage == 0, "aiming at it shows who it would throw, and where", "%s" % [of_thrown[0].to if not of_thrown.is_empty() else null])
	var thrown_hp: int = thrown.hp
	var to: Vector2i = of_thrown[0].to if not of_thrown.is_empty() else thrown.position
	combat.lose_hp(urn, 999)
	combat.combatant_die(urn)
	await settle(3)
	ok(not urn.alive and thrown.position == to, "broken, they are thrown as it said", "%s" % thrown.position)
	ok(thrown.hp == thrown_hp, "and it did them no harm in itself", "%d" % (thrown_hp - thrown.hp))
	# Into somebody: both hurt.
	var second := await put_thing("gale_urn", run[0] + run[1] * 2)
	place(thrown, run[0] + run[1] * 3)
	place(into, run[0] + run[1] * 6)
	second.hp = 1
	seen = combat.foresee_shoves(enfina, blow, [second])
	of_thrown = seen.filter(func(entry): return entry.who == thrown)
	ok(of_thrown.size() == 1 and of_thrown[0].into == into and of_thrown[0].damage > 0, "stopped by somebody, the prompt has what that costs", "%d" % (of_thrown[0].damage if not of_thrown.is_empty() else -1))
	var into_hp: int = into.hp
	thrown_hp = thrown.hp
	var expected: int = of_thrown[0].damage if not of_thrown.is_empty() else 0
	combat.lose_hp(second, 999)
	combat.combatant_die(second)
	await settle(3)
	ok(thrown_hp - thrown.hp == expected, "and they take what it said", "%d" % (thrown_hp - thrown.hp))
	ok(into.hp < into_hp, "and so does whoever they hit", "%d" % (into_hp - into.hp))
	log_line("")


func the_cauldron():
	log_line("======== Tar Cauldron ========")
	var enfina := who("enfina")
	var run := a_run(8, enfina)
	var cauldron := await put_thing("tar_cauldron", run[0] + run[1] * 3)
	ok(cauldron.hp == 40 and cauldron.object.costly_radius == 2, "its health and area are its own to set")
	var near: Vector2i = run[0] + run[1] * 2
	var far: Vector2i = run[0] + run[1] * 7
	ok(combat.hem_cost(enfina, near) == 2, "a step near it costs twice")
	ok(combat.hem_cost(enfina, far) == 1, "not further off")
	enfina["movement_class"] = 1
	ok(combat.hem_cost(enfina, near) == 1, "not for somebody flying")
	enfina["movement_class"] = 0
	ok(combat.costly_ground().has(near) and not combat.costly_ground().has(far), "and the board has the ground to draw")
	# A real walk: what it costs.
	place(enfina, run[0])
	await their_turn(enfina)
	controller.set_movement(10)
	await controller.ai_move(run[0] + run[1] * 2)
	await settle()
	ok(controller.movement == 10 - 2 - 2, "walked: two tiles of it, at twice each", "%d" % controller.movement)
	# Broken, the ground is as it was.
	combat.lose_hp(cauldron, 999)
	combat.combatant_die(cauldron)
	await settle(2)
	ok(not cauldron.alive and combat.hem_cost(enfina, near) == 1, "broken, it is gone")
	ok(combat.costly_ground().is_empty(), "off the board too")
	log_line("")
