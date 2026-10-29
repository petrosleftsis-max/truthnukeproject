extends Node
class_name ExplorationScene
## Root of exploration mode: loads a map, puts the party in it, and drives
## walking, interacting and the hand-off to and from battles.
##
## Exploration is the hub - battles start from here and come back to here. The
## map to load and where to stand in it live on Campaign, so they survive the
## scene change into a battle and out again.
##
## Like GameScene, this builds its map in _enter_tree rather than _ready:
## _enter_tree runs top-down but _ready bottom-up, so a parent's _ready fires
## after its children's, and the children need the map already there.


## Loaded when Campaign has no map set - running this scene straight from the
## editor, for instance.
@export_file("*.tscn") var default_map: String = "res://maps/crossroads_explore.tscn"
## Who is in the party at the start of a run, in marching order - the first one
## leads. Edit this to add or remove teammates; they need to exist in
## CombatantDatabase first. Only used to seed Campaign.party_order the first
## time, so it doesn't overwrite a party the player has since reordered.
@export var starting_party: Array[String] = ["enfina", "cyrus", "prometheus"]
## Where an encounter trigger sends the party.
@export_file("*.tscn") var battle_scene: String = "res://scenes/game.tscn"
@export var game_ui: Control
@export var camera: Camera2D

const MAP_NODE = "Map"
const PARTY_NODE = "Party"

## The party walking the map - in co-op, the group of whoever's press is being
## handled (Coop.acting), else the first player's: so everything a press does,
## through all the code that has only ever known one party, is done by the
## player who pressed (see "Co-op").
var party: ExplorationParty:
	get:
		return _acting_group()
	set(value):
		_main_party = value
## The first player's group - everybody's, outside co-op.
var _main_party: ExplorationParty = null
var _tile_map: TileMap = null
var _blocking: Dictionary = {}
var _interactables: Array = []
var _current_target: Interactable = null
var _blocking_interaction := false
## The guards' side of a stealth map, or null on any other map.
var stealth: StealthWatch = null


func _enter_tree():
	_build_map()


func _ready():
	# Walking about, as far as a pad's pointer is concerned - see Pad.
	add_to_group(&"pad_walk")
	Pad.changed.connect(_update_prompt)
	# The map's own cast wins where it has one: a map that names its party is
	# stating who is there at that point in the story, while Starting Party is
	# only a fallback for a map that says nothing (and for running one straight
	# from the editor).
	var setup = _map_setup()
	# In a dungeon the party and what it carries are the dungeon's, from one
	# map to the next: a map's own cast and kit are where its story has them.
	var in_dungeon := Campaign.in_dungeon()
	if in_dungeon:
		pass
	elif setup != null and setup.is_set():
		Campaign.set_party(setup.members, setup.level)
	else:
		Campaign.seed_party(starting_party)
	# Back from a fight on this map, the party walks in with what it left with.
	# Emptying the bags and handing the kit out again is for arriving: done on
	# the way back, it took whatever had been picked up or lifted here since.
	var coming_back = Campaign.return_to_position
	var keep_bags = coming_back or in_dungeon
	if setup != null and setup.empty_handed and not keep_bags:
		# Before the story has given anybody anything. Done after the party is
		# set, so it empties the bags of whoever is actually here.
		for key in Campaign.living_party():
			Campaign.empty_inventory(key)
	if setup != null and setup.hands_kit_out() and not keep_bags:
		# After emptying, so a map that wants the party holding exactly this and
		# nothing else can set both and get it.
		for key in Campaign.living_party():
			for item in setup.kit_for(key):
				Campaign.give_item(key, item)
	if setup != null and setup.music != "":
		# Starting the track already playing does nothing, so stepping out to a
		# fight and back does not restart the map's music from the top.
		Music.play(setup.music)
	# A conversation can recruit someone or send them away mid-map (see
	# Campaign.add_member), so the line and the portraits rebuild themselves
	# whenever the roster changes rather than only on arrival.
	if not Campaign.party_changed.is_connected(_on_party_changed):
		Campaign.party_changed.connect(_on_party_changed)
	# A level reached, or somebody joining at one, can mean a path to choose.
	if not Campaign.party_leveled.is_connected(_on_party_leveled):
		Campaign.party_leveled.connect(_on_party_leveled)
	_paths_due = true
	if not Campaign.store_requested.is_connected(_on_store_requested):
		Campaign.store_requested.connect(_on_store_requested)
	_spawn_party()
	# The familiar's keeper, on every map (Find Familiar - FamiliarKeeper).
	familiar_keeper = FamiliarKeeper.new()
	familiar_keeper.name = "FamiliarKeeper"
	familiar_keeper.scene = self
	add_child(familiar_keeper)
	begin_stealth()
	# Walked onto a stealth map rather than back onto it from a fight: how
	# things stand now is where Restart Stage goes back to. So too arriving by
	# a load, which comes back with no checkpoint at all.
	if stealth != null and (not coming_back or Campaign.stealth_checkpoint.get("map", "") != map_path()):
		Campaign.save_stealth_checkpoint(map_path(), party.position_of_leader())
	if game_ui != null and game_ui.has_method("set_exploration_mode"):
		game_ui.set_exploration_mode(true)
	if game_ui != null and game_ui.has_method("show_outside_moves"):
		moves_panel = OutsideMovesPanel.new()
		moves_panel.scene = self
		game_ui.show_outside_moves(moves_panel)
	_refresh_party_panel()
	_update_prompt()
	# Anything automatic the party has arrived standing on fires now rather than
	# on their first step. "Activates when the player gets in range" has to
	# include arriving already in range, which is exactly where you put the
	# conversation that opens a map.
	#
	# Deferred so the map has finished coming up before a conversation starts
	# over the top of it.
	_check_contact_triggers.call_deferred(party_position())


## Someone joined or left. Rebuild the walking line where the party currently
## stands, so a new recruit falls in behind rather than the party jumping back
## to the map's entry point.
func _on_party_changed():
	_paths_due = true
	if party == null or not is_inside_tree() or _passing_lead:
		return
	var from := _lead_from if _lead_from != NOWHERE else party_position()
	var leading := party
	_lead_from = NOWHERE
	if Coop.on():
		_build_groups(leading, from)
	else:
		_main_party.setup(_party_textures(), from, is_walkable)
	_keep_stayers()
	_refresh_party_panel()


## Redraws the portrait column down the left. Called whenever the party's
## make-up or order changes - on arrival, and after passing the lead.
func _refresh_party_panel():
	if game_ui != null and game_ui.has_method("show_exploration_party"):
		game_ui.show_exploration_party(Campaign.party_members())


func map_path() -> String:
	return Campaign.current_map if Campaign.current_map != "" else default_map


