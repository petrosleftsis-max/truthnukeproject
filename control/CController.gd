extends Node2D
class_name CController
##Class for controlling sprites representing combatants on the tile map

signal movement_changed(movement: int)
signal finished_move
signal target_selection_started()
signal target_selection_finished()

@export var controlled_node : Node2D
@export var combat: Combat

var tile_map : TileMap

var movement = 3:
	set = set_movement,
	get = get_movement

var _astargrid = AStarGrid2D.new()

var player_turn = true
## True while a skill's animation (this combatant's own, or a reactive one
## triggered elsewhere) is playing and resolving - blocks all input, since
## the combatant using it (and, per _process's re-entrancy guard, movement
## generally) is meant to be unable to do anything else until it finishes.
var action_locked = false

var _attack_target_position
var _blocked_target_position
var _ally_target_position
var _aoe_preview_positions: Array = []
var _aoe_preview_is_ally: bool = false
var _range_preview_positions: Array = []

## Every tile some living enemy can see, drawn while a hidden player is taking
## their turn so they can plan a route that keeps them hidden.
##
## Worked out once when the turn starts rather than per frame: it is a line of
## sight from every enemy to every tile in the region, which is far too much to
## do sixty times a second, and it cannot change while the player is the one
## moving - the watchers stay where they are.
var _watched_tiles: Array = []

## True while a skill that would hide whoever casts it is being aimed. The enemy
## lines of sight are worth seeing before committing to hiding, not only after -
## choosing where to disappear is the whole decision.
var _previewing_hide := false

var _skill_selected = false

## Whether `skill` would take whoever casts it out of sight.
func hides_its_caster(skill: SkillDefinition) -> bool:
	if skill == null:
		return false
	for effect in skill.all_effects():
		if effect != null and effect.type == EffectDefinition.EffectType.HIDE:
			return true
	return false


## Whether a skill is currently being aimed (target selection in progress).
## Used by the pause menu to avoid stealing Escape away from cancelling
## that, which takes priority.
func is_skill_selected() -> bool:
	return _skill_selected

## --- Deployment ---
##
## Before the first turn the player arranges the party across the encounter's
## starting tiles: click one of your own, then a highlighted tile to move them
## there, swapping with whoever already has it.

var _deployment_active := false
var _deployment_tiles: Array = []
var _deployment_selection = null


func begin_deployment(tiles: Array):
	_deployment_active = true
	_deployment_tiles = tiles.duplicate()
	_deployment_selection = null
	queue_redraw()


func end_deployment():
	_deployment_active = false
	_deployment_tiles = []
	_deployment_selection = null
	queue_redraw()


func _handle_deployment_input(event):
	if not event is InputEventMouseButton:
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.is_released():
		return
	var tile = tile_map.local_to_map(get_global_mouse_position())
	var comb = get_combatant_at_position(tile)
	if _deployment_selection == null:
		if comb != null and comb.side == 0:
			_deployment_selection = comb
			queue_redraw()
		return
	if tile in _deployment_tiles:
		_swap_deployed(_deployment_selection, tile)
		_deployment_selection = null
	elif comb != null and comb.side == 0:
		# Clicked a different hero instead - switch who's being moved.
		_deployment_selection = comb
	queue_redraw()


## Moves `comb` onto `tile`, trading places with whoever is already standing
## there. Enemies are never displaced - their positions are the encounter's
## design, not the player's to rearrange.
func _swap_deployed(comb: Dictionary, tile: Vector2i):
	if comb.side != 0:
		# Only the party is the player's to arrange. Input can't select an
		# enemy in the first place, but this is the function that actually
		# moves people, so it enforces it rather than trusting the caller.
		return
	var occupant = get_combatant_at_position(tile)
	if occupant == comb:
		return
	if occupant != null and occupant.side != 0:
		return
	var from = comb.position
	if occupant == null:
		_occupied_spaces.erase(from)
		_occupied_spaces[tile] = true
		release_tile(from)
	else:
		# A straight swap: both tiles stay occupied, so the occupancy list
		# doesn't change at all.
		_set_deployed_position(occupant, from)
	_set_deployed_position(comb, tile)
	update_points_weight()


func _set_deployed_position(comb: Dictionary, tile: Vector2i):
	comb.position = tile
	comb.sprite.position = tile_map.map_to_local(tile)


## Whether the character sheet is up. Reading somebody's sheet should not also
## be ordering the party around behind it: a click meant for the sheet landed
## on the map underneath and walked whoever was acting.
func reading_a_character_sheet() -> bool:
	var sheet = get_node_or_null("../CharacterSheet")
	return sheet != null and sheet.has_method("is_open") and sheet.is_open()


## Whether anything the player is reading or choosing from is over the map -
## the character sheet, or the pause menu and its options. Neither the map nor
## the End Turn key is theirs to drive while one of those is up.
func a_menu_is_over_the_map() -> bool:
	if reading_a_character_sheet():
		return true
	var pause = get_node_or_null("../PauseUI")
	if pause == null:
		return false
	for panel in ["PausePanel", "OptionsPanel"]:
		var node = pause.get_node_or_null(panel)
		if node != null and node.visible:
			return true
	return false


