extends Node
## The designer's handoff of 2026-10-25 (docs/handoff_0.1/disarm_deep_corrosion_light_swing.md):
## Enfina's Armor Shred is Disarm - x0.8, and the target's next weapon attack
## deals half damage; Cyrus's Exposing Shot is gone, and Corrosive Round has a
## Deep Corrosion rank at 41 - x1.0 and Deeply Corroded (-20% Defense) in place of
## Corroded; Light Swing mends 5 / 7 / 9 / 12 / 15% of her own health, twice that
## the first time in a fight it strikes a foe at half their health or less.

var LOG_PATH := HarnessLog.path_for("disarm")
const WATCHER := "res://data/encounters/encounter_03_watcher.tres"
const DISARMED := "res://data/conditions/disarmed.tres"
const CORRODED := "res://data/conditions/corroded.tres"
const DEEPLY_CORRODED := "res://data/conditions/deeply_corroded.tres"
const PARTY := ["cyrus", "enfina", "prometheus", "alithia"]

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
	kits()
	defense_owners()
	await open_fight({"cyrus": "saboteur"}, 41)
	await disarm()
	await deep_corrosion()
	await open_fight({}, 1)
	light_swing_ladder()
	await light_swing()
	await close_fight()
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


## The watcher fight in the story, the party at `level` on the paths given.
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
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(2)
	# Nobody at the keyboard: a reaction is taken without asking.
	combat.reaction_prompt = null


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
	return combat.combatants.filter(func(c): return c.side == 1 and c.alive and not c.has("object") and not c.get("illusion", false))


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


## A row of `gap_of` + 1 open tiles, its right end returned, the nearer `near` the
## better.
func pair_near(near: Vector2i, gap_of: int = 1) -> Vector2i:
	var region: Rect2i = combat.controller._astargrid.region
	var best := Vector2i(-1, -1)
	var best_gap := 999999
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var there := Vector2i(x, y)
			var gap: int = combat.get_position_distance(near, there)
			if gap < best_gap and range(gap_of + 1).all(func(step): return open(there + Vector2i.LEFT * step)):
				best = there
				best_gap = gap
	return best


## Puts `target` `gap` tiles from `attacker` - beside them for 1 - on open ground.
func face_off(attacker: Dictionary, target: Dictionary, gap: int = 1):
	var near: Vector2i = attacker.position
	put(attacker, Vector2i(-50, -50))
	put(target, Vector2i(-51, -51))
	var at := pair_near(near, gap)
	put(target, at)
	put(attacker, at + Vector2i.LEFT * gap)


## Gives `comb` the turn, nothing in the way of acting, and a sure hit.
func give_turn(comb: Dictionary):
	combat.current_combatant = combat.combatants.find(comb)
	combat.controller.set_controlled_combatant(comb)
	combat.controller.player_turn = comb.side == 0
	combat.controller.action_locked = false
	comb.skill_used_this_turn = false
	comb.secondary_used_this_turn = false
	comb.reaction_used = false
	if not comb.status_effects.any(func(entry): return entry.get("source_name", "") == "test"):
		comb.status_effects.append({"stat": "accuracy", "amount": 200, "duration": 99, "source_name": "test"})


func use(key: String, user: Dictionary, target: Dictionary):
	give_turn(user)
	await combat.use_skill(key, user, target.position, false)
	await settle(2)


func has(comb: Dictionary, path: String) -> bool:
	return comb.status_effects.any(func(entry): return (entry.get("stat", "") == "condition" and entry.get("condition") != null
		and entry.condition.resource_path == path))


## Every skill key `key` could ever have: their own, and every path's.
func kit_of(key: String) -> Array:
	var definition: CombatantDefinition = CombatantDatabase.combatants[key]
	var keys: Array = definition.skills.duplicate()
	var paths := DataFolder.subclasses()
	for path in definition.subclasses:
		if paths.has(path):
			keys.append_array(paths[path].skills)
	return keys


