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
## One moment worth counting - a turn, an action, a hit, a heal, a gate, an
## item, a declared move, stagger (see "Metrics"). Nothing in the game listens;
## the laboratory sequence's LabMetrics does.
signal metric(event: String, data: Dictionary)

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
## The sound of a foreseen turn changed - the marks shattering (see
## _future_changed). Empty, a placeholder made on the spot stands in for it.
@export var future_shatter_sound: AudioStream

## The colour a changed future is written in, the Intuition marks' own.
const FUTURE_COLOUR := Color(0.4, 1.0, 0.95)
## The beat of frozen time a changed future gets, in seconds.
const FUTURE_HIT_STOP := 0.12
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


## --- Rolls ---
##
## Every roll in a fight - to hit, contests, damage ranges, which way the wind
## blows, the AI's choices - comes out of this one generator, so a fight begun
## from the same seed rolls the same on every machine (multiplayer/Net.gd).
## Nothing in a fight calls randf, randi or shuffle by itself.
var rng := RandomNumberGenerator.new()
## The seed this fight rolls from.
var fight_seed := 0


## The encounter's "seed" meta - a networked fight's - else any.
func _seed_wanted() -> int:
	if encounter != null and encounter.has_meta("seed"):
		return int(encounter.get_meta("seed"))
	return randi()


func seed_rolls(value: int):
	fight_seed = value
	rng.seed = value


## `array` shuffled in place by the fight's own rolls.
func _shuffle(array: Array):
	for i in range(array.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var kept = array[i]
		array[i] = array[j]
		array[j] = kept


## How the fight stands, as text: the round and whose turn, then everybody's
## side, health, tile, standing and conditions, a line each. Two machines
## replaying one fight from one seed and the same moves have the same text
## after every turn - a roll made outside `rng` sooner or later makes it
## differ. Numbers that are not whole are written to four places, so the last
## bit of a float cannot tell two machines apart.
func fight_state() -> String:
	var acting: Dictionary = combatants[current_combatant] if current_combatant < combatants.size() else {}
	var lines := ["round %d, the turn of %d" % [round_number, acting.get("id", -1)]]
	for comb in combatants:
		var effects := []
		for entry in comb.get("status_effects", []):
			var condition = entry.get("condition")
			var named := ""
			if condition is ConditionDefinition:
				named = condition.resource_path.get_file() if condition.resource_path != "" else condition.display_name
			effects.append("%s %s %s %s" % [entry.get("stat", ""), named, _state_value(entry.get("duration", "")), _state_value(entry.get("amount", ""))])
		effects.sort()
		lines.append("%d %s side %d hp %d at %s %s [%s]" % [comb.get("id", -1), comb.get("combatant_key", ""),
			comb.get("side", -1), comb.get("hp", 0), comb.get("position", Vector2i.ZERO),
			"up" if comb.get("alive", false) else "down", "; ".join(effects)])
	return "\n".join(lines)


func _state_value(value) -> String:
	return "%.4f" % value if value is float else str(value)


func _ready():
	emit_signal("register_combat", self)
	seed_rolls(_seed_wanted())

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
		if not party_spawn and not spawn.arrives_late():
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
		if not party_spawn and spawn.arrives_late():
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
		if spawn.has_meta("opened_on"):
			_opened_on = enemy
		if spawn.has_meta("wall_flag"):
			enemy["wall_flag"] = spawn.get_meta("wall_flag")
		if spawn.invisible:
			_invisible_from_the_start.append(enemy)
		if changing_sides.get(spawn.combatant_key, 0) > 0:
			changing_sides[spawn.combatant_key] -= 1
			bought.append(enemy)

	_deploy_party(player_tiles, fallback_party, player_loadouts)
	_begin_invisible()
	# Whoever brings a summon into every fight, with it beside them ("Summons").
	_bring_starting_summons()
	for enemy in bought:
		switch_sides(enemy, 0, "[color=yellow]%s[/color] has been paid to fight for the party.\n" % enemy.name)
	# Something on the map to use, and the party can use it.
	_offer_interact()
	# Somebody with a price, and the party can pay it.
	_offer_bribe()
	# The ways out, for anybody who breaks and runs (see "Getting away"). None,
	# and whoever is meant to run can never get away - said, for whoever made it.
	escape_points = encounter.escape_points.filter(func(tile): return controller.is_in_bounds(tile))
	# High ground and floors, and where to climb from (see "Heights").
	_setup_heights()
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
	# A fight ends the long rest's window for changing paths (Campaign.path_change_open).
	Campaign.path_change_open = false
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
			add_deepest_castings(comb)
			# Somebody who learns their spells has only those they have learned
			# (Campaign "Spellbooks"); Arena Mode knows everything.
			Campaign.forget_unlearned(comb, key)
		Campaign.apply_carried_state(comb, key)
		# Gates opened outside the fight - for a hack's hint - stay opened.
		Campaign.take_gates_spent_outside(comb, key)
		add_combatant(comb, 0, tiles[i])
		if loadout != null and loadout.invisible:
			_invisible_from_the_start.append(comb)
	# The gates opened only outside a fight (Iris) come back with a fight's own:
	# every fight, but in a dungeon only at a rest, as its own gates do.
	if not Campaign.in_dungeon():
		Campaign.outside_spent.clear()
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


## --- An ambush's opening blow ---
##
## An ambush sprung on a stealth map with a damaging move (OutsideMoves, Ambush;
## StealthWatch.ambush_with) opens with it: the encounter's "opener" meta names
## who and the move, and the spawn of the guard it was aimed at is marked
## "opened_on". Once everybody is placed and before the first turn, they use it
## on him - free, their own first turn untouched (a PROPOSAL, 2026-10-26: the
## designer left open whether it costs the action). Paid for as in any turn.

## The guard the opening blow is for, while it is still to land.
var _opened_on: Dictionary = {}
var _opening_done := false


## Whether there is an opening blow still to land.
func opener_due() -> bool:
	return not _opening_done and encounter != null and encounter.has_meta("opener")


## The opening blow, then the first turn.
func _open_the_ambush():
	_opening_done = true
	var opener: Dictionary = encounter.get_meta("opener")
	var who: Dictionary = {}
	for index in groups[Group.PLAYERS]:
		var comb: Dictionary = combatants[index]
		if comb.get("combatant_key", "") == opener.get("key", "") and comb.alive:
			who = comb
	var skill: SkillDefinition = SkillDatabase.skills.get(opener.get("move", ""))
	if not who.is_empty() and skill != null and not _opened_on.is_empty() and _opened_on.alive:
		var aim := nearest_tile_of(_opened_on, who.position)
		if distance_to(who, aim) <= effective_max_range(who, skill) and distance_to(who, aim) >= skill.min_range:
			update_information.emit("[color=yellow]%s[/color] opens with %s!\n" % [who.name, skill.name])
			await use_skill(opener.move, who, aim, false)
			if not still_running():
				return
			who.skill_used_this_turn = false
			who.secondary_used_this_turn = false
		else:
			update_information.emit("[color=yellow]%s[/color]'s %s falls short.\n" % [who.name, skill.name])
	start_first_turn()


## Sets the battle actually running. Separate from _ready because deployment
## sits in between.
func start_first_turn():
	if opener_due():
		_open_the_ambush.call_deferred()
		return
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
	# Left at 0 on the spawn, or with no spawn at all (a summon, a guard off a
	# stealth map), it is their own at this level.
	stats["defense"] = spawn.defense if spawn != null and spawn.defense > 0 else definition.defense_at(level)
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
		# Less what is cast only outside a fight (Find Familiar).
		"skill_list" = Combat.fighting_skills(definition.skills),
		"skill_levels" = definition.skill_levels.duplicate(),
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
		"pocket" = _pocket_from(spawn, definition.pocket_size),
		"ai_function" = definition.ai_function,
		# When the AI readies a move ("Readying, for the AI").
		"ai_readies" = definition.ai_readies,
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
		# Or something that is not there at all, save to the other side's mind
		# (Illusory Cover - "Images").
		if definition.illusion:
			comb["illusion"] = true
		# -1 for as often as you like.
		comb["uses_left"] = definition.uses if definition.uses > 0 else -1
		comb.movement = 0
		comb.initiative = 0
		comb["turns_per_round"] = 0
	# Their nerve (see "Nerve"), what they can be bought for and what the party
	# would need on them, a binding, and the parts of them that can be broken.
	comb["nerve"] = definition.nerve
	comb["keeps_codex"] = definition.keeps_codex
	comb["future_changed_lines"] = definition.future_changed_lines
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
	# The size they are without anything making them bigger ("Growing").
	comb["base_size"] = definition.size
	# And the size they began as, which a melee blow's area is measured from
	# (aoe_radius_of) - a phase that grows them for good still counts.
	comb["original_size"] = definition.size
	comb["gigantic_span"] = definition.gigantic_span
	# What their spells are worked out from, whichever spell (scaling_stat_of).
	comb["spellcasting_stat"] = definition.spellcasting_stat
	# Nothing touches them, and who they bring with them (see "Summons").
	if definition.untouchable:
		comb["untouchable"] = true
	if definition.summon_at_start != "":
		comb["summon_at_start"] = definition.summon_at_start
	# Their colour, how many they hold at once, and what they eat (see
	# "Swallowing" and "Gluttony").
	comb["tint"] = definition.tint
	comb["holds_at_once"] = definition.holds_at_once
	if definition.eats != 0:
		comb["eats"] = definition.eats
		comb["eat_reach"] = definition.eat_reach
		comb["meal_heals"] = definition.meal_heals
		comb["fed_effects"] = definition.fed_effects.duplicate()
	if definition.spat_out_with != null:
		comb["spat_out_with"] = definition.spat_out_with
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
	# How much they carry into a fight to use, what else they carry - no use in
	# one, a spellbook say - and what the encounter gave them to wear, all of it
	# for whoever loots them once they are down ("Loot").
	comb["pocket_size"] = definition.pocket_size
	comb["carried"] = _carried_from(spawn, definition.pocket_size)
	_wear_spawn_equipment(comb, spawn)
	# More castings through their deepest gate, if a passive gives them ("Progression").
	add_deepest_castings(comb)
	return comb


## `keys` without what is cast only outside a fight (SkillDefinition.outside_only -
## Find Familiar), which is nobody's to use in one.
static func fighting_skills(keys: Array) -> Array:
	return keys.filter(func(key): return not (SkillDatabase.skills.has(key) and SkillDatabase.skills[key].outside_only()))


## Puts `comb` on the path called `subclass` (SubclassDefinition), from the
## level paths open at: its skills and passives on top of their own. Each skill
## and passive still waits for its own level. Nothing for "" or below the level.
func take_path(comb: Dictionary, subclass: String):
	var path := SubclassDefinition.named(subclass) if subclass != "" else null
	if path == null or comb.get("level", 1) < Stats.SUBCLASS_LEVEL:
		return
	comb["subclass"] = subclass
	for key in Combat.fighting_skills(path.skills):
		if SkillDatabase.skills.has(key) and not comb.skill_list.has(key):
			comb.skill_list.append(key)
	for passive in path.passives:
		if passive != null and not comb.passives.has(passive):
			comb.passives.append(passive)
	# A path can teach spells to somebody who cast none, and gates are only
	# handed to those who do.
	if comb.max_spell_slots.all(func(count): return count == 0) and _casts_anything(comb):
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
	# Where they began - a guard's post ("Readying, for the AI").
	if not combatant.has("post"):
		combatant["post"] = position
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
	new_combatant_sprite.set_tint(combatant.get("tint", Color.WHITE))
	# Drawn to their size (Sizes.draw_scale): a quarter for Tiny, four times for
	# Enormous.
	var drawn := Sizes.draw_scale(combatant.get("size", Sizes.Size.HUMAN), combatant.get("span", 1))
	if not is_equal_approx(drawn, 1.0):
		new_combatant_sprite.scale *= drawn
	if side == 1:
		combatant["initiative"] -= 1
	combatant["sprite"] = new_combatant_sprite

	# A summon acts on its summoner's turn, never one of its own (see "Summons").
	if not combatant.has("object") and not combatant.has("summoner"):
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
	# Learned at a level of their own (CombatantDefinition.skill_levels).
	var own_levels: Dictionary = comb.get("skill_levels", {})
	if skill != null and not own_levels.is_empty():
		var key := skill.resource_path.get_file().get_basename()
		if own_levels.has(key):
			return comb.get("level", 1) >= int(own_levels[key])
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
	# Into the pouch, while there is something in it and room on the belt (see
	# "Drawing").
	if not found.has(DRAW_SKILL) and SkillDatabase.skills.has(DRAW_SKILL) and draw_refusal(comb) == "":
		found.append(DRAW_SKILL)
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
	# Anybody with a summon standing can command it (see "Summons").
	if not granted.has("command") and not summons_of(comb).is_empty():
		granted.append("command")
	# The party can go through the fallen of the other side (see "Loot").
	if not granted.has("loot") and comb.get("side", 1) == Group.PLAYERS and not comb.has("summoner") \
			and not comb.has("object") and any_body_to_loot(comb):
		granted.append("loot")
	# Into the pouch, for whoever handles items with the secondary (see "Drawing").
	if not granted.has(DRAW_SKILL) and items_as_secondary(comb) and draw_refusal(comb) == "":
		granted.append(DRAW_SKILL)
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
##
## A spell is worked out from its caster's spellcasting stat
## (CombatantDefinition.spellcasting_stat), whichever spell it is; a skill
## that costs no gate from its own.
func scaling_stat_of(attacker: Dictionary, skill: SkillDefinition) -> int:
	var passive = scaling_stat_from(attacker)
	if passive != null:
		return passive.scales_every_skill_with
	if is_spell(skill) and not skill is ItemDefinition and attacker.has("spellcasting_stat"):
		return attacker.spellcasting_stat
	return skill.scaling_stat


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
		# Through a gate they have yet to open: on their character sheet, not here.
		if not gate_opened_for(comb, skill):
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


## Whether `comb` has opened `skill`'s gate at all: castings through it, or a
## deeper one, at their level - spent or not. Free skills, and anybody casting
## without gates, always have.
func gate_opened_for(comb: Dictionary, skill: SkillDefinition) -> bool:
	if skill.spell_slot_level <= 0 or casts_without_gates(comb):
		return true
	for pool in [comb.get("max_spell_slots", []), comb.get("spell_slots", [])]:
		for gate in range(skill.spell_slot_level, pool.size()):
			if pool[gate] > 0:
				return true
	return false


## Whether `comb` can currently afford `skill` at all. Free skills always can.
func can_afford_skill(comb: Dictionary, skill: SkillDefinition) -> bool:
	if skill.spell_slot_level <= 0:
		return true
	if casts_without_gates(comb):
		return true
	if spares_left(comb, skill) > 0:
		return true
	return slot_available_for(comb, skill.spell_slot_level) > 0


## --- Spare castings ---
##
## Castings of somebody's own on top of their gates, for only the spells their
## passive names (PassiveDefinition.spare_castings - Alithia's Devotion: Heal,
## or Dread Visage). One pays for one of those spells in place of its gate, and
## is spent before any gate. They are spent until a rest (`spare_spent`, in
## SPENT_UNTIL_REST): a short rest gives back so many, a long rest all
## (Campaign.short_rest, long_rest). The designer, 2026-10-25.

## How many spare castings `comb` has when none are spent.
func spares_most(comb: Dictionary) -> int:
	var most := 0
	for passive in active_passives(comb):
		most += passive.spare_castings
	return most


## How many spare castings `comb` has left for `skill` - 0 for a spell no
## passive of theirs lets them pay for that way.
func spares_left(comb: Dictionary, skill: SkillDefinition) -> int:
	if skill == null or skill is ItemDefinition:
		return 0
	var key := skill_key_of(skill)
	if not active_passives(comb).any(func(passive): return passive.spare_castings > 0 and passive.spare_casting_spells.has(key)):
		return 0
	return maxi(spares_most(comb) - int(comb.get("spare_spent", 0)), 0)


## What their spare castings are called, for the log and the HUD: the first
## passive of theirs that gives any.
func spares_name(comb: Dictionary) -> String:
	for passive in active_passives(comb):
		if passive.spare_castings > 0:
			return passive.name
	return "spare castings"


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
		# More on a turn begun in cover (Cat Burglar I).
		if stat == "movement" and comb.get("started_in_cover", false):
			bonus += passive.movement_in_cover
	return bonus


## --- Ranks of a passive ---
##
## Passives that share a name but for the numeral on the end - Momentum I and II,
## Iron Hide I to III - are one passive in ranks (the designer, 2026-10-25). Each
## rank adds its numbers to the ones before, as separate passives always did; the
## character sheet shows only the highest unlocked, whose description gives the
## totals (CharacterSheet.passive_families).

const _NUMERALS := [" X", " IX", " VIII", " VII", " VI", " V", " IV", " III", " II", " I"]

## Passive -> the name of its family, worked out once.
static var _families := {}


## The name `passive` shares with its other ranks: its own, less the numeral.
static func passive_family(passive: PassiveDefinition) -> String:
	if _families.has(passive):
		return _families[passive]
	var named := passive.name.strip_edges()
	for numeral in _NUMERALS:
		if named.ends_with(numeral):
			named = named.trim_suffix(numeral)
			break
	_families[passive] = named
	return named


## Where `passive` stands among its ranks: I is 1, II 2, none 1.
static func passive_rank(passive: PassiveDefinition) -> int:
	var named := passive.name.strip_edges()
	for i in _NUMERALS.size():
		if named.ends_with(_NUMERALS[i]):
			return _NUMERALS.size() - i
	return 1


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
		if aoe_shape_of(enemy, skill) == SkillDefinition.AoEShape.DIAMOND:
			this += aoe_radius_of(enemy, skill)
		else:
			this = maxi(this, aoe_radius_of(enemy, skill))
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
	# What they would go for, as they see it: an image a body like any other.
	var believed := ai_believes
	ai_believes = true
	_believer_side = Group.ENEMIES if side == Group.PLAYERS else Group.PLAYERS
	var threat := {}
	var reaction := {}
	var across := {}
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
				# And the other floors, for anything aimed at a tile - through a gap
				# in the floor between ("Heights"). A line or a cone keeps to its own.
				if _floored and aoe_shape_of(enemy, skill) == SkillDefinition.AoEShape.DIAMOND:
					var over := Vector4i(far, near, int(skill.respects_blocking), -1)
					if not aimed.has(over):
						aimed[over] = _aims_across_floors(enemy, standing, far, near, skill.respects_blocking)
					landing = landing.merged(aimed[over])
				var radius := aoe_radius_of(enemy, skill)
				if radius > 0:
					if aoe_shape_of(enemy, skill) == SkillDefinition.AoEShape.DIAMOND:
						landing = _spread(landing.keys(), radius)
					else:
						# A line or a cone starts at the caster and runs its length.
						landing = landing.merged(_spread(standing, radius))
				theirs.merge(landing)
			sight.stand_back(enemy)
			var own := floor_of(enemy.position)
			for tile in theirs:
				threat[tile] = threat.get(tile, 0) + 1
				# The floors besides their own they reach - drawn red where they
				# are under or over the floor shown (CController._draw_ghosts).
				if _floored:
					var on := floor_of(tile)
					if on != own and on >= 0:
						if not across.has(enemy.get("id", -1)):
							across[enemy.get("id", -1)] = {}
						across[enemy.get("id", -1)][on] = true
		if trimmed:
			enemy.status_effects = now
			resync_movement_class(enemy)
		if enemy.get("reaction_used", false) or has_restriction(enemy, "prevents_reactions"):
			continue
		for key in enemy.skill_list:
			var skill: SkillDefinition = SkillDatabase.skills.get(key)
			if skill == null or not skill.reacts_to(SkillDefinition.Trigger.LEAVES_REACH):
				continue
			if not can_afford_skill(enemy, skill) or not meets_level_for(enemy, skill):
				continue
			var far = effective_max_range(enemy, skill)
			# From every edge of somebody bigger than a tile, not their corner.
			for tile in _spread(tiles_of(enemy), far):
				if distance_to(enemy, tile) < skill.min_range or distance_to(enemy, tile) > far:
					continue
				if skill.respects_blocking and not sees_tile(enemy, tile):
					continue
				reaction[tile] = true
			for tile in _reach_across_floors(enemy, skill, far):
				reaction[tile] = true
		# Stepping in sets something off too ("Reactions", "Ready"): an area they
		# readied a move over, or their reach, for a move readied - or a
		# reaction - for whoever steps into it.
		var readied: Dictionary = enemy.get("readied", {})
		for tile in readied.get("area", []):
			reaction[tile] = true
		var into_reach := []
		if readied.get("trigger", 0) == SkillDefinition.Trigger.ENTERS_REACH and SkillDatabase.skills.has(readied.skill):
			into_reach.append(SkillDatabase.skills[readied.skill])
		for key in enemy.skill_list:
			var skill: SkillDefinition = SkillDatabase.skills.get(key)
			if skill != null and skill.reacts_to(SkillDefinition.Trigger.ENTERS_REACH) and not skill.targets_ally \
					and skill.set_off_by != SkillDefinition.SetOffBy.ALLIES and can_afford_skill(enemy, skill):
				into_reach.append(skill)
		for skill in into_reach:
			var far = effective_max_range(enemy, skill)
			for tile in _spread(tiles_of(enemy), far):
				if distance_to(enemy, tile) < skill.min_range or distance_to(enemy, tile) > far:
					continue
				if skill.respects_blocking and not sees_tile(enemy, tile):
					continue
				reaction[tile] = true
			for tile in _reach_across_floors(enemy, skill, far):
				reaction[tile] = true
	ai_believes = believed
	return {"threat": threat, "reaction": reaction, "across": across}


## The tiles on other floors than `enemy`'s that `skill` reaches from where they
## stand, for a reaction: through open air, with a clear line when it needs one
## ("Heights"). None for a melee blow, which keeps to its own floor.
func _reach_across_floors(enemy: Dictionary, skill: SkillDefinition, far: int) -> Array:
	if not _floored or is_melee(skill):
		return []
	return _aims_across_floors(enemy, [enemy.position], far, skill.min_range, skill.respects_blocking).keys()


## Every tile `enemy` could aim at from somewhere in `standing`, between `near`
## and `far` steps away - with a clear line to it, when `needs_sight`.
func _aim_points(enemy: Dictionary, standing: Array, far: int, near: int, needs_sight: bool, sight: _SightGrid) -> Dictionary:
	# Somebody bigger than a tile reaches, and looks, from every edge of the
	# square they would stand in - not from its corner, past their own body.
	var shape := footprint(enemy)
	var covered: Array = standing
	if shape != Vector2i.ONE:
		var seen := {}
		for anchor in standing:
			for tile in tiles_of(enemy, anchor):
				seen[tile] = true
		covered = seen.keys()
	var candidates := _spread(covered, far)
	if not needs_sight:
		return candidates
	var aims := {}
	for tile in candidates:
		if _aim_blocked(tile, enemy.movement_class):
			continue
		for from in standing:
			var source: Vector2i = from
			if shape != Vector2i.ONE:
				var square := rect_of(enemy, from)
				source = Vector2i(clampi(tile.x, square.position.x, square.end.x - 1), clampi(tile.y, square.position.y, square.end.y - 1))
			var gap = absi(source.x - tile.x) + absi(source.y - tile.y)
			if gap > far or gap < near:
				continue
			# With high ground about, the whole rule ("Heights") - the flat grid
			# knows nothing of who is up.
			var clear: bool = has_line_of_sight(source, tile, terrain_class(enemy), enemy.get("size", Sizes.Size.HUMAN)) if _heights \
				else sight.clear(source, tile, terrain_class(enemy), enemy.get("size", Sizes.Size.HUMAN))
			if clear:
				aims[tile] = true
				break
	return aims


## Every tile on another floor than its own that `enemy` could aim at from
## somewhere in `standing` - between `near` and `far` away, the storeys between
## counted, through open air in any floor between, and with a clear line to it
## when `needs_sight` ("Heights"). The other floors' half of _aim_points.
func _aims_across_floors(enemy: Dictionary, standing: Array, far: int, near: int, needs_sight: bool) -> Dictionary:
	var aims := {}
	if not _floored or far <= 0 or standing.is_empty():
		return aims
	var here := floor_of(standing[0])
	if here < 0:
		return aims
	var movement_class := terrain_class(enemy)
	var size: int = enemy.get("size", Sizes.Size.HUMAN)
	var reals: Array = standing.map(func(tile): return real_of(tile))
	for i in floors.size():
		var rise: int = absi(floors[i].level - floors[here].level)
		if i == here or rise > far:
			continue
		# Where over the ground it might reach, then whether anywhere they could
		# stand does reach it.
		for spot in _spread_over_ground(reals, far - rise):
			var tile := tile_on(i, spot)
			if tile.x == -99999 or not controller.is_on_map(tile):
				continue
			if needs_sight and _aim_blocked(tile, movement_class):
				continue
			for k in standing.size():
				var gap: int = absi(reals[k].x - spot.x) + absi(reals[k].y - spot.y) + rise
				if gap > far or gap < near:
					continue
				var clear: bool = has_line_of_sight(standing[k], tile, movement_class, size) if needs_sight \
					else floors_open_between(standing[k], tile)
				if clear:
					aims[tile] = true
					break
	return aims


## Every spot over the ground within `reach` steps of any of `reals` - _spread,
## over the ground rather than on a floor.
static func _spread_over_ground(reals: Array, reach: int) -> Dictionary:
	var seen := {}
	var frontier: Array = []
	for spot in reals:
		if not seen.has(spot):
			seen[spot] = true
			frontier.append(spot)
	for step in reach:
		var next: Array = []
		for spot in frontier:
			for way in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
				var there: Vector2i = spot + way
				if not seen.has(there):
					seen[there] = true
					next.append(there)
		frontier = next
	return seen


## has_line_of_sight, for asking tens of thousands of times at once: the
## same walk from the same end of the pair, stopped by the same things, read
## off a flat grid built once instead of through three lookups a step.
class _SightGrid:
	## What a standing breakable wall counts as: bigger than any viewer.
	const WALL_BODY := 255
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
		# An image is a body only to the other side's mind (Combat.believes_illusion).
		if comb.get("illusion", false) and not _controller.combat.believes_illusion(comb):
			return
		var value: int = comb.get("size", Sizes.Size.HUMAN) + 1
		# A breakable wall is a wall to everybody, however big (CController.blocks_sight).
		if Combat.is_wall(comb):
			value = WALL_BODY
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
## count of steps, walls and all, the way a skill's reach is measured - on the
## floor each starts on (_aims_across_floors has the others).
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
			var here := floor_of(tile) if _floored else -1
			for step in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
				var there = tile + step
				if seen.has(there) or not controller.is_in_bounds(there):
					continue
				if here >= 0 and floor_of(there) != here:
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
	# Every gate open at once, for a turn (Grand Design).
	return comb.has("status_effects") and has_restriction(comb, "casts_freely")


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
## any level, or on any of their paths (knows_or_can_learn) - so a Communion
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
## just save it in a folder of data/skills/ and put its key - the file name - in a
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
##
## A skill Placed In Reach is aimed at whoever it is of, anywhere, and put down
## at `destination`, which has to be in reach (an AI giving none puts it beside
## them, if they are in reach).
##
## What it does goes by what is there, whatever the AI took it for: an image
## stops nothing (ai_believes is off while it resolves).
func use_skill(skill_key: String, attacker: Dictionary, impact_position: Vector2i, end_turn_after: bool = true, as_secondary: bool = false, destination: Vector2i = Vector2i(-99999, -99999), landing: bool = false):
	var believed := ai_believes
	ai_believes = false
	await _use_skill(skill_key, attacker, impact_position, end_turn_after, as_secondary, destination, landing)
	ai_believes = believed


func _use_skill(skill_key: String, attacker: Dictionary, impact_position: Vector2i, end_turn_after: bool, as_secondary: bool, destination: Vector2i, landing: bool):
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
	# Placed (an image, put down where aimed): whoever it is of can be anywhere of
	# theirs, and where it goes is what has to be in reach.
	if skill.placed_in_reach and not landing and destination != NO_AREA:
		var chosen := get_combatant_at(impact_position)
		valid = not chosen.is_empty() and chosen.get("side", -1) == attacker.get("side", -2) \
			and get_range_tiles(skill, attacker.position, attacker.get("movement_class", 0), attacker).has(destination)
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
	# Anything ruling it out for where it is aimed (refusal_for):
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
	# Going through a fallen enemy - see "Loot".
	if valid and loots(skill):
		if as_secondary:
			attacker.secondary_used_this_turn = true
		else:
			attacker.skill_used_this_turn = true
		loot(attacker, body_to_loot(impact_position, attacker))
		if game_ui != null and game_ui.has_method("refresh_action_buttons"):
			game_ui.refresh_action_buttons()
		return
	# Something out of the pouch and onto the belt - see "Drawing".
	if valid and draws(skill):
		var drawn := await _choose_draw(attacker)
		if not still_running() or drawn == "":
			return
		if as_secondary:
			attacker.secondary_used_this_turn = true
		else:
			attacker.skill_used_this_turn = true
		draw_into_belt(attacker, drawn)
		if game_ui != null and game_ui.has_method("refresh_action_buttons"):
			game_ui.refresh_action_buttons()
		return
	# Commanding a summon: its moment of this turn, now - see "Summons".
	if valid and commands(skill):
		if as_secondary:
			attacker.secondary_used_this_turn = true
		else:
			attacker.skill_used_this_turn = true
		await command(attacker, get_combatant_at(impact_position))
		return
	# Prometheus's Hack, or Using something that has to be hacked first: the
	# minigame decides it before anything else happens (see "Hacking").
	if valid and (_hacks(skill) or (_interacts(skill) and not _hack_locked_object_at(impact_position).is_empty())):
		await _hack_in_fight(attacker, skill_key, skill, impact_position, end_turn_after, as_secondary)
		return
	# Declared (SkillDefinition.declared): announced now, for nothing - it lands
	# at the start of their next turn (declare, land_declared).
	if valid and skill.declared and not landing:
		await declare(attacker, skill_key, impact_position, as_secondary, destination)
		return
	# A spell is answered as it is cast, before any of it happens (Casts) - and
	# cancelled there (InstaHack's cancel_casting), it comes to nothing.
	if valid and is_spell(skill):
		if await _react_to_casting(attacker, skill_key, skill):
			await _cast_cancelled(attacker, skill_key, skill, end_turn_after, as_secondary)
			return
		if not still_running() or not attacker.alive:
			return
	# Through which gate, for a spell cast through whichever its caster likes
	# (chooses_gate - Dispel Magic): asked now, paid as it lands.
	if valid and skill.chooses_gate and not attacker.has("cast_through"):
		attacker["cast_through"] = await _choose_gate(attacker, skill)
		if not still_running():
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
		_pay_for_cast(attacker, skill)
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
		var tiles = get_impact_tiles(skill, nearest_tile_of(attacker, impact_position), impact_position, terrain_class(attacker), attacker.get("size", Sizes.Size.HUMAN), attacker)
		var radius := aoe_radius_of(attacker, skill)
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
		if radius == 0 and aoe_shape_of(attacker, skill) == SkillDefinition.AoEShape.DIAMOND and targets.size() > 1:
			var picked = targets.filter(func(each): return each.get("id", -1) == aim_choice)
			targets = [picked[0] if not picked.is_empty() else targets[0]]
		aim_choice = -1
		# Before anything lands, whoever can react to it does ("Reactions"): a blow
		# foreseen, a spell being cast, somebody about to be hit, an ally of theirs.
		await _react_before(attacker, skill, skill_key, targets)
		if not still_running() or not attacker.alive:
			return
		if has_restriction(attacker, "skips_turn"):
			update_information.emit("[color=yellow]%s[/color] is stopped before %s lands.\n" % [attacker.name, skill.name])
			targets = []
		targets = targets.filter(func(target): return target.get("alive", false) or skill.targets_fallen)
		# Whoever it hurts, for what goes off once it has (Struck).
		var struck := []
		# Held on a tether ("Tethers"): what everybody carried before, so what
		# it adds can be marked as its own.
		var carried_before := []
		if skill.tethered:
			for other in combatants:
				carried_before.append([other, other.get("status_effects", []).duplicate()])
		# What it calls into the fight, on the tile aimed at ("Summons").
		_summoned_now = []
		var trapped_ground := false
		for effect in skill.all_effects():
			if effect != null and effect.type == EffectDefinition.EffectType.SUMMON and effect.summons != "":
				summon(attacker, effect, impact_position, skill)
			# A trap on the ground aimed at ("Traps"), or a zone left on it ("Zones").
			if effect != null and effect.type == EffectDefinition.EffectType.TRAP:
				set_trap(attacker, effect, impact_position, skill)
				trapped_ground = true
			if effect != null and effect.type == EffectDefinition.EffectType.ZONE:
				lay_zone(attacker, effect, tiles, skill)
				trapped_ground = true
			# Dispel Magic at bare ground: the zone on it; at cover that is not there,
			# the spell that made it - nothing else ever touches it ("Dispelling").
			if effect != null and effect.type == EffectDefinition.EffectType.DISPEL_MAGIC:
				var there := get_combatant_at(impact_position)
				if there.is_empty():
					dispel_zones_at(attacker, impact_position, skill)
					trapped_ground = true
				elif there.has("object") and there.get("illusion", false):
					dispel_magic(attacker, there, skill)
					trapped_ground = true
		_dealt_now = 0
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
			if not skill.uses_stat_contest and (rng.randi() % 100) >= hit_chance(attacker, skill, target):
				update_information.emit("[color=yellow]%s[/color] missed [color=red]%s[/color].\n" % [
					attacker.name, target.name])
				continue
			# An illusion takes it instead (see "The paths").
			if _evades(attacker, target, skill):
				continue
			connected = true
			# Only the first effect on each target names the skill, so a
			# multi-effect hit reads as one action rather than repeating
			# "used Poison Dart" for every effect it carries.
			var mention_skill = true
			var grazed = skill.uses_stat_contest and not wins_contest(attacker, target, skill)
			if grazed:
				update_information.emit(_contest_lost_line(attacker, target, skill))
			# Somebody warding them may take some of it off (the Abjurer's).
			var warded: float = await _offer_ward(attacker, target, skill)
			if not still_running():
				return
			# Which of their containers a Steal empties ("Stealing").
			if steals(skill):
				_steal_from = await _choose_container(attacker, target)
				if not still_running():
					return
			# Which of what is on them a cleanse - or a heal that lifts - takes
			# off, when it cannot take it all ("Cleansing: choosing what comes off").
			_lift_picks = await _choose_lifts(attacker, target, skill)
			if not still_running():
				return
			# Where it was aimed, for a part of somebody big (see "Body parts") -
			# none for an area, which hits the whole of them.
			_aimed_tile = _aim_from_inside(attacker, target, impact_position) if aims_at_parts(attacker, skill) else null
			# Where what it makes goes, for a skill Placed In Reach (summon_decoy).
			_placing_at = destination if skill.placed_in_reach else NO_AREA
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
				apply_effect(attacker, target, effect, skill, mention_skill, (0.5 if grazed else 1.0) * warded * (quick if quick_time_governs(skill, target) else 1.0), impact_position if radius > 0 else attacker.position)
				mention_skill = false
			_aimed_tile = null
			_placing_at = NO_AREA
			_steal_from = ""
			_lift_picks = []
			if not grazed:
				_after_landing(attacker, target, skill)
			if skill.deals_damage and target.get("side", -1) != attacker.get("side", -1):
				struck.append(target)
		# And what the skill does to whoever used it - a swing that steadies the
		# arm that swung it. Once, however many it caught, and only because the
		# skill landed on somebody.
		if connected:
			# Light Swing's finishing mend: twice the share, once a foe.
			_share_times = _wounded_bonus(attacker, skill, struck)
			for effect in skill.all_effects():
				if not effect.applies_to_caster or not attacker.alive:
					continue
				apply_effect(attacker, attacker, effect, skill, false)
			_share_times = 1.0
			# Their Guard covering those beside them too (Covering Stance).
			_cover_with_guard(attacker, skill_key, skill)
		elif targets.is_empty() and _summoned_now.is_empty() and not trapped_ground:
			# Nothing was standing there to roll against in the first place.
			update_information.emit("{0} hit nothing.\n".format([attacker.name]))
		# Held on a tether from now on, if anything came of it: everything it
		# put on anybody, and everything it called up, goes when that breaks.
		if skill.tethered and attacker.alive and (connected or not _summoned_now.is_empty()):
			var tether_id := tie_tether(attacker, skill_key, skill)
			for pair in carried_before:
				var had: Array = pair[1]
				for entry in pair[0].get("status_effects", []):
					if not had.any(func(old): return is_same(old, entry)):
						entry["tether_of"] = tether_id
			for called in _summoned_now:
				called["tether_of"] = tether_id
		_summoned_now = []
		# What the paths make of a spell that landed (see "The paths"): a leap to
		# one more (Chain), the whole of it again (Conduit), a share of it mended
		# (Righteous).
		if attacker.alive:
			_chain(attacker, skill, struck)
			if not struck.is_empty() and _conduit_ready(attacker, skill):
				_cast_again(attacker, skill, struck)
			_righteous(attacker, skill)
		_dealt_now = 0
		# Counted for Kindling: the next ones burn hotter.
		if is_spell(skill):
			attacker["spells_cast"] = attacker.get("spells_cast", 0) + 1
		# The element they last used (Elemental Armour), and cast (Resonance).
		if skill.deals_damage:
			attacker["last_element"] = effective_damage_type(attacker, skill.damage_type)
			if is_spell(skill):
				attacker["last_spell_element"] = attacker.last_element
		# Whoever they hurt this turn - not Exposed to them (see "Hemmed In and Exposed").
		_note_struck(attacker, struck)
		_note_path_hits(attacker, struck, skill)
		# Whoever was moved by it, into or out of a zone ("Zones").
		sync_zones()
		# And whoever it hurt answers it, if they can (Struck).
		await _react_after(attacker, struck)
		if not still_running():
			return
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
		# A step after whoever their Tremor threw back, taken for them: free,
		# and provoking nothing (tremor_step_to).
		var follow: Vector2i = tremor_step_to(attacker) if attacker.alive else attacker.position
		attacker.erase("tremor_struck")
		if follow != attacker.position and teleport_to(attacker, follow):
			update_information.emit("[color=yellow]%s[/color] steps in after them.\n" % attacker.name)
			sync_zones()
		if as_secondary:
			attacker.secondary_used_this_turn = true
		else:
			attacker.skill_used_this_turn = true
		# Given back as it was spent: a kill that spurs them on (Rampage), or the
		# first spell of a Grand Design.
		if is_spell(skill) and has_restriction(attacker, "casts_freely") and not attacker.get("designed", false):
			attacker["designed"] = true
			attacker["action_back"] = true
		if attacker.get("action_back", false):
			attacker.erase("action_back")
			if attacker.alive:
				attacker.skill_used_this_turn = false
				update_information.emit("[color=yellow]%s[/color] has their action back.\n" % attacker.name)
		_metric("action", {"who": attacker, "skill": skill, "secondary": as_secondary, "landing": landing})
		# A weapon attack made: Disarmed comes off ("Disarmed").
		_weapon_attack_made(attacker, skill)
		# Counted for what can be used only so often a short rest
		# (uses_per_short_rest, SPENT_UNTIL_REST).
		if skill.uses_per_short_rest > 0:
			var uses: Dictionary = attacker.get("uses", {})
			uses[skill_key] = uses.get(skill_key, 0) + 1
			attacker["uses"] = uses
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


## What casting `skill` costs `attacker`, spent: its gate - or, amplified (the
## Demolitionist's), a free amplification or a deeper gate in its place.
func _pay_for_cast(attacker: Dictionary, skill: SkillDefinition):
	# Through a gate of their choosing (SkillDefinition.chooses_gate - Dispel Magic).
	var through: int = attacker.get("cast_through", 0)
	attacker.erase("cast_through")
	# A spare casting of their own, before any gate (see "Spare castings").
	if through <= 0 and not casts_without_gates(attacker) and spares_left(attacker, skill) > 0:
		attacker["spare_spent"] = int(attacker.get("spare_spent", 0)) + 1
		update_information.emit("[color=yellow]%s[/color] spends one of %s (%d left).\n" % [
			attacker.name, spares_name(attacker), spares_left(attacker, skill)])
		_metric("spare", {"who": attacker, "skill": skill})
		_casting_skill = skill
		_casting_gate = skill.spell_slot_level
		return
	var spent := 0
	if through > 0 and not casts_without_gates(attacker) and through < attacker.spell_slots.size() and attacker.spell_slots[through] > 0:
		attacker.spell_slots[through] -= 1
		spent = through
	elif through <= 0 or not casts_without_gates(attacker):
		through = 0
		var deeper := settle_amplify(attacker, skill)
		spent = deeper if deeper > 0 else spend_slot_for(attacker, skill)
		if deeper > 0:
			attacker.spell_slots[deeper] -= 1
	if spent > 0:
		update_information.emit("[color=yellow]%s[/color] spends %s.\n" % [attacker.name, Stats.short_gate_name(spent)])
		_metric("gate", {"who": attacker, "gate": spent, "skill": skill})
	# The gate it came through, for what it leaves on people ("Dispelling").
	_casting_skill = skill
	_casting_gate = maxi(maxi(spent, through), skill.spell_slot_level if skill != null else 0)


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
	# Into cover, for somebody whose stepping into it sets nothing off (Agile II).
	if in_cover(mover) and active_passives(mover).any(func(passive): return passive.slips_into_cover):
		return
	for reactor in combatants:
		if not reactor.alive or reactor == mover or reactor.reaction_used or is_inside(reactor):
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
			if not skill.reacts_to(SkillDefinition.Trigger.LEAVES_REACH):
				continue
			if not can_afford_skill(reactor, skill) or not meets_level_for(reactor, skill):
				# Out of slots for it, or not learned yet - either way there is
				# nothing to offer and nothing to ask the player about.
				continue
			# Somebody its Set Off By lets set it off, and somebody it is for: a
			# skill that hurts is never used on an ally, nor one for allies on an
			# enemy.
			var valid_side = SkillDefinition.sets_off(Trigger.LEAVES_REACH, skill.set_off_by, reactor.side, mover.side) \
				and (reactor.side == mover.side) == skill.targets_ally
			if not valid_side:
				continue
			# Across floors only for what reaches through a gap ("Heights").
			var distance_before = reach_gap(reactor, mover, skill, previous_position)
			var distance_after = reach_gap(reactor, mover, skill, new_position)
			# The reactor's reach, not the skill's: a blinded one can only see
			# the tile beside them, and use_reactive_skill checks line of sight
			# but never range, so this is the only thing standing between a
			# blinded combatant and a shot across the map.
			var reach = effective_max_range(reactor, skill)
			var was_in_range = distance_before >= skill.min_range and distance_before <= reach
			var now_in_range = distance_after >= skill.min_range and distance_after <= reach
			if not was_in_range or now_in_range:
				continue
			if skill.respects_blocking and not sees_tile(reactor, previous_position, mover):
				# The shot was blocked anyway - use_reactive_skill would bail on
				# the same check, so there's nothing worth asking about.
				continue
			if not _reaches_through_floors(reactor, mover, previous_position):
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
		if not mover.alive or not still_running() or combat_over:
			return
		# Grabbed on the way out: dragged back, and nobody else need bother.
		if holder_of(mover).get("id", -2) == reactor.get("id", -1):
			_drag_back(mover, reactor, previous_position)
			return
	# Stepping into somebody's reach, or into an area marked for it ("Reactions").
	await _react_to_step(mover, previous_position, new_position)


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
func use_reactive_skill(skill_key: String, attacker: Dictionary, target: Dictionary, trigger_position: Vector2i, why: String = ""):
	var skill: SkillDefinition = SkillDatabase.skills[skill_key]
	if skill.respects_blocking and not is_same(attacker, target) and not sees_tile(attacker, trigger_position, target):
		return
	attacker.reaction_used = true
	if attacker.side == 0 and skill.can_be_copied:
		last_player_skill_used = skill_key
	var spent = spend_slot_for(attacker, skill)
	if spent > 0:
		update_information.emit("[color=yellow]%s[/color] spends %s.\n" % [attacker.name, Stats.short_gate_name(spent)])
		_metric("gate", {"who": attacker, "gate": spent, "skill": skill})
	_metric("action", {"who": attacker, "skill": skill, "secondary": false, "landing": false, "reaction": true})
	if why == "":
		update_information.emit("[color=yellow]{0}[/color] reacts as [color=red]{1}[/color] leaves range!\n".format([
			attacker.name,
			target.name
		]))
	else:
		update_information.emit("[color=yellow]%s[/color] reacts with %s - %s!\n" % [attacker.name, skill.name, why])
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
	_land_reaction(attacker, skill, target)


## A reaction's skill landing on `target`: the roll (or the contest), and what
## it does - the same for a reactive skill and a readied move.
func _land_reaction(attacker: Dictionary, skill: SkillDefinition, target: Dictionary):
	var connected = true
	if not skill.uses_stat_contest:
		connected = (rng.randi() % 100) < hit_chance(attacker, skill, target)
	# An illusion takes it instead (see "The paths").
	if connected and _evades(attacker, target, skill):
		return
	if connected:
		var mention_skill = true
		var grazed = skill.uses_stat_contest and not wins_contest(attacker, target, skill)
		if grazed:
			update_information.emit(_contest_lost_line(attacker, target, skill))
		for effect in skill.all_effects():
			if grazed and effect.type != EffectDefinition.EffectType.DAMAGE:
				continue
			apply_effect(attacker, target, effect, skill, mention_skill, 0.5 if grazed else 1.0)
			mention_skill = false
		if skill.deals_damage:
			_note_struck(attacker, [target])
			var opened: Array = attacker.get("opened_on", [])
			if not opened.has(target.get("id", -1)):
				opened.append(target.get("id", -1))
				attacker["opened_on"] = opened
	else:
		update_information.emit("{0} missed.\n".format([attacker.name]))
	_weapon_attack_made(attacker, skill)


## Remembers that `attacker` hurt each of `struck` this turn, for Exposed.
func _note_struck(attacker: Dictionary, struck: Array):
	if struck.is_empty():
		return
	var ids: Array = attacker.get("struck_this_turn", [])
	for target in struck:
		if not ids.has(target.get("id", -1)):
			ids.append(target.get("id", -1))
	attacker["struck_this_turn"] = ids


## Manhattan distance between two grid positions - the same metric the rest
## of the game (movement, range) already uses. Between floors ("Heights"), the
## distance across them, and a step for every storey.
func get_position_distance(a: Vector2i, b: Vector2i) -> int:
	if _floored and floor_of(a) != floor_of(b):
		var ra := real_of(a)
		var rb := real_of(b)
		return absi(ra.x - rb.x) + absi(ra.y - rb.y) + absi(floor_level(a) - floor_level(b))
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
##
## `user`, given, is whoever uses it: a melee blow's area grows and shrinks with
## their size (aoe_radius_of).
func get_impact_tiles(skill: SkillDefinition, caster_position: Vector2i, aim_position: Vector2i, movement_class: int = 0, viewer_size: int = Sizes.Size.HUMAN, user: Dictionary = {}) -> Array:
	var tiles: Array
	var radius := aoe_radius_of(user, skill)
	var shape := aoe_shape_of(user, skill)
	match shape:
		SkillDefinition.AoEShape.LINE:
			tiles = get_line_tiles(caster_position, aim_position, radius, skill.aoe_width)
		SkillDefinition.AoEShape.CONE:
			tiles = get_cone_tiles(caster_position, aim_position, radius)
			# A blow grown into a cone still lands where it was aimed.
			if skill.aoe_radius == 0 and not tiles.has(aim_position):
				tiles.append(aim_position)
		_:
			# DIAMOND is centred on the clicked/aimed tile, not the caster.
			tiles = get_diamond_tiles(aim_position, radius)
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
		if shape != SkillDefinition.AoEShape.LINE \
				and shape != SkillDefinition.AoEShape.CONE:
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
		if _aim_blocked(tile, movement_class):
			continue
		# Whoever stands there is no cover to the rest of themselves - every
		# tile of somebody big can be seen past their own front.
		if has_line_of_sight(from, tile, movement_class, viewer_size, get_combatant_at(tile)):
			result.append(tile)
	return result


## Whether there's a clear straight path from `from` to `to` for
## `movement_class` - no blocking tile anywhere strictly between them
## (the endpoints themselves aren't checked here; see is_tile_blocking).
##
## `looking_at`, somebody standing at the far end, is no cover to themselves:
## their own body does not hide the rest of them (somebody bigger than a tile).
func has_line_of_sight(from: Vector2i, to: Vector2i, movement_class: int, viewer_size: int = Sizes.Size.HUMAN, looking_at: Dictionary = {}) -> bool:
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
	# From one floor to another, over its own rules; somebody raised at either end
	# - up on high ground, or bigger than a Human - over anything low (see
	# "Heights").
	if _floored and floor_of(from) != floor_of(to):
		return _sight_between_floors(from, to, viewer_size, looking_at)
	var raised: bool = viewer_size > Sizes.Size.HUMAN or controller.raised_at(from) > 0 or controller.raised_at(to) > 0
	# Raised under a floor above: the line may climb into it or come down through
	# it, and nothing goes through a floor - so the floors' rules, on one floor too.
	if raised and _floored and floor_beside(floor_of(from), 1) >= 0:
		return _sight_between_floors(from, to, viewer_size, looking_at)
	if movement_class != 1 and raised:
		movement_class = 1
	if to.x < from.x or (to.x == from.x and to.y < from.y):
		return _walk_is_clear(to, from, movement_class, viewer_size, looking_at)
	return _walk_is_clear(from, to, movement_class, viewer_size, looking_at)


## One direction of the walk. has_line_of_sight is the question to ask; this is
## half of its answer, and on its own it is the asymmetry rather than the rule.
## _SightGrid.clear walks the same line for the danger view - change one, change
## both (the danger suite checks they agree).
##
## Deliberately the same arithmetic, in the same order, so it cannot disagree
## with get_tiles_between about what lies between two tiles. The blindcast
## and stealth suites check the two against each other.
func _walk_is_clear(from: Vector2i, to: Vector2i, movement_class: int, viewer_size: int = Sizes.Size.HUMAN, looking_at: Dictionary = {}) -> bool:
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
		if controller.blocks_line_of_sight(between, movement_class, viewer_size, looking_at):
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
	# Inside somebody (Swallow), all there is to reach is them.
	if not caster.is_empty() and is_inside(caster):
		return tiles_of(swallower_of(caster))
	var tiles = []
	var reach = effective_max_range(caster, skill) if not caster.is_empty() else skill.max_range
	var viewer: int = caster.get("size", Sizes.Size.HUMAN)
	if not caster.is_empty():
		movement_class = terrain_class(caster)
	# Somebody bigger than a tile reaches from every edge of their square, and
	# looks from whichever of their tiles is nearest.
	if footprint(caster) != Vector2i.ONE:
		var rect := rect_of(caster)
		for y in range(rect.position.y - reach, rect.end.y + reach):
			for x in range(rect.position.x - reach, rect.end.x + reach):
				var tile := Vector2i(x, y)
				var distance := rect_gap(rect, Rect2i(tile, Vector2i.ONE))
				if distance < skill.min_range or distance > reach:
					continue
				if skill.respects_blocking and (_aim_blocked(tile, movement_class) \
						or not has_line_of_sight(nearest_tile_of(caster, tile), tile, movement_class, viewer, get_combatant_at(tile))):
					continue
				tiles.append(tile)
		return tiles
	for tile in get_diamond_tiles(caster_position, reach):
		if get_position_distance(caster_position, tile) >= skill.min_range and floor_of(tile) == floor_of(caster_position):
			tiles.append(tile)
	if skill.respects_blocking:
		tiles = filter_tiles_by_line_of_sight(tiles, caster_position, movement_class, viewer)
	# The other floors, as far as a storey's height leaves the reach to go - and
	# only through open air ("Heights").
	if _floored and floor_of(caster_position) >= 0 and aoe_shape_of(caster, skill) == SkillDefinition.AoEShape.DIAMOND:
		var here := floor_of(caster_position)
		var real := real_of(caster_position)
		for i in floors.size():
			var rise: int = absi(floors[i].level - floors[here].level)
			if i == here or rise > reach:
				continue
			for spot in get_diamond_tiles(real, reach - rise):
				var tile := tile_on(i, spot)
				if tile.x == -99999 or not controller.is_on_map(tile):
					continue
				if get_position_distance(caster_position, tile) < skill.min_range or not floors_open_between(caster_position, tile):
					continue
				if skill.respects_blocking and (_aim_blocked(tile, movement_class) \
						or not has_line_of_sight(caster_position, tile, movement_class, viewer, get_combatant_at(tile))):
					continue
				tiles.append(tile)
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
		# A thing on the map that is not there (Illusory Cover): it goes straight
		# through.
		if comb.has("object") and comb.get("illusion", false):
			continue
		# A skill that affects both sides catches everyone standing in it -
		# that's the whole point of aiming one carefully.
		if not affects_both_sides:
			var is_ally = comb.side == caster.side
			if is_ally != targets_ally:
				continue
		# Caught by any tile of theirs, for somebody bigger than one - once.
		if footprint(comb) == Vector2i.ONE:
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
	# Summoning and commanding are the skill's doing, not something done to
	# whoever stands there (use_skill, "Summons").
	if effect.type == EffectDefinition.EffectType.SUMMON or effect.type == EffectDefinition.EffectType.COMMAND \
			or effect.type == EffectDefinition.EffectType.LOOT or effect.type == EffectDefinition.EffectType.DRAW \
			or effect.type == EffectDefinition.EffectType.TRAP or effect.type == EffectDefinition.EffectType.ZONE:
		return
	# Everything of theirs lingering goes off at once (see "Catalyst").
	if effect.type == EffectDefinition.EffectType.CATALYST:
		catalyst(attacker, effect)
		return
	# Nothing from the other side takes hold of the untouchable (Illusory Dragon).
	if target.get("untouchable", false) and target.get("side", -1) != attacker.get("side", -2):
		update_information.emit("It passes through [color=red]%s[/color] as if nothing were there.\n" % target.name)
		float_number(target, "Untouched", Color("cfd8e3"))
		return
	# Invisible, anything done to the other side gives them away (see
	# "Invisibility"). Looking them over (Study) does nothing to anybody.
	if is_invisible(attacker) and target != attacker and target.side != attacker.side \
			and not target.has("object") and effect.type != EffectDefinition.EffectType.REVEAL:
		_invisibility_ends(attacker)
	# Not on the fallen being stood back up: a flinch on a body, and the rise
	# fighting the recoil for where it is drawn.
	if effect.type != EffectDefinition.EffectType.REVIVE and effect.type != EffectDefinition.EffectType.SUMMON_DECOY:
		flash_target(attacker, target, damage_colour, blast_origin)
	# Ending what spells did to somebody ("Dispelling") - its own way through.
	if effect.type == EffectDefinition.EffectType.DISPEL_MAGIC:
		dispel_magic(attacker, target, skill)
		return
	# What a spell leaves on them carries the gate it came through ("Dispelling").
	var spell_cast: bool = is_spell(skill) and target.has("status_effects")
	var had: Array = target.status_effects.duplicate() if spell_cast else []
	_apply_effect_by_type(attacker, target, effect, skill, mention_skill, power)
	if spell_cast:
		_mark_spell_gate(target, had, skill)
		if effect.type == EffectDefinition.EffectType.INVISIBLE and is_invisible(target):
			target["invisible_gate"] = spell_gate_of(skill)


func _apply_effect_by_type(attacker: Dictionary, target: Dictionary, effect: EffectDefinition, skill: SkillDefinition, mention_skill: bool, power: float):
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
				"duration" = stored_duration(target, effect) + _control_extra(attacker, effect),
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
				"duration" = stored_duration(target, effect) + _control_extra(attacker, effect),
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
				"dot_base" = dot_base_damage(attacker, skill, effect.damage_modifier) * lingering_bonus(attacker),
				"duration" = stored_duration(target, effect) + lingering_turns(attacker),
				"ends_at_start" = effect.wears_off_at_start,
				"source_name" = attacker.name,
				# What it sounds like when it ticks: the blow that left it.
				"sound" = skill.sound if skill != null else null,
				"sound_db" = skill.sound_volume_db if skill != null else 0.0,
			})
			update_information.emit(describe_condition(attacker, target, effect, skill, mention_skill, "a lingering wound"))
		EffectDefinition.EffectType.CONDITION:
			# A rank's stronger condition in place of the effect's, replacing the
			# weaker on them rather than stacking with it (SkillRank.condition).
			var ranked := ranked_condition_effect(attacker, skill, effect)
			if ranked != effect:
				replace_matching_tick(target, "condition", effect.condition, 0)
				effect = ranked
			if effect.condition == null:
				push_warning("A CONDITION effect on %s has no condition assigned." % (skill.name if skill != null else "an unnamed skill"))
			elif immune_to_condition(target, effect.condition):
				shrug_off(target, effect.condition.display_name.to_lower(), true)
			else:
				var movement_before = get_effective_stat(target, "movement")
				replace_matching_tick(target, "condition", effect.condition, 0)
				var lasts: int = condition_turns(target, effect, rank_duration(attacker, skill)) \
					+ (lingering_turns(attacker) if _lingers(effect.condition) else 0) + _control_extra(attacker, effect)
				target.status_effects.append({
					"stat" = "condition",
					"condition" = effect.condition,
					"dot_base" = dot_base_damage(attacker, skill, dot_strength_of(attacker, skill, effect)) * (lingering_bonus(attacker) if _lingers(effect.condition) else 1.0),
					"duration" = lasts,
					# What it started at - to start again from (Catalyst, Contagion).
					"full_duration" = lasts,
					"ends_at_start" = effect.condition.wears_off_at_start,
					"source_name" = attacker.name,
					"source_id" = attacker.get("id", -1),
					"sound" = skill.sound if skill != null else null,
					"sound_db" = skill.sound_volume_db if skill != null else 0.0,
				})
				_metric("condition", {"target": target, "condition": effect.condition, "by": attacker, "turns": lasts})
				if effect.condition.movement_change != 0:
					resync_live_movement(target, movement_before)
				# Grappled (Holding on): one held at a time, and a way out.
				if effect.condition.holds:
					_got_hold(attacker, target)
					# Held, a readied move they could no longer make is gone ("Ready").
					if _ready_impossible(target):
						drop_readied(target, "held fast, they could not make it")
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
		EffectDefinition.EffectType.INVISIBLE:
			make_invisible(target)
		EffectDefinition.EffectType.CANCEL_CASTING:
			cancel_casting(attacker, target)
		EffectDefinition.EffectType.SWALLOW:
			swallow(attacker, target, effect, skill)
		EffectDefinition.EffectType.GROW:
			grow(attacker, target, effect, skill, mention_skill)
		EffectDefinition.EffectType.HIDE:
			if alone_on_their_side(target):
				update_information.emit("[color=yellow]%s[/color] is the last one standing - there is nobody else to slip behind.
" % target.name)
			elif last_in_sight(target):
				update_information.emit("[color=yellow]%s[/color] is the last of their side in sight - there is nobody else to draw the eye.
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
			shake(attacker, target, rng.randi_range(effect.min_amount, maxi(effect.min_amount, effect.max_amount)))
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
		if sees_tile(watcher, nearest_tile_of(comb, watcher.position), comb):
			return true
	return false


## Whether `viewer` has a clear line to `tile`: from whichever of their tiles is
## nearest it, so somebody bigger than a tile looks out from every edge rather
## than past their own body from a corner. `looking_at`, whoever stands at
## `tile`, is no cover to the rest of themselves either.
func sees_tile(viewer: Dictionary, tile: Vector2i, looking_at: Dictionary = {}) -> bool:
	return has_line_of_sight(nearest_across(viewer, tile), tile, viewer.get("movement_class", 0), Sizes.Size.HUMAN, looking_at)


## Whether everybody else standing on `comb`'s side is out of sight already -
## or there is nobody else. Hiding is something you do while the enemy has
## somebody else to look at, and with nobody on a side left in sight the fight
## could go nowhere. An image of one of them is somebody to look at, while
## whoever made it stands (images_hold_the_eye) - so behind images the whole
## side can be out of sight. Any other illusion is nobody.
func last_in_sight(comb: Dictionary) -> bool:
	for index in groups[comb.side]:
		var other = combatants[index]
		if other == comb or not other.alive or is_hidden(other):
			continue
		if other.get("illusion", false) and not _image_holds_the_eye(other):
			continue
		return false
	return true


## --- Images, and hiding ---
##
## An image of somebody (summon_decoy - Mirror Image, Reality's Reflection) is
## somebody for the other side to look at, so while one of a side's stands, all
## of the real ones can be hidden or invisible (last_in_sight). It only holds the
## eye while whoever made it (`made_by`) stands:
## - the last image gone with all of them out of sight gives away whoever made
##   it, and the rest stay hidden behind them (_after_image_gone, from _shatter);
## - whoever made them falling while everybody else is out of sight gives
##   everybody away: their images stop holding the eye, and combatant_die's
##   reveal_anyone_now_seen applies the side rule.


## Whether `image` is an image of somebody, made by somebody still standing.
func _image_holds_the_eye(image: Dictionary) -> bool:
	if not image.has("image_of"):
		return false
	var maker := _combatant_by_id(image.get("made_by", -1))
	return not maker.is_empty() and maker.get("alive", false)


## Whether nobody real of `side` is left in sight - every one of them hidden.
func _side_out_of_sight(side: int) -> bool:
	for index in groups[side]:
		var other = combatants[index]
		if other.alive and not other.get("illusion", false) and not is_hidden(other):
			return false
	return true


## `image` is gone. The last of its side's gone, with all of them out of sight:
## whoever made it is given away - or, with them gone too, everybody.
func _after_image_gone(image: Dictionary):
	var side: int = image.get("side", 0)
	for index in groups[side]:
		if combatants[index].alive and _image_holds_the_eye(combatants[index]):
			return
	if not _side_out_of_sight(side):
		return
	var maker := _combatant_by_id(image.get("made_by", -1))
	if not maker.is_empty() and maker.get("alive", false) and is_hidden(maker):
		set_hidden(maker, false)
		maker["shown_this_turn"] = true
		update_information.emit("[color=yellow]%s[/color]'s last image is gone, and %s is in plain sight again.\n" % [maker.name, maker.name])
	else:
		reveal_anyone_now_seen()


## Hides or reveals `comb`, and dresses them for it. Revealed, they are not
## invisible either.
func set_hidden(comb: Dictionary, hidden: bool):
	if not hidden:
		comb.erase("invisible")
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
			# Seen, until their next turn - a zone that hides them waits for it.
			comb["shown_this_turn"] = true
			revealed.append(comb)
			update_information.emit("[color=yellow]%s[/color] is the last one standing, and can hide no longer.
" % comb.name)
			continue
		if last_in_sight(comb):
			# Nobody on their side left in sight - everybody else hidden or
			# invisible too - and the same goes for all of them at once.
			for index in groups[comb.side]:
				var other = combatants[index]
				if other.alive and other.get("hidden", false):
					set_hidden(other, false)
					other["shown_this_turn"] = true
					revealed.append(other)
					update_information.emit("[color=yellow]%s[/color] can hide no longer - nobody on their side is left in sight.
" % other.name)
			continue
		# Invisible, being looked at finds nothing (see "Invisibility").
		if is_invisible(comb):
			continue
		if is_seen_by_opponents(comb):
			set_hidden(comb, false)
			revealed.append(comb)
			update_information.emit("[color=yellow]%s[/color] is spotted!
" % comb.name)
	return revealed


## --- Invisibility ---
##
## Hidden, but not by cover: `comb.invisible` on top of `comb.hidden`, so
## everything that leaves somebody hidden alone leaves them alone too. What is
## different is what ends it. Sight does not (reveal_anyone_now_seen passes
## them by), being caught in a blast does not (do_damage), and it can be cast
## on somebody being watched, an ally as well as yourself. Doing anything to
## the other side does (apply_effect), and so does nobody on their side being
## left in sight, as for hiding.

func is_invisible(comb: Dictionary) -> bool:
	return comb.get("invisible", false)


## Those whose spawn starts them invisible (SpawnDefinition.invisible), held
## until everybody is on the board - whether somebody can be depends on who
## else is in sight.
var _invisible_from_the_start: Array = []


## Makes them so: in reverse, so with a whole side asking, the first of them -
## whoever led, on a stealth map - is the one left in sight.
func _begin_invisible():
	var asking := _invisible_from_the_start.duplicate()
	_invisible_from_the_start.clear()
	asking.reverse()
	for comb in asking:
		if comb.alive:
			make_invisible(comb)


## Why `skill` can't make whoever stands on `impact` invisible, or "" when it
## can, or it does not try to.
func _invisibility_refusal(skill: SkillDefinition, target: Dictionary) -> String:
	if target.is_empty() or not skill.all_effects().any(func(effect): return effect != null and effect.type == EffectDefinition.EffectType.INVISIBLE):
		return ""
	if is_invisible(target):
		return "%s is invisible already" % target.name
	if not is_hidden(target) and last_in_sight(target):
		return "%s is the last of their side in sight - there is nobody else to draw the eye" % target.name
	return ""


func make_invisible(comb: Dictionary):
	if is_invisible(comb):
		return
	if not is_hidden(comb) and last_in_sight(comb):
		update_information.emit("[color=yellow]%s[/color] is the last of their side in sight - there is nobody else to draw the eye.\n" % comb.name)
		return
	comb["invisible"] = true
	if is_hidden(comb):
		update_combatants.emit(combatants)
	else:
		set_hidden(comb, true)
	update_information.emit("[color=yellow]%s[/color] fades from sight.\n" % comb.name)


## They did something to the other side, and can be seen again.
func _invisibility_ends(comb: Dictionary):
	set_hidden(comb, false)
	# Given away for the rest of this turn, even in a zone that hides them.
	comb["shown_this_turn"] = true
	update_information.emit("[color=yellow]%s[/color] acts against the enemy, and flickers back into sight.\n" % comb.name)


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
	# Nothing roots the Unstoppable.
	if restriction == "prevents_movement" and unstoppable(comb):
		return false
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
## each. One landing on whoever is acting right now has the rest of this turn as
## well, on top.
## `source` is whatever carries the duration - an EffectDefinition, or a
## ConditionDefinition, which keeps its own.
func stored_duration(target: Dictionary, source) -> int:
	return turns_stored(source.duration, source.wears_off_at_start, on_whoever_acts(target))


## Whether it is `comb`'s turn right now - what lands on them then has the rest
## of it on top of its turns (turns_stored).
func on_whoever_acts(comb: Dictionary) -> bool:
	return not comb.is_empty() and current_combatant >= 0 and current_combatant < combatants.size() \
		and comb == combatants[current_combatant]


## The turns an effect written as lasting `duration` is stored with - which is
## how many of its bearer's turns it is on them for. Written "N turns", it is
## on them for N of their own turns (the user's rule, 2026-10-24): Blind 3 on an
## enemy is three blind turns of theirs, Stunned 2 two lost, a Burn of 3 three
## ticks.
##
## `at_start` picks which end of a turn it goes at. Going as it starts, it hangs
## on through everybody else's turns after its last and is gone the moment
## before its bearer could use it - right for Guard, which is for the enemies'
## turns. Going as it ends, it holds through the last of its turns, so whatever
## is on somebody is still on them while that turn is played.
##
## `lands_on_actor`: it lands on the one whose turn it is (a Run, a buff cast on
## oneself, a trap stepped on). Going at the end, they have the rest of this turn
## on top of their N - Run 1 is this turn and the next - so a buff cast as the
## last thing in a turn is not spent on nothing.
##
## An effect going at the start is stored with its duration and left on at
## nothing until its bearer's next turn begins (end_of_turn_effects keeps it,
## start_of_turn_effects clears it). One going at the end comes off as the last
## of its turns ends.
##
## Everything that tells the player how long something lasts asks here, so the
## numbers they read are the turns they get.
static func turns_stored(duration: int, at_start: bool, lands_on_actor: bool = false) -> int:
	return duration + 1 if lands_on_actor and not at_start else duration


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
func condition_turns(target: Dictionary, effect: EffectDefinition, ranked: int = 0) -> int:
	var turns: int = ranked if ranked > 0 else (effect.condition_duration if effect.condition_duration > 0 else effect.condition.duration)
	return turns_stored(turns, effect.condition.wears_off_at_start, on_whoever_acts(target))


## --- Ranks ---
##
## A skill grown stronger with its user's level (SkillDefinition.ranks,
## SkillRank): from each rank's level, the figures it sets stand in for the
## skill's - each later rank over the one before, a 0 keeping what was.

## `skill`'s ranks `comb` has reached, lowest first.
static func ranks_reached(comb: Dictionary, skill: SkillDefinition) -> Array:
	if skill == null or skill.ranks.is_empty():
		return []
	var level: int = comb.get("level", 1)
	var reached: Array = skill.ranks.filter(func(rank): return rank != null and rank.level <= level)
	reached.sort_custom(func(a, b): return a.level < b.level)
	return reached


## `skill`'s Ability Modifier in `comb`'s hands.
static func modifier_of(comb: Dictionary, skill: SkillDefinition) -> float:
	var value: float = skill.ability_modifier
	for rank in ranks_reached(comb, skill):
		if rank.ability_modifier > 0.0:
			value = rank.ability_modifier
	return value


## How hard the condition `effect` puts on burns, from `skill` in `comb`'s hands.
static func dot_strength_of(comb: Dictionary, skill: SkillDefinition, effect: EffectDefinition) -> float:
	var value: float = effect.condition_dot_strength()
	for rank in ranks_reached(comb, skill):
		if rank.condition_dot_modifier > 0.0:
			value = rank.condition_dot_modifier
	return value


## `effect` as `skill` in `comb`'s hands puts it on: with a rank's condition in
## place of its own (SkillRank.condition), or `effect` itself.
static func ranked_condition_effect(comb: Dictionary, skill: SkillDefinition, effect: EffectDefinition) -> EffectDefinition:
	var condition: ConditionDefinition = null
	for rank in ranks_reached(comb, skill):
		if rank.condition != null:
			condition = rank.condition
	if condition == null or effect == null or effect.condition == condition:
		return effect
	var ranked: EffectDefinition = effect.duplicate()
	ranked.condition = condition
	return ranked


## The share of its user's health `effect` mends, from `skill` in `comb`'s hands
## (SkillRank.heal_share_of_health).
static func heal_share_of(comb: Dictionary, skill: SkillDefinition, effect: EffectDefinition) -> float:
	var value: float = effect.heal_share_of_health if effect != null else 0.0
	for rank in ranks_reached(comb, skill):
		if rank.heal_share_of_health > 0.0:
			value = rank.heal_share_of_health
	return value


## How long `skill`'s conditions last in `comb`'s hands, if a rank says - 0 for
## what the effect says.
static func rank_duration(comb: Dictionary, skill: SkillDefinition) -> int:
	var value := 0
	for rank in ranks_reached(comb, skill):
		if rank.condition_duration > 0:
			value = rank.condition_duration
	return value


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
	var keeps_boons := immune_to(target, Immunity.Kind.BUFFS_REMOVED)
	if keeps_boons and effect.dispel_scope == EffectDefinition.DispelScope.BUFFS_ONLY:
		shrug_off(target, Immunity.name_of(Immunity.Kind.BUFFS_REMOVED))
		return
	var was_held := has_restriction(target, "prevents_movement")
	var movement_before: int = get_effective_stat(target, "movement") if target.has("movement") else 0
	# What the player chose to lift first (_choose_lifts)...
	for entry in _lift_picks.duplicate():
		if effect.dispel_count > 0 and removed >= effect.dispel_count:
			break
		var at := _effect_index(target, entry)
		if at >= 0 and should_dispel(entry, effect, keeps_boons):
			target.status_effects.remove_at(at)
			_lift_picks.erase(entry)
			removed += 1
	# ...then from the end, so the most recently acquired goes first. That only
	# shows when dispel_count limits how many come off - a remedy that lifts one
	# thing should lift the thing that just happened.
	var i = target.status_effects.size() - 1
	while i >= 0:
		if effect.dispel_count > 0 and removed >= effect.dispel_count:
			break
		if should_dispel(target.status_effects[i], effect, keeps_boons):
			target.status_effects.remove_at(i)
			removed += 1
		i -= 1
	# One of the things lifted may have been what was keeping them off the floor,
	# or a Growth - or, in their own turn, what held them where they stood.
	resync_movement_class(target)
	resync_size(target)
	if removed > 0 and target.has("movement"):
		_movement_after_lift(target, was_held, movement_before)
	if removed > 0:
		# Same reason as applying one: the icon has to leave the portrait as
		# the cleanse lands, not when the turn happens to end.
		update_combatants.emit(combatants)
		update_information.emit("[color=yellow]{0}[/color] cleansed {1} effect(s) from [color=lightgreen]{2}[/color]\n".format([
			attacker.name,
			removed,
			target.name
		]))


## --- Cleansing: choosing what comes off ---
##
## A cleanse that lifts only so much (Dispel Count) and a heal that lifts some
## harmful conditions too (Heals Lift - Mercy II) take what the player chooses
## when there is more on them than comes off: asked once per thing lifted,
## before the skill lands on them, as a Steal's container is (_choose_lifts in
## use_skill). Anybody else lifts the most recent first.

## What the player chose to lift from whoever is being landed on now, in order.
var _lift_picks: Array = []


## Asks the player which of `target`'s entries `skill` lifts, when it cannot
## lift them all. Empty: nothing to ask, or nobody to ask it of.
func _choose_lifts(attacker: Dictionary, target: Dictionary, skill: SkillDefinition) -> Array:
	if skill == null or not plays_for_party(attacker) or reaction_prompt == null or not reaction_prompt.has_method("pick") \
			or not target.has("status_effects"):
		return []
	var limit := 0
	var candidates := []
	for effect in skill.all_effects():
		if effect != null and effect.type == EffectDefinition.EffectType.DISPEL and effect.dispel_count > 0:
			var keeps_boons := immune_to(target, Immunity.Kind.BUFFS_REMOVED)
			limit = effect.dispel_count
			candidates = target.status_effects.filter(func(entry): return should_dispel(entry, effect, keeps_boons))
			break
	if limit == 0 and heal_effect_of(skill) != null and target.get("side", -1) == attacker.get("side", -2):
		for passive in active_passives(attacker):
			limit += passive.heals_lift
		candidates = target.status_effects.filter(func(entry): return _harmful(entry))
	if limit <= 0 or candidates.size() <= limit:
		return []
	# The most recent first, as anybody else would lift them.
	candidates.reverse()
	var picks := []
	while picks.size() < limit and not candidates.is_empty():
		var picked: int = await reaction_prompt.pick("%s: %s" % [attacker.name, skill.name],
			"Which of what is on %s comes off?%s" % [target.name, (" (%d of %d)" % [picks.size() + 1, limit]) if limit > 1 else ""],
			candidates.map(func(entry): return lift_label(entry)))
		if not still_running():
			return []
		var at := clampi(picked, 0, candidates.size() - 1)
		picks.append(candidates[at])
		candidates.remove_at(at)
	return picks


## What a status entry is called, lifting it: its condition, a lingering wound,
## or the figure it changes.
static func lifted_name(entry: Dictionary) -> String:
	var condition = entry.get("condition")
	if condition != null:
		return condition.display_name
	match entry.get("stat", ""):
		"dot":
			return "a lingering wound"
	var amount = entry.get("amount", 0)
	if entry.get("op", "add") == "multiply":
		return "%s x%s" % [entry.get("stat", "?"), snappedf(float(amount), 0.01)]
	return "%s %+d" % [entry.get("stat", "?"), int(amount)]


## The same, with how long it has left - a button's label.
static func lift_label(entry: Dictionary) -> String:
	var turns: int = entry.get("duration", 0)
	if turns <= 0 or turns >= 99:
		return lifted_name(entry)
	return "%s (%d turn%s left)" % [lifted_name(entry), turns, "" if turns == 1 else "s"]


## After something came off `comb`: in their own turn, what they have left to
## walk made to fit. Let go of what held them where they stood (Crystallised,
## a root), it is their movement less what they walked this turn before it took
## hold; anything else changing their movement, it follows the change
## (resync_live_movement).
func _movement_after_lift(comb: Dictionary, was_held: bool, movement_before: int):
	if comb != get_current_combatant() or controller == null:
		return
	if was_held and not has_restriction(comb, "prevents_movement"):
		controller.movement = maxi(get_effective_stat(comb, "movement") - int(comb.get("walked_this_turn", 0)), 0)
	else:
		resync_live_movement(comb, movement_before)


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
	return Rect2i(at, footprint(comb))


## How many tiles across and down `comb` covers: their square - or, folded to
## fit somewhere (Combat "Squeezing"), the shape they are folded to.
static func footprint(comb: Dictionary) -> Vector2i:
	if comb.has("fold"):
		return comb.fold
	var span: int = comb.get("span", 1)
	return Vector2i(span, span)


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
	if footprint(comb) == Vector2i.ONE:
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


## The tile of `comb`'s square, were they anchored at `anchor`, nearest `tile` -
## where a line or a cone of theirs goes out from (get_impact_tiles), for the AI
## weighing where it could stand. Their anchor, for anybody a tile big.
static func nearest_from(comb: Dictionary, anchor: Vector2i, tile: Vector2i) -> Vector2i:
	var shape := footprint(comb)
	return Vector2i(clampi(tile.x, anchor.x, anchor.x + shape.x - 1), clampi(tile.y, anchor.y, anchor.y + shape.y - 1))


## The movement class whose ground `comb` answers to - what stops them, and what
## stops their sight. Their own, save for anything Monstrous or bigger: too big
## for a map's walls to matter, it goes and sees wherever a flier could - only
## what stops a flier stops it. It still cannot walk through anybody.
static func terrain_class(comb: Dictionary) -> int:
	if comb.get("size", Sizes.Size.HUMAN) >= Sizes.Size.MONSTROUS:
		return 1
	# Up on high ground ("Heights"): standing on what stops a walker, seeing over
	# what does not stop a flier.
	if comb.get("up", false):
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
	var here: int = floor_of(anchor) if _floored else -1
	for tile in tiles_of(comb, anchor):
		if ground and (not controller.is_in_bounds(tile) or blocks_for(comb, tile)):
			return false
		# A square on one floor, not straddling the gap to the next.
		if ground and here >= 0 and floor_of(tile) != here:
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


## How big `comb`'s sprite is drawn (Sizes.draw_scale) - squashed, folded to fit
## somewhere (Squeezing), to the shape it is folded to.
func drawn_scale(comb: Dictionary) -> Vector2:
	var span: int = comb.get("span", 1)
	var scale := Vector2.ONE * Sizes.draw_scale(comb.get("size", Sizes.Size.HUMAN), span)
	return scale * Vector2(footprint(comb)) / float(span)


## How far `comb`'s drawing sits off their node, on the map: to the middle of
## the square somebody bigger covers, or - for something smaller than a tile -
## to its own place in the tile it shares, by how many as small of its side are
## there before it.
func drawing_offset(comb: Dictionary) -> Vector2:
	var size: int = comb.get("size", Sizes.Size.HUMAN)
	if not Sizes.shares(size):
		return Vector2(footprint(comb) - Vector2i.ONE) * Vector2(Grid.TILE_SIZE, Grid.TILE_SIZE) * 0.5
	# Gathered round the middle of the tile, however many share it: one alone in
	# the middle, two side by side, three in a triangle, four in a square, and
	# more in rows each centred under the last. Spaced as wide as the biggest of
	# them is - half a tile with a Small one there - closer if that will not fit.
	var sharing := []
	var widest := 0.25
	var here = comb.get("position")
	for other in combatants:
		if here != null and other.alive and other.position == here and Sizes.shares(other.get("size", Sizes.Size.HUMAN)) \
				and not other.has("riding"):
			sharing.append(other)
			if other.get("size", Sizes.Size.HUMAN) == Sizes.Size.SMALL:
				widest = 0.5
	var count := maxi(sharing.size(), 1)
	var index := maxi(sharing.find(comb), 0)
	var across := ceili(sqrt(float(count)))
	var rows := ceili(float(count) / across)
	var cell := minf(widest, 1.0 / maxi(across, rows))
	var row := index / across
	var in_row := across if row < rows - 1 else count - across * (rows - 1)
	var at := Vector2((index % across) - (in_row - 1) * 0.5, row - (rows - 1) * 0.5) * cell
	if count > 1:
		# Not quite in ranks: each nudged a little, the same way every time.
		var nudge: int = (int(comb.get("id", index)) * 37 + 11) % 7
		at += Vector2(nudge % 3 - 1, nudge / 3 - 1) * cell * 0.08
	return at * float(Grid.TILE_SIZE)


## Puts every drawing of somebody bigger or smaller than a tile where
## drawing_offset says - after anybody arrives, leaves or moves.
func place_sprites():
	_carry_riders()
	for comb in combatants:
		var sprite = comb.get("sprite")
		if not comb.alive or sprite == null or not is_instance_valid(sprite):
			continue
		if footprint(comb) != Vector2i.ONE or Sizes.shares(comb.get("size", Sizes.Size.HUMAN)):
			sprite.set_size_offset(drawing_offset(comb))
		elif sprite.size_offset != Vector2.ZERO:
			# A tile big again, having been bigger or smaller (Growing): back
			# over their own tile.
			sprite.set_size_offset(Vector2.ZERO)


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
	# Up on somebody (Climb), a melee blow at what you are riding shoves it, or
	# drags it, nowhere.
	if is_melee(skill) and attacker.get("riding", -1) == target.get("id", -2):
		update_information.emit("[color=yellow]%s[/color] cannot shift [color=red]%s[/color] from on top of it.\n" % [attacker.name, target.name])
		return
	if target.position == attacker.position:
		return
	if immune_to(target, Immunity.Kind.SHOVED):
		shrug_off(target, Immunity.name_of(Immunity.Kind.SHOVED))
		return
	# Somebody of theirs holding the line around them (Hold the Line).
	if target.get("side", -1) != attacker.get("side", -2) and _line_held(target):
		update_information.emit("[color=yellow]%s[/color] holds the line, and does not give ground.\n" % target.name)
		float_number(target, "Held", Color("cfd8e3"))
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
	var max_steps = effect.knockback_distance + (0 if pulling else push_extra_of(attacker))
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
		if footprint(target) != Vector2i.ONE or Sizes.shares(target.get("size", Sizes.Size.HUMAN)):
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
	# Shoved into something solid by somebody whose shoves daze (Tremor).
	if not pulling and (hit_obstacle or not bumped.is_empty()):
		_tremor_impact(attacker, target)
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
		return rng.randi_range(effect.min_amount, effect.max_amount)
	return maxi(roundi(float(base_skill_damage(attacker, skill)) * effect.damage_modifier), 0)


## Applies one collision's worth of damage to `who`, resisted by them, and
## reports it. Shared by the wall case and both halves of a body-to-body one so
## the three cannot drift apart.
func _take_collision_damage(shover: Dictionary, who: Dictionary, effect: EffectDefinition, impact: int, what_happened: String):
	var shove_element = effective_damage_type(shover, effect.damage_type)
	var collision_damage = resisted_damage(who, shove_element,
		Stats.final_damage(float(impact), 1.0, stat_of(who, Stats.Type.DEFENSE)))
	lose_hp(who, collision_damage, shove_element, shover)
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
##
## `paced` (a real turn opening, from advance_turn): each tick lands on its own,
## as the hit it is - the view on them, the sound of whatever left it, the
## number, the flash, the screen's edges for one of the party - with a beat
## after each (TICK_BEAT), and only then is the turn theirs.
func start_of_turn_effects(comb: Dictionary, paced: bool = false):
	# Gone through as they stood, newest first, each checked still there: a tick
	# can change the list under it - a boss's phase shedding its conditions
	# (BossPhase.clears_conditions), a death letting go of a hold.
	var effects: Array = comb.status_effects.duplicate()
	effects.reverse()
	var watched := false
	for eff in effects:
		var at := _effect_index(comb, eff)
		if at == -1:
			continue
		if eff.duration <= 0:
			comb.status_effects.remove_at(at)
			continue
		var wound: bool = eff.stat == "dot"
		var burning: bool = eff.get("stat", "") == "condition" and eff.condition != null \
			and (eff.condition.dot_max > 0 or eff.condition.dot_modifier > 0.0)
		if not (wound or burning) or not comb.alive:
			continue
		if paced and not watched:
			watched = true
			_pace_turn(comb)
			watch_combatant(comb)
			# Nobody's to act while it lands - not the one whose turn just ended.
			if controller != null:
				controller.player_turn = false
				controller.action_locked = true
			if game_ui != null:
				game_ui.lock_action_buttons()
		if paced:
			play_stream(eff.get("sound"), eff.get("sound_db", 0.0))
		if wound:
			tick_damage_over_time(comb, eff)
		else:
			tick_condition_damage(comb, eff.condition, eff.get("dot_base", 0.0), 1.0, _combatant_by_id(eff.get("source_id", -1)))
		if paced:
			await get_tree().create_timer(TICK_BEAT).timeout
			if not still_running():
				return
	if watched:
		stop_watching()
		if controller != null:
			controller.action_locked = false
	resync_movement_class(comb)
	resync_size(comb)
	clamp_hp_to_max(comb)


## The beat after each lingering tick as a turn opens (start_of_turn_effects),
## before the next lands or the turn begins.
const TICK_BEAT := 0.5


## Where `eff` itself - not merely one just like it - is in `comb`'s effects,
## or -1 once it is gone.
func _effect_index(comb: Dictionary, eff: Dictionary) -> int:
	for i in comb.status_effects.size():
		if is_same(comb.status_effects[i], eff):
			return i
	return -1


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
	# Before the turns come off, so Exposed lasts until their next one begins.
	_expose_at_turn_end(comb)
	var i = comb.status_effects.size() - 1
	while i >= 0:
		var eff = comb.status_effects[i]
		eff.duration -= 1
		if eff.duration <= 0 and not eff.get("ends_at_start", false):
			comb.status_effects.remove_at(i)
		i -= 1
	# Anything that just expired may have been holding them in the air - or
	# making them bigger.
	resync_movement_class(comb)
	resync_size(comb)
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
	return rng.randi_range(flat_min, flat_max)


## `times` ticks' worth at once, for everything left going off together (Catalyst).
func tick_condition_damage(comb: Dictionary, condition: ConditionDefinition, dot_base: float = 0.0, times: float = 1.0, by: Dictionary = {}):
	if not comb.alive:
		return
	var resistance = resistance_of(comb, condition.dot_type)
	var amount = resisted_damage(comb, condition.dot_type, roundi(dot_tick(comb, dot_base, condition.dot_min, condition.dot_max) * times))
	lose_hp(comb, amount, condition.dot_type, by, condition.display_name)
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
	lose_hp(comb, amount, type, _combatant_by_id(eff.get("source_id", -1)), "a lingering wound")
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
	if stat == "movement" and unstoppable(comb):
		# Nothing lowers it or stops it (Unstoppable): never under their own.
		return maxi(fold_stat_changes(comb, stat, comb.get(stat, 0)), comb.get(stat, 0) + passive_stat_bonus(comb, stat))
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
			elif stat == "defense" and condition.defense_change != 0.0 \
					and not (condition.defense_change < 0.0 and immune_to(comb, Immunity.Kind.WEAKENED)):
				multiplier *= 1.0 + condition.defense_change
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
		_metric("round", {"round": round_number})
		# A zone whose caster is down counts its turns by the round ("Zones").
		_zones_round_begins()
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
## An enemy spawn that arrives late (SpawnDefinition.arrives_late) is held back
## until what it waits for has all happened - its round, so many of its side
## fallen, a cue (cue) - then put on its tile, or the nearest free one, and into
## the turn order: at the top of its round, or at the end of the turn that
## brought it, slotted in where it belongs (add_mid_round).

## Which round the fight is in: 1 until everybody has had a turn.
var round_number := 1
## Spawns still to come, in the order the encounter lists them.
var _arriving: Array = []
## Every cue that has happened this fight (cue), by name.
var _cues := {}


## Something has happened that a late arrival may wait on (arrives_on_cue):
## "phase:Gorge", "broke:Jaws", "swallowed" and so on - SpawnDefinition says.
func cue(what: String):
	_cues[what] = true
	_metric("cue", {"what": what})


## How many of `side` are out of the fight - fallen, fled or given up. Things
## on the map and images are nobody.
func fallen_of(side: int) -> int:
	return combatants.filter(func(comb): return comb.get("side", -1) == side and not comb.alive \
		and not comb.has("object") and not comb.get("illusion", false)).size()


## Whether everything `spawn` waits on has happened.
func _arrival_due(spawn: SpawnDefinition) -> bool:
	return spawn.arrives_on_round <= round_number \
		and fallen_of(Group.ENEMIES) >= spawn.arrives_after_deaths \
		and (spawn.arrives_on_cue == "" or _cues.has(spawn.arrives_on_cue))


## Whoever is due, brought in - at the top of a round, or `mid_round` at the end
## of the turn that brought them.
func _bring_in_arrivals(mid_round: bool = false):
	var still_coming: Array = []
	var came := false
	for spawn in _arriving:
		if not _arrival_due(spawn):
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
		if mid_round:
			add_mid_round(arrival, 1, tile)
		else:
			add_combatant(arrival, 1, tile)
		var joined: Dictionary = combatants.back()
		update_information.emit("[color=red]%s[/color] joins the fight.\n" % joined.name)
		if spawn.invisible:
			make_invisible(joined)
		# And whatever they bring with them ("Summons").
		_bring_own_summon(joined)
		# A boss arriving late is announced as it comes.
		_announce_boss(joined)
		if joined.has("object"):
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
##
## What happens as turns change goes by what is there, whatever the AI whose
## turn it was took it for (ai_believes is off while it runs).
func advance_turn():
	var believed := ai_believes
	ai_believes = false
	await _advance_turn()
	ai_believes = believed


func _advance_turn():
	# The fight may have been walked out of while somebody was mid-move. The
	# enemy's turn is a coroutine several awaits deep, and the scene it stands
	# on is freed the moment the title screen is asked for - but ai_move returns
	# cleanly rather than vanishing, so the chain unwinds back to here and asks
	# a Combat that is no longer in the tree for a timer. There is no turn to
	# advance once the battle is gone.
	if not still_running():
		return
	# A summon's moment of its summoner's turn over (Command): back to them.
	if not _commanding.is_empty() and combatants[current_combatant] == _commanding.summon:
		_end_command()
		return
	var ending: Dictionary = combatants[current_combatant]
	ending.turn_taken = true
	# An AI turn ending with its main action unused: something to ready, perhaps
	# ("Readying, for the AI").
	if ending.has("ai_turn_live"):
		ending.erase("ai_turn_live")
		# Still their mind being made up (ai_believes).
		ai_believes = true
		_believer_side = ending.get("side", Group.ENEMIES)
		_ai_consider_ready(ending)
		ai_believes = false
	if ending.alive:
		end_of_turn_effects(ending)
		_turncoat_turn_ends(ending)
		# Their summons not commanded stand on guard (see "Summons").
		_summons_turn_ends(ending)
		if not still_running() or combat_over:
			return
	# Whoever was waiting on what this turn brought about - so many fallen, a
	# cue - comes in now, into this round ("Arriving late").
	_bring_in_arrivals(true)
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
		# An image (the Illusionist's) takes no turns: it only stands there. Nor
		# does a summon, which acts on its summoner's (see "Summons").
		if not comb.alive or comb.get("illusion", false) or comb.has("summoner"):
			set_next_combatant()
			comb = combatants[current_combatant]
			continue
		comb.skill_used_this_turn = false
		comb.secondary_used_this_turn = false
		comb.reaction_used = false
		comb.reactions_suppressed = false
		comb.erase("movement_left_when_grabbed")
		# Not walked yet this turn (Momentum), and whether they start it in cover
		# (Cat Burglar I) - "Progression".
		comb.erase("moved_this_turn")
		comb.erase("struck_this_turn")
		comb["started_in_cover"] = in_cover(comb)
		_mend_at_turn_start(comb)
		# What the paths count per turn and per round, Contagion, and what
		# only lasts so long ("The paths").
		_paths_at_turn_start(comb)
		# What they readied and never needed passes with the moment ("Ready") -
		# said for the party's, and not for an enemy's, which would only fill the
		# log turn after turn with a guard standing ready again.
		drop_readied(comb, "the moment passed", comb.side != 0)
		# A changed future (Intuition) holds until their next turn begins.
		if comb.has("thwarted"):
			comb.erase("thwarted")
			update_combatants.emit(combatants)
		# Whatever is still burning them lands first, one tick at a time.
		await start_of_turn_effects(comb, true)
		if not still_running() or combat_over:
			return
		# A turn of theirs begun (for what the other side has declared), an aura
		# they are standing in, the ground they are standing on.
		_turn_begins_for(comb)
		# Their summons' turn begins with theirs, and their tether wears on.
		await _summons_turn_begins(comb)
		_tether_turn(comb)
		if not still_running() or combat_over:
			return
		# Whoever is inside them digested a turn more, their parts a turn nearer
		# grown back, and - free - a meal ("Swallowing", "Gluttony").
		_glutton_turn_begins(comb)
		if not still_running() or combat_over:
			return
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
			_metric("turn", {"who": comb, "outcome": "lost", "why": _why_turn_lost(comb)})
			# Whatever they declared went with the turn.
			drop_declared(comb, _why_turn_lost(comb))
			comb.erase("intent")
			# Their summons fend for themselves (see "Summons").
			await _summons_fend(comb)
			if not still_running() or combat_over:
				return
			end_of_turn_effects(comb)
			_summons_turn_ends(comb)
			set_next_combatant()
			comb = combatants[current_combatant]
			continue
		break
	_pace_turn(comb)
	apply_drift(comb)
	_metric("turn", {"who": comb, "why": "",
		"outcome": "confused" if has_restriction(comb, "confuses") else ("deceived" if has_restriction(comb, "turns_on_own_side") else "taken")})
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
		# Theirs not to give, their summons fend for themselves (see "Summons").
		await _summons_fend(comb)
		if not still_running() or not comb.alive:
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
		await _summons_fend(comb)
		if not still_running() or not comb.alive:
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
	_shuffle(options)
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
	# Whatever comes after is everybody's again (Coop).
	Coop.fight_turn(Coop.ANYONE)
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
	var after := Damage.after_resistance(amount, resistance_of(target, type))
	# Less of the element they last used themselves (Elemental Armour).
	if after > 0 and target.get("last_element", -1) == type and target.has("passives"):
		for passive in active_passives(target):
			if passive.elemental_armour > 0.0:
				return roundi(after * (1.0 - passive.elemental_armour))
	return after


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
	play_stream(skill.sound, skill.sound_volume_db)


## Plays `stream` on the next free voice - a skill's sound, or anything else a
## fight makes a noise about.
func play_stream(stream: AudioStream, volume_db: float = 0.0):
	if stream == null:
		return
	if _sound_players.is_empty():
		_build_sound_players()
	var player = _sound_players[_next_voice]
	_next_voice = (_next_voice + 1) % _sound_players.size()
	player.stream = stream
	player.volume_db = volume_db
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
	# Away from the blow, measured to the part of them it struck - not the
	# corner of somebody bigger than a tile.
	var struck: Vector2i = nearest_tile_of(target, origin)
	if origin != struck:
		sprite.recoil(Vector2(struck - origin))


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
	# Over the middle of them, too: somebody bigger than a tile is drawn in the
	# middle of their square, away from the corner their node stands on.
	var above = Vector2(0.0, -sprite.head_height())
	FloatingNumber.spawn(sprite.get_parent(), sprite.position + drawing_offset(target) + above, text, colour)


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
	# Made of somebody's mind (a summon With Summoners Attributes - the
	# Illusory Dragon): theirs, as they are now, while they stand.
	if comb.has("attributes_of"):
		for mind in combatants:
			if mind.get("id", -1) == comb.attributes_of and mind.get("alive", false) and mind != comb:
				return stat_of(mind, type)
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
	return stat_of(target, skill.contest_stat) < stat_of(attacker, scaling_stat_of(attacker, skill)) + contest_bonus_of(attacker, target)


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
		modifier_of(attacker, skill) * power * damage_dealt_multiplier(attacker, target, skill),
		0 if _pierces_read(attacker, target, skill) else defense_against(target, skill))


## Whether `attacker`'s `skill` goes through all of `target`'s defence: one of
## theirs that does on anybody they have read (Final Judgment).
func _pierces_read(attacker: Dictionary, target: Dictionary, skill: SkillDefinition) -> bool:
	if skill == null or not attacker.has("passives") or not has_read(attacker, target):
		return false
	var key := skill_key_of(skill)
	return active_passives(attacker).any(func(passive): return passive.pierce_read_with.has(key))


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
	# Somebody whose foreseen turn the party changed, to anybody whose path
	# rewards it (PassiveDefinition.thwarted_damage_bonus).
	if target.get("thwarted", false):
		for passive in active_passives(attacker):
			multiplier *= 1.0 + passive.thwarted_damage_bonus
	# Momentum, Elemental Affinity, Synergy ("Progression").
	multiplier *= progression_damage_bonus(attacker, target, skill)
	# Disarmed, a weapon attack lands for less ("Disarmed").
	multiplier *= weapon_damage_factor(attacker, skill)
	return multiplier


## --- Disarmed ---
##
## A condition's Weapon Damage Change touches the bearer's weapon attacks - a
## skill that hurts with Physical damage and is neither a spell (through a gate)
## nor an item: a sword, a gun, a dart, a thrown nail, not a Fire Burst. With
## Ends After Weapon Attack it comes off once they have made one, hit or miss.
## Enfina's Disarm (the designer's handoff of 2026-10-25): their next one, half.

## Whether `skill` is a weapon attack.
static func is_weapon_attack(skill: SkillDefinition) -> bool:
	return skill != null and skill.deals_damage and not skill is ItemDefinition and not is_spell(skill) \
		and skill.damage_type == Damage.Type.PHYSICAL


## What `attacker`'s conditions do to `skill`'s damage: 1.0 but for a weapon
## attack while Disarmed.
func weapon_damage_factor(attacker: Dictionary, skill: SkillDefinition) -> float:
	if not is_weapon_attack(skill):
		return 1.0
	var factor := 1.0
	for entry in attacker.get("status_effects", []):
		var condition = entry.get("condition") if entry.get("stat", "") == "condition" else null
		if condition != null and condition.weapon_damage_change != 0.0:
			factor *= maxf(1.0 + condition.weapon_damage_change, 0.0)
	return factor


## `attacker` has made a weapon attack with `skill`: what lasted only until one
## comes off.
func _weapon_attack_made(attacker: Dictionary, skill: SkillDefinition):
	if not is_weapon_attack(skill) or not attacker.has("status_effects"):
		return
	for entry in attacker.status_effects.duplicate():
		var condition = entry.get("condition") if entry.get("stat", "") == "condition" else null
		if condition != null and condition.ends_after_weapon_attack:
			attacker.status_effects.erase(entry)
			update_information.emit("[color=yellow]%s[/color] is no longer %s.\n" % [attacker.name, condition.display_name.to_lower()])
			update_combatants.emit(combatants)



## What `skill` swings for before anybody's defence takes its share - the number
## the skill itself is worth, which is what the action panel shows.
##
## The same arithmetic as skill_damage with the target's half left out, and the
## mirror of heal_amount: a heal has never had a target's defence in it either,
## which is why the two now read the same way on the panel.
func base_skill_damage(attacker: Dictionary, skill: SkillDefinition) -> int:
	return maxi(roundi(power_behind(attacker, skill) * modifier_of(attacker, skill)), 0)


## A share of `target`'s own health a heal gives on top of its amount
## (EffectDefinition.heal_share_of_health): Restoration, Grace, the cure potions.
func heal_share_on(target: Dictionary, effect: EffectDefinition) -> int:
	if effect == null or effect.heal_share_of_health <= 0.0 or not target.has("max_hp"):
		return 0
	return roundi(get_effective_stat(target, "max_hp") * effect.heal_share_of_health)


## The share of `target`'s health `effect` mends from `healer`'s `skill`: ranked
## (heal_share_of), and twice it for Light Swing's finishing mend (_share_times).
func heal_share_from(healer: Dictionary, target: Dictionary, skill: SkillDefinition, effect: EffectDefinition) -> int:
	var share: float = heal_share_of(healer, skill, effect) if skill != null else effect.heal_share_of_health
	if share <= 0.0 or not target.has("max_hp"):
		return 0
	return roundi(get_effective_stat(target, "max_hp") * share * _share_times)


## What a heal's share is multiplied by just now: 2 while Light Swing's
## finishing mend lands (_wounded_bonus), 1 otherwise.
var _share_times := 1.0


## Twice the share of `skill`'s heal (EffectDefinition.share_doubled_on_wounded)
## when it struck somebody in `struck` now at half their health or less, the first
## time for them this fight - remembered on `attacker` (`wounded_bonus_on`).
func _wounded_bonus(attacker: Dictionary, skill: SkillDefinition, struck: Array) -> float:
	if skill == null or not skill.all_effects().any(func(effect): return effect != null and effect.share_doubled_on_wounded):
		return 1.0
	var spent: Array = attacker.get("wounded_bonus_on", [])
	for target in struck:
		if spent.has(target.get("id", -1)) or not target.has("max_hp"):
			continue
		if target.hp * 2 <= get_effective_stat(target, "max_hp"):
			spent.append(target.get("id", -1))
			attacker["wounded_bonus_on"] = spent
			update_information.emit("[color=yellow]%s[/color] finishes on a wounded foe, and mends twice over.\n" % attacker.name)
			return 2.0
	return 1.0


## What `skill` mends when `healer` casts it. No defence on the other side of
## it - being tough does not make you harder to patch up - and no randomness,
## so a heal is something you can count on when deciding whether it is enough.
##
## A skill's heal under the flat rule (EffectDefinition.heals_flat - Heal, Light
## Heal, Communion, Restoration, Mend the Bound) is Heal Flat + Heal Per Stat x the
## healer's healing stat + Heal Per Weapon x their weapon base; anything else is
## power_behind x the dial. Either way the heal bonus (Mercy I) multiplies all of
## it, and never the share of the target's health (heal_share_on). With no effect
## given, the skill's own heal is read - the AI ranks heals that way.
func heal_amount(healer: Dictionary, skill: SkillDefinition, effect: EffectDefinition = null) -> int:
	# A path that heals harder (the Carer's) - here, so the panel says so too.
	var bonus := 1.0
	for passive in active_passives(healer):
		bonus += passive.heal_bonus
	var heal := effect if effect != null or skill == null else heal_effect_of(skill)
	if heal != null and heal.heals_flat() and not skill is ItemDefinition:
		var stat := float(stat_of(healer, scaling_stat_of(healer, skill)))
		var weapon := float(healer.get("weapon_base", Stats.WEAPON_BASE))
		return maxi(roundi((heal.heal_flat + heal.heal_per_stat * stat + heal.heal_per_weapon * weapon) * bonus), 0)
	return maxi(roundi(power_behind(healer, skill) * heal_strength(skill, effect) * bonus), 0)


## `skill`'s first heal, or null.
func heal_effect_of(skill: SkillDefinition) -> EffectDefinition:
	for effect in skill.all_effects():
		if effect != null and effect.type == EffectDefinition.EffectType.HEAL:
			return effect
	return null


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
	var tiles = get_impact_tiles(skill, from, aim, terrain_class(caster), caster.get("size", Sizes.Size.HUMAN), caster)
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
					result.heal += (0 if effect.heals_share_only else heal_amount(attacker, skill, effect)) + heal_share_from(attacker, target, skill, effect)
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
	# A wall only to a spell, an item, or the strong (breaks_wall).
	if target.has("object") and target.object.wall and not breaks_wall(attacker, skill):
		update_information.emit("The [color=orange]%s[/color] holds: only a spell, a bomb or great strength brings it down.\n" % target.name)
		return
	# The raised element while an upgrade is being spent on this cast, and the
	# written one otherwise - read once, so what is resisted, what is shown and
	# what the log says can never disagree.
	var element = effective_damage_type(attacker, effect.damage_type)
	var resistance = resistance_of(target, element)
	# A skill's damage comes from the caster's stat and the skill's modifier.
	# The effect's own min/max only stand in when there is no skill behind the
	# damage at all - a condition burning away, a shove into a wall.
	var raw = skill_damage(attacker, target, skill, power) if skill != null else rng.randi_range(effect.min_amount, effect.max_amount)
	var damage = resisted_damage(target, element, raw)
	var flavour = "%s damage%s" % [Damage.type_name(element).to_lower(), Damage.describe_resistance(resistance)]
	# Being hit gives you away, whoever was aimed at. A blast thrown at somebody
	# else that happens to catch a hidden combatant has found them, even though
	# nobody knew they were there to aim at. Not somebody invisible, though:
	# there is still nothing there to see.
	if is_hidden(target) and not is_invisible(target):
		set_hidden(target, false)
		update_information.emit("[color=yellow]%s[/color] is caught, and their cover is blown!
" % target.name)
	# Somebody guarding them takes their share first (the Guardian's).
	damage = _guard_share(target, damage)
	# And a blow that would fell them stops short, somebody walling them (Last Wall).
	damage = _last_wall(target, damage)
	lose_hp(target, damage, element, attacker)
	if target.get("side", -1) != attacker.get("side", -2):
		_dealt_now += damage
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
		# A kill that spurs them on (Rampage).
		_after_felling(attacker, target)


func do_heal(attacker: Dictionary, target: Dictionary, effect: EffectDefinition, skill: SkillDefinition = null, mention_skill: bool = false):
	# A wall is no patient: a heal over it mends nothing.
	if is_wall(target):
		return
	# The same shape as damage: the healer's stat and the skill's modifier. The
	# effect's flat range only stands in when there is no skill behind the
	# healing at all, the way it does for damage.
	var amount = heal_amount(attacker, skill, effect) if skill != null else rng.randi_range(effect.min_amount, effect.max_amount)
	if effect.heals_share_only:
		amount = 0
	amount += heal_share_from(attacker, target, skill, effect)
	var before_heal: int = target.hp
	target.hp = mini(target.hp + amount, get_effective_stat(target, "max_hp"))
	_metric("heal", {"who": attacker, "target": target, "amount": target.hp - before_heal, "skill": skill})
	# What the healer's heals do besides (Mercy II and III - "Progression").
	_after_heal(attacker, target)
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
	# A summon falls and is gone - no body to take or bring back (see "Summons").
	if combatant.has("summoner"):
		if combatant.alive:
			cue("fell:%s" % combatant.name)
		_unsummon(combatant, "falls, and is gone")
		reveal_anyone_now_seen()
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
		cue("fell:%s" % combatant.name)
	# Guarded the way every other sprite reach in this file is: create_combatant
	# makes a combatant with no sprite on it, so the logic layer killing one of
	# its own must not depend on there being something drawn.
	var dying_sprite = combatant.get("sprite")
	if dying_sprite != null and is_instance_valid(dying_sprite):
		dying_sprite.set_dead()
	combatant_died.emit(combatant)
	# Their tether snaps, and their summons go with them (see "Summons").
	_summoner_gone(combatant)
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
		if not comb.alive and comb.side == side and comb.position == tile and not comb.get("illusion", false) and not comb.has("object") and not comb.has("taken") and not comb.get("eaten", false):
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
		if not comb.alive and comb.side == side and not comb.get("illusion", false) and not comb.has("object") and not comb.get("eaten", false):
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
	target.erase("invisible")
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
	# Back as big as they are without any Growth.
	resync_size(target)
	float_number(target, "+" + str(target.hp), Color("7fe08a"))
	update_combatants.emit(combatants)
	update_turn_queue.emit(combatants, turn_queue)
	update_information.emit("[color=yellow]%s[/color] used %s: [color=lightgreen]%s[/color] is back on their feet with %d health - and %d%% weaker until a long rest.\n" % [
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
## A Steal (EffectType.STEAL) empties one of somebody's containers - the one the
## thief chooses, asked before it lands (_choose_container): a party member's
## belt, pouch or backpack (Campaign "Containers"), or an enemy's pocket (what it
## fights with) or what it carries besides (comb.carried). It goes where the
## thief keeps their own - the party's bag from the belt on, so it is to hand at
## once if there is room; an enemy's pocket, then what it carries. What the thief
## has no room for stays where it was.

## The container a Steal being resolved takes from, while it is; "" for the
## first with anything in it.
var _steal_from := ""


## Whether `skill` takes things off whoever it lands on.
static func steals(skill: SkillDefinition) -> bool:
	if skill == null:
		return false
	for effect in skill.all_effects():
		if effect != null and effect.type == EffectDefinition.EffectType.STEAL:
			return true
	return false


## What there is to steal off `target`, a container at a time, the empty ones
## left out: [{"kind", "label", "items"}], "items" an item key for each thing.
func steal_choices(target: Dictionary) -> Array:
	var found := []
	var key: String = target.get("combatant_key", "")
	if target.get("side", 1) == 0 and key != "" and CombatantDatabase.combatants.has(key) and not target.has("summoner"):
		for kind in Campaign.CONTAINER_SLOTS:
			var items: Array = Campaign.contents_of(key, kind)
			if items.is_empty():
				continue
			var piece := EquipmentDefinition.named(Campaign.container_in(key, kind))
			found.append({"kind": kind, "label": piece.name if piece != null else EquipmentDefinition.slot_name_of(kind), "noun": EquipmentDefinition.slot_name_of(kind).to_lower(), "items": items})
		return found
	if not target.get("pocket", []).is_empty():
		found.append({"kind": "pocket", "label": "What it fights with", "noun": "pocket", "items": target.pocket.duplicate()})
	if not target.get("carried", []).is_empty():
		found.append({"kind": "carried", "label": "What it carries", "noun": "pack", "items": target.carried.duplicate()})
	return found


## Whether anybody standing against `comb` has something on them to take.
func anyone_carrying_against(comb: Dictionary) -> bool:
	for other in combatants:
		if other.alive and other.side != comb.get("side", 0) and not steal_choices(other).is_empty():
			return true
	return false


## Which of `target`'s containers `attacker`'s Steal empties: the player is asked
## when there is more than one with anything in it; anybody else takes the
## fullest. "" for none at all.
func _choose_container(attacker: Dictionary, target: Dictionary) -> String:
	var choices := steal_choices(target)
	if choices.is_empty():
		return ""
	if choices.size() == 1:
		return choices[0].kind
	if plays_for_party(attacker) and reaction_prompt != null and reaction_prompt.has_method("pick"):
		var labels: Array = choices.map(func(choice): return "%s: %s" % [choice.label, _item_names(choice.items)])
		var picked: int = await reaction_prompt.pick("%s steals" % attacker.name,
			"Which of %s's things does %s take?" % [target.name, attacker.name], labels)
		return choices[clampi(picked, 0, choices.size() - 1)].kind
	var fullest: Dictionary = choices[0]
	for choice in choices:
		if choice.items.size() > fullest.items.size():
			fullest = choice
	return fullest.kind


## Empties the container of `target`'s chosen for this Steal (_steal_from) - all
## of it, or effect.steal_count of it - into `attacker`'s, as far as they have
## room.
func steal(attacker: Dictionary, target: Dictionary, effect: EffectDefinition, skill: SkillDefinition = null):
	if immune_to(target, Immunity.Kind.STOLEN_FROM):
		shrug_off(target, Immunity.name_of(Immunity.Kind.STOLEN_FROM))
		return
	var choices := steal_choices(target)
	var chosen: Dictionary = choices[0] if not choices.is_empty() else {}
	for choice in choices:
		if choice.kind == _steal_from:
			chosen = choice
	var carried: Array = chosen.get("items", []).duplicate()
	if effect.steal_count > 0 and carried.size() > effect.steal_count:
		carried.resize(effect.steal_count)
	if carried.is_empty():
		update_information.emit("[color=red]%s[/color] has nothing on them to steal.\n" % target.name)
		return
	var thief_key: String = attacker.get("combatant_key", "") if attacker.get("side", 1) == 0 else ""
	var taken := []
	var for_later := []
	var left := []
	for key in carried:
		var slot := _stow(attacker, key)
		if slot < 0:
			left.append(key)
			continue
		_give_up(target, key, chosen.kind)
		taken.append(key)
		if thief_key != "" and slot >= Campaign.combat_slots_of(thief_key):
			for_later.append(key)
	if taken.is_empty():
		update_information.emit("[color=yellow]%s[/color] has no room for anything [color=red]%s[/color] is carrying.\n" % [
			attacker.name, target.name])
		return
	float_number(target, "Stolen", Color("f2d36b"))
	update_combatants.emit(combatants)
	update_information.emit("[color=yellow]%s[/color] used %s: empties [color=red]%s[/color]'s %s - %s.\n" % [
		attacker.name, skill.name if skill != null else "it", target.name, chosen.noun, _item_names(taken)])
	if not for_later.is_empty():
		update_information.emit("[color=yellow]%s[/color] has no free hand for %s - packed away, for after the fight.\n" % [
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
	if pocket.size() >= comb.get("pocket_size", Campaign.COMBAT_SLOTS):
		return -1
	pocket.append(key)
	return pocket.size() - 1


## Takes one `key` off `comb`, out of their container `kind` ("" for wherever it
## is to hand first).
func _give_up(comb: Dictionary, key: String, kind: String = ""):
	if comb.side == 0:
		Campaign.take_item(comb.get("combatant_key", ""), key, kind if kind in Campaign.CONTAINER_SLOTS else "")
		return
	for list in (["carried"] if kind == "carried" else ["pocket", "carried"]):
		var held: Array = comb.get(list, [])
		var slot := held.find(key)
		if slot >= 0:
			held.remove_at(slot)
			return


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
## came off their health. `by` is whoever did it, when anybody did, and
## `lingering` names what was burning on them (a condition's name) - both only
## for the metric, so a tick is laid at its source's door, and a reaction at
## the reactor's, rather than at whoever's turn it is.
func lose_hp(target: Dictionary, amount: int, element: int = -1, by: Dictionary = {}, lingering: String = "") -> int:
	# Nothing hurts the untouchable (Illusory Dragon).
	if target.get("untouchable", false):
		return 0
	var shield: int = target.get("temp_hp", 0)
	var absorbed := mini(shield, amount)
	if absorbed > 0:
		target.temp_hp = shield - absorbed
	target.hp -= amount - absorbed
	_metric("damage", {"target": target, "amount": amount - absorbed, "absorbed": absorbed, "element": element,
		"during": combatants[current_combatant] if current_combatant >= 0 and current_combatant < combatants.size() else {},
		"by": by, "lingering": lingering})
	# A boss's stagger bar and phases (see "Bosses"); `element` is the damage's
	# type, for a bar only one type fills.
	_after_hp_lost(target, amount - absorbed, element)
	# What they were holding on a tether, frayed (see "Tethers").
	_tether_hurt(target, amount - absorbed)
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
		if not warder.alive or warder.side != target.side or warder.get("illusion", false):
			continue
		# Their reaction spent - unless it went on a Ward and they can Ward more
		# than once a round (Shared Ward), and have not yet as often as that.
		var wards: int = warder.get("wards_this_round", 0)
		if warder.get("reaction_used", false) and (wards == 0 or wards >= wards_a_round(warder)):
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
			warder["wards_this_round"] = wards + 1
			update_information.emit("[color=yellow]%s[/color] wards [color=yellow]%s[/color].\n" % [warder.name, target.name])
			return 1.0 - passive.ward_reduction
	return 1.0


## What `attacker`'s paths do once `skill` has landed on `target`: an ally a
## spell lands on overhealed, or spurred on; an enemy hit while empowered set
## alight too.
func _after_landing(attacker: Dictionary, target: Dictionary, skill: SkillDefinition):
	if not attacker.alive:
		return
	# The shock spreads even from somebody the blow felled (Titanfall, Tremor).
	if target.get("side", -1) != attacker.side and skill.deals_damage:
		_splash(attacker, target, skill)
	if not target.alive:
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
	if target.side != attacker.side and skill.deals_damage:
		# What the paths do with a hit that landed (see "The paths").
		_overload(attacker, target, skill)
		_spellstrike(attacker, target, skill)


## The blow that landed on `target` catching others too: a rank that splashes
## (SkillRank.splash_radius - Greatsword Attack's Titanfall) at its own modifier
## within its reach, and Tremor (PassiveDefinition.tremor_share) at a share of
## the hit on everybody beside them - each caught once, at the harder of the
## two. The rank shoves only as far as its Splash Shove (Titanfall: not at all,
## since the designer's change of 2026-10-24); Tremor shoves everybody beside
## them a tile whichever was harder, and the one struck as well - and remembers
## whoever it threw, for the step after them (tremor_steps).
func _splash(attacker: Dictionary, target: Dictionary, skill: SkillDefinition):
	if skill == null or not skill.deals_damage:
		return
	var rank: SkillRank = null
	for reached in ranks_reached(attacker, skill):
		if reached.splash_radius > 0:
			rank = reached
	var tremor := 0.0
	for passive in active_passives(attacker):
		tremor = maxf(tremor, passive.tremor_share)
	if rank == null and tremor <= 0.0:
		return
	var modifier := modifier_of(attacker, skill)
	var caught := []
	for other in combatants:
		if other == target or not other.get("alive", false) or other.get("side", -1) == attacker.get("side", -2) \
				or other.has("object") or other.has("riding"):
			continue
		var hit := 0.0
		var shove := 0
		if rank != null and distance_to(other, nearest_tile_of(target, other.position)) <= rank.splash_radius:
			hit = rank.splash_modifier
			shove = rank.splash_shove
		if tremor > 0.0 and _beside(other, target):
			hit = maxf(hit, modifier * tremor)
			shove = maxi(shove, 1)
		if hit > 0.0:
			caught.append([other, hit, shove])
	if not caught.is_empty():
		update_information.emit("The shock of it spreads from [color=red]%s[/color].\n" % target.name)
	for each in caught:
		apply_effect(attacker, each[0], skill.damage_effect(), skill, false, each[1] / maxf(modifier, 0.01), target.position)
		_shove(attacker, each[0], each[2], skill)
	if tremor > 0.0:
		_shove(attacker, target, 1, skill)
		# In their own turn: what they could step after once the action is done.
		if on_whoever_acts(attacker):
			var thrown: Array = attacker.get("tremor_struck", [])
			if not thrown.has(target.get("id", -1)):
				thrown.append(target.get("id", -1))
			attacker["tremor_struck"] = thrown


## The tiles `comb` could step to after their Tremor threw somebody back
## (PassiveDefinition.tremor_follow): a straight tile beside them nearer the
## first of those it threw still standing, free and safe - nothing in the way
## and nobody there (can_land_on), no hazard marked on it, no ground that hurts,
## nothing of the other side's laid on it. Only in their own turn and with
## nothing holding them where they are. Empty otherwise - in reach of them
## already, nothing nearer to be had, or nobody it threw still standing.
func tremor_steps(comb: Dictionary) -> Array:
	var found := []
	var thrown: Array = comb.get("tremor_struck", []).map(func(id): return combatant_with_id(id)).filter(func(target): return target.get("alive", false))
	if thrown.is_empty() or not on_whoever_acts(comb) or has_restriction(comb, "prevents_movement") \
			or not active_passives(comb).any(func(passive): return passive.tremor_follow):
		return found
	var target: Dictionary = thrown[0]
	var unsafe := hazard_warning_tiles() + bad_ground_tiles()
	for way in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
		var tile: Vector2i = comb.position + way
		if tile in unsafe or not can_land_on(comb, tile) or zones_at(tile).any(func(zone): return zone.side != comb.side):
			continue
		if get_position_distance(tile, nearest_tile_of(target, tile)) < get_position_distance(comb.position, nearest_tile_of(target, comb.position)):
			found.append(tile)
	return found


## Where `comb` steps after their Tremor threw somebody back: of tremor_steps,
## the one that leaves them closest beside whoever it was (by the eight ways
## round) - or where they stand, with none. Taken for them, free: no movement
## spent, and nothing provoked (the designer, 2026-10-24).
func tremor_step_to(comb: Dictionary) -> Vector2i:
	var best: Vector2i = comb.position
	var steps := tremor_steps(comb)
	if steps.is_empty():
		return best
	var target := combatant_with_id(comb.tremor_struck.filter(func(id): return combatant_with_id(id).get("alive", false))[0])
	var best_gap := 999999
	for tile in steps:
		var near := nearest_tile_of(target, tile)
		var gap := maxi(absi(near.x - tile.x), absi(near.y - tile.y))
		if gap < best_gap:
			best = tile
			best_gap = gap
	return best


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

## How many free amplifications `comb` has a short rest at their level.
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
##
## A skill Placed In Reach puts the image wherever it was aimed (_placing_at),
## of whoever was chosen however far off they are. The other side takes it for
## who it is of all the way through: worth what they are worth to it
## (ai_target_value, _seen_as), and a body in its way, cover and all, while it
## decides what to do (ai_believes). What actually happens goes by what is
## there: it stops no shot and shields nobody from a blast.

## Whether the other side's mind is being made up - the AI deciding its turn, or
## the danger view and Intuition saying what it will decide - rather than
## something happening. While it is, an image is a body like any other to sight
## (CController.blocks_sight, _SightGrid); otherwise it stops nothing. Set by
## ai_process, threat_map and plan_intent; use_skill, advance_turn and a step
## arriving (CController) put it back to what happens for as long as they run.
var ai_believes := false
## Whose mind it is, while ai_believes: the side deciding. An illusion is real
## to the other side of whoever made it, never to its own (believes_illusion).
var _believer_side: int = Group.ENEMIES


## Whether the party's mind is being made up - the player aiming a skill
## (CController) - rather than something happening: an illusion of the other
## side's is real to them then, as the party's is to the AI's (ai_believes).
func party_believes() -> bool:
	return not ai_believes and controller != null and is_instance_valid(controller) \
		and controller._skill_selected and controller.player_turn


## Whether `thing` - an image, Illusory Cover - is real to whoever's mind is
## being made up just now: the other side's, never its own. When nobody's is
## (something happening), it stops nothing.
func believes_illusion(thing: Dictionary) -> bool:
	if ai_believes:
		return thing.get("side", -1) != _believer_side
	if party_believes():
		return thing.get("side", -1) != Group.PLAYERS
	return false

## Where the image a skill Placed In Reach makes goes, while it lands (use_skill).
var _placing_at := NO_AREA


## Who `comb` is taken for by the other side: whoever an image is of, while they
## are standing, or else themselves.
func _seen_as(comb: Dictionary) -> Dictionary:
	if not comb.get("illusion", false):
		return comb
	for other in combatants:
		if other.get("id", -1) == comb.get("image_of", -2) and other.get("alive", false):
			return other
	return comb


## Puts up an image of `target`, from `attacker`: where it was aimed for a skill
## Placed In Reach (_placing_at), or else on a tile beside them.
func summon_decoy(attacker: Dictionary, target: Dictionary, skill: SkillDefinition = null):
	if not target.alive or target.get("illusion", false):
		return
	var definition: CombatantDefinition = CombatantDatabase.combatants.get(target.get("combatant_key", ""))
	if definition == null:
		return
	var tile: Vector2i = _placing_at
	if tile == NO_AREA:
		tile = controller.nearest_free_tile(target.position, target.movement_class)
		if tile == target.position or not can_land_on(target, tile):
			update_information.emit("There is no room beside [color=yellow]%s[/color] for an image.\n" % target.name)
			return
	elif tile == target.position or not can_land_on(target, tile):
		update_information.emit("There is no room there for an image of [color=yellow]%s[/color].\n" % target.name)
		return
	# The party's own know their images for what they are; an image of the other
	# side's is meant to fool them, so it is called what its original is, and
	# looks it.
	var ours: bool = target.get("side", 0) == Group.PLAYERS
	var image: Dictionary = create_combatant(definition, "", ("%s (image)" % target.name) if ours else target.name, null, target.get("level", 1))
	if not ours:
		image["named_by_author"] = true
	image["illusion"] = true
	image["image_of"] = target.get("id", -1)
	# Who made it: while they stand, it holds the other side's eye ("Images, and hiding").
	image["made_by"] = attacker.get("id", -1)
	# Made by a spell: Dispel Magic through as deep a gate undoes it ("Dispelling").
	if is_spell(skill):
		image["spell_gate"] = spell_gate_of(skill)
	image["base_name"] = image.name
	image.max_hp = 1
	image.hp = 1
	image.skill_list = []
	image.passives = []
	image.initiative = 0
	image.movement = 0
	image.spell_slots = Stats.no_gates()
	image.max_spell_slots = Stats.no_gates()
	add_combatant(image, target.side, tile)
	var sprite = image.get("sprite")
	if ours and sprite != null and is_instance_valid(sprite):
		sprite.modulate = Color(0.75, 0.85, 1.0, 0.65)
	update_turn_queue.emit(combatants, turn_queue)
	update_combatants.emit(combatants)
	if ours:
		update_information.emit("[color=yellow]%s[/color] used %s: an image of [color=lightgreen]%s[/color] stands %s.\n" % [
			attacker.name, skill.name if skill != null else "it", target.name, "beside them" if _placing_at == NO_AREA else "where it was put"])
	else:
		# Where it stands is the other side's secret.
		update_information.emit("[color=red]%s[/color] used %s.\n" % [attacker.name, skill.name if skill != null else "an illusion"])


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
	# The last of them gone, with everybody out of sight ("Images, and hiding").
	_after_image_gone(image)


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
	if aoe_radius_of(comb, skill) > 0:
		tiles = get_impact_tiles(skill, nearest_tile_of(comb, aim), aim, terrain_class(comb), comb.get("size", Sizes.Size.HUMAN), comb)
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
	_metric("declared", {"who": comb, "skill": skill, "tiles": tiles})
	update_combatants.emit(combatants)
	if controller != null:
		controller.queue_redraw()
	if game_ui != null and comb.side == 0 and game_ui.has_method("refresh_action_buttons"):
		game_ui.refresh_action_buttons()
	# Whoever can answer a move being called does (Declares) - a Hack, say.
	await _react(Trigger.DECLARES, comb, "%s calls %s" % [comb.name, skill.name])


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
	_metric("declared_landed", {"who": comb, "skill": SkillDatabase.skills[declared.skill], "tiles": declared.tiles})
	comb["landing_tiles"] = declared.tiles
	await use_skill(declared.skill, comb, declared.aim, false, declared.as_secondary, declared.destination, true)
	comb.erase("landing_tiles")


## Loses what `comb` declared, saying why.
func drop_declared(comb: Dictionary, why: String):
	if not comb.has("declared"):
		return
	update_information.emit("[color=yellow]%s[/color]'s %s comes to nothing - %s.\n" % [
		comb.name, SkillDatabase.skills[comb.declared.skill].name, why])
	_metric("declared_dropped", {"who": comb, "skill": SkillDatabase.skills[comb.declared.skill], "why": why})
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
	if condition.resource_path in comb.get("immune_conditions", []):
		return true
	# A path's (Unstoppable's Grappled).
	if comb.has("passives"):
		for passive in active_passives(comb):
			if passive.immune_to_conditions.any(func(c): return c != null and c.resource_path == condition.resource_path):
				return true
	return false


func immune_to(comb: Dictionary, kind: int) -> bool:
	if comb.has("object") or kind in comb.get("immune_to", []):
		return true
	# A path's (Immovable's shoves).
	if comb.has("passives"):
		for passive in active_passives(comb):
			if kind in passive.immune_to:
				return true
	return false


## Says `comb` shrugged `what` off ("stunned", "being shoved") - and, for a
## condition, counts it on their stagger bar.
func shrug_off(comb: Dictionary, what: String, a_condition: bool = false):
	if comb.has("object"):
		return
	update_information.emit("[color=red]%s[/color] is immune to %s.\n" % [comb.name, what])
	_metric("blocked", {"who": comb, "what": what, "condition": a_condition})
	float_number(comb, "Immune", Color("cfd8e3"))
	var bar: StaggerDefinition = comb.get("stagger_def")
	if a_condition and bar != null:
		add_stagger(comb, bar.per_blocked_condition, "blocked condition")


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
	_metric("condition", {"target": target, "condition": condition, "by": combatant_with_id(source_id) if source_id >= 0 else {}, "by_name": source, "turns": stored})
	if condition.movement_change != 0:
		resync_live_movement(target, movement_before)
	update_combatants.emit(combatants)
	return true


## --- Metrics ---
##
## A moment a test harness counts (LabMetrics, tools/lab_metrics.gd): a round
## begun, a turn taken or lost, an action, damage, a heal, a gate spent, an item,
## a declared move called, landed or dropped, stagger gained or full. Reported
## as it happens, read by nobody in the game itself.
func _metric(event: String, data: Dictionary):
	metric.emit(event, data)


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
	cue("phase:%s" % phase.name)
	# What it grows, whole - over whatever part was there before (part_index_at
	# asks the newest first).
	for part in phase.parts_added:
		if part == null:
			continue
		if not comb.has("parts"):
			comb["parts"] = []
			comb["parts_hp"] = []
		comb.parts.append(part)
		comb.parts_hp.append(maxi(roundi(comb.max_hp * part.health_share), 1))
		update_information.emit("[color=red]%s[/color] grows %s.\n" % [comb.name, part.name.to_lower()])
	if phase.grows > 0:
		comb["base_size"] = mini(comb.get("base_size", comb.size) + phase.grows, Sizes.Size.GIGANTIC)
		resync_size(comb)
	if phase.holds_at_once > 0:
		comb["holds_at_once"] = phase.holds_at_once
	if phase.eats_itself > 0.0:
		comb["eats_itself"] = phase.eats_itself
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
	var staggered: float = target.get("stagger_hit_bonus", 1.0) if is_staggered(target) else 1.0
	# Iron Hide, Bulwark, Radiant Guardian and the like ("Progression").
	return staggered * (1.0 - damage_reduction_of(target))


## Adds `amount` to `comb`'s stagger bar - more while they are readying
## something declared, by their bar's While Readying - and staggers them when
## it is full. Nothing while they have no bar or are staggered already.
## `source` says what filled it, for the metrics ("damage", "blocked condition").
func add_stagger(comb: Dictionary, amount: float, source: String = ""):
	var bar: StaggerDefinition = comb.get("stagger_def")
	if bar == null or amount <= 0.0 or not comb.alive or is_staggered(comb):
		return
	if comb.has("declared"):
		amount *= bar.while_readying
	_metric("stagger_gain", {"who": comb, "amount": amount, "source": source, "readying": comb.has("declared")})
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
	_metric("staggered", {"who": comb, "turns_lost": bar.turns_lost})
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
	drop_readied(comb, "staggered")
	# Reeling, it heaves up whoever it has swallowed (Swallow).
	_free_the_swallowed(comb, false, "is heaved back up, alive")
	cue("staggered:%s" % comb.name)
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
			add_stagger(target, lost * bar.per_damage, "damage")


## A hit landing on a boss: its bar's Per Hit, and what the skill adds itself.
func _stagger_from_hit(target: Dictionary, skill: SkillDefinition):
	var bar: StaggerDefinition = target.get("stagger_def")
	if bar == null:
		return
	var amount := bar.per_hit
	if skill != null:
		amount += bar.from_skills.get(skill.resource_path.get_file().get_basename(), 0.0)
	add_stagger(target, amount, "a hit")


## --- Auras ---
##
## A passive with an Aura Radius (PassiveDefinition): whoever begins a turn
## within that many tiles of its holder has its condition for that turn - the
## foes' one or the allies' one. A boss's presence, mostly; anybody can have one.

func _auras_on(comb: Dictionary):
	for holder in combatants:
		if holder == comb or not holder.alive or not holder.has("passives"):
			continue
		_aura_of(holder, comb, true)


## Whether `holder`'s aura of `passive` takes hold of `comb`: always, unless it is
## Aura Contested - then only if the holder's Aura Contest With beats their Aura
## Resisted By, as a contested skill is weighed (wins_contest).
func _aura_takes_hold(holder: Dictionary, passive: PassiveDefinition, comb: Dictionary) -> bool:
	if not passive.aura_contested:
		return true
	return stat_of(comb, passive.aura_resisted_by) < stat_of(holder, passive.aura_contest_with)


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
			_shuffle(open)
			places = open.slice(0, hazard.count)
		_:
			var standing := []
			for comb in combatants:
				if comb.alive and _takes_turns(comb) and (hazard.aim == HazardDefinition.Aim.AT_EVERYONE or comb.side == 0):
					var theirs := tiles_of(comb)
					standing.append(theirs[rng.randi() % theirs.size()])
			_shuffle(standing)
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
		if put_condition(target, condition, turns_stored(turns, condition.wears_off_at_start, on_whoever_acts(target)), source):
			update_information.emit("[color=red]%s[/color] is %s.\n" % [target.name, condition.display_name.to_lower()])
	if stagger_amount > 0.0:
		add_stagger(target, stagger_amount, "the arena")
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
	# Something that Using turns into something else - a carcass tainted.
	if thing.object.used_becomes != null:
		_becomes(thing, thing.object.used_becomes, user)
		return
	set_off(thing, user)
	if thing.uses_left > 0:
		thing.uses_left -= 1
		if thing.uses_left == 0 and thing.alive:
			_object_gone(thing, "is spent")


## `thing`, Used by `user`, turned into `into` (BattleObjectDefinition.used_becomes):
## the same spot on the map, as the other thing.
func _becomes(thing: Dictionary, into: BattleObjectDefinition, user: Dictionary):
	var before: String = thing.name
	thing.object = into
	thing.name = into.name
	thing.base_name = into.name
	thing.uses_left = into.uses if into.uses > 0 else -1
	var sprite = thing.get("sprite")
	if sprite != null and is_instance_valid(sprite):
		if into.sprite_frames != null:
			sprite.show_as(into.sprite_frames)
		else:
			sprite.set_still(into.map_still())
		sprite.set_tint(into.tint)
	update_information.emit("[color=yellow]%s[/color] turns the [color=orange]%s[/color] into the [color=orange]%s[/color].\n" % [user.name, before, into.name])
	cue("used:%s" % before)
	update_combatants.emit(combatants)


## `thing` going off - Used, or broken. `backfire`: a hack on it failed, and it
## goes off on the party (Backfire Hits) with nothing for a boss's bar.
func set_off(thing: Dictionary, by: Dictionary = {}, backfire: bool = false):
	var object: BattleObjectDefinition = thing.object
	cue("used:%s" % thing.name)
	if backfire:
		update_information.emit("[color=red]The %s goes off in [color=yellow]%s[/color]'s hands![/color]\n" % [thing.name, by.get("name", "their")])
	elif object.set_off_line != "":
		update_information.emit("[color=orange]%s[/color]\n" % object.set_off_line)
	elif not by.is_empty():
		update_information.emit("[color=yellow]%s[/color] sets off the [color=orange]%s[/color].\n" % [by.name, thing.name])
	if object.stagger > 0.0 and not backfire:
		for boss in living_bosses():
			add_stagger(boss, object.stagger, "a thing on the map")
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
## fight: the Hack skill (EffectType.HACK) on a foe winding up a declared skill
## that is Hackable (SkillDefinition.can_be_hacked - refusal_for turns the rest
## away), and Using a thing on the map whose BattleObjectDefinition has a Hack. Either
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
					add_stagger(target, hack.stagger_on_success, "a hack")
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


## Whether `attacker`'s `skill` can hurt a breakable wall: a spell, an item, or
## anything of somebody who Breaks Walls (CombatantDefinition.breaks_walls).
func breaks_wall(attacker: Dictionary, skill: SkillDefinition) -> bool:
	if skill == null:
		return false
	if skill is ItemDefinition or is_spell(skill):
		return true
	var definition: CombatantDefinition = CombatantDatabase.combatants.get(attacker.get("combatant_key", ""))
	return definition != null and definition.breaks_walls


## Takes `thing` off the board - spent, or broken - saying `how`.
func _object_gone(thing: Dictionary, how: String):
	# A wall off a map, kept down there (StealthWatch.build_fight's "wall_flag").
	if thing.has("wall_flag"):
		Campaign.set_flag(thing.wall_flag)
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
##
## The whole turn is made up as they see it: an image is a body to them
## (ai_believes) - though what they do lands on what is really there.
func ai_process(comb: Dictionary):
	var believed := ai_believes
	ai_believes = true
	_believer_side = comb.get("side", Group.ENEMIES)
	await _ai_turn(comb)
	ai_believes = believed


func _ai_turn(comb: Dictionary):
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
	if not climbers_of(comb).is_empty():
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
	# A guard does not leave its post to chase what it cannot reach this turn:
	# it readies instead ("Readying, for the AI").
	if comb.get("ai_readies", 0) & AiReady.GUARDS and not _ai_can_strike_this_turn(comb) and _ai_guard_ready(comb):
		await ai_secondary_attack(comb)
		await advance_turn()
		return
	# Played out to the end, a turn that never used its main action may ready
	# one as it ends (advance_turn).
	comb["ai_turn_live"] = true
	var ai_function = comb.get("ai_function", "ai_melee_rush")
	if ai_function != "" and has_method(ai_function):
		await call(ai_function, comb)
	else:
		await ai_melee_rush(comb)
	comb.erase("ai_turn_live")


## The nearest living combatant on the opposite side to comb, or an empty
## Dictionary if there isn't one.
func find_nearest_enemy_of(comb: Dictionary) -> Dictionary:
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
		if skill == null or not skill.deals_damage or skill.targets_ally or skill.reaction_only:
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
		if skill.targets_ally or skill.aoe_radius > 0 or skill.reaction_only:
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
	if skill != null and skill.reaction_only:
		return "%s only goes off as a reaction - when %s." % [skill.name, skill.describe_triggers()]
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
		if skill.reaction_only or not can_afford_skill(comb, skill) or not meets_level_for(comb, skill):
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
	var is_blast = aoe_shape_of(caster, skill) != SkillDefinition.AoEShape.LINE \
			and aoe_shape_of(caster, skill) != SkillDefinition.AoEShape.CONE
	#
	# A skill that moves its caster aims at the tile they arrive on, and nobody
	# arrives on a tile somebody is already standing on. Without this the best
	# aim for Blink Strike is the target's own tile - the blast catches them
	# from there, so it scores as a hit - and the blink quietly does nothing.
	var must_land = skill.teleports == SkillDefinition.TeleportWho.CASTER and not caster.is_empty()
	var radius := aoe_radius_of(caster, skill)
	var catchable: Array[Vector2i] = []
	if is_blast:
		for index in groups[Group.PLAYERS]:
			var p = combatants[index]
			if not p.alive or is_hidden(p):
				continue
			# Exactly what filter_tiles_by_line_of_sight would have dropped, and
			# it has to stay exactly that or the AI writes off a target the
			# player is shown as reachable.
			if skill.respects_blocking and _aim_blocked(p.position, movement_class):
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
					if get_position_distance(aim, position) > radius:
						continue
					# Line of sight is a question about where the blast lands
					# now, so it is asked here rather than once per tile - but
					# only for somebody actually inside it, and the walk is at
					# most the blast's own radius.
					if skill.respects_blocking and not has_line_of_sight(aim, position, movement_class):
						continue
					count += 1
			else:
				var tiles = get_impact_tiles(skill, nearest_from(caster, caster_position, aim), aim, movement_class, caster.get("size", Sizes.Size.HUMAN), caster)
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
				if not skill.reacts_to(SkillDefinition.Trigger.LEAVES_REACH):
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
	# An image is worth what whoever it is of is worth: there is no telling them
	# apart (see "Images") - not by how hurt it looks, nor how easily it falls.
	var seen := _seen_as(target)
	# Nothing touches the untouchable, and they soon stop trying (Illusory Dragon).
	if seen.get("untouchable", false) and seen.get("side", -1) != attacker.get("side", -2):
		return 0.0
	var hit = predict_hit(attacker, seen, skill)
	var worth := float(hit.damage)
	if hit.wins:
		for effect in skill.all_effects():
			if effect == null or effect.applies_to_caster or effect.condition == null:
				continue
			if effect.type == EffectDefinition.EffectType.CONDITION and not _carries(seen, effect.condition):
				worth += AI_CONDITION_VALUE
	if worth <= 0.0:
		return 0.0
	if hit.lethal:
		worth += AI_KILL_BONUS
	var most = maxf(float(get_effective_stat(seen, "max_hp")), 1.0)
	worth += AI_HURT_BONUS * clampf(1.0 - float(seen.hp) / most, 0.0, 1.0)
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
	for other in combatants:
		if not other.alive:
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
	if skill == null or skill.targets_ally or skill.kills_caster or skill.reaction_only or _swallows(skill):
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
	# What is in their pocket to throw - anything that hurts or hinders the other
	# side - weighed against their own skills by what it would do (ai_plan_attack).
	if comb.side != 0:
		for key in items_of(comb):
			var item: ItemDefinition = ItemDatabase.item(key)
			if item != null and _item_against_the_other_side(item) and not keys.has(key) \
					and SkillDatabase.skills.has(key):
				keys.append(key)
	# Declared moves are announced on their own (_ai_declare), not swung now.
	return keys.filter(func(key): return not SkillDatabase.skills[key].declared)


## Whether `item` is for the other side: something to throw that hurts them or
## leaves something on them - a bomb, a bottle of fire or frost.
static func _item_against_the_other_side(item: ItemDefinition) -> bool:
	if item.targets_ally or item.targets_fallen:
		return false
	if item.deals_damage:
		return true
	return item.all_effects().any(func(effect): return effect != null and not effect.applies_to_caster \
		and effect.type in [EffectDefinition.EffectType.CONDITION, EffectDefinition.EffectType.DAMAGE_OVER_TIME,
			EffectDefinition.EffectType.PUSH, EffectDefinition.EffectType.PULL])


## The best way `comb` has to mend `patient`: its own heal, or something healing
## in its pocket - a Gate Nade of a heal, a potion for itself - whichever mends
## more and can reach them. Its own skill on a tie, so the pocket is kept. "" for
## nothing at all.
func _ai_heal_key(comb: Dictionary, patient: Dictionary, movement_budget: int = -1) -> String:
	var options := []
	var own := find_skill_of_type(comb, EffectDefinition.EffectType.HEAL)
	if own != "":
		options.append(own)
	if comb.side != 0:
		for key in items_of(comb):
			var item: ItemDefinition = ItemDatabase.item(key)
			if item == null or not item.targets_ally or not SkillDatabase.skills.has(key) or options.has(key):
				continue
			if item is GateNadeDefinition and not can_use_gate_nade(comb, item):
				continue
			if not item.all_effects().any(func(effect): return effect != null and effect.type == EffectDefinition.EffectType.HEAL):
				continue
			# Drunk, not thrown: for itself only.
			if not patient.is_empty() and patient != comb and effective_max_range(comb, item) < 1:
				continue
			options.append(key)
	# Given a budget, the biggest heal that can reach the patient this turn - a
	# bigger one it cannot get in range of would only walk it there and mend
	# nobody. With none in reach, the biggest, to close on for next turn.
	if movement_budget >= 0 and not patient.is_empty():
		var reaching := options.filter(func(key): return can_shoot_from_anywhere_reachable(
			comb, patient.position, SkillDatabase.skills[key], movement_budget))
		if not reaching.is_empty():
			options = reaching
	var best := ""
	var most := -1.0
	for key in options:
		var amount := float(heal_amount(comb, SkillDatabase.skills[key]))
		if amount > most:
			most = amount
			best = key
	return best


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
	var radius: int = aoe_radius_of(comb, skill)
	var blast = aoe_shape_of(comb, skill) == SkillDefinition.AoEShape.DIAMOND
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
				if _aim_blocked(other.position, comb.movement_class):
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
	var radius: int = aoe_radius_of(comb, skill)
	var blast = aoe_shape_of(comb, skill) == SkillDefinition.AoEShape.DIAMOND
	var own: float = worth.get(comb.get("id", -1), 0.0)
	for aim in aims:
		# From whichever of their tiles stood there is nearest, for somebody bigger.
		var from := standing
		if footprint(comb) != Vector2i.ONE:
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
			var tiles = get_impact_tiles(skill, nearest_from(comb, standing, aim), aim, comb.movement_class, comb.get("size", Sizes.Size.HUMAN), comb)
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
	if aoe_shape_of(comb, skill) != SkillDefinition.AoEShape.DIAMOND:
		tiles = get_impact_tiles(skill, nearest_from(comb, standing, aim), aim, comb.movement_class, comb.get("size", Sizes.Size.HUMAN), comb)
	var best := {}
	var best_value := 0.0
	for other in combatants:
		if not other.alive or other.side == comb.side or is_hidden(other):
			continue
		var caught = other.position in tiles if not tiles.is_empty() \
				else get_position_distance(aim, other.position) <= aoe_radius_of(comb, skill)
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


## The Alchemist (ai_function "ai_alchemist"): fights with what it carries - a
## pocket of a dozen things (CombatantDefinition.pocket_size), and its Bandolier
## to use one with each action. Each action goes on whatever is worth most:
## mending whichever of its side is worst hurt, if anybody is down below
## AI_ALCHEMIST_MENDS_BELOW and it has something to mend them with, or else the
## best thing it has to throw at the other side, weighed against its own skills
## (ai_plan_attack). Then it steps back out of reach with what movement is left.
const AI_ALCHEMIST_MENDS_BELOW := 0.6

func ai_alchemist(comb: Dictionary):
	for secondary in [false, true]:
		if not still_running() or not comb.alive:
			return
		await _ai_alchemist_act(comb, secondary)
	if still_running() and comb.alive and controller.movement > 0:
		var tile := find_best_reachable_tile(comb, controller.movement, func(t: Vector2i) -> float: return score_tile_safety(t))
		tile = avoid_needless_opportunity_attacks(comb, tile, {})
		if tile != comb.position:
			await controller.ai_move(tile)
	if still_running() and comb.alive and current_combatant == combatants.find(comb):
		await advance_turn()


## One action of the Alchemist's (`secondary`, or its main one): a mend if
## somebody is badly hurt, or else the best throw. True if it did something.
func _ai_alchemist_act(comb: Dictionary, secondary: bool) -> bool:
	if comb.get("secondary_used_this_turn" if secondary else "skill_used_this_turn", false):
		return false
	var patient := find_most_injured_ally(comb)
	if not patient.is_empty() and float(patient.hp) < float(get_effective_stat(patient, "max_hp")) * AI_ALCHEMIST_MENDS_BELOW:
		var mend := _ai_heal_key(comb, patient, controller.movement)
		if mend != "" and (not secondary or ItemDatabase.is_item(mend)):
			var skill: SkillDefinition = SkillDatabase.skills[mend]
			if await move_into_range_of(comb, patient.position, skill, controller.movement, false, patient):
				await use_skill(mend, comb, patient.position, false, secondary)
				return true
	# The best throw - or swing, with the main action - from wherever it can get to.
	var keys := _ai_main_keys(comb)
	if secondary:
		keys = keys.filter(func(key): return ItemDatabase.is_item(key))
	var plan := ai_plan_attack(comb, keys, controller.movement)
	if plan.skill == "":
		return false
	if plan.tile != comb.position:
		await controller.ai_move(plan.tile)
	if not still_running() or not comb.alive:
		return false
	await use_skill(plan.skill, comb, plan.aim, false, secondary)
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


## The glutton's way of fighting (Erysichthon's). Whoever it has hold of it
## means to swallow - its Devour announced, free, for the party to answer.
## Whoever it has caught the scent of (Scented) it lunges for and grabs. Anybody
## else in reach it bites - staying put while it holds anybody, since walking
## off would let them go. With its secondary it catches the scent of somebody
## new, and it eats, free, whatever it ends its move beside ("Gluttony").
const GLUTTON_GRAB := "grab"
const GLUTTON_SCENT := "catch_the_scent"
const SCENTED := preload("res://data/conditions/scented.tres")

func ai_glutton(comb: Dictionary):
	var holding: Array = held_by(comb)
	await _ai_announce_devour(comb, holding)
	if not still_running() or not comb.alive:
		return
	var budget: int = movement_budget_of(comb) if holding.is_empty() else 0
	var acted := false
	if holding.size() < comb.get("holds_at_once", 1) and comb.skill_list.has(GLUTTON_GRAB):
		var prey := _ai_scented_prey(comb)
		var grab: SkillDefinition = SkillDatabase.skills.get(GLUTTON_GRAB)
		if not prey.is_empty() and grab != null and _grip_refusal(comb, grab, prey) == "" \
				and await move_into_range_of(comb, prey.position, grab, budget):
			if still_running() and comb.alive and prey.alive:
				await use_skill(GLUTTON_GRAB, comb, nearest_tile_of(prey, comb.position), false)
				acted = true
				if holder_of(prey).get("id", -2) == comb.get("id", -1):
					await _ai_announce_devour(comb, [prey])
	if not still_running() or not comb.alive:
		return
	if not acted and not comb.get("skill_used_this_turn", false):
		var keys: Array = _ai_main_keys(comb).filter(func(key): return key != GLUTTON_GRAB \
			and not _swallows(SkillDatabase.skills[key]))
		var plan := ai_plan_attack(comb, keys, budget)
		acted = await _ai_carry_out(comb, plan, keys)
		if not acted and held_by(comb).is_empty() and still_running() and comb.alive:
			await approach_with_remaining_movement(comb, _ai_most_wanted(comb, keys))
	if not still_running() or not comb.alive:
		return
	await _ai_catch_scent(comb)
	if still_running() and comb.alive and not combat_over:
		feed(comb)
	if still_running() and comb.alive and not combat_over:
		await advance_turn()


## `comb` announces its Devour (a declared skill that swallows) on the first of
## `holding` it could swallow, if nothing is declared already.
func _ai_announce_devour(comb: Dictionary, holding: Array):
	if comb.has("declared"):
		return
	for key in comb.skill_list:
		var skill: SkillDefinition = SkillDatabase.skills.get(key)
		if skill == null or not skill.declared or not _swallows(skill) \
				or not can_afford_skill(comb, skill) or not meets_level_for(comb, skill):
			continue
		for held in holding:
			if held.alive and refusal_for(comb, skill, held.position) == "":
				await declare(comb, key, held.position)
				return


## The nearest of the other side `comb` has caught the scent of, that it could
## get hold of - or {}.
func _ai_scented_prey(comb: Dictionary) -> Dictionary:
	var best := {}
	for other in combatants:
		if not other.alive or other.get("side", -1) == comb.side or other.has("object") or other.has("riding") \
				or is_hidden(other) or holder_of(other).get("id", -2) == comb.get("id", -1):
			continue
		if not conditions_of(other).has(SCENTED):
			continue
		if best.is_empty() or get_distance(comb, other) < get_distance(comb, best):
			best = other
	return best


## With its secondary, `comb` catches the scent of somebody new - the most hurt
## of the other side it can find - unless somebody already has it on them.
func _ai_catch_scent(comb: Dictionary):
	if comb.get("secondary_used_this_turn", false) or not comb.skill_list.has(GLUTTON_SCENT):
		return
	var skill: SkillDefinition = SkillDatabase.skills.get(GLUTTON_SCENT)
	if skill == null or not meets_level_for(comb, skill):
		return
	var marked := false
	var weakest := {}
	for other in combatants:
		if not other.alive or other.get("side", -1) == comb.side or other.has("object") or other.has("riding") or is_hidden(other):
			continue
		if conditions_of(other).has(SCENTED):
			marked = true
		var share := float(other.hp) / maxf(float(get_effective_stat(other, "max_hp")), 1.0)
		if weakest.is_empty() or share < float(weakest.hp) / maxf(float(get_effective_stat(weakest, "max_hp")), 1.0):
			weakest = other
	if marked or weakest.is_empty() or get_distance(comb, weakest) > effective_max_range(comb, skill):
		return
	await use_skill(GLUTTON_SCENT, comb, nearest_tile_of(weakest, comb.position), false, true)


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
		var heal_skill_key = _ai_heal_key(comb, comb)
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
	# Its own heal, or something healing in its pocket that would mend more
	# (_ai_heal_key) - a healer heals, whichever it heals with.
	var heal_skill_key = _ai_heal_key(comb, find_most_injured_ally(comb))
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
	var rand_num = rng.randf()
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
	# Every attack on the untouchable misses (Illusory Dragon).
	if target.get("untouchable", false) and target.get("side", -1) != attacker.get("side", -2):
		return 0
	return clampi(skill.accuracy + get_effective_stat(attacker, "accuracy"), 0, 100)


## What the log says when `target` beats `attacker` at `skill`'s contest: a grab
## twisted out of, anything else shrugged off the worst of.
func _contest_lost_line(attacker: Dictionary, target: Dictionary, skill: SkillDefinition) -> String:
	if holding_condition(skill) != null:
		return "[color=red]%s[/color] twists out of [color=yellow]%s[/color]'s grab.\n" % [target.name, attacker.name]
	return "[color=red]%s[/color] shrugs off the worst of %s.\n" % [target.name, skill.name]


## Locks the view onto whoever is acting for the length of an AI turn.
##
## Only for the AI. On the player's own turn they are steering the view
## themselves and having it taken away mid-decision is worse than not knowing
## where an enemy is. Silent when this battle has no camera, the same way
## shake_camera is, so nothing depends on there being one.
##
## On the middle of the tiles they stand on - for somebody bigger than a tile,
## not the corner their node is at - and, if they are bigger than the view, the
## view pulls back until they fit (stop_watching brings it in again).
func watch_combatant(comb: Dictionary):
	if camera == null or not is_instance_valid(camera):
		return
	var sprite = comb.get("sprite")
	if sprite != null and is_instance_valid(sprite):
		var shape := footprint(comb)
		camera.follow(sprite, drawing_offset(comb))
		if camera.has_method("fit_in_view"):
			camera.fit_in_view(Vector2(Grid.TILE_SIZE, Grid.TILE_SIZE) * maxi(shape.x, shape.y))


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


## An enemy spawn's pocket: the first `size` (CombatantDefinition.pocket_size) of
## what it lists that are real items and of any use in a fight. The party's
## spawns hand their items to Campaign instead, so theirs stays empty.
func _pocket_from(spawn: SpawnDefinition, size: int = Campaign.COMBAT_SLOTS) -> Array:
	var pocket: Array = []
	if spawn == null or spawn.side == 0:
		return pocket
	for key in spawn.starting_items:
		var item: ItemDefinition = ItemDatabase.item(key) if key != "" else null
		if item == null or item.stealth_only():
			continue
		pocket.append(key)
		if pocket.size() >= size:
			break
	return pocket


## What else an enemy spawn carries, past its pocket: anything of no use in a
## fight - a spellbook, a keepsake - and whatever its pocket of `size` had no room
## for. Never used; there to be looted ("Loot").
func _carried_from(spawn: SpawnDefinition, size: int = Campaign.COMBAT_SLOTS) -> Array:
	var carried: Array = []
	if spawn == null or spawn.side == 0:
		return carried
	var pocketed := _pocket_from(spawn, size)
	for key in spawn.starting_items:
		if key == "" or ItemDatabase.item(key) == null:
			continue
		var at := pocketed.find(key)
		if at != -1:
			pocketed.remove_at(at)
			continue
		carried.append(key)
	return carried


## What `spawn` gives its combatant to wear (SpawnDefinition.equipment): a weapon's
## base, an armour's defence, a charm's passive, over what the spawn says - and
## kept by key, for whoever loots them ("Loot").
func _wear_spawn_equipment(comb: Dictionary, spawn: SpawnDefinition):
	var keys := []
	var worn := []
	if spawn != null:
		for key in spawn.equipment:
			var piece := EquipmentDefinition.named(key)
			if piece == null:
				continue
			keys.append(key)
			worn.append(piece.name)
			match piece.slot:
				EquipmentDefinition.Slot.WEAPON:
					comb.weapon_base = piece.weapon_base
				EquipmentDefinition.Slot.ARMOUR:
					comb.stats["defense"] = piece.defense
				EquipmentDefinition.Slot.CHARM:
					if piece.passive != null and not comb.passives.has(piece.passive):
						comb.passives.append(piece.passive)
	comb["equipment"] = keys
	if not worn.is_empty():
		comb["gear"] = worn


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
	_metric("item", {"who": comb, "item": key})
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


## Whether `comb` is a breakable wall still standing (BattleObjectDefinition
## .wall): a wall in every way - walked round, seen past by nobody, cover - until
## it is knocked down (breaks_wall).
static func is_wall(comb: Dictionary) -> bool:
	return comb.get("alive", false) and comb.has("object") and comb.object.wall


## Why a move does nothing to a breakable wall (refusal_for, the map's own).
const WALL_HOLDS := "Only a spell, an item or Enfina's strength knocks a wall down"


## The co-op player (Coop) who plays `comb`'s turn: whoever steers them, or
## their summoner (Campaign.controllers).
func player_of(comb: Dictionary) -> int:
	var key: String = comb.get("combatant_key", "")
	if comb.has("summoner"):
		var summoner := _combatant_by_id(comb.summoner)
		key = summoner.get("combatant_key", key)
	return Coop.controller_of(key)


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
	drop_readied(comb, "changing sides")
	comb.erase("intent")
	if why != "":
		update_information.emit(why)
	var sprite = comb.get("sprite")
	if sprite != null and is_instance_valid(sprite) and sprite.has_method("refresh_side"):
		sprite.refresh_side(comb.side)
	# The tiles they stand on change colour with them.
	if controller != null:
		controller.queue_redraw()
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
## Made up as they see it (ai_believes).
func plan_intent(comb: Dictionary) -> Dictionary:
	var believed := ai_believes
	ai_believes = true
	_believer_side = comb.get("side", Group.ENEMIES)
	var plan := _plan_intent(comb)
	ai_believes = believed
	return plan


func _plan_intent(comb: Dictionary) -> Dictionary:
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
			"tiles": get_impact_tiles(skill, nearest_from(comb, plan.tile, plan.aim), plan.aim, comb.movement_class, comb.get("size", Sizes.Size.HUMAN), comb),
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
	# Who foresaw it, for when the party changes it (_future_changed).
	intent["read_by"] = reader.get("name", "Alithia")
	intent["reader_id"] = reader.get("id", -1)
	target["intent"] = intent
	update_information.emit("[color=yellow]%s[/color] reads [color=red]%s[/color]: %s.\n" % [reader.name, target.name, intent_text(target)])
	# What their path makes of a reading (PassiveDefinition, Intuition): on the
	# one read, and on whoever of their own side its blow is aimed at.
	var intuition: SkillDefinition = SkillDatabase.skills.get("intuition")
	for passive in active_passives(reader):
		for effect in passive.on_read_effects:
			if effect != null and target.get("alive", false):
				apply_effect(reader, target, effect, intuition, false)
		for ally in foreseen_victims(target):
			for effect in passive.forewarn_effects:
				if effect != null and ally.get("alive", false):
					apply_effect(reader, ally, effect, intuition, false)
	if controller != null:
		controller.queue_redraw()
	update_combatants.emit(combatants)


## Whoever stands where `comb`'s read blow will land (its intent's tiles), of the
## side it means to hurt.
func foreseen_victims(comb: Dictionary) -> Array:
	var tiles: Array = comb.get("intent", {}).get("tiles", [])
	if tiles.is_empty():
		return []
	return combatants.filter(func(other): return other.get("alive", false) and other.side != comb.side \
		and not other.has("object") and tiles_of(other).any(func(tile): return tile in tiles))


## Of foreseen_victims, whoever the read blow would knock out as things stand -
## a death in the vision, marked red (see intent_marks).
func foreseen_doom(comb: Dictionary) -> Array:
	var skill: SkillDefinition = SkillDatabase.skills.get(comb.get("intent", {}).get("skill", ""))
	if skill == null or not skill.deals_damage:
		return []
	return foreseen_victims(comb).filter(func(victim): return predict_hit(comb, victim, skill).lethal)


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
	var said := "%s%s%s" % [skill.name, on, ", after moving to the marked tile" if moving else ", from where they stand"]
	# A death in the vision is said too, as well as marked red.
	var doomed := foreseen_doom(comb)
	if not doomed.is_empty():
		said += " - and it would finish %s" % " and ".join(doomed.map(func(victim): return victim.name))
	return said


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
##
## `doomed` is the tiles of whoever the blow would knock out as things stand
## (foreseen_doom), worked out afresh each time - heal them and the mark goes.
func intent_marks() -> Array:
	var marks := []
	for comb in combatants:
		if comb.get("alive", false) and comb.has("intent"):
			var doomed := []
			for victim in foreseen_doom(comb):
				doomed.append(tiles_of(victim))
			marks.append({"tiles": comb.intent.tiles, "stand": comb.intent.tile, "from": comb.position, "shape": footprint(comb),
				"doomed": doomed})
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
			# The tile it meant to stand on is taken, or out of its reach now.
			_future_changed(comb, intent)
			return false
		await controller.ai_move(intent.tile)
		if not still_running() or not comb.alive:
			return true
		if comb.position != intent.tile:
			# Stopped on the way - grabbed, or somebody came into view.
			_future_changed(comb, intent)
			return false
	if intent.skill != "":
		var skill: SkillDefinition = SkillDatabase.skills.get(intent.skill)
		if skill == null or not can_afford_skill(comb, skill) or comb.get("skill_used_this_turn", false):
			# There, but what it meant to do is beyond it now.
			_future_changed(comb, intent)
			return false
		# Coming as foreseen: whoever was ready for it can answer it (Foreseen Blow).
		comb["acting_foreseen"] = intent
		await use_skill(intent.skill, comb, intent.aim, false)
		comb.erase("acting_foreseen")
	if still_running() and comb.alive:
		await ai_secondary_attack(comb)
		await advance_turn()
	return true


## `comb` cannot do what was read of it, and plans its turn afresh - said in the
## log, naming whoever read it.
##
## And seen to happen: the marks that were read shatter with a sound and a beat
## of frozen time, "Future changed!" rises off them, their face in the turn
## queue cracks until their next turn, and whoever read it says so
## (CombatantDefinition.future_changed_lines). Thwarted till then, the hits of
## anybody whose path rewards it land harder (PassiveDefinition
## thwarted_damage_bonus).
func _future_changed(comb: Dictionary, intent: Dictionary):
	update_information.emit("The party managed to change the future that %s foresaw and the [color=red]%s[/color] is forced to adapt.\n" % [
		intent.get("read_by", "Alithia"), comb.name])
	comb["thwarted"] = true
	if controller != null and controller.has_method("shatter_future"):
		var broken: Array = intent.get("tiles", []).duplicate()
		for dx in footprint(comb).x:
			for dy in footprint(comb).y:
				var stand: Vector2i = intent.get("tile", comb.position) + Vector2i(dx, dy)
				if not broken.has(stand):
					broken.append(stand)
		controller.shatter_future(broken)
	play_stream(future_shatter_sound if future_shatter_sound != null else PlaceholderSounds.make("future_changed"))
	float_number(comb, "Future changed!", FUTURE_COLOUR)
	hit_stop(FUTURE_HIT_STOP)
	var reader := _combatant_by_id(intent.get("reader_id", -1))
	var lines: Array = reader.get("future_changed_lines", [])
	if reader.get("alive", false) and not lines.is_empty():
		var line: String = lines[rng.randi() % lines.size()]
		float_number(reader, line, FUTURE_COLOUR)
		update_information.emit("[color=yellow]%s[/color]: \"%s\"\n" % [reader.name, line])
	update_combatants.emit(combatants)


## --- Hemmed In and Exposed ---
##
## No taunts: nothing forces anybody's aim. A champion holds attention by making
## it costly to ignore. Hemmed In (PassiveDefinition.hems_in): the tiles near it
## cost the other side twice the movement - hard to get past, easy to fight
## (hem_cost, in every walk the controller measures). Exposed (exposes_within,
## exposes_with): whoever of the other side ends a turn near it without having
## hurt it that turn (struck_this_turn) takes more from it until their next turn
## (ConditionDefinition.more_from_source).


## The tiles that cost `mover` twice the movement: those within reach of
## anybody of the other side who hems them in.
func hemmed_tiles(mover: Dictionary) -> Dictionary:
	var tiles := {}
	if mover.is_empty() or not mover.has("side"):
		return tiles
	for other in combatants:
		if not other.get("alive", false) or other.get("side", -1) == mover.side or other.get("illusion", false):
			continue
		var reach := 0
		for passive in active_passives(other):
			reach = maxi(reach, passive.hems_in)
		if reach <= 0:
			continue
		for own in tiles_of(other):
			for dy in range(-reach, reach + 1):
				for dx in range(-reach, reach + 1):
					var tile: Vector2i = own + Vector2i(dx, dy)
					if not tiles.has(tile) and distance_to(other, tile) <= reach:
						tiles[tile] = true
	return tiles


## What each movement point stepping onto `tile` costs `mover`: 2 hemmed in, 1
## otherwise.
func hem_cost(mover: Dictionary, tile: Vector2i) -> int:
	return 2 if hemmed_tiles(mover).has(tile) else 1


## As `comb`'s turn ends: Exposed to anybody of the other side near them they
## did not hurt this turn.
func _expose_at_turn_end(comb: Dictionary):
	if not comb.get("alive", false) or comb.get("illusion", false):
		return
	var struck: Array = comb.get("struck_this_turn", [])
	for other in combatants:
		if not other.get("alive", false) or other.get("side", -1) == comb.get("side", -2) or struck.has(other.get("id", -1)):
			continue
		for passive in active_passives(other):
			if passive.exposes_within <= 0 or passive.exposes_with == null:
				continue
			if distance_to(other, nearest_tile_of(comb, other.position)) > passive.exposes_within:
				continue
			if put_condition(comb, passive.exposes_with, turns_stored(passive.exposes_with.duration, passive.exposes_with.wears_off_at_start, on_whoever_acts(comb)), other.name, true, other.get("id", -1)):
				update_information.emit("[color=yellow]%s[/color] turned from [color=yellow]%s[/color], and is %s.\n" % [comb.name, other.name, passive.exposes_with.display_name.to_lower()])


## Whether `skill` is something that hurts the other side.
func _hostile(skill: SkillDefinition) -> bool:
	return skill != null and not skill.targets_ally and not skill.targets_fallen and skill.deals_damage


## Why `attacker` cannot use `skill` aimed at `impact`, or "" - asked by
## use_skill before anything is spent, and by the controller while aiming, so
## the two always agree.
func refusal_for(attacker: Dictionary, skill: SkillDefinition, impact: Vector2i) -> String:
	if skill == null or attacker.is_empty():
		return ""
	if skill.reaction_only:
		return "%s only goes off as a reaction" % skill.name
	# A standing breakable wall is a wall: nothing is done to it but knocking it
	# down - by a spell, an item, or somebody who Breaks Walls (breaks_wall).
	var aimed_at := get_combatant_at(impact)
	if is_wall(aimed_at) and aoe_radius_of(attacker, skill) == 0:
		if not skill.deals_damage:
			return "That is a wall"
		if not breaks_wall(attacker, skill):
			return WALL_HOLDS
	# Only so often a short rest (Recant, Grand Design, Minefield, Catalyst,
	# Stunning Blow).
	if uses_left(attacker, skill) == 0:
		return "%s is spent until a short rest" % skill.name
	# Only on somebody whose next turn they have read (Accusation, Recant).
	if skill.needs_read:
		var read := get_combatant_at(impact)
		if read.is_empty() or not has_read(attacker, read):
			return "Only on somebody %s has read" % attacker.get("name", "they")
	# A trap goes on bare ground ("Traps"); a field anywhere in reach.
	if sets_traps(skill) and trap_field_of(skill) == 0 and not trap_fits(impact):
		return "A trap needs bare ground"
	# Dispel Magic at bare ground is for a spell's zone on it ("Dispelling").
	if dispels_magic(skill) and get_combatant_at(impact).is_empty() \
			and not zones_at(impact).any(func(zone): return zone.get("gate", 0) > 0):
		return "No spell's work on the ground there to undo"
	# Looting is of a fallen enemy with something on them (see "Loot").
	if loots(skill) and body_to_loot(impact, attacker).is_empty():
		return "Nothing to take there"
	# Rummaging needs something in the pouch and room on the belt (see "Drawing").
	if draws(skill):
		var why := draw_refusal(attacker)
		if why != "":
			return why
	# A leap that has to end in cover (Cover Leap).
	if skill.lands_in_cover and skill.teleports == SkillDefinition.TeleportWho.CASTER and not in_cover(attacker, impact):
		return "No cover there to leap into"
	# Commanding is for one's own summons, once a turn each (see "Summons").
	if commands(skill):
		var summoned := get_combatant_at(impact)
		if summoned.get("summoner", -2) != attacker.get("id", -1) or not summoned.get("alive", false):
			return "Only a summon of %s's can be commanded" % attacker.get("name", "theirs")
		if summoned.get("commanded", false):
			return "%s has had its moment this turn" % summoned.name
		if is_commanding():
			return "One summon at a time"
	# Inside somebody (Swallow): a blow at them, and nothing else.
	if is_inside(attacker):
		var swallower := swallower_of(attacker)
		if skill.targets_ally or skill.aoe_radius > 0 or skill.teleports != SkillDefinition.TeleportWho.NOBODY \
				or not covers(swallower, impact):
			return "Inside %s, there is only %s to hit" % [swallower.get("name", "it"), swallower.get("name", "it")]
	# Aimed at another floor ("Heights"): through a gap in whatever floor is in
	# between, and not along a line or a cone, which run along the one floor.
	# Not for a skill Placed In Reach, aimed at whoever it is of wherever they are.
	if _floored and not skill.placed_in_reach and floor_of(attacker.get("position", impact)) != floor_of(impact):
		if aoe_shape_of(attacker, skill) != SkillDefinition.AoEShape.DIAMOND:
			return "%s reaches along one floor only" % skill.name
		if not floors_open_between(nearest_tile_of(attacker, impact), impact):
			return "The floor is in the way"
	# Swallowing (Devour) is for whoever they have hold of.
	if _swallows(skill):
		var held := get_combatant_at(impact)
		if held.is_empty() or holder_of(held).get("id", -2) != attacker.get("id", -1):
			return "%s has to have hold of them first" % attacker.name
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
	# A move being wound up is hacked only if it is Hackable (or has a hack of its
	# own); a bound creature's binding always can be.
	if _hacks(skill) and _bound_at(impact).is_empty():
		var winding := _winding_up_at(impact)
		var declared: SkillDefinition = SkillDatabase.skills.get(winding.declared.skill) if not winding.is_empty() else null
		if declared != null and not declared.can_be_hacked():
			return "%s's %s can't be hacked" % [winding.name, declared.name]
	if _bribes(skill):
		return _bribe_refusal(target)
	return _invisibility_refusal(skill, target)


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
		and not comb.has("summoner") and not immune_to(comb, Immunity.Kind.BREAKING)


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
	drop_readied(comb, "broken")
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
	# Their tether snaps, and their summons go with them (see "Summons").
	_summoner_gone(comb)
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
	return combatants.filter(func(comb): return comb.get("taken", "") in ["surrendered", "knocked_out"] and not comb.get("eaten", false))


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
## Whether `skill` is a melee move rather than a ranged one (SkillDefinition.melee)
## - the one question anything that favours or hinders melee asks.
static func is_melee(skill: SkillDefinition) -> bool:
	return skill != null and skill.melee


## How far `skill`'s area reaches used by `comb` (its aoe_radius), grown or shrunk
## with them for a melee blow. A blow with an area of its own reaches a tile
## further for every size they are bigger than they began the fight, and a tile
## less for every size smaller - a line or a cone never shorter than one, a blast
## never less than the tile aimed at. A blow at one tile becomes a cone the first
## size bigger (aoe_shape_of), two long - the tile aimed at and the three behind
## it - and a tile longer for every size after; smaller, it is still the one tile.
## A throw, or anything that is not a blow at the other side, keeps its own.
func aoe_radius_of(comb: Dictionary, skill: SkillDefinition) -> int:
	if skill == null:
		return 0
	var grown := _grown_by(comb, skill)
	if grown == 0:
		return skill.aoe_radius
	if skill.aoe_radius == 0:
		return 1 + grown if grown > 0 else 0
	return maxi(skill.aoe_radius + grown, 0 if skill.aoe_shape == SkillDefinition.AoEShape.DIAMOND else 1)


## The shape of `skill`'s area used by `comb`: its own - or a cone, for a blow at
## one tile from somebody grown bigger (aoe_radius_of).
func aoe_shape_of(comb: Dictionary, skill: SkillDefinition) -> int:
	if skill == null:
		return SkillDefinition.AoEShape.DIAMOND
	if skill.aoe_radius == 0 and _grown_by(comb, skill) > 0:
		return SkillDefinition.AoEShape.CONE
	return skill.aoe_shape


## How many sizes bigger (or, below 0, smaller) `comb` is than they began the
## fight, for a skill whose area goes by it (area_grows_with_size) - 0 for the rest.
func _grown_by(comb: Dictionary, skill: SkillDefinition) -> int:
	if comb.is_empty() or not area_grows_with_size(skill):
		return 0
	var size: int = comb.get("size", Sizes.Size.HUMAN)
	return size - comb.get("original_size", size)


## Whether `skill`'s area grows and shrinks with whoever uses it (aoe_radius_of):
## a melee blow that does damage to the other side and is not a throw - with an
## area of its own, or at arm's length (a hook that reaches five tiles is not a swing).
static func area_grows_with_size(skill: SkillDefinition) -> bool:
	return is_melee(skill) and skill.deals_damage and not skill.targets_ally and not skill.targets_fallen \
			and not skill.throws and skill.teleports != SkillDefinition.TeleportWho.TARGET \
			and (skill.aoe_radius > 0 or skill.max_range <= 1)


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
	# Out of somebody (Swallow): what was eating them stops, and they are seen again.
	var was_inside := is_inside(rider)
	var inside_condition = rider.get("inside_condition")
	rider.erase("inside")
	rider.erase("inside_condition")
	rider.erase("digest_left")
	for i in range(rider.status_effects.size() - 1, -1, -1):
		var entry: Dictionary = rider.status_effects[i]
		if entry.get("stat", "") == "condition" and (entry.condition == RIDING \
				or (inside_condition != null and entry.condition == inside_condition)):
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
		if was_inside:
			sprite.visible = true
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
	for rider in climbers_of(mount):
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
		if rng.randi() % 100 < chance:
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
		var inside := is_inside(rider)
		dismount(rider)
		if inside:
			update_information.emit("[color=yellow]%s[/color] claws their way out of [color=red]%s[/color].\n" % [rider.name, mount.name])
		else:
			update_information.emit("[color=yellow]%s[/color] jumps clear of [color=red]%s[/color].\n" % [rider.name, mount.name])


## --- Holding on ---
##
## Grab (Enfina's, and the Barbarian's) puts a condition with Holds ticked on
## somebody beside it - Grappled: they cannot move. It is a reaction too: grabbed
## as they leave the grabber's reach, they are dragged back to the tile they were
## leaving and their walk ends there (check_reactive_skills, CController).
##
## Getting hold is Grab's stat contest (Uses Stat Contest, Physical against
## Physical): it never misses anybody weaker than the grabber, and anybody as
## strong or stronger twists out of it. Breaking free is a roll (grip_chance):
## GRIP_CHANCE of the time against somebody as strong, a point more for every
## point of Physical more than them, within the bounds.
##
## Held, they have Break Free (BREAK_FREE_SKILL, their main action). Whoever
## holds them can walk off with them ("Dragging"). Otherwise the grip lasts until:
## - whoever holds them is not beside them any more (somewhere they could not be
##   dragged after them), is down, gone, or up on somebody (check_holds)
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
	# As many as they can hold at once (holds_at_once); past that, the others go.
	var others: Array = held_by(holder).filter(func(other): return other != held)
	while others.size() > holder.get("holds_at_once", 1) - 1:
		var other: Dictionary = others.pop_front()
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
	var freed := rng.randi() % 100 < chance
	_metric("break_free", {"held": held, "holder": holder, "chance": chance, "freed": freed})
	if freed:
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


## --- Dragging ---
##
## Somebody with hold of somebody else (Grab) who walks takes them along: after
## every step, whoever they hold who is no longer beside them is pulled after
## them (drag_held) - onto the free tile beside them nearest where they were,
## so they trail behind. Every tile walked costs twice its movement while
## dragging (drag_cost), unless whoever is dragged is a size or more smaller.
## Nobody is dragged anywhere they could not stand, nor to another floor: with
## nowhere to go, check_holds lets them go.

## What each tile `mover` walks costs, times: 2 while they drag somebody not a
## size or more smaller than them, 1 otherwise. CController pays steps with it
## and get_reachable_tiles shares the budget out by it.
func drag_cost(mover: Dictionary) -> int:
	var size: int = mover.get("size", Sizes.Size.HUMAN)
	for held in held_by(mover):
		if held.get("size", Sizes.Size.HUMAN) > size - 1:
			return 2
	return 1


## `holder` has taken a step: everybody they hold who is no longer beside them
## is pulled after them. Said in the log if `say`. True if anybody was moved.
func drag_held(holder: Dictionary, say: bool = false) -> bool:
	var dragged := false
	for held in held_by(holder):
		if rect_gap(rect_of(holder), rect_of(held)) <= 1:
			continue
		if _floored and floor_of(holder.position) != floor_of(held.position):
			continue
		var anchor := _drag_to(held, holder)
		if anchor.x == -99999:
			continue
		held.position = anchor
		var sprite = held.get("sprite")
		if sprite != null and is_instance_valid(sprite):
			var slide: Tween = sprite.create_tween()
			slide.tween_property(sprite, "position", sprite_point(held), DRAG_SECONDS)
		if say:
			update_information.emit("[color=yellow]%s[/color] drags [color=red]%s[/color] along.\n" % [holder.name, held.name])
		dragged = true
	return dragged


## How long a dragged body takes to slide after whoever drags them.
const DRAG_SECONDS := 0.2


## Where `held` is pulled to after `holder`: the anchor beside `holder` they fit
## at, nearest where they are now. (-99999, -99999) for nowhere.
func _drag_to(held: Dictionary, holder: Dictionary) -> Vector2i:
	var best := Vector2i(-99999, -99999)
	var nearest := 1 << 30
	var square := rect_of(holder)
	var shape := footprint(held)
	for y in range(square.position.y - shape.y, square.end.y + 1):
		for x in range(square.position.x - shape.x, square.end.x + 1):
			var anchor := Vector2i(x, y)
			var there := rect_of(held, anchor)
			if there.intersects(square) or rect_gap(square, there) > 1:
				continue
			if not room_for(held, anchor):
				continue
			var distance := get_position_distance(anchor, held.position)
			if distance < nearest:
				nearest = distance
				best = anchor
	return best


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


## --- Heights ---
##
## Two kinds of up, on the same rules (README "Heights"):
##   - High ground on a floor: a tile that stops a walker but not a flier and is
##     not see-through (barrels, a low wall - not water; is_high). A walker gets
##     onto it only from a climb tile beside it (climb_tiles: the encounter's
##     Climb Points, and tiles the TileSet marks Climb), walks along it, and
##     steps down off it anywhere. Up there they are "up" (CController keeps it).
##   - Floors (EncounterDefinition.floors): areas of the map that lie one over
##     another (FloorDefinition), each painted where it is. Up the stairs - a
##     climb tile with a floor above it - and down off any edge with open air
##     past it, onto the floor below.
## Up on high ground, they see as a flier does: a low thing between them and
## anybody - one that does not stop a flier - is no cover, either way. Between
## floors a line has to pass every floor in its way through open air, so nobody
## straight underneath, or under the floor beside the one looking, can be seen
## (_sight_between_floors); and range across floors is the distance across plus
## a step for every storey (get_position_distance). CController walks it all
## (_height_steps).

## The encounter's floors, bottom first as written; and every tile to climb from.
var floors: Array = []
var climb_tiles := {}
## Whether there is anything high to get onto here at all, and more than one floor.
var _heights := false
var _floored := false


func _setup_heights():
	floors = encounter.floors.filter(func(floor): return floor != null)
	for tile in encounter.climb_points:
		climb_tiles[tile] = true
	if controller != null and controller.has_method("painted_climb_tiles"):
		for tile in controller.painted_climb_tiles():
			climb_tiles[tile] = true
	_floored = floors.size() > 1
	_heights = _floored or not climb_tiles.is_empty()
	# Whoever starts up on high ground is up from the start.
	if _heights and controller != null:
		controller.refresh_occupancy()


## Whether this map has anything high to get onto.
func heights_in_play() -> bool:
	return _heights


## Which of the floors `tile` is on, by index - or -1, on a map of one floor.
func floor_of(tile: Vector2i) -> int:
	if not _floored:
		return -1
	for i in floors.size():
		if floors[i].region.has_point(tile):
			return i
	return -1


## How high `tile`'s floor is: 0 for the bottom one, and for a map of one floor.
func floor_level(tile: Vector2i) -> int:
	var i := floor_of(tile)
	return floors[i].level if i >= 0 else 0


## Where `tile` lies over the bottom floor, in its tiles - the same tile on a map
## of one floor.
func real_of(tile: Vector2i) -> Vector2i:
	var i := floor_of(tile)
	if i < 0:
		return tile
	return tile - floors[i].region.position + floors[i].over


## The tile of floor `index` that lies over `real` - (-99999, -99999) where the
## floor's Region does not reach.
func tile_on(index: int, real: Vector2i) -> Vector2i:
	if index < 0 or index >= floors.size():
		return Vector2i(-99999, -99999)
	var tile: Vector2i = real - floors[index].over + floors[index].region.position
	return tile if floors[index].region.has_point(tile) else Vector2i(-99999, -99999)


## The floor a storey above (`by` 1) or below (-1) floor `index`, or -1.
func floor_beside(index: int, by: int) -> int:
	if index < 0:
		return -1
	for i in floors.size():
		if floors[i].level == floors[index].level + by:
			return i
	return -1


## Whether `tile` is high ground: stops a walker, not a flier, and not see-through.
func is_high(tile: Vector2i) -> bool:
	if controller == null or not controller.is_on_map(tile):
		return false
	return controller.is_tile_blocking(tile, 0) and not controller.is_tile_blocking(tile, 1) \
		and controller.terrain_blocks_sight(tile, 0)


## How raised `comb` is: up on high ground counts one, and every size above Human
## one more - somebody bigger than the barrels is as good as up on them. Raised at
## all, they see over anything low and get no cover from it.
static func elevation(comb: Dictionary) -> int:
	if comb.has("object") or comb.has("riding"):
		return 0
	return (1 if comb.get("up", false) else 0) + maxi(comb.get("size", Sizes.Size.HUMAN) - Sizes.Size.HUMAN, 0)


## Whether something of `size`, walking, steps over high ground rather than
## climbing onto it: anything Large or bigger - the barrels come to its knees.
static func steps_over_size(size: int, movement_class: int) -> bool:
	return size >= Sizes.Size.LARGE and movement_class != 1


## Whether `tile` stops `comb` standing there: what stops their movement class -
## save high ground, for anybody big enough to step over it.
func blocks_for(comb: Dictionary, tile: Vector2i, size: int = -1) -> bool:
	if size < 0:
		size = comb.get("size", Sizes.Size.HUMAN)
	if not controller.is_tile_blocking(tile, terrain_class(comb)):
		return false
	return not (steps_over_size(size, comb.get("movement_class", 0)) and is_high(tile))


## Whether a target at `tile` is hidden by the very ground they stand on - which
## nobody raised (up on it, or big enough to stand over it) is.
func _aim_blocked(tile: Vector2i, movement_class: int) -> bool:
	return controller.terrain_blocks_sight(tile, movement_class) and controller.raised_at(tile) <= 0


## The tile of `comb`'s nearest `tile`: nearest_tile_of on one floor, and from
## another floor the one of theirs over or under the nearest point of them.
func nearest_across(comb: Dictionary, tile: Vector2i) -> Vector2i:
	var here := floor_of(comb.get("position", tile))
	if not _floored or here < 0 or floor_of(tile) == here:
		return nearest_tile_of(comb, tile)
	var corner := real_of(comb.position)
	var real := real_of(tile)
	var shape := footprint(comb)
	var near := Vector2i(clampi(real.x, corner.x, corner.x + shape.x - 1), clampi(real.y, corner.y, corner.y + shape.y - 1))
	var found := tile_on(here, near)
	return found if found.x != -99999 else nearest_tile_of(comb, tile)


## How far apart a reaction reckons `reactor` and `other` (standing at `at`, or
## where they are) for `skill`: rect_gap on one floor. Across floors, the ground
## between their nearest tiles with the storeys between added on, as
## get_position_distance has it - for anything that reaches through a gap in the
## floor. A melee blow keeps to its own floor: out of reach.
func reach_gap(reactor: Dictionary, other: Dictionary, skill: SkillDefinition, at = null) -> int:
	var where: Vector2i = at if at != null else other.get("position", Vector2i.ZERO)
	if not _floored or floor_of(reactor.position) == floor_of(where):
		return rect_gap(rect_of(reactor), rect_of(other, where))
	if is_melee(skill):
		return OUT_OF_REACH
	var mine := Rect2i(real_of(reactor.position), footprint(reactor))
	var theirs := Rect2i(real_of(where), footprint(other))
	return rect_gap(mine, theirs) + absi(floor_level(reactor.position) - floor_level(where))


## Further than anything reaches.
const OUT_OF_REACH := 1 << 20


## Whether `reactor` can get `skill` at `other` (standing at `at`, or where they
## are) through the floors between them - always, on one floor (floors_open_between).
func _reaches_through_floors(reactor: Dictionary, other: Dictionary, at = null) -> bool:
	if not _floored:
		return true
	var where: Vector2i = at if at != null else other.get("position", Vector2i.ZERO)
	if floor_of(reactor.position) == floor_of(where):
		return true
	var body: Dictionary = other if at == null else _standing_at(other, where)
	var theirs := nearest_across(body, reactor.position)
	return floors_open_between(nearest_across(reactor, theirs), theirs)


## `comb` as they would be standing at `anchor` - a copy, for asking about it.
static func _standing_at(comb: Dictionary, anchor: Vector2i) -> Dictionary:
	var body := {"position": anchor, "span": comb.get("span", 1)}
	if comb.has("fold"):
		body.fold = comb.fold
	return body


## Whether a line from `a` down (or up) to `b` gets through every floor between
## them: looked at from the higher end, the floor of each storey it drops through
## must be open air at the point it drops through it. Always, for two tiles on
## one floor. Even a lob has to come down through a gap - no skill goes through a
## floor - so this is asked of everything aimed across floors, and the rest of
## a line of sight (_sight_between_floors) of what needs one.
func floors_open_between(a: Vector2i, b: Vector2i) -> bool:
	if not _floored or floor_of(a) == floor_of(b):
		return true
	return _floors_crossed_open(a, b, _eye_height(a), _eye_height(b))


## Whether a line from an eye at `a` (`ea` storeys up) to one at `b` (`eb`) gets
## through every floor whose level lies between the two: through open air at the
## point it crosses it. Somebody tall enough below sees over a floor's edge, and
## is seen; nobody sees through the floor itself - from either side, whoever is
## at the ends, however big. Worked out from one end whichever asks, so both get
## the same answer (_walked_from_b).
func _floors_crossed_open(a: Vector2i, b: Vector2i, ea: float, eb: float) -> bool:
	if _walked_from_b(a, b):
		var swap := a
		a = b
		b = swap
		var was := ea
		ea = eb
		eb = was
	var cells := _real_line(real_of(a), real_of(b))
	var steps := cells.size() - 1
	for storey in range(ceili(minf(ea, eb)), floori(maxf(ea, eb)) + 1):
		var at := float(storey)
		if (ea - at) * (eb - at) >= 0.0:
			continue
		var index := _floor_at_level(storey)
		if index < 0:
			continue
		if steps <= 0:
			# Straight underneath: the floor is in the way.
			return false
		# The line goes through this storey's floor this far along it.
		var along := (ea - at) / (ea - eb)
		var k := clampi(ceili(along * steps), 1, steps)
		var through := tile_on(index, cells[k])
		if through.x != -99999 and controller.is_on_map(through):
			return false
	return true


## Whether a line between `a` and `b` is walked from `b`'s end: the one on the
## higher floor, or on one floor the lesser tile, as has_line_of_sight walks.
func _walked_from_b(a: Vector2i, b: Vector2i) -> bool:
	var high_a := floor_level(a)
	var high_b := floor_level(b)
	if high_a != high_b:
		return high_b > high_a
	return b.x < a.x or (b.x == a.x and b.y < a.y)


## How high, in storeys, whoever stands at `tile` looks from - and can be seen
## at: half a storey above their floor, and a storey more for every step they
## are raised (elevation: up on high ground, or bigger than a Human - `raise` at
## least, for a viewer of a size asked about where nobody stands yet). Never up
## through a floor over their head, though.
func _eye_height(tile: Vector2i, raise: int = 0) -> float:
	var raised: int = maxi(controller.raised_at(tile), raise)
	if raised > 0:
		var over := tile_on(floor_beside(floor_of(tile), 1), real_of(tile))
		if over.x != -99999 and controller.is_on_map(over):
			raised = 0
	return float(floor_level(tile)) + 0.5 + float(raised)


## Whether a line from `a` to `b` is clear by the floors' rules (has_line_of_sight
## hands it here between floors, and on one floor with somebody raised at either
## end under a floor above): through every floor it crosses (_floors_crossed_open),
## and no wall on the way at the height it is at - nothing low counts, the line
## runs over it.
func _sight_between_floors(a: Vector2i, b: Vector2i, viewer_size: int, looking_at: Dictionary) -> bool:
	var ea := _eye_height(a, maxi(viewer_size - Sizes.Size.HUMAN, 0))
	var eb := _eye_height(b)
	if not _floors_crossed_open(a, b, ea, eb):
		return false
	var one_floor := floor_of(a) == floor_of(b)
	if _walked_from_b(a, b):
		var swap := a
		a = b
		b = swap
		var was := ea
		ea = eb
		eb = was
	var bottom := mini(floor_level(a), floor_level(b))
	var top := maxi(maxi(floor_level(a), floor_level(b)), floori(maxf(ea, eb)))
	var cells := _real_line(real_of(a), real_of(b))
	var steps := cells.size() - 1
	for k in range(1, steps):
		var height := ea + (eb - ea) * float(k) / float(steps)
		var storey := clampi(floori(height), bottom, top)
		var on := tile_on(_floor_at_level(storey), cells[k])
		# Open air on a floor above the lowest the line reaches: nothing to stop
		# it. Off the edge of the lowest is off the map - on one floor, whatever a
		# hole in it is to anybody's sight.
		if on.x == -99999 or not controller.is_on_map(on):
			if storey > bottom:
				continue
			if not one_floor:
				return false
		if controller.blocks_line_of_sight(on, 1, viewer_size, looking_at):
			return false
	return true


## `mover`'s step from `from` to `to`, said if it took them up or down - onto
## high ground or off it (`was_up` whether they were up before), or between floors.
func note_height_step(mover: Dictionary, from: Vector2i, to: Vector2i, was_up: bool):
	var before := floor_of(from)
	var after := floor_of(to)
	if before != after and after >= 0:
		var called: String = floors[after].name if floors[after].name != "" else "the floor %s" % ("above" if floor_level(to) > floor_level(from) else "below")
		update_information.emit("[color=yellow]%s[/color] %s to %s.\n" % [mover.name,
			"climbs up" if floor_level(to) > floor_level(from) else "drops down", called])
	elif mover.get("up", false) != was_up:
		update_information.emit("[color=yellow]%s[/color] %s.\n" % [mover.name, "climbs up" if mover.get("up", false) else "steps down"])


## The floor whose level is `level`, or -1.
func _floor_at_level(level: int) -> int:
	for i in floors.size():
		if floors[i].level == level:
			return i
	return -1


## The tiles of a straight line from `from` to `to`, both ends included - the
## same walk has_line_of_sight takes.
static func _real_line(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [from]
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
		cells.append(Vector2i(x, y))
	return cells


## --- Growing ---
##
## Somebody's size can change in the middle of a fight (Sizes): a size bigger
## while Growth (EffectType.GROW) holds on them, or for good as a boss's phase
## begins (BossPhase.grows - bigger with the parts it grows). Bigger, they cover
## a square with their tile as its corner - or, if that is not free, the nearest
## square that holds their tile and is; no room anywhere, and they do not grow.
## They are drawn bigger, and their body parts stretch with them. Their size is
## worked out afresh from what is on them whenever that changes (resync_size),
## so Growth wearing off shrinks them back into the corner they grew from, and a
## boss with no room to grow into grows the moment there is some.

## The size `comb` should be: their own (base_size), and every Growth on them.
func size_wanted(comb: Dictionary) -> int:
	var size: int = comb.get("base_size", comb.get("size", Sizes.Size.HUMAN))
	for eff in comb.get("status_effects", []):
		if eff.get("stat", "") == "size":
			size += int(eff.get("amount", 0))
	return clampi(size, Sizes.Size.TINY, Sizes.Size.GIGANTIC)


## Puts `comb` at the size they should be (size_wanted), if there is room.
func resync_size(comb: Dictionary):
	if not comb.get("alive", false) or comb.has("object"):
		return
	var wanted := size_wanted(comb)
	if wanted != comb.get("size", Sizes.Size.HUMAN):
		resize(comb, wanted)
	# Somebody squeezed in stays folded until there is room where they are.
	if can_squeeze(comb):
		fit_to_room(comb)


## The anchor `comb` would stand at grown to `size`: their own tile as the
## corner, or the nearest square holding it that is free. (-99999, -99999) for
## nowhere.
func _room_to_grow(comb: Dictionary, size: int) -> Vector2i:
	var was_size: int = comb.size
	var was_span: int = comb.get("span", 1)
	var was_fold = comb.get("fold")
	var span := Sizes.span(size, comb.get("gigantic_span", 16))
	comb.size = size
	comb.span = span
	comb.erase("fold")
	var best := Vector2i(-99999, -99999)
	var best_shift := 999
	for dy in range(-(span - 1), 1):
		for dx in range(-(span - 1), 1):
			var anchor: Vector2i = comb.position + Vector2i(dx, dy)
			var shift := absi(dx) + absi(dy)
			if shift < best_shift and room_for(comb, anchor):
				best = anchor
				best_shift = shift
	comb.size = was_size
	comb.span = was_span
	if was_fold != null:
		comb.fold = was_fold
	return best


## `comb` grown or shrunk to `size` - said in the log unless `quiet`. False, and
## nothing changed, with no room.
func resize(comb: Dictionary, size: int, quiet: bool = false) -> bool:
	if comb.has("riding") or comb.has("object"):
		return false
	var old_span: int = comb.get("span", 1)
	var span := Sizes.span(size, comb.get("gigantic_span", 16))
	var anchor: Vector2i = comb.position
	# Folded (Squeezing), it needs its whole new square free, grown or not.
	if span > old_span or comb.has("fold") or (Sizes.shares(comb.size) and not Sizes.shares(size)):
		anchor = _room_to_grow(comb, size)
		if anchor.x == -99999:
			return false
	var bigger: bool = size > comb.size
	comb.size = size
	comb.span = span
	comb.erase("fold")
	comb.erase("squeezed")
	_stretch_parts(comb, old_span, span)
	var from: Vector2i = comb.position
	comb.position = anchor
	var sprite = comb.get("sprite")
	if sprite != null and is_instance_valid(sprite):
		sprite.scale = drawn_scale(comb)
		# Onto the new anchor - grown up or left of where they stood, the drawing
		# was put over the middle of a square starting where they used to be,
		# half a tile and more below and beside the one they cover.
		sprite.position = sprite_point(comb)
	if controller != null:
		controller.reposition_combatant(from, anchor)
	check_holds()
	float_number(comb, "Bigger!" if bigger else "Smaller", Color("9fe0a0") if bigger else Color("c0c0c0"))
	if not quiet:
		update_information.emit("[color=yellow]%s[/color] %s - %s now.\n" % [comb.name, "grows" if bigger else "shrinks back", Sizes.name_of(size)])
	update_combatants.emit(combatants)
	return true


## `comb`'s parts stretched (or shrunk) from a square `old_span` a side to one
## `new_span`: each tile of a part becomes the block of tiles it now spans. Each
## part is their own copy from then on, so nobody else of their kind changes.
func _stretch_parts(comb: Dictionary, old_span: int, new_span: int):
	if old_span == new_span or comb.get("parts", []).is_empty():
		return
	for i in comb.parts.size():
		var part: BodyPartDefinition = comb.parts[i].duplicate()
		var tiles: Array[Vector2i] = []
		for tile in part.tiles:
			if new_span > old_span:
				var by := new_span / old_span
				for dy in by:
					for dx in by:
						tiles.append(tile * by + Vector2i(dx, dy))
			else:
				var shrunk: Vector2i = tile / (old_span / new_span)
				if not tiles.has(shrunk):
					tiles.append(shrunk)
		part.tiles = tiles
		comb.parts[i] = part


## `attacker`'s Growth (EffectType.GROW) on `target`: a size bigger, for the
## effect's duration (0, the rest of the fight) - if there is room for it.
func grow(attacker: Dictionary, target: Dictionary, effect: EffectDefinition, skill: SkillDefinition, mention_skill: bool):
	if target.has("object") or target.get("illusion", false):
		return
	var size := size_wanted(target) + 1
	if size > Sizes.Size.GIGANTIC:
		update_information.emit("[color=yellow]%s[/color] can grow no bigger.\n" % target.name)
		return
	var entry := {
		"stat" = "size",
		"op" = "add",
		"amount" = 1,
		"duration" = stored_duration(target, effect) if effect.duration > 0 else 999,
		"ends_at_start" = effect.wears_off_at_start,
		"source_name" = attacker.name,
	}
	target.status_effects.append(entry)
	if not resize(target, size, true):
		target.status_effects.erase(entry)
		update_information.emit("There is no room for [color=yellow]%s[/color] to grow.\n" % target.name)
		return
	update_information.emit(describe_condition(attacker, target, effect, skill, mention_skill, "a size bigger"))


## --- Progression ---
##
## The switches docs/progression.csv's passives are made of (PassiveDefinition
## "Taking less", "Hitting harder", "Lingering", "Contests", "Gates", "Cover",
## and Healing's Heals Lift / Heals Leave; ConditionDefinition's Damage Taken
## Change and Mends Share). Each is read where its kind of thing is worked out:
## damage_taken_multiplier, damage_dealt_multiplier, wins_contest, the CONDITION
## and DAMAGE_OVER_TIME branches, do_heal, the turn's start, passive_stat_bonus,
## check_reactive_skills - so the aim prompt and the hit agree.

## Whether `comb` - standing at `anchor`, or where they are - is in cover: beside
## something that blocks sight.
func in_cover(comb: Dictionary, anchor = null) -> bool:
	if controller == null or not comb.has("position"):
		return false
	var at: Vector2i = anchor if anchor != null else comb.position
	var own := tiles_of(comb, at)
	for tile in own:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var beside: Vector2i = tile + Vector2i(dx, dy)
				if beside in own or not controller.is_on_map(beside):
					continue
				if controller.terrain_blocks_sight(beside, 0):
					return true
				# Something on the map blocks sight like a body - a keg; or cover
				# that is not there at all (Illusory Cover), in the mind of the
				# side it fools only (believes_illusion).
				if combatants_at(beside).any(func(thing): return thing.has("object") and thing.get("alive", false) \
						and (not thing.get("illusion", false) or believes_illusion(thing))):
					return true
	return false


## Whether `condition` does damage over time.
static func _lingers(condition: ConditionDefinition) -> bool:
	return condition != null and (condition.dot_modifier > 0.0 or condition.dot_max > 0)


## Whether a status entry is something its bearer would rather not have.
static func _harmful(entry: Dictionary) -> bool:
	match entry.get("stat", ""):
		"dot":
			return true
		"condition":
			var condition: ConditionDefinition = entry.get("condition")
			if condition == null:
				return false
			return _lingers(condition) or condition.skips_turn or condition.prevents_movement or condition.prevents_secondary \
				or condition.prevents_reactions or condition.prevents_approach or condition.confuses or condition.more_from_source > 0.0 \
				or condition.holds or condition.movement_change < 0 or condition.accuracy_change < 0 or condition.damage_taken_change > 0.0 \
				or condition.defense_change < 0.0
		"element_up", "movement_class", "size":
			return false
	if entry.get("op", "add") == "multiply":
		return entry.get("amount", 1.0) < 1.0
	return entry.get("amount", 0) < 0


## Whether `comb` carries anything harmful on them.
func is_afflicted(comb: Dictionary) -> bool:
	return comb.get("status_effects", []).any(func(entry): return _harmful(entry))


## Whether `comb` is taking damage over time.
func has_lingering(comb: Dictionary) -> bool:
	return comb.get("status_effects", []).any(func(entry):
		return entry.get("stat", "") == "dot" or (entry.get("stat", "") == "condition" and _lingers(entry.get("condition"))))


## Whether `comb` carries something harmful `by` put on them.
func _afflicted_by(comb: Dictionary, by: Dictionary) -> bool:
	return comb.get("status_effects", []).any(func(entry): return _harmful(entry) and entry.get("source_id", -2) == by.get("id", -1))


## The share less `target` takes of a hit - more, below 0: their passives, in
## cover too; their conditions; and anybody of their side who shields them all.
func damage_reduction_of(target: Dictionary) -> float:
	if not target.has("status_effects"):
		return 0.0
	var reduction := 0.0
	for passive in active_passives(target):
		reduction += passive.damage_reduction
		if passive.damage_reduction_in_cover > 0.0 and in_cover(target):
			reduction += passive.damage_reduction_in_cover
	for entry in target.status_effects:
		var condition = entry.get("condition") if entry.get("stat", "") == "condition" else null
		if condition != null:
			reduction -= condition.damage_taken_change
	for ally in combatants:
		if not ally.get("alive", false) or ally.get("side", -1) != target.get("side", -2) or ally.get("illusion", false):
			continue
		for passive in active_passives(ally):
			reduction += passive.party_damage_reduction
	return clampf(reduction, -1.0, 0.9)


## How much harder `attacker`'s hits land on `target`: on a turn not walked;
## on anybody weak to the element, or taking lingering damage; and, from
## anybody of their side with Synergy, on anybody afflicted.
func progression_damage_bonus(attacker: Dictionary, target: Dictionary, skill: SkillDefinition) -> float:
	var bonus := 0.0
	var kindling := 0.0
	var kindling_most := 0.0
	for passive in active_passives(attacker):
		kindling += passive.kindling_step
		kindling_most += passive.kindling_most
		if passive.still_damage_bonus > 0.0 and not attacker.get("moved_this_turn", false):
			bonus += passive.still_damage_bonus
		if passive.bonus_vs_weak > 0.0 and skill != null \
				and target.get("resistances", {}).get(effective_damage_type(attacker, skill.damage_type), 0) < 0:
			bonus += passive.bonus_vs_weak
		if passive.bonus_vs_lingering > 0.0 and has_lingering(target):
			bonus += passive.bonus_vs_lingering
	# Every spell cast this fight so far makes this one hotter, up to the most.
	if kindling > 0.0 and is_spell(skill):
		bonus += minf(kindling * attacker.get("spells_cast", 0), kindling_most)
	# Exposed to them, and to nobody else.
	for entry in target.get("status_effects", []):
		var condition = entry.get("condition") if entry.get("stat", "") == "condition" else null
		if condition != null and condition.more_from_source > 0.0 and entry.get("source_id", -2) == attacker.get("id", -1):
			bonus += condition.more_from_source
	if target.has("status_effects") and not target.status_effects.is_empty():
		for ally in combatants:
			if not ally.get("alive", false) or ally.get("side", -1) != attacker.get("side", -2) or ally.get("illusion", false):
				continue
			for passive in active_passives(ally):
				if passive.party_bonus_vs_afflicted > 0.0 and is_afflicted(target):
					bonus += passive.party_bonus_vs_afflicted
				if passive.party_bonus_vs_own > 0.0 and _afflicted_by(target, ally):
					bonus += passive.party_bonus_vs_own
	# The paths' (see "The paths").
	bonus += _path_hit_bonus(attacker, target, skill)
	return maxf(1.0 + bonus, 0.0)


## What `attacker` adds to their stat in a contest with `target`.
func contest_bonus_of(attacker: Dictionary, target: Dictionary) -> int:
	var bonus := 0
	for passive in active_passives(attacker):
		bonus += passive.contest_bonus
		if passive.contest_bonus_vs_afflicted > 0 and is_afflicted(target):
			bonus += passive.contest_bonus_vs_afflicted
	return bonus


## How much harder `attacker`'s lingering damage burns, as a multiplier.
func lingering_bonus(attacker: Dictionary) -> float:
	var bonus := 1.0
	for passive in active_passives(attacker):
		bonus += passive.dot_bonus
	return bonus


## How many turns longer `attacker`'s lingering damage lasts.
func lingering_turns(attacker: Dictionary) -> int:
	var turns := 0
	for passive in active_passives(attacker):
		turns += passive.dot_extra_turns
	return turns


## What `healer`'s heal does besides mending `target`: harmful conditions
## lifted (Heals Lift), and a condition left on them (Heals Leave).
func _after_heal(healer: Dictionary, target: Dictionary):
	var lifting := 0
	var leaving: Array = []
	for passive in active_passives(healer):
		lifting += passive.heals_lift
		if passive.heals_leave != null:
			leaving.append(passive.heals_leave)
	if lifting > 0:
		var was_held := has_restriction(target, "prevents_movement")
		var movement_before: int = get_effective_stat(target, "movement") if target.has("movement") else 0
		var lifted := []
		# What the player chose first (_choose_lifts), then the most recent.
		for entry in _lift_picks.duplicate():
			if lifted.size() >= lifting:
				break
			var at := _effect_index(target, entry)
			if at >= 0 and _harmful(entry):
				target.status_effects.remove_at(at)
				_lift_picks.erase(entry)
				lifted.append(lifted_name(entry))
		for i in range(target.status_effects.size() - 1, -1, -1):
			if lifted.size() >= lifting:
				break
			var entry: Dictionary = target.status_effects[i]
			if _harmful(entry):
				target.status_effects.remove_at(i)
				lifted.append(lifted_name(entry))
		if not lifted.is_empty():
			resync_movement_class(target)
			if target.has("movement"):
				_movement_after_lift(target, was_held, movement_before)
			update_information.emit("[color=yellow]%s[/color]'s heal lifts %s from [color=lightgreen]%s[/color].\n" % [
				healer.name, ", ".join(lifted), target.name])
	for condition in leaving:
		put_condition(target, condition, turns_stored(condition.duration, condition.wears_off_at_start, on_whoever_acts(target)), healer.name, true, healer.get("id", -1))
	# A shield of light left with it, for so many of their turns (Veil of Mercy III),
	# and a phantom guiding them on (Guiding Phantasm).
	for passive in active_passives(healer):
		if passive.heals_spur > 0 and target.get("alive", false):
			var spur := EffectDefinition.new()
			spur.type = EffectDefinition.EffectType.STAT_MODIFIER
			spur.stat = "movement"
			spur.modifier_amount = passive.heals_spur
			spur.duration = 1
			spur.display_name = "Guided"
			apply_effect(healer, target, spur, null, false)
		if passive.heals_shield > 0.0 and target.get("alive", false):
			overheal(target, roundi(get_effective_stat(target, "max_hp") * passive.heals_shield), healer)
			if passive.heals_shield_turns > 0:
				target["temp_hp_turns"] = passive.heals_shield_turns


## As `comb`'s turn starts, whatever on them mends a share of their health
## does (ConditionDefinition.mends_share - Alithia's Aura II).
func _mend_at_turn_start(comb: Dictionary):
	var share := 0.0
	for entry in comb.get("status_effects", []):
		var condition = entry.get("condition") if entry.get("stat", "") == "condition" else null
		if condition != null:
			share += condition.mends_share
	if share <= 0.0 or not comb.get("alive", false):
		return
	var most := get_effective_stat(comb, "max_hp")
	var amount := mini(roundi(most * share), most - comb.hp)
	if amount <= 0:
		return
	comb.hp += amount
	float_number(comb, "+" + str(amount), Color("7fe08a"))
	update_information.emit("[color=lightgreen]%s[/color] mends %d.\n" % [comb.name, amount])
	update_combatants.emit(combatants)


## More castings through the deepest gate open to `comb`, as their passives say
## (Extra Deepest Castings - Reserved Power, Elemental Mastery). Safe to call
## again: what was added before is not added twice.
func add_deepest_castings(comb: Dictionary):
	var wanted := 0
	for passive in active_passives(comb):
		wanted += passive.extra_deepest_castings
	var more: int = wanted - comb.get("deepest_castings_added", 0)
	var most: Array = comb.get("max_spell_slots", [])
	if more <= 0 or most.is_empty():
		return
	for gate in range(most.size() - 1, 0, -1):
		if most[gate] > 0:
			most[gate] += more
			comb.spell_slots[gate] += more
			comb["deepest_castings_added"] = wanted
			return


## --- The paths ---
##
## What the twelve paths (data/subclasses, chosen at Stats.SUBCLASS_LEVEL) ask of
## a fight beyond the progression's switches - each a switch on PassiveDefinition
## ("Paths") or ConditionDefinition ("Illusions and favours"), read here:
## - Hitting harder (_path_hit_bonus, inside progression_damage_bonus): after a
##   charge, flanking, the first hit on each enemy, a repeated Rapier, on the read
##   or the trapped, a skill of their own (Avatar), a change of element
##   (Resonance), near a Crusader; less from afar on the Blurred.
## - What a hit does besides (_after_landing): Titanfall's and Tremor's splash
##   (_splash), Overload, Spellstrike.
## - Missing (_evades, after the hit roll): Illusory Guardian, Phantom Body,
##   Afterimage, a copy taking it (miss_chance).
## - Staying up: Last Wall (_last_wall), Hold the Line (_line_held), Unstoppable.
## - After the use (_use_skill): Covering Stance, Chain, Conduit, Righteous, an
##   action given back (action_back: Rampage, Grand Design).
## - As a turn starts (_paths_at_turn_start): what counts per turn and per round,
##   Contagion, a shield wearing off, cover that was never there fading.
## Traps and Catalyst have sections of their own.


## Whether nothing lowers `comb`'s movement or stops them walking (Unstoppable).
func unstoppable(comb: Dictionary) -> bool:
	return comb.has("passives") and active_passives(comb).any(func(passive): return passive.unstoppable)


## Whether `a` and `b` stand beside one another - the eight tiles round, between
## their nearest tiles.
func _beside(a: Dictionary, b: Dictionary) -> bool:
	if not a.has("position") or not b.has("position"):
		return false
	var mine := nearest_tile_of(a, b.position)
	var theirs := nearest_tile_of(b, mine)
	return maxi(absi(mine.x - theirs.x), absi(mine.y - theirs.y)) == 1


## Whether `reader` has read `target`'s next turn (Intuition), and it has not
## come yet.
func has_read(reader: Dictionary, target: Dictionary) -> bool:
	return target.has("intent") and target.intent.get("reader_id", -2) == reader.get("id", -1)


## Whether `target` stands beside one of `attacker`'s side - flanked (Flanker).
func _flanked(attacker: Dictionary, target: Dictionary) -> bool:
	for ally in combatants:
		if ally == attacker or not ally.get("alive", false) or ally.get("side", -1) != attacker.get("side", -2) \
				or ally.has("object") or ally.get("illusion", false):
			continue
		if _beside(ally, target):
			return true
	return false


## How much harder the paths make `attacker`'s hit on `target` with `skill`, on
## top of 1 - see progression_damage_bonus.
func _path_hit_bonus(attacker: Dictionary, target: Dictionary, skill: SkillDefinition) -> float:
	var bonus := 0.0
	if skill == null or not attacker.has("passives"):
		return bonus
	var key := skill_key_of(skill)
	var foe: bool = target.get("side", -1) != attacker.get("side", -1)
	for passive in active_passives(attacker):
		if passive.charge_bonus > 0.0 and attacker.get("walked_this_turn", 0) >= passive.charge_tiles \
				and not attacker.get("charge_spent", false):
			bonus += passive.charge_bonus
		if passive.flanking_bonus > 0.0 and foe and (passive.flanking_skills.is_empty() or passive.flanking_skills.has(key)) \
				and _flanked(attacker, target):
			bonus += passive.flanking_bonus
		if passive.opener_bonus > 0.0 and foe and not attacker.get("opened_on", []).has(target.get("id", -1)):
			bonus += passive.opener_bonus
		if passive.repeat_bonus > 0.0 and passive.repeat_skills.has(key) and attacker.get("repeat_hits", {}).get(key, 0) >= 1:
			bonus += passive.repeat_bonus
		if passive.bonus_vs_read > 0.0 and foe and has_read(attacker, target):
			bonus += passive.bonus_vs_read
		if passive.bonus_vs_trapped > 0.0 and foe and _trapped_by(target, attacker):
			bonus += passive.bonus_vs_trapped
		if passive.skill_bonuses.has(key):
			bonus += float(passive.skill_bonuses[key])
		if passive.resonance > 0.0 and is_spell(skill) and attacker.has("last_spell_element") \
				and attacker.last_spell_element != effective_damage_type(attacker, skill.damage_type):
			bonus += passive.resonance
	# Near a Crusader of their side (Crusade).
	for ally in combatants:
		if ally == attacker or not ally.get("alive", false) or ally.get("side", -1) != attacker.get("side", -2) \
				or ally.get("illusion", false) or not ally.has("position") or not attacker.has("position"):
			continue
		for passive in active_passives(ally):
			if passive.crusade_bonus > 0.0 and get_position_distance(ally.position, attacker.position) <= passive.crusade_reach:
				bonus += passive.crusade_bonus
	# Blurred (Veil of Mercy II): less from anybody more than a tile away.
	if foe and attacker.has("position") and target.has("position") and not _beside(attacker, target):
		var blur := 0.0
		for condition in conditions_of(target):
			blur = maxf(blur, condition.less_from_afar)
		bonus -= blur
	return bonus


## What `attacker`'s use just did, for what counts per turn and per fight: who
## they have opened on (Ambush Strike), how many times this turn they have hit
## with `skill` (Thousand Cuts), and a charge spent (Leading Charge).
func _note_path_hits(attacker: Dictionary, struck: Array, skill: SkillDefinition):
	if struck.is_empty():
		return
	var opened: Array = attacker.get("opened_on", [])
	for target in struck:
		if not opened.has(target.get("id", -1)):
			opened.append(target.get("id", -1))
	attacker["opened_on"] = opened
	var key := skill_key_of(skill)
	if key != "":
		var hits: Dictionary = attacker.get("repeat_hits", {})
		hits[key] = hits.get(key, 0) + 1
		attacker["repeat_hits"] = hits
	if attacker.get("walked_this_turn", 0) > 0:
		attacker["charge_spent"] = true


## Felling `target` on their own turn, somebody whose kills spur them on gets
## their main action back, and more movement (Rampage).
func _after_felling(attacker: Dictionary, target: Dictionary):
	if not attacker.get("alive", false) or target.get("side", -1) == attacker.get("side", -2) \
			or target.has("object") or target.get("illusion", false) or not is_same(get_current_combatant(), attacker):
		return
	for passive in active_passives(attacker):
		if not passive.felling_refreshes:
			continue
		attacker["action_back"] = true
		if controller != null and passive.felling_movement > 0:
			controller.movement += passive.felling_movement
		update_information.emit("[color=yellow]%s[/color] is not done yet: %s falls, and she goes on.\n" % [attacker.name, target.name])
		return


## Shoves `who` `tiles` away from `attacker`, as a skill's PUSH would.
func _shove(attacker: Dictionary, who: Dictionary, tiles: int, skill: SkillDefinition):
	if tiles <= 0 or not who.get("alive", false):
		return
	var push := EffectDefinition.new()
	push.type = EffectDefinition.EffectType.PUSH
	push.knockback_distance = tiles
	apply_effect(attacker, who, push, skill, false)


## Shoved into something solid by somebody whose shoves leave a mark (Tremor:
## Dazed). Put on afresh each time, never stacked - a second impact before their
## turn leaves them dazed for that one turn still (put_condition replaces it).
func _tremor_impact(attacker: Dictionary, target: Dictionary):
	if not attacker.has("passives") or not target.get("alive", false):
		return
	for passive in active_passives(attacker):
		var impact: ConditionDefinition = passive.tremor_impact_condition
		if impact != null:
			if put_condition(target, impact, turns_stored(impact.duration, impact.wears_off_at_start, on_whoever_acts(target)),
					attacker.name, false, attacker.get("id", -1)):
				update_information.emit("[color=red]%s[/color] is %s by the impact.\n" % [target.name, impact.display_name.to_lower()])
			return


## Their Guard (Covering Stance) covers allies within reach of them too: what it
## does to them, done to each.
func _cover_with_guard(attacker: Dictionary, skill_key: String, skill: SkillDefinition):
	if skill_key != "guard":
		return
	var reach := 0
	for passive in active_passives(attacker):
		reach = maxi(reach, passive.guard_covers)
	if reach <= 0:
		return
	for ally in combatants:
		if ally == attacker or not ally.get("alive", false) or ally.get("side", -1) != attacker.side \
				or ally.has("object") or ally.get("illusion", false) or distance_to(ally, nearest_tile_of(attacker, ally.position)) > reach:
			continue
		for effect in skill.all_effects():
			if effect != null and effect.applies_to_caster:
				apply_effect(attacker, ally, effect, skill, false)
		update_information.emit("[color=yellow]%s[/color]'s guard covers [color=yellow]%s[/color] too.\n" % [attacker.name, ally.name])


## Whether somebody holds the line around `target` (Hold the Line): an ally of
## theirs whose aura they stand in.
func _line_held(target: Dictionary) -> bool:
	if not target.has("side"):
		return false
	for ally in combatants:
		if ally == target or not ally.get("alive", false) or ally.get("side", -1) != target.side or ally.get("illusion", false):
			continue
		var holds := false
		var reach := 0
		for passive in active_passives(ally):
			holds = holds or passive.holds_the_line
			reach = maxi(reach, passive.aura_radius)
		if holds and reach > 0 and distance_to(target, nearest_tile_of(ally, target.position)) <= reach:
			return true
	return false


## A blow of `damage` that would fell `target` stops at 1 health while somebody
## of theirs walls them (Last Wall): the rest lands on that one. What is left
## for the target.
func _last_wall(target: Dictionary, damage: int) -> int:
	var standing: int = target.get("hp", 0) + target.get("temp_hp", 0)
	if damage < standing or not target.has("side") or target.has("object") or target.get("illusion", false):
		return damage
	for wall in combatants:
		if wall == target or not wall.get("alive", false) or wall.get("side", -1) != target.side or wall.get("illusion", false):
			continue
		for passive in active_passives(wall):
			if passive.last_wall <= 0 or distance_to(wall, nearest_tile_of(target, wall.position)) > passive.last_wall:
				continue
			var kept := maxi(standing - 1, 0)
			var rest := damage - kept
			lose_hp(wall, rest)
			show_damage(wall, rest, Damage.Type.PHYSICAL, true)
			update_information.emit("[color=yellow]%s[/color] throws herself in the way: %d of the blow that would have felled [color=yellow]%s[/color] is hers.\n" % [
				wall.name, rest, target.name])
			if wall.hp <= 0:
				combatant_die(wall)
			return kept
	return damage


## Whether `attacker`'s hit on `target`, rolled to land, misses after all: the
## first blow of a fight on somebody under an Illusory Guardian, a phantom taking
## it (Phantom Body), an afterimage in cover, or a copy (miss_chance). Said.
func _evades(attacker: Dictionary, target: Dictionary, skill: SkillDefinition) -> bool:
	if skill == null or not skill.deals_damage or attacker.get("side", -1) == target.get("side", -2) \
			or target.has("object") or not target.has("status_effects"):
		return false
	if not target.get("first_blow_missed", false):
		for guardian in combatants:
			if guardian.get("alive", false) and guardian.get("side", -1) == target.side and not guardian.get("illusion", false) \
					and active_passives(guardian).any(func(passive): return passive.guards_first_blow):
				target["first_blow_missed"] = true
				update_information.emit("[color=yellow]%s[/color]'s blow finds only an illusion of [color=yellow]%s[/color].\n" % [attacker.name, target.name])
				return true
	for entry in target.status_effects.duplicate():
		var condition = entry.get("condition") if entry.get("stat", "") == "condition" else null
		if condition != null and condition.evades_next_hit:
			target.status_effects.erase(entry)
			update_combatants.emit(combatants)
			update_information.emit("[color=yellow]%s[/color] strikes [color=yellow]%s[/color]'s phantom, and it passes through nothing.\n" % [attacker.name, target.name])
			return true
	if not target.get("afterimage_spent", false) and in_cover(target) \
			and active_passives(target).any(func(passive): return passive.afterimage):
		target["afterimage_spent"] = true
		update_information.emit("[color=yellow]%s[/color] strikes an afterimage - [color=yellow]%s[/color] was never there.\n" % [attacker.name, target.name])
		return true
	var chance := 0
	for condition in conditions_of(target):
		chance = maxi(chance, condition.miss_chance)
	if chance > 0 and rng.randi() % 100 < chance:
		update_information.emit("[color=yellow]%s[/color] strikes a copy of [color=yellow]%s[/color], and misses.\n" % [attacker.name, target.name])
		return true
	return false


## A Gun hit of somebody who Overloads: each of their lingering conditions on
## `target` ticks once more, there and then.
func _overload(attacker: Dictionary, target: Dictionary, skill: SkillDefinition):
	if not (skill.is_ammo or skill.combines_ammo or skill_key_of(skill) == "gun") \
			or not active_passives(attacker).any(func(passive): return passive.overload):
		return
	for entry in target.get("status_effects", []).duplicate():
		if not target.get("alive", false):
			return
		var condition = entry.get("condition") if entry.get("stat", "") == "condition" else null
		if condition != null and _lingers(condition) and entry.get("source_id", -2) == attacker.get("id", -1):
			update_information.emit("[color=yellow]%s[/color]'s shot sets the %s off.\n" % [attacker.name, condition.display_name.to_lower()])
			tick_condition_damage(target, condition, entry.get("dot_base", 0.0), 1.0, attacker)


## A hit with an Edge that lands strikes again with its element, free
## (Spellstrike).
func _spellstrike(attacker: Dictionary, target: Dictionary, skill: SkillDefinition):
	var key := skill_key_of(skill)
	for passive in active_passives(attacker):
		if passive.spellstrike > 0.0 and passive.spellstrike_skills.has(key) and target.get("alive", false):
			update_information.emit("[color=yellow]%s[/color]'s blade carries a spell with it.\n" % attacker.name)
			apply_effect(attacker, target, skill.damage_effect(), skill, false, passive.spellstrike / maxf(modifier_of(attacker, skill), 0.01))
			return


## The turns more a root or a slow of `attacker`'s lasts (Battlefield Control).
func _control_extra(attacker: Dictionary, effect: EffectDefinition) -> int:
	if not attacker.has("passives"):
		return 0
	var slows := false
	match effect.type:
		EffectDefinition.EffectType.STAT_MODIFIER:
			slows = effect.stat == "movement" and effect.modifier_amount < 0
		EffectDefinition.EffectType.STAT_MULTIPLIER:
			slows = effect.stat == "movement" and effect.stat_multiplier < 1.0
		EffectDefinition.EffectType.CONDITION:
			slows = effect.condition != null and (effect.condition.prevents_movement or effect.condition.movement_change < 0)
	if not slows:
		return 0
	var extra := 0
	for passive in active_passives(attacker):
		extra += passive.control_extra_turns
	return extra


## The tiles further `attacker`'s shoves go (Battlefield Control).
func push_extra_of(attacker: Dictionary) -> int:
	var extra := 0
	if attacker.has("passives"):
		for passive in active_passives(attacker):
			extra += passive.push_extra
	return extra


## How many times a round `warder` can Ward (Shared Ward): 1 unless a path says.
func wards_a_round(warder: Dictionary) -> int:
	var most := 1
	for passive in active_passives(warder):
		most = maxi(most, passive.wards_per_round)
	return most


## A spell of `attacker`'s that leaps (Chain): from whoever it hit to one more of
## the other side within reach of them, at a share of the damage.
func _chain(attacker: Dictionary, skill: SkillDefinition, struck: Array):
	if struck.is_empty() or not is_spell(skill) or not skill.deals_damage:
		return
	var element := effective_damage_type(attacker, skill.damage_type)
	for passive in active_passives(attacker):
		if passive.chain_share <= 0.0 or not passive.chain_elements.has(element):
			continue
		var best: Dictionary = {}
		var best_gap := 999999
		for other in combatants:
			if not other.get("alive", false) or other.get("side", -1) == attacker.side or other.has("object") \
					or struck.has(other) or is_hidden(other):
				continue
			for hit in struck:
				var gap := distance_to(other, nearest_tile_of(hit, other.position))
				if gap <= passive.chain_reach and gap < best_gap:
					best = other
					best_gap = gap
		if best.is_empty():
			return
		update_information.emit("The %s leaps to [color=red]%s[/color].\n" % [skill.name, best.name])
		apply_effect(attacker, best, skill.damage_effect(), skill, false, passive.chain_share)
		return


## Whether `skill` goes through the deepest gate open to `attacker` and they
## have a Conduit still to spend before a short rest.
func _conduit_ready(attacker: Dictionary, skill: SkillDefinition) -> bool:
	if not is_spell(skill) or attacker.get("conduit_spent", false) \
			or not active_passives(attacker).any(func(passive): return passive.conduit):
		return false
	var deepest := 0
	var gates: Array = attacker.get("max_spell_slots", [])
	for gate in range(gates.size() - 1, 0, -1):
		if gates[gate] > 0:
			deepest = gate
			break
	return deepest > 0 and skill.spell_slot_level >= deepest


## What `attacker`'s use did to whoever it hit, done again (Conduit): the spell
## cast twice.
func _cast_again(attacker: Dictionary, skill: SkillDefinition, struck: Array):
	attacker["conduit_spent"] = true
	update_information.emit("[color=yellow]%s[/color]'s %s comes through the gate twice.\n" % [attacker.name, skill.name])
	for target in struck:
		if not target.get("alive", false):
			continue
		for effect in skill.all_effects():
			if effect != null and not effect.applies_to_caster:
				apply_effect(attacker, target, effect, skill, false)


## Damage dealt by the use under way, for Righteous - counted in do_damage.
var _dealt_now := 0


## A damaging spell of somebody Righteous heals the most hurt of their side
## within reach of them for a share of what it dealt.
func _righteous(attacker: Dictionary, skill: SkillDefinition):
	if _dealt_now <= 0 or not is_spell(skill) or not attacker.get("alive", false):
		return
	for passive in active_passives(attacker):
		if passive.righteous_share <= 0.0:
			continue
		var patient: Dictionary = {}
		var lowest := 2.0
		for ally in combatants:
			if not ally.get("alive", false) or ally.get("side", -1) != attacker.side or ally.has("object") or ally.get("illusion", false) \
					or distance_to(ally, nearest_tile_of(attacker, ally.position)) > passive.righteous_reach:
				continue
			var share := float(ally.hp) / maxf(float(get_effective_stat(ally, "max_hp")), 1.0)
			if share < lowest and share < 1.0:
				lowest = share
				patient = ally
		var mended := roundi(_dealt_now * passive.righteous_share)
		if patient.is_empty() or mended <= 0:
			return
		patient.hp = mini(patient.hp + mended, get_effective_stat(patient, "max_hp"))
		float_number(patient, "+%d" % mended, Color("7fe08a"))
		update_combatants.emit(combatants)
		update_information.emit("Righteous: [color=lightgreen]%s[/color] is mended for %d.\n" % [patient.name, mended])
		return


## How many more times `comb` can use `skill` before a short rest - -1 for as
## often as they like (SkillDefinition.uses_per_short_rest).
func uses_left(comb: Dictionary, skill: SkillDefinition) -> int:
	if skill == null or skill.uses_per_short_rest <= 0:
		return -1
	return maxi(uses_a_rest(comb, skill) - int(comb.get("uses", {}).get(skill_key_of(skill), 0)), 0)


## How many uses a short rest `comb` has of `skill` at their level: its Uses Per
## Short Rest, and one more for each of its More Uses At they have reached.
static func uses_a_rest(comb: Dictionary, skill: SkillDefinition) -> int:
	var count := skill.uses_per_short_rest
	for level in skill.more_uses_at:
		if comb.get("level", 1) >= level:
			count += 1
	return count


## What is spent until a short rest rather than for a fight (the designer's
## change of 2026-10-24, APPROVED_TRIAL), by what it is kept under on the
## combatant: the uses of a skill (uses_per_short_rest), a free amplification
## (free_amplifies_at), a Conduit, the Trapper's free bomb (free_item_each_fight,
## a short rest's since the designer's change of 2026-10-25) and spare castings
## (Devotion - a short rest gives only some of those back). In a dungeon
## Campaign carries them from fight to fight (record_party, apply_carried_state)
## until a short or long rest clears them; every fight elsewhere starts with all
## of them, as it does with the gates.
const SPENT_UNTIL_REST := ["uses", "free_amplifies_used", "conduit_spent", "free_items_used", "spare_spent"]


## What `comb` has spent until a rest (SPENT_UNTIL_REST), to carry into the
## next fight.
static func spent_until_rest(comb: Dictionary) -> Dictionary:
	var spent := {}
	for key in SPENT_UNTIL_REST:
		if comb.has(key):
			spent[key] = comb[key].duplicate(true) if comb[key] is Dictionary or comb[key] is Array else comb[key]
	return spent


## As `comb`'s turn starts: what the paths count per turn and per round starts
## again; their conditions spread (Contagion); a shield of theirs that only
## lasted so long goes; cover they called up that was never there fades.
func _paths_at_turn_start(comb: Dictionary):
	for key in ["walked_this_turn", "charge_spent", "repeat_hits", "afterimage_spent", "wards_this_round", "shown_this_turn", "tremor_struck"]:
		comb.erase(key)
	if comb.has("temp_hp_turns"):
		comb.temp_hp_turns -= 1
		if comb.temp_hp_turns <= 0:
			comb.erase("temp_hp_turns")
			if comb.get("temp_hp", 0) > 0:
				comb.temp_hp = 0
				update_information.emit("[color=yellow]%s[/color]'s shield of light fades.\n" % comb.name)
	for thing in combatants:
		if thing.get("alive", false) and thing.has("fades_after") and thing.get("called_by", -1) == comb.get("id", -2):
			thing.fades_after -= 1
			if thing.fades_after <= 0:
				_object_gone(thing, "fades - it was never there")
	_spread_conditions(comb)
	_zones_at_turn_start(comb)


## Contagion: the conditions put on `comb` by somebody whose conditions spread go
## to everybody of `comb`'s side beside them, fresh.
func _spread_conditions(comb: Dictionary):
	if not comb.get("alive", false):
		return
	for entry in comb.get("status_effects", []).duplicate():
		var condition = entry.get("condition") if entry.get("stat", "") == "condition" else null
		if condition == null or not _harmful(entry):
			continue
		var source := _combatant_by_id(entry.get("source_id", -1))
		if source.is_empty() or not source.get("alive", false) or not active_passives(source).any(func(passive): return passive.contagion):
			continue
		for other in combatants:
			if other == comb or not other.get("alive", false) or other.get("side", -1) != comb.side or other.has("object") \
					or other.get("illusion", false) or not _beside(comb, other) or _carries(other, condition) \
					or immune_to_condition(other, condition):
				continue
			var copy: Dictionary = entry.duplicate()
			copy["duration"] = entry.get("full_duration", entry.duration)
			other.status_effects.append(copy)
			update_information.emit("The %s spreads from [color=red]%s[/color] to [color=red]%s[/color].\n" % [condition.display_name.to_lower(), comb.name, other.name])
	update_combatants.emit(combatants)


## --- Catalyst ---
##
## Cyrus's (EffectType.CATALYST, once a short rest): every lingering condition of his
## (source_id) on every enemy - whoever it is aimed at - goes off at once for all
## it had left: one tick's damage x the ticks left x Catalyst Times, resisted
## once. Then each starts again from the top (full_duration, kept as it landed).
## Conditions only: a bare damage-over-time wound is not one. Its scope and
## arithmetic are the designer's (2026-10-24) - not to change without a trial.
## Only his own, on purpose: Catalyst is Cyrus's personal condition payoff, and
## the rest of the party's conditions are not his to set off. Team-wide
## condition synergy may come later as a mechanic of its own - not folded in here.


func catalyst(attacker: Dictionary, effect: EffectDefinition):
	var any := false
	for other in combatants.duplicate():
		if not other.get("alive", false) or other.get("side", -1) == attacker.get("side", -2) or other.has("object"):
			continue
		for entry in other.status_effects.duplicate():
			var condition = entry.get("condition") if entry.get("stat", "") == "condition" else null
			if condition == null or not _lingers(condition) or entry.get("source_id", -2) != attacker.get("id", -1):
				continue
			any = true
			var left := ticks_left(other, entry)
			if left > 0 and other.alive:
				tick_condition_damage(other, condition, entry.get("dot_base", 0.0), left * effect.catalyst_times, attacker)
			if other.alive:
				entry.duration = entry.get("full_duration", entry.duration)
	if not any:
		update_information.emit("Nothing of [color=yellow]%s[/color]'s is lingering on anybody.\n" % attacker.name)
	update_combatants.emit(combatants)


## --- Traps ---
##
## The Trapper's (EffectType.TRAP): a hidden trap on a bare tile, seen only by
## its setter's side (trap_tiles, drawn by the board). The first of the other side
## to step onto it (spring_trap, from the controller's walk) is held by it - its
## Trap Holds With - and the walk is over; a Tripwire bursts as well. One set at a
## time, more with Field of Traps (extra_traps) - a new one past that takes the
## oldest's place. A Minefield sets one on every free tile within Trap Field
## Radius at once, past the limit.

## {"tile", "owner_id", "side", "holds", "burst", "burst_radius", "skill"}, oldest first.
var traps: Array = []


## Whether `skill` sets traps (EffectType.TRAP).
static func sets_traps(skill: SkillDefinition) -> bool:
	return skill != null and skill.effects.any(func(effect): return effect != null and effect.type == EffectDefinition.EffectType.TRAP)


## How far round the tile aimed at `skill` sets traps (Minefield's field), 0 for
## one trap on the tile itself.
static func trap_field_of(skill: SkillDefinition) -> int:
	if skill == null:
		return 0
	for effect in skill.effects:
		if effect != null and effect.type == EffectDefinition.EffectType.TRAP:
			return effect.trap_field_radius
	return 0


## Whether `tile` can take a trap: open ground, nobody on it, no trap there.
func trap_fits(tile: Vector2i) -> bool:
	return controller != null and controller.is_in_bounds(tile) and controller.is_on_map(tile) \
		and not controller.is_tile_blocking(tile, 0) and get_combatant_at(tile).is_empty() \
		and not traps.any(func(trap): return trap.tile == tile)


## Sets `effect`'s trap where `skill` was aimed.
func set_trap(setter: Dictionary, effect: EffectDefinition, tile: Vector2i, skill: SkillDefinition):
	var tiles := [tile]
	if effect.trap_field_radius > 0:
		tiles = []
		for dy in range(-effect.trap_field_radius, effect.trap_field_radius + 1):
			for dx in range(-effect.trap_field_radius, effect.trap_field_radius + 1):
				var there: Vector2i = tile + Vector2i(dx, dy)
				if get_position_distance(tile, there) <= effect.trap_field_radius and trap_fits(there):
					tiles.append(there)
	var laid := 0
	for there in tiles:
		if not trap_fits(there):
			continue
		traps.append({"tile": there, "owner_id": setter.get("id", -1), "side": setter.get("side", 0),
			"holds": effect.trap_holds_with, "burst": effect.trap_burst_modifier, "burst_radius": effect.trap_burst_radius,
			"skill": skill, "field": effect.trap_field_radius > 0})
		laid += 1
	# Past how many they can keep set, the oldest goes - a field is past it.
	if effect.trap_field_radius == 0:
		var most := 1
		for passive in active_passives(setter):
			most += passive.extra_traps
		var theirs := traps.filter(func(trap): return trap.owner_id == setter.get("id", -1) and not trap.get("field", false))
		while theirs.size() > most:
			traps.erase(theirs.pop_front())
	if laid > 0:
		update_information.emit("[color=yellow]%s[/color] sets %s.\n" % [setter.name, "a trap" if laid == 1 else "%d traps" % laid])
	else:
		update_information.emit("There is no room for a trap there.\n")
	if controller != null:
		controller.queue_redraw()


## The tiles of the traps the player can see: their own side's.
func trap_tiles() -> Array:
	return traps.filter(func(trap): return trap.side == 0).map(func(trap): return trap.tile)


## `mover` stepping onto `tile`: a trap of the other side's there goes off - they
## are held, a Tripwire bursts. True when one did.
func spring_trap(mover: Dictionary, tile: Vector2i) -> bool:
	for trap in traps.duplicate():
		if trap.tile != tile or trap.side == mover.get("side", -1):
			continue
		traps.erase(trap)
		var setter := _combatant_by_id(trap.owner_id)
		var by: Dictionary = setter if not setter.is_empty() else {"name": "a trap", "id": trap.owner_id, "side": trap.side}
		update_information.emit("[color=red]%s[/color] walks into a trap!\n" % mover.name)
		if trap.holds != null and put_condition(mover, trap.holds, turns_stored(trap.holds.duration, trap.holds.wears_off_at_start, on_whoever_acts(mover)),
				by.name, true, trap.owner_id):
			mover["trapped_by"] = trap.owner_id
		if trap.burst > 0.0 and not setter.is_empty() and trap.skill != null:
			for other in combatants.duplicate():
				if other.get("alive", false) and other.get("side", -1) != trap.side and not other.has("object") \
						and distance_to(other, tile) <= trap.burst_radius:
					apply_effect(setter, other, trap.skill.damage_effect(), trap.skill, false, trap.burst / maxf(modifier_of(setter, trap.skill), 0.01), tile)
		if controller != null:
			controller.queue_redraw()
		update_combatants.emit(combatants)
		return true
	return false


## --- Zones ---
##
## A lasting zone on the ground (EffectType.ZONE): the tiles a skill covers,
## where it was aimed, stay for Zone Turns of its caster's turns. Whoever of Zone
## For stands in it has Zone Condition for as long as they stand there - stepping
## in puts it on, stepping out takes it off. sync_zones squares that up after
## every step (the controller), every use (use_skill) and as every turn begins;
## the entries it puts on carry `zone_id`, and nothing else touches them. Drawn by
## the board (zone_tiles). Sanctuary of Light, Mass Mirage - and whatever else
## leaves something on the ground.

## {"id", "tiles", "condition", "for", "turns", "owner_id", "side", "name"}.
var zones: Array = []
var _next_zone_id := 1
## Whether a zone was ever laid this fight - before then, nothing to square up.
var _zones_laid := false


## Leaves `effect`'s zone on `tiles`, the ground `skill` covered.
func lay_zone(caster: Dictionary, effect: EffectDefinition, tiles: Array, skill: SkillDefinition):
	if effect.zone_condition == null or tiles.is_empty():
		return
	zones.append({"id": _next_zone_id, "tiles": tiles.duplicate(), "condition": effect.zone_condition,
		"for": effect.zone_for, "turns": effect.zone_turns, "owner_id": caster.get("id", -1),
		"side": caster.get("side", 0), "name": skill.name if skill != null else effect.zone_condition.display_name,
		"unseen": effect.zone_unseen,
		# The gate it came through, for Dispel Magic ("Dispelling") - 0, no spell's.
		"gate": spell_gate_of(skill) if is_spell(skill) else 0})
	_next_zone_id += 1
	_zones_laid = true
	update_information.emit("[color=yellow]%s[/color]'s %s stays on the ground.\n" % [caster.name, skill.name if skill != null else "zone"])
	sync_zones()
	if controller != null:
		controller.queue_redraw()


## Whether `zone` holds `comb`: of the side it is for, with a tile in it.
func _zone_holds(zone: Dictionary, comb: Dictionary) -> bool:
	if not comb.get("alive", false) or comb.has("object") or comb.get("illusion", false) or not comb.has("position"):
		return false
	match zone["for"]:
		0:
			if comb.get("side", -1) != zone.side:
				return false
		1:
			if comb.get("side", -1) == zone.side:
				return false
	return tiles_of(comb).any(func(tile): return tile in zone.tiles)


## Everybody has the conditions of the zones they stand in, and none of those
## they do not.
func sync_zones():
	if not _zones_laid:
		return
	var changed := false
	for comb in combatants:
		if not comb.has("status_effects"):
			continue
		var inside := {}
		for zone in zones:
			if _zone_holds(zone, comb) and not immune_to_condition(comb, zone.condition):
				inside[zone.id] = zone
		var before: int = comb.status_effects.size()
		var movement_before = get_effective_stat(comb, "movement") if comb.has("movement") else 0
		comb.status_effects = comb.status_effects.filter(func(entry): return not entry.has("zone_id") or inside.has(entry.zone_id))
		changed = changed or before != comb.status_effects.size()
		for id in inside:
			var zone: Dictionary = inside[id]
			var held = comb.status_effects.filter(func(entry): return entry.get("zone_id", -1) == id)
			if not held.is_empty():
				# Shown as long as the zone has left, and never run out on them first.
				held[0].duration = zone.turns + 1
				continue
			comb.status_effects.append({"stat": "condition", "condition": zone.condition, "dot_base": 0.0,
				"duration": zone.turns + 1, "ends_at_start": false, "source_name": zone.name,
				"source_id": zone.owner_id, "zone_id": id})
			changed = true
		if changed and comb.has("movement") and get_effective_stat(comb, "movement") != movement_before:
			resync_live_movement(comb, movement_before)
		_zone_invisibility(comb)
	if changed:
		update_combatants.emit(combatants)


## Invisible while they stand in a zone that makes them so (makes_invisible -
## Reality's Reflection): made so as they hold it, and again once a turn of
## theirs starts if they gave themselves away (shown_this_turn, from
## _invisibility_ends); seen again once they step out - if it was the zone that
## hid them (zone_invisible).
func _zone_invisibility(comb: Dictionary):
	if not comb.get("alive", false) or comb.get("illusion", false) or comb.has("object"):
		return
	var held: bool = comb.status_effects.any(func(entry): return entry.has("zone_id") and entry.get("condition") != null \
		and entry.condition.makes_invisible)
	if held:
		if not is_invisible(comb) and not comb.get("shown_this_turn", false):
			make_invisible(comb)
			if is_invisible(comb):
				comb["zone_invisible"] = true
	elif comb.get("zone_invisible", false):
		comb.erase("zone_invisible")
		if is_invisible(comb):
			set_hidden(comb, false)
			update_information.emit("[color=yellow]%s[/color] steps out of the reflection, and can be seen again.\n" % comb.name)


## As `comb`'s turn starts: their zones have a turn less, and go when they have
## none left.
func _zones_at_turn_start(comb: Dictionary):
	if not _zones_laid:
		return
	for zone in zones.duplicate():
		if zone.owner_id == comb.get("id", -2):
			zone.turns -= 1
			if zone.turns <= 0:
				_zone_fades(zone)
	sync_zones()


## At the top of a round: a zone whose caster is down - and so takes no turns to
## count it down by - has a round less instead. It outlasts them; it does not
## outlast its time.
func _zones_round_begins():
	if not _zones_laid:
		return
	for zone in zones.duplicate():
		var owner := _combatant_by_id(zone.owner_id)
		if owner.is_empty() or not owner.get("alive", false):
			zone.turns -= 1
			if zone.turns <= 0:
				_zone_fades(zone)
	sync_zones()


## `zone` is gone from the ground - its time up, or dispelled.
func _zone_fades(zone: Dictionary, how: String = "fades from the ground"):
	zones.erase(zone)
	update_information.emit("The %s %s.\n" % [zone.name, how])
	if controller != null:
		controller.queue_redraw()


## The zones' tiles, and whether each is the other side's to the party - for the
## board to tint.
func zone_tiles() -> Array:
	# One the other side keeps from them is not drawn for them (zone_unseen).
	return zones.filter(func(zone): return zone.side == 0 or not zone.get("unseen", false)) \
		.map(func(zone): return {"tiles": zone.tiles, "hostile": zone.side != 0})


## --- Dispelling ---
##
## Everything a spell leaves - a condition or a change on somebody (marked
## `spell_gate` in apply_effect), invisibility (`invisible_gate`), somebody or
## something it called up or made (a summon, an image, Illusory Cover:
## `spell_gate` on them), a zone (`gate`) - remembers the gate it came through:
## the spell's own, or the deeper one it was cast through (_pay_for_cast,
## `_casting_gate`). Dispel Magic (EffectType.DISPEL_MAGIC, Prometheus) ends
## whatever of that came through a gate no deeper than the one it is cast
## through - it may be cast through any gate from its own down
## (SkillDefinition.chooses_gate, _choose_gate). Aimed at somebody, it ends
## what spells did to them, theirs or the other side's; aimed at bare ground in
## a zone, the zone. A zone's own conditions go with the zone, not by
## themselves; what no spell did, it leaves alone.

## The gate the spell being cast came through, set as it is paid for.
var _casting_gate := 0
var _casting_skill: SkillDefinition = null


## The gate `skill` came through: the one it was just cast through, if it is
## the spell being cast; its own otherwise - a Gate Nade, its spell's.
func spell_gate_of(skill: SkillDefinition) -> int:
	if skill == null:
		return 0
	if skill == _casting_skill and _casting_gate > 0:
		return _casting_gate
	if skill is GateNadeDefinition and skill.cast != null:
		return skill.cast.spell_slot_level
	return skill.spell_slot_level


## Whether `skill` dispels magic (EffectType.DISPEL_MAGIC).
static func dispels_magic(skill: SkillDefinition) -> bool:
	return skill != null and skill.effects.any(func(effect): return effect != null and effect.type == EffectDefinition.EffectType.DISPEL_MAGIC)


## Marks what `skill` just left on `target` - whatever is on them now that
## was not in `had` - with the gate it came through.
func _mark_spell_gate(target: Dictionary, had: Array, skill: SkillDefinition):
	var gate := spell_gate_of(skill)
	for entry in target.get("status_effects", []):
		if not entry.has("spell_gate") and not had.any(func(old): return is_same(old, entry)):
			entry["spell_gate"] = gate


## The zones covering `tile`.
func zones_at(tile: Vector2i) -> Array:
	return zones.filter(func(zone): return tile in zone.tiles)


## Which gate `attacker` casts `skill` through: asked of the player among those
## they have a casting in from its own down (the shallowest first); the
## shallowest for anybody else.
func _choose_gate(attacker: Dictionary, skill: SkillDefinition) -> int:
	var choices := []
	var slots: Array = attacker.get("spell_slots", [])
	var opened: Array = attacker.get("max_spell_slots", [])
	var free := casts_without_gates(attacker)
	for gate in range(maxi(skill.spell_slot_level, 1), slots.size()):
		# A casting left through it - or, casting without spending, it opened.
		if slots[gate] > 0 or (free and gate < opened.size() and opened[gate] > 0):
			choices.append(gate)
	if choices.is_empty():
		return skill.spell_slot_level
	if choices.size() > 1 and plays_for_party(attacker) and reaction_prompt != null and reaction_prompt.has_method("pick"):
		var labels: Array = choices.map(func(gate): return "%s (%d left)" % [Stats.gate_name(gate), slots[gate]])
		var picked: int = await reaction_prompt.pick("%s casts %s" % [attacker.name, skill.name],
			"Through which gate? It undoes what came through that gate or a shallower one.", labels)
		return choices[clampi(picked, 0, choices.size() - 1)]
	return choices[0]


## Dispel Magic landing on `target`: what spells through gates no deeper than
## its own left on them is ended - or, made by a spell, they are.
func dispel_magic(caster: Dictionary, target: Dictionary, skill: SkillDefinition):
	var gate := spell_gate_of(skill)
	var ended := []
	var too_deep := []
	# Somebody or something a spell called up or made: gone.
	if target.has("spell_gate"):
		if target.spell_gate > gate:
			too_deep.append(target.name)
		elif target.has("object"):
			_object_gone(target, "is dispelled")
			return
		elif target.get("illusion", false):
			_shatter(target)
			return
		elif target.has("summoner"):
			_unsummon(target, "is dispelled")
			return
	var movement_before = get_effective_stat(target, "movement") if target.has("movement") else 0
	var was_held: bool = target.has("movement") and has_restriction(target, "prevents_movement")
	for entry in target.get("status_effects", []).duplicate():
		# A zone's goes with the zone, not by itself.
		if not entry.has("spell_gate") or entry.has("zone_id"):
			continue
		var what: String = entry.condition.display_name if entry.get("condition") != null else String(entry.get("stat", "a spell"))
		if entry.spell_gate > gate:
			too_deep.append(what)
			continue
		target.status_effects.erase(entry)
		ended.append(what)
	if is_invisible(target) and target.has("invisible_gate"):
		if target.invisible_gate > gate:
			too_deep.append("invisibility")
		else:
			target.erase("invisible_gate")
			set_hidden(target, false)
			ended.append("invisibility")
	if not ended.is_empty():
		resync_movement_class(target)
		resync_size(target)
		clamp_hp_to_max(target)
		if target.has("movement"):
			_movement_after_lift(target, was_held, movement_before)
		update_combatants.emit(combatants)
		update_information.emit("[color=yellow]%s[/color] undoes the magic on [color=yellow]%s[/color]: %s.\n" % [caster.name, target.name, ", ".join(ended)])
	if not too_deep.is_empty():
		update_information.emit("Cast through %s, it cannot reach what came through a deeper gate: %s.\n" % [Stats.gate_name(gate), ", ".join(too_deep)])
	if ended.is_empty() and too_deep.is_empty():
		update_information.emit("There is nothing of a spell's on [color=yellow]%s[/color] to undo.\n" % target.name)


## Dispel Magic aimed at bare ground: the zones there that came through a gate
## no deeper than its own are gone.
func dispel_zones_at(caster: Dictionary, tile: Vector2i, skill: SkillDefinition):
	var gate := spell_gate_of(skill)
	var any := false
	for zone in zones_at(tile):
		if zone.get("gate", 0) <= 0:
			continue
		any = true
		if zone.gate > gate:
			update_information.emit("The %s came through a deeper gate than %s - it holds.\n" % [zone.name, Stats.gate_name(gate)])
		else:
			_zone_fades(zone, "is dispelled by [color=yellow]%s[/color]" % caster.name)
	if not any:
		update_information.emit("There is no magic on the ground there to undo.\n")
	sync_zones()


## Whether `target` is held by one of `setter`'s traps right now (Grand Snare).
func _trapped_by(target: Dictionary, setter: Dictionary) -> bool:
	if target.get("trapped_by", -2) != setter.get("id", -1):
		return false
	for entry in target.get("status_effects", []):
		if entry.get("stat", "") == "condition" and entry.get("source_id", -2) == setter.get("id", -1) \
				and entry.get("condition") != null and entry.condition.prevents_movement:
			return true
	return false


## --- Drawing ---
##
## Rummage (EffectType.DRAW, data/skills/common/rummage.tres): one thing out of the
## user's pouch and onto their belt, ready to use (Campaign "Containers"). It is
## handling an item, so it is a main action, and a secondary one too for whoever
## uses items from it (items_as_secondary - Cyrus's Quick Hands). Offered while
## there is something in the pouch to use in a fight and room on the belt
## (main_skills_of, secondary_grants); the player picks which (_choose_draw).

const DRAW_SKILL := "rummage"


## Whether `skill` takes something out of a pouch.
static func draws(skill: SkillDefinition) -> bool:
	return skill != null and skill.all_effects().any(func(effect): return effect != null and effect.type == EffectDefinition.EffectType.DRAW)


## What `comb` could take out of their pouch to fight with, each once.
func drawable(comb: Dictionary) -> Array:
	var key: String = comb.get("combatant_key", "")
	if comb.get("side", 1) != 0 or key == "" or not CombatantDatabase.combatants.has(key) or comb.has("summoner"):
		return []
	var found := []
	for item_key in Campaign.contents_of(key, "pouch"):
		var item: ItemDefinition = ItemDatabase.item(item_key)
		if item != null and not item.stealth_only() and not found.has(item_key):
			found.append(item_key)
	return found


## Why `comb` cannot Rummage now, or "".
func draw_refusal(comb: Dictionary) -> String:
	var key: String = comb.get("combatant_key", "")
	if key == "" or Campaign.container_in(key, "pouch") == "":
		return "%s wears no pouch" % comb.get("name", "They")
	if drawable(comb).is_empty():
		return "Nothing in %s's pouch to fight with" % comb.get("name", "their")
	if not Campaign.has_room_in(key, "belt"):
		return "No room on %s's baldric" % comb.get("name", "their")
	return ""


## Which of `comb`'s pouch's things to take out: the player is asked when there
## is more than one; anybody else takes the first.
func _choose_draw(comb: Dictionary) -> String:
	var choices := drawable(comb)
	if choices.size() <= 1 or not plays_for_party(comb) or reaction_prompt == null or not reaction_prompt.has_method("pick"):
		return choices[0] if not choices.is_empty() else ""
	var labels: Array = choices.map(func(key): return _item_names([key]))
	var picked: int = await reaction_prompt.pick("%s rummages" % comb.name, "What does %s take out of the pouch?" % comb.name, labels)
	return choices[clampi(picked, 0, choices.size() - 1)]


## `comb` takes `item_key` out of their pouch and puts it on their belt. False,
## and nothing moved, if it is not there or there is no room.
func draw_into_belt(comb: Dictionary, item_key: String) -> bool:
	var key: String = comb.get("combatant_key", "")
	if key == "" or not Campaign.has_room_in(key, "belt") or not Campaign.take_item(key, item_key, "pouch"):
		return false
	if Campaign.stow_item(key, item_key, "belt") < 0:
		Campaign.stow_item(key, item_key, "pouch")
		return false
	update_information.emit("[color=yellow]%s[/color] takes %s out of the pouch and onto the baldric.\n" % [comb.name, _item_names([item_key])])
	update_combatants.emit(combatants)
	return true


## --- Loot ---
##
## An enemy down - fallen, knocked out, given up - can be looted: everything they
## carried, what is left in their pocket (comb.pocket) and what was never of use
## in a fight (comb.carried - a spellbook, say), and everything they wore
## (comb.equipment, SpawnDefinition.equipment). It goes to whoever loots them:
## their bag, and the party's stash for gear. Loot (EffectType.LOOT) is a
## secondary action, offered to the party while there is a body worth it
## (secondary_grants), aimed at one beside them or under their feet. Whatever is
## left on the bodies once the fight is won, the victory screen offers to take
## (loot_the_fallen). Nothing comes of a fight on its own.

## Whether `skill` loots (EffectType.LOOT).
static func loots(skill: SkillDefinition) -> bool:
	return skill != null and skill.all_effects().any(func(effect): return effect != null and effect.type == EffectDefinition.EffectType.LOOT)


## Whether `body` is down, of the other side to `looter`, and has anything on it.
func is_lootable(body: Dictionary, looter: Dictionary) -> bool:
	if body.get("alive", true) or body.get("side", -1) == looter.get("side", -2):
		return false
	if body.has("object") or body.get("illusion", false) or body.has("summoner") or body.get("eaten", false):
		return false
	# Gone from the field: nothing left lying there to go through.
	if body.get("taken", "") in ["fled", "bought", "unsummoned"]:
		return false
	return not (body.get("pocket", []).is_empty() and body.get("carried", []).is_empty() and body.get("equipment", []).is_empty())


## A body on `tile` for `looter` to loot, or {}.
func body_to_loot(tile: Vector2i, looter: Dictionary) -> Dictionary:
	for body in combatants:
		if is_lootable(body, looter) and rect_of(body).has_point(tile):
			return body
	return {}


## Whether there is any body for `looter` to loot.
func any_body_to_loot(looter: Dictionary) -> bool:
	return combatants.any(func(body): return is_lootable(body, looter))


## `looter` takes everything on `body` that they have room for: what it carried
## into their bag, what it wore into the party's stash. The names of what they
## took.
func loot(looter: Dictionary, body: Dictionary) -> Array:
	var taken := []
	for list in ["pocket", "carried"]:
		for key in body.get(list, []).duplicate():
			if _stow(looter, key) < 0:
				continue
			body[list].erase(key)
			var item: ItemDefinition = ItemDatabase.item(key)
			taken.append(item.name if item != null else key)
	for key in body.get("equipment", []).duplicate():
		var piece := EquipmentDefinition.named(key)
		if piece == null or looter.get("side", 1) != 0:
			continue
		Campaign.gear.append(key)
		Campaign.gear_changed.emit()
		body.equipment.erase(key)
		taken.append(piece.name)
	if taken.is_empty():
		update_information.emit("[color=yellow]%s[/color] has no room for anything [color=red]%s[/color] carried.\n" % [looter.name, body.name])
	else:
		update_information.emit("[color=yellow]%s[/color] loots [color=red]%s[/color]: %s.\n" % [looter.name, body.name, ", ".join(taken)])
	update_combatants.emit(combatants)
	return taken


## Everything still on the fallen of the other side to the party, by name.
func loot_left_on_the_fallen() -> Array:
	var left := []
	var party := {"side": Group.PLAYERS}
	for body in combatants:
		if not is_lootable(body, party):
			continue
		for key in body.get("pocket", []) + body.get("carried", []):
			var item: ItemDefinition = ItemDatabase.item(key)
			left.append(item.name if item != null else key)
		for key in body.get("equipment", []):
			var piece := EquipmentDefinition.named(key)
			left.append(piece.name if piece != null else key)
	return left


## The fight won: everything still on the fallen goes to the party - into the
## bag of the first of them with room, leader first, gear into the stash. What
## was taken, by name.
func loot_the_fallen() -> Array:
	var taken := []
	var party := {"side": Group.PLAYERS}
	for body in combatants:
		if not is_lootable(body, party):
			continue
		for list in ["pocket", "carried"]:
			for key in body.get(list, []).duplicate():
				for member in Campaign.living_party():
					if Campaign.stow_item(member, key) >= 0:
						body[list].erase(key)
						var item: ItemDefinition = ItemDatabase.item(key)
						taken.append(item.name if item != null else key)
						break
		for key in body.get("equipment", []).duplicate():
			var piece := EquipmentDefinition.named(key)
			if piece == null:
				continue
			Campaign.gear.append(key)
			body.equipment.erase(key)
			taken.append(piece.name)
	if not taken.is_empty():
		Campaign.gear_changed.emit()
	return taken


## --- Summons ---
##
## Somebody called into the fight by another (EffectType.SUMMON - a spell, an
## item, anything with the effect - or a CombatantDefinition's Summon At Start)
## is their summon: `comb.summoner` is the caller's id. It has no turn of its
## own and no place in the turn queue. It acts on its summoner's:
##   - Command (EffectType.COMMAND, the summoner's secondary action - offered to
##     anybody with a summon standing, secondary_grants) gives it its moment: its
##     move and its action, there and then (command), played by the summoner's
##     player - or the AI, for theirs - and back to the summoner after, with what
##     they had left of their turn. Ending the summon's moment (End Turn, or
##     nothing left to do) is advance_turn handing back (_end_command).
##   - Not commanded, it stands on guard as its summoner's turn ends - Enfina's
##     Guard (_stand_guard).
##   - Its summoner's turn lost to a stun, or played for them by confusion or a
##     deception, it fends for itself (_summons_fend): the AI keeps it safe, or
##     stands it by its summoner when somebody could reach them (ai_summon_alone).
## Whatever lasts on it ticks with its summoner's turn (_summons_turn_begins).
## When its summoner is out of the fight - fallen, fled, taken, however - it goes
## with them, and it leaves no body when it falls itself (_unsummon). It never
## breaks (can_break), and nothing of it is kept after the fight (record_party).

## The summon taking its moment of a summoner's turn, and what was left of that
## turn: {"summoner", "summon", "movement", "alone"}. Empty when none is.
var _commanding := {}

## Everything summoned by the skill being used, for its tether (use_skill).
var _summoned_now: Array = []


## Whether `comb` is somebody's summon.
static func is_summon(comb: Dictionary) -> bool:
	return comb.has("summoner")


## `comb`'s summons standing.
func summons_of(comb: Dictionary) -> Array:
	var id: int = comb.get("id", -1)
	return combatants.filter(func(other): return other.get("alive", false) and other.get("summoner", -2) == id)


## Who summoned `comb`, or {}.
func summoner_of(comb: Dictionary) -> Dictionary:
	for other in combatants:
		if other.get("id", -1) == comb.get("summoner", -2):
			return other
	return {}


## Whether `skill` summons (EffectType.SUMMON): the key of what, or "".
static func summons_with(skill: SkillDefinition) -> String:
	if skill == null:
		return ""
	for effect in skill.all_effects():
		if effect != null and effect.type == EffectDefinition.EffectType.SUMMON and effect.summons != "":
			return effect.summons
	return ""


## Whether `skill` commands a summon (EffectType.COMMAND).
static func commands(skill: SkillDefinition) -> bool:
	return skill != null and skill.all_effects().any(func(effect): return effect != null and effect.type == EffectDefinition.EffectType.COMMAND)


## Something the size of what `skill` summons, at `tile`, to ask whether it would
## fit there (can_land_on) - for aiming it. {} if it summons nothing.
func summon_probe(skill: SkillDefinition, side: int) -> Dictionary:
	var definition: CombatantDefinition = CombatantDatabase.combatants.get(summons_with(skill))
	if definition == null:
		return {}
	var size: int = definition.size
	return {"size": size, "span": Sizes.span(size, definition.gigantic_span), "side": side,
		"movement_class": definition.class_m, "position": Vector2i(-99999, -99999)}


## `caster` calls `effect`'s summons in on `tile` - or the nearest tile it fits,
## if it does not fit there. The summon, or {} when there is no room anywhere near.
func summon(caster: Dictionary, effect: EffectDefinition, tile: Vector2i, skill: SkillDefinition = null) -> Dictionary:
	var definition: CombatantDefinition = CombatantDatabase.combatants.get(effect.summons)
	if definition == null:
		push_warning("A summon of '%s', who is in neither data/enemies nor data/characters." % effect.summons)
		return {}
	var called: Dictionary = create_combatant(definition, effect.summons, "", null, caster.get("level", 1))
	called["summoner"] = caster.get("id", -1)
	called["side"] = caster.get("side", 0)
	# Made of their mind (Illusory Dragon): their attributes, not its own - as
	# they are, buffs and all, for as long as they stand (stat_of).
	if effect.with_summoners_attributes:
		called["stats"] = caster.get("stats", {}).duplicate(true)
		called["attributes_of"] = caster.get("id", -1)
	# Fighting for somebody the AI plays for the party (bought, rebound), the AI
	# plays it too.
	if caster.get("ai_controlled", false):
		called["ai_controlled"] = true
	var at: Vector2i = tile if can_land_on(called, tile) else _free_tile_for(called, tile)
	if at.x == -99999:
		update_information.emit("There is no room for [color=yellow]%s[/color] to call %s.\n" % [caster.name, called.name])
		return {}
	add_combatant(called, caster.side, at)
	_summoned_now.append(called)
	# Called up by a spell: Dispel Magic through as deep a gate undoes it.
	if is_spell(skill):
		called["spell_gate"] = spell_gate_of(skill)
	# Something called up that only lasts so long (Illusory Cover): it fades
	# as its caller's turns go by ("The paths").
	if definition is BattleObjectDefinition and definition.lasts_turns > 0:
		called["fades_after"] = definition.lasts_turns
	# A thing on the map is nobody's summon - nothing to command, no face beside
	# them - only something they put there.
	if called.has("object"):
		called["called_by"] = called.summoner
		called.erase("summoner")
	update_information.emit("[color=yellow]%s[/color] %s [color=lightgreen]%s[/color]%s.\n" % [caster.name,
		"calls up" if skill != null else "brings", called.name, " into the fight" if skill != null else " with them"])
	# Its presence felt the moment it is there, not only at turn starts.
	for other in combatants.duplicate():
		if other.get("alive", false) and other != called and not other.has("object"):
			_aura_of(called, other)
	update_combatants.emit(combatants)
	return called


## What `holder`'s auras put on `comb`, now - as `comb`'s turn begins
## (`at_turn_start`, saying nothing of a contest won), or as `holder` appears.
func _aura_of(holder: Dictionary, comb: Dictionary, at_turn_start: bool = false):
	for passive in active_passives(holder):
		if passive.aura_radius <= 0:
			continue
		var condition: ConditionDefinition = passive.aura_on_allies if holder.side == comb.side else passive.aura_on_foes
		if condition == null or get_distance(holder, comb) > passive.aura_radius:
			continue
		if not _aura_takes_hold(holder, passive, comb):
			if not at_turn_start:
				update_information.emit("[color=yellow]%s[/color] stands firm against [color=red]%s[/color]'s presence.\n" % [comb.name, holder.name])
			continue
		if put_condition(comb, condition, 1, "%s's aura" % holder.name, true, holder.get("id", -1)):
			update_information.emit("[color=yellow]%s[/color] is %s by [color=red]%s[/color]'s presence.\n" % [
				comb.name, condition.display_name.to_lower(), holder.name])


## Everybody who brings a summon into every fight (Summon At Start), with it
## beside them.
func _bring_starting_summons():
	for comb in combatants.duplicate():
		_bring_own_summon(comb)


## `comb`'s summon at start, beside them, if they have one and it is not here.
func _bring_own_summon(comb: Dictionary):
	var key: String = comb.get("summon_at_start", "")
	if key == "" or not comb.get("alive", false) or not summons_of(comb).is_empty():
		return
	var effect := EffectDefinition.new()
	effect.type = EffectDefinition.EffectType.SUMMON
	effect.summons = key
	summon(comb, effect, comb.position)


## Takes a summon off the board: called away, or fallen - it leaves no body.
func _unsummon(summoned: Dictionary, why: String):
	if not summoned.get("alive", false):
		return
	var index := combatants.find(summoned)
	_drop_riders(summoned)
	if summoned.has("riding"):
		dismount(summoned)
	summoned.alive = false
	summoned["taken"] = "unsummoned"
	if index != -1:
		groups[summoned.side].erase(index)
	update_information.emit("[color=yellow]%s[/color] %s.\n" % [summoned.name, why])
	combatant_died.emit(summoned)
	var sprite = summoned.get("sprite")
	if sprite != null and is_instance_valid(sprite):
		sprite.queue_free()
	summoned["sprite"] = null
	check_holds()
	if controller != null:
		controller.refresh_occupancy()
	update_combatants.emit(combatants)


## `comb` is out of the fight, however: their tether snaps, and their summons go with
## them.
func _summoner_gone(comb: Dictionary):
	snap_tether(comb, "%s is out of the fight" % comb.get("name", "they"))
	for summoned in summons_of(comb):
		_unsummon(summoned, "fades as %s goes" % comb.name)


## `summoner` gives `summoned` its moment of their turn (Command): its move and
## its action, now. `alone` is it fending for itself, its summoner's turn lost
## (_summons_fend) - played by the AI, saying nothing.
func command(summoner: Dictionary, summoned: Dictionary, alone: bool = false):
	if summoned.is_empty() or not summoned.get("alive", false) or not _commanding.is_empty():
		return
	_commanding = {"summoner": summoner, "summon": summoned, "alone": alone,
		"movement": controller.movement if controller != null else 0}
	summoned["commanded"] = true
	summoned.skill_used_this_turn = false
	# Its moment is a move and one action.
	summoned.secondary_used_this_turn = true
	current_combatant = combatants.find(summoned)
	if not alone:
		update_information.emit("[color=yellow]%s[/color] commands [color=lightgreen]%s[/color].\n" % [summoner.name, summoned.name])
	turn_advanced.emit(summoned)
	update_combatants.emit(combatants)
	if alone or ai_plays(summoned):
		watch_combatant(summoned)
		if alone:
			await ai_summon_alone(summoned)
		else:
			await ai_process(summoned)
		stop_watching()
		# Its moment ended without handing back (an AI with nothing to do).
		if not _commanding.is_empty() and _commanding.summon == summoned:
			_end_command()


## A summon's moment over: back to whoever gave it, with what they had left of
## their turn.
func _end_command():
	var summoner: Dictionary = _commanding.summoner
	var movement: int = _commanding.movement
	var alone: bool = _commanding.alone
	_commanding = {}
	current_combatant = combatants.find(summoner)
	if alone or not summoner.get("alive", false):
		return
	turn_advanced.emit(summoner)
	if controller != null:
		controller.movement = movement
		if game_ui != null and game_ui.has_method("set_movement"):
			game_ui.set_movement(movement)
	update_combatants.emit(combatants)


## Whether a summon is taking its moment of somebody's turn right now.
func is_commanding() -> bool:
	return not _commanding.is_empty()


## As `summoner`'s turn begins, their summons' with it: fresh actions, and what
## is on them ticking.
func _summons_turn_begins(summoner: Dictionary):
	for summoned in summons_of(summoner):
		summoned.skill_used_this_turn = false
		summoned.secondary_used_this_turn = false
		summoned.reaction_used = false
		summoned.reactions_suppressed = false
		summoned.erase("commanded")
		await start_of_turn_effects(summoned)
		if summoned.get("alive", false):
			_turn_begins_for(summoned)


## As `summoner`'s turn ends: every summon of theirs not commanded stands on
## guard, and what is on them ticks.
func _summons_turn_ends(summoner: Dictionary):
	for summoned in summons_of(summoner):
		if not summoned.get("commanded", false):
			_stand_guard(summoned)
		summoned.erase("commanded")
		end_of_turn_effects(summoned)


## `comb` on guard: what Guard does (Enfina's), free - whether or not they know it.
func _stand_guard(comb: Dictionary):
	var guard: SkillDefinition = SkillDatabase.skills.get("guard")
	if guard == null or not comb.get("alive", false):
		return
	update_information.emit("[color=yellow]%s[/color] stands on guard.\n" % comb.name)
	for effect in guard.all_effects():
		apply_effect(comb, comb, effect, guard, false)


## `summoner`'s turn is not theirs to give (stunned, confused, deceived): each of
## their summons fends for itself.
func _summons_fend(summoner: Dictionary):
	for summoned in summons_of(summoner):
		if not still_running() or combat_over:
			return
		await command(summoner, summoned, true)


## A summon on its own (its summoner's turn lost): when anybody of the other side
## could reach its summoner this coming round, it stands by them - between them
## and whoever is nearest, striking at them if it can - and otherwise it keeps
## itself as safe as it can. On guard after, unless it struck.
func ai_summon_alone(comb: Dictionary):
	var summoner := summoner_of(comb)
	var budget := movement_budget_of(comb)
	var threat := _nearest_threat_to(summoner)
	if not summoner.is_empty() and not threat.is_empty():
		# Near them, and nearer the one coming for them.
		var near := func(tile: Vector2i) -> float:
			return -2.0 * float(get_position_distance(tile, summoner.position)) - float(get_position_distance(tile, threat.position))
		var plan := ai_plan_attack(comb, _ai_main_keys(comb), budget, near)
		if plan.skill != "" and await _ai_carry_out(comb, plan, _ai_main_keys(comb), near):
			await advance_turn()
			return
		var post := find_best_reachable_tile(comb, budget, near)
		if post != comb.position:
			await controller.ai_move(post)
	else:
		var safe := find_best_reachable_tile(comb, budget, func(tile: Vector2i) -> float:
			return float(_distance_to_nearest_foe(comb, tile)))
		if safe != comb.position:
			await controller.ai_move(safe)
	if comb.get("alive", false):
		_stand_guard(comb)
	await advance_turn()


## Whoever of the other side could reach `comb` this coming round - the nearest
## such - or {}.
func _nearest_threat_to(comb: Dictionary) -> Dictionary:
	if comb.is_empty():
		return {}
	var best := {}
	var nearest := 999999
	for other in combatants:
		if not other.get("alive", false) or other.side == comb.side or other.has("object") or is_hidden(other) \
				or other.get("illusion", false) or other.get("untouchable", false):
			continue
		var gap: int = get_distance(other, comb)
		if gap <= movement_budget_of(other) + maxi(threat_reach(other), 1) and gap < nearest:
			nearest = gap
			best = other
	return best


## The Summoner (ai_function "ai_summoner"): frailer than a sorcerer, and it
## knows it - it keeps itself out of reach and lets its summon do the fighting.
## No summon standing, it calls one (any skill of its that summons, if it can
## pay for it), between itself and the other side. Then it goes to the safest
## tile from which it can still reach its summon; mends the summon if it is
## hurt, or else empowers it if it is not empowered already; and sends it in
## (Command) - played by the summon's own AI, which is as reckless as it likes.
func ai_summoner(comb: Dictionary):
	var call := ""
	for key in _ai_main_keys(comb):
		if summons_with(SkillDatabase.skills[key]) != "" and can_afford_skill(comb, SkillDatabase.skills[key]):
			call = key
			break
	if summons_of(comb).is_empty() and call != "":
		var at := _summon_spot(comb, SkillDatabase.skills[call])
		if at.x != -99999:
			await use_skill(call, comb, at, false)
			if not still_running() or not comb.alive:
				return
	var beasts := summons_of(comb)
	var beast: Dictionary = beasts[0] if not beasts.is_empty() else {}
	var mend := find_skill_of_type(comb, EffectDefinition.EffectType.HEAL)
	var empower := ""
	for key in _ai_main_keys(comb):
		var skill: SkillDefinition = SkillDatabase.skills[key]
		if skill.targets_ally and skill.all_effects().any(func(effect): return effect != null \
				and effect.type == EffectDefinition.EffectType.STAT_MULTIPLIER and effect.stat_multiplier > 1.0):
			empower = key
			break
	var reach := 0
	for key in [mend, empower]:
		if key != "":
			reach = maxi(reach, SkillDatabase.skills[key].max_range)
	# Safe first - but where it can still see to its summon.
	if not comb.get("skill_used_this_turn", false) or controller.movement > 0:
		var tile := find_best_reachable_tile(comb, movement_budget_of(comb), func(t: Vector2i) -> float:
			var score := score_tile_safety(t) if comb.side == Group.ENEMIES else float(_distance_to_nearest_foe(comb, t))
			if not beast.is_empty() and reach > 0 and get_position_distance(t, nearest_tile_of(beast, t)) > reach:
				score -= 1000.0
			return score)
		tile = avoid_needless_opportunity_attacks(comb, tile, {})
		if tile != comb.position:
			await controller.ai_move(tile)
		if not still_running() or not comb.alive:
			return
	if not beast.is_empty() and beast.alive and not comb.get("skill_used_this_turn", false):
		var hurt: bool = float(beast.hp) < float(get_effective_stat(beast, "max_hp")) * 0.6
		var empowered: bool = beast.status_effects.any(func(eff): return eff.get("stat", "") == "physical" \
			and eff.get("op", "") == "multiply" and float(eff.get("amount", 1.0)) > 1.0)
		var aid := mend if hurt and mend != "" else ("" if empowered else empower)
		if aid != "" and distance_to(comb, nearest_tile_of(beast, comb.position)) <= effective_max_range(comb, SkillDatabase.skills[aid]) \
				and can_afford_skill(comb, SkillDatabase.skills[aid]):
			await use_skill(aid, comb, nearest_tile_of(beast, comb.position), false)
	if not still_running() or not comb.alive:
		return
	# Sent in, recklessly - its own AI plays it.
	if not beast.is_empty() and beast.alive and not comb.get("secondary_used_this_turn", false):
		comb.secondary_used_this_turn = true
		await command(comb, beast)
	if not still_running() or not comb.alive:
		return
	# Nothing to aid, the summon gone: something of its own, from where it is.
	if not comb.get("skill_used_this_turn", false):
		var keys := _ai_main_keys(comb).filter(func(key): return key != call)
		var plan := ai_plan_attack(comb, keys, 0)
		if plan.skill != "":
			await _ai_carry_out(comb, plan, keys)
	if still_running() and comb.alive and current_combatant == combatants.find(comb):
		await advance_turn()


## Where `comb` would call up what `skill` summons: a tile in its reach that
## the summon fits on, as near the other side as can be. (-99999, -99999) for none.
func _summon_spot(comb: Dictionary, skill: SkillDefinition) -> Vector2i:
	var probe := summon_probe(skill, comb.side)
	var best := Vector2i(-99999, -99999)
	var nearest := 999999
	for tile in get_range_tiles(skill, comb.position, comb.get("movement_class", 0), comb):
		if not can_land_on(probe, tile):
			continue
		var gap := _distance_to_nearest_foe(comb, tile)
		if gap < nearest:
			nearest = gap
			best = tile
	return best


## How far `tile` is from the nearest of the other side to `comb`.
func _distance_to_nearest_foe(comb: Dictionary, tile: Vector2i) -> int:
	var best := 999
	for other in combatants:
		if other.get("alive", false) and other.side != comb.side and not other.has("object") and not is_hidden(other):
			best = mini(best, get_position_distance(tile, nearest_tile_of(other, tile)))
	return best


## --- Tethers ---
##
## A spell that is Tethered (SkillDefinition) is held on a tether to its caster:
## `comb.tether` while they hold one - {"skill", "name", "bar", "max",
## "per_turn", "per_damage", "id"}, a bar drawn under their health (the portrait,
## and the map). It frays by Tether Per Turn as each of their turns begins
## (_tether_turn), and by Tether Per Damage for every hundredth of their health
## they lose (lose_hp). Worn through, it snaps (snap_tether): everything the spell
## put on anybody comes off - each entry it added is marked `tether_of` its id
## (use_skill) - and everything it summoned goes. One at a time: tethering
## another lets go of the first. Out of the fight, it goes with them.

## Counts the tethers tied, so each has an id of its own.
var _next_tether_id := 1


## Whether `comb` is holding a spell on a tether.
static func holds_tether(comb: Dictionary) -> bool:
	return comb.has("tether")


## `caster` ties `skill` to themselves, letting go of whatever they held. Its id,
## for marking what it does.
func tie_tether(caster: Dictionary, skill_key: String, skill: SkillDefinition) -> int:
	snap_tether(caster, "%s turns to %s" % [caster.name, skill.name])
	var id := _next_tether_id
	_next_tether_id += 1
	caster["tether"] = {"skill": skill_key, "name": skill.name, "bar": float(skill.tether_strength), "max": float(skill.tether_strength),
		"per_turn": float(skill.tether_per_turn), "per_damage": skill.tether_per_damage, "id": id}
	update_information.emit("[color=yellow]%s[/color] holds %s on a tether.\n" % [caster.name, skill.name])
	update_combatants.emit(combatants)
	return id


## Frays `comb`'s tether by `amount`, snapping it if that wears it through -
## `why` for the log.
func fray_tether(comb: Dictionary, amount: float, why: String):
	if not holds_tether(comb) or amount <= 0.0:
		return
	comb.tether.bar = maxf(comb.tether.bar - amount, 0.0)
	if comb.tether.bar <= 0.0:
		snap_tether(comb, why)
	else:
		update_combatants.emit(combatants)


## As `comb`'s turn begins, a turn's wear on their tether.
func _tether_turn(comb: Dictionary):
	if holds_tether(comb):
		fray_tether(comb, comb.tether.per_turn, "worn through")


## Health `comb` lost, off their tether.
func _tether_hurt(comb: Dictionary, lost: int):
	if not holds_tether(comb) or lost <= 0:
		return
	var most := maxf(float(get_effective_stat(comb, "max_hp")), 1.0)
	fray_tether(comb, 100.0 * float(lost) / most * comb.tether.per_damage, "torn by the pain")


## `comb`'s tether snaps: what the spell it held put on anybody comes off, and
## what it summoned goes.
func snap_tether(comb: Dictionary, why: String):
	if not holds_tether(comb):
		return
	var held: Dictionary = comb.tether
	comb.erase("tether")
	update_information.emit("[color=yellow]%s[/color]'s tether to %s snaps - %s.\n" % [comb.get("name", "?"), held.name, why])
	for other in combatants:
		var effects: Array = other.get("status_effects", [])
		var kept := effects.filter(func(eff): return eff.get("tether_of", -1) != held.id)
		if kept.size() != effects.size():
			other.status_effects = kept
			resync_movement_class(other)
			resync_size(other)
	for summoned in combatants.duplicate():
		if summoned.get("alive", false) and summoned.get("tether_of", -1) == held.id:
			_unsummon(summoned, "is gone with the tether that held it")
	update_combatants.emit(combatants)


## --- Squeezing ---
##
## Somebody with a passive that Squeezes (Erysichthon's Hollow Frame) goes where
## their own square will not fit, folded to fit: a side at a time, and only as
## far as it has to - their square a size narrower or a size shorter (a Large one
## two tiles by one, or one by two), or both when neither will do (one by one).
## They are the size they are all the while; only the room they take changes.
## Each step into a fold costs twice its movement - the walk plans it
## (CController._stance) - and they open out to their square again as soon as it
## fits where they stand. While folded, `comb.fold` is the shape (footprint) and
## `comb.squeezed` is true; they are drawn squashed to it (drawn_scale), and
## their parts fold with them (part_index_at).

## Whether `comb` climbs anywhere (PassiveDefinition.climbs_anywhere - Cyrus's Cat
## Burglar): onto high ground with no climb tile, and up a wall or pillar onto the
## floor above it (CController._height_steps).
func climbs_anywhere(comb: Dictionary) -> bool:
	if comb.is_empty() or comb.has("object"):
		return false
	for passive in active_passives(comb):
		if passive.climbs_anywhere:
			return true
	return false


## Whether `comb` can squeeze (PassiveDefinition.squeezes).
func can_squeeze(comb: Dictionary) -> bool:
	if comb.is_empty() or comb.has("object"):
		return false
	for passive in active_passives(comb):
		if passive.squeezes:
			return true
	return false


## The shapes `comb` at `size` (their own, unless given) can stand in, best
## first: their square, then - for somebody who can squeeze - folded a size
## narrower, a size shorter, and both. Just the square for anybody else, or for
## anybody a tile big, who has nothing to fold.
func fold_shapes(comb: Dictionary, size: int = -1) -> Array:
	if size < 0:
		size = comb.get("size", Sizes.Size.HUMAN)
	var span := Sizes.span(size, comb.get("gigantic_span", 16))
	var shapes: Array = [Vector2i(span, span)]
	if size > Sizes.Size.TINY and can_squeeze(comb):
		var folded := Sizes.span(size - 1, comb.get("gigantic_span", 16))
		if folded < span:
			shapes.append_array([Vector2i(span, folded), Vector2i(folded, span), Vector2i(folded, folded)])
	return shapes


## Whether `comb`, folded to `shape`, would fit anchored at `anchor` (room_for).
func fits_as_shape(comb: Dictionary, anchor: Vector2i, shape: Vector2i) -> bool:
	var was_fold = comb.get("fold")
	comb.fold = shape
	var fits := room_for(comb, anchor)
	if was_fold != null:
		comb.fold = was_fold
	else:
		comb.erase("fold")
	return fits


## A squeezer fitted to where they stand: their square if it fits at their
## anchor, or else the first fold that does (fold_shapes) - said in the log, and
## drawn so, when it changes. True if they are folded now.
func fit_to_room(comb: Dictionary) -> bool:
	if not can_squeeze(comb) or not comb.get("alive", false) or comb.has("riding"):
		return false
	var shapes := fold_shapes(comb)
	var was := footprint(comb)
	var shape: Vector2i = was
	for each in shapes:
		if fits_as_shape(comb, comb.position, each):
			shape = each
			break
	if shape != was:
		if shape == shapes[0]:
			comb.erase("fold")
			update_information.emit("[color=yellow]%s[/color] opens out again.\n" % comb.name)
		else:
			comb.fold = shape
			update_information.emit("[color=yellow]%s[/color] folds itself %d by %d to fit.\n" % [comb.name, shape.x, shape.y])
		var sprite = comb.get("sprite")
		if sprite != null and is_instance_valid(sprite):
			sprite.scale = drawn_scale(comb)
		if controller != null:
			controller.reposition_combatant(comb.position, comb.position)
		update_combatants.emit(combatants)
	comb.squeezed = comb.has("fold")
	return comb.squeezed


## --- Swallowing ---
##
## Swallow (EffectType.SWALLOW - the glutton's Devour) takes whoever the user has
## hold of inside them, whole, if they are smaller: off the board, carried
## wherever it goes, reaching nobody and reached by nobody - Climb's machinery
## ("riding"), with "inside" - and suffering the effect's condition (Swallowed: a
## stomach at work). From inside they can do one thing: hit it, on the part that
## frees them if it has one (the Belly Hole), and Riding's bonus besides. Out
## they come:
##   - alive, through the hole, when a part that Frees The Swallowed breaks
##   - alive, the way they went in, when it is staggered: it heaves them up
##   - alive, when it falls
##   - dead, through the hole, once it has had the effect's Duration of its own
##     turns to digest them (_digest) - a body that can still be stood back up
## Spat out alive, they wear its Spat Out With (bile).

## Whether `skill` swallows whoever it lands on (EffectType.SWALLOW).
static func _swallows(skill: SkillDefinition) -> bool:
	return skill != null and skill.effects.any(func(effect): return effect != null and effect.type == EffectDefinition.EffectType.SWALLOW)


## Whether `comb` is inside somebody (Swallow).
static func is_inside(comb: Dictionary) -> bool:
	return comb.has("inside")


## Whoever has `comb` inside them, or {}.
func swallower_of(comb: Dictionary) -> Dictionary:
	return mount_of(comb) if is_inside(comb) else {}


## Everybody inside `swallower`.
func swallowed_by(swallower: Dictionary) -> Array:
	return riders_of(swallower).filter(func(rider): return is_inside(rider))


## Everybody up on `mount` by climbing (Climb) - not anybody inside it.
func climbers_of(mount: Dictionary) -> Array:
	return riders_of(mount).filter(func(rider): return not is_inside(rider))


## `attacker` swallows `target` (EffectType.SWALLOW), if they have hold of them.
func swallow(attacker: Dictionary, target: Dictionary, effect: EffectDefinition, skill: SkillDefinition):
	if not target.get("alive", false) or target.has("object") or target.get("illusion", false) or is_inside(target):
		return
	if holder_of(target).get("id", -2) != attacker.get("id", -1):
		update_information.emit("[color=yellow]%s[/color] is not in [color=red]%s[/color]'s grip - there is nothing to swallow.\n" % [target.name, attacker.name])
		return
	if target.get("size", Sizes.Size.HUMAN) >= attacker.get("size", Sizes.Size.HUMAN):
		update_information.emit("[color=yellow]%s[/color] is too big for [color=red]%s[/color] to swallow.\n" % [target.name, attacker.name])
		return
	_break_holds_on(target)
	if target.has("riding"):
		dismount(target)
	drop_readied(target, "swallowed")
	drop_declared(target, "swallowed")
	target.erase("intent")
	target["riding"] = attacker.id
	target["inside"] = true
	target["ride_offset"] = Vector2i.ZERO
	_metric("swallowed", {"who": target, "by": attacker})
	target["digest_left"] = maxi(effect.duration, 1)
	var riders: Array = attacker.get("riders", [])
	riders.append(target.id)
	attacker["riders"] = riders
	if effect.condition != null:
		target["inside_condition"] = effect.condition
		replace_matching_tick(target, "condition", effect.condition, 0)
		target.status_effects.append({
			"stat" = "condition",
			"condition" = effect.condition,
			"dot_base" = dot_base_damage(attacker, skill, effect.condition.dot_modifier),
			"duration" = 999,
			"ends_at_start" = false,
			"source_name" = attacker.name,
			"source_id" = attacker.get("id", -1),
			"sound" = skill.sound if skill != null else null,
			"sound_db" = skill.sound_volume_db if skill != null else 0.0,
		})
	var from: Vector2i = target.position
	target.position = attacker.position
	if controller != null:
		controller.reposition_combatant(from, target.position)
		if target == get_current_combatant():
			controller.movement = 0
	var sprite = target.get("sprite")
	if sprite != null and is_instance_valid(sprite):
		sprite.visible = false
	shake_camera(LEVEL_THREE_SHAKE * 0.5)
	update_information.emit("[color=red]%s[/color] swallows [color=yellow]%s[/color] whole! They have %s to get out.\n" % [
		attacker.name, target.name, "until its next turn" if target.digest_left == 1 else "%d of its turns" % target.digest_left])
	cue("swallowed")
	update_combatants.emit(combatants)


## Where whoever comes out of `swallower` lands: behind it - away from the
## nearest of the other side - through the hole, or in front, heaved up.
func _out_of(swallower: Dictionary, rider: Dictionary, through_the_hole: bool) -> Vector2i:
	var rect := rect_of(swallower)
	var centre := Vector2(rect.position) + Vector2(rect.size) / 2.0
	var away := Vector2.DOWN
	var nearest := {}
	for other in combatants:
		if other.alive and other.get("side", -1) != swallower.side and not other.has("riding") and not other.has("object"):
			if nearest.is_empty() or get_distance(swallower, other) < get_distance(swallower, nearest):
				nearest = other
	if not nearest.is_empty():
		var towards := Vector2(nearest.position) + Vector2.ONE * 0.5 - centre
		if towards.length() > 0.01:
			away = towards.normalized()
	if through_the_hole:
		away = -away
	var reach := float(rect.size.x) / 2.0 + 1.0
	var wanted := Vector2i((centre + away * reach).floor())
	return _nearest_free_tile(rider, wanted, 6)


## `rider` comes out of `swallower`: alive (and wearing its Spat Out With), or
## not - `through_the_hole` behind it, or heaved up in front.
func _release(rider: Dictionary, swallower: Dictionary, through_the_hole: bool, alive: bool):
	dismount(rider, _out_of(swallower, rider, through_the_hole))
	if alive and rider.alive:
		var bile: ConditionDefinition = swallower.get("spat_out_with")
		if bile != null:
			put_condition(rider, bile, bile.duration, swallower.name, true, swallower.get("id", -1))


## Everybody inside `swallower` let out alive - `how` says how, for the log.
func _free_the_swallowed(swallower: Dictionary, through_the_hole: bool, how: String):
	for rider in swallowed_by(swallower):
		_release(rider, swallower, through_the_hole, true)
		update_information.emit("[color=yellow]%s[/color] %s.\n" % [rider.name, how])
		_metric("freed", {"who": rider, "by": swallower, "how": how})


## `swallower`'s turn begins: whoever is inside is one of its turns nearer to
## being digested - and at none, they are, and fall out through the hole dead.
func _digest(swallower: Dictionary):
	for rider in swallowed_by(swallower):
		rider.digest_left = rider.get("digest_left", 1) - 1
		if rider.digest_left > 0:
			update_information.emit("[color=yellow]%s[/color] is being digested - %s left to get out.\n" % [
				rider.name, "one more of its turns" if rider.digest_left == 1 else "%d of its turns" % rider.digest_left])
			continue
		update_information.emit("[color=red]%s[/color] is digested - and what is left falls out of [color=red]%s[/color].\n" % [rider.name, swallower.name])
		_metric("digested", {"who": rider, "by": swallower})
		_release(rider, swallower, true, false)
		rider.hp = 0
		combatant_die(rider)
		cue("digested")
		if combat_over:
			return


## Where a blow from inside `attacker`'s swallower lands, for its parts: the
## part that frees them, if it has one - they claw at the belly from inside.
## `aimed` otherwise.
func _aim_from_inside(attacker: Dictionary, target: Dictionary, aimed: Vector2i) -> Vector2i:
	if not is_inside(attacker) or swallower_of(attacker).get("id", -2) != target.get("id", -1):
		return aimed
	for i in range(target.get("parts", []).size() - 1, -1, -1):
		var part: BodyPartDefinition = target.parts[i]
		if part.frees_the_swallowed and not part_broken(target, i) and not part.tiles.is_empty():
			return target.position + _folded(target, part.tiles[0])
	return aimed


## --- Gluttony ---
##
## Somebody who eats (CombatantDefinition.eats) eats, free, everything edible
## within Eat Reach as their turn begins and again once they have moved
## (ai_glutton): food on the map (BattleObjectDefinition's Food - gone once eaten,
## and doing what it says to them), and the bodies of their own side, or of the
## other, as Eats says - gone, nobody stands them back up. A meal (nourishing
## food, or a body) heals them by Meal Heals, grows back every part that grows
## back when they eat, and does their Fed Effects to them. A phase can have them
## eat themselves (BossPhase.eats_itself) when there is nothing else in reach.
## Parts grow back on a clock too (BodyPartDefinition.regrows_after, _regrow_clock).

const EATS_FOOD := 1
const EATS_OWN_FALLEN := 2
const EATS_OTHER_FALLEN := 4


## Everything `comb` would eat where they stand.
func food_within(comb: Dictionary) -> Array:
	var found := []
	var wants: int = comb.get("eats", 0)
	if wants == 0:
		return found
	var reach: int = comb.get("eat_reach", 1)
	for other in combatants:
		if other == comb or rect_gap(rect_of(comb), rect_of(other)) > reach:
			continue
		if other.has("object"):
			if other.alive and wants & EATS_FOOD and other.object.edible:
				found.append(other)
		elif _a_body(other):
			var own: bool = other.get("side", -1) == comb.get("side", -2)
			if (own and wants & EATS_OWN_FALLEN) or (not own and wants & EATS_OTHER_FALLEN):
				found.append(other)
	return found


## Whether `comb` is a body lying on the field - fallen or knocked out, not fled
## or given up, not an image, and not eaten.
func _a_body(comb: Dictionary) -> bool:
	return not comb.alive and comb.get("taken", "knocked_out") == "knocked_out" and not comb.get("illusion", false) \
		and not comb.get("eaten", false) and not comb.has("riding")


## `comb` eats everything in reach. True when they ate anything.
func feed(comb: Dictionary) -> bool:
	var ate := false
	for food in food_within(comb):
		if not comb.alive or combat_over:
			break
		eat(comb, food)
		ate = true
	return ate


## `comb` eats `food` - something on the map, or a body.
func eat(comb: Dictionary, food: Dictionary):
	cue("ate:%s" % food.name)
	if not food.has("object"):
		food["eaten"] = true
		var remains = food.get("sprite")
		if remains != null and is_instance_valid(remains):
			remains.visible = false
		update_information.emit("[color=red]%s[/color] devours what is left of [color=yellow]%s[/color].\n" % [comb.name, food.name])
		_meal(comb)
		return
	var object: BattleObjectDefinition = food.object
	update_information.emit("[color=red]%s[/color] devours the [color=orange]%s[/color].\n" % [comb.name, food.name])
	food.alive = false
	var sprite = food.get("sprite")
	if sprite != null and is_instance_valid(sprite):
		sprite.set_dead()
	combatant_died.emit(food)
	if object.eaten_damage > 0 or object.eaten_condition != null:
		hit_by_the_arena(comb, object.eaten_damage, object.eaten_damage_type, object.eaten_condition, object.eaten_condition_turns, 0.0, food.name)
	if not comb.alive or comb.hp <= 0:
		if comb.alive:
			combatant_die(comb)
		return
	if object.eaten_stagger > 0.0:
		add_stagger(comb, object.eaten_stagger, "eating")
	if object.eaten_breaks != "":
		for i in comb.get("parts", []).size():
			if comb.parts[i].name == object.eaten_breaks and not part_broken(comb, i):
				_break_part(comb, i)
	if object.nourishing:
		_meal(comb)
	update_combatants.emit(combatants)


## A meal for `comb`: healed by their Meal Heals (`heals` - not when they ate
## themselves), what grows back when they eat grown back, and their Fed Effects.
func _meal(comb: Dictionary, heals: bool = true):
	var share: float = comb.get("meal_heals", 0.0)
	if heals and share > 0.0:
		var most: int = get_effective_stat(comb, "max_hp")
		var amount := mini(roundi(most * share), most - comb.hp)
		if amount > 0:
			comb.hp += amount
			float_number(comb, "+%d" % amount, Color("7fe08a"))
			update_information.emit("[color=red]%s[/color] is fed - it heals %d.\n" % [comb.name, amount])
	for i in comb.get("parts", []).size():
		if comb.parts[i].regrows_when_eating and part_broken(comb, i):
			_regrow_part(comb, i)
	for effect in comb.get("fed_effects", []):
		if effect != null and comb.alive:
			apply_effect(comb, comb, effect, null, false)
	update_combatants.emit(combatants)


## `comb`, with nothing else to eat, eating itself (BossPhase.eats_itself): a
## meal that costs it its own flesh and gives none back.
func _eat_itself(comb: Dictionary):
	var share: float = comb.get("eats_itself", 0.0)
	if share <= 0.0 or not comb.alive:
		return
	var bite := maxi(roundi(get_effective_stat(comb, "max_hp") * share), 1)
	update_information.emit("[color=red]%s[/color] finds nothing left to eat - and tears into itself (%d).\n" % [comb.name, bite])
	lose_hp(comb, bite, Damage.Type.PHYSICAL)
	show_damage(comb, bite, Damage.Type.PHYSICAL, true)
	cue("ate:itself")
	if comb.hp <= 0:
		combatant_die(comb)
		return
	_meal(comb, false)


## As `comb`'s turn begins (advance_turn): whoever is inside them a turn nearer
## digested, the parts growing back a turn nearer whole, and - free - a meal of
## whatever is in reach, or of themselves.
func _glutton_turn_begins(comb: Dictionary):
	if not comb.alive:
		return
	_digest(comb)
	_regrow_clock(comb)
	if comb.get("eats", 0) == 0 or combat_over:
		return
	if not feed(comb):
		_eat_itself(comb)


## A turn off every part of `comb`'s that grows back on a clock; whole again at none.
func _regrow_clock(comb: Dictionary):
	var clocks: Dictionary = comb.get("regrowing", {})
	for index in clocks.keys():
		clocks[index] -= 1
		if clocks[index] <= 0:
			_regrow_part(comb, index)


## `comb`'s part `index` grows back whole, and whatever breaking it did is undone.
func _regrow_part(comb: Dictionary, index: int):
	if not part_broken(comb, index):
		return
	var part: BodyPartDefinition = comb.parts[index]
	comb.parts_broken.erase(index)
	comb.get("regrowing", {}).erase(index)
	comb.parts_hp[index] = maxi(roundi(comb.max_hp * part.health_share), 1)
	match part.when_broken:
		BodyPartDefinition.Broken.ROOTED:
			for i in range(comb.status_effects.size() - 1, -1, -1):
				var entry: Dictionary = comb.status_effects[i]
				if entry.get("condition") == CRIPPLED and entry.get("source_name", "") == part.name:
					comb.status_effects.remove_at(i)
		BodyPartDefinition.Broken.DISARMED:
			for key in part.disarms:
				if not comb.skill_list.has(key):
					comb.skill_list.append(key)
	update_information.emit("[color=red]%s[/color]'s %s grow%s back!\n" % [comb.name, part.name.to_lower(), "" if part.name.ends_with("s") else "s"])
	float_number(comb, "%s regrown" % part.name, PART_COLOUR)
	update_combatants.emit(combatants)
	if controller != null:
		controller.queue_redraw()


## --- Reactions ---
##
## A reactive skill (SkillDefinition.is_reactive) goes off when what it reacts
## to (reacts_when) happens, as its user's one reaction between their own turns;
## a readied move ("Ready") goes off the same way, on the one trigger it was
## readied for. The player is asked about their own; the AI takes the best it
## has. Leaving reach is check_reactive_skills, as it always was. The rest come
## through _react, from:
##   each step of a move - Enters Reach, and Ready's area (_react_to_step);
##   use_skill, as a spell is cast, before any of it happens - Casts
##     (_react_to_casting), where InstaHack can cancel it (cancel_casting);
##   use_skill, once its targets are known and before anything lands -
##     Foreseen Blow, Targeted, Ally Attacked (_react_before);
##   use_skill, once it has landed - Struck (_react_after);
##   declare - Declares.
## Who a reaction lands on is _reaction_target: whoever it protects, for a skill
## aimed at allies, or else the enemy who set it off - in reach and in sight.

const Trigger := SkillDefinition.Trigger


## Whether `reactor` is in a state to react at all: standing, their reaction
## unspent, not hidden (nobody hidden gives themselves away by striking), and not
## sick, stunned, confused or deceived.
func _can_react(reactor: Dictionary) -> bool:
	if not reactor.get("alive", false) or reactor.get("reaction_used", false) \
			or reactor.get("illusion", false) or reactor.has("object") or is_hidden(reactor) or is_inside(reactor):
		return false
	for restriction in ["prevents_reactions", "skips_turn", "confuses", "turns_on_own_side"]:
		if has_restriction(reactor, restriction):
			return false
	return true


## Who `skill`, as `reactor`'s reaction, lands on: `protected` for a skill aimed
## at allies, `enemy` for anything else - or {} when that one is beyond its
## reach, out of sight or not to be got hold of.
func _reaction_target(reactor: Dictionary, skill: SkillDefinition, enemy: Dictionary, protected: Dictionary) -> Dictionary:
	var target: Dictionary = protected if skill.targets_ally else enemy
	if target.is_empty() or not target.get("alive", false):
		return {}
	if is_same(target, reactor):
		return target
	if (target.get("side", -1) == reactor.get("side", -1)) != skill.targets_ally:
		return {}
	# On another floor, only for what reaches through a gap in it ("Heights").
	var gap = reach_gap(reactor, target, skill)
	if gap < skill.min_range or gap > effective_max_range(reactor, skill):
		return {}
	if not _reaches_through_floors(reactor, target):
		return {}
	if skill.respects_blocking and not sees_tile(reactor, nearest_across(target, reactor.position), target):
		return {}
	if _grip_refusal(reactor, skill, target) != "":
		return {}
	return target


## Every reaction `trigger` sets off. `source` is whoever set it off - an enemy,
## or for the triggers either side can (SkillDefinition.EITHER_SIDE), an ally of
## whoever reacts, as each skill's Set Off By allows - and `why` what happened,
## for the log and the question. For each who might react, `protected_for` says
## whom it is happening to (when not given: the ally who set it off, or
## themselves), and `fits` whether a skill of theirs is placed to react to it at
## all - the reach a mover just stepped into, say - given the skill and what
## they readied ({} for a reactive skill). Each reacts once at most.
func _react(trigger: int, source: Dictionary, why: String, protected_for: Callable = Callable(), fits: Callable = Callable()):
	if source.is_empty():
		return
	for reactor in combatants.duplicate():
		# Over once whoever set it off is down - or the fight itself is.
		if not still_running() or combat_over or not source.get("alive", false):
			return
		if is_same(reactor, source) or not _can_react(reactor):
			continue
		var ally: bool = reactor.get("side", -1) == source.get("side", -1)
		if not ally and is_hidden(source):
			# Nobody reacts to an enemy they cannot see.
			continue
		var protected: Dictionary = protected_for.call(reactor) if protected_for.is_valid() else (source if ally else reactor)
		var options := []
		for key in reactor.skill_list:
			var skill: SkillDefinition = SkillDatabase.skills.get(key)
			if skill == null or not skill.reacts_to(trigger):
				continue
			if not SkillDefinition.sets_off(trigger, skill.set_off_by, reactor.side, source.side):
				continue
			if not can_afford_skill(reactor, skill) or not meets_level_for(reactor, skill):
				continue
			if fits.is_valid() and not fits.call(reactor, skill, {}):
				continue
			var target := _reaction_target(reactor, skill, source, protected)
			if not target.is_empty():
				options.append({"key": key, "skill": skill, "target": target, "readied": false})
		var readied: Dictionary = reactor.get("readied", {})
		if not readied.is_empty() and readied.trigger == trigger \
				and SkillDefinition.sets_off(trigger, readied.get("by", SkillDefinition.SetOffBy.ENEMIES), reactor.side, source.side):
			var skill: SkillDefinition = SkillDatabase.skills.get(readied.skill)
			if skill != null and (not fits.is_valid() or fits.call(reactor, skill, readied)):
				var target := _reaction_target(reactor, skill, source, protected)
				# An area they marked is watched all over, out to its edge - its
				# middle was in reach when they marked it. A clear line it needs,
				# and whoever stepped in has to be somebody the move is for.
				if target.is_empty() and trigger == Trigger.ENTERS_AREA and source.get("alive", false) \
						and ally == skill.targets_ally and _reaches_through_floors(reactor, source) \
						and (not skill.respects_blocking or sees_tile(reactor, nearest_across(source, reactor.position), source)):
					target = source
				if not target.is_empty():
					options.append({"key": readied.skill, "skill": skill, "target": target, "readied": true})
		if options.is_empty():
			continue
		var picked := await _choose_option(reactor, source, options, why)
		if picked < 0 or not still_running():
			continue
		var option: Dictionary = options[picked]
		if option.readied:
			await _fire_readied(reactor, option.target, why)
		else:
			await use_reactive_skill(option.key, reactor, option.target, nearest_across(option.target, reactor.position), why)


## Which of `options` `reactor` takes, or -1 to let it go. The player is asked;
## the AI takes whichever it rates highest.
func _choose_option(reactor: Dictionary, enemy: Dictionary, options: Array, why: String) -> int:
	var labels: Array = options.map(func(option): return ("Ready: %s" if option.readied else "%s") % option.skill.name)
	if reactor.side != 0 or reaction_prompt == null:
		var best := 0
		var most := -INF
		for i in options.size():
			var worth := ai_target_value(reactor, options[i].target, options[i].skill)
			if worth > most:
				most = worth
				best = i
		return best
	if options.size() == 1:
		var yes: bool = await reaction_prompt.ask(reactor, options[0].target, options[0].skill, why, labels[0])
		if not yes:
			update_information.emit("[color=yellow]%s[/color] holds their reaction.\n" % reactor.name)
		return 0 if yes else -1
	var picked: int = await reaction_prompt.choose(reactor, enemy, options.map(func(option): return option.skill), why, labels)
	if picked < 0 or picked >= options.size():
		update_information.emit("[color=yellow]%s[/color] holds their reaction.\n" % reactor.name)
		return -1
	return picked


## A mover's step from `from` to `to`, on their own turn: into somebody's reach
## (Enters Reach), or into an area somebody marked (Ready).
func _react_to_step(mover: Dictionary, from: Vector2i, to: Vector2i):
	if mover.get("reactions_suppressed", false) or not mover.get("alive", false):
		return
	var stepped_in := func(reactor: Dictionary, skill: SkillDefinition, readied: Dictionary) -> bool:
		if readied.get("trigger", 0) == Trigger.ENTERS_AREA:
			return false
		var before = reach_gap(reactor, mover, skill, from)
		var after = reach_gap(reactor, mover, skill, to)
		var reach := effective_max_range(reactor, skill)
		return not (before >= skill.min_range and before <= reach) and after >= skill.min_range and after <= reach
	await _react(Trigger.ENTERS_REACH, mover, "%s steps into reach" % mover.name, Callable(), stepped_in)
	if not mover.get("alive", false):
		return
	var into_area := func(_reactor: Dictionary, _skill: SkillDefinition, readied: Dictionary) -> bool:
		var area: Array = readied.get("area", [])
		if area.is_empty():
			return false
		var was_in := tiles_of(mover, from).any(func(tile): return tile in area)
		var now_in := tiles_of(mover, to).any(func(tile): return tile in area)
		return now_in and not was_in
	await _react(Trigger.ENTERS_AREA, mover, "%s steps into the watched cone" % mover.name, Callable(), into_area)


## Whether `skill` is a spell: something that normally takes a gate - cast
## through one, or sealed in a Gate Nade.
static func is_spell(skill: SkillDefinition) -> bool:
	if skill is GateNadeDefinition and skill.cast != null:
		return skill.cast.spell_slot_level > 0
	return skill != null and skill.spell_slot_level > 0


## Whether `skill` cancels a spell being cast (EffectType.CANCEL_CASTING).
static func _cancels_casting(skill: SkillDefinition) -> bool:
	return skill.all_effects().any(func(effect): return effect != null and effect.type == EffectDefinition.EffectType.CANCEL_CASTING)


## `attacker` casting `skill_key`, a spell: whoever sees it can answer it
## (Casts), before any of it happens. True when one of them cancelled it
## (cancel_casting) - and once it is, there is nothing left to answer.
func _react_to_casting(attacker: Dictionary, skill_key: String, skill: SkillDefinition) -> bool:
	attacker["casting"] = skill_key
	var answerable := func(reactor: Dictionary, reacting: SkillDefinition, _readied: Dictionary) -> bool:
		if attacker.has("cast_cancelled"):
			return false
		# Spells locked against hacking (a Hack's Locks For Good) can't be.
		if _cancels_casting(reacting) and attacker.get("hack_locked", false):
			return false
		return sees_tile(reactor, nearest_tile_of(attacker, reactor.position), attacker)
	await _react(Trigger.CASTS, attacker, "%s casts %s" % [attacker.name, skill.name], Callable(), answerable)
	attacker.erase("casting")
	return attacker.erase("cast_cancelled")


## `attacker` cancels the spell `target` is in the middle of casting
## (EffectType.CANCEL_CASTING - InstaHack's): it comes to nothing. Only while
## they cast it - a reaction to Casts - and not once their spells are locked
## against hacking.
func cancel_casting(attacker: Dictionary, target: Dictionary):
	var casting: SkillDefinition = SkillDatabase.skills.get(target.get("casting", ""))
	if casting == null:
		update_information.emit("[color=red]%s[/color] is casting nothing to cancel.\n" % target.name)
		return
	if target.get("hack_locked", false):
		update_information.emit("[color=red]%s[/color]'s spells are locked against hacking now.\n" % target.name)
		return
	target["cast_cancelled"] = true
	update_information.emit("[color=yellow]%s[/color] cancels [color=red]%s[/color]'s %s - it comes to nothing!\n" % [
		attacker.name, target.name, casting.name])


## `attacker`'s `skill`, cancelled as they cast it: none of it happens, but
## what it cost is spent all the same - the gate (or the Gate Nade), and the
## action.
func _cast_cancelled(attacker: Dictionary, skill_key: String, skill: SkillDefinition, end_turn_after: bool, as_secondary: bool):
	_pay_for_cast(attacker, skill)
	attacker["amplify"] = 0
	if is_item(skill_key):
		consume_item(attacker, skill_key)
	await _hack_spends_action(attacker, as_secondary, end_turn_after)


## Before `attacker`'s `skill` lands on `targets`: a blow foreseen coming as
## foreseen, somebody about to be hit, an ally of theirs.
func _react_before(attacker: Dictionary, skill: SkillDefinition, skill_key: String, targets: Array):
	var foreseen: Dictionary = attacker.get("acting_foreseen", {})
	var victims: Array = targets.filter(func(target): return target.get("side", -1) != attacker.get("side", -1) \
		and not target.has("object") and not target.get("illusion", false))
	var victim_of := func(reactor: Dictionary) -> Dictionary:
		# Themselves, if it is them; else the nearest of theirs it is aimed at.
		for victim in victims:
			if is_same(victim, reactor):
				return victim
		var nearest := {}
		for victim in victims:
			if victim.get("side", -1) == reactor.get("side", -1) and (nearest.is_empty() \
					or distance_to(reactor, victim.position) < distance_to(reactor, nearest.position)):
				nearest = victim
		return nearest
	if not foreseen.is_empty() and foreseen.get("skill", "") == skill_key:
		await _react(Trigger.FORESEEN_BLOW, attacker, "the blow that was foreseen comes", victim_of)
	if not _hostile(skill) or victims.is_empty():
		return
	for victim in victims:
		if not attacker.get("alive", false):
			return
		var only_them := func(reactor: Dictionary, _skill: SkillDefinition, _readied: Dictionary) -> bool:
			return is_same(reactor, victim)
		await _react(Trigger.TARGETED, attacker, "%s is about to hit %s" % [attacker.name, victim.name], Callable(), only_them)
	var not_them := func(reactor: Dictionary, _skill: SkillDefinition, _readied: Dictionary) -> bool:
		return not victims.any(func(victim): return is_same(victim, reactor)) \
			and victims.any(func(victim): return victim.get("side", -1) == reactor.get("side", -1))
	if attacker.get("alive", false):
		await _react(Trigger.ALLY_ATTACKED, attacker, "%s is about to hit %s" % [attacker.name,
			", ".join(victims.map(func(victim): return victim.name))], victim_of, not_them)


## After `attacker`'s skill has hit `struck` (whoever it hurt).
func _react_after(attacker: Dictionary, struck: Array):
	for victim in struck:
		if not attacker.get("alive", false) or not victim.get("alive", false):
			continue
		var only_them := func(reactor: Dictionary, _skill: SkillDefinition, _readied: Dictionary) -> bool:
			return is_same(reactor, victim)
		await _react(Trigger.STRUCK, attacker, "%s hits %s" % [attacker.name, victim.name], Callable(), only_them)
	for victim in struck:
		await _react_watched_hit(attacker, victim)


## Whoever readied something for when `victim` is hit (HIT_IN_SIGHT), with them
## still in sight: off it goes - a hostile move at `victim` if they are of the
## other side, else at `attacker`; a move for allies at `victim`. Out of sight,
## or nobody it could land on in reach, and it waits on.
func _react_watched_hit(attacker: Dictionary, victim: Dictionary):
	for reactor in combatants.duplicate():
		if not still_running() or combat_over:
			return
		var readied: Dictionary = reactor.get("readied", {})
		if readied.is_empty() or readied.trigger != Trigger.HIT_IN_SIGHT or readied.get("watched", -1) != victim.get("id", -2):
			continue
		if is_same(reactor, attacker) or not _can_react(reactor):
			continue
		if not sees_tile(reactor, nearest_across(victim, reactor.position), victim):
			continue
		var skill: SkillDefinition = SkillDatabase.skills.get(readied.skill)
		if skill == null:
			continue
		var at: Dictionary = {}
		if skill.targets_ally:
			at = victim if victim.get("side", -1) == reactor.get("side", -2) else {}
		elif victim.get("side", -1) != reactor.get("side", -2):
			at = victim
		elif attacker.get("side", -1) != reactor.get("side", -2):
			at = attacker
		if at.is_empty() or not at.get("alive", false):
			continue
		if _reaction_target(reactor, skill, at, at).is_empty():
			continue
		await _fire_readied(reactor, at, "%s is hit" % victim.name)


## --- Ready ---
##
## A move held back for the right moment: its user's main action now - spent,
## with any gate it costs, whether or not the moment ever comes - to go off as
## their reaction the first time its trigger happens before their next turn.
## Any trigger a reactive skill can have, or, for something ranged, somebody
## stepping into an area they mark: a great cone (READY_CONE_TILES long) out of
## them towards where they point, over every tile they can see from there past
## the walls (the designer, 2026-10-29: it respects blocking) - or somebody they
## choose, in sight, being hit (HIT_IN_SIGHT, the designer 2026-10-29): a
## hostile move then goes at them if they are the other side's, else at whoever
## hit them, and a move for allies at them (_react_watched_hit). Out of sight
## when it happens, it does not go off. The player readies through the HUD's
## Ready button (ui/ready_picker.gd). Like Set Off By on a
## skill, `by` says who sets it off where either side can: an enemy (a shot at
## whoever comes through the door), an ally (a heal for whoever steps into the
## light), or either. Lost at the start of their next turn if it never went off.
## Stunned, confused or deceived, it does not go off; held (Grappled), it is
## lost only if it is a move they could not then make.

## How far out a readied cone watches, in tiles - a PROPOSAL value: "very, very
## big" (the designer, 2026-10-29). It once was a diamond of 4 round a point.
const READY_CONE_TILES := 12
const NO_AREA := Vector2i(-99999, -99999)


## Why `comb` cannot ready `skill_key` for `trigger` set off by `by` (SetOffBy)
## (and, for the area, around `centre`), or "" when they can.
func ready_refusal(comb: Dictionary, skill_key: String, trigger: int, centre: Vector2i = NO_AREA, by: int = SkillDefinition.SetOffBy.ENEMIES, watched: Dictionary = {}) -> String:
	var skill: SkillDefinition = SkillDatabase.skills.get(skill_key)
	if skill == null or not comb.get("skill_list", []).has(skill_key):
		return "%s does not know that" % comb.get("name", "They")
	if comb.has("readied"):
		return "%s already has %s readied" % [comb.name, SkillDatabase.skills[comb.readied.skill].name]
	if comb.get("skill_used_this_turn", false):
		return "%s has already used their main action" % comb.name
	if skill.declared or skill.throws or _hacks(skill):
		return "%s can't be readied" % skill.name
	if skill.reaction_only:
		return "%s goes off by itself - it can't be readied" % skill.name
	if not meets_level_for(comb, skill):
		return "%s has not learned %s yet" % [comb.name, skill.name]
	if not can_afford_skill(comb, skill):
		return "%s has no %s left for %s" % [comb.name, Stats.short_gate_name(skill.spell_slot_level), skill.name]
	if not SkillDefinition.TRIGGER_NAMES.has(trigger):
		return "Choose what it waits for"
	if trigger == Trigger.ENTERS_AREA:
		# Something ranged, and for whoever will set it off: what hurts for
		# enemies, what is aimed at allies for allies.
		var suits: bool = (_hostile(skill) and by != SkillDefinition.SetOffBy.ALLIES) \
			or (skill.targets_ally and by != SkillDefinition.SetOffBy.ENEMIES)
		if is_melee(skill) or not suits:
			return "Only something ranged that hurts can watch an area for enemies, or something for allies watch it for them"
		if centre == NO_AREA or (controller != null and not controller.is_on_map(centre)):
			return "Choose where the area goes"
		# The point only says which way the cone goes: anywhere off them will do.
		if tiles_of(comb).has(centre):
			return "Point it away from %s" % comb.name
		# On another floor, through a gap in whatever floor is between ("Heights").
		if not floors_open_between(nearest_across(comb, centre), centre):
			return "The floor is in the way"
		if ready_area(comb, centre).is_empty():
			return "%s can't see anything that way" % comb.name
	if trigger == Trigger.HIT_IN_SIGHT:
		if watched.is_empty() or not watched.get("alive", false) or is_same(watched, comb):
			return "Choose who to watch"
		if not sees_tile(comb, nearest_across(watched, comb.position), watched):
			return "%s can't see %s" % [comb.name, watched.name]
	return ""


## Readies `skill_key` for `trigger`, set off by `by` (SetOffBy - an enemy
## unless the trigger is one either side can set off), around `centre` for an
## area. The main action and any gate are spent now. False, and nothing spent,
## when it can't be.
func ready_action(comb: Dictionary, skill_key: String, trigger: int, centre: Vector2i = NO_AREA, by: int = SkillDefinition.SetOffBy.ENEMIES, watched: Dictionary = {}) -> bool:
	if not trigger in SkillDefinition.EITHER_SIDE:
		by = SkillDefinition.SetOffBy.ENEMIES
	var refused := ready_refusal(comb, skill_key, trigger, centre, by, watched)
	if refused != "":
		update_information.emit(refused + ".\n")
		return false
	var skill: SkillDefinition = SkillDatabase.skills[skill_key]
	var spent = spend_slot_for(comb, skill)
	if spent > 0:
		update_information.emit("[color=yellow]%s[/color] spends %s.\n" % [comb.name, Stats.short_gate_name(spent)])
		_metric("gate", {"who": comb, "gate": spent, "skill": skill})
	comb.skill_used_this_turn = true
	comb["readied"] = {"skill": skill_key, "trigger": trigger, "centre": centre, "by": by,
		"area": ready_area(comb, centre) if trigger == Trigger.ENTERS_AREA else [],
		"watched": watched.get("id", -1)}
	var when := SkillDefinition.trigger_name(trigger, by)
	if trigger == Trigger.HIT_IN_SIGHT:
		when = "%s is hit" % watched.name
	update_information.emit("[color=yellow]%s[/color] readies %s - for when %s.\n" % [comb.name, skill.name, when])
	update_combatants.emit(combatants)
	if controller != null:
		controller.queue_redraw()
	if game_ui != null and comb.side == 0 and game_ui.has_method("refresh_action_buttons"):
		game_ui.refresh_action_buttons()
	return true


## The tiles `comb`'s readied cone pointed at `centre` watches: out of the tile
## of theirs nearest it, READY_CONE_TILES long, on the floor `centre` is on, and
## only what they see from there past the walls - the ground and every breakable
## wall standing, not the bodies, who walk on (at the moment it goes off, a move
## that respects blocking still wants a clear line - _react). Pointed at another
## floor, it lies over the same ground there, seen through the gaps between.
func ready_area(comb: Dictionary, centre: Vector2i) -> Array:
	var from := nearest_across(comb, centre)
	var on := floor_of(centre)
	var across := _floored and floor_of(from) != on
	var mover_class := terrain_class(comb)
	var size: int = comb.get("size", Sizes.Size.HUMAN)
	var walls = null
	if controller != null and not heights_in_play():
		walls = _SightGrid.new(controller, combatants.filter(func(other): return is_wall(other)))
	var nowhere := Vector2i(-99999, -99999)
	var own := tiles_of(comb)
	var tiles := []
	var reals := get_cone_tiles(real_of(from), real_of(centre), READY_CONE_TILES)
	# Whatever way it leans, the tile pointed at is in it.
	if not reals.has(real_of(centre)):
		reals.append(real_of(centre))
	for real in reals:
		var tile: Vector2i = tile_on(on, real) if _floored else real
		if tile == nowhere or own.has(tile):
			continue
		if controller != null and (not controller.is_on_map(tile) or _aim_blocked(tile, mover_class)):
			continue
		if across and not floors_open_between(from, tile):
			continue
		if walls != null:
			if not walls.clear(from, tile, mover_class, size):
				continue
		elif controller != null and not has_line_of_sight(from, tile, mover_class, size, get_combatant_at(tile)):
			continue
		tiles.append(tile)
	return tiles


## Loses what `comb` readied, saying why - or not, when `quiet`.
func drop_readied(comb: Dictionary, why: String, quiet: bool = false):
	if not comb.has("readied"):
		return
	if not quiet:
		update_information.emit("[color=yellow]%s[/color]'s readied %s comes to nothing - %s.\n" % [
			comb.name, SkillDatabase.skills[comb.readied.skill].name, why])
	comb.erase("readied")
	update_combatants.emit(combatants)
	if controller != null:
		controller.queue_redraw()


## Whether what `comb` readied is a move they could not make where they are held:
## one that takes them onto somebody (Climb). Anything else - a swing, a shot, a
## spell, even a blink that would break the hold - they still can.
func _ready_impossible(comb: Dictionary) -> bool:
	var readied: Dictionary = comb.get("readied", {})
	if readied.is_empty() or not has_restriction(comb, "prevents_movement"):
		return false
	var skill: SkillDefinition = SkillDatabase.skills.get(readied.skill)
	return skill != null and skill.all_effects().any(func(effect): return effect != null and effect.type == EffectDefinition.EffectType.CLIMB)


## What `reactor` readied going off at `target`, as their reaction: the gate was
## spent when it was readied. An area skill bursts on them, catching whoever
## else is there.
func _fire_readied(reactor: Dictionary, target: Dictionary, why: String):
	var readied: Dictionary = reactor.readied
	reactor.erase("readied")
	var skill: SkillDefinition = SkillDatabase.skills[readied.skill]
	reactor.reaction_used = true
	update_information.emit("[color=yellow]%s[/color]'s readied %s goes off - %s!\n" % [reactor.name, skill.name, why])
	if controller != null:
		controller.queue_redraw()
		controller.action_locked = true
	if game_ui != null:
		game_ui.lock_action_buttons()
	var sprite = reactor.get("sprite")
	if sprite != null and is_instance_valid(sprite):
		await sprite.play_skill_and_wait(skill.animation)
	if not still_running():
		return
	play_skill_sound(skill)
	if controller != null:
		controller.action_locked = false
	if game_ui != null:
		game_ui.refresh_action_buttons()
	if not reactor.alive or not target.alive:
		return
	var victims := [target]
	if aoe_radius_of(reactor, skill) > 0:
		var aim := nearest_across(target, reactor.position)
		var tiles = get_impact_tiles(skill, nearest_across(reactor, aim), aim, terrain_class(reactor), reactor.get("size", Sizes.Size.HUMAN), reactor)
		victims = get_targets_in_tiles(tiles, reactor, skill.targets_ally, skill.affects_both_sides)
	for victim in victims:
		if victim.get("alive", false):
			_land_reaction(reactor, skill, victim)


## --- Readying, for the AI ---
##
## Per creature (CombatantDefinition.ai_readies), and only when there is nothing
## it could hit this turn: as a turn ends with its main action unused
## (advance_turn, through ai_turn_live, which ai_process sets), or - for a guard
## - instead of leaving its post to chase (ai_process). A gate it would spend
## has to be one it can spare: never its last casting. Whatever it readies is
## the move worth most against whoever is likely to set it off (_ai_ready_pick -
## ai_target_value, the planner's own arithmetic), not merely the one that
## reaches furthest (the designer, 2026-10-29: smarter readies - PROPOSAL).
##   Counters Casters - somebody of the party who casts, in sight and within
##     reach of where it stands (a reaction does not walk): readied for when
##     they cast.
##   Waits For The Hidden - somebody of the party out of sight: readied for
##     whoever steps into its reach. A hidden one steps in seen, or not at all.
##   Covers The Approach - its cone (ready_area) pointed down the way the party
##     has to come, never over anybody already in it, who would not "step in"
##     (_ai_approach_aim); with nowhere like that, its reach.
##   Guards Its Post - its cone over its post (the thing on the map beside it -
##     a bell - or the tile it started on), or the way they would come, or else
##     its own reach.
##   Protects Its Own - the ally of its in sight most at risk, watched: whoever
##     hits them is hit back (HIT_IN_SIGHT), if they would be within reach.

enum AiReady { APPROACH = 1, GUARDS = 2, CASTERS = 4, HIDDEN = 8, PROTECTS = 16 }

## How near a thing on the map has to be to be the one a guard stands over.
const GUARD_OBJECT_TILES := 6


## Readies something for `comb`, whose AI turn is ending with its main action
## unused, if what it is (ai_readies) and what it sees call for it.
func _ai_consider_ready(comb: Dictionary):
	var wants: int = comb.get("ai_readies", 0)
	if wants == 0 or not ai_plays(comb) or not comb.get("alive", false) or comb.has("object"):
		return
	if comb.get("skill_used_this_turn", false) or comb.has("readied") or comb.get("fleeing", 0) > 0:
		return
	for restriction in ["skips_turn", "confuses", "turns_on_own_side"]:
		if has_restriction(comb, restriction):
			return
	var foes := _ai_foes_in_view(comb)
	if wants & AiReady.CASTERS:
		var casters := _ai_casters_in_sight(comb)
		if not casters.is_empty():
			var key := _ai_ready_pick(comb, false, Trigger.CASTS, casters, true)
			if key != "" and ready_action(comb, key, Trigger.CASTS):
				return
	if wants & AiReady.HIDDEN and _ai_somebody_hidden(comb):
		var key := _ai_ready_pick(comb, false, Trigger.ENTERS_REACH, _ai_hidden_foes(comb))
		if key != "" and ready_action(comb, key, Trigger.ENTERS_REACH):
			return
	if wants & AiReady.APPROACH and not foes.is_empty():
		var key := _ai_ready_pick(comb, true, Trigger.ENTERS_AREA, foes)
		if key != "":
			var aim := _ai_approach_aim(comb, key)
			if aim != NO_AREA and ready_action(comb, key, Trigger.ENTERS_AREA, aim):
				return
		# Nowhere the cone would catch them coming: its reach, which they have
		# to step into to come at it.
		var near := _ai_ready_pick(comb, false, Trigger.ENTERS_REACH, foes)
		if near != "" and ready_action(comb, near, Trigger.ENTERS_REACH):
			return
	if wants & AiReady.GUARDS and _ai_guard_ready(comb):
		return
	if wants & AiReady.PROTECTS:
		_ai_protect_ready(comb)


## The move `comb` would ready for `trigger`: something that hurts, it knows
## and can spare the gate for - ranged, when `ranged`. The one worth most
## against `likely` (who would set it off), within its reach from here when
## `needs_reach`; then what reaches furthest, then what hits hardest. "" when
## there is nothing - or nothing worth anything against `likely`, given some.
func _ai_ready_pick(comb: Dictionary, ranged: bool, trigger: int, likely: Array = [], needs_reach: bool = false) -> String:
	# Something free first, whatever a spell would add: a readied move that never
	# goes off spends its gate all the same.
	var free := _ai_ready_pick_among(comb, ranged, trigger, true, likely, needs_reach)
	return free if free != "" else _ai_ready_pick_among(comb, ranged, trigger, false, likely, needs_reach)


func _ai_ready_pick_among(comb: Dictionary, ranged: bool, trigger: int, free_only: bool, likely: Array, needs_reach: bool) -> String:
	var best := ""
	var best_worth := -1.0
	var best_reach := -1
	var best_power := -1.0
	for key in _ai_main_keys(comb):
		var skill: SkillDefinition = SkillDatabase.skills.get(key)
		if skill == null or not _hostile(skill) or not _ai_plannable(comb, skill):
			continue
		if ranged and is_melee(skill):
			continue
		if free_only and skill.spell_slot_level > 0:
			continue
		if not _ai_can_spare(comb, skill):
			continue
		if ready_refusal(comb, key, trigger, NO_AREA) != "" and trigger != Trigger.ENTERS_AREA and trigger != Trigger.HIT_IN_SIGHT:
			continue
		var worth := _ai_ready_worth(comb, skill, likely, needs_reach)
		if not likely.is_empty() and worth <= 0.0:
			continue
		var reach := effective_max_range(comb, skill)
		var better := worth > best_worth
		if is_equal_approx(worth, best_worth):
			better = reach > best_reach or (reach == best_reach and skill.ability_modifier > best_power)
		if better:
			best = key
			best_worth = worth
			best_reach = reach
			best_power = skill.ability_modifier
	return best


## What `skill` readied by `comb` is worth: the most it would do to any of
## `likely` (ai_target_value) - only those within its reach from where `comb`
## stands, when `needs_reach`. 0 for nobody.
func _ai_ready_worth(comb: Dictionary, skill: SkillDefinition, likely: Array, needs_reach: bool) -> float:
	var most := 0.0
	for other in likely:
		if not other.get("alive", false):
			continue
		if needs_reach:
			var gap := reach_gap(comb, other, skill)
			if gap < skill.min_range or gap > effective_max_range(comb, skill) or not _reaches_through_floors(comb, other):
				continue
			if skill.respects_blocking and not sees_tile(comb, nearest_across(other, comb.position), other):
				continue
		most = maxf(most, ai_target_value(comb, other, skill))
	return most


## Whether `comb` can spend what `skill` costs without it being their last
## casting: free, or with more than one left through its gate or deeper.
func _ai_can_spare(comb: Dictionary, skill: SkillDefinition) -> bool:
	if skill.spell_slot_level <= 0 or casts_without_gates(comb):
		return true
	var left := 0
	var slots: Array = comb.get("spell_slots", [])
	for gate in range(skill.spell_slot_level, slots.size()):
		left += slots[gate]
	return left > 1


## Whether anything `comb` has could hit anybody this turn, from anywhere it
## could walk to.
func _ai_can_strike_this_turn(comb: Dictionary) -> bool:
	var budget := movement_budget_of(comb)
	for key in _ai_main_keys(comb):
		var skill: SkillDefinition = SkillDatabase.skills.get(key)
		if skill == null or not _hostile(skill) or not _ai_plannable(comb, skill) or wasted_on(comb, skill) != "":
			continue
		for other in combatants:
			if not other.alive or other.side == comb.side or is_hidden(other) or other.has("object") or other.get("illusion", false):
				continue
			if can_shoot_from_anywhere_reachable(comb, other.position, skill, budget):
				return true
	return false


## The other side's, standing and not hidden from `comb` - who it knows of.
func _ai_foes_in_view(comb: Dictionary) -> Array:
	return combatants.filter(func(other): return other.get("alive", false) and other.get("side", -1) != comb.side \
		and not other.has("object") and not other.get("illusion", false) and not is_hidden(other) and other.has("position"))


## The other side's who are out of sight - hidden or invisible.
func _ai_hidden_foes(comb: Dictionary) -> Array:
	return combatants.filter(func(other): return other.get("alive", false) and other.get("side", -1) != comb.side and is_hidden(other))


## Everybody of the other side who casts through a gate, in `comb`'s sight.
func _ai_casters_in_sight(comb: Dictionary) -> Array:
	var found := []
	for other in combatants:
		if not other.alive or other.side == comb.side or is_hidden(other) or other.has("object"):
			continue
		if not other.get("spell_slots", []).any(func(count): return count > 0):
			continue
		if sees_tile(comb, nearest_tile_of(other, comb.position), other):
			found.append(other)
	return found


## Whether somebody of the other side is out of sight - hidden or invisible.
func _ai_somebody_hidden(comb: Dictionary) -> bool:
	return combatants.any(func(other): return other.alive and other.side != comb.side and is_hidden(other))


## Which way `comb` would point a readied cone with `key` to catch the other
## side coming: of the four ways, one with nobody in it already (they would not
## "step in"), across the line between it and the most of them - the nearest
## counting most, since they come soonest. NO_AREA when no way does.
func _ai_approach_aim(comb: Dictionary, key: String) -> Vector2i:
	var foes := _ai_foes_in_view(comb)
	if foes.is_empty():
		return NO_AREA
	var shape := footprint(comb)
	var middle: Vector2i = comb.position + shape / 2
	var best := NO_AREA
	var best_score := 0.0
	for way in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var aim := NO_AREA
		for out in range(maxi(shape.x, shape.y), maxi(shape.x, shape.y) + 3):
			var tile: Vector2i = middle + way * out
			if ready_refusal(comb, key, Trigger.ENTERS_AREA, tile) == "":
				aim = tile
				break
		if aim == NO_AREA:
			continue
		var score := _ai_cone_score(comb, ready_area(comb, aim), foes)
		if score > best_score:
			best_score = score
			best = aim
	return best


## What a cone over `tiles` is worth to `comb` against `foes`: nothing with any
## of them in it already; else, for each whose straight way to `comb` crosses
## it, more the nearer they are.
func _ai_cone_score(comb: Dictionary, tiles: Array, foes: Array) -> float:
	if tiles.is_empty():
		return 0.0
	var cone := {}
	for tile in tiles:
		cone[tile] = true
	var score := 0.0
	for foe in foes:
		if tiles_of(foe).any(func(tile): return cone.has(tile)):
			return 0.0
		var way := get_tiles_between(nearest_tile_of(foe, comb.position), nearest_tile_of(comb, foe.position))
		if way.any(func(tile): return cone.has(tile)):
			score += 1.0 / (1.0 + float(distance_to(comb, foe.position)))
	return score


## Whether any of `foes` stands on any of `tiles`.
func _ai_anybody_in(tiles: Array, foes: Array) -> bool:
	for foe in foes:
		for tile in tiles_of(foe):
			if tile in tiles:
				return true
	return false


## A guard readying over its post, without moving: its cone over the thing on
## the map nearest it (or the tile it started on), else over the way the other
## side would come (_ai_approach_aim), with something ranged; or else its reach.
## True when it readied something.
func _ai_guard_ready(comb: Dictionary) -> bool:
	if comb.get("skill_used_this_turn", false) or comb.has("readied"):
		return false
	var post: Vector2i = comb.get("post", comb.position)
	var nearest_thing := GUARD_OBJECT_TILES + 1
	for other in combatants:
		if other.get("alive", false) and other.has("object") and not is_wall(other):
			var gap := distance_to(comb, other.position)
			if gap < nearest_thing:
				nearest_thing = gap
				post = other.position
	var foes := _ai_foes_in_view(comb)
	var ranged := _ai_ready_pick(comb, true, Trigger.ENTERS_AREA, foes)
	if ranged != "":
		var aim := NO_AREA
		if not tiles_of(comb).has(post) and ready_refusal(comb, ranged, Trigger.ENTERS_AREA, post) == "" \
				and not _ai_anybody_in(ready_area(comb, post), foes):
			aim = post
		if aim == NO_AREA:
			aim = _ai_approach_aim(comb, ranged)
		if aim != NO_AREA and ready_action(comb, ranged, Trigger.ENTERS_AREA, aim):
			return true
	var near := _ai_ready_pick(comb, false, Trigger.ENTERS_REACH, foes)
	return near != "" and ready_action(comb, near, Trigger.ENTERS_REACH)


## Protects Its Own: the ally of `comb`'s in sight that the most of the other
## side could get at next turn - the hurt counting double - watched with what
## hurts their attackers most and would reach them there. True when it readied.
func _ai_protect_ready(comb: Dictionary) -> bool:
	if comb.get("skill_used_this_turn", false) or comb.has("readied"):
		return false
	var foes := _ai_foes_in_view(comb)
	var ward := {}
	var most := 0.0
	for ally in combatants:
		if is_same(ally, comb) or not ally.get("alive", false) or ally.get("side", -1) != comb.side \
				or ally.has("object") or ally.get("illusion", false) or not ally.has("position"):
			continue
		if not sees_tile(comb, nearest_across(ally, comb.position), ally):
			continue
		var near := foes.filter(func(foe): return distance_to(ally, nearest_tile_of(foe, ally.position)) <= movement_budget_of(foe) + 1)
		if near.is_empty():
			continue
		var hurt := 1.0 - float(ally.hp) / maxf(float(get_effective_stat(ally, "max_hp")), 1.0)
		var risk := float(near.size()) * (1.0 + hurt)
		if risk > most:
			most = risk
			ward = ally
	if ward.is_empty():
		return false
	var attackers := foes.filter(func(foe): return distance_to(ward, nearest_tile_of(foe, ward.position)) <= movement_budget_of(foe) + 1)
	var best := ""
	var best_worth := 0.0
	for key in _ai_main_keys(comb):
		var skill: SkillDefinition = SkillDatabase.skills.get(key)
		if skill == null or not _hostile(skill) or not _ai_plannable(comb, skill) or not _ai_can_spare(comb, skill):
			continue
		# Whoever hits them will be beside them: within reach of where they stand.
		if reach_gap(comb, ward, skill) > effective_max_range(comb, skill) + 1:
			continue
		if ready_refusal(comb, key, Trigger.HIT_IN_SIGHT, NO_AREA, SkillDefinition.SetOffBy.ENEMIES, ward) != "":
			continue
		var worth := _ai_ready_worth(comb, skill, attackers, false)
		if skill.spell_slot_level <= 0:
			# Free first, as ever, all else near enough equal.
			worth *= 1.25
		if worth > best_worth:
			best_worth = worth
			best = key
	return best != "" and ready_action(comb, best, Trigger.HIT_IN_SIGHT, NO_AREA, SkillDefinition.SetOffBy.ENEMIES, ward)


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
			if skill.respects_blocking and not sees_tile(comb, tile, other):
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


## Whether `skill` used by `attacker` can be aimed at a part: only a blow at one
## tile. Anything with an area (aoe_radius_of - a blow grown into a sweep too)
## lands on the whole of whoever it catches, and no part takes it.
func aims_at_parts(attacker: Dictionary, skill: SkillDefinition) -> bool:
	return skill != null and aoe_radius_of(attacker, skill) == 0


## Which of `comb`'s parts covers `tile`, or -1 - the newest first, so a part
## grown in a later phase covers one there before it.
func part_index_at(comb: Dictionary, tile: Vector2i) -> int:
	if not comb.has("parts"):
		return -1
	var cells := _unfolded(comb, tile - comb.position)
	for i in range(comb.parts.size() - 1, -1, -1):
		for cell in cells:
			if comb.parts[i].tiles.has(cell):
				return i
	return -1


## The tiles of `comb`'s square that their tile `offset` (from their anchor)
## stands for - itself, or folded (Squeezing), every tile of the square folded
## into it. A part's tiles are always the square's.
static func _unfolded(comb: Dictionary, offset: Vector2i) -> Array:
	var span: int = comb.get("span", 1)
	var shape := footprint(comb)
	if shape == Vector2i(span, span):
		return [offset]
	var across := span / shape.x
	var down := span / shape.y
	var cells := []
	for dy in down:
		for dx in across:
			cells.append(Vector2i(offset.x * across + dx, offset.y * down + dy))
	return cells


## Which of `comb`'s tiles (from their anchor) the tile `cell` of their square
## is folded into (Squeezing) - itself when they are not folded.
static func _folded(comb: Dictionary, cell: Vector2i) -> Vector2i:
	var span: int = comb.get("span", 1)
	var shape := footprint(comb)
	return Vector2i(cell.x * shape.x / span, cell.y * shape.y / span)


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
				add_stagger(target, part.stagger, "a broken part")
		BodyPartDefinition.Broken.DISARMED:
			for key in part.disarms:
				target.skill_list.erase(key)
				if target.has("declared") and target.declared.skill == key:
					drop_declared(target, "its weapon is gone")
	# Growing back on a clock, of its own turns (_regrow_clock).
	if part.regrows_after > 0:
		var clocks: Dictionary = target.get("regrowing", {})
		clocks[index] = part.regrows_after
		target["regrowing"] = clocks
	# A belly torn open: whoever is inside falls out through it.
	if part.frees_the_swallowed:
		_free_the_swallowed(target, true, "falls out through the hole, alive")
	cue("broke:%s" % part.name)
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


## Every part on the board, for the controller to draw (CController._draw_parts):
## [{tiles, broken, name, kind (BodyPartDefinition.Broken), id (whose)}].
func part_marks() -> Array:
	var marks := []
	for comb in combatants:
		if not comb.get("alive", false) or not comb.has("parts"):
			continue
		for i in comb.parts.size():
			var part: BodyPartDefinition = comb.parts[i]
			# Not where a part grown since covers it; folded, where it is folded to.
			var showing: Array = []
			for cell in part.tiles:
				var offset := _folded(comb, cell)
				if not showing.has(offset) and part_index_at(comb, comb.position + offset) == i:
					showing.append(offset)
			if showing.is_empty():
				continue
			marks.append({"tiles": showing.map(func(offset): return comb.position + offset), "broken": part_broken(comb, i),
				"name": part.name, "kind": part.when_broken, "id": comb.get("id", -1)})
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