func _unhandled_input(event):
	if _deployment_active:
		_handle_deployment_input(event)
		return
	if player_turn == false or action_locked:
		return
	if a_menu_is_over_the_map():
		return

	if _skill_selected and event.is_action_pressed("ui_cancel"):
		cancel_skill_selection()
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.is_released():
			if _skill_selected:
				cancel_skill_selection()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_released():
				if _skill_selected == true:
					var mouse_position = get_global_mouse_position()
					var mouse_position_i = tile_map.local_to_map(mouse_position)
					var skill = SkillDatabase.skills[_selected_skill]
					if picking_a_landing_tile():
						# Aiming at somewhere to stand, which has to be a tile the
						# traveller fits on - a body standing there is not a target,
						# it is the reason they cannot go.
						if is_valid_landing_tile(mouse_position_i):
							confirm_skill_target(mouse_position_i)
					elif skill.aoe_radius > 0:
						# Area skills can be aimed at any tile, occupied or not.
						confirm_skill_target(mouse_position_i)
					else:
						var comb = get_combatant_at_position(mouse_position_i)
						if comb != null and comb.alive and is_valid_skill_target(comb):
							confirm_skill_target(comb.position)
				elif _arrived == true:
					move_player()
	
	if event is InputEventMouseMotion:
		if _arrived == true:
			var mouse_position = get_global_mouse_position()
			var mouse_position_i = tile_map.local_to_map(mouse_position)
			find_path(mouse_position_i)
			var comb = get_combatant_at_position(mouse_position_i)
			var local_map = tile_map.map_to_local(mouse_position_i)
			_attack_target_position = null
			_ally_target_position = null
			_blocked_target_position = null
			_aoe_preview_positions = []
			if _skill_selected:
				var skill = SkillDatabase.skills[_selected_skill]
				if picking_a_landing_tile() and not is_valid_landing_tile(mouse_position_i):
					# Nowhere to arrive, so show no swing either: this click will
					# do nothing at all.
					_blocked_target_position = local_map
				elif skill.aoe_radius > 0:
					var caster = combat.get_current_combatant()
					_aoe_preview_positions = combat.get_impact_tiles(skill, caster.position, mouse_position_i, caster.movement_class)
					_aoe_preview_is_ally = skill.targets_ally
				elif comb != null and comb.alive and is_valid_skill_target(comb):
					if skill.targets_ally:
						_ally_target_position = local_map
					else:
						_attack_target_position = local_map
				elif comb != null:
					_blocked_target_position = local_map
			elif comb != null and comb.alive and comb.side == 1:
				_attack_target_position = local_map
			elif comb != null:
				_blocked_target_position = local_map
			elif is_tile_blocking(mouse_position_i, combat.get_current_combatant().movement_class):
				_blocked_target_position = local_map
			else:
				_blocked_target_position = null


func get_combatant_at_position(target_position: Vector2i):
	for comb in combat.combatants:
		if comb.position == target_position and comb.alive:
			return comb
	return null

## Every tile somebody is standing on. A Dictionary because line of sight asks
## it once per tile walked, and this is the most-called question in the game -
## an Array answered it by scanning, which is the same trap _blocking_lookup
## was built to get out of.
var _occupied_spaces := {}

var _blocking_spaces = [
	[],#Ground
	[],#Flying
	[]#Mounted
]

## Every tile that blocks at least one movement class, each listed once -
## unlike _blocking_spaces, a tile that blocks multiple classes (e.g.
## Blocks = [0, 2]) only appears here a single time.
var _all_blocking_spaces = []

## The same tiles as _blocking_spaces, as a set, for asking whether one tile is
## in there.
##
## "tile in array" walks the array. There are around fifteen hundred blocking
## tiles on the lab map, and is_tile_blocking is asked on every step of every
## line of sight - which the AI works out tens of thousands of times a turn, and
## which now also draws the enemy's field of view for a hidden player. That made
## the commonest question in the game a fifteen-hundred-element scan.
##
## Kept alongside the arrays rather than replacing them: other code walks them
## in order, and nothing ever removes a blocking tile, so the two cannot drift.
var _blocking_lookup: Array[Dictionary] = [{}, {}, {}]

## Whether `tile` blocks movement (and, when a skill opts in via
## SkillDefinition.respects_blocking, line of sight) for `movement_class`
## (0=Ground, 1=Flying, 2=Mounted). Same data movement already uses.
func is_tile_blocking(tile: Vector2i, movement_class: int) -> bool:
	return _blocking_lookup[movement_class].has(tile)


## Whether somebody is standing on `tile`, which breaks a line of sight the way
## a wall does.
##
## For every movement class alike: a body is a body, and flying does not see
## over one. Movement was already stopped by an occupied tile; this is what puts
## a person in front of an ally and calls it cover.
##
## Somebody hidden is no cover, though. A line that stopped dead at an empty
## stretch of floor would say exactly where they were standing - the shot that
## mysteriously will not connect is a better tell than seeing them.
func blocks_sight(tile: Vector2i) -> bool:
	if not _occupied_spaces.has(tile) or combat == null:
		return false
	var standing = combat.get_combatant_at(tile)
	return not standing.is_empty() and not combat.is_hidden(standing)


## Whether `tile` is inside the playable grid at all, regardless of blocking.
func is_in_bounds(tile: Vector2i) -> bool:
	return _astargrid.region.has_point(tile)


## Instantly moves a combatant to a new tile outside the normal turn-based
## movement flow (used by PUSH/PULL skill effects), keeping the pathfinding
## grid's occupancy tracking in sync so other units' movement/LOS is correct
## immediately afterwards.
func reposition_combatant(old_position: Vector2i, new_position: Vector2i):
	_occupied_spaces.erase(old_position)
	_occupied_spaces[new_position] = true
	release_tile(old_position)
	update_points_weight()


## Lets the pathfinding grid know nobody is standing on `tile` any more.
##
## update_points_weight() only ever visits tiles that are still occupied or are
## blocking terrain, so it can mark a tile solid but never unmark one: the
## releasing is done by whoever moved the body. Walking does it in
## _handle_step_arrival and dying does it in combatant_died; without this, a
## tile somebody was shoved, pulled, blown or teleported off stayed solid for
## the rest of the battle and nobody could ever walk onto it again. A blink
## still could, since teleporting asks Combat.can_land_on rather than this
## grid - which is exactly how the bug showed itself.
func release_tile(tile: Vector2i):
	if not is_in_bounds(tile):
		return
	_astargrid.set_point_solid(tile, false)
	_astargrid.set_point_weight_scale(tile, 1)


## The movement cost of entering `tile` for `movement_class` - the same
## "Cost" tile data get_tile_cost()/get_tile_cost_at_point() already use for
## whoever's turn it currently is, but explicit about which class, so it's
## safe to call for a class other than the current combatant's.
func get_tile_cost_for_class(tile: Vector2i, movement_class: int) -> int:
	if movement_class != 0:
		return 1
	var tile_data = tile_map.get_cell_tile_data(0, tile)
	if tile_data == null:
		return 1
	return int(tile_data.get_custom_data("Cost"))


