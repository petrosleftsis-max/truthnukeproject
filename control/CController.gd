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

var _skill_selected = false

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
		_occupied_spaces.append(tile)
	else:
		# A straight swap: both tiles stay occupied, so the occupancy list
		# doesn't change at all.
		_set_deployed_position(occupant, from)
	_set_deployed_position(comb, tile)
	update_points_weight()


func _set_deployed_position(comb: Dictionary, tile: Vector2i):
	comb.position = tile
	comb.sprite.position = tile_map.map_to_local(tile)


func _unhandled_input(event):
	if _deployment_active:
		_handle_deployment_input(event)
		return
	if player_turn == false or action_locked:
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
					if skill.aoe_radius > 0:
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
			_aoe_preview_positions = []
			if _skill_selected:
				var skill = SkillDatabase.skills[_selected_skill]
				if skill.aoe_radius > 0:
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
			elif mouse_position_i in _blocking_spaces[combat.get_current_combatant().movement_class]:
				_blocked_target_position = local_map
			else:
				_blocked_target_position = null


func get_combatant_at_position(target_position: Vector2i):
	for comb in combat.combatants:
		if comb.position == target_position and comb.alive:
			return comb
	return null

var _occupied_spaces = []

var _blocking_spaces = [
	[],#Ground
	[],#Flying
	[]#Mounted
]

## Every tile that blocks at least one movement class, each listed once -
## unlike _blocking_spaces, a tile that blocks multiple classes (e.g.
## Blocks = [0, 2]) only appears here a single time.
var _all_blocking_spaces = []

## Whether `tile` blocks movement (and, when a skill opts in via
## SkillDefinition.respects_blocking, line of sight) for `movement_class`
## (0=Ground, 1=Flying, 2=Mounted). Same data movement already uses.
func is_tile_blocking(tile: Vector2i, movement_class: int) -> bool:
	return tile in _blocking_spaces[movement_class]


## Whether `tile` is inside the playable grid at all, regardless of blocking.
func is_in_bounds(tile: Vector2i) -> bool:
	return _astargrid.region.has_point(tile)


## Instantly moves a combatant to a new tile outside the normal turn-based
## movement flow (used by PUSH/PULL skill effects), keeping the pathfinding
## grid's occupancy tracking in sync so other units' movement/LOS is correct
## immediately afterwards.
func reposition_combatant(old_position: Vector2i, new_position: Vector2i):
	_occupied_spaces.erase(old_position)
	_occupied_spaces.append(new_position)
	update_points_weight()


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
	_astargrid.cell_size = Vector2i(32, 32)
	_astargrid.offset = Vector2(16, 16)
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


func combatant_added(combatant):
#	_astargrid.set_point_solid(combatant.position, true)
#	_astargrid.set_point_weight_scale(combatant.position, INF)
	_occupied_spaces.append(combatant.position)


func combatant_died(combatant):
	_astargrid.set_point_solid(combatant.position, false)
	_astargrid.set_point_weight_scale(combatant.position, 1)
	_occupied_spaces.erase(combatant.position)


func set_controlled_combatant(combatant: Dictionary):
	if combatant.side == 0:
		player_turn = true
	else:
		player_turn = false
	controlled_node = combatant.sprite
	movement = maxi(combat.get_effective_stat(combatant, "movement"), 0)
	_skill_selected = false
	_attack_target_position = null
	_ally_target_position = null
	_aoe_preview_positions = []
	_range_preview_positions = []
	update_points_weight()

func update_points_weight():
	var current_comb = combat.get_current_combatant()
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

func get_distance(point1: Vector2i, point2: Vector2i):
	return absi(point1.x - point2.x) + absi(point1.y - point2.y)


var _arrived = true

var _path : PackedVector2Array

var _next_position

var _position_id = 0

var move_speed = 96

var _previous_position : Vector2i

var _processing_step := false

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
		controlled_node.position += controlled_node.position.direction_to(_next_position) * delta * move_speed
		if controlled_node.position.distance_to(_next_position) < 1:
			_processing_step = true
			_run_step_arrival_with_timeout()


