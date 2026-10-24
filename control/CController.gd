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
	# The first turn was handed out before the party was placed, so where it
	# begins is only known now. Remembered from before, a walk back would put
	# them on whichever tile they stood on before being moved.
	if combat != null and not combat.combatants.is_empty():
		_remember_turn_start(combat.get_current_combatant())
	queue_redraw()


func _handle_deployment_input(event):
	if not event is InputEventMouseButton:
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.is_released():
		return
	var tile = tile_map.local_to_map(_pointed_at())
	var comb = get_combatant_at_position(tile)
	if _deployment_selection == null:
		if comb != null and comb.side == 0 and not comb.get("ai_controlled", false):
			_deployment_selection = comb
			queue_redraw()
		return
	if tile in _deployment_tiles:
		_swap_deployed(_deployment_selection, tile)
		_deployment_selection = null
	elif comb != null and comb.side == 0 and not comb.get("ai_controlled", false):
		# Clicked a different hero instead - switch who's being moved.
		_deployment_selection = comb
	queue_redraw()


## Moves `comb` onto `tile`, trading places with whoever is already standing
## there. Enemies are never displaced - their positions are the encounter's
## design, not the player's to rearrange.
func _swap_deployed(comb: Dictionary, tile: Vector2i):
	if comb.side != 0 or comb.get("ai_controlled", false):
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
	# A straight swap with whoever is there, if anybody: both tiles stay taken.
	if occupant != null:
		_set_deployed_position(occupant, from)
	_set_deployed_position(comb, tile)
	update_points_weight()


func _set_deployed_position(comb: Dictionary, tile: Vector2i):
	comb.position = tile
	comb.sprite.position = tile_map.map_to_local(tile)
	refresh_occupancy()


## --- A pad's cursor on the board (see Pad) ---
##
## A pad does not point freely here: its cursor sits on a tile, and goes a tile
## at a time - or, where only some tiles would do anything, from one of those
## to the next:
##   placing the party      the tiles they can be placed on
##   aiming at somebody     whoever it can hit - or, with nobody, every tile
##                          in its reach, to see what it covers
##   aiming at an area, or
##   somewhere to land      every tile it could go
##   otherwise              every tile on the map, walkable or not, since a
##                          click further off than a walk reaches still works
## Pressed a way, it goes to the nearest of them that way, jumping whatever is
## in between - tiles cover keeps a skill from, a wall - so one out on its own
## is still reached; LB and RB go through all of them in turn besides.
##
## The tile is the cursor; the pointer (which is the mouse - see Pad) is put on
## it every frame. Whenever the cursor goes somewhere, the view goes along to
## keep it clear of the HUD, where a click would land on a button instead; when
## the view is moved away from it, it comes along onto a tile still in view.

const NO_TILE := Vector2i(-99999, -99999)

var _pad_cursor := NO_TILE
var _pad_set: Array = []
var _pad_set_key := ""
## Goes up whenever the tiles change - what was under the cursor may mean
## something else now, and Pad tells the board so.
var pad_version := 0


## Whether a pad's pointer is pointing at this board: for as long as there is
## one to point at, and the battle is not over - the result panel is a menu,
## its buttons the D-pad's.
func pad_board_active() -> bool:
	if not still_in_a_battle() or not is_visible_in_tree():
		return false
	var result = get_node_or_null("../ResultUI/Panel")
	return result == null or not result.visible


## The tiles the cursor goes between right now - see above - or [] for every
## tile on the map.
func pad_tiles() -> Array:
	var caster = aiming_caster() if _skill_selected else {}
	var key := "%s|%s|%s|%s|%s|%s|%s|%s" % [_deployment_active, _skill_selected, _selected_skill, _teleport_subject,
		_range_preview_positions.size(), caster.get("position", NO_TILE), _deployment_tiles.size(), _step_tiles.size()]
	if key != _pad_set_key:
		_pad_set_key = key
		pad_version += 1
		_pad_set = _work_out_pad_tiles()
		_pad_set_changed()
	return _pad_set


func _work_out_pad_tiles() -> Array:
	if _stepping:
		# Where a step could go, and staying put.
		return _step_tiles + [_step_choice]
	if _deployment_active:
		var tiles: Array = _deployment_tiles.duplicate()
		for comb in combat.combatants if combat != null else []:
			if comb.side == 0 and comb.alive and not tiles.has(comb.position):
				tiles.append(comb.position)
		return tiles
	if not _skill_selected:
		return []
	var skill: SkillDefinition = SkillDatabase.skills[_selected_skill]
	if skill.placed_in_reach and not waiting_for_destination():
		# Whose image: any of theirs, in reach or not.
		var allies := []
		for comb in combat.combatants:
			if comb.get("alive", false) and refusal_at(comb.position, comb) == "":
				allies.append(comb.position)
		return allies
	var reach: Array = _range_preview_positions.duplicate()
	var will_do: Array = reach.filter(func(tile): return refusal_at(tile, aim_subject_at(tile)) == "")
	if combat.aoe_radius_of(aiming_caster(), skill) == 0 and not picking_a_landing_tile():
		# Aimed at somebody: whoever it can hit. Nobody, and the reach is
		# still worth going over, to see who is just out of it.
		return will_do if not will_do.is_empty() else reach
	return will_do if not will_do.is_empty() else reach


## A different set of tiles: the cursor goes onto the one that makes most
## sense, unless it is on one of them already.
func _pad_set_changed():
	if _pad_set.is_empty() or _pad_set.has(_pad_cursor):
		return
	var near := _pad_cursor
	if _skill_selected:
		near = aiming_caster().get("position", near)
	elif _deployment_active:
		for comb in combat.combatants:
			if comb.side == 0 and comb.alive:
				near = comb.position
				break
	_pad_move_cursor(nearest_tile(_pad_set, near))


## Where the cursor is on the screen, for Pad to put the pointer on - or null
## with no cursor yet. Puts it on the board first if it has never been.
func pad_cursor_screen():
	_fresh_view()
	var tiles := pad_tiles()
	if _pad_cursor == NO_TILE:
		var current = combat.get_current_combatant() if combat != null and not combat.combatants.is_empty() else {}
		var start: Vector2i = current.get("position", tile_map.local_to_map(_pointed_at()))
		_pad_move_cursor(start if tiles.is_empty() else nearest_tile(tiles, start))
		if _pad_cursor == NO_TILE:
			return null
	var screen := _screen_of_tile(_pad_cursor)
	var room := _pad_room()
	var camera = combat.camera if combat != null else null
	if not _in_room(screen, room) and camera != null and not camera.is_following():
		# The view was moved off it: it comes along, onto whatever is nearest
		# the edge it went past.
		var inside := screen.clamp(room.position, room.end)
		var under := tile_map.local_to_map(get_canvas_transform().affine_inverse() * inside)
		var candidates: Array = tiles.filter(func(tile): return _in_room(_screen_of_tile(tile), room))
		if tiles.is_empty():
			if is_in_bounds(under):
				_pad_cursor = under
		elif not candidates.is_empty():
			_pad_cursor = nearest_tile(candidates, under)
		screen = _screen_of_tile(_pad_cursor)
	return screen


## The D-pad, or the left stick: the cursor `way` - to the next tile that way,
## or to the nearest of the tiles that would do anything that way.
func pad_tile_step(way: Vector2i):
	if _pad_cursor == NO_TILE:
		pad_cursor_screen()
		return
	var tiles := pad_tiles()
	var to := _pad_cursor + way if tiles.is_empty() else next_tile(tiles, _pad_cursor, way)
	if is_in_bounds(to):
		_pad_move_cursor(to)


## LB and RB, aiming or placing the party: the cursor through every tile that
## would do anything, one after another, so none of them is out of reach.
## False with no such tiles to go through.
func pad_cycle(step: int) -> bool:
	var tiles := pad_tiles()
	if tiles.is_empty():
		return false
	var order := tiles.duplicate()
	order.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
	var at := order.find(_pad_cursor)
	var next := posmod(at + step, order.size()) if at >= 0 else 0
	_pad_move_cursor(order[next])
	return true


## The cursor onto `tile`, the view going along so it is clear of the HUD.
func _pad_move_cursor(tile: Vector2i):
	if tile == NO_TILE:
		return
	_pad_cursor = tile
	_note_hover(tile)
	_fresh_view()
	var room := _pad_room()
	var screen := _screen_of_tile(tile)
	var over := screen - screen.clamp(room.position, room.end)
	var camera = combat.camera if combat != null else null
	if over != Vector2.ZERO and camera != null and not camera.is_following():
		camera.position += over / get_canvas_transform().get_scale().x
		camera.clamp_to_map()
		# Now, not at the end of the frame: where the cursor is on the screen is
		# asked straight after, and must be asked of the view as it now is.
		camera.force_update_scroll()


## The view as the camera has it now. The camera only hands its position on to
## the screen at the end of the frame, and anything can have moved it since -
## the turn starting, the right stick - so where a tile is on the screen is
## asked of the view brought up to date first, or it is asked of the old one.
func _fresh_view():
	var camera = combat.camera if combat != null else null
	if camera != null and camera.is_inside_tree():
		camera.force_update_scroll()


## The tile a pad's cursor is on, or NO_TILE.
func pad_cursor() -> Vector2i:
	return _pad_cursor


## Whether `screen` is in `room` - its edges counting, and a pixel either side
## of them, since the view is moved to put the cursor exactly on one.
func _in_room(screen: Vector2, room: Rect2) -> bool:
	return room.grow(2.0).has_point(screen)


## Where the cursor's tile is kept on the screen: the part the HUD leaves the
## map, in from its edges by half a tile as the view has them - so the whole
## tile shows, not just its middle - or as near that as there is room for.
func _pad_room() -> Rect2:
	var hud = combat.game_ui if combat != null else null
	var room: Rect2 = hud.map_view_rect() if hud != null and hud.has_method("map_view_rect") else get_viewport_rect().grow(-24.0)
	var half_tile := Grid.TILE_SIZE * 0.5 * get_canvas_transform().get_scale().x
	return room.grow(-minf(half_tile, minf(room.size.x, room.size.y) * 0.3))


func _screen_of_tile(tile: Vector2i) -> Vector2:
	return get_canvas_transform() * tile_map.map_to_local(tile)


## The tile of `tiles` to go to from `from`, pressing `way`: the nearest one
## that way, those straight on counting as nearer than those off to one side -
## or `from`, with nothing that way at all. Anything level with `from` or
## behind it is for another way to reach; anything ahead is fair game however
## far it is off to the side, so a tile on its own beyond a gap is reached as
## readily as the next one along. (LB and RB go through every one regardless.)
static func next_tile(tiles: Array, from: Vector2i, way: Vector2i) -> Vector2i:
	var heading := Vector2(way).normalized()
	var best := from
	var best_score := INF
	for tile in tiles:
		if tile == from:
			continue
		var gap := Vector2(tile - from)
		var ahead := gap.dot(heading)
		if ahead <= 0.01:
			continue
		var score := ahead + absf(gap.cross(heading)) * 2.0
		if score < best_score:
			best_score = score
			best = tile
	return best


## Whichever of `tiles` is nearest `to` - the first in reading order of any
## that are as near as each other. NO_TILE when there are none.
static func nearest_tile(tiles: Array, to: Vector2i) -> Vector2i:
	var best := NO_TILE
	var best_gap := INF
	for tile in tiles:
		var gap := Vector2(tile - to).length()
		if gap < best_gap - 0.001 or (absf(gap - best_gap) <= 0.001 and (tile.y < best.y or (tile.y == best.y and tile.x < best.x))):
			best_gap = gap
			best = tile
	return best


## Where the mouse is on the map - a pad's pointer, while a pad is in use.
func _pointed_at() -> Vector2:
	return get_canvas_transform().affine_inverse() * Pad.screen_point()


