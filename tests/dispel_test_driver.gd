extends Node
## Dispel Magic (Combat "Dispelling"): what spells left on somebody - theirs or
## the other side's - ended by the gate it is cast through or a shallower one,
## and what came through a deeper gate left alone; a spell's zone undone at its
## ground; what a spell called up or made undone with it; and what no spell did
## left be.

var LOG_PATH := HarnessLog.path_for("dispel")
const WATCHER := "res://data/encounters/encounter_03_watcher.tres"

var _log: FileAccess = null
var _fail = 0
var game: Node = null
var combat = null


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
	await dispelling()
	if game != null and is_instance_valid(game):
		game.queue_free()
		await settle(3)
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


func open_fight():
	Campaign.reset()
	Campaign.set_party(["cyrus", "enfina", "prometheus", "alithia"], 64)
	for spell in Campaign.learnable_spells("prometheus"):
		Campaign.learn("prometheus", spell)
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
	combat.reaction_prompt = null
	for comb in combat.combatants:
		if comb.alive:
			comb.max_hp = 9999
			comb.hp = 9999


func who(key: String) -> Dictionary:
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == key and not comb.get("illusion", false):
			return comb
	return {}


func enemies() -> Array:
	return combat.combatants.filter(func(c): return c.side == 1 and c.alive and not c.has("object"))


func put(comb: Dictionary, tile: Vector2i):
	var from: Vector2i = comb.position
	comb.position = tile
	if comb.get("sprite") != null:
		comb.sprite.position = combat.controller.tile_map.map_to_local(tile)
	combat.controller.reposition_combatant(from, tile)


func open(tile: Vector2i) -> bool:
	return combat.controller.is_in_bounds(tile) and combat.controller.is_on_map(tile) \
		and combat.get_combatant_at(tile).is_empty() and not combat.controller.is_tile_blocking(tile, 0)


## The nearest free tile to `near` that passes `test`.
func a_tile(near: Vector2i, test: Callable) -> Vector2i:
	var region: Rect2i = combat.controller._astargrid.region
	var best := Vector2i(-1, -1)
	var best_gap := 999999
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var there := Vector2i(x, y)
			var gap: int = combat.get_position_distance(near, there)
			if gap >= best_gap or not open(there) or not test.call(there):
				continue
			best = there
			best_gap = gap
	return best


func give_turn(comb: Dictionary):
	combat.current_combatant = combat.combatants.find(comb)
	combat.controller.set_controlled_combatant(comb)
	combat.controller.player_turn = comb.side == 0
	combat.controller.action_locked = false
	comb.skill_used_this_turn = false
	comb.secondary_used_this_turn = false


func has_condition(comb: Dictionary, name: String) -> bool:
	return combat.conditions_of(comb).any(func(c): return c.resource_path.get_file().get_basename() == name)


## What `skill`'s condition effect does to `target`, from `caster`, as though cast.
func put_on(caster: Dictionary, target: Dictionary, key: String):
	var skill: SkillDefinition = SkillDatabase.skills[key]
	for effect in skill.effects:
		if effect != null and effect.type != EffectDefinition.EffectType.DAMAGE:
			combat.apply_effect(caster, target, effect, skill, false)


## Prometheus casts Dispel Magic at `aim`, through `gate`.
func dispel(prometheus: Dictionary, aim: Vector2i, gate: int):
	give_turn(prometheus)
	prometheus["cast_through"] = gate
	await combat.use_skill("dispel_magic", prometheus, aim, false)
	await settle(2)