func party_position() -> Vector2:
	return party.position_of_leader() if party != null else Vector2.ZERO


## Sends the current map's message to the shared Information log, so examining
## things reads the same as combat events do.
func log_message(text: String):
	if game_ui != null and game_ui.has_method("update_information"):
		game_ui.update_information(text)


func _build_map():
	var path = map_path()
	if not ResourceLoader.exists(path):
		push_error("Exploration map '%s' doesn't exist." % path)
		return
	var map = load(path).instantiate()
	map.name = MAP_NODE
	add_child(map)
	move_child(map, 0)
	_tile_map = map.get_node_or_null("TileMap")
	if _tile_map == null:
		# The map may be a plain wrapper around a terrain scene instance.
		for child in map.get_children():
			var found = child.get_node_or_null("TileMap")
			if found != null:
				_tile_map = found
				break
	# The camera's own path only reaches a TileMap straight under the map.
	if _tile_map != null and camera != null and camera.has_method("use_tile_map"):
		camera.use_tile_map(_tile_map)
	# Most terrain scenes save their grid overlay hidden and the encounter
	# editor turns it on while placing units, but a couple of maps were authored
	# without it switched off and carry a visible grid. Exploration is not
	# played on tiles as far as the player is concerned - they walk about
	# freely - so the mode settles it here rather than every map having to
	# remember. The scene on disk is untouched, so the grid is still there to
	# lay things out against in the editor.
	_hide_grid(map)
	_build_blocking()
	_interactables = []
	_collect_interactables(map)
	_collect_walls(map)
	# Gaps placed as nodes, on a map whose tileset paints none (SmallGap).
	if _tile_map != null:
		for gap in map.find_children("*", "SmallGap", true, false):
			set_small_gap(_tile_map.local_to_map(_tile_map.to_local(gap.global_position)), true)
	_traps = map.find_children("*", "MagicTrap", true, false)
	for trap in _traps:
		trap.armed = not Campaign.flag(trap.flag_for(map_path()))
	# Dialogue can walk people about this map now, and anything it was walking
	# on the last one is gone with it.
	Actors.use_scene(self, _tile_map)


## Switches off any grid overlay the map brought with it, wherever it sits -
## a map may be a plain wrapper around a terrain scene, so the grid is not
## always a direct child.
func _hide_grid(node: Node):
	for child in node.get_children():
		if child is GridOverlay:
			child.visible = false
		else:
			_hide_grid(child)


## Which tiles the party can't walk on. Built once from the same "Blocks"
## custom data combat reads, so the two modes can never disagree about where a
## wall is. Unpainted cells count as blocked for the same reason they do in
## combat: there's no ground there.
func _build_blocking():
	_blocking.clear()
	_blocking_fliers.clear()
	_small_gaps.clear()
	if _tile_map == null:
		return
	var used = _tile_map.get_used_rect()
	for x in range(used.position.x, used.position.x + used.size.x):
		for y in range(used.position.y, used.position.y + used.size.y):
			var tile = Vector2i(x, y)
			var data = _tile_map.get_cell_tile_data(0, tile)
			if data == null:
				_blocking[tile] = true
				_blocking_fliers[tile] = true
				continue
			var blocks = data.get_custom_data("Blocks")
			if 0 in blocks:
				_blocking[tile] = true
			if 1 in blocks:
				_blocking_fliers[tile] = true
			if SMALL_GAP in blocks:
				_small_gaps[tile] = true


## Whether the party may stand at this world position. Outside the map counts
## as blocked, which is what keeps them on the board.
func is_walkable(world_position: Vector2) -> bool:
	if _tile_map == null:
		return true
	var tile = _tile_map.local_to_map(world_position)
	if not _tile_map.get_used_rect().has_point(tile):
		return false
	# Flying (Fly - OutsideMoves), over whatever stops only walkers.
	var walls: Dictionary = _blocking_fliers if flying() else _blocking
	return not walls.has(tile) and not _shut.has(tile) and not _small_gaps.has(tile)


## --- Small gaps ---
##
## A gap only something Small or smaller fits through - a grate, a drain, a hole
## under a fence: a tile whose Blocks carries SMALL_GAP (4) beside what it stops,
## or one opened by set_small_gap. Nobody in the party gets through one; a
## familiar does (Find Familiar - StealthWatch "Familiar"). A flier goes by what
## stops fliers (Blocks 1) rather than walkers.

## The value a tile's Blocks data carries to say "only Small or smaller fit
## through": [0, 4] is a wall to everybody but the small.
const SMALL_GAP := 4

## Tiles that stop fliers - the 1s in Blocks.
var _blocking_fliers: Dictionary = {}
## The small gaps, as a set.
var _small_gaps: Dictionary = {}


## Makes `tile` a small gap, or a wall to the small again - for a placed
## SmallGap, a map's script or a test; a painted one is in the tile's Blocks.
func set_small_gap(tile: Vector2i, gap: bool):
	if gap:
		_small_gaps[tile] = true
	else:
		_small_gaps.erase(tile)


func is_small_gap(tile: Vector2i) -> bool:
	return _small_gaps.has(tile)


## Whether something of `size` getting about by `movement_class` (0 on foot, 1
## flying) may be at this world position: a small gap if it is Small or smaller,
## and otherwise whatever stops its movement class - and a shut door, always.
func is_walkable_for(world_position: Vector2, size: int, movement_class: int = 0) -> bool:
	if _tile_map == null:
		return true
	var tile = _tile_map.local_to_map(world_position)
	if not _tile_map.get_used_rect().has_point(tile) or _shut.has(tile):
		return false
	if _small_gaps.has(tile):
		return size <= Sizes.Size.SMALL
	return not (_blocking_fliers if movement_class == 1 else _blocking).has(tile)


## Tiles shut for now - a closed door - on top of the painted walls. Not in
## _blocking, so the routes worked out for guards and conversations still run
## through them: a guard has the key to his own doors.
var _shut := {}


## Shuts `tile` to the party, or opens it again.
func set_tile_shut(tile: Vector2i, shut: bool):
	if shut:
		_shut[tile] = true
	else:
		_shut.erase(tile)


func _collect_interactables(node: Node):
	if node is Interactable:
		_interactables.append(node)
	for child in node.get_children():
		_collect_interactables(child)


func _spawn_party():
	party = ExplorationParty.new()
	_main_party.name = PARTY_NODE
	add_child(_main_party)
	_main_party.setup(_party_textures(), _start_position(), is_walkable)
	_main_party.moved.connect(_on_party_moved)
	if Coop.on():
		_build_groups(_main_party, _main_party.position_of_leader())
	if not Coop.players_changed.is_connected(_on_players_changed):
		Coop.players_changed.connect(_on_players_changed)
	_follow_camera(_main_party.position_of_leader())


