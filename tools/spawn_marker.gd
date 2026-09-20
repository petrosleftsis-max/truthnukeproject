@tool
extends Sprite2D
class_name SpawnMarker
## Editor-only. One combatant placed on the map in the encounter editor - drag
## it around the terrain instead of typing coordinates into a .tres.
##
## Snaps itself to tile centres while the editor has it, so a marker is always
## on exactly one tile. Nothing in the running game uses this; markers only
## exist inside scenes/encounter_editor.tscn, and EncounterEditor turns them
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
## Optional name overriding the combatant's own - "Goblin 1", "Sapper 2".
@export var display_name: String = "":
	set(value):
		display_name = value
		queue_redraw()
## The level this combatant fights at here - 1 to 3. Decides every attribute
## they have and which of their skills are unlocked. See SpawnDefinition.
@export_range(1, 3) var level: int = 1:
	set(value):
		level = value
		queue_redraw()
## What their attacks start from before any stat, and how much damage they
## soak. Per spawn so the same character can be armed and armoured differently
## from one encounter to the next.
@export_range(0, 100) var weapon_base: int = 6
@export_range(1, 100) var defense: int = 10
## Set by EncounterEditor from the map being previewed.
@export var tile_size := Grid.TILE_SIZE

## The database, read straight from its scene rather than through the
## CombatantDatabase autoload: autoloads aren't reliably available to @tool
## scripts in the editor, and this needs no scene tree.
static var _definitions: Dictionary = {}

static func combatant_definitions() -> Dictionary:
	if _definitions.is_empty():
		var database = load("res://databases/combatant_database.tscn").instantiate()
		_definitions = database.combatants.duplicate()
		database.free()
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
	var box = Rect2(-half, -half, tile_size, tile_size)
	var outline = Color(0.35, 0.65, 1.0) if side == 0 else Color(1.0, 0.4, 0.4)
	draw_rect(box, outline, false, 2.0)
	var font = ThemeDB.fallback_font
	var label = effective_name()
	if level > 1:
		# The level is the one thing about a marker you cannot see from the
		# portrait, and it changes every number the combatant has.
		label += " Lv%d" % level
	var width = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	draw_string(font, Vector2(-width * 0.5, half + 11), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)


## Turns combatant_key into a dropdown of the actual database keys, so the
## editor can't produce an encounter referring to a combatant that isn't there.
func _validate_property(property: Dictionary):
	if property.name == "combatant_key":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(combatant_definitions().keys())
