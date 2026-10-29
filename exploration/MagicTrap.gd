@tool
@icon("res://art/editor_icons/magic_trap.svg")
extends Node2D
class_name MagicTrap
## A glyph on the floor that fires a magical laser at whoever of the party
## steps on it (the designer, 2026-10-29). Place it on a floor tile. The moment
## it goes off is a casting, and only then can it be answered: somebody of the
## party with a Counter Trap move (InstaHack) gets a quick time event (Quick
## Time) and, done in time, hacks the casting apart for the move's gate. Late,
## or with nobody to answer, the laser hits for Laser Share of their health -
## never the last point of it - and on a watched map the alert goes up a level
## and the guards near it come to look. Either way it is spent, for good (Flag).

## The flag it is kept spent in. Empty: one made from the map and the node's name.
@export var flag: String = ""
## How much of the health of whoever stepped on it the laser takes - a PROPOSAL
## test value.
@export_range(0.0, 1.0, 0.05) var laser_share: float = 0.3
## How far off the laser is heard, on a watched map.
@export_range(0.0, 20.0, 0.5, "suffix:tiles") var noise_tiles: float = 8.0
## The quick time event an answer is played as; empty for the default.
@export var quick_time: QuickTimeDefinition

const DEFAULT_QUICK_TIME := "res://data/quick_times/counter_trap.tres"
const GLYPH := Color(0.62, 0.45, 0.95, 0.32)

## Whether it can still go off.
var armed := true : set = _set_armed


func _set_armed(value: bool):
	armed = value
	queue_redraw()


func _ready():
	z_as_relative = false
	z_index = ExplorationParty.PARTY_Z_TOP - 3


## The flag it is kept spent in, on the map at `map_path`.
func flag_for(map_path: String) -> String:
	return flag if flag != "" else "trap_spent:%s::%s" % [map_path, name]


## The quick time event an answer is played as.
func quick_time_event() -> QuickTimeDefinition:
	return quick_time if quick_time != null else load(DEFAULT_QUICK_TIME)


func _draw():
	if not armed and not Engine.is_editor_hint():
		return
	var tile := float(Grid.TILE_SIZE)
	draw_arc(Vector2.ZERO, tile * 0.34, 0.0, TAU, 32, GLYPH, 5.0)
	draw_arc(Vector2.ZERO, tile * 0.22, 0.0, TAU, 24, GLYPH, 3.0)
	for i in 6:
		var a := TAU * i / 6.0
		draw_line(Vector2.RIGHT.rotated(a) * tile * 0.22, Vector2.RIGHT.rotated(a + PI / 6.0) * tile * 0.34, GLYPH, 3.0)
	if Engine.is_editor_hint():
		draw_string(ThemeDB.fallback_font, Vector2(-tile / 2.0 + 8, -tile / 2.0 + 28), "Magic trap", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1.0, 0.85, 0.3, 0.9))
