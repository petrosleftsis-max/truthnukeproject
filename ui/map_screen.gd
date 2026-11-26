extends Node
class_name MapScreen
## The map you can open (the proposals of 2026-11-19, "A map you can open"; the designer: "Do all"). N opens it, or a pad's View
## among the menus (Pad's ring, after the Journal and the rest). Drawn from the map's own tiles - walls, raised ground, water, doors -
## and only where the party has been (MapMemory); the rest lies under the night. The party, the rest spots, a stealth map's goal and
## the pins are marked, and a place's name fades with Lethe (MapLabel). A click puts a pin down, or takes one up; the newest is what
## the arrow at the screen's edge points at (WayArrow). Holds the game while open, as the Journal does. PROPOSAL.

const LAYER := 38
## The map's own colours on the night: what is seen of the floor, raised ground, walls, water and doors.
const FLOOR := Color("8fa7d9")
const RAISED := Color("b7c8ee")
const WALL := Color("1b2a5c")
const WATER := Color("3c7fd1")
const DOOR := Color("e6c36a")
const PIN := Color("e8565a")
const REST := Color("7fe0a2")
const GOAL := Color("ffd84a")

var memory: MapMemory = null
var _layer: CanvasLayer = null
var _drawing: _Drawing = null
var _secrets: Label = null


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	# One of the menus a pad's View goes round (Pad).
	add_to_group(&"pad_menu")


func is_open() -> bool:
	return _layer != null


func open():
	if is_open() or not _may_open():
		return
	MenuPause.hold(self)
	_build()
	MapFeel.sound(&"mark_seen", -10.0)


func close():
	if _layer == null:
		return
	_layer.queue_free()
	_layer = null
	_drawing = null
	MenuPause.release(self)


func _may_open() -> bool:
	if memory == null or memory.scene == null:
		return false
	if memory.scene.get("_blocking_interaction"):
		return false
	return not MenuPause.holders().any(func(holder): return holder != self)


func _input(event: InputEvent):
	if not is_open():
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"map") \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		get_viewport().set_input_as_handled()
		close()


func _unhandled_input(event: InputEvent):
	if is_open() or not event.is_action_pressed(&"map"):
		return
	get_viewport().set_input_as_handled()
	open()


## --- For a pad's View (see Pad) ---


func pad_menu_order() -> int:
	return 4


func pad_menu_available() -> bool:
	return _may_open()


func pad_menu_is_open() -> bool:
	return is_open()


func pad_menu_open():
	open()


func pad_menu_close():
	close()


## --- Building it ---