## What everyone still standing looks like, leader first - straight off the
## campaign roster, so the line on the map is exactly the party you would
## field. Each entry carries both the still and the animation set, because the
## party walks with the same SpriteFrames it fights with.
func _party_textures() -> Array:
	if Coop.on():
		return _looks_of(Coop.keys_of(_first_player()))
	var looks = []
	for member in Campaign.party_members():
		looks.append({"key": member.key, "map_sprite": member.map_sprite, "sprite_frames": member.sprite_frames})
	if looks.is_empty():
		# Everyone is down, but there still has to be something to walk with.
		for key in Campaign.party_order:
			if CombatantDatabase.combatants.has(key):
				var definition = CombatantDatabase.combatants[key]
				looks.append({"key": key, "map_sprite": definition.map_sprite, "sprite_frames": definition.sprite_frames})
				break
	return looks


## Coming back from a battle puts the party exactly where they left; arriving
## through a door uses the entry point that door named; anything else uses the
## map's first entry point.
func _start_position() -> Vector2:
	if Campaign.return_to_position:
		Campaign.return_to_position = false
		return Campaign.return_position
	var entries = []
	_collect_entries(get_node_or_null(MAP_NODE), entries)
	if entries.is_empty():
		var ground = _first_standable_position()
		push_warning("Exploration map '%s' has no EntryPoint - starting the party on the first ground found, at %s. Add one to say where they should arrive." % [map_path(), ground])
		return ground
	if Campaign.target_entry != "":
		for entry in entries:
			if entry.entry_name == Campaign.target_entry:
				Campaign.target_entry = ""
				return entry.position
		push_warning("Map '%s' has no entry point named '%s' - using its first one." % [map_path(), Campaign.target_entry])
		Campaign.target_entry = ""
	return entries[0].position


## Somewhere on this map the party can actually stand, for a map with no
## EntryPoint to fall back to.
##
## The origin used to be that fallback, which only ever worked by luck: it is
## the corner of the coordinate system, not a promise of walkable ground. The
## moment a map gains a border of solid rock, or simply does not start at tile
## zero, the party arrives sealed inside a wall with every direction blocked -
## which looks exactly like movement being broken.
##
## Checked at the same four corners the party itself uses, so a tile picked
## here is one it can genuinely occupy rather than merely the centre of.
func _first_standable_position() -> Vector2:
	if _tile_map == null:
		return Vector2.ZERO
	var radius = ExplorationParty.new().body_radius
	var used = _tile_map.get_used_rect()
	for y in range(used.position.y, used.position.y + used.size.y):
		for x in range(used.position.x, used.position.x + used.size.x):
			var centre = _tile_map.map_to_local(Vector2i(x, y))
			var clear = true
			for offset in [
				Vector2(-radius, -radius), Vector2(radius, -radius),
				Vector2(-radius, radius), Vector2(radius, radius)
			]:
				if not is_walkable(centre + offset):
					clear = false
					break
			if clear:
				return centre
	push_error("Exploration map '%s' has nowhere the party can stand at all." % map_path())
	return Vector2.ZERO


func _collect_entries(node: Node, into: Array):
	if node == null:
		return
	if node is EntryPoint:
		into.append(node)
	for child in node.get_children():
		_collect_entries(child, into)


func _on_party_moved(leader_position: Vector2):
	if not groups.is_empty():
		_group_moved(leader_position, _main_party)
		return
	_follow_camera(leader_position)
	_update_prompt()
	_check_contact_triggers(leader_position)
	_pick_up_stayers(leader_position)


func _follow_camera(leader_position: Vector2):
	if camera == null:
		return
	if _frame_groups():
		return
	camera.position = leader_position
	if camera.has_method("clamp_to_map"):
		# The battle camera's clamping: the middle of the view stays on the
		# map, so the leader is kept in the middle of the screen right up to
		# its edge rather than pushed out towards the HUD there.
		camera.clamp_to_map()


## Doors and ambushes marked `automatic` fire by being walked into.
func _check_contact_triggers(leader_position: Vector2):
	if _blocking_interaction:
		return
	for interactable in _interactables:
		if not is_instance_valid(interactable) or not interactable.is_available():
			continue
		if not interactable.get("automatic"):
			continue
		# Its own reach, the same one the interact key measures against and the
		# same ring drawn around it in the editor. It used to be a single
		# scene-wide radius of barely half a tile, so an automatic trigger only
		# fired if you walked almost exactly onto it - while pressing E worked
		# from a tile and a quarter away. The ring is what it says it is now.
		if interactable.global_position.distance_to(leader_position) > interactable.interaction_radius:
			# Out of it again, so walking back in counts as walking in - unless it
			# only ever fires once, in which case leaving changes nothing.
			if not interactable.get("only_once"):
				interactable.contact_spent = false
			continue
		if interactable.contact_spent:
			continue
		interactable.contact_spent = true
		interactable.use(self)
		return


## The nearest usable thing in range of the leader - or of `group`'s - or null.
func _nearest_interactable(group: ExplorationParty = null) -> Interactable:
	var leader_position = group.position_of_leader() if group != null else party_position()
	var best: Interactable = null
	var best_distance := INF
	for interactable in _interactables:
		if not is_instance_valid(interactable) or not interactable.is_available():
			continue
		if interactable.get("automatic"):
			# Nothing to press: it goes off by being walked into, and it has no
			# prompt to offer. Handing it to the interact key as well is how an
			# arrival scene got replayed by standing on the spot and pressing E.
			continue
		var distance = interactable.global_position.distance_to(leader_position)
		if distance <= interactable.interaction_radius and distance < best_distance:
			best_distance = distance
			best = interactable
	return best


func _update_prompt():
	_current_target = _nearest_interactable()
	if game_ui == null or not game_ui.has_method("set_interaction_prompt"):
		return
	if not groups.is_empty() and not _blocking_interaction:
		game_ui.set_interaction_prompt(_coop_prompts())
	elif _current_target == null or _blocking_interaction or controlling_familiar():
		game_ui.set_interaction_prompt("")
	else:
		game_ui.set_interaction_prompt("Press %s to %s" % [Pad.key(&"interact"), _current_target.prompt.to_lower()])