## The cursor onto `comb` - the one whose turn it now is.
func _point_pad_at(comb: Dictionary):
	if not Pad.using_pad or not comb.has("position") or not still_in_a_battle():
		return
	_pad_move_cursor(comb.position)


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
	# Held, not toggled: the danger view is a look taken while deciding, and it
	# works while placing the party too, which is when it is most use.
	if event.is_action(&"danger_view") and not event.is_echo():
		set_danger_view(event.is_action_pressed(&"danger_view"))
	# Another floor on the screen (Combat "Heights"), whoever's turn it is.
	if combat != null and combat._floored and not event.is_echo():
		if event.is_action_pressed(&"floor_up") or event.is_action_pressed(&"floor_down"):
			cycle_floor(1 if event.is_action_pressed(&"floor_up") else -1)
			get_viewport().set_input_as_handled()
			return
	if _deployment_active:
		_handle_deployment_input(event)
		return
	if _stepping:
		_handle_step_input(event)
		return
	if player_turn == false or action_locked:
		return
	if a_menu_is_over_the_map():
		return

	if _skill_selected and event.is_action_pressed("ui_cancel"):
		cancel_skill_selection()
		# Spent here: one press puts the aim away and does nothing else. Left
		# unclaimed, anything later in line that also answers Escape - a pause
		# menu that stepped aside only because something was being aimed -
		# acted on it too, now that nothing was.
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.is_released():
			if _skill_selected:
				cancel_skill_selection()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_released():
				if _skill_selected and _look_only:
					# Only looking: a click chooses nothing and spends nothing.
					pass
				elif _skill_selected == true:
					aim_click(tile_map.local_to_map(_pointed_at()))
				elif _arrived == true:
					move_player()
	
	if event is InputEventMouseMotion:
		if _arrived == true:
			var mouse_position = _pointed_at()
			var mouse_position_i = tile_map.local_to_map(mouse_position)
			_note_hover(mouse_position_i)
			find_path(mouse_position_i)
			var comb = get_combatant_at_position(mouse_position_i)
			if _skill_selected:
				# Aimed at the fallen, the tile means the body lying on it.
				var subject := aim_subject_at(mouse_position_i)
				comb = subject if not subject.is_empty() else null
			var local_map = tile_map.map_to_local(mouse_position_i)
			# Who is under the cursor - except while aiming, when the prompt of
			# what the hit would do to them has the space.
			_card_for(comb if not _skill_selected else null)
			_attack_target_position = null
			_ally_target_position = null
			_blocked_target_position = null
			_aoe_preview_positions = []
			if _skill_selected:
				var skill = SkillDatabase.skills[_selected_skill]
				var caster = aiming_caster()
				# A melee blow's area grows and shrinks with its user (Combat.aoe_radius_of).
				var radius: int = combat.aoe_radius_of(caster, skill)
				if refusal_at(mouse_position_i, comb if comb != null else {}) != "":
					# Out of reach, nowhere to arrive, nobody it is for: show no
					# swing and no area either, since this click will do nothing
					# at all. An empty tile stays unmarked, as it always was.
					if comb != null or picking_a_landing_tile() or radius > 0:
						_blocked_target_position = local_map
				elif radius > 0:
					_aoe_preview_positions = combat.get_impact_tiles(skill, Combat.nearest_tile_of(caster, mouse_position_i), mouse_position_i, caster.movement_class, caster.get("size", Sizes.Size.HUMAN), caster)
					_aoe_preview_is_ally = skill.targets_ally
				elif (skill.placed_in_reach or Combat.summons_with(skill) != "") and picking_a_landing_tile():
					# Where the image, or what is called up, would stand.
					_ally_target_position = local_map
				elif comb != null:
					# In reach and the right person - refusal_at has said so.
					if skill.targets_ally:
						_ally_target_position = local_map
					else:
						_attack_target_position = local_map
				_preview_hits(mouse_position_i)
			elif comb != null and comb.alive and comb.side == 1:
				_attack_target_position = local_map
			elif comb != null:
				_blocked_target_position = local_map
			elif is_tile_blocking(mouse_position_i, combat.get_current_combatant().movement_class):
				_blocked_target_position = local_map
			else:
				_blocked_target_position = null


## Asks the HUD to say what the skill being aimed would do to whoever the tile
## under the cursor would catch. A skill that picks somebody up and puts them
## down elsewhere is left out - the first click is choosing who, not hitting -
## and so is anywhere a click would be refused: it promises nothing there.
func _preview_hits(tile: Vector2i):
	var hud = combat.game_ui if combat != null else null
	if hud == null or not hud.has_method("show_hit_preview"):
		return
	var skill: SkillDefinition = SkillDatabase.skills[_selected_skill]
	if aimed_twice(skill):
		hud.hide_hit_preview()
		return
	var comb = get_combatant_at_position(tile)
	var refusal := refusal_at(tile, comb if comb != null else {})
	if refusal != "":
		# Aiming a Steal, anybody on the other side can be looked over for what
		# they carry - out of reach or empty-handed too, saying why it cannot
		# go. Not somebody hidden: that would say where they are.
		if Combat.steals(skill) and comb != null and comb.side != aiming_caster().side \
				and not combat.is_hidden(comb) and hud.has_method("show_carried"):
			hud.show_carried(_selected_skill, comb, refusal)
		else:
			hud.hide_hit_preview()
		return
	hud.show_hit_preview(_selected_skill, tile)


func get_combatant_at_position(target_position: Vector2i):
	# Whoever covers the tile - somebody bigger than a tile covers several.
	for comb in combat.combatants:
		if comb.alive and combat.covers(comb, target_position):
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

## The value a tile's Blocks data carries to say "stop movement, but let sight
## through" - a railing, a window, a chest-high wall.
##
## It sits alongside the movement classes rather than beside them because it is
## painted in the same array: [0, 2] is a wall to walkers and riders, and
## [0, 2, 3] is the same wall with a gap at eye height. A tile that does not
## block a class in the first place is already transparent to it, so this only
## ever softens what the other numbers said.
const SEE_THROUGH := 3

## Tiles that stop movement but not sight - the 3s above, as a set.
var _see_through := {}

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

## Whether `tile` blocks movement for `movement_class` (0=Ground, 1=Flying,
## 2=Mounted).
##
## Movement only. Sight is a separate question since a tile can stop one and
## not the other - see blocks_line_of_sight, which is what a shot asks.
func is_tile_blocking(tile: Vector2i, movement_class: int) -> bool:
	return _blocking_lookup[movement_class].has(tile)


## Whether the ground itself stops a shot at `tile` - blocking for this
## movement class, and not painted see-through.
##
## Separate from the body question below because the two are asked in
## different places. A shot passing THROUGH a tile is stopped by either. A shot
## aimed AT a tile is stopped only by the terrain: somebody standing there is
## the reason to aim at it, not a reason to refuse.
func terrain_blocks_sight(tile: Vector2i, movement_class: int) -> bool:
	return _blocking_lookup[movement_class].has(tile) and not _see_through.has(tile)


## Whether `tile` stops a shot from passing through it: the ground, or somebody
## standing on it.
##
## The one place the whole rule lives, so a line of sight, the field of view
## drawn for a hiding player and the AI all judge it the same way.
func blocks_line_of_sight(tile: Vector2i, movement_class: int, viewer_size: int = Sizes.Size.HUMAN, looking_at: Dictionary = {}) -> bool:
	return terrain_blocks_sight(tile, movement_class) or blocks_sight(tile, viewer_size, looking_at)


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
##
## By size, too (Sizes): a body is cover only to somebody no more than one size
## bigger than it. A Human sees over a Tiny one, a Large one over the Small - and
## nobody sees past something their own size or bigger.
##
## Except `looking_at`, the one being looked at: somebody bigger than a tile is
## no cover to the rest of themselves.
func blocks_sight(tile: Vector2i, viewer_size: int = Sizes.Size.HUMAN, looking_at: Dictionary = {}) -> bool:
	if not _occupied_spaces.has(tile) or combat == null:
		return false
	for standing in combat.combatants_at(tile):
		if not looking_at.is_empty() and is_same(standing, looking_at):
			continue
		# An illusion stops nothing - save in the mind of the side it fools, as
		# it decides what to do (Combat.believes_illusion, "Images").
		if standing.get("illusion", false) and not combat.believes_illusion(standing):
			continue
		if not combat.is_hidden(standing) and standing.get("size", Sizes.Size.HUMAN) > viewer_size - 2:
			return true
	return false


## Whether `tile` is inside the playable grid at all, regardless of blocking.
func is_in_bounds(tile: Vector2i) -> bool:
	return _astargrid.region.has_point(tile)


## Whether there is any ground at `tile` at all: inside the map, and not one of
## the holes in it.
func is_on_map(tile: Vector2i) -> bool:
	return is_in_bounds(tile) and tile_map.get_cell_tile_data(0, tile) != null


## Instantly moves a combatant to a new tile outside the normal turn-based
## movement flow (used by PUSH/PULL skill effects), keeping the pathfinding
## grid's occupancy tracking in sync so other units' movement/LOS is correct
## immediately afterwards. Call it after `comb.position` has changed: the
## occupancy is worked out afresh from where everybody now is.
func reposition_combatant(_old_position: Vector2i, _new_position: Vector2i):
	refresh_occupancy()
	update_points_weight()


## Every tile anybody stands on, worked out afresh from where they all are:
## several for somebody bigger than a tile (Combat.tiles_of), one shared by
## several small ones. A tile nobody is on any more is let go on the
## pathfinding grid, and the small and the big are drawn where they now belong
## (Combat.place_sprites). Whoever moves somebody calls this, then
## update_points_weight if it is somebody's turn.
func refresh_occupancy():
	if combat == null:
		return
	var now := {}
	var heights: bool = combat.heights_in_play()
	_up_tiles.clear()
	_raised.clear()
	for comb in combat.combatants:
		if comb.alive:
			for tile in combat.tiles_of(comb):
				now[tile] = true
			# Up on high ground, or not (Combat "Heights").
			if heights or combat.climbs_anywhere(comb):
				var up: bool = Combat.footprint(comb) == Vector2i.ONE and not comb.has("riding") and not comb.has("object") \
					and combat.is_high(comb.position)
				comb["up"] = up
				if up:
					_up_tiles[comb.position] = true
			# And how raised, up there or by their size.
			var raised: int = combat.elevation(comb)
			if raised > 0:
				for tile in combat.tiles_of(comb):
					_raised[tile] = maxi(_raised.get(tile, 0), raised)
	for tile in _occupied_spaces:
		if not now.has(tile):
			release_tile(tile)
	_occupied_spaces = now
	combat.place_sprites()
	# Where everybody stands is drawn on the board (see _draw).
	queue_redraw()


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
func get_reachable_tiles(start: Vector2i, movement_class: int, movement_budget: int, mover: Dictionary = {}) -> Dictionary:
	# Every step twice as dear while dragging somebody (Combat "Dragging"): the
	# same as half the movement, rounded down, since costs are whole.
	if not mover.is_empty() and combat != null:
		movement_budget /= combat.drag_cost(mover)
	# High ground and floors, and squeezing: up only from a climb tile, down from
	# anywhere, wherever they fit - squeezed, if they can.
	if _height_pathing(movement_class, mover):
		return _height_search(start, movement_class, movement_budget, {}, Vector2i(-99999, -99999), mover)
	# Somebody bigger or smaller than a tile: where they fit, not where one
	# tile's worth of floor is free.
	if not mover.is_empty() and (Combat.footprint(mover) != Vector2i.ONE or Sizes.shares(mover.get("size", Sizes.Size.HUMAN))):
		return _reachable_by_size(mover, start, movement_budget)
	const NEIGHBOR_OFFSETS = [
		Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN,
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
	]
	# Twice as dear near anybody hemming them in (Combat "Hemmed In and Exposed").
	var hemmed: Dictionary = combat.hemmed_tiles(mover) if combat != null else {}
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
			var new_cost = current_cost + get_tile_cost_for_class(neighbor, movement_class) * (2 if hemmed.has(neighbor) else 1)
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
	var walker = combat.get_current_combatant() if combat != null else {}
	if _height_pathing(walker.get("movement_class", 0), walker):
		return _height_path(from, to, walker.get("movement_class", 0), walker)
	var world_path = _astargrid.get_point_path(from, to)
	var grid_path = []
	for point in world_path:
		grid_path.append(tile_map.local_to_map(point))
	return grid_path

## --- Heights ---
##
## Walking where there is high ground or more than one floor (Combat "Heights"):
## onto a high tile only from a climb tile beside it or along other high tiles,
## off one onto the ground anywhere; up a floor from a climb tile under it, down
## a floor off any edge with open air past it. The pathfinding grid cannot say
## "only from there", so these walks are searched here (_height_search,
## _height_path) instead, step by step (_height_steps) - for anybody a tile big,
## and for a flier only where there are floors to go between.

const _EIGHT_WAYS := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN,
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

## Where somebody stands up on high ground, kept by refresh_occupancy.
var _up_tiles := {}
## The tiles that cost whoever _height_search is walking for twice, hemmed in
## (Combat "Hemmed In and Exposed") - set as it starts, read by _add_step.
var _hemmed := {}
## How raised whoever stands on each tile is, where it is more than nothing:
## up on high ground counts one, and every size above Human one more (Combat
## "Heights" - somebody bigger than the barrels sees over them, and gets no cover
## from them). Kept by refresh_occupancy, on every map.
var _raised := {}


## Whether somebody stands up on high ground at `tile`.
func up_at(tile: Vector2i) -> bool:
	return _up_tiles.has(tile)


## How raised whoever stands on `tile` is: 0 for nobody, or nobody raised.
func raised_at(tile: Vector2i) -> int:
	return _raised.get(tile, 0)


## Every tile the TileSet marks Climb (its "Climb" custom data), if it has such a layer.
func painted_climb_tiles() -> Array:
	var found := []
	if tile_map == null or tile_map.tile_set == null or tile_map.tile_set.get_custom_data_layer_by_name("Climb") < 0:
		return found
	for tile in tile_map.get_used_cells(0):
		var data = tile_map.get_cell_tile_data(0, tile)
		if data != null and data.get_custom_data("Climb"):
			found.append(tile)
	return found


## --- Floors on the screen ---
##
## One floor is on the screen at a time - the one under the middle of the view
## (shown_floor). The floor buttons (FloorBar), Page Up and Page Down and a pad's
## L3 go to another (show_floor, cycle_floor), at the same place over the ground;
## a turn begins on the floor of whoever's turn it is. Anybody on another floor
## is drawn faintly where they are under or over this one - a grey square with an
## arrow up or down (_draw_ghosts), red in the danger view for an enemy who could
## hit this floor from theirs - and a climb tile has a ladder drawn on it.

const GHOST_FILL := Color(0.7, 0.7, 0.75, 0.18)
const GHOST_EDGE := Color(0.85, 0.85, 0.9, 0.55)
const GHOST_DANGER_FILL := Color(0.9, 0.2, 0.2, 0.3)
const GHOST_DANGER_EDGE := Color(1.0, 0.35, 0.35, 0.85)
const LADDER_COLOUR := Color(0.85, 0.7, 0.45, 0.85)