## Every tile actually reachable from `start` within `movement_budget`
## movement points for `movement_class`, as a Dictionary mapping each
## reachable Vector2i to the movement cost spent getting there (Dijkstra-
## style flood fill over the real per-tile "Cost" data, blocking tiles, and
## other combatants in the way - not a straight-line guess). This is what
## the AI's positioning searches use to know where it can genuinely end up,
## the same way get_tile_cost()-based player movement already works.
func get_reachable_tiles(start: Vector2i, movement_class: int, movement_budget: int) -> Dictionary:
	const NEIGHBOR_OFFSETS = [
		Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN,
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
	]
	var costs = {start: 0}
	var frontier = [start]
	while frontier.size() > 0:
		# Pick the frontier tile with the lowest known cost so far (a plain
		# linear scan rather than a real priority queue - reachable areas
		# here are small enough that this is not worth the complexity).
		var best_index = 0
		for i in range(1, frontier.size()):
			if costs[frontier[i]] < costs[frontier[best_index]]:
				best_index = i
		var current = frontier[best_index]
		frontier.remove_at(best_index)
		var current_cost = costs[current]
		for offset in NEIGHBOR_OFFSETS:
			var neighbor = current + offset
			if not is_in_bounds(neighbor):
				continue
			if is_tile_blocking(neighbor, movement_class):
				continue
			if neighbor != start and neighbor in _occupied_spaces:
				continue
			if neighbor != start and _astargrid.is_point_solid(neighbor):
				# Whatever the pathfinder currently refuses to route through -
				# which includes tiles Fear has closed off - isn't somewhere the
				# AI should be offered either, or it picks a destination its own
				# move would then be refused for.
				continue
			var new_cost = current_cost + get_tile_cost_for_class(neighbor, movement_class)
			if new_cost > movement_budget:
				continue
			if not costs.has(neighbor) or new_cost < costs[neighbor]:
				costs[neighbor] = new_cost
				frontier.append(neighbor)
	return costs


## The actual sequence of grid tiles AStarGrid2D would walk to get from
## `from` to `to` - the same pathfinding real movement uses (via
## _astargrid.get_point_path), just converted from the world/local
## positions it returns back into grid coordinates. Exposed so Combat.gd's
## AI safety checks (e.g. avoid_needless_opportunity_attacks) can verify
## every step of a prospective move, not just its start and end - a route
## can dip into and back out of a threat's range partway through while its
## two endpoints look perfectly safe.
func get_grid_path(from: Vector2i, to: Vector2i) -> Array:
	var world_path = _astargrid.get_point_path(from, to)
	var grid_path = []
	for point in world_path:
		grid_path.append(tile_map.local_to_map(point))
	return grid_path

func _ready():
	tile_map = get_node("../Terrain/TileMap")
#	controlled_node = tile_map.get_node("Steve")
	# Sized from the map itself (see EncounterDefinition.resolve_playable_region)
	# rather than hard-coded. It used to be a literal Rect2i(0, 0, 36, 21),
	# which silently made everything outside that box unwalkable no matter what
	# the map actually was - already one column and one row short of the 37x22
	# this map paints, and unusable for encounters on differently-sized maps.
	if combat != null and combat.encounter != null:
		_astargrid.region = combat.encounter.resolve_playable_region(tile_map)
	else:
		_astargrid.region = tile_map.get_used_rect()
	_astargrid.cell_size = Grid.TILE_VECTOR
	_astargrid.offset = Grid.HALF_TILE
	_astargrid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astargrid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS
	_astargrid.update()
	
	#build blocking spaces arrays
	for tile in tile_map.get_used_cells(0):
		var tile_blocking = tile_map.get_cell_tile_data(0, tile)
		var blocks = tile_blocking.get_custom_data("Blocks")
		if blocks.size() > 0:
			_all_blocking_spaces.append(tile)
		for block in blocks:
			_blocking_spaces[block].append(tile)
			_blocking_lookup[block][tile] = true
	_mark_unpainted_cells_as_blocking()


## Treats every cell inside the grid with no tile painted on it as blocking.
##
## The grid is sized from the TileMap's used *rect*, which is a bounding box -
## so any map that isn't a perfect rectangle leaves holes inside it. Nothing
## builds those cells into _blocking_spaces (that loop only walks cells that
## exist), which left them perfectly walkable: routes were planned straight
## across empty space, and the moment the hover preview asked one of those
## tiles for its movement cost, get_cell_tile_data returned null and
## get_tile_cost crashed on it.
##
## Blocking them fixes that at the source, and does it once here rather than
## needing a null check at every call site: pathfinding, reachability, line of
## sight and area-of-effect all already route through _blocking_spaces, so all
## of them start treating the holes as the edge of the map. Note this includes
## line of sight - you can't see across a gap in the map, which is what you
## want for the outside of a non-rectangular map. If you ever want a hole
## inside the map that units can see across but not walk on, paint it with a
## real tile whose Blocks data lists every movement class instead.
func _mark_unpainted_cells_as_blocking():
	var region = _astargrid.region
	for x in range(region.position.x, region.position.x + region.size.x):
		for y in range(region.position.y, region.position.y + region.size.y):
			var tile = Vector2i(x, y)
			if tile_map.get_cell_tile_data(0, tile) != null:
				continue
			_all_blocking_spaces.append(tile)
			for movement_class in _blocking_spaces.size():
				_blocking_spaces[movement_class].append(tile)
				_blocking_lookup[movement_class][tile] = true


func combatant_added(combatant):
#	_astargrid.set_point_solid(combatant.position, true)
#	_astargrid.set_point_weight_scale(combatant.position, INF)
	_occupied_spaces[combatant.position] = true


func combatant_died(combatant):
	_astargrid.set_point_solid(combatant.position, false)
	_astargrid.set_point_weight_scale(combatant.position, 1)
	_occupied_spaces.erase(combatant.position)


func set_controlled_combatant(combatant: Dictionary):
	# A walk still in the air belongs to a turn that is now over. Left running,
	# _process drags whoever is controlled next along the abandoned path, since
	# there is only one _next_position for everybody.
	end_walk()
	if combatant.side == 0:
		player_turn = true
	else:
		player_turn = false
	controlled_node = combatant.sprite
	movement = maxi(combat.get_effective_stat(combatant, "movement"), 0)
	if combat.has_restriction(combatant, "prevents_movement"):
		# Crystallised - rooted for the turn, whatever their movement stat says.
		movement = 0
	_skill_selected = false
	_attack_target_position = null
	_ally_target_position = null
	_aoe_preview_positions = []
	_range_preview_positions = []
	# Whatever route was drawn under the cursor belonged to whoever was acting a
	# moment ago: it starts on their tile and was checked against their movement
	# class. Left lying around, the next click walks this combatant along it -
	# from the wrong place, through whatever the previous one was allowed to
	# cross. Aim again.
	_path = PackedVector2Array()
	_position_id = 0
	# Their own tile, so a stray frame of _process has nowhere to drag them.
	_next_position = tile_map.map_to_local(combatant.position)
	_previous_position = combatant.position
	update_points_weight()
	refresh_watched_tiles(combatant)
	queue_redraw()


