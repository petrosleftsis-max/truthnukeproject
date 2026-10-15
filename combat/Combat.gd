extends Node
class_name Combat

signal register_combat(combat_node: Node)
signal turn_advanced(combatant: Dictionary)
signal combatant_added(combatant: Dictionary)
signal combatant_died(combatant: Dictionary)
signal update_turn_queue(combatants: Array, turn_queue: Array)
signal update_information(text: String)
signal update_combatants(combatants: Array)
signal combat_finished()
## Someone has been studied and can now be read in full. The character sheet
## opens on them.
signal combatant_studied(combatant: Dictionary)

var combatants = []

enum Group
{
	PLAYERS,
	ENEMIES
}

enum UnitClass
{
	Melee,
	Ranged,
	Magic
}

var groups = [
	[], #players
	[]  #enemies
]

var current_combatant = 0
var combat_over = false
var last_player_skill_used = "" # Used by the Copycat AI type.
var turn = 0
var turn_queue = []

@export var game_ui : Control
@export var controller : CController
## Asks the player whether to spend a reaction when one of their combatants
## triggers. Leave unassigned and reactions fire automatically for everyone,
## which is how it behaved before.
@export var reaction_prompt: ReactionPrompt
## Optional. Used to rattle the view when something big goes off. Everything
## works without it - a battle scene with no camera assigned just doesn't
## shake.
@export var camera: CameraController
## Optional. Frames the screen in the damage colour when the player's own side
## is hurt. A battle scene without one simply does not flash its edges.
@export var hurt_vignette: HurtVignette
## Which battle this is. Assigned by GameScene before _ready runs (from the
## level select's choice, or its own fallback when game.tscn is run directly),
## so one scene plays every encounter - there is no per-encounter copy of this
## script or of game.tscn.
var encounter: EncounterDefinition = null

## Tiles the party may start on, from the encounter's side-0 spawns. Also what
## the player is allowed to rearrange across during deployment.
var deployment_tiles: Array = []
## True while the player is arranging the party, before the first turn.
var deployment_active := false



func _ready():
	emit_signal("register_combat", self)
	randomize()

	if encounter == null:
		push_error("Combat has no EncounterDefinition - GameScene assigns one before _ready. There is nothing to fight.")
		return

	# Tiles already claimed by an earlier party spawn in this encounter - the
	# enemies already placed are asked about directly (room_for). Two on one
	# tile, unless they are small ones of a side sharing it, is nobody the
	# player can click on underneath. Easy to do by mistake when typing
	# coordinates by hand, and silent until it matters, so it's caught here.
	var claimed_tiles := {}
	# A side-0 spawn is a place a party member may start, not a fixed person:
	# who actually stands there comes from the campaign roster, so recruiting
	# someone mid-story puts them in the next battle without editing every
	# encounter. Its combatant_key is kept only as a fallback for battles
	# started from the menu, which may never have loaded a map to build a
	# roster from.
	var player_tiles: Array = []
	var fallback_party: Array = []
	# The spawn each player tile came from, in the same order, so a deploying
	# party member picks up the level and gear that tile was set up with.
	var player_loadouts: Array = []
	# What a conversation in front of this fight agreed (Campaign.parley): some
	# of them staying out of it, some bought onto the party's side, all of them
	# caught off guard.
	var agreed := Campaign.take_parley()
	var staying_out: Dictionary = agreed.get("removed", {}).duplicate()
	var changing_sides: Dictionary = agreed.get("switched", {}).duplicate()
	var bought: Array = []
	for spawn in encounter.spawns:
		if not CombatantDatabase.combatants.has(spawn.combatant_key):
			push_warning("Encounter '%s' spawns unknown combatant key '%s' - skipping it." % [encounter.display_name, spawn.combatant_key])
			continue
		# A place a party member may start - unless what it spawns is a thing on
		# the map, which is nobody's whatever side its spawn was given.
		var party_spawn: bool = spawn.side == 0 and not CombatantDatabase.combatants[spawn.combatant_key] is BattleObjectDefinition
		if not party_spawn and staying_out.get(spawn.combatant_key, 0) > 0:
			staying_out[spawn.combatant_key] -= 1
			continue
		# Nobody on a tile somebody else has - save the small sharing one with
		# their own side, and for somebody bigger, on any tile of their square.
		var arriving_now = null
		if not party_spawn and spawn.arrives_on_round <= 1:
			arriving_now = create_combatant(CombatantDatabase.combatants[spawn.combatant_key], spawn.combatant_key, spawn.display_name, spawn)
			arriving_now["side"] = 1
			var clash := ""
			for tile in tiles_of(arriving_now, spawn.position):
				if claimed_tiles.has(tile):
					clash = claimed_tiles[tile]
			if clash == "" and not room_for(arriving_now, spawn.position, false):
				clash = _first_other_in(arriving_now, spawn.position).get("name", "somebody")
			if clash != "":
				push_warning("Encounter '%s' spawns '%s' on tile %s, which '%s' already occupies - skipping it. Give them their own tile." % [
					encounter.display_name, spawn.combatant_key, spawn.position, clash
				])
				continue
		elif claimed_tiles.has(spawn.position) or not get_combatant_at(spawn.position).is_empty():
			push_warning("Encounter '%s' spawns '%s' on tile %s, which '%s' already occupies - skipping it. Give them their own tile." % [
				encounter.display_name, spawn.combatant_key, spawn.position, claimed_tiles.get(spawn.position, "somebody")
			])
			continue
		if party_spawn:
			claimed_tiles[spawn.position] = spawn.combatant_key
		if not party_spawn and spawn.arrives_on_round > 1:
			# Not here yet - see _bring_in_arrivals.
			_arriving.append(spawn)
			continue
		if party_spawn:
			player_tiles.append(spawn.position)
			fallback_party.append(spawn.combatant_key)
			# Who fights comes from the roster, not from here. But a spawn
			# written for somebody is theirs, level and gear and all, if they
			# are fighting - see party_tiles_for - so nobody fights with
			# somebody else's numbers.
			player_loadouts.append(spawn)
			continue
		var enemy = arriving_now
		if spawn.surprised or agreed.get("surprised", false):
			catch_off_guard(enemy)
		add_combatant(enemy, 1, spawn.position)
		if changing_sides.get(spawn.combatant_key, 0) > 0:
			changing_sides[spawn.combatant_key] -= 1
			bought.append(enemy)

	_deploy_party(player_tiles, fallback_party, player_loadouts)
	for enemy in bought:
		switch_sides(enemy, 0, "[color=yellow]%s[/color] has been paid to fight for the party.\n" % enemy.name)
	# Something on the map to use, and the party can use it.
	_offer_interact()
	# Somebody with a price, and the party can pay it.
	_offer_bribe()
	# The ways out, for anybody who breaks and runs (see "Getting away"). None,
	# and whoever is meant to run can never get away - said, for whoever made it.
	escape_points = encounter.escape_points.filter(func(tile): return controller.is_in_bounds(tile))
	var stuck := encounter.runners_with_nowhere_to_run(CombatantDatabase.combatants)
	if not stuck.is_empty():
		push_warning("Encounter '%s' has no ways out, so %s - who run when broken - can never get away. Add ways out in the encounter editor, or set their When Broken to Surrender." % [
			encounter.display_name, ", ".join(stuck)])

	emit_signal("update_turn_queue", combatants, turn_queue)

	if turn_queue.is_empty():
		push_warning("Encounter '%s' spawned nobody at all." % encounter.display_name)
		return

	current_combatant = turn_queue[0]
	controller.set_controlled_combatant(combatants[turn_queue[0]])
	game_ui.show_combatant_status_main(combatants[turn_queue[0]])
	# Open looking at your own people. A battle that starts with the view parked
	# wherever the map happens to begin makes the first thing you do hunting for
	# yourself, and on a large map that can be most of a screen away.
	centre_on_party()
	# Let the player arrange the party across the starting tiles before anyone
	# takes a turn. Pointless with only one tile to stand on.
	if deployment_tiles.size() > 1 and groups[Group.PLAYERS].size() > 0 and not encounter.skip_deployment:
		begin_deployment()
	else:
		start_first_turn()


## Puts the campaign's fighters on the encounter's starting tiles, in marching
## order. Anyone who can't fight (see CombatantDefinition.can_fight) travels
## with the party on the map but is left out here.
func _deploy_party(tiles: Array, fallback_party: Array, loadouts: Array = []):
	if tiles.is_empty():
		push_warning("Encounter '%s' has no player starting tiles - there is nobody to play as." % encounter.display_name)
		return
	# Going straight to a battle from the menu can mean no map has ever loaded
	# and so no roster exists yet; the encounter's own player spawns stand in.
	Campaign.seed_party(fallback_party)
	var fighters = Campaign.battle_party()
	if not encounter.fighters.is_empty():
		# The encounter names who fights - a stealth map's fight, fielding
		# whoever was caught and whoever came running. Still only the living.
		fighters = []
		for key in encounter.fighters:
			if CombatantDatabase.combatants.has(key) and Campaign.is_alive(key):
				fighters.append(key)
	if fighters.size() > tiles.size():
		push_warning("Encounter '%s' has %d starting tiles but %d fighters in the party - %d sit this one out." % [
			encounter.display_name, tiles.size(), fighters.size(), fighters.size() - tiles.size()
		])
	# A battle walked into from a map keeps whatever the party was carrying when
	# they walked in. One opened straight from the menu has no such history, so
	# what each of them holds is the encounter's to say, spawn by spawn -
	# nothing listed there means empty-handed.
	var walked_in_from_a_map = Campaign.has_map_to_return_to()
	# A dungeon's fights keep what the party carried out of the last one, map
	# or no map - its last stage is gone straight into.
	if Campaign.in_dungeon():
		walked_in_from_a_map = true
	var tile_of_fighter := party_tiles_for(fighters, loadouts, tiles.size())
	for key in fighters:
		if not tile_of_fighter.has(key):
			continue
		var i: int = tile_of_fighter[key]
		var loadout = loadouts[i] if i < loadouts.size() else null
		if not walked_in_from_a_map:
			Campaign.set_inventory(key, loadout.starting_items if loadout != null else [])
		# In the story the party is the level it has reached (Campaign.reach_level),
		# whatever the fight's tiles say; from the menu, the tiles' level stands.
		var comb = create_combatant(CombatantDatabase.combatants[key], key, "", loadout,
			Campaign.party_level if walked_in_from_a_map else 0,
			Campaign.subclass_of(key) if walked_in_from_a_map else "")
		if walked_in_from_a_map:
			wear_gear(comb, key)
		Campaign.apply_carried_state(comb, key)
		# Gates opened outside the fight - for a hack's hint - stay opened.
		Campaign.take_gates_spent_outside(comb, key)
		add_combatant(comb, 0, tiles[i])
	deployment_tiles = tiles


## Which of the player tiles each of `fighters` starts on, by index: fighter
## key -> tile. A tile written for somebody - its spawn names them - is theirs,
## with the level, weapon and defence on it, whatever order the party walks
## in. Anyone without one of their own takes whichever are left, in marching
## order; anyone left over when the tiles run out sits the fight out.
##
## It went by marching order alone, once: the first to walk took the first
## tile's numbers, so the lab fight, written Alithia-Cyrus-Enfina-Prometheus
## and walked into Cyrus-Enfina-Prometheus-Alithia, gave everybody somebody
## else's defence.
static func party_tiles_for(fighters: Array, loadouts: Array, tile_count: int) -> Dictionary:
	var free: Array = range(tile_count)
	var tile_of := {}
	for key in fighters:
		for i in free:
			if i < loadouts.size() and loadouts[i] != null and loadouts[i].combatant_key == key:
				tile_of[key] = i
				free.erase(i)
				break
	for key in fighters:
		if not tile_of.has(key) and not free.is_empty():
			tile_of[key] = free.pop_front()
	return tile_of


## Hands control to the player to arrange the party before the first turn.
func begin_deployment():
	deployment_active = true
	controller.begin_deployment(deployment_tiles)
	game_ui.set_deployment_mode(true)


## Called when the player presses Begin Battle.
func finish_deployment():
	if not deployment_active:
		return
	deployment_active = false
	controller.end_deployment()
	game_ui.set_deployment_mode(false)
	start_first_turn()


## Caught off guard - ambushed on a stealth map before they knew anybody was
## there: they lose their first turn, the way a stun takes one.
const SURPRISED := preload("res://data/conditions/surprised.tres")


func catch_off_guard(comb: Dictionary):
	if immune_to_condition(comb, SURPRISED):
		return
	comb.status_effects.append({
		"stat" = "condition",
		"condition" = SURPRISED,
		"duration" = stored_duration(comb, SURPRISED),
		"ends_at_start" = SURPRISED.wears_off_at_start,
		"source_name" = "Ambush",
	})


## Sets the battle actually running. Separate from _ready because deployment
## sits in between.
func start_first_turn():
	var first: Dictionary = combatants[current_combatant]
	# The bosses on the field, brought up across the screen; the arena's first
	# round; then the opening turn begins like any other.
	for comb in combatants:
		_announce_boss(comb)
	_arena_round_begins()
	_turn_begins_for(first)
	if has_restriction(first, "skips_turn"):
		# Whoever would open the fight cannot - ambushed, most likely. Their
		# turn opens as any other does; advance_turn closes it, which is where
		# the condition comes off, so it wears off on schedule rather than
		# costing them the next round's turn too.
		start_of_turn_effects(first)
		update_information.emit("[color=red]%s[/color] is %s and loses their turn.\n" % [first.name, _why_turn_lost(first)])
		advance_turn.call_deferred()
		return
	if combatants[current_combatant].side == 1:
		# An enemy rolled the highest initiative, so the battle opens on their
		# turn - and nothing has run it. advance_turn() only drives the AI for
		# whoever it moves *to*, and nothing has called it yet, so without this
		# the game would sit forever on turn one waiting for a player who isn't
		# up. Deferred so the scene finishes coming up first.
		_start_opening_ai_turn.call_deferred()


## Runs the AI for a battle that opens on an enemy's turn. Mirrors what
## advance_turn() does when it hands off to an enemy, including the same short
## pause first so the turn is readable rather than instant.
func _start_opening_ai_turn():
	_pace_turn(combatants[current_combatant])
	watch_combatant(combatants[current_combatant])
	await get_tree().create_timer(0.6).timeout
	if not still_running():
		return
	await ai_process(combatants[current_combatant])
	stop_watching()


## `spawn` carries the level, weapon base and defense this combatant fights
## this particular encounter at - see SpawnDefinition. Null means the defaults:
## level 1, flat attributes, an ordinary weapon. `level`, when above 0, is the
## level instead of the spawn's - the party's own, in a fight walked into from
## the story - and `subclass` the path instead of the spawn's (see take_path).
func create_combatant(definition: CombatantDefinition, combatant_key: String = "", override_name = "", spawn: SpawnDefinition = null, level: int = 0, subclass: String = ""):
	# Given a level, this is somebody from the story, whose level and path are
	# their own: nothing on the spawn stands in for either.
	var from_story := level > 0
	if level <= 0:
		level = spawn.level if spawn != null else 1
	var weapon_base = spawn.weapon_base if spawn != null else Stats.WEAPON_BASE
	var stats = Stats.stats_for_level(level, definition.main_stat, definition.secondary_stat)
	# Defense is the spawn's, not the level's - it is how tough this character is
	# in this fight rather than how developed they are.
	stats["defense"] = spawn.defense if spawn != null else Stats.BASE_STAT
	var comb = {
		"name" = definition.name,
		"max_hp" = definition.hp_at(level),
		"hp" = definition.hp_at(level),
		"class" = definition.class_t,
		"alive" = true,
		"movement_class" = definition.class_m,
		# What they go back to when a Hover or the like wears off. The live one
		# above is what everything reads; this is only the floor under it.
		"base_movement_class" = definition.class_m,
		# How big they are (Sizes), and how many tiles a side they cover.
		"size" = definition.size,
		"span" = Sizes.span(definition.size, definition.gigantic_span),
		# Exactly what the database says this character knows. There used to be a
		# list per class underneath this, so being a mage granted a mage's kit and
		# the database only added to it - which meant a skill could not be taken
		# away from a character without taking it from their whole class.
		"skill_list" = definition.skills.duplicate(),
		"icon" = definition.portrait(),
		"map_sprite" = definition.map_still(),
		"sprite_frames" = definition.sprite_frames,
		"movement" = definition.movement,
		"initiative" = definition.initiative,
		"turn_taken" = false,
		"status_effects" = [], # Active timed effects: {"stat":"movement","amount":-2,"duration":2} or a DoT tick: {"stat":"dot","min_amount":2,"max_amount":4,"duration":3}
		"skill_used_this_turn" = false,
		"secondary_used_this_turn" = false,
		"reactions_suppressed" = false,
		"secondary_skills" = definition.secondary_skills.duplicate(),
		"items_as_secondary" = definition.items_as_secondary,
		# Copied off the definition so combat can look a resistance up by damage
		# type without going back to the database for it.
		"resistances" = definition.resistance_table(),
		# Physical / Mindfulness / Intellect / Self / Defense, keyed as
		# Stats.KEYS names them. Flattened onto the combatant for the same
		# reason resistances are: damage is worked out here, not in the database.
		"stats" = stats,
		"level" = level,
		"weapon_base" = weapon_base,
		# Spell slots remaining, indexed by level - [0] is unused so a skill's
		# spell_slot_level reads straight into it. Battle-scoped: a fight starts
		# with the full allowance and spends down from there.
		# What they do without being asked - see PassiveDefinition. Read through
		# active_passives rather than straight off this list, since a passive
		# whose moment has not come yet does nothing.
		"passives" = definition.passives.duplicate(),
		# Out of sight, and treated by the other side as not being there at
		# all. See the hiding section further down.
		"hidden" = false,
		"spell_slots" = definition.gates_at(level),
		"max_spell_slots" = definition.gates_at(level),
		"reaction_used" = false,
		# What an enemy has to hand in this fight, by item key - see items_of.
		# The party's own bags live on Campaign instead.
		"pocket" = _pocket_from(spawn),
		"ai_function" = definition.ai_function,
		# The side they belong to - see FactionDefinition.
		"faction" = definition.faction,
		# Which CombatantDatabase entry this came from. Campaign keys the
		# party's carried-over health off this, so it survives the combatant
		# dictionary being rebuilt from scratch for each encounter.
		"combatant_key" = combatant_key
		}
	# What can't be done to them (see "Immunities"): conditions by file, so a
	# phase can add and take away; the rest by Immunity.Kind.
	comb["immune_conditions"] = definition.immune_to_conditions.filter(func(c): return c != null).map(func(c): return c.resource_path)
	comb["immune_to"] = Array(definition.immune_to)
	# How many places in each round's order they have (see "Turns a round").
	comb["turns_per_round"] = maxi(definition.turns_per_round, 1)
	if definition.boss != null:
		# A boss (see "Bosses"): which of its phases have begun, and its bar.
		comb["boss"] = definition.boss
		comb["phase"] = 0
		comb["phase_name"] = ""
		_set_stagger_bar(comb, definition.boss.stagger)
	if definition is BattleObjectDefinition:
		# Something on the battlefield, not anybody (see "Things on the map").
		comb["object"] = definition
		# -1 for as often as you like.
		comb["uses_left"] = definition.uses if definition.uses > 0 else -1
		comb.movement = 0
		comb.initiative = 0
		comb["turns_per_round"] = 0
	# Their nerve (see "Nerve"), what they can be bought for and what the party
	# would need on them, a binding, and the parts of them that can be broken.
	comb["nerve"] = definition.nerve
	comb["keeps_codex"] = definition.keeps_codex
	comb["when_broken"] = definition.when_broken
	comb["leads"] = definition.leads
	comb["when_fled"] = definition.when_fled
	comb["back_after_rounds"] = definition.back_after_rounds
	comb["brings_back"] = definition.brings_back.duplicate()
	comb["fled_flag"] = definition.fled_flag
	comb["bribe_price"] = definition.bribe_price
	comb["leverage_clues"] = definition.leverage_clues.duplicate()
	if definition.bound_to != "":
		comb["bound_to"] = definition.bound_to
		comb["rebind_hack"] = definition.rebind_hack
		comb["rebind_turns"] = definition.rebind_turns
	if not definition.parts.is_empty():
		comb["parts"] = definition.parts.filter(func(p): return p != null)
		comb["parts_hp"] = comb.parts.map(func(p): return maxi(roundi(comb.max_hp * p.health_share), 1))
	# Kept so duplicates can be numbered off the name they share rather than off
	# a name that has already been numbered.
	comb["base_name"] = definition.name
	if override_name != "":
		comb.name = override_name
		# The author has said what to call this one, so nothing renumbers it.
		comb["named_by_author"] = true
	if subclass == "" and spawn != null and not from_story:
		subclass = spawn.subclass
	take_path(comb, subclass)
	return comb


## Puts `comb` on the path called `subclass` (SubclassDefinition), from the
## level paths open at: its skills and passives on top of their own. Each skill
## and passive still waits for its own level. Nothing for "" or below the level.
func take_path(comb: Dictionary, subclass: String):
	var path := SubclassDefinition.named(subclass) if subclass != "" else null
	if path == null or comb.get("level", 1) < Stats.SUBCLASS_LEVEL:
		return
	comb["subclass"] = subclass
	for key in path.skills:
		if SkillDatabase.skills.has(key) and not comb.skill_list.has(key):
			comb.skill_list.append(key)
	for passive in path.passives:
		if passive != null and not comb.passives.has(passive):
			comb.passives.append(passive)
	# A path can teach spells to somebody who cast none, and gates are only
	# handed to those who do.
	if comb.max_spell_slots == [0, 0, 0, 0] and _casts_anything(comb):
		comb.spell_slots = Stats.gates_for_level(comb.level)
		comb.max_spell_slots = Stats.gates_for_level(comb.level)


## Puts on `comb` what `key` has equipped (Campaign.equipped,
## EquipmentDefinition): a weapon's weapon base and armour's defence in place of
## the fight's own, and a charm's passive on top of theirs. An empty slot leaves
## the fight's number as it was. Before anything carried over is applied, so a
## weakening (apply_frailty) takes its share of the gear's numbers too.
func wear_gear(comb: Dictionary, key: String):
	var worn := []
	var weapon := EquipmentDefinition.named(Campaign.equipped_in(key, "weapon"))
	if weapon != null:
		comb.weapon_base = weapon.weapon_base
		worn.append(weapon.name)
	var armour := EquipmentDefinition.named(Campaign.equipped_in(key, "armour"))
	if armour != null:
		comb.stats["defense"] = armour.defense
		worn.append(armour.name)
	var charm := EquipmentDefinition.named(Campaign.equipped_in(key, "charm"))
	if charm != null:
		if charm.passive != null and not comb.passives.has(charm.passive):
			comb.passives.append(charm.passive)
		worn.append(charm.name)
	comb["gear"] = worn


## Whether anything `comb` knows is cast through a gate.
static func _casts_anything(comb: Dictionary) -> bool:
	for key in comb.get("skill_list", []):
		var skill: SkillDefinition = SkillDatabase.skills.get(key)
		if skill != null and skill.spell_slot_level > 0:
			return true
	return false

## Counts up forever within a battle, so an id is never reused even after a
## combatant dies and another takes their place in the array.
var _next_combatant_id := 1


## Tells apart combatants who would otherwise share a name.
##
## The first Barbarian keeps the plain name; when a second arrives they become
## "Barbarian 1" and "Barbarian 2", and so on. Anyone given a display_name on
## their spawn is left alone - that is the author saying what to call them, and
## "Striker 2" should not become "Striker 2 1".
func _number_duplicates(arrival: Dictionary):
	var base = arrival.get("base_name", arrival.name)
	if arrival.get("named_by_author", false):
		return
	var sharing := []
	for comb in combatants:
		if comb.get("named_by_author", false):
			continue
		if comb.get("base_name", comb.name) == base:
			sharing.append(comb)
	if sharing.size() < 2:
		return
	for i in sharing.size():
		sharing[i].name = "%s %d" % [base, i + 1]

func sort_turn_queue(a, b):
	if combatants[b].initiative < combatants[a].initiative:
		return true
	else:
		return false


## --- Turns a round ---
##
## The order is everybody once, by initiative (_base_queue, kept the way the
## order always was), with anybody who has more than one turn a round
## (comb.turns_per_round) put in again, spread evenly through it: a boss with two
## turns acts at its own place and again halfway round. turn_queue is that spread
## order, and the turns walk through it - the turn queue shows a face for each.

## Everybody once, by initiative.
var _base_queue: Array = []
## A change to somebody's turns a round (a boss's phase), held for the top of the
## next round, so the round under way keeps the order it started with.
var _turn_order_dirty := false


func _anybody_has_more_turns() -> bool:
	for comb in combatants:
		if comb.alive and comb.get("turns_per_round", 1) > 1:
			return true
	return false


## Rebuilds turn_queue from _base_queue, with everybody's extra turns in it.
func _spread_turn_queue():
	var n := _base_queue.size()
	var keyed := []
	for p in n:
		keyed.append([float(p), _base_queue[p]])
	for p in n:
		var index: int = _base_queue[p]
		var turns: int = combatants[index].get("turns_per_round", 1)
		for j in range(1, turns):
			# Just after whoever has that place in the round, never before them.
			keyed.append([fposmod(p + float(j) * n / turns, float(n)) + 0.5, index])
	keyed.sort_custom(func(a, b): return a[0] < b[0])
	turn_queue = keyed.map(func(pair): return pair[1])


## Changes how many turns a round `comb` gets, from the top of the next round.
func set_turns_per_round(comb: Dictionary, turns: int):
	if comb.get("turns_per_round", 1) == turns:
		return
	comb["turns_per_round"] = turns
	_turn_order_dirty = true

func add_combatant(combatant: Dictionary, side: int, position: Vector2i):
	combatant["position"] = position
	combatant["side"] = side
	# Something to be addressed by that is not their name. An encounter can field
	# three barbarians, and the HUD used to find a combatant's icon by name -
	# which meant killing one of the three could take the wrong icon off the
	# screen, or none of them.
	combatant["id"] = _next_combatant_id
	_next_combatant_id += 1
	# Read up on beforehand - a clue that says what this one is weak to
	# (ClueDefinition.reveals_combatants): the sheet open from the start, as
	# Study would leave it, though nobody has the edge Study gives its user.
	if side == 1 and Campaign.clue_reveals(combatant.get("combatant_key", "")):
		combatant["studied"] = true
	# One of a faction the party has learned about (FactionDefinition): the
	# sheet open as well, and hit harder for what is known (skill_damage).
	if side == 1 and Campaign.knows_faction(combatant.get("faction", "")):
		combatant["studied"] = true
		combatant["known_faction"] = combatant.faction
	combatants.append(combatant)
	_number_duplicates(combatant)
	# Something on the map belongs to no side: not counted for who has won, not
	# anybody's watcher or ally, never given a turn.
	if not combatant.has("object"):
		groups[side].append(combatants.size() - 1)

	var new_combatant_sprite = CombatantSprite.new()
	combatant_layer().add_child(new_combatant_sprite)
	new_combatant_sprite.position = sprite_point(combatant)
	new_combatant_sprite.z_index = 1
	var facing_flip = side == 0
	new_combatant_sprite.setup(combatant.sprite_frames, combatant.map_sprite, facing_flip)
	# Drawn to their size (Sizes.draw_scale): a quarter for Tiny, four times for
	# Enormous.
	var drawn := Sizes.draw_scale(combatant.get("size", Sizes.Size.HUMAN), combatant.get("span", 1))
	if not is_equal_approx(drawn, 1.0):
		new_combatant_sprite.scale *= drawn
	if side == 1:
		combatant["initiative"] -= 1
	combatant["sprite"] = new_combatant_sprite

	if not combatant.has("object"):
		_base_queue.append(combatants.size() - 1)
		_base_queue.sort_custom(sort_turn_queue)
		if _anybody_has_more_turns():
			_spread_turn_queue()
		else:
			# Exactly as the order has always been kept, while nobody needs more.
			turn_queue.append(combatants.size() - 1)
			turn_queue.sort_custom(sort_turn_queue)

	emit_signal("combatant_added", combatant)


func get_current_combatant():
	return combatants[current_combatant]


## --- Action slots ---
##
## Every combatant has two per turn, spent independently: a main action and a
## secondary one. A skill belongs to a slot via SkillDefinition.is_secondary,
## and a combatant can be given extra skills in their secondary slot through
## CombatantDefinition.secondary_skills - which is how Cyrus can Run twice in
## one turn, once from each slot.

## Whether `comb` has reached the level `skill` needs. Everything a combatant
## cannot use yet is left out of their panels entirely rather than shown greyed
## out - the panel is what they can do now, not a preview of later.
func meets_level_for(comb: Dictionary, skill: SkillDefinition) -> bool:
	return comb.get("level", 1) >= skill.required_level


## The skills and the consumables are listed apart now: what somebody knows how
## to do does not belong in the same list as what happens to be in their bag,
## and a party carrying four kinds of bottle buried their actual kit. See the
## Consumables tab, filled from items_of().
func main_skills_of(comb: Dictionary) -> Array:
	var found = []
	for key in comb.skill_list:
		if not SkillDatabase.skills.has(key):
			continue
		var skill: SkillDefinition = SkillDatabase.skills[key]
		# Anything with a slot cost is shown on the Spells panel instead, even
		# though it is spent from this same action - and talking somebody round
		# on the Skills tab (talk_skills_of).
		if skill.is_secondary or skill.spell_slot_level > 0 or skill.needs_leverage:
			continue
		if not meets_level_for(comb, skill):
			continue
		found.append(key)
	return found


## Skills `comb` can use as a secondary action on top of those that are one
## already: what their passives grant (Cyrus's Light Footed), and anything written on
## the combatant itself. A passive is the way to give one - the character sheet
## lists it under Passive Skills, where the player can read it; the combatant's
## own list says nothing anywhere.
func secondary_grants(comb: Dictionary) -> Array:
	var granted: Array = comb.get("secondary_skills", []).duplicate()
	for passive in active_passives(comb):
		for key in passive.secondary_skills:
			if not granted.has(key):
				granted.append(key)
	return granted


## The passive that lets `comb` use `key` as a secondary action, or null when
## nothing does or it is already one.
func secondary_grant_from(comb: Dictionary, key: String) -> PassiveDefinition:
	for passive in active_passives(comb):
		if passive.secondary_skills.has(key):
			return passive
	return null


## Whether `comb` can spend a consumable from the secondary action: a passive
## that allows it (Cyrus's Quick Hands), or the combatant's own flag.
func items_as_secondary(comb: Dictionary) -> bool:
	return items_as_secondary_from(comb) != null or comb.get("items_as_secondary", false)


func items_as_secondary_from(comb: Dictionary) -> PassiveDefinition:
	for passive in active_passives(comb):
		if passive.items_as_secondary:
			return passive
	return null


## The attribute `skill` is worked out from in `attacker`'s hands: the one the
## skill names, unless a passive of theirs moves every skill onto one of its
## own - the Mimic's Mimicry, which puts whatever it copies on its Self. Read it
## here rather than off the skill, or the passive changes nothing.
func scaling_stat_of(attacker: Dictionary, skill: SkillDefinition) -> int:
	var passive = scaling_stat_from(attacker)
	return passive.scales_every_skill_with if passive != null else skill.scaling_stat


## The passive moving every one of `comb`'s skills onto one stat, or null.
func scaling_stat_from(comb: Dictionary) -> PassiveDefinition:
	for passive in active_passives(comb):
		if passive.scales_every_skill_with >= 0:
			return passive
	return null


func secondary_skills_of(comb: Dictionary) -> Array:
	var found = []
	if has_restriction(comb, "prevents_secondary"):
		# Crystallised or Frozen - the slot exists but nothing can be spent
		# from it, so the panel comes up empty rather than offering a skill
		# that would be refused.
		return found
	for key in comb.skill_list:
		if not SkillDatabase.skills.has(key):
			continue
		var skill: SkillDefinition = SkillDatabase.skills[key]
		if skill.is_secondary and skill.spell_slot_level == 0 and meets_level_for(comb, skill):
			found.append(key)
	# A combatant's own secondary list can also grant a skill outright, so a
	# character-specific secondary doesn't have to sit in their main list too.
	for key in secondary_grants(comb):
		if not SkillDatabase.skills.has(key) or found.has(key):
			continue
		if SkillDatabase.skills[key].spell_slot_level > 0:
			continue
		if not meets_level_for(comb, SkillDatabase.skills[key]):
			continue
		found.append(key)
	return found


## Everything `comb` knows that costs a spell slot, whichever action it spends.
## Its own panel, because a caster's spell list is the part of their sheet that
## needs reading against a resource, and mixing it into the main list buries it.
func spell_skills_of(comb: Dictionary) -> Array:
	var found = []
	var offered = comb.skill_list.duplicate()
	offered.append_array(secondary_grants(comb))
	for key in offered:
		if not SkillDatabase.skills.has(key) or found.has(key):
			continue
		var skill: SkillDefinition = SkillDatabase.skills[key]
		if skill.spell_slot_level == 0:
			continue
		if not meets_level_for(comb, skill):
			continue
		if skill.is_secondary and has_restriction(comb, "prevents_secondary"):
			continue
		found.append(key)
	return found


## --- Spell slots ---
##
## Three levels, spent from a pool that lasts the battle. A skill can always be
## paid for with a slot at or above its own level, never below - so a level 3
## slot is the most flexible thing a caster has, and the most worth hoarding.


## The cheapest slot that could pay for a level `level` skill, or 0 if none can.
func slot_available_for(comb: Dictionary, level: int) -> int:
	if level <= 0:
		return 0
	var slots = comb.get("spell_slots", [])
	for candidate in range(level, slots.size()):
		if candidate < slots.size() and slots[candidate] > 0:
			return candidate
	return 0


## Whether `comb` can currently afford `skill` at all. Free skills always can.
func can_afford_skill(comb: Dictionary, skill: SkillDefinition) -> bool:
	if skill.spell_slot_level <= 0:
		return true
	if casts_without_gates(comb):
		return true
	return slot_available_for(comb, skill.spell_slot_level) > 0


## Spends the cheapest slot that covers `skill`, so a level 3 is never burned
## on a level 1 spell while a level 1 is still going spare. Returns the level
## actually spent, or 0 if the skill was free.
func spend_slot_for(comb: Dictionary, skill: SkillDefinition) -> int:
	if casts_without_gates(comb):
		# Nothing to spend and nothing to say about it - no gate was opened.
		return 0
	var level = slot_available_for(comb, skill.spell_slot_level)
	if level > 0:
		comb.spell_slots[level] -= 1
	return level


## --- Passives ---
##
## What somebody does without being asked. None of it is ever offered on a
## panel, and a passive is only consulted while its own moment holds - see
## PassiveDefinition.ActiveWhen.


## Whether `passive` is working for `comb` right now.
func passive_is_active(comb: Dictionary, passive: PassiveDefinition) -> bool:
	if passive == null or comb.get("level", 1) < passive.required_level:
		return false
	match passive.active_when:
		PassiveDefinition.ActiveWhen.ALWAYS:
			return true
		PassiveDefinition.ActiveWhen.BELOW_HALF_HEALTH:
			return comb.get("hp", 0) * 2 <= get_effective_stat(comb, "max_hp")
	return false


## What `comb`'s working passives add to `stat` (PassiveDefinition's Movement
## Bonus and Defense Bonus). Only those two: anything else is 0 straight away,
## which also keeps max_hp - which deciding whether a passive is working reads -
## from asking the passives about itself.
func passive_stat_bonus(comb: Dictionary, stat: String) -> int:
	if stat != "movement" and stat != "defense":
		return 0
	var bonus := 0
	for passive in active_passives(comb):
		bonus += passive.movement_bonus if stat == "movement" else passive.defense_bonus
	return bonus


## The passives `comb` has that are working right now.
func active_passives(comb: Dictionary) -> Array:
	var found = []
	for passive in comb.get("passives", []):
		if passive_is_active(comb, passive):
			found.append(passive)
	return found


## --- What the other side could do next turn ---
##
## The danger view: every tile an enemy could reach and hit on its next turn,
## and every tile a player standing in would provoke a reaction by leaving.
## Only enemies the player can see count - a hidden one is not there to them.


## What `enemy` could turn on the other side next turn: every skill it can use
## and afford that is not for its own side - or what the Mimic would copy, for
## somebody whose kit is whatever was last done.
func threat_skills(enemy: Dictionary) -> Array:
	var keys: Array = enemy.skill_list.duplicate()
	keys.append_array(secondary_grants(enemy))
	if enemy.get("ai_function", "") == "ai_copycat" and last_player_skill_used != "":
		keys = [last_player_skill_used]
	var found := []
	for key in keys:
		var skill: SkillDefinition = SkillDatabase.skills.get(key)
		if skill == null or skill.targets_ally or found.has(skill):
			continue
		if not can_afford_skill(enemy, skill) or not meets_level_for(enemy, skill):
			continue
		found.append(skill)
	return found


## How far `enemy` could strike once it has walked, walls aside: the longest
## reach among threat_skills, a blast's radius added on. -1 for nothing at all.
func threat_reach(enemy: Dictionary) -> int:
	var reach := -1
	for skill in threat_skills(enemy):
		var this = maxi(effective_max_range(enemy, skill), 0)
		if skill.aoe_shape == SkillDefinition.AoEShape.DIAMOND:
			this += skill.aoe_radius
		else:
			this = maxi(this, skill.aoe_radius)
		reach = maxi(reach, this)
	return reach


## {"threat": {tile: how many enemies could hit it}, "reaction": {tile: true}}
## for the side opposing `side`, as things stand.
##
## A skill that needs a clear line needs one here too, from somewhere the enemy
## could walk to - walls and bodies in the way count, by the same rule a real
## shot is judged by. Three of the sappers' enemies reach twenty tiles, and
## ignoring walls painted nearly the whole map red; on the maps with walls, most
## long lines are not clear.
func threat_map(side: int = Group.PLAYERS) -> Dictionary:
	var threat := {}
	var reaction := {}
	var sight := _SightGrid.new(controller, combatants)
	for enemy in combatants:
		if not enemy.alive or enemy.side == side or is_hidden(enemy):
			continue
		# Their turn is judged as they will be when it comes: anything set to
		# wear off as it starts, with nothing left, is left out - a Run still on
		# them from their last turn does not double this one, and a Blind about
		# to lift does not keep them close. Put back before their reactions,
		# which happen now, while it all still holds.
		var now: Array = enemy.status_effects
		var then := now.filter(func(eff): return not gone_by_their_turn(eff))
		var trimmed := then.size() != now.size()
		if trimmed:
			enemy.status_effects = then
			resync_movement_class(enemy)
		# Stunned, or caught off guard: whatever they could do, they lose the
		# turn they would do it in. Anything else still on them is still on
		# them when that turn comes round - a Blind included, which
		# effective_max_range below holds them to.
		var skills := [] if has_restriction(enemy, "skips_turn") else threat_skills(enemy)
		if not skills.is_empty():
			var standing: Array = controller.get_reachable_tiles(enemy.position, enemy.movement_class, movement_budget_of(enemy), enemy).keys()
			if not standing.has(enemy.position):
				standing.append(enemy.position)
			# Frightened, they may hold or back away but not close in, so they
			# strike only from where Fear would let them stop. Movement lost or
			# gained to a condition is already in movement_budget_of; the drift
			# Windswept blows them is not, being anybody's guess.
			if has_restriction(enemy, "prevents_approach"):
				standing = standing.filter(func(tile): return fear_allows(enemy, tile))
			var theirs := {}
			# Several skills often share a reach - the Sorcerer's three bolts all
			# go twenty tiles - and the sight lines are the expensive part.
			var aimed := {}
			sight.stand_aside(enemy)
			for skill in skills:
				var far = maxi(effective_max_range(enemy, skill), 0)
				var near = skill.min_range if skill.respects_blocking else 0
				var key = Vector3i(far, near, int(skill.respects_blocking))
				if not aimed.has(key):
					aimed[key] = _aim_points(enemy, standing, far, near, skill.respects_blocking, sight)
				var landing: Dictionary = aimed[key]
				if skill.aoe_radius > 0:
					if skill.aoe_shape == SkillDefinition.AoEShape.DIAMOND:
						landing = _spread(landing.keys(), skill.aoe_radius)
					else:
						# A line or a cone starts at the caster and runs its length.
						landing = landing.merged(_spread(standing, skill.aoe_radius))
				theirs.merge(landing)
			sight.stand_back(enemy)
			for tile in theirs:
				threat[tile] = threat.get(tile, 0) + 1
		if trimmed:
			enemy.status_effects = now
			resync_movement_class(enemy)
		if enemy.get("reaction_used", false) or has_restriction(enemy, "prevents_reactions"):
			continue
		for key in enemy.skill_list:
			var skill: SkillDefinition = SkillDatabase.skills.get(key)
			if skill == null or not skill.is_reactive:
				continue
			if not can_afford_skill(enemy, skill) or not meets_level_for(enemy, skill):
				continue
			var far = effective_max_range(enemy, skill)
			for tile in _spread([enemy.position], far):
				if get_position_distance(enemy.position, tile) < skill.min_range:
					continue
				if skill.respects_blocking and not has_line_of_sight(enemy.position, tile, enemy.movement_class):
					continue
				reaction[tile] = true
	return {"threat": threat, "reaction": reaction}


## Every tile `enemy` could aim at from somewhere in `standing`, between `near`
## and `far` steps away - with a clear line to it, when `needs_sight`.
func _aim_points(enemy: Dictionary, standing: Array, far: int, near: int, needs_sight: bool, sight: _SightGrid) -> Dictionary:
	var candidates := _spread(standing, far)
	if not needs_sight:
		return candidates
	var aims := {}
	for tile in candidates:
		if controller.terrain_blocks_sight(tile, enemy.movement_class):
			continue
		for from in standing:
			var gap = absi(from.x - tile.x) + absi(from.y - tile.y)
			if gap > far or gap < near:
				continue
			if sight.clear(from, tile, terrain_class(enemy), enemy.get("size", Sizes.Size.HUMAN)):
				aims[tile] = true
				break
	return aims


## has_line_of_sight, for asking tens of thousands of times at once: the
## same walk from the same end of the pair, stopped by the same things, read
## off a flat grid built once instead of through three lookups a step.
class _SightGrid:
	var _origin: Vector2i
	var _width := 0
	var _height := 0
	## Per movement class, built on first use: 1 where terrain stops a shot.
	var _terrain := {}
	## Where somebody the player can see is standing: their size + 1, the
	## biggest of them on a tile several share - 0 for nobody.
	var _bodies := PackedByteArray()
	var _controller

	func _init(controller, combatants: Array):
		_controller = controller
		var region: Rect2i = controller._astargrid.region
		_origin = region.position
		_width = region.size.x
		_height = region.size.y
		_bodies.resize(_width * _height)
		for comb in combatants:
			if comb.alive and not comb.get("hidden", false):
				stand_back(comb)

	## Somebody who has walked off takes their body with them, so their old
	## tile stops being cover for the lines they would shoot along.
	func stand_aside(comb: Dictionary):
		for tile in Combat.tiles_of(comb):
			_set_body(tile, 0)

	func stand_back(comb: Dictionary):
		var value: int = comb.get("size", Sizes.Size.HUMAN) + 1
		for tile in Combat.tiles_of(comb):
			var at = _index(tile)
			if at >= 0:
				_bodies[at] = maxi(_bodies[at], value)

	func _set_body(tile: Vector2i, value: int):
		var at = _index(tile)
		if at >= 0:
			_bodies[at] = value

	func _index(tile: Vector2i) -> int:
		var x = tile.x - _origin.x
		var y = tile.y - _origin.y
		if x < 0 or y < 0 or x >= _width or y >= _height:
			return -1
		return y * _width + x

	func _terrain_for(movement_class: int) -> PackedByteArray:
		if not _terrain.has(movement_class):
			var grid := PackedByteArray()
			grid.resize(_width * _height)
			for y in _height:
				for x in _width:
					if _controller.terrain_blocks_sight(_origin + Vector2i(x, y), movement_class):
						grid[y * _width + x] = 1
			_terrain[movement_class] = grid
		return _terrain[movement_class]

	func clear(from: Vector2i, to: Vector2i, movement_class: int, viewer_size: int = Sizes.Size.HUMAN) -> bool:
		# Walked from the lesser end, exactly as has_line_of_sight does.
		if to.x < from.x or (to.x == from.x and to.y < from.y):
			var swap = from
			from = to
			to = swap
		var terrain := _terrain_for(movement_class)
		var dx = absi(to.x - from.x)
		var dy = -absi(to.y - from.y)
		var sx = 1 if from.x < to.x else -1
		var sy = 1 if from.y < to.y else -1
		var err = dx + dy
		var x = from.x
		var y = from.y
		while x != to.x or y != to.y:
			var e2 = 2 * err
			if e2 >= dy:
				err += dy
				x += sx
			if e2 <= dx:
				err += dx
				y += sy
			if x == to.x and y == to.y:
				continue
			var at = (y - _origin.y) * _width + (x - _origin.x)
			# A body is cover to nobody two sizes bigger than it (CController.blocks_sight).
			if terrain[at] == 1 or (_bodies[at] > 0 and _bodies[at] - 1 > viewer_size - 2):
				return false
		return true


## Every tile on the map within `reach` steps of any of `from`. A straight
## count of steps, walls and all, the way a skill's reach is measured.
func _spread(from: Array, reach: int) -> Dictionary:
	var seen := {}
	var frontier: Array = []
	for tile in from:
		if not seen.has(tile):
			seen[tile] = 0
			frontier.append(tile)
	var steps := 0
	while steps < reach and not frontier.is_empty():
		steps += 1
		var next: Array = []
		for tile in frontier:
			for step in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
				var there = tile + step
				if seen.has(there) or not controller.is_in_bounds(there):
					continue
				seen[there] = steps
				next.append(there)
		frontier = next
	return seen


## Everything about the battle a walk could change, apart from where `walker`
## is standing: everybody's health, conditions, hiding, reactions spent, actions
## spent, gates, what has been studied, how they get about, which of their
## passives are working, and where everybody else is.
##
## A walk can be taken back only while this reads the same as it did when the
## turn began - see CController.can_undo_move. Measured rather than listed case
## by case, so a reaction set off on the way, a hidden walker spotted, a skill or
## an item used, or a passive switched on all rule it out without each having to
## be remembered here.
func board_fingerprint(walker: Dictionary) -> String:
	var parts := []
	for comb in combatants:
		var working := []
		for passive in active_passives(comb):
			working.append(passive.resource_path)
		parts.append([
			comb.get("id", -1), comb.get("alive", false), comb.get("hp", 0), comb.get("hidden", false),
			null if comb.get("id", -1) == walker.get("id", -2) else comb.get("position"),
			comb.get("status_effects", []), comb.get("reaction_used", false),
			comb.get("reactions_suppressed", false), comb.get("skill_used_this_turn", false),
			comb.get("secondary_used_this_turn", false), comb.get("spell_slots", []),
			comb.get("studied", false), comb.get("studied_by", []), comb.get("movement_class", 0),
			working,
		])
	return str(parts)


## Whether something `comb` has lets them cast through any gate without
## holding one.
func casts_without_gates(comb: Dictionary) -> bool:
	for passive in active_passives(comb):
		if passive.casts_without_gates:
			return true
	return false


## Whether `comb` still has either action available. Used to decide when a turn
## has nothing left to do and can end on its own.
##
## A spell nobody can pay for does not count as something left to do, or a
## caster out of slots would sit on a turn that can never end.
func has_action_left(comb: Dictionary) -> bool:
	var castable = []
	for key in spell_skills_of(comb):
		if can_afford_skill(comb, SkillDatabase.skills[key]):
			castable.append(key)
	if not comb.get("skill_used_this_turn", false):
		if not main_skills_of(comb).is_empty():
			return true
		for key in castable:
			if not SkillDatabase.skills[key].is_secondary:
				return true
	if not comb.get("secondary_used_this_turn", false):
		if not secondary_skills_of(comb).is_empty():
			return true
		for key in castable:
			if SkillDatabase.skills[key].is_secondary:
				return true
	return false


## --- Gate Nades ---
##
## A GateNadeDefinition is an item that casts its spell (it took the spell's
## shape when the game started): no gate opened, no level needed. But only by
## somebody who knows the spell or could learn it - it is in their own list, at
## any level, or on any of their paths (knows_or_can_learn) - so a Revitalizer
## Nade is Alithia's to throw and not Prometheus's. A passive with Any Gate Nade
## (Cyrus's Nade Juggler) throws whatever is in it. One with Gate Nades As
## Secondary (Nade Juggler again) throws them with the secondary action.

func is_gate_nade(skill) -> bool:
	return skill is GateNadeDefinition


## Whether `comb` can throw `nade`: they know its spell or could learn it, or a
## passive of theirs lets them throw any.
func can_use_gate_nade(comb: Dictionary, nade: GateNadeDefinition) -> bool:
	for passive in active_passives(comb):
		if passive.any_gate_nade:
			return true
	return knows_or_can_learn(comb, nade.spell)


## Whether `key` is a skill `comb` has, or could have: in their list now (at any
## level), in their definition's, or on any of the paths their character can
## take.
func knows_or_can_learn(comb: Dictionary, key: String) -> bool:
	if comb.get("skill_list", []).has(key) or comb.get("secondary_skills", []).has(key):
		return true
	var definition: CombatantDefinition = CombatantDatabase.combatants.get(comb.get("combatant_key", ""))
	if definition == null:
		return false
	if definition.skills.has(key) or definition.secondary_skills.has(key):
		return true
	for subclass in definition.subclasses:
		var path := SubclassDefinition.named(subclass)
		if path != null and path.skills.has(key):
			return true
	return false


## Whether a passive of `comb`'s lets them throw Gate Nades with the secondary
## action, where the spell would take the main one.
func gate_nades_as_secondary(comb: Dictionary) -> bool:
	return gate_nades_as_secondary_from(comb) != null


## The passive letting `comb` throw Gate Nades with the secondary action, or null.
func gate_nades_as_secondary_from(comb: Dictionary) -> PassiveDefinition:
	for passive in active_passives(comb):
		if passive.gate_nades_as_secondary:
			return passive
	return null

func get_distance(attacker: Dictionary, target: Dictionary):
	return rect_gap(rect_of(attacker), rect_of(target))


## Generic entry point for using ANY skill, in place of the separate function
## per attack this used to have. A new skill needs no new code here at all:
## just save it in data/skills/ and put its key - the file name - in a
## combatant's skill list.
## Targets a grid position, not a specific combatant - single-target skills
## are simply skills with aoe_radius = 0, so this one path handles both.
## Waits for attacker's skill animation (see CombatantSprite) to finish -
## locking all input for its duration - before actually resolving the hit;
## for a combatant with no skill animation this resolves on essentially the
## same frame, so nothing changes if you haven't set any up. Anywhere this
## is called with something meant to happen afterward (more movement,
## advance_turn(), etc.) must await it, or that code will run before the
## skill has actually finished.
## end_turn_after only matters for enemies (side 1): leave it true (the
## default, and what every existing call site relies on) for a skill that's
## an enemy's whole turn. AI behaviors that mean to act again afterward
## (move further, use another skill) pass false and call advance_turn()
## themselves once they're truly done.
func use_skill(skill_key: String, attacker: Dictionary, impact_position: Vector2i, end_turn_after: bool = true, as_secondary: bool = false, destination: Vector2i = Vector2i(-99999, -99999), landing: bool = false):
	# Same reason as advance_turn: an AI that was walking when the battle was
	# left comes back here to swing at somebody, on a battlefield that has
	# already been freed.
	if not still_running():
		return
	var skill: SkillDefinition = SkillDatabase.skills[skill_key]
	var distance = distance_to(attacker, impact_position)
	# Something declared lands where it was declared, wherever its user has gone
	# since - it was in reach when they called it.
	var valid = landing or (distance <= effective_max_range(attacker, skill) and distance >= skill.min_range)
	# Up on somebody (Climb), every blow on them is in reach.
	if not valid and attacker.has("riding") and not skill.targets_ally and covers(mount_of(attacker), impact_position):
		valid = true
	# Grabbed on the way and dragged back (Holding on), an enemy makes the best
	# of where it stands - the one holding it, say - rather than its turn going
	# on a swing at nothing.
	if not valid and not landing and ai_plays(attacker) and is_held(attacker) and not attacker.get("making_do", false):
		await _ai_make_do(attacker, end_turn_after, as_secondary)
		return
	if valid and not meets_level_for(attacker, skill):
		update_information.emit("[color=yellow]%s[/color] has not learned %s yet.
" % [attacker.name, skill.name])
		if ai_plays(attacker) and end_turn_after:
			await advance_turn()
		return
	if valid and not can_afford_skill(attacker, skill):
		update_information.emit("[color=yellow]%s[/color] has no %s left for %s.\n" % [
			attacker.name, Stats.short_gate_name(skill.spell_slot_level), skill.name
		])
		if ai_plays(attacker) and end_turn_after:
			await advance_turn()
		return
	# A Gate Nade in the hands of somebody who neither knows its spell nor could
	# learn it is refused, and costs nothing.
	if valid and skill is GateNadeDefinition and not can_use_gate_nade(attacker, skill):
		update_information.emit(wasted_on(attacker, skill) + "\n")
		if ai_plays(attacker) and end_turn_after:
			await advance_turn()
		return
	# Used on nothing usable (the Interact skill), it is refused and costs nothing.
	if valid and _interacts(skill) and not _usable_object_at(impact_position):
		update_information.emit("There is nothing there for [color=yellow]%s[/color] to use.\n" % attacker.name)
		return
	# Taunted and aimed elsewhere, or anything else ruling it out (refusal_for):
	# refused, and nothing spent.
	if valid and not landing:
		var refused := refusal_for(attacker, skill, impact_position)
		if refused != "":
			update_information.emit(refused + ".\n")
			if ai_plays(attacker) and end_turn_after:
				await advance_turn()
			return
	# A throw (Hurl) is its own business: who is grabbed, and where they land
	# - see "Grappling".
	if valid and skill.throws:
		await _hurl(attacker, skill, impact_position, destination, end_turn_after, as_secondary)
		return
	# Prometheus's Hack, or Using something that has to be hacked first: the
	# minigame decides it before anything else happens (see "Hacking").
	if valid and (_hacks(skill) or (_interacts(skill) and not _hack_locked_object_at(impact_position).is_empty())):
		await _hack_in_fight(attacker, skill_key, skill, impact_position, end_turn_after, as_secondary)
		return
	# Declared (SkillDefinition.declared): announced now, for nothing - it lands
	# at the start of their next turn (declare, land_declared).
	if valid and skill.declared and not landing:
		declare(attacker, skill_key, impact_position, as_secondary, destination)
		return
	if valid:
		controller.action_locked = true
		game_ui.lock_action_buttons()
		# Moved before the animation plays, so a blink-and-strike is seen landing
		# and then swinging rather than swinging and then arriving. An area skill
		# that moves its caster therefore bursts from where they end up.
		if skill.teleports == SkillDefinition.TeleportWho.CASTER and attacker.has("riding"):
			# Up on somebody: down off them, onto the tile aimed at (Climb Down).
			dismount(attacker, impact_position)
			update_information.emit("[color=yellow]%s[/color] jumps down.\n" % attacker.name)
		elif skill.teleports == SkillDefinition.TeleportWho.CASTER:
			teleport_to(attacker, impact_position)
		elif skill.teleports == SkillDefinition.TeleportWho.TARGET:
			var travelling = get_combatant_at(impact_position)
			if not travelling.is_empty() and immune_to(travelling, Immunity.Kind.TELEPORTED):
				shrug_off(travelling, Immunity.name_of(Immunity.Kind.TELEPORTED))
			elif not travelling.is_empty():
				teleport_to(travelling, destination)
		await attacker.sprite.play_skill_and_wait(skill.animation)
		# The battle was left while it played: nothing here to resolve it on.
		if not still_running():
			return
		play_skill_sound(skill)
		controller.action_locked = false
		game_ui.refresh_action_buttons()
		if not attacker.alive:
			# Something else killed them while their own skill's animation
			# was still playing - nothing left to resolve.
			return
		if attacker.side == 0 and skill.can_be_copied:
			# The Mimic copies the last thing it can: Run, Study and the like
			# leave whatever it was going to copy as it was.
			last_player_skill_used = skill_key
		# Amplified (the Demolitionist's): free, or through a deeper gate spent in
		# place of the spell's own.
		var deeper := settle_amplify(attacker, skill)
		var spent = deeper if deeper > 0 else spend_slot_for(attacker, skill)
		if deeper > 0:
			attacker.spell_slots[deeper] -= 1
		if spent > 0:
			update_information.emit("[color=yellow]%s[/color] spends %s.\n" % [attacker.name, Stats.short_gate_name(spent)])
		# The heaviest thing a caster can do should land like it. Keyed off the
		# skill's own level rather than the slot spent, so paying for a level 1
		# spell with a level 3 slot doesn't shake the map.
		if skill.spell_slot_level >= 3:
			shake_camera(LEVEL_THREE_SHAKE)
		# Decided once for the whole cast rather than per target: a blast that
		# catches three people is one spell, so it upgrades for all three and
		# spends the one charge.
		spend_element_upgrade(attacker, skill)
		# Out of whichever of their tiles is nearest, for somebody bigger than one.
		var tiles = get_impact_tiles(skill, nearest_tile_of(attacker, impact_position), impact_position, terrain_class(attacker), attacker.get("size", Sizes.Size.HUMAN))
		if landing and attacker.has("landing_tiles"):
			# Exactly the tiles marked when it was declared - what the other side
			# saw coming, and had a turn to get off.
			tiles = attacker.landing_tiles
		# Confused, they hit whoever is there, friend or foe; deceived, their own.
		var targets = get_targets_in_tiles(tiles, attacker, skill.targets_ally,
			skill.affects_both_sides or has_restriction(attacker, "confuses") or has_restriction(attacker, "turns_on_own_side"))
		if skill.targets_fallen:
			# Aimed at the fallen, it lands on nobody standing.
			targets = fallen_in_tiles(tiles, attacker)
		# One target, on a tile several small ones share: only the one picked
		# (aim_choice - whoever the pointer was over), or else the first.
		if skill.aoe_radius == 0 and skill.aoe_shape == SkillDefinition.AoEShape.DIAMOND and targets.size() > 1:
			var picked = targets.filter(func(each): return each.get("id", -1) == aim_choice)
			targets = [picked[0] if not picked.is_empty() else targets[0]]
		aim_choice = -1
		# A roll each, rather than one for the whole use. A blast landing among
		# two enemies is two chances to connect, and each is judged against that
		# enemy - so a studied bonus counts against whoever was actually studied,
		# rather than against whoever happened to be standing on the aimed tile,
		# which for something aimed at open ground is nobody at all.
		#
		# A contested skill still does not roll: it lands on everyone, in full on
		# those it beats and as a graze on those it does not.
		var connected = false
		# A quick time event on the skill, once for the whole use (see "Quick time").
		var quick := await quick_time_power(attacker, targets, skill)
		if not still_running():
			return
		for target in targets:
			if not skill.uses_stat_contest and (randi() % 100) >= hit_chance(attacker, skill, target):
				if holding_condition(skill) != null:
					update_information.emit("[color=red]%s[/color] twists out of [color=yellow]%s[/color]'s grab.\n" % [
						target.name, attacker.name])
				else:
					update_information.emit("[color=yellow]%s[/color] missed [color=red]%s[/color].\n" % [
						attacker.name, target.name])
				continue
			connected = true
			# Only the first effect on each target names the skill, so a
			# multi-effect hit reads as one action rather than repeating
			# "used Poison Dart" for every effect it carries.
			var mention_skill = true
			var grazed = skill.uses_stat_contest and not wins_contest(attacker, target, skill)
			if grazed:
				update_information.emit("[color=red]%s[/color] shrugs off the worst of %s.\n" % [target.name, skill.name])
			# Somebody warding them may take some of it off (the Abjurer's).
			var warded: float = await _offer_ward(attacker, target, skill)
			if not still_running():
				return
			# Where it was aimed, for a part of somebody big (see "Body parts").
			_aimed_tile = impact_position
			for effect in skill.all_effects():
				# Whatever the skill does to its own caster is done once,
				# below, rather than once for every person it caught.
				if effect.applies_to_caster:
					continue
				# A graze is damage only, at half strength - nothing that
				# would stick, slow, poison or shove comes with it.
				if grazed and effect.type != EffectDefinition.EffectType.DAMAGE:
					continue
				# An area skill shoves everyone caught outward from where it
				# landed, so the shape of the blast reads off the recoil.
				apply_effect(attacker, target, effect, skill, mention_skill, (0.5 if grazed else 1.0) * warded * (quick if quick_time_governs(skill, target) else 1.0), impact_position if skill.aoe_radius > 0 else attacker.position)
				mention_skill = false
			_aimed_tile = null
			if not grazed:
				_after_landing(attacker, target, skill)
		# And what the skill does to whoever used it - a swing that steadies the
		# arm that swung it. Once, however many it caught, and only because the
		# skill landed on somebody.
		if connected:
			for effect in skill.all_effects():
				if not effect.applies_to_caster or not attacker.alive:
					continue
				apply_effect(attacker, attacker, effect, skill, false)
		elif targets.is_empty():
			# Nothing was standing there to roll against in the first place.
			update_information.emit("{0} hit nothing.\n".format([attacker.name]))
		if skill.kills_caster and attacker.alive:
			update_information.emit("[color=red]{0}[/color] is consumed by its own {1}!\n".format([attacker.name, skill.name]))
			# Nothing left of them to take alive (see "Nerve").
			attacker["killed_itself"] = true
			combatant_die(attacker)
		# An amplification is spent with the cast it was for.
		attacker["amplify"] = 0
		# A step away after striking (the Swashbuckler's), for the player to
		# choose - or to stay put.
		if connected and attacker.alive and attacker.side == 0 and not has_restriction(attacker, "confuses") \
				and controller.has_method("choose_step"):
			var steps := step_tiles_after(attacker, skill)
			if not steps.is_empty():
				var to: Vector2i = await controller.choose_step(attacker, steps)
				if not still_running():
					return
				if to != attacker.position and teleport_to(attacker, to):
					update_information.emit("[color=yellow]%s[/color] steps away.\n" % attacker.name)
		if as_secondary:
			attacker.secondary_used_this_turn = true
		else:
			attacker.skill_used_this_turn = true
		# Shooting somebody means having a clear line to them, and a clear line
		# runs both ways: whoever was just shot at can see who did it. So this
		# asks, after every action, who can now be seen - which is what stops a
		# hidden archer emptying a quiver from behind a rock all fight. A skill
		# that ignores cover would slip through this, which is why Cyrus has
		# none: see his kit in the combatant database.
		reveal_anyone_now_seen()
		if skill.suppresses_reactions:
			# Only for the rest of this turn. Cleared in advance_turn alongside the
			# action slots, so it can never carry into the next one.
			attacker.reactions_suppressed = true
			update_information.emit("[color=yellow]%s[/color] moves unseen - nothing can react to them this turn.
" % attacker.name)
		# Spent here rather than at the click: an item aimed and then cancelled is
		# still in the bag, and one that missed is still gone.
		if is_item(skill_key):
			consume_item(attacker, skill_key)
		if ai_plays(attacker):
			if end_turn_after:
				await advance_turn()
			# else: the AI behavior that called this will act further and
			# end the turn itself when it's actually done.
		elif controller.movement <= 0 and not has_action_left(attacker):
			# No movement and neither action slot left - nothing more this turn
			# can do.
			await advance_turn()
		else:
			# Something's still available - stay on this combatant's turn and
			# rebuild the panel so the spent slot shows as unavailable.
			# What was just done cannot be walked back, but whatever walking
			# comes after it can: a walk back now returns to here.
			if controller.has_method("settle_undo_point"):
				controller.settle_undo_point()
			game_ui.refresh_action_buttons()
	else:
		update_information.emit("Target too far to attack.\n")
		#advance turn if its currently the enemy turn
		if ai_plays(attacker) and end_turn_after:
			await advance_turn()


## Call after `mover` takes a single movement step, from `previous_position`
## to `new_position` (both grid positions), during their OWN turn. Checks
## every other living combatant for a reactive skill whose range `mover` was
## just inside at `previous_position` but is no longer inside at
## `new_position` - i.e. they left it, whether they started inside and
## walked out, or walked in and back out again within this same move. The
## first such reactive skill each qualifying combatant has (in skill_list
## order) fires automatically, once - see SkillDefinition.is_reactive.
## Awaits each one (see use_reactive_skill), so this only returns once every
## triggered reaction has genuinely finished playing and resolving - the
## caller (CController's per-step movement handler) depends on that to know
## mover's actual alive state before deciding whether to continue moving.
func check_reactive_skills(mover: Dictionary, previous_position: Vector2i, new_position: Vector2i):
	if mover.get("reactions_suppressed", false):
		# Slipped past: leaving somebody's reach is not an opening this turn.
		return
	for reactor in combatants:
		if not reactor.alive or reactor == mover or reactor.reaction_used:
			continue
		if has_restriction(reactor, "prevents_reactions"):
			# Poisoned - too sick to seize the opening.
			continue
		if is_hidden(reactor) or is_hidden(mover):
			# Nobody strikes at what they cannot see, and nobody hidden gives
			# themselves away by striking.
			continue
		# Every reaction of theirs this move sets off - a swing, or a grab
		# (Holding on) - offered together, so the player picks which.
		var offered := []
		for skill_key in reactor.skill_list:
			var skill: SkillDefinition = SkillDatabase.skills[skill_key]
			if not skill.is_reactive:
				continue
			if not can_afford_skill(reactor, skill) or not meets_level_for(reactor, skill):
				# Out of slots for it, or not learned yet - either way there is
				# nothing to offer and nothing to ask the player about.
				continue
			var valid_side = (reactor.side == mover.side) if skill.targets_ally else (reactor.side != mover.side)
			if not valid_side:
				continue
			var distance_before = rect_gap(rect_of(reactor), rect_of(mover, previous_position))
			var distance_after = rect_gap(rect_of(reactor), rect_of(mover, new_position))
			# The reactor's reach, not the skill's: a blinded one can only see
			# the tile beside them, and use_reactive_skill checks line of sight
			# but never range, so this is the only thing standing between a
			# blinded combatant and a shot across the map.
			var reach = effective_max_range(reactor, skill)
			var was_in_range = distance_before >= skill.min_range and distance_before <= reach
			var now_in_range = distance_after >= skill.min_range and distance_after <= reach
			if not was_in_range or now_in_range:
				continue
			if skill.respects_blocking and not has_line_of_sight(reactor.position, previous_position, reactor.movement_class):
				# The shot was blocked anyway - use_reactive_skill would bail on
				# the same check, so there's nothing worth asking about.
				continue
			# Too big to get hold of, or never held (see "Grappling").
			if _grip_refusal(reactor, skill, mover) != "":
				continue
			offered.append(skill_key)
		# Passed on, the reaction stays unspent, so the next enemy to break away
		# this round asks again - but this reactor is done with *this* move.
		var chosen := await choose_reaction(reactor, mover, offered)
		if chosen == "":
			continue
		await use_reactive_skill(chosen, reactor, mover, previous_position)
		if not mover.alive:
			return
		# Grabbed on the way out: dragged back, and nobody else need bother.
		if holder_of(mover).get("id", -2) == reactor.get("id", -1):
			_drag_back(mover, reactor, previous_position)
			return


## Whether `reactor` should spend their one reaction on `mover` right now.
##
## The player is asked; enemies always say yes and take the first opportunity.
## A reaction is one per combatant between their own turns, so for the player
## it's a real decision - spending it on the first enemy to walk past is often
## the wrong call - while the AI having to weigh that up would be a whole
## behaviour of its own.
##
## Answering parks the mover mid-step, which is the same await that already
## lets a reaction's animation finish before movement carries on. The movement
## safety timeouts are told to stop counting meanwhile, so taking a while to
## decide can't be mistaken for a hung coroutine.
func confirm_reaction(reactor: Dictionary, mover: Dictionary, skill: SkillDefinition) -> bool:
	if reactor.side != 0 or reaction_prompt == null:
		return true
	# Nothing to set or clear here: CController asks the prompt directly
	# whether a question is up, so the movement timeouts can't be left
	# switched off if this await never comes back.
	var use_it = await reaction_prompt.ask(reactor, mover, skill)
	if not use_it:
		update_information.emit("[color=yellow]%s[/color] holds their reaction.\n" % reactor.name)
	return use_it


## Resolves a reactive skill use: always a single-target hit against
## `target` specifically (regardless of the skill's normal area shape - by
## the time this fires `target` has already moved on, so there's nothing
## meaningful left standing at `trigger_position` to run an area query
## against). `trigger_position` is where `target` was when they were last in
## range, used for the range/accuracy roll and any line-of-sight check.
## Waits for attacker's skill animation before resolving, same as use_skill -
## callers that need to know it's truly finished (check_reactive_skills does,
## since the mover it's reacting to shouldn't continue moving mid-animation)
## must await it.
func use_reactive_skill(skill_key: String, attacker: Dictionary, target: Dictionary, trigger_position: Vector2i):
	var skill: SkillDefinition = SkillDatabase.skills[skill_key]
	if skill.respects_blocking and not has_line_of_sight(attacker.position, trigger_position, attacker.movement_class):
		return
	attacker.reaction_used = true
	if attacker.side == 0 and skill.can_be_copied:
		last_player_skill_used = skill_key
	var spent = spend_slot_for(attacker, skill)
	if spent > 0:
		update_information.emit("[color=yellow]%s[/color] spends %s.\n" % [attacker.name, Stats.short_gate_name(spent)])
	update_information.emit("[color=yellow]{0}[/color] reacts as [color=red]{1}[/color] leaves range!\n".format([
		attacker.name,
		target.name
	]))
	controller.action_locked = true
	game_ui.lock_action_buttons()
	await attacker.sprite.play_skill_and_wait(skill.animation)
	if not still_running():
		return
	play_skill_sound(skill)
	controller.action_locked = false
	game_ui.refresh_action_buttons()
	if not attacker.alive or not target.alive:
		return
	var connected = true
	if not skill.uses_stat_contest:
		connected = (randi() % 100) < hit_chance(attacker, skill, target)
	if connected:
		var mention_skill = true
		var grazed = skill.uses_stat_contest and not wins_contest(attacker, target, skill)
		if grazed:
			update_information.emit("[color=red]%s[/color] shrugs off the worst of %s.\n" % [target.name, skill.name])
		for effect in skill.all_effects():
			if grazed and effect.type != EffectDefinition.EffectType.DAMAGE:
				continue
			apply_effect(attacker, target, effect, skill, mention_skill, 0.5 if grazed else 1.0)
			mention_skill = false
	elif holding_condition(skill) != null:
		update_information.emit("[color=red]%s[/color] twists out of [color=yellow]%s[/color]'s grab.\n" % [target.name, attacker.name])
	else:
		update_information.emit("{0} missed.\n".format([attacker.name]))


## Manhattan distance between two grid positions - the same metric the rest
## of the game (movement, range) already uses.
func get_position_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## The nearest of the 4 cardinal directions from `from` towards `to`.
## Used to aim CONE shapes.
func get_cardinal_direction(from: Vector2i, to: Vector2i) -> Vector2i:
	var delta = to - from
	if absi(delta.x) >= absi(delta.y):
		return Vector2i.RIGHT if delta.x >= 0 else Vector2i.LEFT
	else:
		return Vector2i.DOWN if delta.y >= 0 else Vector2i.UP


## The nearest of all 8 directions (4 cardinal + 4 diagonal) from `from`
## towards `to`, by actual angle - the same 8 directions AStarGrid2D lets
## combatants move in (DIAGONAL_MODE_ALWAYS). Used to aim LINE shapes and to
## find the push/pull direction for knockback effects.
func get_octant_direction(from: Vector2i, to: Vector2i) -> Vector2i:
	var delta = Vector2(to - from)
	if delta.length_squared() < 0.001:
		return Vector2i(1, 0) # aim_position == origin, arbitrary fallback direction
	const OCTANT_DIRECTIONS = [
		Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
		Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)
	]
	var index = int(round(delta.angle() / (PI / 4.0)))
	index = ((index % 8) + 8) % 8
	return OCTANT_DIRECTIONS[index]


## Every grid tile a skill's area covers, given who's casting it, where it's
## aimed, and the caster's movement class (only used when the skill respects
## blocking - see SkillDefinition.respects_blocking). This is the single
## source of truth for area shape - both the actual hit resolution
## (use_skill) and the hover preview (CController) call this, so what you
## see is always exactly what you get.
func get_impact_tiles(skill: SkillDefinition, caster_position: Vector2i, aim_position: Vector2i, movement_class: int = 0, viewer_size: int = Sizes.Size.HUMAN) -> Array:
	var tiles: Array
	match skill.aoe_shape:
		SkillDefinition.AoEShape.LINE:
			tiles = get_line_tiles(caster_position, aim_position, skill.aoe_radius, skill.aoe_width)
		SkillDefinition.AoEShape.CONE:
			tiles = get_cone_tiles(caster_position, aim_position, skill.aoe_radius)
		_:
			# DIAMOND is centred on the clicked/aimed tile, not the caster.
			tiles = get_diamond_tiles(aim_position, skill.aoe_radius)
	if skill.respects_blocking:
		# Seen from where it lands, not from whoever threw it.
		#
		# A LINE or a CONE is thrown out of the caster, so the caster's view is
		# what decides how far it gets. A blast is different: it arrives at the
		# tile aimed at and spreads from there, so what it can touch is what
		# THAT tile can see. Filtering a blast from the caster meant a bomb
		# landing round a corner still only caught what the thrower could see of
		# it, which is not how anything falling in a room behaves. Range is
		# still the caster's question - see get_range_tiles, which is where the
		# caster's own line of sight decides what may be aimed at in the first
		# place.
		var seen_from = caster_position
		if skill.aoe_shape != SkillDefinition.AoEShape.LINE \
				and skill.aoe_shape != SkillDefinition.AoEShape.CONE:
			seen_from = aim_position
		tiles = filter_tiles_by_line_of_sight(tiles, seen_from, movement_class, viewer_size)
	return tiles


## Keeps only the tiles in `tiles` that (a) aren't themselves solid to look at
## and (b) have an unobstructed straight path from `from` - i.e. nothing
## behind a wall, and no shot that has to pass through one to get there.
##
## Solid to LOOK at, not to walk on. A railing painted see-through stops a
## walker but not a shot, and a flier can be standing on it - so it stays in
## range and is drawn in reach rather than being quietly dropped from the very
## overlay that says what can be hit.
func filter_tiles_by_line_of_sight(tiles: Array, from: Vector2i, movement_class: int, viewer_size: int = Sizes.Size.HUMAN) -> Array:
	var result = []
	for tile in tiles:
		if controller.terrain_blocks_sight(tile, movement_class):
			continue
		if has_line_of_sight(from, tile, movement_class, viewer_size):
			result.append(tile)
	return result


## Whether there's a clear straight path from `from` to `to` for
## `movement_class` - no blocking tile anywhere strictly between them
## (the endpoints themselves aren't checked here; see is_tile_blocking).
func has_line_of_sight(from: Vector2i, to: Vector2i, movement_class: int, viewer_size: int = Sizes.Size.HUMAN) -> bool:
	# The same walk get_tiles_between does, without building the list.
	#
	# This is the most-called function in the game - every blast, every shot the
	# AI considers, and now every tile of the enemy's field of view drawn for a
	# hidden player - and the list it used to build was thrown away one tile
	# later. Allocating an array per call, tens of thousands of times a turn,
	# cost more than the walk itself.
	#
	# Always walked from the same end of the pair, whichever end is asking.
	#
	# The walk is not symmetric on its own. Where a line clips the corner of a
	# wall it steps one side of the corner going out and the other coming back,
	# so the two people at its ends disagreed about whether they could see each
	# other - on the laboratory map, one pair in twenty-eight. That let somebody
	# shoot from a place nobody could shoot back at, which is the hole the
	# reveal-on-acting check exists to close: a hidden archer could empty a
	# quiver past a corner and never be seen.
	#
	# Ordering the pair fixes it for nothing. Asking both ways and taking either
	# answer also works, but only 7% of lines on that map are clear, so the
	# second walk ran on nearly every question: one sweep of the enemy field of
	# view measured 421ms that way, 344ms demanding both, and 78ms like this -
	# less than the 132ms the lopsided version cost, since starting from a fixed
	# end tends to meet a wall sooner.
	#
	# What it does not do is decide corner-grazes on a principle. Whether a shot
	# past a corner connects now depends on which of the two tiles sorts first,
	# which is consistent and arbitrary. Both people get the same answer, which
	# is the part that was actually broken.
	if to.x < from.x or (to.x == from.x and to.y < from.y):
		return _walk_is_clear(to, from, movement_class, viewer_size)
	return _walk_is_clear(from, to, movement_class, viewer_size)


## One direction of the walk. has_line_of_sight is the question to ask; this is
## half of its answer, and on its own it is the asymmetry rather than the rule.
## _SightGrid.clear walks the same line for the danger view - change one, change
## both (the danger suite checks they agree).
##
## Deliberately the same arithmetic, in the same order, so it cannot disagree
## with get_tiles_between about what lies between two tiles. The blindcast
## and stealth suites check the two against each other.
func _walk_is_clear(from: Vector2i, to: Vector2i, movement_class: int, viewer_size: int = Sizes.Size.HUMAN) -> bool:
	var dx = absi(to.x - from.x)
	var dy = -absi(to.y - from.y)
	var sx = 1 if from.x < to.x else -1
	var sy = 1 if from.y < to.y else -1
	var err = dx + dy
	var x = from.x
	var y = from.y
	while x != to.x or y != to.y:
		var e2 = 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
		if x == to.x and y == to.y:
			continue
		var between := Vector2i(x, y)
		# Terrain and bodies both, in the one place that knows the whole rule.
		# Standing in front of somebody is cover, whichever side they are on -
		# and a wall painted see-through stops the step without stopping the
		# shot.
		if controller.blocks_line_of_sight(between, movement_class, viewer_size):
			return false
	return true


## Every grid tile strictly between `from` and `to` on the straight line
## connecting them (Bresenham's line algorithm), excluding both endpoints.
## Unlike aiming a LINE/CONE skill, this isn't snapped to 8 directions - it's
## the true straight-line path between the two exact points, which is what
## you want for "can I actually see them".
func get_tiles_between(from: Vector2i, to: Vector2i) -> Array:
	var tiles = []
	var dx = absi(to.x - from.x)
	var dy = -absi(to.y - from.y)
	var sx = 1 if from.x < to.x else -1
	var sy = 1 if from.y < to.y else -1
	var err = dx + dy
	var x = from.x
	var y = from.y
	while x != to.x or y != to.y:
		var e2 = 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
		if x != to.x or y != to.y:
			tiles.append(Vector2i(x, y))
	return tiles


func get_diamond_tiles(center: Vector2i, radius: int) -> Array:
	var tiles = []
	for dx in range(-radius, radius + 1):
		var remaining = radius - absi(dx)
		for dy in range(-remaining, remaining + 1):
			tiles.append(center + Vector2i(dx, dy))
	return tiles


## Every tile within a skill's min/max range of the caster, regardless of
## where (or whether) anything is standing there - shown as soon as a skill
## is selected, before aiming at anything specific.
func get_range_tiles(skill: SkillDefinition, caster_position: Vector2i, movement_class: int = 0, caster: Dictionary = {}) -> Array:
	var tiles = []
	var reach = effective_max_range(caster, skill) if not caster.is_empty() else skill.max_range
	var viewer: int = caster.get("size", Sizes.Size.HUMAN)
	if not caster.is_empty():
		movement_class = terrain_class(caster)
	# Somebody bigger than a tile reaches from every edge of their square, and
	# looks from whichever of their tiles is nearest.
	if caster.get("span", 1) > 1:
		var rect := rect_of(caster)
		for y in range(rect.position.y - reach, rect.end.y + reach):
			for x in range(rect.position.x - reach, rect.end.x + reach):
				var tile := Vector2i(x, y)
				var distance := rect_gap(rect, Rect2i(tile, Vector2i.ONE))
				if distance < skill.min_range or distance > reach:
					continue
				if skill.respects_blocking and (controller.terrain_blocks_sight(tile, movement_class) \
						or not has_line_of_sight(nearest_tile_of(caster, tile), tile, movement_class, viewer)):
					continue
				tiles.append(tile)
		return tiles
	for tile in get_diamond_tiles(caster_position, reach):
		if get_position_distance(caster_position, tile) >= skill.min_range:
			tiles.append(tile)
	if skill.respects_blocking:
		tiles = filter_tiles_by_line_of_sight(tiles, caster_position, movement_class, viewer)
	return tiles


## A straight beam of `length` tiles out from `origin` (the caster), aimed
## towards `aim_position` (any of the 8 directions, including diagonals),
## `width` tiles wide. Does not include the origin tile itself.
##
## For a cardinal direction, width spreads evenly either side of the
## centreline using the (also cardinal) perpendicular, giving a clean
## rectangle. A diagonal direction's perpendicular is itself diagonal, so
## the same approach would only touch each strip corner-to-corner and leave
## visible gaps - instead, each step widens using a diamond neighbourhood
## (the same Manhattan-radius math get_diamond_tiles uses), which stays
## solid and reads as the beam widening into a diamond cross-section.
func get_line_tiles(origin: Vector2i, aim_position: Vector2i, length: int, width: int) -> Array:
	var direction = get_octant_direction(origin, aim_position)
	var half = width / 2
	var tiles = []
	var is_diagonal = direction.x != 0 and direction.y != 0
	for step in range(1, length + 1):
		var base = origin + direction * step
		if is_diagonal:
			for tile in get_diamond_tiles(base, half):
				if not tile in tiles:
					tiles.append(tile)
		else:
			var perpendicular = Vector2i(-direction.y, direction.x)
			for offset in range(-half, width - half):
				tiles.append(base + perpendicular * offset)
	return tiles


## A wedge out from `origin` (the caster), aimed towards `aim_position`,
## reaching `length` tiles. Widens by one tile on each side per step out, so
## it always starts as a single tile right in front of the caster.
func get_cone_tiles(origin: Vector2i, aim_position: Vector2i, length: int) -> Array:
	var direction = get_cardinal_direction(origin, aim_position)
	var perpendicular = Vector2i(-direction.y, direction.x)
	var tiles = []
	for step in range(1, length + 1):
		var half_width = step - 1
		var base = origin + direction * step
		for offset in range(-half_width, half_width + 1):
			tiles.append(base + perpendicular * offset)
	return tiles


## Every living combatant standing on one of `tiles`, on the correct side
## (targets_ally decides whether that's the caster's own side or the
## opposing one).
func get_targets_in_tiles(tiles: Array, caster: Dictionary, targets_ally: bool, affects_both_sides: bool = false) -> Array:
	var result = []
	for comb in combatants:
		if not comb.alive:
			continue
		# A skill that affects both sides catches everyone standing in it -
		# that's the whole point of aiming one carefully.
		if not affects_both_sides:
			var is_ally = comb.side == caster.side
			if is_ally != targets_ally:
				continue
		# Caught by any tile of theirs, for somebody bigger than one - once.
		if comb.get("span", 1) == 1:
			if comb.position in tiles:
				result.append(comb)
		elif tiles_of(comb).any(func(tile): return tile in tiles):
			result.append(comb)
	return result


## Applies one EffectDefinition from a skill to a target. This is the single
## place to extend if you add a new EffectType later.
## Applies one effect. `skill` is what's being used, and `mention_skill` is
## true for the first effect landing on a given target, so the log reads
## "Cyrus used Poison Dart on Ranger, dealing 5 damage. Cyrus inflicted
## Poisoning on Ranger." rather than repeating the skill's name per effect.
func apply_effect(attacker: Dictionary, target: Dictionary, effect: EffectDefinition, skill: SkillDefinition = null, mention_skill: bool = false, power: float = 1.0, blast_origin = null):
	# Flagged by who sent it, not by what it does: a heal from an enemy is
	# still something the other side did to you, and reading the colour as
	# "whose doing was this" stays true for buffs, shoves and dispels alike.
	# Damage additionally shows its own type for a moment before settling into
	# the side colour, so a hit says what it was as well as who sent it.
	var damage_colour = null
	if effect.type == EffectDefinition.EffectType.DAMAGE:
		damage_colour = Damage.type_colour(effect.damage_type)
	# Not on the fallen being stood back up: a flinch on a body, and the rise
	# fighting the recoil for where it is drawn.
	if effect.type != EffectDefinition.EffectType.REVIVE and effect.type != EffectDefinition.EffectType.SUMMON_DECOY:
		flash_target(attacker, target, damage_colour, blast_origin)
	match effect.type:
		EffectDefinition.EffectType.DAMAGE:
			do_damage(attacker, target, effect, skill, mention_skill, power)
		EffectDefinition.EffectType.HEAL:
			do_heal(attacker, target, effect, skill, mention_skill)
		EffectDefinition.EffectType.STAT_MODIFIER:
			if effect.modifier_amount < 0 and immune_to(target, Immunity.Kind.WEAKENED):
				shrug_off(target, Immunity.name_of(Immunity.Kind.WEAKENED))
				return
			var movement_before = get_effective_stat(target, "movement")
			target.status_effects.append({
				"stat" = effect.stat,
				"op" = "add",
				"amount" = effect.modifier_amount,
				"duration" = stored_duration(target, effect),
				"ends_at_start" = effect.wears_off_at_start,
				"source_name" = attacker.name
			})
			if effect.stat == "movement":
				resync_live_movement(target, movement_before)
			var change_word = "weakened" if effect.modifier_amount < 0 else "strengthened"
			var fallback = "%s %s" % [change_word, effect.stat]
			update_information.emit(describe_condition(attacker, target, effect, skill, mention_skill, fallback))
			clamp_hp_to_max(target)
		EffectDefinition.EffectType.STAT_MULTIPLIER:
			if effect.stat_multiplier < 1.0 and immune_to(target, Immunity.Kind.WEAKENED):
				shrug_off(target, Immunity.name_of(Immunity.Kind.WEAKENED))
				return
			var movement_before = get_effective_stat(target, "movement")
			target.status_effects.append({
				"stat" = effect.stat,
				"op" = "multiply",
				"amount" = effect.stat_multiplier,
				"duration" = stored_duration(target, effect),
				"ends_at_start" = effect.wears_off_at_start,
				"source_name" = attacker.name
			})
			if effect.stat == "movement":
				resync_live_movement(target, movement_before)
			update_information.emit(describe_condition(attacker, target, effect, skill, mention_skill,
				"%sx %s" % [effect.stat_multiplier, effect.stat]))
			clamp_hp_to_max(target)
		EffectDefinition.EffectType.DAMAGE_OVER_TIME:
			if immune_to(target, Immunity.Kind.LINGERING_WOUNDS):
				shrug_off(target, Immunity.name_of(Immunity.Kind.LINGERING_WOUNDS))
				return
			var lingering = effective_damage_type(attacker, effect.damage_type)
			replace_matching_tick(target, "dot", null, lingering)
			target.status_effects.append({
				"stat" = "dot", # reserved pseudo-stat marking a damage-over-time tick
				"damage_type" = lingering,
				"min_amount" = effect.min_amount,
				"max_amount" = effect.max_amount,
				"dot_base" = dot_base_damage(attacker, skill, effect.damage_modifier),
				"duration" = stored_duration(target, effect),
				"ends_at_start" = effect.wears_off_at_start,
				"source_name" = attacker.name
			})
			update_information.emit(describe_condition(attacker, target, effect, skill, mention_skill, "a lingering wound"))
		EffectDefinition.EffectType.CONDITION:
			if effect.condition == null:
				push_warning("A CONDITION effect on %s has no condition assigned." % (skill.name if skill != null else "an unnamed skill"))
			elif immune_to_condition(target, effect.condition):
				shrug_off(target, effect.condition.display_name.to_lower(), true)
			else:
				var movement_before = get_effective_stat(target, "movement")
				replace_matching_tick(target, "condition", effect.condition, 0)
				target.status_effects.append({
					"stat" = "condition",
					"condition" = effect.condition,
					"dot_base" = dot_base_damage(attacker, skill, effect.condition_dot_strength()),
					"duration" = condition_turns(target, effect),
					"ends_at_start" = effect.condition.wears_off_at_start,
					"source_name" = attacker.name,
					"source_id" = attacker.get("id", -1),
				})
				if effect.condition.movement_change != 0:
					resync_live_movement(target, movement_before)
				# Grappled (Holding on): one held at a time, and a way out.
				if effect.condition.holds:
					_got_hold(attacker, target)
				# The icons hang off the portraits, and the portraits are only
				# redrawn when this goes out. Without it, a condition landing
				# mid-turn showed on nobody until the turn changed.
				update_combatants.emit(combatants)
				update_information.emit(describe_condition(attacker, target, effect, skill, mention_skill, effect.condition.display_name))
		EffectDefinition.EffectType.UPGRADE_ELEMENT:
			# Only one is worth holding: two of these would still only upgrade
			# the next spell once, and would then sit there looking like two.
			replace_matching_tick(target, "element_up", null, 0)
			target.status_effects.append({
				"stat" = "element_up",
				"duration" = stored_duration(target, effect),
				"ends_at_start" = effect.wears_off_at_start,
				"source_name" = attacker.name
			})
			update_combatants.emit(combatants)
			update_information.emit(describe_condition(attacker, target, effect, skill, mention_skill,
				"their next element raised"))
		EffectDefinition.EffectType.MOVEMENT_CLASS:
			if target != attacker and immune_to(target, Immunity.Kind.GROUNDED):
				shrug_off(target, Immunity.name_of(Immunity.Kind.GROUNDED))
				return
			target.status_effects.append({
				"stat" = "movement_class",
				"op" = "set",
				"amount" = effect.movement_class,
				"duration" = stored_duration(target, effect),
				"ends_at_start" = effect.wears_off_at_start,
				"source_name" = attacker.name
			})
			resync_movement_class(target)
			# The strip under the portrait is only redrawn when this goes out,
			# and a change to how somebody moves should show the moment it lands.
			update_combatants.emit(combatants)
			update_information.emit(describe_condition(attacker, target, effect, skill, mention_skill,
				"moving as %s" % Stats.movement_class_name(effect.movement_class).to_lower()))
		EffectDefinition.EffectType.RESISTANCE:
			if effect.modifier_amount < 0 and immune_to(target, Immunity.Kind.WEAKENED):
				shrug_off(target, Immunity.name_of(Immunity.Kind.WEAKENED))
				return
			target.status_effects.append({
				"stat" = Damage.resistance_key(effect.damage_type),
				"op" = "add",
				"amount" = effect.modifier_amount,
				"duration" = stored_duration(target, effect),
				"ends_at_start" = effect.wears_off_at_start,
				"source_name" = attacker.name
			})
			update_combatants.emit(combatants)
			var direction = "harder" if effect.modifier_amount > 0 else "easier"
			update_information.emit(describe_condition(attacker, target, effect, skill, mention_skill,
				"%s to hurt with %s" % [direction, Damage.type_name(effect.damage_type).to_lower()]))
		EffectDefinition.EffectType.HIDE:
			if alone_on_their_side(target):
				update_information.emit("[color=yellow]%s[/color] is the last one standing - there is nobody else to slip behind.
" % target.name)
			elif is_seen_by_opponents(target):
				update_information.emit("[color=yellow]%s[/color] cannot slip away while they are being watched.
" % target.name)
			else:
				set_hidden(target, true)
				update_information.emit("[color=yellow]%s[/color] slips out of sight.
" % target.name)
		EffectDefinition.EffectType.DISPEL:
			dispel_status_effects(attacker, target, effect)
		EffectDefinition.EffectType.REVIVE:
			revive(attacker, target, effect, skill)
		EffectDefinition.EffectType.STEAL:
			steal(attacker, target, effect, skill)
		EffectDefinition.EffectType.SUMMON_DECOY:
			summon_decoy(attacker, target, skill)
		EffectDefinition.EffectType.INTERACT:
			use_object(attacker, target)
		EffectDefinition.EffectType.REVEAL:
			study(attacker, target)
		EffectDefinition.EffectType.READ_INTENT:
			read_intent(attacker, target)
		EffectDefinition.EffectType.SHAKE:
			shake(attacker, target, randi_range(effect.min_amount, maxi(effect.min_amount, effect.max_amount)))
		EffectDefinition.EffectType.CLIMB:
			climb_onto(attacker, target)
		EffectDefinition.EffectType.BRIBE:
			pay_off(attacker, target)
		EffectDefinition.EffectType.BREAK_FREE:
			break_free(attacker, target)
		EffectDefinition.EffectType.PUSH:
			apply_knockback(attacker, target, effect, false, skill)
		EffectDefinition.EffectType.PULL:
			apply_knockback(attacker, target, effect, true, skill)


## --- Hiding ---
##
## Somebody hidden is somebody the other side cannot see, and the other side
## behaves accordingly - not because each AI archetype was taught a special
## case, but because the functions that look for somebody to fight stop
## returning them. An enemy that cannot see Cyrus does exactly what it would do
## if Cyrus were not on the map at all.
##
## You may only slip away out of sight, and you stay hidden until somebody can
## see you again. That is checked after every step of every move - by whoever is
## walking, whichever side they are on - because a hiding place is given away
## either by somebody coming round to look at it or by leaving it. The move is
## cut short on the step that does it: see CController._handle_step_arrival.

## A hidden ally is still drawn, faintly, so the player can see where their own
## character is standing. A hidden enemy is not drawn at all - not knowing where
## it is is the whole point of it being hidden.
const HIDDEN_ALLY_ALPHA := 0.4
const HIDDEN_ENEMY_ALPHA := 0.0


func is_hidden(comb: Dictionary) -> bool:
	return comb.get("hidden", false)


## Whether `comb` is the last one left on their side.
##
## Hiding is something you do while the enemy has somebody else to look at.
## Alone, there is nobody else for them to be looking at, so there is nowhere
## to slip to - and the fight cannot go anywhere while the only person left in
## it is one nobody can see.
func alone_on_their_side(comb: Dictionary) -> bool:
	var standing := 0
	for index in groups[comb.side]:
		if combatants[index].alive:
			standing += 1
	return standing <= 1


## Whether anybody on the far side can see `comb` from where they are standing.
func is_seen_by_opponents(comb: Dictionary) -> bool:
	var opposing = Group.PLAYERS if comb.side == Group.ENEMIES else Group.ENEMIES
	for index in groups[opposing]:
		var watcher = combatants[index]
		if not watcher.alive:
			continue
		if has_line_of_sight(watcher.position, comb.position, watcher.movement_class):
			return true
	return false


## Hides or reveals `comb`, and dresses them for it.
func set_hidden(comb: Dictionary, hidden: bool):
	if comb.get("hidden", false) == hidden:
		return
	comb["hidden"] = hidden
	dress_for_hiding(comb)
	update_combatants.emit(combatants)
	# Slipping away is a secondary action, so it can happen in the middle of
	# somebody's own turn - and the overlay showing where the enemy is looking
	# has to arrive with it rather than next turn, when the walking is over.
	if controller != null and is_instance_valid(controller) \
			and controller.has_method("refresh_watched_tiles"):
		controller.refresh_watched_tiles(get_current_combatant())
		controller.queue_redraw()


func dress_for_hiding(comb: Dictionary):
	var sprite = comb.get("sprite")
	if sprite == null or not is_instance_valid(sprite):
		return
	var alpha := 1.0
	if comb.get("hidden", false):
		alpha = HIDDEN_ALLY_ALPHA if comb.side == Group.PLAYERS else HIDDEN_ENEMY_ALPHA
	if sprite.has_method("set_hidden_alpha"):
		sprite.set_hidden_alpha(alpha)
	else:
		sprite.modulate.a = alpha


## Gives away anybody who can now be seen, and hands back who that was, so the
## caller can stop what it was doing and let it land.
func reveal_anyone_now_seen() -> Array:
	var revealed := []
	for comb in combatants:
		if not comb.alive or not comb.get("hidden", false):
			continue
		if alone_on_their_side(comb):
			# The last of their side cannot stay hidden: there is nobody else
			# for the enemy to be busy with.
			set_hidden(comb, false)
			revealed.append(comb)
			update_information.emit("[color=yellow]%s[/color] is the last one standing, and can hide no longer.
" % comb.name)
			continue
		if is_seen_by_opponents(comb):
			set_hidden(comb, false)
			revealed.append(comb)
			update_information.emit("[color=yellow]%s[/color] is spotted!
" % comb.name)
	return revealed


## --- Conditions ---
##
## Puts `comb` on whichever movement class it should be on right now: the last
## one a skill laid on it that is still running, or the one it was born with.
##
## Everything that asks how somebody gets about - pathfinding, what blocks them,
## what they can shoot past, what a tile costs them - reads comb.movement_class
## straight off the dictionary. So this keeps that single field honest rather
## than making twenty call sites remember to ask a question instead, which is
## the version of this where one of them forgets and a flying unit walks a
## grounded path.
##
## Safe to call at any time, and idempotent: it recomputes from scratch rather
## than undoing anything, so it does not care what order effects were added or
## taken away in.
func resync_movement_class(comb: Dictionary):
	var wanted = comb.get("base_movement_class", comb.get("movement_class", 0))
	for eff in comb.get("status_effects", []):
		if eff.get("stat", "") == "movement_class":
			wanted = eff.get("amount", wanted)
	comb["movement_class"] = wanted


## A condition is stored in status_effects like anything else, under the
## reserved pseudo-stat "condition", carrying the ConditionDefinition itself.
## Everything that needs to know whether someone is stunned, blinded, poisoned
## and so on asks through here, so there's one place that knows how conditions
## are stored.

## Every ConditionDefinition currently afflicting `comb`.
func conditions_of(comb: Dictionary) -> Array:
	var found: Array = []
	for eff in comb.get("status_effects", []):
		if eff.get("stat", "") == "condition" and eff.get("condition") != null:
			found.append(eff.condition)
	return found


## Whether any active condition sets the given boolean restriction - e.g.
## has_restriction(comb, "prevents_secondary").
func has_restriction(comb: Dictionary, restriction: String) -> bool:
	for condition in conditions_of(comb):
		if condition.get(restriction):
			return true
	return false


## What is costing `comb` their turn, as the log says it - "stunned", "caught
## off guard".
func _why_turn_lost(comb: Dictionary) -> String:
	for condition in conditions_of(comb):
		if condition.skips_turn:
			return condition.display_name.to_lower()
	return "stunned"


## The tightest skill-range cap any active condition imposes, or 0 for none.
## Blind caps at 1.
func condition_range_cap(comb: Dictionary) -> int:
	var cap = 0
	for condition in conditions_of(comb):
		if condition.max_range > 0 and (cap == 0 or condition.max_range < cap):
			cap = condition.max_range
	return cap


## How far `caster` can actually reach with `skill` right now - its own range,
## capped by anything blinding them. Everything that asks "is this in range",
## including the player's own range preview, goes through this so a blinded
## combatant can't be shown or offered a shot they can't take.
func effective_max_range(caster: Dictionary, skill: SkillDefinition) -> int:
	var reach := skill.max_range + range_bonus(caster, skill)
	var cap = condition_range_cap(caster)
	if cap > 0:
		return mini(reach, cap)
	return reach


## How long a freshly applied status effect should be recorded as lasting (see
## turns_stored).
##
## What is stored counts the afflicted's own turns, one coming off at the END of
## each. One landing on whoever is acting right now counts the rest of this turn
## as the first.
## `source` is whatever carries the duration - an EffectDefinition, or a
## ConditionDefinition, which keeps its own.
func stored_duration(_target: Dictionary, source) -> int:
	return turns_stored(source.duration, source.wears_off_at_start)


## The turns an effect written as lasting `duration` is stored with - which is
## how many of its bearer's turns it is on them for, the one it lands in counting
## when it lands on whoever is acting.
##
## The duration picks the turn it goes in: the one after its last, the turn it
## always used to come off at the start of. `at_start` picks which end of that
## turn. Going as it starts, it hangs on through everybody else's turns after
## its last and is gone the moment before its bearer could use it - right for
## Guard, which is for the enemies' turns. Going as it ends, it holds through
## that turn too, so whatever is on somebody is still on them when their turn
## comes round - right for anything that should never look as if it holds and
## then vanish: a Blind that seemed to keep an archer close, or a Run still
## doubling somebody who would not get to use it. Blind 3 going at the end is
## four blind turns; Stunned 2, three lost; Run 1, this turn and the next.
##
## An effect going at the start is stored with its duration and left on at
## nothing until its bearer's next turn begins (end_of_turn_effects keeps it,
## start_of_turn_effects clears it). One going at the end is stored with a turn
## more, and comes off with the last.
##
## Everything that tells the player how long something lasts asks here, so the
## numbers they read are the turns they get.
static func turns_stored(duration: int, at_start: bool) -> int:
	return duration if at_start else duration + 1


## Whether `effect`, as stored on somebody, will be gone before their next turn
## is under way: one going at the start of a turn with nothing left. The danger
## view leaves these out - they are on them now, and gone by the time it counts.
static func gone_by_their_turn(effect: Dictionary) -> bool:
	return effect.get("ends_at_start", false) and effect.get("duration", 0) <= 0


## How long the condition `effect` inflicts should last on `target`.
##
## The skill decides if it has an opinion - EffectDefinition.condition_duration
## above zero - and the condition's own duration is used otherwise. That way a
## skill can land a brief Blind or a punishing one without a second Blind
## resource existing just to hold a different number, and every skill that
## does not care keeps behaving as it always did. Which end of a turn it goes
## at is the condition's own.
##
## Counted the way stored_duration counts (turns_stored).
func condition_turns(_target: Dictionary, effect: EffectDefinition) -> int:
	return turns_stored(effect.condition_duration if effect.condition_duration > 0 else effect.condition.duration,
		effect.condition.wears_off_at_start)


## Folds a movement buff or debuff that just landed into the live movement
## counter for the combatant currently acting.
##
## controller.movement is a countdown set once at the start of the turn, so a
## change to the movement stat mid-turn has to be applied to it by hand. This
## re-derives it from the new effective stat minus whatever has already been
## walked, rather than adding a flat bonus - so two multipliers stacked in one
## turn compound properly (6 -> 12 -> 24) instead of adding the base value
## twice (6 -> 12 -> 18), and a debuff can take movement away just as well.
func resync_live_movement(target: Dictionary, effective_before: int):
	if target != get_current_combatant():
		return
	var already_walked = effective_before - controller.movement
	controller.movement = maxi(get_effective_stat(target, "movement") - already_walked, 0)


## One log line for a condition being applied. Uses the effect's own
## display_name where it has one ("Poisoning"), falling back to a description
## of what it actually does when it doesn't. Names the skill only on the first
## effect to land on this target.
func describe_condition(attacker: Dictionary, target: Dictionary, effect: EffectDefinition, skill: SkillDefinition, mention_skill: bool, fallback: String) -> String:
	var condition = effect.display_name if effect.display_name != "" else fallback
	# Whoever it landed on, in their own colour. All of these read in the enemy
	# red, so Guard steadying its own user and Quicken hurrying an ally both
	# reported as something done TO them, in the same red a poisoning wears.
	# Heals and cleanses already name an ally in green; this now matches them.
	var whom = "[color=%s]%s[/color]" % [
		"lightgreen" if target.side == attacker.side else "red", target.name]
	if mention_skill and skill != null:
		return "[color=yellow]%s[/color] used %s on %s, inflicting %s.\n" % [
			attacker.name, skill.name, whom, condition
		]
	return "[color=yellow]%s[/color] inflicted %s on %s.\n" % [
		attacker.name, condition, whom
	]


## Removes status effects from `target` matching `effect`'s dispel filters
## (see EffectDefinition.dispel_stat / dispel_scope).
## Takes off whatever the effect about to land would double up on.
##
## Two Burns are one Burn - the newer one. Stacked, the same affliction ticks
## twice a turn under a single name in the panel, and a second casting is
## quietly worth more than the first while reading as though nothing happened.
## Replacing also means the fresher caster's strength and duration are the ones
## that count, which is what "burned by them, then by yourself" should mean.
##
## Matched on identity rather than on the whole effect: the same
## ConditionDefinition for a condition, the same damage type for a nameless
## lingering wound. A Burn and a Poisoning are different afflictions and both
## stay.
func replace_matching_tick(target: Dictionary, kind: String, condition: ConditionDefinition, damage_type: int) -> int:
	var removed = 0
	var i = target.status_effects.size() - 1
	while i >= 0:
		var existing = target.status_effects[i]
		var same := false
		if kind == "condition" and existing.get("stat", "") == "condition":
			same = existing.get("condition") == condition
		elif kind == "dot" and existing.get("stat", "") == "dot":
			same = existing.get("damage_type", -1) == damage_type
		elif kind == "element_up" and existing.get("stat", "") == "element_up":
			same = true
		if same:
			target.status_effects.remove_at(i)
			removed += 1
		i -= 1
	return removed


func dispel_status_effects(attacker: Dictionary, target: Dictionary, effect: EffectDefinition):
	var removed = 0
	# From the end, so the most recently acquired goes first. That only shows
	# when dispel_count limits how many come off - a remedy that lifts one thing
	# should lift the thing that just happened.
	var i = target.status_effects.size() - 1
	var keeps_boons := immune_to(target, Immunity.Kind.BUFFS_REMOVED)
	if keeps_boons and effect.dispel_scope == EffectDefinition.DispelScope.BUFFS_ONLY:
		shrug_off(target, Immunity.name_of(Immunity.Kind.BUFFS_REMOVED))
		return
	while i >= 0:
		if effect.dispel_count > 0 and removed >= effect.dispel_count:
			break
		if should_dispel(target.status_effects[i], effect, keeps_boons):
			target.status_effects.remove_at(i)
			removed += 1
		i -= 1
	# One of the things lifted may have been what was keeping them off the floor.
	resync_movement_class(target)
	if removed > 0:
		# Same reason as applying one: the icon has to leave the portrait as
		# the cleanse lands, not when the turn happens to end.
		update_combatants.emit(combatants)
		update_information.emit("[color=yellow]{0}[/color] cleansed {1} effect(s) from [color=lightgreen]{2}[/color]\n".format([
			attacker.name,
			removed,
			target.name
		]))


func should_dispel(status_effect: Dictionary, dispel_effect: EffectDefinition, keeps_boons: bool = false) -> bool:
	if dispel_effect.dispel_stat != "" and status_effect.stat != dispel_effect.dispel_stat:
		return false
	if dispel_effect.dispel_scope == EffectDefinition.DispelScope.BOTH and not keeps_boons:
		return true
	var is_multiply = status_effect.get("op", "add") == "multiply"
	# A condition is always something done to you - there is no such thing as a
	# helpful one in this game, and every entry in res://data/conditions is an
	# affliction. It carries no `amount`, so the tests below could never see it
	# as a debuff: Cleanse, which exists to lift debuffs, could not lift a
	# single Poisoning, Burn or Crystallisation off anybody.
	var is_debuff = status_effect.stat == "dot" or status_effect.stat == "condition"
	is_debuff = is_debuff or (is_multiply and status_effect.get("amount", 1.0) < 1.0)
	is_debuff = is_debuff or (not is_multiply and status_effect.get("amount", 0) < 0)
	# Immune to having their boons taken (Immunity.Kind.BUFFS_REMOVED): only the
	# harm comes off.
	if dispel_effect.dispel_scope == EffectDefinition.DispelScope.DEBUFFS_ONLY or keeps_boons:
		return is_debuff
	return not is_debuff


## The living combatant standing on `position`, or an empty Dictionary if
## the tile is unoccupied.
func get_combatant_at(position: Vector2i) -> Dictionary:
	for comb in combatants:
		if comb.alive and covers(comb, position):
			return comb
	return {}


## --- Size and room ---
##
## Where somebody is, for somebody bigger than a tile, is the top left of the
## square they cover (comb.position), comb.span tiles a side - see Sizes. For
## anybody a tile or smaller every one of these comes to what it always did.

## The square `comb` covers, standing at `anchor` - or where they are.
static func rect_of(comb: Dictionary, anchor = null) -> Rect2i:
	var at: Vector2i = anchor if anchor != null else comb.get("position", Vector2i.ZERO)
	var span: int = comb.get("span", 1)
	return Rect2i(at, Vector2i(span, span))


## Every tile `comb` covers, standing at `anchor` - or where they are.
static func tiles_of(comb: Dictionary, anchor = null) -> Array:
	# Up on somebody (Climb), they stand on none of the ground.
	if anchor == null and comb.has("riding"):
		return []
	var rect := rect_of(comb, anchor)
	if rect.size == Vector2i.ONE:
		return [rect.position]
	var found := []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			found.append(Vector2i(x, y))
	return found


## Whether `comb` covers `tile`.
static func covers(comb: Dictionary, tile: Vector2i) -> bool:
	if comb.has("riding"):
		return false
	if comb.get("span", 1) == 1:
		return comb.get("position", Vector2i(-99999, -99999)) == tile
	return rect_of(comb).has_point(tile)


## Everybody standing on `tile` - one, or several sharing it, or nobody.
func combatants_at(tile: Vector2i) -> Array:
	return combatants.filter(func(comb): return comb.alive and covers(comb, tile))


## The tile of `comb` nearest `tile` - where a shot of theirs leaves from, and
## what a distance to them is measured to.
static func nearest_tile_of(comb: Dictionary, tile: Vector2i) -> Vector2i:
	var rect := rect_of(comb)
	return Vector2i(clampi(tile.x, rect.position.x, rect.end.x - 1), clampi(tile.y, rect.position.y, rect.end.y - 1))


## The movement class whose ground `comb` answers to - what stops them, and what
## stops their sight. Their own, save for anything Monstrous or bigger: too big
## for a map's walls to matter, it goes and sees wherever a flier could - only
## what stops a flier stops it. It still cannot walk through anybody.
static func terrain_class(comb: Dictionary) -> int:
	if comb.get("size", Sizes.Size.HUMAN) >= Sizes.Size.MONSTROUS:
		return 1
	return comb.get("movement_class", 0)


## Steps from the nearest of `comb`'s tiles to `tile`.
func distance_to(comb: Dictionary, tile: Vector2i) -> int:
	return get_position_distance(nearest_tile_of(comb, tile), tile)


## Steps between the nearest tiles of two squares - 1 for two side by side.
static func rect_gap(a: Rect2i, b: Rect2i) -> int:
	var dx := maxi(0, maxi(b.position.x - (a.end.x - 1), a.position.x - (b.end.x - 1)))
	var dy := maxi(0, maxi(b.position.y - (a.end.y - 1), a.position.y - (b.end.y - 1)))
	return dx + dy


## Whether `comb` would fit standing at `anchor`: every tile of theirs on the
## map and ground their movement class can stand on, and nobody else there -
## save, for something smaller than a tile, others of their own side as small
## with room enough left (Sizes.SPACE_IN_A_TILE).
##
## `ground` false leaves the ground out of it, asking only about others - for an
## encounter's own spawns, which its editor has already checked the ground for.
func room_for(comb: Dictionary, anchor: Vector2i, ground: bool = true) -> bool:
	var sharing := Sizes.shares(comb.get("size", Sizes.Size.HUMAN))
	for tile in tiles_of(comb, anchor):
		if ground and (not controller.is_in_bounds(tile) or controller.is_tile_blocking(tile, terrain_class(comb))):
			return false
		var used := 0
		for other in combatants_at(tile):
			if other == comb:
				continue
			if not sharing or other.side != comb.get("side", -1) or not Sizes.shares(other.get("size", Sizes.Size.HUMAN)):
				return false
			used += Sizes.share(other.size)
		if sharing and used + Sizes.share(comb.size) > Sizes.SPACE_IN_A_TILE:
			return false
	return true


## The first of anybody but `comb` on a tile `comb` would cover at `anchor`.
func _first_other_in(comb: Dictionary, anchor: Vector2i) -> Dictionary:
	for tile in tiles_of(comb, anchor):
		for other in combatants_at(tile):
			if other != comb:
				return other
	return {}


## The id of whoever a single-target skill being let go was pointed at, among
## several small ones sharing a tile - set by the controller as it lets go, and
## spent by use_skill. -1 for nobody in particular.
var aim_choice := -1


## Of everybody on `tile`, whoever is drawn nearest `point` in the world - for
## a pointer over a tile several small ones share.
func nearest_on(tile: Vector2i, point: Vector2) -> Dictionary:
	var best := {}
	var best_distance := INF
	for comb in combatants_at(tile):
		var at: Vector2 = sprite_point(comb) + drawing_offset(comb)
		var distance := at.distance_squared_to(point)
		if distance < best_distance:
			best_distance = distance
			best = comb
	return best


## Where `comb`'s sprite node stands in the world: the middle of the tile they
## are on - their anchor, for somebody bigger. Movement and sight read the node,
## so it is always there; how big they are is where the drawing goes
## (drawing_offset).
func sprite_point(comb: Dictionary, anchor = null) -> Vector2:
	return Grid.tile_to_world(anchor if anchor != null else comb.position)


## How far `comb`'s drawing sits off their node, on the map: to the middle of
## the square somebody bigger covers, or - for something smaller than a tile -
## to its own place in the tile it shares, by how many as small of its side are
## there before it.
func drawing_offset(comb: Dictionary) -> Vector2:
	var span: int = comb.get("span", 1)
	var size: int = comb.get("size", Sizes.Size.HUMAN)
	if not Sizes.shares(size):
		return Vector2(Grid.TILE_SIZE, Grid.TILE_SIZE) * 0.5 * (span - 1)
	# Laid out in a grid of as many a side as fit: two for Small, four for Tiny.
	var across := 2 if size == Sizes.Size.SMALL else 4
	var slot := 0
	for other in combatants:
		if other == comb:
			break
		if other.alive and other.position == comb.position and other.get("size", Sizes.Size.HUMAN) == size:
			slot += 1
	var cell := float(Grid.TILE_SIZE) / across
	return Vector2((slot % across) + 0.5, ((slot / across) % across) + 0.5) * cell - Vector2(Grid.TILE_SIZE, Grid.TILE_SIZE) * 0.5


## Puts every drawing of somebody bigger or smaller than a tile where
## drawing_offset says - after anybody arrives, leaves or moves.
func place_sprites():
	_carry_riders()
	for comb in combatants:
		var sprite = comb.get("sprite")
		if not comb.alive or sprite == null or not is_instance_valid(sprite):
			continue
		if comb.get("span", 1) > 1 or Sizes.shares(comb.get("size", Sizes.Size.HUMAN)):
			sprite.set_size_offset(drawing_offset(comb))


## Shoves (pulling=false) or drags (pulling=true) `target` up to
## effect.knockback_distance tiles along the straight line between attacker
## and target, stopping early at the map edge, a blocking tile, another
## combatant, or - when pulling - one tile short of the attacker (capped by
## proximity, not just an exact-tile match, since the aimed direction is
## snapped to the nearest 45° and so rarely lines up on the attacker's tile
## exactly unless they're already aligned).
##
## A PUSH (not a PULL) stopped short deals collision damage: into the map edge
## or a blocking tile it hurts whoever was shoved, and into another combatant it
## hurts them both, since a body stopping a body is a collision from either side
## of it. One impact, worked out once from whoever threw the shove, which each
## of them then soaks with their own defence and resistances - it is a single
## event, not two coincidental ones. A pull falling short never hurts anybody.
##
## How hard it lands is the same arithmetic as any other hit: the shover's stat
## and weapon behind the skill's own modifier, times the effect's
## damage_modifier so a shove can be worth a fraction of a swing. It was a flat
## min-max roll that no stat touched, which meant a stronger character shoved
## people into walls exactly as hard as a weaker one. The flat pair is still
## the fallback for a shove with no skill behind it.
func apply_knockback(attacker: Dictionary, target: Dictionary, effect: EffectDefinition, pulling: bool, skill: SkillDefinition = null):
	if target.position == attacker.position:
		return
	if immune_to(target, Immunity.Kind.SHOVED):
		shrug_off(target, Immunity.name_of(Immunity.Kind.SHOVED))
		return
	# Between the nearest tiles of the two, for anybody bigger than a tile.
	var from_tile := nearest_tile_of(attacker, target.position)
	var direction = get_octant_direction(from_tile, nearest_tile_of(target, from_tile))
	if pulling:
		direction = -direction
	var old_position = target.position
	var final_position = target.position
	var hit_obstacle = false
	## Whoever the shove ran into, if it ran into somebody rather than something.
	var bumped: Dictionary = {}
	var max_steps = effect.knockback_distance
	if pulling:
		# Chebyshev distance, since movement (and this) is 8-directional -
		# stop one tile short of the attacker rather than travelling the
		# full configured distance regardless of how close they already are.
		var chebyshev_distance = maxi(absi(target.position.x - attacker.position.x), absi(target.position.y - attacker.position.y))
		max_steps = mini(max_steps, chebyshev_distance - 1)
	for step in range(1, max_steps + 1):
		var candidate = old_position + direction * step
		# Something bigger than a tile, or smaller: every tile it would cover
		# has to fit (room_for), and what stops it is whoever is in the way
		# there, or else the ground.
		if target.get("span", 1) > 1 or Sizes.shares(target.get("size", Sizes.Size.HUMAN)):
			if room_for(target, candidate):
				final_position = candidate
				continue
			bumped = _first_other_in(target, candidate)
			hit_obstacle = bumped.is_empty()
			break
		if not controller.is_in_bounds(candidate):
			hit_obstacle = true
			break
		if controller.is_tile_blocking(candidate, target.movement_class):
			hit_obstacle = true
			break
		var occupant = get_combatant_at(candidate)
		if occupant.size() > 0:
			bumped = occupant
			break
		final_position = candidate
	if final_position != old_position:
		target.position = final_position
		target.sprite.position = sprite_point(target)
		controller.reposition_combatant(old_position, final_position)
		var distance_moved = get_position_distance(old_position, final_position)
		update_information.emit("[color=yellow]{0}[/color] {1} [color=red]{2}[/color] {3} tile(s)\n".format([
			attacker.name,
			"dragged" if pulling else "shoved",
			target.name,
			distance_moved
		]))
	# A shove loosens any grip, whether or not it moved them (Holding on).
	if not pulling or final_position != old_position:
		_break_holds_on(target)
	if pulling or effect.max_amount <= 0:
		return
	var impact = collision_impact(attacker, effect, skill)
	if hit_obstacle and target.alive:
		_take_collision_damage(attacker, target, effect, impact, "slammed into an obstacle")
	elif not bumped.is_empty() and bumped.alive:
		# Both of them, and the one still standing where they were takes it too:
		# they are what stopped the other.
		if target.alive:
			_take_collision_damage(attacker, target, effect, impact,
				"slammed into [color=red]%s[/color]" % bumped.name)
		if bumped.alive:
			_take_collision_damage(attacker, bumped, effect, impact,
				"was slammed into by [color=red]%s[/color]" % target.name)


## What a shove from `attacker` is worth before anybody soaks it.
##
## The same base figure the action panel quotes for a swing, times the effect's
## own damage_modifier, so a shove that should hurt less than a full hit says so
## on the effect rather than needing a special case here. The flat min-max range
## stands in when there is no skill behind the shove.
func collision_impact(attacker: Dictionary, effect: EffectDefinition, skill: SkillDefinition) -> int:
	if skill == null:
		return randi_range(effect.min_amount, effect.max_amount)
	return maxi(roundi(float(base_skill_damage(attacker, skill)) * effect.damage_modifier), 0)


## Applies one collision's worth of damage to `who`, resisted by them, and
## reports it. Shared by the wall case and both halves of a body-to-body one so
## the three cannot drift apart.
func _take_collision_damage(shover: Dictionary, who: Dictionary, effect: EffectDefinition, impact: int, what_happened: String):
	var shove_element = effective_damage_type(shover, effect.damage_type)
	var collision_damage = resisted_damage(who, shove_element,
		Stats.final_damage(float(impact), 1.0, stat_of(who, Stats.Type.DEFENSE)))
	lose_hp(who, collision_damage, shove_element)
	show_damage(who, collision_damage, shove_element, true)
	update_combatants.emit(combatants)
	update_information.emit("[color=red]{0}[/color] {1}, taking [color={3}]{2} damage[/color]\n".format([
		who.name,
		what_happened,
		collision_damage,
		damage_colour(shove_element)
	]))
	if who.hp <= 0:
		combatant_die(who)


## One whole turn of `comb`'s effects, start and end together: what their
## effects do to them as the turn opens, and a turn off every one as it closes.
## The battle itself calls the two halves at the two ends of a real turn; this
## is for anything that wants a turn to pass without playing one.
func process_status_effects(comb: Dictionary):
	start_of_turn_effects(comb)
	end_of_turn_effects(comb)


## What `comb`'s effects do to them as their turn opens: anything set to wear
## off at the start of a turn (turns_stored) and run down to nothing goes, and
## then damage over time ticks.
func start_of_turn_effects(comb: Dictionary):
	var i = comb.status_effects.size() - 1
	while i >= 0:
		var eff = comb.status_effects[i]
		if eff.duration <= 0:
			comb.status_effects.remove_at(i)
			i -= 1
			continue
		if eff.stat == "dot":
			tick_damage_over_time(comb, eff)
		elif eff.get("stat", "") == "condition" and eff.condition != null and (eff.condition.dot_max > 0 or eff.condition.dot_modifier > 0.0):
			tick_condition_damage(comb, eff.condition, eff.get("dot_base", 0.0))
		i -= 1
	resync_movement_class(comb)
	clamp_hp_to_max(comb)


## Takes a turn off every effect on `comb` as their turn closes, and drops any
## that have run out - skipped turns included, since a turn lost is still a
## turn spent.
##
## Something set to wear off at the start of a turn is kept at nothing instead,
## on through everybody else's turns, for start_of_turn_effects to clear as
## their next one opens. Everything else goes here, the moment its last turn
## is over, so nothing lingers looking as though it will hold for a turn it
## will not see.
func end_of_turn_effects(comb: Dictionary):
	var i = comb.status_effects.size() - 1
	while i >= 0:
		var eff = comb.status_effects[i]
		eff.duration -= 1
		if eff.duration <= 0 and not eff.get("ends_at_start", false):
			comb.status_effects.remove_at(i)
		i -= 1
	# Anything that just expired may have been holding them in the air.
	resync_movement_class(comb)
	clamp_hp_to_max(comb)


## How many more times a damage-over-time effect on `comb` will tick. Its
## duration, less the turn they are in the middle of, if they are: that turn's
## tick has already happened, or never will for something that landed after
## it, but the turn still counts until it ends.
func ticks_left(comb: Dictionary, effect: Dictionary) -> int:
	var turns: int = effect.get("duration", 0)
	if comb == get_current_combatant():
		turns -= 1
	return maxi(turns, 0)


## Burns a turn's worth of damage off someone suffering a condition that deals
## it. Same shape as tick_damage_over_time, but named by the condition so the
## log says what is actually hurting them.
## One tick of a lingering effect, before resistance. Uses the snapshot taken
## when it landed if there is one, and the flat range if there is not - which is
## how an item's version of a condition, and anything with no skill at all
## behind it, does its damage.
func dot_tick(target: Dictionary, dot_base: float, flat_min: int, flat_max: int) -> int:
	if dot_base > 0.0:
		return Stats.final_damage(dot_base, 1.0, stat_of(target, Stats.Type.DEFENSE))
	return randi_range(flat_min, flat_max)


func tick_condition_damage(comb: Dictionary, condition: ConditionDefinition, dot_base: float = 0.0):
	if not comb.alive:
		return
	var resistance = resistance_of(comb, condition.dot_type)
	var amount = resisted_damage(comb, condition.dot_type, dot_tick(comb, dot_base, condition.dot_min, condition.dot_max))
	lose_hp(comb, amount, condition.dot_type)
	show_damage(comb, amount, condition.dot_type, true)
	update_combatants.emit(combatants)
	update_information.emit("[color=red]%s[/color] took [color=%s]%d %s damage%s[/color] from %s.\n" % [
		comb.name, damage_colour(condition.dot_type), amount,
		Damage.type_name(condition.dot_type).to_lower(),
		Damage.describe_resistance(resistance), condition.display_name
	])
	if comb.hp <= 0:
		combatant_die(comb)


func tick_damage_over_time(comb: Dictionary, eff: Dictionary):
	if not comb.alive:
		return
	var type = eff.get("damage_type", Damage.Type.PHYSICAL)
	var resistance = resistance_of(comb, type)
	var amount = resisted_damage(comb, type, dot_tick(comb, eff.get("dot_base", 0.0), eff.min_amount, eff.max_amount))
	lose_hp(comb, amount, type)
	show_damage(comb, amount, type, true)
	update_combatants.emit(combatants)
	update_information.emit("[color=red]%s[/color] took [color=%s]%d %s damage%s[/color] from a lingering effect (%s).\n" % [
		comb.name, damage_colour(type), amount, Damage.type_name(type).to_lower(),
		Damage.describe_resistance(resistance), eff.get("source_name", "unknown")
	])
	if comb.hp <= 0:
		combatant_die(comb)


## Clamps hp down if it's currently above the combatant's effective max_hp -
## e.g. after a max_hp debuff, or once a temporary max_hp buff wears off.
func clamp_hp_to_max(comb: Dictionary):
	var effective_max = get_effective_stat(comb, "max_hp")
	if comb.hp > effective_max:
		comb.hp = effective_max
		update_combatants.emit(combatants)


## A combatant's base stat (e.g. "movement") plus whatever active status
## effects are currently modifying it. Use this instead of reading the base
## stat directly anywhere gameplay-relevant values are needed. Not clamped
## here - a negative accuracy modifier, for instance, should stay negative
## so it can reduce a hit-chance roll; callers that need a stat clamped to a
## sane range (e.g. movement never going below 0) should clamp themselves.
func get_effective_stat(comb: Dictionary, stat: String) -> int:
	# Rooted is rooted: anything raising movement - Run doubling it, Quicken
	# adding to it - has nothing to work on. Here rather than only where a turn
	# starts, because a buff landing mid-turn works out its share from this
	# number: Run on a Crystallised Striker read "5 before, none left, so 5
	# walked", doubled the 5 and handed the 5 "unwalked" back.
	if stat == "movement" and has_restriction(comb, "prevents_movement"):
		return 0
	return fold_stat_changes(comb, stat, comb.get(stat, 0))


## `value` with everything currently raising or lowering `stat` folded into it.
##
## Split out because a combatant keeps its numbers in two places: hp, movement
## and the like sit at the top level, while the five attributes live under
## "stats" - and a buff applies to either in exactly the same way. Two callers
## that know where a base value lives, one that knows what a buff does to it.
func fold_stat_changes(comb: Dictionary, stat: String, value: int) -> int:
	var additive = passive_stat_bonus(comb, stat)
	var multiplier = 1.0
	for eff in comb.status_effects:
		if eff.get("stat", "") == "condition":
			# Conditions carry their stat changes on the definition rather than
			# as amount/op, so they're folded in here rather than matched by
			# stat name like an ordinary modifier.
			var condition = eff.get("condition")
			if condition == null:
				continue
			if stat == "movement":
				additive += condition.movement_change
			elif stat == "accuracy":
				additive += condition.accuracy_change
			continue
		if eff.stat != stat:
			continue
		if eff.get("op", "add") == "multiply":
			multiplier *= eff.amount
		else:
			additive += eff.amount
	return roundi((value + additive) * multiplier)


func set_next_combatant():
	turn += 1
	if turn >= turn_queue.size():
		for comb in combatants:
			comb.turn_taken = false
		turn = 0
		round_number += 1
		# At the top of the round, before anybody moves, so newcomers take
		# their place in the order rather than cutting into a round already
		# under way.
		_bring_back_the_fled()
		_bring_in_arrivals()
		if _turn_order_dirty:
			# A phase changed somebody's turns a round; the new round has them.
			_turn_order_dirty = false
			_spread_turn_queue()
			update_turn_queue.emit(combatants, turn_queue)
		_drain_stagger_bars()
		_arena_round_begins()
	current_combatant = turn_queue[turn]


## --- Arriving late ---
##
## An enemy spawn with arrives_on_round above 1 is held back until the top of
## that round, then put on its tile - or the nearest free one - and into the
## turn order.

## Which round the fight is in: 1 until everybody has had a turn.
var round_number := 1
## Spawns still to come, in the order the encounter lists them.
var _arriving: Array = []


## Whoever's round has come, brought in.
func _bring_in_arrivals():
	var still_coming: Array = []
	var came := false
	for spawn in _arriving:
		if spawn.arrives_on_round > round_number:
			still_coming.append(spawn)
			continue
		var definition: CombatantDefinition = CombatantDatabase.combatants[spawn.combatant_key]
		var arrival = create_combatant(definition, spawn.combatant_key, spawn.display_name, spawn)
		arrival["side"] = 1
		var tile = _free_tile_for(arrival, spawn.position)
		if tile.x == -99999:
			# Nowhere to put them this round; try again at the next.
			still_coming.append(spawn)
			continue
		add_combatant(arrival, 1, tile)
		update_information.emit("[color=red]%s[/color] joins the fight.\n" % combatants.back().name)
		# A boss arriving late is announced as it comes.
		_announce_boss(combatants.back())
		if combatants.back().has("object"):
			_offer_interact()
		came = true
	_arriving = still_coming
	if came:
		emit_signal("update_turn_queue", combatants, turn_queue)
		emit_signal("update_combatants", combatants)


## Spawns still waiting to arrive, and the round each comes on.
func arriving() -> Array:
	return _arriving


## The free tile nearest `wanted` that something moving by `movement_class`
## can stand on, or (-99999, -99999) for none within a few steps.
func _free_tile_for(arrival: Dictionary, wanted: Vector2i) -> Vector2i:
	var frontier := [wanted]
	var visited := {wanted: true}
	while not frontier.is_empty() and visited.size() < 200:
		var tile: Vector2i = frontier.pop_front()
		# Room for all of them, for somebody bigger or smaller than a tile.
		if room_for(arrival, tile):
			return tile
		for step in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var next: Vector2i = tile + step
			if not visited.has(next):
				visited[next] = true
				frontier.append(next)
	return Vector2i(-99999, -99999)


## Ends the current combatant's turn and hands off to whoever's next -
## skipping anyone already dead, and running combat_finish() instead if one
## side has been wiped out. If the next combatant is an enemy, this awaits
## their entire AI turn (via ai_process) before returning - previously it
## didn't, which meant whoever called advance_turn() would carry on
## immediately while that AI turn kept running in the background, sharing
## the same CController state (position, path, etc.) that a *subsequent*
## turn would then also start touching concurrently. Every call site of
## advance_turn() - including each AI archetype's own final call, ending
## its own turn - must await it for this chain to actually hold; skipping
## await anywhere reopens the same race.
func advance_turn():
	# The fight may have been walked out of while somebody was mid-move. The
	# enemy's turn is a coroutine several awaits deep, and the scene it stands
	# on is freed the moment the title screen is asked for - but ai_move returns
	# cleanly rather than vanishing, so the chain unwinds back to here and asks
	# a Combat that is no longer in the tree for a timer. There is no turn to
	# advance once the battle is gone.
	if not still_running():
		return
	var ending: Dictionary = combatants[current_combatant]
	ending.turn_taken = true
	if ending.alive:
		end_of_turn_effects(ending)
		_turncoat_turn_ends(ending)
		if not still_running() or combat_over:
			return
	set_next_combatant()
	var comb = combatants[current_combatant]
	# A grip nobody is keeping any more is gone before anybody acts on it.
	check_holds()
	while true:
		if groups[Group.PLAYERS].size() < 1 or groups[Group.ENEMIES].size() < 1:
			# Combat is already over - make sure combat_finish() has actually
			# run (it's idempotent, so this is safe even if it already has),
			# then stop advancing turns rather than loop forever looking for
			# a living combatant that no longer exists.
			combat_finish()
			return
		# An image (the Illusionist's) takes no turns: it only stands there.
		if not comb.alive or comb.get("illusion", false):
			set_next_combatant()
			comb = combatants[current_combatant]
			continue
		comb.skill_used_this_turn = false
		comb.secondary_used_this_turn = false
		comb.reaction_used = false
		comb.reactions_suppressed = false
		comb.erase("movement_left_when_grabbed")
		start_of_turn_effects(comb)
		# A turn of theirs begun (for what the other side has declared), an aura
		# they are standing in, the ground they are standing on.
		_turn_begins_for(comb)
		if not comb.alive:
			# A damage-over-time tick (or similar) killed them just as their
			# turn was starting - skip straight to whoever's next.
			set_next_combatant()
			comb = combatants[current_combatant]
			continue
		if has_restriction(comb, "skips_turn"):
			# Stunned. The turn is lost but still spent: it ends here, and the
			# condition comes off with it, so it wears off on schedule.
			update_information.emit("[color=red]%s[/color] is %s and loses their turn.\n" % [comb.name, _why_turn_lost(comb)])
			# Whatever they declared went with the turn.
			drop_declared(comb, _why_turn_lost(comb))
			comb.erase("intent")
			end_of_turn_effects(comb)
			set_next_combatant()
			comb = combatants[current_combatant]
			continue
		break
	_pace_turn(comb)
	apply_drift(comb)
	emit_signal("turn_advanced", comb)
	emit_signal("update_combatants", combatants)
	if comb.alive and has_restriction(comb, "confuses"):
		# Confused, whichever side: the turn is played for them - and what they
		# declared is lost with it.
		drop_declared(comb, "confused")
		comb.erase("intent")
		if comb.side == 0:
			controller.player_turn = false
		watch_combatant(comb)
		await get_tree().create_timer(0.6).timeout
		if not still_running():
			return
		await ai_confused(comb)
		stop_watching()
		return
	if comb.alive and has_restriction(comb, "turns_on_own_side"):
		# Deceived (Deceive), whichever side: played for them, at their own.
		drop_declared(comb, "deceived")
		comb.erase("intent")
		if comb.side == 0:
			controller.player_turn = false
		watch_combatant(comb)
		await get_tree().create_timer(0.6).timeout
		if not still_running():
			return
		await ai_deceived(comb)
		stop_watching()
		return
	# What they declared lands now, spending this turn's action - once every one
	# of the other side has had a turn to get out of the way (declared_due).
	if comb.has("declared") and declared_due(comb):
		if ai_plays(comb):
			watch_combatant(comb)
			await get_tree().create_timer(0.6).timeout
			if not still_running():
				return
		await land_declared(comb)
		if not still_running():
			return
		if not comb.alive:
			await advance_turn()
			return
	if ai_plays(comb):
		# Look at them before they act, so the pause below is the view travelling
		# rather than dead air.
		watch_combatant(comb)
		await get_tree().create_timer(0.6).timeout
		if not still_running():
			# The fight was left during the pause before this enemy acted.
			return
		await ai_process(comb)
		stop_watching()


## Blows a windswept combatant across the map at the start of their turn.
##
## This is not their own movement: it costs none of their budget and provokes
## no reactive skills, because they aren't choosing to go anywhere. It stops
## early at a wall, the map edge or another combatant, the same way a push
## does.
func apply_drift(comb: Dictionary):
	if not comb.alive:
		return
	var tiles = 0
	for condition in conditions_of(comb):
		tiles = maxi(tiles, condition.drift_tiles)
	if tiles <= 0:
		return
	const DIRECTIONS = [
		Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN,
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
	]
	# Somewhere it can actually take them. Picking one of the eight at random
	# and giving up when that way happened to be a wall meant the wind did
	# nothing at all most of the time in a room - which reads as the condition
	# being broken rather than as the body being braced against something.
	var options := DIRECTIONS.duplicate()
	options.shuffle()
	var direction = Vector2i.ZERO
	for candidate in options:
		var first_step = comb.position + candidate
		if not controller.is_in_bounds(first_step):
			continue
		if controller.is_tile_blocking(first_step, comb.movement_class):
			continue
		if not get_combatant_at(first_step).is_empty():
			continue
		direction = candidate
		break
	if direction == Vector2i.ZERO:
		# Hemmed in on all eight sides. Nowhere for the wind to put them.
		return
	var from = comb.position
	var landed = from
	for step in range(1, tiles + 1):
		var candidate = from + direction * step
		if not can_land_on(comb, candidate):
			break
		landed = candidate
	if landed == from:
		return
	comb.position = landed
	comb.sprite.position = sprite_point(comb)
	controller.reposition_combatant(from, landed)
	update_information.emit("[color=red]%s[/color] is blown %d tile(s) off course.\n" % [
		comb.name, get_position_distance(from, landed)
	])
	_break_holds_on(comb)


## Plays an enemy's turn at the speed the player asked for in Options, and a
## player's own at normal speed. See GameSettings.ENEMY_SPEEDS.
func _pace_turn(comb: Dictionary):
	_turn_scale = GameSettings.enemy_time_scale() if comb.get("side", 0) == 1 else 1.0
	if _hit_stop_depth == 0:
		Engine.time_scale = _turn_scale

## The time scale the current turn runs at, for a hit-stop to come back to.
var _turn_scale := 1.0


func combat_finish():
	# Whatever comes after the fight - the log, the result, the map - at normal speed.
	_turn_scale = 1.0
	if _hit_stop_depth == 0:
		Engine.time_scale = 1.0
	if combat_over:
		return
	combat_over = true
	var enemies_alive = groups[Group.ENEMIES].size() > 0
	var players_alive = groups[Group.PLAYERS].size() > 0
	if lost_because != "":
		# Somebody who must not get away got away (see "Getting away").
		update_information.emit("[color=red]Defeat! %s.[/color]\n" % lost_because)
	elif not players_alive and not enemies_alive:
		update_information.emit("[color=yellow]Draw - both sides have fallen.[/color]\n")
	elif not enemies_alive:
		update_information.emit("[color=lightgreen]Victory! All enemies have been defeated.[/color]\n")
	else:
		update_information.emit("[color=red]Defeat! Your party has fallen.[/color]\n")
	controller.player_turn = false
	game_ui.set_skill_list([], true)
	# Hand the party's condition back to the campaign before anything unloads
	# this scene - damage taken here is what they carry into the next battle.
	Campaign.record_party(combatants)
	# And how it went, for the conversation after it (Campaign "The last fight").
	Campaign.record_last_fight(combatants)
	emit_signal("combat_finished")


## How much `type` damage `target` actually takes from a raw `amount`, after
## their own resistance to it. The single place resistances are applied, so a
## direct hit, a damage-over-time tick, a condition burning away and a shove
## into a wall are all treated the same way.
func resisted_damage(target: Dictionary, type: int, amount: int) -> int:
	return Damage.after_resistance(amount, resistance_of(target, type))


func resistance_of(target: Dictionary, type: int) -> int:
	var standing = target.get("resistances", {}).get(type, 0)
	# Anything raising or lowering it for a while. Stored under the same name
	# the definition uses - "resist_fire" - so it dispels, expires and shows on
	# the portrait exactly like any other timed change.
	var key = Damage.resistance_key(type)
	for eff in target.get("status_effects", []):
		if eff.get("stat", "") == key:
			standing += eff.get("amount", 0)
	return standing


## --- Skill sounds ---
##
## A skill names its own sound (see SkillDefinition.sound) and it plays as the
## animation finishes, so the noise lands with the blow rather than under the
## wind-up. Silent for any skill with no sound set, which is all of them until
## one is given audio.

## Enough players that a reaction going off during someone else's swing does
## not cut it short. Beyond this the oldest sound is the one that loses, which
## at four overlapping noises is what you would want anyway.
const SOUND_VOICES = 4

var _sound_players: Array = []
var _next_voice := 0


func _build_sound_players():
	for i in SOUND_VOICES:
		var player = AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sound_players.append(player)


## Plays `skill`'s sound, if it has one. Round-robin across the voices rather
## than one shared player, so two skills resolving close together both sound.
func play_skill_sound(skill: SkillDefinition):
	if skill == null or skill.sound == null:
		return
	if _sound_players.is_empty():
		_build_sound_players()
	var player = _sound_players[_next_voice]
	_next_voice = (_next_voice + 1) % _sound_players.size()
	player.stream = skill.sound
	player.volume_db = skill.sound_volume_db
	player.play()


## How hard a level 3 spell rattles the view, in screen pixels at its peak.
const LEVEL_THREE_SHAKE = 14.0


## Rattles the view, if this battle has a camera to rattle. Silent when it
## doesn't, so nothing needs a camera to work.
func shake_camera(pixels: float):
	if camera != null and is_instance_valid(camera):
		camera.shake(pixels)


## Flashes `target` to show a skill landed on them - red when it came from the
## other side, green when it came from their own, and briefly the damage
## type's own colour first when there was damage. Called once per effect; the
## sprite collapses repeats so a two-effect skill still reads as one hit.
##
## Also shoves the drawn sprite away from wherever the hit came from. For an
## area skill that is away from the blast rather than from the caster, so the
## shape of what just went off is readable from the recoil alone.
func flash_target(attacker: Dictionary, target: Dictionary, damage_colour = null, from_position = null):
	var sprite = target.get("sprite")
	if sprite == null or not is_instance_valid(sprite):
		return
	# Defaulted for the same reason do_damage defaults it: side belongs to being
	# on the board, and this can be reached by anything that has been created
	# but not placed.
	sprite.flash_hit(attacker.get("side", 1) != target.get("side", 1), damage_colour)
	var origin = from_position if from_position != null else attacker.position
	if origin != target.position:
		sprite.recoil(Vector2(target.position - origin))


## Floats a number off `target` - what they just lost, or gained. Parented to
## whatever holds the combatant sprites so it shares their coordinate space and
## scrolls with the map.
## The colour a number of `type` damage is written in, as BBCode wants it.
##
## The same colour the floating number over their head uses, so the log and the
## battlefield agree about what just landed. Every one of these was grey, which
## meant the log threw away the one piece of information the number carries
## besides its size.
func damage_colour(type: int) -> String:
	return "#" + Damage.type_colour(type).to_html(false)


## Where combatant sprites live: a y-sorted layer of the tile map.
##
## They used to be children of the TileMap itself, every one at z_index 1 - and
## among equal z, Godot draws in tree order, which here was whatever order the
## encounter happened to spawn them in. That never showed while a sprite was
## exactly one tile and could not overlap a neighbour. One drawn taller than
## its tile overlaps constantly, and whoever spawned later drew in front
## whether they were standing in front or not.
##
## Made here rather than added to each of the seven terrain scenes by hand, and
## y-sorted on a node of its own rather than on the TileMap, whose own y-sort
## would change how the terrain layers themselves draw.
##
## It sorts by `position`, which stays the exact tile centre - the visual lift
## lives on the sprite's own `offset` - so people are ordered by where their
## feet are rather than by how tall they happen to be drawn.
func combatant_layer() -> Node2D:
	var map = $"../Terrain/TileMap"
	var layer = map.get_node_or_null("Combatants")
	if layer == null:
		layer = Node2D.new()
		layer.name = "Combatants"
		layer.y_sort_enabled = true
		map.add_child(layer)
	return layer


func float_number(target: Dictionary, text: String, colour: Color):
	var sprite = target.get("sprite")
	if sprite == null or not is_instance_valid(sprite) or sprite.get_parent() == null:
		return
	# Over their head rather than through their middle. A sprite no taller than
	# its tile answers zero, so nothing moves for anybody drawn as they are now.
	var above = Vector2(0.0, -sprite.head_height())
	FloatingNumber.spawn(sprite.get_parent(), sprite.position + above, text, colour)


## Blooms the screen edges in `colour`. Silent when this battle has no vignette
## wired up, so nothing depends on it existing.
func flare_hurt(colour: Color, share_of_health: float, lethal: bool = false):
	if hurt_vignette == null or not is_instance_valid(hurt_vignette):
		return
	# A scratch should barely register; a blow that takes a third of someone
	# should be impossible to miss. Floored so even a small hit says something.
	hurt_vignette.flare(colour, clampf(0.25 + share_of_health * 2.0, 0.0, 1.0), lethal)


## Everything that shows a point of damage arriving: the number where it landed,
## the screen edges for the player's own side, and a beat of frozen time.
##
## Shared by a direct hit, a lingering tick and a shove into a wall, because a
## poison that kills you should look no less like something that happened than
## a sword that does - and before this, only the sword did. `flash` is for the
## paths with no attacker to recoil away from, where apply_effect has not
## already tinted the target.
func show_damage(target: Dictionary, amount: int, type: int, flash: bool = false):
	if amount <= 0:
		return
	var ceiling = get_effective_stat(target, "max_hp")
	float_number(target, str(amount), Damage.type_colour(type))
	if flash:
		var sprite = target.get("sprite")
		if sprite != null and is_instance_valid(sprite):
			sprite.flash_hit(true, Damage.type_colour(type))
	if target.get("side", 1) == 0:
		# Twice the intensity when this is the blow that takes them down, and
		# read before the death is applied - target.hp is already below zero by
		# the time anyone would ask afterwards.
		flare_hurt(Damage.type_colour(type), float(amount) / maxf(ceiling, 1.0), target.hp <= 0)
	var freeze = hit_stop_for(amount, ceiling)
	if freeze > 0.0:
		hit_stop(freeze)


## --- Hit stop ---
##
## A beat of frozen time on impact. It is most of what makes a hit feel like it
## weighs something, and it costs nothing to produce - no art, no sound, no
## animation. Scaled by how much of the target it took off, so a scratch does
## not stop the world.

const HIT_STOP_MINIMUM = 0.03
const HIT_STOP_MAXIMUM = 0.13

## How many hit stops are currently waiting to end. Time only starts again
## when the last of them does - otherwise two hits landing together would have
## the first one's release cut the second one short.
var _hit_stop_depth := 0


## Freezes everything for `seconds` of real time. Deliberately not awaited by
## its callers: the freeze is a garnish on a hit that has already resolved, and
## making the whole combat coroutine wait on it would put it in the path of
## everything that follows.
func hit_stop(seconds: float):
	_hit_stop_depth += 1
	Engine.time_scale = 0.0
	# Real seconds, not scaled ones - a timer running on scaled time would
	# never tick while the scale is zero, and the freeze would be permanent.
	await get_tree().create_timer(seconds, true, false, true).timeout
	_hit_stop_depth = maxi(_hit_stop_depth - 1, 0)
	if _hit_stop_depth == 0:
		# Back to whatever this turn runs at - an enemy's may be sped up.
		Engine.time_scale = _turn_scale


## The freeze for a hit that took `damage` off a target with `max_hp`, or 0 for
## one too small to be worth stopping for.
func hit_stop_for(damage: int, max_hp: int) -> float:
	if damage <= 0 or max_hp <= 0:
		return 0.0
	var share = clampf(float(damage) / float(max_hp), 0.0, 1.0)
	return lerpf(HIT_STOP_MINIMUM, HIT_STOP_MAXIMUM, share)


## Time scale is global, so a battle torn down mid-freeze would leave the whole
## game stopped with nothing left running to start it again.
func _exit_tree():
	# Leaving a battle mid-flight, by any route: Arena Mode, the title screen, or
	# walking back out to the map. Anything this battle turned on globally has to
	# come off here rather than at the end of an await chain the scene change has
	# already cut - a hit-stop left behind freezes the game everywhere, including
	# the menu just opened.
	# An enemy's turn may have been sped up too, and a menu running at three
	# times its speed is no menu at all.
	_hit_stop_depth = 0
	_turn_scale = 1.0
	Engine.time_scale = 1.0
	stop_watching()


## --- Attributes and the damage they produce ---


## One of the five attributes on `comb`, by Stats.Type. Ten for anyone created
## before stats existed, which is the database default too, so an unfilled
## entry behaves like an ordinary one rather than dealing nothing.
func stat_of(comb: Dictionary, type: int) -> int:
	var key = Stats.stat_key(type)
	if key == "":
		return 0
	# Folded, not raw. Every damage figure in the game reads an attribute
	# through here, and reading it raw meant nothing could ever buff or weaken
	# one: a spell raising somebody's Defense changed what the sheet said and
	# not what they took, and raising a caster's Intellect did nothing to their
	# spells.
	return fold_stat_changes(comb, key, comb.get("stats", {}).get(key, 10))


## Whether a contested skill lands in full on `target`. The caster's own
## scaling stat is weighed against whichever stat the skill names - so the same
## Fireball that overwhelms a frail sorcerer only singes an armoured knight,
## with no dice involved either way.
func wins_contest(attacker: Dictionary, target: Dictionary, skill: SkillDefinition) -> bool:
	if skill is ItemDefinition:
		# Nothing of the thrower. The bottle's own power against them, the same
		# way its damage is its own - see ItemDefinition.item_power for what the
		# thrower's hidden scaling_stat used to do to this.
		return stat_of(target, skill.contest_stat) < skill.item_power
	return stat_of(target, skill.contest_stat) < stat_of(attacker, scaling_stat_of(attacker, skill))


## What one DAMAGE effect of `skill` does to `target`, before resistances.
## `power` is 1.0 for a clean hit and 0.5 for a graze.
##
## BaseDamage = WeaponBase + 0.7 x Stat, FinalDamage = BaseDamage x
## AbilityModifier x 40/(40 + Defense). The effect's own min/max amounts are
## not consulted at all - a skill's damage is entirely the caster's stat and
## the skill's modifier, which is what makes the same spell scale with whoever
## casts it.
## What `skill` is worth before any of its own dials are applied: the caster's
## arm and attribute for a skill, and the item's own power for an item.
##
## A bomb is a bomb whoever throws it, so nothing of the thrower goes into an
## item's - but from here on the two are the same arithmetic, which is the point.
## An item used to take a different path at every one of the three places below,
## and each had its own idea of what an item was worth.
func power_behind(attacker: Dictionary, skill: SkillDefinition) -> float:
	if skill is ItemDefinition:
		return float(skill.item_power)
	return Stats.base_damage(stat_of(attacker, scaling_stat_of(attacker, skill)),
		attacker.get("weapon_base", Stats.WEAPON_BASE))


func skill_damage(attacker: Dictionary, target: Dictionary, skill: SkillDefinition, power: float = 1.0) -> int:
	return Stats.final_damage(power_behind(attacker, skill),
		skill.ability_modifier * power * damage_dealt_multiplier(attacker, target, skill),
		defense_against(target, skill))


## As much of `target`'s Defense as a hit of `skill` meets: all of it, less
## the share the skill goes straight through (SkillDefinition.ignores_defense).
func defense_against(target: Dictionary, skill: SkillDefinition) -> int:
	var defense := int(stat_of(target, Stats.Type.DEFENSE))
	if skill == null or skill.ignores_defense <= 0:
		return defense
	return roundi(defense * (1.0 - clampi(skill.ignores_defense, 0, 100) / 100.0))


## How much harder than its own numbers `attacker` hits `target` with `skill`:
## 1 for an ordinary blow. One place, read by skill_damage, so the hit that
## lands and the prompt that promised it agree.
##
## - a faction the party has learned about (FactionDefinition.known_damage_bonus)
## - the attacker's path: empowered, or amplifying (path_damage_multiplier)
func damage_dealt_multiplier(attacker: Dictionary, target: Dictionary, skill: SkillDefinition) -> float:
	var multiplier := path_damage_multiplier(attacker, skill)
	if attacker.get("side", 0) == 0 and target.get("known_faction", "") != "":
		var faction := FactionDefinition.named(target.known_faction)
		if faction != null:
			multiplier *= 1.0 + faction.known_damage_bonus
	# Staggered, a boss is hit harder (StaggerDefinition.damage_taken).
	multiplier *= damage_taken_multiplier(target)
	# Broken parts - arms that hit for less, a plate that lets more through -
	# and a blow struck from on top of whoever it lands on.
	multiplier *= parts_multiplier(attacker, target)
	if attacker.get("riding", -1) == target.get("id", -2):
		multiplier *= RIDING_BONUS
	return multiplier



## What `skill` swings for before anybody's defence takes its share - the number
## the skill itself is worth, which is what the action panel shows.
##
## The same arithmetic as skill_damage with the target's half left out, and the
## mirror of heal_amount: a heal has never had a target's defence in it either,
## which is why the two now read the same way on the panel.
func base_skill_damage(attacker: Dictionary, skill: SkillDefinition) -> int:
	return maxi(roundi(power_behind(attacker, skill) * skill.ability_modifier), 0)


## What `skill` mends when `healer` casts it. No defence on the other side of
## it - being tough does not make you harder to patch up - and no randomness,
## so a heal is something you can count on when deciding whether it is enough.
func heal_amount(healer: Dictionary, skill: SkillDefinition, effect: EffectDefinition = null) -> int:
	# A path that heals harder (the Carer's) - here, so the panel says so too.
	var bonus := 1.0
	for passive in active_passives(healer):
		bonus += passive.heal_bonus
	return maxi(roundi(power_behind(healer, skill) * heal_strength(skill, effect) * bonus), 0)


## The share of a caster's power a heal is worth: the effect's own dial when it
## sets one, and the skill's otherwise.
##
## Without this a skill that both cuts and mends did both at the same size,
## since ability_modifier was one dial for the lot - so Light Swing could not
## swing in full and give back a third.
func heal_strength(skill: SkillDefinition, effect: EffectDefinition) -> float:
	if effect != null and effect.heal_modifier > 0.0:
		return effect.heal_modifier
	return skill.ability_modifier


## What a lingering tick from `skill` should be worth, before the target's own
## defence and resistance are applied. Zero when there is no skill to scale
## off, which tells the tick to fall back to its flat amounts.
##
## Snapshotted when the effect lands rather than recomputed each turn: the
## caster may be dead, moved, or debuffed by the time it ticks, and a poison
## getting weaker because the poisoner was hit is not what anyone expects.
## The target's side of it - defence and resistance - is still read live, so
## shoring yourself up mid-burn does help.
func dot_base_damage(attacker: Dictionary, skill: SkillDefinition, modifier: float) -> float:
	if skill == null or modifier <= 0.0:
		return 0.0
	# The caster's own weapon base, the same as skill_damage, base_skill_damage
	# and heal_amount all read. Left out, a tick was always worked out as though
	# whoever inflicted it carried the default weapon - so a spawn given a
	# heavier one hit harder with its attacks and burned exactly as before.
	var base = power_behind(attacker, skill)
	# The skill's own ability_modifier is deliberately not in here. It sizes what
	# the skill does on impact, and a tick has its own dial - so a burn that
	# lingers too long can be turned down without weakening the blow that set it,
	# and a blow can be strengthened without the burn following it up.
	#
	# They used to multiply together, which meant every number was two numbers:
	# Crystalise's 0.4 and 0.3 made a tick worth 0.12, and nothing on the skill
	# said so.
	return base * modifier


## --- Seeing a hit coming ---
##
## What the prompt shown while aiming reads from. Worked out by the same steps
## use_skill, do_damage and do_heal take, so what it promises is what the log
## will report - but nothing is rolled, spent or changed.


## Who `skill`, aimed at `aim` by `caster`, would catch - found the way
## use_skill finds them. Empty when the aim is out of reach.
##
## Anybody hidden on the other side is left out: they would still be caught,
## but naming them would say exactly where they are.
func targets_if_aimed(caster: Dictionary, skill: SkillDefinition, aim: Vector2i) -> Array:
	var distance = distance_to(caster, aim)
	if distance > effective_max_range(caster, skill) or distance < skill.min_range:
		return []
	# A blink bursts from where it lands, which is the tile aimed at.
	var from = aim if skill.teleports == SkillDefinition.TeleportWho.CASTER else nearest_tile_of(caster, aim)
	var tiles = get_impact_tiles(skill, from, aim, terrain_class(caster), caster.get("size", Sizes.Size.HUMAN))
	var found := []
	for target in get_targets_in_tiles(tiles, caster, skill.targets_ally, skill.affects_both_sides):
		if target.side != caster.side and is_hidden(target):
			continue
		found.append(target)
	return found


## What `skill` would do to `target` if it connected:
##
##   hit_chance   the roll it has to make, or 100 for a contested skill, which
##                never rolls
##   contested    whether it is decided by a contest instead
##   wins         whether the caster wins that contest - lands in full - or it
##                is shrugged off, which leaves half the damage and nothing else
##   their_stat / their_stat_name, our_stat / our_stat_name   the two numbers
##                the contest weighs, and what they are called
##   damage       after the target's defence and resistance, as do_damage does
##   heal         what a heal on it would mend
##   lethal       whether the damage alone would finish them
##   also         the conditions that would land with it
##   dropped      what a graze keeps from landing
func predict_hit(attacker: Dictionary, target: Dictionary, skill: SkillDefinition) -> Dictionary:
	var result := {
		"hit_chance": 100, "contested": skill.uses_stat_contest, "wins": true,
		"their_stat": 0, "their_stat_name": "", "our_stat": 0, "our_stat_name": "",
		"damage": 0, "heal": 0, "lethal": false, "deals_damage": false,
		"also": [], "dropped": [],
	}
	var power := 1.0
	if skill.uses_stat_contest:
		result.wins = wins_contest(attacker, target, skill)
		result.their_stat = stat_of(target, skill.contest_stat)
		result.their_stat_name = Stats.stat_name(skill.contest_stat)
		if skill is ItemDefinition:
			result.our_stat = skill.item_power
			result.our_stat_name = "its power"
		else:
			result.our_stat = stat_of(attacker, scaling_stat_of(attacker, skill))
			result.our_stat_name = Stats.stat_name(scaling_stat_of(attacker, skill))
		if not result.wins:
			power = 0.5
	else:
		result.hit_chance = hit_chance(attacker, skill, target)
	# The same test spend_element_upgrade makes, without spending anything.
	var raising := false
	if has_element_upgrade(attacker):
		for type in elements_of(skill):
			if Damage.can_upgrade(type):
				raising = true
	for effect in skill.all_effects():
		if effect == null or effect.applies_to_caster:
			continue
		match effect.type:
			EffectDefinition.EffectType.DAMAGE:
				result.deals_damage = true
				var element = Damage.upgraded_form(effect.damage_type) if raising else effect.damage_type
				result.damage += resisted_damage(target, element, skill_damage(attacker, target, skill, power))
			EffectDefinition.EffectType.HEAL:
				if result.wins:
					result.heal += heal_amount(attacker, skill, effect)
				else:
					result.dropped.append("the heal")
			EffectDefinition.EffectType.CONDITION:
				if effect.condition == null:
					continue
				if result.wins:
					result.also.append(effect.condition.display_name)
				else:
					result.dropped.append(effect.condition.display_name)
			_:
				if not result.wins:
					result.dropped.append(effect.display_name if effect.display_name != "" else "the rest")
	result.lethal = result.damage >= target.hp
	return result


func do_damage(attacker: Dictionary, target: Dictionary, effect: EffectDefinition, skill: SkillDefinition = null, mention_skill: bool = false, power: float = 1.0):
	# Something on the map that is not Breakable takes no harm from a hit.
	if target.has("object") and not target.object.breakable:
		update_information.emit("The [color=orange]%s[/color] takes no harm.\n" % target.name)
		return
	# The raised element while an upgrade is being spent on this cast, and the
	# written one otherwise - read once, so what is resisted, what is shown and
	# what the log says can never disagree.
	var element = effective_damage_type(attacker, effect.damage_type)
	var resistance = resistance_of(target, element)
	# A skill's damage comes from the caster's stat and the skill's modifier.
	# The effect's own min/max only stand in when there is no skill behind the
	# damage at all - a condition burning away, a shove into a wall.
	var raw = skill_damage(attacker, target, skill, power) if skill != null else randi_range(effect.min_amount, effect.max_amount)
	var damage = resisted_damage(target, element, raw)
	var flavour = "%s damage%s" % [Damage.type_name(element).to_lower(), Damage.describe_resistance(resistance)]
	# Being hit gives you away, whoever was aimed at. A blast thrown at somebody
	# else that happens to catch a hidden combatant has found them, even though
	# nobody knew they were there to aim at.
	if is_hidden(target):
		set_hidden(target, false)
		update_information.emit("[color=yellow]%s[/color] is caught, and their cover is blown!
" % target.name)
	# Somebody guarding them takes their share first (the Guardian's).
	damage = _guard_share(target, damage)
	lose_hp(target, damage, element)
	# Aimed at a part of somebody big, the part takes it too (see "Body parts").
	_hit_part(target, damage)
	# A hit on a boss counts on its stagger bar, beyond the damage it did.
	_stagger_from_hit(target, skill)
	show_damage(target, damage, element)
	update_combatants.emit(combatants)
	if mention_skill and skill != null:
		update_information.emit("[color=yellow]%s[/color] used %s on [color=red]%s[/color], dealing [color=%s]%d %s[/color].\n" % [
			attacker.name, skill.name, target.name, damage_colour(element), damage, flavour
		])
	else:
		update_information.emit("[color=yellow]%s[/color] dealt [color=%s]%d %s[/color] to [color=red]%s[/color].\n" % [
			attacker.name, damage_colour(element), damage, flavour, target.name
		])
	# Talked into standing down, then hit: that is the end of that.
	if damage > 0 and target.hp > 0:
		_hurt_ends_conditions(target)
	# Every blow of somebody who measures as they fight (Enfina's) studies.
	if target.hp > 0 and attacker.has("id") and attacker != target and not target.has("object") \
			and not target.get("illusion", false) and studies_on_hit(attacker):
		study(attacker, target, true)
	if target.hp <= 0:
		combatant_die(target)


func do_heal(attacker: Dictionary, target: Dictionary, effect: EffectDefinition, skill: SkillDefinition = null, mention_skill: bool = false):
	# The same shape as damage: the healer's stat and the skill's modifier. The
	# effect's flat range only stands in when there is no skill behind the
	# healing at all, the way it does for damage.
	var amount = heal_amount(attacker, skill, effect) if skill != null else randi_range(effect.min_amount, effect.max_amount)
	target.hp = mini(target.hp + amount, get_effective_stat(target, "max_hp"))
	float_number(target, "+" + str(amount), Color("7fe08a"))
	update_combatants.emit(combatants)
	if mention_skill and skill != null:
		update_information.emit("[color=yellow]%s[/color] used %s on [color=lightgreen]%s[/color], healing [color=lightgreen]%d[/color].\n" % [
			attacker.name, skill.name, target.name, amount
		])
	else:
		update_information.emit("[color=yellow]%s[/color] healed [color=lightgreen]%s[/color] for [color=lightgreen]%d[/color].\n" % [
			attacker.name, target.name, amount
		])
	# A share of it back to the healer (the Carer's), for mending somebody else.
	if target != attacker and attacker.get("alive", false):
		var share := 0.0
		for passive in active_passives(attacker):
			share += passive.heal_self_share
		var back := roundi(amount * share)
		if back > 0:
			attacker.hp = mini(attacker.hp + back, get_effective_stat(attacker, "max_hp"))
			float_number(attacker, "+" + str(back), Color("7fe08a"))
			update_combatants.emit(combatants)
			update_information.emit("[color=lightgreen]%s[/color] recovers %d as well.\n" % [attacker.name, back])


func combatant_die(combatant: Dictionary):
	# A thing on the map does not fall either: broken, it goes off and is gone
	# (see "Things on the map").
	if combatant.has("object"):
		if combatant.alive:
			set_off(combatant)
			_object_gone(combatant, "breaks")
		return
	# An image does not fall: it shatters (see summon_decoy).
	if combatant.get("illusion", false):
		_shatter(combatant)
		if groups[Group.ENEMIES].size() < 1 or groups[Group.PLAYERS].size() < 1:
			combat_finish()
		return
	# Whoever was up on them comes down with them (Climb), and they come down
	# off whoever they were up on.
	_drop_riders(combatant)
	if combatant.has("riding"):
		dismount(combatant)
	# Felled by the party while they are taking them alive: knocked out, and
	# taken (see "Nerve").
	if combatant.alive and _knocks_out(combatant):
		combatant.hp = 0
		_taken(combatant, "knocked_out")
		reveal_anyone_now_seen()
		return
	# Whatever they were hiding behind, they are not hiding any more.
	set_hidden(combatant, false)
	var	comb_id = combatants.find(combatant)
	if comb_id != -1:
		combatant.alive = false
		groups[combatant.side].erase(comb_id)
		update_information.emit("[color=red]{0}[/color] died.\n".format([
			combatant.name
		]
	))
	# Guarded the way every other sprite reach in this file is: create_combatant
	# makes a combatant with no sprite on it, so the logic layer killing one of
	# its own must not depend on there being something drawn.
	var dying_sprite = combatant.get("sprite")
	if dying_sprite != null and is_instance_valid(dying_sprite):
		dying_sprite.set_dead()
	combatant_died.emit(combatant)
	# Down, they hold nobody (Holding on).
	check_holds()
	# Somebody falling is exactly what leaves the last of their side standing
	# alone, and the last one standing cannot stay hidden. Asked here, after the
	# groups above have been updated, so the count is the one that is now true.
	reveal_anyone_now_seen()
	# The party gone, nobody bought or rebound fights on for them.
	if combatant.side == Group.PLAYERS and not combatant.has("turncoat"):
		_turncoats_turn_back_if_alone()
	# The last of a side down, their images go with them: an image is not
	# somebody left standing.
	if not side_standing(combatant.side):
		for other in combatants.duplicate():
			if other.get("illusion", false) and other.alive and other.side == combatant.side:
				_shatter(other)
	if groups[Group.ENEMIES].size() < 1 or groups[Group.PLAYERS].size() < 1:
		combat_finish()




## --- Coming back from the fallen ---
##
## A Resuscitate (SkillDefinition.targets_fallen, EffectType.REVIVE) stands an
## ally back up where they fell. It costs them: everything they are made of but
## how far they can walk comes back a little less, for the rest of the run, and
## a second time takes as much again off what the first left.

## The figures on a combatant that weakening takes from besides their five
## attributes. Movement is the one thing it leaves alone.
const WEAKENED_FIGURES := ["max_hp", "initiative", "weapon_base"]


## Whoever of `side` lies fallen on `tile` - the last to fall there, if more
## than one did - or {}.
func fallen_at(tile: Vector2i, side: int) -> Dictionary:
	var found := {}
	for comb in combatants:
		if not comb.alive and comb.side == side and comb.position == tile and not comb.get("illusion", false) and not comb.has("object") and not comb.has("taken"):
			found = comb
	return found


## Everybody on `caster`'s side lying fallen in `tiles`.
func fallen_in_tiles(tiles: Array, caster: Dictionary) -> Array:
	var found := []
	for tile in tiles:
		var comb := fallen_at(tile, caster.side)
		if not comb.is_empty() and not found.has(comb):
			found.append(comb)
	return found


## Whether anybody on `side` has fallen in this fight.
func anyone_fallen(side: int) -> bool:
	for comb in combatants:
		if not comb.alive and comb.side == side and not comb.get("illusion", false) and not comb.has("object"):
			return true
	return false


## Stands `target` back up: weakened first, then on their feet with
## effect.revive_health of what they can have now - where they fell, or on the
## nearest free tile if somebody is standing there.
func revive(attacker: Dictionary, target: Dictionary, effect: EffectDefinition, skill: SkillDefinition = null):
	if target.alive or not still_running():
		return
	var index := combatants.find(target)
	if index == -1:
		return
	weaken(target, effect.revive_weakening)
	var stand: Vector2i = target.position
	if controller != null and controller.has_method("nearest_free_tile"):
		stand = controller.nearest_free_tile(target.position, target.movement_class)
	target.alive = true
	target.hp = maxi(1, roundi(target.max_hp * effect.revive_health))
	# Whatever was burning or holding them went down with them.
	target.status_effects = []
	target.hidden = false
	target.position = stand
	if not groups[target.side].has(index):
		groups[target.side].append(index)
	var sprite = target.get("sprite")
	if sprite != null and is_instance_valid(sprite):
		if controller != null:
			sprite.position = sprite_point(target)
		sprite.set_alive()
	if controller != null and controller.has_method("combatant_revived"):
		controller.combatant_revived(target)
	float_number(target, "+" + str(target.hp), Color("7fe08a"))
	update_combatants.emit(combatants)
	update_turn_queue.emit(combatants, turn_queue)
	update_information.emit("[color=yellow]%s[/color] used %s: [color=lightgreen]%s[/color] is back on their feet with %d health - and %d%% weaker for good.\n" % [
		attacker.name, skill.name if skill != null else "it", target.name, target.hp, roundi(effect.revive_weakening * 100.0)])


## Takes `fraction` off everything `comb` is made of but their movement - for
## good, and on top of whatever was taken before. See apply_frailty.
static func weaken(comb: Dictionary, fraction: float):
	if fraction <= 0.0:
		return
	comb["frailty"] = comb.get("frailty", 1.0) * (1.0 - fraction)
	apply_frailty(comb)


## Sets everything weakening touches to what it was before any, times
## comb.frailty. Worked from the untouched figures, kept the first time, so
## being weakened again compounds without rounding creeping in. Nothing goes
## below 1 that was above it. Called for a fresh combatant too, by
## Campaign.apply_carried_state, so the weakening outlasts the fight.
static func apply_frailty(comb: Dictionary):
	var frailty: float = comb.get("frailty", 1.0)
	if frailty >= 1.0 and not comb.has("unweakened"):
		return
	if not comb.has("unweakened"):
		var untouched := {"stats": comb.get("stats", {}).duplicate()}
		for figure in WEAKENED_FIGURES:
			untouched[figure] = comb.get(figure, 0)
		comb["unweakened"] = untouched
	var before: Dictionary = comb.unweakened
	for key in before.stats:
		comb.stats[key] = weakened_figure(before.stats[key], frailty)
	for figure in WEAKENED_FIGURES:
		comb[figure] = weakened_figure(before[figure], frailty)
	comb.hp = mini(comb.get("hp", 0), comb.max_hp)


## `figure` weakened to `frailty` of itself - not below 1 if it was above.
static func weakened_figure(figure, frailty: float) -> int:
	if figure <= 0:
		return figure
	return maxi(1, roundi(figure * frailty))


## --- Stealing ---
##
## A Steal (EffectType.STEAL) lifts what somebody has to hand in this fight -
## an enemy's pocket (SpawnDefinition.starting_items), or the front of a party
## member's bag - and puts it where the thief keeps their own: the front of
## their bag first, so it is to hand at once, or an enemy's pocket. What the
## thief has no room for stays with whoever had it.

## Whether `skill` takes things off whoever it lands on.
static func steals(skill: SkillDefinition) -> bool:
	if skill == null:
		return false
	for effect in skill.all_effects():
		if effect != null and effect.type == EffectDefinition.EffectType.STEAL:
			return true
	return false


## Whether anybody standing against `comb` has something on them to take.
func anyone_carrying_against(comb: Dictionary) -> bool:
	for other in combatants:
		if other.alive and other.side != comb.get("side", 0) and not items_of(other).is_empty():
			return true
	return false


## Takes what `target` has to hand - all of it, or effect.steal_count of it -
## and gives it to `attacker`, as far as they have room.
func steal(attacker: Dictionary, target: Dictionary, effect: EffectDefinition, skill: SkillDefinition = null):
	if immune_to(target, Immunity.Kind.STOLEN_FROM):
		shrug_off(target, Immunity.name_of(Immunity.Kind.STOLEN_FROM))
		return
	var carried: Array = items_of(target).duplicate()
	if effect.steal_count > 0 and carried.size() > effect.steal_count:
		carried.resize(effect.steal_count)
	if carried.is_empty():
		update_information.emit("[color=red]%s[/color] has nothing on them to steal.\n" % target.name)
		return
	var taken := []
	var for_later := []
	var left := []
	for key in carried:
		var slot := _stow(attacker, key)
		if slot < 0:
			left.append(key)
			continue
		_give_up(target, key)
		taken.append(key)
		if slot >= Campaign.COMBAT_SLOTS:
			for_later.append(key)
	if taken.is_empty():
		update_information.emit("[color=yellow]%s[/color] has no room for anything [color=red]%s[/color] is carrying.\n" % [
			attacker.name, target.name])
		return
	float_number(target, "Stolen", Color("f2d36b"))
	update_combatants.emit(combatants)
	update_information.emit("[color=yellow]%s[/color] used %s: lifts %s from [color=red]%s[/color].\n" % [
		attacker.name, skill.name if skill != null else "it", _item_names(taken), target.name])
	if not for_later.is_empty():
		update_information.emit("[color=yellow]%s[/color] has no free hand for %s - into the bag, for after the fight.\n" % [
			attacker.name, _item_names(for_later)])
	if not left.is_empty():
		update_information.emit("[color=yellow]%s[/color] has no room for %s, so [color=red]%s[/color] keeps it.\n" % [
			attacker.name, _item_names(left), target.name])


## Puts `key` where `comb` keeps their things, and says which slot it went in:
## the first free one of their bag for the party, the end of their pocket for
## anybody else. -1 when there is no room.
func _stow(comb: Dictionary, key: String) -> int:
	if comb.side == 0:
		var owner_key: String = comb.get("combatant_key", "")
		return Campaign.stow_item(owner_key, key) if owner_key != "" else -1
	if not comb.has("pocket"):
		comb["pocket"] = []
	var pocket: Array = comb.pocket
	if pocket.size() >= Campaign.COMBAT_SLOTS:
		return -1
	pocket.append(key)
	return pocket.size() - 1


## Takes one `key` off `comb`, from what they have to hand.
func _give_up(comb: Dictionary, key: String):
	if comb.side == 0:
		Campaign.take_item(comb.get("combatant_key", ""), key)
		return
	var pocket: Array = comb.get("pocket", [])
	var slot := pocket.find(key)
	if slot >= 0:
		pocket.remove_at(slot)


## "Cure Potion, Tiny Bomb and Medicine", from item keys.
func _item_names(keys: Array) -> String:
	var names := []
	for key in keys:
		var item: ItemDefinition = ItemDatabase.item(key)
		names.append(item.name if item != null else key)
	if names.size() == 1:
		return names[0]
	return "%s and %s" % [", ".join(names.slice(0, names.size() - 1)), names[-1]]


## --- What the paths do ---
##
## The abilities paths (SubclassDefinition) hand out, nearly all as switches on
## a PassiveDefinition, read here through active_passives so a passive waiting
## for its level does nothing. Charms (EquipmentDefinition) can carry any of
## them too.


## The key a skill is saved under - its file's name - or what a skill made on
## the spot was registered as (SkillDefinition.combined).
static func skill_key_of(skill: SkillDefinition) -> String:
	if skill == null:
		return ""
	if skill.has_meta("key"):
		return skill.get_meta("key")
	return skill.resource_path.get_file().get_basename()


## Tiles more `skill` reaches in `comb`'s hands (PassiveDefinition.range_bonuses).
func range_bonus(comb: Dictionary, skill: SkillDefinition) -> int:
	var key := skill_key_of(skill)
	var bonus := 0
	for passive in active_passives(comb):
		bonus += int(passive.range_bonuses.get(key, 0))
	return bonus


## The free items `comb` still has to hand this fight (free_item_each_fight).
func free_items_of(comb: Dictionary) -> Array:
	var used: Array = comb.get("free_items_used", [])
	var found := []
	for passive in active_passives(comb):
		var key: String = passive.free_item_each_fight
		if key != "" and ItemDatabase.is_item(key) and not used.has(key) and not found.has(key):
			found.append(key)
	return found


## --- Overheal ---
##
## Health on top of health (PassiveDefinition.overheals_allies): taken first by
## anything that hurts (lose_hp), never stacking - a second overheal tops up
## to whichever is larger - and gone by the end of the fight, since nothing
## carries it out.

## Takes `amount` off `target`: their overheal first, then their health. What
## came off their health.
func lose_hp(target: Dictionary, amount: int, element: int = -1) -> int:
	var shield: int = target.get("temp_hp", 0)
	var absorbed := mini(shield, amount)
	if absorbed > 0:
		target.temp_hp = shield - absorbed
	target.hp -= amount - absorbed
	# A boss's stagger bar and phases (see "Bosses"); `element` is the damage's
	# type, for a bar only one type fills.
	_after_hp_lost(target, amount - absorbed, element)
	return amount - absorbed


## Gives `target` `amount` overheal, if it is more than they already have.
func overheal(target: Dictionary, amount: int, from: Dictionary):
	if amount <= target.get("temp_hp", 0):
		return
	target["temp_hp"] = amount
	float_number(target, "+%d" % amount, Color("8fd3ff"))
	update_combatants.emit(combatants)
	update_information.emit("[color=lightgreen]%s[/color] is overhealed by %d, from [color=yellow]%s[/color].\n" % [
		target.name, amount, from.name])


## --- Hits ---

## Whether `comb` is empowered by `passive` right now - suffering its condition.
func _empowered(comb: Dictionary, passive: PassiveDefinition) -> bool:
	if passive.empowered_by == null:
		return false
	for condition in conditions_of(comb):
		if condition == passive.empowered_by or condition.resource_path == passive.empowered_by.resource_path:
			return true
	return false


## What the attacker's paths add to a hit: empowered (the Berserker's), or a
## spell amplified (the Demolitionist's, while it is being cast).
func path_damage_multiplier(attacker: Dictionary, skill: SkillDefinition) -> float:
	var multiplier := 1.0
	for passive in active_passives(attacker):
		if passive.empowered_damage_bonus > 0.0 and _empowered(attacker, passive):
			multiplier *= 1.0 + passive.empowered_damage_bonus
		if passive.amplifies_spells and skill != null and skill.spell_slot_level > 0 and attacker.get("amplify", 0) > 0:
			multiplier *= 1.0 + passive.amplify_bonus_per_gate * attacker.amplify
	return multiplier


## Somebody on `target`'s side guarding them (guards_within) takes their share
## of `damage`. What is left for the target.
func _guard_share(target: Dictionary, damage: int) -> int:
	# Somebody made up for the purpose - a dummy hit to see what a number comes
	# to - is on no side, and nobody guards them.
	if damage <= 0 or not target.has("side") or not target.has("position"):
		return damage
	for guard in combatants:
		if not guard.get("alive", false) or guard == target or guard.get("side", -1) != target.side \
				or guard.get("illusion", false) or not guard.has("position"):
			continue
		for passive in active_passives(guard):
			if passive.guards_within <= 0 or passive.guard_share <= 0.0:
				continue
			if get_position_distance(guard.position, target.position) > passive.guards_within:
				continue
			var taken := mini(damage, roundi(damage * passive.guard_share))
			if taken <= 0:
				continue
			lose_hp(guard, taken)
			show_damage(guard, taken, Damage.Type.PHYSICAL, true)
			update_information.emit("[color=yellow]%s[/color] takes %d of the blow meant for [color=yellow]%s[/color].\n" % [
				guard.name, taken, target.name])
			if guard.hp <= 0:
				combatant_die(guard)
			return damage - taken
	return damage


## Whether somebody on `target`'s side spends their reaction warding them from
## `attacker`'s `skill` (wards_allies): the share of the hit that still lands,
## 1 for all of it. The player is asked about their own; anybody else wards
## whenever they can.
func _offer_ward(attacker: Dictionary, target: Dictionary, skill: SkillDefinition) -> float:
	if not skill.deals_damage or attacker.side == target.side:
		return 1.0
	for warder in combatants:
		if not warder.alive or warder.side != target.side or warder.get("reaction_used", false) or warder.get("illusion", false):
			continue
		if has_restriction(warder, "prevents_reactions"):
			continue
		for passive in active_passives(warder):
			if not passive.wards_allies or passive.ward_reduction <= 0.0:
				continue
			if get_position_distance(warder.position, target.position) > passive.ward_range:
				continue
			var take := true
			if warder.side == 0 and reaction_prompt != null and reaction_prompt.has_method("ask_about"):
				take = await reaction_prompt.ask_about("%s can ward" % warder.name,
					"%s is about to be hit by %s. Ward them, taking %d%% off it?\nThis spends %s's one reaction until their next turn." % [
						target.name, skill.name, roundi(passive.ward_reduction * 100), warder.name])
			if not take:
				return 1.0
			warder.reaction_used = true
			update_information.emit("[color=yellow]%s[/color] wards [color=yellow]%s[/color].\n" % [warder.name, target.name])
			return 1.0 - passive.ward_reduction
	return 1.0


## What `attacker`'s paths do once `skill` has landed on `target`: an ally a
## spell lands on overhealed, or spurred on; an enemy hit while empowered set
## alight too.
func _after_landing(attacker: Dictionary, target: Dictionary, skill: SkillDefinition):
	if not attacker.alive or not target.alive:
		return
	var spell := skill.spell_slot_level > 0
	for passive in active_passives(attacker):
		if spell and target.side == attacker.side:
			if passive.overheals_allies > 0.0:
				overheal(target, roundi(power_behind(attacker, skill) * passive.overheals_allies), attacker)
			if passive.ally_spell_movement != 0 and target != attacker:
				var spur := EffectDefinition.new()
				spur.type = EffectDefinition.EffectType.STAT_MODIFIER
				spur.stat = "movement"
				spur.modifier_amount = passive.ally_spell_movement
				spur.duration = 1
				spur.display_name = "Spurred on"
				apply_effect(attacker, target, spur, skill, false)
		if passive.spreads_it and skill.deals_damage and target.side != attacker.side and _empowered(attacker, passive):
			var spread := EffectDefinition.new()
			spread.type = EffectDefinition.EffectType.CONDITION
			spread.condition = passive.empowered_by
			apply_effect(attacker, target, spread, skill, false)


## The tiles `comb` could step to after `skill` (step_after): along each of the
## eight straight lines, as far as step_tiles reaches by the board's own measure
## (a diagonal step is two), stopping at whatever is in the way. Empty when the
## skill is not one they step after.
func step_tiles_after(comb: Dictionary, skill: SkillDefinition) -> Array:
	var key := skill_key_of(skill)
	var reach := 0
	for passive in active_passives(comb):
		if passive.step_after.has(key):
			reach = maxi(reach, passive.step_tiles)
	var found := []
	if reach <= 0:
		return found
	for way in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN,
			Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
		for step in range(1, reach + 1):
			var tile: Vector2i = comb.position + way * step
			if get_position_distance(comb.position, tile) > reach or not can_land_on(comb, tile):
				break
			found.append(tile)
	return found


## --- Amplifying ---

## How many free amplifications `comb` has a fight at their level.
func free_amplifies(comb: Dictionary) -> int:
	var count := 0
	for passive in active_passives(comb):
		for level in passive.free_amplifies_at:
			if comb.get("level", 1) >= level:
				count += 1
	return count


## Whether `comb` can amplify at all.
func amplifies(comb: Dictionary) -> bool:
	return active_passives(comb).any(func(passive): return passive.amplifies_spells)


## Settles what amplifying `skill` by comb.amplify gates costs, before it is
## cast: a free one if any are left, or the gate that many above the spell's.
## Leaves comb.amplify at what it will actually be (0 if it cannot be paid),
## and answers the gate to spend instead of the spell's own (0 for its own).
func settle_amplify(comb: Dictionary, skill: SkillDefinition) -> int:
	var steps: int = comb.get("amplify", 0)
	if steps <= 0 or skill.spell_slot_level <= 0 or not amplifies(comb):
		comb["amplify"] = 0
		return 0
	steps = mini(steps, 3 - skill.spell_slot_level)
	if steps <= 0:
		comb["amplify"] = 0
		update_information.emit("%s is cast through the deepest gate already, and cannot be amplified.\n" % skill.name)
		return 0
	comb["amplify"] = steps
	if comb.get("free_amplifies_used", 0) < free_amplifies(comb):
		comb["free_amplifies_used"] = comb.get("free_amplifies_used", 0) + 1
		update_information.emit("[color=yellow]%s[/color] amplifies %s without opening a deeper gate.\n" % [comb.name, skill.name])
		return 0
	var gate := slot_available_for(comb, skill.spell_slot_level + steps)
	if gate <= 0:
		comb["amplify"] = 0
		update_information.emit("[color=yellow]%s[/color] has no deeper gate to amplify %s with.\n" % [comb.name, skill.name])
		return 0
	return gate


## --- Confused ---


## A confused combatant's turn (ConditionDefinition.confuses), whichever side:
## at whoever is nearest - friend or foe - with the first thing they have that
## hurts and reaches, walking in first if it does not reach yet. Nothing else.
func ai_confused(comb: Dictionary):
	update_information.emit("[color=red]%s[/color] is confused, and lashes out at whoever is nearest.\n" % comb.name)
	await _ai_lash_out(comb, _nearest_anybody(comb))


## A deceived combatant's turn (ConditionDefinition.turns_on_own_side): at the
## nearest of their own side, the same way.
func ai_deceived(comb: Dictionary):
	var target := _nearest_of_own_side(comb)
	if target.is_empty():
		update_information.emit("[color=red]%s[/color] looks round for the traitor, and finds nobody.\n" % comb.name)
	else:
		update_information.emit("[color=red]%s[/color] has been deceived, and turns on [color=red]%s[/color].\n" % [comb.name, target.name])
	await _ai_lash_out(comb, target)


## Whoever of `comb`'s own side is nearest them - not them, not an image.
func _nearest_of_own_side(comb: Dictionary) -> Dictionary:
	var nearest := {}
	var best := INF
	for other in combatants:
		if other == comb or not other.alive or other.side != comb.side or other.has("object") or other.get("illusion", false):
			continue
		var distance = get_distance(comb, other)
		if distance < best:
			best = distance
			nearest = other
	return nearest


## `comb` goes for `target` with the first thing they have that hurts and
## reaches, walking in first if it does not reach yet - and nothing else.
func _ai_lash_out(comb: Dictionary, target: Dictionary):
	var acting: int = current_combatant
	if target.is_empty():
		await advance_turn()
		return
	var keys: Array = _ai_main_keys(comb).filter(_hurts_somebody.bind(comb))
	keys.append(melee_fallback_for(comb))
	var budget := movement_budget_of(comb)
	for key in keys:
		var skill: SkillDefinition = SkillDatabase.skills.get(key)
		if skill == null:
			continue
		var spot := _spot_to_hit_from(comb, skill, target, budget)
		if spot.x == -99999:
			continue
		if spot != comb.position:
			await controller.ai_move(spot)
			if not comb.alive or not still_running():
				return
		await use_skill(key, comb, target.position, false)
		# Their own side's turns can end themselves once nothing is left to do.
		if still_running() and current_combatant == acting:
			await advance_turn()
		return
	# Nothing reaches: they go at them.
	var closer := find_best_reachable_tile(comb, budget, func(tile): return -float(get_position_distance(tile, target.position)))
	if closer != comb.position:
		await controller.ai_move(closer)
	if still_running() and current_combatant == acting:
		await advance_turn()


## A single-target skill of `comb`'s that hurts and that they can use now.
func _hurts_somebody(key: String, comb: Dictionary) -> bool:
	var skill: SkillDefinition = SkillDatabase.skills.get(key)
	return skill != null and skill.deals_damage and not skill.targets_ally and skill.aoe_radius == 0 \
		and can_afford_skill(comb, skill) and meets_level_for(comb, skill)


## Whoever is nearest `comb`, on any side - anybody they can see.
func _nearest_anybody(comb: Dictionary) -> Dictionary:
	var nearest := {}
	var best := INF
	for other in combatants:
		if other == comb or not other.alive or (other.side != comb.side and is_hidden(other)):
			continue
		var distance = get_distance(comb, other)
		if distance < best:
			best = distance
			nearest = other
	return nearest


## The tile, within `budget` of walking, that `skill` reaches `target` from with
## the least walking - their own if it already does. (-99999, -99999) if none.
func _spot_to_hit_from(comb: Dictionary, skill: SkillDefinition, target: Dictionary, budget: int) -> Vector2i:
	var standing: Array = [comb.position]
	if budget > 0:
		standing.append_array(controller.get_reachable_tiles(comb.position, comb.movement_class, budget, comb).keys())
	var best := Vector2i(-99999, -99999)
	var best_walk := INF
	for tile in standing:
		var distance := get_position_distance(tile, target.position)
		if distance < skill.min_range or distance > effective_max_range(comb, skill):
			continue
		if skill.respects_blocking and distance > 1 and not has_line_of_sight(tile, target.position, comb.movement_class):
			continue
		var walk := get_position_distance(comb.position, tile)
		if walk < best_walk:
			best_walk = walk
			best = tile
	return best


## --- Images ---
##
## An image of an ally (EffectType.SUMMON_DECOY, the Illusionist's Mirror
## Image): them, to look at, on a tile beside them - with one point of health,
## no turns of its own, and nothing to do. The first thing that touches it
## shatters it. The other side goes for it as it would for whoever it is of,
## which is the point; it counts for nothing when deciding whether a side is
## still standing, and nothing is remembered of it after the fight.

## Puts up an image of `target`, from `attacker`.
func summon_decoy(attacker: Dictionary, target: Dictionary, skill: SkillDefinition = null):
	if not target.alive or target.get("illusion", false):
		return
	var definition: CombatantDefinition = CombatantDatabase.combatants.get(target.get("combatant_key", ""))
	if definition == null:
		return
	var tile: Vector2i = controller.nearest_free_tile(target.position, target.movement_class)
	if tile == target.position or not can_land_on(target, tile):
		update_information.emit("There is no room beside [color=yellow]%s[/color] for an image.\n" % target.name)
		return
	var image: Dictionary = create_combatant(definition, "", "%s (image)" % target.name, null, target.get("level", 1))
	image["illusion"] = true
	image["base_name"] = image.name
	image.max_hp = 1
	image.hp = 1
	image.skill_list = []
	image.passives = []
	image.initiative = 0
	image.movement = 0
	image.spell_slots = [0, 0, 0, 0]
	image.max_spell_slots = [0, 0, 0, 0]
	add_combatant(image, target.side, tile)
	var sprite = image.get("sprite")
	if sprite != null and is_instance_valid(sprite):
		sprite.modulate = Color(0.75, 0.85, 1.0, 0.65)
	update_turn_queue.emit(combatants, turn_queue)
	update_combatants.emit(combatants)
	update_information.emit("[color=yellow]%s[/color] used %s: an image of [color=lightgreen]%s[/color] stands beside them.\n" % [
		attacker.name, skill.name if skill != null else "it", target.name])


## Whether anybody of `side` is standing who is not an image.
func side_standing(side: int) -> bool:
	for index in groups[side]:
		if not combatants[index].get("illusion", false):
			return true
	return false


## Takes an image off the board: no body left behind, nothing to bring back.
func _shatter(image: Dictionary):
	var index := combatants.find(image)
	if index == -1 or not image.alive:
		return
	image.alive = false
	groups[image.side].erase(index)
	update_information.emit("The image of [color=yellow]%s[/color] shatters.\n" % image.name.trim_suffix(" (image)"))
	combatant_died.emit(image)
	var sprite = image.get("sprite")
	if sprite != null and is_instance_valid(sprite):
		sprite.queue_free()
	image["sprite"] = null


## --- Declared moves ---
##
## A declared skill (SkillDefinition.declared) is announced on one turn and
## lands on the next. Announcing costs nothing - the turn goes on - and marks
## where it will come down on the board (CController draws comb.declared.tiles),
## so the other side has a turn to get out of the way. At the start of its
## user's first turn once every one of the other side has had a turn since
## (declared_due - the next one, for anybody with a turn a round) it lands on
## exactly those tiles, wherever its user has moved to since, spending that
## turn's action (and any gate it costs). A turn lost to a stun or a stagger, or
## taken by confusion, loses it.

## Announces `key`, aimed at `aim`, to land at the start of `comb`'s next turn.
func declare(comb: Dictionary, key: String, aim: Vector2i, as_secondary: bool = false, destination: Vector2i = Vector2i(-99999, -99999)):
	var skill: SkillDefinition = SkillDatabase.skills[key]
	if comb.has("declared"):
		update_information.emit("[color=yellow]%s[/color] is already readying %s.\n" % [
			comb.name, SkillDatabase.skills[comb.declared.skill].name])
		return
	var tiles: Array = [aim]
	if skill.aoe_radius > 0:
		tiles = get_impact_tiles(skill, nearest_tile_of(comb, aim), aim, terrain_class(comb), comb.get("size", Sizes.Size.HUMAN))
	if controller != null:
		# Nothing marked off the edge of the map, or over a hole in it.
		tiles = tiles.filter(func(tile): return controller.is_on_map(tile))
	# Everybody on the other side who has yet to have a turn since: it lands once
	# they all have (declared_due) - the next turn for anybody with one turn a
	# round, and never before the party has had its chance against a boss with
	# several.
	var waiting: Array = []
	for other in combatants:
		if other.alive and other.get("side", -1) != comb.get("side", -1) and _takes_turns(other):
			waiting.append(other.get("id", -1))
	comb["declared"] = {"skill": key, "aim": aim, "as_secondary": as_secondary, "destination": destination, "tiles": tiles,
		"waiting": waiting}
	update_information.emit("[color=yellow]%s[/color] readies [color=orange]%s[/color] - it lands at the start of their next turn.\n" % [
		comb.name, skill.name])
	update_combatants.emit(combatants)
	if controller != null:
		controller.queue_redraw()
	if game_ui != null and comb.side == 0 and game_ui.has_method("refresh_action_buttons"):
		game_ui.refresh_action_buttons()


## Whether what `comb` declared lands at the start of the turn they are in:
## every one of the other side it was waiting on has had a turn since, or is
## gone.
func declared_due(comb: Dictionary) -> bool:
	for id in comb.get("declared", {}).get("waiting", []):
		var other := combatant_with_id(id)
		if not other.is_empty() and other.alive:
			return false
	return true


## The combatant whose id is `id`, or {}.
func combatant_with_id(id: int) -> Dictionary:
	for comb in combatants:
		if comb.get("id", -2) == id:
			return comb
	return {}


## Whether `comb` takes turns at all: not an image, not a thing on the map.
func _takes_turns(comb: Dictionary) -> bool:
	return not comb.get("illusion", false) and not comb.has("object")


## Lands what `comb` declared last turn, at the start of this one.
func land_declared(comb: Dictionary):
	var declared: Dictionary = comb.get("declared", {})
	comb.erase("declared")
	if controller != null:
		controller.queue_redraw()
	if declared.is_empty() or not comb.alive:
		return
	update_information.emit("[color=yellow]%s[/color]'s [color=orange]%s[/color] comes down!\n" % [
		comb.name, SkillDatabase.skills[declared.skill].name])
	comb["landing_tiles"] = declared.tiles
	await use_skill(declared.skill, comb, declared.aim, false, declared.as_secondary, declared.destination, true)
	comb.erase("landing_tiles")


## Loses what `comb` declared, saying why.
func drop_declared(comb: Dictionary, why: String):
	if not comb.has("declared"):
		return
	update_information.emit("[color=yellow]%s[/color]'s %s comes to nothing - %s.\n" % [
		comb.name, SkillDatabase.skills[comb.declared.skill].name, why])
	comb.erase("declared")
	if controller != null:
		controller.queue_redraw()


## An enemy announcing a declared move of theirs before the rest of its turn, if
## it has one worth announcing from where it stands. Free, so the turn goes on
## after it.
func _ai_declare(comb: Dictionary):
	if comb.has("declared"):
		return
	var keys := []
	for key in comb.skill_list:
		var skill: SkillDefinition = SkillDatabase.skills.get(key)
		if skill != null and skill.declared and _ai_plannable(comb, skill):
			keys.append(key)
	if keys.is_empty():
		return
	var plan = ai_plan_attack(comb, keys, 0)
	if plan.skill != "":
		await use_skill(plan.skill, comb, plan.aim, false)


## Every turn's beginning: the other side's declared moves hear that this one
## has had their turn, and whoever it is takes what the auras around them and
## the ground under them give.
func _turn_begins_for(comb: Dictionary):
	for other in combatants:
		if other.has("declared"):
			other.declared.get("waiting", []).erase(comb.get("id", -1))
	if not comb.alive:
		return
	_auras_on(comb)
	_ground_under(comb)


## --- Immunities ---
##
## What cannot be done to somebody: the conditions in comb.immune_conditions
## (by file) and the Immunity kinds in comb.immune_to, both from their
## CombatantDefinition and changed by a boss's phases. The attempt still happens
## and is seen not to work - "Immune" over them, a line in the log - and a boss
## whose stagger bar counts what it shrugs off (StaggerDefinition
## .per_blocked_condition) has it filled by it. A thing on the map is immune to
## all of it.

func immune_to_condition(comb: Dictionary, condition: ConditionDefinition) -> bool:
	if condition == null:
		return false
	if comb.has("object"):
		return true
	return condition.resource_path in comb.get("immune_conditions", [])


func immune_to(comb: Dictionary, kind: int) -> bool:
	return comb.has("object") or kind in comb.get("immune_to", [])


## Says `comb` shrugged `what` off ("stunned", "being shoved") - and, for a
## condition, counts it on their stagger bar.
func shrug_off(comb: Dictionary, what: String, a_condition: bool = false):
	if comb.has("object"):
		return
	update_information.emit("[color=red]%s[/color] is immune to %s.\n" % [comb.name, what])
	float_number(comb, "Immune", Color("cfd8e3"))
	var bar: StaggerDefinition = comb.get("stagger_def")
	if a_condition and bar != null:
		add_stagger(comb, bar.per_blocked_condition)


## Puts `condition` on `target` from something that is not a skill - an aura,
## the arena, a thing on the map - for `stored` of their turns as stored (see
## turns_stored). False, and nothing put on, when they are immune; `quiet` says
## nothing about that (an aura would say it every turn).
func put_condition(target: Dictionary, condition: ConditionDefinition, stored: int, source: String, quiet: bool = false, source_id: int = -1) -> bool:
	if immune_to_condition(target, condition):
		if not quiet:
			shrug_off(target, condition.display_name.to_lower(), true)
		return false
	var movement_before = get_effective_stat(target, "movement")
	replace_matching_tick(target, "condition", condition, 0)
	target.status_effects.append({
		"stat" = "condition",
		"condition" = condition,
		"dot_base" = 0.0,
		"duration" = stored,
		"ends_at_start" = condition.wears_off_at_start,
		"source_name" = source,
		"source_id" = source_id,
	})
	if condition.movement_change != 0:
		resync_live_movement(target, movement_before)
	update_combatants.emit(combatants)
	return true


## --- Bosses ---
##
## A combatant whose definition has a BossDefinition (comb.boss), whatever its
## size. It is announced across the screen as it appears (_announce_boss: at the
## start of the fight, or as it arrives) with its music; the HUD gives it a
## health bar along the top, and its stagger bar under that.
##
## Phases (BossPhase) begin as its health falls past each one's At Health -
## checked whenever it loses health (_check_phases, from lose_hp) - and each is
## announced the same way. A hit that takes it past two begins both.
##
## The stagger bar (comb.stagger out of comb.stagger_max, filled as its
## StaggerDefinition says - add_stagger) staggers it when full: it loses its next
## turn (or more), what it was readying is gone, and it is hit harder until the
## lost turn is over (damage_taken_multiplier). The bar does not fill while it is
## staggered, and starts again from empty, bigger by Grows By.

const STAGGERED := preload("res://data/conditions/staggered.tres")
## How hard the view shakes as a phase begins, and as a boss is staggered.
const PHASE_SHAKE := 18.0
const STAGGER_SHAKE := 12.0
## The banner's colours: a boss's name, a phase's, a stagger.
const BOSS_COLOUR := Color("ff8a5c")
const STAGGER_COLOUR := Color("ffd36b")


func is_boss(comb: Dictionary) -> bool:
	return comb.has("boss")


## The bosses still standing, in the order they joined the fight.
func living_bosses() -> Array:
	return combatants.filter(func(comb): return comb.alive and comb.has("boss"))


## Brings `comb` up across the screen if it is a boss not yet announced.
func _announce_boss(comb: Dictionary):
	if not comb.has("boss") or not comb.alive or comb.get("announced", false):
		return
	comb["announced"] = true
	var boss: BossDefinition = comb.boss
	if boss.music != "":
		Music.play(boss.music)
	_banner(comb.name, boss.title, BOSS_COLOUR)
	update_information.emit("[color=red]%s[/color]%s stands against you.\n" % [
		comb.name, (", " + boss.title) if boss.title != "" else ""])
	update_combatants.emit(combatants)


func _banner(title: String, subtitle: String, colour: Color):
	if game_ui != null and game_ui.has_method("announce_boss"):
		game_ui.announce_boss(title, subtitle, colour)


## Begins whichever of `comb`'s phases its health has fallen into.
func _check_phases(comb: Dictionary):
	if not comb.has("boss") or not comb.alive or comb.hp <= 0:
		return
	var phases: Array = comb.boss.phases_in_order()
	var most := float(maxi(get_effective_stat(comb, "max_hp"), 1))
	var began: BossPhase = null
	while comb.phase < phases.size() and float(comb.hp) <= phases[comb.phase].at_health * most:
		began = phases[comb.phase]
		comb.phase += 1
		_begin_phase(comb, began)
	if began != null:
		comb.phase_name = began.name
		_banner(comb.name, began.name, BOSS_COLOUR)
		shake_camera(PHASE_SHAKE)
		update_combatants.emit(combatants)


func _begin_phase(comb: Dictionary, phase: BossPhase):
	if phase.message != "":
		update_information.emit("[color=red]%s[/color]: %s\n" % [comb.name, phase.message])
	for key in phase.skills_added:
		if not comb.skill_list.has(key):
			comb.skill_list.append(key)
	for key in phase.skills_removed:
		comb.skill_list.erase(key)
	for passive in phase.passives_added:
		if passive != null and not comb.passives.has(passive):
			comb.passives.append(passive)
	if phase.ai_function != "":
		comb.ai_function = phase.ai_function
	if phase.turns_per_round > 0:
		set_turns_per_round(comb, phase.turns_per_round)
	if phase.stagger != null:
		_set_stagger_bar(comb, phase.stagger)
	if phase.clears_conditions:
		# Everything but a stagger: the party earned that.
		comb.status_effects = comb.status_effects.filter(func(eff):
			return eff.get("stat", "") != "condition" or eff.get("condition") == STAGGERED)
	for condition in phase.immunities_gained:
		if condition != null and not condition.resource_path in comb.immune_conditions:
			comb.immune_conditions.append(condition.resource_path)
	for condition in phase.immunities_lost:
		if condition != null:
			comb.immune_conditions.erase(condition.resource_path)
	for kind in phase.immune_to_gained:
		if not kind in comb.immune_to:
			comb.immune_to.append(kind)
	for kind in phase.immune_to_lost:
		comb.immune_to.erase(kind)
	if phase.music != "":
		Music.play(phase.music)
	if phase.ends_hazards:
		_hazards_running.clear()
	for hazard in phase.hazards:
		if hazard != null:
			# From the next round, counted from there.
			_hazards_running.append({"hazard": hazard, "from": round_number + 1})
	for key in phase.summons:
		_summon_beside(comb, key)


## Brings `key` into the fight as near `comb` as it fits, on their side, at
## their level - help a boss calls for.
func _summon_beside(comb: Dictionary, key: String):
	if not CombatantDatabase.combatants.has(key):
		push_warning("A phase of %s summons '%s', which is not a combatant." % [comb.name, key])
		return
	var arrival: Dictionary = create_combatant(CombatantDatabase.combatants[key], key, "", null, comb.get("level", 1))
	arrival["side"] = comb.side
	var tile := _free_tile_for(arrival, comb.position)
	if tile.x == -99999:
		update_information.emit("There is no room for anybody %s calls.\n" % comb.name)
		return
	add_mid_round(arrival, comb.side, tile)
	update_information.emit("[color=red]%s[/color] calls [color=red]%s[/color] to its side.\n" % [comb.name, combatants.back().name])


## add_combatant in the middle of somebody's turn: the order may move round
## whoever is acting, so the turn is kept on them.
func add_mid_round(arrival: Dictionary, side: int, tile: Vector2i):
	var acting: int = current_combatant
	add_combatant(arrival, side, tile)
	if turn < turn_queue.size() and turn_queue[turn] != acting:
		var best := -1
		for i in turn_queue.size():
			if turn_queue[i] == acting and (best == -1 or absi(i - turn) < absi(best - turn)):
				best = i
		if best >= 0:
			turn = best
	if arrival.has("object"):
		_offer_interact()
	_announce_boss(arrival)
	update_turn_queue.emit(combatants, turn_queue)
	update_combatants.emit(combatants)


func _set_stagger_bar(comb: Dictionary, bar: StaggerDefinition):
	comb["stagger_def"] = bar
	comb["stagger"] = 0.0
	comb["stagger_max"] = bar.max_value if bar != null else 0.0
	comb["staggers"] = 0


func is_staggered(comb: Dictionary) -> bool:
	for condition in conditions_of(comb):
		if condition == STAGGERED or condition.resource_path == STAGGERED.resource_path:
			return true
	return false


## How much harder `target` is hit right now: more while staggered.
func damage_taken_multiplier(target: Dictionary) -> float:
	return target.get("stagger_hit_bonus", 1.0) if is_staggered(target) else 1.0


## Adds `amount` to `comb`'s stagger bar - more while they are readying
## something declared, by their bar's While Readying - and staggers them when
## it is full. Nothing while they have no bar or are staggered already.
func add_stagger(comb: Dictionary, amount: float):
	var bar: StaggerDefinition = comb.get("stagger_def")
	if bar == null or amount <= 0.0 or not comb.alive or is_staggered(comb):
		return
	if comb.has("declared"):
		amount *= bar.while_readying
	comb.stagger = minf(comb.stagger + amount, comb.stagger_max)
	if comb.stagger >= comb.stagger_max:
		stagger(comb)
	update_combatants.emit(combatants)


## A full bar: `comb` loses their next turn (or more), what they were readying
## goes, and they are hit harder until it is over. The bar starts again from
## empty, bigger by Grows By.
func stagger(comb: Dictionary):
	var bar: StaggerDefinition = comb.stagger_def
	comb.stagger = 0.0
	comb.staggers += 1
	comb.stagger_max = bar.max_value * pow(1.0 + bar.grows_by, comb.staggers)
	comb["stagger_hit_bonus"] = bar.damage_taken
	# Straight on, whatever they are immune to: staggering is the way past that.
	# Stored as the turns it takes, each lost turn taking one off.
	replace_matching_tick(comb, "condition", STAGGERED, 0)
	comb.status_effects.append({
		"stat" = "condition",
		"condition" = STAGGERED,
		"duration" = bar.turns_lost,
		"ends_at_start" = false,
		"source_name" = "Stagger",
	})
	drop_declared(comb, "staggered")
	float_number(comb, "Staggered!", STAGGER_COLOUR)
	shake_camera(STAGGER_SHAKE)
	update_information.emit("[color=yellow]%s is staggered![/color] It loses %s, and is hit %d%% harder until then.\n" % [
		comb.name, "its next turn" if bar.turns_lost == 1 else "its next %d turns" % bar.turns_lost,
		roundi((bar.damage_taken - 1.0) * 100.0)])
	_banner(comb.name, "Staggered!", STAGGER_COLOUR)
	update_combatants.emit(combatants)


## Every boss's bar, drained by its Drain Per Round at the top of a round.
func _drain_stagger_bars():
	for comb in combatants:
		var bar: StaggerDefinition = comb.get("stagger_def")
		if bar != null and comb.alive and bar.drain_per_round > 0.0 and not is_staggered(comb):
			comb.stagger = maxf(comb.stagger - bar.drain_per_round, 0.0)


## What losing `lost` health does to a boss: its phases, and its bar (Per
## Damage, of the right type). `element` -1 is damage of no type in particular.
## A hit that begins a phase fills no bar: the phase is the event, and starts
## whatever bar it brings empty.
func _after_hp_lost(target: Dictionary, lost: int, element: int):
	var phase_before: int = target.get("phase", 0)
	_check_phases(target)
	if target.get("phase", 0) != phase_before:
		return
	var bar: StaggerDefinition = target.get("stagger_def")
	if bar != null and lost > 0 and bar.per_damage > 0.0:
		if bar.damage_types.is_empty() or element in bar.damage_types:
			add_stagger(target, lost * bar.per_damage)


## A hit landing on a boss: its bar's Per Hit, and what the skill adds itself.
func _stagger_from_hit(target: Dictionary, skill: SkillDefinition):
	var bar: StaggerDefinition = target.get("stagger_def")
	if bar == null:
		return
	var amount := bar.per_hit
	if skill != null:
		amount += bar.from_skills.get(skill.resource_path.get_file().get_basename(), 0.0)
	add_stagger(target, amount)


## --- Auras ---
##
## A passive with an Aura Radius (PassiveDefinition): whoever begins a turn
## within that many tiles of its holder has its condition for that turn - the
## foes' one or the allies' one. A boss's presence, mostly; anybody can have one.

func _auras_on(comb: Dictionary):
	for holder in combatants:
		if holder == comb or not holder.alive or not holder.has("passives"):
			continue
		for passive in active_passives(holder):
			if passive.aura_radius <= 0:
				continue
			var condition: ConditionDefinition = passive.aura_on_allies if holder.side == comb.side else passive.aura_on_foes
			if condition == null or get_distance(holder, comb) > passive.aura_radius:
				continue
			if put_condition(comb, condition, 1, "%s's aura" % holder.name, true, holder.get("id", -1)):
				update_information.emit("[color=yellow]%s[/color] is %s by [color=red]%s[/color]'s presence.\n" % [
					comb.name, condition.display_name.to_lower(), holder.name])


## Tiles within an aura of anybody's, and whether it is the other side's to the
## party - for the board to tint.
func aura_tiles() -> Array:
	var found := []
	for holder in combatants:
		if not holder.alive or not holder.has("passives"):
			continue
		for passive in active_passives(holder):
			if passive.aura_radius > 0 and (passive.aura_on_foes != null or passive.aura_on_allies != null):
				found.append({"tiles": _tiles_within(holder, passive.aura_radius), "hostile": holder.side != 0})
	return found


## Every tile on the map within `reach` steps of any tile of `comb`'s.
func _tiles_within(comb: Dictionary, reach: int) -> Array:
	var rect := rect_of(comb)
	var found := []
	for y in range(rect.position.y - reach, rect.end.y + reach):
		for x in range(rect.position.x - reach, rect.end.x + reach):
			var tile := Vector2i(x, y)
			if rect_gap(rect, Rect2i(tile, Vector2i.ONE)) <= reach and controller.is_on_map(tile):
				found.append(tile)
	return found


## --- The arena ---
##
## What the map does by itself (HazardDefinition): the encounter's from the
## first round, a phase's from the round after it begins. At the top of every
## round (_arena_round_begins) what was marked last round comes down, bad ground
## that has had its time goes, and whatever is due is marked: Falling to land at
## the top of the next round, Ground to hurt from then on whoever starts a turn
## on it (_ground_under). The board draws both (hazard_warning_tiles,
## bad_ground_tiles).

## Running hazards: {"hazard", "from" - the round it counts its rounds from}.
var _hazards_running: Array = []
## Falling marks: {"hazard", "tiles", "lands" - the round it comes down}.
var _hazard_marks: Array = []
## Bad ground: {"hazard", "tiles", "from", "until" - the rounds it hurts in}.
var _bad_ground: Array = []
var _arena_started := false


func _arena_round_begins():
	if not _arena_started:
		_arena_started = true
		if encounter != null:
			for hazard in encounter.hazards:
				if hazard != null:
					_hazards_running.append({"hazard": hazard, "from": 1})
	for mark in _hazard_marks.duplicate():
		if mark.lands <= round_number:
			_hazard_marks.erase(mark)
			_hazard_lands(mark.hazard, mark.tiles)
	_bad_ground = _bad_ground.filter(func(ground): return ground.until >= round_number)
	for running in _hazards_running:
		var hazard: HazardDefinition = running.hazard
		if not hazard.due_in(round_number - running.from + 1):
			continue
		var tiles := _hazard_tiles(hazard)
		if tiles.is_empty():
			continue
		if hazard.kind == HazardDefinition.Kind.FALLING:
			_hazard_marks.append({"hazard": hazard, "tiles": tiles, "lands": round_number + 1})
			update_information.emit("[color=orange]%s[/color] - it comes down at the top of the next round. Get clear!\n" % hazard.display_name)
		else:
			_bad_ground.append({"hazard": hazard, "tiles": tiles, "from": round_number + 1,
				"until": round_number + hazard.lasts_rounds})
			update_information.emit("[color=orange]%s[/color] - from the next round, whoever starts a turn there is caught.\n" % hazard.display_name)
	if controller != null:
		controller.queue_redraw()


## Where `hazard` goes this time: around each of its places, as far as Radius.
func _hazard_tiles(hazard: HazardDefinition) -> Array:
	var places := []
	match hazard.aim:
		HazardDefinition.Aim.THESE_TILES:
			places = hazard.tiles.duplicate()
		HazardDefinition.Aim.ANYWHERE:
			var open := []
			var region: Rect2i = controller._astargrid.region
			for y in range(region.position.y, region.end.y):
				for x in range(region.position.x, region.end.x):
					var tile := Vector2i(x, y)
					if controller.is_on_map(tile) and not controller.is_tile_blocking(tile, 0):
						open.append(tile)
			open.shuffle()
			places = open.slice(0, hazard.count)
		_:
			var standing := []
			for comb in combatants:
				if comb.alive and _takes_turns(comb) and (hazard.aim == HazardDefinition.Aim.AT_EVERYONE or comb.side == 0):
					var theirs := tiles_of(comb)
					standing.append(theirs[randi() % theirs.size()])
			standing.shuffle()
			places = standing.slice(0, hazard.count)
	var tiles := {}
	for place in places:
		for dy in range(-hazard.radius, hazard.radius + 1):
			for dx in range(-hazard.radius, hazard.radius + 1):
				var tile: Vector2i = place + Vector2i(dx, dy)
				if absi(dx) + absi(dy) <= hazard.radius and controller.is_on_map(tile):
					tiles[tile] = true
	return tiles.keys()


func _hazard_lands(hazard: HazardDefinition, tiles: Array):
	update_information.emit("[color=orange]%s[/color] comes down!\n" % hazard.display_name)
	shake_camera(LEVEL_THREE_SHAKE * 0.6)
	for comb in combatants.duplicate():
		if comb.alive and hazard.catches(comb.side) and tiles_of(comb).any(func(tile): return tile in tiles):
			hit_by_the_arena(comb, hazard.damage, hazard.damage_type, hazard.condition, hazard.condition_duration,
				hazard.stagger, hazard.display_name)


## The bad ground `comb` starts their turn on, if any, catching them.
func _ground_under(comb: Dictionary):
	for ground in _bad_ground:
		var hazard: HazardDefinition = ground.hazard
		if ground.from > round_number or ground.until < round_number or not hazard.catches(comb.side):
			continue
		if tiles_of(comb).any(func(tile): return tile in ground.tiles):
			hit_by_the_arena(comb, hazard.damage, hazard.damage_type, hazard.condition, hazard.condition_duration,
				hazard.stagger, hazard.display_name)
			return


## `target` caught by something that is nobody's skill - a hazard, a thing on
## the map going off: its damage through their defence and resistance, its
## condition, and its stagger if they are a boss.
func hit_by_the_arena(target: Dictionary, damage: int, type: int, condition: ConditionDefinition, condition_turns: int,
		stagger_amount: float, source: String):
	if damage > 0 and not (target.has("object") and not target.object.breakable):
		var raw := Stats.final_damage(float(damage), damage_taken_multiplier(target), stat_of(target, Stats.Type.DEFENSE))
		var amount := resisted_damage(target, type, raw)
		flash_target({}, target, Damage.type_colour(type), target.position)
		lose_hp(target, amount, type)
		show_damage(target, amount, type)
		update_information.emit("[color=orange]%s[/color] deals [color=%s]%d %s damage[/color] to [color=red]%s[/color].\n" % [
			source, damage_colour(type), amount, Damage.type_name(type).to_lower(), target.name])
	if condition != null and target.alive and target.hp > 0:
		var turns := condition_turns if condition_turns > 0 else condition.duration
		if put_condition(target, condition, turns_stored(turns, condition.wears_off_at_start), source):
			update_information.emit("[color=red]%s[/color] is %s.\n" % [target.name, condition.display_name.to_lower()])
	if stagger_amount > 0.0:
		add_stagger(target, stagger_amount)
	update_combatants.emit(combatants)
	if target.hp <= 0 and target.alive:
		combatant_die(target)


## Marked tiles: what will fall next round, and ground that will be bad from it.
func hazard_warning_tiles() -> Array:
	var found := []
	for mark in _hazard_marks:
		found.append_array(mark.tiles)
	for ground in _bad_ground:
		if ground.from > round_number:
			found.append_array(ground.tiles)
	return found


## Ground hurting whoever starts a turn on it now.
func bad_ground_tiles() -> Array:
	var found := []
	for ground in _bad_ground:
		if ground.from <= round_number and ground.until >= round_number:
			found.append_array(ground.tiles)
	return found


## --- Things on the map ---
##
## A BattleObjectDefinition spawned like anybody (comb.object): in combatants
## and on the board - standing in the way, blocking sight like a body of its
## size, there to be clicked - but on no side's group and in no turn order, so
## it never acts, never watches, and never keeps a fight going. The party gets
## the Interact skill while there is something to use; using it (EffectType
## .INTERACT) or breaking it sets it off (set_off): every boss's bar fills by its
## Stagger, and its blast catches whoever is around it. Spent or broken, it goes.

const INTERACT_SKILL := "use"


## Gives the party the Interact skill, if there is something on the map to use.
func _offer_interact():
	if not SkillDatabase.skills.has(INTERACT_SKILL):
		return
	var something := combatants.any(func(comb): return comb.alive and comb.has("object") and comb.object.interactable)
	if not something:
		return
	for comb in combatants:
		if comb.alive and comb.side == 0 and _takes_turns(comb) and not comb.skill_list.has(INTERACT_SKILL):
			comb.skill_list.append(INTERACT_SKILL)


## Whether `skill` Uses things on the map (EffectType.INTERACT).
static func _interacts(skill: SkillDefinition) -> bool:
	return skill.effects.any(func(effect): return effect != null and effect.type == EffectDefinition.EffectType.INTERACT)


## Whether there is something on `tile` that can be Used.
func _usable_object_at(tile: Vector2i) -> bool:
	return combatants_at(tile).any(func(comb): return comb.has("object") and comb.object.interactable)


## `user` Using `thing` (the Interact skill).
func use_object(user: Dictionary, thing: Dictionary):
	if not thing.has("object") or not thing.object.interactable or not thing.alive:
		update_information.emit("There is nothing there for [color=yellow]%s[/color] to use.\n" % user.name)
		return
	set_off(thing, user)
	if thing.uses_left > 0:
		thing.uses_left -= 1
		if thing.uses_left == 0 and thing.alive:
			_object_gone(thing, "is spent")


## `thing` going off - Used, or broken. `backfire`: a hack on it failed, and it
## goes off on the party (Backfire Hits) with nothing for a boss's bar.
func set_off(thing: Dictionary, by: Dictionary = {}, backfire: bool = false):
	var object: BattleObjectDefinition = thing.object
	if backfire:
		update_information.emit("[color=red]The %s goes off in [color=yellow]%s[/color]'s hands![/color]\n" % [thing.name, by.get("name", "their")])
	elif object.set_off_line != "":
		update_information.emit("[color=orange]%s[/color]\n" % object.set_off_line)
	elif not by.is_empty():
		update_information.emit("[color=yellow]%s[/color] sets off the [color=orange]%s[/color].\n" % [by.name, thing.name])
	if object.stagger > 0.0 and not backfire:
		for boss in living_bosses():
			add_stagger(boss, object.stagger)
	var hits: int = object.backfire_hits if backfire else object.blast_hits
	if object.blast_radius > 0 and (object.blast_damage > 0 or object.blast_condition != null):
		var blast := _tiles_within(thing, object.blast_radius)
		shake_camera(LEVEL_THREE_SHAKE * 0.5)
		for comb in combatants.duplicate():
			if comb == thing or not comb.alive:
				continue
			var caught: bool = hits == HazardDefinition.Hits.EVERYONE \
				or (hits == HazardDefinition.Hits.THE_PARTY and comb.side == 0) \
				or (hits == HazardDefinition.Hits.THE_ENEMIES and comb.side == 1)
			if caught and tiles_of(comb).any(func(tile): return tile in blast):
				hit_by_the_arena(comb, object.blast_damage, object.blast_damage_type, object.blast_condition, 0, 0.0, thing.name)
	update_combatants.emit(combatants)


## --- Hacking ---
##
## Somebody with a passive's Can Hack (Prometheus's Prying Mind) can hack in a
## fight: the Hack skill (EffectType.HACK) on a foe winding up a declared skill,
## and Using a thing on the map whose BattleObjectDefinition has a Hack. Either
## plays the minigame (Hacking) there and then, with the hacker's own Intellect
## and gates, and nothing is written to Campaign - the fight keeps its own:
## - a declared skill hacked apart comes to nothing (and staggers a boss by the
##   hack's Stagger On Success); failing, with Sets Off, it lands at once
## - a thing hacked is Used as usual; failing, with Sets Off, it goes off on
##   the party (set_off's backfire)
## - Locks For Good makes that foe's spells, or that thing, unhackable for the
##   rest of the fight
## Walking away before a try has failed costs nothing; anything else spends the
## action.

func can_hack(comb: Dictionary) -> bool:
	return active_passives(comb).any(func(passive): return passive.can_hack)


## Whether `skill` is a hack (EffectType.HACK).
static func _hacks(skill: SkillDefinition) -> bool:
	return skill.effects.any(func(effect): return effect != null and effect.type == EffectDefinition.EffectType.HACK)


## Whoever on `tile` is winding up a declared skill, or {}.
func _winding_up_at(tile: Vector2i) -> Dictionary:
	for comb in combatants_at(tile):
		if comb.has("declared"):
			return comb
	return {}


## A thing on `tile` that has to be hacked before it can be Used, or {}.
func _hack_locked_object_at(tile: Vector2i) -> Dictionary:
	for comb in combatants_at(tile):
		if comb.has("object") and comb.object.hack != null and not comb.get("hacked", false):
			return comb
	return {}


func _hack_in_fight(attacker: Dictionary, skill_key: String, skill: SkillDefinition, impact: Vector2i, end_turn_after: bool, as_secondary: bool):
	if not can_hack(attacker):
		update_information.emit("Only somebody who can hack can do that - [color=yellow]%s[/color] can't.\n" % attacker.name)
		return
	var hacking = get_node_or_null("/root/Hacking")
	if hacking == null:
		return
	if _hacks(skill):
		# A bound creature: its binding is hacked, not its spell (see "Rebinding").
		var bound := _bound_at(impact)
		if not bound.is_empty():
			await _rebind(attacker, bound, hacking, end_turn_after, as_secondary)
			return
		var target := _winding_up_at(impact)
		if target.is_empty():
			update_information.emit("Nobody there is winding anything up to hack.\n")
			return
		if target.get("hack_locked", false):
			update_information.emit("[color=red]%s[/color]'s spells are locked against hacking now.\n" % target.name)
			return
		var winding: SkillDefinition = SkillDatabase.skills.get(target.declared.skill)
		var hack: HackDefinition = winding.hack if winding != null and winding.hack != null else skill.hack
		if hack == null:
			push_warning("%s has no hack to play: give it, or %s, one (SkillDefinition.hack)." % [skill.name, target.declared.skill])
			return
		var outcome: Dictionary = await hacking.run(hack, "", self, attacker)
		if not still_running():
			return
		match outcome.get("result", ""):
			"success":
				drop_declared(target, "hacked apart by %s" % attacker.name)
				if hack.stagger_on_success > 0.0:
					add_stagger(target, hack.stagger_on_success)
			"failed":
				if outcome.get("locked_out", false):
					target["hack_locked"] = true
				if outcome.get("set_off", false) and target.has("declared"):
					update_information.emit("[color=red]%s[/color]'s %s goes off early!\n" % [target.name, winding.name])
					await land_declared(target)
					if not still_running():
						return
			_:
				return
		await _hack_spends_action(attacker, as_secondary, end_turn_after)
		return
	var thing := _hack_locked_object_at(impact)
	if thing.get("hack_locked", false):
		update_information.emit("The [color=orange]%s[/color] is locked against hacking now.\n" % thing.name)
		return
	var outcome: Dictionary = await hacking.run(thing.object.hack, "", self, attacker)
	if not still_running():
		return
	match outcome.get("result", ""):
		"success":
			thing["hacked"] = true
			# Hacked, it is Used like anything else.
			await use_skill(skill_key, attacker, impact, end_turn_after, as_secondary)
			return
		"failed":
			if outcome.get("locked_out", false):
				thing["hack_locked"] = true
			if outcome.get("set_off", false):
				set_off(thing, attacker, true)
				_object_gone(thing, "is spent")
		_:
			return
	await _hack_spends_action(attacker, as_secondary, end_turn_after)


## The action a hack took, spent, and the turn on from there as after any skill.
func _hack_spends_action(attacker: Dictionary, as_secondary: bool, end_turn_after: bool):
	if as_secondary:
		attacker.secondary_used_this_turn = true
	else:
		attacker.skill_used_this_turn = true
	update_combatants.emit(combatants)
	if ai_plays(attacker):
		if end_turn_after:
			await advance_turn()
	elif controller.movement <= 0 and not has_action_left(attacker):
		await advance_turn()
	else:
		if controller.has_method("settle_undo_point"):
			controller.settle_undo_point()
		game_ui.refresh_action_buttons()


## Takes `thing` off the board - spent, or broken - saying `how`.
func _object_gone(thing: Dictionary, how: String):
	thing.alive = false
	update_information.emit("The [color=orange]%s[/color] %s.\n" % [thing.name, how])
	var sprite = thing.get("sprite")
	if sprite != null and is_instance_valid(sprite):
		sprite.set_dead()
	combatant_died.emit(thing)


##AI

func sort_weight_array(a, b):
	if a[0] > b[0]:
		return true
	else:
		return false


## Dispatches to whichever function CombatantDefinition.ai_function named for
## this enemy (default "ai_melee_rush"). Add your own by writing a new
## "func ai_my_type(comb: Dictionary):" below, following the pattern of the
## existing ones, and typing its name into a CombatantDefinition's ai_function
## field - no dispatch table to edit. Falls back to ai_melee_rush if the
## named function doesn't exist (e.g. a typo).
func ai_process(comb: Dictionary):
	# The main action already spent on something declared last turn, landing
	# now (land_declared): what is left is the secondary and their feet.
	if comb.get("skill_used_this_turn", false):
		if still_running() and comb.alive:
			await approach_with_remaining_movement(comb, find_nearest_enemy_of(comb))
			await ai_secondary_attack(comb)
			await advance_turn()
		return
	# Broken, they run (see "Nerve"); breaking now, they run or give up.
	if comb.get("fleeing", 0) > 0 or check_nerve(comb):
		# Held (Holding on), there is no running until they break free.
		if comb.get("fleeing", 0) > 0 and is_held(comb):
			await _ai_break_free(comb, true)
			if not still_running() or not comb.alive:
				return
			if is_held(comb):
				if not combat_over:
					await advance_turn()
				return
		if comb.get("fleeing", 0) > 0:
			await _ai_flee(comb)
		elif still_running() and not combat_over:
			await advance_turn()
		return
	# Somebody up on them (Climb): the main action goes on throwing them off.
	if not riders_of(comb).is_empty():
		comb.erase("intent")
		_ai_shake_off(comb)
		if still_running() and comb.alive:
			await approach_with_remaining_movement(comb, find_nearest_enemy_of(comb))
			await ai_secondary_attack(comb)
			await advance_turn()
		return
	# Held with nobody to hit from here (Grab): the main action goes on
	# breaking free, and their feet on whatever they would have walked to.
	if is_held(comb) and await _ai_break_free(comb):
		if still_running() and comb.alive:
			await approach_with_remaining_movement(comb, find_nearest_enemy_of(comb))
			await ai_secondary_attack(comb)
			await advance_turn()
		return
	# Read by Intuition: they do what was read, if they still can.
	if comb.has("intent"):
		if await _ai_follow_intent(comb):
			return
		if not still_running() or not comb.alive:
			return
	# Something declared is free to announce, so it comes before the rest.
	await _ai_declare(comb)
	if not still_running() or not comb.alive:
		return
	# Whatever sort of fighter they are, somebody half dead with a potion to hand
	# drinks it first.
	if await _ai_drink_from_pocket(comb):
		if still_running() and comb.alive:
			await ai_secondary_attack(comb)
			await advance_turn()
		return
	# Somebody beside them to throw into somebody else: a throw is worth two hits.
	if await _ai_hurl(comb):
		if still_running() and comb.alive:
			await ai_secondary_attack(comb)
			await advance_turn()
		return
	var ai_function = comb.get("ai_function", "ai_melee_rush")
	if ai_function != "" and has_method(ai_function):
		await call(ai_function, comb)
	else:
		await ai_melee_rush(comb)


## The nearest living combatant on the opposite side to comb, or an empty
## Dictionary if there isn't one.
func find_nearest_enemy_of(comb: Dictionary) -> Dictionary:
	# Taunted, there is only the one to go for.
	var taunter := taunted_by(comb)
	if not taunter.is_empty() and not is_hidden(taunter):
		return taunter
	var opposing_side = Group.PLAYERS if comb.side == Group.ENEMIES else Group.ENEMIES
	var nearest: Dictionary = {}
	var best_distance = INF
	for index in groups[opposing_side]:
		var candidate = combatants[index]
		# Hidden is not "harder to hit" - it is not being there. Nor is up on
		# somebody (Climb).
		if not candidate.alive or is_hidden(candidate) or candidate.has("riding"):
			continue
		var distance = get_distance(comb, candidate)
		if distance < best_distance:
			best_distance = distance
			nearest = candidate
	return nearest


## Whether Fear lets `comb` end a move on `tile`: never closer to their nearest
## enemy than they stand now. Anybody unafraid may end anywhere.
##
## Here rather than only on the controller, which enforces it for whoever is
## acting, so the danger view can ask the same of an enemy whose turn is still
## to come.
func fear_allows(comb: Dictionary, tile: Vector2i) -> bool:
	if not has_restriction(comb, "prevents_approach"):
		return true
	var nearest = find_nearest_enemy_of(comb)
	if nearest.is_empty():
		return true
	return get_position_distance(tile, nearest.position) >= get_position_distance(comb.position, nearest.position)


## The living combatant on the opposite side to comb with the lowest current
## hp (not missing hp - just lowest absolute hp), or an empty Dictionary if
## there isn't one.
func find_lowest_hp_enemy_of(comb: Dictionary) -> Dictionary:
	var opposing_side = Group.PLAYERS if comb.side == Group.ENEMIES else Group.ENEMIES
	var lowest: Dictionary = {}
	var lowest_hp = INF
	for index in groups[opposing_side]:
		var candidate = combatants[index]
		# Hidden is not being there - see find_nearest_enemy_of. This did not
		# ask, and while the Ranger chose its mark here it would aim at, and walk
		# towards, somebody it could not see.
		if not candidate.alive or is_hidden(candidate):
			continue
		if candidate.hp < lowest_hp:
			lowest_hp = candidate.hp
			lowest = candidate
	return lowest


## The nearest living combatant on comb's own side (excluding comb itself),
## or an empty Dictionary if there isn't one.
func find_nearest_ally(comb: Dictionary) -> Dictionary:
	var nearest: Dictionary = {}
	var best_distance = INF
	for index in groups[comb.side]:
		var candidate = combatants[index]
		if not candidate.alive or candidate == comb:
			continue
		var distance = get_distance(comb, candidate)
		if distance < best_distance:
			best_distance = distance
			nearest = candidate
	return nearest


## comb's own living ally missing the most hp (effective max_hp - current
## hp), or an empty Dictionary if every ally is at full health. Can return
## comb itself.
func find_most_injured_ally(comb: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_missing = 0
	for index in groups[comb.side]:
		var candidate = combatants[index]
		if not candidate.alive:
			continue
		var missing = get_effective_stat(candidate, "max_hp") - candidate.hp
		if missing > best_missing:
			best_missing = missing
			best = candidate
	return best


## comb's own living ally carrying the most debuffs/DoTs, or an empty
## Dictionary if nobody has any. Can return comb itself.
func find_most_afflicted_ally(comb: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_count = 0
	for index in groups[comb.side]:
		var candidate = combatants[index]
		if not candidate.alive:
			continue
		var count = 0
		for eff in candidate.status_effects:
			if eff.stat == "dot" or (eff.get("op", "add") == "add" and eff.get("amount", 0) < 0) or (eff.get("op", "add") == "multiply" and eff.get("amount", 1.0) < 1.0):
				count += 1
		if count > best_count:
			best_count = count
			best = candidate
	return best


## The offensive, single-target (not AoE) skill in comb's skill_list with
## the largest max_range - used by AI archetypes that fight from range with
## single-target skills specifically. Falls back to whatever melee they own.
## Picks by the range they can actually manage right now, not the range printed
## on the skill - a blinded combatant should reach for something usable at one
## tile rather than an archery skill it can no longer aim.
## What this combatant actually swings when the AI falls back to hitting
## somebody standing next to them: the shortest-reaching thing they own that
## hurts, and Enfina's greatsword only for somebody who owns nothing at all.
##
## It used to be greatsword_attack for everyone, whoever was swinging - so the
## Priest, whose kit is water and mending, produced a two-handed sword the
## moment the AI ran out of better ideas. Give somebody a melee skill of their
## own and this finds it; give them none and the old behaviour is still there
## rather than a turn spent doing nothing.
##
## Shortest reach first, so a dedicated melee is preferred to a gun that also
## works point blank.
func melee_fallback_for(comb: Dictionary) -> String:
	var best_key = "greatsword_attack"
	var best_reach = 99
	for skill_key in comb.skill_list:
		var skill: SkillDefinition = SkillDatabase.skills.get(skill_key)
		if skill == null or not skill.deals_damage or skill.targets_ally:
			continue
		if not can_afford_skill(comb, skill) or not meets_level_for(comb, skill):
			continue
		# Usable on somebody standing next to them.
		if skill.min_range > 1 or effective_max_range(comb, skill) < 1:
			continue
		var reach = effective_max_range(comb, skill)
		if reach < best_reach:
			best_reach = reach
			best_key = skill_key
	return best_key


func find_best_single_target_skill(comb: Dictionary) -> String:
	var best_key = melee_fallback_for(comb)
	var best_range = -1
	for skill_key in comb.skill_list:
		var skill: SkillDefinition = SkillDatabase.skills[skill_key]
		if skill.targets_ally or skill.aoe_radius > 0:
			continue
		if not can_afford_skill(comb, skill) or not meets_level_for(comb, skill):
			continue # out of slots for it, or not learned yet
		var reach = effective_max_range(comb, skill)
		if reach < skill.min_range:
			continue # capped below its own minimum - unusable at all
		if reach > best_range:
			best_range = reach
			best_key = skill_key
	return best_key


## Whether all `skill` does is get its own user moving - more movement, or
## moving without being reacted to - and on nobody but them. Run and Slip Past.
## Not Quicken or Hover, which can go on somebody else, nor Trailblaze, which
## sets you alight as well.
func only_gets_you_moving(skill: SkillDefinition) -> bool:
	if skill.max_range > 0 or skill.aoe_radius > 0 or skill.deals_damage:
		return false
	if skill.teleports != SkillDefinition.TeleportWho.NOBODY:
		return false
	var effects = skill.all_effects()
	if effects.is_empty():
		return skill.suppresses_reactions
	for effect in effects:
		if effect == null or effect.stat != "movement":
			return false
		match effect.type:
			EffectDefinition.EffectType.STAT_MODIFIER:
				if effect.modifier_amount <= 0:
					return false
			EffectDefinition.EffectType.STAT_MULTIPLIER:
				if effect.stat_multiplier <= 1.0:
					return false
			_:
				return false
	return true


## Why `skill` would do nothing at all for `comb` right now, or "" when it
## would do something. The action panel greys it out and says this; the AI
## leaves it alone. Rooted, Run doubles a movement that is not there.
func wasted_on(comb: Dictionary, skill: SkillDefinition) -> String:
	if skill is GateNadeDefinition and not can_use_gate_nade(comb, skill):
		return "Only somebody who knows %s, or could learn it, can use this - %s can't." % [
			skill.cast.name if skill.cast != null else skill.spell, comb.get("name", "they")]
	if skill != null and skill.targets_fallen and not anyone_fallen(comb.get("side", 0)):
		return "Nobody on %s's side has fallen, so %s would do nothing." % [comb.get("name", "their"), skill.name]
	if steals(skill) and not anyone_carrying_against(comb):
		return "Nobody against %s is carrying anything, so %s would do nothing." % [comb.get("name", "them"), skill.name]
	if skill == null or not only_gets_you_moving(skill):
		return ""
	for condition in conditions_of(comb):
		if condition.prevents_movement:
			return "%s can't move while %s, so %s would do nothing." % [
				comb.get("name", "They"), condition.display_name, skill.name]
	return ""


## The movement an AI should plan around. Zero for anything rooting them, so a
## crystallised enemy doesn't spend its turn choosing a tile it can't walk to.
func movement_budget_of(comb: Dictionary) -> int:
	if has_restriction(comb, "prevents_movement"):
		return 0
	return get_effective_stat(comb, "movement")


## The first skill in comb's skill_list that has at least one effect of
## `effect_type`, or "" if it has none.
func find_skill_of_type(comb: Dictionary, effect_type: EffectDefinition.EffectType) -> String:
	for skill_key in comb.skill_list:
		var skill: SkillDefinition = SkillDatabase.skills[skill_key]
		if not can_afford_skill(comb, skill) or not meets_level_for(comb, skill):
			continue
		for effect in skill.all_effects():
			if effect.type == effect_type:
				return skill_key
	return ""


## Searches every tile actually reachable by comb within movement_budget -
## true pathfinding-aware reachability (accounts for terrain movement cost,
## blocking tiles, and other combatants in the way, via
## CController.get_reachable_tiles - not a straight-line distance guess) -
## and returns whichever scores highest via `score_func` (a Callable taking
## a Vector2i, returning a float - higher is better). comb's own current
## tile is always considered too, so this never returns a worse option than
## staying put.
func find_best_reachable_tile(comb: Dictionary, movement_budget: int, score_func: Callable) -> Vector2i:
	var reachable = controller.get_reachable_tiles(comb.position, comb.movement_class, movement_budget, comb)
	var best_tile = comb.position
	var best_score = score_func.call(comb.position)
	for tile in reachable:
		if tile == comb.position:
			continue
		var score = score_func.call(tile)
		if score > best_score:
			best_score = score
			best_tile = tile
	return best_tile


## Whether `skill` could actually hit something at `target_position` if used
## from `from_position` - checks both raw distance AND, if the skill
## respects blocking, genuine line of sight. A tile can be numerically in
## range but still blocked by a wall, in which case this correctly reports
## false - unlike a plain distance check, which use_skill() would then
## silently resolve to hitting nobody at all.
func is_effectively_in_range(skill: SkillDefinition, from_position: Vector2i, target_position: Vector2i, movement_class: int, caster: Dictionary = {}) -> bool:
	var d = get_position_distance(from_position, target_position)
	var reach = effective_max_range(caster, skill) if not caster.is_empty() else skill.max_range
	if d < skill.min_range or d > reach:
		return false
	if skill.respects_blocking and not has_line_of_sight(from_position, target_position, movement_class):
		return false
	return true


## Like find_best_reachable_tile, but specifically for getting `comb`
## somewhere skill can actually hit target_position from (see
## is_effectively_in_range - not just numerically in range, genuinely able
## to land).
func find_tile_at_ideal_range(comb: Dictionary, target_position: Vector2i, skill: SkillDefinition, movement_budget: int) -> Vector2i:
	return find_best_reachable_tile(comb, movement_budget, func(tile):
		if is_effectively_in_range(skill, tile, target_position, comb.movement_class, comb):
			return 1000.0
		var d = get_position_distance(tile, target_position)
		return -absf(float(d) - float(clampi(d, skill.min_range, skill.max_range)))
	)


## The best aim position for `skill` cast from `caster_position` - i.e. the
## point within its range that, once get_impact_tiles resolves the skill's
## actual shape from there, hits the most living players. Works for any
## shape (DIAMOND centres on the aim point; LINE/CONE only use it to derive
## a direction from caster_position, so this just tries enough aim points to
## cover every relevant direction too). Returns {"position":Vector2i,
## "count":int}.
func find_best_aim_and_count(skill: SkillDefinition, caster_position: Vector2i, movement_class: int, caster: Dictionary = {}) -> Dictionary:
	var best_aim = caster_position
	var best_count = 0
	var reach = effective_max_range(caster, skill) if not caster.is_empty() else skill.max_range
	# A blast is centred on the tile aimed at, so whether it catches somebody is
	# a distance test - and whether the caster could land it on them at all is a
	# question about where the caster is STANDING, not about where it aims. So
	# both are settled once, here, instead of rebuilding the whole blast and
	# re-walking its line of sight for each of the hundreds of tiles it might
	# aim at.
	#
	# Same answer as building the tiles and looking for players in them. Not the
	# same price: a caster with three area skills and fifteen tiles of reach was
	# taking eleven seconds to decide one turn, which on the web build reads as
	# the game having died rather than as the game thinking. See ai_caster.
	#
	# Only blasts. A LINE or CONE is aimed as a direction from the caster, so
	# its tiles do not sit around the aim and the shortcut does not hold.
	var is_blast = skill.aoe_shape != SkillDefinition.AoEShape.LINE \
			and skill.aoe_shape != SkillDefinition.AoEShape.CONE
	#
	# A skill that moves its caster aims at the tile they arrive on, and nobody
	# arrives on a tile somebody is already standing on. Without this the best
	# aim for Blink Strike is the target's own tile - the blast catches them
	# from there, so it scores as a hit - and the blink quietly does nothing.
	var must_land = skill.teleports == SkillDefinition.TeleportWho.CASTER and not caster.is_empty()
	var catchable: Array[Vector2i] = []
	if is_blast:
		for index in groups[Group.PLAYERS]:
			var p = combatants[index]
			if not p.alive or is_hidden(p):
				continue
			# Exactly what filter_tiles_by_line_of_sight would have dropped, and
			# it has to stay exactly that or the AI writes off a target the
			# player is shown as reachable.
			if skill.respects_blocking and controller.terrain_blocks_sight(p.position, movement_class):
				continue
			catchable.append(p.position)
	for dx in range(-reach, reach + 1):
		var remaining = reach - absi(dx)
		for dy in range(-remaining, remaining + 1):
			var d = absi(dx) + absi(dy)
			if d < skill.min_range:
				continue
			var aim = caster_position + Vector2i(dx, dy)
			if must_land and not can_land_on(caster, aim):
				continue
			var count = 0
			if is_blast:
				for position in catchable:
					if get_position_distance(aim, position) > skill.aoe_radius:
						continue
					# Line of sight is a question about where the blast lands
					# now, so it is asked here rather than once per tile - but
					# only for somebody actually inside it, and the walk is at
					# most the blast's own radius.
					if skill.respects_blocking and not has_line_of_sight(aim, position, movement_class):
						continue
					count += 1
			else:
				var tiles = get_impact_tiles(skill, caster_position, aim, movement_class)
				for index in groups[Group.PLAYERS]:
					var p = combatants[index]
					if p.alive and not is_hidden(p) and p.position in tiles:
						count += 1
			if count > best_count:
				best_count = count
				best_aim = aim
	return {"position": best_aim, "count": best_count}


## How many living players would be hit if `skill` (assumed self-centred -
## caster_position and aim_position are the same) were used from `position`.
func count_players_in_blast(skill: SkillDefinition, position: Vector2i, movement_class: int) -> int:
	var tiles = get_impact_tiles(skill, position, position, movement_class)
	var count = 0
	for index in groups[Group.PLAYERS]:
		var p = combatants[index]
		# Nobody hidden: the Bomber would otherwise run at, and go off beside,
		# somebody it has no way of knowing is there.
		if p.alive and not is_hidden(p) and p.position in tiles:
			count += 1
	return count


## Whether comb could hit at least one living player with a self-centred
## `skill` from somewhere reachable within `movement_budget`.
func can_reach_blast(comb: Dictionary, skill: SkillDefinition, movement_budget: int) -> bool:
	var best_tile = find_best_reachable_tile(comb, movement_budget, func(tile):
		return float(count_players_in_blast(skill, tile, comb.movement_class))
	)
	return count_players_in_blast(skill, best_tile, comb.movement_class) > 0


## How many living players would NOT have a clear line of sight to
## `position` right now - i.e. how hidden it actually is. Checked from each
## player's own position and movement class, the same way a respects_blocking
## skill of theirs would check it - not just a "next to a wall" proxy.
func count_players_without_los(position: Vector2i) -> int:
	var count = 0
	for index in groups[Group.PLAYERS]:
		var p = combatants[index]
		if is_hidden(p):
			# Cover from somebody nobody can see is not worth walking for.
			continue
		if p.alive and not has_line_of_sight(p.position, position, p.movement_class):
			count += 1
	return count


## Manhattan distance from `tile` to the nearest living player, or -1 if there
## are none left.
func distance_to_nearest_player(tile: Vector2i) -> int:
	var best = -1
	for index in groups[Group.PLAYERS]:
		var p = combatants[index]
		# Keeping away from somebody hidden is knowing where they are.
		if not p.alive or is_hidden(p):
			continue
		var d = get_position_distance(tile, p.position)
		if best < 0 or d < best:
			best = d
	return best


## How safe `tile` is to stand on, for any archetype that would rather not be
## reached: genuine line-of-sight cover (count_players_without_los) PLUS plain
## distance from the nearest player.
##
## The distance half is the important one. Cover alone is uniformly 0 on an
## open stretch of map - every reachable tile scores identically, and
## find_best_reachable_tile() keeps the current tile on a tie - which is
## exactly why Caster and Priest used to plant themselves next to the players
## and never move when there was no wall around to hide behind. Distance always
## distinguishes tiles, so there is always a reason to back off.
##
## Distance is capped: past STANDOFF_CAP tiles nothing can reach them this turn
## anyway, so extra distance stops being worth anything and cover decides
## instead - this keeps a retreating unit in the fight rather than fleeing to
## the far corner of the map. The cap also bounds this score, so callers can
## safely add a dominating term on top (see HEAL_COVERAGE_WEIGHT).
const COVER_WEIGHT = 2.0
const STANDOFF_CAP = 8

func score_tile_safety(tile: Vector2i) -> float:
	var standoff = distance_to_nearest_player(tile)
	if standoff < 0:
		standoff = STANDOFF_CAP # no players left - nothing to keep away from
	return float(count_players_without_los(tile)) * COVER_WEIGHT + float(mini(standoff, STANDOFF_CAP))


## Every living combatant with an available reactive skill that would
## trigger if comb moved from `from_tile` to `to_tile` - a dry-run of the
## same transition check check_reactive_skills performs for real, without
## actually resolving anything. Returns an Array of {"reactor":Dictionary,
## "skill_key":String} entries, one per reactor that would trigger - a
## single move can provoke more than one attacker at once, so this checks
## all of them, not just the first found. Only compares the two given tiles
## directly rather than every intermediate step of a longer path, so it's
## an approximation for anything but a single-step move.
## Every living combatant with an available reactive skill that would
## trigger at some point if comb walked `path` (a sequence of grid tiles,
## starting with comb's current position) - checks every step transition
## along the real route, not just its overall start and end, so a path that
## dips into and back out of a threat's range partway through is correctly
## caught even when both endpoints look safe on their own. A dry-run of the
## same transition check check_reactive_skills performs for real, without
## actually resolving anything. Returns an Array of {"reactor":Dictionary,
## "skill_key":String} entries, one per reactor that would trigger - each
## reactor can only appear once, at whichever step first takes them out of
## its range, matching how the real check_reactive_skills processes a move.
func find_triggering_reactions_along_path(comb: Dictionary, path: Array) -> Array:
	var triggered = []
	var already_triggered = []
	for i in range(1, path.size()):
		var from_tile = path[i - 1]
		var to_tile = path[i]
		for reactor in combatants:
			if not reactor.alive or reactor == comb or reactor.reaction_used or reactor in already_triggered:
				continue
			if is_hidden(reactor) or is_hidden(comb):
				continue
			for skill_key in reactor.skill_list:
				var skill: SkillDefinition = SkillDatabase.skills[skill_key]
				if not skill.is_reactive:
					continue
				var valid_side = (reactor.side == comb.side) if skill.targets_ally else (reactor.side != comb.side)
				if not valid_side:
					continue
				var distance_before = rect_gap(rect_of(reactor), rect_of(comb, from_tile))
				var distance_after = rect_gap(rect_of(reactor), rect_of(comb, to_tile))
				# Same reach as the real check above, or the AI plans around
				# reactions that cannot happen and walks into ones that can.
				var reach = effective_max_range(reactor, skill)
				var was_in_range = distance_before >= skill.min_range and distance_before <= reach
				var now_in_range = distance_after >= skill.min_range and distance_after <= reach
				if was_in_range and not now_in_range:
					triggered.append({"reactor": reactor, "skill_key": skill_key})
					already_triggered.append(reactor)
					break
	return triggered


## The largest damage `skill` could deal to `victim` in one hit, ignoring
## accuracy and hit chance entirely. Used for a worst-case "could this possibly
## kill me" check, not an average.
##
## Worked out through the real damage function, so an AI weighing up whether to
## step past a guard is reading the same number the guard would actually deal.
## Estimating it from the effect's own amounts stopped being right the moment
## damage started coming from the caster's stats instead.
func get_max_possible_damage(skill: SkillDefinition, wielder: Dictionary, victim: Dictionary) -> int:
	var total = 0
	for effect in skill.all_effects():
		if effect.type == EffectDefinition.EffectType.DAMAGE:
			total += resisted_damage(victim, effect.damage_type, skill_damage(wielder, victim, skill))
	return total


## Given a tile an archetype's own positioning already picked as its best
## move (best_tile) in order to reach/act on intended_target, decides
## whether it's actually safe to go there, respecting the risk of provoking
## one or more opposing reactive skills at any point along the real route
## there (not just at the destination):
## - If the move wouldn't provoke anything, go there as planned.
## - If it would, and intended_target is among those who'd punish leaving,
##   don't reposition past them - stay and act from the current position
##   instead (attacking them only ever requires entering their range, never
##   leaving it, so this doesn't cost anything).
## - If it would provoke one or more other combatants, but their reactive
##   skills' combined worst case wouldn't kill comb outright, the
##   destination is still worth it - go there anyway.
## - Otherwise it's not worth the risk - stay put.
func avoid_needless_opportunity_attacks(comb: Dictionary, best_tile: Vector2i, intended_target: Dictionary) -> Vector2i:
	if best_tile == comb.position:
		return best_tile
	var path = controller.get_grid_path(comb.position, best_tile)
	if path.size() < 2:
		# No path found (or it's degenerate) - fall back to just the two
		# endpoints rather than skipping the check entirely.
		path = [comb.position, best_tile]
	var triggered = find_triggering_reactions_along_path(comb, path)
	if triggered.is_empty():
		return best_tile
	if not intended_target.is_empty():
		for entry in triggered:
			if entry.reactor == intended_target:
				return comb.position
	var total_possible_damage = 0
	for entry in triggered:
		var reactive_skill: SkillDefinition = SkillDatabase.skills[entry.skill_key]
		total_possible_damage += get_max_possible_damage(reactive_skill, entry.reactor, comb)
	if total_possible_damage < comb.hp:
		return best_tile
	return comb.position


## Moves comb (if needed and possible) to within skill's range of
## target_position. Returns true if comb ends up in range (whether it needed
## to move or already was), false if it couldn't get there this turn.
## If seek_cover is true, it always searches (even if already in range),
## weighing safety (score_tile_safety - cover AND distance from the nearest
## player) against how close to max_range it ends up: a meaningfully safer
## tile can win over a somewhat better-positioned one, though being in range
## at all still dominates everything else. Tune the balance via
## score_tile_safety's own weights.
## If avoid_reactive_target is given (non-empty), the chosen tile is also
## run through avoid_needless_opportunity_attacks (with that as the intended
## target) before actually moving there.
func move_into_range_of(comb: Dictionary, target_position: Vector2i, skill: SkillDefinition, movement_budget: int, seek_cover: bool = false, avoid_reactive_target: Dictionary = {}) -> bool:
	if is_effectively_in_range(skill, comb.position, target_position, comb.movement_class, comb) and not seek_cover:
		return true
	var tile: Vector2i
	if seek_cover:
		# Cover is only worth spending a turn's movement on if the move ends
		# with a shot. Nothing reachable being in range used to leave safety as
		# the only thing being scored, so the ranger walked to whichever nearby
		# tile hid it best, arrived unable to shoot, and had no movement left to
		# close with - then did the same thing again next turn, stepping between
		# two equally safe tiles for the whole fight while the players walked
		# around it. Better to not move at all here and let the caller spend the
		# full budget closing the distance.
		if not can_shoot_from_anywhere_reachable(comb, target_position, skill, movement_budget):
			return false
		tile = find_best_reachable_tile(comb, movement_budget, func(t):
			var range_score: float
			if is_effectively_in_range(skill, t, target_position, comb.movement_class, comb):
				# Any in-range (and, if applicable, unobstructed) position is
				# equally valid - no bonus for being specifically close to
				# max_range, so a large-range skill doesn't pull the AI
				# toward the far edge of it when it's already comfortably in
				# range. Safety alone decides between valid options.
				range_score = 1000.0
			else:
				var d = get_position_distance(t, target_position)
				range_score = -absf(float(d) - float(clampi(d, skill.min_range, skill.max_range)))
			return range_score + score_tile_safety(t)
		)
	else:
		tile = find_tile_at_ideal_range(comb, target_position, skill, movement_budget)
	if not avoid_reactive_target.is_empty():
		tile = avoid_needless_opportunity_attacks(comb, tile, avoid_reactive_target)
	if tile != comb.position:
		await controller.ai_move(tile)
	if not comb.alive:
		return false
	return is_effectively_in_range(skill, comb.position, target_position, comb.movement_class, comb)


## Whether `comb` is holding an element upgrade for their next spell.
func has_element_upgrade(comb: Dictionary) -> bool:
	for eff in comb.get("status_effects", []):
		if eff.get("stat", "") == "element_up":
			return true
	return false


## Every element `skill` would deal, raised or not.
##
## Only what the skill itself throws. A condition it inflicts keeps its own
## element, because a condition is a named thing - Burn is fire by definition,
## and a Burn that was sometimes plasma would be a second condition wearing the
## first one's name.
func elements_of(skill: SkillDefinition) -> Array:
	var found: Array = []
	for effect in skill.all_effects():
		if effect == null:
			continue
		if effect.type == EffectDefinition.EffectType.DAMAGE \
				or effect.type == EffectDefinition.EffectType.DAMAGE_OVER_TIME \
				or effect.type == EffectDefinition.EffectType.PUSH:
			if not effect.damage_type in found:
				found.append(effect.damage_type)
	return found


## Uses up `comb`'s element upgrade, if they are holding one and `skill` has an
## element it could raise. Marks the cast so every damage figure it produces
## reads the raised element, and says so in the log.
##
## A skill with nothing upgradeable about it - a heal, a physical swing, or one
## already throwing plasma - leaves the charge alone rather than wasting it.
func spend_element_upgrade(comb: Dictionary, skill: SkillDefinition):
	comb["element_upgraded_cast"] = false
	if not has_element_upgrade(comb):
		return
	var raisable := false
	for type in elements_of(skill):
		if Damage.can_upgrade(type):
			raisable = true
	if not raisable:
		return
	for i in range(comb.status_effects.size() - 1, -1, -1):
		if comb.status_effects[i].get("stat", "") == "element_up":
			comb.status_effects.remove_at(i)
			break
	comb["element_upgraded_cast"] = true
	update_combatants.emit(combatants)
	var became: Array = []
	for type in elements_of(skill):
		if Damage.can_upgrade(type):
			became.append("%s becomes %s" % [Damage.type_name(type),
				Damage.type_name(Damage.upgraded_form(type))])
	update_information.emit("[color=yellow]%s[/color] raises the element of %s - %s.
" % [
		comb.name, skill.name, ", ".join(became)])


## The element a hit from `attacker` actually lands as: the raised form while
## they are casting a spell they spent an upgrade on, and the written one
## otherwise.
func effective_damage_type(attacker: Dictionary, type: int) -> int:
	if attacker.get("element_upgraded_cast", false):
		return Damage.upgraded_form(type)
	return type


## Whether any tile `comb` can reach this turn would put `target_position` in
## range of `skill` - the question of whether there is a shot to be had at all,
## asked before any movement is spent looking for a good place to take it from.
func can_shoot_from_anywhere_reachable(comb: Dictionary, target_position: Vector2i, skill: SkillDefinition, movement_budget: int) -> bool:
	if is_effectively_in_range(skill, comb.position, target_position, comb.movement_class, comb):
		return true
	for tile in controller.get_reachable_tiles(comb.position, comb.movement_class, movement_budget, comb):
		if is_effectively_in_range(skill, tile, target_position, comb.movement_class, comb):
			return true
	return false


## Spends whatever movement `comb` has left backing away to the safest tile it
## can reach (see score_tile_safety), without breaking contact: any tile more
## than `reengage_cap` away from the reengage target is rejected outright, so
## it can always close again next turn instead of retreating out of the fight
## entirely. This is the "hit and run" second half that made the Ranger work,
## pulled out of ai_ranger so Caster (and, in its own coverage-constrained
## form, Priest) get the same behaviour rather than standing where they fired.
##
## `reengage_target` is who it intends to keep threatening; if that one died to
## the attack it just made, this falls back to the nearest surviving player.
##
## Note the retreat is checked against avoid_needless_opportunity_attacks with
## no intended target: that function's "don't reposition past the one you're
## going for" rule is explicitly about *approaching* (reaching someone only
## ever needs entering their range, never leaving it), and applying it to a
## retreat would forbid the disengage on exactly the turns it matters most.
## The lethality check still applies, so retreating never walks into a
## reaction that could kill.
## Spends whatever movement is left getting nearer to `target`, taking the
## safest of the tiles that get equally near.
##
## The mirror of retreat_with_remaining_movement: that one asks for the safest
## tile that stays in contact, this one asks for the nearest tile and uses
## safety to break the tie. Distance is weighted well above safety on purpose -
## a ranger that cannot shoot anybody has nothing to be safe for, and creeping
## one tile a turn towards cover it is already in is what it was doing before.
const APPROACH_WEIGHT := 10.0


func approach_with_remaining_movement(comb: Dictionary, target: Dictionary):
	if not comb.alive or controller.movement <= 0:
		return
	if target.is_empty() or not target.alive:
		target = find_nearest_enemy_of(comb)
	if target.is_empty():
		return
	var goal = target.position
	var closer = find_best_reachable_tile(comb, controller.movement, func(tile):
		return -float(get_position_distance(tile, goal)) * APPROACH_WEIGHT + score_tile_safety(tile)
	)
	closer = avoid_needless_opportunity_attacks(comb, closer, target)
	if closer != comb.position:
		await controller.ai_move(closer)


func retreat_with_remaining_movement(comb: Dictionary, reengage_target: Dictionary, reengage_cap: int):
	if not comb.alive or controller.movement <= 0:
		return
	var anchor = reengage_target
	if anchor.is_empty() or not anchor.alive:
		anchor = find_nearest_enemy_of(comb)
	if anchor.is_empty():
		return # nobody left to stay in contact with - combat is ending anyway
	var anchor_position = anchor.position
	var retreat_tile = find_best_reachable_tile(comb, controller.movement, func(tile):
		if get_position_distance(tile, anchor_position) > reengage_cap:
			return -1000.0
		return score_tile_safety(tile)
	)
	retreat_tile = avoid_needless_opportunity_attacks(comb, retreat_tile, {})
	if retreat_tile != comb.position:
		await controller.ai_move(retreat_tile)


## How many of comb's living allies it could still get into heal range of from
## `tile` - allies within `heal_reach` (the heal skill's range plus a turn's
## movement), so ones it can't reach right now but could close on next turn
## still count. The Priest treats this as the thing it must not trade away:
## a healer that has backed off somewhere lovely and safe but can no longer
## reach whoever needs healing has failed at the only job it has.
func count_allies_within_heal_reach(comb: Dictionary, tile: Vector2i, heal_reach: int) -> int:
	var count = 0
	for index in groups[comb.side]:
		var candidate = combatants[index]
		if not candidate.alive or candidate == comb:
			continue
		if get_position_distance(tile, candidate.position) <= heal_reach:
			count += 1
	return count


## The ally standing nearest to any living enemy - the one a healer should be
## keeping up with, because they are the one about to be hit. Empty when it is
## on its own, or when there is nobody left to fight.
func ally_nearest_the_enemy(comb: Dictionary) -> Dictionary:
	var closest = {}
	var best = 1 << 30
	for index in groups[comb.side]:
		var mate = combatants[index]
		if not mate.alive or mate == comb:
			continue
		for other in groups[1 - comb.side]:
			var foe = combatants[other]
			# Nobody is about to be hit by somebody the healer cannot see.
			if not foe.alive or is_hidden(foe):
				continue
			var gap = get_position_distance(mate.position, foe.position)
			if gap < best:
				best = gap
				closest = mate
	return closest


## The Priest's equivalent of retreat_with_remaining_movement: spends whatever
## movement it has left on the safest tile that still keeps as many allies as
## possible inside heal reach. Coverage is weighted far above safety (see
## score_tile_safety, which is bounded by STANDOFF_CAP precisely so this can
## dominate it), so it will happily stand somewhere exposed if that's what
## staying able to heal a distant ally costs - but among tiles that cover the
## same allies it always takes the safest, which is what stops it planting
## itself next to the players and never moving.
const HEAL_COVERAGE_WEIGHT = 100.0

## How hard it is pulled towards whoever is nearest the fighting, once coverage
## is settled. It sits between the two terms either side of it: a step of
## coverage is worth 100 and can never be traded away for this, while all the
## safety in the world is worth about 16 and this outweighs it.
##
## Without it, a healer whose allies are all within reach from everywhere simply
## took the best cover on the map - which on the laboratory is a corner behind a
## wall, where one sat out an entire fight. Coverage ties nearly everywhere, so
## something had to break the tie other than hiding.
##
## Deliberately not capped. A capped version was tried and did nothing: a healer
## eighteen tiles from the fighting had every tile it could reach sitting past
## the cap, so they all scored the same and hiding won the tie again - the cap
## switched the rule off in exactly the case it was written for. Uncapped is
## safe here because find_best_reachable_tile only offers tiles within one
## turn's movement, so the spread across candidates is at most twice that - well
## under the 100 a single ally of coverage is worth.
const HEAL_ATTENDANCE_WEIGHT = 4.0

func reposition_healer(comb: Dictionary, heal_reach: int):
	if not comb.alive or controller.movement <= 0:
		return
	# Whoever is closest to the enemy is who is about to need mending.
	var front = ally_nearest_the_enemy(comb)
	var post = front.position if not front.is_empty() else comb.position
	var tile = find_best_reachable_tile(comb, controller.movement, func(t):
		var attendance = -float(get_position_distance(t, post))
		return float(count_allies_within_heal_reach(comb, t, heal_reach)) * HEAL_COVERAGE_WEIGHT \
				+ attendance * HEAL_ATTENDANCE_WEIGHT \
				+ score_tile_safety(t)
	)
	tile = avoid_needless_opportunity_attacks(comb, tile, {})
	if tile != comb.position:
		await controller.ai_move(tile)


## --- Weighing what a turn could do ---
##
## The archetypes used to choose by counting: the caster took whichever spell
## caught the most players, the ranger its longest reach, the rusher its
## shortest - whatever any of them would actually do. These weigh the hit
## instead, through predict_hit, the arithmetic the prompt shown to a player
## while aiming uses: damage through the target's defence and resistances,
## whether a contest would be won or shrugged off, whether it would finish
## them. And they count the cost of catching their own side, which counting
## players never did: a Sorcerer's Fireball burns everybody within five tiles,
## and was aimed as though its own side were not standing there.

## Finishing somebody, on top of the damage it takes.
const AI_KILL_BONUS := 60.0
## Each condition a hit leaves on somebody not already carrying it.
const AI_CONDITION_VALUE := 15.0
## A pull towards whoever is already hurt, scaled by how much of their health is
## gone - so a fight is finished rather than spread thin.
const AI_HURT_BONUS := 20.0
## A pull towards whoever the last enemy to attack went for.
const AI_FOCUS_BONUS := 25.0
## How much each point of harm to its own side counts against a plan, on top of
## AI_ALLY_CAUGHT for catching them at all. Heavy on purpose: an enemy burning
## its own side reads to the player as the AI being foolish, whatever the sums
## say, so it takes a much better blast than the one that spares them.
const AI_ALLY_HARM := 3.0
const AI_ALLY_CAUGHT := 40.0
## Catching itself in its own blast: never worth it.
const AI_SELF_HARM := 1000.0

## Who the last enemy to attack went for. See AI_FOCUS_BONUS.
var _ai_focus_id := -1


## What landing `skill` on `target` would be worth to `attacker`, an opponent
## of theirs, weighted by the chance of it landing. Nothing at all for a hit
## that would do nothing: the pulls towards the hurt and the focused only ever
## sweeten a hit that does something.
func ai_target_value(attacker: Dictionary, target: Dictionary, skill: SkillDefinition) -> float:
	var hit = predict_hit(attacker, target, skill)
	var worth := float(hit.damage)
	if hit.wins:
		for effect in skill.all_effects():
			if effect == null or effect.applies_to_caster or effect.condition == null:
				continue
			if effect.type == EffectDefinition.EffectType.CONDITION and not _carries(target, effect.condition):
				worth += AI_CONDITION_VALUE
	if worth <= 0.0:
		return 0.0
	if hit.lethal:
		worth += AI_KILL_BONUS
	var most = maxf(float(get_effective_stat(target, "max_hp")), 1.0)
	worth += AI_HURT_BONUS * clampf(1.0 - float(target.hp) / most, 0.0, 1.0)
	if target.get("id", -2) == _ai_focus_id:
		worth += AI_FOCUS_BONUS
	return worth * float(hit.hit_chance) / 100.0


func _carries(comb: Dictionary, condition: ConditionDefinition) -> bool:
	for eff in comb.get("status_effects", []):
		if eff.get("stat", "") == "condition" and eff.get("condition") == condition:
			return true
	return false


## What catching each combatant with `skill` would be worth to `comb`: an
## opponent's value, the harm to one of its own side as a cost - only for a
## skill that catches both sides, since nothing else can - and itself as all but
## ruled out. Anybody hidden from it is left off, as they are for aiming at.
func ai_worth_table(comb: Dictionary, skill: SkillDefinition) -> Dictionary:
	var table := {}
	# Taunted: the taunter is the only one of the other side worth anything.
	var taunter := taunted_by(comb)
	for other in combatants:
		if not other.alive:
			continue
		if not taunter.is_empty() and other.side != comb.side and other != taunter:
			continue
		# Up on somebody (Climb), nobody can reach them.
		if other.has("riding"):
			continue
		var id = other.get("id", -1)
		if id == comb.get("id", -2):
			if skill.affects_both_sides:
				table[id] = -AI_SELF_HARM
		elif other.side == comb.side:
			if skill.affects_both_sides:
				var hit = predict_hit(comb, other, skill)
				table[id] = -AI_ALLY_CAUGHT - AI_ALLY_HARM * (float(hit.damage) + (AI_KILL_BONUS if hit.lethal else 0.0))
		elif not is_hidden(other):
			var value = ai_target_value(comb, other, skill)
			if value > 0.0:
				table[id] = value
	return table


## Whether `comb` could use `skill` on the other side at all right now.
func _ai_plannable(comb: Dictionary, skill: SkillDefinition) -> bool:
	if skill == null or skill.targets_ally or skill.kills_caster:
		return false
	# A blink or a carry needs a landing tile worked out, which is the copycat's
	# business rather than this.
	if skill.teleports != SkillDefinition.TeleportWho.NOBODY:
		return false
	# A Gate Nade whose spell is no part of theirs stays in the pocket.
	if skill is GateNadeDefinition and not can_use_gate_nade(comb, skill):
		return false
	# Hacking is a player's minigame; talking somebody round, paying them off and
	# climbing them are the party's.
	if _hacks(skill) or skill.needs_leverage or _bribes(skill) or _climbs(skill):
		return false
	return can_afford_skill(comb, skill) and meets_level_for(comb, skill)


## Everything `comb` could spend its main action on: its skills, its spells,
## and anything in an enemy's pocket to throw at somebody.
func _ai_main_keys(comb: Dictionary) -> Array:
	var keys = main_skills_of(comb).duplicate()
	for key in spell_skills_of(comb):
		if not SkillDatabase.skills[key].is_secondary and not keys.has(key):
			keys.append(key)
	if comb.side != 0:
		for key in items_of(comb):
			var item: ItemDefinition = ItemDatabase.item(key)
			if item != null and item.deals_damage and not item.targets_ally and not keys.has(key) \
					and SkillDatabase.skills.has(key):
				keys.append(key)
	# Declared moves are announced on their own (_ai_declare), not swung now.
	return keys.filter(func(key): return not SkillDatabase.skills[key].declared)


## How badly hurt an enemy has to be before they drink what is in their pocket.
const AI_DRINK_BELOW := 0.5


## Badly hurt with something to mend it in their pocket: they drink it, and
## that is their main action. True when they did.
func _ai_drink_from_pocket(comb: Dictionary) -> bool:
	if comb.side == 0 or comb.hp > comb.max_hp * AI_DRINK_BELOW or comb.get("skill_used_this_turn", false):
		return false
	for key in items_of(comb):
		var item: ItemDefinition = ItemDatabase.item(key)
		if item == null or not item.targets_ally or not SkillDatabase.skills.has(key):
			continue
		if item is GateNadeDefinition and not can_use_gate_nade(comb, item):
			continue
		var mends := false
		for effect in item.effects:
			if effect != null and effect.type == EffectDefinition.EffectType.HEAL:
				mends = true
		if not mends:
			continue
		update_information.emit("[color=yellow]%s[/color] drinks a %s.\n" % [comb.name, item.name])
		await use_skill(key, comb, comb.position, false)
		return true
	return false


## Every tile worth aiming `skill` at, and what catching whoever stands around
## it would be worth - `comb` itself left out, since whether it is caught depends
## on where it stands. Only tiles near somebody worth hitting are asked about: a
## blast that catches none of them is worth nothing wherever it lands, and asking
## about every tile in reach is what once took a caster eleven seconds.
##
## A LINE or CONE is aimed as a direction, so its candidates are the people
## worth hitting, scored per standing tile in _ai_best_aim_from.
func _ai_aim_scores(comb: Dictionary, skill: SkillDefinition, worth: Dictionary) -> Dictionary:
	var scores := {}
	var others := []
	for other in combatants:
		var id = other.get("id", -1)
		if worth.has(id) and id != comb.get("id", -2):
			others.append(other)
	var radius: int = skill.aoe_radius
	var blast = skill.aoe_shape == SkillDefinition.AoEShape.DIAMOND
	for other in others:
		if worth[other.id] <= 0.0:
			continue
		if not blast:
			# Aimed at whichever of their tiles is nearest, for somebody bigger.
			scores[nearest_tile_of(other, comb.position)] = 0.0
			continue
		for dx in range(-radius, radius + 1):
			var span = radius - absi(dx)
			for dy in range(-span, span + 1):
				scores[other.position + Vector2i(dx, dy)] = 0.0
	if not blast:
		return scores
	for aim in scores:
		var total := 0.0
		for other in others:
			if get_position_distance(aim, other.position) > radius:
				continue
			# The same test find_best_aim_and_count makes, so a blast is judged
			# to reach exactly who it does.
			if skill.respects_blocking and radius > 0:
				if controller.terrain_blocks_sight(other.position, comb.movement_class):
					continue
				if not has_line_of_sight(aim, other.position, comb.movement_class):
					continue
			total += worth[other.id]
		scores[aim] = total
	return scores


## The best tile to aim `skill` at from `standing`, and what it is worth there.
func _ai_best_aim_from(comb: Dictionary, skill: SkillDefinition, standing: Vector2i, worth: Dictionary, aims: Dictionary) -> Dictionary:
	var best := {"aim": standing, "score": 0.0}
	var reach = effective_max_range(comb, skill)
	var radius: int = skill.aoe_radius
	var blast = skill.aoe_shape == SkillDefinition.AoEShape.DIAMOND
	var own: float = worth.get(comb.get("id", -1), 0.0)
	for aim in aims:
		# From whichever of their tiles stood there is nearest, for somebody bigger.
		var from := standing
		if comb.get("span", 1) > 1:
			var square := rect_of(comb, standing)
			from = Vector2i(clampi(aim.x, square.position.x, square.end.x - 1), clampi(aim.y, square.position.y, square.end.y - 1))
		var d = get_position_distance(from, aim)
		if d > reach or d < skill.min_range:
			continue
		var score := 0.0
		if blast:
			if radius == 0 and skill.respects_blocking \
					and not has_line_of_sight(from, aim, terrain_class(comb), comb.get("size", Sizes.Size.HUMAN)):
				continue
			score = aims[aim]
			# Itself, stood inside its own blast.
			if own != 0.0 and d <= radius:
				score += own
		else:
			var tiles = get_impact_tiles(skill, standing, aim, comb.movement_class)
			for other in combatants:
				var id = other.get("id", -1)
				if not worth.has(id):
					continue
				var at = standing if id == comb.get("id", -2) else other.position
				if at in tiles:
					score += worth[id]
		if score > best.score:
			best = {"aim": aim, "score": score}
	return best


## The best of `skill_keys` for `comb` to use on the other side this turn, from
## anywhere within `budget` tiles: which skill, where to stand, where to aim, and
## what it is worth. `tile_bonus`, when given, has its say about each standing
## tile - how safe it is, for anybody who would rather not be reached. An empty
## skill when nothing is worth doing. Staying put wins a tie.
func ai_plan_attack(comb: Dictionary, skill_keys: Array, budget: int, tile_bonus: Callable = Callable()) -> Dictionary:
	var plan := {"skill": "", "tile": comb.position, "aim": comb.position, "score": 0.0}
	var standing: Array = [comb.position]
	if budget > 0:
		for tile in controller.get_reachable_tiles(comb.position, comb.movement_class, budget, comb):
			if tile != comb.position:
				standing.append(tile)
	var bonus_of := {}
	for key in skill_keys:
		var skill: SkillDefinition = SkillDatabase.skills.get(key)
		if not _ai_plannable(comb, skill):
			continue
		var worth = ai_worth_table(comb, skill)
		var aims = _ai_aim_scores(comb, skill, worth)
		if aims.is_empty():
			continue
		for tile in standing:
			var found = _ai_best_aim_from(comb, skill, tile, worth, aims)
			if found.score <= 0.0:
				continue
			var total: float = found.score
			if tile_bonus.is_valid():
				if not bonus_of.has(tile):
					bonus_of[tile] = tile_bonus.call(tile)
				total += bonus_of[tile]
			if total > plan.score:
				plan = {"skill": key, "tile": tile, "aim": found.aim, "score": total}
	return plan


## Whoever a plan is mainly aimed at: the opponent it catches who is worth the
## most. What avoiding a reaction on the way in, and focusing, are measured
## against.
func _ai_primary(comb: Dictionary, skill_key: String, standing: Vector2i, aim: Vector2i) -> Dictionary:
	var skill: SkillDefinition = SkillDatabase.skills[skill_key]
	var tiles = []
	if skill.aoe_shape != SkillDefinition.AoEShape.DIAMOND:
		tiles = get_impact_tiles(skill, standing, aim, comb.movement_class)
	var best := {}
	var best_value := 0.0
	for other in combatants:
		if not other.alive or other.side == comb.side or is_hidden(other):
			continue
		var caught = other.position in tiles if not tiles.is_empty() \
				else get_position_distance(aim, other.position) <= skill.aoe_radius
		if not caught:
			continue
		var value = ai_target_value(comb, other, skill)
		if value > best_value:
			best_value = value
			best = other
	return best


## Carries out a plan from ai_plan_attack: walks to its tile, unless the walk
## would hand somebody a reaction that could kill it - then it acts from where
## it stands, if there is still anything worth doing from there - and uses the
## skill. Returns whether it acted.
func _ai_carry_out(comb: Dictionary, plan: Dictionary, skill_keys: Array, tile_bonus: Callable = Callable()) -> bool:
	if plan.skill == "":
		return false
	if plan.tile != comb.position:
		var aimed_at = _ai_primary(comb, plan.skill, plan.tile, plan.aim)
		if avoid_needless_opportunity_attacks(comb, plan.tile, aimed_at) != plan.tile:
			plan = ai_plan_attack(comb, skill_keys, 0, tile_bonus)
			if plan.skill == "":
				return false
	if plan.tile != comb.position:
		await controller.ai_move(plan.tile)
	if not comb.alive:
		return false
	var primary = _ai_primary(comb, plan.skill, comb.position, plan.aim)
	if not primary.is_empty():
		_ai_focus_id = primary.id
	await use_skill(plan.skill, comb, plan.aim, false)
	return true


## Spends the secondary action on a hit, when one is in reach of where it now
## stands - the Barbarian's Follow-up, once it has learned it. Only the Priest
## ever used a secondary before this; everybody else left half of every turn.
func ai_secondary_attack(comb: Dictionary) -> bool:
	if not comb.alive or comb.get("secondary_used_this_turn", false):
		return false
	if has_restriction(comb, "prevents_secondary"):
		return false
	var keys = secondary_skills_of(comb).duplicate()
	for key in spells_in_slot(comb, true):
		if not keys.has(key):
			keys.append(key)
	var plan = ai_plan_attack(comb, keys, 0)
	if plan.skill == "":
		return false
	var primary = _ai_primary(comb, plan.skill, comb.position, plan.aim)
	if not primary.is_empty():
		_ai_focus_id = primary.id
	await use_skill(plan.skill, comb, plan.aim, false, true)
	return true


## Who is most worth going after with any of `skill_keys`, reachable or not -
## where somebody with nothing in reach should be heading. The nearest opponent
## when nobody is worth anything.
func _ai_most_wanted(comb: Dictionary, skill_keys: Array) -> Dictionary:
	var best := {}
	var best_value := 0.0
	for key in skill_keys:
		var skill: SkillDefinition = SkillDatabase.skills.get(key)
		if not _ai_plannable(comb, skill):
			continue
		for other in combatants:
			if not other.alive or other.side == comb.side or is_hidden(other):
				continue
			var value = ai_target_value(comb, other, skill)
			if value > best_value:
				best_value = value
				best = other
	return best if not best.is_empty() else find_nearest_enemy_of(comb)


## Default enemy behaviour: get stuck in. Whatever in its kit is worth the most
## from anywhere it can reach this turn - a Sweep Strike through two players
## over a Greatsword into one - then its secondary, if it has one in reach.
## With nothing in reach it spends the main action on Run, when it has it, and
## closes on whoever is most worth reaching; the walk is kept clear of any
## reaction that could finish it on the way in, either way.
func ai_melee_rush(comb: Dictionary):
	var target = find_nearest_enemy_of(comb)
	if target.is_empty():
		await advance_turn()
		return
	var keys = _ai_main_keys(comb)
	# Borrowing a greatsword stays the last resort for somebody with nothing of
	# their own that hurts - see melee_fallback_for.
	var hurts := false
	for key in keys:
		if SkillDatabase.skills[key].deals_damage:
			hurts = true
	if not hurts:
		keys.append(melee_fallback_for(comb))
	var plan = ai_plan_attack(comb, keys, movement_budget_of(comb))
	if await _ai_carry_out(comb, plan, keys):
		await ai_secondary_attack(comb)
		await advance_turn()
		return
	if not comb.alive:
		return
	var wanted = _ai_most_wanted(comb, keys)
	var run: SkillDefinition = SkillDatabase.skills.get("run")
	if "run" in comb.skill_list and run != null and can_afford_skill(comb, run) \
			and meets_level_for(comb, run) and not comb.get("skill_used_this_turn", false) \
			and wasted_on(comb, run) == "":
		# Nothing to swing at this turn anyway, so the main action is worth
		# more as ground covered - unless something roots them, when there
		# is no ground to cover.
		await use_skill("run", comb, comb.position, false)
	await approach_with_remaining_movement(comb, wanted)
	await ai_secondary_attack(comb)
	await advance_turn()


## If it can already reach (get adjacent to, per Self Destruct's blast)
## a player using this turn's ordinary movement, it moves to wherever hits
## the most players and self-destructs. If it can't reach yet, it uses Run
## to close distance instead (repeating on later turns until it can) rather
## than wasting its one skill on Self Destruct out of range.
func ai_hit_and_explode(comb: Dictionary):
	var target = find_nearest_enemy_of(comb)
	if target.is_empty():
		await advance_turn()
		return
	if not "self_destruct" in comb.skill_list:
		await ai_melee_rush(comb)
		return
	var self_destruct: SkillDefinition = SkillDatabase.skills["self_destruct"]
	var movement_budget = movement_budget_of(comb)
	var can_reach_now = can_reach_blast(comb, self_destruct, movement_budget)
	if not can_reach_now and "run" in comb.skill_list:
		# Rooted, a Run gets it nowhere: it waits for the root to go instead.
		if wasted_on(comb, SkillDatabase.skills.get("run")) == "":
			await use_skill("run", comb, comb.position, false)
		if comb.alive and controller.movement > 0:
			var approach_tile = find_best_reachable_tile(comb, controller.movement, func(tile):
				return -float(get_position_distance(tile, target.position))
			)
			if approach_tile != comb.position:
				await controller.ai_move(approach_tile)
		await advance_turn()
		return
	var best_tile = find_best_reachable_tile(comb, movement_budget, func(tile):
		return float(count_players_in_blast(self_destruct, tile, comb.movement_class))
	)
	if best_tile != comb.position:
		await controller.ai_move(best_tile)
	if comb.alive:
		await use_skill("self_destruct", comb, comb.position, false)
	await advance_turn()


## Fights from range with single-target skills, always aiming at whichever
## living player currently has the lowest hp. If its own hp drops below
## half its max (and it has a HEAL skill), it heals itself instead of
## attacking - healing is always usable on itself regardless of position,
## so this never needs to move for that. Otherwise, avoids provoking a
## potentially-lethal attack of opportunity while closing in (see
## avoid_needless_opportunity_attacks), same as Healer and Caster.
## Fights from range with single-target skills, always aiming at whichever
## living player currently has the lowest hp. If its own hp drops below
## half its max (and it has a HEAL skill), it heals itself instead of
## attacking - healing is always usable on itself regardless of position,
## so this never needs to move for that. After a successful attack, retreats
## with any remaining movement - genuine "hit and run" - but capped so it
## doesn't retreat further than it could close again next turn (max_range +
## its own movement), and preferring a position hidden from players (cover)
## over pure distance where that's achievable within the cap. Avoids
## provoking a potentially-lethal attack of opportunity both closing in and
## retreating (see avoid_needless_opportunity_attacks), same as Healer and
## Caster.
func ai_ranger(comb: Dictionary):
	var movement_budget = movement_budget_of(comb)
	var effective_max_hp = get_effective_stat(comb, "max_hp")
	if comb.hp * 2 < effective_max_hp:
		var heal_skill_key = find_skill_of_type(comb, EffectDefinition.EffectType.HEAL)
		if heal_skill_key != "":
			var heal_skill: SkillDefinition = SkillDatabase.skills[heal_skill_key]
			if await move_into_range_of(comb, comb.position, heal_skill, movement_budget):
				await use_skill(heal_skill_key, comb, comb.position, false)
				await advance_turn()
				return
	# The shot worth the most - skill and target together, weighed by what it
	# would actually do to them - among those it can take from somewhere it can
	# reach. It used to be the lowest health on the board, with whichever skill
	# reached furthest, whatever either would do to the other.
	var choice = _ai_best_shot(comb, movement_budget)
	var target: Dictionary = choice.target
	if target.is_empty():
		await advance_turn()
		return
	var skill_key: String = choice.skill
	var skill: SkillDefinition = SkillDatabase.skills[skill_key]
	var attacked = await move_into_range_of(comb, target.position, skill, movement_budget, true, target)
	if attacked:
		_ai_focus_id = target.id
		await use_skill(skill_key, comb, target.position, false)
		await ai_secondary_attack(comb)
		await retreat_with_remaining_movement(comb, target, skill.max_range + movement_budget)
	else:
		# Nothing it could reach from anywhere it could get to. It used to spend
		# the rest of the turn standing still, because the tile it was already
		# on was as safe as any other and safety was all that was being scored -
		# so a ranger out of range simply waited, all fight, while the players
		# walked around it. Close the distance instead, and keep preferring
		# cover among the tiles that close it.
		await approach_with_remaining_movement(comb, target)
	await advance_turn()


## The single shot worth the most to `comb` this turn: {skill, target}. The
## skill and target it can reach from somewhere within `budget` when there is
## one; otherwise the one most worth closing on, with the skill it would use -
## and an empty target when there is nobody at all.
func _ai_best_shot(comb: Dictionary, budget: int) -> Dictionary:
	var reachable := {"skill": "", "target": {}, "value": 0.0}
	var wanted := {"skill": "", "target": {}, "value": 0.0}
	for key in _ai_main_keys(comb):
		var skill: SkillDefinition = SkillDatabase.skills[key]
		if not _ai_plannable(comb, skill) or skill.aoe_radius > 0:
			continue
		for other in combatants:
			if not other.alive or other.side == comb.side or is_hidden(other):
				continue
			var value = ai_target_value(comb, other, skill)
			if value <= 0.0:
				continue
			if value > wanted.value:
				wanted = {"skill": key, "target": other, "value": value}
			if value > reachable.value and can_shoot_from_anywhere_reachable(comb, other.position, skill, budget):
				reachable = {"skill": key, "target": other, "value": value}
	if not reachable.target.is_empty():
		return reachable
	if not wanted.target.is_empty():
		return wanted
	# Nothing it has would do anything to anybody: its best reach, at whoever
	# is nearest, so it still closes the distance.
	return {"skill": find_best_single_target_skill(comb), "target": find_nearest_enemy_of(comb), "value": 0.0}


## Prioritises healing its most injured ally, then cleansing its most
## afflicted ally, then just repositioning - preferring a safer position (see
## score_tile_safety) over a marginally better one for the job, at each of
## these steps, and avoiding provoking a potentially-lethal attack of
## opportunity while doing so (see avoid_needless_opportunity_attacks). Only
## attacks as a last resort, and only if an enemy is already adjacent.
##
## Whatever it does, it finishes the turn by repositioning (see
## reposition_healer): staying able to reach its allies always comes first -
## it will stand somewhere exposed if that's the price of covering a distant
## one - but among tiles that cover the same allies it takes the safest, so it
## no longer plants itself beside the players and stops moving. Previously the
## idle branch scored only "hug my nearest ally, plus cover", which on an open
## map with no line of sight to break came down to hugging alone, and left it
## standing still in exactly the spot the players were walking towards.
func ai_healer(comb: Dictionary):
	var movement_budget = movement_budget_of(comb)
	var heal_skill_key = find_skill_of_type(comb, EffectDefinition.EffectType.HEAL)
	# How far away an ally can be and still be healable next turn - the
	# constraint reposition_healer refuses to trade away for safety.
	var heal_reach = movement_budget
	if heal_skill_key != "":
		heal_reach += SkillDatabase.skills[heal_skill_key].max_range
	if heal_skill_key != "":
		var patient = find_most_injured_ally(comb)
		if not patient.is_empty():
			var skill: SkillDefinition = SkillDatabase.skills[heal_skill_key]
			if await move_into_range_of(comb, patient.position, skill, movement_budget, true, patient):
				await use_skill(heal_skill_key, comb, patient.position, false)
				# Mending somebody spends the main action and nothing else, so
				# the secondary is still there to lift a condition with.
				await cleanse_as_secondary(comb)
				await reposition_healer(comb, heal_reach)
				await advance_turn()
				return
	# Nobody worth healing. A cleanse that costs the secondary is free to take
	# on the way to doing something else; one that costs the main action is the
	# turn, and ends it.
	var cleanse_skill_key = find_skill_of_type(comb, EffectDefinition.EffectType.DISPEL)
	if cleanse_skill_key != "" and comb.alive:
		var afflicted = find_most_afflicted_ally(comb)
		if not afflicted.is_empty():
			var skill: SkillDefinition = SkillDatabase.skills[cleanse_skill_key]
			if await move_into_range_of(comb, afflicted.position, skill, movement_budget, true, afflicted):
				await use_skill(cleanse_skill_key, comb, afflicted.position, false, skill.is_secondary)
				if not skill.is_secondary:
					await reposition_healer(comb, heal_reach)
					await advance_turn()
					return
	if not comb.alive:
		return
	var nearest_enemy = find_nearest_enemy_of(comb)
	if not nearest_enemy.is_empty() and get_distance(comb, nearest_enemy) == 1:
		await use_skill(melee_fallback_for(comb), comb, nearest_enemy.position, false)
		await cleanse_as_secondary(comb)
		await reposition_healer(comb, heal_reach)
		await advance_turn()
		return
	await cleanse_as_secondary(comb)
	await reposition_healer(comb, heal_reach)
	await advance_turn()


## Lifts a condition off whoever most needs it, if that costs only the
## secondary action and somebody is already in reach.
##
## Deliberately without moving: by the time this is called the main action has
## decided where the healer is standing, and walking off to cleanse somebody
## would undo the positioning that mattered more. It is a turn's spare half,
## taken when it happens to be there.
func cleanse_as_secondary(comb: Dictionary) -> bool:
	if not comb.alive or comb.get("secondary_used_this_turn", false):
		return false
	if has_restriction(comb, "prevents_secondary"):
		return false
	var key = find_skill_of_type(comb, EffectDefinition.EffectType.DISPEL)
	if key == "":
		return false
	var skill: SkillDefinition = SkillDatabase.skills[key]
	if not skill.is_secondary or not can_afford_skill(comb, skill) or not meets_level_for(comb, skill):
		return false
	var afflicted = find_most_afflicted_ally(comb)
	if afflicted.is_empty():
		return false
	if not is_effectively_in_range(skill, comb.position, afflicted.position, comb.movement_class, comb):
		return false
	await use_skill(key, comb, afflicted.position, false, true)
	return true


## Weighs every spell and skill in its kit - blasts and single shots alike -
## from every tile it could stand on, by what each would actually do (see
## ai_plan_attack), with a little for standing where fewer players can see it:
## a meaningfully safer casting spot can win over a marginally better one,
## though hitting nobody never does. Its own side caught in a blast counts
## against it, and itself caught all but rules a blast out - Fireball burns
## everybody within five tiles of where it lands, and was aimed as though the
## caster's own side were not standing there. Falls back to approaching and
## plain-attacking the nearest enemy when nothing could reach anybody.
##
## CASTER_COVER is what one player unable to see the casting tile is worth, in
## the same units as a hit - roughly a third of a middling one.
const CASTER_COVER := 10.0

func ai_caster(comb: Dictionary):
	var target = find_nearest_enemy_of(comb)
	if target.is_empty():
		await advance_turn()
		return
	var movement_budget = movement_budget_of(comb)
	var keys = _ai_main_keys(comb)
	var cover = func(t): return float(count_players_without_los(t)) * CASTER_COVER
	var plan = ai_plan_attack(comb, keys, movement_budget, cover)
	if await _ai_carry_out(comb, plan, keys, cover):
		await ai_secondary_attack(comb)
		# Back off with whatever movement is left rather than standing where it
		# just fired from - a spell's range is long enough that the casting
		# tile is almost never the tile you want to be standing on when the
		# players get their turn.
		await retreat_with_remaining_movement(comb, target, SkillDatabase.skills[plan.skill].max_range + movement_budget)
		await advance_turn()
		return
	if not comb.alive:
		return
	if plan.skill != "":
		# Everything worth doing meant walking into a reaction that could kill
		# it, and nothing was worth doing from where it stands.
		await advance_turn()
		return
	# No AoE skill can hit anyone from anywhere reachable - fall back to a
	# normal approach-and-attack instead of wasting the turn.
	await controller.ai_process(target.position)
	if comb.alive:
		await use_skill(melee_fallback_for(comb), comb, target.position, false)
	await advance_turn()


## Picks who a Copycat should aim a copied ally-targeting skill at: the most
## injured ally for a HEAL skill, the most afflicted ally for a DISPEL
## skill, or comb itself for anything else (a plain buff like Run or
## Vitality) - falling back to comb itself if there's no better candidate
## (e.g. a HEAL skill but nobody's actually hurt).
func pick_ally_target_for_skill(comb: Dictionary, skill: SkillDefinition) -> Dictionary:
	for effect in skill.all_effects():
		if effect.type == EffectDefinition.EffectType.HEAL:
			var patient = find_most_injured_ally(comb)
			return patient if not patient.is_empty() else comb
		if effect.type == EffectDefinition.EffectType.DISPEL:
			var afflicted = find_most_afflicted_ally(comb)
			return afflicted if not afflicted.is_empty() else comb
	return comb


## Copies whichever skill a player most recently used - offensive skills get
## aimed at the nearest enemy (rushing them like ai_melee_rush, moving to
## that skill's range rather than melee range specifically); ally-targeting
## skills get aimed at whichever of its own allies benefits most, itself
## included (see pick_ally_target_for_skill) - so copying a player's Heal
## heals its neediest ally, but copying Run just buffs itself. If nothing's
## been used yet, it has nothing to copy and simply passes its turn, rather
## than defaulting to a generic melee rush.
func ai_copycat(comb: Dictionary):
	if last_player_skill_used == "" or not SkillDatabase.skills.has(last_player_skill_used):
		await advance_turn()
		return
	var skill_key = last_player_skill_used
	var skill: SkillDefinition = SkillDatabase.skills[skill_key]
	var movement_budget = movement_budget_of(comb)
	if skill.targets_ally:
		var ally_target = pick_ally_target_for_skill(comb, skill)
		if await move_into_range_of(comb, ally_target.position, skill, movement_budget):
			await use_skill(skill_key, comb, ally_target.position, false)
		await advance_turn()
		return
	var target = find_nearest_enemy_of(comb)
	if target.is_empty():
		await advance_turn()
		return
	if await move_into_range_of(comb, target.position, skill, movement_budget):
		await use_skill(skill_key, comb, aim_for_copied_skill(comb, skill, target), false)
		await advance_turn()
		return
	if not comb.alive:
		return
	# Couldn't reach for the copied skill - fall back to a normal
	# rush-and-melee approach so the turn isn't wasted.
	await controller.ai_process(target.position)
	if comb.alive:
		await use_skill(melee_fallback_for(comb), comb, target.position, false)
	await advance_turn()


## Where a copied skill should actually be pointed.
##
## Straight at whoever it is chasing, for everything that simply travels to its
## target. A skill that moves its caster is the exception: what it aims at is
## where the caster arrives, so aiming at somebody means trying to stand on
## them. Blink Strike copied that way teleported nowhere and swung anyway - the
## radius-1 burst still caught the target from their own tile, which is why it
## read as an attack with the blink missing rather than as a broken skill.
##
## find_best_aim_and_count already refuses a tile the caster cannot land on, so
## what comes back is open ground that still catches somebody. Falling back to
## the target's tile when it finds nothing keeps a turn from being wasted.
func aim_for_copied_skill(comb: Dictionary, skill: SkillDefinition, target: Dictionary) -> Vector2i:
	if skill.teleports != SkillDefinition.TeleportWho.CASTER:
		return target.position
	var found = find_best_aim_and_count(skill, comb.position, comb.movement_class, comb)
	if found.count > 0:
		return found.position
	return target.position


func ai_pick_target(weights):
	var rand_num = randf()
	var full_weight = 1.0
	for w in weights:
		var weight = w[0]
		full_weight -= weight
		if rand_num > full_weight - 0.001: #full_weight - 0.001 due to float inaccuracy
			return w[1]


## --- Knowing your enemy ---


## Whether `attacker` is the one who measured `target`.
##
## Per studier rather than per side: the sheet is the player's to read once
## anybody has looked, but the advantage of having looked is the studier's.
func _has_studied(attacker: Dictionary, target: Dictionary) -> bool:
	if attacker == null or target == null or target.is_empty():
		return false
	return attacker.get("id", -1) in target.get("studied_by", [])


## `attacker` studies `target` - what Study does (EffectType.REVEAL), and what
## every hit of somebody with studies_on_hit does (Enfina's Measured Eye). A hit
## that studies says so only the first time, and says nothing to an immunity.
func study(attacker: Dictionary, target: Dictionary, by_a_hit: bool = false):
	if immune_to(target, Immunity.Kind.STUDIED):
		if not by_a_hit:
			shrug_off(target, Immunity.name_of(Immunity.Kind.STUDIED))
		return
	# Knowledge, not an injury: it lasts the battle, nothing cleanses it
	# off, and studying the same enemy twice is the same knowledge again.
	var already_known = _has_studied(attacker, target)
	# The codex first: a boss's second page is written by studying it again.
	_write_codex(attacker, target)
	if already_known and by_a_hit:
		return
	target["studied"] = true
	# Who did the measuring, as well as that it has been done. The reading
	# is the player's either way - one sheet, shared - but the edge it gives
	# in a fight belongs to whoever spent the action on it.
	var measured_by: Array = target.get("studied_by", [])
	if not (attacker.get("id", -1) in measured_by):
		measured_by.append(attacker.get("id", -1))
	target["studied_by"] = measured_by
	if already_known:
		update_information.emit("[color=yellow]%s[/color] already has [color=red]%s[/color] measured.\n" % [attacker.name, target.name])
	elif by_a_hit:
		update_information.emit("[color=yellow]%s[/color] takes the measure of [color=red]%s[/color] with the blow - press C to read them.\n" % [attacker.name, target.name])
	else:
		update_information.emit("[color=yellow]%s[/color] studies [color=red]%s[/color], and can read them in full - press C.\n" % [attacker.name, target.name])
	# Study opens the sheet on what it found (and the game waits); a blow that
	# studies only says so - opening a sheet mid-swing, or on a reaction in the
	# other side's turn, would stop the fight for something nobody asked to see.
	if not by_a_hit:
		combatant_studied.emit(target)


## Whether every hit of `comb`'s studies whoever it lands on (studies_on_hit).
func studies_on_hit(comb: Dictionary) -> bool:
	for passive in active_passives(comb):
		if passive.studies_on_hit:
			return true
	return false


## The chance `attacker` has of landing `skill` on `target`: the skill's own
## accuracy, and whatever conditions are helping or hindering them.
##
## Studying somebody used to add ten points here as well. What Study is worth is
## the reading - the sheet, and knowing what you are walking into - rather than
## a thumb on the scale afterwards.
##
## `target` is still taken, because a roll is made per target and a condition on
## one of them is theirs rather than the whole cast's.
func hit_chance(attacker: Dictionary, skill: SkillDefinition, target: Dictionary = {}) -> int:
	# A grab is Physical against Physical, the same as breaking free (Holding on).
	if not target.is_empty() and holding_condition(skill) != null:
		return grip_chance(attacker, target)
	return clampi(skill.accuracy + get_effective_stat(attacker, "accuracy"), 0, 100)


## Locks the view onto whoever is acting for the length of an AI turn.
##
## Only for the AI. On the player's own turn they are steering the view
## themselves and having it taken away mid-decision is worse than not knowing
## where an enemy is. Silent when this battle has no camera, the same way
## shake_camera is, so nothing depends on there being one.
func watch_combatant(comb: Dictionary):
	if camera == null or not is_instance_valid(camera):
		return
	var sprite = comb.get("sprite")
	if sprite != null and is_instance_valid(sprite):
		camera.follow(sprite)


func stop_watching():
	if camera != null and is_instance_valid(camera):
		camera.release()


## --- Consumables ---


## The items `comb` can reach this fight: whatever is in the first four slots of
## their own bag. Enemies carry nothing - they have no campaign inventory, and
## asking for one would make them a bag they never use.
## The spells `comb` casts from one action slot or the other - the main ones
## when `secondary` is false, the secondary ones when it is true.
##
## Which slot a spell spends is the spell's own business (see is_secondary), and
## the panel now shows spells alongside the slot they are cast from rather than
## in a list of their own, so the split has to be askable.
func spells_in_slot(comb: Dictionary, secondary: bool) -> Array:
	var found = []
	for key in spell_skills_of(comb):
		if SkillDatabase.skills[key].is_secondary == secondary:
			found.append(key)
	return found


## What `comb` can use in this fight, by item key: the party's first bag
## slots, or what an enemy spawned with in their pocket (see
## SpawnDefinition.starting_items).
func items_of(comb: Dictionary) -> Array:
	if comb.side != 0:
		return comb.get("pocket", [])
	var key = comb.get("combatant_key", "")
	if key == "":
		return []
	# What a path hands them for every fight, after their own bag.
	var found: Array = Campaign.combat_items_of(key).duplicate()
	for free in free_items_of(comb):
		if not found.has(free):
			found.append(free)
	return found


## An enemy spawn's pocket: the first COMBAT_SLOTS of what it lists that are
## real items and of any use in a fight. The party's spawns hand their items
## to Campaign instead, so theirs stays empty.
func _pocket_from(spawn: SpawnDefinition) -> Array:
	var pocket: Array = []
	if spawn == null or spawn.side == 0:
		return pocket
	for key in spawn.starting_items:
		var item: ItemDefinition = ItemDatabase.item(key) if key != "" else null
		if item == null or item.stealth_only():
			continue
		pocket.append(key)
		if pocket.size() >= Campaign.COMBAT_SLOTS:
			break
	return pocket


## Whether a key names a consumable rather than a skill. Items are registered
## in SkillDatabase alongside the skills so everything that resolves a key
## works unchanged; this is the one question that has to tell them apart.
func is_item(key: String) -> bool:
	return ItemDatabase.is_item(key)


## Takes one off whoever used it. Called once a use has actually gone through,
## so an item aimed at nothing and cancelled is still in the bag.
func consume_item(comb: Dictionary, key: String):
	var item: ItemDefinition = ItemDatabase.item(key)
	if item == null or not item.consumed_on_use:
		return
	if comb.side != 0:
		# Out of an enemy's own pocket, not anybody's bag.
		var pocket: Array = comb.get("pocket", [])
		var slot = pocket.find(key)
		if slot >= 0:
			pocket.remove_at(slot)
		return
	# The free one a path hands them goes first, and the bag keeps its own.
	if free_items_of(comb).has(key):
		var used: Array = comb.get("free_items_used", [])
		used.append(key)
		comb["free_items_used"] = used
		return
	var owner_key = comb.get("combatant_key", "")
	if owner_key == "" or not Campaign.take_item(owner_key, key):
		return
	update_information.emit("[color=yellow]%s[/color] used their last %s.\n" % [comb.name, item.name]
		if Campaign.count_of(owner_key, key) == 0
		else "[color=yellow]%s[/color] has %d %s left.\n" % [comb.name, Campaign.count_of(owner_key, key), item.name])


## --- Teleporting ---


## Whether somebody could be put down on `tile`: on the map, on ground their
## movement class can enter, and with nobody already standing there.
##
## Deliberately the same three questions a knockback asks, so being moved by a
## spell and being shoved agree about where a body can end up.
func can_land_on(comb: Dictionary, tile: Vector2i) -> bool:
	# Every tile of theirs, and room among whoever is there (room_for).
	return room_for(comb, tile)


## Puts `comb` on `tile`, if they can stand there. Costs no movement and
## provokes no reaction: they did not walk out of anybody's reach, they simply
## stopped being where they were.
func teleport_to(comb: Dictionary, tile: Vector2i) -> bool:
	if not can_land_on(comb, tile) or comb.position == tile:
		return false
	var from = comb.position
	comb.position = tile
	comb.sprite.position = sprite_point(comb)
	controller.reposition_combatant(from, tile)
	update_information.emit("[color=yellow]%s[/color] is somewhere else.\n" % comb.name)
	_break_holds_on(comb)
	return true


## Puts the view on the middle of the player's side.
##
## The average of where they are standing rather than any one of them, so a
## party spread across a line of starting tiles is framed as a group. Set
## outright rather than eased: there is nothing on screen yet for a glide to
## carry the eye from.
func centre_on_party():
	if camera == null or not is_instance_valid(camera):
		return
	var total := Vector2.ZERO
	var counted := 0
	for comb in combatants:
		if comb.side == 0 and comb.alive:
			total += Grid.tile_to_world(comb.position)
			counted += 1
	if counted == 0:
		return
	camera.release()
	camera.position = total / counted
	camera.clamp_to_map()


## Whether this battle is still the one being played.
##
## An AI turn is a chain of awaits, and leaving a fight - to Arena Mode, to the
## title screen - changes the scene while that chain is parked. Whatever
## resumes afterwards is acting on a battle nobody is looking at, in a node
## that has been taken out of the tree. Each step asks this before carrying on.
func still_running() -> bool:
	return is_inside_tree() and get_tree() != null


## --- Changing sides ---
##
## Somebody bought for a fight (a bribe), or rebound to Prometheus (a Rebind
## hack), fights for the other side a while. Their side changes and they move
## between `groups`, so everything asking who is whose - the AI's targets,
## winning and losing, the danger view - sees them where they now stand. The
## player never commands them: `ai_controlled` hands their turns to the AI
## whichever side they are on. `comb.turncoat` keeps the side they came from and
## how many of their own turns are left (0: the rest of the fight). They are
## never written into the party's state (Campaign.record_party).


## Whether the AI plays `comb`'s turns: the other side, or somebody fighting
## for the party who is not the player's to command.
func ai_plays(comb: Dictionary) -> bool:
	return comb.get("side", 1) == 1 or comb.get("ai_controlled", false)


## Whether `comb` is one of the party, commanded by the player.
func plays_for_party(comb: Dictionary) -> bool:
	return comb.get("side", 1) == 0 and not comb.get("ai_controlled", false)


## `comb` fights for the other side for `turns` of their own turns, or for the
## rest of the fight with 0. Called on somebody already turned, it turns them
## back.
func switch_sides(comb: Dictionary, turns: int = 0, why: String = ""):
	if not comb.get("alive", false) or comb.has("object") or comb.get("illusion", false):
		return
	var index := combatants.find(comb)
	if index == -1:
		return
	var from: int = comb.side
	groups[from].erase(index)
	comb.side = 1 - from
	if not groups[comb.side].has(index):
		groups[comb.side].append(index)
	if comb.has("turncoat"):
		comb.erase("turncoat")
		comb.erase("ai_controlled")
	else:
		comb["turncoat"] = {"from": from, "turns": turns}
		comb["ai_controlled"] = true
	# What they were winding up, and what they meant to do next, was meant for
	# the side they have left.
	drop_declared(comb, "changing sides")
	comb.erase("intent")
	if why != "":
		update_information.emit(why)
	var sprite = comb.get("sprite")
	if sprite != null and is_instance_valid(sprite) and sprite.has_method("refresh_side"):
		sprite.refresh_side(comb.side)
	update_combatants.emit(combatants)
	if groups[Group.ENEMIES].size() < 1 or groups[Group.PLAYERS].size() < 1:
		combat_finish()


## One of `comb`'s turns as a turncoat is over: with none left, they go back.
func _turncoat_turn_ends(comb: Dictionary):
	if not comb.has("turncoat") or not comb.get("alive", false):
		return
	var left: int = comb.turncoat.turns
	if left <= 0:
		return
	left -= 1
	comb.turncoat.turns = left
	if left == 0:
		switch_sides(comb, 0, "[color=red]%s[/color] remembers who they answer to, and turns back.\n" % comb.name)


## The party all fallen, nobody fights on for them: whoever had turned goes back.
func _turncoats_turn_back_if_alone():
	var real := 0
	var turned := []
	for index in groups[Group.PLAYERS]:
		var comb: Dictionary = combatants[index]
		if comb.has("turncoat"):
			turned.append(comb)
		elif not comb.get("illusion", false):
			real += 1
	if real > 0:
		return
	for comb in turned:
		switch_sides(comb, 0, "With nobody left to fight for, [color=red]%s[/color] turns back.\n" % comb.name)


## --- Reading intent ---
##
## Alithia's Intuition (EffectType.READ_INTENT) reads what somebody the AI plays
## means to do with their next turn - where they will stand, what they will use,
## and where it will land - from the planner their turn would use
## (ai_plan_attack), and holds them to it. `comb.intent` is carried out on that
## turn in place of whatever their archetype would choose by then
## (_ai_follow_intent), so what was read is what happens: step out of the marked
## tiles and the blow lands on nothing; take the tile they meant to stand on and
## they have to think again. Nothing in reach, they mean to close in on somebody,
## and the tile they will close in to is marked instead.


## What `comb` means to do next turn, as a plan to hold them to: {skill, tile,
## aim, tiles, target}, with skill "" for only moving (target is who toward).
func plan_intent(comb: Dictionary) -> Dictionary:
	var keys := _ai_main_keys(comb)
	var hurts := false
	for key in keys:
		if SkillDatabase.skills[key].deals_damage:
			hurts = true
	if not hurts:
		keys.append(melee_fallback_for(comb))
	var budget := movement_budget_of(comb)
	var plan := ai_plan_attack(comb, keys, budget)
	if plan.skill != "":
		var skill: SkillDefinition = SkillDatabase.skills[plan.skill]
		var primary := _ai_primary(comb, plan.skill, plan.tile, plan.aim)
		return {"skill": plan.skill, "tile": plan.tile, "aim": plan.aim,
			"tiles": get_impact_tiles(skill, plan.tile, plan.aim, comb.movement_class),
			"target": primary.get("id", -1)}
	var wanted := _ai_most_wanted(comb, keys)
	if wanted.is_empty():
		wanted = find_nearest_enemy_of(comb)
	if wanted.is_empty() or budget <= 0:
		return {"skill": "", "tile": comb.position, "aim": comb.position, "tiles": [], "target": -1}
	var goal: Vector2i = wanted.position
	var closer := find_best_reachable_tile(comb, budget, func(tile):
		return -float(get_position_distance(tile, goal)))
	return {"skill": "", "tile": closer, "aim": closer, "tiles": [], "target": wanted.id}


## `reader` reads `target`'s next turn (Intuition).
func read_intent(reader: Dictionary, target: Dictionary):
	if target.has("object") or target.get("illusion", false) or not ai_plays(target):
		update_information.emit("There is nothing to read there.\n")
		return
	if immune_to(target, Immunity.Kind.READ):
		shrug_off(target, Immunity.name_of(Immunity.Kind.READ))
		return
	if target.has("declared"):
		update_information.emit("[color=yellow]%s[/color] reads [color=red]%s[/color]: all they mean to do is bring down their %s.\n" % [
			reader.name, target.name, SkillDatabase.skills[target.declared.skill].name])
		return
	var intent := plan_intent(target)
	target["intent"] = intent
	update_information.emit("[color=yellow]%s[/color] reads [color=red]%s[/color]: %s.\n" % [reader.name, target.name, intent_text(target)])
	if controller != null:
		controller.queue_redraw()
	update_combatants.emit(combatants)


## What `comb` means to do, in words: "Greatsword Attack on Enfina, from where
## they stand".
func intent_text(comb: Dictionary) -> String:
	if not comb.has("intent"):
		return ""
	var intent: Dictionary = comb.intent
	var target := _combatant_by_id(intent.get("target", -1))
	var moving: bool = intent.tile != comb.position
	if intent.skill == "":
		if target.is_empty() or not moving:
			return "they mean to hold their ground"
		return "they mean to close in on %s" % target.name
	var skill: SkillDefinition = SkillDatabase.skills[intent.skill]
	var on := " on %s" % target.name if not target.is_empty() else ""
	return "%s%s%s" % [skill.name, on, ", after moving to the marked tile" if moving else ", from where they stand"]


func _combatant_by_id(id: int) -> Dictionary:
	if id < 0:
		return {}
	for comb in combatants:
		if comb.get("id", -2) == id:
			return comb
	return {}


## Every read intent on the board, for the controller to draw: [{tiles, stand,
## from}], the tiles their blow will land on, where they will stand, and where
## they stand now.
func intent_marks() -> Array:
	var marks := []
	for comb in combatants:
		if comb.get("alive", false) and comb.has("intent"):
			marks.append({"tiles": comb.intent.tiles, "stand": comb.intent.tile, "from": comb.position, "span": comb.get("span", 1)})
	return marks


## Carries out the intent that was read: walks to the tile, if it still can, and
## swings at the marked tiles whoever is standing there now. The tile taken or
## out of reach, it plans its turn afresh. True when the turn was played here.
func _ai_follow_intent(comb: Dictionary) -> bool:
	var intent: Dictionary = comb.intent
	comb.erase("intent")
	if controller != null:
		controller.queue_redraw()
	if intent.tile != comb.position:
		var reach = controller.get_reachable_tiles(comb.position, comb.movement_class, movement_budget_of(comb), comb)
		if not reach.has(intent.tile) or not room_for(comb, intent.tile):
			update_information.emit("[color=red]%s[/color] finds the way they meant to take blocked, and thinks again.\n" % comb.name)
			return false
		await controller.ai_move(intent.tile)
		if not still_running() or not comb.alive:
			return true
	if intent.skill != "":
		var skill: SkillDefinition = SkillDatabase.skills.get(intent.skill)
		if skill != null and can_afford_skill(comb, skill) and not comb.get("skill_used_this_turn", false):
			await use_skill(intent.skill, comb, intent.aim, false)
	if still_running() and comb.alive:
		await ai_secondary_attack(comb)
		await advance_turn()
	return true


## --- Taunts ---
##
## Not a skill anybody presses: something an encounter does. A condition with
## `taunts` set (Taunted) ties whoever has it to whoever put it on them - a
## champion's challenging aura (a passive's aura_on_foes), an enemy's roar, an
## idol on the map with an aura of its own. While it lasts, anything of theirs
## that hurts has to catch the taunter: aimed elsewhere it is refused
## (refusal_for), and the AI only values the taunter (ai_worth_table) and walks
## toward them (find_nearest_enemy_of). Put on by nobody in particular - a
## hazard - it ties them to nobody, and does nothing.


## Whoever `comb` is taunted by and still has to answer to, or {}.
func taunted_by(comb: Dictionary) -> Dictionary:
	for entry in comb.get("status_effects", []):
		if entry.get("stat", "") != "condition" or entry.condition == null or not entry.condition.taunts:
			continue
		var taunter := _combatant_by_id(entry.get("source_id", -1))
		if not taunter.is_empty() and taunter.get("alive", false) and taunter.side != comb.side:
			return taunter
	return {}


## Whether `skill` is something that hurts the other side - what a taunt binds.
func _hostile(skill: SkillDefinition) -> bool:
	return skill != null and not skill.targets_ally and not skill.targets_fallen and skill.deals_damage


## Why `attacker` cannot use `skill` aimed at `impact`, or "" - asked by
## use_skill before anything is spent, and by the controller while aiming, so
## the two always agree.
func refusal_for(attacker: Dictionary, skill: SkillDefinition, impact: Vector2i) -> String:
	if skill == null or attacker.is_empty():
		return ""
	var taunter := taunted_by(attacker)
	if not taunter.is_empty() and _hostile(skill):
		var tiles = get_impact_tiles(skill, nearest_tile_of(attacker, impact), impact, terrain_class(attacker), attacker.get("size", Sizes.Size.HUMAN))
		var catches := false
		for tile in tiles_of(taunter):
			if tile in tiles:
				catches = true
		if not catches:
			return "%s is taunted by %s - only %s can be the target" % [attacker.name, taunter.name, taunter.name]
	var target := get_combatant_at(impact)
	# Too heavy to throw, too small to climb (see "Grappling").
	var grip := _grip_refusal(attacker, skill, target)
	if grip != "":
		return grip
	# Nothing on them to work with (Intimidate, Persuade, Deceive).
	if skill.needs_leverage:
		if target.is_empty() or target.has("object") or target.get("illusion", false):
			return "Nobody there to talk to"
		if immune_to(target, Immunity.Kind.SWAYED):
			return "%s cannot be talked round" % target.name
		if not has_leverage(target):
			return "The party has nothing on %s to use - learn something about them first" % target.name
	if _bribes(skill):
		return _bribe_refusal(target)
	return ""


## Whether the party has something on `target` that Intimidate, Persuade or
## Deceive can use: their faction known, one of their kind questioned, or a
## clue that bears on them (Campaign.has_leverage_on).
func has_leverage(target: Dictionary) -> bool:
	return Campaign.has_leverage_on(target.get("combatant_key", ""), target.get("faction", ""), target.get("leverage_clues", []))


## Conditions that come off the moment their bearer is hurt (ends_when_hit).
func _hurt_ends_conditions(target: Dictionary):
	var i: int = target.get("status_effects", []).size() - 1
	while i >= 0:
		var entry: Dictionary = target.status_effects[i]
		if entry.get("stat", "") == "condition" and entry.condition != null and entry.condition.ends_when_hit:
			target.status_effects.remove_at(i)
			update_information.emit("[color=red]%s[/color] is no longer %s.\n" % [target.name, entry.condition.display_name.to_lower()])
		i -= 1


## --- Nerve ---
##
## An enemy can break. What shakes them is added up (shaken_by) - their leader
## (CombatantDefinition.leads) fallen, half their side down, being hurt or badly
## hurt, being the last of their side, being afraid (anything preventing them
## advancing - Fear), and whatever Intimidate has done (EffectType.SHAKE, kept in
## `comb.shaken`) - at the start of each of their turns, and straight after an
## Intimidate. At their Nerve or more they break: they run for a way out and are
## gone once they reach it (see "Getting away"; with none on the map they never
## get away), or they surrender where they stand. Either way they are off
## their side, so the fight can be won without them.
##
## Nobody immune to Breaking (Immunity.Kind.BREAKING) breaks - a boss, a
## fanatic, a golem - and nobody on the party's side does at all.
##
## Gone from the fight without dying is `comb.taken`: "fled", "surrendered",
## "bought", or "knocked_out" - whoever of the other side falls is knocked out
## and taken, unless they cannot be (Immunity.Kind.TAKEN_ALIVE; _knocks_out).
## The surrendered and knocked out are prisoners (prisoners()), for the results
## screen to question.

const NERVE_LEADER_FALLEN := 40
const NERVE_HALF_DOWN := 25
## At half health or less; at a quarter or less, BADLY_HURT instead.
const NERVE_HURT := 15
const NERVE_BADLY_HURT := 30
const NERVE_ALONE := 30
const NERVE_AFRAID := 20
## What comb.fleeing is set to when somebody breaks and runs: a mark that they
## are running, not a count - only reaching a way out ends it (see "Getting away").
const FLEE_TURNS := 2


## Whether `comb` can break at all.
func can_break(comb: Dictionary) -> bool:
	return comb.get("side", 0) == Group.ENEMIES and comb.get("alive", false) and not comb.has("turncoat") \
		and not comb.has("object") and not comb.get("illusion", false) and not comb.has("taken") \
		and not immune_to(comb, Immunity.Kind.BREAKING)


## What is shaking `comb` right now: [[why, how much], ...].
func shaken_by(comb: Dictionary) -> Array:
	var reasons := []
	if comb.get("shaken", 0) > 0:
		reasons.append(["intimidated", int(comb.shaken)])
	var on_side := 1
	var down := 0
	var standing := 0
	var leader_down := false
	for other in combatants:
		if other == comb or other.get("side", -1) != comb.side or other.has("object") \
				or other.get("illusion", false) or other.has("turncoat"):
			continue
		on_side += 1
		if other.alive:
			standing += 1
		else:
			down += 1
			if other.get("leads", false):
				leader_down = true
	if leader_down:
		reasons.append(["their leader is down", NERVE_LEADER_FALLEN])
	if down > 0 and down * 2 >= on_side:
		reasons.append(["half their side is down", NERVE_HALF_DOWN])
	var share := float(comb.hp) / maxf(get_effective_stat(comb, "max_hp"), 1.0)
	if share <= 0.25:
		reasons.append(["badly hurt", NERVE_BADLY_HURT])
	elif share <= 0.5:
		reasons.append(["hurt", NERVE_HURT])
	if standing == 0 and down > 0:
		reasons.append(["alone", NERVE_ALONE])
	if has_restriction(comb, "prevents_approach"):
		reasons.append(["afraid", NERVE_AFRAID])
	return reasons


## How shaken `comb` is, all told.
func shaken(comb: Dictionary) -> int:
	var total := 0
	for reason in shaken_by(comb):
		total += reason[1]
	return total


## Breaks `comb` if they are shaken enough. True when they broke.
func check_nerve(comb: Dictionary) -> bool:
	if not can_break(comb) or comb.get("fleeing", 0) > 0:
		return false
	if shaken(comb) < comb.get("nerve", 60):
		return false
	var why: Array = shaken_by(comb).map(func(reason): return reason[0])
	drop_declared(comb, "broken")
	comb.erase("intent")
	float_number(comb, "Broken!", Color("f0d060"))
	if comb.get("when_broken", 0) == 1:
		update_information.emit("[color=red]%s[/color] breaks - %s - and throws down their weapons.\n" % [comb.name, ", ".join(why)])
		_taken(comb, "surrendered")
	elif escape_points.is_empty():
		update_information.emit("[color=red]%s[/color] breaks - %s - and looks for a way out. There is none.\n" % [comb.name, ", ".join(why)])
		comb["fleeing"] = FLEE_TURNS
		update_combatants.emit(combatants)
	else:
		update_information.emit("[color=red]%s[/color] breaks - %s - and runs for it!\n" % [comb.name, ", ".join(why)])
		comb["fleeing"] = FLEE_TURNS
		update_combatants.emit(combatants)
	return true


## Shakes `comb`'s nerve by `amount` (Intimidate), and sees whether it holds.
func shake(attacker: Dictionary, comb: Dictionary, amount: int):
	if not can_break(comb):
		if comb.get("side", 0) == Group.ENEMIES and immune_to(comb, Immunity.Kind.BREAKING):
			shrug_off(comb, Immunity.name_of(Immunity.Kind.BREAKING))
		return
	comb["shaken"] = comb.get("shaken", 0) + amount
	update_information.emit("[color=yellow]%s[/color] shakes [color=red]%s[/color]'s nerve (%d of %d).\n" % [
		attacker.name, comb.name, shaken(comb), comb.get("nerve", 60)])
	check_nerve(comb)


## A broken enemy's turn. With ways out on the map (escape_points), for the
## nearest of them by every means they have, and gone once they stand on one
## (_run_for_a_way_out). Without, there is no getting away: it keeps as far from
## the nearest of the other side as its feet take it, and that is all.
func _ai_flee(comb: Dictionary):
	if not escape_points.is_empty():
		await _run_for_a_way_out(comb)
		return
	await _keep_away(comb)
	if still_running() and comb.alive and not combat_over:
		await advance_turn()


## `comb`, with nowhere to run to, as far from the nearest of the other side as
## its feet take it.
func _keep_away(comb: Dictionary):
	var foe := find_nearest_enemy_of(comb)
	var budget: int = movement_budget_of(comb) if comb != get_current_combatant() else controller.movement
	if foe.is_empty() or budget <= 0 or has_restriction(comb, "prevents_movement"):
		return
	var away := find_best_reachable_tile(comb, budget, func(tile): return float(get_position_distance(tile, foe.position)))
	if away != comb.position:
		await controller.ai_move(away)


## `comb` is out of the fight without dying: "fled", "surrendered" or
## "knocked_out" - off their side and the turn order, their tile freed.
func _taken(comb: Dictionary, how: String):
	_drop_riders(comb)
	if comb.has("riding"):
		dismount(comb)
	var index := combatants.find(comb)
	comb.alive = false
	comb["taken"] = how
	comb.erase("fleeing")
	set_hidden(comb, false)
	if index != -1:
		groups[comb.side].erase(index)
	# Gone, they hold nobody (Holding on).
	check_holds()
	# The last of a side gone, their images go with them, as when they fall.
	if not side_standing(comb.side):
		for other in combatants.duplicate():
			if other.get("illusion", false) and other.alive and other.side == comb.side:
				_shatter(other)
	match how:
		"fled":
			update_information.emit("[color=red]%s[/color] flees the field.\n" % comb.name)
		"surrendered":
			update_information.emit("[color=red]%s[/color] surrenders, and is taken.\n" % comb.name)
		"knocked_out":
			update_information.emit("[color=red]%s[/color] is knocked out - taken alive.\n" % comb.name)
	var sprite = comb.get("sprite")
	if sprite != null and is_instance_valid(sprite):
		if how in ["fled", "bought"]:
			sprite.visible = false
		elif how == "surrendered":
			sprite.modulate = Color(0.7, 0.7, 0.75, 0.75)
		else:
			sprite.set_dead()
	combatant_died.emit(comb)
	update_combatants.emit(combatants)
	# Away: what comes of it is theirs to say (see "Getting away").
	if how == "fled":
		_got_away(comb)
	if groups[Group.ENEMIES].size() < 1 or groups[Group.PLAYERS].size() < 1:
		combat_finish()


## Whether `target` falling is knocked out rather than killed: always, for
## anybody of the other side who can be taken alive - but not somebody who
## brought it on themselves (SkillDefinition.kills_caster: a Self Destruct).
func _knocks_out(target: Dictionary) -> bool:
	return not target.get("killed_itself", false) and target.get("side", 0) == Group.ENEMIES and not target.has("turncoat") and not target.has("object") \
		and not target.get("illusion", false) and not immune_to(target, Immunity.Kind.TAKEN_ALIVE)


## Everybody taken alive this fight - surrendered or knocked out - for the
## results screen to question.
func prisoners() -> Array:
	return combatants.filter(func(comb): return comb.get("taken", "") in ["surrendered", "knocked_out"])


## --- Bribes ---
##
## Somebody with a price (CombatantDefinition.bribe_price - a mercenary) can be
## paid out of the fight: the Bribe skill, offered to the party as a secondary
## action whenever anybody buyable is fighting them (_offer_bribe), pays it from
## the party's purse and they walk off ("bought"). Before a fight, a parley can
## buy them off or onto the party's side instead (Campaign.bribe).

const BRIBE_SKILL := "bribe"


## The party gets Bribe if anybody they are fighting has a price.
func _offer_bribe():
	if not SkillDatabase.skills.has(BRIBE_SKILL):
		return
	if not combatants.any(func(comb): return comb.alive and comb.side == Group.ENEMIES and comb.get("bribe_price", 0) > 0):
		return
	for comb in combatants:
		if comb.alive and plays_for_party(comb) and _takes_turns(comb) and not comb.skill_list.has(BRIBE_SKILL):
			comb.skill_list.append(BRIBE_SKILL)


## Whether `skill` pays somebody off (EffectType.BRIBE).
static func _bribes(skill: SkillDefinition) -> bool:
	return skill != null and skill.effects.any(func(effect): return effect != null and effect.type == EffectDefinition.EffectType.BRIBE)


## Why `target` cannot be paid off by the party, or "".
func _bribe_refusal(target: Dictionary) -> String:
	if target.is_empty():
		return "Nobody there to pay"
	var price: int = target.get("bribe_price", 0)
	if price <= 0 or target.side != Group.ENEMIES:
		return "%s cannot be bought" % target.name
	if Campaign.gold < price:
		return "%s wants %d gold - the party has %d" % [target.name, price, Campaign.gold]
	return ""


## `payer` pays `target` their price, and they leave the fight.
func pay_off(payer: Dictionary, target: Dictionary):
	var refused := _bribe_refusal(target)
	if refused != "":
		update_information.emit(refused + ".\n")
		return
	var price: int = target.bribe_price
	Campaign.spend_gold(price)
	update_information.emit("[color=yellow]%s[/color] pays [color=red]%s[/color] [color=gold]%d gold[/color] to walk away.\n" % [payer.name, target.name, price])
	_taken(target, "bought")


## --- Grappling ---
##
## Hurl (SkillDefinition.throws): grab somebody beside you - no more than
## lifts_sizes_above sizes bigger than you - and throw them, up to throw_reach
## tiles away. Onto somebody, both are hurt by the skill's damage and the thrown
## one lands on the nearest free tile. Immune to being thrown, or to being shoved,
## is never picked up. Enfina's, and the Barbarian's.
##
## Climb (EffectType.CLIMB): onto somebody Monstrous or bigger, to fight from on
## top of them. The climber stands on none of the ground (covers is false for
## them, so nobody finds them on a tile), is carried wherever their mount goes
## (_carry_riders, from place_sprites), cannot be reached by anybody, and cannot
## walk - Riding. Every blow on the mount from up there is in reach and lands
## RIDING_BONUS harder. The mount spends its main action trying to shake them off
## (_ai_shake_off), which hurts whether it works or not. Climb Down
## (TeleportWho.CASTER, while riding) jumps off; the mount falling drops them.

const THROW_RANGE_PER_PHYSICAL := 30
const RIDING_BONUS := 1.25
## A rider holds on against a shake at this chance, a point more for every
## point of Physical more than their mount, never below or above the bounds.
const HOLD_ON_CHANCE := 50
const HOLD_ON_MIN := 20
const HOLD_ON_MAX := 80
## A shake hurts the rider like a hit from the mount at this share of a swing's
## power - a graze's half.
const SHAKE_OFF_POWER := 0.5
const RIDING := preload("res://data/conditions/riding.tres")
const CLIMB_DOWN_SKILL := "climb_down"


## How far `thrower` can send somebody with `skill`.
func throw_reach(thrower: Dictionary, skill: SkillDefinition) -> int:
	return skill.throw_range + floori(stat_of(thrower, Stats.Type.PHYSICAL) / float(THROW_RANGE_PER_PHYSICAL))


## Why `user` cannot get hold of `target` with `skill` - too big, immune, not
## big enough to climb, somebody already riding - or "".
func _grip_refusal(user: Dictionary, skill: SkillDefinition, target: Dictionary) -> String:
	if skill.lifts_sizes_above < 0 and skill.needs_size_at_least < 0 and not skill.throws and not _climbs(skill):
		return ""
	if target.is_empty():
		return "Nobody there to get hold of"
	if target.has("object") or target.get("illusion", false):
		return "Nothing there to get hold of"
	if target.has("riding"):
		return "%s is up on somebody else" % target.name
	if skill.throws:
		for kind in [Immunity.Kind.THROWN, Immunity.Kind.SHOVED]:
			if immune_to(target, kind):
				return "%s cannot be thrown" % target.name
	if skill.lifts_sizes_above >= 0 and target.get("size", Sizes.Size.HUMAN) > user.get("size", Sizes.Size.HUMAN) + skill.lifts_sizes_above:
		return "%s is too big for %s to %s" % [target.name, user.name, "lift" if skill.throws else "get hold of"]
	var hold := holding_condition(skill)
	if hold != null and immune_to_condition(target, hold):
		return "%s cannot be held" % target.name
	if skill.needs_size_at_least >= 0 and target.get("size", Sizes.Size.HUMAN) < skill.needs_size_at_least:
		return "%s is not big enough to climb - %s or bigger" % [target.name, Sizes.name_of(skill.needs_size_at_least)]
	if _climbs(skill) and immune_to(target, Immunity.Kind.CLIMBED):
		return "%s cannot be climbed" % target.name
	if _climbs(skill) and user.has("riding"):
		return "%s is already up on somebody" % user.name
	return ""


## Whether `skill` climbs onto somebody (EffectType.CLIMB).
static func _climbs(skill: SkillDefinition) -> bool:
	return skill != null and skill.effects.any(func(effect): return effect != null and effect.type == EffectDefinition.EffectType.CLIMB)


## Every tile `thrown` could be sent to by `thrower`'s `skill`: free ground in
## reach, or somebody to throw them at.
func throw_destinations(thrower: Dictionary, skill: SkillDefinition, thrown: Dictionary) -> Array:
	var reach := throw_reach(thrower, skill)
	var found := []
	var from: Vector2i = thrower.position
	for dx in range(-reach, reach + 1):
		var span := reach - absi(dx)
		for dy in range(-span, span + 1):
			var tile := from + Vector2i(dx, dy)
			if tile == thrown.position or not controller.is_in_bounds(tile):
				continue
			if can_land_on(thrown, tile) or _thrown_into(thrown, thrower, tile).size() > 0:
				found.append(tile)
	return found


## Whoever `thrown` would crash into, landing on `tile`.
func _thrown_into(thrown: Dictionary, thrower: Dictionary, tile: Vector2i) -> Array:
	var struck := []
	for other in combatants_at(tile):
		if other != thrown and other != thrower and not other.get("illusion", false):
			struck.append(other)
	return struck


## The free tile nearest `tile` that `comb` can be put down on, or their own.
func _nearest_free_tile(comb: Dictionary, tile: Vector2i, within: int = 4) -> Vector2i:
	for ring in range(0, within + 1):
		for dx in range(-ring, ring + 1):
			var span := ring - absi(dx)
			for dy in ([-span, span] if span > 0 else [0]):
				var candidate := tile + Vector2i(dx, dy)
				if can_land_on(comb, candidate):
					return candidate
	return comb.position


## `thrower` hurls whoever is on `subject_tile` to `destination` (Hurl).
func _hurl(thrower: Dictionary, skill: SkillDefinition, subject_tile: Vector2i, destination: Vector2i, end_turn_after: bool, as_secondary: bool):
	var thrown := get_combatant_at(subject_tile)
	if thrown.is_empty() or not throw_destinations(thrower, skill, thrown).has(destination):
		update_information.emit("[color=yellow]%s[/color] cannot throw anybody there.\n" % thrower.name)
		if ai_plays(thrower) and end_turn_after:
			await advance_turn()
		return
	controller.action_locked = true
	game_ui.lock_action_buttons()
	await thrower.sprite.play_skill_and_wait(skill.animation)
	if not still_running():
		return
	play_skill_sound(skill)
	controller.action_locked = false
	game_ui.refresh_action_buttons()
	# A quick time event for whoever it matters to, if the skill has one.
	var power := await quick_time_power(thrower, [thrown], skill)
	if not still_running():
		return
	var struck := _thrown_into(thrown, thrower, destination)
	var landing := destination if struck.is_empty() else _nearest_free_tile(thrown, destination)
	# Thrown, they are out of anybody's grip and lose hold of anybody in theirs.
	_break_holds_on(thrown)
	if landing != thrown.position:
		var from: Vector2i = thrown.position
		thrown.position = landing
		thrown.sprite.position = sprite_point(thrown)
		controller.reposition_combatant(from, landing)
	if struck.is_empty():
		update_information.emit("[color=yellow]%s[/color] hurls [color=red]%s[/color]!\n" % [thrower.name, thrown.name])
	else:
		update_information.emit("[color=yellow]%s[/color] hurls [color=red]%s[/color] into [color=red]%s[/color]!\n" % [
			thrower.name, thrown.name, ", ".join(struck.map(func(other): return other.name))])
	for victim in [thrown] + struck:
		if not victim.alive:
			continue
		for effect in skill.all_effects():
			apply_effect(thrower, victim, effect, skill, false, power)
	reveal_anyone_now_seen()
	await _hack_spends_action(thrower, as_secondary, end_turn_after)


## `climber` climbs onto `mount`.
func climb_onto(climber: Dictionary, mount: Dictionary):
	var skill: SkillDefinition = SkillDatabase.skills.get("climb")
	var refused := _grip_refusal(climber, skill, mount) if skill != null else ""
	if refused != "" or not climber.alive or not mount.alive:
		update_information.emit((refused if refused != "" else "There is nothing to climb") + ".\n")
		return
	var seat := nearest_tile_of(mount, climber.position)
	_break_holds_on(climber)
	climber["riding"] = mount.id
	climber["ride_offset"] = seat - mount.position
	var riders: Array = mount.get("riders", [])
	riders.append(climber.id)
	mount["riders"] = riders
	put_condition(climber, RIDING, 999, mount.name, true, mount.id)
	if not climber.skill_list.has(CLIMB_DOWN_SKILL) and SkillDatabase.skills.has(CLIMB_DOWN_SKILL):
		climber.skill_list.append(CLIMB_DOWN_SKILL)
	var from: Vector2i = climber.position
	climber.position = seat
	controller.reposition_combatant(from, seat)
	if climber == get_current_combatant():
		controller.movement = 0
	update_information.emit("[color=yellow]%s[/color] climbs up onto [color=red]%s[/color]!\n" % [climber.name, mount.name])
	update_combatants.emit(combatants)


## The one `rider` is up on, or {}.
func mount_of(rider: Dictionary) -> Dictionary:
	return _combatant_by_id(rider.get("riding", -1)) if rider.has("riding") else {}


## `rider` comes down - onto `tile`, or the nearest free tile to where they are.
func dismount(rider: Dictionary, tile = null):
	var mount := mount_of(rider)
	_break_holds_on(rider)
	rider.erase("riding")
	rider.erase("ride_offset")
	if not mount.is_empty():
		var riders: Array = mount.get("riders", [])
		riders.erase(rider.id)
		mount["riders"] = riders
	for i in range(rider.status_effects.size() - 1, -1, -1):
		var entry: Dictionary = rider.status_effects[i]
		if entry.get("stat", "") == "condition" and entry.condition == RIDING:
			rider.status_effects.remove_at(i)
	rider.skill_list.erase(CLIMB_DOWN_SKILL)
	var landing: Vector2i = tile if tile != null else _nearest_free_tile(rider, rider.position)
	if not can_land_on(rider, landing):
		landing = _nearest_free_tile(rider, landing, 8)
	var from: Vector2i = rider.position
	rider.position = landing
	var sprite = rider.get("sprite")
	if sprite != null and is_instance_valid(sprite):
		sprite.z_index = 0
		sprite.position = sprite_point(rider)
	controller.reposition_combatant(from, landing)
	update_combatants.emit(combatants)


## Everybody up on `mount`.
func riders_of(mount: Dictionary) -> Array:
	return mount.get("riders", []).map(func(id): return _combatant_by_id(id)).filter(func(rider): return not rider.is_empty() and rider.alive)


## Riders carried along with their mounts, wherever they have gone: called
## from place_sprites, so every move of anybody keeps them up there.
func _carry_riders():
	for rider in combatants:
		if not rider.has("riding") or not rider.alive:
			continue
		var mount := mount_of(rider)
		if mount.is_empty() or not mount.alive:
			continue
		rider.position = mount.position + rider.get("ride_offset", Vector2i.ZERO)
		var sprite = rider.get("sprite")
		if sprite != null and is_instance_valid(sprite):
			sprite.position = sprite_point(rider)
			var under = mount.get("sprite")
			sprite.z_index = (under.z_index if under != null and is_instance_valid(under) else 0) + 1


## The mount's turn: it spends its main action trying to throw whoever is up on
## it. It hurts them either way; they hold on at HOLD_ON_CHANCE, more for being
## stronger than it.
func _ai_shake_off(mount: Dictionary):
	for rider in riders_of(mount):
		var chance := clampi(HOLD_ON_CHANCE + int(stat_of(rider, Stats.Type.PHYSICAL) - stat_of(mount, Stats.Type.PHYSICAL)), HOLD_ON_MIN, HOLD_ON_MAX)
		# The same arithmetic as a hit, at SHAKE_OFF_POWER - through the rider's
		# defence and what they resist, like any other blow.
		var base := Stats.base_damage(int(stat_of(mount, Stats.Type.PHYSICAL)), mount.get("weapon_base", Stats.WEAPON_BASE))
		var hurt := resisted_damage(rider, Damage.Type.PHYSICAL,
			Stats.final_damage(base, SHAKE_OFF_POWER, int(stat_of(rider, Stats.Type.DEFENSE))))
		update_information.emit("[color=red]%s[/color] bucks and thrashes to throw [color=yellow]%s[/color] off!\n" % [mount.name, rider.name])
		lose_hp(rider, hurt, Damage.Type.PHYSICAL)
		show_damage(rider, hurt, Damage.Type.PHYSICAL)
		if rider.hp <= 0:
			combatant_die(rider)
			continue
		if randi() % 100 < chance:
			update_information.emit("[color=yellow]%s[/color] holds on.\n" % rider.name)
		else:
			dismount(rider)
			update_information.emit("[color=yellow]%s[/color] is thrown off.\n" % rider.name)
	mount.skill_used_this_turn = true
	update_combatants.emit(combatants)


## An enemy with a throw (Hurl) uses it when somebody of the other side is in
## its grip and another stands where they can be thrown into - both hurt, the
## most of them it can catch. True when it threw.
func _ai_hurl(comb: Dictionary) -> bool:
	if comb.get("skill_used_this_turn", false) or not comb.alive:
		return false
	for key in comb.get("skill_list", []):
		var skill: SkillDefinition = SkillDatabase.skills.get(key)
		if skill == null or not skill.throws or skill.is_secondary:
			continue
		if not can_afford_skill(comb, skill) or not meets_level_for(comb, skill):
			continue
		var best := {}
		var most := 0
		for foe in combatants:
			if not foe.alive or foe.side == comb.side or foe.has("object") or is_hidden(foe) or foe.get("illusion", false):
				continue
			var gap := distance_to(comb, foe.position)
			if gap < skill.min_range or gap > effective_max_range(comb, skill):
				continue
			if refusal_for(comb, skill, foe.position) != "":
				continue
			for tile in throw_destinations(comb, skill, foe):
				var caught := _thrown_into(foe, comb, tile).filter(func(other): return other.side != comb.side and not other.has("object")).size()
				if caught > most:
					most = caught
					best = {"foe": foe, "tile": tile}
		if not best.is_empty():
			await use_skill(key, comb, best.foe.position, false, false, best.tile)
			return true
	return false


## Whoever was up on `mount` comes down as it falls or goes.
func _drop_riders(mount: Dictionary):
	for rider in riders_of(mount):
		dismount(rider)
		update_information.emit("[color=yellow]%s[/color] jumps clear of [color=red]%s[/color].\n" % [rider.name, mount.name])


## --- Holding on ---
##
## Grab (Enfina's, and the Barbarian's) puts a condition with Holds ticked on
## somebody beside it - Grappled: they cannot move. It is a reaction too: grabbed
## as they leave the grabber's reach, they are dragged back to the tile they were
## leaving and their walk ends there (check_reactive_skills, CController).
##
## Getting hold and breaking free are the same contest (grip_chance): GRIP_CHANCE
## of the time against somebody as strong, a point more for every point of
## Physical more than them, within the bounds. Grab rolls it as its hit chance
## (hit_chance), so the preview shows it.
##
## Held, they have Break Free (BREAK_FREE_SKILL, their main action). Otherwise
## the grip lasts until:
## - whoever holds them is not beside them any more, is down, gone, or up on
##   somebody (check_holds)
## - either of them is teleported, shoved, thrown, blown along or climbs
##   (_break_holds_on, from wherever that happens)
## - the holder grabs somebody else: one held at a time.
##
## Held, an enemy fights from where it stands if it can hit anybody from there,
## and spends its main action breaking free if it cannot, or is running
## (_ai_break_free).

const BREAK_FREE_SKILL := "break_free"
const GRIP_CHANCE := 50
const GRIP_MIN := 20
const GRIP_MAX := 80


## The entry of the condition holding `comb` (Grappled), or {}.
func hold_on(comb: Dictionary) -> Dictionary:
	for entry in comb.get("status_effects", []):
		if entry.get("stat", "") == "condition" and entry.get("condition") != null and entry.condition.holds:
			return entry
	return {}


## Whether somebody has hold of `comb`.
func is_held(comb: Dictionary) -> bool:
	return not hold_on(comb).is_empty()


## Whoever has hold of `comb`, or {}.
func holder_of(comb: Dictionary) -> Dictionary:
	var entry := hold_on(comb)
	return {} if entry.is_empty() else _combatant_by_id(entry.get("source_id", -1))


## Everybody `holder` has hold of.
func held_by(holder: Dictionary) -> Array:
	return combatants.filter(func(other): return other.alive and other != holder \
		and holder_of(other).get("id", -2) == holder.get("id", -1))


## How likely `who` is to get the better of `other` in a grip - getting hold
## of them, or out of their hold - in percent: Physical against Physical.
func grip_chance(who: Dictionary, other: Dictionary) -> int:
	return clampi(GRIP_CHANCE + int(stat_of(who, Stats.Type.PHYSICAL) - stat_of(other, Stats.Type.PHYSICAL)),
		GRIP_MIN, GRIP_MAX)


## How likely `held` is to break `holder`'s grip, in percent.
func break_free_chance(held: Dictionary, holder: Dictionary) -> int:
	if holder.is_empty():
		return 100
	return grip_chance(held, holder)


## The condition `skill` holds its target with, if it does (Grab).
static func holding_condition(skill: SkillDefinition) -> ConditionDefinition:
	if skill == null:
		return null
	for effect in skill.effects:
		if effect != null and effect.type == EffectDefinition.EffectType.CONDITION and effect.condition != null and effect.condition.holds:
			return effect.condition
	return null


## `holder` has just got hold of `held`: anybody else they had hold of is let
## go, and `held` can now try to break free.
func _got_hold(holder: Dictionary, held: Dictionary):
	for other in held_by(holder):
		if other != held:
			_let_go(other, "%s lets go of [color=red]%s[/color]" % [holder.name, other.name])
	if not held.skill_list.has(BREAK_FREE_SKILL) and SkillDatabase.skills.has(BREAK_FREE_SKILL):
		held.skill_list.append(BREAK_FREE_SKILL)


## `held` is free of whoever had them. `why` is the log line, if any. Their
## walk this turn comes back as it was, if it is theirs.
func _let_go(held: Dictionary, why: String = ""):
	var entry := hold_on(held)
	if entry.is_empty():
		return
	held.status_effects.erase(entry)
	held.skill_list.erase(BREAK_FREE_SKILL)
	if held == get_current_combatant() and controller != null:
		controller.movement = maxi(held.get("movement_left_when_grabbed", get_effective_stat(held, "movement")), 0)
	held.erase("movement_left_when_grabbed")
	if why != "":
		update_information.emit(why + ".\n")
	update_combatants.emit(combatants)


## Every grip `comb` is in, either end of it, broken - they have been
## teleported, shoved, thrown or blown somewhere.
func _break_holds_on(comb: Dictionary):
	if is_held(comb):
		_let_go(comb, "[color=red]%s[/color] is torn free of %s's grip" % [comb.name, holder_of(comb).get("name", "the")])
	for other in held_by(comb):
		_let_go(other, "%s loses hold of [color=red]%s[/color]" % [comb.name, other.name])


## Lets go of anybody whose holder is no longer beside them, or is down, gone
## or up on somebody. Cheap; called after every step and as each turn begins.
func check_holds():
	for comb in combatants:
		if not comb.alive or not is_held(comb):
			continue
		var holder := holder_of(comb)
		if holder.is_empty() or not holder.alive or holder.has("riding") \
				or rect_gap(rect_of(holder), rect_of(comb)) > 1:
			_let_go(comb, "[color=red]%s[/color] is no longer held" % comb.name)


## `held` struggles against `holder` (Break Free).
func break_free(held: Dictionary, holder: Dictionary):
	if holder_of(held).get("id", -2) != holder.get("id", -1):
		update_information.emit("[color=yellow]%s[/color] is not held by %s.\n" % [held.name, holder.get("name", "anybody")])
		return
	var chance := break_free_chance(held, holder)
	if randi() % 100 < chance:
		_let_go(held, "[color=yellow]%s[/color] breaks free of %s's grip" % [held.name, holder.name])
	else:
		update_information.emit("[color=yellow]%s[/color] strains against %s's grip, and cannot break it.\n" % [held.name, holder.name])


## `held`, grabbed as they left `holder`'s reach from `tile`, is dragged back
## onto it.
func _drag_back(held: Dictionary, holder: Dictionary, tile: Vector2i):
	if held.position == tile or not can_land_on(held, tile):
		return
	var from: Vector2i = held.position
	held.position = tile
	held.sprite.position = sprite_point(held)
	controller.reposition_combatant(from, tile)
	update_information.emit("[color=yellow]%s[/color] drags [color=red]%s[/color] back.\n" % [holder.name, held.name])


## Which of `offered` (reactive skill keys) `reactor` uses on `mover`, or ""
## to let them go. The player is asked when there is a choice; the AI takes
## whatever it rates highest against them.
func choose_reaction(reactor: Dictionary, mover: Dictionary, offered: Array) -> String:
	if offered.is_empty():
		return ""
	if reactor.side != 0 or reaction_prompt == null:
		var best: String = offered[0]
		var most := -INF
		for key in offered:
			var worth := ai_target_value(reactor, mover, SkillDatabase.skills[key])
			if worth > most:
				most = worth
				best = key
		return best
	if offered.size() == 1:
		return offered[0] if await confirm_reaction(reactor, mover, SkillDatabase.skills[offered[0]]) else ""
	var picked: int = await reaction_prompt.choose(reactor, mover, offered.map(func(key): return SkillDatabase.skills[key]))
	if picked < 0 or picked >= offered.size():
		update_information.emit("[color=yellow]%s[/color] holds their reaction.\n" % reactor.name)
		return ""
	return offered[picked]


## Whether `comb` could hurt anybody from where it stands with its main action.
func _ai_can_strike_from_here(comb: Dictionary) -> bool:
	for key in _ai_main_keys(comb):
		var skill: SkillDefinition = SkillDatabase.skills.get(key)
		if not _hostile(skill) or not _ai_plannable(comb, skill) or wasted_on(comb, skill) != "":
			continue
		var worth := ai_worth_table(comb, skill)
		for other in combatants:
			if worth.get(other.get("id", -1), 0.0) <= 0.0:
				continue
			var tile := nearest_tile_of(other, comb.position)
			var gap := distance_to(comb, tile)
			if gap < skill.min_range or gap > effective_max_range(comb, skill):
				continue
			if skill.respects_blocking and not has_line_of_sight(comb.position, tile, comb.movement_class):
				continue
			return true
	return false


## `comb`, held where it did not mean to be, uses the best it has from there
## instead of what it planned - or does nothing, when nothing reaches.
func _ai_make_do(comb: Dictionary, end_turn_after: bool, as_secondary: bool):
	var keys: Array = secondary_skills_of(comb).duplicate() if as_secondary else _ai_main_keys(comb)
	var plan := ai_plan_attack(comb, keys, 0)
	if plan.skill == "":
		update_information.emit("[color=yellow]%s[/color] has nothing in reach from where they are held.\n" % comb.name)
		if end_turn_after:
			await advance_turn()
		return
	var primary := _ai_primary(comb, plan.skill, comb.position, plan.aim)
	if not primary.is_empty():
		_ai_focus_id = primary.id
	comb["making_do"] = true
	await use_skill(plan.skill, comb, plan.aim, end_turn_after, as_secondary)
	comb.erase("making_do")


## Held, `comb` spends its main action breaking free - when running (`must`),
## or when there is nobody it could hurt from where it stands. True when it
## tried.
func _ai_break_free(comb: Dictionary, must: bool = false) -> bool:
	if comb.get("skill_used_this_turn", false) or not comb.skill_list.has(BREAK_FREE_SKILL):
		return false
	var holder := holder_of(comb)
	if holder.is_empty():
		return false
	if not must and _ai_can_strike_from_here(comb):
		return false
	comb.erase("intent")
	await use_skill(BREAK_FREE_SKILL, comb, nearest_tile_of(holder, comb.position), false, false)
	return true


## --- Quick time ---
##
## A skill with a quick time event (SkillDefinition.quick_time) pops it up as it
## lands (the QuickTime autoload), once a use however many it catches. For the
## Attacker: when somebody the player commands uses it, done in time it lands
## quick_time_bonus harder on everybody it hits. For the Defender: when it is
## used on the party by somebody they do not command, done in time it lands
## quick_time_bonus softer on the party - and only on them.


## The QTE's say on `skill` landing on `targets`: what each hit it governs is
## multiplied by. 1.0 when it has nothing to say, or was not done in time.
func quick_time_power(user: Dictionary, targets: Array, skill: SkillDefinition) -> float:
	if skill == null or skill.quick_time == null:
		return 1.0
	var quick = get_node_or_null("/root/QuickTime")
	if quick == null:
		return 1.0
	if skill.quick_time_for == 0:
		if not plays_for_party(user):
			return 1.0
		return 1.0 + skill.quick_time_bonus if await quick.run(skill.quick_time) else 1.0
	if not ai_plays(user) or not targets.any(func(target): return plays_for_party(target)):
		return 1.0
	return maxf(1.0 - skill.quick_time_bonus, 0.0) if await quick.run(skill.quick_time) else 1.0


## Whether the QTE on `skill` has its say on the hit on `target`: every hit for
## the Attacker's, only the party's for the Defender's.
static func quick_time_governs(skill: SkillDefinition, target: Dictionary) -> bool:
	if skill == null or skill.quick_time == null:
		return false
	return skill.quick_time_for == 0 or (target.get("side", 1) == 0 and not target.get("ai_controlled", false))


## --- Body parts ---
##
## Somebody big can have parts (CombatantDefinition.parts, BodyPartDefinition):
## tiles of theirs that can be aimed at and broken - a called shot. A hit aimed
## at one of those tiles (_aimed_tile, set by use_skill for the use being
## resolved) hurts the part as much as the body; a part that has taken its share
## of their health breaks, for good: legs that cannot carry them (Crippled),
## arms that hit for less and a plate that lets more through (parts_multiplier,
## in damage_dealt_multiplier), a boss's weak point that staggers it, or a
## weapon arm whose skills are gone. Health per part is `comb.parts_hp`, broken
## ones `comb.parts_broken` (indices).

const CRIPPLED := preload("res://data/conditions/crippled.tres")
const PART_COLOUR := Color("f0a060")

## The tile the use being resolved was aimed at, while it is; null otherwise.
var _aimed_tile = null


## Which of `comb`'s parts covers `tile`, or -1.
func part_index_at(comb: Dictionary, tile: Vector2i) -> int:
	if not comb.has("parts"):
		return -1
	var offset: Vector2i = tile - comb.position
	for i in comb.parts.size():
		if comb.parts[i].tiles.has(offset):
			return i
	return -1


## Whether `comb`'s part `index` is broken.
func part_broken(comb: Dictionary, index: int) -> bool:
	return comb.get("parts_broken", []).has(index)


## What the hover says about aiming at `tile` of `comb`: "Legs - 12 to break:
## cannot move", or "" for no part there.
func part_note(comb: Dictionary, tile: Vector2i) -> String:
	var index := part_index_at(comb, tile)
	if index == -1:
		return ""
	var part: BodyPartDefinition = comb.parts[index]
	if part_broken(comb, index):
		return "%s - broken" % part.name
	return "%s - %d to break: %s" % [part.name, comb.parts_hp[index], part.describe_broken()]


## A hit of `damage` on `target`, aimed at one of their parts: the part takes
## it too, and breaks once it has taken its share.
func _hit_part(target: Dictionary, damage: int):
	if _aimed_tile == null or damage <= 0 or not target.has("parts") or not target.get("alive", false):
		return
	var index := part_index_at(target, _aimed_tile)
	if index == -1 or part_broken(target, index):
		return
	target.parts_hp[index] = maxi(target.parts_hp[index] - damage, 0)
	if target.parts_hp[index] == 0:
		_break_part(target, index)


func _break_part(target: Dictionary, index: int):
	var part: BodyPartDefinition = target.parts[index]
	var broken: Array = target.get("parts_broken", [])
	broken.append(index)
	target["parts_broken"] = broken
	update_information.emit("[color=red]%s[/color]'s %s break%s - %s!\n" % [
		target.name, part.name.to_lower(), "" if part.name.ends_with("s") else "s", part.describe_broken()])
	float_number(target, "%s broken!" % part.name, PART_COLOUR)
	match part.when_broken:
		BodyPartDefinition.Broken.ROOTED:
			# Past any immunity: it is not a condition put on them, it is their legs.
			replace_matching_tick(target, "condition", CRIPPLED, 0)
			target.status_effects.append({"stat" = "condition", "condition" = CRIPPLED, "duration" = 999,
				"ends_at_start" = false, "source_name" = part.name})
		BodyPartDefinition.Broken.STAGGERED:
			if target.has("stagger_max"):
				add_stagger(target, part.stagger)
		BodyPartDefinition.Broken.DISARMED:
			for key in part.disarms:
				target.skill_list.erase(key)
				if target.has("declared") and target.declared.skill == key:
					drop_declared(target, "its weapon is gone")
	update_combatants.emit(combatants)


## What broken parts do to a hit by `attacker` on `target`: weakened arms on
## the one hitting, an exposed plate on the one hit.
func parts_multiplier(attacker: Dictionary, target: Dictionary) -> float:
	var multiplier := 1.0
	for index in attacker.get("parts_broken", []):
		var part: BodyPartDefinition = attacker.parts[index]
		if part.when_broken == BodyPartDefinition.Broken.WEAKENED:
			multiplier *= part.weakened_to
	for index in target.get("parts_broken", []):
		var part: BodyPartDefinition = target.parts[index]
		if part.when_broken == BodyPartDefinition.Broken.EXPOSED:
			multiplier *= part.exposed_by
	return multiplier


## Every part on the board, for the controller to outline while aiming:
## [{tiles, broken}].
func part_marks() -> Array:
	var marks := []
	for comb in combatants:
		if not comb.get("alive", false) or not comb.has("parts"):
			continue
		for i in comb.parts.size():
			marks.append({"tiles": comb.parts[i].tiles.map(func(offset): return comb.position + offset), "broken": part_broken(comb, i)})
	return marks


## --- Rebinding ---
##
## A creature held by a binding (CombatantDefinition.bound_to - a golem made to
## answer to a sorcerer) can have the binding hacked: Prometheus's Hack aimed at
## it plays its Rebind Hack, a Rewrite the Rule whose last line is who it
## answers to. Done, it fights for the party (switch_sides) for Rebind Turns of
## its own turns - or the rest of the fight with 0 - and then answers to its
## master again. Failed, the binding is as Hacking says: locked against him for
## the fight, if it locks for good.


## A bound creature of the other side's on `tile`, with a binding to hack, or {}.
func _bound_at(tile: Vector2i) -> Dictionary:
	for comb in combatants_at(tile):
		if comb.has("bound_to") and comb.get("rebind_hack") != null and comb.side == Group.ENEMIES and not comb.has("turncoat"):
			return comb
	return {}


func _rebind(hacker: Dictionary, target: Dictionary, hacking, end_turn_after: bool, as_secondary: bool):
	if target.get("hack_locked", false):
		update_information.emit("[color=red]%s[/color]'s binding is locked against hacking now.\n" % target.name)
		return
	var outcome: Dictionary = await hacking.run(target.rebind_hack, "", self, hacker)
	if not still_running():
		return
	match outcome.get("result", ""):
		"success":
			var turns: int = target.get("rebind_turns", 0)
			switch_sides(target, turns, "[color=yellow]%s[/color] rewrites [color=red]%s[/color]'s binding - it answers to him now%s.\n" % [
				hacker.name, target.name, (", for %d of its turns" % turns) if turns > 0 else ""])
		"failed":
			if outcome.get("locked_out", false):
				target["hack_locked"] = true
		_:
			return
	await _hack_spends_action(hacker, as_secondary, end_turn_after)


## --- The enemy codex ---
##
## Whoever keeps the codex (CombatantDefinition.keeps_codex - Enfina and
## Prometheus) writes an enemy's page as they study it, with Study or with a
## blow (Enfina's Measured Eye). A boss's second page needs them to study it again
## once it is past its first phase - or, for a boss with no phases, while it is
## staggered. See Campaign "The enemy codex".


func _write_codex(student: Dictionary, target: Dictionary):
	if not student.get("keeps_codex", false) or target.has("object") or target.get("illusion", false):
		return
	var key: String = target.get("combatant_key", "")
	if key == "" or not Campaign.codex_enemies().has(key):
		return
	var pages := Campaign.codex_pages(key)
	if pages == 0:
		Campaign.write_codex(key, 1)
	elif pages == 1 and target.has("boss") and _second_page_due(target):
		Campaign.write_codex(key, 2)


## Whether a boss has shown enough of itself for its second page.
func _second_page_due(boss: Dictionary) -> bool:
	if not boss.boss.phases.is_empty():
		return boss.get("phase", 0) >= 1
	return is_staggered(boss)


## --- Talking them round ---
##
## Intimidate, Persuade and Deceive (SkillDefinition.needs_leverage) live on a
## tab of their own on the HUD - Skills - which is only there when one of them
## can be used on somebody in this fight: somebody of the other side the party
## has leverage on (has_leverage) and who can be talked round at all.


## `comb`'s skills that talk somebody round.
func talk_skills_of(comb: Dictionary) -> Array:
	var found := []
	for key in comb.get("skill_list", []):
		var skill: SkillDefinition = SkillDatabase.skills.get(key)
		if skill != null and skill.needs_leverage and meets_level_for(comb, skill):
			found.append(key)
	return found


## Those of them there is somebody in this fight to use on.
func usable_talk_skills(comb: Dictionary) -> Array:
	var skills := talk_skills_of(comb)
	if skills.is_empty():
		return skills
	for other in combatants:
		if other.get("alive", false) and other.side != comb.get("side", 0) and not other.has("object") \
				and not other.get("illusion", false) and not immune_to(other, Immunity.Kind.SWAYED) and has_leverage(other):
			return skills
	return []


## --- Getting away ---
##
## Somebody broken who runs long enough gets away ("fled"). What comes of it is
## theirs to say (CombatantDefinition.when_fled): nothing more; they come back
## Back After Rounds later where they left, with whoever Brings Back names
## (_returning, brought in with the late arrivals at the top of that round); or
## the fight is lost - `lost_because` says why, and combat_finish and the
## results screen take it as a defeat whatever is left standing. Fled Flag is
## set either way, for a conversation afterwards.

## With ways out on the map (EncounterDefinition.escape_points), running is
## getting to one: whoever broke heads for the nearest by the ground they can
## cross (_escape_field), and is gone the moment they stand on one, however long
## it takes. On the way they use whatever gets them there sooner - a main or
## secondary action that adds to their walk (Run) or puts them somewhere else
## (a blink), and slipping past whoever's reach they leave. The party can stand
## on a way out to shut it. With no ways out, nobody gets away: they keep away.

## The ways out on this map, from the encounter.
var escape_points: Array = []


## Whether `comb` is standing on a way out - any tile of theirs.
func on_a_way_out(comb: Dictionary) -> bool:
	for tile in tiles_of(comb, comb.position):
		if tile in escape_points:
			return true
	return false


## What each tile costs to walk from to the nearest way out, for somebody who
## crosses the ground as `comb` does. A way out somebody else stands on is shut
## for now; anybody standing elsewhere is left out of it - they move. {tile:
## cost}; a tile missing has no way out from it at all.
func _escape_field(comb: Dictionary) -> Dictionary:
	var movement_class := terrain_class(comb)
	var cost := {}
	var buckets := {0: []}
	for tile in escape_points:
		var there := get_combatant_at(tile)
		if controller.is_tile_blocking(tile, movement_class) or (not there.is_empty() and there != comb):
			continue
		cost[tile] = 0
		buckets[0].append(tile)
	var level := 0
	while not buckets.is_empty():
		if not buckets.has(level):
			level += 1
			continue
		var here: Array = buckets[level]
		buckets.erase(level)
		for tile in here:
			if cost.get(tile, -1) != level:
				continue
			# Walking from `next` into `tile` costs what `tile` costs to enter.
			var step: int = level + maxi(controller.get_tile_cost_for_class(tile, movement_class), 1)
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					var next: Vector2i = tile + Vector2i(dx, dy)
					if next == tile or not controller.is_in_bounds(next) or controller.is_tile_blocking(next, movement_class):
						continue
					if step < cost.get(next, 999999):
						cost[next] = step
						if not buckets.has(step):
							buckets[step] = []
						buckets[step].append(next)
		level += 1
	return cost


## How far `comb` would still be from a way out standing at `anchor`, by
## `field` - the nearest of their tiles. Very far for nowhere with a way out.
func _left_to_run(comb: Dictionary, anchor: Vector2i, field: Dictionary) -> int:
	var best := 999999
	for tile in tiles_of(comb, anchor):
		best = mini(best, int(field.get(tile, 999999)))
	return best


## The best `comb` could do this turn with `budget` of walking: the tile to end
## on, and how far from a way out that leaves them.
func _best_run(comb: Dictionary, budget: int, field: Dictionary, from = null) -> Dictionary:
	var start: Vector2i = from if from != null else comb.position
	var best := {"tile": start, "left": _left_to_run(comb, start, field)}
	if budget <= 0:
		return best
	for tile in controller.get_reachable_tiles(start, comb.movement_class, budget, comb):
		var left := _left_to_run(comb, tile, field)
		if left < best.left:
			best = {"tile": tile, "left": left}
	return best


## What one of `comb`'s skills would do for getting away: {key, left, aim} -
## how far from a way out they could be by the end of the turn with it - or {}
## for nothing. A boost to their walk, or a blink somewhere nearer.
func _escape_skill_plan(comb: Dictionary, key: String, budget: int, field: Dictionary) -> Dictionary:
	var skill: SkillDefinition = SkillDatabase.skills.get(key)
	if skill == null or not can_afford_skill(comb, skill) or not meets_level_for(comb, skill) or wasted_on(comb, skill) != "":
		return {}
	if only_gets_you_moving(skill) and not skill.all_effects().is_empty():
		var boosted := budget
		for effect in skill.all_effects():
			if effect.type == EffectDefinition.EffectType.STAT_MULTIPLIER:
				boosted = int(boosted * effect.stat_multiplier)
			elif effect.type == EffectDefinition.EffectType.STAT_MODIFIER:
				boosted += int(effect.modifier_amount)
		return {"key": key, "left": _best_run(comb, boosted, field).left, "aim": comb.position}
	if skill.teleports == SkillDefinition.TeleportWho.CASTER and not skill.deals_damage and not skill.targets_ally:
		var best := {}
		var reach := effective_max_range(comb, skill)
		for dx in range(-reach, reach + 1):
			for dy in range(-reach, reach + 1):
				var tile: Vector2i = comb.position + Vector2i(dx, dy)
				var gap := distance_to(comb, tile)
				if gap < skill.min_range or gap > reach or not can_land_on(comb, tile):
					continue
				var left := maxi(_left_to_run(comb, tile, field) - budget, 0)
				if best.is_empty() or left < best.left:
					best = {"key": key, "left": left, "aim": tile}
		return best
	return {}


## A broken enemy, running for the nearest way out (escape_points): every move
## it has goes on getting there, and it is gone once it stands on one.
func _run_for_a_way_out(comb: Dictionary):
	if on_a_way_out(comb):
		_taken(comb, "fled")
		if still_running() and not combat_over:
			await advance_turn()
		return
	var field := _escape_field(comb)
	var budget := movement_budget_of(comb)
	var walking := _best_run(comb, budget, field)
	if walking.left >= 999999:
		# Every way out shut or out of its reach: away from the nearest of the
		# other side for now, and another look next turn.
		await _keep_away(comb)
		if still_running() and comb.alive and not combat_over:
			await advance_turn()
		return
	if walking.left > 0:
		# Its actions on getting there sooner: whichever of its moves leaves it
		# nearest a way out, main first, then the secondary.
		for as_secondary in [false, true]:
			if comb.get("secondary_used_this_turn" if as_secondary else "skill_used_this_turn", false):
				continue
			var keys: Array = secondary_skills_of(comb) if as_secondary else main_skills_of(comb)
			var best := {}
			for key in keys:
				var plan := _escape_skill_plan(comb, key, budget, field)
				if not plan.is_empty() and plan.left < walking.left and (best.is_empty() or plan.left < best.left):
					best = plan
			if best.is_empty():
				continue
			await use_skill(best.key, comb, best.aim, false, as_secondary)
			if not still_running() or not comb.alive or comb.has("taken"):
				return
			budget = movement_budget_of(comb) if comb != get_current_combatant() else controller.movement
			walking = _best_run(comb, budget, field)
			if walking.left <= 0:
				break
	# Whoever's reach it is leaving, it slips past if it can.
	for as_secondary in [false, true]:
		if comb.get("secondary_used_this_turn" if as_secondary else "skill_used_this_turn", false) or comb.get("reactions_suppressed", false):
			continue
		if walking.tile == comb.position or not _leaves_a_reach(comb):
			break
		for key in (secondary_skills_of(comb) if as_secondary else main_skills_of(comb)):
			var skill: SkillDefinition = SkillDatabase.skills.get(key)
			if skill != null and skill.suppresses_reactions and can_afford_skill(comb, skill) and wasted_on(comb, skill) == "":
				await use_skill(key, comb, comb.position, false, as_secondary)
				break
	if not still_running() or not comb.alive or comb.has("taken"):
		return
	if walking.tile != comb.position:
		await controller.ai_move(walking.tile)
	if not still_running() or not comb.alive or comb.has("taken"):
		return
	if on_a_way_out(comb):
		_taken(comb, "fled")
	if still_running() and not combat_over:
		await advance_turn()


## Whether anybody of the other side who could react has `comb` in reach.
func _leaves_a_reach(comb: Dictionary) -> bool:
	for other in combatants:
		if not other.alive or other.side == comb.side or other.get("reaction_used", false):
			continue
		if rect_gap(rect_of(other), rect_of(comb)) <= 1:
			return true
	return false


## Why the fight is lost though the party stands - somebody who must not get
## away got away - or "".
var lost_because := ""
## Who is coming back, and on which round: [{comb, round}].
var _returning: Array = []


func _got_away(comb: Dictionary):
	if comb.get("fled_flag", "") != "":
		Campaign.set_flag(comb.fled_flag)
	match comb.get("when_fled", 0):
		1:
			var round_back: int = round_number + maxi(comb.get("back_after_rounds", 2), 1)
			_returning.append({"comb": comb, "round": round_back})
			for key in comb.get("brings_back", []):
				if not CombatantDatabase.combatants.has(key):
					continue
				var help := SpawnDefinition.new()
				help.combatant_key = key
				help.side = 1
				help.position = comb.position
				help.level = comb.get("level", 1)
				help.weapon_base = comb.get("weapon_base", Stats.WEAPON_BASE)
				help.arrives_on_round = round_back
				_arriving.append(help)
			update_information.emit("[color=red]%s[/color] will be back%s.\n" % [
				comb.name, " - and not alone" if not comb.get("brings_back", []).is_empty() else ""])
		2:
			lost_because = "%s got away" % comb.name
			update_information.emit("[color=red]%s got away - and that is the fight lost.[/color]\n" % comb.name)
			combat_finish()


## Whoever got away and is due back this round comes back, where they left -
## their nerve steadied, the rest of them as they went.
func _bring_back_the_fled():
	var still_away: Array = []
	var came := false
	for entry in _returning:
		var comb: Dictionary = entry.comb
		if entry.round > round_number:
			still_away.append(entry)
			continue
		var tile := _free_tile_for(comb, comb.position)
		if tile.x == -99999:
			still_away.append(entry)
			continue
		var index := combatants.find(comb)
		comb.alive = true
		comb.erase("taken")
		comb.erase("fleeing")
		comb["shaken"] = 0
		var from: Vector2i = comb.position
		comb.position = tile
		if not groups[Group.ENEMIES].has(index):
			groups[Group.ENEMIES].append(index)
		var sprite = comb.get("sprite")
		if sprite != null and is_instance_valid(sprite):
			sprite.visible = true
			sprite.position = sprite_point(comb)
		controller.reposition_combatant(from, tile)
		update_information.emit("[color=red]%s[/color] is back!\n" % comb.name)
		came = true
	_returning = still_away
	if came:
		emit_signal("update_turn_queue", combatants, turn_queue)
		emit_signal("update_combatants", combatants)