## The floor on the screen when it was last drawn, to draw again on a change.
var _drawn_floor := -1


## The floor under the middle of the view, by index - the nearest, between them.
## -1 on a map of one floor.
func shown_floor() -> int:
	if combat == null or not combat._floored:
		return -1
	# Where the view is going rather than where it has got to: a floor shown is
	# the floor shown at once, not a frame later.
	var camera = combat.camera
	var centre: Vector2 = camera.position if camera != null and is_instance_valid(camera) else Vector2.ZERO
	var tile := tile_map.local_to_map(centre)
	var here: int = combat.floor_of(tile)
	if here >= 0:
		return here
	var best := 0
	var nearest := INF
	for i in combat.floors.size():
		var region: Rect2i = combat.floors[i].region
		var gap := Vector2(region.get_center()).distance_to(Vector2(tile))
		if gap < nearest:
			nearest = gap
			best = i
	return best


## Puts floor `index` on the screen - over the same place on the ground as now,
## or over `at` (a tile, of any floor) when given.
func show_floor(index: int, at = null):
	if combat == null or not combat._floored or index < 0 or index >= combat.floors.size():
		return
	var camera = combat.camera
	if camera == null or not is_instance_valid(camera):
		return
	var from: Vector2i = at if at != null else tile_map.local_to_map(camera.position)
	var real: Vector2i = combat.real_of(from)
	var target: Vector2i = combat.tile_on(index, real)
	if target.x == -99999:
		target = combat.floors[index].region.get_center()
	camera.release()
	camera.position = tile_map.map_to_local(target)
	camera.clamp_to_map()
	queue_redraw()


## The next floor up (`by` 1) or down (-1) on the screen, round to the other end.
func cycle_floor(by: int):
	if combat == null or not combat._floored:
		return
	var order: Array = range(combat.floors.size())
	order.sort_custom(func(a, b): return combat.floors[a].level < combat.floors[b].level)
	var at: int = order.find(shown_floor())
	show_floor(order[posmod(at + by, order.size())])


## Everybody standing on another floor than the one on the screen, drawn faintly
## where they are under or over it; nobody hidden from the player.
func _draw_ghosts():
	var shown := shown_floor()
	_drawn_floor = shown
	for comb in combat.combatants:
		if not comb.get("alive", false) or comb.has("object") or (comb.get("side", 0) != 0 and combat.is_hidden(comb)):
			continue
		var on: int = combat.floor_of(comb.position)
		if on == shown or on < 0:
			continue
		var tile: Vector2i = combat.tile_on(shown, combat.real_of(comb.position))
		if tile.x == -99999:
			continue
		# Red, in the danger view, for an enemy who could hit somebody on this
		# floor from theirs (Combat.threat_map's "across").
		var threatens: bool = _showing_danger and _danger.get("across", {}).get(comb.get("id", -1), {}).has(shown)
		var edge := GHOST_DANGER_EDGE if threatens else GHOST_EDGE
		_draw_area([tile], GHOST_DANGER_FILL if threatens else GHOST_FILL, edge)
		# An arrow, up for somebody above this floor, down for below.
		var r := _tile_rect(tile)
		var mid := r.get_center()
		var size := r.size.x * 0.18
		var above: bool = combat.floors[on].level > combat.floors[shown].level
		var tip := mid + Vector2(0, -size if above else size)
		draw_colored_polygon(PackedVector2Array([tip, mid + Vector2(-size, size if above else -size),
			mid + Vector2(size, size if above else -size)]), edge)


## A ladder on every climb tile (Combat "Heights").
func _draw_ladders():
	for tile in combat.climb_tiles:
		var r := _tile_rect(tile).grow(-Grid.TILE_SIZE * 0.22)
		var left := r.position.x + r.size.x * 0.25
		var right := r.position.x + r.size.x * 0.75
		draw_line(Vector2(left, r.position.y), Vector2(left, r.end.y), LADDER_COLOUR, EDGE_WIDTH)
		draw_line(Vector2(right, r.position.y), Vector2(right, r.end.y), LADDER_COLOUR, EDGE_WIDTH)
		for rung in 4:
			var y := r.position.y + r.size.y * (0.12 + 0.25 * rung)
			draw_line(Vector2(left, y), Vector2(right, y), LADDER_COLOUR, EDGE_WIDTH * 0.7)


## Whether a walk by `mover` (of `movement_class`) goes by these rules rather
## than the grid: on a map with heights - for a flier, only where there are floors
## to go between - and anywhere for somebody who can squeeze (Combat.can_squeeze)
## or climbs anywhere (Combat.climbs_anywhere), barrels on any map.
func _height_pathing(movement_class: int, mover: Dictionary = {}) -> bool:
	if combat == null:
		return false
	if not mover.is_empty() and (combat.can_squeeze(mover) or combat.climbs_anywhere(mover)):
		return true
	if not combat.heights_in_play():
		return false
	return movement_class != 1 or combat._floored


## The size `mover` walks at: the size they are. Anybody unknown is a Human.
func _full_size(mover: Dictionary) -> int:
	if mover.is_empty():
		return Sizes.Size.HUMAN
	return mover.get("size", Sizes.Size.HUMAN)


## `mover`'s square at `size`, as tiles across and down.
func _square_of(mover: Dictionary, size: int) -> Vector2i:
	var span := Sizes.span(size, mover.get("gigantic_span", 16))
	return Vector2i(span, span)


## The shape `mover` could stand in anchored at `anchor`, as tiles across and
## down: their square - or, for somebody who can squeeze whose square does not
## fit there, the first fold of it that does (Combat.fold_shapes). ZERO for no way
## at all. Where they stand now, the shape they are in. Anybody unknown stands as
## a Human.
func _stance(mover: Dictionary, anchor: Vector2i, start: Vector2i, movement_class: int) -> Vector2i:
	if anchor == start and not mover.is_empty() and mover.get("position", NO_TILE) == start:
		return Combat.footprint(mover)
	var full := _full_size(mover)
	for shape in combat.fold_shapes(mover, full):
		if _fits_as(mover, anchor, full, shape, start, movement_class):
			return shape
	return Vector2i.ZERO


## Whether `mover` at `size`, standing in `shape` (tiles across and down), fits
## anchored at `anchor`: every tile of it on the map and on one floor, ground they
## can stand on - high ground too, for somebody a tile big (who has climbed to it)
## or big enough to step over it - and nobody else there, save small ones of
## their own side with room to share. Nothing Fear has closed off, either; where
## they began always fits.
func _fits_as(mover: Dictionary, anchor: Vector2i, size: int, shape: Vector2i, start: Vector2i, movement_class: int) -> bool:
	var here: int = combat.floor_of(anchor)
	var steps_over: bool = Combat.steps_over_size(size, movement_class)
	for dy in shape.y:
		for dx in shape.x:
			var tile: Vector2i = anchor + Vector2i(dx, dy)
			if not is_on_map(tile) or combat.floor_of(tile) != here:
				return false
			if is_tile_blocking(tile, movement_class) and not (combat.is_high(tile) and (shape == Vector2i.ONE or steps_over)):
				return false
	if anchor == start:
		return true
	if _fear_blocked.has(anchor):
		return false
	if mover.is_empty() or not Sizes.shares(size):
		for dy in shape.y:
			for dx in shape.x:
				var tile: Vector2i = anchor + Vector2i(dx, dy)
				if _occupied_spaces.has(tile) and (mover.is_empty() or not combat.covers(mover, tile)):
					return false
		return true
	# Small enough to share: as many as fit, of their own side.
	var was_size: int = mover.size
	var was_span: int = mover.get("span", 1)
	mover.size = size
	mover.span = 1
	var room: bool = combat.room_for(mover, anchor, false)
	mover.size = was_size
	mover.span = was_span
	return room


## Whether every tile of `shape` (tiles across and down) anchored at `anchor` is
## a climb tile: stairs as big as whoever would use them, or bigger.
func _stairs_under(anchor: Vector2i, shape: Vector2i) -> bool:
	for dy in shape.y:
		for dx in shape.x:
			if not combat.climb_tiles.has(anchor + Vector2i(dx, dy)):
				return false
	return true


## Whether `shape` (tiles across and down), anchored over the ground at `real`,
## is all open air on floor `index` - somewhere to step off its edge.
func _open_air(index: int, real: Vector2i, shape: Vector2i) -> bool:
	for dy in shape.y:
		for dx in shape.x:
			var tile: Vector2i = combat.tile_on(index, real + Vector2i(dx, dy))
			if tile.x != -99999 and is_on_map(tile):
				return false
	return true


## Every step `mover` (of `movement_class`) can take from anchor `tile`, as
## [anchor, cost]: along their floor where they fit - onto high ground only from
## stairs or along it, for anybody a tile big; up stairs as big as they are; down
## off an edge into open air. A step they have to fold themselves into (Combat
## "Squeezing") costs twice over.
func _height_steps(tile: Vector2i, movement_class: int, start: Vector2i, mover: Dictionary = {}, stances: Dictionary = {}) -> Array:
	var found := []
	var shape_here: Vector2i = stances.get(tile, Vector2i.ZERO)
	if shape_here == Vector2i.ZERO:
		shape_here = _stance(mover, tile, start, movement_class)
	if shape_here == Vector2i.ZERO:
		shape_here = Combat.footprint(mover) if not mover.is_empty() else Vector2i.ONE
	var climbs: bool = _stairs_under(tile, shape_here)
	var from_high: bool = shape_here == Vector2i.ONE and combat.is_high(tile)
	var here: int = combat.floor_of(tile)
	for way in _EIGHT_WAYS:
		_add_step(found, tile + way, mover, start, movement_class, stances, from_high or climbs)
	if combat._floored and here >= 0:
		var real: Vector2i = combat.real_of(tile)
		# Up the stairs, if they are as big as whoever climbs them.
		if climbs:
			var up: Vector2i = combat.tile_on(combat.floor_beside(here, 1), real)
			if up.x != -99999:
				_add_step(found, up, mover, start, movement_class, stances, true)
		# Up a wall or a pillar onto the floor over it, for somebody who climbs
		# anywhere (Cyrus's Cat Burglar): from open air, beside something solid
		# with standing room above it.
		var above: int = combat.floor_beside(here, 1)
		if above >= 0 and not mover.is_empty() and combat.climbs_anywhere(mover) and _open_air(above, real, shape_here):
			for way in _EIGHT_WAYS:
				var solid: Vector2i = tile + way
				if not is_on_map(solid) or combat.floor_of(solid) != here or not is_tile_blocking(solid, 0):
					continue
				var over: Vector2i = combat.tile_on(above, combat.real_of(solid))
				if over.x != -99999:
					_add_step(found, over, mover, start, movement_class, stances, true)
		# Down off an edge, wherever there is open air the size of them beside them.
		var below: int = combat.floor_beside(here, -1)
		if below >= 0:
			for way in _EIGHT_WAYS:
				var edge: Vector2i = real + way
				if not _open_air(here, edge, shape_here):
					continue
				var down: Vector2i = combat.tile_on(below, edge)
				if down.x != -99999:
					_add_step(found, down, mover, start, movement_class, stances, true)
	return found


## Adds a step onto `next` to `found`, if `mover` can stand there - onto high
## ground, for anybody a tile big who cannot step over it, only `may_climb`. The
## shape they stand in there goes into `stances`.
func _add_step(found: Array, next: Vector2i, mover: Dictionary, start: Vector2i, movement_class: int, stances: Dictionary, may_climb: bool):
	var shape := _stance(mover, next, start, movement_class)
	if shape == Vector2i.ZERO:
		return
	var full := _full_size(mover)
	if shape == Vector2i.ONE and movement_class != 1 and not Combat.steps_over_size(full, movement_class) \
			and combat.is_high(next) and not may_climb and not combat.climbs_anywhere(mover):
		return
	stances[next] = shape
	var folded: bool = shape != _square_of(mover, full)
	found.append([next, get_tile_cost_for_class(next, movement_class) * (2 if folded else 1) * (2 if _hemmed.has(next) else 1)])


## Every anchor reachable from `start` within `budget`, by these rules, with what
## it costs to get there - get_reachable_tiles' answer. Each one's way in goes
## into `parents`; it stops early once `goal` is settled. Steps cost a few points
## at most, so the anchors wait in a bucket per cost rather than a sorted queue.
##
## A diagonal step costs what a straight one does, so many ways in cost the same;
## of those, the one that is shortest to look at, with the fewest climbs, is kept
## (_looks_longer). Without it the walk took whichever it met first and zig-zagged
## along a straight line.
func _height_search(start: Vector2i, movement_class: int, budget: int, parents: Dictionary = {}, goal: Vector2i = Vector2i(-99999, -99999), mover: Dictionary = {}) -> Dictionary:
	# Twice as dear near anybody hemming them in - read by _add_step.
	_hemmed = combat.hemmed_tiles(mover) if combat != null else {}
	var costs := {start: 0}
	var lengths := {start: 0.0}
	var high := {}
	var stances := {}
	var buckets: Array = [[start]]
	var settled := {}
	var at := 0
	while at < buckets.size():
		var bucket: Array = buckets[at]
		while not bucket.is_empty():
			var current: Vector2i = bucket.pop_back()
			if settled.has(current) or costs[current] != at:
				continue
			settled[current] = true
			if current == goal:
				return costs
			for step in _height_steps(current, movement_class, start, mover, stances):
				var cost: int = at + step[1]
				if cost > budget:
					continue
				var length: float = lengths[current] + _looks_longer(current, step[0], high)
				if costs.has(step[0]) and (cost > costs[step[0]] or settled.has(step[0])):
					continue
				if costs.has(step[0]) and cost == costs[step[0]]:
					# As dear as the way in already found: only if it looks shorter.
					if length < lengths[step[0]] - 0.001:
						lengths[step[0]] = length
						parents[step[0]] = current
					continue
				costs[step[0]] = cost
				lengths[step[0]] = length
				parents[step[0]] = current
				while buckets.size() <= cost:
					buckets.append([])
				buckets[cost].append(step[0])
		at += 1
	return costs