## Recomputes where the enemy can see, for a hidden player about to move - or
## for one deciding whether to hide in the first place.
##
## Only for those two: it is expensive, and it is only worth drawing for
## somebody who has something to lose by stepping into it. Anybody else gets an
## empty list and nothing drawn.
func refresh_watched_tiles(combatant: Dictionary):
	_watched_tiles = []
	if combatant.is_empty() or combatant.side != 0:
		return
	if not combat.is_hidden(combatant) and not _previewing_hide:
		return
	var watchers := []
	for other in combat.combatants:
		if other.alive and other.side != combatant.side:
			watchers.append(other)
	if watchers.is_empty():
		return
	var region: Rect2i = _astargrid.region
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var tile := Vector2i(x, y)
			if is_tile_blocking(tile, combatant.movement_class):
				# Nowhere they could stand anyway.
				continue
			for watcher in watchers:
				if combat.has_line_of_sight(watcher.position, tile, watcher.movement_class):
					_watched_tiles.append(tile)
					break


## Tiles made unwalkable by Fear on the current combatant, so they can be
## released again once the fear passes or someone else's turn begins. Nothing
## else in update_points_weight would clear them, since they're neither
## occupied nor blocking terrain.
var _fear_blocked: Array = []


func update_points_weight():
	var current_comb = combat.get_current_combatant()
	# Release last turn's fear tiles before anything else re-decides the grid.
	for tile in _fear_blocked:
		_astargrid.set_point_weight_scale(tile, 1)
		_astargrid.set_point_solid(tile, false)
	_fear_blocked.clear()
	#Update occupied spaces for flying units
	for point in _occupied_spaces:
		if point == current_comb.position:
			# Never block the active combatant's own tile - that's their
			# pathfinding start point, and a solid start point means no
			# path can ever be found at all.
			_astargrid.set_point_weight_scale(point, 1)
			_astargrid.set_point_solid(point, false)
		elif current_comb.movement_class == 1:
			_astargrid.set_point_weight_scale(point, 1)
			_astargrid.set_point_solid(point, false)
		else:
			_astargrid.set_point_weight_scale(point, INF)
			_astargrid.set_point_solid(point, true)
	#Update point weights for blocking spaces - visit each tile once even if
	#it blocks more than one movement class, using the same is_tile_blocking()
	#check skills use, so movement and skills can never disagree.
	for space in _all_blocking_spaces:
		if is_tile_blocking(space, current_comb.movement_class):
			_astargrid.set_point_weight_scale(space, INF)
			_astargrid.set_point_solid(space, true)
		else:
			_astargrid.set_point_weight_scale(space, 1)
			_astargrid.set_point_solid(space, false)
	_apply_fear_restrictions(current_comb)


## Closes off every tile nearer to the current combatant's nearest enemy than
## the one they're standing on, for as long as Fear holds them.
##
## Done on the pathfinding grid rather than by refusing the move afterwards, so
## routes simply go around - and, the real point, the blue movement preview
## only ever offers destinations they're allowed to take. Refusing after the
## click would leave the player guessing which part of the route was the
## problem.
##
## This runs again after every step of a move, so the rule is strictly "never
## reduce the distance": backing away raises the bar behind you rather than
## letting them return to where they started.
func _apply_fear_restrictions(current_comb: Dictionary):
	if combat == null or not combat.has_restriction(current_comb, "prevents_approach"):
		return
	var nearest = combat.find_nearest_enemy_of(current_comb)
	if nearest.is_empty():
		return
	var limit = combat.get_position_distance(current_comb.position, nearest.position)
	var region = _astargrid.region
	for x in range(region.position.x, region.position.x + region.size.x):
		for y in range(region.position.y, region.position.y + region.size.y):
			var tile = Vector2i(x, y)
			if tile == current_comb.position:
				# Never close off the tile they're standing on - a solid start
				# point means no path can be found at all.
				continue
			if combat.get_position_distance(tile, nearest.position) >= limit:
				continue
			if _astargrid.is_point_solid(tile):
				continue # already unwalkable for another reason; leave it be
			_astargrid.set_point_weight_scale(tile, INF)
			_astargrid.set_point_solid(tile, true)
			_fear_blocked.append(tile)

func get_distance(point1: Vector2i, point2: Vector2i):
	return absi(point1.x - point2.x) + absi(point1.y - point2.y)


var _arrived = true

var _path : PackedVector2Array

var _next_position

var _position_id = 0

var move_speed = Grid.tiles(3.0)

var _previous_position : Vector2i

var _processing_step := false

## True while the game is legitimately parked waiting for a person to answer
## something - the reaction prompt, currently. The movement safety timeouts
## stop counting while it is set: they exist to catch a coroutine that has
## genuinely hung, and someone taking thirty seconds over a decision is not
## that. Without this a slow answer would trip the step-arrival timeout and
## orphan the move that is waiting on it.
## True while a reaction prompt is genuinely up and waiting for an answer. The
## movement timeouts below stop counting while it is, since a person taking
## twenty seconds to decide must not look like a hung coroutine.
##
## Asked of the prompt itself rather than kept as a flag Combat sets and clears
## around its await. A flag left true - by an await that never returns, a
## battle ending mid-question, anything - would switch off both safety nets for
## good, turning a recoverable stall into exactly the permanent lockup they
## exist to prevent. Derived state cannot be left behind.
func waiting_on_player() -> bool:
	return combat != null and combat.reaction_prompt != null and combat.reaction_prompt.is_asking()

## Timeout safety net for the _processing_step lock specifically: if
## _handle_step_arrival() (most likely something inside a reactive-skill
## chain it triggers) never actually completes, _processing_step would stay
## true forever - and since _process()'s very first line is "if
## _processing_step: return", that's not just this one move failing, it's
## ALL future movement for EVERY combatant permanently locked out for the
## rest of the game. This force-unlocks it after a generous wait regardless,
## leaving the original hung coroutine as an orphaned no-op rather than a
## permanent lockup.
const STEP_ARRIVAL_TIMEOUT = 15.0

