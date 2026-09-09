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

var skills_lists = [
	["attack_melee", "slowing_strike", "run"], #Melee
	["attack_melee", "attack_ranged", "lightning_bolt", "poison_dart", "run"], #Ranged
	["attack_melee", "basic_magic", "heal", "fireball", "flame_cone", "curse", "vitality", "cleanse", "repel", "gravity_pull", "run"] #Magic
]


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
			continue
		add_combatant(create_combatant(CombatantDatabase.combatants[spawn.combatant_key], spawn.combatant_key, spawn.display_name), 1, spawn.position)

	_deploy_party(player_tiles, fallback_party)

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
func _deploy_party(tiles: Array, fallback_party: Array):
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
		var comb = create_combatant(CombatantDatabase.combatants[key], key)
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
	await get_tree().create_timer(0.6).timeout
	await ai_process(combatants[current_combatant])


func create_combatant(definition: CombatantDefinition, combatant_key: String = "", override_name = ""):
	var comb = {
		"name" = definition.name,
		"max_hp" = definition.max_hp,
		"hp" = definition.max_hp,
		"class" = definition.class_t,
		"alive" = true,
		"movement_class" = definition.class_m,
		"skill_list" = skills_lists[definition.class_t].duplicate(),
		"icon" = definition.icon,
		"map_sprite" = definition.map_sprite,
		"sprite_frames" = definition.sprite_frames,
		"movement" = definition.movement,
		"initiative" = definition.initiative,
		"turn_taken" = false,
		"status_effects" = [], # Active timed effects: {"stat":"movement","amount":-2,"duration":2} or a DoT tick: {"stat":"dot","min_amount":2,"max_amount":4,"duration":3}
		"skill_used_this_turn" = false,
		"secondary_used_this_turn" = false,
		"secondary_skills" = definition.secondary_skills.duplicate(),
		"reaction_used" = false,
		"ai_function" = definition.ai_function,
		# Which CombatantDatabase entry this came from. Campaign keys the
		# party's carried-over health off this, so it survives the combatant
		# dictionary being rebuilt from scratch for each encounter.
		"combatant_key" = combatant_key
		}
	if override_name != "":
		comb.name = override_name
	if definition.skills.size() > 0:
		comb["skill_list"].append_array(definition.skills)
	return comb

func sort_turn_queue(a, b):
	if combatants[b].initiative < combatants[a].initiative:
		return true
	else:
		return false

func add_combatant(combatant: Dictionary, side: int, position: Vector2i):
	combatant["position"] = position
	combatant["side"] = side
	combatants.append(combatant)
	groups[side].append(combatants.size() - 1)

	var new_combatant_sprite = CombatantSprite.new()
	$"../Terrain/TileMap".add_child(new_combatant_sprite)
	new_combatant_sprite.position = Vector2(position * 32.0) + Vector2(16, 16)
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

func main_skills_of(comb: Dictionary) -> Array:
	var found = []
	for key in comb.skill_list:
		if SkillDatabase.skills.has(key) and not SkillDatabase.skills[key].is_secondary:
			found.append(key)
	return found


func secondary_skills_of(comb: Dictionary) -> Array:
	var found = []
	for key in comb.skill_list:
		if SkillDatabase.skills.has(key) and SkillDatabase.skills[key].is_secondary:
			found.append(key)
	# A combatant's own secondary list can also grant a skill outright, so a
	# character-specific secondary doesn't have to sit in their main list too.
	for key in comb.get("secondary_skills", []):
		if SkillDatabase.skills.has(key) and not found.has(key):
			found.append(key)
	return found


## Whether `comb` still has either action available. Used to decide when a turn
## has nothing left to do and can end on its own.
func has_action_left(comb: Dictionary) -> bool:
	if not comb.get("skill_used_this_turn", false) and not main_skills_of(comb).is_empty():
		return true
	if not comb.get("secondary_used_this_turn", false) and not secondary_skills_of(comb).is_empty():
		return true
	return false

func get_distance(attacker: Dictionary, target: Dictionary):
	return get_position_distance(attacker.position, target.position)


