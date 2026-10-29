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

var party: ExplorationParty = null
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
	if party == null or not is_inside_tree():
		return
	party.setup(_party_textures(), party_position(), is_walkable)
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


## Makes `tile` a small gap, or a wall to the small again - for a map's script
## or a test; a painted one is in the tile's Blocks.
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
	party.name = PARTY_NODE
	add_child(party)
	party.setup(_party_textures(), _start_position(), is_walkable)
	party.moved.connect(_on_party_moved)
	_follow_camera(party.position_of_leader())


## What everyone still standing looks like, leader first - straight off the
## campaign roster, so the line on the map is exactly the party you would
## field. Each entry carries both the still and the animation set, because the
## party walks with the same SpriteFrames it fights with.
func _party_textures() -> Array:
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
	_follow_camera(leader_position)
	_update_prompt()
	_check_contact_triggers(leader_position)


func _follow_camera(leader_position: Vector2):
	if camera == null:
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


## The nearest usable thing in range, or null.
func _nearest_interactable() -> Interactable:
	var leader_position = party_position()
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
	if _current_target == null or _blocking_interaction or controlling_familiar():
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
	if event.is_action_pressed(&"swap_leader"):
		get_viewport().set_input_as_handled()
		# With a familiar out, Tab is who the player steers: it or the party.
		if familiar_keeper != null and familiar_keeper.familiar != null:
			familiar_keeper.toggle()
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
	if _current_target == null or not _current_target.is_available():
		return
	get_viewport().set_input_as_handled()
	_current_target.use(self)
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
	var new_leader = Campaign.cycle_leader()
	if new_leader == "":
		return
	party.setup(_party_textures(), standing_at, is_walkable)
	_refresh_party_panel()
	var definition: CombatantDefinition = CombatantDatabase.combatants.get(new_leader)
	if definition != null:
		log_message("[color=yellow]%s[/color] takes the lead.\n" % definition.name)


## Stops the party walking while something else has control - a conversation,
## most obviously. Interactables that open their own UI call this, then
## end_blocking_interaction when they're finished.
func begin_blocking_interaction():
	_blocking_interaction = true
	if party != null:
		party.frozen = true
	_update_prompt()


func end_blocking_interaction(_arg = null):
	_blocking_interaction = false
	if party != null:
		party.frozen = false
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
	return _blocking_interaction or (party != null and party.frozen)


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
	if _paths_due:
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
	for move in _cooldowns.keys():
		_cooldowns[move] -= delta
		if _cooldowns[move] <= 0.0:
			_cooldowns.erase(move)
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


## --- Flying, blinking, waiting ---

var _flying_left := 0.0
## Whether the time is up but they are still over something they cannot stand on.
var _landing := false
## "key|move" -> seconds until a move with no gate can be used again.
var _cooldowns := {}


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


## Seconds before `key` can use `move` again (a move with no gate - OutsideMoves).
func cooldown_of(key: String, move: String) -> float:
	return _cooldowns.get(key + "|" + move, 0.0)


func start_cooldown(key: String, move: String, seconds: float):
	_cooldowns[key + "|" + move] = seconds


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
			set_tile_shut(_tile_map.local_to_map(_tile_map.to_local(wall.global_position)), true)


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
	if familiar_keeper != null and familiar_keeper.familiar != null:
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
