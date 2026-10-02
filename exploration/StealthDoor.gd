@tool
extends Interactable
class_name StealthDoor
## A door on a stealth map, on the floor tile it fills. Shut, nobody walks
## through it and nobody sees through it; E opens and shuts it. Guards have
## the keys: one walking through opens it as he goes and shuts it behind him.
##
## Leave one open that is meant to be shut and a guard who sees it will come
## and shut it - wondering who left it open. Requires Flag locks it until that
## flag is set: a key lifted from somebody's pocket, say.

## Whether it starts open. One that starts shut and is left open is noticed.
@export var starts_open: bool = false : set = _set_starts_open

const WOOD := Color(0.42, 0.28, 0.16)
const WOOD_DARK := Color(0.27, 0.17, 0.09)
const IRON := Color(0.35, 0.36, 0.4)

## Whether it stands open right now - by its own state, not a guard passing.
var is_open := false
## Whether a guard walking through is holding it open this moment.
var held := false


func _init():
	prompt = "Open"
	interaction_radius = Grid.tiles(1.3)


func _set_starts_open(value: bool):
	starts_open = value
	is_open = value
	queue_redraw()


func _ready():
	super()
	is_open = starts_open
	prompt = "Close" if is_open else "Open"
	# Over the floor, under anybody walking through it.
	z_as_relative = false
	z_index = ExplorationParty.PARTY_Z_TOP - 2
	queue_redraw()


## Whether anybody can walk and see through it right now.
func passable() -> bool:
	return is_open or held


func interact(scene: Node):
	var watch = scene.get("stealth")
	if watch != null and watch.has_method("set_door"):
		watch.set_door(self, not is_open, true)
		return
	set_open(not is_open)
	if scene.has_method("set_tile_shut") and scene.get("_tile_map") != null:
		var tile_map: TileMap = scene._tile_map
		scene.set_tile_shut(tile_map.local_to_map(tile_map.to_local(global_position)), not passable())


## Opens or shuts it, as far as it itself knows. The watch keeps the map's
## walls in step - see StealthWatch.set_door.
func set_open(value: bool):
	is_open = value
	prompt = "Close" if is_open else "Open"
	queue_redraw()


func _draw():
	var tile := float(Grid.TILE_SIZE)
	var half := tile / 2.0
	if passable():
		# Swung back against the side of its frame.
		draw_rect(Rect2(-half, -half, tile * 0.14, tile), WOOD_DARK)
		draw_rect(Rect2(-half, -half, tile * 0.14, tile), WOOD, false, 4.0)
	else:
		draw_rect(Rect2(-half, -half, tile, tile), WOOD)
		for i in range(1, 4):
			var x = -half + tile * i / 4.0
			draw_line(Vector2(x, -half), Vector2(x, half), WOOD_DARK, 5.0)
		draw_rect(Rect2(-half, -half * 0.55, tile, tile * 0.08), IRON)
		draw_rect(Rect2(-half, half * 0.45, tile, tile * 0.08), IRON)
		draw_circle(Vector2(half * 0.6, 0.0), tile * 0.05, IRON)
		draw_rect(Rect2(-half, -half, tile, tile), WOOD_DARK, false, 6.0)
	super()
	if Engine.is_editor_hint():
		draw_string(ThemeDB.fallback_font, Vector2(-half + 8, -half + 28), "Door (open)" if starts_open else "Door",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1.0, 0.85, 0.3, 0.9))