func _unhandled_input(event):
	if not event.is_pressed() or event.is_echo():
		return
	# Hiding the HUD is the player's at any time on a map, a conversation too.
	if Pad.went_down(event, &"hide_ui"):
		get_viewport().set_input_as_handled()
		set_ui_hidden(not ui_hidden)
		return
	if _blocking_interaction:
		return
	# On a watched map the stealth bar has the key (StealthBar.outside_spell).
	# Here, it lets a familiar go too.
	if stealth == null and Pad.went_down(event, &"outside_spell"):
		get_viewport().set_input_as_handled()
		outside_spell()
		return
	if Pad.went_down(event, &"stay_here"):
		get_viewport().set_input_as_handled()
		stay_here()
		return
	if event.is_action_pressed(&"swap_leader"):
		get_viewport().set_input_as_handled()
		# With a familiar out, Tab is who the player steers: it or the party -
		# in co-op, the other player's asks for it (FamiliarKeeper.swap_for).
		if familiar_keeper != null and familiar_keeper.familiar != null:
			familiar_keeper.swap_for(Coop.acting if Coop.on() else -1)
			_update_prompt()
			return
		swap_leader()
		return
	if not event.is_action_pressed(&"interact"):
		return
	# Seeing through the familiar's eyes, nothing within the party's reach is -
	# and E sends it back to its caster's shoulder.
	if controlling_familiar():
		get_viewport().set_input_as_handled()
		familiar_keeper.perch()
		_update_prompt()
		return
	# In co-op, what is nearest to whoever pressed (`party` is their group).
	var target := _nearest_interactable() if not groups.is_empty() else _current_target
	if target == null or not target.is_available():
		return
	get_viewport().set_input_as_handled()
	target.use(self)
	_update_prompt()


## Passes the lead to the next living party member (Tab).
##
## The line re-forms on the spot the old leader was standing, rather than the
## new leader walking up from wherever they were trailing - swapping who you
## steer shouldn't teleport the party's position, only its order.
func swap_leader():
	if party == null:
		return
	var standing_at = party_position()
	# Round the line, past anybody told to stay: with nobody else in it, the
	# lead stays where it is.
	var new_leader := ""
	var living := _line_keys()
	for i in range(1, living.size()):
		if not staying.has(living[i]):
			new_leader = living[i]
			break
	if new_leader == "":
		return
	_passing_lead = true
	var guard := Campaign.party_order.size()
	while Campaign.leader() != new_leader and guard > 0:
		Campaign.cycle_leader()
		guard -= 1
	_passing_lead = false
	party.setup(_textures_for(party), standing_at, is_walkable)
	_keep_stayers()
	_refresh_party_panel()
	var definition: CombatantDefinition = CombatantDatabase.combatants.get(new_leader)
	if definition != null:
		log_message("[color=yellow]%s[/color] takes the lead.\n" % definition.name)


## Stops the party walking while something else has control - a conversation,
## most obviously. Interactables that open their own UI call this, then
## end_blocking_interaction when they're finished.
func begin_blocking_interaction():
	_blocking_interaction = true
	for group in all_groups():
		group.frozen = true
	_update_prompt()


func end_blocking_interaction(_arg = null):
	_blocking_interaction = false
	for group in all_groups():
		group.frozen = false
	_update_prompt()


## Walks the party back out of `interactable`'s reach.
##
## For something they were asked about and turned down. An automatic trigger
## fires again the moment it is in range, so leaving them standing on it would
## either loop the conversation or let them stroll past it while it was still
## deciding - they are walked clear instead, and walking back in asks again.
##
## Half a tile past the edge rather than exactly on it, so a single step in any
## direction does not immediately re-offer what they just declined.
func step_party_back_from(interactable: Node) -> void:
	if party == null or interactable == null or not is_instance_valid(interactable):
		return
	await party.retreat_from(interactable.global_position,
		interactable.interaction_radius + Grid.tiles(0.5))
	if is_instance_valid(self):
		_update_prompt()


## Rebuilds the whole scene for whatever map Campaign now points at - how a
## door moves the party between maps.
func reload_map():
	get_tree().reload_current_scene()


## Sets the guards watching, on a map with a StealthSetup in it. Public so a
## map can be made a stealth map after it has come up, which is how the tests
## build one.
func begin_stealth():
	if stealth != null:
		stealth.queue_free()
		stealth = null
	var map = get_node_or_null(MAP_NODE)
	if map == null:
		return
	var setups = map.find_children("*", "StealthSetup", true, false)
	if setups.is_empty():
		return
	stealth = StealthWatch.new()
	stealth.name = "StealthWatch"
	add_child(stealth)
	stealth.begin(self, setups[0], _tile_map)


## Whether something else has the party held right now - a conversation, a
## menu. The guards stand still for it too: nobody is caught mid-sentence.
func is_holding() -> bool:
	if _blocking_interaction:
		return true
	for group in all_groups():
		if group.frozen:
			return true
	return false


## --- Choosing paths ---
##
## At level 5 each of the party chooses a path (SubclassDefinition). The choice
## is put up here, on the map, for one of them at a time - once nothing else is
## going on, so it never lands in the middle of a conversation that reached the
## level.

## Something happened that could mean a path to choose: arriving, a level, a
## new face in the party.
var _paths_due := false
var _path_layer: CanvasLayer = null
## The choice on screen, or null.
var picker: SubclassPicker = null


func _on_party_leveled(_level: int):
	_paths_due = true


func _process(delta):
	if picker != null or store_screen != null or is_holding() or get_tree().paused or SceneTransition.is_changing():
		return
	_hurry_on(delta)
	_watch_traps()
	if _share_out_due():
		share_out()
	elif _paths_due:
		_offer_paths()
	elif _store_due != "":
		_open_store()


## Puts the choice up for the first of the party with a path still to choose.
func _offer_paths():
	_paths_due = false
	var setup := _map_setup()
	if not Campaign.asks_for_paths or (setup != null and not setup.asks_for_paths):
		return
	var due := Campaign.choosing_paths()
	if due.is_empty():
		return
	_path_layer = _overlay("PathChoice")
	picker = SubclassPicker.new()
	picker.process_mode = Node.PROCESS_MODE_ALWAYS
	_path_layer.add_child(picker)
	picker.offer(due[0])
	picker.chosen.connect(_on_path_chosen)
	MenuPause.hold(picker)


func _on_path_chosen(_key: String, _subclass: String):
	MenuPause.release(picker)
	_path_layer.queue_free()
	_path_layer = null
	picker = null
	# Whoever else is still to choose goes next.
	_paths_due = true


## A layer over the map, dimmed, for a choice or a store to sit on.
func _overlay(layer_name: String) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = layer_name
	layer.layer = 60
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	return layer


## --- Moves outside a fight ---
##
## The party's moves on a map (OutsideMoves): the panel in the action bar's place
## (OutsideMovesPanel), the Outside Spell key's choice on a map nobody watches
## (on a watched one it is StealthBar.outside_spell), the party's hurry, and the
## Hide UI key.

