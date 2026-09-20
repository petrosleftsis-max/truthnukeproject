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
@export_file("*.tscn") var default_map: String = "res://scenes/explore_crossroads.tscn"
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


func _enter_tree():
	_build_map()


func _ready():
	# The map's own cast wins where it has one: a map that names its party is
	# stating who is there at that point in the story, while Starting Party is
	# only a fallback for a map that says nothing (and for running one straight
	# from the editor).
	var setup = _map_setup()
	if setup != null and setup.is_set():
		Campaign.set_party(setup.members, setup.level)
	else:
		Campaign.seed_party(starting_party)
	if setup != null and setup.empty_handed:
		# Before the story has given anybody anything. Done after the party is
		# set, so it empties the bags of whoever is actually here.
		for key in Campaign.living_party():
			Campaign.empty_inventory(key)
	if setup != null and setup.hands_kit_out():
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
	_spawn_party()
	if game_ui != null and game_ui.has_method("set_exploration_mode"):
		game_ui.set_exploration_mode(true)
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
	if _tile_map == null:
		return
	var used = _tile_map.get_used_rect()
	for x in range(used.position.x, used.position.x + used.size.x):
		for y in range(used.position.y, used.position.y + used.size.y):
			var tile = Vector2i(x, y)
			var data = _tile_map.get_cell_tile_data(0, tile)
			if data == null or 0 in data.get_custom_data("Blocks"):
				_blocking[tile] = true


## Whether the party may stand at this world position. Outside the map counts
## as blocked, which is what keeps them on the board.
func is_walkable(world_position: Vector2) -> bool:
	if _tile_map == null:
		return true
	var tile = _tile_map.local_to_map(world_position)
	if not _tile_map.get_used_rect().has_point(tile):
		return false
	return not _blocking.has(tile)


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
		# Reuses the battle camera's clamping, so exploration can't scroll off
		# the edge of the map either.
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
	if _current_target == null or _blocking_interaction:
		game_ui.set_interaction_prompt("")
	else:
		game_ui.set_interaction_prompt("Press E to %s" % _current_target.prompt.to_lower())


func _unhandled_input(event):
	if _blocking_interaction:
		return
	if not event is InputEventKey or not event.pressed or event.is_echo():
		return
	if event.physical_keycode == KEY_TAB:
		get_viewport().set_input_as_handled()
		swap_leader()
		return
	if event.physical_keycode != KEY_E and event.physical_keycode != KEY_SPACE:
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