## Generic entry point for using ANY skill - this replaced the old separate
## attack_melee()/attack_ranged()/basic_magic() functions. A new skill needs
## no new code here at all: just add it to skill_database.tscn and reference
## its key in a combatant's skill list.
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
func use_skill(skill_key: String, attacker: Dictionary, impact_position: Vector2i, end_turn_after: bool = true, as_secondary: bool = false):
	var skill: SkillDefinition = SkillDatabase.skills[skill_key]
	var distance = get_position_distance(attacker.position, impact_position)
	var valid = distance <= skill.max_range and distance >= skill.min_range
	if valid:
		controller.action_locked = true
		game_ui.lock_action_buttons()
		await attacker.sprite.play_skill_and_wait()
		controller.action_locked = false
		game_ui.refresh_action_buttons()
		if not attacker.alive:
			# Something else killed them while their own skill's animation
			# was still playing - nothing left to resolve.
			return
		var prob = clampi(skill.accuracy + get_effective_stat(attacker, "accuracy"), 0, 100)
		var random_number = randi() % 100
		if attacker.side == 0:
			last_player_skill_used = skill_key
		if random_number < prob:
			var tiles = get_impact_tiles(skill, attacker.position, impact_position, attacker.movement_class)
			var targets = get_targets_in_tiles(tiles, attacker, skill.targets_ally)
			for target in targets:
				# Only the first effect on each target names the skill, so a
				# multi-effect hit reads as one action rather than repeating
				# "used Poison Dart" for every effect it carries.
				var mention_skill = true
				for effect in skill.effects:
					apply_effect(attacker, target, effect, skill, mention_skill)
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
	for reactor in combatants:
		if not reactor.alive or reactor == mover or reactor.reaction_used:
			continue
		for skill_key in reactor.skill_list:
			var skill: SkillDefinition = SkillDatabase.skills[skill_key]
			if not skill.is_reactive:
				continue
			var valid_side = (reactor.side == mover.side) if skill.targets_ally else (reactor.side != mover.side)
			if not valid_side:
				continue
			var distance_before = get_position_distance(reactor.position, previous_position)
			var distance_after = get_position_distance(reactor.position, new_position)
			var was_in_range = distance_before >= skill.min_range and distance_before <= skill.max_range
			var now_in_range = distance_after >= skill.min_range and distance_after <= skill.max_range
			if was_in_range and not now_in_range:
				await use_reactive_skill(skill_key, reactor, mover, previous_position)
				if not mover.alive:
					return
				break


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
	update_information.emit("[color=yellow]{0}[/color] reacts as [color=red]{1}[/color] leaves range!\n".format([
		attacker.name,
		target.name
	]))
	controller.action_locked = true
	game_ui.lock_action_buttons()
	await attacker.sprite.play_skill_and_wait()
	controller.action_locked = false
	game_ui.refresh_action_buttons()
	if not attacker.alive or not target.alive:
		return
	var prob = clampi(skill.accuracy + get_effective_stat(attacker, "accuracy"), 0, 100)
	var random_number = randi() % 100
	if random_number < prob:
		var mention_skill = true
		for effect in skill.effects:
			apply_effect(attacker, target, effect, skill, mention_skill)
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
func get_range_tiles(skill: SkillDefinition, caster_position: Vector2i, movement_class: int = 0) -> Array:
	var tiles = []
	for tile in get_diamond_tiles(caster_position, skill.max_range):
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
func get_targets_in_tiles(tiles: Array, caster: Dictionary, targets_ally: bool) -> Array:
	var result = []
	for comb in combatants:
		if not comb.alive:
			continue
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
func apply_effect(attacker: Dictionary, target: Dictionary, effect: EffectDefinition, skill: SkillDefinition = null, mention_skill: bool = false):
	match effect.type:
		EffectDefinition.EffectType.DAMAGE:
			do_damage(attacker, target, effect, skill, mention_skill)
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
				"min_amount" = effect.min_amount,
				"max_amount" = effect.max_amount,
				"duration" = stored_duration(target, effect),
				"source_name" = attacker.name
			})
			update_information.emit(describe_condition(attacker, target, effect, skill, mention_skill, "a lingering wound"))
		EffectDefinition.EffectType.DISPEL:
			dispel_status_effects(attacker, target, effect)
		EffectDefinition.EffectType.PUSH:
			apply_knockback(attacker, target, effect, false)
		EffectDefinition.EffectType.PULL:
			apply_knockback(attacker, target, effect, true)


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
func stored_duration(target: Dictionary, effect: EffectDefinition) -> int:
	if target == get_current_combatant():
		return maxi(effect.duration - 1, 0)
	return effect.duration


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
	var i = target.status_effects.size() - 1
	while i >= 0:
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
## exactly unless they're already aligned). If a PUSH (not a PULL) gets
## stopped short specifically by the map edge or a blocking tile, it also
## deals effect.min_amount-max_amount collision damage - being slammed into
## a wall hurts; bumping into another combatant, or a pull falling short,
## doesn't.
func apply_knockback(attacker: Dictionary, target: Dictionary, effect: EffectDefinition, pulling: bool):
	if target.position == attacker.position:
		return
	var direction = get_octant_direction(attacker.position, target.position)
	if pulling:
		direction = -direction
	var old_position = target.position
	var final_position = target.position
	var hit_obstacle = false
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
			break
		final_position = candidate
	if final_position != old_position:
		target.position = final_position
		target.sprite.position = Vector2(final_position * 32.0) + Vector2(16, 16)
		controller.reposition_combatant(old_position, final_position)
		var distance_moved = get_position_distance(old_position, final_position)
		update_information.emit("[color=yellow]{0}[/color] {1} [color=red]{2}[/color] {3} tile(s)\n".format([
			attacker.name,
			"dragged" if pulling else "shoved",
			target.name,
			distance_moved
		]))
	if hit_obstacle and not pulling and target.alive and effect.max_amount > 0:
		var collision_damage = randi_range(effect.min_amount, effect.max_amount)
		target.hp -= collision_damage
		update_combatants.emit(combatants)
		update_information.emit("[color=red]{0}[/color] slammed into an obstacle, taking [color=gray]{1} damage[/color]\n".format([
			target.name,
			collision_damage
		]))
		if target.hp <= 0:
			combatant_die(target)


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
		eff.duration -= 1
		i -= 1
	clamp_hp_to_max(comb)