func kits():
	log_line("======== the kits ========")
	ok(not SkillDatabase.skills.has("armor_shred"), "Armor Shred is gone from the game")
	ok(not SkillDatabase.skills.has("exposing_shot"), "Exposing Shot is gone from the game")
	ok(kit_of("enfina").has("disarm") and not kit_of("enfina").has("armor_shred"), "Enfina has Disarm and no Armor Shred")
	ok(not kit_of("cyrus").has("exposing_shot"), "Cyrus has no Exposing Shot")
	var disarm: SkillDefinition = SkillDatabase.skills.get("disarm")
	if disarm == null:
		ok(false, "Disarm is a skill")
		return
	var effects: Array = disarm.all_effects().filter(func(effect): return effect != null and effect.condition != null)
	ok(disarm.required_level == 24 and is_equal_approx(disarm.ability_modifier, 0.8) and disarm.melee and disarm.max_range == 1
		and disarm.aoe_radius == 0 and disarm.deals_damage and disarm.spell_slot_level == 0 and disarm.uses_per_short_rest == 0,
		"Disarm: level 24, x0.8, a melee blow at one target, a main action with no limit on its uses")
	ok(effects.size() == 1 and effects[0].condition.resource_path == DISARMED, "  and it puts Disarmed on them")
	var disarmed: ConditionDefinition = load(DISARMED)
	ok(is_equal_approx(disarmed.weapon_damage_change, -0.5) and disarmed.ends_after_weapon_attack and disarmed.defense_change == 0.0
		and disarmed.dot_type == 0, "Disarmed: their next weapon attack at half, nothing lingering - no Defense taken, no damage over time")
	var round: SkillDefinition = SkillDatabase.skills["corrosive_round"]
	var deep: Array = round.ranks.filter(func(rank): return rank != null and rank.level == 41)
	ok(deep.size() == 1 and deep[0].condition != null and deep[0].condition.resource_path == DEEPLY_CORRODED
		and is_equal_approx(deep[0].ability_modifier, 1.0), "Corrosive Round has a Deep Corrosion rank at 41: x1.0 and Deeply Corroded")
	var deeply: ConditionDefinition = load(DEEPLY_CORRODED)
	var corroded: ConditionDefinition = load(CORRODED)
	ok(is_equal_approx(deeply.defense_change, -0.2) and is_equal_approx(corroded.defense_change, -0.1),
		"Deeply Corroded takes 20% of their Defense, Corroded 10%")
	log_line("")


## Every lingering Defense reduction the party's skills can put on anybody:
## a condition's Defense Change, or a Defense modifier lasting past the blow.
func defense_owners():
	log_line("======== who takes Defense away ========")
	var owners := {}
	for key in PARTY:
		for skill_key in kit_of(key):
			var skill: SkillDefinition = SkillDatabase.skills.get(skill_key)
			if skill == null:
				continue
			for effect in skill.all_effects():
				if effect == null or effect.applies_to_caster:
					continue
				var shreds := false
				if effect.condition != null and effect.condition.defense_change < 0.0:
					shreds = true
				if effect.type == EffectDefinition.EffectType.STAT_MODIFIER and effect.stat == "defense" and effect.modifier_amount < 0:
					shreds = true
				if shreds:
					owners[key] = owners.get(key, []) + [skill.name]
	ok(owners.has("cyrus") and owners.cyrus.has("Corrosive Round"), "Cyrus takes Defense away with Corrosive Round", "%s" % [owners.get("cyrus", [])])
	ok(not owners.has("enfina"), "Enfina takes none away", "%s" % [owners.get("enfina", [])])
	for key in owners:
		if key != "cyrus" and key != "enfina":
			log_line("  NOTE  %s still lowers Defense with %s - not named by the handoff, OPEN in the ledger" % [key, owners[key]])
	log_line("")