func _run_step_arrival_with_timeout():
	_step_arrival_finished = false
	_run_step_arrival_and_flag()
	var elapsed = 0.0
	while not _step_arrival_finished and elapsed < STEP_ARRIVAL_TIMEOUT:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	if not _step_arrival_finished:
		push_warning("_handle_step_arrival didn't finish within %s seconds - force-unlocking movement processing anyway. This is a real bug worth reporting, ideally with repro steps." % STEP_ARRIVAL_TIMEOUT)
	_processing_step = false


func _run_step_arrival_and_flag():
	await _handle_step_arrival()
	_step_arrival_finished = true


func _handle_step_arrival():
	var old_position = _previous_position
	_astargrid.set_point_solid(_previous_position, false)
	_occupied_spaces.erase(_previous_position)
	_astargrid.set_point_weight_scale(_previous_position, 1)
	controlled_node.position = _next_position
	var new_position: Vector2i = tile_map.local_to_map(_next_position)
	var mover = combat.get_current_combatant()
	mover.position = new_position
	_previous_position = new_position
	_occupied_spaces.append(new_position)
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
		await get_tree().process_frame
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
	if _path_size > 1 and movement > 0:
		move_on_path(current_position)


func move_on_path(current_position):
	if _path.size() < 2:
		# No usable path was found (e.g. the destination is unreachable) -
		# stay put rather than crash trying to index into an empty path.
		finished_move.emit()
		_arrived = true
		return
	_previous_position = current_position
	_position_id = 1
	_next_position = _path[_position_id]
	_arrived = false
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
	_range_preview_positions = combat.get_range_tiles(skill, caster.position, caster.movement_class)
	target_selection_started.emit()
	queue_redraw()


## Commits the aimed skill. The HUD stays hidden until the skill has actually
## finished resolving - awaited rather than fired and forgotten - because the
## point of hiding it was to keep the map clear while the skill plays out, and
## putting the panels back the instant the click lands would defeat that.
func confirm_skill_target(position: Vector2i):
	# Leave aiming mode immediately so input state is correct, but hold the
	# HUD back until the skill is done.
	_skill_selected = false
	_range_preview_positions = []
	queue_redraw()
	await combat.use_skill(_selected_skill, combat.get_current_combatant(), position, true, _selected_skill_is_secondary)
	target_selection_finished.emit()
	queue_redraw()


## Backs out of target selection (right-click or Escape) without spending
## the skill, returning to normal move mode.
func cancel_skill_selection():
	_skill_selected = false
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

func _draw():
	if _deployment_active:
		# Where the party may stand, and which of them is currently picked up.
		for tile in _deployment_tiles:
			draw_texture(grid_tex, tile_map.map_to_local(tile) - Vector2(16, 16), Color(Color.GOLD, 0.45))
		if _deployment_selection != null:
			draw_texture(grid_tex, tile_map.map_to_local(_deployment_selection.position) - Vector2(16, 16), Color(Color.WHITE, 0.85))
		return
	if _arrived == true and player_turn == true:
		if _skill_selected:
			for pos in _range_preview_positions:
				var local = tile_map.map_to_local(pos)
				draw_texture(grid_tex, local - Vector2(16, 16), Color(Color.CRIMSON, 0.5))
		else:
			var path_length = movement
			for i in range(_path.size()):
				var point = _path[i]
				if i > 0:
					path_length -= get_tile_cost_at_point(point)
				var draw_color = Color.WHITE
				if path_length >= 0:
					draw_color = Color.ROYAL_BLUE
				draw_texture(grid_tex, point - Vector2(16, 16), draw_color)
		if _attack_target_position != null:
			draw_texture(grid_tex, _attack_target_position - Vector2(16, 16), Color.CRIMSON)
		if _ally_target_position != null:
			draw_texture(grid_tex, _ally_target_position - Vector2(16, 16), Color.LIME_GREEN)
		for pos in _aoe_preview_positions:
			var local = tile_map.map_to_local(pos)
			var color = Color.LIME_GREEN if _aoe_preview_is_ally else Color.CRIMSON
			draw_texture(grid_tex, local - Vector2(16, 16), Color(color, 0.6))
		if _blocked_target_position != null:
			draw_texture(grid_tex, _blocked_target_position - Vector2(16, 16))
