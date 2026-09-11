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
	for i in mini(fighters.size(), tiles.size()):
		var key = fighters[i]
		var loadout = loadouts[i] if i < loadouts.size() else null
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
	watch_combatant(combatants[current_combatant])
	await get_tree().create_timer(0.6).timeout
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
## "Goblin 3" should not become "Goblin 3 1".
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
	$"../Terrain/TileMap".add_child(new_combatant_sprite)
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
	# Whatever is packed in the first four slots, alongside what they know how
	# to do - a potion is another thing this turn could be spent on.
	for key in items_of(comb):
		var item: ItemDefinition = ItemDatabase.item(key)
		if item != null and not item.is_secondary and not found.has(key):
			found.append(key)
	return found


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
	for key in comb.get("secondary_skills", []):
		if not SkillDatabase.skills.has(key) or found.has(key):
			continue
		if SkillDatabase.skills[key].spell_slot_level > 0:
			continue
		if not meets_level_for(comb, SkillDatabase.skills[key]):
			continue
		found.append(key)
	# Consumables meant for the secondary slot, and - for anyone whose hands are
	# quick enough - the ones that would otherwise cost the main action. That is
	# Cyrus, and it is why he can drink and still swing.
	for key in items_of(comb):
		if found.has(key):
			continue
		var item: ItemDefinition = ItemDatabase.item(key)
		if item == null:
			continue
		if item.is_secondary or comb.get("items_as_secondary", false):
			found.append(key)
	return found


## Everything `comb` knows that costs a spell slot, whichever action it spends.
## Its own panel, because a caster's spell list is the part of their sheet that
## needs reading against a resource, and mixing it into the main list buries it.
func spell_skills_of(comb: Dictionary) -> Array:
	var found = []
	var offered = comb.skill_list.duplicate()
	offered.append_array(comb.get("secondary_skills", []))
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
	for candidate in range(level, 4):
		if candidate < slots.size() and slots[candidate] > 0:
			return candidate
	return 0


## Whether `comb` can currently afford `skill` at all. Free skills always can.
func can_afford_skill(comb: Dictionary, skill: SkillDefinition) -> bool:
	if skill.spell_slot_level <= 0:
		return true
	return slot_available_for(comb, skill.spell_slot_level) > 0