## The moves panel, while the HUD has one.
var moves_panel: OutsideMovesPanel = null
## The choice the Outside Spell key put up, while it is up.
var spell_choice: Control = null
## Whether the player has the HUD hidden (Hide UI).
var ui_hidden := false
var _hurry_left := 0.0
var _hurry_times := 1.0
const OutsideSpellChoice := preload("res://ui/outside_spell_choice.gd")


## The party walks `times` as fast for `seconds` (Speed - OutsideMoves).
func hurry(times: float, seconds: float):
	_hurry_times = times
	_hurry_left = seconds
	if party != null:
		party.hurry = times


## Whether the party is hurrying now.
func hurried() -> bool:
	return _hurry_left > 0.0


## Seconds of hurry left.
func hurry_left() -> float:
	return _hurry_left


func _hurry_on(delta: float):
	_fly_on(delta)
	if _hurry_left <= 0.0:
		return
	_hurry_left -= delta
	if _hurry_left <= 0.0:
		_hurry_left = 0.0
		if party != null:
			party.hurry = 1.0
		log_message("The party's hurry wears off.\n")


## Hides the HUD but for the conversation and the log, or puts it back: the
## party portraits, the action bar and the moves, the prompt, and on a watched
## map the stealth bar, the objectives and the prompts over heads.
func set_ui_hidden(on: bool):
	ui_hidden = on
	if game_ui != null and game_ui.has_method("set_ui_hidden"):
		game_ui.set_ui_hidden(on)
	if stealth != null:
		stealth.set_ui_hidden(on)
	_update_prompt()


## --- Co-op (Coop) ---
##
## Each player walks a group of their own (Campaign.controllers): the first
## player's is the party node it always was (_main_party), the others' are more
## ExplorationParty nodes beside it, every one walked by its player's own
## device. `party` is whoever's press is being handled (Coop.acting), so E, G,
## Tab, Stay Here and the stealth bar's keys act for them; their characters come
## first in Campaign.living_party() for the moment, so the leader is theirs too.
## Every group knows the others (`companions`), so sprite_for - what the guards,
## a fight built on the spot and a conversation ask - finds everybody. One
## camera frames them all, pulling back as far as COOP_ZOOM_FLOOR, and the
## leash keeps any group from walking further than LEASH_TILES from the middle
## of the others. Anything that holds the party (a conversation, a catch, a
## menu) holds every group.

## How far a group may walk from the middle of the others, in tiles - a
## PROPOSAL value.
const LEASH_TILES := 10.0
## How far the view may pull back to keep everybody in it, as a share of the
## map's own zoom - a PROPOSAL value.
const COOP_ZOOM_FLOOR := 0.6
## Room kept round everybody in the view, in tiles.
const COOP_VIEW_ROOM := 5.0

## Every player's group, by player number - empty outside co-op.
var groups := {}
## The map's own zoom, before co-op pulled the view back.
var _coop_zoom := 0.0


func _acting_group() -> ExplorationParty:
	if not groups.is_empty() and groups.has(Coop.acting) and is_instance_valid(groups[Coop.acting]):
		return groups[Coop.acting]
	return _main_party


## Every group walking the map - the party alone, outside co-op.
func all_groups() -> Array:
	if groups.is_empty():
		return [_main_party] if _main_party != null else []
	return groups.values().filter(func(group): return is_instance_valid(group))


## The first player with anybody standing: whose group is the party node.
func _first_player() -> int:
	var ids := Coop.players_in_the_party()
	return ids[0] if not ids.is_empty() else 0


## How each of `keys` looks, for a group's setup.
func _looks_of(keys: Array) -> Array:
	var looks := []
	for key in keys:
		var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
		if definition != null:
			looks.append({"key": key, "map_sprite": definition.map_sprite, "sprite_frames": definition.sprite_frames})
	return looks


## What `group` is set up with: its player's characters in co-op.
func _textures_for(group: ExplorationParty) -> Array:
	if groups.is_empty() or group == null or group.player < 0:
		return _party_textures()
	return _looks_of(Coop.keys_of(group.player))


## Who walks in the acting group, in marching order.
func _line_keys() -> Array:
	if groups.is_empty():
		return Campaign.living_party()
	return Coop.keys_of(party.player)


## The group `key` walks in, or null.
func _group_of(key: String) -> ExplorationParty:
	for group in all_groups():
		if group.own_sprite_for(key) != null:
			return group
	return null


## Lays the groups out afresh for who steers whom now: each where its leader
## stood, `leading` from `from`, and anybody new beside the party.
func _build_groups(leading: ExplorationParty, from: Vector2):
	var was := {}
	for id in groups:
		var group = groups[id]
		if is_instance_valid(group) and group.leader != null:
			was[id] = group.position_of_leader()
	for id in groups:
		var group = groups[id]
		if is_instance_valid(group) and group != _main_party:
			group.queue_free()
	groups.clear()
	if not Coop.on():
		_main_party.player = -1
		_main_party.companions = []
		_main_party.leash = Callable()
		_main_party.setup(_party_textures(), from if leading == _main_party else _main_party.position_of_leader(), is_walkable)
		_frame_groups()
		return
	var ids := Coop.players_in_the_party()
	var first := _first_player()
	var main_at := from if leading == _main_party else _main_party.position_of_leader()
	_main_party.player = first
	_main_party.puppet = not Coop.is_local(first)
	_main_party.setup(_looks_of(Coop.keys_of(first)), main_at, is_walkable)
	groups[first] = _main_party
	for id in ids:
		if id == first:
			continue
		var group := ExplorationParty.new()
		group.name = "Party%d" % (id + 1)
		group.player = id
		group.puppet = not Coop.is_local(id)
		add_child(group)
		var at: Vector2 = was.get(id, _beside(main_at, groups.size()))
		if leading != null and leading.player == id:
			at = from
		group.setup(_looks_of(Coop.keys_of(id)), at, is_walkable)
		group.moved.connect(_group_moved.bind(group))
		groups[id] = group
	for group in groups.values():
		group.companions = groups.values()
		group.leash = _within_leash
		_ring(group)
	_frame_groups()


## Somewhere to stand `nth` beside `at` - a tile or so off, on open ground.
func _beside(at: Vector2, nth: int) -> Vector2:
	for step in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP, Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var there: Vector2 = at + step * Grid.tiles(float(nth))
		if is_walkable(there):
			return there
	return at


## Each player's colour round their group's feet.
func _ring(group: ExplorationParty):
	for sprite in group._members():
		var ring = sprite.get_node_or_null("CoopRing")
		if ring == null:
			ring = _CoopRing.new()
			ring.name = "CoopRing"
			ring.show_behind_parent = true
			sprite.add_child(ring)
		ring.colour = Coop.colour_of(group.player)
		ring.queue_redraw()


