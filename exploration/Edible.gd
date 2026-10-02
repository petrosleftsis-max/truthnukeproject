@tool
extends Interactable
class_name Edible
## Something left out on a stealth map for a guard to eat or drink: a supper
## tray, a jug of wine. Its Eater comes for it Eaten After Seconds into the
## map, whatever he was doing, eats it, and goes back.
##
## Beside it with a poison that goes into food (see ItemDefinition's Poison),
## E stirs it in - with nobody looking, or they know him at once. Whatever it
## does, it does to whoever eats it.

## Whose it is, by his node name on the map.
@export var eater: String = ""
## How long into the map he comes for it.
@export var eaten_after_seconds: float = 30.0
## What it is called, for the log.
@export var called: String = "supper"

## What it looks like.
enum Look { TRAY, JUG }
@export var look: Look = Look.TRAY : set = _set_look

## The poison stirred into it, by item key, or "".
var poisoned_with := ""
var eaten := false


func _init():
	prompt = "Poison it"


func _set_look(value: Look):
	look = value
	queue_redraw()


func _ready():
	super()
	z_as_relative = false
	z_index = ExplorationParty.PARTY_Z_TOP - 2
	queue_redraw()


## Only offered while there is something to put in it, and it is not yet eaten
## or poisoned.
func is_available() -> bool:
	if not super() or eaten or poisoned_with != "" or Engine.is_editor_hint():
		return false
	var poison = Campaign.food_poison_of(Campaign.leader())
	if poison == "":
		return false
	var item = ItemDatabase.item(poison)
	prompt = "Stir %s into the %s" % [item.name if item != null else poison, called]
	return true


func interact(scene: Node):
	var watch = scene.get("stealth")
	if watch != null and watch.has_method("lace"):
		watch.lace(self, Campaign.food_poison_of(Campaign.leader()))


func mark_eaten():
	eaten = true
	queue_redraw()


func _draw():
	var tile := float(Grid.TILE_SIZE)
	match look:
		Look.TRAY:
			draw_rect(Rect2(-tile * 0.32, -tile * 0.05, tile * 0.64, tile * 0.3), Color(0.45, 0.32, 0.2))
			if not eaten:
				draw_circle(Vector2(-tile * 0.1, tile * 0.08), tile * 0.12, Color(0.9, 0.88, 0.82))
				draw_circle(Vector2(-tile * 0.1, tile * 0.08), tile * 0.08, Color(0.72, 0.45, 0.25))
				draw_rect(Rect2(tile * 0.08, -tile * 0.02, tile * 0.14, tile * 0.2), Color(0.85, 0.75, 0.55))
		Look.JUG:
			draw_rect(Rect2(-tile * 0.13, -tile * 0.25, tile * 0.26, tile * 0.45), Color(0.62, 0.38, 0.25))
			draw_rect(Rect2(-tile * 0.08, -tile * 0.33, tile * 0.16, tile * 0.1), Color(0.55, 0.33, 0.22))
			if eaten:
				draw_line(Vector2(-tile * 0.13, tile * 0.2), Vector2(tile * 0.13, -tile * 0.25), Color(0.3, 0.2, 0.12), 6.0)
	super()
	if Engine.is_editor_hint():
		draw_string(ThemeDB.fallback_font, Vector2(-tile / 2.0 + 8, -tile / 2.0 + 28), "For %s" % eater if eater != "" else "Nobody's",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1.0, 0.85, 0.3, 0.9))