func dispelling():
	log_line("======== Dispel Magic ========")
	await open_fight()
	var prometheus := who("prometheus")
	var alithia := who("alithia")
	var cyrus := who("cyrus")
	var spell: SkillDefinition = SkillDatabase.skills.dispel_magic
	ok(prometheus.skill_list.has("dispel_magic") and spell.spell_slot_level == 3 and spell.chooses_gate,
		"Prometheus's, a Pandora spell cast through whichever gate he likes")
	# Sure of hand, so nothing here misses.
	prometheus.status_effects.append({"stat": "accuracy", "amount": 200, "duration": 99, "source_name": "test"})
	prometheus.spell_slots = Stats.gates_for_level(64)
	ok(await combat._choose_gate(prometheus, spell) == 3, "asked of nobody, it goes through its own gate")

	var foe: Dictionary = enemies()[0]
	put(foe, a_tile(prometheus.position, func(tile): return combat.get_position_distance(tile, prometheus.position) in [2, 3, 4]))
	foe.status_effects.clear()
	put_on(prometheus, foe, "wind_swoon")
	put_on(alithia, foe, "glacial_tide")
	put_on(cyrus, foe, "poison_dart")
	var swoon: Dictionary = foe.status_effects.filter(func(e): return e.get("condition") != null and e.condition.display_name == "Windswept")[0]
	ok(swoon.get("spell_gate", 0) == 2, "what a spell leaves carries its gate", "%s" % swoon.get("spell_gate", "none"))
	var pandora: int = prometheus.spell_slots[3]
	await dispel(prometheus, foe.position, 3)
	ok(not has_condition(foe, "windswept"), "through Pandora's gate, a Hermes spell's windswept is undone")
	ok(has_condition(foe, "frozen"), "but not Glacial Tide's frozen - a Sophia spell, deeper")
	ok(has_condition(foe, "poisoned"), "nor a poison that was never a spell's")
	ok(prometheus.spell_slots[3] == pandora - 1, "one casting through Pandora's gate")
	var sophia: int = prometheus.spell_slots[7]
	await dispel(prometheus, foe.position, 7)
	ok(not has_condition(foe, "frozen") and prometheus.spell_slots[7] == sophia - 1, "cast through Sophia's, the frozen too")

	put(cyrus, a_tile(prometheus.position, func(tile): return combat.get_position_distance(tile, prometheus.position) in [2, 3]))
	cyrus.status_effects.clear()
	put_on(prometheus, cyrus, "quicken")
	put_on(prometheus, cyrus, "invisibility")
	ok(not cyrus.status_effects.is_empty() and combat.is_invisible(cyrus), "Cyrus quickened and invisible, by spells")
	await dispel(prometheus, cyrus.position, 3)
	ok(cyrus.status_effects.filter(func(e): return e.has("spell_gate")).is_empty() and not combat.is_invisible(cyrus),
		"his own side's undone just the same")

	# A zone: Sanctuary of Light, through Nemesis's gate.
	var ground := a_tile(prometheus.position + Vector2i(3, 0), func(tile): return combat.get_position_distance(tile, prometheus.position) in [3, 4, 5] \
		and combat.get_position_distance(tile, alithia.position) <= 6)
	give_turn(alithia)
	alithia.spell_slots = Stats.gates_for_level(64)
	await combat.use_skill("sanctuary_of_light", alithia, ground, false)
	await settle(2)
	var bare := a_tile(ground, func(tile): return combat.zones_at(tile).size() > 0 and combat.get_position_distance(tile, prometheus.position) <= 10)
	ok(not combat.zones.is_empty() and combat.zones[0].gate == 6, "a sanctuary on the ground, through Nemesis's gate", "%s" % [combat.zones.map(func(zone): return zone.gate)])
	ok(combat.refusal_for(prometheus, spell, bare) == "", "bare ground in it can be aimed at")
	await dispel(prometheus, bare, 3)
	ok(combat.zones.size() == 1, "through Pandora's, it holds")
	await dispel(prometheus, bare, 6)
	ok(combat.zones.is_empty(), "through Nemesis's, it is gone")
	var nothing := a_tile(prometheus.position, func(tile): return combat.zones_at(tile).is_empty() and combat.get_position_distance(tile, prometheus.position) in [2, 3])
	ok(combat.refusal_for(prometheus, spell, nothing) != "", "bare ground with no spell's work on it, nothing to aim at")

	# What a spell called up or made.
	var spot := a_tile(prometheus.position, func(tile): return combat.get_position_distance(tile, prometheus.position) in [2, 3, 4])
	give_turn(prometheus)
	# Pandora's castings back - spent, it would come through a deeper gate.
	prometheus.spell_slots = Stats.gates_for_level(64)
	await combat.use_skill("kindled_hound", prometheus, spot, false)
	await settle(2)
	var hound: Dictionary = combat.summons_of(prometheus)[0] if not combat.summons_of(prometheus).is_empty() else {}
	ok(hound.get("spell_gate", 0) == 3, "the hound a spell called up carries its gate", "%s, %s, %s" % [hound.get("name", "no hound"), hound.get("spell_gate", "no gate"), prometheus.spell_slots])
	if not hound.is_empty():
		await dispel(prometheus, hound.position, 3)
		ok(not hound.alive, "and is dispelled")
	var count: int = combat.combatants.size()
	combat.summon_decoy(alithia, cyrus, SkillDatabase.skills.mirror_image)
	var image: Dictionary = combat.combatants.back() if combat.combatants.size() > count else {}
	if not image.is_empty():
		await dispel(prometheus, image.position, 3)
		ok(not image.alive, "an image, shattered")
	var cover_at := a_tile(prometheus.position, func(tile): return combat.get_position_distance(tile, prometheus.position) in [3, 4])
	give_turn(alithia)
	await combat.use_skill("illusory_cover", alithia, cover_at, false)
	await settle(2)
	var cover: Dictionary = combat.get_combatant_at(cover_at)
	ok(cover.get("name", "") == "Illusory Cover", "cover that is not there")
	await dispel(prometheus, cover_at, 3)
	ok(not cover.get("alive", true), "dispelled - the one thing that touches it")
	log_line("")
