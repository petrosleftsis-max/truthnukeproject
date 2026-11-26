@tool
@icon("res://art/editor_icons/interactable.svg")
extends Interactable
class_name RestSpot
## A place to rest on a map (the proposals of 2026-11-19, "Rest and travel"; the designer: "Do all"): a fire ring, a shrine, a bench.
## Found by coming near it, it is remembered (Campaign.rest_spots). Used, it offers a short rest (Campaign.short_rest: an hour passes),
## once a day at each spot, and nothing more - no long rest, which comes from the story, and no preparing of spells, which only a
## long rest brings (the designer, 2026-11-19) - then travel to any other rest spot found, on any map, by Iris's rainbow, free and
## taking no time, and where it says so a way into the dream-place (Dream Map), no rest needed. A placeholder fire ring until it has
## a picture. PROPOSAL.

const ENTRY_PREFIX := "rest:"
## How near the party has to come for it to be found, in tiles.
const FOUND_TILES := 3.0
const RAINBOW_SECONDS := 0.7
const RAINBOW := [Color("e8565a"), Color("f2a24a"), Color("f2d65a"), Color("6fd58a"), Color("5aa8f2"), Color("8a6af2")]

## What it is called on the rest menu and in the list to travel to. Empty: its node's name.
@export var spot_name: String = ""
## The dream-place's map (a scene path), for a spot that leads there in sleep. Empty: none.
@export_file("*.tscn") var dream_map: String = ""

var _menu: CanvasLayer = null
var _scene_used: Node = null
## For a suite: how many times it has been rested at.
var rested := 0


func _init():
	prompt = "Rest"


func shown_name() -> String:
	return spot_name if spot_name != "" else String(name).capitalize()


## What it is known by on Campaign: its map and its place in it.
func spot_id() -> String:
	return hack_id()


## Where the party stands on arriving here by the rainbow: just below it.
func arrival_point() -> Vector2:
	return global_position + Vector2(0, Grid.tiles(1.0))


func is_known() -> bool:
	return Campaign.rest_spots.has(spot_id())


func _process(_delta: float):
	if Engine.is_editor_hint() or is_known():
		return
	var up := get_parent()
	while up != null and not up.has_method("party_position"):
		up = up.get_parent()
	if up != null and up.party_position().distance_to(global_position) <= Grid.tiles(FOUND_TILES):
		remember(up.map_path())


## Remembered among the rest spots found, to travel to.
func remember(map: String):
	Campaign.rest_spots[spot_id()] = {"map": map, "at": global_position, "name": shown_name()}


func interact(scene: Node):
	remember(scene.map_path())
	_scene_used = scene
	_open_menu()


## --- What it offers ---


## The flag the day the party last rested here is kept in.
func rested_flag() -> String:
	return "rested_on:" + spot_id()


## Whether the party has rested here today: a rest spot gives one short rest a day, and nothing more - a long rest comes from the
## story and its conversations, and spells are prepared only then (the designer, 2026-11-19).
func rested_today() -> bool:
	return int(Campaign.flags.get(rested_flag(), 0)) == Campaign.day_number()


## A short rest: an hour passes, and what a short rest brings back comes back. False, and nothing done, once rested here today.
func rest_here() -> bool:
	if rested_today():
		return false
	# The day it began, should the hour run past midnight.
	Campaign.set_flag(rested_flag(), Campaign.day_number())
	Campaign.short_rest()
	rested += 1
	MapFeel.sound(&"rest", -2.0, 1.0, global_position)
	if _scene_used != null and _scene_used.has_method("log_message"):
		_scene_used.log_message("The party rests a while by the %s.\n" % shown_name().to_lower())
	return true


## Every other rest spot found, on any map: id -> its name.
func places_to_go() -> Dictionary:
	var found := {}
	for id in Campaign.rest_spots:
		if id != spot_id():
			found[id] = Campaign.rest_spots[id].get("name", "?")
	return found


## By Iris's rainbow to the rest spot `id`: a sweep of colour, and the party is there.
func travel_to(id: String):
	var spot: Dictionary = Campaign.rest_spots.get(id, {})
	if spot.is_empty() or _scene_used == null:
		return
	_close_menu()
	MapFeel.sound(&"rainbow", -2.0)
	await _rainbow()
	Campaign.travel_to_map(spot.map, ENTRY_PREFIX + id)
	_scene_used.reload_map()