## Set true by _run_step_arrival_and_flag() the moment _handle_step_arrival()
## genuinely returns. Deliberately a member variable rather than a local
## flipped by a captured lambda: GDScript lambdas capture locals BY VALUE, so
## assigning to a captured local inside one only ever writes the lambda's own
## private copy and never reaches the enclosing scope (Godot flags this as the
## CONFUSABLE_CAPTURE_REASSIGNMENT warning). That's exactly what this used to
## do - which meant the timeout below could never observe completion and so
## fired on *every single* movement step, holding _processing_step true for
## its full 15 seconds each time and, since _process()'s first line is
## "if _processing_step: return", freezing all movement for every combatant.
## Only one step arrival is ever in flight at a time (_processing_step itself
## guarantees that), so a single shared flag is safe here.
var _step_arrival_finished := false

func _process(delta):
	if _processing_step:
		# A reactive skill triggered by this exact step is still resolving
		# (its animation is playing) - do nothing further until it's done,
		# rather than letting Godot's normal per-frame call re-enter this
		# mid-step and process the same arrival twice.
		return
	if _arrived == false:
		_face_along_the_walk()
		controlled_node.position = advance_towards(controlled_node.position, _next_position, delta * move_speed)
		if controlled_node.position.distance_to(_next_position) < 1:
			_processing_step = true
			_run_step_arrival_with_timeout()


## One frame of walking along the line to the next waypoint, never overshooting
## it: once the waypoint is within a single frame's travel, land exactly on it.
##
## The clamp is what makes arrival certain rather than lucky. Moving a fixed
## step every frame and waiting to be within a pixel only terminates if the
## distance happens to divide nearly evenly by the step - and it doesn't for a
## diagonal. At 60fps a frame covers 9.6px; a straight tile is 192px, which is
## exactly 20 frames, but a diagonal is 271.5px, which leaves 2.7px over. That
## last frame jumps 2.7px past the waypoint, the next jumps 6.9px back, and it
## bounces between the two forever without ever coming within a pixel. Movement
## then hangs mid-step with the walk animation still playing, and because
## _process() bails out while a step is in flight, nobody else can move either.
## Turns the walker to face where they are going.
##
## Exploration has always done this; combat set a sprite's facing once when it
## was built and never again, so a combatant crossing the map leftwards walked
## there backwards. Only a sideways component turns anybody - walking straight
## up or down leaves them facing as they were, rather than snapping to a side.
func _face_along_the_walk():
	if controlled_node == null or not controlled_node.has_method("set_facing"):
		return
	var sideways = _next_position.x - controlled_node.position.x
	if absf(sideways) < 0.5:
		return
	controlled_node.set_facing(sideways < 0.0)


static func advance_towards(from: Vector2, to: Vector2, step: float) -> Vector2:
	var remaining := to - from
	if remaining.length() <= step:
		return to
	return from + remaining.normalized() * step


func _run_step_arrival_with_timeout():
	_step_arrival_finished = false
	_run_step_arrival_and_flag()
	var elapsed = 0.0
	while not _step_arrival_finished and elapsed < STEP_ARRIVAL_TIMEOUT:
		if not still_in_a_battle():
			_processing_step = false
			return
		await get_tree().process_frame
		if not still_in_a_battle():
			_processing_step = false
			return
		if not waiting_on_player():
			elapsed += get_process_delta_time()
	if not _step_arrival_finished:
		push_warning("_handle_step_arrival didn't finish within %s seconds - force-unlocking movement processing anyway. This is a real bug worth reporting, ideally with repro steps." % STEP_ARRIVAL_TIMEOUT)
	_processing_step = false


func _run_step_arrival_and_flag():
	await _handle_step_arrival()
	_step_arrival_finished = true


func _handle_step_arrival():
	if not _walking_combatant.is_empty() \
			and not is_same(_walking_combatant, combat.get_current_combatant()):
		# This step belongs to a turn that has already ended. Writing it now
		# would move whoever is acting instead - they share one _next_position -
		# and leave the original walker stranded between two tiles.
		end_walk()
		return
	var old_position = _previous_position
	_astargrid.set_point_solid(_previous_position, false)
	_occupied_spaces.erase(_previous_position)
	_astargrid.set_point_weight_scale(_previous_position, 1)
	controlled_node.position = _next_position
	var new_position: Vector2i = tile_map.local_to_map(_next_position)
	var mover = _walking_combatant if not _walking_combatant.is_empty() \
			else combat.get_current_combatant()
	mover.position = new_position
	_previous_position = new_position
	_occupied_spaces[new_position] = true
	update_points_weight()
	await combat.check_reactive_skills(mover, old_position, new_position)
	if not mover.alive:
		# A reactive skill killed them mid-move - something that couldn't
		# happen before reactive skills existed, since nothing else could
		# interrupt a combatant's own turn while they're actively moving.
		# Stop here and hand off the turn, rather than animating a dead
		# unit further along its path. Deferred - see the note below.
		_path = []
		finished_move.emit()
		_arrived = true
		combat.advance_turn.call_deferred()
		return
	# Somebody may have just walked into view, or walked into somebody's view.
	# Stopping here is the point of it: the reveal is worth seeing rather than
	# happening somewhere in the middle of a run, and whoever was walking gets
	# to decide what to do now that there is somebody on the map who was not
	# there a moment ago.
	if not combat.reveal_anyone_now_seen().is_empty():
		movement -= get_tile_cost(new_position)
		_path = []
		finished_move.emit()
		_arrived = true
		controlled_node.play_idle()
		check_turn_completion.call_deferred()
		return
	# Pay for the tile just entered (not the one left behind), and only
	# continue if the *next* waypoint - not this one again - is actually
	# affordable.
	movement -= get_tile_cost(new_position)
	if _position_id < _path.size() - 1 and movement > 0 and get_tile_cost_at_point(_path[_position_id + 1]) <= movement:
		_position_id += 1
		_next_position = _path[_position_id]
	else:
		finished_move.emit()
		_arrived = true
		controlled_node.play_idle()
		# Deferred rather than called directly (awaited or not): once
		# _arrived is true, this step's own processing is genuinely
		# finished, and _processing_step (which guards _process() against
		# re-entering mid-step) has nothing left to protect here.
		# advance_turn() can now await an entire subsequent enemy turn
		# (correctly, since a previous fix closed a race where it didn't) -
		# holding this step's lock for that whole duration would block all
		# movement, for everyone, until it's done. call_deferred() genuinely
		# decouples this from _handle_step_arrival's own coroutine, letting
		# it return and release the lock immediately, rather than relying on
		# unawaited-call semantics that may behave unexpectedly when called
		# from a function that's itself mid-coroutine.
		check_turn_completion.call_deferred()


