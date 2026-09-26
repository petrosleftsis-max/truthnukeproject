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

	# Tiles already claimed by an earlier spawn in this encounter. Two
	# combatants sharing a tile corrupts occupancy tracking - _occupied_spaces
	# holds one entry per combatant, so the first of them to move frees the
	# tile for both - and there is no way for the player to click the one
	# underneath. Easy to do by mistake when typing coordinates by hand, and
	# silent until movement starts behaving strangely, so it's caught here.
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
	for spawn in encounter.spawns:
		if not CombatantDatabase.combatants.has(spawn.combatant_key):
			push_warning("Encounter '%s' spawns unknown combatant key '%s' - skipping it." % [encounter.display_name, spawn.combatant_key])
			continue
		if claimed_tiles.has(spawn.position):
			push_warning("Encounter '%s' spawns '%s' on tile %s, which '%s' already occupies - skipping it. Give them their own tile." % [
				encounter.display_name, spawn.combatant_key, spawn.position, claimed_tiles[spawn.position]
			])
			continue
		claimed_tiles[spawn.position] = spawn.combatant_key
		if spawn.side == 0:
			player_tiles.append(spawn.position)
			fallback_party.append(spawn.combatant_key)
			# A player spawn is a place, not a person - who stands there comes
			# from the roster. So the level and gear on it belong to the tile,
			# and whoever deploys onto it fights at that level with that gear.
			player_loadouts.append(spawn)
			continue
		add_combatant(create_combatant(CombatantDatabase.combatants[spawn.combatant_key], spawn.combatant_key, spawn.display_name, spawn), 1, spawn.position)

	_deploy_party(player_tiles, fallback_party, player_loadouts)

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
	if deployment_tiles.size() > 1 and groups[Group.PLAYERS].size() > 0:
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
	if fighters.size() > tiles.size():
		push_warning("Encounter '%s' has %d starting tiles but %d fighters in the party - the last %d sit this one out." % [
			encounter.display_name, tiles.size(), fighters.size(), fighters.size() - tiles.size()
		])
	# A battle walked into from a map keeps whatever the party was carrying when
	# they walked in. One opened straight from the menu has no such history, so
	# what each of them holds is the encounter's to say, spawn by spawn -
	# nothing listed there means empty-handed.
	var walked_in_from_a_map = Campaign.has_map_to_return_to()
	for i in mini(fighters.size(), tiles.size()):
		var key = fighters[i]
		var loadout = loadouts[i] if i < loadouts.size() else null
		if not walked_in_from_a_map:
			Campaign.set_inventory(key, loadout.starting_items if loadout != null else [])
		var comb = create_combatant(CombatantDatabase.combatants[key], key, "", loadout)
		Campaign.apply_carried_state(comb, key)
		add_combatant(comb, 0, tiles[i])
	deployment_tiles = tiles


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


## Sets the battle actually running. Separate from _ready because deployment
## sits in between.
func start_first_turn():
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
## level 1, flat attributes, an ordinary weapon.
func create_combatant(definition: CombatantDefinition, combatant_key: String = "", override_name = "", spawn: SpawnDefinition = null):
	var level = spawn.level if spawn != null else 1
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
		"ai_function" = definition.ai_function,
		# Which CombatantDatabase entry this came from. Campaign keys the
		# party's carried-over health off this, so it survives the combatant
		# dictionary being rebuilt from scratch for each encounter.
		"combatant_key" = combatant_key
		}
	# Kept so duplicates can be numbered off the name they share rather than off
	# a name that has already been numbered.
	comb["base_name"] = definition.name
	if override_name != "":
		comb.name = override_name
		# The author has said what to call this one, so nothing renumbers it.
		comb["named_by_author"] = true
	return comb

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