## How long a step from `from` to `to` looks, for choosing between ways that cost
## the same (_height_search): a diagonal longer than a straight step, and a climb
## onto or off high ground, or between floors, longer again. `high` keeps what
## is_high said of each tile, for the rest of the search.
func _looks_longer(from: Vector2i, to: Vector2i, high: Dictionary) -> float:
	var way := to - from
	# Further than a step on one floor: up or down to another.
	if absi(way.x) > 1 or absi(way.y) > 1:
		return 1.5
	var length := 1.4142 if way.x != 0 and way.y != 0 else 1.0
	for tile in [from, to]:
		if not high.has(tile):
			high[tile] = combat.is_high(tile)
	if high[from] != high[to]:
		length += 0.5
	return length


## The anchors of a walk by `mover` from `from` to `to`, by these rules, both ends
## included - to the nearest one beside `to` that can be reached, if `to` itself
## cannot be stood on (somebody there). Just [from] when nowhere near can be.
func _height_path(from: Vector2i, to: Vector2i, movement_class: int, mover: Dictionary = {}) -> Array:
	var parents := {}
	var costs := _height_search(from, movement_class, 999, parents, to, mover)
	var end := to
	if not costs.has(end):
		end = from
		var cheapest := 999999
		for way in _EIGHT_WAYS:
			var beside: Vector2i = to + way
			if costs.has(beside) and costs[beside] < cheapest:
				cheapest = costs[beside]
				end = beside
	var tiles: Array = [end]
	while tiles.front() != from and parents.has(tiles.front()):
		tiles.push_front(parents[tiles.front()])
	return tiles


## What a step onto `tile` costs whoever is walking: the tile's own cost, twice
## over for somebody who has to squeeze in there.
func _step_cost(tile: Vector2i) -> int:
	var walker = _walking_combatant if not _walking_combatant.is_empty() else combat.get_current_combatant()
	var cost: int = get_tile_cost(tile)
	if combat.can_squeeze(walker):
		var shape := _stance(walker, tile, walker.position, walker.get("movement_class", 0))
		if shape != Vector2i.ZERO and shape != _square_of(walker, _full_size(walker)):
			cost *= 2
	# And twice over again, dragging somebody along (Combat "Dragging").
	return cost * combat.drag_cost(walker) * combat.hem_cost(walker, tile)


func _ready():
	tile_map = get_node("../Terrain/TileMap")
	# The board a pad's pointer moves over - see Pad.
	add_to_group(&"pad_board")
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
		# SEE_THROUGH rides in the same array as the movement classes but is
		# not one, so it is taken out here rather than indexed with them - and
		# a tile carrying nothing else is no obstacle at all, which is why
		# _all_blocking_spaces waits to hear that a class was really listed.
		var stops_somebody = false
		for block in blocks:
			if block == SEE_THROUGH:
				_see_through[tile] = true
				continue
			if block < 0 or block >= _blocking_spaces.size():
				continue
			stops_somebody = true
			_blocking_spaces[block].append(tile)
			_blocking_lookup[block][tile] = true
		if stops_somebody:
			_all_blocking_spaces.append(tile)
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


func combatant_added(_combatant):
	refresh_occupancy()


## Back on their feet (Combat.revive): their tile is taken again.
func combatant_revived(_combatant):
	refresh_occupancy()


## `from` if somebody of `movement_class` could stand there now, or else the
## nearest tile they could - ring by ring outward. For somebody brought back
## where they fell, with somebody else since standing on the spot.
func nearest_free_tile(from: Vector2i, movement_class: int) -> Vector2i:
	for reach in range(0, 12):
		for dx in range(-reach, reach + 1):
			for dy in range(-reach, reach + 1):
				if maxi(absi(dx), absi(dy)) != reach:
					continue
				var tile := from + Vector2i(dx, dy)
				if is_in_bounds(tile) and not _occupied_spaces.has(tile) and not is_tile_blocking(tile, movement_class):
					return tile
	return from


## Whoever a click on `tile` is aimed at while aiming: somebody fallen there,
## for a skill that is aimed at the fallen, or else whoever is standing there.
## {} for nobody.
func aim_subject_at(tile: Vector2i) -> Dictionary:
	if _skill_selected and SkillDatabase.skills[_selected_skill].targets_fallen:
		return combat.fallen_at(tile, aiming_caster().side)
	# Several small ones sharing the tile: whichever the pointer is nearest.
	if combat.combatants_at(tile).size() > 1:
		return combat.nearest_on(tile, _pointed_at())
	var comb = get_combatant_at_position(tile)
	return comb if comb != null else {}


func combatant_died(_combatant):
	refresh_occupancy()


func set_controlled_combatant(combatant: Dictionary):
	# A walk still in the air belongs to a turn that is now over. Left running,
	# _process drags whoever is controlled next along the abandoned path, since
	# there is only one _next_position for everybody.
	end_walk()
	_card_for(null)
	# Somebody fighting for the party but not the player's to command (bought,
	# rebound) is played by the AI, like the other side.
	if combatant.side == 0 and not combatant.get("ai_controlled", false):
		player_turn = true
		_point_pad_at.call_deferred(combatant)
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
	_remember_turn_start(combatant)
	# The party's turn begins on their own floor (Combat "Heights"); the enemy's
	# is watched wherever they are anyway.
	if player_turn and combat._floored and combat.floor_of(combatant.position) != shown_floor():
		show_floor(combat.floor_of(combatant.position), combatant.position)
	queue_redraw()


## --- Taking a walk back ---
##
## A player can walk back to where their turn began, for as long as the walking
## has changed nothing but where they are standing: no reaction set off on the
## way, no skill or item used, nobody's state touched, no passive switched on or
## off. Combat.board_fingerprint is how "nothing" is measured - taken when the
## turn begins, and compared again before any walk back.
##
## Once something like that has happened it stays happened, but the walking
## after it is as free as the walking before it was. So the point a walk back
## returns to moves up to just after it: walk two tiles, fire the Gun, walk
## three more, and a walk back undoes the three - see settle_undo_point.

var _turn_owner_id := -1
var _turn_start_position := Vector2i.ZERO
var _turn_start_movement := 0
var _turn_start_board := ""


func _remember_turn_start(combatant: Dictionary):
	_turn_owner_id = combatant.get("id", -1)
	_turn_start_position = combatant.position
	_turn_start_movement = movement
	_turn_start_board = combat.board_fingerprint(combatant) if combat != null else ""


## Moves the point a walk back returns to up to here and now, if anything has
## happened since it was set that a walk back cannot take back - a skill or an
## item used, a reaction set off by the step just taken, somebody spotted.
## Called after every step of a walk and after every skill, so it always lands
## just after the thing that happened, with the movement left at that moment.
func settle_undo_point():
	if combat == null or not player_turn:
		return
	var comb = combat.get_current_combatant()
	if comb.get("id", -2) != _turn_owner_id or not comb.get("alive", false):
		return
	var board = combat.board_fingerprint(comb)
	if board == _turn_start_board:
		return
	_turn_start_position = comb.position
	_turn_start_movement = movement
	_turn_start_board = board


## Whether the player acting has walked anywhere since the point a walk back
## would return them to.
func has_walked() -> bool:
	if not player_turn or combat == null:
		return false
	var comb = combat.get_current_combatant()
	return comb.get("id", -2) == _turn_owner_id and comb.position != _turn_start_position


## Whether that walk can still be taken back: they are standing still, nothing
## is being aimed or resolved, and the battle is otherwise exactly as it was at
## the point they would go back to.
func can_undo_move() -> bool:
	if not has_walked() or not is_idle() or action_locked or _skill_selected:
		return false
	return combat.board_fingerprint(combat.get_current_combatant()) == _turn_start_board


## Puts the player acting back where their turn began - or just after the last
## thing that cannot be taken back - with the movement they had there. False,
## and nothing done, when it cannot be taken back.
func undo_move() -> bool:
	if not can_undo_move():
		return false
	var comb = combat.get_current_combatant()
	var from: Vector2i = comb.position
	comb.position = _turn_start_position
	comb.sprite.position = tile_map.map_to_local(_turn_start_position)
	reposition_combatant(from, _turn_start_position)
	# Nothing of the walk left to finish, and no route drawn from where they were.
	_path = PackedVector2Array()
	_position_id = 0
	_previous_position = _turn_start_position
	_next_position = tile_map.map_to_local(_turn_start_position)
	set_movement(_turn_start_movement)
	refresh_watched_tiles(comb)
	combat.update_information.emit("[color=yellow]%s[/color] walks back.\n" % comb.name)
	game_ui_refresh()
	queue_redraw()
	return true


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
				if combat.sees_tile(watcher, tile):
					_watched_tiles.append(tile)
					break


## Tiles made unwalkable by Fear on the current combatant, so they can be
## released again once the fear passes or someone else's turn begins. Nothing
## else in update_points_weight would clear them, since they're neither
## occupied nor blocking terrain.
var _fear_blocked: Array = []
## The tiles _weigh_hemmed_tiles weighed twice, to weigh once again.
var _hem_weighted: Array = []
## Whether the grid was last fitted to somebody bigger than a tile, whose
## closing of open ground the next update has to undo first.
var _big_fitted := false


func update_points_weight():
	var current_comb = combat.get_current_combatant()
	# Release last turn's fear tiles before anything else re-decides the grid.
	for tile in _fear_blocked:
		_astargrid.set_point_weight_scale(tile, 1)
		_astargrid.set_point_solid(tile, false)
	_fear_blocked.clear()
	# Somebody bigger than a tile closed every point their square did not fit
	# (_fit_points_to_big) - open ground included, which nothing below revisits.
	# Left closed, whoever came after them could not walk anywhere at all: the
	# party after a golem's turn could only step onto a tile somebody had just
	# left. Opened again here, for the rest of this to re-decide.
	if _big_fitted:
		var region: Rect2i = _astargrid.region
		for y in range(region.position.y, region.end.y):
			for x in range(region.position.x, region.end.x):
				_astargrid.set_point_solid(Vector2i(x, y), false)
				_astargrid.set_point_weight_scale(Vector2i(x, y), 1)
		_big_fitted = false
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
	#
	# Never the tile the active combatant stands on, though, even ground they
	# could not walk onto - shoved, thrown or set down there. A solid start
	# point means no path can be found at all: they would plan a step and a
	# swing, take neither, and swing at nothing from where they stood.
	var standing_on: Array = Combat.tiles_of(current_comb)
	for space in _all_blocking_spaces:
		if is_tile_blocking(space, current_comb.movement_class) and not space in standing_on:
			_astargrid.set_point_weight_scale(space, INF)
			_astargrid.set_point_solid(space, true)
		else:
			_astargrid.set_point_weight_scale(space, 1)
			_astargrid.set_point_solid(space, false)
	# Somebody bigger or smaller than a tile goes only where they fit.
	if Combat.footprint(current_comb) != Vector2i.ONE:
		_fit_points_to_big(current_comb)
		_big_fitted = true
	elif Sizes.shares(current_comb.get("size", Sizes.Size.HUMAN)):
		_fit_points_to_small(current_comb)
	_apply_fear_restrictions(current_comb)
	_weigh_hemmed_tiles(current_comb)