## Into the dream-place, in sleep.
func dream():
	if dream_map == "" or _scene_used == null:
		return
	_close_menu()
	MapFeel.sound(&"dream", -2.0)
	# Where to wake (DreamWake).
	remember(_scene_used.map_path())
	Campaign.set_flag("dreamt_from", spot_id())
	await _rainbow()
	Campaign.travel_to_map(dream_map, "")
	_scene_used.reload_map()


func _rainbow():
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return
	var layer := CanvasLayer.new()
	layer.layer = 60
	get_tree().root.add_child(layer)
	var bands := _Bands.new()
	bands.set_anchors_preset(Control.PRESET_FULL_RECT)
	bands.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bands)
	var tween := bands.create_tween().set_ignore_time_scale(true)
	tween.tween_property(bands, "share", 1.0, RAINBOW_SECONDS)
	await tween.finished
	layer.queue_free.call_deferred()


## Iris's colours sweeping across the screen, each band a little behind the one above.
class _Bands extends Control:
	var share := 0.0:
		set(value):
			share = value
			queue_redraw()

	func _draw():
		var band := size.y / float(RestSpot.RAINBOW.size())
		for i in RestSpot.RAINBOW.size():
			var reach := clampf(share * 1.6 - i * 0.1, 0.0, 1.0)
			draw_rect(Rect2(0, i * band, size.x * reach, band), RestSpot.RAINBOW[i])


## --- The menu ---


func _open_menu():
	if _menu != null:
		return
	MenuPause.hold(self)
	# Heard while the game is held, for Escape to close it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_menu = CanvasLayer.new()
	_menu.layer = 38
	_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_menu)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(centre)
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
	centre.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.custom_minimum_size = Vector2(340, 0)
	panel.add_child(column)
	var title := Label.new()
	title.text = shown_name()
	title.theme_type_variation = GameFonts.HEADER
	title.add_theme_font_size_override("font_size", 24)
	column.add_child(title)
	var rest := _button(column, "Rest an hour", _rest_from_menu)
	if rested_today():
		rest.text = "Rested here today"
		rest.disabled = true
		rest.tooltip_text = "A rest spot gives one short rest a day."
	var places := places_to_go()
	if not places.is_empty():
		var heading := Label.new()
		heading.text = "Travel by Iris's rainbow"
		heading.add_theme_font_size_override("font_size", 15)
		column.add_child(heading)
		for id in places:
			_button(column, "  " + String(places[id]), func(): travel_to(id))
	if dream_map != "":
		_button(column, "Sleep, and dream", func(): dream())
	_button(column, "Leave", _close_menu)


## Rests an hour from the menu. Then, if anybody can Meditate or somebody fallen could be brought back, the rest's own panel
## (RestPanel, as between a dungeon's fights) takes the menu's place to choose it on; otherwise, or once it is Done, the menu shuts.
func _rest_from_menu():
	if not rest_here() or _menu == null or not _rest_has_choices():
		_close_menu()
		return
	for child in _menu.get_children():
		child.queue_free()
	var panel := RestPanel.new()
	panel.on_a_map = true
	panel.continued.connect(_close_menu)
	_menu.add_child(panel)


## Whether a rest's panel would have anything to ask: somebody who can Meditate (Prometheus, with something spent it could bring
## back), or somebody fallen (Resuscitate, if anybody standing can cast it).
func _rest_has_choices() -> bool:
	for key in Campaign.party_order:
		if Campaign.can_meditate(key):
			return true
		if Campaign.party_state.has(key) and not Campaign.party_state[key].get("alive", true):
			return true
	return false


func _button(column: Container, text: String, pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.pressed.connect(pressed)
	column.add_child(button)
	return button


func _close_menu():
	if _menu == null:
		return
	_menu.queue_free()
	_menu = null
	MenuPause.release(self)
	process_mode = Node.PROCESS_MODE_INHERIT


func is_menu_open() -> bool:
	return _menu != null


func _unhandled_input(event: InputEvent):
	if _menu != null and (event.is_action_pressed(&"ui_cancel")
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT)):
		get_viewport().set_input_as_handled()
		_close_menu()


func _draw():
	super()
	if texture == null and sprite_frames == null:
		# A ring of stones round a low fire.
		var tile := float(Grid.TILE_SIZE)
		for i in 8:
			var angle := i * TAU / 8.0
			draw_circle(Vector2(cos(angle), sin(angle) * 0.6) * tile * 0.3, tile * 0.07, Color("6f6a64"))
		draw_circle(Vector2.ZERO, tile * 0.12, Color("f2a24a"))
		draw_circle(Vector2(0, -tile * 0.05), tile * 0.07, Color("ffe08a"))