func add_combatant(combatant: Dictionary, side: int, position: Vector2i):
	combatant["position"] = position
	combatant["side"] = side
	# Something to be addressed by that is not their name. An encounter can field
	# three barbarians, and the HUD used to find a combatant's icon by name -
	# which meant killing one of the three could take the wrong icon off the
	# screen, or none of them.
	combatant["id"] = _next_combatant_id
	_next_combatant_id += 1
	combatants.append(combatant)
	_number_duplicates(combatant)
	groups[side].append(combatants.size() - 1)

	var new_combatant_sprite = CombatantSprite.new()
	combatant_layer().add_child(new_combatant_sprite)
	new_combatant_sprite.position = Grid.tile_to_world(position)
	new_combatant_sprite.z_index = 1
	var facing_flip = side == 0
	new_combatant_sprite.setup(combatant.sprite_frames, combatant.map_sprite, facing_flip)
	if side == 1:
		combatant["initiative"] -= 1
	combatant["sprite"] = new_combatant_sprite
	
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
		# though it is spent from this same action.
		if skill.is_secondary or skill.spell_slot_level > 0:
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
	if passive == null:
		return false
	match passive.active_when:
		PassiveDefinition.ActiveWhen.ALWAYS:
			return true
		PassiveDefinition.ActiveWhen.BELOW_HALF_HEALTH:
			return comb.get("hp", 0) * 2 <= get_effective_stat(comb, "max_hp")
	return false


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
		var skills := threat_skills(enemy)
		if not skills.is_empty():
			var standing: Array = controller.get_reachable_tiles(enemy.position, enemy.movement_class, movement_budget_of(enemy)).keys()
			if not standing.has(enemy.position):
				standing.append(enemy.position)
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
			if sight.clear(from, tile, enemy.movement_class):
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
	## 1 where somebody the player can see is standing.
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
				_set_body(comb.position, 1)

	## Somebody who has walked off takes their body with them, so their old
	## tile stops being cover for the lines they would shoot along.
	func stand_aside(comb: Dictionary):
		_set_body(comb.position, 0)

	func stand_back(comb: Dictionary):
		_set_body(comb.position, 1)

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

	func clear(from: Vector2i, to: Vector2i, movement_class: int) -> bool:
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
			if terrain[at] == 1 or _bodies[at] == 1:
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

func get_distance(attacker: Dictionary, target: Dictionary):
	return get_position_distance(attacker.position, target.position)