## Routes around the tiles hemming the current combatant in where that is
## cheaper (Combat "Hemmed In and Exposed"): weighed twice on the pathfinding
## grid, as they are paid for.
func _weigh_hemmed_tiles(current_comb: Dictionary):
	for tile in _hem_weighted:
		if not _astargrid.is_point_solid(tile):
			_astargrid.set_point_weight_scale(tile, 1)
	_hem_weighted.clear()
	for tile in combat.hemmed_tiles(current_comb):
		if is_in_bounds(tile) and not _astargrid.is_point_solid(tile):
			_astargrid.set_point_weight_scale(tile, 2)
			_hem_weighted.append(tile)


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
	# The floor on the screen changed (the view moved): who is on another one is
	# drawn afresh.
	if combat != null and combat._floored and shown_floor() != _drawn_floor:
		queue_redraw()
	if _processing_step:
		# A reactive skill triggered by this exact step is still resolving
		# (its animation is playing) - do nothing further until it's done,
		# rather than letting Godot's normal per-frame call re-enter this
		# mid-step and process the same arrival twice.
		return
	if _arrived == false:
		# Hopping up or down a floor: the walk waits for the landing.
		if _hop_hold > 0.0:
			_hop_hold -= delta
			return
		if controlled_node.position.distance_to(_next_position) > Grid.TILE_SIZE * 2.0:
			# Up or down a floor (Combat "Heights"): there at once, and the view
			# with them, rather than walked across the map between the two.
			var camera = combat.camera if combat != null else null
			if camera != null and is_instance_valid(camera) and not camera.is_following():
				camera.position += _next_position - controlled_node.position
				camera.clamp_to_map()
			controlled_node.position = _next_position
			if _floor_hop != CombatantSprite.Hop.NONE and controlled_node.has_method("hop"):
				controlled_node.hop(_floor_hop, FLOOR_HOP_SECONDS)
				_floor_hop = CombatantSprite.Hop.NONE
				_hop_hold = FLOOR_HOP_SECONDS
				return
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
	# What a step sets off - reactions, being seen - goes by what is there, even
	# in the middle of an AI's turn (Combat.ai_believes).
	var believed: bool = combat.ai_believes
	combat.ai_believes = false
	await _handle_step_arrival()
	combat.ai_believes = believed
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
	controlled_node.position = _next_position
	var new_position: Vector2i = tile_map.local_to_map(_next_position)
	var mover = _walking_combatant if not _walking_combatant.is_empty() \
			else combat.get_current_combatant()
	var was_up: bool = mover.get("up", false)
	# Dragging somebody costs this step twice over (Combat "Dragging") - priced
	# before the drag, for whoever was held as the step began.
	var dragging: int = combat.drag_cost(mover)
	# Twice as dear near anybody hemming them in (Combat "Hemmed In and Exposed").
	var hemmed: int = combat.hem_cost(mover, new_position)
	mover.position = new_position
	# Walked this turn (Momentum - Combat "Progression"), and how far (Leading
	# Charge - Combat "The paths").
	mover["moved_this_turn"] = true
	mover["walked_this_turn"] = mover.get("walked_this_turn", 0) + 1
	_previous_position = new_position
	# Squeezed in, or out into room again (Combat "Squeezing").
	var squeezing: bool = combat.fit_to_room(mover)
	# Whoever they have hold of comes after them - said once a walk.
	if combat.drag_held(mover, not _dragged_this_walk):
		_dragged_this_walk = true
	refresh_occupancy()
	# Up onto high ground or down off it, up a floor or down one - said.
	if combat.heights_in_play() or combat.climbs_anywhere(mover):
		combat.note_height_step(mover, old_position, new_position, was_up)
	update_points_weight()
	# Walked away from somebody they had hold of, they let go (Grab).
	combat.check_holds()
	await combat.check_reactive_skills(mover, old_position, new_position)
	# Into a zone or out of one (Combat "Zones").
	combat.sync_zones()
	# Onto a trap of the other side's (Combat "Traps"): held fast, and the walk is over.
	if mover.alive and combat.spring_trap(mover, new_position):
		movement = 0
		refresh_occupancy()
		update_points_weight()
		settle_undo_point()
		_path = []
		finished_move.emit()
		_arrived = true
		controlled_node.position = combat.sprite_point(mover)
		controlled_node.play_idle()
		check_turn_completion.call_deferred()
		return
	if combat.is_held(mover):
		# Grabbed on the way out (Grab): dragged back, and the walk is over.
		# What was left of it comes back if they break free this turn.
		mover["movement_left_when_grabbed"] = maxi(movement - get_tile_cost(new_position) * dragging * hemmed, 0)
		movement = 0
		refresh_occupancy()
		update_points_weight()
		settle_undo_point()
		_path = []
		finished_move.emit()
		_arrived = true
		controlled_node.position = combat.sprite_point(mover)
		controlled_node.play_idle()
		check_turn_completion.call_deferred()
		return
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
		movement -= get_tile_cost(new_position) * (2 if squeezing else 1) * dragging * hemmed
		settle_undo_point()
		_path = []
		finished_move.emit()
		_arrived = true
		controlled_node.play_idle()
		check_turn_completion.call_deferred()
		return
	# Pay for the tile just entered (not the one left behind), and only
	# continue if the *next* waypoint - not this one again - is actually
	# affordable. Squeezed in, twice over.
	movement -= get_tile_cost(new_position) * (2 if squeezing else 1) * dragging * hemmed
	# A reaction this step set off is behind them now: a walk back stops here.
	settle_undo_point()
	if _position_id < _path.size() - 1 and movement > 0 and _step_cost(tile_map.local_to_map(_path[_position_id + 1])) <= movement:
		_position_id += 1
		_next_position = _path[_position_id]
		_begin_step()
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
	for tile in tiles_to_check:
		var candidate = target_position + tile
		# Off the edge of the map there is nothing to ask the grid about.
		if not is_in_bounds(candidate) or candidate in _occupied_spaces:
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
	# High ground and floors walk by their own rules ("Heights"), which also
	# find the nearest tile they can stand on when the one asked for is not.
	var walker = combat.get_current_combatant() if combat != null else {}
	if _height_pathing(walker.get("movement_class", 0), walker):
		_path = PackedVector2Array(_height_path(current_position, tile_position, walker.get("movement_class", 0), walker).map(
			func(tile): return tile_map.map_to_local(tile)))
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
	var mover = combat.get_current_combatant()
	# Walking by the rules of heights, or squeezing: wherever they could stand -
	# squeezed, or up on high ground - as the walk found it.
	if _height_pathing(mover.get("movement_class", 0), mover):
		if tile != mover.position and _stance(mover, tile, mover.position, mover.get("movement_class", 0)) == Vector2i.ZERO:
			return false
		return combat.fear_allows(mover, tile)
	# Somebody bigger or smaller than a tile ends a move only where they fit -
	# a flier passes over others, and must still come down somewhere clear.
	if (Combat.footprint(mover) != Vector2i.ONE or Sizes.shares(mover.get("size", Sizes.Size.HUMAN))) \
			and tile != mover.position and not combat.room_for(mover, tile):
		return false
	return combat.fear_allows(mover, tile)


## Whoever is mid-walk, so a step that lands after their turn has passed is
## not written onto whoever happens to be acting by then.
var _walking_combatant: Dictionary = {}
## Whether this walk has dragged anybody yet, so the log says it once.
var _dragged_this_walk := false


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
	_hop_hold = 0.0
	_floor_hop = CombatantSprite.Hop.NONE
	if walker.is_empty() or not walker.get("alive", false):
		return
	var sprite = walker.get("sprite", null)
	if sprite == null or not is_instance_valid(sprite):
		return
	sprite.position = tile_map.map_to_local(walker.position)
	if sprite.has_method("end_hop"):
		sprite.end_hop()
	if sprite.has_method("play_idle"):
		sprite.play_idle()


## --- Hops ---
##
## Up onto high ground or down off it, up a floor or down one, whoever walks
## hops (CombatantSprite.hop): over the step, for one along a floor; in place as
## they arrive, the walk held for it, for one between floors, which is snapped.

const FLOOR_HOP_SECONDS := 0.4

## What is left of the hold for a hop between floors.
var _hop_hold := 0.0
## The hop for the step being walked, if it goes between floors - played once
## the walk has snapped there (_process).
var _floor_hop: int = CombatantSprite.Hop.NONE


## A step from the walker's tile to `_next_position` begins: the hop for it, if
## it is one.
func _begin_step():
	_hop_hold = 0.0
	_floor_hop = CombatantSprite.Hop.NONE
	if _walking_combatant.is_empty() or controlled_node == null or not controlled_node.has_method("hop"):
		return
	var kind := hop_for(_walking_combatant, tile_map.local_to_map(controlled_node.position), tile_map.local_to_map(_next_position))
	var snapped := controlled_node.position.distance_to(_next_position) > Grid.TILE_SIZE * 2.0
	if kind == CombatantSprite.Hop.FLOOR_UP or kind == CombatantSprite.Hop.FLOOR_DOWN:
		if snapped:
			_floor_hop = kind
		else:
			# Floors laid out side by side: walked across, so hopped across.
			controlled_node.hop(CombatantSprite.Hop.UP if kind == CombatantSprite.Hop.FLOOR_UP else CombatantSprite.Hop.DOWN,
				controlled_node.position.distance_to(_next_position) / move_speed)
	elif kind != CombatantSprite.Hop.NONE:
		controlled_node.hop(kind, controlled_node.position.distance_to(_next_position) / move_speed)


## The hop (CombatantSprite.Hop) `mover` makes stepping from `from` to `to`: up
## or down a floor; onto high ground or off it, for anybody a tile big who walks
## and climbs (a flier flies over it, and the big step over it).
func hop_for(mover: Dictionary, from: Vector2i, to: Vector2i) -> int:
	if combat == null or mover.has("riding") or mover.has("object"):
		return CombatantSprite.Hop.NONE
	var before: int = combat.floor_of(from)
	var after: int = combat.floor_of(to)
	if before != after and before >= 0 and after >= 0:
		return CombatantSprite.Hop.FLOOR_UP if combat.floor_level(to) > combat.floor_level(from) else CombatantSprite.Hop.FLOOR_DOWN
	if mover.get("movement_class", 0) == 1 or Combat.footprint(mover) != Vector2i.ONE:
		return CombatantSprite.Hop.NONE
	if not combat.heights_in_play() and not combat.climbs_anywhere(mover):
		return CombatantSprite.Hop.NONE
	var high_before: bool = combat.is_high(from)
	var high_after: bool = combat.is_high(to)
	if high_after and not high_before:
		return CombatantSprite.Hop.UP
	if high_before and not high_after:
		return CombatantSprite.Hop.DOWN
	return CombatantSprite.Hop.NONE


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
	var first_walker = combat.get_current_combatant()
	if movement <= 0 or get_tile_cost_at_point(_path[1]) * combat.drag_cost(first_walker) * combat.hem_cost(first_walker, tile_map.local_to_map(_path[1])) > movement:
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
	_dragged_this_walk = false
	_begin_step()
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


## --- Only looking ---
##
## A skill that cannot be used right now - its action spent, its gate empty, or
## a teammate's on a turn that is not theirs - can still be aimed, to see its
## reach, where it would land and what it would do to whoever it caught. Nothing
## happens on a click: it is a look, from wherever its owner is standing and
## with their numbers, so the question "would Prometheus's Fireball finish him
## off?" can be answered before Cyrus decides what to do.

var _aim_caster: Dictionary = {}
var _look_only := false


## Aims `skill` from `caster` without being able to use it. See above.
func begin_look(skill: String, caster: Dictionary):
	if _skill_selected:
		cancel_skill_selection()
	_selected_skill = skill
	_selected_skill_is_secondary = false
	_aim_caster = caster
	_look_only = true
	begin_target_selection()


## Whether what is being aimed is only being looked at.
func is_look_only() -> bool:
	return _skill_selected and _look_only


## Who the skill being aimed would come from: the one acting, or whoever's
## skill is only being looked at.
func aiming_caster() -> Dictionary:
	if not _aim_caster.is_empty():
		return _aim_caster
	return combat.get_current_combatant()


func begin_target_selection():
	_skill_selected = true
	_card_for(null)
	var skill = SkillDatabase.skills[_selected_skill]
	var caster = aiming_caster()
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
	elif Combat.summons_with(skill) != "":
		# So is calling something up: where it would fit (Combat "Summons").
		_range_preview_positions = landable_tiles(_range_preview_positions, combat.summon_probe(skill, caster.get("side", 0)))
	elif Combat.sets_traps(skill) and Combat.trap_field_of(skill) == 0:
		# A trap goes on bare ground (Combat "Traps"); a field anywhere in reach.
		_range_preview_positions = _range_preview_positions.filter(func(tile): return combat.trap_fits(tile))
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
	# A blink, or calling something up (Combat "Summons"): somewhere to stand.
	if skill.teleports == SkillDefinition.TeleportWho.CASTER or Combat.summons_with(skill) != "":
		return true
	return aimed_twice(skill) and waiting_for_destination()


## Whether `skill` is aimed twice - at who, then at where: a teleport that moves
## somebody else, or a skill Placed In Reach (an image of an ally, put down
## where the caster likes).
static func aimed_twice(skill: SkillDefinition) -> bool:
	return skill.teleports == SkillDefinition.TeleportWho.TARGET or skill.placed_in_reach


## Whoever the aimed teleport would move - or whoever an image is to be of - so
## we can ask whether they fit.
func travelling_combatant() -> Dictionary:
	var skill: SkillDefinition = SkillDatabase.skills[_selected_skill]
	if aimed_twice(skill):
		return combat.get_combatant_at(_teleport_subject)
	# What it calls up, as big as it is (Combat "Summons").
	if Combat.summons_with(skill) != "":
		return combat.summon_probe(skill, aiming_caster().get("side", 0))
	return aiming_caster()


