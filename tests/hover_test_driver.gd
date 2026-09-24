extends Node
## Moves that change how somebody gets about, and Hover in particular.
##
## The movement class is not a cosmetic label: it decides what blocks you, what
## rough ground costs you, and whether you can cross a tile somebody is already
## standing on. So a skill that changes it has to change all of that, and has to
## put it back when it wears off.

var LOG_PATH := HarnessLog.path_for("hover")
const GROUND := 0
const FLYING := 1

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
	get_tree().create_timer(240.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


## The effect Hover carries, dug out of the skill itself rather than rebuilt
## here, so the test is about the shipped skill and not about a copy of it.
func hover_effect() -> EffectDefinition:
	for effect in SkillDatabase.skills["hover"].all_effects():
		if effect.type == EffectDefinition.EffectType.MOVEMENT_CLASS:
			return effect
	return null


func run_test():
	log_line("======== a skill can say how somebody moves ========")
	ok("MOVEMENT_CLASS" in EffectDefinition.EffectType.keys(),
		"there is an effect type for it")
	# The number is what a .tres stores, so these are frozen: a new type goes on
	# the end, and anything inserted in the middle silently turns every existing
	# effect in the project into a different one. Checking the whole ladder
	# rather than "the newest one is last", which stops being true the next time
	# a type is added and says nothing about the ones that matter.
	var frozen := {
		"DAMAGE": 0, "HEAL": 1, "STAT_MODIFIER": 2, "DAMAGE_OVER_TIME": 3,
		"DISPEL": 4, "PUSH": 5, "PULL": 6, "STAT_MULTIPLIER": 7,
		"CONDITION": 8, "REVEAL": 9, "MOVEMENT_CLASS": 10, "HIDE": 11,
		"RESISTANCE": 12, "UPGRADE_ELEMENT": 13,
	}
	var moved := []
	for name in frozen:
		if not name in EffectDefinition.EffectType.keys():
			moved.append("%s is gone" % name)
		elif EffectDefinition.EffectType[name] != frozen[name]:
			moved.append("%s is now %d, was %d" % [name, EffectDefinition.EffectType[name], frozen[name]])
	ok(moved.is_empty(),
		"every effect type still means what the resources think it means",
		"%s" % [moved])
	ok(EffectDefinition.EffectType.keys().size() == frozen.size(),
		"and a new one was added at the end rather than in the middle",
		"%d types, %d known here" % [EffectDefinition.EffectType.keys().size(), frozen.size()])
	var blank := EffectDefinition.new()
	ok("movement_class" in blank, "the effect has a class to set")
	log_line("")

	log_line("======== Hover, as asked for ========")
	ok(SkillDatabase.skills.has("hover"), "the skill is in the database")
	var hover: SkillDefinition = SkillDatabase.skills.get("hover")
	if hover == null:
		log_line("FAILURES: %d" % (_fail + 1))
		get_tree().quit(1)
		return
	ok(hover.name == "Hover", "called Hover", hover.name)
	ok(hover.spell_slot_level == 2, "cast through the Gates of Hermes",
		Stats.gate_name(hover.spell_slot_level))
	ok(hover.targets_ally, "aimed at allies")
	ok(not hover.deals_damage, "and does not hurt the ally it lands on")
	var effect = hover_effect()
	ok(effect != null, "it carries a movement-class effect")
	ok(effect != null and effect.movement_class == FLYING, "which is flying",
		Stats.movement_class_name(effect.movement_class) if effect else "none")
	ok(effect != null and effect.duration > 0, "for a while, not for ever",
		"%d turns" % (effect.duration if effect else 0))
	# Godot leaves a property out of a saved resource when it matches its
	# default, so a skill that relies on the default has nothing written in it
	# and changes meaning the day the default does. Hover says it outright.
	var written = FileAccess.open("res://skills/hover.tres", FileAccess.READ)
	if written != null:
		ok(written.get_as_text().contains("movement_class = 1"),
			"and the resource says so itself rather than leaning on a default")
	ok(EffectDefinition.new().movement_class == GROUND,
		"the default being Ground is what makes that necessary",
		Stats.movement_class_name(EffectDefinition.new().movement_class))
	log_line("")

	# A real battle, because what a movement class means is a question for the
	# map rather than for the dictionary.
	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_02_sappers.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	for i in 8:
		await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await get_tree().process_frame

	var walker = {}
	var caster = {}
	for comb in combat.combatants:
		if comb.alive and comb.side == 0 and comb.movement_class == GROUND:
			if walker.is_empty():
				walker = comb
			elif caster.is_empty():
				caster = comb
	if walker.is_empty() or caster.is_empty():
		ok(false, "the fight has two walkers to try this on")
		log_line("FAILURES: %d" % _fail)
		get_tree().quit(1)
		return

	log_line("======== it lifts them, and puts them down again ========")
	ok(walker.get("base_movement_class", -1) == GROUND,
		"what they were born as is remembered", "%s" % walker.get("base_movement_class", -1))
	var reach_on_foot = combat.controller.get_reachable_tiles(
		walker.position, walker.movement_class, 6).size()

	combat.apply_effect(caster, walker, effect, SkillDatabase.skills["hover"], true)
	await get_tree().process_frame
	ok(walker.movement_class == FLYING, "casting it puts them in the air",
		Stats.movement_class_name(walker.movement_class))
	var lifted := false
	for eff in walker.status_effects:
		if eff.get("stat", "") == "movement_class":
			lifted = true
	ok(lifted, "carried as a timed effect like any other buff")

	var reach_in_air = combat.controller.get_reachable_tiles(
		walker.position, walker.movement_class, 6).size()
	ok(reach_in_air >= reach_on_foot,
		"and the map opens up rather than closing in",
		"%d tiles on foot, %d in the air" % [reach_on_foot, reach_in_air])

	# Whether that is worth anything is a question about the map, not about the
	# skill: if a map blocks flyers and walkers identically and charges them the
	# same for rough ground, Hover is a spell that does nothing you can see.
	var blocks_walkers := 0
	var blocks_flyers := 0
	var costly_on_foot := 0
	for tile in combat.controller._all_blocking_spaces:
		if combat.controller.is_tile_blocking(tile, GROUND):
			blocks_walkers += 1
		if combat.controller.is_tile_blocking(tile, FLYING):
			blocks_flyers += 1
	for tile in combat.controller.get_reachable_tiles(walker.position, GROUND, 6):
		if combat.controller.get_tile_cost_for_class(tile, GROUND) > 1:
			costly_on_foot += 1
	log_line("  NOTE  this map blocks %d tiles to walkers and %d to flyers; %d tiles nearby cost a walker extra"
		% [blocks_walkers, blocks_flyers, costly_on_foot])
	ok(blocks_flyers < blocks_walkers or costly_on_foot > 0,
		"being in the air is worth something here",
		"%d fewer tiles in the way, %d cheaper" % [blocks_walkers - blocks_flyers, costly_on_foot])

	# Wearing off is the half that is easy to forget.
	var turns = 0
	while walker.movement_class == FLYING and turns < 20:
		combat.process_status_effects(walker)
		turns += 1
	ok(walker.movement_class == GROUND, "it wears off and they come down",
		Stats.movement_class_name(walker.movement_class))
	ok(turns == effect.duration + 1,
		"after the turns it said, not one more or less",
		"%d turns of flight for a duration of %d" % [turns - 1, effect.duration])
	ok(combat.controller.get_reachable_tiles(walker.position, walker.movement_class, 6).size()
		== reach_on_foot,
		"and the map is exactly as it was before they took off")
	log_line("")

	log_line("======== cleansing it also puts them down ========")
	# The dangerous version of this bug: the effect is lifted but the field it
	# was holding open is left where it was, and somebody walks on air for ever.
	combat.apply_effect(caster, walker, effect, SkillDatabase.skills["hover"], true)
	await get_tree().process_frame
	ok(walker.movement_class == FLYING, "up again")
	var strip := EffectDefinition.new()
	strip.type = EffectDefinition.EffectType.DISPEL
	strip.dispel_scope = EffectDefinition.DispelScope.BOTH
	combat.dispel_status_effects(caster, walker, strip)
	await get_tree().process_frame
	ok(walker.movement_class == GROUND, "dispelling it brings them down",
		Stats.movement_class_name(walker.movement_class))
	log_line("")

	log_line("======== two of them, in any order ========")
	combat.apply_effect(caster, walker, effect, SkillDatabase.skills["hover"], true)
	combat.apply_effect(caster, walker, effect, SkillDatabase.skills["hover"], true)
	await get_tree().process_frame
	ok(walker.movement_class == FLYING, "two castings still means flying")
	# Take one away by hand, the way a partial cleanse would.
	for i in walker.status_effects.size():
		if walker.status_effects[i].get("stat", "") == "movement_class":
			walker.status_effects.remove_at(i)
			break
	combat.resync_movement_class(walker)
	ok(walker.movement_class == FLYING,
		"losing one of the two leaves them in the air, as the other one says")
	walker.status_effects.clear()
	combat.resync_movement_class(walker)
	ok(walker.movement_class == GROUND, "and losing the last one sets them down")
	log_line("")

	log_line("======== and it reads properly in the panel ========")
	var tip = combat.game_ui.build_skill_tooltip(SkillDatabase.skills["hover"], caster)
	ok(tip.contains("flying"), "the preview says what it does")
	ok(tip.contains("%d turn" % effect.duration), "and for how long")
	# The HUD names the gate on its own - "Hermes" - while the glossary is where
	# it is still called the Gates of Hermes in full.
	ok(tip.contains(Stats.short_gate_name(2)), "and what it costs", Stats.short_gate_name(2))
	log_line("")

	log_line("======== Quicken does not hurt the ally it hurries ========")
	# It read deals_damage as its default of true, so a buff aimed at a friend
	# opened by hitting them for a full physical attack.
	var quicken: SkillDefinition = SkillDatabase.skills.get("quicken")
	ok(quicken != null and not quicken.deals_damage,
		"it is marked as doing no damage")
	if quicken != null:
		var before = walker.hp
		for quick_effect in quicken.all_effects():
			combat.apply_effect(caster, walker, quick_effect, quicken, true)
		await get_tree().process_frame
		ok(walker.hp == before, "and casting it leaves the ally's health alone",
			"%d -> %d" % [before, walker.hp])
	log_line("")

	log_line("======== every ally-targeting skill, while we are here ========")
	var wounding := []
	for key in SkillDatabase.skills:
		var skill: SkillDefinition = SkillDatabase.skills[key]
		if skill is ItemDefinition or not skill.targets_ally:
			continue
		# A skill that helps a friend and also hits them for a full attack is
		# almost always a resource that forgot to say deals_damage = false.
		if skill.deals_damage:
			wounding.append(skill.name)
	ok(wounding.is_empty(), "none of them wound their target", "%s" % [wounding])
	log_line("")

	game.queue_free()
	await get_tree().process_frame
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