func disarm():
	log_line("======== Disarm ========")
	var enfina := who("enfina")
	var cyrus := who("cyrus")
	var prometheus := who("prometheus")
	var foe: Dictionary = foes()[0]
	ok(enfina.skill_list.has("disarm") and not enfina.skill_list.has("armor_shred"), "Enfina at 41 fights with Disarm")
	ok(not cyrus.skill_list.has("exposing_shot"), "Cyrus at 41 has no Exposing Shot")
	var gun: SkillDefinition = SkillDatabase.skills["gun"]
	var sword: SkillDefinition = SkillDatabase.skills["greatsword_attack"]
	var spell: SkillDefinition = SkillDatabase.skills["fire_blast"]
	var bomb: SkillDefinition = ItemDatabase.item("small_bomb")
	ok(Combat.is_weapon_attack(gun) and Combat.is_weapon_attack(sword) and not Combat.is_weapon_attack(spell)
		and not Combat.is_weapon_attack(bomb), "a weapon attack: a gun or a sword, not a spell or a bomb")
	var disarmed: ConditionDefinition = load(DISARMED)
	var whole: int = combat.skill_damage(cyrus, foe, gun)
	var whole_spell: int = combat.skill_damage(prometheus, foe, spell)
	combat.put_condition(cyrus, disarmed, 2, "test", true)
	combat.put_condition(prometheus, disarmed, 2, "test", true)
	var halved: int = combat.skill_damage(cyrus, foe, gun)
	ok(absi(halved * 2 - whole) <= 1, "Disarmed, his Gun lands for half", "%d -> %d" % [whole, halved])
	ok(combat.predict_hit(cyrus, foe, gun).damage == halved, "  and the aim prompt says so")
	ok(combat.skill_damage(prometheus, foe, spell) == whole_spell, "a spell cast while Disarmed lands whole", "%d" % whole_spell)

	# The spell leaves it on him; his weapon attack, hit or miss, takes it off.
	foe.hp = foe.max_hp
	face_off(prometheus, foe)
	await use("fire_blast", prometheus, foe)
	ok(has(prometheus, DISARMED), "  and Disarmed stays on through it")
	foe.hp = foe.max_hp
	face_off(cyrus, foe, 3)
	await use("gun", cyrus, foe)
	ok(not has(cyrus, DISARMED), "his next weapon attack made, Disarmed comes off")
	ok(combat.skill_damage(cyrus, foe, gun) == whole, "  and the one after lands whole")

	# Enfina's blow puts it on.
	foe.status_effects.clear()
	foe.hp = foe.max_hp
	face_off(enfina, foe)
	var foe_hp: int = foe.hp
	await use("disarm", enfina, foe)
	ok(has(foe, DISARMED) and foe.hp < foe_hp, "Enfina's Disarm cuts them and leaves them Disarmed", "%d hurt" % (foe_hp - foe.hp))
	await use("disarm", enfina, foe)
	var entries: Array = foe.status_effects.filter(func(entry): return entry.get("condition") == disarmed)
	ok(entries.size() == 1, "  twice: still one Disarmed - nothing stacks", "%d" % entries.size())
	foe.status_effects.clear()
	log_line("")


func deep_corrosion():
	log_line("======== Deep Corrosion ========")
	var cyrus := who("cyrus")
	var round: SkillDefinition = SkillDatabase.skills["corrosive_round"]
	ok(cyrus.skill_list.has("corrosive_round"), "Cyrus the Saboteur at 41 has Corrosive Round")
	ok(is_equal_approx(Combat.modifier_of({"level": 40}, round), 0.8) and is_equal_approx(Combat.modifier_of({"level": 41}, round), 1.0),
		"x0.8 below 41, x1.0 from 41", "%s, %s" % [Combat.modifier_of({"level": 40}, round), Combat.modifier_of({"level": 41}, round)])
	var effect: EffectDefinition = round.all_effects().filter(func(e): return e != null and e.condition != null)[0]
	ok(Combat.ranked_condition_effect({"level": 40}, round, effect).condition.resource_path == CORRODED
		and Combat.ranked_condition_effect({"level": 41}, round, effect).condition.resource_path == DEEPLY_CORRODED,
		"Corroded below 41, Deeply Corroded from 41")
	var foe: Dictionary = foes()[0]
	foe.status_effects.clear()
	foe.hp = foe.max_hp
	var defense: int = combat.stat_of(foe, Stats.Type.DEFENSE)
	combat.put_condition(foe, load(CORRODED), 5, "test", true)
	ok(has(foe, CORRODED), "already Corroded")
	face_off(cyrus, foe, 3)
	await use("corrosive_round", cyrus, foe)
	ok(has(foe, DEEPLY_CORRODED) and not has(foe, CORRODED), "his round at 41: Deeply Corroded in place of Corroded, never both")
	var deep: int = combat.stat_of(foe, Stats.Type.DEFENSE)
	ok(deep == roundi(defense * 0.8) or deep == int(defense * 0.8), "  their Defense down 20%", "%d -> %d" % [defense, deep])
	await use("corrosive_round", cyrus, foe)
	var count: int = foe.status_effects.filter(func(entry): return (entry.get("stat", "") == "condition" and entry.get("condition") != null
		and entry.condition.resource_path == DEEPLY_CORRODED)).size()
	ok(count == 1 and combat.stat_of(foe, Stats.Type.DEFENSE) == deep, "  again: refreshed, never stacked", "%d" % count)
	foe.status_effects.clear()
	log_line("")