## Generic entry point for using ANY skill, in place of the separate function
## per attack this used to have. A new skill needs no new code here at all:
## just add it to skill_database.tscn and reference its key in a combatant's
## skill list.
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
func use_skill(skill_key: String, attacker: Dictionary, impact_position: Vector2i, end_turn_after: bool = true, as_secondary: bool = false, destination: Vector2i = Vector2i(-99999, -99999)):
	# Same reason as advance_turn: an AI that was walking when the battle was
	# left comes back here to swing at somebody, on a battlefield that has
	# already been freed.
	if not still_running():
		return
	var skill: SkillDefinition = SkillDatabase.skills[skill_key]
	var distance = get_position_distance(attacker.position, impact_position)
	var valid = distance <= effective_max_range(attacker, skill) and distance >= skill.min_range
	if valid and not meets_level_for(attacker, skill):
		update_information.emit("[color=yellow]%s[/color] has not learned %s yet.
" % [attacker.name, skill.name])
		if attacker.side == 1 and end_turn_after:
			await advance_turn()
		return
	if valid and not can_afford_skill(attacker, skill):
		update_information.emit("[color=yellow]%s[/color] has no %s left for %s.\n" % [
			attacker.name, Stats.short_gate_name(skill.spell_slot_level), skill.name
		])
		if attacker.side == 1 and end_turn_after:
			await advance_turn()
		return
	if valid:
		controller.action_locked = true
		game_ui.lock_action_buttons()
		# Moved before the animation plays, so a blink-and-strike is seen landing
		# and then swinging rather than swinging and then arriving. An area skill
		# that moves its caster therefore bursts from where they end up.
		if skill.teleports == SkillDefinition.TeleportWho.CASTER:
			teleport_to(attacker, impact_position)
		elif skill.teleports == SkillDefinition.TeleportWho.TARGET:
			var travelling = get_combatant_at(impact_position)
			if not travelling.is_empty():
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
		var spent = spend_slot_for(attacker, skill)
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
		var tiles = get_impact_tiles(skill, attacker.position, impact_position, attacker.movement_class)
		var targets = get_targets_in_tiles(tiles, attacker, skill.targets_ally, skill.affects_both_sides)
		# A roll each, rather than one for the whole use. A blast landing among
		# two enemies is two chances to connect, and each is judged against that
		# enemy - so a studied bonus counts against whoever was actually studied,
		# rather than against whoever happened to be standing on the aimed tile,
		# which for something aimed at open ground is nobody at all.
		#
		# A contested skill still does not roll: it lands on everyone, in full on
		# those it beats and as a graze on those it does not.
		var connected = false
		for target in targets:
			if not skill.uses_stat_contest and (randi() % 100) >= hit_chance(attacker, skill, target):
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
				apply_effect(attacker, target, effect, skill, mention_skill, 0.5 if grazed else 1.0, impact_position if skill.aoe_radius > 0 else attacker.position)
				mention_skill = false
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
			combatant_die(attacker)
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
		if attacker.side == 1:
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
		if attacker.side == 1 and end_turn_after:
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
			var distance_before = get_position_distance(reactor.position, previous_position)
			var distance_after = get_position_distance(reactor.position, new_position)
			# The reactor's reach, not the skill's: a blinded one can only see
			# the tile beside them, and use_reactive_skill checks line of sight
			# but never range, so this is the only thing standing between a
			# blinded combatant and a shot across the map.
			var reach = effective_max_range(reactor, skill)
			var was_in_range = distance_before >= skill.min_range and distance_before <= reach
			var now_in_range = distance_after >= skill.min_range and distance_after <= reach
			if was_in_range and not now_in_range:
				if skill.respects_blocking and not has_line_of_sight(reactor.position, previous_position, reactor.movement_class):
					# The shot was blocked anyway - use_reactive_skill would
					# bail on the same check, so there's nothing worth asking
					# the player about.
					break
				if not await confirm_reaction(reactor, mover, skill):
					# Passed on it. The reaction stays unspent, so the next
					# enemy to break away this round asks again - but this
					# reactor is done being asked about *this* move.
					break
				await use_reactive_skill(skill_key, reactor, mover, previous_position)
				if not mover.alive:
					return
				break


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
func get_impact_tiles(skill: SkillDefinition, caster_position: Vector2i, aim_position: Vector2i, movement_class: int = 0) -> Array:
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
		tiles = filter_tiles_by_line_of_sight(tiles, seen_from, movement_class)
	return tiles


## Keeps only the tiles in `tiles` that (a) aren't themselves solid to look at
## and (b) have an unobstructed straight path from `from` - i.e. nothing
## behind a wall, and no shot that has to pass through one to get there.
##
## Solid to LOOK at, not to walk on. A railing painted see-through stops a
## walker but not a shot, and a flier can be standing on it - so it stays in
## range and is drawn in reach rather than being quietly dropped from the very
## overlay that says what can be hit.
func filter_tiles_by_line_of_sight(tiles: Array, from: Vector2i, movement_class: int) -> Array:
	var result = []
	for tile in tiles:
		if controller.terrain_blocks_sight(tile, movement_class):
			continue
		if has_line_of_sight(from, tile, movement_class):
			result.append(tile)
	return result


## Whether there's a clear straight path from `from` to `to` for
## `movement_class` - no blocking tile anywhere strictly between them
## (the endpoints themselves aren't checked here; see is_tile_blocking).
func has_line_of_sight(from: Vector2i, to: Vector2i, movement_class: int) -> bool:
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
		return _walk_is_clear(to, from, movement_class)
	return _walk_is_clear(from, to, movement_class)


## One direction of the walk. has_line_of_sight is the question to ask; this is
## half of its answer, and on its own it is the asymmetry rather than the rule.
## _SightGrid.clear walks the same line for the danger view - change one, change
## both (the danger suite checks they agree).
##
## Deliberately the same arithmetic, in the same order, so it cannot disagree
## with get_tiles_between about what lies between two tiles. The blindcast
## and stealth suites check the two against each other.
func _walk_is_clear(from: Vector2i, to: Vector2i, movement_class: int) -> bool:
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
		if controller.blocks_line_of_sight(between, movement_class):
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
	for tile in get_diamond_tiles(caster_position, reach):
		if get_position_distance(caster_position, tile) >= skill.min_range:
			tiles.append(tile)
	if skill.respects_blocking:
		tiles = filter_tiles_by_line_of_sight(tiles, caster_position, movement_class)
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
		if comb.position in tiles:
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
	flash_target(attacker, target, damage_colour, blast_origin)
	match effect.type:
		EffectDefinition.EffectType.DAMAGE:
			do_damage(attacker, target, effect, skill, mention_skill, power)
		EffectDefinition.EffectType.HEAL:
			do_heal(attacker, target, effect, skill, mention_skill)
		EffectDefinition.EffectType.STAT_MODIFIER:
			var movement_before = get_effective_stat(target, "movement")
			target.status_effects.append({
				"stat" = effect.stat,
				"op" = "add",
				"amount" = effect.modifier_amount,
				"duration" = stored_duration(target, effect),
				"source_name" = attacker.name
			})
			if effect.stat == "movement":
				resync_live_movement(target, movement_before)
			var change_word = "weakened" if effect.modifier_amount < 0 else "strengthened"
			var fallback = "%s %s" % [change_word, effect.stat]
			update_information.emit(describe_condition(attacker, target, effect, skill, mention_skill, fallback))
			clamp_hp_to_max(target)
		EffectDefinition.EffectType.STAT_MULTIPLIER:
			var movement_before = get_effective_stat(target, "movement")
			target.status_effects.append({
				"stat" = effect.stat,
				"op" = "multiply",
				"amount" = effect.stat_multiplier,
				"duration" = stored_duration(target, effect),
				"source_name" = attacker.name
			})
			if effect.stat == "movement":
				resync_live_movement(target, movement_before)
			update_information.emit(describe_condition(attacker, target, effect, skill, mention_skill,
				"%sx %s" % [effect.stat_multiplier, effect.stat]))
			clamp_hp_to_max(target)
		EffectDefinition.EffectType.DAMAGE_OVER_TIME:
			var lingering = effective_damage_type(attacker, effect.damage_type)
			replace_matching_tick(target, "dot", null, lingering)
			target.status_effects.append({
				"stat" = "dot", # reserved pseudo-stat marking a damage-over-time tick
				"damage_type" = lingering,
				"min_amount" = effect.min_amount,
				"max_amount" = effect.max_amount,
				"dot_base" = dot_base_damage(attacker, skill, effect.damage_modifier),
				"duration" = stored_duration(target, effect),
				"source_name" = attacker.name
			})
			update_information.emit(describe_condition(attacker, target, effect, skill, mention_skill, "a lingering wound"))
		EffectDefinition.EffectType.CONDITION:
			if effect.condition == null:
				push_warning("A CONDITION effect on %s has no condition assigned." % (skill.name if skill != null else "an unnamed skill"))
			else:
				var movement_before = get_effective_stat(target, "movement")
				replace_matching_tick(target, "condition", effect.condition, 0)
				target.status_effects.append({
					"stat" = "condition",
					"condition" = effect.condition,
					"dot_base" = dot_base_damage(attacker, skill, effect.condition_dot_strength()),
					"duration" = condition_turns(target, effect),
					"source_name" = attacker.name
				})
				if effect.condition.movement_change != 0:
					resync_live_movement(target, movement_before)
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
				"source_name" = attacker.name
			})
			update_combatants.emit(combatants)
			update_information.emit(describe_condition(attacker, target, effect, skill, mention_skill,
				"their next element raised"))
		EffectDefinition.EffectType.MOVEMENT_CLASS:
			target.status_effects.append({
				"stat" = "movement_class",
				"op" = "set",
				"amount" = effect.movement_class,
				"duration" = stored_duration(target, effect),
				"source_name" = attacker.name
			})
			resync_movement_class(target)
			# The strip under the portrait is only redrawn when this goes out,
			# and a change to how somebody moves should show the moment it lands.
			update_combatants.emit(combatants)
			update_information.emit(describe_condition(attacker, target, effect, skill, mention_skill,
				"moving as %s" % Stats.movement_class_name(effect.movement_class).to_lower()))
		EffectDefinition.EffectType.RESISTANCE:
			target.status_effects.append({
				"stat" = Damage.resistance_key(effect.damage_type),
				"op" = "add",
				"amount" = effect.modifier_amount,
				"duration" = stored_duration(target, effect),
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
		EffectDefinition.EffectType.REVEAL:
			# Knowledge, not an injury: it lasts the battle, nothing cleanses it
			# off, and studying the same enemy twice is the same knowledge again.
			var already_known = _has_studied(attacker, target)
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
			else:
				update_information.emit("[color=yellow]%s[/color] studies [color=red]%s[/color], and can read them in full - press C.\n" % [attacker.name, target.name])
			combatant_studied.emit(target)
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
	var cap = condition_range_cap(caster)
	if cap > 0:
		return mini(skill.max_range, cap)
	return skill.max_range


## How long a freshly applied status effect should be recorded as lasting.
##
## Durations count down at the START of the affected combatant's turn, so an
## effect placed on someone who hasn't acted yet gets its full count - their
## next N turns. But one landing on whoever is acting right now is already
## spending one of its turns, the rest of this one, so it's stored a turn
## shorter. Otherwise a self-buff covers the turn it was cast AND the whole of
## the next: Run at duration 1 left Cyrus still doubled at the start of his
## following turn, so he began on 12 movement having used nothing.
##
## The upshot is that duration reads the same either way: 1 means "this turn"
## for something you do to yourself, and "their next turn" for something you do
## to someone else.
## `source` is whatever carries the duration - an EffectDefinition, or a
## ConditionDefinition, which keeps its own.
func stored_duration(target: Dictionary, source) -> int:
	if target == get_current_combatant():
		return maxi(source.duration - 1, 0)
	return source.duration


## How long the condition `effect` inflicts should last on `target`.
##
## The skill decides if it has an opinion - EffectDefinition.condition_duration
## above zero - and the condition's own duration is used otherwise. That way a
## skill can land a brief Blind or a punishing one without a second Blind
## resource existing just to hold a different number, and every skill that
## does not care keeps behaving as it always did.
##
## Docked by one when it lands on whoever is currently acting, for the same
## reason stored_duration docks it: they are part-way through the turn it would
## otherwise get for free.
func condition_turns(target: Dictionary, effect: EffectDefinition) -> int:
	var turns = effect.condition_duration if effect.condition_duration > 0 else effect.condition.duration
	if target == get_current_combatant():
		return maxi(turns - 1, 0)
	return turns


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
	while i >= 0:
		if effect.dispel_count > 0 and removed >= effect.dispel_count:
			break
		if should_dispel(target.status_effects[i], effect):
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


func should_dispel(status_effect: Dictionary, dispel_effect: EffectDefinition) -> bool:
	if dispel_effect.dispel_stat != "" and status_effect.stat != dispel_effect.dispel_stat:
		return false
	if dispel_effect.dispel_scope == EffectDefinition.DispelScope.BOTH:
		return true
	var is_multiply = status_effect.get("op", "add") == "multiply"
	# A condition is always something done to you - there is no such thing as a
	# helpful one in this game, and every entry in res://conditions is an
	# affliction. It carries no `amount`, so the tests below could never see it
	# as a debuff: Cleanse, which exists to lift debuffs, could not lift a
	# single Poisoning, Burn or Crystallisation off anybody.
	var is_debuff = status_effect.stat == "dot" or status_effect.stat == "condition"
	is_debuff = is_debuff or (is_multiply and status_effect.get("amount", 1.0) < 1.0)
	is_debuff = is_debuff or (not is_multiply and status_effect.get("amount", 0) < 0)
	if dispel_effect.dispel_scope == EffectDefinition.DispelScope.DEBUFFS_ONLY:
		return is_debuff
	return not is_debuff


## The living combatant standing on `position`, or an empty Dictionary if
## the tile is unoccupied.
func get_combatant_at(position: Vector2i) -> Dictionary:
	for comb in combatants:
		if comb.alive and comb.position == position:
			return comb
	return {}


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
	var direction = get_octant_direction(attacker.position, target.position)
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
		target.sprite.position = Grid.tile_to_world(final_position)
		controller.reposition_combatant(old_position, final_position)
		var distance_moved = get_position_distance(old_position, final_position)
		update_information.emit("[color=yellow]{0}[/color] {1} [color=red]{2}[/color] {3} tile(s)\n".format([
			attacker.name,
			"dragged" if pulling else "shoved",
			target.name,
			distance_moved
		]))
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
	who.hp -= collision_damage
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


## Ticks any damage-over-time effects and removes one turn of duration from
## every status effect on this combatant, dropping any that have expired.
## Call once per combatant, at the start of their own turn.
## Expiry is checked BEFORE the tick, not after it. Decrementing and then
## dropping anything that reached zero in the same pass spent the effect's last
## turn removing it, so a duration of N only ever lasted N-1 of the target's
## turns - 1 did nothing at all. Now an effect ticks on each of N turns and is
## cleared at the start of the turn after, so duration means what it says.
func process_status_effects(comb: Dictionary):
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
		eff.duration -= 1
		i -= 1
	# Anything that just expired may have been holding them in the air.
	resync_movement_class(comb)
	clamp_hp_to_max(comb)


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
	comb.hp -= amount
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
	comb.hp -= amount
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
	return fold_stat_changes(comb, stat, comb.get(stat, 0))


## `value` with everything currently raising or lowering `stat` folded into it.
##
## Split out because a combatant keeps its numbers in two places: hp, movement
## and the like sit at the top level, while the five attributes live under
## "stats" - and a buff applies to either in exactly the same way. Two callers
## that know where a base value lives, one that knows what a buff does to it.
func fold_stat_changes(comb: Dictionary, stat: String, value: int) -> int:
	var additive = 0
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
	current_combatant = turn_queue[turn]


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
	combatants[current_combatant].turn_taken = true
	set_next_combatant()
	var comb = combatants[current_combatant]
	while true:
		if groups[Group.PLAYERS].size() < 1 or groups[Group.ENEMIES].size() < 1:
			# Combat is already over - make sure combat_finish() has actually
			# run (it's idempotent, so this is safe even if it already has),
			# then stop advancing turns rather than loop forever looking for
			# a living combatant that no longer exists.
			combat_finish()
			return
		if not comb.alive:
			set_next_combatant()
			comb = combatants[current_combatant]
			continue
		comb.skill_used_this_turn = false
		comb.secondary_used_this_turn = false
		comb.reaction_used = false
		comb.reactions_suppressed = false
		process_status_effects(comb)
		if not comb.alive:
			# A damage-over-time tick (or similar) killed them just as their
			# turn was starting - skip straight to whoever's next.
			set_next_combatant()
			comb = combatants[current_combatant]
			continue
		if has_restriction(comb, "skips_turn"):
			# Stunned. The condition has already ticked a turn off itself in
			# process_status_effects above, so it still wears off on schedule.
			update_information.emit("[color=red]%s[/color] is stunned and loses their turn.\n" % comb.name)
			set_next_combatant()
			comb = combatants[current_combatant]
			continue
		break
	_pace_turn(comb)
	apply_drift(comb)
	emit_signal("turn_advanced", comb)
	emit_signal("update_combatants", combatants)
	if comb.side == 1:
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
		if not controller.is_in_bounds(candidate):
			break
		if controller.is_tile_blocking(candidate, comb.movement_class):
			break
		if not get_combatant_at(candidate).is_empty():
			break
		landed = candidate
	if landed == from:
		return
	comb.position = landed
	comb.sprite.position = Grid.tile_to_world(landed)
	controller.reposition_combatant(from, landed)
	update_information.emit("[color=red]%s[/color] is blown %d tile(s) off course.\n" % [
		comb.name, get_position_distance(from, landed)
	])


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
	if not players_alive and not enemies_alive:
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
		skill.ability_modifier * power, stat_of(target, Stats.Type.DEFENSE))



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
	return maxi(roundi(power_behind(healer, skill) * heal_strength(skill, effect)), 0)


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
	var distance = get_position_distance(caster.position, aim)
	if distance > effective_max_range(caster, skill) or distance < skill.min_range:
		return []
	# A blink bursts from where it lands, which is the tile aimed at.
	var from = aim if skill.teleports == SkillDefinition.TeleportWho.CASTER else caster.position
	var tiles = get_impact_tiles(skill, from, aim, caster.movement_class)
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
	target.hp -= damage
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


func combatant_die(combatant: Dictionary):
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
	# Somebody falling is exactly what leaves the last of their side standing
	# alone, and the last one standing cannot stay hidden. Asked here, after the
	# groups above have been updated, so the count is the one that is now true.
	reveal_anyone_now_seen()
	if groups[Group.ENEMIES].size() < 1 or groups[Group.PLAYERS].size() < 1:
		combat_finish()



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
	var ai_function = comb.get("ai_function", "ai_melee_rush")
	if ai_function != "" and has_method(ai_function):
		await call(ai_function, comb)
	else:
		await ai_melee_rush(comb)


## The nearest living combatant on the opposite side to comb, or an empty
## Dictionary if there isn't one.
func find_nearest_enemy_of(comb: Dictionary) -> Dictionary:
	var opposing_side = Group.PLAYERS if comb.side == Group.ENEMIES else Group.ENEMIES
	var nearest: Dictionary = {}
	var best_distance = INF
	for index in groups[opposing_side]:
		var candidate = combatants[index]
		# Hidden is not "harder to hit" - it is not being there.
		if not candidate.alive or is_hidden(candidate):
			continue
		var distance = get_distance(comb, candidate)
		if distance < best_distance:
			best_distance = distance
			nearest = candidate
	return nearest


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
	var reachable = controller.get_reachable_tiles(comb.position, comb.movement_class, movement_budget)
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
				var distance_before = get_position_distance(reactor.position, from_tile)
				var distance_after = get_position_distance(reactor.position, to_tile)
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
	for tile in controller.get_reachable_tiles(comb.position, comb.movement_class, movement_budget):
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
	for other in combatants:
		if not other.alive:
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
	return can_afford_skill(comb, skill) and meets_level_for(comb, skill)


## Everything `comb` could spend its main action on: its skills and its spells.
func _ai_main_keys(comb: Dictionary) -> Array:
	var keys = main_skills_of(comb).duplicate()
	for key in spell_skills_of(comb):
		if not SkillDatabase.skills[key].is_secondary and not keys.has(key):
			keys.append(key)
	return keys


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
			scores[other.position] = 0.0
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
		var d = get_position_distance(standing, aim)
		if d > reach or d < skill.min_range:
			continue
		var score := 0.0
		if blast:
			if radius == 0 and skill.respects_blocking \
					and not has_line_of_sight(standing, aim, comb.movement_class):
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
		for tile in controller.get_reachable_tiles(comb.position, comb.movement_class, budget):
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
			and meets_level_for(comb, run) and not comb.get("skill_used_this_turn", false):
		# Nothing to swing at this turn anyway, so the main action is worth
		# more as ground covered.
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


## The chance `attacker` has of landing `skill` on `target`: the skill's own
## accuracy, and whatever conditions are helping or hindering them.
##
## Studying somebody used to add ten points here as well. What Study is worth is
## the reading - the sheet, and knowing what you are walking into - rather than
## a thumb on the scale afterwards.
##
## `target` is still taken, because a roll is made per target and a condition on
## one of them is theirs rather than the whole cast's.
func hit_chance(attacker: Dictionary, skill: SkillDefinition, _target: Dictionary = {}) -> int:
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


func items_of(comb: Dictionary) -> Array:
	if comb.side != 0:
		return []
	var key = comb.get("combatant_key", "")
	if key == "":
		return []
	return Campaign.combat_items_of(key)


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
	if not controller.is_in_bounds(tile):
		return false
	if controller.is_tile_blocking(tile, comb.movement_class):
		return false
	var sitting = get_combatant_at(tile)
	return sitting.is_empty() or sitting == comb


## Puts `comb` on `tile`, if they can stand there. Costs no movement and
## provokes no reaction: they did not walk out of anybody's reach, they simply
## stopped being where they were.
func teleport_to(comb: Dictionary, tile: Vector2i) -> bool:
	if not can_land_on(comb, tile) or comb.position == tile:
		return false
	var from = comb.position
	comb.position = tile
	comb.sprite.position = Grid.tile_to_world(tile)
	controller.reposition_combatant(from, tile)
	update_information.emit("[color=yellow]%s[/color] is somewhere else.\n" % comb.name)
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