## A group walked: the camera, what is in reach, its automatic triggers and
## those staying, all as its player.
func _group_moved(leader_position: Vector2, group: ExplorationParty):
	var before := Coop.acting
	Coop.acting = group.player
	_follow_camera(leader_position)
	_check_contact_triggers(leader_position)
	_pick_up_stayers(leader_position, group)
	Coop.acting = before
	_update_prompt()


## Somebody joined or left the game, or changed whom they steer.
func _on_players_changed():
	if _main_party == null or not is_inside_tree():
		return
	_build_groups(_main_party, _main_party.position_of_leader())
	_keep_stayers()
	_refresh_party_panel()
	_update_prompt()


## Keeps everybody in view - true while there is more than one group to frame.
func _frame_groups() -> bool:
	if camera == null:
		return false
	var leaders := []
	for group in all_groups():
		if group.leader != null:
			leaders.append(group.leader.position)
	# A familiar steered in co-op is kept in the frame too.
	if not groups.is_empty() and familiar_keeper != null and familiar_keeper.controlling and familiar_keeper.familiar != null:
		leaders.append(familiar_keeper.familiar.position)
	if leaders.size() < 2:
		if _coop_zoom > 0.0:
			camera.zoom = Vector2.ONE * _coop_zoom
			_coop_zoom = 0.0
		return false
	var box := Rect2(leaders[0], Vector2.ZERO)
	for at in leaders:
		box = box.expand(at)
	if _coop_zoom <= 0.0:
		_coop_zoom = camera.zoom.x
	var view: Vector2 = camera.get_viewport_rect().size
	var room := box.size + Vector2.ONE * Grid.tiles(COOP_VIEW_ROOM)
	var needed := minf(view.x / room.x, view.y / room.y)
	camera.zoom = Vector2.ONE * clampf(needed, _coop_zoom * COOP_ZOOM_FLOOR, _coop_zoom)
	camera.position = box.get_center()
	if camera.has_method("clamp_to_map"):
		camera.clamp_to_map()
	return true


## Whether `group` may step to `to`: within LEASH_TILES of the middle of the
## other groups, or at least no further from it than it is now.
func _within_leash(group: ExplorationParty, to: Vector2) -> bool:
	var middle := Vector2.ZERO
	var others := 0
	for other in all_groups():
		if other != group and other.leader != null:
			middle += other.leader.position
			others += 1
	if others == 0 or group.leader == null:
		return true
	middle /= others
	var then := to.distance_to(middle)
	return then <= Grid.tiles(LEASH_TILES) or then <= group.leader.position.distance_to(middle)


## What each player here can do where they stand: "Player 2: Press A to talk".
func _coop_prompts() -> String:
	var lines := []
	var ids := groups.keys()
	ids.sort()
	for id in ids:
		var group = groups[id]
		if not is_instance_valid(group) or group.puppet:
			continue
		# Whoever is seeing through the familiar's eyes has nothing to hand.
		if familiar_keeper != null and familiar_keeper.controlling and familiar_keeper.steerer == id:
			continue
		var target := _nearest_interactable(group)
		if target == null:
			continue
		var pad: bool = Coop.device_of_player(id) >= 0
		lines.append("%s: Press %s to %s" % [Coop.name_of(id), Pad.key_on(pad, &"interact"), target.prompt.to_lower()])
	return "\n".join(lines)


## The Players panel up over the map to share the party out again, or null.
var _sharing: CanvasLayer = null


## Whether to offer to share the party out again: a player steers nobody now
## (theirs left the party, or fell), and this is not what was offered last.
func _share_out_due() -> bool:
	if not Coop.on() or _sharing != null or PlayersPanel.party_now().is_empty():
		return false
	return not Coop.stranded().is_empty() and Coop.party_shape() != Coop.share_out_offered


## Puts the Players panel up, the party as it stands, to share it out again
## (the designer, 2026-10-29). Done leaves it as it is.
func share_out():
	Coop.share_out_offered = Coop.party_shape()
	var names := Coop.stranded().map(func(id): return Coop.name_of(id))
	open_players("%s has nobody left to steer. Share the party out again - or Done to leave it as it is." % " and ".join(names))


## The Players panel over the map, the party as it stands (the pause menu's
## Players, and share_out), with `note` over it.
func open_players(note: String = ""):
	if _sharing != null:
		return
	_sharing = _overlay("ShareOut")
	var panel := PlayersPanel.new()
	panel.only_party = true
	panel.note = note
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.closed.connect(_shared_out.bind(panel))
	_sharing.add_child(panel)
	MenuPause.hold(panel)


func _shared_out(panel: Node):
	MenuPause.release(panel)
	if _sharing != null:
		_sharing.queue_free()
	_sharing = null
	# What they settled on is not to be offered again.
	Coop.share_out_offered = Coop.party_shape()


## A player's colour under each of their party's feet.
class _CoopRing extends Node2D:
	var colour := Color.WHITE

	func _draw():
		var tile := float(Grid.TILE_SIZE)
		draw_arc(Vector2(0, tile * 0.32), tile * 0.3, 0.0, TAU, 40, Color(colour, 0.85), 8.0)


## --- Staying behind ---
##
## The leader told to stay where they are (Stay Here): they stand there, out of
## the line, and the next of the party not told to stay takes the lead from
## where they were walking. With nobody else to lead, the leader stays the
## leader. Walking the leader back up to somebody staying has them fall in
## behind again; Tab goes round only those in the line. The guards see somebody
## staying where they stand, and a fight places them there (the designer,
## 2026-10-29).

const NOWHERE := Vector2(-99999, -99999)
## How near the leader has to come to somebody staying for them to fall in.
const PICK_UP_TILES := 1.0

## Who is staying, and where: combatant key -> world position.
var staying := {}
## Where the next rebuild of the line starts from, when not the leader's spot.
var _lead_from := NOWHERE
## Set while Tab turns the order round past those staying, so the line is
## rebuilt once at the end rather than at every turn.
var _passing_lead := false


## The leader stays here, and the next of the party not staying leads. False,
## and nothing changed, with nobody else to lead.
func stay_here() -> bool:
	if party == null or is_holding() or controlling_familiar():
		return false
	var leading := Campaign.leader()
	var next := ""
	for key in _line_keys():
		if key != leading and not staying.has(key) and party.own_sprite_for(key) != null:
			next = key
			break
	if next == "":
		log_message("Nobody else to lead - [color=yellow]%s[/color] keeps the lead.\n" % Campaign.display_name_of(leading))
		return false
	staying[leading] = party_position()
	_lead_from = party.own_sprite_for(next).global_position
	Campaign.set_leader(next)
	log_message("[color=yellow]%s[/color] stays where they are; [color=yellow]%s[/color] leads.\n" % [
		Campaign.display_name_of(leading), Campaign.display_name_of(next)])
	return true