## Spends the cheapest slot that covers `skill`, so a level 3 is never burned
## on a level 1 spell while a level 1 is still going spare. Returns the level
## actually spent, or 0 if the skill was free.
func spend_slot_for(comb: Dictionary, skill: SkillDefinition) -> int:
	var level = slot_available_for(comb, skill.spell_slot_level)
	if level > 0:
		comb.spell_slots[level] -= 1
	return level


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
		update_information.emit("[color=yellow]%s[/color] has no level %d spell slot left for %s.\n" % [
			attacker.name, skill.spell_slot_level, skill.name
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
		play_skill_sound(skill)
		controller.action_locked = false
		game_ui.refresh_action_buttons()
		if not attacker.alive:
			# Something else killed them while their own skill's animation
			# was still playing - nothing left to resolve.
			return
		if attacker.side == 0:
			last_player_skill_used = skill_key
		var spent = spend_slot_for(attacker, skill)
		if spent > 0:
			update_information.emit("[color=yellow]%s[/color] spends a level %d slot.\n" % [attacker.name, spent])
		# The heaviest thing a caster can do should land like it. Keyed off the
		# skill's own level rather than the slot spent, so paying for a level 1
		# spell with a level 3 slot doesn't shake the map.
		if skill.spell_slot_level >= 3:
			shake_camera(LEVEL_THREE_SHAKE)
		# A contested skill never rolls: it lands on everyone, in full on those
		# it beats and as a graze on those it doesn't. An accuracy skill rolls
		# once for the whole use, hit or miss.
		var connected = true
		if not skill.uses_stat_contest:
			# One roll for the whole use, before it knows who it caught - so the
			# study bonus is judged on whoever is standing where it was aimed.
			connected = (randi() % 100) < hit_chance(attacker, skill, get_combatant_at(impact_position))
		if connected:
			var tiles = get_impact_tiles(skill, attacker.position, impact_position, attacker.movement_class)
			var targets = get_targets_in_tiles(tiles, attacker, skill.targets_ally, skill.affects_both_sides)
			for target in targets:
				# Only the first effect on each target names the skill, so a
				# multi-effect hit reads as one action rather than repeating
				# "used Poison Dart" for every effect it carries.
				var mention_skill = true
				var grazed = skill.uses_stat_contest and not wins_contest(attacker, target, skill)
				if grazed:
					update_information.emit("[color=red]%s[/color] shrugs off the worst of %s.\n" % [target.name, skill.name])
				for effect in skill.all_effects():
					# A graze is damage only, at half strength - nothing that
					# would stick, slow, poison or shove comes with it.
					if grazed and effect.type != EffectDefinition.EffectType.DAMAGE:
						continue
					# An area skill shoves everyone caught outward from where it
					# landed, so the shape of the blast reads off the recoil.
					apply_effect(attacker, target, effect, skill, mention_skill, 0.5 if grazed else 1.0, impact_position if skill.aoe_radius > 0 else attacker.position)
					mention_skill = false
		else:
			update_information.emit("{0} missed.\n".format([attacker.name]))
		if skill.kills_caster and attacker.alive:
			update_information.emit("[color=red]{0}[/color] is consumed by its own {1}!\n".format([attacker.name, skill.name]))
			combatant_die(attacker)
		if as_secondary:
			attacker.secondary_used_this_turn = true
		else:
			attacker.skill_used_this_turn = true
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
			var was_in_range = distance_before >= skill.min_range and distance_before <= skill.max_range
			var now_in_range = distance_after >= skill.min_range and distance_after <= skill.max_range
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
	if attacker.side == 0:
		last_player_skill_used = skill_key
	var spent = spend_slot_for(attacker, skill)
	if spent > 0:
		update_information.emit("[color=yellow]%s[/color] spends a level %d slot.\n" % [attacker.name, spent])
	update_information.emit("[color=yellow]{0}[/color] reacts as [color=red]{1}[/color] leaves range!\n".format([
		attacker.name,
		target.name
	]))
	controller.action_locked = true
	game_ui.lock_action_buttons()
	await attacker.sprite.play_skill_and_wait(skill.animation)
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
		tiles = filter_tiles_by_line_of_sight(tiles, caster_position, movement_class)
	return tiles


## Keeps only the tiles in `tiles` that (a) aren't themselves a blocking tile
## and (b) have an unobstructed straight path from `from` - i.e. nothing
## behind a wall, and no shot that has to pass through one to get there.
func filter_tiles_by_line_of_sight(tiles: Array, from: Vector2i, movement_class: int) -> Array:
	var result = []
	for tile in tiles:
		if controller.is_tile_blocking(tile, movement_class):
			continue
		if has_line_of_sight(from, tile, movement_class):
			result.append(tile)
	return result


## Whether there's a clear straight path from `from` to `to` for
## `movement_class` - no blocking tile anywhere strictly between them
## (the endpoints themselves aren't checked here; see is_tile_blocking).
func has_line_of_sight(from: Vector2i, to: Vector2i, movement_class: int) -> bool:
	for tile in get_tiles_between(from, to):
		if controller.is_tile_blocking(tile, movement_class):
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
## "Cyrus used Poison Dart on Goblin 1, dealing 5 damage. Cyrus inflicted
## Poisoning on Goblin 1." rather than repeating the skill's name per effect.
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
			target.status_effects.append({
				"stat" = "dot", # reserved pseudo-stat marking a damage-over-time tick
				"damage_type" = effect.damage_type,
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
				target.status_effects.append({
					"stat" = "condition",
					"condition" = effect.condition,
					"dot_base" = dot_base_damage(attacker, skill, effect.condition.dot_modifier),
					"duration" = condition_turns(target, effect),
					"source_name" = attacker.name
				})
				if effect.condition.movement_change != 0:
					resync_live_movement(target, movement_before)
				update_information.emit(describe_condition(attacker, target, effect, skill, mention_skill, effect.condition.display_name))
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
			apply_knockback(attacker, target, effect, false)
		EffectDefinition.EffectType.PULL:
			apply_knockback(attacker, target, effect, true)


## --- Conditions ---
##
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
	if mention_skill and skill != null:
		return "[color=yellow]%s[/color] used %s on [color=red]%s[/color], inflicting %s.\n" % [
			attacker.name, skill.name, target.name, condition
		]
	return "[color=yellow]%s[/color] inflicted %s on [color=red]%s[/color].\n" % [
		attacker.name, condition, target.name
	]


## Removes status effects from `target` matching `effect`'s dispel filters
## (see EffectDefinition.dispel_stat / dispel_scope).
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
	if removed > 0:
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
	var is_debuff = status_effect.stat == "dot"
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
## A PUSH (not a PULL) stopped short deals effect.min_amount-max_amount
## collision damage: into the map edge or a blocking tile it hurts whoever was
## shoved, and into another combatant it hurts them both, since a body stopping
## a body is a collision from either side of it. One roll for the impact, each
## of them resisting it with their own resistances - it is a single event, not
## two coincidental ones. A pull falling short never hurts anybody.
func apply_knockback(attacker: Dictionary, target: Dictionary, effect: EffectDefinition, pulling: bool):
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
	var impact = randi_range(effect.min_amount, effect.max_amount)
	if hit_obstacle and target.alive:
		_take_collision_damage(target, effect, impact, "slammed into an obstacle")
	elif not bumped.is_empty() and bumped.alive:
		# Both of them, and the one still standing where they were takes it too:
		# they are what stopped the other.
		if target.alive:
			_take_collision_damage(target, effect, impact,
				"slammed into [color=red]%s[/color]" % bumped.name)
		if bumped.alive:
			_take_collision_damage(bumped, effect, impact,
				"was slammed into by [color=red]%s[/color]" % target.name)


## Applies one collision's worth of damage to `who`, resisted by them, and
## reports it. Shared by the wall case and both halves of a body-to-body one so
## the three cannot drift apart.
func _take_collision_damage(who: Dictionary, effect: EffectDefinition, impact: int, what_happened: String):
	var collision_damage = resisted_damage(who, effect.damage_type, impact)
	who.hp -= collision_damage
	show_damage(who, collision_damage, effect.damage_type, true)
	update_combatants.emit(combatants)
	update_information.emit("[color=red]{0}[/color] {1}, taking [color=gray]{2} damage[/color]\n".format([
		who.name,
		what_happened,
		collision_damage
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
	clamp_hp_to_max(comb)


## Burns a turn's worth of damage off someone suffering a condition that deals
## it. Same shape as tick_damage_over_time, but named by the condition so the
## log says what is actually hurting them.
## One tick of a lingering effect, before resistance. Uses the snapshot taken
## when it landed if there is one, and the flat range if there is not - which
## is what a condition inflicted with no skill behind it falls back to.
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
	update_information.emit("[color=red]%s[/color] took [color=gray]%d %s damage%s[/color] from %s.\n" % [
		comb.name, amount, Damage.type_name(condition.dot_type).to_lower(),
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
	update_information.emit("[color=red]%s[/color] took [color=gray]%d %s damage%s[/color] from a lingering effect (%s).\n" % [
		comb.name, amount, Damage.type_name(type).to_lower(), Damage.describe_resistance(resistance),
		eff.get("source_name", "unknown")
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
	var value = comb.get(stat, 0)
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
	apply_drift(comb)
	emit_signal("turn_advanced", comb)
	emit_signal("update_combatants", combatants)
	if comb.side == 1:
		# Look at them before they act, so the pause below is the view travelling
		# rather than dead air.
		watch_combatant(comb)
		await get_tree().create_timer(0.6).timeout
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
	var direction = DIRECTIONS[randi() % DIRECTIONS.size()]
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


func combat_finish():
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
	return target.get("resistances", {}).get(type, 0)


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
func float_number(target: Dictionary, text: String, colour: Color):
	var sprite = target.get("sprite")
	if sprite == null or not is_instance_valid(sprite) or sprite.get_parent() == null:
		return
	FloatingNumber.spawn(sprite.get_parent(), sprite.position, text, colour)


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
		Engine.time_scale = 1.0


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
	if _hit_stop_depth > 0:
		_hit_stop_depth = 0
		Engine.time_scale = 1.0


## --- Attributes and the damage they produce ---


## One of the five attributes on `comb`, by Stats.Type. Ten for anyone created
## before stats existed, which is the database default too, so an unfilled
## entry behaves like an ordinary one rather than dealing nothing.
func stat_of(comb: Dictionary, type: int) -> int:
	var key = Stats.stat_key(type)
	if key == "":
		return 0
	return comb.get("stats", {}).get(key, 10)


## Whether a contested skill lands in full on `target`. The caster's own
## scaling stat is weighed against whichever stat the skill names - so the same
## Fireball that overwhelms a frail sorcerer only singes an armoured knight,
## with no dice involved either way.
func wins_contest(attacker: Dictionary, target: Dictionary, skill: SkillDefinition) -> bool:
	return stat_of(target, skill.contest_stat) < stat_of(attacker, skill.scaling_stat)


## What one DAMAGE effect of `skill` does to `target`, before resistances.
## `power` is 1.0 for a clean hit and 0.5 for a graze.
##
## BaseDamage = WeaponBase + 0.7 x Stat, FinalDamage = BaseDamage x
## AbilityModifier x 40/(40 + Defense). The effect's own min/max amounts are
## not consulted at all - a skill's damage is entirely the caster's stat and
## the skill's modifier, which is what makes the same spell scale with whoever
## casts it.
func skill_damage(attacker: Dictionary, target: Dictionary, skill: SkillDefinition, power: float = 1.0) -> int:
	if skill is ItemDefinition:
		# A bomb is a bomb whoever throws it, so nothing of the thrower goes into
		# this. The target still soaks it with their Defense exactly as they would
		# a skill - an item does not scale, but it is still contested.
		return Stats.final_damage(skill.flat_power, power, stat_of(target, Stats.Type.DEFENSE))
	var base = Stats.base_damage(stat_of(attacker, skill.scaling_stat), attacker.get("weapon_base", Stats.WEAPON_BASE))
	return Stats.final_damage(base, skill.ability_modifier * power, stat_of(target, Stats.Type.DEFENSE))



## What `skill` mends when `healer` casts it. No defence on the other side of
## it - being tough does not make you harder to patch up - and no randomness,
## so a heal is something you can count on when deciding whether it is enough.
func heal_amount(healer: Dictionary, skill: SkillDefinition) -> int:
	if skill is ItemDefinition:
		# What is written on the bottle, whoever uncorks it. Nothing contests a
		# heal, so unlike damage it is simply the number.
		return maxi(skill.flat_power, 0)
	var base = Stats.base_damage(stat_of(healer, skill.scaling_stat), healer.get("weapon_base", Stats.WEAPON_BASE))
	return maxi(roundi(base * skill.ability_modifier), 0)


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
	return Stats.base_damage(stat_of(attacker, skill.scaling_stat)) * skill.ability_modifier * modifier


func do_damage(attacker: Dictionary, target: Dictionary, effect: EffectDefinition, skill: SkillDefinition = null, mention_skill: bool = false, power: float = 1.0):
	var resistance = resistance_of(target, effect.damage_type)
	# A skill's damage comes from the caster's stat and the skill's modifier.
	# The effect's own min/max only stand in when there is no skill behind the
	# damage at all - a condition burning away, a shove into a wall.
	var raw = skill_damage(attacker, target, skill, power) if skill != null else randi_range(effect.min_amount, effect.max_amount)
	var damage = resisted_damage(target, effect.damage_type, raw)
	var flavour = "%s damage%s" % [Damage.type_name(effect.damage_type).to_lower(), Damage.describe_resistance(resistance)]
	target.hp -= damage
	show_damage(target, damage, effect.damage_type)
	update_combatants.emit(combatants)
	if mention_skill and skill != null:
		update_information.emit("[color=yellow]%s[/color] used %s on [color=red]%s[/color], dealing [color=gray]%d %s[/color].\n" % [
			attacker.name, skill.name, target.name, damage, flavour
		])
	else:
		update_information.emit("[color=yellow]%s[/color] dealt [color=gray]%d %s[/color] to [color=red]%s[/color].\n" % [
			attacker.name, damage, flavour, target.name
		])
	if target.hp <= 0:
		combatant_die(target)


func do_heal(attacker: Dictionary, target: Dictionary, effect: EffectDefinition, skill: SkillDefinition = null, mention_skill: bool = false):
	# The same shape as damage: the healer's stat and the skill's modifier. The
	# effect's flat range only stands in when there is no skill behind the
	# healing at all, the way it does for damage.
	var amount = heal_amount(attacker, skill) if skill != null else randi_range(effect.min_amount, effect.max_amount)
	target.hp = mini(target.hp + amount, get_effective_stat(target, "max_hp"))
	float_number(target, "+" + str(amount), Color("7fe08a"))
	update_combatants.emit(combatants)
	if mention_skill and skill != null:
		update_information.emit("[color=yellow]%s[/color] used %s on [color=lightgreen]%s[/color], healing [color=gray]%d[/color].\n" % [
			attacker.name, skill.name, target.name, amount
		])
	else:
		update_information.emit("[color=yellow]%s[/color] healed [color=lightgreen]%s[/color] for [color=gray]%d[/color].\n" % [
			attacker.name, target.name, amount
		])


func combatant_die(combatant: Dictionary):
	var	comb_id = combatants.find(combatant)
	if comb_id != -1:
		combatant.alive = false
		groups[combatant.side].erase(comb_id)
		update_information.emit("[color=red]{0}[/color] died.\n".format([
			combatant.name
		]
	))
	combatant.sprite.set_dead()
	combatant_died.emit(combatant)
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
		if not candidate.alive:
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
		if not candidate.alive:
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
## single-target skills specifically. Falls back to "greatsword_attack".
## Picks by the range they can actually manage right now, not the range printed
## on the skill - a blinded combatant should reach for something usable at one
## tile rather than an archery skill it can no longer aim.
func find_best_single_target_skill(comb: Dictionary) -> String:
	var best_key = "greatsword_attack"
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
	for dx in range(-reach, reach + 1):
		var remaining = reach - absi(dx)
		for dy in range(-remaining, remaining + 1):
			var d = absi(dx) + absi(dy)
			if d < skill.min_range:
				continue
			var aim = caster_position + Vector2i(dx, dy)
			var tiles = get_impact_tiles(skill, caster_position, aim, movement_class)
			var count = 0
			for index in groups[Group.PLAYERS]:
				var p = combatants[index]
				if p.alive and p.position in tiles:
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
		if p.alive and p.position in tiles:
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
		if p.alive and not has_line_of_sight(p.position, position, p.movement_class):
			count += 1
	return count


## Manhattan distance from `tile` to the nearest living player, or -1 if there
## are none left.
func distance_to_nearest_player(tile: Vector2i) -> int:
	var best = -1
	for index in groups[Group.PLAYERS]:
		var p = combatants[index]
		if not p.alive:
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
			for skill_key in reactor.skill_list:
				var skill: SkillDefinition = SkillDatabase.skills[skill_key]
				if not skill.is_reactive:
					continue
				var valid_side = (reactor.side == comb.side) if skill.targets_ally else (reactor.side != comb.side)
				if not valid_side:
					continue
				var distance_before = get_position_distance(reactor.position, from_tile)
				var distance_after = get_position_distance(reactor.position, to_tile)
				var was_in_range = distance_before >= skill.min_range and distance_before <= skill.max_range
				var now_in_range = distance_after >= skill.min_range and distance_after <= skill.max_range
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


## The Priest's equivalent of retreat_with_remaining_movement: spends whatever
## movement it has left on the safest tile that still keeps as many allies as
## possible inside heal reach. Coverage is weighted far above safety (see
## score_tile_safety, which is bounded by STANDOFF_CAP precisely so this can
## dominate it), so it will happily stand somewhere exposed if that's what
## staying able to heal a distant ally costs - but among tiles that cover the
## same allies it always takes the safest, which is what stops it planting
## itself next to the players and never moving.
const HEAL_COVERAGE_WEIGHT = 100.0

func reposition_healer(comb: Dictionary, heal_reach: int):
	if not comb.alive or controller.movement <= 0:
		return
	var tile = find_best_reachable_tile(comb, controller.movement, func(t):
		return float(count_allies_within_heal_reach(comb, t, heal_reach)) * HEAL_COVERAGE_WEIGHT + score_tile_safety(t)
	)
	tile = avoid_needless_opportunity_attacks(comb, tile, {})
	if tile != comb.position:
		await controller.ai_move(tile)


## Default enemy behaviour: rush the nearest enemy and melee it.
func ai_melee_rush(comb: Dictionary):
	var target = find_nearest_enemy_of(comb)
	if target.is_empty():
		await advance_turn()
		return
	if get_distance(comb, target) == 1:
		await use_skill("greatsword_attack", comb, target.position)
		return
	await controller.ai_process(target.position)
	if comb.alive:
		await use_skill("greatsword_attack", comb, target.position)


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
	var target = find_lowest_hp_enemy_of(comb)
	if target.is_empty():
		await advance_turn()
		return
	var skill_key = find_best_single_target_skill(comb)
	var skill: SkillDefinition = SkillDatabase.skills[skill_key]
	var attacked = await move_into_range_of(comb, target.position, skill, movement_budget, true, target)
	if attacked:
		await use_skill(skill_key, comb, target.position, false)
	if attacked:
		await retreat_with_remaining_movement(comb, target, skill.max_range + movement_budget)
	await advance_turn()


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
				await reposition_healer(comb, heal_reach)
				await advance_turn()
				return
	var cleanse_skill_key = find_skill_of_type(comb, EffectDefinition.EffectType.DISPEL)
	if cleanse_skill_key != "" and comb.alive:
		var afflicted = find_most_afflicted_ally(comb)
		if not afflicted.is_empty():
			var skill: SkillDefinition = SkillDatabase.skills[cleanse_skill_key]
			if await move_into_range_of(comb, afflicted.position, skill, movement_budget, true, afflicted):
				await use_skill(cleanse_skill_key, comb, afflicted.position, false)
				await reposition_healer(comb, heal_reach)
				await advance_turn()
				return
	if not comb.alive:
		return
	var nearest_enemy = find_nearest_enemy_of(comb)
	if not nearest_enemy.is_empty() and get_distance(comb, nearest_enemy) == 1:
		await use_skill("greatsword_attack", comb, nearest_enemy.position, false)
		await reposition_healer(comb, heal_reach)
		await advance_turn()
		return
	await reposition_healer(comb, heal_reach)
	await advance_turn()


## Searches, for each area-effect offensive skill in its kit, every
## reachable position and picks whichever combination of skill + position +
## aim scores best on a blend of "how many living players would this hit"
## and "how many players would NOT be able to see me here" (count_players_
## without_los) - so a meaningfully safer casting spot can win out over a
## marginally more damaging one, though hitting nobody never does. HIT_WEIGHT
## and SAFETY_WEIGHT set that balance; tune them here if it feels off. Falls
## back to approaching and plain-attacking the nearest enemy if no AoE skill
## could hit anyone from anywhere reachable.
func ai_caster(comb: Dictionary):
	const HIT_WEIGHT = 10.0
	const SAFETY_WEIGHT = 3.0
	var target = find_nearest_enemy_of(comb)
	if target.is_empty():
		await advance_turn()
		return
	var movement_budget = movement_budget_of(comb)
	var best_skill_key = ""
	var best_tile = comb.position
	var best_aim = comb.position
	var best_score = -INF
	for skill_key in comb.skill_list:
		var skill: SkillDefinition = SkillDatabase.skills[skill_key]
		if skill.targets_ally or skill.aoe_radius <= 0:
			continue
		if not can_afford_skill(comb, skill) or not meets_level_for(comb, skill):
			continue # out of slots for it, or not learned yet
		var tile = find_best_reachable_tile(comb, movement_budget, func(t):
			var hits = find_best_aim_and_count(skill, t, comb.movement_class, comb).count
			return float(hits) * HIT_WEIGHT + float(count_players_without_los(t)) * SAFETY_WEIGHT
		)
		var result = find_best_aim_and_count(skill, tile, comb.movement_class, comb)
		if result.count <= 0:
			continue
		var score = float(result.count) * HIT_WEIGHT + float(count_players_without_los(tile)) * SAFETY_WEIGHT
		if score > best_score:
			best_score = score
			best_skill_key = skill_key
			best_tile = tile
			best_aim = result.position
	if best_skill_key != "":
		var safe_tile = avoid_needless_opportunity_attacks(comb, best_tile, target)
		if safe_tile != best_tile:
			# The original best position wasn't safe enough - recompute the
			# aim (and check there's still something to hit) from wherever
			# we're actually willing to end up instead.
			var result = find_best_aim_and_count(SkillDatabase.skills[best_skill_key], safe_tile, comb.movement_class, comb)
			if result.count <= 0:
				await advance_turn()
				return
			best_aim = result.position
			best_tile = safe_tile
		if best_tile != comb.position:
			await controller.ai_move(best_tile)
		if comb.alive:
			await use_skill(best_skill_key, comb, best_aim, false)
		# Back off with whatever movement is left rather than standing where it
		# just fired from - an area skill's range is long enough that the
		# casting tile is almost never the tile you want to be standing on when
		# the players get their turn.
		await retreat_with_remaining_movement(comb, target, SkillDatabase.skills[best_skill_key].max_range + movement_budget)
		await advance_turn()
		return
	# No AoE skill can hit anyone from anywhere reachable - fall back to a
	# normal approach-and-attack instead of wasting the turn.
	await controller.ai_process(target.position)
	if comb.alive:
		await use_skill("greatsword_attack", comb, target.position, false)
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
		await use_skill(skill_key, comb, target.position, false)
		await advance_turn()
		return
	if not comb.alive:
		return
	# Couldn't reach for the copied skill - fall back to a normal
	# rush-and-melee approach so the turn isn't wasted.
	await controller.ai_process(target.position)
	if comb.alive:
		await use_skill("greatsword_attack", comb, target.position, false)
	await advance_turn()


func ai_pick_target(weights):
	var rand_num = randf()
	var full_weight = 1.0
	for w in weights:
		var weight = w[0]
		full_weight -= weight
		if rand_num > full_weight - 0.001: #full_weight - 0.001 due to float inaccuracy
			return w[1]


## --- Knowing your enemy ---


## What studying someone is worth when you then take a swing at them. Ten points
## of accuracy: enough to be worth the action against anything you were going to
## struggle to hit, and not enough to make a bad shot a good one.
const STUDIED_ACCURACY_BONUS := 10


## Whether `attacker` is the one who measured `target`.
##
## Per studier rather than per side: the sheet is the player's to read once
## anybody has looked, but the advantage of having looked is the studier's.
func _has_studied(attacker: Dictionary, target: Dictionary) -> bool:
	if attacker == null or target == null or target.is_empty():
		return false
	return attacker.get("id", -1) in target.get("studied_by", [])


## The chance `attacker` has of landing `skill` on `target`, all in: the skill's
## own accuracy, whatever conditions are helping or hindering them, and the
## bonus for having studied who they are aiming at.
##
## `target` may be empty - an area skill rolls once before it knows who it
## caught, and rolls against whoever is standing where it was aimed.
func hit_chance(attacker: Dictionary, skill: SkillDefinition, target: Dictionary = {}) -> int:
	var chance = skill.accuracy + get_effective_stat(attacker, "accuracy")
	if _has_studied(attacker, target):
		chance += STUDIED_ACCURACY_BONUS
	return clampi(chance, 0, 100)


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