## Whether aiming the selected teleport at the traveller's own tile is worth
## doing. A blink that bursts where it lands still bursts if it lands where it
## started, so staying put is a real choice; a skill whose only point is the
## journey would just be a cast thrown away, so it is refused. An image never
## goes where whoever it is of already stands.
func standing_still_does_something() -> bool:
	var skill: SkillDefinition = SkillDatabase.skills[_selected_skill]
	return not skill.placed_in_reach and not skill.all_effects().is_empty()


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
	# A throw may land on somebody (Hurl - see Combat "Grappling").
	var skill: SkillDefinition = SkillDatabase.skills[_selected_skill]
	if skill.throws:
		return combat.throw_destinations(aiming_caster(), skill, traveller).has(tile)
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
	# Only looking: nothing is chosen and nothing is spent, whatever asks.
	if _look_only:
		return
	aim_was_called_off = false
	var skill: SkillDefinition = SkillDatabase.skills[_selected_skill]
	if aimed_twice(skill) and not waiting_for_destination():
		# First click chose who travels - or whose image it is. Stay in aiming
		# mode: the next one says where to, and until then nothing has been spent.
		_teleport_subject = position
		# Now that we know who is travelling, narrow the marked tiles to the
		# ones they could be set down on.
		var subject_comb = combat.get_combatant_at(position)
		if not subject_comb.is_empty() and skill.throws:
			# Thrown: anywhere in the throw's reach, somebody to throw them at
			# included - not the reach they were grabbed from.
			_range_preview_positions = combat.throw_destinations(aiming_caster(), skill, subject_comb)
		elif not subject_comb.is_empty():
			_range_preview_positions = landable_tiles(_range_preview_positions, subject_comb)
		queue_redraw()
		return
	# Among several small ones sharing the tile, the one pointed at.
	combat.aim_choice = aim_subject_at(position).get("id", -1)
	var subject = _teleport_subject
	_teleport_subject = Vector2i(-99999, -99999)
	# Leave aiming mode immediately so input state is correct, but hold the
	# HUD back until the skill is done.
	_skill_selected = false
	_range_preview_positions = []
	# What the hit would do stops being a question the moment it is thrown.
	if combat.game_ui != null and combat.game_ui.has_method("hide_hit_preview"):
		combat.game_ui.hide_hit_preview()
	# The preview belongs to the aiming, so it ends with it.
	_previewing_hide = false
	refresh_watched_tiles(combat.get_current_combatant())
	queue_redraw()
	if aimed_twice(skill):
		await combat.use_skill(_selected_skill, combat.get_current_combatant(), subject, true, _selected_skill_is_secondary, position)
	else:
		await combat.use_skill(_selected_skill, combat.get_current_combatant(), position, true, _selected_skill_is_secondary)
	target_selection_finished.emit()
	queue_redraw()


## --- What an aim may be let go at ---
##
## One set of rules for a click on the map and a click on a face: the right
## side, a clear line, and the reach - the blue tiles on show. Anything outside
## them is refused and aiming goes on, rather than the skill being thrown and
## falling short, which spent nothing but put the aim away and left the player
## to pick the skill again.


## Why the aimed skill could not be let go at `tile` - at `comb`, whoever stands
## there, or {} for nobody - or "" when it could.
func refusal_at(tile: Vector2i, comb: Dictionary) -> String:
	if not _skill_selected:
		return "Nothing is being aimed"
	var skill: SkillDefinition = SkillDatabase.skills[_selected_skill]
	var caster = aiming_caster()
	if picking_a_landing_tile():
		if tile in _range_preview_positions and is_valid_landing_tile(tile):
			return ""
		if skill.throws:
			return "Too far to throw them"
		if skill.placed_in_reach or Combat.summons_with(skill) != "":
			return "%s needs an empty tile in reach to stand on" % skill.name
		return "%s needs an empty tile to land on" % skill.name
	# Aimed at a body, not anybody standing (Combat "Loot").
	if Combat.loots(skill):
		if tile not in _range_preview_positions:
			return "Out of reach"
		return combat.refusal_for(caster, skill, tile)
	if skill.placed_in_reach:
		# Who it is to be of: anybody of theirs standing, however far off - the
		# reach is for where it goes, asked next.
		if comb.is_empty() or not comb.get("alive", false):
			return "Nobody there"
		if comb.get("side", -1) != caster.get("side", -2):
			return "%s is only for allies" % skill.name
		if comb.get("illusion", false) or comb.has("object"):
			return "%s is not somebody to make an image of" % comb.name
		return ""
	if skill.targets_fallen:
		# Aimed at somebody fallen, of their own side, and nobody else.
		if comb.is_empty():
			return "Nobody fallen there"
		if comb.alive:
			return "%s is still standing" % comb.name
		if comb.side != caster.side:
			return "%s is only for allies" % skill.name
	var radius: int = combat.aoe_radius_of(caster, skill)
	# A trap: bare ground in reach, not anybody (Combat "Traps").
	if Combat.sets_traps(skill):
		if tile not in _range_preview_positions:
			return "Out of reach"
		return combat.refusal_for(caster, skill, tile)
	# Dispel Magic at bare ground: a zone there (Combat "Dispelling").
	if Combat.dispels_magic(skill) and comb.is_empty():
		if tile not in _range_preview_positions:
			return "Out of reach"
		return combat.refusal_for(caster, skill, tile)
	if radius == 0:
		# Aimed at somebody, so it is the somebody who has to be right.
		if comb.is_empty():
			return "Nobody there"
		if skill.max_range == 0 and comb != caster:
			return "%s can only be used on %s" % [skill.name, caster.name]
		if not skill.affects_both_sides:
			if skill.targets_ally and comb.side != caster.side:
				return "%s is only for allies" % skill.name
			if not skill.targets_ally and comb.side == caster.side:
				return "%s is only for enemies" % skill.name
		if Combat.steals(skill) and combat.steal_choices(comb).is_empty():
			return "%s has nothing on them to steal" % comb.name
	# Taunted, out of leverage, too heavy to lift - Combat's rules, asked the
	# same way use_skill asks them.
	var ruled_out: String = combat.refusal_for(caster, skill, tile)
	if ruled_out != "":
		return ruled_out
	var there = comb.name if not comb.is_empty() else "there"
	if tile not in _range_preview_positions:
		var distance = combat.distance_to(caster, tile)
		if distance >= skill.min_range and distance <= combat.effective_max_range(caster, skill):
			return "No clear line to %s" % there
		return "Out of reach"
	if radius == 0 and not is_valid_skill_target(comb, tile):
		return "No clear line to %s" % there
	return ""


## --- Aiming at a face ---
##
## A face in the party column or the turn queue can be clicked instead of the
## body on the map, by the same rules - see refusal_at.


## A click on `tile` of the map while aiming. Lets the skill go only where it
## can go: somewhere to stand for a teleport, any tile in reach for an area,
## somebody right for it for the rest. Anywhere else, aiming goes on. True when
## it went.
func aim_click(tile: Vector2i) -> bool:
	var comb = aim_subject_at(tile)
	if _look_only or refusal_at(tile, comb) != "":
		return false
	confirm_skill_target(tile)
	return true


## Why the aimed skill could not be used on `comb` from their face, or "" when
## it could. Said on the face's tooltip.
func aim_refusal(comb: Dictionary) -> String:
	if not _skill_selected or comb.is_empty():
		return "Nothing is being aimed"
	if not comb.get("alive", false):
		return "%s has fallen" % comb.get("name", "They")
	# Their face stays in the queue, but aiming at it would say where they are.
	if comb.side != 0 and combat.is_hidden(comb):
		return "Hidden - somewhere you cannot see"
	return refusal_at(face_aim_tile(comb), comb)


## Uses the aimed skill on `comb`, as clicking them on the map would. False,
## and still aiming, when it could not be used on them - or when it is only
## being looked at.
func aim_at_combatant(comb: Dictionary) -> bool:
	if not player_turn or action_locked or a_menu_is_over_the_map():
		return false
	if _look_only or aim_refusal(comb) != "":
		return false
	confirm_skill_target(face_aim_tile(comb))
	return true


## Marks on the map what aiming at `comb` would do, and says what it would do to
## whoever it caught - what hovering over them on the map shows.
func preview_aim_at_combatant(comb: Dictionary):
	if not _skill_selected:
		return
	_clear_aim_marks()
	var hud = combat.game_ui
	if comb.is_empty() or not comb.get("alive", false) or (comb.side != 0 and combat.is_hidden(comb)):
		# Nobody to mark - or somebody whose tile must not be.
		if hud != null and hud.has_method("hide_hit_preview"):
			hud.hide_hit_preview()
	elif aim_refusal(comb) != "":
		_blocked_target_position = tile_map.map_to_local(face_aim_tile(comb))
		if hud != null and hud.has_method("hide_hit_preview"):
			hud.hide_hit_preview()
	else:
		var skill: SkillDefinition = SkillDatabase.skills[_selected_skill]
		var caster = aiming_caster()
		var aim := face_aim_tile(comb)
		if combat.aoe_radius_of(caster, skill) > 0:
			_aoe_preview_positions = combat.get_impact_tiles(skill, Combat.nearest_tile_of(caster, aim), aim, caster.movement_class, caster.get("size", Sizes.Size.HUMAN), caster)
			_aoe_preview_is_ally = skill.targets_ally
		elif skill.targets_ally:
			_ally_target_position = tile_map.map_to_local(aim)
		else:
			_attack_target_position = tile_map.map_to_local(aim)
		_preview_hits(aim)
	queue_redraw()


## Takes the marks away again, once the cursor has left the face.
func clear_aim_preview():
	_clear_aim_marks()
	var hud = combat.game_ui if combat != null else null
	if hud != null and hud.has_method("hide_hit_preview"):
		hud.hide_hit_preview()
	queue_redraw()


func _clear_aim_marks():
	_attack_target_position = null
	_ally_target_position = null
	_blocked_target_position = null
	_aoe_preview_positions = []


## Backs out of target selection (right-click or Escape) without spending
## the skill, returning to normal move mode.
## Whether the last aim ended by being put away rather than let go - so a pad's
## skill panel, which the aim was begun from, can be gone back to.
var aim_was_called_off := false


func cancel_skill_selection():
	aim_was_called_off = true
	_skill_selected = false
	_look_only = false
	_aim_caster = {}
	_previewing_hide = false
	refresh_watched_tiles(combat.get_current_combatant())
	_teleport_subject = Vector2i(-99999, -99999)
	_clear_aim_marks()
	_range_preview_positions = []
	target_selection_finished.emit()
	queue_redraw()


## Whether `target` is a legal thing to select for the currently selected skill:
## enemies for attacks/debuffs, or the caster's own side for heals/buffs
## (SkillDefinition.targets_ally decides which), and - if the skill respects
## blocking - a clear path from the caster to them. Only used for non-area
## skills - area skills can be aimed at any tile, see aoe_radius handling in
## _unhandled_input.
##
## The line is to `tile`, the one aimed at - for somebody bigger than a tile,
## any of theirs, past the rest of them (their own body is no cover to them).
## Left out, the nearest of their tiles.
func is_valid_skill_target(target: Dictionary, tile = null) -> bool:
	var skill = SkillDatabase.skills[_selected_skill]
	var caster = aiming_caster()
	if not skill.affects_both_sides:
		# A skill that affects both sides can be aimed at anyone; otherwise
		# targets_ally decides which side is legal.
		var right_side = target.side == caster.side if skill.targets_ally else target.side != caster.side
		if not right_side:
			return false
	var aimed: Vector2i = tile if tile != null else combat.nearest_tile_of(target, caster.position)
	if skill.respects_blocking and not combat.has_line_of_sight(combat.nearest_tile_of(caster, aimed), aimed, caster.movement_class,
			caster.get("size", Sizes.Size.HUMAN), target):
		return false
	return true


## Where a click on `comb`'s face aims: the tile of theirs in reach and in
## sight nearest the caster, for somebody bigger than a tile - their own tile
## for anybody else.
func face_aim_tile(comb: Dictionary) -> Vector2i:
	var tiles: Array = combat.tiles_of(comb)
	if tiles.size() <= 1:
		return comb.position
	var caster = aiming_caster()
	var best: Vector2i = combat.nearest_tile_of(comb, caster.position)
	var best_gap := 999999
	for tile in tiles:
		if tile in _range_preview_positions:
			var gap: int = combat.distance_to(caster, tile)
			if gap < best_gap:
				best_gap = gap
				best = tile
	return best


const grid_tex = preload("res://art/ui/grid_marker.png")

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


## --- How the map is marked ---
##
## An area is a soft fill with its outline drawn, rather than a stack of solid
## markers: the reach of a skill used to be a strong red wash over everything
## it covered, and hid the very map it was being aimed across. Each thing has
## its own colour, so none is mistaken for another - red is kept for danger.

const RANGE_FILL := Color(0.45, 0.68, 1.0, 0.24)
const RANGE_EDGE := Color(0.55, 0.78, 1.0, 0.85)
const DECLARED_ENEMY_FILL := Color(1.0, 0.42, 0.1, 0.26)
const DECLARED_ENEMY_EDGE := Color(1.0, 0.5, 0.15, 0.9)
const DECLARED_ALLY_FILL := Color(1.0, 0.84, 0.3, 0.2)
const DECLARED_ALLY_EDGE := Color(1.0, 0.84, 0.3, 0.8)
const READIED_AREA_FILL := Color(0.62, 0.42, 1.0, 0.18)
const READIED_AREA_EDGE := Color(0.72, 0.55, 1.0, 0.9)
## What Intuition read (Combat "Reading intent"): where the blow will land, and
## where they will stand to throw it.
## What Intuition read: strong enough to stand out over the tint under whoever
## stands there, and outlined thick.
const INTENT_FILL := Color(0.15, 0.95, 0.85, 0.42)
const INTENT_EDGE := Color(0.4, 1.0, 0.95, 1.0)
const INTENT_WIDTH := EDGE_WIDTH * 2.0
## A death in the vision: whoever the read blow would knock out, in red, with a
## skull over them (Combat.foreseen_doom).
const DOOM_FILL := Color(0.95, 0.12, 0.12, 0.45)
const DOOM_EDGE := Color(1.0, 0.25, 0.2, 1.0)
const SKULL_BONE := Color(0.97, 0.95, 0.9, 0.95)
const SKULL_SHADOW := Color(0.12, 0.02, 0.02, 0.95)