func set_movement(value):
	movement = value
	movement_changed.emit(value)


## Auto-ends the turn once movement AND the one skill for this turn are both
## spent. Only movement can run out here (skill use is handled in
## Combat.use_skill) - this covers the case of moving after already having
## used the skill.
func check_turn_completion():
	if player_turn and movement <= 0 and not combat.has_action_left(combat.get_current_combatant()):
		await combat.advance_turn()
	elif player_turn:
		# Still something to do, but the walk is over - re-enable the skill
		# buttons that were locked out while the combatant was moving.
		game_ui_refresh()


## Whether the controlled combatant is standing still - not mid-walk. The HUD
## uses this to keep skills unselectable while someone is moving.
func is_idle() -> bool:
	return _arrived and not _processing_step


func game_ui_refresh():
	if combat != null and combat.game_ui != null and combat.game_ui.has_method("refresh_action_buttons"):
		combat.game_ui.refresh_action_buttons()


func get_movement():
	return movement


const tiles_to_check = [
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.LEFT,
	Vector2i.DOWN
]
func ai_process(target_position: Vector2i):
	#find nearest non-solid, unoccupied tile to target_position
	var current_position = tile_map.local_to_map(controlled_node.position)
	for tile in tiles_to_check:
		var candidate = target_position + tile
		if candidate in _occupied_spaces:
			continue
		if !_astargrid.get_point_weight_scale(candidate) > 999999:
			await ai_move(candidate)
			return
	# Every approach tile is occupied or blocked - nothing to move to, so
	# there's nothing to wait for either.


## Timeout safety net: movement getting stuck and never setting _arrived
## true isn't supposed to be possible, but if some edge case manages it
## anyway, this guarantees the AI turn using this can't freeze the whole
## game waiting forever - it just continues regardless, with a warning
## logged for diagnosing what actually happened. Polls _arrived directly
## (the same flag _process()/_handle_step_arrival() themselves set) rather
## than waiting on the finished_move signal, so this can't be affected by
## any signal-connection-timing subtlety - only the actual state matters.
const AI_MOVE_TIMEOUT = 10.0

func ai_move(target_position: Vector2i):
	var current_position = tile_map.local_to_map(controlled_node.position)
	find_path(target_position)
	move_on_path(current_position)
	var elapsed = 0.0
	while not _arrived and elapsed < AI_MOVE_TIMEOUT:
		if not still_in_a_battle():
			return
		await get_tree().process_frame
		if not still_in_a_battle():
			# The battle was left while this enemy was still walking. There is no
			# tree to wait on and nothing to walk to.
			return
		if not waiting_on_player():
			elapsed += get_process_delta_time()
	if not _arrived:
		push_warning("ai_move to %s (from %s) didn't finish within %s seconds - continuing anyway. This is a real bug worth reporting, ideally with repro steps." % [target_position, current_position, AI_MOVE_TIMEOUT])
		push_warning("  diagnostic: _path.size()=%s _path=%s _arrived=%s _position_id=%s _next_position=%s controlled_node.position=%s _processing_step=%s" % [_path.size(), _path, _arrived, _position_id, _next_position, controlled_node.position, _processing_step])


func find_path(tile_position: Vector2i):
	var current_position = tile_map.local_to_map(controlled_node.position)
	if not is_in_bounds(tile_position):
		# The cursor is off the map entirely - easy to do, since at full zoom-out
		# the viewport is larger than the map. There's nowhere to path to, and
		# asking AStarGrid2D about a point outside its region is an error in its
		# own right, so stop before doing either.
		_path = PackedVector2Array()
		queue_redraw()
		return
	if _astargrid.get_point_weight_scale(tile_position) > 999999:
		# The destination is occupied or blocked (e.g. clicking directly on
		# a combatant to move adjacent to them instead) - step back one tile
		# from it, along the actual direction from current_position, rather
		# than landing on it directly. Previously this used four independent
		# if-checks that overwrote each other, which only ever produced a
		# single cardinal direction (RIGHT/LEFT/UP/DOWN) even for a diagonal
		# move - silently redirecting to the wrong tile entirely whenever
		# both an x and a y check were true.
		var delta = tile_position - current_position
		var step = Vector2i(sign(delta.x), sign(delta.y))
		tile_position -= step
	_path = _astargrid.get_point_path(current_position, tile_position)
	queue_redraw()


func move_player():
	var current_position = tile_map.local_to_map(controlled_node.position)
	var _path_size = _path.size()
	if _path_size > 1 and tile_map.local_to_map(_path[0]) != current_position:
		# A route that does not start where this combatant is standing was drawn
		# for somebody else. Clearing it on every turn change should mean this
		# never happens; it is checked here as well because the cost of being
		# wrong is a combatant walking through walls, and the cost of the check
		# is one comparison per click.
		_path = PackedVector2Array()
		queue_redraw()
		return
	if _path_size > 1 and movement > 0:
		move_on_path(current_position)


## Whether whoever is acting may end their move on `tile`.
##
## Fear stops them closing on their nearest enemy - they can hold where they
## are or back away, but not advance. Only the destination is checked, not
## every step of the route, so a path that curves in and back out is allowed;
## that's a deliberate simplification rather than an oversight.
func can_move_to(tile: Vector2i) -> bool:
	var comb = combat.get_current_combatant()
	if not combat.has_restriction(comb, "prevents_approach"):
		return true
	var nearest = combat.find_nearest_enemy_of(comb)
	if nearest.is_empty():
		return true
	return combat.get_position_distance(tile, nearest.position) >= combat.get_position_distance(comb.position, nearest.position)