## Puts everybody staying back where they stay, after the line is rebuilt.
func _keep_stayers():
	for key in staying.keys():
		var group := _group_of(key)
		var sprite = group.own_sprite_for(key) if group != null else null
		if not Campaign.is_alive(key) or not Campaign.party_order.has(key) or sprite == null or sprite == group.leader:
			staying.erase(key)
			continue
		group.stay(sprite, staying[key])


## Somebody staying, with the leader of their group (`group`, or the party)
## come up to them, falls in behind.
func _pick_up_stayers(leader_position: Vector2, group: ExplorationParty = null):
	if group == null:
		group = party
	for key in staying.keys():
		var sprite = group.own_sprite_for(key)
		if sprite != null and group.stayers.has(sprite) and staying[key].distance_to(leader_position) <= Grid.tiles(PICK_UP_TILES):
			staying.erase(key)
			group.rejoin(sprite)
			log_message("[color=yellow]%s[/color] falls in behind.\n" % Campaign.display_name_of(key))


## --- The familiar, on any map (FamiliarKeeper) ---
##
## On a watched map StealthWatch answers for it (the guards have a say); here
## nobody is watching, so it is only calling, steering, the shoulder and letting
## it go.

var familiar_keeper: FamiliarKeeper = null


## The animal a familiar takes here: the stealth setup's, or the map setup's, or
## the rat.
func familiar_form() -> FamiliarForm:
	if stealth != null and stealth.setup != null and stealth.setup.familiar_form != null:
		return stealth.setup.familiar_form
	var setup := _map_setup()
	if setup != null and setup.familiar_form != null:
		return setup.familiar_form
	return load(FamiliarKeeper.DEFAULT_FORM)


## The spell that calls a familiar and who would cast it, or {}.
func familiar_spell() -> Dictionary:
	if stealth != null:
		return stealth.familiar_spell()
	var walking := Campaign.living_party().filter(func(key): return party != null and party.sprite_for(key) != null)
	return FamiliarKeeper.spell_among(walking)


## Why a familiar could not be called right now, or "".
func familiar_refusal() -> String:
	if stealth != null:
		return stealth.familiar_refusal()
	if familiar_keeper == null or familiar_keeper.familiar != null:
		return "The familiar is out already"
	var spell := familiar_spell()
	if spell.is_empty():
		return "Nobody here knows a spell to call a familiar"
	if is_holding():
		return "Not now"
	return FamiliarKeeper.cannot_pay(spell.caster, SkillDatabase.skills[spell.skill])


## Calls the familiar. False, and nothing spent, when it can't be.
func summon_familiar() -> bool:
	if stealth != null:
		return stealth.summon_familiar()
	if familiar_refusal() != "":
		return false
	var spell := familiar_spell()
	var skill: SkillDefinition = SkillDatabase.skills[spell.skill]
	var paid := FamiliarKeeper.pay(spell.caster, skill)
	if paid.is_empty():
		return false
	familiar_keeper.summon(spell.caster, familiar_form())
	log_message("[color=yellow]%s[/color] casts %s%s: a %s answers, and she sees through its eyes.\n" % [
		Campaign.display_name_of(spell.caster), skill.name, FamiliarKeeper.paid_words(paid), familiar_keeper.familiar.form.name.to_lower()])
	return true


## Lets the familiar go.
func dismiss_familiar():
	if stealth != null:
		stealth.dismiss_familiar()
	elif familiar_keeper != null:
		familiar_keeper.dismiss()


## Whether the player is steering the familiar now.
func controlling_familiar() -> bool:
	return familiar_keeper != null and familiar_keeper.controlling_it()


## --- Flying and blinking ---

var _flying_left := 0.0
## Whether the time is up but they are still over something they cannot stand on.
var _landing := false


## The party flies for `seconds` (Fly - OutsideMoves): over whatever stops only
## walkers - a barrel, a cart - and down once the time is up and they are over
## somewhere they can stand.
func fly(seconds: float):
	_flying_left = seconds
	_landing = false


func flying() -> bool:
	return _flying_left > 0.0 or _landing


func _fly_on(delta: float):
	if _flying_left <= 0.0 and not _landing:
		return
	_flying_left = maxf(_flying_left - delta, 0.0)
	if _flying_left > 0.0:
		return
	# Down only onto open ground - judged as a walker.
	var tile := _tile_map.local_to_map(party_position()) if _tile_map != null else Vector2i.ZERO
	if _blocking.has(tile):
		if not _landing:
			log_message("The party will come down once over open ground.\n")
		_landing = true
		return
	_landing = false
	log_message("The party comes down.\n")


## The leader steps up to `tiles` the way they are going - over anything, onto
## the furthest open ground (Blink - OutsideMoves), the party with them. False
## when there is nowhere to land.
func blink(tiles: int) -> bool:
	if party == null or party.leader == null:
		return false
	var way: Vector2 = party.held_direction()
	if way == Vector2.ZERO:
		way = Vector2.LEFT if party.facing_left() else Vector2.RIGHT
	var from := party_position()
	for step in range(tiles, 0, -1):
		var there := from + way.normalized() * Grid.tiles(step)
		if is_walkable(there):
			party.teleport(there)
			_on_party_moved(there)
			return true
	return false


## --- Magical traps (MagicTrap) ---
##
## Somebody of the party stepping onto an armed one sets it off: the casting can
## be answered - a Counter Trap move (InstaHack) and a quick time event - or the
## laser fires (MagicTrap's own words say what it does).

var _traps: Array = []
## The trap going off now, while its quick time event plays.
var springing: MagicTrap = null


func _watch_traps():
	if springing != null or party == null or _tile_map == null:
		return
	for trap in _traps:
		if not is_instance_valid(trap) or not trap.armed:
			continue
		var at := _tile_map.local_to_map(_tile_map.to_local(trap.global_position))
		for member in Campaign.living_party():
			var sprite = party.sprite_for(member)
			if sprite != null and _tile_map.local_to_map(_tile_map.to_local(sprite.global_position)) == at:
				spring_trap(trap, member)
				return


## Who of the party could answer a trap going off, and with what - {"key",
## "move"} - or {}: somebody walking here with a Counter Trap move they could
## pay for.
func trap_answer() -> Dictionary:
	for key in Campaign.living_party():
		if party != null and party.sprite_for(key) == null:
			continue
		for move in OutsideMoves.moves_of(key):
			var skill: SkillDefinition = SkillDatabase.skills[move]
			if OutsideMoves.use_of(skill) == OutsideMoves.Use.COUNTER_TRAP and OutsideMoves.cannot_pay(key, skill) == "":
				return {"key": key, "move": move}
	return {}