const FutureShards := preload("res://control/FutureShards.gd")
## The ways out a broken enemy runs for (Combat "Getting away"): faint all
## fight, bright while somebody is running for one.
const ESCAPE_FILL := Color(0.95, 0.85, 0.3, 0.12)
const ESCAPE_EDGE := Color(0.95, 0.85, 0.3, 0.45)
const ESCAPE_FILL_RUNNING := Color(1.0, 0.85, 0.25, 0.3)
const ESCAPE_EDGE_RUNNING := Color(1.0, 0.85, 0.25, 0.95)
## The parts of somebody big (Combat "Body parts"): each in the colour of what
## breaking it does, so legs and arms side by side read apart; grey once broken.
const PART_COLOURS := {
	BodyPartDefinition.Broken.ROOTED: Color("6fb7ff"),
	BodyPartDefinition.Broken.WEAKENED: Color("ffd166"),
	BodyPartDefinition.Broken.EXPOSED: Color("ff6b6b"),
	BodyPartDefinition.Broken.STAGGERED: Color("c38bff"),
	BodyPartDefinition.Broken.DISARMED: Color("ff9f43"),
}
const PART_BROKEN_COLOUR := Color(0.55, 0.5, 0.45)
## How big a part's name is written on it, against a tile.
const PART_NAME_SIZE := 0.16
## The arena's (Combat "The arena"): what comes down next round, and bad ground.
const HAZARD_WARNING_FILL := Color(0.85, 0.25, 0.85, 0.22)
const HAZARD_WARNING_EDGE := Color(0.95, 0.4, 0.95, 0.9)
const BAD_GROUND_FILL := Color(0.75, 0.15, 0.3, 0.32)
const BAD_GROUND_EDGE := Color(0.9, 0.25, 0.35, 0.8)
## The party's traps (Combat "Traps"), seen only by them: a dull bronze.
const TRAP_FILL := Color(0.7, 0.55, 0.25, 0.3)
const TRAP_EDGE := Color(0.85, 0.65, 0.3, 0.85)
## Zones on the ground (Combat "Zones"): the party's, and the other side's.
const ZONE_ALLY_FILL := Color(0.95, 0.85, 0.45, 0.16)
const ZONE_ALLY_EDGE := Color(1.0, 0.9, 0.5, 0.7)
const ZONE_FOE_FILL := Color(0.9, 0.3, 0.25, 0.16)
const ZONE_FOE_EDGE := Color(1.0, 0.4, 0.3, 0.7)
## The tiles somebody stands on, lightly, by whose they are: the party's (and
## whoever fights for it), the other side's, and things on the battlefield.
const STANDING_ALLY_FILL := Color(0.35, 0.6, 1.0, 0.14)
const STANDING_ALLY_EDGE := Color(0.45, 0.7, 1.0, 0.35)
const STANDING_FOE_FILL := Color(1.0, 0.3, 0.3, 0.14)
const STANDING_FOE_EDGE := Color(1.0, 0.4, 0.4, 0.35)
const STANDING_NEUTRAL_FILL := Color(0.9, 0.85, 0.6, 0.12)
const STANDING_NEUTRAL_EDGE := Color(0.95, 0.9, 0.65, 0.3)
## An aura's reach: faint, since it is on the map for the whole fight.
const AURA_FOE_FILL := Color(0.6, 0.3, 0.9, 0.1)
const AURA_FOE_EDGE := Color(0.7, 0.45, 1.0, 0.45)
const AURA_ALLY_FILL := Color(0.35, 0.75, 1.0, 0.08)
const AURA_ALLY_EDGE := Color(0.45, 0.8, 1.0, 0.4)
const BLAST_FILL := Color(1.0, 0.45, 0.2, 0.42)
const BLAST_EDGE := Color(1.0, 0.62, 0.3, 0.95)
const HELP_FILL := Color(0.4, 0.9, 0.45, 0.35)
const HELP_EDGE := Color(0.5, 1.0, 0.55, 0.9)
const WATCHED_FILL := Color(0.62, 0.38, 0.9, 0.22)
const WATCHED_EDGE := Color(0.72, 0.5, 1.0, 0.7)
const DANGER_FILL := Color(0.9, 0.18, 0.15)
const REACTION_EDGE := Color(1.0, 0.62, 0.2, 0.95)
const HIGHLIGHT_EDGE := Color(1.0, 0.84, 0.35, 0.95)
const EDGE_WIDTH := 6.0


func _tile_rect(tile: Vector2i) -> Rect2:
	return Rect2(tile_map.map_to_local(tile) - Grid.HALF_TILE, Grid.HALF_TILE * 2.0)


## A skull, `size` across, at `centre` - drawn rather than a picture, so it
## needs nothing shipped.
func _draw_skull(centre: Vector2, size: float):
	var head := size * 0.5
	var top := centre + Vector2(0, -size * 0.12)
	draw_circle(top, head + 4.0, SKULL_SHADOW)
	draw_circle(top, head, SKULL_BONE)
	var jaw := Rect2(centre + Vector2(-head * 0.6, head * 0.45), Vector2(head * 1.2, head * 0.55))
	draw_rect(jaw.grow(4.0), SKULL_SHADOW)
	draw_rect(jaw, SKULL_BONE)
	draw_circle(top + Vector2(-head * 0.38, head * 0.05), head * 0.26, SKULL_SHADOW)
	draw_circle(top + Vector2(head * 0.38, head * 0.05), head * 0.26, SKULL_SHADOW)
	draw_colored_polygon(PackedVector2Array([top + Vector2(0, head * 0.3), top + Vector2(-head * 0.12, head * 0.55),
		top + Vector2(head * 0.12, head * 0.55)]), SKULL_SHADOW)
	for i in 3:
		var x := jaw.position.x + jaw.size.x * (0.25 + 0.25 * i)
		draw_line(Vector2(x, jaw.position.y), Vector2(x, jaw.end.y), SKULL_SHADOW, 3.0)


## The marks of a foreseen turn breaking apart over `tiles` (Combat._future_changed).
func shatter_future(tiles: Array):
	if tiles.is_empty():
		return
	var shards := FutureShards.new()
	shards.name = "FutureShards"
	shards.fill = INTENT_FILL
	shards.edge = INTENT_EDGE
	shards.width = INTENT_WIDTH
	shards.setup(tiles.map(func(tile): return _tile_rect(tile)))
	add_child(shards)


## `tiles` as one area: each filled, and the outline drawn only where the area
## ends, so it reads as a shape rather than a grid of squares.
func _draw_area(tiles: Array, fill: Color, edge: Color, width: float = EDGE_WIDTH):
	var inside := {}
	for tile in tiles:
		inside[tile] = true
	for tile in tiles:
		var r = _tile_rect(tile)
		draw_rect(r, fill)
		if not inside.has(tile + Vector2i.UP):
			draw_line(r.position, Vector2(r.end.x, r.position.y), edge, width)
		if not inside.has(tile + Vector2i.DOWN):
			draw_line(Vector2(r.position.x, r.end.y), r.end, edge, width)
		if not inside.has(tile + Vector2i.LEFT):
			draw_line(r.position, Vector2(r.position.x, r.end.y), edge, width)
		if not inside.has(tile + Vector2i.RIGHT):
			draw_line(Vector2(r.end.x, r.position.y), r.end, edge, width)


## The tile the pointer was last over, for the parts it lights (_draw_parts).
var _hover_tile := Vector2i(-99999, -99999)


## The pointer has come onto `tile`: the board is drawn again if a part could
## light up or go dark for it.
func _note_hover(tile: Vector2i):
	if tile == _hover_tile:
		return
	_hover_tile = tile
	if combat != null and not combat.part_marks().is_empty():
		queue_redraw()


## Each part tinted in its colour (PART_COLOURS) and named on the board; the
## one under the pointer brighter and thicker-edged, a broken one grey and
## crossed out. All of them while aiming; otherwise only those of whoever the
## pointer is on.
## Under anybody holding a spell on a tether (Combat "Tethers"), what is left
## of it: a thin violet bar along the bottom of their square - for the
## other side's casters too, whose portraits are not on the HUD.
const TETHER_COLOUR := Color("9d7fe0")

func _draw_tether():
	for comb in combat.combatants:
		if not comb.get("alive", false) or not Combat.holds_tether(comb) or comb.has("riding"):
			continue
		if comb.get("side", 0) != 0 and combat.is_hidden(comb):
			continue
		var square := combat.rect_of(comb)
		var top_left := _tile_rect(square.position).position
		var bottom_right := _tile_rect(square.end - Vector2i.ONE).end
		var width := bottom_right.x - top_left.x
		var under := Rect2(Vector2(top_left.x + width * 0.1, bottom_right.y - 10.0), Vector2(width * 0.8, 6.0))
		draw_rect(under, Color(0.08, 0.06, 0.12, 0.85))
		var held: Dictionary = comb.tether
		var share := clampf(held.bar / maxf(held.max, 1.0), 0.0, 1.0)
		draw_rect(Rect2(under.position, Vector2(under.size.x * share, under.size.y)), TETHER_COLOUR)


func _draw_parts():
	var pointed = get_combatant_at_position(_hover_tile)
	# Aiming something with an area, no part is aimed at (Combat.aims_at_parts):
	# they are all shown, none lit.
	var aims_at_one: bool = not _skill_selected or combat.aims_at_parts(aiming_caster(), SkillDatabase.skills.get(_selected_skill))
	for mark in combat.part_marks():
		if not _skill_selected and (pointed == null or pointed.get("id", -1) != mark.id):
			continue
		var under: bool = aims_at_one and _hover_tile in mark.tiles
		var colour: Color = PART_BROKEN_COLOUR if mark.broken else PART_COLOURS.get(mark.kind, Color.WHITE)
		var fill := Color(colour, 0.4 if under else 0.16)
		var edge := Color(colour, 1.0 if under else 0.8)
		_draw_area(mark.tiles, fill, edge, EDGE_WIDTH * (2.0 if under else 1.0))
		if mark.broken:
			for tile in mark.tiles:
				var r := _tile_rect(tile).grow(-Grid.TILE_SIZE * 0.2)
				draw_line(r.position, r.end, edge, EDGE_WIDTH)
				draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), edge, EDGE_WIDTH)
		var text: String = mark.name + (" (broken)" if mark.broken else "")
		if under:
			# Under the pointer, what is left to break it and what that does.
			var note: String = combat.part_note(combat.combatant_with_id(mark.id), _hover_tile)
			if note != "":
				text = note
		_draw_part_name(mark, text, colour, under)


## `text` across the middle of `mark`'s tiles.
func _draw_part_name(mark: Dictionary, text: String, colour: Color, under: bool):
	var font := ThemeDB.fallback_font
	var size := int(Grid.TILE_SIZE * PART_NAME_SIZE * (1.15 if under else 1.0))
	var middle := Vector2.ZERO
	for tile in mark.tiles:
		middle += tile_map.map_to_local(tile)
	middle /= maxf(mark.tiles.size(), 1.0)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := middle + Vector2(-width / 2.0, size * 0.35)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, int(size * 0.25), Color(0, 0, 0, 0.85))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour.lightened(0.35))


## --- The danger view ---
##
## Held on Shift: every tile an enemy the player can see could reach and hit on
## its next turn, redder where more of them could, and an orange edge on every
## tile a player would set off somebody's reaction by stepping out of. Worked
## out once, when the key goes down - see Combat.threat_map.

var _showing_danger := false
var _danger: Dictionary = {}


func set_danger_view(on: bool):
	if on == _showing_danger:
		return
	_showing_danger = on
	_danger = combat.threat_map() if on and combat != null else {}
	var hud = combat.game_ui if combat != null else null
	if hud != null and hud.has_method("set_danger_legend"):
		hud.set_danger_legend(on)
	queue_redraw()


func is_showing_danger() -> bool:
	return _showing_danger


## What the danger view is showing: {"threat": {tile: count}, "reaction": {tile: true}}.
func danger() -> Dictionary:
	return _danger


func _notification(what):
	# Let go of Shift in another window and the key-up never arrives here.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		set_danger_view(false)


func _draw_danger():
	var threat: Dictionary = _danger.get("threat", {})
	for tile in threat:
		# The walls themselves say nothing - nobody stands in one.
		if _blocking_lookup[0].has(tile):
			continue
		var many: int = threat[tile]
		draw_rect(_tile_rect(tile), Color(DANGER_FILL, clampf(0.16 + 0.1 * float(many - 1), 0.16, 0.5)))
	for tile in _danger.get("reaction", {}):
		if _blocking_lookup[0].has(tile):
			continue
		draw_rect(_tile_rect(tile).grow(-12.0), REACTION_EDGE, false, 8.0)


## --- Pointing somebody out ---
##
## A gold outline on whoever the cursor is over in the turn queue or the party
## column, so a face on the HUD can be found on the map.

var _highlight_tile = null


func highlight_unit(comb: Dictionary):
	var hidden = not comb.is_empty() and comb.get("side", 0) != 0 and combat.is_hidden(comb)
	_highlight_tile = null if comb.is_empty() or not comb.get("alive", false) or hidden else combat.rect_of(comb)
	queue_redraw()


func clear_highlight():
	_highlight_tile = null
	queue_redraw()