func _build():
	_layer = CanvasLayer.new()
	_layer.name = "MapScreen"
	_layer.layer = LAYER
	add_child(_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(dim)
	var panel := PanelContainer.new()
	# The look before T, SkyLook (the designer, 2026-11-21): a dark slate panel with a quiet edge, as the journal's.
	var box := StyleBoxFlat.new()
	box.bg_color = Color("19212c")
	box.border_color = Color("2b3947")
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 14
	box.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", box)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 60
	panel.offset_right = -60
	panel.offset_top = 40
	panel.offset_bottom = -40
	_layer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	var title := Label.new()
	title.text = memory.place_name()
	title.theme_type_variation = GameFonts.HEADER
	title.add_theme_font_size_override("font_size", 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	_secrets = Label.new()
	top.add_child(_secrets)
	_drawing = _Drawing.new()
	_drawing.screen = self
	_drawing.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_drawing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_drawing.mouse_filter = Control.MOUSE_FILTER_STOP
	column.add_child(_drawing)
	var hint := Label.new()
	hint.text = "Click to put a pin down, again to take it up    %s or %s to close" % [Pad.key(&"map"), Pad.key(&"ui_cancel")]
	hint.add_theme_font_size_override("font_size", 14)
	column.add_child(hint)
	_refresh()


func _refresh():
	if _secrets != null:
		var all := memory.secrets()
		_secrets.text = "Secrets found: %d of %d    Seen: %d%%" % [memory.secrets_found(), all.size(), roundi(memory.share_seen() * 100.0)] \
				if not all.is_empty() else "Seen: %d%%" % roundi(memory.share_seen() * 100.0)
	if _drawing != null:
		_drawing.queue_redraw()


## A click on the map: a pin down or up at that tile.
func pin_at(tile: Vector2i):
	memory.toggle_pin(tile)
	MapFeel.sound(&"secret_found", -14.0, 1.6)
	_refresh()


## The map, drawn: each tile seen a small square in its kind's colour, and the marks over it.
class _Drawing extends Control:
	var screen: MapScreen = null
	var _kinds := {}

	## Where a tile is drawn and how big: the map fitted into this control, centred.
	func _fit() -> Dictionary:
		var mine := screen.memory.record()
		var size_tiles: Vector2i = mine.size
		var cell := minf(size.x / maxf(size_tiles.x, 1.0), size.y / maxf(size_tiles.y, 1.0))
		var corner := (size - Vector2(size_tiles) * cell) * 0.5
		return {"origin": mine.origin, "cell": cell, "corner": corner}

	func tile_at(point: Vector2) -> Vector2i:
		var fit := _fit()
		var at: Vector2 = (point - fit.corner) / fit.cell
		return Vector2i(floori(at.x), floori(at.y)) + fit.origin

	func point_of(tile: Vector2i) -> Vector2:
		var fit := _fit()
		return fit.corner + (Vector2(tile - fit.origin) + Vector2(0.5, 0.5)) * fit.cell

	func _gui_input(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			screen.pin_at(tile_at(event.position))

	func _kind_of(tile: Vector2i) -> int:
		if _kinds.has(tile):
			return _kinds[tile]
		var scene: Node = screen.memory.scene
		var kind := 0
		var tile_map: TileMap = scene.get("_tile_map")
		var data: TileData = tile_map.get_cell_tile_data(0, tile) if tile_map != null else null
		var lift = data.get_custom_data("Lift") if data != null else 0
		if data == null:
			kind = 2
		elif lift is float and lift < 0.0 or lift is int and lift < 0:
			kind = 3
		elif scene.get("_blocking").has(tile):
			kind = 1 if scene.has_method("climbable") and scene.climbable(tile) else 2
		_kinds[tile] = kind
		return kind

	func _draw():
		var memory := screen.memory
		var scene: Node = memory.scene
		var tile_map: TileMap = scene.get("_tile_map")
		if tile_map == null:
			return
		var fit := _fit()
		var cell: float = fit.cell
		for tile in tile_map.get_used_cells(0):
			if not memory.has_seen(tile):
				continue
			var colour: Color = [MapScreen.FLOOR, MapScreen.RAISED, MapScreen.WALL, MapScreen.WATER][_kind_of(tile)]
			draw_rect(Rect2(point_of(tile) - Vector2.ONE * cell * 0.5, Vector2.ONE * cell), colour)
		var map: Node = scene.get_node_or_null("Map")
		if map != null:
			for door in map.find_children("*", "StealthDoor", true, false):
				var at := tile_map.local_to_map(tile_map.to_local(door.global_position))
				if memory.has_seen(at):
					draw_rect(Rect2(point_of(at) - Vector2.ONE * cell * 0.4, Vector2.ONE * cell * 0.8), MapScreen.DOOR)
			for spot in map.find_children("*", "RestSpot", true, false):
				var at := tile_map.local_to_map(tile_map.to_local(spot.global_position))
				if memory.has_seen(at):
					draw_circle(point_of(at), maxf(cell * 0.7, 5.0), MapScreen.REST)
			for label in map.find_children("*", "MapLabel", true, false):
				var at := tile_map.local_to_map(tile_map.to_local(label.global_position))
				if memory.has_seen(at) and label.has_method("shown_share"):
					var share: float = label.shown_share()
					if share > 0.02:
						var font := get_theme_default_font()
						draw_string_outline(font, point_of(at), label.text, HORIZONTAL_ALIGNMENT_CENTER, -1, 15, 4, Color(0, 0, 0, share))
						draw_string(font, point_of(at), label.text, HORIZONTAL_ALIGNMENT_CENTER, -1, 15, Color(1, 1, 1, share))
		var goal := memory.way_target()
		if goal.is_finite() and memory.pins().is_empty():
			var at := tile_map.local_to_map(tile_map.to_local(goal))
			_star(point_of(at), maxf(cell * 1.2, 8.0), MapScreen.GOAL)
		for pin in memory.pins():
			var at: Vector2 = point_of(pin)
			var r := maxf(cell * 0.9, 7.0)
			draw_colored_polygon(PackedVector2Array([at, at + Vector2(-r * 0.6, -r * 1.6), at + Vector2(r * 0.6, -r * 1.6)]), MapScreen.PIN)
			draw_circle(at + Vector2(0, -r * 1.6), r * 0.6, MapScreen.PIN)
		# The party: a bright arrowhead, the way the leader faces.
		var leader := point_of(memory.leader_tile())
		var r := maxf(cell * 1.1, 8.0)
		draw_circle(leader, r * 0.9, Color(0, 0, 0, 0.5))
		draw_circle(leader, r * 0.6, Color.WHITE)

	func _star(at: Vector2, r: float, colour: Color):
		var points := PackedVector2Array()
		for i in 10:
			var angle := -PI / 2.0 + i * PI / 5.0
			points.append(at + Vector2(cos(angle), sin(angle)) * (r if i % 2 == 0 else r * 0.45))
		draw_colored_polygon(points, colour)
