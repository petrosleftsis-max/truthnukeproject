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
## How close an automatic door or ambush has to be to fire on contact.
const CONTACT_RADIUS = 18.0

var party: ExplorationParty = null
var _tile_map: TileMap = null
var _blocking: Dictionary = {}
var _interactables: Array = []
var _current_target: Interactable = null
var _blocking_interaction := false


func _enter_tree():
	_build_map()


func _ready():
	Campaign.seed_party(starting_party)
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
	_build_blocking()
	_interactables = []
	_collect_interactables(map)


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


## Map sprites for everyone still standing, leader first - straight off the
## campaign roster, so the line on the map is exactly the party you'd field.
func _party_textures() -> Array:
	var textures = []
	for member in Campaign.party_members():
		textures.append(member.map_sprite)
	if textures.is_empty():
		# Everyone is down, but there still has to be something to walk with.
		for key in Campaign.party_order:
			if CombatantDatabase.combatants.has(key):
				textures.append(CombatantDatabase.combatants[key].map_sprite)
				break
	return textures


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
		push_warning("Exploration map '%s' has no EntryPoint - the party will start at the origin." % map_path())
		return Vector2.ZERO
	if Campaign.target_entry != "":
		for entry in entries:
			if entry.entry_name == Campaign.target_entry:
				Campaign.target_entry = ""
				return entry.position
		push_warning("Map '%s' has no entry point named '%s' - using its first one." % [map_path(), Campaign.target_entry])
		Campaign.target_entry = ""
	return entries[0].position


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
		if interactable.global_position.distance_to(leader_position) <= CONTACT_RADIUS:
			interactable.interact(self)
			return


## The nearest usable thing in range, or null.
func _nearest_interactable() -> Interactable:
	var leader_position = party_position()
	var best: Interactable = null
	var best_distance := INF
	for interactable in _interactables:
		if not is_instance_valid(interactable) or not interactable.is_available():
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
		game_ui.set_interaction_prompt("[E] %s" % _current_target.prompt)


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
	_current_target.interact(self)
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


## Rebuilds the whole scene for whatever map Campaign now points at - how a
## door moves the party between maps.
func reload_map():
	get_tree().reload_current_scene()