## Whoever is mid-walk, so a step that lands after their turn has passed is
## not written onto whoever happens to be acting by then.
var _walking_combatant: Dictionary = {}


## Ends whatever walk is in flight and puts the walker down on the tile the
## game says they are on.
##
## Movement slides a sprite between tile centres while position holds the last
## tile actually reached, so a walk abandoned mid-stride leaves a body drawn
## between two tiles. Targeting compares a click against position, never
## against the sprite - so that body is visible, alive, and impossible to
## click, which is exactly how this showed itself.
func end_walk():
	var walker = _walking_combatant
	_walking_combatant = {}
	_path = PackedVector2Array()
	_position_id = 0
	_arrived = true
	if walker.is_empty() or not walker.get("alive", false):
		return
	var sprite = walker.get("sprite", null)
	if sprite == null or not is_instance_valid(sprite):
		return
	sprite.position = tile_map.map_to_local(walker.position)
	if sprite.has_method("play_idle"):
		sprite.play_idle()


func move_on_path(current_position):
	if _path.size() >= 2 and not can_move_to(tile_map.local_to_map(_path[_path.size() - 1])):
		# Feared, and this move would close the distance. Enforced here rather
		# than at the player's click so the AI is held to it too.
		finished_move.emit()
		_arrived = true
		return
	if _path.size() < 2:
		# No usable path was found (e.g. the destination is unreachable) -
		# stay put rather than crash trying to index into an empty path.
		finished_move.emit()
		_arrived = true
		return
	if movement <= 0 or get_tile_cost_at_point(_path[1]) > movement:
		# There is no free first step. move_player() already refuses a click
		# with nothing left to spend, but the AI walks by calling here directly
		# and so skipped that check: a combatant held in place by Crystallised
		# still shifted one tile every turn, and anybody out of movement got
		# one more tile than they had paid for.
		finished_move.emit()
		_arrived = true
		return
	_previous_position = current_position
	_position_id = 1
	_next_position = _path[_position_id]
	_arrived = false
	_walking_combatant = combat.get_current_combatant()
	controlled_node.play_walk()
	# Grey the skills out for the duration of the walk - see is_idle().
	game_ui_refresh()
	queue_redraw()


var _selected_skill: String
## Which action slot the selected skill will be spent from.
var _selected_skill_is_secondary := false

func set_selected_skill(skill: String, as_secondary: bool = false):
	_selected_skill = skill
	_selected_skill_is_secondary = as_secondary


func begin_target_selection():
	_skill_selected = true
	var skill = SkillDatabase.skills[_selected_skill]
	var caster = combat.get_current_combatant()
	# Aiming something that would hide them: show what the enemy can see, so
	# the choice is made looking at the thing it is about.
	_previewing_hide = hides_its_caster(skill)
	if _previewing_hide:
		refresh_watched_tiles(caster)
	# Passing the caster lets the preview shrink to match anything blinding
	# them, so they're never shown a reach they don't have.
	_range_preview_positions = combat.get_range_tiles(skill, caster.position, caster.movement_class, caster)
	if skill.teleports == SkillDefinition.TeleportWho.CASTER:
		# A blink is aimed at somewhere to stand, so only offer the tiles it
		# could actually stand on.
		_range_preview_positions = landable_tiles(_range_preview_positions, caster)
	target_selection_started.emit()
	queue_redraw()


## Commits the aimed skill. The HUD stays hidden until the skill has actually
## finished resolving - awaited rather than fired and forgotten - because the
## point of hiding it was to keep the map clear while the skill plays out, and
## putting the panels back the instant the click lands would defeat that.
## Who a two-stage skill has picked up but not yet put down. A teleport that
## moves somebody else needs two answers - who, and where to - and the first
## click only gives the first.
var _teleport_subject = Vector2i(-99999, -99999)


func waiting_for_destination() -> bool:
	return _teleport_subject != Vector2i(-99999, -99999)


## Whether the aimed skill wants somewhere to put a body down rather than a
## body to aim at. True for a blink from the moment it is chosen, and for a
## skill that moves somebody else once it knows who is moving.
func picking_a_landing_tile() -> bool:
	if _selected_skill == "":
		return false
	var skill: SkillDefinition = SkillDatabase.skills[_selected_skill]
	if skill.teleports == SkillDefinition.TeleportWho.CASTER:
		return true
	return skill.teleports == SkillDefinition.TeleportWho.TARGET and waiting_for_destination()


## Whoever the aimed teleport would move, so we can ask whether they fit.
func travelling_combatant() -> Dictionary:
	var skill: SkillDefinition = SkillDatabase.skills[_selected_skill]
	if skill.teleports == SkillDefinition.TeleportWho.TARGET:
		return combat.get_combatant_at(_teleport_subject)
	return combat.get_current_combatant()


## Whether aiming the selected teleport at the traveller's own tile is worth
## doing. A blink that bursts where it lands still bursts if it lands where it
## started, so staying put is a real choice; a skill whose only point is the
## journey would just be a cast thrown away, so it is refused.
func standing_still_does_something() -> bool:
	var skill: SkillDefinition = SkillDatabase.skills[_selected_skill]
	return not skill.all_effects().is_empty()


## Whether a teleport aimed at `tile` would really arrive there - the same
## questions teleport_to() asks before it moves anybody.
##
## A click on an occupied tile used to be accepted and then quietly refused by
## the teleport itself, so the skill went off from where the caster was already
## standing: the damage landed and the move never happened.
func is_valid_landing_tile(tile: Vector2i) -> bool:
	var traveller = travelling_combatant()
	if traveller.is_empty():
		return false
	if traveller.position == tile:
		return standing_still_does_something()
	return combat.can_land_on(traveller, tile)


## Of `tiles`, the ones `traveller` could really be put down on.
func landable_tiles(tiles: Array, traveller: Dictionary) -> Array:
	var landable: Array = []
	for tile in tiles:
		if tile == traveller.position:
			if standing_still_does_something():
				landable.append(tile)
			continue
		if combat.can_land_on(traveller, tile):
			landable.append(tile)
	return landable