func light_swing_ladder():
	log_line("======== Light Swing's ladder ========")
	var swing: SkillDefinition = SkillDatabase.skills["light_swing"]
	var heal: EffectDefinition = combat.heal_effect_of(swing)
	ok(heal != null and heal.applies_to_caster and heal.heals_share_only and heal.share_doubled_on_wounded,
		"Light Swing mends a share of her own health and nothing from her power")
	var shares: Array = [1, 15, 16, 31, 32, 53, 54, 63, 64].map(func(level): return roundi(Combat.heal_share_of({"level": level}, swing, heal) * 100))
	ok(shares == [5, 5, 7, 7, 9, 9, 12, 12, 15], "5 / 7 / 9 / 12 / 15% at 1 / 16 / 32 / 54 / 64", "%s" % [shares])
	log_line("")


func light_swing():
	log_line("======== Light Swing in a fight (level 1) ========")
	var enfina := who("enfina")
	var all := foes()
	if all.size() < 2:
		ok(false, "two foes to swing at")
		return
	var first: Dictionary = all[0]
	var second: Dictionary = all[1]
	for foe in [first, second]:
		foe.max_hp = 1000
		foe.hp = 1000
	var max_hp: int = combat.get_effective_stat(enfina, "max_hp")
	var base := roundi(max_hp * 0.05)
	var mended := func(foe: Dictionary, foe_hp: int) -> int:
		foe.hp = foe_hp
		enfina.hp = 1
		face_off(enfina, foe)
		await use("light_swing", enfina, foe)
		return enfina.hp - 1
	var got: int = await mended.call(first, 1000)
	ok(got == base, "on a foe above half their health: 5% of hers", "%d of %d (%d)" % [got, max_hp, base])
	got = await mended.call(first, 1000)
	ok(got == base, "  and again, as often as she swings", "%d" % got)
	got = await mended.call(first, 500)
	ok(got == roundi(max_hp * 0.05 * 2), "the first blow on them at half their health or less: twice that", "%d" % got)
	got = await mended.call(first, 400)
	ok(got == base, "  the next on the same foe: the base again - once a foe, a fight", "%d" % got)
	got = await mended.call(second, 1000)
	ok(got == base, "another foe, still above half: the base", "%d" % got)
	got = await mended.call(second, 300)
	ok(got == roundi(max_hp * 0.05 * 2), "  that foe brought low: twice, once for them too", "%d" % got)
	# The blow that breaks the threshold counts: struck from above half to below.
	var third: Dictionary = all[2] if all.size() > 2 else {}
	if not third.is_empty():
		third.max_hp = 1000
		var hit: int = combat.skill_damage(enfina, third, SkillDatabase.skills["light_swing"])
		got = await mended.call(third, 500 + hit)
		ok(got == roundi(max_hp * 0.05 * 2), "the blow that takes a foe to half pays twice", "%d (hit %d)" % [got, hit])
	ok(enfina.get("wounded_bonus_on", []).size() == (3 if not third.is_empty() else 2),
		"who she has had it from is kept on her for the fight", "%s" % [enfina.get("wounded_bonus_on", [])])
	log_line("")
