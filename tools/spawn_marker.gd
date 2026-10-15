@tool
@icon("res://art/editor_icons/spawn_marker.svg")
extends Sprite2D
class_name SpawnMarker
## Editor-only. One combatant placed on the map in the encounter editor - drag
## it around the terrain instead of typing coordinates into a .tres.
##
## Snaps itself to tile centres while the editor has it, so a marker is always
## on exactly one tile. Nothing in the running game uses this; markers only
## exist inside tools/encounter_editor.tscn, and EncounterEditor turns them
## into SpawnDefinitions when you save.


## Which CombatantDatabase entry this places. Shown as a dropdown of every key
## in the database (see _validate_property).
@export var combatant_key: String = "":
	set(value):
		combatant_key = value
		_refresh()
@export_enum("Players", "Enemies") var side := 0:
	set(value):
		side = value
		_refresh()
## Optional name overriding the combatant's own - "Striker 1", "Caster 2".
@export var display_name: String = "":
	set(value):
		display_name = value
		queue_redraw()
## The level this combatant fights at here - 1 to 20. Decides every attribute
## they have and which of their skills are unlocked. See SpawnDefinition.
@export_range(1, 20) var level: int = 1:
	set(value):
		level = value
		queue_redraw()
## The path they are on from level 5, picked from the paths there are. See
## SpawnDefinition.subclass.
@export var subclass: String = ""
## What their attacks start from before any stat, and how much damage they
## soak. Per spawn so the same character can be armed and armoured differently
## from one encounter to the next.
@export_range(0, 100) var weapon_base: int = 6
@export_range(1, 100) var defense: int = 10
## What this one brings to the fight, picked from the items there are. Empty
## means empty-handed. An enemy uses what they bring - a potion drunk when
## badly hurt, a bomb thrown - and it is what a Steal takes off them. See
## SpawnDefinition.starting_items.
##
## Here because the marker is what gets written back: saving builds a fresh
## SpawnDefinition out of these fields, so a field the marker does not hold is
## a field that saving erases. This one was not held, and one press of "Save
## spawns to encounter" emptied every bag in the encounter without saying so.
@export var starting_items: Array[String] = []
## The round an enemy joins on - 1 is from the start. See
## SpawnDefinition.arrives_on_round. Held here for the same reason as
## starting_items: without it, Save put every late arrival back to round 1.
@export_range(1, 20) var arrives_on_round: int = 1:
	set(value):
		arrives_on_round = value
		queue_redraw()
## Caught off guard: loses their first turn. See SpawnDefinition.surprised.
@export var surprised: bool = false
## Set by EncounterEditor from the map being previewed.
@export var tile_size := Grid.TILE_SIZE

## Everybody, read straight from their folders rather than through the
## CombatantDatabase autoload: autoloads aren't reliably available to @tool
## scripts in the editor, and this needs no scene tree.
static var _definitions: Dictionary = {}

static func combatant_definitions() -> Dictionary:
	if _definitions.is_empty():
		_definitions = DataFolder.combatants()
	return _definitions


func _ready():
	_refresh()


func _process(_delta):
	if not Engine.is_editor_hint():
		return
	# Snap to the centre of whatever tile the marker has been dragged onto, so
	# a marker can never sit between two tiles or half off one.
	var target = Vector2(grid_position() * tile_size) + Vector2(tile_size, tile_size) * 0.5
	if position != target:
		position = target


## The tile this marker is standing on. The terrain preview and the marker
## container both sit at the origin, so this matches TileMap.local_to_map.
func grid_position() -> Vector2i:
	return Vector2i(floori(position.x / tile_size), floori(position.y / tile_size))


func definition() -> CombatantDefinition:
	return combatant_definitions().get(combatant_key)


## How many tiles a side this one covers (Sizes) - 1 for anybody a tile or smaller.
func span() -> int:
	var found := definition()
	return Sizes.span(found.size, found.gigantic_span) if found != null else 1


## The tiles this one covers, from the tile it is on.
func footprint() -> Array:
	var tiles := []
	for y in span():
		for x in span():
			tiles.append(grid_position() + Vector2i(x, y))
	return tiles


## The name this combatant will actually fight under. A marker with no
## combatant chosen still says so on the map - a blank label on a blank square
## is indistinguishable from nothing being there at all, which is exactly the
## state a spawn added to the encounter by hand starts in.
func effective_name() -> String:
	if display_name != "":
		return display_name
	var found = definition()
	if found != null:
		return found.name
	return combatant_key if combatant_key != "" else "(pick a combatant)"


func _refresh():
	var found = definition()
	# portrait() rather than icon: a combatant whose picture comes from their
	# animation has no icon of their own, and a marker with no texture is an
	# invisible marker - which is exactly what the enemies became.
	texture = found.portrait() if found != null else null
	# Blue for your party, red for the opposition - the same read as the rest
	# of the game's UI, so a glance at the map tells you the shape of the fight.
	modulate = Color(0.6, 0.8, 1.0) if side == 0 else Color(1.0, 0.6, 0.6)
	queue_redraw()


func _draw():
	if not Engine.is_editor_hint():
		return
	var half = tile_size * 0.5
	# The whole square somebody bigger than a tile covers, from this tile -
	# their anchor - down and right.
	var box = Rect2(-half, -half, tile_size * span(), tile_size * span())
	var outline = Color(0.35, 0.65, 1.0) if side == 0 else Color(1.0, 0.4, 0.4)
	draw_rect(box, outline, false, 2.0)
	var font = ThemeDB.fallback_font
	var label = effective_name()
	if level > 1:
		# The level is the one thing about a marker you cannot see from the
		# portrait, and it changes every number the combatant has.
		label += " Lv%d" % level
	if arrives_on_round > 1:
		# Otherwise a reinforcement looks like somebody there from the start.
		label += " R%d" % arrives_on_round
	var width = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	draw_string(font, Vector2(-width * 0.5, half + 11), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)


## Turns combatant_key into a dropdown of the actual database keys, and each of
## starting_items into one of the items, so the editor can't produce an
## encounter referring to a combatant or an item that isn't there.
func _validate_property(property: Dictionary):
	if property.name == "combatant_key":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(combatant_definitions().keys())
	elif property.name == "starting_items":
		property.hint = PROPERTY_HINT_TYPE_STRING
		property.hint_string = SpawnDefinition.item_list_hint()
	elif property.name == "subclass":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = SpawnDefinition.subclass_hint()