func tick_damage_over_time(comb: Dictionary, eff: Dictionary):
	if not comb.alive:
		return
	var amount = randi_range(eff.min_amount, eff.max_amount)
	comb.hp -= amount
	update_combatants.emit(combatants)
	update_information.emit("[color=red]{0}[/color] took [color=gray]{1} damage[/color] from a lingering effect ({2})\n".format([
		comb.name,
		amount,
		eff.get("source_name", "unknown")
	]))
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
		process_status_effects(comb)
		if not comb.alive:
			# A damage-over-time tick (or similar) killed them just as their
			# turn was starting - skip straight to whoever's next.
			set_next_combatant()
			comb = combatants[current_combatant]
			continue
		break
	emit_signal("turn_advanced", comb)
	emit_signal("update_combatants", combatants)
	if comb.side == 1:
		await get_tree().create_timer(0.6).timeout
		await ai_process(comb)


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


func do_damage(attacker: Dictionary, target: Dictionary, effect: EffectDefinition, skill: SkillDefinition = null, mention_skill: bool = false):
	var damage = randi_range(effect.min_amount, effect.max_amount)
	target.hp -= damage
	update_combatants.emit(combatants)
	if mention_skill and skill != null:
		update_information.emit("[color=yellow]%s[/color] used %s on [color=red]%s[/color], dealing [color=gray]%d damage[/color].\n" % [
			attacker.name, skill.name, target.name, damage
		])
	else:
		update_information.emit("[color=yellow]%s[/color] dealt [color=gray]%d damage[/color] to [color=red]%s[/color].\n" % [
			attacker.name, damage, target.name
		])
	if target.hp <= 0:
		combatant_die(target)


func do_heal(attacker: Dictionary, target: Dictionary, effect: EffectDefinition, skill: SkillDefinition = null, mention_skill: bool = false):
	var amount = randi_range(effect.min_amount, effect.max_amount)
	target.hp = mini(target.hp + amount, get_effective_stat(target, "max_hp"))
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
## single-target skills specifically. Falls back to "attack_melee".
func find_best_single_target_skill(comb: Dictionary) -> String:
	var best_key = "attack_melee"
	var best_range = -1
	for skill_key in comb.skill_list:
		var skill: SkillDefinition = SkillDatabase.skills[skill_key]
		if skill.targets_ally or skill.aoe_radius > 0:
			continue
		if skill.max_range > best_range:
			best_range = skill.max_range
			best_key = skill_key
	return best_key


