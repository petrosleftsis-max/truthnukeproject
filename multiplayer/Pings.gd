extends CanvasLayer
## Pings (the designer, 2026-10-29): a player marks something for the others - a
## guard, a door, an enemy, a spot on the ground. Z on the keyboard, where the
## mouse points; in co-op, Share on a pad too, where its pointer is, or ahead of
## that player's group while walking with the pointer down (alone, Share still
## hides the UI). A ring in their colour where they pointed, what is there named
## beside it, a sound and a line in the log; an arrow at the edge of the screen
## while it is off it. Gone after PING_SECONDS; a player's newest replaces their
## oldest past PINGS_EACH. Anybody may ping at any time - on somebody else's turn
## too, which is what it is for (Coop lets it through the gate). Over a network
## the others see it as well (Net listens to `pinged`).

signal pinged(player: int, at: Vector2, label: String)

const PING_SECONDS := 4.0
const PINGS_EACH := 2
## How far ahead of a walking group a ping goes with no pointer to aim it.
const AHEAD_TILES := 2.0
const RING := 46.0
const EDGE_ROOM := 34.0

## [{player, at (world), label, left}].
var pings: Array = []

var _canvas: Control = null
var _sound: AudioStreamPlayer = null


func _ready():
	layer = 27
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = _Marks.new()
	_canvas.pings = self
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_canvas)
	_sound = AudioStreamPlayer.new()
	_sound.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	add_child(_sound)


func _process(delta: float):
	if pings.is_empty():
		return
	for ping in pings:
		ping.left -= delta
	pings = pings.filter(func(ping): return ping.left > 0.0)
	_canvas.queue_redraw()


## Taken before anything else hears it: the pad's Share is Hide UI's too, and in
## co-op it is a ping's.
func _input(event: InputEvent):
	if not event.is_action_pressed(&"ping") or event.is_echo():
		return
	var pad := event is InputEventJoypadButton
	if pad and not Coop.on():
		return
	var player := Coop.player_of_event(event) if Coop.on() else 0
	if player == Coop.ANYONE:
		return
	get_viewport().set_input_as_handled()
	ping(player, aim_of(player, pad))


## Where player `player` is pointing: the mouse, or a pad's pointer - or, a pad
## walking about with its pointer down, a little ahead of their group.
func aim_of(player: int, pad: bool) -> Vector2:
	var screen := get_viewport().get_mouse_position()
	if pad:
		if Pad.pointer_showing() and Pad.pointer_pad == Coop.device_of_player(player):
			screen = Pad.pointer()
		else:
			var group = _group_of(player)
			if group != null and group.leader != null:
				var ahead := Vector2.LEFT if group.facing_left() else Vector2.RIGHT
				return group.leader.global_position + ahead * Grid.tiles(AHEAD_TILES)
	return to_world(screen)