func confirm_skill_target(position: Vector2i):
	var skill: SkillDefinition = SkillDatabase.skills[_selected_skill]
	if skill.teleports == SkillDefinition.TeleportWho.TARGET and not waiting_for_destination():
		# First click chose who travels. Stay in aiming mode: the next one says
		# where to, and until then nothing has been spent.
		_teleport_subject = position
		# Now that we know who is travelling, narrow the marked tiles to the
		# ones they could be set down on.
		var subject_comb = combat.get_combatant_at(position)
		if not subject_comb.is_empty():
			_range_preview_positions = landable_tiles(_range_preview_positions, subject_comb)
		queue_redraw()
		return
	var subject = _teleport_subject
	_teleport_subject = Vector2i(-99999, -99999)
	# Leave aiming mode immediately so input state is correct, but hold the
	# HUD back until the skill is done.
	_skill_selected = false
	_range_preview_positions = []
	# The preview belongs to the aiming, so it ends with it.
	_previewing_hide = false
	refresh_watched_tiles(combat.get_current_combatant())
	queue_redraw()
	if skill.teleports == SkillDefinition.TeleportWho.TARGET:
		await combat.use_skill(_selected_skill, combat.get_current_combatant(), subject, true, _selected_skill_is_secondary, position)
	else:
		await combat.use_skill(_selected_skill, combat.get_current_combatant(), position, true, _selected_skill_is_secondary)
	target_selection_finished.emit()
	queue_redraw()


## Backs out of target selection (right-click or Escape) without spending
## the skill, returning to normal move mode.
func cancel_skill_selection():
	_skill_selected = false
	_previewing_hide = false
	refresh_watched_tiles(combat.get_current_combatant())
	_teleport_subject = Vector2i(-99999, -99999)
	_attack_target_position = null
	_ally_target_position = null
	_aoe_preview_positions = []
	_range_preview_positions = []
	target_selection_finished.emit()
	queue_redraw()


## Whether `target` is a legal thing to select for the currently selected skill:
## enemies for attacks/debuffs, or the caster's own side for heals/buffs
## (SkillDefinition.targets_ally decides which), and - if the skill respects
## blocking - a clear path from the caster to them. Only used for non-area
## skills - area skills can be aimed at any tile, see aoe_radius handling in
## _unhandled_input.
func is_valid_skill_target(target: Dictionary) -> bool:
	var skill = SkillDatabase.skills[_selected_skill]
	var caster = combat.get_current_combatant()
	if not skill.affects_both_sides:
		# A skill that affects both sides can be aimed at anyone; otherwise
		# targets_ally decides which side is legal.
		var right_side = target.side == caster.side if skill.targets_ally else target.side != caster.side
		if not right_side:
			return false
	if skill.respects_blocking and not combat.has_line_of_sight(caster.position, target.position, caster.movement_class):
		return false
	return true


const grid_tex = preload("res://imagese/grid_marker.png")

## The movement cost of `tile` for whoever's turn it is. Unpainted tiles - the
## holes in a non-rectangular map - report a nominal 1: movement can't reach
## one (they're blocking, see _mark_unpainted_cells_as_blocking), but the hover
## preview is free to ask about any tile the cursor crosses, and a null
## TileData here used to be a hard crash.
func get_tile_cost(tile):
	if combat.get_current_combatant().movement_class != 0:
		return 1
	var tile_data = tile_map.get_cell_tile_data(0, tile)
	if tile_data == null:
		return 1
	return int(tile_data.get_custom_data("Cost"))

## As get_tile_cost, but taking a local/world position rather than a grid tile.
func get_tile_cost_at_point(point):
	return get_tile_cost(tile_map.local_to_map(point))

## Draws the tile-highlight texture stretched to cover exactly one tile,
## centred on `centre`.
##
## Stretched rather than drawn at the texture's own size, so the marker art
## doesn't have to be redrawn every time the tile size changes - a 32px marker
## and a 192px one both fill their tile, the smaller one just softer. Before
## this it was drawn at native size from the tile's top-left corner, which at
## 192-unit tiles would have covered a thirty-sixth of one.
func _draw_tile_marker(centre: Vector2, colour: Color = Color.WHITE):
	draw_texture_rect(grid_tex, Rect2(centre - Grid.HALF_TILE, Grid.HALF_TILE * 2.0), false, colour)


func _draw():
	if _deployment_active:
		# Where the party may stand, and which of them is currently picked up.
		for tile in _deployment_tiles:
			_draw_tile_marker(tile_map.map_to_local(tile), Color(Color.GOLD, 0.45))
		if _deployment_selection != null:
			_draw_tile_marker(tile_map.map_to_local(_deployment_selection.position), Color(Color.WHITE, 0.85))
		return
	if _arrived == true and player_turn == true:
		# Where the enemy is looking, for somebody whose turn depends on not
		# being looked at. Drawn under everything else, since it is the ground
		# the rest of the turn is planned on rather than a choice being made.
		for tile in _watched_tiles:
			_draw_tile_marker(tile_map.map_to_local(tile), Color(Color.CRIMSON, 0.5))
		if _skill_selected:
			for pos in _range_preview_positions:
				var local = tile_map.map_to_local(pos)
				_draw_tile_marker(local, Color(Color.CRIMSON, 0.5))
		else:
			var path_length = movement
			for i in range(_path.size()):
				var point = _path[i]
				if i > 0:
					path_length -= get_tile_cost_at_point(point)
				var draw_color = Color.WHITE
				if path_length >= 0:
					draw_color = Color.ROYAL_BLUE
				_draw_tile_marker(point, draw_color)
		if _attack_target_position != null:
			_draw_tile_marker(_attack_target_position, Color.CRIMSON)
		if _ally_target_position != null:
			_draw_tile_marker(_ally_target_position, Color.LIME_GREEN)
		for pos in _aoe_preview_positions:
			var local = tile_map.map_to_local(pos)
			var color = Color.LIME_GREEN if _aoe_preview_is_ally else Color.CRIMSON
			_draw_tile_marker(local, Color(color, 0.6))
		if _blocked_target_position != null:
			_draw_tile_marker(_blocked_target_position)


## Whether this controller still belongs to a running battle.
##
## Every loop below parks itself on the next frame, and leaving a fight - to
## Arena Mode, to the title screen - changes the scene out from under whichever
## coroutine was mid-await. It resumes into a node that has been taken out of
## the tree, and get_tree() is null by then. Checked on both sides of an await,
## since the scene can change during it.
func still_in_a_battle() -> bool:
	return is_inside_tree() and get_tree() != null