## Asks the HUD to show the card for whoever `comb` is, or to put it away.
## Nobody hidden from the player is ever shown - it would say where they are.
func _card_for(comb):
	var hud = combat.game_ui if combat != null else null
	if hud == null or not hud.has_method("show_unit_card"):
		return
	if comb == null or comb.is_empty() or not comb.alive or (comb.side != 0 and combat.is_hidden(comb)):
		hud.hide_unit_card()
	else:
		hud.show_unit_card(comb)


func _draw():
	# Where everybody stands, under everything: blue for the party's side, red
	# for the other, pale gold for things on the battlefield - each one its own
	# shape, so two side by side, or one big, read as what they are. Nobody
	# hidden from the player is given away.
	if combat != null:
		for comb in combat.combatants:
			if not comb.get("alive", false) or (comb.get("side", 0) != 0 and combat.is_hidden(comb)):
				continue
			var tiles: Array = combat.tiles_of(comb)
			if tiles.is_empty():
				continue
			if comb.has("object"):
				_draw_area(tiles, STANDING_NEUTRAL_FILL, STANDING_NEUTRAL_EDGE)
			elif comb.get("side", 0) == 0:
				_draw_area(tiles, STANDING_ALLY_FILL, STANDING_ALLY_EDGE)
			else:
				_draw_area(tiles, STANDING_FOE_FILL, STANDING_FOE_EDGE)
	# Auras, faintest and underneath everything else: violet where the other
	# side's reaches, blue for the party's own.
	if combat != null:
		for aura in combat.aura_tiles():
			_draw_area(aura.tiles, AURA_FOE_FILL if aura.hostile else AURA_ALLY_FILL,
				AURA_FOE_EDGE if aura.hostile else AURA_ALLY_EDGE)
		# The arena: bad ground in red, and what is about to happen in magenta.
		_draw_area(combat.bad_ground_tiles(), BAD_GROUND_FILL, BAD_GROUND_EDGE)
		_draw_area(combat.hazard_warning_tiles(), HAZARD_WARNING_FILL, HAZARD_WARNING_EDGE)
		# The party's own traps, which nobody else can see.
		_draw_area(combat.trap_tiles(), TRAP_FILL, TRAP_EDGE)
		# Zones left on the ground: the party's in pale gold, the other side's in
		# warning red.
		for zone in combat.zone_tiles():
			_draw_area(zone.tiles, ZONE_FOE_FILL if zone.hostile else ZONE_ALLY_FILL,
				ZONE_FOE_EDGE if zone.hostile else ZONE_ALLY_EDGE)
	# Where declared moves will come down (Combat.declare): the other side's in
	# warning orange, the party's own in gold.
	if combat != null:
		for comb in combat.combatants:
			if comb.alive and comb.has("declared"):
				var hostile: bool = comb.side != 0
				_draw_area(comb.declared.tiles, DECLARED_ENEMY_FILL if hostile else DECLARED_ALLY_FILL,
					DECLARED_ENEMY_EDGE if hostile else DECLARED_ALLY_EDGE)
			# An area a readied move watches (Combat "Ready"), in violet: step in
			# and it goes off.
			if comb.alive and not comb.get("readied", {}).get("area", []).is_empty():
				_draw_area(comb.readied.area, READIED_AREA_FILL, READIED_AREA_EDGE, INTENT_WIDTH)
		# What Intuition read: the blow's tiles filled, the tile they will stand
		# on outlined, and a line from where they are to it.
		for mark in combat.intent_marks():
			_draw_area(mark.tiles, INTENT_FILL, INTENT_EDGE, INTENT_WIDTH)
			var square := []
			for dx in mark.shape.x:
				for dy in mark.shape.y:
					square.append(mark.stand + Vector2i(dx, dy))
			if mark.stand != mark.from:
				var half: Vector2 = Vector2(mark.shape - Vector2i.ONE) * Grid.HALF_TILE
				draw_line(tile_map.map_to_local(mark.from) + half, tile_map.map_to_local(mark.stand) + half, INTENT_EDGE, INTENT_WIDTH)
			_draw_area(square, Color(INTENT_FILL, INTENT_FILL.a * 0.5), INTENT_EDGE, INTENT_WIDTH)
			# A death in the vision: red over whoever it would finish, and a skull.
			for victim_tiles in mark.get("doomed", []):
				_draw_area(victim_tiles, DOOM_FILL, DOOM_EDGE, INTENT_WIDTH)
				# In the corner rather than the middle, where whoever stands
				# there would be drawn over it.
				var skull := Grid.HALF_TILE.x * 0.6
				_draw_skull(_tile_rect(victim_tiles[0]).position + Vector2.ONE * (skull * 0.7), skull)
		# The ways out, each its own square: brighter while somebody runs for one.
		if not combat.escape_points.is_empty():
			var running: bool = combat.combatants.any(func(comb): return comb.alive and comb.get("fleeing", 0) > 0)
			for tile in combat.escape_points:
				_draw_area([tile], ESCAPE_FILL_RUNNING if running else ESCAPE_FILL,
					ESCAPE_EDGE_RUNNING if running else ESCAPE_EDGE)
	# The parts of anybody big that can be aimed at and broken (Combat "Body
	# parts"): while aiming, and while the pointer is on whoever has them.
	if combat != null:
		_draw_parts()
		_draw_tether()
	# Where to climb, and who is on another floor (Combat "Heights").
	if combat != null and combat.heights_in_play():
		_draw_ladders()
		if combat._floored:
			_draw_ghosts()
	if _showing_danger:
		_draw_danger()
	if _highlight_tile != null:
		var whole := Rect2(_tile_rect(_highlight_tile.position).position, _tile_rect(_highlight_tile.end - Vector2i.ONE).end - _tile_rect(_highlight_tile.position).position)
		draw_rect(whole.grow(-6.0), HIGHLIGHT_EDGE, false, 10.0)
	if _deployment_active:
		# Where the party may stand, and which of them is currently picked up.
		for tile in _deployment_tiles:
			_draw_tile_marker(tile_map.map_to_local(tile), Color(Color.GOLD, 0.45))
		if _deployment_selection != null:
			_draw_tile_marker(tile_map.map_to_local(_deployment_selection.position), Color(Color.WHITE, 0.85))
		return
	if _stepping:
		# Where a step after striking could go (choose_step).
		_draw_area(_step_tiles, RANGE_FILL, RANGE_EDGE)
		return
	if _arrived == true and player_turn == true:
		# Where the enemy is looking, for somebody whose turn depends on not
		# being looked at. Drawn under everything else, since it is the ground
		# the rest of the turn is planned on rather than a choice being made.
		if not _watched_tiles.is_empty():
			_draw_area(_watched_tiles, WATCHED_FILL, WATCHED_EDGE)
		if _skill_selected:
			_draw_area(_range_preview_positions, RANGE_FILL, RANGE_EDGE)
		else:
			var path_length = movement
			for i in range(_path.size()):
				var point = _path[i]
				if i > 0:
					var walker = combat.get_current_combatant()
					path_length -= get_tile_cost_at_point(point) * combat.drag_cost(walker) * combat.hem_cost(walker, tile_map.local_to_map(point))
				var draw_color = Color.WHITE
				if path_length >= 0:
					draw_color = Color.ROYAL_BLUE
				_draw_tile_marker(point, draw_color)
		if _attack_target_position != null:
			_draw_tile_marker(_attack_target_position, Color.CRIMSON)
		if _ally_target_position != null:
			_draw_tile_marker(_ally_target_position, Color.LIME_GREEN)
		if not _aoe_preview_positions.is_empty():
			if _aoe_preview_is_ally:
				_draw_area(_aoe_preview_positions, HELP_FILL, HELP_EDGE)
			else:
				_draw_area(_aoe_preview_positions, BLAST_FILL, BLAST_EDGE)
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


## --- A step after striking ---
##
## A path that steps away after a strike (PassiveDefinition.step_after, the
## Swashbuckler's) asks here, once the strike has landed: the tiles it could
## step to are marked, a click on one steps there - nothing provoked, since
## Combat.teleport_to provokes nothing - and Escape, a right click, or a click
## on their own tile stays put.

var _stepping := false
var _step_tiles: Array = []
var _step_choice = NO_TILE


## Marks `tiles` for `comb` to step to and waits for the choice. Answers the
## tile chosen, or their own to stay. `what` is what the log says they can do:
## step away (the Swashbuckler's), or step after them (Tremor's).
func choose_step(comb: Dictionary, tiles: Array, what: String = "can step away") -> Vector2i:
	_step_tiles = tiles.duplicate()
	_step_choice = comb.position
	_stepping = true
	combat.update_information.emit("[color=yellow]%s[/color] %s: pick a marked tile, or press %s to stay.\n" % [
		comb.name, what, Pad.key(&"ui_cancel", "Escape")])
	queue_redraw()
	while _stepping and is_inside_tree() and combat.still_running():
		await get_tree().process_frame
	_stepping = false
	_step_tiles = []
	queue_redraw()
	return _step_choice


func is_stepping() -> bool:
	return _stepping


## Steps to `tile`, if it is one of those marked; anything else stays put.
func step_to(tile: Vector2i):
	if not _stepping:
		return
	if _step_tiles.has(tile):
		_step_choice = tile
	_stepping = false


## Stays where they are.
func stay_put():
	_stepping = false


func _handle_step_input(event):
	if event.is_action_pressed(&"ui_cancel"):
		stay_put()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.is_released():
		if event.button_index == MOUSE_BUTTON_RIGHT:
			stay_put()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var tile := tile_map.local_to_map(_pointed_at())
			if _step_tiles.has(tile) or tile == _step_choice:
				step_to(tile)


## --- Room to move, by size ---
##
## The pathfinding grid is decided per tile for whoever is acting. Somebody
## bigger than a tile is walked by their anchor - the top left of the square
## they cover - so a tile is open to them only where the whole square would fit:
## nothing in the way under any of it, and nobody but them. Worked out with a
## summed-area table so a Gigantic one does not cost a check per tile of its
## square per tile of the map. Somebody smaller than a tile may step onto a
## tile their own side's small ones share, while there is room.

## Opens and closes every point for `comb`, bigger than a tile, by whether the
## square anchored there fits.
func _fit_points_to_big(comb: Dictionary):
	var region: Rect2i = _astargrid.region
	var width := region.size.x
	var height := region.size.y
	# A flier passes over others; something only too big for the walls does not.
	var flier: bool = comb.movement_class == 1
	var ground: int = Combat.terrain_class(comb)
	# blocked[y][x] in a flat array, then summed so any square's count is four
	# reads.
	var sums := PackedInt32Array()
	sums.resize((width + 1) * (height + 1))
	for y in height:
		var row := 0
		for x in width:
			var tile := region.position + Vector2i(x, y)
			# High ground underfoot is no wall to somebody big enough to step over it.
			var blocked: bool = is_tile_blocking(tile, ground) and combat.blocks_for(comb, tile)
			if not blocked and not flier and _occupied_spaces.has(tile) and not combat.covers(comb, tile):
				blocked = true
			row += 1 if blocked else 0
			sums[(y + 1) * (width + 1) + x + 1] = sums[y * (width + 1) + x + 1] + row
	var shape := Combat.footprint(comb)
	for y in height:
		for x in width:
			var tile := region.position + Vector2i(x, y)
			var fits := x + shape.x <= width and y + shape.y <= height
			if fits:
				var bottom := (y + shape.y) * (width + 1)
				var top := y * (width + 1)
				var count := sums[bottom + x + shape.x] - sums[bottom + x] - sums[top + x + shape.x] + sums[top + x]
				fits = count == 0
			if tile == comb.position:
				fits = true
			_astargrid.set_point_solid(tile, not fits)
			_astargrid.set_point_weight_scale(tile, 1 if fits else INF)


## Opens the tiles `comb`, smaller than a tile, could share.
func _fit_points_to_small(comb: Dictionary):
	if comb.movement_class == 1:
		return
	for tile in _occupied_spaces:
		if tile == comb.position or is_tile_blocking(tile, comb.movement_class):
			continue
		var fits := combat.room_for(comb, tile)
		_astargrid.set_point_solid(tile, not fits)
		_astargrid.set_point_weight_scale(tile, 1 if fits else INF)


## get_reachable_tiles for somebody bigger or smaller than a tile: every anchor
## they could walk to within `budget`, each step one they fit (Combat.room_for),
## costing what the tile they step onto costs.
func _reachable_by_size(mover: Dictionary, start: Vector2i, budget: int) -> Dictionary:
	const NEIGHBOR_OFFSETS = [
		Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN,
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
	]
	var hemmed: Dictionary = combat.hemmed_tiles(mover)
	var costs := {start: 0}
	var frontier := [start]
	while not frontier.is_empty():
		var best := 0
		for i in range(1, frontier.size()):
			if costs[frontier[i]] < costs[frontier[best]]:
				best = i
		var current: Vector2i = frontier[best]
		frontier.remove_at(best)
		for offset in NEIGHBOR_OFFSETS:
			var neighbor: Vector2i = current + offset
			if not combat.room_for(mover, neighbor):
				continue
			var cost: int = costs[current] + get_tile_cost_for_class(neighbor, Combat.terrain_class(mover)) * (2 if hemmed.has(neighbor) else 1)
			if cost > budget:
				continue
			if not costs.has(neighbor) or cost < costs[neighbor]:
				costs[neighbor] = cost
				frontier.append(neighbor)
	return costs