## The screen point `screen` on the map.
func to_world(screen: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen


## The map point `at` on the screen.
func to_screen(at: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * at


## Marks `at` (a point on the map) for everybody, as player `player`.
func ping(player: int, at: Vector2) -> Dictionary:
	var label := label_at(at)
	var made := show_ping(player, at, label)
	pinged.emit(player, at, label)
	return made


## Puts a ping up - one made here (ping) or from another machine (Net).
func show_ping(player: int, at: Vector2, label: String) -> Dictionary:
	var theirs := pings.filter(func(each): return each.player == player)
	while theirs.size() >= PINGS_EACH:
		pings.erase(theirs.pop_front())
	var made := {"player": player, "at": at, "label": label, "left": PING_SECONDS}
	pings.append(made)
	_sound.stream = PlaceholderSounds.make("ping")
	_sound.play()
	var scene := _map()
	var said := "[color=#%s]%s[/color] pings %s.\n" % [Coop.colour_of(player).to_html(false), Coop.name_of(player), label]
	if scene != null:
		scene.log_message(said)
	else:
		var combat := _combat()
		if combat != null:
			combat.update_information.emit(said)
	_canvas.queue_redraw()
	return made


## What is at `at`, in words: whoever stands there in a fight, a guard or
## something to use on a map, somebody of the party - or "here".
func label_at(at: Vector2) -> String:
	var scene := _map()
	var combat := _combat() if scene == null else null
	if combat != null and combat.controller != null:
		var tile_map: TileMap = combat.controller.tile_map
		var standing: Dictionary = combat.get_combatant_at(tile_map.local_to_map(tile_map.to_local(at)))
		if not standing.is_empty() and not combat.is_hidden(standing):
			return standing.get("name", "somebody")
		return "here"
	if scene != null:
		var watch: StealthWatch = scene.stealth
		if watch != null:
			var guard = watch._guard_on(watch.tile_of(at))
			if guard != null and is_instance_valid(guard) and guard.visible:
				return watch._name_of(guard)
		var nearest: Interactable = null
		var gap := INF
		for thing in scene._interactables:
			if is_instance_valid(thing) and thing.is_available() and not thing.get("automatic"):
				var distance: float = thing.global_position.distance_to(at)
				if distance <= thing.interaction_radius and distance < gap:
					gap = distance
					nearest = thing
		if nearest != null and nearest.prompt != "":
			return "\"%s\"" % nearest.prompt
		for member in Campaign.party_members():
			var sprite = scene.party.sprite_for(member.key) if scene.party != null else null
			if sprite != null and sprite.global_position.distance_to(at) <= Grid.tiles(0.6):
				return Campaign.display_name_of(member.key)
	return "here"


func clear():
	pings.clear()
	_canvas.queue_redraw()


## The map being walked, or null.
func _map() -> ExplorationScene:
	for node in get_tree().get_nodes_in_group(&"pad_walk"):
		if node is ExplorationScene and node.is_inside_tree() and not node.is_queued_for_deletion():
			return node
	return null


## The fight going on, or null.
func _combat() -> Combat:
	for board in get_tree().get_nodes_in_group(&"pad_board"):
		var combat = board.get("combat")
		if combat is Combat and is_instance_valid(combat) and combat.is_inside_tree():
			return combat
	return null


func _group_of(player: int):
	var scene := _map()
	if scene == null:
		return null
	if scene.groups.has(player):
		return scene.groups[player]
	return scene._main_party


## The rings, the names and the arrows, over everything but conversations.
class _Marks extends Control:
	var pings = null

	func _draw():
		if pings == null:
			return
		var view := get_viewport_rect().size
		var font := ThemeDB.fallback_font
		for ping in pings.pings:
			var colour: Color = Coop.colour_of(ping.player)
			var fade := clampf(ping.left / 0.6, 0.0, 1.0)
			colour.a = fade
			var at: Vector2 = pings.to_screen(ping.at)
			var inside := Rect2(Vector2.ZERO, view).grow(-EDGE_ROOM).has_point(at)
			var text := "%s: %s" % [Coop.name_of(ping.player), ping.label]
			if inside:
				var pulse := 1.0 + 0.18 * sin((PING_SECONDS - ping.left) * 9.0)
				draw_arc(at, RING * pulse, 0.0, TAU, 40, colour, 5.0)
				draw_arc(at, RING * 0.35, 0.0, TAU, 20, colour, 4.0)
				draw_line(at + Vector2(0, -RING * 1.9), at + Vector2(0, -RING * 1.15), colour, 6.0)
				draw_circle(at + Vector2(0, -RING * 0.95), 4.0, colour)
				draw_string_outline(font, at + Vector2(RING + 8, 6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6, Color(0, 0, 0, fade))
				draw_string(font, at + Vector2(RING + 8, 6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, colour)
			else:
				# Off the screen: an arrow on its edge, pointing the way.
				var middle := view / 2.0
				var way := (at - middle).normalized()
				var edge := Vector2(clampf(at.x, EDGE_ROOM, view.x - EDGE_ROOM), clampf(at.y, EDGE_ROOM, view.y - EDGE_ROOM))
				var tip := edge
				var side := Vector2(-way.y, way.x)
				draw_colored_polygon(PackedVector2Array([tip, tip - way * 28.0 + side * 14.0, tip - way * 28.0 - side * 14.0]), colour)
				var place := edge - way * 46.0 - Vector2(0, 0)
				draw_string_outline(font, place, text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, 5, Color(0, 0, 0, fade))
				draw_string(font, place, text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, colour)
