@tool
extends Interactable
class_name PlantSpot
## Somewhere on a stealth map to leave something that should be found there:
## a forged letter in a desk, a stolen ring in a locker. With the item in the
## leader's bag, E beside it leaves it here and sets Planted Flag - which a
## StealthObjective (or the story) can wait on.

## What goes here, by item key.
@export var item_key: String = ""
## Set once it is here.
@export var planted_flag: String = ""

var planted := false


func _init():
	prompt = "Leave it here"


func _ready():
	super()
	z_as_relative = false
	z_index = ExplorationParty.PARTY_Z_TOP - 2
	queue_redraw()


func is_available() -> bool:
	if not super() or planted or item_key == "" or Engine.is_editor_hint():
		return false
	if Campaign.count_of(Campaign.leader(), item_key) == 0:
		return false
	var item = ItemDatabase.item(item_key)
	prompt = "Leave the %s here" % (item.name.to_lower() if item != null else item_key)
	return true


func interact(scene: Node):
	if not Campaign.take_item(Campaign.leader(), item_key):
		return
	planted = true
	if planted_flag != "":
		Campaign.set_flag(planted_flag)
	if scene != null and scene.has_method("log_message"):
		var item = ItemDatabase.item(item_key)
		scene.log_message("You leave the %s where it will be found.\n" % (item.name.to_lower() if item != null else item_key))
	queue_redraw()


func _draw():
	var tile := float(Grid.TILE_SIZE)
	# A desk, or a shelf.
	draw_rect(Rect2(-tile * 0.35, -tile * 0.1, tile * 0.7, tile * 0.32), Color(0.36, 0.26, 0.16))
	draw_rect(Rect2(-tile * 0.35, -tile * 0.1, tile * 0.7, tile * 0.06), Color(0.46, 0.34, 0.22))
	if planted:
		draw_rect(Rect2(-tile * 0.1, -tile * 0.2, tile * 0.22, tile * 0.12), Color(0.92, 0.88, 0.74))
	super()
	if Engine.is_editor_hint():
		draw_string(ThemeDB.fallback_font, Vector2(-tile / 2.0 + 8, -tile / 2.0 + 28), "Plant %s" % item_key,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1.0, 0.85, 0.3, 0.9))