## `who` stepped onto `trap`: answered in time, or the laser.
func spring_trap(trap: MagicTrap, who: String):
	if not trap.armed or springing != null:
		return
	springing = trap
	trap.armed = false
	Campaign.set_flag(trap.flag_for(map_path()))
	var answer := trap_answer()
	var hacked := false
	if not answer.is_empty():
		var skill: SkillDefinition = SkillDatabase.skills[answer.move]
		log_message("A glyph flares under [color=yellow]%s[/color] - a laser is being cast! [color=yellow]%s[/color] reaches for %s...\n" % [
			Campaign.display_name_of(who), Campaign.display_name_of(answer.key), skill.name])
		hacked = await QuickTime.run(trap.quick_time_event())
		if not is_instance_valid(self):
			return
		if hacked:
			var paid := OutsideMoves.pay(answer.key, skill)
			log_message("[color=yellow]%s[/color] hacks the casting apart%s. The glyph goes dark.\n" % [
				Campaign.display_name_of(answer.key), OutsideMoves.paid_through(paid)])
	if not hacked:
		_laser(trap, who)
	springing = null
	_refresh_party_panel()


## The laser: a share of `who`'s health - never the last point - and, where
## guards watch, the alert up a level and everybody near coming to look.
func _laser(trap: MagicTrap, who: String):
	var most: int = Campaign.party_state.get(who, {}).get("max_hp", 0)
	if most <= 0:
		var definition: CombatantDefinition = CombatantDatabase.combatants.get(who)
		most = definition.hp_at(Campaign.party_level) if definition != null else 1
	var before: int = Campaign.party_state.get(who, {}).get("hp", most)
	Campaign.strain(who, roundi(most * trap.laser_share))
	log_message("A laser lances out of the glyph: [color=red]%s[/color] loses %d health.\n" % [
		Campaign.display_name_of(who), before - Campaign.party_state[who].hp])
	if stealth != null:
		stealth.raise_alert_level()
		stealth.make_noise(trap.global_position, trap.noise_tiles, true)


## --- Breakable walls ---

var _walls: Array = []


## Every breakable wall on the map, standing or not.
func walls() -> Array:
	return _walls


func _collect_walls(map: Node):
	_walls = map.find_children("*", "BreakableWall", true, false)
	for wall in _walls:
		wall.broken = Campaign.flag(wall.flag_for(map_path()))
		if not wall.broken and _tile_map != null:
			var tile := _tile_map.local_to_map(_tile_map.to_local(wall.global_position))
			set_tile_shut(tile, true)
			# Not a door: nobody has the key, guards included.
			if Actors._scene == self:
				Actors.refresh_tile(tile)


## The standing wall nearest the leader within `reach` tiles (the fight's count),
## or null.
func wall_in_reach(reach: int) -> BreakableWall:
	if _tile_map == null or party == null:
		return null
	var from := _tile_map.local_to_map(_tile_map.to_local(party_position()))
	var best: BreakableWall = null
	var best_gap := 1 << 30
	for wall in _walls:
		if not is_instance_valid(wall) or wall.broken:
			continue
		var at := _tile_map.local_to_map(_tile_map.to_local(wall.global_position))
		var gap := absi(at.x - from.x) + absi(at.y - from.y)
		if gap <= maxi(reach, 1) and gap < best_gap:
			best = wall
			best_gap = gap
	return best


## Knocks `wall` down for good: walked and seen through, kept in the flags, and
## heard far and wide on a watched map.
func break_wall(wall: BreakableWall):
	if wall == null or wall.broken:
		return
	wall.broken = true
	Campaign.set_flag(wall.flag_for(map_path()))
	var tile := _tile_map.local_to_map(_tile_map.to_local(wall.global_position))
	set_tile_shut(tile, false)
	# A way through now, for whoever walks a route - guards and conversations.
	Actors.refresh_tile(tile)
	if stealth != null:
		stealth.wall_broken(tile)
		stealth.make_noise(wall.global_position, WALL_NOISE_TILES, true)


## How far a wall coming down is heard - a PROPOSAL test value.
const WALL_NOISE_TILES := 8.0


## The Outside Spell key on a map nobody watches: lets a familiar go while one
## is out; otherwise the one spell to some purpose now cast - Find Familiar among
## them - or the choice of which when there are more.
func outside_spell():
	if is_instance_valid(spell_choice) or is_holding():
		return
	# Only the caster's player lets it go, in co-op; the other casts their own.
	if familiar_keeper != null and familiar_keeper.familiar != null and familiar_keeper.may_dismiss(Coop.acting):
		dismiss_familiar()
		return
	var ready := OutsideMoves.ready_spells(self)
	var calls := familiar_refusal() == ""
	if calls and ready.is_empty():
		summon_familiar()
	elif ready.size() == 1 and not calls:
		OutsideMoves.use(self, ready[0].key, ready[0].move)
		if moves_panel != null:
			moves_panel.refresh()
	elif ready.size() + int(calls) > 1:
		var layer := CanvasLayer.new()
		layer.name = "SpellChoice"
		layer.layer = 60
		layer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(layer)
		spell_choice = OutsideSpellChoice.new()
		spell_choice.scene = self
		spell_choice.closed.connect(layer.queue_free)
		layer.add_child(spell_choice)


## --- Stores ---
##
## A store asked for (Campaign.open_store - a StoreInteractable, a conversation)
## goes up once nothing else is going on: a conversation that sends the party
## shopping finishes first.

## The store waiting to be opened, or "".
var _store_due := ""
var _store_layer: CanvasLayer = null
## The store on screen, or null.
var store_screen: StoreScreen = null


func _on_store_requested(store: String):
	_store_due = store


func _open_store():
	_store_layer = _overlay("Store")
	store_screen = StoreScreen.new()
	store_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	_store_layer.add_child(store_screen)
	store_screen.open_on(_store_due)
	_store_due = ""
	store_screen.closed.connect(_close_store)
	MenuPause.hold(store_screen)


func _close_store():
	MenuPause.release(store_screen)
	_store_layer.queue_free()
	_store_layer = null
	store_screen = null


## The loaded map's MapSetup, if it has one. Searched the whole way down
## rather than only among the map's own children, because a map can be a
## wrapper around an instanced terrain scene - the same reason finding the
## TileMap looks in both places.
func _map_setup() -> MapSetup:
	var map = get_node_or_null(MAP_NODE)
	if map == null:
		return null
	for node in map.find_children("*", "MapSetup", true, false):
		return node
	return null