## The first skill in comb's skill_list that has at least one effect of
## `effect_type`, or "" if it has none.
func find_skill_of_type(comb: Dictionary, effect_type: EffectDefinition.EffectType) -> String:
	for skill_key in comb.skill_list:
		var skill: SkillDefinition = SkillDatabase.skills[skill_key]
		for effect in skill.effects:
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
func is_effectively_in_range(skill: SkillDefinition, from_position: Vector2i, target_position: Vector2i, movement_class: int) -> bool:
	var d = get_position_distance(from_position, target_position)
	if d < skill.min_range or d > skill.max_range:
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
		if is_effectively_in_range(skill, tile, target_position, comb.movement_class):
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
func find_best_aim_and_count(skill: SkillDefinition, caster_position: Vector2i, movement_class: int) -> Dictionary:
	var best_aim = caster_position
	var best_count = 0
	for dx in range(-skill.max_range, skill.max_range + 1):
		var remaining = skill.max_range - absi(dx)
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


## The largest possible damage a skill could deal in one hit - sums every
## DAMAGE effect's max_amount, ignoring accuracy/hit chance entirely. Used
## for a worst-case "could this possibly kill me" check, not an average.
func get_max_possible_damage(skill: SkillDefinition) -> int:
	var total = 0
	for effect in skill.effects:
		if effect.type == EffectDefinition.EffectType.DAMAGE:
			total += effect.max_amount
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
		total_possible_damage += get_max_possible_damage(reactive_skill)
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
	if is_effectively_in_range(skill, comb.position, target_position, comb.movement_class) and not seek_cover:
		return true
	var tile: Vector2i
	if seek_cover:
		tile = find_best_reachable_tile(comb, movement_budget, func(t):
			var range_score: float
			if is_effectively_in_range(skill, t, target_position, comb.movement_class):
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
	return is_effectively_in_range(skill, comb.position, target_position, comb.movement_class)


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
		await use_skill("attack_melee", comb, target.position)
		return
	await controller.ai_process(target.position)
	if comb.alive:
		await use_skill("attack_melee", comb, target.position)


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
	var movement_budget = get_effective_stat(comb, "movement")
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
	var movement_budget = get_effective_stat(comb, "movement")
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
	var movement_budget = get_effective_stat(comb, "movement")
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
		await use_skill("attack_melee", comb, nearest_enemy.position, false)
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
	var movement_budget = get_effective_stat(comb, "movement")
	var best_skill_key = ""
	var best_tile = comb.position
	var best_aim = comb.position
	var best_score = -INF
	for skill_key in comb.skill_list:
		var skill: SkillDefinition = SkillDatabase.skills[skill_key]
		if skill.targets_ally or skill.aoe_radius <= 0:
			continue
		var tile = find_best_reachable_tile(comb, movement_budget, func(t):
			var hits = find_best_aim_and_count(skill, t, comb.movement_class).count
			return float(hits) * HIT_WEIGHT + float(count_players_without_los(t)) * SAFETY_WEIGHT
		)
		var result = find_best_aim_and_count(skill, tile, comb.movement_class)
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
			var result = find_best_aim_and_count(SkillDatabase.skills[best_skill_key], safe_tile, comb.movement_class)
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
		await use_skill("attack_melee", comb, target.position, false)
	await advance_turn()


## Picks who a Copycat should aim a copied ally-targeting skill at: the most
## injured ally for a HEAL skill, the most afflicted ally for a DISPEL
## skill, or comb itself for anything else (a plain buff like Run or
## Vitality) - falling back to comb itself if there's no better candidate
## (e.g. a HEAL skill but nobody's actually hurt).
func pick_ally_target_for_skill(comb: Dictionary, skill: SkillDefinition) -> Dictionary:
	for effect in skill.effects:
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
	var movement_budget = get_effective_stat(comb, "movement")
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
		await use_skill("attack_melee", comb, target.position, false)
	await advance_turn()


func ai_pick_target(weights):
	var rand_num = randf()
	var full_weight = 1.0
	for w in weights:
		var weight = w[0]
		full_weight -= weight
		if rand_num > full_weight - 0.001: #full_weight - 0.001 due to float inaccuracy
			return w[1]
